"""Inspects the fighter pack and writes the roster with proposed rarities.

    python3 tools/pack/inspect_pack.py anime1.rbxm

Converts the binary .rbxm to XML with Rojo (in a temp folder), then:
  * finds every character rig (a Model with a Humanoid, Head and Torso),
  * scans every script for backdoor patterns,
  * counts the asset types the pack depends on,
  * writes docs/ROSTER.md and tools/pack/roster.json.
Rarities come from the lists below; edit them and re-run to rebalance.
"""
import collections
import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROJO = os.path.expanduser("~/.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo")

RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
INCOME = {"Common": 8, "Uncommon": 35, "Rare": 180, "Epic": 900, "Legendary": 6000, "Mythic": 60000, "Secret": 500000}
# Proposed tiers: ultimate forms and giants at the top, base forms of side characters at the bottom.
TIER = {
    "Secret": ["Attack Titan", "Female Titan", "Mugetsu"],
    "Mythic": ["VEGITO BLUE", "Final Aizen", "KCM MINATO", "8TH GATE", "GER", "DIO AWAKENED",
               "Gojo Satoru (Blindfold Off)", "Saitama", "Madara", "Gilgamesh", "Shunko Yoruichi"],
    "Legendary": ["Gojo Satoru", "Sukuna", "Aizen", "DIO", "Goku Black [NEW]", "VEGITO", "LSSJ BROLY", "SSJR",
                  "Whitebeard", "Shanks", "Itachi", "Pain", "Sage Mode", "Hollow Ichigo", "Vasto", "Bankai Toshiro",
                  "All Might (MODE)", "100% Deku", "Killua Godspeed", "Adult Gon", "Iskandar", "Saber",
                  "Archer (EMIYA)", "Awakened Jolyne", "Accel", "Afro Samurai"],
    "Epic": ["Goku", "Vegeta", "Majin Vegeta", "Buu Saga Goku", "Broly", "Minato", "Kakashi", "Might Guy", "5TH GATE",
             "ROCK LEE GATES", "Ichigo", "Byakuya", "Yamamoto", "Ulq", "Grimmjow", "Kisuke", "Shunsui", "Yoruichi",
             "Neko Yoru", "Akainu", "Kizaru", "Ace", "tsLuffy", "tsZoro", "TS SANJI", "Jotaro", "Giorno",
             "Kira Yoshikage", "Killer Queen", "Doppio", "All Might", "Deku Awakened", "Awakened Bakugo",
             "Natsu Awakened", "Grey Awakening", "Illumi Awakened", "Yusuke Mode", "Hiei (Jagan Eye)", "Lancer Mode",
             "SALTER", "Rikka Awakened", "Eren Post-time skip", "tsNaruto", "tsSasuke", "STONE FREE AURA"],
    "Rare": ["Gaara", "Rock Lee", "Toshiro", "Starrk", "Shinji", "Gin", "Piccolo", "Trunks", "Gohan", "Caulifa",
             "Natsu", "Gray", "Deku", "Bakugo", "Todoroki", "Hellflame", "Yuji", "Tanjiro", "Hisoka", "Illumi",
             "Lancer", "Shirou", "Josuke", "Jolyne", "STONE FREE", "Stand", "Snakeman", "R1", "R2", "ptsLaw", "Eren",
             "Mikasa", "Zabuza", "Speed Guy"],
    "Uncommon": ["Neji", "ptsNaruto", "ptsSasuke", "ptsLuffy", "ptsZoro", "ptsSanji", "Yusuke", "Hiei", "Killua",
                 "Gon", "Lemillion", "Annie", "Erwin", "Old Joseph", "Young Joseph", "Jonathan", "Rin", "Kiritsugu"],
    # Everything else is Common.
}
DANGER = re.compile(r"require\s*\(\s*\d|loadstring|getfenv|setfenv|HttpService|TeleportService|MarketplaceService|"
                    r"InsertService|string\.reverse|\\\d{2,3}")
ASSET_PROPS = {"MeshContent", "TextureContent", "MeshId", "TextureId", "TextureID", "Texture", "ShirtTemplate",
               "PantsTemplate", "AnimationId", "SoundId", "Image", "Graphic"}


def to_xml(rbxm):
    tmp = tempfile.mkdtemp()
    project = os.path.join(tmp, "pack.project.json")
    with open(project, "w") as f:
        json.dump({"name": "pack", "tree": {"$path": os.path.abspath(rbxm)}}, f)
    out = os.path.join(tmp, "pack.rbxmx")
    subprocess.run([ROJO, "build", project, "-o", out], check=True, capture_output=True)
    return out


def name(item):
    props = item.find("Properties")
    for p in props if props is not None else []:
        if p.get("name") == "Name":
            return p.text or ""
    return "?"


def walk(item, path):
    yield item, path
    for child in item.findall("Item"):
        yield from walk(child, path + [name(item)])


def display(raw):
    text = raw.replace("[NEW]", "").strip()
    for prefix, label in (("pts", "Pre-Timeskip"), ("ts", "Timeskip"), ("TS ", "Timeskip")):
        if text.startswith(prefix) and len(text) > len(prefix) and (prefix.endswith(" ") or text[len(prefix)].isupper()):
            return f"{text[len(prefix):].strip().title()} ({label})"
    return text.title() if text.isupper() else text


def main():
    rbxm = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "anime1.rbxm")
    root = ET.parse(to_xml(rbxm)).getroot().find("Item")
    tier_of = {n: r for r, names in TIER.items() for n in names}
    fighters, seen, flagged, assets = [], set(), [], collections.defaultdict(set)
    for item, path in walk(root, []):
        cls = item.get("class")
        props = item.find("Properties")
        for p in props if props is not None else []:
            if p.get("name") in ASSET_PROPS:
                for asset in re.findall(r"(\d{6,})", "".join(p.itertext())):
                    assets[(cls, p.get("name"))].add(asset)
            if p.get("name") == "Source" and DANGER.search("".join(p.itertext())):
                flagged.append("/".join(path + [name(item)]))
        if cls != "Model":
            continue
        kids = item.findall("Item")
        kid_names = {name(k) for k in kids}
        if not (any(k.get("class") == "Humanoid" for k in kids) and "Head" in kid_names and "Torso" in kid_names):
            continue
        raw = name(item).strip()
        series = path[1] if len(path) > 1 else "?"
        if (series, raw) in seen:
            continue
        seen.add((series, raw))
        parts = sum(1 for x, _ in walk(item, []) if x.get("class") in ("Part", "MeshPart", "UnionOperation", "WedgePart"))
        rarity = tier_of.get(raw, "Common")
        fighters.append({"key": re.sub(r"[^A-Za-z0-9]", "", raw.title()), "source": raw, "display": display(raw),
                         "series": series.replace(" Pack", ""), "parentInPack": path[-1], "rarity": rarity,
                         "income": INCOME[rarity], "parts": parts})

    fighters.sort(key=lambda f: (RARITIES.index(f["rarity"]), f["series"], f["display"]))
    with open(os.path.join(ROOT, "tools", "pack", "roster.json"), "w") as f:
        json.dump(fighters, f, indent=1)

    counts = collections.Counter(f["rarity"] for f in fighters)
    lines = ["# Fighter roster (from the pack)", "",
             f"Generated by `tools/pack/inspect_pack.py` from `{os.path.basename(rbxm)}`. Rarities and incomes are a "
             "first proposal; edit the lists in the script and re-run.", "",
             f"**{len(fighters)} fighters** (classic R6 avatars), "
             + ", ".join(f"{counts[r]} {r}" for r in RARITIES) + ".", "",
             f"**Script scan:** {len(flagged)} scripts match backdoor patterns."
             + (" " + "; ".join(flagged[:10]) if flagged else ""), "",
             "**External assets the pack depends on:** "
             + ", ".join(f"{len(v)} {c}.{p}" for (c, p), v in sorted(assets.items())) + ".", "",
             "| Rarity | Fighter | Series | $/s | Parts | Pack name |", "|---|---|---|---:|---:|---|"]
    lines += [f"| {f['rarity']} | {f['display']} | {f['series']} | {f['income']:,} | {f['parts']} | `{f['source']}` |"
              for f in fighters]
    with open(os.path.join(ROOT, "docs", "ROSTER.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{len(fighters)} fighters; {dict(counts)}; {len(flagged)} flagged scripts")


if __name__ == "__main__":
    main()
