-- The Fighter Roll (tools/sim/roll_economy.py and tools/sim/pacing.py tuned these numbers): a cheap, instant,
-- repeatable roll for a random fighter, paid with cash, always one tap away (client/Roll.lua,
-- server/Services/RollService.lua).
--   * Banners: the hub banner from the start, and one per cleared zone (its fighters, better odds, a higher
--     price). Each rolls from its pool (shared/Fighters.lua ByPool), the odds shown on the panel.
--   * Pity, shared by every banner and saved: at least a Rare every 10 rolls, an Epic every 50, a Legendary
--     every 500. Pity never hands out a Mythic or a Secret: those are always luck.
--   * Auto-sell (on for Commons by default): a sold fighter pays ROLL.sellSeconds of its own income.
-- Pure data and maths, so tests can run it outside Roblox.
local Roll = {}

-- `after`: the zone whose boss opens it (nil = from the start).
Roll.Banners = {
	{
		id = "Hub",
		title = "SKY DOJO ROLL",
		pool = "Hub",
		cost = 5e3,
		odds = { Common = 52, Uncommon = 32, Rare = 13, Epic = 2.8, Legendary = 0.2 },
	},
	{
		id = "Blossom",
		title = "BLOSSOM ROLL",
		after = "Blossom",
		pool = "Blossom",
		cost = 300e3,
		odds = { Uncommon = 50, Rare = 35, Epic = 13.5, Legendary = 1.5 },
	},
	{
		id = "Ninja",
		title = "HIDDEN LEAF ROLL",
		after = "Ninja",
		pool = "Ninja",
		cost = 15e6,
		odds = { Rare = 52, Epic = 38, Legendary = 9.85, Mythic = 0.15 },
	},
	{
		id = "Pirate",
		title = "GRAND PIRATE ROLL",
		after = "Pirate",
		pool = "Pirate",
		cost = 300e6,
		odds = { Epic = 58, Legendary = 39, Mythic = 2.98, Secret = 0.02 },
	},
}
Roll.ById = {}
for i, b in Roll.Banners do
	b.order = i
	Roll.ById[b.id] = b
end

Roll.Pity = { { every = 10, rarity = "Rare" }, { every = 50, rarity = "Epic" }, { every = 500, rarity = "Legendary" } }
-- Roll tickets: a roll costs one ticket plus a small cash fee (`fee` x the banner's cost), and tickets come from
-- playing the game (tools/sim/pacing.py), so rolling is the reward for fighting, training and stealing, never a
-- way round them: `drop` per drop fight won, `guardian` per guardian or boss beaten for the first time, one
-- per `reps` training reps, `steal` per fighter stolen, `start` when the tutorial ends.
Roll.Tickets = { start = 5, drop = 3, guardian = 10, reps = 200, steal = 5, fee = 0.2 }
Roll.SellSeconds = 10
Roll.Cooldown = 0.35 -- seconds between rolls (the reveal of a Common takes about this long)
Roll.AutoEvery = 1.2 -- seconds between rolls with Auto Roll on

local ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local function rank(rarity)
	return table.find(ORDER, rarity) or 0
end
Roll.rank = rank

-- Whether a banner is open to a player who has beaten the bosses in `bosses` ({ [zone] = true }).
function Roll.open(banner, bosses)
	return banner.after == nil or bosses[banner.after] == true
end

-- The banner's odds with luck applied: everything rarer than its most common rarity is `luck` times as likely.
function Roll.lucky(banner, luck)
	local out, lowest = {}, math.huge
	for rarity in banner.odds do
		lowest = math.min(lowest, rank(rarity))
	end
	for rarity, w in banner.odds do
		out[rarity] = rank(rarity) == lowest and w or w * (luck or 1)
	end
	return out
end

-- One roll: the rarity it lands on, given `pity` ({ [rarity] = rolls since that tier }, updated in place) and a
-- random number source `next()` returning 0..1.
function Roll.rarity(banner, pity, luck, next)
	local weights = Roll.lucky(banner, luck)
	local total = 0
	for _, w in weights do
		total += w
	end
	local r = next() * total
	local got
	for _, rarity in ORDER do
		local w = weights[rarity]
		if w then
			if r < w then
				got = rarity
				break
			end
			r -= w
		end
	end
	got = got or ORDER[1]
	-- Pity: the counters tick, and a full one lifts the roll to its tier.
	local floor
	for _, p in Roll.Pity do
		pity[p.rarity] = (pity[p.rarity] or 0) + 1
		if pity[p.rarity] >= p.every and (not floor or rank(p.rarity) > rank(floor)) then
			floor = p.rarity
		end
	end
	if floor and rank(got) < rank(floor) then
		got = floor
	end
	for _, p in Roll.Pity do
		if rank(got) >= rank(p.rarity) then
			pity[p.rarity] = 0
		end
	end
	return got
end

-- The nearest pity goal: rolls left and its rarity ("RARE IN 3").
function Roll.nextPity(pity)
	local best, left
	for _, p in Roll.Pity do
		local n = p.every - (pity[p.rarity] or 0)
		if not left or n < left then
			best, left = p.rarity, n
		end
	end
	return best, left
end

-- Chance (0..1) of `rarity` on this banner (for "1 in X" on the reveal).
function Roll.chance(banner, rarity)
	local total = 0
	for _, w in banner.odds do
		total += w
	end
	return (banner.odds[rarity] or 0) / total
end

return Roll
