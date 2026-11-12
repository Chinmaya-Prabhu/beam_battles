-- The beam clash on the client (docs/POLISH_BIBLE.md §2.3).
-- Everyone sees the beams and the collision ball; the two players also get the clash screen,
-- the side-on camera, tap and CHARGED ATTACK input. All numbers come from the server; the client only draws.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local ClashRules = require(Shared.ClashRules)
local Cinema = require(script.Parent.ClashCinema)
local Audio = require(script.Parent.Audio)
local ClashBeams = require(script.Parent.ClashBeams)
local BeamSkins = require(Shared.BeamSkins)
local UIKit = require(script.Parent.UIKit)
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local UIAtlas = require(Shared.UIAtlas)

local Clash = {}
local B = Config.Battle
local P = Config.Push
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SIDE_COLOR = { Color3.fromRGB(70, 210, 255), Color3.fromRGB(255, 130, 40) }
local INK = Color3.fromRGB(24, 16, 40)
local FONT = Enum.Font.LuckiestGuy

local views = {} -- [altar] = view
local mine = nil -- the view the local player is fighting in
local close -- forward (the TRAIN button closes the clash screen)
local remote

-- ------------------------------------------------------------------ helpers
local function tween(inst, time, props, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- A sound effect by name (shared/Sounds.lua); `scale` multiplies its volume, `pitch` its speed.
local function sound(name, scale, pitch)
	Audio.play(name, { scale = scale, pitch = pitch })
end

local function neon(name, shape, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0
	p.Size = Vector3.one
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = workspace
	return p
end

-- Clash text follows the game's type system (client/UIKit.lua TYPE): give a Style for a fixed size, or it
-- scales to its box up to MaxSize (default 44) so nothing balloons on big screens.
local OURS = { StrokeThickness = true, Style = true, MaxSize = true }
local function text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 1
	local style = props.Style and UIKit.TYPE[props.Style]
	if style then
		t.Font = style.font
		t.TextScaled = false
		t.TextSize = style.size
	else
		t.TextScaled = true
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = props.MaxSize or 44
		cap.Parent = t
	end
	for k, v in props do
		if not OURS[k] then
			t[k] = v
		end
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = props.StrokeThickness or 3
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0.5, 0)
	c.Parent = parent
end

local function stroke(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 4
	s.Color = color or INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function pop(inst, from)
	local scale = inst:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = inst
	scale.Scale = from or 1.6
	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- The point in front of a fighter's chest where its beam leaves its hands.
local function hands(model)
	local r = model and model.Parent and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not r then
		return nil
	end
	local s = model:GetScale()
	return (r.CFrame * CFrame.new(0, 0.5 * s, -2.1 * s)).Position
end

-- ------------------------------------------------------------------ world view (everyone)
local function makeBeams(view)
	view.beams = {}
	for side = 1, 2 do
		-- The player's equipped beam skin (shared/BeamSkins.lua); bots and players without one use the side colour.
		local info = view.sides[side]
		local owner = info and info.userId and info.userId ~= 0 and Players:GetPlayerByUserId(info.userId)
		local skin = owner and BeamSkins.ByKey[owner:GetAttribute("BeamSkin") or ""]
		view.beams[side] = ClashBeams.new(SIDE_COLOR[side], skin)
	end
	local ball = neon("ClashBall", Enum.PartType.Ball, Color3.fromRGB(255, 255, 230), 0)
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 0.8
	light.Color = Color3.fromRGB(255, 240, 200)
	light.Parent = ball
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 60
	sparks.Lifetime = NumberRange.new(0.25, 0.5)
	sparks.Speed = NumberRange.new(10, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.9, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 250, 200), Color3.fromRGB(255, 180, 80))
	sparks.Parent = ball
	local halo = neon("ClashHalo", Enum.PartType.Ball, Color3.fromRGB(255, 220, 140), 0.7)
	halo.Material = Enum.Material.SmoothPlastic
	view.ball, view.halo, view.sparks = ball, halo, sparks
	ball.Transparency, halo.Transparency = 1, 1
	sparks.Enabled = false
end

local function destroyBeams(view)
	for _, beam in view.beams or {} do
		beam:destroy()
	end
	if view.ball then
		view.ball:Destroy()
		view.halo:Destroy()
	end
	view.beams = nil
end

local function updateWorld(view, dt)
	local a, b = hands(view.sides[1].model), hands(view.sides[2].model)
	if not (a and b and view.beams) then
		return
	end
	local t = workspace:GetServerTimeNow()
	local live = view.phase == "battle" and t >= (view.goAt or 0)
	local firing = live or (view.roundHit and os.clock() - view.roundHit < 0.25)
	view.shown = view.shown or 0.5
	local target = view.pos or 0.5
	if view.roundHit then
		-- The clash point blows through the round's loser.
		target = view.roundLoser == 1 and -0.04 or 1.04
	end
	if not Cinema.frozen(view) then
		-- The K.O. blast travels in slow motion for the first second.
		local koSlow = view.cine and view.cine.koAt and os.clock() - view.cine.koAt < 1.1 and 1.6 or 6
		view.shown += (target - view.shown) * math.min(1, dt * (view.roundHit and koSlow or 10))
	end
	-- The beams angle up and meet in the air above the altar, under the hovering prize.
	local ballPos = a:Lerp(b, view.shown) + Vector3.new(0, math.sin(math.clamp(view.shown, 0, 1) * math.pi) * 6, 0)
	local pulse = 1 + math.sin(t * 30) * 0.08
	local frenzy = view.frenzyUntil and t < view.frenzyUntil
	local combo = view.comboNow or { 1, 1 }
	-- Intensity for the cinematic director: the hottest combo, maxed in a frenzy.
	-- (Capped at half outside a frenzy: full overdrive washes the screen in fire and hides the fight.)
	view.heat = frenzy and 1 or math.clamp(math.max(combo[1], combo[2]) - 1, 0, 0.6) / 0.6 * 0.45
	for side = 1, 2 do
		local beam = view.beams[side]
		local from = side == 1 and a or b
		-- A steady combo makes your beam thicker and white-hot; an ultimate or a frenzy blows it up.
		local heat = math.clamp((combo[side] - 1) / 0.6, 0, 1)
		local ult = view.ultFlash and view.ultFlash[side] and os.clock() - view.ultFlash[side] < 0.6 and 1 or 0
		local width = (1.3 + heat * 1.4) * pulse * (frenzy and 1.6 or 1) * (1 + ult * 1.2)
		beam:update(from, ballPos, width, firing, t, math.max(heat * 0.6, ult, frenzy and 0.8 or 0))
	end
	local size = (2.2 + view.heat * 2.4) * pulse
	view.ball.Size = Vector3.one * size
	view.ball.Position = ballPos
	view.halo.Size = Vector3.one * size * 1.9
	view.halo.Position = ballPos
	view.ball.Transparency = firing and 0 or 1
	view.ball.Color = frenzy and Color3.fromRGB(255, 80, 70) or Color3.fromRGB(255, 255, 230)
	view.halo.Transparency = firing and 0.6 or 1
	view.sparks.Enabled = firing
end

-- ------------------------------------------------------------------ clash screen (the two players)
local function portrait(parent, prize)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	corner(vp)
	vp.Parent = parent
	-- Keep a clean copy the first time: by the result card the altar's model has already gone.
	local model = prize and prize.model
	if prize and not prize.copy and model and model.Parent then
		local copy = model:Clone()
		for _, d in copy:GetDescendants() do
			if d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		copy:PivotTo(CFrame.new())
		prize.copy = copy
	end
	if prize and prize.copy then
		local copy = prize.copy:Clone()
		copy.Parent = vp
		local cam = Instance.new("Camera")
		local head = copy:FindFirstChild("Head")
		local focus = head and head.Position or Vector3.zero
		local r = copy:FindFirstChild("HumanoidRootPart")
		local forward = r and r.CFrame.LookVector or Vector3.new(0, 0, -1)
		local s = copy:GetScale()
		cam.CFrame =
			CFrame.lookAt(focus + forward * 3.2 * s + Vector3.new(0, 0.3 * s, 0), focus - Vector3.new(0, 0.6 * s, 0))
		cam.FieldOfView = 40
		cam.Parent = vp
		vp.CurrentCamera = cam
	end
	return vp
end

local function buildScreen(view)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClashUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")
	view.gui = gui
	local me, rival = view.mySide, 3 - view.mySide

	view.overlay = Cinema.overlay(gui)

	-- On phones Roblox's top bar is tall and holds more buttons: the header (names, tug bar) and the lines
	-- under it move down clear of it.
	local DROP = UIKit.compact() and 34 or 0

	-- Tap anywhere.
	local tap = Instance.new("TextButton")
	tap.Name = "TapZone"
	tap.Size = UDim2.fromScale(1, 1)
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.AutoButtonColor = false
	tap.ZIndex = 1
	tap.Parent = gui
	view.tap = tap

	-- Tug bar: your colour from the left, theirs from the right, prize portrait on the boundary.
	local bar = Instance.new("Frame")
	bar.Name = "TugBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 90 + DROP)
	bar.Size = UDim2.new(0.62, 0, 0, 30)
	bar.BackgroundColor3 = SIDE_COLOR[rival]
	bar.ZIndex = 3
	corner(bar)
	stroke(bar, 5)
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Mine"
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.BackgroundColor3 = SIDE_COLOR[me]
	fill.ZIndex = 3
	corner(fill)
	fill.Parent = bar
	local shine = Instance.new("Frame")
	shine.Size = UDim2.new(1, -12, 0.3, 0)
	shine.Position = UDim2.new(0, 6, 0.12, 0)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.6
	shine.ZIndex = 4
	corner(shine)
	shine.Parent = bar
	local face = Instance.new("Frame")
	face.Name = "Prize"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromOffset(78, 78)
	face.BackgroundTransparency = 1
	face.ZIndex = 6
	face.Parent = bar
	local ring = portrait(face, view.prize)
	ring.ZIndex = 6
	local prizeRarity = view.prize.key and Fighters.ByKey[view.prize.key].rarity or "Common"
	stroke(ring, 5, Config.Rarities[prizeRarity].color)
	view.bar, view.fill, view.face = bar, fill, face

	-- Names and scores at each end.
	local function nameplate(side, anchorX, posX, align)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(anchorX, 1)
		holder.Position = UDim2.new(posX, 0, 0, 84 + DROP)
		holder.Size = UDim2.new(0.28, 0, 0, 64)
		holder.ZIndex = 3
		holder.Parent = gui
		table.insert(view.namePlates, holder)
		local label = (side == me) and "YOU"
			or (view.sides[side].bot and (view.sides[side].name .. "  BOT") or view.sides[side].name)
		text(holder, {
			Style = "heading",
			TextSize = 22,
			Text = label,
			Size = UDim2.new(1, 0, 0.5, 0),
			TextColor3 = SIDE_COLOR[side],
			TextXAlignment = align,
			ZIndex = 3,
		})
		-- Rounds won, as dots under the name (filled = won).
		local dots = Instance.new("Frame")
		dots.BackgroundTransparency = 1
		dots.Position = UDim2.fromScale(0, 0.56)
		dots.Size = UDim2.new(1, 0, 0.32, 0)
		dots.ZIndex = 3
		dots.Parent = holder
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.HorizontalAlignment = align == Enum.TextXAlignment.Left and Enum.HorizontalAlignment.Left
			or Enum.HorizontalAlignment.Right
		row.Padding = UDim.new(0, 6)
		row.Parent = dots
		-- (Says what the dots are.)
		text(dots, {
			Style = "label",
			TextSize = 16,
			Text = "ROUNDS",
			Size = UDim2.fromOffset(70, 18),
			LayoutOrder = align == Enum.TextXAlignment.Left and 0 or 99,
			TextXAlignment = align,
			ZIndex = 3,
		})
		local list = {}
		for i = 1, view.roundsToWin or P.roundsToWin do
			local d = Instance.new("Frame")
			d.LayoutOrder = i
			d.Size = UDim2.fromOffset(16, 16)
			d.BackgroundColor3 = Color3.fromRGB(40, 36, 60)
			d.ZIndex = 3
			corner(d, UDim.new(1, 0))
			stroke(d, 2.5)
			d.Parent = dots
			list[i] = d
		end
		return list
	end
	view.scoreLabel = {}
	view.namePlates = {}
	view.scoreLabel[me] = nameplate(me, 0, 0.19, Enum.TextXAlignment.Left)
	view.scoreLabel[rival] = nameplate(rival, 1, 0.81, Enum.TextXAlignment.Right)

	-- The seconds left, in a dark round badge under the bar (clear of the prize portrait on the bar).
	view.timer = text(gui, {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132 + DROP),
		Size = UDim2.fromOffset(64, 40),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Color3.fromRGB(24, 18, 40),
		Text = "",
		Style = "number",
		TextSize = 36,
		ZIndex = 3,
	})
	Instance.new("UICorner", view.timer).CornerRadius = UDim.new(1, 0)
	view.push = text(gui, {
		Name = "Push",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 178 + DROP),
		Size = UDim2.fromOffset(320, 30),
		Text = "",
		Style = "label",
		TextSize = 18,
		ZIndex = 3,
	})
	view.center = text(gui, {
		Name = "Center",
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- (Phones: below the bar and the lines under it, which sit lower there.)
		Position = UDim2.fromScale(0.5, UIKit.compact() and 0.6 or 0.42),
		Size = UIKit.compact() and UDim2.fromScale(0.45, 0.1) or UDim2.fromScale(0.6, 0.16),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 226, 70),
		StrokeThickness = 6,
		MaxSize = 84,
		ZIndex = 8,
	})
	view.combo = text(gui, {
		Name = "Combo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.06, 0.55),
		Size = UDim2.fromOffset(220, 70),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})

	-- The CHARGED ATTACK: one big round button where the right thumb rests (E on a keyboard). A ring of 12
	-- pips around it fills from your pushes; full, it turns gold with turning rays and a bouncing PRESS E.
	local holder = Instance.new("Frame")
	holder.Name = "ChargedAttack"
	-- The tapping hand stays free for tapping: right-handed players (the default) get the charged attack on the
	-- LEFT, left-handed ones (Settings) on the right.
	local function placeHolder()
		local onLeft = player:GetAttribute("LeftHanded") ~= true
		local margin = UIKit.compact() and 14 or 40
		holder.AnchorPoint = Vector2.new(onLeft and 0 or 1, 1)
		holder.Position = UDim2.new(onLeft and 0 or 1, onLeft and margin or -margin, 1, UIKit.compact() and -10 or -64)
		-- The combo text takes the other side.
		view.combo.AnchorPoint = Vector2.new(onLeft and 1 or 0, 0.5)
		view.combo.Position = UDim2.fromScale(onLeft and 0.94 or 0.06, 0.55)
		view.combo.TextXAlignment = onLeft and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	end
	placeHolder()
	player:GetAttributeChangedSignal("LeftHanded"):Connect(placeHolder)
	holder.Size = UDim2.fromOffset(170, 170)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 11
	holder.Parent = gui
	UIKit.fitScale(holder)
	-- Rays behind the button (shown when full).
	local rays = Instance.new("Frame")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1.9, 1.9)
	rays.BackgroundTransparency = 1
	rays.Visible = false
	rays.ZIndex = 10
	rays.Parent = holder
	for i = 0, 3 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(1, 0, 0, 22)
		ray.Rotation = i * 45
		ray.BackgroundColor3 = Color3.fromRGB(255, 226, 90)
		ray.BorderSizePixel = 0
		ray.ZIndex = 10
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = ray
		ray.Parent = rays
	end
	-- The button.
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.Size = UDim2.fromScale(0.78, 0.78)
	button.BackgroundColor3 = Color3.fromRGB(42, 36, 72)
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = 12
	corner(button)
	local edge = stroke(button, 6)
	button.Parent = holder
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 190))
	grad.Parent = button
	local icon = UIAtlas.label(button, "smash_charged", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.58, 0.58),
		BackgroundTransparency = 1,
		ZIndex = 13,
	})
	local label = text(button, {
		Text = "CHARGED ATTACK",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.86, 0.2),
		StrokeThickness = 2.5,
		ZIndex = 14,
	})
	-- The pip ring.
	local pips = {}
	for i = 1, 12 do
		local a = math.rad(-90 + (i - 1) * 30)
		local pip = Instance.new("Frame")
		pip.AnchorPoint = Vector2.new(0.5, 0.5)
		pip.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.47, 0.5 + math.sin(a) * 0.47)
		pip.Size = UDim2.fromScale(0.12, 0.12)
		pip.BackgroundColor3 = Color3.fromRGB(40, 36, 60)
		pip.ZIndex = 12
		corner(pip, UDim.new(1, 0))
		stroke(pip, 2.5)
		pip.Parent = holder
		pips[i] = pip
	end
	-- One prompt only: the button's own label says what to do when it's full ("PRESS E!" / "TAP!").
	local keyboard = not UIKit.touch() -- (touch screens can report a keyboard too: go by the preferred input)
	view.charge = {
		holder = holder,
		button = button,
		edge = edge,
		icon = icon,
		label = label,
		pips = pips,
		rays = rays,
		lit = 0,
		keyboard = keyboard,
	}
	view.ultButton = holder
	button.Activated:Connect(function()
		if view.phase == "battle" then
			remote:FireServer("Ult")
			pop(holder, 1.3)
		end
	end)
	-- The matchup line under the tug bar (YOU 2K vs 1.2K · EVEN), or the rival's charged attack warning.
	view.matchupLabel = text(gui, {
		Style = "label",
		TextSize = 20,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 212 + DROP),
		Size = UDim2.fromOffset(420, 28),
		Text = "",
		ZIndex = 3,
	})
	-- Under it, for a HARD or TOO STRONG rival: what to do about it (train), said before the fight.
	view.hintLabel = text(gui, {
		Style = "label",
		TextSize = 16,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 242 + DROP),
		Size = UDim2.fromOffset(460, 22),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 200, 150),
		ZIndex = 3,
	})
end

local function floatNumber(view, at, value, color)
	local label = text(view.gui, {
		Text = "+" .. value,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(90, 44),
		TextColor3 = color,
		ZIndex = 9,
	})
	local dx = math.random(-40, 40)
	tween(label, 0.45, { Position = UDim2.fromOffset(at.X + dx, at.Y - 90), TextTransparency = 1 })
	local s = label:FindFirstChildOfClass("UIStroke")
	tween(s, 0.45, { Transparency = 1 })
	Debris:AddItem(label, 0.5)
end

-- Big centred word that pops in and clears itself (SURGE!, COUNTER BREAK!, FIRST STRIKE!).
local function flashWord(view, word, color, hold)
	view.center.Text = word
	view.center.TextColor3 = color or Color3.fromRGB(255, 226, 70)
	pop(view.center, 2)
	task.delay(hold or 0.7, function()
		if view.center.Text == word then
			view.center.Text = ""
		end
	end)
end

local function onTap(view, at)
	if view.phase ~= "battle" then
		return
	end
	view.pending += 1
	view.myClicks += 1
	local t = os.clock()
	view.combo_n = (t - (view.lastTap or 0) < 0.35) and math.min((view.combo_n or 0) + 1, 99) or 1
	view.lastTap = t
	local tier = math.clamp(math.floor(view.combo_n / 8) + 1, 1, 10)
	floatNumber(view, at or UserInputService:GetMouseLocation(), 1, SIDE_COLOR[view.mySide])
	sound("tap", 0.35, 0.9 + tier * 0.08)
	view.comboTier = tier
	view.kick = 0.12
end

-- ------------------------------------------------------------------ lifecycle
local function cameraFor(view)
	local me, rival = view.pads[view.mySide], view.pads[3 - view.mySide]
	local mid = (me.Position + rival.Position) / 2
	if not view.out then
		local dir = (rival.Position - me.Position).Unit
		local out = dir:Cross(Vector3.yAxis).Unit -- rival appears on the right of the screen
		-- Use the other side if a tree or building would sit between the camera and the clash.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { view.sides[1].model, view.sides[2].model, workspace.Map.Altars }
		local from = mid + Vector3.new(0, 6, 0)
		if workspace:Raycast(from, out * 28 + Vector3.new(0, 4, 0), params) then
			if not workspace:Raycast(from, -out * 28 + Vector3.new(0, 4, 0), params) then
				out = -out
			end
		end
		view.out = out
	end
	return mid, view.out
end

-- The result. The fighters celebrate (or fall) in the middle of the screen, so nothing goes there: the
-- verdict and the grade take the top (where the tug bar was), and what you won, or what to do about a loss,
-- sits on the bottom edge.
local function endScreen(view, data)
	local won = data.winner == view.mySide
	local compact = UIKit.compact()
	view.bar.Visible = false
	for _, plate in view.namePlates or {} do
		plate.Visible = false -- (the verdict takes the top)
	end
	view.timer.Text = ""
	view.timer.BackgroundTransparency = 1
	view.combo.Text = ""
	view.push.Text = ""
	view.ultButton.Visible = false
	view.matchupLabel.Text = ""
	view.hintLabel.Text = ""
	view.tap.Visible = false
	-- Top: VICTORY! / DEFEATED with the grade beside it.
	view.center.Position = UDim2.new(0.5, 0, 0, compact and 104 or 140)
	view.center.Size = UDim2.fromScale(0.42, compact and 0.14 or 0.11)
	view.center.TextColor3 = won and Color3.fromRGB(255, 214, 51) or Color3.fromRGB(200, 205, 220)
	view.center.Text = won and "VICTORY!" or "DEFEATED"
	pop(view.center, 2.4)
	local grade = data.grades and data.grades[view.mySide]
	if grade then
		local gradeColor = ({
			S = Color3.fromRGB(255, 214, 51),
			A = Color3.fromRGB(120, 230, 255),
			B = Color3.fromRGB(200, 205, 220),
		})[grade]
		local badge = text(view.gui, {
			Text = grade,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.71, 0, 0, compact and 104 or 140),
			Size = UDim2.fromOffset(compact and 60 or 84, compact and 60 or 84),
			TextColor3 = gradeColor,
			StrokeThickness = 6,
			ZIndex = 9,
		})
		pop(badge, 3)
	end
	if data.tiebreak or (data.close and not won) then
		local soClose = text(view.gui, {
			Text = data.tiebreak and (won and "YOU PUSHED FURTHER!" or "RIVAL PUSHED FURTHER!") or "SO CLOSE!",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, (compact and 104 or 140) + (compact and 26 or 44)),
			Size = UDim2.fromOffset(360, compact and 26 or 36),
			TextColor3 = won and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 120, 120),
			ZIndex = 8,
		})
		pop(soClose, 1.8)
	end
	local paidPower = (won and data.winPower) or (not won and data.consolation)
	if paidPower then
		local paid = text(view.gui, {
			Text = "+" .. Format.short(paidPower) .. " POWER",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, (compact and 104 or 140) + (compact and 54 or 84)),
			Size = UDim2.fromOffset(260, compact and 26 or 36),
			TextColor3 = Color3.fromRGB(255, 214, 80),
			ZIndex = 8,
		})
		pop(paid, won and 3 or 1.8)
	end
	-- Bottom edge: one dark card.
	local function bottomCard(width, height, edgeColor)
		local card = Instance.new("Frame")
		-- (Bottom-right corner: the camera centres the celebrating fighter.)
		card.AnchorPoint = Vector2.new(1, 1)
		card.Position = UDim2.new(1, compact and -10 or -22, 1, compact and -10 or -22)
		card.Size = UDim2.fromOffset(width, height)
		card.BackgroundColor3 = Color3.fromRGB(26, 22, 44)
		card.BackgroundTransparency = 0.05
		card.ZIndex = 8
		corner(card, UDim.new(0, 18))
		stroke(card, 5, edgeColor)
		card.Parent = view.gui
		UIKit.fitScale(card, 0.8)
		return card
	end
	if won and data.prize.key then
		local fighter = Fighters.ByKey[data.prize.key]
		local rarityColor = Config.Rarities[fighter.rarity].color
		-- The prize card slams in, tilted, with the odds as the headline: the number is the prize.
		local card = bottomCard(560, 168, rarityColor)
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(0.5, 0, 1, compact and -10 or -22)
		card.Rotation = -3
		local pic = Instance.new("Frame")
		pic.BackgroundTransparency = 1
		pic.Position = UDim2.fromOffset(12, 12)
		pic.Size = UDim2.fromOffset(144, 144)
		pic.ZIndex = 9
		pic.Parent = card
		portrait(pic, view.prize).ZIndex = 9
		text(card, {
			RichText = true,
			Text = UIKit.mutationTag(data.prize.mutation) .. string.upper(fighter.display),
			Position = UDim2.fromOffset(168, 10),
			Size = UDim2.new(1, -180, 0, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,
		})
		text(card, {
			Text = data.prize.upgraded and ("S-RANK: " .. string.upper(data.prize.mutation) .. "!")
				or string.upper(data.prize.odds or fighter.rarity),
			Position = UDim2.fromOffset(168, 46),
			Size = UDim2.new(1, -180, 0, 66),
			TextColor3 = data.prize.upgraded and Color3.fromRGB(255, 214, 51) or rarityColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 4,
			ZIndex = 9,
		})
		-- What it earns counts up.
		local income = text(card, {
			Text = "+" .. Format.cash(0) .. "/S",
			Position = UDim2.fromOffset(168, 116),
			Size = UDim2.new(1, -180, 0, 40),
			TextColor3 = Color3.fromRGB(110, 255, 110),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,
		})
		task.spawn(function()
			local total, start = data.prize.income or 0, os.clock()
			while income.Parent and os.clock() - start < 0.7 do
				income.Text = "+" .. Format.cash(math.floor(total * (os.clock() - start) / 0.7)) .. "/S"
				task.wait()
			end
			income.Text = "+" .. Format.cash(total) .. "/S"
		end)
		pop(card, 2.6)
		Cinema.flash(view.overlay, rarityColor, 0.55)
		Cinema.event(view, "bigImpact")
	elseif not won and (view.rivalPower or 0) > (view.myPower or 0) * 1.3 then
		-- Lost to someone stronger: say why, and send them to get stronger.
		local times = (view.rivalPower or 0) / math.max(1, view.myPower or 1)
		local card = bottomCard(520, 84, Color3.fromRGB(255, 150, 60))
		text(card, {
			Text = times >= 2 and ("RIVAL WAS " .. math.floor(times + 0.5) .. "x STRONGER!") or "RIVAL WAS STRONGER!",
			Position = UDim2.fromOffset(18, 12),
			Size = UDim2.new(1, -230, 1, -24),
			TextColor3 = Color3.fromRGB(255, 170, 90),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,
		})
		local train = Instance.new("TextButton")
		train.AnchorPoint = Vector2.new(1, 0.5)
		train.Position = UDim2.new(1, -14, 0.5, 0)
		train.Size = UDim2.fromOffset(190, 58)
		train.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
		train.Font = FONT
		train.TextSize = 30
		train.TextColor3 = Color3.new(1, 1, 1)
		train.Text = "TRAIN!"
		train.ZIndex = 10
		corner(train, UDim.new(0, 16))
		stroke(train, 4)
		train.Parent = card
		train.Activated:Connect(function()
			player:SetAttribute("GoTrain", os.clock()) -- client/ArrowPath.lua points the way to a gym
			close(view.altar)
		end)
		pop(card, 1.2)
	end
end

-- Nothing may hide the fight: any part between the camera and either fighter (or the clash point) fades to
-- see-through for this player while it's in the way, and comes back once it isn't. Trees right by the
-- camera fade too (their leaves don't block rays but would fill the screen).
local CLEAR = 0.85
local function clearView(view, eye)
	view.faded = view.faded or {}
	local hit = {}
	local skip = {}
	for _, m in { view.sides[1].model, view.sides[2].model, player.Character } do
		table.insert(skip, m)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local mid = (view.pads[1].Position + view.pads[2].Position) / 2
	local floor = math.min(view.pads[1].Position.Y, view.pads[2].Position.Y) + 0.5
	-- Both fighters, and points along the beam line from low to chest height: an altar's pillars or a
	-- bench in front of where the beams meet count as in the way, not only walls in front of the fighters.
	local targets = { mid + Vector3.new(0, 6, 0) }
	-- Both fighters' heads and chests too: the result's hero shot looks straight at the winner.
	for _, side in view.sides do
		local head = side.model and side.model:FindFirstChild("Head")
		if head then
			table.insert(targets, head.Position)
			table.insert(targets, head.Position - Vector3.new(0, 2.5, 0))
		end
	end
	for _, k in { 0, 0.25, 0.5, 0.75, 1 } do
		local at = view.pads[1].Position:Lerp(view.pads[2].Position, k)
		for _, h in { 1.5, 3.5 } do
			table.insert(targets, at + Vector3.new(0, h, 0))
		end
	end
	for _, target in targets do
		local ignore = table.clone(skip)
		for _ = 1, 10 do
			params.FilterDescendantsInstances = ignore
			local result = workspace:Raycast(eye, target - eye, params)
			if not result then
				break
			end
			local part = result.Instance
			table.insert(ignore, part)
			-- The ground the fight stands on stays (a low camera grazing the floor isn't "in the way").
			if part:IsA("BasePart") and not part:IsA("Terrain") and result.Position.Y > floor then
				hit[part] = true
			end
		end
	end
	-- The fighter just won, lifted over the winner's head straight away: hidden until the result screen
	-- closes, so it never stands between the camera and the celebration.
	for _, name in { "Held_" .. player.Name, "Stolen_" .. player.Name } do
		local held = workspace:FindFirstChild(name)
		for _, part in held and held:GetDescendants() or {} do
			if part:IsA("BasePart") then
				hit[part] = true
				part.LocalTransparencyModifier = 1
			end
		end
	end
	-- Anything the camera itself sits inside or right against (a ray starting inside a part never hits it).
	local near = OverlapParams.new()
	near.FilterType = Enum.RaycastFilterType.Exclude
	near.FilterDescendantsInstances = skip
	for _, part in workspace:GetPartBoundsInRadius(eye, 3, near) do
		if part.Position.Y > floor and not part:IsA("Terrain") then
			hit[part] = true
		end
	end
	local trees = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Trees")
	for _, p in trees and trees:GetDescendants() or {} do
		if p:IsA("BasePart") and (p.Position - eye).Magnitude < 16 then
			hit[p] = true
		end
	end
	for p in view.faded do
		if not hit[p] then
			p.LocalTransparencyModifier = 0
			view.faded[p] = nil
		end
	end
	for p in hit do
		view.faded[p] = true
		local isHeld = p:FindFirstAncestor("Held_" .. player.Name) or p:FindFirstAncestor("Stolen_" .. player.Name)
		p.LocalTransparencyModifier = isHeld and 1 or CLEAR
	end
end

function close(index)
	local view = views[index]
	if not view then
		return
	end
	views[index] = nil
	for p in view.faded or {} do
		p.LocalTransparencyModifier = 0
	end
	destroyBeams(view)
	if view.gui then
		view.gui:Destroy()
	end
	Cinema.cleanup(view)
	if view == mine then
		UIKit.holdPopups(6) -- (first: pop-ups give the player a moment after the result)
		player:SetAttribute("ClashScreen", nil) -- (client/ClashMode.lua brings the HUD back)
		Cinema.restore()
		Audio.loop("beamLoop", false)
		Audio.battle(nil)
		mine = nil
		ContextActionService:UnbindAction("ClashTap")
		ContextActionService:UnbindAction("ClashUlt")
		-- Hand the camera back from behind the character (the result shot faces them, and the default camera
		-- would otherwise keep looking at their face until they turn it).
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root then
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
			camera.CFrame =
				CFrame.lookAt(root.Position - look * 14 + Vector3.new(0, 6, 0), root.Position + Vector3.new(0, 2, 0))
		end
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
end

local function cometTo(prizeModel, target, color)
	local from = prizeModel and prizeModel.Parent and prizeModel:GetPivot().Position
	if not (from and target) then
		return
	end
	local orb = neon("PrizeComet", Enum.PartType.Ball, color, 0)
	orb.Size = Vector3.one * 2.5
	orb.Position = from
	local trail = Instance.new("Trail")
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.9, 0), Vector3.new(0, -0.9, 0)
	a0.Parent, a1.Parent = orb, orb
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = orb
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min((os.clock() - start) / 0.9, 1)
		local p = from:Lerp(target, k) + Vector3.new(0, math.sin(k * math.pi) * 18, 0)
		orb.Position = p
		if k >= 1 then
			conn:Disconnect()
			orb.Size = Vector3.one * 6
			tween(orb, 0.3, { Transparency = 1, Size = Vector3.one * 10 })
			Debris:AddItem(orb, 0.4)
		end
	end)
end

local function onStart(data)
	close(data.altar)
	local view = {
		altar = data.altar,
		sides = data.sides,
		pads = data.pads,
		prize = data.prize,
		roundsToWin = data.rounds or P.roundsToWin, -- 3 for bosses (best of five)
		challenge = data.challenge, -- a guardian/boss fight: no prize changes hands
		title = data.title,
		startAt = data.startAt,
		endAt = data.endAt,
		phase = "faceoff",
		score = { 0, 0 },
		pending = 0,
		myClicks = 0,
	}
	views[data.altar] = view
	makeBeams(view)
	for side, s in data.sides do
		if not s.bot and s.userId == player.UserId then
			view.mySide = side
		end
	end
	if not view.mySide then
		return
	end
	mine = view
	player:SetAttribute("ClashScreen", true) -- the fight owns the screen until its result closes
	-- The fight's theme: a boss has its own (guardians and drops share the clash theme).
	local boss = data.challenge and data.title and not string.find(data.title, "^GUARDIAN")
	Audio.battle(boss and "Boss" or "Clash")
	local waiting = player.PlayerGui:FindFirstChild("ClashWaiting")
	if waiting then
		waiting:Destroy()
	end
	buildScreen(view)
	camera.CameraType = Enum.CameraType.Scriptable
	view.tap.MouseButton1Down:Connect(function(x, y)
		onTap(view, Vector2.new(x, y))
	end)
	view.tap.TouchTap:Connect(function(positions)
		onTap(view, positions[1] and Vector2.new(positions[1].X, positions[1].Y) or nil)
	end)
	ContextActionService:BindAction("ClashTap", function(_, state)
		if state == Enum.UserInputState.Begin then
			onTap(view, nil)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonA)
	ContextActionService:BindAction("ClashUlt", function(_, state)
		if state == Enum.UserInputState.Begin and view.phase == "battle" then
			remote:FireServer("Ult")
			pop(view.ultButton, 1.3)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonX)
	-- The matchup, one word (Power against Power): EASY / EVEN / HARD / TOO STRONG.
	local myMult, theirMult = data.mult and data.mult[view.mySide] or 1, data.mult and data.mult[3 - view.mySide] or 1
	local word = ClashRules.matchup(myMult, theirMult)
	view.matchupText = ("YOU %s  vs  %s  ·  %s"):format(
		Format.short(data.power and data.power[view.mySide] or 0),
		Format.short(data.power and data.power[3 - view.mySide] or 0),
		word
	)
	view.matchupColor = ({
		EASY = Color3.fromRGB(120, 255, 140),
		EVEN = Color3.fromRGB(255, 226, 70),
		HARD = Color3.fromRGB(255, 150, 60),
		["TOO STRONG"] = Color3.fromRGB(255, 80, 80),
	})[word]
	view.matchupWord = word
	view.rivalPower = data.power and data.power[3 - view.mySide] or 0
	view.myPower = data.power and data.power[view.mySide] or 0
	view.hintLabel.Text = (word == "HARD" or word == "TOO STRONG")
			and ("TIP: TRAIN TO " .. Format.short(view.rivalPower) .. " POWER TO MAKE IT EVEN")
		or ""
	-- The VS card during the face-off: big word, then the fight.
	task.delay(0.1, function()
		if mine == view then
			flashWord(view, word, view.matchupColor, 1.2)
		end
	end)
	sound("roundStart", 0.7, 0.8)
end

local function onState(data)
	local view = views[data.altar]
	if not view then
		return
	end
	view.pos = data.pos
	view.cps, view.comboNow, view.ult = data.cps, data.combo, data.ult
	view.frenzyTaps = data.frenzy
	view.endsAt = data.endsAt
end

local function onEnd(data)
	local view = views[data.altar]
	if not view then
		return
	end
	view.phase = "result"
	view.winner = data.winner
	view.endTime = workspace:GetServerTimeNow()
	view.score = data.scores
	sound("ko", view == mine and 0.9 or 0.4, 1)
	local winnerModel = view.sides[data.winner].model
	local color = data.prize.rarity and Config.Rarities[data.prize.rarity].color or Color3.new(1, 1, 1)
	if not view.challenge or (data.prize.key and view.sides[data.winner] and not view.sides[data.winner].bot) then
		task.delay(0.35, function()
			cometTo(view.prize.model, hands(winnerModel), color)
		end)
	end
	if view == mine then
		Cinema.event(view, "ko")
		Cinema.flash(view.overlay, Color3.new(1, 1, 1), 0.9)
		local loserModel = view.sides[3 - data.winner].model
		local hit = hands(loserModel)
		if hit then
			Cinema.shockwave(hit, Color3.new(1, 1, 1), 40)
			task.delay(0.12, function()
				Cinema.shockwave(hit, SIDE_COLOR[data.winner], 60)
			end)
		end
		local ko = text(view.gui, {
			Text = "K.O.!",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.5, 0.2),
			TextColor3 = Color3.fromRGB(255, 70, 60),
			StrokeThickness = 8,
			ZIndex = 15,
		})
		pop(ko, 3.5)
		task.delay(1.1, function()
			tween(ko, 0.3, { TextTransparency = 1 })
			tween(ko:FindFirstChildOfClass("UIStroke"), 0.3, { Transparency = 1 })
		end)
		view.center.Text = ""
		task.wait(1.15)
		if views[data.altar] ~= view then
			return
		end
		endScreen(view, data)
		if data.winner == view.mySide then
			sound("win", 1, 1)
		else
			sound("lose")
		end
	end
	task.delay(B.result + 2.2, function()
		if views[data.altar] == view then
			close(data.altar)
		end
	end)
end

-- Someone fired their ultimate.
local function onUlt(data)
	local view = views[data.altar]
	if not view then
		return
	end
	view.pos = data.pos
	view.ultFlash = view.ultFlash or {}
	view.ultFlash[data.side] = os.clock()
	if view.ball then
		Cinema.shockwave(view.ball.Position, SIDE_COLOR[data.side], data.stand and 40 or 26)
	end
	if view ~= mine then
		return
	end
	Cinema.event(view, "surge")
	sound("ultFire", 0.9, data.side == view.mySide and 1.2 or 0.9)
	if data.side == view.mySide then
		flashWord(view, data.stand and "COMEBACK!" or "CHARGED ATTACK!", Color3.fromRGB(255, 226, 70), 0.8)
		-- The pips burst and the button flashes; the first one ever is remembered (no more coach line).
		local c = view.charge
		if c then
			for _, pip in c.pips do
				pop(pip, 2.4)
			end
			pop(c.holder, 1.5)
			c.button.BackgroundColor3 = Color3.new(1, 1, 1)
		end
		if not player:GetAttribute("SeenCharge") then
			Net.get("Tutorial"):FireServer("SeenCharge")
		end
		Cinema.flash(view.overlay, SIDE_COLOR[view.mySide], 0.35)
	else
		flashWord(view, data.stand and "THEY FIGHT BACK!" or "INCOMING!", Color3.fromRGB(255, 90, 80), 0.8)
		Cinema.flash(view.overlay, Color3.fromRGB(255, 60, 60), 0.35)
	end
end

-- Two ultimates collided: tap frenzy.
local function onUltClash(data)
	local view = views[data.altar]
	if not view then
		return
	end
	view.pos = data.pos
	view.frenzyUntil = data.endsAt
	if view.ball then
		Cinema.shockwave(view.ball.Position, Color3.new(1, 1, 1), 60)
	end
	if view ~= mine then
		return
	end
	Cinema.event(view, "counter")
	Cinema.flash(view.overlay, Color3.new(1, 1, 1), 0.6)
	flashWord(view, "CLASH!", Color3.fromRGB(255, 255, 255), 0.9)
	sound("clash", 1, 0.7)
end

local function onFrenzy(data)
	local view = views[data.altar]
	if not view then
		return
	end
	view.pos = data.pos
	view.frenzyUntil = nil
	if view ~= mine then
		return
	end
	if data.winner == view.mySide then
		flashWord(view, "YOU WIN THE CLASH!", Color3.fromRGB(120, 255, 140), 1)
		sound("tierUp", 0.9, 1.4)
	elseif data.winner then
		flashWord(view, "OVERPOWERED!", Color3.fromRGB(255, 90, 80), 1)
		sound("lose", 0.8, 0.8)
	end
end

local function onRage(data)
	local view = views[data.altar]
	if view ~= mine then
		return
	end
	view.rageUntil = data.untilT
	flashWord(view, "RAGE!", Color3.fromRGB(255, 50, 50), 1)
	Cinema.flash(view.overlay, Color3.fromRGB(255, 30, 30), 0.5)
	sound("rage", 1, 0.6)
end

local function onRoundStart(data)
	local view = views[data.altar]
	if not view then
		return
	end
	view.phase = "battle"
	view.hintLabel.Text = "" -- (the tip was for before the fight; now it's tapping)
	view.roundHit = nil
	view.pos = 0.5
	view.goAt = data.goAt
	view.endsAt = data.endsAt
	view.frenzyUntil = nil
	view.rounds = data.rounds
	view.blast = data.blast
	if view ~= mine then
		return
	end
	local need = (view.roundsToWin or P.roundsToWin) - 1
	local mineAt, rivalAt = data.rounds[view.mySide], data.rounds[3 - view.mySide]
	local title = data.blast and "ONE BLAST!"
		or (data.final or (mineAt == need and rivalAt == need)) and "FINAL ROUND"
		or (mineAt == need or rivalAt == need) and "MATCH POINT"
		or ("ROUND " .. data.round)
	flashWord(view, title, Color3.fromRGB(255, 255, 255), P.countdown - 0.2)
	task.delay(P.countdown, function()
		if mine == view and view.phase == "battle" then
			flashWord(view, "TAP!", Color3.fromRGB(255, 226, 70), 0.5)
			sound("roundStart", 0.6, 1.3)
			Audio.loop("beamLoop", true)
		end
	end)
end

local function onRound(data)
	local view = views[data.altar]
	if not view then
		return
	end
	if view == mine then
		Audio.loop("beamLoop", false)
	end
	view.roundHit = os.clock()
	view.roundLoser = 3 - data.winner
	view.rounds = data.rounds
	view.pos = data.winner == 1 and 1 or 0
	view.frenzyUntil = nil
	local loserModel = view.sides[view.roundLoser].model
	local hit = hands(loserModel)
	if hit then
		Cinema.shockwave(hit, Color3.new(1, 1, 1), 30)
	end
	if view ~= mine or data.matchOver then
		return
	end
	Cinema.event(view, "bigImpact")
	if data.winner == view.mySide then
		local comeback = data.rounds[view.mySide] == data.rounds[3 - view.mySide]
		flashWord(view, comeback and "COMEBACK!" or "ROUND WON!", Color3.fromRGB(120, 255, 140), 1.4)
		sound("tierUp", 0.8, 1.4)
	else
		Cinema.flash(view.overlay, Color3.fromRGB(255, 60, 60), 0.5)
		flashWord(view, "BLOWN AWAY!", Color3.fromRGB(255, 90, 90), 1.4)
		sound("ko", 0.9, 0.9)
	end
end

local function onSeat(data)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClashWaiting"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local ribbon = Instance.new("Frame")
	ribbon.AnchorPoint = Vector2.new(0.5, 1)
	-- On the bottom edge (the player stands in the middle), smaller on phones.
	ribbon.Position = UDim2.new(0.5, 0, 1, UIKit.compact() and -8 or -20)
	ribbon.Size = UDim2.fromOffset(520, 70)
	ribbon.BackgroundColor3 = Color3.fromRGB(40, 32, 70)
	corner(ribbon, UDim.new(0, 18))
	stroke(ribbon, 5)
	ribbon.Parent = gui
	UIKit.fitScale(ribbon, 0.7)
	local label = text(ribbon, {
		Style = "label",
		TextSize = 20,
		Text = "Waiting for a rival...",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -170, 1, -20),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local leave = Instance.new("TextButton")
	leave.AnchorPoint = Vector2.new(1, 0.5)
	leave.Position = UDim2.new(1, -12, 0.5, 0)
	leave.Size = UDim2.fromOffset(130, 50)
	leave.BackgroundColor3 = Color3.fromRGB(235, 70, 80)
	leave.Font = FONT
	leave.TextSize = 24
	leave.TextColor3 = Color3.new(1, 1, 1)
	leave.Text = "LEAVE"
	corner(leave, UDim.new(0, 14))
	stroke(leave, 4)
	leave.Parent = ribbon
	leave.Activated:Connect(function()
		remote:FireServer("Leave")
		gui:Destroy()
	end)
	local untilT = os.clock() + data.botIn
	task.spawn(function()
		while gui.Parent do
			local left = math.ceil(untilT - os.clock())
			local textNow = left > 0 and ("WAITING FOR A CHALLENGER...  " .. left) or "RIVAL FOUND!"
			if label.Text ~= textNow then
				label.Text = textNow
				pop(ribbon, 1.06)
			end
			task.wait(0.2)
		end
	end)
	pop(ribbon, 0.6)
end

function Clash.start()
	remote = Net.get("Clash")
	remote.OnClientEvent:Connect(function(kind, ...)
		if kind == "Start" then
			onStart(...)
		elseif kind == "State" then
			onState(...)
		elseif kind == "Ult" then
			onUlt(...)
		elseif kind == "UltClash" then
			onUltClash(...)
		elseif kind == "Frenzy" then
			onFrenzy(...)
		elseif kind == "Rage" then
			onRage(...)
		elseif kind == "RoundStart" then
			onRoundStart(...)
		elseif kind == "Round" then
			onRound(...)
		elseif kind == "End" then
			onEnd(...)
		elseif kind == "Seat" then
			onSeat(...)
		end
	end)
	-- Send taps in batches (the server caps the rate anyway).
	task.spawn(function()
		while true do
			task.wait(B.batchInterval)
			if mine and mine.pending > 0 then
				remote:FireServer("Click", mine.pending)
				mine.pending = 0
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local t = workspace:GetServerTimeNow()
		for _, view in views do
			updateWorld(view, dt)
			Cinema.effects(view, t, dt)
		end
		local view = mine
		if not view then
			return
		end
		-- Camera, mood and world effects come from the cinematic director (ClashCinema.lua).
		local _, out = cameraFor(view)
		view.kick = math.max(0, (view.kick or 0) - dt)
		local cf, fov = Cinema.camera(view, t, out)
		clearView(view, cf.Position)
		camera.CFrame = cf
		camera.FieldOfView = fov + (view.kick or 0) * 6
		Cinema.mood(view, t)
		Cinema.updateOverlay(view.overlay, view, t)
		-- Screen.
		-- Tug bar: where the clash point is (far from me = good). It also steers the camera's lean.
		local myFill = math.clamp(view.mySide == 1 and view.shown or 1 - view.shown, 0, 1)
		view.shownShare = (view.shownShare or 0.5) + (myFill - (view.shownShare or 0.5)) * math.min(1, dt * 14)
		view.fill.Size = UDim2.fromScale(view.shownShare, 1)
		view.face.Position = UDim2.fromScale(view.shownShare, 0.5)
		-- Rounds as pips under each name.
		local rounds = view.rounds or { 0, 0 }
		for side = 1, 2 do
			for i, d in view.scoreLabel[side] do
				d.BackgroundColor3 = i <= rounds[side] and SIDE_COLOR[side] or Color3.fromRGB(40, 36, 60)
			end
		end
		if view.phase == "faceoff" then
			local left = math.ceil(view.startAt - t)
			local label = left > 0 and tostring(left) or ""
			if view.center.Text ~= label then
				view.center.Text = label
				pop(view.center, 1.8)
				sound("click", 0.6, 0.7)
			end
		end
		-- Danger glow while I'm being pushed out.
		local myShare = view.mySide == 1 and (view.pos or 0.5) or 1 - (view.pos or 0.5)
		view.danger = math.clamp((0.35 - myShare) / 0.35, 0, 1)
		if view.phase == "battle" then
			local live = t >= (view.goAt or 0)
			local frenzy = view.frenzyUntil and t < view.frenzyUntil
			-- Round clock.
			local left = live and math.max(0, math.ceil((view.endsAt or t) - t)) or nil
			view.timer.Text = left and tostring(left) or ""
			view.timer.BackgroundTransparency = left and 0.25 or 1
			view.timer.TextColor3 = (left and left <= 5) and Color3.fromRGB(255, 90, 80) or Color3.new(1, 1, 1)
			-- One big word for what's happening.
			local word, tint = "", Color3.new(1, 1, 1)
			if frenzy then
				local taps = view.frenzyTaps or { 0, 0 }
				word = ("TAP TAP TAP!  %d - %d"):format(taps[view.mySide], taps[3 - view.mySide])
				tint = Color3.fromRGB(255, 226, 70)
			elseif view.rageUntil and t < view.rageUntil then
				word, tint = "BOSS RAGE! HOLD ON!", Color3.fromRGB(255, 60, 60)
			elseif live then
				local cps = view.cps or { 0, 0 }
				if cps[view.mySide] < 1 then
					word = UIKit.touch() and "TAP TO PUSH!" or "CLICK OR SPACE TO PUSH!"
					tint = Color3.fromRGB(255, 226, 70)
				end
			end
			view.push.Text = word
			view.push.TextColor3 = tint
			-- Combo: fire around the screen edge as it builds (no numbers to read).
			local combo = view.comboNow and view.comboNow[view.mySide] or 1
			view.combo.Text = combo >= 1.5 and "BLAZING!" or combo >= 1.25 and "ON FIRE!" or ""
			view.combo.TextColor3 = combo >= 1.5 and Color3.fromRGB(255, 90, 40) or Color3.fromRGB(255, 196, 40)
			-- CHARGED ATTACK: pips light as it charges; full = gold, rays, PRESS E; red x2 in Last Stand.
			local c = view.charge
			local charge = view.ult and view.ult[view.mySide] or 0
			local ready = charge >= 1
			local stand = myShare <= P.lastStand + 0.05
			local lit = math.clamp(math.floor(charge * 12 + 1e-6), 0, 12)
			local hot = (ready and stand) and Color3.fromRGB(255, 70, 60) or Color3.fromRGB(255, 210, 60)
			for i, pip in c.pips do
				local on = i <= lit
				pip.BackgroundColor3 = ready and hot or on and SIDE_COLOR[view.mySide] or Color3.fromRGB(40, 36, 60)
			end
			if lit > c.lit and not ready then
				sound("click", 0.35, 1 + lit * 0.06)
				pop(c.pips[lit], 1.8)
			end
			if ready and c.lit < 12 then
				sound("ultCharge", 0.8, 1.7) -- full!
				pop(c.holder, 1.35)
			end
			c.lit = lit
			c.button.BackgroundColor3 = ready and hot:Lerp(Color3.new(0, 0, 0), 0.25) or Color3.fromRGB(42, 36, 72)
			c.edge.Color = ready and Color3.new(1, 1, 1) or INK
			c.label.Text = ready and (stand and "x2 POWER!" or (c.keyboard and "PRESS E!" or "TAP!"))
				or "CHARGED ATTACK"
			c.label.TextColor3 = ready and Color3.fromRGB(255, 240, 120) or Color3.new(1, 1, 1)
			c.rays.Visible = ready
			c.rays.Rotation = (t * 40) % 360
			local s = c.holder:FindFirstChildOfClass("UIScale")
			if s then
				s.Scale = ready and (1 + math.sin(t * 10) * 0.06) or 1
			end
			-- Rival's ultimate is ready: a warning, so I can save mine to answer it.
			-- (Not in the tutorial's fight: that bot never fires it.)
			local ftue = player:GetAttribute("Ftue")
			local rivalReady = ftue ~= 4
				and ftue ~= 5
				and not view.blast
				and view.ult
				and view.ult[3 - view.mySide]
				and view.ult[3 - view.mySide] >= 1
			if rivalReady and live and not frenzy then
				view.matchupLabel.Text = "RIVAL CHARGED ATTACK READY!"
				view.matchupLabel.TextColor3 = Color3.fromRGB(255, 90, 80)
			else
				view.matchupLabel.Text = view.matchupText or ""
				view.matchupLabel.TextColor3 = view.matchupColor or Color3.new(1, 1, 1)
			end
		end
	end)
end

return Clash
