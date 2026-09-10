# Source data

Everything the models are built from lives here. Provenance and terms differ by
dataset, so they are listed separately below.

## Public domain

| File | What it is | Source |
|------|------------|--------|
| `earth_base.jpg` | Earth surface, 2048x1024 | NASA Visible Earth, "Blue Marble" |
| `earth_clouds.png` | Cloud cover, coverage in the alpha channel | NASA Visible Earth |
| `moon_base.jpg` | Lunar albedo, 1024x512 | NASA / JPL lunar mosaic |
| `countries.geojson` | National boundaries at 1:110m | Natural Earth |

NASA imagery is not subject to copyright. Natural Earth is public domain.

## Published scientific data

`moon_craters.csv` — 24,520 craters as longitude, latitude and diameter in
kilometres, largest first. Merged from two catalogues:

- **Head et al. (2010)** — 5,185 craters of 20 km and up, from Lunar Orbiter
  Laser Altimeter topography.
- **Povilaitis et al. (2018)** — 19,335 craters between 5 and 20 km.

Both were published as supplements to peer-reviewed papers.

## Planetary maps — check before releasing commercially

| File | Body |
|------|------|
| `mercury_base.jpg`, `mercury_bump.jpg` | Mercury surface and topography |
| `venus_base.jpg`, `venus_bump.jpg` | Venus surface (radar) and topography |
| `mars_base.jpg`, `mars_bump.jpg` | Mars surface and topography |
| `jupiter_base.jpg` | Jupiter |
| `saturn_base.jpg`, `saturn_ring.jpg` | Saturn and its rings |
| `uranus_base.jpg`, `neptune_base.jpg` | Uranus, Neptune |
| `sun_base.jpg` | The Sun's photosphere |

These come from the [threex.planets](https://github.com/jeromeetienne/threex.planets)
repository, which is MIT licensed and states that its images are based on data
from Planet Pixel Emporium. The underlying maps were assembled by James
Hastings-Trew from spacecraft imagery, and his terms govern them rather than
the repository's licence.

**They are fine for development and personal use. Before publishing the app
commercially, either confirm permission for these maps or replace them.** The
drop-in replacement is the Solar System Scope texture set, which is CC BY 4.0
and so allows commercial use with attribution. Swapping is a matter of putting
files with the same names in this folder and rebuilding — no code changes.

## Refreshing

```bash
/usr/bin/python3 tools/blender/fetch_data.py
```

The files are committed so a build needs no network access.
