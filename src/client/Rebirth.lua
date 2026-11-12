-- Rebirth on the client (server: TrainingService "Rebirth"). The REBIRTH tile is always in the HUD menu (after
-- the tutorial) with a bar for the Power still needed, and turns gold ("READY!") when they can. It opens a window
-- that says plainly what resets and what stays, and what this rebirth gives (its training bonus and any
-- weights it unlocks). The first time each rebirth becomes possible a big REBIRTH UNLOCKED! card shows it
-- (once per rebirth: RebirthSeen), and beating the last boss says rebirth is the next goal.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Training = require(Shared.Training)
local Format = require(Shared.Format)
local UIAtlas = require(Shared.UIAtlas)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local Rebirth = {}
local player = Players.LocalPlayer

function Rebirth.start()
	local remote = Net.get("Train")
	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	local open = UIKit.tile(UIKit.menu(), "rebirth", "REBIRTH", { LayoutOrder = 4 })
	open:SetAttribute("AfterTutorial", true) -- (UIKit.menu shows it once the tutorial is done)
	open:SetAttribute("OpenWhen", "Boss_Blossom") -- (its bar would sit at 0% for hours before that)
	-- A dot when it's possible (the window shows how far along it is).
	local readyDot = UIKit.dot(open)

	-- The confirm window.
	local window, body = UIKit.window(gui, "REBIRTH", Vector2.new(480, 400))
	UIAtlas.label(body, "rebirth", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(84, 84),
	})
	local gain = UIKit.text(body, {
		Style = "title",
		TextSize = 26,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = Color3.fromRGB(110, 230, 120),
	})
	UIKit.text(body, {
		Style = "label",
		TextSize = 19,
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "RESETS: POWER, WEIGHTS, STATIONS",
		TextColor3 = Color3.fromRGB(255, 120, 110),
	})
	UIKit.text(body, {
		Style = "label",
		TextSize = 19,
		Position = UDim2.fromOffset(0, 162),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "KEEPS: FIGHTERS, BASE, CASH, ZONES",
		TextColor3 = Color3.fromRGB(130, 210, 255),
	})
	-- What this rebirth unlocks besides the bonus (rebirth-gated weights).
	local unlocks = UIKit.text(body, {
		Style = "label",
		TextSize = 19,
		Position = UDim2.fromOffset(0, 194),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		TextColor3 = Color3.fromRGB(210, 160, 255),
	})
	local yes = UIKit.pill(body, "gold", "REBIRTH!", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.5, -8, 0, 56),
	})
	local no = UIKit.pill(body, "grey", "NOT YET", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.5, -8, 0, 56),
	})

	-- The weights rebirth `n` unlocks, as text ("" if none).
	local function unlockText(n)
		local names = {}
		for _, g in Training.Gear do
			if g.rebirth == n then
				table.insert(names, string.upper(g.name) .. " (x" .. g.mult .. ")")
			end
		end
		return #names > 0 and ("UNLOCKS " .. table.concat(names, ", ")) or ""
	end

	-- The big moment: the first time a rebirth is possible (and after beating the last boss).
	local function unlockCard(cleared)
		local done = player:GetAttribute("Rebirths") or 0
		local cost = Training.rebirthCost(done)
		local ready = (player:GetAttribute("Power") or 0) >= cost
		local card = Instance.new("ScreenGui")
		card.Name = "RebirthUnlocked"
		card.ResetOnSpawn = false
		card.IgnoreGuiInset = true
		card.DisplayOrder = 20
		card.Parent = player.PlayerGui
		local w, b = UIKit.window(card, ready and "REBIRTH UNLOCKED!" or "WORLD CLEARED!", Vector2.new(560, 430))
		UIAtlas.label(b, "rebirth", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(96, 96),
		})
		local bonus = math.floor((done + 1) * Training.RebirthBonus * 100)
		UIKit.text(b, {
			Style = "title",
			Position = UDim2.fromOffset(0, 104),
			Size = UDim2.new(1, 0, 0, 34),
			Text = "+" .. bonus .. "% TRAINING FOREVER",
			TextColor3 = Color3.fromRGB(110, 230, 120),
		})
		UIKit.text(b, {
			Style = "body",
			Position = UDim2.fromOffset(10, 146),
			Size = UDim2.new(1, -20, 0, 110),
			Text = (
				ready and "You're strong enough to be reborn! "
				or ("You beat every zone! Reach " .. Format.short(cost) .. " Power to rebirth. ")
			)
				.. "Rebirth starts your Power over, but every click trains harder forever"
				.. (unlockText(done + 1) ~= "" and (", and it " .. string.lower(unlockText(done + 1)) .. ".") or ".")
				.. "\nYour fighters, base, cash and zones all stay.",
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		local go = UIKit.pill(b, ready and "gold" or "green", ready and "SEE REBIRTH" or "GOT IT!", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.fromOffset(240, 58),
		})
		w:GetPropertyChangedSignal("Visible"):Connect(function()
			if not w.Visible then
				card:Destroy()
			end
		end)
		go.Activated:Connect(function()
			w.Visible = false
			if ready then
				window.Visible = true
			end
		end)
		w.Visible = true
		if ready and not cleared then
			remote:FireServer("SeenRebirth")
		end
	end

	local function refresh()
		local power = player:GetAttribute("Power") or 0
		local done = player:GetAttribute("Rebirths") or 0
		local cost = Training.rebirthCost(done)
		local ready = power >= cost
		readyDot.Visible = ready
		window.Title.Text = "REBIRTH " .. (done + 1)
		local bonus = math.floor((done + 1) * Training.RebirthBonus * 100)
		gain.Text = ready and ("+" .. bonus .. "% TRAINING FOREVER") or ("NEEDS " .. Format.short(cost) .. " POWER")
		gain.TextColor3 = ready and Color3.fromRGB(110, 230, 120) or Color3.fromRGB(255, 175, 60)
		yes.Visible = ready
		unlocks.Text = unlockText(done + 1)
		-- Side by side when both show; NOT YET alone sits centred.
		no.AnchorPoint = ready and Vector2.new(1, 1) or Vector2.new(0.5, 1)
		no.Position = ready and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, 0, 1, 0)
	end
	refresh()
	for _, name in { "Power", "Rebirths" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	-- Once per rebirth, when it first becomes possible (after the tutorial, never over a fight).
	local pending = false
	local function check()
		local done = player:GetAttribute("Rebirths") or 0
		local seen = player:GetAttribute("RebirthSeen") or 0
		local ready = (player:GetAttribute("Power") or 0) >= Training.rebirthCost(done)
		if pending or not ready or seen > done or (player:GetAttribute("Ftue") or 99) < 99 then
			return
		end
		pending = true
		task.spawn(function()
			while player:GetAttribute("InClash") or UIKit.popupsHeld() do
				task.wait(0.5)
			end
			task.wait(1)
			unlockCard(false)
			task.wait(2)
			pending = false
		end)
	end
	for _, name in { "Power", "RebirthSeen", "Rebirths" } do
		player:GetAttributeChangedSignal(name):Connect(check)
	end
	task.delay(4, check)
	-- The rebirth itself: a white flash, then REBIRTH n! with what it gave, popping in over the screen.
	local function celebrate(n)
		UIKit.closeAll() -- the moment gets the screen to itself
		UIKit.holdPopups(6)
		local fx = Instance.new("ScreenGui")
		fx.Name = "RebirthMoment"
		fx.IgnoreGuiInset = true
		fx.ResetOnSpawn = false
		fx.DisplayOrder = 30
		fx.Parent = player.PlayerGui
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 0
		flash.Parent = fx
		TweenService:Create(flash, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.42)
		holder.Size = UDim2.fromOffset(700, 220)
		holder.BackgroundTransparency = 1
		holder.Parent = fx
		local pop = Instance.new("UIScale")
		pop.Scale = 0.3
		pop.Parent = holder
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		UIAtlas.label(holder, "rebirth", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -70),
			Size = UDim2.fromOffset(96, 96),
		})
		local lines = {
			{ "REBIRTH " .. n .. "!", Color3.fromRGB(255, 214, 80), 70, 40 },
			{
				"+" .. math.floor(n * Training.RebirthBonus * 100) .. "% TRAINING FOREVER",
				Color3.fromRGB(110, 230, 120),
				40,
				114,
			},
		}
		local unlock = unlockText(n)
		if unlock ~= "" then
			table.insert(
				lines,
				{ string.gsub(unlock, "^UNLOCKS ", "") .. " IN STOCK!", Color3.fromRGB(200, 150, 255), 30, 160 }
			)
		end
		local labels = {}
		for k, l in lines do
			local t = UIKit.text(holder, {
				Style = k == 1 and "display" or nil,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, l[4]),
				Size = UDim2.new(1, 0, 0, l[3]),
				Text = l[1],
				TextColor3 = l[2],
				StrokeThickness = 4,
			})
			if k == 1 then
				t.TextSize = 72 -- the title towers over the lines under it
			end
			table.insert(labels, t)
		end
		task.delay(3.5, function()
			for _, t in labels do
				TweenService:Create(t, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
				local st = t:FindFirstChildOfClass("UIStroke")
				if st then
					TweenService:Create(st, TweenInfo.new(0.6), { Transparency = 1 }):Play()
				end
			end
			for _, d in holder:GetDescendants() do
				if d:IsA("ImageLabel") then
					TweenService:Create(d, TweenInfo.new(0.6), { ImageTransparency = 1 }):Play()
				end
			end
			task.wait(0.7)
			fx:Destroy()
		end)
	end
	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind == "Rebirth" and data.userId == player.UserId then
			celebrate(data.rebirths)
		end
	end)
	player:GetAttributeChangedSignal("WorldCleared"):Connect(function()
		local done = player:GetAttribute("Rebirths") or 0
		local ready = (player:GetAttribute("Power") or 0) >= Training.rebirthCost(done)
		if player:GetAttribute("WorldCleared") and not ready then
			task.delay(11, unlockCard, true) -- after the boss's reveal; (ready players get the unlock card)
		end
	end)
	open.Activated:Connect(function()
		window.Visible = not window.Visible
		refresh()
	end)
	no.Activated:Connect(function()
		window.Visible = false
	end)
	yes.Activated:Connect(function()
		window.Visible = false
		remote:FireServer("Rebirth")
	end)
end

return Rebirth
