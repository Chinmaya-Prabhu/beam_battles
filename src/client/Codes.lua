-- The CODES window (server: RewardsService Request "Code", shared/Codes.lua): a CODES tile in the menu's free column opens a box to type
-- a code and REDEEM it. The answer shows under the box: what it gave in green, or why not in red. New codes
-- come with every Saturday update (docs/CONTENT_CALENDAR.md).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local Codes = {}
local player = Players.LocalPlayer
local GREEN = Color3.fromRGB(60, 170, 80)
local RED = Color3.fromRGB(210, 70, 60)

function Codes.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CodesGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")
	local window, body = UIKit.window(gui, "CODES", Vector2.new(560, 240))
	UIKit.text(body, {
		Style = "body",
		Size = UDim2.new(1, 0, 0, 22),
		Text = "New codes every Saturday update!",
		TextColor3 = Color3.new(1, 1, 1),
	})
	local box = Instance.new("TextBox")
	box.Name = "CodeBox"
	box.Position = UDim2.fromOffset(0, 34)
	box.Size = UDim2.new(1, -176, 0, 58) -- (REDEEM sits beside it: on a phone the keyboard hides anything lower)
	box.BackgroundColor3 = UIKit.ROW
	box.PlaceholderText = "Type a code..."
	box.PlaceholderColor3 = UIKit.SOFT
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.LuckiestGuy
	box.TextSize = 28
	box.TextColor3 = Color3.new(1, 1, 1)
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
	local edge = Instance.new("UIStroke")
	edge.Thickness = 3
	edge.Color = UIKit.SKY
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = box
	box.Parent = body
	local result = UIKit.text(body, {
		Style = "label",
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		StrokeThickness = 0,
	})
	local redeem = UIKit.pill(body, "green", "REDEEM", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 34),
		Size = UDim2.fromOffset(164, 58),
	})
	local busy = false
	local function send()
		if busy then
			return
		end
		busy = true
		result.Text = "..."
		result.TextColor3 = Color3.new(1, 1, 1)
		local ok, answer = pcall(function()
			return Net.get("Request"):InvokeServer("Code", box.Text)
		end)
		busy = false
		if not ok or type(answer) ~= "table" then
			result.Text = "TRY AGAIN"
			result.TextColor3 = RED
			return
		end
		result.Text = answer.text or ""
		result.TextColor3 = answer.ok and GREEN or RED
		if answer.ok then
			box.Text = ""
		end
	end
	redeem.Activated:Connect(send)
	box.FocusLost:Connect(function(enter)
		if enter then
			send()
		end
	end)

	Codes.open = function()
		window.Visible = true
		result.Text = ""
	end
	-- (CODES lives in SETTINGS, client/Settings.lua: one less tile on the HUD.)
end

return Codes
