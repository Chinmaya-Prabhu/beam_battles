-- The guide beam (the big games' quest line): one straight glowing beam of scrolling chevrons from the
-- player's chest to the place they should go, and a pillar of light over the target.
-- It ignores walls and paths on purpose: a clean straight pointer reads at a glance.
--   ArrowPath.set(owner, target)  show the way to `target` (a Vector3) for `owner` ("Tutorial", "Carry", "Rush");
--                                 nil clears it. Carry wins, then Tutorial, then Rush.
-- The chevron texture is the "beam" art (art/atlas/anime_clash_beam.png); before it is uploaded the beam is
-- a plain glowing ribbon.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIAtlas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIAtlas"))

local ArrowPath = {}
local player = Players.LocalPlayer

local WIDTH = 3.6 -- (wide and bright: it has to read through auras and on a phone)
local COLOR = Color3.fromRGB(120, 255, 150)
local TEXTURE = (UIAtlas.Ids.beam or 0) ~= 0 and ("rbxassetid://" .. UIAtlas.Ids.beam) or nil

local targets = {} -- [owner] = Vector3
local folder, anchor, startAt, endAt, beam, glowBeam
local marker -- the light pillar over the target

local function buildBeam()
	anchor = Instance.new("Part")
	anchor.Name = "BeamAnchor"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new()
	anchor.Parent = folder
	startAt = Instance.new("Attachment")
	startAt.Parent = anchor
	endAt = Instance.new("Attachment")
	endAt.Parent = anchor
	beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = startAt, endAt
	beam.Width0, beam.Width1 = WIDTH, WIDTH
	beam.FaceCamera = true
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.Brightness = 1
	beam.Segments = 1 -- straight
	beam.Color = ColorSequence.new(COLOR)
	if TEXTURE then
		-- The chevron strip (art/ui/tutorial_guide_arrows.png): three > per tile, pointing from the player
		-- (Attachment0) to the target, scrolling the same way so they march toward it.
		beam.Texture = TEXTURE
		beam.Color = ColorSequence.new(Color3.new(1, 1, 1)) -- the art's own greens
		beam.LightEmission = 0.55
		beam.Brightness = 2.2
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureLength = WIDTH * 4 -- the tile is 1:4 (three chevrons stacked), so each keeps its shape
		beam.TextureSpeed = 1.2
		beam.Transparency = NumberSequence.new(0)
	else
		beam.Transparency = NumberSequence.new(0.1)
	end
	beam.Enabled = false
	beam.Parent = anchor
	-- A faint glow under the arrows, a little wider, so the path reads as one line from far away.
	glowBeam = Instance.new("Beam")
	glowBeam.Attachment0, glowBeam.Attachment1 = startAt, endAt
	glowBeam.Width0, glowBeam.Width1 = WIDTH * 1.6, WIDTH * 1.6
	glowBeam.FaceCamera = true
	glowBeam.Segments = 1
	glowBeam.LightEmission = 1
	glowBeam.LightInfluence = 0
	glowBeam.Color = ColorSequence.new(COLOR)
	glowBeam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0.45),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	glowBeam.ZOffset = -0.1
	glowBeam.Enabled = false
	glowBeam.Parent = anchor
end

-- A tall pillar of light on the target with a big arrow bobbing over it.
local function buildMarker()
	local m = Instance.new("Part")
	m.Name = "GuideMarker"
	m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
	m.Transparency = 1
	m.Size = Vector3.new(1, 1, 1)
	local bottom = Instance.new("Attachment")
	bottom.Parent = m
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 60, 0)
	top.Parent = m
	local pillar = Instance.new("Beam")
	pillar.Attachment0, pillar.Attachment1 = bottom, top
	pillar.Width0, pillar.Width1 = 5, 5
	pillar.FaceCamera = true
	pillar.LightEmission = 1
	pillar.LightInfluence = 0
	pillar.Color = ColorSequence.new(COLOR)
	pillar.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	pillar.Parent = m
	m.Parent = folder
	return m
end

local function active()
	return targets.Carry or targets.Tutorial or targets.Rush or targets.Train or targets.Quest
end

-- "TRAIN!" after losing to someone stronger (client/Clash.lua sets GoTrain): the beam points at the
-- nearest training station for a minute, or until you get there.
local function pointToGym()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local best, bestDist
	for _, m in game:GetService("CollectionService"):GetTagged("TrainStation") do
		local d = (m:GetPivot().Position - root.Position).Magnitude
		if not bestDist or d < bestDist then
			best, bestDist = m:GetPivot().Position, d
		end
	end
	targets.Train = best
	task.delay(60, function()
		if targets.Train == best then
			targets.Train = nil
		end
	end)
end

function ArrowPath.set(owner, target)
	targets[owner] = target
end

function ArrowPath.start()
	folder = Instance.new("Folder")
	folder.Name = "ArrowPath"
	folder.Parent = workspace
	buildBeam()
	marker = buildMarker()
	player:GetAttributeChangedSignal("GoTrain"):Connect(pointToGym)
	RunService.Heartbeat:Connect(function()
		local target = active()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if targets.Train and root and (root.Position - targets.Train).Magnitude < 10 then
			targets.Train = nil -- arrived
		end
		if
			not target
			or not root
			or (root.Position - target).Magnitude < 8
			or player:GetAttribute("InClash")
			or player:GetAttribute("ClashScreen")
		then
			beam.Enabled = false
			glowBeam.Enabled = false
			marker.Parent = nil
			return
		end
		-- From head height straight to just over the target: over the low props, under the camera (any higher
		-- and it is seen edge-on).
		local to = target + Vector3.new(0, 4, 0)
		local from = root.Position + Vector3.new(0, 2.5, 0)
		from += (to - from).Unit * 2.5
		startAt.WorldPosition, endAt.WorldPosition = from, to
		beam.Enabled = true
		glowBeam.Enabled = true
		marker.CFrame = CFrame.new(target)
		marker.Parent = folder
	end)
end

return ArrowPath
