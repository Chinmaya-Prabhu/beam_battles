-- The Summit dragon: a brick dragon coiled up a tower (docs/WORLD_PLAN.md §8). Built in layers so it reads
-- sculpted, not flat: every body segment has one clean jade core and back ridge, a gold belly plate and
-- (every third) a darker ring; bold two-tone dorsal spines run its length. Four jointed,
-- clawed legs grip inward. The head is stacked plates: skull, heavy brows over glowing slit eyes (no
-- eyeballs), layered cheeks and snout, flared nostrils, an open toothed jaw, ringed horns, ear frills, a
-- double mane and a beard, with a glowing pearl before the jaws. Whiskers sway and the pearl floats.
local Core = require(script.Parent.Core)
local Bricks = require(game:GetService("ReplicatedStorage").Shared.Bricks)

local Dragon = {}
local C = Bricks.C

local JADE = Color3.fromRGB(46, 156, 96)
local JADE_DARK = Color3.fromRGB(24, 104, 64)
local JADE_DEEP = Color3.fromRGB(16, 76, 48)
local JADE_LIGHT = Color3.fromRGB(104, 196, 124)
local BELLY = Color3.fromRGB(240, 196, 80)
local BELLY_DARK = Color3.fromRGB(196, 146, 46)
local SPINE = Color3.fromRGB(214, 48, 36)
local SPINE_LIGHT = Color3.fromRGB(250, 128, 40)
local HORN = Color3.fromRGB(246, 226, 170)
local HORN_DARK = Color3.fromRGB(196, 166, 110)
local EYE = Color3.fromRGB(255, 200, 40)

local SMOOTH = { smooth = true }
local DECOR = { smooth = true, collide = false }
local WEDGE = { class = "WedgePart", smooth = true, collide = false }

-- Body thickness along the coil (0 = tail tip, 1 = neck).
local function thickness(t)
	if t < 0.18 then
		return 1.4 + t / 0.18 * 2.6
	end
	return 4 - math.max(0, t - 0.85) / 0.15 * 0.7
end

-- One body segment, layered. `frame` looks along the body (toward the head).
local function segment(m, frame, th, len, i)
	local bump = (i % 2) * 0.06 -- neighbours differ a hair so overlapping joints never share faces
	local h = th * 0.85
	Core.part(m, frame, Vector3.new(th + bump, h + bump, len + 0.35), JADE, SMOOTH)
	-- Back ridge.
	Core.part(
		m,
		frame * CFrame.new(0, h / 2 + 0.17, 0),
		Vector3.new(th * 0.6 + bump, 0.35, len + 0.1),
		JADE,
		SMOOTH
	)
	Core.part(
		m,
		frame * CFrame.new(0, h / 2 + 0.42, 0),
		Vector3.new(th * 0.3 + bump, 0.2, len - 0.2),
		JADE_DEEP,
		SMOOTH
	)
	-- Gold belly plate (the gaps between plates read as segment grooves).
	Core.part(
		m,
		frame * CFrame.new(0, -h / 2 - 0.17, 0),
		Vector3.new(th * 0.72, 0.35 + bump, len * 0.82),
		BELLY,
		SMOOTH
	)
	Core.part(m, frame * CFrame.new(0, -h / 2 - 0.37, 0), Vector3.new(th * 0.4, 0.15, len * 0.6), BELLY_DARK, DECOR)
	-- A darker ring every third segment.
	if i % 3 == 1 and th > 2 then
		Core.part(m, frame * CFrame.new(0, 0, len / 2 - 0.25), Vector3.new(th + 0.3, h + 0.3, 0.45), JADE_DEEP, DECOR)
	end
	-- Two-tone dorsal spines, leaning back toward the tail.
	if i % 2 == 0 and th > 1.8 then
		local sh = 0.9 + th * 0.4
		Core.part(
			m,
			frame * CFrame.new(0, h / 2 + 0.52 + sh / 2, 0.1) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(0.9, sh, 1.8),
			SPINE,
			WEDGE
		)
		Core.part(
			m,
			frame * CFrame.new(0, h / 2 + 0.52 + sh * 0.3, 1.2) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(0.6, sh * 0.6, 1.1),
			SPINE_LIGHT,
			WEDGE
		)
	end
end

-- A jointed leg from `hip` reaching toward the tower and down, ending in a paw with three claws.
local function leg(m, hip, inward)
	local elbow = hip + inward * 2.4 + Vector3.new(0, 0.6, 0)
	local foot = elbow + inward * 2.2 - Vector3.new(0, 3, 0)
	for _, seg in { { hip, elbow, 1.7 }, { elbow, foot, 1.3 } } do
		local a, b, w = seg[1], seg[2], seg[3]
		local f = CFrame.lookAt((a + b) / 2, b)
		Core.part(m, f, Vector3.new(w, w, (b - a).Magnitude + 0.5), JADE, SMOOTH)
		Core.part(
			m,
			f * CFrame.new(0, w / 2 + 0.1, 0),
			Vector3.new(w * 0.7, 0.2, (b - a).Magnitude * 0.7),
			JADE_LIGHT,
			DECOR
		)
		Core.part(
			m,
			f * CFrame.new(0, -w / 2 - 0.1, 0),
			Vector3.new(w * 0.6, 0.2, (b - a).Magnitude * 0.7),
			BELLY,
			DECOR
		)
	end
	Core.part(m, CFrame.new(elbow), Vector3.one * 1.9, JADE, SMOOTH)
	Core.part(m, CFrame.new(elbow + Vector3.new(0, 0.9, 0)), Vector3.new(0.5, 1.4, 0.5), SPINE, DECOR)
	local paw = CFrame.lookAt(foot, foot + inward)
	Core.part(m, paw, Vector3.new(2.2, 1, 1.8), JADE, SMOOTH)
	Core.part(m, paw * CFrame.new(0, 0.55, 0.1), Vector3.new(1.8, 0.25, 1.4), JADE_DARK, DECOR)
	for k = -1, 1 do
		Core.part(m, paw * CFrame.new(k * 0.7, 0, -0.9), Vector3.new(0.6, 0.7, 0.6), JADE_DARK, DECOR)
		Core.part(
			m,
			paw * CFrame.new(k * 0.7, -0.25, -1.6) * CFrame.Angles(math.rad(-35), 0, 0),
			Vector3.new(0.35, 0.5, 1.3),
			HORN,
			WEDGE
		)
	end
end

-- base: CFrame at the tower's base centre. opts: radius, y0, y1 (heights above base), turns, faceDeg
-- (angle from +X toward +Z where the head comes out; the head faces straight out from the tower), headScale.
function Dragon.coil(parent, base, opts)
	local m = Core.model(parent, "Dragon", base)
	local radius, y0, y1 = opts.radius or 20, opts.y0 or 4, opts.y1 or 40
	local turns = opts.turns or 2
	local faceA = math.rad(opts.faceDeg or 90)
	local function point(t)
		local a = faceA - turns * math.pi * 2 * (1 - t)
		local y = y0 + (y1 - y0) * t
		return base * Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
	end
	local arc = turns * math.pi * 2 * radius
	local n = math.floor(arc / 2.6)
	local body = Core.model(m, "Body", base)
	local legsAt = {
		[math.floor(n * 0.3)] = true,
		[math.floor(n * 0.4)] = true,
		[math.floor(n * 0.74)] = true,
		[math.floor(n * 0.84)] = true,
	}
	for i = 0, n - 1 do
		local t0, t1 = i / n, (i + 1) / n
		local p0, p1 = point(t0), point(t1)
		local mid = (p0 + p1) / 2
		local th = thickness((t0 + t1) / 2)
		segment(body, CFrame.lookAt(mid, p1), th, (p1 - p0).Magnitude, i)
		if legsAt[i] then
			local inward = (Vector3.new(base.X, mid.Y, base.Z) - mid).Unit
			leg(body, mid + inward * (th / 2 - 0.3), inward)
		end
	end
	-- Tail: a fan of red fins at the tip.
	local tailFrame = CFrame.lookAt(point(0), point(1 / n))
	for k = -2, 2 do
		local f = tailFrame * CFrame.new(0, 0.2, 0.8) * CFrame.Angles(math.rad(k * 20), 0, 0) * CFrame.new(0, 0, 1.4)
		Core.part(m, f, Vector3.new(0.3, 1.4, 2.8), k % 2 == 0 and SPINE or SPINE_LIGHT, DECOR)
	end
	-- Neck rising out of the coil, then the head facing straight out.
	local neckBase = point(1)
	local outWorld = base:VectorToWorldSpace(Vector3.new(math.cos(faceA), 0, math.sin(faceA)))
	local neck = {
		neckBase,
		neckBase + outWorld * 1.6 + Vector3.new(0, 2.8, 0),
		neckBase + outWorld * 3.6 + Vector3.new(0, 5.2, 0),
	}
	for k = 1, #neck - 1 do
		local a, b = neck[k], neck[k + 1]
		segment(m, CFrame.lookAt((a + b) / 2, b), 3.4, (b - a).Magnitude, k + 1)
	end
	local headPos = neck[#neck] + outWorld * 2.6 + Vector3.new(0, 1, 0)
	Dragon.head(m, CFrame.lookAt(headPos, headPos + outWorld * 10 - Vector3.new(0, 1, 0)), opts.headScale or 1.35)
	return m
end

-- The head, built in a frame looking along -Z, then scaled.
function Dragon.head(parent, F, scale)
	local m = Core.model(parent, "Head", F)
	local function p(x, y, z, sx, sy, sz, color, opts, rot)
		return Core.part(
			m,
			F * CFrame.new(x, y, z) * (rot or CFrame.identity),
			Vector3.new(sx, sy, sz),
			color,
			opts or SMOOTH
		)
	end
	-- Skull in stacked layers.
	p(0, 0, 0.2, 4.4, 3.4, 4.6, JADE)
	p(0, 1.9, 0.4, 3.8, 0.4, 4, JADE_DARK)
	p(0, 2.25, 0.7, 2.8, 0.3, 3.2, JADE)
	p(0, 2.5, 1.1, 1.4, 0.25, 2.2, JADE_DEEP)
	-- Crest spikes along the top of the skull.
	for k = 0, 2 do
		p(0, 2.95 + k * 0.05, 1.6 - k * 1.1, 0.4, 0.9 - k * 0.15, 1.2, SPINE, WEDGE, CFrame.Angles(0, math.pi, 0))
	end
	-- Heavy brows angled down toward the centre, over slit eyes in dark sockets (no eyeballs).
	for _, sx in { -1, 1 } do
		p(sx * 1.35, 1.45, -1.95, 1.9, 0.95, 1.7, JADE_DARK, SMOOTH, CFrame.Angles(0, 0, sx * math.rad(14)))
		p(sx * 1.35, 1.98, -1.75, 1.5, 0.3, 1.3, JADE_LIGHT, DECOR, CFrame.Angles(0, 0, sx * math.rad(14)))
		p(sx * 2.21, 0.72, -1.85, 0.1, 0.75, 1.9, C.black, DECOR, CFrame.Angles(sx * math.rad(-8), 0, 0))
		p(
			sx * 2.27,
			0.74,
			-1.9,
			0.1,
			0.24,
			1.45,
			EYE,
			{ material = Enum.Material.Neon, collide = false },
			CFrame.Angles(sx * math.rad(-8), 0, 0)
		)
	end
	-- Layered cheeks with backward spikes, and ear frills.
	for _, sx in { -1, 1 } do
		p(sx * 2.45, -0.5, -0.5, 0.6, 1.7, 2.6, JADE_DARK)
		p(sx * 2.8, -0.55, -0.2, 0.3, 1.2, 1.9, JADE_LIGHT, DECOR)
		for k = 0, 1 do
			p(sx * 2.7, -1 + k * 0.6, 1.2 + k * 0.4, 0.4, 0.6, 1.4, JADE_LIGHT, WEDGE)
		end
		for k = -1, 1 do
			local f = CFrame.Angles(math.rad(k * 22), sx * math.rad(35), 0) * CFrame.new(0, 0, 1)
			p(sx * 2.3, 1, 1.7, 0.25, 1.4, 2, k == 0 and SPINE or SPINE_LIGHT, DECOR, f)
		end
	end
	-- Snout: base, upper layer, nose ridge, tapered tip, nose pad and flared nostrils.
	p(0, -0.35, -3.9, 3.4, 2.2, 3.2, JADE)
	p(0, 0.95, -3.8, 2.6, 0.4, 3.4, JADE_LIGHT)
	p(0, 1.3, -3.6, 1, 0.3, 3, JADE_DARK)
	p(0, -0.25, -6, 3, 1.8, 1.2, JADE)
	p(0, 0.55, -6.55, 3.3, 1, 0.8, JADE_DARK)
	for _, sx in { -1, 1 } do
		p(sx * 0.95, 0.75, -6.85, 0.95, 0.75, 0.6, JADE)
		p(sx * 0.95, 0.75, -7.18, 0.45, 0.4, 0.1, C.black, DECOR)
		p(sx * 1.73, -1.05, -4.3, 0.2, 0.5, 4.4, JADE_DEEP, DECOR) -- lip line
	end
	-- Upper teeth along the front and sides.
	for _, t in { { -1.2, -6.1 }, { -0.4, -6.4 }, { 0.4, -6.4 }, { 1.2, -6.1 }, { -1.5, -5 }, { 1.5, -5 } } do
		p(t[1], -1.4, t[2], 0.4, 0.65, 0.5, C.white, WEDGE, CFrame.Angles(math.pi, 0, 0))
	end
	-- Open lower jaw: layered, toothed, gold underneath, forked tongue.
	local hinge = F * CFrame.new(0, -1.25, -1.4) * CFrame.Angles(math.rad(-22), 0, 0)
	local function j(x, y, z, sx, sy, sz, color, opts, rot)
		return Core.part(
			m,
			hinge * CFrame.new(x, y, z) * (rot or CFrame.identity),
			Vector3.new(sx, sy, sz),
			color,
			opts or SMOOTH
		)
	end
	j(0, -0.4, -2.5, 2.9, 0.8, 5, JADE_DARK)
	j(0, -0.95, -2.3, 2.3, 0.35, 4.4, BELLY)
	j(0, -0.6, -5.1, 1.8, 0.9, 0.8, JADE)
	j(0, 0.05, -2.3, 1.4, 0.15, 3.4, SPINE, DECOR)
	for _, sx in { -1, 1 } do
		j(sx * 0.35, 0.05, -4.3, 0.4, 0.15, 0.9, SPINE, DECOR, CFrame.Angles(0, sx * math.rad(20), 0))
		for _, z in { -4.4, -3.2 } do
			j(sx * 1.15, 0.3, z, 0.4, 0.6, 0.5, C.white, WEDGE)
		end
	end
	-- Beard: gold strands under the chin.
	for k = -1, 1 do
		j(k * 0.6, -1.9, -4.6, 0.3, 2, 0.3, BELLY, DECOR, CFrame.Angles(math.rad(-15), 0, math.rad(k * 10)))
	end
	-- Ringed horns sweeping back and up.
	for _, sx in { -1, 1 } do
		local f = F * CFrame.new(sx * 1.4, 2, 0.6) * CFrame.Angles(math.rad(32), sx * math.rad(-14), 0)
		for k, size in { 0.95, 0.75, 0.55 } do
			local len = 2 - k * 0.3
			Core.part(m, f * CFrame.new(0, 0, len / 2), Vector3.new(size, size, len), HORN, SMOOTH)
			Core.part(m, f * CFrame.new(0, 0, 0.15), Vector3.new(size + 0.2, size + 0.2, 0.3), HORN_DARK, DECOR)
			f = f * CFrame.new(0, 0, len) * CFrame.Angles(math.rad(18), 0, 0)
		end
	end
	-- Double mane fanning from the back of the head.
	for k = 0, 6 do
		local a = math.rad(-90 + k * 30)
		local f = F
			* CFrame.new(math.cos(a) * 2.1, math.sin(a) * 1.7 + 0.4, 2.3)
			* CFrame.Angles(0, 0, a)
			* CFrame.Angles(math.rad(-35), 0, 0)
		Core.part(m, f * CFrame.new(0, 0, 1.1), Vector3.new(0.5, 1.7, 2.6), SPINE, WEDGE)
		if k > 0 and k < 6 then
			local g = F
				* CFrame.new(math.cos(a) * 1.5, math.sin(a) * 1.2 + 0.4, 2.6)
				* CFrame.Angles(0, 0, a)
				* CFrame.Angles(math.rad(-30), 0, 0)
			Core.part(m, g * CFrame.new(0, 0, 0.8), Vector3.new(0.4, 1.2, 1.8), SPINE_LIGHT, WEDGE)
		end
	end
	-- The glowing pearl held before the jaws.
	local pearl = p(
		0,
		-2.3,
		-8.4,
		2.4,
		2.4,
		2.4,
		Color3.fromRGB(255, 244, 200),
		{ shape = Enum.PartType.Ball, neon = true, collide = false, tag = "Bob" }
	)
	Core.light(pearl, Color3.fromRGB(255, 220, 140), 22, 1.6)
	Core.particles(pearl, {
		color = Color3.fromRGB(255, 240, 180),
		size = 0.3,
		rate = 8,
		life = { 1, 2 },
		speed = 1.2,
		spread = 180,
		lightEmission = 1,
	})
	-- Whiskers trailing back and down from the snout.
	local whiskers = {}
	for _, sx in { -1, 1 } do
		local root = F * CFrame.new(sx * 1.75, -0.35, -5.4)
		local w = p(0, 0, 0, 0.25, 0.25, 7, BELLY, DECOR)
		w.CFrame = root * CFrame.Angles(math.rad(24), sx * math.rad(38), 0) * CFrame.new(0, 0, 3.5)
		table.insert(whiskers, w)
	end
	m:ScaleTo(scale or 1)
	-- Hinges are set after scaling, at each whisker's root end.
	for _, w in whiskers do
		w:SetAttribute("Hinge", w.CFrame * CFrame.new(0, 0, -w.Size.Z / 2))
		w:SetAttribute("Amp", 0.08)
		w:SetAttribute("Speed", 1.1)
		Core.tag(w, "Banner")
	end
	return m
end

return Dragon
