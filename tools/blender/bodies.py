"""Definitions for every celestial body exported by ``build_models.py``.

Meshes are exported as unit spheres (radius 1.0). True physical sizes and
orbital elements live in ``assets/data/bodies.json`` so the app can choose its
own scale — true-to-life, logarithmic, or artistic — without re-exporting the
models.
"""

# Mesh resolution. 48 segments x 24 rings is 1,152 quads (~2,300 triangles),
# inside the 1,500-3,000 triangle budget for a mobile scene.
SPHERE_SEGMENTS = 48
SPHERE_RINGS = 24

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
        'emission_strength': 6.0,
        'noise_scale': 9.0,
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
        'noise_scale': 12.0,
        'crater_max': 0.085,
        'bump_strength': 0.35,
    },
    {
        'key': 'venus',
        'label': 'Venus',
        'surface': 'cloudy',
        'radius_km': 6051.8,
        'rotation_hours': -5832.5,
        'axial_tilt_deg': 177.36,
        'palette': ['#B08A45', '#D8B677', '#EFDCAC', '#F8EFD6'],
        'roughness': 0.85,
        'contrast': 0.55,
        'noise_scale': 6.0,
        # No normal map: Venus is smooth cloud deck, and every map costs a
        # pure-Dart image decode on the device at load time.
        'bump_strength': 0.0,
    },
    {
        'key': 'earth',
        'label': 'Earth',
        'surface': 'terran',
        'radius_km': 6371.0,
        'rotation_hours': 23.934,
        'axial_tilt_deg': 23.44,
        'palette': ['#0A2A5E', '#12518F', '#2C6B38', '#7E7A45', '#8A7359', '#F2F4F7'],
        'roughness': 0.7,
        'noise_scale': 3.2,
        'bump_strength': 0.18,
    },
    {
        'key': 'moon',
        'label': 'Moon',
        'surface': 'cratered',
        'radius_km': 1737.4,
        'rotation_hours': 655.72,
        'axial_tilt_deg': 6.68,
        'palette': ['#2E2B28', '#5C574F', '#8E877C', '#C2BBB0'],
        'roughness': 0.98,
        'noise_scale': 10.0,
        'crater_max': 0.11,
        'maria': True,
        'bump_strength': 0.5,
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
        'noise_scale': 5.0,
        'bump_strength': 0.3,
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
        'band_count': 13.0,
        'band_turbulence': 0.9,
        'great_spot': True,
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
        'band_count': 11.0,
        'band_turbulence': 0.5,
        'contrast': 0.9,
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
        'band_count': 3.5,
        'band_turbulence': 0.12,
        'contrast': 0.4,
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
        'band_count': 6.0,
        'band_turbulence': 0.35,
        'contrast': 0.72,
        'dark_spot': True,
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
}

BODIES_BY_KEY = {b['key']: b for b in BODIES}
