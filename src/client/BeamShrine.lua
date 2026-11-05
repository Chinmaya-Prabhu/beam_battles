-- The Beam Shrine on the client (server/Services/BeamShrineService.lua): each pylon fires its skin's real
-- clash beam (client/ClashBeams.lua) into the orb over the floor, so players see exactly what they'd buy.
-- Over each pylon: the skin's name and price (OWNED / EQUIPPED once bought). The prompts say Buy, Equip or
-- Unequip for this player. Beams only run while the player is near.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BeamSkins = require(Shared.BeamSkins)
local Products = require(Shared.Products)
local ClashBeams = require(script.Parent.ClashBeams)

local BeamShrine = {}
local player = Players.LocalPlayer
local NEAR = 170
local ROBUX = utf8.char(0xE002)

local function plate(model, skin, pass)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShrinePlate"
	gui.Size = UDim2.fromScale(4.6, 2.1)
	gui.StudsOffsetWorldSpace = Vector3.new(0, -0.6, 0) -- on the pylon, under the beams
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = model:FindFirstChild("PromptAnchor")
	gui.Parent = model
	local function line(text, color, y, h)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, y)
		t.Size = UDim2.fromScale(1, h)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = Color3.fromRGB(30, 20, 40)
		t.Parent = gui
		return t
	end
	line(string.upper(pass.name), skin.glow:Lerp(Color3.new(1, 1, 1), 0.35), 0, 0.55)
	return line(ROBUX .. " " .. pass.price, Color3.fromRGB(120, 230, 255), 0.55, 0.45)
end

function BeamShrine.start()
	local map = workspace:WaitForChild("Map", 60)
	local shrine = map and map:WaitForChild("BeamShrine", 60)
	if not shrine then
		return
	end
	local pylons = {}
	for _, model in shrine:GetChildren() do
		local key = model:GetAttribute("Skin")
		local skin = key and BeamSkins.ByKey[key]
		local pass = key and Products.ByKey["Beam" .. key]
		if skin and pass then
			local price = plate(model, skin, pass)
			table.insert(pylons, {
				key = key,
				pass = pass,
				model = model,
				price = price,
				beam = ClashBeams.new(skin.glow, skin, { noImpact = true }),
				phase = #pylons * 0.7,
			})
		end
	end
	-- The orb the beams meet in.
	local orb = Instance.new("Part")
	orb.Name = "ShrineOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch = true, false, false, false
	orb.CastShadow = false
	orb.Color = Color3.fromRGB(255, 250, 230)
	orb.Parent = workspace
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = orb

	local function labels()
		local equipped = player:GetAttribute("BeamSkin")
		for _, p in pylons do
			local owned = player:GetAttribute("Owns_" .. p.pass.key) == true
			p.price.Text = equipped == p.key and "EQUIPPED" or owned and "OWNED" or (ROBUX .. " " .. p.pass.price)
			p.price.TextColor3 = equipped == p.key and Color3.fromRGB(255, 214, 80)
				or owned and Color3.fromRGB(120, 255, 150)
				or Color3.fromRGB(120, 230, 255)
			local prompt = p.model:FindFirstChild("BeamPrompt", true)
			if prompt then
				prompt.ActionText = equipped == p.key and "Unequip"
					or owned and "Equip"
					or ("Buy  ·  " .. ROBUX .. " " .. p.pass.price)
			end
		end
	end
	labels()
	player:GetAttributeChangedSignal("BeamSkin"):Connect(labels)
	for _, p in pylons do
		player:GetAttributeChangedSignal("Owns_" .. p.pass.key):Connect(labels)
	end

	-- One beam at a time (six at once wash into one white blob): each skin fires for SHOW seconds, its name
	-- popping up over the shrine, then the next.
	local SHOW = 3.5
	local nameGui = Instance.new("BillboardGui")
	nameGui.Size = UDim2.fromScale(9, 1.8)
	nameGui.StudsOffsetWorldSpace = Vector3.new(0, -8, 0) -- down at the front of the floor, clear of the sign and pylons
	nameGui.LightInfluence = 0
	nameGui.MaxDistance = 120
	nameGui.Adornee = orb
	nameGui.Parent = orb
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.Font = Enum.Font.LuckiestGuy
	nameLabel.TextScaled = true
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Parent = nameGui
	local shown
	RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local target = shrine:GetAttribute("Orb")
		local near = root and target and (root.Position - target).Magnitude < NEAR
		local t = os.clock()
		local current = #pylons > 0 and math.floor(t / SHOW) % #pylons + 1 or nil
		local into = (t % SHOW) / SHOW -- 0..1 through this skin's turn
		orb.Transparency = near and 0 or 1
		nameGui.Enabled = near and true or false
		if near then
			local p = pylons[current]
			orb.Position = target
			orb.Size = Vector3.one * (1.6 + math.sin(t * 6) * 0.2) * (into < 0.08 and 1.6 or 1)
			orb.Color = p.beam.skin.glow:Lerp(Color3.new(1, 1, 1), 0.4)
			if shown ~= current then
				shown = current
				nameLabel.Text = string.upper(p.pass.name)
				nameLabel.TextColor3 = p.beam.skin.glow:Lerp(Color3.new(1, 1, 1), 0.3)
			end
		end
		for i, p in pylons do
			local from = p.model:GetAttribute("At")
			local on = near and from ~= nil and i == current
			-- It surges in, holds, and fades at the end of its turn.
			local width = 2 * math.clamp(into * 8, 0, 1) * math.clamp((1 - into) * 6, 0, 1)
			p.beam:update(from, target, math.max(width, 0.05), on, t + p.phase, 0)
		end
	end)
end

return BeamShrine
