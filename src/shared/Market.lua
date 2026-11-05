-- The Fighter Market (server/Services/MarketService.lua): five fighters on display on the hub's market
-- street, bought with Robux by walking up to one. The stock is the same for the whole server and rolls
-- over every Market.Period seconds, often with rare mutations, so there is always something new to look
-- at. Each fighter's price comes from what it earns: one developer product per price tier (MarketT1-T5 in
-- shared/Products.lua). Slot 5 is the featured pedestal: always a Mythic or Secret with a big mutation.
-- A fixed item (not a random roll), so it's allowed where paid random items are restricted.
-- Pure data and maths (the same roll on client, server and in tests).
local Fighters = require(script.Parent.Fighters)

local Market = {}
Market.Period = 300
Market.Slots = 5

local RARITY = { Epic = 40, Legendary = 38, Mythic = 18, Secret = 4 }
local MUTATION = { Normal = 30, Golden = 32, Diamond = 22, Rainbow = 13, Huge = 3 }
local FEATURED_RARITY = { Mythic = 80, Secret = 20 }
local FEATURED_MUTATION = { Diamond = 30, Rainbow = 55, Huge = 15 }
-- Secrets stay Normal or Golden in the market (a Rainbow or Huge Secret is for luck, not for sale).
local SECRET_MUTATIONS = { Normal = 50, Golden = 50 }

-- Price: the fighter's rarity sets the tier, its mutation raises it (a Rainbow always costs more than the
-- same rarity plain), capped at the top tier. Products MarketT1-T5 (shared/Products.lua).
Market.Tiers = { "MarketT1", "MarketT2", "MarketT3", "MarketT4", "MarketT5" }
local RARITY_TIER = { Epic = 1, Legendary = 2, Mythic = 3, Secret = 4 }
local MUTATION_STEP = { Normal = 0, Golden = 1, Diamond = 1, Rainbow = 2, Huge = 2 }

function Market.epoch(now)
	return math.floor(now / Market.Period)
end

function Market.endsAt(epoch)
	return (epoch + 1) * Market.Period
end

local function generator(seed)
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end

local function pick(weights, nextRandom)
	local keys, total = {}, 0
	for k, w in weights do
		table.insert(keys, k)
		total += w
	end
	table.sort(keys) -- pairs order isn't stable; the roll must be
	local roll = nextRandom() * total
	for _, k in keys do
		roll -= weights[k]
		if roll <= 0 then
			return k
		end
	end
	return keys[#keys]
end

-- The product key for a fighter with `mutation`.
function Market.tierFor(key, mutation)
	local fighter = Fighters.ByKey[key]
	local tier = (RARITY_TIER[fighter and fighter.rarity] or 1) + (MUTATION_STEP[mutation] or 0)
	return Market.Tiers[math.clamp(tier, 1, #Market.Tiers)]
end

-- The stock for one period: { { key, mutation, product } } for slots 1..Market.Slots, no fighter twice.
function Market.stock(epoch)
	local nextRandom = generator(epoch * 7919 + 4243)
	for _ = 1, 4 do
		nextRandom()
	end
	local out, used = {}, {}
	for slot = 1, Market.Slots do
		local featured = slot == Market.Slots
		local rarity = pick(featured and FEATURED_RARITY or RARITY, nextRandom)
		local pool = Fighters.ByRarity[rarity] or {}
		-- A random start, then the first one not already on show.
		local fighter
		local start = math.floor(nextRandom() * #pool)
		for i = 0, #pool - 1 do
			local f = pool[(start + i) % #pool + 1]
			if not used[f.key] then
				fighter = f
				break
			end
		end
		if fighter then
			used[fighter.key] = true
			local mutation =
				pick(rarity == "Secret" and SECRET_MUTATIONS or featured and FEATURED_MUTATION or MUTATION, nextRandom)
			table.insert(
				out,
				{ key = fighter.key, mutation = mutation, product = Market.tierFor(fighter.key, mutation) }
			)
		end
	end
	-- The four regular plinths run cheapest to priciest; the featured one (the last slot) stays as is.
	local featured = table.remove(out)
	table.sort(out, function(x, y)
		return table.find(Market.Tiers, x.product) < table.find(Market.Tiers, y.product)
	end)
	table.insert(out, featured)
	return out
end

return Market
