"""Copies the hand-made fighter files from ~/Documents/anime_models into tools/pack/custom/<Key>.rbxm, one model per
file (upper_moon.rbxm holds ten characters: each is cut out into its own file).

    python3 tools/pack/split_models.py [folder]

strip_pack.py then turns every file in tools/pack/custom into a clean fighter (scripts, health bars, sounds, particles
and anything else that is not the body and what it wears are removed there, not here).
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROJO = os.path.expanduser("~/.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo")
OUT = os.path.join(ROOT, "tools", "pack", "custom")
LATER = os.path.join(ROOT, "tools", "pack", "custom_later")  # not in the game yet: see its README

WHOLE = {  # file -> fighter key
    "beerus": "Beerus", "big_mom": "BigMom", "cell_max": "CellMax", "doflamingo": "Doflamingo", "frieza": "Frieza",
    "fujitora": "Fujitora", "kaido": "Kaido", "mihawk": "Mihawk", "rayleigh": "Rayleigh", "sengoku": "Sengoku",
}
UPPER_MOON = {  # model name inside upper_moon.rbxm -> fighter key
    "hantengu": "Hantengu", "Nakime": "Nakime", "Akaza": "Akaza", "Douma": "Douma", "Gyutaro": "Gyutaro",
    "Gyokko": "Gyokko", "Kaigaku": "Kaigaku", "Kokushibo": "Kokushibo", " ": "Daki",
    "tanjiro demon king": "TanjiroDemonKing",
}


def to_xml(rbxm):
    tmp = tempfile.mkdtemp()
    project = os.path.join(tmp, "p.project.json")
    with open(project, "w") as f:
        json.dump({"name": "pack", "tree": {"$path": os.path.abspath(rbxm)}}, f)
    out = os.path.join(tmp, "p.rbxmx")
    subprocess.run([ROJO, "build", project, "-o", out], check=True, capture_output=True)
    return out


def name(item):
    for p in item.find("Properties"):
        if p.get("name") == "Name":
            return p.text
    return ""


def write_model(root, model, key):
    keep = ET.Element("roblox", {"version": "4"})
    shared = root.find("SharedStrings")
    if shared is not None:
        keep.append(shared)
    keep.append(model)
    tmp = tempfile.mkdtemp()
    xml_path = os.path.join(tmp, key + ".rbxmx")
    ET.ElementTree(keep).write(xml_path, encoding="utf-8", xml_declaration=False)
    project = os.path.join(tmp, "p.project.json")
    with open(project, "w") as f:
        json.dump({"name": key, "tree": {"$path": xml_path}}, f)
    subprocess.run([ROJO, "build", project, "-o", os.path.join(LATER, key + ".rbxm")], check=True, capture_output=True)


def main():
    src = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Documents/anime_models")
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(LATER, exist_ok=True)
    for stem, key in WHOLE.items():
        shutil.copy(os.path.join(src, stem + ".rbxm"), os.path.join(OUT, key + ".rbxm"))
        print("copied", key)
    root = ET.parse(to_xml(os.path.join(src, "upper_moon.rbxm"))).getroot()
    pack = root.find("Item")
    for model in pack.findall("Item"):
        key = UPPER_MOON.get(name(model))
        if key:
            write_model(root, model, key)
            print("split ", key)
        else:
            print("skipped (not in UPPER_MOON):", repr(name(model)))


if __name__ == "__main__":
    main()
