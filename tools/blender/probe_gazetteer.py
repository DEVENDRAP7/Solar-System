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
import urllib.request

AGENT = ('SolarSystemApp-Nomenclature/1.0 '
         '(https://github.com/DEVENDRAP7/Solar-System)')

BASE = 'https://planetarynames.wr.usgs.gov'

# Small enough to read in a log, and it certainly has named features.
SAMPLE = ('Mimas', '43_Mimas')
KNOWN = 'Herschel'


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read().decode('utf-8', 'replace')


def main():
    body, target = SAMPLE
    page = get('{}/SearchResults?Target={}'.format(BASE, target))
    print('{}: {} bytes'.format(body, len(page)))

    for tag in ('table', 'tbody', 'tr', 'td', 'th', 'ul', 'li', 'article',
                'section'):
        print('  <{:<8} {}'.format(tag + '>', len(
            re.findall(r'<' + tag + r'[\s>]', page, re.I))))

    print('\n--- classes used most ---')
    classes = re.findall(r'class=["\']([^"\']+)["\']', page)
    counts = {}
    for value in classes:
        for name in value.split():
            counts[name] = counts.get(name, 0) + 1
    for name, count in sorted(counts.items(), key=lambda kv: -kv[1])[:25]:
        print('  {:<34} {}'.format(name, count))

    where = page.find(KNOWN)
    print('\n--- markup around {!r} (found at {}) ---'.format(KNOWN, where))
    if where > 0:
        print(page[max(0, where - 2200):where + 2200])

    # Whatever wraps a row, the coordinates are distinctive: a signed decimal
    # followed by a degree sign or the word N/S. Show what surrounds one.
    match = re.search(r'-?\d+\.\d+\s*(?:&deg;|°|N|S)\b', page)
    print('\n--- markup around the first coordinate ---')
    if match:
        start = match.start()
        print(page[max(0, start - 1500):start + 1500])
    else:
        print('no coordinate-looking text found')


if __name__ == '__main__':
    main()
