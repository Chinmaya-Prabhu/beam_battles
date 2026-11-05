"""R15 animation studio for Anime Clash.

Builds R15 rigs with Roblox's default R15 proportions (segments overlap at the joints, like the real
avatar, so bent limbs stay connected), keyframes the fighter clip set, previews it, and exports the clips
as src/shared/Clips.lua for the game's FighterAnimator.

Clips are written as keyed poses in Roblox joint terms (radians for CFrame.Angles(x, y, z) applied as
Motor6D.Transform; Root may also move). Blender interpolates between keys with eased curves; the exporter
samples the result at 30 fps so the game plays exactly what is previewed here.

Run in Blender (live MCP: exec this file) or: Blender --python tools/blender/r15_studio.py
"""
import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = "/Users/chinmayaprabhu/Documents/RBX/anime-clash"
FPS = 30
EXPORT_FPS = 15  # the game blends between frames, so half the samples look the same and halve Clips.lua

# Roblox default R15 segment sizes (x, y=height, z) and rig attachment offsets, laid out from the floor up.
# part: (size x, depth, height, centre z, centre x, parent, pivot (x, z))
PARTS = {
    "LowerTorso": ((2, 1, 0.4), 2.019, 0, None, (0, 2.019)),
    "UpperTorso": ((2, 1, 1.6), 3.019, 0, "LowerTorso", (0, 2.219)),
    "Head": ((1.2, 1.2, 1.2), 4.319, 0, "UpperTorso", (0, 3.819)),
    "RightUpperArm": ((1, 1, 1.169), 3.162, 1.5, "UpperTorso", (1.5, 3.582)),
    "RightLowerArm": ((1, 1, 1.052), 2.567, 1.5, "RightUpperArm", (1.5, 2.828)),
    "RightHand": ((1, 1, 0.3), 1.942, 1.5, "RightLowerArm", (1.5, 2.067)),
    "LeftUpperArm": ((1, 1, 1.169), 3.162, -1.5, "UpperTorso", (-1.5, 3.582)),
    "LeftLowerArm": ((1, 1, 1.052), 2.567, -1.5, "LeftUpperArm", (-1.5, 2.828)),
    "LeftHand": ((1, 1, 0.3), 1.942, -1.5, "LeftLowerArm", (-1.5, 2.067)),
    "RightUpperLeg": ((1, 1, 1.217), 1.398, 0.5, "LowerTorso", (0.5, 1.819)),
    "RightLowerLeg": ((1, 1, 1.193), 0.797, 0.5, "RightUpperLeg", (0.5, 0.997)),
    "RightFoot": ((1, 1, 0.3), 0.15, 0.5, "RightLowerLeg", (0.5, 0.25)),
    "LeftUpperLeg": ((1, 1, 1.217), 1.398, -0.5, "LowerTorso", (-0.5, 1.819)),
    "LeftLowerLeg": ((1, 1, 1.193), 0.797, -0.5, "LeftUpperLeg", (-0.5, 0.997)),
    "LeftFoot": ((1, 1, 0.3), 0.15, -0.5, "LeftLowerLeg", (-0.5, 0.25)),
}
JOINT_TO_BONE = {
    "Root": "LowerTorso", "Waist": "UpperTorso", "Neck": "Head",
    "RightShoulder": "RightUpperArm", "RightElbow": "RightLowerArm", "RightWrist": "RightHand",
    "LeftShoulder": "LeftUpperArm", "LeftElbow": "LeftLowerArm", "LeftWrist": "LeftHand",
    "RightHip": "RightUpperLeg", "RightKnee": "RightLowerLeg", "RightAnkle": "RightFoot",
    "LeftHip": "LeftUpperLeg", "LeftKnee": "LeftLowerLeg", "LeftAnkle": "LeftFoot",
}
BONE_TO_JOINT = {b: j for j, b in JOINT_TO_BONE.items()}
# Roblox (x right, y up, z back) -> Blender (x right, z up, -y back): (x, y, z) -> (x, -z, y)
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


# ---------------------------------------------------------------- poses (Roblox joint terms)
def P(**joints):
    """A pose: joint=(rx, ry, rz) or (rx, ry, rz, dx, dy, dz) for Root."""
    return joints


GUARD = P(
    Root=(0, 0, 0, 0, -0.35, 0), Waist=(0.08, 0.38, 0), Neck=(-0.08, -0.32, 0),
    RightShoulder=(1.3, -0.35, 0.15), RightElbow=(1.9, 0, 0), RightWrist=(-0.25, 0, 0),
    LeftShoulder=(1.15, 0.45, -0.2), LeftElbow=(1.95, 0, 0),
    RightHip=(0.4, 0, 0.14), RightKnee=(-0.75, 0, 0), RightAnkle=(0.35, 0, 0),
    LeftHip=(-0.2, 0, -0.16), LeftKnee=(-0.4, 0, 0), LeftAnkle=(0.3, 0, 0),
)


def breathe(pose, amount):
    p = {k: list(v) for k, v in pose.items()}
    for k in [k for k in p if k.startswith("_")]:  # hand targets rise with the chest
        p[k][1] += 0.04 * amount
    p.setdefault("Waist", [0, 0, 0])[0] -= 0.04 * amount
    p.setdefault("Neck", [0, 0, 0])[0] += 0.03 * amount
    for s in ("RightShoulder", "LeftShoulder"):
        p.setdefault(s, [0, 0, 0])[0] += 0.06 * amount
    root = p.setdefault("Root", [0, 0, 0, 0, 0, 0])
    while len(root) < 6:
        root.append(0)
    root[4] += 0.06 * amount
    return {k: tuple(v) for k, v in p.items()}


CLIPS = {
    # Fighting-stance idle: guard up, chest rising and falling, slight bounce.
    "Idle": {"loop": True, "keys": [(0, GUARD), (1.0, breathe(GUARD, 1)), (2.0, GUARD)]},
    # Gather in, then explode outward with an aura scream.
    "PowerUp": {"loop": False, "keys": [
        (0, GUARD),
        (0.35, P(Root=(0.15, 0, 0, 0, -0.75, 0), Waist=(0.35, 0, 0), Neck=(0.35, 0, 0),
                 RightShoulder=(0.6, 0, 0.25), RightElbow=(2.2, 0, 0), LeftShoulder=(0.6, 0, -0.25),
                 LeftElbow=(2.2, 0, 0), RightHip=(0.55, 0, 0.3), RightKnee=(-1.05, 0, 0), RightAnkle=(0.5, 0, 0),
                 LeftHip=(0.55, 0, -0.3), LeftKnee=(-1.05, 0, 0), LeftAnkle=(0.5, 0, 0))),
        (0.62, P(Root=(-0.12, 0, 0, 0, -0.35, 0), Waist=(-0.3, 0, 0), Neck=(-0.5, 0, 0),
                 RightShoulder=(0.2, 0, 1.25), RightElbow=(0.9, 0, 0), RightWrist=(0, 0, 0.3),
                 LeftShoulder=(0.2, 0, -1.25), LeftElbow=(0.9, 0, 0), LeftWrist=(0, 0, -0.3),
                 RightHip=(0.15, 0, 0.42), RightKnee=(-0.55, 0, 0), RightAnkle=(0.3, 0, -0.3),
                 LeftHip=(0.15, 0, -0.42), LeftKnee=(-0.55, 0, 0), LeftAnkle=(0.3, 0, 0.3))),
        (1.6, P(Root=(-0.08, 0, 0, 0, -0.4, 0), Waist=(-0.22, 0, 0), Neck=(-0.4, 0, 0),
                RightShoulder=(0.15, 0, 1.15), RightElbow=(1.0, 0, 0), LeftShoulder=(0.15, 0, -1.15),
                LeftElbow=(1.0, 0, 0), RightHip=(0.15, 0, 0.4), RightKnee=(-0.6, 0, 0), RightAnkle=(0.3, 0, -0.3),
                LeftHip=(0.15, 0, -0.4), LeftKnee=(-0.6, 0, 0), LeftAnkle=(0.3, 0, 0.3))),
    ]},
    # Two-handed beam push (the clash stance), with a straining shake.
    "Fire": {"loop": True, "keys": [
        (0, P(Root=(0, 0.35, 0, 0, -0.55, 0), Waist=(0.18, -0.3, 0), Neck=(-0.05, -0.05, 0),
              RightShoulder=(1.5, 0.35, -0.1), RightElbow=(0.15, 0, 0), RightWrist=(-1.1, 0, 0),
              LeftShoulder=(1.5, -0.35, 0.1), LeftElbow=(0.15, 0, 0), LeftWrist=(-1.1, 0, 0),
              RightHip=(0.75, 0, 0.1), RightKnee=(-0.95, 0, 0), RightAnkle=(0.2, 0, 0),
              LeftHip=(-0.5, 0, -0.1), LeftKnee=(-0.15, 0, 0), LeftAnkle=(0.35, 0, 0))),
        (0.15, P(Root=(0.03, 0.35, 0.02, 0, -0.6, 0), Waist=(0.22, -0.3, 0.02), Neck=(-0.08, -0.05, 0),
                 RightShoulder=(1.55, 0.33, -0.1), RightElbow=(0.1, 0, 0), RightWrist=(-1.15, 0, 0),
                 LeftShoulder=(1.55, -0.33, 0.1), LeftElbow=(0.1, 0, 0), LeftWrist=(-1.15, 0, 0),
                 RightHip=(0.78, 0, 0.1), RightKnee=(-1.0, 0, 0), RightAnkle=(0.2, 0, 0),
                 LeftHip=(-0.52, 0, -0.1), LeftKnee=(-0.15, 0, 0), LeftAnkle=(0.35, 0, 0))),
        (0.3, None),  # back to the first key
    ]},
    # Crouch, spring up, fist to the sky, land into a proud stance.
    "Victory": {"loop": False, "keys": [
        (0, GUARD),
        (0.25, P(Root=(0.2, 0, 0, 0, -0.8, 0), Waist=(0.3, 0, 0), Neck=(0.2, 0, 0),
                 RightShoulder=(0.4, 0, 0.3), RightElbow=(1.6, 0, 0), LeftShoulder=(0.4, 0, -0.3),
                 LeftElbow=(1.6, 0, 0), RightHip=(0.7, 0, 0.12), RightKnee=(-1.3, 0, 0), RightAnkle=(0.6, 0, 0),
                 LeftHip=(0.7, 0, -0.12), LeftKnee=(-1.3, 0, 0), LeftAnkle=(0.6, 0, 0))),
        (0.5, P(Root=(-0.1, 0, 0, 0, 0.9, 0), Waist=(-0.15, 0, 0), Neck=(-0.35, 0, 0),
                RightShoulder=(3.0, 0, 0.15), RightElbow=(0.1, 0, 0), LeftShoulder=(0.2, 0, -0.5),
                LeftElbow=(0.9, 0, 0), RightHip=(-0.1, 0, 0.05), RightKnee=(-0.2, 0, 0),
                LeftHip=(0.6, 0, -0.05), LeftKnee=(-1.4, 0, 0), LeftAnkle=(0.4, 0, 0))),
        (0.8, P(Root=(0, 0, 0, 0, -0.15, 0), Waist=(-0.1, 0.15, 0), Neck=(-0.3, 0.1, 0),
                RightShoulder=(2.95, 0, 0.2), RightElbow=(0.2, 0, 0), LeftShoulder=(0.35, 0, -0.55),
                LeftElbow=(1.9, 0.4, 0), RightHip=(0.15, 0, 0.15), RightKnee=(-0.3, 0, 0),
                LeftHip=(0.05, 0, -0.15), LeftKnee=(-0.15, 0, 0))),
        (1.6, P(Root=(0, 0, 0, 0, -0.05, 0), Waist=(-0.12, 0.15, 0), Neck=(-0.3, 0.1, 0),
                RightShoulder=(2.9, 0, 0.2), RightElbow=(0.25, 0, 0), LeftShoulder=(0.35, 0, -0.55),
                LeftElbow=(1.9, 0.4, 0), RightHip=(0.12, 0, 0.15), RightKnee=(-0.25, 0, 0),
                LeftHip=(0.05, 0, -0.15), LeftKnee=(-0.1, 0, 0))),
    ]},
    # Hit by the winning beam: knocked back, arms flung, flat on the back.
    "KO": {"loop": False, "keys": [
        (0, GUARD),
        (0.15, P(Root=(-0.45, 0, 0, 0, -0.2, 0.6), Waist=(-0.35, 0, 0), Neck=(0.4, 0, 0),
                 RightShoulder=(1.6, 0, 1.2), RightElbow=(0.6, 0, 0), LeftShoulder=(1.4, 0, -1.3),
                 LeftElbow=(0.5, 0, 0), RightHip=(0.6, 0, 0.2), RightKnee=(-0.3, 0, 0),
                 LeftHip=(0.9, 0, -0.2), LeftKnee=(-0.6, 0, 0))),
        (0.55, P(Root=(-1.45, 0, 0.1, 0, -1.6, 2.6), Waist=(-0.2, 0, 0), Neck=(0.3, 0.3, 0),
                 RightShoulder=(2.4, 0, 0.9), RightElbow=(0.4, 0, 0), LeftShoulder=(2.2, 0, -1.0),
                 LeftElbow=(0.6, 0, 0), RightHip=(0.9, 0, 0.3), RightKnee=(-0.9, 0, 0),
                 LeftHip=(0.4, 0, -0.25), LeftKnee=(-0.3, 0, 0))),
        (1.2, P(Root=(-1.57, 0, 0.1, 0, -1.95, 2.9), Waist=(0, 0, 0), Neck=(0.15, 0.4, 0),
                RightShoulder=(2.9, 0, 0.6), RightElbow=(0.2, 0, 0), LeftShoulder=(2.7, 0, -0.7),
                LeftElbow=(0.3, 0, 0), RightHip=(0.5, 0, 0.25), RightKnee=(-0.6, 0, 0),
                LeftHip=(0.15, 0, -0.2), LeftKnee=(-0.2, 0, 0))),
    ]},
    # Point at the rival, other fist on the hip, little nod.
    "Taunt": {"loop": False, "keys": [
        (0, GUARD),
        (0.3, P(Waist=(0, -0.3, 0), Neck=(-0.1, 0.2, 0), RightShoulder=(1.55, 0, 0.05),
                RightElbow=(0.05, 0, 0), LeftShoulder=(0.35, 0, -0.6), LeftElbow=(2.0, 0.45, 0),
                RightHip=(0.05, 0, 0.12), LeftHip=(0, 0, -0.1))),
        (0.6, P(Waist=(0, -0.3, 0), Neck=(0.12, 0.2, 0), RightShoulder=(1.5, 0, 0.05),
                RightElbow=(0.05, 0, 0), LeftShoulder=(0.35, 0, -0.6), LeftElbow=(2.0, 0.45, 0),
                RightHip=(0.05, 0, 0.12), LeftHip=(0, 0, -0.1))),
        (1.2, P(Waist=(0, -0.3, 0), Neck=(-0.08, 0.2, 0), RightShoulder=(1.55, 0, 0.05),
                RightElbow=(0.05, 0, 0), LeftShoulder=(0.35, 0, -0.6), LeftElbow=(2.0, 0.45, 0),
                RightHip=(0.05, 0, 0.12), LeftHip=(0, 0, -0.1))),
    ]},
}

# Dances (shared/Dances.lua lists them): played now and then by fighters on show, after a clash win, and all
# together at a base's dance party. Moves in the spirit of what's trending in Roblox emotes; our own names.
def loop(beat, *poses):
    """A looping dance: the poses one beat apart, back to the first."""
    keys = [(i * beat, p) for i, p in enumerate(poses)]
    keys.append((len(poses) * beat, None))
    return {"loop": True, "keys": keys}


def mirror(pose):
    """The same pose on the other side: left and right swapped, sideways turns and leans flipped."""
    out = {}
    for k, v in pose.items():
        if k.startswith("_"):
            side = "L" if k[1] == "R" else "R"
            out["_" + side + k[2:]] = (-v[0], v[1], v[2])
            continue
        name = k.replace("Right", "#").replace("Left", "Right").replace("#", "Left")
        v = list(v)
        v[1], v[2] = -v[1], -v[2]
        if len(v) > 3:
            v[3] = -v[3]
        out[name] = tuple(v)
    return out


SHUFFLE_A = P(Root=(0, 0, 0, 0, -0.3, 0), Waist=(0.1, 0, 0),
              RightHip=(0.9, 0, 0.05), RightKnee=(-1.3, 0, 0), RightAnkle=(0.4, 0, 0),
              LeftHip=(-0.35, 0, -0.05), LeftKnee=(-0.2, 0, 0),
              _R=(1.3, 3.3, 0.9), _L=(-1.4, 2.6, -0.4))
HELLO_A = P(Root=(0, 0, 0.1, 0.25, -0.15, 0), Waist=(0, 0, -0.14), Neck=(0, 0.15, 0.2),
            _R=(0.55, 3.8, 0.9), _L=(-0.15, 3.75, 0.95), RightKnee=(-0.35, 0, 0), RightHip=(0.15, 0, 0))
FUNK_A = P(Root=(0.15, 0, 0, 0, -0.55, 0.2), Waist=(0.25, 0, 0), Neck=(-0.1, 0, 0),
           RightHip=(0.7, 0, 0.3), RightKnee=(-1.1, 0, 0), RightAnkle=(0.4, 0, 0),
           LeftHip=(0.7, 0, -0.3), LeftKnee=(-1.1, 0, 0), LeftAnkle=(0.4, 0, 0),
           _R=(-0.6, 2.5, 1.2), _L=(0.6, 2.5, 1.2))
FUNK_B = P(Root=(-0.15, 0, 0, 0, -0.25, -0.15), Waist=(-0.2, 0, 0), Neck=(0.05, 0, 0),
           RightHip=(0.2, 0, 0.3), RightKnee=(-0.4, 0, 0), RightAnkle=(0.2, 0, 0),
           LeftHip=(0.2, 0, -0.3), LeftKnee=(-0.4, 0, 0), LeftAnkle=(0.2, 0, 0),
           _R=(1.5, 2.3, 0.4), _L=(-1.5, 2.3, 0.4))
BUGGIN_A = P(Root=(0, 0, 0, 0, -0.35, 0), Neck=(0.3, 0.25, 0), Waist=(0.1, 0.2, 0),
             RightHip=(0.4, 0, 0.15), RightKnee=(-0.7, 0, 0), LeftHip=(0.4, 0, -0.15), LeftKnee=(-0.7, 0, 0),
             _R=(0.6, 3.1, 1.1), _L=(-0.6, 3.1, 1.1))
BUGGIN_B = P(Root=(0, 0, 0, 0, -0.05, 0), Neck=(-0.15, -0.25, 0), Waist=(-0.05, -0.2, 0),
             RightHip=(0.1, 0, 0.15), RightKnee=(-0.2, 0, 0), LeftHip=(0.1, 0, -0.15), LeftKnee=(-0.2, 0, 0),
             _R=(0.75, 3.55, 0.95), _L=(-0.75, 3.55, 0.95))
SAHUR_A = P(Root=(0, 0, 0, 0, 0.25, 0), Neck=(-0.2, 0, 0), RightHip=(0.15, 0, 0.1), LeftHip=(0.15, 0, -0.1),
            RightKnee=(-0.3, 0, 0), LeftKnee=(-0.3, 0, 0), _R=(0.35, 5.6, 0.6), _L=(-0.35, 5.5, 0.6))
SAHUR_B = P(Root=(0.2, 0, 0, 0, -0.45, 0), Waist=(0.35, 0, 0), Neck=(0.3, 0, 0),
            RightHip=(0.6, 0, 0.12), RightKnee=(-1.0, 0, 0), RightAnkle=(0.4, 0, 0),
            LeftHip=(0.6, 0, -0.12), LeftKnee=(-1.0, 0, 0), LeftAnkle=(0.4, 0, 0),
            _R=(0.25, 2.3, 1.9), _L=(-0.25, 2.3, 1.9))
SWAG_A = P(Root=(-0.05, 0.15, 0, 0, 0, 0), Waist=(-0.15, 0.2, 0), Neck=(-0.1, -0.2, 0),
           RightHip=(0.6, 0, 0.05), RightKnee=(-0.5, 0, 0), RightAnkle=(0.2, 0, 0),
           LeftHip=(-0.3, 0, -0.05), LeftKnee=(-0.1, 0, 0),
           _R=(1.5, 2.5, -0.5), _L=(-1.35, 2.7, 0.7))
AFRO_A = P(Root=(0, 0, 0.12, 0.3, -0.25, 0), Waist=(0.1, 0.25, -0.2), Neck=(0, -0.2, 0.15),
           RightHip=(0.35, 0, 0.12), RightKnee=(-0.7, 0, 0), RightAnkle=(0.3, 0, 0),
           LeftHip=(0.1, 0, -0.05), LeftKnee=(-0.25, 0, 0),
           _R=(1.6, 2.9, 0.6), _L=(-1.0, 3.3, 0.9))
HEEL_A = P(Root=(0, 0, 0, 0, -0.2, 0), Waist=(0.15, 0, 0), Neck=(0.1, 0, 0),
           RightHip=(0.15, 0, 0.1), RightKnee=(-0.2, 0, 0), RightAnkle=(-0.6, 0, 0),
           LeftHip=(0.6, 0, -0.1), LeftKnee=(-1.2, 0, 0), LeftAnkle=(0.3, 0, 0),
           _R=(1.3, 2.4, -0.6), _L=(-1.3, 2.4, -0.6))

CLIPS.update({
    # Shuffle: the running-man slide, knees up in turn, arms pumping.
    "DanceShuffle": loop(0.22, SHUFFLE_A, mirror(SHUFFLE_A)),
    # Hello Kitty: hips swinging, paws up by the cheeks.
    "DanceKitty": loop(0.3, HELLO_A, mirror(HELLO_A)),
    # Funk: low bounce, hips snapping forward and back, arms crossing and opening.
    "DanceFunk": loop(0.2, FUNK_A, FUNK_B),
    # Buggin: head bob and shoulder shrug, fists at the chest.
    "DanceBuggin": loop(0.18, BUGGIN_A, BUGGIN_B, mirror(BUGGIN_A), mirror(BUGGIN_B)),
    # Sahur: up on the toes with both arms high, then a big drum swing down.
    "DanceSahur": loop(0.28, SAHUR_A, SAHUR_B),
    # Swag walk: a lean-back strut on the spot, one arm swinging.
    "DanceSwag": loop(0.3, SWAG_A, mirror(SWAG_A)),
    # Afrobeat: a loose hip groove, arms floating side to side.
    "DanceAfro": loop(0.32, AFRO_A, mirror(AFRO_A)),
    # Heel tap: heel to the floor, the other knee up, arms swinging behind.
    "DanceHeel": loop(0.2, HEEL_A, mirror(HEEL_A)),
})


# Signature poses (Sig*): each series' iconic stance, played when a fighter lands, is revealed, wins a clash or
# goes on a stand (shared/Fighters.lua: Fighters.signature picks one by series, with a few per character).
# Shape: guard -> a quick wind-up -> snap into the pose -> hold it, breathing. No fingers on the rig, so hand
# signs read from where the two hands meet.
def sig(windup, pose, hold=2.4, snap=0.55, wind=0.3):
    return {"loop": False, "keys": [(0, GUARD), (wind, windup), (snap, pose), (snap + 0.35, pose),
                                    (hold, breathe(pose, 1))]}


RELAXED_LEGS = dict(RightHip=(0, 0, 0.1), LeftHip=(0, 0, -0.1))
WIDE_LEGS = dict(Root=(0, 0, 0, 0, -0.45, 0), RightHip=(0.35, 0, 0.32), RightKnee=(-0.7, 0, 0), RightAnkle=(0.35, 0, -0.3),
                 LeftHip=(0.35, 0, -0.32), LeftKnee=(-0.7, 0, 0), LeftAnkle=(0.35, 0, 0.3))
CROUCH = P(Root=(0.15, 0, 0, 0, -0.7, 0), Waist=(0.3, 0, 0), Neck=(0.2, 0, 0),
           RightShoulder=(0.5, 0, 0.3), RightElbow=(2.0, 0, 0), LeftShoulder=(0.5, 0, -0.3), LeftElbow=(2.0, 0, 0),
           RightHip=(0.6, 0, 0.2), RightKnee=(-1.1, 0, 0), RightAnkle=(0.5, 0, 0),
           LeftHip=(0.6, 0, -0.2), LeftKnee=(-1.1, 0, 0), LeftAnkle=(0.5, 0, 0))

CLIPS.update({
    # Gojo: floating, right hand up in front of the face, left hand across the chest (the domain sign).
    "SigGojo": sig(CROUCH, P(
        Root=(0, 0.2, 0, 0, 0.55, 0), Waist=(-0.05, -0.15, 0), Neck=(0.12, 0.12, 0.05),
        _R=(0.35, 4.7, 1.1), _L=(-0.05, 3.85, 1.15),
        RightHip=(0.25, 0, 0.06), RightKnee=(-0.55, 0, 0), RightAnkle=(-0.35, 0, 0),
        LeftHip=(0.05, 0, -0.06), LeftKnee=(-0.25, 0, 0), LeftAnkle=(-0.3, 0, 0))),
    # Sukuna: palms pressed together in front of the chest, elbows wide, low and menacing.
    "SigSukuna": sig(CROUCH, P(
        Waist=(0.12, 0, 0), Neck=(0.28, 0, 0),
        _R=(0.12, 3.25, 1.35), _L=(-0.12, 3.25, 1.35), _RE=(1.7, 3.0, 0.6), _LE=(-1.7, 3.0, 0.6),
        **WIDE_LEGS)),
    # JoJo: the twisted, arched "menacing" stand: hand to the face, other arm flung down and back.
    "SigJojo": sig(GUARD, P(
        Root=(0, 0.45, 0, 0, -0.1, 0), Waist=(-0.28, -0.55, 0.22), Neck=(0.15, 0.55, -0.25),
        _R=(0.35, 4.15, 0.75),
        LeftShoulder=(-0.45, 0, -0.65), LeftElbow=(0.35, 0, 0),
        RightHip=(0.35, 0, 0.3), RightKnee=(-0.75, 0, 0), RightAnkle=(0.3, 0, 0),
        LeftHip=(-0.12, 0, -0.18), LeftKnee=(-0.1, 0, 0))),
    # Dragon Ball: cup the energy at the right hip, then thrust both palms forward.
    "SigKamehameha": {"loop": False, "keys": [
        (0, GUARD),
        (0.4, P(Root=(0, 0.6, 0, 0, -0.65, 0), Waist=(0.15, 0.35, 0), Neck=(0, -0.8, 0),
                _R=(1.35, 2.45, 0.35), _L=(0.95, 2.6, 0.75),
                RightHip=(0.7, 0, 0.25), RightKnee=(-1.15, 0, 0), RightAnkle=(0.4, 0, 0),
                LeftHip=(0.2, 0, -0.35), LeftKnee=(-0.75, 0, 0), LeftAnkle=(0.35, 0, 0.2))),
        (1.3, P(Root=(0, 0.65, 0, 0, -0.7, 0), Waist=(0.17, 0.4, 0), Neck=(0, -0.85, 0),
                _R=(1.35, 2.4, 0.35), _L=(0.95, 2.55, 0.75),
                RightHip=(0.72, 0, 0.25), RightKnee=(-1.2, 0, 0), RightAnkle=(0.42, 0, 0),
                LeftHip=(0.2, 0, -0.35), LeftKnee=(-0.75, 0, 0), LeftAnkle=(0.35, 0, 0.2))),
        (1.5, CLIPS["Fire"]["keys"][0][1]),
        (2.6, CLIPS["Fire"]["keys"][1][1]),
    ]},
    # Naruto: a hand seal low at the chest, then the tiger seal up at the chin.
    "SigSeal": {"loop": False, "keys": [
        (0, GUARD),
        (0.35, P(Neck=(0.2, 0, 0), _R=(0.12, 2.9, 1.2), _L=(-0.12, 2.9, 1.2), **WIDE_LEGS)),
        (0.8, P(Neck=(0.05, 0, 0), _R=(0.1, 3.45, 1.0), _L=(-0.1, 3.45, 1.0), **WIDE_LEGS)),
        (1.15, P(Neck=(0.05, 0, 0), _R=(0.1, 3.45, 1.0), _L=(-0.1, 3.45, 1.0), **WIDE_LEGS)),
        (2.4, breathe(P(Neck=(0.05, 0, 0), _R=(0.1, 3.45, 1.0), _L=(-0.1, 3.45, 1.0), **WIDE_LEGS), 1)),
    ]},
    # One Piece: arms thrown wide and up, head back, bouncing with laughter.
    "SigLaugh": {"loop": False, "keys": [(0, GUARD)] + [
        (0.3 + i * 0.28, P(Root=(0, 0, 0, 0, (0.15 if i % 2 else -0.25), 0), Waist=(-0.25, 0, 0),
                           Neck=(-0.55 + (0.1 if i % 2 else 0), 0, 0),
                           RightShoulder=(0.6, 0, 1.9 + (0.15 if i % 2 else 0)), RightElbow=(0.6, 0, 0),
                           LeftShoulder=(0.6, 0, -1.9 - (0.15 if i % 2 else 0)), LeftElbow=(0.6, 0, 0),
                           RightHip=(0.2, 0, 0.28), RightKnee=(-0.4 - (0 if i % 2 else 0.3), 0, 0),
                           LeftHip=(0.2, 0, -0.28), LeftKnee=(-0.4 - (0 if i % 2 else 0.3), 0, 0)))
        for i in range(8)]},
    # My Hero Academia: wind the fist back, then a lunging SMASH.
    "SigSmash": sig(P(Root=(0, -0.5, 0, 0, -0.5, 0), Waist=(0.2, -0.6, 0), Neck=(0, 0.6, 0),
                      RightShoulder=(-0.6, 0, 0.35), RightElbow=(1.9, 0, 0),
                      LeftShoulder=(1.4, 0, -0.1), LeftElbow=(0.4, 0, 0),
                      RightHip=(0.15, 0, 0.2), RightKnee=(-0.6, 0, 0), LeftHip=(0.6, 0, -0.1), LeftKnee=(-0.9, 0, 0)),
                    P(Root=(0.2, 0.45, 0, 0, -0.65, -0.4), Waist=(0.25, 0.4, 0), Neck=(-0.15, -0.45, 0),
                      RightShoulder=(1.6, 0.25, 0), RightElbow=(0.05, 0, 0), RightWrist=(-0.2, 0, 0),
                      LeftShoulder=(-0.5, 0, -0.45), LeftElbow=(1.5, 0, 0),
                      RightHip=(-0.55, 0, 0.1), RightKnee=(-0.2, 0, 0), RightAnkle=(0.5, 0, 0),
                      LeftHip=(1.1, 0, -0.1), LeftKnee=(-1.1, 0, 0), LeftAnkle=(0.2, 0, 0)), wind=0.35, snap=0.5),
    # All Might: chest out, left fist on the hip, right arm up in a thumbs-up ("I am here!").
    "SigAllMight": sig(GUARD, P(
        Root=(0, 0, 0, 0, -0.1, 0), Waist=(-0.15, 0, 0), Neck=(-0.15, 0, 0),
        _R=(1.25, 5.0, 1.3), _L=(-1.15, 2.2, 0.25), _LE=(-2.2, 2.9, -0.2),
        RightHip=(0, 0, 0.22), LeftHip=(0, 0, -0.22))),
    # Attack on Titan: the salute, right fist over the heart, left hand behind the back, chin up.
    "SigSalute": sig(GUARD, P(
        Waist=(-0.05, 0, 0), Neck=(-0.12, 0, 0),
        _R=(-0.45, 3.35, 0.75), _L=(-0.2, 2.45, -0.75),
        **RELAXED_LEGS), wind=0.25, snap=0.45),
    # Bleach: side-on, the sword arm out level, the free hand gripping it (Bankai).
    "SigBankai": sig(GUARD, P(
        Root=(0, 0.85, 0, 0, -0.35, 0), Waist=(0, -0.2, 0), Neck=(0, -0.7, 0),
        RightShoulder=(1.55, -0.6, 0), RightElbow=(0.1, 0, 0), RightWrist=(-0.3, 0, 0),
        _L=(-0.35, 3.3, 1.75),
        RightHip=(0.45, 0, 0.25), RightKnee=(-0.8, 0, 0), RightAnkle=(0.4, 0, 0),
        LeftHip=(-0.35, 0, -0.25), LeftKnee=(-0.2, 0, 0), LeftAnkle=(0.3, 0, 0))),
    # Hunter x Hunter: crouched low, fist drawn back charging, the other palm out (Jajanken).
    "SigJajanken": sig(GUARD, P(
        Root=(0.2, 0.3, 0, 0, -0.95, 0), Waist=(0.25, 0.3, 0), Neck=(-0.1, -0.5, 0),
        RightShoulder=(-0.7, 0, 0.25), RightElbow=(1.9, 0, 0),
        LeftShoulder=(1.35, 0.1, -0.1), LeftElbow=(0.2, 0, 0), LeftWrist=(-1.0, 0, 0),
        RightHip=(0.75, 0, 0.3), RightKnee=(-1.5, 0, 0), RightAnkle=(0.7, 0, 0),
        LeftHip=(0.9, 0, -0.3), LeftKnee=(-1.2, 0, 0), LeftAnkle=(0.4, 0, 0))),
    # Fate: upright, both hands on the hilt of a sword planted in front.
    "SigSword": sig(GUARD, P(
        Waist=(-0.05, 0, 0), Neck=(-0.1, 0, 0),
        _R=(0.1, 2.55, 1.45), _L=(-0.1, 2.75, 1.45),
        RightHip=(0, 0, 0.18), LeftHip=(0, 0, -0.18)), wind=0.3, snap=0.6),
    # Yu Yu Hakusho: the Spirit Gun, right arm straight out pointing, left hand bracing it.
    "SigSpiritGun": sig(GUARD, P(
        Root=(0, 0.5, 0, 0, -0.3, 0), Waist=(0, -0.15, 0), Neck=(0, -0.35, 0),
        RightShoulder=(1.6, -0.3, 0), RightElbow=(0.05, 0, 0),
        _L=(0.35, 3.35, 1.45),
        RightHip=(0.35, 0, 0.2), RightKnee=(-0.6, 0, 0), LeftHip=(-0.25, 0, -0.2), LeftKnee=(-0.15, 0, 0))),
    # Fairy Tail: right arm straight up to the sky (the guild sign), left fist on the hip, looking up.
    "SigGuild": sig(GUARD, P(
        Waist=(-0.12, 0, 0), Neck=(-0.4, 0, 0),
        RightShoulder=(3.05, 0, 0.1), RightElbow=(0.05, 0, 0),
        _L=(-1.15, 2.2, 0.25), _LE=(-2.2, 2.9, -0.2),
        RightHip=(0, 0, 0.2), LeftHip=(0, 0, -0.2))),
    # Everyone else: a double-biceps flex, elbows out at shoulder height, fists by the head.
    "SigFlex": sig(CROUCH, P(
        Root=(0, 0, 0, 0, -0.3, 0), Waist=(-0.1, 0, 0), Neck=(-0.1, 0, 0),
        _R=(1.75, 4.45, 0.2), _RE=(2.75, 3.55, 0.1), _L=(-1.75, 4.45, 0.2), _LE=(-2.75, 3.55, 0.1),
        **{k: v for k, v in WIDE_LEGS.items() if k != "Root"})),
})

# Rarity idles (FighterAnimator picks by the fighter's rarity): Epic and Legendary stand proud, arms crossed;
# Mythic and Secret float off the ground (the floating-Gojo trend), arms loose. Common to Rare keep the guard.
PROUD = P(Root=(0, 0, 0, 0, -0.05, 0), Waist=(-0.08, 0, 0), Neck=(-0.1, 0.1, 0),
          _R=(-0.55, 3.25, 0.75), _L=(0.55, 3.15, 0.8), _RE=(1.55, 3.0, 0.5), _LE=(-1.55, 3.0, 0.5),
          RightHip=(0, 0, 0.16), LeftHip=(0, 0, -0.16))
FLOAT = P(Root=(0, 0, 0, 0, 0.9, 0), Waist=(-0.05, 0, 0), Neck=(-0.05, 0, 0),
          RightShoulder=(0.2, 0, 0.45), RightElbow=(0.5, 0, 0), LeftShoulder=(0.2, 0, -0.45), LeftElbow=(0.5, 0, 0),
          RightHip=(0.35, 0, 0.06), RightKnee=(-0.7, 0, 0), RightAnkle=(-0.4, 0, 0),
          LeftHip=(0.1, 0, -0.06), LeftKnee=(-0.35, 0, 0), LeftAnkle=(-0.35, 0, 0))
CLIPS.update({
    "IdleProud": {"loop": True, "keys": [(0, PROUD), (1.2, breathe(PROUD, 1)), (2.4, PROUD)]},
    "IdleFloat": {"loop": True, "keys": [
        (0, FLOAT),
        (1.5, breathe(dict(FLOAT, Root=(0, 0, 0, 0, 1.2, 0)), 1)),
        (3.0, FLOAT),
    ]},
    # The Naruto run: leaning far forward, both arms straight back, quick steps (a follower on the move).
    "RunNaruto": loop(0.16,
        P(Root=(0.5, 0, 0, 0, -0.35, 0), Waist=(0.35, 0, 0), Neck=(-0.6, 0, 0),
          RightShoulder=(-1.35, 0, 0.15), RightElbow=(0.05, 0, 0), LeftShoulder=(-1.35, 0, -0.15), LeftElbow=(0.05, 0, 0),
          RightHip=(0.4, 0, 0), RightKnee=(-1.4, 0, 0), LeftHip=(-1.0, 0, 0), LeftKnee=(-0.3, 0, 0)),
        P(Root=(0.5, 0, 0, 0, -0.25, 0), Waist=(0.35, 0, 0), Neck=(-0.6, 0, 0),
          RightShoulder=(-1.4, 0, 0.15), RightElbow=(0.05, 0, 0), LeftShoulder=(-1.4, 0, -0.15), LeftElbow=(0.05, 0, 0),
          LeftHip=(0.4, 0, 0), LeftKnee=(-1.4, 0, 0), RightHip=(-1.0, 0, 0), RightKnee=(-0.3, 0, 0))),
})

def preview(names):
    """Keys the named clips onto the stage rigs (left to right) for checking in the viewport."""
    rigs_ = sorted((o for o in bpy.data.objects if o.type == "ARMATURE"), key=lambda o: o.location.x)
    for rig, name in zip(rigs_, names):
        key_clip(rig, name)


# ---------------------------------------------------------------- helpers
def srgb(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, rgb, rough=0.5):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (srgb(rgb[0]), srgb(rgb[1]), srgb(rgb[2]), 1)
    bsdf.inputs["Roughness"].default_value = rough
    return mat


def box(name, size, location, mat, bevel=0.16):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    obj.data.materials.append(mat)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = min(bevel, min(size) * 0.3)
    mod.segments = 4
    mod.limit_method = "NONE"
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def roblox_rotation(x, y, z):
    return C @ (Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(z, 3, "Z")) @ C.transposed()


def build_rig(label, offset, outfit):
    data = bpy.data.armatures.new(label + "_Rig")
    rig = bpy.data.objects.new(label + "_Rig", data)
    bpy.context.scene.collection.objects.link(rig)
    rig.location = (offset, 0, 0)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (size, cz, cx, parent, pivot) in PARTS.items():
        b = data.edit_bones.new(name)
        b.head = Vector((pivot[0], 0, pivot[1]))
        up = name in ("Head", "UpperTorso", "LowerTorso")
        b.tail = Vector((pivot[0], 0, pivot[1] + (0.5 if up else -0.5)))
        b.roll = 0
    for name, (size, cz, cx, parent, pivot) in PARTS.items():
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for name, (size, cz, cx, parent, pivot) in PARTS.items():
        obj = box(label + "_" + name, size, (offset + cx, 0, cz), outfit[name])
        world = obj.matrix_world.copy()
        obj.parent, obj.parent_type, obj.parent_bone = rig, "BONE", name
        obj.matrix_world = world
    head = PARTS["Head"][1]
    extras = [("EyeL", (0.16, 0.05, 0.3), (-0.24, 0.61, head + 0.1), "Eye"),
              ("EyeR", (0.16, 0.05, 0.3), (0.24, 0.61, head + 0.1), "Eye"),
              ("Mouth", (0.34, 0.05, 0.07), (0, 0.61, head - 0.27), "Eye")] + outfit["extras"]
    for n, s, p, m in extras:
        z = p[2] - 4.65 + head if p[2] > 4 else p[2]
        obj = box(label + "_" + n, s, (offset + p[0], p[1], z), outfit[m], bevel=min(s) * 0.3)
        world = obj.matrix_world.copy()
        obj.parent, obj.parent_type, obj.parent_bone = rig, "BONE", "Head"
        obj.matrix_world = world
    rig.show_in_front = True
    data.display_type = "STICK"
    return rig


IK_CACHE = {}
ARMS = {"R": ("RightShoulder", "RightElbow", "RightHand", "RightLowerArm"),
        "L": ("LeftShoulder", "LeftElbow", "LeftHand", "LeftLowerArm")}


def _body_point(rig, bone, tail=True):
    """A bone's tip (or base) in Roblox body axes relative to the rig: (right, up, forward)."""
    pb = rig.pose.bones[bone]
    w = C.transposed() @ (rig.matrix_world @ (pb.tail if tail else pb.head) - rig.location)
    return Vector((w.x, w.y, -w.z))


def solve_arms(rig, pose):
    """Resolves hand targets in a pose: _R / _L = (right, up, forward) where that hand should end up, and
    optionally _RE / _LE = where its elbow should sit. Finds the shoulder (rx, ry, rz) and elbow bend by
    coordinate descent against the rig itself, so the numbers mean the same thing as the game's rig."""
    key = repr(sorted(pose.items()))
    if key in IK_CACHE:
        return IK_CACHE[key]
    plain = {k: v for k, v in pose.items() if not k.startswith("_")}
    for side, (shoulder, elbow, hand, lower) in ARMS.items():
        target = pose.get("_" + side)
        if not target:
            continue
        target, hint = Vector(target), pose.get("_" + side + "E")
        sign = 1 if side == "R" else -1
        x = list(plain.get(shoulder, (1.0, 0, 0))) + [plain.get(elbow, (1.0, 0, 0))[0]]

        def cost(v):
            plain[shoulder], plain[elbow] = (v[0], v[1], v[2]), (max(0.0, v[3]), 0, 0)
            set_pose(rig, plain)
            bpy.context.view_layer.update()
            c = (_body_point(rig, hand) - target).length ** 2
            e = _body_point(rig, lower, tail=False)
            if hint:
                c += 0.3 * (e - Vector(hint)).length ** 2
            # Elbows stay out of the chest.
            c += 2.0 * max(0.0, 1.0 - sign * e.x) ** 2 if e.z < 0.6 else 0
            return c + 0.002 * (v[1] ** 2)

        best, step = cost(x), 0.4
        while step > 0.005:
            moved = False
            for i in range(4):
                for d in (step, -step):
                    y = list(x)
                    y[i] += d
                    c = cost(y)
                    if c < best - 1e-6:
                        x, best, moved = y, c, True
            if not moved:
                step *= 0.5
        plain[shoulder], plain[elbow] = (x[0], x[1], x[2]), (max(0.0, x[3]), 0, 0)
    IK_CACHE[key] = plain
    return plain


def set_pose(rig, pose):
    if any(k.startswith("_") for k in pose):
        pose = solve_arms(rig, pose)
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    for joint, v in pose.items():
        bone = JOINT_TO_BONE[joint]
        pb = rig.pose.bones[bone]
        q = rig.data.bones[bone].matrix_local.to_3x3()
        pb.rotation_quaternion = (q.inverted() @ roblox_rotation(v[0], v[1], v[2]) @ q).to_quaternion()
        if len(v) > 3:
            pb.location = q.inverted() @ (C @ Vector((v[3], v[4], v[5])))


def key_clip(rig, name):
    clip = CLIPS[name]
    action = bpy.data.actions.get(name) or bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = action
    keys = clip["keys"]
    for t, pose in keys:
        pose = pose if pose is not None else keys[0][1]
        set_pose(rig, pose)
        frame = 1 + round(t * FPS)
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("location", frame=frame)
    action.use_fake_user = True
    return action


def export(rig):
    """Samples every clip at EXPORT_FPS and writes src/shared/Clips.lua (Transform per joint per frame)."""
    lines = ["-- Generated by tools/blender/r15_studio.py. Do not edit by hand: change the clips there and re-run.",
             "-- Per clip: fps, loop, frames[i][joint] = { qx, qy, qz, qw, px, py, pz } as Motor6D.Transform.",
             "return {"]
    sc = bpy.context.scene
    for name, clip in CLIPS.items():
        key_clip(rig, name)
        length = clip["keys"][-1][0]
        step = FPS // EXPORT_FPS
        count = 1 + round(length * EXPORT_FPS)
        lines.append("\t%s = {" % name)
        lines.append("\t\tfps = %d," % EXPORT_FPS)
        lines.append("\t\tloop = %s," % ("true" if clip["loop"] else "false"))
        lines.append("\t\tframes = {")
        for i in range(count):
            sc.frame_set(1 + i * step)
            parts = []
            for pb in rig.pose.bones:
                q = rig.data.bones[pb.name].matrix_local.to_3x3()
                rot = C.transposed() @ (q @ pb.rotation_quaternion.to_matrix() @ q.inverted()) @ C
                quat = rot.to_quaternion()
                pos = C.transposed() @ (q @ pb.location)
                vals = [quat.x, quat.y, quat.z, quat.w, pos.x, pos.y, pos.z]
                if max(abs(vals[0]), abs(vals[1]), abs(vals[2]), abs(vals[4]), abs(vals[5]), abs(vals[6])) < 1e-4:
                    continue
                parts.append("%s = { %s }" % (BONE_TO_JOINT[pb.name], ", ".join("%.3g" % x for x in vals)))
            lines.append("\t\t\t{ %s }," % ", ".join(parts))
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    out = os.path.join(ROOT, "src", "shared", "Clips.lua")
    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")
    return out


def outfit(skin, top, bottom, shoes, sleeve=None, belt=None, mats=None, extras=None):
    m = {"Eye": material("Eye", (30, 28, 40), 0.3), "Skin": material("Skin", skin)}
    m["Top"] = material("Top%s" % (top,), top)
    m["Bottom"] = material("Bottom%s" % (bottom,), bottom)
    m["Shoes"] = material("Shoes%s" % (shoes,), shoes)
    m["Sleeve"] = material("Sleeve%s" % ((sleeve or skin),), sleeve or skin)
    m["Belt"] = material("Belt%s" % ((belt or bottom),), belt or bottom)
    for k, v in (mats or {}).items():
        m[k] = material(k, v)
    o = {"Head": m["Skin"], "UpperTorso": m["Top"], "LowerTorso": m["Belt"],
         "RightUpperArm": m["Sleeve"], "LeftUpperArm": m["Sleeve"], "RightLowerArm": m["Skin"],
         "LeftLowerArm": m["Skin"], "RightHand": m["Skin"], "LeftHand": m["Skin"],
         "RightUpperLeg": m["Bottom"], "LeftUpperLeg": m["Bottom"], "RightLowerLeg": m["Bottom"],
         "LeftLowerLeg": m["Bottom"], "RightFoot": m["Shoes"], "LeftFoot": m["Shoes"]}
    o.update(m)
    o["extras"] = extras or []
    return o


def spikes(mat, base_z=5.32, color_h=0.55):
    return [("Hair", (1.4, 1.35, color_h), (0, 0, base_z), mat),
            ("Spike1", (0.5, 0.5, 0.75), (-0.45, 0, base_z + 0.4), mat),
            ("Spike2", (0.5, 0.5, 0.9), (0.05, 0, base_z + 0.48), mat),
            ("Spike3", (0.5, 0.5, 0.7), (0.5, 0, base_z + 0.38), mat)]


def stage():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    skin = (255, 206, 160)
    cast = [
        ("Idle", outfit(skin, (255, 128, 30), (255, 128, 30), (40, 70, 160), sleeve=(255, 128, 30),
                        belt=(40, 70, 160), mats={"HairBlack": (28, 24, 34)}, extras=spikes("HairBlack"))),
        ("PowerUp", outfit(skin, (255, 140, 20), (255, 140, 20), (25, 25, 30), sleeve=(34, 34, 46),
                           mats={"HairBlond": (255, 214, 60), "Band": (44, 56, 100)},
                           extras=spikes("HairBlond") + [("Headband", (1.3, 1.3, 0.22), (0, 0, 5.0), "Band")])),
        ("Fire", outfit(skin, (34, 36, 68), (34, 36, 68), (20, 20, 26), sleeve=(34, 36, 68),
                        mats={"HairWhite": (240, 244, 255), "Blindfold": (22, 22, 28)},
                        extras=spikes("HairWhite") + [("Blindfold", (1.3, 1.3, 0.3), (0, 0, 4.78), "Blindfold")])),
        ("Victory", outfit(skin, (225, 45, 45), (45, 95, 205), (150, 100, 60),
                           mats={"Straw": (240, 205, 110), "HatBand": (200, 32, 32), "HairBlack2": (28, 24, 34)},
                           extras=[("Hair", (1.3, 1.3, 0.35), (0, 0, 5.3), "HairBlack2"),
                                   ("HatBrim", (2.4, 2.4, 0.12), (0, 0, 5.45), "Straw"),
                                   ("HatTop", (1.4, 1.4, 0.55), (0, 0, 5.75), "Straw"),
                                   ("HatBand", (1.45, 1.45, 0.16), (0, 0, 5.56), "HatBand")])),
        ("KO", outfit(skin, (28, 28, 34), (28, 28, 34), (22, 22, 26), sleeve=(28, 28, 34), belt=(240, 240, 246),
                      mats={"HairOrange": (255, 122, 34)}, extras=spikes("HairOrange"))),
        ("Taunt", outfit(skin, (80, 160, 90), (240, 240, 246), (40, 40, 50), sleeve=(80, 160, 90),
                         mats={"HairGreen": (60, 150, 70)}, extras=spikes("HairGreen"))),
    ]
    rigs = []
    for i, (clip, fit) in enumerate(cast):
        rig = build_rig(clip, (i - 2.5) * 5, fit)
        key_clip(rig, clip)
        rigs.append(rig)

    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=17, depth=0.6, location=(0, 0, -0.3))
    bpy.context.active_object.data.materials.append(material("StageStone", (226, 218, 200), 0.65))
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=17.7, depth=0.5, location=(0, 0, -0.42))
    bpy.context.active_object.data.materials.append(material("StageRim", (214, 48, 40), 0.5))
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.0
    sun.color = (1.0, 0.88, 0.74)
    sun.angle = math.radians(4)
    s = bpy.data.objects.new("Sun", sun)
    s.rotation_euler = (math.radians(52), math.radians(8), math.radians(160))
    bpy.context.scene.collection.objects.link(s)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 900
    fill.size = 14
    fill.color = (0.72, 0.82, 1.0)
    f = bpy.data.objects.new("Fill", fill)
    f.location = (-10, 16, 10)
    f.rotation_euler = (Vector((0, 0, 2.5)) - f.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(f)
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.42, 0.62, 0.95, 1)
    bg.inputs["Strength"].default_value = 0.7
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 38
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, 31, 8)
    cam.rotation_euler = (Vector((0, 0, 2.6)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(cam)
    sc = bpy.context.scene
    sc.camera = cam
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = engine
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = 1800, 800
    sc.render.fps = FPS
    sc.frame_start, sc.frame_end = 1, 1 + round(2.0 * FPS)
    sc.view_settings.view_transform = "Standard"
    return rigs


rigs = stage()
print("rigs", len(rigs), "actions", [a.name for a in bpy.data.actions])
