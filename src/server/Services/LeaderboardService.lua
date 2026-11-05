-- All-time global leaderboards (docs/RETENTION_PLAN.md §4): four boards beside the spawn path, outside the
-- conveyor ring (most Power ever
-- trained, most cash collected, most steals, most rebirths), each the top 10 across every server from an
-- OrderedDataStore. Players' scores are written every WRITE_EVERY seconds and on leaving; boards reread every
-- READ_EVERY. Without DataStore access (Studio with API access off) boards show this server's players.
-- Each board is the Toolbox "Time Played Leaderboard" (ServerStorage.LeaderboardKit, assets/models, scripts
-- stripped): its frame, lights and rows (Name1-10, Score1-10, Photo1-10), our title on its sign, and the
-- #1 player's own avatar standing on its pedestal.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local LeaderboardService = {}
local Data

local WRITE_EVERY, READ_EVERY = 120, 150
local TOP = 10
local MAX = 9e15 -- OrderedDataStore values are integers

local BOARDS = {
	{
		key = "Power",
		title = "MOST POWER",
		color = Color3.fromRGB(255, 205, 60),
		score = function(d)
			return d.stats.power or d.power
		end,
		show = Format.short,
		at = Vector3.new(-34, 0, 24),
	},
	{
		key = "Steals",
		title = "TOP THIEVES",
		color = Color3.fromRGB(255, 110, 100),
		score = function(d)
			return d.stats.steals or 0
		end,
		show = Format.short,
		at = Vector3.new(-64, 0, 16),
	},
	{
		key = "Cash",
		title = "RICHEST",
		color = Color3.fromRGB(120, 240, 130),
		score = function(d)
			return d.stats.collected or 0
		end,
		show = Format.cash,
		at = Vector3.new(34, 0, 24),
	},
	{
		key = "Rebirths",
		title = "MOST REBIRTHS",
		color = Color3.fromRGB(190, 140, 255),
		score = function(d)
			return d.rebirths or 0
		end,
		show = tostring,
		at = Vector3.new(64, 0, 16),
	},
}

local stores = {}
local names = {}

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

-- A board beside the spawn path, angled toward it; returns { rows, podium } for fill().
local function buildBoard(parent, spec)
	local kit = game:GetService("ServerStorage"):FindFirstChild("LeaderboardKit")
	local template = kit and kit:FindFirstChild("TimePlayedLeaderboard", true)
	if not template then
		return nil
	end
	local model = template:Clone()
	model.Name = "Leaderboard_" .. spec.key
	-- Only the board: not the kit's own 3D title, its status signs or its stand-in avatar.
	for _, name in { "ThreeDTextObject", "ThumbnailCamera" } do
		local d = model:FindFirstChild(name)
		if d then
			d:Destroy()
		end
	end
	local block = model:FindFirstChild("ScoreBlock")
	for _, name in { "NoDataFound", "Credits", "NoAPIServices", "WaitingSync" } do
		local d = block and block:FindFirstChild(name)
		if d then
			d:Destroy()
		end
	end
	local podium = model:FindFirstChild("First Place Avatar")
	local stand = podium and podium:FindFirstChild("Rig") -- the kit's stand-in: marks where #1 stands
	-- (The kit's small sign along the bottom says "TOP 10"; the title gets its own big sign on top, below.)
	local sign = model:FindFirstChild("UpdateBoardTimer")
	local label = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = "TOP 10"
		label.TextColor3 = spec.color
		label.TextScaled = true
		label.Font = Enum.Font.LuckiestGuy
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	-- Stand it beside the path, its face (the ScoreBlock's front) toward the path ahead of spawn, grown 1.3x.
	model:ScaleTo(1.3)
	local sp = Config.Island.spawn
	local pos = sp + spec.at
	local look = Vector3.new(sp.X, pos.Y, sp.Z - 20) - pos
	local face = block and block.CFrame or model:GetPivot()
	local turn = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z))
	model:PivotTo(CFrame.new(pos) * turn * face:ToObjectSpace(model:GetPivot()))
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, pos.Y - (box.Position.Y - size.Y / 2), 0)) -- on the ground
	local standAt = stand and stand:GetPivot()
	if stand then
		stand:Destroy()
	end
	-- The big title sign across the top: dark, a neon edge in the board's colour, the title in big letters.
	if block then
		local top = block.CFrame * CFrame.new(0, block.Size.Y / 2 + 3.2, 0)
		local header = Instance.new("Part")
		header.Name = "TitleSign"
		header.Anchored = true
		header.Size = Vector3.new(block.Size.X + 2, 4.4, 0.8)
		header.CFrame = top
		header.Color = Color3.fromRGB(26, 22, 40)
		header.Material = Enum.Material.SmoothPlastic
		header.Parent = model
		local edge = Instance.new("Part")
		edge.Name = "TitleEdge"
		edge.Anchored = true
		edge.CanCollide = false
		edge.Size = Vector3.new(block.Size.X + 2.6, 5, 0.6)
		edge.CFrame = top * CFrame.new(0, 0, 0.15)
		edge.Color = spec.color
		edge.Material = Enum.Material.Neon
		edge.Parent = model
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = header
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(0.94, 0.84)
		title.Position = UDim2.fromScale(0.03, 0.08)
		title.Font = Enum.Font.LuckiestGuy
		title.TextScaled = true
		title.Text = spec.title
		title.TextColor3 = spec.color
		title.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Color3.fromRGB(20, 14, 30)
		stroke.Parent = title
	end
	model.Parent = parent
	local rows = {}
	local gui = block and block:FindFirstChild("Leaderboard")
	for i = 1, TOP do
		rows[i] = {
			name = gui and gui.Names:FindFirstChild("Name" .. i),
			value = gui and gui.Score:FindFirstChild("Score" .. i),
			thumb = gui and gui.Photos:FindFirstChild("Photo" .. i),
		}
	end
	return {
		rows = rows,
		podium = podium,
		standAt = standAt,
	}
end

local function write(player)
	local data = Data.get(player)
	if not data then
		return
	end
	for _, spec in BOARDS do
		local store = stores[spec.key]
		if store then
			local score = math.floor(math.clamp(spec.score(data) or 0, 0, MAX))
			pcall(store.SetAsync, store, tostring(player.UserId), score)
		end
	end
end

-- [{ userId, score }] best first: from the store, or this server's players without one.
local function top(spec)
	local store = stores[spec.key]
	if store then
		local ok, pages = pcall(store.GetSortedAsync, store, false, TOP)
		if ok then
			local out = {}
			for _, e in pages:GetCurrentPage() do
				table.insert(out, { userId = tonumber(e.key), score = e.value })
			end
			return out
		end
	end
	local out = {}
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data then
			table.insert(out, { userId = player.UserId, score = spec.score(data) or 0 })
		end
	end
	table.sort(out, function(a, b)
		return a.score > b.score
	end)
	return out
end

-- The #1 player's avatar on the podium (rebuilt only when #1 changes).
local function crown(board, userId)
	if board.topId == userId or not board.podium or not board.standAt then
		return
	end
	board.topId = userId
	if board.avatar then
		board.avatar:Destroy()
		board.avatar = nil
	end
	if not userId then
		return
	end
	local ok, avatar = pcall(Players.CreateHumanoidModelFromUserId, Players, userId)
	if not ok or not avatar then
		return
	end
	for _, d in avatar:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	avatar.Name = "Rig"
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- no name tag over the statue
	end
	avatar:ScaleTo(1.3)
	avatar:PivotTo(board.standAt)
	avatar.Parent = board.podium
	board.avatar = avatar
end

local function fill(spec, board)
	local list = top(spec)
	for i, row in board.rows do
		local e = list[i]
		if row.name then
			row.name.Text = e and nameOf(e.userId) or ""
		end
		if row.value then
			row.value.Text = e and spec.show(e.score) or ""
		end
		if row.thumb then
			row.thumb.Image = e and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", e.userId) or ""
		end
	end
	crown(board, list[1] and list[1].userId)
end

function LeaderboardService.start(world, DataService)
	Data = DataService
	for _, spec in BOARDS do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "Board_" .. spec.key)
		stores[spec.key] = ok and store or nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = world.root or workspace
	local boards = {}
	for _, spec in BOARDS do
		boards[spec] = buildBoard(folder, spec)
	end
	Players.PlayerRemoving:Connect(write)
	task.spawn(function()
		task.wait(10) -- let the first players load
		local sinceWrite = WRITE_EVERY
		while true do
			if sinceWrite >= WRITE_EVERY then
				sinceWrite = 0
				for _, player in Players:GetPlayers() do
					write(player)
				end
			end
			for spec, board in boards do
				fill(spec, board)
			end
			task.wait(READ_EVERY)
			sinceWrite += READ_EVERY
		end
	end)
end

return LeaderboardService
