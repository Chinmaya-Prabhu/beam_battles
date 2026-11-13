# Roster plan: rarity, income and aura for every fighter

Status: **the rarities and zones below are already in the game.** The **income boosts** and the **auras marked
*(new)* or *(changed)*** are proposals: nothing in the game uses them yet. Say yes and they go in.

## How income works

A fighter on your base stand earns cash every second. The base amount comes from its rarity. These numbers are
tuned against the cash weights in tools/sim/cash_weights.py, so they stay as they are:

| Rarity | Base income |
|---|---|
| Common | 100/s |
| Uncommon | 400/s |
| Rare | 2K/s |
| Epic | 10K/s |
| Legendary | 80K/s |
| Mythic | 600K/s |
| Secret | 5M/s |

**Proposed change:** today a name rule in gen_registry.py gives "strong form" fighters +25% and outfit swaps
-20%. Replace it with one hand-picked boost per fighter, so the fighter kids want most at each rarity also earns
the most:

- **x1**: regular
- **x1.25**: a fan favourite or a power-up form
- **x1.5**: the zone's headline fighter at that rarity (at most one per rarity)

Mutations and stars still multiply on top, as now. Each rarity earns 4-8x the one below it, so even x1.5 never
beats the next rarity up.

## How auras work

Each fighter's aura has a style (its shape) and two colours. Rarity sets how big and busy it is: a Common gets
one thin layer, a Legendary three, and a Secret three at the largest size plus sparkles. The styles are:

- big Saiyan flame
- flames
- dark smoke and bolts
- energy wisps
- spirit flame
- steam clouds
- sparkles
- lightning

## Hub (rookie altars)

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Common | Gonn | 100/s | energy wisps, green with white |
| Common | Hiey | 100/s | flames, purple with purple |
| Common | Kilua | 100/s | lightning, blue with white |
| Common | Yusuki | 100/s | spirit flame, blue with white |
| Uncommon | Grai | 400/s | spirit flame, pale blue with white |
| Uncommon | Hisokka | 400/s | energy wisps, pink with white |
| Uncommon | Ilumi | 400/s | dark smoke and bolts, black with purple |
| Uncommon | Natsue | 400/s | flames, orange with gold |
| Rare | Hiey (Third Eye) | 2K/s | flames, purple with purple |
| Rare | Natsue Awakened | 2K/s | flames, orange with gold |
| Rare | Yusuki Mode | 2K/s | spirit flame, blue with white |
| Epic | Grai Awakened | 10K/s | spirit flame, pale blue with white |
| Epic | Ilumi Awakened | 10K/s | dark smoke and bolts, black with purple |
| Legendary | Adult Gonn | 80K/s | big Saiyan flame, gold with white |
| Legendary | Kilua Godspeed | 80K/s | lightning, blue with white |

## Blossom Academy

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Common | Erri | 100/s | sparkles, gold with white |
| Common | Speed Guy | 100/s | lightning, green with pale green |
| Common | Yuuji | 125/s (x1.25) | lightning, red with black |
| Uncommon | Lemilion | 400/s | sparkles, gold with white |
| Rare | Bakugoh | 2K/s | flames, orange with gold |
| Rare | Dekku | 2K/s | lightning, green with pale green |
| Rare | Hellflame | 2K/s | flames, orange with gold |
| Rare | Todoruki | 2.5K/s (x1.25) | flames, red with pale blue |
| Epic | All Mighty | 10K/s | big Saiyan flame, gold with white |
| Epic | Awakened Bakugoh | 12.5K/s (x1.25) | flames, orange with gold |
| Epic | Dekku Awakened | 10K/s | lightning, green with pale green |
| Legendary | 100% Dekku | 100K/s (x1.25) | lightning, green with white (bigger, more bolts) *(new)* |
| Legendary | All Mighty (Max) | 80K/s | big Saiyan flame, gold with white |
| Legendary | Gojou | 120K/s (x1.5) | energy wisps, purple with pale purple |
| Legendary | Sukana | 100K/s (x1.25) | dark smoke and bolts, black with red |
| Mythic | Gojou (Unmasked) (boss) | 600K/s | energy wisps, purple with pale purple |
| Mythic | Sukana (Awakened) **NEW** | 900K/s (x1.5) | dark smoke, blood red with black *(new)* |

## Ninja Village

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Common | Nejii | 100/s | spirit flame, white with white |
| Common | Rock Leo | 100/s | energy wisps, green with white |
| Common | Narutoe | 150/s (x1.5) | big Saiyan flame, orange with gold |
| Common | Sasuki | 125/s (x1.25) | dark smoke and bolts, black with purple |
| Rare | Gara | 2K/s | steam clouds, gold with gold |
| Rare | Kakashy | 3K/s (x1.5) | lightning, blue with white |
| Rare | Tsunadi **NEW** | 2.5K/s (x1.25) | energy wisps, mint green with white *(new)* |
| Epic | Might Guyy | 10K/s | flames, green with white |
| Epic | Minatoe | 15K/s (x1.5) | lightning, gold with white |
| Epic | Orochimeru **NEW** | 12.5K/s (x1.25) | dark smoke, purple with snake green *(new)* |
| Legendary | Itachy | 120K/s (x1.5) | dark smoke and bolts, black with red |
| Legendary | Pein | 80K/s | energy wisps, purple with white |
| Legendary | Sage Narutoe | 100K/s (x1.25) | big Saiyan flame, orange with red |
| Legendary | Jiraya **NEW** | 100K/s (x1.25) | energy wisps, red-orange (sage) with white *(new)* |
| Legendary | Hashiramo **NEW** | 100K/s (x1.25) | energy wisps, leaf green with gold *(new)* |
| Mythic | Might Guyy (8th Gate) | 750K/s (x1.25) | flames, red with orange |
| Mythic | Minatoe (Fox Cloak) | 750K/s (x1.25) | big Saiyan flame, gold with white |
| Mythic | Madaro (boss) | 600K/s | dark smoke and bolts, black with blue |
| Mythic | Narutoe (Six Paths) **NEW** | 900K/s (x1.5) | spirit flame, gold with black sparks (the orbs) *(new)* |
| Mythic | Kaguyo **NEW** | 750K/s (x1.25) | sparkles, pale violet and white *(new)* |
| Secret | Narutoe (Baryon) **NEW** | 5M/s | flames, red-orange with violet tips *(new)* |

## Pirate Bay

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Epic | Ase | 12.5K/s (x1.25) | flames, orange with gold |
| Epic | Sanjii | 10K/s | flames, orange-red *(new)* |
| Epic | Luffi | 15K/s (x1.5) | steam clouds, red with white |
| Epic | Zoru | 12.5K/s (x1.25) | dark smoke, black with green *(new)* |
| Epic | Doflamengo | 10K/s | energy wisps, pink with white |
| Legendary | Akainuu | 100K/s (x1.25) | flames, red with orange |
| Legendary | Kizaro | 100K/s (x1.25) | sparkles, gold with white |
| Legendary | Snake Man Luffi | 100K/s (x1.25) | steam clouds, pink with white |
| Legendary | Fujitura | 80K/s | energy wisps, purple with pale purple |
| Legendary | Mihawck | 120K/s (x1.5) | spirit flame, red with white |
| Legendary | Raylee | 80K/s | dark smoke and bolts, black with red |
| Legendary | Aokijii **NEW** | 100K/s (x1.25) | sparkles, ice blue with white frost *(new)* |
| Mythic | Shankz | 900K/s (x1.5) | dark smoke and bolts, black with red |
| Mythic | Whitebeerd (boss) | 600K/s | energy wisps, white with pale blue cracks *(new)* |
| Mythic | Sengoko | 600K/s | big Saiyan flame, gold with white |
| Mythic | Kaydo | 750K/s (x1.25) | big Saiyan flame, blue with gold |
| Mythic | Big Mum | 600K/s | flames, red with gold |
| Secret | Luffi (Gear 5) **NEW** | 7.5M/s (x1.5) | steam clouds, pure white with soft lilac *(new)* |
| Secret | Rogger **NEW** | 5M/s | dark smoke, black with red bolts (Conqueror's Haki) *(new)* |

## Walled City

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Legendary | Anny | 80K/s | steam clouds, white with orange |
| Legendary | Erin | 120K/s (x1.5) | steam clouds, white with orange |
| Legendary | Mikasha | 100K/s (x1.25) | energy wisps, crimson with white *(new)* |
| Mythic | Erwyn | 600K/s | energy wisps, gold with white *(new)* |
| Mythic | Levii **NEW** | 900K/s (x1.5) | energy wisps, steel blue with white streaks *(new)* |
| Secret | Attack Titan (boss) | 5M/s | steam clouds, white with orange |
| Secret | Female Titan | 6.2M/s (x1.25) | steam clouds, white with orange |
| Secret | Armored Titan **NEW** | 6.2M/s (x1.25) | steam clouds, sand gold with orange *(new)* |

## Divine (summon only)

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Epic | Cel (boss) | 10K/s | energy wisps, green with green |
| Legendary | Brolli | 80K/s | big Saiyan flame, green with white |
| Legendary | Gokku | 100K/s (x1.25) | big Saiyan flame, gold with cyan |
| Legendary | Majin Vegata | 80K/s | big Saiyan flame, gold with purple |
| Legendary | Vegata | 100K/s (x1.25) | big Saiyan flame, blue with white |
| Legendary | Mahoraja (boss) | 80K/s | spirit flame, white with gold |
| Legendary | Freeza | 80K/s | energy wisps, purple with white |
| Legendary | Gogetta **NEW** | 120K/s (x1.5) | big Saiyan flame, gold with white *(new)* |
| Mythic | Legendary Brolli | 750K/s (x1.25) | big Saiyan flame, green with pale green |
| Mythic | Vegitto | 900K/s (x1.5) | big Saiyan flame, gold with cyan |
| Mythic | Golden Freeza (boss) | 750K/s (x1.25) | big Saiyan flame, gold with purple |
| Secret | Beeris | 7.5M/s (x1.5) | dark smoke and bolts, purple with pink |
| Secret | Cel Max | 5M/s | energy wisps, green with green |
| Secret | Gohann (Beast) **NEW** | 6.2M/s (x1.25) | big Saiyan flame, silver-white with red bolts *(new)* |
| Secret | Gokku (Ultra Instinct) **NEW** | 7.5M/s (x1.5) | big Saiyan flame, silver with blue wisps *(new)* |
| Secret | Vegata (Ultra Ego) **NEW** | 6.2M/s (x1.25) | big Saiyan flame, violet with pink bolts *(new)* |
| Secret | Gogetta (SS4) **NEW** | 6.2M/s (x1.25) | big Saiyan flame, crimson with gold *(new)* |

## Hub: what to import

The Hub is the first 15 minutes of play (rookie altars, Common to Legendary), so it needs the names kids already
chase, one version of each. Today it holds 15 fighters from three older series, and 7 of them are repeats:

- Gon and Adult Gon
- Killua and Killua Godspeed
- Hiei and Hiei Third Eye
- Yusuke and Yusuke Mode
- Natsu and Natsu Awakened
- Gray and Gray Awakened
- Illumi and Illumi Awakened

The proposal is a Demon Slayer core (all eight Hashira are already imported) plus the newer hits.

| Rarity | Fighter | Have it? |
|---|---|---|
| Common | Tanjiro | yes (pack) |
| Common | Zenitsu | **import** |
| Common | Inosuke | **import** |
| Common | Denji (Chainsaw Man, human form) | **import** |
| Uncommon | Nezuko | **import** |
| Uncommon | Power (Chainsaw Man) | **import** |
| Uncommon | Genos (One Punch Man) | **import** |
| Uncommon | Okarun (Dandadan) | **import** |
| Rare | Giyu | yes (Hashira) |
| Rare | Shinobu | yes (Hashira) |
| Rare | Mitsuri | yes (Hashira) |
| Rare | Momo (Dandadan) | **import** |
| Epic | Rengoku | yes (Hashira) |
| Epic | Muichiro | yes (Hashira) |
| Epic | Sanemi | yes (Hashira) |
| Epic | Chainsaw Man (devil form) | **import** |
| Legendary | Saitama | yes (pack) |
| Legendary | Sung Jinwoo (Shadow Monarch) | **import** |
| Legendary | Gyomei | yes (Hashira) |

**The 10 to import:**

1. Zenitsu
2. Inosuke
3. Denji
4. Nezuko
5. Power
6. Genos
7. Okarun
8. Momo
9. Chainsaw Man (devil form)
10. Sung Jinwoo

Iguro stays parked, and so do the Upper Moons, for a Demon Slayer zone later.

## Open points

- **Walled City has only 3 Legendaries** (Annie, Eren, Mikasa), but its altars roll a Legendary 88% of the time.
  Adding Hange, Reiner, Bertholdt or Zeke would help.
- **Ninja Village has no Uncommon, and Pirate Bay has no Rare.** That's fine: their altars never roll those
  rarities, and a guardian roll at a missing rarity gives a fighter from the next rarity down.
- **Pirate Bay's guardians were the young versions**, which are now cut. They are now Zoro, Sanji, Ace, Mihawk and
  Shanks, with Whitebeard as the boss.
