"""Render a contact sheet of the exported models.

    blender -b -P tools/blender/preview.py -- --models assets/models --out preview.png

Useful for checking the maps without opening Blender: the models are imported
from their .glb files exactly as the app will load them.
"""

import glob
import math
import os
import sys

import bpy


def parse_args():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    options = {'models': 'assets/models', 'out': 'preview.png', 'samples': '48',
               'width': '1400', 'only': None}
    for index in range(0, len(argv) - 1, 2):
        key = argv[index].lstrip('-')
        if key in options:
            options[key] = argv[index + 1]
    return options


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def main():
    options = parse_args()
    clear_scene()

    paths = sorted(glob.glob(os.path.join(options['models'], '*.glb')))
    if options['only']:
        wanted = {k.strip() for k in options['only'].split(',')}
        paths = [p for p in paths
                 if os.path.splitext(os.path.basename(p))[0] in wanted]
    if not paths:
        raise SystemExit('no .glb files found in ' + options['models'])

    columns = min(4, len(paths))
    rows = int(math.ceil(len(paths) / columns))
    spacing = 2.6

    for index, path in enumerate(paths):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new_objects = set(bpy.data.objects) - before
        imported = [o for o in new_objects if o.type == 'MESH']

        # The importer parents meshes to an empty that carries the Y-up to
        # Z-up conversion; detach them so the placement below is absolute.
        bpy.ops.object.select_all(action='DESELECT')
        for obj in imported:
            obj.select_set(True)
        if imported:
            bpy.context.view_layer.objects.active = imported[0]
            bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
        for obj in new_objects:
            if obj.type == 'EMPTY':
                bpy.data.objects.remove(obj, do_unlink=True)

        column = index % columns
        row = index // columns
        x = (column - (columns - 1) / 2.0) * spacing
        y = ((rows - 1) / 2.0 - row) * spacing

        for obj in imported:
            # The importer leaves objects in quaternion mode, where assigning
            # rotation_euler is silently ignored.
            obj.rotation_mode = 'XYZ'
            obj.location = (x, y, 0.0)
            if 'ring' in os.path.basename(path).lower():
                # Flat geometry would be edge-on at a quarter turn.
                obj.rotation_euler = (math.radians(62.0), 0.0, math.radians(12.0))
            else:
                # Geometry comes back Z-up, so tip the sphere a quarter turn
                # to face the camera at the equator with the pole up.
                obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)

    camera_data = bpy.data.cameras.new('camera')
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = columns * spacing
    camera = bpy.data.objects.new('camera', camera_data)
    camera.location = (0.0, 0.0, 12.0)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera

    light_data = bpy.data.lights.new('key', type='SUN')
    light_data.energy = 5.0
    light = bpy.data.objects.new('key', light_data)
    light.rotation_euler = (math.radians(55.0), 0.0, math.radians(35.0))
    bpy.context.collection.objects.link(light)

    # A weak fill from the camera keeps the whole disc readable, which matters
    # when the point of the render is to inspect the surface maps.
    fill_data = bpy.data.lights.new('fill', type='SUN')
    fill_data.energy = 1.6
    fill = bpy.data.objects.new('fill', fill_data)
    fill.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.collection.objects.link(fill)

    # Emissive bodies are authored to glow in the app; at their export
    # strength they clip to white here, so neutralise it for inspection.
    for material in bpy.data.materials:
        if not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED' and 'Emission Strength' in node.inputs:
                if node.inputs['Emission Strength'].default_value > 1.0:
                    node.inputs['Emission Strength'].default_value = 1.0

    world = bpy.data.worlds.new('space')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.01, 0.012, 0.02, 1.0)
    bpy.context.scene.world = world

    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = int(options['samples'])
    scene.cycles.use_denoising = False
    scene.render.resolution_x = int(options['width'])
    scene.render.resolution_y = int(int(options['width']) * rows / columns)
    scene.render.film_transparent = False
    scene.render.filepath = os.path.abspath(options['out'])
    scene.render.image_settings.file_format = 'PNG'

    bpy.ops.render.render(write_still=True)
    print('[preview] wrote', scene.render.filepath)


if __name__ == '__main__':
    main()
