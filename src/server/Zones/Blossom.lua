-- Zone 1: Blossom Academy, an anime high-school campus (docs/WORLD_PLAN.md §4.1), 200 x 630, on the layout
-- every zone shares. Front (hub side, -Z): the school gate -> DROPS straight ahead (the fountain court, its five
-- altars round it, as far apart as the hub's) with the TRAINING yard to the side of the gate -> guardian 1 on the
-- forecourt -> the school (walk-through hall, the boss arena on its roof) -> the gym court (guardian 2) and
-- the lawn (guardian 3) -> the running track round the pitch (guardians 4 and 5) -> the exit gate. Rows of
-- cherry trees down both long edges frame the campus; the middle stays open lawn and warm paving.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.Parent.BrickKit)
local ZoneKit = require(script.Parent.ZoneKit)
local CampusKit = require(script.Parent.CampusKit)
local GymKit = require(script.Parent.GymKit)

local Blossom = {}
local PLATE = K.Core.PLATE
local set = Bricks.Zones.Blossom
local P = CampusKit.P

-- The island: a rounded rectangle 200 wide, from z -300 (front) to 330 (back).
local HALF_W, Z0, Z1, CORNER = 100, -300, 330, 40
local function island(x, z)
	local zc = (Z0 + Z1) / 2
	local hz = (Z1 - Z0) / 2
	local dx = math.max(math.abs(x) - (HALF_W - CORNER), 0)
	local dz = math.max(math.abs(z - zc) - (hz - CORNER), 0)
	return dx * dx + dz * dz <= CORNER * CORNER
end

function Blossom.build(parent, zone, ctx)
	local Fz = CFrame.lookAt(zone.center, Vector3.new(0, zone.center.Y, 0))
	local function L(x, y, z, yaw)
		return Fz * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	local root = K.Core.model(parent, "BlossomAcademy", Fz)
	K.Core.seed(2001)
	-- School grounds: green lawn everywhere (a campus of grey paving read as unfinished concrete), with
	-- paved plazas only where people gather: the gate, the drop court and the forecourt before the doors.
	local ground = table.clone(set)
	ground.grass = { P.lawn[1] }
	K.Terrain.landmass(K.Core.model(root, "Ground", Fz), Fz, 312, island, 16, ground, { under = 40, cell = 8 })
	local plazas = K.Core.model(root, "Plazas", Fz)
	local function plaza(x0, z0, w, d)
		-- Warm cherry-blossom paving with a darker kerb (grey read as a car park).
		-- (The kerb sits lower than the paving: two surfaces a hair apart flicker from a distance.)
		K.Core.box(plazas, Fz, x0 - 1, 0, z0 - 1, w + 2, PLATE / 2, d + 2, set.path[4], { smooth = true }) -- the kerb
		K.Core.box(plazas, Fz, x0, 0, z0, w, PLATE, d, set.path[1], { smooth = true })
	end
	local COURT, COURT_R = -185, 52 -- the drop court: its centre (z) and the altars' ring
	plaza(-30, -296, 60, 50) -- in front of and through the school gate
	plaza(-76, COURT - 70, 152, 140) -- the drop court round the fountain
	plaza(-50, -128, 100, 76) -- the forecourt before the school doors (guardian 1)
	-- A lawn ring round the fountain, so the court is a garden square, not a slab.
	local garden = K.Core.model(root, "CourtGarden", Fz)
	K.Core.cyl(garden, L(0, PLATE, COURT), 0, 0, 0, 34, PLATE, P.lawn[1])

	-- Arrival: the school gate and the return pad; nothing else in the way.
	local front = K.Core.model(root, "Front", Fz)
	CampusKit.schoolGate(front, L(0, 0, -270), zone.title)
	local returnPad = ZoneKit.returnPad(front, L(30, 0, -288), set)

	-- TRAINING: one yard beside the gate (on the arriving player's right): the post, the bag and the gear stall.
	local yard = K.Core.model(root, "TrainingYard", Fz)
	GymKit.station(yard, L(-72, 0, -270, -90), "AcademyPost", set)
	GymKit.station(yard, L(-72, 0, -236, -90), "AcademyBag", set)
	GymKit.stall(yard, L(-90, 0, -253, -90), set, { 4, 5 })

	-- DROPS, the heart of the zone, straight ahead of the gate: the five altars round the fountain under the
	-- portal, open toward the gate, each facing the fountain so every prize pad is on the open middle.
	local court = K.Core.model(root, "Courtyard", Fz)
	local hub = L(0, 0, COURT)
	local sky = (L(0, 76, COURT)).Position
	local portal = K.Play.dropPortal(court, CFrame.new(sky), 18, set)
	portal.Name = "ZonePortal"
	CampusKit.fountain(court, hub, 9)
	local altars = {}
	for _, deg in { -120, -60, 0, 60, 120 } do
		local a = math.rad(deg)
		local pos = (hub * CFrame.new(math.sin(a) * COURT_R, 0, math.cos(a) * COURT_R)).Position
		local cf = CFrame.lookAt(pos, Vector3.new(hub.Position.X, pos.Y, hub.Position.Z))
		table.insert(altars, ctx.altar(cf, sky, cf.LookVector))
	end

	-- Guardians stand in open plazas along the walk (never inside a building, so nothing blocks a fight):
	-- each station is the challenger's pad (front), the prize altar and the guardian on its pad (back).
	local ladder = K.Core.model(root, "Ladder", Fz)
	local stations = {}
	local function station(rung, cf, opts)
		stations[rung] = ZoneKit.station(ladder, cf, set, "Blossom", rung, zone.guardians[rung], opts)
	end

	-- Guardian 1 on the forecourt, past the drop court, right before the school doors.
	station(1, L(0, 0, -85), { noStrip = true }) -- (on paving already)

	-- The school (bigger), with the boss arena on its roof.
	local school, roof = CampusKit.school(root, L(0, 0, -15), set, 120, zone.title)
	local boss = ZoneKit.bossArena(school, roof * CFrame.new(-32, 0, 0), set, "Blossom", zone.boss.key)

	-- Behind the school: the gym court with guardian 2 on the lawn beside it, then guardian 3 on the lawn.
	local sport = K.Core.model(root, "Sports", Fz)
	CampusKit.gym(sport, L(-48, 0, 55), set, 56, 60)
	station(2, L(40, 0, 55))
	station(3, L(-40, 0, 125))

	-- Running track round the football pitch: guardians 4 and 5 face off across the pitch.
	CampusKit.track(sport, L(0, 0, 235), 30, 36)
	station(4, L(0, 0, 210, 90), { noStrip = true })
	station(5, L(0, 0, 260, 90), { noStrip = true })

	-- Exit gate to the next zone, at the far end, facing out.
	local exitGate = CampusKit.exitGate(root, L(0, 0, 320, 180), set, "TO NINJA VILLAGE", zone.next)

	-- Cherry trees in two even rows down the long edges (one soft pink border, like the hub's open edges and
	-- the Ninja Village's pines), clear of the training yard.
	local edges = K.Core.model(root, "Edges", Fz)
	local n = 0
	for z = -240, 300, 45 do
		for _, sx in { -1, 1 } do
			if not (sx < 0 and z < -200) then
				n += 1
				K.Core.seed(2500 + n)
				K.Nature.tree(edges, L(sx * 88, 0, z + (sx > 0 and 0 or 22)), "blossom", 2, set)
			end
		end
	end
	-- Walkway: warm tiles from the school's back door to the track.
	K.Terrain.path(edges, L(0, 0, 160), 157, 10, set)

	ZoneKit.edgeWall(root, Fz, island, 312)

	-- Sky: clouds drifting round the island.
	local rng = Random.new(2002)
	for i = 1, 8 do
		local z = -280 + (i - 1) * 72
		local side = i % 2 == 0 and 1 or -1
		K.Core.seed(2400 + i)
		K.Nature.cloud(root, Fz * CFrame.new(side * rng:NextNumber(150, 220), rng:NextNumber(-60, 25), z), (i % 3) + 1)
	end

	return {
		model = root,
		frame = Fz,
		radius = 345,
		arrival = L(0, 3, -286, 180),
		returnPad = returnPad:GetPivot().Position,
		altars = altars,
		words = { DROPS = hub.Position, TRAINING = L(-76, 0, -253).Position },
		stations = stations,
		boss = boss,
		exitGate = exitGate,
	}
end

return Blossom
