-- The EVENTS window (server/Services/LiveOpsService.lua): the QUESTS tile in the menu's free column opens it
-- (a dot counts the quests ready to claim).
--   * this week's event: its name in its colour, what it does, when it ends, its limited fighters,
--   * what's coming next, and the developer's announcement (remote config),
--   * the weekly quests (reset every Monday) with progress bars and CLAIM, and the weekly chest
--     (a Legendary fighter) once all 5 are claimed.
-- Also: a banner the first time an event is seen this session is handled by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveOps = require(Shared.LiveOps)
local Fighters = require(Shared.Fighters)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local EventsPanel = {}
local player = Players.LocalPlayer
local window, ui = nil, {}

local function countdown(s)
	s = math.max(0, math.floor(s))
	local d, h, m = s // 86400, s % 86400 // 3600, s % 3600 // 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm %ds", m, s % 60)
end

local function build(gui)
	local body
	window, body = UIKit.window(gui, "QUESTS & EVENTS", Vector2.new(640, 880))
	-- The event card.
	local card = Instance.new("Frame")
	-- (Below the weekly quests: the QUESTS tile opens this, so the quests come first.)
	card.Position = UDim2.fromOffset(0, 480)
	card.Size = UDim2.new(1, 0, 0, 132)
	card.BackgroundColor3 = Color3.fromRGB(34, 28, 56)
	card.Parent = body
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Thickness = 4
	edge.Parent = card
	ui.card, ui.edge = card, edge
	ui.title = UIKit.text(card, {
		Style = "title",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -200, 0, 34),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	ui.ends = UIKit.text(card, {
		Style = "label",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(180, 22),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 130, 120),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	ui.desc = UIKit.text(card, {
		Style = "label",
		TextSize = 17,
		Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(1, -32, 0, 22),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	ui.fighters = UIKit.text(card, {
		Style = "small",
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 0, 34),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 225, 120),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	ui.next = UIKit.text(body, {
		Style = "body",
		Position = UDim2.fromOffset(4, 620),
		Size = UDim2.new(1, -8, 0, 20),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	ui.announcement = UIKit.text(body, {
		Style = "body",
		Position = UDim2.fromOffset(4, 642),
		Size = UDim2.new(1, -8, 0, 20),
		Text = "",
		TextColor3 = Color3.fromRGB(200, 110, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- Goals (the player's own next steps, server TutorialService "Goals"): first, they're what to do now.
	UIKit.text(body, {
		Style = "heading",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -8, 0, 26),
		Text = "YOUR GOALS",
		TextColor3 = UIKit.GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	ui.goals = {}
	for i = 1, 3 do
		local row = Instance.new("ImageLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, 32 + (i - 1) * 52)
		row.Size = UDim2.new(1, 0, 0, 46)
		UIKit.skin(row, "card", 0.16)
		row.Parent = body
		local text = UIKit.text(row, {
			Style = "body",
			TextSize = 17,
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -250, 0, 22),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local reward = UIKit.text(row, {
			Style = "label",
			TextSize = 17,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -160, 0.5, 0),
			Size = UDim2.fromOffset(80, 24),
			Text = "",
			TextColor3 = Color3.fromRGB(70, 170, 90),
			TextXAlignment = Enum.TextXAlignment.Right,
			StrokeThickness = 0,
		})
		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(12, 30)
		track.Size = UDim2.new(1, -250, 0, 9)
		track.BackgroundColor3 = Color3.fromRGB(210, 205, 195)
		track.Parent = row
		Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(90, 200, 110)
		fill.Parent = track
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
		local _, count = UIKit.pill(row, "gold", "", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(140, 38),
		})
		ui.goals[i] = { row = row, text = text, reward = reward, fill = fill, count = count }
	end
	-- Weekly quests.
	UIKit.text(body, {
		Style = "heading",
		Position = UDim2.fromOffset(4, 200),
		Size = UDim2.new(1, -200, 0, 26),
		Text = "WEEKLY QUESTS",
		TextColor3 = UIKit.GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	ui.reset = UIKit.text(body, {
		Style = "small",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 206),
		Size = UDim2.fromOffset(200, 18),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	ui.rows = {}
	for i = 1, LiveOps.QuestsPerWeek do
		local row = Instance.new("ImageLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, 232 + (i - 1) * 46)
		row.Size = UDim2.new(1, 0, 0, 40)
		UIKit.skin(row, "card", 0.16)
		row.Parent = body
		local text = UIKit.text(row, {
			Style = "body",
			Position = UDim2.fromOffset(12, 3),
			Size = UDim2.new(1, -170, 0, 18),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local track = Instance.new("Frame")
		track.Position = UDim2.fromOffset(12, 23)
		track.Size = UDim2.new(1, -170, 0, 9)
		track.BackgroundColor3 = Color3.fromRGB(210, 205, 195)
		track.Parent = row
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1, 0)
		tc.Parent = track
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(90, 200, 110)
		fill.Parent = track
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = fill
		local button, label = UIKit.pill(row, "grey", "", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(140, 34),
		})
		local r = { text = text, fill = fill, button = button, label = label, color = "grey" }
		button.Activated:Connect(function()
			if r.ready and r.id then
				Net.get("Rewards"):FireServer("Weekly", r.id)
			end
		end)
		ui.rows[i] = r
	end
	local chest, chestLabel = UIKit.pill(body, "grey", "", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(360, 44),
	})
	ui.chest, ui.chestLabel, ui.chestColor = chest, chestLabel, "grey"
	chest.Activated:Connect(function()
		if ui.chestReady then
			Net.get("Rewards"):FireServer("WeeklyChest")
		end
	end)
end

local function setPill(r, text, color, button, label, key)
	label.Text = text
	if r[key] ~= color then
		r[key] = color
		UIKit.setPill(button, color)
	end
end

local function refresh()
	local now = os.time()
	-- Goals.
	local okGoals, goals = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Goals") or "[]")
	goals = okGoals and goals or {}
	for i, r in ui.goals do
		local g = goals[i]
		r.row.Visible = g ~= nil
		if g then
			r.text.Text = g.t
			r.reward.Text = g.r or ""
			r.fill.Size = UDim2.fromScale(math.clamp(g.have / g.need, 0, 1), 1)
			r.count.Text = Format.short(math.min(g.have, g.need)) .. " / " .. Format.short(g.need)
		end
	end
	local key = ReplicatedStorage:GetAttribute("LiveEvent")
	local event = key and LiveOps.Events[key]
	if event then
		ui.title.Text = string.upper(event.title)
		ui.title.TextColor3 = event.color
		ui.edge.Color = event.color
		ui.desc.Text = event.desc
		ui.ends.Text = "Ends in " .. countdown((ReplicatedStorage:GetAttribute("LiveEventEnds") or now) - now)
		local names = {}
		for _, k in event.fighters or {} do
			local f = Fighters.ByKey[k]
			if f then
				table.insert(names, f.display)
			end
		end
		ui.fighters.Text = #names > 0 and ("Limited fighters: " .. table.concat(names, ", ")) or ""
	else
		ui.title.Text = "NO EVENT RIGHT NOW"
		ui.title.TextColor3 = Color3.new(1, 1, 1)
		ui.edge.Color = Color3.fromRGB(90, 90, 110)
		ui.desc.Text = "Check back soon. Events run every week."
		ui.ends.Text, ui.fighters.Text = "", ""
	end
	local nextKey, nextAt = ReplicatedStorage:GetAttribute("NextEvent"), ReplicatedStorage:GetAttribute("NextEventAt")
	ui.next.Text = (nextKey and LiveOps.Events[nextKey] and nextAt)
			and ("Coming up: " .. LiveOps.Events[nextKey].title .. " in " .. countdown(nextAt - now))
		or ""
	ui.announcement.Text = ReplicatedStorage:GetAttribute("Announcement") or ""
	-- Weekly quests.
	local week = LiveOps.week(now)
	ui.reset.Text = "Resets in " .. countdown(LiveOps.weekStart(week + 1) - now)
	local ok, w = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Weekly") or "{}")
	local quests = ok and w.quests or {}
	for i, r in ui.rows do
		local q = quests[i]
		r.id = q and q.id
		r.ready = q and not q.claimed and q.have >= q.need
		if q then
			r.text.Text = q.text
			r.fill.Size = UDim2.fromScale(math.clamp(q.have / q.need, 0, 1), 1)
			if q.claimed then
				setPill(r, "CLAIMED", "grey", r.button, r.label, "color")
			elseif r.ready then
				setPill(r, "CLAIM!", "green", r.button, r.label, "color")
			else
				setPill(
					r,
					Format.short(math.min(q.have, q.need)) .. " / " .. Format.short(q.need),
					"gold",
					r.button,
					r.label,
					"color"
				)
			end
		end
	end
	local chest = ok and w.chest or "locked"
	ui.chestReady = chest == "ready"
	setPill(
		ui,
		chest == "claimed" and "WEEKLY CHEST CLAIMED"
			or chest == "ready" and "OPEN WEEKLY CHEST: LEGENDARY!"
			or "FINISH ALL 5 FOR A LEGENDARY",
		chest == "ready" and "green" or chest == "claimed" and "grey" or "gold",
		ui.chest,
		ui.chestLabel,
		"chestColor"
	)
end

-- How many weekly quests (or the chest) can be claimed now.
function EventsPanel.claimable()
	local ok, w = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Weekly") or "{}")
	if not ok then
		return 0
	end
	local n = w.chest == "ready" and 1 or 0
	for _, q in w.quests or {} do
		if not q.claimed and q.have >= q.need then
			n += 1
		end
	end
	return n
end

function EventsPanel.open()
	window.Visible = true
	refresh()
end

function EventsPanel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EventsPanelGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")
	build(gui)
	local tile = UIKit.tile(UIKit.menu("free"), "clock", "QUESTS", { LayoutOrder = 3 })
	tile:SetAttribute("AfterTutorial", true) -- (UIKit.menu shows it once the tutorial is done)
	local dot = UIKit.dot(tile)
	tile.Activated:Connect(function()
		if window.Visible then
			window.Visible = false
		else
			EventsPanel.open()
		end
	end)
	task.spawn(function()
		while true do
			if window.Visible then
				refresh()
			end
			local n = EventsPanel.claimable()
			dot.Visible = n > 0
			dot.Count.Text = n > 0 and tostring(n) or ""
			task.wait(1)
		end
	end)
end

return EventsPanel
