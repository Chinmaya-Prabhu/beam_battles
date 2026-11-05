-- Architecture and props: lanterns, torii, curved-eave roofs, walls, storeys, pagodas, shop booths, fences,
-- banners, crates, barrels. Frames: `cf` is the base centre on the ground, the front faces -Z.
local Core = require(script.Parent.Core)
local Bricks = require(game:GetService("ReplicatedStorage").Shared.Bricks)

local Build = {}
local BRICK, PLATE = Core.BRICK, Core.PLATE
local C = Bricks.C
local CORNERS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }

-- A beam along X that curves up toward both ends (torii kasagi, ridge lines). `lift` is the rise at the tips.
local function curvedBeam(m, cf, length, y, height, depth, lift, color, segments)
	segments = segments or 9
	local seg = length / segments
	for i = 0, segments - 1 do
		local xm = -length / 2 + (i + 0.5) * seg
		local t = xm / (length / 2)
		local yoff = t * t * lift
		local slope = 2 * t * lift / (length / 2)
		Core.part(
			m,
			cf * CFrame.new(xm, y + height / 2 + yoff, 0) * CFrame.Angles(0, 0, math.atan(slope)),
			Vector3.new(seg + 0.15, height + (i % 2) * 0.06, depth + (i % 2) * 0.06), -- joints never coincide
			color,
			{ smooth = true }
		)
	end
end

-- A stone lantern (tōrō): stepped plinth, shaft, firebox with glowing paper panels, flared stone cap.
function Build.lanternStone(parent, cf, set)
	local m = Core.model(parent, "StoneLantern", cf)
	local s1, s2 = set.stone[1], C.gray
	Core.centered(m, cf, 0, 0, 0, 5, PLATE * 2, 5, s2)
	Core.skirt(m, cf, 5, 5, PLATE * 2, 1, PLATE * 2, s1, { cornerH = 0 })
	Core.centered(m, cf, 0, PLATE * 2, 0, 3, PLATE * 2, 3, s1)
	Core.cyl(m, cf, 0, PLATE * 4, 0, 1.6, BRICK * 3, s1)
	Core.cyl(m, cf, 0, PLATE * 4 + BRICK * 1.5, 0, 1.9, 0.4, s2)
	local y = PLATE * 4 + BRICK * 3
	Core.centered(m, cf, 0, y, 0, 4, PLATE * 2, 4, s1)
	y += PLATE * 2
	for _, c in CORNERS do
		Core.part(
			m,
			cf * CFrame.new(c[1] * 1.3, y + 1.2, c[2] * 1.3),
			Vector3.new(0.6, 2.4, 0.6),
			s1,
			{ smooth = true }
		)
	end
	for k = 0, 3 do
		local face = cf * CFrame.Angles(0, k * math.pi / 2, 0)
		Core.part(
			m,
			face * CFrame.new(0, y + 1.2, -1.3),
			Vector3.new(2, 1.8, 0.2),
			C.lightYellow,
			{ smooth = true, trans = 0.1 }
		)
		Core.part(m, face * CFrame.new(0, y + 1.2, -1.42), Vector3.new(0.15, 1.8, 0.1), C.darkGray, { smooth = true })
	end
	local core = Core.part(
		m,
		cf * CFrame.new(0, y + 1.2, 0),
		Vector3.new(0.8, 0.8, 0.8),
		C.lightOrange,
		{ neon = true, collide = false }
	)
	Core.light(core, Color3.fromRGB(255, 196, 140), 11, 0.8, true)
	y += 2.4
	Core.centered(m, cf, 0, y, 0, 6, PLATE, 6, s2)
	Core.skirt(m, cf, 6, 6, y + PLATE, 2, BRICK, s1, { cornerH = PLATE * 2, cornerColor = s2 })
	Core.centered(m, cf, 0, y + PLATE, 0, 2, BRICK, 2, s1)
	Core.cyl(m, cf, 0, y + PLATE + BRICK, 0, 1.2, PLATE, s2)
	Core.ball(m, cf, 0, y + PLATE * 2 + BRICK + 0.5, 0, 1.2, s1)
	return m
end

-- A hanging paper lantern. `cf` is the hook point; it hangs below.
function Build.lanternPaper(parent, cf, color)
	local m = Core.model(parent, "PaperLantern", cf)
	-- Sways gently from its hook (KitMotion).
	m:SetAttribute("Hinge", cf)
	m:SetAttribute("Amp", 0.07)
	Core.tag(m, "Swing")
	Core.part(m, cf * CFrame.new(0, -0.5, 0), Vector3.new(0.15, 1, 0.15), C.black, { smooth = true, collide = false })
	Core.cyl(m, cf, 0, -1.4, 0, 1.2, PLATE, C.black, { collide = false })
	local body = Core.part(
		m,
		cf * CFrame.new(0, -2.5, 0),
		Vector3.new(1.9, 1.9, 1.9),
		color,
		{ shape = Enum.PartType.Ball, smooth = true, collide = false }
	)
	body.Material = Enum.Material.SmoothPlastic
	Core.part(
		m,
		cf * CFrame.new(0, -2.5, 0),
		Vector3.new(2.3, 1.1, 1.1),
		color:Lerp(Color3.new(1, 1, 1), 0.15),
		{ shape = Enum.PartType.Cylinder, smooth = true, collide = false }
	)
	Core.cyl(m, cf, 0, -3.8, 0, 1.2, PLATE, C.black, { collide = false })
	Core.part(m, cf * CFrame.new(0, -4.5, 0), Vector3.new(0.25, 1, 0.25), C.gold, { smooth = true, collide = false })
	Core.light(body, color:Lerp(Color3.new(1, 0.8, 0.5), 0.5), 12, 1.1, true)
	return m
end

-- A torii gate `w` wide and `h` tall with a curved top beam. opts: color, label, plaque (false = none)
function Build.torii(parent, cf, w, h, opts)
	opts = opts or {}
	local color = opts.color or C.vermilion
	local m = Core.model(parent, "Torii", cf)
	local px = w / 2 - 1.5
	for _, x in { -px, px } do
		Core.cyl(m, cf, x, 0, 0, 2.8, BRICK, C.black)
		Core.cyl(m, cf, x, BRICK, 0, 2.2, h - BRICK, color)
		Core.cyl(m, cf, x, h - 0.4, 0, 2.5, 0.4, C.black)
	end
	-- Tie beam (nuki) running through the pillars, with a strut and plaque up to the top beam.
	Core.centered(m, cf, 0, h - BRICK * 4, -0.5, w + 4, BRICK, 1, color)
	if opts.plaque ~= false then
		Core.centered(m, cf, 0, h - BRICK * 3, -0.4, 1, BRICK * 3, 0.8, color)
		local plaque = Core.centered(m, cf, 0, h - BRICK * 3.4, -1, 3.6, BRICK * 2.2, 0.4, C.black, { smooth = true })
		Core.centered(m, cf, 0, h - BRICK * 3.6, -0.9, 4.2, BRICK * 2.6, 0.2, C.gold, { smooth = true })
		if opts.label then
			Core.label(plaque, opts.label, Enum.NormalId.Front, C.gold)
		end
	end
	-- Curved kasagi with its black cap (shimaki).
	curvedBeam(m, cf, w + 5, h, BRICK, 2, 1, color)
	curvedBeam(m, cf, w + 7, h + BRICK, BRICK * 0.8, 2.6, 1.6, C.black)
	return m
end

-- A curved-eave hip roof over a w x d footprint (eave edge). `cf` is the roof's base centre.
-- opts: colors {dark, mid, light}, trim, finial, tiers (limit; flat top left for a storey above), brackets
-- Returns the model and the height of its top.
function Build.roof(parent, cf, w, d, opts)
	opts = opts or {}
	local ramp = opts.colors or { C.darkRed, C.red, C.vermilion }
	local trim = opts.trim or C.black
	local m = Core.model(parent, "Roof", cf)
	-- Shadowed underside, then the eave line.
	Core.centered(m, cf, 0, -PLATE, 0, w - 2, PLATE, d - 2, C.darkBrown)
	Core.centered(m, cf, 0, 0, 0, w, PLATE, d, trim)
	-- Flared eave: a shallow first ring, then steeper rings up to the ridge (reads as a curve).
	local y = PLATE
	Core.skirt(m, cf, w, d, y, 2, PLATE * 1.5, ramp[1], { cornerH = PLATE * 1.5, cornerColor = trim })
	Core.centered(m, cf, 0, y, 0, w - 4, PLATE * 1.5, d - 4, ramp[1])
	y += PLATE * 1.5
	local cw, cd, i = w - 4, d - 4, 0
	local maxTiers = opts.tiers or math.huge
	while math.min(cw, cd) >= 4 and i < maxTiers do
		local color = i % 2 == 0 and ramp[2] or ramp[3]
		-- Dark hip ridges climb the corners.
		Core.skirt(m, cf, cw, cd, y, 1, BRICK, color, { cornerColor = trim })
		Core.centered(m, cf, 0, y, 0, cw - 2, BRICK, cd - 2, color)
		y += BRICK
		cw -= 2
		cd -= 2
		i += 1
	end
	if not opts.tiers then
		-- Ridge along the long axis, with gold ends.
		Core.centered(m, cf, 0, y, 0, math.max(1, cw), BRICK, math.max(1, cd), trim)
		y += BRICK
		if cw > cd then
			for _, s in { -1, 1 } do
				Core.centered(m, cf, s * (cw / 2 - 0.5), y, 0, 1, BRICK, 1, C.gold)
			end
		end
	end
	-- Upturned corners on the eave.
	for _, c in CORNERS do
		local at = cf * CFrame.new(c[1] * (w / 2 - 0.5), PLATE, c[2] * (d / 2 - 0.5))
		Core.part(m, at * CFrame.new(0, 0.5, 0), Vector3.new(1, 1, 1), trim, { smooth = true })
		Core.part(
			m,
			at * CFrame.new(c[1] * 0.4, 1.2, c[2] * 0.4) * CFrame.Angles(c[2] * math.rad(25), 0, -c[1] * math.rad(25)),
			Vector3.new(0.8, 1, 0.8),
			C.gold,
			{ smooth = true }
		)
	end
	-- Brackets under the eaves.
	if opts.brackets ~= false then
		for k = 0, 3 do
			local face = cf * CFrame.Angles(0, k * math.pi / 2, 0)
			local along = k % 2 == 0 and w or d
			local across = k % 2 == 0 and d or w
			for x = -along / 2 + 3, along / 2 - 3, 4 do
				Core.part(
					m,
					face * CFrame.new(x, -PLATE * 2, -across / 2 + 2.5),
					Vector3.new(0.8, PLATE * 2, 1.4),
					opts.bracket or C.gold,
					{ smooth = true }
				)
			end
		end
	end
	if opts.finial then
		Core.cyl(m, cf, 0, y, 0, 1.4, PLATE, C.gold)
		for k = 0, 6 do
			Core.cyl(m, cf, 0, y + PLATE + k * 0.7, 0, 1.3 - k * 0.1, 0.3, C.gold)
		end
		Core.cyl(m, cf, 0, y + PLATE, 0, 0.4, 5.4, C.gold)
		Core.ball(m, cf, 0, y + PLATE + 5.8, 0, 1.1, C.gold)
	end
	return m, y
end

-- A gable roof along X (two slopes, ridge on top) over w x d. Returns the model and its top.
function Build.gable(parent, cf, w, d, rise, ramp, trim)
	local m = Core.model(parent, "Gable", cf)
	Core.centered(m, cf, 0, 0, 0, w, PLATE, d, trim)
	Core.slope(m, cf, -w / 2, w / 2, -d / 2, PLATE, d / 2, rise, ramp[2])
	Core.slope(m, cf * CFrame.Angles(0, math.pi, 0), -w / 2, w / 2, -d / 2, PLATE, d / 2, rise, ramp[3])
	Core.centered(m, cf, 0, PLATE + rise - 0.2, 0, w + 0.4, 0.8, 1.2, trim, { smooth = true })
	return m, PLATE + rise + 0.6
end

-- A wall along X, `length` long. style: "stone" (running bond) | "plaster" | "planks". opts: crenels, thick
function Build.wall(parent, cf, length, height, set, style, opts)
	opts = opts or {}
	local m = Core.model(parent, "Wall", cf)
	local thick = opts.thick or 1
	local rows = math.floor(height / BRICK)
	if style == "plaster" then
		Core.centered(m, cf, 0, 0, 0, length, rows * BRICK, thick, set.plaster)
		Core.centered(m, cf, 0, 0, -0.1, length, BRICK, thick + 0.2, set.wood[1])
	else
		local tones = style == "planks" and set.wood or set.stone
		for r = 0, rows - 1 do
			local x = -length / 2
			if r % 2 == 1 then
				Core.box(m, cf, x, r * BRICK, -thick / 2, 1, BRICK, thick, Core.pick(tones))
				x += 1
			end
			while x < length / 2 do
				local len = math.min(Core.pick(style == "planks" and { 4, 6 } or { 2, 3, 4 }), length / 2 - x)
				Core.box(m, cf, x, r * BRICK, -thick / 2, len, BRICK, thick, Core.pick(tones))
				x += len
			end
		end
		Core.centered(m, cf, 0, rows * BRICK, 0, length + 0.4, PLATE, thick + 0.4, C.gray)
	end
	if opts.crenels then
		for x = -length / 2, length / 2 - 2, 4 do
			Core.box(m, cf, x, rows * BRICK + PLATE, -thick / 2, 2, BRICK * 1.5, thick, set.stone[1])
		end
	end
	return m
end

-- Lattice window: frame, glowing paper, muntins. `at` is the window centre on the wall, facing -Z.
local function window(m, at, w, h, glow)
	Core.part(
		m,
		at * CFrame.new(0, 0, -0.05),
		Vector3.new(w, h, 0.2),
		glow and C.lightYellow or C.cream,
		{ neon = false, smooth = true }
	)
	if glow then
		Core.light(
			Core.part(
				m,
				at * CFrame.new(0, 0, 0.4),
				Vector3.new(0.4, 0.4, 0.4),
				C.lightOrange,
				{ trans = 1, collide = false }
			),
			Color3.fromRGB(255, 190, 110),
			10,
			0.8
		)
	end
	for k = 1, 2 do
		Core.part(
			m,
			at * CFrame.new(-w / 2 + k * w / 3, 0, -0.18),
			Vector3.new(0.15, h, 0.15),
			C.darkBrown,
			{ smooth = true }
		)
	end
	Core.part(m, at * CFrame.new(0, 0, -0.18), Vector3.new(w, 0.15, 0.15), C.darkBrown, { smooth = true })
	Core.part(m, at * CFrame.new(0, h / 2 + 0.2, -0.22), Vector3.new(w + 0.8, 0.4, 0.3), C.darkBrown, { smooth = true })
	Core.part(m, at * CFrame.new(0, -h / 2 - 0.2, -0.3), Vector3.new(w + 0.8, 0.4, 0.5), C.darkBrown, { smooth = true })
end

-- One storey: stone floor, posts, wainscot, plaster panels with lattice windows, beam bands, eave brackets,
-- optional sliding-door front and balcony. opts: post colour, door, balcony, glow
function Build.storey(parent, cf, w, h, set, opts)
	opts = opts or {}
	local m = Core.model(parent, "Storey", cf)
	local post = opts.post or set.post or set.accent
	Core.centered(m, cf, 0, 0, 0, w, BRICK, w, set.stone[1])
	Core.centered(m, cf, 0, BRICK - PLATE, 0, w + 0.4, PLATE, w + 0.4, C.gray)
	local y0 = BRICK
	for _, c in CORNERS do
		Core.centered(m, cf, c[1] * (w / 2 - 1), y0, c[2] * (w / 2 - 1), 2, h, 2, post)
	end
	local inner = w - 4
	for side = 0, 3 do
		local face = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		local zf = -w / 2 + 0.5
		if side == 0 and opts.door then
			-- Sliding shoji doors, one slid open onto a dark interior, with a noren curtain.
			local dw = math.min(6, inner - 2)
			local sideW = (inner - dw) / 2
			Core.box(m, face, -inner / 2, y0, zf, sideW, h, 1, set.plaster)
			Core.box(m, face, dw / 2, y0, zf, sideW, h, 1, set.plaster)
			Core.box(m, face, -dw / 2, y0 + h - BRICK * 2, zf, dw, BRICK * 2, 1, set.plaster)
			Core.box(m, face, -dw / 2, y0, zf + 1.2, dw, h - BRICK * 2, 0.4, C.darkBrown, { smooth = true })
			window(
				m,
				face * CFrame.new(dw / 4, y0 + (h - BRICK * 2) / 2, zf + 0.3),
				dw / 2 - 0.2,
				h - BRICK * 2 - 0.6,
				opts.glow
			)
			for k = 0, 2 do
				local strip = Core.box(
					m,
					face,
					-dw / 2 + k * dw / 3 + 0.1,
					y0 + h - BRICK * 3.5,
					zf - 0.3,
					dw / 3 - 0.2,
					BRICK * 1.5,
					0.2,
					set.accent,
					{ smooth = true, collide = false, tag = "Banner" }
				)
				strip:SetAttribute("Hinge", strip.CFrame * CFrame.new(0, BRICK * 0.75, 0))
			end
		else
			Core.box(m, face, -inner / 2, y0, zf, inner, h, 1, set.plaster)
			window(m, face * CFrame.new(0, y0 + h * 0.52, zf), math.min(4, inner - 2), math.min(3, h - 3), opts.glow)
		end
		-- Wainscot and beam bands.
		Core.box(m, face, -inner / 2, y0, zf - 0.2, inner, BRICK, 0.4, set.wood[1])
		Core.box(m, face, -w / 2, y0 + h - BRICK, -w / 2 - 0.2, w, BRICK, 1.2, post)
		-- Brackets stepping out under the eave.
		for _, x in { -w / 2 + 1, w / 2 - 1 } do
			Core.part(
				m,
				face * CFrame.new(x, y0 + h - BRICK * 1.5, -w / 2 - 0.6),
				Vector3.new(0.8, PLATE, 1.2),
				C.gold,
				{ smooth = true }
			)
		end
	end
	if opts.balcony then
		Core.centered(m, cf, 0, 0, 0, w + 4, PLATE, w + 4, set.wood[1]) -- on the roof below, not in it
		for side = 0, 3 do
			local face = cf * CFrame.Angles(0, side * math.pi / 2, 0)
			for x = -w / 2 - 1.5, w / 2 + 1.5, 2 do
				Core.part(
					m,
					face * CFrame.new(x, 1, -w / 2 - 1.6),
					Vector3.new(0.4, 2, 0.4),
					set.wood[#set.wood],
					{ smooth = true }
				)
			end
			Core.part(m, face * CFrame.new(0, 2.1, -w / 2 - 1.6), Vector3.new(w + 4, 0.4, 0.6), post, { smooth = true })
		end
	end
	return m, y0 + h
end

-- A pagoda of `storeys` floors on a stepped podium. Returns the model and its total height.
function Build.pagoda(parent, cf, storeys, w, set, opts)
	opts = opts or {}
	local m = Core.model(parent, "Pagoda", cf)
	Core.centered(m, cf, 0, 0, 0, w + 8, BRICK, w + 8, C.gray)
	Core.skirt(m, cf, w + 8, w + 8, BRICK, 1, BRICK, set.stone[1], { cornerH = 0 })
	Core.centered(m, cf, 0, BRICK, 0, w + 6, BRICK, w + 6, set.stone[1])
	for k = 0, 2 do
		Core.centered(m, cf, 0, k * BRICK, -(w + 8) / 2 - 1 - (2 - k) * 2 + 1, 6, BRICK * (k + 1), 2, set.stone[1])
	end
	local y = BRICK * 2
	for i = 1, storeys do
		local sw = math.max(6, w - (i - 1) * 2)
		local h = i == 1 and BRICK * 6 or BRICK * 4
		local _, top =
			Build.storey(m, cf * CFrame.new(0, y, 0), sw, h, set, { door = i == 1, balcony = i > 1, glow = opts.glow })
		y += top
		local last = i == storeys
		local eave = sw + (last and 8 or 7)
		eave += eave % 2
		local _, ry = Build.roof(m, cf * CFrame.new(0, y, 0), eave, eave, {
			colors = set.roof,
			tiers = not last and 1 or nil,
			finial = last,
			trim = set.trim or C.black,
		})
		if opts.lanterns then
			for _, c in CORNERS do
				Build.lanternPaper(
					m,
					cf * CFrame.new(c[1] * (eave / 2 - 0.5), y - PLATE, c[2] * (eave / 2 - 0.5)),
					C.red
				)
			end
		end
		y += ry
	end
	return m, y
end

-- A market booth facing -Z: plank walls, gable tile roof, striped awning, counter and goods.
-- opts: title, stripes {a, b}, signColor
function Build.shopFront(parent, cf, w, set, opts)
	opts = opts or {}
	local m = Core.model(parent, "Shop", cf)
	local stripes = opts.stripes or { set.accent, C.white }
	local wallH = BRICK * 6
	Core.centered(m, cf, 0, 0, 0, w + 2, BRICK, 10, set.stone[1])
	Core.skirt(m, cf, w + 2, 10, BRICK, 1, PLATE, set.stone[1], { cornerH = 0 })
	local floorY = BRICK
	Core.box(m, cf, -w / 2, floorY, 3, w, wallH, 1, set.wood[1])
	for _, x in { -w / 2, w / 2 - 1 } do
		Core.box(m, cf, x, floorY, -3, 1, wallH, 6, set.wood[#set.wood])
	end
	for _, x in { -w / 2, w / 2 - 1 } do
		Core.box(m, cf, x, floorY, -4, 1, wallH + BRICK, 1, set.post or set.accent)
	end
	-- The back faces the lower ring: plaster panel, beam bands and two lit lattice windows.
	local back = cf * CFrame.Angles(0, math.pi, 0)
	Core.box(m, back, -w / 2 + 1, floorY + BRICK, -4.3, w - 2, wallH - BRICK * 2, 0.3, set.plaster, { smooth = true })
	for _, y in { floorY + BRICK, floorY + wallH - BRICK * 1.5 } do
		Core.box(m, back, -w / 2, y, -4.5, w, PLATE * 1.5, 0.5, set.post or set.wood[1], { smooth = true })
	end
	for _, x in { -w / 4, w / 4 } do
		window(m, back * CFrame.new(x, floorY + wallH * 0.5, -4.35), 2.6, 2.2, true)
	end
	-- Counter and wares.
	Core.box(m, cf, -w / 2 + 1, floorY, -3.5, w - 2, BRICK * 2, 1.5, set.wood[1])
	Core.box(m, cf, -w / 2 + 1, floorY + BRICK * 2, -3.8, w - 2, PLATE, 2, C.lightTan, { smooth = true })
	for x = -w / 2 + 2, w / 2 - 2, 2 do
		Core.cyl(
			m,
			cf,
			x,
			floorY + BRICK * 2 + PLATE,
			-3,
			1,
			Core.pick({ 1, 1.3, 0.8 }),
			Core.pick({ C.red, C.azure, C.leafLight, C.lavender, C.gold })
		)
	end
	for _, y in { BRICK * 2.5, BRICK * 4 } do
		Core.box(m, cf, -w / 2 + 1, floorY + y, 2, w - 2, PLATE, 1, set.wood[#set.wood], { smooth = true })
		for x = -w / 2 + 1.5, w / 2 - 2, 1.5 do
			Core.cyl(
				m,
				cf,
				x,
				floorY + y + PLATE,
				2.5,
				0.7,
				Core.pick({ 0.8, 1.1 }),
				Core.pick({ C.red, C.azure, C.gold, C.pink, C.leafLight })
			)
		end
	end
	-- Gable roof.
	Build.gable(m, cf * CFrame.new(0, floorY + wallH + BRICK, 0), w + 4, 11, BRICK * 2.5, set.roof, set.trim or C.black)
	-- Striped awning sagging out from under the eave.
	local slope = math.atan2(BRICK * 1.2, 4)
	for k = 0, math.floor(w / 2) - 1 do
		local x = -w / 2 + k * 2 + 1
		local color = stripes[k % 2 + 1]
		Core.part(
			m,
			cf * CFrame.new(x, floorY + wallH - BRICK * 0.4, -6) * CFrame.Angles(-slope, 0, 0),
			Vector3.new(2, 0.3, 4.2),
			color,
			{ smooth = true }
		)
		Core.part(
			m,
			cf * CFrame.new(x, floorY + wallH - BRICK * 1.6, -8.05),
			Vector3.new(2, k % 2 == 0 and 1 or 0.6, 0.2),
			color,
			{ smooth = true }
		)
	end
	-- Hanging sign.
	local sign = Core.part(
		m,
		cf * CFrame.new(0, floorY + wallH + BRICK * 2.6, -5.6),
		Vector3.new(w - 2, BRICK * 1.8, 0.4),
		opts.signColor or set.accent,
		{ smooth = true }
	)
	Core.part(
		m,
		cf * CFrame.new(0, floorY + wallH + BRICK * 2.6, -5.5),
		Vector3.new(w - 1.4, BRICK * 1.8 + 0.6, 0.3),
		C.gold,
		{ smooth = true }
	)
	if opts.title then
		Core.label(sign, opts.title, Enum.NormalId.Front, C.white)
	end
	Build.lanternPaper(m, cf * CFrame.new(-w / 2 - 0.5, floorY + wallH, -4.5), C.red)
	Build.lanternPaper(m, cf * CFrame.new(w / 2 + 0.5, floorY + wallH, -4.5), C.red)
	Build.crate(m, cf * CFrame.new(-w / 2 - 2, floorY, -2), set)
	Build.barrel(m, cf * CFrame.new(w / 2 + 2, floorY, -1), set)
	return m
end

function Build.fence(parent, cf, length, set)
	local m = Core.model(parent, "Fence", cf)
	for x = -length / 2, length / 2, 3 do
		Core.box(m, cf, x - 0.5, 0, -0.5, 1, BRICK * 3, 1, set.wood[1])
		Core.roundPlate(m, cf, x, BRICK * 3, 0, set.wood[#set.wood])
	end
	for _, y in { BRICK, BRICK * 2.2 } do
		Core.box(m, cf, -length / 2, y, -0.3, length, PLATE, 0.6, set.wood[#set.wood], { smooth = true })
	end
	return m
end

-- A tall banner that sways (KitMotion). `emblem` is an optional colour for a diamond on the cloth.
function Build.banner(parent, cf, h, color, emblem)
	local m = Core.model(parent, "Banner", cf)
	Core.cyl(m, cf, 0, 0, 0, 1.6, PLATE, C.black)
	Core.cyl(m, cf, 0, PLATE, 0, 0.6, h, C.darkBrown)
	Core.ball(m, cf, 0, h + 0.8, 0, 1.2, C.gold)
	Core.rod(m, cf, 1.6, h - 0.3, 0, 4, 0.4, C.darkBrown)
	local hinge = cf * CFrame.new(1.6, h - 0.5, 0)
	local clothH = h * 0.45
	local cloth = Core.part(
		m,
		hinge * CFrame.new(0, -clothH / 2, 0),
		Vector3.new(3.4, clothH, 0.2),
		color,
		{ smooth = true, collide = false, tag = "Banner" }
	)
	cloth:SetAttribute("Hinge", hinge)
	for _, sx in { -1, 1 } do
		local tail = Core.part(
			m,
			hinge * CFrame.new(sx * 0.95, -clothH - 0.6, 0),
			Vector3.new(1.5, 1.2, 0.2),
			color,
			{ smooth = true, collide = false, tag = "Banner" }
		)
		tail:SetAttribute("Hinge", hinge)
	end
	if emblem then
		local e = Core.part(
			m,
			hinge * CFrame.new(0, -clothH * 0.4, -0.15) * CFrame.Angles(0, 0, math.pi / 4),
			Vector3.new(1.6, 1.6, 0.1),
			emblem,
			{ smooth = true, collide = false, tag = "Banner" }
		)
		e:SetAttribute("Hinge", hinge)
	end
	return m
end

function Build.crate(parent, cf, set)
	local m = Core.model(parent, "Crate", cf)
	Core.centered(m, cf, 0, 0, 0, 2, BRICK * 1.5, 2, set.wood[2] or set.wood[1])
	Core.centered(m, cf, 0, BRICK * 1.5, 0, 2, PLATE, 2, set.wood[1])
	for k = 0, 3 do
		local face = cf * CFrame.Angles(0, k * math.pi / 2, 0)
		Core.part(
			m,
			face * CFrame.new(0, 0.9, -1.03) * CFrame.Angles(0, 0, math.rad(42)),
			Vector3.new(2.4, 0.25, 0.1),
			set.wood[1],
			{ smooth = true }
		)
	end
	return m
end

function Build.barrel(parent, cf, set)
	local m = Core.model(parent, "Barrel", cf)
	Core.cyl(m, cf, 0, 0, 0, 2, BRICK * 2, set.wood[2] or set.wood[1])
	for _, y in { 0.35, BRICK * 2 - 0.55 } do
		Core.cyl(m, cf, 0, y, 0, 2.15, 0.25, C.darkGray)
	end
	Core.cyl(m, cf, 0, BRICK * 2, 0, 1.6, 0.1, set.wood[1])
	return m
end

-- Carp streamers (koinobori) on a tall pole with a spinning pinwheel on top. The carp ripple in the
-- wind (KitMotion "Streamer"); `cf` is the pole base, the wind blows toward +X.
function Build.koinobori(parent, cf, h)
	local m = Core.model(parent, "Koinobori", cf)
	Core.cyl(m, cf, 0, 0, 0, 1.6, PLATE, C.darkGray)
	Core.cyl(m, cf, 0, PLATE, 0, 0.5, h, C.white)
	Core.ball(m, cf, 0, h + 0.6, 0, 1, C.gold)
	-- Pinwheel: four vanes round a hub, turning about the pole.
	local wheel = Core.model(m, "Pinwheel", cf * CFrame.new(0, h - 0.6, 0))
	for k = 0, 3 do
		Core.part(
			wheel,
			cf
				* CFrame.new(0, h - 0.6, 0)
				* CFrame.Angles(0, k * math.pi / 2, 0)
				* CFrame.new(0, 0, -1)
				* CFrame.Angles(0.5, 0, 0),
			Vector3.new(0.5, 0.1, 1.8),
			k % 2 == 0 and C.gold or C.red,
			{ smooth = true, collide = false }
		)
	end
	wheel:SetAttribute("Speed", 3)
	Core.tag(wheel, "Spin")
	local carp = {
		{ body = C.black, belly = C.gold },
		{ body = C.red, belly = C.lightOrange },
		{ body = C.blue, belly = C.white },
	}
	for i, c in carp do
		local root = cf * CFrame.new(0.3, h - 1.6 - (i - 1) * 3.2, 0)
		local n = 6
		for k = 0, n - 1 do
			local size = 1.5 - k * 0.12
			local seg = Core.part(
				m,
				root * CFrame.new(k * 1.4 + 0.7, -size / 2, 0),
				Vector3.new(1.5, size, size * 0.8),
				k % 2 == 0 and c.body or c.body:Lerp(c.belly, 0.35),
				{ smooth = true, collide = false, shadow = false, tag = "Streamer" }
			)
			seg:SetAttribute("Root", root)
			seg:SetAttribute("Index", k)
			seg:SetAttribute("Count", n)
			seg:SetAttribute("Drop", -size / 2)
			seg:SetAttribute("Phase", i * 1.3)
			if k == 0 then
				-- Eyes on both sides of the head.
				for _, z in { -0.62, 0.62 } do
					local eye = Core.part(
						m,
						root * CFrame.new(0.5, -size / 2 + 0.2, z),
						Vector3.new(0.5, 0.5, 0.08),
						C.white,
						{ smooth = true, collide = false, shadow = false, tag = "Streamer" }
					)
					eye:SetAttribute("Root", root)
					eye:SetAttribute("Index", 0)
					eye:SetAttribute("Count", n)
					eye:SetAttribute("Drop", -size / 2 + 0.2)
					eye:SetAttribute("Offset", Vector3.new(-0.2, 0, z))
					eye:SetAttribute("Phase", i * 1.3)
				end
			end
		end
	end
	return m
end

-- A water wheel turning on an axle along X (KitMotion "Rotor"). `cf` is the axle centre.
function Build.waterWheel(parent, cf, radius, set)
	local m = Core.model(parent, "WaterWheel", cf)
	for _, x in { -2, 2 } do
		Core.box(m, cf, x - 0.5, -radius - 1, -1, 1, radius + 1.5, 2, set.wood[#set.wood])
	end
	local wheel = Core.model(m, "Wheel", cf)
	Core.part(wheel, cf, Vector3.new(3.4, 1.4, 1.4), C.darkBrown, { shape = Enum.PartType.Cylinder, smooth = true })
	local n = 10
	for k = 0, n - 1 do
		local spin = cf * CFrame.Angles(k * math.pi * 2 / n, 0, 0)
		Core.part(
			wheel,
			spin * CFrame.new(0, radius / 2, 0),
			Vector3.new(0.4, radius, 0.5),
			set.wood[1],
			{ smooth = true }
		)
		Core.part(
			wheel,
			spin * CFrame.new(0, radius + 0.4, 0),
			Vector3.new(2.6, 1.6, 0.3),
			set.wood[k % 2 + 1] or set.wood[1],
			{ smooth = true }
		)
		Core.part(
			wheel,
			spin * CFrame.new(-1.2, radius - 0.3, 0) * CFrame.Angles(math.pi / n, 0, 0),
			Vector3.new(0.3, 0.4, 2 * radius * math.sin(math.pi / n) + 0.2),
			C.darkBrown,
			{ smooth = true }
		)
		Core.part(
			wheel,
			spin * CFrame.new(1.2, radius - 0.3, 0) * CFrame.Angles(math.pi / n, 0, 0),
			Vector3.new(0.3, 0.4, 2 * radius * math.sin(math.pi / n) + 0.2),
			C.darkBrown,
			{ smooth = true }
		)
	end
	wheel:SetAttribute("Axis", Vector3.xAxis)
	wheel:SetAttribute("Speed", 0.7)
	Core.tag(wheel, "Rotor")
	return m
end

-- A bamboo water-knocker (shishi-odoshi): it slowly fills, tips, empties and knocks back (KitMotion
-- "Rocker"). `cf` is the base, the spout end faces -Z.
function Build.shishiOdoshi(parent, cf, set)
	local m = Core.model(parent, "ShishiOdoshi", cf)
	Core.centered(m, cf, 0, 0, -1.5, 4, BRICK, 3, C.gray)
	Core.centered(m, cf, 0, BRICK, -1.5, 3, PLATE, 2, Color3.fromRGB(64, 180, 225), { smooth = true, trans = 0.3 })
	for _, x in { -0.8, 0.8 } do
		Core.box(m, cf, x - 0.25, 0, 0.75, 0.5, 2.2, 0.5, set.wood[1])
	end
	local bamboo = Color3.fromRGB(120, 170, 70)
	local hinge = cf * CFrame.new(0, 2, 1)
	local tube = Core.part(
		m,
		hinge * CFrame.new(0, 0, -0.6) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(4.2, 0.6, 0.6),
		bamboo,
		{ shape = Enum.PartType.Cylinder, smooth = true, tag = "Rocker" }
	)
	tube:SetAttribute("Hinge", hinge)
	tube:SetAttribute("Period", 5)
	-- Feed pipe dripping into the tube.
	Core.part(
		m,
		cf * CFrame.new(0, 3.6, 1.8) * CFrame.Angles(0, math.pi / 2, math.rad(-20)),
		Vector3.new(2.6, 0.4, 0.4),
		bamboo,
		{ shape = Enum.PartType.Cylinder, smooth = true }
	)
	Core.box(m, cf, -0.3, 0, 2.4, 0.6, 4, 0.6, bamboo)
	local drip =
		Core.part(m, cf * CFrame.new(0, 3, 0.6), Vector3.new(0.2, 0.2, 0.2), bamboo, { trans = 1, collide = false })
	Core.particles(drip, {
		color = Color3.fromRGB(150, 210, 240),
		size = 0.12,
		rate = 12,
		life = { 0.3, 0.4 },
		speed = 1,
		spread = 5,
		accel = Vector3.new(0, -30, 0),
	})
	return m
end

-- A temple bell under a little roof; the striker log sways and the bell answers (KitMotion "Swing").
function Build.templeBell(parent, cf, set)
	local m = Core.model(parent, "TempleBell", cf)
	Core.centered(m, cf, 0, 0, 0, 10, BRICK, 10, set.stone[1])
	for _, c in CORNERS do
		Core.centered(m, cf, c[1] * 4, BRICK, c[2] * 4, 1, BRICK * 7, 1, set.post or set.accent)
	end
	Core.centered(m, cf, 0, BRICK * 8, 0, 10, BRICK, 10, set.post or set.accent)
	Build.roof(
		m,
		cf * CFrame.new(0, BRICK * 9, 0),
		14,
		14,
		{ colors = set.roof, trim = set.trim or C.black, finial = true, brackets = false }
	)
	local bronze = Color3.fromRGB(120, 92, 56)
	local hook = cf * CFrame.new(0, BRICK * 8, 0)
	local bell = Core.model(m, "Bell", hook)
	Core.part(bell, hook * CFrame.new(0, -0.5, 0), Vector3.new(0.4, 1, 0.4), C.black, { smooth = true })
	for k, d in { 2, 2.6, 2.8, 3 } do
		local part = Core.cyl(bell, hook, 0, -1 - k * 1.1, 0, d, 1.1, bronze)
		part.Material = Enum.Material.Metal
	end
	bell:SetAttribute("Hinge", hook)
	bell:SetAttribute("Amp", 0.03)
	bell:SetAttribute("Speed", 1.1)
	Core.tag(bell, "Swing")
	-- Striker log on two ropes.
	local log = Core.model(m, "Striker", hook * CFrame.new(-1, 0, 0))
	for _, z in { -0.8, 0.8 } do
		Core.part(
			log,
			hook * CFrame.new(-3, -1.6, z),
			Vector3.new(0.15, 3.2, 0.15),
			C.tan,
			{ smooth = true, collide = false }
		)
	end
	Core.part(
		log,
		hook * CFrame.new(-3, -3.4, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(3.4, 0.8, 0.8),
		set.wood[1],
		{ shape = Enum.PartType.Cylinder, smooth = true }
	)
	log:SetAttribute("Hinge", hook * CFrame.new(-3, 0, 0))
	log:SetAttribute("Amp", 0.22)
	log:SetAttribute("Speed", 1.1)
	log:SetAttribute("Roll", true)
	Core.tag(log, "Swing")
	return m
end

-- A bronze incense burner with drifting smoke.
function Build.incense(parent, cf)
	local m = Core.model(parent, "Incense", cf)
	local bronze = Color3.fromRGB(110, 86, 52)
	for _, c in { { -1, 0 }, { 1, 0 }, { 0, 1 } } do
		Core.part(
			m,
			cf * CFrame.new(c[1] * 0.8, 0.5, c[2] * 0.8 - 0.3),
			Vector3.new(0.4, 1, 0.4),
			bronze,
			{ smooth = true }
		)
	end
	local pot = Core.cyl(m, cf, 0, 1, 0, 2.6, 1.4, bronze)
	pot.Material = Enum.Material.Metal
	Core.cyl(m, cf, 0, 2.4, 0, 2.9, 0.3, bronze)
	Core.particles(pot, {
		texture = "smoke",
		color = Color3.fromRGB(235, 235, 240),
		size = NumberSequence.new(0.4, 2.4),
		rate = 3,
		life = { 4, 6 },
		speed = 1.2,
		spread = 8,
		accel = Vector3.new(0.3, 0.2, 0),
		rotSpeed = 30,
		transparency = 0.55,
	})
	return m
end

-- A paper sky lantern that rises slowly and fades, then starts again (KitMotion "Rise").
function Build.skyLantern(parent, cf, height, period, phase)
	local m = Core.model(parent, "SkyLantern", cf)
	local body = Core.part(
		m,
		cf * CFrame.new(0, 0.8, 0),
		Vector3.new(1.2, 1.6, 1.2),
		C.lightOrange,
		{ neon = true, collide = false, shadow = false }
	)
	Core.part(
		m,
		cf * CFrame.new(0, 1.7, 0),
		Vector3.new(1.3, 0.2, 1.3),
		C.darkOrange,
		{ smooth = true, collide = false, shadow = false }
	)
	Core.light(body, Color3.fromRGB(255, 170, 80), 10, 1, true)
	m:SetAttribute("Height", height)
	m:SetAttribute("Period", period)
	m:SetAttribute("Phase", phase)
	Core.tag(m, "Rise")
	return m
end

return Build
