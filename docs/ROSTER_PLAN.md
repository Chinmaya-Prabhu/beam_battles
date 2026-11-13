# Roster: zones, rarity, income, size and aura for every fighter

Everything below is in the game (generated from tools/pack/launch.json and shared/FighterAura.lua on 2026-11-13).

## Zone order

The zones open in this order: **Walled City, Blossom Academy, Ninja Village, Pirate Bay**. That list is
Config.ZoneOrder, and what goes with each place in the order is Config.ZoneSlots:

| Place in the order | Opens | Altars | Guardians' Power | Boss gives |
|---|---|---|---|---|
| 1st: Walled City | at 2K Power | Silver (mostly Uncommon) | 2K to 600K | Attack Titan (Legendary) |
| 2nd: Blossom Academy | when the Attack Titan falls | Gold (mostly Rare) | 1.5M to 50M | Gojo Unmasked (Mythic) |
| 3rd: Ninja Village | when Gojo falls | Diamond (mostly Epic) | 100M to 1.1B | Madara (Mythic) |
| 4th: Pirate Bay | when Madara falls | Celestial (mostly Legendary) | 2B to 12B | Whitebeard (Secret) |

Each zone keeps its own island, look, music, mutation, post and bag. The numbers (Power gates, prices, station
multipliers, weight-shop gates, guardian cash) follow the zone's place in the order, so the economy is the same as
before.

**Fighters that only come from guardians:** the Ninja Commons (Naruto, Sasuke, Rock Lee, Neji) and Rares (Kakashi,
Gaara, Tsunade), and Blossom's Commons and Uncommon (Eri, Speed Guy, Yuji, Lemillion). Their zone's altars start
above those rarities, but a guardian spawn rolls them.

## Income

Base per rarity (unchanged, tuned in tools/sim/cash_weights.py):

| Rarity | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|
| Income | 100/s | 400/s | 2K/s | 10K/s | 80K/s | 600K/s | 5M/s |

On top of that, each fighter has a hand-picked boost:

- **x1**: regular
- **x1.25**: a fan favourite or a power-up form
- **x1.5**: the zone's headline fighter at that rarity (at most one per rarity)

Mutations and stars multiply on top. Each rarity earns 4-8x the one below it, so a boost never beats the next rarity
up.

## Size

- **Normal fighters** keep their own size.
- **Titans:** the Attack, Female, Armored and Beast Titans stand at Whitebeard's giant size (2.6x a normal
  fighter), the Jaw Titan at 1.7x and the Cart Titan, on four legs, at 1.5x.
- **Room limit:** every place a fighter stands has a most-room limit (Config.Fit): altars 18 wide and 34 tall, base
  stands 17 and 30, a champion following you 12 and 22, a fighter carried overhead 9 and 12, a clash pad 14 and 26.
  It is checked after every multiplier, Huge mutations included. Normal fighters never reach it; a giant is shrunk
  until it fits, so it still towers over the others without burying an altar or the next stand.

## Aura

Each fighter's aura is a style plus two colours. Rarity sets how big and busy it is. In the tables, "steam
clouds" are the titans, the Demon Slayer fighters wear their breathing's colours, and the Saiyan forms wear their
own (UI Goku silver, UE Vegeta violet, SS4 Gogeta crimson).

## Hub (rookie altars)

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Common | Tanjirou **NEW** | 150/s (x1.5) | flames, orange with blue |
| Common | Zenitzu **NEW** | 125/s (x1.25) | lightning, gold with white |
| Common | Inoske **NEW** | 100/s | dark smoke and bolts, blue with pale blue |
| Uncommon | Nezuco **NEW** | 600/s (x1.5) | flames, red with pale red |
| Uncommon | Shinobo **NEW** | 400/s | sparkles, purple with pale pink |
| Uncommon | Mitsury **NEW** | 500/s (x1.25) | spirit flame, pink with green |
| Uncommon | Iguru **NEW** | 400/s | dark smoke and bolts, purple with white |
| Rare | Giyuu **NEW** | 3K/s (x1.5) | spirit flame, blue with white |
| Rare | Sanemy **NEW** | 2K/s | spirit flame, green with white |
| Rare | Erzza **NEW** | 2.5K/s (x1.25) | sparkles, red with white |
| Epic | Rengoko **NEW** | 15K/s (x1.5) | flames, orange with gold |
| Epic | Muichiru **NEW** | 10K/s | steam clouds, pale blue with white |
| Legendary | Gyomey **NEW** | 100K/s (x1.25) | energy wisps, gold with white |
| Legendary | Saitamo | 120K/s (x1.5) | a glowing halo, gold with white |

## Zone 1: Walled City (Silver altars)

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Common | Sashy | 100/s | energy wisps, orange with white |
| Uncommon | Erin | 600/s (x1.5) | steam clouds, white with orange |
| Uncommon | Erwyn | 400/s | energy wisps, gold with white |
| Uncommon | Mikasha | 500/s (x1.25) | energy wisps, red with white |
| Rare | Levii **NEW** | 3K/s (x1.5) | energy wisps, blue with white |
| Rare | Jaw Titan **NEW** *(titan size)* | 2.5K/s (x1.25) | steam clouds, pale gold with gold |
| Rare | Cart Titan **NEW** *(titan size)* | 2K/s | steam clouds, pale gold with orange |
| Epic | Female Titan *(titan size)* | 12.5K/s (x1.25) | steam clouds, white with orange |
| Epic | Beast Titan **NEW** *(titan size)* | 15K/s (x1.5) | steam clouds, orange with orange |
| Legendary | Attack Titan (boss) *(titan size)* | 120K/s (x1.5) | steam clouds, white with orange |
| Legendary | Armored Titan **NEW** *(titan size)* | 100K/s (x1.25) | steam clouds, gold with orange |

## Zone 2: Blossom Academy (Gold altars)

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Common | Erri | 100/s | sparkles, gold with white |
| Common | Speed Guy | 100/s | lightning, green with pale green |
| Common | Yuuji | 150/s (x1.5) | lightning, red with black |
| Uncommon | Lemilion | 400/s | sparkles, gold with white |
| Rare | Bakugoh | 2K/s | flames, orange with gold |
| Rare | Dekku | 3K/s (x1.5) | lightning, green with pale green |
| Rare | Hellflame | 2K/s | flames, orange with gold |
| Rare | Todoruki | 2.5K/s (x1.25) | flames, red with pale blue |
| Epic | All Mighty | 10K/s | big Saiyan flame, gold with white |
| Epic | Awakened Bakugoh | 12.5K/s (x1.25) | flames, orange with gold |
| Epic | Dekku Awakened | 15K/s (x1.5) | lightning, green with pale green |
| Legendary | 100% Dekku | 100K/s (x1.25) | lightning, green with white |
| Legendary | All Mighty (Max) | 80K/s | big Saiyan flame, gold with white |
| Legendary | Gojou | 120K/s (x1.5) | energy wisps, purple with pale purple |
| Legendary | Sukana | 100K/s (x1.25) | dark smoke and bolts, black with red |
| Mythic | Gojou (Unmasked) (boss) | 900K/s (x1.5) | energy wisps, purple with pale purple |
| Mythic | Sukana (Awakened) **NEW** | 750K/s (x1.25) | dark smoke and bolts, black with red |

## Zone 3: Ninja Village (Diamond altars)

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Common | Nejii | 100/s | spirit flame, white with white |
| Common | Rock Leo | 100/s | energy wisps, green with white |
| Common | Narutoe | 150/s (x1.5) | big Saiyan flame, orange with gold |
| Common | Sasuki | 125/s (x1.25) | dark smoke and bolts, black with purple |
| Rare | Gara | 2.5K/s (x1.25) | steam clouds, gold with gold |
| Rare | Kakashy | 3K/s (x1.5) | lightning, blue with white |
| Rare | Tsunadi **NEW** | 2K/s | energy wisps, green with white |
| Epic | Might Guyy | 10K/s | flames, green with white |
| Epic | Minatoe | 15K/s (x1.5) | lightning, gold with white |
| Epic | Orochimeru **NEW** | 12.5K/s (x1.25) | dark smoke and bolts, purple with green |
| Legendary | Itachy | 120K/s (x1.5) | dark smoke and bolts, black with red |
| Legendary | Pein | 80K/s | energy wisps, purple with white |
| Legendary | Sage Narutoe | 100K/s (x1.25) | big Saiyan flame, orange with red |
| Legendary | Jiraya **NEW** | 100K/s (x1.25) | energy wisps, orange with white |
| Legendary | Hashiramo **NEW** | 100K/s (x1.25) | energy wisps, green with gold |
| Mythic | Might Guyy (8th Gate) | 600K/s | flames, red with orange |
| Mythic | Minatoe (Fox Cloak) | 750K/s (x1.25) | big Saiyan flame, gold with white |
| Mythic | Madaro (boss) | 750K/s (x1.25) | dark smoke and bolts, black with blue |
| Mythic | Narutoe (Six Paths) **NEW** | 900K/s (x1.5) | spirit flame, gold with black |
| Mythic | Kaguyo **NEW** | 750K/s (x1.25) | sparkles, pale purple with white |
| Secret | Narutoe (Baryon) **NEW** | 5M/s | flames, orange with purple |

## Zone 4: Pirate Bay (Celestial altars)

| Rarity | Fighter | Income | Aura |
|---|---|---|---|
| Epic | Ase | 12.5K/s (x1.25) | flames, orange with gold |
| Epic | Sanjii | 10K/s | flames, orange with gold |
| Epic | Luffi | 15K/s (x1.5) | steam clouds, red with white |
| Epic | Zoru | 12.5K/s (x1.25) | dark smoke and bolts, black with green |
| Epic | Doflamengo | 10K/s | energy wisps, pink with white |
| Legendary | Akainuu | 100K/s (x1.25) | flames, red with orange |
| Legendary | Kizaro | 100K/s (x1.25) | sparkles, gold with white |
| Legendary | Snake Man Luffi | 100K/s (x1.25) | steam clouds, pink with white |
| Legendary | Fujitura | 80K/s | energy wisps, purple with pale purple |
| Legendary | Mihawck | 120K/s (x1.5) | spirit flame, red with white |
| Legendary | Raylee | 80K/s | dark smoke and bolts, black with red |
| Legendary | Aokijii **NEW** | 100K/s (x1.25) | sparkles, blue with white |
| Mythic | Shankz | 900K/s (x1.5) | dark smoke and bolts, black with red |
| Mythic | Sengoko | 600K/s | big Saiyan flame, gold with white |
| Mythic | Kaydo | 750K/s (x1.25) | big Saiyan flame, blue with gold |
| Mythic | Big Mum | 600K/s | flames, red with gold |
| Secret | Whitebeerd (boss) | 6.2M/s (x1.25) | energy wisps, white with blue |
| Secret | Luffi (Gear 5) **NEW** | 7.5M/s (x1.5) | steam clouds, white with pale purple |
| Secret | Rogger **NEW** | 6.2M/s (x1.25) | dark smoke and bolts, black with red |

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
| Legendary | Gogetta **NEW** | 120K/s (x1.5) | big Saiyan flame, gold with white |
| Mythic | Legendary Brolli | 750K/s (x1.25) | big Saiyan flame, green with pale green |
| Mythic | Vegitto | 900K/s (x1.5) | big Saiyan flame, gold with cyan |
| Mythic | Golden Freeza (boss) | 750K/s (x1.25) | big Saiyan flame, gold with purple |
| Secret | Beeris | 6.2M/s (x1.25) | dark smoke and bolts, purple with pink |
| Secret | Cel Max | 5M/s | energy wisps, green with green |
| Secret | Gohann (Beast) **NEW** | 6.2M/s (x1.25) | big Saiyan flame, white with red |
| Secret | Gokku (Ultra Instinct) **NEW** | 7.5M/s (x1.5) | big Saiyan flame, white with blue |
| Secret | Vegata (Ultra Ego) **NEW** | 6.2M/s (x1.25) | big Saiyan flame, purple with pink |
| Secret | Gogetta (SS4) **NEW** | 6.2M/s (x1.25) | big Saiyan flame, red with gold |

## Not yet checked in Studio

The new fighters haven't been seen in the game yet. To check:

- each new fighter in the gallery
- that the Jaw and Cart Titans' meshes move with their hidden skeleton
- that the Cart Titan faces forward
- the Beast Titan's long arms (the R15 rebuild may give it normal-length arms)
- Tanjiro's head (his model has no neck joint)
