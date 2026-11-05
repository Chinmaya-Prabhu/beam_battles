# Anime Dice: playtest report

Played 2026-11-05, 10:50 to 11:11 (about 21 minutes), on desktop, on an existing save with $29.6M and 45 units. No Robux spent.
So this covers mid-early game on a keyboard. It does **not** cover a brand-new player's first minutes, phone layout, sound (I can't hear it), late game, or trading.
Screenshots: `docs/anime_dice_playtest/`. Earlier facts and ad decision: `docs/ANIME_DICE_TEARDOWN.md`.

Labels: **Saw** = happened on screen. **Read** = my interpretation.

## The short version
Anime Dice is not a good-looking game, and it isn't deep to play. It wins because **almost every second gives you a number that went up, and the next purchase is always nearly affordable.** There is one verb (roll). Everything else is a multiplier on that verb. Nothing is ever a waste, nothing is ever far away, and nothing needs skill.

In 21 minutes my best unit went from $46/s to $13K/s, about 280x. I hit "I want one more" several times, and I'm not a kid.

## 1. The core loop (Saw)
1. Tap ROLL. A card appears in about 1 second.
2. The unit goes in your backpack and earns on your plot.
3. Cash buys a better die or an upgrade node.
4. Luck goes up, so better units come out.
5. Rebirth when cash allows. Repeat.

- Roll cycle: about 3 to 5 seconds on AUTO, without the Roll Speed pass (27 units in about 90 seconds in one stretch).
- AUTO is free and adds a HIDE button that skips reveals. The game is happy to play itself. AUTO exists on rolls, traits, quirks and tower fights.
- **Equip Best is one tap** in both the backpack and the tower. No inventory puzzle at all.

## 2. The numbers that drive it
**Luck is the star stat.** It sits on the HUD as a clover with a live multiplier. What I saw it do:

| Action | Luck shown |
|---|---|
| Start, Fire die | x12.5 |
| Buy Ice die ($4M) | x250 |
| Rebirth 1 | x375 |
| One rebirth point on Luck | x412.5 |
| Luck IV potion (5 minutes) | x1.6K |

Five jumps in 15 minutes, each instantly visible.

**Dice ladder (Saw):** Normal 2x, Fire 5x, Water 10x ($10K), Nature 20x ($75K), Lightning 42x ($500K), Ice 100x ($4M), Magma 200x ($30M), Storm 400x ($200M), Shadow 750x ($1.5B), Light 1,500x ($12B), Blood Moon 3,000x ($100B), up to Neon 750,000,000,000x ($250udc).
- Each step roughly doubles luck for about 7x the price, so the next die is always in reach but never free.
- Dice have rarities too, so the shop itself feels like a collection.
- The absurd end of the list is on show from day one. Scrolling to it is a thrill by itself.
- I was $510K short of Magma at $29.49M. That near miss pulled hard. **Read:** this is deliberate, or at least it works as if it were.

**One global odds table (Saw).** The Index lists each unit with its own number: 1 in 2, 3, 4, 6, 11, 15, 20, 28 and on up. Every unit has a unique odds number, the same everywhere.
- **This solves our odds problem.** We show a different number per altar, which is why "Rare 1 in 6" clashed with "Rare 1 in 100". They have no altars, so no contradictions.
- **The label is the base odds and luck is a separate stack.** So with 250x luck I saw labels of 1 in 28K, 1 in 170K and 1 in 6M within minutes, and I own a Huge Zaro labelled 1 in 170K. Big honest-looking numbers, delivered often. This is the same idea as our New Player Luck, applied to the whole game.

**Rarity layers on a unit (Saw):** rarity, size (None, Huge, Titanic), mutation (silver, gold, emerald, diamond and more), trait (Genesis 120x at about 0.0006%), grade, quirk (Sovereign 0.002%), awakening stars (up to 5, from duplicates). About seven layers, and each one has its own reroll stall.

## 3. Dopamine triggers
| Trigger | How it plays | Why it works (Read) |
|---|---|---|
| Instant reveal | Card with odds on a coloured burst (green, blue, purple) in about 1 second | Reward comes faster than you can get bored |
| Odds as the headline | "1 in 170K" in big tilted type above the name | The number is the prize. It's bragging material |
| Lucky Spin cinematic | HUD disappears, clovers stack (x1.5, x2, x4), screen goes black, camera rockets into the sky, speed lines, slams down tilted with "1 in 7,985" | The one big set piece. It costs 8 seconds and feels huge |
| Clover shower | Clovers flood the screen on a good roll | Cheap effect, big feeling |
| Your die is the button | The ROLL button turned into my Ice die | Your best item is what you press all day |
| Cash burst | Equip Best took me from $3.42M to $20.57M in one tap | Saved-up income landing at once feels like winning |
| Hex tree fog | Upgrades are a hex map with "?" tiles. Each buy reveals neighbours | Curiosity. Every purchase shows you something new |
| Live card update | A trait reroll changed the card from $11K/s to $13K/s on the spot | Instant proof the action mattered |
| Ticking potion | Potion timer on the HUD (4m59s) | Urgency. You want to roll now |
| Red badges | "!" on Rebirth and Shop, number on Upgrades | Always something waiting |
| Reward strips | Codes fly in as three strips plus a counter on the HUD | Even free stuff gets a moment |

**Possible near-miss reel (unconfirmed):** before a Lucky Spin lands, very rare cards flash past (1 in 120M, 1 in 110K), then the final result is far lower (1 in 1,516). It looks like a slot reel, but I didn't check whether those cards entered my backpack. It may also raise a fairness question, so I wouldn't copy it blindly.

**One weak spot:** rebirth has almost no moment. The number resets, "Rebirth successful!" appears, and that's it. We can beat them here.

## 4. Nothing is ever wasted
- Duplicates feed Awakening stars, so a dupe still has value.
- Junk potions fuse 10 into 1.
- Bad units can be sold (SELL UNITS stall).
- Rebirth keeps your dice, units and upgrades. It only resets cash, and it gives a point to spend (Luck, Money, Damage, Health, Trait Luck) with a free Reset. So rebirth feels like a pure gain.
- First rebirth cost $50K, the next $5M. I could afford the second about 7 minutes later.

## 5. Other systems
- **Towers** (Dragon Easy, Cursed Medium, Pirate, Slayer Nightmare, Shadow Abyssal): a pure auto-battler. Two cards, HP bars, damage numbers, a floor count ticking up about once a second. My team of 4 reached around floor 9, and the reward was one potion on a rainbow screen. Drop odds are visible before you start. It gives units a second use and feeds potions and gems. It took under a minute and no skill.
- **Trading:** locked at 1,000 rolls (I was at 62). A goal, and a guard against throwaway accounts.
- **Quirks, Traits, Grades:** each one is the same screen: pick a unit, roll, with the full odds table on the right showing what you could hit.
- **Backpack cap:** 105 slots with a visible count (I hit 89). It gently pushes you to sell, fuse, or buy Unit Storage.
- **Offline money:** in the description, and again as rainbow text on the **exit screen**: "Characters earn money offline!". Even leaving sells coming back.
- **Daily:** opens itself on join, 7 days of consumables with a big Day 7. A 1,000x Jackpot Spin is the Day 5 and Day 7 reward, so free players taste the paid item.
- **Friend Boost:** always on the HUD with a + button, next to cash. A constant nudge to invite friends.
- **Other players:** you see their plots ringing the hub, with glowing units and a name, rarity, odds and $/s floating over them. I barely interacted with anyone, and stealing doesn't exist. Social is display, not conflict.

## 6. UI
**Saw:** bottom centre is BACKPACK, huge ROLL, UPGRADES. Left: Shop, Rebirth, Index. Top: Hub, Home, Shop teleports. Right: two offer tiles. Bottom left: cash and Friend Boost. Bottom right: buffs.
- Everything is one of three places: bottom (play), left (menus), right (sell).
- Windows are small, centred, dark, with a thick coloured title bar per system and a big red X.
- Walking into a glowing ring opens a stall. No prompt, no key. Teleport buttons mean you barely walk.
- Backpack cards show only face plus $/s, sorted by earnings. Tooltip shows level, $/s, odds.
- Short labels, big type, rounded heavy font with a dark outline.
- Rarity colour is consistent on every card border.

**Weak points:** the ring reopens a window if you stand in it, which caught me several times. Some close buttons took two clicks (possibly just my automated clicking). Stall words are small from a distance.

## 7. Visuals
**Saw:** cheap but cohesive. Saturated blue sky, flat green and red studded plates, low-poly palms, simple stalls with big floating words. Characters are plain blocky Roblox rigs, often stiff. Names are disguised like ours (Naroto, Zell, Aizan, Zaro).
**Read:** the art is not why it's popular. Its job is to be readable on a phone and stay out of the way. The polish goes into icons (dice, potions, gems) and UI, which is what you stare at. Our world and fighters are clearly better. Our UI icons and reward moments are where we should copy them.

## 8. Monetization
**Saw:** two offer tiles on the right with a sparkle burst and an "OP!" tag. The top rotates through passes every few seconds. The bottom is always Jackpot Roll.
- Jackpot Spins are the consumable: 1,000x luck on the next roll. Bundles of 1, 5, 10 are shown first in the Shop.
- Passes all multiply the core verb: Double Roll, Ultra Luck 3x, Luck 1.5x, Roll Speed, More Cash 2x, More Traits, More Grades, VIP (chat tag, trail, 1.5x cash, 1.5x luck).
- Every pass has a gift button, so players can spend on friends.
- Shop title bar is an animated rainbow, the only window that gets one.

**Correction:** I said 24 Robux looked very cheap. Prices on your account are about 27% of the list prices (Double Roll 220 vs 799 list), which matches regional pricing. So don't copy 24 as a global price. The real list price is likely nearer 90.

## 9. What to take for Anime Beam Battle
Ordered by likely value. These are my recommendations, none is built yet.

1. **Replicate the feel inside beam battle, not their mechanics (decided 2026-11-05).** No roll or summon loop: the beam fight stays the core verb. Make that verb as fast, frequent and rewarding as a roll.
2. **Make Luck a visible HUD stat** with a live multiplier that jumps on every upgrade.
3. **One global odds number per fighter**, with luck stacked on top. This ends the altar label confusion.
4. **Equip Best and AUTO everywhere.** No manual placing as the default.
5. **Payout moment:** let saved income land in one big burst.
6. **Fog-of-war upgrade tree** instead of flat upgrades.
7. **Give duplicates a use** (stars or fusing).
8. **Rebirth gives points and keeps everything else.** Then give it the big moment they lack. Our aura and beam tech can win here.
9. **One big cinematic for rare rolls**, reusing our drop beam.
10. **Exit and daily hooks:** offline money on the leave screen, daily opens on join, consumable taste in daily rewards.
11. **Add a consumable to the offer icon**, kept always visible. Ours only rotates passes today.
12. **Gift buttons on passes.**

**What not to copy:** the flat art, stiff characters, and any near-miss reel until we've thought about whether it's fair to kids.

**Our real edge:** spectacle, the beam fight and stealing. Stealing creates stories their game doesn't have, but it also creates loss, and Anime Dice has none. **Read:** their no-loss design may be a big part of the 99% rating. It's worth asking whether stealing should be optional or softer for new players.

## 10. What changed on your Anime Dice account
Claimed the Day 1 reward, redeemed code UPDATE8, bought upgrade nodes and the Water and Ice dice with in-game cash, did Rebirth 1 (cash reset, point on Luck), ran one Dragon Tower, used one Luck IV potion, spent 2 trait rerolls on the top unit, used all Lucky Spins. Dismissed the Join Event prompt without subscribing. No Robux spent.
