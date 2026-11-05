-- The Brick Kit: studded world pieces built from Parts (docs/WORLD_PLAN.md §9).
-- Core helpers plus the piece families, merged into one table: BrickKit.Terrain.terrace(...), etc.
local BrickKit = {
	Core = require(script.Core),
	Terrain = require(script.Terrain),
	Nature = require(script.Nature),
	Build = require(script.Build),
	Play = require(script.Play),
	Plot = require(script.Plot),
	Dragon = require(script.Dragon),
	VoxelKit = require(script.VoxelKit),
}

return BrickKit
