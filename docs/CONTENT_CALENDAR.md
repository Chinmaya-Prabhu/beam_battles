# Content calendar

What ships each week after launch, and the commands that run it. The LiveOps machinery is in
`docs/LIVEOPS.md`; this is the plan that feeds it.

## The weekly rhythm

| When (UTC) | What happens | How |
|---|---|---|
| **Saturday 17:00** | **Update day:** new content goes live (republish), a new code, the next event starts | Publish from Studio, then `push.py code …`, `push.py update …` for the following week |
| Saturday 17:00–18:00 | **Admin event:** you join a busy server and run something loud (free drops, Luck Storm) | Studio debug attributes don't work live; until an admin panel exists, schedule a `DoubleDrops` event for that hour |
| Friday 18:00 → Monday | Weekend boost event (Double Drops, Mutation Week, Golden Rush, Training Frenzy) | The default calendar does this by itself (`LiveOps.Order`) |
| Monday 00:00 | Weekly quests reset (5 new, a Legendary in the chest) | Automatic |
| Every hour, every 15 min, every 5 min | Luck Storm, Secret Rush, stall and market restock | Automatic |

The hub's **update board** (left of the spawn path) always counts down to the next Saturday 17:00 UTC. Name the
update on it the moment you know what's in it:

```bash
python3 tools/liveops/push.py update 2026-11-07T17:00 "SPIRIT TEMPLE" "Final Aizen awaits"
```

## Codes

Players type them in the **CODES** tile. Each works once per player. Ki and Cash scale with the player, so a
code is worth typing at any stage. Built into the game: `RELEASE` (Cash + Ki), `ANIMECLASH` (2x training
15 min), `FIRSTFIGHTER` (an Epic fighter). New ones go live without republishing:

```bash
python3 tools/liveops/push.py code SPIRIT boost cash --expires 2026-11-14T17:00
python3 tools/liveops/push.py code 1KLIKES legendary        # like milestones: no expiry
python3 tools/liveops/push.py uncode SPIRIT
```

Reward words: `cash`, `ki`, `boost`, `epic`, `legendary`, `mythic`. Rules of thumb: one code per update (expires
with the next one), one per like milestone (1K, 5K, 10K, 50K likes), a `mythic` only for big milestones.
Post every code in the group and on socials; that's what the codes are for.

## The first 8 weeks

Content still unused in the pack: Bleach 14 (plus 9 already in the Soul Society event), JoJo 9 (plus 8 in
Bizarre), Fate 10, other 8, Dragon Ball 5. That's enough for every week below without making new models.

| Week | Saturday update | Code | Event that week |
|---|---|---|---|
| **1** (launch) | Launch: 4 zones, Floor 2, rebirth, codes | `RELEASE` (built in) | Double Drops (launch weekend) |
| **2** | **Zone 5: Spirit Temple** (Bleach). Boss: Final Aizen. Guardians: Shinji, Starrk, Grimmjow, Ulquiorra, Yamamoto. Adds Gin, R1, R2, Shunsui to its drops | `SPIRIT` (boost + cash) | Soul Society Invasion |
| **3** | 4 JoJo fighters (Old Joseph, Jolyne, Stone Free, Kira); a new beam skin; **Colosseum ranked (beta)** | `BIZARRE` (ki + epic) | Mutation Week |
| **4** | **Zone 6: Dune Pyramids** (JoJo, Egypt arc). Boss: DIO (Awakened, leaves the Bizarre pool and becomes boss-exclusive). Guardians: Stand, Doppio, Stone Free Aura, Awakened Jolyne, Ger | `PYRAMID` (boost + cash) | Bizarre Adventure |
| **5** | 5 Fate fighters (Rin, Kiritsugu, Lancer, Shirou, Salter) at the hub and Blossom altars; Fate summon banner | `GRAIL` (legendary) | Golden Rush |
| **6** | **Zone 7: Ki Planet** (Dragon Ball). Boss: Vegito Blue (leaves summons, becomes boss-exclusive). Guardians: Krillin, Piccolo, Gohan, Trunks, Caulifla | `KIPLANET` (boost + ki) | Training Frenzy |
| **7** | Ranked season 1 rewards; Fate Legendaries (Archer Emiya, Iskandar, Saber) and Gilgamesh (Mythic) | `SEASON1` (mythic) | Double Drops |
| **8** | The "other" set (Tanjiro, Accel, Afro Samurai, Saitama as a Mythic), Rikka, Chika, Kazuma; Floor 3 or a new base feature | `HERO` (cash + legendary) | Mutation Week |

From week 9 the rotation repeats with new events and the next zones; plan them by then.

## Zones 5–7: Power gates (first pass)

They continue the curve from Walled City (boss 3B Power) at the rebirth stage, where players wear Turtle Shell
(x800, rebirth 1), Saiyan Armor (x1600, rebirth 3) and Ultra Instinct (x5000, rebirth 5) weights.

| Zone | Guardians | Boss | Needs |
|---|---|---|---|
| Spirit Temple | 8B → 40B | 60B | about rebirth 1–2 |
| Dune Pyramids | 150B → 800B | 1.2T | about rebirth 3 |
| Ki Planet | 3T → 15T | 25T | about rebirth 5 |

Tune these with the pacing model before each zone ships (the same one used for zones 1–4). Each new zone
also needs: its altar tier (one above Celestial), its bot Power, two training stations, a gear stall, 5 drop
altars, a quest card and a map card (both automatic from `Config.Zones`).

## Before each update (checklist)

1. Build and test the content in Studio (play it as a new and as a returning player).
2. Run `bash tests/run_rules.sh`.
3. Publish on Saturday at 17:00 UTC.
4. `push.py code …` for the update's code, then announce it.
5. `push.py update <next Saturday> "<next title>" "<teaser>"` so the board shows what's next.
6. Join a server for the admin hour.
