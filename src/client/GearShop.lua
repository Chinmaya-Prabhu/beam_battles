-- The gear stalls on the client (server/Zones/GymKit.lua builds them, TrainingService sells):
--   * walking up to a stall opens the TRAINING GEAR window (walking away closes it): one scrolling list, the
--     two premium weights first, then every weight on the ladder, each with a 3D preview, rarity, multiplier
--     and BUY / OWNED / REBIRTH n (no stock, no restock: everything is always for sale),
--   * the two premium weights on the stall's pedestals prompt a Robux purchase ("PremiumPrompt").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Training = require(Shared.Training)
local GearLook = require(Shared.GearLook)
local Products = require(Shared.Products)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Fancy = require(script.Parent.Fancy)

local GearShop = {}
local player = Players.LocalPlayer
local OPEN_AT, CLOSE_AT = 11, 15 -- studs from the stall (the posts and bags stand well away from it)

local window, rows = nil, {}
local current -- the stall model the window is open for
local dismissed -- a stall the player closed the window at (stays shut until they walk away)
local shownFor -- the stall the window was last opened for

-- A spinning 3D preview of a weight in a ViewportFrame.
local function preview(parent, look)
	local old = parent:FindFirstChild("Preview")
	if old then
		old:Destroy()
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromOffset(56, 56)
	vp.Position = UDim2.fromOffset(6, 4)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.Parent = parent
	local model = GearLook.band(look, 1.4, 1)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	model:PivotTo(CFrame.Angles(0, 0, 0.4))
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 2.6), Vector3.zero)
	cam.FieldOfView = 50
	cam.Parent = vp
	vp.CurrentCamera = cam
	return model
end

local function build(gui)
	local w, body = UIKit.window(gui, "TRAINING GEAR", Vector2.new(600, 660))
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y -- the whole window scrolls: premium cards and the list
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = body
	-- Featured: the two premium weights, big and loud, above the regular ladder.
	local featured = Instance.new("Frame")
	featured.LayoutOrder = 0
	featured.BackgroundTransparency = 1
	featured.Size = UDim2.new(1, -14, 0, 262)
	featured.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 16)
	layout.Parent = featured
	for _, pass in Products.Passes do
		if pass.gear then
			local g = Training.Gear[pass.gear]
			local _, label, buy = Fancy.premiumCard(featured, {
				look = g.look,
				name = g.name,
				rarity = string.upper(Training.gearRarity(pass.gear)),
				mult = g.mult,
				price = pass.price,
				color = g.look == "dragon" and Color3.fromRGB(60, 220, 100) or Color3.fromRGB(255, 130, 20),
				onBuy = function()
					if player:GetAttribute(pass.key) then
						return
					end
					if RunService:IsStudio() then
						Net.get("Shop"):FireServer("DebugBuy", pass.key) -- (Studio: a test grant)
					elseif pass.id ~= 0 then
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end
				end,
			})
			local function owned()
				local own = player:GetAttribute(pass.key) == true
				label.Text = own and "OWNED" or (utf8.char(0xE002) .. " " .. pass.price)
				UIKit.setPill(buy, own and "grey" or "green")
			end
			owned()
			player:GetAttributeChangedSignal(pass.key):Connect(owned)
		end
	end
	-- One row per weight on the Ki ladder (Cloth Wraps, the start, is everyone's), filled by refresh().
	for tier = 2, Training.LadderTop do
		local g = Training.Gear[tier]
		local row = Instance.new("ImageLabel")
		row.LayoutOrder = tier
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -14, 0, 64)
		UIKit.skin(row, "card", 0.2)
		row.Parent = body
		local spin = preview(row, g.look)
		UIKit.text(row, {
			Style = "heading",
			TextSize = 18,
			Position = UDim2.fromOffset(70, 9),
			Size = UDim2.new(1, -236, 0, 22),
			Text = string.upper(g.name),
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 0,
		})
		local rarity = Training.gearRarity(tier)
		local info = UIKit.text(row, {
			Style = "label",
			TextSize = 15,
			StrokeThickness = 0,
			Position = UDim2.fromOffset(70, 34),
			Size = UDim2.new(1, -236, 0, 18),
			Text = rarity .. '  <font color="#C8D2E6">x' .. g.mult .. " per click</font>",
			TextColor3 = Config.Rarities[rarity].color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		info.RichText = true
		local button, label = UIKit.pill(row, "green", "", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(150, 46),
		})
		local r = { tier = tier, button = button, label = label, color = "green", spin = spin }
		rows[tier] = r
		button.Activated:Connect(function()
			if current and r.canBuy then
				Net.get("Train"):FireServer("BuyGear", { stall = current:GetAttribute("StallIndex"), tier = r.tier })
			end
		end)
	end
	w.Close.Activated:Connect(function()
		dismissed = current
		current = nil
	end)
	return w
end

local function setRow(r, text, color)
	r.label.Text = text
	if r.color ~= color then
		r.color = color
		UIKit.setPill(r.button, color)
	end
end

local function refresh()
	if not current then
		return
	end
	local owned = player:GetAttribute("Gear") or 1
	local ki = player:GetAttribute("Ki") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	for tier, r in rows do
		local g = Training.Gear[tier]
		r.canBuy = false
		if tier <= owned then
			setRow(r, "OWNED", "grey")
		elseif g.rebirth and rebirths < g.rebirth then
			setRow(r, "REBIRTH " .. g.rebirth, "gold")
		else
			r.canBuy = ki >= g.cost
			setRow(r, Format.short(g.cost) .. " KI", r.canBuy and "green" or "red")
		end
	end
end

function GearShop.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GearShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9 -- windows sit above the HUD and the goals (Tutorial, 8)
	gui.Parent = player:WaitForChild("PlayerGui")
	window = build(gui)
	for _, name in { "Gear", "Ki", "Rebirths" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end

	-- Premium weights: their pedestals' prompts open the Robux purchase.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		-- The premium weights' pedestals, and the gold +2 Stands stands at your base.
		if who ~= player or (prompt.Name ~= "PremiumPrompt" and not prompt:GetAttribute("Pass")) then
			return
		end
		local pass = Products.ByKey[prompt:GetAttribute("Pass")]
		if not pass then
			return
		end
		if RunService:IsStudio() then
			Net.get("Shop"):FireServer("DebugBuy", pass.key) -- (Studio: a test grant)
		elseif pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end
	end)
	-- Owned premium weights say so on their prompt.
	local function premiumText()
		for _, stall in CollectionService:GetTagged("GearStall") do
			for _, p in stall:GetDescendants() do
				if p:IsA("ProximityPrompt") and p.Name == "PremiumPrompt" then
					local pass = Products.ByKey[p:GetAttribute("Pass")]
					local own = player:GetAttribute(p:GetAttribute("Pass"))
					p.ActionText = own and "Owned"
						or ("Buy  ·  " .. utf8.char(0xE002) .. " " .. (pass and pass.price or ""))
				end
			end
		end
	end
	task.delay(3, premiumText)
	for _, pass in Products.Passes do
		if pass.gear then
			player:GetAttributeChangedSignal(pass.key):Connect(premiumText)
		end
	end

	-- The floating signs over the premium pedestals: rarity in a scrolling rainbow, name, multiplier.
	local function sign(board)
		if board:FindFirstChild("Rarity") then
			return
		end
		local rarity = UIKit.text(board, {
			Name = "Rarity",
			Size = UDim2.fromScale(1, 0.36),
			Text = board:GetAttribute("Rarity") or "",
			StrokeThickness = 3,
		})
		if board:GetAttribute("Rarity") == "SECRET" then
			Fancy.rainbowText(rarity)
		else
			rarity.TextColor3 = Color3.fromRGB(255, 120, 230)
		end
		UIKit.text(board, {
			Position = UDim2.fromScale(0, 0.36),
			Size = UDim2.fromScale(1, 0.34),
			Text = board:GetAttribute("Title") or "",
			StrokeThickness = 3,
		})
		UIKit.text(board, {
			Position = UDim2.fromScale(0, 0.7),
			Size = UDim2.fromScale(1, 0.3),
			Text = (board:GetAttribute("Price") or "") .. "+ PER CLICK",
			TextColor3 = Color3.fromRGB(255, 220, 90),
			StrokeThickness = 2.5,
		})
		local base = board.StudsOffsetWorldSpace
		task.spawn(function()
			while board.Parent do
				board.StudsOffsetWorldSpace = base + Vector3.new(0, math.sin(os.clock() * 2) * 0.35, 0)
				task.wait()
			end
		end)
	end
	for _, board in CollectionService:GetTagged("FancySign") do
		sign(board)
	end
	CollectionService:GetInstanceAddedSignal("FancySign"):Connect(sign)

	-- Opens as soon as you walk up to a stall, closes when you walk away (X keeps it shut until you leave).
	RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local nearest, best
		for _, stall in CollectionService:GetTagged("GearStall") do
			local d = (stall:GetPivot().Position - root.Position).Magnitude
			if not best or d < best then
				nearest, best = stall, d
			end
		end
		if dismissed and (not best or best > CLOSE_AT or nearest ~= dismissed) then
			dismissed = nil
		end
		if nearest and best < OPEN_AT and nearest ~= dismissed and not player:GetAttribute("InClash") then
			if current ~= nearest then
				current = nearest
				refresh()
			end
		elseif current and (not best or best > CLOSE_AT or nearest ~= current) then
			current = nil
		end
		-- Only on arriving or leaving, so another window opened here (the shop) isn't fought every frame.
		if current ~= shownFor then
			shownFor = current
			window.Visible = current ~= nil
		end
		player:SetAttribute("GearShopOpen", window.Visible or nil) -- the tutorial bubble steps aside
		if current then
			for _, r in rows do
				if r.spin then
					r.spin:PivotTo(CFrame.Angles(0, os.clock() * 1.2, 0.4))
				end
			end
		end
	end)
end

return GearShop
