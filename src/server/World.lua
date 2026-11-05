-- Builds Sky Dojo Island from studded Parts at server start (docs/HIT_PLAN.md §7.1).
-- Rules: every walkable top is studded; the island edge steps like bricks; the portal, colosseum,
-- altars and champion podiums are the tallest things so the eye lands on what matters.
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Kit = require(game:GetService("ReplicatedStorage").Shared.Kit)

local World = {}
local P = Config.Palette
local I = Config.Island

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function smooth(p)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function container(class, parent, name)
	local f = Instance.new(class)
	f.Name = name
	f.Parent = parent
	return f
end

local function polar(angleDeg, radius, y)
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, y or 0, math.sin(a) * radius)
end

local function label(p, text, face, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.LuckiestGuy
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.fromRGB(40, 20, 16)
	t.Parent = gui
	return t
end

-- A disc of studded rows: each 16-stud row spans the circle's width at that row, so tops never
-- overlap (no z-fighting) and the rim steps like bricks.
local function disc(parent, name, center, radius, topY, height, color, tile)
	tile = tile or I.tile
	for z = -radius, radius - tile, tile do
		local zc = z + tile / 2
		local half = math.sqrt(math.max(radius * radius - zc * zc, 0))
		half = math.floor(half / 4) * 4
		if half >= 4 then
			part(
				parent,
				name,
				Vector3.new(half * 2, height, tile),
				center + Vector3.new(0, topY - height / 2, zc),
				color
			)
		end
	end
end

-- A ring of `count` blocks between two radii, skipping angles inside `gaps` (degrees, ± width).
local function ring(parent, name, center, inner, outer, y, height, color, count, gaps, gapWidth)
	local mid = (inner + outer) / 2
	local arc = 2 * math.pi * mid / count
	for i = 0, count - 1 do
		local angle = i * 360 / count
		local skip = false
		for _, g in gaps or {} do
			local d = math.abs(((angle - g + 180) % 360) - 180)
			if d < gapWidth then
				skip = true
			end
		end
		if not skip then
			local pos = center + polar(angle, mid, y + height / 2)
			local tangent = polar(angle + 90, 1)
			-- Facing along the tangent puts the block's X axis on the radius.
			part(parent, name, Vector3.new(outer - inner, height, arc * 1.04), CFrame.lookAt(pos, pos + tangent), color)
		end
	end
end

local function floatingIsland(parent, name, center, radius)
	local m = container("Model", parent, name)
	disc(m, "Grass", center, radius, 0, 4, P.grass)
	local layers = {
		{ r = radius - 2, top = -4, h = 6, c = P.cliff },
		{ r = radius * 0.86, top = -10, h = 8, c = P.cliff },
		{ r = radius * 0.68, top = -18, h = 10, c = P.cliffDark },
		{ r = radius * 0.48, top = -28, h = 12, c = P.rock },
		{ r = radius * 0.27, top = -40, h = 14, c = P.rock },
	}
	for _, l in layers do
		if l.r >= 8 then
			disc(m, "Cliff", center, l.r, l.top, l.h, l.c)
		end
	end
	return m
end

local function lantern(parent, pos)
	local kit = Kit.place("StoneLantern", pos, { height = 6.5, parent = parent, yaw = math.random() * math.pi })
	if kit then
		local glow = Kit.parts(kit, "Glow")[1]
		if glow then
			glow.Material = Enum.Material.Neon
			glow.Color = Color3.fromRGB(255, 196, 120)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 170, 90)
			light.Range = 14
			light.Brightness = 1.2
			light.Parent = glow
		end
		return
	end
	part(parent, "LanternPost", Vector3.new(0.8, 7, 0.8), pos + Vector3.new(0, 3.5, 0), P.woodDark)
	part(parent, "LanternCap", Vector3.new(2.4, 0.5, 2.4), pos + Vector3.new(0, 9.4, 0), P.woodDark)
	local box = part(parent, "Lantern", Vector3.new(1.8, 2.2, 1.8), pos + Vector3.new(0, 8, 0), P.lantern, {
		Material = Enum.Material.SmoothPlastic,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = box
end

local treePick = 0
local function blossomTree(parent, pos, scale, petals)
	scale = scale or 1
	treePick += 1
	local kit = Kit.place("BlossomTree" .. (treePick % 3 + 1), pos, {
		height = 19 * scale,
		parent = parent,
		yaw = (treePick * 2.39) % (math.pi * 2),
	})
	if kit then
		if petals then
			local leaves = Kit.parts(kit, "Leaves")[1]
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(P.blossom)
			e.Size = NumberSequence.new(0.35)
			e.Rate = 3
			e.Lifetime = NumberRange.new(6, 9)
			e.Speed = NumberRange.new(0.5, 1.5)
			e.Acceleration = Vector3.new(0.6, -0.8, 0.3)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-60, 60)
			e.Parent = leaves
		end
		return kit
	end
	local m = container("Model", parent, "BlossomTree")
	part(m, "Trunk", Vector3.new(2.4, 11, 2.4) * scale, pos + Vector3.new(0, 5.5 * scale, 0), P.woodDark)
	part(
		m,
		"Branch",
		Vector3.new(1.4, 6, 1.4) * scale,
		CFrame.new(pos + Vector3.new(1.6, 10, 0) * scale) * CFrame.Angles(0, 0, math.rad(-35)),
		P.woodDark
	)
	local canopy = {
		{ Vector3.new(12, 5, 12), Vector3.new(0, 13, 0), P.blossom },
		{ Vector3.new(8, 4, 8), Vector3.new(-1, 17, 1), P.blossom },
		{ Vector3.new(7, 4, 6), Vector3.new(5, 12, -2), P.blossomDark },
		{ Vector3.new(6, 3, 7), Vector3.new(-4, 11, -3), P.blossomDark },
	}
	local top
	for _, c in canopy do
		top = part(m, "Leaves", c[1] * scale, pos + c[2] * scale, c[3])
	end
	if petals then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(P.blossom)
		e.Size = NumberSequence.new(0.35)
		e.Rate = 3
		e.Lifetime = NumberRange.new(6, 9)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Acceleration = Vector3.new(0.6, -0.8, 0.3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.LightEmission = 0.2
		e.Parent = top
	end
	return m
end

local function torii(parent, center, facing, width, height, color, text)
	local cf = CFrame.lookAt(center, center + facing)
	local kit = Kit.place("Torii", cf, {
		height = height + 2,
		parent = parent,
		colors = color ~= P.red and { Lacquer = color } or nil,
	})
	if kit then
		-- The plaque carries the text (owner name / game title) in front of the kit's gold plate.
		local _, size = kit:GetBoundingBox()
		local depth = math.min(size.X, size.Z)
		local plaque = part(
			kit,
			"Plaque",
			Vector3.new(size.Y * 0.42, size.Y * 0.13, 0.3),
			cf * CFrame.new(0, size.Y * 0.835, -depth / 2 - 0.2),
			P.woodDark
		)
		plaque.TopSurface = Enum.SurfaceType.Smooth
		local name = label(plaque, text or "", Enum.NormalId.Front, P.gold)
		name.Name = "Title"
		return kit, name
	end
	local m = container("Model", parent, "Torii")
	for _, x in { -width / 2, width / 2 } do
		part(m, "Pillar", Vector3.new(2, height, 2), cf * CFrame.new(x, height / 2, 0), color)
		part(m, "PillarBase", Vector3.new(2.8, 1, 2.8), cf * CFrame.new(x, 0.5, 0), P.woodDark)
	end
	part(m, "Kasagi", Vector3.new(width + 7, 1.6, 2.8), cf * CFrame.new(0, height + 0.8, 0), P.woodDark)
	part(m, "KasagiRed", Vector3.new(width + 5, 1, 2.4), cf * CFrame.new(0, height - 0.4, 0), color)
	part(m, "Nuki", Vector3.new(width + 3, 1, 1.4), cf * CFrame.new(0, height - 3.4, 0), color)
	local plaque =
		part(m, "Plaque", Vector3.new(width * 0.6, 2.6, 0.6), cf * CFrame.new(0, height - 1.9, -0.9), P.woodDark)
	local name = label(plaque, text or "", Enum.NormalId.Front, P.gold)
	name.Name = "Title"
	return m, name
end

local function buildCloudSea(root)
	-- Flattened clusters of overlapping puffs read as a cloud sea instead of separate balls.
	local clouds = container("Folder", root, "CloudSea")
	local rng = Random.new(7)
	if Kit.has("Cloud1") then
		for i = 1, 60 do
			local pos = polar(rng:NextNumber(0, 360), rng:NextNumber(60, 470), rng:NextNumber(-110, -80))
			Kit.place(
				i % 2 == 0 and "Cloud1" or "Cloud2",
				pos,
				{ width = rng:NextNumber(60, 130), parent = clouds, collide = false, yaw = rng:NextNumber(0, 6.28) }
			)
		end
		-- A few drifting puffs at island height, near the edges.
		for _ = 1, 10 do
			local pos = polar(rng:NextNumber(0, 360), rng:NextNumber(385, 480), rng:NextNumber(-20, 25)) -- (past the rim: the bases reach 335)
			Kit.place(
				"Cloud" .. rng:NextInteger(1, 2),
				pos,
				{ width = rng:NextNumber(30, 55), parent = clouds, collide = false, yaw = rng:NextNumber(0, 6.28) }
			)
		end
		return
	end
	for _ = 1, 34 do
		local center = polar(rng:NextNumber(0, 360), rng:NextNumber(40, 440), rng:NextNumber(-115, -85))
		local base = rng:NextNumber(50, 90)
		for _ = 1, 5 do
			local size = base * rng:NextNumber(0.55, 1)
			local offset = Vector3.new(
				rng:NextNumber(-1, 1) * base * 0.8,
				rng:NextNumber(0, 0.25) * base,
				rng:NextNumber(-1, 1) * base * 0.8
			)
			-- Ball parts are forced round; a sphere mesh on a block can be squashed into a puff.
			local p = part(clouds, "Cloud", Vector3.new(size * 1.3, size * 0.45, size), center + offset, P.cloud, {
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
				CanCollide = false,
				CanQuery = false,
			})
			smooth(p)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
	end
end

local function buildWaterfalls(root, island)
	for _, angle in { 160, 250, 340 } do
		local edge = polar(angle, I.radius - 4, 0)
		local out = polar(angle, 1)
		local cf = CFrame.lookAt(edge, edge + out)
		local water = part(island, "Waterfall", Vector3.new(16, 90, 2), cf * CFrame.new(0, -45, -6), P.water, {
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25,
			CanCollide = false,
			CastShadow = false,
		})
		smooth(water)
		part(island, "Stream", Vector3.new(14, 0.6, 22), cf * CFrame.new(0, 0.3, 8), P.water, {
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.2,
		})
		local mist = Instance.new("ParticleEmitter")
		mist.Color = ColorSequence.new(Color3.new(1, 1, 1))
		mist.Size = NumberSequence.new(4, 10)
		mist.Transparency = NumberSequence.new(0.6, 1)
		mist.Rate = 6
		mist.Lifetime = NumberRange.new(3, 5)
		mist.Speed = NumberRange.new(2, 4)
		mist.SpreadAngle = Vector2.new(60, 60)
		mist.Parent = water
	end
	return root
end

local function buildColosseum(root)
	local m = container("Model", root, "Colosseum")
	local S, T = I.stage, I.stands
	disc(m, "Stage", Vector3.zero, S.radius, S.height, S.height, P.stone, 8)
	ring(m, "StageRim", Vector3.zero, S.radius - 1, S.radius + 2, 0, S.height + 0.4, P.red, 40)
	-- Steps into the stage at the four entrances.
	for _, angle in { 0, 90, 180, 270 } do
		for i = 1, 2 do
			local pos = polar(angle, S.radius + 2 + (3 - i) * 2.5, 0)
			local tangent = polar(angle + 90, 1)
			part(
				m,
				"Step",
				Vector3.new(10, i * 1.2, 3),
				CFrame.lookAt(pos + Vector3.new(0, i * 0.6, 0), pos + Vector3.new(0, i * 0.6, 0) + tangent)
					* CFrame.Angles(0, math.pi / 2, 0),
				P.stoneDark
			)
		end
	end
	-- Rune circle in the stage centre.
	local rune = part(
		m,
		"Rune",
		Vector3.new(0.2, 26, 26),
		CFrame.new(0, S.height + 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
		P.gold,
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
		}
	)
	smooth(rune)
	local runeInner = rune:Clone()
	runeInner.Size = Vector3.new(0.25, 22, 22)
	runeInner.Color = P.stone
	runeInner.Material = Enum.Material.Plastic
	runeInner.Transparency = 0
	runeInner.Parent = m
	-- Tiered crowd stands with four entrances.
	local gaps = { 0, 90, 180, 270 }
	for t = 0, T.tiers - 1 do
		local inner = T.inner + t * (T.outer - T.inner) / T.tiers
		ring(
			m,
			"Stand",
			Vector3.zero,
			inner,
			T.outer,
			0,
			(t + 1) * T.tierHeight,
			t % 2 == 0 and P.stone or P.stoneDark,
			36,
			gaps,
			13
		)
	end
	ring(m, "StandWall", Vector3.zero, T.outer, T.outer + 2, 0, T.tiers * T.tierHeight + 3, P.red, 36, gaps, 13)
	-- Banners and lanterns at the entrances.
	for _, angle in gaps do
		for _, side in { -15, 15 } do
			local base = polar(angle + side, T.outer + 1, T.tiers * T.tierHeight + 3)
			part(m, "BannerPole", Vector3.new(0.8, 14, 0.8), base + Vector3.new(0, 7, 0), P.woodDark)
			local facing = polar(angle + side, 1)
			part(
				m,
				"Banner",
				Vector3.new(4, 7, 0.3),
				CFrame.lookAt(base + Vector3.new(0, 9.5, 0), base + Vector3.new(0, 9.5, 0) - facing)
					* CFrame.new(0, 0, -0.6),
				P.red
			)
		end
		lantern(m, polar(angle - 8, S.radius + 7))
		lantern(m, polar(angle + 8, S.radius + 7))
	end
	return m
end

local function buildPortal(root)
	local m = container("Model", root, "Portal")
	local center = Vector3.new(0, I.portal.height, 0)
	local r = I.portal.radius
	local kitRing = Kit.place("PortalRing", center - Vector3.new(0, 1.6, 0), {
		width = r * 2 + 4,
		parent = m,
		flat = true,
		collide = false,
	})
	if kitRing then
		kitRing.Name = "Ring"
		CollectionService:AddTag(kitRing, "PortalRing")
	end
	local spin = container("Model", m, kitRing and "BlockRing" or "Ring")
	local count = kitRing and 0 or 32
	for i = 0, count - 1 do
		local angle = i * 360 / count
		local pos = center + polar(angle, r, 0)
		local tangent = polar(angle + 90, 1)
		local block = part(
			spin,
			"RingBlock",
			Vector3.new(3.2, 3.2, 2 * math.pi * r / count * 1.05),
			CFrame.lookAt(pos, pos + tangent),
			i % 2 == 0 and P.gold or Color3.fromRGB(255, 232, 140),
			{
				CastShadow = false,
			}
		)
		block.TopSurface = Enum.SurfaceType.Studs
	end
	if not kitRing then
		spin.PrimaryPart = spin:FindFirstChild("RingBlock")
		CollectionService:AddTag(spin, "PortalRing")
	end
	local core = part(
		m,
		"Core",
		Vector3.new(0.6, r * 2 - 2, r * 2 - 2),
		CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(150, 90, 255),
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			CastShadow = false,
		}
	)
	smooth(core)
	local swirl = core:Clone()
	swirl.Name = "Swirl"
	swirl.Size = Vector3.new(0.7, r * 1.1, r * 1.1)
	swirl.Color = Color3.fromRGB(230, 220, 255)
	swirl.Transparency = 0.2
	swirl.Parent = m
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 130, 255)
	light.Range = 60
	light.Brightness = 2
	light.Parent = core
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromRGB(220, 190, 255), Color3.fromRGB(255, 230, 140))
	sparkle.Size = NumberSequence.new(1.2, 0)
	sparkle.Rate = 25
	sparkle.Lifetime = NumberRange.new(2, 4)
	sparkle.Speed = NumberRange.new(4, 9)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Parent = core
	-- Countdown board hanging under the portal; the client writes the time.
	local anchor = part(m, "CountdownAnchor", Vector3.one, center - Vector3.new(0, 10, 0), P.gold, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local board = Instance.new("BillboardGui")
	board.Name = "Countdown"
	board.Size = UDim2.fromScale(40, 10)
	board.LightInfluence = 0
	board.AlwaysOnTop = false
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

local function buildAltar(parent, index, spec)
	local tier = Config.Tiers[spec.tier]
	local base = polar(spec.angle, I.altarRadius)
	local toCenter = (-base).Unit
	local cf = CFrame.lookAt(base, base + toCenter)
	local m = container("Model", parent, "Altar" .. index)
	m:SetAttribute("Tier", spec.tier)
	m:SetAttribute("Index", index)
	local y = 0
	local top
	local body = Kit.place("Altar", cf, { width = 22.4, parent = m, colors = { Trim = tier.trim } })
	if body then
		-- Studded accent plate on top of the sculpted body: the fighter stands here.
		y = body:GetExtentsSize().Y
		top = part(m, "Top", Vector3.new(8.6, 0.4, 8.6), cf * CFrame.new(0, y + 0.2, 0), tier.trim)
		y += 0.4
	else
		local steps = { { 22, 2, P.stoneDark }, { 16, 2, P.stone }, { 11, 2, tier.trim } }
		for _, s in steps do
			top = part(m, "Step", Vector3.new(s[1], s[2], s[1]), cf * CFrame.new(0, y + s[2] / 2, 0), s[3])
			y += s[2]
		end
		top.Name = "Top"
	end
	local stand = Instance.new("Attachment")
	stand.Name = "FighterStand"
	stand.Parent = top
	stand.WorldPosition = base + Vector3.new(0, y, 0)
	local light = Instance.new("PointLight")
	light.Name = "RarityLight"
	light.Range = 24
	light.Brightness = 0
	light.Parent = top
	-- Braziers on the four corners.
	for _, c in { { -9, -9 }, { 9, -9 }, { -9, 9 }, { 9, 9 } } do
		local pillar = part(m, "Brazier", Vector3.new(2, 4, 2), cf * CFrame.new(c[1], 2, c[2]), P.woodDark)
		local bowl = part(m, "Bowl", Vector3.new(3, 1, 3), cf * CFrame.new(c[1], 4.5, c[2]), tier.trim)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Color = Color3.fromRGB(255, 140, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
		fire.Parent = bowl
		pillar.TopSurface = Enum.SurfaceType.Smooth
	end
	-- Two clash pads on either side (left/right of the altar as seen from the plaza centre).
	local pads = {}
	for i, side in { -1, 1 } do
		local pad = part(
			m,
			"ClashPad",
			Vector3.new(0.4, 7, 7),
			cf * CFrame.new(side * 17, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			tier.trim,
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Neon,
				Transparency = 0.45,
			}
		)
		smooth(pad)
		pad:SetAttribute("Side", i)
		pads[i] = pad
	end
	local sign = part(m, "Sign", Vector3.new(10, 2.4, 0.5), cf * CFrame.new(0, 2.6, -11.4), P.woodDark)
	label(sign, string.upper(spec.tier), Enum.NormalId.Front, tier.trim)
	m.PrimaryPart = top
	return m, pads
end

local function podium(parent, name, cf, size, color, trim)
	part(parent, name .. "Base", Vector3.new(size + 1.5, 1, size + 1.5), cf * CFrame.new(0, 0.5, 0), trim)
	local top = part(parent, name, Vector3.new(size, 1.2, size), cf * CFrame.new(0, 1.6, 0), color)
	return top
end

local function buildPlot(parent, index, angle)
	local color = Config.PlotColors[index]
	local center = polar(angle, I.plotRadius)
	local inward = (-center).Unit
	local cf = CFrame.lookAt(center, center + inward) -- -Z faces the plaza
	local w, d = I.plotSize.X, I.plotSize.Y
	local m = container("Model", parent, "Plot" .. index)
	m:SetAttribute("Index", index)
	part(m, "Base", Vector3.new(w, 1, d), cf * CFrame.new(0, 0.5, 0), P.path)
	part(m, "Border", Vector3.new(w + 2, 0.8, d + 2), cf * CFrame.new(0, 0.4, 0), color)
	-- Low stone fence on the sides and back.
	part(m, "Fence", Vector3.new(1, 2, d), cf * CFrame.new(-w / 2 - 0.5, 1.8, 0), P.stoneDark)
	part(m, "Fence", Vector3.new(1, 2, d), cf * CFrame.new(w / 2 + 0.5, 2.2, 0), P.stoneDark)
	part(m, "Fence", Vector3.new(w + 2, 2, 1), cf * CFrame.new(0, 1.8, d / 2 + 0.5), P.stoneDark)
	local _, title = torii(m, (cf * CFrame.new(0, 1, -d / 2 - 1)).Position, inward, 12, 14, color, "EMPTY PLOT")
	title.Name = "OwnerName"
	-- Podiums: two rows of four, champion at the back.
	local podiums = container("Folder", m, "Podiums")
	local slot = 0
	for row, z in { -5, 3 } do
		for _, x in { -14, -5, 5, 14 } do
			slot += 1
			local top = podium(podiums, "Podium" .. slot, cf * CFrame.new(x, 1, z), 5, P.stone, P.stoneDark)
			top:SetAttribute("Slot", slot)
			top:SetAttribute("Row", row)
		end
	end
	local champion = podium(podiums, "Champion", cf * CFrame.new(0, 1, 11), 7, P.red, P.gold)
	champion:SetAttribute("Slot", 0)
	-- Cash shrine by the gate.
	local shrine = container("Model", m, "CashShrine")
	local scf = cf * CFrame.new(w / 2 - 6, 1, -d / 2 + 6)
	part(shrine, "Plinth", Vector3.new(6, 1.4, 6), scf * CFrame.new(0, 0.7, 0), P.stoneDark)
	for _, c in { { -2.2, -2.2 }, { 2.2, -2.2 }, { -2.2, 2.2 }, { 2.2, 2.2 } } do
		part(shrine, "Post", Vector3.new(0.8, 5, 0.8), scf * CFrame.new(c[1], 3.9, c[2]), P.red)
	end
	part(shrine, "Roof", Vector3.new(8, 1, 8), scf * CFrame.new(0, 6.9, 0), P.woodDark)
	part(shrine, "RoofTop", Vector3.new(5, 1, 5), scf * CFrame.new(0, 7.9, 0), P.red)
	local dish = part(
		shrine,
		"Collector",
		Vector3.new(0.4, 4.4, 4.4),
		scf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(90, 255, 120),
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
		}
	)
	smooth(dish)
	-- Path from the plaza ring to the gate.
	local gate = (cf * CFrame.new(0, 0, -d / 2)).Position
	local from = polar(angle, I.altarRadius + 14)
	local length = (gate - from).Magnitude
	part(
		m,
		"Path",
		Vector3.new(8, 0.4, length),
		CFrame.lookAt((gate + from) / 2 + Vector3.new(0, 0.2, 0), gate + Vector3.new(0, 0.2, 0)),
		P.path
	)
	return m
end

local function stall(parent, name, pos, facing, stripe, sign)
	local cf = CFrame.lookAt(pos, pos + facing)
	local m = container("Model", parent, name)
	part(m, "Counter", Vector3.new(14, 3.4, 4), cf * CFrame.new(0, 1.7, 0), P.wood)
	part(m, "CounterTop", Vector3.new(15, 0.6, 5), cf * CFrame.new(0, 3.7, 0), P.woodDark)
	for _, x in { -7, 7 } do
		part(m, "Post", Vector3.new(1, 11, 1), cf * CFrame.new(x, 5.5, 1.5), P.woodDark)
	end
	for i = 0, 6 do
		part(
			m,
			"Canopy",
			Vector3.new(2.3, 0.8, 7),
			cf * CFrame.new(-6.9 + i * 2.3, 11.2, 0) * CFrame.Angles(math.rad(12), 0, 0),
			i % 2 == 0 and stripe or P.white
		)
	end
	local board = part(m, "Sign", Vector3.new(12, 3, 0.6), cf * CFrame.new(0, 13.6, 1.5), stripe)
	label(board, sign, Enum.NormalId.Front)
	m:SetAttribute("Stall", name)
	return m
end

local function buildPaths(root)
	local m = container("Model", root, "Paths")
	-- Main avenue from the bridge to the colosseum, lined with lanterns.
	local from, to = I.radius, I.stands.outer + 2
	part(m, "Avenue", Vector3.new(14, 0.4, from - to), Vector3.new(0, 0.2, (from + to) / 2), P.path)
	for z = to + 8, from - 6, 16 do
		lantern(m, Vector3.new(-9, 0, z))
		lantern(m, Vector3.new(9, 0, z))
	end
	-- Ring road through the altars.
	local count = 40
	local r = I.altarRadius
	for i = 0, count - 1 do
		local angle = i * 360 / count
		local pos = polar(angle, r, 0.2)
		local tangent = polar(angle + 90, 1)
		part(m, "Ring", Vector3.new(10, 0.4, 2 * math.pi * r / count * 1.06), CFrame.lookAt(pos, pos + tangent), P.path)
	end
	-- Spokes from the stands to the ring.
	for _, angle in { 0, 180, 270 } do
		local a, b = polar(angle, I.stands.outer + 2, 0.2), polar(angle, r - 5, 0.2)
		part(m, "Spoke", Vector3.new(10, 0.4, (a - b).Magnitude), CFrame.lookAt((a + b) / 2, b), P.path)
	end
	stall(m, "Shop", Vector3.new(-22, 0, 112), Vector3.new(1, 0, 0), P.red, "SHOP")
	stall(m, "Upgrades", Vector3.new(22, 0, 112), Vector3.new(-1, 0, 0), P.blue, "UPGRADES")
	return m
end

local function buildSpawnIslet(root)
	local s = I.spawnIslet
	local islet = floatingIsland(root, "SpawnIslet", Vector3.new(s.center.X, 0, s.center.Z), s.radius)
	-- Bridge from the islet to the main island.
	local north, south = I.radius - 6, s.center.Z - s.radius + 6
	local bridge = container("Model", root, "Bridge")
	part(bridge, "Deck", Vector3.new(12, 1, south - north), Vector3.new(0, -0.5, (north + south) / 2), P.wood)
	for z = north, south, 8 do
		for _, x in { -6.5, 6.5 } do
			part(bridge, "Post", Vector3.new(1, 4, 1), Vector3.new(x, 1.5, z), P.woodDark)
		end
	end
	for _, x in { -6.5, 6.5 } do
		part(bridge, "Rail", Vector3.new(0.6, 0.6, south - north), Vector3.new(x, 3.3, (north + south) / 2), P.red)
	end
	torii(islet, Vector3.new(0, 0, south + 2), Vector3.new(0, 0, -1), 14, 16, P.red, "ANIME BEAM BATTLE")
	blossomTree(islet, Vector3.new(-16, 0, s.center.Z + 4), 1, true)
	blossomTree(islet, Vector3.new(16, 0, s.center.Z - 2), 0.9, true)
	return islet
end

local function buildTrees(root)
	local m = container("Folder", root, "Trees")
	for i, angle in { 0, 45, 135, 180, 225, 270, 315 } do
		blossomTree(m, polar(angle, 134), 1.15, i % 2 == 1)
		blossomTree(m, polar(angle + 14, 104), 0.8, false)
		blossomTree(m, polar(angle - 14, 104), 0.8, false)
	end
	return m
end

-- True when a spot is clear of gameplay space (stage, ring road, altars, plots, paths, stalls, bridge).
local function free(pos, margin)
	margin = margin or 0
	local flat = Vector3.new(pos.X, 0, pos.Z)
	local r = flat.Magnitude
	if r < I.stands.outer + 4 + margin or r > I.radius - 6 or math.abs(r - I.altarRadius) < 7 + margin then
		return false
	end
	for _, spec in I.altars do
		if (flat - polar(spec.angle, I.altarRadius)).Magnitude < 25 + margin then
			return false
		end
	end
	for _, angle in I.plotAngles do
		if (flat - polar(angle, I.plotRadius)).Magnitude < 29 + margin then
			return false
		end
	end
	if math.abs(pos.X) < 13 + margin and pos.Z > I.stands.outer then
		return false -- avenue and bridge
	end
	for _, angle in { 0, 180, 270 } do
		local dir = polar(angle, 1)
		local along = flat:Dot(dir)
		if along > I.stands.outer and along < I.altarRadius and (flat - dir * along).Magnitude < 9 + margin then
			return false
		end
	end
	for _, x in { -22, 22 } do
		if (flat - Vector3.new(x, 0, 112)).Magnitude < 14 + margin then
			return false
		end
	end
	return true
end

local function buildScatter(root)
	if not Kit.has("Rock1") then
		return
	end
	local m = container("Folder", root, "Scatter")
	local rng = Random.new(21)
	local placed = {}
	local function try(name, opts, count, minR, maxR, margin)
		local made, tries = 0, 0
		while made < count and tries < count * 40 do
			tries += 1
			local pos = polar(rng:NextNumber(0, 360), rng:NextNumber(minR, maxR))
			local ok = free(pos, margin)
			for _, q in placed do
				if ok and (q - pos).Magnitude < (opts.spacing or 6) then
					ok = false
				end
			end
			if ok then
				opts.parent = m
				opts.yaw = rng:NextNumber(0, math.pi * 2)
				local copy = table.clone(opts)
				if copy.height then
					copy.height *= rng:NextNumber(0.8, 1.25)
				end
				if copy.width then
					copy.width *= rng:NextNumber(0.8, 1.25)
				end
				Kit.place(name, pos, copy)
				table.insert(placed, pos)
				made += 1
			end
		end
	end
	-- Big shapes first (trees, rocks), then mid (bushes), then small (flowers, grass).
	try("GreenTree1", { height = 22, spacing = 14 }, 5, 96, 148, 4)
	try("GreenTree2", { height = 20, spacing = 14 }, 5, 96, 148, 4)
	try("Pine", { height = 24, spacing = 14 }, 6, 120, 148, 4)
	for i = 1, 3 do
		try("Rock" .. i, { width = 7, spacing = 9 }, 5, 66, 148, 2)
	end
	try("Bush", { width = 6, spacing = 6, collide = false }, 18, 66, 148, 1)
	try("FlowerBush", { width = 6, spacing = 6, collide = false }, 14, 66, 148, 1)
	try("Flowers1", { width = 3.5, spacing = 4, collide = false }, 26, 66, 148, 0)
	try("Flowers2", { width = 3.5, spacing = 4, collide = false }, 26, 66, 148, 0)
	try("Grass", { height = 2.6, spacing = 3, collide = false }, 60, 66, 148, 0)
	-- Market clutter by the stalls.
	for _, spot in
		{
			{ -30, 106, "Barrel" },
			{ -31, 110, "Crate" },
			{ 30, 106, "Barrel" },
			{ 31, 110, "Crate" },
			{ -14, 107, "Barrel" },
			{ 14, 107, "Crate" },
		}
	do
		Kit.place(
			spot[3],
			Vector3.new(spot[1], 0, spot[2]),
			{ height = spot[3] == "Barrel" and 3.2 or 3, parent = m, yaw = rng:NextNumber(0, 6.28) }
		)
	end
end

-- Huge rocks hanging upside down under the island rim, so it reads as a floating chunk of rock.
local function buildUnderside(root, radius, center, count)
	if not Kit.has("Rock1") then
		return
	end
	local m = container("Folder", root, "Underside")
	local rng = Random.new(5 + count)
	for i = 1, count do
		local angle = i * 360 / count + rng:NextNumber(-6, 6)
		local pos = center + polar(angle, radius * rng:NextNumber(0.55, 0.88), -3)
		local base = CFrame.new(pos) * CFrame.Angles(math.pi, rng:NextNumber(0, 6.28), 0)
		Kit.place("Rock" .. rng:NextInteger(1, 3), base, {
			width = radius * rng:NextNumber(0.45, 0.7),
			parent = m,
			collide = false,
		})
	end
end

function World.build()
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local root = container("Folder", workspace, "Map")
	local island = floatingIsland(root, "Island", Vector3.zero, I.radius)
	buildWaterfalls(root, island)
	buildCloudSea(root)
	local colosseum = buildColosseum(root)
	local portal = buildPortal(root)
	local altars = container("Folder", root, "Altars")
	local pads = {}
	for i, spec in I.altars do
		local _, pair = buildAltar(altars, i, spec)
		pads[i] = pair
	end
	local plots = container("Folder", root, "Plots")
	for i, angle in I.plotAngles do
		buildPlot(plots, i, angle)
	end
	buildPaths(root)
	buildTrees(root)
	buildScatter(root)
	buildSpawnIslet(root)
	buildUnderside(root, I.radius, Vector3.zero, 18)
	buildUnderside(root, I.spawnIslet.radius, Vector3.new(0, 0, I.spawnIslet.center.Z), 5)
	return { root = root, altars = altars, pads = pads, plots = plots, portal = portal, colosseum = colosseum }
end

return World
