-- A fighter held up over a player's head while they run it home (a win, a steal, the tutorial's practice
-- steal, one picked up off a stand): a normal-size copy (a Huge one twice that) standing on the raised hands, facing the way they run, welded to their root so it
-- rides steadily. The arms-up pose itself is drawn on every client (client/TrainPose.lua, "carry", from the
-- player attribute Carrying).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FighterModels = require(ReplicatedStorage.Shared.FighterModels)
local Config = require(ReplicatedStorage.Shared.Config)

local Carry = {}
Carry.Scale = 1 -- the fighter's normal size; Huge mutations double it (Config.Mutations.Huge.scale)
Carry.HandsAbove = 1.25 -- studs from the top of the head to the raised hands

-- Returns the model (or nil if the fighter has no model).
function Carry.lift(player, key, mutation)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not head then
		return nil
	end
	local model = FighterModels.spawn(key, head.Position, root.CFrame.LookVector, {
		scale = Carry.Scale * (Config.Mutations[mutation or "Normal"].scale or 1),
		parent = workspace,
		mutation = mutation,
		aura = true, -- (its rarity's aura, held up with it)
	})
	if not model then
		return nil
	end
	-- Stand its feet on the hands, facing forward.
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	local handsY = head.Position.Y + head.Size.Y / 2 + Carry.HandsAbove
	local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local at = Vector3.new(root.Position.X, model:GetPivot().Position.Y + handsY - bottom, root.Position.Z)
	model:PivotTo(CFrame.lookAt(at, at + flat))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.Massless = false, false, true
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model:SetAttribute("Clip", "PowerUp")
	model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
	return model
end

return Carry
