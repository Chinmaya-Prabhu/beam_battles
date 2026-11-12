-- The training ladder on the server (docs/TRAINING_PLAN.md). Server-authoritative:
--   * clients send "Reps" batches of clicks on the Train remote; the server accepts at most
--     Training.MaxCps per second, ignores players in a clash, and adds Power at the rate of their
--     gear x station x champion x rebirth multipliers,
--   * stations: walking onto an owned one seats the player on its spot (root anchored) and it trains by
--     itself (Training.StationRate reps a second at its multiplier) until they move or jump (client sends
--     "Leave"); they must step off it before it seats them again. An unowned one's prompt buys it with Cash,
--   * gear stalls sell weights for Cash (only in zones the player has opened),
--   * a won fighter also pays Power (Training.WinReps by rarity at the best owned station's rate),
--   * the body grows with Power (R15 scale values), and crossing an aura tier fires FX "PowerUp" to
--     everyone with a server banner,
--   * every fighter a player wins is saved; the best one (by Training.championMult) is equipped as their
--     Champion automatically, follows them (client/Champion.lua) and multiplies their training.
-- Player attributes it keeps live: Power (also saved via DataService), Training (the pose style while
-- reps are coming in) and TrainStation (the station copy's id while seated).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Training = require(Shared.Training)
local Config = require(Shared.Config)
local Odds = require(Shared.Odds)
local LiveOps = require(Shared.LiveOps)
local Fighters = require(Shared.Fighters)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local GymKit = require(script.Parent.Parent.Zones.GymKit)
local Social = require(script.Parent.SocialService)

local TrainingService = {}
local FX = Net.get("FX")
local remote = Net.get("Train")
local Data, Clash

local GOLD = Color3.fromRGB(255, 214, 80)
local RED = Color3.fromRGB(255, 120, 100)
local GREEN = Color3.fromRGB(120, 255, 150)

local MAX_FIGHTERS = 400 -- saved per player; past this only upgrades replace the weakest
local state = {} -- [player] = { lastBatch, activeUntil, station (GymKit entry) }
local occupant = {} -- [GymKit entry] = player seated there

local function banner(player, text, color)
	FX:FireClient(player, "Banner", { text = text, color = color })
end

local function rootOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

-- Body growth: scale the player's own R15 proportions (remembered at spawn) by the Power curve.
local SCALES = { BodyWidthScale = "width", BodyDepthScale = "depth", BodyHeightScale = "height" }
local function applyBody(player)
	local _, humanoid = rootOf(player)
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local scale = Training.bodyScale(player:GetAttribute("Power") or 0)
	for name, axis in SCALES do
		local value = humanoid:FindFirstChild(name)
		if value then
			local baseValue = humanoid:GetAttribute("Base_" .. name)
			if not baseValue then
				baseValue = value.Value
				humanoid:SetAttribute("Base_" .. name, baseValue)
			end
			local target = baseValue * scale[axis]
			if math.abs(value.Value - target) > 0.004 then
				value.Value = target
			end
		end
	end
end

local function leaveStation(player)
	local s = state[player]
	if not s or not s.station then
		return
	end
	if occupant[s.station] == player then
		occupant[s.station] = nil
	end
	s.left = s.station -- (no auto seat there again until they step off it)
	s.station = nil
	player:SetAttribute("TrainStation", nil)
	local root = rootOf(player)
	if root then
		root.Anchored = false
	end
end

local function seat(player, station)
	local root, humanoid = rootOf(player)
	if not root or not humanoid or humanoid.Health <= 0 or Clash.isBusy(player) then
		return
	end
	if occupant[station] and occupant[station] ~= player then
		return false
	end
	leaveStation(player)
	local s = state[player]
	s.station = station
	occupant[station] = player
	local height = humanoid.HipHeight + root.Size.Y / 2
	root.Anchored = true
	root.CFrame = station.spot + Vector3.new(0, height, 0)
	player:SetAttribute("TrainStation", station.id)
	return true
end

-- ------------------------------------------------------------------ champion

local function fighterMult(entry)
	local fighter = entry and Fighters.ByKey[entry.k]
	return fighter and Training.championMult(fighter.rarity, entry.m) or 1
end

local function publishChampion(player, data)
	local entry = data.fighters[data.champion]
	-- The multiplier first, so clients building the follower already see the new value.
	player:SetAttribute("ChampionMult", entry and fighterMult(entry) or 1)
	player:SetAttribute("ChampionMutation", entry and entry.m or nil)
	player:SetAttribute("Champion", entry and entry.k or nil)
end

-- Saves a fighter in the player's bag (data.fighters; entry.s = the stand it stands on, nil = in the bag).
-- `how`: "carry" (a clash win or a steal: it rides over their head until they place it on a stand,
-- PlotService.hold) or nil (a summon, the market, a gift: straight onto a free stand, else the bag).
-- The first fighter becomes the follower (Champion); after that the player picks it in the Bag.
function TrainingService.addFighter(player, key, mutation, how)
	local data = Data.get(player)
	local fighter = Fighters.ByKey[key]
	if not data or not fighter then
		return
	end
	if TrainingService.onAcquire then
		TrainingService.onAcquire(player, key, mutation or "Normal") -- the Index (RewardsService)
	end
	local entry = { k = key, m = mutation or "Normal" }
	-- A duplicate is never wasted: your best copy gains a star.
	local best
	for _, e in data.fighters do
		if e.k == key and (e.r or 0) < Config.Stars.max then
			if not best or Odds.income(e.k, e.m, e.r) > Odds.income(best.k, best.m, best.r) then
				best = e
			end
		end
	end
	if best then
		best.r = (best.r or 0) + 1
		banner(player, string.upper(fighter.display) .. " POWERED UP! +" .. best.r, Color3.fromRGB(255, 214, 80))
	end
	if fighter.rarity == "Secret" then
		Social.award(player, "FirstSecret")
	end
	local index
	if #data.fighters < MAX_FIGHTERS then
		table.insert(data.fighters, entry)
		index = #data.fighters
	else
		-- A full bag: it replaces the weakest one that isn't following you or on a stand.
		local weakest, weakestMult = nil, math.huge
		for i, e in data.fighters do
			local m = fighterMult(e)
			if m < weakestMult and i ~= data.champion and not e.s then
				weakest, weakestMult = i, m
			end
		end
		if weakest and fighterMult(entry) > weakestMult then
			data.fighters[weakest] = entry
			index = weakest
		end
	end
	if not index then
		return
	end
	local current = data.fighters[data.champion]
	local mult = fighterMult(entry)
	if not current and how ~= "carry" then -- (a carried one isn't also following; fixChampion decides once it's placed)
		data.champion = index
	elseif mult > fighterMult(current) then
		local shown = math.floor(mult * 100 + 0.5) / 100
		banner(player, "STRONGER FIGHTER! x" .. shown .. " TRAINING · MAKE IT FOLLOW YOU IN YOUR BAG", GOLD)
	end
	Data.changed(player)
	publishChampion(player, data)
	if how == "carry" and TrainingService.onCarry then
		TrainingService.onCarry(player, entry)
	elseif TrainingService.onPlace then
		TrainingService.onPlace(player, entry)
	end
	if TrainingService.onFighters then
		TrainingService.onFighters(player) -- the plot shows what stands on its stands
	end
end

-- The follower (Champion) never stands on a stand: a fighter either earns cash on a stand or walks with you
-- and boosts your training (the trade-off). When the follower goes onto a stand (or there is none), the best
-- fighter left in the bag follows instead, or nobody. PlotService calls this after every change.
-- `held`: the entry the player is carrying (it isn't following either).
function TrainingService.fixChampion(player, held)
	local data = Data.get(player)
	if not data then
		return
	end
	local current = data.fighters[data.champion]
	if current and not current.s and current ~= held then
		return
	end
	local best, bestMult = 0, 0
	for i, e in data.fighters do
		local m = fighterMult(e)
		if not e.s and e ~= held and m > bestMult then
			best, bestMult = i, m
		end
	end
	if best == data.champion then
		return
	end
	data.champion = best
	Data.changed(player)
	publishChampion(player, data)
	if current and current.s then
		local next = data.fighters[best]
		local name = Fighters.ByKey[current.k] and string.upper(Fighters.ByKey[current.k].display) or "IT"
		banner(
			player,
			name
				.. " IS EARNING ON A STAND NOW · "
				.. (next and (string.upper(Fighters.ByKey[next.k].display) .. " FOLLOWS YOU") or "NOBODY FOLLOWS YOU"),
			GOLD
		)
	end
end

-- The player picks their follower from the Bag (client/Bag.lua). One on a stand leaves it to follow.
function TrainingService.setChampion(player, index)
	local data = Data.get(player)
	local entry = data and type(index) == "number" and data.fighters[index]
	if not entry then
		return
	end
	if entry.s then
		local name = Fighters.ByKey[entry.k] and string.upper(Fighters.ByKey[entry.k].display) or "IT"
		banner(player, name .. " LEFT STAND " .. entry.s .. " TO FOLLOW YOU (NO CASH FROM IT NOW)", GOLD)
		entry.s = nil
	end
	data.champion = index
	Data.changed(player)
	publishChampion(player, data)
	if TrainingService.onFighters then
		TrainingService.onFighters(player) -- its stand empties
	end
end

-- Removes a saved fighter (stolen), keeping the Champion index right; if it was the Champion, the best
-- remaining fighter takes over. Returns the removed entry.
function TrainingService.removeFighter(player, entry)
	local data = Data.get(player)
	local index = data and table.find(data.fighters, entry)
	if not index then
		return nil
	end
	table.remove(data.fighters, index)
	if data.champion == index then
		local best, bestMult = 0, 0
		for i, e in data.fighters do
			local m = fighterMult(e)
			if m > bestMult then
				best, bestMult = i, m
			end
		end
		data.champion = best
	elseif data.champion > index then
		data.champion -= 1
	end
	Data.changed(player)
	publishChampion(player, data)
	if TrainingService.onFighters then
		TrainingService.onFighters(player)
	end
	return entry
end

-- Studio only: DebugFighter = "ALLNEW" grants these (the new fighters and the daily-reward ones).
local DEBUG_NEW = {
	"Beerus",
	"CellMax",
	"Frieza",
	"Kaido",
	"BigMom",
	"Sengoku",
	"Mihawk",
	"Fujitora",
	"Rayleigh",
	"Doflamingo",
	"Cell",
	"Mahoraga",
	"GoldenFrieza",
	"Tsluffy",
}

-- Zones that open at a Power level (Blossom Academy at 2K): opened the moment the player first reaches it.
local function openZones(player, data)
	for name, zone in Config.Zones do
		if zone.unlockPower and data.power >= zone.unlockPower and not data.zones[name] then
			data.zones[name] = true
			Data.changed(player)
			banner(player, zone.title .. " UNLOCKED!", GOLD)
			FX:FireClient(player, "ZoneUnlocked", { zone = name }) -- client/Tutorial.lua: the big card with GO
		end
	end
end

-- Adds Power, updates the live attributes and fires the tier-up moment.
local function grant(player, data, amount)
	local before = Training.aura(data.power)
	data.power += amount
	data.stats.power = (data.stats.power or 0) + amount -- lifetime, for the leaderboard
	Data.touch(player)
	player:SetAttribute("Power", data.power)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Power.Value = math.floor(math.min(data.power, 9e18))
	end
	openZones(player, data)
	local after, aura = Training.aura(data.power)
	if after > before then
		FX:FireAllClients("PowerUp", { userId = player.UserId, tier = after })
		banner(player, "POWER UP: " .. string.upper(aura.name) .. "!", aura.color)
		if after >= 3 then
			for _, other in Players:GetPlayers() do
				if other ~= player then
					banner(other, player.DisplayName .. " REACHED " .. string.upper(aura.name) .. "!", aura.color)
				end
			end
		end
	end
	applyBody(player)
end

local function gain(player, reps)
	local data = Data.get(player)
	local s = state[player]
	if not data or not s or reps <= 0 then
		return
	end
	local stationMult, style = 1, "punch"
	if s.station then
		local root = rootOf(player)
		if not root or (root.Position - s.station.spot.Position).Magnitude > 8 then
			leaveStation(player)
		else
			local def = Training.StationByKey[s.station.key]
			stationMult, style = def.mult, def.style
		end
	end
	player:SetAttribute("Training", style)
	s.activeUntil = os.clock() + Training.ActiveFor
	local champion = fighterMult(data.fighters[data.champion])
	-- Paid multipliers (MonetizationService) and the tutorial's head start (TutorialService).
	local boost = (player:GetAttribute("TrainBoost") or 1)
		* (player:GetAttribute("TutorialBoost") or 1)
		* LiveOps.mult("train") -- the running LiveOps event (Training Frenzy)
	local premium = player:GetAttribute("PremiumGear")
	local per = Training.perRep(data.gear, stationMult, champion, data.rebirths, boost, premium)
	grant(player, data, per * reps)
	-- LIMIT BREAK (Config.Social.limitBreak): every N reps a burst worth many reps at once, so a long
	-- training session has a beat to chase (client/Social.lua draws the meter and the burst).
	local every = Config.Social.limitBreak
	s.limit = (s.limit or 0) + reps
	if s.limit >= every then
		s.limit -= every
		local bonus = per * Config.Social.limitBreakReps
		grant(player, data, bonus)
		FX:FireClient(player, "LimitBreak", { amount = bonus })
	end
	player:SetAttribute("LimitCount", s.limit)
end

-- Power one click anywhere gives this player right now (rewards scale with it).
function TrainingService.perRep(player)
	local data = Data.get(player)
	if not data then
		return 1
	end
	local boost = player:GetAttribute("TrainBoost") or 1
	local premium = player:GetAttribute("PremiumGear")
	return Training.perRep(data.gear, 1, fighterMult(data.fighters[data.champion]), data.rebirths, boost, premium)
end

-- Power for winning a fighter of `rarity`: Training.WinReps at the best owned station's rate.
function TrainingService.winPower(player, rarity)
	local data = Data.get(player)
	if not data then
		return 0
	end
	local boost = player:GetAttribute("TrainBoost") or 1
	local premium = player:GetAttribute("PremiumGear")
	local per = Training.perRep(
		data.gear,
		Training.bestStationMult(data.stations),
		fighterMult(data.fighters[data.champion]),
		data.rebirths,
		boost,
		premium
	)
	return per * (Training.WinReps[rarity] or Training.WinReps.Common)
end

-- Adds Power from a reward (gifts, dailies, codes, goals): `reps` at the player's click rate, at least `floor`.
function TrainingService.givePower(player, amount)
	local data = Data.get(player)
	if data and amount > 0 then
		grant(player, data, amount)
	end
end

-- Reps from Auto Train (MonetizationService): trained like clicks, skipped mid-clash.
function TrainingService.autoRep(player, reps)
	if Clash and not Clash.isBusy(player) then
		gain(player, reps)
	end
end

local function onStationPrompt(station, player)
	local data = Data.get(player)
	if not data then
		return
	end
	local plot = station.model:GetAttribute("Plot")
	if plot and plot ~= player:GetAttribute("Plot") then
		return -- someone else's base post
	end
	local s = state[player]
	if s and s.station == station then
		leaveStation(player)
		return
	end
	if data.stations[station.key] then
		return -- owned: it seats you by itself when you walk onto it (the prompt is only for buying)
	end
	local def = Training.StationByKey[station.key]
	local ok, why = Training.canBuyStation(station.key, data.power, data.cash, false)
	if not ok then
		if why == "NEEDS POWER" then
			banner(player, "NEEDS " .. Format.short(def.power) .. " POWER", RED)
		else
			banner(player, "NEEDS " .. Format.cash(def.price), RED)
		end
		return
	end
	data.cash -= def.price
	data.stations[station.key] = true
	Data.changed(player)
	banner(player, string.upper(def.name) .. " UNLOCKED! STAND ON IT TO TRAIN", GREEN)
	seat(player, station)
end

-- Buying weights at a stall (Train remote "BuyGear" with the tier, from the stall's window,
-- client/GearShop.lua). Every weight is always for sale (no stock): Cash, the zone and the rebirth gate decide.
local function buyGear(player, tier)
	local data = Data.get(player)
	if not data then
		return
	end
	local g = Training.Gear[tier]
	local ok, why = Training.canBuyGear(data.gear, tier, data.cash, data.rebirths, data.zones, data.power)
	if not ok then
		local text = why == "NOT ENOUGH CASH" and ("NEEDS " .. Format.cash(g.cost))
			or why == "NEEDS POWER" and ("NEEDS " .. Format.short(g.power) .. " POWER")
			or why
		banner(player, text, RED)
		return
	end
	data.cash -= g.cost
	data.gear = tier
	Data.changed(player)
	banner(player, string.upper(g.name) .. " EQUIPPED! x" .. g.mult, GREEN)
	FX:FireAllClients("GearUp", { userId = player.UserId, tier = tier })
end

-- Rebirth (Train remote "Rebirth"): needs Training.rebirthCost(rebirths) Power. Resets Power, gear,
-- stations and the body; adds a rebirth (a permanent +50% training each).
local function rebirth(player)
	local data = Data.get(player)
	if not data then
		return
	end
	local cost = Training.rebirthCost(data.rebirths)
	if data.power < cost then
		banner(player, "REBIRTH NEEDS " .. Format.short(cost) .. " POWER", RED)
		return
	end
	leaveStation(player)
	data.rebirths += 1
	Social.award(player, "Rebirth")
	data.power, data.gear = 0, 1
	data.stations = { PunchPost = true }
	Data.changed(player)
	Data.saveNow(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Power.Value = 0
		leaderstats.Rebirths.Value = data.rebirths
	end
	applyBody(player)
	-- (The reborn player's own moment is drawn by client/Rebirth.lua.)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			banner(other, player.DisplayName .. " REBIRTHED! (" .. data.rebirths .. ")", GOLD)
		end
	end
	FX:FireAllClients("Rebirth", { userId = player.UserId, rebirths = data.rebirths })
end

local function setup(player)
	state[player] = { lastBatch = os.clock(), activeUntil = 0 }
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local power = Instance.new("IntValue")
	power.Name = "Power"
	power.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player
	player.CharacterAdded:Connect(function(character)
		leaveStation(player)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			task.wait(0.5) -- let the avatar's own scale values arrive first
			applyBody(player)
		end
	end)
	if player.Character then
		task.spawn(applyBody, player)
	end
	-- Studio only: set the player attribute DebugGrant from the server command bar to add that much
	-- Power (to check aura tiers, gear and stations without clicking for hours).
	if game:GetService("RunService"):IsStudio() then
		-- And DebugFighter = "Goku" or "Goku:Rainbow" wins that fighter; "ALLNEW" grants every new one.
		player:GetAttributeChangedSignal("DebugFighter"):Connect(function()
			local spec = player:GetAttribute("DebugFighter")
			if type(spec) == "string" and spec ~= "" then
				player:SetAttribute("DebugFighter", nil)
				if spec == "ALLNEW" then
					-- Every fighter added since launch prep, one after another (stands first, then the bag), to look
					-- them over in minutes.
					Data.discardSession(player) -- (they would otherwise be saved to your real account)
					for _, newKey in DEBUG_NEW do
						TrainingService.addFighter(player, newKey, "Normal")
						task.wait(0.2)
					end
					return
				end
				Data.discardSession(player)
				local key, mutation = string.match(spec, "^([^:]+):?(%a*)$")
				TrainingService.addFighter(player, key, mutation ~= "" and mutation or "Normal", "carry")
			end
		end)
		-- DebugWin = "AllMightMode" prints the Power a win of that fighter pays (ClashService.onWin), without a fight.
		player:GetAttributeChangedSignal("DebugWin"):Connect(function()
			local key = player:GetAttribute("DebugWin")
			if type(key) == "string" and key ~= "" and Clash.onWin then
				player:SetAttribute("DebugWin", nil)
				Data.discardSession(player)
				local before = player:GetAttribute("Power") or 0
				local paid = Clash.onWin(player, key)
				print("DebugWin", key, paid, (player:GetAttribute("Power") or 0) - before)
			end
		end)
		player:GetAttributeChangedSignal("DebugGrant"):Connect(function()
			local amount = tonumber(player:GetAttribute("DebugGrant"))
			if amount and amount > 0 then
				player:SetAttribute("DebugGrant", nil)
				Data.discardSession(player)
				local data = Data.get(player)
				if data then
					grant(player, data, amount)
				end
			end
		end)
	end
end

function TrainingService.start(DataService, ClashService)
	Data, Clash = DataService, ClashService
	-- A loss still pays: about 30 taps' worth of Power.
	ClashService.onLoss = function(player)
		local data = Data.get(player)
		if not data then
			return nil
		end
		local power = math.floor(TrainingService.perRep(player) * 30)
		grant(player, data, power)
		return power
	end
	-- A win pays Power by the fighter's rarity (shown on the win card), on top of the fighter.
	ClashService.onWin = function(player, key)
		local data = Data.get(player)
		local fighter = Fighters.ByKey[key]
		if not data or not fighter then
			return nil
		end
		local power = math.floor(TrainingService.winPower(player, fighter.rarity))
		grant(player, data, power)
		return power
	end
	ClashService.onPrize = function(player, key, mutation)
		TrainingService.addFighter(player, key, mutation, "carry") -- a win is carried home
	end
	for _, station in GymKit.List do
		station.prompt.Triggered:Connect(function(player)
			onStationPrompt(station, player)
		end)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		leaveStation(player)
		state[player] = nil
	end)
	DataService.onLoaded(function(player, data)
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			leaderstats.Power.Value = math.floor(math.min(data.power, 9e18))
			leaderstats.Rebirths.Value = data.rebirths
		end
		publishChampion(player, data)
		applyBody(player)
	end)

	remote.OnServerEvent:Connect(function(player, kind, value)
		local s = state[player]
		if not s then
			return
		end
		if kind == "Leave" then
			leaveStation(player)
			return
		elseif kind == "Rebirth" then
			rebirth(player)
			return
		elseif kind == "SeenRebirth" then
			-- Saw the REBIRTH UNLOCKED card for the next rebirth (client/Rebirth.lua): once per rebirth.
			local data = Data.get(player)
			if data and (data.rebirthSeen or 0) <= data.rebirths then
				data.rebirthSeen = data.rebirths + 1
				player:SetAttribute("RebirthSeen", data.rebirthSeen)
				Data.changed(player)
			end
			return
		elseif kind == "BuyGear" then
			-- value = { stall = index, tier = tier }; the player must be standing at that stall.
			local stall = type(value) == "table" and type(value.stall) == "number" and GymKit.Stalls[value.stall]
			local root = rootOf(player)
			if stall and root and type(value.tier) == "number" and (root.Position - stall.position).Magnitude < 20 then
				buyGear(player, value.tier)
			end
			return
		end
		if kind ~= "Reps" or type(value) ~= "number" or value ~= value then
			return
		end
		local now = os.clock()
		local reps = Training.accept(value, now - s.lastBatch)
		s.lastBatch = now
		if Clash.isBusy(player) then
			leaveStation(player)
			return
		end
		gain(player, reps)
	end)

	-- Clear the training pose once reps stop, and unseat anyone moved off their station (teleports,
	-- zone travel, respawns) so the root never stays anchored somewhere else.
	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			for player, s in state do
				if s.activeUntil > 0 and now > s.activeUntil then
					s.activeUntil = 0
					player:SetAttribute("Training", nil)
				end
				if s.station then
					local root = rootOf(player)
					if not root or (root.Position - s.station.spot.Position).Magnitude > 8 then
						leaveStation(player)
					end
				end
			end
		end
	end)

	-- Owned stations train by themselves: stop on one and it seats you and trains (no prompt, no clicks).
	-- Clicks elsewhere stay manual, so the Auto Train pass still matters (anywhere, and on top of this).
	local SEAT_RANGE, CLEAR_RANGE = 4, 7
	local function flat(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local dt = math.min(now - last, 1)
			last = now
			for player, s in state do
				local data = Data.get(player)
				local root, humanoid = rootOf(player)
				if not data or not root or not humanoid or humanoid.Health <= 0 then
					continue
				end
				if s.left and (s.left == s.station or flat(root.Position, s.left.spot.Position) > CLEAR_RANGE) then
					s.left = nil
				end
				if s.station then
					if Clash.isBusy(player) then
						leaveStation(player)
						continue
					end
					s.auto = (s.auto or 0) + Training.StationRate * dt
					local reps = math.floor(s.auto)
					if reps > 0 then
						s.auto -= reps
						gain(player, reps)
					end
					continue
				end
				s.auto = 0
				local v = root.AssemblyLinearVelocity
				if Vector3.new(v.X, 0, v.Z).Magnitude > 3 or Clash.isBusy(player) then
					continue -- (only once they stop on it)
				end
				for _, station in GymKit.List do
					if
						station ~= s.left
						and data.stations[station.key]
						and not occupant[station]
						and flat(root.Position, station.spot.Position) < SEAT_RANGE
						and math.abs(root.Position.Y - station.spot.Position.Y) < 8
					then
						local plot = station.model:GetAttribute("Plot")
						if not plot or plot == player:GetAttribute("Plot") then
							seat(player, station)
							break
						end
					end
				end
			end
		end
	end)
end

return TrainingService
