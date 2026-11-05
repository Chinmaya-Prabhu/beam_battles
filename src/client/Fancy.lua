-- Eye-catching UI for premium items (the top simulators' shop look), all animated from one loop:
--   Fancy.rays(parent, color)          light rays slowly turning behind something
--   Fancy.rainbowStroke(gui, thick)    a UIStroke whose rainbow gradient keeps rotating
--   Fancy.rainbowText(label)           text with a scrolling rainbow
--   Fancy.shine(frame)                 a white glint sweeping across every few seconds
--   Fancy.pulse(gui)                   a gentle heartbeat scale
--   Fancy.spinModel(viewportModel)     turns a ViewportFrame model
--   Fancy.premiumCard(parent, opts)    the featured premium card: rays, spinning 3D item, rarity tag, rainbow
--                                      border, shine, big multiplier and a pulsing Robux button
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearLook = require(Shared.GearLook)
local UIKit = require(script.Parent.UIKit)

local Fancy = {}
local items = {} -- { kind, inst, data }

local function rainbow(offset)
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6 + offset) % 1, 0.75, 1)))
	end
	return ColorSequence.new(keys)
end

function Fancy.rays(parent, color, count)
	local holder = Instance.new("Frame")
	holder.Name = "Rays"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1.6, 1.6)
	holder.BackgroundTransparency = 1
	holder.ZIndex = parent.ZIndex
	count = count or 12
	for i = 1, count do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0.09, 0, 0.5, 0)
		ray.BorderSizePixel = 0
		ray.BackgroundColor3 = color
		ray.ZIndex = holder.ZIndex
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 0.15),
		})
		g.Parent = ray
		-- Rotate each ray about the centre: pivot via a wrapper turned to its angle.
		local arm = Instance.new("Frame")
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Position = UDim2.fromScale(0.5, 0.5)
		arm.Size = UDim2.fromScale(1, 1)
		arm.BackgroundTransparency = 1
		arm.Rotation = i / count * 360
		arm.ZIndex = holder.ZIndex
		ray.Parent = arm
		arm.Parent = holder
	end
	holder.Parent = parent
	table.insert(items, { kind = "spin", inst = holder, speed = 18 })
	return holder
end

function Fancy.rainbowStroke(gui, thick)
	local s = Instance.new("UIStroke")
	s.Thickness = thick or 4
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Color = rainbow(0)
	g.Parent = s
	s.Parent = gui
	table.insert(items, { kind = "turn", inst = g, speed = 120 })
	return s
end

function Fancy.rainbowText(label)
	label.TextColor3 = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Color = rainbow(0)
	g.Parent = label
	table.insert(items, { kind = "scroll", inst = g })
	return g
end

function Fancy.shine(frame)
	frame.ClipsDescendants = true
	local glint = Instance.new("Frame")
	glint.Name = "Shine"
	glint.AnchorPoint = Vector2.new(0.5, 0.5)
	glint.Size = UDim2.new(0.25, 0, 2, 0)
	glint.Rotation = 20
	glint.BackgroundColor3 = Color3.new(1, 1, 1)
	glint.BorderSizePixel = 0
	glint.ZIndex = frame.ZIndex + 8
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = glint
	glint.Parent = frame
	table.insert(items, { kind = "shine", inst = glint, offset = math.random() * 3 })
	return glint
end

function Fancy.pulse(gui)
	local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = gui
	table.insert(items, { kind = "pulse", inst = scale })
	return scale
end

function Fancy.spinModel(model)
	table.insert(items, { kind = "model", inst = model })
end

-- opts: look, name, rarity ("MYTHIC" / "SECRET"), mult, price, color, owned (bool), onBuy
function Fancy.premiumCard(parent, opts)
	local card = Instance.new("Frame")
	card.Name = "Premium_" .. opts.name
	card.BackgroundColor3 = Color3.fromRGB(26, 20, 48)
	card.Size = UDim2.fromOffset(250, 250)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = card
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Color = ColorSequence.new(opts.color:Lerp(Color3.new(0, 0, 0), 0.35), Color3.fromRGB(18, 14, 36))
	bg.Parent = card
	-- Secret items get the rainbow border; others a solid one in their colour.
	if opts.rarity == "SECRET" then
		Fancy.rainbowStroke(card, 5)
	else
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = opts.color
		stroke.Parent = card
	end
	-- The spinning item.
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0)
	stage.Position = UDim2.new(0.5, 0, 0, 26)
	stage.Size = UDim2.fromOffset(150, 120)
	stage.ClipsDescendants = false
	stage.Parent = card
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(220, 220, 220)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.ZIndex = 3
	vp.Parent = stage
	local model = GearLook.band(opts.look, 1.4, 1)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.9, 2.5), Vector3.zero)
	cam.FieldOfView = 48
	cam.Parent = vp
	vp.CurrentCamera = cam
	Fancy.spinModel(model)
	-- Rarity tag top-left, with a scrolling rainbow.
	local tag = UIKit.text(card, {
		Style = "heading",
		TextSize = 18,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(110, 24),
		Text = opts.rarity,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		StrokeThickness = 2.5,
	})
	if opts.rarity == "SECRET" then
		Fancy.rainbowText(tag)
	else
		tag.TextColor3 = opts.color
	end
	UIKit.text(card, {
		Style = "heading",
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(90, 22),
		Text = "FOREVER",
		TextColor3 = Color3.fromRGB(255, 214, 80),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
		StrokeThickness = 2.5,
	})
	UIKit.text(card, {
		Style = "label",
		Position = UDim2.fromOffset(10, 148),
		Size = UDim2.new(1, -20, 0, 26),
		Text = string.upper(opts.name),
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		StrokeThickness = 3,
	})
	local mult = UIKit.text(card, {
		Style = "heading",
		TextSize = 18,
		Position = UDim2.fromOffset(10, 174),
		Size = UDim2.new(1, -20, 0, 22),
		Text = "x" .. opts.mult .. "+ PER CLICK",
		ZIndex = 5,
		StrokeThickness = 2.5,
	})
	mult.TextColor3 = Color3.fromRGB(255, 220, 90)
	local buy, label = UIKit.pill(card, "green", opts.owned and "OWNED" or (utf8.char(0xE002) .. " " .. opts.price), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -36, 0, 44),
		ZIndex = 6,
	})
	if opts.owned then
		UIKit.setPill(buy, "grey")
	end
	buy.Activated:Connect(function()
		if opts.onBuy then
			opts.onBuy()
		end
	end)
	card.Parent = parent
	return card, label, buy
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for i = #items, 1, -1 do
		local it = items[i]
		local inst = it.inst
		if not inst.Parent then
			table.remove(items, i)
			continue
		end
		if it.kind == "spin" or it.kind == "turn" then
			inst.Rotation = (inst.Rotation + dt * it.speed) % 360
		elseif it.kind == "scroll" then
			inst.Offset = Vector2.new((now * 0.6) % 2 - 1, 0)
			inst.Color = rainbow(now * 0.15)
		elseif it.kind == "shine" then
			local t = (now + it.offset) % 3.2
			inst.Position = UDim2.fromScale(-0.3 + math.min(t / 0.8, 1) * 1.6, 0.5)
		elseif it.kind == "pulse" then
			inst.Scale = 1 + math.sin(now * 5) * 0.04
		elseif it.kind == "model" then
			inst:PivotTo(CFrame.Angles(0.35, now * 1.4, 0.25))
		end
	end
end)

return Fancy
