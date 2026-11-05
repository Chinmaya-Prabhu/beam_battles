-- Visible progression for every player (docs/TRAINING_PLAN.md §5), all built on this client from player
-- attributes the server keeps (Power, Gear, Rebirths, Training):
--   * the aura: flame, sparks, light and (higher tiers) arcs, a dust ring and floating rocks, flaring up
--     while the player trains,
--   * the training weights on both wrists and ankles (shared/GearLook.lua), rebuilt when the gear tier or
--     the body's size changes,
--   * the overhead plate: Power Level, rank title and rebirth stars,
--   * FX "PowerUp": a shockwave, a light pillar and (for this player) a flash and a shake; "GearUp" sparkles.
-- Body growth itself is server-side (Humanoid scale values).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Training = require(Shared.Training)
local GearLook = require(Shared.GearLook)
local FighterAura = require(Shared.FighterAura)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local Aura = {}
local TrainPose -- set by start(): tells the pose module about power-ups
local tracked = {} -- [player] = { character, tier, gear, aura = {...}, gearModel, plate, rocks }

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local LIMBS = {
	{ "RightLowerArm", "Right Arm" },
	{ "LeftLowerArm", "Left Arm" },
	{ "RightLowerLeg", "Right Leg" },
	{ "LeftLowerLeg", "Left Leg" },
}

local function rainbow()
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 * 0.85, 0.8, 1)))
	end
	return ColorSequence.new(keys)
end

local function seq(color, info)
	if info and info.rainbow then
		return rainbow()
	end
	return ColorSequence.new(color)
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LockedToPart = false
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

-- ------------------------------------------------------------------ aura

local function clearAura(t)
	for _, inst in t.aura or {} do
		inst:Destroy()
	end
	t.aura = {}
	for _, rock in t.rocks or {} do
		rock:Destroy()
	end
	t.rocks = {}
end

-- ------------------------------------------------------------------ Toolbox aura VFX
-- ReplicatedStorage.Assets.AuraVFX.SuperSaiyan: attachments (positioned on a HumanoidRootPart) holding the
-- pack's emitters, taken from a free Toolbox aura pack with its scripts removed. Each tier switches on
-- more of them, recoloured to the tier and scaled up (AURA_TIERS); the tier's colours replace the pack's.
-- The pack's swirl, wind and dust only (its tall pillar and spike columns are gone: the aura wraps the
-- body now, shared/FighterAura.lua's anime blaze), joining in from Elite up.
local AURA_TIERS = {
	{ scale = 0.6, rate = 0.3, on = {} },
	{ scale = 0.7, rate = 0.4, on = {} },
	{ scale = 0.8, rate = 0.5, on = {} },
	{ scale = 0.9, rate = 0.7, on = { RoughSwishThing = true, SmokeParticle = true } },
	{ scale = 1, rate = 0.9, on = { RoughSwishThing = true, SmokeParticle = true, Wind1 = true } },
	{ scale = 1.15, rate = 1.1, on = { RoughSwishThing = true, SmokeParticle = true, Wind1 = true, Wind2 = true } },
	{ scale = 1.3, rate = 1.3, on = { RoughSwishThing = true, SmokeParticle = true, Wind1 = true, Wind2 = true } },
}
-- The blaze round the body per tier (FighterAura layers), its size and how thick: each tier adds a layer
-- and grows, from a soft glow (Trainee) to a full Super Saiyan blaze with lightning (Super) to a storm of
-- flame, lightning, energy and dark power (God).
local BLAZE = {
	-- (Each tier is clearly bigger and richer than the last: the first two used to look almost the same.)
	{ k = 0.7, n = 0.7, layers = { "blaze", "sparkles" } },
	{ k = 1.05, n = 1.1, layers = { "blaze", "spikes", "bolts", "sparkles" } },
	{ k = 1.3, n = 1.2, layers = { "blaze", "spikes", "bolts", "halo" } },
	{ k = 1.5, n = 1.3, layers = { "blaze", "spikes", "bolts", "wisps", "halo" } },
	{ k = 1.7, n = 1.4, layers = { "blaze", "spikes", "bolts", "wisps", "halo", "sparkles" } },
	{ k = 1.95, n = 1.5, layers = { "blaze", "spikes", "bolts", "wisps", "fire", "halo", "sparkles" } },
	{ k = 2.25, n = 1.7, layers = { "blaze", "spikes", "bolts", "wisps", "fire", "cloud", "halo", "sparkles" } },
}
-- Emitters drawn in the accent (white-hot) colour rather than the main one.
local ACCENT = { SPECKS = true, Linesbrr = true, Wind1 = true, Wind2 = true, LongSlash = true }

local function auraTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfx = assets and assets:FindFirstChild("AuraVFX")
	return vfx and vfx:FindFirstChild("SuperSaiyan")
end

local function scaled(sequence, k)
	local keys = {}
	for _, kp in sequence.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
	end
	return NumberSequence.new(keys)
end

-- Clones the pack's attachments onto `root`, keeping the emitters the tier uses. Returns the attachments.
local function packAura(root, tier, info, color, accent)
	local template = auraTemplate()
	if not template then
		return nil
	end
	local spec = AURA_TIERS[math.clamp(tier, 1, #AURA_TIERS)]
	local out = {}
	for _, a in template:GetChildren() do
		local clone = a:Clone()
		local kept = 0
		for _, e in clone:GetDescendants() do
			if e:IsA("ParticleEmitter") then
				local on = (spec.all and not (spec.skip and spec.skip[e.Name])) or (spec.on and spec.on[e.Name])
				if not on then
					e:Destroy()
				else
					kept += 1
					e.Size = scaled(e.Size, spec.scale)
					e.Rate = e.Rate * spec.rate
					if e.Name == "SmokeParticle" then
						e.Color = ColorSequence.new(Color3.fromRGB(200, 190, 175)) -- dust stays dust
					elseif info.rainbow then
						e.Color = rainbow()
					else
						local c = ACCENT[e.Name] and accent or color
						e.Color = ColorSequence.new(c, c:Lerp(Color3.new(1, 1, 1), 0.35))
					end
				end
			end
		end
		if kept > 0 then
			clone.Parent = root
			table.insert(out, clone)
		else
			clone:Destroy()
		end
	end
	return out
end

local buildClassicAura -- the hand-made aura, for places without the pack

local function buildAura(t, tier)
	clearAura(t)
	local character = t.character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or tier <= 0 then
		return
	end
	local info = Training.Auras[tier]
	local blaze = BLAZE[math.clamp(tier, 1, #BLAZE)]
	local main = info.rainbow and "rainbow" or info.color
	for _, e in FighterAura.build(root, blaze.k, blaze.layers, main, info.accent, blaze.n) do
		table.insert(t.aura, e)
	end
	for _, a in packAura(root, tier, info, info.color, info.accent) or {} do
		table.insert(t.aura, a)
	end
	-- Lightning arcs from Elite up (the pack has none).
	if tier >= 4 then
		table.insert(
			t.aura,
			emitter(root, {
				Name = "AuraArcs",
				Texture = SPARK,
				Color = seq(info.accent, info),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
				Squash = NumberSequence.new(-2),
				Lifetime = NumberRange.new(0.08, 0.16),
				Speed = NumberRange.new(14, 22),
				SpreadAngle = Vector2.new(180, 180),
				Rate = 10 + tier * 3,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
			})
		)
	end
	if tier >= 6 then
		for k = 1, 5 do
			local rock = Instance.new("Part")
			rock.Size = Vector3.new(0.6, 0.5, 0.7) * (0.8 + (k % 3) * 0.3)
			rock.Color = Color3.fromRGB(110, 106, 100)
			rock.Material = Enum.Material.Slate
			rock.Anchored = true
			rock.CanCollide = false
			rock.CanQuery = false
			rock.CanTouch = false
			rock.CastShadow = false
			rock.Parent = workspace
			table.insert(t.rocks, rock)
		end
	end
	local glow = Instance.new("Highlight")
	glow.Name = "AuraGlow"
	glow.Adornee = character
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.OutlineColor = info.rainbow and Color3.fromHSV(0, 0.7, 1) or info.color
	glow.OutlineTransparency = math.max(0.4 - tier * 0.1, 0)
	glow.FillColor = info.color
	glow.FillTransparency = 1 - math.min(0.04 + tier * 0.025, 0.2)
	glow.Parent = character
	table.insert(t.aura, glow)
	t.glow = glow
	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = info.color
	light.Range = 8 + tier * 1.5
	light.Brightness = 0.6 + tier * 0.15
	light.Shadows = false
	light.Parent = root
	table.insert(t.aura, light)
	t.baseRates = {}
	for _, inst in t.aura do
		for _, e in { inst, table.unpack(inst:GetDescendants()) } do
			if e:IsA("ParticleEmitter") then
				t.baseRates[e] = e.Rate
			end
		end
	end
end

function buildClassicAura(t, tier)
	clearAura(t)
	local character = t.character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or tier <= 0 then
		return
	end
	local info = Training.Auras[tier]
	local size = 1.2 + tier * 0.3
	-- An invisible shell the size of the body: flames and sparks rise from all of it, not just the hips.
	local shell = Instance.new("Part")
	shell.Name = "AuraShell"
	shell.Size = Vector3.new(3.6, 5.6, 2.2)
	shell.Transparency = 1
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Massless = true
	shell.CFrame = root.CFrame * CFrame.new(0, -0.4, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = shell
	weld.Parent = shell
	shell.Parent = character
	table.insert(t.aura, shell)
	root = shell
	-- Flame rising round the body.
	table.insert(
		t.aura,
		emitter(root, {
			Name = "AuraFlame",
			Texture = FIRE,
			Color = seq(info.color, info),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 1.4), NumberSequenceKeypoint.new(1, 0.2) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.6, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			LightEmission = 0.7,
			Brightness = 1.5 + tier * 0.4,
			Lifetime = NumberRange.new(0.45, 0.8),
			Speed = NumberRange.new(3, 6),
			Acceleration = Vector3.new(0, 12, 0),
			SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Top,
			Rate = 28 + tier * 10,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			LightInfluence = 0,
		})
	)
	-- Sparks.
	if tier >= 2 then
		table.insert(
			t.aura,
			emitter(root, {
				Name = "AuraSparks",
				Texture = SPARK,
				Color = seq(info.accent, info),
				Size = NumberSequence.new(0.35),
				Lifetime = NumberRange.new(0.4, 0.9),
				Speed = NumberRange.new(4, 9),
				SpreadAngle = Vector2.new(60, 60),
				EmissionDirection = Enum.NormalId.Top,
				Rate = 4 + tier * 3,
			})
		)
	end
	-- Lightning arcs: fast, short-lived streaks.
	if tier >= 4 then
		table.insert(
			t.aura,
			emitter(root, {
				Name = "AuraArcs",
				Texture = SPARK,
				Color = seq(info.accent, info),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
				Squash = NumberSequence.new(-2),
				Lifetime = NumberRange.new(0.08, 0.16),
				Speed = NumberRange.new(14, 22),
				SpreadAngle = Vector2.new(180, 180),
				Rate = 18,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
			})
		)
	end
	-- Dust ring at the feet.
	if tier >= 5 then
		local feet = Instance.new("Attachment")
		feet.Name = "AuraFeet"
		feet.Position = Vector3.new(0, -root.Size.Y / 2 + 0.2, 0) -- the shell's bottom is at the feet
		feet.Parent = root
		table.insert(t.aura, feet)
		emitter(feet, {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(200, 190, 175)),
			LightEmission = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.8, 1.2),
			Speed = NumberRange.new(6, 9),
			SpreadAngle = Vector2.new(0, 180),
			EmissionDirection = Enum.NormalId.Right,
			Rate = 14,
		})
	end
	-- Floating rocks orbiting at the top tiers.
	if tier >= 6 then
		for k = 1, 5 do
			local rock = Instance.new("Part")
			rock.Size = Vector3.new(0.6, 0.5, 0.7) * (0.8 + (k % 3) * 0.3)
			rock.Color = Color3.fromRGB(110, 106, 100)
			rock.Material = Enum.Material.Slate
			rock.Anchored = true
			rock.CanCollide = false
			rock.CanQuery = false
			rock.CanTouch = false
			rock.CastShadow = false
			rock.Parent = workspace
			table.insert(t.rocks, rock)
		end
	end
	-- A glowing outline in the aura colour: the part of the aura that reads in bright daylight.
	local glow = Instance.new("Highlight")
	glow.Name = "AuraGlow"
	glow.Adornee = character
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.OutlineColor = info.rainbow and Color3.fromHSV(0, 0.7, 1) or info.color
	glow.OutlineTransparency = math.max(0.4 - tier * 0.1, 0)
	glow.FillColor = info.color
	glow.FillTransparency = 1 - math.min(0.06 + tier * 0.03, 0.25)
	glow.Parent = character
	table.insert(t.aura, glow)
	t.glow = glow
	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = info.color
	light.Range = 8 + tier * 1.5
	light.Brightness = 0.6 + tier * 0.15
	light.Shadows = false
	light.Parent = root
	table.insert(t.aura, light)
	t.baseRates = {}
	for _, inst in t.aura do
		if inst:IsA("ParticleEmitter") then
			t.baseRates[inst] = inst.Rate
		end
	end
end

-- ------------------------------------------------------------------ gear

local function limb(character, names)
	for _, name in names do
		local p = character:FindFirstChild(name)
		if p then
			return p, name
		end
	end
end

-- The weights' own aura, growing with the tier: a shimmer from Steel, sparks from Gold, the pack's flame
-- from Diamond, and the full flame, glow and specks on the rebirth and premium weights. In the look's trim
-- colour, so each weight burns in its own colour.
local function gearAura(band, tier, width)
	local look = Training.gear(tier).look
	local spec = GearLook.Looks[look]
	local core = band.PrimaryPart
	if not spec or not core or tier < 5 then
		return
	end
	local color = spec.trim
	local k = width / 1.2 -- the pack is sized for a body; a band is a fraction of that
	emitter(core, {
		Name = "GearShimmer",
		Texture = SPARK,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new(0.15 * k + tier * 0.02),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 2 + tier,
	})
	local template = auraTemplate()
	if not template or tier < 9 then
		return
	end
	local names = tier >= 11 and { FLAMEPILLAR = true, GLOW = true, SPECKS = true } or { FLAMEPILLAR = true }
	for _, a in template:GetChildren() do
		for _, e in a:GetDescendants() do
			if e:IsA("ParticleEmitter") and names[e.Name] then
				local c = e:Clone()
				c.Size = scaled(c.Size, (tier >= 11 and 0.32 or 0.22) * k)
				c.Speed = NumberRange.new(c.Speed.Min * 0.25, c.Speed.Max * 0.25)
				c.Acceleration = c.Acceleration * 0.25
				c.Rate = c.Rate * (tier >= 11 and 0.4 or 0.25)
				c.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.4))
				c.Parent = core
			end
		end
	end
end

local function buildGear(t, tier)
	if t.gearModel then
		t.gearModel:Destroy()
		t.gearModel = nil
	end
	local character = t.character
	if not character then
		return
	end
	local look = Training.gear(tier).look
	local folder = Instance.new("Folder")
	folder.Name = "TrainingGear"
	for _, names in LIMBS do
		local part, name = limb(character, names)
		if part then
			local r6 = name == names[2]
			local width = math.max(part.Size.X, part.Size.Z)
			local band = GearLook.band(look, width * 1.22, part.Size.Y * (r6 and 0.18 or 0.32))
			-- Near the hand or foot end of the limb.
			local along = -part.Size.Y * (r6 and 0.36 or 0.28)
			-- GearLook bands lie with their axis on the pivot's Y after this turn: round the limb, like a cuff.
			band:PivotTo(part.CFrame * CFrame.new(0, along, 0) * CFrame.Angles(0, 0, math.pi / 2))
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = band.PrimaryPart
			weld.Parent = band.PrimaryPart
			gearAura(band, tier, width)
			band.Parent = folder
		end
	end
	folder.Parent = character
	t.gearModel = folder
	t.gearSize = character:FindFirstChild("RightLowerArm") and character.RightLowerArm.Size
end

-- ------------------------------------------------------------------ plate

local function buildPlate(t, player)
	if t.plate then
		t.plate:Destroy()
	end
	local head = t.character and t.character:FindFirstChild("Head")
	-- Your own Power and rank are on the HUD; the plate is for reading other players.
	if not head or player == Players.LocalPlayer then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PowerPlate"
	gui.Size = UDim2.fromOffset(200, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 50
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = head
	local function label(props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		for k, v in props do
			l[k] = v
		end
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = Color3.fromRGB(30, 16, 40)
		s.Parent = l
		l.Parent = gui
		return l
	end
	t.plateTitle = label({ Size = UDim2.fromScale(1, 0.38), TextColor3 = Color3.new(1, 1, 1) })
	t.platePower = label({
		Position = UDim2.fromScale(0, 0.38),
		Size = UDim2.fromScale(1, 0.62),
		TextColor3 = Color3.fromRGB(255, 214, 80),
	})
	gui.Parent = head
	t.plate = gui
	t.platePlayer = player
end

local function refreshPlate(t, player)
	if not t.plate then
		return
	end
	local power = player:GetAttribute("Power") or 0
	local tier, info = Training.aura(power)
	-- Rebirths as "R3" (the game font has no star glyph).
	local done = player:GetAttribute("Rebirths") or 0
	local stars = done > 0 and ("R" .. done) or ""
	local vip = player:GetAttribute("VIP") and '<font color="#FFD24A">VIP</font> · ' or ""
	t.plateTitle.RichText = true
	t.plateTitle.Text = vip .. (stars ~= "" and (stars .. " ") or "") .. string.upper(Training.title(power))
	t.plateTitle.TextColor3 = tier > 0 and info.color or Color3.fromRGB(220, 220, 230)
	t.platePower.Text = Format.short(power) .. " POWER"
end

-- ------------------------------------------------------------------ tracking

local function refresh(player)
	local t = tracked[player]
	if not t or not t.character then
		return
	end
	local power = player:GetAttribute("Power") or 0
	local tier = Training.aura(power)
	if tier ~= t.tier then
		t.tier = tier
		buildAura(t, tier)
	end
	local gear = Training.bestGear(player:GetAttribute("Gear"), player:GetAttribute("PremiumGear"))
	if gear ~= t.gear then
		t.gear = gear
		buildGear(t, gear)
	end
	refreshPlate(t, player)
end

local function onCharacter(player, character)
	local t = tracked[player]
	if t.gearModel then
		t.gearModel:Destroy()
		t.gearModel = nil
	end
	clearAura(t)
	t.character = character
	t.tier, t.gear = nil, nil
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Head", 10)
	task.wait(0.6) -- body scale and limbs settle
	if t.character ~= character then
		return
	end
	buildPlate(t, player)
	refresh(player)
end

local function track(player)
	tracked[player] = { aura = {}, rocks = {} }
	for _, name in { "Power", "Gear", "PremiumGear", "Rebirths", "VIP" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refresh(player)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

-- ------------------------------------------------------------------ moments

local function neon(size, cf, color, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end

local function tween(inst, time, props)
	TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function powerUp(data)
	local player = Players:GetPlayerByUserId(data.userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local info = Training.Auras[data.tier] or Training.Auras[1]
	local feet = root.Position - Vector3.new(0, 3, 0)
	-- Shockwave ring along the ground.
	local ring = neon(
		Vector3.new(0.4, 4, 4),
		CFrame.new(feet) * CFrame.Angles(0, 0, math.pi / 2),
		info.color,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0.2
	tween(ring, 0.6, { Size = Vector3.new(0.2, 40, 40), Transparency = 1 })
	Debris:AddItem(ring, 0.7)
	-- Pillar of light.
	local pillar = neon(
		Vector3.new(60, 6, 6),
		CFrame.new(feet + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		info.color,
		Enum.PartType.Cylinder
	)
	pillar.Transparency = 0.3
	tween(pillar, 0.9, { Size = Vector3.new(60, 0.5, 0.5), Transparency = 1 })
	Debris:AddItem(pillar, 1)
	local burst = Instance.new("Attachment")
	burst.Parent = root
	local e = emitter(burst, {
		Texture = SPARK,
		Color = seq(info.accent, info),
		Size = NumberSequence.new(0.6),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(20, 34),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
	})
	e:Emit(60)
	Debris:AddItem(burst, 1.2)
	if TrainPose then
		TrainPose.burst(player, 1.4)
	end
	if player == Players.LocalPlayer then
		local gui = player:FindFirstChild("PlayerGui")
		if gui then
			local screen = Instance.new("ScreenGui")
			screen.IgnoreGuiInset = true
			local flash = Instance.new("Frame")
			flash.Size = UDim2.fromScale(1, 1)
			flash.BackgroundColor3 = info.color
			flash.BackgroundTransparency = 0.2
			flash.Parent = screen
			screen.Parent = gui
			tween(flash, 0.6, { BackgroundTransparency = 1 })
			Debris:AddItem(screen, 0.7)
		end
		local camera = workspace.CurrentCamera
		local stop = os.clock() + 0.5
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local left = stop - os.clock()
			if left <= 0 then
				conn:Disconnect()
				return
			end
			camera.CFrame *= CFrame.new(math.noise(os.clock() * 40, 1) * left, math.noise(os.clock() * 40, 2) * left, 0)
		end)
	end
end

local function gearUp(data)
	local player = Players:GetPlayerByUserId(data.userId)
	local t = player and tracked[player]
	if not t or not t.gearModel then
		return
	end
	local g = Training.gear(data.tier)
	local color = (GearLook.Looks[g.look] or GearLook.Looks.cloth).trim
	for _, band in t.gearModel:GetChildren() do
		if band.PrimaryPart then
			local e = emitter(band.PrimaryPart, {
				Texture = SPARK,
				Color = ColorSequence.new(color),
				Size = NumberSequence.new(0.4),
				Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(6, 10),
				SpreadAngle = Vector2.new(180, 180),
				Rate = 0,
			})
			e:Emit(16)
		end
	end
end

-- Phones: a screen full of aura hides the thumbstick's world, the guide beam and the fighters, so every aura
-- there is thinner (fewer particles; the look and colours stay).
local PHONE_AURA = 0.3

function Aura.start(trainPose)
	TrainPose = trainPose
	if UIKit.compact() then
		local function soften(e)
			if e:IsA("ParticleEmitter") and e.Name == "Aura" and not e:GetAttribute("Softened") then
				e:SetAttribute("Softened", true)
				e.Rate *= PHONE_AURA
			end
		end
		workspace.DescendantAdded:Connect(soften)
		task.spawn(function()
			for _, d in workspace:GetDescendants() do
				soften(d)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		local t = tracked[player]
		if t then
			clearAura(t)
		end
		tracked[player] = nil
	end)
	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind == "PowerUp" then
			powerUp(data)
		elseif kind == "Rebirth" then
			-- The rebirth moment: the top-tier burst (rainbow) on the reborn player.
			powerUp({ userId = data.userId, tier = #Training.Auras })
		elseif kind == "GearUp" then
			gearUp(data)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for player, t in tracked do
			local character = t.character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end
			-- Flare while training.
			local training = player:GetAttribute("Training") ~= nil
			for e, rate in t.baseRates or {} do
				e.Rate = (training and rate * 2.2 or rate) * (UIKit.compact() and PHONE_AURA or 1)
			end
			if t.glow and t.glow.Parent then
				local tier = t.tier or 0
				local base = math.max(0.4 - tier * 0.1, 0)
				t.glow.OutlineTransparency = training and base * (0.5 + 0.3 * math.sin(now * 12)) or base
				if Training.Auras[tier] and Training.Auras[tier].rainbow then
					t.glow.OutlineColor = Color3.fromHSV(now * 0.25 % 1, 0.7, 1)
				end
			end
			-- Rebuild the weights when the body grows.
			local arm = character:FindFirstChild("RightLowerArm")
			if arm and t.gearSize and (arm.Size - t.gearSize).Magnitude > 0.05 then
				buildGear(t, t.gear or 1)
			end
			-- Gravity rings orbit; floating rocks circle.
			if t.gearModel then
				for _, hub in t.gearModel:GetDescendants() do
					if hub.Name == "Orbit" and hub:IsA("Weld") then
						hub.C0 *= CFrame.Angles(dt * 4, 0, 0)
					end
				end
			end
			for k, rock in t.rocks do
				local a = now * 0.9 + k / #t.rocks * math.pi * 2
				rock.CFrame = CFrame.new(
					root.Position
						+ Vector3.new(math.cos(a) * 4.5, math.sin(now * 1.7 + k) * 0.8 - 0.5, math.sin(a) * 4.5)
				) * CFrame.Angles(now + k, now * 0.7, 0)
			end
		end
	end)
end

return Aura
