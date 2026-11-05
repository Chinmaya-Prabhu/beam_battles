-- Offline checks for shared/ClashRules.lua (run with tests/run_rules.sh).
local Config = CONFIG()
local ClashRules = RULES(Config)
local B = Config.Battle
local function eq(a, b, msg)
	assert(a == b, msg .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
eq(ClashRules.judge(0.1), "Perfect", "fast reaction")
eq(ClashRules.judge(0.5), "Good", "medium reaction")
eq(ClashRules.judge(0.85), nil, "too slow")
eq(ClashRules.judge(-0.1), nil, "before the pulse")
eq(ClashRules.burst("Perfect", true), B.perfectBurst * 1.5, "first-strike perfect")
eq(ClashRules.burst("Good", false), B.goodBurst, "good")
local times = ClashRules.pulseTimes(B.duration)
assert(#times >= 3, "at least three pulses per clash")
assert(times[#times] <= B.duration - B.pulseWindow, "last pulse resolvable before the end")
eq(ClashRules.grade({ perfect = 4, first = 4, pulses = 4 }), "S", "flawless")
eq(ClashRules.grade({ good = 4, pulses = 4 }), "A", "all good")
eq(ClashRules.grade({ miss = 3, good = 1, pulses = 4 }), "B", "mostly missed")
eq(ClashRules.powerMult(50, true), 1, "power ignored against a human")
eq(ClashRules.powerMult(50, false), 50, "power counts against a bot")
local bucket = {}
eq(ClashRules.accept(bucket, 0, 100), math.floor(B.maxCps * 0.6), "burst capped")
print("ClashRules: all checks passed")
assert(ClashRules.clickValue(false, 0.5, true) == B.overdriveMult, "overdrive multiplies clicks")
assert(ClashRules.inOverdrive(98, 100) and not ClashRules.inOverdrive(90, 100), "overdrive window")
print("Overdrive: checks passed")
local Rl = Config.Rally
local w0 = ClashRules.rallyWindow(Rl.startTravel)
assert(w0 == Rl.windowMax, "slow orb: full window")
assert(ClashRules.rallyWindow(Rl.minTravel) == Rl.windowMin, "fast orb: tight window")
eq(ClashRules.judgeDeflect(0.02, w0), "Perfect", "deflect on arrival")
eq(ClashRules.judgeDeflect(0.2, w0), "Good", "deflect a bit early")
eq(ClashRules.judgeDeflect(1.0, w0), "Early", "whiff")
eq(ClashRules.judgeDeflect(-0.2, w0), nil, "too late")
eq(ClashRules.judgeDeflect(-0.1, w0), "Perfect", "a slightly late press still counts as PERFECT (input lag)")
eq(ClashRules.judgeDeflect(-0.15, w0), "Good", "late but inside grace")
assert(ClashRules.nextTravel(1, "Perfect", false) < ClashRules.nextTravel(1, "Good", false), "perfect returns faster")
assert(ClashRules.nextTravel(1, "Good", true) < ClashRules.nextTravel(1, "Good", false), "smash returns faster")
assert(ClashRules.nextTravel(Rl.minTravel, "Perfect", false) >= Rl.minTravel, "speed capped")
assert(ClashRules.rallyRate(1, 14, 0) < 1 and ClashRules.rallyRate(1, 0, 14) > 1, "mashing sways the orb")
eq(ClashRules.rallyHeat(0), 0, "no heat at rally start")
eq(ClashRules.rallyHeat(Rl.overdriveHits + 1), 1, "full overdrive")
eq(ClashRules.rallyGrade({ perfect = 6, deflects = 6 }), "S", "flawless rally")
eq(ClashRules.rallyGrade({ good = 2, miss = 2, deflects = 2 }), "B", "shaky rally")
local rngStub = {
	NextNumber = function()
		return 0.01
	end,
}
eq(ClashRules.botDeflect(Config.BotSkill.Bronze, Rl.startTravel, rngStub), "Perfect", "bot early rally")
do
	-- Mashing your return makes it cross faster, which makes bots miss more often.
	local function rate(travel)
		local made, rng = 0, {
			NextNumber = function()
				return math.random()
			end,
		}
		for _ = 1, 4000 do
			local plan = ClashRules.botDeflect(Config.BotSkill.Bronze, travel, rng)
			if plan == "Perfect" or plan == "Good" then
				made += 1
			end
		end
		return made / 4000
	end
	local plain, pushed = 0.9, 0.9 / ClashRules.rallyRate(1, 0, 9) -- same orb, rival out-mashed by 9 cps
	assert(rate(pushed) < rate(plain) - 0.05, "pushing hard makes the bot crack")
end
do
	-- A player who never deflects never scores: slow orbs (the serve, the opening pace, a returning orb the
	-- player didn't push) are always returned, whatever the player's Power and the bot's tier.
	local rng = {
		NextNumber = function()
			return math.random()
		end,
	}
	for _, tier in { "Easy", "Bronze", "Silver", "Gold", "Diamond", "Master", "Legend" } do
		for _, power in { 1, 1e3, 1e6, 1e12 } do
			local skill = ClashRules.powerSkill(Config.BotSkill[tier], power)
			for _, travel in { Rl.startTravel * 1.8, Rl.startTravel * 1.3, Rl.startTravel } do
				for _ = 1, 300 do
					local plan = ClashRules.botDeflect(skill, travel, rng)
					assert(plan == "Perfect" or plan == "Good", "bot missed a slow orb: " .. tier .. " " .. power)
				end
			end
		end
	end
	-- Power still helps once you rally: at a fast pace a 1M-Power player cracks the bot more often.
	local function made(skill)
		local n = 0
		for _ = 1, 4000 do
			local plan = ClashRules.botDeflect(skill, 0.8, rng)
			n += (plan == "Perfect" or plan == "Good") and 1 or 0
		end
		return n / 4000
	end
	assert(
		made(ClashRules.powerSkill(Config.BotSkill.Silver, 1e6)) < made(Config.BotSkill.Silver) - 0.05,
		"power cracks bots"
	)
end
print("Rally: checks passed")
do
	-- Beam Push.
	local P = Config.Push
	-- Power against bots: steep, both ways, capped at 0.35x..2.5x.
	assert(ClashRules.pushMult(1000, 1000, true) == 1, "even")
	assert(ClashRules.pushMult(2000, 1000, true) > 1.4, "2x stronger feels it against bots")
	assert(ClashRules.pushMult(1e9, 1, true) == 2.5 and ClashRules.pushMult(1, 1e9, true) == 0.35, "bot caps")
	-- Between players: +25% per doubling, no ceiling, floor 0.4.
	assert(math.abs(ClashRules.pushMult(2000, 1000, false) - 1.25) < 1e-6, "pvp doubling")
	assert(ClashRules.pushMult(100e3, 1000, false) > 2.5, "pvp keeps growing")
	assert(ClashRules.pushMult(1, 1e9, false) == 0.4, "pvp floor")
	-- Tapping decides: no taps, no ground gained against a tapper; Power only multiplies effort.
	assert(ClashRules.pushForce(0, 1, 2.5) < ClashRules.pushForce(5, 1, 1), "idle with 2.5x power loses to a tapper")
	assert(ClashRules.pushForce(7, 1.6, 1) > ClashRules.pushForce(7, 1, 1), "combo helps")
	-- An even fight (equal Power, 7 taps vs a 4.5-cps bot, steady combos) takes about 8-15 s to push through;
	-- a 1.4x Power edge makes it about twice as quick.
	local drift = ClashRules.pushForce(7, 1.3, 1) - ClashRules.pushForce(4.5, 1.3, 1)
	local seconds = 0.5 / drift
	assert(seconds > 8 and seconds < 15, "round length " .. seconds)
	local edged = 0.5 / (ClashRules.pushForce(7, 1.3, 1.4) - ClashRules.pushForce(4.5, 1.3, 1))
	assert(edged < seconds * 0.6, "power edge shortens the fight " .. edged)
	-- Ultimate: doubled in last stand.
	local normal = ClashRules.ultPush(1, 0.5, 1)
	local stand, isStand = ClashRules.ultPush(1, 0.1, 1)
	assert(isStand and math.abs(stand - normal * 2) < 1e-9, "last stand x2")
	assert(ClashRules.ultPerTap(1e6) > ClashRules.ultPerTap(1), "power fills ultimate faster")
	-- Rounds.
	assert(ClashRules.pushRoundWinner(1) == 1 and ClashRules.pushRoundWinner(0) == 2, "pushed through")
	assert(ClashRules.pushRoundWinner(0.6) == nil and ClashRules.pushRoundWinner(0.6, true) == 1, "time up")
	-- Matchup words.
	assert(ClashRules.matchup(2, 1) == "EASY" and ClashRules.matchup(1, 1) == "EVEN", "matchup")
	assert(ClashRules.matchup(0.7, 1) == "HARD" and ClashRules.matchup(0.4, 1) == "TOO STRONG", "matchup 2")
	-- Grades.
	assert(ClashRules.pushGrade({ taps = 160, seconds = 20, ults = 2, clashes = 1 }) == "S", "S grade")
	assert(ClashRules.pushGrade({ taps = 40, seconds = 20 }) == "B", "B grade")
	assert(P.rookieMax > 0, "rookie altars")
end
print("Push: checks passed")

-- Match plans: best of 2 for Common to Rare (ground decides 1-1), best of 5 above.
do
	local w, m = ClashRules.matchPlan("Rare", false)
	assert(w == 2 and m == 2, "rare is a best of 2")
	w, m = ClashRules.matchPlan("Epic", false)
	assert(w == 3 and m == nil, "epic is a best of 5")
	w, m = ClashRules.matchPlan("Epic", true)
	assert(w == 2 and m == 2, "the tutorial is always short")
	assert(ClashRules.matchWinner({ 2, 0 }, { 0.9, 0 }, 1, 2, 2) == 1, "2-0 ends it")
	assert(ClashRules.matchWinner({ 1, 0 }, { 0.5, 0 }, 1, 2, 2) == nil, "1-0 goes on")
	local side, tie = ClashRules.matchWinner({ 1, 1 }, { 0.5, 0.2 }, 2, 2, 2)
	assert(side == 1 and tie, "1-1 goes to whoever pushed further")
	assert(ClashRules.matchWinner({ 1, 1 }, { 0.5, 0.5 }, 2, 2, 2) == 2, "dead even: the last round's winner")
	assert(ClashRules.matchWinner({ 2, 2 }, { 1, 1 }, 2, 3, nil) == nil, "a best of 5 has no limit")
	print("Match plans: checks passed")
end
