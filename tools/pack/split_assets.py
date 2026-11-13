"""Cuts the fighters out of the Toolbox files in assets/ into tools/pack/custom/<Key>.rbxm (one rig each), or
tools/pack/custom_later/ for series not in the game yet.

    python3 tools/pack/split_assets.py

  * assets/naruto_pack.rbxm   six rigs side by side (Pain, Jiraiya, Kaguya, Orochimaru, Hashirama, Tsunade)
  * assets/6pathsnaruto.rbxm  a bare R6 body plus loose morph models (hair, cloak, Kurama sleeves, shoes, the
                              Truth-Seeking Orbs). The morphs are moved INSIDE the body, each container renamed after
                              the limb it sits on, so strip_pack welds the sleeves to the arms (not the head).
  * assets/baryon naruto.rbxm one NPC rig (its health bar, attack and respawn scripts go in strip_pack)
  * assets/AOT.rbxm           Eren, Levi, Mikasa, Armored Titan (the pack's own Eren and Mikasa stay)
  * assets/awakened_sukuna.rbxm one rig
  * one rig each: Aokiji, gear5 (Luffy Gear 5), roger, BeastGohan, UIGoku, UEvegeta, ss4gogeta, Gogeta
  * assets/Hashiras.rbxm      one Model holding the eight Demon Slayer Hashira (the Hub)
  * assets/demonslayer.rbxm  Tanjiro, Zenitsu, Inosuke, Nezuko (the Hub); erza.rbxm one rig

The files hold several top-level instances, which Rojo can't read, so rbxm_bin.wrap() puts them in one Folder
first. The Six Paths file also carries a fake "setup window" LocalScript (ScreenBuilder/Runtime): never drag it
into Studio as is; strip_pack removes every script.
"""
import math
import os
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rbxm_bin  # noqa: E402
from split_models import OUT, ROOT, name, to_xml, write_model  # noqa: E402
import split_models  # noqa: E402

ASSETS = os.path.join(ROOT, "assets")
# file -> {model name -> fighter key}; None skips it (the pack already has a look the game uses).
PACKS = {
    "naruto_pack.rbxm": {
        "Jiraiya": "Jiraiya", "Kaguya": "Kaguya", "Orochimaru": "Orochimaru", "Senju Hashirama R15": "Hashirama",
        "Tsunade": "Tsunade", "pain": None,
    },
    "AOT.rbxm": {"Levi": "Levi", "Armored Titan": "ArmoredTitan", "Eren": None, "Mikasa": None},
    # (its Tanjiro replaces the pack's look)
    "demonslayer.rbxm": {"Tanjiro": "Tanjiro", "Zenitsu": "Zenitsu", "Inosuke": "Inosuke", "Nezuko": "Nezuko"},
    # (its Deku takes Deku Awakened's place in Blossom Academy)
    "mha.rbxm": {"Shigaraki": "Shigaraki", "Kirishima": "Kirishima", "Deku": "DekuOFA", "Dabi": "Dabi",
                 "All for One": "AllForOne", "Aizawa": "Aizawa"},
}
WHOLE = {
    "baryon naruto.rbxm": "BaryonNaruto", "awakened_sukuna.rbxm": "AwakenedSukuna", "Aokiji.rbxm": "Aokiji",
    "gear5.rbxm": "Gear5Luffy", "roger.rbxm": "Roger", "BeastGohan.rbxm": "BeastGohan", "UIGoku.rbxm": "UIGoku",
    "UEvegeta.rbxm": "UEVegeta", "ss4gogeta.rbxm": "SS4Gogeta", "Gogeta.rbxm": "Gogeta",
    "erza.rbxm": "Erza", "beasttitan.rbxm": "BeastTitan",
}
HASHIRA = {  # inside assets/Hashiras.rbxm's one Model
    "Sanemi": "Sanemi", "Rengoku": "Rengoku", "Iguro": "Iguro", "Muichiro": "Muichiro", "Shinobu": "Shinobu",
    "Giyu": "Giyu", "Gyomei": "Gyomei", "Mitsuri": "Mitsuri",
}
BODY = ("Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg")
LABEL = {"Head": "Head", "Torso": "Torso", "Left Arm": "LeftArm", "Right Arm": "RightArm", "Left Leg": "LeftLeg",
         "Right Leg": "RightLeg"}


def pos(item):
    for p in item.find("Properties"):
        if p.get("name") == "CFrame":
            return tuple(float(p.find(k).text) for k in ("X", "Y", "Z"))
    return None


def wrapped_xml(path):
    tmp = tempfile.mkdtemp()
    out = os.path.join(tmp, "w.rbxm")
    rbxm_bin.wrap(path, out)
    return ET.parse(to_xml(out)).getroot()


def unwrap(model):
    """Some exports keep the real rig one level down (Jiraiya's "StarterCharacter", Nezuko's unnamed Model):
    strip_pack drops nested rigs, so the inner rig becomes the fighter (named after the outer one)."""
    if any(k.get("class") == "Humanoid" for k in model.findall("Item")):
        return model
    inner = [k for k in model.findall("Item") if k.get("class") == "Model" and any(
        c.get("class") == "Humanoid" for c in k.findall("Item"))]
    if len(inner) != 1:
        return model
    for p in inner[0].find("Properties"):
        if p.get("name") == "Name":
            p.text = name(model)
    return inner[0]


def save(root, model, key, later=False):
    model = unwrap(model)
    write_model(root, model, key)  # (writes to custom_later)
    if not later:
        shutil.move(os.path.join(split_models.LATER, key + ".rbxm"), os.path.join(OUT, key + ".rbxm"))
    print("wrote", key, "(later)" if later else "")


# ---------------------------------------------------------------- titans without a rig
# The Jaw and Cart Titan files are welded meshes with no Humanoid or joints. They get an invisible R6 skeleton
# sized to them (FighterRig.HIDDEN_BODY hides the R15 body built from it); strip_pack's adopt_orphans then welds
# each mesh cluster to its nearest limb (Jaw) or, inside a "TorsoMorph" model, all of it to the torso (Cart, on four
# legs). Their own meshes named like body parts are renamed first so they can't be taken for the skeleton.
R6_NAMES = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}


def _cf(item):
    for p in item.find("Properties"):
        if p.get("name") == "CFrame":
            return p
    return None


def _part(parent, name, pos, size, ref):
    it = ET.SubElement(parent, "Item", {"class": "Part", "referent": ref})
    pr = ET.SubElement(it, "Properties")
    ET.SubElement(pr, "string", {"name": "Name"}).text = name
    cf = ET.SubElement(pr, "CoordinateFrame", {"name": "CFrame"})
    for k, v in zip(("X", "Y", "Z"), pos):
        ET.SubElement(cf, k).text = repr(float(v))
    for k, v in zip(("R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"), (1, 0, 0, 0, 1, 0, 0, 0, 1)):
        ET.SubElement(cf, k).text = str(v)
    sz = ET.SubElement(pr, "Vector3", {"name": "size"})
    for k, v in zip(("X", "Y", "Z"), size):
        ET.SubElement(sz, k).text = repr(float(v))
    ET.SubElement(pr, "float", {"name": "Transparency"}).text = "1"
    ET.SubElement(pr, "bool", {"name": "CanCollide"}).text = "false"
    ET.SubElement(pr, "bool", {"name": "Anchored"}).text = "false"
    return it


def turn_y(model, degrees, pivot):
    """Turns every part of `model` about the vertical axis through `pivot` (to make a model face -Z)."""
    a = math.radians(degrees)
    c, s_ = math.cos(a), math.sin(a)
    rot = ((c, 0, s_), (0, 1, 0), (-s_, 0, c))
    for item in model.iter("Item"):
        cf = _cf(item)
        if cf is None:
            continue
        g = {k.tag: float(k.text) for k in cf}
        x, z = g["X"] - pivot[0], g["Z"] - pivot[2]
        g["X"], g["Z"] = pivot[0] + rot[0][0] * x + rot[0][2] * z, pivot[2] + rot[2][0] * x + rot[2][2] * z
        m = [[g["R%d%d" % (i, j)] for j in range(3)] for i in range(3)]
        r = [[sum(rot[i][k] * m[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
        for i in range(3):
            for j in range(3):
                g["R%d%d" % (i, j)] = r[i][j]
        for k in cf:
            k.text = repr(g[k.tag])


def skeleton(model, key, scale, torso, all_on_torso=False):
    """Adds an invisible R6 body (scale = R6 units; `torso` = where the Torso's centre goes) and a Humanoid."""
    for item in model.iter("Item"):
        if item.get("class") in ("Part", "MeshPart", "UnionOperation") and name(item) in R6_NAMES:
            for p in item.find("Properties"):
                if p.get("name") == "Name":
                    p.text = "Titan" + p.text.replace(" ", "")
    if all_on_torso:
        morph = ET.Element("Item", {"class": "Model", "referent": "SKEL_MORPH"})
        ET.SubElement(ET.SubElement(morph, "Properties"), "string", {"name": "Name"}).text = "TorsoMorph"
        for child in list(model.findall("Item")):
            model.remove(child)
            morph.append(child)
        model.append(morph)
    x, y, z = torso
    k = scale
    for nm, off, size in (
        ("HumanoidRootPart", (0, 0, 0), (2, 2, 1)),
        ("Torso", (0, 0, 0), (2, 2, 1)),
        ("Head", (0, 1.5, 0), (2, 1, 1)),
        ("Left Arm", (-1.5, 0, 0), (1, 2, 1)),
        ("Right Arm", (1.5, 0, 0), (1, 2, 1)),
        ("Left Leg", (-0.5, -2, 0), (1, 2, 1)),
        ("Right Leg", (0.5, -2, 0), (1, 2, 1)),
    ):
        _part(model, nm, (x + off[0] * k, y + off[1] * k, z + off[2] * k), [v * k for v in size], "SKEL_" + key + nm.replace(" ", ""))
    hum = ET.SubElement(model, "Item", {"class": "Humanoid", "referent": "SKEL_" + key + "Humanoid"})
    ET.SubElement(ET.SubElement(hum, "Properties"), "string", {"name": "Name"}).text = "Humanoid"


def parts_box(model):
    lo, hi = [1e9] * 3, [-1e9] * 3
    for item in model.iter("Item"):
        if item.get("class") not in ("Part", "MeshPart", "UnionOperation"):
            continue
        cf = _cf(item)
        size = next((p for p in item.find("Properties") if p.get("name") in ("size", "Size")), None)
        if cf is None or size is None:
            continue
        c = [float(cf.find(a).text) for a in "XYZ"]
        h = [float(size.find(a).text) / 2 for a in "XYZ"]
        for i in range(3):
            lo[i], hi[i] = min(lo[i], c[i] - h[i]), max(hi[i], c[i] + h[i])
    return lo, hi


def rig_titans():
    tmp = tempfile.mkdtemp()
    # Jaw Titan: R6 proportions already (torso 18.6 tall: scale 9.3), facing -Z.
    root = ET.parse(to_xml(os.path.join(ASSETS, "jawtitan.rbxm"))).getroot()
    model = root.find("Item")
    torso = next(i for i in model.iter("Item") if name(i) == "Torso" and i.get("class") == "MeshPart")
    t = [float(_cf(torso).find(a).text) for a in "XYZ"]
    skeleton(model, "JawTitan", 9.3, t)
    save(root, model, "JawTitan")
    # Cart Titan: on four legs, its head at -X: turned to face -Z, everything welded to the torso.
    root = ET.parse(to_xml(os.path.join(ASSETS, "carttitan.rbxm"))).getroot()
    model = root.find("Item")
    lo, hi = parts_box(model)
    mid = [(lo[i] + hi[i]) / 2 for i in range(3)]
    turn_y(model, -90, mid)
    lo, hi = parts_box(model)
    k = (hi[1] - lo[1]) / 5  # the skeleton spans the titan's height (an R6 body is 5 units tall)
    skeleton(model, "CartTitan", k, ((lo[0] + hi[0]) / 2, lo[1] + 3 * k, (lo[2] + hi[2]) / 2), all_on_torso=True)
    save(root, model, "CartTitan")


def main():
    os.makedirs(OUT, exist_ok=True)
    for fname, keys in PACKS.items():
        root = wrapped_xml(os.path.join(ASSETS, fname))
        for model in root.find("Item").findall("Item"):
            key = keys.get(name(model), "?")
            if key == "?":
                print("skipped (not in PACKS):", fname, repr(name(model)))
            elif key:
                save(root, model, key)

    root = ET.parse(to_xml(os.path.join(ASSETS, "Hashiras.rbxm"))).getroot()
    for model in root.find("Item").findall("Item"):
        if name(model) in HASHIRA:
            save(root, model, HASHIRA[name(model)])  # (the Hub)

    root = wrapped_xml(os.path.join(ASSETS, "6pathsnaruto.rbxm"))
    pack = root.find("Item")
    rig = next(m for m in pack.findall("Item") if name(m) == "R6")
    body = {name(k): pos(k) for k in rig.findall("Item") if name(k) in BODY}
    for model in [m for m in pack.findall("Item") if m is not rig]:
        points = [pos(p) for p in model.iter("Item") if p.get("class") in ("Part", "MeshPart", "UnionOperation")]
        points = [p for p in points if p]
        if not points:
            continue
        centre = tuple(sum(p[k] for p in points) / len(points) for k in range(3))
        limb = "Torso" if "Orbs" in name(model) else min(body, key=lambda b: math.dist(body[b], centre))
        for p in model.find("Properties"):
            if p.get("name") == "Name":
                p.text = LABEL[limb] + "Morph"
        pack.remove(model)
        rig.append(model)
        print("  six paths:", LABEL[limb] + "Morph", len(points), "parts")
    save(root, rig, "SixPathsNaruto")

    for fname, key in WHOLE.items():
        shutil.copy(os.path.join(ASSETS, fname), os.path.join(OUT, key + ".rbxm"))
        print("wrote", key)
    rig_titans()


if __name__ == "__main__":
    main()
