-- Walled City's own pieces (docs/WORLD_PLAN.md §4, zone 4): a medieval town inside a giant circular wall,
-- under grey skies, with a titan peering over the wall. Grey stone, timber-frame houses, red roofs, green
-- banners. Frames face their front along -Z.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local K = require(script.Parent.Parent.BrickKit)

local WalledKit = {}
local C = Bricks.C
local Core = K.Core
local BRICK = Core.BRICK
local SMOOTH = { smooth = true }
local DECOR = { smooth = true, collide = false }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local STONE = { rgb(168, 170, 168), rgb(148, 150, 150), rgb(182, 180, 172) }
local STONE_DARK = rgb(110, 112, 114)
local TIMBER = rgb(70, 46, 30)

-- The ring wall round `cf` (centre, on the ground): radius r (centre line), thickness t, height h, with
-- merlons on top. Angles (degrees from +X toward +Z) inside any of `gaps` = { {from, to} } are left open.
function WalledKit.ringWall(parent, cf, r, t, h, gaps)
	local m = Core.model(parent, "RingWall", cf)
	local n = math.floor(2 * math.pi * r / 6)
	local seg = 2 * math.pi * r / n
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local deg = math.deg(a)
		local open = false
		for _, g in gaps or {} do
			if deg > g[1] and deg < g[2] then
				open = true
			end
		end
		if not open then
			local bump = (i % 2) * 0.06
			local p = cf * Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			-- Frame: -Z along the wall, +X toward the centre (inside), -X outside.
			local frame = CFrame.lookAt(p, p + cf:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a))))
			Core.part(
				m,
				frame * CFrame.new(0, h / 2, 0),
				Vector3.new(t + bump, h + bump, seg + 0.3),
				STONE[i % #STONE + 1]
			)
			Core.part(
				m,
				frame * CFrame.new(0, 1.2 + bump / 2, 0),
				Vector3.new(t + 0.6 + bump, 2.4 + bump, seg + 0.3),
				STONE_DARK,
				SMOOTH
			)
			-- Masonry: raised blocks in a checker of courses on both faces, a capping band under the merlons.
			local rowH = BRICK * 2.5
			for k = 0, math.floor((h - 4.4) / rowH) - 1 do
				for _, s in { -1, 1 } do
					if (i + k + (s > 0 and 1 or 0)) % 2 == 0 then
						Core.part(
							m,
							frame * CFrame.new(s * ((t + bump) / 2 + 0.1), 2.6 + (k + 0.5) * rowH, 0),
							Vector3.new(0.4, rowH - 0.3, seg * 0.92),
							STONE[(i + k) % #STONE + 1],
							DECOR
						)
					end
				end
			end
			Core.part(
				m,
				frame * CFrame.new(0, h - 1.2, 0),
				Vector3.new(t + 0.8 + bump, 1 + bump, seg + 0.3),
				STONE_DARK,
				SMOOTH
			)
			-- Buttresses on the outer face.
			if i % 5 == 0 then
				Core.part(m, frame * CFrame.new(-(t / 2 + 1.2), h * 0.35, 0), Vector3.new(2.4, h * 0.7, 3), STONE_DARK)
				Core.part(
					m,
					frame * CFrame.new(-(t / 2 + 0.7), h * 0.8, 0),
					Vector3.new(1.4, h * 0.2, 2.4),
					STONE_DARK,
					SMOOTH
				)
			end
			Core.part(
				m,
				frame * CFrame.new(-t / 2 + 0.5, h + 1.2, 0),
				Vector3.new(1, 2.4, seg * 0.5),
				STONE[(i + 1) % #STONE + 1]
			)
		end
	end
	return m
end

-- The gatehouse: twin square towers with crenels and slate cone roofs, an arch over the opening with a
-- raised portcullis and the city's name. `w` is the opening, h the wall height.
function WalledKit.gatehouse(parent, cf, title, w, h)
	local m = Core.model(parent, "Gatehouse", cf)
	for _, sx in { -1, 1 } do
		local x = sx * (w / 2 + 6)
		Core.centered(m, cf, x, 0, 0, 12, h + 8, 12, STONE[1])
		Core.centered(m, cf, x, 0, 0, 12.6, 2.4, 12.6, STONE_DARK, SMOOTH)
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			Core.centered(m, cf, x + c[1] * 5, h + 8, c[2] * 5, 2, 2.4, 2, STONE[2])
		end
		K.Build.roof(m, cf * CFrame.new(x, h + 10.4, 0), 10, 10, {
			colors = { rgb(70, 76, 92), rgb(90, 96, 112), rgb(110, 116, 130) },
			trim = STONE_DARK,
			finial = true,
			brackets = false,
		})
		for k = 0, 1 do
			Core.part(m, cf * CFrame.new(x, h - 4 - k * 10, -6.05), Vector3.new(1.2, 3, 0.2), C.black, DECOR)
		end
	end
	Core.centered(m, cf, 0, h - 8, 0, w + 2, 8, 10, STONE[2])
	local sign = Core.part(m, cf * CFrame.new(0, h - 4, -5.1), Vector3.new(w - 2, 3, 0.4), STONE_DARK, SMOOTH)
	Core.label(sign, title, Enum.NormalId.Front, C.white, C.black)
	-- Raised portcullis bars.
	for x = -w / 2 + 1, w / 2 - 1, 1.6 do
		Core.part(m, cf * CFrame.new(x, h - 10.5, -3), Vector3.new(0.3, 5, 0.3), C.darkGray, DECOR)
	end
	Core.part(m, cf * CFrame.new(0, h - 12.8, -3), Vector3.new(w, 0.4, 0.4), C.darkGray, DECOR)
	return m
end

-- A timber-frame town house: plaster between dark beams with cross braces, lit windows, a steep red roof
-- and a chimney. `storeys` 1 or 2; w along X, d along Z.
function WalledKit.house(parent, cf, set, w, d, storeys)
	local m = Core.model(parent, "House", cf)
	local h = BRICK * 5 * storeys
	Core.centered(m, cf, 0, 0, 0, w + 1, BRICK, d + 1, STONE_DARK)
	Core.centered(m, cf, 0, BRICK, 0, w, h, d, set.plaster)
	for side = 0, 3 do
		local f = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		local along = side % 2 == 0 and w or d
		local across = side % 2 == 0 and d or w
		for x = -along / 2, along / 2 + 0.01, along / 3 do
			Core.part(m, f * CFrame.new(x, BRICK + h / 2, -across / 2 - 0.1), Vector3.new(0.6, h, 0.2), TIMBER, DECOR)
		end
		for s = 0, storeys do
			Core.part(
				m,
				f * CFrame.new(0, BRICK + s * BRICK * 5 - (s == storeys and 0.3 or 0), -across / 2 - 0.12),
				Vector3.new(along, 0.6, 0.2),
				TIMBER,
				DECOR
			)
		end
		for s = 0, storeys - 1 do
			local y = BRICK + s * BRICK * 5 + BRICK * 2.5
			if side == 0 and s == 0 then
				Core.part(
					m,
					f * CFrame.new(0, BRICK + 2.2, -across / 2 - 0.08),
					Vector3.new(2.6, 4.4, 0.2),
					TIMBER,
					DECOR
				)
			else
				Core.part(
					m,
					f * CFrame.new(along / 6, y, -across / 2 - 0.08),
					Vector3.new(1.8, 2, 0.15),
					rgb(255, 210, 130),
					{ neon = true, collide = false }
				)
				Core.part(
					m,
					f * CFrame.new(-along / 6, y, -across / 2 - 0.15) * CFrame.Angles(0, 0, math.rad(40)),
					Vector3.new(0.4, BRICK * 5 * 0.9, 0.15),
					TIMBER,
					DECOR
				)
			end
		end
	end
	K.Build.gable(m, cf * CFrame.new(0, BRICK + h, 0), w + 2, d + 2, BRICK * 4, set.roof, TIMBER)
	Core.centered(m, cf, w / 4, BRICK + h, d / 6, 1.6, BRICK * 5, 1.6, STONE_DARK)
	return m
end

-- The castle keep: a tall square tower with corner turrets, crenels, slate cones and green banners.
function WalledKit.keep(parent, cf, set, s, h)
	local m = Core.model(parent, "Keep", cf)
	Core.centered(m, cf, 0, 0, 0, s + 4, BRICK * 2, s + 4, STONE_DARK)
	Core.centered(m, cf, 0, BRICK * 2, 0, s, h, s, STONE[1])
	for k = 1, 3 do
		Core.centered(m, cf, 0, BRICK * 2 + k * h / 4, 0, s + 0.6, 0.8, s + 0.6, STONE_DARK, SMOOTH)
	end
	Core.part(m, cf * CFrame.new(0, BRICK * 2 + 5, -s / 2 - 0.1), Vector3.new(6, 10, 0.3), TIMBER, SMOOTH)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local t = cf * CFrame.new(c[1] * s / 2, 0, c[2] * s / 2)
		Core.cyl(m, t, 0, 0, 0, 6, h + BRICK * 6, STONE[2])
		K.Build.roof(m, t * CFrame.new(0, h + BRICK * 6, 0), 8, 8, {
			colors = { rgb(70, 76, 92), rgb(90, 96, 112), rgb(110, 116, 130) },
			trim = STONE_DARK,
			finial = true,
			brackets = false,
		})
	end
	for x = -s / 2 + 2, s / 2 - 2, 4 do
		for _, z in { -s / 2 + 0.5, s / 2 - 0.5 } do
			Core.centered(m, cf, x, BRICK * 2 + h, z, 2, 2.4, 1, STONE[2])
		end
	end
	for _, x in { -s / 4, s / 4 } do
		K.Build.banner(m, cf * CFrame.new(x, BRICK * 2 + h, 0), 12, set.accent, C.gold)
	end
	for k = -1, 1, 2 do
		local hinge = cf * CFrame.new(k * s / 4, BRICK * 2 + h - 2, -s / 2 - 0.3)
		local cloth = Core.part(
			m,
			hinge * CFrame.new(0, -6, 0),
			Vector3.new(4, 12, 0.2),
			set.accent,
			{ smooth = true, collide = false, tag = "Banner" }
		)
		cloth:SetAttribute("Hinge", hinge)
		cloth:SetAttribute("Amp", 0.05)
	end
	return m
end

-- The titan peering over the wall: a colossal head (grinning teeth, glowing eyes, wild hair) on a neck and
-- shoulders rising from below the island, scaled by `s`. `cf` sits at the wall-top level behind the wall,
-- facing in (-Z). `hands` are CFrames on a ledge edge (facing in) where its hands grip.
function WalledKit.titan(parent, cf, s, hands)
	local m = Core.model(parent, "Titan", cf)
	local skin, skinDark = rgb(214, 160, 130), rgb(176, 120, 96)
	local hair = rgb(60, 40, 30)
	local muscle = rgb(170, 60, 60)
	s = s or 1
	local function p(x, y, z, sx, sy, sz, color, opts)
		return Core.part(m, cf * CFrame.new(x * s, y * s, z * s), Vector3.new(sx, sy, sz) * s, color, opts or SMOOTH)
	end
	-- Neck and shoulders with the exposed-muscle strips.
	p(0, -8, 8, 14, 12, 14, skinDark)
	p(0, -22, 10, 46, 18, 20, skin)
	for _, sx in { -1, 1 } do
		p(sx * 18, -14.3, 10, 10, 3, 16, skin)
		for k = 0, 2 do
			p(sx * (8 + k * 4.5), -18 + (k % 2) * 0.05, -0.1, 2, 10, 0.4, muscle)
		end
	end
	-- Head in layers: a broad cranium, a narrower jaw stepped in at the sides, a chin under it. The face
	-- plane is z = -5; everything on the face stands proud of it in steps.
	p(0, 14, 6, 26, 16, 22, skin) -- cranium
	p(0, 3, 6.1, 22, 10, 21.8, skin) -- jaw
	p(0, -2.5, 0.5, 12, 3, 10, skinDark) -- chin
	p(0, 14, -5.6, 24, 2.6, 1.6, skinDark) -- brow ridge
	p(0, 12.9, -6.5, 2, 2.4, 0.4, skinDark) -- frown furrow
	for _, sx in { -1, 1 } do
		p(sx * 6, 11, -5.2, 6, 3.4, 0.6, C.black) -- eye socket
		p(sx * 6, 11, -5.6, 2.6, 2, 0.3, rgb(110, 255, 140), { neon = true, collide = false }) -- glowing eye
		p(sx * 9, 7.5, -5.5, 6, 3, 1.2, skin) -- cheekbone
		p(sx * 13.2, 9, 6, 1.6, 8, 5, skinDark) -- ear
		p(sx * 13.9, 9, 6.2, 0.6, 5, 3, rgb(150, 96, 78)) -- inner ear
	end
	-- Nose: bridge, a fleshy tip and nostrils.
	p(0, 9.6, -5.7, 2.6, 4.6, 1.6, skin)
	p(0, 6.6, -6.4, 4.4, 2.4, 2.4, skinDark)
	for _, sx in { -1, 1 } do
		p(sx * 1.2, 5.3, -7.4, 1, 0.5, 0.3, C.black)
	end
	-- The famous grin: a dark lip band with upper and lower rows of teeth, stretched cheek muscle at the
	-- corners.
	p(0, 1.6, -5.3, 18, 4.6, 1, rgb(110, 36, 36))
	for k = -7, 7 do
		p(k * 1.15, 2.7, -5.95 - (k % 2) * 0.04, 1, 1.8, 0.3, rgb(246, 240, 226))
		p(k * 1.15, 0.5, -5.95 - (k % 2) * 0.04, 1, 1.6, 0.3, rgb(236, 228, 210))
	end
	for _, sx in { -1, 1 } do
		for j = 0, 2 do
			p(
				sx * (8.8 + j * 0.8),
				2.4 + j * 0.2,
				-5.3 - (j % 2) * 0.05,
				0.6,
				5.4,
				0.6,
				j == 1 and muscle or rgb(196, 86, 86)
			)
		end
	end
	-- Hair: a cap, spikes on top, a ragged fringe over the forehead, sides above the ears and the back.
	p(0, 22.5, 6.5, 27, 3, 23, hair)
	for k = 0, 8 do
		local x = -12 + k * 3
		p(x, 24 + (k % 3), 6 - (k % 2) * 3, 4, 4 + (k % 3) * 2, 18, hair)
	end
	for k = -3, 3 do
		local long = (k % 2) * 1.6
		p(k * 3.5, 19.2 - long / 2, -5.4 - (k % 2) * 0.1, 3, 4 + long, 1.2, hair)
	end
	for _, sx in { -1, 1 } do
		p(sx * 13.6, 18, 6, 1.4, 8, 20, hair)
	end
	p(0, 15, 17.5, 26, 16, 1.2, hair)
	-- Hands (sized for s = 2): the palm hangs outside the wall, the fingers lie across its top and curl
	-- down the inner face with dark nails, a forearm runs down to the shoulder.
	local k = s / 2
	for _, hand in hands or {} do
		local function h(x, y, z, sx, sy, sz, color)
			return Core.part(m, hand * CFrame.new(x * k, y * k, z * k), Vector3.new(sx, sy, sz) * k, color, SMOOTH)
		end
		h(0, -6, 9, 26, 18, 18, skin)
		for f = -1.5, 1.5 do
			local x, lift = f * 6.2, (f % 2) * 0.05
			h(x, 2.6 + lift, -3.5, 5.2, 5.2, 7.5, skin)
			h(x, -2.2 + lift, -8.6, 5.2, 8, 3.2, skin)
			h(x, -5.2, -10.35, 4.4, 2.6, 0.4, skinDark)
		end
		local side = cf:PointToObjectSpace(hand.Position).X > 0 and 1 or -1
		local wrist = (hand * CFrame.new(0, -6 * k, 16 * k)).Position
		local shoulder = (cf * CFrame.new(side * 19 * s, -20 * s, 10 * s)).Position
		Core.part(
			m,
			CFrame.lookAt((wrist + shoulder) / 2, shoulder),
			Vector3.new(14 * k, 14 * k, (shoulder - wrist).Magnitude + 6),
			skin,
			SMOOTH
		)
	end
	return m
end

return WalledKit
