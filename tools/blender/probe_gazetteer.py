"""Show how one gazetteer result is marked up.

The sandbox cannot reach planetarynames.wr.usgs.gov, so this runs on a CI
runner and prints what the site returns. Read the workflow log and write the
parser from that, rather than guessing and spending a run on each guess.

Known so far: the search endpoint wants an internal target id, which the
Advanced Search form gives up (Mimas is 70_Mimas); a target name answers 500;
output=csv is ignored; the results are not in a table; and the class
'nomen-name' is the site's logo, not a result. What remains is the shape of a
row, so this prints the markup around a feature known to be on the page.
"""

import html
import re
import urllib.request

AGENT = ('SolarSystemApp-Nomenclature/1.0 '
         '(https://github.com/DEVENDRAP7/Solar-System)')

BASE = 'https://planetarynames.wr.usgs.gov'

# Small enough to read in a log, and Herschel is certainly on it.
TARGET = '70_Mimas'
KNOWN = 'Herschel'


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read().decode('utf-8', 'replace')


def main():
    page = get('{}/SearchResults?Target={}'.format(BASE, TARGET))
    print('{}: {} bytes'.format(TARGET, len(page)))

    hits = [m.start() for m in re.finditer(re.escape(KNOWN), page)]
    print('{!r} at {}'.format(KNOWN, hits))
    if not hits:
        raise SystemExit('the known feature is not on the page')

    # The last hit is the one inside the results, not a nav link.
    for where in hits:
        print('\n' + '=' * 72)
        print('MARKUP AROUND OFFSET {}'.format(where))
        print('=' * 72)
        print(page[max(0, where - 2500):where + 2500])


if __name__ == '__main__':
    main()
