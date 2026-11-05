-- Zone 4: Walled City, a medieval town inside a giant wall under grey skies (docs/WORLD_PLAN.md §4), about
-- 390 across. Front (hub side, -Z): arrive outside the wall by the training yard -> through the gatehouse ->
-- the market square with the 5 drop altars round under the portal (the way from the gate left clear) ->
-- the avenue up to the castle keep, four guardians in the side streets and the fifth on the avenue, each a
-- full station -> a long stair beside the keep up to the bastion on the back wall, where the boss arena
-- stands with the titan's face peering over the wall right behind it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.Parent.BrickKit)
local ZoneKit = require(script.Parent.ZoneKit)
local WalledKit = require(script.Parent.WalledKit)
local GymKit = require(script.Parent.GymKit)

local Walled = {}
local BRICK = K.Core.BRICK
local set = Bricks.Zones.Walled
local WALL_H = BRICK * 25

local WALL_R = 158

local function island(x, z)
	local a = math.atan2(z, x)
	local r = 196 * (1 + math.sin(a * 5) * 0.02 + math.sin(a * 3 + 1) * 0.015)
	return x * x + z * z <= r * r
end

function Walled.build(parent, zone, ctx)
	local Fz = CFrame.lookAt(zone.center, Vector3.new(0, zone.center.Y, 0))
	local function L(x, y, z, yaw)
		return Fz * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	local root = K.Core.model(parent, "WalledCity", Fz)
	K.Core.seed(5001)
	K.Terrain.landmass(K.Core.model(root, "Ground", Fz), Fz, 202, island, 16, set, { under = 40, cell = 8 })

	-- The wall, gatehouse (front) and bastion (back).
	local city = K.Core.model(root, "City", Fz)
	WalledKit.ringWall(city, Fz, WALL_R, 6, WALL_H, { { 265, 275 }, { 78, 102 } })
	WalledKit.gatehouse(city, L(0, 0, -WALL_R), zone.title, 14, WALL_H)
	K.Terrain.terrace(
		city,
		L(0, WALL_H, WALL_R - 12),
		70,
		50,
		WALL_H + BRICK,
		set,
		{ tiles = "coarse", strata = { Color3.fromRGB(168, 170, 168), Color3.fromRGB(148, 150, 150) } }
	)
	-- The titan, towering over the keep from the town, gripping the wall beside the bastion.
	local hands = {}
	for _, deg in { 66, 114 } do
		local a = math.rad(deg)
		local p = L(math.cos(a) * (WALL_R + 3), WALL_H, math.sin(a) * (WALL_R + 3)).Position
		table.insert(hands, CFrame.lookAt(p, L(0, WALL_H, 0).Position))
	end
	WalledKit.titan(city, L(0, WALL_H, WALL_R + 32), 2.6, hands)
	local returnPad = ZoneKit.returnPad(city, L(30, 0, -184), set)
	-- The training yard outside the gates: the post, the bag and the gear stall all face the arrival.
	local function polarAt(deg, r)
		local a = math.rad(deg)
		return L(math.cos(a) * r, 0, math.sin(a) * r).Position
	end
	local arrivalAt = L(0, 0, -184).Position
	-- (All on the arriving player's right of the gate, so TRAINING is one place.)
	for _, st in { { 232, 176, "WalledPost" }, { 246, 178, "WalledBag" } } do
		local at = polarAt(st[1], st[2])
		GymKit.station(city, CFrame.lookAt(at, Vector3.new(arrivalAt.X, at.Y, arrivalAt.Z)), st[3], set)
	end
	local stallAt = polarAt(258, 184)
	GymKit.stall(city, CFrame.lookAt(stallAt, Vector3.new(arrivalAt.X, stallAt.Y, arrivalAt.Z)), set, { 10 })

	-- The market square with the five drop altars round under the portal (none in the way from the gate),
	-- the avenue to the keep and the cross streets to the side-street stations.
	local streets = K.Core.model(root, "Streets", Fz)
	K.Terrain.path(streets, L(0, 0, -40), 104, 100, set)
	K.Terrain.path(streets, L(0, 0, 66), 106, 10, set)
	for _, z in { -40, 40 } do
		for _, sx in { -1, 1 } do
			K.Terrain.path(streets, L(sx * 5, 0, z, sx < 0 and 90 or -90), 80, 8, set)
		end
	end
	local hub = L(0, 0, -95)
	local sky = (L(0, 70, -95)).Position
	local portal = K.Play.dropPortal(streets, CFrame.new(sky), 16, set)
	portal.Name = "ZonePortal"
	local altars = {}
	for _, deg in { -60, 60, -120, 120, 180 } do
		local a = math.rad(deg)
		local pos = (hub * CFrame.new(math.sin(a) * 50, 0, -math.cos(a) * 50)).Position
		-- Facing the portal, so every prize pad is on the open middle of the square (as in every zone).
		local cf = CFrame.lookAt(pos, Vector3.new(hub.Position.X, pos.Y, hub.Position.Z))
		table.insert(altars, ctx.altar(cf, sky, cf.LookVector))
	end

	-- The Dojo Ladder: side streets (1-4), the avenue before the keep (5), the bastion (boss).
	local ladder = K.Core.model(root, "Ladder", Fz)
	local stations = {}
	for rung, at in { { -95, -40 }, { 95, -40 }, { -95, 40 }, { 95, 40 } } do
		stations[rung] = ZoneKit.station(ladder, L(at[1], 0, at[2]), set, "Walled", rung, zone.guardians[rung])
	end
	stations[5] = ZoneKit.station(ladder, L(0, 0, 30), set, "Walled", 5, zone.guardians[5], { noStrip = true })
	WalledKit.keep(city, L(0, 0, 82), set, 32, BRICK * 25)
	local stairsX = -44
	K.Terrain.stairs(ladder, L(stairsX, 0, 70, 180), 8, 25, set, { rails = set.wood[2] })
	K.Terrain.bridge(
		ladder,
		CFrame.lookAt(L(stairsX, WALL_H, 120).Position, L(stairsX + 14, WALL_H, 128).Position),
		17,
		8,
		"stone",
		set
	)
	local boss = ZoneKit.bossArena(ladder, L(0, WALL_H, WALL_R - 14), set, "Walled", zone.boss.key)

	-- Town houses facing the streets.
	local town = K.Core.model(root, "Town", Fz)
	local houses = {
		{ -75, -125 },
		{ 75, -125 },
		{ -125, -80 },
		{ -125, 0 },
		{ -118, 80 },
		{ 125, -80 },
		{ 125, 0 },
		{ 118, 80 },
	}
	for i, h in houses do
		K.Core.seed(5100 + i)
		WalledKit.house(town, L(h[1], 0, h[2], h[1] < 0 and -90 or 90), set, 10, 8, i % 3 == 0 and 1 or 2)
	end
	for i, t in { { -60, -140 }, { 60, -140 }, { 55, 95 } } do
		K.Core.seed(5200 + i)
		K.Nature.tree(town, L(t[1], 0, t[2]), "round", 2, set)
	end

	ZoneKit.edgeWall(root, Fz, island, 202)

	-- Sky.
	local rng = Random.new(5002)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		K.Core.seed(5300 + i)
		K.Nature.cloud(
			root,
			Fz * CFrame.new(math.cos(a) * 280, rng:NextNumber(-30, 50), math.sin(a) * 280),
			(i % 3) + 1
		)
	end

	return {
		model = root,
		frame = Fz,
		radius = 300,
		arrival = L(0, 3, -184, 180),
		returnPad = returnPad:GetPivot().Position,
		altars = altars,
		words = { DROPS = hub.Position, TRAINING = polarAt(245, 178) },
		stations = stations,
		boss = boss,
	}
end

return Walled
