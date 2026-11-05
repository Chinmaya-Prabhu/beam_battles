-- Builds display fighters from ReplicatedStorage.Assets.Fighters (made by tools/pack/strip_pack.py).
--
-- Every part is anchored and placed by solving the rig's joints from the HumanoidRootPart, so a
-- pose is just a rotation on a Motor6D and nothing depends on physics or animation assets.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local FighterAura = require(script.Parent.FighterAura)
local Fighters = require(script.Parent.Fighters)
local Poses = require(script.Parent.Poses)
local MutationLook = require(script.Parent.MutationLook)

local FighterModels = {}

-- The parts a fighter stands on (R15, then R6).
local FEET = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }

local JOINT_CLASSES = { Motor6D = true, Weld = true, ManualWeld = true, Snap = true, Motor = true, Glue = true }

local function source(key)
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	folder = folder and folder:FindFirstChild("Fighters")
	local fighter = Fighters.ByKey[key]
	return folder and fighter and folder:FindFirstChild(fighter.model)
end

-- Places every part reachable from the root through joints. Joints use C0 * pose * C1^-1, exactly
-- what Roblox enforces for an active joint (the pose only applies to Motor6Ds). Saved part positions
-- can't be trusted: the pack stored accessories (hair, headbands) away from the body and its morph
-- scripts snapped them on. Only WeldConstraints, which have no offsets, keep the saved placement.
local function solve(model, root, pose)
	local links = {}
	local function link(a, b, rel)
		links[a] = links[a] or {}
		table.insert(links[a], { to = b, rel = rel })
		links[b] = links[b] or {}
		table.insert(links[b], { to = a, rel = rel:Inverse() })
	end
	-- Some rigs also weld their arms to the torso; Motor6Ds go first so they win and poses apply.
	local joints = model:GetDescendants()
	local function posed(j)
		return j:IsA("Motor6D") or j:IsA("AnimationConstraint")
	end
	table.sort(joints, function(a, b)
		return posed(a) and not posed(b)
	end)
	for _, joint in joints do
		if JOINT_CLASSES[joint.ClassName] and joint.Part0 and joint.Part1 then
			local turn = joint:IsA("Motor6D") and pose and pose[joint.Name] or CFrame.identity
			link(joint.Part0, joint.Part1, joint.C0 * turn * joint.C1:Inverse())
		elseif joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
			-- Newer R15 rigs: Part1 = Part0 * Attachment0 * Transform * Attachment1^-1.
			local a0, a1 = joint.Attachment0, joint.Attachment1
			local turn = pose and pose[joint.Name] or CFrame.identity
			if a0.Parent:IsA("BasePart") and a1.Parent:IsA("BasePart") then
				link(a0.Parent, a1.Parent, a0.CFrame * turn * a1.CFrame:Inverse())
			end
		elseif joint:IsA("WeldConstraint") and joint.Part0 and joint.Part1 then
			link(joint.Part0, joint.Part1, joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame))
		end
	end
	local placed = { [root] = root.CFrame }
	local queue = { root }
	while #queue > 0 do
		local part = table.remove(queue, 1)
		for _, edge in links[part] or {} do
			if not placed[edge.to] then
				placed[edge.to] = placed[part] * edge.rel
				table.insert(queue, edge.to)
			end
		end
	end
	for part, cf in placed do
		part.CFrame = cf
	end
end

local function quiet(model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.CastShadow = true
			item.Massless = true
		elseif item:IsA("Humanoid") then
			item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			item.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			item.BreakJointsOnDeath = false
			item.RequiresNeck = false
		elseif item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			-- Everything is anchored and placed; joints would only fight that.
			item.Enabled = false
		end
	end
end

-- Set by the server at start (FighterRig.template): builds and caches a fighter's R15 rig.
FighterModels.builder = nil

-- The model to clone: the cached R15 rig if there is one (or the server can build it), else the
-- pack's R6 original.
function FighterModels.template(key)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local r15 = assets and assets:FindFirstChild("R15")
	local cached = r15 and r15:FindFirstChild(key)
	if cached then
		return cached, true
	end
	local original = source(key)
	if original and FighterModels.builder then
		local built = FighterModels.builder(key, original)
		if built then
			return built, true
		end
	end
	return original, false
end

-- Returns a copy standing with its feet at `feet`, facing `look` (a direction).
-- R15 fighters stand in their rest pose with only the root anchored; clients pose and animate them
-- through their Motor6Ds (client/FighterAnimator.lua) using the "Pose" attribute.
-- R6 fallbacks are posed here by solving their joints. opts: scale, pose, parent, mutation, aura (a plain
-- fighter on show gets its rarity aura).
function FighterModels.spawn(key, feet, look, opts)
	opts = opts or {}
	local template, isR15 = FighterModels.template(key)
	if not template then
		warn("[Fighters] no model for", key)
		return nil
	end
	local model = template:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	model.PrimaryPart = root
	if opts.scale and opts.scale ~= 1 then
		-- ScaleTo is absolute: multiply, so a big original (Whitebeard, the titans: FighterRig bakes in 2.2-2.6)
		-- keeps its own size under the context's scale.
		model:ScaleTo(model:GetScale() * opts.scale)
	end
	local pose = opts.pose or Poses.forKey(key)
	if isR15 then
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = item == root
				item.CanCollide = false
				item.CanTouch = false
				item.CanQuery = false
				item.Massless = true
			elseif item:IsA("Humanoid") then
				item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				item.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				item.BreakJointsOnDeath = false
				item.RequiresNeck = false
				item:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			elseif item:IsA("Animator") then
				-- Clips are played by client/FighterAnimator.lua; Roblox's Animator would reset the
				-- joints every frame and erase them.
				item:Destroy()
			end
		end
	else
		if root then
			solve(model, root, Poses.List[pose])
		end
		quiet(model)
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	model:PivotTo(CFrame.lookAt(model:GetPivot().Position, model:GetPivot().Position + flat))
	-- Stand on the feet, not on the lowest thing attached: a weapon or cape hanging below the feet
	-- (Whitebeard's naginata) would otherwise lift the whole fighter into the air.
	local box = model:GetBoundingBox()
	local bottom
	for _, name in FEET do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			local low = p.Position.Y - p.Size.Y / 2
			bottom = bottom and math.min(bottom, low) or low
		end
	end
	if not bottom then
		local _, size = model:GetBoundingBox()
		bottom = box.Position.Y - size.Y / 2
	end
	model:PivotTo(model:GetPivot() + (feet - Vector3.new(box.Position.X, bottom, box.Position.Z)))
	model:SetAttribute("FighterKey", key)
	model:SetAttribute("Pose", pose)
	local mutated = opts.mutation and opts.mutation ~= "Normal"
	if mutated then
		MutationLook.apply(model, opts.mutation) -- the mutation's look on the body (shared/MutationLook.lua)
	end
	if mutated or opts.aura then
		-- The aura in the fighter's anime style (shared/FighterAura.lua), sized by rarity.
		local fighter = Fighters.ByKey[key]
		if fighter then
			FighterAura.apply(model, key, fighter.rarity, opts.mutation, fighter.series)
		end
	end
	model.Parent = opts.parent or workspace
	if isR15 then
		CollectionService:AddTag(model, "Fighter")
	end
	return model
end

-- Holds a fighter in the last frame of a clip (shared/Clips.lua) by placing its parts through the
-- joints. For fighters in a ViewportFrame, where nothing simulates joints and FighterAnimator doesn't
-- reach: the Index, the Bag and the summon reveal show each fighter in its signature pose.
local clips
function FighterModels.holdPose(model, clipName)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if not model:FindFirstChild("UpperTorso") then
		-- An R6 original: its own version of the pose (shared/Poses.lua).
		if Poses.List[clipName] then
			solve(model, root, Poses.List[clipName])
		end
		return
	end
	clips = clips or require(script.Parent.Clips)
	local clip = clips[clipName]
	if not clip then
		return
	end
	local frame = clip.frames[#clip.frames]
	local pose = {}
	for joint, f in frame do
		pose[joint] = CFrame.new(f[5], f[6], f[7], f[1], f[2], f[3], f[4])
	end
	-- Live joints would drag the whole rig along with each part placed: anchor it and switch them off.
	quiet(model)
	solve(model, root, pose)
end

-- Viewport animation (the daily prize cards): freeze() once, then setPose() every frame with { jointName = CFrame }
-- (what FighterAnimator.view builds from a clip). Parts are placed through the joints, as holdPose does.
function FighterModels.freeze(model)
	quiet(model)
end

function FighterModels.setPose(model, pose)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root then
		solve(model, root, pose)
	end
end

-- Big originals (Whitebeard, the titans) are big already: FighterRig scales their R15 body to the pack's own.
function FighterModels.scaleFor(_, context)
	return Config.Scale[context] or 1
end

function FighterModels.has(key)
	return source(key) ~= nil
end

return FighterModels
