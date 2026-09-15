# Source data

Everything the models are built from lives here. Provenance and terms differ by
dataset, so they are listed separately below.

## Public domain

| File | What it is | Source |
|------|------------|--------|
| `earth_base.jpg` | Earth surface, 2048x1024 | NASA Visible Earth, "Blue Marble" |
| `earth_clouds.png` | Cloud cover, coverage in the alpha channel | NASA Visible Earth |
| `earth_night.png` | City lights, 2048x1024, for Earth's night side | NASA Earth Observatory, "Black Marble" |
| `moon_base.jpg` | Lunar albedo, 1024x512 | NASA / JPL lunar mosaic |
| `countries.geojson` | National boundaries at 1:110m | Natural Earth |

NASA imagery is not subject to copyright. Natural Earth is public domain.

## Solar System Scope, via Wikimedia Commons (CC BY 4.0)

Mercury, Venus, Earth (day and night), the Moon, Mars, Jupiter, Saturn and the
Sun are the Solar System Scope textures at 8k or 4k, based on NASA imagery and
distributed under CC Attribution 4.0 International — usable commercially with
attribution. Fetched by the `Fetch textures` workflow.

They come from Wikimedia Commons rather than solarsystemscope.com because that
site serves a CAPTCHA to datacentre addresses, so a CI runner gets an HTML page
where it asked for a JPEG.

Uranus and Neptune are not in that set under a title the search matches, so
they are still the 1k maps listed above. Both are close to featureless in
visible light, so little is lost.

## Higher-resolution maps

Run the `Fetch textures` workflow to pull a different size on a runner — the
development sandbox can only reach GitHub — and commit it to a branch, then
rebuild the models from that branch.

Note on what was deliberately not used: the Real Solar System texture pack
(github.com/KSP-RO/RSS-Textures) has 4k and 8k maps in-repo, but is CC-BY-NC-SA
— non-commercial and share-alike — so it is not in here.

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

## Place names

`assets/data/features.csv` — the named craters, seas, mountains, canyons and
plains drawn as labels over each body. Names and positions follow the IAU
Gazetteer of Planetary Nomenclature, but this file is a **curated subset
entered by hand**, not an export of it: `tools/blender/fetch_nomenclature.py`
was written to pull the real thing on a runner and its first run failed — the
gazetteer's search endpoint wants an internal target id (`16_Moon`) rather than
a target name, and returns HTTP 500 otherwise. The positions here are good to
about a degree, which is a fraction of a pixel at the size a phone draws a
planet, but they are not authoritative. Fixing the fetcher would replace this
file wholesale.

Jupiter's Great Red Spot and Neptune's Great Dark Spot are deliberately absent:
both drift in longitude, so there is no fixed coordinate to put them at, and
where they sit in our particular surface map is not something that was
verified.
