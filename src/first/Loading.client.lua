-- The loading screen (ReplicatedFirst, so it shows from the first frame instead of Roblox's grey one):
-- the game's name over a dusk sky, a filling bar and a tip, until the game has loaded, the player's data is
-- in (they have a plot) and their character stands in the world. Then it fades out and sets the player
-- attribute Loaded (client only), which the tutorial's opening swoop and the pop-ups wait for.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
ReplicatedFirst:RemoveDefaultLoadingScreen()

local TIPS = {
	"Train at the punching posts to raise your Power.",
	"Beat a zone's 5 guardians, then its boss, to open the next zone.",
	"Fighters on your stands earn cash, even while you're away.",
	"Lock your base at the gate so nobody steals your fighters.",
	"Your follower makes every training click stronger.",
	"New codes every Saturday update!",
	"Rarer mutations earn up to 25 times more.",
	"Press the boombox at your base for a dance party.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = player:WaitForChild("PlayerGui")

local sky = Instance.new("Frame")
sky.Size = UDim2.fromScale(1, 1)
sky.BorderSizePixel = 0
sky.BackgroundColor3 = Color3.new(1, 1, 1)
sky.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 24, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(150, 60, 140)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 90)),
})
gradient.Parent = sky

-- Slow-turning light rays behind the title.
local rays = Instance.new("Frame")
rays.AnchorPoint = Vector2.new(0.5, 0.5)
rays.Position = UDim2.fromScale(0.5, 0.4)
rays.Size = UDim2.fromOffset(1400, 1400)
rays.BackgroundTransparency = 1
rays.Parent = sky
-- (Each bar crosses the centre and turns about it, so six bars make twelve rays.)
for i = 0, 5 do
	local ray = Instance.new("Frame")
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Position = UDim2.fromScale(0.5, 0.5)
	ray.Size = UDim2.fromOffset(80, 1400)
	ray.Rotation = i * 30
	ray.BackgroundColor3 = Color3.fromRGB(255, 230, 160)
	ray.BackgroundTransparency = 0.88
	ray.BorderSizePixel = 0
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = ray
	ray.Parent = rays
end

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(0.5, 0.5)
holder.Position = UDim2.fromScale(0.5, 0.5)
holder.Size = UDim2.fromOffset(720, 360)
holder.BackgroundTransparency = 1
holder.Parent = sky
local scale = Instance.new("UIScale")
scale.Parent = holder
local function fit()
	local view = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(view.X / 760, view.Y / 520), 0.45, 1.3)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextScaled = true
	for k, v in props do
		if k ~= "Stroke" then
			l[k] = v
		end
	end
	local s = Instance.new("UIStroke")
	s.Thickness = props.Stroke or 4
	s.Color = Color3.fromRGB(30, 16, 40)
	s.Parent = l
	l.Parent = holder
	return l
end
local title = label({
	Size = UDim2.new(1, 0, 0, 120),
	Text = "ANIME BEAM BATTLE",
	TextColor3 = Color3.fromRGB(255, 214, 80),
	Stroke = 6,
})
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 40))
grad.Parent = title
label({
	Position = UDim2.fromOffset(0, 118),
	Size = UDim2.new(1, 0, 0, 34),
	Text = "TRAIN. CLASH. COLLECT.",
	Stroke = 3,
})

-- The bar.
local track = Instance.new("Frame")
track.Position = UDim2.fromOffset(110, 210)
track.Size = UDim2.new(1, -220, 0, 30)
track.BackgroundColor3 = Color3.fromRGB(30, 16, 40)
track.Parent = holder
Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
local edge = Instance.new("UIStroke")
edge.Thickness = 3
edge.Color = Color3.new(1, 1, 1)
edge.Parent = track
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.04, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 120, 40))
fillGrad.Parent = fill
local status =
	label({ Position = UDim2.fromOffset(0, 248), Size = UDim2.new(1, 0, 0, 26), Text = "LOADING THE DOJO", Stroke = 3 })
local tip = label({
	Position = UDim2.fromOffset(40, 300),
	Size = UDim2.new(1, -80, 0, 24),
	Text = "TIP: " .. TIPS[math.random(1, #TIPS)],
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 235, 210),
	Stroke = 2,
})

-- Steps the bar walks through; it eases toward the step reached, so it never sits still.
local done = false
local target = 0.05
task.spawn(function()
	local t = 0
	while not done do
		local dt = task.wait()
		t += dt
		rays.Rotation = t * 6
		local now = fill.Size.X.Scale
		fill.Size = UDim2.fromScale(now + (target - now) * math.min(dt * 3, 1), 1)
		if math.floor(t / 4) ~= math.floor((t - dt) / 4) then
			tip.Text = "TIP: " .. TIPS[math.random(1, #TIPS)]
		end
	end
end)

local function step(fraction, text)
	target = math.max(target, fraction)
	status.Text = text
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end
step(0.35, "BUILDING THE ISLANDS")
-- The player's data has loaded once they have a plot (server PlotService); a minute at most.
local deadline = os.clock() + 60
while not player:GetAttribute("Plot") and os.clock() < deadline do
	task.wait(0.2)
end
step(0.7, "WAKING YOUR FIGHTERS")
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart", 15)
task.wait(0.6) -- a beat for the world around them to stream in
step(1, "READY!")
task.wait(0.5)
done = true

-- Fade out, then let the game's own moments start.
for _, d in gui:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
		TweenService:Create(d, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	end
end
player:SetAttribute("Loaded", true)
task.wait(0.7)
gui:Destroy()
