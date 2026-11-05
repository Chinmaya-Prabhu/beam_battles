"""Pacing sim: a realistic kid over several days of play, on the game's numbers plus a candidate balance.

A day is one session (minutes per day below); between sessions the base earns offline (50%, up to 8 h).
In a session the kid clicks ~2 reps/s while training, wins a drop every ~2.5 min at the best altar open to
them, beats each guardian once strong enough (+1 min for the fight, and takes its prize fighter), buys
gear/stations/stands when they can and rolls with spare cash. Prints when the big moments land.

    python3 tools/sim/pacing.py
"""
import random
import roll_economy as E

SESSIONS = [60, 45, 45, 40, 40, 35, 35, 35, 30, 30]  # minutes played on days 1..10
REPS = 2.0
DROP_EVERY = 150


def play(bal, seed, payer=False, rolls=True, tickets=None):
    rng = random.Random(seed)
    s = dict(power=0.0, ki=0.0, cash=0.0, gear=0, stations=1, stands=4, zone=0, rung=0, rolls=0)
    fighters, first, pity = [], {}, {n: 0 for n, _ in bal["pity"]}
    tk = dict(have=(tickets or {}).get("start", 0), reps=0.0, used=0)
    clock = 0  # minutes of play so far

    def add(r, src):
        fighters.append((E.INCOME[r] * E.mutation(rng), r, src))
        first.setdefault(r, clock_now[0])

    clock_now = [0.0]
    for day, minutes in enumerate(SESSIONS, 1):
        if day > 1:  # offline earnings
            best = sorted(fighters, key=lambda f: -f[0])[: s["stands"]]
            s["cash"] += sum(f[0] for f in best) * 0.5 * 8 * 3600
        next_drop = DROP_EVERY
        for t in range(minutes * 60):
            clock_now[0] = (clock * 60 + t) / 60
            best = sorted(fighters, key=lambda f: -f[0])[: s["stands"]]
            s["cash"] += sum(f[0] for f in best) * (2 if payer else 1)
            champ = E.CHAMP[best[0][1]] if best else 1
            per = E.GEAR[s["gear"]][0] * E.STATIONS[s["stations"] - 1][2] * champ * (2 if payer else 1)
            s["power"] += REPS * per
            if tickets:
                tk["reps"] += REPS
                while tk["reps"] >= tickets["reps"]:
                    tk["reps"] -= tickets["reps"]
                    tk["have"] += 1
            s["ki"] += REPS * per
            while s["gear"] + 1 < len(E.GEAR) and s["ki"] >= E.GEAR[s["gear"] + 1][1]:
                s["gear"] += 1
                s["ki"] -= E.GEAR[s["gear"]][1]
            st = s["stations"]
            if st < len(E.STATIONS) and s["power"] >= E.STATIONS[st][0] and s["cash"] >= E.STATIONS[st][1]:
                s["cash"] -= E.STATIONS[st][1]
                s["stations"] += 1
            if s["stands"] < 8 and s["cash"] >= E.STANDS[s["stands"] + 1]:
                s["cash"] -= E.STANDS[s["stands"] + 1]
                s["stands"] += 1
            z = s["zone"]
            if z < 4 and s["power"] >= bal["ladder"][z][s["rung"]] and t % 60 == 59:
                add(E.pick(rng, bal["guardian"][s["rung"]][z]), "guardian")
                if tickets:
                    tk["have"] += tickets["guardian"]
                s["rung"] += 1
                if s["rung"] == 6:
                    s["zone"], s["rung"] = z + 1, 0
                    first.setdefault("zone%d" % (z + 1), clock_now[0])
            if t >= next_drop:
                next_drop = t + DROP_EVERY
                if s["zone"] == 0 and s["power"] <= E.ROOKIE_MAX:
                    w = bal["altar"]["hub"]
                else:
                    w = bal["altar"][min(s["zone"], 3)]
                add(E.pick(rng, w), "drop")
                if tickets:
                    tk["have"] += tickets["drop"]
            if rolls:
                banner = max((b for b in bal["banners"] if b[0] <= s["zone"]), key=lambda b: b[1])
                rate = 1.0 if payer else 0.5
                cost = banner[1] * (tickets["fee"] if tickets else 1)
                if rng.random() < rate and (not tickets or tk["have"] >= 1):
                    reserve = E.STANDS.get(s["stands"] + 1, 0) * 0.5
                    if s["cash"] - reserve >= cost:
                        s["cash"] -= cost
                        if tickets:
                            tk["have"] -= 1
                            tk["used"] += 1
                            first.setdefault("roll%d" % tk["used"], clock_now[0])
                        s["rolls"] += 1
                        odds = banner[2]
                        top = max(odds, key=lambda k: E.ORDER.index(k))
                        floor = None
                        for every, tier in bal["pity"]:
                            pity[every] += 1
                            if pity[every] >= every:
                                floor = top if tier == "TOP" else tier
                        r = E.pick(rng, odds)
                        if floor and E.ORDER.index(r) < E.ORDER.index(floor):
                            r = floor
                        for every, tier in bal["pity"]:
                            if E.ORDER.index(r) >= E.ORDER.index(top if tier == "TOP" else tier):
                                pity[every] = 0
                        worst = best[-1][0] if len(best) >= s["stands"] else 0
                        v = E.INCOME[r] * E.mutation(rng)
                        if v > worst:
                            fighters.append((v, r, "roll"))
                        else:
                            s["cash"] += v * 10
                        first.setdefault(r, clock_now[0])
            if len(fighters) > 60:
                fighters[:] = sorted(fighters, key=lambda f: -f[0])[:60]
        clock += minutes
    return first


def day_of(minute):
    total = 0
    for day, m in enumerate(SESSIONS, 1):
        total += m
        if minute <= total:
            return day
    return None


def report(label, bal, keys=None, **kw):
    runs = [play(bal, s, **kw) for s in range(1, 61)]
    keys = keys or ["Epic", "Legendary", "Mythic", "Secret", "zone1", "zone2", "zone3", "zone4"]
    parts = []
    for k in keys:
        got = sorted(r[k] for r in runs if k in r)
        if not got:
            parts.append("%s never" % k)
            continue
        m = got[len(got) // 2]
        parts.append("%s %s (day %s, %d%%)" % (k, ("%dm" % m) if m < 120 else ("%.1fh" % (m / 60)), day_of(m), 100 * len(got) // 60))
    print(label)
    print("   " + "\n   ".join(parts))


GUARDIAN_NOW = [  # per rung, per zone: the guardian prize odds as the game does today (approx: shifted per zone)
    [{"Uncommon": 60, "Rare": 35, "Epic": 5}, {"Rare": 60, "Epic": 35, "Legendary": 5},
     {"Epic": 60, "Legendary": 35, "Mythic": 5}, {"Epic": 60, "Legendary": 35, "Mythic": 5}],
    [{"Rare": 75, "Epic": 25}, {"Epic": 75, "Legendary": 25}, {"Legendary": 75, "Mythic": 25},
     {"Legendary": 75, "Mythic": 25}],
    [{"Rare": 45, "Epic": 48, "Legendary": 7}, {"Epic": 45, "Legendary": 48, "Mythic": 7},
     {"Legendary": 45, "Mythic": 48, "Secret": 7}, {"Legendary": 45, "Mythic": 48, "Secret": 7}],
    [{"Epic": 80, "Legendary": 20}, {"Legendary": 80, "Mythic": 20}, {"Legendary": 80, "Mythic": 20},
     {"Mythic": 80, "Secret": 20}],
    [{"Epic": 55, "Legendary": 40, "Mythic": 5}, {"Legendary": 55, "Mythic": 40, "Secret": 5},
     {"Legendary": 55, "Mythic": 40, "Secret": 5}, {"Mythic": 55, "Secret": 45}],
    [{"Legendary": 75, "Mythic": 23, "Secret": 2}, {"Legendary": 75, "Mythic": 23, "Secret": 2},
     {"Legendary": 75, "Mythic": 23, "Secret": 2}, {"Mythic": 75, "Secret": 25}],
]
NOW = dict(
    altar={"hub": E.HUB_ALTAR, 0: E.ZONES[0][0], 1: E.ZONES[1][0], 2: E.ZONES[2][0], 3: E.ZONES[3][0]},
    ladder=[z[1] for z in E.ZONES],
    guardian=GUARDIAN_NOW,
    banners=E.BANNERS,
    pity=E.PITY,
)



def guardian_table(base, shifts=(0, 0, 1, 2), cap={"Mythic": 0.15, "Secret": 0.03}):
    """Per rung, per zone, the way shared/Odds.lua guardianWeights does it (shift, then cap)."""
    out = []
    for w in base:
        row = []
        for steps in shifts:
            sw = {}
            for k, v in w.items():
                i = min(E.ORDER.index(k) + steps, len(E.ORDER) - 1)
                sw[E.ORDER[i]] = sw.get(E.ORDER[i], 0) + v
            total = sum(sw.values())
            for key, down in (("Secret", "Mythic"), ("Mythic", "Legendary")):
                c = total * cap[key]
                if sw.get(key, 0) > c:
                    sw[down] = sw.get(down, 0) + sw[key] - c
                    sw[key] = c
            row.append(sw)
        out.append(row)
    return out


NOW["guardian"] = guardian_table([
    {"Uncommon": 60, "Rare": 35, "Epic": 5}, {"Rare": 75, "Epic": 25}, {"Rare": 45, "Epic": 48, "Legendary": 7},
    {"Epic": 80, "Legendary": 20}, {"Epic": 55, "Legendary": 40, "Mythic": 5}, {"Legendary": 75, "Mythic": 23, "Secret": 2},
])

NEW = dict(
    altar={
        "hub": {"Common": 62, "Uncommon": 30, "Rare": 8},
        0: {"Uncommon": 45, "Rare": 38, "Epic": 15, "Legendary": 2},
        1: {"Rare": 50, "Epic": 40, "Legendary": 9.7, "Mythic": 0.3},
        2: {"Epic": 60, "Legendary": 35, "Mythic": 4.8, "Secret": 0.2},
        3: {"Legendary": 78, "Mythic": 21, "Secret": 1},
    },
    ladder=[
        [2e3, 15e3, 100e3, 300e3, 1e6, 3.5e6],
        [6e6, 10e6, 16e6, 24e6, 34e6, 50e6],
        [70e6, 90e6, 110e6, 130e6, 155e6, 180e6],
        [220e6, 270e6, 320e6, 370e6, 420e6, 470e6],
    ],
    guardian=guardian_table([
        {"Uncommon": 60, "Rare": 35, "Epic": 5}, {"Rare": 75, "Epic": 25}, {"Rare": 55, "Epic": 42, "Legendary": 3},
        {"Epic": 85, "Legendary": 15}, {"Epic": 70, "Legendary": 28, "Mythic": 2}, {"Legendary": 85, "Mythic": 14.5, "Secret": 0.5},
    ]),
    banners=E.BANNERS,
    pity=E.PITY,
)



NEW2 = dict(NEW)
NEW2["altar"] = dict(NEW["altar"])
NEW2["altar"][2] = {"Epic": 60, "Legendary": 35.9, "Mythic": 4, "Secret": 0.1}
NEW2["altar"][3] = {"Legendary": 79, "Mythic": 20.5, "Secret": 0.5}
NEW2["ladder"] = NEW["ladder"][:3] + [[300e6, 380e6, 460e6, 540e6, 620e6, 700e6]]
NEW2["guardian"] = guardian_table([
    {"Uncommon": 60, "Rare": 35, "Epic": 5}, {"Rare": 75, "Epic": 25}, {"Rare": 55, "Epic": 42, "Legendary": 3},
    {"Epic": 85, "Legendary": 15}, {"Epic": 70, "Legendary": 28, "Mythic": 2}, {"Legendary": 85, "Mythic": 14.5, "Secret": 0.5},
], cap={"Mythic": 0.15, "Secret": 0.01})



NEW3 = dict(NEW2)
NEW3["pity"] = [(10, "Rare"), (50, "Epic"), (500, "Legendary")]  # pity never hands out a Mythic or Secret



TICKETS = dict(start=5, drop=3, guardian=10, reps=200, fee=0.2)  # (shared/Roll.lua Roll.Tickets)

if __name__ == "__main__":
    report("FINAL: free player, rolls with tickets", NEW3, tickets=TICKETS, keys=["Epic", "Legendary", "Mythic", "Secret", "zone1", "zone2", "zone3", "zone4", "roll10", "roll50", "roll200"])
