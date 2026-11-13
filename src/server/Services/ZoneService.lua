-- Zones (docs/WORLD_PLAN.md §2-5): builds each zone island that has a builder (server/Zones/<Name>.lua),
-- moves players between the hub and zones, and runs the Dojo Ladder.
--   * build(world): before drops and clashes start; zone altars join world.altars / world.pads.
--   * start(ClashService, DataService): registers every guardian and boss as a clash venue and starts the
--     travel loop. Guardians unlock one at a time; beating the boss unlocks the next zone. Upgrade Power
--     softens guardians like any bot (ClashService).
--   * Travel: walk into an unlocked gate's portal (hub or zone exit) to go through; a zone's return pad
--     brings you back to its hub gate. The player's current place is the attribute "Zone" (client lighting).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local CollectionService = game:GetService("CollectionService")
local Social = require(script.Parent.SocialService)
local Bricks = require(Shared.Bricks)
local Fighters = require(Shared.Fighters)
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local Reveal = require(script.Parent.Parent.Reveal)
local Ocean = require(script.Parent.Parent.Ocean)
local Streaming = require(script.Parent.Parent.Streaming)
local Plots = require(script.Parent.PlotService)

local ZoneService = {}
local FX = Net.get("FX")
local built = {} -- [zone name] = builder result
local gates = {} -- { { model, zone, trigger, from } }
local travelled = {} -- [player] = os.clock() of their last trip
local Data

local GOLD = Color3.fromRGB(255, 214, 80)
local RED = Color3.fromRGB(255, 120, 100)
local GREEN = Color3.fromRGB(120, 255, 150)

local function banner(player, text, color)
	FX:FireClient(player, "Banner", { text = text, color = color })
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Bot skill for ladder rung 1-5, stepping through the zone's band.
local function skillFor(zone, rung)
	local a, b = Config.BotSkill[zone.band[1]], Config.BotSkill[zone.band[2]]
	local t = (rung - 1) / 4
	return {
		base = lerp(a.base, b.base, t),
		fade = lerp(a.fade, b.fade, t),
		perfect = lerp(a.perfect, b.perfect, t),
		smash = lerp(a.smash, b.smash, t),
	}
end

local function cpsFor(band, t)
	local a, b = Config.Bots[band[1]], Config.Bots[band[2]]
	return lerp((a[1] + a[2]) / 2, (b[1] + b[2]) / 2, t)
end

-- A signpost at a zone's arrival (docs/WAYFINDING_PLAN.md step 5) pointing at the places in that zone.
local function centroid(models)
	local sum, n = Vector3.zero, 0
	for _, m in models do
		sum += m:GetPivot().Position
		n += 1
	end
	return n > 0 and sum / n or nil
end

-- One big floating word over each place in the zone (DROPS, TRAINING, GUARDIANS, BOSS), like the hub's,
-- instead of a signpost: readable from across the zone, nothing standing in the way.
local function word(parent, pos, text, color)
	local anchor = Instance.new("Part")
	anchor.Name = "PlaceWord"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = parent
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(#text * 3.4 + 6, 8)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 14, 30)
	stroke.Parent = t
end

local function placeWords(info, name)
	if not info or not info.arrival then
		return
	end
	local training = {}
	for _, d in info.model:GetDescendants() do
		if d:IsA("Model") and CollectionService:HasTag(d, "TrainStation") then
			table.insert(training, d)
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "PlaceWords_" .. name
	folder.Parent = info.model
	local function add(text, color, at, up)
		if at then
			word(folder, at + Vector3.new(0, up, 0), text, color)
		end
	end
	-- (A zone can say where its places are; a centroid of things spread round the island points at nothing.)
	local at = info.words or {}
	add("DROPS", Color3.fromRGB(255, 205, 60), at.DROPS or centroid(info.altars or {}), 38) -- (over the name cards)
	add("TRAINING", Color3.fromRGB(255, 150, 40), at.TRAINING or centroid(training), 22)
	add(
		"GUARDIANS",
		Color3.fromRGB(120, 200, 255),
		info.stations and info.stations[1] and info.stations[1].model:GetPivot().Position,
		58 -- (high: seen from the arrival it sits above DROPS, not on it)
	)
	add("BOSS", Color3.fromRGB(255, 90, 80), info.boss and info.boss.model and info.boss.model:GetPivot().Position, 34)
	-- (No HUB word: the return pad carries its own HUB board right beside the arrival.)
end

function ZoneService.build(world, Hub)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = world.root
	local index = #world.pads
	for name, zone in Config.Zones do
		local module = script.Parent.Parent.Zones:FindFirstChild(name)
		if module and zone.center then
			local set = Bricks.Zones[zone.set]
			built[name] = require(module).build(zonesFolder, zone, {
				altar = function(cf, sky, facing)
					index += 1
					local m, pads = Hub.altar(world.altars, index, cf, zone.tier, set, sky, facing)
					m:SetAttribute("Zone", name)
					world.pads[index] = pads
					return m
				end,
			})
			placeWords(built[name], name)
		end
	end
	-- Hub gates (built by Hub) and each zone's exit gate.
	for _, g in world.root:GetDescendants() do
		if g:IsA("Model") and g.Name == "ZoneGate" and g:GetAttribute("Trigger") then
			local from
			for name, info in built do
				if info.exitGate == g then
					from = name
				end
			end
			table.insert(
				gates,
				{ model = g, zone = g:GetAttribute("Zone"), trigger = g:GetAttribute("Trigger"), from = from }
			)
		end
	end
end

-- Where a player arrives back in the hub from `zone`: on its gate's pier, facing the hub.
local function hubReturn(zone)
	for _, g in gates do
		if g.zone == zone and not g.from then
			local p = g.trigger
			local inward = Vector3.new(-p.X, 0, -p.Z).Unit
			local at = p + inward * 12
			return CFrame.lookAt(at, at + inward)
		end
	end
	return CFrame.new(Config.Island.spawn + Vector3.new(0, 3, 0))
end

local function travel(player, cf)
	if not player.Character then
		return
	end
	travelled[player] = os.clock()
	task.spawn(function()
		Streaming.prepare(player, cf.Position) -- (the place is loaded before they land in it)
		local character = player.Character
		if character then
			character:PivotTo(cf + Vector3.new(0, 3, 0))
			player:SetAttribute("Arrived", os.clock()) -- client/ZoneClient.lua turns the camera to face the way in
		end
	end)
end

local function unlocked(player, zone)
	local data = Data.get(player)
	return data and data.zones[zone] == true
end

local function tryGate(player, gate)
	local zone = Config.Zones[gate.zone]
	if not zone then
		return
	end
	if not unlocked(player, gate.zone) then
		local before
		for _, z in Config.Zones do
			if z.next == gate.zone then
				before = z
			end
		end
		local need = zone.unlockPower
			and ("REACH " .. Format.short(zone.unlockPower) .. " POWER TO ENTER " .. zone.title)
		banner(player, before and ("BEAT " .. before.boss.title .. " IN " .. before.title) or need or "LOCKED", RED)
		return
	end
	local info = built[gate.zone]
	if not info then
		banner(player, zone.title .. " IS COMING SOON!", GOLD)
		return
	end
	travel(player, info.arrival)
end

-- Fell into the sea (server/Ocean.lua): back to the place's way in, no death. A thief drops the fighter
-- (PlotService sets onSplash to end the steal).
ZoneService.onSplash = nil
local function splash(player, where)
	if ZoneService.onSplash then
		ZoneService.onSplash(player)
	end
	local info = built[where]
	if info and info.arrival then
		travel(player, info.arrival)
	else
		local sp = Config.Island.spawn
		travel(player, CFrame.lookAt(sp + Vector3.new(0, 3, 0), Vector3.new(0, 3, 0)))
	end
	banner(player, "SPLASH! BACK TO SAFETY", Color3.fromRGB(120, 200, 255))
end

local function travelLoop()
	while true do
		task.wait(0.2)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or root.Anchored then
				continue
			end
			local pos = root.Position
			-- Which place they're in (for lighting and music on the client).
			local where = "Hub"
			for name, info in built do
				local c = info.frame.Position
				if Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude < (info.radius or 170) then
					where = name
				end
			end
			if player:GetAttribute("Zone") ~= where then
				player:SetAttribute("Zone", where)
			end
			if pos.Y < Ocean.LEVEL + 6 then
				splash(player, where)
				continue
			end
			if os.clock() - (travelled[player] or 0) < 3 then
				continue
			end
			for _, g in gates do
				if (pos - g.trigger).Magnitude < 9 then
					travelled[player] = os.clock()
					tryGate(player, g)
					break
				end
			end
			for name, info in built do
				if (pos - info.returnPad).Magnitude < 5 then
					travel(player, hubReturn(name))
				end
			end
		end
	end
end

-- First-clear prizes: each guardian pays cash (the zone's slot guardianCash x rung, so the ladder climbs), the boss
-- gives its exclusive fighter (shared/Fighters.lua `exclusive`) with the full reveal.

local function ladderResult(name, zone, rung, isBoss)
	return function(winner)
		if not winner then
			return
		end
		local data = Data.get(winner)
		if not data then
			return
		end
		if isBoss then
			local first = not data.bosses[name]
			data.bosses[name] = true
			if zone.next then
				data.zones[zone.next] = true
			end
			Data.changed(winner)
			if first then
				if Fighters.ByKey[zone.boss.key] then
					task.delay(2.5, Reveal.giveFighter, winner, zone.boss.key, "Normal") -- after the result card
				end
				local nextZone = zone.next and Config.Zones[zone.next]
				banner(winner, nextZone and (nextZone.title .. " UNLOCKED!") or (zone.boss.title .. " DEFEATED!"), GOLD)
				if nextZone then
					-- The big NEW AREA card with the zone's colour and emblem (client/Tutorial.lua), after the result card.
					task.delay(2.5, function()
						if winner.Parent then
							FX:FireClient(winner, "ZoneUnlocked", { zone = zone.next })
						end
					end)
				end
				Social.award(winner, name) -- the zone's badge (Config.Badges)
				if not nextZone then
					winner:SetAttribute("WorldCleared", true) -- client/Rebirth.lua: rebirth is what comes next
				end
				for _, other in Players:GetPlayers() do
					if other ~= winner then
						banner(other, winner.DisplayName .. " DEFEATED " .. zone.boss.title .. "!", GOLD)
					end
				end
			end
			return
		end
		if (data.ladder[name] or 0) < rung then
			data.ladder[name] = rung
			local prize = ((Config.Zones[name] and Config.Zones[name].guardianCash) or 0) * rung
			if prize > 0 then
				Plots.addCash(winner, prize)
			end
			Data.changed(winner)
			banner(
				winner,
				(rung < 5 and ("GUARDIAN " .. rung .. " DEFEATED!") or "THE BOSS AWAITS!")
					.. (prize > 0 and ("  +" .. Format.cash(prize)) or ""),
				GREEN
			)
		end
	end
end

local function ladderGate(name, rung, isBoss)
	return function(player)
		local data = Data.get(player)
		if not data then
			return false, "LOADING..."
		end
		if not data.zones[name] then
			return false, "ZONE LOCKED"
		end
		local need = isBoss and 5 or rung - 1
		if (data.ladder[name] or 0) < need then
			return false, isBoss and "BEAT ALL 5 GUARDIANS FIRST" or ("BEAT GUARDIAN " .. need .. " FIRST")
		end
		-- Power gate (only for the first clear: a rebirth's reset never re-locks what you've beaten).
		local cleared = isBoss and data.bosses[name] or (data.ladder[name] or 0) >= rung
		local power = Config.Zones[name].ladderPower and Config.Zones[name].ladderPower[rung]
		if power and not cleared and (data.power or 0) < power then
			return false, "NEEDS " .. Format.short(power) .. " POWER"
		end
		return true
	end
end

-- Where a guardian spawn stands: on the station's prize altar between the two pads (the boss arena has
-- none: it hovers over the middle), facing the challenger's pad.
local function prizeSpot(station)
	local pads = station.pads
	local mid = (pads[1].Position + pads[2].Position) / 2
	local spot = station.prizeAt and station.prizeAt.Position or mid + Vector3.new(0, 7, 0)
	local toward = pads[1].Position - mid
	local flat = Vector3.new(toward.X, 0, toward.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	return spot, flat
end

function ZoneService.start(ClashService, DataService, DropService)
	Data = DataService
	for name, info in built do
		local zone = Config.Zones[name]
		for rung, station in info.stations do
			local key = zone.guardians[rung]
			local fighter = Fighters.ByKey[key]
			local spec = {
				pads = station.pads,
				model = station.display,
				model_parent = station.model,
				tier = zone.tier,
				title = "GUARDIAN " .. rung,
				rounds = 2,
				rival = {
					key = key,
					name = fighter and fighter.display or key,
					skill = skillFor(zone, rung),
					cps = cpsFor(zone.band, (rung - 1) / 4),
					-- An EVEN fight at the rung's Power requirement; train past it to make it EASY.
					power = (zone.ladderPower and zone.ladderPower[rung] or 1e3) * 1.2,
					scale = 1.1,
				},
				canSeat = ladderGate(name, rung, false),
				onResult = ladderResult(name, zone, rung, false),
				-- The first win over this guardian gives the guardian itself (ClashService); after that, only
				-- whatever drop is hovering over it.
				firstPrize = function(player)
					local data = Data.get(player)
					return data and (data.ladder[name] or 0) < rung and fighter and key or nil
				end,
			}
			local index = ClashService.addChallenge(spec)
			if DropService then
				local top, facing = prizeSpot(station)
				DropService.addGuardian(index, spec, name, rung, zone.order, top, facing)
			end
		end
		local boss = zone.boss
		local bossSpec = {
			pads = info.boss.pads,
			model = info.boss.display,
			model_parent = info.boss.model,
			tier = zone.tier,
			title = boss.title,
			rounds = boss.rounds,
			rival = {
				key = boss.key,
				name = boss.title,
				skill = Config.BotSkill[boss.skill],
				cps = cpsFor({ zone.band[2], zone.band[2] }, 1) + 1,
				power = (zone.ladderPower and zone.ladderPower[6] or 10e3) * 1.5,
				boss = true, -- rages once a round when pushed deep (ClashService)
				scale = 1.25,
			},
			canSeat = ladderGate(name, 6, true),
			onResult = ladderResult(name, zone, 6, true),
		}
		local bossIndex = ClashService.addChallenge(bossSpec)
		if DropService then
			local top, facing = prizeSpot(info.boss)
			DropService.addGuardian(bossIndex, bossSpec, name, 6, zone.order, top, facing)
		end
	end
	-- The MAP (client/Map.lua): travel to any unlocked zone's arrival, or back to the hub's spawn.
	Net.get("Zone").OnServerEvent:Connect(function(player, kind, where)
		if kind ~= "Travel" or type(where) ~= "string" then
			return
		end
		if player:GetAttribute("InClash") then
			return
		end
		if player:GetAttribute("Carrying") and player:GetAttribute("CarryKind") ~= "own" then
			banner(player, "RUN IT HOME! NO TELEPORTING WHILE STEALING", RED)
			return
		end
		if (player:GetAttribute("Ftue") or 99) < 99 then
			return -- the tutorial walks you where you need to be
		end
		if where == "Hub" then
			local sp = Config.Island.spawn
			travel(player, CFrame.lookAt(sp + Vector3.new(0, 3, 0), Vector3.new(0, 3, 0)))
			return
		end
		local info = built[where]
		if info and unlocked(player, where) then
			travel(player, info.arrival)
		end
	end)

	-- Dying in a zone (a fall off the edge, mostly) brings you back at that zone's arrival, not the hub.
	local diedIn = {}
	local function track(player)
		player.CharacterRemoving:Connect(function()
			diedIn[player] = player:GetAttribute("Zone")
		end)
		player.CharacterAdded:Connect(function(character)
			local zone = diedIn[player]
			diedIn[player] = nil
			local info = zone and built[zone]
			if info and info.arrival then
				character:WaitForChild("HumanoidRootPart", 5)
				task.wait(0.2)
				travel(player, info.arrival)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		travelled[player] = nil
		diedIn[player] = nil
	end)
	task.spawn(travelLoop)
end

return ZoneService
