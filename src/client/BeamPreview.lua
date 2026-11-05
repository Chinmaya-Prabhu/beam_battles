-- A moving 3D beam for the shop's BEAMS cards. ViewportFrames can't draw Beams or particles, so this mirrors
-- client/ClashBeams.lua with parts: each textured layer (shared/BeamSkins.lua `layers`) is a flat quad facing
-- the camera with the same Toolbox beam texture scrolling along it, over a white-hot core, with two
-- strands spiralling round it, a pulsing flare at the hands and an impact with shockwave rings and shards.
-- BeamPreview.new(parentFrame, skin) -> object; object:step(t) every frame while shown.
local BeamPreview = {}
BeamPreview.__index = BeamPreview

local LENGTH = 10
local BEADS = 16
local CAMERA = Vector3.new(0, 1.6, 9)

local function part(parent, shape, color, transparency, neon)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = transparency or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function BeamPreview.new(parent, skin)
	local self = setmetatable({}, BeamPreview)
	self.skin = skin
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.new(1, 1, 1)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(0, 0, -1)
	vp.Parent = parent
	-- Fade the top and bottom, so the texture quads' edges never show as boxes.
	local edge = Instance.new("UIGradient")
	edge.Rotation = 90
	edge.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	edge.Parent = vp
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local block, cyl, ball = Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Ball
	-- Textured layers: invisible quads carrying a scrolling Texture on the face toward the camera.
	self.layers = {}
	for i, l in skin.layers do
		local q = part(world, block, Color3.new(1, 1, 1), 1)
		local tex = Instance.new("Texture")
		tex.Texture = l[1]
		tex.Face = Enum.NormalId.Front
		tex.Transparency = math.min(0.8, l[4] + 0.2)
		tex.ZIndex = i
		tex.Parent = q
		table.insert(self.layers, { part = q, tex = tex, width = l[2], speed = l[3], color = l[5] })
	end
	self.core = part(world, cyl, skin.core, 0, true)
	self.beads = { {}, {} }
	for s = 1, 2 do
		for i = 1, BEADS do
			self.beads[s][i] = part(world, ball, skin.strand, 0.05, skin.style ~= "dark")
		end
	end
	self.flare = part(world, ball, skin.core, 0, true)
	self.flareGlow = part(world, ball, skin.glow, 0.55)
	self.hit = part(world, ball, skin.core, 0, true)
	self.rings = {}
	for i = 1, 2 do
		self.rings[i] = part(world, cyl, skin.glow, 0.3, true)
	end
	self.shards = {}
	for i = 1, 10 do
		self.shards[i] = part(world, block, skin.strand, 0.2, true)
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(CAMERA, Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return self
end

local function place(p, a, b, width)
	local len = (b - a).Magnitude
	p.Size = Vector3.new(math.max(len, 0.05), width, width)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
end

function BeamPreview:step(t)
	local skin = self.skin
	local glow, strand = skin.glow, skin.strand
	if skin.style == "rainbow" then
		glow = Color3.fromHSV(t * 0.35 % 1, 0.85, 1)
		strand = Color3.fromHSV((t * 0.35 + 0.5) % 1, 0.7, 1)
	end
	local colors = { glow = glow, strand = strand, core = skin.core }
	local from, to = Vector3.new(-LENGTH / 2, -0.15, 0), Vector3.new(LENGTH / 2, 0.15, 0)
	local dir = (to - from).Unit
	local len = (to - from).Magnitude
	local center = (from + to) / 2
	local back = (CAMERA - center)
	back = (back - dir * back:Dot(dir)).Unit
	local up = (-back):Cross(dir)
	local flicker = 1
	if skin.style == "fire" then
		flicker = 1 + math.noise(t * 7, 0.3) * 0.25
	elseif skin.style == "lightning" then
		flicker = 1 + math.noise(t * 30, 0.7) * 0.35
	end
	-- Layers: quads facing the camera, textures scrolling along the beam.
	for i, l in self.layers do
		local w = 0.8 * l.width * flicker * (1 + math.sin(t * 9 + i) * 0.06)
		l.part.Size = Vector3.new(len, w, 0.05)
		l.part.CFrame = CFrame.fromMatrix(center + back * (i * 0.02), dir, up)
		l.tex.StudsPerTileU = len * 0.5
		l.tex.StudsPerTileV = w
		l.tex.OffsetStudsU = (-t * l.speed * 3) % (len * 0.5)
		l.tex.Color3 = colors[l.color] or glow
	end
	self.core.Color = skin.core:Lerp(glow, 0.25)
	place(self.core, from, to, 0.3 * flicker)
	-- Two helix strands scrolling toward the target.
	for s = 1, 2 do
		for i, bead in self.beads[s] do
			local u = ((i - 1) / BEADS + t * 0.5) % 1
			local a = u * math.pi * 5 + t * 5 + (s - 1) * math.pi
			local r = 1 + math.sin(u * math.pi) * 0.3
			bead.Position = from + dir * len * u + up * math.cos(a) * r + back * math.sin(a) * r
			bead.Size = Vector3.one * (0.24 + math.sin(u * math.pi) * 0.16)
			bead.Color = strand
		end
	end
	-- The flare at the hands.
	local pulse = 1 + math.sin(t * 16) * 0.12
	self.flare.Position = from
	self.flare.Size = Vector3.one * 1.3 * pulse
	self.flareGlow.Position = from
	self.flareGlow.Size = Vector3.one * 2.4 * pulse * flicker
	self.flareGlow.Color = glow
	-- The impact: a bright ball, two shockwave rings expanding and fading, shards flying out.
	self.hit.Position = to
	self.hit.Size = Vector3.one * (1.5 + math.sin(t * 12) * 0.2)
	self.hit.Color = skin.core:Lerp(glow, 0.35)
	for i, ring in self.rings do
		local k = (t * 1.4 + (i - 1) * 0.5) % 1
		ring.Size = Vector3.new(0.08, 1 + k * 3.5, 1 + k * 3.5)
		ring.CFrame = CFrame.new(to) * CFrame.fromMatrix(Vector3.zero, dir, up)
		ring.Transparency = 0.15 + k * 0.85
		ring.Color = i == 1 and glow or strand
	end
	for i, shard in self.shards do
		local a = i / #self.shards * math.pi * 2 + t * 0.6
		local k = (t * 1.9 + i * 0.31) % 1
		local out = (up * math.cos(a) + back * math.sin(a) * 0.4 + dir * 0.5).Unit
		local p = to + out * (0.5 + k * 2.4)
		shard.Size = skin.style == "fire" and Vector3.new(0.16, 0.6, 0.16) or Vector3.new(0.14, 0.45, 0.14)
		shard.CFrame = CFrame.lookAt(p, p + out) * CFrame.Angles(math.rad(90), 0, 0)
		shard.Transparency = 0.1 + k * 0.9
		shard.Color = i % 2 == 0 and strand or glow
	end
end

return BeamPreview
