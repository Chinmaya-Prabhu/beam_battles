-- The gear stalls' rotating stock (docs/SHOP_RESEARCH.md): every Stock.Period seconds each player's stalls
-- restock with Stock.Slots weights rolled from the whole cash ladder, rarer weights less often. The player's
-- next tier is always in stock so progression never waits on luck; the rolled slots let a lucky player
-- skip ahead. The roll is deterministic (user id, period, restock count) so the client shows exactly
-- what the server will sell. "Restock now" (a Robux product) bumps the restock count.
local Training = require(script.Parent.Training)

local Stock = {}
Stock.Period = 300
Stock.Slots = 3
Stock.Grace = 15 -- seconds after a restock that the previous stock still sells (a click in flight)
Stock.Weights = { Common = 40, Uncommon = 25, Rare = 14, Epic = 8, Legendary = 4, Mythic = 2, Secret = 1 }

function Stock.epoch(now)
	return math.floor(now / Stock.Period)
end

-- When the stock of `epoch` runs out (server time).
function Stock.endsAt(epoch)
	return (epoch + 1) * Stock.Period
end

-- A small seeded generator (Park-Miller), so the roll is the same on client, server and in tests.
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

-- The rolled tiers (ascending) for a player in one period.
function Stock.roll(userId, epoch, salt)
	local nextRandom = generator(math.abs(userId) % 1000003 * 7 + epoch * 7919 + (salt or 0) * 104729 + 1)
	for _ = 1, 4 do
		nextRandom()
	end
	local pool = {}
	for tier = 2, Training.LadderTop do
		table.insert(pool, { tier = tier, weight = Stock.Weights[Training.gearRarity(tier)] or 1 })
	end
	local out = {}
	for _ = 1, math.min(Stock.Slots, #pool) do
		local total = 0
		for _, e in pool do
			total += e.weight
		end
		local roll = nextRandom() * total
		for i, e in pool do
			roll -= e.weight
			if roll <= 0 or i == #pool then
				table.insert(out, e.tier)
				table.remove(pool, i)
				break
			end
		end
	end
	table.sort(out)
	return out
end

-- Whether `tier` is sold to this player right now (or was a moment ago, within Stock.Grace).
function Stock.has(userId, now, salt, currentTier, tier)
	if tier == (currentTier or 1) + 1 then
		return true
	end
	local epoch = Stock.epoch(now)
	if table.find(Stock.roll(userId, epoch, salt), tier) then
		return true
	end
	return now - epoch * Stock.Period < Stock.Grace and table.find(Stock.roll(userId, epoch - 1, salt), tier) ~= nil
end

return Stock
