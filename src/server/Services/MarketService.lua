-- The Fighter Market (shared/Market.lua, server/Hub.lua fighterMarket): five fighters on plinths on the
-- hub's market street, the same for everyone, restocked every Market.Period seconds. Walk up and hold E
-- to buy one for Robux: the plinth's price tier product (MarketT1-T5) is prompted, and what the player was
-- looking at is remembered (saved, so a receipt that lands after a rejoin or a restock still gives that
-- fighter). MonetizationService calls MarketService.grant from ProcessReceipt.
-- Studio: products with id 0 can't be bought, so a Studio purchase is granted straight away.
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Fighters = require(Shared.Fighters)
local FighterModels = require(Shared.FighterModels)
local Market = require(Shared.Market)
local Products = require(Shared.Products)
local Odds = require(Shared.Odds)
local Format = require(Shared.Format)
local Reveal = require(script.Parent.Parent.Reveal)

local MarketService = {}
local ROBUX = utf8.char(0xE002)
local Data
local slots = {} -- [slot] = { spot, ring, model, prompt, item }
local shownEpoch

local function plate(model, item, featured)
	local fighter = Fighters.ByKey[item.key]
	local anchor = model:FindFirstChild("Head") or model.PrimaryPart
	if not anchor then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "MarketPlate"
	-- Sized in studs, so far plates shrink instead of piling over each other.
	gui.Size = UDim2.fromScale(featured and 9 or 7.5, featured and 5 or 4.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.4 * model:GetScale(), 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = model
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local function line(text, color, height, order)
		local t = Instance.new("TextLabel")
		t.LayoutOrder = order
		t.Size = UDim2.fromScale(1, height / 130)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.LuckiestGuy
		t.Text = text
		t.TextScaled = true
		t.TextColor3 = color
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = Color3.fromRGB(30, 20, 40)
		t.Parent = gui
	end
	if featured then
		line("FEATURED", Color3.fromRGB(255, 214, 80), 16, 0)
	end
	if item.mutation ~= "Normal" then
		line(string.upper(item.mutation), Color3.fromRGB(255, 230, 120), 18, 1)
	end
	line(fighter.display, Color3.new(1, 1, 1), 28, 2)
	line(string.upper(fighter.rarity), Config.Rarities[fighter.rarity].color, 20, 3)
	line(Format.cash(Odds.income(item.key, item.mutation)) .. "/s", Color3.fromRGB(110, 255, 110), 20, 4)
	line(ROBUX .. " " .. Products.ByKey[item.product].price, Color3.fromRGB(120, 230, 255), 24, 5)
end

local function show(epoch)
	shownEpoch = epoch
	local stock = Market.stock(epoch)
	for slot, s in slots do
		if s.model then
			s.model:Destroy()
			s.model = nil
		end
		local item = stock[slot]
		s.item = item
		s.prompt.Enabled = item ~= nil
		if item then
			local fighter = Fighters.ByKey[item.key]
			local featured = slot == Market.Slots
			-- A Huge one stands a bit bigger, not 2x: on a plinth it would hide the rest of the market.
			local scale = FighterModels.scaleFor(item.key, "Table")
				* (featured and 1.15 or 1)
				* math.min(Config.Mutations[item.mutation].scale or 1, 1.35)
			local feet = s.spot.Position
			local function make(k)
				return FighterModels.spawn(item.key, feet, -s.spot.LookVector, { -- face the road
					scale = k,
					parent = s.folder,
					mutation = item.mutation,
					aura = true,
				})
			end
			local model = make(scale)
			-- Anything taller (titans, Huge mutations) is shrunk to fit under the sign.
			local tallest = featured and 21 or 18 -- under the sign (its board starts about 24 up); giants stand clearly taller (server/Hub.lua fighterMarket)
			local size = model and select(2, model:GetBoundingBox())
			if model and size.Y > tallest then
				model:Destroy()
				model = make(scale * tallest / size.Y)
			end
			if model then
				model.Name = "MarketFighter"
				model:SetAttribute("Clip", Fighters.signature(item.key))
				model:SetAttribute("ClipStart", workspace:GetServerTimeNow())
				plate(model, item, featured)
				s.model = model
			end
			s.ring.Color = Config.Rarities[fighter.rarity].color
			s.prompt.ObjectText = (item.mutation ~= "Normal" and (item.mutation .. " ") or "") .. fighter.display
			s.prompt.ActionText = "Buy  ·  " .. ROBUX .. " " .. Products.ByKey[item.product].price
		end
	end
end

-- Gives a market fighter for `productKey` (ProcessReceipt). Returns true once granted.
function MarketService.grant(player, productKey)
	local data = Data.get(player)
	if not data then
		return false
	end
	data.marketPending = data.marketPending or {}
	local pending = data.marketPending[productKey]
	local key, mutation = pending and pending.k, pending and pending.m
	if not (key and Fighters.ByKey[key]) then
		-- Nothing remembered (shouldn't happen): whatever is on show at that price now, else the
		-- featured plinth.
		for _, s in slots do
			if s.item and s.item.product == productKey then
				key, mutation = s.item.key, s.item.mutation
			end
		end
	end
	if not key then
		return false
	end
	data.marketPending[productKey] = nil
	Data.changed(player)
	Reveal.giveFighter(player, key, mutation or "Normal", true) -- (bought: carried to a stand)
	return true
end

local function buy(player, slot)
	local s = slots[slot]
	local item = s and s.item
	local data = Data.get(player)
	if not item or not data then
		return
	end
	data.marketPending = data.marketPending or {}
	data.marketPending[item.product] = { k = item.key, m = item.mutation }
	Data.changed(player)
	local product = Products.ByKey[item.product]
	if product.id == 0 then
		if RunService:IsStudio() then
			MarketService.grant(player, item.product) -- Studio test purchase
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
end

function MarketService.start(world, DataService)
	Data = DataService
	local spec = world.market
	if not spec then
		return
	end
	for slot, spot in spec.spots do
		local folder = Instance.new("Folder")
		folder.Name = "MarketSlot" .. slot
		folder.Parent = world.root
		local anchor = Instance.new("Part")
		anchor.Name = "MarketPromptAnchor"
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		-- Low on the plinth's front, so the prompt never covers the fighter's face.
		anchor.CFrame = spot * CFrame.new(0, -2.2, 4) -- the road side
		anchor.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MarketPrompt"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player)
			buy(player, slot)
		end)
		slots[slot] = { spot = spot, ring = spec.rings[slot], prompt = prompt, folder = folder }
	end
	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			local epoch = Market.epoch(now)
			if epoch ~= shownEpoch then
				show(epoch)
			end
			local left = math.max(0, math.floor(Market.endsAt(epoch) - now))
			for _, label in spec.countdown do -- (front and back of the sign)
				label.Text = string.format("NEW STOCK IN %d:%02d", left // 60, left % 60)
			end
			task.wait(1)
		end
	end)
end

return MarketService
