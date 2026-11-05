-- The Index book (shared/Collection.lua, server/Services/RewardsService.lua): an INDEX tile opens every
-- fighter by series. Owned fighters show in colour with their name; the rest are black silhouettes and
-- "???". Each card has five pips for the mutations found. The left column lists the series with progress
-- (gold when complete); the header shows the total and the cash bonus from completed series (+10% each).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIAtlas = require(Shared:WaitForChild("UIAtlas"))
local Config = require(Shared.Config)
local Collection = require(Shared.Collection)
local LiveOps = require(Shared.LiveOps)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local Index = {}
local player = Players.LocalPlayer
local BLACK = Color3.new(0, 0, 0)

local window, header, list, grid
local book = {} -- [key] = { [mutation] = true }
local seriesButtons = {}
local selected = Collection.Series[1]

-- Limited event fighters (shared/LiveOps.lua) get their own page at the end of the list. They don't count
-- toward series bonuses: they're bragging rights.
local LIMITED = "Limited"
local limitedList = {}
do
	local seen = {}
	for _, key in LiveOps.Order do
		for _, k in LiveOps.Events[key].fighters or {} do
			local f = Fighters.ByKey[k]
			if f and not seen[k] then
				seen[k] = true
				table.insert(limitedList, f)
			end
		end
	end
end
local function fightersOf(series)
	return series == LIMITED and limitedList or Collection.BySeries[series]
end
local seriesOrder = table.clone(Collection.Series)
table.insert(seriesOrder, LIMITED)

local function portrait(parent, key, owned)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Position = UDim2.fromOffset(4, 4)
	vp.Size = UDim2.new(1, -8, 1, -46)
	vp.Ambient = owned and Color3.fromRGB(200, 200, 200) or BLACK
	vp.LightColor = owned and Color3.new(1, 1, 1) or BLACK
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.Parent = parent
	local model = FighterModels.spawn(key, Vector3.zero, Vector3.new(0, 0, 1), { parent = vp })
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

local function showSeries(series)
	selected = series
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, f in fightersOf(series) do
		local owned = book[f.key]
		local color = Config.Rarities[f.rarity].color
		local card = Instance.new("Frame")
		card.LayoutOrder = order
		card.BackgroundColor3 = owned and color or Color3.fromRGB(60, 60, 80)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = card
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 140))
		g.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = color
		stroke.Parent = card
		card.Parent = grid
		portrait(card, f.key, owned)
		-- Name (or ??? until found), then what it is: its rarity, or how many of its mutations you have.
		UIKit.text(card, {
			Style = "label",
			TextSize = 18,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -26),
			Size = UDim2.new(1, -10, 0, 22),
			Text = owned and string.upper(f.display) or "???",
		})
		local total, got = 0, 0
		for _, m in Config.MutationOrder do
			local zone = Config.Mutations[m].zone
			if not zone or zone == f.pool then -- the universal ones and its zone's
				total += 1
				got += (owned and owned[m]) and 1 or 0
			end
		end
		UIKit.text(card, {
			Style = "label",
			TextSize = 15,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -10, 0, 18),
			Text = owned and ("MUTATIONS " .. got .. "/" .. total) or string.upper(f.rarity),
			TextColor3 = owned and Color3.fromRGB(150, 255, 150) or color,
		})
	end
	for s, b in seriesButtons do
		b.BackgroundColor3 = s == series and Color3.fromRGB(70, 140, 255) or UIKit.ROW
	end
end

local function refresh()
	local ok, result = pcall(function()
		return Net.get("Request"):InvokeServer("Index")
	end)
	if ok and type(result) == "table" then
		book = result
	end
	local total, have = 0, 0
	for _, s in seriesOrder do
		local h, t = 0, #fightersOf(s)
		for _, f in fightersOf(s) do
			if book[f.key] then
				h += 1
			end
		end
		if s ~= LIMITED then -- the header counts the launch roster only
			have += h
			total += t
		end
		local b = seriesButtons[s]
		b.Count.Text = h .. "/" .. t
		b.Count.TextColor3 = h == t and UIKit.GOLD or Color3.new(1, 1, 1)
	end
	local bonus = math.floor((Collection.cashMult(book) - 1) * 100 + 0.5)
	header.Text = "COLLECTED " .. have .. "/" .. total .. "   ·   CASH BONUS +" .. bonus .. "%"
	showSeries(selected)
end

function Index.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "IndexGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9 -- windows sit above the HUD and the goals (Tutorial, 8)
	gui.Parent = player:WaitForChild("PlayerGui")
	local body
	window, body = UIKit.window(gui, "INDEX", Vector2.new(840, 600), { scrolls = false })
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
		Text = "FINISH A SERIES: +10% CASH FOREVER",
		TextColor3 = UIKit.GOLD,
	})
	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 60)
	list.Size = UDim2.new(0, 210, 1, -60)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = body
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 6)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = list
	for order, s in seriesOrder do
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(1, -10, 0, 44)
		b.BackgroundColor3 = UIKit.ROW
		b.Text = ""
		b.AutoButtonColor = true
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = b
		local label = UIKit.text(b, {
			Style = "label",
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -70, 1, 0),
			Text = string.upper(Fighters.SeriesNames[s] or s),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label.Name = "Label"
		local count = UIKit.text(b, {
			Style = "label",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.new(0, 56, 1, 0),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		count.Name = "Count"
		b.Parent = list
		b.Activated:Connect(function()
			showSeries(s)
		end)
		seriesButtons[s] = b
	end
	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(220, 60)
	grid.Size = UDim2.new(1, -220, 1, -60)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.ScrollBarImageColor3 = UIKit.SKY
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = body
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(136, 190)
	gl.CellPadding = UDim2.fromOffset(10, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid

	local tile = UIKit.tile(
		UIKit.menu(),
		UIAtlas.has("index") and "index" or "fighter",
		"INDEX",
		{ LayoutOrder = 3 }
	)
	tile.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("IndexCount"):Connect(function()
		if window.Visible then
			refresh()
		end
	end)
end

return Index
