-- The Beam Shrine on the hub (server/Hub.lua beamShrine): a prompt on each pylon. Holding it buys that
-- beam skin's gamepass, or equips it (or takes it off) if the player already owns it. The pylons carry
-- attributes for client/BeamShrine.lua, which draws the beams and sets each prompt's text per player:
--   pylon model: Skin, At (where its beam starts); shrine model: Orb (where the beams meet).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Products = require(ReplicatedStorage.Shared.Products)

local BeamShrineService = {}

function BeamShrineService.start(world, Monetization)
	local spec = world.shrine
	if not spec then
		return
	end
	local shrine = world.root:FindFirstChild("BeamShrine")
	if shrine then
		shrine:SetAttribute("Orb", spec.orb)
	end
	for _, pylon in spec.pylons do
		local pass = Products.ByKey["Beam" .. pylon.skin]
		pylon.model:SetAttribute("At", pylon.at)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BeamPrompt"
		prompt.ObjectText = pass and pass.name or pylon.skin
		prompt.ActionText = pass and ("Buy  ·  R$ " .. pass.price) or "Buy"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = pylon.anchor
		prompt.Triggered:Connect(function(player)
			if not pass then
				return
			end
			if Monetization.has(player, pass.key) then
				local on = player:GetAttribute("BeamSkin") == pylon.skin
				Monetization.equipBeam(player, on and "" or pylon.skin)
			else
				Monetization.buyPass(player, pass.key)
			end
		end)
	end
end

return BeamShrineService
