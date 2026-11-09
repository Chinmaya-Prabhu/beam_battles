-- Training on the client (docs/TRAINING_PLAN.md): click or tap anywhere to train, "+N" pops, the Power /
-- Ki HUD with the bar to the next aura tier, and the station and gear prompts' text for this player.
-- The server decides every number (server/Services/TrainingService.lua); the pops show the expected gain.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Training = require(Shared.Training)
local LiveOps = require(Shared.LiveOps)
local UIAtlas = require(Shared.UIAtlas)
local UIKit = require(script.Parent.UIKit)
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Products = require(Shared.Products)

local TrainingClient = {}
local player = Players.LocalPlayer
local remote
local pending = 0
local stamps = {} -- click times in the last second (local cap mirrors the server's)
TrainingClient.onRep = nil -- set by TrainPose: called on every accepted local click

local GOLD = Color3.fromRGB(255, 214, 80)
local KI = Color3.fromRGB(110, 230, 255)
local BEAM = Color3.fromRGB(255, 170, 80)
local INK = Color3.fromRGB(30, 16, 40)

local function tween(inst, time, props, style)
	local t =
		TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Fades a label and its outline together (a bare TextTransparency tween leaves the stroke behind).
local function fade(label, time, extra)
	local props = { TextTransparency = 1 }
	for k, v in extra or {} do
		props[k] = v
	end
	tween(label, time, props)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		tween(stroke, time, { Transparency = 1 })
	end
end

local function text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		t[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = INK
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function stationMult()
	local id = player:GetAttribute("TrainStation")
	if not id then
		return 1
	end
	local def = Training.StationByKey[string.match(id, "^[^#]+")]
	return def and def.mult or 1
end

local function expected()
	return Training.perRep(
		player:GetAttribute("Gear") or 1,
		stationMult(),
		player:GetAttribute("ChampionMult") or 1,
		player:GetAttribute("Rebirths") or 0,
		(player:GetAttribute("TrainBoost") or 1) * (player:GetAttribute("TutorialBoost") or 1) * LiveOps.mult("train"),
		player:GetAttribute("PremiumGear")
	)
end

-- ------------------------------------------------------------------ HUD

local hud = {}
-- Rank emblem per aura tier (tier 0 = no aura yet).

local function buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrainingHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	hud.gui = gui
	-- The player's numbers. Desktop: bottom-left, Cash big with Power, Ki and the per-tap multiplier under it and the bar to the next
	-- aura under those. Phones: one line under Roblox's buttons (Cash, Power, Ki) with the aura bar under it,
	-- clear of the thumbstick. Tap a number for what it's for.
	local compact = UIKit.compact()
	local panel = Instance.new("Frame")
	panel.Name = "Stats"
	panel.BackgroundTransparency = 1
	if compact then
		panel.AnchorPoint = Vector2.zero
		panel.Position = UDim2.fromOffset(16, 58) -- (clear of Roblox's round logo button above)
		panel.Size = UDim2.fromOffset(330, 56)
	else
		panel.AnchorPoint = Vector2.new(0, 1)
		panel.Position = UDim2.new(0, 16, 1, -14)
		panel.Size = UDim2.fromOffset(360, 132)
	end
	panel.Parent = gui
	local scale = UIKit.fitScale(panel, 0.75) -- (smaller on phones: the world comes first)
	hud.panel, hud.scale = panel, scale
	hud.baseScale = scale.Scale
	scale:GetPropertyChangedSignal("Scale"):Connect(function()
		if not hud.bumping then
			hud.baseScale = scale.Scale
		end
	end)
	-- Tap a number for what it's for: a card beside the block for a few seconds.
	local tip = Instance.new("Frame")
	tip.Name = "Tip"
	tip.AnchorPoint = compact and Vector2.zero or Vector2.new(0, 1)
	tip.Position = compact and UDim2.fromOffset(0, 56) or UDim2.new(0, 0, 0, -8)
	tip.Size = UDim2.fromOffset(340, 70)
	tip.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
	tip.BackgroundTransparency = 0.05
	tip.ZIndex = 10
	tip.Visible = false
	Instance.new("UICorner", tip).CornerRadius = UDim.new(0, 12)
	local tipEdge = Instance.new("UIStroke")
	tipEdge.Thickness = 2
	tipEdge.Parent = tip
	tip.Parent = panel
	local tipText = UIKit.text(tip, {
		Style = "body",
		TextSize = 17,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 1, -12),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 11,
	})
	local tipShown = 0
	local function showTip(line, color)
		tipShown += 1
		local mine = tipShown
		if tip.Visible and tipText.Text == line then
			tip.Visible = false -- a second tap closes it
			return
		end
		tipText.Text = line
		tipEdge.Color = color
		tip.Visible = true
		task.delay(5, function()
			if tipShown == mine then
				tip.Visible = false
			end
		end)
	end
	local TIPS = {
		cash = "CASH: your fighters earn it on your base's stands. Spend it on more stands and stations.",
		power = "POWER: train to raise it. Guardians and bosses need it, and beating them opens new zones.",
		ki = "KI: earned by training. Spend it on new weights at the Training Gear stall.",
		smash_charged = "BEAM: how hard every tap hits. Gear, your follower and rebirths multiply it.",
	}
	-- One number with its icon; it grows with the number (never "2.3...").
	local function stat(parent, order, iconName, color, size)
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = order
		cell.Size = UDim2.fromOffset(size, size)
		cell.Parent = parent
		UIAtlas.label(cell, iconName, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(size, size),
		})
		local t = UIKit.text(cell, {
			Style = "number",
			TextSize = math.floor(size * 0.92),
			Position = UDim2.fromOffset(size + 4, 0),
			Size = UDim2.new(0, 0, 1, 0),
			Text = "0",
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 3,
		})
		t.TextScaled = false
		t.TextTruncate = Enum.TextTruncate.None
		-- Sized to its number every time it changes (automatic sizing lagged a frame and cut "22.5K" to
		-- "22.5").
		-- Sized to the rendered text: an invisible copy of the label, always wide, reports the number's real width
		-- (TextBounds, which also catches the font finishing loading), and the label and its cell take it.
		-- (Measuring with TextService ran wide and left big gaps; automatic sizing lagged and cut "22.5K".)
		local probe = t:Clone()
		for _, d in probe:GetChildren() do
			if d:IsA("UIStroke") then
				d.Transparency = 1
			end
		end
		probe.Name = "Probe"
		probe.TextTransparency = 1
		probe.TextStrokeTransparency = 1
		probe.Size = UDim2.new(0, 1000, 1, 0)
		probe.Parent = cell
		local function fit()
			-- (TextBounds is in screen pixels, after the HUD's UIScale; the sizes here are design units.)
			local k = probe.AbsoluteSize.X > 0 and probe.AbsoluteSize.X / 1000 or 1
			local w = math.ceil(probe.TextBounds.X / k) + 6
			t.Size = UDim2.new(0, w, 1, 0)
			cell.Size = UDim2.fromOffset(size + 4 + w, size)
		end
		t:GetPropertyChangedSignal("Text"):Connect(function()
			probe.Text = t.Text
		end)
		probe:GetPropertyChangedSignal("TextBounds"):Connect(fit)
		probe:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
		-- (Not on phones: a thumb heading for the thumbstick kept landing on these instead of steering.)
		if not UIKit.compact() then
			local hit = Instance.new("TextButton")
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 5
			hit.Parent = cell
			hit.Activated:Connect(function()
				showTip(TIPS[iconName], color)
			end)
		end
		return t
	end
	local function line(y, height, padding)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, y)
		row.Size = UDim2.new(1, 0, 0, height)
		row.Parent = panel
		local l = Instance.new("UIListLayout")
		l.FillDirection = Enum.FillDirection.Horizontal
		l.Padding = UDim.new(0, padding)
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = row
		return row
	end
	local barY
	if compact then
		-- One dark pill holds Cash, Power and Ki; the aura bar sits under it.
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Position = UDim2.fromOffset(-8, -3)
		back.Size = UDim2.fromOffset(346, 34)
		back.BackgroundColor3 = Color3.fromRGB(20, 18, 40)
		back.BackgroundTransparency = 0.1
		Instance.new("UICorner", back).CornerRadius = UDim.new(1, 0)
		local backEdge = Instance.new("UIStroke")
		backEdge.Thickness = 2
		backEdge.Color = Color3.fromRGB(90, 80, 140)
		backEdge.Parent = back
		back.Parent = panel
		local row = line(0, 28, 14)
		row.Position = UDim2.fromOffset(4, 0)
		-- The pill (and the aura bar under it) is as wide as its numbers, never narrower, so Ki always fits.
		local rowList = row:FindFirstChildOfClass("UIListLayout")
		hud.fitBack = function()
			-- (In design units: the cells' own widths and the 14 between them, never the scaled on-screen size.)
			local content, count = 0, 0
			for _, cell in row:GetChildren() do
				if cell:IsA("GuiObject") then
					content += cell.Size.X.Offset
					count += 1
				end
			end
			local width = math.max(content + 14 * math.max(count - 1, 0) + 24, 240)
			back.Size = UDim2.fromOffset(width, 34)
			if hud.barFrame then
				hud.barFrame.Size = UDim2.new(0, width - 16, 0, 22)
			end
		end
		rowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			hud.fitBack()
		end)
		-- Three numbers only, a size smaller: on a phone this pill must leave the world visible. (The per-tap
		-- multiplier is desktop only; it lives in the gear window and the stations' plates too.)
		hud.cash = stat(row, 1, "cash", Color3.fromRGB(130, 255, 140), 20)
		hud.power = stat(row, 2, "power", GOLD, 20)
		hud.ki = stat(row, 3, "ki", KI, 20)
		hud.beam = Instance.new("TextLabel") -- (not shown)
		barY = 34
	else
		hud.cash = stat(line(0, 50, 0), 1, "cash", Color3.fromRGB(130, 255, 140), 48)
		local row = line(54, 32, 18)
		hud.power = stat(row, 1, "power", GOLD, 30)
		hud.ki = stat(row, 2, "ki", KI, 30)
		hud.beam = stat(row, 3, "smash_charged", BEAM, 30)
		barY = 94
	end
	-- The one bar: the next thing you can buy ("NEXT: STONE WEIGHTS 72%").
	local bar = Instance.new("ImageLabel")
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.fromOffset(0, barY)
	bar.Size = UDim2.new(0, compact and 300 or 300, 0, compact and 22 or 32)
	UIKit.skin(bar, "bar_track", 0.38)
	bar.Parent = panel
	hud.barFrame = compact and bar or nil
	-- Phones: no bar under the numbers (the shop and stand buttons already say what's ready).
	bar.Visible = not compact
	if hud.fitBack then
		hud.fitBack()
	end
	local fill = Instance.new("ImageLabel")
	fill.BackgroundTransparency = 1
	fill.Size = UDim2.fromScale(0.1, 1)
	UIKit.skin(fill, "bar_fill", 0.38)
	fill.Parent = bar
	hud.fill = fill
	hud.next = UIKit.text(bar, {
		Style = "label",
		TextSize = compact and 15 or 18,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -4),
		Text = "",
		ZIndex = 3,
	})
	-- A friend boost shows as one tag (desktop: above the cash; phones: none, too tight).
	hud.boostTag = UIKit.text(panel, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(4, -4),
		Size = UDim2.fromOffset(260, 22),
		Text = "",
		TextColor3 = Color3.fromRGB(120, 255, 150),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
		Visible = not compact,
	})
	hud.gear = { Text = "" } -- (the per-click line lives in the Bag now)
	-- BASE is the first travel tab (UIKit.tab: BASE, HUB, MAP).
	local home = UIKit.tab("BASE", "base", "green", 1)
	home.Activated:Connect(function()
		Net.get("Plot"):FireServer("Home")
	end)
end

local lastPower = -1
local lastBeam

-- The nearest thing to buy: the next weights (Ki) or the next stand (cash), whichever is closest. Returns its
-- name and how far along it is (0..1+), or nil once there's nothing left.
local function nextGoal(ki, gearTier)
	local name, progress
	local rebirths = player:GetAttribute("Rebirths") or 0
	local gear = Training.Gear[gearTier + 1]
	if gearTier < Training.LadderTop and gear and Training.canBuyGear(gearTier, gearTier + 1, math.huge, rebirths) then
		name, progress = gear.name, ki / gear.cost
	end
	local stand = (player:GetAttribute("Stands") or 0) + 1
	local price = Config.Plot.standPrices[stand]
	if price then
		local p = (player:GetAttribute("Cash") or 0) / price
		if not progress or p > progress then
			name, progress = "STAND " .. stand, p
		end
	end
	return name, progress
end
local function refresh()
	local power = player:GetAttribute("Power") or 0
	local ki = player:GetAttribute("Ki") or 0
	local gearTier = player:GetAttribute("Gear") or 1
	hud.power.Text = Format.short(power)
	hud.ki.Text = Format.short(ki)
	hud.cash.Text = Format.cash(player:GetAttribute("Cash") or 0)
	local goal, goalAt = nextGoal(ki, gearTier)
	if goal then
		-- The fill keeps its rounded ends, so it never draws narrower than its own height.
		hud.fill.Size = UDim2.fromScale(math.clamp(goalAt, 0.13, 1), 1)
		hud.next.Text = goalAt >= 1 and (string.upper(goal) .. " READY!")
			or ("NEXT: " .. string.upper(goal) .. " " .. math.floor(goalAt * 100) .. "%")
	else
		local progress, nextAt = Training.toNext(power)
		hud.fill.Size = UDim2.fromScale(math.max(progress, 0.13), 1)
		hud.next.Text = nextAt and ("NEXT AURA " .. math.floor(progress * 100) .. "%") or "MAX AURA"
	end
	-- One line sums up training speed: gear x Champion x rebirths (stations add on top while seated).
	local perClick = Training.perRep(
		gearTier,
		1,
		player:GetAttribute("ChampionMult") or 1,
		player:GetAttribute("Rebirths") or 0,
		(player:GetAttribute("TrainBoost") or 1) * (player:GetAttribute("TutorialBoost") or 1) * LiveOps.mult("train"),
		player:GetAttribute("PremiumGear")
	)
	-- BEAM: the stat that jumps. Every gear, follower or rebirth multiplies it, so make that visible.
	hud.beam.Text = "x" .. (perClick < 100 and (math.floor(perClick * 10 + 0.5) / 10) or Format.short(perClick))
	if lastBeam and perClick > lastBeam then
		local grow = hud.beam:FindFirstChildOfClass("UIScale")
		if not grow then
			grow = Instance.new("UIScale")
			grow.Parent = hud.beam
		end
		grow.Scale = 1.7
		hud.beam.TextColor3 = Color3.new(1, 1, 1)
		tween(grow, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(hud.beam, 0.5, { TextColor3 = BEAM })
	end
	lastBeam = perClick
	local champion = Fighters.ByKey[player:GetAttribute("Champion") or ""]
	hud.gear.Text = "x"
		.. (perClick < 100 and (math.floor(perClick * 10 + 0.5) / 10) or Format.short(perClick))
		.. " PER CLICK"
		.. (champion and ("  ·  " .. string.upper(champion.display)) or "")
	local friends = player:GetAttribute("FriendBoost")
	hud.boostTag.Text = friends and ("+" .. math.floor((friends - 1) * 100 + 0.5) .. "% FRIEND BOOST") or ""
	if power > lastPower and lastPower >= 0 and not hud.bumping then
		hud.bumping = true
		hud.scale.Scale = hud.baseScale * 1.04
		tween(hud.scale, 0.15, { Scale = hud.baseScale }).Completed:Connect(function()
			hud.bumping = false
		end)
	end
	lastPower = power
end

-- A "+N" pop floating up from where the player clicked.
-- Click combo: clicks less than COMBO_GAP apart chain; the numbers grow and heat up with it.
local COMBO_GAP = 0.6
local combo, lastClick = 0, 0
local comboLabel, comboScale
local HEAT = {
	{ 0, GOLD },
	{ 10, Color3.fromRGB(255, 150, 40) },
	{ 30, Color3.fromRGB(255, 80, 90) },
	{ 60, Color3.fromRGB(200, 110, 255) },
}

local function heat(n)
	local color = GOLD
	for _, h in HEAT do
		if n >= h[1] then
			color = h[2]
		end
	end
	return color
end

local function pop(at, amount)
	local now = os.clock()
	combo = now - lastClick < COMBO_GAP and combo + 1 or 1
	lastClick = now
	local big = math.min(combo / 60, 1)
	local label = text(hud.gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X + math.random(-30, 30), at.Y - 10),
		Size = UDim2.fromOffset(140 + 60 * big, 38 + 18 * big),
		Text = "+" .. (amount < 100 and amount % 1 ~= 0 and string.format("%.1f", amount) or Format.short(amount)),
		TextColor3 = heat(combo),
		Rotation = math.random(-14, 14),
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = label
	tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	fade(label, 0.75, { Position = label.Position - UDim2.fromOffset(math.random(-20, 20), 80) })
	Debris:AddItem(label, 0.85)
	-- The combo counter, from 5 clicks in a row.
	if not comboLabel then
		comboLabel = text(hud.gui, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -150),
			Size = UDim2.fromOffset(320, 56),
			Text = "",
		})
		comboScale = Instance.new("UIScale")
		comboScale.Parent = comboLabel
	end
	comboLabel.Visible = combo >= 5
	if combo >= 5 then
		comboLabel.Text = "COMBO x" .. combo
		comboLabel.TextColor3 = heat(combo)
		comboLabel.TextTransparency = 0
		local stroke = comboLabel:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0
		end
		comboScale.Scale = combo % 10 == 0 and 1.6 or 1.15
		tween(comboScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(COMBO_GAP + 0.05, function()
			if os.clock() - lastClick >= COMBO_GAP then
				fade(comboLabel, 0.3)
			end
		end)
	end
end

-- ------------------------------------------------------------------ prompts

local function stationPromptText(prompt)
	local key = prompt:GetAttribute("Station")
	local def = Training.StationByKey[key]
	if not def then
		return
	end
	local owned = string.find("," .. (player:GetAttribute("Stations") or "") .. ",", "," .. key .. ",", 1, true)
	local here = player:GetAttribute("TrainStation")
	local model = prompt:FindFirstAncestorWhichIsA("Model")
	while model and not model:GetAttribute("StationId") do
		model = model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model")
	end
	if here and model and model:GetAttribute("StationId") == here then
		prompt.ActionText = "Stop"
		prompt.ObjectText = def.name
	elseif owned then
		prompt.ActionText = "Train"
		prompt.ObjectText = def.name .. "  ·  x" .. def.mult
	else
		prompt.ActionText = def.price > 0 and ("Buy  ·  " .. Format.cash(def.price)) or "Train"
		local power = player:GetAttribute("Power") or 0
		prompt.ObjectText = power < def.power and (def.name .. "  ·  needs " .. Format.short(def.power) .. " Power")
			or (def.name .. "  ·  x" .. def.mult)
	end
end

local prompts = {}
local function watchPrompt(inst)
	if inst:IsA("ProximityPrompt") and inst.Name == "StationPrompt" then
		prompts[inst] = true
		stationPromptText(inst)
	end
end

local function refreshPrompts()
	for prompt in prompts do
		if not prompt.Parent then
			prompts[prompt] = nil
		else
			stationPromptText(prompt)
		end
	end
end

-- Auto Train: the same +Power numbers as tapping, rising over the player twice a second (no combo: nobody tapped).
local function autoPop()
	local view = workspace.CurrentCamera.ViewportSize
	local amount = expected() * Products.AutoTrainRate * 0.5
	local label = text(hud.gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(view.X * 0.5 + math.random(-90, 90), view.Y * 0.45 + math.random(-30, 30)),
		Size = UDim2.fromOffset(140, 38),
		Text = "+" .. (amount < 100 and amount % 1 ~= 0 and string.format("%.1f", amount) or Format.short(amount)),
		TextColor3 = heat(1),
		Rotation = math.random(-10, 10),
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 1.4
	scale.Parent = label
	tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	fade(label, 0.75, { Position = label.Position - UDim2.fromOffset(math.random(-20, 20), 70) })
	Debris:AddItem(label, 0.85)
end

-- ------------------------------------------------------------------ input

-- A stray tap does nothing: training starts on the second tap in a row, and never while moving. (On a station
-- they chose to train, so every tap counts.)
local START_GAP = 0.8 -- seconds between two taps that count as meaning it
local lastTap = 0
local function click(at, humanoid)
	local now = os.clock()
	local seated = player:GetAttribute("TrainStation") ~= nil
	local first = now - lastTap > START_GAP
	lastTap = now
	if not seated and (first or humanoid.MoveDirection.Magnitude > 0.1) then
		return
	end
	while stamps[1] and now - stamps[1] > 1 do
		table.remove(stamps, 1)
	end
	if #stamps >= Training.MaxCps then
		return
	end
	table.insert(stamps, now)
	pending += 1
	pop(at, expected())
	if TrainingClient.onRep then
		TrainingClient.onRep()
	end
end

function TrainingClient.start()
	remote = Net.get("Train")
	buildHud()
	refresh()
	for _, name in
		{
			"Power",
			"Ki",
			"Gear",
			"Rebirths",
			"Champion",
			"ChampionMult",
			"Cash",
			"Stands",
			"TrainBoost",
			"TutorialBoost",
			"PremiumGear",
			"FriendBoost",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	for _, name in { "Power", "Ki", "Gear", "Stations", "TrainStation" } do
		player:GetAttributeChangedSignal(name):Connect(refreshPrompts)
	end
	for _, inst in workspace:GetDescendants() do
		watchPrompt(inst)
	end
	workspace.DescendantAdded:Connect(watchPrompt)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or player:GetAttribute("InClash") then
			return
		end
		click(Vector2.new(input.Position.X, input.Position.Y), humanoid)
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if
				player:GetAttribute("AutoTrainOn")
				and not player:GetAttribute("InClash")
				and os.clock() - lastClick > 1
				and hud.gui
				and hud.gui.Enabled
			then
				autoPop()
			end
		end
	end)
	-- Send reps in small batches; leave a station when the player moves or jumps.
	task.spawn(function()
		while true do
			task.wait(0.2)
			if pending > 0 then
				remote:FireServer("Reps", pending)
				pending = 0
			end
		end
	end)
	local leaving = false
	game:GetService("RunService").Heartbeat:Connect(function()
		if not player:GetAttribute("TrainStation") then
			leaving = false
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and not leaving and (humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Jump) then
			leaving = true
			remote:FireServer("Leave")
		end
	end)
	-- Jump also leaves (a seated player's root is anchored, so Humanoid.Jump never turns on).
	UserInputService.JumpRequest:Connect(function()
		if player:GetAttribute("TrainStation") and not leaving then
			leaving = true
			remote:FireServer("Leave")
		end
	end)
end

return TrainingClient
