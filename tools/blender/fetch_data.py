"""Re-download the source data used to build the models.

Run from the repository root:

    python3 tools/blender/fetch_data.py

The results are committed, so this only needs running to refresh them. See
`data/SOURCES.md` for what each file is and where it comes from.
"""

import csv
import io
import os
import urllib.request

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')

IMAGERY = {
    'earth_base.jpg':
        'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/'
        'textures/planets/earth_atmos_2048.jpg',
    'earth_clouds.png':
        'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/'
        'textures/planets/earth_clouds_1024.png',
    'moon_base.jpg':
        'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/'
        'textures/planets/moon_1024.jpg',
    'countries.geojson':
        'https://raw.githubusercontent.com/nvkelso/natural-earth-vector/'
        'master/geojson/ne_110m_admin_0_countries.geojson',
}

# Surface maps for the other bodies. See SOURCES.md on their terms before
# releasing commercially.
PLANET_BASE = ('https://raw.githubusercontent.com/jeromeetienne/threex.planets/'
               'master/images')

PLANETS = {
    'mercury_base.jpg': 'mercurymap.jpg',
    'mercury_bump.jpg': 'mercurybump.jpg',
    'venus_base.jpg': 'venusmap.jpg',
    'venus_bump.jpg': 'venusbump.jpg',
    'mars_base.jpg': 'marsmap1k.jpg',
    'mars_bump.jpg': 'marsbump1k.jpg',
    'jupiter_base.jpg': 'jupitermap.jpg',
    'saturn_base.jpg': 'saturnmap.jpg',
    'saturn_ring.jpg': 'saturnringcolor.jpg',
    'uranus_base.jpg': 'uranusmap.jpg',
    'neptune_base.jpg': 'neptunemap.jpg',
    'sun_base.jpg': 'sunmap.jpg',
}

CRATERS = {
    'lroc':
        'https://raw.githubusercontent.com/silburt/DeepMoon/master/'
        'catalogues/LROCCraters.csv',
    'head':
        'https://raw.githubusercontent.com/silburt/DeepMoon/master/'
        'catalogues/HeadCraters.csv',
}


def fetch(url):
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read()


def main():
    os.makedirs(DATA_DIR, exist_ok=True)

    for name, url in IMAGERY.items():
        data = fetch(url)
        with open(os.path.join(DATA_DIR, name), 'wb') as handle:
            handle.write(data)
        print('{:<22} {:>8.0f} KB'.format(name, len(data) / 1024))

    for name, remote in PLANETS.items():
        data = fetch('{}/{}'.format(PLANET_BASE, remote))
        with open(os.path.join(DATA_DIR, name), 'wb') as handle:
            handle.write(data)
        print('{:<22} {:>8.0f} KB'.format(name, len(data) / 1024))

    rows = []
    lroc = csv.DictReader(io.StringIO(fetch(CRATERS['lroc']).decode()))
    for row in lroc:
        rows.append((float(row['Long']), float(row['Lat']),
                     float(row['Diameter (km)'])))

    head = csv.DictReader(io.StringIO(fetch(CRATERS['head']).decode()))
    for row in head:
        rows.append((float(row['Lon']), float(row['Lat']),
                     float(row['Diam_km'])))

    # Largest first, so the height field lays down the old basins before the
    # smaller craters that sit inside them.
    rows.sort(key=lambda row: -row[2])

    path = os.path.join(DATA_DIR, 'moon_craters.csv')
    with open(path, 'w') as handle:
        handle.write('lon,lat,diameter_km\n')
        for lon, lat, diameter in rows:
            handle.write('%.4f,%.4f,%.3f\n' % (lon, lat, diameter))

    print('{:<22} {:>8.0f} KB  ({} craters)'.format(
        'moon_craters.csv', os.path.getsize(path) / 1024, len(rows)))


if __name__ == '__main__':
    main()
