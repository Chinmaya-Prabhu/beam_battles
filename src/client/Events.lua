-- Server events on the client (server/Services/EventService.lua):
--   * THE top chip, the one timer on screen, showing the most urgent thing: Server Luck or a Luck Storm
--     while running, a rush that's been announced, else alternating every few seconds between the free
--     Legendary countdown (client/Gifts.lua; tap opens the gifts) and the next event,
--   * Secret Rush: the guide beam (client/ArrowPath.lua, owner "Rush") to the altar for everyone and a big
--     countdown over it,
--   * Luck Storm: the sky turns gold-violet while it lasts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIKit = require(script.Parent.UIKit)
local Fancy = require(script.Parent.Fancy)
local ArrowPath = require(script.Parent.ArrowPath)
local Rewards = require(Shared.Rewards)
local LiveOps = require(Shared.LiveOps)

local Events = {}
local player = Players.LocalPlayer
local PURPLE = Color3.fromRGB(220, 140, 255)

local function clock(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- The countdown over the rush altar.
local marker
local function rushMarker(pos)
	if marker then
		marker:Destroy()
	end
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(pos + Vector3.new(0, 16, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 130)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 3000
	gui.Parent = part
	local title = UIKit.text(gui, { Size = UDim2.fromScale(1, 0.4), Text = "SECRET RUSH", StrokeThickness = 3 })
	Fancy.rainbowText(title)
	local count = UIKit.text(gui, {
		Name = "Count",
		Position = UDim2.fromScale(0, 0.4),
		Size = UDim2.fromScale(1, 0.6),
		Text = "",
		TextColor3 = PURPLE,
		StrokeThickness = 4,
	})
	part.Parent = workspace
	marker = part
	return count
end

function Events.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EventsGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")
	local chip = Instance.new("TextButton")
	chip.AutoButtonColor = false
	chip.Text = ""
	chip.AnchorPoint = Vector2.new(0.5, 0)
	-- Under the top bar (its middle holds the BASE / HUB / MAP tabs).
	chip.Position = UDim2.new(0.5, 0, 0, 62)
	chip.Size = UDim2.fromOffset(300, 34)
	chip.BackgroundColor3 = Color3.fromRGB(30, 24, 50)
	chip.BackgroundTransparency = 0.25
	chip.Visible = false
	chip.Parent = gui
	UIKit.fitScale(chip)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = chip
	local chipText = UIKit.text(chip, {
		Style = "label",
		TextSize = 17,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = PURPLE,
	})
	local showsGift, showsEvent = false, false
	chip.Activated:Connect(function()
		if showsEvent then
			require(script.Parent.EventsPanel).open()
		elseif showsGift then
			require(script.Parent.Gifts).open()
		end
	end)

	-- The storm's sky.
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "StormTint"
	tint.TintColor = Color3.new(1, 1, 1)
	tint.Parent = Lighting
	local stormOn = false

	local count
	while true do
		local now = workspace:GetServerTimeNow()
		local stormUntil = ReplicatedStorage:GetAttribute("StormUntil") or 0
		local nextStorm = ReplicatedStorage:GetAttribute("NextStorm") or math.huge
		local nextRush = ReplicatedStorage:GetAttribute("NextRush") or math.huge
		local rushAt, rushPos = ReplicatedStorage:GetAttribute("RushAt"), ReplicatedStorage:GetAttribute("RushPos")
		-- The chip: the most urgent thing.
		local luckUntil = ReplicatedStorage:GetAttribute("ServerLuckUntil") or 0
		local text, color
		local tutorial = (player:GetAttribute("Ftue") or 99) < 99
		showsGift = false
		showsEvent = false
		if now < luckUntil then
			text, color = "SERVER LUCK x2  " .. clock(luckUntil - now), UIKit.GOLD
		elseif now < stormUntil then
			text, color = "LUCK STORM x" .. Config.Events.stormLuck .. "  " .. clock(stormUntil - now), UIKit.GOLD
		elseif rushAt then
			text, color = "SECRET RUSH IN " .. clock(rushAt - now) .. "!", PURPLE
		else
			-- Nothing live: alternate the free Legendary and the next event.
			local claimed =
				string.find("," .. (player:GetAttribute("GiftsClaimed") or "") .. ",", "," .. #Rewards.Gifts .. ",")
			local goal = Rewards.Gifts[#Rewards.Gifts].min * 60
			local played = now - (player:GetAttribute("GiftStart") or now)
			-- Three turns of 6 s: the free Legendary, the running LiveOps event, the next server event.
			local liveKey = ReplicatedStorage:GetAttribute("LiveEvent")
			local live = liveKey and LiveOps.Events[liveKey]
			local turn = math.floor(now / 6) % 3
			local giftTurn = not claimed and not tutorial and turn == 0
			if live and turn == 1 then
				showsEvent = true
				local left = (ReplicatedStorage:GetAttribute("LiveEventEnds") or now) - now
				local d = math.floor(left / 86400)
				text = string.upper(live.title)
					.. "  "
					.. (d > 0 and (d .. "D " .. math.floor(left % 86400 / 3600) .. "H") or clock(left))
				color = live.color
			elseif giftTurn then
				showsGift = true
				text = played >= goal and "FREE LEGENDARY READY!" or ("FREE LEGENDARY IN " .. clock(goal - played))
				color = UIKit.GOLD
			elseif nextStorm - now < 15 * 60 and nextStorm < nextRush then
				text, color = "LUCK STORM IN " .. clock(nextStorm - now), UIKit.GOLD
			else
				text, color = "SECRET RUSH IN " .. clock(nextRush - now), PURPLE
			end
		end
		-- (Phones have no room for it beside the stats and the next-target card: the GIFTS tile carries the
		-- gift timer and QUESTS the event.)
		-- Only while something is live: a countdown to something later is noise.
		local live = now < luckUntil or now < stormUntil or rushAt ~= nil
		chip.Visible = live and not UIKit.compact()
		chipText.Text = text
		chipText.TextColor3 = color
		-- The storm's sky.
		local storming = now < stormUntil
		if storming ~= stormOn then
			stormOn = storming
			TweenService:Create(tint, TweenInfo.new(2), {
				TintColor = storming and Color3.fromRGB(255, 225, 245) or Color3.new(1, 1, 1),
				Saturation = storming and 0.25 or 0,
			}):Play()
		end
		-- The rush: beam and countdown while announced, and a little after it drops.
		if rushPos then
			if not marker then
				count = rushMarker(rushPos)
			end
			count.Text = rushAt and tostring(math.max(0, math.ceil(rushAt - now))) or "GO GO GO!"
			ArrowPath.set("Rush", rushPos)
		elseif marker then
			marker:Destroy()
			marker = nil
			ArrowPath.set("Rush", nil)
		end
		task.wait(0.25)
	end
end

return Events
