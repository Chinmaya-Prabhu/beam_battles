-- The first-time experience and goals on the client (server/Services/TutorialService.lua decides the steps;
-- this draws them from player attributes Ftue, FtueText, FtueTarget, Goals):
--   * step 1: a camera swoop over the hub while Gokku drops ("THIS COULD BE YOURS!"); a click skips it,
--   * the coach bubble with the step's line (clash tips while in the tutorial clash),
--   * the big tapping hand for the click step,
--   * the guide beam to the step's target (client/ArrowPath.lua),
--   * after the tutorial: the goals panel, a chest pop for each finished goal, and confetti at the end,
--   * at the top of the goals panel, always: NEXT TARGET, the next guardian or boss to beat (or the rebirth)
--     with how much of its Power the player has, so there's a clear goal mid-game too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local Config = require(Shared.Config)
local Training = require(Shared.Training)
local Format = require(Shared.Format)
local UIAtlas = require(Shared.UIAtlas)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Fx = require(script.Parent.Fx)
local ArrowPath = require(script.Parent.ArrowPath)
local ZoneQuest = require(script.Parent.ZoneQuest)

local Tutorial = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local DONE = 99
local GREEN = Color3.fromRGB(110, 235, 130)

local gui, coach, coachText, hand, goalsPanel
local swooping = false
-- The fighter the opening swoop shows landing: a famous one in his normal form (shared/Fighters.lua).
local SHOWCASE = "Goku"

local function tween(inst, time, props, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- ------------------------------------------------------------------ coach

local CLASH_TIPS = {
	"TAP FAST TO PUSH THE BEAM!",
	UIKit.touch() and "TAP CHARGED ATTACK WHEN IT GLOWS!" or "PRESS E WHEN IT GLOWS!",
}

local function buildCoach()
	coach = Instance.new("ImageLabel")
	coach.Name = "Coach"
	coach.AnchorPoint = Vector2.new(0.5, 1)
	coach.Position = UDim2.new(0.5, 0, 1, -96)
	coach.Size = UDim2.fromOffset(720, 86)
	coach.BackgroundTransparency = 1
	coach.Visible = false
	UIKit.skin(coach, "bubble", 0.5)
	coach.Parent = gui
	local icon = UIAtlas.label(coach, "hand", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -30, 0.45, 0),
		Size = UDim2.fromOffset(74, 74),
		ZIndex = 3,
	})
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.Position = UDim2.new(0.5, icon and 20 or 0, 0.44, 0)
	textLabel.Size = UDim2.new(1, icon and -90 or -40, 0.6, 0)
	textLabel.Font = Enum.Font.LuckiestGuy
	textLabel.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 30
	cap.Parent = textLabel
	textLabel.TextColor3 = UIKit.INK
	textLabel.ZIndex = 3
	textLabel.Parent = coach
	coachText = textLabel
	local fit = Instance.new("UIScale")
	fit.Parent = coach
	local function scale()
		-- (On phones it fits between the thumbstick and the jump button.)
		local room = UIKit.compact() and camera.ViewportSize.X - 300 or camera.ViewportSize.X - 40
		fit.Scale = math.min(1, room / 760)
	end
	scale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(scale)
end

local tipIndex, tipAt = 1, 0
local LINE_TIME = 6 -- seconds a zone's next-step line stays up
local lastLine, lineUntil = nil, 0
local function refreshCoach()
	local step = player:GetAttribute("Ftue") or DONE
	local text = player:GetAttribute("FtueText")
	local inClash = player:GetAttribute("InClash")
	if step == 5 and inClash then
		if os.clock() - tipAt > 4 then
			tipAt = os.clock()
			tipIndex = tipIndex % #CLASH_TIPS + 1
		end
		text = CLASH_TIPS[tipIndex]
	elseif inClash then
		text = nil
	elseif step >= DONE then
		-- In a zone: the one thing to do next, for a few seconds whenever it changes.
		-- (Not behind the NEW AREA card: it shows once that closes.)
		local line = not gui:FindFirstChild("ZoneUnlocked") and ZoneQuest.line() or nil
		if line ~= lastLine then
			lastLine, lineUntil = line, os.clock() + LINE_TIME
		end
		text = os.clock() < lineUntil and line or nil
	end
	-- At the stand with the fighter: the stand's own prompt is the next thing to tap, so the bubble (which can sit
	-- right over it on a phone) steps aside.
	local target = player:GetAttribute("FtueTarget")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local atStand = step == 6
		and typeof(target) == "Vector3"
		and root ~= nil
		and player:GetAttribute("CarryKind") == "own"
		and (root.Position - target).Magnitude < 14
	local show = text ~= nil and not swooping and not atStand and not player:GetAttribute("GearShopOpen")
	if show and (coachText.Text ~= UIKit.device(text) or not coach.Visible) then
		coachText.Text = UIKit.device(text)
		coach.Size = UDim2.fromOffset(720, 86)
		local base = coach.Size
		coach.Size = UDim2.fromOffset(base.X.Offset * 0.85, base.Y.Offset * 0.85)
		tween(coach, 0.25, { Size = base }, Enum.EasingStyle.Back)
	end
	coach.Visible = show
	-- In the clash, the bubble sits up top, clear of the clash buttons.
	-- In the clash it drops lower, between the SMASH and DEFLECT buttons.
	coach.Position = inClash and UDim2.new(0.5, 0, 1, -24) or UDim2.new(0.5, 0, 1, UIKit.compact() and ((step == 6 or step >= DONE) and -116 or -14) or -96) -- (over the main button)
	hand.Visible = step == 2 and not swooping
end

-- ------------------------------------------------------------------ arrow and beam

local function updateMarker()
	local target = player:GetAttribute("FtueTarget")
	local show = typeof(target) == "Vector3" and not swooping
	-- The way there: the moving chevron beam (client/ArrowPath.lua), nothing else.
	ArrowPath.set("Tutorial", show and target or nil)
end

-- ------------------------------------------------------------------ swoop

local function swoop()
	if swooping then
		return
	end
	swooping = true
	while not UIKit.loaded() do -- after the loading screen (ReplicatedFirst)
		task.wait(0.2)
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	-- The Mythic drop show on the nearest hub altar (client only; not a real drop).
	local altars = workspace:WaitForChild("Map"):WaitForChild("Altars")
	local best, bestDist
	for _, a in altars:GetChildren() do
		local top = a:FindFirstChild("Top")
		local stand = top and top:FindFirstChild("FighterStand")
		if stand and root then
			local d = (stand.WorldPosition - root.Position).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = a, d
			end
		end
	end
	local target = best and best.Top.FighterStand.WorldPosition or Vector3.new(0, 0, 60)
	local look = root and root.Position or Vector3.new(0, 0, 112)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 150, 260), Vector3.new(0, 0, 0))
	local skip = false
	local showcase, hidden -- the show's fighter, and a real one it covers
	local conn = UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			skip = true
		end
	end)
	tween(
		camera,
		2.2,
		{ CFrame = CFrame.lookAt(target + Vector3.new(30, 30, 40), target) },
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut
	)
	task.delay(1.6, function()
		if skip then
			return
		end
		-- A fighter every player recognises (always the same one), for the dream.
		local pick = Fighters.ByKey[SHOWCASE]
		Fx.drop({
			rarity = pick.rarity,
			mutation = "Normal",
			display = pick.display,
			position = target,
			from = best and best:GetAttribute("Sky"),
		})
		-- The beam lands on a real fighter: a local one on this altar for the show (a fighter already
		-- standing there is hidden meanwhile), gone when the swoop ends.
		task.delay(Config.Drops.landDelay, function()
			if skip or not best then
				return
			end
			hidden = best:FindFirstChild("Fighter", true)
			for _, d in hidden and hidden:GetDescendants() or {} do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = 1
				elseif d:IsA("BillboardGui") then
					d.Enabled = false -- (its name plate too)
				end
			end
			local facing = best:GetAttribute("Facing") or Vector3.new(0, 0, 1)
			showcase = FighterModels.spawn(SHOWCASE, target, facing, {
				scale = FighterModels.scaleFor(SHOWCASE, "Table"),
				parent = workspace,
				aura = true,
			})
			if showcase then
				showcase:SetAttribute("Clip", Fighters.signature(SHOWCASE))
				showcase:SetAttribute("ClipStart", workspace:GetServerTimeNow())
			end
		end)
		local text = UIKit.text(gui, {
			Style = "display",
			TextSize = 40,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.7),
			Size = UDim2.fromOffset(640, 70),
			Text = "THIS COULD BE YOURS!",
			TextColor3 = UIKit.GOLD,
			StrokeThickness = 4,
		})
		local s = Instance.new("UIScale")
		s.Scale = 2
		s.Parent = text
		tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		Debris:AddItem(text, 2.6)
	end)
	local start = os.clock()
	while not skip and os.clock() - start < 3.6 do
		task.wait()
	end
	conn:Disconnect()
	if showcase then
		showcase:Destroy()
	end
	for _, d in hidden and hidden:GetDescendants() or {} do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		elseif d:IsA("BillboardGui") then
			d.Enabled = true
		end
	end
	-- Ease back behind the player.
	if root then
		tween(camera, 0.8, { CFrame = CFrame.lookAt(look + Vector3.new(0, 9, 16), look) })
		task.wait(0.8)
	end
	camera.CameraType = Enum.CameraType.Custom
	swooping = false
	Net.get("Tutorial"):FireServer("Swooped")
end

-- ------------------------------------------------------------------ goals

local nextTarget -- (below)
local collapse -- (the NEXT card folds into a badge; set up by buildGoals)
local CARD_OPEN = 5 -- seconds the NEXT card stays open before it folds
local function buildGoals()
	-- Top right, under Roblox's own buttons: a compact list, one line of text and a thin bar per goal.
	goalsPanel = Instance.new("Frame")
	goalsPanel.Name = "Goals"
	goalsPanel.AnchorPoint = Vector2.new(1, 0)
	-- (Only the NEXT target card shows on the HUD; the goals list is in the QUESTS window, client/EventsPanel.)
	goalsPanel.Position = UDim2.new(1, -16, 0, UIKit.compact() and 58 or 64)
	goalsPanel.Size = UDim2.fromOffset(300, 72)
	goalsPanel.BackgroundTransparency = 1
	goalsPanel.Visible = false
	goalsPanel.Parent = gui
	UIKit.fitScale(goalsPanel)
	-- NEXT TARGET: one card.
	local target = Instance.new("Frame")
	target.Name = "Target"
	target.Position = UDim2.fromOffset(0, 0)
	target.Size = UDim2.new(1, 0, 0, 72)
	target.BackgroundColor3 = Color3.fromRGB(255, 205, 60)
	target.Parent = goalsPanel
	Instance.new("UICorner", target).CornerRadius = UDim.new(0, 10)
	-- Tapping the card shows the way: the zone's guardian list in a zone (its LET'S GO points the beam), the
	-- MAP everywhere else (TRAVEL takes you there).
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 10
	tap.Parent = target
	-- GO: in the hub, the guide beam to the next zone's gate.
	local go = UIKit.pill(target, "green", "GO!", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0, 51),
		Size = UDim2.fromOffset(86, 38),
		ZIndex = 11,
	})
	go.Name = "Go"
	go.Visible = false
	local function showWay()
		local _, _, zoneName = nextTarget()
		for _, gate in game:GetService("CollectionService"):GetTagged("ZoneGate") do
			if gate:GetAttribute("Zone") == zoneName and gate:IsDescendantOf(workspace) then
				ArrowPath.set("Quest", gate:GetPivot().Position)
				return true
			end
		end
		return false
	end
	-- GO: the beam to the gate, and the MAP open on it (its NEXT! card has TRAVEL).
	local function goNow()
		showWay()
		local Map = require(script.Parent.Map)
		if Map.open then
			Map.open()
		end
	end
	go.Activated:Connect(goNow)
	tap.Activated:Connect(function()
		local zone = player:GetAttribute("Zone")
		if (zone == nil or zone == "Hub") and select(3, nextTarget()) then
			goNow()
			return
		end
		if zone and Config.Zones[zone] and ZoneQuest.openCard then
			ZoneQuest.openCard(zone)
		else
			local Map = require(script.Parent.Map)
			if Map.open then
				Map.open()
			end
		end
	end)
	local targetEdge = Instance.new("UIStroke")
	targetEdge.Thickness = 2
	targetEdge.Color = Color3.fromRGB(150, 90, 10)
	targetEdge.Parent = target
	local tt = UIKit.text(target, {
		Style = "heading",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 26),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	tt.TextWrapped = false
	tt.TextScaled = true -- (shrinks to fit a long place name instead of cutting it off)
	local ttCap = tt:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	ttCap.MaxTextSize = 24
	ttCap.MinTextSize = 12
	ttCap.Parent = tt
	tt.Name = "Text"
	local targetBar = Instance.new("Frame")
	targetBar.Name = "Bar"
	targetBar.Position = UDim2.fromOffset(10, 38)
	targetBar.Size = UDim2.new(1, -20, 0, 26)
	targetBar.BackgroundColor3 = Color3.fromRGB(120, 70, 10)
	targetBar.Parent = target
	Instance.new("UICorner", targetBar).CornerRadius = UDim.new(1, 0)
	local targetFill = Instance.new("Frame")
	targetFill.Name = "Fill"
	targetFill.Size = UDim2.fromScale(0.3, 1)
	targetFill.BackgroundColor3 = Color3.fromRGB(110, 235, 130)
	targetFill.Parent = targetBar
	Instance.new("UICorner", targetFill).CornerRadius = UDim.new(1, 0)
	local targetPct = UIKit.text(targetBar, {
		Style = "label",
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		StrokeThickness = 1.2,
	})
	targetPct.Name = "Count"
	-- The card shows when the target is new (or the badge is tapped), then folds back into a round badge (the
	-- zone's icon) after CARD_OPEN seconds; a chevron on the card folds it by hand. Phones and desktop alike.
	do
		tt.Size = UDim2.new(1, -52, 0, 26)
		local fold = Instance.new("TextButton")
		fold.Name = "Fold"
		fold.AnchorPoint = Vector2.new(1, 0)
		fold.Position = UDim2.new(1, -6, 0, 6)
		fold.Size = UDim2.fromOffset(32, 28)
		fold.BackgroundTransparency = 1
		fold.Text = ""
		fold.ZIndex = 12
		fold.Parent = target
		local up = UIKit.chevron(fold, 20, Color3.fromRGB(120, 70, 10))
		up.AnchorPoint = Vector2.new(0.5, 0.5)
		up.Position = UDim2.fromScale(0.5, 0.5)
		up.Rotation = 180
		up.ZIndex = 12
		for _, bar in up:GetChildren() do
			bar.ZIndex = 13
		end
		local badge = Instance.new("TextButton")
		badge.Name = "Badge"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 0, 0, 0)
		badge.Size = UDim2.fromOffset(60, 60)
		badge.BackgroundColor3 = Color3.fromRGB(22, 20, 44)
		badge.Text = ""
		badge.AutoButtonColor = false
		badge.Visible = false
		Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
		local ring = Instance.new("UIStroke")
		ring.Thickness = 3.5
		ring.Color = Color3.fromRGB(255, 205, 60)
		ring.Parent = badge
		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.AnchorPoint = Vector2.new(0.5, 0.5)
		picture.Position = UDim2.fromScale(0.5, 0.5)
		picture.Size = UDim2.fromOffset(46, 46)
		picture.BackgroundTransparency = 1
		picture.Parent = badge
		badge.Parent = goalsPanel
		local ready = UIKit.dot(badge)
		ready.Name = "Ready"
		-- The zone's count, on the badge's lower edge.
		local count = UIKit.text(badge, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.fromOffset(52, 22),
			Text = "",
			ZIndex = 6,
			StrokeThickness = 2.5,
		})
		local token = 0
		collapse = { badge = badge, picture = picture, ready = ready, count = count, card = target, line = nil }
		function collapse.set(open, auto)
			token += 1
			local mine = token
			target.Visible = open
			badge.Visible = not open
			if open and auto then
				task.delay(CARD_OPEN, function()
					if token == mine then
						collapse.set(false)
					end
				end)
			end
		end
		fold.Activated:Connect(function()
			collapse.set(false)
		end)
		badge.Activated:Connect(function()
			collapse.set(true, true)
		end)
	end
end

-- The next big target: the next guardian or boss in the furthest zone not yet cleared, or the rebirth once
-- every open zone is beaten. Returns its line and the Power it needs.
function nextTarget()
	local open = {}
	for name in string.gmatch(player:GetAttribute("Zones") or "", "[^,]+") do
		open[name] = true
	end
	local order = {}
	for name, z in Config.Zones do
		table.insert(order, { name = name, z = z })
	end
	table.sort(order, function(a, b)
		return a.z.order < b.z.order
	end)
	-- Before the first zone opens (2K Power) the goal is to train for it.
	local first = order[1]
	if not open[first.name] and first.z.unlockPower then
		return "TRAIN TO UNLOCK " .. string.upper(first.z.title), first.z.unlockPower, nil
	end
	for _, e in order do
		local z = e.z
		if open[e.name] and not player:GetAttribute("Boss_" .. e.name) then
			local rung = (player:GetAttribute("Ladder_" .. e.name) or 0) + 1
			local need = z.ladderPower[math.min(rung, 6)]
			if rung <= 5 then
				local f = Fighters.ByKey[z.guardians[rung]]
				return "BEAT " .. string.upper(f and f.display or "GUARDIAN " .. rung), need, e.name
			end
			return "BEAT " .. z.boss.title, need, e.name
		end
	end
	return "REBIRTH", Training.rebirthCost(player:GetAttribute("Rebirths") or 0)
end

local function refreshTarget()
	local target = goalsPanel and goalsPanel:FindFirstChild("Target")
	if not target then
		return
	end
	local line, need, zoneName = nextTarget()
	local power = player:GetAttribute("Power") or 0
	local p = math.clamp(power / math.max(need, 1), 0, 1)
	-- In the hub the next step is a PLACE (its guardian is out of sight): name it, and GO shows the way.
	local zone = player:GetAttribute("Zone")
	local inHub = zone == nil or zone == "Hub"
	local go = target:FindFirstChild("Go")
	if inHub and zoneName then
		line = string.upper(Config.Zones[zoneName].title)
	end
	-- Room for GO beside the bar when it shows; the name always gets the full width.
	-- Phones, inside the zone being worked on: just its name and how many of its 6 are beaten (the list is one
	-- tap away); no boss name or Power. Once its boss falls, the target is the next zone: GO again.
	local here = zoneName ~= nil and zone == zoneName
	local beaten = 0
	if here then
		beaten = (player:GetAttribute("Ladder_" .. zoneName) or 0) + (player:GetAttribute("Boss_" .. zoneName) and 1 or 0)
		line = string.upper(Config.Zones[zoneName].title)
	elseif zoneName and not inHub then
		line = string.upper(Config.Zones[zoneName].title) -- (in a cleared zone: the next one, with GO)
	end
	local showGo = (inHub or not here) and zoneName ~= nil
	target.Bar.Size = UDim2.new(1, showGo and -112 or -20, 0, 26)
	if go then
		go.Visible = showGo
	end
	if collapse then
		-- A new target opens the card for a few seconds; the badge wears the place's picture.
		local key = line .. (here and "@" or "")
		if collapse.line ~= key then
			collapse.line = key
			collapse.set(true, true)
		end
		local icon = zoneName and string.lower(zoneName) or (line == "REBIRTH" and "rebirth" or "power")
		UIAtlas.icon(collapse.picture, icon)
		collapse.ready.Visible = p >= 1 and not here
		collapse.ready.Count.Text = "!"
		collapse.count.Text = here and (beaten .. "/6") or ""
	end
	if here then
		target.Text.Text = line .. "  " .. beaten .. "/6"
		target.Bar.Fill.Size = UDim2.fromScale(math.max(beaten / 6, 0.08), 1)
		target.Bar.Count.Text = beaten .. " OF 6 BEATEN"
		return
	end
	target.Text.Text = "NEXT: " .. line
	target.Bar.Fill.Size = UDim2.fromScale(math.max(p, 0.08), 1)
	target.Bar.Count.Text = p >= 1 and "READY! GO FIGHT"
		or (Format.short(power) .. " / " .. Format.short(need) .. " POWER (" .. math.floor(p * 100) .. "%)")
end

local function refreshGoals()
	local done = (player:GetAttribute("Ftue") or DONE) >= DONE
	-- (In zones too: the card turns into the zone's count there.)
	goalsPanel.Visible = done and not player:GetAttribute("InClash")
	refreshTarget()
end

-- A chest bursting open in the middle of the screen with the reward.
local function goalPop(data)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromOffset(360, 230)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = holder
	UIAtlas.label(holder, "chest_open", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(140, 140),
	})
	UIKit.text(holder, {
		Style = "title",
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "GOAL COMPLETE!",
		TextColor3 = UIKit.GOLD,
		StrokeThickness = 3,
	})
	UIKit.text(holder, {
		Style = "number",
		TextSize = 30,
		Position = UDim2.fromOffset(0, 184),
		Size = UDim2.new(1, 0, 0, 36),
		Text = data.reward,
		TextColor3 = GREEN,
		StrokeThickness = 3,
	})
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.8, function()
		tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end)
	Debris:AddItem(holder, 2.2)
end

-- A new area just opened (Blossom Academy at 2K Power): a big card in the middle that stays until the player
-- answers it. GO points the guide beam at the area's gate and opens the map on it.
local function zonePop(data)
	local zone = Config.Zones[data.zone]
	if not zone then
		return
	end
	-- The zone's own colour (its gate's) and emblem badge, so each area's card looks like that area.
	local color = Color3.fromRGB(255, 205, 60)
	for _, gate in Config.Island.gates do
		if gate.zone == data.zone and gate.color then
			color = gate.color
		end
	end
	local holder = Instance.new("Frame")
	holder.Name = "ZoneUnlocked"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromOffset(420, 330)
	holder.BackgroundColor3 = Color3.new(1, 1, 1)
	holder.Parent = gui
	Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 18)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.65))
	fade.Parent = holder
	local edge = Instance.new("UIStroke")
	edge.Thickness = 5
	edge.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
	edge.Parent = holder
	UIAtlas.label(holder, string.lower(data.zone), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(92, 92),
		BackgroundTransparency = 1,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = holder
	UIKit.text(holder, {
		Style = "heading",
		Position = UDim2.fromOffset(10, 108),
		Size = UDim2.new(1, -20, 0, 32),
		Text = "NEW AREA UNLOCKED!",
		TextColor3 = UIKit.GOLD,
		StrokeThickness = 3,
	})
	local name = UIKit.text(holder, {
		Style = "title",
		Position = UDim2.fromOffset(10, 142),
		Size = UDim2.new(1, -20, 0, 56),
		Text = zone.title,
		TextColor3 = Color3.new(1, 1, 1),
		StrokeThickness = 4,
	})
	name.TextScaled = true
	UIKit.text(holder, {
		Style = "label",
		TextSize = 20,
		Position = UDim2.fromOffset(10, 204),
		Size = UDim2.new(1, -20, 0, 28),
		Text = "NEW GUARDIANS, FIGHTERS AND GEAR!",
		TextColor3 = Color3.new(1, 1, 1),
	})
	local function close()
		tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Debris:AddItem(holder, 0.3)
	end
	local go = UIKit.pill(holder, "green", "GO!", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(200, 54),
	})
	go.Activated:Connect(function()
		for _, gate in game:GetService("CollectionService"):GetTagged("ZoneGate") do
			if gate:GetAttribute("Zone") == data.zone and gate:IsDescendantOf(workspace) then
				ArrowPath.set("Quest", gate:GetPivot().Position)
				break
			end
		end
		local Map = require(script.Parent.Map)
		if Map.open then
			Map.open()
		end
		close()
	end)
	-- Never bigger than the screen (phones are short): the card fits under Roblox's top bar.
	local view = workspace.CurrentCamera.ViewportSize
	local fit = math.min(1, (view.Y - 70) / 330, (view.X - 24) / 420)
	holder.Position = UDim2.new(0.5, 0, 0.5, 18)
	tween(scale, 0.35, { Scale = fit }, Enum.EasingStyle.Back)
	task.delay(14, function()
		if holder.Parent then
			close()
		end
	end)
end

-- Confetti pieces raining from the top of the screen.
local function confetti()
	for _ = 1, 26 do
		local piece = UIAtlas.label(gui, "confetti", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, -0.08, 0),
			Size = UDim2.fromOffset(math.random(44, 76), math.random(44, 76)),
			Rotation = math.random(0, 360),
		})
		if not piece then
			return
		end
		local time = 1.6 + math.random() * 1.2
		tween(piece, time, {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-260, 260),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(piece, time + 0.1)
	end
end

-- ------------------------------------------------------------------ start

function Tutorial.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	buildCoach()
	buildGoals()
	hand = UIAtlas.label(gui, "hand", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.56, 0.5),
		Size = UDim2.fromOffset(120, 120),
		Visible = false,
	}) or Instance.new("Frame")

	local function onStep()
		refreshCoach()
		refreshGoals()
		if player:GetAttribute("Ftue") == 1 then
			task.spawn(swoop)
		end
	end
	for _, name in { "Ftue", "FtueText", "InClash", "Carrying", "GearShopOpen" } do
		player:GetAttributeChangedSignal(name):Connect(onStep)
	end
	player:GetAttributeChangedSignal("Goals"):Connect(refreshGoals)
	player:GetAttributeChangedSignal("Zone"):Connect(refreshGoals)
	-- The NEXT TARGET card follows Power and ladder progress.
	local watched = { "Power", "Zones", "Rebirths" }
	for name in Config.Zones do
		table.insert(watched, "Ladder_" .. name)
		table.insert(watched, "Boss_" .. name)
	end
	for _, name in watched do
		player:GetAttributeChangedSignal(name):Connect(refreshTarget)
	end
	onStep()
	task.spawn(function()
		while true do
			task.wait(0.5)
			if (player:GetAttribute("Ftue") or DONE) >= DONE then
				refreshCoach()
			end
		end
	end)

	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind == "GoalDone" then
			task.spawn(function()
				while UIKit.inFight() or UIKit.popupsHeld() do -- (after a fight's result, never over it)
					task.wait(0.5)
				end
				goalPop(data)
			end)
		elseif kind == "ZoneUnlocked" then
			task.spawn(function()
				while UIKit.inFight() or UIKit.popupsHeld() do
					task.wait(0.5)
				end
				zonePop(data)
				confetti()
			end)
		elseif kind == "FtueDone" then
			confetti()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		updateMarker()
		if hand.Visible then
			-- The tapping hand: a quick press every 0.6 s.
			local t = now % 0.6
			hand.Size = t < 0.12 and UDim2.fromOffset(104, 104) or UDim2.fromOffset(120, 120)
		end
		local ftue = player:GetAttribute("Ftue")
		if (ftue == 5 and player:GetAttribute("InClash")) or ftue == 6 then
			refreshCoach()
		end
	end)
end

return Tutorial
