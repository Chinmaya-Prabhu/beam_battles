-- Places Sky Dojo Island kit models (tools/blender/build_kit.py -> imported into ReplicatedStorage.Assets.Kit).
-- Props are found by name (Kit_<Name> or <Name>), scaled to the size the caller asks for and stood on the given
-- base. Parts named <Name>__<Role> get role treatment: leaf and flower cards are alpha-cut, foliage and clouds
-- don't collide, and colours can be overridden per role (altar trim by tier). Returns nil when the kit or the
-- prop is missing, so callers keep their block-built fallback.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = {}

local CUTOUT = { Leaves = true, Flowers = true, Grass = true }
local NO_COLLIDE = { Leaves = true, Flowers = true, Grass = true, Cloud = true, Glow = true }

local function folder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Kit")
end

function Kit.has(name)
	local f = folder()
	return f ~= nil and (f:FindFirstChild("Kit_" .. name, true) or f:FindFirstChild(name, true)) ~= nil
end

local function roleOf(part)
	local role = string.match(part.Name, "__(%w+)")
	return role
end

-- opts: height | width | size (largest side), parent, collide (default true for solid roles),
--       colors = { Role = Color3 }, material = { Role = Enum.Material }, yaw (radians), flat (thinnest axis up)
function Kit.place(name, base, opts)
	opts = opts or {}
	local f = folder()
	local source = f and (f:FindFirstChild("Kit_" .. name, true) or f:FindFirstChild(name, true))
	if not source then
		return nil
	end
	local model = source:Clone()
	if not model:IsA("Model") then
		local wrap = Instance.new("Model")
		model.Parent = wrap
		model = wrap
	end
	model.Name = name
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local role = roleOf(p)
			p.Anchored = true
			p.CanCollide = opts.collide ~= false and not NO_COLLIDE[role]
			p.CanTouch = false
			p.CanQuery = p.CanCollide
			p.CastShadow = role ~= "Cloud"
			if CUTOUT[role] then
				-- Roblox only alpha-cuts a texture's transparent pixels on a part that is very slightly transparent.
				p.Transparency = 0.02
			end
			if opts.colors and opts.colors[role] then
				p.Color = opts.colors[role]
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
			end
			if opts.material and opts.material[role] then
				p.Material = opts.material[role]
			end
		elseif p:IsA("LuaSourceContainer") then
			p:Destroy()
		end
	end
	-- Orient: optionally lay flat (thinnest axis up), then yaw.
	local cf, size = model:GetBoundingBox()
	local rot = CFrame.identity
	if opts.flat and not (size.Y <= size.X and size.Y <= size.Z) then
		rot = size.X < size.Z and CFrame.Angles(0, 0, math.pi / 2) or CFrame.Angles(math.pi / 2, 0, 0)
	end
	model:PivotTo(CFrame.new(cf.Position) * rot)
	cf, size = model:GetBoundingBox()
	local scale
	if opts.height then
		scale = opts.height / size.Y
	elseif opts.width then
		scale = opts.width / math.max(size.X, size.Z)
	elseif opts.size then
		scale = opts.size / math.max(size.X, size.Y, size.Z)
	end
	if scale then
		model:ScaleTo(model:GetScale() * scale)
	end
	-- Stand the bounding box's bottom centre on `base` (a CFrame or Vector3), turned by its yaw.
	cf, size = model:GetBoundingBox()
	local baseCf = typeof(base) == "CFrame" and base or CFrame.new(base)
	local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(
		baseCf
			* CFrame.Angles(0, opts.yaw or 0, 0)
			* CFrame.new(model:GetPivot().Position - bottom)
			* model:GetPivot().Rotation
	)
	model.Parent = opts.parent or workspace
	return model
end

-- Every part of a placed kit model with the given role (e.g. the lantern's Glow, the altar's Trim).
function Kit.parts(model, role)
	local list = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and roleOf(p) == role then
			table.insert(list, p)
		end
	end
	return list
end

return Kit
