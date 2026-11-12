-- Training poses for every R15 player, written over the default animation each frame (Stepped runs after
-- the Animator):
--   punch (click anywhere, and every station: they're all posts and bags): an anime fighter's stance (low,
--     lead foot forward, leaning in), each punch pulled back a hair, snapped out with the hips turning
--     into it and the other fist pulled back to the hip; every hit lands with a flash, a shock ring and
--     sparks in the fighter's aura colour. Fast clicking turns into a barrage (ghost fists around each
--     punch) and every 10th punch in a row is a heavy finisher with a bigger blast and a camera kick. The
--     local player's strike fires on each click; everyone else (and auto training) punches to a beat,
--   carry: holding a fighter overhead on the way home,
--   burst: the power-up pose (fists down, head back) for a moment after a tier-up.
-- Who trains comes from player attributes (Training, TrainStation) set by the server; the local player
-- also starts at once on their own click so it never feels laggy.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Training = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Training"))

local TrainPose = {}
local localPlayer = Players.LocalPlayer
local RANGE = 160

local joints = {} -- [character] = { [name] = Motor6D }
local bursts = {} -- [player] = until (os.clock)
local localActiveUntil = 0
-- The local player's last strike: which arm (1 right, 2 left), when, how many in a row, and its kind.
local jab = { move = 2, at = 0, combo = 0, heavy = false, rush = false }
local clicks = {} -- the local player's recent click times (a barrage at RUSH_CPS)
local RUSH_CPS = 6
local BEAT = 4 -- punches a second for everyone else, and for auto training (Training.StationRate)
local FX_RANGE = 90
local impacts = {} -- queued hits: { player, at, side, heavy, rush }
local beats = {} -- [player] = the last beat index (to fire their hits)
local shake = 0 -- the local camera kick, decaying
local stations = {} -- [StationId] = model

local NAMES = {
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"RightElbow",
	"LeftShoulder",
	"LeftElbow",
	"RightHip",
	"RightKnee",
	"LeftHip",
	"LeftKnee",
}

local function jointsOf(character)
	local j = joints[character]
	if j and j.Root and j.RightShoulder then
		return j
	end
	j = {}
	for _, d in character:GetDescendants() do
		-- Newer R15 avatars joint their parts with AnimationConstraints; both take a Transform.
		if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and table.find(NAMES, d.Name) then
			j[d.Name] = d
		end
	end
	joints[character] = j
	return j
end

local function rx(a)
	return CFrame.Angles(a, 0, 0)
end

local function set(j, name, cf)
	local m = j[name]
	if m then
		m.Transform = cf
	end
end

-- One punch over time `dt` since it started: a short pull back (negative), a snap out easing into the hit,
-- a held beat at full reach, then back to guard. A heavy one winds up longer and holds longer; a barrage
-- skips the wind-up and returns fast. Returns the amount (-0.3 .. 1) and the time the fist lands.
local function strikeCurve(dt, heavy, rush)
	local wind = rush and 0 or heavy and 0.07 or 0.035
	local out = rush and 0.045 or 0.055
	local hold = heavy and 0.12 or rush and 0.02 or 0.05
	local back = rush and 0.09 or 0.16
	local land = wind + out
	if dt < 0 then
		return 0, land
	elseif dt < wind then
		return -0.3 * dt / wind, land
	elseif dt < land then
		local k = (dt - wind) / out
		return -0.3 + 1.3 * (1 - (1 - k) ^ 3), land
	elseif dt < land + hold then
		return 1, land
	elseif dt < land + hold + back then
		return 1 - (dt - land - hold) / back, land
	end
	return 0, land
end

local POSES = {}

-- The stance holds the lead (left) foot forward and the body low, so it never reads as running; each punch
-- comes from the hips: the waist turns into it, the body leans and lunges a little, the punching arm goes
-- out straight at shoulder height and the other fist pulls back to the hip (the classic chamber).
function POSES.punch(j, t, p)
	local move, amount, heavy
	if p.isLocal then
		move, heavy = jab.move, jab.heavy
		amount = strikeCurve(os.clock() - jab.at, jab.heavy, jab.rush)
	else
		local beat = t * BEAT
		move = math.floor(beat) % 2 + 1
		amount = strikeCurve((beat % 1) / BEAT, false, false)
	end
	local reach = math.max(amount, 0)
	local pull = math.min(amount, 0) -- the wind-up (negative)
	local strikeSide = move == 1 and "Right" or "Left"
	local power = heavy and 1.35 or 1
	local function arm(prefix, sx)
		if prefix == strikeSide then
			-- (The inward turn goes first, about the shoulder's upright axis; after the lift it would twist the
			-- arm instead.)
			set(j, prefix .. "Shoulder", CFrame.Angles(0, sx * 0.25 * reach, 0) * rx(0.55 + 1.05 * reach + 0.5 * pull))
			set(j, prefix .. "Elbow", rx(2.1 * (1 - reach) - 0.4 * pull + 0.03))
		else
			-- The other fist: up at the chin in guard, pulled back to the hip as the punch lands.
			set(j, prefix .. "Shoulder", CFrame.Angles(0, sx * 0.18, 0) * rx(0.55 - 0.95 * reach))
			set(j, prefix .. "Elbow", rx(2.1 - 0.35 * reach))
		end
	end
	arm("Right", 1)
	arm("Left", -1)
	local side = strikeSide == "Right" and 1 or -1
	local turn = side * (0.6 * reach * power - 0.25 * pull)
	set(j, "Root", CFrame.new(0, -0.22, -0.3 * reach * power) * rx(-0.1 - 0.12 * reach * power))
	set(j, "Waist", CFrame.Angles(0, turn, 0) * rx(-0.06 * reach))
	set(j, "Neck", CFrame.Angles(0, -turn * 0.8, 0) * rx(0.1)) -- eyes stay on the target
	set(j, "LeftHip", rx(0.5))
	set(j, "LeftKnee", rx(-0.55))
	set(j, "RightHip", rx(-0.3 + 0.1 * reach))
	set(j, "RightKnee", rx(-0.4))
end

-- Holding a fighter up overhead while running it home: both arms up under it with a small bounce in
-- step; the legs keep the normal run.
function POSES.carry(j, t)
	local bob = math.sin(t * 9) * 0.06
	set(j, "RightShoulder", rx(2.95 + bob) * CFrame.Angles(0, 0, 0.22))
	set(j, "LeftShoulder", rx(2.95 - bob) * CFrame.Angles(0, 0, -0.22))
	set(j, "RightElbow", rx(0.35))
	set(j, "LeftElbow", rx(0.35))
end

function POSES.burst(j, t)
	local jitter = math.noise(t * 30, 0.5) * 0.06
	set(j, "Root", CFrame.new(0, -0.4, 0))
	set(j, "RightShoulder", rx(-0.25) * CFrame.Angles(0, 0, 0.55 + jitter))
	set(j, "LeftShoulder", rx(-0.25) * CFrame.Angles(0, 0, -0.55 - jitter))
	set(j, "RightElbow", rx(0.6))
	set(j, "LeftElbow", rx(0.6))
	set(j, "Waist", rx(0.25))
	set(j, "Neck", rx(0.45))
	set(j, "RightHip", CFrame.Angles(0, 0, 0.22))
	set(j, "LeftHip", CFrame.Angles(0, 0, -0.22))
	set(j, "RightKnee", rx(-0.45))
	set(j, "LeftKnee", rx(-0.45))
end

function TrainPose.burst(player, seconds)
	bursts[player] = os.clock() + seconds
end

-- Called on every local click (client/Training.lua).
function TrainPose.rep()
	local now = os.clock()
	localActiveUntil = now + Training.ActiveFor
	jab.combo = now - jab.at < 0.6 and jab.combo + 1 or 1
	jab.move = jab.move % 2 + 1
	jab.at = now
	while clicks[1] and now - clicks[1] > 1 do
		table.remove(clicks, 1)
	end
	table.insert(clicks, now)
	jab.rush = #clicks >= RUSH_CPS
	jab.heavy = jab.combo % 10 == 0
	local _, land = strikeCurve(0, jab.heavy, jab.rush)
	table.insert(impacts, {
		player = localPlayer,
		at = now + land,
		side = jab.move == 1 and "Right" or "Left",
		heavy = jab.heavy,
		rush = jab.rush,
	})
end

-- ------------------------------------------------------------------ hit effects

local fxFolder = Instance.new("Folder")
fxFolder.Name = "PunchFX"

local function fxPart(shape, color, size, cf, trans)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Shape = shape
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = trans or 0
	p.Parent = fxFolder
	return p
end

local function fade(p, seconds, goal)
	goal.Transparency = 1
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, seconds + 0.05)
end

local sparks -- one emitter, moved to each hit
local function sparkAt(cf, color, count)
	if not sparks then
		local holder = fxPart(Enum.PartType.Block, Color3.new(1, 1, 1), Vector3.one * 0.1, cf, 1)
		sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Rate = 0
		sparks.Lifetime = NumberRange.new(0.15, 0.3)
		sparks.Speed = NumberRange.new(14, 26)
		sparks.SpreadAngle = Vector2.new(55, 55)
		sparks.Drag = 6
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparks.EmissionDirection = Enum.NormalId.Front
		sparks.Parent = holder
	end
	sparks.Parent.CFrame = cf
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparks:Emit(count)
end

local function auraColor(player)
	local _, aura = Training.aura(player:GetAttribute("Power") or 0)
	return aura and aura.color or Color3.fromRGB(150, 220, 255)
end

-- A hit landing: a white flash at the fist, a shock ring in the aura colour facing the way the punch goes,
-- sparks flying on; a barrage adds ghost fists around it, a heavy finisher a second, bigger ring.
local function impact(hit)
	local character = hit.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hand = character and character:FindFirstChild(hit.side .. "Hand")
	if not root or not hand then
		return
	end
	local look = root.CFrame.LookVector
	local at = hand.Position + look * 0.5
	local facing = CFrame.lookAt(at, at + look)
	local color = auraColor(hit.player)
	local hot = color:Lerp(Color3.new(1, 1, 1), 0.6) -- (white-hot, so it reads over the player's own aura)
	local big = hit.heavy and 1.7 or 1
	local flash = fxPart(Enum.PartType.Ball, Color3.new(1, 1, 1), Vector3.one * 0.7, CFrame.new(at), 0.05)
	fade(flash, 0.12, { Size = Vector3.one * 2.2 * big })
	local ringFrame = facing * CFrame.Angles(0, math.pi / 2, 0) -- (a cylinder's axis is its X)
	local ring = fxPart(Enum.PartType.Cylinder, hot, Vector3.new(0.08, 1, 1), ringFrame, 0.1)
	fade(ring, 0.2 * big, { Size = Vector3.new(0.04, 4.2 * big, 4.2 * big) })
	sparkAt(facing, color, hit.heavy and 16 or 6)
	if hit.heavy then
		task.delay(0.05, function()
			local second = fxPart(Enum.PartType.Cylinder, Color3.new(1, 1, 1), Vector3.new(0.08, 1.5, 1.5), ringFrame, 0.3)
			fade(second, 0.3, { Size = Vector3.new(0.04, 8, 8), CFrame = ringFrame * CFrame.new(-1.2, 0, 0) })
		end)
	end
	if hit.rush then
		-- Ghost fists: the barrage looks like a dozen fists at once.
		for _ = 1, 2 do
			local offset = facing * CFrame.new(math.random(-8, 8) / 10, math.random(-7, 7) / 10, 0.6)
			local ghost = fxPart(Enum.PartType.Ball, color, Vector3.one * 0.75, offset, 0.35)
			fade(ghost, 0.14, { CFrame = offset * CFrame.new(0, 0, -1.6), Size = Vector3.one * 0.45 })
		end
	end
	if hit.player == localPlayer then
		shake = math.max(shake, hit.heavy and 0.35 or hit.rush and 0.06 or 0.04)
	end
end

local function index(model)
	local id = model:GetAttribute("StationId")
	if id then
		stations[id] = model
	end
end

function TrainPose.start()
	fxFolder.Parent = workspace
	for _, m in CollectionService:GetTagged("TrainStation") do
		index(m)
	end
	CollectionService:GetInstanceAddedSignal("TrainStation"):Connect(index)

	local camera = workspace.CurrentCamera
	local swung, touched = {}, {}
	RunService.Stepped:Connect(function()
		local now = os.clock()
		local eye = camera.CFrame.Position
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
				continue
			end
			if (root.Position - eye).Magnitude > RANGE or player:GetAttribute("InClash") then
				continue
			end
			-- The local player's strikes follow their clicks; with Auto Train on (no clicks) they use the same
			-- punch rhythm everyone else's do, so it moves too.
			-- (So does training by itself at a station.)
			local auto = player:GetAttribute("AutoTrainOn") or player:GetAttribute("TrainStation")
			local isLocal = player == localPlayer and not (auto and now - jab.at > 0.6)
			local station = player:GetAttribute("TrainStation")
			local active = player:GetAttribute("Training") ~= nil or (isLocal and now < localActiveUntil)
			local style
			if (bursts[player] or 0) > now then
				style = "burst"
			elseif player:GetAttribute("Carrying") and not station then
				style = "carry"
			elseif station or (active and (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude < 2) then
				-- (Never while walking: planted punching legs on a moving body looked like sliding.)
				style = "punch"
			end
			if not style then
				continue
			end
			-- At a station but idle: hold the guard at a slow tempo.
			local tempo = (active or style == "burst" or style == "carry") and 1 or 0.25
			local t = now * tempo + (player.UserId % 100) * 0.1
			POSES[style](jointsOf(character), t, { isLocal = isLocal })
			-- Everyone else's hits (and auto training's) land on their beat.
			if style == "punch" and active and not isLocal then
				local beat = math.floor(t * BEAT)
				if beats[player] ~= beat then
					beats[player] = beat
					if (root.Position - eye).Magnitude < FX_RANGE then
						local _, land = strikeCurve(0, false, false)
						table.insert(impacts, {
							player = player,
							at = now + land,
							side = beat % 2 == 0 and "Right" or "Left",
						})
					end
				end
			end
			-- The sandbag only moves when it's being hit.
			local model = station and stations[station]
			local bag = model and model:FindFirstChild("Bag")
			if bag then
				local hinge = bag:GetAttribute("Hinge")
				-- Knock-back on every punch: a sharp kick away from the puncher, then a damped swing back.
				-- The local player's hits come from their clicks; other players' from their punch rhythm.
				local since
				if isLocal then
					since = now - jab.at
				else
					since = active and (t * BEAT) % 1 / BEAT or 99
				end
				local swing = 0
				if since < 1.6 then
					swing = 0.38 * math.exp(-since * 3.2) * math.sin(math.min(since * 14, math.pi / 2) + since * 9)
				end
				bag:PivotTo(hinge * CFrame.Angles(-swing, 0, 0)) -- positive swing = away from the puncher
				swung[bag] = true
				touched[bag] = true
			end
		end
		-- Hits whose fist has landed.
		for i = #impacts, 1, -1 do
			if now >= impacts[i].at then
				local hit = table.remove(impacts, i)
				if not hit.player:GetAttribute("InClash") then
					impact(hit)
				end
			end
		end
		-- The local camera kick.
		local myHumanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if myHumanoid and (shake > 0.005 or myHumanoid.CameraOffset ~= Vector3.zero) then
			if shake > 0.005 then
				myHumanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake
				shake *= 0.6
			else
				shake = 0
				myHumanoid.CameraOffset = Vector3.zero
			end
		end
				-- Bags nobody is hitting settle back.
		for bag in swung do
			if not touched[bag] then
				bag:PivotTo(bag:GetAttribute("Hinge"))
				swung[bag] = nil
			end
		end
		table.clear(touched)
	end)
	Players.PlayerRemoving:Connect(function(player)
		bursts[player] = nil
		beats[player] = nil
		if player.Character then
			joints[player.Character] = nil
		end
	end)
end

return TrainPose
