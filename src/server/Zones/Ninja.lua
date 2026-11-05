-- Zone 2: Ninja Village, a hidden village in a valley at the end of the day (docs/WORLD_PLAN.md §4), 220 x 520,
-- built on the layout every zone shares. Front (hub side, -Z): the village gate -> DROPS (the five altars round
-- a big court under the portal, right on the avenue) with TRAINING in a yard beside the street -> a big torii
-- -> the five guardians up one straight avenue, left and right of it -> the boss under the carved cliff of stone
-- faces, its waterfall into a koi pond; the exit gate beside the boss. Low rock rims keep the valley open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.Parent.BrickKit)
local ZoneKit = require(script.Parent.ZoneKit)
local NinjaKit = require(script.Parent.NinjaKit)
local GymKit = require(script.Parent.GymKit)

local Ninja = {}
local C = Bricks.C
local BRICK = K.Core.BRICK
local set = Bricks.Zones.Ninja
local ROCK = { C.darkGray, C.gray, C.darkGray, C.lightGray }

-- The island: a rounded rectangle 220 wide, z -260..260.
local HALF_W, HALF_L, CORNER = 110, 260, 30
local function island(x, z)
	local dx = math.max(math.abs(x) - (HALF_W - CORNER), 0)
	local dz = math.max(math.abs(z) - (HALF_L - CORNER), 0)
	return dx * dx + dz * dz <= CORNER * CORNER
end

-- The layout every zone shares (arrival at the front, DROPS on the left, TRAINING on the right, the five
-- guardians up one straight avenue, the boss at its end, the exit beside it), in zone coordinates (x across,
-- z down the valley; the village gate is at -235, the carved cliff at 240).
local RUNGS = {
	{ -40, -30 },
	{ 40, 6 },
	{ -40, 42 },
	{ 40, 78 },
	{ -40, 114 },
}
local BOSS_AT = { 0, 182 }
-- DROPS is the heart of the zone (what players come back for once the guardians are done): a big round court
-- right on the avenue as you leave the village street, its five altars as far apart as the hub's, every one
-- reachable from the open middle.
local DROPS_AT = { 0, -130 }
local DROPS_R = 56
local LEDGE_Y = BRICK * 44 -- the carved back cliff's ledge (scenery)

-- Dressing, designed rather than scattered. One hero (the carved cliff of stone faces with its waterfall, seen
-- from the gate straight down the avenue), two landmarks (the village gate you arrive through and the pagoda
-- half way up), and the village itself in four tight groups at the edges, so the middle stays one open, readable
-- floor like the hub's. The ninja look comes from a few strong pieces (red torii, black-roofed houses, stone
-- lanterns in a slow rhythm, maples and blossoms in clumps), not from many small ones.
local function dress(root, frame, L)
	local d = K.Core.model(root, "Dressing", frame)
	-- One avenue from the gate to the boss, and short side paths into the court and the training yard.
	K.Terrain.path(d, L(0, 0, -45), 370, 10, set)
	K.Terrain.path(d, L(-44, 0, -212, 90), 30, 8, set) -- (into the training yard)
	-- The guardians' gateway: one big torii where the avenue leaves the drop court.
	K.Build.torii(d, L(0, 0, -50), 18, 18, { color = C.vermilion })
	-- Stone lanterns in pairs, a slow beat up the avenue (every 40 studs), none in the court or under the torii.
	for z = -215, 135, 40 do
		if (z < DROPS_AT[2] - DROPS_R - 6 or z > DROPS_AT[2] + DROPS_R + 6) and math.abs(z + 50) > 6 then
			for _, sx in { -1, 1 } do
				K.Build.lanternStone(d, L(sx * 9, 0, z), set)
			end
		end
	end
	-- One string of paper lanterns across the street, just inside the gate.
	NinjaKit.lanternString(d, L(-14, 0, -208).Position, L(14, 0, -208).Position, set, 6)
	-- The pagoda (the second landmark), on the left between the guardians, with its bell and two lanterns.
	K.Build.pagoda(d, L(82, 0, 42), 5, 16, set, { glow = true, lanterns = true })
	K.Build.templeBell(d, L(88, 0, 4), set)
	-- Groves in clumps: blossoms framing the gate, maples on the right across from the pagoda, a pair of maples
	-- by the pond at the back. Pines line the low rims.
	local trees = K.Core.model(d, "Groves", frame)
	local groves = {
		{ 88, -238, "blossom", 3 },
		{ 76, -224, "blossom", 2 },
		{ 86, -206, "blossom", 2 },
		{ -86, 72, "maple", 3 },
		{ -78, 88, "maple", 2 },
		{ -90, 94, "blossom", 2 },
		{ -88, 196, "maple", 2 },
		{ -46, 214, "maple", 2 },
	}
	for k, g in groves do
		K.Core.seed(3700 + k)
		K.Nature.tree(trees, L(g[1], 0, g[2], k * 47), g[3], g[4], set)
	end
	K.Build.shishiOdoshi(d, L(-48, 0, 196, 90), set)
	-- A few paper sky lanterns drifting over the drop court.
	local rng = Random.new(3600)
	for i = 1, 6 do
		K.Build.skyLantern(
			d,
			L(DROPS_AT[1] + rng:NextNumber(-30, 30), rng:NextNumber(4, 10), DROPS_AT[2] + rng:NextNumber(-30, 30)),
			130,
			46,
			i * 3.3
		)
	end
end

function Ninja.build(parent, zone, ctx)
	local Fz = CFrame.lookAt(zone.center, Vector3.new(0, zone.center.Y, 0))
	local function L(x, y, z, yaw)
		return Fz * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	local root = K.Core.model(parent, "NinjaVillage", Fz)
	local ground = K.Core.model(root, "Ground", Fz)
	K.Core.seed(3001)
	K.Terrain.landmass(ground, Fz, 268, island, 16, set, { under = 40, cell = 8 })
	local rockOpts = { tiles = "coarse", strata = ROCK }
	-- A low rock rim down each side (the valley stays open to the sky, like the hub) and the carved back cliff
	-- with its ledge: the zone's hero, seen from the gate down the whole avenue.
	for _, sx in { -1, 1 } do
		K.Terrain.terrace(ground, L(sx * 101, BRICK * 6, 0), 18, 500, BRICK * 7, set, rockOpts)
	end
	local ledgeY = LEDGE_Y
	K.Terrain.terrace(ground, L(0, ledgeY, 240), 184, 30, ledgeY + BRICK, set, rockOpts)
	K.Terrain.terrace(ground, L(0, BRICK * 64, 250), 184, 14, BRICK * 21, set, rockOpts)
	for k, x in { -50, 0, 50 } do
		NinjaKit.stoneFace(ground, L(x, ledgeY + 4, 243), k)
	end

	-- The Dojo Ladder: a station on the valley floor for each rung (its challenger pad toward the way you
	-- arrive), then the boss arena under the cliff.
	local ladder = K.Core.model(root, "Ladder", Fz)
	local stations = {}
	for rung, at in RUNGS do
		K.Core.seed(3100 + rung)
		stations[rung] = ZoneKit.station(ladder, L(at[1], 0, at[2]), set, "Ninja", rung, zone.guardians[rung])
	end
	local boss = ZoneKit.bossArena(ladder, L(BOSS_AT[1], 0, BOSS_AT[2]), set, "Ninja", zone.boss.key)

	-- Arrival: the village gate, the return pad beside it.
	local street = K.Core.model(root, "Village", Fz)
	NinjaKit.villageGate(street, L(0, 0, -235), set, zone.title, 18)
	local returnPad = ZoneKit.returnPad(street, L(30, 0, -250), set)
	-- TRAINING on the right: the two training spots and the gear stall in one yard.
	-- (Behind the houses on the right of the street, so the court ahead stays the drops' alone.)
	GymKit.station(street, L(-62, 0, -228), "NinjaPost", set)
	GymKit.station(street, L(-62, 0, -198), "NinjaBag", set)
	GymKit.stall(street, L(-82, 0, -213, -90), set, { 6, 7 })

	-- DROPS: the five altars round their court under the portal, open toward the street, each facing the middle.
	local court = L(DROPS_AT[1], 0, DROPS_AT[2])
	local sky = (L(DROPS_AT[1], 70, DROPS_AT[2])).Position
	local portal = K.Play.dropPortal(street, CFrame.new(sky), 16, set)
	portal.Name = "ZonePortal"
	local altars = {}
	for _, deg in { -120, -60, 0, 60, 120 } do
		local a = math.rad(deg)
		local pos = (court * CFrame.new(math.sin(a) * DROPS_R, 0, math.cos(a) * DROPS_R)).Position
		local cf = CFrame.lookAt(pos, Vector3.new(court.Position.X, pos.Y, court.Position.Z))
		table.insert(altars, ctx.altar(cf, sky, cf.LookVector))
	end

	-- The village street: black-roofed houses in one tidy row down each side from the gate (aligned roofs give
	-- rhythm, not clutter), opening onto the court and the training yard.
	local k = 0
	for _, z in { -222, -206, -190 } do
		for _, sx in { -1, 1 } do
			k += 1
			K.Core.seed(3200 + k)
			NinjaKit.house(street, L(sx * 27, 0, z, sx < 0 and -90 or 90), set, 12, 10, k % 3 == 0)
		end
	end
	dress(root, Fz, L)
	-- Waterfalls from the carved cliff down to a koi pond.
	K.Terrain.pond(street, L(-70, 0, 212), 16, 10, set)
	K.Terrain.waterfall(root, L(-70, BRICK * 64, 243), BRICK * 64 - ledgeY, 6, set, { pool = true })
	K.Terrain.waterfall(root, L(-70, ledgeY, 225), ledgeY, 6, set, { pool = true })
	-- The forest the village hides in: one even wall of pines along each low rim (a single soft texture reads
	-- calm, where scattered trees read busy).
	local trees = K.Core.model(root, "Trees", Fz)
	for z = -236, 236, 26 do
		for _, sx in { -1, 1 } do
			K.Core.seed(3300 + z + sx)
			K.Nature.tree(trees, L(sx * 101, BRICK * 6, z + sx * 6), "pine", (z // 26) % 2 == 0 and 3 or 2, set)
		end
	end

	-- Exit gate to the next zone, by the east canyon wall under the cliff.
	local gateCF = L(80, 0, 212, 90)
	local exitGate = NinjaKit.villageGate(root, gateCF, set, "TO PIRATE BAY", 18)
	ZoneKit.portalize(exitGate, gateCF, set, zone.next, 18, BRICK * 10)
	exitGate.Name = "ZoneGate"

	ZoneKit.edgeWall(root, Fz, island, 268)

	-- Sky.
	local rng = Random.new(3002)
	for i = 1, 8 do
		local z = -250 + (i - 1) * 66
		K.Core.seed(3500 + i)
		K.Nature.cloud(
			root,
			Fz * CFrame.new((i % 2 == 0 and 1 or -1) * rng:NextNumber(170, 230), rng:NextNumber(-40, 70), z),
			(i % 3) + 1
		)
	end

	return {
		model = root,
		frame = Fz,
		radius = 300,
		arrival = L(0, 3, -252, 180),
		returnPad = returnPad:GetPivot().Position,
		altars = altars,
		words = { DROPS = L(DROPS_AT[1], 0, DROPS_AT[2]).Position, TRAINING = L(-66, 0, -213).Position },
		stations = stations,
		boss = boss,
		exitGate = exitGate,
	}
end

return Ninja
