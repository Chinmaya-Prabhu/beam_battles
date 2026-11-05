-- The training weights' looks (docs/TRAINING_PLAN.md §4), built from parts so both sides can use them:
-- the client straps them to every player's wrists and ankles, the server stands them on shop displays.
-- GearLook.band(look, diameter, length) returns a Model whose PrimaryPart "Band" is centred on the origin
-- with the band's axis along Y (wrap it round a limb that points up or down). Parts are unanchored and
-- welded to the Band; the caller anchors or welds the Band itself.
local GearLook = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Base colour, material, reflectance and the trim colour per look.
local LOOKS = {
	cloth = { color = rgb(246, 244, 238), material = Enum.Material.SmoothPlastic, trim = rgb(214, 206, 188) },
	wood = { color = rgb(150, 98, 56), material = Enum.Material.Wood, trim = rgb(60, 56, 54) },
	stone = { color = rgb(128, 128, 124), material = Enum.Material.Slate, trim = rgb(96, 96, 94) },
	iron = { color = rgb(78, 80, 86), material = Enum.Material.Metal, trim = rgb(150, 152, 158) },
	steel = { color = rgb(186, 192, 200), material = Enum.Material.Metal, trim = rgb(110, 116, 126), shine = 0.25 },
	gold = { color = rgb(255, 196, 40), material = Enum.Material.Metal, trim = rgb(255, 236, 150), shine = 0.3 },
	chakra = { color = rgb(26, 30, 60), material = Enum.Material.Metal, trim = rgb(90, 220, 255), glow = true },
	seastone = { color = rgb(70, 112, 116), material = Enum.Material.Slate, trim = rgb(150, 255, 230), glow = true },
	diamond = { color = rgb(170, 240, 255), material = Enum.Material.Glass, trim = rgb(235, 255, 255), shine = 0.4 },
	gravity = { color = rgb(24, 20, 34), material = Enum.Material.Metal, trim = rgb(190, 90, 255), glow = true },
	-- Rebirth-gated.
	-- Turtle school: training-gi orange with navy trim and green shell plates.
	turtle = { color = rgb(255, 140, 30), material = Enum.Material.SmoothPlastic, trim = rgb(30, 50, 140) },
	-- Saiyan armour: white chest-plate shell with golden-brown shoulder plates.
	saiyan = { color = rgb(245, 245, 240), material = Enum.Material.SmoothPlastic, trim = rgb(200, 150, 40) },
	-- Ultra Instinct: chrome silver with a cold blue-white glow and silver wisps.
	ultra = {
		color = rgb(200, 210, 225),
		material = Enum.Material.Metal,
		trim = rgb(150, 210, 255),
		glow = true,
		shine = 0.45,
	},
	-- Premium (Robux).
	-- Shenron: emerald scales, gold trim, the seven dragon balls orbiting.
	dragon = {
		color = rgb(30, 150, 70),
		material = Enum.Material.Metal,
		trim = rgb(255, 200, 40),
		glow = true,
		shine = 0.25,
	},
	-- Nine-tails chakra: blazing orange with black seal marks.
	kyuubi = {
		color = rgb(255, 150, 30),
		material = Enum.Material.Neon,
		trim = rgb(30, 20, 20),
		glow = true,
	},
}
GearLook.Looks = LOOKS

local function part(model, band, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = band.CFrame * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = band
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- A cylinder ring round the band axis (Y): Roblox cylinders run along X, so turn them onto Y.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

function GearLook.band(look, diameter, length)
	local spec = LOOKS[look] or LOOKS.cloth
	local model = Instance.new("Model")
	model.Name = "Gear_" .. look
	-- The Band part is an invisible core (the weld and pivot); what you see is a hollow ring round it.
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Size = Vector3.new(length, diameter * 0.3, diameter * 0.3)
	band.CFrame = UPRIGHT
	band.Transparency = 1
	band.CanCollide = false
	band.CanQuery = false
	band.CanTouch = false
	band.Massless = true
	band.CastShadow = false
	band.Parent = model
	model.PrimaryPart = band
	-- Decorations are placed in the band part's own frame, where the band's axis is X.
	local r = diameter / 2

	-- A hollow ring round the axis: `width` along it, outer diameter `outer`, wall `wall` thick, centred at
	-- x along the axis. Built from short curved-ish segments so the middle stays open.
	local SEGMENTS = 12
	local function ring(width, outer, wall, x, color, material, props)
		local rMid = outer / 2 - wall / 2
		local chord = 2 * rMid * math.tan(math.pi / SEGMENTS) * 1.12
		for k = 0, SEGMENTS - 1 do
			local a = k / SEGMENTS * math.pi * 2
			part(
				model,
				band,
				Vector3.new(width, chord, wall),
				CFrame.new(x, 0, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0, -rMid),
				color,
				material,
				props
			)
		end
	end
	local wall = diameter * 0.2
	ring(length, diameter, wall, 0, spec.color, spec.material, {
		Reflectance = spec.shine or 0,
		Transparency = spec.material == Enum.Material.Glass and 0.25 or 0,
	})

	-- Trim rings sit proud of the band on every face: a larger outer edge, a smaller hole wall (so no two
	-- surfaces share a plane and flicker), and `extra` studs thicker than the band's outside.
	local function deco(width, extra, x, color, material, props)
		ring(width, diameter + extra, wall * 0.55 + extra / 2, x, color, material, props)
	end

	-- Rims at both ends (all looks), in the trim colour, reaching just past the band's ends.
	for _, y in { -1, 1 } do
		deco(length * 0.2, 0.08, y * (length * 0.4 + 0.02), spec.trim, spec.material, { Reflectance = spec.shine or 0 })
	end

	local function around(count, fn)
		for k = 0, count - 1 do
			local a = k / count * math.pi * 2
			fn(a, CFrame.Angles(a, 0, 0) * CFrame.new(0, 0, -r))
		end
	end

	if look == "cloth" then
		-- A loose wrap: a tilted ring across the band reads as a strip wound round it.
		deco(length * 0.28, 0.06, 0, spec.trim, Enum.Material.SmoothPlastic)
	elseif look == "stone" then
		around(5, function(_, at)
			part(model, band, Vector3.new(length * 0.7, 0.35, 0.45), at, spec.trim, Enum.Material.Slate)
		end)
	elseif look == "iron" or look == "steel" then
		around(6, function(_, at)
			part(model, band, Vector3.one * 0.18, at * CFrame.new(0, 0, -0.02), spec.trim, Enum.Material.Metal, {
				Shape = Enum.PartType.Ball,
			})
		end)
		if look == "steel" then
			deco(length * 0.16, 0.14, 0, spec.trim, Enum.Material.Metal, { Reflectance = 0.3 })
		end
	elseif look == "gold" then
		around(4, function(_, at)
			part(
				model,
				band,
				Vector3.new(length * 0.5, 0.2, 0.3),
				at * CFrame.new(0, 0, -0.04),
				spec.trim,
				Enum.Material.Metal,
				{
					Reflectance = 0.4,
				}
			)
		end)
	elseif look == "chakra" or look == "gravity" or look == "seastone" then
		-- A glowing seal ring with glyph blocks.
		deco(length * 0.14, 0.06, 0, spec.trim, Enum.Material.Neon)
		if look == "chakra" then
			around(4, function(_, at)
				part(
					model,
					band,
					Vector3.new(length * 0.5, 0.22, 0.12),
					at * CFrame.new(0, 0, -0.02),
					spec.trim,
					Enum.Material.Neon
				)
			end)
		end
	elseif look == "diamond" then
		around(6, function(_, at)
			part(
				model,
				band,
				Vector3.new(length * 0.6, 0.3, 0.3),
				at * CFrame.Angles(0, 0, math.rad(45)),
				spec.trim,
				Enum.Material.Glass,
				{ Transparency = 0.2, Reflectance = 0.4 }
			)
		end)
	end

	if look == "turtle" then
		-- Hexagon shell plates round the band.
		around(6, function(_, at)
			part(
				model,
				band,
				Vector3.new(length * 0.55, 0.42, 0.42),
				at * CFrame.new(0, 0, -0.03),
				rgb(70, 150, 60),
				Enum.Material.SmoothPlastic,
				{ Shape = Enum.PartType.Cylinder }
			)
		end)
		deco(length * 0.12, 0.08, 0, spec.trim, Enum.Material.SmoothPlastic)
	elseif look == "saiyan" then
		-- Two golden shoulder-plate fins and a dark undersuit band.
		deco(length * 0.3, 0.05, 0, rgb(30, 40, 110), Enum.Material.SmoothPlastic)
		around(2, function(_, at)
			part(
				model,
				band,
				Vector3.new(length * 0.9, 0.5, 0.22),
				at * CFrame.new(0, 0, -0.06),
				spec.trim,
				Enum.Material.SmoothPlastic
			)
		end)
	elseif look == "ultra" then
		-- A silver seal ring and wisps of cold silver-blue aura.
		deco(length * 0.14, 0.1, 0, spec.trim, Enum.Material.Neon)
		local wisp = Instance.new("ParticleEmitter")
		wisp.Texture = "rbxasset://textures/particles/smoke_main.dds"
		wisp.Color = ColorSequence.new(rgb(230, 240, 255), rgb(140, 200, 255))
		wisp.Transparency = NumberSequence.new(0.4, 1)
		wisp.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, diameter * 0.5), NumberSequenceKeypoint.new(1, 0) })
		wisp.Lifetime = NumberRange.new(0.5, 0.9)
		wisp.Speed = NumberRange.new(1.5, 2.5)
		wisp.Rate = 25
		wisp.LightEmission = 1
		wisp.Parent = band
	end

	if look == "dragon" then
		-- Shenron: rows of overlapping emerald scales, a gold whisker ridge, and the seven orange dragon
		-- balls with their red stars orbiting (the client spins the "GravityRing" hub).
		around(10, function(_, at)
			part(
				model,
				band,
				Vector3.new(length * 0.75, 0.34, 0.28),
				at * CFrame.Angles(0, 0, math.rad(35)),
				rgb(20, 110, 50),
				Enum.Material.Metal,
				{ Reflectance = 0.3 }
			)
		end)
		deco(length * 0.14, 0.12, 0, rgb(255, 200, 40), Enum.Material.Neon)
		local hub = part(model, band, Vector3.one * 0.1, CFrame.new(), spec.trim, nil, { Transparency = 1 })
		hub.Name = "GravityRing"
		hub:FindFirstChildOfClass("WeldConstraint"):Destroy()
		local tilt = CFrame.Angles(0.4, 0, 0.3)
		hub.CFrame = band.CFrame * tilt
		for b = 0, 6 do
			local a = b / 7 * math.pi * 2
			local ballAt = CFrame.new(0, math.cos(a) * diameter * 0.95, math.sin(a) * diameter * 0.95)
			part(
				model,
				hub,
				Vector3.one * 0.32,
				ballAt,
				rgb(255, 150, 20),
				Enum.Material.Glass,
				{ Shape = Enum.PartType.Ball, Reflectance = 0.2 }
			)
			part(
				model,
				hub,
				Vector3.one * 0.12,
				ballAt * CFrame.new(-0.12, 0, 0),
				rgb(220, 20, 20),
				Enum.Material.Neon,
				{ Shape = Enum.PartType.Ball }
			)
		end
		local orbit = Instance.new("Weld")
		orbit.Name = "Orbit"
		orbit.Part0, orbit.Part1, orbit.C0 = band, hub, tilt
		orbit.Parent = hub
		local glow = Instance.new("ParticleEmitter")
		glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glow.Color = ColorSequence.new(rgb(140, 255, 120), rgb(255, 220, 80))
		glow.Size = NumberSequence.new(0.25)
		glow.Lifetime = NumberRange.new(0.5, 1)
		glow.Speed = NumberRange.new(0.8, 1.6)
		glow.SpreadAngle = Vector2.new(180, 180)
		glow.Rate = 14
		glow.LightEmission = 1
		glow.Parent = band
	elseif look == "kyuubi" then
		-- Nine-tails chakra: black seal bands, swirl marks, and chakra flame boiling off it.
		deco(length * 0.12, 0.08, -length * 0.22, spec.trim, Enum.Material.SmoothPlastic)
		deco(length * 0.12, 0.08, length * 0.22, spec.trim, Enum.Material.SmoothPlastic)
		around(6, function(_, at)
			part(
				model,
				band,
				Vector3.new(length * 0.3, 0.22, 0.22),
				at * CFrame.new(0, 0, -0.04),
				spec.trim,
				Enum.Material.SmoothPlastic,
				{ Shape = Enum.PartType.Ball }
			)
		end)
		local fire = Instance.new("ParticleEmitter")
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
		fire.Color = ColorSequence.new(rgb(255, 170, 40), rgb(255, 70, 10))
		fire.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, diameter * 1.1), NumberSequenceKeypoint.new(1, 0) })
		fire.Lifetime = NumberRange.new(0.35, 0.7)
		fire.Speed = NumberRange.new(2, 3.5)
		fire.RotSpeed = NumberRange.new(-180, 180)
		fire.Rate = 45
		fire.LightEmission = 1
		fire.Parent = band
	end
	if look == "gravity" then
		-- Two rings of neon beads orbiting the band. Each ring hangs off an invisible hub on a Weld named
		-- "Orbit"; the client turns the weld (tag "GravityRing").
		for k = 1, 2 do
			local hub = part(model, band, Vector3.one * 0.1, CFrame.new(), spec.trim, nil, { Transparency = 1 })
			hub.Name = "GravityRing"
			hub:FindFirstChildOfClass("WeldConstraint"):Destroy()
			local tilt = CFrame.Angles(k * 1.1, 0, 0.7)
			hub.CFrame = band.CFrame * tilt
			for b = 0, 7 do
				local a = b / 8 * math.pi * 2
				local bead = part(
					model,
					hub,
					Vector3.one * 0.16,
					CFrame.new(0, math.cos(a) * diameter * 0.95, math.sin(a) * diameter * 0.95),
					spec.trim,
					Enum.Material.Neon,
					{ Shape = Enum.PartType.Ball }
				)
				bead.Name = "Bead"
			end
			local orbit = Instance.new("Weld")
			orbit.Name = "Orbit"
			orbit.Part0 = band
			orbit.Part1 = hub
			orbit.C0 = tilt
			orbit.Parent = hub
		end
	end
	if spec.glow then
		local light = Instance.new("PointLight")
		light.Color = spec.trim
		light.Range = 4
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = band
	end
	if look == "gold" or look == "diamond" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(spec.trim)
		sparkle.Size = NumberSequence.new(0.18)
		sparkle.Rate = 3
		sparkle.Lifetime = NumberRange.new(0.4, 0.8)
		sparkle.Speed = NumberRange.new(0.3)
		sparkle.LightEmission = 1
		sparkle.Parent = band
	end
	return model
end

return GearLook
