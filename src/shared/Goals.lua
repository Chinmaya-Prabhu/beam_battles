-- The goals checklist after the tutorial (docs/FTUE_PLAN.md §2). Three show at a time; each points at the
-- next thing to learn and pays a reward. After the list, repeatable goals keep the HUD busy: their targets
-- count from when they were handed out (`relative`).
-- `metric` names a number TutorialService reads from the player's data (Goals.metric below). `done` goals
-- are yes/no (shown 0/1), for metrics that don't start at zero (gear tier, stands).
local Format = require(script.Parent.Format)

local Goals = {}

Goals.List = {
	{ id = "power10k", text = "Reach 10K Power", metric = "power", need = 1e4, cash = 20000 },
	{ id = "stone", text = "Buy Stone Weights", metric = "gear", need = 3, done = true, cash = 10000 },
	{ id = "wins3", text = "Win 3 clashes", metric = "wins", need = 3, cash = 30000 },
	{ id = "collect5k", text = "Collect $50K at your base", metric = "collected", need = 50000, cash = 20000 },
	{ id = "stand5", text = "Unlock stand 5", metric = "stands", need = 5, done = true, cash = 100000 },
	{ id = "blossom", text = "Enter the Walled City", metric = "zone_Walled", need = 1, cash = 50000 },
	{ id = "bench", text = "Buy the Iron Post", metric = "station_WalledPost", need = 1, cash = 500000 },
	{ id = "guardian1", text = "Beat Guardian 1", metric = "ladder_Walled", need = 1, cash = 100000 },
	{ id = "silver", text = "Clash at a Silver altar", metric = "silver", need = 1, cash = 300000 },
	{ id = "steal", text = "Steal a fighter from a player", metric = "steals", need = 1, cash = 250000 },
	{ id = "boss1", text = "Beat the Walled City boss", metric = "boss_Walled", need = 1, cash = 5000000 },
	{ id = "power1m", text = "Reach 1M Power", metric = "power", need = 1e6, cash = 1000000 },
	{ id = "rebirth", text = "Rebirth", metric = "rebirths", need = 1, boost = 15 },
}

-- After the list: these repeat, each counting from when it was given.
Goals.Repeat = {
	{ id = "r_wins", text = "Win 5 clashes", metric = "wins", need = 5, relative = true, cash = 200000 },
	{ id = "r_collect", text = "Collect $500K", metric = "collected", need = 500000, relative = true, cash = 100000 },
	{ id = "r_steal", text = "Steal 2 fighters", metric = "steals", need = 2, relative = true, cash = 500000 },
}

Goals.ById = {}
for _, list in { Goals.List, Goals.Repeat } do
	for _, g in list do
		Goals.ById[g.id] = g
	end
end

-- The number a goal measures, from the save data.
function Goals.metric(data, name)
	local stats = data.stats or {}
	if name == "power" or name == "gear" or name == "stands" or name == "rebirths" then
		return data[name] or 0
	end
	local kind, key = string.match(name, "^(%a+)_(%a+)$")
	if kind == "zone" then
		return (stats.zones or {})[key] and 1 or 0
	elseif kind == "station" then
		return data.stations[key] and 1 or 0
	elseif kind == "ladder" then
		return data.ladder[key] or 0
	elseif kind == "boss" then
		return data.bosses[key] and 1 or 0
	end
	return stats[name] or 0
end

function Goals.rewardText(g)
	if g.cash then
		return "+" .. Format.cash(g.cash)
	end
	return "2x TRAINING " .. g.boost .. " MIN"
end

return Goals
