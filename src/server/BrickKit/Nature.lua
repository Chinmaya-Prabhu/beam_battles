-- Nature built from bricks: trees (blossom, round, maple, pine, palm), bushes, rocks, flowers, grass tufts
-- and clouds. Volume comes from tone ramps: every canopy dome is dark underneath, mid in the body and light
-- on top, with sloped edges so it reads round, not boxy.
local Core = require(script.Parent.Core)
local Bricks = require(game:GetService("ReplicatedStorage").Shared.Bricks)

local Nature = {}
local BRICK, PLATE = Core.BRICK, Core.PLATE
local C = Bricks.C

local RAMPS = {
	blossom = function(set)
		return set.blossom
	end,
	round = function(set)
		return set.leaves
	end,
	maple = function()
		return { C.darkRed, C.darkOrange, C.orange, C.lightOrange }
	end,
}

-- A rounded dome `s` studs wide whose bottom sits at (cx, y, cz): shaded underside, body, sloped
-- shoulders, light cap and (for big ones) a highlight crown. ramp = { dark, mid, light[, highlight] }.
local domeCount = 0
local function dome(m, cf, cx, y, cz, s, ramp, opts)
	opts = opts or {}
	-- Overlapping domes would share top planes and flicker; each one sits a different hair higher.
	domeCount += 1
	y += (domeCount % 5) * 0.08
	local dark, mid, light = ramp[1], ramp[2], ramp[3]
	local high = ramp[4] or light
	local at = cf * CFrame.new(cx, 0, cz)
	local o = { collide = opts.collide, shadow = opts.shadow }
	Core.centered(m, at, 0, y, 0, s - 2, BRICK, s - 2, dark, o)
	Core.centered(m, at, 0, y + BRICK, 0, s, BRICK * 2, s, mid, o)
	Core.skirt(
		m,
		at,
		s,
		s,
		y + BRICK * 3,
		1,
		BRICK,
		light,
		{ cornerH = PLATE, collide = opts.collide, shadow = opts.shadow }
	)
	Core.centered(m, at, 0, y + BRICK * 3, 0, s - 2, BRICK, s - 2, light, o)
	if s >= 6 then
		Core.skirt(
			m,
			at,
			s - 2,
			s - 2,
			y + BRICK * 4,
			1,
			BRICK,
			high,
			{ cornerH = 0, collide = opts.collide, shadow = opts.shadow }
		)
		Core.centered(m, at, 0, y + BRICK * 4, 0, s - 4, BRICK, s - 4, high, o)
	end
	return y + BRICK * (s >= 6 and 5 or 4)
end

-- A trunk of `n` bricks with root flares and a kink. Returns its top (x, y, z).
local function trunk(m, cf, n, set)
	local bark, dark = set.wood[1], C.darkBrown
	Core.skirt(m, cf, 4, 4, 0, 1, BRICK, dark, { cornerH = 0 })
	local x, z = 0, 0
	local kinkAt = Core.int(math.max(2, n - 3), math.max(2, n - 1))
	for i = 0, n - 1 do
		if i == kinkAt then
			if Core.chance(0.5) then
				x += Core.pick({ -1, 1 })
			else
				z += Core.pick({ -1, 1 })
			end
		end
		Core.box(m, cf, x - 1, i * BRICK, z - 1, 2, BRICK, 2, i % 4 == 1 and dark or bark)
	end
	return x, n * BRICK, z
end

-- A branch stepping from the trunk toward (tx, ty, tz).
local function branch(m, cf, fx, fy, fz, tx, ty, tz, color)
	local steps = math.max(math.abs(tx - fx), math.abs(tz - fz))
	for i = 1, steps do
		local t = i / steps
		local x = math.floor(fx + (tx - fx) * t + 0.5)
		local z = math.floor(fz + (tz - fz) * t + 0.5)
		local y = fy + (ty - fy) * t
		Core.box(m, cf, x - 0.5, y, z - 0.5, 1, BRICK, 1, color)
	end
end

-- kind: "blossom" | "round" | "maple" | "pine" | "palm"; size 1-3
function Nature.tree(parent, cf, kind, size, set)
	local m = Core.model(parent, "Tree", cf)
	size = size or 2
	if kind == "pine" then
		Core.tag(m, "Sway")
		Nature.pine(m, cf, size, set)
		return m
	elseif kind == "palm" then
		Nature.palm(m, cf, size, set)
		return m
	end
	local ramp = RAMPS[kind](set)
	local tx, ty, tz = trunk(m, cf, 3 + size * 2, set)
	local main = 6 + size * 2
	local count = 2 + size
	-- Lower satellites first, then the main dome over the trunk, then a crown.
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + Core.num(-0.35, 0.35)
		local r = main * Core.num(0.5, 0.65)
		local cx = tx + math.floor(math.cos(a) * r + 0.5)
		local cz = tz + math.floor(math.sin(a) * r + 0.5)
		local cy = ty - BRICK * Core.int(1, 2)
		branch(m, cf, tx, ty - BRICK * 3, tz, cx, cy - BRICK, cz, set.wood[1])
		dome(m, cf, cx, cy, cz, Core.pick({ 4, 6, 6 }), ramp)
	end
	local top = dome(m, cf, tx, ty - BRICK, tz, main, ramp)
	dome(m, cf, tx + Core.int(-1, 1), top - BRICK * 2, tz + Core.int(-1, 1), math.max(4, main - 4), ramp)
	-- The whole tree sways a little in the breeze (KitMotion).
	Core.tag(m, "Sway")
	if kind == "maple" or kind == "round" then
		local leaves = Core.part(
			m,
			cf * CFrame.new(tx, ty, tz),
			Vector3.new(main + 2, 1, main + 2),
			ramp[2],
			{ trans = 1, collide = false, shadow = false }
		)
		Core.particles(leaves, {
			color = ramp[2],
			size = 0.35,
			rate = 0.8,
			life = { 5, 7 },
			speed = 0.3,
			spread = 180,
			accel = Vector3.new(0.6, -1.4, 0.2),
			rotSpeed = 160,
			transparency = 0.05,
		})
	end
	if kind == "blossom" then
		local emitter = Core.part(
			m,
			cf * CFrame.new(tx, ty + BRICK, tz),
			Vector3.new(main + 4, 1, main + 4),
			C.pink,
			{ trans = 1, collide = false, shadow = false }
		)
		Core.particles(emitter, {
			color = C.pinkLight,
			size = 0.3,
			rate = 3,
			life = { 5, 8 },
			speed = 0.3,
			spread = 180,
			accel = Vector3.new(0.5, -1, 0.3),
			rotSpeed = 120,
			transparency = 0.05,
		})
		-- Fallen petals around the roots.
		local fallen = {}
		for _ = 1, 6 + size * 3 do
			local a, r = Core.num(0, math.pi * 2), Core.num(2.5, main / 2 + 2)
			local px, pz = math.floor(tx + math.cos(a) * r), math.floor(tz + math.sin(a) * r)
			if fallen[px .. ":" .. pz] then
				continue
			end
			fallen[px .. ":" .. pz] = true
			Core.box(
				m,
				cf,
				px,
				0,
				pz,
				1,
				PLATE * 0.5,
				1,
				Core.pick({ C.pink, C.pinkLight }),
				{ smooth = true, collide = false }
			)
		end
	end
	return m
end

-- A cone of sloped tiers, dark at the base of each tier and lighter toward the tip.
function Nature.pine(m, cf, size, set)
	local n = 2 + size
	for i = 0, n - 1 do
		Core.box(m, cf, -1, i * BRICK, -1, 2, BRICK, 2, set.wood[1])
	end
	local ramp = set.leaves
	local w = 7 + size * 2
	local y = n * BRICK - BRICK
	local tier = 0
	while w >= 3 do
		Core.centered(m, cf, 0, y, 0, w, BRICK, w, ramp[1])
		Core.skirt(m, cf, w, w, y + BRICK, 2, BRICK * 2, ramp[2], { cornerH = BRICK })
		Core.centered(m, cf, 0, y + BRICK, 0, w - 4, BRICK, w - 4, ramp[2]) -- the next tier sits on this
		y += BRICK * 2
		w -= 2 + (tier % 2)
		tier += 1
	end
	Core.centered(m, cf, 0, y + BRICK, 0, 1, BRICK * 2, 1, ramp[3])
	return m
end

function Nature.palm(m, cf, size, set)
	local n = 6 + size * 2
	local x = 0
	for i = 0, n - 1 do
		if i > n / 3 and i % 2 == 0 then
			x += 1
		end
		Core.box(m, cf, x - 1, i * BRICK, -1, 2, BRICK, 2, i % 2 == 0 and C.mediumNougat or C.tan)
	end
	local crown = cf * CFrame.new(x, n * BRICK + 0.4, 0)
	Core.part(m, crown, Vector3.new(2, BRICK, 2), set.leaves[1])
	for k = 0, 6 do
		local base = crown * CFrame.Angles(0, k * math.pi * 2 / 7 + Core.num(-0.15, 0.15), 0)
		local f1 = base * CFrame.Angles(math.rad(-10), 0, 0)
		Core.part(m, f1 * CFrame.new(0, 0, -2.5), Vector3.new(2.4, PLATE, 5), set.leaves[2], { collide = false })
		local f2 = f1 * CFrame.new(0, 0, -5) * CFrame.Angles(math.rad(-28), 0, 0)
		Core.part(m, f2 * CFrame.new(0, 0, -2), Vector3.new(1.8, PLATE, 4), set.leaves[3], { collide = false })
		local f3 = f2 * CFrame.new(0, 0, -4) * CFrame.Angles(math.rad(-30), 0, 0)
		Core.part(m, f3 * CFrame.new(0, 0, -1), Vector3.new(1, PLATE, 2), set.leaves[3], { collide = false })
	end
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		Core.part(
			m,
			crown * CFrame.new(math.cos(a) * 1.1, -1, math.sin(a) * 1.1),
			Vector3.one * 1.2,
			C.brown,
			{ shape = Enum.PartType.Ball, smooth = true }
		)
	end
	return m
end

-- A rounded bush, optionally flowering. size 1-3
function Nature.bush(parent, cf, size, set, flowers)
	local m = Core.model(parent, "Bush", cf)
	local s = 2 + size * 2
	dome(m, cf, 0, 0, 0, s, set.leaves)
	if size >= 2 then
		dome(m, cf, math.floor(s / 2), 0, Core.int(-1, 1), s - 2, set.leaves)
	end
	if flowers then
		for _ = 1, size * 2 + 1 do
			local x, z = Core.int(-s / 2 + 1, s / 2 - 2), Core.int(-s / 2 + 1, s / 2 - 2)
			Core.roundPlate(m, cf, x + 0.5, BRICK * 4, z + 0.5, Core.pick(set.blossom), 1)
		end
	end
	return m
end

-- A boulder: stacked offset blocks with sloped shoulders, light on top, mossy cap. size 1-3
function Nature.rock(parent, cf, size, set, moss)
	local m = Core.model(parent, "Rock", cf)
	local stone = set.stone
	local w = 4 + size * 2
	local d = w - 2
	local h = BRICK * (1 + size)
	Core.centered(m, cf, 0, 0, 0, w, h, d, C.gray)
	Core.skirt(m, cf, w, d, h, 1, BRICK, stone[1], { cornerH = PLATE })
	Core.centered(m, cf, 0, h, 0, w - 2, BRICK, d - 2, stone[1])
	local ox = Core.int(-1, 1)
	local cap = cf * CFrame.new(ox, 0, 0)
	Core.centered(m, cap, 0, h + BRICK, 0, w - 4, BRICK * size, d - 3, stone[1])
	Core.skirt(m, cap, w - 4, d - 3, h + BRICK * (size + 1), 1, BRICK, C.white, { cornerH = 0 })
	Core.centered(m, cap, 0, h + BRICK * (size + 1), 0, math.max(1, w - 6), BRICK, math.max(1, d - 5), C.white)
	-- A smaller stone leaning on the side.
	Core.centered(m, cf, w / 2, 0, Core.int(-1, 1), 3, BRICK * size, 3, C.gray)
	Core.skirt(m, cf * CFrame.new(w / 2, 0, 0), 3, 3, BRICK * size, 1, BRICK, stone[1], { cornerH = 0 })
	if moss then
		Core.box(
			m,
			cap,
			-math.floor((w - 4) / 2),
			h + BRICK * (size + 1),
			-math.floor((d - 3) / 2),
			math.max(2, w - 5),
			PLATE,
			2,
			set.leaves[2]
		)
	end
	return m
end

-- Grass tufts: pairs of thin blades leaning apart.
function Nature.tufts(parent, cf, radius, count, set)
	local m = Core.model(parent, "Tufts", cf)
	for _ = 1, count do
		local x, z = Core.int(-radius, radius), Core.int(-radius, radius)
		local at = cf * CFrame.new(x + 0.5, 0, z + 0.5) * CFrame.Angles(0, Core.num(0, math.pi), 0)
		local color = Core.pick({ set.leaves[2], set.leaves[3] })
		for _, s in { -1, 1 } do
			Core.part(
				m,
				at * CFrame.new(s * 0.25, 0.5, 0) * CFrame.Angles(0, 0, s * math.rad(-14)),
				Vector3.new(0.2, 1, 0.6),
				color,
				{ smooth = true, collide = false, shadow = false }
			)
		end
	end
	return m
end

-- A scatter of flowers within `radius`.
function Nature.flowers(parent, cf, radius, count, set)
	local m = Core.model(parent, "Flowers", cf)
	local used = {}
	for _ = 1, count do
		local x, z = Core.int(-radius, radius), Core.int(-radius, radius)
		local key = x .. ":" .. z
		if not used[key] and x * x + z * z <= radius * radius then
			used[key] = true
			Core.part(
				m,
				cf * CFrame.new(x + 0.5, 0.45, z + 0.5),
				Vector3.new(0.2, 0.9, 0.2),
				set.leaves[2],
				{ smooth = true, collide = false }
			)
			Core.roundPlate(m, cf, x + 0.5, 0.9, z + 0.5, Core.pick(set.blossom), 1)
			Core.cyl(m, cf, x + 0.5, 0.9 + PLATE, z + 0.5, 0.4, 0.25, C.yellow)
		end
	end
	return m
end

-- A puffy cloud of rounded domes that bobs slowly (KitMotion). size 1-3
function Nature.cloud(parent, cf, size)
	local m = Core.model(parent, "Cloud", cf)
	local ramp = {
		Color3.fromRGB(214, 226, 242),
		Color3.fromRGB(240, 246, 252),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 255, 255),
	}
	local o = { collide = false, shadow = false }
	local w = 8 + size * 4
	dome(m, cf, 0, 0, 0, w, ramp, o)
	dome(m, cf, -math.floor(w / 2), -BRICK, Core.int(-1, 1), w - 4, ramp, o)
	dome(m, cf, math.floor(w / 2), -BRICK, Core.int(-1, 1), w - 2, ramp, o)
	if size >= 2 then
		dome(m, cf, Core.int(-2, 2), BRICK * 2, 0, w - 6, ramp, o)
	end
	Core.tag(m, "Bob")
	Core.tag(m, "Drift")
	return m
end

return Nature
