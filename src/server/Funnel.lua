-- Where players stop, for the Creator Dashboard (Analytics > Funnels). Each step is logged once per player, ever;
-- data.funnel and data.progress remember the last one. In Studio it prints the time from the tutorial's start.
--   Onboarding funnel: the tutorial, by Ftue step (TutorialService).
--   "Progress" funnel: first zone and its ladder, then the next zone.
--   Custom events: FirstFighterSeconds and TutorialSeconds.
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)

local Funnel = {}

local DONE = 99
local TUTORIAL = {
	[1] = { 1, "Joined" },
	[4] = { 2, "IntroDone" },
	[5] = { 3, "ReachedPad" },
	[6] = { 4, "WonFirstFighter" },
	[7] = { 5, "PlacedFighter" },
	[2] = { 6, "CollectedCash" },
	[3] = { 7, "GotFirstWeights" },
	[10] = { 8, "FinishedTraining" },
	[DONE] = { 9, "BoughtWeights" },
}
local PROGRESS = {
	"EnteredZone1",
	"Guardian1",
	"Guardian2",
	"Guardian3",
	"Guardian4",
	"Guardian5",
	"Zone1Boss",
	"EnteredZone2",
}

local function seconds(data)
	return os.time() - (data.ftueStarted or os.time())
end

local function custom(player, name, value)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value)
end

-- Call on entering tutorial step `step`.
function Funnel.tutorial(player, data, step)
	local entry = TUTORIAL[step]
	if not data or not entry or entry[1] <= data.funnel then
		return
	end
	if step == DONE and data.funnel == 0 then
		data.funnel = entry[1] -- (a save from before this existed: nothing to report)
		return
	end
	data.funnel = entry[1]
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, entry[1], entry[2])
	if step == 6 then
		custom(player, "FirstFighterSeconds", seconds(data))
	elseif step == DONE then
		custom(player, "TutorialSeconds", seconds(data))
	end
	if RunService:IsStudio() then
		print(string.format("[Funnel] %d %s at %ds", entry[1], entry[2], seconds(data)))
	end
end

-- How far the player has got: logs every step reached since last time.
function Funnel.progress(player, data)
	if not data then
		return
	end
	local zones = data.stats.zones or {}
	local stage = 0
	local first, second = Config.ZoneOrder[1], Config.ZoneOrder[2]
	if zones[first] then
		stage = 1 + (data.ladder[first] or 0)
		if data.bosses[first] then
			stage = 7
		end
		if zones[second] then
			stage = 8
		end
	end
	for step = data.progress + 1, stage do
		pcall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, player, "Progress", nil, step, PROGRESS[step])
	end
	data.progress = math.max(data.progress, stage)
end

return Funnel
