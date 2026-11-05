# Anime Clash — monetization

Catalogue: `src/shared/Products.lua`. Server: `src/server/Services/MonetizationService.lua` (grants), `src/server/Reveal.lua` (fighter reveals). Shop screen: `src/client/Shop.lua`. Gear stalls: `src/client/GearShop.lua`. Pass offer tile: `src/client/PassOffers.lua`. Research and the approved shop plan: `docs/SHOP_RESEARCH.md`.

## Rules
- Nothing sold decides a fight between two players by itself. Stealing stays free; the perks around it only speed things up.
- No fake urgency. Every countdown is real, and nothing is called LIMITED or "-X%" unless it truly is.
- The aura shows Power you earned. Anything cosmetic sold later only changes its colour or style, never its size or tier.
- Paid random items (summons, and the Starter Pack's random Epic fighter) follow Roblox policy. Players where they're restricted don't see summons, and the Starter Pack gives a fixed Epic instead. Summon odds are shown on each card.
- Pop-ups appear at most once per session each. They never appear mid-clash, never over a window, and take turns with each other.

## Gamepasses (owned forever)
| Key | Name | Price (R$) | Description |
|---|---|---|---|
| VIP | VIP | 299 | +50% cash · 2x daily rewards · gold name and chat tag |
| ProBundle | Pro Bundle | 449 | 2x Cash + 2x Power + Auto Train |
| DoubleCash | 2x Cash | 199 | Your stands earn double, forever |
| DoublePower | 2x Power | 249 | Every rep gives double Power and Ki |
| AutoTrain | Auto Train | 149 | Train while you're AFK (toggle on the HUD) |
| FastSteal | Fast Steal | 299 | Grab in 0.5s and run faster carrying |
| DropLuck | x2 Drop Luck | 249 | Drops near you roll twice as rare |
| MutationLuck | 2x Mutations | 349 | Drops near you and your summons mutate twice as often |
| ExtraStands | +2 Stands | 299 | Two extra gold stands at your base, forever |
| DragonWeights | Shenron Dragon Weights | 599 | x1000 per click, or 3x your best weights, forever |
| ChakraWeights | Nine-Tails Chakra Weights | 299 | x700 per click, or 2x your best weights, forever |

The Pro Bundle counts as owning 2x Cash, 2x Power and Auto Train. It hides once you own any of them, and its "save N R$" comes from the live prices. VIP doubles the daily Cash, Ki and boosts (a fighter day stays one fighter). +2 Stands opens the two gold stands beside the base tent (slots 9 and 10); without it they show "+2 STANDS PASS" and their prompt offers it.

Premium weights are never outgrown. They give the larger of their own multiplier and 2x (Nine-Tails) or 3x (Shenron) the player's best Ki weight (`Training.gearMult`).

## Developer products (bought again and again)
| Key | Name | Price (R$) | Description |
|---|---|---|---|
| ServerLuck | Server Luck | 99 | Rarer drops for EVERYONE for 15 min |
| PowerBoost | 2x Training | 49 | Double Power and Ki for 15 min |
| Shield | Base Shield | 39 | Nobody can steal from you for 10 min |
| CashLarge | Cash Vault | 99 | 1 hour of your stands' income |
| StandNow | Next Stand | 49 | Unlock your next stand right now |
| CashHuge | Treasury | 249 | 4 hours of your stands' income |
| StarterPack | Starter Pack | 49 | Epic fighter · Iron Weights · 2x Training 30 min · $250K |
| Restock | Restock Now | 29 | New gear stall stock right now |
| SummonLegendary | Legendary Summon | 175 | A Legendary or better fighter |
| SummonMythic | Mythic Summon | 599 | A Mythic or better fighter |
| SummonSecret | Secret Summon | 2399 | A guaranteed Secret fighter |

## Where players see things to buy
- **The SHOP tile:**
  - FEATURED: the Starter Pack (new players, 3 days, one time), the premium weights, and the summons (where allowed)
  - PASSES
  - BOOSTS
  - CASH
- **Gear stalls:** the two premium weights on pedestals, the stall window's premium cards, and RESTOCK.
- **Moment offers** (once per session each):
  - Server Luck after a Mythic or Secret drop
  - Base Shield after being robbed
  - 2x Training after a rebirth
  - the Starter Pack after the tutorial
- **Seen in the world:** the premium weights on a player's wrists and ankles, the VIP tag on their plate, and "X SUMMONED ..." banners.

## Going live: needs you, on the Creator Dashboard
1. Publish the place.
2. Create every pass, product and badge with `tools/ids/create.py` (Open Cloud). It uploads each icon from
   `art/products/` and `art/badges/` (`tools/ids/icons.py` builds the ones not hand-cut) and writes every new ID
   into `src/shared/Products.lua` and `Config.Badges`:
   ```bash
   python3 tools/ids/create.py                  # dry run
   python3 tools/ids/create.py --go             # passes and products (free)
   python3 tools/ids/create.py --go --badges    # badges: 100 R$ each, asks first
   ```
   Then publish again so the live game has the IDs.
3. **Group:** create the group on Roblox (only you can) and paste its ID into `Config.Social.groupId`.
4. Until an item has an ID, a live game shows SOON on it; in Studio, items with ID 0 are given for free so they can be tested.
5. Optional:
   - set a private server price (around 50 R$ is common in the genre)
   - turn on Premium Payouts (automatic for Premium members' playtime)

## Safety
- Each developer-product purchase is granted exactly once. Purchase IDs are saved with the player's data, and the save is written straight away.
- Nothing is granted before the player's data loads; Roblox retries the purchase until it can be.
- Pass ownership is checked with Roblox on every join.

## Changed 2026-10-21 (monetization review)
- **Removed:**
  - Cash Pack (25 R$)
  - the LIMITED labels (they're now FOREVER, since passes are permanent)
  - the Starter Pack's made-up "-70%" (now NEW PLAYERS · ONE TIME)
- **Changed:**
  - The Treasury is now 4 h of income (8 h made the Vault pointless).
  - Premium weights now scale with the Ki ladder, so they're never outgrown.
- **Added:**
  - the PolicyService check for paid random items
  - thumbnails in `art/products/`

## Built 2026-10-21 (second pass)
- **Stronger VIP:**
  - double daily Cash, Ki and boosts
  - "VIP" in gold on the overhead plate
  - a gold [VIP] chat tag
- **Pro Bundle** (449 R$): 2x Cash, 2x Power and Auto Train, which cost 597 R$ separately.
- **2x Mutations** (349 R$): drops near the owner, and the owner's summons, mutate twice as often. Clash prizes are not affected.
- **+2 Stands** (299 R$): two gold stands at the base.

## Decided against
- **Aura or trail sales:** the aura stays a pure sign of earned Power.
- **Any paid help in clashes:** no retries, surges or skips. Nobody can pay to win.

## Still open
- **Roblox Premium perk:** +10% cash and a tag for Premium members (Premium Payouts). Waiting for your decision.
- **"Can't afford" offer at the gear stall:** 2x Training, shown once per session.
- **VIP lounge in the hub:** needs world building.


## Beam skins (gamepasses, cosmetic only)

Equipped in the shop's BEAMS tab (shared/BeamSkins.lua, client/ClashBeams.lua). They change how your beam looks in
every clash, everyone sees it, and they never change the fight.

| Key | Name | R$ | Look |
|---|---|---|---|
| BeamKamehameha | Turtle Wave | 99 | blue-white wave |
| BeamHellfire | Hellfire | 149 | red flame, fire sparks |
| BeamChidori | Thousand Birds | 199 | violet lightning, jagged flickering core |
| BeamCursed | Cursed Energy | 199 | purple glow, black strands |
| BeamGoldenGod | Golden God | 249 | gold |
| BeamPrism | Prism Rainbow | 399 | colours cycle |

## Fighter Market (developer products)

Five price tiers (shared/Market.lua): MarketT1 79, MarketT2 199, MarketT3 649, MarketT4 1199, MarketT5 2499.
