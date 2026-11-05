"""When the game's existing rewards land for a realistic kid (no rolls): every exciting moment on a timeline,
graded small / big, and the longest stretches with nothing big happening. Used to place the dopamine hits.

    python3 tools/sim/moments.py
"""
import random
import roll_economy as E
import pacing as P

AURAS = [1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9]
GIFTS = [5, 10, 15, 25, 40, 60, 90]  # minutes into a session (shared/Rewards.lua)
GIFT_BIG = {60: "EPIC gift", 90: "LEGENDARY gift"}


def timeline(bal, seed=1, sessions=(60, 45, 45), knobs=None):
    knobs = knobs or {}
    rng = random.Random(seed)
    s = dict(power=0.0, ki=0.0, cash=0.0, gear=0, stations=1, stands=4, zone=0, rung=0)
    fighters, seen, log = [], set(), []
    aura = 0
    clock = 0
    drop_every = knobs.get("drop_every", P.DROP_EVERY)
    stands = dict(E.STANDS)
    stands.update(knobs.get("stands", {}))
    for day, minutes in enumerate(sessions, 1):
        if day > 1:
            best = sorted(fighters, key=lambda f: -f[0])[: s["stands"]]
            s["cash"] += sum(f[0] for f in best) * 0.5 * 8 * 3600
            log.append((clock, "big", "DAILY reward + offline cash"))
        next_drop = knobs.get("first_drop", drop_every)
        for t in range(minutes * 60):
            now = clock + t / 60

            def note(kind, text):
                log.append((now, kind, text))

            best = sorted(fighters, key=lambda f: -f[0])[: s["stands"]]
            s["cash"] += sum(f[0] for f in best)
            champ = E.CHAMP[best[0][1]] if best else 1
            per = E.GEAR[s["gear"]][0] * E.STATIONS[s["stations"] - 1][2] * champ
            s["power"] += P.REPS * per
            s["ki"] += P.REPS * per
            while aura < len(AURAS) and s["power"] >= AURAS[aura]:
                aura += 1
                note("big", "AURA tier %d" % aura)
            gears = knobs.get("gear", E.GEAR)
            while s["gear"] + 1 < len(gears) and s["ki"] >= gears[s["gear"] + 1][1]:
                s["gear"] += 1
                s["ki"] -= gears[s["gear"]][1]
                note("small", "new weights x%d" % gears[s["gear"]][0])
            st = s["stations"]
            if st < len(E.STATIONS) and s["power"] >= E.STATIONS[st][0] and s["cash"] >= E.STATIONS[st][1]:
                s["cash"] -= E.STATIONS[st][1]
                s["stations"] += 1
                note("small", "new station x%d" % E.STATIONS[st][2])
            if s["stands"] < 8 and s["cash"] >= stands[s["stands"] + 1]:
                s["cash"] -= stands[s["stands"] + 1]
                s["stands"] += 1
                note("big", "stand %d" % s["stands"])
            z = s["zone"]
            if z < 4 and s["power"] >= bal["ladder"][z][s["rung"]] and t % 60 == 59:
                r = E.pick(rng, bal["guardian"][s["rung"]][z])
                fighters.append((E.INCOME[r] * E.mutation(rng), r, "g"))
                s["rung"] += 1
                note("big", "beat guardian %d-%d (%s)" % (z + 1, s["rung"], r))
                if r not in seen:
                    seen.add(r)
                    note("big", "first " + r)
                if s["rung"] == 6:
                    s["zone"], s["rung"] = z + 1, 0
                    note("big", "ZONE %d cleared" % (z + 1))
            if t >= next_drop:
                next_drop = t + drop_every
                w = bal["altar"]["hub"] if (s["zone"] == 0 and s["power"] <= E.ROOKIE_MAX) else bal["altar"][min(s["zone"], 3)]
                r = E.pick(rng, w)
                fighters.append((E.INCOME[r] * E.mutation(rng), r, "d"))
                note("small", "won a %s" % r)
                if r not in seen:
                    seen.add(r)
                    note("big", "first " + r)
            for g in knobs.get("gifts", GIFTS):
                if t == g * 60:
                    note("big" if g in GIFT_BIG else "small", GIFT_BIG.get(g, "gift %dm" % g))
        clock += minutes
    return log


def gaps(log, kind="big", until=None):
    times = sorted(t for t, k, _ in log if k == kind)
    out = []
    prev = 0
    for t in times + ([until] if until else []):
        out.append((t - prev, prev, t))
        prev = t
    return sorted(out, reverse=True)


if __name__ == "__main__":
    log = timeline(P.NEW3)
    for t, k, text in log:
        if t < 60 or k == "big":
            print("%6.1f  %-5s %s" % (t, k, text))
    print("\nlongest stretches with no big moment (day 1-3, minutes of play):")
    for g, a, b in gaps(log, until=150)[:8]:
        print("  %5.1f min  (%.0f -> %.0f)" % (g, a, b))
