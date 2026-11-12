"""Pacing with cash-only weights (no Ki): when each gate, weight and station lands for an active kid.

    python3 tools/sim/cash_weights.py            # the numbers in the game
A session a day (minutes below); between sessions the base earns offline (50%, up to 8 h). While training
the kid stands at their best station (it trains by itself at 4 reps/s, plus a few taps). Every DROP_EVERY
seconds they fight for a fighter (FIGHT seconds away from training, win Power by rarity) and carry it home.
Weights are sold only once their zone is open. Buys the cheapest thing it can afford.
"""
import random, sys

SESSIONS = [60, 45, 45, 40, 40, 35, 35, 35, 30, 30]
REPS = 5.0          # an owned station trains by itself (4/s), plus some taps
DROP_EVERY = 120
FIGHT = 40
INCOME = dict(Common=100, Uncommon=400, Rare=2000, Epic=10e3, Legendary=100e3, Mythic=750e3, Secret=6e6)
CHAMP = dict(Common=1.1, Uncommon=1.25, Rare=1.5, Epic=2, Legendary=3, Mythic=5, Secret=10)
ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
MUT = [(88, 1), (5, 2), (4, 3), (3, 5), (0.9, 10), (0.1, 25)]
ALTAR = [
    dict(Common=93, Uncommon=6, Rare=1),
    dict(Uncommon=93.4, Rare=4.5, Epic=1.7, Legendary=0.4),
    dict(Rare=78, Epic=18, Legendary=3.5, Mythic=0.5),
    dict(Epic=80, Legendary=16, Mythic=3.7, Secret=0.3),
    dict(Legendary=88, Mythic=11, Secret=1),
]
GUARD = [
    dict(Uncommon=60, Rare=35, Epic=5), dict(Rare=75, Epic=25), dict(Rare=55, Epic=42, Legendary=3),
    dict(Epic=85, Legendary=15), dict(Epic=70, Legendary=28, Mythic=2), dict(Legendary=85, Mythic=14.5, Secret=0.5),
]
FIRST = [  # the guardian itself, on the first win
    ["Common", "Rare", "Rare", "Rare", "Rare", "Legendary"],
    ["Uncommon", "Rare", "Rare", "Epic", "Legendary", "Mythic"],
    ["Epic", "Epic", "Legendary", "Legendary", "Mythic", "Mythic"],
    ["Epic", "Legendary", "Legendary", "Mythic", "Mythic", "Secret"],
]
STANDS = {5: 50e3, 6: 500e3, 7: 20e6, 8: 400e6}
# (mult, power needed, cash, zone index: 0 hub, 1..4)
STATIONS = [(2, 0, 0, 0), (3, 200, 30e3, 0), (5, 2e3, 500e3, 1), (8, 10e3, 3e6, 1), (12, 200e3, 20e6, 2),
            (20, 1e6, 100e6, 2), (30, 12e6, 600e6, 3), (50, 60e6, 3e9, 3), (75, 600e6, 15e9, 4), (120, 3e9, 80e9, 4)]
ZONE_OF_GEAR = [0, 0, 0, 1, 1, 2, 2, 3, 3, 4]
GEAR_MULT = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512]

GUARDIAN_CASH = [50e3, 1e6, 20e6, 400e6]  # x rung, first clear (server/Services/ZoneService.lua)
# The numbers in the game: shared/Training.lua (Gear cost and power, WinReps) and shared/Config.lua (ladderPower).
BAL = dict(
    gear=[0, 1e3, 5e3, 250e3, 6e6, 100e6, 1e9, 8e9, 60e9, 400e9],
    floor=[0, 0, 0, 10e3, 150e3, 2e6, 20e6, 150e6, 750e6, 8e9],
    ladder=[[2e3, 6e3, 15e3, 40e3, 150e3, 600e3], [1.5e6, 3e6, 6e6, 12e6, 24e6, 50e6],
            [100e6, 180e6, 300e6, 500e6, 750e6, 1.1e9], [2e9, 3e9, 4.5e9, 6.5e9, 9e9, 12e9]],
    win=dict(Common=150, Uncommon=200, Rare=300, Epic=500, Legendary=800, Mythic=1500, Secret=3000),
)


def pick(rng, w):
    r = rng.random() * sum(w.values())
    for k, v in w.items():
        r -= v
        if r <= 0:
            return k
    return k


def shift(w, n):
    return {ORDER[min(ORDER.index(k) + n, 6)]: v for k, v in w.items()}


def play(bal, seed):
    rng = random.Random(seed)
    s = dict(power=1000.0, cash=5000.0, gear=2, st=1, stands=4, zone=0, rung=0)
    fighters = [("Common", 100.0), ("Common", 100.0)]
    log, clock = [], 6 * 60  # the tutorial: 6 minutes, ends at 1K Power with Stone Weights

    def mark(what):
        best = sorted(fighters, key=lambda f: -f[1])
        log.append((what, clock / 60, s["power"], sum(f[1] for f in best[1 : s["stands"] + 1])))

    def add(r):
        m = MUT[[i for i, _ in enumerate(MUT)][0]][1]
        x = rng.random() * 101
        for w, mm in MUT:
            x -= w
            if x <= 0:
                m = mm
                break
        fighters.append((r, INCOME[r] * m))

    for day, minutes in enumerate(SESSIONS, 1):
        if day > 1:
            best = sorted(fighters, key=lambda f: -f[1])
            s["cash"] += sum(f[1] for f in best[1 : s["stands"] + 1]) * 0.5 * 8 * 3600
        t, next_drop, busy = 0, DROP_EVERY, 0
        while t < minutes * 60:
            t += 1
            clock += 1
            best = sorted(fighters, key=lambda f: -f[1])
            champ = max(CHAMP[f[0]] for f in fighters)
            s["cash"] += sum(f[1] for f in best[1 : s["stands"] + 1])  # (the follower earns nothing)
            per = GEAR_MULT[s["gear"]] * STATIONS[s["st"]][0] * champ
            if busy > 0:
                busy -= 1
            else:
                s["power"] += REPS * per
            # buy: stand, station, weights (cheapest first)
            while True:
                opts = []
                if s["stands"] < 8:
                    opts.append((STANDS[s["stands"] + 1], "stand"))
                n = s["st"] + 1
                unlocked = s["zone"] + (1 if s["power"] >= 2e3 else 0)  # zones open: Blossom at 2K, then per boss
                if n < len(STATIONS) and s["power"] >= STATIONS[n][1] and STATIONS[n][3] <= unlocked:
                    opts.append((STATIONS[n][2], "station"))
                g = s["gear"] + 1
                if g < len(bal["gear"]) and ZONE_OF_GEAR[g] <= unlocked and s["power"] >= bal["floor"][g]:
                    opts.append((bal["gear"][g], "gear"))
                opts = [o for o in opts if o[0] <= s["cash"]]
                if not opts:
                    break
                price, kind = min(opts)
                s["cash"] -= price
                if kind == "stand":
                    s["stands"] += 1
                elif kind == "station":
                    s["st"] += 1
                    mark("station x%d" % STATIONS[s["st"]][0])
                else:
                    s["gear"] += 1
                    mark("WEIGHTS x%d" % GEAR_MULT[s["gear"]])
            z = s["zone"]
            if busy == 0 and z < 4 and s["power"] >= bal["ladder"][z][s["rung"]] * 1.0:
                r = FIRST[z][s["rung"]]
                add(r)
                s["power"] += bal["win"][r] * per
                busy = 60
                s["rung"] += 1
                if s["rung"] < 6:
                    s["cash"] += GUARDIAN_CASH[z] * s["rung"]
                mark("zone %d rung %d" % (z + 1, s["rung"]))
                if s["rung"] == 6:
                    s["zone"], s["rung"] = z + 1, 0
            if t >= next_drop and busy == 0:
                next_drop = t + DROP_EVERY
                busy = FIGHT
                if s["power"] < 2e3:
                    w = ALTAR[0]
                elif s["rung"] > 0 and rng.random() < 0.5:
                    w = shift(GUARD[s["rung"] - 1], min(s["zone"], 3))
                else:
                    w = ALTAR[min(s["zone"] + 1, 4)]
                r = pick(rng, w)
                add(r)
                s["power"] += bal["win"][r] * per
        log.append(("-- end of day %d" % day, clock / 60, s["power"], 0))
    return log


def fmt(n):
    for d, u in ((1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if n >= d:
            return "%.3g%s" % (n / d, u)
    return "%d" % n


def report(bal, runs=40):
    logs = [play(bal, i) for i in range(runs)]
    names = [x[0] for x in logs[0]]
    seen = []
    for lg in logs:
        for x in lg:
            if x[0] not in seen:
                seen.append(x[0])
    rows = []
    for name in seen:
        hits = [next(x for x in lg if x[0] == name) for lg in logs if any(x[0] == name for x in lg)]
        hits.sort(key=lambda x: x[1])
        mid = hits[len(hits) // 2]
        rows.append((mid[1], name, len(hits) / runs, mid[2], mid[3]))
    rows.sort()
    prev = 0
    for at, name, share, power, income in rows:
        gap = ""
        if name.startswith("zone"):
            gap = "+%.0fm" % (at - prev)
            prev = at
        print("%7.0fm  %-18s %4.0f%%  power %-7s income/s %-7s %s" % (at, name, share * 100, fmt(power), fmt(income), gap))


if __name__ == "__main__":
    report(BAL)
