-- Shared UI pieces drawn from the art atlases (shared/UIAtlas.lua), each with a plain fallback so the UI still
-- works before the art is live:
--   UIKit.text      a label. Give it Style = "title" | "heading" | "number" | "label" | "body" | "small" for the
--                   type system below (fixed size per role); without a Style it scales to fit its box (capped)
--   UIKit.fitScale  a UIScale on a HUD block so it keeps its size relative to the screen
--   UIKit.tile      a square menu button (icon on a gold or blue tile, label underneath)
--   UIKit.pill      a wide pill button (gold / green / red / grey) with a label
--   UIKit.window    a modal window (white body, sky-blue header with the title, a close button)
--   UIKit.menu()    the HUD's menu columns (game, and "free" rewards); modules add tiles in LayoutOrder
--   UIKit.dot       a red notification dot on a tile
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIAtlas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UIAtlas"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UIKit = {}
UIKit.INK = Color3.fromRGB(31, 42, 68)
UIKit.GOLD = Color3.fromRGB(255, 205, 60)
UIKit.GREEN = Color3.fromRGB(90, 220, 120)
UIKit.SKY = Color3.fromRGB(110, 200, 255)
local INK = UIKit.INK

local FALLBACK = {
	pill_gold = Color3.fromRGB(255, 196, 40),
	pill_green = Color3.fromRGB(80, 200, 110),
	pill_red = Color3.fromRGB(240, 90, 80),
	pill_grey = Color3.fromRGB(170, 175, 190),
	tile_gold = Color3.fromRGB(255, 250, 240),
	tile_blue = Color3.fromRGB(200, 235, 255),
	window = Color3.fromRGB(255, 255, 255),
	card = Color3.fromRGB(255, 246, 224),
}

-- The type system: every piece of text has one role, and each role one font, size and outline. Display
-- text (LuckiestGuy) for titles and numbers; a plain rounded bold font in normal case for anything you read.
-- Sizes are in points at the 1080p reference (HUD blocks and windows scale as a whole).
UIKit.TYPE = {
	display = { font = Enum.Font.LuckiestGuy, size = 46, stroke = 4 },
	title = { font = Enum.Font.LuckiestGuy, size = 30, stroke = 3 },
	heading = { font = Enum.Font.LuckiestGuy, size = 20, stroke = 2 },
	number = { font = Enum.Font.LuckiestGuy, size = 26, stroke = 2.5 },
	label = { font = Enum.Font.FredokaOne, size = 18, stroke = 1.5 },
	body = { font = Enum.Font.GothamBold, size = 16, stroke = 0, wrap = true },
	small = { font = Enum.Font.GothamBold, size = 14, stroke = 0 },
}

function UIKit.text(parent, props)
	props = props or {}
	local style = props.Style and UIKit.TYPE[props.Style]
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = style and style.font or Enum.Font.LuckiestGuy
	t.TextColor3 = Color3.new(1, 1, 1)
	if style then
		t.TextScaled = false
		t.TextSize = style.size
		t.TextWrapped = style.wrap == true
		t.TextTruncate = style.wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
		if style.stroke == 0 then
			t.TextColor3 = Color3.fromRGB(235, 233, 250) -- body text sits on the dark windows
		end
	else
		t.TextScaled = true
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 34
		cap.MinTextSize = 9
		cap.Parent = t
	end
	for k, v in props do
		if k ~= "StrokeThickness" and k ~= "Style" then -- ours, not TextLabel properties
			t[k] = v
		end
	end
	-- One-line styles never cut text off with "...": a line too long for its box shrinks to fit (down to 60%
	-- of its size), which matters most on phones where boxes are narrow. (Set TextScaled = false after for a
	-- label that sizes itself to its text.)
	if style and not style.wrap and props.TextScaled == nil then
		t.TextScaled = true
		t.TextTruncate = Enum.TextTruncate.None
		local cap = Instance.new("UITextSizeConstraint")
		local function caps()
			cap.MaxTextSize = math.max(1, math.floor(t.TextSize))
			cap.MinTextSize = math.max(1, math.min(cap.MaxTextSize, math.max(9, math.floor(t.TextSize * 0.6))))
		end
		caps()
		t:GetPropertyChangedSignal("TextSize"):Connect(caps)
		cap.Parent = t
	end
	local thickness = props.StrokeThickness or (style and style.stroke) or 2.5
	if thickness > 0 then
		local s = Instance.new("UIStroke")
		s.Thickness = thickness
		s.Color = INK
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Parent = t
	end
	t.Parent = parent
	return t
end

-- Keeps a HUD block the same size relative to the screen. HUD blocks are laid out in "design" units: on
-- desktop 1 unit = 1 px of a 720 px tall window (from 0.75 on short windows up to 1.35 on big screens); on
-- phones the layout is drawn for a 360 point tall screen.
function UIKit.hudScale()
	local view = workspace.CurrentCamera.ViewportSize
	if UIKit.compact() then
		return math.clamp(view.Y / 360, 0.85, 1.3)
	end
	return math.clamp(view.Y / 720, 0.75, 1.35)
end

function UIKit.fitScale(frame, phoneFactor)
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	local function fit()
		-- (phoneFactor: how much smaller this block is on a phone; kept across screen changes)
		scale.Scale = UIKit.hudScale() * ((UIKit.compact() and phoneFactor) or 1)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	return scale
end

-- Paints `image` with a frame from the atlas, or a rounded fallback colour.
function UIKit.skin(image, frameName, sliceScale)
	if frameName == "card" then
		-- Cards on the dark windows are a plain lighter row (the card art is a light panel).
		image.Image = ""
		image.BackgroundTransparency = 0
		image.BackgroundColor3 = UIKit.ROW
		if not image:FindFirstChildOfClass("UICorner") then
			Instance.new("UICorner", image).CornerRadius = UDim.new(0, 12)
		end
		return
	end
	if not UIAtlas.frame(image, frameName, sliceScale) then
		image.Image = ""
		image.BackgroundTransparency = 0
		image.BackgroundColor3 = FALLBACK[frameName] or Color3.new(1, 1, 1)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = image
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = INK
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = image
	end
end

-- A little squash on press.
local function bounce(button)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.9 }):Play()
	end)
	local function up()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(up)
	button.MouseLeave:Connect(up)
end

-- A menu tile: just the big icon with its label printed over the bottom of it (no panel behind), so it reads at
-- a glance. Returns the button and its label.
function UIKit.tile(parent, iconName, label, props)
	local b = Instance.new("ImageButton")
	b.Name = label
	b.Size = UDim2.fromOffset(84, 84)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.42)
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Parent = b
	if not UIAtlas.icon(icon, iconName) then
		icon:Destroy()
	end
	local text = UIKit.text(b, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -6, 0.3, 0),
		Text = label,
		ZIndex = 3,
		StrokeThickness = 2.5,
	})
	text:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 22
	for k, v in props or {} do
		b[k] = v
	end
	bounce(b)
	b.Parent = parent
	return b, text
end

-- A pill button with a label. `color` is gold, green, red or grey.
function UIKit.pill(parent, color, label, props)
	local b = Instance.new("ImageButton")
	b.Name = label
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(160, 50)
	UIKit.skin(b, "pill_" .. color, 0.4)
	local text = UIKit.text(b, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.82, 0.62),
		Text = label,
		ZIndex = 3,
	})
	for k, v in props or {} do
		b[k] = v
	end
	text.ZIndex = b.ZIndex + 1 -- the label always sits on its button, whatever layer the button is on
	bounce(b)
	b.Parent = parent
	return b, text
end

-- Re-colours a pill made by UIKit.pill.
function UIKit.setPill(button, color)
	UIKit.skin(button, "pill_" .. color, 0.4)
end

-- Phones (and other short screens, landscape height under 560): the HUD packs tighter (UIKit.menu, client
-- Training) and windows draw a little larger so their text stays easy to read.
-- Decided once (the first time it's asked): the whole HUD is built for one layout, so it must never flip
-- halfway (a touch device that gets a key press reports keyboard as its preferred input afterwards).
local compactLayout
function UIKit.compact()
	if compactLayout == nil then
		-- (The shorter side: a phone that starts in portrait and turns to landscape while the game loads reports a
		-- tall screen first, and would otherwise get the desktop layout for the whole session.)
		local view = workspace.CurrentCamera.ViewportSize
		compactLayout = UIKit.touch() and math.min(view.X, view.Y) < 560
	end
	return compactLayout
end

-- Window colours: the body, rows on it, and each window's header by its title.
UIKit.PANEL = Color3.fromRGB(26, 22, 44)
UIKit.ROW = Color3.fromRGB(44, 38, 72)
UIKit.SOFT = Color3.fromRGB(190, 188, 215) -- secondary text on dark
local HEADERS = {
	SHOP = Color3.fromRGB(255, 170, 30),
	BAG = Color3.fromRGB(70, 140, 255),
	INDEX = Color3.fromRGB(70, 140, 255),
	GIFTS = Color3.fromRGB(80, 200, 100),
	DAILY = Color3.fromRGB(240, 70, 70),
	QUESTS = Color3.fromRGB(255, 140, 40),
	CODES = Color3.fromRGB(170, 90, 255),
	MAP = Color3.fromRGB(40, 190, 200),
	SETTINGS = Color3.fromRGB(120, 125, 150),
	REBIRTH = Color3.fromRGB(255, 120, 40),
	GEAR = Color3.fromRGB(255, 140, 40),
	FOLLOWER = Color3.fromRGB(70, 140, 255),
	WELCOME = Color3.fromRGB(80, 200, 100),
	UNLOCKED = Color3.fromRGB(255, 120, 40),
	CLEARED = Color3.fromRGB(255, 120, 40),
}
function UIKit.headerColor(title)
	for word, color in HEADERS do
		if string.find(string.upper(title), word, 1, true) then
			return color
		end
	end
	return Color3.fromRGB(240, 90, 160) -- (zones and the rest)
end

-- A modal window centred on screen: white body, sky-blue header with the title, a close button top-right.
-- Returns the window and its body (put content there; laid out for the design `size`). Windows never shrink
-- their text to fit a short screen: they keep their size (a little larger on phones, smaller only when the
-- screen is too narrow) and, when too tall for the screen, the body scrolls. UIKit.resizeWindow changes the
-- design size later.
-- opts.scrolls = false: the content scrolls by itself (a list or grid in its own ScrollingFrame), so the
-- body just fits the window and never scrolls too (scroll-inside-scroll is miserable on a touch screen).
function UIKit.window(parent, title, size, opts)
	local ownScroll = opts and opts.scrolls == false
	local w = Instance.new("ImageLabel")
	w.Name = title
	w.AnchorPoint = Vector2.new(0.5, 0.5)
	w.Position = UDim2.fromScale(0.5, 0.52)
	w.Size = UDim2.fromOffset(size.X, size.Y)
	w.BackgroundTransparency = 1
	w.Visible = false
	game:GetService("CollectionService"):AddTag(w, "UIWindow") -- UIKit.closeAll hides it
	-- Drawn, not art: a dark body (bright pictures and white words read best on it, as in the big simulator
	-- games) under a bold coloured header with the title, and a big red X.
	w.Image = ""
	w.BackgroundTransparency = 0
	w.BackgroundColor3 = UIKit.PANEL
	Instance.new("UICorner", w).CornerRadius = UDim.new(0, 18)
	local rim = Instance.new("UIStroke")
	rim.Thickness = 5
	rim.Color = Color3.fromRGB(12, 8, 22)
	rim.Parent = w
	local headColor = (opts and opts.color) or UIKit.headerColor(title)
	local band = Instance.new("Frame")
	band.Name = "Header"
	band.Size = UDim2.new(1, 0, 0, UIKit.compact() and 50 or 66)
	band.BackgroundColor3 = headColor
	band.ZIndex = 2
	Instance.new("UICorner", band).CornerRadius = UDim.new(0, 18)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 190))
	shade.Parent = band
	band.Parent = w
	local squareOff = Instance.new("Frame") -- (square the header's lower corners)
	squareOff.Position = UDim2.new(0, 0, 1, -18)
	squareOff.Size = UDim2.new(1, 0, 0, 18)
	squareOff.BackgroundColor3 = headColor
	squareOff.BorderSizePixel = 0
	squareOff.ZIndex = 2
	local shade2 = shade:Clone()
	shade2.Color = ColorSequence.new(Color3.fromRGB(190, 190, 202), Color3.fromRGB(175, 175, 190))
	shade2.Parent = squareOff
	squareOff.Parent = band
	w.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = w
	-- (the body starts under the header band; phones use a slimmer band so more of the window is content)
	local header = UIKit.compact() and 62 or 80
	local body -- (made below)
	local function fit()
		local view = workspace.CurrentCamera.ViewportSize
		local design = w:GetAttribute("DesignSize") or size
		-- Below Roblox's top bar, as tall as the room there allows; whatever doesn't fit scrolls.
		local top = math.max(game:GetService("GuiService").TopbarInset.Height, 36) + 6
		local room = view.Y - top - 8
		local k = math.min(1, (view.X - 24) / design.X)
		if UIKit.compact() then
			-- Phones: shrink a window until all of it fits the short screen (never below 0.72: the text must stay
			-- easy to read, so a very tall window still scrolls a little).
			k = math.min(k, math.max(0.72, room / (design.Y - (80 - header))))
		end
		scale.Scale = k
		local tall = math.min(design.Y - (80 - header), math.floor(room / k))
		w.Size = UDim2.fromOffset(design.X, tall)
		-- A ScreenGui that keeps Roblox's top inset starts below it: take that off, or the window sits too low and
		-- runs off the bottom of a phone.
		local gui = w:FindFirstAncestorWhichIsA("ScreenGui")
		local inset = (gui and not gui.IgnoreGuiInset) and game:GetService("GuiService"):GetGuiInset().Y or 0
		w.Position = UDim2.fromOffset(view.X / 2, top - inset + room / 2)
		if body then
			body.CanvasSize = ownScroll and UDim2.fromScale(0, 0) or UDim2.fromOffset(0, design.Y - 80 - 22)
			body.ScrollingEnabled = not ownScroll
		end
	end
	w:SetAttribute("DesignSize", size)
	w:GetAttributeChangedSignal("DesignSize"):Connect(fit)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	UIKit.text(w, {
		Style = "title",
		TextSize = 34,
		Name = "Title",
		Position = UDim2.fromOffset(22, UIKit.compact() and 4 or 10),
		Size = UDim2.new(1, -100, 0, 46),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		StrokeThickness = 3.5,
	})
	local close = Instance.new("ImageButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 12, 0, -12)
	close.Size = UDim2.fromOffset(60, 60)
	close.BackgroundTransparency = 1
	close.ZIndex = 4
	if not UIAtlas.icon(close, "close") then
		close.BackgroundTransparency = 0
		close.BackgroundColor3 = Color3.fromRGB(240, 90, 80)
		Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)
	end
	close.Parent = w
	bounce(close)
	close.Activated:Connect(function()
		w.Visible = false
	end)
	body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(22, header)
	body.Size = UDim2.new(1, -44, 1, -header - 22)
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.ScrollBarThickness = 10 -- (thick and dark enough to say "there's more below")
	body.ScrollBarImageColor3 = Color3.fromRGB(60, 100, 190)
	body.VerticalScrollBarInset = Enum.ScrollBarInset.None
	body.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	body.Parent = w
	if not ownScroll then
		-- A strip on the right for the scrollbar, so it never draws over the content.
		local pad = Instance.new("UIPadding")
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = body
	end
	fit()
	-- Pop in when shown; one window at a time, so opening this one closes the rest.
	w:GetPropertyChangedSignal("Visible"):Connect(function()
		if w.Visible then
			for _, other in game:GetService("CollectionService"):GetTagged("UIWindow") do
				if other ~= w then
					other.Visible = false
				end
			end
			body.CanvasPosition = Vector2.zero
			fit()
			local base = scale.Scale
			scale.Scale = base * 0.85
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = base }):Play()
		end
	end)
	return w, body
end

-- The HUD's menu: two columns of tiles on the left, added by the modules that own them.
--   UIKit.menu()       the game column: BASE, SHOP, BAG, REBIRTH, MAP, INDEX,
--   UIKit.menu("free") the free-rewards column beside it: GIFTS (with its countdown), DAILY, QUESTS, CODES.
local menuGui
local menus = {}
function UIKit.menu(column)
	column = column or "game"
	if menus[column] and menus[column].Parent then
		return menus[column]
	end
	local player = Players.LocalPlayer
	if not (menuGui and menuGui.Parent) then
		menuGui = Instance.new("ScreenGui")
		menuGui.Name = "MenuGui"
		menuGui.ResetOnSpawn = false
		menuGui.IgnoreGuiInset = true
		menuGui.DisplayOrder = 4
		menuGui.Parent = player:WaitForChild("PlayerGui")
		-- Hidden mid-clash (the clash's own buttons sit there).
		player:GetAttributeChangedSignal("InClash"):Connect(function()
			menuGui.Enabled = not player:GetAttribute("InClash")
		end)
	end
	local menu = Instance.new("Frame")
	menu.Name = column == "game" and "Menu" or "FreeMenu"
	menu.BackgroundTransparency = 1
	local compact = UIKit.compact()
	-- Desktop: the game menu (SHOP, BAG, INDEX, REBIRTH) is one column of big tiles down the left, the free
	-- menu (GIFTS, DAILY, QUESTS, CODES) one down the right, both centred in the space between the top and
	-- the cash block (client/Training.lua). Phones: each is one row of four under the stats (left) and the
	-- next-target card (right), clear of the thumbstick and the jump button.
	local cell = compact and 54 or 84
	local gap = compact and 8 or 14
	local four = cell * 4 + gap * 3
	if compact then
		-- Phones: each side is two rows of square tiles (SHOP, BAG / INDEX, REBIRTH on the left; GIFTS, DAILY /
		-- QUESTS on the right), under the stats and the next-target badge, clear of the thumbstick and jump button.
		menu.Size = UDim2.fromOffset(cell * 2 + 8, 2 * (cell + 8))
	else
		menu.Size = UDim2.fromOffset(cell + 16, four + 18)
	end
	if compact then
		menu.AnchorPoint = column == "game" and Vector2.new(0, 0) or Vector2.new(1, 0)
		menu.Position = column == "game" and UDim2.fromOffset(16, 126) or UDim2.new(1, -16, 0, 144) -- (right: under the NEXT card / badge and its count)
	else
		menu.AnchorPoint = column == "game" and Vector2.new(0, 0.5) or Vector2.new(1, 0.5)
		menu.Position = column == "game" and UDim2.new(0, 16, 0.45, 0) or UDim2.new(1, -16, 0.55, 0)
	end
	menu.Parent = menuGui
	UIKit.fitScale(menu)
	local rows
	if compact then
		-- Two rows: the first two tiles, then the rest centred under them (tiles are sorted into them below).
		local stack = Instance.new("UIListLayout")
		stack.FillDirection = Enum.FillDirection.Vertical
		stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
		stack.Padding = UDim.new(0, 0)
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = menu
		rows = {}
		for i = 1, 2 do
			local r = Instance.new("Frame")
			r.Name = "Row" .. i
			r.LayoutOrder = i
			r.BackgroundTransparency = 1
			r.Size = UDim2.fromOffset(cell * 2 + 8, cell + 8)
			local l = Instance.new("UIListLayout")
			l.FillDirection = Enum.FillDirection.Horizontal
			l.HorizontalAlignment = Enum.HorizontalAlignment.Center
			l.Padding = UDim.new(0, 8)
			l.SortOrder = Enum.SortOrder.LayoutOrder
			l.Parent = r
			r.Parent = menu
			rows[i] = r
		end
	else
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = column == "free" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		list.Padding = UDim.new(0, gap)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = menu
	end
	-- Every tile in this menu is the same size.
	menu.ChildAdded:Connect(function(t)
		if t:IsA("GuiButton") then
			t.Size = UDim2.fromOffset(cell, cell)
			if rows then
				task.defer(function()
					t.Parent = t.LayoutOrder <= 2 and rows[1] or rows[2] -- (SHOP, BAG / INDEX; GIFTS, DAILY / QUESTS)
				end)
			end
		end
	end)
	-- Tiles marked AfterTutorial (MAP, REBIRTH, DAILY, QUESTS, CODES) wait for the tutorial to end, so a new
	-- player starts with five (BASE, SHOP, BAG, INDEX, GIFTS). A player who has spent long in the tutorial
	-- without finishing it gets them anyway (server TutorialService: player attribute MenuOpen), so nobody is
	-- ever stuck without CODES or the MAP. After the tutorial they arrive one at a time rather than all at once
	-- (OpenAfter: minutes after the tutorial ended, player attribute FtueDoneAt; OpenWhen: a player attribute
	-- that must be set, e.g. Boss_Blossom for REBIRTH), each popping in, so a new kid isn't hit by every button
	-- in the same second and gets a small "something new!" every few minutes.
	local built = os.clock()
	local function tutorialTiles()
		local learning = (player:GetAttribute("Ftue") or 99) < 99 and not player:GetAttribute("MenuOpen")
		local doneAt = player:GetAttribute("FtueDoneAt") -- (old saves: none, so everything is open)
		local since = doneAt and (os.time() - doneAt) / 60 or math.huge
		for _, t in menu:GetDescendants() do
			if t:IsA("GuiObject") and t:GetAttribute("AfterTutorial") then
				local when = t:GetAttribute("OpenWhen")
				local show = not learning
					and t:GetAttribute("Hidden") ~= true
					and since >= (t:GetAttribute("OpenAfter") or 0)
					and (when == nil or player:GetAttribute(when) ~= nil and player:GetAttribute(when) ~= false)
				if show and not t.Visible and os.clock() - built > 3 then
					UIKit.popIn(t)
				end
				t.Visible = show
			end
		end
	end
	player:GetAttributeChangedSignal("Ftue"):Connect(tutorialTiles)
	player:GetAttributeChangedSignal("MenuOpen"):Connect(tutorialTiles)
	player:GetAttributeChangedSignal("FtueDoneAt"):Connect(tutorialTiles)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Boss_" then
			tutorialTiles()
		end
	end)
	task.spawn(function()
		while menu.Parent do
			task.wait(5)
			tutorialTiles()
		end
	end)
	menu.DescendantAdded:Connect(function()
		task.defer(tutorialTiles)
	end)
	menus[column] = menu
	return menu
end

-- Two bars at a slant, for marks the game font has no glyph for (and no emoji, ever).
local function bar(parent, x, y, length, thickness, angle, color)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.new(length, 0, 0, thickness)
	f.Rotation = angle
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = parent.ZIndex + 1
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	f.Parent = parent
	return f
end

-- A chevron pointing down (set .Rotation = -90 to point right), drawn from two bars.
function UIKit.chevron(parent, size, color)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(size, size)
	f.Parent = parent
	local t = math.max(2, math.floor(size / 5))
	bar(f, 0.33, 0.5, 0.55, t, 45, color or Color3.new(1, 1, 1))
	bar(f, 0.67, 0.5, 0.55, t, -45, color or Color3.new(1, 1, 1))
	return f
end

-- A tick, drawn from two bars.
function UIKit.tick(parent, size, color)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(size, size)
	f.Parent = parent
	local t = math.max(2, math.floor(size / 5))
	bar(f, 0.32, 0.6, 0.38, t, 45, color or Color3.new(1, 1, 1))
	bar(f, 0.6, 0.45, 0.7, t, -55, color or Color3.new(1, 1, 1))
	return f
end

-- The travel tabs in the middle of Roblox's top bar: BASE, HUB, MAP (big words, one tap each).
-- UIKit.tab(label, icon, color, order) adds one; returns the button.
local tabsBar
local tabsDrop -- (phones: the MAP pill's drop-down card)

-- Phones: ONE red "MAP" pill in the middle of the top bar; tapping it drops a small card with the travel tabs
-- (BASE, MAP). Cleaner than a row of pills; while a fighter is carried, the main button says HOME
-- (client/MainButton.lua).
local function compactTab(label, iconName, color, order)
	local player = Players.LocalPlayer
	if not (tabsBar and tabsBar.Parent) then
		local gui = Instance.new("ScreenGui")
		gui.Name = "TabsGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 10 -- (above the NEXT card, so the open drop-down is never under it)
		gui.Parent = player:WaitForChild("PlayerGui")
		tabsBar = Instance.new("Frame")
		tabsBar.Name = "Tabs"
		tabsBar.AnchorPoint = Vector2.new(0.5, 0.5)
		tabsBar.Size = UDim2.fromOffset(150, 46)
		tabsBar.BackgroundTransparency = 1
		tabsBar.Parent = gui
		local tabsScale = Instance.new("UIScale")
		tabsScale.Parent = tabsBar
		local function fitTabs()
			tabsScale.Scale = UIKit.hudScale() * 0.9
		end
		fitTabs()
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitTabs)
		local GuiService = game:GetService("GuiService")
		local function place()
			local inset = GuiService.TopbarInset
			local view = workspace.CurrentCamera.ViewportSize
			local x = (inset.Min.X + inset.Max.X - 56) / 2
			if inset.Max.X <= inset.Min.X then
				x = view.X / 2
			end
			local half = 75 * tabsScale.Scale
			local lo, hi = 285 + half, view.X - 112 - half
			x = hi >= lo and math.clamp(x, lo, hi) or view.X / 2
			tabsBar.Position = UDim2.fromOffset(x, inset.Min.Y + math.max(inset.Height, 44) / 2)
		end
		place()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
		tabsScale:GetPropertyChangedSignal("Scale"):Connect(place)
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
		-- The head: MAP with a chevron.
		local head = UIKit.pill(tabsBar, "red", "MAP", {
			Name = "Head",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(150, 46),
		})
		local headText = head:FindFirstChildOfClass("TextLabel")
		headText.Position = UDim2.new(0.5, 4, 0.47, 0)
		headText.Size = UDim2.new(1, -92, 0.62, 0)
		UIAtlas.label(head, "walled", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.47, 0),
			Size = UDim2.fromOffset(38, 38),
			ZIndex = head.ZIndex + 1,
		})
		local arrow = UIKit.chevron(head, 20)
		arrow.AnchorPoint = Vector2.new(1, 0.5)
		arrow.Position = UDim2.new(1, -12, 0.47, 0)
		arrow.ZIndex = head.ZIndex + 1
		for _, stroke in arrow:GetChildren() do
			stroke.ZIndex = head.ZIndex + 2
		end
		-- The drop-down card.
		tabsDrop = Instance.new("Frame")
		tabsDrop.Name = "Drop"
		tabsDrop.AnchorPoint = Vector2.new(0.5, 0)
		tabsDrop.Position = UDim2.new(0.5, 0, 1, 8)
		tabsDrop.Size = UDim2.fromOffset(150, 0)
		tabsDrop.AutomaticSize = Enum.AutomaticSize.Y
		tabsDrop.BackgroundColor3 = Color3.fromRGB(20, 18, 40)
		tabsDrop.BackgroundTransparency = 0.05
		tabsDrop.Visible = false
		tabsDrop.ZIndex = 5
		Instance.new("UICorner", tabsDrop).CornerRadius = UDim.new(0, 16)
		local dropEdge = Instance.new("UIStroke")
		dropEdge.Thickness = 2.5
		dropEdge.Color = Color3.fromRGB(90, 80, 140)
		dropEdge.Parent = tabsDrop
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		pad.Parent = tabsDrop
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = tabsDrop
		tabsDrop.Parent = tabsBar
		head.Activated:Connect(function()
			tabsDrop.Visible = not tabsDrop.Visible
		end)
		local function tutorial()
			local learning = (player:GetAttribute("Ftue") or 99) < 99 and not player:GetAttribute("MenuOpen")
			for _, t in tabsDrop:GetChildren() do
				if t:IsA("GuiObject") and t:GetAttribute("AfterTutorial") then
					t.Visible = not learning
				end
			end
		end
		player:GetAttributeChangedSignal("Ftue"):Connect(tutorial)
		player:GetAttributeChangedSignal("MenuOpen"):Connect(tutorial)
		tabsDrop.ChildAdded:Connect(function()
			task.defer(tutorial)
		end)
		-- Any window opening closes the card.
		game:GetService("CollectionService"):GetInstanceAddedSignal("UIWindow"):Connect(function(w)
			w:GetPropertyChangedSignal("Visible"):Connect(function()
				tabsDrop.Visible = false
			end)
		end)
		for _, w in game:GetService("CollectionService"):GetTagged("UIWindow") do
			w:GetPropertyChangedSignal("Visible"):Connect(function()
				tabsDrop.Visible = false
			end)
		end
	end
	local row, text = UIKit.pill(tabsDrop, color, label, { Size = UDim2.fromOffset(128, 42), LayoutOrder = order, ZIndex = 6 })
	text.Position = UDim2.new(0.5, 14, 0.47, 0)
	text.Size = UDim2.new(1, -54, 0.62, 0)
	UIAtlas.label(row, iconName, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.47, 0),
		Size = UDim2.fromOffset(34, 34),
		ZIndex = row.ZIndex + 1,
	})
	row.Activated:Connect(function()
		tabsDrop.Visible = false
	end)
	return row
end

function UIKit.tab(label, iconName, color, order)
	if UIKit.compact() then
		return compactTab(label, iconName, color, order)
	end
	local player = Players.LocalPlayer
	if not (tabsBar and tabsBar.Parent) then
		local gui = Instance.new("ScreenGui")
		gui.Name = "TabsGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 4
		gui.Parent = player:WaitForChild("PlayerGui")
		tabsBar = Instance.new("Frame")
		tabsBar.Name = "Tabs"
		tabsBar.AnchorPoint = Vector2.new(0.5, 0.5)
		tabsBar.Size = UDim2.fromOffset(2 * 128 + (UIKit.compact() and 22 or 18), 46)
		local tabsScale -- (phones: a little smaller, the top bar is crowded there)
		tabsBar.BackgroundTransparency = 1
		tabsBar.Parent = gui
		tabsScale = Instance.new("UIScale")
		tabsScale.Parent = tabsBar
		local function fitTabs()
			tabsScale.Scale = UIKit.hudScale() * (UIKit.compact() and 0.85 or 1)
		end
		fitTabs()
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitTabs)
		local GuiService = game:GetService("GuiService")
		-- Centred in the top bar's free space (TopbarInset: right of Roblox's buttons, left of the gear).
		local function place()
			local inset = GuiService.TopbarInset
			local x = (inset.Min.X + inset.Max.X - 56) / 2
			if inset.Max.X <= inset.Min.X then
				x = workspace.CurrentCamera.ViewportSize.X / 2
			end
			-- Always on screen, right of Roblox's buttons and left of the gear (a phone's inset can be off).
			local view = workspace.CurrentCamera.ViewportSize
			local half = tabsBar.Size.X.Offset * tabsScale.Scale / 2
			local lo, hi = 285 + half, view.X - 112 - half
			if hi >= lo then
				x = math.clamp(x, lo, hi)
			else
				x = view.X / 2
			end
			tabsBar.Position = UDim2.fromOffset(x, inset.Min.Y + math.max(inset.Height, 44) / 2)
		end
		place()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
		tabsBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, UIKit.compact() and 22 or 18)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = tabsBar
		local function tutorial()
			local learning = (player:GetAttribute("Ftue") or 99) < 99 and not player:GetAttribute("MenuOpen")
			for _, t in tabsBar:GetChildren() do
				if t:IsA("GuiObject") and t:GetAttribute("AfterTutorial") then
					t.Visible = not learning
				end
			end
		end
		player:GetAttributeChangedSignal("Ftue"):Connect(tutorial)
		player:GetAttributeChangedSignal("MenuOpen"):Connect(tutorial)
		tabsBar.ChildAdded:Connect(function()
			task.defer(tutorial)
		end)
	end
	local b, text = UIKit.pill(tabsBar, color, label, { Size = UDim2.fromOffset(128, 46), LayoutOrder = order })
	text.Position = UDim2.new(0.5, 14, 0.47, 0)
	text.Size = UDim2.new(1, -54, 0.62, 0)
	UIAtlas.label(b, iconName, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.47, 0),
		Size = UDim2.fromOffset(38, 38),
		ZIndex = b.ZIndex + 1,
	})
	return b
end

-- A just-unlocked tile pops in.
function UIKit.popIn(tile)
	local scale = tile:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.3
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- A red notification dot on a tile's corner (returns it; set .Visible). `text` puts a count in it.
function UIKit.dot(tile)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -6, 0, 6)
	dot.Size = UDim2.fromOffset(20, 20)
	dot.BackgroundColor3 = Color3.fromRGB(240, 60, 60)
	dot.ZIndex = 5
	dot.Visible = false
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	local ring = Instance.new("UIStroke")
	ring.Thickness = 2
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = dot
	UIKit.text(
		dot,
		{ Name = "Count", Size = UDim2.fromScale(1, 1), Text = "", TextSize = 13, ZIndex = 6, StrokeThickness = 0 }
	)
	dot.Parent = tile
	return dot
end

-- Changes a window's design size (its content's layout size) after it was made.
function UIKit.resizeWindow(w, size)
	w:SetAttribute("DesignSize", size)
end

-- Pop-ups (offers, the gifts hook) take turns: claimPopup() is true when none is showing and marks one as
-- showing until releasePopup().
local popupBusy = false
function UIKit.claimPopup()
	if popupBusy then
		return false
	end
	popupBusy = true
	return true
end
function UIKit.releasePopup()
	popupBusy = false
end

-- A full-screen moment (a rebirth, a reveal) asks pop-ups that open by themselves to wait `seconds`.
local heldUntil = 0
function UIKit.holdPopups(seconds)
	heldUntil = math.max(heldUntil, os.clock() + seconds)
end
-- Words for the player's device: on a touch screen without a keyboard, "CLICK" reads "TAP".
function UIKit.touch()
	local UIS = game:GetService("UserInputService")
	local ok, preferred = pcall(function()
		return UIS.PreferredInput
	end)
	if ok and preferred == Enum.PreferredInput.Touch then
		return true
	end
	-- (A phone can still report another preferred input while it loads, and UIKit.compact() decides the whole
	-- HUD layout once, so also trust the hardware: a touch screen with no keyboard and no mouse is a phone.)
	return UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled
end

function UIKit.device(text)
	if text and UIKit.touch() then
		return (string.gsub(text, "CLICK", "TAP"))
	end
	return text
end

-- Whether the fight owns the screen: in a clash (server attribute InClash) or still on its result screen
-- (client attribute ClashScreen, set by client/Clash.lua until the result closes).
-- A mutation's name as a RichText tag in its own colour (Config.Mutations[m].color), with a trailing space;
-- "" for Normal. The label it goes in needs RichText = true.
function UIKit.mutationTag(mutation)
	local m = mutation and mutation ~= "Normal" and Config.Mutations[mutation]
	if not m then
		return ""
	end
	return string.format('<font color="#%s">%s</font> ', m.color:ToHex(), string.upper(mutation))
end

function UIKit.inFight()
	local p = Players.LocalPlayer
	return p:GetAttribute("InClash") ~= nil or p:GetAttribute("ClashScreen") == true
end

-- Whether the loading screen (ReplicatedFirst.Loading) is done, or there is none.
-- Opens Roblox's purchase window for gamepass `key` (id `id`). The game's creator already owns every pass on
-- Roblox (the window would only say "already own"), so for them the server turns it on for the session instead.
function UIKit.promptPass(key, id)
	local player = Players.LocalPlayer
	if player.UserId == game.CreatorId then
		require(game:GetService("ReplicatedStorage").Shared.Net).get("Shop"):FireServer("OwnerPass", key)
	elseif id and id ~= 0 then
		game:GetService("MarketplaceService"):PromptGamePassPurchase(player, id)
	end
end

function UIKit.loaded()
	return Players.LocalPlayer:GetAttribute("Loaded") == true
		or not game:GetService("ReplicatedFirst"):FindFirstChild("Loading")
end

function UIKit.popupsHeld()
	-- (and while the loading screen is up)
	return os.clock() < heldUntil or not UIKit.loaded()
end

-- Hides every open window (before a full-screen moment like the summon reveal).
function UIKit.closeAll()
	for _, w in game:GetService("CollectionService"):GetTagged("UIWindow") do
		w.Visible = false
	end
end

return UIKit
