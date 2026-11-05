-- Fighters drop from the Summoning Portal onto empty altars on a server-wide timer.
-- The server owns the schedule and the fighter; clients draw the beam (FX "Drop") and the countdown
-- (ReplicatedStorage attribute "NextDrop", a server timestamp).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local Odds = require(Shared.Odds)
local Products = require(Shared.Products)
local LiveOps = require(Shared.LiveOps)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local DropService = {}
DropService.Altars = {}
-- Guardian spawns: [venue index] = { venue (ClashService challenge spec), zone, rung, order (zone order),
-- top (where the prize hovers: over the guardian's head), facing }. ZoneService registers them.
DropService.Guardians = {}

local rng = Random.new()
local FX = Net.get("FX")

-- One clean card above the fighter: mutation ribbon, name, rarity, $/s, odds. Fades out with distance
-- so a plaza full of fighters never becomes a wall of text.
local function nameplate(model, fighter, mutation, tier)
	local anchor = model:FindFirstChild("Head") or model.PrimaryPart
	if not anchor then
		return
	end
	local rarity = Config.Rarities[fighter.rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	local mutated = mutation ~= "Normal" and Config.Mutations[mutation]
	gui.Size = UDim2.fromOffset(260, (mutated and 108 or 86) + (tier and 20 or 0))
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6 * model:GetScale(), 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = model
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local function line(text, color, height, order, stroke)
		local t = Instance.new("TextLabel")
		t.LayoutOrder = order
		t.Size = UDim2.new(1, 0, 0, height)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.LuckiestGuy
		t.Text = text
		t.TextScaled = true
		t.TextColor3 = color
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = stroke or Color3.fromRGB(30, 20, 40)
		t.Parent = gui
		return t
	end
	-- Lines a kid reads at a glance: the mutation's own tag (in its colour), who, how rare (and the odds),
	-- what it earns.
	if mutated then
		line(string.upper(mutation) .. "  x" .. mutated.mult, mutated.color, 22, 0)
	end
	line(string.upper(fighter.display), Color3.new(1, 1, 1), 32, 1)
	local rare = string.upper(fighter.rarity)
	if tier then
		rare ..= "  ·  " .. string.upper(Odds.label(Odds.base(fighter.key, mutation)))
	end
	line(rare, rarity.color, 24, 2)
	line(Format.cash(Odds.income(fighter.key, mutation)) .. "/S", Color3.fromRGB(110, 255, 110), 26, 3)
	-- The odds above are the fighter's own; this is how much better they are at this altar.
	local luck = tier and Odds.altarLuck(tier, fighter.key, mutation)
	if luck then
		line(string.upper(tier) .. " ALTAR  ·  x" .. Format.short(luck) .. " LUCK", Config.Tiers[tier].trim, 20, 4)
	end
end

function DropService.clear(index)
	local altar = DropService.Altars[index]
	if altar.model then
		altar.model:Destroy()
	end
	altar.model, altar.key, altar.mutation = nil, nil, nil
	altar.reservedFor, altar.reservedUntil = nil, nil
	altar.light.Brightness = 0
end

-- `forced` = { key, mutation } drops that fighter instead of rolling (the tutorial's personal Epic).
function DropService.drop(index, forced)
	local altar = DropService.Altars[index]
	-- Server Luck (a Robux product) doubles the rarer rarities for everyone while it lasts; an x2 Drop
	-- Luck owner standing near the altar doubles them again.
	local luckUntil = ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0
	local luck = workspace:GetServerTimeNow() < luckUntil and 2 or 1
	local mutationLuck = 1
	if workspace:GetServerTimeNow() < (ReplicatedStorage:GetAttribute("StormUntil") or 0) then
		luck *= Config.Events.stormLuck -- the hourly Luck Storm (EventService)
	end
	-- x2 Drop Luck / x2 Mutation Luck owners standing near the altar (one owner of each is enough).
	local dropLuckNear, mutationLuckNear, newbieNear = false, false, 0
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character.PrimaryPart
		if root and (root.Position - altar.stand).Magnitude < Products.DropLuckRange then
			dropLuckNear = dropLuckNear or player:GetAttribute("DropLuck") == true
			mutationLuckNear = mutationLuckNear or player:GetAttribute("MutationLuck") == true
			newbieNear = math.max(newbieNear, ((player:GetAttribute("NewbieUntil") or 0) - os.time()) / (Config.NewbieLuck.minutes * 60))
		end
	end
	if dropLuckNear then
		luck *= Products.DropLuck
	end
	if newbieNear > 0 then
		-- New Player Luck fades from x`mult` to x1; the shown odds stay the real base odds.
		luck *= 1 + (Config.NewbieLuck.mult - 1) * math.min(newbieNear, 1)
	end
	if mutationLuckNear then
		mutationLuck = Products.MutationLuck
	end
	-- The running LiveOps event (Double Drops, Mutation Week...).
	luck *= LiveOps.mult("dropLuck")
	mutationLuck *= LiveOps.mult("mutationLuck")
	-- Each zone's altars drop that zone's universe; the hub's the rookie universes (shared/Fighters.lua pools).
	local fighter = forced and Fighters.ByKey[forced.key]
		or Odds.rollFighter(altar.tier, rng, luck, altar.zone or "Hub")
	-- A limited event fighter sometimes takes a hub drop of the same rarity (LiveOpsService).
	if not forced and not altar.zone and DropService.eventFighter then
		fighter = DropService.eventFighter(fighter.rarity) or fighter
	end
	local mutation = forced and (forced.mutation or "Normal") or Odds.rollMutation(rng, mutationLuck, altar.zone)
	altar.key, altar.mutation = fighter.key, mutation -- reserved before the beam lands
	FX:FireAllClients("Drop", {
		altar = index,
		position = altar.stand,
		from = altar.sky, -- the portal over this altar (hub or zone)
		rarity = fighter.rarity,
		mutation = mutation,
		display = fighter.display,
	})
	task.delay(Config.Drops.landDelay, function()
		if altar.key ~= fighter.key then
			return
		end
		local scale = FighterModels.scaleFor(fighter.key, "Table") * (Config.Mutations[mutation].scale or 1)
		local model = FighterModels.spawn(fighter.key, altar.stand, altar.facing, {
			scale = scale,
			parent = altar.model_parent,
			mutation = mutation,
			aura = true,
		})
		if not model then
			DropService.clear(index)
			return
		end
		model.Name = "Fighter"
		-- Lands in its signature pose, then settles into its idle (client/FighterAnimator.lua).
		model:SetAttribute("Clip", Fighters.signature(fighter.key))
		model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
		model:SetAttribute("Rarity", fighter.rarity)
		model:SetAttribute("Mutation", mutation)
		nameplate(model, fighter, mutation, altar.tier)
		altar.model = model
		altar.landedAt = os.clock()
		altar.light.Color = Config.Rarities[fighter.rarity].color
		altar.light.Brightness = fighter.rarity == "Common" and 0.3 or 1.1
	end)
end

local function emptyAltars()
	local list = {}
	for index, altar in DropService.Altars do
		if not altar.key then
			table.insert(list, index)
		end
	end
	return list
end

-- ------------------------------------------------------------------ guardian spawns

local GUARDIAN_TALLEST = 14 -- studs: a spawn on a guardian station never stands taller

function DropService.addGuardian(index, venue, zone, rung, order, top, facing)
	DropService.Guardians[index] = {
		venue = venue,
		zone = zone,
		rung = rung,
		order = order,
		top = top,
		facing = facing,
	}
end

-- Takes the fighter off a guardian (won, or left too long).
function DropService.clearGuardian(index)
	local g = DropService.Guardians[index]
	if not g then
		return
	end
	local v = g.venue
	if v.prizeModel then
		v.prizeModel:Destroy()
	end
	v.prizeKey, v.prizeMutation, v.prizeModel, v.prizeAt = nil, nil, nil, nil
	if v.model_parent then
		v.model_parent:SetAttribute("PrizeName", nil)
		v.model_parent:SetAttribute("PrizeRarity", nil)
	end
end

-- Drops a fighter over guardian `index`: rarer up the ladder (Odds.guardianWeights), the zone's own pool.
function DropService.dropGuardian(index)
	local g = DropService.Guardians[index]
	local v = g and g.venue
	if not v or v.prizeKey or v.locked then
		return
	end
	local luck = LiveOps.mult("dropLuck")
	if (ReplicatedStorage:GetAttribute("StormUntil") or 0) > workspace:GetServerTimeNow() then
		luck *= Config.Events.stormLuck
	end
	local weights = Odds.guardianWeights(g.rung, g.zone)
	local fighter = Odds.rollWeighted(weights, rng, luck, g.zone)
	local mutation = Odds.rollMutation(rng, LiveOps.mult("mutationLuck"), g.zone)
	v.prizeKey, v.prizeMutation, v.prizeAt = fighter.key, mutation, os.clock()
	FX:FireAllClients("Drop", {
		position = g.top,
		from = g.top + Vector3.new(0, 140, 0),
		rarity = fighter.rarity,
		mutation = mutation,
		display = fighter.display,
	})
	task.delay(Config.Drops.landDelay, function()
		if v.prizeKey ~= fighter.key or v.prizeModel then
			return
		end
		local scale = FighterModels.scaleFor(fighter.key, "Table")
			* 0.8
			* math.min(Config.Mutations[mutation].scale or 1, 1.3)
		local function make(k)
			return FighterModels.spawn(fighter.key, g.top, g.facing, {
				scale = k,
				parent = v.model_parent,
				mutation = mutation,
				aura = true,
			})
		end
		local model = make(scale)
		-- Giants (the titans) shrink to fit the station instead of towering over the whole street.
		local size = model and select(2, model:GetBoundingBox())
		if model and size.Y > GUARDIAN_TALLEST then
			model:Destroy()
			model = make(scale * GUARDIAN_TALLEST / size.Y)
		end
		if not model then
			DropService.clearGuardian(index)
			return
		end
		model.Name = "GuardianPrize"
		model:SetAttribute("Clip", Fighters.signature(fighter.key))
		model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
		nameplate(model, fighter, mutation, nil)
		v.prizeModel = model
		if v.model_parent then
			v.model_parent:SetAttribute("PrizeName", fighter.display)
			v.model_parent:SetAttribute("PrizeRarity", fighter.rarity)
		end
	end)
end

-- One guardian spawn per zone each drop: on a random guardian (or boss) with nothing over it and no fight on.
local function dropGuardians()
	local byZone = {}
	for index, g in DropService.Guardians do
		local v = g.venue
		if v.prizeKey and not v.locked and os.clock() - (v.prizeAt or 0) > Config.Drops.despawn then
			DropService.clearGuardian(index)
		end
		if not v.prizeKey and not v.locked then
			byZone[g.zone] = byZone[g.zone] or {}
			table.insert(byZone[g.zone], index)
		end
	end
	for _, list in byZone do
		DropService.dropGuardian(list[rng:NextInteger(1, #list)])
	end
end

function DropService.start(world)
	for _, altarModel in world.altars:GetChildren() do
		local index = altarModel:GetAttribute("Index")
		local top = altarModel.Top
		local stand = top.FighterStand.WorldPosition
		DropService.Altars[index] = {
			tier = altarModel:GetAttribute("Tier"),
			model_parent = altarModel,
			stand = stand,
			facing = altarModel:GetAttribute("Facing") or Vector3.new(stand.X, 0, stand.Z),
			light = top.RarityLight,
			sky = altarModel:GetAttribute("Sky"),
			zone = altarModel:GetAttribute("Zone"),
		}
	end
	task.spawn(function()
		while true do
			local nextAt = workspace:GetServerTimeNow() + Config.Drops.interval
			ReplicatedStorage:SetAttribute("NextDrop", nextAt)
			task.wait(Config.Drops.interval)
			-- Unclaimed fighters leave so altars keep cycling.
			for index, altar in DropService.Altars do
				local gift = altar.reservedFor and os.clock() < (altar.reservedUntil or 0) -- a new player's tutorial drop
				if
					altar.model
					and not altar.locked
					and not gift
					and os.clock() - (altar.landedAt or 0) > Config.Drops.despawn
				then
					DropService.clear(index)
				end
			end
			-- One drop per place (the hub and each zone), so the hub never waits on zone altars.
			local byPlace = {}
			for _, index in emptyAltars() do
				local place = DropService.Altars[index].zone or "Hub"
				byPlace[place] = byPlace[place] or {}
				table.insert(byPlace[place], index)
			end
			for _, empty in byPlace do
				DropService.drop(empty[rng:NextInteger(1, #empty)])
			end
			dropGuardians()
		end
	end)
	-- Studio testing: set workspace attribute ForceDrop = <altar index> from the Server command bar.
	if game:GetService("RunService"):IsStudio() then
		workspace:GetAttributeChangedSignal("ForceDrop"):Connect(function()
			local index = workspace:GetAttribute("ForceDrop")
			if DropService.Altars[index] then
				DropService.clear(index)
				DropService.drop(index)
			end
			workspace:SetAttribute("ForceDrop", nil)
		end)
	end
	-- Open with a few fighters already standing, so the island never looks empty on join.
	for index in DropService.Altars do
		if index % 2 == 1 then
			DropService.drop(index)
		end
	end
end

-- Studio check: every fighter in rows north of the island (workspace attribute FighterGallery).
function DropService.gallery()
	local folder = Instance.new("Folder")
	folder.Name = "FighterGallery"
	folder.Parent = workspace
	for i, fighter in Fighters.Launch do
		local col = (i - 1) % 16
		local row = math.floor((i - 1) / 16)
		local feet = Vector3.new(-60 + col * 8, 0, -170 - row * 12)
		local model = FighterModels.spawn(fighter.key, feet, Vector3.new(0, 0, 1), { parent = folder })
		if model then
			nameplate(model, fighter, "Normal", "Diamond")
		end
	end
end

return DropService
