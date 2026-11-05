-- Robux sales (shared/Products.lua, docs/MONETIZATION.md). Server-authoritative:
--   * gamepasses: ownership is checked on join (and remembered on purchase); perks become player
--     attributes the other services read: CashMult (2x Cash, VIP), TrainBoost (2x Power, 2x Training),
--     LockBonus (VIP), FastSteal / CarryBoost (Fast Steal), AutoTrain,
--   * developer products go through ProcessReceipt, granted exactly once (receipt ids saved with the
--     player's data) and only once their data has loaded,
--   * Auto Train: owners who switch it on (Shop remote "AutoTrain") train at Products.AutoTrainRate reps
--     per second without clicking,
--   * Studio: products with id 0 can be "bought" from the shop (Shop remote "DebugBuy") to test the flow.
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Products)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Reveal = require(script.Parent.Parent.Reveal)
local MarketService = require(script.Parent.MarketService)

local MonetizationService = {}
local FX = Net.get("FX")
local remote = Net.get("Shop")
local Data, Plots, Training

local GOLD = Color3.fromRGB(255, 214, 80)
local GREEN = Color3.fromRGB(120, 255, 150)
local MAX_RECEIPTS = 60

local owns = {} -- [player] = { [passKey] = true } from Roblox (gamepasses)
local rng = Random.new()

local function banner(player, text, color)
	FX:FireClient(player, "Banner", { text = text, color = color })
end

local function ownsPass(player, key)
	local data = Data.get(player)
	return (owns[player] and owns[player][key]) or (data and data.passes[key]) or false
end

-- Owns the pass, or a bundle that includes it (Pro Bundle).
local function has(player, key)
	if ownsPass(player, key) then
		return true
	end
	for _, pass in Products.Passes do
		if pass.includes and table.find(pass.includes, key) and ownsPass(player, pass.key) then
			return true
		end
	end
	return false
end

local function boostActive(data, key)
	return (data.boostUntil[key] or 0) > os.time()
end

-- Recomputes every perk attribute from passes and timed boosts.
function MonetizationService.refresh(player)
	local data = Data.get(player)
	if not data then
		return
	end
	local vip, cash, power = has(player, "VIP"), has(player, "DoubleCash"), has(player, "DoublePower")
	local fast, auto = has(player, "FastSteal"), has(player, "AutoTrain")
	player:SetAttribute("VIP", vip or nil)
	player:SetAttribute("DoubleCash", cash or nil)
	player:SetAttribute("DoublePower", power or nil)
	player:SetAttribute("FastSteal", fast or nil)
	player:SetAttribute("AutoTrain", auto or nil)
	player:SetAttribute(
		"CashMult",
		(cash and 2 or 1)
			* (vip and Products.VIPCash or 1)
			* (player:GetAttribute("IndexMult") or 1)
			* (player:GetAttribute("GroupMult") or 1) -- the group reward (SocialService)
			* (player:GetAttribute("FriendBoost") or 1) -- friends in the server (SocialService)
	)
	-- Premium weights: the best one owned (TrainingService wears and trains with it).
	local premium = 0
	for _, pass in Products.Passes do
		if pass.gear then
			local own = has(player, pass.key)
			player:SetAttribute(pass.key, own or nil) -- the shop and the stall prompts show OWNED
			if own then
				premium = math.max(premium, pass.gear)
			end
		end
	end
	player:SetAttribute("PremiumGear", premium > 0 and premium or nil)
	player:SetAttribute(
		"TrainBoost",
		(power and 2 or 1) * (boostActive(data, "PowerBoost") and 2 or 1) * (player:GetAttribute("FriendBoost") or 1)
	)
	player:SetAttribute("LockBonus", vip and Products.VIPLock or 0)
	player:SetAttribute("CarryBoost", fast and Products.FastStealCarry or 0)
	player:SetAttribute("DropLuck", has(player, "DropLuck") or nil)
	player:SetAttribute("MutationLuck", has(player, "MutationLuck") or nil)
	-- Owned passes as attributes too, so the shop shows OWNED (bundles count for what they include).
	for _, pass in Products.Passes do
		if not pass.gear then
			player:SetAttribute("Owns_" .. pass.key, has(player, pass.key) or nil)
		end
	end
	-- The equipped beam skin (shared/BeamSkins.lua), if it's still owned; client/ClashBeams.lua draws it.
	local beamPass = data.beam and Products.ByKey["Beam" .. data.beam]
	player:SetAttribute("BeamSkin", (beamPass and has(player, beamPass.key)) and data.beam or nil)
	local extra = has(player, "ExtraStands")
	if (player:GetAttribute("ExtraStands") == true) ~= extra then
		player:SetAttribute("ExtraStands", extra or nil)
		Plots.refresh(player) -- the two gold stands open (or show their lock)
	end
	local floor2 = has(player, "Floor2")
	if (player:GetAttribute("Floor2") == true) ~= floor2 then
		player:SetAttribute("Floor2", floor2 or nil)
		Plots.refresh(player) -- Floor 2's stands go from the pass lock to cash locks
	end
	-- The Starter Pack is offered until this time (os.time), once.
	local starterEnds = (data.firstJoin or 0) + Products.StarterDays * 86400
	player:SetAttribute("StarterUntil", (not data.starterBought and starterEnds > os.time()) and starterEnds or nil)
	-- New Player Luck: the first drops of a new save are luckier (DropService), so the first Rares come fast.
	player:SetAttribute("NewbieUntil", (data.firstJoin or 0) + Config.NewbieLuck.minutes * 60)
	player:SetAttribute("PowerBoostUntil", boostActive(data, "PowerBoost") and data.boostUntil.PowerBoost or nil)
	if not auto then
		player:SetAttribute("AutoTrainOn", nil)
	end
end

-- A rarity from a summon's odds table.
local function rollOdds(odds, floor)
	local total = 0
	for _, w in odds do
		total += w
	end
	local roll = rng:NextNumber(0, total)
	for _, key in Config.RarityOrder do
		local w = odds[key]
		if w then
			if roll < w then
				return key
			end
			roll -= w
		end
	end
	return floor
end

-- Applies one developer product. Returns true once granted.
local function grantItem(player, key)
	local data = Data.get(player)
	local item = Products.ByKey[key]
	if not data or not item then
		return false
	end
	if key == "ServerLuck" then
		local now = workspace:GetServerTimeNow()
		local current = ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0
		ReplicatedStorage:SetAttribute("ServerLuckUntil", math.max(current, now) + item.minutes * 60)
		for _, other in Players:GetPlayers() do
			banner(other, string.upper(player.DisplayName) .. " ACTIVATED SERVER LUCK x2!", GOLD)
		end
	elseif key == "PowerBoost" then
		data.boostUntil.PowerBoost = math.max(data.boostUntil.PowerBoost or 0, os.time()) + item.minutes * 60
		banner(player, "2x TRAINING FOR " .. item.minutes .. " MIN!", GREEN)
	elseif key == "Shield" then
		if not Plots.shield(player, item.minutes * 60) then
			return false
		end
		banner(player, "BASE SHIELDED FOR " .. item.minutes .. " MIN!", GREEN)
	elseif item.market then
		return MarketService.grant(player, key) -- a Fighter Market fighter (its own reveal)
	elseif item.floor then
		-- Only offered where paid random items are allowed; if one is bought anyway, its floor, fixed.
		if player:GetAttribute("PaidRandomOK") then
			Reveal.give(player, rollOdds(item.odds, item.floor), nil, true)
		else
			Reveal.give(player, item.floor, true, true)
		end
	elseif key == "StarterPack" then
		data.starterBought = true
		-- A random fighter is a paid random item: a fixed one where those aren't allowed.
		Reveal.give(player, "Epic", player:GetAttribute("PaidRandomOK") ~= true, true)
		if data.gear < Products.StarterGear then
			data.gear = Products.StarterGear
		end
		data.boostUntil.PowerBoost = math.max(data.boostUntil.PowerBoost or 0, os.time()) + item.minutes * 60
		Plots.addCash(player, Products.StarterCash)
		banner(player, "STARTER PACK UNLOCKED!", GOLD)
	elseif key == "CashLarge" or key == "CashHuge" then
		local amount = math.max(Products.MinCashPack, Plots.incomeRate(player) * item.seconds)
		if not Plots.addCash(player, amount) then
			return false
		end
		banner(player, "+" .. Format.cash(amount) .. "!", GREEN)
	elseif key == "StandNow" then
		if not Plots.unlockFree(player) then
			-- Every stand is already open: pay it out as a Cash Pack instead.
			local amount = math.max(Products.MinCashPack, Plots.incomeRate(player) * 600)
			Plots.addCash(player, amount)
			banner(player, "ALL STANDS OPEN · +" .. Format.cash(amount), GREEN)
		end
	else
		return false
	end
	Data.changed(player)
	MonetizationService.refresh(player)
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and Data.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they're back
	end
	if table.find(data.receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
	end
	local item = Products.ById[receipt.ProductId]
	if not item or not grantItem(player, item.key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.receipts, receipt.PurchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
	Data.changed(player)
	Data.saveNow(player) -- a paid grant shouldn't wait for the next autosave
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Roblox's rules for this player (some countries restrict paid random items): summons only show where
-- PaidRandomOK is true (client/Shop.lua). Unknown (the check failed) counts as restricted.
local function checkPolicy(player)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	player:SetAttribute("PaidRandomOK", ok and info and info.ArePaidRandomItemsRestricted == false or nil)
end

local function checkPasses(player)
	task.spawn(checkPolicy, player)
	owns[player] = owns[player] or {}
	-- Roblox counts the game's creator as owning every pass; that would hide the new-player experience
	-- (premium weights, VIP...), so the creator only gets passes bought in the session.
	if player.UserId == game.CreatorId then
		MonetizationService.refresh(player)
		return
	end
	for _, pass in Products.Passes do
		if pass.id ~= 0 then
			local ok, result =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and result then
				owns[player][pass.key] = true
			end
		end
	end
	MonetizationService.refresh(player)
end

-- Whether the player owns pass `key` (or a bundle with it).
function MonetizationService.has(player, key)
	return has(player, key)
end

-- Equips beam skin `skin` (a BeamSkins key the player owns, or "" for the side colour).
function MonetizationService.equipBeam(player, skin)
	local data = Data.get(player)
	local pass = type(skin) == "string" and Products.ByKey["Beam" .. skin]
	if data and (skin == "" or (pass and has(player, pass.key))) then
		data.beam = skin ~= "" and skin or nil
		Data.changed(player)
		MonetizationService.refresh(player)
	end
end

-- Offers gamepass `key` (from a world display). Studio, with no id yet: granted at once to test the flow.
function MonetizationService.buyPass(player, key)
	local pass = Products.ByKey[key]
	local data = Data.get(player)
	if not pass or not data or has(player, key) then
		return
	end
	if pass.id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	elseif RunService:IsStudio() then
		data.passes[key] = true
		if pass.beam then
			data.beam = pass.beam
		end
		Data.changed(player)
		banner(player, string.upper(pass.name) .. " UNLOCKED! (STUDIO TEST)", GOLD)
		MonetizationService.refresh(player)
	end
end

function MonetizationService.start(DataService, PlotService, TrainingService)
	Data, Plots, Training = DataService, PlotService, TrainingService
	MarketplaceService.ProcessReceipt = processReceipt
	DataService.onLoaded(function(player)
		task.spawn(checkPasses, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		owns[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in Products.Passes do
			if pass.id == passId then
				owns[player] = owns[player] or {}
				owns[player][pass.key] = true
				banner(player, string.upper(pass.name) .. " UNLOCKED! THANK YOU!", GOLD)
				local data = Data.get(player)
				if pass.beam and data then
					data.beam = pass.beam -- a new beam skin goes on at once
					Data.changed(player)
				end
			end
		end
		MonetizationService.refresh(player)
	end)

	remote.OnServerEvent:Connect(function(player, kind, value)
		if kind == "EquipBeam" then
			MonetizationService.equipBeam(player, value)
		elseif kind == "AutoTrain" then
			player:SetAttribute("AutoTrainOn", (value == true and has(player, "AutoTrain")) or nil)
		elseif kind == "DebugBuy" and RunService:IsStudio() and type(value) == "string" then
			-- Studio only: pretend the purchase went through (products with id 0 can't be bought).
			local product = Products.ByKey[value]
			local data = Data.get(player)
			if not product or not data then
				return
			end
			if table.find(Products.Passes, product) then
				data.passes[value] = true
				if product.beam then
					data.beam = product.beam
				end
				Data.changed(player)
				banner(player, string.upper(product.name) .. " UNLOCKED! (STUDIO TEST)", GOLD)
				MonetizationService.refresh(player)
			else
				grantItem(player, value)
			end
		end
	end)

	-- Auto Train, and perks refreshed as timed boosts run out.
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.25)
			tick += 1
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("AutoTrainOn") then
					Training.autoRep(player, Products.AutoTrainRate * 0.25)
				end
				if tick % 20 == 0 then
					local data = Data.get(player)
					if data and data.boostUntil.PowerBoost and not boostActive(data, "PowerBoost") then
						data.boostUntil.PowerBoost = nil
						MonetizationService.refresh(player)
					end
				end
			end
		end
	end)
end

return MonetizationService
