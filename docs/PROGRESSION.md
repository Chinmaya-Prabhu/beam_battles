# Anime Clash — progression decision

Decided 2026-10-19. Replaces the progression parts of HIT_PLAN.md and POLISH_BIBLE.md where they conflict.

## What the top 1v1 Roblox games actually do

| Game | What you unlock | Does it make you stronger vs players? | What keeps you playing |
|---|---|---|---|
| **RIVALS** | Weapons, bought with Keys earned from wins, tasks and contracts | No: unlocks add options, not stats | Per-weapon contracts, wraps (skins), finishers, win streaks |
| **Untitled Boxing Game** | Fighting styles, rolled with Spins from quests and codes | Slightly: styles play differently and have tier lists, but skill dominates | Rolling for a better style, gloves, knockdown animations |
| **Blade Ball** | Abilities, bought with coins earned in matches | Sideways: each ability is a different tactic | Ranked tiers, swords, explosion effects |
| **The Strongest Battlegrounds** | Emotes, finishers, auras (free roll every 50 kills, or Robux) | No: kills give flair, not power | Cosmetic collection, monthly kill-leaderboard titles |

**The shared rule:** progression gives **options and flair, never raw power over another player.** Power progression only exists against the game itself (bosses, gates). Players return for new options (a weapon, style or ability), for status anyone can see (finishers, auras, titles, ranks, streaks), and for long goals (contracts, mastery, seasons).

## The problem in our design

Anime Clash is two genres glued together:
- a **collection simulator**, where numbers must go up (income, upgrades, rebirth), and
- a **1v1 skill duel**, where numbers must not decide the fight.

If upgrades raise clash power against players, veterans flatten newcomers and newcomers quit. If upgrades do nothing, the simulator half has no point. Our plan's Bronze-only power cap patched this, but only on one tier.

## The call

### 1. Two separate ladders
- **The economy ladder (vertical, numbers go up):** fighters on your plot earn cash, cash buys upgrades (click power, plot slots, speed), and rebirth multiplies it all. Upgrades count **only against the game itself**: altar guardian bots, the tier gates on Silver/Gold/Diamond altars, the Titan boss, and plot defence bots in raids.
- **The skill ladder (horizontal, options and flair):** in a clash between two humans, **stats count for nothing.** Both sides push at the same base strength. Skill (taps, pulses, counters, timing) and your fighter's style decide it.

One sentence for players: *"Upgrades beat the altars. Skill beats players."*

### 2. The clash becomes a skill duel
- **Pulses:** a target flashes for both players at once, about every 2.5 s. Tap it for PERFECT or GOOD; missing or tapping early staggers your beam. Whoever hits it first gets **FIRST STRIKE.** It's one big tap target, built for phones.
- **Surge** (one per clash) and **Counter Break:** surging within 0.5 s of your rival's surge cancels half of theirs and blasts the ball toward them.
- The 14 taps-per-second cap stays, so mashing helps but can't win alone.
- **Win grades S/A/B**, from accuracy and first strikes. An S win gets a double mutation roll on the prize.

### 3. Your Champion is your style
You equip **one Champion.** Its series sets one of four styles, each with one passive:

| Style | Series | Passive |
|---|---|---|
| Breaker | DBZ, AOT, One Piece brawlers | Losing badly: clicks +40% and surge charges faster |
| Counter | Bleach, swordsmen, Fate | PERFECT pulses hit harder; Counter Break steals surge charge |
| Tempo | Naruto, HxH, MHA speedsters | A pulse chain raises your combo multiplier |
| Disruptor | JJK, JoJo, Fairy Tail, sorcerers | Your surge shrinks the rival's next pulse window |

Rarer Champions are **not** stronger in a fight. They look better: bigger aura, a signature beam colour, a flashier finisher. This is how RIVALS weapons and UBG styles work. Collecting widens your options and your flex.

*This replaces the earlier "team of 3 + ultimates" decision.* A team of three either adds power (unfair) or adds complexity nobody reads mid-fight. One Champion with one clear style is how UBG works, and it's easy to understand at a glance.

### 4. Two currencies with two jobs
- **Cash** (plot income) feeds the economy ladder: upgrades, plot slots, rebirth.
- **Gems** come from clash wins, contracts, streak shutdowns, daily rewards and Index pages. They buy spins for cosmetics (finishers, beam colours, auras, emotes) and the Clash Pass tiers. They're the equivalent of RIVALS Keys or UBG Spins.

### 5. Long goals
- **Champion mastery contracts** (RIVALS-style), three per Champion: win clashes with it, land PERFECT pulses with it, end streaks with it. Rewards: level 1 a title, level 2 a mastery aura, level 3 its signature finisher.
- **A free cosmetic roll every 25 clash wins**, like The Strongest Battlegrounds' 50-kill emote rolls.
- **Win streaks** floating over your head, worth +3% plot income per streak up to +30%. Ending a 5+ streak triggers a server-wide banner and a gem bounty.
- **Clash Rank** (Bronze → Silver → Gold → Diamond → Champion) from wins against humans, with a monthly reset. The rank badge shows overhead, and season-end rewards are cosmetic.
- **Monthly leaderboards** for most wins, best streak and most shutdowns, each with a title that resets.

### 6. Monetization adjusted to the rule
- **Sells well and stays fair:** finishers, beam colours, auras and emotes (The Strongest Battlegrounds' model, the best-proven seller in this genre), spin packs for cosmetics, the Clash Pass, VIP, 2× Cash, drop luck (prize rarity only), auto-collect, extra podiums, shields, Server Luck.
- **Removed:** the "+1 team slot" pass (teams are gone) and anything that adds clash power against players.

## Build order (updates phase B)
1. **Clash skill layer:** pulses, first strike, counter break, grades, equal strength in player-vs-player, and full power against bots.
2. **Champion styles:** assign each series a style, add the passives, show the style badge at face-off.
3. **Streaks, shutdown bounties and the overhead badge.**
4. **Saving and plots (phase E)**, then cash upgrades that act only against the game.
5. **Gems, mastery contracts, cosmetic rolls, Clash Rank and leaderboards.**

Sources: [How to get keys fast in RIVALS](https://robloxden.com/game-codes/rivals/guides/how-to-get-keys-fast-in-rivals), [RIVALS on games.gg](https://games.gg/hi/rivals/), [Untitled Boxing Game codes and spins](https://www.digitalcitizen.life/untitled-boxing-game-codes/), [UBG style tier list](https://games.gg/nl/roblox/guides/untitled-boxing-game-style-tier-list-de-beste-stijlen-gerangschikt/), [Blade Ball ability tier list](https://www.pocketgamer.com/roblox/blade-ball-ability-tier-list/), [Roblox weekly recap Jan 2024](https://roblox-newsflash.beehiiv.com/p/weeks-roblox-recap-14-jan-2024), [How to get emotes in TSB](https://www.ginx.tv/en/?p=63335), [TSB wiki](https://bloxodes.com/wiki/the-strongest-battlegrounds).

## Update 2026-10-19: the clash is a Beam Rally
Playtesting showed the 10-second mash plus pulses felt "decent, not exciting". Research on the strongest duel loops (Blade Ball's speed ramp and one-mistake rounds, Dragon Ball's beam clashes, risk/reward design) pointed to the missing pieces: a single readable threat coming at you, a rising speed curve, rounds that end at the moment someone cracks, and a real gamble. The clash is now:
- **One orb flies between the players.** The receiver presses **DEFLECT (E)** as it arrives. Too early is a whiff with a short lockout; too late and the orb blows them away and they lose the round.
- **Every return is faster**, and a PERFECT is faster still. A rally starts calm and ends frantic; OVERDRIVE starts at 8 returns.
- **Mashing** (click or tap) slows an incoming orb, speeds your outgoing one, and charges **SMASH (Space)**.
- **SMASH:** arm it and your next return is much faster. A PERFECT on an incoming smash is a **REVERSAL**: it goes straight back at smash speed.
- **Best of three rounds**, with MATCH POINT and FINAL ROUND callouts. The grade comes from perfects, reversals and misses.
All numbers are in `Config.Rally`; the rules are in `ClashRules` (rally section), with tests in `tests/`.

**Fairness pass (same day).** Playtest: "can't win, clicking didn't matter." An offline simulation agreed: an average player won 26% against the easiest bot, and mashing changed nothing. Fixes:
- The late window grew from 70 ms to 180 ms. PERFECT now leans late (from 70 ms early to 120 ms late) to absorb screen, input and reaction lag.
- The whiff lockout dropped from 0.35 s to 0.15 s.
- The client places the orb by server time, so the ring and the server's judgment agree.
- Bots now decide just before their window opens, at the orb's *real* speed. Mash your return and it arrives faster, and the bot cracks more often.
- Bot fatigue now grows with the square of the speed-up, so bots stay solid on slow orbs and rallies build before someone breaks.
- Mashing counts more (±30% at an 8-tap-per-second lead), and an on-screen readout shows it ("PUSHING +x%" / "SLOWING IT −x%" / "RIVAL OVERPOWERING"). The beam of the side that is out-mashing also gets fatter.
- Tested in Studio with a scripted player that reads the on-screen ring. With 70 ms lag and mashing it won 2–0 and 2–1. With 120 ms lag, sloppy timing and no mashing it went 1–1. Simulator: `python3 tools/sim/rally_tune.py` (the model and the old numbers are in `rally_model.py`).

## Update 2026-10-20: train, travel, compete

**This supersedes "stats count for nothing between two humans" (§1–2 above).** The user's direction: the game is about players competing over rare spawns and getting stronger by training, like the top Roblox simulators. Guardians and zones serve that loop; they are not the game.

The loop: **train Power → reach a deeper zone → fight other players for its rarer drops → fighters earn cash on your plot → cash buys faster training → repeat** (rebirth later).

- **Power counts in PvP, capped per altar.** Power strengthens your side of the rally (mash push, return speed) through `ClashRules.powerMult`. Each altar tier has a `powerCap`: the hub's caps everyone near base strength so newcomers can win, and deeper tiers allow more. Deeper altars also need a minimum Power to sit (`Config.Tiers[].power`, `Battle.enforceTiers` on). Timing still matters, so a skilled player can upset a stronger one.
- **Training.** Clicking anywhere gives a little Power. Anime-themed stations (punching posts, boulder lifts, waterfall meditation, ki charging) give much more per rep. Each zone's stations are stronger than the last zone's. Cash buys training multipliers.
- **Drops get rarer the deeper you go** ("like Steal an Egg or Kick a Lucky Block: you go to the next zone hoping for a rarer item"). Proposed ladder: Hub = Bronze, Blossom = Silver, Ninja = Gold, Pirate = Diamond, Walled = a new top tier with the best Mythic/Secret odds. The hub loses its Gold and Diamond altars. Rare drops get a server-wide callout so players in that zone rush the pads.
- **Guardians and the boss gate the next zone** (its altars and its training stations). The first clear of each guardian pays cash or Power. Each boss gives an exclusive fighter.

Build order:
1. Saving and the plot economy: won fighters saved and shown on plot stands, cash per second, collect pads.
2. Power and training: saved Power, click training, zone stations, Power in the rally with altar caps, altar Power gates on.
3. Drop ladder retune: tiers per zone as above, the new top tier, rare-drop callouts.
4. Guardian first-clear rewards and boss-exclusive fighters.
5. Cash spending (training multipliers, plot slots), then rebirth.
6. Grab-and-run stealing.
7. HUD, shop, monetization (never selling raw PvP power), sound.

## Plot economy (built 2026-10-20)

`server/Services/PlotService.lua` and `client/Plots.lua`; the numbers are in `Config.Plot`.
- **Your base:** each player gets the first free plot when their data loads. The torii shows "<NAME>'S BASE", and the HUD's BASE button takes you there.
- **Stands:** your best fighters by income stand on your unlocked stands automatically. Every fighter won in a clash is saved.
- **Earning:** each stand adds its fighter's income ($8/s for a Common up to $500K/s for a Secret) to its own collect pad every second. Stepping on a pad collects it, with coins and a "+$N" pop.
- **Waiting cash:** uncollected cash is saved, so it's still on the pads when you come back. You don't earn while offline (a possible gamepass later).
- **Stand unlocks:** you start with 4 stands. Stands 5–8 cost $5K, $50K, $500K and $5M. Training stations (Sandbag $3K up to Gravity Seal $8B) are the other cash sink; gear costs Ki.
- **Leaderboard:** Power, Rebirths, Cash.

## Grab-and-run stealing (built 2026-10-20)

`server/Services/PlotService.lua` (rules) and `client/Plots.lua` (prompts and carry UI). Stealing is free, as in the big games.
- **Grabbing:** hold **E** for 1.5 s at a stand on someone else's base. A small copy of the fighter rides over the thief's head; they slow to walk speed 11, and a green beam and a "RUN TO YOUR BASE!" message guide them home.
- **Outcomes:** reaching their own plot keeps it. If the owner touches them (within 5 studs) it goes back; so it does if they die, leave or take longer than 60 s.
- **While carried:** the stand is empty and earns nothing. If the fighter was the owner's Champion, their next-best takes over.
- **Announcements:** the victim gets "CATCH THEM!" the moment a steal starts, and everyone sees "X STOLE Y FROM Z!" in a feed.
- **Defence:** the red LOCK pad just inside each torii blocks steals for 60 s, with a countdown sign over the gate. Steal prompts hide on a locked base.
- **Paid-perk hooks** (player attributes, set by the monetization step): FastSteal (0.5 s hold), LockBonus (extra lock seconds), CarryBoost (extra speed while carrying).
- **Tested** in Studio's Server & Clients mode with two players: steal → run home → kept; steal → owner catches → returned; locked base → refused.

## Altar Power gates and rebirth (built 2026-10-20)

**Altar gates.** A drop altar needs the tier's trained Power to sit (`Config.Tiers[].power`): Bronze 0, Silver 1K, Gold 25K, Diamond 500K. The tier plate shows it ("GOLD · 25K POWER"), and stepping on the pad short says "NEEDS 25K POWER · TRAIN TO SIT HERE". Guardians and bosses keep their own ladder. In clashes, Power still only weakens bots (log scale, floored); it doesn't change player-vs-player fights.
- Side effect: the hub's Gold and Diamond altars are now out of reach for new players, which removes the "Mythic at spawn" shortcut without moving any altars.

**Rebirth.** It needs `Training.rebirthCost(n)` Power: 1M, then ×5 each time (5M, 25M…).
- **Resets:** Power, Ki, gear, owned stations, body size.
- **Keeps:** fighters, base, cash, zones, passes.
- **Gain:** each rebirth is a permanent +50% training.
- **UI:** a REBIRTH button under SHOP appears at half the cost and reads "REBIRTH READY!" when you can. A confirm panel lists what resets and what stays. There's a burst, a banner for you and one for the server, and "R2"-style counts on overhead plates.
- **Code:** `client/Rebirth.lua`, `TrainingService` ("Rebirth" on the Train remote).
