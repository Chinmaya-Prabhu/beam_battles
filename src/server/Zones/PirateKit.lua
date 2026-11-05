-- Pirate Bay's own pieces (docs/WORLD_PLAN.md §4, zone 3): a tropical lagoon harbour at noon. Sand, sea
-- blues, weathered timber, red-and-white sails. Frames face their front along -Z.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.Parent.BrickKit)

local PirateKit = {}
local C = Bricks.C
local Core = K.Core
local BRICK, PLATE = Core.BRICK, Core.PLATE
local SMOOTH = { smooth = true }
local DECOR = { smooth = true, collide = false }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WOOD = rgb(150, 100, 60)
local WOOD_DARK = rgb(96, 60, 34)
local HULL = rgb(120, 64, 38)
local HULL_DARK = rgb(70, 38, 22)
local SAIL = rgb(246, 238, 220)
PirateKit.WATER = rgb(40, 170, 210)

-- Fill the cells of `shape(x, z)` (local, cell grid) with water: a translucent surface over a dark floor.
function PirateKit.water(parent, cf, half, shape, y, depth)
	local m = Core.model(parent, "Water", cf)
	for z = -half, half, 4 do
		local start
		for x = -half, half + 4, 4 do
			local inside = x <= half and shape(x + 2, z + 2)
			if inside and not start then
				start = x
			elseif not inside and start then
				Core.box(
					m,
					cf,
					start,
					y - 0.6,
					z,
					x - start,
					0.6,
					4,
					PirateKit.WATER,
					{ smooth = true, trans = 0.3, collide = false, shadow = false }
				)
				Core.box(m, cf, start, y - depth, z, x - start, 0.4, 4, rgb(20, 90, 120), SMOOTH)
				start = nil
			end
		end
	end
	return m
end

-- A wooden dock on posts: plank deck w x d (top 0.4 above `cf`), bollards and a rope rail on three sides
-- (the -Z end, toward the shore, stays open).
function PirateKit.dock(parent, cf, w, d)
	local m = Core.model(parent, "Dock", cf)
	for z = -d / 2, d / 2 - 1 do
		Core.box(m, cf, -w / 2, 0, z, w, PLATE, 1, (z % 2 == 0) and WOOD or rgb(166, 114, 70), SMOOTH)
	end
	for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
		for z = -d / 2 + 1, d / 2 - 1, 6 do
			Core.centered(m, cf, x, -BRICK * 4, z, 1, BRICK * 4, 1, WOOD_DARK)
			Core.cyl(m, cf, x, PLATE, z, 1, 1.4, WOOD_DARK)
		end
		Core.part(m, cf * CFrame.new(x, 1.6, 0), Vector3.new(0.25, 0.25, d - 2), C.tan, DECOR)
	end
	Core.part(m, cf * CFrame.new(0, 1.6, d / 2 - 0.5), Vector3.new(w - 1, 0.25, 0.25), C.tan, DECOR)
	return m
end

-- A tall striped lighthouse with a gallery and a turning lamp.
function PirateKit.lighthouse(parent, cf)
	local m = Core.model(parent, "Lighthouse", cf)
	Core.centered(m, cf, 0, 0, 0, 12, BRICK * 2, 12, C.lightGray)
	local y = BRICK * 2
	for k = 0, 7 do
		local d = 9 - k * 0.5
		Core.cyl(m, cf, 0, y, 0, d, 4.8, k % 2 == 0 and C.white or C.red)
		y += 4.8
	end
	Core.cyl(m, cf, 0, y, 0, 9, 0.8, C.darkGray)
	for k = 0, 11 do
		local a = k * math.pi / 6
		Core.part(
			m,
			cf * CFrame.new(math.cos(a) * 4.2, y + 1.6, math.sin(a) * 4.2),
			Vector3.new(0.25, 1.8, 0.25),
			C.darkGray,
			DECOR
		)
	end
	y += 0.8
	local lamp = Core.cyl(m, cf, 0, y, 0, 4, 4, rgb(255, 240, 180), { neon = true })
	Core.light(lamp, rgb(255, 230, 160), 40, 2)
	local beam = Core.model(m, "Beam", cf * CFrame.new(0, y + 2, 0))
	Core.part(
		beam,
		cf * CFrame.new(0, y + 2, -9),
		Vector3.new(2, 1.6, 14),
		rgb(255, 245, 200),
		{ neon = true, trans = 0.7, collide = false, shadow = false }
	)
	beam:SetAttribute("Speed", 0.8)
	Core.tag(beam, "Spin")
	Core.cyl(m, cf, 0, y + 4, 0, 5.4, 1, C.red)
	Core.cyl(m, cf, 0, y + 5, 0, 3.4, 1.2, C.red)
	Core.ball(m, cf, 0, y + 6.6, 0, 1.2, C.gold)
	return m
end

-- The harbour arch: two rope-wrapped timber posts, a plank sign and an anchor.
function PirateKit.arch(parent, cf, title, w)
	local m = Core.model(parent, "HarbourArch", cf)
	for _, sx in { -1, 1 } do
		Core.cyl(m, cf, sx * (w / 2), 0, 0, 2, BRICK * 11, WOOD_DARK)
		for k = 1, 3 do
			Core.cyl(m, cf, sx * (w / 2), k * 3.4, 0, 2.3, 0.5, C.tan)
		end
	end
	Core.centered(m, cf, 0, BRICK * 11, 0, w + 4, BRICK, 1.6, WOOD_DARK)
	local sign = Core.part(m, cf * CFrame.new(0, BRICK * 9.4, -0.6), Vector3.new(w - 2, BRICK * 2.2, 0.5), WOOD, SMOOTH)
	Core.label(sign, title, Enum.NormalId.Front, C.white, WOOD_DARK)
	local anchor = cf * CFrame.new(0, BRICK * 12.6, -0.9)
	Core.part(m, anchor, Vector3.new(0.6, 3.4, 0.4), C.darkGray, SMOOTH)
	Core.part(m, anchor * CFrame.new(0, -1.5, 0), Vector3.new(3, 0.5, 0.4), C.darkGray, SMOOTH)
	Core.part(
		m,
		anchor * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.4, 1.2, 1.2),
		C.darkGray,
		{ shape = Enum.PartType.Cylinder, smooth = true }
	)
	return m
end

-- The galleon, bow toward -Z, floating with its deck `deckY` above `cf`. Layered hull with a pointed bow,
-- cannon ports, a stern castle with lit windows, three masts with swaying sails and a skull flag.
-- Returns the model, the deck-centre CFrame and the stern castle roof CFrame.
function PirateKit.galleon(parent, cf, deckY, len)
	local m = Core.model(parent, "Galleon", cf)
	local layers = { { 16, -2.4, HULL_DARK }, { 22, 0.6, HULL }, { 26, 3.6, HULL }, { 26, 6.6, HULL_DARK } }
	for i, l in layers do
		local w, y0, color = l[1], l[2], l[3]
		local h = i == #layers and deckY - y0 or 3
		local body = len - 8 - (#layers - i) * 2
		Core.part(m, cf * CFrame.new(0, y0 + h / 2, 4), Vector3.new(w, h, body), color, SMOOTH)
		-- Bow: the hull narrows in steps to a point.
		for k = 1, 4 do
			local bw = w * (1 - k / 5)
			Core.part(
				m,
				cf * CFrame.new(0, y0 + h / 2 + (k % 2) * 0.03, 4 - body / 2 - (k - 0.5) * 2.5),
				Vector3.new(bw, h, 2.6),
				color,
				SMOOTH
			)
		end
	end
	Core.part(m, cf * CFrame.new(0, 4.6, 4), Vector3.new(26.2, 0.6, len - 8), C.gold, DECOR) -- gold stripe
	local deck = cf * CFrame.new(0, deckY, 4)
	for z = -(len - 8) / 2, (len - 8) / 2 - 1.5, 1.5 do
		Core.part(
			m,
			deck * CFrame.new(0, 0.2, z + 0.75),
			Vector3.new(24.4, 0.4, 1.5),
			(math.floor(z / 1.5) % 2 == 0) and WOOD or rgb(166, 114, 70),
			SMOOTH
		)
	end
	-- Rails.
	for _, sx in { -1, 1 } do
		Core.part(m, deck * CFrame.new(sx * 12.6, 1.6, 0), Vector3.new(0.5, 0.4, len - 8), WOOD_DARK, SMOOTH)
		for z = -(len - 8) / 2 + 1, (len - 8) / 2 - 1, 4 do
			Core.part(m, deck * CFrame.new(sx * 12.6, 0.9, z), Vector3.new(0.4, 1.4, 0.4), WOOD_DARK, SMOOTH)
		end
		-- Cannons out of the ports.
		for z = -20, 20, 8 do
			Core.part(
				m,
				cf * CFrame.new(sx * 13.4, 5.2, 4 + z) * CFrame.Angles(0, 0, 0),
				Vector3.new(1.2, 1, 1),
				C.black,
				SMOOTH
			)
			Core.part(
				m,
				cf * CFrame.new(sx * 14.4, 5.2, 4 + z),
				Vector3.new(2.2, 0.8, 0.8),
				C.black,
				{ shape = Enum.PartType.Cylinder, smooth = true, collide = false }
			)
		end
	end
	-- Stern castle with lit windows and lanterns.
	local stern = deck * CFrame.new(0, 0, (len - 8) / 2 - 7)
	Core.part(m, stern * CFrame.new(0, 3.6, 0), Vector3.new(26, 7.2, 14), HULL, SMOOTH)
	for k = -2, 2 do
		Core.part(
			m,
			stern * CFrame.new(k * 4.4, 4.2, -7.05),
			Vector3.new(2.4, 2.4, 0.2),
			rgb(255, 210, 120),
			{ neon = true, collide = false }
		)
		Core.part(
			m,
			stern * CFrame.new(k * 4.4, 4.2, 7.05),
			Vector3.new(2.4, 2.4, 0.2),
			rgb(255, 210, 120),
			{ neon = true, collide = false }
		)
	end
	Core.part(m, stern * CFrame.new(0, 7.4, 0), Vector3.new(26.4, 0.4, 14.4), WOOD, SMOOTH)
	for _, sx in { -1, 1 } do
		K.Build.lanternPaper(m, stern * CFrame.new(sx * 12.5, 10, 7.5), C.orange)
	end
	-- Masts, yards and sails.
	local masts = { { -24, 30 }, { 14, 36 } }
	for _, ms in masts do
		local base = deck * CFrame.new(0, 0, ms[1])
		Core.cyl(m, base, 0, 0, 0, 1.6, ms[2], WOOD_DARK)
		for k, frac in { 0.45, 0.8 } do
			local y = ms[2] * frac
			Core.part(
				m,
				base * CFrame.new(0, y, 0),
				Vector3.new(22 - k * 4, 0.6, 0.6),
				WOOD_DARK,
				{ shape = Enum.PartType.Cylinder, smooth = true }
			)
			local hinge = base * CFrame.new(0, y - 0.4, 0.4)
			local h = ms[2] * 0.3
			local sail = Core.part(
				m,
				hinge * CFrame.new(0, -h / 2, 0),
				Vector3.new(20 - k * 4, h, 0.3),
				SAIL,
				{ smooth = true, collide = false, tag = "Banner" }
			)
			sail:SetAttribute("Hinge", hinge)
			sail:SetAttribute("Amp", 0.04)
			local stripe = Core.part(
				m,
				hinge * CFrame.new(0, -h / 2, -0.2),
				Vector3.new(20 - k * 4, h * 0.3, 0.1),
				C.red,
				{ smooth = true, collide = false, tag = "Banner" }
			)
			stripe:SetAttribute("Hinge", hinge)
			stripe:SetAttribute("Amp", 0.04)
		end
		Core.cyl(m, base, 0, ms[2] * 0.9, 0, 3, 1, WOOD) -- crow's nest
	end
	local flagHinge = deck * CFrame.new(0, 36 + 1, 14)
	local flag = Core.part(
		m,
		flagHinge * CFrame.new(2.4, -1.4, 0),
		Vector3.new(4.8, 2.8, 0.15),
		C.black,
		{ smooth = true, collide = false, tag = "Banner" }
	)
	flag:SetAttribute("Hinge", flagHinge)
	local skull = Core.part(
		m,
		flagHinge * CFrame.new(2.4, -1.3, -0.12),
		Vector3.new(1.2, 1.2, 0.05),
		C.white,
		{ smooth = true, collide = false, tag = "Banner" }
	)
	skull:SetAttribute("Hinge", flagHinge)
	return m, deck * CFrame.new(0, 0.4, 0), stern * CFrame.new(0, 7.6, 0)
end

return PirateKit
