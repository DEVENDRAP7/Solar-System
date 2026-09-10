"""Per-surface map generators.

Each generator returns ``(colour, height)`` where ``colour`` is an
``(H, W, 3)`` float array in 0..1 and ``height`` is an ``(H, W)`` float array
(or ``None`` for bodies with no relief, such as the gas giants and the Sun).
"""

import numpy as np

import sources
from textures import craters, fbm, height_to_normal, palette_array, ramp, sphere_grid, warp


def _stretch(values, low=0.02, high=0.98):
    """Rescale to 0..1 using percentiles so palettes get their full range."""
    lo, hi = np.quantile(values, [low, high])
    if hi - lo < 1e-9:
        return np.zeros_like(values)
    return np.clip((values - lo) / (hi - lo), 0.0, 1.0)


def _contrast(values, amount):
    """Compress or expand values around the mid point."""
    if amount == 1.0:
        return values
    return np.clip(0.5 + (values - 0.5) * amount, 0.0, 1.0)


def _oval(lat, lon, lat_c, lon_c, half_width, half_height):
    """Smooth elliptical mask centred on a latitude/longitude."""
    d_lon = (lon - lon_c + np.pi) % (2.0 * np.pi) - np.pi
    x = d_lon * np.cos(lat) / half_width
    y = (lat - lat_c) / half_height
    r = np.sqrt(x * x + y * y)
    return np.clip(1.0 - r, 0.0, 1.0) ** 0.6


def _latitude_bands(dirs, lat, spec, seed):
    """Banded cloud structure for the gas giants."""
    bands = float(spec.get('band_count', 10.0))
    turbulence = float(spec.get('band_turbulence', 0.4))

    # Stretch the noise along longitude so detail smears into the bands.
    streaked = dirs * np.array([0.35, 0.35, 1.7])
    streaked = streaked / np.linalg.norm(streaked, axis=-1, keepdims=True)

    swirl = fbm(streaked, freq=2.5, octaves=5, seed=seed) - 0.5
    fine = fbm(streaked, freq=9.0, octaves=4, seed=seed + 313) - 0.5

    phase = lat * bands + swirl * turbulence * 4.0 + fine * turbulence * 0.9
    return 0.5 + 0.5 * np.sin(phase * 2.0)


def generate(spec, width, height_px, seed):
    surface = spec['surface']
    dirs, lat, lon = sphere_grid(width, height_px)
    colors = palette_array(spec['palette'])

    if surface == 'earth_real':
        # Real imagery, so the continents are the actual continents.
        color = sources.expose(
            sources.load_map('earth_base.jpg', width, height_px),
            gamma=float(spec.get('gamma', 0.82)),
            gain=float(spec.get('gain', 1.25)),
        )

        # Cloud deck, laid over the surface at partial strength so the land
        # underneath still reads.
        clouds = sources.load_alpha('earth_clouds.png', width, height_px)
        cover = np.clip(clouds * float(spec.get('cloud_opacity', 0.55)), 0.0, 1.0)
        color = color * (1.0 - cover[..., None]) + cover[..., None]

        # National borders, drawn faintly: enough to pick out a country, not so
        # much that the planet stops looking like a photograph.
        borders = sources.country_borders(width, height_px)
        strength = float(spec.get('border_opacity', 0.30)) * borders
        border_colour = np.array([1.0, 0.86, 0.62])
        color = color * (1.0 - strength[..., None]) + border_colour * strength[..., None]

        return np.clip(color, 0.0, 1.0), None

    if surface == 'moon_real':
        color = sources.expose(
            sources.load_map('moon_base.jpg', width, height_px),
            gamma=float(spec.get('gamma', 0.88)),
            gain=float(spec.get('gain', 1.18)),
        )
        relief = sources.crater_height_field(
            dirs,
            minimum_km=float(spec.get('crater_minimum_km', 4.0)),
        )
        return np.clip(color, 0.0, 1.0), relief

    if surface == 'star':
        cells = fbm(dirs, freq=6.0, octaves=3, seed=seed)
        granulation = fbm(dirs, freq=float(spec.get('noise_scale', 9.0)) * 2.2,
                          octaves=4, seed=seed + 11)
        spots = fbm(dirs, freq=2.2, octaves=3, seed=seed + 29)

        value = _stretch(0.55 * granulation + 0.45 * cells)
        # Bias hot and keep the range narrow: the photosphere reads as a bright
        # glowing surface with fine granulation, not high-contrast mottling.
        value = 0.18 + 0.72 * np.clip(value ** 0.85, 0.0, 1.0)
        # A few broad, shallow cooler regions.
        value *= 1.0 - 0.30 * np.clip((0.24 - spots) * 5.0, 0.0, 1.0)
        return ramp(colors, np.clip(value, 0.0, 1.0)), None

    if surface == 'cratered':
        base = fbm(dirs, freq=float(spec.get('noise_scale', 10.0)), octaves=5, seed=seed)
        relief = craters(dirs, count=340, seed=seed + 7,
                         min_radius=0.010, max_radius=float(spec.get('crater_max', 0.09)))

        height = 0.30 * _stretch(base) + relief
        value = _stretch(0.55 * base + 0.45 * _stretch(relief))

        if spec.get('maria'):
            # Large, dark, smooth basins.
            basins = fbm(dirs, freq=1.7, octaves=3, seed=seed + 101)
            mare = np.clip((0.47 - basins) * 6.0, 0.0, 1.0)
            value = value * (1.0 - 0.62 * mare)
            height = height * (1.0 - 0.55 * mare)

        return ramp(colors, value), height

    if surface == 'cloudy':
        swirled = warp(dirs, amount=0.42, freq=1.8, seed=seed + 5)
        clouds = fbm(swirled, freq=float(spec.get('noise_scale', 6.0)), octaves=6, seed=seed)
        detail = fbm(swirled, freq=14.0, octaves=3, seed=seed + 71)

        value = _stretch(0.75 * clouds + 0.25 * detail, 0.08, 0.92)
        value = _contrast(value, float(spec.get('contrast', 1.0)))
        return ramp(colors, value), _stretch(clouds) * 0.4

    if surface == 'dusty':
        base = fbm(dirs, freq=float(spec.get('noise_scale', 5.0)), octaves=6, seed=seed)
        albedo_field = fbm(dirs, freq=2.0, octaves=4, seed=seed + 19)
        relief = craters(dirs, count=160, seed=seed + 3, min_radius=0.010, max_radius=0.07)

        value = 0.25 + 0.75 * _stretch(0.6 * base + 0.4 * albedo_field)
        # Dark, low-albedo regions of exposed rock.
        dark = np.clip((0.42 - albedo_field) * 5.0, 0.0, 1.0)
        color = ramp(colors[0:4], value) * (1.0 - 0.22 * dark[..., None])

        caps = np.clip((np.abs(lat) + 0.10 * (base - 0.5) - 1.20) / 0.16, 0.0, 1.0)
        color = color * (1.0 - caps[..., None]) + colors[4] * caps[..., None]

        height = 0.55 * _stretch(base) + relief
        return color, height

    if surface == 'banded':
        value = _latitude_bands(dirs, lat, spec, seed)
        value = _contrast(value, float(spec.get('contrast', 1.0)))
        color = ramp(colors[0:4], value)

        if spec.get('great_spot'):
            spot = _oval(lat, lon, lat_c=-0.38, lon_c=0.85, half_width=0.42, half_height=0.17)
            swirl = fbm(dirs, freq=14.0, octaves=3, seed=seed + 601) - 0.5
            spot = np.clip(spot * 1.35 + 0.3 * swirl * (spot > 0.05), 0.0, 1.0)
            color = color * (1.0 - spot[..., None]) + colors[4] * spot[..., None]

        if spec.get('dark_spot'):
            spot = _oval(lat, lon, lat_c=-0.40, lon_c=-1.2, half_width=0.26, half_height=0.12)
            color = color * (1.0 - spot[..., None]) + colors[4] * spot[..., None]

        return color, None

    raise ValueError('unknown surface type: {}'.format(surface))


def ring_strip(width, seed, inner=0.0, outer=1.0):
    """Colour + alpha strip for a planetary ring system.

    Returns an ``(1, W, 4)`` RGBA array sampled along the radius, which is
    mapped across the annulus by the ring mesh's UVs.
    """
    rng = np.random.default_rng(seed)
    t = (np.arange(width, dtype=np.float64) + 0.5) / width

    # Sum of bands at several scales gives the layered look of the real rings.
    density = np.zeros_like(t)
    for scale, weight in ((7.0, 0.5), (19.0, 0.3), (53.0, 0.2)):
        phase = rng.random() * 2.0 * np.pi
        density += weight * (0.5 + 0.5 * np.sin(t * scale * 2.0 * np.pi + phase))

    fine = rng.random(width)
    density = 0.82 * density + 0.18 * np.convolve(fine, np.ones(9) / 9.0, mode='same')

    # The Cassini division and a softer inner gap.
    for centre, half_width, strength in ((0.62, 0.035, 0.95), (0.28, 0.02, 0.55)):
        density *= 1.0 - strength * np.exp(-((t - centre) ** 2) / (2 * half_width ** 2))

    density = np.clip(density, 0.0, 1.0)

    # Fade out at both edges so the annulus has no hard rim.
    density *= np.clip((t - 0.02) / 0.06, 0.0, 1.0) * np.clip((0.99 - t) / 0.07, 0.0, 1.0)

    warm = np.array([0.85, 0.76, 0.60])
    pale = np.array([0.72, 0.70, 0.68])
    color = warm * density[:, None] + pale * (1.0 - density[:, None])

    alpha = np.clip(density * 1.15, 0.0, 1.0)
    return np.concatenate([color, alpha[:, None]], axis=-1)[None, :, :]
