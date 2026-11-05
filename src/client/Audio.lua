-- All the game's sound on the client (shared/Sounds.lua lists every clip):
--   * Audio.play(name, opts) plays a sound effect (opts.scale multiplies its volume, opts.pitch its speed;
--     clips with `vary` get a random pitch, `alt` picks one of several takes),
--   * Audio.loop(name, on) starts or stops a looping effect (the beams' hum during a round),
--   * music follows where the player is (the player attribute Zone) and crossfades; Audio.battle(kind)
--     switches to the clash or boss theme for a fight and back (nil) after,
--   * music and effects can be turned off in Settings (client/Settings.lua; player attributes MusicOff /
--     SfxOff, saved by TutorialService "Settings"),
--   * hooks the game's own moments: menu buttons, window opens, purchases, rewards, drops, collecting,
--     gear and aura tiers, rebirths, steals, carrying a fighter and placing it, and each training rep.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Sounds)
local Net = require(Shared.Net)

local Audio = {}
local player = Players.LocalPlayer
local rng = Random.new()

local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SFX"
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Parent = SoundService

local function sfxOn()
	return not player:GetAttribute("SfxOff")
end

-- Plays effect `name` once.
function Audio.play(name, opts)
	local def = Sounds.SFX[name]
	if not def or not sfxOn() then
		return
	end
	opts = opts or {}
	local s = Instance.new("Sound")
	local takes = def.alt and { def.id, table.unpack(def.alt) } or nil
	s.SoundId = takes and takes[rng:NextInteger(1, #takes)] or def.id
	s.Volume = (def.volume or 0.5) * (opts.scale or 1)
	local pitch = opts.pitch or def.pitch or 1
	if def.vary then
		pitch *= 1 + rng:NextNumber(-def.vary, def.vary)
	end
	s.PlaybackSpeed = pitch
	s.SoundGroup = sfxGroup
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(12, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Starts (on = true) or stops a looping effect.
local loops = {}
function Audio.loop(name, on)
	local def = Sounds.SFX[name]
	if not def then
		return
	end
	local s = loops[name]
	if on and sfxOn() then
		if not s then
			s = Instance.new("Sound")
			s.SoundId = def.id
			s.Looped = true
			s.Volume = def.volume or 0.3
			s.SoundGroup = sfxGroup
			s.Parent = SoundService
			loops[name] = s
		end
		if not s.IsPlaying then
			s:Play()
		end
	elseif s then
		s:Stop()
	end
end

-- ------------------------------------------------------------------ music

local tracks = {} -- [key] = Sound
local current -- the key playing now
local battle -- "Clash" | "Boss" | nil

local function track(key)
	local def = Sounds.Music[key]
	if not def then
		return nil
	end
	if not tracks[key] then
		local s = Instance.new("Sound")
		s.Name = "Music_" .. key
		s.SoundId = def.id
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = musicGroup
		s.Parent = SoundService
		tracks[key] = s
	end
	return tracks[key], def.volume or 0.35
end

local function fade(s, to, seconds)
	TweenService:Create(s, TweenInfo.new(seconds or 1.5), { Volume = to }):Play()
end

local function refreshMusic()
	local want = battle or player:GetAttribute("Zone") or "Hub"
	if not Sounds.Music[want] then
		want = "Hub"
	end
	if player:GetAttribute("MusicOff") then
		want = nil
	end
	if want == current then
		return
	end
	if current and tracks[current] then
		local old = tracks[current]
		fade(old, 0, 1.2)
		task.delay(1.3, function()
			if old ~= tracks[current] then
				old:Pause()
			end
		end)
	end
	current = want
	if want then
		local s, volume = track(want)
		if s then
			if battle == want then
				s.TimePosition = 0 -- a fight's theme starts from the top
			end
			if not s.IsPlaying then
				s:Resume()
				if not s.IsPlaying then
					s:Play()
				end
			end
			fade(s, volume, battle == want and 0.6 or 2)
		end
	end
end

-- The fight's theme ("Clash" or "Boss"), or nil to go back to the place's music.
function Audio.battle(kind)
	battle = kind
	refreshMusic()
end

-- ------------------------------------------------------------------ hooks

local hooked = setmetatable({}, { __mode = "k" })
local function hookButton(b)
	if hooked[b] or not b:IsA("GuiButton") then
		return
	end
	hooked[b] = true
	b.Activated:Connect(function()
		Audio.play("click")
	end)
end

local function hookWindow(w)
	w:GetPropertyChangedSignal("Visible"):Connect(function()
		if w.Visible then
			Audio.play("open")
		end
	end)
end

function Audio.start()
	-- Every menu tile and pill clicks (UIKit buttons carry a UIScale from their bounce).
	local gui = player:WaitForChild("PlayerGui")
	local function scan(inst)
		if inst:IsA("GuiButton") and inst:FindFirstChildOfClass("UIScale") and inst.Name ~= "Close" then
			hookButton(inst)
		end
	end
	for _, d in gui:GetDescendants() do
		scan(d)
	end
	gui.DescendantAdded:Connect(function(d)
		task.defer(scan, d)
	end)
	for _, w in CollectionService:GetTagged("UIWindow") do
		hookWindow(w)
	end
	CollectionService:GetInstanceAddedSignal("UIWindow"):Connect(hookWindow)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, _, bought)
		if who == player and bought then
			Audio.play("purchase")
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, bought)
		if userId == player.UserId and bought then
			Audio.play("purchase")
		end
	end)
	-- The game's moments, from its FX remote.
	Net.get("FX").OnClientEvent:Connect(function(kind, data)
		data = type(data) == "table" and data or {}
		if kind == "Reward" then
			Audio.play("reward")
		elseif kind == "Collect" then
			Audio.play("collect")
			Audio.play("coins", { scale = 0.8 })
		elseif kind == "Drop" then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local near = root and data.position and (root.Position - data.position).Magnitude < 120
			if data.rarity == "Secret" then
				Audio.play("secretDrop")
			elseif near then
				Audio.play("dropFall", { scale = 0.8 })
				task.delay(1, Audio.play, "dropLand", { scale = 0.7 })
			end
		elseif kind == "GearUp" and data.userId == player.UserId then
			Audio.play("gearUp")
		elseif kind == "PowerUp" and data.userId == player.UserId then
			Audio.play("tierUp")
		elseif kind == "Rebirth" and data.userId == player.UserId then
			Audio.play("rebirth")
			task.delay(1.2, Audio.play, "cheer")
		elseif kind == "Stolen" and data.victim == player.UserId then
			Audio.play("stolen")
		elseif kind == "Party" and data.position then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - data.position).Magnitude < 150 then
				Audio.play("cheer")
				Audio.play("roundStart", { scale = 0.6 })
			end
		elseif kind == "StandUnlocked" then
			Audio.play("purchase")
			task.delay(0.25, Audio.play, "coins")
		end
	end)
	-- Carrying a fighter: lifted, then put down.
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		Audio.play(player:GetAttribute("Carrying") and "pickup" or "place")
	end)
	-- Zone title cards and music.
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		if player:GetAttribute("Zone") and player:GetAttribute("Zone") ~= "Hub" then
			Audio.play("zone")
		end
		refreshMusic()
	end)
	for _, name in { "MusicOff", "SfxOff" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refreshMusic()
			if player:GetAttribute("SfxOff") then
				for _, s in loops do
					s:Stop()
				end
			end
		end)
	end
	task.delay(2, refreshMusic)
end

-- One training rep (client/Training.lua calls this through Main).
function Audio.rep()
	Audio.play("rep")
end

return Audio
