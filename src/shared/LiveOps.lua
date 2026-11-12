-- LiveOps (docs/LIVEOPS.md): timed events, the weekly calendar, weekly quests and limited event fighters.
-- Pure data and maths (tests run it outside Roblox); server/Services/LiveOpsService.lua runs it live and
-- lets a remote config (DataStore + MessagingService) override the calendar without republishing.
--
-- Events: each has `effects` (multipliers the game reads through LiveOps.mult) and optional `fighters`:
-- limited fighters from the held-back roster that only drop while the event runs.
local LiveOps = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

LiveOps.Events = {
	DoubleDrops = {
		title = "Double Drops",
		desc = "Every altar rolls twice as rare.",
		color = rgb(255, 205, 60),
		effects = { dropLuck = 2 },
	},
	MutationWeek = {
		title = "Mutation Week",
		desc = "Mutations happen three times as often everywhere.",
		color = rgb(180, 90, 255),
		effects = { mutationLuck = 3 },
	},
	GoldenRush = {
		title = "Golden Rush",
		desc = "Your stands earn double cash.",
		color = rgb(255, 180, 40),
		effects = { cash = 2 },
	},
	TrainingFrenzy = {
		title = "Training Frenzy",
		desc = "Every click trains twice as hard.",
		color = rgb(255, 120, 60),
		effects = { train = 2 },
	},
	-- Limited fighters: held back from the launch roster, only during their event.
	SoulSociety = {
		title = "Soul Blade Invasion",
		desc = "Soul Blades fighters appear at the hub altars. Limited time!",
		color = rgb(120, 200, 255),
		effects = { dropLuck = 1.5 },
		fighters = { "Rukia", "Toshiro", "Byakuya", "Ichigo", "Kisuke", "Yoruichi", "Aizen", "HollowIchigo", "Mugetsu" },
	},
	Bizarre = {
		title = "Bizarre Stand Week",
		desc = "Bizarre Stands fighters appear at the hub altars. Limited time!",
		color = rgb(230, 90, 200),
		effects = { mutationLuck = 1.5 },
		fighters = { "Jonathan", "YoungJoseph", "Josuke", "Jotaro", "Giorno", "KillerQueen", "Dio", "DioAwakened" },
	},
}
LiveOps.Order = { "DoubleDrops", "SoulSociety", "MutationWeek", "GoldenRush", "Bizarre", "TrainingFrenzy" }

-- Chance an altar drop becomes a limited event fighter of the rolled rarity (when the event has one).
LiveOps.EventFighterChance = 0.2

local WEEK = 7 * 86400
-- Weeks start Monday 00:00 UTC (the Unix epoch was a Thursday, so shift by 3 days).
local MONDAY = 3 * 86400

function LiveOps.week(now)
	return math.floor((now + MONDAY) / WEEK)
end

function LiveOps.weekStart(week)
	return week * WEEK - MONDAY
end

-- The default calendar: one event a week, rotating through LiveOps.Order, Friday 18:00 to Monday 00:00 UTC
-- (the weekend) for the plain boosts, the whole week for the limited-fighter events.
function LiveOps.defaultEvent(now)
	local week = LiveOps.week(now)
	local key = LiveOps.Order[week % #LiveOps.Order + 1]
	local start, finish = LiveOps.weekStart(week), LiveOps.weekStart(week + 1)
	if not LiveOps.Events[key].fighters then
		start += 4 * 86400 + 18 * 3600 -- Friday 18:00
	end
	return key, start, finish
end

-- The running event at `now`: a remote override if one covers now, else the default calendar.
-- schedule: { { key, start, finish } } (unix seconds). Returns key, finish (or nil).
function LiveOps.current(now, schedule)
	for _, e in schedule or {} do
		if LiveOps.Events[e.key] and now >= e.start and now < e.finish then
			return e.key, e.finish
		end
	end
	local key, start, finish = LiveOps.defaultEvent(now)
	if now >= start and now < finish then
		return key, finish
	end
	return nil
end

-- The next event after `now` (for "coming up"): key and start.
function LiveOps.next(now, schedule)
	local best, at
	for _, e in schedule or {} do
		if LiveOps.Events[e.key] and e.start > now and (not at or e.start < at) then
			best, at = e.key, e.start
		end
	end
	for w = 0, 2 do
		local key, start = LiveOps.defaultEvent(LiveOps.weekStart(LiveOps.week(now) + w) + 1)
		if start > now and (not at or start < at) then
			best, at = key, start
		end
	end
	return best, at
end

-- Weekly quests: 5 a week from the pool, the same for everyone that week. `metric` is a Goals.metric name;
-- progress counts from the week's start. Finishing all 5 opens the weekly chest.
LiveOps.QuestPool = {
	{
		id = "wins10",
		text = "Win 10 clashes",
		metric = "wins",
		need = 10,
		reward = { kind = "power", reps = 400, floor = 5000 },
	},
	{
		id = "wins25",
		text = "Win 25 clashes",
		metric = "wins",
		need = 25,
		reward = { kind = "cash", seconds = 900, floor = 200000 },
	},
	{
		id = "steal3",
		text = "Steal 3 fighters",
		metric = "steals",
		need = 3,
		reward = { kind = "cash", seconds = 600, floor = 100000 },
	},
	{
		id = "steal8",
		text = "Steal 8 fighters",
		metric = "steals",
		need = 8,
		reward = { kind = "boost", minutes = 20 },
	},
	{
		id = "cash50k",
		text = "Collect $500K at your base",
		metric = "collected",
		need = 5e5,
		reward = { kind = "power", reps = 300, floor = 4000 },
	},
	{
		id = "cash1m",
		text = "Collect $10M at your base",
		metric = "collected",
		need = 1e7,
		reward = { kind = "power", reps = 800, floor = 20000 },
	},
	{
		id = "power100k",
		text = "Train 100K Power",
		metric = "power",
		need = 1e5,
		reward = { kind = "cash", seconds = 600, floor = 150000 },
	},
	{
		id = "power10m",
		text = "Train 10M Power",
		metric = "power",
		need = 1e7,
		reward = { kind = "boost", minutes = 30 },
	},
}
LiveOps.QuestsPerWeek = 5
LiveOps.WeeklyChest = { kind = "fighter", rarity = "Legendary" }

-- A small seeded generator, so a week's quests are the same on client, server and in tests.
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

function LiveOps.quests(week)
	local nextRandom = generator(week * 7919 + 17)
	for _ = 1, 3 do
		nextRandom()
	end
	local pool = table.clone(LiveOps.QuestPool)
	local out = {}
	while #out < LiveOps.QuestsPerWeek and #pool > 0 do
		local i = math.floor(nextRandom() * #pool) + 1
		table.insert(out, table.remove(pool, i))
	end
	return out
end

-- Live multipliers: LiveOpsService writes the running event's effects to ReplicatedStorage attributes
-- "Live_<effect>"; everything that boosts reads them through here (1 when nothing runs).
-- Updates ship every Saturday at 17:00 UTC (docs/CONTENT_CALENDAR.md). The next one after `now`, unless the
-- remote config names it (`update` = { at, title, teaser }, while `at` is still ahead).
-- The weekly Saturday countdown is only a promise if updates really ship that often, so it is OFF: the update board
-- shows (and counts down) only while the remote config names an update (tools/liveops/push.py update ...).
LiveOps.WeeklyUpdates = false
LiveOps.UpdateDay = 5 -- days after Monday 00:00 UTC (Saturday)
LiveOps.UpdateHour = 17
function LiveOps.nextUpdate(now, override)
	if type(override) == "table" and tonumber(override.at) and tonumber(override.at) > now then
		return tonumber(override.at), override.title, override.teaser
	end
	local week = LiveOps.week(now)
	local at = LiveOps.weekStart(week) + LiveOps.UpdateDay * 86400 + LiveOps.UpdateHour * 3600
	if at <= now then
		at += 7 * 86400
	end
	return at, nil, nil
end

function LiveOps.mult(name)
	local rs = game and game:GetService("ReplicatedStorage")
	return rs and rs:GetAttribute("Live_" .. name) or 1
end

return LiveOps
