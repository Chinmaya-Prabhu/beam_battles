# Anime Clash — launch roster (decided 2026-10-21)

Data: `tools/pack/launch.json` → `python3 tools/pack/gen_registry.py` → `src/shared/Fighters.lua` (`Fighters.Launch`, `ByPool`, `ByRarity`). 85 of the 148 pack fighters ship; the rest stay hidden for updates.

- **Each zone drops only its own universe** (`Odds.rollFighter` with the altar's zone; the hub uses the Hub pool). Earnings climb from the rookie hub to Dragon Ball.
- **Boss fighters (★) are exclusive**: only from beating that zone's boss; never dropped, summoned or gifted.
- **Dragon Ball** is Legendary / Mythic / Secret only and never drops: it comes from summons, the Secret Rush, the 90-minute gift and day 7.
- Income follows the launch rarity (Common 8 … Secret 500K per second).

## Hub — the rookie universes: Hunter × Hunter, Yu Yu Hakusho, Fairy Tail (Bronze + Silver altars) · 15

| Rarity | Fighters |
|---|---|
| Common | Gon, Hiei, Killua, Yusuke |
| Uncommon | Gray, Hisoka, Illumi, Natsu |
| Rare | Hiei (Jagan Eye), Natsu Awakened, Yusuke Mode |
| Epic | Grey Awakening, Illumi Awakened |
| Legendary | Adult Gon, Killua Godspeed |

## Blossom Academy — My Hero Academia + Jujutsu Kaisen (Bronze altars) · 16

| Rarity | Fighters |
|---|---|
| Common | Eri, Lemillion |
| Uncommon | Speed Guy, Yuji |
| Rare | Bakugo, Deku, Hellflame, Todoroki |
| Epic | All Might, Awakened Bakugo, Deku Awakened |
| Legendary | 100% Deku, Gojo Satoru, Sukuna |
| Mythic | ★ All Might (MODE), Gojo Satoru (Blindfold Off) |

## Ninja Village — Naruto (Silver altars) · 19

| Rarity | Fighters |
|---|---|
| Uncommon | Neji, Naruto (Pre-Timeskip), Sasuke (Pre-Timeskip) |
| Rare | Gaara, Rock Lee, Zabuza |
| Epic | 5Th Gate, Kakashi, Might Guy, Minato, Rock Lee Gates, Naruto (Timeskip), Sasuke (Timeskip) |
| Legendary | Itachi, Pain, Sage Mode |
| Mythic | 8Th Gate, Kcm Minato, ★ Madara |

## Pirate Bay — One Piece (Gold altars) · 13

| Rarity | Fighters |
|---|---|
| Rare | Law (Pre-Timeskip), Luffy (Pre-Timeskip), Sanji (Pre-Timeskip), Zoro (Pre-Timeskip), Snakeman |
| Epic | Ace, Kizaru, Sanji (Timeskip), Luffy (Timeskip), Zoro (Timeskip) |
| Legendary | Akainu, Shanks |
| Mythic | ★ Whitebeard |

## Walled City — Attack on Titan (Diamond altars) · 12

| Rarity | Fighters |
|---|---|
| Epic | Annie (Junior High), Erwin (Alt), Mikasa (Formal), Sasha, Sasha (Suit) |
| Legendary | Annie, Eren, Erwin, Mikasa |
| Mythic | Eren Post-time skip |
| Secret | ★ Attack Titan, Female Titan |

## Dragon Ball — the strongest universe, summons / Secret Rush / gifts only · 10

| Rarity | Fighters |
|---|---|
| Legendary | Broly, Buu Saga Goku, Goku, Majin Vegeta, Vegeta |
| Mythic | Goku Black, Lssj Broly, Ssjr, Vegito |
| Secret | Vegito Blue |

## Guardians and bosses

- **Blossom:** Lemillion, Deku, Bakugo, Todoroki, Deku Awakened; boss "Symbol of Peace" = All Might (MODE) ★
- **Ninja:** Neji, Gaara, Zabuza, Kakashi, Itachi; boss "The Shadow" = Madara ★
- **Pirate:** Luffy, Law, Zoro (Pre-Timeskip), Ace, Shanks; boss "The Emperor" = Whitebeard ★
- **Walled:** Sasha, Erwin, Mikasa, Eren (Post-Timeskip), Female Titan; boss "The Titan" = Attack Titan ★

## Mutations (`src/shared/MutationLook.lua`, `Config.Mutations`)

The fighter becomes a statue of the mutation (the grow-engine method: everything recoloured, face kept), with its own flame aura (Toolbox "Red Aura" pack, recoloured, scripts stripped).

| Mutation | Where | Income | Look |
|---|---|---|---|
| Golden | everywhere | ×2 | gold statue (GoldStatue texture), gold flame |
| Cursed | Blossom only | ×3 | deep purple, black limbs and hair; black flame, purple sparks |
| Sage | Ninja only | ×3 | orange, red limbs and hair; orange flame, red sparks |
| Haki | Pirate only | ×3 | fully black armament metal; black flame, red sparks |
| Titan | Walled only | ×3 | pale titan skin, red-muscle limbs; red-orange flame, steam |
| Diamond | everywhere | ×5 | blue ice statue, ice-blue flame |
| Rainbow | everywhere | ×10 | colour-cycling statue, rainbow flame |
| Huge | everywhere | ×25 | 2× size in its own colours, orange flame |

## Held back for updates (63 fighters)

- **JoJo (17):** a "Morioh" zone.
- **Bleach (23):** a "Soul Society" zone.
- **Fate (10)**
- **The rest of Dragon Ball (5):** Krillin, Gohan, Piccolo, Trunks, Caulifla.
- **Others (8):** Accel, Afro Samurai, Saitama, Tanjiro and more.

At roughly one new zone or event every 2 to 3 weeks, that fits the 3–4 month run.
