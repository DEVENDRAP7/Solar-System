"""Procedural surface map generation for the solar system models.

Every body gets an equirectangular colour map and, where the surface has
relief, a height field that is converted into a tangent-space normal map.
The maps are produced with numpy only, so they are deterministic: the same
seed always yields the same planet.

Noise is evaluated in three dimensions at points on the unit sphere rather
than across the flat image, which means patterns wrap around the longitude
seam with no visible join.
"""

import numpy as np

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------


def hex_to_rgb(value):
    """Convert ``'#RRGGBB'`` to a linear-ish float triple in 0..1."""
    value = value.lstrip('#')
    srgb = np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0
    return srgb


def palette_array(palette):
    return np.array([hex_to_rgb(c) for c in palette], dtype=np.float64)


def ramp(colors, t):
    """Map ``t`` in 0..1 across an evenly spaced colour ramp.

    ``t`` may have any shape; the result gains a trailing axis of size 3.
    """
    colors = np.asarray(colors, dtype=np.float64)
    stops = len(colors) - 1
    t = np.clip(t, 0.0, 1.0) * stops
    i0 = np.clip(np.floor(t).astype(np.int32), 0, stops - 1)
    frac = (t - i0)[..., None]
    return colors[i0] * (1.0 - frac) + colors[i0 + 1] * frac


# ---------------------------------------------------------------------------
# Noise
# ---------------------------------------------------------------------------


def _smoothstep(t):
    return t * t * (3.0 - 2.0 * t)


def value_noise(dirs, freq, seed):
    """Trilinearly interpolated value noise sampled on the unit sphere.

    ``dirs`` is an array of unit vectors with shape ``(..., 3)``. The lattice
    is sized to the requested frequency so no wrapping (and therefore no
    tiling) can occur.
    """
    size = int(np.ceil(2.0 * freq)) + 2
    rng = np.random.default_rng(seed)
    lattice = rng.random((size, size, size), dtype=np.float32)

    coords = dirs * freq + freq
    base = np.floor(coords).astype(np.int32)
    frac = _smoothstep(coords - base)

    x0, y0, z0 = base[..., 0], base[..., 1], base[..., 2]
    x1, y1, z1 = x0 + 1, y0 + 1, z0 + 1
    fx, fy, fz = frac[..., 0], frac[..., 1], frac[..., 2]

    def at(xi, yi, zi):
        return lattice[xi, yi, zi]

    c00 = at(x0, y0, z0) * (1 - fx) + at(x1, y0, z0) * fx
    c10 = at(x0, y1, z0) * (1 - fx) + at(x1, y1, z0) * fx
    c01 = at(x0, y0, z1) * (1 - fx) + at(x1, y0, z1) * fx
    c11 = at(x0, y1, z1) * (1 - fx) + at(x1, y1, z1) * fx

    c0 = c00 * (1 - fy) + c10 * fy
    c1 = c01 * (1 - fy) + c11 * fy
    return (c0 * (1 - fz) + c1 * fz).astype(np.float64)


def fbm(dirs, freq=3.0, octaves=5, seed=0, lacunarity=2.0, gain=0.5):
    """Fractal sum of value noise, normalised to roughly 0..1."""
    total = np.zeros(dirs.shape[:-1], dtype=np.float64)
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        total += amplitude * value_noise(dirs, freq * lacunarity ** octave, seed + octave * 977)
        norm += amplitude
        amplitude *= gain
    return total / norm


def warp(dirs, amount, freq, seed):
    """Displace sample directions by a vector noise field (domain warping)."""
    offset = np.stack(
        [
            fbm(dirs, freq=freq, octaves=3, seed=seed + axis * 5171) - 0.5
            for axis in range(3)
        ],
        axis=-1,
    )
    warped = dirs + amount * offset
    return warped / np.linalg.norm(warped, axis=-1, keepdims=True)


# ---------------------------------------------------------------------------
# Geometry of the map
# ---------------------------------------------------------------------------


def sphere_grid(width, height):
    """Return unit direction vectors, latitude and longitude for each texel.

    The layout matches Blender's UV sphere unwrap: u spans longitude, v spans
    latitude, with v=0 at the south pole.
    """
    lon = (np.arange(width, dtype=np.float64) + 0.5) / width * 2.0 * np.pi - np.pi
    lat = (np.arange(height, dtype=np.float64) + 0.5) / height * np.pi - np.pi / 2.0
    lon_grid, lat_grid = np.meshgrid(lon, lat)

    cos_lat = np.cos(lat_grid)
    dirs = np.stack(
        [cos_lat * np.cos(lon_grid), cos_lat * np.sin(lon_grid), np.sin(lat_grid)],
        axis=-1,
    )
    return dirs, lat_grid, lon_grid


def height_to_normal(height, strength=1.0):
    """Convert a height field into an encoded tangent-space normal map."""
    rows = height.shape[0]
    lat = (np.arange(rows, dtype=np.float64) + 0.5) / rows * np.pi - np.pi / 2.0
    # Texels converge at the poles, so horizontal gradients are scaled by the
    # shrinking circumference; clamped to keep the poles from blowing up.
    scale = 1.0 / np.clip(np.cos(lat), 0.15, None)

    d_lat, d_lon = np.gradient(height)
    d_lon = d_lon * scale[:, None]

    nx = -d_lon * strength * 40.0
    ny = -d_lat * strength * 40.0
    nz = np.ones_like(height)

    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return normal * 0.5 + 0.5


def craters(dirs, count, seed, min_radius=0.012, max_radius=0.10, depth=1.0):
    """Accumulate a crater height field over the sphere.

    Craters are placed uniformly on the sphere; each contributes a bowl with a
    raised rim, and older (larger) craters are flattened by younger ones simply
    by being summed in size order.
    """
    rng = np.random.default_rng(seed)
    height = np.zeros(dirs.shape[:-1], dtype=np.float64)

    # Uniform points on the sphere.
    centres = rng.normal(size=(count, 3))
    centres /= np.linalg.norm(centres, axis=-1, keepdims=True)
    # Power-law size distribution: many small craters, few large ones.
    radii = min_radius + (max_radius - min_radius) * rng.random(count) ** 2.6
    order = np.argsort(-radii)

    for index in order:
        centre = centres[index]
        radius = radii[index]
        cos_d = np.clip(dirs @ centre, -1.0, 1.0)
        angle = np.arccos(cos_d)

        reach = radius * 1.45
        mask = angle < reach
        if not mask.any():
            continue

        a = angle[mask] / radius
        bowl = np.where(a < 1.0, -(1.0 - a ** 2), 0.0)
        rim = np.exp(-((a - 1.05) ** 2) / 0.02) * 0.55
        height[mask] += (bowl + rim) * radius * depth * 6.0

    span = np.ptp(height)
    return height / span if span > 1e-9 else height
