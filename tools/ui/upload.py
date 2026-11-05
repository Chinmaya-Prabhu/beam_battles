"""Uploads Anime Clash's UI atlases (art/atlas/*.png, made by tools/ui/atlas.py) to Roblox through Open Cloud
and writes their asset ids to src/shared/UIAtlasIds.lua, which shared/UIAtlas.lua reads.

Same setup and Open Cloud calls as the grow-engine and animal-forest uploaders: an API key with the Assets API
(read + write), kept in the terminal's environment (never in a file), and who owns the uploads:

    export ROBLOX_API_KEY=...                  # never commit this
    export ROBLOX_CREATOR=user:<your user id>  # or group:<id>

Then, any time the art changes:

    python3 tools/ui/upload.py            # uploads new or changed atlases only
    python3 tools/ui/upload.py --dry-run  # shows what would upload

Ids are kept in art/atlas/ids.json with a hash of each file, so an unchanged file is never uploaded twice.
"""
import hashlib
import json
import os
import re
import struct
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ATLAS = os.path.join(ROOT, "art", "atlas")
IDS = os.path.join(ATLAS, "ids.json")
LUA = os.path.join(ROOT, "src", "shared", "UIAtlasIds.lua")
API = "https://apis.roblox.com"
# File -> the name shared/UIAtlas.lua knows it by.
FILES = {"anime_clash_icons.png": "icons", "anime_clash_more.png": "more", "anime_clash_frames.png": "frames", "anime_clash_beam.png": "beam", "anime_clash_extra.png": "extra"}


def request(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def multipart(fields, file_name, file_bytes):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{file_name}"\r\nContent-Type: image/png\r\n\r\n'.encode())
    parts.append(file_bytes + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def wait_for(op_path, key):
    for _ in range(60):
        status, body = request("GET", f"{API}/assets/v1/{op_path}", key)
        data = json.loads(body or b"{}")
        if status == 200 and data.get("done"):
            return data.get("response", {}).get("assetId")
        time.sleep(1.5)
    raise RuntimeError(f"upload operation {op_path} never finished")


def create(path, key, creator, asset_type):
    kind, cid = creator.split(":")
    meta = {
        "assetType": asset_type,
        "displayName": os.path.basename(path)[:-4][:50],
        "description": "Anime Clash UI art",
        "creationContext": {"creator": {("userId" if kind == "user" else "groupId"): cid}},
    }
    body, ctype = multipart({"request": json.dumps(meta)}, os.path.basename(path), open(path, "rb").read())
    status, resp = request("POST", f"{API}/assets/v1/assets", key, body, {"Content-Type": ctype})
    if status != 200:
        return None, f"{status} {resp[:300]!r}"
    op = json.loads(resp)
    return wait_for(op["path"], key), None


# ---- Decal -> image id: download the decal and read the image id out of its Texture property.
def lz4_block(src, size):
    out = bytearray()
    i = 0
    while i < len(src):
        token = src[i]
        i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]
                i += 1
                lit += b
                if b != 255:
                    break
        out += src[i : i + lit]
        i += lit
        if i >= len(src):
            break
        off = src[i] | (src[i + 1] << 8)
        i += 2
        ml = token & 15
        if ml == 15:
            while True:
                b = src[i]
                i += 1
                ml += b
                if b != 255:
                    break
        ml += 4
        start = len(out) - off
        for k in range(ml):
            out.append(out[start + k])
    return bytes(out[:size])


def decal_to_image(decal_id, key):
    status, body = request("GET", f"{API}/asset-delivery-api/v1/assetId/{decal_id}", key)
    if status != 200:
        return None
    location = json.loads(body).get("location")
    if not location:
        return None
    with urllib.request.urlopen(location, timeout=60) as r:
        blob = r.read()
    text = blob
    if blob.startswith(b"<roblox!"):  # binary place/model format: chunks may be LZ4-compressed
        chunks, i = [], 32
        while i + 16 <= len(blob):
            name = blob[i : i + 4]
            clen, ulen = struct.unpack("<II", blob[i + 4 : i + 12])
            data = blob[i + 16 : i + 16 + (clen or ulen)]
            chunks.append(lz4_block(data, ulen) if clen else data)
            i += 16 + (clen or ulen)
            if name == b"END\x00":
                break
        text = b"".join(chunks)
    m = re.search(rb"(?:rbxassetid://|asset/\?id=)(\d+)", text)
    return int(m.group(1)) if m else None


def write_lua(ids):
    lines = [
        "-- GENERATED by tools/ui/upload.py: do not edit by hand. Re-run it after the atlases change.",
        "-- Asset ids of the UI atlases (0 = not uploaded yet; the UI keeps its plain look for those).",
        "return {",
    ]
    for f, name in sorted(FILES.items(), key=lambda kv: kv[1]):
        e = ids.get(f)
        lines.append("\t%s = %d," % (name, e["id"] if e else 0))
    lines.append("}")
    open(LUA, "w").write("\n".join(lines) + "\n")
    print("wrote", os.path.relpath(LUA, ROOT))


def main():
    dry = "--dry-run" in sys.argv
    key = os.environ.get("ROBLOX_API_KEY")
    creator = os.environ.get("ROBLOX_CREATOR", "")
    ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    if not dry and (not key or not re.fullmatch(r"(user|group):\d+", creator)):
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_CREATOR (user:<id> or group:<id>) first. See the top of this file.")
    todo = []
    for f in FILES:
        h = hashlib.sha1(open(os.path.join(ATLAS, f), "rb").read()).hexdigest()
        e = ids.get(f)
        if not (isinstance(e, dict) and e.get("hash") == h and e.get("id")):
            todo.append((f, h))
    print(f"{len(FILES)} atlases · {len(FILES) - len(todo)} already uploaded · {len(todo)} to upload")
    if dry:
        for f, _ in todo:
            print("  would upload", f)
        return
    asset_type = "Image"
    for n, (f, h) in enumerate(todo, 1):
        path = os.path.join(ATLAS, f)
        asset_id, err = create(path, key, creator, asset_type)
        if err and asset_type == "Image":
            print("  'Image' uploads not accepted for this key, falling back to Decal:", err)
            asset_type = "Decal"
            asset_id, err = create(path, key, creator, asset_type)
        if err and ("401" in err[:4] or "403" in err[:4]):
            sys.exit(f"Roblox refused the API key ({err[:3]}): stopped. Check the key's IP list, Assets permission and owner, then re-run.")
        if err or not asset_id:
            print(f"  [{n}/{len(todo)}] FAILED {f}: {err}")
            continue
        image_id = int(asset_id)
        if asset_type == "Decal":
            image_id = decal_to_image(asset_id, key)
            if not image_id:
                print(f"  [{n}/{len(todo)}] uploaded {f} as decal {asset_id} but couldn't read its image id (needs Assets read permission)")
                continue
        ids[f] = {"id": image_id, "hash": h}
        json.dump(ids, open(IDS, "w"), indent=1, sort_keys=True)  # save as we go so a crash loses nothing
        print(f"  [{n}/{len(todo)}] {f} -> {image_id}")
    write_lua(ids)


if __name__ == "__main__":
    main()
