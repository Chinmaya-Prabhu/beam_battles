-- The dances (clips Dance* in shared/Clips.lua, authored in tools/blender/r15_studio.py): played now and then
-- by fighters on show (client/FighterAnimator.lua), by a guardian after it wins (server ClashService), and all
-- together at a base's dance party (server PlotService "Party").
local Dances = {}

Dances.List = {
	"DanceShuffle",
	"DanceKitty",
	"DanceFunk",
	"DanceBuggin",
	"DanceSahur",
	"DanceSwag",
	"DanceAfro",
	"DanceHeel",
}

-- The idle a fighter on show stands in, by rarity: Epic and Legendary stand proud, Mythic and Secret float.
local IDLES = { Epic = "IdleProud", Legendary = "IdleProud", Mythic = "IdleFloat", Secret = "IdleFloat" }
function Dances.idleFor(rarity)
	return IDLES[rarity] or "Idle"
end

return Dances
