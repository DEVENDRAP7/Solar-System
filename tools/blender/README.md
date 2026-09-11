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

| Body | Built from |
|------|-----------|
| Earth | NASA surface imagery, its cloud deck composited from the alpha channel, and national borders rasterised from Natural Earth polygons |
| Moon | NASA lunar albedo, with relief stamped from 24,520 catalogued craters at their real positions and diameters |
| Mercury, Mars | Surface maps with their real topography as relief |
| Jupiter, Saturn, Uranus, Neptune | Surface maps |
| Sun | A photosphere map, exported on the emission channel |
| Saturn's rings | A radial slice of the real ring system, transparency taken from its brightness |
| Venus | Generated cloud deck — see below |
| The twenty moons | Generated surfaces at a quarter the map size, with palettes following how each one looks: Io's sulphur yellows, Europa's clean ice, Callisto's dark crust, Titan's orange haze |

Every body is drawn from real imagery, with one deliberate exception. Venus is
permanently covered by cloud, so the only maps of its surface are radar. A view
from space would never show that ground, so Venus is drawn as its cloud deck: a
pale, almost featureless cream disc, which is what it actually looks like. The
radar surface is in `data/venus_base.jpg` if the ground is wanted instead.

Some of the maps arrive far more colourful than the body really is — the
Mercury map is strongly orange when Mercury is close to grey. The structure in
them is genuine, so rather than throw it away, `sources.tone()` pulls the
chroma back toward a measured tint and sets the overall brightness from the
body's albedo. Older maps also have crater shadows painted into the albedo,
which fight the real relief lit on top; `soften` blurs those out so the shading
comes from the topography.

Terms differ between datasets. `data/SOURCES.md` covers each one, and flags
which need checking before a commercial release.

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
