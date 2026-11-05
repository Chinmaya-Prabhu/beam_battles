-- Streaming (Workspace.StreamingEnabled, default.project.json): phones only load the world near the player.
-- What the game needs on every client all the time (its UI and guide beam read them) is made Persistent:
-- altars, bases, training stations, gear stalls, zone gates and guardians, and the ocean and horizon (seen
-- from everywhere). Before any teleport, the server streams the destination in first (Streaming.prepare).
local CollectionService = game:GetService("CollectionService")

local Streaming = {}

local TAGS = { "TrainStation", "GearStall", "ZoneGate", "Guardian" }

local function persist(model)
	if model and model:IsA("Model") then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
end

function Streaming.setup(world)
	for _, tag in TAGS do
		for _, m in CollectionService:GetTagged(tag) do
			persist(m)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(persist)
	end
	for _, folder in { world.altars, world.plots } do
		for _, m in folder and folder:GetChildren() or {} do
			persist(m)
		end
	end
	persist(world.root:FindFirstChild("Ocean"))
	-- Things the client writes on or animates once, found by name at start: the drop portals and the update
	-- board (client/Ambience.lua, client/UpdateBoard.lua).
	persist(world.portal)
	for _, d in world.root:GetDescendants() do
		if d:IsA("Model") and (d.Name == "UpdateBoardStand" or d.Name == "ZonePortal" or d.Name == "Portal") then
			persist(d)
		end
	end
end

-- Loads the area round `position` for `player` before they're moved there (so they never land in the void).
function Streaming.prepare(player, position)
	if workspace.StreamingEnabled then
		pcall(player.RequestStreamAroundAsync, player, position, 3)
	end
end

return Streaming
