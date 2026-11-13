-- Rolls and odds for table spawns. Pure functions so they can be unit tested.
local Config = require(script.Parent.Config)
local Fighters = require(script.Parent.Fighters)

local Odds = {}

local function pick(weights, order, rng)
	local total = 0
	for _, key in order do
		total += weights[key] or 0
	end
	local roll = rng:NextNumber(0, total)
	for _, key in order do
		local w = weights[key] or 0
		if roll < w then
			return key
		end
		roll -= w
	end
	-- Floating-point edge: fall back to the last key with weight.
	for i = #order, 1, -1 do
		if (weights[order[i]] or 0) > 0 then
			return order[i]
		end
	end
	return nil
end

-- The tier's weights with luck applied: every rarity rarer than the tier's most common one is `luck`
-- times as likely (Server Luck).
function Odds.lucky(tier, luck)
	local weights = Config.Tiers[tier].weights
	if not luck or luck == 1 then
		return weights
	end
	local out, first = {}, true
	for _, key in Config.RarityOrder do
		local w = weights[key]
		if w then
			out[key] = first and w or w * luck
			first = false
		end
	end
	return out
end

function Odds.rollRarity(tier, rng, luck)
	return pick(Odds.lucky(tier, luck), Config.RarityOrder, rng)
end

-- The fighters an altar in `poolName` (a zone, or "Hub") can drop at `rarity`: its zone's own, or if the zone
-- has none of that rarity, the nearest lower rarity it has, else any launch fighter of that rarity.
function Odds.poolFor(poolName, rarity)
	local pools = poolName and Fighters.ByPool[poolName]
	if pools then
		for i = table.find(Config.RarityOrder, rarity), 1, -1 do
			local list = pools[Config.RarityOrder[i]]
			if list and #list > 0 then
				return list
			end
		end
	end
	return Fighters.ByRarity[rarity]
end

-- A fighter for an altar of `tier` in `poolName` (defaults to every launch fighter).
function Odds.rollFighter(tier, rng, luck, poolName)
	local rarity = Odds.rollRarity(tier, rng, luck)
	local pool = Odds.poolFor(poolName, rarity)
	local fighter = pool[rng:NextInteger(1, #pool)]
	return fighter, fighter.rarity
end

-- `weights` moved `steps` rarities up (a rarity past Secret stays Secret).
function Odds.shiftRarity(weights, steps)
	if (steps or 0) <= 0 then
		return weights
	end
	local out = {}
	local order = Config.RarityOrder
	for key, w in weights do
		local i = math.min(table.find(order, key) + steps, #order)
		out[order[i]] = (out[order[i]] or 0) + w
	end
	return out
end

-- Guardian spawn weights for `rung` in zone pool `poolName`: the ladder's odds (Config.GuardianOdds), shifted
-- up only as far as the zone's pool starts (Pirate starts at Epic: two steps), then
-- capped at the top so the rarest are a treat, not every spawn (the pools have one or two fighters there).
local GUARDIAN_CAP = { Mythic = 0.15, Secret = 0.01 } -- (tools/sim/pacing.py: Secrets take about a week)
function Odds.guardianWeights(rung, poolName)
	local base = Config.GuardianOdds[rung] or Config.GuardianOdds[1]
	local order = Config.RarityOrder
	local pools = poolName and Fighters.ByPool[poolName] or {}
	local lowest = #order
	for i, rarity in order do
		if pools[rarity] and #pools[rarity] > 0 then
			lowest = math.min(lowest, i)
		end
	end
	local steps = math.max(0, lowest - table.find(order, "Uncommon"))
	local out = Odds.shiftRarity(base, steps)
	local total = 0
	for _, w in out do
		total += w
	end
	-- Excess Secret falls to Mythic, excess Mythic to Legendary.
	for _, pair in { { "Secret", "Mythic" }, { "Mythic", "Legendary" } } do
		local key, down = pair[1], pair[2]
		local cap = total * GUARDIAN_CAP[key]
		if (out[key] or 0) > cap then
			out[down] = (out[down] or 0) + out[key] - cap
			out[key] = cap
		end
	end
	return out
end

-- A fighter from explicit rarity `weights` (guardian spawns), with luck on everything but the most common.
function Odds.rollWeighted(weights, rng, luck, poolName)
	local lucky, first = {}, true
	for _, key in Config.RarityOrder do
		local w = weights[key]
		if w then
			lucky[key] = (first or not luck) and w or w * luck
			first = false
		end
	end
	local rarity = pick(lucky, Config.RarityOrder, rng)
	local pool = Odds.poolFor(poolName, rarity)
	local fighter = pool[rng:NextInteger(1, #pool)]
	return fighter, fighter.rarity
end

-- The mutation weights in `zone` (zone mutations only roll in their own zone).
local function mutationWeights(zone, luck)
	local weights = {}
	for key, m in Config.Mutations do
		if not m.zone or m.zone == zone then
			weights[key] = key == "Normal" and m.weight or m.weight * (luck or 1)
		end
	end
	return weights
end

-- `luck` multiplies every mutation's weight except Normal (x2 Mutation Luck); `zone` adds that zone's own.
function Odds.rollMutation(rng, luck, zone)
	local weights = mutationWeights(zone, luck)
	return pick(weights, Config.MutationOrder, rng)
end

-- Chance (0..1) that one spawn at `tier` is exactly this fighter with this mutation.
function Odds.chance(tier, key, mutation)
	local fighter = Fighters.ByKey[key]
	local weights = Config.Tiers[tier].weights
	local total = 0
	for _, w in weights do
		total += w
	end
	local mutationTotal = 0
	local weights2 = mutationWeights(fighter.pool)
	for _, w in weights2 do
		mutationTotal += w
	end
	local rarityChance = (weights[fighter.rarity] or 0) / total
	local pool = fighter.pool and Fighters.ByPool[fighter.pool] and Fighters.ByPool[fighter.pool][fighter.rarity]
		or Fighters.ByRarity[fighter.rarity]
		or { fighter }
	return rarityChance / #pool * (weights2[mutation] or 0) / mutationTotal
end

-- A fighter's own odds as a chance (0..1), the same at every altar: Config.BaseOdds for its rarity, spread 0.7x to
-- 1.6x by its key and rounded to two figures, then the mutation's own rarity on top.
function Odds.base(key, mutation)
	local fighter = Fighters.ByKey[key]
	local hash = 0
	for i = 1, #key do
		hash = (hash * 31 + string.byte(key, i)) % 91
	end
	local oneIn = Config.BaseOdds[fighter.rarity] * (0.7 + hash / 100)
	local unit = 10 ^ (math.floor(math.log10(oneIn)) - 1)
	oneIn = math.floor(oneIn / unit + 0.5) * unit
	local weights, total = mutationWeights(fighter.pool), 0
	for _, w in weights do
		total += w
	end
	return (weights[mutation or "Normal"] or weights.Normal) / total / oneIn
end

-- How much luck an altar of `tier` gives this fighter: its own odds against the real chance there (nil: the altar
-- doesn't drop it). This is what makes the big number honest, so a plate always shows it beside the odds.
function Odds.altarLuck(tier, key, mutation)
	local chance = Odds.chance(tier, key, mutation)
	if chance <= 0 then
		return nil
	end
	local luck = chance / Odds.base(key, mutation)
	local unit = 10 ^ math.max(math.floor(math.log10(luck)) - 1, 0)
	return math.floor(luck / unit + 0.5) * unit
end

function Odds.income(key, mutation, stars)
	return Fighters.ByKey[key].income * Config.Mutations[mutation].mult * (1 + (stars or 0) * Config.Stars.bonus)
end

-- "1 in 112,222": the whole number with thousands separators (a big number is more exciting than "112K").
function Odds.label(chance)
	if chance <= 0 then
		return "Never"
	end
	local whole = tostring(math.max(1, math.floor(1 / chance + 0.5)))
	local digits = string.reverse(whole)
	digits = string.gsub(digits, "(%d%d%d)", "%1,")
	whole = string.reverse(digits)
	if string.sub(whole, 1, 1) == "," then
		whole = string.sub(whole, 2)
	end
	return "1 in " .. whole
end

return Odds
