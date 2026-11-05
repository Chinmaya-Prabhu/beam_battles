-- Bright anime daylight under a Toolbox anime sky (see shared/ZoneLighting.lua) (docs/HIT_PLAN.md §7.2). Lighting.Technology (ShadowMap, phone-safe
-- shadows) can't be set from scripts, so it lives in default.project.json.
-- Events retint the sky by tweening these values on the client.
local Lighting = game:GetService("Lighting")

local Atmosphere = {}

local function ensure(class, name)
	local item = Lighting:FindFirstChild(name)
	if not item then
		item = Instance.new(class)
		item.Name = name
		item.Parent = Lighting
	end
	return item
end

function Atmosphere.apply()
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(100, 94, 112)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 152, 165)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0

	local atmosphere = ensure("Atmosphere", "Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(215, 228, 245)
	atmosphere.Decay = Color3.fromRGB(90, 130, 210)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.4

	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.2
	bloom.Size = 20
	bloom.Threshold = 2.2

	local grade = ensure("ColorCorrectionEffect", "Grade")
	grade.Saturation = 0.2
	grade.Contrast = 0.18
	grade.Brightness = 0
	grade.TintColor = Color3.fromRGB(250, 250, 255)

	local rays = ensure("SunRaysEffect", "SunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.8

	-- "Anime Sky" from the Toolbox (asset 6799834843, by Ninja215215: a lone Sky, no scripts): its six faces.
	local sky = ensure("Sky", "Sky")
	sky.SkyboxBk = "rbxassetid://6778646360"
	sky.SkyboxDn = "rbxassetid://6778658683"
	sky.SkyboxFt = "rbxassetid://6778648039"
	sky.SkyboxLf = "rbxassetid://6778649136"
	sky.SkyboxRt = "rbxassetid://6778650519"
	sky.SkyboxUp = "rbxassetid://6778658364"
	sky.SunTextureId = "rbxassetid://6679618752"
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 0
	sky.CelestialBodiesShown = true
end

return Atmosphere
