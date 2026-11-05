-- Beam skins (docs/MONETIZATION.md): how a player's beam looks in a clash. Cosmetic only, never stronger.
-- Each is a gamepass (shared/Products.lua: key "Beam" .. key, `beam = key`, with the price); the owner equips one in the shop's BEAMS tab and
-- the server publishes it as the player attribute BeamSkin. client/ClashBeams.lua draws them.
--   core    the white-hot centre
--   glow    the wide soft outer layer
--   strand  the two energy strands twisting round the beam
--   spark   particles shed along the beam and at the hands
--   style   "rainbow" (colours cycle), "lightning" (jagged flicker), "fire" (flame particles), "dark"
--   layers  textured beam layers: { texture, width (x the beam width), scroll speed, transparency, colour }
--   Paid skins also get the impact burst and flare at the hands (Assets.BeamVFX) and the twisting strands;
--   the default beam is one plain layer, so any skin is an obvious upgrade.
-- No skin (nil) uses the side's colour (blue or red).
local BeamSkins = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Beam textures (from the free Toolbox "beam vfx pack" by TheOceanWanderer: plain images, no scripts).
-- White-ish bitmaps; a Beam's Color tints them.
local T = {
	ENERGY = "rbxassetid://12781850191",
	SWIRL = "rbxassetid://12781880888",
	WAVE = "rbxassetid://12781780964",
	CRACKLE = "rbxassetid://12781873863",
	BLOBS = "rbxassetid://12781881514",
	BOLT = "rbxassetid://12781820353",
	ZIGZAG = "rbxassetid://12781880233",
	SQUIGGLE = "rbxassetid://12781816988",
	PURPLE = "rbxassetid://12781741946",
	PURPLE2 = "rbxassetid://12781743000",
	HELIX = "rbxassetid://12781768773",
	RIPPLE = "rbxassetid://12781834839",
	BAR = "rbxassetid://12781852245",
	SHRED = "rbxassetid://12781783939",
	STREAKS = "rbxassetid://12781883661",
}
BeamSkins.Textures = T

BeamSkins.List = {
	{
		key = "Kamehameha",
		name = "Turtle Wave",
		core = rgb(235, 250, 255),
		glow = rgb(60, 180, 255),
		strand = rgb(170, 235, 255),
		spark = rgb(140, 220, 255),
		layers = {
			{ T.ENERGY, 2.6, 1.6, 0.25, "glow" },
			{ T.SWIRL, 1.8, -2.4, 0.15, "strand" },
			{ T.WAVE, 3.4, 1.1, 0.45, "glow" },
		},
	},
	{
		key = "Hellfire",
		name = "Hellfire",
		core = rgb(255, 235, 150),
		glow = rgb(230, 30, 10),
		strand = rgb(255, 150, 20),
		spark = rgb(255, 140, 40),
		style = "fire",
		layers = {
			{ T.CRACKLE, 2.8, 2.2, 0.15, "glow" },
			{ T.BLOBS, 3.6, 1.4, 0.3, "strand" },
			{ T.ENERGY, 1.6, 3, 0.1, "core" },
		},
	},
	{
		key = "Chidori",
		name = "Thousand Birds",
		core = rgb(255, 255, 255),
		glow = rgb(130, 120, 255),
		strand = rgb(210, 220, 255),
		spark = rgb(190, 200, 255),
		style = "lightning",
		layers = {
			{ T.BOLT, 2.4, 3.5, 0.05, "core" },
			{ T.ZIGZAG, 3.2, -2.8, 0.2, "glow" },
			{ T.SQUIGGLE, 2, 4.2, 0.1, "strand" },
		},
	},
	{
		key = "Cursed",
		name = "Cursed Energy",
		core = rgb(255, 210, 255),
		glow = rgb(120, 20, 180),
		strand = rgb(25, 0, 35),
		spark = rgb(190, 60, 255),
		style = "dark",
		layers = {
			{ T.PURPLE, 3, 1.5, 0.15, "glow" },
			{ T.HELIX, 2.4, -2, 0.2, "strand" },
			{ T.PURPLE2, 2, 2.6, 0.2, "core" },
		},
	},
	{
		key = "GoldenGod",
		name = "Golden God",
		core = rgb(255, 252, 225),
		glow = rgb(255, 185, 30),
		strand = rgb(255, 235, 130),
		spark = rgb(255, 215, 90),
		layers = {
			{ T.BAR, 2.2, 2.4, 0.05, "core" },
			{ T.RIPPLE, 3.2, 1.3, 0.2, "glow" },
			{ T.STREAKS, 3.8, -1.8, 0.35, "strand" },
		},
	},
	{
		key = "Prism",
		name = "Prism Rainbow",
		core = rgb(255, 255, 255),
		glow = rgb(255, 80, 80),
		strand = rgb(255, 255, 255),
		spark = rgb(255, 255, 255),
		style = "rainbow",
		layers = {
			{ T.HELIX, 2.8, 2, 0.1, "glow" },
			{ T.SHRED, 3.4, -1.6, 0.25, "strand" },
			{ T.ENERGY, 1.8, 3, 0.1, "core" },
		},
	},
}

BeamSkins.ByKey = {}
for _, s in BeamSkins.List do
	BeamSkins.ByKey[s.key] = s
end

-- The default look for a side: built from the side colour.
function BeamSkins.side(color)
	return {
		core = color:Lerp(Color3.new(1, 1, 1), 0.75),
		glow = color,
		strand = color:Lerp(Color3.new(1, 1, 1), 0.4),
		spark = color:Lerp(Color3.new(1, 1, 1), 0.5),
		layers = { { T.ENERGY, 2, 1.2, 0.35, "glow" } },
		plain = true,
	}
end

-- The pass key for a skin (Products.Passes entries named "Beam" .. key).
function BeamSkins.passKey(key)
	return "Beam" .. key
end

return BeamSkins
