-- The Fighter Roll button and its reveal (shared/Roll.lua, server/Services/RollService.lua).
--   * Bottom centre, after the tutorial: the banner's name with arrows to switch banners, a big ROLL button
--     with your tickets and the cash fee (FREE ROLL! for the very first), the nearest pity goal ("RARE IN 3"),
--     or where tickets come from when you have none,
--     AUTO (the Auto Roll pass) and SELL COMMONS, and ODDS (every banner's odds, always shown).
--   * The reveal over the top of the screen: a quick pop for Common to Rare, a short spin with a flash for
--     Epic and up (one roll in eight flicks past a rarer fighter first), the fighter posed, "1 in X".
-- Hidden during the tutorial and fights.
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roll = require(Shared.Roll)
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local Format = require(Shared.Format)
local Odds = require(Shared.Odds)
local Products = require(Shared.Products)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)

local RollUI = {}
local player = Players.LocalPlayer
local remote = Net.get("Roll")

local gui, panel, button, buttonLabel, priceLabel, titleLabel, pityLabel, autoPill, sellPill
local selected = "Hub"
local autoOn = false

local function open()
	local bosses = {}
	for name in Config.Zones do
		bosses[name] = player:GetAttribute("Boss_" .. name) == true
	end
	local list = {}
	for _, b in Roll.Banners do
		if Roll.open(b, bosses) then
			table.insert(list, b)
		end
	end
	return list
end

local function refresh()
	local list = open()
	local banner = Roll.ById[selected]
	if not table.find(list, banner) then
		banner = list[#list]
		selected = banner.id
	end
	titleLabel.Text = banner.title
	local tickets = player:GetAttribute("Tickets") or 0
	local first = player:GetAttribute("FirstRoll") == true
	local fee = first and 0 or math.floor(banner.cost * Roll.Tickets.fee)
	local can = tickets >= 1 and (player:GetAttribute("Cash") or 0) >= fee
	buttonLabel.Text = tickets < 1 and "NO TICKETS" or first and "FREE ROLL!" or "ROLL"
	priceLabel.Text = tickets < 1 and ""
		or ("x" .. tickets .. " TICKETS" .. (fee > 0 and ("  ·  " .. Format.cash(fee)) or ""))
	local cash = player:GetAttribute("Cash") or 0
	UIKit.setPill(button, can and "green" or "grey")
	local ok, pity = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("RollPity") or "{}")
	local rarity, left = Roll.nextPity(ok and pity or {})
	if tickets < 1 then
		-- Where tickets come from (the reward for playing: shared/Roll.lua Roll.Tickets).
		pityLabel.Text = "FIGHT & TRAIN FOR TICKETS"
		pityLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
	else
		pityLabel.Text = string.upper(rarity) .. " IN " .. left
		pityLabel.TextColor3 = Config.Rarities[rarity].color
	end
	panel.Left.Visible = list[1] ~= banner
	panel.Right.Visible = list[#list] ~= banner
	UIKit.setPill(sellPill, player:GetAttribute("AutoSell") ~= false and "green" or "grey")
	UIKit.setPill(autoPill, autoOn and "green" or "grey")
end

local function visible()
	local done = (player:GetAttribute("Ftue") or 99) >= 99
	-- (Out of the way while carrying a fighter or under a steal alert: those lines use the bottom on phones.)
	panel.Visible = done
		and not UIKit.inFight()
		and not player:GetAttribute("Carrying")
		and not player:GetAttribute("StealAlert")
end

-- ------------------------------------------------------------------ reveal

local revealGui
local queue, showing = {}, false

local function portrait(parent, key, mutation)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.Parent = parent
	local model = FighterModels.spawn(key, Vector3.zero, Vector3.new(0, 0, 1), { parent = vp, mutation = mutation })
	local height = 5
	if model then
		FighterModels.holdPose(model, Fighters.signature(key))
		local _, size = model:GetBoundingBox()
		height = math.max(size.Y, size.X * 0.8, 1)
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(
		Vector3.new(0, height / 2, height / 2 / math.tan(math.rad(15)) * 1.1),
		Vector3.new(0, height / 2, 0)
	)
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp
end

local function oneIn(chance)
	return string.upper(Odds.label(chance))
end

-- One card in the reveal row: the fighter, its name (with the mutation's tag), its rarity and "1 in X".
local function card(parent, r, order)
	local rarity = Config.Rarities[r.rarity]
	local fighter = Fighters.ByKey[r.key]
	local c = Instance.new("Frame")
	c.LayoutOrder = order
	c.Size = UDim2.fromOffset(170, 214)
	c.BackgroundColor3 = Color3.fromRGB(24, 22, 40)
	c.Parent = parent
	Instance.new("UICorner", c).CornerRadius = UDim.new(0, 14)
	local edge = Instance.new("UIStroke")
	edge.Thickness = 4
	edge.Color = rarity.color
	edge.Parent = c
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0)
	glow.Position = UDim2.new(0.5, 0, 0, 10)
	glow.Size = UDim2.fromOffset(120, 120)
	glow.BackgroundColor3 = rarity.color
	glow.BackgroundTransparency = 0.6
	glow.Parent = c
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 2)
	holder.Size = UDim2.fromOffset(150, 136)
	holder.Parent = c
	portrait(holder, r.key, r.mutation)
	local name = UIKit.text(c, {
		Position = UDim2.fromOffset(6, 136),
		Size = UDim2.new(1, -12, 0, 26),
		RichText = true,
		Text = UIKit.mutationTag(r.mutation) .. string.upper(fighter and fighter.display or r.key),
		StrokeThickness = 2,
	})
	name.TextScaled = true
	UIKit.text(c, {
		Position = UDim2.fromOffset(6, 162),
		Size = UDim2.new(1, -12, 0, 22),
		Text = string.upper(r.rarity),
		TextColor3 = rarity.color,
		StrokeThickness = 2,
	})
	UIKit.text(c, {
		Position = UDim2.fromOffset(6, 186),
		Size = UDim2.new(1, -12, 0, 20),
		Text = r.sold and ("SOLD +" .. Format.cash(r.sold)) or oneIn(r.chance or 0),
		TextColor3 = r.sold and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(220, 220, 235),
		StrokeThickness = 1.5,
	})
	return c, edge
end

local function play(results)
	local best = results[1]
	for _, r in results do
		if Roll.rank(r.rarity) > Roll.rank(best.rarity) then
			best = r
		end
	end
	local big = Roll.rank(best.rarity) >= Roll.rank("Epic")
	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.42) -- (a moment in the middle, like a dice roll; gone in a second)
	row.Size = UDim2.fromOffset(#results * 180, 220)
	row.BackgroundTransparency = 1
	row.Parent = revealGui
	local fit = UIKit.fitScale(row)
	if UIKit.compact() then
		fit.Scale *= 0.7
	end
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row
	-- The spin for the big ones: the card's edge flicks through the rarity colours (past a rarer one first,
	-- one time in eight), then lands with a flash.
	if big or best.near then
		local spin = Instance.new("Frame")
		spin.Size = UDim2.fromOffset(170, 214)
		spin.BackgroundColor3 = Color3.fromRGB(24, 22, 40)
		spin.Parent = row
		Instance.new("UICorner", spin).CornerRadius = UDim.new(0, 14)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 6
		stroke.Parent = spin
		local q = UIKit.text(spin, { Size = UDim2.fromScale(1, 1), Text = "?", StrokeThickness = 3 })
		q.TextColor3 = Color3.new(1, 1, 1)
		local steps = big and 12 or 6
		for i = 1, steps do
			local tier = Config.RarityOrder[(i % 6) + 1]
			if i == steps - 1 and best.near then
				tier = "Mythic" -- so close...
			end
			stroke.Color = Config.Rarities[tier].color
			task.wait(0.05 + i * 0.012)
		end
		spin:Destroy()
	end
	for i, r in results do
		local c = card(row, r, i)
		local s = Instance.new("UIScale")
		s.Scale = 0.4
		s.Parent = c
		TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if big then
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Config.Rarities[best.rarity].color
		flash.BackgroundTransparency = 0.35
		flash.ZIndex = 0
		flash.Parent = revealGui
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.delay(0.7, function()
			flash:Destroy()
		end)
	end
	task.wait(big and 2.2 or 0.9)
	TweenService:Create(row, TweenInfo.new(0.2), { Position = row.Position - UDim2.fromOffset(0, 30) }):Play()
	task.wait(0.2)
	row:Destroy()
end

local function nextReveal()
	if showing then
		return
	end
	showing = true
	while #queue > 0 do
		play(table.remove(queue, 1))
	end
	showing = false
end

-- ------------------------------------------------------------------ build

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "RollGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")
	revealGui = Instance.new("ScreenGui")
	revealGui.Name = "RollReveal"
	revealGui.ResetOnSpawn = false
	revealGui.IgnoreGuiInset = true
	revealGui.DisplayOrder = 8
	revealGui.Parent = gui.Parent
	local compact = UIKit.compact()
	panel = Instance.new("Frame")
	panel.Name = "RollPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, compact and -8 or -16)
	panel.Size = UDim2.fromOffset(420, 132)
	panel.BackgroundTransparency = 1
	panel.Visible = false
	panel.Parent = gui
	local fit = UIKit.fitScale(panel)
	if compact then
		fit.Scale *= 0.78
	end
	-- The banner's name with arrows either side.
	titleLabel = UIKit.text(panel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(280, 26),
		Text = "",
		TextColor3 = UIKit.GOLD,
		StrokeThickness = 2.5,
	})
	for _, side in { "Left", "Right" } do
		local b = UIKit.pill(panel, "grey", side == "Left" and "<" or ">", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, side == "Left" and -164 or 164, 0, -4),
			Size = UDim2.fromOffset(40, 32),
		})
		b.Name = side
		b.Activated:Connect(function()
			local list = open()
			local i = table.find(list, Roll.ById[selected]) or 1
			i = math.clamp(i + (side == "Left" and -1 or 1), 1, #list)
			selected = list[i].id
			refresh()
		end)
	end
	-- ROLL with its price.
	button, buttonLabel = UIKit.pill(panel, "green", "ROLL", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(220, 66),
	})
	buttonLabel.Position = UDim2.fromScale(0.5, 0.38)
	buttonLabel.Size = UDim2.fromScale(0.8, 0.5)
	priceLabel = UIKit.text(button, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.7, 0.3),
		Text = "",
		ZIndex = button.ZIndex + 2,
		StrokeThickness = 1.5,
	})
	local function roll()
		local banner = Roll.ById[selected]
		local fee = player:GetAttribute("FirstRoll") and 0 or math.floor(banner.cost * Roll.Tickets.fee)
		if (player:GetAttribute("Tickets") or 0) < 1 or (player:GetAttribute("Cash") or 0) < fee then
			return false
		end
		remote:FireServer("Roll", selected)
		return true
	end
	button.Activated:Connect(roll)
	-- AUTO (the pass) on the left, SELL COMMONS on the right, ODDS under, the pity goal over the button.
	autoPill = UIKit.pill(panel, "grey", "AUTO", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -118, 0, 44),
		Size = UDim2.fromOffset(84, 40),
	})
	autoPill.Activated:Connect(function()
		if player:GetAttribute("AutoRoll") then
			autoOn = not autoOn
			refresh()
		else
			local pass = Products.ByKey.AutoRoll
			if pass and pass.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			elseif RunService:IsStudio() then
				Net.get("Shop"):FireServer("DebugBuy", "AutoRoll")
			end
		end
	end)
	sellPill = UIKit.pill(panel, "green", "SELL COMMON", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.5, 118, 0, 44),
		Size = UDim2.fromOffset(110, 40),
	})
	sellPill.Activated:Connect(function()
		remote:FireServer("AutoSell", player:GetAttribute("AutoSell") == false)
	end)
	pityLabel = UIKit.text(panel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(200, 22), -- (clear of ODDS beside it)
		Text = "",
		StrokeThickness = 2,
	})
	local odds = UIKit.pill(panel, "grey", "ODDS", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.5, 118, 0, 90),
		Size = UDim2.fromOffset(84, 32),
	})
	-- The odds window: every rarity of the selected banner, as % and "1 in X".
	local oddsGui = Instance.new("ScreenGui")
	oddsGui.Name = "RollOdds"
	oddsGui.ResetOnSpawn = false
	oddsGui.IgnoreGuiInset = true
	oddsGui.DisplayOrder = 9 -- (windows sit above the HUD)
	oddsGui.Parent = gui.Parent
	local window, body = UIKit.window(oddsGui, "ROLL ODDS", Vector2.new(520, 480))
	window.Visible = false
	local oddsLines = Instance.new("Frame")
	oddsLines.BackgroundTransparency = 1
	oddsLines.Size = UDim2.new(1, 0, 0, 400)
	oddsLines.Parent = body
	odds.Activated:Connect(function()
		for _, c in oddsLines:GetChildren() do
			c:Destroy()
		end
		local banner = Roll.ById[selected]
		local y = 6
		UIKit.text(oddsLines, {
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.new(1, -20, 0, 28),
			Text = banner.title .. "  ·  " .. Format.cash(banner.cost),
			TextColor3 = UIKit.GOLD,
		})
		y += 40
		for _, rarity in Config.RarityOrder do
			local chance = Roll.chance(banner, rarity)
			if chance > 0 then
				UIKit.text(oddsLines, {
					Position = UDim2.fromOffset(20, y),
					Size = UDim2.new(1, -40, 0, 30),
					Text = string.upper(rarity)
						.. "   "
						.. (math.floor(chance * 10000 + 0.5) / 100)
						.. "%   ("
						.. oneIn(chance)
						.. ")",
					TextColor3 = Config.Rarities[rarity].color,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				y += 36
			end
		end
		UIKit.text(oddsLines, {
			Position = UDim2.fromOffset(20, y + 6),
			Size = UDim2.new(1, -40, 0, 50),
			Text = "EVERY 10 ROLLS: A RARE OR BETTER\nEVERY 50: AN EPIC · EVERY 500: A LEGENDARY",
			TextWrapped = true,
		})
		window.Visible = true
	end)
	-- Auto Roll: presses ROLL on its own while it's on (and stops when the cash runs out).
	task.spawn(function()
		while true do
			task.wait(Roll.AutoEvery)
			if autoOn and panel.Visible and not roll() then
				autoOn = false
				refresh()
			end
		end
	end)
end

function RollUI.start()
	build()
	for _, name in { "Cash", "RollPity", "AutoSell", "Tickets", "FirstRoll", "AutoRoll", "Zones" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	for name in Config.Zones do
		player:GetAttributeChangedSignal("Boss_" .. name):Connect(refresh)
	end
	for _, name in { "Ftue", "InClash", "ClashScreen", "Carrying", "StealAlert" } do
		player:GetAttributeChangedSignal(name):Connect(visible)
	end
	refresh()
	visible()
	-- "+3 TICKETS": a pop over the ROLL button when tickets come in (a fight won, a guardian, training...).
	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		if kind ~= "Tickets" or not panel.Visible then
			return
		end
		local pop = UIKit.text(panel, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, 34),
			Size = UDim2.fromOffset(220, 30),
			Text = "+" .. data.amount .. (data.amount == 1 and " TICKET" or " TICKETS"),
			TextColor3 = UIKit.GOLD,
			StrokeThickness = 2.5,
		})
		pop.ZIndex = 20
		TweenService:Create(pop, TweenInfo.new(1.1), {
			Position = UDim2.new(0.5, 0, 0, -10),
			TextTransparency = 1,
		}):Play()
		task.delay(1.2, function()
			pop:Destroy()
		end)
	end)
	remote.OnClientEvent:Connect(function(kind, results)
		if kind == "Result" and type(results) == "table" then
			table.insert(queue, results)
			task.spawn(nextReveal)
		end
	end)
end

return RollUI
