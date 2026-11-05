# Anime Clash — world and progression plan (v2)

Written 2026-10-19. Replaces the world layout in GAME_PLAN.md §2–3 and §11, and the art section of POLISH_BIBLE.md §3.1. PROGRESSION.md still holds; this plan puts it on a map.

---

## 0. The short answer: how progression works today, and what changes

**Today there is no second place.** The whole game is one flat island:
- 6 altars ring the plaza: 2 Bronze, 2 Silver, 1 Gold and 1 Diamond.
- Higher altars need more Power, drop rarer fighters and have tougher bots.
- That is the entire climb. It's visible from spawn on minute one, so there is nothing to discover, nothing to look forward to, and no moment where you *arrive* somewhere new.

**The new structure: the Sky Dojo Archipelago.**
- A hub island, plus **seven zone islands** floating around it, each themed to the anime its fighters come from.
- Each zone has its own altars, tougher opponents, rarer drops, its own look, lighting and music, and a **Dojo Ladder**: 5 guardians and a boss. Beat the boss and the bridge to the next zone opens.
- This is the proven top-Roblox pattern:
  - Arm Wrestle Simulator: beat harder bosses map by map.
  - Anime Fighters Simulator: per-world enemies, a quest NPC, and a final boss.
  - Pet Simulator 99: area gates, where each unlock opens new content and costs escalate.
- It uses *our* hook, the Beam Rally, as the thing you climb with.

The rule from PROGRESSION.md, extended: **"Upgrades help you climb the zones. Skill wins everywhere."** Bots and bosses feel your Power. Another human never does.

---

## 1. Audit of the current world (looked at live, 2026-10-19)

| # | Problem | Why it kills excitement |
|---|---|---|
| 1 | **It's a pancake.** One disc of grass at a single height. No hills, terraces, cliffs or water. | From ground level you see a green floor and the backs of things. Nothing invites you to climb or explore. |
| 2 | **No landmark.** The colosseum is a low red wall; the drop portal is a thin ring in the sky. | Top games have one huge silhouette you can see from anywhere (a tower, a statue, a volcano). It orients you and is the thumbnail. |
| 3 | **Mixed styles.** Smooth low-poly CC0 trees, rocks and grass sit next to studded plates. | It reads as an asset flip, and the studs look accidental instead of chosen. |
| 4 | **Empty space.** Big green gaps between areas, sparse props, paths that are flat beige strips. | Density is what makes a Roblox world feel alive. Empty grass reads as unfinished. |
| 5 | **Plots are grey grids with a torii.** | Your base is where you spend the most time and show off. It has no personality and no growth. |
| 6 | **Altars are small white blobs** that look the same at every tier. | They're the reason to move, yet they're the least readable thing on the map. |
| 7 | **Washed-out sky and light.** Hazy blue-grey horizon, flat noon light, sphere clouds everywhere. | No mood and no contrast. Screenshots and thumbnails look pale. |
| 8 | **Nothing moves** apart from fighters. No water, banners, birds, crowds or falling petals. | Motion is what makes a still world feel alive at a glance. |
| 9 | **One area, all visible from spawn.** | There's no "what's over there?" and no reward for progressing. |

Verdict: the systems are good, but the world is a prototype. It needs a rebuild, not a decoration pass.

---

## 2. The archipelago (layout)

```
                         [7] KI PLANET  (green sky, rock spires)
                                  |
          [6] DUNE PYRAMIDS ------+------ [5] SPIRIT TEMPLE
                 \                                /
                  \          ( HUB )             /
   [4] WALLED CITY ---- SKY DOJO: Colosseum ---- [3] PIRATE BAY
                       + Summit Pagoda
                       + 8 plot islets
                         /          \
            [1] BLOSSOM ACADEMY    [2] NINJA VILLAGE
                         \___ spawn ___/
```

- **Hub: Sky Dojo.** Spawn, plots, shops and the Colosseum. Everyone passes through it, and all player-vs-player headline moments happen here (§5).
- **Zones** float at different heights and distances. A gate opens onto a walkable bridge, so the first trip feels like a journey. After that, the World Map and teleport pads make the trip instant, as in Pet Simulator 99.
- **Locked zones are visible from the hub:**
  - each has its colour beam, its landmark silhouette and a chained torii gate;
  - the boss's giant silhouette stands on its summit;
  - the gate sign reads "Beat the Pirate Bay Captain to open".

  That gives the player the "what's over there?" pull.
- **At launch: the hub plus zones 1–4.** Zones 5–7 ship as updates, one every 1–2 weeks, each one a marketing beat. They also hold back the biggest names (Aizen, Dio, Vegito) for hype.

---

## 3. What every zone contains (the template)

```
 bridge from previous zone / hub
        |
   [ARRIVAL PLAZA]  title card slams in: "NINJA VILLAGE"
   quest NPC · teleport pad · zone shop window
        |
   [ALTAR GROUNDS]  3 altars with this zone's drops (open to all who reached the zone)
        |
   [THE DOJO LADDER]  a path climbing the island over 3–4 terraces
     rung 1 → rung 2 → rung 3 → rung 4 → rung 5   (guardians on studded podiums)
        |
   [BOSS ARENA]  summit set-piece, the zone's landmark
        |
   [SUMMIT ALTAR]  best drops in the zone, unlocked by beating the boss
        |
   gate → bridge to the next zone
   + 1 hidden spot (secret chest, daily gems) to reward exploring
```

### The Dojo Ladder (how you climb)
- **5 guardians per zone.** Each is a fighter from that zone's series, scaled 1.3×, standing on a studded podium with a name banner. Walk onto the challenge pad to start a Beam Rally against them.
- **Guardians get tougher by rung.** Bot skill steps up inside the zone's band (§5).
- **First clear rewards:** gems, Champion XP, and a guaranteed fighter from the zone on rung 5.
- **Re-fights:** once per day per guardian, for small gem rewards (the "daily ladder").
- **The boss is locked until rung 5 is cleared.** A boss is a best-of-5 rally with a **signature mechanic** (§4). At its match point it **transforms**: a cinematic and a second phase.
- **Beating the boss:**
  - opens the gate and the next zone for you;
  - unlocks the Summit Altar;
  - plays a server-wide banner ("clawchin17 defeated the Storm Captain!");
  - unlocks a zone title.
- **Soft gate, not a hard wall.** Each zone shows a *Recommended Power*. Power softens guardians and bosses (as it already does for altar bots), but a skilled player can clear under-powered, and that's a flex. Zones 5+ also need rebirths (a hard gate, as Pet Simulator 99 does) so the long game has milestones.

---

## 4. The seven zones

Names are placeholders (in-game names are coming later). Each zone's fighter pool is the series listed, 148 fighters in total. Boss mechanics are all built on the existing Beam Rally.

| # | Zone | Series pool | Landmark | Palette, light | Boss and mechanic | Rec. Power | Hard gate | Target arrival |
|---|---|---|---|---|---|---|---|---|
| 1 | **Blossom Academy** | MHA, YYH, others (24) | Giant school clock tower in a blossom grove | Pink, white, sky blue; golden morning | **Sensei:** the tutorial boss. Telegraphs PERFECT timing; teaches SMASH. | 0 | – | spawn |
| 2 | **Ninja Village** | Naruto, HxH (26) | Five-storey pagoda on a cliff, carved stone faces in the cliff | Warm orange, red, navy; dusk with lanterns | **Shadow Ninja:** *Feint* (the orb stops mid-flight, then goes on; early presses whiff). *Clones* (two orbs, one fades). | 50 | – | ~10 min |
| 3 | **Pirate Bay** | One Piece, Fairy Tail (17) | Huge galleon docked in a ring-shaped harbour, lighthouse | Teal water, sand, red sails; bright noon | **Storm Captain:** *Cannon curve* (the orb speeds up in the last third). *Broadside* (three orbs in a row). | 400 | – | ~40 min |
| 4 | **Walled City** | AOT, Fate (22) | Colossal stone wall with a titan's face looking over it, castle keep | Stone grey, brick, green banners; overcast, dramatic | **Wall Colossus** (giant scale): *Heavy orb*. Mash it below a speed before deflecting or it breaks through; mashing becomes the boss mechanic. | 3K | Rebirth 1 | ~2 h |
| 5 | **Spirit Temple** | Bleach, JJK (27) | Floating white palace over a black-water lake, giant moon | White, black, ice blue, violet; night | **Soul King:** *Eclipse* (the orb goes dark mid-flight; play off the ring and the sound). | 25K | Rebirth 2 | ~6 h |
| 6 | **Dune Pyramids** | JoJo (17) | Golden pyramid with a giant stand-like statue, sun disc | Gold, sand, magenta, teal; harsh sun, heat haze | **Pharaoh:** *Time Stop* (the world freezes for 1 s mid-rally and the orb jumps closer). | 200K | Rebirth 3 | ~15 h |
| 7 | **Ki Planet** | DBZ (15) | Rock spires, a cratered arena, a giant planet in the sky | Green sky, blue grass, orange rock; alien | **Ki Emperor:** two orbs from the first serve and OVERDRIVE from rally 1. Phase 2 is a golden transformation. | 1.5M | Rebirth 5 | ~30 h+ |

---

### 4.1 Zone 1 in detail: Blossom Academy (anime high-school campus)
Decided 2026-10-20 after the first build read too much like the hub. Rule for every zone: **a different landmark, layout, ground, props, sky and sound from the hub, not just different colours.** The hub is a red-and-gold temple festival on a round terraced island; Blossom Academy is a bright modern anime school on a long strip.

**Layout: a long campus strip** (about 90 × 300 studs), walked front to back, then up to the roof:
1. **Front gate and cherry avenue.** You arrive here.
   - A school gate with stone pillars, a nameplate and a sliding iron gate, then a paved avenue under blossom trees.
   - Bike racks, a bus-stop sign and the return pad.
2. **Front courtyard (altar grounds).**
   - A paved courtyard round a fountain; the 3 drop altars stand on it, under the drop portal.
   - Vending machines, benches, a notice board and a flagpole.
3. **The school building** (the landmark): three storeys long, with a central clock tower and lit classroom windows (desks and chalkboards inside).
   - An outside zig-zag staircase climbs to the **rooftop**: a chain-link fence, a water tank and the **boss arena**. This is the classic anime rooftop showdown.
4. **Behind the building, the ladder loops round the campus:**
   - Guardian 1: the entrance hall (shoe lockers).
   - Guardian 2: the gym (basketball court).
   - Guardian 3: the pool deck (lane ropes, diving boards).
   - Guardian 4: the running track.
   - Guardian 5: the sports field (goals, scoreboard).
   - Then back to the building and up the stairs to the boss on the roof.
5. **Exit gate to Ninja Village** at the far end of the sports field, on a pier.

**Ground:** mostly smooth paving, with studded grass only in planters and verges.
- light grey courtyard tiles
- a red running track with white lanes
- a green field with white lines
- a blue pool with lane ropes
- a wooden gym floor

**Zone-only props** (never used in the hub):
- the school gate
- bike racks with bikes
- glowing vending machines
- benches and modern lamp posts (instead of stone lanterns)
- shoe lockers, desks and chalkboards (seen through the windows)
- basketball hoops, soccer goals, hurdles, the scoreboard
- pool ladders and diving boards
- the rooftop fence and water tank
- the flagpole, the notice board, potted plants

**Palette:** cream walls, slate-blue window frames, teal roof edges, the red track, green fields and pink blossoms. No vermilion, no gold-and-red.

**Sky and light:** bright clear morning (about 8:30), cool white haze and drifting petals. The hub stays golden hour.

**Sound:** the school chime on a timer, birdsong, a distant sports whistle and the ambient murmur of a courtyard. The audio assets still need to be sourced from the Roblox audio library.

## 5. How opponents get tougher, and how player-vs-player stays fair

**Against the game (vertical):**
- Each zone has a bot skill band that extends today's `Config.BotSkill`:
  - zone 1: Easy → Bronze
  - zone 2: Bronze → Silver
  - zone 3: Silver → Gold
  - zone 4: Gold
  - zone 5: Gold → Diamond
  - zone 6: Diamond
  - zone 7: Diamond+ (fade about 0.17)
- Guardians climb the band rung by rung. Bosses sit at the top of the band and add their mechanic.
- Altar bots in a zone use the band's middle.
- Power still lowers bot skill, so the economy has a clear job: buy Power to make the next zone's guardians beatable.

**Against players (horizontal, equal stats):**
1. **Zone altars.** Anyone in the zone can contest a drop. Two humans clash at equal strength; an empty seat fills with a bot after 3 s.
2. **Main Event (the Colosseum), the headline player-vs-player moment.**
   - Every 3–4 minutes a server-wide banner announces "MAIN EVENT in 30 s — LEGENDARY drop". Every player in every zone gets a **JOIN** button that teleports them to the Colosseum.
   - The format is **winner stays on**: the champion holds the stage, challengers queue, and each clash is one round. When the timer ends, whoever holds the stage wins the fighter.
   - Spectators watch on giant screens and in the stands, and everyone who joined gets gems.
   - With 8 players spread over 4+ zones, this pulls them all back into one place for the big moments.
3. **Ranked queue** at the Colosseum (Clash Rank, from PROGRESSION.md).

---

## 6. Drops by zone

- A zone's altars roll **rarity first** from the zone's odds, then a fighter of that rarity from the **zone's series pool**. If the pool has none at that rarity, the roll steps down one rarity.
- Mutation chance rises by zone. The Summit Altar uses the next zone's odds.

| Zone | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret | Mutation |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 55% | 30% | 12% | 3% | – | – | – | 5% |
| 2 | 25% | 35% | 28% | 11% | 1% | – | – | 7% |
| 3 | – | 35% | 38% | 22% | 5% | – | – | 9% |
| 4 | 5% | 25% | 33% | 26% | 9% | 2% | 1 in 2,000 | 11% |
| 5 | – | – | 35% | 40% | 20% | 5% | 1 in 1,000 | 13% |
| 6 | – | 15% | 30% | 35% | 15% | 5% | – | 15% |
| 7 | – | – | 25% | 40% | 25% | 10% | 1 in 500 | 18% |

Secret chances come out of the Mythic share. So no fighter is left out of the Index: every zone also has a **5% "local" roll** that picks any fighter in the pool regardless of rarity. That covers a zone 5 Common like Rukia. (The numbers are a first pass; tune them in `Config.Zones` against playtests.)

---

## 7. The full progression, layer by layer

| Time scale | What the player does | What pulls them on |
|---|---|---|
| **30 s** | A drop lands, they rush, clash, win and the fighter flies home | The rally itself: speed, PERFECTs, the SMASH gamble |
| **5 min** | Collect plot cash, buy Power, take the next guardian rung | The rung counter "3 / 5" and the next guardian standing in view |
| **30 min** | Beat the zone boss, open a new zone, see it for the first time | The arrival title card, a new look and music, a new series to collect |
| **Session** | Main Events, the daily ladder, quests, one boss | The Main Event banner every 3–4 min; daily gems |
| **Days** | Rebirth (×1.5 income and Power, keeps zones, fighters and gems) to pass the rebirth gates of zones 4–7 | The next locked island hangs in the sky with its boss silhouette |
| **Weeks** | The Index (one page per zone), mastery contracts, Clash Rank, streaks | A new zone every 1–2 weeks; a monthly rank reset |

**Currencies (unchanged):** Cash comes from plots and buys Power, slots and rebirth. Gems come from wins, guardians, the daily ladder and the Index, and buy cosmetics and spins.

**What saves (needs DataStore, which moves up the build order):** cash, Power, rebirths, fighters and plot, zones unlocked, ladder rungs cleared, bosses beaten, daily ladder timestamps, Index, gems, Champion, mastery and rank.

**First-session targets:**
- first clash within 20 s;
- first win within 2 clashes;
- first guardian at about 3 min;
- the Sensei beaten and Ninja Village open at about 10 min. The first zone reveal is the session-one wow moment.

---

## 8. The hub, rebuilt: Sky Dojo

Three terraces instead of one disc:

1. **Lower ring: spawn and plots.**
   - Spawn sits on a studded courtyard facing up the grand stairs toward the Colosseum and the Summit Pagoda, so your first view is the landmark.
   - The 8 plots are **personal islets** hanging off the ring, each joined by a short bridge.
   - Each plot has a **base building that grows with rebirth**: tent → dojo → pagoda → floating palace. Pedestals sit in stepped rows, the collector is a coin fountain, and the nameplate arch carries the owner, $/s and rank.
2. **Middle: market street.** Studded shop fronts with striped awnings, hanging lanterns and big floating icons:
   - Power Dojo (upgrades)
   - Champion Hall (styles)
   - Gem Shrine (spins)
   - Rebirth Gong
   - Index Library
   - Quest board
   - leaderboard pillars

   It's a real street with things on both sides, not stalls on grass.
3. **Top: the Colosseum and the Summit Pagoda.**
   - The Colosseum is an enclosed bowl: tiered studded stands full of cheering NPC crowds, giant screens showing the live clash, flag poles and a stage with a glowing ring.
   - Behind it rises the **Summit Pagoda**: five storeys, about 140 studs, red and gold, with a dragon coiled around it. It's the island's silhouette and the game thumbnail. The drop portal hangs from the dragon's mouth.

**Zone gates** ring the hub's edge: big torii, each in its zone's colour, with a bridge launching into the sky toward that island.

**Water:** waterfalls pour off every terrace edge and off the island rim into the clouds. Studded blue plates with scrolling texture, plus mist particles and sound.

### 8.1 Your base (where your fighters live)

**Where:** every player's base is one of the 8 **plot islets on the hub's lower ring**. It's yours for the session, and it is not in the zones. Why the hub:
- **Everyone sees everyone's collection.** Every player passes the ring on the way to a zone gate or the Colosseum, so a base full of glowing Mythics is a public flex. Spreading bases across zones would hide them.
- **Raids** (approved earlier) need bases next to each other, near the action.
- **One home to return to** gives the session a rhythm: go out to a zone, climb, come back richer, upgrade, show off, go out again.

**What's on it:**
- **The base building** grows with rebirth: tent → dojo → pagoda → floating palace. Your progress is visible from across the hub.
- **Pedestals** in stepped rows: start with 8 and buy rows up to 40. Fighters stand in their pose with a rarity glow; Mythic and Secret get a ground crack and a light.
- **The showcase podium** at the entrance arch holds your best fighter at 2× scale, so passers-by see it first.
- **Zone wings:** each row of pedestals takes the trim of the zone its fighters came from (blossom pink, ninja orange, pirate teal…). A base filled from Pirate Bay *looks* like Pirate Bay, which shows how far you've climbed.
- **The collector fountain** fills with coins as income builds.
- **The nameplate arch** shows your name, $/s, rebirth, Clash Rank and win streak.
- **Storage** for extra fighters (up to 100), placed from a panel.

**Gaps that zones create, and their fixes:**
1. **Winning a fighter far from home:** the fighter launches as a comet from the zone altar across the sky to your base. Everyone on the hub sees a rare one land, with a beam and a banner. If you're in the zone, a small "sent home" card shows it standing on its pedestal.
2. **Collecting cash while away:** income piles up in the fountain without a cap on time (a soft cap at 2 hours of income encourages returning). The **Home** button on the HUD teleports you to your fountain. The Auto-collect pass sends cash straight to you anywhere.
3. **Raid defence while you're out climbing:** the raid rules stay as approved in HIT_PLAN §5.4, adjusted for zones.
   - The RAID alarm reaches you in any zone, and the **Return** button teleports you home from anywhere, so distance is never unfair.
   - If you don't come back, the defender bot fights at 80%.
   - While you're inside a guardian or boss fight, the defender bot takes the raid at 100% instead, so climbing is never punished.
   - Shields, the raid-only-up rule and revenge are unchanged.
4. **Rejoining:** you get a free plot on join. Your building, pedestals and fighters rebuild from your save, with a short "unpacking" animation.

---

## 9. Art bible: "Brick Anime"

The look: **a bright toy-brick world.** Everything is built from studded bricks, with anime colour, lighting and effects on top.

**Rules**
1. **Everything in the world is bricks.** Top surfaces use studs and undersides use inlets. Plastic material, chunky proportions, with no smooth CC0 meshes in the world (they come out). Fighters and VFX are the only non-brick things.
2. **Every height change is a step** of 2, 4 or 8 studs. Islands are layered terraces with stepped cliff edges, and undersides are inverted stepped brick pyramids with hanging vines and chains.
3. **Shapes have silhouettes:**
   - roofs are stepped wedges with upturned corners;
   - trees are stacked studded block canopies (blossom, pine, palm, maple, dead);
   - rocks are stepped studded boulders.
4. **Three colours plus one accent per zone.** Altars and gates use the zone's accent, so the important things are the brightest.
5. **Density:**
   - nothing on a walkable surface is more than about 12 studs from a prop;
   - paths have borders, lamps and fences;
   - grass has brick flowers and tufts.
6. **Motion everywhere:**
   - waterfalls, falling petals and leaves;
   - waving banners (tweened), spinning windmills and wheels;
   - bobbing floating rocks, birds and koi;
   - NPC crowds and training dummies;
   - flickering lanterns at night zones.
7. **Light per zone.** ClockTime, Atmosphere colour and density, ColorCorrection (saturation +0.15 to +0.25), Bloom and a painted Sky. The client switches presets smoothly as you cross into a zone.
8. **Sound per zone:** an ambient bed and a music loop (hub: festive taiko; Ninja: shakuhachi dusk; Pirate: sea shanty percussion; and so on), plus positional sources for waterfalls, crowds and wind.
9. **Readability first.**
   - Altars have tall tier-coloured light pillars visible from 300 studs.
   - Guardians have floating name banners and rung numbers.
   - The boss stands at 3× scale on the summit.

**Brick Kit (built in code, one module, reused by every zone):**
- **Terrain pieces:** terrace, stepped cliff, island underside, stairs, ramp, bridge (plank or stone or rope), path with border.
- **Nature:** tree (5 kinds), bush, flower patch, rock (3 sizes), waterfall, pond with koi, cloud bank.
- **Buildings:** wall, pagoda storey, stepped roof, shop front, fence, gate/torii, lantern (post, hanging, stone), banner, crate, barrel.
- **Gameplay pieces:**
  - altar (tiered, light pillar)
  - guardian podium with challenge pad
  - boss arena ring
  - teleport pad
  - zone gate with lock state
  - plot base (4 growth stages)
  - pedestal
  - collector fountain
- **Zone-specific pieces:** the galleon, the titan wall face, the moon palace, the pyramid with its statue, the rock spires and planet. Each is one bespoke builder.

**Performance budget (mobile first):**
- Hub at most 12K parts; each zone at most 8K.
- `StreamingEnabled` on, with islands 700–1,000 studs apart so only the hub plus one zone streams in.
- Teleports call `RequestStreamAroundAsync` before moving the player.
- Particles are capped per zone. Lighting uses ShadowMap, and night zones use a few large lights, not many small ones.

---

## 10. Technical plan

- **`Config.Zones`**, data only. Per zone:
  - id, name, series, centre and height
  - palette, lighting preset, music
  - drop odds and mutation chance
  - bot band
  - guardians (fighter key and skill)
  - boss (fighter key, mechanic, phases)
  - recommended Power and rebirth gate
- **`shared/BrickKit.lua`:** every kit piece as a function returning a Model (deterministic, tagged for the client effects).
- **`server/World/Hub.lua` and `server/World/Zones/<Zone>.lua`:** a hand-authored layout per island (coordinates in data), built from the kit. This replaces the current `World.lua` (the old builder is kept until the hub passes review).
- **`server/Services/ZoneService.lua`:**
  - unlock state, gate doors and teleport pads;
  - the "entered zone" event, which drives the title card, lighting and music;
  - guardian and boss challenge pads → ClashService with an opponent spec (skill plus mechanic);
  - first-clear and daily rewards.
- **ClashService:** add opponent specs (guardian or boss) and the rally modifiers:
  - feint, clones, curve and volley
  - heavy, eclipse and time-stop
  - double orb and phase change

  Each modifier is a pure function in `ClashRules`, with tests.
- **DrawService:** zone odds and pool rolls, and the Main Event (winner stays on) at the Colosseum.
- **DataService (moved up):** the DataStore profile with session locking. Zone progress has to persist from day one.
- **Client:** `ZoneLighting.lua` (preset blend), `ZoneTitle.lua` (title card), `WorldMap.lua` (map panel and teleport), and Ambience by zone.

---

## 11. Build order

The rebuild adds about 3 weeks to the remaining plan. Each step ends with screenshots for your review before the next one starts.

| Step | Deliverable | What you review |
|---|---|---|
| **W1. Brick Kit and art bible** | Every kit piece in a "kit gallery" place, with lighting presets | A gallery screenshot sheet. We agree the look **before** building islands |
| **W2. Hub rebuild** | Sky Dojo: terraces, Colosseum bowl with crowd, Summit Pagoda, market street, plot islets with growth stages, waterfalls, gates | Aerial, spawn view, plot, market and Colosseum shots, plus a phone-sized test |
| **W3. Zone framework and saving** | `Config.Zones`, ZoneService, guardians, bosses (Sensei and Shadow Ninja mechanics), gates, teleports, World Map, DataStore profile | Play from spawn to Ninja Village; progress survives a rejoin |
| **W4. Zones 1–2 built** | Blossom Academy and Ninja Village fully dressed, lighting, music | The first-session run (target: second zone at about 10 min) |
| **W5. Zones 3–4 and the Main Event** | Pirate Bay and Walled City with their bosses; winner-stays-on Colosseum event | A full launch-content playthrough plus a two-client Main Event test |
| **W6. Polish and performance** | Audio pass, mobile performance (part budgets, streaming), thumbnails and icon from the Summit Pagoda | Phone FPS numbers; a final screenshot set |
| Updates | Zone 5 → 6 → 7, one every 1–2 weeks | – |

Champion styles, streaks and gems (PROGRESSION.md steps 2–5) slot in around W3–W5; they don't depend on the art.

---

## 12. Decisions (answered 2026-10-20)
1. **Launch with 4 zones** (Blossom Academy, Ninja Village, Pirate Bay, Walled City). Spirit Temple, Dune Pyramids and Ki Planet ship as updates 1–2 weeks apart.
2. **The Main Event is winner-stays-on** at the Colosseum.
3. **Imported models get the stud skin.** Models may come from online CC0 sources or the Studio Toolbox. Each one gets a stud texture on its upward faces, is recoloured to the zone's flat toy palette and set to Plastic, so everything reads as one brick world. Architecture, terraces and landmarks are built from real studded Parts.
4. **The kit gallery comes first.** Every kit piece is shown under each zone's lighting, and we approve the look before any island is built.

5. **Blender is a main building tool** (the user's reminder). Hero landmarks, curved or detailed buildings, statues and natural rocks are modelled in Blender and get studs applied for Studio. Modular, repeated pieces (terraces, paths, walls, fences, trees) stay code-built from real studded Parts. The stud method for meshes is chosen by a side-by-side test next to a real studded Part. The candidates:
   - (a) a stud MaterialVariant applied in Studio;
   - (b) studs baked into the texture in Blender;
   - (c) real stud geometry on top faces.

The quality bar is "the highest quality" (the user's words): nothing ships until it holds up in a close-up screenshot.

Sources:
- [Arm Wrestle Simulator progression (allthings.how)](https://allthings.how/arm-wrestle-simulator-pets-and-progression-explained-roblox/)
- [Anime Fighters Simulator progression (gamerempire.net)](https://gamerempire.net/anime-fighters-simulator-how-to-progress-and-level-up-fast/)
- [Pet Simulator 99 areas (bloxodes wiki)](https://bloxodes.com/wiki/pet-simulator-99/areas)
- [Pet Simulator 99 biomes (itemlevel.net)](https://itemlevel.net/pet-simulator-99-complete-biomes-list-update-5/)
- [Roblox map design patterns (playbooks.com)](https://playbooks.com/skills/taozhuo/game-dev-skills/map-design)

## 13. Direction update (2026-10-20)
- **The goal is money with a 3–4 month life.** Launch fast; the world only needs to look polished, not deeply detailed.
- **No pay-to-win roll mechanic.** We keep the current mechanics: altar drops won by clashes, plot income and the Dojo Ladder.
- **Stealing will be grab-and-run** (Steal a Brainrot style): pick up a fighter from someone's stand and carry it back to your base while they chase you. It's built after the world is done.
- **Order:** finish the world (zones 2–4 for launch), then the economy, saving, stealing, monetization and launch kit.

