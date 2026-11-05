-- Offline checks for shared/Stock.lua (run with tests/run_rules.sh).
local Training = TRAINING()
local Stock = STOCK(Training)
-- Deterministic, Stock.Slots distinct Ki tiers, sorted.
local a = Stock.roll(123456789, 5000, 0)
local b = Stock.roll(123456789, 5000, 0)
assert(#a == Stock.Slots, "slot count")
for i, t in a do
	assert(b[i] == t, "same roll on both sides")
	assert(t >= 2 and t <= Training.LadderTop, "only Ki tiers")
	assert(i == 1 or a[i - 1] < t, "sorted and distinct")
end
-- A restock changes something within a few tries; periods differ.
local changed = false
for salt = 1, 5 do
	local c = Stock.roll(123456789, 5000, salt)
	for i = 1, #a do
		if c[i] ~= a[i] then
			changed = true
		end
	end
end
assert(changed, "restock rerolls")
-- Rare weights show up less often than common ones over many periods.
local seen = {}
for e = 1, 4000 do
	for _, t in Stock.roll(42, e, 0) do
		seen[t] = (seen[t] or 0) + 1
	end
end
assert((seen[2] or 0) > (seen[13] or 0) * 5, "Ultra Instinct is scarce")
assert((seen[13] or 0) > 0, "but it does appear")
-- The next tier is always for sale; grace covers the previous period only briefly.
assert(Stock.has(1, 1000, 0, 4, 5), "next tier always stocked")
local now = 5000 * Stock.Period + 2
local old = Stock.roll(7, 4999, 0)
local cur = Stock.roll(7, 5000, 0)
for _, t in old do
	if not table.find(cur, t) and t ~= 2 then
		assert(Stock.has(7, now, 0, 1, t), "grace sells the old stock")
		assert(not Stock.has(7, now + Stock.Grace, 0, 1, t), "but not for long")
	end
end
print("Stock: checks passed")
