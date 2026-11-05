-- The toy-brick palette (docs/WORLD_PLAN.md §9). Classic brick colours, then each zone's set.
-- Every world colour comes from here. Sets give tones as ramps where volume matters:
-- leaves/blossom/roof = { dark, mid, light[, highlight] }, so canopies and roofs shade from bottom to top.
-- Weighted lists (grass, stone, path) repeat the common tone.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Bricks = {}

Bricks.C = {
	white = rgb(242, 240, 232),
	pureWhite = rgb(255, 255, 255),
	lightGray = rgb(163, 166, 168),
	gray = rgb(130, 133, 134),
	darkGray = rgb(96, 98, 96),
	black = rgb(38, 38, 44),
	red = rgb(206, 38, 28),
	vermilion = rgb(222, 64, 36),
	darkRed = rgb(120, 22, 22),
	coral = rgb(255, 112, 128),
	orange = rgb(250, 136, 30),
	darkOrange = rgb(176, 86, 12),
	lightOrange = rgb(250, 190, 90),
	yellow = rgb(242, 205, 55),
	lightYellow = rgb(255, 236, 140),
	gold = rgb(240, 180, 40),
	tan = rgb(222, 198, 150),
	lightTan = rgb(236, 218, 180),
	darkTan = rgb(150, 136, 110),
	cream = rgb(246, 236, 210),
	nougat = rgb(200, 140, 100),
	mediumNougat = rgb(166, 120, 80),
	brown = rgb(104, 60, 32),
	darkBrown = rgb(62, 38, 20),
	grass = rgb(84, 170, 76),
	grassDark = rgb(60, 140, 64),
	grassLight = rgb(118, 192, 92),
	leafDark = rgb(38, 110, 62),
	leaf = rgb(76, 156, 70),
	leafLight = rgb(130, 196, 88),
	green = rgb(35, 120, 65),
	darkGreen = rgb(24, 70, 50),
	olive = rgb(130, 140, 80),
	sandGreen = rgb(150, 180, 160),
	azure = rgb(54, 174, 191),
	darkAzure = rgb(14, 120, 180),
	slate = rgb(70, 86, 110),
	slateLight = rgb(100, 118, 142),
	blue = rgb(20, 90, 190),
	mediumBlue = rgb(90, 147, 219),
	darkBlue = rgb(16, 46, 92),
	pinkDark = rgb(204, 96, 150),
	pink = rgb(240, 142, 182),
	pinkLight = rgb(255, 188, 214),
	pinkHighlight = rgb(255, 228, 238),
	magenta = rgb(146, 57, 120),
	lavender = rgb(205, 180, 230),
	purple = rgb(100, 60, 170),
	water = rgb(64, 180, 225),
	waterDeep = rgb(28, 120, 190),
}

local C = Bricks.C

-- Zone sets. Ground is ONE colour (grass, lawn): flat and calm, so the fighters stand out.
-- post = building frames, plaster = walls, roof = tile ramp, trim = eaves and accents.
Bricks.Zones = {
	Hub = {
		grass = { C.grass },
		dirt = { C.mediumNougat, C.brown },
		stone = { C.lightGray, C.lightGray, C.gray, C.white },
		path = { C.tan, C.tan, C.lightTan, C.darkTan },
		wood = { C.brown, C.mediumNougat },
		accent = C.red,
		accent2 = C.gold,
		post = C.vermilion,
		roof = { C.darkRed, C.red, C.vermilion },
		trim = C.black,
		plaster = C.cream,
		leaves = { C.leafDark, C.leaf, C.leafLight },
		blossom = { C.pinkDark, C.pink, C.pinkLight, C.pinkHighlight },
	},
	-- Blossom Academy, an anime school campus (docs/WORLD_PLAN.md §4.1): grey studded paving, pale stone
	-- cliffs, cream walls with slate-blue frames, teal roofs. Nothing red-and-gold (that is the hub).
	Blossom = {
		grass = { rgb(172, 168, 160) },
		lawn = { rgb(96, 176, 84) },
		dirt = { rgb(196, 186, 170), rgb(150, 140, 128) },
		stone = { rgb(214, 214, 210), rgb(214, 214, 210), rgb(190, 192, 192), C.white },
		path = { rgb(236, 206, 196), rgb(226, 190, 180), rgb(244, 222, 212), rgb(150, 110, 100) },
		wood = { rgb(214, 170, 110), rgb(184, 140, 90) },
		accent = rgb(70, 96, 130),
		accent2 = rgb(70, 150, 150),
		post = rgb(70, 96, 130),
		roof = { rgb(40, 110, 116), rgb(70, 150, 150), rgb(96, 176, 172) },
		trim = rgb(44, 62, 90),
		plaster = rgb(246, 238, 220),
		leaves = { C.leafDark, C.leaf, C.leafLight },
		blossom = { C.pinkDark, C.pink, C.pinkLight, C.pinkHighlight },
	},
	Ninja = {
		grass = { C.green },
		dirt = { C.brown, C.darkBrown },
		stone = { C.darkGray, C.gray, C.darkGray },
		path = { C.darkTan, C.tan, C.darkTan, C.brown },
		wood = { C.brown, C.darkBrown },
		accent = C.orange,
		accent2 = C.red,
		post = C.darkBrown,
		roof = { C.black, C.darkGray, C.darkGray },
		trim = C.black,
		plaster = C.tan,
		leaves = { C.darkGreen, C.green, C.leaf },
		blossom = { C.darkOrange, C.orange, C.lightOrange, C.lightYellow },
	},
	Pirate = {
		-- Golden sand: the plain tans wash out to white under the noon sun.
		grass = { rgb(232, 198, 132) },
		dirt = { C.nougat, C.mediumNougat },
		stone = { C.lightGray, C.white, C.sandGreen },
		path = { C.mediumNougat, C.nougat, C.mediumNougat, C.brown },
		wood = { C.mediumNougat, C.brown },
		accent = C.red,
		accent2 = C.white,
		post = C.brown,
		roof = { C.darkRed, C.red, C.red },
		trim = C.darkBrown,
		plaster = C.white,
		leaves = { C.leafDark, C.leaf, C.leafLight },
		blossom = { C.coral, C.yellow, C.pinkLight, C.pureWhite },
	},
	Walled = {
		grass = { C.olive },
		dirt = { C.darkTan, C.mediumNougat },
		stone = { C.lightGray, C.gray, C.darkTan, C.lightGray },
		path = { C.lightGray, C.lightGray, C.lightGray, C.gray }, -- (one calm stone, not a grey checkerboard)
		wood = { C.brown, C.darkBrown },
		accent = C.green,
		accent2 = C.gold,
		post = C.darkBrown,
		roof = { C.darkRed, C.red, C.red },
		trim = C.darkGray,
		plaster = C.lightTan,
		leaves = { C.darkGreen, C.green, C.olive },
		blossom = { C.lavender, C.white, C.lavender, C.pureWhite },
	},
}

-- Balance (60/30/10): the big surfaces of every place (ground, cliffs, paths, walls, roofs, trees) are
-- deeper and a little softer (rich, not grey), so the bright colours are kept for what you play with: altars, gates,
-- portals, pads, the fighters and their auras (those use `accent`/`accent2` or the C colours directly).
local MUTED = { "grass", "lawn", "dirt", "stone", "path", "wood", "roof", "plaster", "leaves", "blossom", "post" }
local function mute(color)
	local h, sat, v = color:ToHSV()
	return Color3.fromHSV(h, sat * 0.78, v * 0.82)
end
for _, zoneSet in Bricks.Zones do
	for _, key in MUTED do
		local value = zoneSet[key]
		if typeof(value) == "Color3" then
			zoneSet[key] = mute(value)
		elseif type(value) == "table" then
			for i, c in value do
				value[i] = mute(c)
			end
		end
	end
end
-- Accents (gates, trims, rails, banners) keep their colour but lose the neon edge.
for _, zoneSet in Bricks.Zones do
	for _, key in { "accent", "accent2" } do
		if typeof(zoneSet[key]) == "Color3" then
			local h, sat, v = zoneSet[key]:ToHSV()
			zoneSet[key] = Color3.fromHSV(h, sat * 0.85, v * 0.88)
		end
	end
end
Bricks.mute = mute

return Bricks
