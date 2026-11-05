-- Training poses for every R15 player, written over the default animation each frame (Stepped runs after
-- the Animator):
--   punch (click anywhere, and every station: they're all posts and bags): a boxer's guard, then straight
--     punches driven from the hip with the torso turning into them, and front kicks; the local player's
--     strike fires on each click,
--   carry: holding a fighter overhead on the way home,
--   burst: the power-up pose (fists down, head back) for a moment after a tier-up.
-- Who trains comes from player attributes (Training, TrainStation) set by the server; the local player
-- also starts at once on their own click so it never feels laggy.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Training = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Training"))

local TrainPose = {}
local localPlayer = Players.LocalPlayer
local RANGE = 160

local joints = {} -- [character] = { [name] = Motor6D }
local bursts = {} -- [player] = until (os.clock)
local localActiveUntil = 0
local jab = { move = 4, at = 0 } -- the local player's last strike (1..4) and when
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

-- A straight punch: out in 0.07 s, held a beat at full reach, back to guard over 0.17 s (0 = guard,
-- 1 = full extension).
local function jabCurve(dt)
	if dt < 0 then
		return 0
	elseif dt < 0.07 then
		local k = dt / 0.07
		return 1 - (1 - k) * (1 - k) -- fast out, easing into the hit
	elseif dt < 0.11 then
		return 1
	elseif dt < 0.28 then
		return 1 - (dt - 0.11) / 0.17
	end
	return 0
end

local POSES = {}

-- Strikes cycle right jab, left jab, right kick, left kick, so arms and legs both train.
-- `move` is 1..4 in that order; `amount` 0 (guard) .. 1 (full extension).
function POSES.punch(j, t, p)
	local move, amount
	if p.isLocal then
		move, amount = jab.move, jabCurve(os.clock() - jab.at)
	else
		local phase = (t * 5) % 4
		move, amount = math.floor(phase) + 1, jabCurve(phase % 1 * 0.3)
	end
	local kick = move >= 3
	local strikeSide = (move == 1 or move == 3) and "Right" or "Left"
	-- Guard: elbows tucked by the ribs, fists up at the chin. A punch drives the upper arm up to shoulder
	-- height and straightens the elbow so the fist travels straight out from the chin, angled a little in
	-- toward the centre line; the other fist stays at the chin.
	local function arm(prefix, sx)
		if not kick and prefix == strikeSide then
			-- (The inward turn goes first, about the shoulder's upright axis; after the lift it would twist the
			-- arm instead.)
			set(j, prefix .. "Shoulder", CFrame.Angles(0, sx * 0.22 * amount, 0) * rx(0.55 + 1.05 * amount))
			set(j, prefix .. "Elbow", rx(2.1 * (1 - amount) + 0.04))
		else
			set(j, prefix .. "Shoulder", CFrame.Angles(0, sx * 0.18, 0) * rx(0.55))
			set(j, prefix .. "Elbow", rx(2.1))
		end
	end
	arm("Right", 1)
	arm("Left", -1)
	-- The torso turns into the punch (the power comes from the hips), and back to square in guard.
	local turn = (strikeSide == "Right" and 0.45 or -0.45) * amount
	if kick then
		-- A front kick: the hip swings the leg up, the knee snaps straight; lean back a touch.
		local other = strikeSide == "Right" and "Left" or "Right"
		set(j, strikeSide .. "Hip", rx(1.5 * amount))
		set(j, strikeSide .. "Knee", rx(-1.4 * (1 - amount) - 0.05))
		set(j, other .. "Hip", rx(-0.1))
		set(j, other .. "Knee", rx(-0.3))
		set(j, "Waist", rx(-0.18 * amount) * CFrame.Angles(0, turn * 0.5, 0))
	else
		set(j, "Waist", CFrame.Angles(0, turn, 0))
		set(j, "RightHip", rx(-0.15))
		set(j, "LeftHip", rx(0.3))
		set(j, "RightKnee", rx(-0.25))
		set(j, "LeftKnee", rx(-0.35))
	end
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
	local shake = math.noise(t * 30, 0.5) * 0.06
	set(j, "Root", CFrame.new(0, -0.4, 0))
	set(j, "RightShoulder", rx(-0.25) * CFrame.Angles(0, 0, 0.55 + shake))
	set(j, "LeftShoulder", rx(-0.25) * CFrame.Angles(0, 0, -0.55 - shake))
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
	localActiveUntil = os.clock() + Training.ActiveFor
	jab.move = jab.move % 4 + 1
	jab.at = os.clock()
end

local function index(model)
	local id = model:GetAttribute("StationId")
	if id then
		stations[id] = model
	end
end

function TrainPose.start()
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
			-- punch-and-kick rhythm everyone else's do, so it moves too.
			local isLocal = player == localPlayer and not (player:GetAttribute("AutoTrainOn") and now - jab.at > 0.6)
			local station = player:GetAttribute("TrainStation")
			local active = player:GetAttribute("Training") ~= nil or (isLocal and now < localActiveUntil)
			local style
			if (bursts[player] or 0) > now then
				style = "burst"
			elseif player:GetAttribute("Carrying") and not station then
				style = "carry"
			elseif station or active then
				style = "punch"
			end
			if not style then
				continue
			end
			-- At a station but idle: hold the guard at a slow tempo.
			local tempo = (active or style == "burst" or style == "carry") and 1 or 0.25
			local t = now * tempo + (player.UserId % 100) * 0.1
			POSES[style](jointsOf(character), t, { isLocal = isLocal })
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
					since = active and (t * 2.5) % 1 / 2.5 or 99
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
		if player.Character then
			joints[player.Character] = nil
		end
	end)
end

return TrainPose
