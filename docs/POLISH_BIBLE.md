# Anime Clash — the polish bible

What the finished game looks, sounds and feels like, moment by moment, and the bar each part must clear before it ships. HIT_PLAN.md says *what* the game is; this says *how good* every piece of it must be, and how it makes money.

A note on honesty: nobody has an exact recipe for a viral hit — timing and luck matter. But the games that break out share a production standard that is very consistent, and almost every failed game misses it in the same places. This document is that standard, applied to our mechanics: portal drops → beam clash → team → plot → raids → events.

---

## Part 1 — The quality bar

Every feature passes these five tests before it counts as done.

| Test | How | Pass when |
|---|---|---|
| **3-second test** | Show a stranger a 3-second clip or one screenshot | They can say what's happening and what's valuable |
| **Mute test** | Play with sound off | Every action still has visible feedback (motion, numbers, flashes) |
| **Sound-only test** | Play with eyes closed | You can hear wins, losses, rare drops, money and danger apart |
| **Phone test** | Real phone, thumb only, 5-inch screen | Every button reachable, every number readable, 50+ FPS on a mid phone |
| **Kid test** | Watch a 9–13-year-old play without help | They grin or shout within 60 s and ask to keep playing |

Plus three rules for everything on screen:
1. **One thing is the hero.** Every moment has a single focus (the drop, the beam ball, the reward). Everything else gets quieter.
2. **Every action answers within 100 ms** with motion, sound and a number.
3. **Bigger reward = bigger moment.** Commons are quick and quiet; Secrets stop the whole server. The ladder must be obvious.

---

## Part 2 — The core loop, polished moment by moment

Our loop: **drop → rush → clash → reward → plot → upgrade → raid/event → repeat.** For each moment: what the player sees, hears and feels, with exact timings.

### 2.1 The drop (anticipation → awe)

| t | Visual | Audio | Camera / UI |
|---|---|---|---|
| −10 s | Portal ring spins faster; core shifts toward the next drop's *tier colour* (not rarity — keep the surprise) | Low rising hum | Top-centre timer turns yellow, pulses each second |
| −3 s | Portal shoots sparks; the target altar's braziers flare | Drumroll, 3-2-1 ticks | Arrow over the target altar for everyone |
| 0 | Beam slams down, width by rarity; sky briefly tints the rarity colour (Legendary+) | Rarity stinger (7 escalating stingers) | Screen shake by distance; FOV kick +4° |
| +0.15 s | Shockwave ring, dust burst, stud-shards fly | Impact boom | — |
| +0.4 s | Fighter rises from the light in its **Landing** animation (crouch → stand → pose) | Character "power-up" whoosh | Nameplate card flips in (rarity ribbon → name → $/s → odds) |
| +1 s | Aura settles into its idle loop; altar light holds rarity colour | Aura loop sound (Epic+) | Legendary+: server banner + chat system message |

**Rare-drop extras:** Mythic darkens the whole server's sky for 4 s; Secret plays its own 6-s music sting for everyone and leaves a lingering rainbow pillar until claimed.

### 2.2 The rush and seat (urgency)
- Clash pads glow and **pulse in the tier colour** while free; a seated player's pad turns their colour.
- Sitting: avatar snaps onto the pad with a quick "lock-in" spin + click sound; a "WAITING FOR RIVAL" ribbon with a 3-2-1 bot timer.
- If two players hit the same pad within 100 ms, the server picks one; the other bounces back with a comic "boing" — never a silent failure.

### 2.3 The beam clash (the hero moment — 13 s)
Shots are cinematic but readable:
1. **Lock-in (1.5 s)** — camera cuts to a low side angle; both players slam into stance (R15 *ClashStance* animation); each team's lead fighter rises behind its player as a **giant translucent spirit** (fighter clone, 3× scale, ForceField material, rarity-coloured Highlight). Power numbers count up under each name with a ticking sound. "VS" splash.
2. **CLASH! (10 s)** — both fire. Beams are textured `Beam`s with a scrolling energy texture, a bright core and a wider soft glow; they meet in a **collision ball** (neon sphere + flipbook lightning + sparks + light). Every click:
   - pushes the ball (server-authoritative position, client-smoothed),
   - pops a `+N` from the player's hand, arcing and fading in 400 ms,
   - kicks the camera 2 px and nudges FOV,
   - plays a click "zap" whose pitch climbs with combo.
   - **Combo** text (x2…x10) grows and changes colour each tier; at x10 the beam turns white-hot.
   - **SURGE** button fills along the bottom; pressing it doubles the beam's width for 2 s with a roar.
   - **ULTIMATE** (lead fighter's) — a 1.5-s cut-in: the fighter's portrait slides across the screen on a speed-line banner (classic anime cut-in), then the move fires (fire dragon, lightning spear, black flash…).
   - The ground under the ball cracks progressively; crowd stands react (cheer volume follows how close it is).
3. **K.O. (1.5 s)** — losing beam collapses; ball explodes onto the loser; **0.3 s slow-motion** + white frame; loser ragdoll-flops (comedic); "VICTORY!" or "DEFEATED" word art; prize fighter launches toward the winner's plot on a comet trail visible across the map.
- Close finishes (<10% gap) add "SO CLOSE!" for the loser and a **REMATCH** button (2 s window).

### 2.4 The reward (dopamine peak)
Full-screen reward card on a spinning sunburst: fighter portrait (live 3D viewport doing its *Victory* clip), rarity ribbon, mutation badge, "+$X/s", "NEW!" sticker if first time (Index), confetti for Rare+. Tap to continue — or it auto-closes in 3 s so it never blocks play. Index count ticks up in the corner ("Index 23 → 24/148").

### 2.5 The plot (ownership)
- Fighter lands on the next free podium with a dust puff and stands in its idle clip.
- Every second each podium pops "+$1.2K" (floating, fading); coins stream to the Cash Shrine.
- Shrine collect: step on it → coin fountain, cash counter ticks up over 0.8 s (with accelerating tick sound), "+$48.2K" big pop. Never just set the number.
- Champion podium fighter is 3× with a spotlight; visitors see your plot's total "$/s" on the torii.

### 2.6 Upgrade (progress)
Upgrade stall glows "!" when something is affordable. Buying: button squash, stat line flies to the HUD, number rolls to the new value, sparkle on the avatar, short level-up chime. The next price is always visible, with a progress bar of cash toward it.

### 2.7 Raid (danger and drama)
- Challenging a podium: target fighter glows red, a siren rises, the owner's screen gets red edges + "RAID! 10s" + a big **DEFEND** button that teleports them home.
- The clash plays as 2.3 but with a red/black colour grade and drum-heavy music.
- Stolen fighter: it's yanked off the podium on a chain-beam into the raider's hand → flies to their plot. Loser sees "REVENGE (60s)" with the raider highlighted through walls.

### 2.8 Server events (the clip machine)
Each event has: a sky grade, a music swap, a banner with icon, a timer, and an end card. Titan Invasion: the Attack Titan (30×, slow lumbering *TitanClimb* animation) grips the island edge; the whole server's beams merge into one giant beam (every player's click counts); health bar across the top; MVP podium at the end.

---

## Part 3 — Art production

### 3.1 Style guide (studs as accents)
- **Shapes:** chunky and exaggerated (1.3–1.5× real proportions), soft bevels on every mesh edge (bevel ≈ 6% of the smallest dimension), no thin parts under 0.4 studs.
- **Surfaces:** smooth stylized materials with **painted vertical gradients** (darker at the base, lighter at the top) baked into textures. Studs only on: colosseum stage, paths, altar tops, plot floors, clash pads.
- **Palette:** HIT_PLAN §7.3. Saturation high, values separated (dark bases, light tops) so things read on phones.
- **Lighting:** golden hour; strong warm key, cool fill from the sky, rim from the portal.
- **Outline feel:** no real outlines in Roblox, so silhouettes come from value contrast and a thin darker band at mesh edges in textures.

### 3.2 Asset list (what has to be made)

| Group | Items | Source |
|---|---|---|
| Hero meshes | Portal ring + core, colosseum stage + stands, 4 altar tiers, clash pads, champion podium, cash shrine, torii (plot + spawn), bridge | Blender (beveled, gradient textures), uploaded via the creature-lab pipeline |
| Nature kit | 3 blossom trees, 2 pines, 4 rocks, grass tufts, flowers, bushes, waterfall mesh + foam | CC0 Quaternius stylized kits recoloured with `kitbash.py` |
| Props | Lanterns (3), banners, market stalls (3), barrels, crates, signs, fences, stone lamps | Blender + kits |
| Sky & clouds | Painted anime skybox (6 faces), cloud-sea meshes (5 variants), distant islands | Blender render → upload |
| Fighters | 148 R15 conversions + **12 animation clips** (Idle, Landing, ClashStance, Fire, Surge, Ultimate, Victory, Defeat/Flop, PowerUp, Wave, PlotIdle, TitanClimb for the boss) | FighterRig + Blender R15 rig → clips as code |
| VFX textures | Aura flipbooks (7 rarities), beam textures (3), lightning flipbook, shockwave ring, sparks, coins, confetti, ground crack decals, speed lines | `fx.py` (exists) + Blender renders |
| UI | 9-slice kit, ~45 icons, word art (~25), rarity ribbons, badges, portrait frames, sunburst | creature-lab `kit.py`, `icons_blender.py`, `wordart.py` |
| Store art | Icon, 3–5 thumbnails, pass/product thumbnails | Rendered scenes + word art |

### 3.3 Fighters on screen
- R15 rigs (elbows, knees) with Blender-authored clips played as code, so all 148 share one animation set.
- Per-rarity aura stacks: Uncommon glow; Rare ring + sparkles; Epic flames; Legendary light pillar + floating rocks; Mythic red lightning + ground cracks; Secret rainbow + music.
- Mutations: Golden (gold material on clothes + glints), Diamond (crystal Highlight + sparkle), Rainbow (cycling hue), Huge (2× + crown).

### 3.4 Performance budget (mobile)
- ≤ 25k parts visible at once; hero meshes ≤ 20k triangles each, props ≤ 3k.
- ≤ 8 active particle emitters near the camera at full rate; auras throttle with distance.
- Fighters beyond 120 studs stop animating; beyond 250 swap to a static pose.
- Textures 512–1024; the whole island streams in under 8 s on 4G.

---

## Part 4 — UI

### 4.1 Language
Glossy toy UI: thick dark outline, gradient fill, white inner highlight, soft drop shadow. Numbers and buttons in **Luckiest Guy / Fredoka One**, small text in **Builder Sans**. Colour means one thing (green = go/money, gold = currency, red = danger/close, purple = rebirth, cyan = power).

### 4.2 Screen map

| Screen | Contents | Behaviour |
|---|---|---|
| **HUD** | Top: drop timer, event banner. Left: Shop, Index, Team, Rebirth, Quests (with "!" badges). Bottom-left: cash (ticking), gems, $/s. Bottom-right: team portraits + power. Right: active boosts. | Hides during clashes and cutscenes |
| **Clash** | Names, power, spirits, push bar (ball position), combo, Surge, Ultimate, timer | Full-screen tap area; nothing else |
| **Reward card** | Portrait, rarity, mutation, $/s, NEW! | Auto-close 3 s |
| **Team** | 3 slots + roster grid with power and ultimate preview | Drag or tap to equip |
| **Index** | Series pages, silhouettes, page rewards, completion % | Pages slide; completion fanfare |
| **Shop** | Featured, Passes, Gems, Boosts, Starter Pack | Real regional prices, owned states |
| **Rebirth** | What you keep / reset, the new multiplier and aura preview | Two-step confirm |
| **Quests & Daily** | 3 quests, 7-day calendar, playtime gifts | Claim buttons bounce |
| **Clash Pass** | Free and premium tracks, tier rewards | Scroll; claim all |
| **Settings** | Music, SFX, reduced motion/flashes, graphics quality | — |

### 4.3 Motion rules
Panels: scale 0.8 → 1.05 → 1 in 220 ms (back-out). Buttons: squash to 0.92 on press, spring back. Numbers: always roll, never jump. Rewards: arrive on a sunburst. Notifications: slide in from the top, max 2 at a time, priority-sorted.

---

## Part 5 — Audio

- **Music (5 loops):** Plaza (upbeat anime-pop, 120 bpm), Clash (intense, 150 bpm, layers in as the clash gets closer), Plot (calm koto/lo-fi), Event (taiko war drums), Titan (epic choir). Crossfade 1 s, duck under stingers.
- **SFX (~60):** click zaps (pitch by combo), beam loop, ball crackle, surge roar, 12 ultimate sounds, K.O. explosion, victory fanfare, defeat "womp", 7 rarity stingers, drop impact, coin ticks and fountain, upgrade chime, UI taps, raid siren, crowd cheer layers, portal hum, ambient birds/wind/waterfall.
- Sources: Roblox audio library (licensed, free) first; anything missing commissioned or made with licensed tools. Every sound normalised; no sound louder than the rarity stingers.

---

## Part 6 — The psychology, applied (reward schedule)

When the player gets something, by session time. The rule: **the gap between rewards grows slowly, and the size of rewards grows faster.**

| Session time | Reward rhythm |
|---|---|
| 0–1 min | Win in 15 s, fighter on plot, coins popping, first upgrade affordable |
| 1–5 min | Something every 10–20 s: clash, collect, upgrade, quest tick, Index entry |
| 5–15 min | First Rare+, first team equip with spirit, first event, first raid seen |
| 15–30 min | First Legendary chance, first rebirth goal visible, daily quest done, playtime gift |
| Day 1 → 2 | Login streak day 2, offline earnings waiting, "your Epic is waiting on the Index" |
| Day 3–7 | Streak day 7 big chest, weekly leaderboard reset, Saturday update with new fighters |
| Week 2+ | Season (Clash Pass) progression, rebirth auras, rare-hunt for Mythics, raid rivalries |

Hooks we use (and the honest version of each):
- **Variable reward** — rarity + mutation on every drop (odds shown).
- **Near-miss** — real, close clashes + rematch (never faked).
- **Loss aversion** — raids with shields/locks so it's thrilling, not punishing.
- **Status** — plot, aura, titles, leaderboards visible to everyone.
- **Completion** — Index pages with rewards.
- **Appointment** — drop timer, events schedule, Saturday updates, daily streak.
- **Social** — server announcements, crowds, friend boosts, revenge.

---

## Part 7 — Monetization (complete)

Principles: **sell speed, convenience, protection, luck and status — never a guaranteed clash win.** Every purchase must feel good the next minute, and the free player must still have a great time (they're the crowd that makes paying players' moments matter).

### 7.1 Currencies
- **Cash** (soft) — from plots and clashes; upgrades, podiums, rebirths.
- **Gems** (premium, also earnable slowly from quests, Index and the free pass track) — boosts, cosmetics, pass tier skips, shield refreshes.

### 7.2 Game passes (permanent)

| Pass | Robux | What it does | Why it sells |
|---|---:|---|---|
| **VIP** | 299 | Gold nametag, VIP lounge altar (drops only VIP can clash for), +20% income, chat tag | Status + exclusive drops |
| **2× Cash** | 349 | Double plot income | Classic best-seller |
| **Lucky Gloves** | 399 | +35% drop luck on altars you claim, gold glove VFX | Luck + visible flex |
| **+1 Team Slot** | 249 | 4th team slot (slot power ×0.5 so it's not dominant) | Power fantasy, capped |
| **Auto Collect** | 149 | Shrine cash collects itself | Convenience |
| **Super Shield** | 199 | Shields last 3× longer, free shield every 10 min | Protection |
| **Extra Podiums** | 199 | +8 podiums | Show more |
| **Fast Run** | 99 | +20% run speed (helps the rush, not the clash) | Cheap first purchase |

### 7.3 Developer products (repeatable)

| Product | Robux | Effect |
|---|---:|---|
| **Starter Pack** (one-time, first 3 days, real timer) | 99 | Epic fighter + 2× cash 30 min + 500 gems (≈80% better value; shown once, then in the shop) |
| Gem packs | 49 / 149 / 399 / 999 / 2,499 | Gems (bonus % grows with size; "Best value" tag on 999) |
| **Server Luck 15 min** | 99 / 249 (×2/×4) | Everyone's drops luckier; buyer's name in a gold banner |
| **Summon Legendary Drop** | 299 | Forces a Legendary drop now; whole server rushes; the buyer gets a 3-s head start |
| **Shield Now** | 25 | Instant shield (gems or Robux) |
| **Cash boosts** | 39–299 | Cash scaled to progress |
| **Clash Pass premium** | 399 per season | Premium track (cosmetics, gems, an exclusive fighter skin, pass XP boost) |
| **Clash Pass +10 tiers** | 199 | Tier skip |

### 7.4 Subscriptions and other revenue
- **Clash Club** (Roblox experience subscription, monthly): daily gem drop, +10% luck, exclusive monthly aura, a members-only daily Legendary drop event. Recurring revenue from the most engaged players.
- **Private servers** (paid, e.g. 100 Robux/month): for friend groups and creators recording content.
- **Premium Payouts**: Roblox pays creators for Premium subscribers' time in the game — give Premium members a small perk (+5% luck, Premium badge) to encourage longer sessions.
- **Rewarded video ads** (only where Roblox allows them, for eligible users): "watch to double this reward" on the reward card. Optional, never forced.

### 7.5 Where offers appear (contextual, never pushy)
- After a **close loss**: small card "Lucky Gloves +35% luck" (once per session max).
- After being **raided**: "Super Shield" card.
- When the **plot is full**: "Extra Podiums".
- On the **reward card** of a Legendary+: "Show it off — Gold podium frame" (cosmetic).
- **Never**: auto-prompting a purchase, interrupting a clash, fake discounts, fake timers, "you'll lose this unless you pay".
- Use Roblox's price-testing tools to test prices once the game has traffic; regional pricing is automatic.

### 7.6 Targets (to measure, not promises)
Payer conversion 2–4%, ARPDAU growing toward $0.05–0.10, first purchase within 3 sessions for payers, Starter Pack as the most-bought first purchase.

---

## Part 8 — Virality and growth (built into the game)

- **Clip moments by design**: Secret drops, 1-click clash wins, Titan Invasion, raid steals. Each is under 15 s, loud and colourful.
- **Screenshot/share prompts** at peak moments (Secret pull, Titan MVP) using Roblox's capture-sharing feature — one tap, optional.
- **Invites**: after a win, "Invite a friend: +10% luck while they play" (friend boost); invite rewards when an invited friend reaches their first rebirth.
- **Codes**: in-game code box; new codes every update and at like milestones (posted in the group + socials).
- **Group + notifications**: join-group reward; opt-in experience notifications for events and updates ("Blood Moon in 10 min").
- **Experience Events** for every Saturday update (players tap "Notify me").
- **Thumbnail/icon tests** with Roblox's experiments; 3 variants each, keep the winner.
- **Creators**: give small TikTok/YouTube creators codes and early access; spend the first part of the ₹20,000 budget here, not on ads.
- **Update cadence**: every Saturday, same time, countdown board in the plaza with a teaser of the next fighter.

---

## Part 9 — Live ops calendar

| Cadence | What ships |
|---|---|
| Daily | Rotating daily quests, login streak, 2 scheduled big drops at peak hours |
| Hourly | One server event (Blood Moon / Golden Rain / Power Hour / Titan Invasion rotation) |
| Weekly (Sat) | 4–6 new fighters or forms, a new code, a balance pass, an admin event |
| Monthly | New season (Clash Pass), new event type, a new island area or boss |
| Holidays | Themed events (Halloween, winter) with limited cosmetic skins that **return** next year |

---

## Part 10 — Build order with polish gates

Each phase ends at a gate: it passes Part 1's tests on a real phone with real kids, or it doesn't move on.

| Phase | Length | Contents | Gate |
|---|---|---|---|
| **A. Fighters alive** | 3–4 days | R15 conversion verified for all 148, Blender R15 rig, 12 clips, auras per rarity | 10 random fighters look right and alive in a screenshot |
| **B. The clash** | 5–6 days | Full beam clash (2.3) with spirits, combo, surge, 4 ultimates, K.O., bots, rematch; sounds | Strangers ask to clash again; mute & sound tests pass |
| **C. Art pass** | 6–8 days | Hero meshes, nature kit, sky, clouds, lighting tune, VFX textures | Screenshot test vs. top-10 games side by side |
| **D. UI + reward flow** | 5 days | Full UI kit, HUD, reward card, team, index, upgrades, numbers that roll | Phone test, 5-min kid test |
| **E. Plot + raids + progression** | 6 days | Visible income, shrine, upgrades, rebirth, raids with shields, saving | 30-min session test: players hit goals at the Part 6 rhythm |
| **F. Events + social** | 4 days | Blood Moon, Golden Rain, Titan Invasion, announcements, leaderboards, codes, invites | One event gets a reaction from every tester |
| **G. Monetization** | 3 days | Passes, products, pass track, subscription, offer placement | Purchases restore, prices regional, no dark patterns |
| **H. Launch prep** | 4 days | Performance, exploits, thumbnails/icon tests, private beta 20+ | Beta funnel: 90% finish first clash, D1 ≥ 30% in beta cohort |

Total ≈ 6–7 weeks of focused work. Phase A is first because everything else stands on fighters that look alive.

---

## Part 11 — What we need beyond code
- **Music**: Roblox library first; commission or license 2–3 signature tracks if budget allows.
- **A painted skybox and key art**: rendered from Blender; the icon may benefit from a paid artist (the single highest-leverage spend).
- **Real playtesters**: 10–20 kids aged 9–14 for gates B, D, E and H.
- **Budget (₹20,000)**: icon/key art first, then creator codes, ads last.
