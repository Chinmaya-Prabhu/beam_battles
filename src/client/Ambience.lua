-- Things that move all the time: the portal ring spins, the drop countdown ticks.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ambience = {}

local RING_SPEED = 0.25 -- radians per second

function Ambience.start()
	local rings = {}
	local function track(model)
		local center = model:GetBoundingBox().Position
		local offsets = {}
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				offsets[p] = CFrame.new(center):ToObjectSpace(p.CFrame)
			end
		end
		table.insert(rings, { center = center, offsets = offsets })
	end
	for _, model in CollectionService:GetTagged("PortalRing") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("PortalRing"):Connect(track)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, ringData in rings do
			local spin = CFrame.new(ringData.center) * CFrame.Angles(0, t * RING_SPEED, 0)
			for p, offset in ringData.offsets do
				p.CFrame = spin * offset
			end
		end
		local nextDrop = ReplicatedStorage:GetAttribute("NextDrop")
		if nextDrop then
			local left = math.max(0, math.ceil(nextDrop - workspace:GetServerTimeNow()))
			local soon = left <= 3
			local line = soon and ("DROP IN " .. left .. "!") or string.format("NEXT DROP  %d:%02d", left // 60, left % 60)
			-- Every portal's board (the hub's and each zone's).
			for _, anchor in CollectionService:GetTagged("DropCountdown") do
				local board = anchor:FindFirstChild("Countdown")
				local label = board and board:FindFirstChild("Text")
				if label then
					label.Text = line
					label.TextColor3 = soon and Color3.fromRGB(255, 230, 90) or Color3.new(1, 1, 1)
				end
			end
		end
	end)
end

return Ambience
