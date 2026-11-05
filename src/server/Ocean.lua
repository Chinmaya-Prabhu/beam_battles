-- The sea under the whole world and the mountains on its horizon, so there is no open Roblox void anywhere: the
-- hub and the zone islands stand in one ocean that runs out to the anime sky's own sea (server/Atmosphere),
-- with Toolbox mountains far out to close the view. (The little decor islands that used to ring it are gone: about
-- a thousand parts and decals nobody could reach.) Falling in brings you back (server/Services/ZoneService).
local Ocean = {}

Ocean.LEVEL = -14 -- the water surface: just under the hub's cliffs
local TILE = 2000 -- the sea is a grid of TILE-wide slabs (a part is at most 2048 across)
local TILES = 3 -- each way from the middle: (2 * 3 + 1) * 2000 = 14000 studs of sea

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function part(parent, name, cf, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

function Ocean.build(root)
	local m = Instance.new("Model")
	m.Name = "Ocean"
	m.Parent = root
	for x = -TILES, TILES do
		for z = -TILES, TILES do
			local sea = part(
				m,
				"Sea",
				CFrame.new(x * TILE, Ocean.LEVEL - 1, z * TILE),
				Vector3.new(TILE + 1, 2, TILE + 1),
				rgb(34, 104, 190)
			)
			sea.Reflectance = 0.08
		end
	end
	-- The horizon: Toolbox rocky mountains in a far ring (ServerStorage.Horizon, assets/models/Horizon.rbxmx,
	-- scripts stripped), with gaps of open sea.
	local horizon = game:GetService("ServerStorage"):FindFirstChild("Horizon")
	local rng = Random.new(910)
	for ring, spec in
		{
			{ name = "Mountain", r = 3000, n = 16, width = { 900, 1500 } },
		}
	do
		local template = horizon and horizon:FindFirstChild(spec.name)
		if not template then
			continue
		end
		for i = 1, spec.n do
			if rng:NextNumber() < 0.2 then
				continue -- a gap: open sea to the horizon
			end
			local a = (i + rng:NextNumber(-0.3, 0.3)) / spec.n * math.pi * 2 + ring
			local r = spec.r + rng:NextNumber(-250, 250)
			local copy = template:Clone()
			local size = copy:GetExtentsSize()
			copy:ScaleTo(rng:NextNumber(spec.width[1], spec.width[2]) / math.max(size.X, size.Z))
			for _, d in copy:GetDescendants() do
				if d:IsA("SpawnLocation") then
					d:Destroy() -- (the model came with one)
				elseif d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
				end
			end
			-- Sat in the water: its bottom a little under the surface, turned at random.
			local cf, box = copy:GetBoundingBox()
			local bottom = cf.Position.Y - box.Y / 2
			local at = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			copy:PivotTo(
				CFrame.new(at.X, copy:GetPivot().Position.Y - bottom + Ocean.LEVEL - box.Y * 0.04, at.Z)
					* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			)
			copy.Parent = m
		end
	end
	return m
end

return Ocean
