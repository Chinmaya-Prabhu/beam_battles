-- One folder of remotes, created by the server and found by clients.
--   FX (server -> clients): presentation cues such as "Drop".
--   Clash (both ways): clients send "Click" batches, "Surge" and "Leave"; the server sends "Seat",
--     "Start", "State" and "End" (see server/Services/ClashService.lua).
--   Train (client -> server): "Reps" batches of clicks, "Leave" a station (server/Services/TrainingService.lua).
--   Plot (client -> server): "Home" to go to your base (server/Services/PlotService.lua).
--   Tutorial (client -> server): "Swooped" when the intro camera ends (server/Services/TutorialService.lua).
--   Rewards (client -> server): "Gift" <index> and "Daily" claims (server/Services/RewardsService.lua).
--   Zone (client -> server): "Travel" <zone name | "Hub"> from the map (server/Services/ZoneService.lua).
--   Request (client -> server, returns): "Index" = the player's Index book.
--   Shop (client -> server): "AutoTrain" on/off, "DebugBuy" in Studio (server/Services/MonetizationService.lua).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}
local NAMES = {
	FX = "RemoteEvent",
	Clash = "RemoteEvent",
	Train = "RemoteEvent",
	Plot = "RemoteEvent",
	Shop = "RemoteEvent",
	Tutorial = "RemoteEvent",
	Rewards = "RemoteEvent",
	Zone = "RemoteEvent",
	Request = "RemoteFunction",
}

local function folder()
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Net")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Net"
			f.Parent = ReplicatedStorage
			for name, class in NAMES do
				local remote = Instance.new(class)
				remote.Name = name
				remote.Parent = f
			end
		end
		return f
	end
	return ReplicatedStorage:WaitForChild("Net")
end

function Net.get(name)
	local f = folder()
	return RunService:IsServer() and f[name] or f:WaitForChild(name)
end

return Net
