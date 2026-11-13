-- Every fighter's aura, in its anime's style (like Anime Dice's): it wraps the whole body rather than
-- rising off it. A STYLE is a few particle layers on the fighter's HumanoidRootPart (emitting from its
-- volume, sized to the fighter); each fighter has a style and colours from its series (SERIES) or its own
-- line (BY_KEY). Rarity sets how much of it there is (STRENGTH); a mutation keeps the shape and swaps the
-- colours (MUTATION). Fighters also get an outline (client/FighterOutline.lua).
-- Textures are from the Toolbox aura pack in Assets.AuraVFX (scripts stripped) and Roblox's built-ins.
local FighterAura = {}

local TEX = {
	blaze = "rbxassetid://250186345", -- the Super Saiyan flame
	spike = "rbxassetid://7451697448", -- a jagged flame tongue (white: it takes any tint)
	wisp = "rbxassetid://10337713824", -- a soft white wisp
	-- The old bolt and cloud images were dark: a colour only multiplies a texture, so every lightning bolt and
	-- steam cloud came out black whatever its fighter's colours. Both now use the white textures.
	bolt = "rbxassetid://7451697448",
	cloud = "rbxassetid://10337713824",
	orb = "rbxassetid://4509687978",
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function nums(...)
	local points, args = {}, { ... }
	for i = 1, #args, 2 do
		table.insert(points, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(points)
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, rgb(255, 200, 40)),
	ColorSequenceKeypoint.new(0.4, rgb(80, 230, 80)),
	ColorSequenceKeypoint.new(0.6, rgb(60, 160, 255)),
	ColorSequenceKeypoint.new(0.8, rgb(170, 80, 255)),
	ColorSequenceKeypoint.new(1, rgb(255, 60, 160)),
})

-- ------------------------------------------------------------------ layers
-- Each builds one emitter: (k = fighter scale, c = main colour, a = accent colour, n = amount 0..1).
-- ZOffset < 0 draws it behind the body, so the fighter reads in front of its own aura.
local LAYERS = {}

-- A colour sequence from white-hot (the core) to `c` at the tips, or `c` itself for rainbow/dark ones.
local function hot(c)
	if typeof(c) ~= "Color3" or math.max(c.R, c.G, c.B) < 0.25 then
		return c
	end
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c:Lerp(Color3.new(1, 1, 1), 0.35)),
		ColorSequenceKeypoint.new(0.25, c),
		ColorSequenceKeypoint.new(1, c),
	})
end

-- The big flame round the whole body (Super Saiyan): strong and sharp behind, a thinner sheet in front.
function LAYERS.blaze(k, c, _, n)
	return {
		{
			Texture = TEX.blaze,
			Size = nums(0, 6.5 * k, 1, 8.5 * k),
			Transparency = nums(0, 1, 0.12, 0.05, 0.7, 0.3, 1, 1),
			Lifetime = NumberRange.new(0.3, 0.5),
			Rate = 22 * n,
			Speed = NumberRange.new(1.5 * k, 3 * k),
			Rotation = NumberRange.new(-12, 12),
			ZOffset = -1.5 * k,
			Color = hot(c),
			LockedToPart = true,
			LightEmission = 0.35, -- mostly solid colour: a glow-only flame washes out to white in daylight
		},
		{
			Texture = TEX.blaze,
			Size = nums(0, 5.5 * k, 1, 6.5 * k),
			Transparency = nums(0, 1, 0.2, 0.55, 1, 1),
			Lifetime = NumberRange.new(0.25, 0.4),
			Rate = 10 * n,
			Speed = NumberRange.new(1 * k, 2 * k),
			Rotation = NumberRange.new(-10, 10),
			ZOffset = 0.5 * k,
			Color = hot(c),
			LockedToPart = true,
			LightEmission = 0.5,
		},
	}
end

-- Jagged flame tongues shooting up off the body (the Super Saiyan flicker): short and fast, never a pillar.
function LAYERS.spikes(k, c, _, n)
	return {
		{
			Texture = TEX.spike,
			Size = nums(0, 2.2 * k, 0.5, 3.2 * k, 1, 1.5 * k),
			Transparency = nums(0, 0.1, 0.6, 0.3, 1, 1),
			Lifetime = NumberRange.new(0.18, 0.32),
			Rate = 26 * n,
			Speed = NumberRange.new(7 * k, 11 * k),
			SpreadAngle = Vector2.new(22, 22),
			Color = hot(c),
			LightEmission = 0.6,
		},
	}
end

-- Licking flames up the body.
function LAYERS.fire(k, c, a, n)
	return {
		{
			Texture = TEX.fire,
			Size = nums(0, 2.6 * k, 1, 0.4 * k),
			Transparency = nums(0, 0.2, 1, 1),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 45 * n,
			Speed = NumberRange.new(2 * k, 5 * k),
			SpreadAngle = Vector2.new(12, 12),
			Acceleration = Vector3.new(0, 4 * k, 0),
			RotSpeed = NumberRange.new(-60, 60),
			Rotation = NumberRange.new(0, 360),
			Color = (typeof(a) == "Color3" and typeof(c) == "Color3") and ColorSequence.new(a, c) or c,
			LightEmission = 0.65, -- (the flame image has dark edges: low glow turned them into brown smoke)
		},
	}
end

-- A cloud hanging round the fighter (black for the dark styles), with a glow inside it.
function LAYERS.cloud(k, c, a, n)
	return {
		{
			Texture = TEX.cloud,
			Size = nums(0, 4 * k, 1, 6.5 * k),
			Transparency = nums(0, 1, 0.25, 0.25, 1, 1),
			Lifetime = NumberRange.new(1, 1.6),
			Rate = 9 * n,
			Speed = NumberRange.new(0.3 * k, 1 * k),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-25, 25),
			ZOffset = -1.5 * k,
			Color = c,
			LightEmission = 0.55, -- a bright cloud glows (no grey haze); a black one is set to 0 in build()
		},
		{
			Texture = TEX.orb,
			Size = nums(0, 6 * k, 1, 7 * k),
			Transparency = nums(0, 1, 0.3, 0.55, 1, 1),
			Lifetime = NumberRange.new(1, 1.4),
			Rate = 2.5 * n,
			Speed = NumberRange.new(0, 0),
			ZOffset = -2.5 * k,
			Color = a,
			LockedToPart = true,
			LightEmission = 1,
		},
	}
end

-- Energy wisps curling round the body.
function LAYERS.wisps(k, c, _, n)
	return {
		{
			Texture = TEX.wisp,
			Size = nums(0, 2.5 * k, 1, 4.5 * k),
			Transparency = nums(0, 1, 0.2, 0.35, 1, 1),
			Lifetime = NumberRange.new(0.7, 1.1),
			Rate = 10 * n,
			Speed = NumberRange.new(0.5 * k, 1.5 * k),
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Color = c,
			LightEmission = 0.45,
		},
	}
end

-- Crackling lightning on the body.
function LAYERS.bolts(k, _, a, n)
	return {
		{
			Texture = TEX.bolt,
			Size = nums(0, 3.4 * k, 1, 4 * k),
			Lifetime = NumberRange.new(0.06, 0.12),
			Rate = 12 * n,
			Brightness = 2,
			Speed = NumberRange.new(0, 0),
			Rotation = NumberRange.new(0, 360),
			Color = a,
			LockedToPart = true,
			LightEmission = 1,
		},
	}
end

-- A soft halo behind the fighter.
function LAYERS.halo(k, c, _, n)
	return {
		{
			Texture = TEX.orb,
			Size = nums(0, 5.5 * k, 1, 6 * k),
			Transparency = nums(0, 1, 0.3, 0.45, 1, 1),
			Lifetime = NumberRange.new(1, 1.4),
			Rate = 2.5 * math.max(n, 0.5),
			Speed = NumberRange.new(0, 0),
			ZOffset = -2.5 * k,
			Color = c,
			LockedToPart = true,
			LightEmission = 0.5,
		},
	}
end

-- Twinkles drifting off the body.
function LAYERS.sparkles(k, _, a, n)
	return {
		{
			Texture = TEX.sparkle,
			Size = nums(0, 0.6 * k, 1, 0),
			Lifetime = NumberRange.new(0.8, 1.4),
			Rate = 14 * n,
			Speed = NumberRange.new(1 * k, 2.5 * k),
			SpreadAngle = Vector2.new(180, 180),
			Color = a,
			LightEmission = 1,
		},
	}
end

-- ------------------------------------------------------------------ styles
-- Layers in order of importance: a weak fighter shows the first, a strong one all of them.
local STYLES = {
	saiyan = { "blaze", "spikes", "bolts", "halo" }, -- Dragon Ball
	fire = { "fire", "halo", "blaze" }, -- flame users
	dark = { "cloud", "bolts", "wisps" }, -- curses, hollows, Haki, darkness
	energy = { "wisps", "halo", "bolts" }, -- chakra, cursed energy, quirks
	spirit = { "blaze", "wisps", "sparkles" }, -- reiatsu, spirit energy
	steam = { "cloud", "fire", "halo" }, -- titans
	magic = { "sparkles", "halo", "wisps" }, -- servants, mages, the cute ones
	lightning = { "bolts", "wisps", "halo" }, -- lightning users
}

-- { style, main colour, accent colour }
local GOLD, WHITE = rgb(255, 205, 50), rgb(255, 250, 230)
local SERIES = {
	DBZ = { "saiyan", GOLD, rgb(140, 220, 255) },
	NARUTO = { "energy", rgb(255, 140, 30), rgb(255, 230, 150) },
	["One Piece"] = { "dark", rgb(20, 8, 12), rgb(255, 40, 40) },
	Bleach = { "spirit", rgb(120, 200, 255), WHITE },
	JJK = { "energy", rgb(70, 130, 255), rgb(200, 230, 255) },
	JOJO = { "energy", rgb(170, 70, 255), rgb(255, 200, 255) },
	["My Hero Academia"] = { "lightning", rgb(80, 255, 120), rgb(190, 255, 170) },
	AOT = { "steam", rgb(235, 230, 225), rgb(255, 130, 50) },
	HXH = { "energy", rgb(90, 220, 140), WHITE },
	FATE = { "magic", GOLD, WHITE },
	YYH = { "spirit", rgb(90, 160, 255), WHITE },
	["Fairy Tail"] = { "fire", rgb(255, 90, 20), rgb(255, 220, 120) },
	OTHER = { "magic", rgb(255, 150, 210), WHITE },
	["Demon Slayer"] = { "spirit", rgb(60, 140, 255), WHITE }, -- (water breathing; each one has their own below)
}
local RED, BLACK, BLUE, PURPLE = rgb(255, 40, 40), rgb(14, 6, 18), rgb(70, 160, 255), rgb(160, 60, 255)
local BY_KEY = {
	-- Dragon Ball
	Vegeta = { "saiyan", BLUE, WHITE },
	VegitoBlue = { "saiyan", BLUE, WHITE },
	Piccolo = { "energy", rgb(120, 255, 90), WHITE },
	Krillin = { "energy", rgb(255, 230, 140), WHITE },
	Broly = { "saiyan", rgb(110, 255, 90), WHITE },
	LssjBroly = { "saiyan", rgb(110, 255, 90), rgb(200, 255, 170) },
	GokuBlackNew = { "saiyan", rgb(255, 90, 190), rgb(255, 200, 240) },
	Ssjr = { "saiyan", rgb(255, 90, 190), rgb(255, 200, 240) },
	MajinVegeta = { "saiyan", GOLD, PURPLE },
	-- Naruto
	Ptssasuke = { "lightning", BLUE, WHITE },
	Tssasuke = { "dark", BLACK, PURPLE },
	Kakashi = { "lightning", BLUE, WHITE },
	Minato = { "lightning", GOLD, WHITE },
	KcmMinato = { "saiyan", GOLD, WHITE },
	Tsnaruto = { "saiyan", rgb(255, 150, 30), GOLD },
	SageMode = { "saiyan", rgb(255, 150, 30), rgb(255, 60, 30) },
	Itachi = { "dark", BLACK, RED },
	Madara = { "dark", BLACK, BLUE },
	Pain = { "energy", PURPLE, WHITE },
	Gaara = { "steam", rgb(220, 180, 110), rgb(255, 220, 150) },
	Zabuza = { "steam", rgb(230, 235, 240), WHITE },
	Neji = { "spirit", rgb(220, 230, 255), WHITE },
	RockLee = { "energy", rgb(80, 255, 120), WHITE },
	RockLeeGates = { "fire", rgb(80, 255, 120), WHITE },
	MightGuy = { "fire", rgb(80, 255, 120), WHITE },
	["5ThGate"] = { "fire", rgb(80, 255, 120), WHITE },
	["8ThGate"] = { "fire", RED, rgb(255, 170, 120) },
	-- One Piece
	Ace = { "fire", rgb(255, 110, 20), GOLD },
	Akainu = { "fire", rgb(255, 50, 10), rgb(255, 160, 60) },
	Kizaru = { "magic", GOLD, WHITE },
	Ptslaw = { "energy", rgb(90, 160, 255), WHITE },
	Snakeman = { "steam", rgb(255, 120, 190), WHITE },
	Tsluffy = { "steam", rgb(255, 150, 170), WHITE },
	-- Bleach
	Ichigo = { "dark", BLACK, RED },
	HollowIchigo = { "dark", BLACK, RED },
	Mugetsu = { "dark", BLACK, RED },
	Vasto = { "dark", BLACK, RED },
	Byakuya = { "magic", rgb(255, 150, 200), WHITE },
	Yamamoto = { "fire", rgb(255, 90, 20), GOLD },
	Aizen = { "energy", PURPLE, WHITE },
	FinalAizen = { "energy", PURPLE, WHITE },
	Ulq = { "dark", BLACK, rgb(80, 255, 140) },
	Grimmjow = { "spirit", rgb(60, 140, 255), WHITE },
	Yoruichi = { "lightning", WHITE, rgb(200, 220, 255) },
	ShunkoYoruichi = { "lightning", WHITE, rgb(200, 220, 255) },
	Gin = { "magic", rgb(200, 230, 255), WHITE },
	-- Jujutsu Kaisen
	GojoSatoru = { "energy", PURPLE, rgb(225, 180, 255) }, -- Hollow Purple
	GojoSatoruBlindfoldOff = { "energy", PURPLE, rgb(225, 180, 255) },
	Sukuna = { "dark", BLACK, RED },
	Yuji = { "lightning", RED, rgb(20, 0, 0) },
	-- JoJo
	Dio = { "energy", GOLD, WHITE },
	DioAwakened = { "energy", GOLD, WHITE },
	Giorno = { "magic", GOLD, WHITE },
	Ger = { "magic", GOLD, WHITE },
	KillerQueen = { "energy", rgb(255, 120, 200), WHITE },
	KiraYoshikage = { "energy", rgb(255, 120, 200), WHITE },
	-- My Hero Academia
	Bakugo = { "fire", rgb(255, 140, 30), GOLD },
	AwakenedBakugo = { "fire", rgb(255, 140, 30), GOLD },
	Todoroki = { "fire", rgb(255, 60, 30), rgb(160, 220, 255) },
	Hellflame = { "fire", rgb(255, 90, 20), GOLD },
	AllMight = { "saiyan", GOLD, WHITE },
	AllMightMode = { "saiyan", GOLD, WHITE },
	Eri = { "magic", GOLD, WHITE },
	Lemillion = { "magic", GOLD, WHITE },
	-- Attack on Titan: the titans burn
	AttackTitan = { "steam", rgb(235, 230, 225), rgb(255, 90, 30) },
	FemaleTitan = { "steam", rgb(235, 230, 225), rgb(255, 90, 30) },
	-- Hunter x Hunter
	Killua = { "lightning", BLUE, WHITE },
	KilluaGodspeed = { "lightning", BLUE, WHITE },
	AdultGon = { "saiyan", rgb(255, 230, 100), WHITE },
	Hisoka = { "energy", rgb(255, 90, 190), WHITE },
	Illumi = { "dark", BLACK, PURPLE },
	IllumiAwakened = { "dark", BLACK, PURPLE },
	-- Fate
	Lancer = { "energy", RED, WHITE },
	LancerMode = { "energy", RED, WHITE },
	ArcherEmiya = { "energy", RED, WHITE },
	Rin = { "magic", RED, WHITE },
	Kiritsugu = { "steam", rgb(160, 160, 170), WHITE },
	Salter = { "dark", BLACK, RED },
	-- Yu Yu Hakusho, Fairy Tail
	Hiei = { "fire", rgb(60, 20, 90), PURPLE },
	HieiJaganEye = { "fire", rgb(60, 20, 90), PURPLE },
	Gray = { "spirit", rgb(160, 220, 255), WHITE },
	GreyAwakening = { "spirit", rgb(160, 220, 255), WHITE },
	-- One Piece, the top of the sea
	Kaido = { "saiyan", rgb(50, 130, 255), rgb(255, 225, 90) }, -- Mythic: dragon flame and thunder
	BigMom = { "fire", rgb(255, 70, 160), rgb(255, 230, 120) }, -- Mythic: soul flame
	Mihawk = { "spirit", rgb(200, 30, 50), rgb(255, 215, 215) }, -- Legendary: a blade-sharp crimson
	Rayleigh = { "dark", BLACK, RED }, -- Legendary: Conqueror's Haki
	Fujitora = { "energy", rgb(160, 80, 255), rgb(225, 200, 255) }, -- Legendary: gravity
	Sengoku = { "saiyan", GOLD, rgb(255, 250, 220) }, -- Mythic: the golden Buddha
	Doflamingo = { "energy", rgb(255, 110, 190), rgb(255, 235, 245) }, -- Epic: pink strings
	-- Dragon Ball villains
	Frieza = { "energy", PURPLE, rgb(255, 205, 255) }, -- Legendary
	Beerus = { "dark", rgb(150, 40, 230), rgb(255, 120, 220) }, -- Secret: destruction, purple and pink
	CellMax = { "energy", rgb(110, 230, 70), rgb(225, 255, 120) }, -- Secret: bio-energy
	-- The daily-reward fighters
	Cell = { "energy", rgb(110, 230, 70), rgb(225, 255, 120) }, -- Epic
	Mahoraga = { "spirit", rgb(235, 235, 245), GOLD },
	GoldenFrieza = { "saiyan", GOLD, PURPLE },
	-- Others
	Saitama = { "halo", GOLD, WHITE },
	Accel = { "energy", WHITE, rgb(200, 220, 255) },
	AfroSamurai = { "dark", BLACK, RED },
	Rikka = { "energy", PURPLE, WHITE },
	RikkaAwakened = { "energy", PURPLE, WHITE },
	-- Added 2026-11-13 (docs/ROSTER_PLAN.md): the Hub's Demon Slayer core, each in their breathing's colours
	Tanjiro = { "fire", rgb(255, 120, 40), rgb(120, 200, 255) }, -- sun and water
	Zenitsu = { "lightning", rgb(255, 220, 50), WHITE },
	Inosuke = { "dark", rgb(70, 90, 140), rgb(200, 220, 255) }, -- beast
	Nezuko = { "fire", rgb(255, 90, 150), rgb(255, 200, 220) }, -- her blood demon art
	Shinobu = { "magic", rgb(190, 120, 255), rgb(255, 200, 240) }, -- insect
	Mitsuri = { "spirit", rgb(255, 120, 190), rgb(150, 255, 170) }, -- love
	Iguro = { "dark", rgb(140, 60, 200), WHITE }, -- serpent
	Giyu = { "spirit", rgb(60, 140, 255), WHITE }, -- water
	Sanemi = { "spirit", rgb(150, 230, 170), WHITE }, -- wind
	Rengoku = { "fire", rgb(255, 100, 20), GOLD }, -- flame
	Muichiro = { "steam", rgb(200, 230, 255), WHITE }, -- mist
	Gyomei = { "energy", rgb(190, 160, 110), WHITE }, -- stone
	Erza = { "magic", rgb(255, 70, 70), rgb(230, 230, 255) }, -- scarlet and her armour's silver
	-- The Walled City: soldiers in energy, titans in steam
	Sasha = { "energy", rgb(190, 140, 90), WHITE },
	Mikasa = { "energy", rgb(220, 40, 60), WHITE },
	Erwin = { "energy", GOLD, WHITE },
	Levi = { "energy", rgb(120, 150, 190), WHITE },
	ArmoredTitan = { "steam", rgb(220, 190, 120), rgb(255, 140, 50) },
	BeastTitan = { "steam", rgb(200, 170, 130), rgb(255, 140, 60) },
	JawTitan = { "steam", rgb(235, 225, 200), GOLD },
	CartTitan = { "steam", rgb(230, 225, 215), rgb(255, 160, 90) },
	-- Blossom Academy
	["100Deku"] = { "lightning", rgb(80, 255, 120), WHITE },
	DekuOFA = { "lightning", rgb(80, 255, 120), WHITE },
	Kirishima = { "energy", rgb(230, 40, 40), rgb(255, 200, 160) }, -- hardening
	Aizawa = { "energy", rgb(255, 60, 60), WHITE }, -- erasure: red eyes
	Dabi = { "fire", rgb(40, 110, 255), rgb(170, 220, 255) }, -- blue flames
	Shigaraki = { "dark", BLACK, rgb(170, 150, 160) }, -- decay
	AllForOne = { "dark", BLACK, rgb(200, 20, 40) },
	AwakenedSukuna = { "dark", BLACK, rgb(200, 20, 40) },
	-- Ninja Village
	SixPathsNaruto = { "spirit", GOLD, BLACK }, -- the Truth-Seeking Orbs
	BaryonNaruto = { "fire", rgb(255, 80, 30), PURPLE },
	Kaguya = { "magic", rgb(220, 200, 255), WHITE },
	Jiraiya = { "energy", rgb(255, 90, 40), WHITE }, -- sage
	Hashirama = { "energy", rgb(80, 200, 90), GOLD }, -- wood
	Orochimaru = { "dark", PURPLE, rgb(120, 220, 80) },
	Tsunade = { "energy", rgb(110, 240, 180), WHITE },
	-- Pirate Bay
	Tszoro = { "dark", BLACK, rgb(60, 220, 110) },
	TsSanji = { "fire", rgb(255, 90, 30), GOLD },
	Whitebeard = { "energy", WHITE, rgb(150, 200, 255) }, -- the quake
	Aokiji = { "magic", rgb(140, 210, 255), WHITE }, -- ice
	Gear5Luffy = { "steam", WHITE, rgb(210, 190, 255) },
	Roger = { "dark", BLACK, RED }, -- Conqueror's Haki
	-- Dragon Ball: the new forms
	Gogeta = { "saiyan", GOLD, WHITE },
	SS4Gogeta = { "saiyan", rgb(220, 30, 40), GOLD },
	UIGoku = { "saiyan", rgb(225, 230, 240), rgb(120, 180, 255) },
	UEVegeta = { "saiyan", PURPLE, rgb(255, 120, 200) },
	BeastGohan = { "saiyan", rgb(235, 235, 245), RED },
}
STYLES.halo = { "halo", "sparkles" } -- (Saitama: he doesn't need one)

-- How much aura each rarity gets: how many of the style's layers, and how strong. Every fighter has one.
-- `flame`: how strong the solid body-wrapping flame under the style's own layers is (0 = none). The smoke and glow
-- textures of the other styles are mostly transparent and read as faint next to it, so Rare and up all get the flame.
local STRENGTH = {
	Common = { layers = 1, n = 0.55, size = 0.75, flame = 0 },
	Uncommon = { layers = 1, n = 0.8, size = 0.85, flame = 0 },
	Rare = { layers = 2, n = 0.9, size = 1, flame = 0.55 },
	Epic = { layers = 2, n = 1.1, size = 1.15, flame = 0.8 },
	Legendary = { layers = 3, n = 1.2, size = 1.3, flame = 1 },
	Mythic = { layers = 3, n = 1.4, size = 1.5, flame = 1.2 },
	Secret = { layers = 3, n = 1.6, size = 1.75, flame = 1.4, sparkles = true },
}

-- A mutation keeps the fighter's style and paints it: { main, accent } (a black main colour: the outline takes the accent).
local MUTATION = {
	Golden = { GOLD, WHITE },
	Diamond = { rgb(120, 215, 255), WHITE },
	Rainbow = { "rainbow", WHITE },
	Huge = { rgb(255, 110, 30), GOLD },
	Cursed = { BLACK, PURPLE },
	Sage = { rgb(255, 130, 20), RED },
	Haki = { BLACK, RED },
	Titan = { rgb(255, 80, 40), WHITE },
}

-- The outline colour for a fighter (client/FighterOutline.lua): the mutation's, or white.
function FighterAura.outline(mutation)
	local m = MUTATION[mutation or "Normal"]
	if not m then
		return WHITE
	elseif m[1] == "rainbow" then
		return rgb(255, 120, 220)
	end
	return math.max(m[1].R, m[1].G, m[1].B) < 0.25 and m[2] or m[1] -- a black flame: the accent
end

local function sequence(c)
	if c == "rainbow" then
		return RAINBOW
	end
	return typeof(c) == "ColorSequence" and c or ColorSequence.new(c)
end

-- Builds `layers` (names from LAYERS) on `part` at scale `k`, in `main`/`accent` (Color3 or "rainbow"),
-- amount `n`. Returns the emitters. (The player aura uses this too: client/Aura.lua.)
function FighterAura.build(part, k, layers, main, accent, n)
	local out = {}
	local dark = typeof(main) == "Color3" and math.max(main.R, main.G, main.B) < 0.25
	for _, name in layers do
		for _, props in LAYERS[name](k, main, accent, n) do
			local e = Instance.new("ParticleEmitter")
			e.Name = "Aura"
			for prop, value in props do
				if prop == "Color" then
					value = sequence(value)
				end
				e[prop] = value
			end
			if dark and props.Color == main then
				e.LightEmission = 0
			end
			e.Parent = part
			table.insert(out, e)
		end
	end
	return out
end

-- Puts the aura on `model` (a spawned fighter). `rarity` and `mutation` as in the save.
function FighterAura.apply(model, key, rarity, mutation, series)
	local strength = STRENGTH[rarity]
	local m = MUTATION[mutation or "Normal"]
	if m and (not strength or strength.layers < 2) then
		strength = STRENGTH.Epic -- a mutation always shows
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not (strength and hrp) then
		return
	end
	local look = BY_KEY[key] or SERIES[series] or SERIES.OTHER
	local style = STYLES[look[1]]
	local main, accent = look[2], look[3]
	if m then
		main, accent = m[1], m[2]
	end
	local k = model:GetScale() * strength.size
	local layers = table.clone(style)
	if strength.sparkles and not table.find(layers, "sparkles") then
		table.insert(layers, "sparkles")
	end
	local shown = {}
	for i, name in layers do
		if i <= strength.layers or name == "sparkles" then
			table.insert(shown, name)
		end
	end
	-- The solid flame round the whole body, in the fighter's colour (a black style burns in its accent colour, so it
	-- is a red or purple flame, not a dark smudge).
	if strength.flame > 0 and not table.find(shown, "blaze") then
		local dark = typeof(main) == "Color3" and math.max(main.R, main.G, main.B) < 0.25
		FighterAura.build(hrp, k, { "blaze" }, dark and accent or main, accent, strength.n * strength.flame)
	end
	FighterAura.build(hrp, k, shown, main, accent, strength.n)
end

return FighterAura
