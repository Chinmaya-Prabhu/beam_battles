-- Cinematic director for the beam clash: camera shots, lighting mood and world effects.
-- Only the two players get the camera and the mood; everyone nearby sees the world effects.
--
-- The arc of a clash:
--   FACE-OFF  rival hero shot (low angle) -> your hero shot -> pull out to the duel
--   DUEL      side-on, slow dolly, leans toward whoever is losing, handheld sway;
--             punch-in + freeze frame on PERFECT / FIRST STRIKE; orbit the ball on SURGE / COUNTER
--   OVERDRIVE last seconds: camera pushes in and rolls, sunset grade, lightning off the ball,
--             debris lifting off the ground, braziers flare, heartbeat vignette
--   K.O.      white flash + freeze, slow-motion over-the-shoulder of the blast, winner hero shot
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Cinema = {}
local B = Config.Battle

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function headOf(model)
	if not (model and model.Parent) then
		return nil
	end
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return head and head.Position or root and root.Position + Vector3.new(0, 2, 0)
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
end

local function noise(t, seed, amount)
	return Vector3.new(math.noise(t, seed, 0.3), math.noise(t, seed + 7, 0.6), math.noise(t, seed + 13, 0.9)) * amount
end

-- --------------------------------------------------------------- events from Clash.lua
function Cinema.event(view, kind)
	view.cine = view.cine or {}
	local c = view.cine
	local now = os.clock()
	if kind == "impact" then
		c.punchAt = now
		c.hitstopUntil = now + 0.07
	elseif kind == "bigImpact" then
		c.punchAt = now
		c.hitstopUntil = now + 0.11
		c.shakeUntil, c.shakeAmount = now + 0.35, 0.9
	elseif kind == "surge" or kind == "counter" then
		c.orbitAt = now
		c.orbitFor = kind == "counter" and 0.9 or 0.6
		c.hitstopUntil = now + (kind == "counter" and 0.12 or 0.05)
		c.shakeUntil, c.shakeAmount = now + 0.5, kind == "counter" and 1.4 or 0.7
	elseif kind == "ko" then
		c.koAt = now
		c.hitstopUntil = now + 0.14
		c.shakeUntil, c.shakeAmount = now + 0.6, 1.8
	elseif kind == "rivalImpact" then
		c.shakeUntil, c.shakeAmount = now + 0.3, 0.6
	end
end

function Cinema.frozen(view)
	return view.cine and view.cine.hitstopUntil and os.clock() < view.cine.hitstopUntil
end

-- Overdrive strength 0..1: the fight's heat (view.heat: the hottest combo, maxed in a tap frenzy).
function Cinema.overdrive(view)
	if view.phase ~= "battle" then
		return 0
	end
	return smooth(view.heat or 0)
end

-- --------------------------------------------------------------- camera
function Cinema.camera(view, t, out)
	view.cine = view.cine or {}
	local c = view.cine
	local now = os.clock()
	local me, rival = view.mySide, 3 - view.mySide
	local myPad, rivalPad = view.pads[me].Position, view.pads[rival].Position
	local dir = flat(rivalPad - myPad) -- from me toward the rival
	local mid = (myPad + rivalPad) / 2
	local up = Vector3.yAxis
	local myHead = headOf(view.sides[me].model) or myPad + Vector3.new(0, 6, 0)
	local rivalHead = headOf(view.sides[rival].model) or rivalPad + Vector3.new(0, 6, 0)
	local ballPos = view.ball and view.ball.Position or mid + Vector3.new(0, 8, 0)
	local eye, focus, fov, roll = nil, nil, 62, 0

	-- K.O.: owns the camera once it starts.
	if c.koAt then
		local e = now - c.koAt
		local winnerSide = view.winner or me
		local winHead = winnerSide == me and myHead or rivalHead
		local loseHead = winnerSide == me and rivalHead or myHead
		local toLoser = flat(loseHead - winHead)
		local side = toLoser:Cross(up).Unit
		if e < 0.14 then
			eye, focus, fov = c.lastEye or (mid + out * 20 + up * 8), c.lastFocus or ballPos, 58
		elseif e < 1.15 then
			-- Slow push over the winner's shoulder onto the blast.
			local k = smooth((e - 0.14) / 1.0)
			eye = winHead - toLoser * (5 - k * 1.5) + side * 2.6 + up * (0.6 + k * 0.4)
			focus = loseHead:Lerp(loseHead - up * 2, k)
			fov = 50 - k * 6
		else
			-- Winner hero shot: low angle, slow orbit, from the arena's open side (`out`, where the duel camera
			-- sits). From the loser's side the altar between the two pads filled the frame.
			local k = smooth((e - 1.15) / 1.6)
			local swing = CFrame.Angles(0, math.rad(-25 + k * 35), 0)
			local offset = swing:VectorToWorldSpace(out * 6 + toLoser * 7)
			eye = winHead + offset - up * 1.2
			focus = winHead - up * 1.6 -- (the head high in frame, clear of the prize card)
			fov = 48
		end
		roll = 0
	elseif view.phase == "faceoff" then
		local f = B.faceOff - (view.startAt - t) -- 0 .. faceOff
		local side = dir:Cross(up).Unit
		if f < 0.85 then
			-- Rival hero shot: low, three-quarter front, slow dolly in.
			local k = smooth(f / 0.85)
			eye = rivalHead - dir * (8.5 - k * 2) + side * 3.2 - up * 2.4
			focus = rivalHead + up * 0.3
			fov = 46
		elseif f < 1.6 then
			-- Your hero shot.
			local k = smooth((f - 0.85) / 0.75)
			eye = myHead + dir * (8.5 - k * 2) - side * 3.2 - up * 2.4
			focus = myHead + up * 0.3
			fov = 46
		else
			-- Pull out to the duel.
			local k = smooth((f - 1.6) / (B.faceOff - 1.6))
			eye = (myHead + dir * 6.5 - side * 3.2 - up * 2.4):Lerp(mid + out * 21 + up * 8, k)
			focus = (myHead + up * 0.3):Lerp(mid + up * 7, k)
			fov = 46 + k * 16
		end
	else
		-- The duel: side-on, drifting, leaning toward whoever is losing.
		local od = Cinema.overdrive(view, t)
		local share = view.shownShare or 0.5 -- my share, 0..1
		local lean = (0.5 - share) * 7 -- losing pulls the camera toward my side
		local drift = math.sin(t * 0.35) * math.rad(9)
		local sideOut = CFrame.Angles(0, drift, 0):VectorToWorldSpace(out)
		local distance = 21 - od * 9
		local height = 8 - od * 3.5
		focus = mid:Lerp(ballPos, 0.45) + up * (1.5 - od) - dir * lean * 0.5
		eye = focus + sideOut * distance + up * height - dir * lean
		eye += noise(t * 0.8, 1, 0.25 + od * 0.35)
		fov = 62 - od * 10 + math.sin(t * 2) * 0.6
		roll = math.rad(od * 7) * math.sin(t * 0.9 + 0.5)
		-- Orbit the ball on surge / counter.
		if c.orbitAt and now - c.orbitAt < c.orbitFor then
			local k = (now - c.orbitAt) / c.orbitFor
			local around = CFrame.Angles(0, math.rad(-40 + k * 80), 0):VectorToWorldSpace(sideOut)
			local blend = math.sin(k * math.pi)
			eye = eye:Lerp(ballPos + around * 9 - up * 1.5, blend)
			focus = focus:Lerp(ballPos, blend)
			fov -= 8 * blend
		end
		-- Punch in on big hits.
		if c.punchAt then
			local k = 1 - math.clamp((now - c.punchAt) / 0.28, 0, 1)
			eye = eye:Lerp(ballPos, 0.18 * k)
			fov -= 7 * k
		end
	end

	if c.shakeUntil and now < c.shakeUntil then
		eye += noise(now * 45, 3, (c.shakeUntil - now) * (c.shakeAmount or 1))
	end
	c.lastEye, c.lastFocus = eye, focus
	return CFrame.lookAt(eye, focus) * CFrame.Angles(0, 0, roll), fov
end

-- --------------------------------------------------------------- lighting mood (players only)
local base = nil
local function grade()
	return Lighting:FindFirstChild("Grade"), Lighting:FindFirstChild("Bloom"), Lighting:FindFirstChild("Atmosphere")
end

local function capture()
	if base then
		return
	end
	local g, b, a = grade()
	base = {
		clock = Lighting.ClockTime,
		exposure = Lighting.ExposureCompensation,
		sat = g and g.Saturation,
		contrast = g and g.Contrast,
		tint = g and g.TintColor,
		bloom = b and b.Intensity,
		density = a and a.Density,
	}
end

function Cinema.mood(view, t)
	capture()
	local g, b, a = grade()
	local battle = (view.phase == "battle" or view.phase == "faceoff") and 1 or 0
	local od = Cinema.overdrive(view, t)
	local ko = view.cine and view.cine.koAt and math.max(0, 1 - (os.clock() - view.cine.koAt) / 2.5) or 0
	local heat = math.max(od, ko)
	Lighting.ClockTime = base.clock + 1.3 * heat -- toward a blood-orange sunset
	Lighting.ExposureCompensation = base.exposure - 0.15 * battle - 0.2 * heat
	if g then
		g.Saturation = base.sat + 0.12 * battle + 0.15 * heat
		g.Contrast = base.contrast + 0.1 * battle + 0.15 * heat
		g.TintColor = base.tint:Lerp(Color3.fromRGB(255, 205, 175), heat)
	end
	if b then
		b.Intensity = base.bloom + 0.2 * battle + 0.6 * heat
	end
	if a then
		a.Density = base.density + 0.12 * heat
	end
end

function Cinema.restore()
	if not base then
		return
	end
	local g, b, a = grade()
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(Lighting, info, { ClockTime = base.clock, ExposureCompensation = base.exposure }):Play()
	if g then
		TweenService:Create(g, info, { Saturation = base.sat, Contrast = base.contrast, TintColor = base.tint }):Play()
	end
	if b then
		TweenService:Create(b, info, { Intensity = base.bloom }):Play()
	end
	if a then
		TweenService:Create(a, info, { Density = base.density }):Play()
	end
	base = nil
end

-- --------------------------------------------------------------- world effects (everyone nearby)
local function neon(size, cf, color, transparency, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = transparency or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end

-- A jagged bolt from `a` to `b`, made of short segments, gone in a blink.
local function bolt(a, b, color, width)
	local points = { a }
	local segments = 5
	for i = 1, segments - 1 do
		local k = i / segments
		table.insert(
			points,
			a:Lerp(b, k) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.2
		)
	end
	table.insert(points, b)
	for i = 1, #points - 1 do
		local p, q = points[i], points[i + 1]
		local seg = neon(Vector3.new(width, width, (q - p).Magnitude), CFrame.lookAt((p + q) / 2, q), color, 0)
		Debris:AddItem(seg, 0.06)
	end
end

function Cinema.shockwave(pos, color, size)
	local ring = neon(
		Vector3.new(0.3, 2, 2),
		CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		0.15,
		Enum.PartType.Cylinder
	)
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, size, size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

function Cinema.effects(view, t, dt)
	if not view.ball or view.ball.Transparency >= 1 then
		return
	end
	view.cine = view.cine or {}
	local c = view.cine
	local od = Cinema.overdrive(view, t)
	local ballPos = view.ball.Position
	-- Lightning arcs off the ball: a few in the duel, a storm in overdrive.
	c.boltAcc = (c.boltAcc or 0) + dt * (2 + od * 22)
	while c.boltAcc >= 1 do
		c.boltAcc -= 1
		local outward = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.2, math.random() - 0.5).Unit
		local color = math.random() < 0.5 and Color3.fromRGB(255, 250, 210) or Color3.fromRGB(170, 220, 255)
		bolt(ballPos, ballPos + outward * (4 + od * 6), color, 0.18 + od * 0.12)
	end
	-- Debris lifting off the ground under the ball in overdrive.
	if od > 0 then
		c.rockAcc = (c.rockAcc or 0) + dt * od * 14
		while c.rockAcc >= 1 do
			c.rockAcc -= 1
			local ground = Vector3.new(ballPos.X, view.pads[1].Position.Y + 0.5, ballPos.Z)
			local start = ground + Vector3.new(math.random(-9, 9), 0, math.random(-9, 9))
			local size = 0.4 + math.random() * 0.9
			local rock = Instance.new("Part")
			rock.Anchored, rock.CanCollide, rock.CanQuery, rock.CanTouch = true, false, false, false
			rock.Size = Vector3.new(size, size * 0.8, size)
			rock.Color = Color3.fromRGB(150, 140, 128)
			rock.Material = Enum.Material.Slate
			rock.CFrame = CFrame.new(start) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			rock.Parent = workspace
			TweenService:Create(rock, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(start + Vector3.new(0, 6 + math.random() * 6, 0))
					* CFrame.Angles(math.random() * 6, math.random() * 6, 0),
				Transparency = 1,
			}):Play()
			Debris:AddItem(rock, 1.25)
		end
	end
	-- Braziers flare with the clash.
	if not c.fires then
		c.fires = {}
		local altar = workspace:FindFirstChild("Map") and workspace.Map.Altars:FindFirstChild("Altar" .. view.altar)
		for _, f in altar and altar:GetDescendants() or {} do
			if f:IsA("Fire") then
				c.fires[f] = { size = f.Size, heat = f.Heat }
			end
		end
	end
	for f, orig in c.fires do
		f.Size = orig.size * (1.6 + od * 1.4)
		f.Heat = orig.heat * (1.5 + od)
	end
end

function Cinema.cleanup(view)
	for f, orig in view.cine and view.cine.fires or {} do
		if f.Parent then
			f.Size, f.Heat = orig.size, orig.heat
		end
	end
end

-- --------------------------------------------------------------- overlay (vignette + flash), players only
local function edge(parent, anchor, pos, size, rotation)
	local f = Instance.new("Frame")
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.ZIndex = 2
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	f.Parent = parent
	return f
end

function Cinema.overlay(gui)
	local holder = Instance.new("Frame")
	holder.Name = "Vignette"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 2
	holder.Parent = gui
	local edges = {
		edge(holder, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1), 0),
		edge(holder, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.22, 1), 180),
		edge(holder, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.22), 90),
		edge(holder, Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.22), 270),
	}
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 20
	flash.Parent = gui
	return { holder = holder, edges = edges, flash = flash }
end

function Cinema.flash(ov, color, strength)
	ov.flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	ov.flash.BackgroundTransparency = 1 - (strength or 0.7)
	TweenService:Create(ov.flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

-- Red heartbeat as the orb closes in on you, orange in overdrive.
function Cinema.updateOverlay(ov, view, t)
	local od = Cinema.overdrive(view, t)
	local color, amount = Color3.new(0, 0, 0), 0
	if view.phase == "battle" then
		local danger = view.danger or 0
		if danger > 0 then
			local beat = (math.sin(t * 14) + 1) / 2
			color, amount = Color3.fromRGB(255, 30, 40), danger * 0.6 * (0.6 + 0.4 * beat)
		end
		if od > 0 and amount < od * 0.45 then
			color, amount = Color3.fromRGB(255, 110, 30), od * 0.45
		end
	end
	for _, e in ov.edges do
		e.BackgroundColor3 = color
		e.BackgroundTransparency = 1 - amount
	end
end

return Cinema
