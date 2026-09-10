# Source data

Everything in this folder is public domain or equivalent, and is used to build
the models in `assets/models/`.

## Imagery

| File | What it is | Source |
|------|------------|--------|
| `earth_base.jpg` | Earth surface, 2048x1024 equirectangular | NASA Visible Earth "Blue Marble" |
| `earth_clouds.png` | Cloud cover, coverage stored in the alpha channel | NASA Visible Earth |
| `moon_base.jpg` | Lunar albedo, 1024x512 equirectangular | NASA / JPL lunar mosaic |

NASA imagery is not subject to copyright and may be used without restriction.

## Coastlines and borders

| File | What it is | Source |
|------|------------|--------|
| `countries.geojson` | National boundaries at 1:110m | Natural Earth |

Natural Earth is in the public domain.

## Lunar craters

`moon_craters.csv` holds 24,520 craters as longitude, latitude and diameter in
kilometres, sorted largest first. It merges two published catalogues:

- **Head et al. (2010)** — 5,185 craters of 20 km and larger, from Lunar
  Orbiter Laser Altimeter topography.
- **Povilaitis et al. (2018)** — 19,335 craters between 5 and 20 km, from the
  same survey programme.

Both were published as supplements to peer-reviewed papers and are used here as
factual data. The merged file is produced by `fetch_data.py`.

## Refreshing

```bash
/usr/bin/python3 tools/blender/fetch_data.py
```

The files are committed so that a build needs no network access.
