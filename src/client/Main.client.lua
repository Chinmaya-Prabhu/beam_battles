-- Client entry. The HUD, clash screen and panels arrive with the vertical slice's next steps.
local Ambience = require(script.Parent.Ambience)
local Fx = require(script.Parent.Fx)
local FighterAnimator = require(script.Parent.FighterAnimator)
local Clash = require(script.Parent.Clash)
local KitMotion = require(script.Parent.KitMotion)
local ZoneClient = require(script.Parent.ZoneClient)
local Training = require(script.Parent.Training)
local TrainPose = require(script.Parent.TrainPose)
local Aura = require(script.Parent.Aura)
local Champion = require(script.Parent.Champion)
local Plots = require(script.Parent.Plots)
local Shop = require(script.Parent.Shop)
local Rebirth = require(script.Parent.Rebirth)
local Tutorial = require(script.Parent.Tutorial)
local ArrowPath = require(script.Parent.ArrowPath)
local GearShop = require(script.Parent.GearShop)
local SummonReveal = require(script.Parent.SummonReveal)
local Gifts = require(script.Parent.Gifts)
local Events = require(script.Parent.Events)
local Index = require(script.Parent.Index)
local VipChat = require(script.Parent.VipChat)
local BaseBeacon = require(script.Parent.BaseBeacon)
local ClashMode = require(script.Parent.ClashMode)
local EventsPanel = require(script.Parent.EventsPanel)
local BeamShrine = require(script.Parent.BeamShrine)
local ZoneQuest = require(script.Parent.ZoneQuest)
local Bag = require(script.Parent.Bag)
local Map = require(script.Parent.Map)
local Codes = require(script.Parent.Codes)
local MainButton = require(script.Parent.MainButton)
local UpdateBoard = require(script.Parent.UpdateBoard)
local Audio = require(script.Parent.Audio)
local Social = require(script.Parent.Social)
local Settings = require(script.Parent.Settings)
local PassOffers = require(script.Parent.PassOffers)
local FighterOutline = require(script.Parent.FighterOutline)

require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MutationLook")).startClient()

-- Each system starts on its own thread, so one waiting (Fx waits for remotes) never blocks the others.
for _, system in
	{
		Ambience,
		Fx,
		FighterAnimator,
		Clash,
		KitMotion,
		ZoneClient,
		TrainPose,
		Champion,
		Plots,
		Shop,
		Rebirth,
		Tutorial,
		ArrowPath,
		GearShop,
		SummonReveal,
		Gifts,
		Events,
		Index,
		VipChat,
		BaseBeacon,
		ClashMode,
		EventsPanel,
		BeamShrine,
		ZoneQuest,
		Bag,
		Map,
		Codes,
		UpdateBoard,
		Audio,
		Social,
		Settings,
		PassOffers,
		MainButton,
		FighterOutline,
	}
do
	task.spawn(system.start)
end
-- Training: the pose module hears local clicks at once; the aura plays power-up poses through it.
Training.onRep = function()
	TrainPose.rep()
	Audio.rep()
end
task.spawn(Training.start)
task.spawn(Aura.start, TrainPose)
