"""Fetch the IAU Gazetteer of Planetary Nomenclature.

The gazetteer is the authority on what the craters, mountains, plains and seas
of every body are called. It lives at planetarynames.wr.usgs.gov, which the
development sandbox cannot reach — its egress only allows GitHub — so this runs
on a CI runner, the same way the textures are fetched.

    python3 tools/blender/fetch_nomenclature.py [--out assets/data/features.csv]
"""

import argparse
import csv
import io
import json
import os
import urllib.error
import urllib.parse
import urllib.request

AGENT = ('SolarSystemApp-Nomenclature/1.0 '
         '(https://github.com/DEVENDRAP7/Solar-System)')

# The bodies the app draws, under the names the gazetteer uses.
TARGETS = [
    'MERCURY', 'VENUS', 'MOON', 'MARS', 'PHOBOS', 'DEIMOS',
    'IO', 'EUROPA', 'GANYMEDE', 'CALLISTO',
    'MIMAS', 'ENCELADUS', 'TETHYS', 'DIONE', 'RHEA', 'TITAN', 'IAPETUS',
    'MIRANDA', 'ARIEL', 'TITANIA', 'OBERON',
    'TRITON', 'PROTEUS',
]

# The gazetteer's own search endpoint, asked for JSON.
SEARCH = 'https://planetarynames.wr.usgs.gov/SearchResults'

# Only features worth a label on a globe a few hundred pixels across.
MINIMUM_KM = 40.0

# Keep the count sane: a label layer is useless if it is a wall of text.
PER_BODY = 60


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        return response.read()


def fetch_target(target):
    """Return rows of (name, lat, lon, diameter_km, kind) for one body."""
    query = urllib.parse.urlencode({
        'target': target,
        'featureType': '',
        'displayColumns': ('Feature_Name,Target,Diameter,Center_Latitude,'
                           'Center_Longitude,Feature_Type'),
        'sort_asc': 'Feature_Name',
        'show': 'Fsearch',
        'output': 'csv',
    })
    raw = get('{}?{}'.format(SEARCH, query)).decode('utf-8', 'replace')

    # The endpoint answers with an HTML page when it does not like the query,
    # and an HTML page parses as CSV perfectly happily, so check the header.
    reader = csv.DictReader(io.StringIO(raw))
    if not reader.fieldnames or 'Feature_Name' not in ','.join(
            reader.fieldnames):
        raise ValueError('not the CSV we asked for: {!r}'.format(raw[:120]))

    rows = []
    for row in reader:
        try:
            diameter = float(row.get('Diameter') or 0)
            lat = float(row['Center_Latitude'])
            lon = float(row['Center_Longitude'])
        except (TypeError, ValueError, KeyError):
            continue
        name = (row.get('Feature_Name') or '').strip()
        if not name or diameter < MINIMUM_KM:
            continue
        rows.append((name, lat, lon, diameter,
                     (row.get('Feature_Type') or '').strip()))

    # Biggest first, then trimmed: the largest features are the ones worth
    # naming at the size a phone draws a planet.
    rows.sort(key=lambda r: -r[3])
    return rows[:PER_BODY]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default='assets/data/features.csv')
    options = parser.parse_args()

    found = {}
    for target in TARGETS:
        try:
            rows = fetch_target(target)
        except (urllib.error.URLError, urllib.error.HTTPError,
                ValueError) as error:
            print('{:<12} failed: {}'.format(target, error))
            continue
        if rows:
            found[target] = rows
        print('{:<12} {} features'.format(target, len(rows)))

    if len(found) < len(TARGETS) // 2:
        raise SystemExit('too few bodies came back to be worth a commit')

    os.makedirs(os.path.dirname(options.out), exist_ok=True)
    with open(options.out, 'w', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['body', 'name', 'lat', 'lon', 'diameter_km', 'kind'])
        for target, rows in sorted(found.items()):
            for name, lat, lon, diameter, kind in rows:
                writer.writerow([target.lower(), name,
                                 '{:.4f}'.format(lat), '{:.4f}'.format(lon),
                                 '{:.1f}'.format(diameter), kind])

    total = sum(len(r) for r in found.values())
    print('\nwrote {} features across {} bodies to {}'.format(
        total, len(found), options.out))


if __name__ == '__main__':
    main()
