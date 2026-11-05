"""Renders assets/kit/SkyDojoKit.glb as a contact sheet: assets/kit/preview.png (all props in a grid).

    Blender -b --factory-startup --python tools/blender/render_kit.py
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = "/Users/chinmayaprabhu/Documents/RBX/anime-clash"
KIT = os.path.join(ROOT, "assets", "kit")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(KIT, "SkyDojoKit.glb"))
sc = bpy.context.scene
kits = sorted((o for o in bpy.data.objects if o.name.startswith("Kit_")), key=lambda o: o.location.x)


def extent(empty):
    pts = []
    for c in empty.children_recursive:
        if c.type == "MESH":
            pts += [c.matrix_world @ v.co for v in c.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


# Re-lay them out in a grid, each scaled to fit a 10-unit cell, so big and small props read together.
COLS = 7
for i, k in enumerate(kits):
    lo, hi = extent(k)
    size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    s = 8.5 / size
    k.scale = (s, s, s)
    bpy.context.view_layer.update()
    lo, hi = extent(k)
    cx, cy = (i % COLS) * 12, -(i // COLS) * 13
    k.location += Vector((cx - (lo.x + hi.x) / 2, cy - (lo.y + hi.y) / 2, -lo.z))

bpy.ops.mesh.primitive_plane_add(size=300, location=(36, -20, 0))
ground = bpy.context.active_object
mat = bpy.data.materials.new("Ground")
mat.use_nodes = True
next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.25, 0.55, 0.18, 1)
ground.data.materials.append(mat)

world = bpy.data.worlds.new("Sky")
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.45, 0.68, 1.0, 1)
bg.inputs["Strength"].default_value = 0.9
sc.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.data.color = (1.0, 0.88, 0.74)
sun.rotation_euler = (math.radians(48), 0, math.radians(25))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 92
cam.location = (36, -88, 46)
cam.rotation_euler = (Vector((36, -20, 3)) - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.collection.objects.link(cam)
sc.camera = cam
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        sc.render.engine = engine
        break
    except TypeError:
        continue
sc.view_settings.view_transform = "Standard"
sc.render.resolution_x, sc.render.resolution_y = 2000, 1200
sc.render.filepath = os.path.join(KIT, "preview.png")
bpy.ops.render.render(write_still=True)
print("PREVIEW", [k.name for k in kits])
