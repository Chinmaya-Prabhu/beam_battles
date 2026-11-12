-- The shop (shared/Products.lua, server/Services/MonetizationService.lua): a SHOP tile in the HUD menu opens
-- a tabbed window (docs/SHOP_RESEARCH.md), with the player's Cash in the corner:
--   FEATURED  the Starter Pack (new players, with its countdown), the premium weights, the fighter summons,
--   PASSES    gamepasses,
--   BOOSTS    timed boosts and one-off skips,
--   CASH      cash packs.
-- Each card shows its icon, name, a short line and a price pill: the live Robux price, OWNED, or a running
-- boost timer. Owners of Auto Train get an AUTO tile; while Server Luck runs, a timer shows at the top of
-- everyone's screen. Shop.open(tab) opens the window on a tab (the moment offers use it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared.Products)
local UIAtlas = require(Shared.UIAtlas)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.UIKit)
local Fancy = require(script.Parent.Fancy)
local Training = require(Shared.Training)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local BeamSkins = require(Shared.BeamSkins)
local BeamPreview = require(script.Parent.BeamPreview)

local Shop = {}
local player = Players.LocalPlayer
local remote

-- The Roblox currency glyph in Roblox's built-in fonts.
local ROBUX = utf8.char(0xE002)
local ICONS = {
	VIP = "vip",
	DoubleCash = "double_cash",
	DoublePower = "double_power",
	AutoTrain = "auto_train",
	FastSteal = "fast_steal",
	ServerLuck = "server_luck",
	PowerBoost = "power_boost",
	Shield = "shield",
	CashLarge = "cash_large",
	StandNow = "stand_now",
	DropLuck = "server_luck",
	ProBundle = "chest",
	MutationLuck = "confetti",
	ExtraStands = "stand_now",
	Floor2 = "stand_now",
	CashHuge = "chest",
}
-- Which tab each product sits on (passes go to PASSES; summons and the starter pack are FEATURED).
local TAB_OF = {
	ServerLuck = "BOOSTS",
	PowerBoost = "BOOSTS",
	Shield = "BOOSTS",
	StandNow = "BOOSTS",
	CashLarge = "CASH",
	CashHuge = "CASH",
}
local TABS = { "FEATURED", "PASSES", "BEAMS", "BOOSTS", "CASH" }

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function isPass(product)
	return table.find(Products.Passes, product) ~= nil
end

local function buy(product)
	if RunService:IsStudio() and (isPass(product) or product.id == 0) then
		remote:FireServer("DebugBuy", product.key) -- (Studio: a test grant; the game's creator "owns" every real pass)
	elseif product.id ~= 0 then
		if isPass(product) then
			UIKit.promptPass(product.key, product.id)
		else
			MarketplaceService:PromptProductPurchase(player, product.id)
		end
	end
end

-- ------------------------------------------------------------------ window

local cards = {} -- { product, price (pill), label, color }
local pages, tabButtons = {}, {}
local starterCard, starterTimer
local window

local function page(body)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(0, 58)
	scroll.Size = UDim2.new(1, 0, 1, -58)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = UIKit.SKY
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Visible = false
	scroll.Parent = body
	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, 14)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stack.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = scroll
	return scroll
end

local function grid(parent, order)
	local holder = Instance.new("Frame")
	holder.LayoutOrder = order or 10
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -14, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = parent
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(152, 196)
	g.CellPadding = UDim2.fromOffset(12, 12)
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = holder
	return holder
end

local function row(parent, order, height)
	local f = Instance.new("Frame")
	f.LayoutOrder = order
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -14, 0, height)
	f.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 16)
	l.Parent = f
	return f
end

local function heading(parent, order, text)
	local h = UIKit.text(parent, {
		LayoutOrder = order,
		Size = UDim2.new(1, -20, 0, 30),
		Text = text,
		TextColor3 = UIKit.GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	return h
end

-- A regular product card (icon, name, line, price pill).
local function productCard(parent, product, order)
	local card = Instance.new("ImageLabel")
	card.LayoutOrder = product.includes and 0 or order
	card.BackgroundTransparency = 1
	UIKit.skin(card, isPass(product) and "card" or "tile_blue", 0.3)
	card.Parent = parent
	UIAtlas.label(card, ICONS[product.key] or "gift", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(72, 72),
	})
	-- Fixed size so every card's title matches (TextScaled would shrink long names on their own).
	local title = UIKit.text(card, {
		Position = UDim2.fromOffset(6, 84),
		Size = UDim2.new(1, -12, 0, 24),
		Text = string.upper(product.name),
		TextColor3 = isPass(product) and UIKit.GOLD or Color3.new(1, 1, 1),
	})
	title.TextScaled = false
	title.TextSize = 19
	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(10, 110)
	desc.Size = UDim2.new(1, -20, 0, 34)
	desc.Font = Enum.Font.GothamBold
	desc.TextWrapped = true
	desc.TextScaled = true
	desc.TextColor3 = Color3.new(1, 1, 1)
	desc.Text = product.desc
	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MaxTextSize = 13
	tsc.Parent = desc
	desc.Parent = card
	local price, text = UIKit.pill(card, "green", ROBUX .. " " .. product.price, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -18, 0, 40),
	})
	price.Activated:Connect(function()
		buy(product)
	end)
	table.insert(cards, { product = product, price = price, label = text, color = "green", card = card, desc = desc })
	if product.includes then
		UIKit.skin(card, "tile_gold", 0.3)
	end
	return card
end

-- A dark card with a gradient and a rounded border (summons, the starter pack).
local function darkCard(parent, size, color)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(26, 20, 48)
	card.Size = size
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = card
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.25), Color3.fromRGB(18, 14, 36))
	bg.Parent = card
	card.Parent = parent
	return card
end

-- A fighter summon (the lucky block): a glowing mystery orb in the rarity's colour over turning rays.
local function summonCard(parent, product)
	local color = Config.Rarities[product.floor].color
	local card = darkCard(parent, UDim2.fromOffset(200, 268), color)
	if product.floor == "Secret" then
		Fancy.rainbowStroke(card, 5)
	else
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = color
		stroke.Parent = card
	end
	local tag = UIKit.text(card, {
		Style = "heading",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 24),
		Text = string.upper(product.floor) .. (product.floor == "Secret" and "" or "+"),
		TextColor3 = color,
		ZIndex = 5,
		StrokeThickness = 2.5,
	})
	if product.floor == "Secret" then
		Fancy.rainbowText(tag)
	end
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0)
	stage.Position = UDim2.new(0.5, 0, 0, 36)
	stage.Size = UDim2.fromOffset(110, 110)
	stage.Parent = card
	local orb = Instance.new("Frame")
	orb.AnchorPoint = Vector2.new(0.5, 0.5)
	orb.Position = UDim2.fromScale(0.5, 0.5)
	orb.Size = UDim2.fromOffset(84, 84)
	orb.BackgroundColor3 = color
	orb.ZIndex = 3
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = orb
	local shade = Instance.new("UIGradient")
	shade.Rotation = 120
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), color:Lerp(Color3.new(0, 0, 0), 0.3))
	shade.Parent = orb
	local ring = Instance.new("UIStroke")
	ring.Thickness = 4
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = orb
	orb.Parent = stage
	UIKit.text(orb, {
		Size = UDim2.fromScale(1, 1),
		Text = "?",
		ZIndex = 4,
		StrokeThickness = 3,
	})
	UIKit.text(card, {
		Position = UDim2.fromOffset(8, 150),
		Size = UDim2.new(1, -16, 0, 24),
		Text = string.upper(product.name),
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		StrokeThickness = 3,
	})
	-- The odds, so the buyer sees exactly what they can get.
	local odds = {}
	for _, key in Config.RarityOrder do
		if product.odds[key] then
			table.insert(odds, key .. " " .. product.odds[key] .. "%")
		end
	end
	UIKit.text(card, {
		Style = "small",
		Position = UDim2.fromOffset(10, 176),
		Size = UDim2.new(1, -20, 0, 30),
		Text = table.concat(odds, " · "),
		TextColor3 = Color3.fromRGB(255, 225, 120),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 5,
	})
	local price, text = UIKit.pill(card, "green", ROBUX .. " " .. product.price, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -30, 0, 44),
		ZIndex = 6,
	})
	price.Activated:Connect(function()
		buy(product)
	end)
	table.insert(cards, { product = product, price = price, label = text, color = "green" })
end

-- The Starter Pack banner: everything it holds, a big discount badge and the time left to get it.
local function starterBanner(parent, order)
	local product = Products.ByKey.StarterPack
	local card = darkCard(parent, UDim2.new(1, -24, 0, 150), Color3.fromRGB(255, 170, 40))
	card.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = UIKit.GOLD
	stroke.Parent = card
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(20, 15)
	stage.Size = UDim2.fromOffset(120, 120)
	stage.Parent = card
	UIAtlas.label(stage, "gift", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(100, 100),
		ZIndex = 3,
	})
	local title = UIKit.text(card, {
		Style = "title",
		Position = UDim2.fromOffset(156, 12),
		Size = UDim2.new(1, -340, 0, 36),
		Text = "STARTER PACK",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		StrokeThickness = 3,
	})
	title.TextColor3 = UIKit.GOLD
	local lines = {
		"Epic fighter",
		"Iron Weights (x8 per click)",
		"2x Training for 30 min",
		"$" .. Format.short(Products.StarterCash) .. " cash",
	}
	for i, l in lines do
		UIKit.text(card, {
			Style = "label",
			Position = UDim2.fromOffset(156, 50 + (i - 1) * 22),
			Size = UDim2.new(1, -340, 0, 20),
			Text = "+  " .. l,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		})
	end
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -18, 0, 12)
	badge.Size = UDim2.fromOffset(150, 40)
	badge.BackgroundColor3 = Color3.fromRGB(235, 50, 50)
	badge.Rotation = 4
	badge.ZIndex = 6
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 10)
	bc.Parent = badge
	badge.Parent = card
	UIKit.text(badge, {
		Style = "label",
		Size = UDim2.fromScale(1, 1),
		Text = "NEW PLAYERS · ONE TIME",
		TextSize = 14,
		ZIndex = 7,
	})
	starterTimer = UIKit.text(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 56),
		Size = UDim2.fromOffset(170, 22),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 120, 110),
		ZIndex = 5,
		StrokeThickness = 2,
	})
	local price, text = UIKit.pill(card, "green", ROBUX .. " " .. product.price, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -14),
		Size = UDim2.fromOffset(170, 50),
		ZIndex = 6,
	})
	Fancy.pulse(price)
	price.Activated:Connect(function()
		buy(product)
	end)
	table.insert(cards, { product = product, price = price, label = text, color = "green" })
	Fancy.shine(card)
	return card
end

-- A beam skin (shared/BeamSkins.lua): a dark card with the beam itself, moving in 3D (client/BeamPreview.lua),
-- then buy / EQUIP / EQUIPPED (tap EQUIPPED to go back to your side's colour).
local previews = {} -- BeamPreview objects, stepped while the BEAMS page shows
local function beamCard(parent, product, order)
	local skin = BeamSkins.ByKey[product.beam]
	local card = darkCard(parent, UDim2.fromOffset(220, 258), skin.glow)
	card.LayoutOrder = order
	card.ClipsDescendants = true
	local edge = Instance.new("UIStroke")
	edge.Thickness = 4
	edge.Color = skin.glow
	edge.Parent = card
	if skin.style == "rainbow" then
		edge:Destroy()
		Fancy.rainbowStroke(card, 4)
	end
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(0, 6)
	stage.Size = UDim2.new(1, 0, 0, 132)
	stage.Parent = card
	table.insert(previews, BeamPreview.new(stage, skin))
	local title = UIKit.text(card, {
		Position = UDim2.fromOffset(8, 138),
		Size = UDim2.new(1, -16, 0, 28),
		Text = string.upper(product.name),
		TextColor3 = skin.glow:Lerp(Color3.new(1, 1, 1), 0.45),
	})
	title.TextScaled = false
	title.TextSize = 22
	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(12, 168)
	desc.Size = UDim2.new(1, -24, 0, 30)
	desc.Font = Enum.Font.GothamBold
	desc.TextWrapped = true
	desc.TextScaled = true
	desc.TextColor3 = Color3.fromRGB(220, 215, 240)
	desc.Text = product.desc
	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MaxTextSize = 14
	tsc.Parent = desc
	desc.Parent = card
	local price, text = UIKit.pill(card, "green", ROBUX .. " " .. product.price, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 44),
	})
	price.Activated:Connect(function()
		if player:GetAttribute("Owns_" .. product.key) then
			remote:FireServer("EquipBeam", player:GetAttribute("BeamSkin") == product.beam and "" or product.beam)
		else
			buy(product)
		end
	end)
	table.insert(cards, { product = product, price = price, label = text, color = "green", card = card, desc = desc })
	return card
end

local function selectTab(name)
	for tab, p in pages do
		p.Visible = tab == name
		UIKit.setPill(tabButtons[tab], tab == name and "gold" or "grey")
	end
end

local refreshCards -- defined below; the deals row calls it

local function buildWindow(gui)
	local w, body = UIKit.window(gui, "SHOP", Vector2.new(760, 600), { scrolls = false })
	-- Tabs across the top, the player's balance on the right.
	for i, name in TABS do
		local b = UIKit.pill(body, "grey", name, {
			Position = UDim2.fromOffset(4 + (i - 1) * 112, 4),
			Size = UDim2.fromOffset(106, 44),
		})
		b.Activated:Connect(function()
			selectTab(name)
		end)
		tabButtons[name] = b
		pages[name] = page(body)
	end
	-- The balance sits in the title bar, right of the title and clear of the close button.
	local title = w:FindFirstChild("Title")
	local balance = UIKit.text(w, {
		Style = "number",
		TextSize = 22,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -70, 0, title and (title.Position.Y.Offset + title.Size.Y.Offset / 2) or 40),
		Size = UDim2.fromOffset(300, 28),
		Text = "",
		TextColor3 = Color3.fromRGB(150, 255, 150),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})
	balance.RichText = true
	local function money()
		balance.Text = Format.cash(player:GetAttribute("Cash") or 0)
	end
	money()
	player:GetAttributeChangedSignal("Cash"):Connect(money)

	-- FEATURED: starter pack, premium weights, summons.
	local featured = pages.FEATURED
	-- This week's deals: products the remote config features (LiveOpsService "Featured"), rebuilt when it changes.
	local dealsHead = heading(featured, 0, "THIS WEEK'S DEALS")
	local deals
	local function buildDeals()
		if deals then
			deals:Destroy()
		end
		deals = grid(featured, 0)
		deals.Name = "Deals"
		local keys = string.split(ReplicatedStorage:GetAttribute("Featured") or "", ",")
		local n = 0
		for i, key in keys do
			local product = Products.ByKey[key]
			if product and not product.gear then
				productCard(deals, product, i)
				n += 1
			end
		end
		dealsHead.Visible, deals.Visible = n > 0, n > 0
		dealsHead.LayoutOrder, deals.LayoutOrder = -2, -1
		refreshCards()
	end
	starterCard = starterBanner(featured, 1)
	heading(featured, 2, "PREMIUM WEIGHTS")
	local weights = row(featured, 3, 262)
	for _, pass in Products.Passes do
		if pass.gear then
			local g = Training.Gear[pass.gear]
			local card, label, button = Fancy.premiumCard(weights, {
				look = g.look,
				name = g.name,
				rarity = string.upper(Training.gearRarity(pass.gear)),
				mult = g.mult,
				price = pass.price,
				color = g.look == "dragon" and Color3.fromRGB(60, 220, 100) or Color3.fromRGB(255, 130, 20),
				onBuy = function()
					if not player:GetAttribute(pass.key) then
						buy(pass)
					end
				end,
			})
			local function owned()
				local own = player:GetAttribute(pass.key) == true
				label.Text = own and "OWNED" or (ROBUX .. " " .. pass.price)
				UIKit.setPill(button, own and "grey" or "green")
				if card then
					card.Visible = not own -- (bought once, kept forever: nothing left to sell)
				end
			end
			owned()
			player:GetAttributeChangedSignal(pass.key):Connect(owned)
		end
	end
	-- Summons are paid random items: shown only where Roblox allows them (PaidRandomOK, MonetizationService).
	local summonHead = heading(featured, 4, "FIGHTER SUMMONS")
	local summons = row(featured, 5, 276)
	for _, item in Products.Items do
		if item.floor then
			summonCard(summons, item)
		end
	end
	local function policy()
		local ok = player:GetAttribute("PaidRandomOK") == true
		summonHead.Visible, summons.Visible = ok, ok
	end
	policy()
	player:GetAttributeChangedSignal("PaidRandomOK"):Connect(policy)

	-- The other tabs: grids of regular cards.
	local grids = { PASSES = grid(pages.PASSES), BOOSTS = grid(pages.BOOSTS), CASH = grid(pages.CASH) }
	heading(pages.BEAMS, 0, "BEAM SKINS · LOOKS ONLY, NEVER STRONGER")
	local beams = grid(pages.BEAMS, 1)
	beams:FindFirstChildOfClass("UIGridLayout").CellSize = UDim2.fromOffset(220, 258)
	-- The previews move only while the BEAMS page is on screen.
	game:GetService("RunService").RenderStepped:Connect(function()
		if w.Visible and pages.BEAMS.Visible then
			local t = os.clock()
			for _, preview in previews do
				preview:step(t)
			end
		end
	end)
	local order = 0
	for _, list in { Products.Passes, Products.Items } do
		for _, product in list do
			if product.beam then
				order += 1
				beamCard(beams, product, order)
				continue
			end
			local tab = isPass(product) and "PASSES" or TAB_OF[product.key]
			if product.gear or not tab then
				continue -- featured
			end
			order += 1
			productCard(grids[tab], product, order)
		end
	end
	-- The real prices from Roblox once the products exist.
	for _, list in { Products.Passes, Products.Items } do
		for _, product in list do
			if product.id ~= 0 then
				task.spawn(function()
					local info = isPass(product) and Enum.InfoType.GamePass or Enum.InfoType.Product
					local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.id, info)
					if ok and result and result.PriceInRobux then
						product.price = result.PriceInRobux
					end
				end)
			end
		end
	end
	selectTab("FEATURED")
	task.defer(buildDeals)
	ReplicatedStorage:GetAttributeChangedSignal("Featured"):Connect(buildDeals)
	return w
end

-- Price pills: OWNED / ACTIVE timer / price / SOON.
local function setCard(c, text, color)
	c.label.Text = text
	if c.color ~= color then
		c.color = color
		UIKit.setPill(c.price, color)
	end
end

-- A bundle's saving, from the live prices of what it includes.
local function bundleSaving(bundle)
	local sum = 0
	for _, key in bundle.includes do
		sum += Products.ByKey[key].price
	end
	return sum - bundle.price
end

function refreshCards()
	local now = os.time()
	local starterEnds = player:GetAttribute("StarterUntil")
	starterCard.Visible = starterEnds ~= nil and starterEnds > now
	if starterCard.Visible then
		local left = starterEnds - now
		starterTimer.Text =
			string.format("ENDS IN %dD %02dH %02dM", left // 86400, left % 86400 // 3600, left % 3600 // 60)
	end
	local luckLeft = (ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0) - workspace:GetServerTimeNow()
	for _, c in cards do
		local p = c.product
		-- A bundle hides once you own any part of it (no paying twice), and says what it saves.
		if p.includes and c.card then
			local ownsPart = false
			for _, key in p.includes do
				ownsPart = ownsPart or player:GetAttribute("Owns_" .. key) == true
			end
			c.card.Visible = not ownsPart or player:GetAttribute("Owns_" .. p.key) == true
			local saving = bundleSaving(p)
			c.desc.Text = p.desc .. (saving > 0 and (" · save " .. saving .. " R$") or "")
		end
		local owned = isPass(p) and (player:GetAttribute("Owns_" .. p.key) or player:GetAttribute(p.key))
		local left = p.key == "PowerBoost" and (player:GetAttribute("PowerBoostUntil") or 0) - now
			or p.key == "ServerLuck" and luckLeft
			or 0
		if p.beam and owned then
			if player:GetAttribute("BeamSkin") == p.beam then
				setCard(c, "EQUIPPED", "gold")
			else
				setCard(c, "EQUIP", "green")
			end
		elseif owned then
			setCard(c, "OWNED", "grey")
			if c.card then
				c.card.Visible = false -- a one-time pass that's already bought isn't shown (beam skins stay: EQUIP)
			end
		elseif left > 0 then
			setCard(c, "+ " .. clock(left), "gold")
		elseif p.id == 0 and not RunService:IsStudio() then
			setCard(c, "SOON", "grey")
		else
			setCard(c, ROBUX .. " " .. p.price, "green")
		end
	end
end

function Shop.start()
	remote = Net.get("Shop")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9 -- windows sit above the HUD and the goals (Tutorial, 8)
	gui.Parent = player:WaitForChild("PlayerGui")
	window = buildWindow(gui)

	local menu = UIKit.menu()
	local shop = UIKit.tile(menu, "shop", "SHOP", { LayoutOrder = 1 })
	shop.Activated:Connect(function()
		window.Visible = not window.Visible
		refreshCards()
	end)
	player:GetAttributeChangedSignal("StarterUntil"):Connect(refreshCards)
	task.spawn(function()
		while true do
			if window.Visible then
				refreshCards()
			end
			task.wait(1)
		end
	end)
end

function Shop.close()
	if window then
		window.Visible = false
	end
end

-- Opens the shop on a tab (FEATURED, PASSES, BOOSTS or CASH).
function Shop.open(tab)
	if not window then
		return
	end
	selectTab(tab or "FEATURED")
	window.Visible = true
	refreshCards()
end

return Shop
