local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Atmosphere = require(script.Parent.Atmosphere)
local Hub = require(script.Parent.Hub)
local DataService = require(script.Parent.Services.DataService)
local ZoneService = require(script.Parent.Services.ZoneService)
local DropService = require(script.Parent.Services.DropService)
local ClashService = require(script.Parent.Services.ClashService)
local TrainingService = require(script.Parent.Services.TrainingService)
local PlotService = require(script.Parent.Services.PlotService)
local MonetizationService = require(script.Parent.Services.MonetizationService)
local TutorialService = require(script.Parent.Services.TutorialService)
local RewardsService = require(script.Parent.Services.RewardsService)
local EventService = require(script.Parent.Services.EventService)
local LeaderboardService = require(script.Parent.Services.LeaderboardService)
local LiveOpsService = require(script.Parent.Services.LiveOpsService)
local MarketService = require(script.Parent.Services.MarketService)
local BeamShrineService = require(script.Parent.Services.BeamShrineService)
local SocialService = require(script.Parent.Services.SocialService)
local FighterRig = require(script.Parent.FighterRig)
local FighterModels = require(game:GetService("ReplicatedStorage").Shared.FighterModels)
local Fighters = require(game:GetService("ReplicatedStorage").Shared.Fighters)

Atmosphere.apply()
FighterModels.builder = FighterRig.template
if RunService:IsStudio() and workspace:GetAttribute("KitGallery") then
	-- Studio showcase of the Brick Kit instead of the game world (server/KitGallery.lua).
	require(script.Parent.KitGallery).build()
	return
end
DataService.start()
local world = Hub.build()
ZoneService.build(world, Hub) -- zone islands and their altars, before drops and clashes start
DropService.start(world)
ClashService.start(world, DropService)
ZoneService.start(ClashService, DataService, DropService)
TrainingService.start(DataService, ClashService) -- after the hub and zones have built their stations
PlotService.start(world, DataService, TrainingService)
require(script.Parent.Streaming).setup(world)
ZoneService.onSplash = PlotService.splash
MonetizationService.start(DataService, PlotService, TrainingService)
SocialService.start(DataService, MonetizationService)
RewardsService.start(DataService, PlotService, TrainingService, MonetizationService)
EventService.start(DropService)
LeaderboardService.start(world, DataService)
LiveOpsService.start(DataService, RewardsService)
MarketService.start(world, DataService)
BeamShrineService.start(world, MonetizationService)
DropService.eventFighter = LiveOpsService.eventFighter
TutorialService.start(world, {
	Data = DataService,
	Drops = DropService,
	Clash = ClashService,
	Plots = PlotService,
	Training = TrainingService,
	Shop = MonetizationService,
})

-- Build every fighter's R15 rig in the background so clients can clone any of them later.
task.spawn(function()
	local source = game:GetService("ReplicatedStorage").Assets.Fighters
	for _, fighter in Fighters.List do
		local original = source:FindFirstChild(fighter.model)
		if original then
			FighterRig.template(fighter.key, original)
		end
		task.wait()
	end
end)

if RunService:IsStudio() and workspace:GetAttribute("FighterGallery") then
	DropService.gallery()
end

print(string.format("[AnimeBeamBattle] %s ready", Config.Version))
