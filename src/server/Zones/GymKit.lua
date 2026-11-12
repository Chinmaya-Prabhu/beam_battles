-- Training stations and gear stalls (docs/TRAINING_PLAN.md §3-4), in Brick Kit style.
-- GymKit.station(parent, cf, key, set): `cf` is the centre of the station's mat on the ground, its front
-- (sign side, where players walk up) toward -Z. Builds the equipment, a sign and a ProximityPrompt and
-- registers the station with GymKit.List for TrainingService: { id, key, model, spot, prompt }. A key can
-- have several copies; each copy (model tag "TrainStation", attribute StationId) seats one trainee.
-- `spot` is where the trainee stands (ground level, facing the way they look while training).
-- Every station is a punching post or a heavy bag, dressed per zone (LOOKS).
-- GymKit.stall(parent, cf, set, tiers) builds a gear shop with a display per tier and one prompt that
-- sells the player's next tier if this stall stocks it (attribute Tiers = "4,5").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Bricks = require(Shared.Bricks)
local Training = require(Shared.Training)
local GearLook = require(Shared.GearLook)
local K = require(script.Parent.Parent.BrickKit)

local GymKit = {}
GymKit.List = {}
GymKit.Stalls = {}

local C = Bricks.C
local Core = K.Core
local BRICK, PLATE = Core.BRICK, Core.PLATE
local SMOOTH = { smooth = true }
local DECOR = { smooth = true, collide = false }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local STEEL, STEEL_DARK = rgb(170, 176, 184), rgb(70, 74, 82)

local function prompt(parent, at, text, object)
	local anchor = Core.part(parent, CFrame.new(at), Vector3.one * 0.5, C.white, { trans = 1, collide = false })
	anchor.Name = "PromptAnchor"
	local p = Instance.new("ProximityPrompt")
	p.ActionText = text
	p.ObjectText = object or ""
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.Parent = anchor
	return p
end

-- The floor inside the mat's rim, themed per zone: tatami (hub, Ninja), a blue gym mat (Blossom), deck
-- planks (Pirate) or flagstones (Walled).
local TATAMI, TATAMI_EDGE = rgb(214, 204, 140), rgb(46, 84, 56)
local RIM = PLATE + 0.15 -- (a little over a plaza's PLATE-high paving: equal heights flicker)
local function floor(m, cf, zone, set)
	local y = RIM
	if zone == "Pirate" then
		for k = 0, 4 do
			Core.box(
				m,
				cf,
				-5.5 + k * 2.2,
				y,
				-5.5,
				2.1,
				0.2 + (k % 2) * 0.04,
				11,
				k % 2 == 0 and set.wood[1] or set.wood[2],
				{ smooth = true, material = Enum.Material.Wood }
			)
		end
	elseif zone == "Walled" then
		for i = 0, 2 do
			for j = 0, 2 do
				Core.box(
					m,
					cf,
					-5.5 + i * 3.7,
					y,
					-5.5 + j * 3.7,
					3.6,
					0.2 + ((i + j) % 2) * 0.04,
					3.6,
					(i + j) % 3 == 0 and C.gray or C.lightGray,
					{ smooth = true, material = Enum.Material.Slate }
				)
			end
		end
	elseif zone == "Blossom" then
		Core.centered(m, cf, 0, y, 0, 11, 0.2, 11, rgb(54, 92, 170), SMOOTH)
		for _, d in { -1, 1 } do
			Core.centered(m, cf, d * 4.9, y + 0.2, 0, 0.3, 0.14, 10, C.white, DECOR)
			Core.centered(m, cf, 0, y + 0.2, d * 4.9, 10, 0.14, 0.3, C.white, DECOR)
		end
	else
		-- Two tatami mats side by side, each with its dark cloth edging.
		for _, x in { -2.75, 2.75 } do
			Core.centered(m, cf, x, y, 0, 5.4, 0.2, 11, TATAMI, SMOOTH)
			for _, dx in { -1, 1 } do
				Core.centered(m, cf, x + dx * 2.55, y + 0.2, 0, 0.3, 0.14, 11, TATAMI_EDGE, DECOR)
			end
		end
	end
end

-- The mat's rim, the floor, a sign on two posts at the front left and the multiplier plate.
local function base(m, cf, def, set)
	Core.centered(m, cf, 0, 0, 0, 13, RIM, 13, set.trim or C.darkGray)
	floor(m, cf, def.zone, set)
	local sx = -7.5
	for _, dx in { -2.2, 2.2 } do
		Core.centered(m, cf, sx + dx, 0, -6.2, 0.6, BRICK * 4.6, 0.6, set.wood and set.wood[2] or C.darkBrown)
	end
	local board = Core.part(
		m,
		cf * CFrame.new(sx, BRICK * 3.9, -6.2),
		Vector3.new(5.6, BRICK * 1.6, 0.4),
		set.wood and set.wood[1] or C.brown,
		SMOOTH
	)
	Core.label(board, string.upper(def.name), Enum.NormalId.Front, C.white)
	local plate = Core.part(m, cf * CFrame.new(sx, BRICK * 2.5, -6.25), Vector3.new(3.4, BRICK, 0.3), C.black, SMOOTH)
	Core.label(plate, "x" .. def.mult .. " POWER", Enum.NormalId.Front, C.yellow)
end

-- Every station is a punching post or a heavy bag (the training is always punching); each zone dresses
-- them in its own materials. `look` colours: pole, pad, bands, cap, foot (post); frame, bag, bands (bag).
local LOOKS = {
	PunchPost = { pole = C.brown, pad = rgb(186, 96, 48), bands = rgb(245, 228, 190), cap = C.darkGray, foot = C.gray },
	Sandbag = { frame = C.darkBrown, bag = C.red, bands = C.black },
	-- Blossom Academy: a gym's padded strike post and a blue boxing bag on a steel frame.
	AcademyPost = { pole = STEEL, pad = rgb(60, 110, 210), bands = C.white, cap = STEEL_DARK, foot = STEEL_DARK },
	AcademyBag = { frame = STEEL, bag = rgb(50, 90, 200), bands = C.white },
	-- Ninja Village: a rope-bound makiwara and a straw bag under a bamboo beam.
	NinjaPost = {
		pole = rgb(120, 82, 50),
		pad = rgb(205, 180, 120),
		bands = rgb(70, 50, 34),
		cap = rgb(70, 50, 34),
		foot = C.darkGray,
	},
	NinjaBag = { frame = rgb(150, 170, 80), bag = rgb(210, 185, 120), bands = rgb(90, 60, 36) },
	-- Pirate Cove: a mast stump wrapped in rope and a canvas sack hung from a spar.
	PiratePost = {
		pole = rgb(110, 70, 40),
		pad = rgb(200, 170, 110),
		bands = rgb(150, 110, 60),
		cap = C.darkGray,
		foot = rgb(80, 55, 35),
	},
	PirateBag = { frame = rgb(95, 62, 38), bag = rgb(225, 210, 170), bands = rgb(120, 80, 45) },
	-- Walled City: an iron-shod post with a leather pad and a leather bag on an iron gantry.
	WalledPost = {
		pole = C.darkGray,
		pad = rgb(120, 70, 40),
		bands = rgb(60, 60, 66),
		cap = rgb(60, 60, 66),
		foot = C.gray,
	},
	WalledBag = { frame = rgb(60, 60, 66), bag = rgb(110, 62, 36), bands = rgb(40, 40, 44) },
}

-- Both are built like the rest of the world: studded bricks on the stud grid, the studs showing on every
-- step (the foot around the column, the pad around the pole, the cap), a few round studs as rivets, and a
-- red-and-white target where the fists land.
local WHITE, TARGET_RED = rgb(245, 245, 245), rgb(220, 40, 40)

-- A round target facing the trainee (-Z) at local (x, y, z): white, red and white rings, each a little proud
-- of the last, so it reads at a glance as "hit here".
local function target(m, cf, x, y, z, size)
	for i, ring in { { size, WHITE }, { size * 0.68, TARGET_RED }, { size * 0.34, WHITE } } do
		Core.part(
			m,
			cf * CFrame.new(x, y, z - i * 0.06) * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(0.12, ring[1], ring[1]),
			ring[2],
			{ shape = Enum.PartType.Cylinder, smooth = true, collide = false }
		)
	end
end

-- Rivets: 1x1 round studs on a brick's top corners.
local function rivets(m, cf, x, y, z, half, color)
	for _, dx in { -half, half } do
		for _, dz in { -half, half } do
			Core.roundPlate(m, cf, x + dx, y, z + dz, color, 0.8)
		end
	end
end

-- A training post: a kung fu wooden dummy. A slim round trunk held between two studded rails on a brick
-- frame behind it, two arms reaching out at shoulder height and one bent leg low down, bands round the
-- trunk and a small target at the chest. (A post you punch should be slim: the old padded column was a
-- block.)
local function limb(m, cf, from, dir, length, diameter, color)
	local d = dir.Unit
	local centre = from + d * (length / 2)
	Core.part(
		m,
		cf * (CFrame.lookAt(centre, centre + d) * CFrame.Angles(0, math.pi / 2, 0)), -- (a cylinder's axis is X)
		Vector3.new(length, diameter, diameter),
		color,
		{ shape = Enum.PartType.Cylinder, smooth = true }
	)
end

local function post(m, cf, look)
	local z = 1.6
	local trunkTop = PLATE + BRICK * 6
	-- The frame: a studded base plate, two posts behind the trunk and two rails through them.
	Core.centered(m, cf, 0, 0, z + 0.7, 7, PLATE, 2, look.foot)
	for _, x in { -2.8, 2.8 } do
		Core.centered(m, cf, x, PLATE, z + 0.9, 1, trunkTop + 0.4 - PLATE, 1, look.pole)
		Core.roundPlate(m, cf, x, trunkTop + 0.4, z + 0.9, look.cap, 1)
	end
	for _, y in { PLATE + BRICK * 1.5, trunkTop - BRICK } do
		Core.centered(m, cf, 0, y, z + 0.9, 6.6, PLATE * 1.5, 1, look.pole) -- a rail (studs on top)
	end
	-- The trunk: slim and round, banded at the top and bottom.
	Core.cyl(m, cf, 0, PLATE, z, 1.5, trunkTop - PLATE, look.pad)
	for _, y in { PLATE + 0.5, trunkTop - 0.5 } do
		Core.cyl(m, cf, 0, y, z, 1.6, 0.25, look.bands)
	end
	Core.roundPlate(m, cf, 0, trunkTop, z, look.cap, 1.2) -- the cap
	-- The arms: two at shoulder height, angled out to the sides, one a little higher; the leg: bent down.
	local front = z - 0.7
	limb(m, cf, Vector3.new(-0.35, 4.9, front + 0.1), Vector3.new(-0.45, 0.12, -1), 2.3, 0.38, look.pole)
	limb(m, cf, Vector3.new(0.35, 4.6, front + 0.1), Vector3.new(0.45, 0.12, -1), 2.3, 0.38, look.pole)
	limb(m, cf, Vector3.new(0, 3.6, front + 0.1), Vector3.new(0, 0, -1), 1.3, 0.38, look.pole) -- the middle arm
	local knee = Vector3.new(0.3, 2.0, front - 0.9)
	limb(m, cf, Vector3.new(0.15, 2.3, front + 0.1), knee - Vector3.new(0.15, 2.3, front + 0.1), 1.05, 0.45, look.pole)
	limb(m, cf, knee, Vector3.new(0.15, -1, -0.15), 1.4, 0.45, look.pole)
	target(m, cf, 0, 4.2, z - 0.72, 0.9)
	return cf * CFrame.new(0, PLATE, -1.6) * CFrame.Angles(0, math.pi, 0) -- facing the dummy
end

-- A heavy bag under a brick gantry: two studded pillars on wide feet with brackets under a studded beam;
-- the bag itself is a chunky brick barrel (a cross of bricks, round from the front) with studded band
-- rings, a studded top cap on a short chain, the target on its face. It swings only while someone
-- punches it (client/TrainPose.lua).
local function bag(m, cf, look)
	local top = PLATE + BRICK * 7
	for _, x in { -3.4, 3.4 } do
		Core.centered(m, cf, x, PLATE, 2, 3, BRICK, 3, look.frame) -- the foot
		rivets(m, cf, x, PLATE + BRICK, 2, 1, look.bands)
		Core.centered(m, cf, x, PLATE + BRICK, 2, 1.6, BRICK * 6, 1.6, look.frame) -- the pillar
		Core.centered(m, cf, x - 1.3 * math.sign(x), top - BRICK, 2, 1, BRICK, 1.6, look.frame) -- bracket
	end
	Core.centered(m, cf, 0, top, 2, 9, BRICK, 2, look.frame) -- the beam (studded on top)
	for _, x in { -3.4, 3.4 } do
		Core.roundPlate(m, cf, x, top + BRICK, 2, look.bands, 1.2)
	end
	local hinge = cf * CFrame.new(0, top, 2)
	local b = Core.model(m, "Bag", hinge)
	local loose = { collide = false }
	local looseSmooth = { collide = false, smooth = true }
	-- The chain: three links, turned alternately.
	for k = 0, 2 do
		Core.part(
			b,
			hinge * CFrame.new(0, -0.25 - k * 0.4, 0) * CFrame.Angles(0, k % 2 * math.pi / 2, 0),
			Vector3.new(0.2, 0.45, 0.5),
			C.darkGray,
			looseSmooth
		)
	end
	local bodyTop = -2
	-- The cap: a studded 2x2 plate on a 3x3 one.
	Core.part(b, hinge * CFrame.new(0, bodyTop + PLATE * 1.5, 0), Vector3.new(2, PLATE, 2), look.bands, loose)
	Core.part(b, hinge * CFrame.new(0, bodyTop + PLATE * 0.5, 0), Vector3.new(3, PLATE, 3), look.bands, loose)
	-- The barrel: a cross of bricks (3x2 and 2x3 around a 3x3 core) reads round from every side.
	local height = BRICK * 4
	local mid = bodyTop - height / 2
	for _, size in { Vector3.new(3, height, 3), Vector3.new(4, height, 2), Vector3.new(2, height, 4) } do
		Core.part(b, hinge * CFrame.new(0, mid, 0), size, look.bag, loose)
	end
	-- Two band rings, one stud proud of the barrel, studs on top.
	for _, y in { bodyTop - BRICK - PLATE / 2, mid - BRICK * 1.2 } do
		for _, size in { Vector3.new(3.4, PLATE, 3.4), Vector3.new(4.4, PLATE, 2.2), Vector3.new(2.2, PLATE, 4.4) } do
			Core.part(b, hinge * CFrame.new(0, y, 0), size, look.bands, loose)
		end
	end
	-- The bottom: a smaller 2x2 brick under the barrel.
	Core.part(b, hinge * CFrame.new(0, bodyTop - height - PLATE / 2, 0), Vector3.new(2, PLATE, 2), look.bands, loose)
	target(b, hinge, 0, mid + 0.3, -2.06, 1.6)
	b:SetAttribute("Hinge", hinge)
	return cf * CFrame.new(0, PLATE, -1.5) * CFrame.Angles(0, math.pi, 0) -- facing the bag (clear of its bands)
end

function GymKit.station(parent, cf, key, set)
	local def = Training.StationByKey[key]
	local id = key .. "#" .. (#GymKit.List + 1)
	local m = Core.model(parent, "Station_" .. key, cf)
	m:SetAttribute("Station", key)
	m:SetAttribute("StationId", id)
	Core.tag(m, "TrainStation")
	base(m, cf, def, set)
	local look = LOOKS[key]
	local spot = (look.bag and bag or post)(m, cf, look)
	local p = prompt(m, spot.Position + Vector3.new(0, 3, 0), "Train", def.name)
	p.Name = "StationPrompt"
	p:SetAttribute("Station", key)
	table.insert(GymKit.List, { id = id, key = key, model = m, spot = spot, prompt = p })
	return m
end

-- A gear stall: a counter under a striped awning with the stall's sign, and in front two pedestals showing
-- the premium weights (Robux) spinning in a glowing aura, each with a Buy prompt (named "PremiumPrompt",
-- attribute Pass; the client prompts the purchase). The cash weights this stall stocks (`tiers`) are sold
-- from a window that opens when a player walks up (client/GearShop.lua; model tag "GearStall", attributes
-- StallIndex and Tiers).
local PREMIUM = {
	{ key = "DragonWeights", tier = 15, glow = rgb(90, 255, 120) },
	{ key = "ChakraWeights", tier = 14, glow = rgb(255, 130, 20) },
}
function GymKit.stall(parent, cf, set, tiers)
	local m = Core.model(parent, "GearStall", cf)
	local index = #GymKit.Stalls + 1
	m:SetAttribute("StallIndex", index)
	m:SetAttribute("Tiers", table.concat(tiers, ","))
	Core.tag(m, "GearStall")
	local wood, dark = set.wood and set.wood[1] or C.brown, set.wood and set.wood[2] or C.darkBrown
	Core.centered(m, cf, 0, 0, 3, 12, BRICK * 3, 3, wood)
	Core.centered(m, cf, 0, BRICK * 3, 3, 12.4, 0.4, 3.4, dark)
	for _, x in { -5.6, 5.6 } do
		Core.centered(m, cf, x, BRICK * 3, 3.8, 0.6, BRICK * 5, 0.6, dark)
	end
	for k = 0, 5 do
		Core.part(
			m,
			cf * CFrame.new(-5 + k * 2, BRICK * 8.4, 2.6) * CFrame.Angles(math.rad(-20), 0, 0),
			Vector3.new(2, 0.3, 4.4),
			k % 2 == 0 and (set.accent or C.red) or C.white,
			SMOOTH
		)
	end
	local sign = Core.part(m, cf * CFrame.new(0, BRICK * 9.6, 4.2), Vector3.new(8, BRICK * 1.4, 0.4), dark, SMOOTH)
	Core.label(sign, "TRAINING GEAR", Enum.NormalId.Front, C.yellow)
	for i, p in PREMIUM do
		local g = Training.Gear[p.tier]
		local x = (i - 1.5) * 9.5
		-- A gold-trimmed plinth with a glow ring on top.
		Core.centered(m, cf, x, 0, -3, 3.6, BRICK * 2, 3.6, C.darkGray)
		Core.centered(m, cf, x, BRICK * 2, -3, 4, 0.4, 4, C.gold, { material = Enum.Material.Metal })
		local ring = Core.part(
			m,
			cf * CFrame.new(x, BRICK * 2 + 0.45, -3) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.1, 3.6, 3.6),
			p.glow,
			{ shape = Enum.PartType.Cylinder, neon = true, collide = false }
		)
		-- The item floats high, big and spinning, in a pillar of light over a turning rune ring.
		local at = cf * CFrame.new(x, BRICK * 2 + 4.6, -3)
		local display = Instance.new("Model")
		display.Name = "Display"
		for _, dx in { -1.1, 1.1 } do
			local band = GearLook.band(g.look, 2, 1.5)
			band:PivotTo(at * CFrame.new(dx, 0, 0) * CFrame.Angles(0, 0, 0.3))
			for _, part in band:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			band.Parent = display
		end
		display.WorldPivot = at
		display.Parent = m
		Core.tag(display, "Spin")
		display:SetAttribute("Speed", 1.6)
		-- The pillar of light (KitMotion's LightPillar shimmer) from the plinth up past the item.
		local pillar = Core.part(
			m,
			cf * CFrame.new(x, BRICK * 2 + 5, -3) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(10, 2.6, 2.6),
			p.glow,
			{
				shape = Enum.PartType.Cylinder,
				neon = true,
				collide = false,
				trans = 0.9,
				tag = "LightPillar",
				shadow = false,
			}
		)
		pillar:SetAttribute("Base", 0.9)
		-- A rune ring of neon ticks turning on the plinth.
		local rune = Instance.new("Model")
		rune.Name = "Rune"
		local runeAt = cf * CFrame.new(x, BRICK * 2 + 0.55, -3)
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			Core.part(
				rune,
				runeAt * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.9),
				Vector3.new(0.5, 0.08, 0.25),
				k % 2 == 0 and p.glow or C.white,
				{ neon = true, collide = false }
			)
		end
		rune.WorldPivot = runeAt
		rune.Parent = m
		Core.tag(rune, "Spin")
		rune:SetAttribute("Speed", -2.5)
		-- The aura: a fire swirl, a fountain of sparks, falling stardust and strong light.
		Core.particles(ring, {
			texture = "fire",
			color = p.glow,
			size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.2) }),
			rate = 30,
			life = { 0.6, 1.1 },
			speed = 4,
			spread = 14,
			accel = Vector3.new(0, 8, 0),
			rotSpeed = 180,
			lightEmission = 1,
		})
		Core.particles(ring, {
			color = Color3.new(1, 1, 1),
			size = 0.55,
			rate = 22,
			life = { 0.8, 1.6 },
			speed = 9,
			spread = 30,
			accel = Vector3.new(0, -10, 0),
			lightEmission = 1,
		})
		local dust =
			Core.part(m, at * CFrame.new(0, 3, 0), Vector3.new(4, 0.2, 4), C.white, { trans = 1, collide = false })
		Core.particles(dust, {
			color = p.glow,
			size = 0.3,
			rate = 14,
			life = { 1.5, 2.5 },
			speed = 0.6,
			spread = 180,
			accel = Vector3.new(0, -1.5, 0),
			lightEmission = 1,
		})
		Core.light(ring, p.glow, 14, 2.2)
		-- A floating rarity sign the client animates (tag "FancySign": rainbow text, bobbing).
		local floater = Instance.new("BillboardGui")
		floater.Name = "FancySign"
		-- Small and high: up close a big sign filled the whole screen.
		floater.Size = UDim2.fromScale(3.4, 1.35)
		floater.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
		floater.MaxDistance = 45
		floater.LightInfluence = 0
		floater.AlwaysOnTop = false
		floater.Adornee = pillar
		floater:SetAttribute("Rarity", string.upper(Training.gearRarity(p.tier)))
		floater:SetAttribute("Title", string.upper(g.name))
		floater:SetAttribute("Price", "x" .. g.mult)
		floater.Parent = m
		Core.tag(floater, "FancySign")
		local tag =
			Core.part(m, cf * CFrame.new(x, BRICK * 2 - 0.9, -4.85), Vector3.new(3.4, 0.9, 0.2), C.black, SMOOTH)
		Core.label(tag, string.upper(g.name), Enum.NormalId.Front, p.glow)
		local buy = prompt(m, at.Position, "Buy", g.name .. "  ·  x" .. g.mult)
		buy.Name = "PremiumPrompt"
		buy.MaxActivationDistance = 7
		buy:SetAttribute("Pass", p.key)
	end
	table.insert(GymKit.Stalls, { tiers = tiers, position = cf.Position, model = m })
	return m
end

return GymKit
