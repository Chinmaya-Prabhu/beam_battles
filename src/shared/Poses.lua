-- Display poses for the pack's R6 fighters, as joint rotations (radians) applied on top of each
-- Motor6D's rest C0. The pack's own animations belong to the original game and can't play here,
-- so every stance is set in code.
--
-- R6 joint frames: a shoulder or hip rotated about Z swings the limb forward/back; about X lifts it
-- out to the side. Left joints are mirrored, so the same motion has the opposite sign on the left.
local Poses = {}

local function r(x, y, z)
	return CFrame.Angles(x or 0, y or 0, z or 0)
end

Poses.List = {
	Stance = { -- fists up, weight forward
		["Right Shoulder"] = r(0, 0, 1.15),
		["Left Shoulder"] = r(0, 0, -0.75),
		["Right Hip"] = r(0, 0, 0.18),
		["Left Hip"] = r(0, 0, 0.12),
		["Neck"] = r(0.06, 0, 0),
	},
	Ready = { -- arms out and down, ready to spring
		["Right Shoulder"] = r(-0.35, 0, 0.35),
		["Left Shoulder"] = r(0.35, 0, -0.35),
		["Right Hip"] = r(-0.12, 0, 0),
		["Left Hip"] = r(0.12, 0, 0),
	},
	PowerUp = { -- both arms flexed out wide
		["Right Shoulder"] = r(-1.45, 0, 0),
		["Left Shoulder"] = r(1.45, 0, 0),
		["Right Hip"] = r(-0.16, 0, 0),
		["Left Hip"] = r(0.16, 0, 0),
		["Neck"] = r(-0.12, 0, 0),
	},
	Victory = { -- right fist to the sky
		["Right Shoulder"] = r(-0.2, 0, 2.9),
		["Left Shoulder"] = r(0.15, 0, -0.15),
		["Neck"] = r(-0.15, 0, 0),
	},
	Point = { -- pointing at the rival across the table
		["Right Shoulder"] = r(0, 0, 1.55),
		["Left Shoulder"] = r(0.25, 0, 0),
		["Neck"] = r(0, 0, 0),
	},
	Slump = { -- after losing a battle
		["Right Shoulder"] = r(0, 0, -0.15),
		["Left Shoulder"] = r(0, 0, 0.15),
		["Neck"] = r(0.45, 0, 0),
	},
	-- The signature poses (clips Sig* for R15, shared/Fighters.lua: Fighters.signature) for R6 fighters,
	-- which have no elbows: the arms point where the R15 hands go.
	SigGojo = { ["Right Shoulder"] = r(0.5, 0, 2.1), ["Left Shoulder"] = r(-0.45, 0, -1.4), ["Neck"] = r(0.1, 0, 0) },
	SigSukuna = {
		["Right Shoulder"] = r(0.45, 0, 1.45),
		["Left Shoulder"] = r(-0.45, 0, -1.45),
		["Neck"] = r(0.2, 0, 0),
	},
	SigJojo = {
		["Right Shoulder"] = r(0.35, 0, 2.6),
		["Left Shoulder"] = r(0.45, 0, 0.5),
		["Right Hip"] = r(0, 0, 0.25),
		["Neck"] = r(0, 0.4, 0),
	},
	SigKamehameha = { ["Right Shoulder"] = r(0.2, 0, 1.55), ["Left Shoulder"] = r(-0.2, 0, -1.55) },
	SigSeal = { ["Right Shoulder"] = r(0.5, 0, 1.9), ["Left Shoulder"] = r(-0.5, 0, -1.9) },
	SigLaugh = { ["Right Shoulder"] = r(-2.2, 0, 0.3), ["Left Shoulder"] = r(2.2, 0, -0.3), ["Neck"] = r(-0.3, 0, 0) },
	SigSmash = { ["Right Shoulder"] = r(0, 0, 1.6), ["Left Shoulder"] = r(0.2, 0, 0.6), ["Right Hip"] = r(0, 0, -0.3) },
	SigAllMight = { ["Right Shoulder"] = r(0, 0, 2.8), ["Left Shoulder"] = r(0.6, 0, 0), ["Neck"] = r(-0.15, 0, 0) },
	SigSalute = { ["Right Shoulder"] = r(0.9, 0, 1.2), ["Left Shoulder"] = r(0.1, 0, 0.2), ["Neck"] = r(-0.1, 0, 0) },
	SigBankai = { ["Right Shoulder"] = r(0, 0, 1.55), ["Left Shoulder"] = r(-0.4, 0, -1.3) },
	SigJajanken = {
		["Right Shoulder"] = r(0, 0, -0.6),
		["Left Shoulder"] = r(0, 0, -1.5),
		["Right Hip"] = r(0, 0, 0.3),
	},
	SigSword = { ["Right Shoulder"] = r(0.35, 0, 0.7), ["Left Shoulder"] = r(-0.35, 0, -0.7) },
	SigSpiritGun = { ["Right Shoulder"] = r(0, 0, 1.57), ["Left Shoulder"] = r(-0.6, 0, -1.2) },
	SigGuild = { ["Right Shoulder"] = r(0, 0, 3.0), ["Left Shoulder"] = r(0.6, 0, 0), ["Neck"] = r(-0.3, 0, 0) },
	SigFlex = { ["Right Shoulder"] = r(-1.45, 0, 0.4), ["Left Shoulder"] = r(1.45, 0, -0.4), ["Neck"] = r(-0.1, 0, 0) },
}

-- R15 poses, as Motor6D.Transform rotations. R15 joint frames line up with the body: rotating about
-- +X swings a hanging limb forward, about +Z swings it toward the body's right (+X). Elbows bend
-- with +X, knees with -X. `Root` may also carry a small offset (crouch).
Poses.R15 = {
	Stance = { -- fists up in a guard, knees bent, turned side-on
		Root = CFrame.new(0, -0.35, 0),
		Waist = r(0.08, 0.38, 0),
		Neck = r(-0.08, -0.32, 0),
		RightShoulder = r(1.25, -0.2, 0.25),
		RightElbow = r(1.75, 0, 0),
		RightWrist = r(-0.2, 0, 0),
		LeftShoulder = r(1.05, 0.3, -0.3),
		LeftElbow = r(1.8, 0, 0),
		RightHip = r(0.35, 0, 0.12),
		RightKnee = r(-0.6, 0, 0),
		RightAnkle = r(0.25, 0, 0),
		LeftHip = r(-0.15, 0, -0.14),
		LeftKnee = r(-0.35, 0, 0),
		LeftAnkle = r(0.2, 0, 0),
	},
	Ready = { -- loose ready stance, arms out from the body
		Root = CFrame.new(0, -0.2, 0),
		Waist = r(0.05, 0, 0),
		RightShoulder = r(0.25, 0, 0.35),
		RightElbow = r(0.6, 0, 0),
		LeftShoulder = r(0.25, 0, -0.35),
		LeftElbow = r(0.6, 0, 0),
		RightHip = r(0.1, 0, 0.18),
		RightKnee = r(-0.25, 0, 0),
		LeftHip = r(0.1, 0, -0.18),
		LeftKnee = r(-0.25, 0, 0),
	},
	PowerUp = { -- powering up: wide stance, fists down and out, head back
		Root = CFrame.new(0, -0.45, 0),
		Waist = r(-0.12, 0, 0),
		Neck = r(-0.3, 0, 0),
		RightShoulder = r(-0.15, 0, 0.6),
		RightElbow = r(0.5, 0, 0),
		LeftShoulder = r(-0.15, 0, -0.6),
		LeftElbow = r(0.5, 0, 0),
		RightHip = r(0.1, 0, 0.32),
		RightKnee = r(-0.45, 0, 0),
		RightAnkle = r(0.2, 0, -0.25),
		LeftHip = r(0.1, 0, -0.32),
		LeftKnee = r(-0.45, 0, 0),
		LeftAnkle = r(0.2, 0, 0.25),
	},
	Point = { -- pointing straight at you, other fist on the hip
		Waist = r(0, -0.2, 0),
		Neck = r(0, 0.15, 0),
		RightShoulder = r(1.5, 0, 0.05),
		RightElbow = r(0.05, 0, 0),
		LeftShoulder = r(0.35, 0, -0.55),
		LeftElbow = r(1.9, 0.4, 0),
		RightHip = r(0, 0, 0.1),
		LeftHip = r(0, 0, -0.1),
	},
	Victory = { -- fist to the sky
		Waist = r(-0.08, 0.1, 0),
		Neck = r(-0.25, 0, 0),
		RightShoulder = r(2.9, 0, 0.2),
		RightElbow = r(0.25, 0, 0),
		LeftShoulder = r(0.35, 0, -0.55),
		LeftElbow = r(1.9, 0.4, 0),
	},
}

-- Fighters display in one of these, chosen per fighter so a table of them doesn't look identical.
Poses.Display = { "Stance", "Ready", "PowerUp", "Point" }

function Poses.forKey(key)
	local h = 0
	for i = 1, #key do
		h = (h * 31 + string.byte(key, i)) % 1000003
	end
	return Poses.Display[h % #Poses.Display + 1]
end

return Poses
