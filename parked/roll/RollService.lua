-- The Fighter Roll on the server (shared/Roll.lua has the banners, odds and pity; client/Roll.lua the button).
--   * Roll remote "Roll" <banner id>: checks the banner is open (its zone's boss beaten), takes a ticket and the
--     cash fee (Roll.Tickets.fee x the banner's cost), rolls (x3 with the x3 Roll pass), and sends each result
--     back ("Result"). A Mythic or Secret is announced to the whole server.
--   * Tickets (Roll.Tickets) come from playing: drop fights won, first guardian and boss clears, training reps,
--     steals, and 5 when the tutorial ends; the very first roll is free of its fee and at least a Rare.
--   * Roll remote "AutoSell" <bool>: Commons are sold on the spot (on by default) for Roll.SellSeconds of
--     their income.
--   * Luck: x2 while Server Luck runs, x2 for x2 Drop Luck owners, and the live event's drop luck.
--   * Player attributes: RollPity (JSON { [rarity] = rolls since one }), AutoSell, Tickets, FirstRoll.
-- Saved: data.rollPity, data.autoSell, data.tickets, data.repTickets (reps toward the next ticket), data.rolls.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Roll = require(Shared.Roll)
local Odds = require(Shared.Odds)
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local LiveOps = require(Shared.LiveOps)
local Products = require(Shared.Products)
local Net = require(Shared.Net)

local RollService = {}
local Data, Training, Plots, Monetization
local remote = Net.get("Roll")
local FX = Net.get("FX")
local rng = Random.new()
local last = {} -- [player] = os.clock() of their last roll

local function publish(player, data)
	local pity = data.rollPity
	player:SetAttribute("RollPity", HttpService:JSONEncode(pity))
	player:SetAttribute("AutoSell", data.autoSell ~= false)
	player:SetAttribute("Tickets", data.tickets or 0)
	player:SetAttribute("FirstRoll", (data.rolls or 0) == 0 or nil)
end

local function luck(player)
	local l = LiveOps.mult("dropLuck")
	if workspace:GetServerTimeNow() < (ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0) then
		l *= 2
	end
	if player:GetAttribute("DropLuck") then
		l *= Products.DropLuck
	end
	return l
end

local function rollOnce(player, data, banner)
	data.rollPity = data.rollPity or {}
	local rarity = Roll.rarity(banner, data.rollPity, luck(player), function()
		return rng:NextNumber()
	end)
	local pool = Odds.poolFor(banner.pool, rarity)
	local fighter = pool[rng:NextInteger(1, #pool)]
	local mutation = Odds.rollMutation(rng, player:GetAttribute("MutationLuck") and Products.MutationLuck or 1)
	local result = {
		key = fighter.key,
		mutation = mutation,
		rarity = fighter.rarity,
		banner = banner.id,
		chance = Roll.chance(banner, fighter.rarity) / #pool * (Config.Mutations[mutation].weight / 100),
		-- The near miss: one roll in eight flicks past a rarer fighter before landing (client/Roll.lua).
		near = Roll.rank(fighter.rarity) < 5 and rng:NextNumber() < 0.125,
	}
	if data.autoSell ~= false and fighter.rarity == "Common" and mutation == "Normal" then
		local income = Odds.income(fighter.key, mutation)
		Plots.addCash(player, income * Roll.SellSeconds)
		result.sold = income * Roll.SellSeconds
	else
		Training.addFighter(player, fighter.key, mutation, "roll")
	end
	if Roll.rank(fighter.rarity) >= Roll.rank("Mythic") then
		FX:FireAllClients("Banner", {
			text = string.upper(player.DisplayName)
				.. " ROLLED A "
				.. string.upper(fighter.rarity)
				.. "! "
				.. string.upper(fighter.display),
			color = Config.Rarities[fighter.rarity].color,
		})
	end
	return result
end

local function onRoll(player, bannerId)
	local data = Data.get(player)
	local banner = type(bannerId) == "string" and Roll.ById[bannerId]
	if not data or not banner or not Roll.open(banner, data.bosses) then
		return
	end
	if os.clock() - (last[player] or 0) < Roll.Cooldown then
		return
	end
	local first = (data.rolls or 0) == 0
	local fee = first and 0 or math.floor(banner.cost * Roll.Tickets.fee)
	if (data.tickets or 0) < 1 or data.cash < fee then
		return
	end
	last[player] = os.clock()
	data.tickets -= 1
	data.cash -= fee
	local count = Monetization and Monetization.has(player, "TripleRoll") and 3 or 1
	local results = {}
	player:SetAttribute("Rolling", true) -- (quiets the bag's own banners: the reveal shows the fighter)
	for _ = 1, count do
		table.insert(results, rollOnce(player, data, banner))
	end
	-- The very first roll is at least a Rare.
	if first and Roll.rank(results[1].rarity) < Roll.rank("Rare") then
		local pool = Fighters.ByRarity.Rare
		local pick = pool[rng:NextInteger(1, #pool)]
		Training.addFighter(player, pick.key, "Normal", "roll")
		results[1] = { key = pick.key, mutation = "Normal", rarity = "Rare", banner = banner.id, chance = 0.13 }
	end
	player:SetAttribute("Rolling", nil)
	data.rolls = (data.rolls or 0) + count
	Data.changed(player)
	publish(player, data)
	remote:FireClient(player, "Result", results)
end

-- Adds `n` roll tickets (a "+n TICKETS" pop on the player's screen).
function RollService.giveTickets(player, n)
	local data = Data.get(player)
	if data and n > 0 then
		data.tickets = (data.tickets or 0) + n
		publish(player, data)
		Data.touch(player)
		FX:FireClient(player, "Tickets", { amount = n })
	end
end

function RollService.start(deps)
	Data, Training, Plots, Monetization = deps.Data, deps.Training, deps.Plots, deps.Monetization
	Data.onLoaded(function(player, data)
		data.rollPity = data.rollPity or {}
		data.tickets = data.tickets or 0
		publish(player, data)
	end)
	-- Where tickets come from.
	local T = Roll.Tickets
	local prize = deps.Clash.onPrize
	deps.Clash.onPrize = function(player, ...)
		if prize then
			prize(player, ...)
		end
		RollService.giveTickets(player, T.drop)
	end
	deps.Zone.onGuardian = function(player)
		RollService.giveTickets(player, T.guardian)
	end
	deps.Training.onReps = function(player, reps)
		local data = Data.get(player)
		if data then
			data.repTickets = (data.repTickets or 0) + reps
			if data.repTickets >= T.reps then
				local n = data.repTickets // T.reps
				data.repTickets -= n * T.reps
				RollService.giveTickets(player, n)
			end
		end
	end
	local steal = Plots.onSteal
	Plots.onSteal = function(player, ...)
		if steal then
			steal(player, ...)
		end
		RollService.giveTickets(player, T.steal)
	end
	remote.OnServerEvent:Connect(function(player, kind, value)
		if kind == "Roll" then
			onRoll(player, value)
		elseif kind == "AutoSell" and type(value) == "boolean" then
			local data = Data.get(player)
			if data then
				data.autoSell = value
				publish(player, data)
				Data.changed(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return RollService
