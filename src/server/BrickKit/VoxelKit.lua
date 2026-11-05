-- The voxel models (art/voxel_pilot): one uploaded Model, Config.VoxelKitId, holds the altar and pad meshes.
-- They are laid over the brick builds, which stay as invisible collision, so walking, stands, pads and every marker
-- work as before. Each mesh goes where shared/VoxelKitData.lua says, at the size it says, so it doesn't matter what
-- Import 3D did to the origin. With id 0, or if the load fails, everything stays brick.
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(ReplicatedStorage.Shared.VoxelKitData)

local VoxelKit = {}
local meshes, tried
-- Roblox turned the whole kit 180 degrees about Y on upload (baked into the meshes), so each one turns back.
local UPLOAD_TURN = CFrame.Angles(0, math.pi, 0)

local function load()
	if tried or Config.VoxelKitId == 0 then
		return meshes
	end
	tried = true
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(Config.VoxelKitId)
	end)
	if not ok then
		warn("[VoxelKit] load failed, keeping bricks:", asset)
		return nil
	end
	local found = {}
	for _, d in asset:GetDescendants() do
		if d:IsA("MeshPart") then
			found[d.Name] = d
		end
	end
	for _, piece in Data do
		for name in piece do
			if not found[name] then
				warn("[VoxelKit] missing mesh, keeping bricks:", name)
				return nil
			end
		end
	end
	meshes = found
	return meshes
end

function VoxelKit.ready()
	return load() ~= nil
end

-- The piece's meshes in a new Model under `parent`, placed in `cf`'s space. `paint(part)` colours each one.
local function place(parent, piece, cf, paint)
	local m = Instance.new("Model")
	m.Name = "Voxel" .. piece
	for name, spot in Data[piece] do
		local part = meshes[name]:Clone()
		part.Size = spot.s
		part.CFrame = cf * CFrame.new(spot.c) * UPLOAD_TURN
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(1, 1, 1) -- (the colours are in the mesh)
		if paint then
			paint(part)
		end
		part.Parent = m
	end
	m.Parent = parent
	return m
end

local function tinted(color)
	return function(part)
		if string.find(part.Name, "Glow", 1, true) then
			part.Color = color
			part.Material = Enum.Material.Neon
		end
	end
end

-- Hides the bricks of `m`. (Their lights, fire and sparks keep working on the invisible parts.)
local function hide(m, keep)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not (keep and keep(d)) then
			d.Transparency = 1
			d.CastShadow = false
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
end

function VoxelKit.altar(m, cf, accent)
	hide(m, function(d)
		return CollectionService:HasTag(d, "LightPillar")
	end)
	local paint = tinted(accent)
	place(m, "Altar", cf, function(part)
		paint(part)
		if string.find(part.Name, "Trim", 1, true) then
			part.Color = accent
		end
	end)
end

function VoxelKit.pad(m, cf, color, gold)
	hide(m)
	local paint = tinted(color)
	-- (Turned so the step faces away from the altar.)
	place(m, "Pad", cf * CFrame.Angles(0, math.pi, 0), function(part)
		paint(part)
		if string.find(part.Name, "Trim", 1, true) then
			part.Color = gold
		end
	end)
end

return VoxelKit
