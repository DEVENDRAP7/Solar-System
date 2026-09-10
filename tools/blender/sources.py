"""Real-world source data: imagery, coastlines and the lunar crater catalogue.

Everything here comes from public domain datasets shipped in `data/`. See
`data/SOURCES.md` for provenance.
"""

import csv
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')

# Mean lunar radius, for turning crater diameters into angles on the sphere.
MOON_RADIUS_KM = 1737.4


def _path(name):
    return os.path.join(DATA_DIR, name)


def expose(color, gamma=1.0, gain=1.0):
    """Lift a photographic map so it reads on a phone screen.

    Real planetary albedo is low — Earth reflects about a third of the light
    that reaches it, the Moon about an eighth — so imagery that is accurate
    looks almost black once a lambert term is applied to it. This brightens
    without clipping the highlights.
    """
    lifted = np.clip(color, 0.0, 1.0) ** gamma * gain
    return np.clip(lifted, 0.0, 1.0)


def soften(color, radius):
    """Blur a map slightly.

    Older maps were painted with the craters' shadows already in them. Lighting
    real topography on top of that gives every crater two shadows pointing
    different ways. Softening the albedo leaves the markings while letting the
    relief do the shading.
    """
    if radius <= 0:
        return color
    image = Image.fromarray((np.clip(color, 0.0, 1.0) * 255).astype(np.uint8))
    blurred = image.filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(blurred, dtype=np.float64) / 255.0


def tone(color, keep=1.0, tint=(1.0, 1.0, 1.0), target_mean=None, contrast=1.0):
    """Correct a map's colour toward how the body actually looks.

    Several of the available maps are colourised well beyond the real thing —
    Mercury and Venus arrive strongly orange when Mercury is nearly grey. The
    structure in them is genuine, so rather than discard it, the chroma is
    pulled back toward a measured tint and the overall brightness set to match
    the body's albedo.

    `keep` is how much of the original colour survives, 0 for fully neutral.
    """
    grey = color @ np.array([0.2126, 0.7152, 0.0722])
    neutral = grey[..., None] * np.array(tint)
    out = neutral * (1.0 - keep) + color * keep

    if contrast != 1.0:
        # Some maps have shadowing baked into the albedo, which reads as harsh
        # speckle once real relief is lit on top of it. Pulling the contrast in
        # leaves the markings without the double shadows.
        mean = float(out.mean())
        out = mean + (out - mean) * contrast

    if target_mean is not None:
        current = float(out.mean())
        if current > 1e-6:
            out = out * (target_mean / current)

    return np.clip(out, 0.0, 1.0)


def load_map(name, width, height):
    """Load an equirectangular image as an sRGB float array.

    Source maps are stored the usual way round, with the north pole on the
    first row. The generators work bottom-up, with the south pole first, so the
    image is flipped on the way in.
    """
    image = Image.open(_path(name)).convert('RGB')
    image = image.resize((width, height), Image.LANCZOS)
    array = np.asarray(image, dtype=np.float64) / 255.0
    return np.flipud(array).copy()


def load_grey(name, width, height):
    """Load a single-channel map, flipped to match [load_map]."""
    image = Image.open(_path(name)).convert('L')
    image = image.resize((width, height), Image.LANCZOS)
    array = np.asarray(image, dtype=np.float64) / 255.0
    return np.flipud(array).copy()


def load_alpha(name, width, height):
    """Load a map's transparency as a 0..1 mask.

    The cloud map keeps its coverage in the alpha channel and is otherwise
    solid white, so reading its brightness would blanket the whole planet.
    """
    image = Image.open(_path(name)).convert('RGBA')
    image = image.resize((width, height), Image.LANCZOS)
    array = np.asarray(image, dtype=np.float64)[..., 3] / 255.0
    return np.flipud(array).copy()


def _project(lon_deg, lat_deg, width, height):
    """Longitude and latitude to pixel coordinates.

    Drawing happens the usual way up, with the north pole on the first row,
    because that is where an image library puts its origin. The result is
    flipped afterwards to match [load_map].
    """
    x = (lon_deg + 180.0) / 360.0 * width
    y = (90.0 - lat_deg) / 180.0 * height
    return x, y


def country_borders(width, height, line_width=1):
    """Rasterise national borders from the Natural Earth country polygons.

    Returns a 0..1 mask. Drawing is done at four times the target size and
    averaged down, which gives the lines a soft edge instead of a stair-step.
    """
    scale = 4 if width <= 1024 else 2
    canvas = Image.new('L', (width * scale, height * scale), 0)
    draw = ImageDraw.Draw(canvas)

    with open(_path('countries.geojson')) as handle:
        collection = json.load(handle)

    for feature in collection['features']:
        geometry = feature['geometry']
        if geometry is None:
            continue
        polygons = geometry['coordinates']
        if geometry['type'] == 'Polygon':
            polygons = [polygons]

        for polygon in polygons:
            for ring in polygon:
                points = []
                previous_x = None
                for lon, lat in ring:
                    x, y = _project(lon, lat, width * scale, height * scale)
                    # Break the line where it wraps across the date line, so no
                    # stray stroke is drawn back across the whole map.
                    if previous_x is not None and abs(x - previous_x) > width * scale * 0.5:
                        if len(points) > 1:
                            draw.line(points, fill=255, width=line_width * scale)
                        points = []
                    points.append((x, y))
                    previous_x = x
                if len(points) > 1:
                    draw.line(points, fill=255, width=line_width * scale)

    borders = np.asarray(
        canvas.resize((width, height), Image.LANCZOS), dtype=np.float64) / 255.0
    return np.flipud(borders).copy()


def land_mask(width, height):
    """Filled land polygons as a 0..1 mask, from the same country data."""
    scale = 2
    canvas = Image.new('L', (width * scale, height * scale), 0)
    draw = ImageDraw.Draw(canvas)

    with open(_path('countries.geojson')) as handle:
        collection = json.load(handle)

    for feature in collection['features']:
        geometry = feature['geometry']
        if geometry is None:
            continue
        polygons = geometry['coordinates']
        if geometry['type'] == 'Polygon':
            polygons = [polygons]

        for polygon in polygons:
            if not polygon:
                continue
            ring = polygon[0]
            points = [_project(lon, lat, width * scale, height * scale)
                      for lon, lat in ring]
            if len(points) > 2:
                draw.polygon(points, fill=255)

    mask = np.asarray(
        canvas.resize((width, height), Image.LANCZOS), dtype=np.float64) / 255.0
    return np.flipud(mask).copy()


def load_craters(minimum_km=0.0):
    """The lunar crater catalogue as (longitude, latitude, diameter) arrays.

    Rows are ordered largest first so that when the height field is built, the
    big old basins are laid down before the smaller craters that sit inside
    them — which is the order they happened in.
    """
    lons = []
    lats = []
    diameters = []

    with open(_path('moon_craters.csv')) as handle:
        for row in csv.DictReader(handle):
            diameter = float(row['diameter_km'])
            if diameter < minimum_km:
                continue
            lons.append(float(row['lon']))
            lats.append(float(row['lat']))
            diameters.append(diameter)

    return (
        np.array(lons, dtype=np.float64),
        np.array(lats, dtype=np.float64),
        np.array(diameters, dtype=np.float64),
    )


def crater_height_field(dirs, minimum_km=4.0, depth_scale=1.0):
    """Build a height field from the real craters.

    Each crater contributes a bowl with a raised rim, sized from its catalogued
    diameter. Craters are stamped largest first, so later small craters cut into
    the floors of the basins that came before them, as on the real surface.
    """
    lons, lats, diameters = load_craters(minimum_km)

    lon_rad = np.radians(lons)
    lat_rad = np.radians(lats)
    cos_lat = np.cos(lat_rad)
    centres = np.stack(
        [cos_lat * np.cos(lon_rad), cos_lat * np.sin(lon_rad), np.sin(lat_rad)],
        axis=-1,
    )

    # Angular radius on the sphere, from the crater's real diameter.
    radii = (diameters / 2.0) / MOON_RADIUS_KM

    height = np.zeros(dirs.shape[:-1], dtype=np.float64)
    flat = dirs.reshape(-1, 3)
    rows, columns = dirs.shape[0], dirs.shape[1]

    for index in range(len(radii)):
        radius = radii[index]
        if radius <= 0:
            continue

        centre = centres[index]

        # Only the band of rows the crater can reach needs testing, which keeps
        # a catalogue of this size manageable.
        centre_lat = lat_rad[index]
        reach = radius * 1.6
        low = int(max(0, math.floor((centre_lat - reach + math.pi / 2) / math.pi * rows) - 1))
        high = int(min(rows, math.ceil((centre_lat + reach + math.pi / 2) / math.pi * rows) + 1))
        if high <= low:
            continue

        band = flat[low * columns:high * columns]
        cosine = band @ centre
        np.clip(cosine, -1.0, 1.0, out=cosine)
        angle = np.arccos(cosine)

        mask = angle < reach
        if not mask.any():
            continue

        a = angle[mask] / radius
        # A bowl inside the rim, a raised ring at it, and ejecta falling away.
        bowl = np.where(a < 1.0, -(1.0 - a * a) ** 0.8, 0.0)
        rim = np.exp(-((a - 1.0) ** 2) / 0.045) * 0.6
        ejecta = np.where(a >= 1.0, np.exp(-((a - 1.0) ** 2) / 0.5) * 0.12, 0.0)

        # Deeper craters are shallower in proportion as they get larger, which
        # is why big basins are flat plains rather than deep holes.
        relief = radius ** 0.62 * depth_scale
        contribution = (bowl + rim + ejecta) * relief

        target = height.reshape(-1)[low * columns:high * columns]
        target[mask] += contribution

    span = np.ptp(height)
    return height / span if span > 1e-9 else height
