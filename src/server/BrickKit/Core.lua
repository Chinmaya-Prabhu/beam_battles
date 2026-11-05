-- Brick Kit core (docs/WORLD_PLAN.md §9). Every world piece is built from studded bricks on a 1-stud grid:
-- tops are studded, undersides inlet, heights come in bricks (1.2) and plates (0.4).
-- Builders work in a local frame `cf` (origin on the ground, +Y up). box() takes a min corner and a size,
-- so with whole-stud inputs every edge lands on the grid and neighbouring studs line up.
-- Client motion (client/KitMotion.lua) is driven by tags: Banner, WaterStreak, Spin, Bob, Flicker,
-- LightPillar, Koi.
local CollectionService = game:GetService("CollectionService")

local Core = {}

Core.BRICK = 1.2
Core.PLATE = 0.4

local rng = Random.new(1)

-- Builders are deterministic: the same seed gives the same tree, rock or path.
function Core.seed(n)
	rng = Random.new(n)
end

function Core.num(a, b)
	return rng:NextNumber(a, b)
end

function Core.int(a, b)
	return rng:NextInteger(a, b)
end

function Core.pick(list)
	return list[rng:NextInteger(1, #list)]
end

function Core.chance(p)
	return rng:NextNumber() < p
end

function Core.model(parent, name, cf)
	local m = Instance.new("Model")
	m.Name = name
	m.WorldPivot = cf
	m.Parent = parent
	return m
end

function Core.tag(inst, tag)
	CollectionService:AddTag(inst, tag)
	return inst
end

-- opts: class ("WedgePart" | "CornerWedgePart"), shape (Enum.PartType), smooth (no studs), neon,
--       material, trans, collide (false = walk-through), shadow (false), tag, name
local function apply(p, color, opts)
	p.Anchored = true
	p.Color = color
	p.Material = opts.material or (opts.neon and Enum.Material.Neon) or Enum.Material.Plastic
	if opts.smooth or opts.neon or opts.material then
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	else
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
	end
	if opts.trans then
		p.Transparency = opts.trans
	end
	if opts.collide == false then
		p.CanCollide = false
		p.CanQuery = false
	end
	p.CanTouch = false
	if opts.shadow == false then
		p.CastShadow = false
	end
	if opts.tag then
		CollectionService:AddTag(p, opts.tag)
	end
end

-- A part centred at the world CFrame `at`.
function Core.part(parent, at, size, color, opts)
	opts = opts or {}
	local p = Instance.new(opts.class or "Part")
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Name = opts.name or "Brick"
	p.Size = size
	p.CFrame = at
	apply(p, color, opts)
	p.Parent = parent
	return p
end

-- An axis-aligned brick in frame `cf`: min corner (x, y, z), size (sx, sy, sz).
function Core.box(parent, cf, x, y, z, sx, sy, sz, color, opts)
	return Core.part(parent, cf * CFrame.new(x + sx / 2, y + sy / 2, z + sz / 2), Vector3.new(sx, sy, sz), color, opts)
end

-- A brick centred on (x, z) with its bottom at y.
function Core.centered(parent, cf, x, y, z, sx, sy, sz, color, opts)
	return Core.box(parent, cf, x - sx / 2, y, z - sz / 2, sx, sy, sz, color, opts)
end

-- A vertical cylinder standing on (x, y, z).
function Core.cyl(parent, cf, x, y, z, diameter, height, color, opts)
	local o = table.clone(opts or {})
	o.shape = Enum.PartType.Cylinder
	o.smooth = true
	return Core.part(
		parent,
		cf * CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(height, diameter, diameter),
		color,
		o
	)
end

-- A cylinder lying along the frame's X axis, centred at (x, y, z).
function Core.rod(parent, cf, x, y, z, length, diameter, color, opts)
	local o = table.clone(opts or {})
	o.shape = Enum.PartType.Cylinder
	o.smooth = true
	return Core.part(parent, cf * CFrame.new(x, y, z), Vector3.new(length, diameter, diameter), color, o)
end

function Core.ball(parent, cf, x, y, z, diameter, color, opts)
	local o = table.clone(opts or {})
	o.shape = Enum.PartType.Ball
	o.smooth = true
	return Core.part(parent, cf * CFrame.new(x, y, z), Vector3.one * diameter, color, o)
end

-- A classic 1x1 round plate with a stud: flower heads, coins, rivets.
function Core.roundPlate(parent, cf, x, y, z, color, diameter)
	diameter = diameter or 1
	local plate = Core.cyl(parent, cf, x, y, z, diameter, Core.PLATE, color)
	Core.cyl(parent, cf, x, y + Core.PLATE, z, diameter * 0.6, 0.2, color)
	return plate
end

function Core.light(parent, color, range, brightness, flicker)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 14
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = parent
	if flicker then
		CollectionService:AddTag(l, "Flicker")
	end
	return l
end

local TEXTURES = {
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
}

-- Particles from Roblox's built-in textures (no uploads needed). opts: texture, color, size, rate,
-- life, speed, spread, accel, rotSpeed, transparency, lightEmission
function Core.particles(parent, opts)
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEXTURES[opts.texture or "sparkle"]
	e.Color = ColorSequence.new(opts.color or Color3.new(1, 1, 1))
	e.Size = typeof(opts.size) == "NumberSequence" and opts.size or NumberSequence.new(opts.size or 0.5)
	e.Rate = opts.rate or 4
	e.Lifetime = NumberRange.new(opts.life and opts.life[1] or 2, opts.life and opts.life[2] or 4)
	e.Speed = NumberRange.new(opts.speed or 1)
	e.SpreadAngle = Vector2.new(opts.spread or 30, opts.spread or 30)
	e.Acceleration = opts.accel or Vector3.zero
	e.RotSpeed = NumberRange.new(-(opts.rotSpeed or 0), opts.rotSpeed or 0)
	e.Rotation = NumberRange.new(0, 360)
	e.Transparency = typeof(opts.transparency) == "NumberSequence" and opts.transparency
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, opts.transparency or 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
	e.LightEmission = opts.lightEmission or 0
	e.Parent = parent
	return e
end

-- One sloped brick in a face frame: spans x0..x1, outer (low) edge at z = zOuter, `run` deep toward +Z,
-- rising `rise` from y. (A WedgePart is tall at its +Z side and slopes down toward -Z.)
function Core.slope(parent, face, x0, x1, zOuter, y, run, rise, color, opts)
	local o = table.clone(opts or {})
	o.class = "WedgePart"
	if o.smooth == nil then
		o.smooth = true -- brick slopes are smooth on the slope
	end
	return Core.part(
		parent,
		face * CFrame.new((x0 + x1) / 2, y + rise / 2, zOuter + run / 2),
		Vector3.new(x1 - x0, rise, run),
		color,
		o
	)
end

-- A ring of slopes around a w x d footprint (outer edge), sitting on y: the building block of roofs,
-- cones and rounded canopies. Corners get a cap block `cornerH` tall (0 = leave open) in `cornerColor`.
function Core.skirt(parent, cf, w, d, y, run, rise, color, opts)
	opts = opts or {}
	for k = 0, 3 do
		local face = cf * CFrame.Angles(0, k * math.pi / 2, 0)
		local along = k % 2 == 0 and w or d
		local across = k % 2 == 0 and d or w
		if along - run * 2 > 0 then
			Core.slope(parent, face, -along / 2 + run, along / 2 - run, -across / 2, y, run, rise, color, opts)
		end
	end
	local cornerH = opts.cornerH or rise
	if cornerH > 0 then
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			Core.part(
				parent,
				cf * CFrame.new(c[1] * (w / 2 - run / 2), y + cornerH / 2, c[2] * (d / 2 - run / 2)),
				Vector3.new(run, cornerH, run),
				opts.cornerColor or color,
				{ smooth = opts.smooth, collide = opts.collide, shadow = opts.shadow }
			)
		end
	end
end

-- A flame standing straight up at the world position `pos`. Fire shoots along its part's up vector, so it
-- gets its own small upright anchor (never a rotated bowl or cylinder). Returns the anchor part.
function Core.fire(parent, pos, size, heat)
	local anchor = Instance.new("Part")
	anchor.Name = "Flame"
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.CFrame = CFrame.new(pos)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = parent
	local flame = Instance.new("Fire")
	flame.Size = size or 3
	flame.Heat = heat or 6
	flame.Color = Color3.fromRGB(255, 140, 40)
	flame.SecondaryColor = Color3.fromRGB(255, 220, 90)
	flame.Parent = anchor
	return anchor
end

-- Big chunky text on a part face (signs, plaques, banners).
function Core.label(part, text, face, color, stroke)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.9, 0.84)
	t.Position = UDim2.fromScale(0.05, 0.08)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.LuckiestGuy
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Parent = gui
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = stroke or Color3.fromRGB(40, 20, 16)
	s.Parent = t
	return t
end

return Core
