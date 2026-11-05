-- Gives a fighter with the full show (summons, the Starter Pack, gifts): the player's reveal spinner
-- (client/SummonReveal.lua), then a beam down onto them that everyone sees, then it's saved.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local Products = require(Shared.Products)
local Net = require(Shared.Net)

local Reveal = {}
local FX = Net.get("FX")
local rng = Random.new()
local Training -- TrainingService, set by Reveal.init

function Reveal.init(trainingService)
	Training = trainingService
end

-- A random fighter of `rarity` (15% Golden) revealed to `player`. With `fixed`, always the first fighter
-- of that rarity and no mutation: what a paid item gives where paid random items aren't allowed.
function Reveal.give(player, rarity, fixed, carry)
	local pool = Fighters.ByRarity[rarity]
	local fighter = fixed and pool[1] or pool[rng:NextInteger(1, #pool)]
	-- 15% Golden, doubled with x2 Mutation Luck.
	local golden = 0.15 * (player:GetAttribute("MutationLuck") and Products.MutationLuck or 1)
	local mutation = (not fixed and rng:NextNumber() < golden) and "Golden" or "Normal"
	Reveal.giveFighter(player, fighter.key, mutation, carry)
end

-- A chosen fighter (the Fighter Market) with the same show.
-- `carry` (a purchase): the fighter lands in the player's arms to carry to a stand, not straight onto one or into the bag.
function Reveal.giveFighter(player, key, mutation, carry)
	local fighter = Fighters.ByKey[key]
	if not fighter then
		return
	end
	local rarity = fighter.rarity
	FX:FireClient(player, "SummonReveal", { key = fighter.key, mutation = mutation })
	task.delay(Products.RevealSeconds, function()
		if not player.Parent then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local at = root.Position - Vector3.new(0, 3, 0)
			FX:FireAllClients("Drop", {
				position = at,
				from = at + Vector3.new(0, 160, 0),
				rarity = rarity,
				mutation = mutation,
				display = fighter.display,
				summoner = player.DisplayName,
			})
		end
		task.wait(Config.Drops.landDelay)
		if player.Parent then
			Training.addFighter(player, fighter.key, mutation, carry and "carry" or nil)
		end
	end)
end

return Reveal
