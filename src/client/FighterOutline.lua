-- The bright outline round fighters (like Anime Dice's): white, or the mutation's colour
-- (shared/FighterAura.lua), so a fighter stands out from the dark bases. Roblox draws only about 31
-- Highlights at once (players' auras use some), so only the nearest LIMIT fighters get one; none in a fight.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FighterAura = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FighterAura"))
local UIKit = require(script.Parent.UIKit)

local FighterOutline = {}
local LIMIT = 16
local RANGE = 140

function FighterOutline.start()
	local camera = workspace.CurrentCamera
	local shown = {} -- [model] = Highlight
	local function drop(model)
		if shown[model] then
			shown[model]:Destroy()
			shown[model] = nil
		end
	end
	while true do
		task.wait(0.5)
		camera = workspace.CurrentCamera or camera
		local from = camera.CFrame.Position
		local near = {}
		if not UIKit.inFight() then
			for _, model in CollectionService:GetTagged("Fighter") do
				-- In the world only (not a viewport), standing on a stand or an altar, not a follower.
				if model:IsDescendantOf(workspace) and not model.Name:find("^Champion_") then
					local root = model:FindFirstChild("HumanoidRootPart")
					local d = root and (root.Position - from).Magnitude
					if d and d < RANGE then
						table.insert(near, { model = model, d = d })
					end
				end
			end
			table.sort(near, function(a, b)
				return a.d < b.d
			end)
		end
		local keep = {}
		for i = 1, math.min(LIMIT, #near) do
			keep[near[i].model] = true
		end
		for model in shown do
			if not keep[model] or not model.Parent then
				drop(model)
			end
		end
		for model in keep do
			if not shown[model] then
				local h = Instance.new("Highlight")
				h.Name = "Outline"
				h.Adornee = model
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.FillTransparency = 1
				h.OutlineTransparency = 0
				h.OutlineColor = FighterAura.outline(model:GetAttribute("Mutation"))
				h.Parent = model
				shown[model] = h
			end
		end
	end
end

return FighterOutline
