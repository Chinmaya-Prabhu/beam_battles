-- Offline checks for shared/Rewards.lua and shared/Collection.lua (run with tests/run_rules.sh).
local Rewards = REWARDS()
local Collection = COLLECTION()
-- Gifts unlock in order and only once.
local claimed = {}
assert(not Rewards.giftReady(1, 179, claimed), "gift 1 waits 3 min")
assert(Rewards.giftReady(1, 180, claimed), "gift 1 at 3 min")
claimed[1] = true
assert(not Rewards.giftReady(1, 9999, claimed), "only once")
local i, left = Rewards.nextGift(400, claimed)
assert(i == 2 and left == 80, "next gift countdown")
local last = Rewards.Gifts[#Rewards.Gifts]
assert(last.min == 55 and last.kind == "fighter" and last.rarity == "Legendary", "55 min Legendary")
for k = 1, #Rewards.Gifts do
	claimed[k] = true
end
assert(Rewards.nextGift(1e6, claimed) == nil, "all claimed")
-- Daily streak.
local open, day = Rewards.daily(nil, 0, 100)
assert(open and day == 1, "first claim is day 1")
open, day = Rewards.daily(100, 1, 100)
assert(not open, "once a day")
open, day = Rewards.daily(100, 1, 101)
assert(open and day == 2, "consecutive day climbs")
open, day = Rewards.daily(100, 5, 103)
assert(open and day == 1, "missed day resets")
open, day = Rewards.daily(100, 9, 101)
assert(day == 7, "caps at day 7")
assert(Rewards.Daily[7].rarity == "Mythic", "day 7 is a Mythic")
assert(Rewards.amount({ kind = "ki", reps = 10, floor = 500 }, 1, 0) == 500, "floor")
assert(Rewards.amount({ kind = "cash", seconds = 100, floor = 5 }, 1, 20) == 2000, "income scaled")
-- Collection.
local index = {}
assert(Collection.cashMult(index) == 1, "empty book")
local series = Collection.Series[#Collection.Series]
for _, f in Collection.BySeries[series] do
	assert(Collection.add(index, f.key, "Normal"), "new entry")
end
assert(not Collection.add(index, Collection.BySeries[series][1].key, "Normal"), "dupe is not new")
assert(Collection.add(index, Collection.BySeries[series][1].key, "Golden"), "new mutation is new")
local done = Collection.completed(index)
assert(#done == 1 and done[1] == series, "series complete")
assert(math.abs(Collection.cashMult(index) - 1.1) < 1e-9, "+10% per series")
print("Rewards: checks passed")
