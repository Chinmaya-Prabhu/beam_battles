# Fighters kept for later

Cleaned-up source models that are NOT in the game yet. Move a file back to `tools/pack/custom/` and add it to
`roster.json` / `launch.json` / `names.json` to ship it (then `python3 tools/pack/gen_registry.py` and
`python3 tools/pack/strip_pack.py`).

## The ten Demon Slayer fighters (the Upper Moons set, `split_models.py` cuts them out of upper_moon.rbxm)

Rarity should follow rank in the anime (a lower number is stronger), so the order is:

| Fighter | Rank | Suggested rarity |
|---|---|---|
| Kokushibo | Upper Moon 1 | Mythic |
| Douma | Upper Moon 2 | Legendary (the top one) |
| Akaza | Upper Moon 3 | Legendary (a little below Douma) |
| Hantengu | Upper Moon 4 | Epic |
| Gyokko | Upper Moon 5 | Epic |
| Daki, Gyutaro | Upper Moon 6 | Epic / Rare |
| Nakime | Lower/Upper Moon 4 | Rare |
| Kaigaku | Upper Moon 6 (replacement) | Rare |
| Tanjiro Demon King | his own form | Mythic |

Series key `Demon Slayer`, shown to players as "Moon Demons". Mihawk-style R15 models (Daki) go through the same pipeline.

## The eight Hashira (`split_assets.py` cuts them out of assets/Hashiras.rbxm)

Sanemi, Rengoku, Iguro, Muichiro, Shinobu, Giyu, Gyomei, Mitsuri. Same `Demon Slayer` series as the Upper Moons:
together with them (and Tanjiro) they make a whole Demon Slayer zone. Their pieces were welded by runtime "Weld"
scripts, so strip_pack's adopt_orphans welds them to the nearest limb: check them in the gallery before shipping.
