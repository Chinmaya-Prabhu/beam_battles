-- The plot economy (docs/PROGRESSION.md, update 2026-10-20). Server-authoritative:
--   * each player gets the first free plot when their data loads (player attribute Plot); its torii shows
--     their name,
--   * each fighter in the player's bag (data.fighters) stands where they put it (entry.s = stand slot, nil =
--     in the bag). Wins come home over their head (PlotService.hold): hold E at a stand to place it there
--     (or swap with what stands there), hold E on a filled stand to pick it up and move it, R sends it to
--     the bag. Old saves are laid out once: best earners on the unlocked stands (data.placed),
--   * every second each standing fighter adds its income to that stand's stash, shown on the collect pad,
--   * the owner steps on a pad to collect it into Cash (FX "Collect" for the coins and the pop),
--   * locked stands carry a prompt that unlocks them for Config.Plot.standPrices[slot] cash,
--   * the Plot remote's "Home" sends the player to their base,
--   * grab-and-run stealing: hold E at someone else's stand to lift its fighter over your head, then run
--     it home (slowed). Reaching your own plot keeps it; the owner touching you, dying, leaving or 60 s
--     sends it back. While carried its stand is empty and earns nothing,
--   * the base lock: the owner steps on the plot's LOCK pad to block steals for 60 s.
-- Stash and cash live in the save (DataService), so uncollected money waits on the pads.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local Dances = require(Shared.Dances)
local FighterModels = require(Shared.FighterModels)
local Odds = require(Shared.Odds)
local LiveOps = require(Shared.LiveOps)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Carry = require(script.Parent.Parent.Carry)
local Streaming = require(script.Parent.Parent.Streaming)
local Social = require(script.Parent.SocialService)

local PlotService = {}
local FX = Net.get("FX")
local remote = Net.get("Plot")
local Data

local GREEN = Color3.fromRGB(120, 255, 150)
local RED = Color3.fromRGB(255, 120, 100)
local SLOTS = 18 -- 1-8 bought with cash, 9-10 the +2 Stands pass, 11-18 Floor 2 (its pass, then cash each)
local CASH_SLOTS = 8
local FLOOR2 = 10 -- Floor 2's stands are FLOOR2 + 1 .. FLOOR2 + 8 (Config.Plot.floor2Prices)
local GOLD = Color3.fromRGB(255, 214, 80)

local plots = {} -- [index] = { model, owner, label, lockedUntil, stands = { [slot] = stand } }
local owned = {} -- [player] = plot
local carried = {} -- [fighter entry] = theft (while someone is running off with it)
local holds = {} -- [player] = { entry, model }
local showFloor2 -- defined with refresh: their own fighter over their head, on its way to a stand
local thefts = {} -- [thief] = { entry, victim, model, started }
local Training -- TrainingService (set in start)
local endTheft -- defined with the stealing below (release needs it first)

-- Stealing is free (as in the big games); paid perks plug in as player attributes the monetization step
-- sets: FastSteal (shorter hold, applied by the client), LockBonus (extra lock seconds), CarryBoost
-- (extra walk speed while carrying).
local STEAL = { hold = 1.5, fastHold = 0.5, timeout = 60, catchRadius = 5, slowSpeed = 11, lockTime = 60 }

local function rootPosition(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or Vector3.zero
end

local function banner(player, text, color)
	FX:FireClient(player, "Banner", { text = text, color = color })
end

local function income(entry)
	return Odds.income(entry.k, entry.m or "Normal", entry.r)
end

-- ------------------------------------------------------------------ display

local function nameplate(model, entry)
	local fighter = Fighters.ByKey[entry.k]
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "StandPlate"
	local m = entry.m or "Normal"
	local mutated = m ~= "Normal" and Config.Mutations[m]
	gui.Size = UDim2.fromScale(8, mutated and 4.4 or 3.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Adornee = head
	local function line(text, color, y, h)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.Color = Color3.fromRGB(30, 16, 40)
		s.Parent = l
		l.Parent = gui
	end
	-- The mutation's own tag (in its colour, with its multiplier), the name in white, the rarity in its
	-- colour, then the income: a Golden Common never reads as a Legendary.
	local rarity = Config.Rarities[fighter.rarity]
	local top = 0
	if mutated then
		line(string.upper(m) .. "  x" .. mutated.mult, mutated.color, 0, 0.18)
		top = 0.18
	end
	local k = 1 - top
	line(string.upper(fighter.display), Color3.new(1, 1, 1), top, 0.42 * k)
	line(string.upper(fighter.rarity), rarity.color, top + 0.42 * k, 0.26 * k)
	line(Format.cash(income(entry)) .. "/s", GREEN, top + 0.68 * k, 0.32 * k)
	gui.Parent = model
end

local function setPad(stand, amount)
	stand.cashLabel.Text = Format.cash(math.floor(amount))
end

local function clearStand(stand)
	if stand.fighter then
		stand.fighter:Destroy()
		stand.fighter = nil
	end
	stand.entry = nil
end

-- Shows `entry` on the stand (or nothing), and the lock if the stand isn't unlocked.
local function dress(stand, entry, unlocked, plotIndex)
	stand.lock.Enabled = not unlocked
	stand.prompt.Enabled = not unlocked
	stand.prompt:SetAttribute("Plot", plotIndex)
	stand.steal:SetAttribute("Plot", plotIndex)
	-- A fighter being carried off leaves its stand empty (and earning nothing) until it's back.
	local away = entry and carried[entry]
	stand.steal.Enabled = unlocked and entry ~= nil and not away
	if entry then
		stand.steal.ObjectText = Fighters.ByKey[entry.k].display
	end
	if unlocked and entry and not away then
		if stand.entry and stand.entry.k == entry.k and stand.entry.m == entry.m then
			return
		end
		clearStand(stand)
		local scale = FighterModels.scaleFor(entry.k, "Plot") * (Config.Mutations[entry.m or "Normal"].scale or 1)
		local model = FighterModels.spawn(entry.k, stand.top.Position, stand.top.LookVector, {
			scale = scale,
			parent = stand.model,
			mutation = entry.m,
			aura = true,
		})
		if model then
			model.Name = "Fighter"
			model:SetAttribute("Clip", Fighters.signature(entry.k))
			model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
			nameplate(model, entry)
			stand.fighter = model
		end
		stand.entry = entry
	else
		clearStand(stand)
	end
end

-- The player's fighters ranked by income, best first (indices into data.fighters).
local function ranked(data)
	local list = {}
	for i in data.fighters do
		table.insert(list, i)
	end
	table.sort(list, function(a, b)
		return income(data.fighters[a]) > income(data.fighters[b])
	end)
	return list
end

local function isUnlocked(player, data, slot)
	if slot > FLOOR2 then
		return player:GetAttribute("Floor2") == true and slot - FLOOR2 <= (data.floor2 or 0)
	end
	return slot <= data.stands or (slot > CASH_SLOTS and player:GetAttribute("ExtraStands") == true)
end

-- [slot] = the entry standing there (one per stand; a second one claiming a stand goes back to the bag).
local function placements(data)
	local at = {}
	for _, e in data.fighters do
		if e.s then
			if at[e.s] then
				e.s = nil
			else
				at[e.s] = e
			end
		end
	end
	return at
end

-- Saves from before stands were chosen by hand: the best earners go on the unlocked stands, once.
local function layOut(player, data)
	if data.placed then
		return
	end
	data.placed = true
	local slot = 0
	for _, i in ranked(data) do
		repeat
			slot += 1
		until slot > SLOTS or isUnlocked(player, data, slot)
		if slot > SLOTS then
			break
		end
		data.fighters[i].s = slot
	end
	Data.changed(player)
end

local function fullName(entry)
	local fighter = Fighters.ByKey[entry.k]
	return string.upper(
		(entry.m and entry.m ~= "Normal" and (entry.m .. " ") or "") .. (fighter and fighter.display or entry.k)
	)
end

-- The owner's E / R prompts on a stand say what they'll do: place or swap what you hold, pick up or
-- bag what stands there.
local function promptsFor(player, stand, entry, unlocked)
	local hold = holds[player]
	stand.move.Enabled = unlocked and (hold ~= nil or entry ~= nil)
	stand.move.ActionText = hold and (entry and "Swap" or "Place Here") or "Pick Up"
	stand.move.ObjectText = hold and fullName(hold.entry) or (entry and fullName(entry) or "")
	stand.bag.Enabled = unlocked and entry ~= nil and hold == nil
	stand.bag.ObjectText = entry and fullName(entry) or ""
end

-- Shows or hides a plot's Floor 2: the deck, its ladder and its eight stands.
function showFloor2(plot, shown)
	if plot.floor2Shown == shown then
		return
	end
	plot.floor2Shown = shown
	for _, root in plot.floor2Parts do
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				if d:GetAttribute("T0") == nil then
					d:SetAttribute("T0", d.Transparency)
					d:SetAttribute("C0", d.CanCollide)
				end
				d.Transparency = shown and d:GetAttribute("T0") or 1
				d.CanCollide = shown and d:GetAttribute("C0") or false
				d.CanQuery = shown
			elseif d:IsA("SurfaceGui") or (d:IsA("BillboardGui") and d.Name == "Cash") then
				d.Enabled = shown
			end
		end
	end
end

function PlotService.refresh(player)
	local plot = owned[player]
	local data = Data.get(player)
	if not plot or not data then
		return
	end
	layOut(player, data)
	Training.fixChampion(player, holds[player] and holds[player].entry) -- never on a stand, never in your hands
	for i = 1, SLOTS do
		data.stash[i] = data.stash[i] or 0 -- saves from before Floor 2 had 10 (no holes in the saved list)
	end
	local at = placements(data)
	-- What the next stand is worth: the best earner waiting in the bag (none placed means it's all upside).
	local bestWaiting = 0
	for _, e in data.fighters do
		if not e.s then
			bestWaiting = math.max(bestWaiting, income(e))
		end
	end
	for slot = 1, SLOTS do
		local stand = plot.stands[slot]
		if stand then
			local unlocked = isUnlocked(player, data, slot)
			dress(stand, unlocked and at[slot] or nil, unlocked, plot.index)
			promptsFor(player, stand, unlocked and at[slot] or nil, unlocked)
			setPad(stand, data.stash[slot] or 0)
			-- Floor 2's stands (only there with its pass): cash locks in order, like the ground floor's.
			if slot > FLOOR2 and not unlocked then
				local k = slot - FLOOR2
				if player:GetAttribute("Floor2") then
					local price = Config.Plot.floor2Prices[k]
					local isNext = k == (data.floor2 or 0) + 1
					stand.lockLabel.Text = (isNext and "NEXT: STAND " or "STAND ") .. slot .. "\n" .. Format.cash(price)
					stand.lockLabel.TextColor3 = isNext and GREEN or RED
					stand.prompt.ActionText = "Unlock  ·  " .. Format.cash(price)
				else
					stand.lock.Enabled = false
					stand.prompt.Enabled = false
				end
			end
			-- Locked cash stands say which one is next, so nobody walks to stand 7 first.
			local price = Config.Plot.standPrices[slot]
			if not unlocked and price and stand.lockLabel then
				local isNext = slot == data.stands + 1
				stand.lockLabel.Text = (isNext and "NEXT: STAND " or "STAND ") .. slot .. "\n" .. Format.cash(price)
				if isNext then
					-- +1 fighter earning: how much the best one in the bag would add.
					stand.lockLabel.Text ..= bestWaiting > 0 and ("\n+" .. Format.cash(bestWaiting) .. "/s FROM YOUR BAG") or "\n+1 FIGHTER EARNING"
				end
				stand.lockLabel.TextColor3 = isNext and GREEN or RED
				stand.lock.Size = UDim2.fromScale(isNext and 8 or 5.5, isNext and 4.6 or 3)
				stand.lock.StudsOffsetWorldSpace = Vector3.new(0, isNext and 5.2 or 3, 0) -- (the taller one clears the stand)
			end
		end
	end
	-- Floor 2 shows with its pass; before that, once stand 8 is open, its offer stands where the ladder goes.
	local has = player:GetAttribute("Floor2") == true
	showFloor2(plot, has)
	local offer = not has and data.stands >= CASH_SLOTS
	plot.offer.Transparency = offer and 0 or 1
	plot.offerPrompt.Enabled = offer
	plot.offerSign.Enabled = offer
	player:SetAttribute("Stands", data.stands)
	player:SetAttribute("BagVersion", (player:GetAttribute("BagVersion") or 0) + 1) -- client/Bag.lua reloads
end

-- ------------------------------------------------------------------ holding your own fighters

-- Stops holding (the fighter is already safe in the bag). `why` = a banner to show, if any.
local function letGo(player, why)
	local hold = holds[player]
	if not hold then
		return
	end
	holds[player] = nil
	if hold.model then
		hold.model:Destroy()
	end
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("CarryKind", nil)
	if why and player.Parent then
		banner(player, why, Color3.fromRGB(255, 214, 80))
	end
end

-- Lifts `entry` (one of the player's own, in the bag) over their head to take to a stand. Whatever they
-- held before goes to the bag.
function PlotService.hold(player, entry)
	if player:GetAttribute("InClash") then
		-- Won on a clash pad: lift it once they're off the pad (after the result card).
		task.spawn(function()
			local waited = 0
			while player.Parent and player:GetAttribute("InClash") and waited < 20 do
				waited += task.wait(0.25)
			end
			local data = Data.get(player)
			if player.Parent and data and table.find(data.fighters, entry) and not entry.s then
				PlotService.hold(player, entry)
			end
		end)
		return
	end
	if holds[player] then
		letGo(player, fullName(holds[player].entry) .. " WENT TO YOUR BAG")
	end
	if thefts[player] then
		return -- busy stealing; the new one waits in the bag
	end
	local model = Carry.lift(player, entry.k, entry.m)
	if model then
		model.Name = "Held_" .. player.Name
		-- R: not now, straight to the bag (a plain Roblox prompt; client/Plots.lua shows it to the holder only).
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HeldBagPrompt"
		prompt.ActionText = "To Bag"
		prompt.ObjectText = fullName(entry)
		prompt.KeyboardKeyCode = Enum.KeyCode.R
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 20
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Owner", player.UserId)
		prompt.UIOffset = Vector2.new(0, -130) -- (negative is down: beside the player, clear of the HUD top line)
		prompt.Parent = model.PrimaryPart
		prompt.Triggered:Connect(function(who)
			if who == player and holds[player] and holds[player].model == model then
				letGo(player, fullName(entry) .. " WENT TO YOUR BAG")
				PlotService.refresh(player)
			end
		end)
	end
	holds[player] = { entry = entry, model = model }
	player:SetAttribute("CarryKind", "own") -- client/Plots.lua: "TAKE IT TO YOUR BASE" / "PRESS E ON A STAND"
	player:SetAttribute("Carrying", entry.k)
	PlotService.refresh(player)
end

-- A summon, a market buy, a gift: straight onto the first empty unlocked stand, else into the bag.
function PlotService.autoPlace(player, entry)
	local data = Data.get(player)
	if not data or not owned[player] then
		return
	end
	layOut(player, data)
	local at = placements(data)
	-- What the next stand is worth: the best earner waiting in the bag (none placed means it's all upside).
	local bestWaiting = 0
	for _, e in data.fighters do
		if not e.s then
			bestWaiting = math.max(bestWaiting, income(e))
		end
	end
	for slot = 1, SLOTS do
		if owned[player].stands[slot] and isUnlocked(player, data, slot) and not at[slot] then
			entry.s = slot
			return
		end
	end
	banner(player, fullName(entry) .. " WENT TO YOUR BAG", Color3.fromRGB(255, 214, 80))
end

local function standEntry(data, slot)
	return placements(data)[slot]
end

-- Hold E at your own stand: place what you hold (swapping with what stands there), or pick it up.
local function moveAt(player, slot)
	local plot = owned[player]
	local data = Data.get(player)
	if not plot or not data or not isUnlocked(player, data, slot) or thefts[player] then
		return
	end
	local there = standEntry(data, slot)
	if carried[there] then
		return -- being stolen right now
	end
	local hold = holds[player]
	if hold then
		letGo(player)
		hold.entry.s = slot
		if there then
			there.s = nil
			PlotService.hold(player, there) -- the swap: now you hold the one that stood here
		end
		banner(player, fullName(hold.entry) .. " IS ON STAND " .. slot .. "!", GREEN)
	elseif there then
		there.s = nil
		PlotService.hold(player, there)
	end
	Data.changed(player)
	PlotService.refresh(player)
end

-- R at your own stand: what stands there goes to the bag.
local function bagAt(player, slot)
	local data = Data.get(player)
	local there = data and owned[player] and standEntry(data, slot)
	if not there or carried[there] then
		return
	end
	there.s = nil
	banner(player, fullName(there) .. " WENT TO YOUR BAG", Color3.fromRGB(255, 214, 80))
	Data.changed(player)
	PlotService.refresh(player)
end

-- The Bag (client/Bag.lua): every fighter the player owns, where it is, and who follows them.
function PlotService.bagList(player)
	local data = Data.get(player)
	if not data then
		return nil
	end
	local list = {}
	for i, e in data.fighters do
		table.insert(list, { i = i, k = e.k, m = e.m or "Normal", s = e.s, r = e.r })
	end
	return {
		list = list,
		champion = data.champion,
		holding = holds[player] and table.find(data.fighters, holds[player].entry),
	}
end

-- ------------------------------------------------------------------ ownership

local function assign(player)
	if owned[player] then
		return
	end
	for index = 1, #plots do
		local plot = plots[index]
		if not plot.owner then
			plot.owner = player
			owned[player] = plot
			player:SetAttribute("Plot", index)
			if plot.label then
				plot.label.Text = string.upper(player.DisplayName) .. "'S BASE"
			end
			PlotService.refresh(player)
			return
		end
	end
	warn("[Plot] no free plot for", player.Name)
end

local function release(player)
	-- A thief leaving drops what they carry; a victim leaving takes it with them (it stays theirs).
	endTheft(player, false)
	letGo(player)
	for thief, theft in thefts do
		if theft.victim == player then
			endTheft(thief, false, "THE OWNER LEFT")
		end
	end
	local plot = owned[player]
	owned[player] = nil
	if not plot then
		return
	end
	plot.owner = nil
	if plot.label then
		plot.label.Text = "EMPTY PLOT"
	end
	if plot.badges then
		plot.badges:Destroy()
		plot.badges = nil
	end
	for _, stand in plot.stands do
		clearStand(stand)
		setPad(stand, 0)
		stand.lock.Enabled = false
		stand.prompt.Enabled = false
	end
	showFloor2(plot, false)
	plot.offer.Transparency = 1
	plot.offerPrompt.Enabled = false
	plot.offerSign.Enabled = false
end

-- A stand opening is a moment: a burst of light and coins on it for its owner (client/Fx.lua, FX
-- "StandUnlocked").
local function unlockMoment(player, plot, slot)
	local stand = plot and plot.stands[slot]
	if stand and stand.model then
		FX:FireClient(player, "StandUnlocked", { position = stand.model:GetPivot().Position, slot = slot })
	end
end

local function unlock(player, slot)
	local plot = owned[player]
	local data = Data.get(player)
	if slot > FLOOR2 then
		-- Floor 2 (with its pass): in order, for cash.
		local k = slot - FLOOR2
		local done = data and data.floor2 or 0
		if not plot or not data or not player:GetAttribute("Floor2") then
			return
		end
		if k ~= done + 1 then
			if k > done + 1 then
				banner(player, "UNLOCK STAND " .. (FLOOR2 + done + 1) .. " FIRST", RED)
			end
			return
		end
		local price = Config.Plot.floor2Prices[k]
		if data.cash < price then
			banner(player, "NEEDS " .. Format.cash(price), RED)
			return
		end
		data.cash -= price
		data.floor2 = k
		Data.changed(player)
		banner(player, "STAND " .. slot .. " UNLOCKED!", GREEN)
		PlotService.refresh(player)
		unlockMoment(player, plot, slot)
		return
	end
	if not plot or not data or slot ~= data.stands + 1 then
		if data and slot > data.stands + 1 then
			banner(player, "UNLOCK STAND " .. (data.stands + 1) .. " FIRST", RED)
		end
		return
	end
	local price = Config.Plot.standPrices[slot]
	if not price then
		return
	end
	if data.cash < price then
		banner(player, "NEEDS " .. Format.cash(price), RED)
		return
	end
	data.cash -= price
	data.stands = slot
	if slot >= CASH_SLOTS then
		Social.award(player, "FullBase")
	end
	Data.changed(player)
	banner(player, "STAND " .. slot .. " UNLOCKED!", GREEN)
	PlotService.refresh(player)
	unlockMoment(player, plot, slot)
	if slot >= CASH_SLOTS then
		task.delay(1.5, PlotService.party, player) -- a full base: everyone dances
	end
end

-- A dance party: every fighter on the player's stands does the same dance, in time, for a few seconds
-- (client/FighterAnimator.lua plays the Clip attributes). From the base's boombox, and by itself when the
-- last ground-floor stand opens.
local PARTY_SECONDS, PARTY_COOLDOWN = 10, 20
function PlotService.party(player)
	local plot = owned[player]
	if not plot or os.clock() < (plot.partyUntil or 0) then
		return
	end
	plot.partyUntil = os.clock() + PARTY_COOLDOWN
	local dance = Dances.List[math.random(1, #Dances.List)]
	local start = workspace:GetServerTimeNow()
	local dancing = {}
	for _, stand in plot.stands do
		local m = stand.fighter
		if m and m.Parent then
			m:SetAttribute("Clip", dance)
			m:SetAttribute("ClipStart", start)
			table.insert(dancing, m)
		end
	end
	if #dancing == 0 then
		banner(player, "PUT FIGHTERS ON YOUR STANDS TO PARTY!", RED)
		plot.partyUntil = 0
		return
	end
	banner(player, "DANCE PARTY!", GREEN)
	FX:FireAllClients("Party", { position = plot.lockPad.Position, userId = player.UserId })
	task.delay(PARTY_SECONDS, function()
		for _, m in dancing do
			if m.Parent and m:GetAttribute("ClipStart") == start then
				m:SetAttribute("Clip", nil)
				m:SetAttribute("ClipStart", nil)
			end
		end
	end)
end

-- POSE (the Bag's follower card): the player strikes their follower's signature pose for a few seconds and
-- the follower does it with them (client/Champion.lua, player attribute PoseAt); their camera swings round.
local POSE_SECONDS, POSE_COOLDOWN = 3.2, 6
local posedAt = setmetatable({}, { __mode = "k" })
function PlotService.pose(player)
	local character = player.Character
	if not character or player:GetAttribute("InClash") or player:GetAttribute("Carrying") then
		return
	end
	if os.clock() - (posedAt[player] or -99) < POSE_COOLDOWN then
		return
	end
	posedAt[player] = os.clock()
	local key = player:GetAttribute("Champion")
	local clip = key and Fighters.signature(key) or "SigFlex"
	local start = workspace:GetServerTimeNow()
	CollectionService:AddTag(character, "Fighter")
	character:SetAttribute("Clip", clip)
	character:SetAttribute("ClipStart", start)
	player:SetAttribute("PoseAt", start)
	task.delay(POSE_SECONDS, function()
		if character.Parent and character:GetAttribute("ClipStart") == start then
			CollectionService:RemoveTag(character, "Fighter")
			character:SetAttribute("Clip", nil)
			character:SetAttribute("ClipStart", nil)
		end
	end)
end

-- In front of the plot's torii, facing in.
local function home(player)
	local plot = owned[player]
	local character = player.Character
	if not plot or not character then
		return
	end
	-- (Carrying without CarryKind "own" = a steal, the tutorial's practice steal too.)
	if thefts[player] or (player:GetAttribute("Carrying") and player:GetAttribute("CarryKind") ~= "own") then
		-- No teleporting home with a stolen fighter: you have to run it (the owner can catch you).
		banner(player, "RUN IT HOME! NO TELEPORTING WHILE STEALING", RED)
		return
	end
	-- Past the LOCK pad, far enough in that the camera behind you sits inside the torii instead of behind
	-- one of its pillars, taking in the whole base.
	local front = plot.frame * CFrame.new(0, 3, -plot.depth / 2 + 16)
	Streaming.prepare(player, front.Position)
	character:PivotTo(CFrame.lookAt(front.Position, (plot.frame * CFrame.new(0, 3, 0)).Position))
end

-- ------------------------------------------------------------------ shop hooks (MonetizationService)

-- Cash per second the player's stands earn right now (with their multiplier).
function PlotService.incomeRate(player)
	local plot = owned[player]
	local total = 0
	for _, stand in plot and plot.stands or {} do
		if stand.entry then
			total += income(stand.entry)
		end
	end
	return total * (player:GetAttribute("CashMult") or 1) * LiveOps.mult("cash")
end

function PlotService.addCash(player, amount)
	local data = Data.get(player)
	if not data then
		return false
	end
	data.cash += math.floor(amount)
	Data.changed(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value = math.floor(math.min(data.cash, 9e18))
	end
	return true
end

-- Locks the player's base for at least `seconds` from now (Base Shield).
function PlotService.shield(player, seconds)
	local plot = owned[player]
	if not plot then
		return false
	end
	plot.lockedUntil = math.max(plot.lockedUntil or 0, os.clock() + seconds)
	return true
end

-- Unlocks the next stand without charging cash (Next Stand). False if all are open.
function PlotService.unlockFree(player)
	local data = Data.get(player)
	if not data or data.stands >= CASH_SLOTS then
		return false
	end
	data.stands += 1
	if data.stands >= CASH_SLOTS then
		Social.award(player, "FullBase")
	end
	Data.changed(player)
	banner(player, "STAND " .. data.stands .. " UNLOCKED!", GREEN)
	PlotService.refresh(player)
	return true
end

-- ------------------------------------------------------------------ tutorial hooks (TutorialService)

-- Where things are on the player's base (nil until they have one).
function PlotService.places(player)
	local plot = owned[player]
	if not plot then
		return nil
	end
	-- The first empty unlocked stand (where a carried fighter can go).
	local data = Data.get(player)
	local free
	if data then
		local at = placements(data)
		for slot = 1, SLOTS do
			local stand = plot.stands[slot]
			if stand and isUnlocked(player, data, slot) and not at[slot] then
				free = stand.top.Position
				break
			end
		end
	end
	return {
		free = free,
		gate = (plot.frame * CFrame.new(0, 0, -plot.depth / 2 + 4)).Position,
		pad = plot.stands[1] and plot.stands[1].pad.Position,
		lock = plot.lockPad.Position,
	}
end

-- Series badges (completed Index series, RewardsService) floating over the player's base for everyone.
local BADGE_COLORS = {
	DBZ = Color3.fromRGB(255, 150, 30),
	NARUTO = Color3.fromRGB(255, 120, 40),
	Bleach = Color3.fromRGB(70, 70, 90),
	JOJO = Color3.fromRGB(200, 90, 220),
	["One Piece"] = Color3.fromRGB(230, 60, 60),
	AOT = Color3.fromRGB(120, 100, 70),
	["My Hero Academia"] = Color3.fromRGB(60, 160, 90),
	FATE = Color3.fromRGB(60, 90, 200),
	HXH = Color3.fromRGB(80, 200, 120),
	YYH = Color3.fromRGB(90, 140, 230),
	["Fairy Tail"] = Color3.fromRGB(230, 70, 120),
	JJK = Color3.fromRGB(110, 60, 180),
	OTHER = Color3.fromRGB(150, 150, 160),
}
-- A series badge's text: the initials of the name players read (Fighters.SeriesNames), e.g. "DF".
local function badgeShort(series)
	local name = Fighters.SeriesNames[series] or series
	local out = ""
	for word in string.gmatch(name, "%a+") do
		out ..= string.upper(string.sub(word, 1, 1))
	end
	return out
end

function PlotService.setBadges(player, series)
	local plot = owned[player]
	if not plot then
		return
	end
	if plot.badges then
		plot.badges:Destroy()
		plot.badges = nil
	end
	if #series == 0 then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "Badges"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = plot.frame * CFrame.new(0, 30, 8)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(math.min(#series, 7) * 4.2, 6.4)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = anchor
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.3)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 80)
	title.TextStrokeTransparency = 0
	title.Text = "SERIES BADGES"
	title.Parent = gui
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromScale(0, 0.34)
	row.Size = UDim2.fromScale(1, 0.66)
	row.Parent = gui
	local list = Instance.new("UIGridLayout")
	list.CellSize = UDim2.fromScale(1 / math.min(#series, 7) - 0.02, 0.95)
	list.CellPadding = UDim2.fromScale(0.02, 0.05)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = row
	for _, name in series do
		local medal = Instance.new("Frame")
		medal.BackgroundColor3 = BADGE_COLORS[name] or BADGE_COLORS.OTHER
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = medal
		local ring = Instance.new("UIStroke")
		ring.Thickness = 4
		ring.Color = Color3.fromRGB(255, 214, 80)
		ring.Parent = medal
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.86, 0.86)
		label.Position = UDim2.fromScale(0.07, 0.07)
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.Text = badgeShort(name)
		label.Parent = medal
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = medal
		medal.Parent = row
	end
	anchor.Parent = workspace
	plot.badges = anchor
end

function PlotService.isLocked(player)
	local plot = owned[player]
	return plot ~= nil and plot.lockedUntil ~= nil and os.clock() < plot.lockedUntil
end

-- Adds cash waiting on a stand's pad (the tutorial's starter cash).
function PlotService.addStash(player, slot, amount)
	local data = Data.get(player)
	local plot = owned[player]
	if data and plot and plot.stands[slot] then
		data.stash[slot] = (data.stash[slot] or 0) + amount
		setPad(plot.stands[slot], data.stash[slot])
		Data.touch(player)
	end
end

-- ------------------------------------------------------------------ stealing

local inPlot -- defined below; PlotService.isHome uses it
function PlotService.isHome(player, position)
	local plot = owned[player]
	return plot ~= nil and inPlot(plot, position)
end

function inPlot(plot, position)
	local local_ = plot.frame:PointToObjectSpace(position)
	local size = Config.Island.plotSize
	return math.abs(local_.X) < size.X / 2 + 1 and math.abs(local_.Z) < size.Y / 2 + 1 and math.abs(local_.Y) < 48 -- Floor 2 is 36 up (server/Hub.lua FLOOR_H)
end

local function locked(plot)
	return plot.lockedUntil and os.clock() < plot.lockedUntil
end

-- Ends a theft: the fighter either changes hands (`kept`) or goes back to its stand.
function endTheft(thief, kept, reason)
	local theft = thefts[thief]
	if not theft then
		return
	end
	thefts[thief] = nil
	carried[theft.entry] = nil
	if theft.model then
		theft.model:Destroy()
	end
	thief:SetAttribute("Carrying", nil)
	if theft.victim.Parent then
		theft.victim:SetAttribute("StealAlert", nil)
	end
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and theft.speed then
		humanoid.WalkSpeed = theft.speed
	end
	local name = string.upper(Fighters.ByKey[theft.entry.k].display)
	local victim = theft.victim
	if kept then
		if victim.Parent and Training.removeFighter(victim, theft.entry) then
			Training.addFighter(thief, theft.entry.k, theft.entry.m, "carry") -- they place it on a stand
			if PlotService.onSteal then
				task.spawn(PlotService.onSteal, thief)
			end
			Social.award(thief, "FirstSteal")
			banner(thief, "YOU STOLE " .. name .. "!", GREEN)
			banner(victim, thief.DisplayName .. " STOLE YOUR " .. name .. "!", RED)
			FX:FireAllClients("Stolen", { thief = thief.UserId, victim = victim.UserId, key = theft.entry.k })
		end
	else
		if thief.Parent then
			banner(thief, reason or "THE STEAL FAILED", RED)
		end
		if victim.Parent then
			banner(victim, name .. " IS BACK ON YOUR STAND!", GREEN)
			PlotService.refresh(victim)
		end
	end
end

local function startTheft(thief, plot, stand)
	local victim = plot.owner
	local entry = stand.entry
	local character = thief.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not victim or victim == thief or not entry or carried[entry] or not head or not humanoid then
		return
	end
	if thefts[thief] or holds[thief] then
		banner(thief, "YOU'RE ALREADY CARRYING ONE!", RED)
		return
	end
	if not owned[thief] then
		banner(thief, "YOU NEED A BASE TO STEAL", RED)
		return
	end
	if locked(plot) then
		banner(thief, "THIS BASE IS LOCKED!", RED)
		return
	end
	-- Lift a small copy of the fighter over the thief's head (they hold it up while they run).
	local model = Carry.lift(thief, entry.k, entry.m)
	if model then
		model.Name = "Stolen_" .. thief.Name
	end
	local theft = { entry = entry, victim = victim, model = model, started = os.clock(), speed = humanoid.WalkSpeed }
	thefts[thief] = theft
	carried[entry] = theft
	humanoid.WalkSpeed = STEAL.slowSpeed + (thief:GetAttribute("CarryBoost") or 0)
	thief:SetAttribute("Carrying", entry.k)
	PlotService.refresh(victim)
	local name = string.upper(Fighters.ByKey[entry.k].display)
	-- The thief's own call ("RUN HOME WITH ...!") is on their screen (client/Plots.lua); no banner too.
	banner(victim, thief.DisplayName .. " IS STEALING YOUR " .. name .. "! CATCH THEM!", RED)
	-- The first time: how to stop it happening again (the tutorial no longer teaches the lock).
	local victimData = Data.get(victim)
	if victimData and not victimData.seenLockTip then
		victimData.seenLockTip = true
		Data.changed(victim)
		banner(victim, "STEP ON YOUR LOCK PAD TO KEEP THIEVES OUT!", GREEN)
	end
	-- And a warning that stays up until the steal ends (client/Plots.lua).
	victim:SetAttribute(
		"StealAlert",
		string.upper(thief.DisplayName) .. " IS STEALING YOUR " .. name .. "! CATCH THEM!"
	)
end

-- ------------------------------------------------------------------ setup

local function gather(world)
	for _, model in world.plots:GetChildren() do
		local index = model:GetAttribute("Index")
		if not index then
			continue
		end
		local plot = { index = index, model = model, stands = {} }
		-- The torii plaque's text ("EMPTY PLOT") becomes the owner's name.
		for _, d in model:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == "EMPTY PLOT" then
				plot.label = d
			end
		end
		plot.frame = model:GetAttribute("Frame") or model:GetPivot()
		plot.depth = Config.Island.plotSize.Y
		-- Floor 2's pieces (shown with the pass) and its offer where the ladder goes.
		plot.floor2Parts = { model:FindFirstChild("Floor2") }
		for _, standModel in model.Stands:GetChildren() do
			if standModel:GetAttribute("Pass") == "Floor2" then
				table.insert(plot.floor2Parts, standModel)
			end
		end
		plot.offer = model:FindFirstChild("Floor2Offer", true)
		local offerPrompt = Instance.new("ProximityPrompt")
		offerPrompt.Name = "Floor2Prompt"
		offerPrompt.ActionText = "Open Floor 2"
		offerPrompt.ObjectText = "8 more stands"
		offerPrompt:SetAttribute("Pass", "Floor2") -- client/GearShop.lua opens the purchase
		offerPrompt:SetAttribute("Plot", index)
		offerPrompt.HoldDuration = 0.3
		offerPrompt.MaxActivationDistance = 10
		offerPrompt.RequiresLineOfSight = false
		offerPrompt.Enabled = false
		offerPrompt.Parent = plot.offer
		plot.offerPrompt = offerPrompt
		local offerSign = Instance.new("BillboardGui")
		offerSign.Name = "Floor2Sign"
		offerSign.Size = UDim2.fromScale(10, 3)
		offerSign.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
		offerSign.MaxDistance = 120
		offerSign.LightInfluence = 0
		offerSign.Enabled = false
		offerSign.Adornee = plot.offer
		local offerText = Instance.new("TextLabel")
		offerText.BackgroundTransparency = 1
		offerText.Size = UDim2.fromScale(1, 1)
		offerText.Font = Enum.Font.LuckiestGuy
		offerText.TextScaled = true
		offerText.Text = "FLOOR 2\n8 MORE STANDS"
		offerText.TextColor3 = GOLD
		local offerStroke = Instance.new("UIStroke")
		offerStroke.Thickness = 3
		offerStroke.Color = Color3.fromRGB(30, 16, 40)
		offerStroke.Parent = offerText
		offerText.Parent = offerSign
		offerSign.Parent = model
		plot.offerSign = offerSign
		for _, standModel in model.Stands:GetChildren() do
			local slot = standModel:GetAttribute("Slot")
			local pedestal = standModel:FindFirstChild("Pedestal")
			local pad = standModel:FindFirstChild("CollectPad")
			local padPart = pad and pad:FindFirstChild("Pad")
			if not (slot and pedestal and padPart) then
				continue
			end
			local top = pedestal:GetPivot() * CFrame.new(0, 4, 0)
			-- Lock: a red "LOCKED" sign over the pedestal and a prompt to buy it (owner only).
			local lock = Instance.new("BillboardGui")
			lock.Name = "Lock"
			lock.Size = UDim2.fromScale(5, 2)
			lock.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			lock.MaxDistance = 70
			lock.LightInfluence = 0
			lock.Enabled = false
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Size = UDim2.fromScale(1, 1)
			text.Font = Enum.Font.LuckiestGuy
			text.TextScaled = true
			text.TextColor3 = RED
			local price = Config.Plot.standPrices[slot]
			local pass = standModel:GetAttribute("Pass") -- the gold stands: the +2 Stands pass
			-- (The game font has no emoji, so no padlock glyph.)
			text.Text = pass == "Floor2" and "FLOOR 2"
				or pass and "+2 STANDS PASS"
				or ("LOCKED · " .. (price and Format.cash(price) or ""))
			if pass then
				text.TextColor3 = Color3.fromRGB(255, 214, 80)
			end
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(30, 16, 40)
			stroke.Parent = text
			text.Parent = lock
			local anchor = pedestal:FindFirstChildWhichIsA("BasePart", true)
			lock.Adornee = anchor
			lock.Parent = standModel
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "StandPrompt"
			prompt.ActionText = pass and "Get +2 Stands" or ("Unlock  ·  " .. (price and Format.cash(price) or ""))
			if pass then
				prompt:SetAttribute("Pass", pass) -- the client opens the purchase (client/GearShop.lua)
			end
			prompt.ObjectText = "Stand " .. slot
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.Enabled = false
			prompt:SetAttribute("Slot", slot)
			prompt.Parent = anchor
			prompt.Triggered:Connect(function(player)
				-- (A stand whose prompt opens a pass purchase is the client's: client/GearShop.lua.)
				if owned[player] == plot and not prompt:GetAttribute("Pass") then
					unlock(player, slot)
				end
			end)
			-- Steal: hold E at someone else's stand (the client hides it on your own plot).
			local steal = Instance.new("ProximityPrompt")
			steal.Name = "StealPrompt"
			steal.ActionText = "Steal"
			steal.HoldDuration = STEAL.hold
			steal.MaxActivationDistance = 8
			steal.RequiresLineOfSight = false
			steal.KeyboardKeyCode = Enum.KeyCode.E
			steal.Enabled = false
			steal.UIOffset = Vector2.new(0, 60)
			steal:SetAttribute("Slot", slot)
			steal.Parent = anchor
			local standRef
			steal.Triggered:Connect(function(player)
				if plot.owner and plot.owner ~= player and standRef.entry then
					startTheft(player, plot, standRef)
				end
			end)
			-- The owner's own: E places / swaps / picks up, R sends to the bag (the client shows them on your
			-- own plot only).
			local move = Instance.new("ProximityPrompt")
			move.Name = "MovePrompt"
			move.ActionText = "Pick Up"
			move.HoldDuration = 0.25
			move.MaxActivationDistance = 9
			move.RequiresLineOfSight = false
			move.KeyboardKeyCode = Enum.KeyCode.E
			move.GamepadKeyCode = Enum.KeyCode.ButtonX
			move.Enabled = false
			move:SetAttribute("Slot", slot)
			move.Parent = anchor
			move.Triggered:Connect(function(player)
				if owned[player] == plot then
					moveAt(player, slot)
				end
			end)
			local bag = Instance.new("ProximityPrompt")
			bag.Name = "BagPrompt"
			bag.ActionText = "To Bag"
			bag.HoldDuration = 0.4
			bag.MaxActivationDistance = 9
			bag.RequiresLineOfSight = false
			bag.KeyboardKeyCode = Enum.KeyCode.R
			bag.GamepadKeyCode = Enum.KeyCode.ButtonY
			bag.Enabled = false
			bag.UIOffset = Vector2.new(0, 70)
			bag:SetAttribute("Slot", slot)
			bag.Parent = anchor
			bag.Triggered:Connect(function(player)
				if owned[player] == plot then
					bagAt(player, slot)
				end
			end)
			move:SetAttribute("Plot", index)
			bag:SetAttribute("Plot", index)
			standRef = {
				move = move,
				bag = bag,
				model = standModel,
				top = top,
				pad = padPart,
				cashLabel = padPart.Cash.Text,
				lock = lock,
				lockLabel = text,
				prompt = prompt,
				steal = steal,
			}
			plot.stands[slot] = standRef
		end
		-- The LOCK pad on the path just inside the torii, with a countdown sign over the gate.
		local lockAt = plot.frame * CFrame.new(0, 0.35, -plot.depth / 2 + 8)
		local lockPad = Instance.new("Part")
		lockPad.Name = "LockPad"
		lockPad.Anchored = true
		lockPad.CanCollide = false
		lockPad.CanTouch = false
		lockPad.Size = Vector3.new(4, 0.3, 4)
		lockPad.CFrame = lockAt
		lockPad.Material = Enum.Material.Neon
		lockPad.Color = RED
		lockPad.Parent = model
		local padGui = Instance.new("SurfaceGui")
		padGui.Face = Enum.NormalId.Top
		padGui.Parent = lockPad
		local padText = Instance.new("TextLabel")
		padText.Size = UDim2.fromScale(1, 1)
		padText.BackgroundTransparency = 1
		padText.Font = Enum.Font.LuckiestGuy
		padText.TextScaled = true
		padText.Text = "LOCK"
		padText.TextColor3 = Color3.new(1, 1, 1)
		padText.Parent = padGui
		local sign = Instance.new("BillboardGui")
		sign.Name = "LockSign"
		sign.Size = UDim2.fromScale(10, 2.4)
		sign.StudsOffsetWorldSpace = Vector3.new(0, 15, -4)
		sign.MaxDistance = 90
		sign.LightInfluence = 0
		sign.Enabled = false
		sign.Adornee = lockPad
		local signText = Instance.new("TextLabel")
		signText.Size = UDim2.fromScale(1, 1)
		signText.BackgroundTransparency = 1
		signText.Font = Enum.Font.LuckiestGuy
		signText.TextScaled = true
		signText.TextColor3 = RED
		local signStroke = Instance.new("UIStroke")
		signStroke.Thickness = 3
		signStroke.Color = Color3.fromRGB(30, 16, 40)
		signStroke.Parent = signText
		signText.Parent = sign
		sign.Parent = model
		plot.lockPad, plot.lockSign, plot.lockText = lockPad, sign, signText
		-- A boombox beside the path: its owner starts a dance party (all their stand fighters, in sync).
		-- (Off to the side of the entrance, so arriving at your base never stacks its prompt on yours.)
		local boxAt = plot.frame * CFrame.new(18, 0, -plot.depth / 2 + 5)
		local boombox = Instance.new("Part")
		boombox.Name = "Boombox"
		boombox.Anchored, boombox.CanCollide = true, true
		boombox.Size = Vector3.new(4, 2.4, 1.6)
		boombox.CFrame = boxAt * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.pi, 0)
		boombox.Color = Color3.fromRGB(35, 30, 45)
		boombox.Parent = model
		for _, x in { -1, 1 } do
			local speaker = Instance.new("Part")
			speaker.Shape = Enum.PartType.Cylinder
			speaker.Anchored, speaker.CanCollide = true, false
			speaker.Size = Vector3.new(0.3, 1.6, 1.6)
			speaker.CFrame = boombox.CFrame * CFrame.new(x * 1.05, 0, -0.85) * CFrame.Angles(0, math.pi / 2, 0)
			speaker.Material = Enum.Material.Neon
			speaker.Color = Color3.fromRGB(255, 80, 200)
			speaker.Parent = model
		end
		local party = Instance.new("ProximityPrompt")
		party.Name = "PartyPrompt"
		party.ActionText = "Dance Party"
		party.ObjectText = "Your fighters"
		party.KeyboardKeyCode = Enum.KeyCode.E
		party.HoldDuration = 0
		party.MaxActivationDistance = 6
		party.RequiresLineOfSight = false
		party:SetAttribute("Plot", index)
		party.Parent = boombox
		party.Triggered:Connect(function(player)
			if owned[player] == plot then
				PlotService.party(player)
			end
		end)
		showFloor2(plot, false)
		plot.offer.Transparency = 1
		plots[index] = plot
	end
end

-- Fell in the sea (server/Services/ZoneService.lua): a steal in progress fails, the fighter goes home.
function PlotService.splash(player)
	if thefts[player] then
		endTheft(player, false, "SPLASH! THE STEAL FAILED")
	end
end

function PlotService.start(world, DataService, TrainingService)
	Data = DataService
	Training = TrainingService
	gather(world)
	DataService.onLoaded(function(player, data)
		assign(player)
		-- Offline earnings (Config.Social): the base kept earning a share of its income while its owner was
		-- away, up to a cap. Offered as a WELCOME BACK card (client/Social.lua, Plot remote "Offline").
		local S = Config.Social
		local away = data.lastSeen and (os.time() - data.lastSeen) or 0
		data.lastSeen = os.time()
		if away >= S.offlineMin then
			task.delay(2, function() -- after the plot has dressed its stands (income counts what stands)
				local seconds = math.min(away, S.offlineCap)
				local amount = math.floor(PlotService.incomeRate(player) * seconds * S.offlineShare)
				if amount > 0 and player.Parent then
					data.offlinePending = (data.offlinePending or 0) + amount
					player:SetAttribute("OfflineCash", data.offlinePending)
					player:SetAttribute("OfflineSeconds", seconds)
					Data.changed(player)
				end
			end)
		elseif (data.offlinePending or 0) > 0 then
			player:SetAttribute("OfflineCash", data.offlinePending) -- left before collecting last time
		end
	end)
	Players.PlayerRemoving:Connect(release)
	TrainingService.onFighters = PlotService.refresh

	-- Thefts and base locks: a thief home keeps the fighter; the owner touching them, death or the
	-- timeout sends it back. Owners on their LOCK pad lock the base; the sign over the gate counts down.
	task.spawn(function()
		while true do
			task.wait(0.15)
			local now = os.clock()
			for thief, theft in thefts do
				local character = thief.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local base = owned[thief]
				if not root or not humanoid or humanoid.Health <= 0 then
					endTheft(thief, false, "YOU DROPPED IT!")
				elseif now - theft.started > STEAL.timeout then
					endTheft(thief, false, "TOO SLOW! IT WENT BACK")
				elseif base and inPlot(base, root.Position) then
					endTheft(thief, true)
				else
					local victimChar = theft.victim.Character
					local victimRoot = victimChar and victimChar:FindFirstChild("HumanoidRootPart")
					if victimRoot and (victimRoot.Position - root.Position).Magnitude < STEAL.catchRadius then
						endTheft(thief, false, "CAUGHT! " .. string.upper(theft.victim.DisplayName) .. " GOT IT BACK")
						banner(theft.victim, "YOU CAUGHT " .. string.upper(thief.DisplayName) .. "!", GREEN)
					end
				end
			end
			-- Your own fighter over your head goes to the bag if you die or sit down for a clash.
			for player in holds do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 or player:GetAttribute("InClash") then
					letGo(player, "IT WENT TO YOUR BAG")
					PlotService.refresh(player)
				end
			end
			for player, plot in owned do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and not locked(plot) then
					local offset = plot.lockPad.CFrame:PointToObjectSpace(root.Position)
					if math.abs(offset.X) < 2.5 and math.abs(offset.Z) < 2.5 and math.abs(offset.Y) < 6 then
						plot.lockedUntil = now + STEAL.lockTime + (player:GetAttribute("LockBonus") or 0)
						banner(player, "BASE LOCKED!", GREEN)
					end
				end
				local left = plot.lockedUntil and plot.lockedUntil - now or 0
				plot.lockSign.Enabled = left > 0
				if left > 0 then
					local secs = math.ceil(left)
					plot.lockText.Text = "LOCKED  "
						.. (secs >= 60 and string.format("%d:%02d", secs // 60, secs % 60) or (secs .. "s"))
				end
				plot.model:SetAttribute("Locked", left > 0)
			end
		end
	end)
	remote.OnServerEvent:Connect(function(player, kind, value)
		local data = Data.get(player)
		if kind == "Home" then
			home(player)
		elseif kind == "Offline" and data and (data.offlinePending or 0) > 0 then
			local amount = data.offlinePending
			data.offlinePending = 0
			player:SetAttribute("OfflineCash", nil)
			PlotService.addCash(player, amount)
			FX:FireClient(player, "Collect", { amount = amount, position = rootPosition(player) })
		elseif kind == "Pose" then
			PlotService.pose(player)
		elseif kind == "Stow" and holds[player] then
			-- The TO BAG button while holding one.
			letGo(player, fullName(holds[player].entry) .. " WENT TO YOUR BAG")
			PlotService.refresh(player)
		elseif kind == "Take" and data and type(value) == "number" and data.fighters[value] then
			-- The Bag's TAKE OUT: into your hands, to put on a stand.
			local entry = data.fighters[value]
			if carried[entry] or (holds[player] and holds[player].entry == entry) then
				return
			end
			entry.s = nil
			Data.changed(player)
			PlotService.hold(player, entry)
		elseif kind == "Follow" and type(value) == "number" then
			Training.setChampion(player, value)
			player:SetAttribute("BagVersion", (player:GetAttribute("BagVersion") or 0) + 1)
		end
	end)
	TrainingService.onCarry = PlotService.hold
	TrainingService.onPlace = PlotService.autoPlace

	-- Income: once a second every standing fighter adds its income to its stand's pad.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, plot in owned do
				local data = Data.get(player)
				if not data then
					continue
				end
				for slot, stand in plot.stands do
					if stand.entry then
						-- CashMult: 2x Cash and VIP (MonetizationService).
						local mult = (player:GetAttribute("CashMult") or 1) * LiveOps.mult("cash")
						data.stash[slot] = (data.stash[slot] or 0) + income(stand.entry) * mult
						setPad(stand, data.stash[slot])
					end
				end
				Data.touch(player)
			end
		end
	end)

	-- Collecting: the owner standing on a pad takes its stash.
	task.spawn(function()
		local radius = Config.Plot.collectRadius
		while true do
			task.wait(0.15)
			for player, plot in owned do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local data = Data.get(player)
				if not root or not data then
					continue
				end
				for slot, stand in plot.stands do
					local offset = root.Position - stand.pad.Position
					local amount = math.floor(data.stash[slot] or 0)
					if
						amount >= 1
						and Vector3.new(offset.X, 0, offset.Z).Magnitude < radius
						and math.abs(offset.Y) < 6
					then
						data.stash[slot] -= amount
						data.cash += amount
						Data.touch(player)
						player:SetAttribute("Cash", data.cash)
						local leaderstats = player:FindFirstChild("leaderstats")
						local cash = leaderstats and leaderstats:FindFirstChild("Cash")
						if cash then
							cash.Value = math.floor(math.min(data.cash, 9e18))
						end
						setPad(stand, data.stash[slot])
						FX:FireClient(player, "Collect", { amount = amount, position = stand.pad.Position })
						if PlotService.onCollect then
							task.spawn(PlotService.onCollect, player, amount)
						end
					end
				end
			end
		end
	end)

	-- Cash on the leaderboard.
	DataService.onLoaded(function(player, data)
		-- Studio only: set the player attribute DebugCash from the server command bar to add that much cash.
		if game:GetService("RunService"):IsStudio() then
			player:GetAttributeChangedSignal("DebugCash"):Connect(function()
				local amount = tonumber(player:GetAttribute("DebugCash"))
				if amount and amount > 0 then
					player:SetAttribute("DebugCash", nil)
					PlotService.addCash(player, amount)
				end
			end)
		end
		local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 5)
		if leaderstats and not leaderstats:FindFirstChild("Cash") then
			local cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Value = math.floor(math.min(data.cash, 9e18))
			cash.Parent = leaderstats
		end
	end)
end

return PlotService
