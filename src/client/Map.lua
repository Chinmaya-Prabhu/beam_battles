-- The MAP (server: ZoneService "Zone" remote, "Travel"): a menu tile that opens a card for the hub and every
-- zone in ladder order. An unlocked zone shows its emblem in colour, its name and this player's ladder
-- progress, with TRAVEL to go straight to its arrival. A locked zone is a dark silhouette with a "?" and
-- says which boss opens it. Unlocks come from the player attribute "Zones"; progress from Ladder_<Zone>
-- and Boss_<Zone>. The card for where you are says YOU ARE HERE.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local UIAtlas = require(Shared.UIAtlas)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local Map = {}
local player = Players.LocalPlayer

local ICON = { Hub = "hub", Blossom = "blossom", Ninja = "ninja", Pirate = "pirate", Walled = "walled" }
local COLOR = {
	Hub = Color3.fromRGB(255, 205, 60),
	Blossom = Color3.fromRGB(255, 130, 185),
	Ninja = Color3.fromRGB(255, 140, 30),
	Pirate = Color3.fromRGB(40, 100, 210),
	Walled = Color3.fromRGB(80, 150, 70),
}
local DARK = Color3.fromRGB(28, 26, 40)

local window, row

-- The places in order: the hub, then the zones by `order`.
local function places()
	local list = { "Hub" }
	local zones = {}
	for name, z in Config.Zones do
		table.insert(zones, { name = name, order = z.order or 99 })
	end
	table.sort(zones, function(a, b)
		return a.order < b.order
	end)
	for _, z in zones do
		table.insert(list, z.name)
	end
	return list
end

local function unlockedSet()
	local set = { Hub = true }
	for name in string.gmatch(player:GetAttribute("Zones") or "", "[^,]+") do
		set[name] = true
	end
	return set
end

-- The boss whose defeat opens `name` (the zone whose `next` it is).
local function opener(name)
	for _, z in Config.Zones do
		if z.next == name then
			return z
		end
	end
	return nil
end

-- The zone to head for next: the first open one (in order) whose boss isn't beaten yet.
function Map.nextZone()
	local open = {}
	for z in string.gmatch(player:GetAttribute("Zones") or "", "[^,]+") do
		open[z] = true
	end
	local best
	for name, z in Config.Zones do
		if open[name] and not player:GetAttribute("Boss_" .. name) then
			if not best or z.order < Config.Zones[best].order then
				best = name
			end
		end
	end
	return best
end

local function card(name, order, open)
	local zone = Config.Zones[name]
	local here = (player:GetAttribute("Zone") or "Hub") == name
	local color = COLOR[name] or Color3.new(1, 1, 1)
	local c = Instance.new("Frame")
	c.LayoutOrder = order
	c.BackgroundColor3 = open and color or DARK
	Instance.new("UICorner", c).CornerRadius = UDim.new(0, 14)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 160))
	g.Parent = c
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = here and 4 or 3
	stroke.Color = here and UIKit.GOLD or (open and color:Lerp(Color3.new(0, 0, 0), 0.3) or Color3.fromRGB(70, 70, 90))
	stroke.Parent = c
	c.Parent = row
	-- The emblem: in colour, or a black silhouette under a big "?".
	local icon = UIAtlas.label(c, ICON[name] or "hub", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(88, 88),
		BackgroundTransparency = 1,
	})
	if icon and not open then
		icon.ImageColor3 = Color3.new(0, 0, 0)
		icon.ImageTransparency = 0.15
	end
	if not open then
		UIKit.text(c, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 22),
			Size = UDim2.fromOffset(80, 64),
			Text = "?",
			TextColor3 = Color3.fromRGB(200, 200, 220),
			StrokeThickness = 3,
		})
	end
	UIKit.text(c, {
		Position = UDim2.fromOffset(6, 104),
		Size = UDim2.new(1, -12, 0, 24),
		Text = open and (zone and zone.title or "SKY DOJO HUB") or "???",
		StrokeThickness = 2,
	})
	local line
	if not open then
		local before = opener(name)
		line = before and ("BEAT " .. before.boss.title)
			or zone.unlockPower and ("REACH " .. Format.short(zone.unlockPower) .. " POWER")
			or "LOCKED"
	elseif zone then
		local cleared = player:GetAttribute("Ladder_" .. name) or 0
		local boss = player:GetAttribute("Boss_" .. name) == true
		line = boss and "ZONE CLEARED!" or (cleared .. "/5 GUARDIANS")
	else
		line = "TRAIN · DROPS · BASE"
	end
	local lineLabel = UIKit.text(c, {
		Position = UDim2.fromOffset(6, 130),
		Size = UDim2.new(1, -12, 0, 42),
		Text = line,
		TextColor3 = open and Color3.fromRGB(255, 250, 230) or Color3.fromRGB(200, 200, 220),
		StrokeThickness = 1.5,
	})
	lineLabel.TextWrapped = true -- (two lines rather than tiny letters)
	local cap = lineLabel:FindFirstChildOfClass("UITextSizeConstraint")
	cap.MaxTextSize, cap.MinTextSize = 18, 14
	if open and name == Map.nextZone() and not here then
		-- NEXT!: a gold ribbon over the top and a pulsing gold edge, so the way on is obvious.
		local ribbon = Instance.new("Frame")
		ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
		ribbon.Position = UDim2.new(0.5, 0, 0, 2)
		ribbon.Size = UDim2.fromOffset(96, 28)
		ribbon.BackgroundColor3 = UIKit.GOLD
		ribbon.ZIndex = 5
		ribbon.Parent = c
		Instance.new("UICorner", ribbon).CornerRadius = UDim.new(1, 0)
		UIKit.text(ribbon, { Size = UDim2.fromScale(1, 1), Text = "NEXT!", ZIndex = 6, StrokeThickness = 2 })
		stroke.Color = UIKit.GOLD
		stroke.Thickness = 5
		task.spawn(function()
			while c.Parent do
				stroke.Transparency = 0.5 + 0.5 * math.sin(os.clock() * 5)
				task.wait()
			end
		end)
	end
	if here then
		UIKit.text(c, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -16, 0, 22),
			Text = "YOU ARE HERE",
			TextColor3 = UIKit.GOLD,
			StrokeThickness = 2,
		})
	elseif open then
		local go = UIKit.pill(c, "green", "TRAVEL", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 40),
		})
		go.Activated:Connect(function()
			window.Visible = false
			Net.get("Zone"):FireServer("Travel", name)
		end)
	end
end

local function refresh()
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local open = unlockedSet()
	for i, name in places() do
		card(name, i, open[name] == true)
	end
end

function Map.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MapGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")
	local body
	window, body = UIKit.window(gui, "MAP", Vector2.new(860, 360))
	row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = body
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	row.ChildAdded:Connect(function(c)
		if c:IsA("GuiObject") then
			c.Size = UDim2.new(0.2, -10, 1, 0)
		end
	end)

	-- The MAP tab in the top bar (BASE is client/Training.lua's; the Hub is a stop on the map).
	local tile = UIKit.tab("MAP", "walled", "red", 2)
	tile:SetAttribute("AfterTutorial", true) -- (shown once the tutorial is done)
	tile.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			refresh()
		end
	end)
	-- (The NEXT target card opens it too: client/Tutorial.lua.)
	Map.open = function()
		window.Visible = true
		refresh()
	end
	for _, name in { "Zones", "Zone" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if window.Visible then
				refresh()
			end
		end)
	end
end

return Map
