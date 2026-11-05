-- Ground pieces: terraces, island undersides, stairs, tile paths, bridges, waterfalls, ponds.
-- Grass is a mosaic of studded bricks in a few tones with a 1-stud overhanging lip; paths are smooth tiles
-- laid on top (studs vs. tiles is what makes the classic brick look read).
local Core = require(script.Parent.Core)

local Terrain = {}
local BRICK, PLATE = Core.BRICK, Core.PLATE

-- Fill a w x d rectangle (min corner x0, z0) with bricks of random sizes from `widths` x `depths`.
local function mosaic(m, cf, x0, z0, w, d, y, h, colors, widths, depths, opts)
	local z = 0
	while z < d do
		local rowD = math.min(Core.pick(depths), d - z)
		local x = 0
		while x < w do
			local tw = math.min(Core.pick(widths), w - x)
			Core.box(m, cf, x0 + x, y, z0 + z, tw, h, rowD, Core.pick(colors), opts)
			x += tw
		end
		z += rowD
	end
end

-- A raised block of land. `cf` is the centre of its top surface. opts: tiles = "fine" | "coarse",
-- noDrips, noDetail, strata (colours for the side layers).
function Terrain.terrace(parent, cf, w, d, h, set, opts)
	opts = opts or {}
	local m = Core.model(parent, "Terrace", cf)
	local coarse = opts.tiles == "coarse"
	-- Grass top with a 1-stud lip all round.
	mosaic(
		m,
		cf,
		-w / 2 - 1,
		-d / 2 - 1,
		w + 2,
		d + 2,
		-BRICK,
		BRICK,
		set.grass,
		coarse and { 6, 8, 10, 12 } or { 2, 3, 4, 4, 6 },
		coarse and { 4, 6, 8 } or { 2, 2, 4 }
	)
	-- Side strata: alternating bands of dirt (or stone) under the lip.
	local strata = opts.strata or set.dirt
	local y, band = -BRICK, 0
	while y > -h do
		local bh = math.min(BRICK * (band % 3 == 0 and 2 or 1), h + y)
		Core.box(m, cf, -w / 2, y - bh, -d / 2, w, bh, d, strata[band % #strata + 1])
		y -= bh
		band += 1
	end
	if not opts.noDrips then
		-- Grass dripping over the edge, under the lip.
		for _ = 1, math.floor((w + d) / 4) do
			local side = Core.int(1, 4)
			local along = Core.int(0, (side <= 2 and w or d) - 1)
			local len = Core.pick({ BRICK, BRICK, BRICK * 2 })
			local x, z
			if side == 1 then
				x, z = -w / 2 + along, -d / 2 - 1
			elseif side == 2 then
				x, z = -w / 2 + along, d / 2
			elseif side == 3 then
				x, z = -w / 2 - 1, -d / 2 + along
			else
				x, z = w / 2, -d / 2 + along
			end
			Core.box(m, cf, x, -BRICK - len, z, 1, len, 1, Core.pick(set.grass), { smooth = true })
		end
	end
	if not opts.noDetail then
		-- Stones poking out of the cliff face.
		for _ = 1, math.floor((w + d) / 6) do
			local side = Core.int(1, 4)
			local len = Core.int(2, 4)
			local yy = -BRICK * Core.int(2, math.max(2, math.floor(h / BRICK) - 1))
			local along = Core.int(0, math.max(0, (side <= 2 and w or d) - len))
			local color = Core.pick(set.stone)
			if side == 1 then
				Core.box(m, cf, -w / 2 + along, yy, -d / 2 - 0.6, len, BRICK, 1, color)
			elseif side == 2 then
				Core.box(m, cf, -w / 2 + along, yy, d / 2 - 0.4, len, BRICK, 1, color)
			elseif side == 3 then
				Core.box(m, cf, -w / 2 - 0.6, yy, -d / 2 + along, 1, BRICK, len, color)
			else
				Core.box(m, cf, w / 2 - 0.4, yy, -d / 2 + along, 1, BRICK, len, color)
			end
		end
	end
	return m
end

-- The underside of a floating island: an inverted, uneven stepped pyramid of rock with hanging vines.
-- `cf` is the centre of its top (the bottom of the terrace above).
function Terrain.underside(parent, cf, w, d, depth, set)
	local m = Core.model(parent, "Underside", cf)
	local x0, x1, z0, z1 = -w / 2, w / 2, -d / 2, d / 2
	local y, layer = 0, 0
	while y > -depth and x1 - x0 >= 4 and z1 - z0 >= 4 do
		local lh = BRICK * 2
		local color = layer % 3 == 2 and Core.pick(set.dirt) or Core.pick(set.stone)
		Core.box(m, cf, x0, y - lh, z0, x1 - x0, lh, z1 - z0, color)
		-- A boulder jutting out of this layer now and then.
		if Core.chance(0.5) then
			local s = Core.int(2, 4)
			if Core.chance(0.5) then
				Core.box(
					m,
					cf,
					Core.chance(0.5) and x0 - 1 or x1 - s + 1,
					y - lh,
					Core.int(z0, z1 - s),
					s,
					lh,
					s,
					Core.pick(set.stone)
				)
			else
				Core.box(
					m,
					cf,
					Core.int(x0, x1 - s),
					y - lh,
					Core.chance(0.5) and z0 - 1 or z1 - s + 1,
					s,
					lh,
					s,
					Core.pick(set.stone)
				)
			end
		end
		y -= lh
		layer += 1
		local shrink = math.max(1, math.floor(math.min(x1 - x0, z1 - z0) * Core.num(0.06, 0.14)))
		x0 += Core.int(1, shrink + 1)
		x1 -= Core.int(1, shrink + 1)
		z0 += Core.int(1, shrink + 1)
		z1 -= Core.int(1, shrink + 1)
	end
	-- Stalactites under the bottom.
	local cx, cz = math.floor((x0 + x1) / 2), math.floor((z0 + z1) / 2)
	Core.box(m, cf, cx - 1, y - BRICK * 3, cz - 1, 2, BRICK * 3, 2, Core.pick(set.stone))
	Core.box(m, cf, cx, y - BRICK * 5, cz, 1, BRICK * 2, 1, Core.pick(set.stone))
	-- Vines hanging from the rim.
	for _ = 1, math.floor((w + d) / 3) do
		local len = BRICK * Core.int(2, 7)
		local side = Core.int(1, 4)
		local x, z
		if side <= 2 then
			x, z = Core.int(-w / 2 + 1, w / 2 - 2), side == 1 and -d / 2 - 1 or d / 2
		else
			x, z = side == 3 and -w / 2 - 1 or w / 2, Core.int(-d / 2 + 1, d / 2 - 2)
		end
		Core.box(m, cf, x, -len, z, 1, len, 1, Core.pick(set.leaves or set.grass), { smooth = true, collide = false })
	end
	return m
end

-- Solid stairs climbing toward -Z from `cf` (bottom front centre). opts: colors, rails (accent colour)
function Terrain.stairs(parent, cf, width, steps, set, opts)
	opts = opts or {}
	local m = Core.model(parent, "Stairs", cf)
	local run = 2
	for i = 0, steps - 1 do
		local color = (opts.colors or set.stone)[i % 2 + 1] or set.stone[1]
		-- Tops sit a hair above the grid so the last step never shares a plane with the terrace it meets.
		Core.box(m, cf, -width / 2, 0, -(i + 1) * run, width, (i + 1) * BRICK + 0.06, run, color)
	end
	if opts.rails then
		for _, x in { -width / 2 - 1, width / 2 } do
			for i = 0, steps - 1 do
				Core.box(m, cf, x, 0, -(i + 1) * run, 1, (i + 2) * BRICK + 0.06, run, opts.rails)
			end
		end
	end
	return m
end

-- Smooth tiles laid on the ground along -Z, with a darker border. `cf` sits on the ground at the start.
function Terrain.path(parent, cf, length, width, set)
	local m = Core.model(parent, "Path", cf)
	local border = set.path[#set.path]
	local inner = {}
	for i = 1, #set.path - 1 do
		inner[i] = set.path[i]
	end
	for _, x in { -width / 2, width / 2 - 1 } do
		local z = 0
		while z < length do
			local seg = math.min(Core.int(2, 4), length - z)
			Core.box(m, cf, x, 0, -z - seg, 1, PLATE, seg, border, { smooth = true })
			z += seg
		end
	end
	mosaic(
		m,
		cf,
		-width / 2 + 1,
		-length,
		width - 2,
		length,
		0,
		PLATE,
		inner,
		{ 1, 2, 2, 3, 4 },
		{ 1, 2, 2 },
		{ smooth = true }
	)
	return m
end

-- A bridge along -Z. `cf` is the start of the deck (top surface). style: "wood" | "stone" | "rope"
function Terrain.bridge(parent, cf, length, width, style, set)
	local m = Core.model(parent, "Bridge", cf)
	local wood = set.wood
	if style == "stone" then
		mosaic(m, cf, -width / 2, -length, width, length, -BRICK, BRICK, set.stone, { 2, 3, 4 }, { 2 }, nil)
		for _, x in { -width / 2 - 1, width / 2 } do
			Core.box(m, cf, x, -BRICK, -length, 1, BRICK * 2, length, set.stone[1])
			for z = 0, length - 2, 4 do
				Core.box(m, cf, x, BRICK, -z - 2, 1, BRICK, 2, set.stone[#set.stone])
			end
		end
		-- Arch underneath.
		Core.box(m, cf, -width / 2, -BRICK * 3, -length + 2, width, BRICK * 2, length - 4, set.stone[1])
		return m
	end
	-- Planks across the deck.
	for z = 0, length - 1 do
		local w = width + (Core.chance(0.3) and 1 or 0)
		-- The deck sits one plate above the ground it lands on, so it never shares a plane with grass.
		Core.box(m, cf, -w / 2, 0, -z - 1, w, PLATE, 1, wood[z % #wood + 1], { smooth = true })
	end
	for _, x in { -width / 2 + 1, width / 2 - 2 } do
		Core.box(m, cf, x, -BRICK, -length, 1, BRICK, length, wood[#wood])
	end
	local posts = {}
	for z = 0, length, 4 do
		for _, x in { -width / 2 - 1, width / 2 } do
			Core.box(m, cf, x, -BRICK, -math.min(z, length - 1) - 1, 1, BRICK * 4, 1, wood[1])
			table.insert(posts, { x = x + 0.5, z = -math.min(z, length - 1) - 0.5 })
		end
	end
	if style == "rope" then
		for i = 1, #posts - 2 do
			local a, b = posts[i], posts[i + 2]
			local pa = cf * Vector3.new(a.x, BRICK * 2.6, a.z)
			local pb = cf * Vector3.new(b.x, BRICK * 2.6, b.z)
			local mid = (pa + pb) / 2 - Vector3.new(0, 0.6, 0)
			for _, seg in { { pa, mid }, { mid, pb } } do
				local len = (seg[2] - seg[1]).Magnitude
				Core.part(
					m,
					CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]) * CFrame.Angles(0, math.pi / 2, 0),
					Vector3.new(len, 0.3, 0.3),
					Color3.fromRGB(228, 205, 158),
					{ shape = Enum.PartType.Cylinder, smooth = true, collide = false }
				)
			end
		end
	else
		for _, x in { -width / 2 - 1, width / 2 } do
			Core.box(m, cf, x, BRICK * 3, -length, 1, PLATE, length, wood[#wood], { smooth = true })
		end
	end
	return m
end

-- Water spilling over an edge. `cf` is the lip: on top of the ground, facing the drop along -Z.
-- opts.pool = true adds a foam splash at the bottom; otherwise it falls into the clouds with a mist trail.
function Terrain.waterfall(parent, cf, height, width, _set, opts)
	opts = opts or {}
	local m = Core.model(parent, "Waterfall", cf)
	local water = Color3.fromRGB(64, 190, 230)
	local deep = Color3.fromRGB(30, 140, 200)
	-- Stream on top, running to the lip.
	Core.box(m, cf, -width / 2, 0, -1, width, PLATE, 6, water, { smooth = true, trans = 0.25, collide = false })
	-- The falling sheet (two layers for depth).
	Core.box(
		m,
		cf,
		-width / 2,
		-height,
		-2,
		width,
		height + PLATE,
		1,
		water,
		{ smooth = true, trans = 0.3, collide = false, shadow = false }
	)
	Core.box(
		m,
		cf,
		-width / 2 + 0.5,
		-height,
		-1.4,
		width - 1,
		height,
		0.4,
		deep,
		{ smooth = true, trans = 0.2, collide = false, shadow = false }
	)
	-- White streaks that slide down (client/KitMotion.lua).
	for _ = 1, math.max(4, math.floor(width * 1.5)) do
		local x = Core.num(-width / 2 + 0.5, width / 2 - 0.5)
		local len = Core.pick({ 1.2, 2.4, 3.6 })
		local top = cf * CFrame.new(x, -len / 2, -2.15)
		local s = Core.part(
			m,
			top,
			Vector3.new(Core.pick({ 0.4, 0.6, 1 }), len, 0.2),
			Color3.new(1, 1, 1),
			{ smooth = true, trans = 0.25, collide = false, shadow = false, tag = "WaterStreak" }
		)
		s:SetAttribute("Top", top)
		s:SetAttribute("Fall", height - len)
		s:SetAttribute("Phase", Core.num(0, height))
		s:SetAttribute("Speed", Core.num(14, 22))
	end
	local bottom = Core.part(
		m,
		cf * CFrame.new(0, -height, -2),
		Vector3.new(width, 1, 1),
		water,
		{ smooth = true, trans = 1, collide = false }
	)
	if opts.pool then
		for _ = 1, math.max(3, width) do
			Core.centered(
				m,
				cf,
				Core.int(-width / 2, width / 2),
				-height,
				-Core.int(1, 4),
				Core.int(1, 3),
				Core.pick({ PLATE, BRICK }),
				Core.int(1, 3),
				Color3.new(1, 1, 1),
				{ smooth = true, collide = false }
			)
		end
		Core.particles(bottom, {
			texture = "smoke",
			color = Color3.new(1, 1, 1),
			size = NumberSequence.new(2, 5),
			rate = 8,
			life = { 1, 2 },
			speed = 3,
			spread = 60,
			transparency = 0.5,
		})
	else
		Core.particles(bottom, {
			texture = "smoke",
			color = Color3.new(1, 1, 1),
			size = NumberSequence.new(3, 8),
			rate = 6,
			life = { 2, 3 },
			speed = 2,
			spread = 40,
			accel = Vector3.new(0, -4, 0),
			transparency = 0.6,
		})
	end
	return m
end

-- A raised pond with lily pads and koi. `cf` is on the ground at the centre.
function Terrain.pond(parent, cf, w, d, set)
	local m = Core.model(parent, "Pond", cf)
	-- Rim of stones.
	for _, side in
		{
			{ -w / 2 - 1, -d / 2 - 1, w + 2, 1 },
			{ -w / 2 - 1, d / 2, w + 2, 1 },
			{ -w / 2 - 1, -d / 2, 1, d },
			{ w / 2, -d / 2, 1, d },
		}
	do
		local x, z, sw, sd = side[1], side[2], side[3], side[4]
		local along = sw > sd and sw or sd
		local pos = 0
		while pos < along do
			local seg = math.min(Core.int(2, 3), along - pos)
			if sw > sd then
				Core.box(m, cf, x + pos, 0, z, seg, BRICK, 1, Core.pick(set.stone))
			else
				Core.box(m, cf, x, 0, z + pos, 1, BRICK, seg, Core.pick(set.stone))
			end
			pos += seg
		end
	end
	Core.box(m, cf, -w / 2, 0, -d / 2, w, PLATE, d, Color3.fromRGB(20, 70, 110))
	Core.box(
		m,
		cf,
		-w / 2,
		PLATE,
		-d / 2,
		w,
		PLATE * 1.5,
		d,
		Color3.fromRGB(64, 190, 230),
		{ smooth = true, trans = 0.35 }
	)
	for _ = 1, math.floor(w * d / 16) do
		local x, z = Core.int(-w / 2 + 1, w / 2 - 1), Core.int(-d / 2 + 1, d / 2 - 1)
		Core.cyl(
			m,
			cf,
			x,
			PLATE * 2.5,
			z,
			Core.pick({ 1.6, 2 }),
			0.2,
			Core.pick({ Color3.fromRGB(75, 159, 74), Color3.fromRGB(187, 233, 11) })
		)
		if Core.chance(0.4) then
			Core.roundPlate(m, cf, x + 0.3, PLATE * 2.5 + 0.2, z, Color3.fromRGB(255, 205, 222), 0.6)
		end
	end
	for i = 1, 3 do
		local koi = Core.box(
			m,
			cf,
			0,
			PLATE * 1.2,
			0,
			0.6,
			0.4,
			1.6,
			i == 2 and Color3.new(1, 1, 1) or Color3.fromRGB(254, 138, 24),
			{ smooth = true, collide = false, tag = "Koi" }
		)
		koi:SetAttribute("Center", cf * CFrame.new(0, PLATE * 1.4, 0))
		koi:SetAttribute("Radius", math.min(w, d) / 2 - 1.5)
		koi:SetAttribute("Phase", i * 2.1)
	end
	return m
end

-- A landmass of any outline on a grid of `cell`-stud cells: studded grass top (mosaic), banded cliffs,
-- grass drips over the rim and, optionally, a rocky underside that narrows into a point.
-- `shape(x, z)` is true inside (local coords, cf at the centre of the top surface); `half` bounds it.
-- opts: cell (4), top (mask for where grass goes; default = shape), under (depth), tiles ("coarse"),
--       noDrips
function Terrain.landmass(parent, cf, half, shape, h, set, opts)
	opts = opts or {}
	local cell = opts.cell or 4
	local top = opts.top or shape
	local m = Core.model(parent, "Landmass", cf)
	local widths = opts.tiles == "fine" and { 4, 4, 8 } or { 8, 12, 16, 8 }
	-- Runs of consecutive cells in one row where `mask` holds.
	local function runs(mask, z)
		local out = {}
		local start
		for x = -half, half, cell do
			local inside = mask(x + cell / 2, z + cell / 2)
			if inside and not start then
				start = x
			elseif not inside and start then
				table.insert(out, { start, x })
				start = nil
			end
		end
		if start then
			table.insert(out, { start, half + cell })
		end
		return out
	end
	for z = -half, half, cell do
		-- Grass top.
		for _, r in runs(top, z) do
			local x = r[1]
			while x < r[2] do
				local len = math.min(Core.pick(widths), r[2] - x)
				Core.box(m, cf, x, -BRICK, z, len, BRICK, cell, Core.pick(set.grass))
				x += len
			end
		end
		-- Cliff bands under the whole row.
		for _, r in runs(shape, z) do
			local y, band = -BRICK, 0
			while y > -h do
				local bh = math.min(band % 3 == 0 and BRICK * 2 or BRICK, h + y)
				Core.box(m, cf, r[1], y - bh, z, r[2] - r[1], bh, cell, set.dirt[band % #set.dirt + 1])
				y -= bh
				band += 1
			end
			-- Drips at the row's ends and where the row above/below ends.
			if not opts.noDrips then
				for _, x in { r[1] - 1, r[2] } do
					if Core.chance(0.6) then
						Core.box(
							m,
							cf,
							x,
							-BRICK - BRICK * Core.int(1, 2),
							z + Core.int(0, cell - 1),
							1,
							BRICK * 2,
							1,
							Core.pick(set.grass),
							{ smooth = true }
						)
					end
				end
				for _, dz in { -1, cell } do
					local zz = dz < 0 and z - 1 or z + cell
					for x = r[1], r[2] - 1, cell do
						if not shape(x + cell / 2, zz + (dz < 0 and -cell / 2 or cell / 2)) and Core.chance(0.35) then
							Core.box(
								m,
								cf,
								x + Core.int(0, cell - 1),
								-BRICK * Core.int(2, 3),
								zz,
								1,
								BRICK * 2,
								1,
								Core.pick(set.grass),
								{ smooth = true }
							)
						end
					end
				end
			end
		end
	end
	-- Underside: each layer is the outline shrunk a little more, with a ragged edge, down to a point.
	if opts.under then
		local layers = math.floor(opts.under / (BRICK * 2))
		for layer = 1, layers do
			-- Scale grows so the outline shrinks to a point by the last layer (a rounded, convex underside).
			local s = 1 / (1 - (layer / layers) ^ 0.8 * 0.92)
			local y = -h - (layer - 1) * BRICK * 2
			local color = layer % 3 == 0 and Core.pick(set.dirt) or Core.pick(set.stone)
			local any = false
			for z = -half, half, cell do
				for _, r in
					runs(function(x, zz)
						return shape(x * s, zz * s) and (Core.chance(0.93) or layer < 2)
					end, z)
				do
					any = true
					Core.box(m, cf, r[1], y - BRICK * 2, z, r[2] - r[1], BRICK * 2, cell, color)
				end
			end
			if not any then
				break
			end
		end
	end
	return m
end

-- A tiled ring road: smooth tiles with darker borders following a circle. `center` sits on the ground.
-- opts: segments, gaps = { { fromDeg, toDeg }, ... } (angles from +X toward +Z), color (border)
function Terrain.ringPath(parent, center, radius, width, set, opts)
	opts = opts or {}
	local m = Core.model(parent, "RingPath", center)
	local n = opts.segments or math.floor(2 * math.pi * radius / 3)
	local seg = 2 * math.pi * radius / n
	local border = opts.color or set.path[#set.path]
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local deg = math.deg(a)
		local skip = false
		for _, g in opts.gaps or {} do
			if deg >= g[1] and deg <= g[2] then
				skip = true
			end
		end
		if not skip then
			-- Neighbouring segments overlap a sliver at their joints; odd ones sit 0.05 higher so they never flicker.
			local p = center * Vector3.new(math.cos(a) * radius, PLATE / 2 + (i % 2) * 0.05, math.sin(a) * radius)
			local frame = CFrame.lookAt(p, p + center:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a))))
			Core.part(m, frame, Vector3.new(width - 2, PLATE, seg + 0.2), set.path[i % 2 + 1], { smooth = true })
			for _, x in { -(width / 2 - 0.5), width / 2 - 0.5 } do
				Core.part(m, frame * CFrame.new(x, 0, 0), Vector3.new(1, PLATE, seg + 0.2), border, { smooth = true })
			end
		end
	end
	return m
end

return Terrain
