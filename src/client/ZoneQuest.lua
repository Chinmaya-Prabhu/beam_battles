-- The zone quest (server/Services/ZoneService.lua runs the ladder):
--   * the first time a player enters a zone (player attribute NewZone, set by TutorialService) a ZONE QUEST
--     card lists its 5 guardians and the boss: portrait, name, the Power each needs and this player's status;
--     LET'S GO points the guide beam (client/ArrowPath.lua, owner "Quest") at the next one;
--   * while in a zone, a tracker at the top right shows the zone's progress and the one to beat next (tap it
--     to point the beam there); tap the header for the full list (the ZONE QUEST card again).
-- Status comes from Ladder_<Zone> (guardians cleared) and Boss_<Zone>, the same as the guardian labels.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local Format = require(Shared.Format)
local UIKit = require(script.Parent.UIKit)
local ArrowPath = require(script.Parent.ArrowPath)

local ZoneQuest = {}
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 214, 80)
local GREEN = Color3.fromRGB(110, 230, 130)
local RED = Color3.fromRGB(255, 110, 95)
local GRAY = Color3.fromRGB(150, 150, 170)
local INK = Color3.fromRGB(30, 16, 40)
local ARRIVED = 26 -- studs from a station that count as "there"

local hud, rows, header
local card
local target -- the station position the beam points at

-- The station model for `zone`'s rung (6 = the boss arena).
local function station(zone, rung)
	for _, m in CollectionService:GetTagged("Guardian") do
		if m:GetAttribute("Zone") == zone and m:GetAttribute("Rung") == rung then
			return m
		end
	end
	return nil
end

-- The guardian standing in a station (not a spawn on its altar, not its fighting copy).
local function guardianOf(m)
	for _, child in m and m:GetChildren() or {} do
		if child:IsA("Model") and child:GetAttribute("FighterKey") and child.Name ~= "GuardianPrize" then
			if child.Name ~= "ClashBot" then
				return child
			end
		end
	end
	return nil
end

-- One rung's line: key, name, needed Power, and its state for this player:
-- "done", "next" (can fight now), "power" (next, but needs more Power) or "locked".
local function entries(zone)
	local z = Config.Zones[zone]
	local cleared = player:GetAttribute("Ladder_" .. zone) or 0
	local power = player:GetAttribute("Power") or 0
	local list = {}
	for rung = 1, 6 do
		local key = rung == 6 and z.boss.key or z.guardians[rung]
		local need = z.ladderPower and z.ladderPower[rung] or 0
		local done = rung == 6 and player:GetAttribute("Boss_" .. zone) == true or rung < 6 and cleared >= rung
		local open = rung == 6 and cleared >= 5 or rung < 6 and cleared == rung - 1
		local state = done and "done" or open and (power >= need and "next" or "power") or "locked"
		table.insert(list, {
			rung = rung,
			key = key,
			-- "Gojo Satoru (Blindfold Off)" -> "GOJO SATORU": the list has room for the name only.
			name = string.upper(
				(string.gsub(Fighters.ByKey[key] and Fighters.ByKey[key].display or key, "%s*%b()", ""))
			),
			need = need,
			state = state,
		})
	end
	return list
end

local function stateText(e)
	if e.state == "done" then
		return "DEFEATED", GREEN
	elseif e.state == "next" then
		return "CHALLENGE NOW!", GOLD
	elseif e.state == "power" then
		return "NEEDS " .. Format.short(e.need) .. " POWER", RED
	end
	return e.rung == 6 and "BEAT ALL 5 FIRST" or "LOCKED", GRAY
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0, 10)
	c.Parent = parent
end

local function badge(parent, e, size)
	local b = Instance.new("Frame")
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = e.state == "done" and GREEN
		or (e.state == "next" or e.state == "power") and GOLD
		or Color3.fromRGB(90, 90, 110)
	corner(b, UDim.new(1, 0))
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = INK
	s.Parent = b
	b.Parent = parent
	if e.state == "done" then
		local tick = UIKit.tick(b, math.floor(size * 0.7))
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5, 0.5)
	else
		UIKit.text(b, {
			Size = UDim2.fromScale(1, 1),
			Text = e.rung == 6 and "B" or tostring(e.rung),
			StrokeThickness = 2,
		})
	end
	return b
end

-- A head-and-shoulders view of the guardian standing in its station.
local function portrait(parent, zone, rung)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	corner(vp)
	vp.Parent = parent
	local model = guardianOf(station(zone, rung))
	if not model then
		return vp
	end
	local copy = model:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	copy:PivotTo(CFrame.new())
	copy.Parent = vp
	local head = copy:FindFirstChild("Head")
	local focus = head and head.Position or Vector3.zero
	local root = copy:FindFirstChild("HumanoidRootPart")
	local forward = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	local s = copy:GetScale()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame =
		CFrame.lookAt(focus + forward * 3.2 * s + Vector3.new(0, 0.3 * s, 0), focus - Vector3.new(0, 0.6 * s, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

local function pointAt(zone, rung)
	local m = station(zone, rung)
	if not m then
		return
	end
	target = m:GetPivot().Position
	ArrowPath.set("Quest", target)
end

local function nextRung(zone)
	for _, e in entries(zone) do
		if e.state ~= "done" then
			return e.rung
		end
	end
	return nil
end

-- ------------------------------------------------------------------ tracker

local function refresh()
	local zone = player:GetAttribute("Zone")
	local z = zone and Config.Zones[zone]
	-- (Phones: the NEXT card's badge shows the zone's count instead: client/Tutorial.lua.)
	hud.Enabled = z ~= nil and not UIKit.compact()
	if not z then
		return
	end
	local list = entries(zone)
	local done = 0
	for _, e in list do
		done += e.state == "done" and 1 or 0
	end
	header.Text = string.upper(z.title) .. "  " .. done .. "/6"
	for _, r in rows do
		r:Destroy()
	end
	table.clear(rows)
	-- Only the one to beat next (the whole list is one tap away on the header).
	for i, e in list do
		if e.state == "done" or rows[1] then
			continue
		end
		local row = Instance.new("TextButton")
		row.Text = ""
		row.AutoButtonColor = true
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundColor3 = e.state == "next" and Color3.fromRGB(70, 55, 20) or Color3.fromRGB(28, 24, 44)
		row.BackgroundTransparency = 0.15
		corner(row, UDim.new(0, 8))
		row.Parent = hud.Frame
		local b = badge(row, e, 38)
		b.Position = UDim2.fromOffset(6, 6)
		local text, color = stateText(e)
		UIKit.text(row, {
			Position = UDim2.fromOffset(52, 3),
			Size = UDim2.new(1, -58, 0, 24),
			Text = (e.rung == 6 and "BOSS: " or "NEXT: ") .. e.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 2,
			TextColor3 = Color3.new(1, 1, 1),
		})
		UIKit.text(row, {
			Position = UDim2.fromOffset(52, 27),
			Size = UDim2.new(1, -58, 0, 19),
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1.5,
			TextColor3 = color,
		})
		row.Activated:Connect(function()
			pointAt(zone, e.rung)
		end)
		table.insert(rows, row)
	end
end

local function buildHud()
	hud = Instance.new("ScreenGui")
	hud.Name = "ZoneQuestHUD"
	hud.IgnoreGuiInset = true -- the same space as the goals panel it sits under
	hud.ResetOnSpawn = false
	hud.Enabled = false
	hud.Parent = player.PlayerGui
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.AnchorPoint = Vector2.new(1, 0)
	-- Top right, where the hub shows its NEXT target card (client/Tutorial.lua hides that in zones).
	frame.Position = UDim2.new(1, -16, 0, UIKit.compact() and 58 or 64)
	frame.Size = UDim2.fromOffset(300, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.Parent = hud
	UIKit.fitScale(frame)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local head = Instance.new("TextButton")
	head.Text = ""
	head.LayoutOrder = 0
	head.Size = UDim2.new(1, 0, 0, 34)
	head.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
	corner(head, UDim.new(0, 8))
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = head
	head.Parent = frame
	header = UIKit.text(head, { Size = UDim2.new(1, -34, 1, -4), Position = UDim2.fromOffset(8, 2), Text = "" })
	header:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 20
	local more = UIKit.chevron(head, 14)
	more.AnchorPoint = Vector2.new(1, 0.5)
	more.Position = UDim2.new(1, -10, 0.5, 0)
	more.Rotation = -90
	head.Activated:Connect(function()
		local zone = player:GetAttribute("Zone")
		if zone and ZoneQuest.openCard then
			ZoneQuest.openCard(zone)
		end
	end)
	rows = {}
end

-- ------------------------------------------------------------------ the first-visit card

local function showCard(zone)
	local z = Config.Zones[zone]
	if not z then
		return
	end
	if card then
		card:Destroy()
	end
	card = Instance.new("ScreenGui")
	card.Name = "ZoneQuestCard"
	card.ResetOnSpawn = false
	card.DisplayOrder = 20
	card.Parent = player.PlayerGui
	local window, body = UIKit.window(card, string.upper(z.title), Vector2.new(700, 460))
	UIKit.text(body, {
		Style = "body",
		TextSize = 18,
		Size = UDim2.new(1, 0, 0, 26),
		Text = "Beat the 5 guardians in order, then the boss, to open the next zone.",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 34)
	holder.Size = UDim2.new(1, 0, 0, 238)
	holder.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -6, 0, 74)
	grid.CellPadding = UDim2.fromOffset(12, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder
	for i, e in entries(zone) do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.BackgroundColor3 = e.rung == 6 and Color3.fromRGB(80, 26, 34) or Color3.fromRGB(34, 28, 56)
		corner(row)
		row.Parent = holder
		local face = Instance.new("Frame")
		face.BackgroundTransparency = 1
		face.Position = UDim2.fromOffset(8, 5)
		face.Size = UDim2.fromOffset(64, 64)
		face.Parent = row
		portrait(face, zone, e.rung)
		-- The rung number on the portrait's top-left corner (never over the words).
		local b = badge(row, e, 28)
		b.Position = UDim2.fromOffset(2, 2)
		for _, d in b:GetDescendants() do -- (this window draws by global layer: lift the number too)
			if d:IsA("GuiObject") then
				d.ZIndex = 5
			end
		end
		b.ZIndex = 4
		local text, color = stateText(e)
		UIKit.text(row, {
			Style = "heading",
			TextSize = 24,
			Position = UDim2.fromOffset(82, 8),
			Size = UDim2.new(1, -90, 0, 30),
			Text = (e.rung == 6 and "BOSS: " or "") .. e.name,
			TextColor3 = e.rung == 6 and Color3.fromRGB(255, 120, 100) or Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UIKit.text(row, {
			Style = "label",
			TextSize = 18,
			Position = UDim2.fromOffset(82, 40),
			Size = UDim2.new(1, -90, 0, 24),
			Text = e.state == "locked" and ("NEEDS " .. Format.short(e.need) .. " POWER") or text,
			TextColor3 = e.state == "locked" and GRAY or color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local go = UIKit.pill(body, "green", "LET'S GO!", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 282),
		Size = UDim2.fromOffset(220, 54),
	})
	go.Activated:Connect(function()
		window.Visible = false
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible then
			local rung = nextRung(zone)
			if rung and player:GetAttribute("Zone") == zone then
				pointAt(zone, rung)
			end
			card:Destroy()
			card = nil
		end
	end)
	window.Visible = true
end

-- The beam always points at the next guardian while you're in a zone (after a fight's result screen,
-- never over a fight), so after each win the way on is obvious even when it's behind a building.
local pending = 0
local function guide(delay)
	pending += 1
	local mine = pending
	task.delay(delay or 0, function()
		while UIKit.inFight() and mine == pending do
			task.wait(0.5)
		end
		local zone = player:GetAttribute("Zone")
		if mine ~= pending or not (zone and Config.Zones[zone]) then
			return
		end
		local rung = nextRung(zone)
		if rung then
			pointAt(zone, rung)
		else
			target = nil
			ArrowPath.set("Quest", nil)
		end
	end)
end

function ZoneQuest.start()
	ZoneQuest.openCard = showCard
	buildHud()
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		target = nil
		ArrowPath.set("Quest", nil)
		refresh()
		guide(2)
	end)
	player:GetAttributeChangedSignal("NewZone"):Connect(function()
		local zone = player:GetAttribute("NewZone")
		task.delay(3, function() -- after the zone's title card, and never over a fight
			while player:GetAttribute("InClash") do
				task.wait(0.5)
			end
			if player:GetAttribute("Zone") == zone then
				showCard(zone)
			end
		end)
	end)
	player:GetAttributeChangedSignal("Power"):Connect(refresh)
	for name in Config.Zones do
		for _, attr in { "Ladder_" .. name, "Boss_" .. name } do
			player:GetAttributeChangedSignal(attr):Connect(function()
				refresh()
				guide(1)
			end)
		end
	end
	refresh()
	-- Arrived: the beam stops.
	RunService.Heartbeat:Connect(function()
		local root = target and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - target).Magnitude < ARRIVED then
			target = nil
			ArrowPath.set("Quest", nil)
		end
	end)
end

return ZoneQuest
