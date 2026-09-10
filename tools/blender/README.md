# Model pipeline

Generates the celestial body models in `assets/models/` as glTF binaries.

## Running it

```bash
blender -b -P tools/blender/build_models.py -- --out assets/models --res 1024
```

| Option | Default | Meaning |
|--------|---------|---------|
| `--out` | `assets/models` | Output directory for the `.glb` files |
| `--res` | `512` | Colour map width in pixels; height is half. Bodies may override it — Earth and the Moon are built at 2048 |
| `--only` | all | Comma separated keys, e.g. `earth,mars` |
| `--seed` | `20260908` | Master seed — the same seed rebuilds the same planets |

Keep `--res` low. `three_js` decodes textures with `package:image` in pure
Dart on mobile, one isolate per image, so every doubling of the map width
quadruples the decode work the phone has to do before a body appears. At 512
the whole set is under 2 MB and decodes quickly; at 1024 the app spent minutes
on its loading screen.

A full run takes about 20 seconds and needs no GPU. Blender 4.0 or newer, with
numpy available to its Python (official builds bundle it; on Debian and Ubuntu
packages install `python3-numpy`).

To look at the result without opening Blender:

```bash
blender -b -P tools/blender/preview.py -- --models assets/models --out preview.png
```

## How the surfaces are made

Each body gets an equirectangular colour map, and bodies with relief also get a
tangent-space normal map derived from a height field. Both are embedded in the
`.glb`, so the app loads one file per body and needs no side-car textures.

Noise is evaluated in three dimensions at points on the unit sphere rather than
across the flat image. That means patterns are continuous across the longitude
seam — there is no visible join where the map wraps.

| Surface | Used by | Built from |
|---------|---------|-----------|
| `earth_real` | Earth | NASA surface imagery, its cloud deck composited from the alpha channel, and national borders rasterised from Natural Earth polygons |
| `moon_real` | Moon | NASA lunar albedo, with relief stamped from 24,520 catalogued craters at their real positions and diameters |
| `star` | Sun | Fine granulation over broader convection cells, biased bright, with a few cooler regions. Exported on the emission channel |
| `cratered` | Mercury | Fractal base terrain plus a generated crater field |
| `cloudy` | Venus | Domain-warped noise for swirling cloud decks, low contrast |
| `dusty` | Mars | Fractal terrain, dark low-albedo regions, polar caps, light cratering |
| `banded` | Jupiter, Saturn, Uranus, Neptune | Latitude bands displaced by turbulence, with noise stretched along longitude so detail smears into the bands. Jupiter adds the Great Red Spot, Neptune a dark spot |

Earth and the Moon are built from real survey data, so they are the actual
Earth and the actual Moon rather than something that resembles them. The other
bodies have no comparable public imagery at a useful resolution here, so their
surfaces are generated.

### The lunar craters

Every crater of 4 km and larger from the merged Head and Povilaitis catalogues
is stamped into the height field at its cataloged position, sized from its
real diameter. Each contributes a bowl, a raised rim and a skirt of ejecta,
with depth falling off as the crater widens — which is why the big basins come
out as flat plains rather than deep holes. They are applied largest first, so
later craters cut into the floors of the basins that came before them.

At 2048x1024 one pixel spans about 5 km at the equator, so craters below
roughly 15 km across contribute texture rather than a resolved bowl. Raising
`resolution` for the Moon in `bodies.py` sharpens them further at the cost of
file size.

### Orientation

Source imagery, the crater catalogue and the country polygons all use the same
convention: longitude increasing east, latitude increasing north. The sphere's
texture coordinates run the other way round, so maps are mirrored once on
export — and tangent-space normal maps have their sideways component negated
to match. `data/SOURCES.md` lists where each dataset comes from.

Saturn's rings are a separate flat annulus with a generated colour and alpha
strip mapped radially, exported with alpha blending.

## Scale

**Every mesh is a unit sphere with radius 1.0.** True radii, rotation periods
and axial tilts are written to `assets/data/bodies.json` instead, so the app
chooses its own scale at runtime.

This is deliberate. A solar system at true scale is mostly empty space — Neptune
is 4.5 billion km out while Earth is 12,742 km across — so any usable
visualisation compresses distance and size non-linearly. Baking one particular
scale into the geometry would force a re-export every time that choice changed.

Axial tilt is likewise left to the app: the meshes are untilted, and
`axialTiltDeg` in the manifest says how far to rotate each one.

Note that inside the `.glb` files the pole is on **+Y**, following the glTF
convention, even though Blender works in Z-up.

## Orbits

Orbital paths are not exported as models. They depend on the same scale choice
as everything else, and a ring drawn from orbital elements at runtime costs
almost nothing and stays correct when the scale changes.

## Files

| File | Role |
|------|------|
| `bodies.py` | Per-body definitions: palettes, surface type, physical data |
| `textures.py` | Noise, colour ramps, crater fields, height-to-normal conversion |
| `surfaces.py` | One generator per surface type |
| `build_models.py` | Meshes, materials, export, and the manifest |
| `preview.py` | Contact sheet renderer for checking the output |
