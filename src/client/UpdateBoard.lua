-- The update board by the hub spawn (server/Hub.lua builds the panel "UpdateBoard"): NEXT UPDATE IN a live
-- countdown, the update's title and teaser (ReplicatedStorage attributes UpdateAt, UpdateTitle, UpdateTeaser
-- from server/Services/LiveOpsService.lua; the remote config's `update`, or every Saturday 17:00 UTC if
-- LiveOps.WeeklyUpdates is on; with neither, the sign is hidden).
-- The last hour the countdown turns red and pulses; at zero it says UPDATE IS LIVE! (rejoin for it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UpdateBoard = {}

local GOLD = Color3.fromRGB(255, 214, 80)
local RED = Color3.fromRGB(255, 90, 80)

local function line(gui, y, h, color)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(15, 10, 30)
	s.Parent = t
	t.Parent = gui
	return t
end

local function countdown(left)
	left = math.max(0, math.floor(left))
	local d, h, m, s = left // 86400, left % 86400 // 3600, left % 3600 // 60, left % 60
	if d > 0 then
		return string.format("%dD %02dH %02dM", d, h, m)
	end
	return string.format("%02d:%02d:%02d", h, m, s)
end

function UpdateBoard.start()
	local map = workspace:WaitForChild("Map", 60)
	local panel = map and map:FindFirstChild("UpdateBoard", true)
	if not panel then
		return
	end
	-- The whole sign (posts, frame and panel) is hidden while there is no real update to count down to; its parts stop
	-- colliding too (this client only), so an invisible post never blocks the path.
	local stand = panel.Parent
	local collides = {} -- [part] = its CanCollide, remembered the first time
	local function setShown(show)
		for _, d in stand:GetDescendants() do
			if d:IsA("BasePart") then
				if collides[d] == nil then
					collides[d] = d.CanCollide
				end
				d.LocalTransparencyModifier = show and 0 or 1
				d.CanCollide = show and collides[d]
			end
		end
	end
	local shown, appliedAt = nil, 0
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- (CFrame.lookAt points the panel's front, -Z, at the spawn)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Adornee = panel
	gui.Parent = panel
	local head = line(gui, 0.05, 0.16, Color3.new(1, 1, 1))
	head.Text = "NEXT UPDATE IN"
	local timer = line(gui, 0.22, 0.3, GOLD)
	local title = line(gui, 0.55, 0.2, Color3.fromRGB(150, 220, 255))
	local teaser = line(gui, 0.77, 0.16, Color3.fromRGB(220, 220, 235))
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		if now - last < 0.25 then
			return
		end
		last = now
		local at = ReplicatedStorage:GetAttribute("UpdateAt")
		-- (While hidden it is re-applied every couple of seconds: streaming can bring the sign's parts back.)
		if (at ~= nil) ~= shown or (not shown and now - appliedAt > 2) then
			shown = at ~= nil
			appliedAt = now
			setShown(shown)
			gui.Enabled = shown
		end
		if not at then
			return
		end
		local left = at - now
		title.Text = string.upper(ReplicatedStorage:GetAttribute("UpdateTitle") or "NEW UPDATE")
		teaser.Text = ReplicatedStorage:GetAttribute("UpdateTeaser") or ""
		if left <= 0 then
			head.Text = "UPDATE IS LIVE!"
			timer.Text = "REJOIN TO PLAY"
			timer.TextColor3 = GOLD
			return
		end
		head.Text = "NEXT UPDATE IN"
		timer.Text = countdown(left)
		local soon = left < 3600
		timer.TextColor3 = soon and RED or GOLD
		timer.TextTransparency = soon and (0.15 + math.sin(now * 6) * 0.15) or 0
	end)
end

return UpdateBoard
