"""Generate the main-belt asteroid population.

Run from the repository root:

    python3 tools/build_asteroids.py

Writes `assets/data/asteroids.csv`, which the app reads and propagates with the
same Kepler solver it uses for the planets — so the belt orbits properly rather
than spinning as a decoration.

The belt's structure is real. Its gaps are not invented: each one sits where an
asteroid's orbital period would form a whole-number ratio with Jupiter's, so
Jupiter tugs it at the same point every few orbits until it is cleared out.
Those positions come out of the resonance arithmetic below, and land on the
observed Kirkwood gaps at 2.06, 2.50, 2.82, 2.96 and 3.28 AU.

Individual asteroids are drawn from the belt's measured distributions rather
than from a catalogue: the survey archives are not reachable from the build
environment. `fetch_asteroids.py` replaces this file with the real thing, with
the same columns, wherever the network allows.
"""

import math
import os
import random

# Jupiter's semi-major axis, which sets where every resonance falls.
JUPITER_AU = 5.202887

# Mean-motion resonances that clear the gaps, as (asteroid orbits : Jupiter's).
RESONANCES = ((4, 1), (3, 1), (5, 2), (7, 3), (2, 1))

# How wide each gap is, in AU. The stronger low-order resonances clear more.
GAP_WIDTH = {(4, 1): 0.015, (3, 1): 0.020, (5, 2): 0.015, (7, 3): 0.010,
             (2, 1): 0.025}

INNER_EDGE = 2.06
OUTER_EDGE = 3.28

COUNT = 6000
SEED = 20260910


def resonance_axis(orbits, jupiter_orbits):
    """Semi-major axis whose period is `jupiter_orbits/orbits` of Jupiter's.

    Kepler's third law gives the period from the axis, so inverting it gives
    the axis at which the periods form the ratio.
    """
    period_ratio = jupiter_orbits / orbits
    return JUPITER_AU * period_ratio ** (2.0 / 3.0)


def density(axis, gaps):
    """Relative number of asteroids near `axis`.

    A broad hump across the belt, with a notch cut at each resonance.
    """
    if axis < INNER_EDGE or axis > OUTER_EDGE:
        return 0.0

    # The belt is fullest through its middle and thins toward both edges.
    centre = (INNER_EDGE + OUTER_EDGE) / 2.0
    span = (OUTER_EDGE - INNER_EDGE) / 2.0
    value = 1.0 - 0.55 * ((axis - centre) / span) ** 2

    # Denser bands between the gaps, where families of asteroids collect.
    value *= 1.0 + 0.35 * math.cos((axis - 2.35) * 9.0)

    for position, width in gaps:
        value *= 1.0 - 0.97 * math.exp(-((axis - position) ** 2) / (2 * width ** 2))

    return max(value, 0.0)


def rayleigh(rng, scale, limit):
    """Draw from a Rayleigh distribution, which is how eccentricities and
    inclinations are spread through a relaxed population."""
    while True:
        value = scale * math.sqrt(-2.0 * math.log(1.0 - rng.random()))
        if value <= limit:
            return value


def main():
    rng = random.Random(SEED)
    gaps = [(resonance_axis(*ratio), GAP_WIDTH[ratio]) for ratio in RESONANCES]

    print('Kirkwood gaps from resonance with Jupiter:')
    for ratio, (position, _) in zip(RESONANCES, gaps):
        print('  {}:{} resonance -> {:.3f} AU'.format(ratio[0], ratio[1], position))

    peak = max(density(INNER_EDGE + i * (OUTER_EDGE - INNER_EDGE) / 2000.0, gaps)
               for i in range(2001))

    rows = []
    while len(rows) < COUNT:
        axis = rng.uniform(INNER_EDGE, OUTER_EDGE)
        if rng.random() * peak > density(axis, gaps):
            continue

        rows.append((
            axis,
            rayleigh(rng, 0.105, 0.35),          # eccentricity, mean about 0.13
            rayleigh(rng, 8.5, 34.0),            # inclination in degrees
            rng.uniform(0.0, 360.0),             # longitude of ascending node
            rng.uniform(0.0, 360.0),             # argument of perihelion
            rng.uniform(0.0, 360.0),             # mean anomaly at the epoch
        ))

    rows.sort()
    path = os.path.join('assets', 'data', 'asteroids.csv')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as handle:
        handle.write('a_au,e,i_deg,node_deg,peri_deg,mean_anomaly_deg\n')
        for row in rows:
            handle.write('%.4f,%.4f,%.3f,%.2f,%.2f,%.2f\n' % row)

    axes = [row[0] for row in rows]
    print('\nwrote {} asteroids to {} ({:.0f} KB)'.format(
        len(rows), path, os.path.getsize(path) / 1024))
    print('semi-major axis {:.2f} to {:.2f} AU'.format(min(axes), max(axes)))
    print('mean eccentricity {:.3f}, mean inclination {:.1f} degrees'.format(
        sum(r[1] for r in rows) / len(rows),
        sum(r[2] for r in rows) / len(rows)))


if __name__ == '__main__':
    main()
