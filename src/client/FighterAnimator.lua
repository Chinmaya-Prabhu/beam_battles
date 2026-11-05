-- Animates every R15 fighter on this client by writing each joint's Transform every frame from the clips
-- authored in Blender (tools/blender/r15_studio.py -> shared/Clips.lua).
--
-- Model attributes (set by the server):
--   Clip       name of the clip to play (default "Idle")
--   ClipStart  server time the clip started (so everyone sees the same moment)
-- One-shot clips (PowerUp, Victory, KO, Taunt) play once and then return to Idle.
-- Fighters out of range are skipped so a crowded island stays cheap.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FighterAnimator = {}
local Clips
local Dances = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dances"))
local FighterModels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FighterModels"))
local Fighters = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fighters"))
local DANCES = Dances.List

local RANGE = 220
local tracked = {}

-- Roblox builds R15 rigs with AnimationConstraints (older rigs and packs use Motor6Ds); both take a
-- Transform. The tag can replicate before the parts do, so joints are re-collected until all 15 exist.
local function collect(model)
	local joints, count = {}, 0
	for _, j in model:GetDescendants() do
		if j:IsA("Motor6D") or j:IsA("AnimationConstraint") then
			joints[j.Name] = j
			count += 1
		end
	end
	return joints, count
end

local function add(model)
	local joints, count = collect(model)
	-- Each fighter starts its idle at a different point so a row of them never moves in lockstep.
	local seed = 0
	for i = 1, #model.Name do
		seed += string.byte(model.Name, i)
	end
	-- Display fighters dance now and then; player characters and clash bots don't.
	local dances = not Players:GetPlayerFromCharacter(model) and not model:GetAttribute("Bot")
	-- Fighters on show idle by rarity (shared/Dances.lua); players and bots keep the guard.
	local fighter = Fighters.ByKey[model:GetAttribute("FighterKey") or ""]
	local idle = (dances and fighter) and Dances.idleFor(fighter.rarity) or "Idle"
	tracked[model] = { joints = joints, count = count, offset = (seed % 97) / 97 * 2, dances = dances, idle = idle }
end

local function sample(frame)
	return CFrame.new(frame[5], frame[6], frame[7], frame[1], frame[2], frame[3], frame[4])
end

-- The pose of `clip` at time t (seconds), blending between the two nearest sampled frames.
local function poseAt(clip, t)
	local count = #clip.frames
	local f = t * clip.fps
	local i
	if clip.loop then
		f = f % (count - 1)
		i = math.floor(f)
	else
		f = math.min(f, count - 1)
		i = math.min(math.floor(f), count - 2)
	end
	local a, b = clip.frames[i + 1], clip.frames[i + 2] or clip.frames[i + 1]
	local alpha = f - i
	return a, b, alpha
end

-- Animates a fighter shown in a ViewportFrame (the daily prize cards): a dance picked by its key, looping, until the
-- model is gone. Nothing simulates joints in a viewport, so every frame the clip's pose is written through
-- FighterModels.setPose (the way the Bag and Index place their still poses).
function FighterAnimator.view(model, key)
	if not Clips then
		return false
	end
	FighterModels.freeze(model)
	local seed = 0
	for i = 1, #key do
		seed += string.byte(key, i)
	end
	local clip = Clips[DANCES[seed % #DANCES + 1]] or Clips.Idle
	local length = (#clip.frames - 1) / clip.fps
	local began = os.clock()
	local conn
	local function step()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		local a, b, alpha = poseAt(clip, (os.clock() - began) % length)
		local pose = {}
		for jointName, fa in a do
			local fb = b[jointName]
			pose[jointName] = sample(fa):Lerp(fb and sample(fb) or sample(fa), alpha)
		end
		FighterModels.setPose(model, pose)
	end
	step()
	conn = RunService.RenderStepped:Connect(step)
	return true
end

function FighterAnimator.start()
	local ok, result = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Clips"))
	end)
	if not ok then
		warn("[FighterAnimator] clips failed to load:", result)
		return
	end
	Clips = result
	for _, m in CollectionService:GetTagged("Fighter") do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("Fighter"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Fighter"):Connect(function(m)
		tracked[m] = nil
	end)

	local camera = workspace.CurrentCamera
	RunService.Stepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local eye = camera.CFrame.Position
		for model, data in tracked do
			if not model.Parent then
				tracked[model] = nil
				continue
			end
			if data.count < 15 then
				data.joints, data.count = collect(model)
			end
			local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end
			if (root.Position - eye).Magnitude > RANGE then
				continue
			end
			local idle = Clips[data.idle] or Clips.Idle
			local name = model:GetAttribute("Clip") or "Idle"
			local clip = (name == "Idle" and idle) or Clips[name] or idle
			local start = model:GetAttribute("ClipStart")
			local t = start and (now - start) or (now + data.offset)
			local settled = not clip.loop and t * clip.fps >= #clip.frames - 1 + clip.fps * 0.6
			if settled or (name == "Idle" and not start) then
				-- Back in idle: hold the last frame briefly, then idle, with an occasional dance.
				clip, t = idle, now + data.offset
				if data.dances then
					data.danceAt = data.danceAt or now + 8 + math.random() * 20
					if data.dance and now >= data.dance.untilT then
						data.dance = nil
					end
					if not data.dance and now >= data.danceAt then
						data.danceAt = now + 15 + math.random() * 25
						if math.random() < 0.45 then
							local pick = DANCES[math.random(1, #DANCES)]
							local d = Clips[pick]
							data.dance = { clip = d, start = now, untilT = now + (#d.frames - 1) / d.fps * 3 }
						end
					end
					if data.dance then
						clip, t = data.dance.clip, now - data.dance.start
					end
				end
			end
			local a, b, alpha = poseAt(clip, math.max(t, 0))
			for jointName, joint in data.joints do
				local fa, fb = a[jointName], b[jointName]
				if fa or fb then
					local ca = fa and sample(fa) or CFrame.identity
					local cb = fb and sample(fb) or CFrame.identity
					joint.Transform = ca:Lerp(cb, alpha)
				else
					joint.Transform = CFrame.identity
				end
			end
		end
	end)
end

return FighterAnimator
