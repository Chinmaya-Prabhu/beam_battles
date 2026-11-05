-- Blossom Academy's own pieces (docs/WORLD_PLAN.md §4.1): an anime school campus. None of these appear in the
-- hub. Frames face their front along -Z and sit on the ground. Colours come from the zone set plus P below.
-- Neighbouring parts that could share a face are offset by a hair (no flicker).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.Parent.BrickKit)

local CampusKit = {}
local C = Bricks.C
local Core = K.Core
local BRICK, PLATE = Core.BRICK, Core.PLATE

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local P = {
	wall = rgb(246, 238, 220),
	wallShade = rgb(226, 214, 190),
	frame = rgb(70, 96, 130),
	frameDark = rgb(44, 62, 90),
	roof = rgb(70, 150, 150),
	glass = rgb(170, 214, 240),
	interior = rgb(250, 246, 236),
	chalk = rgb(40, 84, 60),
	desk = rgb(196, 150, 96),
	metal = rgb(150, 156, 164),
	dark = rgb(54, 58, 66),
	track = rgb(196, 70, 56),
	line = rgb(250, 250, 250),
	wood = rgb(214, 170, 110),
	water = rgb(90, 190, 230),
	tile = rgb(236, 240, 240),
	lawn = { rgb(96, 176, 84), rgb(82, 160, 74) },
}
CampusKit.P = P

local SMOOTH = { smooth = true }
local DECOR = { smooth = true, collide = false }
local GLASS = { smooth = true, trans = 0.35, collide = false }

-- A flat ring of `n` segments at radius r between angles a0..a1 (radians), width w, on top of y.
local function arc(m, cf, r, w, a0, a1, n, y, color, h)
	for i = 0, n - 1 do
		local a = a0 + (a1 - a0) * (i + 0.5) / n
		local p = cf * Vector3.new(math.cos(a) * r, y + (h or 0.4) / 2 + (i % 2) * 0.03, math.sin(a) * r)
		local tangent = cf:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
		local len = math.abs(a1 - a0) * r / n + 0.15
		Core.part(m, CFrame.lookAt(p, p + tangent), Vector3.new(w, h or 0.4, len), color, SMOOTH)
	end
end

-- ------------------------------------------------------------------ small props

-- The school gate: stone pillars, low wing walls, a sliding iron gate left open and the name on a steel arch.
function CampusKit.schoolGate(parent, cf, title)
	local m = Core.model(parent, "SchoolGate", cf)
	for _, sx in { -1, 1 } do
		Core.centered(m, cf, sx * 12, 0, 0, 3, BRICK * 6, 3, rgb(200, 198, 192))
		Core.centered(m, cf, sx * 12, BRICK * 6, 0, 3.6, PLATE * 1.5, 3.6, rgb(170, 168, 162), SMOOTH)
		Core.centered(m, cf, sx * 17.5, 0, 0, 8, BRICK * 3, 1.6, P.wall)
		Core.centered(m, cf, sx * 17.5, BRICK * 3, 0, 8.4, PLATE, 2, rgb(170, 168, 162), SMOOTH)
		-- Steel arch posts.
		Core.centered(m, cf, sx * 10, 0, -2.4, 0.8, 14, 0.8, P.dark, SMOOTH)
	end
	local sign = Core.centered(m, cf, 0, 11, -2.4, 22, 3.2, 0.6, C.white, SMOOTH)
	Core.centered(m, cf, 0, 10.6, -2.4, 22.8, 4, 0.4, P.frame, SMOOTH)
	Core.label(sign, title, Enum.NormalId.Front, P.frame, C.white)
	-- The sliding gate, pushed open behind the left wing wall.
	local gate = cf * CFrame.new(-17.5, 0, 1.4)
	for _, y in { 0.5, 3.2 } do
		Core.part(m, gate * CFrame.new(0, y, 0), Vector3.new(9, 0.25, 0.25), P.dark, SMOOTH)
	end
	for x = -4, 4 do
		Core.part(m, gate * CFrame.new(x, 1.85, 0), Vector3.new(0.18, 2.9, 0.18), P.dark, SMOOTH)
	end
	return m
end

-- A row of bicycles in a rack.
function CampusKit.bikeRack(parent, cf, n)
	local m = Core.model(parent, "BikeRack", cf)
	local colors = { rgb(220, 70, 60), rgb(60, 120, 210), C.white, rgb(240, 200, 60), rgb(80, 170, 110) }
	Core.part(m, cf * CFrame.new(0, 0.6, 1.6), Vector3.new(n * 2 + 1, 0.2, 0.2), P.metal, SMOOTH)
	for i = 1, n do
		local b = cf * CFrame.new(-n - 1 + i * 2, 0, 0)
		local color = colors[(i - 1) % #colors + 1]
		for _, z in { -1.1, 1.1 } do
			Core.part(
				m,
				b * CFrame.new(0, 0.9, z),
				Vector3.new(0.18, 1.8, 1.8),
				P.dark,
				{ shape = Enum.PartType.Cylinder, smooth = true }
			)
			Core.part(
				m,
				b * CFrame.new(0, 0.9, z),
				Vector3.new(0.22, 0.5, 0.5),
				P.metal,
				{ shape = Enum.PartType.Cylinder, smooth = true }
			)
		end
		Core.part(m, b * CFrame.new(0, 1.75, 0), Vector3.new(0.18, 0.18, 2), color, SMOOTH)
		Core.part(
			m,
			b * CFrame.new(0, 1.35, -0.45) * CFrame.Angles(math.rad(-50), 0, 0),
			Vector3.new(0.18, 0.18, 1.5),
			color,
			SMOOTH
		)
		Core.part(m, b * CFrame.new(0, 2.05, 0.75), Vector3.new(0.4, 0.14, 0.8), P.dark, SMOOTH)
		Core.part(m, b * CFrame.new(0, 2.3, -1), Vector3.new(1.3, 0.14, 0.14), P.dark, SMOOTH)
	end
	return m
end

-- A glowing drinks machine.
function CampusKit.vendingMachine(parent, cf, color)
	local m = Core.model(parent, "VendingMachine", cf)
	Core.centered(m, cf, 0, 0, 0, 3.2, 6.4, 2.4, color, SMOOTH)
	Core.part(m, cf * CFrame.new(0, 6.2, -1.25), Vector3.new(2.8, 0.6, 0.1), C.white, { neon = true, collide = false })
	Core.part(
		m,
		cf * CFrame.new(-0.3, 3.6, -1.45),
		Vector3.new(2.2, 3.4, 0.1),
		rgb(220, 236, 250),
		{ smooth = true, trans = 0.45, collide = false }
	)
	local cans = { rgb(230, 60, 50), rgb(60, 130, 220), rgb(250, 210, 60), rgb(90, 190, 110), C.white }
	for row = 0, 2 do
		for col = 0, 4 do
			Core.cyl(
				m,
				cf,
				-1.15 + col * 0.42,
				2.25 + row * 1.05,
				-1.32,
				0.24,
				0.5,
				cans[(row + col) % #cans + 1],
				{ collide = false }
			)
		end
	end
	for k = 0, 4 do
		Core.part(
			m,
			cf * CFrame.new(1.2, 2.6 + k * 0.5, -1.25),
			Vector3.new(0.3, 0.25, 0.1),
			k % 2 == 0 and C.white or P.dark,
			DECOR
		)
	end
	Core.part(m, cf * CFrame.new(0, 0.9, -1.25), Vector3.new(2.2, 0.8, 0.1), P.dark, DECOR)
	Core.light(m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart"), rgb(220, 236, 255), 10, 0.8)
	return m
end

function CampusKit.bench(parent, cf)
	local m = Core.model(parent, "Bench", cf)
	for _, x in { -1.6, 1.6 } do
		Core.centered(m, cf, x, 0, 0, 0.4, 1.2, 1.4, P.dark, SMOOTH)
	end
	for k = 0, 2 do
		Core.part(m, cf * CFrame.new(0, 1.3, -0.45 + k * 0.45), Vector3.new(4.2, 0.2, 0.38), P.wood, SMOOTH)
	end
	for _, y in { 1.9, 2.45 } do
		Core.part(m, cf * CFrame.new(0, y, 0.75), Vector3.new(4.2, 0.4, 0.15), P.wood, SMOOTH)
	end
	return m
end

-- A modern lamp post (the campus has no stone lanterns).
function CampusKit.lampPost(parent, cf)
	local m = Core.model(parent, "LampPost", cf)
	Core.cyl(m, cf, 0, 0, 0, 1.2, 0.6, P.dark)
	Core.cyl(m, cf, 0, 0.6, 0, 0.45, 10, P.dark)
	Core.part(m, cf * CFrame.new(0, 10.4, -1), Vector3.new(0.3, 0.3, 2.4), P.dark, SMOOTH)
	local head = Core.part(m, cf * CFrame.new(0, 10.1, -2), Vector3.new(1.4, 0.5, 1.1), P.dark, SMOOTH)
	Core.part(
		m,
		cf * CFrame.new(0, 9.8, -2),
		Vector3.new(1.1, 0.12, 0.8),
		rgb(255, 244, 220),
		{ neon = true, collide = false }
	)
	Core.light(head, rgb(255, 240, 210), 18, 0.9)
	return m
end

function CampusKit.pottedPlant(parent, cf, set)
	local m = Core.model(parent, "Planter", cf)
	Core.cyl(m, cf, 0, 0, 0, 2, 1.6, rgb(190, 110, 70))
	Core.cyl(m, cf, 0, 1.6, 0, 2.3, 0.3, rgb(170, 96, 60))
	for k = 0, 2 do
		local a = k * 2.1
		Core.ball(m, cf, math.cos(a) * 0.4, 2.6 + k * 0.3, math.sin(a) * 0.4, 1.6 - k * 0.2, set.leaves[k + 1])
	end
	return m
end

function CampusKit.noticeBoard(parent, cf)
	local m = Core.model(parent, "NoticeBoard", cf)
	for _, x in { -2.6, 2.6 } do
		Core.centered(m, cf, x, 0, 0, 0.5, 5.6, 0.5, P.frame, SMOOTH)
	end
	Core.centered(m, cf, 0, 2, 0, 5.6, 3.2, 0.4, rgb(170, 125, 85), SMOOTH)
	local papers = { C.white, rgb(255, 240, 160), rgb(200, 230, 255), rgb(255, 210, 220), C.white, rgb(210, 245, 210) }
	for k, color in papers do
		local x, y = -1.9 + ((k - 1) % 3) * 1.9, 4.2 - math.floor((k - 1) / 3) * 1.4
		Core.part(
			m,
			cf * CFrame.new(x, y - 0.1, -0.25) * CFrame.Angles(0, 0, math.rad((k % 3 - 1) * 4)),
			Vector3.new(1.1, 1.2, 0.05),
			color,
			DECOR
		)
	end
	Core.part(m, cf * CFrame.new(0, 5.4, 0), Vector3.new(6.4, 0.3, 1.2), P.frameDark, SMOOTH)
	return m
end

-- A courtyard fountain: stone basin ring, water, a tiered centre spraying droplets.
function CampusKit.fountain(parent, cf, r)
	local m = Core.model(parent, "Fountain", cf)
	local stone = rgb(210, 208, 202)
	local n = 20
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local p = cf * Vector3.new(math.cos(a) * r, 0.6 + (i % 2) * 0.03, math.sin(a) * r)
		local tangent = cf:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
		Core.part(m, CFrame.lookAt(p, p + tangent), Vector3.new(1.2, 1.2, 2 * math.pi * r / n + 0.25), stone, SMOOTH)
	end
	Core.cyl(m, cf, 0, 0, 0, r * 2 - 1, 0.4, rgb(70, 120, 160))
	Core.cyl(m, cf, 0, 0.4, 0, r * 2 - 1.1, 0.5, P.water, { trans = 0.3 })
	Core.cyl(m, cf, 0, 0, 0, 2, BRICK * 2, stone)
	Core.cyl(m, cf, 0, BRICK * 2, 0, 4.4, 0.5, stone)
	Core.cyl(m, cf, 0, BRICK * 2 + 0.5, 0, 0.9, 1.6, stone)
	local top = Core.cyl(m, cf, 0, BRICK * 2 + 2.1, 0, 2.4, 0.4, stone)
	Core.particles(top, {
		color = rgb(210, 236, 255),
		size = 0.25,
		rate = 40,
		life = { 0.8, 1.1 },
		speed = 7,
		spread = 22,
		accel = Vector3.new(0, -24, 0),
		transparency = 0.2,
	})
	return m
end

-- ------------------------------------------------------------------ the school building

-- Window bay on a facade frame `f` (front = -Z), with a glimpse of the classroom behind on `inside`.
local function windowBay(m, f, x, y, inside)
	Core.part(m, f * CFrame.new(x, y + 1.8, -0.05), Vector3.new(4, 3.6, 0.2), P.glass, GLASS)
	Core.part(m, f * CFrame.new(x, y + 1.8, -0.2), Vector3.new(0.25, 3.6, 0.2), P.frame, SMOOTH)
	Core.part(m, f * CFrame.new(x, y - 0.1, -0.35), Vector3.new(4.4, 0.25, 0.6), P.frame, SMOOTH)
	if inside then
		Core.part(m, f * CFrame.new(x, y + 0.45, 1.2), Vector3.new(1.8, 0.9, 0.9), P.desk, DECOR)
		if math.floor(x / 6) % 2 == 0 then
			Core.part(m, f * CFrame.new(x, y + 2.2, 2.04), Vector3.new(3.2, 1.6, 0.1), P.chalk, DECOR)
		end
	end
end

-- The school: three storeys, `len` long (a multiple of 4) and 36 deep. A walk-through entrance hall with
-- shoe lockers, classroom windows (desks and chalkboards inside on the front), a central clock tower and a
-- fenced rooftop reached by a switchback staircase at the east end (+X). Returns the model and the
-- rooftop CFrame (centre, on the roof surface).
function CampusKit.school(parent, cf, set, len, title)
	local m = Core.model(parent, "School", cf)
	local half, D = len / 2, 36
	local floorH, floors = BRICK * 7, 3
	local base = BRICK
	local roofY = base + floorH * floors
	local top = roofY + 0.6
	local gap = 2.6 -- between the facade and the solid core: the strip of classroom you see through the glass
	local coreZ = D - gap * 2
	Core.centered(m, cf, 0, 0, 0, len + 2, BRICK, D + 2, rgb(170, 168, 162))
	-- Solid core either side of the hall, and over it from the first floor up.
	Core.box(m, cf, 10, base, -coreZ / 2, half - gap - 10, floorH * floors, coreZ, P.interior, SMOOTH)
	Core.box(m, cf, -(half - gap), base, -coreZ / 2, half - gap - 10, floorH * floors, coreZ, P.interior, SMOOTH)
	Core.box(m, cf, -10, base + floorH, -coreZ / 2, 20, floorH * (floors - 1), coreZ, P.interior, SMOOTH)
	-- Facades: front (-Z) shows classrooms, back (+Z) plain glass. The ground floor leaves x -10..10 open.
	local function row(f, y, from, to, inside)
		local xb = -half
		while xb + 6 <= half - 2 do
			local x0, x1 = xb, xb + 6
			if from and x1 > from and x0 < to then
				if x0 < from then
					Core.box(m, f, x0, y, -0.5, from - x0, 3.6, 1, P.wall)
				end
				if x1 > to then
					Core.box(m, f, to, y, -0.5, x1 - to, 3.6, 1, P.wall)
				end
			else
				Core.box(m, f, x0, y, -0.5, 2, 3.6, 1, P.wall)
				windowBay(m, f, x0 + 4, y, inside)
			end
			xb += 6
		end
		Core.box(m, f, xb, y, -0.5, half - xb, 3.6, 1, P.wall)
	end
	for side = 0, 1 do
		local f = cf * CFrame.Angles(0, side * math.pi, 0) * CFrame.new(0, 0, -D / 2 + 0.5)
		for fl = 0, floors - 1 do
			local y = base + fl * floorH
			local ground = fl == 0
			local function band(y0, h)
				if ground then
					Core.box(m, f, -half, y0, -0.5, half - 10, h, 1, P.wall)
					Core.box(m, f, 10, y0, -0.5, half - 10, h, 1, P.wall)
				else
					Core.box(m, f, -half, y0, -0.5, len, h, 1, P.wall)
				end
			end
			band(y, BRICK * 2)
			band(y + BRICK * 2 + 3.6, floorH - BRICK * 2 - 3.6)
			row(f, y + BRICK * 2, ground and -10 or nil, ground and 10 or nil, side == 0)
			-- Classroom floor behind the glass (not across the hall).
			if ground then
				Core.box(m, f, -half + 1, y, 0.5, half - 11, 0.2, gap - 1, rgb(196, 176, 140), DECOR)
				Core.box(m, f, 10, y, 0.5, half - 11, 0.2, gap - 1, rgb(196, 176, 140), DECOR)
			else
				Core.box(m, f, -half + 1, y, 0.5, len - 2, 0.2, gap - 1, rgb(196, 176, 140), DECOR)
				Core.box(m, f, -half, y - 0.3, -0.8, len, 0.6, 0.4, P.frame, SMOOTH) -- floor band
			end
		end
		for _, sx in { -1, 1 } do
			Core.box(
				m,
				f,
				sx > 0 and half - 1.5 or -half - 0.5,
				base,
				-0.9,
				2,
				floorH * floors,
				0.6,
				P.wallShade,
				SMOOTH
			)
		end
	end
	-- End walls fit between the facades.
	for _, sx in { -1, 1 } do
		Core.box(m, cf, sx > 0 and half - 1 or -half, base, -D / 2 + 1, 1, floorH * floors, D - 2, P.wall)
	end
	-- Entrance hall: tiled floor, glass doors slid open, shoe lockers on both walls, a canopy out front.
	Core.box(m, cf, -10, base, -D / 2, 20, 0.2, D, P.tile, SMOOTH)
	for _, z in { -D / 2 + 0.5, D / 2 - 0.5 } do
		for _, sx in { -1, 1 } do
			Core.part(m, cf * CFrame.new(sx * 8, base + 3.6, z), Vector3.new(4, 7, 0.2), P.glass, GLASS)
			Core.part(m, cf * CFrame.new(sx * 9.8, base + 3.7, z), Vector3.new(0.4, 7.2, 0.6), P.frame, SMOOTH)
		end
		Core.part(m, cf * CFrame.new(0, base + 7.4, z), Vector3.new(20, 0.4, 0.6), P.frame, SMOOTH)
	end
	for _, sx in { -1, 1 } do
		for _, z in { -8, 4 } do
			local lf = cf * CFrame.new(sx * 9.4, base, z) * CFrame.Angles(0, sx * math.pi / 2, 0)
			Core.part(m, lf * CFrame.new(0, 2.6, 0), Vector3.new(10, 4.8, 1.2), rgb(120, 130, 140), SMOOTH)
			for k = 1, 3 do
				Core.part(m, lf * CFrame.new(0, 0.2 + k * 1.2, -0.62), Vector3.new(10, 0.15, 0.05), P.dark, DECOR)
			end
			for col = -2, 2 do
				Core.part(m, lf * CFrame.new(col * 2, 2.6, -0.63), Vector3.new(0.15, 4.8, 0.05), P.dark, DECOR)
			end
		end
	end
	local canopy = cf * CFrame.new(0, base + 8, -D / 2 - 4.5)
	Core.part(m, canopy, Vector3.new(24, 0.8, 9), P.frameDark, SMOOTH)
	for _, sx in { -1, 1 } do
		Core.part(m, cf * CFrame.new(sx * 11, 4.6, -D / 2 - 8.4), Vector3.new(0.6, 9.2, 0.6), P.metal, SMOOTH)
	end
	local nameplate = Core.part(m, canopy * CFrame.new(0, 1.4, -4.3), Vector3.new(22, 2, 0.3), C.white, SMOOTH)
	Core.label(nameplate, title, Enum.NormalId.Front, P.frame, C.white)
	-- Roof: slab, parapet, chain-link fence with a gap at the stair landing (east side, z -6..6).
	Core.centered(m, cf, 0, roofY, 0, len, 0.6, D, rgb(176, 178, 182))
	for side = 0, 3 do
		local f = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		local along = side % 2 == 0 and len or D - 2
		local across = side % 2 == 0 and D or len
		local east = side == 3 -- this frame's local X runs along world Z on the east end
		local function inGap(x)
			return east and x > -7 and x < 7
		end
		if east then
			for _, seg in { { -along / 2, -7 }, { 7, along / 2 } } do
				Core.part(
					m,
					f * CFrame.new((seg[1] + seg[2]) / 2, top + 0.6, -across / 2 + 0.5),
					Vector3.new(seg[2] - seg[1], 1.2, 1),
					P.wallShade,
					SMOOTH
				)
			end
		else
			Core.part(
				m,
				f * CFrame.new(0, top + 0.6, -across / 2 + 0.5),
				Vector3.new(along, 1.2, 1),
				P.wallShade,
				SMOOTH
			)
		end
		local posts = {}
		for x = -along / 2, along / 2 + 0.01, along / math.max(1, math.floor(along / 6)) do
			table.insert(posts, x)
		end
		for k, x in posts do
			if not inGap(x) then
				Core.part(m, f * CFrame.new(x, top + 3.2, -across / 2 + 0.5), Vector3.new(0.3, 4, 0.3), P.metal, SMOOTH)
				local nx = posts[k + 1]
				if nx and not inGap(nx) then
					Core.part(
						m,
						f * CFrame.new((x + nx) / 2, top + 3.2, -across / 2 + 0.5),
						Vector3.new(nx - x - 0.3, 3.8, 0.1),
						rgb(120, 150, 130),
						{ smooth = true, trans = 0.55 }
					)
				end
			end
		end
	end
	local tank = cf * CFrame.new(half - 12, top, 9)
	for _, c in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
		Core.centered(m, tank, c[1], 0, c[2], 0.5, 3, 0.5, P.metal, SMOOTH)
	end
	Core.cyl(m, tank, 0, 3, 0, 5, 4.4, C.white)
	Core.cyl(m, tank, 0, 7.4, 0, 3, 0.6, C.white)
	for k = 0, 1 do
		local ac = cf * CFrame.new(half - 20 - k * 5, top, -13)
		Core.centered(m, ac, 0, 0, 0, 3.6, 2.4, 2.4, rgb(220, 222, 224), SMOOTH)
		Core.part(
			m,
			ac * CFrame.new(0, 1.2, -1.25) * CFrame.Angles(0, math.pi / 2, 0),
			Vector3.new(0.1, 1.8, 1.8),
			P.dark,
			{ shape = Enum.PartType.Cylinder, smooth = true, collide = false }
		)
	end
	-- Clock tower over the centre.
	local tower = cf * CFrame.new(0, top, 2)
	Core.centered(m, tower, 0, 0, 0, 14, 15, 14, P.wall)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Core.centered(m, tower, c[1] * 7, 0, c[2] * 7, 1.6, 15.3, 1.6, P.frame, SMOOTH)
	end
	local face = tower * CFrame.new(0, 9, -7.05)
	Core.part(
		m,
		face * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.3, 10, 10),
		P.frame,
		{ shape = Enum.PartType.Cylinder, smooth = true }
	)
	Core.part(
		m,
		face * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.2, 9, 9),
		C.white,
		{ shape = Enum.PartType.Cylinder, smooth = true }
	)
	for k = 0, 11 do
		local a = k * math.pi / 6
		Core.part(
			m,
			face * CFrame.new(math.sin(a) * 3.7, math.cos(a) * 3.7, -0.35) * CFrame.Angles(0, 0, -a),
			Vector3.new(0.35, k % 3 == 0 and 1 or 0.55, 0.1),
			P.dark,
			DECOR
		)
	end
	for _, hand in { { "HourHand", 2.4, 0.5, -0.02 }, { "MinuteHand", 3.4, 0.32, -0.24 } } do
		local pivot = face * CFrame.new(0, 0, -0.45)
		local h = Core.model(m, hand[1], pivot)
		Core.part(h, pivot * CFrame.new(0, hand[2] / 2 - 0.3, 0), Vector3.new(hand[3], hand[2], 0.1), P.dark, DECOR)
		h:SetAttribute("Axis", Vector3.zAxis)
		h:SetAttribute("Speed", hand[4])
		Core.tag(h, "Rotor")
	end
	K.Build.roof(
		m,
		tower * CFrame.new(0, 15, 0),
		17,
		17,
		{ colors = set.roof, trim = set.trim, finial = true, brackets = false }
	)
	-- Switchback staircase up the east end: three flights of 8 steps (rise `top` / 24 each) on two lanes,
	-- landings at z -4..2 (front) and 18..24 (behind); the last landing meets the roof at the fence gap.
	local rise = top / 24
	local function flight(x, zFrom, zTo, y0)
		local dir = zTo > zFrom and 1 or -1
		for s = 0, 7 do
			local y = y0 + (s + 1) * rise
			Core.part(
				m,
				cf * CFrame.new(x, y - 0.6, zFrom + dir * (s * 2 + 1)),
				Vector3.new(4, 1.2, 2),
				rgb(180, 182, 186),
				SMOOTH
			)
		end
		for _, dx in { -2.1, 2.1 } do
			local a = cf * Vector3.new(x + dx, y0 + 3.4, zFrom)
			local b = cf * Vector3.new(x + dx, y0 + rise * 8 + 3.4, zTo)
			Core.part(m, CFrame.lookAt((a + b) / 2, b), Vector3.new(0.25, 0.25, (b - a).Magnitude), P.frame, SMOOTH)
		end
	end
	local laneA, laneB = half + 3, half + 7.2
	flight(laneA, 18, 2, 0)
	flight(laneB, 2, 18, rise * 8)
	flight(laneA, 18, 2, rise * 16)
	for k, landing in { { -4, 2 }, { 18, 24 }, { -4, 2 } } do
		local y = rise * 8 * k
		Core.box(m, cf, half, y - 0.6, landing[1], 9.4, 0.6, 6, rgb(170, 172, 176))
		Core.centered(m, cf, half + 8.6, 0, (landing[1] + landing[2]) / 2, 0.6, y - 0.6, 0.6, P.metal, SMOOTH)
	end
	return m, cf * CFrame.new(0, top, 0)
end

-- ------------------------------------------------------------------ sports

-- An open-air covered court: wooden floor with court lines, pillars, a gable roof and two hoops.
-- Returns the model and the floor-top CFrame (centre).
function CampusKit.gym(parent, cf, set, w, d)
	local m = Core.model(parent, "Gym", cf)
	Core.centered(m, cf, 0, 0, 0, w, PLATE, d, P.wood, SMOOTH)
	local y = PLATE + 0.03
	local function line(x, z, sx, sz)
		Core.part(m, cf * CFrame.new(x, y, z), Vector3.new(sx, 0.06, sz), P.line, DECOR)
	end
	line(0, -d / 2 + 2, w - 4, 0.3)
	line(0, d / 2 - 2, w - 4, 0.3)
	line(-w / 2 + 2, 0, 0.3, d - 4)
	line(w / 2 - 2, 0, 0.3, d - 4)
	line(0, 0, w - 4, 0.3)
	arc(m, cf, 5, 0.3, 0, math.pi * 2, 20, PLATE, P.line, 0.06)
	for _, sz in { -1, 1 } do
		line(0, sz * (d / 2 - 8), 10, 0.3)
		line(-5, sz * (d / 2 - 5), 0.3, 6)
		line(5, sz * (d / 2 - 5), 0.3, 6)
	end
	local roofH = 16
	for _, sx in { -1, 1 } do
		for z = -d / 2 + 1, d / 2 - 1, 8 do
			Core.centered(m, cf, sx * (w / 2 - 0.5), PLATE, z, 1, roofH - PLATE, 1, set.post, SMOOTH)
		end
		Core.part(
			m,
			cf * CFrame.new(sx * (w / 2 - 0.5), roofH - 0.4, 0),
			Vector3.new(1.2, 0.8, d + 0.2),
			P.frameDark,
			SMOOTH
		)
	end
	-- An open slatted roof, gently peaked: you can see the court (and the guardian) through it.
	for z = -d / 2, d / 2, 3 do
		for _, sx in { -1, 1 } do
			Core.part(
				m,
				cf * CFrame.new(sx * (w / 4 + 0.5), roofH + 1.4, z) * CFrame.Angles(0, 0, sx * math.rad(-12)),
				Vector3.new(w / 2 + 2, 0.5, 1.6),
				set.roof[1],
				SMOOTH
			)
		end
	end
	Core.part(m, cf * CFrame.new(0, roofH + 4.1, 0), Vector3.new(1.2, 0.6, d + 1), P.frameDark, SMOOTH)
	for _, sz in { -1, 1 } do
		local hoop = cf * CFrame.new(0, 0, sz * (d / 2 - 1)) * CFrame.Angles(0, sz > 0 and 0 or math.pi, 0)
		Core.centered(m, hoop, 0, PLATE, 0, 0.6, 9, 0.6, P.dark, SMOOTH)
		Core.part(m, hoop * CFrame.new(0, 9.2, -0.8), Vector3.new(0.4, 0.4, 1.8), P.dark, SMOOTH)
		Core.part(m, hoop * CFrame.new(0, 9.4, -1.8), Vector3.new(4, 2.6, 0.2), C.white, SMOOTH)
		Core.part(m, hoop * CFrame.new(0, 9.1, -1.92), Vector3.new(1.6, 1.1, 0.05), rgb(220, 70, 50), DECOR)
		arc(m, hoop * CFrame.new(0, 0, -2.75), 0.75, 0.12, 0, math.pi * 2, 10, 8.45, rgb(240, 120, 40), 0.12)
		for k = 0, 3 do
			local a = k * math.pi / 2
			Core.part(
				m,
				hoop * CFrame.new(math.cos(a) * 0.6, 8.0, -2.75 + math.sin(a) * 0.6),
				Vector3.new(0.08, 0.9, 0.08),
				C.white,
				DECOR
			)
		end
	end
	return m, cf * CFrame.new(0, PLATE, 0)
end

-- An outdoor pool on a raised deck: blue lanes, lane ropes, starting blocks and ladders. The wide west deck
-- (local -X) holds a ladder station. Returns the model and the west deck's top-centre CFrame.
function CampusKit.pool(parent, cf, w, d)
	local m = Core.model(parent, "Pool", cf)
	local deckH = BRICK
	local wx0, wx1, wz = -w / 2 + 14, w / 2 - 4, d / 2 - 4 -- water rectangle
	Core.box(m, cf, -w / 2, 0, -d / 2, wx0 + w / 2, deckH, d, P.tile)
	Core.box(m, cf, wx1, 0, -d / 2, w / 2 - wx1, deckH, d, P.tile)
	Core.box(m, cf, wx0, 0, wz, wx1 - wx0, deckH, d / 2 - wz, P.tile)
	Core.box(m, cf, wx0, 0, -d / 2, wx1 - wx0, deckH, d / 2 - wz, P.tile)
	Core.box(m, cf, wx0, 0, -wz, wx1 - wx0, 0.3, wz * 2, rgb(60, 130, 190), SMOOTH)
	local lanes = 4
	local laneW = (wx1 - wx0) / lanes
	for k = 0, lanes - 1 do
		local x = wx0 + laneW * (k + 0.5)
		Core.part(m, cf * CFrame.new(x, 0.32, 0), Vector3.new(0.5, 0.04, wz * 2 - 3), rgb(30, 70, 130), DECOR)
	end
	Core.box(
		m,
		cf,
		wx0,
		0.3,
		-wz,
		wx1 - wx0,
		deckH - 0.55,
		wz * 2,
		P.water,
		{ smooth = true, trans = 0.35, collide = false }
	)
	for k = 1, lanes - 1 do
		local x = wx0 + laneW * k
		local n = math.floor(wz * 2 / 3)
		for s = 0, n - 1 do
			local z = -wz + (s + 0.5) * (wz * 2 / n)
			Core.part(
				m,
				cf * CFrame.new(x, deckH - 0.25, z) * CFrame.Angles(0, math.pi / 2, 0),
				Vector3.new(wz * 2 / n - 0.1, 0.4, 0.4),
				s % 2 == 0 and rgb(230, 60, 50) or C.white,
				{ shape = Enum.PartType.Cylinder, smooth = true, collide = false }
			)
		end
	end
	for k = 0, lanes - 1 do
		local x = wx0 + laneW * (k + 0.5)
		local block = Core.centered(m, cf, x, deckH, wz + 1.2, 1.6, 1, 1.6, C.white, SMOOTH)
		Core.label(block, tostring(k + 1), Enum.NormalId.Front, P.frame, C.white)
	end
	for _, z in { -wz + 1, wz - 1 } do
		for _, dx in { -0.5, 0.5 } do
			Core.part(m, cf * CFrame.new(wx1 - 0.6 + dx, deckH + 1, z), Vector3.new(0.15, 2.4, 0.15), P.metal, SMOOTH)
		end
	end
	return m, cf * CFrame.new(-w / 2 + 7, deckH, 0)
end

-- A running track (stadium shape, three lanes) round a striped lawn with a football pitch, goals, hurdles
-- and corner flags. Straights run along Z. Returns the model, the west straight's centre and the pitch centre.
function CampusKit.track(parent, cf, straight, inner)
	local m = Core.model(parent, "Track", cf)
	local outer = inner + 8
	local mid = (inner + outer) / 2
	for _, sx in { -1, 1 } do
		Core.part(m, cf * CFrame.new(sx * mid, 0.2, 0), Vector3.new(8, PLATE, straight * 2), P.track, SMOOTH)
		for k = 0, 3 do
			Core.part(
				m,
				cf * CFrame.new(sx * (inner + 0.1 + k * 2.6), 0.43, 0),
				Vector3.new(0.2, 0.06, straight * 2),
				P.line,
				DECOR
			)
		end
	end
	for _, sz in { -1, 1 } do
		local end_ = cf * CFrame.new(0, 0, sz * straight)
		local a0 = sz > 0 and 0 or math.pi
		arc(m, end_, mid, 8, a0, a0 + math.pi, 16, 0, P.track, PLATE)
		for k = 0, 3 do
			arc(m, end_, inner + 0.1 + k * 2.6, 0.2, a0, a0 + math.pi, 16, PLATE, P.line, 0.06)
		end
	end
	-- Striped lawn inside the track.
	local hw = inner - 1
	local z = -straight - hw
	local stripe = 0
	while z < straight + hw do
		local zc = z + 2
		local over = math.max(0, math.abs(zc) - straight)
		local half = math.sqrt(math.max(0, hw * hw - over * over))
		half = math.floor(half)
		if half >= 2 then
			Core.box(m, cf, -half, 0, z, half * 2, PLATE, 4, P.lawn[stripe % 2 + 1])
		end
		z += 4
		stripe += 1
	end
	-- Pitch markings, goals and corner flags.
	local pw, pl = inner - 8, straight + inner * 0.55
	local function line(x, zz, sx, sz)
		Core.part(m, cf * CFrame.new(x, PLATE + 0.03, zz), Vector3.new(sx, 0.06, sz), P.line, DECOR)
	end
	line(-pw, 0, 0.3, pl * 2)
	line(pw, 0, 0.3, pl * 2)
	line(0, -pl, pw * 2, 0.3)
	line(0, pl, pw * 2, 0.3)
	line(0, 0, pw * 2, 0.3)
	arc(m, cf, 6, 0.3, 0, math.pi * 2, 20, PLATE, P.line, 0.06)
	for _, sz in { -1, 1 } do
		line(0, sz * (pl - 10), 20, 0.3)
		line(-10, sz * (pl - 5), 0.3, 10)
		line(10, sz * (pl - 5), 0.3, 10)
		local goal = cf * CFrame.new(0, PLATE, sz * pl)
		for _, x in { -4, 4 } do
			Core.part(m, goal * CFrame.new(x, 1.8, 0), Vector3.new(0.4, 3.6, 0.4), C.white, SMOOTH)
		end
		Core.part(m, goal * CFrame.new(0, 3.6, 0), Vector3.new(8.4, 0.4, 0.4), C.white, SMOOTH)
		Core.part(
			m,
			goal * CFrame.new(0, 1.8, sz * 2),
			Vector3.new(8, 3.6, 0.1),
			C.white,
			{ smooth = true, trans = 0.6, collide = false }
		)
		for _, x in { -pw, pw } do
			Core.part(m, cf * CFrame.new(x, PLATE + 1.2, sz * pl), Vector3.new(0.15, 2.4, 0.15), C.white, DECOR)
			local flag = Core.part(
				m,
				cf * CFrame.new(x + 0.5, PLATE + 2.1, sz * pl),
				Vector3.new(0.9, 0.6, 0.05),
				rgb(250, 200, 40),
				{ smooth = true, collide = false, tag = "Banner" }
			)
			flag:SetAttribute("Hinge", flag.CFrame * CFrame.new(-0.45, 0.3, 0))
		end
	end
	-- Hurdles down the east straight.
	for k = -1, 1 do
		local h = cf * CFrame.new(mid, PLATE, k * 14)
		for _, x in { -3.6, 3.6 } do
			Core.part(m, h * CFrame.new(x, 0.9, 0), Vector3.new(0.2, 1.8, 0.2), P.dark, SMOOTH)
		end
		Core.part(
			m,
			h * CFrame.new(0, 1.7, 0),
			Vector3.new(7.4, 0.35, 0.15),
			k % 2 == 0 and C.white or rgb(230, 60, 50),
			SMOOTH
		)
	end
	return m, cf * CFrame.new(-mid, PLATE, 0), cf * CFrame.new(0, PLATE, 0)
end

-- The campus back gate to the next zone: the school gate's pillars and arch, with the zone's name, plus
-- the two looks every zone gate carries ("Chains" when locked, a "Sheet" portal when open; ZoneClient
-- switches them per player). Tagged "ZoneGate" with attributes Zone and Trigger.
function CampusKit.exitGate(parent, cf, set, title, zone)
	local m = CampusKit.schoolGate(parent, cf, title)
	m.Name = "ZoneGate"
	local chains = Core.model(m, "Chains", cf)
	for _, x in { -6, -2, 2, 6 } do
		Core.part(chains, cf * CFrame.new(x, 4, 0), Vector3.new(0.3, 8, 0.3), P.dark, DECOR)
	end
	for _, y in { 1.5, 6.5 } do
		Core.part(chains, cf * CFrame.new(0, y, 0), Vector3.new(20, 0.3, 0.3), P.dark, DECOR)
	end
	local lock = Core.part(chains, cf * CFrame.new(0, 4, -0.4), Vector3.new(2.4, 2.4, 0.8), C.gold, DECOR)
	lock.Material = Enum.Material.Metal
	local sheetModel = Core.model(m, "Sheet", cf)
	local sheet = Core.part(
		sheetModel,
		cf * CFrame.new(0, 5, 0),
		Vector3.new(19, 10, 0.2),
		set.accent:Lerp(Color3.new(1, 1, 1), 0.5),
		{ neon = true, trans = 1, collide = false, tag = "LightPillar" }
	)
	local sparkles = Core.particles(
		sheet,
		{ color = C.white, size = 0.5, rate = 12, life = { 1, 2 }, speed = 1, spread = 90, lightEmission = 1 }
	)
	sparkles.Enabled = false
	m:SetAttribute("Zone", zone)
	m:SetAttribute("Trigger", (cf * CFrame.new(0, 3, 0)).Position)
	Core.tag(m, "ZoneGate")
	return m
end

-- A scoreboard on legs.
function CampusKit.scoreboard(parent, cf)
	local m = Core.model(parent, "Scoreboard", cf)
	for _, x in { -7, 7 } do
		Core.centered(m, cf, x, 0, 0, 1, 10, 1, P.frame, SMOOTH)
	end
	local board = Core.centered(m, cf, 0, 10, 0, 20, 7, 1, P.dark, SMOOTH)
	Core.centered(m, cf, 0, 9.6, 0, 20.8, 7.8, 0.8, P.frame, SMOOTH)
	Core.label(board, "HOME 0 : 0 AWAY", Enum.NormalId.Front, rgb(255, 210, 80), P.dark)
	return m
end

return CampusKit
