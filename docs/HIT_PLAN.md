# Anime Clash — the hit plan

This supersedes the design parts of GAME_PLAN.md (the technical sections there still apply). Goal: a game that unfamiliar kids can't stop playing, that looks like a top-10 game in a 2-second glance, and that has every ingredient the 100k+ CCU games share.

**Honest framing:** only a few dozen Roblox games hold 100k+ concurrent players at any moment. Nobody can guarantee it. What we *can* control: a loop that hooks in 30 seconds, visuals that win the click on the Discover page, moments that get clipped, a weekly update rhythm, and retention numbers good enough that Roblox's recommendations keep pushing the game. Everything below serves one of those. (My knowledge of specific charts runs to mid-2026; check what's trending the week we launch.)

---

## 1. Why day 1 looks terrible (diagnosis)

| Problem | Why it kills a game | Fix (§7) |
|---|---|---|
| Flat grey floor, flat default lighting | Reads as "unfinished" in screenshots and the first 2 seconds | Floating sky island, anime golden-hour lighting, saturated colour grade |
| Tables are small brown boxes in a big empty square | Nothing to look at, nothing feels important | One huge central stage + few, grand drop altars |
| Fighters are 7 studs tall and static | The prize doesn't feel like a prize | 2–3× scale on drop, auras, idle motion, beam-from-the-sky entrance |
| Nameplates overlap into unreadable text | Clutter = cheap | One clean card per fighter, shown only near/hovered |
| No UI, no sound, no effects | Zero dopamine per action | Every action gets a number, a sound, a pop and a shake |
| No reason to look up or run | No anticipation | Server-wide countdown to the next drop, visible from everywhere |

The *systems* from day 1 (cleaned fighters, posing, odds, tiers) are kept. The *world and presentation* are rebuilt.

---

## 2. What 100k-CCU Roblox games have in common

From the breakout hits of 2025–26 (Grow a Garden, Steal a Brainrot, 99 Nights in the Forest, Dig, Fisch, Pet Simulator 99 and others):

1. **Understandable in one glance, playable in one tap.** No tutorial needed. A 7-year-old gets it from the thumbnail.
2. **A collection of characters kids already talk about.** Brainrots, pets, fruits. Ours: anime fighters (the strongest fandom on the platform).
3. **Other players matter.** Steal a Brainrot's stealing, trading in Grow a Garden. Other players create stories ("he stole my Secret!").
4. **Server-wide moments.** Weather events, admin events, rare spawns: everyone in the server sees the same thing at the same time, and screams. These are what get clipped.
5. **Timers that bring you back.** Shop restocks, crops growing offline, timed events. Kids come back on a schedule.
6. **Numbers that only go up**, fast at first, with a visible next goal at all times.
7. **Weekly updates on a fixed day**, announced in-game with a countdown. CCU spikes every update day.
8. **Codes, group rewards, like goals.** Cheap growth loops that turn players into marketers.
9. **Chunky, bright, readable visuals** that look good on a phone at small size. Not realistic, not cluttered.

Our current concept has 2, partly 3 and 6. The plan below adds the rest.

---

## 3. The new hook

> **"Win anime fighters in beam clashes — then steal them from other players."**

Three changes make the game's fantasy much stronger:

1. **The click battle becomes a BEAM STRUGGLE.** The single most iconic anime image (Kamehameha vs Galick Gun, Naruto vs Sasuke) — two energy beams colliding, the collision point pushed back and forth. Every click pushes your beam. This is instantly readable, looks spectacular, and it's what kids already act out on the playground.
2. **Your fighters fight *with* you.** You equip a team of 3. Your best fighter appears as a giant spirit behind you in a clash, and the team's rarity sets your beam's colour, power bonus and ultimate. Collecting now means power, not just income — every new rare is a reason to go clash.
3. **You can raid other players' plots.** Walk up to someone's fighter, press **CHALLENGE**: the owner gets a "RAID!" alarm and has 10 seconds to rush back and defend in a beam clash. Win and the fighter is yours. This is the Steal a Brainrot drama engine, made fair by skill and with protections (§5.4).

The table/drop system stays as the fair, always-available source of fighters. Raids are the high-stakes, high-drama layer on top.

---

## 4. The psychology map

Every feature exists to trigger one of these. Listed with how we use it — and, where relevant, how we keep it honest (the audience is mostly children; §12).

| Trigger | What it is | Where it lives in Anime Clash |
|---|---|---|
| **Variable rewards** | Unpredictable payoffs are the most compelling kind | Every drop rolls rarity + mutation; every clash win can be a Huge Rainbow |
| **Anticipation** | The build-up releases more dopamine than the reward | Server countdown to next drop, portal charging, 3-2-1 before beams fire, reveal card that flips |
| **Genuine near-miss** | "So close" makes you try again | Clashes are tight by design (comeback surge, rubber-band); "LOST BY 4 CLICKS" + instant REMATCH. Never faked |
| **Spectacle / awe** | Big, loud, bright moments | Legendary drops: sky turns colour, beam from the portal, whole server shakes |
| **Social proof** | We want what others want | Server announcements ("Jay got a MYTHIC GOJO!"), crowds gathering at clashes |
| **Status** | Being seen as rare/strong | Plot podium for your best fighter, titles over your head, aura colour by rebirth, leaderboards |
| **Loss aversion** | Losing hurts twice as much as winning feels good | Raids — defend what's yours. Balanced with locks and shields so it's exciting, not miserable |
| **Revenge / reciprocity** | Settling scores | REVENGE tag for 60 s after a raid; steal it back at +50% |
| **Competence** | Getting better feels good | Clicking rhythm, Surge timing, Ultimate timing — real skill on top of stats |
| **Collection completion** | The urge to fill the set | Index by series with page rewards; silhouettes of what's missing |
| **Goal gradient** | Effort speeds up near a goal | Progress bars everywhere: next rebirth, next Index page, next table tier, "2 wins to daily reward" |
| **Endowed progress** | Starting with something makes you continue | You start with one fighter already on your plot and a bar 20% filled |
| **Streaks** | Don't break the chain | Win streak flames; daily login streak with a big day-7 reward |
| **Appointment** | Coming back at set times | Restock every 5 min, events on the hour, update every Saturday with a lobby countdown |
| **Belonging** | Playing with friends | Friend boost, raid parties, co-op Titan raids where the whole server wins together |
| **Ownership** | It's *mine* | Your plot, your nameplate, your team, your fighter names on the leaderboard |

---

## 5. Systems (the full game)

### 5.1 Drops (the free source of fighters)

- A giant **Summoning Portal** hangs in the sky over the central plaza, visible from every plot. A big countdown hangs under it: **"NEXT DROP 0:24"**.
- At zero: the portal spins up, the sky tints to the rarity colour, a beam slams into one of the **Drop Altars** (6 altars ringing the plaza, tiered Bronze → Diamond), shockwave, dust, the fighter stands up 2–3× human size in its aura. Nameplate card pops.
- **Small drops every 20–30 s** (Common–Epic) keep the plaza busy. **Big drops** (Legendary+) are on a visible schedule ("LEGENDARY DROP in 3:12"), so players plan around them and the whole server rushes — the best recurring moment in the game.
- First to sit on the altar's challenge seat + one rival = beam clash for the fighter. Bot fills after 3–5 s.
- Tier gating stays (power required for higher altars), with Bronze capped so newcomers are safe.

### 5.2 The Beam Clash (the heart)

**Timeline (13 s):**
1. **Lock-in (1.5 s):** both players snap into facing stances on a clash platform; the camera swings to a cinematic side view; each player's **lead fighter rises behind them as a giant translucent spirit**; names + power levels slam in ("POWER LEVEL 9,240").
2. **CLASH! (10 s):** both fire beams that meet in the middle in a crackling energy ball. **Every click pushes the ball** toward the rival. The screen frame pulses with each click, `+N` numbers fly from your side, the ball grows as total power grows, the ground cracks under it.
   - **Combo:** steady clicking builds `x2 … x10 COMBO` with rising pitch sounds.
   - **SURGE** (fills from clicks): tap for a 2-second power burst — the beam doubles in width.
   - **ULTIMATE** (from your lead fighter, once per clash): a fighter-specific burst (e.g. fire dragon, lightning, black flash) that's a big swing — timing it is skill.
   - **Comeback:** the player behind gets slightly more push per click (rubber band, capped), so most clashes are close until the end. Close clashes = near-miss = rematches.
3. **K.O. (1.5 s):** the winning beam overwhelms, the ball explodes onto the loser (ragdoll flop, comedic), slow-motion 0.3 s, "VICTORY!" word art, the prize fighter flies in an arc to the winner's plot with a comet trail.
- Spectators within range see the whole thing above the stage; crowd cheer sounds scale with how close it is.
- Fairness: server-authoritative clicks, cap 14 CPS (autoclickers gain nothing), bots fill seats.

### 5.3 Team & power
- Equip **3 fighters** (more slots via rebirth/pass). Team power = sum of their rarity power × mutation; it sets click power, your **beam colour** and **spirit**. Lead fighter's ultimate is your ultimate.
- This makes every collection decision interesting: income on the plot vs. power in the team (a fighter can do both — equipped fighters still earn).

### 5.4 Raids (the drama engine)
- Other players' plots are walkable. Each fighter on a pedestal has a **CHALLENGE** prompt.
- Challenging starts a **raid**: alarm + red screen edge for the owner, "RAID AT YOUR PLOT!" with a big arrow and a 10 s timer to get back (a **Return** button teleports them — no unfair distance).
- Owner arrives → beam clash for that fighter. Owner doesn't arrive → a **defender bot** uses the owner's team power at 80%. Raider wins → fighter stolen. Defender wins → raider pays a stake (cash) to the defender.
- **Protections (so it's fun, not miserable):**
  - **Shield:** after being raided (win or lose) your plot is shielded for 3 min. Plus a free manual shield with a cooldown, and a longer shield pass.
  - **Favorite lock:** your single best fighter can be locked and can never be stolen.
  - **Raid only up:** you can't raid players whose power is far below yours (no bullying beginners); you *can* raid up for bonus rewards.
  - **Only in-session:** your plot exists only while you're in the server. Leaving never costs you anything.
  - **Revenge:** a raider is marked for 60 s; beating them returns your fighter plus a bonus.

### 5.5 Plot (your base)
- A themed courtyard with a torii gate, nameplate, podiums in rows, and your **Champion Podium** (best fighter, giant, visible from the plaza).
- Fighters on podiums **visibly earn**: a `+$1.2K` pops above each one every second, coins fly to your **Cash Shrine**; stepping on it collects with a coin fountain and a counter tick-up. Visible income is a constant small dopamine hit and makes plots look alive.
- Plot upgrades: more podiums, income multiplier, defence (shield length), decorations (status).

### 5.6 Server events (the clip machine)
Scheduled every ~10 minutes plus random ones, each lasting 2–4 minutes, announced with a sky change, music change and banner:
- **Blood Moon** — red sky; Mythic/Secret drop chance ×5.
- **Titan Invasion** (co-op boss) — the Attack Titan, *30× scale*, climbs over the island's edge. Everyone clicks together to push it back (a server-wide beam clash vs. the boss); everyone who contributed gets a reward chest; MVP gets a Titan shard. Huge, cooperative, perfect for beginners and clips.
- **Power Hour** — double clash rewards.
- **Golden Rain** — all drops roll Golden or better.
- **Admin events** on update day (the developer joins and triggers chaos: everyone gets a free Legendary drop, gravity events) — proven CCU and clip driver.

### 5.7 Progression
- **Cash** → upgrades (click power, walk speed, podiums, shrine multiplier).
- **Rebirth (Ascend)** → resets cash + upgrades, keeps fighters; gives a permanent multiplier, a new **aura colour around your avatar** (status everyone sees), +1 team slot every few rebirths, unlocks the next altar tier.
- **Index** by series (Naruto page, DBZ page…) with silhouettes, page rewards and permanent bonuses; "Index 87/148" on your nameplate.
- **Titles** from achievements shown above your head ("Titan Slayer", "Raid King", "1,000 Clashes").
- **Leaderboards** in the plaza (weekly resets): most clash wins, most raids, richest, highest power.

### 5.8 Return hooks
- **Restock** — the Fighter Shop (buy specific common/rare fighters with cash) restocks every 5 min with a timer.
- **Offline earnings** — plots earn while you're away (capped at 2 h, so returning sooner matters).
- **Daily login streak**, three daily quests, playtime gifts (5/15/30/60 min).
- **Update Saturday** — lobby countdown board to the next update with a teaser of the next fighter.
- **Codes** — announced in the group/socials; give luck boosts and cash.
- **Group + like rewards** — join the Roblox group for +10% luck; "50K likes = new code" goal board in the plaza.

---

## 6. The first 5 minutes (scripted)

| Time | What happens | Feeling |
|---|---|---|
| 0:00 | Spawn on a cliff overlooking the island at golden hour; portal humming in the sky; a clash already happening on the stage below | "Whoa" |
| 0:03 | Giant arrow + text "A fighter is dropping! RUN!" countdown 0:08 | Urgency |
| 0:11 | Beam slams onto the Bronze altar; a Rare spins up in blue aura | Awe |
| 0:15 | Sit → first clash vs. a tuned-easy bot; on-screen hand: "TAP FAST!" | Instant action |
| 0:27 | VICTORY, slow-mo, fighter flies to your plot; "+1 FIGHTER, +$45/s" | First win |
| 0:35 | Arrow to plot; fighter on podium; coins already popping; step on shrine: coin fountain | Ownership |
| 1:00 | "Equip your fighter!" → it appears as your spirit; power number jumps | Power |
| 1:30 | Upgrade stall glowing "!": buy Click Power 2 | Progress |
| 2:30 | Banner: "LEGENDARY DROP in 1:00" — the whole server starts gathering | Anticipation |
| 3:30 | Legendary drop chaos; you probably lose to a veteran — but you get consolation cash + see what you're aiming for | Desire |
| 4:00 | Daily quest bar: "Win 3 clashes (1/3)"; Index: "1/148 — collect the Naruto page for a reward" | Goals |
| 5:00 | Server event: Titan Invasion — everyone together; reward chest | Belonging, spectacle |

Rule: **something rewarding every 10–20 seconds for the first 5 minutes.**

---

## 7. Visual bible

### 7.1 The world: "Sky Dojo Island"
A floating island above a sea of clouds, at permanent golden hour, built in **studded Roblox style but dense and composed**:
- **Centre:** the **Clash Colosseum** — a round studded stone stage with tiered crowd stands, banners, lanterns and a ring of glowing rune tiles. All clashes happen on 4 clash platforms around it, plus the main stage for Legendary+ and events.
- **Sky:** the **Summoning Portal**, a giant rotating ring of studded gold blocks with a neon core, always visible.
- **Plaza ring:** 6 Drop Altars (stepped studded pyramids, tier-coloured, with braziers).
- **Plots:** 8 courtyards around the outer ring, each behind a red torii gate, with stone paths, pink blossom trees and lanterns. Island edges have waterfalls pouring into the clouds.
- **Hub:** a studded market street (shop stalls with striped awnings, paper lanterns overhead) between spawn and the colosseum.
- **Density rule:** no empty floor bigger than a plot; every walk passes props, trees, lights or other players.
- **Silhouette rule:** portal, colosseum, altars and champion podiums are the tallest things — the eye always lands on what matters.

### 7.2 Lighting & colour (Roblox settings to start from)
- `Lighting.Technology = ShadowMap` (good shadows, phone-safe), `ClockTime ≈ 16.8` (golden hour), `Brightness 3`, warm `OutdoorAmbient`.
- `Atmosphere`: Density 0.32, Haze 1.6, warm Color, cool Decay — soft distance fog that hides draw distance and adds depth.
- `Bloom`: Intensity 0.7, Size 28, Threshold 1.1 — neon and auras glow.
- `ColorCorrection`: Saturation +0.18, Contrast +0.08, slight warm TintColor.
- `SunRays`: Intensity 0.06.
- Custom anime skybox (painted clouds, big moon visible in the day) — one image set, huge payoff.
- Events recolour the sky (Blood Moon red, Golden Rain gold) by tweening these values.

### 7.3 Palette
Warm stone + saturated accents. Each colour means one thing:
red = stage/clash, gold = money/legendary, cyan = power/diamond, purple = epic/rebirth, green = confirm/income, pink = blossoms/decor. Rarity colours never appear on decor.

### 7.4 Fighters
- **Drops:** 2.5× scale, landing pose → idle power-up loop (aura, slow bob, hair-wind particles).
- **Plot:** 1.5× on podiums, champion 3×.
- **Rarity look:** Common none · Uncommon soft glow · Rare blue ring + sparkles · Epic purple flames · Legendary gold pillar of light + floating rocks · Mythic red-black lightning + ground cracks · Secret rainbow aura + its own music.
- **Mutations:** Golden (gold metal material on accessories + shimmer), Diamond (glass-cyan + sparkle), Rainbow (cycling hue Highlight), Huge (2× + "HUGE" crown tag).
- **Nameplate:** one clean card (name, rarity ribbon, $/s, odds) only within 40 studs, fading; no stacking text walls.

### 7.5 VFX (the "juice")
- Click: `+N` numbers with arc, scale pop, tiny screen kick; combo text escalating size/colour.
- Beams: two textured Beams with scrolling texture + glow, the collision ball (neon sphere + particles + light), ground crack decals, sparks along the beam.
- K.O.: white flash frame, 0.3 s slow-mo (time-scaled effects), explosion, confetti for winner.
- Drops: portal spin-up, sky tint, beam pillar, shockwave ring, dust, rarity word art.
- Money: coins flying to the shrine, number tick-ups, "+$" floaters over podiums.
- Reduced Motion / Reduced Flashes settings tone all of this down.

### 7.6 UI
- **Glossy chunky toy UI** (the genre standard): thick dark outlines, gradient fills, inner highlight, drop shadow; Luckiest Guy / Fredoka for all numbers and buttons.
- **Layout:** left column of big icon buttons (Shop, Index, Team, Rebirth, Quests) with red "!" badges; top-centre event banner + drop countdown; bottom-left cash with tick-up; bottom-right team portraits with power; right column of active boosts.
- **Everything animates:** buttons squash on press, panels bounce in, rewards spin in on sunbursts, numbers count up.
- Portraits = live ViewportFrames of the actual fighters.
- Made with the existing creature-lab UI pipeline (generated 9-slice kit, Blender toon-rendered icons, word art).

### 7.7 Camera & audio
- Cinematic camera cuts only for clashes, big drops and events; never steal the camera during free movement.
- Music: upbeat anime-style loop in the plaza, intense track during clashes/events, calm koto loop on plots.
- SFX: every action has one; rarity stingers escalate; crowd reacts to clash closeness. Licensed from the Roblox library.

---

## 8. Monetization (fair-PvP version)

Rule: **Robux can make you richer, faster, luckier, safer or prettier — never directly win a clash.**

| Item | Type | Price | Why players buy |
|---|---|---:|---|
| VIP | pass | 199 | Gold name, VIP lounge with its own altar, +25% income |
| 2× Cash | pass | 249 | Speed |
| +2 Team Slots | pass | 299 | Bigger team (capped so it's not dominant: slot power ×0.5) |
| Extra Podiums | pass | 149 | Show more |
| Auto Collect | pass | 99 | Convenience |
| Lucky | pass | 249 | +30% better drop rarity on altars you claim |
| Long Shield | pass | 149 | Peace of mind vs raids |
| Server Luck 15 min | product | 99 | Everyone benefits, buyer is announced (generous + status) |
| Summon Legendary Drop | product | 199 | Forces a Legendary drop — announced, whole server rushes (buyer still has to win it) |
| Cash / Gem packs | product | 25–799 | Scaled to progress |

No Robux for random fighter rolls; no paid power in clashes beyond the capped slot pass.

---

## 9. Virality & growth

- **Thumbnail/icon:** one giant fighter (top rarity, glowing) + two beams colliding + a scared Roblox avatar; huge "ANIME CLASH" word art. Test 3 icons with Roblox's thumbnail testing. The image must read at phone size.
- **Clip-able moments by design:** Secret drops, Titan Invasion, steal-back revenge, close clashes. Each is loud, colourful and over in under 15 seconds, the length of a Short.
- **Codes:** every update + like milestones; posted in the group and on socials.
- **TikTok/Shorts plan:** daily 15-second clips from our own gameplay (Secret drops, 1-click clash wins, raid fails). This is where the ₹20,000 goes first — small creators, not ads.
- **Update cadence:** every Saturday. New fighters (from the pack's unused forms first), a new event, a new code. Lobby countdown board.
- **Social features feeding discovery:** friend boost (+10% per friend), "Join friend's raid party", group join reward, like goal board.

---

## 10. What Roblox's recommendations reward (targets)

Roblox has said its discovery systems favour engagement (playtime), retention and monetization quality. Rules of thumb for a game the algorithm pushes (aim, not promise):

| Metric | Target |
|---|---|
| Day-1 retention | 30%+ |
| Day-7 retention | 10%+ |
| Average session | 20+ minutes |
| First-session completion of first clash | 90%+ |
| Payer conversion | 2–4% |

Built-in analytics: funnel (join → first clash → first win → equip → first upgrade → second session), clash closeness, raid outcomes, event participation, drop → claim rate.

---

## 11. Content

- **Launch:** all 148 fighters across 7 rarities + mutations, 4 events, Titan Invasion boss, 6 altars, 8 plots.
- **Ultimates:** grouped by series and rarity (e.g. all Naruto Legendaries share a "Rasengan" burst with colour variants) — ~12 ultimate effects cover the roster.
- **Weekly updates:** new event, 4–6 forms/variants, new title set, a code. Bigger monthly: new island area or boss.

---

## 12. Lines we don't cross

Most players are children. These protect them, protect the game from Roblox policy and refunds, and keep parents on our side:
- No Robux spent on random outcomes; all drop odds shown in-game.
- No fake near-misses, fake countdowns, fake scarcity or fake "players online" numbers.
- Raids never cost anything while you're offline; favorite lock and shields always exist.
- No punishing absence (offline earnings only add).
- Clear prices, no auto-prompting purchases, no "you'll lose this if you don't buy" pressure.

The game can be extremely compelling without any of these.

---

## 13. Roadmap (revised)

The scope is bigger than the old 3-week plan. Honest estimate: **5–6 weeks to a polished public launch**, then weekly updates.

| Phase | Weeks | Deliverable |
|---|---|---|
| **1. Vertical slice** | 1–2 | One altar + the colosseum + one plot, fully art-directed: lighting, sky, portal drop, beam clash with spirits/combo/surge/K.O., UI kit, sounds. **Playtest with 10+ kids. If the clash isn't fun, fix it before anything else.** |
| **2. Full loop** | 3–4 | All altars and tiers, team & ultimates, plots with visible income, raids with protections, rebirth, Index, quests, saving, shop |
| **3. Spectacle & social** | 5 | Server events + Titan Invasion, announcements, leaderboards, titles, codes, group/like rewards, friend boost |
| **4. Launch prep** | 6 | Monetization, performance pass on phones, exploit pass, icon/thumbnail tests, private beta (20+ players), fix |
| **Live** | weekly | Saturday updates, admin events, clips, codes |

**Kept from day 1:** the fighter pipeline (all 148 clean models), joint-based posing, odds/tiers/mutations, Config, project setup.
**Rebuilt:** the world, all presentation, the battle (now beam clash), UI.

---

## 14. Decisions needed
1. **Raids:** in (recommended — it's the drama engine) or tables only?
2. **Team & ultimates:** in (recommended — gives collecting a purpose)?
3. **Island theme:** Sky Dojo Island as described, or another setting?
4. **Timeline:** accept 5–6 weeks to launch for this scope?
