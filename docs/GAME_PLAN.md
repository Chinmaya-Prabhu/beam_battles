# Anime Clash — full game plan

**Working title:** Anime Clash (rename freely)
**Genre:** PvP click battle + collect-and-display tycoon
**Platform:** Roblox, mobile first (most of this genre's players are on phones), desktop and console supported
**Art style:** fully studded, bright, chunky "classic simulator" look (studded Parts everywhere, thick-outlined glossy UI)
**One-line pitch:** *Anime fighters drop onto tables. Race to the seat, out-click your rival for 10 seconds, and take the fighter home to your plot.*

---

## 0. What makes it work (and different)

Anime Dice and its peers prove the audience: anime characters, rarities, "1 in 400m" odds, a plot full of income-earning models, luck boosts and rebirths. Those games are **luck alone**. Anime Clash keeps everything that audience loves and adds the one thing those games lack: **another player in front of you**.

Four pillars, in priority order:
1. **The clash.** A 10-second duel that's instantly readable, loud and close. Every system serves this moment.
2. **The rush.** A rare drop is announced to the whole server and everyone sprints for two chairs. Musical chairs with stakes.
3. **The plot.** Every win stands on your plot, earning money and showing off. Rare fighters glow so other players notice.
4. **Fair for everyone.** Autoclickers can't win, new players have their own tables, and empty seats never stall.

---

## 1. The loop

**Moment to moment (30 s):**
spawn announced → run to a table → sit → wait for a rival (player or bot) → 3-2-1 → 10 s click battle → winner's fighter flies to their plot → loser gets cash + a comeback boost → next table.

**Session loop (10 min):**
win fighters → they earn cash on your plot → buy click power and plot space → qualify for higher-tier tables → win rarer fighters → fill the Index.

**Long loop (days):**
rebirth for a permanent multiplier → harder tables and Secret fighters → complete Index pages → climb leaderboards → weekly update brings new fighters and an event table.

**First-session targets** (to verify in playtests, not assumptions):

| Moment | Target |
|---|---|
| Spawn to first battle | under 20 s (a starter table is right at spawn, bot fills in 3 s) |
| First win | within the first 2 battles (first battle vs. an easy bot, scripted to be winnable) |
| First fighter on plot + first income | under 60 s |
| First upgrade bought | 2–3 min |
| First Silver table unlocked | 8–12 min |
| First rebirth | ~60–90 min |

---

## 2. World layout (one server, 8 players)

Top-down, one compact studded map so the rush is short and visible:

```
                       ◇ DIAMOND (raised dais)
 [PLOT 1]            ● GOLD    ● GOLD              [PLOT 5]
 [PLOT 2]  ═══  ● SILVER  ● SILVER  ● SILVER  ═══  [PLOT 6]
 [PLOT 3]  ═══ ● BRONZE ● BRONZE ● BRONZE ● BRONZE ═══ [PLOT 7]
 [PLOT 4]                 [ SPAWN + HUB ]           [PLOT 8]
                     Shop · Rebirth · Upgrades
```

- **Arena** (center): 10 tables on a studded stone floor. Bronze ×4 nearest spawn, Silver ×3, Gold ×2, Diamond ×1 on a raised dais with stairs, so a Diamond drop makes everyone run past everything.
- **Hub at spawn**: three physical stalls (Shop, Upgrades, Rebirth) — walking up opens the panel. All are also on the HUD, so nobody has to walk.
- **Plots**: 8 plots, 4 on the west side and 4 on the east side of the arena, each joined to it by a walkway (keeps the south clear for spawn and the hub). Each is a studded baseplate with a nameplate arch, a grid of display pedestals, and a cash collector pad. Visiting other plots is just walking over.
- **Event table**: one extra table appears only during events (weekend, update launch) with special fighters.
- **Spectator ring**: low walls around every table so crowds can gather and watch close battles.

Scale: everything sized so a full rush from spawn to the Diamond table takes ~5 s at base speed, so the rush feels like a race and never a trek.

---

## 3. Tables, spawns and seats

### Table tiers

| Tier | Count | Power to sit | Rarities that spawn | Respawn after claim |
|---|---:|---|---|---:|
| Bronze | 4 | none | Common, Uncommon, Rare | 15 s |
| Silver | 3 | Power 50 | Uncommon → Epic | 20 s |
| Gold | 2 | Power 400 | Rare → Legendary | 30 s |
| Diamond | 1 | Power 3,000 (or 1 rebirth) | Epic → Secret | 45 s |

- **Bronze tables cap click power** to the Bronze level for everyone. A rebirthed veteran sitting there gets no advantage, which keeps new players safe.
- A table shows its locked requirement in red over the chairs if you can't sit there yet ("Power 400 needed"), so the next goal is visible.

### Spawning

- Each table rolls a fighter from its rarity range, then a **mutation** (§5).
- The fighter **drops onto the table** from above with a studded "thunk", dust burst and a rarity-coloured beam into the sky (beams visible across the map for Epic+).
- **Server announcements** for Legendary+: a top-of-screen banner ("LEGENDARY Huge Golden ___ dropped at Gold Table 2!") and a sound. Secret drops shake every player's screen slightly. This is the rush trigger.
- A fighter left unclaimed for 60 s despawns and the table re-rolls (no stale tables).

### Seats

Each table has **two chairs** facing each other across the table (real `Seat` parts, studded).

1. **Claim:** touching a chair seats you (standard Seat). Server checks: tier requirement, not already in a battle, not on cooldown.
2. **Waiting:** a seated player sees "Waiting for rival… bot in 5". If the other chair stays empty for **5 s** (Bronze: 3 s), a **bot** sits.
3. **Lock:** the moment both chairs are filled, the server locks them: jumping out forfeits (counts as a loss, no consolation). Movement is frozen during the battle.
4. **Anti-camping:** you can sit at most 20 s without a battle starting (only possible if bots are disabled for an event); then you're stood up. After a battle, a 2 s seat cooldown stops instant re-sits.
5. **Spectators:** everyone within 30 studs sees the battle UI floating above the table (BillboardGui tug bar), so crowds watch.

---

## 4. The click battle (the heart of the game)

### Timeline (14 s total)
1. **Face-off (2 s):** camera swings to a side view of the table, both avatars and the fighter between them. Names, power and win streaks pop in on each side. "3 · 2 · 1 · CLASH!" in word art.
2. **Battle (10 s):** click/tap anywhere (or press the gamepad button). Each click adds your **click value** to your side.
3. **Finish (2 s):** "WINNER!" word art, the fighter flies off in an arc toward the winner's plot (a beam traces it), confetti on the winner, the loser's avatar does a slump animation.

### What players see
- A big **tug-of-war bar** across the screen: your colour vs. theirs, with the **fighter's portrait** riding the boundary — it physically slides toward whoever is ahead. Far more readable (and more fun to watch) than two numbers.
- Your click count and clicks per second under your side, theirs under theirs.
- Every click: a small `+N` pop, the tap point sparkles, the bar shakes. The tighter the battle, the more the screen pulses.
- **Surge meter** (see below) fills along the bottom.
- Last 3 seconds: timer turns red and ticks loudly.

### The rules (server-authoritative)
- **Click value** = base 1 × click power (from upgrades) × rebirth multiplier × active boosts. Bronze tables clamp click power.
- **Click cap:** the server counts at most **14 clicks per second** per player (rolling window). Anything above is silently ignored. A human tapping fast already reaches 8–12; an autoclicker gains nothing past 14, so macros stop being a win button.
- **Surge:** every click fills the Surge meter; when full (~40 clicks), a big SURGE button lights up. Tap it for **2× click value for 2 s**. One per battle. Adds a decision and a comeback window, rewards timing over raw speed.
- **Ties:** 2-second sudden death.
- **Disconnect / leave:** the remaining player wins.
- **Network:** clients send click *batches* every 0.1 s (`count` 0–3); the server clamps to elapsed time × 14 and ignores packets outside the battle window. Totals and the bar are broadcast from the server 10× per second, so both players and spectators see the same state.

### Rewards
- **Winner:** the fighter goes to their plot (if the plot is full, a quick prompt: replace your weakest, or send it to storage).
- **Loser:** consolation cash = 25% of the fighter's value, plus a **Comeback boost** (+20% click value next battle, stacks up to 3 losses). Losing should never feel like wasted time.
- **Streaks:** consecutive wins show a flame on your nameplate; at 5 streak the server announces you ("X is on a 5 win streak!"), which also makes you a target.

### Bots
- Bots wear random studded avatars and anime-ish names, and are clearly marked with a small "BOT" chip (honesty matters with this audience).
- Each tier has a bot band: a **target CPS** (Bronze 5–7, Silver 7–9, Gold 9–11, Diamond 11–13) and the tier's typical click power, with randomness so they win ~40–50% against a player who's at the tier's level.
- The **first battle in a new player's life** is always against an easy bot (wins are guaranteed to be achievable).
- Bot wins: the fighter vanishes in a puff (it doesn't go anywhere), table re-rolls.

---

## 5. Fighters (characters)

### Registry (one data file drives everything)
`src/shared/Fighters.lua` holds one entry per fighter:

```lua
Naroto = {
    display = "Naroto",          -- what players see
    rarity = "Common",
    baseIncome = 8,              -- cash per second on the plot
    model = "Naroto",            -- name in ReplicatedStorage.Assets.Fighters
    height = 7,                  -- studs; models are normalized to this
    pose = "idle_stance",        -- display animation
    aura = nil,                  -- optional override
    series = "Ninja",            -- Index page grouping
}
```

Swapping any model (e.g. replacing a pack model with an original later) is changing one `model` field. Nothing else in the game references models directly.

### Rarities

| Rarity | Colour | Base income ($/s) | Visual |
|---|---|---:|---|
| Common | grey-white | 5–15 | none |
| Uncommon | green | 20–60 | soft glow |
| Rare | blue | 100–300 | blue aura ring |
| Epic | purple | 600–1.5K | purple aura + sparkles |
| Legendary | gold | 4K–12K | gold beam + particles |
| Mythic | red/black | 40K–120K | flame aura, ground cracks |
| Secret | rainbow | 500K+ | rainbow aura, plays music on plot |

Spawn weights inside each table tier are tuned in `Config.lua` (e.g. Bronze: Common 70 / Uncommon 25 / Rare 5).

### Mutations (rolled at spawn, visible on the table)
| Mutation | Chance | Income | Look |
|---|---:|---:|---|
| Normal | 88% | ×1 | — |
| Golden | 8% | ×2 | gold material + shimmer |
| Diamond | 3% | ×5 | glassy cyan + sparkles |
| Rainbow | 0.9% | ×10 | cycling hue |
| Huge | 0.1% | ×25 | 2× size + "HUGE" tag |

Mutations raise the stakes on common tables: a Rainbow Common is worth fighting for, so low tables stay exciting.

### Launch roster (from the pack in this folder)
The pack (`anime1.rbxm`; `anime2.rbxm` is an identical copy) holds **148 unique fighters across 12 series**, all classic **R6 Roblox avatars** with welded hair/accessory meshes, shirts and pants. The full list with proposed rarities is in [ROSTER.md](ROSTER.md), generated by `tools/pack/inspect_pack.py`.

| Rarity | Count | Examples |
|---|---:|---|
| Common | 11 | Krillin, Rukia, Sasha, Chika |
| Uncommon | 18 | Gon, Killua, Neji, Pre-Timeskip Luffy |
| Rare | 34 | Natsu, Deku, Gaara, Tanjiro, Jolyne |
| Epic | 45 | Goku, Ichigo, Kakashi, Jotaro, Timeskip Luffy |
| Legendary | 26 | Gojo, Sukuna, Aizen, DIO, Itachi, Whitebeard |
| Mythic | 11 | Vegito Blue, Final Aizen, Madara, Saitama, GER, Unsealed Gojo |
| Secret | 3 | Attack Titan, Female Titan (both shown giant-sized), Mugetsu |

- **Forms are the progression.** The pack has base → powered-up chains (Natsu → Natsu Awakened, Ichigo → Hollow Ichigo → Mugetsu, Rock Lee → Gates → 8th Gate, Minato → KCM Minato). Each form is its own fighter one or two rarities higher, which fills the Index naturally and makes "I got the awakened version" a moment.
- **Series are the Index pages** (Naruto, DBZ, Bleach, One Piece, JoJo, MHA, JJK, HxH, YYH, Fate, Fairy Tail, AOT, Other).
- **Bronze tables draw from 63 fighters** (Common–Rare); spawn weights, not pool size, decide how often rarities appear.
- The pack is used **as the whole roster**. Launch with all 148, then add forms and event fighters in weekly updates.

### Display on plots and tables
- Every fighter stands on a **studded pedestal** coloured by rarity, with a BillboardGui nameplate: name, rarity, mutation, "$X/s", and odds ("1 in 400"). This matches what players already know from the genre.
- Idle animation (bob + slow turn if the model isn't rigged).

---

## 6. Plots

- **Pedestals:** start with 8 slots; buy more (up to 40) in rows that build out across the plot.
- **Income:** each fighter earns its $/s into the plot's **collector pad** (a glowing studded pad with a floating cash counter). Step on it to collect, with a coin fountain. (Auto-collect is a pass.)
- **Manage:** walk up to a pedestal → prompt "Move · Sell · Lock". Sell gives 50% of its value. Locked fighters can't be sold by accident.
- **Storage:** extra fighters go to a Backpack/storage list (up to 100) and can be placed later.
- **Showing off:** your best fighter stands on a big central podium at the plot entrance, so passers-by see it. Plot nameplate shows owner, total $/s and rebirth level.
- **Plot upgrades:** pedestal count, collector multiplier (+10% per level), plot theme (cosmetic).

---

## 7. Economy and progression

### Currencies
- **Cash ($)**: from plots, consolation, quests. Spent on everything in-game.
- **Gems**: rare soft currency from Index milestones, daily rewards and quests. Spent on luck boosts and cosmetics (also sold for Robux).

### Upgrades (Upgrades stall)
| Upgrade | Effect | Price curve |
|---|---|---|
| Click Power (Gloves) | +1 click value per level, and the "Power" number that gates tables | ×1.35 per level |
| Walk Speed | faster rush (16 → 28 studs/s) | 10 levels |
| Plot Slots | +4 pedestals | ×2 per row |
| Collector | +10% plot income | ×1.6 per level |
| Luck | +5% better rarity rolls on tables you sit at* | gems |

\* Luck affects what spawns on a table **when you're the first to sit**, never the battle outcome.

### Rebirth
- Requires a cash amount that grows each time.
- Resets cash and click power upgrades; keeps fighters, plot slots, gems and the Index.
- Gives a permanent **×1.5 click and income multiplier** (stacking), a rebirth badge on your nameplate, and unlocks the next table requirement tier faster.

### Index
- Every fighter × mutation is an Index entry, grouped by series pages. Undiscovered ones are dark silhouettes with "???".
- Completing a page or rarity column gives gems and a permanent +2% income.

### Quests and daily
- Three daily quests (win 5 battles, win at a Silver table, use Surge 3 times) → cash and gems.
- Daily login calendar (7 days, day 7 a guaranteed Epic table spawn token).
- Playtime gifts (5, 15, 30, 60 min) for session length.

### Leaderboards
In-world boards at spawn: most wins (all-time), highest win streak (weekly), richest $/s, most Index entries. Weekly resets keep them reachable.

---

## 8. Social features
- **Server announcements** for big drops, big wins and streaks.
- **Spectating** any battle from nearby; spectators' cheers (a tap emote) show as floating icons.
- **Revenge:** after losing to a player, a "Revenge" tag appears over them for 60 s; beating them gives +50% consolation-style bonus cash.
- **Friend boost:** +10% income per friend in the server (max +50%) — a classic invite driver.
- **Trading:** not at launch (scam and moderation overhead). Revisit after the economy is stable.

---

## 9. Monetization (fair-PvP rules)

The rule: **Robux can make you richer, faster, luckier or prettier — never directly win a clash.** Pay-to-win clicks make new players quit, and this game lives on full servers.

### Game passes
| Pass | Price (Robux) | Effect |
|---|---:|---|
| VIP | 149 | VIP chat tag, gold nameplate, +20% plot income, VIP-only Gold table |
| 2× Cash | 199 | doubles plot income |
| Auto Collect | 99 | plot cash goes straight to your wallet |
| Extra Storage | 79 | +100 storage |
| Lucky | 249 | permanent +25% luck on tables you sit at first |
| Fast Walk | 79 | +4 walk speed (helps the rush, not the clash) |

### Developer products
| Product | Price | Effect |
|---|---:|---|
| Cash packs | 25 / 99 / 299 / 799 | cash scaled to your current progress |
| Gems | 49 / 149 / 399 | gems |
| Server Luck (15 min) | 99 | everyone's tables roll better; buyer is announced — social and generous |
| Instant Drop | 149 | forces a Legendary+ spawn on the next free table — and announces it to the server (creates a rush) |
| Skip Rebirth Wait | 49 | — |

Shop UI shows the real regional price from `MarketplaceService`, owned states, and never auto-prompts.

---

## 10. UI — every screen

### Style
- **Glossy, chunky, thick-outlined** like the genre's top games: rounded 9-slice buttons with a bottom shadow lip, navy outlines, saturated fills, white Luckiest Guy text with dark stroke.
- Built with the same kit approach as Elemental Kaijus: `kit.py` draws the 9-slice panels, buttons, bars, pills, ribbons at 4× and downsamples; buttons are drawn white-grey and **tinted in code** (one image, every colour).
- **Icons** rendered in Blender as small toon-shaded 3D objects (`icons_blender.py`: 3-step toon shading, hard glint, navy outline) — the same look as the reference screenshot's Shop/Rebirth/Index buttons.
- **Word art** (`wordart.py`): CLASH!, WINNER!, DEFEAT, PERFECT SURGE, LEGENDARY, NEW!, REBIRTH, etc.
- Layout authored at 1400×800 and UIScaled to the device (same `rescale()` as `UI.lua`), with mobile-safe insets and 48 px minimum touch targets.
- No emoji anywhere (same check script).

### HUD (idle)
- **Top center:** three big nav buttons — **Plot · Arena · Shop** (teleports; Arena returns to the hub).
- **Left column:** **Upgrades · Rebirth · Index · Quests** (big square icon buttons with red "!" badges when something's ready).
- **Bottom left:** cash total (big, green, abbreviated: 824.13T) with $/s underneath; gems below.
- **Bottom center:** **Backpack** (storage) and **Emotes**.
- **Right column:** active boosts (Server Luck timer, Comeback stacks, Friend boost) and a gift icon (playtime rewards).
- **Top right:** settings gear.
- **World UI:** table requirement labels, fighter nameplates, plot nameplates, collector cash counters, leaderboard boards.

### Seat / waiting
- A ribbon above the HUD: "Waiting for rival… Bot joins in 3" with a Leave button.

### Battle screen (replaces the HUD)
- Face-off card: both avatars' headshots, names, power, streak flames, "VS".
- Tug-of-war bar across the top third with the fighter portrait on the boundary.
- Huge tap zone (entire screen) with click pops; on desktop, any mouse button or Space; gamepad A.
- Surge meter + SURGE button bottom center.
- 10 s timer ring.
- Result: WINNER!/DEFEAT word art, reward card (fighter + income, or consolation cash + Comeback), "Back to Arena".

### Panels (one open at a time, modal with darkened backdrop)
- **Upgrades:** rows with icon, current → next value, price button (green if affordable, grey + lock if not), and a progress ring to the next table unlock.
- **Rebirth:** what you keep / what resets (two columns), the multiplier you'll get, a big confirm button with a 2-tap safety.
- **Index:** tabs by rarity, grid of cards; silhouettes for undiscovered; page rewards bar.
- **Backpack/Storage:** card grid of stored fighters with Place / Sell / Lock.
- **Shop:** tabs Passes · Cash · Gems · Boosts; each card has the product thumbnail (built by `store_thumbs.py`), real price, owned state.
- **Quests & Daily:** three quest bars + 7-day calendar.
- **Settings:** music, SFX, reduced motion, reduced flashes, hide other players' announcements, low-graphics mode.

### Toasts and banners
- Top banner for server announcements (rarity-coloured ribbon).
- Bottom toast for personal events (+cash collected, quest complete).

---

## 11. Art direction — fully studded

### World kit (built in code from Parts, so it's light and consistent)
- **Every horizontal top surface uses `SurfaceType.Studs`**, walls get Inlets — the classic Roblox studded look across floor, tables, chairs, plots, stalls and pedestals.
- **Palette:** saturated primaries on a neutral stone/grass base. Arena floor light grey studded stone with a red border; tiers colour-coded (bronze/silver/gold/diamond trims) so table rank reads from across the map.
- **Tables:** chunky round studded tabletops on thick legs, a coloured trim ring by tier, a small rarity light underneath when a fighter is on it.
- **Chairs:** blocky studded thrones in the tier colour, with the seat facing the table.
- **Plots:** studded baseplate per player colour, pedestals as stepped studded blocks, a gate arch with nameplate, cash collector as a green neon-topped pad.
- **Hub stalls:** studded market stalls with striped canopies (Shop red/white, Upgrades blue/white, Rebirth purple/gold) and big floating icon signs.
- **Skybox and lighting:** bright daytime sky, soft atmosphere, mild bloom, slight colour correction for punchy saturation. Future lighting off for mobile performance (ShadowMap).
- **Props:** studded trees, rocks and lamp posts from the existing Blender kitbash route (recoloured CC0 packs) or Part-built, kept low-part.

### Fighters (models)
- The pack's R6 avatars are already in the blocky Roblox style, so they suit the studded world as they are. Each one goes through the pipeline (§13): stripped to body, accessories and clothing; anchored; pivot at the feet; posed; standing on a studded rarity pedestal.
- **Display scale:** 1.5× on tables (so the prize reads from across the arena), 1.2× on plot pedestals, Secret titans at 4×.
- **Poses in code, not animations:** the pack's 1,970 animations are owned by the original game and won't play in ours. Fighters are posed by setting their R6 Motor6D joints from a small pose library (`Poses.lua`: fighting stance, arms crossed, power-up, victory, sword ready) with a gentle code-driven idle bob and breathing. This also means no animation uploads.
- **Rarity look on top of the model:** Epic+ get the aura effects from §VFX attached to the HumanoidRootPart; Mythic/Secret add a ground-crack decal and a light.

### VFX
- Rarity auras (ParticleEmitters + Beams) using the existing fx sheet (sunburst, glow, sparkle, aura ring, hit spark, lightning).
- Click pops, bar shake, Surge lightning across the screen, confetti on win, coin fountain on collect, drop beams on spawn.
- All toned down by Reduced Motion / Reduced Flashes.

### Audio
Click ticks (pitch rises with combo), Surge whoosh, countdown, win fanfare, lose "aww", drop thunk, rarity stingers (bigger per rarity), collector coin rush, upbeat arena loop and a calmer plot loop. Licensed from the Roblox audio library (uploaded/approved sounds) — not the placeholder built-ins.

---

## 12. Technical architecture

Same structure and tooling as the existing projects: **Rojo** (own port), Luau, server-authoritative everything, ProfileStore-style saving.

```
anime-clash/
  default.project.json
  src/
    server/
      Main.server.lua
      Services/
        DataService.lua        -- load/save profile, session locking, migrations
        SpawnService.lua       -- table rolls, mutations, despawn, announcements
        SeatService.lua        -- claims, locks, cooldowns, bots joining
        BattleService.lua      -- battle state machine, click validation, surge, results
        BotService.lua         -- bot avatars, CPS curves
        PlotService.lua        -- plot assignment, pedestals, income tick, collect
        EconomyService.lua     -- upgrades, rebirth, prices, cash/gems
        QuestService.lua       -- daily quests, login calendar, playtime gifts
        IndexService.lua       -- discoveries, page rewards
        PurchaseService.lua    -- passes, products, receipts (idempotent)
        LeaderboardService.lua -- OrderedDataStores, weekly keys
        Telemetry.lua          -- funnel + economy events
    shared/
      Config.lua      -- every number: tiers, weights, caps, prices, timers
      Fighters.lua    -- the registry
      Rarity.lua      -- colours, auras, income bands
      Net.lua         -- one RemoteEvent + RemoteFunction, typed message names
      Format.lua      -- 824.13T style numbers
      UIAssets.lua    -- generated
      StoreIds.lua    -- generated
    client/
      Main.client.lua
      UI.lua          -- kit, buttons, panels (ported from creature-lab)
      Hud.lua
      Battle.lua      -- battle screen, tug bar, click capture, surge
      Arena.lua       -- table labels, drop effects, spectator billboards
      Plot.lua        -- pedestals, collector, manage prompts
      Panels/ (Upgrades, Rebirth, Index, Backpack, Shop, Quests, Settings)
      Fx.lua, Sound.lua, Announce.lua
  tools/   -- copied from creature-lab: ui_art/*, store_thumbs.py, create_store_products.py,
           -- upload_props.py, studio/sanitize_assets.lua, check_no_emoji.py
  tests/   -- Luau test doubles like LuckyShapes (rules, battle, economy, data)
  docs/
```

### Data (per player)
```lua
{
  schema = 1,
  cash = 0, gems = 0,
  power = 1, speed = 0, collector = 0, slots = 8, luck = 0,
  rebirths = 0,
  fighters = { {id = "uuid", key = "Naroto", mutation = "Golden", locked = false, slot = 3}, ... },
  storage = { ... },
  index = { ["Naroto:Golden"] = true },
  stats = { wins = 0, losses = 0, bestStreak = 0, surges = 0 },
  quests = { day = 0, list = {...} },
  login = { day = 0, last = 0 },
  passes = {}, settings = {...},
}
```

### Server rules that protect the game
- Battle outcome, totals and rewards are computed only on the server; clients only send click batches and Surge activation.
- Click batches are rate-limited (14/s rolling) and ignored outside a battle the player is seated in.
- All purchases go through `ProcessReceipt` with a receipt log in the profile (no double grants).
- Plot income is computed from timestamps (no per-second remote spam); collection is server-validated distance to the pad.
- Exploit checks: teleporting to chairs (distance/time check on seat claims), speed hacks (walk speed recalc), remote spam (per-player budget).

### Performance (8 players on phones)
- Fighters on plots: max 40 × 8 = 320 models. Each pack model is checked for part/triangle count; heavy ones get simplified or a lighter LOD for plots far from the camera (`StreamingEnabled` with plots as streaming regions, models set to `ModelStreamingMode.Atomic`).
- Particle budgets per rarity; auras only on Epic+ by default.
- Everything world-side is built once at server start; per-frame work is client-side and only for nearby things.

### Testing
- **Luau unit tests** with service doubles (as in LuckyShapes): spawn weights sum, click cap math, battle state machine (ties, leaves, disconnects), reward math, rebirth, purchase idempotency, data migration.
- **Studio multi-client tests** (Test → 2–4 players): seat races, simultaneous claims, spectator billboards, bot fill.
- **Device emulator** passes on phone/tablet sizes, then a real phone.
- **Balance simulator** (Python, like LuckyShapes): time to first Silver/Gold/rebirth with simulated win rates.

---

## 13. Asset pipeline (reusing what Elemental Kaijus built)

### Fighters from the pack (`anime1.rbxm`)
What's inside each character (measured): an R6 rig (Head, Torso, arms, legs, HumanoidRootPart, Humanoid), welded hair/accessory MeshParts, Shirt/Pants, a face decal — **plus a whole fighting-game move set we don't want**: ~34 Sounds, up to 64 Animations, Trails, ParticleEmitters, hilt/sheath welds, BillboardGui rank tags (`[ SEMI-PRO ]`, `[ CHAMPION ]`), Values, RemoteFunctions and decompiled LocalScripts (201 scripts in total; none match backdoor patterns, but none are needed).

The pipeline works **offline, with no Studio clicking**, because Rojo can read and write models:
1. **`tools/pack/inspect_pack.py`** (done): converts the `.rbxm` to XML with Rojo, lists every rig, scans scripts, writes `docs/ROSTER.md` + `tools/pack/roster.json`.
2. **`tools/pack/strip_pack.py`**: from the XML, keeps per fighter only the R6 body parts, their Motor6Ds, accessory parts and their welds, SpecialMeshes, Shirt, Pants, BodyColors and the face Decal. Deletes every Script/LocalScript/ModuleScript, Sound, Animation/Animator, Trail, Beam, ParticleEmitter, BillboardGui, Value object, RemoteFunction/Event, the second ("Stand"/morph) humanoid and leftover move-set parts (hilts, sheaths, effect parts — anything not welded to the body). Renames each model to its registry key, writes **`assets/models/Fighters.rbxm`** (one folder, ~148 models), and reports part counts before/after.
3. **Rojo maps `Fighters.rbxm`** to `ReplicatedStorage.Assets.Fighters`, so every built place and live sync has them — no Save to File step, no uploads (the meshes and textures are already public asset IDs).
4. **At runtime, `FighterModels.lua`** clones a fighter, anchors it, turns off collision/touch/query, sets the pivot to its feet, scales it for the context (table/plot/Index), applies a pose from `Poses.lua`, and adds rarity effects.
5. **Portraits** for the tug bar, Index and reward cards come from a ViewportFrame of the same model (`UI.modelSlot`, as in creature-lab), so there are no portrait images to make or upload.
6. **`tools/studio/audit_fighters.lua`** (command bar, Play or Edit) spawns every fighter in a grid and lists any with missing meshes/textures, so a removed asset is caught before players see it.

### World kit
Built in code from studded Parts (no uploads), plus a few CC0 kitbash props via `kitbash.py` → `import_props.py` → `upload_props.py` → `load_props.lua`.

### UI art
`kit.py` (panels, buttons) → `icons_blender.py` (icons) → `wordart.py` (word art) → `fx.py` (effects) → `pack.py` (atlases + `UIAssets.lua`) → `upload.py` (only changed images). New icon set for this game: Shop, Upgrades, Rebirth, Index, Quests, Backpack, Plot, Arena, Settings, Cash, Gems, Power, Speed, Luck, Surge, Crown, Flame streak, Bot chip.

### Store
`store_thumbs.py` builds pass/product thumbnails from the icons; `create_store_products.py` creates them and writes `StoreIds.lua`.

---

## 14. IP and safety notes
- **Where the pack came from:** its scripts are headed "Decompiled with the Synapse X Luau decompiler" (an exploit tool), and it contains a fighting game's rank tags and battle scripts. It was ripped from a live anime fighting game. That game's developer is the most likely person to report a copy, more than any anime company.
- **Mitigations:** the move sets, scripts, sounds and animations (the original game's own work) are all stripped (§13); only the avatar look remains. Keep the anime names out of the title, icon, thumbnails and ads. The registry makes any fighter replaceable in minutes if one is reported.
- **Asset dependency:** the models load meshes and textures by the original uploaders' asset IDs (508 meshes, ~360 images). If any of those are moderated, that part disappears; `audit_fighters.lua` catches it.
- If you ever want lower-risk marketing faces, original fighters can be added to the same registry later.

---

## 15. Analytics (what to watch after launch)
- Funnel: join → first sit → first battle → first win → first collect → first upgrade → second session.
- Battle: average CPS distribution (spot autoclickers hugging 14), win rate vs bots by tier, battle completion vs forfeits.
- Economy: time to each table unlock, rebirth timing, cash sinks vs income.
- Social: average players per table rush, spectators per battle, announcements per hour.
- Retention: D1 / D7, session length; monetization: conversion, ARPPU, which products sell.

---

## 16. Build schedule

Honest scope: a **playable, fun MVP in 1 week**; a **complete polished launch in about 3 weeks**.

### Week 1 — playable core
| Day | Work |
|---|---|
| 1 | Project setup (Rojo, port, tooling copied from creature-lab), Config, Fighters registry, studded arena greybox with 10 tables and chairs |
| 2 | SpawnService + SeatService: drops, tiers, claims, locks, bots joining |
| 3 | BattleService + battle screen: click batches, cap, tug bar, Surge, results, spectator billboards |
| 4 | Fighter pipeline: `strip_pack.py` → `Fighters.rbxm` mapped by Rojo, `FighterModels.lua` + `Poses.lua`; all 148 spawning on tables |
| 5 | Plots: assignment, pedestals, income, collector, manage/sell, storage |
| 6 | Economy: upgrades, table requirements, rebirth, saving (DataService) |
| 7 | Internal playtest with 4–8 people; fix what isn't fun |

### Week 2 — content and UI polish
| Day | Work |
|---|---|
| 8 | UI kit + icons + word art generated and uploaded; HUD rebuilt in the final style |
| 9 | All panels: Upgrades, Rebirth, Index, Backpack, Settings |
| 10 | Mutation visuals (Golden/Diamond/Rainbow/Huge on R6 avatars) + rarity auras + Secret titans at giant scale |
| 11 | World art pass: studded hub stalls, plots, props, lighting, skybox |
| 12 | VFX + audio pass (drops, clicks, Surge, win/lose, collect) |
| 13 | Quests, daily calendar, playtime gifts, leaderboards, announcements |
| 14 | Mobile pass on real devices; performance pass |

### Week 3 — monetization, testing, launch
| Day | Work |
|---|---|
| 15 | Passes and products created, Shop panel, receipts, thumbnails |
| 16 | Balance simulator + tuning; bot difficulty tuning from playtest data |
| 17 | Exploit pass (seat teleport, remote spam, speed), data migration tests |
| 18 | Icon, thumbnails (posed pack fighters rendered in the studded arena), game page |
| 19 | Private beta with 20 unfamiliar players; record the funnel |
| 20 | Fixes from beta |
| 21 | Public launch at low ad spend; read the first-day funnel before spending more |

---

## 17. Decisions I need from you
1. **Name.** Working title Anime Clash — keep or rename?
2. **Rarities.** Review the proposed tiers in [ROSTER.md](ROSTER.md) — who should be rarer or more common?
3. **Display names.** Keep the pack's character names in-game, or use altered names?
4. **Scope.** Ship the week-1 MVP to a small audience first, or hold for the full 3-week polish?
5. **Where it lives.** This plan assumes a new project at `~/Documents/RBX/anime-clash`, reusing creature-lab's tools, on its own Rojo port and its own Roblox place.
