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
  * assets/Hashiras.rbxm      one Model holding the eight Demon Slayer Hashira -> custom_later (no zone yet)

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
}
WHOLE = {
    "baryon naruto.rbxm": "BaryonNaruto", "awakened_sukuna.rbxm": "AwakenedSukuna", "Aokiji.rbxm": "Aokiji",
    "gear5.rbxm": "Gear5Luffy", "roger.rbxm": "Roger", "BeastGohan.rbxm": "BeastGohan", "UIGoku.rbxm": "UIGoku",
    "UEvegeta.rbxm": "UEVegeta", "ss4gogeta.rbxm": "SS4Gogeta", "Gogeta.rbxm": "Gogeta",
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


def save(root, model, key, later=False):
    write_model(root, model, key)  # (writes to custom_later)
    if not later:
        shutil.move(os.path.join(split_models.LATER, key + ".rbxm"), os.path.join(OUT, key + ".rbxm"))
    print("wrote", key, "(later)" if later else "")


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
            save(root, model, HASHIRA[name(model)], later=True)

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


if __name__ == "__main__":
    main()
