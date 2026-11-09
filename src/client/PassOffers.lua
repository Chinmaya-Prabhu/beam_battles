-- Pass offers (docs/MONETIZATION.md): a pulsing icon on the right side that offers one gamepass at a time, with no
-- panel behind it and one word under it (AUTO, POWER, LUCK...). Tapping it opens Roblox's purchase window for that pass.
--   * Auto Train is offered the moment the player passes 1K Power, then the other passes follow as the player grows
--     (each at its own Power milestone),
--   * an offer stays up for SHOW_FOR seconds; one that is ignored comes back later, a little less often each time,
--   * phones: one tile between the main button and the jump button, rotating faster (no panel, so it costs no room),
--   * never during the tutorial, a clash, a full-screen moment or while a window is open; at least GAP seconds
--     between two offers; a pass that is owned is never offered.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Products)
local UIAtlas = require(Shared.UIAtlas)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local PassOffers = {}
local player = Players.LocalPlayer

local PHONE = UIKit.compact()
local SHOW_FOR = PHONE and 30 or 50 -- seconds an offer stays up
local GAP = PHONE and 15 or 150 -- seconds between the end of one offer and the next
local SIZE = PHONE and 0.72 or 1
local REOFFER = { 360, 540, 840, 1200 } -- seconds before an ignored pass comes back (then the last value, again)
local MAX_SHOWS = 6 -- per pass, per session

-- In the order they are offered. `from`: the Power at which the pass starts to make sense.
local CANDIDATES = {
	{ key = "AutoTrain", word = "AUTO", icon = "auto_train", from = 1e3 },
	{ key = "DoublePower", word = "POWER", icon = "double_power", from = 2.5e4 },
	{ key = "DropLuck", word = "LUCK", icon = "server_luck", from = 1e5 },
	{ key = "DoubleCash", word = "CASH", icon = "double_cash", from = 2e5 },
	{ key = "FastSteal", word = "STEAL", icon = "fast_steal", from = 5e5 },
	{ key = "ExtraStands", word = "STANDS", icon = "stand_now", from = 1e6 },
	{ key = "VIP", word = "VIP", icon = "vip", from = 2e6 },
}

-- Store items, offered the moment they make sense (one icon either way): after a Mythic or Secret drop, after
-- being stolen from, after a rebirth, a few minutes after the tutorial. Each comes back after MOMENT_GAP at most.
local MOMENTS = {
	ServerLuck = { word = "LUCK x2", icon = "server_luck" },
	Shield = { word = "SHIELD", icon = "shield" },
	PowerBoost = { word = "2X TRAIN", icon = "power_boost" },
	StarterPack = { word = "STARTER", icon = "gift" },
}
local MOMENT_GAP = 600
local waiting -- the moment to show as soon as it's clear
local momentAt = {}

local gui, holder, button, word, pulse
local current -- the candidate on show
local shownAt, lastEnd = 0, -math.huge
local nextAt, shows = {}, {} -- [key] = os.clock() it may come back, how many times it has been shown

local function owned(key)
	return player:GetAttribute("Owns_" .. key) == true
end

local function hide()
	if not current then
		return
	end
	current = nil
	lastEnd = os.clock()
	if pulse then
		pulse:Cancel()
		pulse = nil
	end
	local scale = holder:FindFirstChildOfClass("UIScale")
	local out = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Scale = 0,
	})
	out:Play()
	out.Completed:Connect(function()
		if not current then
			holder.Visible = false
		end
	end)
end

local function show(candidate)
	current = candidate
	shownAt = os.clock()
	shows[candidate.key] = (shows[candidate.key] or 0) + 1
	UIAtlas.icon(button, candidate.icon)
	word.Text = candidate.word
	holder.Visible = true
	local scale = holder:FindFirstChildOfClass("UIScale")
	scale.Scale = 0
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = SIZE }):Play()
	-- The pulse is on the icon itself, so the word stays still.
	local beat = button:FindFirstChildOfClass("UIScale")
	beat.Scale = 1
	pulse =
		TweenService:Create(beat, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Scale = 1.16,
		})
	pulse:Play()
end

local function buy()
	local candidate = current
	if not candidate then
		return
	end
	local product = Products.ByKey[candidate.key]
	if RunService:IsStudio() then
		Net.get("Shop"):FireServer("DebugBuy", candidate.key) -- (Studio: a test grant; the creator "owns" every real pass)
	elseif product and product.id ~= 0 and candidate.item then
		MarketplaceService:PromptProductPurchase(player, product.id)
	elseif product and product.id ~= 0 then
		UIKit.promptPass(candidate.key, product.id)
	end
	-- Not bought yet? It comes back later like any ignored offer.
	nextAt[candidate.key] = os.clock() + REOFFER[math.min(shows[candidate.key] or 1, #REOFFER)]
	hide()
end

local function anyWindowOpen()
	for _, w in CollectionService:GetTagged("UIWindow") do
		if w:IsA("GuiObject") and w.Visible then
			return true
		end
	end
	return false
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "PassOffersGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("InClash"):Connect(function()
		gui.Enabled = not player:GetAttribute("InClash")
	end)
	holder = Instance.new("Frame")
	holder.Name = "PassOffer"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(100, 130)
	holder.Visible = false
	-- Beside the free-rewards column (the right edge), at its height; on phones low down, clear of every tile.
	if PHONE then
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.Position = UDim2.new(0.7, 0, 1, -8)
	else
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.new(1, -150, 0.55, 0)
	end
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	button = Instance.new("ImageButton")
	button.Name = "Icon"
	button.BackgroundTransparency = 1
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 0)
	button.Size = UDim2.fromOffset(96, 96)
	button.AutoButtonColor = false
	button.Parent = holder
	Instance.new("UIScale").Parent = button
	button.Activated:Connect(buy)
	word = UIKit.text(holder, {
		Style = "heading",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		StrokeThickness = 3,
	})
end

local function pick()
	local power = player:GetAttribute("Power") or 0
	local stands = player:GetAttribute("Stands") or 0
	local now = os.clock()
	for _, c in CANDIDATES do
		local ready = power >= c.from and (c.key ~= "ExtraStands" or stands >= 8)
		if ready and not owned(c.key) and (shows[c.key] or 0) < MAX_SHOWS and now >= (nextAt[c.key] or 0) then
			return c
		end
	end
	return nil
end

local function moment(key)
	local product = Products.ByKey[key]
	if product and (product.id ~= 0 or RunService:IsStudio()) and os.clock() >= (momentAt[key] or 0) then
		momentAt[key] = os.clock() + MOMENT_GAP
		waiting = { key = key, item = true, word = MOMENTS[key].word, icon = MOMENTS[key].icon }
	end
end

function PassOffers.start()
	build()
	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind == "Drop" and (data.rarity == "Mythic" or data.rarity == "Secret") and not data.summoner then
			if (ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0) <= workspace:GetServerTimeNow() then
				task.delay(3, moment, "ServerLuck")
			end
		elseif kind == "Stolen" and data.victim == player.UserId then
			task.delay(2, moment, "Shield")
		elseif kind == "Rebirth" and data.userId == player.UserId then
			task.delay(8, moment, "PowerBoost")
		elseif kind == "FtueDone" and (player:GetAttribute("StarterUntil") or 0) > os.time() then
			task.delay(180, moment, "StarterPack")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			local clear = (player:GetAttribute("Ftue") or 99) >= 99
				and not UIKit.inFight()
				and not UIKit.popupsHeld()
				and not anyWindowOpen()
			if waiting and clear then
				-- A moment takes the icon straight away.
				if pulse then
					pulse:Cancel()
					pulse = nil
				end
				show(waiting)
				waiting = nil
			elseif current then
				-- It leaves when bought, or when its time is up (and comes back later).
				if owned(current.key) then
					hide()
				elseif os.clock() - shownAt > SHOW_FOR then
					nextAt[current.key] = os.clock() + REOFFER[math.min(shows[current.key] or 1, #REOFFER)]
					hide()
				end
			elseif os.clock() - lastEnd > GAP and clear then
				local candidate = pick()
				if candidate then
					show(candidate)
				end
			end
		end
	end)
end

return PassOffers
