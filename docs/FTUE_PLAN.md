# Anime Clash — first-time experience (FTUE)

**Changed 2026-11-04: fighter first.** The live order is swoop, personal drop, first fight, take it home, collect, then train, first aura, lock. The aim is a fighter in under 60 seconds (docs/ANIME_DICE_TEARDOWN.md). The table below is the older training-first plan; server/Services/TutorialService.lua is the source of truth.

Agreed 2026-10-20.
- **Style:** guided but mostly free. Arrows and coach text; steps wait for the player. Only the first click step blocks.
- **First win:** a rigged Epic and an easy bot.
- **Stealing:** a practice steal from a dummy base.
- **Afterwards:** a goals checklist with rewards.

**Aim:** a reward every ~30 seconds for the first 3 minutes; one new verb at a time; no wall of text. Each coach line is one short sentence.

## 1. The scripted part (about 3 minutes)

| # | Trigger | What happens | Teaches | Reward |
|---|---|---|---|---|
| 0 | First join | 4 s camera swoop over the hub. On the nearest altar a **Mythic** drops (client-only show, not a real drop): "THIS COULD BE YOURS". Skips on any click. | The dream | Spectacle |
| 1 | Swoop ends | Big pulsing hand at screen centre: **"CLICK TO TRAIN!"** Tutorial boost: training x5 until step 4 ends. Clicks do nothing else until 10 clicks. | Training | +N pops, Power racing |
| 2 | 50 Power | **"GIFT! WOODEN WEIGHTS"**: gear tier 2 snaps on with sparkles (free). | Gear | Visible item |
| 3 | 1K Power | The first aura power-up (the existing moment), coach: "YOU UNLOCKED AN AURA! KEEP TRAINING TO EVOLVE IT". | Auras | Big moment |
| 4 | Right after | Arrow on the ground and a beam to the nearest hub Bronze altar. A personal **Epic** drops there (reserved for this player for 90 s; other players see it but can't sit). Coach: "A FIGHTER DROPPED! STAND ON THE PAD TO CLASH". | Drops, altars | Anticipation |
| 5 | Seated | **Tutorial clash:** best of 3 against an easy bot that misses after 3–4 returns. Coach lines in the clash UI, in order: "PRESS E WHEN THE ORB HITS THE RING" → "CLICK FAST TO PUSH IT" → "SPACE = SMASH WHEN CHARGED". | The core fight | The win |
| 6 | Won | The fighter flies to them and becomes their **Champion**: "NEW CHAMPION · x2 TRAINING!" (existing). | Champions | Follower + multiplier |
| 7 | Right after | BASE button pulses; coach: "YOUR FIGHTER EARNS CASH AT YOUR BASE". On arrival the arrow points at the pad: "STEP ON THE PAD TO COLLECT". Starter stash: the pad already holds $500. | Plot income | Cash pop |
| 8 | Collected | Arrow to the **Practice Dojo** (a one-stand dummy base near spawn holding a Rare fighter): "STEAL IT! HOLD E, THEN RUN HOME". The usual steal flow (carry, beam home); no catcher. | Stealing | A second fighter (Rare) |
| 9 | Home with it | Arrow to their LOCK pad: "OTHER PLAYERS CAN STEAL TOO. STEP HERE TO LOCK YOUR BASE". | Defence | — |
| 10 | Locked | "YOU'RE READY!" Confetti, +500 Ki. The goals list appears. The x5 tutorial boost ends here (from step 4 it's x2, so training doesn't feel like it suddenly drops). | — | Ki gift |

**Rules for every step:**
- It waits as long as needed; the arrow re-points if they wander.
- Leaving and rejoining resumes the current step (saved as `data.ftue`).
- Returning players (with data) never see it.
- In Studio, the attribute `ResetFTUE` restarts it for testing.

## 2. Goals checklist (after the script)
Three goals on the HUD at a time, under the Power bar; each is a short line with a tiny progress bar.
- Finishing one: a chest pop, "+REWARD", and the next goal slides in.
- Goals point at the next system to learn; each one that needs a place puts an arrow there on click.

| # | Goal | Reward | Teaches |
|---|---|---|---|
| 1 | Reach 10K Power (Fighter aura) | 1K Ki | Training |
| 2 | Buy Stone Weights | $1K | Gear stall |
| 3 | Win 3 clashes | 2K Ki | Clashing |
| 4 | Collect $5K at your base | $2K | Income |
| 5 | Unlock stand 5 | 3K Ki | Spending cash |
| 6 | Enter Blossom Academy | $5K | Zones |
| 7 | Buy the Bench Press | 5K Ki | Stations |
| 8 | Beat Guardian 1 | $10K | Guardians |
| 9 | Sit at a Silver altar | 10K Ki | Altar gates |
| 10 | Steal a fighter from a player | $25K | Stealing for real |
| 11 | Beat the Blossom boss | 50K Ki | Next zone |
| 12 | Reach 1M Power | $100K | — |
| 13 | Rebirth | 2x Training for 15 min (free) | Rebirth |

After goal 13 the list loops into repeatable "daily-style" goals (win 5 clashes, collect $X, train for 5 min), so the HUD always has something to chase.

## 3. Build pieces
- **shared/Goals.lua:** the goal list, each with an id, text, target, reward and how to measure progress (from saved counters).
- **Saved data:** `ftue` (step), `goal` (index), counters (`wins`, `collected`, `steals`, `zones`).
- **server/Services/TutorialService.lua:**
  - steps, the x5/x2 boost (through TrainBoost)
  - the gift weights
  - the personal Epic drop and reserved altar (DropService and ClashService hooks)
  - the easy bot
  - the starter stash and the practice steal
  - goal tracking and rewards
- **Practice Dojo:** a small built base near spawn with one stand; stealing from it is per player and only during step 8.
- **client/Tutorial.lua:** the swoop and Mythic show, pointer hand, ground arrow and beam to targets, coach line, goals list, clash coach lines (via an attribute the clash UI reads), confetti.

## 4. Test
A fresh player in Studio, start to finish: every step in order, rejoin mid-way, a second player taking the reserved altar (refused), and the goals ticking.

## Status (2026-10-20): built and played through in Studio
- **Code:** `server/Services/TutorialService.lua`, `client/Tutorial.lua`, `client/ArrowPath.lua`, `shared/Goals.lua`, plus small hooks in Drop, Clash and Plot services.
- **Directions:** a trail of green arrows on the ground, routed with pathfinding, leads to every target. The same trail guides a carried fighter home.
- **Tutorial clash:** a soft bot that receives first and cracks by its 3rd return, and the new player gets up to 3 automatic saves per round. Tested with no input at all: VICTORY S.
- **Losing anyway** ("SO CLOSE! TRY AGAIN") drops a fresh personal Epic on the nearest free Bronze altar. Reserved drops refuse other players.
- **Practice Dojo:** built on the free spot on the outer ring closest to spawn.
- **Studio switches** (player attributes, set from the server command bar): `ResetFTUE` replays it; `DebugFtueStep = n` jumps to step n.
- **Not tested:** rejoining mid-tutorial (Studio can't save without API access).
