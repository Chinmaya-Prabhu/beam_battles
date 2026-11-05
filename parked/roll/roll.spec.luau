-- Offline checks for shared/Roll.lua (run with tests/run_rules.sh): pity floors, and pity never gives a
-- Mythic or Secret.
local Roll = ROLL()
local hub = Roll.ById.Hub
local seed = 1
local function rand()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local pity = {}
local sinceRare, worstGap = 0, 0
local counts = {}
for _ = 1, 20000 do
	local r = Roll.rarity(hub, pity, 1, rand)
	counts[r] = (counts[r] or 0) + 1
	if Roll.rank(r) >= Roll.rank("Rare") then
		worstGap = math.max(worstGap, sinceRare + 1)
		sinceRare = 0
	else
		sinceRare += 1
	end
end
assert(worstGap <= 10, "a Rare or better at least every 10 rolls, got a gap of " .. worstGap)
assert(not counts.Mythic and not counts.Secret, "the hub banner never gives a Mythic or Secret")
assert((counts.Legendary or 0) >= 20000 / 500, "at least one Legendary per 500 rolls")
-- A banner with Mythic and Secret: pity lifts to Legendary at most.
local pirate = Roll.ById.Pirate
local always = function()
	return 0 -- (the most common rarity every time)
end
local p = { Legendary = 499 }
assert(Roll.rarity(pirate, p, 1, always) == "Legendary", "the 500th roll is a Legendary")
assert(Roll.open(Roll.ById.Ninja, { Ninja = true }) and not Roll.open(Roll.ById.Ninja, {}), "banners open on their boss")
local rarity, left = Roll.nextPity({ Rare = 7, Epic = 10, Legendary = 100 })
assert(rarity == "Rare" and left == 3, "the nearest pity goal")
print("Roll: checks passed")
