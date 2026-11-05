-- LiveOps on the server (shared/LiveOps.lua, docs/LIVEOPS.md):
--   * the running event, from the remote config's schedule or the default weekly calendar, published as
--     ReplicatedStorage attributes: LiveEvent, LiveEventEnds, NextEvent, NextEventAt, Announcement,
--     Featured (product keys, comma-separated) and Live_<effect> multipliers (LiveOps.mult reads them),
--   * remote config: a DataStore entry (LiveOps/config) reloaded every minute, and at once when a
--     MessagingService "LiveOps" message arrives, so events and offers change without republishing:
--       { "schedule": [ { "key": "DoubleDrops", "start": 1793000000, "finish": 1793259200 } ],
--         "announcement": "Bleach week starts Friday!", "featured": [ "SummonMythic", "ProBundle" ],
--         "codes": { "SPIRIT": { "rewards": [ { "kind": "boost", "minutes": 15 } ], "expires": 1793600000 } },
--         "update": { "at": 1793379600, "title": "SPIRIT TEMPLE", "teaser": "Final Aizen awaits" } }
--   * limited event fighters: while an event with `fighters` runs, hub altar drops sometimes become one,
--   * weekly quests: 5 per week (LiveOps.quests), progress from the week's start, claimed with the Rewards
--     remote "Weekly" <id>; all 5 claimed opens the weekly chest ("WeeklyChest"). Player attribute
--     Weekly = JSON { week, quests = [ { id, text, have, need, claimed } ], chest = "locked"|"ready"|"claimed" }.
-- Studio: workspace attribute DebugEvent = "<key>" runs that event for 30 minutes ("" clears it);
-- DebugFeatured = "SummonMythic,ProBundle" stands in for the config's featured list; player attribute
-- DebugWeekly = true fills this week's quests.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local LiveOps = require(Shared.LiveOps)
local Goals = require(Shared.Goals)
local Fighters = require(Shared.Fighters)
local Net = require(Shared.Net)

local LiveOpsService = {}
local FX = Net.get("FX")
local Data, Rewards

local config = { schedule = {}, featured = {}, codes = {} }
local debugSchedule = {}
local running -- the event key now running (nil: none)
local rng = Random.new()

local EFFECTS = { "dropLuck", "mutationLuck", "cash", "train" }

local function all(text, color)
	for _, player in Players:GetPlayers() do
		FX:FireClient(player, "Banner", { text = text, color = color })
	end
end

local function loadConfig()
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, "LiveOps")
	if not ok or not store then
		return
	end
	local got, raw = pcall(store.GetAsync, store, "config")
	if not got or type(raw) ~= "string" then
		return
	end
	local parsed, value = pcall(HttpService.JSONDecode, HttpService, raw)
	if parsed and type(value) == "table" then
		config = {
			schedule = type(value.schedule) == "table" and value.schedule or {},
			announcement = type(value.announcement) == "string" and value.announcement or nil,
			featured = type(value.featured) == "table" and value.featured or {},
			codes = type(value.codes) == "table" and value.codes or {}, -- shared/Codes.lua
			update = type(value.update) == "table" and value.update or nil, -- the next update's countdown
		}
	end
end

local function schedule()
	local list = table.clone(debugSchedule)
	for _, e in config.schedule do
		table.insert(list, e)
	end
	return list
end

local function publish()
	local now = os.time()
	local key, finish = LiveOps.current(now, schedule())
	local event = key and LiveOps.Events[key]
	ReplicatedStorage:SetAttribute("LiveEvent", key)
	ReplicatedStorage:SetAttribute("LiveEventEnds", finish)
	for _, name in EFFECTS do
		ReplicatedStorage:SetAttribute("Live_" .. name, event and event.effects[name] or nil)
	end
	local nextKey, nextAt = LiveOps.next(now, schedule())
	ReplicatedStorage:SetAttribute("NextEvent", nextKey)
	ReplicatedStorage:SetAttribute("NextEventAt", nextAt)
	ReplicatedStorage:SetAttribute("Announcement", config.announcement)
	-- The update board in the hub (client/UpdateBoard.lua).
	local updateAt, updateTitle, updateTeaser = LiveOps.nextUpdate(now, config.update)
	local pushed = type(config.update) == "table" and tonumber(config.update.at) and tonumber(config.update.at) > now
	if not pushed and not LiveOps.WeeklyUpdates then
		updateAt = nil -- no real update announced: the board stays hidden (client/UpdateBoard.lua)
	end
	ReplicatedStorage:SetAttribute("UpdateAt", updateAt)
	ReplicatedStorage:SetAttribute("UpdateTitle", updateTitle or "NEW UPDATE")
	ReplicatedStorage:SetAttribute("UpdateTeaser", updateTeaser or "New fighters, a new event and a new code!")
	local featured = table.concat(config.featured, ",")
	if RunService:IsStudio() and workspace:GetAttribute("DebugFeatured") then
		featured = workspace:GetAttribute("DebugFeatured")
	end
	ReplicatedStorage:SetAttribute("Featured", featured)
	if key ~= running then
		running = key
		if event then
			all(string.upper(event.title) .. " HAS STARTED!", event.color)
		end
	end
end

-- A limited fighter for a hub altar drop of `rarity`, or nil (DropService asks).
function LiveOpsService.eventFighter(rarity)
	local event = running and LiveOps.Events[running]
	if not event or not event.fighters or rng:NextNumber() > LiveOps.EventFighterChance then
		return nil
	end
	local pool = {}
	for _, key in event.fighters do
		local f = Fighters.ByKey[key]
		if f and f.rarity == rarity then
			table.insert(pool, f)
		end
	end
	return #pool > 0 and pool[rng:NextInteger(1, #pool)] or nil
end

-- ------------------------------------------------------------------ weekly quests

local function weekly(data)
	local week = LiveOps.week(os.time())
	if not data.weekly or data.weekly.week ~= week then
		local base = {}
		for _, q in LiveOps.quests(week) do
			base[q.metric] = Goals.metric(data, q.metric)
		end
		data.weekly = { week = week, base = base, claimed = {}, chest = false }
	end
	return data.weekly
end

local function publishWeekly(player, data)
	local w = weekly(data)
	local list, all5 = {}, true
	for _, q in LiveOps.quests(w.week) do
		local have = math.max(0, Goals.metric(data, q.metric) - (w.base[q.metric] or 0))
		table.insert(list, { id = q.id, text = q.text, have = have, need = q.need, claimed = w.claimed[q.id] == true })
		all5 = all5 and w.claimed[q.id] == true
	end
	local chest = w.chest and "claimed" or all5 and "ready" or "locked"
	local json = HttpService:JSONEncode({ week = w.week, quests = list, chest = chest })
	if player:GetAttribute("Weekly") ~= json then
		player:SetAttribute("Weekly", json)
	end
end

local function claimQuest(player, id)
	local data = Data.get(player)
	if not data or type(id) ~= "string" then
		return
	end
	local w = weekly(data)
	for _, q in LiveOps.quests(w.week) do
		if q.id == id and not w.claimed[id] then
			local have = Goals.metric(data, q.metric) - (w.base[q.metric] or 0)
			if have >= q.need then
				w.claimed[id] = true
				local line = Rewards.pay(player, data, q.reward)
				Data.changed(player)
				FX:FireClient(player, "Reward", { title = "WEEKLY QUEST!", line = line })
				publishWeekly(player, data)
			end
			return
		end
	end
end

local function claimChest(player)
	local data = Data.get(player)
	if not data then
		return
	end
	local w = weekly(data)
	for _, q in LiveOps.quests(w.week) do
		if not w.claimed[q.id] then
			return
		end
	end
	if w.chest then
		return
	end
	w.chest = true
	Rewards.pay(player, data, LiveOps.WeeklyChest) -- a Legendary fighter, with the reveal
	Data.changed(player)
	publishWeekly(player, data)
end

function LiveOpsService.start(DataService, RewardsService)
	Data, Rewards = DataService, RewardsService
	RewardsService.remoteCodes = function()
		return config.codes
	end
	task.spawn(loadConfig)
	task.spawn(pcall, function() -- subscribing can wait (and fails in Studio without API access)
		MessagingService:SubscribeAsync("LiveOps", function()
			task.spawn(function()
				loadConfig()
				publish()
			end)
		end)
	end)
	Net.get("Rewards").OnServerEvent:Connect(function(player, kind, value)
		if kind == "Weekly" then
			claimQuest(player, value)
		elseif kind == "WeeklyChest" then
			claimChest(player)
		end
	end)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("DebugEvent"):Connect(function()
			local key = workspace:GetAttribute("DebugEvent")
			table.clear(debugSchedule)
			if key and LiveOps.Events[key] then
				table.insert(debugSchedule, { key = key, start = os.time() - 1, finish = os.time() + 1800 })
			end
			publish()
		end)
		-- Player attribute DebugWeekly = true fills this week's quests (to test claiming and the chest).
		Players.PlayerAdded:Connect(function(player)
			player:GetAttributeChangedSignal("DebugWeekly"):Connect(function()
				local data = player:GetAttribute("DebugWeekly") and Data.get(player)
				if data then
					player:SetAttribute("DebugWeekly", nil)
					local w = weekly(data)
					for _, q in LiveOps.quests(w.week) do
						w.base[q.metric] = math.min(w.base[q.metric] or 0, Goals.metric(data, q.metric) - q.need)
					end
					publishWeekly(player, data)
				end
			end)
		end)
	end
	task.spawn(function()
		local sinceLoad = 0
		while true do
			publish()
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				if data then
					publishWeekly(player, data)
				end
			end
			task.wait(5)
			sinceLoad += 5
			if sinceLoad >= 60 then
				sinceLoad = 0
				task.spawn(loadConfig)
			end
		end
	end)
end

return LiveOpsService
