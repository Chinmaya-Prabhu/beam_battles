-- Client-side spectacle for server cues. Everything here is cosmetic; the server already decided.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Fx = {}
local camera = workspace.CurrentCamera
local shakeUntil, shakeStrength = 0, 0

local function neon(size, cf, color, transparency)
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
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = workspace
	return p
end

local function tween(inst, time, props, style)
	local t =
		TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function Fx.shake(strength, duration)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

-- Banners show one at a time, high in the middle, under any open window (never printed across one); more
-- arriving wait their turn (at most 3 waiting: older news is dropped).
local queue = {}
local showing = false
-- (Phones: low, between the thumbstick and the jump button, above the carry line; the middle is the
-- player's, with their prompts.)
local TOP = workspace.CurrentCamera.ViewportSize.Y < 560 and 0.78 or 0.22

local function show(text, color)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = gui:FindFirstChild("Banners") or Instance.new("ScreenGui")
	screen.Name = "Banners"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 8 -- (windows are 9 and up)
	screen.Parent = gui
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	-- During the tutorial the coach line owns the bottom of the screen: banners go up top, never over it.
	local coaching = (Players.LocalPlayer:GetAttribute("Ftue") or 99) < 99
	label.Position = UDim2.fromScale(0.5, coaching and 0.22 or TOP)
	label.Size = UDim2.fromScale(0.6, 0.06)
	local cap = Instance.new("UITextSizeConstraint") -- readable on phones, never huge on big screens
	cap.MaxTextSize = 36
	cap.MinTextSize = 18
	cap.Parent = label
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = require(script.Parent.UIKit).device(text)
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(30, 16, 40)
	local scale = Instance.new("UIScale")
	scale.Scale = 1.4
	scale.Parent = label
	label.Parent = screen
	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.9, function()
		tween(label, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(label, 2.3)
end

local function pump()
	if showing then
		return
	end
	local nextOne = table.remove(queue, 1)
	if not nextOne then
		return
	end
	showing = true
	show(nextOne[1], nextOne[2])
	task.delay(2.2, function()
		showing = false
		pump()
	end)
end

local function banner(text, color)
	if require(script.Parent.UIKit).inFight() then
		return -- the fight owns the screen (client/ClashMode.lua)
	end
	for _, q in queue do
		if q[1] == text then
			return -- (already waiting)
		end
	end
	table.insert(queue, { text, color })
	while #queue > 3 do
		table.remove(queue, 1)
	end
	pump()
end

-- The portal fires a pillar of light down onto the altar, then a shockwave ring blasts outward.
function Fx.drop(data)
	local info = Config.Rarities[data.rarity]
	local color = info.color
	local top = data.from or Vector3.new(0, Config.Island.portal.height, 0)
	local target = data.position
	local length = (top - target).Magnitude
	local mid = (top + target) / 2
	local beam =
		neon(Vector3.new(length, 1, 1), CFrame.lookAt(mid, target) * CFrame.Angles(0, math.pi / 2, 0), color, 0.1)
	beam.Shape = Enum.PartType.Cylinder
	local width = 4 + table.find(Config.RarityOrder, data.rarity) * 1.2
	tween(beam, 0.25, { Size = Vector3.new(length, width, width) })
	task.delay(Config.Drops.landDelay, function()
		tween(beam, 0.6, { Size = Vector3.new(length, 0.2, 0.2), Transparency = 1 })
		Debris:AddItem(beam, 0.7)
		local ring = neon(
			Vector3.new(0.4, 4, 4),
			CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			0.2
		)
		ring.Shape = Enum.PartType.Cylinder
		tween(ring, 0.6, { Size = Vector3.new(0.2, 46, 46), Transparency = 1 })
		Debris:AddItem(ring, 0.7)
		local flash = neon(Vector3.new(8, 8, 8), CFrame.new(target + Vector3.new(0, 4, 0)), Color3.new(1, 1, 1), 0)
		flash.Shape = Enum.PartType.Ball
		tween(flash, 0.35, { Size = Vector3.new(20, 20, 20), Transparency = 1 })
		Debris:AddItem(flash, 0.4)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - target).Magnitude
			if distance < 90 then
				Fx.shake(0.6 * (1 - distance / 90), 0.4)
			end
		end
	end)
	-- Big drops are called out widely (the rush); Epic and Legendary only to players near that altar, so
	-- drops in other zones don't flood the screen.
	local rank = table.find(Config.RarityOrder, data.rarity)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local near = root and (root.Position - target).Magnitude < 160
	-- Secrets reach the whole server; Mythics only players in the same place (a zone or the hub: within
	-- 400 studs); a new player in the tutorial only hears about drops right next to them.
	local player = Players.LocalPlayer
	local learning = (player:GetAttribute("Ftue") or 99) < 99
	local sameZone = root and (root.Position - target).Magnitude < 400
	local serverWide = not learning
		and (data.rarity == "Secret" or (data.rarity == "Mythic" and sameZone) or data.summoner ~= nil)
	if rank >= table.find(Config.RarityOrder, "Epic") and (near or serverWide) then
		local prefix = data.mutation ~= "Normal" and (string.upper(data.mutation) .. " ") or ""
		if data.summoner then
			banner(string.upper(data.summoner) .. " SUMMONED " .. prefix .. string.upper(data.display) .. "!", color)
		else
			banner(string.upper(data.rarity) .. " DROP!  " .. prefix .. string.upper(data.display), color)
		end
	end
end

-- A stand opening (FX "StandUnlocked"): a gold pillar of light up out of it, a ring along the ground and
-- coins popping up and falling, with a small shake.
function Fx.standUnlocked(data)
	local at = data.position
	local gold = Color3.fromRGB(255, 210, 60)
	local pillar = neon(
		Vector3.new(30, 1, 1),
		CFrame.new(at + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		gold,
		0.2
	)
	pillar.Shape = Enum.PartType.Cylinder
	tween(pillar, 0.25, { Size = Vector3.new(30, 7, 7) })
	task.delay(0.5, function()
		tween(pillar, 0.6, { Size = Vector3.new(30, 0.2, 0.2), Transparency = 1 })
	end)
	Debris:AddItem(pillar, 1.2)
	local ring = neon(
		Vector3.new(0.4, 4, 4),
		CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		gold,
		0.2
	)
	ring.Shape = Enum.PartType.Cylinder
	tween(ring, 0.6, { Size = Vector3.new(0.2, 28, 28), Transparency = 1 })
	Debris:AddItem(ring, 0.7)
	for _ = 1, 14 do
		local coin = neon(Vector3.new(0.3, 1.4, 1.4), CFrame.new(at + Vector3.new(0, 3, 0)), gold, 0)
		coin.Shape = Enum.PartType.Cylinder
		local out = Vector3.new(math.random(-8, 8), math.random(6, 11), math.random(-8, 8))
		tween(coin, 0.45, { CFrame = CFrame.new(at + out) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) })
		task.delay(0.45, function()
			tween(
				coin,
				0.5,
				{ CFrame = CFrame.new(at + out * Vector3.new(1.3, 0, 1.3)), Transparency = 1 },
				Enum.EasingStyle.Quad
			)
		end)
		Debris:AddItem(coin, 1.1)
	end
	Fx.shake(0.35, 0.3)
end

function Fx.start()
	local remote = Net.get("FX")
	remote.OnClientEvent:Connect(function(kind, data)
		if kind == "Drop" then
			Fx.drop(data)
		elseif kind == "Banner" then
			banner(data.text, data.color or Color3.new(1, 1, 1))
		elseif kind == "StandUnlocked" and type(data) == "table" and data.position then
			Fx.standUnlocked(data)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local left = shakeUntil - os.clock()
		if left > 0 then
			local s = shakeStrength * math.min(1, left * 4)
			camera.CFrame *= CFrame.new(math.noise(os.clock() * 40, 1) * s, math.noise(os.clock() * 40, 2) * s, 0)
		else
			shakeStrength = 0
		end
	end)
end

return Fx
