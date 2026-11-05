-- Beam clash rules as pure functions, so they behave the same everywhere and can be tested alone.
local Config = require(script.Parent.Config)

local ClashRules = {}
local B = Config.Battle

-- Side 1's share of the push, 0..1 (0.5 = dead even).
function ClashRules.share(score1, score2)
	local total = score1 + score2
	return total > 0 and score1 / total or 0.5
end

-- Where the collision ball sits between the two players, 0 (at side 1) .. 1 (at side 2).
-- Side 1 winning pushes the ball toward side 2.
function ClashRules.ballPosition(share1)
	return 0.5 + (share1 - 0.5) * 0.9
end

-- Value of one click: doubled while surging; the side behind gets a capped boost (rubber band).
function ClashRules.clickValue(surging, ownShare, overdrive)
	local behind = math.max(0, 0.5 - ownShare) * 2 -- 0 when even, 1 when fully dominated
	return (surging and B.surgeMult or 1) * (1 + B.rubberBand * behind) * (overdrive and B.overdriveMult or 1)
end

-- True in the final seconds of a battle that ends at `endAt`.
function ClashRules.inOverdrive(t, endAt)
	return endAt ~= nil and t >= endAt - B.overdrive
end

-- Token bucket that caps clicks at maxCps. Returns how many of `count` clicks are accepted.
function ClashRules.accept(bucket, now, count)
	local rate = B.maxCps
	local cap = rate * 0.6
	bucket.tokens = math.min(cap, (bucket.tokens or cap) + (now - (bucket.at or now)) * rate)
	bucket.at = now
	local accepted = math.clamp(math.floor(count), 0, math.floor(bucket.tokens))
	bucket.tokens -= accepted
	return accepted
end

-- 1 or 2, or nil for a tie (under one click apart).
function ClashRules.winner(score1, score2)
	if math.abs(score1 - score2) < 1 then
		return nil
	end
	return score1 > score2 and 1 or 2
end

function ClashRules.close(score1, score2)
	local total = score1 + score2
	return total > 0 and math.abs(score1 - score2) / total < 0.1
end

-- "Perfect" | "Good" | nil (too slow) for a reaction time in seconds.
function ClashRules.judge(reaction)
	if reaction < 0 or reaction > B.pulseWindow then
		return nil
	end
	if reaction <= B.perfect then
		return "Perfect"
	end
	return reaction <= B.good and "Good" or nil
end

function ClashRules.burst(judgment, first)
	local base = judgment == "Perfect" and B.perfectBurst or judgment == "Good" and B.goodBurst or 0
	return base * (first and 1 + B.firstStrike or 1)
end

-- Pulse times for a battle, in seconds after it starts.
function ClashRules.pulseTimes(duration)
	local list = {}
	local t = B.pulseFirst
	while t <= duration - B.pulseWindow do
		table.insert(list, t)
		t += B.pulseEvery
	end
	return list
end

-- S / A / B from a side's stats: { perfect, good, first, counter, miss, pulses }.
function ClashRules.grade(stats)
	local most = math.max(1, (stats.pulses or 0) * 4)
	local points = (stats.perfect or 0) * 3
		+ (stats.good or 0) * 2
		+ (stats.first or 0)
		+ (stats.counter or 0) * 2
		- (stats.miss or 0) * 2
	local score = points / most
	return score >= B.gradeS and "S" or score >= B.gradeA and "A" or "B", score
end

-- Click multiplier from upgrade power: full against the game, none against another player.
function ClashRules.powerMult(power, rivalIsHuman)
	if rivalIsHuman and not Config.PowerAgainstPlayers then
		return 1
	end
	return math.max(1, power or 1)
end

-- ---------------------------------------------------------------- Beam Rally
local R = Config.Rally

-- Deflect window (seconds before arrival) for an orb crossing in `travel` seconds.
function ClashRules.rallyWindow(travel)
	return math.clamp(travel * R.windowFrac, R.windowMin, R.windowMax)
end

-- `remaining`: seconds until the orb arrives when DEFLECT was pressed (negative = after arrival).
-- "Perfect" | "Good" | "Early" (whiff) | nil (too late: the orb already hit).
function ClashRules.judgeDeflect(remaining, window)
	if remaining > window then
		return "Early"
	elseif remaining < -R.grace then
		return nil
	end
	return (remaining <= R.perfectEarly and remaining >= -R.perfectLate) and "Perfect" or "Good"
end

-- Travel time of the return.
function ClashRules.nextTravel(travel, judgment, smash)
	local t = travel * (judgment == "Perfect" and R.perfectSpeedUp or R.speedUp)
	if smash then
		t *= R.smashSpeed
	end
	return math.max(R.minTravel * (smash and 0.8 or 1), t)
end

-- Orb progress per second toward the receiver: the receiver's mashing slows it, the sender's speeds it.
function ClashRules.rallyRate(travel, receiverCps, senderCps)
	local sway = math.clamp((senderCps - receiverCps) / R.mashNorm, -1, 1) * R.mashSway
	return (1 + sway) / travel
end

-- Rally hits -> overdrive strength 0..1 (ramps in over the two hits before overdriveHits).
function ClashRules.rallyHeat(hits)
	return math.clamp((hits - R.overdriveHits + 2) / 3, 0, 1)
end

-- A bot's skill against a player with `power`: up to twice the fade (cracks sooner in fast rallies) at
-- 1M+ Power; its base (how it handles slow orbs) is untouched.
function ClashRules.powerSkill(skill, power)
	local out = table.clone(skill)
	out.fade = skill.fade * (1 + math.clamp(math.log10(math.max(1, power or 1)) / 6, 0, 1))
	return out
end

-- Bot deflect plan: returns the judgment it will produce ("Perfect"/"Good"/"Early"/nil for a miss).
-- `travel` is the orb's real crossing time (mashing included), so pushing hard makes bots crack.
function ClashRules.botDeflect(skill, travel, rng)
	local spedUp = R.startTravel - travel
	-- Fatigue grows with the square of the speed-up: solid on slow orbs, cracking as the rally gets frantic.
	-- An orb no faster than the opening pace is always returned: a bot never gifts a point.
	if spedUp <= 0.05 then
		return rng:NextNumber() < skill.perfect and "Perfect" or "Good"
	end
	local chance = math.clamp(skill.base - spedUp ^ 2 * skill.fade, 0.12, 0.99)
	if rng:NextNumber() < chance then
		return rng:NextNumber() < skill.perfect and "Perfect" or "Good"
	end
	return rng:NextNumber() < 0.3 and "Early" or nil
end

-- Grade for a rally player: stats = { perfect, good, reversal, miss, deflects }.
function ClashRules.rallyGrade(stats)
	local attempts = math.max(1, (stats.deflects or 0) + (stats.miss or 0))
	local points = (stats.perfect or 0) * 3 + (stats.good or 0) * 2 + (stats.reversal or 0) * 2 - (stats.miss or 0) * 2
	local score = points / (attempts * 3)
	return score >= B.gradeS and "S" or score >= B.gradeA and "A" or "B", score
end

function ClashRules.botCps(tier, easy, rng)
	local band = easy and Config.Bots.Easy or Config.Bots[tier] or Config.Bots.Bronze
	return rng:NextNumber(band[1], band[2])
end

-- ---------------------------------------------------------------- Beam Push
local P = Config.Push

-- Push multiplier for a side with `mine` Power against `theirs` (rivalIsBot: the steep curve).
function ClashRules.pushMult(mine, theirs, rivalIsBot)
	local ratio = math.max(1, mine or 1) / math.max(1, theirs or 1)
	if rivalIsBot then
		return math.clamp(ratio ^ P.botCurve, 0.35, P.botMax)
	end
	return math.max(0.4, 1 + P.pvpStep * math.log(ratio, 2))
end

-- One word for the matchup, from your multiplier against theirs.
function ClashRules.matchup(myMult, theirMult)
	local edge = myMult / math.max(0.01, theirMult)
	if edge >= 1.4 then
		return "EASY"
	elseif edge >= 0.85 then
		return "EVEN"
	elseif edge >= 0.55 then
		return "HARD"
	end
	return "TOO STRONG"
end

-- A side's push per second: tapping `cps` with combo `combo`, times its Power multiplier.
function ClashRules.pushForce(cps, combo, mult)
	return (P.basePush + cps * P.clickPush * (combo or 1)) * (mult or 1)
end

-- An ultimate's push for `side` at `pos` (doubled in LAST STAND), and whether it was a last stand.
function ClashRules.ultPush(side, pos, mult)
	local mine = side == 1 and pos or 1 - pos -- 0 = pushed right into your own end
	local stand = mine <= P.lastStand
	return P.ultPush * (mult or 1) * (stand and 2 or 1), stand
end

-- Ultimate charge per tap (fills in P.ultTaps taps, up to 1.5x faster with Power: 1M+).
function ClashRules.ultPerTap(power)
	return (1 + 0.5 * math.clamp(math.log10(math.max(1, power or 1)) / 6, 0, 1)) / P.ultTaps
end

-- How a drop's match runs: returns rounds to win, and the most rounds it can last (nil: no limit).
function ClashRules.matchPlan(rarity, short)
	if short or P.shortRarities[rarity] then
		return 2, 2
	end
	return P.longRoundsToWin, nil
end

-- After a round: the match's winning side, or nil if it goes on. `ground` = how far each side pushed over the
-- match; `last` = who won this round (it also takes a dead-even tiebreak). Second result: decided on ground.
function ClashRules.matchWinner(rounds, ground, last, toWin, maxRounds)
	if rounds[last] >= toWin then
		return last, false
	end
	if maxRounds and rounds[1] + rounds[2] >= maxRounds then
		if ground[1] == ground[2] then
			return last, true
		end
		return ground[1] > ground[2] and 1 or 2, true
	end
	return nil, false
end

-- Which side won the round at `pos` (nil: still going). `timeUp`: the round clock ran out.
function ClashRules.pushRoundWinner(pos, timeUp)
	if pos >= 1 then
		return 1
	elseif pos <= 0 then
		return 2
	elseif timeUp then
		return pos >= 0.5 and 1 or 2
	end
	return nil
end

-- Grade for a side: stats = { taps, seconds, ults, clashes (frenzies won), stands (last-stand ults) }.
function ClashRules.pushGrade(stats)
	local cps = (stats.taps or 0) / math.max(1, stats.seconds or 1)
	local flair = (stats.clashes or 0) * 2 + (stats.stands or 0) + (stats.ults or 0) * 0.5
	if cps >= 7 and flair >= 1.5 then
		return "S", cps
	elseif cps >= 4.5 or flair >= 2 then
		return "A", cps
	end
	return "B", cps
end

return ClashRules
