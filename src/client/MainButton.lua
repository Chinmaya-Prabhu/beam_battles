-- The phone HUD's one big button, bottom centre between the thumbstick and the jump button: what to do next,
-- so a kid never has to read the screen to find it (docs/ANIME_DICE_TEARDOWN.md).
--   HOME   carrying a fighter: takes you to your base
--   FIGHT  a fighter stands on an altar you can use here: the guide beam points at its pad
--   ZONES  too strong for the hub's altars: opens the MAP
--   TRAIN  nothing to fight: the guide beam points at the nearest training station
-- Phones only, after the tutorial (and as HOME while the tutorial's first fighter is carried). Desktop has its
-- own layout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local UIAtlas = require(Shared.UIAtlas)
local UIKit = require(script.Parent.UIKit)
local Fancy = require(script.Parent.Fancy)
local ArrowPath = require(script.Parent.ArrowPath)
local ZoneQuest = require(script.Parent.ZoneQuest)

local MainButton = {}
local player = Players.LocalPlayer

local ICONS = { HOME = "base", FIGHT = "smash_charged", ZONES = "walled", TRAIN = "power" }

-- The pad of the nearest altar here with a fighter standing on it that this player may fight for.
local function nearestDrop()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local map = workspace:FindFirstChild("Map")
	local altars = map and map:FindFirstChild("Altars")
	if not root or not altars then
		return nil
	end
	local zone = player:GetAttribute("Zone") or "Hub"
	local power = player:GetAttribute("Power") or 0
	local best, bestDist
	for _, altar in altars:GetChildren() do
		local tier = Config.Tiers[altar:GetAttribute("Tier")]
		local here = (altar:GetAttribute("Zone") or "Hub") == zone
		if here and tier and power >= tier.power and altar:FindFirstChild("Fighter", true) then
			for _, d in altar:GetDescendants() do
				if d.Name == "ClashPad" and d:GetAttribute("Side") == 1 then
					local distance = (d.Position - root.Position).Magnitude
					if not bestDist or distance < bestDist then
						best, bestDist = d.Position, distance
					end
				end
			end
		end
	end
	return best
end

local function decide()
	if player:GetAttribute("Carrying") then
		return "HOME"
	end
	local zone = player:GetAttribute("Zone") or "Hub"
	if zone == "Hub" and ((player:GetAttribute("Power") or 0) > Config.Push.rookieMax or ZoneQuest.ready()) then
		return "ZONES"
	end
	local pad = nearestDrop()
	if pad then
		return "FIGHT", pad
	end
	return "TRAIN"
end

function MainButton.start()
	if not UIKit.compact() then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainButtonGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")
	local holder = Instance.new("Frame")
	holder.Name = "MainButton"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -8)
	holder.Size = UDim2.fromOffset(92, 92)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	UIKit.fitScale(holder)
	local button, label = UIKit.tile(holder, ICONS.TRAIN, "TRAIN", { Size = UDim2.fromScale(1, 1) })
	Fancy.pulse(button)
	local icon = button:FindFirstChild("Icon")

	local state, pad = "TRAIN", nil
	local beaming -- the pad the beam points at (it stops on arrival)
	local function refresh()
		local ftue = player:GetAttribute("Ftue") or 99
		local learning = ftue < 99 and not (ftue == 6 and player:GetAttribute("Carrying"))
		gui.Enabled = not learning and not player:GetAttribute("InClash") and not player:GetAttribute("ClashScreen")
		state, pad = decide()
		if label.Text ~= state then
			label.Text = state
			if icon then
				UIAtlas.icon(icon, ICONS[state])
			end
		end
	end
	button.Activated:Connect(function()
		if state == "HOME" then
			Net.get("Plot"):FireServer("Home")
		elseif state == "FIGHT" then
			beaming = pad
			ArrowPath.set("Quest", pad)
		elseif state == "ZONES" then
			local Map = require(script.Parent.Map)
			if Map.open then
				Map.open()
			end
		else
			player:SetAttribute("GoTrain", os.clock()) -- client/ArrowPath.lua points the way to a station
		end
	end)
	RunService.Heartbeat:Connect(function()
		local root = beaming and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - beaming).Magnitude < 8 then
			beaming = nil
			ArrowPath.set("Quest", nil)
		end
	end)
	for _, name in { "Ftue", "InClash", "ClashScreen", "Carrying", "Zone" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(1)
		end
	end)
end

return MainButton
