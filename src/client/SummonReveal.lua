-- The summon reveal (FX "SummonReveal" from MonetizationService, for summons and the Starter Pack's fighter):
-- the shop closes, the screen darkens, and a strip of fighter silhouettes races past a marker, slowing
-- down, rare ones flashing their colours, until it stops on the winner. Then a white flash, the silhouette
-- fills in with full colour over turning rays, and the rarity, name and mutation slam in. The server beams
-- the fighter down onto the player as the reveal ends.
-- Silhouettes are free: a ViewportFrame with black ambient and light draws any model as solid black.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Fancy = require(script.Parent.Fancy)
local Shop = require(script.Parent.Shop)

local SummonReveal = {}
local player = Players.LocalPlayer

local CARD = 150 -- card width in px
local GAP = 12
local COUNT = 34
local WIN = 30 -- the winner's card index
local SPIN = 4.6 -- seconds of spinning
local BLACK = Color3.new(0, 0, 0)

local gui
local busy = false

-- A sound effect by name (shared/Sounds.lua, client/Audio.lua).
local function sound(name, scale, pitch)
	require(script.Parent.Audio).play(name, { scale = scale, pitch = pitch })
end

local function tween(inst, time, props, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- A fighter in a ViewportFrame, framed to fit. Black ambient and light make it a silhouette.
local function portrait(parent, key, silhouette, mutation)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = silhouette and BLACK or Color3.fromRGB(200, 200, 200)
	vp.LightColor = silhouette and BLACK or Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.ZIndex = parent.ZIndex + 1
	vp.Parent = parent
	local model = FighterModels.spawn(key, Vector3.zero, Vector3.new(0, 0, 1), { parent = vp, mutation = mutation })
	if model then
		FighterModels.holdPose(model, Fighters.signature(key)) -- (viewports don't animate: hold the pose)
	end
	-- A viewport's flat white light washes shiny materials (gold metal, ice) out to cream: inside the reveal a
	-- mutation statue is drawn matte, so its true colour shows.
	if mutation and mutation ~= "Normal" then
		for _, p in model and model:GetDescendants() or {} do
			if p:IsA("BasePart") then
				p.MaterialVariant = ""
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0
			end
		end
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local height = 5
	if model then
		local _, size = model:GetBoundingBox()
		height = math.max(size.Y, size.X * 0.8, 1)
	end
	local distance = height / 2 / math.tan(math.rad(15)) * 1.15
	cam.CFrame = CFrame.lookAt(Vector3.new(0, height / 2, distance), Vector3.new(0, height / 2, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

-- The strip's other cards: random fighters, rarer ones over-represented so exciting ones fly past.
local function filler(winRarity)
	local weights = { Common = 2, Uncommon = 3, Rare = 5, Epic = 6, Legendary = 6, Mythic = 4, Secret = 3 }
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = math.random() * total
	local rarity = winRarity
	for _, r in Config.RarityOrder do
		roll -= weights[r]
		if roll <= 0 then
			rarity = r
			break
		end
	end
	local pool = Fighters.ByRarity[rarity] or Fighters.ByRarity[winRarity]
	return pool[math.random(1, #pool)]
end

local function card(strip, i, fighter, silhouette)
	local color = Config.Rarities[fighter.rarity].color
	local c = Instance.new("Frame")
	c.Name = "Card" .. i
	c.Size = UDim2.fromOffset(CARD, 200)
	c.Position = UDim2.fromOffset((i - 1) * (CARD + GAP), 0)
	c.BackgroundColor3 = color
	c.ZIndex = 3
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = c
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(BLACK, 0.45))
	g.Parent = c
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = c
	c.Parent = strip
	local vp = portrait(c, fighter.key, silhouette)
	UIKit.text(c, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 22),
		Text = "?",
		ZIndex = 6,
		StrokeThickness = 2.5,
	})
	return c, vp
end

function SummonReveal.play(data)
	if busy then
		return
	end
	busy = true
	Shop.close()
	UIKit.closeAll()
	local winner = Fighters.ByKey[data.key]
	local info = Config.Rarities[winner.rarity]
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(8, 6, 20)
	root.BackgroundTransparency = 1
	root.ZIndex = 1
	root.Parent = gui
	tween(root, 0.3, { BackgroundTransparency = 0.15 })
	local title = UIKit.text(root, {
		Style = "display",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.12, 0),
		Size = UDim2.fromOffset(700, 60),
		Text = "SUMMONING...",
		ZIndex = 10,
		StrokeThickness = 4,
	})
	Fancy.rainbowText(title)

	-- The window the strip slides through, with a gold marker down the middle.
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.new(1, 0, 0, 230)
	track.BackgroundColor3 = Color3.fromRGB(20, 16, 40)
	track.BackgroundTransparency = 0.2
	track.ClipsDescendants = true
	track.ZIndex = 2
	track.Parent = root
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(COUNT * (CARD + GAP), 200)
	strip.ZIndex = 3
	strip.Parent = track
	local cards = {}
	for i = 1, COUNT do
		local f = i == WIN and winner or filler(winner.rarity)
		cards[i] = { card(strip, i, f, true) }
	end
	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.Size = UDim2.new(0, 6, 1, 0)
	marker.BackgroundColor3 = UIKit.GOLD
	marker.BorderSizePixel = 0
	marker.ZIndex = 8
	marker.Parent = track
	for _, y in { 0, 1 } do
		local tip = UIKit.text(track, {
			AnchorPoint = Vector2.new(0.5, y),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.fromOffset(40, 30),
			Text = y == 0 and "v" or "^",
			TextColor3 = UIKit.GOLD,
			ZIndex = 9,
		})
		tip.Name = "Tip"
	end

	-- Spin: the winner's centre ends on the marker, slightly off so it doesn't look staged.
	local function xFor(index, nudge)
		local width = track.AbsoluteSize.X
		return width / 2 - ((index - 1) * (CARD + GAP) + CARD / 2 + nudge)
	end
	local startX = xFor(3, 0)
	local endX = xFor(WIN, math.random(-CARD * 0.3, CARD * 0.3))
	strip.Position = UDim2.fromOffset(startX, 15)
	local value = Instance.new("NumberValue")
	value.Value = startX
	local lastCard = 0
	local conn = RunService.RenderStepped:Connect(function()
		strip.Position = UDim2.fromOffset(value.Value, 15)
		-- A tick each time a card passes the marker.
		local under = math.floor((track.AbsoluteSize.X / 2 - value.Value) / (CARD + GAP)) + 1
		if under ~= lastCard then
			lastCard = under
			sound("click", 0.5, 1.2) -- each card ticking past
		end
	end)
	tween(value, SPIN, { Value = endX }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out).Completed:Wait()
	conn:Disconnect()
	value:Destroy()

	-- The reveal: flash, the winner fills with colour and steps forward, everything else falls away.
	sound("tierUp", 1)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.ZIndex = 20
	flash.Parent = root
	tween(flash, 0.6, { BackgroundTransparency = 1 })
	track.Visible = false
	title.Text = string.upper(winner.rarity) .. "!"
	title.TextColor3 = info.color
	if winner.rarity ~= "Secret" and winner.rarity ~= "Mythic" then
		local g = title:FindFirstChildOfClass("UIGradient")
		if g then
			g:Destroy()
		end
	end
	local stage = Instance.new("Frame")
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.48)
	stage.Size = UDim2.fromOffset(320, 400)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 4
	stage.Parent = root
	Fancy.rays(stage, info.color, 16)
	local vp = portrait(stage, winner.key, true, data.mutation)
	vp.ZIndex = 6
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = stage
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(0.35)
	tween(vp, 0.6, { Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.new(1, 1, 1) })
	local name = UIKit.text(root, {
		Style = "display",
		TextSize = 40,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.8, 0),
		Size = UDim2.fromOffset(700, 54),
		RichText = true,
		Text = UIKit.mutationTag(data.mutation) .. string.upper(winner.display),
		ZIndex = 10,
		StrokeThickness = 4,
	})
	local nameScale = Instance.new("UIScale")
	nameScale.Scale = 2
	nameScale.Parent = name
	tween(nameScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.text(root, {
		Style = "heading",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.8, 58),
		Size = UDim2.fromOffset(500, 28),
		Text = "IS ON THE WAY TO YOU!",
		TextColor3 = UIKit.GOLD,
		ZIndex = 10,
	})
	for _ = 1, 3 do
		sound("cheer", 0.8)
		task.wait(0.12)
	end
	task.wait(2.2)
	tween(root, 0.4, { BackgroundTransparency = 1 })
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			tween(d, 0.3, { TextTransparency = 1 })
		end
	end
	tween(scale, 0.35, { Scale = 0.05 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.45)
	root:Destroy()
	busy = false
end

function SummonReveal.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "SummonReveal"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind == "SummonReveal" then
			task.spawn(SummonReveal.play, data)
		end
	end)
end

return SummonReveal
