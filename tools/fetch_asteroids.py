"""Replace the generated belt with a real survey catalogue.

    python3 tools/fetch_asteroids.py

Needs outbound access to NASA's Small-Body Database. Where that is reachable
this writes the same `assets/data/asteroids.csv` from real observations, and
the app picks it up with no code change — the columns are identical.

The build environment used for this project cannot reach the archives, which
is why `build_asteroids.py` exists alongside it. Run this anywhere with open
network access, or from a CI job, to swap the modelled population for the
measured one.
"""

import csv
import json
import math
import os
import urllib.parse
import urllib.request

QUERY = 'https://ssd-api.jpl.nasa.gov/sbdb_query.api'

# Main-belt asteroids brighter than absolute magnitude 12, which is roughly
# the population large enough to have been surveyed completely.
PARAMETERS = {
    'fields': 'a,e,i,om,w,ma,epoch',
    'sb-class': 'MBA',
    'sb-cdata': json.dumps({
        'AND': ['H|LT|12'],
    }),
    'limit': '20000',
}

# Julian date of J2000, the epoch the app's mean anomalies are referred to.
J2000 = 2451545.0

DAYS_PER_YEAR = 365.256363004


def main():
    url = '{}?{}'.format(QUERY, urllib.parse.urlencode(PARAMETERS))
    with urllib.request.urlopen(url, timeout=180) as response:
        payload = json.load(response)

    rows = []
    for record in payload['data']:
        try:
            a, e, i, node, peri, mean, epoch = (float(v) for v in record[:7])
        except (TypeError, ValueError):
            continue

        # Catalogue mean anomalies are quoted at each object's own epoch;
        # carry them back to J2000 so every orbit shares one reference.
        motion = 360.0 / (DAYS_PER_YEAR * a ** 1.5)
        mean_at_j2000 = (mean + motion * (J2000 - epoch)) % 360.0

        rows.append((a, e, i, node, peri, mean_at_j2000))

    rows.sort()
    path = os.path.join('assets', 'data', 'asteroids.csv')
    with open(path, 'w') as handle:
        handle.write('a_au,e,i_deg,node_deg,peri_deg,mean_anomaly_deg\n')
        for row in rows:
            handle.write('%.4f,%.4f,%.3f,%.2f,%.2f,%.2f\n' % row)

    print('wrote {} real asteroids to {}'.format(len(rows), path))


if __name__ == '__main__':
    main()
