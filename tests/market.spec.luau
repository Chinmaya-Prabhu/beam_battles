-- Offline checks for shared/Market.lua (run with tests/run_rules.sh).
local Market, Fighters, Config, Products = MARKET()
local seenMut, featuredTiers = {}, {}
for epoch = 1, 400 do
	local a, b = Market.stock(epoch), Market.stock(epoch)
	assert(#a == Market.Slots, "five on display")
	local keys = {}
	for i, item in a do
		assert(b[i].key == item.key and b[i].mutation == item.mutation, "same stock everywhere")
		assert(Fighters.ByKey[item.key], "a real fighter")
		assert(Config.Mutations[item.mutation] and not Config.Mutations[item.mutation].zone, "a market mutation")
		assert(not keys[item.key], "no fighter twice")
		keys[item.key] = true
		assert(Products.ByKey[item.product] and Products.ByKey[item.product].market, "priced by a market product")
		local r = Fighters.ByKey[item.key].rarity
		if r == "Secret" then
			assert(item.mutation == "Normal" or item.mutation == "Golden", "no Rainbow/Huge Secrets for sale")
		end
		seenMut[item.mutation] = true
	end
	local f = a[Market.Slots]
	local r = Fighters.ByKey[f.key].rarity
	assert(r == "Mythic" or r == "Secret", "featured is Mythic or Secret")
	featuredTiers[f.product] = true
end
for _, m in { "Normal", "Golden", "Diamond", "Rainbow", "Huge" } do
	assert(seenMut[m], "mutation shows up: " .. m)
end
assert(not featuredTiers.MarketT1 and not featuredTiers.MarketT2, "featured is never a cheap tier")
-- Price tiers climb with income.
local last = 0
for _, t in Market.Tiers do
	local p = Products.ByKey[t].price
	assert(p > last, "tiers get pricier")
	last = p
end
-- Within a rarity, a mutation always costs at least as much as plain, and Rainbow more than plain.
for _, f in Fighters.Launch do
	local plain = table.find(Market.Tiers, Market.tierFor(f.key, "Normal"))
	assert(table.find(Market.Tiers, Market.tierFor(f.key, "Golden")) >= plain, "golden >= plain")
	if plain < #Market.Tiers then
		assert(table.find(Market.Tiers, Market.tierFor(f.key, "Rainbow")) > plain, "rainbow > plain " .. f.key)
	end
end
-- The regular plinths are sorted cheapest first.
for epoch = 1, 100 do
	local st = Market.stock(epoch)
	for i = 2, Market.Slots - 1 do
		assert(table.find(Market.Tiers, st[i].product) >= table.find(Market.Tiers, st[i - 1].product), "sorted")
	end
end
print("Market: checks passed")
