# Anime Clash

PvP click battles for anime fighters that drop onto studded tables. Plan: [docs/GAME_PLAN.md](docs/GAME_PLAN.md). Roster: [docs/ROSTER.md](docs/ROSTER.md).

## Run it

1. Serve the code: `~/.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo serve default.project.json --port 34961`
2. Open `AnimeClash.rbxlx` in Studio and connect the Rojo plugin to `localhost:34961`.
3. Press Play.

Rebuild the place file: `~/.aftman/tool-storage/rojo-rbx/rojo/7.7.1/rojo build default.project.json -o AnimeClash.rbxlx`

**Fighter gallery (Studio only):** run `workspace:SetAttribute('FighterGallery', true)` in the command bar (Edit mode, use the Run button), then Play. All fighters stand in rows north of the map (around z = -150 to -240).

## The fighter pack

`anime1.rbxm` is the source pack (`anime2.rbxm` is an identical copy). The game never loads it directly:

```bash
python3 tools/pack/inspect_pack.py anime1.rbxm   # roster.json + docs/ROSTER.md (rarities live in this script)
python3 tools/pack/strip_pack.py anime1.rbxm     # assets/models/Fighters.rbxm: look only, no scripts/sounds/anims
python3 tools/pack/gen_registry.py               # src/shared/Fighters.lua
```

Rojo maps `assets/models/Fighters.rbxm` to `ReplicatedStorage.Assets.Fighters`. `src/shared/FighterModels.lua` clones, scales, poses (by solving the rig's joints in code) and anchors a fighter for display.

## Checks

```bash
~/.aftman/tool-storage/JohnnyMorganz/StyLua/0.20.0/StyLua src
~/.aftman/tool-storage/Kampfkarren/selene/0.27.1/selene src
```
