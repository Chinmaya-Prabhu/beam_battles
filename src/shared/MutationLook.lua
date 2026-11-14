-- How each mutation looks on a fighter (Config.Mutations), applied wherever one is spawned
-- (FighterModels.spawn with opts.mutation): altars, stands, the Champion, the carry, the reveal, the Index.
-- The grow-engine method (its VariantFx): the fighter becomes a STATUE of the mutation. Every visible part
-- (body, hair, accessories, weapons) is recoloured in one material and colour; clothing and mesh textures go
-- so the colour shows; the face decal stays, so it's still them. Each mutation also has its own aura.
-- The aura itself (every fighter's, mutated or not) is shared/FighterAura.lua.
--   Golden   metallic gold statue (MaterialService.GoldStatue, the grow-engine gold texture); gold flame
--   Diamond  blue ice statue; ice-blue flame
--   Rainbow  statue constantly changing colour (clients cycle it); rainbow flame
--   Huge     no statue: twice the size in its own colours (the caller scales); orange flame
--   Cursed   deep purple, black curse marks up the limbs, black hair; black flame, purple sparks (Blossom)
--   Sage     orange, red sage pigment on limbs and hair; orange flame, red sparks               (Ninja)
--   Haki     fully black armament metal; black flame, red sparks                                 (Pirate)
--   Titan    pale titan skin, exposed red-muscle limbs, brown hair; red-orange flame, white steam (Walled)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MutationLook = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- statue: { color, material, reflectance, materialVariant? }
MutationLook.Looks = {
	Golden = { statue = { rgb(255, 214, 70), Enum.Material.Metal, 0.45, "GoldStatue" }, light = rgb(255, 200, 60) },
	Diamond = { statue = { rgb(110, 205, 255), Enum.Material.Ice, 0.35 }, light = rgb(140, 225, 255) },
	Rainbow = {
		statue = { rgb(255, 0, 0), Enum.Material.SmoothPlastic, 0.15 },
		light = rgb(255, 255, 255),
		cycle = true,
	},
	Huge = { light = rgb(255, 150, 60) },
	-- Zone mutations are two-tone: `statue` paints the torso, upper limbs and head; `regions` repaint the
	-- extremities (forearms, hands, shins, feet) and the gear (hair, accessories, weapons).
	Cursed = {
		statue = { rgb(85, 25, 140), Enum.Material.SmoothPlastic, 0.1 },
		regions = {
			ends = { rgb(14, 6, 20), Enum.Material.SmoothPlastic, 0.15 }, -- curse marks spreading up the limbs
			gear = { rgb(14, 6, 20), Enum.Material.SmoothPlastic, 0.15 },
		},
		light = rgb(140, 40, 220),
	},
	Sage = {
		statue = { rgb(255, 135, 25), Enum.Material.SmoothPlastic, 0.1 },
		regions = {
			ends = { rgb(205, 25, 20), Enum.Material.SmoothPlastic, 0.1 }, -- sage pigment
			gear = { rgb(205, 25, 20), Enum.Material.SmoothPlastic, 0.1 },
		},
		light = rgb(255, 140, 40),
	},
	Haki = {
		statue = { rgb(10, 8, 12), Enum.Material.Metal, 0.05 }, -- fully coated in armament haki
		light = rgb(230, 30, 40),
	},
	Titan = {
		statue = { rgb(225, 165, 140), Enum.Material.Slate, 0 }, -- pale titan skin
		regions = {
			ends = { rgb(165, 25, 25), Enum.Material.Slate, 0 }, -- exposed red muscle
			gear = { rgb(70, 40, 30), Enum.Material.Slate, 0 },
		},
		light = rgb(255, 150, 100),
	},
}

-- Which region of a statue a part is: the extremities, the gear, or the main body.
local ENDS = {
	LeftLowerArm = true,
	LeftHand = true,
	RightLowerArm = true,
	RightHand = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightLowerLeg = true,
	RightFoot = true,
}
local BODY = {
	PackHead = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	RightUpperArm = true,
	LeftUpperLeg = true,
	RightUpperLeg = true,
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}
local function regionOf(part)
	if ENDS[part.Name] then
		return "ends"
	elseif BODY[part.Name] then
		return "body"
	end
	return "gear"
end

local function paint(part, spec)
	local color, material, reflectance, variant = table.unpack(spec)
	local sa = part:FindFirstChildWhichIsA("SurfaceAppearance")
	if sa then
		sa:Destroy()
	end
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh.TextureId = "" -- untextured, so the part colour shows
	end
	if part:IsA("MeshPart") then
		part.TextureID = ""
	end
	part.Material = material
	part.Reflectance = reflectance
	part.Color = color
	if variant and game:GetService("MaterialService"):FindFirstChild(variant) then
		part.MaterialVariant = variant
	end
end

function MutationLook.apply(model, mutation)
	local look = MutationLook.Looks[mutation or "Normal"]
	if not look then
		return
	end
	model:SetAttribute("Mutation", mutation)
	if look.statue then
		for _, d in model:GetDescendants() do
			if d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
				d:Destroy()
			end
		end
		-- A fighter with no face decal wears its face in a texture: a head mesh or a hair-and-face accessory (Luffy,
		-- Levi, Mihawk, the titans). Those pieces, worn over the head, keep their own look, as a face decal does, so
		-- a statue is still them and not a faceless one.
		local faceDecal = false
		for _, d in model:GetDescendants() do
			if d:IsA("Decal") and d.Parent:IsA("BasePart") and d.Parent.Transparency < 0.95 then
				faceDecal = true
				break
			end
		end
		local head = model:FindFirstChild("Head")
		local function wornOverHead(p)
			if faceDecal or not (head and head:IsA("BasePart")) then
				return false
			end
			local textured = (p:IsA("MeshPart") and p.TextureID ~= "")
				or p:FindFirstChildWhichIsA("SurfaceAppearance") ~= nil
				or (p:FindFirstChildOfClass("SpecialMesh") and p:FindFirstChildOfClass("SpecialMesh").TextureId ~= "")
			if not textured then
				return false
			end
			local here = p.CFrame:PointToObjectSpace(head.Position)
			local half = p.Size * 0.65 -- (a little past its box: Gogeta's face mesh sits just off the head's centre)
			return math.abs(here.X) <= half.X and math.abs(here.Y) <= half.Y and math.abs(here.Z) <= half.Z
		end
		for _, p in model:GetDescendants() do
			-- Visible parts only: the face plates (invisible, decal only) and the root keep as they are.
			if p:IsA("BasePart") and p.Transparency < 0.9 and p.Name ~= "HumanoidRootPart" then
				local spec = look.regions and look.regions[regionOf(p)] or look.statue
				if not wornOverHead(p) then
					paint(p, spec)
				else
					-- A face worn as a texture: the piece takes the statue's material, its texture stays and is tinted
					-- the statue's colour, so the face shows in darker gold like every other statue's. A SpecialMesh
					-- tints its own texture; a MeshPart's can't be, so each client washes it with a Highlight.
					local color, material, reflectance = table.unpack(spec)
					p.Material = material
					p.Reflectance = reflectance
					p.Color = color
					local mesh = p:FindFirstChildOfClass("SpecialMesh")
					if mesh and mesh.TextureId ~= "" then
						mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
					elseif p:IsA("MeshPart") or p:FindFirstChildWhichIsA("SurfaceAppearance") then
						p:SetAttribute("StatueTint", color)
						CollectionService:AddTag(p, "StatueFace")
					end
				end
			end
		end
		-- Face decals take the statue's colour too: features stay, in darker gold.
		for _, d in model:GetDescendants() do
			if d:IsA("Decal") and d.Parent:IsA("BasePart") then
				local spec = look.regions and look.regions[regionOf(d.Parent)] or look.statue
				d.Color3 = spec[1]
			end
		end
		if look.cycle then
			CollectionService:AddTag(model, "RainbowMutation")
		end
	end
	local root = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model.PrimaryPart
	if not root then
		return
	end
	local k = model:GetScale()
	local light = Instance.new("PointLight")
	light.Name = "Mutation"
	light.Color = look.light
	light.Range = 12 * k
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = root
end

-- Clients cycle Rainbow statues through the colours, constantly.
function MutationLook.startClient()
	local tracked = {}
	local function add(model)
		local parts = {}
		for _, p in model:GetDescendants() do
			local shell = p:IsA("BasePart") and p.Transparency < 0.9 and p.Name ~= "HumanoidRootPart"
			local face = p:IsA("Decal") or (p:IsA("SpecialMesh") and p.TextureId ~= "") -- (faces cycle too)
			if shell or face then
				table.insert(parts, p)
			end
		end
		tracked[model] = parts
	end
	for _, m in CollectionService:GetTagged("RainbowMutation") do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("RainbowMutation"):Connect(function(m)
		task.delay(0.5, add, m) -- after the model has replicated
	end)
	CollectionService:GetInstanceRemovedSignal("RainbowMutation"):Connect(function(m)
		tracked[m] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		local color = Color3.fromHSV(os.clock() * 0.3 % 1, 0.85, 1)
		for model, shells in tracked do
			if not model.Parent then
				tracked[model] = nil
				continue
			end
			for _, s in shells do
				if s:IsA("Decal") then
					s.Color3 = color
				elseif s:IsA("SpecialMesh") then
					s.VertexColor = Vector3.new(color.R, color.G, color.B)
				else
					s.Color = color
					if s:GetAttribute("StatueTint") then
						s:SetAttribute("StatueTint", color)
					end
				end
			end
		end
	end)
	MutationLook.startFaceTint()
end

-- Face textures on MeshParts (Roblox can't tint them) get a Highlight fill in the statue's colour, on that one
-- piece only, so the face reads as gold like every other statue's. Highlights are drawn per screen and Roblox draws
-- about 31 at once (fighter outlines and auras use most), so only the nearest FACE_LIMIT faces get one; a far face
-- keeps its colours, a few pixels at that distance.
local FACE_LIMIT = 6
function MutationLook.startFaceTint()
	local glow = {} -- face part -> Highlight
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			for part, h in glow do
				local tint = part:GetAttribute("StatueTint")
				if tint and h.FillColor ~= tint then
					h.FillColor = tint
				end
			end
			return
		end
		acc = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local here = camera.CFrame.Position
		local faces = {}
		for _, part in CollectionService:GetTagged("StatueFace") do
			if part:IsDescendantOf(workspace) then
				table.insert(faces, { part = part, d = (part.Position - here).Magnitude })
			end
		end
		table.sort(faces, function(a, b)
			return a.d < b.d
		end)
		local keep = {}
		for i = 1, math.min(FACE_LIMIT, #faces) do
			local part = faces[i].part
			keep[part] = true
			if not glow[part] then
				local h = Instance.new("Highlight")
				h.Name = "StatueFaceTint"
				h.Adornee = part
				h.FillColor = part:GetAttribute("StatueTint") or Color3.new(1, 0.84, 0.3)
				h.FillTransparency = 0.35
				h.OutlineTransparency = 1
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Parent = part
				glow[part] = h
			end
		end
		for part, h in glow do
			if not keep[part] then
				h:Destroy()
				glow[part] = nil
			end
		end
	end)
end

return MutationLook
