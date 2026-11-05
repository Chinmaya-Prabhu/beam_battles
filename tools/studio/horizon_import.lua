-- Paste into Studio's command bar (Edit mode, Anime Click Battle place). Loads the two Toolbox horizon models,
-- deletes every script inside them, and leaves them in ServerStorage.Horizon, selected, ready to save.
local SS = game:GetService("ServerStorage")
local old = SS:FindFirstChild("Horizon")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "Horizon"
for name, id in { Island = 13138901447, Mountain = 11751636142 } do
	local model = Instance.new("Model")
	model.Name = name
	for _, obj in game:GetObjects("rbxassetid://" .. id) do
		obj.Parent = model
	end
	local removed = 0
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			removed += 1
			d:Destroy()
		end
	end
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then parts += 1 end
	end
	print(name, id, "parts:", parts, "scripts removed:", removed)
	model.Parent = folder
end
folder.Parent = SS
game:GetService("Selection"):Set({ folder })
print("Done. Right-click ServerStorage > Horizon > Save to File... as assets/models/Horizon.rbxmx")
