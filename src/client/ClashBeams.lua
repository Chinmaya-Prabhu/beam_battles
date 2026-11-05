-- One fighter's clash beam (client/Clash.lua draws two, one per side; client/BeamShrine.lua shows them off).
-- Built from Roblox Beams and particles so it reads as wild energy, not a tube:
--   * textured layers that scroll along the beam at their own speeds (shared/BeamSkins.lua `layers`,
--     textures from a Toolbox beam pack) over a white-hot core,
--   * paid skins add: two energy strands twisting round it, a flare and charge burst at the hands, and the
--     impact burst where the beams meet (Assets.BeamVFX.Impact: a Toolbox "Magma" VFX, scripts stripped,
--     recoloured to the skin): shockwave rings, flashes, an aura and a spray of sparks,
--   * styles: fire (more sparks, flickering width), lightning (jagged core, flicker), rainbow (colours cycle),
--     dark (black strands and smoke).
-- The default beam (no skin) is one plain layer and a core, so every skin is an obvious upgrade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeamSkins = require(ReplicatedStorage.Shared.BeamSkins)

local ClashBeams = {}
ClashBeams.__index = ClashBeams

local function fade(a, b, c)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, a),
		NumberSequenceKeypoint.new(0.5, b),
		NumberSequenceKeypoint.new(1, c),
	})
end

local function scaled(seq, k)
	local keys = {}
	for _, kp in seq.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
	end
	return NumberSequence.new(keys)
end

local function beam(rig, a0, a1, props)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.LightInfluence = 0
	b.LightEmission = 1
	b.Segments = 20
	b.Enabled = false
	for k, v in props do
		b[k] = v
	end
	b.Parent = rig
	return b
end

-- The Toolbox burst (Assets.BeamVFX.Impact) on `attachment`, sized by `k` and tinted to the skin.
local function burst(attachment, skin, k, only)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfx = assets and assets:FindFirstChild("BeamVFX")
	local template = vfx and vfx:FindFirstChild("Impact")
	local list = {}
	if not template then
		return list
	end
	for _, e in template:GetChildren() do
		if e:IsA("ParticleEmitter") and (not only or only[e.Name]) then
			local c = e:Clone()
			c.Size = scaled(e.Size, k)
			c.Speed = NumberRange.new(e.Speed.Min * k, e.Speed.Max * k)
			c.Acceleration = e.Acceleration * k
			c.LightInfluence = 0
			local smoke = string.find(e.Name, "smoke") ~= nil
			if smoke then
				c.Color = ColorSequence.new(
					skin.style == "dark" and Color3.new(0, 0, 0) or skin.glow:Lerp(Color3.new(0, 0, 0), 0.5)
				)
			else
				c.Color = ColorSequence.new(skin.core, skin.glow)
			end
			c.Enabled = false
			c.Parent = attachment
			table.insert(list, { emitter = c, rate = e.Rate, smoke = smoke })
		end
	end
	return list
end

-- `skin`: a BeamSkins entry (nil: the side colour `sideColor`, the plain default beam).
-- opts.noImpact: no burst at the far end (the Beam Shrine, where six beams meet in one orb).
function ClashBeams.new(sideColor, skin, opts)
	opts = opts or {}
	local self = setmetatable({}, ClashBeams)
	self.skin = skin or BeamSkins.side(sideColor)
	self.style = skin and skin.style
	self.fancy = skin ~= nil
	local s = self.skin
	local rig = Instance.new("Part")
	rig.Name = "ClashBeamRig"
	rig.Anchored, rig.CanCollide, rig.CanQuery, rig.CanTouch = true, false, false, false
	rig.Transparency = 1
	rig.Size = Vector3.one * 0.2
	rig.CFrame = CFrame.new()
	rig.Parent = workspace
	self.rig = rig
	local function att()
		local a = Instance.new("Attachment")
		a.Parent = rig
		return a
	end
	self.a0, self.a1 = att(), att()
	-- Textured layers.
	self.layers = {}
	for i, l in s.layers do
		local b = beam(rig, self.a0, self.a1, {
			Texture = l[1],
			TextureMode = Enum.TextureMode.Wrap,
			TextureLength = 6 + i * 2,
			TextureSpeed = l[3],
			Transparency = fade(l[4] + 0.15, l[4], l[4] + 0.1),
			ZOffset = i * 0.1,
		})
		table.insert(self.layers, { beam = b, width = l[2], color = l[5] })
	end
	self.core = beam(rig, self.a0, self.a1, {
		Color = ColorSequence.new(s.core),
		Transparency = fade(0.1, 0.05, 0.1),
		ZOffset = 1,
	})
	-- Paid skins: strands, hand flare and charge, impact burst.
	self.strands = {}
	if self.fancy then
		self.s = { { att(), att() }, { att(), att() } }
		for i = 1, 2 do
			self.strands[i] = beam(rig, self.s[i][1], self.s[i][2], {
				Texture = BeamSkins.Textures.ENERGY,
				TextureMode = Enum.TextureMode.Wrap,
				TextureLength = 5,
				TextureSpeed = 3,
				Color = ColorSequence.new(s.strand),
				Transparency = fade(0.3, 0.05, 0.25),
				LightEmission = self.style == "dark" and 0 or 1,
				ZOffset = 1.2,
			})
		end
		self.impact = opts.noImpact and {} or burst(self.a1, s, self.style == "fire" and 0.24 or 0.2)
		self.charge = burst(self.a0, s, 0.09, { aura = true, Flash52 = true, Flash53 = true, lavadrop = true })
	else
		-- The default: a small spray where it hits, nothing at the hands.
		self.impact = burst(self.a1, s, 0.12, { aura = true, lavadrop = true })
		self.charge = {}
	end
	local flare = Instance.new("Part")
	flare.Name = "ClashBeamFlare"
	flare.Shape = Enum.PartType.Ball
	flare.Material = Enum.Material.Neon
	flare.Anchored, flare.CanCollide, flare.CanQuery, flare.CanTouch = true, false, false, false
	flare.CastShadow = false
	flare.Color = s.core
	flare.Transparency = 1
	flare.Parent = workspace
	self.flare = flare
	return self
end

local function setEmitters(list, on, boost)
	for _, e in list do
		e.emitter.Enabled = on
		e.emitter.Rate = e.rate * (boost or 1)
	end
end

-- Draws the beam from `from` to `to` (world positions), `width` studs across; `boost` 0..1 (overdrive)
-- whitens it and pumps the VFX; `t` is the clock for the twist and flicker.
function ClashBeams:update(from, to, width, firing, t, boost)
	local on = (firing and from and to) and true or false
	for _, l in self.layers do
		l.beam.Enabled = on
	end
	self.core.Enabled = on
	for _, b in self.strands do
		b.Enabled = on
	end
	boost = boost or 0
	setEmitters(self.impact, on, 1 + boost * 2)
	setEmitters(self.charge, on, 1 + boost)
	self.flare.Transparency = (on and self.fancy) and 0.25 or 1
	if not on then
		return
	end
	local s = self.skin
	local glow, strand = s.glow, s.strand
	if self.style == "rainbow" then
		glow = Color3.fromHSV(t * 0.35 % 1, 0.85, 1)
		strand = Color3.fromHSV((t * 0.35 + 0.5) % 1, 0.7, 1)
		local seq = ColorSequence.new(glow, strand)
		for _, e in self.impact do
			if not e.smoke then
				e.emitter.Color = seq
			end
		end
	end
	glow = glow:Lerp(Color3.new(1, 1, 1), boost * 0.5)
	local colors = { glow = glow, strand = strand, core = s.core }
	self.a0.Position, self.a1.Position = from, to
	local flicker = 1
	if self.style == "fire" then
		flicker = 1 + math.noise(t * 7, 0.3) * 0.25
	elseif self.style == "lightning" then
		flicker = 1 + math.noise(t * 30, 0.7) * 0.4
	end
	for i, l in self.layers do
		local w = width * l.width * flicker * (1 + math.sin(t * 9 + i) * 0.06)
		l.beam.Width0, l.beam.Width1 = w * 0.9, w
		l.beam.Color = ColorSequence.new(colors[l.color] or glow)
	end
	self.core.Width0, self.core.Width1 = width * 0.45, width * 0.5
	if self.style == "lightning" and t - (self.lastBolt or 0) > 0.05 then
		self.lastBolt = t
		local len = (to - from).Magnitude
		self.core.CurveSize0 = (math.random() - 0.5) * len * 0.3
		self.core.CurveSize1 = (math.random() - 0.5) * len * 0.3
	end
	if self.fancy then
		local dir = to - from
		local len = dir.Magnitude
		dir = len > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
		local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
		local right = dir:Cross(up).Unit
		local normal = right:Cross(dir).Unit
		local amp = math.clamp(len * 0.14, 1.2, 6)
		for i, pair in self.s do
			local a = t * 8 + (i - 1) * math.pi
			local axis = right * math.cos(a) + normal * math.sin(a)
			pair[1].CFrame = CFrame.fromMatrix(from, axis, dir)
			pair[2].CFrame = CFrame.fromMatrix(to, axis, dir)
			local b = self.strands[i]
			b.CurveSize0, b.CurveSize1 = amp, -amp
			b.Width0, b.Width1 = width * 0.45, width * 0.3
			b.Color = ColorSequence.new(strand)
		end
		local pulse = 1 + math.sin(t * 22) * 0.15
		self.flare.Size = Vector3.one * width * 1.5 * pulse
		self.flare.Position = from
		self.flare.Color = s.core:Lerp(glow, 0.3)
	end
end

function ClashBeams:destroy()
	self.rig:Destroy()
	self.flare:Destroy()
end

return ClashBeams
