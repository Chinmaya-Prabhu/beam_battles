-- Beam Push clashes at the altars, guardians and bosses (Config.Push). Server-authoritative:
--   * standing on a clash pad next to an altar with a fighter on it claims that side; a bot fills an
--     empty side after the tier's delay (8 s when another free player is nearby, for player vs player),
--   * the beams meet at a clash point; taps (capped by ClashRules.accept) push it toward the rival, with a
--     combo for steady tapping; pushing it through wins the round; best of three wins the fighter,
--   * the ULTIMATE fills from taps: a big push, x2 in LAST STAND; two ultimates close together are an
--     ULTIMATE CLASH (tap frenzy); bosses RAGE once a round,
--   * Power multiplies each side's push against the rival's Power (ClashRules.pushMult),
--   * hub altars are ROOKIE altars (Config.Push.rookieMax).
-- Everyone gets the events so spectators see the beams; only the two players get the UI.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local ClashRules = require(Shared.ClashRules)
local Odds = require(Shared.Odds)
local Net = require(Shared.Net)
local Social = require(script.Parent.SocialService)
local Format = require(Shared.Format)

local ClashService = {}
local B = Config.Battle
local remote = Net.get("Clash")
local rng = Random.new()

local Drops -- DropService, passed to start()
local spots = {} -- [altar] = { [side] = { pad, cframe } }
local clashes = {} -- [altar] = clash
local busy = {} -- [player] = { altar, side }
local cooldown = {} -- [player] = os.clock() when they may sit again
local wins = {} -- [player] = { {key, mutation}, ... } until plots exist
local challenges = {} -- [index] = guardian/boss venue (ClashService.addChallenge); indices above the altars'
local nagged = {} -- [player] = os.clock() of the last "locked" message

local DANCES = require(Shared.Dances).List

-- An altar (DropService) or a challenge venue: both expose tier, model (what the clash is over), locked,
-- model_parent and light; challenges add rival, rounds, title, canSeat and onResult.
local function venueOf(index)
	return challenges[index] or Drops.Altars[index]
end

local function now()
	return workspace:GetServerTimeNow()
end

local function root(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Plays one of the shared clips (client/FighterAnimator.lua) on a player's character or a bot.
local function play(model, clip)
	if not model or not model.Parent then
		return
	end
	CollectionService:AddTag(model, "Fighter")
	model:SetAttribute("Clip", clip)
	model:SetAttribute("ClipStart", now())
end

local function stopPlaying(model)
	if model and model.Parent and Players:GetPlayerFromCharacter(model) then
		CollectionService:RemoveTag(model, "Fighter")
		model:SetAttribute("Clip", nil)
		model:SetAttribute("ClipStart", nil)
	end
end

local P = Config.Push

local function newStats()
	return { taps = 0, seconds = 0, ults = 0, clashes = 0, stands = 0 }
end

local function sideInfo(side)
	return {
		name = side.name,
		userId = side.player and side.player.UserId or 0,
		bot = side.player == nil,
		model = side.model,
	}
end

local function snapshot(index, clash)
	local altar = venueOf(index)
	return {
		altar = index,
		tier = altar.tier,
		sides = { sideInfo(clash.sides[1]), sideInfo(clash.sides[2]) },
		startAt = clash.startAt,
		-- A guardian's prize is the fighter hovering over it (DropService guardian spawns), if any.
		-- (A first win's prize is the guardian itself: its fighting copy stands in for the portrait and the comet.)
		prize = clash.firstKey and {
			key = clash.firstKey,
			mutation = "Normal",
			model = clash.sides[2] and clash.sides[2].model,
		}
			or altar.rival and { key = altar.prizeKey, mutation = altar.prizeMutation, model = altar.prizeModel }
			or { key = altar.key, mutation = altar.mutation, model = altar.model },
		rounds = clash.roundsToWin,
		title = altar.title,
		challenge = altar.rival ~= nil,
		pads = { spots[index][1].cframe, spots[index][2].cframe },
		power = { clash.sides[1].power or 0, clash.sides[2].power or 0 },
		mult = { clash.sides[1].mult or 1, clash.sides[2].mult or 1 },
	}
end

local function release(index)
	local clash = clashes[index]
	if not clash then
		return
	end
	clashes[index] = nil
	for side = 1, 2 do
		local s = clash.sides[side]
		if s then
			if s.player then
				busy[s.player] = nil
				s.player:SetAttribute("InClash", nil)
				cooldown[s.player] = os.clock() + B.seatCooldown
				stopPlaying(s.model)
				local r = root(s.player)
				if r then
					r.Anchored = false
					-- Step off the pad so the next drop doesn't seat them by accident.
					local pad = spots[index][side].cframe
					r.CFrame = pad * CFrame.new(0, 0, 7)
				end
			elseif s.model then
				s.model:Destroy()
			end
		end
	end
	local altar = venueOf(index)
	altar.locked = false
	local home = altar.prizeHome
	altar.prizeHome = nil
	if home and home.model.Parent and home.model == altar.prizeModel then
		home.model:ScaleTo(home.scale)
		home.model:PivotTo(home.pivot)
	end
	if altar.parked then
		if altar.model and altar.model.Parent then
			altar.model:PivotTo(altar.parked)
		end
		altar.parked = nil
	end
end

local function finish(index, winnerSide, tiebreak)
	local clash = clashes[index]
	clash.phase = "result"
	local altar = venueOf(index)
	-- (A first win over a guardian: the guardian itself, not the drop hovering over it.)
	local first = clash.firstKey and winnerSide == 1 and clash.firstKey or nil
	local prizeKey = first or (altar.rival and altar.prizeKey or altar.key)
	local prize = {
		key = prizeKey,
		mutation = first and "Normal" or (altar.rival and altar.prizeMutation or altar.mutation) or "Normal",
		rarity = prizeKey and Fighters.ByKey[prizeKey].rarity,
	}
	local s1, s2 = clash.rounds[1], clash.rounds[2]
	local grades, stats = {}, {}
	for side, s in clash.sides do
		stats[side] = s.stats or newStats()
		grades[side] = ClashRules.pushGrade(stats[side])
	end
	-- An S-rank win rolls the prize's mutation twice and keeps the better one.
	if grades[winnerSide] == "S" and prize.key then
		local again = Odds.rollMutation(rng, 1, altar.zone)
		if Config.Mutations[again].mult > Config.Mutations[prize.mutation or "Normal"].mult then
			prize.mutation = again
			prize.upgraded = true
		end
	end
	-- For the prize card: the fighter's own odds, and what it earns.
	if prize.key then
		prize.odds = Odds.label(Odds.base(prize.key, prize.mutation))
		prize.income = Odds.income(prize.key, prize.mutation)
	end
	local losing = clash.sides[3 - winnerSide]
	local consolation = losing.player and ClashService.onLoss and ClashService.onLoss(losing.player)
	-- A won fighter also pays Power by its rarity (TrainingService), shown on the win card.
	local winning = clash.sides[winnerSide]
	local winPower = winning.player and prize.key and ClashService.onWin and ClashService.onWin(winning.player, prize.key)
	remote:FireAllClients("End", {
		consolation = consolation,
		winPower = winPower,
		tiebreak = tiebreak,
		grades = grades,
		stats = stats,
		altar = index,
		winner = winnerSide,
		scores = { s1, s2 },
		close = math.abs(s1 - s2) <= 1,
		prize = prize,
	})
	local winner, loser = clash.sides[winnerSide], clash.sides[3 - winnerSide]
	local winnerKey = winner.model and winner.model:GetAttribute("FighterKey")
	play(winner.model, winnerKey and Fighters.signature(winnerKey) or "Victory")
	play(loser.model, "KO")
	if ClashService.onResult then
		task.spawn(ClashService.onResult, winner.player, loser.player, altar)
	end
	if winner.player then
		Social.award(winner.player, "FirstWin")
	end
	if winner.player and prize.key then
		wins[winner.player] = wins[winner.player] or {}
		table.insert(wins[winner.player], { key = prize.key, mutation = prize.mutation })
		winner.player:SetAttribute("FightersWon", #wins[winner.player])
		if ClashService.onPrize then
			task.spawn(ClashService.onPrize, winner.player, prize.key, prize.mutation)
		end
	end
	for _, s in clash.sides do
		if s.player then
			s.player:SetAttribute("Clashes", (s.player:GetAttribute("Clashes") or 0) + 1)
		end
	end
	if altar.rival then
		-- A guardian or boss fight: the zone records the result (ladder progress). A fighter hovering over
		-- the guardian goes to the winner (granted above) and leaves; a loss leaves it there for the next try.
		task.spawn(altar.onResult, winner.player, loser.player)
		if winner.player and prize.key and not first and Drops.clearGuardian then
			task.delay(0.6, Drops.clearGuardian, index)
		end
	else
		-- The prize leaves the altar as the clients fly it to the winner; the altar refills next drop.
		task.delay(0.6, function()
			Drops.clear(index)
		end)
	end
	task.delay(1.6, function()
		if clashes[index] == clash then
			play(winner.model, DANCES[rng:NextInteger(1, #DANCES)])
		end
	end)
	task.delay(B.result + 2.2, function()
		if clashes[index] == clash then
			release(index)
		end
	end)
end

local function begin(index)
	local clash = clashes[index]
	clash.phase = "faceoff"
	clash.startAt = now() + B.faceOff
	clash.rounds = { 0, 0 }
	clash.round = 1
	local altar = venueOf(index)
	altar.locked = true
	clash.ground = { 0, 0 }
	if altar.rounds then
		clash.roundsToWin = altar.rounds
	else
		-- (The tutorial's prize is an Epic, but a first fight is always the short one.)
		local key = altar.key and Fighters.ByKey[altar.key]
		clash.roundsToWin, clash.maxRounds = ClashRules.matchPlan(key and key.rarity, clash.tutorial)
	end
	-- A guardian beaten for the first time gives itself (ZoneService firstPrize): the hovering drop stays for
	-- everyone else.
	local challenger = clash.sides[1] and clash.sides[1].player
	clash.firstKey = altar.firstPrize and challenger and altar.firstPrize(challenger) or nil
	-- The prize (an altar's drop, or a guardian spawn) shrinks and rises to hover above the clash, out of the
	-- beams' path.
	local prize = if altar.rival then (not clash.firstKey and altar.prizeModel) else altar.model
	if prize and prize.Parent then
		if altar.rival then
			altar.prizeHome = { model = prize, pivot = prize:GetPivot(), scale = prize:GetScale() } -- back after a loss
		end
		local feet = prize:GetPivot().Position
		prize:ScaleTo(prize:GetScale() * 0.55)
		prize:PivotTo(prize:GetPivot() + (feet - prize:GetPivot().Position) + Vector3.new(0, 8, 0))
	end
	-- A guardian steps off its pad while its fighting copy (the clash bot) stands there.
	if altar.rival and altar.model and altar.model.Parent and not altar.parked then
		altar.parked = altar.model:GetPivot()
		altar.model:PivotTo(altar.parked + Vector3.new(0, -400, 0))
	end
	if altar.light then
		altar.light.Brightness = 0.4
	end
	for _, s in clash.sides do
		s.cps, s.tapped, s.bucket, s.ult, s.combo = 0, 0, {}, 0, 1
		s.stats = newStats()
		if s.player then
			s.power = s.player:GetAttribute("Power") or 0
		end
		s.ultRate = ClashRules.ultPerTap(s.power)
		play(s.model, "Fire")
	end
	-- Power: each side's push is multiplied by how its Power compares with the rival's (ClashRules.pushMult:
	-- steep against bots, gentler between players). Bots push at 1x; the player's multiplier carries it.
	for side, s in clash.sides do
		local rival = clash.sides[3 - side]
		if s.player then
			s.mult = ClashRules.pushMult(s.power, rival.power, not rival.player)
			-- Far stronger than a drop's bot: one round, one blast.
			if not rival.player and not altar.rival and not clash.tutorial and s.power >= rival.power * P.blastRatio then
				s.mult *= P.blastMult
				clash.blast, clash.roundsToWin, clash.maxRounds = true, 1, 1
				rival.noUlt = true -- (it never gets to answer)
			end
		else
			s.mult = 1
		end
	end
	remote:FireAllClients("Start", snapshot(index, clash))
end

-- A drop altar's rival: the zone's entry Power (its first guardian's) or the hub tier's, times the rarity step for
-- each rarity the prize is above the altar's most common one (Config.Push.botPower).
local function dropBotPower(altar)
	local zone = altar.zone and Config.Zones[altar.zone]
	local base = zone and zone.ladderPower and zone.ladderPower[1] or P.botPower[altar.tier] or P.botPower.Bronze
	local weights = Config.Tiers[altar.tier] and Config.Tiers[altar.tier].weights or {}
	local lowest
	for i, rarity in Config.RarityOrder do
		if weights[rarity] then
			lowest = i
			break
		end
	end
	local prize = altar.key and Fighters.ByKey[altar.key]
	local rank = prize and table.find(Config.RarityOrder, prize.rarity)
	local steps = (rank and lowest) and math.max(rank - lowest, 0) or 0
	local step = zone and zone.botRarityStep or not zone and P.hubRarityStep[altar.tier] or P.botRarityStep
	return math.floor(base * step ^ steps)
end

local function addBot(index, side)
	local clash = clashes[index]
	local altar = venueOf(index)
	local other = clash.sides[3 - side]
	-- A random fighter from the tier's pool stands in as the rival.
	local pool = {}
	for rarity in Config.Tiers[altar.tier].weights do
		for _, f in Fighters.ByRarity[rarity] or {} do
			table.insert(pool, f)
		end
	end
	local pick = pool[rng:NextInteger(1, #pool)]
	if altar.rival then
		pick = Fighters.ByKey[altar.rival.key] or pick
	end
	local pad = spots[index][side].cframe
	local model = FighterModels.spawn(
		pick.key,
		pad.Position,
		pad.LookVector,
		{ parent = altar.model_parent, scale = altar.rival and altar.rival.scale, aura = true }
	)
	if not model then
		return false
	end
	model.Name = "ClashBot"
	model:SetAttribute("Bot", true)
	-- The tutorial's first clash (TutorialService steps 4-5): a slow bot that never fires an ultimate, so a new
	-- player can't lose it. (Step 4 counts too: the tutorial moves to 5 on its own tick, which can come after
	-- the bot is made.)
	local ftue = other.player and other.player:GetAttribute("Ftue")
	local tutorial = ftue and ftue >= 4 and ftue <= 5 and not altar.rival
	if tutorial then
		clash.tutorial = true
	end
	clash.sides[side] = {
		name = altar.rival and altar.rival.name or pick.display,
		model = model,
		botCps = tutorial and 0.3 or altar.rival and altar.rival.cps or ClashRules.botCps(altar.tier, false, rng),
		power = tutorial and P.botPower.Tutorial or altar.rival and altar.rival.power or dropBotPower(altar),
		-- How often it answers your ultimate with its own (an ULTIMATE CLASH): stronger bots more.
		answer = tutorial and 0
			or 0.25
				+ ((altar.rival and altar.rival.skill or Config.BotSkill[altar.tier] or {}).perfect or 0.2) * 0.6,
		noUlt = tutorial,
		boss = altar.rival and altar.rival.boss,
	}
	return true
end

local function seat(player, index, side)
	local altar = venueOf(index)
	local clash = clashes[index]
	if not clash then
		clash = { phase = "waiting", sides = {}, created = os.clock() }
		clashes[index] = clash
		altar.locked = true
	end
	local r = root(player)
	r.Anchored = true
	r.CFrame = spots[index][side].cframe + Vector3.new(0, r.Size.Y / 2 + 2.1, 0)
	clash.sides[side] = { player = player, name = player.DisplayName, model = player.Character }
	busy[player] = { altar = index, side = side }
	if ClashService.onSeat then
		task.spawn(ClashService.onSeat, player, altar)
	end
	player:SetAttribute("InClash", true)
	play(player.Character, "Idle")
	if clash.sides[3 - side] then
		begin(index)
	else
		-- Free altars always wait for a second player (player vs player) before a bot steps in.
		-- The tutorial's first fight starts at once (no one to wait for yet); guardians nearly at once.
		local tutorial = (player:GetAttribute("Ftue") or 99) < 6
		local delay = 1.5
		-- Another free player nearby: give them time to come and fight (player vs player), and tell them.
		if not altar.rival then
			local here = spots[index][side].cframe.Position
			local tierName = string.upper(altar.tier or "")
			for _, other in Players:GetPlayers() do
				local o = other ~= player and not busy[other] and root(other)
				if o and (o.Position - here).Magnitude < B.pvpRadius then
					delay = tutorial and 1.5 or B.pvpWait
					Net.get("FX"):FireClient(other, "Banner", {
						text = string.upper(player.DisplayName) .. " WANTS TO CLASH AT THE " .. tierName .. " ALTAR!",
						color = Color3.fromRGB(255, 120, 100),
					})
				end
			end
		end
		clash.botAt = os.clock() + delay
		remote:FireClient(player, "Seat", { altar = index, side = side, botIn = delay })
	end
end

local function leave(player, forfeit)
	local where = busy[player]
	if not where then
		return
	end
	local clash = clashes[where.altar]
	if not clash then
		busy[player] = nil
		player:SetAttribute("InClash", nil)
		return
	end
	if clash.phase == "waiting" then
		release(where.altar)
	elseif (clash.phase == "faceoff" or clash.phase == "battle" or clash.phase == "between") and forfeit then
		finish(where.altar, 3 - where.side)
	end
end

local function claimLoop()
	while true do
		task.wait(0.15)
		for _, player in Players:GetPlayers() do
			local r = root(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if
				not r
				or busy[player]
				or (cooldown[player] or 0) > os.clock()
				or not humanoid
				or humanoid.Health <= 0
			then
				continue
			end
			for index, pads in spots do
				local altar = venueOf(index)
				local clash = clashes[index]
				if not altar.model or (clash and clash.phase ~= "waiting") then
					continue
				end
				for side = 1, altar.rival and 1 or 2 do -- a challenge's side 2 is the guardian's
					local pad = pads[side].cframe.Position
					local flat = Vector3.new(r.Position.X - pad.X, 0, r.Position.Z - pad.Z).Magnitude
					if
						flat < B.padRadius
						and math.abs(r.Position.Y - pad.Y) < 7
						and not (clash and clash.sides[side])
					then
						local ok, why = true, nil
						if player:GetAttribute("Carrying") then
							ok, why = false, "TAKE YOUR FIGHTER HOME FIRST"
						elseif
							altar.reservedFor
							and altar.reservedFor ~= player
							and os.clock() < (altar.reservedUntil or 0)
						then
							-- The tutorial's personal drop belongs to one new player for a while.
							ok, why = false, "THIS ONE IS A NEW PLAYER'S GIFT"
						elseif altar.canSeat then
							ok, why = altar.canSeat(player)
						elseif not altar.rival then
							-- Drop altars need the tier's trained Power (Config.Tiers[].power); hub altars are
							-- ROOKIE altars, so strong players can't farm new ones there.
							local need = Config.Tiers[altar.tier].power or 0
							local power = player:GetAttribute("Power") or 0
							if power < need then
								ok, why = false, "NEEDS " .. Format.short(need) .. " POWER · TRAIN TO SIT HERE"
							elseif not altar.zone and power > P.rookieMax then
								ok, why = false, "ROOKIE ALTAR · YOU'RE TOO STRONG! FIGHT IN THE ZONES"
							end
						end
						if ok then
							seat(player, index, side)
						elseif why and os.clock() - (nagged[player] or 0) > 3 then
							nagged[player] = os.clock()
							Net.get("FX")
								:FireClient(player, "Banner", { text = why, color = Color3.fromRGB(255, 120, 100) })
						end
						break
					end
				end
				if busy[player] then
					break
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- the push battle
-- clash.pos 0..1 (side 1 pushes up), clash.goAt (beams start), clash.roundEndsAt, clash.frenzy
-- { endsAt, taps = { n1, n2 } } during an ULTIMATE CLASH. Each side: cps (smoothed), combo, ult (0..1),
-- mult (Power), power, stats.

local function share(side, pos)
	return side == 1 and pos or 1 - pos -- 1 = the point sits on the rival
end

local function startRound(index, clash)
	local t = now()
	clash.phase = "battle"
	clash.pos = 0.5
	clash.goAt = t + P.countdown
	clash.roundEndsAt = clash.goAt + P.roundTime
	clash.frenzy = nil
	clash.rageUsed = false
	for _, s in clash.sides do
		s.combo, s.comboStart, s.lastTap, s.acc, s.lastUlt, s.rageUntil = 1, nil, nil, 0, nil, nil
	end
	remote:FireAllClients("RoundStart", {
		altar = index,
		round = clash.round,
		rounds = clash.rounds,
		goAt = clash.goAt,
		endsAt = clash.roundEndsAt,
		blast = clash.blast,
		final = clash.maxRounds ~= nil and clash.round >= clash.maxRounds,
	})
end

local function endRound(index, clash, winnerSide)
	local loserSide = 3 - winnerSide
	clash.rounds[winnerSide] += 1
	clash.ground[winnerSide] += math.abs(clash.pos - 0.5)
	local matchWinner, tiebreak = ClashRules.matchWinner(
		clash.rounds,
		clash.ground,
		winnerSide,
		clash.roundsToWin or P.roundsToWin,
		clash.maxRounds
	)
	local matchOver = matchWinner ~= nil
	remote:FireAllClients("Round", {
		altar = index,
		winner = winnerSide,
		rounds = clash.rounds,
		matchOver = matchOver,
		pos = clash.pos,
	})
	if matchOver then
		finish(index, matchWinner, tiebreak)
		return
	end
	clash.phase = "between"
	clash.round += 1
	play(clash.sides[loserSide].model, "KO")
	play(clash.sides[winnerSide].model, "Taunt")
	task.delay(P.roundGap, function()
		if clashes[index] == clash and clash.phase == "between" then
			startRound(index, clash)
			for _, s in clash.sides do
				play(s.model, "Fire")
			end
		end
	end)
end

local function addTaps(clash, side, n, t)
	local s = clash.sides[side]
	if n <= 0 then
		return
	end
	if not s.lastTap or t - s.lastTap > P.comboGap then
		s.comboStart = t
	end
	s.lastTap = t
	s.combo = math.min(P.comboMax, 1 + math.floor((t - s.comboStart) / 0.5) * P.comboStep)
	s.tapped += n
	s.stats.taps += n
	s.ult = math.min(1, s.ult + n * (s.ultRate or 1 / P.ultTaps))
	if clash.frenzy then
		clash.frenzy.taps[side] += n
	end
end

local fireUlt -- forward

-- A bot may answer a player's ultimate with its own (an ULTIMATE CLASH), if it has enough charge.
local function botAnswer(index, clash, botSide)
	local s = clash.sides[botSide]
	if s.player or s.noUlt or s.ult < 0.5 or rng:NextNumber() > (s.answer or 0) then
		return
	end
	task.delay(rng:NextNumber(0.25, 0.8), function()
		if clashes[index] == clash and clash.phase == "battle" and not clash.frenzy then
			fireUlt(index, clash, botSide, true)
		end
	end)
end

function fireUlt(index, clash, side, answering)
	local s = clash.sides[side]
	local rival = clash.sides[3 - side]
	local t = now()
	if clash.phase ~= "battle" or t < clash.goAt or clash.frenzy then
		return
	end
	if s.ult < 1 and not answering then
		return
	end
	s.ult = 0
	s.stats.ults += 1
	-- The rival fired theirs a moment ago: ULTIMATE CLASH. Their push is undone; tap frenzy.
	if rival.lastUlt and t - rival.lastUlt.t <= P.clashWindow then
		clash.pos -= (3 - side == 1 and 1 or -1) * rival.lastUlt.push
		clash.pos = math.clamp(clash.pos, 0.02, 0.98)
		rival.lastUlt = nil
		clash.frenzy = { endsAt = t + P.frenzyTime, taps = { 0, 0 } }
		clash.roundEndsAt += P.frenzyTime
		remote:FireAllClients("UltClash", { altar = index, endsAt = clash.frenzy.endsAt, pos = clash.pos })
		return
	end
	local push, stand = ClashRules.ultPush(side, clash.pos, s.mult)
	if stand then
		s.stats.stands += 1
	end
	clash.pos += (side == 1 and 1 or -1) * push
	s.lastUlt = { t = t, push = push }
	remote:FireAllClients("Ult", { altar = index, side = side, push = push, stand = stand, pos = clash.pos })
	if s.player and not rival.player then
		botAnswer(index, clash, 3 - side)
	end
end

local function tick(dt)
	local t = now()
	for index, clash in clashes do
		if clash.phase == "waiting" then
			if clash.botAt and os.clock() >= clash.botAt then
				local empty = clash.sides[1] and 2 or 1
				if addBot(index, empty) then
					begin(index)
				else
					release(index)
				end
			end
		elseif clash.phase == "faceoff" and t >= clash.startAt then
			startRound(index, clash)
		elseif clash.phase == "battle" and t >= clash.goAt then
			-- Bots tap at their rate (faster in a frenzy or a rage) and fire their ultimate when it counts.
			for side, s in clash.sides do
				if not s.player then
					local rate = s.botCps
						* (clash.frenzy and 1.25 or 1)
						* ((s.rageUntil and t < s.rageUntil) and 1.5 or 1)
					s.acc += dt * rate * (0.85 + 0.3 * math.noise(t * 0.7, rate))
					local n = math.floor(s.acc)
					s.acc -= n
					addTaps(clash, side, n, t)
					if s.ult >= 1 and not s.noUlt and not clash.frenzy then
						local mine = share(side, clash.pos)
						if
							mine <= P.lastStand + 0.05
							or (mine >= 0.75 and rng:NextNumber() < dt * 1.5)
							or rng:NextNumber() < dt * 0.12
						then
							fireUlt(index, clash, side)
						end
					end
					-- A boss pushed deep into its half rages once a round.
					if s.boss and not clash.rageUsed and share(side, clash.pos) <= 0.3 then
						clash.rageUsed = true
						s.rageUntil = t + P.bossRage
						remote:FireAllClients("Rage", { altar = index, side = side, untilT = s.rageUntil })
					end
				end
				-- Combo drops after a pause.
				if s.lastTap and t - s.lastTap > P.comboGap then
					s.combo = 1
				end
				s.cps += (s.tapped / math.max(dt, 1e-3) - s.cps) * math.min(1, dt * 3)
				s.tapped = 0
				s.stats.seconds += dt
			end
			if clash.frenzy then
				if t >= clash.frenzy.endsAt then
					local f = clash.frenzy
					clash.frenzy = nil
					local w = f.taps[1] > f.taps[2] and 1 or f.taps[2] > f.taps[1] and 2 or nil
					if w then
						clash.pos += (w == 1 and 1 or -1) * P.frenzySwing
						clash.sides[w].stats.clashes += 1
					end
					remote:FireAllClients("Frenzy", { altar = index, winner = w, taps = f.taps, pos = clash.pos })
				end
			else
				local a, b = clash.sides[1], clash.sides[2]
				clash.pos += (ClashRules.pushForce(a.cps, a.combo, a.mult) - ClashRules.pushForce(
					b.cps,
					b.combo,
					b.mult
				)) * dt
			end
			local winner = ClashRules.pushRoundWinner(clash.pos, not clash.frenzy and t >= clash.roundEndsAt)
			if winner then
				clash.pos = math.clamp(clash.pos, 0, 1)
				endRound(index, clash, winner)
			end
		end
	end
end

local function broadcast()
	while true do
		task.wait(0.1)
		for index, clash in clashes do
			if clash.phase == "battle" then
				local a, b = clash.sides[1], clash.sides[2]
				remote:FireAllClients("State", {
					altar = index,
					pos = clash.pos,
					cps = { a.cps or 0, b.cps or 0 },
					combo = { a.combo or 1, b.combo or 1 },
					ult = { a.ult or 0, b.ult or 0 },
					frenzy = clash.frenzy and clash.frenzy.taps,
					endsAt = clash.roundEndsAt,
				})
			end
		end
	end
end

local function onClient(player, kind, value)
	local where = busy[player]
	if kind == "Leave" then
		leave(player, false)
		return
	end
	if not where then
		return
	end
	local clash = clashes[where.altar]
	if not clash or clash.phase ~= "battle" then
		return
	end
	local s = clash.sides[where.side]
	local t = now()
	if kind == "Click" and typeof(value) == "number" then
		if t < clash.goAt then
			return
		end
		local accepted = ClashRules.accept(s.bucket, t, value)
		addTaps(clash, where.side, accepted, t)
	elseif kind == "Ult" then
		fireUlt(where.altar, clash, where.side)
	end
end

-- Register a guardian or boss venue. spec: pads = { playerPad, rivalPad } (Parts), model (the display
-- the fight is over), model_parent, tier, title, rounds, rival = { key, name, skill, cps, scale },
-- canSeat(player) -> ok, reason, onResult(winnerPlayer?, loserPlayer?). Returns the venue index.
-- Whether a player is seated at an altar or venue (training ignores their clicks then).
function ClashService.isBusy(player)
	return busy[player] ~= nil
end

-- The altar index a player is seated at, or nil.
function ClashService.seatedAt(player)
	return busy[player] and busy[player].altar
end

local nextChallenge = 1000
function ClashService.addChallenge(spec)
	nextChallenge += 1
	local index = nextChallenge
	challenges[index] = spec
	local a, b = spec.pads[1], spec.pads[2]
	spots[index] = {
		{ pad = a, cframe = CFrame.lookAt(a.Position, Vector3.new(b.Position.X, a.Position.Y, b.Position.Z)) },
		{ pad = b, cframe = CFrame.lookAt(b.Position, Vector3.new(a.Position.X, b.Position.Y, a.Position.Z)) },
	}
	return index
end

function ClashService.start(world, dropService)
	Drops = dropService
	for index, pair in world.pads do
		spots[index] = {}
		for side, pad in pair do
			local other = pair[3 - side]
			local flat = Vector3.new(other.Position.X, pad.Position.Y, other.Position.Z)
			spots[index][side] = { pad = pad, cframe = CFrame.lookAt(pad.Position, flat) }
		end
	end
	remote.OnServerEvent:Connect(onClient)
	RunService.Heartbeat:Connect(tick)
	Players.PlayerRemoving:Connect(function(player)
		leave(player, true)
		cooldown[player], wins[player], nagged[player] = nil, nil, nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			leave(player, true)
		end)
	end)
	task.spawn(claimLoop)
	task.spawn(broadcast)
end

return ClashService
