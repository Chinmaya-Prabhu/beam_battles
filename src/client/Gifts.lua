-- Free gifts and the daily streak on the client (server/Services/RewardsService.lua, shared/Rewards.lua):
--   * GIFTS and DAILY tiles in the menu's free column (UIKit.menu("free")): GIFTS counts down to the next
--     gift under it ("READY!" with a dot when one is), DAILY says CLAIM! or the time until tomorrow's,
--   * FREE BOOSTS along the gift window's bottom: invite friends, join the group (client/Social),
--   * the top chip (client/Events.lua) keeps saying "FREE LEGENDARY IN 87:12" so players know to stay,
--   * a join pop-up: "PLAY 55 MIN FOR A FREE LEGENDARY FIGHTER!" (the last gift: shared/Rewards.lua),
--   * the GIFTS window: the seven gifts with their times, CLAIM on the ready ones,
--   * the DAILY window (opens itself on join when a claim is open): the 7-day streak,
--   * FX "Reward": a chest that pops open with what was won.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rewards = require(Shared.Rewards)
local UIAtlas = require(Shared.UIAtlas)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local FighterAnimator = require(script.Parent.FighterAnimator)
local Fancy = require(script.Parent.Fancy)
local Social = require(script.Parent.Social)
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)

local Gifts = {}
local player = Players.LocalPlayer
local remote
local gui, giftWindow, dailyWindow, hookCard
local giftCards, dailyCards = {}, {}

local function clock(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, s % 3600 // 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

local function tween(inst, time, props, style)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad), props)
	t:Play()
	return t
end

-- A named fighter prize: the real model, animated, filling the whole card (behind its day label and pill).
-- No name, no rarity: just the fighter.
local function portrait(card, key)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Position = UDim2.fromOffset(0, 0)
	vp.Size = UDim2.fromScale(1, 1) -- the whole card: the day label and the pill sit on top of the fighter
	vp.ZIndex = 1
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.Parent = card
	local model = FighterModels.spawn(key, Vector3.zero, Vector3.new(0, 0, 1), { parent = vp })
	local height, centre = 5, Vector3.new(0, 2.5, 0)
	if model then
		local box, size = model:GetBoundingBox()
		-- Wide ones (wings, capes) must fit the narrow card too: its width is about 0.75 of its height.
		height = math.max(size.Y, size.X / 0.75, 1)
		centre = box.Position
		if not FighterAnimator.view(model, key) then
			FighterModels.holdPose(model, Fighters.signature(key)) -- (no clips yet: the signature pose)
		end
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local distance = height / 2 / math.tan(math.rad(15)) * 1.08 -- (the whole fighter, head to feet, fills the card)
	cam.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0, distance), centre)
	cam.Parent = vp
	vp.CurrentCamera = cam
end

-- What a reward reads as on its card.
local function describe(r)
	if r.kind == "ki" then
		return "Ki", "ki"
	elseif r.kind == "cash" then
		return "Cash", "cash"
	elseif r.kind == "boost" then
		return "2x Training\n" .. r.minutes .. " min", "power_boost"
	end
	local fighter = r.key and Fighters.ByKey[r.key]
	if fighter then
		return fighter.display .. "\n" .. r.rarity, nil
	end
	return r.rarity .. " fighter", "smash_charged"
end

local function claimed()
	local set = {}
	for n in string.gmatch(player:GetAttribute("GiftsClaimed") or "", "%d+") do
		set[tonumber(n)] = true
	end
	return set
end

local function elapsed()
	return workspace:GetServerTimeNow() - (player:GetAttribute("GiftStart") or workspace:GetServerTimeNow())
end

-- One reward card: icon, what it is, and a pill (time / CLAIM / CLAIMED).
local function rewardCard(parent, r, order, top)
	local card = Instance.new("ImageLabel")
	card.LayoutOrder = order
	card.BackgroundTransparency = 1
	UIKit.skin(card, "card", 0.3)
	if r.kind == "fighter" then -- (the big prizes: a gold border)
		local edge = Instance.new("UIStroke")
		edge.Thickness = 4
		edge.Color = UIKit.GOLD
		edge.Parent = card
	end
	card.Parent = parent
	local what, icon = describe(r)
	UIKit.text(card, {
		Style = "heading",
		TextSize = 22,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 26),
		Text = top,
		TextColor3 = UIKit.GOLD,
		ZIndex = 3,
	})
	if icon then
		UIAtlas.label(card, icon, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 36),
			Size = UDim2.fromOffset(70, 70),
		})
	else
		portrait(card, r.key)
	end
	if icon or not r.key then
		UIKit.text(card, {
			Style = "label",
			TextSize = 17,
			Position = UDim2.fromOffset(6, 108),
			Size = UDim2.new(1, -12, 0, 40),
			Text = string.upper(what),
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
	end
	local pill, label = UIKit.pill(card, "grey", "", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -14, 0, 42),
	})
	return { card = card, pill = pill, label = label, color = "grey" }
end

local function setPill(c, text, color)
	c.label.Text = text
	if c.color ~= color then
		c.color = color
		UIKit.setPill(c.pill, color)
	end
end

local function grid(body, cell)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(0, 44)
	holder.Size = UDim2.new(1, 0, 1, -44)
	holder.Parent = body
	local g = Instance.new("UIGridLayout")
	g.CellSize = cell
	g.CellPadding = UDim2.fromOffset(cell.X.Offset < 100 and 6 or 10, 10)
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = holder
	return holder
end

local function buildGiftWindow()
	local w, body = UIKit.window(gui, "FREE GIFTS", Vector2.new(700, 620))
	UIKit.text(body, {
		Style = "label",
		TextSize = 20,
		TextColor3 = UIKit.GOLD,
		Size = UDim2.new(1, 0, 0, 34),
		Text = "PLAY TO UNLOCK GIFTS. " .. Rewards.Gifts[#Rewards.Gifts].min .. " MIN = FREE LEGENDARY!",
	})
	local holder = grid(body, UDim2.fromOffset(150, 204))
	for i, g in Rewards.Gifts do
		local c = rewardCard(holder, g, i, g.min .. " MIN")
		c.pill.Activated:Connect(function()
			if Rewards.giftReady(i, elapsed(), claimed()) then
				remote:FireServer("Gift", i)
			end
		end)
		giftCards[i] = c
	end
	-- Free boosts along the bottom: invite friends (while they play here) and the group.
	local S = Config.Social
	local strip = Instance.new("Frame")
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.Position = UDim2.fromScale(0, 1)
	strip.Size = UDim2.new(1, 0, 0, 50)
	strip.BackgroundTransparency = 1
	strip.Parent = body
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.Parent = strip
	local invite, inviteText = UIKit.pill(strip, "gold", "", { Size = UDim2.fromOffset(310, 50), LayoutOrder = 1 })
	invite.Activated:Connect(Social.invite)
	local group, groupText = UIKit.pill(strip, "green", "", { Size = UDim2.fromOffset(310, 50), LayoutOrder = 2 })
	group.Activated:Connect(Social.joinGroup)
	local function boosts()
		local boost = player:GetAttribute("FriendBoost")
		inviteText.Text = boost and ("FRIEND BOOST +" .. math.floor((boost - 1) * 100 + 0.5) .. "%")
			or ("INVITE FRIENDS: +" .. math.floor(S.friendStep * 100) .. "% EACH")
		group.Visible = ReplicatedStorage:GetAttribute("GroupId") ~= nil and not player:GetAttribute("GroupMult")
		groupText.Text = "JOIN GROUP: +" .. math.floor((S.groupCash - 1) * 100 + 0.5) .. "% CASH"
	end
	boosts()
	for _, name in { "FriendBoost", "GroupMult" } do
		player:GetAttributeChangedSignal(name):Connect(boosts)
	end
	ReplicatedStorage:GetAttributeChangedSignal("GroupId"):Connect(boosts)
	return w
end

local function buildDailyWindow()
	local w, body = UIKit.window(gui, "DAILY REWARDS", Vector2.new(700, 560))
	UIKit.text(body, {
		Style = "label",
		TextSize = 20,
		TextColor3 = UIKit.GOLD,
		Size = UDim2.new(1, 0, 0, 34),
		Text = "COME BACK EVERY DAY. DAY 7 = FREE MYTHIC!",
	})
	local holder = grid(body, UDim2.fromOffset(150, 204))
	for d, r in Rewards.Daily do
		local c = rewardCard(holder, r, d, "DAY " .. d)
		c.pill.Activated:Connect(function()
			if player:GetAttribute("DailyOpen") and player:GetAttribute("DailyDay") == d then
				remote:FireServer("Daily")
			end
		end)
		dailyCards[d] = c
	end
	return w
end

local function refreshDaily()
	local open, day = player:GetAttribute("DailyOpen"), player:GetAttribute("DailyDay") or 1
	for d, c in dailyCards do
		if open and d == day then
			setPill(c, "CLAIM!", "green")
		elseif d < day or (not open and d == day) then
			setPill(c, "DONE", "grey")
		else
			setPill(c, "LOCKED", "grey")
		end
	end
end

-- FX "Reward": a chest that bursts open with the prize.
local function rewardPop(data)
	while UIKit.inFight() do -- (a reward won in a fight shows once its result is over)
		task.wait(0.5)
	end
	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.45)
	root.Size = UDim2.fromOffset(360, 300)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local stage = Instance.new("Frame")
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.45)
	stage.Size = UDim2.fromOffset(180, 180)
	stage.BackgroundTransparency = 1
	stage.Parent = root
	Fancy.rays(stage, UIKit.GOLD, 14)
	local chest = UIAtlas.label(stage, "chest", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(150, 150),
		ZIndex = 3,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = root
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	-- Shake, then pop open.
	for k = 1, 6 do
		if chest then
			chest.Rotation = (k % 2 == 0 and 1 or -1) * 10
		end
		task.wait(0.06)
	end
	if chest then
		chest.Rotation = 0
		UIAtlas.icon(chest, "chest_open")
	end
	UIKit.text(root, {
		Style = "title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 44),
		Text = data.title,
		TextColor3 = UIKit.GOLD,
		StrokeThickness = 3,
		ZIndex = 5,
	})
	local line = UIKit.text(root, {
		Style = "display",
		TextSize = 38,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 44),
		Text = data.line,
		StrokeThickness = 3,
		ZIndex = 5,
	})
	local lineScale = Instance.new("UIScale")
	lineScale.Scale = 2
	lineScale.Parent = line
	tween(lineScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(2)
	tween(scale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back)
	task.wait(0.35)
	root:Destroy()
end

-- The join pop-up that sells staying.
local function hook()
	if giftWindow.Visible or dailyWindow.Visible then
		return
	end
	local tries = 0
	while not UIKit.claimPopup() do
		tries += 1
		if tries > 30 then
			return
		end
		task.wait(1)
	end
	local card = Instance.new("ImageLabel")
	hookCard = card
	-- At the bottom, where offers appear (the top is the HUD's), sliding up from below.
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, 160)
	card.Size = UDim2.fromOffset(520, 110)
	card.BackgroundTransparency = 1
	UIKit.skin(card, "card", 0.3)
	card.Parent = gui
	UIKit.fitScale(card, 0.72)
	UIAtlas.label(card, "gift", { Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(86, 86) })
	UIKit.text(card, {
		Style = "heading",
		Position = UDim2.fromOffset(110, 14),
		Size = UDim2.new(1, -124, 0, 40),
		Text = "PLAY " .. Rewards.Gifts[#Rewards.Gifts].min .. " MIN FOR A",
		TextColor3 = Color3.new(1, 1, 1),
		StrokeThickness = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local big = UIKit.text(card, {
		Style = "title",
		TextSize = 28,
		Position = UDim2.fromOffset(110, 54),
		Size = UDim2.new(1, -124, 0, 44),
		Text = "FREE LEGENDARY FIGHTER!",
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
	})
	big.TextColor3 = UIKit.GOLD
	tween(card, 0.5, { Position = UDim2.new(0.5, 0, 1, UIKit.compact() and -116 or -24) }, Enum.EasingStyle.Back)
	task.wait(6)
	tween(card, 0.4, { Position = UDim2.new(0.5, 0, 1, 160) })
	task.wait(0.5)
	card:Destroy()
	UIKit.releasePopup()
end

-- Opens the daily streak window.
function Gifts.openDaily()
	refreshDaily()
	dailyWindow.Visible = true
end

-- Opens the gift window (the top chip's Legendary line opens it too).
function Gifts.open()
	if hookCard then
		hookCard.Visible = false
	end
	giftWindow.Visible = true
end

function Gifts.start()
	remote = Net.get("Rewards")
	gui = Instance.new("ScreenGui")
	gui.Name = "GiftsGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9 -- windows sit above the HUD and the goals (Tutorial, 8)
	gui.Parent = player:WaitForChild("PlayerGui")
	giftWindow = buildGiftWindow()
	dailyWindow = buildDailyWindow()

	local free = UIKit.menu("free")
	local tile = UIKit.tile(free, "gift", "GIFTS", { LayoutOrder = 1 })
	local giftDot = UIKit.dot(tile)
	tile.Activated:Connect(function()
		if giftWindow.Visible then
			giftWindow.Visible = false
		else
			Gifts.open()
		end
	end)
	local daily = UIKit.tile(free, "chest", "DAILY", { LayoutOrder = 2 })
	daily:SetAttribute("AfterTutorial", true)
	local dailyDot = UIKit.dot(daily)
	daily.Activated:Connect(function()
		if dailyWindow.Visible then
			dailyWindow.Visible = false
		else
			Gifts.openDaily()
		end
	end)

	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind == "Reward" then
			task.spawn(rewardPop, data)
		end
	end)
	for _, name in { "DailyOpen", "DailyDay" } do
		player:GetAttributeChangedSignal(name):Connect(refreshDaily)
	end

	-- First join of the session: the hook, then the daily window if a claim is open.
	task.spawn(function()
		while not player:GetAttribute("GiftStart") do
			task.wait(0.5)
		end
		-- Not over the tutorial: wait for it to finish, then give the new player a minute to play (the
		-- Starter Pack offer comes first), so pop-ups don't pile up the moment it ends.
		local learning = false
		while (player:GetAttribute("Ftue") or 99) < 99 do
			learning = true
			task.wait(2)
		end
		task.wait(learning and 60 or 8)
		while UIKit.popupsHeld() do
			task.wait(1)
		end
		hook()
		-- The daily window opens itself only when nothing else is open (never over a window the player chose).
		local anyOpen = false
		for _, w in game:GetService("CollectionService"):GetTagged("UIWindow") do
			anyOpen = anyOpen or w.Visible
		end
		while UIKit.inFight() or UIKit.popupsHeld() do -- (never during or right after a fight)
			task.wait(1)
		end
		if player:GetAttribute("DailyOpen") and not anyOpen then
			-- (ClashMode closes it if a clash starts right after.)
			refreshDaily()
			dailyWindow.Visible = true
		end
	end)

	task.spawn(function()
		while true do
			local t, set = elapsed(), claimed()
			local anyReady = false
			for i, c in giftCards do
				if set[i] then
					setPill(c, "CLAIMED", "grey")
				elseif Rewards.giftReady(i, t, set) then
					setPill(c, "CLAIM!", "green")
					anyReady = true
				else
					setPill(c, clock(Rewards.Gifts[i].min * 60 - t), "gold")
				end
			end
			giftDot.Visible = anyReady
			dailyDot.Visible = player:GetAttribute("DailyOpen") == true
			task.wait(1)
		end
	end)
end

return Gifts
