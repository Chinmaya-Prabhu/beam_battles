-- Offline checks for shared/LiveOps.lua (run with tests/run_rules.sh).
local LiveOps = LIVEOPS()
-- Week math: Monday starts.
local mon = 1792800000 -- some date
local w = LiveOps.week(mon)
assert(LiveOps.weekStart(w) <= mon and mon < LiveOps.weekStart(w + 1), "week bounds")
assert(os.date("!*t", LiveOps.weekStart(w)).wday == 2, "weeks start on Monday (UTC)")
-- Every event in the rotation exists, and the calendar always yields one per week.
for _, k in LiveOps.Order do
	assert(LiveOps.Events[k], k)
end
for i = 0, 20 do
	local key, start, finish = LiveOps.defaultEvent(LiveOps.weekStart(w + i) + 10)
	assert(LiveOps.Events[key] and finish > start, "calendar week " .. i)
	local cur = LiveOps.current(start + 60)
	assert(cur == key, "event running inside its window")
end
-- Overrides win.
local sched = { { key = "MutationWeek", start = mon - 10, finish = mon + 10 } }
assert(LiveOps.current(mon, sched) == "MutationWeek", "override")
local nk, nat = LiveOps.next(mon, {})
assert(nk and nat > mon, "next event is ahead")
-- Weekly quests: deterministic, distinct, the right count.
local a, b = LiveOps.quests(w), LiveOps.quests(w)
assert(#a == LiveOps.QuestsPerWeek, "quest count")
local seen = {}
for i, q in a do
	assert(b[i].id == q.id, "same quests on both sides")
	assert(not seen[q.id], "distinct")
	seen[q.id] = true
end
local differs = false
for i, q in LiveOps.quests(w + 1) do
	differs = differs or q.id ~= a[i].id
end
assert(differs, "quests rotate weekly")
print("LiveOps: checks passed")
