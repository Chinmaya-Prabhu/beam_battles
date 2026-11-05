"""Renders clips from tools/blender/r15_studio.py on the studio's six stage rigs, so poses can be checked as
pictures before exporting: each batch of six clips is shown at time T (default: each clip's last key), from
the front and from a three-quarter angle.

    Blender -b --python tools/blender/preview.py -- OUT_DIR SigGojo,SigSukuna,... [T]
"""
import os
import sys

import bpy
from mathutils import Vector

ROOT = "/Users/chinmayaprabhu/Documents/RBX/anime-clash"
exec(open(os.path.join(ROOT, "tools", "blender", "r15_studio.py")).read())

args = sys.argv[sys.argv.index("--") + 1:]
out_dir, names = args[0], args[1].split(",")
at = float(args[2]) if len(args) > 2 else None
os.makedirs(out_dir, exist_ok=True)

sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y = 1500, 620
rigs_ = sorted((o for o in bpy.data.objects if o.type == "ARMATURE"), key=lambda o: o.location.x)
side = bpy.data.objects.new("Side", bpy.data.cameras["Cam"].copy())
side.location = (22, 22, 9)
side.rotation_euler = (Vector((0, 0, 2.6)) - side.location).to_track_quat("-Z", "Y").to_euler()
sc.collection.objects.link(side)
front = sc.camera

for b in range(0, len(names), 6):
    batch = names[b:b + 6]
    longest = 0
    for rig, name in zip(rigs_, batch):
        key_clip(rig, name)
        longest = max(longest, CLIPS[name]["keys"][-1][0])
    for rig in rigs_[len(batch):]:
        key_clip(rig, "Idle")
    sc.frame_set(1 + round((at if at is not None else longest) * FPS))
    for cam, tag in ((front, "front"), (side, "side")):
        sc.camera = cam
        sc.render.filepath = os.path.join(out_dir, "batch%d_%s.png" % (b // 6, tag))
        bpy.ops.render.render(write_still=True)
    print("rendered", batch)
