"""Turns the ripped fighting-game pack into clean display fighters.

    python3 tools/pack/strip_pack.py [anime1.rbxm]

Reads the pack (converted to XML with Rojo) and tools/pack/roster.json, and writes
assets/models/Fighters.rbxm (binary, ~2.7 MB; the XML form is ~33 MB): one Folder holding one
Model per roster fighter, named by its key. Rojo maps it to ReplicatedStorage.Assets.Fighters.

Each fighter keeps only how it looks:
  * the R6 body (Head, Torso, arms, legs, HumanoidRootPart) and every visible part joined to it
    through welds/Motor6Ds (hair, accessories, weapons worn on the body),
  * meshes, clothing (Shirt/Pants), body colours, face and texture decals, one Humanoid
    (R6 clothing only renders with a Humanoid).
Everything from the original game's move set is removed: scripts, sounds, animations, trails,
beams, particles, lights, GUIs (rank tags), values, remotes, invisible hitbox/effect parts, parts
not attached to the body, and any nested rig (stands and name-tag models are their own entries).
"""
import collections
import copy
import json
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROJO = os.path.expanduser("~/.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo")
OUT = os.path.join(ROOT, "assets", "models", "Fighters.rbxm")

BODY = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}
# Hand-made fighters can already be R15 (Mihawk, Daki): their body parts count as the body too.
BODY |= {
    "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand",
    "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot",
}
PARTS = {"Part", "MeshPart", "UnionOperation", "WedgePart", "CornerWedgePart", "TrussPart"}
JOINTS = {"Weld", "ManualWeld", "Snap", "Motor6D", "Motor", "Glue", "WeldConstraint"}
KEEP = PARTS | JOINTS | {
    "Model", "Folder", "Humanoid", "Shirt", "Pants", "ShirtGraphic", "BodyColors", "CharacterMesh",
    "SpecialMesh", "BlockMesh", "CylinderMesh", "FileMesh", "Decal", "Texture", "SurfaceAppearance",
    "Attachment", "Accessory", "Hat", "Accoutrement", "WrapLayer", "WrapTarget",
}


def to_xml(rbxm):
    tmp = tempfile.mkdtemp()
    project = os.path.join(tmp, "pack.project.json")
    with open(project, "w") as f:
        json.dump({"name": "pack", "tree": {"$path": os.path.abspath(rbxm)}}, f)
    out = os.path.join(tmp, "pack.rbxmx")
    subprocess.run([ROJO, "build", project, "-o", out], check=True, capture_output=True)
    return out


def prop(item, key):
    props = item.find("Properties")
    for p in props if props is not None else []:
        if p.get("name") == key:
            return p
    return None


def name(item):
    p = prop(item, "Name")
    return (p.text or "") if p is not None else "?"


def set_name(item, value):
    prop(item, "Name").text = value


def walk(item):
    yield item
    for child in item.findall("Item"):
        yield from walk(child)


def is_rig(item):
    kids = item.findall("Item")
    names = {name(k) for k in kids}
    return item.get("class") == "Model" and any(k.get("class") == "Humanoid" for k in kids) and "Head" in names and "Torso" in names


def remove(parent_of, item):
    parent_of[item].remove(item)


def cframe(el):
    """XML CoordinateFrame -> (position, 3x3 rotation rows)."""
    v = {c.tag: float(c.text) for c in el}
    pos = (v["X"], v["Y"], v["Z"])
    rot = ((v["R00"], v["R01"], v["R02"]), (v["R10"], v["R11"], v["R12"]), (v["R20"], v["R21"], v["R22"]))
    return pos, rot


def apply(cf, point):
    (px, py, pz), r = cf
    x, y, z = point
    return (px + r[0][0] * x + r[0][1] * y + r[0][2] * z,
            py + r[1][0] * x + r[1][1] * y + r[1][2] * z,
            pz + r[2][0] * x + r[2][1] * y + r[2][2] * z)


def reconnect(rig, parent_of):
    """The pack's morph scripts filled in some welds at runtime: the AOT hair is a part called
    "Handle" with an unconnected weld named "Handle" inside the Head that still carries the right
    offset. Connect such welds from their body part to the matching part (nearest one if several)."""
    parts_by_name = collections.defaultdict(list)
    for item in walk(rig):
        if item.get("class") in PARTS and name(item) not in BODY:
            parts_by_name[name(item)].append(item)
    taken = set()
    for joint in list(walk(rig)):
        if joint.get("class") not in ("Weld", "ManualWeld", "Snap"):
            continue
        p0, p1 = prop(joint, "Part0"), prop(joint, "Part1")
        owner = parent_of.get(joint)
        if p0 is None or p1 is None or p0.text != "null" or p1.text != "null" or owner is None:
            continue
        if owner.get("class") not in PARTS or name(owner) not in BODY:
            continue
        candidates = [c for c in parts_by_name.get(name(joint), []) if c.get("referent") not in taken]
        if not candidates:
            continue
        # Where C0 says the attached part's origin sits (C1 is the identity in every case seen).
        target = apply(cframe(prop(owner, "CFrame")), cframe(prop(joint, "C0"))[0])

        def distance(c):
            q = cframe(prop(c, "CFrame"))[0]
            return sum((a - b) ** 2 for a, b in zip(q, target))

        best = min(candidates, key=distance)
        taken.add(best.get("referent"))
        p0.text = owner.get("referent")
        p1.text = best.get("referent")



HINTS = (  # a container's name says which limb its pieces sit on (checked nearest container first)
    ("head", "Head"), ("hat", "Head"), ("torso", "Torso"),
    ("rightarm", "Right Arm"), ("rarm", "Right Arm"), ("leftarm", "Left Arm"), ("larm", "Left Arm"),
    ("rightleg", "Right Leg"), ("rleg", "Right Leg"), ("leftleg", "Left Leg"), ("lleg", "Left Leg"),
)


def adopt_orphans(rig, parent_of):
    """Hand-made fighters (tools/pack/custom) sometimes leave pieces unjoined (accessories that the game would have
    welded at runtime). Group the unjoined visible pieces into connected clusters and weld each cluster to the body
    part its container is named for (Hats, AccessoriesRightArm, larm...), else to the nearest body part."""
    body = {name(k): k for k in rig.findall("Item") if k.get("class") in PARTS and name(k) in BODY}
    if "Torso" not in body and "UpperTorso" not in body:
        return 0
    graph = collections.defaultdict(set)
    for j in walk(rig):
        if j.get("class") in JOINTS:
            ends = [prop(j, k) for k in ("Part0", "Part1", "Part0Internal", "Part1Internal")]
            ends = [e.text for e in ends if e is not None and e.text and e.text != "null"]
            if len(ends) == 2:
                graph[ends[0]].add(ends[1])
                graph[ends[1]].add(ends[0])
    # Everything already reachable from the body is fine.
    reached = {b.get("referent") for b in body.values()}
    queue = collections.deque(reached)
    while queue:
        for nxt in graph[queue.popleft()]:
            if nxt not in reached:
                reached.add(nxt)
                queue.append(nxt)
    loose = [i for i in walk(rig) if i.get("class") in PARTS and i.get("referent") not in reached]
    seen, welded = set(), 0
    for part in loose:
        if part.get("referent") in seen:
            continue
        cluster, queue = [part], collections.deque([part.get("referent")])
        seen.add(part.get("referent"))
        by_ref = {i.get("referent"): i for i in loose}
        while queue:
            for nxt in graph[queue.popleft()]:
                if nxt in by_ref and nxt not in seen:
                    seen.add(nxt)
                    cluster.append(by_ref[nxt])
                    queue.append(nxt)
        def shown(c):
            t = prop(c, "Transparency")
            # (An invisible plate that carries a face decal or texture counts: dropping it loses the face.)
            carries = any(k.get("class") in ("Decal", "Texture", "SurfaceGui") for k in c.findall("Item"))
            return t is None or float(t.text or 0) < 0.95 or carries

        visible = [c for c in cluster if shown(c)]
        if not visible:
            continue
        target = None
        for c in visible[:1]:
            node = parent_of.get(c)
            while node is not None and node is not rig and target is None:
                label = name(node).lower().replace(" ", "")
                for hint, limb in HINTS:
                    if hint in label and limb in body:
                        target = body[limb]
                        break
                node = parent_of.get(node)
        centre = tuple(sum(cframe(prop(c, "CFrame"))[0][k] for c in visible) / len(visible) for k in range(3))
        if target is None:
            # (Never the invisible root: FighterRig skips anything welded to it, so those pieces would vanish.)
            target = min(
                (b for n, b in body.items() if n != "HumanoidRootPart"),
                key=lambda b: sum((a - q) ** 2 for a, q in zip(cframe(prop(b, "CFrame"))[0], centre)),
            )
        anchor = min(visible, key=lambda c: sum((a - q) ** 2 for a, q in zip(cframe(prop(c, "CFrame"))[0], cframe(prop(target, "CFrame"))[0])))
        weld = ET.SubElement(rig, "Item", {"class": "WeldConstraint", "referent": "ADOPT" + anchor.get("referent")})
        props = ET.SubElement(weld, "Properties")
        ET.SubElement(props, "string", {"name": "Name"}).text = "AdoptWeld"
        ET.SubElement(props, "Ref", {"name": "Part0Internal"}).text = target.get("referent")
        ET.SubElement(props, "Ref", {"name": "Part1Internal"}).text = anchor.get("referent")
        ET.SubElement(props, "bool", {"name": "Enabled"}).text = "true"
        parent_of[weld] = rig
        welded += 1
    return welded


MORPH_STATS = collections.Counter()


def attach_morphs(rig, parent_of):
    """Morph models (hair, headbands) whose welds the original game filled in at runtime: the morph has its
    own "Head" part sitting exactly on the body's Head, and its pieces' welds point at nothing. Weld every
    piece of such a morph to the body Head at its saved position (WeldConstraints keep the saved offset)."""
    body_head = next((k for k in rig.findall("Item") if name(k) == "Head" and k.get("class") in PARTS), None)
    if body_head is None:
        return
    head_pos = cframe(prop(body_head, "CFrame"))[0]
    # Parts already joined by a working joint keep it (only orphans get the morph weld).
    joined = set()
    for j in walk(rig):
        if j.get("class") in JOINTS:
            ends = [prop(j, k) for k in ("Part0", "Part1", "Part0Internal", "Part1Internal")]
            ends = [e.text for e in ends if e is not None and e.text and e.text != "null"]
            if len(ends) == 2:
                joined.update(ends)
    for model in [m for m in walk(rig) if m.get("class") == "Model" and m is not rig]:
        if any(k.get("class") == "Humanoid" for k in model.findall("Item")):
            continue  # a nested rig (stand, name tag): not a morph
        mhead = next((k for k in model.findall("Item") if name(k) == "Head" and k.get("class") in PARTS), None)
        aligned = mhead is not None and sum(
            (a - b) ** 2 for a, b in zip(cframe(prop(mhead, "CFrame"))[0], head_pos)
        ) <= 0.25
        for part in (i for i in walk(model) if i.get("class") in PARTS):
            if part.get("referent") in joined:
                continue
            pos = cframe(prop(part, "CFrame"))[0]
            # The whole morph if its own Head sits on the body's; else only the pieces at the head (hair).
            if not aligned and sum((a - b) ** 2 for a, b in zip(pos, head_pos)) > 2.5**2:
                continue
            weld = ET.SubElement(rig, "Item", {"class": "WeldConstraint", "referent": "MORPH" + part.get("referent")})
            props = ET.SubElement(weld, "Properties")
            ET.SubElement(props, "string", {"name": "Name"}).text = "MorphWeld"
            ET.SubElement(props, "Ref", {"name": "Part0Internal"}).text = body_head.get("referent")
            ET.SubElement(props, "Ref", {"name": "Part1Internal"}).text = part.get("referent")
            ET.SubElement(props, "bool", {"name": "Enabled"}).text = "true"
            parent_of[weld] = rig
            MORPH_STATS[name(rig)] += 1


def strip(rig, key):
    """Strips a deep copy of one rig in place and returns stats."""
    parent_of = {c: p for p in walk(rig) for c in p.findall("Item")}
    before = sum(1 for i in walk(rig) if i.get("class") in PARTS)

    # Nested rigs (JoJo stands, "[ SEMI-PRO ]" name-tag models) are separate entries or junk.
    for item in list(walk(rig)):
        if item is not rig and item in parent_of and item.get("class") == "Model" and any(
            k.get("class") == "Humanoid" for k in item.findall("Item")
        ):
            remove(parent_of, item)
    parent_of = {c: p for p in walk(rig) for c in p.findall("Item")}

    # Disallowed classes go, with everything under them.
    for item in list(walk(rig)):
        if item is not rig and item in parent_of and item.get("class") not in KEEP:
            remove(parent_of, item)
    parent_of = {c: p for p in walk(rig) for c in p.findall("Item")}

    reconnect(rig, parent_of)
    attach_morphs(rig, parent_of)

    # Keep only visible parts joined (directly or through other parts) to the body.
    by_ref = {i.get("referent"): i for i in walk(rig)}
    graph = collections.defaultdict(set)
    for joint in (i for i in walk(rig) if i.get("class") in JOINTS):
        refs = [prop(joint, k) for k in ("Part0", "Part1", "Part0Internal", "Part1Internal")]
        ends = [r.text for r in refs if r is not None and r.text and r.text != "null"]
        if len(ends) == 2:
            graph[ends[0]].add(ends[1])
            graph[ends[1]].add(ends[0])
    body = [k for k in rig.findall("Item") if k.get("class") in PARTS and name(k) in BODY]
    # Breadth-first from the body, remembering how each part was reached, so the invisible connector parts
    # a visible part hangs from (a face plate welded to an invisible "Middle" welded to the head) can stay.
    reached = set()
    came_from = {}
    queue = collections.deque(b.get("referent") for b in body)
    for b in body:
        reached.add(b.get("referent"))
    while queue:
        ref = queue.popleft()
        for nxt in graph[ref]:
            if nxt not in reached:
                reached.add(nxt)
                came_from[nxt] = ref
                queue.append(nxt)

    def draws(part):
        # A transparent part can still show a decal or texture: packs put the face on an invisible
        # "Face" plate in front of the head this way, so those parts must stay.
        return any(c.get("class") in ("Decal", "Texture", "SurfaceGui") for c in part.findall("Item"))

    def visible(part):
        # Body parts always stay (some rigs hide the real Head behind a "FakeHead" that carries the
        # face); other invisible parts are hitboxes and effect anchors, unless they draw something.
        t = prop(part, "Transparency")
        return (
            (name(part) in BODY and parent_of.get(part) is rig)
            or t is None
            or float(t.text or 0) < 0.95
            or draws(part)
        )

    # Every part on the way from the body to a visible part is kept, even when invisible itself.
    holds = set()
    for item in walk(rig):
        if item.get("class") in PARTS and item.get("referent") in reached and visible(item):
            ref = came_from.get(item.get("referent"))
            while ref is not None and ref not in holds:
                holds.add(ref)
                ref = came_from.get(ref)

    for item in list(walk(rig)):
        if item.get("class") in PARTS and item in parent_of:
            ref = item.get("referent")
            if ref not in reached or not (visible(item) or ref in holds):
                remove(parent_of, item)
    parent_of = {c: p for p in walk(rig) for c in p.findall("Item")}

    # Joints, PrimaryPart and other refs must point inside what's left.
    present = {i.get("referent") for i in walk(rig)}
    for item in list(walk(rig)):
        props = item.find("Properties")
        dangling = False
        for p in props if props is not None else []:
            if p.tag == "Ref" and p.text and p.text != "null" and p.text not in present:
                p.text = "null"
                dangling = dangling or p.get("name") in ("Part0", "Part1", "Part0Internal", "Part1Internal")
        if item.get("class") in JOINTS and dangling and item in parent_of:
            remove(parent_of, item)
    parent_of = {c: p for p in walk(rig) for c in p.findall("Item")}

    # Containers with no parts left, and the default "roblox" torso logo.
    changed = True
    while changed:
        changed = False
        for item in list(walk(rig)):
            if item is rig or item not in parent_of:
                continue
            empty_box = item.get("class") in ("Model", "Folder", "Accessory", "Hat", "Accoutrement") and not any(
                i.get("class") in PARTS for i in walk(item)
            )
            if empty_box or (item.get("class") == "Decal" and name(item) == "roblox"):
                remove(parent_of, item)
                changed = True
                break

    hrp = next((k for k in rig.findall("Item") if name(k) == "HumanoidRootPart"), None)
    pp = prop(rig, "PrimaryPart")
    if pp is not None and hrp is not None:
        pp.text = hrp.get("referent")
    set_name(rig, key)
    after = sum(1 for i in walk(rig) if i.get("class") in PARTS)
    return before, after


def main():
    rbxm = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "anime1.rbxm")
    tree = ET.parse(to_xml(rbxm))
    source = tree.getroot()
    top = source.find("Item")
    with open(os.path.join(ROOT, "tools", "pack", "roster.json")) as f:
        roster = json.load(f)

    # Find each roster fighter by series + pack name (first occurrence, as inspect_pack does).
    wanted = {(f["series"], f["source"]): f for f in roster}
    found = {}
    for series in top.findall("Item"):
        label = name(series).replace(" Pack", "")
        for item in walk(series):
            if is_rig(item):
                k = (label, name(item).strip())
                if k in wanted and k not in found:
                    found[k] = item

    folder = ET.Element("Item", {"class": "Folder", "referent": "FIGHTERS"})
    props = ET.SubElement(folder, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = "Fighters"
    report, keys = [], set()
    in_roster = {f["key"] for f in roster}
    custom_keys = {
        f[:-5] for f in os.listdir(os.path.join(ROOT, "tools", "pack", "custom")) if f.endswith(".rbxm") and f[:-5] in in_roster
    }
    for k, fighter in sorted(wanted.items(), key=lambda kv: kv[1]["key"]):
        key = fighter["key"]
        assert key not in keys, f"duplicate key {key}"
        keys.add(key)
        if key in custom_keys:
            continue  # hand-made: added below
        rig = copy.deepcopy(found[k])
        before, after = strip(rig, key)
        folder.append(rig)
        report.append((key, before, after))

    # Fighters made by hand replace the pack's: tools/pack/custom/<Key>.rbxm (one rigged Model), stripped the same
    # way. Referents get a prefix so they can't collide with the pack's.
    custom_shared = []
    custom_dir = os.path.join(ROOT, "tools", "pack", "custom")
    for fname in sorted(os.listdir(custom_dir)) if os.path.isdir(custom_dir) else []:
        if not fname.endswith(".rbxm") or fname[:-5] not in custom_keys:
            continue
        key = fname[:-5]
        csrc = ET.parse(to_xml(os.path.join(custom_dir, fname))).getroot()
        rig = csrc.find("Item")
        ref_prefix = "C_" + key + "_"
        for item in rig.iter("Item"):
            item.set("referent", ref_prefix + item.get("referent"))
        for ref in rig.iter("Ref"):
            if ref.text and ref.text != "null":
                ref.text = ref_prefix + ref.text
        adopt_orphans(rig, {c: p for p in walk(rig) for c in p.findall("Item")})
        report.append((key, *strip(rig, key)))
        for old_rig in folder.findall("Item"):
            if name(old_rig) == key:
                folder.remove(old_rig)
        folder.append(rig)
        shared_in = csrc.find("SharedStrings")
        if shared_in is not None:
            custom_shared.extend(shared_in)
        print("custom fighter:", key)

    # Keep only the shared mesh/physics data the fighters still reference.
    used = {e.text for e in folder.iter("SharedString") if e.text}
    shared = source.find("SharedStrings")
    out_root = ET.Element("roblox", {"version": "4"})
    out_root.append(folder)
    if shared is not None or custom_shared:
        kept = ET.SubElement(out_root, "SharedStrings")
        seen = set()
        for s in list(shared if shared is not None else []) + custom_shared:
            if s.get("md5") in used and s.get("md5") not in seen:
                seen.add(s.get("md5"))
                kept.append(s)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = tempfile.mkdtemp()
    xml_path = os.path.join(tmp, "Fighters.rbxmx")
    ET.ElementTree(out_root).write(xml_path, encoding="utf-8", xml_declaration=False)
    project = os.path.join(tmp, "fighters.project.json")
    with open(project, "w") as f:
        json.dump({"name": "Fighters", "tree": {"$path": xml_path}}, f)
    subprocess.run([ROJO, "build", project, "-o", OUT], check=True, capture_output=True)

    missing = [f["key"] for kk, f in wanted.items() if kk not in found and f["key"] not in custom_keys]
    total_before = sum(r[1] for r in report)
    total_after = sum(r[2] for r in report)
    heavy = sorted(report, key=lambda r: -r[2])[:6]
    print(f"{len(report)} fighters -> {os.path.relpath(OUT, ROOT)} ({os.path.getsize(OUT) / 1e6:.1f} MB)")
    print("morph pieces re-attached:", dict(MORPH_STATS))
    print(f"parts {total_before} -> {total_after}; heaviest: " + ", ".join(f"{k} {a}" for k, b, a in heavy))
    if missing:
        print("MISSING:", missing)


if __name__ == "__main__":
    main()
