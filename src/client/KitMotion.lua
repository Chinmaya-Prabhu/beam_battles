-- Small ambient motion for Brick Kit pieces, all on the client (server/BrickKit tags them):
--   Banner / Swing  sway from a Hinge (attributes Amp, Speed; Roll swings sideways too); parts or models
--   WaterStreak     slides down a waterfall (Top, Fall, Speed, Phase)
--   Spin            turns about world Y (Speed); Rotor turns a model about its own Axis (Speed)
--   Bob / Drift     floats up and down / wanders slowly sideways
--   Sway            a tree leaning a touch in the breeze
--   Streamer        carp streamer segments rippling from a Root (Index, Count, Drop, Offset, Phase)
--   Rocker          the bamboo water-knocker: slow fill, quick tip, knock back (Hinge, Period)
--   Rise            sky lantern rising and fading (Height, Period, Phase)
--   Flicker / LightPillar / Koi
-- Only things near the camera move. Whole-model motion (PivotTo) runs at 30 Hz to stay cheap.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local KitMotion = {}

local RANGE = 280
local TAGS = {
	"Banner",
	"Swing",
	"WaterStreak",
	"Spin",
	"Rotor",
	"Bob",
	"Drift",
	"Sway",
	"Streamer",
	"Rocker",
	"Rise",
	"Flicker",
	"LightPillar",
	"Koi",
}
local items = {} -- [instance] = state

local function has(inst, tag)
	return CollectionService:HasTag(inst, tag)
end

local function pivotOf(inst)
	return inst:IsA("Model") and inst:GetPivot() or inst.CFrame
end

local function setPivot(inst, cf)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	else
		inst.CFrame = cf
	end
end

local function track(inst)
	if items[inst] then
		return
	end
	local s = { phase = math.random() * 10 }
	if inst:IsA("PointLight") then
		s.base = inst.Brightness
	else
		s.start = pivotOf(inst)
		local hinge = inst:GetAttribute("Hinge")
		if hinge then
			s.rel = hinge:ToObjectSpace(s.start)
		end
		if inst:IsA("BasePart") then
			s.trans = inst.Transparency
		end
		if has(inst, "Rise") then
			s.parts = {}
			for _, p in inst:GetDescendants() do
				if p:IsA("BasePart") then
					s.parts[p] = p.Transparency
				end
			end
		end
	end
	items[inst] = s
end

local function lightPosition(light)
	local p = light.Parent
	return p and p:IsA("BasePart") and p.Position
end

local function swingAngles(inst, s, t)
	local amp = inst:GetAttribute("Amp") or 0.12
	local speed = inst:GetAttribute("Speed") or 1.7
	local a = math.sin(t * speed + s.phase) * amp + math.sin(t * speed * 1.8 + s.phase * 2) * amp * 0.3
	local roll = inst:GetAttribute("Roll") and math.sin(t * speed + s.phase) * amp or a * 0.3
	return CFrame.Angles(a, 0, roll)
end

-- The bamboo knocker's angle over one period: fill slowly, tip fast, knock back.
local function rockerAngle(t, period)
	local p = (t % period) / period
	if p < 0.82 then
		return -0.28 + p / 0.82 * 0.36
	elseif p < 0.88 then
		return 0.08 + (p - 0.82) / 0.06 * 0.5
	end
	return 0.58 - (p - 0.88) / 0.12 * 0.86
end

local function step(inst, s, t, heavy)
	if inst:IsA("PointLight") then
		inst.Brightness = s.base * (0.85 + 0.25 * math.noise(t * 6, s.phase))
		return
	end
	if has(inst, "WaterStreak") then
		local fall = math.max(inst:GetAttribute("Fall") or 1, 1)
		local speed, phase = inst:GetAttribute("Speed") or 18, inst:GetAttribute("Phase") or 0
		inst.CFrame = inst:GetAttribute("Top") * CFrame.new(0, -((t * speed + phase) % fall), 0)
		return
	end
	if has(inst, "Koi") then
		local center, r = inst:GetAttribute("Center"), inst:GetAttribute("Radius") or 2
		local a = t * 0.5 + (inst:GetAttribute("Phase") or 0)
		local pos = center * Vector3.new(math.cos(a) * r, math.sin(t * 3 + a) * 0.05, math.sin(a) * r)
		local ahead = center * Vector3.new(math.cos(a + 0.2) * r, 0, math.sin(a + 0.2) * r)
		inst.CFrame = CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z))
		return
	end
	if has(inst, "Streamer") then
		local k, n = inst:GetAttribute("Index"), inst:GetAttribute("Count")
		local phase = inst:GetAttribute("Phase") or 0
		local depth = (k + 1) / n
		local wave = t * 2.4 - k * 0.8 + phase
		local y = (inst:GetAttribute("Drop") or 0) - k * 0.18 + math.sin(wave) * 0.3 * depth
		local z = math.sin(wave * 0.8 + 1) * 0.45 * depth
		local yaw = math.cos(wave * 0.8 + 1) * 0.35 * depth
		local offset = inst:GetAttribute("Offset") or Vector3.zero
		inst.CFrame = inst:GetAttribute("Root")
			* CFrame.new(k * 1.4 + 0.7, y, z)
			* CFrame.Angles(0, yaw, math.sin(wave) * 0.15)
			* CFrame.new(offset)
		return
	end
	if has(inst, "Rocker") then
		local angle = rockerAngle(t + s.phase, inst:GetAttribute("Period") or 5)
		inst.CFrame = inst:GetAttribute("Hinge") * CFrame.Angles(angle, 0, 0) * s.rel
		return
	end
	if s.rel and (has(inst, "Banner") or has(inst, "Swing")) then
		if inst:IsA("Model") and not heavy then
			return
		end
		setPivot(inst, inst:GetAttribute("Hinge") * swingAngles(inst, s, t) * s.rel)
		return
	end
	if inst:IsA("Model") and not heavy then
		return
	end
	local cf = s.start
	if has(inst, "Rise") then
		local period = inst:GetAttribute("Period") or 30
		local p = ((t + (inst:GetAttribute("Phase") or 0)) % period) / period
		cf = cf + Vector3.new(math.sin(p * 9) * 1.5, p * (inst:GetAttribute("Height") or 60), math.cos(p * 7) * 1.5)
		local fade = math.clamp((p - 0.75) / 0.25, 0, 1) + math.clamp(1 - p / 0.05, 0, 1)
		for part, base in s.parts do
			part.Transparency = base + (1 - base) * math.min(fade, 1)
		end
	end
	if has(inst, "Sway") then
		cf = cf * CFrame.Angles(math.sin(t * 0.9 + s.phase) * 0.012, 0, math.sin(t * 0.7 + s.phase * 1.3) * 0.016)
	end
	if has(inst, "Drift") then
		cf = cf + Vector3.new(math.sin(t * 0.03 + s.phase) * 18, 0, math.cos(t * 0.02 + s.phase) * 6)
	end
	if has(inst, "Bob") then
		cf = cf + Vector3.new(0, math.sin(t * 0.8 + s.phase) * (inst:IsA("Model") and 0.8 or 0.35), 0)
	end
	if has(inst, "Spin") then
		local speed = inst:GetAttribute("Speed") or 1
		cf = CFrame.new(cf.Position) * CFrame.Angles(0, t * speed, 0) * (cf - cf.Position)
	end
	if has(inst, "Rotor") then
		local axis = inst:GetAttribute("Axis") or Vector3.xAxis
		cf = cf * CFrame.fromAxisAngle(axis, t * (inst:GetAttribute("Speed") or 1))
	end
	if has(inst, "LightPillar") and s.trans then
		-- "Base" (set by ZoneClient when a gate opens or closes) overrides the starting transparency.
		local base = inst:GetAttribute("Base") or s.trans
		inst.Transparency = base >= 1 and 1 or math.clamp(base + math.sin(t * 2 + s.phase) * 0.04, 0, 1)
	end
	if cf ~= s.start then
		setPivot(inst, cf)
	end
end

function KitMotion.start()
	for _, tag in TAGS do
		for _, inst in CollectionService:GetTagged(tag) do
			track(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
	end
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		local heavy = acc >= 1 / 30
		if heavy then
			acc = 0
		end
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local eye = cam.CFrame.Position
		local t = os.clock()
		for inst, s in items do
			if not inst.Parent then
				items[inst] = nil
				continue
			end
			local p = s.start and s.start.Position or lightPosition(inst)
			if p and (p - eye).Magnitude <= RANGE then
				step(inst, s, t, heavy)
			end
		end
	end)
end

return KitMotion
