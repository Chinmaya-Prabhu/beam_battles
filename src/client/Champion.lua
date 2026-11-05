-- Champion followers (docs/TRAINING_PLAN.md §3): every player's equipped fighter floats beside them like a
-- pet, built on this client from the cached fighter rigs so it moves smoothly with no network lag.
-- Reads player attributes set by server/Services/TrainingService.lua: Champion (fighter key),
-- ChampionMutation and ChampionMult. While its owner trains it powers up with them; a new Champion
-- arrives with a burst, in its signature pose. Naruto fighters do the Naruto run while their owner moves.
-- POSE (Champion.pose, from the Bag): the owner and the follower strike its signature pose together (server:
-- PlotService "Pose", player attribute PoseAt) while the owner's camera swings round them.
-- Clips play through client/FighterAnimator.lua (the model is tagged "Fighter").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local Net = require(Shared.Net)

local Champion = {}
local followers = {} -- [player] = { model, key, mutation, pos, nextClip }
local folder

local SCALE = 1 -- the fighter's normal size; a Huge one is always twice that
local OFFSET = Vector3.new(3.8, 0, 0.6) -- at the owner's right, just behind their shoulder (owner space),
-- clear of the camera behind them
local MUTATION_COLORS = {
	Golden = Color3.fromRGB(255, 200, 60),
	Diamond = Color3.fromRGB(120, 230, 255),
	Huge = Color3.fromRGB(255, 255, 255),
}

local function rainbow()
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 * 0.85, 0.8, 1)))
	end
	return ColorSequence.new(keys)
end

local function plateText(label, fighter, mutation, mult)
	local shown = math.floor(mult * 100 + 0.5) / 100
	label.Text = (mutation ~= "Normal" and (string.upper(mutation) .. " ") or "")
		.. string.upper(fighter.display)
		.. "  x"
		.. shown
end

local function plate(model, fighter, mutation, mult)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ChampionPlate"
	gui.Size = UDim2.fromScale(4.2, 1)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	gui.MaxDistance = 35
	gui.LightInfluence = 0
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	plateText(label, fighter, mutation, mult)
	label.TextColor3 = Config.Rarities[fighter.rarity] and Config.Rarities[fighter.rarity].color or Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(30, 16, 40)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = model
	return label
end

local function sparkle(model, mutation)
	local root = model.PrimaryPart
	if not root or mutation == "Normal" then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = mutation == "Rainbow" and rainbow() or ColorSequence.new(MUTATION_COLORS[mutation] or Color3.new(1, 1, 1))
	e.Size = NumberSequence.new(mutation == "Huge" and 0.6 or 0.35)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 10
	e.LightEmission = 1
	e.Parent = root
end

local function burst(position, color)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(position)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(0.6)
	e.Lifetime = NumberRange.new(0.5, 1)
	e.Speed = NumberRange.new(10, 18)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.LightEmission = 1
	e.Parent = p
	e:Emit(40)
	Debris:AddItem(p, 1.2)
end

local function clear(player)
	local f = followers[player]
	if f and f.model then
		f.model:Destroy()
	end
	followers[player] = nil
end

local function build(player)
	local key = player:GetAttribute("Champion")
	local mutation = player:GetAttribute("ChampionMutation") or "Normal"
	local current = followers[player]
	if current and current.key == key and current.mutation == mutation then
		return
	end
	local start = current and current.pos
	clear(player)
	local fighter = key and Fighters.ByKey[key]
	if not fighter then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = start or (root and root.Position) or Vector3.zero
	local scale = SCALE * (Config.Mutations[mutation] and Config.Mutations[mutation].scale or 1)
	local model = FighterModels.spawn(
		key,
		at,
		Vector3.new(0, 0, -1),
		{ scale = scale, parent = folder, mutation = mutation, aura = true }
	)
	if not model then
		return
	end
	model.Name = "Champion_" .. player.Name
	-- Your own Champion's name and multiplier are on the HUD; plates are for other players' followers.
	local label = player ~= Players.LocalPlayer
			and plate(model, fighter, mutation, player:GetAttribute("ChampionMult") or 1)
		or nil
	sparkle(model, mutation)
	local _, size = model:GetBoundingBox()
	-- spawn() stood the model's feet on `at`; the pivot sits this far above its feet.
	local lift = model:GetPivot().Position.Y - at.Y
	followers[player] = {
		model = model,
		key = key,
		mutation = mutation,
		fighter = fighter,
		label = label,
		pos = at,
		lift = lift,
		scale = scale,
		nextClip = 0,
	}
	-- A new Champion arrives in its signature pose, in a burst of its rarity's colour.
	model:SetAttribute("Clip", Fighters.signature(key))
	model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
	if current then
		burst(at + Vector3.new(0, size.Y / 2, 0), Config.Rarities[fighter.rarity].color)
	end
end

local function track(player)
	for _, name in { "Champion", "ChampionMutation" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			build(player)
		end)
	end
	player:GetAttributeChangedSignal("ChampionMult"):Connect(function()
		local f = followers[player]
		if f and f.label then
			plateText(f.label, f.fighter, f.mutation, player:GetAttribute("ChampionMult") or 1)
		end
	end)
	task.spawn(build, player)
end

-- The local player's POSE: asks the server, then swings the camera round them for the pose.
local posing = false
function Champion.pose()
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if posing or not root or player:GetAttribute("InClash") then
		return
	end
	posing = true
	Net.get("Plot"):FireServer("Pose")
	local camera = workspace.CurrentCamera
	local was = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local base = root.CFrame
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local k = math.min(t / 3, 1)
		-- From in front and to one side, round to the other, slightly low (heroic).
		local angle = math.rad(-35 + 70 * (1 - (1 - k) ^ 2))
		local focus = base.Position + Vector3.new(0, 1.5, 0)
		local eye = focus + (base * CFrame.Angles(0, angle, 0)).LookVector * 11 + Vector3.new(0, -0.6, 0)
		camera.CFrame = CFrame.lookAt(eye, focus)
		if t >= 3.3 then
			conn:Disconnect()
			camera.CameraType = was
			posing = false
		end
	end)
end

function Champion.start()
	folder = Instance.new("Folder")
	folder.Name = "Champions"
	folder.Parent = workspace
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(clear)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for player, f in followers do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or not f.model.Parent then
				continue
			end
			-- Float beside the owner at their feet's height, gently bobbing; ease toward the spot.
			local feetY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
			local side = CFrame.lookAt(Vector3.zero, look)
			local target = Vector3.new(
				root.Position.X,
				feetY + 0.6 + math.sin(now * 2 + player.UserId % 7) * 0.25,
				root.Position.Z
			) + side:VectorToWorldSpace(OFFSET * Vector3.new(f.scale or 1, 1, 1)) -- a Huge one stands further out
			local alpha = 1 - math.exp(-dt * 7)
			f.pos = f.pos:Lerp(target, alpha)
			if (f.pos - target).Magnitude > 60 then
				f.pos = target -- teleported: catch up at once
			end
			local pivot = f.pos + Vector3.new(0, f.lift, 0)
			f.model:PivotTo(CFrame.lookAt(pivot, pivot + look))
			-- Posing with its owner (Champion.pose): its signature, in time with them.
			local poseAt = player:GetAttribute("PoseAt")
			if poseAt and poseAt ~= f.posedAt then
				f.posedAt = poseAt
				f.running = false
				f.model:SetAttribute("Clip", Fighters.signature(f.key))
				f.model:SetAttribute("ClipStart", poseAt)
				f.nextClip = now + 3
			end
			-- Naruto fighters do the Naruto run while their owner is on the move.
			local moving = humanoid.MoveDirection.Magnitude > 0.1
			if f.fighter.series == "NARUTO" and now >= f.nextClip then
				if moving and not f.running then
					f.running = true
					f.model:SetAttribute("Clip", "RunNaruto")
					f.model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
				elseif not moving and f.running then
					f.running = false
					f.model:SetAttribute("Clip", nil)
					f.model:SetAttribute("ClipStart", nil)
				end
			end
			-- Power up alongside a training owner.
			if player:GetAttribute("Training") and now >= f.nextClip then
				f.running = false
				f.nextClip = now + 1.8
				f.model:SetAttribute("Clip", "PowerUp")
				f.model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
			end
		end
	end)
end

return Champion
