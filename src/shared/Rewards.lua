-- Free rewards that keep players around (docs/RETENTION_PLAN.md):
--   * playtime gifts: unlock at Rewards.Gifts[i].min minutes into THIS session (timers restart on rejoin);
--     fighters at 15 (Rare), 35 (Epic) and 55 minutes (Legendary), so every session has its big moments
--     (tools/sim/moments.py placed them in the quiet stretches), and the HUD keeps telling players so,
--   * the daily streak: one claim per UTC day; claiming on consecutive days climbs to day 7 (a Mythic
--     fighter), a missed day starts again at day 1, after day 7 it repeats day 7.
-- Amounts scale with the player: `reps` is that many reps at their current rate (Ki), `seconds` that much of
-- their stands' income (Cash); `floor` is the least it pays. Pure data and maths for tests.
local Rewards = {}

Rewards.Gifts = {
	{ min = 3, kind = "ki", reps = 150, floor = 500 },
	{ min = 8, kind = "cash", seconds = 180, floor = 20000 },
	{ min = 15, kind = "fighter", rarity = "Rare" },
	{ min = 25, kind = "boost", minutes = 10 },
	{ min = 35, kind = "fighter", rarity = "Epic" },
	{ min = 45, kind = "cash", seconds = 600, floor = 100000 },
	{ min = 55, kind = "fighter", rarity = "Legendary" },
}

-- Days 3, 5 and 7 are named fighters (`key`), shown in the card as the real model so players come back
-- for them: Epic, then Legendary, then Mythic.
Rewards.Daily = {
	{ kind = "cash", seconds = 300, floor = 50000 },
	{ kind = "ki", reps = 300, floor = 2000 },
	{ kind = "fighter", rarity = "Epic", key = "Cell" },
	{ kind = "cash", seconds = 900, floor = 200000 },
	{ kind = "fighter", rarity = "Legendary", key = "Mahoraga" },
	{ kind = "ki", reps = 1000, floor = 20000 },
	{ kind = "fighter", rarity = "Mythic", key = "GoldenFrieza" },
}

-- Whether gift `i` can be claimed `elapsed` seconds into the session, given the claimed set.
function Rewards.giftReady(i, elapsed, claimed)
	local g = Rewards.Gifts[i]
	return g ~= nil and not claimed[i] and elapsed >= g.min * 60
end

-- The next unclaimed gift (index) and the seconds until it unlocks (0 = ready); nil when all are claimed.
function Rewards.nextGift(elapsed, claimed)
	for i, g in Rewards.Gifts do
		if not claimed[i] then
			return i, math.max(0, g.min * 60 - elapsed)
		end
	end
	return nil
end

function Rewards.day(unixTime)
	return math.floor(unixTime / 86400)
end

-- The daily streak on `today` given the last claimed day and streak: whether a claim is open and which
-- streak day (1..7) it pays.
function Rewards.daily(lastDay, streak, today)
	if lastDay == today then
		return false, streak
	end
	local nextStreak = (lastDay == today - 1) and (streak or 0) + 1 or 1
	return true, math.min(nextStreak, #Rewards.Daily)
end

-- What a reward pays, for players earning `perRep` per rep and `income` cash per second.
function Rewards.amount(reward, perRep, income)
	if reward.kind == "ki" then
		return math.max(reward.floor, math.floor(reward.reps * perRep))
	elseif reward.kind == "cash" then
		return math.max(reward.floor, math.floor(reward.seconds * income))
	end
	return 0
end

return Rewards
