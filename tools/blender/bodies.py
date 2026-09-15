"""Definitions for every celestial body exported by ``build_models.py``.

Meshes are exported as unit spheres (radius 1.0). True physical sizes and
orbital elements live in ``assets/data/bodies.json`` so the app can choose its
own scale — true-to-life, logarithmic, or artistic — without re-exporting the
models.
"""

# Mesh resolution. 72 segments x 36 rings is 2,592 quads (~5,000 triangles).
# The scene is transformed a vertex at a time in Dart, so this is a real cost
# on the phone and `test/performance_test.dart` guards it. It buys two things:
# a limb smooth enough not to read as a polygon when a body fills the screen,
# and enough vertices for the real topography below to show at all.
SPHERE_SEGMENTS = 72
SPHERE_RINGS = 36

# Surface recipes are interpreted by ``materials.build_surface``.
BODIES = [
    {
        'key': 'sun',
        'label': 'Sun',
        'surface': 'star',
        'radius_km': 696340.0,
        'rotation_hours': 609.12,
        'axial_tilt_deg': 7.25,
        'palette': ['#A83000', '#E86A00', '#FFA524', '#FFC85C', '#FFDE96'],
        'roughness': 1.0,
        'photo': 'sun_base.jpg',
        'resolution': 1024,
        'tint': (1.0, 0.82, 0.52),
        'colour_keep': 0.45,
        'target_mean': 0.86,
        'emission_strength': 6.0,
        'bump_strength': 0.0,
    },
    {
        'key': 'mercury',
        'label': 'Mercury',
        'surface': 'cratered',
        'radius_km': 2439.7,
        'rotation_hours': 1407.6,
        'axial_tilt_deg': 0.034,
        'palette': ['#3A3532', '#6B635C', '#938A80', '#B5ABA0'],
        'roughness': 0.95,
        # Real MESSENGER-derived imagery and topography.
        'photo': 'mercury_base.jpg',
        'bump': 'mercury_bump.jpg',
        'resolution': 2048,
        # The source map is heavily colourised; Mercury is close to grey.
        'colour_keep': 0.12,
        'tint': (1.0, 0.98, 0.95),
        'target_mean': 0.64,
        'colour_contrast': 0.55,
        # The 8k map is a real photograph with its craters already in it, so
        # it is left alone. The 1k map this replaced was painted, with crater
        # shadows baked in that fought the relief, and had to be blurred.
        'soften': 0.0,
        'bump_strength': 0.26,
        # Only a touch: the altimetry is a 1k map stretched over a 2k
        # surface, so leaning on it turns real craters into sandpaper.
        'relief_shade': 0.15,
        # Relief displaced into the mesh itself, as a fraction of the
        # radius. Exaggerated, as every relief map is: real topography is
        # a rounding error on a globe this size and would not be visible.
        'relief_strength': 0.009,
    },
    {
        'key': 'venus',
        'label': 'Venus',
        'surface': 'cloudy',
        'radius_km': 6051.8,
        'rotation_hours': -5832.5,
        'axial_tilt_deg': 177.36,
        # Venus is drawn as the cloud deck, which is all that is ever visible
        # from space; the radar map of the ground below is in data/ as
        # venus_base.jpg if the surface is wanted instead. The deck itself is
        # now a real photograph rather than invented noise.
        'photo': 'venus_clouds.jpg',
        'palette': ['#C9AE7A', '#E0CDA0', '#F2E6C8', '#FAF3E2'],
        'resolution': 2048,
        'colour_keep': 0.5,
        'tint': (1.0, 0.93, 0.76),
        'target_mean': 0.72,
        'roughness': 0.85,
        'contrast': 0.5,
        'noise_scale': 6.0,
        # No normal map: Venus is smooth cloud deck, and every map costs a
        # pure-Dart image decode on the device at load time.
        'bump_strength': 0.0,
    },
    {
        'key': 'earth',
        'label': 'Earth',
        'surface': 'earth_real',
        'night': 'earth_night.png',
        'night_floor': 0.20,
        'night_gain': 1.25,
        'cloud_opacity': 0.55,
        'border_opacity': 0.30,
        # The day side now reaches full brightness, so the map no longer
        # needs lifting: at the old exposure the Sahara blew out to white.
        'gamma': 0.92,
        'gain': 1.02,
        'resolution': 2048,
        'radius_km': 6371.0,
        'rotation_hours': 23.934,
        'axial_tilt_deg': 23.44,
        'palette': ['#0A2A5E', '#12518F', '#2C6B38', '#7E7A45', '#8A7359', '#F2F4F7'],
        'roughness': 0.7,
        # No normal map: the imagery's brightness is not its elevation, so a
        # map derived from it would raise the Sahara into a plateau.
        'bump_strength': 0.0,
    },
    {
        'key': 'moon',
        'label': 'Moon',
        'surface': 'moon_real',
        'crater_minimum_km': 4.0,
        'resolution': 2048,
        # The Moon reflects about an eighth of the light hitting it, so the
        # honest imagery needs a firm lift to read on a screen.
        'gamma': 0.95,
        'gain': 1.0,
        'radius_km': 1737.4,
        'rotation_hours': 655.72,
        'axial_tilt_deg': 6.68,
        'palette': ['#2E2B28', '#5C574F', '#8E877C', '#C2BBB0'],
        'roughness': 0.98,
        'noise_scale': 10.0,
        'crater_max': 0.11,
        'maria': True,
        'bump_strength': 0.5,
        # The 8k map already carries fine crater detail, so the curvature bake
        # only has to deepen it. At the strength the 1k map needed it swamped
        # the maria, leaving a uniformly pale ball.
        'relief_shade': 0.34,
        # Relief displaced into the mesh itself, as a fraction of the
        # radius. Exaggerated, as every relief map is: real topography is
        # a rounding error on a globe this size and would not be visible.
        'relief_strength': 0.01,
    },
    {
        'key': 'mars',
        'label': 'Mars',
        'surface': 'dusty',
        'radius_km': 3389.5,
        'rotation_hours': 24.623,
        'axial_tilt_deg': 25.19,
        'palette': ['#5A2010', '#8C3A1B', '#C0632E', '#D89A63', '#F0EDE6'],
        'roughness': 0.92,
        'photo': 'mars_base.jpg',
        'bump': 'mars_bump.jpg',
        'resolution': 2048,
        'colour_keep': 0.6,
        'tint': (1.0, 0.86, 0.72),
        'target_mean': 0.50,
        'bump_strength': 0.3,
        'relief_shade': 0.26,
        # Relief displaced into the mesh itself, as a fraction of the
        # radius. Exaggerated, as every relief map is: real topography is
        # a rounding error on a globe this size and would not be visible.
        'relief_strength': 0.012,
    },
    {
        'key': 'jupiter',
        'label': 'Jupiter',
        'surface': 'banded',
        'radius_km': 69911.0,
        'rotation_hours': 9.925,
        'axial_tilt_deg': 3.13,
        'palette': ['#6B4423', '#A9713F', '#D6B48A', '#EFE2CC', '#B04A33'],
        'roughness': 0.6,
        'photo': 'jupiter_base.jpg',
        'resolution': 2048,
        'colour_keep': 0.8,
        'target_mean': 0.55,
        'bump_strength': 0.0,
    },
    {
        'key': 'saturn',
        'label': 'Saturn',
        'surface': 'banded',
        'radius_km': 58232.0,
        'rotation_hours': 10.656,
        'axial_tilt_deg': 26.73,
        'palette': ['#8A6B36', '#B99459', '#DCC189', '#F2E6C8', '#C7A96B'],
        'roughness': 0.6,
        'photo': 'saturn_base.jpg',
        'resolution': 2048,
        'colour_keep': 0.85,
        'target_mean': 0.58,
        'bump_strength': 0.0,
    },
    {
        'key': 'uranus',
        'label': 'Uranus',
        'surface': 'banded',
        'radius_km': 25362.0,
        'rotation_hours': -17.24,
        'axial_tilt_deg': 97.77,
        'palette': ['#69AEB8', '#89C7CF', '#A8DBE1', '#C4E9ED', '#7FC0C9'],
        'roughness': 0.5,
        'photo': 'uranus_base.jpg',
        'resolution': 2048,
        'target_mean': 0.62,
        'bump_strength': 0.0,
    },
    {
        'key': 'neptune',
        'label': 'Neptune',
        'surface': 'banded',
        'radius_km': 24622.0,
        'rotation_hours': 16.11,
        'axial_tilt_deg': 28.32,
        'palette': ['#1B3C8C', '#2A56B5', '#4E82D8', '#9CC0EE', '#12296B'],
        'roughness': 0.5,
        'photo': 'neptune_base.jpg',
        'resolution': 2048,
        # Voyager's images were contrast-stretched; reprocessing shows Neptune
        # is much paler, close to Uranus but a little bluer.
        'colour_keep': 0.32,
        'tint': (0.80, 0.89, 1.0),
        'target_mean': 0.58,
        'bump_strength': 0.0,
    },
]

# Saturn's rings are a flat annulus with a generated colour + alpha texture,
# expressed in multiples of the planet's radius.
RINGS = {
    'key': 'saturn_rings',
    'label': 'Saturn rings',
    'inner_radius': 1.24,
    'outer_radius': 2.27,
    'segments': 128,
    # The 8k strip carries the ring's own transparency in its alpha, so
    # the Cassini division is a real gap rather than one inferred from
    # how dark the pixels are.
    'photo': 'saturn_ring_hi.png',
}

# ---------------------------------------------------------------------------
# Moons
# ---------------------------------------------------------------------------
# Small bodies, drawn at a quarter of the map size the planets use: at the
# scale a moon appears on screen, more pixels would be wasted bytes. Palettes
# follow how each one actually looks — Io's sulphur yellows, Europa's clean
# ice, Callisto's dark cratered crust, Titan's orange haze.

MOONS = [
    {'key': 'phobos', 'label': 'Phobos', 'surface': 'cratered',
     'palette': ['#2A2622', '#4A423A', '#6B6156', '#847A6E'],
     'crater_max': 0.22, 'noise_scale': 14.0, 'bump_strength': 0.5},
    {'key': 'deimos', 'label': 'Deimos', 'surface': 'cratered',
     'palette': ['#2E2A25', '#514840', '#736A5E', '#8D8376'],
     'crater_max': 0.18, 'noise_scale': 12.0, 'bump_strength': 0.4},

    {'key': 'io', 'label': 'Io', 'surface': 'dusty',
     'palette': ['#6B4A12', '#B58A20', '#E8C64E', '#F5E08C', '#FFF4C4'],
     'noise_scale': 7.0, 'bump_strength': 0.12},
    {'key': 'europa', 'label': 'Europa', 'surface': 'cratered',
     'palette': ['#7A6A56', '#BFAE96', '#E4DACA', '#F6F1E6'],
     'crater_max': 0.05, 'noise_scale': 9.0, 'bump_strength': 0.08},
    {'key': 'ganymede', 'label': 'Ganymede', 'surface': 'cratered',
     'palette': ['#3E3830', '#6E6357', '#9A8E7F', '#BDB2A2'],
     'crater_max': 0.12, 'noise_scale': 8.0, 'bump_strength': 0.3},
    {'key': 'callisto', 'label': 'Callisto', 'surface': 'cratered',
     'palette': ['#241F1A', '#453D34', '#6A5F52', '#8E8174'],
     'crater_max': 0.16, 'noise_scale': 11.0, 'bump_strength': 0.45},

    {'key': 'mimas', 'label': 'Mimas', 'surface': 'cratered',
     'palette': ['#4A4740', '#7C776D', '#ADA79B', '#D2CCBF'],
     'crater_max': 0.30, 'noise_scale': 10.0, 'bump_strength': 0.5},
    {'key': 'enceladus', 'label': 'Enceladus', 'surface': 'cratered',
     'palette': ['#8E9298', '#C3C7CC', '#E8EBEE', '#FBFCFD'],
     'crater_max': 0.06, 'noise_scale': 9.0, 'bump_strength': 0.12},
    {'key': 'tethys', 'label': 'Tethys', 'surface': 'cratered',
     'palette': ['#6E6F6A', '#A3A49D', '#D0D0C8', '#EDEDE6'],
     'crater_max': 0.14, 'noise_scale': 9.0, 'bump_strength': 0.25},
    {'key': 'dione', 'label': 'Dione', 'surface': 'cratered',
     'palette': ['#65665F', '#9A9A92', '#C6C6BD', '#E4E4DA'],
     'crater_max': 0.12, 'noise_scale': 9.0, 'bump_strength': 0.22},
    {'key': 'rhea', 'label': 'Rhea', 'surface': 'cratered',
     'palette': ['#5E5F58', '#95958C', '#C2C2B8', '#E0E0D6'],
     'crater_max': 0.13, 'noise_scale': 10.0, 'bump_strength': 0.28},
    {'key': 'titan', 'label': 'Titan', 'surface': 'cloudy',
     'palette': ['#8A5A12', '#C08A28', '#E0B057', '#F0D08E'],
     'contrast': 0.4, 'noise_scale': 5.0, 'bump_strength': 0.0},
    {'key': 'iapetus', 'label': 'Iapetus', 'surface': 'cratered',
     'palette': ['#241C14', '#5A4E3E', '#A69A88', '#DCD5C6'],
     'crater_max': 0.15, 'noise_scale': 8.0, 'bump_strength': 0.3},

    {'key': 'miranda', 'label': 'Miranda', 'surface': 'cratered',
     'palette': ['#4E5254', '#82868A', '#B0B4B8', '#D6D9DC'],
     'crater_max': 0.16, 'noise_scale': 11.0, 'bump_strength': 0.4},
    {'key': 'ariel', 'label': 'Ariel', 'surface': 'cratered',
     'palette': ['#5A5E60', '#8E9294', '#BCC0C2', '#DEE1E3'],
     'crater_max': 0.10, 'noise_scale': 9.0, 'bump_strength': 0.25},
    {'key': 'umbriel', 'label': 'Umbriel', 'surface': 'cratered',
     'palette': ['#33352F', '#565853', '#7A7C77', '#989995'],
     'crater_max': 0.14, 'noise_scale': 9.0, 'bump_strength': 0.3},
    {'key': 'titania', 'label': 'Titania', 'surface': 'cratered',
     'palette': ['#4A423C', '#7C726A', '#A99E94', '#CBC1B7'],
     'crater_max': 0.11, 'noise_scale': 9.0, 'bump_strength': 0.25},
    {'key': 'oberon', 'label': 'Oberon', 'surface': 'cratered',
     'palette': ['#443C36', '#746A62', '#A0958B', '#C3B9AE'],
     'crater_max': 0.13, 'noise_scale': 9.0, 'bump_strength': 0.28},

    {'key': 'proteus', 'label': 'Proteus', 'surface': 'cratered',
     'palette': ['#2C2E30', '#4E5154', '#71757A', '#8F9398'],
     'crater_max': 0.20, 'noise_scale': 11.0, 'bump_strength': 0.4},
    {'key': 'triton', 'label': 'Triton', 'surface': 'cratered',
     'palette': ['#7A6A6A', '#B5A29C', '#DCCFC6', '#F2EAE2'],
     'crater_max': 0.06, 'noise_scale': 8.0, 'bump_strength': 0.12},
]

# Physical data, so the manifest describes the real moons rather than the
# meshes. Radii in kilometres, rotation periods in hours — every one of these
# is tidally locked, so its day equals its orbit.
MOON_FACTS = {
    'phobos': (11.27, 7.654), 'deimos': (6.2, 30.299),
    'io': (1821.6, 42.459), 'europa': (1560.8, 85.228),
    'ganymede': (2634.1, 171.709), 'callisto': (2410.3, 400.536),
    'mimas': (198.2, 22.618), 'enceladus': (252.1, 32.885),
    'tethys': (531.1, 45.307), 'dione': (561.4, 65.686),
    'rhea': (763.8, 108.437), 'titan': (2574.7, 382.690),
    'iapetus': (734.5, 1903.716),
    'miranda': (235.8, 33.924), 'ariel': (578.9, 60.489),
    'umbriel': (584.7, 99.460), 'titania': (788.4, 208.941),
    'oberon': (761.4, 323.118),
    'proteus': (210.0, 26.936), 'triton': (1353.4, 141.045),
}

# Every moon is generated the same way, only smaller.
for _moon in MOONS:
    _moon.setdefault('roughness', 0.95)
    _moon.setdefault('resolution', 256)
    _radius, _rotation = MOON_FACTS[_moon['key']]
    _moon['radius_km'] = _radius
    _moon['rotation_hours'] = _rotation
    _moon['axial_tilt_deg'] = 0.0

BODIES = BODIES + MOONS

BODIES_BY_KEY = {b['key']: b for b in BODIES}
