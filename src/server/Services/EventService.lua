-- Server-wide events (Config.Events, docs/RETENTION_PLAN.md §3). The schedule runs on the server clock, so
-- it is the same in every server and players can plan round it. ReplicatedStorage attributes for clients
-- (client/Events.lua):
--   NextRush        server time of the next Secret Rush
--   RushAt, RushPos when the announced rush drops, and where (cleared once it has dropped)
--   StormUntil      the Luck Storm runs until then (DropService multiplies luck while it does)
--   NextStorm       server time of the next storm
-- Studio: workspace attribute DebugRush = true starts a rush now; DebugStorm = true starts a storm.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local Net = require(Shared.Net)

local EventService = {}
local E = Config.Events
local FX = Net.get("FX")
local rng = Random.new()
local Drops

local PURPLE = Color3.fromRGB(220, 140, 255)
local GOLD = Color3.fromRGB(255, 214, 80)

local function all(text, color)
	for _, player in Players:GetPlayers() do
		FX:FireClient(player, "Banner", { text = text, color = color })
	end
end

-- A hub altar not in a clash.
local function pickAltar()
	local list = {}
	for index, altar in Drops.Altars do
		if not altar.zone and not altar.locked then
			table.insert(list, index)
		end
	end
	return #list > 0 and list[rng:NextInteger(1, #list)] or nil
end

local function rush(warn)
	local index = pickAltar()
	if not index then
		return
	end
	local altar = Drops.Altars[index]
	local at = workspace:GetServerTimeNow() + warn
	ReplicatedStorage:SetAttribute("RushAt", at)
	ReplicatedStorage:SetAttribute("RushPos", altar.stand)
	all("SECRET RUSH IN " .. math.floor(warn) .. "s! FOLLOW THE BEAM!", PURPLE)
	task.delay(warn, function()
		-- If a clash took the altar meanwhile, move to another.
		if altar.locked then
			index = pickAltar() or index
			altar = Drops.Altars[index]
		end
		local rarity = rng:NextNumber() < E.rushSecret and "Secret" or "Mythic"
		local pool = Fighters.ByRarity[rarity]
		Drops.clear(index)
		Drops.drop(index, { key = pool[rng:NextInteger(1, #pool)].key, mutation = "Normal" })
		ReplicatedStorage:SetAttribute("RushAt", nil)
		task.delay(20, function()
			if not ReplicatedStorage:GetAttribute("RushAt") then
				ReplicatedStorage:SetAttribute("RushPos", nil)
			end
		end)
	end)
end

local function storm(length)
	local now = workspace:GetServerTimeNow()
	ReplicatedStorage:SetAttribute("StormUntil", now + length)
	all("LUCK STORM! x" .. E.stormLuck .. " LUCK FOR " .. math.floor(length / 60) .. " MIN!", GOLD)
	FX:FireAllClients("Storm", { untilTime = now + length })
end

-- The next time (server clock) at or after `now` that fits `every` seconds offset by `offset`.
local function nextAt(now, every, offset)
	return math.ceil((now - offset) / every) * every + offset
end

function EventService.start(DropService)
	Drops = DropService
	task.spawn(function()
		local lastRush, lastStorm = nil, nil
		while true do
			local now = workspace:GetServerTimeNow()
			local rushTime = nextAt(now + E.rushWarn, E.rushEvery, E.rushOffset)
			ReplicatedStorage:SetAttribute("NextRush", rushTime)
			if rushTime - now <= E.rushWarn and lastRush ~= rushTime then
				lastRush = rushTime
				rush(rushTime - now)
			end
			-- A storm runs through the first stormLength seconds of each hour (joining mid-storm still counts).
			local hourStart = math.floor(now / E.stormEvery) * E.stormEvery
			if now - hourStart < E.stormLength and lastStorm ~= hourStart then
				lastStorm = hourStart
				storm(hourStart + E.stormLength - now)
			end
			ReplicatedStorage:SetAttribute("NextStorm", hourStart + E.stormEvery)
			task.wait(1)
		end
	end)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("DebugRush"):Connect(function()
			if workspace:GetAttribute("DebugRush") then
				workspace:SetAttribute("DebugRush", nil)
				rush(10)
			end
		end)
		workspace:GetAttributeChangedSignal("DebugStorm"):Connect(function()
			if workspace:GetAttribute("DebugStorm") then
				workspace:SetAttribute("DebugStorm", nil)
				storm(60)
			end
		end)
	end
end

return EventService
