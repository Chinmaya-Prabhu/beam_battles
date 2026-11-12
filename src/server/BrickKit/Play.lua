-- Gameplay pieces: drop altar, guardian podium, teleport pad, zone gate, pedestal, collector fountain.
-- These are the things players move toward, so they carry the zone accent and the only neon on the map.
local Core = require(script.Parent.Core)
local VoxelKit = require(script.Parent.VoxelKit)
local Build = require(script.Parent.Build)
local Terrain = require(script.Parent.Terrain)
local Bricks = require(game:GetService("ReplicatedStorage").Shared.Bricks)

local Play = {}
local BRICK, PLATE = Core.BRICK, Core.PLATE
local C = Bricks.C

-- Neon strips framing a square of side `s` at height y.
local function ring(m, cf, y, s, color, tag)
	for side = 0, 3 do
		local face = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		Core.part(
			m,
			face * CFrame.new(0, y + 0.1, -s / 2 - 0.2),
			-- Two sides run past the corners, two stop short, so the strips never overlap.
			Vector3.new(side % 2 == 0 and s + 0.4 or s, 0.2, 0.4),
			color,
			{ neon = true, collide = false, tag = tag }
		)
	end
end

-- A drop altar: stepped dais in the zone accent, corner crystals and a light pillar to the sky.
-- Returns the model and the CFrame where the prize stands.
-- fire = true puts flaming braziers on the corner pillars instead of crystals (they flare in clashes).
function Play.altar(parent, cf, set, accent, fire)
	accent = accent or set.accent
	local m = Core.model(parent, "Altar", cf)
	Core.centered(m, cf, 0, 0, 0, 16, BRICK, 16, set.stone[#set.stone])
	Core.centered(m, cf, 0, BRICK, 0, 14, BRICK, 14, set.stone[1])
	Core.centered(m, cf, 0, BRICK * 2, 0, 10, BRICK, 10, accent)
	Core.centered(m, cf, 0, BRICK * 3, 0, 7, BRICK, 7, C.lightTan)
	ring(m, cf, BRICK * 3, 7, accent:Lerp(Color3.new(1, 1, 1), 0.3))
	-- Steps on all four sides.
	for side = 0, 3 do
		local face = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		Core.box(m, face, -3, 0, -9, 6, BRICK, 1, set.stone[1])
	end
	-- Corner pillars with floating crystals.
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local x, z = c[1] * 6, c[2] * 6
		Core.centered(m, cf, x, BRICK * 2, z, 2, BRICK * 3, 2, accent)
		Core.centered(m, cf, x, BRICK * 5, z, 2, PLATE, 2, C.gold)
		if fire then
			local bowl = Core.cyl(m, cf, x, BRICK * 5 + PLATE, z, 2.4, 0.8, C.gold)
			bowl.Material = Enum.Material.Metal
			Core.fire(m, bowl.Position + Vector3.new(0, 0.6, 0), 3, 6)
		else
			local crystal = Core.part(
				m,
				cf * CFrame.new(x, BRICK * 5 + 2.2, z) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
				Vector3.new(1.2, 1.2, 1.2),
				accent:Lerp(Color3.new(1, 1, 1), 0.4),
				{ neon = true, collide = false, tag = "Spin" }
			)
			crystal:SetAttribute("Speed", 1.5)
			Core.tag(crystal, "Bob")
		end
	end
	local pillar = Core.cyl(
		m,
		cf,
		0,
		BRICK * 4,
		0,
		5,
		80,
		accent:Lerp(Color3.new(1, 1, 1), 0.5),
		{ neon = true, collide = false, shadow = false, trans = 0.9, tag = "LightPillar" }
	)
	Core.light(pillar, accent, 20, 1)
	if VoxelKit.ready() then
		VoxelKit.altar(m, cf, accent)
	end
	return m, cf * CFrame.new(0, BRICK * 4, 0)
end

-- A clash pad: the battle pedestal a fighter stands on to clash across the altar. `color` is the side's
-- colour. A round two-tier stone dais with a gold trim, a glowing rim and rune emblem in the side colour,
-- a front step, two pillars with floating crystals and swinging banners beside the fighter (not behind,
-- where the clash camera sits), rising sparks and an under-glow. Front (-Z) faces the opponent.
-- Returns the model and the CFrame of the top surface (where the fighter stands).
function Play.clashPad(parent, cf, set, color)
	local m = Core.model(parent, "ClashPad", cf)
	local dark = set.stone[#set.stone]
	local stone = set.stone[1]
	local glow = color:Lerp(Color3.new(1, 1, 1), 0.35)
	-- The dais: a wide base disc, a narrower second tier, a gold band, then the coloured stage.
	Core.cyl(m, cf, 0, 0, 0, 10.5, BRICK, dark)
	Core.cyl(m, cf, 0, BRICK, 0, 9, BRICK, stone)
	local band = Core.cyl(m, cf, 0, BRICK * 2, 0, 8.2, 0.35, C.gold)
	band.Material = Enum.Material.Metal
	local rim = Core.cyl(m, cf, 0, BRICK * 2 + 0.35, 0, 7.6, 0.3, glow, { neon = true })
	local top = BRICK * 2 + 0.65
	Core.cyl(m, cf, 0, BRICK * 2 + 0.35, 0, 7, 0.3 + 0.01, color:Lerp(Color3.new(0, 0, 0), 0.25))
	-- The rune emblem: a ring of eight short strokes and a centre seal, flush with the stage.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Core.part(
			m,
			cf * CFrame.new(math.sin(a) * 2.6, top + 0.03, math.cos(a) * 2.6) * CFrame.Angles(0, a, 0),
			Vector3.new(0.3, 0.06, 1.1),
			glow,
			{ neon = true, collide = false }
		)
	end
	Core.cyl(m, cf, 0, top, 0, 2.2, 0.06, glow, { neon = true, collide = false })
	Core.cyl(m, cf, 0, top + 0.01, 0, 1.5, 0.06, color, { collide = false })
	-- A front step toward the opponent.
	Core.centered(m, cf, 0, 0, -5.4, 4.2, BRICK, 1.6, stone)
	Core.centered(m, cf, 0, BRICK, -4.6, 3.2, BRICK, 1, stone)
	-- Two pillars beside the fighter with floating crystals and banners.
	for _, x in { -4.3, 4.3 } do
		local z = 0.8
		Core.cyl(m, cf, x, BRICK, z, 1.5, 0.5, C.gold, { material = Enum.Material.Metal })
		Core.cyl(m, cf, x, BRICK + 0.5, z, 1.1, BRICK * 4, stone)
		local cap = Core.cyl(m, cf, x, BRICK * 5 + 0.5, z, 1.6, 0.4, C.gold)
		cap.Material = Enum.Material.Metal
		local crystal = Core.part(
			m,
			cf * CFrame.new(x, BRICK * 5 + 2.4, z) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Vector3.new(1.1, 1.1, 1.1),
			glow,
			{ neon = true, collide = false, tag = "Spin" }
		)
		crystal:SetAttribute("Speed", 1.6)
		Core.tag(crystal, "Bob")
		Core.light(crystal, color, 10, 1.2)
		local flag = Core.part(
			m,
			cf * CFrame.new(x + (x > 0 and 0.75 or -0.75), BRICK * 4, z),
			Vector3.new(0.15, 2.4, 1.4),
			color,
			{ smooth = true, collide = false, tag = "Banner" }
		)
		flag:SetAttribute("Hinge", flag.CFrame * CFrame.new(0, 1.2, 0))
	end
	-- Energy rising off the stage, and a glow under the fighter's feet.
	Core.particles(rim, {
		color = glow,
		size = NumberSequence.new(0.45, 0),
		rate = 10,
		life = { 0.8, 1.4 },
		speed = 3,
		spread = 8,
		lightEmission = 1,
	})
	Core.light(rim, color, 12, 1.4)
	if VoxelKit.ready() then
		VoxelKit.pad(m, cf, color, C.gold)
	end
	return m, cf * CFrame.new(0, top, 0)
end

-- The drop portal: a studded ring floating high over the altar grounds with a swirling core.
-- Fighters fall from it on a beam (DropService). `cf` is the ring's centre.
function Play.dropPortal(parent, cf, radius, set)
	local m = Core.model(parent, "DropPortal", cf)
	local ringModel = Core.model(m, "Ring", cf)
	local n = math.floor(radius * 1.6)
	local seg = 2 * math.pi * radius / n
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local at = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		-- Odd segments are a hair bigger so overlapping joints never share a face.
		local bump = (i % 2) * 0.06
		Core.part(
			ringModel,
			at,
			Vector3.new(seg + 0.3, BRICK * 1.5 + bump, 3 + bump),
			i % 2 == 0 and set.accent or C.gold
		)
		Core.part(
			ringModel,
			at * CFrame.new(0, -BRICK, 0.6),
			Vector3.new(seg + 0.3, PLATE * 2 + bump, 1.8 + bump),
			C.black,
			{ smooth = true }
		)
		if i % 4 == 0 then
			Core.slope(
				ringModel,
				at * CFrame.Angles(0, math.pi, 0),
				-0.8,
				0.8,
				-1.5,
				BRICK * 0.75,
				2,
				BRICK * 2,
				C.gold
			)
		end
	end
	Core.tag(ringModel, "Spin")
	ringModel:SetAttribute("Speed", 0.15)
	local swirl = Core.cyl(
		m,
		cf,
		0,
		-0.2,
		0,
		radius * 2 - 2,
		0.3,
		set.accent:Lerp(Color3.new(1, 1, 1), 0.55),
		{ neon = true, trans = 0.55, collide = false, shadow = false, tag = "Spin" }
	)
	swirl:SetAttribute("Speed", -0.6)
	Core.particles(
		swirl,
		{ color = C.white, size = 0.6, rate = 14, life = { 1.5, 2.5 }, speed = 2, spread = 180, lightEmission = 1 }
	)
	Core.light(swirl, set.accent, 40, 2)
	-- Countdown board hanging under the portal; the client writes the time (Ambience, tag "DropCountdown").
	local anchor = Core.part(
		m,
		cf * CFrame.new(0, -10, 0),
		Vector3.one,
		C.gold,
		{ trans = 1, collide = false, name = "CountdownAnchor" }
	)
	Core.tag(anchor, "DropCountdown")
	local board = Instance.new("BillboardGui")
	board.Name = "Countdown"
	board.Size = UDim2.fromScale(40, 10)
	board.LightInfluence = 0
	board.MaxDistance = 1000
	board.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(60, 20, 90)
	text.Text = "NEXT DROP"
	text.Parent = board
	return m
end

-- A guardian podium on the Dojo Ladder with its rung number and a challenge pad in front.
function Play.podium(parent, cf, rung, set, noPad)
	local m = Core.model(parent, "Podium", cf)
	Core.centered(m, cf, 0, 0, 0, 10, BRICK, 10, set.stone[#set.stone])
	Core.centered(m, cf, 0, BRICK, 0, 8, BRICK * 2, 8, set.accent)
	Core.centered(m, cf, 0, BRICK * 3, 0, 7, PLATE, 7, C.gold)
	local plaque = Core.box(m, cf, -1.5, BRICK * 1.2, -4.3, 3, BRICK * 1.6, 0.4, C.black, { smooth = true })
	Core.label(plaque, tostring(rung), Enum.NormalId.Front, C.gold)
	for _, x in { -6, 6 } do
		Build.banner(m, cf * CFrame.new(x, 0, 4), 14, set.accent, C.gold)
	end
	if not noPad then
		Core.centered(m, cf, 0, 0, -10, 8, PLATE, 6, C.black, { smooth = true })
		local pad =
			Core.centered(m, cf, 0, PLATE, -10, 6, 0.2, 4, set.accent:Lerp(Color3.new(1, 1, 1), 0.2), { neon = true })
		Core.label(pad, "CHALLENGE", Enum.NormalId.Top, C.white)
	end
	return m, cf * CFrame.new(0, BRICK * 3 + PLATE, 0)
end

-- A teleport pad with a spinning neon ring and rising sparkles.
function Play.teleportPad(parent, cf, set)
	local m = Core.model(parent, "TeleportPad", cf)
	Core.centered(m, cf, 0, 0, 0, 10, PLATE, 10, C.black)
	Core.centered(m, cf, 0, PLATE, 0, 8, PLATE, 8, set.accent)
	Core.centered(m, cf, 0, PLATE * 2, 0, 4, PLATE, 4, C.white, { smooth = true })
	local spin = Core.model(m, "Spinner", cf)
	for k = 0, 3 do
		Core.part(
			spin,
			cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, k * math.pi / 4, 0),
			Vector3.new(7, 0.2, 0.4),
			set.accent:Lerp(Color3.new(1, 1, 1), 0.4),
			{ neon = true, collide = false }
		)
	end
	Core.tag(spin, "Spin")
	spin:SetAttribute("Speed", 1.2)
	local emitter =
		Core.part(m, cf * CFrame.new(0, 1, 0), Vector3.new(6, 0.2, 6), C.white, { trans = 1, collide = false })
	Core.particles(emitter, {
		color = set.accent:Lerp(Color3.new(1, 1, 1), 0.5),
		size = 0.4,
		rate = 10,
		life = { 1, 2 },
		speed = 4,
		spread = 5,
		lightEmission = 1,
	})
	return m
end

-- A giant torii gate to a zone. It carries both looks: "Chains" (two sagging chains and a padlock) and
-- "Sheet" (a shimmering portal). `locked` picks the starting look; the client switches it per player
-- (client/ZoneClient.lua) from their unlocked zones. Tagged "ZoneGate" with attribute Zone.
function Play.zoneGate(parent, cf, set, title, locked, zone, color)
	local m = Core.model(parent, "ZoneGate", cf)
	Core.centered(m, cf, 0, 0, 0, 34, BRICK, 8, set.stone[#set.stone])
	Core.centered(m, cf, 0, BRICK, 0, 32, BRICK, 6, set.stone[1])
	Build.torii(m, cf * CFrame.new(0, BRICK * 2, 0), 28, 26, { color = color or set.accent, plaque = false })
	-- The zone's name on a wide board between the tie beam and the top beam, readable from both sides
	-- (players walk up from the hub, behind the torii's front). Nothing hangs in front of it.
	-- Just in front of the tie beam (which runs at z -1..0), below the top beam.
	local signY = BRICK * 2 + 26 - 1.8
	local board = Core.part(m, cf * CFrame.new(0, signY, -1.5), Vector3.new(20.6, 3.4, 0.6), C.black, { smooth = true })
	Core.part(
		m,
		cf * CFrame.new(0, signY, -1.5),
		Vector3.new(21.6, 4, 0.4),
		C.gold,
		{ smooth = true, material = Enum.Material.Metal }
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Core.label(board, title, face, C.gold)
	end
	local chains = Core.model(m, "Chains", cf)
	local function chain(a, b)
		local n = math.floor((b - a).Magnitude / 1.2)
		for i = 0, n - 1 do
			local t = (i + 0.5) / n
			local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2.5, 0)
			local link = Core.part(
				chains,
				CFrame.lookAt(p, b) * CFrame.Angles(0, 0, (i % 2) * math.pi / 2),
				Vector3.new(0.5, 0.9, 1.4),
				C.darkGray,
				{ smooth = true, collide = false }
			)
			link.Material = Enum.Material.Metal
		end
	end
	local top = BRICK * 2 + 16
	chain(cf * Vector3.new(-13, top, -1), cf * Vector3.new(13, top - 10, -1))
	chain(cf * Vector3.new(13, top, -1.3), cf * Vector3.new(-13, top - 10, -1.3))
	local lock = Core.part(
		chains,
		cf * CFrame.new(0, top - 7.5, -1.8),
		Vector3.new(3, 3, 1.2),
		C.gold,
		{ smooth = true, collide = false }
	)
	lock.Material = Enum.Material.Metal
	Core.part(
		chains,
		cf * CFrame.new(0, top - 5.4, -1.8),
		Vector3.new(2.2, 1.6, 0.5),
		C.darkGray,
		{ smooth = true, collide = false }
	)
	Core.part(
		chains,
		cf * CFrame.new(0, top - 7.6, -2.45),
		Vector3.new(0.5, 1, 0.1),
		C.black,
		{ smooth = true, collide = false }
	)
	local sheetModel = Core.model(m, "Sheet", cf)
	local sheet = Core.part(
		sheetModel,
		cf * CFrame.new(0, BRICK * 2 + 9.5, 0),
		Vector3.new(22, 19, 0.2), -- stops below the tie beam, clear of the name board
		set.accent:Lerp(Color3.new(1, 1, 1), 0.5),
		{ neon = true, trans = 0.7, collide = false, tag = "LightPillar" }
	)
	local sparkles = Core.particles(
		sheet,
		{ color = C.white, size = 0.5, rate = 12, life = { 1, 2 }, speed = 1, spread = 90, lightEmission = 1 }
	)
	-- Starting look (the server's default view; each client then shows its own).
	for _, p in chains:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = locked and 0 or 1
		end
	end
	sheet:SetAttribute("Open", 0.7)
	sheet.Transparency = locked and 1 or 0.7
	sparkles.Enabled = not locked
	m:SetAttribute("Zone", zone)
	Core.tag(m, "ZoneGate")
	return m
end

-- A collect-money panel in front of a stand: gold-framed green pad with a $ on top and a floating cash
-- readout (named "Cash", written by the plot system). `cf` sits on the ground, front facing -Z.
function Play.collectPad(parent, cf)
	local m = Core.model(parent, "CollectPad", cf)
	Core.centered(m, cf, 0, 0, 0, 6, PLATE, 4, C.gold, { smooth = true })
	local pad = Core.centered(m, cf, 0, PLATE, 0, 5, PLATE * 0.5, 3, Color3.fromRGB(70, 200, 96), { smooth = true })
	pad.Name = "Pad"
	Core.label(pad, "$", Enum.NormalId.Top, C.white, Color3.fromRGB(20, 90, 40))
	local gui = Instance.new("BillboardGui")
	gui.Name = "Cash"
	gui.Size = UDim2.fromScale(6, 1.8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Parent = pad
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(120, 255, 140)
	text.Text = "$0"
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = text
	return m, pad
end

-- A plot pedestal: stepped, gold-capped (or `cap`); the fighter stands on top.
function Play.pedestal(parent, cf, set, trim, cap)
	local m = Core.model(parent, "Pedestal", cf)
	Core.centered(m, cf, 0, 0, 0, 6, BRICK, 6, set.stone[1])
	Core.centered(m, cf, 0, BRICK, 0, 4, BRICK * 2, 4, trim or set.accent)
	Core.centered(m, cf, 0, BRICK * 3, 0, 5, PLATE, 5, cap or C.gold)
	return m, cf * CFrame.new(0, BRICK * 3 + PLATE, 0)
end

-- The plot's cash collector: a basin of water and a heap of coins round a spout.
function Play.fountain(parent, cf, set)
	local m = Core.model(parent, "Fountain", cf)
	Core.centered(m, cf, 0, 0, 0, 12, BRICK, 12, set.stone[#set.stone])
	for side = 0, 3 do
		local face = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		-- Even sides span the corners, odd sides fit between them (no shared faces).
		local span = side % 2 == 0 and 10 or 8
		Core.box(m, face, -span / 2, BRICK, -5, span, BRICK * 2, 1, set.stone[1])
		Core.box(
			m,
			face,
			-span / 2 - (side % 2 == 0 and 0.2 or -0.2),
			BRICK * 3,
			-5.2,
			span + (side % 2 == 0 and 0.4 or -0.4),
			PLATE,
			1.4,
			C.gold,
			{ smooth = true }
		)
	end
	Core.centered(m, cf, 0, BRICK * 1.6, 0, 8, PLATE, 8, Color3.fromRGB(64, 190, 230), { smooth = true, trans = 0.3 })
	Core.centered(m, cf, 0, BRICK, 0, 2, BRICK * 4, 2, set.stone[1])
	Core.centered(m, cf, 0, BRICK * 5, 0, 5, BRICK, 5, set.stone[1])
	Core.centered(m, cf, 0, BRICK * 6, 0, 3, PLATE, 3, C.gold)
	local coin = Core.cyl(m, cf, 0, BRICK * 6 + 1.5, 0, 2.6, 0.5, C.gold, { tag = "Spin" })
	coin.CFrame = cf * CFrame.new(0, BRICK * 6 + 2, 0) * CFrame.Angles(0, 0, 0)
	coin:SetAttribute("Speed", 2)
	coin.Material = Enum.Material.Metal
	for _ = 1, 14 do
		local a, r = Core.num(0, math.pi * 2), Core.num(1.6, 3.6)
		Core.roundPlate(m, cf, math.cos(a) * r, BRICK * 1.6 + PLATE + Core.int(0, 2) * PLATE, math.sin(a) * r, C.gold)
	end
	Core.particles(coin, {
		color = C.lightYellow,
		size = 0.3,
		rate = 6,
		life = { 0.8, 1.4 },
		speed = 3,
		spread = 40,
		accel = Vector3.new(0, -6, 0),
		lightEmission = 0.6,
	})
	return m
end

-- The Colosseum: a raised round stage, tiers of stands in rings of colour, an outer wall with banners and
-- four gated entrances. `cf` is the ground centre. Returns the model and the stage-top CFrame.
function Play.colosseum(parent, cf, set, opts)
	opts = opts or {}
	local m = Core.model(parent, "Colosseum", cf)
	local stageR, inner, tiers, depth, sectors = opts.stage or 24, opts.inner or 30, 5, 3, 48
	-- Sandstone and deep maroon, not bright red: a grand arena that doesn't shout over the fighters.
	local function rgb(r, g, b)
		return Color3.fromRGB(r, g, b)
	end
	local SAND, SAND_DARK = rgb(196, 168, 132), rgb(160, 132, 100)
	local MAROON, MAROON_DARK = rgb(132, 52, 50), rgb(96, 38, 40)
	local BRASS = rgb(200, 160, 72)
	local stageSet =
		{ grass = { C.lightTan, C.tan, C.lightTan, C.cream }, dirt = { C.gray, C.darkGray }, stone = set.stone }
	Terrain.landmass(m, cf * CFrame.new(0, BRICK * 2, 0), stageR + 4, function(x, z)
		return x * x + z * z <= stageR * stageR
	end, BRICK * 2, stageSet, { tiles = "fine", noDrips = true })
	-- Rings painted on the stage.
	for _, ringSpec in { { stageR - 2.5, MAROON, 1.6 }, { 9, BRASS, 1 } } do
		local r, color, w = ringSpec[1], ringSpec[2], ringSpec[3]
		local n = math.floor(r * 1.2)
		for i = 0, n - 1 do
			local a = (i + 0.5) / n * math.pi * 2
			local p = cf * Vector3.new(math.cos(a) * r, BRICK * 2 + 0.1 + (i % 2) * 0.04, math.sin(a) * r)
			Core.part(
				m,
				CFrame.lookAt(p, p + cf:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))),
				Vector3.new(w, 0.2, 2 * math.pi * r / n + 0.15),
				color,
				{ smooth = true }
			)
		end
	end
	local gates = opts.gates or { 0, 90, 180, 270 }
	local function inGate(deg, halfWidth)
		for _, g in gates do
			local d = math.abs((deg - g + 180) % 360 - 180)
			if d < halfWidth then
				return true
			end
		end
		return false
	end
	local seatColors = { rgb(222, 212, 194), rgb(200, 190, 172), MAROON, rgb(222, 212, 194), MAROON_DARK }
	for i = 0, sectors - 1 do
		local a = (i + 0.5) / sectors * math.pi * 2
		local deg = math.deg(a)
		if not inGate(deg, 9) then
			local dir = cf:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
			local tangent = cf:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
			for t = 0, tiers - 1 do
				local r = inner + t * depth + depth / 2
				local h = BRICK * 2 * (t + 1) + (i % 2) * 0.05 -- neighbours never share a top plane
				local p = cf.Position + dir * r + Vector3.new(0, h / 2, 0)
				Core.part(
					m,
					CFrame.lookAt(p, p + tangent),
					Vector3.new(depth, h, 2 * math.pi * r / sectors + 0.3),
					seatColors[t + 1]
				)
			end
			-- Outer wall with a gold coping.
			local r = inner + tiers * depth + 1
			local h = BRICK * 2 * tiers + BRICK * 3 + (i % 2) * 0.05
			local p = cf.Position + dir * r + Vector3.new(0, h / 2, 0)
			local frame = CFrame.lookAt(p, p + tangent)
			Core.part(
				m,
				frame,
				Vector3.new(2 + (i % 2) * 0.05, h, 2 * math.pi * r / sectors + 0.3),
				(i % 2 == 0) and SAND or SAND_DARK
			)
			Core.part(
				m,
				frame * CFrame.new(0, h / 2 + 0.3, 0),
				Vector3.new(2.6 + (i % 2) * 0.05, 0.6, 2 * math.pi * r / sectors + 0.3),
				BRASS,
				{ smooth = true }
			)
			if i % 6 == 0 then
				local base = cf.Position + dir * r + Vector3.new(0, h + 0.6, 0)
				Build.banner(
					m,
					CFrame.lookAt(base, base + dir),
					10,
					i % 12 == 0 and MAROON or BRASS,
					i % 12 == 0 and BRASS or MAROON
				)
			end
		end
	end
	-- Entrance gates with braziers.
	for _, g in gates do
		local a = math.rad(g)
		local dir = cf:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
		local base = cf.Position + dir * (inner + tiers * depth + 1)
		Build.torii(m, CFrame.lookAt(base, base + dir), 14, 18, { color = set.accent, label = opts.title })
		for _, side in { -1, 1 } do
			local p = base + cf:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a))) * side * 9 + dir * 2
			local bf = CFrame.new(p)
			Core.centered(m, bf, 0, 0, 0, 2, BRICK * 3, 2, C.gray)
			local bowl = Core.cyl(m, bf, 0, BRICK * 3, 0, 2.6, 0.8, C.gold)
			bowl.Material = Enum.Material.Metal
			Core.fire(m, bowl.Position + Vector3.new(0, 0.6, 0), 4, 7)
			Core.light(bowl, C.orange, 18, 1.2, true)
		end
	end
	return m, cf * CFrame.new(0, BRICK * 2, 0)
end

return Play
