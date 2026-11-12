-- Free rewards and the Index (docs/RETENTION_PLAN.md):
--   * playtime gifts (shared/Rewards.lua): timed from this session's join; player attributes GiftStart (server
--     time) and GiftsClaimed ("1,2,..."); claimed with the Rewards remote "Gift" <index>,
--   * the daily streak: DailyOpen / DailyDay attributes; claimed with "Daily",
--   * the Index (shared/Collection.lua): every fighter a player gets is recorded (TrainingService.onAcquire);
--     completed series raise IndexMult (MonetizationService folds it into CashMult) and are listed in
--     IndexDone for the badges over the base; IndexCount = fighters collected. The book itself comes from
--     the Request remote ("Index").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Rewards = require(Shared.Rewards)
local Codes = require(Shared.Codes)
local Collection = require(Shared.Collection)
local Fighters = require(Shared.Fighters)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Reveal = require(script.Parent.Parent.Reveal)

local RewardsService = {}
local FX = Net.get("FX")
local Data, Plots, Training, Shop

local GOLD = Color3.fromRGB(255, 214, 80)
local GREEN = Color3.fromRGB(120, 255, 150)

local redeem -- defined before start
local sessions = {} -- [player] = { start = server time, claimed = { [i] = true } }

local function banner(player, text, color)
	FX:FireClient(player, "Banner", { text = text, color = color })
end

-- Pays one reward (a gift or a daily), `times` over for Cash, Power and boosts; returns the line shown.
function RewardsService.pay(player, data, reward, times)
	times = times or 1
	if reward.kind == "power" or reward.kind == "ki" then -- ("ki": old LiveOps and code rewards)
		local amount = Rewards.amount(reward, Training.perRep(player), 0) * times
		Training.givePower(player, amount)
		return "+" .. Format.short(amount) .. " POWER"
	elseif reward.kind == "cash" then
		local amount = Rewards.amount(reward, 0, Plots.incomeRate(player)) * times
		Plots.addCash(player, amount)
		return "+" .. Format.cash(amount)
	elseif reward.kind == "boost" then
		local minutes = reward.minutes * times
		data.boostUntil.PowerBoost = math.max(data.boostUntil.PowerBoost or 0, os.time()) + minutes * 60
		Shop.refresh(player)
		return "2x TRAINING " .. minutes .. " MIN"
	elseif reward.kind == "fighter" then
		if reward.key then
			Reveal.giveFighter(player, reward.key, "Normal")
		else
			Reveal.give(player, reward.rarity)
		end
		return "A " .. string.upper(reward.rarity) .. " FIGHTER"
	end
	return ""
end

local function publishGifts(player)
	local s = sessions[player]
	if not s then
		return
	end
	local list = {}
	for i in s.claimed do
		table.insert(list, i)
	end
	table.sort(list)
	player:SetAttribute("GiftStart", s.start)
	player:SetAttribute("GiftsClaimed", table.concat(list, ","))
end

local function publishDaily(player, data)
	local open, day = Rewards.daily(data.daily.last, data.daily.streak, Rewards.day(os.time()))
	player:SetAttribute("DailyOpen", open)
	player:SetAttribute("DailyDay", day)
end

local function publishIndex(player, data)
	local count = 0
	for _ in data.index do
		count += 1
	end
	player:SetAttribute("IndexCount", count)
	player:SetAttribute("IndexTotal", #Fighters.Launch)
	local done = Collection.completed(data.index)
	player:SetAttribute("IndexDone", table.concat(done, ","))
	Plots.setBadges(player, done)
	local before = player:GetAttribute("IndexMult")
	local mult = Collection.cashMult(data.index)
	player:SetAttribute("IndexMult", mult)
	if before ~= mult then
		Shop.refresh(player) -- CashMult includes it
	end
end

local function claimGift(player, i)
	local data = Data.get(player)
	local s = sessions[player]
	if not data or not s or type(i) ~= "number" then
		return
	end
	if not Rewards.giftReady(i, workspace:GetServerTimeNow() - s.start, s.claimed) then
		return
	end
	s.claimed[i] = true
	local line = RewardsService.pay(player, data, Rewards.Gifts[i])
	Data.changed(player)
	publishGifts(player)
	if Rewards.Gifts[i].kind ~= "fighter" then -- a fighter has its own reveal
		FX:FireClient(player, "Reward", { title = "FREE GIFT!", line = line })
	end
end

local function claimDaily(player)
	local data = Data.get(player)
	if not data then
		return
	end
	local today = Rewards.day(os.time())
	local open, day = Rewards.daily(data.daily.last, data.daily.streak, today)
	if not open then
		return
	end
	data.daily.last, data.daily.streak = today, day
	-- VIP doubles the daily Cash, Power and boosts (a fighter stays one fighter).
	local vip = player:GetAttribute("VIP") == true
	local line = RewardsService.pay(player, data, Rewards.Daily[day], vip and 2 or 1)
	Data.changed(player)
	Data.saveNow(player) -- (the streak must not be lost if they leave a moment later)
	publishDaily(player, data)
	if Rewards.Daily[day].kind ~= "fighter" then
		local title = vip and Rewards.Daily[day].kind ~= "fighter" and ("DAY " .. day .. " · VIP x2!")
			or ("DAY " .. day .. " REWARD!")
		FX:FireClient(player, "Reward", { title = title, line = line })
	end
end

-- A fighter arrives (TrainingService.addFighter): into the book, and a series completed is a big moment.
local function acquire(player, key, mutation)
	local data = Data.get(player)
	if not data then
		return
	end
	local doneBefore = #Collection.completed(data.index)
	local isNew = Collection.add(data.index, key, mutation)
	if not isNew then
		return
	end
	local done = Collection.completed(data.index)
	if #done > doneBefore then
		local series = Fighters.ByKey[key].series
		banner(player, string.upper(series) .. " SERIES COMPLETE! +10% CASH FOREVER", GOLD)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				banner(other, player.DisplayName .. " COMPLETED " .. string.upper(series) .. "!", GOLD)
			end
		end
	elseif not player:GetAttribute("Ftue") or player:GetAttribute("Ftue") >= 99 then
		banner(player, "NEW IN YOUR INDEX!", GREEN)
	end
	Data.changed(player)
	publishIndex(player, data)
end

-- Redeems a code (client/Codes.lua): returns { ok, text }. One try a second; every reward of the code
-- is paid and the code is remembered (data.codes) so it works once.
redeem = function(player, data, text, lastTry)
	if os.clock() - (lastTry[player] or 0) < 1 then
		return { ok = false, text = "SLOW DOWN" }
	end
	lastTry[player] = os.clock()
	data.codes = data.codes or {}
	local remote = RewardsService.remoteCodes and RewardsService.remoteCodes() or nil
	local entry, code = Codes.check(text, data.codes, os.time(), remote)
	if not entry then
		return { ok = false, text = code }
	end
	data.codes[code] = true
	player:SetAttribute("CodesUsed", true) -- (the Settings gear stops asking: client/Settings.lua)
	local lines = {}
	for _, reward in entry.rewards do
		local line = RewardsService.pay(player, data, reward)
		if line ~= "" then
			table.insert(lines, line)
		end
	end
	Data.changed(player)
	Data.saveNow(player)
	local paid = table.concat(lines, "  ·  ")
	FX:FireClient(player, "Reward", { title = "CODE " .. code, line = paid })
	return { ok = true, text = paid }
end

function RewardsService.start(DataService, PlotService, TrainingService, MonetizationService)
	Data, Plots, Training, Shop = DataService, PlotService, TrainingService, MonetizationService
	Reveal.init(TrainingService)
	TrainingService.onAcquire = acquire
	DataService.onLoaded(function(player, data)
		-- Saves from before the Index: everything they own now goes in.
		for _, entry in data.fighters do
			Collection.add(data.index, entry.k, entry.m)
		end
		sessions[player] = { start = workspace:GetServerTimeNow(), claimed = {} }
		player:SetAttribute("CodesUsed", next(data.codes or {}) ~= nil or nil)
		publishGifts(player)
		-- Studio: player attribute DebugGiftSkip = minutes moves this session's gift clock forward.
		if game:GetService("RunService"):IsStudio() then
			player:GetAttributeChangedSignal("DebugGiftSkip"):Connect(function()
				local minutes = player:GetAttribute("DebugGiftSkip")
				if minutes and sessions[player] then
					sessions[player].start -= minutes * 60
					player:SetAttribute("DebugGiftSkip", nil)
					publishGifts(player)
				end
			end)
		end
		publishDaily(player, data)
		publishIndex(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	Net.get("Rewards").OnServerEvent:Connect(function(player, kind, value)
		if kind == "Gift" then
			claimGift(player, value)
		elseif kind == "Daily" then
			claimDaily(player)
		end
	end)
	local lastTry = {}
	Net.get("Request").OnServerInvoke = function(player, kind, value)
		local data = Data.get(player)
		if kind == "Index" and data then
			return data.index
		elseif kind == "Bag" then
			return Plots.bagList(player) -- client/Bag.lua
		elseif kind == "Code" and data then
			return redeem(player, data, value, lastTry)
		end
		return nil
	end
	-- A new UTC day while playing opens the next daily claim.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				if data then
					publishDaily(player, data)
				end
			end
		end
	end)
end

return RewardsService
