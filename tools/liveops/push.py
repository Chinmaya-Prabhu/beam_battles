"""Changes Anime Clash's live events and deals without republishing (server/Services/LiveOpsService.lua).

Writes the LiveOps config to the "LiveOps" DataStore (key "config") through Open Cloud, then pings every
running server over MessagingService (topic "LiveOps") so they reload at once (otherwise within a minute).

    export ROBLOX_API_KEY=...          # Open Cloud key with DataStore (read+write) and Messaging (publish)
    export ROBLOX_UNIVERSE=<id>        # the experience's universe id (Creator Dashboard)

    python3 tools/liveops/push.py show
    python3 tools/liveops/push.py event SoulSociety 2026-11-07T18:00 2026-11-10T00:00   # UTC times
    python3 tools/liveops/push.py clear-events
    python3 tools/liveops/push.py announce "Bleach invasion this weekend!"
    python3 tools/liveops/push.py feature SummonMythic ProBundle
    python3 tools/liveops/push.py code SPIRIT boost cash --expires 2026-11-14T17:00   # rewards: cash ki boost
                                                                                     # epic legendary mythic
    python3 tools/liveops/push.py uncode SPIRIT
    python3 tools/liveops/push.py update 2026-11-07T17:00 "SPIRIT TEMPLE" "Final Aizen awaits"
    python3 tools/liveops/push.py clear-update
Event keys: DoubleDrops, MutationWeek, GoldenRush, TrainingFrenzy, SoulSociety, Bizarre (shared/LiveOps.lua).
"""
import datetime
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://apis.roblox.com"


def call(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def entry_url(universe):
    q = urllib.parse.urlencode({"datastoreName": "LiveOps", "entryKey": "config"})
    return f"{API}/datastores/v1/universes/{universe}/standard-datastores/datastore/entries/entry?{q}"


def load(universe, key):
    status, body = call("GET", entry_url(universe), key)
    if status == 200:
        try:
            return json.loads(json.loads(body))  # stored as a JSON string
        except (ValueError, TypeError):
            pass
    return {"schedule": [], "featured": []}


def save(universe, key, config):
    body = json.dumps(json.dumps(config)).encode()
    status, resp = call("POST", entry_url(universe), key, body, {"Content-Type": "application/json"})
    if status != 200:
        sys.exit(f"DataStore write failed: {status} {resp[:200]!r}")
    ping = json.dumps({"message": "reload"}).encode()
    status, resp = call(
        "POST", f"{API}/messaging-service/v1/universes/{universe}/topics/LiveOps", key, ping,
        {"Content-Type": "application/json"},
    )
    print("saved;", "servers pinged" if status == 200 else f"ping failed ({status}), servers reload within a minute")


def utc(text):
    return int(datetime.datetime.fromisoformat(text).replace(tzinfo=datetime.timezone.utc).timestamp())


def main():
    key, universe = os.environ.get("ROBLOX_API_KEY"), os.environ.get("ROBLOX_UNIVERSE")
    if not key or not universe:
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_UNIVERSE first (see the top of this file).")
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd, args = sys.argv[1], sys.argv[2:]
    config = load(universe, key)
    if cmd == "show":
        print(json.dumps(config, indent=2))
        return
    if cmd == "event" and len(args) == 3:
        config.setdefault("schedule", []).append({"key": args[0], "start": utc(args[1]), "finish": utc(args[2])})
    elif cmd == "clear-events":
        config["schedule"] = []
    elif cmd == "announce":
        config["announcement"] = " ".join(args) or None
    elif cmd == "feature":
        config["featured"] = args
    elif cmd == "code" and len(args) >= 2:
        # Reward presets (shared/Codes.lua, shared/Rewards.lua kinds): Power and Cash scale with the player.
        presets = {
            "cash": {"kind": "cash", "seconds": 600, "floor": 10000},
            "power": {"kind": "power", "reps": 600, "floor": 3000},
            "boost": {"kind": "boost", "minutes": 15},
            "epic": {"kind": "fighter", "rarity": "Epic"},
            "legendary": {"kind": "fighter", "rarity": "Legendary"},
            "mythic": {"kind": "fighter", "rarity": "Mythic"},
        }
        name, rest, expires = args[0].upper(), args[1:], None
        if "--expires" in rest:
            i = rest.index("--expires")
            expires = utc(rest[i + 1])
            rest = rest[:i] + rest[i + 2:]
        unknown = [r for r in rest if r not in presets]
        if unknown or not rest:
            sys.exit("Rewards must be some of: " + " ".join(presets))
        entry = {"rewards": [presets[r] for r in rest]}
        if expires:
            entry["expires"] = expires
        config.setdefault("codes", {})["".join(c for c in name if c.isalnum())] = entry
    elif cmd == "uncode" and len(args) == 1:
        config.setdefault("codes", {}).pop(args[0].upper(), None)
    elif cmd == "update" and len(args) >= 2:
        config["update"] = {"at": utc(args[0]), "title": args[1], "teaser": " ".join(args[2:]) or None}
    elif cmd == "clear-update":
        config.pop("update", None)
    else:
        sys.exit(__doc__)
    save(universe, key, config)


if __name__ == "__main__":
    main()
