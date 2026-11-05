-- Player progress saved to a DataStore (docs/WORLD_PLAN.md §7): zones unlocked, Dojo Ladder rungs cleared,
-- bosses beaten, and the training ladder (docs/TRAINING_PLAN.md): Power, Ki, gear tier, owned stations and
-- rebirths. Cash, fighters and plots join when the economy lands.
-- Loads on join (with retries); saves on leave, on shutdown and every AUTOSAVE seconds when changed.
-- If the store can't be reached (e.g. Studio without API access), the player plays on an in-memory profile
-- that is never written back, so a bad load can never wipe a real save.
-- The client reads progress from player attributes: Zones ("Blossom,Ninja"), Ladder_<Zone>, Boss_<Zone>,
-- Power, Ki, Gear, Stations ("PunchPost,Bench"), Rebirths, and Champion / ChampionMutation /
-- ChampionMult for the equipped fighter, Cash, Stands and Plot (the plot index this session).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Training = require(game:GetService("ReplicatedStorage").Shared.Training)

local DataService = {}

local STORE = "AnimeClash_Progress_v1"
local AUTOSAVE = 90
local profiles = {} -- [player] = { data, dirty, online }
local inflight = 0 -- saves that have been sent and not yet answered (shutdown waits for them)
local loadedSignal = Instance.new("BindableEvent")

-- The player's save key. (The owner can start over on a new slot: Config.OwnerSaveSlot.)
local function saveKey(player)
	local key = "u" .. player.UserId
	if player.UserId == game.CreatorId and Config.OwnerSaveSlot > 0 then
		key ..= "_slot" .. Config.OwnerSaveSlot
	end
	return key
end

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE)
	end)
	store = ok and result or nil
end

local function default()
	local data = {
		version = 1,
		zones = {},
		ladder = {},
		bosses = {},
		power = 0,
		ki = 0,
		gear = 1,
		stations = { PunchPost = true },
		rebirths = 0,
		fighters = {}, -- won fighters: { k = key, m = mutation }
		champion = 0, -- index into fighters (0 = none)
		cash = 0,
		cashX10 = true, -- (new saves start on the big-number scale)
		stands = Config.Plot.startStands, -- stands unlocked on the plot
		stash = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, -- uncollected cash waiting on each stand's pad
		passes = {}, -- gamepasses granted in Studio tests (real ones are checked with Roblox each join)
		boostUntil = {}, -- timed boosts: [key] = os.time() they end
		receipts = {}, -- developer-product purchase ids already granted (newest last)
		marketPending = {}, -- [MarketT product] = { k, m }: the Fighter Market fighter a prompt was for
		firstJoin = os.time(), -- for the Starter Pack window (old saves get it on their next join)
		starterBought = false,
		index = {}, -- every fighter ever owned: [key] = { [mutation] = true } (shared/Collection.lua)
		daily = { streak = 0 }, -- last = the UTC day last claimed (shared/Rewards.lua)
		restocks = 0, -- gear-stall restocks bought (salts the rotating stock, shared/Stock.lua)
		ftue = 1, -- tutorial step (TutorialService); new players start at 1
		goals = {}, -- active goal ids (TutorialService) -> baseline for relative goals
		goalNext = 1, -- next goal in Goals.List to hand out
		stats = { wins = 0, collected = 0, steals = 0, silver = 0, zones = {} },
	}
	for name, zone in Config.Zones do
		if zone.unlocked then
			data.zones[name] = true
		end
	end
	return data
end

local function publish(player, data)
	local list = {}
	for name in data.zones do
		table.insert(list, name)
	end
	table.sort(list)
	player:SetAttribute("Zones", table.concat(list, ","))
	for name in Config.Zones do
		player:SetAttribute("Ladder_" .. name, data.ladder[name] or 0)
		player:SetAttribute("Boss_" .. name, data.bosses[name] == true)
	end
	-- Big numbers (every cash amount x10): older saves' cash moves up with them, once.
	if not data.cashX10 then
		data.cashX10 = true
		data.cash = (data.cash or 0) * 10
		for i, v in data.stash or {} do
			data.stash[i] = v * 10
		end
		data.offlinePending = (data.offlinePending or 0) * 10
	end
	-- Stations renamed when every station became a post or a bag.
	for old, new in Training.RenamedStations do
		if data.stations[old] then
			data.stations[old] = nil
			data.stations[new] = true
		end
	end
	local owned = {}
	for key in data.stations do
		table.insert(owned, key)
	end
	table.sort(owned)
	player:SetAttribute("Stations", table.concat(owned, ","))
	player:SetAttribute("Power", data.power)
	player:SetAttribute("Ki", data.ki)
	player:SetAttribute("Gear", data.gear)
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("RebirthSeen", data.rebirthSeen or 0) -- client/Rebirth.lua: the unlock card shown
	player:SetAttribute("Cash", data.cash)
	player:SetAttribute("Stands", data.stands)
	player:SetAttribute("Restocks", data.restocks)
end

local function load(player)
	local data, online = nil, false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(saveKey(player))
			end)
			if ok then
				data, online = result, true
				break
			end
			warn("[Data] load failed (" .. attempt .. "):", result)
			task.wait(attempt)
		end
	end
	if store and not online and not game:GetService("RunService"):IsStudio() then
		-- The store couldn't be read: playing on, they'd earn progress that is never saved (and the next save
		-- could not tell). Better to make them rejoin.
		player:Kick("We couldn't load your progress. Please rejoin in a minute.")
		return
	end
	local hadSave = type(data) == "table"
	local fresh = default()
	if type(data) == "table" then
		-- A save from before the tutorial existed: that player is not new, so skip it.
		if data.ftue == nil then
			data.ftue = 99
		end
		-- Fill in anything added since this save was written (new unlocked-by-default zones).
		for name in fresh.zones do
			data.zones[name] = true
		end
		-- And fields added since (the training ladder).
		for key, value in fresh do
			if data[key] == nil then
				data[key] = value
			end
		end
	else
		data = fresh
	end
	if not player.Parent then
		return
	end
	if game:GetService("RunService"):IsStudio() and Config.Studio.unlockAllZones then
		for name in Config.Zones do
			data.zones[name] = true
		end
		online = false -- never saved: the unlocks must not reach a real save
	end
	-- One plain line per join, so it is obvious from the Output window whether progress will be kept.
	if online then
		print(
			string.format(
				"[Data] %s: %s; progress WILL be saved",
				player.Name,
				hadSave and "loaded a saved profile" or "new player"
			)
		)
	else
		warn(
			"[Data] "
				.. player.Name
				.. ": the DataStore could not be reached, so progress will NOT be saved this session."
				.. " In Studio: publish the place to Roblox (File > Publish to Roblox) and turn on Game Settings > Security >"
				.. " Enable Studio Access to API Services for THAT experience."
		)
	end
	profiles[player] = { data = data, dirty = false, online = online }
	publish(player, data)
	loadedSignal:Fire(player, data)
end

local function save(player)
	local profile = profiles[player]
	if not (profile and profile.online and profile.dirty and store) then
		return
	end
	profile.dirty = false
	profile.data.lastSeen = os.time() -- for offline earnings (PlotService)
	inflight += 1
	local ok, err = pcall(function()
		store:SetAsync(saveKey(player), profile.data)
	end)
	inflight -= 1
	if not ok then
		profile.dirty = true
		warn("[Data] save failed:", err)
	end
end

-- The player's data table (nil until loaded). Mutate it, then call DataService.changed(player).
function DataService.get(player)
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.changed(player)
	local profile = profiles[player]
	if profile then
		profile.dirty = true
		publish(player, profile.data)
	end
end

-- Saves right away (after a Robux purchase), instead of waiting for the next autosave.
function DataService.saveNow(player)
	local profile = profiles[player]
	if profile then
		profile.dirty = true
		task.spawn(save, player)
	end
end

-- Marks the save dirty without republishing every attribute (for values that change many times a
-- second, like Power and Ki, whose attributes the caller sets itself).
function DataService.touch(player)
	local profile = profiles[player]
	if profile then
		profile.dirty = true
	end
end

-- Studio test grants: nothing more is written to the store this session, so test items can't reach a real save.
function DataService.discardSession(player)
	local profile = profiles[player]
	if profile then
		profile.online = false
		warn("[Data] " .. player.Name .. ": test items were granted, so this session will NOT be saved.")
	end
end

-- Fires once a player's data has loaded (or at once if it already has).
function DataService.onLoaded(callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.data)
	end
	return loadedSignal.Event:Connect(callback)
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local waited = 0
		-- (Also the save PlayerRemoving already sent: closing before it is answered would lose it.)
		while (pending > 0 or inflight > 0) and waited < 25 do -- (Roblox allows about 30 s)
			waited += task.wait(0.25)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
end

return DataService
