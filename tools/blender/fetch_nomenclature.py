"""Fetch the IAU Gazetteer of Planetary Nomenclature.

The gazetteer is the authority on what the craters, mountains, plains and seas
of every body are called. It lives at planetarynames.wr.usgs.gov, which the
development sandbox cannot reach — its egress only allows GitHub — so this runs
on a CI runner, the same way the textures are fetched.

There is no data API, and the site took some reading to use:

* the search endpoint wants an internal target id, ``16_Moon`` rather than
  ``MOON``, which answers HTTP 500. The ids are read out of the Advanced Search
  form rather than hard-coded, since they are the site's own numbering;
* ``output=csv`` is ignored, so the results come back as a page;
* the rows are a table whose cells carry semantic classes —
  ``featureNameColumn``, ``diameterColumn`` and so on — which is what this
  reads. An earlier version matched the header text instead and silently found
  nothing;
* longitudes are not all measured the same way. Each row says which convention
  it uses, and several bodies are +West; those are converted, or half the map
  would be mirrored.

    python3 tools/blender/fetch_nomenclature.py [--min-diameter 40] [--per-body 60]
"""

import argparse
import csv
import html
import os
import re
import urllib.error
import urllib.parse
import urllib.request

AGENT = ('SolarSystemApp-Nomenclature/1.0 '
         '(https://github.com/DEVENDRAP7/Solar-System)')

BASE = 'https://planetarynames.wr.usgs.gov'

# The bodies the app draws, as the gazetteer spells them.
WANTED = [
    'Mercury', 'Venus', 'Moon', 'Mars', 'Phobos', 'Deimos',
    'Io', 'Europa', 'Ganymede', 'Callisto',
    'Mimas', 'Enceladus', 'Tethys', 'Dione', 'Rhea', 'Titan', 'Iapetus',
    'Miranda', 'Ariel', 'Titania', 'Oberon',
    'Triton', 'Proteus',
]

ROW = re.compile(r'<tr[^>]*class="[^"]*hover-highlight[^"]*"[^>]*>(.*?)</tr>',
                 re.S | re.I)
CELL = re.compile(r'<td[^>]*class="([^"]*)"[^>]*>(.*?)</td>', re.S | re.I)
TAG = re.compile(r'<[^>]+>')


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read().decode('utf-8', 'replace')


def text_of(markup):
    return ' '.join(html.unescape(TAG.sub(' ', markup)).split())


def target_ids():
    """Map body name -> the site's internal target id, read from the form."""
    page = get(BASE + '/AdvancedSearch')
    ids = {}
    for value, label in re.findall(
            r'<option[^>]*value=["\'](\d+_[^"\']+)["\'][^>]*>\s*([^<]*)', page):
        ids[html.unescape(label).strip()] = html.unescape(value)
    return ids


def cell(row, *needles):
    """The text of the first cell whose class mentions all of [needles]."""
    for classes, markup in CELL.findall(row):
        flat = classes.lower().replace(' ', '')
        if all(needle in flat for needle in needles):
            return text_of(markup)
    return ''


def number(value):
    match = re.search(r'-?\d+(?:\.\d+)?', value or '')
    return float(match.group()) if match else None


def to_east(longitude, convention):
    """Put a longitude on the east-positive scale the meshes are wrapped with.

    Several bodies are published +West. Mirroring them would put every named
    place on the wrong side of the globe, which is the kind of mistake that
    looks fine until someone who knows the Moon opens the app.
    """
    if '+west' in convention.lower().replace(' ', ''):
        longitude = -longitude
    # Wrap to -180..180.
    return (longitude + 180.0) % 360.0 - 180.0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default='assets/data/features.csv')
    parser.add_argument('--min-diameter', type=float, default=40.0)
    parser.add_argument('--per-body', type=int, default=60)
    options = parser.parse_args()

    ids = target_ids()
    missing = [body for body in WANTED if body not in ids]
    print('{} of {} target ids found'.format(len(WANTED) - len(missing),
                                             len(WANTED)))
    if missing:
        print('no id for: {}'.format(', '.join(missing)))
    print()

    found = {}
    for body in WANTED:
        target = ids.get(body)
        if not target:
            continue

        url = '{}/SearchResults?{}'.format(
            BASE, urllib.parse.urlencode({'Target': target}))
        try:
            page = get(url)
        except (urllib.error.URLError, urllib.error.HTTPError) as error:
            print('{:<10} fetch failed: {}'.format(body, error))
            continue

        rows = ROW.findall(page)
        kept = []
        conventions = set()

        for row in rows:
            name = cell(row, 'featurename')
            if not name:
                continue
            latitude = number(cell(row, 'latitude'))
            longitude = number(cell(row, 'longitude'))
            if latitude is None or longitude is None:
                continue

            convention = cell(row, 'coordsystem')
            conventions.add(convention)
            diameter = number(cell(row, 'diameter')) or 0.0
            if diameter < options.min_diameter:
                continue

            kind = cell(row, 'featuretype') or ''
            kept.append((name, latitude, to_east(longitude, convention),
                         diameter, kind.split(',')[0].strip()))

        # Biggest first, then trimmed: a label layer that names everything
        # names nothing, because it is a wall of text.
        kept.sort(key=lambda entry: -entry[3])
        kept = kept[:options.per_body]
        if kept:
            found[body] = kept

        print('{:<10} {:>5} rows -> {:>3} kept  {:<28} {}'.format(
            body, len(rows), len(kept),
            '; '.join(sorted(conventions))[:28],
            kept[0][0] if kept else '-'))

    if len(found) < 4:
        raise SystemExit('too few bodies came back to be worth a commit')

    os.makedirs(os.path.dirname(options.out), exist_ok=True)
    with open(options.out, 'w', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['body', 'name', 'lat', 'lon', 'diameter_km', 'kind'])
        for body, rows in sorted(found.items()):
            for name, lat, lon, diameter, kind in rows:
                writer.writerow([body.lower(), name,
                                 '{:.4f}'.format(lat), '{:.4f}'.format(lon),
                                 '{:.1f}'.format(diameter), kind])

    total = sum(len(rows) for rows in found.values())
    print('\nwrote {} features across {} bodies to {}'.format(
        total, len(found), options.out))


if __name__ == '__main__':
    main()
