-- Every number the game tunes lives here. See docs/GAME_PLAN.md for why each value is what it is.
local Config = {}

Config.Version = "0.1.0"
Config.Port = 34961
Config.MaxPlayers = 8

-- Studio only (never in a live server): look round the whole world without the grind. While unlockAllZones is on,
-- every zone opens on join and nothing is saved, so a real save can never pick the unlocks up.
Config.Studio = { unlockAllZones = false } -- (true: every zone open on join, to look round the world)
-- The game owner's save slot. Raise it to start over as a new player; older slots stay saved. 0 is the first save.
Config.OwnerSaveSlot = 1

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
Config.Rarities = {
	Common = { color = Color3.fromRGB(225, 232, 240), glow = false },
	Uncommon = { color = Color3.fromRGB(96, 220, 96), glow = true },
	Rare = { color = Color3.fromRGB(64, 156, 255), glow = true },
	Epic = { color = Color3.fromRGB(176, 92, 255), glow = true },
	Legendary = { color = Color3.fromRGB(255, 196, 40), glow = true },
	Mythic = { color = Color3.fromRGB(255, 56, 72), glow = true },
	Secret = { color = Color3.fromRGB(255, 255, 255), glow = true, rainbow = true },
}

-- Table tiers, nearest spawn first. `power` is the trained Power needed to sit at a drop altar of that
-- tier (shown on the altar's plate; guardians and bosses have their own ladder). `weights` are per rarity.
Config.TierOrder = { "Bronze", "Silver", "Gold", "Diamond", "Celestial" }
Config.Tiers = {
	Bronze = {
		trim = Color3.fromRGB(205, 127, 50),
		power = 0,
		respawn = 15,
		botDelay = 3,
		weights = { Common = 93, Uncommon = 6, Rare = 1 },
	},
	Silver = {
		trim = Color3.fromRGB(200, 212, 226),
		power = 2000,
		respawn = 20,
		botDelay = 5,
		weights = { Uncommon = 93.4, Rare = 4.5, Epic = 1.7, Legendary = 0.4 },
	},
	Gold = {
		trim = Color3.fromRGB(255, 196, 40),
		power = 200e3,
		respawn = 30,
		botDelay = 5,
		weights = { Rare = 78, Epic = 18, Legendary = 3.5, Mythic = 0.5 },
	},
	Diamond = {
		trim = Color3.fromRGB(110, 230, 255),
		power = 10e6,
		respawn = 45,
		botDelay = 5,
		weights = { Epic = 80, Legendary = 16, Mythic = 3.7, Secret = 0.3 },
	},
	-- Walled City only: the top of the drop ladder.
	Celestial = {
		trim = Color3.fromRGB(255, 120, 230),
		power = 250e6,
		respawn = 60,
		botDelay = 5,
		weights = { Legendary = 88, Mythic = 11, Secret = 1 },
	},
}

-- The voxel models (art/voxel_pilot/VoxelKit.glb): the uploaded Model's asset id. 0 keeps everything brick.
Config.VoxelKitId = 121245120135946

-- Every fighter's own odds, the same everywhere: "1 in N" for its rarity, spread a little per fighter so no two
-- read alike (Odds.base). This is the number on show. Altars (Config.Tiers weights) and luck decide how often it
-- really drops; a plate shows that as its altar's luck, base odds / real chance (Odds.altarLuck).
-- A duplicate powers up your best copy: +bonus income per star, up to max (Odds.income, TrainingService).
Config.Stars = { max = 5, bonus = 0.1 }

Config.BaseOdds = {
	Common = 1e3,
	Uncommon = 5e3,
	Rare = 25e3,
	Epic = 120e3,
	Legendary = 750e3,
	Mythic = 5e6,
	Secret = 50e6,
}

-- Mutations roll after the fighter. `mult` multiplies income. Golden, Diamond, Rainbow and Huge happen
-- anywhere; each zone has one themed mutation (`zone`) that only rolls on its altars. Looks:
-- shared/MutationLook.lua. MutationOrder runs from worst to best.
Config.MutationOrder = { "Normal", "Golden", "Cursed", "Sage", "Haki", "Titan", "Diamond", "Rainbow", "Huge" }
Config.Mutations = {
	-- `color`: the mutation's tag over the name (its own colour, never the rarity's, so a Golden Common
	-- can't read as a Legendary).
	Normal = { weight = 88, mult = 1 },
	Golden = { weight = 5, mult = 2, color = Color3.fromRGB(255, 205, 50) },
	Cursed = { weight = 4, mult = 3, zone = "Blossom", color = Color3.fromRGB(180, 90, 255) },
	Sage = { weight = 4, mult = 3, zone = "Ninja", color = Color3.fromRGB(255, 145, 40) },
	Haki = { weight = 4, mult = 3, zone = "Pirate", color = Color3.fromRGB(255, 60, 70) },
	Titan = { weight = 4, mult = 3, zone = "Walled", color = Color3.fromRGB(255, 120, 90) },
	Diamond = { weight = 3, mult = 5, color = Color3.fromRGB(120, 215, 255) },
	Rainbow = { weight = 0.9, mult = 10, color = Color3.fromRGB(255, 130, 230) },
	Huge = { weight = 0.1, mult = 25, scale = 2, color = Color3.fromRGB(255, 160, 70) },
}

-- Display scales for the pack's R6 avatars (5 studs tall at 1x).
-- New Player Luck: rarer rarities start x`mult` for drops near a save's first `minutes` minutes of life, fading to x1.
Config.NewbieLuck = { mult = 10, minutes = 20 }

Config.Scale = { Table = 2.5, Plot = 1.5, Champion = 3, Index = 1 }

-- Battle.
Config.Battle = {
	faceOff = 2,
	duration = 10,
	result = 2,
	maxCps = 14,
	batchInterval = 0.1,
	surgeClicks = 40,
	surgeDuration = 2,
	surgeMult = 2,
	suddenDeath = 2,
	unclaimedDespawn = 60,
	seatCooldown = 2,
	maxWaitWithoutBot = 20,
	pvpWait = 5, -- a free player within pvpRadius gets this long to take the other pad before a bot does
	pvpRadius = 120,
	consolation = 0.25,
	comebackBonus = 0.2,
	comebackMaxStacks = 3,
	rubberBand = 0.6, -- the player behind gets up to +60% per click, so clashes stay close
	padRadius = 6.5, -- how close (studs, flat) a player must stand to claim a clash pad: anywhere on the dais, its step too

	-- Skill layer (docs/PROGRESSION.md §2). A pulse target appears for both players at the same instant.
	pulseFirst = 1.2, -- seconds into the battle before the first pulse
	pulseEvery = 2.4,
	pulseWindow = 0.9, -- a pulse not hit within this is a MISS
	perfect = 0.3, -- reaction (s) for PERFECT
	good = 0.75, -- reaction (s) for GOOD
	perfectBurst = 10, -- score added by a PERFECT (in clicks)
	goodBurst = 6,
	firstStrike = 0.5, -- extra share of the burst for whoever hits a pulse first
	missPenalty = 3,
	earlyLockout = 0.6, -- pressing PULSE with no pulse open locks it this long (no spamming)
	overdrive = 3, -- the last seconds of a clash: everything is worth more
	overdriveMult = 1.5,
	latencyAllowance = 0.35, -- how far a client's reported tap time may trail the server's receipt
	counterWindow = 0.5, -- surge within this of the rival's surge = COUNTER BREAK
	counterSteal = 0.15, -- share of all points moved from the countered side to the counterer
	-- Grades: points per pulse (perfect 3, good 2, first strike +1), counter +2, miss -2, out of 4 per pulse.
	gradeS = 0.75,
	gradeA = 0.5,
}

-- Beam Push (client/Clash.lua, server/Services/ClashService.lua): the two beams meet at a clash point.
-- TAP ANYWHERE pushes it toward the rival; push it all the way through to win the round (best of 3).
--   * combo: steady tapping builds the push up to comboMax (a pause resets it),
--   * ULTIMATE (one button, Space on PC): fills from your taps; fire it for a big push, doubled in LAST STAND
--     (when you're nearly pushed out),
--   * ULTIMATE CLASH: both ultimates within clashWindow -> both cancel into a TAP FRENZY; whoever taps more
--     wins a big swing,
--   * Power: each side's push is multiplied by how its Power compares (steep against bots, gentler between
--     players, no cap either way: ClashRules.pushMult).
-- `pos` runs 0..1: side 1 pushes it up toward 1 (side 2's end), side 2 pushes it down toward 0.
Config.Push = {
	roundsToWin = 2,
	countdown = 1.1, -- "CLASH!" before each round
	roundGap = 1.4,
	roundTime = 15, -- then whoever has the point on the rival's half wins the round
	clickPush = 0.012, -- point travel per second per tap-per-second
	basePush = 0.008, -- a fighter holds a little ground even between taps
	comboStep = 0.1, -- combo grows this much per half second of steady tapping...
	comboMax = 1.6, -- ...up to this
	comboGap = 0.4, -- a pause this long resets it
	ultTaps = 35, -- taps to fill the ultimate (Power fills it up to 1.5x faster)
	ultPush = 0.2,
	lastStand = 0.15, -- within this of your own end your ultimate pushes x2
	clashWindow = 1,
	frenzyTime = 3,
	frenzySwing = 0.28,
	bossRage = 4, -- a boss pushed deep into its half rages (taps x1.5) this long, once a round
	-- Match length by prize: Common to Rare is a best of 2 (at 1-1 whoever pushed further across both rounds wins);
	-- Epic and up is a best of 5. Guardians and bosses set their own (ZoneService).
	shortRarities = { Common = true, Uncommon = true, Rare = true },
	longRoundsToWin = 3,
	-- ONE BLAST: a player this many times stronger than a drop's bot ends it in a single round, at blastMult push.
	blastRatio = 10,
	blastMult = 4,
	rookieMax = 100e3, -- hub altars: players above this Power fight in the zones instead
	-- Power curves (ratio = your Power / theirs): against bots ratio^botCurve (0.35x..2.5x: stronger wins, but you still have to tap); between players
	-- 1 + pvpStep * log2(ratio), at least 0.4x, no ceiling.
	botCurve = 0.6,
	botMax = 2.5,
	pvpStep = 0.25,
	-- Drop-altar bots (guardians and bosses use their ladder Power, ZoneService). The tutorial's first fight is
	-- 30; hub altars start at their tier's Power (players leave the tutorial past 1K); a zone's altars start at
	-- the Power the zone asks for (its first guardian's) and every rarity above the altar's most common one
	-- multiplies it by botRarityStep (or the zone's own), so a rarer prize is guarded by a stronger rival.
	botPower = { Tutorial = 30, Bronze = 1e3, Silver = 4e3, Gold = 320e3, Diamond = 16e6, Celestial = 600e6 },
	botRarityStep = 1.5,
	hubRarityStep = { Silver = 4 }, -- (hub Silver shares Blossom's drops: its rare ones can't be cheaper here)
}

-- Beam Rally (docs/PROGRESSION.md, rally section): one orb flies between the players and must be deflected
-- as it arrives; it speeds up on every return; a missed deflect loses the round; best of three.
Config.Rally = {
	roundsToWin = 2,
	serveDelay = 1.1, -- after the round starts, the orb leaves the centre
	roundGap = 2.2, -- pause between rounds
	startTravel = 1.7, -- seconds for the orb to cross on the first pass
	speedUp = 0.9, -- each return: travel *= this
	perfectSpeedUp = 0.84,
	smashSpeed = 0.58, -- a SMASH return: travel *= this
	minTravel = 0.42,
	windowFrac = 0.5, -- deflect window = this share of the travel time (clamped)
	windowMax = 0.5,
	windowMin = 0.24,
	-- PERFECT spans arrival, leaning late: screen, input and reaction lag make honest presses land late.
	perfectEarly = 0.07,
	perfectLate = 0.12,
	grace = 0.18, -- deflects accepted this long after arrival
	whiffLock = 0.15, -- pressing too early locks DEFLECT this long
	mashSway = 0.3, -- mashing can slow (receiver) or speed (sender) the orb by up to this share...
	mashNorm = 8, -- ...reached at this many taps per second more than the rival
	botDecide = 0.45, -- a bot commits to its deflect this long before its window opens (at the orb's real speed)
	smashCharge = 30, -- taps to charge a SMASH (resets when used)
	overdriveHits = 8, -- returns in one rally before OVERDRIVE
}

-- Upgrade power only counts against the game (bots, gates, bosses). Human-vs-human clashes ignore it.
Config.PowerAgainstPlayers = false

-- Bot pulse reactions in seconds (low, high) and miss chance, by altar tier.
-- Bot deflects: success chance starts at `base` and falls by `fade` x (seconds the orb has sped up)^2;
-- `perfect` is the share of successes that are PERFECT; `smash` the chance to smash when charged.
Config.BotSkill = {
	Tutorial = { base = 0.85, fade = 4, perfect = 0, smash = 0 }, -- the tutorial clash: cracks by the 3rd return
	Easy = { base = 0.97, fade = 0.95, perfect = 0.1, smash = 0.15 },
	Bronze = { base = 0.98, fade = 0.55, perfect = 0.2, smash = 0.3 },
	Silver = { base = 0.99, fade = 0.4, perfect = 0.3, smash = 0.4 },
	Gold = { base = 0.99, fade = 0.3, perfect = 0.4, smash = 0.5 },
	Diamond = { base = 0.99, fade = 0.23, perfect = 0.5, smash = 0.6 },
	Master = { base = 0.995, fade = 0.17, perfect = 0.6, smash = 0.7 }, -- late Pirate, Walled
	Legend = { base = 0.997, fade = 0.13, perfect = 0.7, smash = 0.8 }, -- the last guardians and the Titan
}
Config.BotSkill.Celestial = Config.BotSkill.Master -- Walled City's altar bots

-- Bot rivals: clicks per second by altar tier (low, high). A first-ever clash uses the easy band.
Config.Bots = {
	-- Taps per second, at real human speeds so an EVEN fight is a real fight (a quick mouse is 8-12,
	-- a phone thumb 5-8). Training Power is how you beat the faster tiers.
	Easy = { 2, 3 },
	Bronze = { 4.5, 5.5 },
	Silver = { 6, 7 },
	Gold = { 7, 8 },
	Diamond = { 8, 9.5 },
	Master = { 9, 10.5 },
	Legend = { 10, 12 },
}
Config.Bots.Celestial = Config.Bots.Master

-- Sky Dojo, the hub island (docs/WORLD_PLAN.md §8; built by server/Hub.lua from the Brick Kit).
-- Y = 0 is the open grass. +Z is south, toward spawn. Angles are degrees from +X toward +Z.
-- One big, mostly empty island (radius ~300) with compact districts and wide open grass between them:
--   centre      the plaza (r < 78, y 4.8): Colosseum (ranked, coming soon), the Summit Pagoda behind it
--   south  90   spawn (r 210) and the Drop Arena between spawn and the plaza (r 150)
--   west  180   Training district (r 150)    east 0   Shopping district (r 150): Fighter Market, Beam Shrine
--   north       the zone gates in a row on the rim
--   ring        the 8 player bases, open plates on the grass (r 280), so everyone sees everyone's fighters
Config.Island = {
	radius = 345,
	middle = { radius = 78, height = 4.8, road = 53 },
	lowerRoad = 89,
	colosseum = { stage = 24, inner = 30 },
	summit = { center = Vector3.new(0, 9.6, -78), size = Vector2.new(34, 26) }, -- the Summit Pagoda's plateau
	portal = { height = 100, radius = 22 },
	altarRadius = 150,
	-- The Drop Arena: a wide arc between spawn and the plaza. Gold and Diamond altars live only in the zones.
	altars = {
		{ tier = "Bronze", angle = 76 },
		{ tier = "Bronze", angle = 104 },
		{ tier = "Silver", angle = 48 },
		{ tier = "Silver", angle = 132 },
	},
	-- The Training district (two grounds side by side and the Practice Dojo). Their stalls sell Wooden (for
	-- anyone who skipped the tutorial's gift) and Stone from the stall's window.
	training = { angle = 180, dist = 150, tiers = { 2, 3 } },
	shops = { angle = 0, dist = 150 }, -- the Shopping district: Fighter Market and Beam Shrine
	plotRadius = 276, -- (outer edge 335, inside the rim; neighbours 4 studs apart at the inner corners)
	plotAngles = { 124, 152, 180, 208, 332, 0, 28, 56 }, -- 28 apart: 11 studs between neighbours at least
	plotSize = Vector2.new(96, 118), -- 8 stands + 2 pass stands on the ground, Floor 2 (8 more) on the slab above
	spawn = Vector3.new(0, 0, 210),
	-- The conveyor ring in front of the bases (server/Hub.lua belt): centre radius, lane width (two lanes,
	-- opposite ways), speed (studs/s; walking is 16), and where it breaks (the spawn path at 90 degrees).
	belt = { radius = 200, lane = 6, height = 0.5, speed = 32, step = 3, gaps = { 90 }, gapHalf = 6 },
	-- Zone gates on piers at the north rim, in ladder order left to right as you walk up from the plaza.
	gates = {
		-- `color`: each gate's own colour (its torii, pier and signpost arm), so the four don't look alike.
		{ zone = "Blossom", title = "BLOSSOM", angle = 245, open = false, color = Color3.fromRGB(255, 130, 185) },
		{ zone = "Ninja", title = "NINJA", angle = 265, color = Color3.fromRGB(255, 140, 30) },
		{ zone = "Pirate", title = "PIRATE", angle = 285, color = Color3.fromRGB(40, 100, 210) },
		{ zone = "Walled", title = "WALLED", angle = 305, color = Color3.fromRGB(80, 150, 70) },
	},
	waterfalls = { 72, 108 },
	market = {}, -- (old shop fronts round the plaza: removed, everything they sold is a menu)
}

-- Zone islands (docs/WORLD_PLAN.md §3-4). Each zone floats out past its hub gate; you climb its Dojo
-- Ladder (5 guardians, then the boss) and beating the boss opens the next zone. `band` is the bot skill
-- range the ladder climbs through (Config.BotSkill names); Power upgrades soften every guardian and boss.
-- `center` is the middle of the zone island's main terrace.
Config.Zones = {
	Blossom = {
		order = 1,
		title = "BLOSSOM ACADEMY",
		set = "Blossom",
		gateAngle = 35,
		center = Vector3.new(708, 24, 496),
		series = { "My Hero Academia", "OTHER", "YYH" },
		band = { "Bronze", "Silver" },
		-- Power to challenge guardians 1-5 and the boss (ZoneService), in step with the zone's stations.
		-- (Blossom opens at 2K Power, so its first guardian needs 2K; the rest climb from there.)
		ladderPower = { 2e3, 6e3, 15e3, 40e3, 400e3, 3.5e6 }, -- (small steps first: the early wins come fast)
		botRarityStep = 8, -- (its ladder climbs far: a Legendary's bot sits near the end of it, about 1M)
		tier = "Silver", -- altar tier (drop odds): one step above the hub, and up a step per zone
		guardians = { "Lemillion", "Deku", "Bakugo", "Todoroki", "Hellflame" },
		boss = { key = "AllMightMode", title = "SYMBOL OF PEACE", rounds = 3, skill = "Gold" },
		unlocked = false,
		unlockPower = 2e3, -- Blossom Academy opens when a player first reaches 2K Power (TrainingService)
		next = "Ninja",
	},
	Ninja = {
		order = 2,
		title = "NINJA VILLAGE",
		set = "Ninja",
		gateAngle = 145,
		center = Vector3.new(-708, 24, 496),
		series = { "NARUTO", "HXH" },
		band = { "Silver", "Gold" },
		ladderPower = { 6e6, 10e6, 16e6, 24e6, 34e6, 50e6 }, -- (cleared around day 3)
		botRarityStep = 2, -- (a Mythic's bot sits at the boss's level)
		tier = "Gold",
		guardians = { "Neji", "RockLee", "Gaara", "Kakashi", "Itachi" },
		boss = { key = "Madara", title = "THE SHADOW", rounds = 3, skill = "Diamond" },
		unlocked = false,
		next = "Pirate",
	},
	Pirate = {
		order = 3,
		title = "PIRATE BAY",
		set = "Pirate",
		gateAngle = 325,
		center = Vector3.new(708, 24, -496),
		series = { "One Piece", "Fairy Tail" },
		band = { "Gold", "Master" },
		ladderPower = { 70e6, 90e6, 110e6, 130e6, 155e6, 180e6 }, -- (cleared around day 5)
		tier = "Diamond",
		guardians = { "Ptsluffy", "Ptslaw", "Ptszoro", "Ace", "Shanks" },
		boss = { key = "Whitebeard", title = "THE EMPEROR", rounds = 3, skill = "Master" },
		unlocked = false,
		next = "Walled",
	},
	Walled = {
		order = 4,
		title = "WALLED CITY",
		set = "Walled",
		gateAngle = 215,
		center = Vector3.new(-708, 24, -496),
		series = { "AOT", "FATE" },
		band = { "Diamond", "Legend" },
		ladderPower = { 300e6, 380e6, 460e6, 540e6, 620e6, 700e6 }, -- (cleared around day 7)
		tier = "Celestial",
		guardians = { "Sasha", "Erwin", "Mikasa", "ErenPostTimeSkip", "FemaleTitan" },
		boss = { key = "AttackTitan", title = "THE TITAN", rounds = 3, skill = "Legend" },
		unlocked = false,
	},
}

Config.Drops = {
	interval = 22, -- seconds between drops onto empty altars
	landDelay = 0.9, -- beam hits, then the fighter appears
	despawn = 120, -- unclaimed fighters leave after this
	scale = 2.5,
}

-- Guardian spawns (DropService): every zone drop also lands a fighter over one of the zone's guardians (or
-- its boss); the first player to beat that guardian wins it. Rarer up the ladder: weights per rung (6 = the
-- boss) for the first zone, shifted one rarity up per later zone (Odds.shiftRarity).
Config.GuardianOdds = {
	{ Uncommon = 60, Rare = 35, Epic = 5 },
	{ Rare = 75, Epic = 25 },
	{ Rare = 55, Epic = 42, Legendary = 3 },
	{ Epic = 85, Legendary = 15 },
	{ Epic = 70, Legendary = 28, Mythic = 2 },
	{ Legendary = 85, Mythic = 14.5, Secret = 0.5 },
}

-- Server events (docs/RETENTION_PLAN.md §3), on the server clock so every server runs them together:
--   Secret Rush: every rushEvery seconds (offset rushOffset), a hub altar is announced rushWarn seconds
--     ahead, then drops a guaranteed Mythic (or, rushSecret of the time, a Secret),
--   Luck Storm: the first stormLength seconds of every hour, drops roll stormLuck times rarer.
Config.Events = {
	rushEvery = 900,
	rushOffset = 420, -- :07, :22, :37, :52 (clear of the storm at the top of the hour)
	rushWarn = 30,
	rushSecret = 0.25,
	stormEvery = 3600,
	stormLength = 300,
	stormLuck = 3,
}

-- Kept for plot code until plots move to the island ring.
Config.Layout = {
	startPedestals = 8,
	maxPedestals = 40,
}

-- Each colour means one thing (docs/HIT_PLAN.md §7.3). Rarity colours never appear on decor.
Config.Palette = {
	grass = Color3.fromRGB(104, 196, 74),
	grassDark = Color3.fromRGB(78, 158, 60),
	cliff = Color3.fromRGB(196, 150, 104),
	cliffDark = Color3.fromRGB(150, 108, 76),
	rock = Color3.fromRGB(122, 104, 96),
	stone = Color3.fromRGB(226, 218, 200),
	stoneDark = Color3.fromRGB(170, 160, 146),
	path = Color3.fromRGB(214, 196, 160),
	wood = Color3.fromRGB(140, 96, 64),
	woodDark = Color3.fromRGB(96, 64, 44),
	red = Color3.fromRGB(214, 48, 40),
	redDark = Color3.fromRGB(150, 30, 28),
	gold = Color3.fromRGB(255, 200, 52),
	white = Color3.fromRGB(246, 244, 236),
	blossom = Color3.fromRGB(255, 168, 206),
	blossomDark = Color3.fromRGB(242, 128, 178),
	water = Color3.fromRGB(110, 200, 255),
	cloud = Color3.fromRGB(255, 255, 255),
	lantern = Color3.fromRGB(255, 120, 60),
	blue = Color3.fromRGB(40, 120, 220),
	purple = Color3.fromRGB(130, 70, 200),
}
-- The plot economy (server/Services/PlotService.lua): stands fill their collect pads with each fighter's
-- income every second; the owner steps on a pad to collect. Stands 5-8 are bought with cash.
Config.Plot = {
	startStands = 4,
	standPrices = { [5] = 50e3, [6] = 500e3, [7] = 20e6, [8] = 400e6 }, -- (tools/sim/moments.py: 7 and 8 land on day 2)
	-- Floor 2 (the Floor 2 pass, offered once stand 8 is open): its 8 stands (slots 11-18) unlock in order.
	floor2Prices = { 500e6, 1e9, 2e9, 4e9, 8e9, 16e9, 32e9, 64e9 },
	collectRadius = 3.4, -- flat distance from a pad's centre that collects it
}

-- Social and return hooks (server/Services/SocialService.lua, PlotService offline earnings, client/Social.lua).
Config.Social = {
	groupId = 0, -- the game's Roblox group (0 = none yet: the JOIN GROUP reward stays hidden)
	groupCash = 1.1, -- members earn +10% cash forever
	friendStep = 0.1, -- +10% cash and training per friend in the server...
	friendMax = 5, -- ...up to 5 friends (+50%)
	offlineShare = 0.5, -- a base earns this share of its income while its owner is away...
	offlineCap = 8 * 3600, -- ...for at most 8 hours
	offlineMin = 120, -- (away less than 2 minutes: nothing to show)
	limitBreak = 100, -- every this many training reps: LIMIT BREAK!
	limitBreakReps = 30, -- worth this many reps at once
}

-- Badges (create them on the Creator Dashboard, then paste each id; 0 = not created yet, skipped).
Config.Badges = {
	Welcome = 0, -- joined the game
	FirstWin = 0, -- won a clash
	Blossom = 0, -- beat Blossom Academy's boss
	Ninja = 0,
	Pirate = 0,
	Walled = 0,
	FirstSecret = 0, -- got a Secret fighter
	FirstSteal = 0, -- stole a fighter
	Rebirth = 0, -- the first rebirth
	FullBase = 0, -- all 8 ground-floor stands unlocked
}

Config.PlotColors = {
	Color3.fromRGB(196, 40, 28),
	Color3.fromRGB(13, 105, 172),
	Color3.fromRGB(40, 127, 71),
	Color3.fromRGB(245, 205, 48),
	Color3.fromRGB(107, 50, 124),
	Color3.fromRGB(218, 133, 65),
	Color3.fromRGB(4, 175, 236),
	Color3.fromRGB(255, 102, 204),
}

return Config
