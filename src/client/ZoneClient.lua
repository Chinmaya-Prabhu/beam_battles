-- The zone layer on the client (server/Services/ZoneService.lua):
--   * entering a zone (player attribute "Zone") slams its title card and blends to its lighting;
--   * zone gates show chains or an open portal from this player's own unlocked zones ("Zones");
--   * every guardian and boss gets a label: its rung, name and this player's status (CLEARED /
--     CHALLENGE / LOCKED) from Ladder_<Zone> and Boss_<Zone>.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local ZoneLighting = require(ReplicatedStorage.Shared.ZoneLighting)
local Format = require(ReplicatedStorage.Shared.Format)

local ZoneClient = {}
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 214, 80)
local GREEN = Color3.fromRGB(120, 255, 150)
local GRAY = Color3.fromRGB(190, 190, 205)

local function tween(inst, time, props, style)
	TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad), props):Play()
end

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 64
	cap.Parent = t
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		t[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(30, 16, 40)
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function titleCard(name)
	local zone = Config.Zones[name]
	local title = zone and zone.title or "SKY DOJO"
	local sub = zone and ("ZONE " .. zone.order) or "THE HUB"
	local gui = player.PlayerGui:FindFirstChild("ZoneTitle")
	if gui then
		gui:Destroy()
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "ZoneTitle"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = player.PlayerGui
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Below the drop banners (Fx, at 0.2) so the two never overlap.
	frame.Position = UDim2.fromScale(0.5, 0.4)
	frame.Size = UDim2.fromScale(0.8, 0.2)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 1.8
	scale.Parent = frame
	local subLabel = label(frame, { Text = sub, TextColor3 = GOLD, Size = UDim2.fromScale(1, 0.3) })
	local main = label(frame, { Text = title, Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.7) })
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		for _, t in { subLabel, main } do
			tween(t, 0.6, { TextTransparency = 1 })
			tween(t:FindFirstChildOfClass("UIStroke"), 0.6, { Transparency = 1 })
		end
		task.wait(0.7)
		gui:Destroy()
	end)
end

local function unlockedZones()
	local set = {}
	for name in string.gmatch(player:GetAttribute("Zones") or "", "[^,]+") do
		set[name] = true
	end
	return set
end

local function refreshGates()
	local open = unlockedZones()
	for _, gate in CollectionService:GetTagged("ZoneGate") do
		local isOpen = open[gate:GetAttribute("Zone")] == true
		local chains, sheet = gate:FindFirstChild("Chains"), gate:FindFirstChild("Sheet")
		for _, p in chains and chains:GetDescendants() or {} do
			if p:IsA("BasePart") then
				p.Transparency = isOpen and 1 or 0
			end
		end
		for _, p in sheet and sheet:GetDescendants() or {} do
			if p:IsA("BasePart") then
				p:SetAttribute("Base", isOpen and 0.7 or 1)
				p.Transparency = isOpen and 0.7 or 1
			elseif p:IsA("ParticleEmitter") then
				p.Enabled = isOpen
			end
		end
	end
end

-- Guardian labels.
local labels = {} -- [model] = { status, name }

local RED = Color3.fromRGB(255, 120, 100)

-- "CHALLENGE", or the Power it still needs (Config.Zones[zone].ladderPower).
local function ready(zone, rung)
	local need = Config.Zones[zone] and Config.Zones[zone].ladderPower and Config.Zones[zone].ladderPower[rung]
	if need and (player:GetAttribute("Power") or 0) < need then
		return "NEEDS " .. Format.short(need) .. " POWER", RED
	end
	return "CHALLENGE", GOLD
end

local function status(model)
	local zone, rung = model:GetAttribute("Zone"), model:GetAttribute("Rung")
	local cleared = player:GetAttribute("Ladder_" .. zone) or 0
	-- A fighter hovering over this guardian (a guardian spawn): say what you can win, if you can fight it.
	local prize, prizeRarity = model:GetAttribute("PrizeName"), model:GetAttribute("PrizeRarity")
	local canFight = rung == 6 and cleared >= 5 or rung ~= 6 and cleared >= rung - 1
	if prize and canFight then
		local text, color = ready(zone, rung)
		if text == "CHALLENGE" then
			local rarity = Config.Rarities[prizeRarity]
			return "WIN: " .. string.upper(prize), rarity and rarity.color or GOLD
		end
		return text, color
	end
	if rung == 6 then
		if player:GetAttribute("Boss_" .. zone) then
			return "DEFEATED", GREEN
		end
		if cleared >= 5 then
			return ready(zone, 6)
		end
		return "BEAT ALL 5 GUARDIANS", GRAY
	end
	if cleared >= rung then
		return "CLEARED", GREEN
	end
	if cleared == rung - 1 then
		return ready(zone, rung)
	end
	return "LOCKED", GRAY
end

local function refreshLabels()
	for model, l in labels do
		if not model.Parent then
			labels[model] = nil
			continue
		end
		local text, color = status(model)
		l.status.Text = text
		l.status.TextColor3 = color
	end
end

local function addLabel(model)
	if labels[model] then
		return
	end
	-- Hang it over the guardian (the fighter model inside the station), or the station itself.
	local fighter
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("FighterKey") and child.Name ~= "GuardianPrize" then
			fighter = child
		end
	end
	local adornee = fighter and (fighter.PrimaryPart or fighter:FindFirstChildWhichIsA("BasePart"))
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not adornee then
		return
	end
	local boss = model:GetAttribute("Rung") == 6
	local gui = Instance.new("BillboardGui")
	gui.Name = "GuardianLabel"
	-- Sized in studs so far labels shrink instead of piling up over the near ones.
	gui.Size = boss and UDim2.fromScale(15, 6) or UDim2.fromScale(10, 4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, boss and 13 or 5.5, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = model
	label(gui, {
		Text = boss and "BOSS" or ("GUARDIAN " .. model:GetAttribute("Rung")),
		TextColor3 = boss and Color3.fromRGB(255, 90, 80) or GOLD,
		Size = UDim2.fromScale(1, 0.3),
	})
	label(gui, {
		Text = string.upper(model:GetAttribute("Guardian") or ""),
		Position = UDim2.fromScale(0, 0.3),
		Size = UDim2.fromScale(1, 0.38),
	})
	local s = label(gui, { Text = "", Position = UDim2.fromScale(0, 0.7), Size = UDim2.fromScale(1, 0.3) })
	labels[model] = { status = s }
	model:GetAttributeChangedSignal("PrizeName"):Connect(refreshLabels)
	refreshLabels()
end

function ZoneClient.start()
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		local zone = player:GetAttribute("Zone")
		ZoneLighting.apply(zone, 2)
		if zone and zone ~= "Hub" then
			titleCard(zone) -- (going home to the hub needs no title over the screen)
		end
	end)
	-- After a gate trip the camera still looks the way it did before (out of the gate, toward the void):
	-- put it behind the character, facing into the zone, so W walks in, not off the edge.
	player:GetAttributeChangedSignal("Arrived"):Connect(function()
		task.wait()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if root and camera.CameraType == Enum.CameraType.Custom then
			local back = root.CFrame * CFrame.new(0, 6, 14)
			camera.CFrame = CFrame.lookAt(back.Position, root.Position + root.CFrame.LookVector * 10)
		end
	end)
	player:GetAttributeChangedSignal("Zones"):Connect(refreshGates)
	for name in Config.Zones do
		player:GetAttributeChangedSignal("Ladder_" .. name):Connect(refreshLabels)
		player:GetAttributeChangedSignal("Boss_" .. name):Connect(refreshLabels)
		player:GetAttributeChangedSignal("Power"):Connect(refreshLabels)
	end
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(refreshGates)
	refreshGates()
	for _, model in CollectionService:GetTagged("Guardian") do
		task.spawn(addLabel, model)
	end
	CollectionService:GetInstanceAddedSignal("Guardian"):Connect(function(model)
		task.wait(1) -- let the guardian's fighter model replicate in
		addLabel(model)
	end)
end

return ZoneClient
