-- Wooden signposts that point the way (docs/WAYFINDING_PLAN.md): a tall post with one arm per place,
-- stacked top to bottom, each arm turned to point at its place, the name on both faces in that district's
-- colour and an arrow tip on the end that points. Used at the hub spawn, at the hub districts and at every
-- zone's arrival.
--   Signpost.build(parent, cf, entries)  cf: the post's foot on the ground. entries: { { label, color, target } }
--                                        target: a Vector3 to point at (nil: a flat name board, no arrow).
--                                        flat: all arms face the reader with left/right/up arrows (directories).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.BrickKit)

local Signpost = {}

local C = Bricks.C
local Core = K.Core
local WOOD = Color3.fromRGB(120, 78, 44)
local DARK = Color3.fromRGB(70, 44, 26)
local ARM_LEN, ARM_H, GAP = 9, 1.7, 0.5

local function label(part, text, color)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local t = Core.label(part, text, face, color, Color3.fromRGB(30, 18, 10))
		t.Size = UDim2.fromScale(0.86, 0.78)
		t.Position = UDim2.fromScale(0.07, 0.11)
	end
end

function Signpost.build(parent, cf, entries, flat)
	local m = Core.model(parent, "Signpost", cf)
	local height = 3 + #entries * (ARM_H + GAP) + 1
	Core.centered(m, cf, 0, 0, 0, 2.4, 0.6, 2.4, C.darkGray)
	Core.centered(m, cf, 0, 0.6, 0, 0.8, height, 0.8, DARK, { smooth = true })
	Core.centered(m, cf, 0, 0.6 + height, 0, 1.2, 0.5, 1.2, WOOD, { smooth = true })
	for i, e in entries do
		local y = 0.6 + height - 0.6 - (i - 1) * (ARM_H + GAP) - ARM_H / 2
		local origin = (cf * CFrame.new(0, y, 0)).Position
		local dir
		if e.target then
			local level = Vector3.new(e.target.X - origin.X, 0, e.target.Z - origin.Z)
			dir = level.Magnitude > 0.1 and level.Unit or cf.LookVector
		end
		-- The arm runs from the post toward the place; a flat board (no target) faces the way the post faces.
		local armCf
		local text = string.upper(e.label)
		if flat and dir then
			-- A directory board: every arm faces the reader; an arrow in the text says which way, as seen by
			-- someone reading it (they look opposite the board's facing).
			armCf = cf * CFrame.new(0, y, -0.5)
			local forward = -cf.LookVector
			local right = Vector3.new(-forward.Z, 0, forward.X)
			local side, ahead = dir:Dot(right), dir:Dot(forward)
			if ahead > 0.7 then
				text = "^ " .. text
			elseif side > 0 then
				text = text .. " >"
			else
				text = "< " .. text
			end
			dir = nil
		elseif dir then
			armCf = CFrame.lookAt(origin, origin + dir)
				* CFrame.new(0, 0, -ARM_LEN / 2 - 0.3)
				* CFrame.Angles(0, math.pi / 2, 0)
		else
			armCf = cf * CFrame.new(0, y, -0.5)
		end
		local arm = Core.part(m, armCf, Vector3.new(ARM_LEN, ARM_H, 0.4), WOOD, { smooth = true })
		Core.part(m, armCf, Vector3.new(ARM_LEN + 0.2, ARM_H + 0.2, 0.3), DARK, { smooth = true })
		label(arm, text, e.color or C.white)
		if dir then
			-- An arrow head (">") just past the pointing end: two bars meeting at the tip.
			local L = ARM_H * 1.1
			local tip = armCf * CFrame.new(ARM_LEN / 2 + ARM_H * 0.75, 0, 0)
			for _, side in { 1, -1 } do
				local c = math.cos(math.rad(45)) * L / 2
				Core.part(
					m,
					tip * CFrame.new(-c, side * c, 0) * CFrame.Angles(0, 0, -side * math.rad(45)),
					Vector3.new(L, 0.45, 0.45),
					e.color or WOOD,
					{ smooth = true }
				)
			end
		end
	end
	return m
end

return Signpost
