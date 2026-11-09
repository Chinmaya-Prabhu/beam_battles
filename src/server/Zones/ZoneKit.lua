-- Pieces every zone island shares (docs/WORLD_PLAN.md §3): Dojo Ladder stations, the boss arena, the
-- return pad, fighter statues and the clock tower. Frames face their approach along -Z.
-- Stations and the arena are Models tagged "Guardian" (attributes Zone, Rung, Guardian = display name;
-- the boss is Rung 6) so the client can label them with each player's own progress.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bricks = require(ReplicatedStorage.Shared.Bricks)
local FighterModels = require(ReplicatedStorage.Shared.FighterModels)
local Fighters = require(ReplicatedStorage.Shared.Fighters)
local K = require(script.Parent.Parent.BrickKit)

local ZoneKit = {}
local C = Bricks.C
local BRICK, PLATE = K.Core.BRICK, K.Core.PLATE
local CHALLENGER = Color3.fromRGB(70, 150, 255)
local RIVAL = Color3.fromRGB(255, 80, 70)
local BOSS_TALLEST = 18 -- studs

-- A fighter standing at `cf` (feet), facing cf.LookVector, playing its idle clip.
function ZoneKit.statue(parent, key, cf, scale)
	local model = FighterModels.spawn(key, cf.Position, cf.LookVector, { parent = parent, scale = scale, aura = true })
	if model then
		CollectionService:AddTag(model, "Fighter")
		model:SetAttribute("Clip", "Idle")
		model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
	end
	return model
end

-- An invisible marker on a clash pad's standing surface (what ClashService measures against).
local function marker(parent, surface)
	return K.Core.part(
		parent,
		surface,
		Vector3.new(4, 0.2, 4),
		C.white,
		{ trans = 1, collide = false, name = "ClashPad" }
	)
end

local function guardianModel(parent, name, cf, zone, rung, key)
	local m = K.Core.model(parent, name, cf)
	m:SetAttribute("Zone", zone)
	m:SetAttribute("Rung", rung)
	m:SetAttribute("Guardian", Fighters.ByKey[key] and Fighters.ByKey[key].display or key)
	CollectionService:AddTag(m, "Guardian")
	return m
end

-- A ladder station, laid out like a hub drop altar: the challenger's pad at the front (-Z), the prize altar in
-- the middle (`cf`, where a guardian spawn stands) and the guardian standing on its own pad at the back
-- (+Z), the two pads facing each other across the altar. Returns { model, pads, display, prizeAt }.
-- opts.compact: pads 14 from the centre (tight decks) instead of 17; opts.noStrip: skip the tiled strip
-- (the floor is already paved); opts.noSign: skip the CHALLENGE sign.
function ZoneKit.station(parent, cf, set, zone, rung, key, opts)
	opts = opts or {}
	local half = opts.compact and 14 or 17
	local m = guardianModel(parent, "Station" .. rung, cf, zone, rung, key)
	if not opts.noStrip then
		K.Terrain.path(m, cf * CFrame.new(0, 0, half + 12), half * 2 + 24, 12, set)
	end
	local _, standCF = K.Play.altar(m, cf, set, set.accent, true)
	local _, rivalTop = K.Play.clashPad(m, cf * CFrame.new(0, 0, half), set, RIVAL)
	local _, playerTop =
		K.Play.clashPad(m, cf * CFrame.new(0, 0, -half) * CFrame.Angles(0, math.pi, 0), set, CHALLENGER)
	-- The guardian waits on its pad, facing the challenger.
	local toward = playerTop.Position - rivalTop.Position
	local display = ZoneKit.statue(m, key, CFrame.lookAt(rivalTop.Position, rivalTop.Position + toward), 1.3)
	if not opts.noSign then
		local sign = K.Core.part(
			m,
			cf * CFrame.new(0, PLATE * 1.5, -half - 12),
			Vector3.new(8, PLATE, 2.6),
			set.accent:Lerp(Color3.new(1, 1, 1), 0.2),
			{ neon = true }
		)
		K.Core.label(sign, "CHALLENGE", Enum.NormalId.Top, C.white)
	end
	return {
		model = m,
		pads = { marker(m, playerTop), marker(m, rivalTop) },
		display = display,
		prizeAt = standCF,
	}
end

-- A sign arch over a walkway (posts either side, a glowing board across the top with `text` on both faces),
-- so a place reads at a glance from the path. `cf` is the walkway's centre at the ground, facing the approach.
function ZoneKit.arch(parent, cf, set, text)
	local m = K.Core.model(parent, "Arch", cf)
	local post = set.wood and set.wood[2] or C.darkBrown
	for _, sx in { -1, 1 } do
		K.Core.centered(m, cf, sx * 15, 0, 0, 1.6, 16, 1.6, post, { smooth = true })
		K.Core.centered(m, cf, sx * 15, 0, 0, 3, PLATE * 2, 3, C.gray, { smooth = true })
	end
	K.Core.centered(m, cf, 0, 14, 0, 33, 1.2, 1.8, post, { smooth = true })
	local board = K.Core.centered(m, cf, 0, 15.2, 0, 22, 4, 0.8, Color3.fromRGB(255, 205, 60), { smooth = true })
	K.Core.label(board, text, Enum.NormalId.Front, C.white, Color3.fromRGB(120, 70, 0))
	K.Core.label(board, text, Enum.NormalId.Back, C.white, Color3.fromRGB(120, 70, 0))
	return m
end

-- Give any gate model the two looks a zone gate needs (ZoneClient switches them per player): "Chains"
-- across the opening when locked, a glowing "Sheet" portal when open. `cf` is the opening's base centre
-- (front -Z), w x h its size. Tags the model "ZoneGate" with attributes Zone and Trigger.
function ZoneKit.portalize(m, cf, set, zone, w, h)
	local chains = K.Core.model(m, "Chains", cf)
	for k = 0, 1 do
		local a = cf * Vector3.new(-w / 2 + 0.5, h * (0.75 - k * 0.35), -0.3 - k * 0.3)
		local b = cf * Vector3.new(w / 2 - 0.5, h * (0.4 + k * 0.35), -0.3 - k * 0.3)
		local n = math.floor((b - a).Magnitude / 1.2)
		for i = 0, n - 1 do
			local t = (i + 0.5) / n
			local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 1.5, 0)
			local link = K.Core.part(
				chains,
				CFrame.lookAt(p, b) * CFrame.Angles(0, 0, (i % 2) * math.pi / 2),
				Vector3.new(0.5, 0.9, 1.4),
				C.darkGray,
				{ smooth = true, collide = false }
			)
			link.Material = Enum.Material.Metal
		end
	end
	local lock = K.Core.part(
		chains,
		cf * CFrame.new(0, h * 0.5, -0.9),
		Vector3.new(2.6, 2.6, 1),
		C.gold,
		{ smooth = true, collide = false }
	)
	lock.Material = Enum.Material.Metal
	local sheetModel = K.Core.model(m, "Sheet", cf)
	local sheet = K.Core.part(
		sheetModel,
		cf * CFrame.new(0, h / 2, 0),
		Vector3.new(w - 1, h - 0.5, 0.2),
		set.accent:Lerp(Color3.new(1, 1, 1), 0.5),
		{ neon = true, trans = 1, collide = false, tag = "LightPillar" }
	)
	local sparkles = K.Core.particles(
		sheet,
		{ color = C.white, size = 0.5, rate = 12, life = { 1, 2 }, speed = 1, spread = 90, lightEmission = 1 }
	)
	sparkles.Enabled = false
	m:SetAttribute("Zone", zone)
	m:SetAttribute("Trigger", (cf * CFrame.new(0, 3, 0)).Position)
	CollectionService:AddTag(m, "ZoneGate")
	return m
end

-- The boss arena: a raised round stage with a painted ring, braziers and banners, the boss's giant statue
-- at the side. Pads 20 apart across the centre. Returns { model, pads, display }.
-- opts.radius (13) and opts.padAt (10, the pads' distance from the centre) shrink it to fit a ship's deck.
function ZoneKit.bossArena(parent, cf, set, zone, key, opts)
	opts = opts or {}
	local m = guardianModel(parent, "BossArena", cf, zone, 6, key)
	local r = opts.radius or 13
	local padAt = opts.padAt or 10
	local stageSet = { grass = { C.lightTan, C.tan, C.cream }, dirt = { C.gray, C.darkGray }, stone = set.stone }
	K.Terrain.landmass(m, cf * CFrame.new(0, BRICK, 0), 16, function(x, z)
		return x * x + z * z <= r * r
	end, BRICK, stageSet, { tiles = "fine", noDrips = true })
	local n = 28
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local p = cf * Vector3.new(math.cos(a) * (r - 2), BRICK + 0.1 + (i % 2) * 0.04, math.sin(a) * (r - 2))
		K.Core.part(
			m,
			CFrame.lookAt(p, p + cf:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))),
			Vector3.new(1.2, 0.2, 2 * math.pi * (r - 2) / n + 0.15),
			set.accent,
			{ smooth = true }
		)
	end
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local bf = cf * CFrame.new(math.cos(a) * (r + 2), 0, math.sin(a) * (r + 2))
		K.Core.centered(m, bf, 0, 0, 0, 2, BRICK * 3, 2, C.gray)
		local bowl = K.Core.cyl(m, bf, 0, BRICK * 3, 0, 2.6, 0.8, C.gold)
		bowl.Material = Enum.Material.Metal
		K.Core.fire(m, bowl.Position + Vector3.new(0, 0.6, 0), 4, 7)
		K.Core.light(bowl, C.orange, 18, 1.2, true)
		K.Build.banner(m, cf * CFrame.new(math.cos(a) * (r + 5), 0, math.sin(a) * (r + 5)), 14, set.accent, C.gold)
	end
	local _, rivalTop = K.Play.clashPad(m, cf * CFrame.new(0, BRICK, padAt), set, RIVAL)
	local _, playerTop =
		K.Play.clashPad(m, cf * CFrame.new(0, BRICK, -padAt) * CFrame.Angles(0, math.pi, 0), set, CHALLENGER)
	-- The boss waits on its own pad, bigger than a guardian, facing the challenger. The giants (Whitebeard, the
	-- titans) keep their original big bodies but never stand taller than BOSS_TALLEST.
	local toward = playerTop.Position - rivalTop.Position
	local stand = CFrame.lookAt(rivalTop.Position, rivalTop.Position + toward)
	local display = ZoneKit.statue(m, key, stand, 1.7)
	local body = display and display:GetAttribute("BodyScale") or 1 -- (the bounding box counts weapons: not used)
	if display and 1.7 * body * 5 > BOSS_TALLEST then
		display:Destroy()
		display = ZoneKit.statue(m, key, stand, BOSS_TALLEST / (body * 5))
	end
	return { model = m, pads = { marker(m, playerTop), marker(m, rivalTop) }, display = display }
end

-- The pad that sends you back to the hub, with a sign.
function ZoneKit.returnPad(parent, cf, set)
	local m = K.Play.teleportPad(parent, cf, set)
	local sign = K.Core.part(m, cf * CFrame.new(0, 5, 4.5), Vector3.new(7, 2.4, 0.4), C.black, { smooth = true })
	K.Core.label(sign, "HUB", Enum.NormalId.Front, C.gold)
	for _, x in { -3.2, 3.2 } do
		K.Core.centered(m, cf, x, 0, 4.5, 0.6, 5, 0.6, C.darkBrown)
	end
	return m
end

-- A clock tower: storeys under a tall clock block with a face on the front (hands turn) and a roof.
function ZoneKit.clockTower(parent, cf, set)
	local m = K.Core.model(parent, "ClockTower", cf)
	K.Core.centered(m, cf, 0, 0, 0, 16, BRICK, 16, set.stone[#set.stone])
	local y = BRICK
	for i = 1, 3 do
		local _, top = K.Build.storey(m, cf * CFrame.new(0, y, 0), 12, BRICK * 5, set, { door = i == 1, glow = true })
		y += top
	end
	-- Clock block with posts.
	local clockH = BRICK * 8
	K.Core.centered(m, cf, 0, y, 0, 11, clockH, 11, set.plaster)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		K.Core.centered(m, cf, c[1] * 5.5, y, c[2] * 5.5, 1.6, clockH, 1.6, set.post or set.accent)
	end
	local center = cf * CFrame.new(0, y + clockH / 2, -5.5)
	K.Core.part(
		m,
		center * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.3, 9.4, 9.4),
		C.gold,
		{ shape = Enum.PartType.Cylinder, smooth = true }
	)
	K.Core.part(
		m,
		center * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.2, 8.4, 8.4),
		C.cream,
		{ shape = Enum.PartType.Cylinder, smooth = true }
	)
	for k = 0, 11 do
		local a = k * math.pi / 6
		local s = k % 3 == 0 and 0.9 or 0.5
		K.Core.part(
			m,
			center * CFrame.new(math.sin(a) * 3.5, math.cos(a) * 3.5, -0.45) * CFrame.Angles(0, 0, -a),
			Vector3.new(0.3, s, 0.1),
			C.black,
			{ smooth = true }
		)
	end
	for _, hand in { { "HourHand", 2.2, 0.45, -0.02 }, { "MinuteHand", 3.2, 0.3, -0.24 } } do
		local pivot = center * CFrame.new(0, 0, -0.55)
		local h = K.Core.model(m, hand[1], pivot)
		K.Core.part(
			h,
			pivot * CFrame.new(0, hand[2] / 2 - 0.3, 0),
			Vector3.new(hand[3], hand[2], 0.1),
			C.black,
			{ smooth = true, collide = false }
		)
		h:SetAttribute("Axis", Vector3.zAxis)
		h:SetAttribute("Speed", hand[4])
		K.Core.tag(h, "Rotor")
	end
	K.Core.cyl(m, center * CFrame.new(0, 0, -0.62) * CFrame.Angles(math.pi / 2, 0, 0), 0, 0, 0, 0.7, 0.15, C.gold)
	y += clockH
	local _, roofTop =
		K.Build.roof(m, cf * CFrame.new(0, y, 0), 17, 17, { colors = set.roof, trim = set.trim, finial = true })
	return m, y + roofTop
end

-- An invisible wall round a zone island's edge so nobody walks off: `shape(x, z)` is the island's outline in
-- `cf`'s space (the same one its landmass uses) and `half` bounds it. Each degree a ray finds the outermost
-- ground; the wall runs from point to point (so long straight sides and corners have no gaps).
function ZoneKit.edgeWall(parent, cf, shape, half)
	local m = K.Core.model(parent, "Edge", cf)
	local points = {}
	for deg = 0, 359 do
		local a = math.rad(deg)
		local dx, dz = math.cos(a), math.sin(a)
		for r = half, 0, -1 do
			if shape(dx * r, dz * r) then
				table.insert(points, Vector3.new(dx * (r + 1), 0, dz * (r + 1)))
				break
			end
		end
	end
	for i, p in points do
		local q = points[i % #points + 1]
		local length = (q - p).Magnitude
		if length > 0.05 then
			local wall = Instance.new("Part")
			wall.Name = "EdgeWall"
			wall.Anchored = true
			wall.Transparency = 1
			wall.CanQuery = false
			wall.CanTouch = false
			wall.CastShadow = false
			wall.Size = Vector3.new(length + 1.5, 140, 1)
			local mid = (p + q) / 2
			wall.CFrame = cf
				* CFrame.lookAt(mid + Vector3.new(0, 60, 0), q + Vector3.new(0, 60, 0))
				* CFrame.Angles(0, math.pi / 2, 0)
			wall.Parent = m
		end
	end
	return m
end

-- ------------------------------------------------------------------ conveyor belts
-- The hub's conveyor ring (server/Hub.lua) in a zone: two lanes going opposite ways round the whole zone, low
-- enough to step on or off anywhere. A route is a list of candidate loops (local x/z points in `cf`, the zone's
-- frame); the one with the fewest blocked pieces is built. Decoration in the way (trees, houses, lanterns...,
-- DECOR) is cleared off the path; a piece blocked by something that matters (a station, a gate, a building,
-- the water) is left out.
local BELT = { lane = 6, height = 0.5, speed = 32, piece = 6 }
local BELT_BASE, BELT_TRIM = Color3.fromRGB(46, 50, 64), Color3.fromRGB(255, 205, 60)
local MARKS = { Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 205, 60) }
local DECOR = {
	Tree = true,
	Bush = true,
	Rock = true,
	Tufts = true,
	Flowers = true,
	StoneLantern = true,
	PaperLantern = true,
	Banner = true,
	Crate = true,
	Barrel = true,
	Fence = true,
	House = true,
	Bench = true,
	LampPost = true,
	Planter = true,
	VendingMachine = true,
	BikeRack = true,
	NoticeBoard = true,
	LanternString = true,
	Scoreboard = true,
	Koinobori = true,
}

-- The decoration model a part belongs to (to clear it off the belt's path), or nil if it's something else.
local function decorOf(part, root)
	local d = part.Parent
	while d and d ~= root and d ~= workspace do
		if d:IsA("Model") and DECOR[d.Name] then
			return d
		end
		d = d.Parent
	end
	return nil
end

-- The pieces of a path: { at (local Vector3), dir (local unit Vector3) }, every BELT.piece studs.
local function pieces(points, closed)
	local out = {}
	local count = #points - (closed and 0 or 1)
	for i = 1, count do
		local a, b = points[i], points[i % #points + 1]
		local d = b - a
		local n = math.max(1, math.floor(d.Magnitude / BELT.piece + 0.5))
		for k = 0, n - 1 do
			table.insert(out, { at = a + d * ((k + 0.5) / n), dir = d.Unit, length = d.Magnitude / n })
		end
	end
	return out
end

-- Whether a piece can go here: solid ground at the zone's own level just under it (not water, not a wall
-- top) and nothing that matters standing in the way. Returns the ground height and the decoration to clear.
local function clear(cf, piece, ignore, root)
	local width = BELT.lane * 2 + 2
	local at = cf:PointToWorldSpace(piece.at)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), params)
	if
		not hit
		or math.abs(hit.Position.Y - at.Y) > 3
		or hit.Instance.Material == Enum.Material.Water
		or hit.Instance.Name:find("Water")
		or decorOf(hit.Instance, root)
	then
		return nil
	end
	local box = CFrame.lookAt(hit.Position, hit.Position + cf:VectorToWorldSpace(piece.dir)) * CFrame.new(0, 4.5, 0)
	local over = OverlapParams.new()
	over.FilterType = Enum.RaycastFilterType.Exclude
	over.FilterDescendantsInstances = ignore
	local decor = {}
	for _, p in workspace:GetPartBoundsInBox(box, Vector3.new(width, 7, piece.length), over) do
		if p.Transparency < 1 then
			local d = decorOf(p, root)
			if d then
				decor[d] = true
			elseif p.CanCollide then
				-- (What stopped it, for the Blocked attribute: the model right under the zone.)
				local top = p
				while top.Parent and top.Parent.Parent ~= root and top.Parent ~= root do
					top = top.Parent
				end
				return nil, nil, top.Name
			end
		end
	end
	return hit.Position.Y, decor
end

function ZoneKit.belt(parent, cf, routes, opts)
	opts = opts or {}
	local m = K.Core.model(parent, "Belt", cf)
	local ignore = { m }
	-- Pick the route with the most clear pieces.
	local best, bestY, bestDecor, bestCount
	for _, route in routes do
		local list = pieces(route, opts.closed ~= false)
		local ys, decor, count, blocked = {}, {}, 0, {}
		for i, piece in list do
			local why
			ys[i], decor[i], why = clear(cf, piece, ignore, parent)
			count += ys[i] and 1 or 0
			if why then
				blocked[why] = (blocked[why] or 0) + 1
			end
		end
		if not bestCount or count > bestCount then
			best, bestY, bestDecor, bestCount = list, ys, decor, count
			local names = {}
			for name, n in blocked do
				table.insert(names, name .. " x" .. n)
			end
			m:SetAttribute("Blocked", table.concat(names, ", "))
			m:SetAttribute("Built", count .. "/" .. #list)
		end
	end
	-- Clear the decoration off the chosen path.
	for _, set in bestDecor or {} do
		for d in set do
			if d.Parent then
				d:Destroy()
			end
		end
	end
	for i, piece in best or {} do
		local y = bestY[i]
		if not y then
			continue
		end
		local dir = cf:VectorToWorldSpace(piece.dir)
		local side = dir:Cross(Vector3.yAxis).Unit
		local at = Vector3.new(cf:PointToWorldSpace(piece.at).X, y, cf:PointToWorldSpace(piece.at).Z)
		for lane, sx in { -1, 1 } do
			local mid = at + side * sx * BELT.lane / 2 + Vector3.new(0, BELT.height / 2, 0)
			local way = dir * (lane == 1 and 1 or -1)
			local laneCf = CFrame.lookAt(mid, mid + way)
			local p = K.Core.part(m, laneCf, Vector3.new(BELT.lane, BELT.height, piece.length + 0.3), BELT_BASE, {
				smooth = true,
				name = "Belt",
			})
			p.AssemblyLinearVelocity = way * BELT.speed
			if i % 2 == 0 then
				for _, arm in { -1, 1 } do
					K.Core.part(
						m,
						laneCf
							* CFrame.new(arm * 0.9, BELT.height / 2 + 0.08, 0)
							* CFrame.Angles(0, arm * math.rad(40), 0),
						Vector3.new(0.35, 0.16, 2.6),
						MARKS[lane],
						{ neon = true, collide = false }
					)
				end
			end
		end
		for _, sx in { -1, 1 } do
			local edge = at + side * sx * (BELT.lane + 0.3) + Vector3.new(0, BELT.height / 2 + 0.05, 0)
			K.Core.part(
				m,
				CFrame.lookAt(edge, edge + dir),
				Vector3.new(0.6, BELT.height + 0.1, piece.length + 0.3),
				BELT_TRIM,
				{
					smooth = true,
					name = "BeltEdge",
				}
			)
		end
	end
	return m
end

-- Rounded-rectangle loops round a zone: half-width `x`, from z0 (front) to z1 (back), corner radius `r`,
-- tried at each inset in `insets` (studs in from those edges).
function ZoneKit.rectRoutes(x, z0, z1, r, insets)
	local routes = {}
	for _, k in insets or { 0 } do
		local hx, a, b = x - k, z0 + k, z1 - k
		local pts = {}
		local corners =
			{ { hx - r, b - r, 0 }, { -hx + r, b - r, 90 }, { -hx + r, a + r, 180 }, { hx - r, a + r, 270 } }
		for _, c in corners do
			for deg = c[3], c[3] + 90, 15 do
				local t = math.rad(deg)
				table.insert(pts, Vector3.new(c[1] + math.cos(t) * r, 0, c[2] + math.sin(t) * r))
			end
		end
		table.insert(routes, pts)
	end
	return routes
end

-- Elliptical loops (radii rx, rz times each of `scales`).
function ZoneKit.loopRoutes(rx, rz, scales, cx, cz)
	local routes = {}
	for _, k in scales do
		local pts = {}
		for deg = 0, 354, 6 do
			local a = math.rad(deg)
			table.insert(pts, Vector3.new((cx or 0) + math.cos(a) * rx * k, 0, (cz or 0) + math.sin(a) * rz * k))
		end
		table.insert(routes, pts)
	end
	return routes
end

return ZoneKit
