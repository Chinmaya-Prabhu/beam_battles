-- The Index (docs/RETENTION_PLAN.md §5): every fighter a player has ever owned, by series. Completing a
-- series (owning each of its fighters at least once, any mutation) adds Collection.SeriesBonus to their
-- cash multiplier for good and earns that series' badge, shown over their base. Mutations are tracked too
-- (index[key] = { Normal = true, Golden = true, ... }) for the book's extra pips.
local Fighters = require(script.Parent.Fighters)

local Collection = {}
Collection.SeriesBonus = 0.1

-- Series names in book order (biggest first) and their fighters.
Collection.Series = {}
Collection.BySeries = {}
for _, f in Fighters.Launch do
	if not Collection.BySeries[f.series] then
		Collection.BySeries[f.series] = {}
		table.insert(Collection.Series, f.series)
	end
	table.insert(Collection.BySeries[f.series], f)
end
table.sort(Collection.Series, function(a, b)
	local na, nb = #Collection.BySeries[a], #Collection.BySeries[b]
	if na ~= nb then
		return na > nb
	end
	return a < b
end)

-- Owned / total for one series.
function Collection.progress(index, series)
	local have = 0
	for _, f in Collection.BySeries[series] do
		if index[f.key] then
			have += 1
		end
	end
	return have, #Collection.BySeries[series]
end

-- The completed series, in book order.
function Collection.completed(index)
	local out = {}
	for _, series in Collection.Series do
		local have, total = Collection.progress(index, series)
		if have == total then
			table.insert(out, series)
		end
	end
	return out
end

function Collection.cashMult(index)
	return 1 + #Collection.completed(index) * Collection.SeriesBonus
end

-- Records a fighter; returns true if it is new to the book (key or mutation).
function Collection.add(index, key, mutation)
	mutation = mutation or "Normal"
	local entry = index[key]
	if not entry then
		index[key] = { [mutation] = true }
		return true
	end
	if not entry[mutation] then
		entry[mutation] = true
		return true
	end
	return false
end

return Collection
