-- Ninja Village's own pieces (docs/WORLD_PLAN.md §4, zone 2): a hidden canyon village at dusk. Dark tile
-- roofs, tan plaster, dark timber, orange lanterns; no vermilion or gold (that is the hub).
-- Frames face their front along -Z and stand on the ground.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.Parent.BrickKit)

local NinjaKit = {}
local C = Bricks.C
local Core = K.Core
local BRICK, PLATE = Core.BRICK, Core.PLATE
local SMOOTH = { smooth = true }
local DECOR = { smooth = true, collide = false }

-- The village gate: two huge timber posts under little roofs, a crossbeam with the crest sign and two door
-- leaves swung open. `w` is the opening.
function NinjaKit.villageGate(parent, cf, set, title, w)
	w = w or 18
	local m = Core.model(parent, "VillageGate", cf)
	local wood, dark = set.wood[1], set.wood[2] or C.darkBrown
	for _, sx in { -1, 1 } do
		local x = sx * (w / 2 + 1.5)
		Core.centered(m, cf, x, 0, 0, 3, BRICK * 14, 3, wood)
		Core.centered(m, cf, x, 0, 0, 3.6, BRICK * 2, 3.6, C.darkGray)
		K.Build.gable(m, cf * CFrame.new(x, BRICK * 14, 0), 6, 6, BRICK * 2, set.roof, set.trim)
		-- Door leaf swung open (hinged at the post, opened inward toward +Z).
		local hinge = cf * CFrame.new(sx * (w / 2), 0, 1.6) * CFrame.Angles(0, sx * math.rad(-80), 0)
		Core.part(m, hinge * CFrame.new(-sx * w / 4, BRICK * 5, 0), Vector3.new(w / 2, BRICK * 10, 0.8), dark, SMOOTH)
		for k = 1, 3 do
			Core.part(
				m,
				hinge * CFrame.new(-sx * w / 4, BRICK * 2.5 * k, -0.45),
				Vector3.new(w / 2, 0.4, 0.15),
				C.black,
				DECOR
			)
		end
	end
	Core.centered(m, cf, 0, BRICK * 12, 0, w + 8, BRICK, 2.4, dark)
	local sign =
		Core.part(m, cf * CFrame.new(0, BRICK * 10.2, -1.4), Vector3.new(w - 2, BRICK * 2.4, 0.4), C.black, SMOOTH)
	Core.part(
		m,
		cf * CFrame.new(0, BRICK * 10.2, -1.3),
		Vector3.new(w - 1.2, BRICK * 2.4 + 0.6, 0.3),
		set.accent,
		SMOOTH
	)
	Core.label(sign, title, Enum.NormalId.Front, set.accent, C.black)
	return m
end

-- A village house: optional stilts, plaster walls in a dark timber frame, lattice windows, a curtained
-- door, a dark gable roof and a lantern by the door. w along X, d along Z.
function NinjaKit.house(parent, cf, set, w, d, stilts)
	local m = Core.model(parent, "House", cf)
	local wood, plaster = set.wood[1], set.plaster
	local y = 0
	if stilts then
		for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
			for _, z in { -d / 2 + 0.5, 0, d / 2 - 0.5 } do
				Core.centered(m, cf, x, 0, z, 1, BRICK * 3, 1, wood)
			end
		end
		y = BRICK * 3
		-- Steps up to the door.
		for k = 0, 2 do
			Core.box(m, cf, -2, k * BRICK, -d / 2 - 2 * (3 - k), 4, BRICK, 2, wood)
		end
	end
	Core.centered(m, cf, 0, y, 0, w + 1, PLATE * 1.5, d + 1, wood)
	local wallH = BRICK * 5
	local y0 = y + PLATE * 1.5
	Core.centered(m, cf, 0, y0, 0, w, wallH, d, plaster)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Core.centered(m, cf, c[1] * (w / 2 - 0.3), y0, c[2] * (d / 2 - 0.3), 0.8, wallH, 0.8, C.darkBrown, SMOOTH)
	end
	Core.centered(m, cf, 0, y0 + wallH - 0.6, 0, w + 0.2, 0.6, d + 0.2, C.darkBrown, SMOOTH)
	-- Front: a curtained door and a lattice window either side.
	Core.part(m, cf * CFrame.new(0, y0 + 2.4, -d / 2 - 0.05), Vector3.new(3, 4.8, 0.2), C.black, DECOR)
	for k = 0, 2 do
		local strip = Core.part(
			m,
			cf * CFrame.new(-1 + k, y0 + 3.9, -d / 2 - 0.2),
			Vector3.new(0.9, 1.6, 0.1),
			set.accent,
			{ smooth = true, collide = false, tag = "Banner" }
		)
		strip:SetAttribute("Hinge", strip.CFrame * CFrame.new(0, 0.8, 0))
	end
	for _, sx in { -1, 1 } do
		local win = cf * CFrame.new(sx * w / 4 + sx * 0.5, y0 + 3.2, -d / 2 - 0.05)
		Core.part(m, win, Vector3.new(2.4, 2, 0.15), C.lightOrange, { neon = true, collide = false })
		for k = -1, 1 do
			Core.part(m, win * CFrame.new(k * 0.8, 0, -0.1), Vector3.new(0.12, 2, 0.1), C.darkBrown, DECOR)
		end
		Core.part(m, win * CFrame.new(0, 0, -0.1), Vector3.new(2.4, 0.12, 0.1), C.darkBrown, DECOR)
	end
	K.Build.gable(m, cf * CFrame.new(0, y0 + wallH, 0), w + 3, d + 3, BRICK * 3, set.roof, set.trim)
	K.Build.lanternPaper(m, cf * CFrame.new(2.6, y0 + wallH - 0.4, -d / 2 - 1.2), C.orange)
	return m
end

-- A string of paper lanterns sagging between two poles, from `a` to `b` (world positions on the ground).
function NinjaKit.lanternString(parent, a, b, set, count)
	local m = Core.model(parent, "LanternString", CFrame.new(a))
	local h = 9
	for _, p in { a, b } do
		Core.part(
			m,
			CFrame.new(p + Vector3.new(0, h / 2, 0)),
			Vector3.new(0.6, h, 0.6),
			set.wood[2] or C.darkBrown,
			SMOOTH
		)
	end
	local top = Vector3.new(0, h - 0.4, 0)
	count = count or 5
	local prev = a + top
	for k = 1, count + 1 do
		local t = k / (count + 1)
		local p = a:Lerp(b, t) + top - Vector3.new(0, math.sin(t * math.pi) * 1.6, 0)
		Core.part(m, CFrame.lookAt((prev + p) / 2, p), Vector3.new(0.12, 0.12, (p - prev).Magnitude), C.black, DECOR)
		if k <= count then
			K.Build.lanternPaper(m, CFrame.new(p), k % 2 == 0 and C.red or C.orange)
		end
		prev = p
	end
	return m
end

-- Training posts: three timber posts with straw targets and a couple of thrown kunai.
function NinjaKit.trainingPosts(parent, cf, set)
	local m = Core.model(parent, "TrainingPosts", cf)
	for k = -1, 1 do
		local p = cf * CFrame.new(k * 3.5, 0, 0)
		Core.centered(m, p, 0, 0, 0, 1, BRICK * 4, 1, set.wood[1])
		Core.part(
			m,
			p * CFrame.new(0, 3.6, -0.6) * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(0.3, 2.4, 2.4),
			C.tan,
			{ shape = Enum.PartType.Cylinder, smooth = true }
		)
		Core.part(
			m,
			p * CFrame.new(0, 3.6, -0.8) * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(0.1, 1.2, 1.2),
			C.red,
			{ shape = Enum.PartType.Cylinder, smooth = true, collide = false }
		)
		Core.part(
			m,
			p * CFrame.new(0.3 * k, 3.9, -1.4) * CFrame.Angles(math.rad(10), 0, 0),
			Vector3.new(0.15, 0.15, 1.2),
			C.darkGray,
			DECOR
		)
	end
	return m
end

-- A giant face carved into a cliff, `cf` at the chin on the cliff face (looking out along -Z). Variants
-- change the hair and the headband.
function NinjaKit.stoneFace(parent, cf, variant)
	local m = Core.model(parent, "StoneFace", cf)
	local s1, s2, s3 = C.gray, C.lightGray, C.darkGray
	local function p(x, y, z, sx, sy, sz, color, opts)
		return Core.part(m, cf * CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, opts or SMOOTH)
	end
	p(0, 8, -1, 12, 16, 4, s2) -- face
	p(0, 15, -1.6, 13, 2, 3.4, s1) -- brow line
	p(0, 13.2, -3.2, 11, 1.4, 0.4, s3) -- headband
	p(0, 13.2, -3.45, 3, 1.1, 0.2, C.lightGray) -- headband plate
	for _, sx in { -1, 1 } do
		p(sx * 2.8, 10.6, -3.1, 2.6, 1.3, 0.3, C.black) -- eye socket
		p(sx * 2.8, 11.6, -3.3, 3.2, 0.6, 0.6, s1) -- brow
		p(sx * 6.4, 8, -1.2, 1.2, 4, 2, s1) -- ear
	end
	Core.part(
		m,
		cf * CFrame.new(0, 8.4, -3.4) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(1.6, 3, 1.6),
		s1,
		{ class = "WedgePart", smooth = true }
	) -- nose
	p(0, 5, -3.1, 4, 0.5, 0.3, s3) -- mouth
	p(0, 2.4, -2.4, 7, 3, 1.6, s2) -- chin
	-- Hair: spiky, swept or a high topknot.
	local spikes = variant == 1 and 7 or variant == 2 and 5 or 3
	for k = 0, spikes - 1 do
		local x = -6 + (k + 0.5) * 12 / spikes
		local tall = variant == 3 and (k == 1 and 7 or 3) or 3 + (k % 2) * 2
		Core.part(
			m,
			cf * CFrame.new(x, 16 + tall / 2, -1.2) * CFrame.Angles(0, 0, math.rad((x / 6) * -18)),
			Vector3.new(12 / spikes + 0.6, tall, 3.4),
			s1,
			SMOOTH
		)
	end
	return m
end

return NinjaKit
