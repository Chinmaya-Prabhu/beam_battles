-- Studio-only showcase of the Brick Kit (workspace attribute KitGallery = true): a floating Blossom islet
-- laid out like a zone slice (gate, path, altar grounds with clash pads under the drop portal, dojo on a
-- raised terrace, pagoda, market booth, pond, waterfall), plus the four plot base stages in a row.
local Bricks = require(game:GetService("ReplicatedStorage").Shared.Bricks)
local BrickKit = require(script.Parent.BrickKit)

local KitGallery = {}
local K = BrickKit
local C = Bricks.C
local BRICK = K.Core.BRICK

local function at(x, y, z, yaw)
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

local function islet(root, set)
	local top = 12
	local upper = top + BRICK * 3
	K.Core.seed(11)
	K.Terrain.terrace(root, at(0, top, 0), 112, 84, 12, set, { tiles = "coarse" })
	K.Terrain.underside(root, at(0, 0, 0), 112, 84, 40, set)
	-- Raised back terrace for the dojo, reached by stairs.
	K.Terrain.terrace(root, at(0, upper, -30), 52, 22, BRICK * 3, set, { tiles = "coarse", noDetail = true })
	K.Terrain.stairs(root, at(0, top, -13), 10, 3, set)
	K.Plot.dojo(root, at(0, upper, -30), set)
	for _, x in { -14, 14 } do
		K.Build.lanternStone(root, at(x, upper, -22), set)
	end
	-- Entrance: gate, lanterns and the path up to the stairs.
	K.Terrain.path(root, at(0, top, 42), 60, 8, set)
	K.Build.torii(root, at(0, top, 34), 14, 16, { color = C.vermilion, label = "DOJO" })
	for _, z in { 24, 8 } do
		K.Build.lanternStone(root, at(-7, top, z), set)
		K.Build.lanternStone(root, at(7, top, z), set)
	end
	-- Altar grounds: the altar between two clash pads, the drop portal hanging above.
	K.Terrain.path(root, at(32, top, 22), 28, 30, set)
	K.Play.altar(root, at(32, top, 8), set, C.pink)
	K.Play.clashPad(root, at(18, top, 8, 90), set, Color3.fromRGB(70, 150, 255))
	K.Play.clashPad(root, at(46, top, 8, -90), set, Color3.fromRGB(255, 80, 70))
	K.Play.dropPortal(root, at(32, top + 48, 8), 9, set)
	-- West side: pagoda, market booth, pond.
	K.Build.pagoda(root, at(-36, top, -22), 4, 12, set, { glow = true, lanterns = true })
	K.Build.shopFront(root, at(-28, top, 20, -90), 10, set, { title = "SHOP", stripes = { C.vermilion, C.white } })
	K.Terrain.pond(root, at(-14, top, 2), 10, 8, set)
	K.Terrain.waterfall(root, at(-46, top, 42, 180), 44, 6, set)
	K.Build.banner(root, at(-11, upper, -24), 14, set.accent, C.gold)
	K.Build.banner(root, at(11, upper, -24), 14, set.accent, C.gold)
	K.Build.fence(root, at(52, top, -20, 90), 18, set)
	-- Small motion: carp streamers, water wheel, water-knocker, temple bell, incense, sky lanterns.
	K.Build.koinobori(root, at(-13, top, 30), 22)
	K.Build.waterWheel(root, at(-14, top + 3.6, -1), 3, set)
	K.Build.shishiOdoshi(root, at(-22, top, 7, 90), set)
	K.Build.templeBell(root, at(-19, upper, -30), set)
	K.Build.incense(root, at(0, top, -6))
	for i, p in { { -62, -12, 0 }, { 62, -22, 30 }, { 0, -32, -62 }, { 34, -6, 62 }, { -34, -24, 54 } } do
		K.Build.skyLantern(root, at(p[1], top + p[2], p[3]), 130, 46, i * 9)
	end
	-- Trees, shrubs and stones.
	local trees = {
		{ "blossom", 3, 36, -26 },
		{ "blossom", 2, 50, 30 },
		{ "blossom", 2, -48, 4 },
		{ "blossom", 1, 14, 30 },
		{ "round", 2, -20, 32 },
		{ "pine", 2, 50, -34 },
		{ "pine", 1, 22, -36 },
		{ "maple", 2, -50, -36 },
	}
	for _, t in trees do
		K.Nature.tree(root, at(t[3], top, t[4]), t[1], t[2], set)
	end
	K.Nature.bush(root, at(-6, top, 14), 2, set, true)
	K.Nature.bush(root, at(8, top, 18), 1, set, true)
	K.Nature.bush(root, at(-40, top, 30), 3, set, false)
	K.Nature.bush(root, at(24, upper, -38), 2, set, true)
	K.Nature.rock(root, at(-24, top, -6), 2, set, true)
	K.Nature.rock(root, at(46, top, -6), 3, set, true)
	K.Nature.rock(root, at(-2, top, 36), 1, set, false)
	for _, p in { { -16, 18 }, { 18, 22 }, { -34, -4 }, { 40, 36 }, { 4, -6 }, { -46, 22 } } do
		K.Nature.flowers(root, at(p[1], top, p[2]), 3, 10, set)
		K.Nature.tufts(root, at(p[1] + 3, top, p[2] - 3), 3, 6, set)
	end
	for i, c in { { -84, -6, 20 }, { 86, -14, -14 }, { 20, -26, 80 }, { -40, 30, -90 } } do
		K.Nature.cloud(root, at(c[1], c[2], c[3]), (i - 1) % 3 + 1)
	end
end

local function plotRow(root)
	local set = Bricks.Zones.Hub
	for i, stage in K.Plot.STAGES do
		local x = -105 + (i - 1) * 70
		K.Core.seed(100 + i)
		K.Terrain.terrace(root, at(x, 4, 130), 44, 44, 4, set, { tiles = "coarse", noDetail = true })
		stage(root, at(x, 4, 130), set)
	end
end

function KitGallery.build()
	local root = Instance.new("Folder")
	root.Name = "KitGallery"
	root.Parent = workspace
	for name, build in
		{
			Islet = function(m)
				islet(m, Bricks.Zones.Blossom)
			end,
			Plots = plotRow,
		}
	do
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = root
		build(m)
	end
	return root
end

return KitGallery
