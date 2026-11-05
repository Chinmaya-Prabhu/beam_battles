"""Brings the passes and developer products ALREADY on Roblox in line with src/shared/Products.lua (names,
descriptions, and optionally prices), and takes the products named in RETIRE off sale. Uses Open Cloud.

Setup, in your own terminal (the key never goes in a file):

    export ROBLOX_API_KEY=...        # Open Cloud key with Game Passes (read, write) and Developer Products
                                     # (read, write) for this experience
    export ROBLOX_UNIVERSE=<id>      # the experience's universe id

    python3 tools/ids/sync.py                # dry run: shows every change it would make
    python3 tools/ids/sync.py --go           # applies names and descriptions, takes RETIRE items off sale
    python3 tools/ids/sync.py --go --prices  # also pushes the prices in Products.lua UP to Roblox (overwrites the Dashboard!)
    python3 tools/ids/sync.py --pull-prices  # dry run: the Dashboard's prices that differ from Products.lua
    python3 tools/ids/sync.py --pull-prices --go   # writes the Dashboard's prices INTO Products.lua (Roblox untouched)

(Run it with `python3 tools/ids/sync.py`: the file is not executable on its own.)

Roblox has no delete for these: "archive" is isForSale = false, which is also what the Dashboard's archive does
for a product nobody can buy any more. Safe to run again: it only touches what differs.
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import create  # noqa: E402  (the same http helpers and Products.lua reader)

RETIRE = ["Restock Now"]  # Dashboard names of products to take off sale


def main():
    key, universe = os.environ.get("ROBLOX_API_KEY"), os.environ.get("ROBLOX_UNIVERSE")
    go, prices, pull = "--go" in sys.argv, "--prices" in sys.argv, "--pull-prices" in sys.argv
    if not key or not universe or not universe.isdigit():
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_UNIVERSE (digits only) first; see the top of this file.")
    api = create.API
    passes_url = f"{api}/game-passes/v1/universes/{universe}/game-passes"
    products_url = f"{api}/developer-products/v2/universes/{universe}/developer-products"
    on_pass = {p["gamePassId"]: p for p in create.list_all(passes_url + "/creator", key, "gamePasses")}
    on_product = {p["productId"]: p for p in create.list_all(products_url + "/creator", key, "developerProducts")}

    changes = 0
    if pull:
        # The other direction: Roblox's prices become Products.lua's (so the game's own numbers match the Dashboard).
        text = open(create.PRODUCTS_LUA).read()
        for item in create.read_products():
            have = (on_pass if item["kind"] == "pass" else on_product).get(item["id"])
            if not have:
                continue
            live = have.get("price")
            if live is None:
                live = (have.get("priceInformation") or {}).get("defaultPriceInRobux")
            if not isinstance(live, int) or live == item["price"]:
                continue
            changes += 1
            print(f'pull    {item["kind"]:7} {item["key"]:16} Products.lua {item["price"]} -> {live} (the Dashboard)')
            text = re.sub(
                r'(key = "' + item["key"] + r'",\s*id = ' + str(item["id"]) + r',\s*price = )\d+', r"\g<1>" + str(live), text, count=1
            )
        if go:
            open(create.PRODUCTS_LUA, "w").write(text)
        print("done" if go else f"dry run: {changes} price(s) would change in Products.lua; add --go to write them")
        return
    for item in create.read_products():
        if not item["id"]:
            continue
        have = (on_pass if item["kind"] == "pass" else on_product).get(item["id"])
        if not have:
            print(f'missing {item["kind"]:7} {item["key"]}: id {item["id"]} is not on this experience')
            continue
        fields = {}
        if have.get("name") != item["name"]:
            fields["name"] = item["name"]
        if (have.get("description") or "") != item["desc"]:
            fields["description"] = item["desc"]
        if prices and have.get("price") not in (None, item["price"]) and have.get("priceInformation", {}).get("defaultPriceInRobux", item["price"]) != item["price"]:
            fields["price"] = item["price"]
        if not fields:
            continue
        changes += 1
        print(f'update  {item["kind"]:7} {item["key"]:16}', {k: (have.get(k), v) for k, v in fields.items()})
        if go:
            url = f"{passes_url}/{item['id']}" if item["kind"] == "pass" else f"{products_url}/{item['id']}"
            body, ctype = create.multipart(fields, {})
            status, data = create.call("PATCH", url, key, body, ctype)
            if status not in (200, 204):  # (204 = updated, nothing to return)
                sys.exit(f"  failed ({status}): {data}")
            time.sleep(0.5)

    for p in on_product.values():
        if p.get("name") in RETIRE and p.get("isForSale", True):
            changes += 1
            print(f'retire  product {p["name"]!r} ({p["productId"]}): take off sale')
            if go:
                body, ctype = create.multipart({"isForSale": "false"}, {})
                status, data = create.call("PATCH", f"{products_url}/{p['productId']}", key, body, ctype)
                if status not in (200, 204):  # (204 = updated, nothing to return)
                    sys.exit(f"  failed ({status}): {data}")

    print("done" if go else f"dry run: {changes} change(s); run with --go to apply")


if __name__ == "__main__":
    main()
