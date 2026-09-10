"""Build the solar system models and export them as glTF binaries.

Run headless from the repository root:

    blender -b -P tools/blender/build_models.py -- --out assets/models

Options (after the ``--``):

    --out DIR      output directory for the .glb files
    --res N        colour map width in pixels (height is half); default 512.
                   Keep this low: three_js decodes textures in pure Dart on
                   mobile, so each doubling of width quadruples the load time.
    --only KEYS    comma separated body keys, e.g. ``earth,mars``
    --seed N       master seed; the same seed always builds the same planets

Meshes are unit spheres. Physical sizes, rotation periods and axial tilts are
written to ``assets/data/bodies.json`` so the app picks its own scale.
"""

import json
import os
import sys
import tempfile

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bodies as body_defs  # noqa: E402
import surfaces  # noqa: E402


# ---------------------------------------------------------------------------
# Scene and image helpers
# ---------------------------------------------------------------------------


def parse_args():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    options = {'out': 'assets/models', 'res': 512, 'only': None, 'seed': 20260908}
    for index in range(0, len(argv) - 1, 2):
        key = argv[index].lstrip('-')
        if key in options:
            options[key] = argv[index + 1]
    options['res'] = int(options['res'])
    options['seed'] = int(options['seed'])
    if options['only']:
        options['only'] = [k.strip() for k in str(options['only']).split(',')]
    return options


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def srgb_to_linear(values):
    """Blender stores pixels linearly; convert so saved files hold our colours."""
    values = np.clip(values, 0.0, 1.0)
    return np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)


def save_image(array, name, path, color_data=True, quality=92):
    """Write an ``(H, W, 3 or 4)`` float array to disk and return the datablock."""
    height, width = array.shape[:2]
    has_alpha = array.shape[2] == 4

    rgb = array[..., :3]
    if color_data:
        rgb = srgb_to_linear(rgb)
    alpha = array[..., 3:4] if has_alpha else np.ones((height, width, 1))

    rgba = np.concatenate([rgb, alpha], axis=-1)

    # The sphere's texture coordinates run the opposite way round to the
    # generators' longitude, so a map applied as-is comes out mirrored: east
    # ends up on the left. Flipping here fixes every body at once.
    rgba = np.fliplr(rgba)
    if not color_data:
        # A mirrored tangent-space normal map needs its sideways component
        # negated too, or the relief would light from the wrong side.
        rgba[..., 0] = 1.0 - rgba[..., 0]

    # Blender image rows run bottom to top.
    flat = np.flipud(rgba).astype(np.float32).ravel()

    image = bpy.data.images.new(name, width=width, height=height, alpha=has_alpha)
    if not color_data:
        image.colorspace_settings.name = 'Non-Color'
    image.pixels.foreach_set(flat)

    image.file_format = 'PNG' if (has_alpha or not color_data) else 'JPEG'
    image.filepath_raw = path
    bpy.context.scene.render.image_settings.quality = quality
    image.save()

    loaded = bpy.data.images.load(path)
    if not color_data:
        loaded.colorspace_settings.name = 'Non-Color'
    return loaded


def set_input(node, name, value):
    if name in node.inputs:
        node.inputs[name].default_value = value


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------


def make_sphere(name):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=body_defs.SPHERE_SEGMENTS,
        ring_count=body_defs.SPHERE_RINGS,
        radius=1.0,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.shade_smooth()
    return obj


def make_annulus(name, inner, outer, segments):
    """Flat ring in the XY plane with radial UVs (u = 0 inner, u = 1 outer)."""
    vertices = []
    faces = []
    uvs = []

    for i in range(segments):
        angle = 2.0 * np.pi * i / segments
        cos_a, sin_a = np.cos(angle), np.sin(angle)
        vertices.append((inner * cos_a, inner * sin_a, 0.0))
        vertices.append((outer * cos_a, outer * sin_a, 0.0))

    for i in range(segments):
        a = 2 * i
        b = 2 * ((i + 1) % segments)
        faces.append((a, b, b + 1, a + 1))
        uvs.extend([(0.0, 0.5), (0.0, 0.5), (1.0, 0.5), (1.0, 0.5)])

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    uv_layer = mesh.uv_layers.new(name='UVMap')
    uv_layer.data.foreach_set('uv', [c for uv in uvs for c in uv])

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------


def surface_material(spec, color_image, normal_image):
    material = bpy.data.materials.new('{}_surface'.format(spec['key']))
    material.use_nodes = True
    tree = material.node_tree
    principled = tree.nodes['Principled BSDF']

    set_input(principled, 'Metallic', 0.0)
    set_input(principled, 'Roughness', float(spec.get('roughness', 0.9)))
    set_input(principled, 'Specular IOR Level', 0.25)

    color_node = tree.nodes.new('ShaderNodeTexImage')
    color_node.image = color_image
    color_node.location = (-700, 200)

    if spec['surface'] == 'star':
        # Emissive bodies carry their colour on the emission channel so the
        # renderer does not light them from outside.
        set_input(principled, 'Base Color', (0.0, 0.0, 0.0, 1.0))
        set_input(principled, 'Emission Strength', float(spec.get('emission_strength', 5.0)))
        tree.links.new(color_node.outputs['Color'], principled.inputs['Emission Color'])
    else:
        tree.links.new(color_node.outputs['Color'], principled.inputs['Base Color'])

    if normal_image is not None:
        normal_node = tree.nodes.new('ShaderNodeTexImage')
        normal_node.image = normal_image
        normal_node.location = (-700, -200)

        normal_map = tree.nodes.new('ShaderNodeNormalMap')
        normal_map.location = (-400, -200)
        normal_map.inputs['Strength'].default_value = 1.0

        tree.links.new(normal_node.outputs['Color'], normal_map.inputs['Color'])
        tree.links.new(normal_map.outputs['Normal'], principled.inputs['Normal'])

    return material


def ring_material(image):
    material = bpy.data.materials.new('saturn_rings')
    material.use_nodes = True
    material.blend_method = 'BLEND'
    material.show_transparent_back = True
    material.use_backface_culling = False

    tree = material.node_tree
    principled = tree.nodes['Principled BSDF']
    set_input(principled, 'Metallic', 0.0)
    set_input(principled, 'Roughness', 0.85)

    texture = tree.nodes.new('ShaderNodeTexImage')
    texture.image = image
    texture.location = (-600, 0)
    texture.extension = 'EXTEND'

    tree.links.new(texture.outputs['Color'], principled.inputs['Base Color'])
    tree.links.new(texture.outputs['Alpha'], principled.inputs['Alpha'])
    return material


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------


def export(obj, path):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_image_format='AUTO',
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )


def triangle_count(obj):
    mesh = obj.data
    return sum(len(polygon.vertices) - 2 for polygon in mesh.polygons)


def build():
    options = parse_args()
    out_dir = os.path.abspath(options['out'])
    os.makedirs(out_dir, exist_ok=True)
    work_dir = tempfile.mkdtemp(prefix='solar_maps_')

    width = options['res']
    height = width // 2

    selected = [
        spec for spec in body_defs.BODIES
        if options['only'] is None or spec['key'] in options['only']
    ]

    manifest = []
    for index, spec in enumerate(selected):
        key = spec['key']
        # Bodies carrying real survey data are worth more pixels than the
        # procedural ones, whose detail is invented anyway.
        body_width = int(spec.get('resolution', width))
        body_height = body_width // 2
        print('[build] {} ({}x{})'.format(key, body_width, body_height), flush=True)
        clear_scene()

        seed = options['seed'] + index * 7919
        color, relief = surfaces.generate(spec, body_width, body_height, seed)

        color_image = save_image(
            color, '{}_color'.format(key),
            os.path.join(work_dir, '{}_color.jpg'.format(key)),
            color_data=True,
        )

        normal_image = None
        if relief is not None and spec.get('bump_strength', 0.0) > 0.0:
            from textures import height_to_normal
            normal = height_to_normal(relief, strength=float(spec['bump_strength']))
            normal_image = save_image(
                normal, '{}_normal'.format(key),
                os.path.join(work_dir, '{}_normal.png'.format(key)),
                color_data=False,
            )

        obj = make_sphere(key)
        obj.data.materials.append(surface_material(spec, color_image, normal_image))

        path = os.path.join(out_dir, '{}.glb'.format(key))
        export(obj, path)

        entry = {
            'key': key,
            'label': spec['label'],
            'model': 'assets/models/{}.glb'.format(key),
            'radiusKm': spec['radius_km'],
            'rotationHours': spec['rotation_hours'],
            'axialTiltDeg': spec['axial_tilt_deg'],
            'triangles': triangle_count(obj),
            'bytes': os.path.getsize(path),
        }
        manifest.append(entry)
        print('    -> {} ({:.2f} MB, {} triangles)'.format(
            os.path.basename(path), entry['bytes'] / 1048576.0, entry['triangles']), flush=True)

    # Saturn's rings.
    if options['only'] is None or 'saturn_rings' in (options['only'] or []) or 'saturn' in (options['only'] or []):
        spec = body_defs.RINGS
        print('[build] {}'.format(spec['key']), flush=True)
        clear_scene()

        ring_photo = spec.get('photo')
        strip = (surfaces.ring_strip_from_map(ring_photo, 1024) if ring_photo
                 else surfaces.ring_strip(1024, seed=options['seed'] + 5507))
        image = save_image(strip, 'rings_color',
                           os.path.join(work_dir, 'rings_color.png'), color_data=True)

        obj = make_annulus(spec['key'], spec['inner_radius'], spec['outer_radius'],
                           spec['segments'])
        obj.data.materials.append(ring_material(image))

        path = os.path.join(out_dir, '{}.glb'.format(spec['key']))
        export(obj, path)
        manifest.append({
            'key': spec['key'],
            'label': spec['label'],
            'model': 'assets/models/{}.glb'.format(spec['key']),
            'innerRadius': spec['inner_radius'],
            'outerRadius': spec['outer_radius'],
            'triangles': triangle_count(obj),
            'bytes': os.path.getsize(path),
        })
        print('    -> {} ({:.2f} MB)'.format(os.path.basename(path),
                                             manifest[-1]['bytes'] / 1048576.0), flush=True)

    data_path = os.path.join(os.path.dirname(out_dir), 'data', 'bodies.json')
    os.makedirs(os.path.dirname(data_path), exist_ok=True)
    with open(data_path, 'w') as handle:
        json.dump({'units': {'mesh': 'unit sphere, radius 1.0'}, 'bodies': manifest},
                  handle, indent=2)
    print('[build] wrote {}'.format(data_path))

    total = sum(entry['bytes'] for entry in manifest)
    print('[build] {} models, {:.2f} MB total'.format(len(manifest), total / 1048576.0))


if __name__ == '__main__':
    build()
