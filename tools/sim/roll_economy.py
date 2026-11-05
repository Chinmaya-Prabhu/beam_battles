"""Economy sim for the Fighter Roll (design only, nothing in the game reads this).

Plays a free player (and a payer) second by second for N minutes on the game's real numbers (incomes,
stand prices, gear, stations, zone ladders, drop odds), with a roll banner table to tune, and prints what the
player feels: rolls per minute, time to first Epic / Legendary / Mythic, where their stand fighters came from,
and how much of their cash goes into rolls.

    python3 tools/sim/roll_economy.py
"""
import random

INCOME = {"Common": 100, "Uncommon": 400, "Rare": 2000, "Epic": 10000, "Legendary": 80000,
          "Mythic": 600000, "Secret": 5000000}
ORDER = list(INCOME)
MUT = [("Normal", 88, 1), ("Golden", 5, 2), ("Zone", 4, 3), ("Diamond", 3, 5), ("Rainbow", 0.9, 10), ("Huge", 0.1, 25)]
STANDS = {5: 50e3, 6: 500e3, 7: 5e6, 8: 50e6}
GEAR = [(1, 0), (2, 100), (4, 1e3), (8, 10e3), (16, 100e3), (32, 1e6), (64, 10e6), (128, 100e6), (256, 1e9), (512, 10e9)]
# (power needed, cash price, mult) per station, in the order they open
STATIONS = [(0, 0, 2), (200, 30e3, 3), (2e3, 500e3, 5), (10e3, 3e6, 8), (200e3, 20e6, 12), (1e6, 100e6, 20),
            (12e6, 600e6, 30), (60e6, 3e9, 50)]
CHAMP = {"Common": 1.1, "Uncommon": 1.25, "Rare": 1.5, "Epic": 2, "Legendary": 3, "Mythic": 5, "Secret": 10}
ZONES = [  # (altar weights, ladder power)
    ({"Uncommon": 50, "Rare": 38, "Epic": 12}, [2e3, 4e3, 6e3, 10e3, 14e3, 20e3]),
    ({"Rare": 45, "Epic": 42, "Legendary": 13}, [120e3, 200e3, 320e3, 480e3, 720e3, 1e6]),
    ({"Epic": 55, "Legendary": 36, "Mythic": 8.5, "Secret": 0.5}, [4e6, 7e6, 12e6, 20e6, 36e6, 60e6]),
    ({"Legendary": 75, "Mythic": 23, "Secret": 2}, [200e6, 320e6, 600e6, 1e9, 1.8e9, 3e9]),
]
HUB_ALTAR = {"Common": 62, "Uncommon": 30, "Rare": 8}
ROOKIE_MAX = 100e3

# ---- the design under test -------------------------------------------------------------------------------
# Banners: (unlocked after clearing zone n; 0 = from the start), cost, odds.
BANNERS = [  # tuned 2026-10-30 (see the report in the chat): rolls never outpace the drops for the top tiers
    (0, 5e3, {"Common": 52, "Uncommon": 32, "Rare": 13, "Epic": 2.8, "Legendary": 0.2}),
    (1, 300e3, {"Uncommon": 50, "Rare": 35, "Epic": 13.5, "Legendary": 1.5}),
    (2, 15e6, {"Rare": 52, "Epic": 38, "Legendary": 9.85, "Mythic": 0.15}),
    (3, 300e6, {"Epic": 58, "Legendary": 39, "Mythic": 2.98, "Secret": 0.02}),
]
PITY = [(10, "Rare"), (50, "Epic"), (500, "Legendary")]  # every n rolls at least this (never a Mythic or Secret)
SELL_SECONDS = 10  # a sold fighter pays this many seconds of its income
ROLLS_PER_SEC = 0.6  # a kid tapping ROLL while they also do other things (Auto Roll pass: 1/s)


def pick(rng, weights):
    total = sum(weights.values())
    r = rng.uniform(0, total)
    for k, w in weights.items():
        if r < w:
            return k
        r -= w
    return list(weights)[-1]


def mutation(rng):
    r = rng.uniform(0, 100.0)
    for _, w, m in MUT:
        if r < w:
            return m
        r -= w
    return 1


def run(minutes, payer=False, seed=1, rolls_on=True):
    rng = random.Random(seed)
    power = ki = cash = 0.0
    gear = 0
    stations = 1
    stands = 4
    zone = 0  # zones cleared
    rung = 0
    fighters = []  # (income, rarity, source)
    first = {}
    counts = {"roll": 0, "drop": 0}
    spent_rolls = spent_other = 0.0
    rolls = 0
    pity = {n: 0 for n, _ in PITY}
    roll_log = []
    next_drop = 75
    for t in range(minutes * 60):
        # income from the best `stands` fighters
        best = sorted(fighters, key=lambda f: -f[0])[:stands]
        income = sum(f[0] for f in best) * (2 if payer else 1)
        cash += income
        # training: 5 taps a second half the time
        champ = CHAMP[best[0][1]] if best else 1
        per = GEAR[gear][0] * STATIONS[stations - 1][2] * champ * (2 if payer else 1)
        gain = 2.5 * per
        power += gain
        ki += gain
        while gear + 1 < len(GEAR) and ki >= GEAR[gear + 1][1]:
            gear += 1
            ki -= GEAR[gear][1]
        # stations and stands first (a kid buys the visible upgrade), then rolls
        if stations < len(STATIONS) and power >= STATIONS[stations][0] and cash >= STATIONS[stations][1]:
            cash -= STATIONS[stations][1]
            spent_other += STATIONS[stations][1]
            stations += 1
        if stands < 8 and cash >= STANDS[stands + 1]:
            cash -= STANDS[stands + 1]
            spent_other += STANDS[stands + 1]
            stands += 1
        # zones: beat the next guardian when strong enough
        if zone < len(ZONES) and power >= ZONES[zone][1][rung]:
            rung += 1
            if rung == 6:
                zone, rung = zone + 1, 0
        # drops: a win every ~75 s while fighting at the best altar open to you
        if t >= next_drop:
            next_drop = t + 75
            weights = HUB_ALTAR if (zone == 0 and power <= ROOKIE_MAX) else ZONES[min(zone, 3)][0]
            if zone == 0 and power > ROOKIE_MAX:
                weights = ZONES[0][0]
            r = pick(rng, weights)
            fighters.append((INCOME[r] * mutation(rng), r, "drop"))
            first.setdefault(r, t)
        # rolls
        if rolls_on:
            banner = max((b for b in BANNERS if b[0] <= zone), key=lambda b: b[1])
            rate = 1.0 if payer else ROLLS_PER_SEC
            n = int(rate) + (1 if rng.random() < rate - int(rate) else 0)
            for _ in range(n):
                # a kid keeps the next stand's price before rolling (the stand is the bigger thrill)
                reserve = STANDS.get(stands + 1, 0) * 0.5
                if cash - reserve < banner[1]:
                    break
                cash -= banner[1]
                spent_rolls += banner[1]
                rolls += 1
                odds = dict(banner[2])
                top = max(odds, key=lambda k: ORDER.index(k))
                floor = None
                for every, tier in PITY:
                    pity[every] += 1
                    if pity[every] >= every:
                        floor = top if tier == "TOP" else tier
                r = pick(rng, odds)
                if floor and ORDER.index(r) < ORDER.index(floor):
                    r = floor
                for every, tier in PITY:
                    want = top if tier == "TOP" else tier
                    if ORDER.index(r) >= ORDER.index(want):
                        pity[every] = 0
                value = INCOME[r] * mutation(rng)
                roll_log.append(t)
                first.setdefault(r, t)
                worst = best[-1][0] if len(best) >= stands else 0
                if value > worst:
                    fighters.append((value, r, "roll"))
                else:
                    cash += value * SELL_SECONDS
        if len(fighters) > 60:
            fighters = sorted(fighters, key=lambda f: -f[0])[:60]
    best = sorted(fighters, key=lambda f: -f[0])[:stands]
    for f in best:
        counts[f[2]] += 1
    return dict(first=first, rolls=rolls, roll_log=roll_log, zone=zone, power=power,
                income=sum(f[0] for f in best), spent_rolls=spent_rolls, spent_other=spent_other,
                counts=counts, stands=stands)


def fmt(s):
    return "-" if s is None else ("%dm%02ds" % (s // 60, s % 60))


def report(label, **kw):
    runs = [run(seed=s, **kw) for s in range(1, 41)]

    def med(xs):
        xs = sorted(x for x in xs)
        return xs[len(xs) // 2]

    print("\n==", label)
    for r in ["Rare", "Epic", "Legendary", "Mythic", "Secret"]:
        times = [x["first"].get(r) for x in runs]
        got = [t for t in times if t is not None]
        print("  first %-9s median %-8s (%d/40 runs got one)" % (r, fmt(med(got)) if got else "-", len(got)))
    for a, b in [(0, 10), (10, 30), (30, 60), (60, 120), (120, 180)]:
        if b > kw["minutes"]:
            break
        rpm = sum(sum(1 for t in x["roll_log"] if a * 60 <= t < b * 60) for x in runs) / 40 / (b - a)
        print("  rolls/min %3d-%3d min: %.1f" % (a, b, rpm))
    sr = sum(x["spent_rolls"] for x in runs)
    so = sum(x["spent_other"] for x in runs)
    print("  cash into rolls: %d%%   zones cleared (median): %d   income at end (median): $%s/s"
          % (100 * sr / max(1, sr + so), med([x["zone"] for x in runs]), "{:,.0f}".format(med([x["income"] for x in runs]))))
    print("  stand fighters from rolls: %d%%" % (100 * sum(x["counts"]["roll"] for x in runs)
                                                / max(1, sum(x["counts"]["roll"] + x["counts"]["drop"] for x in runs))))


if __name__ == "__main__":
    report("FREE player, 3 hours, no rolls (today)", minutes=180, rolls_on=False)
    report("FREE player, 3 hours, with rolls", minutes=180)
    report("PAYER (2x cash, 2x power, auto roll), 3 hours", minutes=180, payer=True)
