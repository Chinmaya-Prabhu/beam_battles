-- Builds Sky Dojo, the hub island, from the Brick Kit (docs/WORLD_PLAN.md §8; layout in Config.Island).
-- Lower ring: spawn, ring road, the drop altars with their clash pads, zone gates on piers, bridges out
-- to the 8 plot islets. Middle terrace: the Colosseum and the market street round it. North: the Summit
-- Pagoda on its plateau. Above it all, the drop portal.
-- Returns what the services need: { root, altars, pads, plots, portal, colosseum } (same as the old World).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local Format = require(ReplicatedStorage.Shared.Format)
local K = require(script.Parent.BrickKit)
local Ocean = require(script.Parent.Ocean)
local GymKit = require(script.Parent.Zones.GymKit)
local BeamSkins = require(ReplicatedStorage.Shared.BeamSkins)

local Hub = {}
local I = Config.Island
local set = Bricks.Zones.Hub
local C = Bricks.C
local BRICK, PLATE = K.Core.BRICK, K.Core.PLATE
local CENTER = Vector3.zero
local SIDE_COLORS = { Color3.fromRGB(70, 150, 255), Color3.fromRGB(255, 80, 70) }

local function polar(deg, r, y)
	local a = math.rad(deg)
	return Vector3.new(math.cos(a) * r, y or 0, math.sin(a) * r)
end

-- Facing the centre (front = -Z toward the hub).
local function inward(pos)
	return CFrame.lookAt(pos, Vector3.new(CENTER.X, pos.Y, CENTER.Z))
end

-- Facing away from the centre.
local function outward(pos)
	return CFrame.lookAt(pos, Vector3.new(pos.X * 2, pos.Y, pos.Z * 2))
end

local function folder(parent, name, class)
	local f = Instance.new(class or "Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- The wobbly rim radius at an angle (radians), so the island edge isn't a perfect circle.
local function rimAt(a)
	return I.radius + math.sin(a * 5) * 4 + math.sin(a * 3 + 1) * 3
end

-- Places kept clear when scattering trees and props: { position, radius }.
local reserved = {}
local function reserve(pos, r)
	table.insert(reserved, { Vector3.new(pos.X, 0, pos.Z), r })
end
local function free(pos, r)
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, c in reserved do
		if (flat - c[1]).Magnitude < r + c[2] then
			return false
		end
	end
	return true
end

local function ground(root)
	local R, M = I.radius, I.middle.radius
	local function lower(x, z)
		return math.sqrt(x * x + z * z) <= rimAt(math.atan2(z, x))
	end
	local function middle(x, z)
		local a = math.atan2(z, x)
		return math.sqrt(x * x + z * z) <= M + math.sin(a * 4 + 2) * 2.5
	end
	K.Core.seed(1)
	-- Both landmasses use bounds that are multiples of the 4-stud cell, so their grids line up and the
	-- lower grass stops exactly where the middle terrace begins.
	local function bound(r)
		return math.ceil(r / 4) * 4
	end
	-- The big open island: 8-stud cells keep the part count sane at this size. Its grass runs a little under
	-- the plaza's edge, so the two grids never leave a gap at the plaza's foot.
	local function underPlaza(x, z)
		return math.sqrt(x * x + z * z) <= M - 10
	end
	K.Terrain.landmass(root, CFrame.new(0, 0, 0), math.ceil((R + 12) / 8) * 8, lower, 16, set, {
		under = 12, -- (the rest would be under the sea: server/Ocean.lua)
		cell = 8,
		top = function(x, z)
			return lower(x, z) and not underPlaza(x, z)
		end,
	})
	K.Terrain.landmass(root, CFrame.new(0, I.middle.height, 0), bound(M + 6), middle, I.middle.height + BRICK, set)
	-- Summit plateau (north) for the pagoda: a cliff block rising from the lower ring.
	local s = I.summit
	K.Terrain.terrace(root, CFrame.new(s.center), s.size.X, s.size.Y, s.center.Y + BRICK, set, { tiles = "coarse" })
end

local function roads(root)
	local mid = I.middle
	K.Terrain.ringPath(root, CFrame.new(0, 0, 0), I.lowerRoad, 6, set, { gaps = { { 84, 96 } } })
	K.Terrain.ringPath(root, CFrame.new(0, mid.height, 0), mid.road, 8, set)
	-- Grand stairs from the lower ring onto the middle terrace (east, south, west), with paths to the road.
	for _, deg in { 0, 90, 180 } do
		local bottom = polar(deg, mid.radius + 8)
		K.Terrain.stairs(root, inward(bottom), 16, 4, set, { rails = set.accent })
		reserve(bottom, 12)
		local top = polar(deg, mid.radius, mid.height)
		K.Terrain.path(root, inward(top), mid.radius - mid.road - 4, 8, set)
	end
	-- Stairs up to the summit plateau.
	local s = I.summit
	local front = s.center.Z + s.size.Y / 2
	K.Terrain.stairs(
		root,
		CFrame.lookAt(Vector3.new(0, mid.height, front + 8), Vector3.new(0, mid.height, front - 10)),
		12,
		4,
		set,
		{ rails = set.accent }
	)
	-- Spawn plaza and the path north to the stairs.
	local sp = I.spawn
	K.Terrain.path(root, CFrame.new(sp.X, 0, sp.Z + 8), 14, 26, set)
	K.Terrain.path(root, CFrame.new(sp.X, 0, sp.Z - 6), sp.Z - 6 - (mid.radius + 8), 10, set)
	reserve(sp, 16)
	for z = mid.radius + 10, sp.Z, 12 do
		reserve(Vector3.new(0, 0, z), 7)
	end
	-- Paths out to the Training (west) and Shopping (east) districts, and north to the zone gates.
	for _, deg in { I.training.angle, I.shops.angle } do
		local from, to = I.lowerRoad + 3, (deg == I.training.angle and I.training.dist or I.shops.dist) - 26
		K.Terrain.path(root, CFrame.lookAt(polar(deg, from), polar(deg, to)), to - from, 10, set)
		for r = from, to, 10 do
			reserve(polar(deg, r), 7)
		end
	end
	local gateRow = I.radius - 45
	K.Terrain.path(
		root,
		CFrame.lookAt(polar(270, I.lowerRoad + 3), polar(270, gateRow)),
		gateRow - I.lowerRoad - 3,
		10,
		set
	)
	for r = I.lowerRoad + 3, gateRow, 10 do
		reserve(polar(270, r), 7)
	end
	-- The gate row: an arc path joining the four gates.
	local first, last = I.gates[1].angle, I.gates[#I.gates].angle
	K.Terrain.ringPath(root, CFrame.new(0, 0, 0), gateRow, 8, set, { gaps = { { 0, first - 2 }, { last + 2, 360 } } })
end

-- An altar with its two clash pads, wired the way DropService and ClashService expect:
-- Model "Altar<i>" (Tier, Index) with a Top part holding FighterStand + RarityLight; pads are markers.
-- `cf` stands the altar on the ground facing its front (-Z); its clash pads go 17 studs to either side.
-- `sky` is where its drop beam starts (the portal above it). Zones build their altars with this too.
function Hub.altar(parent, index, cf, tierName, zoneSet, sky, facing)
	local spec = { tier = tierName }
	local zs = zoneSet or set
	local tier = Config.Tiers[spec.tier]
	local base = cf.Position
	local m = folder(parent, "Altar" .. index, "Model")
	m:SetAttribute("Tier", spec.tier)
	m:SetAttribute("Sky", sky or Vector3.new(0, I.portal.height, 0))
	m:SetAttribute("Facing", facing or -cf.LookVector) -- the way a dropped fighter faces
	m:SetAttribute("Index", index)
	local _, standCF = K.Play.altar(m, cf, zs, tier.trim, true)
	local top = K.Core.part(
		m,
		standCF * CFrame.new(0, -0.1, 0),
		Vector3.new(6, 0.2, 6),
		tier.trim,
		{ trans = 1, collide = false, name = "Top" }
	)
	local stand = Instance.new("Attachment")
	stand.Name = "FighterStand"
	stand.Parent = top
	stand.WorldPosition = standCF.Position
	local light = Instance.new("PointLight")
	light.Name = "RarityLight"
	light.Range = 16
	light.Brightness = 0
	light.Parent = top
	m.PrimaryPart = top
	-- Tier sign on the front step.
	local sign = K.Core.part(
		m,
		cf * CFrame.new(0, BRICK * 1.5, -9.3),
		Vector3.new(tier.power > 0 and 12 or 8, BRICK * 1.4, 0.4),
		C.black,
		{ smooth = true }
	)
	-- The tier, and the Power it takes to sit here (ClashService checks it).
	local need = tier.power > 0 and ("  ·  " .. Format.short(tier.power) .. " POWER") or ""
	K.Core.label(sign, string.upper(spec.tier) .. need, Enum.NormalId.Front, tier.trim)
	reserve(base, 13)
	local pads = {}
	for side, sx in { -1, 1 } do
		local padPos = (cf * CFrame.new(sx * 17, 0, 0)).Position
		local _, surface = K.Play.clashPad(m, CFrame.lookAt(padPos, base), zs, SIDE_COLORS[side])
		local marker =
			K.Core.part(m, surface, Vector3.new(4, 0.2, 4), C.white, { trans = 1, collide = false, name = "ClashPad" })
		marker:SetAttribute("Side", side)
		pads[side] = marker
		reserve(padPos, 7)
	end
	return m, pads
end

-- A player's base, open and spacious so the fighters are what you see: one flat dark plate on the grass (96 x
-- 118), every base the same dark slate so the fighters and their auras stand out, a carpet down the middle from the torii (hub side, -Z) to the back, and two
-- rows of stands facing each other across it, well apart. Nothing stands inside the base. FLOOR 2 (the Floor
-- 2 pass, like Steal a Brainrot's) is a thin slab high above on four slim posts at the corners only, with
-- the same eight stands (slots 11-18), reached by a ladder inside the back of the base up through a hatch; it stays hidden until the owner
-- has the pass (server/Services/PlotService.lua shows it), and until then a FLOOR 2 offer stands at the back.
-- Stands are Models "Stand<k>" (Slot k; Pass = the pass that opens it) holding a Pedestal and a CollectPad.
local COLUMN_X = 30 -- pedestal centres at x = -30 and 30; each faces the carpet, its pad 6 studs toward it
local STAND_Z = { -38, -18, 2, 22 } -- along each row, entrance to back, 20 apart
local EXTRA_Z = 42 -- slots 9-10, at the back of each row
local FLOOR_H = 36 -- Floor 2's surface above the ground floor (tall: the base looks big and the ground floor open)
local HATCH = 7 -- the square hole in Floor 2 the ladder comes up through, at the back of the carpet
-- One dark slate for every base (the base's own colour is only on its beacon, client/BaseBeacon.lua).
local SLATE = {
	floor = Color3.fromRGB(30, 32, 42),
	rim = Color3.fromRGB(46, 50, 64),
	carpet = Color3.fromRGB(40, 43, 56),
	post = Color3.fromRGB(56, 60, 76),
	stand = Color3.fromRGB(36, 38, 50),
	trim = Color3.fromRGB(52, 56, 72),
	cap = Color3.fromRGB(72, 76, 94),
	ladder = Color3.fromRGB(110, 116, 138),
}

local function plot(parent, index, deg)
	local center = polar(deg, I.plotRadius)
	-- On the open grass like every other base (no islet, no bridge), so everyone sees everyone's fighters.
	local cf = inward(center) + Vector3.new(0, PLATE + 0.05, 0)
	local w, d = I.plotSize.X, I.plotSize.Y
	local m = folder(parent, "Plot" .. index, "Model")
	m:SetAttribute("Index", index)
	m:SetAttribute("Frame", cf) -- ground centre, front (-Z) toward the hub (server/Services/PlotService.lua)
	K.Core.seed(200 + index)
	-- One flat floor with a thin rim in the base's colour, and the carpet down the middle.
	K.Core.centered(m, cf, 0, -PLATE - 0.05, 0, w + 2, PLATE - 0.2, d + 2, SLATE.rim, { smooth = true }) -- (lower than the floor: surfaces a hair apart flicker)
	K.Core.centered(m, cf, 0, -PLATE - 0.05, 0, w, PLATE + 0.05, d, SLATE.floor, { smooth = true })
	K.Core.centered(m, cf, 0, 0, 0, 16, 0.15, d, SLATE.carpet, { smooth = true, collide = false })
	local stands = folder(m, "Stands")
	local function stand(slot, at, trim, pass)
		local s = folder(stands, "Stand" .. slot, "Model")
		s:SetAttribute("Slot", slot)
		if pass then
			s:SetAttribute("Pass", pass)
		end
		K.Play.pedestal(s, at, { stone = { SLATE.stand } }, trim, SLATE.cap)
		K.Play.collectPad(s, at * CFrame.new(0, 0, -6))
	end
	-- A stand in a row (side -1 left, 1 right) at z on floor `base`, turned to face the carpet.
	local function facing(base, side, z)
		return base * CFrame.new(side * COLUMN_X, 0, z) * CFrame.Angles(0, side * math.pi / 2, 0)
	end
	local slot = 0
	for _, z in STAND_Z do
		for _, side in { -1, 1 } do
			slot += 1
			stand(slot, facing(cf, side, z), SLATE.trim)
		end
	end
	for _, side in { -1, 1 } do
		slot += 1
		stand(slot, facing(cf, side, EXTRA_Z), SLATE.trim, "ExtraStands")
	end

	-- In front of where the ladder goes: the FLOOR 2 offer (PlotService puts the purchase prompt on it).
	local offer = K.Core.centered(m, cf, 0, 0, d / 2 - 14, 7, PLATE, 5, C.gold, { smooth = true, name = "Floor2Offer" })
	offer.Material = Enum.Material.Neon

	-- Floor 2: one thin slab on four slim corner posts, a low rim, and a hatch at the back of the carpet with
	-- the ladder standing in it, climbed from inside the base (its climbing face looks toward the torii).
	local top = cf * CFrame.new(0, FLOOR_H, 0)
	local floor2 = folder(m, "Floor2", "Model")
	local h0, h1 = d / 2 - 2 - HATCH, d / 2 - 2 -- the hatch's front and back edges (z), centred on x = 0
	local function slab(x0, x1, z0, z1)
		K.Core.box(floor2, top, x0, -0.8, z0, x1 - x0, 0.6, z1 - z0, SLATE.rim, { smooth = true })
		K.Core.box(floor2, top, x0, -0.2, z0, x1 - x0, 0.25, z1 - z0, SLATE.floor, { smooth = true })
	end
	slab(-w / 2 - 1, w / 2 + 1, -d / 2 - 1, h0)
	slab(-w / 2 - 1, w / 2 + 1, h1, d / 2 + 1)
	slab(-w / 2 - 1, -HATCH / 2, h0, h1)
	slab(HATCH / 2, w / 2 + 1, h0, h1)
	K.Core.box(floor2, top, -8, 0.05, -d / 2, 16, 0.15, h0 + d / 2, SLATE.carpet, { smooth = true, collide = false })
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			K.Core.centered(floor2, cf, x, 0, z, 1.6, FLOOR_H - 0.8, 1.6, SLATE.post, { smooth = true })
		end
	end
	local function rail(x0, x1, z0, z1)
		K.Core.box(floor2, top, x0, 0, z0, x1 - x0, 1.6, z1 - z0, SLATE.post, { smooth = true })
	end
	rail(-w / 2 - 1, w / 2 + 1, -d / 2 - 1, -d / 2 - 0.6)
	rail(-w / 2 - 1, w / 2 + 1, d / 2 + 0.6, d / 2 + 1)
	rail(-w / 2 - 1, -w / 2 - 0.6, -d / 2 - 1, d / 2 + 1)
	rail(w / 2 + 0.6, w / 2 + 1, -d / 2 - 1, d / 2 + 1)
	-- The ladder against the hatch's back edge, a little above the deck so stepping off at the top is easy.
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, FLOOR_H + 2, 2)
	ladder.CFrame = cf * CFrame.new(0, (FLOOR_H + 2) / 2, h1 - 1)
	ladder.Color = SLATE.ladder
	ladder.Parent = floor2
	for _, z in STAND_Z do
		for _, side in { -1, 1 } do
			slot += 1
			stand(slot, facing(top, side, z), SLATE.trim, "Floor2")
		end
	end

	-- The torii with the owner's name at the front: the only thing standing up on the ground floor.
	K.Build.torii(m, cf * CFrame.new(0, 0, -d / 2 + 2), 16, 14, { color = SLATE.post, label = "EMPTY PLOT" })
	-- The owner's own punching post just inside the gate (left; the boombox is right). Only its owner sees
	-- it and can use it (client/Plots.lua hides the others', TrainingService checks).
	local post = GymKit.station(m, cf * CFrame.new(-18, 0, -d / 2 + 10), "PunchPost", set)
	post:SetAttribute("Plot", index)
	reserve(center, 84)
	return m
end

local function gate(root, spec)
	local a = math.rad(spec.angle)
	local rim = rimAt(a)
	local pier = polar(spec.angle, rim + 6, BRICK)
	local cf = outward(pier)
	K.Terrain.terrace(root, cf, 36, 18, BRICK + 10, set, { tiles = "coarse", strata = set.stone })
	K.Terrain.underside(root, cf * CFrame.new(0, -BRICK - 10, 0), 36, 18, 18, set)
	local gateModel =
		K.Play.zoneGate(root, cf * CFrame.new(0, 0, 2), set, spec.title, not spec.open, spec.zone, spec.color)
	-- The pier in the gate's colour (a studded floor up to the gate), so each gate reads from afar.
	K.Core.centered(root, cf, 0, 0, 6.5, 30, PLATE, 5, spec.color or set.accent)
	gateModel:SetAttribute("Trigger", (cf * CFrame.new(0, 3, 2)).Position)
	-- A short path from the gate row to the pier.
	local rowR = I.radius - 41
	local start = polar(spec.angle, rowR)
	K.Terrain.path(root, CFrame.lookAt(start, polar(spec.angle, rim + 10)), math.floor(rim - rowR - 1), 6, set)
	for r = rowR - 4, rim + 12, 6 do
		reserve(polar(spec.angle, r), 9)
	end
end

local function colosseum(root)
	local cf = CFrame.new(0, I.middle.height, 0)
	local m =
		K.Play.colosseum(root, cf, set, { stage = I.colosseum.stage, inner = I.colosseum.inner, title = "COLOSSEUM" })
	return m
end

local function market(root)
	local mid = I.middle
	for i, shop in I.market do
		local pos = polar(shop.angle, mid.road + 14, mid.height)
		K.Core.seed(300 + i)
		K.Build.shopFront(
			root,
			inward(pos),
			10,
			set,
			{ title = shop.title, stripes = { i % 2 == 0 and C.vermilion or C.azure, C.white } }
		)
	end
end

-- The Fighter Market (server/Services/MarketService.lua): five plinths in an arc on the market street
-- by the south stairs, fighters on show for Robux, a big sign and the restock countdown. The middle plinth
-- (slot 5, gold and taller) is the featured one. Returns { spots = { [slot] = feet CFrame }, rings, countdown }.
-- The Shopping district's frame: on the grass east of the plaza, front (-Z) toward the plaza.
local function shopsFrame()
	return inward(polar(I.shops.angle, I.shops.dist))
end

local MARKET_SLOTS = { { -30, 4 }, { -15, 1 }, { 15, 1 }, { 30, 4 }, { 0, -1 } } -- slot -> (x, z); 5 = featured
local function fighterMarket(root)
	local m = folder(root, "FighterMarket", "Model")
	local out = { spots = {}, rings = {} }
	local mcf = shopsFrame() * CFrame.new(-32, 0, -4) -- the left half of the district, as seen from the plaza
	K.Core.centered(m, mcf, 0, -0.25, 1, 76, PLATE, 22, Bricks.mute(C.vermilion:Lerp(C.white, 0.55)), { smooth = true })
	for slot, xz in MARKET_SLOTS do
		local featured = slot == 5
		local cf = mcf * CFrame.new(xz[1], 0, xz[2])
		local h = featured and BRICK * 4 or BRICK * 2.5
		local w = featured and 7 or 5.6
		K.Core.centered(m, cf, 0, 0, 0, w + 1, PLATE, w + 1, C.darkGray)
		K.Core.centered(
			m,
			cf,
			0,
			PLATE,
			0,
			w,
			h,
			w,
			featured and C.gold or C.darkGray,
			{ material = featured and Enum.Material.Metal or nil }
		)
		K.Core.centered(
			m,
			cf,
			0,
			PLATE + h,
			0,
			w + 0.4,
			0.4,
			w + 0.4,
			featured and C.white or C.gold,
			{ material = Enum.Material.Metal }
		)
		local ring = K.Core.part(
			m,
			cf * CFrame.new(0, PLATE + h + 0.45, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(0.1, w, w),
			C.white,
			{ shape = Enum.PartType.Cylinder, neon = true, collide = false }
		)
		out.rings[slot] = ring
		out.spots[slot] = cf * CFrame.new(0, PLATE + h + 0.5, 0)
		reserve(cf.Position, 6)
	end
	-- The sign high over the arc (above the tallest fighter on show, MarketService caps them), facing the road.
	local signCf = mcf * CFrame.new(0, 0, 9)
	for _, x in { -13, 13 } do
		K.Core.centered(m, signCf, x, 0, 0, 1.4, 35, 1.4, C.darkBrown)
		K.Core.centered(m, signCf, x, 35, 0, 2, 1, 2, C.gold, { material = Enum.Material.Metal })
	end
	-- A deep navy board in a gold frame, white letters with a dark outline: readable from both sides.
	local navy = Color3.fromRGB(28, 32, 58)
	local board = K.Core.part(m, signCf * CFrame.new(0, 31, 0), Vector3.new(28, 5.5, 1), navy, { smooth = true })
	K.Core.part(m, signCf * CFrame.new(0, 31, 0), Vector3.new(29, 6.5, 0.6), C.gold, { material = Enum.Material.Metal })
	local clock = K.Core.part(m, signCf * CFrame.new(0, 26.6, 0), Vector3.new(17, 2.8, 0.8), navy, { smooth = true })
	out.countdown = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local title = K.Core.label(board, "FIGHTER MARKET", face, C.white, Color3.fromRGB(10, 10, 24))
		title.Parent.LightInfluence = 0
		local timer =
			K.Core.label(clock, "NEW STOCK IN 5:00", face, Color3.fromRGB(255, 214, 90), Color3.fromRGB(10, 10, 24))
		timer.Parent.LightInfluence = 0
		table.insert(out.countdown, timer)
	end
	reserve(signCf.Position, 8)
	return out
end

-- The Beam Shrine (server/Services/BeamShrineService.lua, client/BeamShrine.lua): the beam skins on show for
-- an impulse buy. Six pylons on an arc behind a round floor, each firing its skin's real beam into a floating
-- orb over the middle. Returns { pylons = { { skin, at (beam start), anchor (prompt part), model } }, orb }.
local function beamShrine(root)
	local m = folder(root, "BeamShrine", "Model")
	local cf = shopsFrame() * CFrame.new(46, 0, 4) -- the right half, beside the market (never behind it)
	-- A dark wall behind the pylons, so each beam reads against it instead of washing into the sky.
	K.Core.centered(m, cf, 0, 0, 15.5, 34, 18, 1.2, Color3.fromRGB(26, 20, 44), { smooth = true })
	for _, x in { -17.5, 17.5 } do
		K.Core.centered(m, cf, x, 0, 12, 1.2, 18, 8, Color3.fromRGB(26, 20, 44), { smooth = true })
	end
	-- The floor: a dark disc with a gold ring.
	K.Core.cyl(m, cf, 0, 0, 0, 28, PLATE, C.darkGray)
	K.Core.cyl(m, cf, 0, PLATE, 0, 25, 0.1, C.gold, { material = Enum.Material.Metal })
	K.Core.cyl(m, cf, 0, PLATE + 0.1, 0, 24.4, 0.1, Color3.fromRGB(30, 26, 48))
	local out = { pylons = {} }
	local n = #BeamSkins.List
	for i, skin in BeamSkins.List do
		local a = math.rad(-78 + (i - 1) * 156 / (n - 1))
		local pcf = cf * CFrame.new(math.sin(a) * 10.5, PLATE, math.cos(a) * 10.5)
		local pm = K.Core.model(m, "Pylon_" .. skin.key, pcf)
		pm:SetAttribute("Skin", skin.key)
		K.Core.cyl(pm, pcf, 0, 0, 0, 3.2, BRICK, C.darkGray)
		K.Core.cyl(pm, pcf, 0, BRICK, 0, 2.6, 0.3, C.gold, { material = Enum.Material.Metal })
		K.Core.cyl(pm, pcf, 0, BRICK + 0.3, 0, 1.5, 4.5, Color3.fromRGB(40, 36, 60))
		-- Neon rings in the skin's colour, so each pylon reads as its beam.
		for _, y in { 1.2, 2.6, 4 } do
			K.Core.cyl(pm, pcf, 0, BRICK + 0.3 + y, 0, 1.62, 0.22, skin.glow, { neon = true, collide = false })
		end
		K.Core.cyl(pm, pcf, 0, BRICK + 4.8, 0, 2.2, 0.4, C.gold, { material = Enum.Material.Metal })
		K.Core.cyl(pm, pcf, 0, BRICK + 0.3, 0, 1.6, 0.25, skin.glow, { neon = true, collide = false })
		local at = (pcf * CFrame.new(0, BRICK + 6.6, 0)).Position
		local crystal = K.Core.part(
			pm,
			CFrame.new(at) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Vector3.new(1.4, 1.4, 1.4),
			skin.glow:Lerp(Color3.new(1, 1, 1), 0.3),
			{ neon = true, collide = false, tag = "Spin" }
		)
		crystal:SetAttribute("Speed", 2)
		K.Core.light(crystal, skin.glow, 12, 1.5)
		local anchor = K.Core.part(
			pm,
			pcf * CFrame.new(0, 3, 0),
			Vector3.new(1, 1, 1),
			C.white,
			{ trans = 1, collide = false, name = "PromptAnchor" }
		)
		table.insert(out.pylons, { skin = skin.key, at = at, anchor = anchor, model = pm })
		reserve(pcf.Position, 3)
	end
	-- The orb the beams meet in, over the middle of the floor.
	out.orb = (cf * CFrame.new(0, 10, -9)).Position -- out in front, so each beam is long and reads clearly
	-- The sign behind the arc, facing the road.
	local back = cf * CFrame.new(0, 0, 14.6)
	for _, x in { -9, 9 } do
		K.Core.centered(m, back, x, 0, 0, 1.2, 21, 1.2, C.darkBrown)
	end
	local board = K.Core.part(
		m,
		back * CFrame.new(0, 19, 0),
		Vector3.new(19, 4.2, 0.6),
		Color3.fromRGB(60, 30, 110),
		{ smooth = true }
	)
	K.Core.label(board, "BEAM SHRINE", Enum.NormalId.Front, C.yellow)
	K.Core.part(m, back * CFrame.new(0, 19, 0.1), Vector3.new(20, 5.2, 0.4), C.gold, { material = Enum.Material.Metal })
	local note = K.Core.part(m, back * CFrame.new(0, 15.6, 0), Vector3.new(14, 1.8, 0.5), C.darkGray, { smooth = true })
	K.Core.label(note, "BEAM SKINS · LOOKS ONLY", Enum.NormalId.Front, C.white)
	reserve(cf.Position, 22)
	return out
end

local function summit(root)
	local s = I.summit
	local cf = CFrame.new(s.center)
	K.Core.seed(400)
	local _, height = K.Build.pagoda(root, cf * CFrame.new(0, 0, -1), 5, 16, set, { glow = true, lanterns = true })
	-- The dragon coils up the pagoda and looks out over the hub toward spawn.
	K.Dragon.coil(
		root,
		cf * CFrame.new(0, 0, -1),
		{ radius = 22, y0 = 4, y1 = height - 9, turns = 1.75, faceDeg = 90, headScale = 1.4 }
	)
	reserve(s.center, 26)
end

local function portal(root)
	local m = K.Play.dropPortal(root, CFrame.new(0, I.portal.height, 0), I.portal.radius, set)
	m.Name = "Portal"
	-- Countdown board hanging under the portal; the client writes the time (Ambience).
	local anchor = K.Core.part(
		m,
		CFrame.new(0, I.portal.height - 10, 0),
		Vector3.one,
		C.gold,
		{ trans = 1, collide = false, name = "CountdownAnchor" }
	)
	local board = Instance.new("BillboardGui")
	board.Name = "Countdown"
	board.Size = UDim2.fromScale(40, 10)
	board.LightInfluence = 0
	board.MaxDistance = 1000
	board.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(60, 20, 90)
	text.Text = "NEXT DROP"
	text.Parent = board
	return m
end

local function spawn(root)
	local sp = I.spawn
	K.Build.torii(
		root,
		CFrame.new(sp.X, 0, sp.Z - 8) * CFrame.Angles(0, math.pi, 0),
		16,
		18,
		{ color = C.vermilion, label = "ANIME BEAM BATTLE" }
	)
	local pad = workspace:FindFirstChild("SpawnPad")
	if pad and pad:IsA("BasePart") then
		pad.CFrame = CFrame.new(sp + Vector3.new(0, PLATE + 0.5, 0))
	end
end

-- The Training district on the grass west of the plaza (docs/TRAINING_PLAN.md): two training grounds side by
-- side (a punching post and a sandbag either side of a gear stall, a giant weight plate behind) and the
-- Practice Dojo behind them, where the tutorial teaches stealing.
local function trainingFrame()
	return inward(polar(I.training.angle, I.training.dist))
end

local function trainingGround(root, gcf, tiers)
	-- The ground's orange floor under the stations, the stall and the landmark. The two stations stand
	-- out front with room to walk between them; the gear stall sits back, out of the way to the posts.
	K.Core.centered(root, gcf, 0, -0.2, 8, 56, PLATE, 36, Bricks.mute(C.orange))
	GymKit.station(root, gcf * CFrame.new(-22, 0, 0), "PunchPost", set)
	GymKit.station(root, gcf * CFrame.new(22, 0, 0), "Sandbag", set)
	GymKit.stall(root, gcf * CFrame.new(0, 0, 16), set, tiers) -- well back from the post and bag
	local face = gcf * CFrame.new(0, 0, 27)
	local m = folder(root, "TrainingLandmark", "Model")
	K.Core.centered(m, face, 0, 0, 0, 12, BRICK * 2, 6, set.stone[1])
	local disc = face * CFrame.new(0, BRICK * 2 + 8, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local metal = { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal }
	K.Core.part(m, disc, Vector3.new(2.4, 16, 16), C.darkGray, metal)
	K.Core.part(m, disc, Vector3.new(2.6, 6, 6), C.orange, { shape = Enum.PartType.Cylinder, smooth = true })
	K.Core.part(m, disc, Vector3.new(2.8, 2, 2), C.darkGray, metal)
end

local function gym(root)
	local tcf = trainingFrame()
	for _, x in { -42, 42 } do -- two grounds with open grass between them
		trainingGround(root, tcf * CFrame.new(x, 0, 0), I.training.tiers)
	end
	reserve(tcf.Position, 75)
end

local function waterfalls(root)
	for _, deg in I.waterfalls do
		local a = math.rad(deg)
		local lip = polar(deg, rimAt(a) - 1)
		K.Terrain.waterfall(root, outward(lip), 60, 8, set)
		reserve(polar(deg, rimAt(a) - 6), 9)
	end
end

-- One big floating word over each place (like Anime Dice's), readable from across the island, instead of
-- signposts; and the update board beside the spawn path.
local DROPS = Color3.fromRGB(255, 205, 60)
local function word(root, pos, text, color)
	local anchor =
		K.Core.part(root, CFrame.new(pos), Vector3.one, C.white, { trans = 1, collide = false, name = "PlaceWord" })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(#text * 4 + 8, 9)
	gui.LightInfluence = 0
	gui.MaxDistance = 500
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 14, 30)
	stroke.Parent = t
end

local function signs(root)
	word(root, polar(90, I.altarRadius, 30), "DROPS", DROPS)
	-- Over the middle of the Colosseum: what is coming for it.
	local middle = Vector3.new(0, I.middle.height, 0)
	word(root, middle + Vector3.new(0, 24, 0), "RANKED MATCHES", Color3.fromRGB(255, 120, 110))
	word(root, middle + Vector3.new(0, 14, 0), "COMING SOON", Color3.fromRGB(255, 205, 60))
	word(root, polar(I.training.angle, I.training.dist, 34), "TRAINING", C.orange)
	word(root, polar(I.shops.angle, I.shops.dist, 34), "SHOP", Color3.fromRGB(255, 110, 90))
	word(root, polar(275, I.radius - 30, 40), "ZONES", Color3.fromRGB(190, 150, 255))
	word(root, polar(166, I.plotRadius, 46), "BASES", Color3.fromRGB(120, 255, 150))
	word(root, polar(14, I.plotRadius, 46), "BASES", Color3.fromRGB(120, 255, 150))
	-- The update board beside the spawn path: the countdown to the next Saturday update and what it brings
	-- (client/UpdateBoard.lua draws the text on the panel named "UpdateBoard").
	local sp = I.spawn
	local boardAt = Vector3.new(sp.X - 24, 0, sp.Z - 8)
	local bcf = CFrame.lookAt(boardAt, Vector3.new(sp.X, 0, sp.Z + 6))
	local board = folder(root, "UpdateBoardStand", "Model")
	for _, x in { -7.5, 7.5 } do
		K.Core.centered(board, bcf, x, 0, 0, 1.2, 13, 1.2, C.darkBrown)
	end
	K.Core.part(board, bcf * CFrame.new(0, 9.5, 0), Vector3.new(17, 8, 0.8), C.gold, { material = Enum.Material.Metal })
	local panel = K.Core.part(
		board,
		bcf * CFrame.new(0, 9.5, -0.45),
		Vector3.new(16, 7, 0.2),
		Color3.fromRGB(30, 20, 55),
		{ smooth = true, name = "UpdateBoard" }
	)
	panel.Material = Enum.Material.Neon
	reserve(boardAt, 8)
end

-- A few trees near the rim, framing the island; the open grass stays empty so it reads big and calm.
-- The island's edge: a low stone kerb along the rim so you can see where the world ends, and an invisible
-- wall above it so nobody falls off (the zone gates' piers stick out past the rim: walled round instead).
local function invisibleWall(parent, cf, size)
	local p = Instance.new("Part")
	p.Name = "EdgeWall"
	p.Anchored = true
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
end
local function edge(root)
	local function nearGate(deg, pad)
		for _, g in I.gates do
			if math.abs((deg - g.angle + 180) % 360 - 180) < pad then
				return true
			end
		end
		return false
	end
	for deg = 0, 357, 3 do
		local mid = deg + 1.5
		local rim = rimAt(math.rad(mid))
		if not nearGate(mid, 4.5) then
			local length = 2 * rim * math.sin(math.rad(1.5)) + 1.5
			K.Core.centered(root, inward(polar(mid, rim - 1.2)), 0, 0, 0, length, BRICK * 2, 1.6, set.stone[1], {
				smooth = true,
			})
		end
	end
	-- The wall in 1-degree pieces, open only across each pier (36 wide): its side walls close the rest.
	for deg = 0, 359 do
		local mid = deg + 0.5
		local rim = rimAt(math.rad(mid))
		if not nearGate(mid, 3) then
			local length = 2 * rim * math.sin(math.rad(0.5)) + 1
			invisibleWall(root, inward(polar(mid, rim - 0.4, 40)), Vector3.new(length, 80, 1))
		end
	end
	for _, g in I.gates do
		local rim = rimAt(math.rad(g.angle))
		local cf = outward(polar(g.angle, rim + 6, 40))
		for _, x in { -18.5, 18.5 } do
			invisibleWall(root, cf * CFrame.new(x, 0, 0), Vector3.new(1, 80, 22))
		end
		invisibleWall(root, cf * CFrame.new(0, 0, -10), Vector3.new(38, 80, 1))
	end
end

-- The conveyor ring in front of the bases (Config.Island.belt): two lanes going opposite ways, low enough to
-- step on or off anywhere, so getting round the bases (and back to the hub) is a ride, not a long walk.
-- Each piece is an anchored part with AssemblyLinearVelocity along the ring, which carries whoever stands
-- on it. A gap where the spawn path crosses, so new players never land on it.
local function belt(root)
	local B = I.belt
	local lanes = {
		{ r = B.radius - B.lane / 2, dir = 1, mark = Color3.fromRGB(90, 220, 255) }, -- inner: counter-clockwise
		{ r = B.radius + B.lane / 2, dir = -1, mark = Color3.fromRGB(255, 205, 60) }, -- outer: clockwise
	}
	local base, trim = Color3.fromRGB(46, 50, 64), Color3.fromRGB(255, 205, 60)
	local function onGap(deg)
		for _, g in B.gaps do
			if math.abs((deg - g + 180) % 360 - 180) < B.gapHalf then
				return true
			end
		end
		return false
	end
	for deg = 0, 359, B.step do
		local mid = deg + B.step / 2
		if onGap(mid) then
			continue
		end
		local a = math.rad(mid)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) -- counter-clockwise
		for _, lane in lanes do
			local at = polar(mid, lane.r, B.height / 2)
			local length = 2 * lane.r * math.sin(math.rad(B.step / 2)) + 0.3
			local cf = CFrame.lookAt(at, at + tangent * lane.dir) -- -Z along the way it moves
			local p =
				K.Core.part(root, cf, Vector3.new(B.lane, B.height, length), base, { smooth = true, name = "Belt" })
			p.AssemblyLinearVelocity = tangent * lane.dir * B.speed
			-- A chevron on every other piece, pointing the way the lane moves.
			if deg % (B.step * 2) == 0 then
				for _, side in { -1, 1 } do
					local arm = cf
						* CFrame.new(side * 0.9, B.height / 2 + 0.08, 0)
						* CFrame.Angles(0, side * math.rad(40), 0) -- the arms meet ahead: a ^ pointing the way
					K.Core.part(root, arm, Vector3.new(0.35, 0.16, 2.6), lane.mark, { neon = true, collide = false })
				end
			end
		end
		-- Hazard-yellow edges, inside and out.
		for _, r in { B.radius - B.lane - 0.3, B.radius + B.lane + 0.3 } do
			local at = polar(mid, r, B.height / 2 + 0.05)
			local length = 2 * r * math.sin(math.rad(B.step / 2)) + 0.3
			K.Core.part(root, CFrame.lookAt(at, at + tangent), Vector3.new(0.6, B.height + 0.1, length), trim, {
				smooth = true,
				name = "BeltEdge",
			})
		end
	end
end

local function scatter(trees)
	K.Core.seed(500)
	local rng = Random.new(500)
	local placed = 0
	for _ = 1, 600 do
		if placed >= 10 then
			break
		end
		-- Trees only near the rim: they frame the districts instead of standing in them.
		local deg = rng:NextNumber(0, 360)
		local r = rng:NextNumber(rimAt(math.rad(deg)) - 14, rimAt(math.rad(deg)) - 6)
		local pos = polar(deg, r)
		if r > I.lowerRoad + 4 and free(pos, 7) then
			local roll = rng:NextNumber()
			local kind = roll < 0.55 and "blossom" or roll < 0.75 and "round" or roll < 0.9 and "pine" or "maple"
			K.Nature.tree(
				trees,
				CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				kind,
				rng:NextInteger(1, 2),
				set
			)
			reserve(pos, 7)
			placed += 1
		end
	end
end

local function sky(root)
	local rng = Random.new(77)
	for i = 1, 8 do
		local deg = rng:NextNumber(0, 360)
		K.Core.seed(600 + i)
		K.Nature.cloud(
			root,
			CFrame.new(polar(deg, rng:NextNumber(250, 340), rng:NextNumber(-60, 40))),
			rng:NextInteger(1, 3)
		)
	end
end

function Hub.build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	table.clear(reserved)
	local root = folder(workspace, "Map")
	ground(folder(root, "Ground", "Model"))
	roads(folder(root, "Roads", "Model"))
	local altars = folder(root, "Altars")
	local floors = folder(root, "DistrictFloors", "Model")
	local pads = {}
	for i, spec in I.altars do
		local cf = inward(polar(spec.angle, I.altarRadius))
		-- The Drop Arena's gold floor under the altar and its two clash pads.
		K.Core.centered(floors, cf, 0, -0.2, 0, 46, PLATE, 16, Bricks.mute(C.gold)) -- not in Altars: DropService reads every child
		local _, pair = Hub.altar(altars, i, cf, spec.tier)
		pads[i] = pair
	end
	local plots = folder(root, "Plots")
	for i, deg in I.plotAngles do
		plot(plots, i, deg)
	end
	local gates = folder(root, "Gates", "Model")
	for _, spec in I.gates do
		gate(gates, spec)
	end
	local colosseumModel = colosseum(root)
	market(folder(root, "Market", "Model"))
	local fighterMarketSpots = fighterMarket(root)
	local shrine = beamShrine(root)
	summit(folder(root, "Summit", "Model"))
	local portalModel = portal(root)
	spawn(folder(root, "Spawn", "Model"))
	gym(folder(root, "Gym", "Model"))
	waterfalls(folder(root, "Waterfalls", "Model"))
	signs(folder(root, "Places", "Model"))
	scatter(folder(root, "Trees"))
	edge(folder(root, "Edge", "Model"))
	belt(folder(root, "Belt", "Model"))
	Ocean.build(root)
	sky(folder(root, "Sky", "Model"))
	return {
		root = root,
		altars = altars,
		pads = pads,
		plots = plots,
		portal = portalModel,
		colosseum = colosseumModel,
		market = fighterMarketSpots,
		shrine = shrine,
	}
end

return Hub
