-- The training ladder (docs/TRAINING_PLAN.md): Power (permanent, drives body, aura and clash strength)
-- and Cash (earned by the fighters on the stands; it buys stands, stations and weights). Clicks anywhere
-- train at the gear's rate; an owned station trains by itself while you stand at it. Everything here is data and pure maths so tests can run it outside Roblox.
local Training = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Reps per second a client may send (matches the clash's mash cap).
Training.MaxCps = 14
-- How long after the last rep a player still counts as training (for the pose other clients see).
Training.ActiveFor = 0.6

-- Worn on both wrists and both ankles. `look` is read by the client's gear builder.
-- Each tier doubles the click gain. Bought with Cash, and only once the weight's zone is open (offline cash would
-- otherwise buy weights far ahead). Prices from tools/sim/cash_weights.py: each one a few minutes of the
-- income a player has when they reach that zone. `power` is the Power needed too (like stations), so cash
-- kept through a rebirth can't buy the whole ladder back at once.
Training.Gear = {
	{ name = "Cloth Wraps", mult = 1, cost = 0, zone = nil, look = "cloth" },
	{ name = "Wooden Weights", mult = 2, cost = 1e3, zone = "Hub", look = "wood" },
	{ name = "Stone Weights", mult = 4, cost = 5e3, zone = "Hub", look = "stone" },
	{ name = "Iron Weights", mult = 8, cost = 250e3, power = 10e3, zone = "Blossom", look = "iron" },
	{ name = "Steel Weights", mult = 16, cost = 6e6, power = 150e3, zone = "Blossom", look = "steel" },
	{ name = "Gold Weights", mult = 32, cost = 100e6, power = 2e6, zone = "Ninja", look = "gold" },
	{ name = "Chakra Seals", mult = 64, cost = 1e9, power = 20e6, zone = "Ninja", look = "chakra" },
	{ name = "Sea Rock Shackles", mult = 128, cost = 8e9, power = 150e6, zone = "Pirate", look = "seastone" },
	{ name = "Diamond Weights", mult = 256, cost = 60e9, power = 750e6, zone = "Pirate", look = "diamond" },
	{ name = "Gravity Rings", mult = 512, cost = 400e9, power = 8e9, zone = "Walled", look = "gravity" },
	-- Rebirth-gated: only sold to players with at least `rebirth` rebirths.
	{ name = "Turtle Shell Weights", mult = 800, cost = 2e12, power = 8e9, zone = "Walled", look = "turtle", rebirth = 1 },
	{ name = "Warrior Armor Weights", mult = 1600, cost = 15e12, power = 30e9, zone = "Walled", look = "saiyan", rebirth = 3 },
	{ name = "Limitless Instinct Weights", mult = 5000, cost = 100e12, power = 150e9, zone = "Walled", look = "ultra", rebirth = 5 },
	-- Premium (Robux gamepasses, shared/Products.lua): never bought with Cash and never outgrown: they give the
	-- larger of their own `mult` and `boost` times the player's best ladder weight (Training.gearMult).
	-- Nine-Tail Fox (R$299) is the entry tier, Eternal Dragon (R$599) the top one: the later tier always trains best
	-- (a player owning both wears the higher tier).
	{
		name = "Nine-Tail Fox Weights",
		mult = 700,
		boost = 2,
		cost = 0,
		premium = "ChakraWeights",
		look = "kyuubi",
	},
	{ name = "Eternal Dragon Weights", mult = 1000, boost = 3, cost = 0, premium = "DragonWeights", look = "dragon" },
}
Training.LadderTop = 13 -- the last cash tier (the premium tiers come after)

-- The tier a player wears (its look): their premium weights if they own any (those always train best),
-- else their ladder tier.
function Training.bestGear(ladderTier, premiumTier)
	if premiumTier and Training.Gear[premiumTier] then
		return premiumTier
	end
	return ladderTier or 1
end

-- The click multiplier of a player's weights: the ladder tier's, or with premium weights the larger of their
-- own multiplier and `boost` times the ladder's.
function Training.gearMult(ladderTier, premiumTier)
	local ladder = Training.gear(ladderTier).mult
	local p = premiumTier and Training.Gear[premiumTier]
	if not p then
		return ladder
	end
	return math.max(p.mult, ladder * (p.boost or 1))
end

-- How rare a weight is, for stock odds and card colours.
function Training.gearRarity(tier)
	local g = Training.Gear[tier]
	if g.premium then
		return g.mult >= 1000 and "Secret" or "Mythic"
	elseif g.rebirth then
		return g.rebirth >= 5 and "Secret" or g.rebirth >= 3 and "Mythic" or "Legendary"
	end
	return ({ "Common", "Common", "Common", "Uncommon", "Uncommon", "Rare", "Rare", "Epic", "Epic", "Legendary" })[tier]
		or "Common"
end

-- Stations by zone: a punching post and a heavy bag in each (all training is punching). `style` picks the
-- training pose; `power` is the Power needed to buy, `price` the
-- cash.
Training.Stations = {
	Hub = {
		{ key = "PunchPost", name = "Punching Post", style = "punch", mult = 2, power = 0, price = 0 },
		{ key = "Sandbag", name = "Sandbag", style = "punch", mult = 3, power = 200, price = 30e3 },
	},
	Blossom = {
		{ key = "AcademyPost", name = "Academy Post", style = "punch", mult = 5, power = 2e3, price = 500e3 },
		{ key = "AcademyBag", name = "Academy Bag", style = "punch", mult = 8, power = 10e3, price = 3e6 },
	},
	Ninja = {
		{ key = "NinjaPost", name = "Makiwara Post", style = "punch", mult = 12, power = 200e3, price = 20e6 },
		{ key = "NinjaBag", name = "Straw Bag", style = "punch", mult = 20, power = 1e6, price = 100e6 },
	},
	Pirate = {
		{ key = "PiratePost", name = "Mast Post", style = "punch", mult = 30, power = 12e6, price = 600e6 },
		{ key = "PirateBag", name = "Sea Sack", style = "punch", mult = 50, power = 60e6, price = 3e9 },
	},
	Walled = {
		{ key = "WalledPost", name = "Iron Post", style = "punch", mult = 75, power = 600e6, price = 15e9 },
		{ key = "WalledBag", name = "Titan Bag", style = "punch", mult = 120, power = 3e9, price = 80e9 },
	},
}
-- Saves from before every station became a post or a bag (DataService renames them on load).
Training.RenamedStations = {
	Bench = "AcademyPost",
	Treadmill = "AcademyBag",
	Boulder = "NinjaPost",
	Waterfall = "NinjaBag",
	Anchor = "PiratePost",
	Rowing = "PirateBag",
	WallClimb = "WalledPost",
	Gravity = "WalledBag",
}
Training.StationByKey = {}
for zone, list in Training.Stations do
	for _, s in list do
		s.zone = zone
		Training.StationByKey[s.key] = s
	end
end

-- Aura tiers by Power. Tier 0 has no aura. `color` is the flame, `accent` the sparks or arcs.
Training.Auras = {
	{ power = 1e3, name = "Trainee", color = rgb(90, 200, 255), accent = rgb(220, 245, 255) },
	{ power = 1e4, name = "Fighter", color = rgb(90, 235, 120), accent = rgb(210, 255, 210) },
	{ power = 1e5, name = "Super", color = rgb(255, 205, 40), accent = rgb(255, 250, 170) },
	{ power = 1e6, name = "Elite", color = rgb(235, 40, 50), accent = rgb(255, 170, 120) },
	{ power = 1e7, name = "Master", color = rgb(150, 60, 235), accent = rgb(220, 170, 255) },
	{ power = 1e8, name = "Ultra", color = rgb(210, 225, 240), accent = rgb(140, 200, 255) },
	{ power = 1e9, name = "God", color = rgb(255, 255, 255), accent = rgb(255, 255, 255), rainbow = true },
}
Training.RookieTitle = "Rookie"

-- Champion multipliers by rarity (the follower's training boost); the mutation's own multiplier stacks.
Training.ChampionMult = {
	Common = 1.1,
	Uncommon = 1.25,
	Rare = 1.5,
	Epic = 2,
	Legendary = 3,
	Mythic = 5,
	Secret = 10,
}

-- A mutated Champion trains a little harder (gentler than the mutation's income multiplier, so a Huge
-- Secret is x30, not x250).
Training.MutationMult = {
	Normal = 1,
	Golden = 1.25,
	Cursed = 1.35,
	Sage = 1.35,
	Haki = 1.35,
	Titan = 1.35,
	Diamond = 1.5,
	Rainbow = 2,
	Huge = 3,
}

-- The training multiplier of a fighter by rarity and mutation (1 with no Champion).
function Training.championMult(rarity, mutation)
	if not rarity then
		return 1
	end
	return (Training.ChampionMult[rarity] or 1) * (Training.MutationMult[mutation or "Normal"] or 1)
end

-- Rebirth: each one adds this much to the permanent training multiplier. The first needs RebirthBase
-- Power, each next one RebirthStep times more. Rebirth resets Power, gear and stations; fighters,
-- the base, cash and zones stay.
Training.RebirthBonus = 0.5
Training.RebirthBase = 12e9 -- the Walled City boss (the long game after the four zones)
Training.RebirthStep = 5

-- Power needed for the next rebirth after `done` rebirths.
function Training.rebirthCost(done)
	return Training.RebirthBase * Training.RebirthStep ^ (done or 0)
end

function Training.gear(tier)
	return Training.Gear[math.clamp(tier or 1, 1, #Training.Gear)]
end

-- The aura tier index for `power` (0 = none) and its entry.
function Training.aura(power)
	local tier = 0
	for i, a in Training.Auras do
		if power >= a.power then
			tier = i
		end
	end
	return tier, Training.Auras[tier]
end

function Training.title(power)
	local _, a = Training.aura(power)
	return a and a.name or Training.RookieTitle
end

-- Progress (0..1) from the current aura tier to the next, and the next threshold (nil at the top).
function Training.toNext(power)
	local tier = Training.aura(power)
	local nextAura = Training.Auras[tier + 1]
	if not nextAura then
		return 1, nil
	end
	local from = tier > 0 and Training.Auras[tier].power or 0
	-- Log scale so the bar moves at a steady pace across a 10x tier.
	local a, b = math.log10(math.max(from, 1)), math.log10(nextAura.power)
	return math.clamp((math.log10(math.max(power, 1)) - a) / (b - a), 0, 1), nextAura.power
end

-- Body scale for `power`: 0 at nothing, 1 at 1B. Width and depth grow most, height a little.
function Training.bodyScale(power)
	local s = math.clamp(math.log10(math.max(power, 1)) / 9, 0, 1)
	return { width = 1 + 0.6 * s, depth = 1 + 0.6 * s, height = 1 + 0.15 * s }
end

-- Power for one rep. `boost` covers paid multipliers (2x Power pass, 2x Training boost);
-- `premiumTier` is the player's premium weights, if any (Training.gearMult).
function Training.perRep(gearTier, stationMult, championMult, rebirths, boost, premiumTier)
	return Training.gearMult(gearTier, premiumTier)
		* (stationMult or 1)
		* (championMult or 1)
		* (1 + (rebirths or 0) * Training.RebirthBonus)
		* (boost or 1)
end

-- Whether a player may buy gear tier `tier`: any cash tier above what they have, in a zone they have
-- opened (`zones` = the save's zone set; the hub is always open), with the rebirths, Power and cash it needs.
function Training.canBuyGear(currentTier, tier, cash, rebirths, zones, power)
	local g = Training.Gear[tier]
	if not g or g.premium or tier <= (currentTier or 1) then
		return false, "ALREADY OWNED"
	end
	if g.rebirth and (rebirths or 0) < g.rebirth then
		return false, "NEEDS REBIRTH " .. g.rebirth
	end
	if g.zone and g.zone ~= "Hub" and not (zones and zones[g.zone]) then
		return false, "OPEN THE ZONE FIRST"
	end
	if (power or 0) < (g.power or 0) then
		return false, "NEEDS POWER"
	end
	if cash < g.cost then
		return false, "NOT ENOUGH CASH"
	end
	return true
end

-- Winning a fighter also trains you: this many reps (at your best station's rate) by its rarity, so fighting
-- for drops beats standing at a bag.
Training.WinReps = { Common = 150, Uncommon = 200, Rare = 300, Epic = 500, Legendary = 800, Mythic = 1500, Secret = 3000 }
-- An owned station trains by itself while you stand on it (no clicks): this many reps a second.
Training.StationRate = 4

-- The best multiplier among `stations` (the save's owned set), 1 with none.
function Training.bestStationMult(stations)
	local best = 1
	for key in stations or {} do
		local s = Training.StationByKey[key]
		if s and s.mult > best then
			best = s.mult
		end
	end
	return best
end

-- Whether a player may buy station `key`.
function Training.canBuyStation(key, power, cash, owned)
	local s = Training.StationByKey[key]
	if not s then
		return false, "UNKNOWN STATION"
	end
	if owned then
		return false, "ALREADY OWNED"
	end
	if power < s.power then
		return false, "NEEDS POWER"
	end
	if cash < s.price then
		return false, "NOT ENOUGH CASH"
	end
	return true
end

-- How many reps to accept from a batch: at most MaxCps per second since the last batch, plus a little
-- slack for network jitter.
function Training.accept(claimed, elapsed)
	local allowed = math.floor(Training.MaxCps * math.min(elapsed, 2) * 1.25 + 2)
	return math.clamp(math.floor(claimed), 0, allowed)
end

return Training
