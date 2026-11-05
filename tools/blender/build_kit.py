"""Builds the Sky Dojo Island world kit (docs/POLISH_BIBLE.md §3) and exports it as one GLB for a single
Studio 3D import.

    Blender -b --factory-startup --python tools/blender/build_kit.py        # or exec() it in a live Blender

Sources:
  * CC0 Quaternius Stylized Nature MegaKit + Fantasy Props MegaKit (already downloaded by the Elemental Kaijus
    pipeline in ~/Documents/RBX/kaiju-pipeline/packs), recoloured for the island with its kitbash helpers.
  * Custom pieces built here (torii, stone lantern, altar body, portal ring, cloud puffs, island rocks).

Every prop is an empty named Kit_<Name> holding one mesh per role, named <Name>__<Role> (Bark, Leaves, Stone,
Lacquer, Gold...). One texture per role. The game (src/shared/Kit.lua) finds props by name, scales them to the
size it wants and makes leaf/flower roles alpha-cut. Output: assets/kit/SkyDojoKit.glb + assets/kit/preview.png.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = "/Users/chinmayaprabhu/Documents/RBX/anime-clash"
PIPE = os.path.expanduser("~/Documents/RBX/kaiju-pipeline")
OUT = os.path.join(ROOT, "assets", "kit")

# Borrow the kitbash helpers without running its recipes ("--" with a name that matches none).
_argv = sys.argv
sys.argv = [_argv[0], "--", "__none__"]
K = {"__file__": os.path.join(PIPE, "kitbash.py"), "__name__": "kitbash"}
exec(compile(open(os.path.join(PIPE, "kitbash.py")).read(), "kitbash.py", "exec"), K)
sys.argv = _argv
K["TMP"] = os.path.join(OUT, "tex")
NAT, PROPS = K["NAT"], K["PROPS"]
recolor, retex, load, ground, apply, join = K["recolor"], K["retex"], K["load"], K["ground"], K["apply"], K["join"]
plain_material, gradient_image, make_image = K["plain_material"], K["gradient_image"], K["make_image"]

# Island looks (texture recolour ops).
# The twisted-tree leaf texture is painted red (the pack tints it in-engine): shift red to soft pink.
BLOSSOM = {"hue": -25, "sat": 0.38, "val": 1.5}
BLOSSOM_DEEP = {"hue": -28, "sat": 0.55, "val": 1.4}
RED_TO_GREEN = {"hue": 105, "sat": 0.85, "val": 1.0}
LUSH = {"sat": 1.15, "val": 1.08}
WARM_STONE = {"tint": (0.86, 0.8, 0.72), "amount": 0.55, "val": 1.12}
DARK_BARK = {"val": 0.8}


# ------------------------------------------------------------------ helpers
def split_roles(obj, name):
    """One object per material role, parented to an empty Kit_<name>."""
    K["merge_roles"](obj)
    while obj.data.color_attributes:
        obj.data.color_attributes.remove(obj.data.color_attributes[0])
    ground(obj)
    empty = bpy.data.objects.new("Kit_" + name, None)
    bpy.context.scene.collection.objects.link(empty)
    parts = []
    mats = list(obj.data.materials)
    if len(mats) <= 1:
        obj.name = obj.data.name = f"{name}__{mats[0].name if mats else 'Body'}"
        parts = [obj]
    else:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="MATERIAL")
        bpy.ops.object.mode_set(mode="OBJECT")
        for o in bpy.context.selected_objects:
            role = o.data.materials[0].name if o.data.materials else "Body"
            o.name = o.data.name = f"{name}__{role}"
            parts.append(o)
    for o in parts:
        o.parent = empty
    return empty


def pack_prop(name, file, roles, height=None, folder=None):
    obj = load(os.path.join(folder or NAT, file + ".gltf"))
    # Blender renames repeat imports' materials (Leaves_TwistedTree.001): match roles on the base name.
    named = {}
    for m in obj.data.materials:
        base = m.name.split(".")[0] if m else None
        if base in roles:
            named[m.name] = roles[base]
    if "*" in roles:
        named["*"] = roles["*"]
    retex(obj, named)
    if height:
        ground(obj, height)
    return split_roles(obj, name)


def bevel(obj, width, segments=3):
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(40)
    m.harden_normals = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=m.name)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def box(size, loc, mat, bev=0.08):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = size
    apply(o)
    o.data.materials.append(mat)
    K["smart_uv"] = None
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=max(size) * 1.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    return bevel(o, min(bev, min(size) * 0.3))


def cyl(radius, depth, loc, mat, verts=16, bev=0.06, radius2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius if radius2 is None else radius2, depth=depth, location=loc)
    o = bpy.context.active_object
    o.data.materials.append(mat)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cylinder_project()
    bpy.ops.object.mode_set(mode="OBJECT")
    return bevel(o, min(bev, radius * 0.3))


def gmat(role, bottom, top):
    """A plain material whose texture is a vertical gradient (darker base, lighter top: the painted look)."""
    return plain_material(role, gradient_image(f"{role}_{abs(hash((bottom, top))) % 10**6}", bottom, top))


def custom(name, parts):
    """Groups custom meshes by material into role objects under Kit_<name>."""
    obj = join(parts) if len(parts) > 1 else parts[0]
    return split_roles(obj, name)


# ------------------------------------------------------------------ custom pieces
def torii():
    lac = gmat("Lacquer", (0.62, 0.08, 0.06), (0.93, 0.2, 0.14))
    ink = gmat("Ink", (0.08, 0.06, 0.06), (0.2, 0.16, 0.15))
    gold = gmat("Gold", (0.85, 0.55, 0.1), (1.0, 0.86, 0.38))
    stone = gmat("Stone", (0.55, 0.52, 0.5), (0.82, 0.8, 0.76))
    p = []
    for x in (-3.0, 3.0):
        p.append(cyl(0.42, 7.6, (x, 0, 3.8), lac, radius2=0.36))
        p.append(cyl(0.62, 0.5, (x, 0, 0.25), stone, verts=8))
        p.append(box((0.95, 0.95, 0.28), (x, 0, 6.2), ink))
    p.append(box((8.6, 1.0, 0.5), (0, 0, 7.9), ink, bev=0.15))
    p.append(box((8.0, 0.8, 0.42), (0, 0, 7.45), lac, bev=0.1))
    p.append(box((7.4, 0.5, 0.42), (0, 0, 6.2), lac, bev=0.08))
    p.append(box((1.6, 0.25, 1.1), (0, 0.3, 6.85), gold, bev=0.06))
    # upturned kasagi tips
    for s in (-1, 1):
        t = box((0.9, 1.0, 0.5), (s * 4.55, 0, 8.05), ink, bev=0.12)
        t.rotation_euler = (0, s * math.radians(-12), 0)
        apply(t)
        p.append(t)
    return custom("Torii", p)


def stone_lantern():
    stone = gmat("Stone", (0.5, 0.48, 0.46), (0.86, 0.83, 0.78))
    glow = plain_material("Glow", make_image("LanternGlow", np.ones((4, 4, 4)) * np.array([1.0, 0.78, 0.45, 1.0])))
    p = [
        cyl(0.75, 0.35, (0, 0, 0.18), stone, verts=8),
        cyl(0.28, 1.6, (0, 0, 1.15), stone, verts=8),
        cyl(0.7, 0.3, (0, 0, 2.05), stone, verts=8),
        box((0.95, 0.95, 0.85), (0, 0, 2.6), glow, bev=0.05),
        cyl(0.95, 0.5, (0, 0, 3.25), stone, verts=6, radius2=0.25),
        cyl(0.18, 0.35, (0, 0, 3.65), stone, verts=8),
    ]
    for x, y in ((0.46, 0), (-0.46, 0), (0, 0.46), (0, -0.46)):
        post = box((0.16 if x else 0.95, 0.95 if x else 0.16, 0.85), (x * 1.05, y * 1.05, 2.6), stone, bev=0.03)
        p.append(post)
    return custom("StoneLantern", p)


def altar_body():
    stone = gmat("Stone", (0.6, 0.57, 0.52), (0.92, 0.89, 0.82))
    trim = gmat("Trim", (0.7, 0.7, 0.7), (1.0, 1.0, 1.0))  # recoloured per tier in game
    p = [
        cyl(11.2, 2.0, (0, 0, 1.0), stone, verts=8, bev=0.35),
        cyl(8.4, 2.0, (0, 0, 3.0), stone, verts=8, bev=0.3),
        cyl(8.7, 0.35, (0, 0, 2.05), trim, verts=8, bev=0.08),
        cyl(5.8, 2.0, (0, 0, 5.0), trim, verts=8, bev=0.3),
    ]
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        p.append(box((1.0, 1.0, 1.6), (math.cos(a) * 10.4, math.sin(a) * 10.4, 2.3), stone, bev=0.2))
    return custom("Altar", p)


def portal_ring():
    gold = gmat("Gold", (0.85, 0.5, 0.08), (1.0, 0.88, 0.4))
    ink = gmat("Ink", (0.25, 0.12, 0.35), (0.45, 0.25, 0.6))
    bpy.ops.mesh.primitive_torus_add(major_radius=24, minor_radius=1.7, major_segments=64, minor_segments=12)
    ring = bpy.context.active_object
    ring.data.materials.append(gold)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cylinder_project()
    bpy.ops.object.mode_set(mode="OBJECT")
    for p in ring.data.polygons:
        p.use_smooth = True
    p = [ring]
    for i in range(16):
        a = i * math.tau / 16
        b = box((2.4, 2.4, 4.6), (math.cos(a) * 24, math.sin(a) * 24, 0), ink if i % 2 else gold, bev=0.4)
        b.rotation_euler = (0, 0, a)
        apply(b)
        p.append(b)
    # Stand the ring upright (its face toward +Y) so the game can lay it flat or tilt it.
    o = join(p)
    o.rotation_euler = (math.radians(90), 0, 0)
    apply(o)
    return split_roles(o, "PortalRing")


def cloud_puff(name, seed):
    rng = np.random.default_rng(seed)
    white = gmat("Cloud", (0.82, 0.86, 0.95), (1.0, 1.0, 1.0))
    blobs = []
    for k in range(7):
        r = rng.uniform(2.2, 3.6) * (1.3 if k == 0 else 1)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=r, location=(rng.uniform(-4, 4), rng.uniform(-2.5, 2.5), rng.uniform(0, 1.2)))
        o = bpy.context.active_object
        o.scale = (1.15, 1.0, 0.72)
        apply(o)
        o.data.materials.append(white)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.sphere_project()
        bpy.ops.object.mode_set(mode="OBJECT")
        for p in o.data.polygons:
            p.use_smooth = True
        blobs.append(o)
    return custom(name, blobs)


# ------------------------------------------------------------------ the kit
def build():
    K["clear"]()
    props = [
        pack_prop("BlossomTree1", "TwistedTree_1", {"Bark_TwistedTree": ("Bark", DARK_BARK, False), "Leaves_TwistedTree": ("Leaves", BLOSSOM, True)}),
        pack_prop("BlossomTree2", "TwistedTree_2", {"Bark_TwistedTree": ("Bark", DARK_BARK, False), "Leaves_TwistedTree": ("Leaves", BLOSSOM_DEEP, True)}),
        pack_prop("BlossomTree3", "TwistedTree_4", {"Bark_TwistedTree": ("Bark", DARK_BARK, False), "Leaves_TwistedTree": ("Leaves", BLOSSOM, True)}),
        pack_prop("GreenTree1", "CommonTree_1", {"Bark_NormalTree": ("Bark", None, False), "Leaves_NormalTree": ("Leaves", LUSH, True)}),
        pack_prop("GreenTree2", "CommonTree_3", {"Bark_NormalTree": ("Bark", None, False), "Leaves_NormalTree": ("Leaves", LUSH, True)}),
        pack_prop("Pine", "Pine_2", {"Leaves_Pine": ("Leaves", LUSH, True), "Bark_NormalTree": ("Bark", None, False)}),
        pack_prop("FlowerBush", "Bush_Common_Flowers", {"Flowers": ("Flowers", {"hue": -20, "sat": 1.2}, True), "Leaves_NormalTree": ("Leaves", LUSH, True)}),
        pack_prop("Bush", "Bush_Common", {"*": ("Leaves", RED_TO_GREEN, True)}),
        pack_prop("Rock1", "Rock_Medium_1", {"*": ("Rock", WARM_STONE, False)}),
        pack_prop("Rock2", "Rock_Medium_2", {"*": ("Rock", WARM_STONE, False)}),
        pack_prop("Rock3", "Rock_Medium_3", {"*": ("Rock", WARM_STONE, False)}),
        pack_prop("Flowers1", "Flower_3_Group", {"*": ("Flowers", {"sat": 1.2}, True)}),
        pack_prop("Flowers2", "Flower_4_Group", {"*": ("Flowers", {"hue": 25, "sat": 1.2}, True)}),
        pack_prop("Grass", "Grass_Common_Tall", {"*": ("Grass", LUSH, True)}),
        pack_prop("SteppingStone", "RockPath_Round_Wide", {"*": ("Stone", WARM_STONE, False)}),
        pack_prop("Barrel", "Barrel", {"*": ("Wood", None, False)}, folder=PROPS),
        pack_prop("Crate", "Crate_Wooden", {"*": ("Wood", None, False)}, folder=PROPS),
        torii(),
        stone_lantern(),
        altar_body(),
        portal_ring(),
        cloud_puff("Cloud1", 3),
        cloud_puff("Cloud2", 11),
    ]
    # Lay them out in a row so the import (and the preview) is easy to read.
    x = 0
    for empty in props:
        kids = [c for c in empty.children]
        width = 0
        for c in kids:
            lo, hi = K["bounds"](c)
            width = max(width, hi.x - lo.x, hi.y - lo.y)
        empty.location = (x + width / 2, 0, 0)
        x += width + 4
    return props


def export(props):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "SkyDojoKit.glb"), export_format="GLB", use_selection=False)


def preview(props):
    sc = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = engine
            break
        except TypeError:
            continue
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.45, 0.68, 1.0, 1)
    bg.inputs["Strength"].default_value = 0.9
    sc.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.color = (1.0, 0.88, 0.74)
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(sun)
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 2400, 900


props = build()
export(props)
preview(props)
print("KIT", len(props), "props ->", os.path.join(OUT, "SkyDojoKit.glb"))
