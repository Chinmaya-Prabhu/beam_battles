-- The plot's base building, which grows with rebirth (docs/WORLD_PLAN.md §8.1):
-- 1 tent -> 2 dojo -> 3 pagoda -> 4 floating palace. `cf` is the ground centre, front facing -Z.
local Core = require(script.Parent.Core)
local Build = require(script.Parent.Build)
local Bricks = require(game:GetService("ReplicatedStorage").Shared.Bricks)

local Plot = {}
local BRICK, PLATE = Core.BRICK, Core.PLATE
local C = Bricks.C

local function campfire(m, cf)
	for k = 0, 7 do
		local a = k * math.pi / 4
		Core.centered(
			m,
			cf,
			math.floor(math.cos(a) * 2 + 0.5),
			0,
			math.floor(math.sin(a) * 2 + 0.5),
			1,
			BRICK,
			1,
			C.darkGray
		)
	end
	for _, r in { 0, math.pi / 2 } do
		Core.part(
			m,
			cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, r, math.rad(12)),
			Vector3.new(3, 0.6, 0.6),
			C.brown,
			{ shape = Enum.PartType.Cylinder, smooth = true }
		)
	end
	local core =
		Core.part(m, cf * CFrame.new(0, 1, 0), Vector3.new(1, 1, 1), C.orange, { neon = true, collide = false })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = C.orange
	fire.SecondaryColor = C.yellow
	fire.Parent = core
	Core.light(core, C.orange, 16, 2, true)
end

-- Stage 1: a striped canvas tent with a campfire.
function Plot.tent(parent, cf, set)
	local m = Core.model(parent, "Tent", cf)
	Core.centered(m, cf, 0, 0, 0, 14, PLATE, 14, set.wood[1], { smooth = true })
	local frame = cf * CFrame.Angles(0, math.pi / 2, 0)
	local L, d, h = 10, 9, 6
	for k = 0, L / 2 - 1 do
		local x = -L / 2 + k * 2 + 1
		local color = k % 2 == 0 and C.white or set.accent
		Core.part(
			m,
			frame * CFrame.new(x, PLATE + h / 2, -d / 4),
			Vector3.new(2, h, d / 2),
			color,
			{ class = "WedgePart" }
		)
		Core.part(
			m,
			frame * CFrame.new(x, PLATE + h / 2, d / 4) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(2, h, d / 2),
			color,
			{ class = "WedgePart" }
		)
	end
	-- Door flap on the front gable.
	Core.part(
		m,
		cf * CFrame.new(0, PLATE + 1.4, -L / 2 - 0.1),
		Vector3.new(2.4, 2.8, 0.2),
		C.darkBrown,
		{ smooth = true }
	)
	Core.part(m, cf * CFrame.new(0, PLATE + h + 0.3, 0), Vector3.new(0.4, 0.6, L + 1), C.brown, { smooth = true })
	campfire(m, cf * CFrame.new(4, PLATE, -9))
	Build.crate(m, cf * CFrame.new(-5, PLATE, -6), set)
	Build.barrel(m, cf * CFrame.new(-5, PLATE, -3), set)
	Build.banner(m, cf * CFrame.new(6, PLATE, 5), 10, set.accent, C.gold)
	return m
end

-- Stage 2: a one-storey dojo on a stone platform.
function Plot.dojo(parent, cf, set)
	local m = Core.model(parent, "Dojo", cf)
	Core.centered(m, cf, 0, 0, 0, 20, BRICK, 20, set.stone[#set.stone])
	Build.storey(m, cf * CFrame.new(0, BRICK, 0), 14, BRICK * 6, set, { door = true, glow = true })
	Build.roof(m, cf * CFrame.new(0, BRICK * 8, 0), 20, 20, { colors = set.roof, trim = C.black, finial = true })
	for _, x in { -6, 6 } do
		Build.lanternStone(m, cf * CFrame.new(x, BRICK, -9), set)
	end
	local sign = Core.box(m, cf, -3, BRICK * 7.4, -7.6, 6, BRICK * 1.4, 0.4, C.black, { smooth = true })
	Core.label(sign, "DOJO", Enum.NormalId.Front, C.gold)
	return m
end

-- Stage 3: a three-storey pagoda with lanterns.
function Plot.pagoda(parent, cf, set)
	local m = Core.model(parent, "PagodaBase", cf)
	Build.pagoda(m, cf, 3, 12, set, { glow = true, lanterns = true })
	return m
end

-- Stage 4: a palace with a walled court, a two-storey keep and corner towers under gold roofs.
function Plot.palace(parent, cf, set)
	local m = Core.model(parent, "Palace", cf)
	local goldRoof = { C.darkOrange, C.gold, C.lightOrange }
	Core.centered(m, cf, 0, 0, 0, 28, BRICK * 2, 28, set.stone[#set.stone])
	for side = 0, 3 do
		local face = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		if side == 0 then
			Build.wall(m, face * CFrame.new(-8.5, BRICK * 2, -13.5), 11, BRICK * 2, set, "stone", { crenels = true })
			Build.wall(m, face * CFrame.new(8.5, BRICK * 2, -13.5), 11, BRICK * 2, set, "stone", { crenels = true })
		else
			Build.wall(m, face * CFrame.new(0, BRICK * 2, -13.5), 28, BRICK * 2, set, "stone", { crenels = true })
		end
	end
	local _, top = Build.storey(
		m,
		cf * CFrame.new(0, BRICK * 2, 2),
		16,
		BRICK * 6,
		set,
		{ door = true, glow = true, post = C.gold }
	)
	local _, roofTop =
		Build.roof(m, cf * CFrame.new(0, BRICK * 2 + top, 2), 22, 22, { colors = goldRoof, tiers = 2, trim = C.black })
	local y2 = BRICK * 2 + top + roofTop
	local _, top2 =
		Build.storey(m, cf * CFrame.new(0, y2, 2), 12, BRICK * 5, set, { balcony = true, glow = true, post = C.gold })
	Build.roof(m, cf * CFrame.new(0, y2 + top2, 2), 18, 18, { colors = goldRoof, trim = C.black, finial = true })
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local t = cf * CFrame.new(c[1] * 11, BRICK * 2, c[2] * 11)
		local _, th = Build.storey(m, t, 6, BRICK * 7, set, { glow = true, post = set.accent })
		Build.roof(m, t * CFrame.new(0, th, 0), 9, 9, { colors = goldRoof, trim = C.black, finial = true })
	end
	for _, x in { -4, 4 } do
		Build.banner(m, cf * CFrame.new(x, BRICK * 2, -12), 12, set.accent, C.gold)
	end
	return m
end

Plot.STAGES = { Plot.tent, Plot.dojo, Plot.pagoda, Plot.palace }

return Plot
