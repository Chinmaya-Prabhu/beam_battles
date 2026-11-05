-- Your own base's beacon (docs/WAYFINDING_PLAN.md step 4): a soft column of light in your plot's colour
-- rising from your base, visible only to you, so you can always spot home from anywhere in the hub. It
-- fades out when you're standing on your base.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local BaseBeacon = {}
local player = Players.LocalPlayer
local HEIGHT = 140

function BaseBeacon.start()
	local holder, beam, glow
	local function build()
		if holder then
			holder:Destroy()
			holder = nil
		end
		local index = player:GetAttribute("Plot")
		local map = workspace:WaitForChild("Map", 30)
		local plots = map and map:WaitForChild("Plots", 30)
		local plot = index and plots and plots:FindFirstChild("Plot" .. index)
		if not plot then
			return
		end
		local frame = plot:GetAttribute("Frame") or plot:GetPivot()
		local color = Config.PlotColors[index] or Color3.fromRGB(120, 255, 150) -- the plot's torii and banners
		holder = Instance.new("Part")
		holder.Name = "BaseBeacon"
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.CFrame = CFrame.new(frame.Position + Vector3.new(0, 2, 0))
		local bottom = Instance.new("Attachment")
		bottom.Parent = holder
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, HEIGHT, 0)
		top.Parent = holder
		beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = bottom, top
		beam.Width0, beam.Width1 = 7, 3
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.7, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = holder
		glow = Instance.new("BillboardGui")
		glow.Size = UDim2.fromOffset(160, 40)
		glow.StudsOffsetWorldSpace = Vector3.new(0, 24, 0)
		glow.AlwaysOnTop = true
		glow.LightInfluence = 0
		glow.MaxDistance = 1000
		glow.Parent = holder
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.Text = "YOUR BASE"
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Parent = glow
		holder.Parent = workspace
	end
	player:GetAttributeChangedSignal("Plot"):Connect(build)
	task.spawn(build)
	RunService.Heartbeat:Connect(function()
		if not holder then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local near = root
			and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(
					holder.Position.X,
					0,
					holder.Position.Z
				)).Magnitude
				< 34
		local show = not near and not player:GetAttribute("InClash") and not player:GetAttribute("ClashScreen")
		beam.Enabled = show
		glow.Enabled = show
	end)
end

return BaseBeacon
