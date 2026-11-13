-- Converts the pack's R6 fighters into R15 rigs (elbows, knees, wrists, waist) that keep their look:
-- shirt and pants (the same templates render on R15), body colours, the pack's own head and face (on an
-- invisible R15 head), and every item attached to the body (hair, hats, scarves, swords), re-anchored to the
-- matching R15 joint.
--
-- Templates are built once per fighter with Roblox's own R15 builder and cached in
-- ReplicatedStorage.Assets.R15 so both server and clients can clone them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FighterRig = {}

-- Pack fighters that came without something (checked in the launch face check, 2026-10-21):
-- FACE_FROM: no eyes in the pack (Sage Mode only has whiskers): borrow another fighter's face decal.
-- OUTFIT: their Shirt/Pants images no longer load on Roblox: paint the outfit on the body instead
-- { shirt, shorts, shoes } (arms and torso, upper legs, feet).
-- true: every R15 body part is hidden; a set: just those (Frieza's torso is invisible in his model, his limbs are not).
-- (Jaw and Cart Titan are meshes on an invisible skeleton built in tools/pack/split_assets.py.)
local HIDDEN_BODY =
	{ GoldenFrieza = true, Frieza = { UpperTorso = true, LowerTorso = true }, JawTitan = true, CartTitan = true }
-- The biggest body a fighter keeps (Whitebeard is 2.6x a normal avatar): a model built larger than this (Cell Max
-- is 12x) is scaled down to it, so nothing towers over its altar, stand or card.
local MAX_BODY = 2.6
-- Fighters drawn at a set size: 2.565 is Whitebeard's (the biggest original body in the pack); 1.8 sits between his and a
-- normal avatar.
local GIANT = 2.565
-- Every fighter's size, from their height in the anime (a normal adult, about 1.8 m, is 1; anyone not listed is 1).
-- GIANT is Whitebeard's 6.7 m, the biggest body a fighter keeps (MAX_BODY): the true giants (Kaido, Big Mom, Cell Max,
-- the 15 m titans) share it so nothing buries its altar. The Jaw Titan is one of the small, fast ones, the Cart Titan
-- walks on four legs (1.5 keeps its length near Whitebeard's height).
local BODY_SCALE = {
	-- Giants
	Whitebeard = GIANT,
	Kaido = GIANT,
	BigMom = GIANT,
	CellMax = GIANT,
	AttackTitan = GIANT,
	FemaleTitan = GIANT,
	ArmoredTitan = GIANT,
	BeastTitan = GIANT,
	Mahoraga = 1.8,
	JawTitan = 1.7,
	CartTitan = 1.5,
	-- Tall: the Admirals and the other 3 m giants of the sea, then the big ones
	Akainu = 1.6,
	Kizaru = 1.6,
	Aokiji = 1.6,
	Doflamingo = 1.6,
	Fujitora = 1.5,
	Sengoku = 1.5,
	Roger = 1.5,
	LssjBroly = 1.5,
	AwakenedSukuna = 1.4, -- (the Heian form)
	Broly = 1.3,
	AllMightMode = 1.3,
	AllMight = 1.25,
	Gyomei = 1.25,
	Cell = 1.15,
	Mihawk = 1.1,
	Shanks = 1.1,
	Snakeman = 1.1,
	Hellflame = 1.1,
	Erwin = 1.05,
	Jiraiya = 1.05,
	Hashirama = 1.05,
	Rayleigh = 1.05,
	GojoSatoru = 1.05,
	GojoSatoruBlindfoldOff = 1.05,
	-- Small
	Eri = 0.75, -- (a child)
	Shinobu = 0.85,
	Nezuko = 0.85,
	Frieza = 0.85,
	GoldenFrieza = 0.85,
	Levi = 0.9,
	Muichiro = 0.9,
	Iguro = 0.9,
	Tanjiro = 0.95,
	Zenitsu = 0.95,
	Inosuke = 0.95,
	Mitsuri = 0.95,
	Mikasa = 0.95,
	Sasha = 0.95,
	Tsunade = 0.95,
	Gaara = 0.95,
	Deku = 0.95,
}
-- A normal R15 avatar from the top of its head to the soles of its feet (studs). Hand-made R15 fighters are sized
-- by their body, never their sword or hair: Armored Titan came in at 48 studs.
local R15_HEIGHT = 5.2

-- Head top to feet, from the body parts only.
local function bodyHeight(rig)
	local head = rig:FindFirstChild("Head")
	local feet = { rig:FindFirstChild("LeftFoot"), rig:FindFirstChild("RightFoot") }
	if not (head and head:IsA("BasePart") and feet[1] and feet[2]) then
		return nil
	end
	local bottom = math.min(feet[1].Position.Y - feet[1].Size.Y / 2, feet[2].Position.Y - feet[2].Size.Y / 2)
	return head.Position.Y + head.Size.Y / 2 - bottom
end
local FACE_FROM = { SageMode = "Tsnaruto" }
-- Packs that switched faces with a script: the face that works is saved hidden and the one shown points
-- at a deleted image, so the head is blank. [key] = the decal to show (the other front decals on its part go).
local FACE_SHOW = { Vegito = "Face1", VegitoBlue = "Face1" }
local KILLUA = { Color3.fromRGB(45, 55, 95), Color3.fromRGB(215, 200, 165), Color3.fromRGB(40, 40, 50) }
local OUTFIT = { Killua = KILLUA, KilluaGodspeed = KILLUA }
-- PANTS: only the Pants image is dead (the shirt still loads): paint just the legs { shorts, shins, feet }.
local LUFFY_LEGS = { Color3.fromRGB(40, 78, 160), nil, Color3.fromRGB(150, 105, 60) } -- blue shorts, sandals
local PANTS = { Ptsluffy = LUFFY_LEGS } -- (Tsluffy is a hand-made model with its own outfit: left exactly as made)
local SHIRT = {
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	RightUpperArm = true,
	LeftLowerArm = true,
	RightLowerArm = true,
}
local SHORTS = { LeftUpperLeg = true, RightUpperLeg = true }
local SHOES = { LeftFoot = true, RightFoot = true }

-- A fighter's front face decal (not the "roblox" torso logo).
local function faceDecal(model)
	for _, d in model:GetDescendants() do
		if d:IsA("Decal") and d.Name ~= "roblox" and d.Face == Enum.NormalId.Front then
			return d
		end
	end
	return nil
end

local BODY6 = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	HumanoidRootPart = true,
}

local function cache()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local folder = assets:FindFirstChild("R15")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "R15"
		folder.Parent = assets
	end
	return folder
end

-- R6 joint points, from the torso, in a pose with no animation: neck, shoulders and hips.
local function r6Anchors(torso)
	local cf = torso.CFrame
	-- (Every distance grows with the body: for Kaido, Whitebeard or a titan the neck is 2.5 studs up, not 1, and with
	-- the standard numbers the head was put 1.5 studs too high: floating off the body.)
	local k = torso.Size.Y / 2
	return {
		Head = cf * CFrame.new(0, k, 0),
		Torso = cf * CFrame.new(0, k, 0),
		["Right Arm"] = cf * CFrame.new(k, 0.5 * k, 0),
		["Left Arm"] = cf * CFrame.new(-k, 0.5 * k, 0),
		["Right Leg"] = cf * CFrame.new(0.5 * k, -k, 0),
		["Left Leg"] = cf * CFrame.new(-0.5 * k, -k, 0),
	}
end

local function attachmentCFrame(model, partName, attachmentName)
	local p = model:FindFirstChild(partName)
	local a = p and p:FindFirstChild(attachmentName)
	return a and a.WorldCFrame
end

-- The same joint points on the R15 rig, oriented like the root.
local function r15Anchors(rig)
	local rot = rig.HumanoidRootPart.CFrame.Rotation
	local function at(partName, attachmentName)
		local cf = attachmentCFrame(rig, partName, attachmentName)
		return cf and (CFrame.new(cf.Position) * rot)
	end
	local neck = at("UpperTorso", "NeckRigAttachment")
	return {
		Head = neck,
		Torso = neck,
		["Right Arm"] = at("UpperTorso", "RightShoulderRigAttachment"),
		["Left Arm"] = at("UpperTorso", "LeftShoulderRigAttachment"),
		["Right Leg"] = at("LowerTorso", "RightHipRigAttachment"),
		["Left Leg"] = at("LowerTorso", "LeftHipRigAttachment"),
	}
end

-- Which R15 segment carries an item that sat on an R6 limb, from how far down the limb it is.
local DEFAULT_FACE = { Cell = true }

local function segmentFor(region, offset, k)
	local y = offset.Position.Y / k
	if region == "Head" then
		return "Head"
	elseif region == "Torso" then
		return y < -1.4 and "LowerTorso" or "UpperTorso"
	end
	local side = string.find(region, "Right") and "Right" or "Left"
	if string.find(region, "Arm") then
		return side .. (y < -1.3 and "Hand" or y < -0.6 and "LowerArm" or "UpperArm")
	end
	return side .. (y < -1.6 and "Foot" or y < -0.8 and "LowerLeg" or "UpperLeg")
end

-- Finds, for every non-body part, the R6 body part it is (eventually) attached to.
local function regions(source)
	local links = {}
	local function link(a, b)
		links[a] = links[a] or {}
		links[b] = links[b] or {}
		table.insert(links[a], b)
		table.insert(links[b], a)
	end
	for _, joint in source:GetDescendants() do
		if (joint:IsA("JointInstance") or joint:IsA("WeldConstraint")) and joint.Part0 and joint.Part1 then
			link(joint.Part0, joint.Part1)
		end
	end
	local region = {}
	local queue = {}
	for _, p in source:GetChildren() do
		if p:IsA("BasePart") and BODY6[p.Name] and p.Name ~= "HumanoidRootPart" then
			region[p] = p.Name
			table.insert(queue, p)
		end
	end
	-- Hand-made fighters (tools/pack/custom) parent their coat, sleeves and shorts straight under the limb
	-- they sit on, with no weld: those belong to that limb too.
	for _, p in queue do
		for _, d in p:GetDescendants() do
			if d:IsA("BasePart") and not BODY6[d.Name] and not region[d] then
				region[d] = region[p]
			end
		end
	end
	-- A piece welded to several body parts (an armband welded to the torso AND the arm) belongs to the nearest one,
	-- or it stays on the torso when the arm moves.
	local bodies = {}
	for _, p in source:GetChildren() do
		if p:IsA("BasePart") and BODY6[p.Name] and p.Name ~= "HumanoidRootPart" then
			bodies[p] = true
		end
	end
	local nearest = {}
	for part, around in links do
		if not BODY6[part.Name] then
			local best, bestDistance, onLimb = nil, math.huge, false
			for _, q in around do
				if bodies[q] then
					onLimb = onLimb or string.find(q.Name, "Arm") ~= nil or string.find(q.Name, "Leg") ~= nil
					local distance = (part.Position - q.Position).Magnitude
					if distance < bestDistance then
						best, bestDistance = q, distance
					end
				end
			end
			if best and onLimb then -- (hair and hats welded to head and torso stay as they were)
				nearest[part] = best
			end
		end
	end
	for part, body in nearest do
		region[part] = body.Name
	end
	while #queue > 0 do
		local p = table.remove(queue, 1)
		for _, q in links[p] or {} do
			-- (Only the rig's own body parts end the walk: a "Head" part nested inside a Head model, like Cell Max's,
			-- is just a link between the pieces of his head, and they all belong to the limb it hangs from.)
			if not region[q] and not (BODY6[q.Name] and q.Parent == source) then
				region[q] = region[p]
				table.insert(queue, q)
			end
		end
	end
	-- Anything the joints didn't reach (a morph welded through a part the walk stops at, a weapon on a hilt welded
	-- by a script that never ran) belongs to the nearest body part: never dropped (Whitebeard's bisento, Sasuke's
	-- sword, Golden Frieza's limbs and Six Paths Naruto's sleeves and shoes were).
	local bodyList = {}
	for p in bodies do
		table.insert(bodyList, p)
	end
	for _, p in source:GetDescendants() do
		if p:IsA("BasePart") and not region[p] and not (BODY6[p.Name] and p.Parent == source) then
			local best, bestDistance = nil, math.huge
			for _, b in bodyList do
				local distance = (p.Position - b.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = b, distance
				end
			end
			if best then
				region[p] = best.Name
			end
		end
	end
	return region
end

local function solveRest(source)
	-- Same joint solve as FighterModels, with no pose: every part at its rest offset from the root.
	local root = source:FindFirstChild("HumanoidRootPart")
	local links = {}
	local function link(a, b, rel)
		links[a] = links[a] or {}
		links[b] = links[b] or {}
		table.insert(links[a], { to = b, rel = rel })
		table.insert(links[b], { to = a, rel = rel:Inverse() })
	end
	local joints = source:GetDescendants()
	table.sort(joints, function(a, b)
		return a:IsA("Motor6D") and not b:IsA("Motor6D")
	end)
	for _, j in joints do
		if j:IsA("JointInstance") and j.Part0 and j.Part1 then
			link(j.Part0, j.Part1, j.C0 * j.C1:Inverse())
		elseif j:IsA("WeldConstraint") and j.Part0 and j.Part1 then
			link(j.Part0, j.Part1, j.Part0.CFrame:ToObjectSpace(j.Part1.CFrame))
		end
	end
	local placed = { [root] = root.CFrame }
	local queue = { root }
	while #queue > 0 do
		local p = table.remove(queue, 1)
		for _, e in links[p] or {} do
			if not placed[e.to] then
				placed[e.to] = placed[p] * e.rel
				table.insert(queue, e.to)
			end
		end
	end
	for p, cf in placed do
		p.CFrame = cf
	end
end

-- A body part by name, never a container that happens to share it.
local function bodyPart(model, name)
	for _, child in model:GetChildren() do
		if child.Name == name and child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

local function colorOf(source, name)
	local p = bodyPart(source, name)
	return p and p:IsA("BasePart") and p.Color or Color3.fromRGB(242, 243, 243)
end

function FighterRig.build(key, source)
	if source:FindFirstChild("UpperTorso") then
		-- Already R15 (hand-made fighters like Mihawk and Daki): used as built, with the clean-up tools/pack did.
		local rig = source:Clone()
		rig.Name = key
		for _, item in rig:GetDescendants() do
			if item:IsA("LuaSourceContainer") then
				item:Destroy()
			end
		end
		rig.PrimaryPart = rig:FindFirstChild("HumanoidRootPart")
		rig:SetAttribute("FighterKey", key)
		-- Its size: a set one (the titans), else as built but never bigger than the biggest body (MAX_BODY).
		local height = bodyHeight(rig)
		local bodyScale = 1
		if height and height > 0 then
			local want = math.min(BODY_SCALE[key] or 1, MAX_BODY) -- (not listed: a normal adult, however it was built)
			if math.abs(want * R15_HEIGHT / height - 1) > 0.03 then
				rig:ScaleTo(rig:GetScale() * want * R15_HEIGHT / height)
			end
			bodyScale = want
		end
		rig:SetAttribute("BodyScale", bodyScale)
		return rig
	end
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = colorOf(source, "Head")
	description.TorsoColor = colorOf(source, "Torso")
	description.LeftArmColor = colorOf(source, "Left Arm")
	description.RightArmColor = colorOf(source, "Right Arm")
	description.LeftLegColor = colorOf(source, "Left Leg")
	description.RightLegColor = colorOf(source, "Right Leg")
	local ok, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not ok or not rig then
		warn("[FighterRig] R15 build failed for", key, rig)
		return nil
	end
	rig.Name = key
	for _, item in rig:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end
	local src = source:Clone()
	local srcRoot = bodyPart(src, "HumanoidRootPart")
	local torso = bodyPart(src, "Torso")
	if torso and not srcRoot then
		-- A hand-made rig saved without its root part (Mahoraga): make one where the Torso is.
		srcRoot = Instance.new("Part")
		srcRoot.Name = "HumanoidRootPart"
		srcRoot.Size = Vector3.new(2, 2, 1)
		srcRoot.Transparency = 1
		srcRoot.CFrame = torso.CFrame
		srcRoot.Parent = src
	end
	if not (srcRoot and torso) then
		rig:Destroy()
		src:Destroy()
		return nil
	end
	-- Its size (BODY_SCALE, else a normal adult): scales every piece, joint and mesh with it.
	local wantBody = math.min(BODY_SCALE[key] or 1, MAX_BODY)
	if torso and math.abs(wantBody * 2 / torso.Size.Y - 1) > 0.01 then
		src:ScaleTo(src:GetScale() * wantBody * 2 / torso.Size.Y)
	end
	-- Big originals (Whitebeard, the titans) are R6 bodies scaled up evenly: grow the R15 body to match, so the
	-- pack's own head, hair and items sit on a body of their size instead of a standard-sized one.
	local bodyScale = torso.Size.Y / 2
	if math.abs(bodyScale - 1) > 0.01 then
		rig:ScaleTo(bodyScale)
	else
		bodyScale = 1
	end
	-- Line both rigs up at the origin in their rest poses.
	-- Parts parented straight under a limb with no joint (hand-made fighters: coat, sleeves, shorts) don't move when
	-- the body is put in its rest pose: remember where each sits on its limb and put it back after.
	local jointed = {}
	for _, j in src:GetDescendants() do
		if (j:IsA("JointInstance") or j:IsA("WeldConstraint")) and j.Part0 and j.Part1 then
			jointed[j.Part0], jointed[j.Part1] = true, true
		end
	end
	local nested = {}
	for _, limb in src:GetChildren() do
		if limb:IsA("BasePart") and BODY6[limb.Name] and limb.Name ~= "HumanoidRootPart" then
			for _, d in limb:GetDescendants() do
				if d:IsA("BasePart") and not BODY6[d.Name] and not jointed[d] then
					table.insert(nested, { part = d, limb = limb, rel = limb.CFrame:ToObjectSpace(d.CFrame) })
				end
			end
		end
	end
	-- Every part to the origin together first: a part with no joint to the root (Nezuko and Shinobu have no neck)
	-- would otherwise stay where the model was built while the joints carry the rest.
	local toOrigin = srcRoot.CFrame:Inverse()
	for _, p in src:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = toOrigin * p.CFrame
		end
	end
	srcRoot.CFrame = CFrame.new()
	solveRest(src)
	for _, n in nested do
		n.part.CFrame = n.limb.CFrame * n.rel
	end
	rig.HumanoidRootPart.CFrame = CFrame.new()
	for _, j in rig:GetDescendants() do
		if j:IsA("Motor6D") then
			j.Transform = CFrame.identity
		end
	end
	-- Joints only update parts when simulated; place R15 parts by their rig attachments instead.
	local rigRoot = rig.HumanoidRootPart
	local placed = { [rigRoot] = rigRoot.CFrame }
	local pending = true
	while pending do
		pending = false
		for _, j in rig:GetDescendants() do
			if j:IsA("Motor6D") and placed[j.Part0] and not placed[j.Part1] then
				placed[j.Part1] = placed[j.Part0] * j.C0 * j.C1:Inverse()
				j.Part1.CFrame = placed[j.Part1]
				pending = true
			end
		end
	end

	-- Clothing, face and body colours.
	for _, item in src:GetChildren() do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			item:Clone().Parent = rig
		end
	end
	-- The head stays the pack's own: its original Head (and FakeHead) with whatever draws the face (a decal,
	-- a textured mesh, a welded face part) ride on the R15 head, which turns invisible and loses Roblox's
	-- default face. Faces then match the source exactly, however the pack drew them.
	rig.Head.Transparency = 1
	for _, d in rig.Head:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end

	-- Every attached item moves to the matching R15 segment, keeping its place relative to the joint.
	local from, to = r6Anchors(torso), r15Anchors(rig)
	local region = regions(src)
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = rig
	local srcHead = bodyPart(src, "Head")
	if srcHead then
		region[srcHead] = "Head"
	end
	-- Every piece below gets its own weld to its new segment. Old welds between two pieces (the pack head and the
	-- hair welded to it) must go first: moving one piece while still welded to another that hasn't moved yet drags
	-- it back to where the model was built (Nezuko's head ended up 1000 studs away).
	-- The body is the rig's own Head, Torso and limbs only. A part with a body name inside a morph or a container
	-- (Cell Max's and Gogeta's real heads, a morph's own "Right Leg") is a piece like any other and moves too:
	-- skipping it threw it away with everything inside it.
	local isBody = {}
	for _, p in src:GetChildren() do
		if p:IsA("BasePart") and BODY6[p.Name] and p ~= srcHead then
			isBody[p] = true
		end
	end
	local function moving(part)
		return part and region[part] and not isBody[part]
	end
	for _, j in src:GetDescendants() do
		if (j:IsA("JointInstance") or j:IsA("WeldConstraint")) and (moving(j.Part0) or moving(j.Part1)) then
			j:Destroy()
		end
	end
	for part, r in region do
		if moving(part) and from[r] and to[r] then
			local offset = from[r]:ToObjectSpace(part.CFrame)
			local segment = rig:FindFirstChild(segmentFor(r, offset, torso.Size.Y / 2))
			if segment then
				for _, j in part:GetChildren() do
					if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
						j:Destroy()
					end
				end
				if part == srcHead then
					part.Name = "PackHead" -- "Head" stays the R15 joint part
				end
				part.Parent = items
				part.CFrame = to[r] * offset
				part.Anchored = false
				part.Massless = true
				part.CanCollide = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = segment
				weld.Part1 = part
				weld.Parent = part
				-- Parts kept inside this one (the Cart Titan's meshes, a Jaw Titan claw) ride on it: weld each, or they
				-- come loose and fall the moment the fighter spawns.
				for _, d in part:GetDescendants() do
					if d:IsA("BasePart") and not region[d] then
						d.Anchored = false
						d.Massless = true
						d.CanCollide = false
						local hold = Instance.new("WeldConstraint")
						hold.Part0 = part
						hold.Part1 = d
						hold.Parent = d
					end
				end
			end
		end
	end
	-- (Studio: anything visible still left in the source is lost from the fighter. Say so, with why.)
	if RunService:IsStudio() then
		local lost = {}
		for _, p in src:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 0.95 and not isBody[p] then
				local r = region[p]
				table.insert(
					lost,
					string.format(
						"%s<%s> region=%s moving=%s",
						p.Name,
						p.Parent and p.Parent.Name or "?",
						tostring(r),
						tostring(moving(p) and true or false)
					)
				)
			end
		end
		if #lost > 0 then
			warn("[FighterRig] " .. key .. " lost " .. #lost .. " pieces: " .. table.concat(lost, "; "))
		end
	end
	src:Destroy()
	-- Packs that draw the face on a "FakeHead" put it exactly where the real head is; the two fight over
	-- which draws in front and the face can vanish. The FakeHead is a whole head itself, so hide the real one.
	local fakeHead = items:FindFirstChild("FakeHead")
	local packHead = items:FindFirstChild("PackHead")
	if fakeHead and packHead and fakeHead:FindFirstChildWhichIsA("Decal") then
		packHead.Transparency = 1
	end
	local donorKey = FACE_FROM[key]
	if donorKey then
		local folder = ReplicatedStorage.Assets:FindFirstChild("Fighters")
		local donor = folder and folder:FindFirstChild(donorKey)
		local face = donor and faceDecal(donor)
		local mark = faceDecal(rig) -- the decal already there (whiskers): the face goes on the same part
		if face and mark and string.find(mark.Texture, "textures/face.png", 1, true) then
			mark.Texture = face.Texture -- (the default smiley: replaced, not drawn over)
		elseif face and mark then
			local copy = face:Clone()
			copy.Name = "face"
			copy.ZIndex = mark.ZIndex - 1 -- under the whiskers
			copy.Parent = mark.Parent
		end
	end
	-- Cell's pack head is a plain head: its face decal has no image (the original was deleted), so he stood
	-- blank. Roblox's own face is drawn on the head instead (a decal, so cards and the Bag show it too).
	if DEFAULT_FACE[key] and packHead and not packHead:FindFirstChildWhichIsA("Decal") then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = packHead
	end
	local show = FACE_SHOW[key]
	if show then
		for _, d in rig:GetDescendants() do
			if d:IsA("Decal") and d.Name == show then
				d.Transparency = 0
				for _, other in d.Parent:GetChildren() do
					if other:IsA("Decal") and other ~= d and other.Face == d.Face then
						other:Destroy()
					end
				end
			end
		end
	end
	local outfit = OUTFIT[key]
	if outfit then
		for _, c in rig:GetDescendants() do
			if c:IsA("Clothing") or c:IsA("BodyColors") then
				c:Destroy() -- BodyColors would paint the skin back over the outfit
			end
		end
		for _, part in rig:GetChildren() do
			if part:IsA("BasePart") then
				part.Color = SHIRT[part.Name] and outfit[1]
					or SHORTS[part.Name] and outfit[2]
					or SHOES[part.Name] and outfit[3]
					or part.Color
			end
		end
	end
	local legs = PANTS[key]
	if legs then
		for _, c in rig:GetDescendants() do
			if c:IsA("Pants") or c:IsA("BodyColors") then
				c:Destroy() -- (BodyColors would paint the skin back over the shorts)
			end
		end
		for _, part in rig:GetChildren() do
			if part:IsA("BasePart") then
				local shin = part.Name == "LeftLowerLeg" or part.Name == "RightLowerLeg"
				part.Color = SHORTS[part.Name] and legs[1]
					or shin and legs[2]
					or SHOES[part.Name] and legs[3]
					or part.Color
			end
		end
	end
	local hidden = HIDDEN_BODY[key]
	if hidden then
		-- Fighters whose look is their own meshes (the R6 body parts are invisible in the model): hide the R15 ones.
		for _, part in rig:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and (hidden == true or hidden[part.Name]) then
				part.Transparency = 1
			end
		end
	end
	rig:SetAttribute("FighterKey", key)
	rig:SetAttribute("BodyScale", bodyScale) -- 1 for a normal avatar, 2.2-2.6 for Whitebeard and the titans
	return rig
end

-- Returns the cached R15 template for a fighter, building it on first use.
function FighterRig.template(key, source)
	local folder = cache()
	local existing = folder:FindFirstChild(key)
	if existing then
		return existing
	end
	local rig = FighterRig.build(key, source)
	if rig then
		rig.Parent = folder
	end
	return rig
end

return FighterRig
