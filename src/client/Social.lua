-- Return and social hooks on the client (server: SocialService, PlotService offline earnings, TrainingService
-- LIMIT BREAK; Config.Social):
--   * WELCOME BACK: when the base earned while the player was away (player attribute OfflineCash), a card
--     shows how much and for how long, and COLLECT takes it (Plot remote "Offline"),
--   * Social.invite / Social.joinGroup for the gift window's free boosts (client/Gifts) (+10% per friend here, FriendBoost;
--     +10% cash forever in the group, GroupMult),
--   * LIMIT BREAK: a meter while training fills to Config.Social.limitBreak reps (LimitCount), then a burst:
--     a flash, a shake, LIMIT BREAK! and the Power it gave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local GroupService = game:GetService("GroupService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Audio = require(script.Parent.Audio)
local Fx = require(script.Parent.Fx)

local Social = {}
local player = Players.LocalPlayer
local S = Config.Social
local GOLD = Color3.fromRGB(255, 214, 80)

local function duration(seconds)
	local h, m = seconds // 3600, seconds % 3600 // 60
	return h > 0 and string.format("%dH %02dM", h, m) or string.format("%dM", math.max(1, m))
end

-- ------------------------------------------------------------------ welcome back

local shownFor
local function welcomeBack()
	local amount = player:GetAttribute("OfflineCash")
	if not amount or amount <= 0 or shownFor == amount then
		return
	end
	if (player:GetAttribute("Ftue") or 99) < 99 or player:GetAttribute("InClash") or not UIKit.loaded() then
		return -- later (the attribute stays until collected)
	end
	if UIKit.popupsHeld() then
		task.delay(2, welcomeBack) -- (just after a fight: let the result play first)
		return
	end
	shownFor = amount
	UIKit.holdPopups(4) -- the daily window and offers wait their turn
	local gui = Instance.new("ScreenGui")
	gui.Name = "WelcomeBack"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Parent = player.PlayerGui
	local w, body = UIKit.window(gui, "WELCOME BACK!", Vector2.new(520, 330))
	local seconds = player:GetAttribute("OfflineSeconds")
	UIKit.text(body, {
		Style = "body",
		Size = UDim2.new(1, 0, 0, 24),
		Text = seconds and ("Your base kept earning while you were away (" .. duration(seconds) .. "):")
			or "Your base earned while you were away:",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	UIKit.text(body, {
		Style = "display",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 70),
		Text = Format.cash(amount),
		TextColor3 = Color3.fromRGB(110, 230, 120),
	})
	UIKit.text(body, {
		Style = "body",
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Up to " .. (S.offlineCap // 3600) .. " hours. Come back often!",
		TextColor3 = Color3.fromRGB(120, 120, 140),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local collect = UIKit.pill(body, "green", "COLLECT", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(240, 60),
	})
	local done = false
	local function take()
		if done then
			return
		end
		done = true
		Net.get("Plot"):FireServer("Offline")
		w.Visible = false
	end
	collect.Activated:Connect(take)
	w:GetPropertyChangedSignal("Visible"):Connect(function()
		if not w.Visible then
			take() -- closing it collects too (never lose the money to the X)
			gui:Destroy()
		end
	end)
	w.Visible = true
end

-- ------------------------------------------------------------------ friends and group

-- For the gift window's FREE BOOSTS: invite friends (Roblox's invite prompt) and join the group.
function Social.invite()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end

function Social.joinGroup()
	local groupId = ReplicatedStorage:GetAttribute("GroupId")
	if groupId then
		pcall(GroupService.PromptJoinAsync, GroupService, groupId)
		Net.get("Tutorial"):FireServer("CheckGroup")
	end
end

-- ------------------------------------------------------------------ LIMIT BREAK

local function limitMeter()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LimitBreak"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player.PlayerGui
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.fromOffset(320, 30)
	frame.BackgroundColor3 = Color3.fromRGB(30, 22, 50)
	frame.BackgroundTransparency = 0.2
	frame.Visible = false
	Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Color = GOLD
	edge.Parent = frame
	frame.Parent = gui
	UIKit.fitScale(frame)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 90, 40))
	g.Parent = fill
	fill.Parent = frame
	local label = UIKit.text(frame, {
		Size = UDim2.fromScale(1, 1),
		Text = "",
		StrokeThickness = 2,
		ZIndex = 3,
	})
	local function refresh()
		local n = player:GetAttribute("LimitCount") or 0
		local training = player:GetAttribute("Training") ~= nil
		frame.Visible = training and not player:GetAttribute("InClash")
		local k = math.clamp(n / S.limitBreak, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.max(k, 0.06), 1) }):Play()
		label.Text = "LIMIT BREAK  " .. n .. "/" .. S.limitBreak
	end
	player:GetAttributeChangedSignal("LimitCount"):Connect(refresh)
	player:GetAttributeChangedSignal("Training"):Connect(refresh)
	refresh()
	return gui
end

local function burst(amount)
	local fx = Instance.new("ScreenGui")
	fx.Name = "LimitBreakBurst"
	fx.IgnoreGuiInset = true
	fx.ResetOnSpawn = false
	fx.DisplayOrder = 25
	fx.Parent = player.PlayerGui
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
	flash.BackgroundTransparency = 0.3
	flash.Parent = fx
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.36)
	holder.Size = UDim2.fromOffset(640, 150)
	holder.BackgroundTransparency = 1
	holder.Parent = fx
	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = holder
	TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local title = UIKit.text(holder, {
		Style = "display",
		Size = UDim2.new(1, 0, 0, 80),
		Text = "LIMIT BREAK!",
		TextColor3 = Color3.fromRGB(255, 200, 60),
		StrokeThickness = 4,
	})
	title.TextSize = 70
	local line = UIKit.text(holder, {
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "+" .. Format.short(amount) .. " POWER",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		StrokeThickness = 3,
	})
	Fx.shake(0.6, 0.5)
	Audio.play("ultFire", { scale = 0.8 })
	task.delay(1.6, function()
		for _, t in { title, line } do
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
		task.wait(0.45)
		fx:Destroy()
	end)
end

function Social.start()
	limitMeter()
	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind == "LimitBreak" and type(data) == "table" then
			burst(data.amount or 0)
		end
	end)
	for _, name in { "OfflineCash", "Ftue", "InClash", "Loaded" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			task.delay(1, welcomeBack)
		end)
	end
	task.delay(3, welcomeBack)
end

return Social
