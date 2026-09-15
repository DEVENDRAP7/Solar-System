"""Find out how the IAU gazetteer wants to be asked.

The development sandbox cannot reach planetarynames.wr.usgs.gov, so this runs
on a CI runner and prints what the site actually returns. Read the workflow log
and write the real fetcher from what it says, rather than guessing at the query
and spending a run on each guess.
"""

import re
import urllib.error
import urllib.request

AGENT = ('SolarSystemApp-Nomenclature/1.0 '
         '(https://github.com/DEVENDRAP7/Solar-System)')

BASE = 'https://planetarynames.wr.usgs.gov'


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.status, response.read().decode('utf-8', 'replace')


def show(label, url, head=600):
    print('\n' + '=' * 72)
    print('{}\n{}'.format(label, url))
    print('-' * 72)
    try:
        status, body = get(url)
    except urllib.error.HTTPError as error:
        print('HTTP {} {}'.format(error.code, error.reason))
        try:
            print(error.read().decode('utf-8', 'replace')[:head])
        except Exception:
            pass
        return None
    except Exception as error:
        print('failed: {!r}'.format(error))
        return None

    print('HTTP {}  {} bytes'.format(status, len(body)))
    print(body[:head].replace('\r', ''))
    return body


def main():
    # 1. The search form, for the internal target ids.
    page = show('SEARCH FORM', BASE + '/AdvancedSearch', head=300)
    if page:
        selects = re.findall(
            r'<select[^>]*name=["\']([^"\']+)["\'][^>]*>(.*?)</select>',
            page, re.S | re.I)
        print('\n--- form selects ---')
        for name, inner in selects:
            options = re.findall(
                r'<option[^>]*value=["\']([^"\']*)["\'][^>]*>\s*([^<]*)',
                inner, re.I)
            print('\nselect {!r}: {} options'.format(name, len(options)))
            for value, text in options[:40]:
                print('    {:<22} {}'.format(value, text.strip()[:40]))

        print('\n--- form inputs ---')
        for match in re.findall(r'<input[^>]*>', page, re.I)[:40]:
            print('   ', match.strip()[:150])

        forms = re.findall(r'<form[^>]*>', page, re.I)
        print('\n--- form tags ---')
        for form in forms:
            print('   ', form.strip()[:200])

    # 2. Candidate result queries, to see which shape it accepts.
    for label, url in [
        ('by target NAME', BASE + '/SearchResults?Target=MOON'),
        ('by target ID 16_Moon', BASE + '/SearchResults?Target=16_Moon'),
        ('by target ID plus csv',
         BASE + '/SearchResults?Target=16_Moon&output=csv'),
        ('nomenclature feature list',
         BASE + '/nomenclature/SearchResults?Target=16_Moon'),
        ('GIS downloads page', BASE + '/GIS_Downloads'),
    ]:
        show(label, url, head=500)


if __name__ == '__main__':
    main()
