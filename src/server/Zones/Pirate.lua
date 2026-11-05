-- Zone 3: Pirate Bay, a tropical lagoon harbour at noon (docs/WORLD_PLAN.md §4), about 364 x 396. A sandy ring
-- island round a big blue lagoon (a channel cuts through the back, crossed by a rope bridge). Front (hub
-- side, -Z): harbour arch -> the 5 drop altars in two rows under the portal -> a pier and stairs up to the
-- galleon moored mid-lagoon, where the boss waits on deck. The Dojo Ladder runs round the ring on five wide
-- docks reaching into the lagoon, each a full station (the challenger's pad at the shore end, the prize
-- altar, the guardian out over the water); palms, market stalls and a lighthouse dress the ring; the exit
-- gate stands on the back-left shore.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.Parent.BrickKit)
local ZoneKit = require(script.Parent.ZoneKit)
local PirateKit = require(script.Parent.PirateKit)
local GymKit = require(script.Parent.GymKit)

local Pirate = {}
local set = Bricks.Zones.Pirate

local LAGOON = { x = 0, z = 15, rx = 95, rz = 110 }
local OUTER = { x = 182, z = 198 }

local function outer(x, z)
	local a = math.atan2(z, x)
	local w = 1 + math.sin(a * 6) * 0.025 + math.sin(a * 3 + 2) * 0.02
	local dx, dz = x / (OUTER.x * w), z / (OUTER.z * w)
	return dx * dx + dz * dz <= 1
end
local function lagoon(x, z)
	local dx, dz = (x - LAGOON.x) / LAGOON.rx, (z - LAGOON.z) / LAGOON.rz
	return dx * dx + dz * dz <= 1
end
local function channel(x, z)
	return math.abs(x) < 20 and z > LAGOON.z + LAGOON.rz - 10
end
local function ring(x, z)
	return outer(x, z) and not lagoon(x, z) and not channel(x, z)
end

-- Dock angles round the lagoon (degrees from +X toward +Z; -Z is the front), in ladder order: three down the
-- left side, over the back channel, two up the right.
local DOCKS = { 220, 170, 125, 55, 10 }
local DOCK_W, DOCK_D = 30, 62

function Pirate.build(parent, zone, ctx)
	local Fz = CFrame.lookAt(zone.center, Vector3.new(0, zone.center.Y, 0))
	local function L(x, y, z, yaw)
		return Fz * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	local root = K.Core.model(parent, "PirateBay", Fz)
	K.Core.seed(4001)
	K.Terrain.landmass(K.Core.model(root, "Ground", Fz), Fz, 205, ring, 16, set, { under = 40, cell = 8 })
	PirateKit.water(root, Fz, 205, function(x, z)
		return outer(x, z) and (lagoon(x, z) or channel(x, z))
	end, -0.6, 8)
	local reserved = {}
	local function reserve(x, z, r)
		table.insert(reserved, { Vector2.new(x, z), r })
	end
	local function free(x, z, r)
		for _, c in reserved do
			if (c[1] - Vector2.new(x, z)).Magnitude < r + c[2] then
				return false
			end
		end
		return true
	end

	-- Front: harbour arch, return pad, the five drop altars in two rows under the portal.
	local front = K.Core.model(root, "Front", Fz)
	PirateKit.arch(front, L(0, 0, -178), zone.title, 20)
	local returnPad = ZoneKit.returnPad(front, L(30, 0, -188), set)
	local sky = (L(0, 70, -132)).Position
	local portal = K.Play.dropPortal(front, CFrame.new(sky), 18, set)
	portal.Name = "ZonePortal"
	local altars = {}
	for _, a in { { 0, -150 }, { -62, -150 }, { 62, -150 }, { -86, -112 }, { 86, -112 } } do
		local cf = L(a[1], 0, a[2])
		table.insert(altars, ctx.altar(cf, sky, cf.LookVector))
		reserve(a[1], a[2], 30)
	end
	reserve(0, -178, 16)
	reserve(30, -188, 8)
	-- TRAINING: one yard on the shore to the arriving player's right: anchor curls, the rowing frame and the
	-- gear stall together (they were split across the island, so the word over them pointed at the lagoon).
	GymKit.station(front, L(-128, 0, -92, -90), "PiratePost", set)
	GymKit.station(front, L(-128, 0, -60, -90), "PirateBag", set)
	GymKit.stall(front, L(-146, 0, -76, -90), set, { 8, 9 })
	reserve(-128, -92, 10)
	reserve(-128, -60, 10)
	reserve(-146, -76, 9)

	-- The galleon mid-lagoon, reached by a pier from the front shore, stairs and a plank onto the bow.
	local ship, deck = PirateKit.galleon(root, L(0, -0.6, LAGOON.z), 9, 90)
	local pier = K.Core.model(root, "Pier", Fz)
	local shore = LAGOON.z - LAGOON.rz -- the lagoon's front edge
	-- A wooden pier from the shore out to the stairs (the stairs climb toward +Z from z -60).
	K.Terrain.bridge(
		pier,
		CFrame.lookAt(L(0, 0, shore - 6).Position, L(0, 0, -60).Position),
		-60 - (shore - 6),
		8,
		"wood",
		set
	)
	K.Terrain.stairs(pier, L(0, 0, -60, 180), 8, 7, set, { colors = set.wood, rails = set.wood[2] })
	K.Terrain.bridge(pier, CFrame.lookAt(L(0, 8.4, -46).Position, L(0, 8.4, 0).Position), 16, 6, "rope", set)
	reserve(0, shore, 12)
	-- (A smaller ring: the deck is 24 wide and the masts stand at -24 and +14 along it.)
	local boss =
		ZoneKit.bossArena(ship, deck * CFrame.new(0, 0, -5), set, "Pirate", zone.boss.key, { radius = 10, padAt = 8 })

	-- The Dojo Ladder: five wide docks into the lagoon, a full station on each (challenger at the shore end).
	local ladder = K.Core.model(root, "Ladder", Fz)
	local stations = {}
	local middle = L(LAGOON.x, 0, LAGOON.z).Position
	for rung, deg in DOCKS do
		local a = math.rad(deg)
		local edge = L(LAGOON.x + LAGOON.rx * math.cos(a), 0, LAGOON.z + LAGOON.rz * math.sin(a)).Position
		local out = (edge - middle).Unit
		local center = edge - out * (DOCK_D / 2 - 1)
		local frame = CFrame.lookAt(center, center + out) -- -Z (the open end) toward the shore
		PirateKit.dock(ladder, frame, DOCK_W, DOCK_D)
		stations[rung] = ZoneKit.station(
			ladder,
			frame * CFrame.new(0, 0.4, 0),
			set,
			"Pirate",
			rung,
			zone.guardians[rung],
			{ noStrip = true }
		)
		local shoreAt = Fz:PointToObjectSpace(edge + out * 12)
		reserve(shoreAt.X, shoreAt.Z, 16)
	end
	-- Rope bridge over the back channel.
	local channelZ = LAGOON.z + LAGOON.rz + 30
	K.Terrain.bridge(
		ladder,
		CFrame.lookAt(L(-26, 0, channelZ).Position, L(26, 0, channelZ).Position),
		52,
		8,
		"rope",
		set
	)
	reserve(0, channelZ, 28)

	-- The lighthouse and the exit gate.
	local town = K.Core.model(root, "Town", Fz)
	PirateKit.lighthouse(town, L(115, 0, 135))
	reserve(115, 135, 10)
	-- Faces inward so players walking round the ring see the sign.
	local gatePos = L(-112, 0, 132).Position
	local gateCF = CFrame.lookAt(gatePos, gatePos + Fz:VectorToWorldSpace(Vector3.new(1, 0, -0.45)))
	local exitGate = PirateKit.arch(root, gateCF, "TO WALLED CITY", 18)
	ZoneKit.portalize(exitGate, gateCF, set, zone.next, 18, 12)
	exitGate.Name = "ZoneGate"
	reserve(-112, 132, 16)

	-- Palms round the shore.
	local trees = K.Core.model(root, "Trees", Fz)
	local rng = Random.new(4002)
	local placed = 0
	for _ = 1, 600 do
		if placed >= 16 then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.7, 0.92)
		local x, z = math.cos(a) * OUTER.x * r, math.sin(a) * OUTER.z * r
		if ring(x, z) and ring(x + 4, z) and ring(x - 4, z) and ring(x, z + 4) and ring(x, z - 4) and free(x, z, 8) then
			K.Core.seed(4200 + placed)
			K.Nature.tree(trees, L(x, 0, z, rng:NextNumber(0, 360)), "palm", rng:NextInteger(1, 2), set)
			reserve(x, z, 6)
			placed += 1
		end
	end

	ZoneKit.edgeWall(root, Fz, ring, 205)

	-- Sky.
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		K.Core.seed(4300 + i)
		K.Nature.cloud(
			root,
			Fz * CFrame.new(math.cos(a) * 270, rng:NextNumber(-40, 30), math.sin(a) * 290),
			(i % 3) + 1
		)
	end

	return {
		model = root,
		frame = Fz,
		radius = 300,
		arrival = L(0, 3, -190, 180),
		returnPad = returnPad:GetPivot().Position,
		altars = altars,
		words = { DROPS = L(0, 0, -138).Position, TRAINING = L(-134, 0, -76).Position },
		stations = stations,
		boss = boss,
		exitGate = exitGate,
	}
end

return Pirate
