-- The first-time experience and the goals checklist (docs/FTUE_PLAN.md). Server-authoritative; the client
-- (client/Tutorial.lua) draws whatever these player attributes say:
--   Ftue        the step (below); 99 = done. Saved, so a rejoin resumes where the player left off.
--   FtueText    the coach line for this step
--   FtueTarget  a world position the arrow and beam point at (nil = none)
--   Goals       JSON list of the 3 active goals: { t = text, have, need, r = reward text }
-- Fighter first: a new player wins a fighter within a minute, and everything else is taught after that.
-- Order: 1 intro swoop (client) · 4 walk to the personal drop (Luffi, TUTORIAL_FIGHTER) · 5 win the clash ·
-- 6 take it home · 7 collect the pad · 2 click to train (gift weights at 50) · 3 click at the base's punching
-- post (x2) to 1K (first aura) · 10 buy Stone Weights at the gear shop · 11 train to the first zone's Power (2K) ·
-- 12 walk to its gate · then done (+$2K, goals appear; inside, the zone's quest card leads to the guardians). The numbers are saved, so
-- they keep their old meaning. A save from the old order (training first) goes 3 -> 4 and skips 2-3 after 7.
-- (Stealing isn't taught: players find it at other bases. Locking is taught the first time someone steals from
-- them (PlotService). Steps 8 and 9 are gone; a save on either moves on to 10.)
-- Training is x5 for steps 2-3 and x2 for the rest (TutorialBoost).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Goals = require(Shared.Goals)
local Training = require(Shared.Training)
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local GymKit = require(script.Parent.Parent.Zones.GymKit)
local Funnel = require(script.Parent.Parent.Funnel)

local TutorialService = {}
local FX = Net.get("FX")
local remote = Net.get("Tutorial")
local Data, Drops, Clash, Plots, Shop

local GOLD = Color3.fromRGB(255, 214, 80)
local GREEN = Color3.fromRGB(120, 255, 150)
local DONE = 99
-- The tutorial's first prize: always Luffi (Luffy, Epic), a face every kid knows (shared/Fighters.lua).
local TUTORIAL_FIGHTER = "Tsluffy"
local MENU_AFTER = 600 -- seconds in an unfinished tutorial before the whole menu opens anyway
local GIFT_POWER, AURA_POWER = 50, 1000
local FIRST_WEIGHTS = 3 -- Stone Weights (shared/Training.lua): the tutorial's last step buys them
local START_POWER = Config.Push.botPower.Tutorial -- an even first fight: at 0 Power no amount of tapping could win it

local TEXT = {
	[2] = "CLICK ANYWHERE TO TRAIN!",
	[3] = "STAND AT THE PUNCHING POST!", -- (it seats you and trains by itself)
	[4] = "A FIGHTER DROPPED! STAND ON THE BLUE PAD",
	[5] = "TAP FAST TO PUSH THE BEAM!",
	[6] = "TAKE YOUR FIGHTER HOME AND PUT IT ON A STAND!",
	[7] = "STEP ON THE GREEN PAD TO COLLECT!",
	[10] = "FOLLOW THE ARROW AND BUY STONE WEIGHTS!",
	-- After the weights, the way into the first zone (its own quest card takes over once inside).
	[11] = "TRAIN AT YOUR POST OR WIN FIGHTS AT THE ALTARS: " .. Format.short(
		Config.Zones[Config.ZoneOrder[1]].unlockPower or 0
	) .. " POWER OPENS THE NEXT ZONE!",
	[12] = "THE " .. Config.Zones[Config.ZoneOrder[1]].title .. " IS OPEN! FOLLOW THE ARROW",
}
local FIRST_ZONE = Config.ZoneOrder[1]

local state = {} -- [player] = { altar, resultAt, droppedAt }

local function banner(player, text, color)
	FX:FireClient(player, "Banner", { text = text, color = color })
end

local function rootOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

-- ------------------------------------------------------------------ goals

local function publishGoals(player, data)
	local list = {}
	for _, id in data.goalOrder or {} do
		local g = Goals.ById[id]
		local base = data.goals[id]
		if g and base then
			local have = Goals.metric(data, g.metric) - (g.relative and base or 0)
			local need = g.need
			if g.done then
				have, need = have >= need and 1 or 0, 1
			end
			table.insert(list, { t = g.text, have = math.max(0, have), need = need, r = Goals.rewardText(g) })
		end
	end
	player:SetAttribute("Goals", HttpService:JSONEncode(list))
end

local function fillGoals(data)
	data.goalOrder = data.goalOrder or {}
	local guard = 0
	while #data.goalOrder < 3 and guard < 20 do
		guard += 1
		local g
		if data.goalNext <= #Goals.List then
			g = Goals.List[data.goalNext]
			data.goalNext += 1
		else
			-- Repeatables, round-robin, never twice at once.
			local r = Goals.Repeat[(data.goalNext - #Goals.List - 1) % #Goals.Repeat + 1]
			data.goalNext += 1
			if not data.goals[r.id] then
				g = r
			end
		end
		if g and not data.goals[g.id] then
			data.goals[g.id] = g.relative and Goals.metric(data, g.metric) or 0
			table.insert(data.goalOrder, g.id)
		end
	end
end

local function reward(player, data, g)
	if g.cash then
		Plots.addCash(player, g.cash)
	elseif g.boost then
		data.boostUntil.PowerBoost = math.max(data.boostUntil.PowerBoost or 0, os.time()) + g.boost * 60
		Shop.refresh(player)
	end
	FX:FireClient(player, "GoalDone", { text = g.text, reward = Goals.rewardText(g) })
end

local function checkGoals(player, data)
	fillGoals(data)
	local changed = false
	for i = #data.goalOrder, 1, -1 do
		local id = data.goalOrder[i]
		local g = Goals.ById[id]
		local have = g and (Goals.metric(data, g.metric) - (g.relative and data.goals[id] or 0))
		if not g or have >= g.need then
			table.remove(data.goalOrder, i)
			data.goals[id] = nil
			if g then
				reward(player, data, g)
			end
			changed = true
		end
	end
	if changed then
		fillGoals(data)
		Data.changed(player)
	end
	publishGoals(player, data)
end

-- ------------------------------------------------------------------ steps

local setStep -- forward

-- After the training steps: on to the weights, or (a save from the old order, no fighter won yet) to the first drop.
local function afterTraining(data)
	return data.stats.wins > 0 and 10 or 4
end

-- The tutorial drop: a personal Epic on the nearest free hub Bronze altar, held for this player.
local function dropFor(player)
	local root = rootOf(player)
	if not root then
		return nil
	end
	local best, bestDist
	for index, altar in Drops.Altars do
		if altar.tier == "Bronze" and not altar.zone and not altar.locked and not Clash.seatedAt(player) then
			local free = not altar.reservedFor or altar.reservedFor == player or os.clock() > (altar.reservedUntil or 0)
			local d = (altar.stand - root.Position).Magnitude
			if free and (not bestDist or d < bestDist) then
				best, bestDist = index, d
			end
		end
	end
	if not best then
		return nil
	end
	local altar = Drops.Altars[best]
	if altar.model and altar.reservedFor ~= player then
		Drops.clear(best)
	end
	-- (Also when the reserved drop was cleared, e.g. it timed out unclaimed.)
	if altar.reservedFor ~= player or not altar.key then
		Drops.drop(best, { key = TUTORIAL_FIGHTER })
		altar.reservedFor = player
		state[player].droppedAt = os.clock()
	end
	altar.reservedUntil = os.clock() + 90
	-- The pad to stand on: side 1's marker.
	local model = workspace.Map.Altars:FindFirstChild("Altar" .. best)
	for _, d in model and model:GetDescendants() or {} do
		if d.Name == "ClashPad" and d:GetAttribute("Side") == 1 then
			player:SetAttribute("FtueTarget", d.Position)
		end
	end
	return best
end

-- The player's own base punching post (else the nearest one).
local function postTarget(player)
	local root = rootOf(player)
	local mine = player:GetAttribute("Plot")
	local best, bestDist
	for _, station in GymKit.List do
		local d = root and (station.spot.Position - root.Position).Magnitude or 0
		local plot = station.model:GetAttribute("Plot")
		if plot == mine and plot ~= nil then
			d = -1
		elseif plot then
			continue
		end
		if station.key == "PunchPost" and (not bestDist or d < bestDist) then
			best, bestDist = station, d
		end
	end
	return best and best.spot.Position
end

local function enter(player, step)
	local data = Data.get(player)
	Funnel.tutorial(player, data, step)
	player:SetAttribute("Ftue", step)
	player:SetAttribute("FtueText", TEXT[step])
	player:SetAttribute("FtueTarget", nil)
	player:SetAttribute("TutorialBoost", (step == 2 or step == 3) and 5 or (step >= 4 and step < DONE) and 2 or nil)
	local places = Plots.places(player)
	if step == 4 then
		state[player].altar = dropFor(player)
	elseif step == 3 then
		player:SetAttribute("FtueTarget", postTarget(player))
	elseif step == 11 and data then
		if data.power >= (Config.Zones[FIRST_ZONE].unlockPower or 0) then
			task.defer(setStep, player, 12)
			return
		end
		player:SetAttribute("FtueTarget", postTarget(player))
	elseif step == 12 and data then
		if data.stats.zones[FIRST_ZONE] then
			task.defer(setStep, player, DONE)
			return
		end
		for _, gate in CollectionService:GetTagged("ZoneGate") do
			if gate:GetAttribute("Zone") == FIRST_ZONE then
				player:SetAttribute("FtueTarget", gate:GetPivot().Position)
			end
		end
	elseif step == 6 and places then
		player:SetAttribute("FtueTarget", places.gate)
	elseif step == 7 and places then
		Plots.addStash(player, 1, 5000)
		player:SetAttribute("FtueTarget", places.pad)
	elseif step == 8 or step == 9 then
		task.defer(setStep, player, 10) -- (no practice steal or lock step any more)
	elseif step == 10 and data then
		if data.gear >= FIRST_WEIGHTS then
			task.defer(setStep, player, 11)
			return
		end
		-- Enough cash for them, so the first shop visit always ends in a purchase.
		local cost = Training.Gear[FIRST_WEIGHTS].cost
		if data.cash < cost then
			banner(player, "GIFT! +" .. Format.cash(cost - data.cash), GOLD)
			Plots.addCash(player, cost - data.cash)
		end
		-- The nearest stall that sells them.
		local root = rootOf(player)
		local best, bestDist
		for _, stall in GymKit.Stalls do
			local d = root and (stall.position - root.Position).Magnitude or 0
			if table.find(stall.tiers, FIRST_WEIGHTS) and (not bestDist or d < bestDist) then
				best, bestDist = stall, d
			end
		end
		player:SetAttribute("FtueTarget", best and best.position)
	elseif step == DONE then
		player:SetAttribute("FtueText", nil)
		if data and not data.ftueDoneAt then
			data.ftueDoneAt = os.time() -- (client UIKit.menu opens the later tiles from this)
		end
		player:SetAttribute("FtueDoneAt", data and data.ftueDoneAt)
		if data then
			checkGoals(player, data)
		end
	end
end

function setStep(player, step)
	local data = Data.get(player)
	if not data or data.ftue == step then
		return
	end
	data.ftue = step
	Data.changed(player)
	if step == DONE then
		Plots.addCash(player, 2000)
		banner(player, "YOU'RE READY! +" .. Format.cash(2000), GOLD)
		FX:FireClient(player, "FtueDone", {})
	end
	enter(player, step)
end

-- Checks each step's goal (called a few times a second).
local function tick(player)
	local data = Data.get(player)
	local s = state[player]
	if not data or not s then
		return
	end
	local step = data.ftue
	if step >= DONE then
		return
	end
	local root = rootOf(player)
	-- Rejoined mid-step: the base wasn't assigned yet when the step was entered, so the arrow still needs setting.
	if (step == 6 or step == 7) and player:GetAttribute("FtueTarget") == nil then
		local places = Plots.places(player)
		if places then
			player:SetAttribute("FtueTarget", step == 6 and places.gate or places.pad)
		end
	end
	if step == 2 and data.power >= GIFT_POWER then
		if data.gear < 2 then
			data.gear = 2
			Data.changed(player)
			banner(player, "GIFT! WOODEN WEIGHTS · x2 PER CLICK", GREEN)
			FX:FireAllClients("GearUp", { userId = player.UserId, tier = 2 })
		end
		setStep(player, 3)
	elseif step == 3 and data.power < AURA_POWER then
		-- Once on the post: no target, and the coach explains it trains by itself.
		local seated = player:GetAttribute("TrainStation") ~= nil -- the post, or any station they chose
		local text = seated and "IT TRAINS BY ITSELF! TAP TO GO FASTER" or TEXT[3]
		if player:GetAttribute("FtueText") ~= text then
			player:SetAttribute("FtueText", text)
			if seated then
				player:SetAttribute("FtueTarget", nil)
			else
				enter(player, 3)
			end
		end
	elseif step == 3 and data.power >= AURA_POWER then
		task.delay(1.6, setStep, player, afterTraining(data)) -- let the first power-up moment play
		data.ftue = 3.5 -- (waiting)
	elseif step == 4 then
		local altar = s.altar and Drops.Altars[s.altar]
		local seat = Clash.seatedAt(player)
		local seatAltar = seat and Drops.Altars[seat]
		-- Any hub altar counts (a new player often takes the one next to the arrow).
		if seatAltar and not seatAltar.zone then
			s.altar = seat
			setStep(player, 5)
		elseif
			not altar
			or altar.reservedFor ~= player
			or not altar.key
			-- The beam came down but no fighter stands there (it failed to spawn): drop it again.
			or (not altar.model and os.clock() - (s.droppedAt or 0) > Config.Drops.landDelay + 4)
		then
			s.altar = dropFor(player)
		else
			altar.reservedUntil = os.clock() + 90
		end
	elseif step == 5 then
		-- Walked off before it started, or the result came back a loss: try again.
		if not Clash.seatedAt(player) and os.clock() - (s.resultAt or 0) > 4 then
			setStep(player, 4)
		end
	elseif step == 6 and root and Plots.isHome(player, root.Position) and player:GetAttribute("CarryKind") == "own" then
		-- Home with it: the arrow moves from the gate to a free stand.
		local places = Plots.places(player)
		if places and places.free and player:GetAttribute("FtueTarget") ~= places.free then
			player:SetAttribute("FtueTarget", places.free)
		end
	elseif
		step == 6
		and root
		and Plots.isHome(player, root.Position)
		and player:GetAttribute("CarryKind") ~= "own" -- placed it (client/Plots.lua says how)
	then
		setStep(player, 7)
	elseif step == 10 and data.gear >= FIRST_WEIGHTS then
		setStep(player, 11)
	elseif step == 11 and data.power >= (Config.Zones[FIRST_ZONE].unlockPower or 0) then
		setStep(player, 12)
	elseif step == 12 and (data.stats.zones[FIRST_ZONE] or player:GetAttribute("Zone") == FIRST_ZONE) then
		setStep(player, DONE)
	end
end

function TutorialService.start(_world, deps)
	Data, Drops, Clash, Plots, Shop = deps.Data, deps.Drops, deps.Clash, deps.Plots, deps.Shop

	-- Goal counters.
	local function bump(player, stat, n)
		local data = Data.get(player)
		if data then
			data.stats[stat] = (data.stats[stat] or 0) + (n or 1)
			Data.touch(player)
		end
	end
	Clash.onResult = function(winner, loser)
		if winner then
			bump(winner, "wins")
		end
		for _, p in { winner, loser } do
			if p and state[p] then
				state[p].resultAt = os.clock()
				local data = Data.get(p)
				if data and (data.ftue == 5 or data.ftue == 4) then
					if p == winner then
						task.delay(2.5, setStep, p, 6)
					else
						banner(p, "SO CLOSE! TRY AGAIN", GOLD)
						task.delay(3, setStep, p, 4)
					end
				end
			end
		end
	end
	Clash.onSeat = function(player, altar)
		if altar and altar.tier == "Silver" and not altar.rival then
			bump(player, "silver")
		end
	end
	Plots.onCollect = function(player, amount)
		bump(player, "collected", amount)
		local data = Data.get(player)
		if data and data.ftue == 7 then
			setStep(player, data.power >= AURA_POWER and 10 or 2) -- (at the base, right by its punching post)
		end
	end
	Plots.onSteal = function(player)
		bump(player, "steals")
	end

	Data.onLoaded(function(player, data)
		player:SetAttribute("FtueDoneAt", data.ftueDoneAt) -- (UIKit.menu: the later tiles)
		state[player] = {}
		player:SetAttribute("SeenCharge", data.seenCharge == true or nil)
		player:SetAttribute("SeenFollower", data.seenFollower == true or nil)
		local settings = data.settings or {}
		player:SetAttribute("MusicOff", settings.music == false or nil)
		player:SetAttribute("SfxOff", settings.sfx == false or nil)
		player:SetAttribute("LeftHanded", settings.lefty == true or nil)
		player:GetAttributeChangedSignal("Zone"):Connect(function()
			local zone = player:GetAttribute("Zone")
			if zone and zone ~= "Hub" and not data.stats.zones[zone] then
				data.stats.zones[zone] = true
				player:SetAttribute("NewZone", zone) -- first visit: the zone's quest card (client/ZoneQuest.lua)
				Data.touch(player)
			end
		end)
		if data.ftue == 3.5 then
			data.ftue = afterTraining(data)
		end
		-- When the tutorial began (for the menu's safety net below).
		if data.ftue < DONE then
			if not data.ftueStarted then
				data.ftueStarted = os.time()
				Data.changed(player)
			end
		end
		enter(player, data.ftue >= DONE and DONE or data.ftue)
		-- Studio: set the player attribute ResetFTUE to replay the tutorial, or DebugFtueStep = n to jump.
		if RunService:IsStudio() then
			player:GetAttributeChangedSignal("DebugFtueStep"):Connect(function()
				local n = player:GetAttribute("DebugFtueStep")
				if type(n) == "number" then
					player:SetAttribute("DebugFtueStep", nil)
					setStep(player, n)
				end
			end)
			player:GetAttributeChangedSignal("ResetFTUE"):Connect(function()
				if player:GetAttribute("ResetFTUE") then
					player:SetAttribute("ResetFTUE", nil)
					Data.discardSession(player) -- (a test run: never written to the real save)
					local live = Data.get(player)
					live.power = 0
					player:SetAttribute("Power", 0)
					live.ftue = 0
					setStep(player, 1)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
	remote.OnServerEvent:Connect(function(player, kind, value)
		local data = Data.get(player)
		if kind == "Swooped" and data and data.ftue == 1 then
			if data.power < START_POWER then
				data.power = START_POWER
				player:SetAttribute("Power", data.power)
			end
			setStep(player, 4)
		elseif kind == "Settings" and data and type(value) == "table" then
			-- Music and sound effects on or off (client/Audio.lua).
			data.settings = { music = value.music ~= false, sfx = value.sfx ~= false, lefty = value.lefty == true }
			player:SetAttribute("MusicOff", not data.settings.music or nil)
			player:SetAttribute("SfxOff", not data.settings.sfx or nil)
			player:SetAttribute("LeftHanded", data.settings.lefty or nil)
			Data.changed(player)
		elseif kind == "SeenFollower" and data and not data.seenFollower then
			-- Saw the follower card (client/Bag.lua).
			data.seenFollower = true
			player:SetAttribute("SeenFollower", true)
			Data.changed(player)
		elseif kind == "SeenCharge" and data and not data.seenCharge then
			-- Fired a charged attack: the clash stops coaching it (client/Clash.lua).
			data.seenCharge = true
			player:SetAttribute("SeenCharge", true)
			Data.changed(player)
		end
	end)

	task.spawn(function()
		local n = 0
		while true do
			task.wait(0.25)
			n += 1
			for player in state do
				tick(player)
				local data = Data.get(player)
				if data and data.ftue >= DONE and n % 4 == 0 then
					checkGoals(player, data)
					Funnel.progress(player, data)
				end
				-- The menu's safety net: 10 minutes into an unfinished tutorial (this visit or across visits), the
				-- whole menu opens anyway (client/UIKit.lua). The tutorial carries on; it can still be finished.
				if
					data
					and data.ftue < DONE
					and not player:GetAttribute("MenuOpen")
					and os.time() - (data.ftueStarted or os.time()) >= MENU_AFTER
				then
					player:SetAttribute("MenuOpen", true)
				end
			end
		end
	end)
end

return TutorialService
