-- The Bag (server/Services/PlotService.lua bagList): every fighter the player owns, best earners first.
-- Each card shows the fighter, its mutation, what it earns on a stand, its training boost as a follower and
-- where it is (FOLLOWING / ON STAND n / IN BAG). FOLLOW makes it the fighter that walks with you (and sets
-- your training boost); TAKE OUT puts it in your hands to carry to a stand (hold E there to place it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIAtlas = require(Shared:WaitForChild("UIAtlas"))
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local Format = require(Shared.Format)
local Odds = require(Shared.Odds)
local Training = require(Shared.Training)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local Bag = {}
local player = Players.LocalPlayer
local SHOWN = 80 -- cards drawn at once (portraits are 3D views); the rest are counted
local GOLD = Color3.fromRGB(255, 205, 60)
local GREEN = Color3.fromRGB(70, 190, 100)

local window, header, grid

local function portrait(parent, key, mutation, fill)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Position = fill and UDim2.new() or UDim2.fromOffset(4, 34)
	vp.Size = fill and UDim2.fromScale(1, 1) or UDim2.new(1, -8, 0, 116)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.Parent = parent
	local model = FighterModels.spawn(key, Vector3.zero, Vector3.new(0, 0, 1), { parent = vp, mutation = mutation })
	if model then
		FighterModels.holdPose(model, Fighters.signature(key)) -- (viewports don't animate: hold the pose)
	end
	local height = 5
	if model then
		local _, size = model:GetBoundingBox()
		height = math.max(size.Y, size.X * 0.8, 1)
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local distance = height / 2 / math.tan(math.rad(15)) * 1.1
	cam.CFrame = CFrame.lookAt(Vector3.new(0, height / 2, distance), Vector3.new(0, height / 2, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
end

local function card(e, order, champion)
	local fighter = Fighters.ByKey[e.k]
	if not fighter then
		return
	end
	local color = Config.Rarities[fighter.rarity].color
	local follows = e.i == champion
	local c = Instance.new("Frame")
	c.LayoutOrder = order
	c.BackgroundColor3 = color
	Instance.new("UICorner", c).CornerRadius = UDim.new(0, 12)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 140))
	g.Parent = c
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = follows and 4 or 3
	stroke.Color = follows and GOLD or color
	stroke.Parent = c
	c.Parent = grid
	-- Where it is.
	local where = follows and "FOLLOWING" or e.s and ("ON STAND " .. e.s) or "IN BAG"
	local chip = Instance.new("Frame")
	chip.Position = UDim2.fromOffset(6, 5)
	chip.Size = UDim2.new(1, -12, 0, 26)
	chip.BackgroundColor3 = follows and GOLD or e.s and GREEN or Color3.fromRGB(90, 90, 110)
	Instance.new("UICorner", chip).CornerRadius = UDim.new(1, 0)
	chip.Parent = c
	UIKit.text(chip, { Size = UDim2.fromScale(1, 1), Text = where, StrokeThickness = 1.5 })
	portrait(c, e.k, e.m)
	local name = UIKit.text(c, {
		Position = UDim2.fromOffset(6, 152),
		Size = UDim2.new(1, -12, 0, 26),
		RichText = true,
		Text = UIKit.mutationTag(e.m) .. string.upper(fighter.display) .. ((e.r or 0) > 0 and (" +" .. e.r) or ""),
		StrokeThickness = 2.5,
	})
	name:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 22
	-- What it does where: earns on a stand, trains faster as a follower.
	local stats = UIKit.text(c, {
		Position = UDim2.fromOffset(6, 180),
		Size = UDim2.new(1, -12, 0, 24),
		Text = Format.cash(Odds.income(e.k, e.m, e.r)) .. "/S  ·  TRAIN x" .. (math.floor(
			Training.championMult(fighter.rarity, e.m) * 10 + 0.5
		) / 10),
		TextColor3 = Color3.fromRGB(150, 255, 150),
		StrokeThickness = 2,
	})
	stats:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 20
	-- The follower's card offers POSE (you and it strike its signature pose); the others, FOLLOW.
	local follow = UIKit.pill(c, follows and "gold" or "grey", follows and "POSE!" or "FOLLOW", {
		Position = UDim2.fromOffset(5, 212),
		Size = UDim2.new(0.5, -7, 0, 44),
	})
	follow.Activated:Connect(function()
		if not follows then
			Net.get("Plot"):FireServer("Follow", e.i)
		else
			window.Visible = false
			require(script.Parent.Champion).pose()
		end
	end)
	local take = UIKit.pill(c, "green", e.s and "MOVE" or "TAKE OUT", {
		Position = UDim2.new(0.5, 2, 0, 212),
		Size = UDim2.new(0.5, -7, 0, 44),
	})
	take.Activated:Connect(function()
		Net.get("Plot"):FireServer("Take", e.i)
		window.Visible = false
	end)
end

local function refresh()
	local ok, bag = pcall(function()
		return Net.get("Request"):InvokeServer("Bag")
	end)
	if not ok or not bag then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = bag.list
	-- Following first, then stands, then the best earners.
	table.sort(list, function(a, b)
		local fa, fb = a.i == bag.champion, b.i == bag.champion
		if fa ~= fb then
			return fa
		end
		local ia, ib = Odds.income(a.k, a.m, a.r), Odds.income(b.k, b.m, b.r)
		if ia ~= ib then
			return ia > ib
		end
		return a.i < b.i
	end)
	local placed = 0
	for _, e in list do
		placed += e.s and 1 or 0
	end
	header.Text = #list .. (#list == 1 and " FIGHTER" or " FIGHTERS") .. "  ·  " .. placed .. " ON STANDS"
	-- Nothing yet: say how to get one instead of an empty box.
	local empty = grid.Parent:FindFirstChild("Empty")
	if #list == 0 and not empty then
		empty = UIKit.text(grid.Parent, { -- (over the grid, not in it: the grid would size it like a card)
			Name = "Empty",
			Style = "body",
			TextSize = 20,
			Position = UDim2.fromOffset(20, 76),
			Size = UDim2.new(1, -40, 0, 80),
			Text = "No fighters yet!\nWin a fight at a drop altar to get one.",
			TextColor3 = Color3.new(1, 1, 1),
		})
		empty.TextWrapped = true
	end
	if empty then
		empty.Visible = #list == 0
	end
	for order, e in list do
		if order > SHOWN then
			break
		end
		if e.i ~= bag.holding then
			card(e, order, bag.champion)
		end
	end
end

-- Opens the Bag (the HUD's FOLLOWER line, the follower card).
function Bag.open()
	if window then
		window.Visible = true
		refresh()
	end
end

-- The first time a player has a follower (after the tutorial): what it is and where to change it.
local function followerCard()
	local champion = Fighters.ByKey[player:GetAttribute("Champion") or ""]
	if not champion or player:GetAttribute("SeenFollower") then
		return
	end
	local ftue = player:GetAttribute("Ftue")
	if ftue and ftue < 99 then
		return -- later: after the tutorial
	end
	if UIKit.inFight() or UIKit.popupsHeld() then
		task.delay(2, followerCard) -- never over a fight or its result: once it's done
		return
	end
	Net.get("Tutorial"):FireServer("SeenFollower")
	local gui = Instance.new("ScreenGui")
	gui.Name = "FollowerCard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player.PlayerGui
	local win, body = UIKit.window(gui, "YOUR FOLLOWER", Vector2.new(580, 400))
	local face = Instance.new("Frame")
	face.BackgroundColor3 = UIKit.ROW
	face.Size = UDim2.fromOffset(150, 170)
	Instance.new("UICorner", face).CornerRadius = UDim.new(0, 12)
	face.Parent = body
	portrait(face, champion.key, player:GetAttribute("ChampionMutation"), true)
	local mult = player:GetAttribute("ChampionMult") or 1
	UIKit.text(body, {
		Position = UDim2.fromOffset(166, 0),
		Size = UDim2.new(1, -166, 0, 34),
		Text = string.upper(champion.display) .. " FOLLOWS YOU!",
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- Two short lines a kid reads at a glance: what it gives, and the trade-off.
	UIKit.text(body, {
		Style = "heading",
		TextSize = 24,
		Position = UDim2.fromOffset(166, 48),
		Size = UDim2.new(1, -166, 0, 30),
		Text = "TRAINING x" .. (math.floor(mult * 10 + 0.5) / 10) .. " FASTER",
		TextColor3 = Color3.fromRGB(150, 255, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UIKit.text(body, {
		Style = "body",
		TextSize = 19,
		Position = UDim2.fromOffset(166, 90),
		Size = UDim2.new(1, -166, 0, 70),
		Text = "Followers don't earn cash. Put it on a stand to earn instead.",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local bag = UIKit.pill(body, "gold", "OPEN BAG", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0.5, -6, 1, -4),
		Size = UDim2.fromOffset(190, 54),
	})
	local ok = UIKit.pill(body, "green", "GOT IT!", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 6, 1, -4),
		Size = UDim2.fromOffset(190, 54),
	})
	win:GetPropertyChangedSignal("Visible"):Connect(function()
		if not win.Visible then
			gui:Destroy()
		end
	end)
	bag.Activated:Connect(function()
		win.Visible = false
		Bag.open()
	end)
	ok.Activated:Connect(function()
		win.Visible = false
	end)
	win.Visible = true
end

function Bag.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Bag"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")
	local body
	window, body = UIKit.window(gui, "BAG", Vector2.new(720, 600), { scrolls = false })
	header = UIKit.text(body, {
		Style = "heading",
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		StrokeThickness = 0,
	})
	UIKit.text(body, {
		Style = "label",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "ON A STAND: EARNS CASH   ·   FOLLOWING: TRAINS FASTER",
		TextColor3 = UIKit.GOLD,
	})
	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(0, 58)
	grid.Size = UDim2.new(1, 0, 1, -58)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = UIKit.SKY
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = body
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(214, 262)
	gl.CellPadding = UDim2.fromOffset(10, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = grid

	local tile = UIKit.tile(
		UIKit.menu(),
		UIAtlas.has("bag") and "bag" or "fighter",
		"BAG",
		{ LayoutOrder = 2 }
	)
	tile.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refresh()
		end
	end)
	for _, name in { "Champion", "Ftue", "InClash" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			task.delay(1.5, followerCard)
		end)
	end
	task.delay(5, followerCard)
	player:GetAttributeChangedSignal("BagVersion"):Connect(function()
		if window.Visible then
			refresh()
		end
	end)
end

return Bag
