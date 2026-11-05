# Anime Clash — training and visible progression

Drafted 2026-10-20 after the user's direction: progression must be **physically visible** (the body changes, or an item always on the player keeps upgrading) and follow **the usual Roblox training ladder**: train to earn points, buy better weights and stations, which earn points faster. It plugs into the loop in docs/PROGRESSION.md ("Update 2026-10-20"): train, travel, compete.

## 1. The loop in one picture

```
click / train at a station  ──►  +POWER (floating numbers, bar fills)
        ▲                               │
        │                               ├─► body grows, aura tier changes, Power Level overhead
 better gear and stations               ├─► stronger in clashes (capped per altar)
 (bought in the zone shops)             └─► opens deeper altars and zones
        ▲                                         │
        └──── currency ◄── fighters on your plot ◄┴── win rarer drops against other players
```

Every few minutes something visibly upgrades: a new gear tier on your wrists, an aura tier, a size jump, a new zone. That cadence is the dopamine schedule.

**Decided 2026-10-20:**
- Gear and stations are bought with separate training points, **Ki**, earned one for one with Power.
- Your equipped Champion follows you and multiplies training.
- The body grows wider (capped about 1.6×) on top of the aura tiers; avatars are R15.
- Rebirth ships at launch.

## 2. Power and Ki

- **Power** is the number everyone sees: "Power Level 12.4K" over your head, in the server leaderboard and in the clash face-off.
  - It only ever goes up, except at rebirth.
  - It drives the body, the aura, clash strength (capped per altar) and the altar and zone gates.
- **Ki** is the wallet. Every rep gives the same amount of Ki as Power.
  - Ki buys gear tiers and station unlocks.
  - Spending Ki never lowers Power, so shopping never makes you look or fight weaker.

## 3. Ways to gain Power

| Source | How | Rate |
|---|---|---|
| **Click training** | Click or tap anywhere outside a clash. Your character punches, with a hit flash and a "+N" pop. | Base × gear multiplier. Capped at the clash cap of 14 clicks per second. |
| **Stations** | Stand at one and click. Each has a themed animation, like the treadmill or bench of the genre. | Base × gear × station multiplier. Stations get much stronger zone by zone. |
| **Guardians** | First clear of each guardian. | A lump of Power, plus cash. |
| **Your Champion** | The fighter you equip follows you (the pet slot of the genre). It's a small version of its model and copies your training pose. | Multiplies training by rarity: Common ×1.1, Uncommon ×1.25, Rare ×1.5, Epic ×2, Legendary ×3, Mythic ×5, Secret ×10. Its mutation's multiplier stacks on top. |

### Stations by zone (themed, all clickable)

| Zone | Stations | Station multiplier |
|---|---|---|
| Hub | Punching posts, sandbag | ×2 |
| Blossom (campus) | Gym bench press, running track, pool laps | ×5 |
| Ninja | Waterfall meditation, boulder lift, tree kicks | ×12 |
| Pirate | Anchor curls, rowing boat, cannonball catch | ×30 |
| Walled | Wall climb, gravity chamber, titan-finger pull-ups | ×75 |

Each station is the "treadmill" purchase: a sign shows its Power requirement and its Ki price ("NEEDS 25K POWER · 40K KI"). Once bought, it's yours to use permanently, like Muscle Legends' rock lifts but with a price. The best station in a zone needs about 5× the zone's entry Power. Stations stand near the zone's altars, so the people training are also the people rushing the drops.

## 4. Gear: the item always on you

**Training weights on the wrists and ankles** (Rock Lee's leg weights; Goku's weighted clothing). They're worn all the time, visible on your avatar, and every tier looks clearly better. They're the "better weights" purchase.

| Tier | Gear | Click multiplier | Cost in Ki* | Sold in |
|---|---|---|---|---|
| 1 | Cloth wraps | ×1 | free | — |
| 2 | Wooden weights | ×2 | 100 | Hub |
| 3 | Stone weights | ×4 | 600 | Hub |
| 4 | Iron weights | ×8 | 3K | Blossom |
| 5 | Steel weights (riveted) | ×16 | 15K | Blossom |
| 6 | Gold weights (shine) | ×32 | 80K | Ninja |
| 7 | Chakra seals (glowing glyphs) | ×64 | 400K | Ninja |
| 8 | Sea-stone shackles (glow, chains) | ×128 | 2M | Pirate |
| 9 | Diamond weights (sparkles) | ×256 | 10M | Pirate |
| 10 | Gravity rings (orbiting, distortion) | ×512 | 50M | Walled |

\*Costs are about 5× per tier, so each purchase pays back in a few minutes at the zone you're in. The two tiers each zone sells give you a reason to travel. Final numbers come from a tuning sheet like the rally simulator.

## 5. What the player sees

1. **Body growth.** Width and depth grow with log(Power), up to about 1.6× at the top. Height grows a little, up to about 1.15×. The head stays the same so faces read. The doors in our zones are wide enough for the cap. This needs **R15 avatars**, set in Game Settings → Avatar.
2. **Aura tiers.** The anime version of "getting stronger". A tier-up plays a power-up moment: a scream pose, a screen flash, a ground shockwave and a server banner ("Kazu reached SUPER!").

| Power | Aura |
|---|---|
| 1K | White wisps rising |
| 10K | Blue flame |
| 100K | Gold flame and sparks ("SUPER") |
| 1M | Crimson flame and lightning arcs |
| 10M | Violet flame, dust ring at your feet |
| 100M | Silver "ultra" glow, floating rocks |
| 1B | Rainbow |

3. **The gear itself** on your wrists and ankles (§4).
4. **Overhead plate.** Power Level, your rank title by aura tier and your rebirth stars.
5. **In the clash.** Your beam takes your aura's colour, and the face-off shows both Power Levels. When Power is capped at an altar it shows as "CAPPED 25K".
6. **Constant feedback.**
   - "+N" pops on every click.
   - A bar to the next aura tier.
   - A "NEW GEAR AVAILABLE" ping when you can afford the next tier.
   - Server leaderboard columns: Power, Cash, Rebirths.

## 6. Rebirth (at launch)

At a Power threshold you can rebirth. Power, Ki, gear, station unlocks and body size reset. You keep your fighters, plot, zone unlocks and cash. You gain a permanent training multiplier (+50% each time), a rebirth star on your plate and a rebirth-coloured aura trim. It's the genre's long tail, and it keeps the early zones busy with returning players.

## 7. Power in clashes (capped per altar)

- Effective Power is your Power, clamped to the altar's cap.
- The edge comes from the ratio of the two effective Powers on a log scale: up to about ±35% on mash push and return speed.
- Deflect timing is untouched, so a skilled player can still beat a stronger one.

Caps (first pass):

| Hub | Blossom | Ninja | Pirate | Walled |
|---|---|---|---|---|
| 1K | 25K | 500K | 10M | none |

Sitting at an altar also needs a minimum Power: the zone's entry level.

## 8. Build plan

1. **Data.** Power, Ki, gear tier, station unlocks, rebirths, owned fighters and the equipped Champion in a new DataStore version. Leaderboard stats.
2. **Click training.** A server-checked rate, a punch animation, "+N" pops, the Power bar.
3. **Visible progression.** Body scaling, the aura tiers and the power-up moment, gear models on the wrists and ankles, the overhead plate.
4. **Gear shops.** One stall per zone selling its two tiers, plus a shop panel.
5. **Stations.** Five themed sets placed in the zones, with requirement and price signs.
6. **The Champion follower** and its training multiplier.
7. **Power in the rally** with altar caps and minimums. Tests and simulator.
8. **Rebirth.**
9. **Plot economy** (fighters earn cash), then the drop-ladder retune and guardian rewards (docs/PROGRESSION.md).

Steps 1–5 are playable on their own: you can feel the ladder before the economy exists.

## Status (2026-10-20)

Steps 1–5 are built and tested in Studio:
- **Data:** Power, Ki, gear, owned stations and rebirths are saved; Power and Rebirths show on the leaderboard.
- **Click training:** a server-capped click rate, "+N" pops, the HUD and the hint.
- **Visible layer:** the body grows with Power; seven aura tiers, each with a coloured flame, an outline glow, sparks, arcs, a dust ring and orbiting rocks as they climb; the power-up moment, with a banner the whole server sees from Super up; ten gear looks on the wrists and ankles; the overhead plate.
- **Gear stalls:** one per place; each has a single prompt that sells your next tier when that stall stocks it.
- **Stations:** ten themed stations, each bought once, with trainee poses (punch, press, lift, run, meditate, row, climb), and the barbell, boulder or anchor carried in the trainee's hands. Each station seats one trainee, and anyone moved off a station is unseated.

Changes from the plan:
- The Blossom "Bench Press" is a standing barbell rack (press pose), not a lying bench.
- Studio-only testing: setting the player attribute `DebugGrant` from the server command bar adds that much Power and Ki.

Code:
- shared: `Training.lua` (rules and maths, tested in `tests/training.spec.luau`), `GearLook.lua`
- server: `Zones/GymKit.lua`, `Services/TrainingService.lua`
- client: `Training.lua`, `Aura.lua`, `TrainPose.lua`

**Step 6 (Champion follower):** done.
- Every fighter a player wins in a clash is saved (up to 400; past that, a better fighter replaces the weakest).
- The best one is equipped automatically, with a "NEW CHAMPION" banner.
- It floats at the player's right with its name and multiplier, sparkles if mutated, and powers up while its owner trains.
- Its multiplier applies to every rep: by rarity (Common x1.1 to Secret x10) times a gentler mutation bonus (Golden x1.25, Diamond x1.5, Rainbow x2, Huge x3).
- Studio testing: setting the player attribute `DebugFighter` = "Sukuna:Golden" from the server command bar wins that fighter.
- Choosing a Champion by hand comes with the inventory and shop UI.

Next: step 7 (Power in the rally with altar caps), then 8–9.
