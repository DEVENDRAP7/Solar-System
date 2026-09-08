# Model pipeline

Generates the celestial body models in `assets/models/` as glTF binaries.

## Running it

```bash
blender -b -P tools/blender/build_models.py -- --out assets/models --res 1024
```

| Option | Default | Meaning |
|--------|---------|---------|
| `--out` | `assets/models` | Output directory for the `.glb` files |
| `--res` | `512` | Colour map width in pixels; height is half |
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
| `star` | Sun | Fine granulation over broader convection cells, biased bright, with a few cooler regions. Exported on the emission channel |
| `cratered` | Mercury, Moon | Fractal base terrain plus a crater field; craters are placed by size so large basins sit under later small ones. The Moon adds dark, smooth maria |
| `cloudy` | Venus | Domain-warped noise for swirling cloud decks, low contrast |
| `terran` | Earth | Fractal continents above a sea level threshold, ocean depth shading, aridity-driven land colour, and snow that follows both elevation and latitude |
| `dusty` | Mars | Fractal terrain, dark low-albedo regions, polar caps, light cratering |
| `banded` | Jupiter, Saturn, Uranus, Neptune | Latitude bands displaced by turbulence, with noise stretched along longitude so detail smears into the bands. Jupiter adds the Great Red Spot, Neptune a dark spot |

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
