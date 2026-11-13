-- Offline checks for Odds.guardianWeights (run with tests/run_rules.sh): guardian spawns shift up only as
-- far as each zone's pool starts, and never become mostly Mythic or Secret.
local Odds, Config = ODDS()
for _, zone in { "Blossom", "Ninja", "Pirate", "Walled" } do
	for rung = 1, 6 do
		local w = Odds.guardianWeights(rung, zone)
		local total = 0
		for _, v in w do
			total += v
		end
		assert(math.abs(total - 100) < 1e-6, zone .. " rung " .. rung .. ": weights still sum to 100")
		assert((w.Secret or 0) <= 3 + 1e-6, zone .. " rung " .. rung .. ": Secret at most 3%")
		assert((w.Mythic or 0) <= 15 + 1e-6, zone .. " rung " .. rung .. ": Mythic at most 15%")
	end
end
-- Zones whose pool starts at Common or Uncommon (Walled, Blossom, Ninja) keep the ladder's own odds; Pirate (pool
-- from Epic up) starts two steps higher, the caps holding Mythic and Secret to 15% and 1%.
assert(Odds.guardianWeights(1, "Walled").Uncommon == 60, "Walled rung 1 unshifted")
assert(Odds.guardianWeights(1, "Blossom").Uncommon == 60, "Blossom rung 1 unshifted")
assert(Odds.guardianWeights(1, "Pirate").Epic == 60, "Pirate rung 1 starts at Epic")
assert(Odds.guardianWeights(6, "Pirate").Legendary > 80, "Pirate boss rung mostly Legendary")
print("Odds: checks passed")

-- Odds.label prints the whole number with thousands separators (never "1.2K").
assert(Odds.label(1 / 112222) == "1 in 112,222", "label: " .. Odds.label(1 / 112222))
assert(Odds.label(1 / 1000000) == "1 in 1,000,000", "label: " .. Odds.label(1 / 1000000))
assert(Odds.label(1 / 125) == "1 in 125", "label: " .. Odds.label(1 / 125))
assert(Odds.label(0) == "Never", "label zero")

-- Fighters' own odds: never low, the same at every altar, and an altar's luck is what connects them to the real chance.
do
	local lowest = math.huge
	for key in FIGHTERS().ByKey do
		lowest = math.min(lowest, 1 / Odds.base(key, "Normal"))
	end
	assert(lowest >= 500, "no fighter reads under 1 in 500: " .. lowest)
	assert(Odds.base("Gaara", "Golden") < Odds.base("Gaara", "Normal"), "a mutation is rarer")
	local luck = Odds.altarLuck("Gold", "Gaara", "Normal")
	local real = Odds.chance("Gold", "Gaara", "Normal")
	assert(math.abs(luck * Odds.base("Gaara", "Normal") / real - 1) < 0.1, "altar luck connects the two")
	assert(Odds.altarLuck("Bronze", "Madara", "Normal") == nil, "an altar that never drops it")
	print("Base odds: checks passed")
end
