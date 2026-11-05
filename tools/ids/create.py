"""Creates Anime Beam Battle's game passes, developer products and badges on Roblox through Open Cloud, with their
icons, and writes each new id into the game (src/shared/Products.lua, Config.Badges in src/shared/Config.lua).

Setup, in your own terminal (the key never goes in a file):

    export ROBLOX_API_KEY=...        # Open Cloud key (Creator Dashboard -> Open Cloud -> API Keys), with, for
                                     # this experience: Game Passes (read, write), Developer Products (read,
                                     # write), and Badges / legacy-universe.badge (manage and spend Robux)
    export ROBLOX_UNIVERSE=<id>      # the experience's universe id

    python3 tools/ids/create.py                 # dry run: shows what it would create, changes nothing
    python3 tools/ids/create.py --go            # creates the passes and products (free)
    python3 tools/ids/create.py --go --badges   # also the badges, ONLY if Roblox makes them free: a badge that costs Robux
                                                # is skipped. Add --pay-badges to be asked before paying.

Safe to run again: anything that already has an id in the code is skipped, and an item that already exists on
Roblox under the same name is adopted (its id written in) rather than made twice. Icons come from
art/products/<Key>.png and art/badges/<Key>.png (tools/ids/icons.py makes the missing ones).
Every id it writes is also logged to tools/ids/ids.json.
"""
import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PRODUCTS_LUA = os.path.join(ROOT, "src", "shared", "Products.lua")
CONFIG_LUA = os.path.join(ROOT, "src", "shared", "Config.lua")
LOG = os.path.join(HERE, "ids.json")
API = "https://apis.roblox.com"

# Names on Roblox must be unique per experience; the five Market tiers share one in-game name.
STORE_NAMES = {
    "MarketT1": "Market Fighter: Epic",
    "MarketT2": "Market Fighter: Legendary",
    "MarketT3": "Market Fighter: Rare Pick",
    "MarketT4": "Market Fighter: Mythic",
    "MarketT5": "Market Fighter: Best Pick",
}

BADGES = {
    "Welcome": ("Welcome to Anime Beam Battle", "Joined Anime Beam Battle for the first time."),
    "FirstWin": ("First Victory", "Won your first clash."),
    "Blossom": ("Symbol of Peace Defeated", "Beat the boss of Blossom Academy."),
    "Ninja": ("The Shadow Defeated", "Beat the boss of Ninja Village."),
    "Pirate": ("Pirate Bay Conquered", "Beat the boss of Pirate Bay."),
    "Walled": ("Walled City Conquered", "Beat the boss of the Walled City."),
    "FirstSecret": ("Secret Found", "Got your first Secret fighter."),
    "FirstSteal": ("Master Thief", "Stole a fighter from another player's base."),
    "Rebirth": ("Reborn", "Rebirthed for the first time."),
    "FullBase": ("Full House", "Unlocked all 8 stands at your base."),
}


# ------------------------------------------------------------------ http

def multipart(fields, files):
    boundary = uuid.uuid4().hex
    out = b""
    for k, v in fields.items():
        out += f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    for k, path in files.items():
        mime = mimetypes.guess_type(path)[0] or "application/octet-stream"
        out += (
            f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"; filename="{os.path.basename(path)}"\r\n'
            f"Content-Type: {mime}\r\n\r\n"
        ).encode()
        out += open(path, "rb").read() + b"\r\n"
    out += f"--{boundary}--\r\n".encode()
    return out, f"multipart/form-data; boundary={boundary}"


def call(method, url, key=None, body=None, ctype=None):
    headers = {}
    if key:
        headers["x-api-key"] = key
    if ctype:
        headers["Content-Type"] = ctype
    for attempt in range(5):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                return r.status, json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            raw = e.read()
            if e.code == 429 and attempt < 4:  # rate limited: back off and retry
                time.sleep(2 + attempt * 2)
                continue
            try:
                return e.code, json.loads(raw)
            except ValueError:
                return e.code, {"raw": raw[:300].decode(errors="replace")}
    return 0, {}


def list_all(url, key, field):
    items, token = [], None
    while True:
        status, data = call("GET", url + "?pageSize=50" + (f"&pageToken={token}" if token else ""), key)
        if status != 200:
            hint = "Does the API key have read access for this?" if status in (401, 403) else ""
            sys.exit(f"Couldn't list {field} ({status}): {data}\n{hint}")
        items += data.get(field) or []
        token = data.get("nextPageToken")
        if not token:
            return items


# ------------------------------------------------------------------ the game's lists

def read_products():
    s = open(PRODUCTS_LUA).read()
    items_at = s.index("Products.Items")
    out = []
    pattern = r'key = "(\w+)",\s*id = (\d+),\s*price = (\d+),\s*name = "([^"]*)",\s*desc = "([^"]*)"'
    for m in re.finditer(pattern, s):
        out.append({
            "kind": "pass" if m.start() < items_at else "product",
            "key": m.group(1),
            "id": int(m.group(2)),
            "price": int(m.group(3)),
            "name": STORE_NAMES.get(m.group(1), m.group(4)),
            "desc": m.group(5),
        })
    return out


def read_badges():
    s = open(CONFIG_LUA).read()
    block = s[s.index("Config.Badges = {"):]
    block = block[: block.index("}")]
    return {m.group(1): int(m.group(2)) for m in re.finditer(r"(\w+) = (\d+),", block)}


def write_product_id(key, new_id):
    s = open(PRODUCTS_LUA).read()
    s2, n = re.subn(r'(key = "' + key + r'",\s*id = )0\b', r"\g<1>" + str(new_id), s, count=1)
    if n != 1:
        sys.exit(f"Couldn't write the id for {key} into Products.lua")
    open(PRODUCTS_LUA, "w").write(s2)


def write_badge_id(key, new_id):
    s = open(CONFIG_LUA).read()
    start = s.index("Config.Badges = {")
    end = s.index("}", start)
    block, n = re.subn(r"(\b" + key + r" = )0,", r"\g<1>" + str(new_id) + ",", s[start:end], count=1)
    if n != 1:
        sys.exit(f"Couldn't write the badge id for {key} into Config.lua")
    open(CONFIG_LUA, "w").write(s[:start] + block + s[end:])


def log(kind, key, new_id):
    data = json.load(open(LOG)) if os.path.exists(LOG) else {}
    data.setdefault(kind, {})[key] = new_id
    json.dump(data, open(LOG, "w"), indent=2, sort_keys=True)


# ------------------------------------------------------------------ main

def main():
    key, universe = os.environ.get("ROBLOX_API_KEY"), os.environ.get("ROBLOX_UNIVERSE")
    go, do_badges = "--go" in sys.argv, "--badges" in sys.argv
    if not key or not universe:
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_UNIVERSE first (see the top of this file).")
    if not universe.isdigit() or len(universe) > 16:
        sys.exit(f"ROBLOX_UNIVERSE should be the experience's universe id (digits only), not {universe!r}.")

    passes_url = f"{API}/game-passes/v1/universes/{universe}/game-passes"
    products_url = f"{API}/developer-products/v2/universes/{universe}/developer-products"
    existing = {
        "pass": {p["name"]: p["gamePassId"] for p in list_all(passes_url + "/creator", key, "gamePasses")},
        "product": {
            p["name"]: p["productId"] for p in list_all(products_url + "/creator", key, "developerProducts")
        },
    }

    made = adopted = 0
    for item in read_products():
        if item["id"] != 0:
            continue
        label = f'{item["kind"]:7} {item["key"]:16} {item["price"]:>5} R$  "{item["name"]}"'
        have = existing[item["kind"]].get(item["name"])
        if have:
            print(f"adopt   {label} -> {have} (already on Roblox)")
            if go:
                write_product_id(item["key"], have)
                log(item["kind"], item["key"], have)
            adopted += 1
            continue
        icon = os.path.join(ROOT, "art", "products", item["key"] + ".png")
        print(f"create  {label}" + ("" if os.path.exists(icon) else "  (NO ICON)"))
        if not go:
            continue
        fields = {"name": item["name"], "description": item["desc"], "price": item["price"], "isForSale": "true"}
        body, ctype = multipart(fields, {"imageFile": icon} if os.path.exists(icon) else {})
        status, data = call("POST", passes_url if item["kind"] == "pass" else products_url, key, body, ctype)
        new_id = data.get("gamePassId") or data.get("productId")
        if status != 200 or not new_id:
            sys.exit(f"  failed ({status}): {data}\nNothing after this was created; fix it and run again.")
        write_product_id(item["key"], new_id)
        log(item["kind"], item["key"], new_id)
        print(f"        -> {new_id}")
        made += 1
        time.sleep(0.5)

    if do_badges:
        status, meta = call("GET", "https://badges.roblox.com/v1/badges/metadata")
        price = meta.get("badgeCreationPrice", 0) if status == 200 else None
        status, data = call("GET", f"https://badges.roblox.com/v1/universes/{universe}/badges?limit=100")
        on_roblox = {b["name"]: b["id"] for b in (data.get("data") or [])} if status == 200 else {}
        todo = [k for k, v in read_badges().items() if v == 0 and k in BADGES]
        new = [k for k in todo if BADGES[k][0] not in on_roblox]
        confirmed = False
        cost = "unknown" if price is None else f"{price} R$ each, {price * len(new)} R$ in all"
        print(f"\nbadges: {len(todo)} without an id, {len(new)} to create ({cost})")
        for k in todo:
            name, desc = BADGES[k]
            if name in on_roblox:
                print(f"adopt   badge   {k:16} -> {on_roblox[name]}")
                if go:
                    write_badge_id(k, on_roblox[name])
                    log("badge", k, on_roblox[name])
                continue
            print(f'create  badge   {k:16} "{name}"')
            if not go:
                continue
            if price is None:
                sys.exit("Couldn't read the badge price from Roblox, so no badge was made (nothing was spent).")
            if price > 0 and "--pay-badges" not in sys.argv:
                # Free badges only, unless --pay-badges is given: never spend Robux by accident.
                print(f"        skipped: badges cost {price} R$ each (add --pay-badges to pay for them)")
                continue
            if price > 0 and not confirmed:
                answer = input(f"Badges cost {price} R$ each ({price * len(new)} R$ for {len(new)}). Type yes to pay: ")
                if answer.strip().lower() != "yes":
                    sys.exit("No badges made; nothing was spent.")
                confirmed = True
            fields = {
                "name": name,
                "description": desc,
                "paymentSourceType": 2 if os.environ.get("ROBLOX_PAY") == "group" else 1,
                "expectedCost": price,
                "isActive": "true",
            }
            body, ctype = multipart(fields, {"files": os.path.join(ROOT, "art", "badges", k + ".png")})
            status, data = call("POST", f"{API}/legacy-badges/v1/universes/{universe}/badges", key, body, ctype)
            if status != 200 or not data.get("id"):
                sys.exit(f"  failed ({status}): {data}\nNothing after this was created; fix it and run again.")
            write_badge_id(k, data["id"])
            log("badge", k, data["id"])
            print(f"        -> {data['id']}")
            time.sleep(0.7)

    if go:
        print(f"\ndone: {made} created, {adopted} adopted. Ids are in Products.lua / Config.lua and tools/ids/ids.json.")
    else:
        print("\ndry run: nothing was created. Add --go to do it.")


if __name__ == "__main__":
    main()
