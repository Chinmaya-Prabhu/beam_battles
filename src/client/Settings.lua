-- SETTINGS: a small gear in Roblox's top bar opens a window with the player's switches:
--   * MUSIC and SOUND EFFECTS (player attributes MusicOff / SfxOff; client/Audio listens, the server saves
--     them through TutorialService "Settings"),
--   * AUTO TRAIN: a switch for owners of the Auto Train pass (Shop remote "AutoTrain", attribute AutoTrainOn);
--     everyone else sees the row too, with its icon and a button that offers the pass.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Products = require(Shared.Products)
local UIAtlas = require(Shared.UIAtlas)
local UIKit = require(script.Parent.UIKit)

local Settings = {}
local player = Players.LocalPlayer

-- The gear, drawn from frames (the atlas has no gear icon): four bars turned 45° apart for the teeth, a disc,
-- and a hole.
local function gear(parent)
	local b = Instance.new("ImageButton")
	b.Name = "SettingsButton"
	b.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	b.BackgroundTransparency = 0.35
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(44, 44)
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local white = Color3.new(1, 1, 1)
	for i = 0, 3 do
		local tooth = Instance.new("Frame")
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Position = UDim2.fromScale(0.5, 0.5)
		tooth.Size = UDim2.fromOffset(28, 7)
		tooth.Rotation = i * 45
		tooth.BackgroundColor3 = white
		tooth.BorderSizePixel = 0
		tooth.Parent = b
		Instance.new("UICorner", tooth).CornerRadius = UDim.new(0, 2)
	end
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(20, 20)
	disc.BackgroundColor3 = white
	disc.Parent = b
	Instance.new("UICorner", disc).CornerRadius = UDim.new(1, 0)
	local hole = Instance.new("Frame")
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.Size = UDim2.fromOffset(8, 8)
	hole.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	hole.Parent = disc
	Instance.new("UICorner", hole).CornerRadius = UDim.new(1, 0)
	b.Parent = parent
	return b
end

local function build(gui)
	local window, body = UIKit.window(gui, "SETTINGS", Vector2.new(480, 380))
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	-- One row: name and hint on the left, an ON/OFF pill on the right.
	-- (`icon`: an atlas icon at the left; `offer`: returns the button text when it should sell something instead.)
	local function row(order, title, hint, isOn, flip, icon, offer)
		local f = Instance.new("Frame")
		f.LayoutOrder = order
		f.Size = UDim2.new(1, 0, 0, 64)
		f.BackgroundColor3 = UIKit.ROW
		f.Parent = body
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
		local left = icon and 74 or 16
		if icon then
			UIAtlas.label(f, icon, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				Size = UDim2.fromOffset(54, 54),
				BackgroundTransparency = 1,
			})
		end
		UIKit.text(f, {
			Style = "heading",
			Position = UDim2.fromOffset(left, 8),
			Size = UDim2.new(1, -left - 134, 0, 26),
			Text = title,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UIKit.text(f, {
			Style = "small",
			Position = UDim2.fromOffset(left, 36),
			Size = UDim2.new(1, -left - 134, 0, 18),
			Text = hint,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local pill, label = UIKit.pill(f, "green", "ON", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 46),
		})
		local function show()
			local sell = offer and offer()
			if sell then
				label.Text = sell
				UIKit.setPill(pill, "green")
				return
			end
			local on = isOn()
			label.Text = on and "ON" or "OFF"
			UIKit.setPill(pill, on and "green" or "grey")
		end
		pill.Activated:Connect(function()
			flip()
			show()
		end)
		show()
		return f, show
	end
	local function sound(attribute)
		return function()
			return not player:GetAttribute(attribute)
		end, function()
			player:SetAttribute(attribute, (not player:GetAttribute(attribute)) or nil) -- at once here; the server saves it
			Net.get("Tutorial"):FireServer("Settings", {
				music = not player:GetAttribute("MusicOff"),
				sfx = not player:GetAttribute("SfxOff"),
				lefty = player:GetAttribute("LeftHanded") == true,
			})
		end
	end
	local _, showMusic = row(1, "MUSIC", "Each place has its own theme", sound("MusicOff"))
	local _, showSfx = row(2, "SOUND EFFECTS", "Hits, rewards and buttons", sound("SfxOff"))
	-- Right-handed players tap with the right hand, so their charged attack sits on the left; left-handed ones flip it.
	local _, showHand = row(3, "LEFT-HANDED", "Charged attack on the right side", function()
		return player:GetAttribute("LeftHanded") == true
	end, function()
		player:SetAttribute("LeftHanded", (player:GetAttribute("LeftHanded") ~= true) or nil)
		Net.get("Tutorial"):FireServer("Settings", {
			music = not player:GetAttribute("MusicOff"),
			sfx = not player:GetAttribute("SfxOff"),
			lefty = player:GetAttribute("LeftHanded") == true,
		})
	end)
	-- Codes (they used to be a tile on the phone HUD): the button opens the code window.
	row(4, "CODES", "Enter a code for free rewards", function()
		return true
	end, function()
		window.Visible = false
		local Codes = require(script.Parent.Codes)
		if Codes.open then
			Codes.open()
		end
	end, "bubble", function()
		return "ENTER"
	end)
	local autoPass = Products.ByKey.AutoTrain
	local _, showAuto = row(
		5,
		"AUTO TRAIN",
		"Trains for you while you're away",
		function()
			return player:GetAttribute("AutoTrainOn") == true
		end,
		function()
			if player:GetAttribute("AutoTrain") == true then
				Net.get("Shop"):FireServer("AutoTrain", not player:GetAttribute("AutoTrainOn"))
			elseif autoPass and RunService:IsStudio() then
				Net.get("Shop"):FireServer("DebugBuy", autoPass.key) -- (Studio: a test grant; the creator "owns" every real pass)
			elseif autoPass and autoPass.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, autoPass.id)
			end
		end,
		"auto_train",
		function()
			return player:GetAttribute("AutoTrain") ~= true and ("R$" .. (autoPass and autoPass.price or 149)) or nil
		end
	)
	local function refreshAuto()
		UIKit.resizeWindow(window, Vector2.new(480, 470))
		showAuto()
	end
	refreshAuto()
	-- (The Shop loads each pass's live Robux price into Products a moment after joining: show it when opened.)
	window:GetPropertyChangedSignal("Visible"):Connect(refreshAuto)
	for _, name in { "AutoTrain", "AutoTrainOn" } do
		player:GetAttributeChangedSignal(name):Connect(refreshAuto)
	end
	player:GetAttributeChangedSignal("MusicOff"):Connect(showMusic)
	player:GetAttributeChangedSignal("SfxOff"):Connect(showSfx)
	player:GetAttributeChangedSignal("LeftHanded"):Connect(showHand)
	return window
end

function Settings.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SettingsGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")
	local window = build(gui)
	-- At the right end of Roblox's top bar (GuiService.TopbarInset: the bar's free space), clear of Roblox's
	-- own buttons on every device (phones have more of them) and of the stats on phones.
	local button = gear(gui)
	button.AnchorPoint = Vector2.new(1, 0.5)
	local function place()
		local inset = game:GetService("GuiService").TopbarInset
		button.Position = UDim2.fromOffset(inset.Max.X - 12, inset.Min.Y + math.max(inset.Height, 44) / 2)
	end
	place()
	game:GetService("GuiService"):GetPropertyChangedSignal("TopbarInset"):Connect(place)
	-- A red dot on the gear until the player has looked in SETTINGS (CODES live there) or used a code.
	local dot = UIKit.dot(button)
	local seen = false
	local function showDot()
		dot.Visible = not seen and player:GetAttribute("CodesUsed") ~= true and (player:GetAttribute("Ftue") or 99) >= 99
		dot.Count.Text = "!"
	end
	showDot()
	player:GetAttributeChangedSignal("CodesUsed"):Connect(showDot)
	player:GetAttributeChangedSignal("Ftue"):Connect(showDot)
	button.Activated:Connect(function()
		window.Visible = not window.Visible
		seen = true
		showDot()
	end)
	player:GetAttributeChangedSignal("InClash"):Connect(function()
		button.Visible = not player:GetAttribute("InClash")
	end)
end

return Settings
