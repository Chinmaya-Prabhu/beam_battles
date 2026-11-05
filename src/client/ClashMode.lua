-- Clash mode: while the local player is in a clash (player attribute InClash), the fight owns the screen.
-- Every other HUD screen hides (and stays hidden if something tries to show it mid-fight), open windows
-- close, banners wait (client/Fx.lua drops them), proximity prompts go, and the world clutter round the pads
-- steps aside: the base beacon, the guide beam's arrow, everyone's followers and other players' Power plates.
-- Everything returns the moment the clash ends.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local UIKit = require(script.Parent.UIKit)

local ClashMode = {}
local player = Players.LocalPlayer

-- The ScreenGuis the clash keeps (its own, banners, reveals and the reward chest).
local KEEP = { ClashUI = true, ClashWaiting = true, SummonReveal = true }
-- World labels hidden during a fight.
local PLATES = { Nameplate = true, StandPlate = true, GuardianLabel = true, Cash = true, Lock = true }

function ClashMode.start()
	local hidden = {}
	local parked -- the followers' folder, out of the world during a fight
	local plates = {} -- name plates switched off for the fight
	local function apply()
		local fighting = UIKit.inFight()
		local playerGui = player:WaitForChild("PlayerGui")
		if fighting then
			for _, w in CollectionService:GetTagged("UIWindow") do
				w.Visible = false
			end
			for _, g in playerGui:GetChildren() do
				if g:IsA("ScreenGui") and g.Enabled and not KEEP[g.Name] then
					g.Enabled = false
					hidden[g] = true
				end
			end
		else
			-- The result and the winner's celebration play out first: pop-ups (the daily window, offers, the
			-- welcome-back card) wait a few seconds after a fight.
			UIKit.holdPopups(6)
			for g in hidden do
				if g.Parent then
					g.Enabled = true
				end
			end
			table.clear(hidden)
		end
		-- Prompts (stands, altars, stalls) and followers.
		game:GetService("ProximityPromptService").MaxPromptsVisible = fighting and 0 or 16
		local champions = fighting and workspace:FindFirstChild("Champions") or parked
		if fighting and champions then
			parked = champions
			champions.Parent = nil
		elseif not fighting and parked then
			parked.Parent = workspace
			parked = nil
		end
		-- Name plates over the fighters round the pads (altar drops, stands, guardians), so the fight is the
		-- only thing on screen.
		for _, d in workspace:GetDescendants() do
			if d:IsA("BillboardGui") and PLATES[d.Name] then
				if fighting and d.Enabled then
					d.Enabled = false
					plates[d] = true
				elseif not fighting and plates[d] then
					d.Enabled = true
				end
			end
		end
		if not fighting then
			table.clear(plates)
		end
		-- Other players' Power plates over their heads.
		for _, other in Players:GetPlayers() do
			local plate = other.Character and other.Character:FindFirstChild("PowerPlate", true)
			if plate and plate:IsA("BillboardGui") then
				plate.Enabled = not fighting
			end
		end
		for _, name in { "BaseBeacon", "ArrowPath" } do
			local inst = workspace:FindFirstChild(name)
			if inst then
				for _, d in inst:GetDescendants() do
					if d:IsA("BillboardGui") or d:IsA("Beam") then
						d.Enabled = not fighting
					end
				end
			end
		end
	end
	player:GetAttributeChangedSignal("InClash"):Connect(apply)
	player:GetAttributeChangedSignal("ClashScreen"):Connect(apply)
	-- A screen that switches itself back on mid-fight goes straight back off.
	local function guard(g)
		if g:IsA("ScreenGui") and not KEEP[g.Name] then
			g:GetPropertyChangedSignal("Enabled"):Connect(function()
				if UIKit.inFight() and g.Enabled then
					g.Enabled = false
					hidden[g] = true
				end
			end)
		end
	end
	for _, g in player:WaitForChild("PlayerGui"):GetChildren() do
		guard(g)
	end
	player.PlayerGui.ChildAdded:Connect(guard)
	-- A name plate that appears mid-fight (a new drop on a nearby altar) stays hidden too.
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BillboardGui") and PLATES[d.Name] then
			task.defer(function()
				if UIKit.inFight() and d.Parent and d.Enabled then
					d.Enabled = false
					plates[d] = true
				end
			end)
		end
	end)
	-- Screens created mid-clash (a pop-up, the daily window) stay hidden too.
	player:WaitForChild("PlayerGui").ChildAdded:Connect(function(g)
		if UIKit.inFight() and g:IsA("ScreenGui") and not KEEP[g.Name] then
			task.defer(function()
				if g.Enabled then
					g.Enabled = false
					hidden[g] = true
				end
			end)
		end
	end)
end

return ClashMode
