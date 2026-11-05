-- Lighting presets per place (docs/WORLD_PLAN.md §9.7). The client blends to the preset of the zone the
-- player is in (client/ZoneClient.lua); the server applies the hub preset at start (server/Atmosphere.lua).
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local ZoneLighting = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- A slightly softer sun and ambient than before so shadows read, and a little more contrast. The world's
-- colours themselves are muted in shared/Bricks.lua, so the fighters and their auras stand out.
ZoneLighting.Presets = {
	-- Bright anime daytime under the anime sky (server/Atmosphere.lua): a strong sun, clear blue air.
	Hub = {
		lighting = {
			ClockTime = 14,
			Brightness = 3,
			ExposureCompensation = 0,
			OutdoorAmbient = rgb(150, 152, 165),
		},
		atmosphere = { Density = 0.22, Haze = 0.4, Color = rgb(215, 228, 245), Decay = rgb(90, 130, 210) },
		grade = { Saturation = 0.2, Contrast = 0.18, TintColor = rgb(250, 250, 255) },
	},
	-- Clear school morning: cool air, crisp shadows.
	Blossom = {
		lighting = {
			ClockTime = 10.5,
			Brightness = 3,
			ExposureCompensation = 0,
			OutdoorAmbient = rgb(146, 152, 170),
		},
		atmosphere = { Density = 0.2, Haze = 0.3, Color = rgb(205, 222, 245), Decay = rgb(110, 146, 210) },
		grade = { Saturation = 0.22, Contrast = 0.18, TintColor = rgb(248, 250, 255) },
	},
	-- Warm late afternoon (still daylight), orange air.
	Ninja = {
		lighting = {
			ClockTime = 15.8,
			Brightness = 2.7,
			ExposureCompensation = 0,
			OutdoorAmbient = rgb(150, 132, 140),
		},
		atmosphere = { Density = 0.22, Haze = 0.35, Color = rgb(250, 200, 160), Decay = rgb(110, 100, 170) }, -- (clearer air: the valley reads clean)
		grade = { Saturation = 0.2, Contrast = 0.18, TintColor = rgb(255, 240, 225) },
	},
	-- Tropical noon: clear air, deep blues.
	Pirate = {
		lighting = {
			ClockTime = 12.8,
			Brightness = 3.2,
			ExposureCompensation = -0.05,
			OutdoorAmbient = rgb(150, 160, 170),
		},
		atmosphere = { Density = 0.16, Haze = 0.3, Color = rgb(190, 220, 245), Decay = rgb(90, 160, 220) },
		grade = { Saturation = 0.26, Contrast = 0.16, TintColor = rgb(250, 252, 255) },
	},
	-- Grey overcast: heavy haze, low saturation, hard contrast (darker on purpose: the titans' city).
	Walled = {
		lighting = {
			ClockTime = 14.5,
			Brightness = 2.2,
			ExposureCompensation = 0,
			OutdoorAmbient = rgb(136, 138, 148),
		},
		atmosphere = { Density = 0.32, Haze = 1.4, Color = rgb(190, 194, 206), Decay = rgb(100, 108, 124) },
		grade = { Saturation = -0.02, Contrast = 0.2, TintColor = rgb(236, 240, 246) },
	},
}

-- Blend Lighting, Atmosphere and the ColorCorrection named "Grade" to a preset over `time` seconds.
function ZoneLighting.apply(name, time)
	local preset = ZoneLighting.Presets[name] or ZoneLighting.Presets.Hub
	local info = TweenInfo.new(time or 2, Enum.EasingStyle.Sine)
	local function blend(inst, props)
		if inst and props then
			if (time or 0) <= 0 then
				for k, v in props do
					inst[k] = v
				end
			else
				TweenService:Create(inst, info, props):Play()
			end
		end
	end
	blend(Lighting, preset.lighting)
	blend(Lighting:FindFirstChildOfClass("Atmosphere"), preset.atmosphere)
	blend(Lighting:FindFirstChild("Grade"), preset.grade)
end

return ZoneLighting
