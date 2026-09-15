"""Find out how the IAU gazetteer lays out its results.

The sandbox cannot reach planetarynames.wr.usgs.gov, so this runs on a CI
runner and prints what the site actually returns. Read the workflow log and
write the parser from what it says, rather than guessing and spending a run on
each guess.

Target ids are already known to work: Target=16_Moon answers 200, a target
name answers 500. What is not known is how a row of results is marked up.
"""

import html
import re
import urllib.parse
import urllib.request

AGENT = ('SolarSystemApp-Nomenclature/1.0 '
         '(https://github.com/DEVENDRAP7/Solar-System)')

BASE = 'https://planetarynames.wr.usgs.gov'

# Small enough to read in a log, and it certainly has named features.
SAMPLE = 'Mimas'


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read().decode('utf-8', 'replace')


def target_ids():
    """Map body name -> the site's internal target id, read from the form."""
    page = get(BASE + '/AdvancedSearch')
    ids = {}
    for value, label in re.findall(
            r'<option[^>]*value=["\'](\d+_[^"\']+)["\'][^>]*>\s*([^<]*)', page):
        ids[html.unescape(label).strip()] = html.unescape(value)
    return ids


def main():
    ids = target_ids()
    print('--- target ids that look like bodies ---')
    for name in sorted(ids):
        if name and name[0].isupper() and len(name) < 14 and ' ' not in name:
            print('  {:<16} {}'.format(name, ids[name]))

    target = ids.get(SAMPLE)
    print('\nusing {} -> {!r}'.format(SAMPLE, target))
    if not target:
        raise SystemExit('no id for the sample body')

    page = get('{}/SearchResults?Target={}'.format(
        BASE, urllib.parse.quote(target)))
    print('{}: {} bytes'.format(SAMPLE, len(page)))

    for marker in ('nomen-name', 'nomen', 'Herschel'):
        hits = [m.start() for m in re.finditer(re.escape(marker), page)]
        print('  {!r}: {} hits'.format(marker, len(hits)))

    # One whole result, whatever wraps it.
    where = page.find('nomen-name')
    print('\n--- markup from the first nomen-name ---')
    if where > 0:
        print(page[max(0, where - 1200):where + 3000])
    else:
        print('nomen-name not present; dumping the middle of the page')
        middle = len(page) // 2
        print(page[middle:middle + 3000])


if __name__ == '__main__':
    main()
