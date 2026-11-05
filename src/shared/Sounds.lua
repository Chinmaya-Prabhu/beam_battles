-- Every sound in the game, by name (client/Audio.lua plays them). All free Creator Store audio from Roblox's
-- licensed partners, usable in any experience: sound effects from ProSoundEffects and Roblox's own UI
-- library, music from APM and DistroKid. `id` is the asset; `volume` and `pitch` are the defaults
-- (`vary` = random pitch spread, so repeated hits don't sound like a machine gun of one clip).
local Sounds = {}

local function id(n)
	return "rbxassetid://" .. n
end

Sounds.SFX = {
	-- Clash.
	tap = { id = id(9117969687), volume = 0.25, vary = 0.12, alt = { id(9117969717), id(9117969878) } },
	ultCharge = { id = id(9125981170), volume = 0.6 }, -- the charged attack is ready
	ultFire = { id = id(9114314399), volume = 0.9 }, -- the charged attack fires
	clash = { id = id(9120769331), volume = 0.8 }, -- ULTIMATE CLASH: both fire at once
	beamLoop = { id = id(9125636146), volume = 0.18, loop = true }, -- under the beams while a round runs
	roundStart = { id = id(9126229255), volume = 0.7 },
	ko = { id = id(9126102254), volume = 0.9 }, -- a round's last push
	win = { id = id(9120974911), volume = 0.7 }, -- the crowd, after a win
	lose = { id = id(17208353912), volume = 0.6 },
	rage = { id = id(9120018172), volume = 0.7 }, -- a boss rages
	-- Training and progress.
	rep = { id = id(9113510797), volume = 0.12, vary = 0.15 },
	gearUp = { id = id(9117297453), volume = 0.7 },
	tierUp = { id = id(9116384485), volume = 0.8 }, -- a new aura tier
	rebirth = { id = id(9125544480), volume = 0.9 },
	-- Fighters and the base.
	dropFall = { id = id(9126229255), volume = 0.5 },
	dropLand = { id = id(9116384485), volume = 0.6 },
	secretDrop = { id = id(9120018172), volume = 0.8 },
	pickup = { id = id(17208319162), volume = 0.6 },
	place = { id = id(17208323435), volume = 0.7 },
	collect = { id = id(9113728049), volume = 0.5, vary = 0.05 },
	coins = { id = id(9113849492), volume = 0.4 },
	stolen = { id = id(17208353912), volume = 0.7 },
	-- UI.
	click = { id = id(17208396156), volume = 0.5 },
	open = { id = id(17208405682), volume = 0.4 },
	purchase = { id = id(17208380755), volume = 0.7 },
	reward = { id = id(17208361335), volume = 0.6 },
	zone = { id = id(15675043410), volume = 0.6 }, -- a zone's title card
	cheer = { id = id(9120974911), volume = 0.6 },
}

-- Music by place (the player attribute Zone), plus the clash and boss themes. `volume` is the default.
Sounds.Music = {
	Hub = { id = id(9046415502), volume = 0.35 }, -- Shori (APM, Japanese taiko: the Sky Dojo)
	Blossom = { id = id(138435199386270), volume = 0.35 }, -- Rooftop School
	Ninja = { id = id(1847644836), volume = 0.35 }, -- Ninja Fighter (APM)
	Pirate = { id = id(1835322563), volume = 0.35 }, -- Pirate King (APM)
	Walled = { id = id(93280557270748), volume = 0.3 }, -- Epic Battle Momentum
	Clash = { id = id(88274542544631), volume = 0.4 }, -- Tempest Banner (anime taiko)
	Boss = { id = id(86774375802051), volume = 0.4 }, -- BOSS FIGHT
}

return Sounds
