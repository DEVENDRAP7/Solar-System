"""Fetch higher-resolution surface maps for the bodies that have them.

Separate from ``fetch_data.py`` because these come from Solar System Scope,
which the development sandbox cannot reach — its egress only allows GitHub. A
GitHub Actions runner has open internet, so this is meant to be run there, by
the `Fetch textures` workflow, which commits what it gets to a branch.

The maps are CC BY 4.0 and based on NASA imagery, so they are usable
commercially with attribution — unlike most of the high-resolution planetary
texture packs, which are non-commercial. See `data/SOURCES.md`.

    python3 tools/blender/fetch_hires.py [--size 2k]
"""

import argparse
import os
import urllib.error
import urllib.request

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')

BASE = 'https://www.solarsystemscope.com/textures/download'

# Local name -> the stem Solar System Scope publishes it under.
MAPS = {
    'mercury_base.jpg': 'mercury',
    'venus_base.jpg': 'venus_surface',
    'venus_clouds.jpg': 'venus_atmosphere',
    'earth_base.jpg': 'earth_daymap',
    'earth_night.png': 'earth_nightmap',
    'moon_base.jpg': 'moon',
    'mars_base.jpg': 'mars',
    'jupiter_base.jpg': 'jupiter',
    'saturn_base.jpg': 'saturn',
    'uranus_base.jpg': 'uranus',
    'neptune_base.jpg': 'neptune',
    'sun_base.jpg': 'sun',
}


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'curl/8'})
    with urllib.request.urlopen(request, timeout=180) as response:
        return response.read()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--size', default='2k', choices=['2k', '4k', '8k'])
    options = parser.parse_args()

    os.makedirs(DATA_DIR, exist_ok=True)
    got = 0

    for name, stem in MAPS.items():
        extension = os.path.splitext(name)[1]
        url = '{}/{}_{}{}'.format(BASE, options.size, stem, extension)
        try:
            data = fetch(url)
        except (urllib.error.URLError, urllib.error.HTTPError) as error:
            # Not every body is published at every size, and the naming has
            # changed before. Skipping leaves the committed map in place.
            print('{:<22} skipped: {}'.format(name, error))
            continue

        with open(os.path.join(DATA_DIR, name), 'wb') as handle:
            handle.write(data)
        got += 1
        print('{:<22} {:>8.0f} KB  {}'.format(name, len(data) / 1024, url))

    print('\n{} of {} maps fetched at {}'.format(got, len(MAPS), options.size))
    if got == 0:
        raise SystemExit('nothing fetched — check the URLs above')


if __name__ == '__main__':
    main()
