"""Uploads art/voxel_pilot/VoxelKit.glb to Roblox through Open Cloud and writes its asset id into
src/shared/Config.lua (Config.VoxelKitId).

Setup, in your own terminal (the key never goes in a file):

    export ROBLOX_API_KEY=...        # Open Cloud key with the Assets API: asset:read and asset:write

    python3 tools/ids/upload_kit.py          # dry run: shows what it would upload
    python3 tools/ids/upload_kit.py --go     # uploads it (free) and writes the id into the game

The model is owned by your account (USER_ID): it has to match the game's owner or the game can't load it.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
KIT = os.path.join(ROOT, "art", "voxel_pilot", "VoxelKit.glb")
CONFIG_LUA = os.path.join(ROOT, "src", "shared", "Config.lua")
LOG = os.path.join(HERE, "ids.json")
API = "https://apis.roblox.com/assets/v1"
USER_ID = "10576492953"


def call(req):
    try:
        with urllib.request.urlopen(req, timeout=180) as res:
            return json.load(res)
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", "replace")[:400]
        hint = " (the key needs the Assets API: asset:read and asset:write)" if e.code in (401, 403) else ""
        sys.exit(f"Roblox said {e.code}{hint}: {text}")


def main():
    size = os.path.getsize(KIT) / 1e6
    print(f"VoxelKit.glb, {size:.1f} MB, owner user {USER_ID}")
    if "--go" not in sys.argv:
        print("Dry run: nothing uploaded. Add --go to upload.")
        return
    key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not key:
        sys.exit("Set ROBLOX_API_KEY first; see the top of this file.")
    meta = {
        "assetType": "Model",
        "displayName": "Anime Beam Battle Voxel Kit",
        "description": "Voxel altar, clash pad and summit.",
        "creationContext": {"creator": {"userId": USER_ID}},
    }
    boundary = uuid.uuid4().hex
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n{json.dumps(meta)}\r\n'
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="VoxelKit.glb"\r\n'
        "Content-Type: model/gltf-binary\r\n\r\n"
    ).encode() + open(KIT, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(f"{API}/assets", data=body, method="POST")
    req.add_header("x-api-key", key)
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    op = call(req)
    path = op.get("path") or f"operations/{op.get('operationId')}"
    print("Uploading, waiting for Roblox...")
    asset = None
    for _ in range(60):
        time.sleep(5)
        poll = urllib.request.Request(f"{API}/{path}")
        poll.add_header("x-api-key", key)
        state = call(poll)
        if state.get("done"):
            if "error" in state:
                sys.exit(f"Roblox refused it: {json.dumps(state['error'])[:400]}")
            asset = state.get("response", {}).get("assetId")
            break
    if not asset:
        sys.exit("Still processing after 5 minutes. Run it again later, or check Creator Dashboard > Development Items.")
    src = open(CONFIG_LUA, encoding="utf-8").read()
    src, n = re.subn(r"Config\.VoxelKitId = \d+", f"Config.VoxelKitId = {asset}", src)
    if n != 1:
        sys.exit(f"Uploaded as {asset}, but couldn't write it into Config.lua: set Config.VoxelKitId by hand.")
    open(CONFIG_LUA, "w", encoding="utf-8").write(src)
    ids = json.load(open(LOG)) if os.path.exists(LOG) else {}
    ids["voxelKit"] = int(asset)
    json.dump(ids, open(LOG, "w"), indent=2)
    print(f"Done: asset {asset}, written to Config.VoxelKitId.")


main()
