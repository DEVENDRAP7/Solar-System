"""Fetch higher-resolution surface maps for the bodies that have them.

Separate from ``fetch_data.py`` because these do not come from GitHub, which is
the only host the development sandbox can reach. A GitHub Actions runner has
open internet, so this is meant to be run there by the `Fetch textures`
workflow, which commits what it gets to a branch.

The maps are the Solar System Scope set — CC BY 4.0, based on NASA imagery, so
usable commercially with attribution, unlike most high-resolution planetary
texture packs. They are taken from Wikimedia Commons rather than from
solarsystemscope.com directly: that site puts bot protection in front of its
downloads, and a datacentre address such as a CI runner is served a CAPTCHA
page rather than an image.

    python3 tools/blender/fetch_hires.py [--size 4k] [--dry-run]
"""

import argparse
import json
import os
import urllib.error
import urllib.parse
import urllib.request

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')

API = 'https://commons.wikimedia.org/w/api.php'

# Wikimedia asks that automated clients identify themselves and refuses
# requests that do not.
AGENT = ('SolarSystemApp-TextureFetch/1.0 '
         '(https://github.com/DEVENDRAP7/Solar-System)')

# Local name -> the body as Solar System Scope names it on Commons.
MAPS = {
    'mercury_base.jpg': 'mercury',
    'venus_base.jpg': 'venus surface',
    'venus_clouds.jpg': 'venus atmosphere',
    'earth_base.jpg': 'earth daymap',
    'earth_night.png': 'earth nightmap',
    'earth_clouds_hi.jpg': 'earth clouds',
    'moon_base.jpg': 'moon',
    'mars_base.jpg': 'mars',
    'jupiter_base.jpg': 'jupiter',
    'saturn_base.jpg': 'saturn',
    'saturn_ring_hi.png': 'saturn ring alpha',
    'uranus_base.jpg': 'uranus',
    'neptune_base.jpg': 'neptune',
    'sun_base.jpg': 'sun',
}

# Tried in order per body. Not everything is published at every size — the
# ice giants are near featureless and only go up to 2k — so asking for 8k
# should mean "8k if it exists, otherwise the best there is", not "nothing".
LADDER = {'8k': ['8k', '4k', '2k'], '4k': ['4k', '2k'], '2k': ['2k']}

# Smallest plausible size for a real map. The failure this guards against is
# not a 404 — it is a 200 carrying a CAPTCHA or an error page, which is how a
# previous run committed eleven HTML files named .jpg.
MINIMUM_BYTES = 8 * 1024

SIGNATURES = (b'\xff\xd8\xff', b'\x89PNG\r\n\x1a\n')


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        return response.read()


def find(size, body):
    """Search Commons for one texture and return its direct URL, or None."""
    query = urllib.parse.urlencode({
        'action': 'query',
        'format': 'json',
        'generator': 'search',
        'gsrsearch': 'Solarsystemscope texture {} {}'.format(size, body),
        'gsrnamespace': '6',
        'gsrlimit': '5',
        'prop': 'imageinfo',
        'iiprop': 'url|size',
    })
    payload = json.loads(get('{}?{}'.format(API, query)).decode('utf-8'))

    pages = payload.get('query', {}).get('pages', {})
    wanted = body.replace(' ', '')
    for page in pages.values():
        title = page.get('title', '').lower().replace('_', '').replace(' ', '')
        if size not in title or wanted not in title:
            continue
        info = (page.get('imageinfo') or [{}])[0]
        if info.get('url'):
            return page['title'], info['url'], info.get('width'), info.get('height')
    return None


def looks_like_an_image(data):
    return (len(data) >= MINIMUM_BYTES
            and any(data.startswith(signature) for signature in SIGNATURES))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--size', default='4k', choices=['2k', '4k', '8k'])
    parser.add_argument('--dry-run', action='store_true',
                        help='report what would be fetched, write nothing')
    options = parser.parse_args()

    os.makedirs(DATA_DIR, exist_ok=True)
    got = 0

    for name, body in MAPS.items():
        found = None
        try:
            for size in LADDER[options.size]:
                found = find(size, body)
                if found is not None:
                    break
        except (urllib.error.URLError, urllib.error.HTTPError) as error:
            print('{:<22} search failed: {}'.format(name, error))
            continue

        if found is None:
            print('{:<22} not published at any size'.format(name))
            continue

        title, url, width, height = found
        if options.dry_run:
            print('{:<22} {}x{}  {}'.format(name, width, height, title))
            got += 1
            continue

        try:
            data = get(url)
        except (urllib.error.URLError, urllib.error.HTTPError) as error:
            print('{:<22} download failed: {}'.format(name, error))
            continue

        if not looks_like_an_image(data):
            # Refuse rather than write: a bot-protection page is a 200 too.
            print('{:<22} REFUSED: {} bytes, not an image'.format(
                name, len(data)))
            continue

        with open(os.path.join(DATA_DIR, name), 'wb') as handle:
            handle.write(data)
        got += 1
        print('{:<22} {}x{} {:>8.0f} KB  {}'.format(
            name, width, height, len(data) / 1024, title))

    print('\n{} of {} maps at {}'.format(got, len(MAPS), options.size))
    if got < len(MAPS) // 2:
        raise SystemExit(
            'too few maps fetched to be worth a commit — see the lines above')


if __name__ == '__main__':
    main()
