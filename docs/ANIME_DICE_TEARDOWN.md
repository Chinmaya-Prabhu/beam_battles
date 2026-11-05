# Anime Dice teardown and ad decision

Written 2026-11-04. Numbers are from Roblox's public APIs, trackers and fan wikis. Visuals were checked by playing on a desktop client with an existing save, so the first-time experience was not timed.

## Decision
- No real ad money yet. Run one $250-500 test (about 1,000 plays) to get data.
- Scale only if: day-1 retention 16%+, day-7 5%+, session 15+ min, 2%+ of players pay.
- If the test misses, fix the loop, not the budget.
- Before the test: first fighter in under 60 seconds; stealing, locking and gear move to after the first win.
- If the test misses: make the beam fight loop faster and more rewarding. Do not add a roll or summon loop; we copy the feel, not the mechanics.

## Benchmarks (GameAnalytics 2026, games with 1M+ monthly players)
| Metric | Median | Top 1% |
|---|---|---|
| Day-1 retention | 10.3% | 22.2% |
| Day-7 retention | 1.6% | 9.1% |
| Game session | 9.8 min | 21.1 min |

3.8% of players pay across Roblox. Third-party cost per play is about $0.22-0.45 (unofficial, conflicting), against roughly $0.18 revenue per player at a top-5% game, so ads buy data and a discovery push, not direct profit.

## Anime Dice facts
- More & More Games, universe 10708913337, released 2026-08-15.
- 161.8M visits, 103,168 peak players, 99% rating, 11 updates in 81 days. About 39K players on 2026-11-04 and falling.
- The studio's four earlier games made about 8M visits in total.
- Passes (list price): Double Roll 799, Ultra Luck 499, Roll Speed 349, More Traits 329, More Grades 299, VIP 249, Luck 199, More Cash 199.

## Why it works
1. One action: roll, and a reward appears in about 3 seconds.
2. Money while offline, first line of the description.
3. Stacked luck: rarity, mutations, traits, grades, sizes.
4. Every pass boosts the roll.
5. Like and player-count milestones unlock codes. Trading arrived in week 2.

## Visual comparison
| Area | Better | Why |
|---|---|---|
| World and zones | Us | They have flat brick plots and one hub; we have four themed zones |
| Fighter presentation | Us | Our giants, auras and beam fights beat their small units with tiny nameplates |
| Store art polish | Us | Ours is cleaner and brighter |
| Store art message | Them | A hand holding dice explains the game instantly; ours does not show what you do |
| HUD hierarchy | Them | One huge ROLL button bottom centre; we have no single main button |
| Core reward moment | Them for speed, us for spectacle | Their reveal takes about 3 seconds with the odds in the middle of the screen |
| Selling on the HUD | Them | Two sparkling offer tiles rotate through passes, including a cheap Jackpot Roll |

## Visual actions
1. Give the phone HUD one big main button.
2. Show the action in the thumbnail: a hand or player reaching for the prize, or a beam fight.
3. Bring back one rotating offer tile on phones (pass offers are off there now) and add a cheap impulse product.
4. Add a fast reveal card with the odds big in the middle.
