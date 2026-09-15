"""Fetch the IAU Gazetteer of Planetary Nomenclature.

The gazetteer is the authority on what the craters, mountains, plains and seas
of every body are called. It lives at planetarynames.wr.usgs.gov, which the
development sandbox cannot reach — its egress only allows GitHub — so this runs
on a CI runner, the same way the textures are fetched.

There is no data API. The search endpoint takes an internal target id of the
form ``16_Moon`` and answers with a results page; a target *name* gets an HTTP
500, and asking for ``output=csv`` is ignored. So this reads the ids out of the
search form itself rather than hard-coding them — they are the site's own
numbering and would otherwise be a guess that breaks silently — and parses the
results table by matching its header, rather than by column position.

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

# Header cells we need, and the key each maps to.
COLUMNS = {
    'feature name': 'name',
    'clean feature name': 'name',
    'diameter': 'diameter',
    'center latitude': 'lat',
    'center longitude': 'lon',
    'feature type': 'kind',
}

TAG = re.compile(r'<[^>]+>')


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read().decode('utf-8', 'replace')


def text_of(cell):
    """Strip a table cell down to its text."""
    return html.unescape(TAG.sub(' ', cell)).replace('\xa0', ' ').strip()


def target_ids():
    """Map body name -> the site's internal target id, read from the form."""
    page = get(BASE + '/AdvancedSearch')
    ids = {}
    for value, label in re.findall(
            r'<option[^>]*value=["\'](\d+_[^"\']+)["\'][^>]*>\s*([^<]*)', page):
        name = html.unescape(label).strip()
        # The same page carries a references select whose values look alike;
        # those labels are citations, not body names, and never match.
        if name and name.lower() in {b.lower() for b in WANTED}:
            ids[name] = html.unescape(value)
    return ids


def parse_results(page):
    """Rows from the results table, keyed by what its header says they are."""
    rows = []
    for table in re.findall(r'<table[\s\S]*?</table>', page, re.I):
        trs = re.findall(r'<tr[\s\S]*?</tr>', table, re.I)
        if len(trs) < 2:
            continue

        header = [text_of(c).lower() for c in
                  re.findall(r'<t[hd][\s\S]*?</t[hd]>', trs[0], re.I)]
        index = {}
        for position, cell in enumerate(header):
            key = COLUMNS.get(cell)
            if key and key not in index:
                index[key] = position
        if not {'name', 'lat', 'lon'} <= set(index):
            continue

        for tr in trs[1:]:
            cells = [text_of(c) for c in
                     re.findall(r'<t[hd][\s\S]*?</t[hd]>', tr, re.I)]
            if len(cells) <= max(index.values()):
                continue
            rows.append({key: cells[position]
                         for key, position in index.items()})
        if rows:
            return rows, header
    return rows, []


def number(value):
    try:
        return float(re.sub(r'[^0-9.eE+-]', '', value))
    except (TypeError, ValueError):
        return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default='assets/data/features.csv')
    parser.add_argument('--min-diameter', type=float, default=40.0)
    parser.add_argument('--per-body', type=int, default=60)
    options = parser.parse_args()

    ids = target_ids()
    print('found {} of {} target ids: {}\n'.format(
        len(ids), len(WANTED), ', '.join(sorted(ids))))
    missing = [b for b in WANTED if b not in ids]
    if missing:
        print('no id for: {}\n'.format(', '.join(missing)))
    if not ids:
        raise SystemExit('the search form gave up no target ids at all')

    found = {}
    for body, target in sorted(ids.items()):
        url = '{}/SearchResults?{}'.format(
            BASE, urllib.parse.urlencode({'Target': target}))
        try:
            page = get(url)
        except (urllib.error.URLError, urllib.error.HTTPError) as error:
            print('{:<12} fetch failed: {}'.format(body, error))
            continue

        rows, header = parse_results(page)
        if not rows:
            print('{:<12} no table found in {} bytes'.format(body, len(page)))
            continue

        kept = []
        for row in rows:
            lat = number(row.get('lat', ''))
            lon = number(row.get('lon', ''))
            diameter = number(row.get('diameter', '')) or 0.0
            name = row.get('name', '').strip()
            if not name or lat is None or lon is None:
                continue
            if diameter < options.min_diameter:
                continue
            kept.append((name, lat, lon, diameter, row.get('kind', '')))

        # Biggest first, then trimmed: a label layer that names everything
        # names nothing, because it is a wall of text.
        kept.sort(key=lambda r: -r[3])
        kept = kept[:options.per_body]
        if kept:
            found[body] = kept
        print('{:<12} {:>5} rows -> {:>3} kept   (e.g. {})'.format(
            body, len(rows), len(kept), kept[0][0] if kept else '-'))

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

    total = sum(len(r) for r in found.values())
    print('\nwrote {} features across {} bodies to {}'.format(
        total, len(found), options.out))


if __name__ == '__main__':
    main()
