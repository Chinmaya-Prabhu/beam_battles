"""R15 rig + pose preview in Blender (stand-in bodies with outfit colours).

Builds a Roblox R15 skeleton (same 15 segments and joints the game converts every fighter to), binds a
blocky body to it, and applies the poses from src/shared/Poses.lua (Poses.R15), converted from Roblox
axes (X right, Y up, -Z forward) to Blender (X right, Z up, +Y forward). Units are studs.

Run inside Blender (live MCP or): Blender --python tools/blender/r15_pose_preview.py
"""
import math

import bpy
from mathutils import Matrix, Vector

# part: (size x, y(depth), z, centre z, centre x, parent, pivot z)
PARTS = {
    "LowerTorso": ((2, 1, 0.4), 2.2, 0, None, 2.2),
    "UpperTorso": ((2, 1, 1.6), 3.2, 0, "LowerTorso", 2.4),
    "Head": ((1.2, 1.2, 1.2), 4.65, 0, "UpperTorso", 4.0),
    "RightUpperArm": ((1, 1, 0.85), 3.575, 1.5, "UpperTorso", 3.9),
    "RightLowerArm": ((1, 1, 0.85), 2.725, 1.5, "RightUpperArm", 3.15),
    "RightHand": ((1, 1, 0.3), 2.15, 1.5, "RightLowerArm", 2.3),
    "LeftUpperArm": ((1, 1, 0.85), 3.575, -1.5, "UpperTorso", 3.9),
    "LeftLowerArm": ((1, 1, 0.85), 2.725, -1.5, "LeftUpperArm", 3.15),
    "LeftHand": ((1, 1, 0.3), 2.15, -1.5, "LeftLowerArm", 2.3),
    "RightUpperLeg": ((1, 1, 0.85), 1.575, 0.5, "LowerTorso", 2.0),
    "RightLowerLeg": ((1, 1, 0.85), 0.725, 0.5, "RightUpperLeg", 1.15),
    "RightFoot": ((1, 1, 0.3), 0.15, 0.5, "RightLowerLeg", 0.3),
    "LeftUpperLeg": ((1, 1, 0.85), 1.575, -0.5, "LowerTorso", 2.0),
    "LeftLowerLeg": ((1, 1, 0.85), 0.725, -0.5, "LeftUpperLeg", 1.15),
    "LeftFoot": ((1, 1, 0.3), 0.15, -0.5, "LeftLowerLeg", 0.3),
}
# Roblox joint name -> the segment it moves.
JOINT_TO_BONE = {
    "Root": "LowerTorso", "Waist": "UpperTorso", "Neck": "Head",
    "RightShoulder": "RightUpperArm", "RightElbow": "RightLowerArm", "RightWrist": "RightHand",
    "LeftShoulder": "LeftUpperArm", "LeftElbow": "LeftLowerArm", "LeftWrist": "LeftHand",
    "RightHip": "RightUpperLeg", "RightKnee": "RightLowerLeg", "RightAnkle": "RightFoot",
    "LeftHip": "LeftUpperLeg", "LeftKnee": "LeftLowerLeg", "LeftAnkle": "LeftFoot",
}
# Copied from Poses.R15 (radians, Roblox CFrame.Angles(x, y, z)); Root may carry a y offset.
POSES = {
    "Stance": {"Root": (0, 0, 0, -0.35), "Waist": (0.08, 0.38, 0), "Neck": (-0.08, -0.32, 0),
               "RightShoulder": (1.25, -0.2, 0.25), "RightElbow": (1.75, 0, 0), "RightWrist": (-0.2, 0, 0),
               "LeftShoulder": (1.05, 0.3, -0.3), "LeftElbow": (1.8, 0, 0),
               "RightHip": (0.35, 0, 0.12), "RightKnee": (-0.6, 0, 0), "RightAnkle": (0.25, 0, 0),
               "LeftHip": (-0.15, 0, -0.14), "LeftKnee": (-0.35, 0, 0), "LeftAnkle": (0.2, 0, 0)},
    "Ready": {"Root": (0, 0, 0, -0.2), "Waist": (0.05, 0, 0), "RightShoulder": (0.25, 0, 0.35),
              "RightElbow": (0.6, 0, 0), "LeftShoulder": (0.25, 0, -0.35), "LeftElbow": (0.6, 0, 0),
              "RightHip": (0.1, 0, 0.18), "RightKnee": (-0.25, 0, 0), "LeftHip": (0.1, 0, -0.18),
              "LeftKnee": (-0.25, 0, 0)},
    "PowerUp": {"Root": (0, 0, 0, -0.45), "Waist": (-0.12, 0, 0), "Neck": (-0.3, 0, 0),
                "RightShoulder": (-0.15, 0, 0.6), "RightElbow": (0.5, 0, 0), "LeftShoulder": (-0.15, 0, -0.6),
                "LeftElbow": (0.5, 0, 0), "RightHip": (0.1, 0, 0.32), "RightKnee": (-0.45, 0, 0),
                "RightAnkle": (0.2, 0, -0.25), "LeftHip": (0.1, 0, -0.32), "LeftKnee": (-0.45, 0, 0),
                "LeftAnkle": (0.2, 0, 0.25)},
    "Point": {"Waist": (0, -0.2, 0), "Neck": (0, 0.15, 0), "RightShoulder": (1.5, 0, 0.05),
              "RightElbow": (0.05, 0, 0), "LeftShoulder": (0.35, 0, -0.55), "LeftElbow": (1.9, 0.4, 0),
              "RightHip": (0, 0, 0.1), "LeftHip": (0, 0, -0.1)},
    "Victory": {"Waist": (-0.08, 0.1, 0), "Neck": (-0.25, 0, 0), "RightShoulder": (2.9, 0, 0.2),
                "RightElbow": (0.25, 0, 0), "LeftShoulder": (0.35, 0, -0.55), "LeftElbow": (1.9, 0.4, 0)},
}
# Roblox -> Blender basis: (x, y, z) -> (x, -z, y)
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def roblox_rotation(x, y, z):
    rx = Matrix.Rotation(x, 3, "X")
    ry = Matrix.Rotation(y, 3, "Y")
    rz = Matrix.Rotation(z, 3, "Z")
    return C @ (rx @ ry @ rz) @ C.transposed()


def material(name, rgb, rough=0.45):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*[c / 255 for c in rgb], 1)
    bsdf.inputs["Roughness"].default_value = rough
    return mat


def box(name, size, location, mat, bevel=0.07):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    obj.data.materials.append(mat)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 3
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def build(label, offset, outfit, pose):
    rig_data = bpy.data.armatures.new(label + "_Rig")
    rig = bpy.data.objects.new(label + "_Rig", rig_data)
    bpy.context.scene.collection.objects.link(rig)
    rig.location = (offset, 0, 0)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (size, cz, cx, parent, pivot) in PARTS.items():
        b = rig_data.edit_bones.new(name)
        b.head = Vector((cx, 0, pivot))
        tail_z = cz - size[2] / 2 if pivot > cz else cz + size[2] / 2
        if abs(tail_z - pivot) < 0.1:
            tail_z = pivot + (0.3 if name in ("Head", "UpperTorso", "LowerTorso") else -0.3)
        b.tail = Vector((cx, 0, tail_z))
        b.roll = 0
    for name, (size, cz, cx, parent, pivot) in PARTS.items():
        if parent:
            rig_data.edit_bones[name].parent = rig_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")

    # Body parts bound rigidly to their bones (Roblox R15 segments are rigid too).
    parts = {}
    for name, (size, cz, cx, parent, pivot) in PARTS.items():
        obj = box(label + "_" + name, size, (offset + cx, 0, cz), outfit[name])
        world = obj.matrix_world.copy()
        obj.parent = rig
        obj.parent_type = "BONE"
        obj.parent_bone = name
        obj.matrix_world = world
        parts[name] = obj
    # Face: eyes and mouth on the front of the head, plus the outfit's hair/hat pieces.
    head_front = 4.65
    extras = [(label + "_EyeL", (0.16, 0.05, 0.28), (-0.24, 0.61, head_front + 0.12), outfit["Eye"]),
              (label + "_EyeR", (0.16, 0.05, 0.28), (0.24, 0.61, head_front + 0.12), outfit["Eye"]),
              (label + "_Mouth", (0.36, 0.05, 0.07), (0, 0.61, head_front - 0.25), outfit["Eye"])]
    extras += [(label + "_" + n, s, p, outfit[m]) for n, s, p, m in outfit.get("extras", [])]
    for n, s, p, m in extras:
        obj = box(n, s, (offset + p[0], p[1], p[2]), m, bevel=min(0.05, min(s) / 3))
        world = obj.matrix_world.copy()
        obj.parent = rig
        obj.parent_type = "BONE"
        obj.parent_bone = "Head"
        obj.matrix_world = world

    # Pose: the rotation is about the joint, in the parent's frame at rest (which is the rig's axes),
    # so in bone space it is Q^-1 R Q where Q is the bone's rest orientation.
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for joint, values in POSES[pose].items():
        bone = JOINT_TO_BONE[joint]
        pb = rig.pose.bones[bone]
        q = rig.data.bones[bone].matrix_local.to_3x3()
        r = roblox_rotation(values[0], values[1], values[2])
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (q.inverted() @ r @ q).to_quaternion()
        if len(values) > 3:
            pb.location = q.inverted() @ (C @ Vector((0, values[3], 0)))
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True
    rig.data.display_type = "STICK"
    return rig


def outfit(skin, top, bottom, shoes, sleeves=None, belt=None, extras=None, mats=None):
    m = {"Eye": material("Eye", (25, 25, 35), 0.3), "Skin": material("Skin", skin)}
    m["Top"] = material("Top_%d_%d_%d" % top, top)
    m["Bottom"] = material("Bottom_%d_%d_%d" % bottom, bottom)
    m["Shoes"] = material("Shoes_%d_%d_%d" % shoes, shoes)
    m["Sleeve"] = material("Sleeve_%d_%d_%d" % (sleeves or skin), sleeves or skin)
    m["Belt"] = material("Belt_%d_%d_%d" % (belt or bottom), belt or bottom)
    for k, v in (mats or {}).items():
        m[k] = material(k, v)
    parts = {
        "Head": m["Skin"], "UpperTorso": m["Top"], "LowerTorso": m["Belt"],
        "RightUpperArm": m["Sleeve"], "LeftUpperArm": m["Sleeve"],
        "RightLowerArm": m["Skin"], "LeftLowerArm": m["Skin"], "RightHand": m["Skin"], "LeftHand": m["Skin"],
        "RightUpperLeg": m["Bottom"], "LeftUpperLeg": m["Bottom"],
        "RightLowerLeg": m["Bottom"], "LeftLowerLeg": m["Bottom"], "RightFoot": m["Shoes"], "LeftFoot": m["Shoes"],
    }
    parts.update(m)
    parts["extras"] = extras or []
    return parts


def scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    skin = (255, 214, 170)
    fighters = [
        ("Stance", outfit(skin, (255, 128, 30), (255, 128, 30), (40, 70, 160), sleeves=(255, 128, 30),
                          belt=(40, 70, 160), mats={"HairBlack": (25, 22, 30)},
                          extras=[("Hair", (1.4, 1.3, 0.6), (0, 0, 5.35), "HairBlack"),
                                  ("Spike1", (0.5, 0.5, 0.8), (-0.45, 0, 5.75), "HairBlack"),
                                  ("Spike2", (0.5, 0.5, 0.95), (0.1, 0, 5.85), "HairBlack"),
                                  ("Spike3", (0.5, 0.5, 0.7), (0.55, 0, 5.7), "HairBlack")])),
        ("PowerUp", outfit(skin, (255, 140, 20), (255, 140, 20), (25, 25, 30), sleeves=(30, 30, 40),
                           mats={"HairBlond": (255, 214, 60), "Band": (40, 50, 90)},
                           extras=[("Hair", (1.4, 1.35, 0.55), (0, 0, 5.32), "HairBlond"),
                                   ("Spike1", (0.45, 0.45, 0.7), (-0.5, -0.1, 5.7), "HairBlond"),
                                   ("Spike2", (0.45, 0.45, 0.8), (0.0, 0.1, 5.75), "HairBlond"),
                                   ("Spike3", (0.45, 0.45, 0.65), (0.5, -0.1, 5.68), "HairBlond"),
                                   ("Headband", (1.3, 1.3, 0.22), (0, 0, 5.0), "Band")])),
        ("Point", outfit(skin, (30, 32, 60), (30, 32, 60), (20, 20, 25), sleeves=(30, 32, 60),
                         mats={"HairWhite": (240, 244, 255), "Blindfold": (20, 20, 25)},
                         extras=[("Hair", (1.4, 1.35, 0.7), (0, -0.05, 5.4), "HairWhite"),
                                 ("Spike1", (0.5, 0.5, 0.9), (-0.3, -0.1, 5.9), "HairWhite"),
                                 ("Spike2", (0.5, 0.5, 1.0), (0.3, -0.05, 5.95), "HairWhite"),
                                 ("Blindfold", (1.3, 1.3, 0.3), (0, 0, 4.78), "Blindfold")])),
        ("Victory", outfit(skin, (220, 40, 40), (40, 90, 200), (150, 100, 60), sleeves=skin,
                           mats={"Straw": (240, 205, 110), "HatBand": (200, 30, 30), "HairBlack2": (25, 22, 30)},
                           extras=[("Hair", (1.3, 1.3, 0.35), (0, 0, 5.3), "HairBlack2"),
                                   ("HatBrim", (2.4, 2.4, 0.12), (0, 0, 5.45), "Straw"),
                                   ("HatTop", (1.4, 1.4, 0.55), (0, 0, 5.75), "Straw"),
                                   ("HatBand", (1.45, 1.45, 0.16), (0, 0, 5.56), "HatBand")])),
        ("Ready", outfit(skin, (25, 25, 30), (25, 25, 30), (20, 20, 25), sleeves=(25, 25, 30),
                         belt=(240, 240, 245), mats={"HairOrange": (255, 120, 30)},
                         extras=[("Hair", (1.4, 1.35, 0.55), (0, 0, 5.32), "HairOrange"),
                                 ("Spike1", (0.5, 0.45, 0.7), (-0.5, 0, 5.7), "HairOrange"),
                                 ("Spike2", (0.5, 0.45, 0.85), (0.05, 0, 5.78), "HairOrange"),
                                 ("Spike3", (0.5, 0.45, 0.65), (0.5, 0, 5.66), "HairOrange")])),
    ]
    for i, (pose, fit) in enumerate(fighters):
        build(pose, (i - 2) * 4.5, fit, pose)

    # Studded-accent stage under them, golden-hour light, sky gradient.
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=13, depth=0.6, location=(0, 0, -0.3))
    stage = bpy.context.active_object
    stage.name = "Stage"
    stage.data.materials.append(material("StageStone", (226, 218, 200), 0.6))
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=13.6, depth=0.5, location=(0, 0, -0.42))
    bpy.context.active_object.data.materials.append(material("StageRim", (214, 48, 40), 0.5))

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 4.0
    sun.color = (1.0, 0.86, 0.7)
    sun_obj = bpy.data.objects.new("Sun", sun)
    sun_obj.rotation_euler = (math.radians(50), math.radians(10), math.radians(150))
    bpy.context.scene.collection.objects.link(sun_obj)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 600
    fill.size = 12
    fill.color = (0.7, 0.8, 1.0)
    fill_obj = bpy.data.objects.new("Fill", fill)
    fill_obj.location = (-8, 14, 9)
    fill_obj.rotation_euler = (Vector((0, 0, 2.5)) - fill_obj.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(fill_obj)

    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.75, 1.0, 1)
    bg.inputs["Strength"].default_value = 0.8

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 40
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, 21, 6.5)
    cam.rotation_euler = (Vector((0, 0, 2.6)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = engine
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = 1600, 800
    sc.view_settings.view_transform = "Standard"


scene()
print("built", len([o for o in bpy.data.objects if o.type == "ARMATURE"]), "rigs")
