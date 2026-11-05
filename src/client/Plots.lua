-- The plot economy on the client (server/Services/PlotService.lua): the collect moment (a fountain of
-- coins off the pad, a "+$N" pop and a little HUD bump), stand-unlock prompts only on this player's own
-- plot, Steal prompts only on other players' plots (shorter hold with the FastSteal perk), the
-- "RUN HOME" call and arrow trail while carrying a stolen fighter, and a feed of steals. Your own fighter
-- over your head (a win, or one picked up off a stand) says where to take it (R on it sends it to the bag); the
-- Place / Pick Up (E) and To Bag (R) prompts show on your own stands only. While your base is unlocked and
-- another player is on it, a warning at the top says so (tap it to go home and lock it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local Net = require(Shared.Net)
local ArrowPath = require(script.Parent.ArrowPath)
local UIKit = require(script.Parent.UIKit)
local UIAtlas = require(Shared.UIAtlas)

local Plots = {}

-- Base punching posts (server/Hub.lua, attribute Plot): only your own is shown and usable.
local function basePosts()
	local mine = game:GetService("Players").LocalPlayer:GetAttribute("Plot")
	for _, m in game:GetService("CollectionService"):GetTagged("TrainStation") do
		local plot = m:GetAttribute("Plot")
		if plot then
			local show = plot == mine
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = show and 0 or 1
				elseif d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
					d.Enabled = show
				end
			end
		end
	end
end
local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 205, 60)
local prompts = {}

local function coins(position, amount)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(2, 0.2, 2)
	holder.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(GOLD)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.2) })
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Speed = NumberRange.new(12, 20)
	e.SpreadAngle = Vector2.new(30, 30)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -40, 0)
	e.LightEmission = 1
	e.Rate = 0
	e.Parent = holder
	e:Emit(math.clamp(8 + math.floor(math.log10(math.max(amount, 1)) * 6), 8, 50))
	-- The cash icon and what was collected, floating up off the stand.
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(250, 64)
	sign.StudsOffset = Vector3.new(0, 3, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.MaxDistance = 90
	sign.Parent = holder
	local icon = UIAtlas.label(sign, "cash", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(58, 58),
		BackgroundTransparency = 1,
	})
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0, 0.5)
	text.Position = UDim2.new(0, 64, 0.5, 0)
	text.Size = UDim2.new(1, -64, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = "+" .. Format.cash(amount)
	text.TextColor3 = Color3.fromRGB(120, 255, 140)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 60, 30)
	stroke.Parent = text
	text.Parent = sign
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	TweenService:Create(sign, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 7, 0),
	}):Play()
	TweenService:Create(text, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	if icon then
		TweenService:Create(icon, info, { ImageTransparency = 1 }):Play()
	end
	Debris:AddItem(holder, 2.2)
end

local function pop(amount)
	local gui = player:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("TrainingHud")
	if not hud then
		return
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	-- A little scatter so back-to-back collects don't print on top of each other.
	label.Position = UDim2.new(0.5, math.random(-60, 60), 0.62, math.random(-20, 20))
	label.Size = UDim2.fromOffset(260, 46)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 38
	cap.Parent = label
	label.Text = "+" .. Format.cash(amount)
	label.TextColor3 = Color3.fromRGB(120, 255, 140)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 60, 30)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = label
	label.Parent = hud
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4)
	TweenService:Create(label, info, { Position = label.Position - UDim2.fromScale(0, 0.12), TextTransparency = 1 })
		:Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	Debris:AddItem(label, 1.5)
end

-- "LOCKED · $500" stand signs only matter to the plot's owner: hide them on other bases.
local lockSigns = {}
local function showLockSign(gui)
	local plot = gui:FindFirstAncestorWhichIsA("Model")
	while plot and not plot:GetAttribute("Index") do
		plot = plot.Parent and plot.Parent:FindFirstAncestorWhichIsA("Model")
	end
	if not lockSigns[gui] then
		lockSigns[gui] = gui.Adornee
	end
	local mine = plot and plot:GetAttribute("Index") == player:GetAttribute("Plot")
	gui.Adornee = mine and lockSigns[gui] or nil
end

-- Unlock prompts belong to the plot owner; Steal prompts to everyone else (and not while carrying).
local function showPrompt(prompt)
	local mine = prompt:GetAttribute("Plot") == player:GetAttribute("Plot")
	local ownerOnly =
		{ StandPrompt = true, MovePrompt = true, BagPrompt = true, Floor2Prompt = true, PartyPrompt = true }
	if ownerOnly[prompt.Name] then
		prompt.MaxActivationDistance = mine and 9 or 0
	else
		-- Hidden on your own plot, while you carry one, and while that base is locked.
		local busy = player:GetAttribute("Carrying") ~= nil
		local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
		local plot = plots and plots:FindFirstChild("Plot" .. tostring(prompt:GetAttribute("Plot")))
		local locked = plot and plot:GetAttribute("Locked")
		prompt.MaxActivationDistance = (mine or busy or locked) and 0 or 8
		prompt.HoldDuration = player:GetAttribute("FastSteal") and 0.5 or 1.5
	end
end

local function watch(inst)
	if inst:IsA("BillboardGui") and inst.Name == "Lock" then
		task.defer(showLockSign, inst)
		return
	end
	if inst:IsA("ProximityPrompt") and inst.Name == "HeldBagPrompt" then
		-- Only the one holding it gets "To Bag".
		inst.MaxActivationDistance = inst:GetAttribute("Owner") == player.UserId and 20 or 0
		return
	end
	local names = {
		StandPrompt = true,
		StealPrompt = true,
		MovePrompt = true,
		BagPrompt = true,
		Floor2Prompt = true,
		PartyPrompt = true,
	}
	if inst:IsA("ProximityPrompt") and names[inst.Name] then
		prompts[inst] = true
		showPrompt(inst)
		inst:GetAttributeChangedSignal("Plot"):Connect(function()
			showPrompt(inst)
		end)
	end
end

-- ------------------------------------------------------------------ carrying

local carry = {}
local function stopCarry()
	ArrowPath.set("Carry", nil)
	for _, inst in carry do
		inst:Destroy()
	end
	table.clear(carry)
end

local function myPlot()
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("Plot")))
end

local function atHome(frame)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not frame then
		return false
	end
	local p = frame:PointToObjectSpace(root.Position)
	local size = Config.Island.plotSize
	return math.abs(p.X) < size.X / 2 + 1 and math.abs(p.Z) < size.Y / 2 + 1
end

local function startCarry()
	stopCarry()
	local own = player:GetAttribute("CarryKind") == "own"
	local fighter = Fighters.ByKey[player:GetAttribute("Carrying") or ""]
	local name = fighter and string.upper(fighter.display) or "IT"
	local plot = myPlot()
	local frame = plot and plot:GetAttribute("Frame")
	local gui = player:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("TrainingHud")
	if hud then
		local label = Instance.new("TextLabel")
		local compact = require(script.Parent.UIKit).compact()
		local view = workspace.CurrentCamera.ViewportSize
		-- (Desktop: under the events chip. Phones: over the main button.)
		label.AnchorPoint = compact and Vector2.new(0.5, 1) or Vector2.new(0.5, 0.5)
		label.Position = compact and UDim2.new(0.5, 0, 1, -108) or UDim2.new(0.5, 0, 0, 128)
		label.Size = compact and UDim2.fromOffset(math.max(200, view.X - 420), 34) or UDim2.fromOffset(520, 44)
		-- On a dark pill, so it never blends into a name plate in the world behind it.
		label.BackgroundColor3 = Color3.fromRGB(24, 18, 40)
		label.BackgroundTransparency = 0.25
		Instance.new("UICorner", label).CornerRadius = UDim.new(1, 0)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5)
		pad.Parent = label
		-- (In the tutorial the coach already says where to take it.)
		label.Visible = (player:GetAttribute("Ftue") or 99) >= 99
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 28
		cap.Parent = label
		label.Text = own and ("TAKE " .. name .. " TO YOUR BASE!") or ("RUN HOME WITH " .. name .. "!")
		label.TextColor3 = own and GOLD or Color3.fromRGB(120, 255, 140)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Color = own and Color3.fromRGB(60, 40, 10) or Color3.fromRGB(20, 60, 30)
		stroke.Parent = label
		label.Parent = hud
		table.insert(carry, label)
		task.spawn(function()
			local home
			while label.Parent do
				-- (Not over the fight's result screen: client/Clash.lua hides the fighter there.)
				local onResult = player:GetAttribute("ClashScreen") == true
				-- (Phones: the HOME button already says "go home"; this stays for what to do at the base.)
				local said = compact and string.find(label.Text, "TO YOUR BASE", 1, true) ~= nil
				label.Visible = (player:GetAttribute("Ftue") or 99) >= 99 and not onResult and not said
				-- The fighter over your head is full size: see through it when the camera is close behind.
				local held = workspace:FindFirstChild("Held_" .. player.Name)
					or workspace:FindFirstChild("Stolen_" .. player.Name)
				if held and not onResult then
					local near = (workspace.CurrentCamera.CFrame.Position - held:GetPivot().Position).Magnitude < 16
					for _, part in held:GetDescendants() do
						if part:IsA("BasePart") then
							part.LocalTransparencyModifier = near and 0.65 or 0
						end
					end
				end
				-- Own fighters: once inside the base, say how to place it; the arrow stops.
				local inside = own and atHome(frame)
				if inside ~= home then
					home = inside
					if own then
						label.Text = inside and "HOLD E ON A STAND TO PLACE " .. name
							or ("TAKE " .. name .. " TO YOUR BASE!")
						ArrowPath.set("Carry", (not inside and frame) and frame.Position or nil)
					end
				end
				task.wait()
			end
		end)
	end
	-- The way home: the arrow trail on the ground (client/ArrowPath.lua).
	if not own or not atHome(frame) then
		ArrowPath.set("Carry", frame and frame.Position or nil)
	end
end

-- A short feed line for everyone: "<thief> stole <fighter> from <victim>!"
local function feed(data)
	local gui = player:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("TrainingHud")
	local thief, victim = Players:GetPlayerByUserId(data.thief), Players:GetPlayerByUserId(data.victim)
	local fighter = Fighters.ByKey[data.key]
	if not hud or not fighter then
		return
	end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -16, 0, 70)
	label.Size = UDim2.fromOffset(420, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne -- the feed is read, so the reading font in normal case
	label.TextSize = 17
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Text = (thief and thief.DisplayName or "Someone")
		.. " stole "
		.. fighter.display
		.. " from "
		.. (victim and victim.DisplayName or "someone")
		.. "!"
	label.TextColor3 = Color3.fromRGB(255, 120, 100)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(30, 16, 40)
	stroke.Parent = label
	label.Parent = hud
	task.delay(4, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(label, 5)
end

-- Someone on your unlocked base while you're away from it: a red warning under the top chip. Tapping it
-- takes you home, where the LOCK pad is just inside the torii. While someone is running off with one of your
-- fighters it says so instead (player attribute StealAlert), until the steal ends.
local function intruderAlert()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BaseAlert"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 7
	gui.Parent = player:WaitForChild("PlayerGui")
	local alert, label = UIKit.pill(gui, "red", "", {
		-- Under the events chip; on phones at the bottom between the thumbstick and the jump button.
		AnchorPoint = UIKit.compact() and Vector2.new(0.5, 1) or Vector2.new(0.5, 0),
		Position = UIKit.compact() and UDim2.new(0.5, 0, 1, -16) or UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(UIKit.compact() and 380 or 460, 46),
		Visible = false,
	})
	UIKit.fitScale(alert)
	alert.Activated:Connect(function()
		if player:GetAttribute("StealAlert") then
			return -- (going home won't help: catch them)
		end
		Net.get("Plot"):FireServer("Home")
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
			local plot = plots and plots:FindFirstChild("Plot" .. tostring(player:GetAttribute("Plot")))
			local show = false
			local stealing = player:GetAttribute("StealAlert")
			if stealing then
				show = true
				label.Text = stealing
			elseif plot and not plot:GetAttribute("Locked") and not player:GetAttribute("InClash") then
				local frame, size = plot:GetBoundingBox()
				local function inside(pos)
					local o = frame:PointToObjectSpace(pos)
					return math.abs(o.X) < size.X / 2 + 4 and math.abs(o.Z) < size.Z / 2 + 4
				end
				local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not (me and inside(me.Position)) then
					for _, other in Players:GetPlayers() do
						local root = other ~= player
							and other.Character
							and other.Character:FindFirstChild("HumanoidRootPart")
						if root and inside(root.Position) then
							show = true
							label.Text = string.upper(other.DisplayName)
								.. " IS AT YOUR BASE! TAP TO GO HOME AND LOCK IT"
							break
						end
					end
				end
			end
			alert.Visible = show
		end
	end)
end

function Plots.start()
	task.delay(2, basePosts)
	game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("Plot"):Connect(basePosts)
	intruderAlert()
	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind == "Collect" then
			coins(data.position, data.amount)
			pop(data.amount)
		elseif kind == "Stolen" then
			feed(data)
		end
	end)
	player:GetAttributeChangedSignal("FastSteal"):Connect(function()
		for prompt in prompts do
			if prompt.Parent then
				showPrompt(prompt)
			end
		end
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		if player:GetAttribute("Carrying") then
			task.wait() -- CarryKind is set alongside it
			startCarry()
		else
			stopCarry()
		end
		for prompt in prompts do
			if prompt.Parent then
				showPrompt(prompt)
			end
		end
	end)
	for _, inst in workspace:GetDescendants() do
		watch(inst)
	end
	-- Re-check prompts when any base locks or unlocks.
	local map = workspace:WaitForChild("Map", 30)
	local plotsFolder = map and map:WaitForChild("Plots", 30)
	if plotsFolder then
		for _, plot in plotsFolder:GetChildren() do
			plot:GetAttributeChangedSignal("Locked"):Connect(function()
				for prompt in prompts do
					if prompt.Parent and prompt:GetAttribute("Plot") == plot:GetAttribute("Index") then
						showPrompt(prompt)
					end
				end
			end)
		end
	end
	workspace.DescendantAdded:Connect(watch)
	player:GetAttributeChangedSignal("Plot"):Connect(function()
		for gui in lockSigns do
			if gui.Parent then
				showLockSign(gui)
			end
		end
		for prompt in prompts do
			if prompt.Parent then
				showPrompt(prompt)
			else
				prompts[prompt] = nil
			end
		end
	end)
end

return Plots
