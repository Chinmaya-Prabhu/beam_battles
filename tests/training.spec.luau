-- Offline checks for shared/Training.lua (run with tests/run_rules.sh).
local Training = TRAINING()
local function eq(a, b, msg)
	assert(a == b, msg .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
-- Gear ladder: each tier at least doubles the click rate and costs more than the last.
for i = 2, Training.LadderTop do
	local a, b = Training.Gear[i - 1], Training.Gear[i]
	assert(b.mult > a.mult, "gear " .. i .. " beats the one before")
	assert(b.cost > a.cost, "gear " .. i .. " costs more")
end
-- Stations: stronger zone by zone.
local order = { "Hub", "Blossom", "Ninja", "Pirate", "Walled" }
local last = 0
for _, zone in order do
	for _, s in Training.Stations[zone] do
		assert(s.mult > last, s.key .. " beats the station before it")
		last = s.mult
		eq(Training.StationByKey[s.key].zone, zone, s.key .. " knows its zone")
	end
end
-- Auras.
eq(Training.aura(0), 0, "no aura at zero")
eq(Training.aura(999), 0, "no aura below the first tier")
eq(Training.aura(1000), 1, "first aura")
eq(Training.aura(2e9), #Training.Auras, "top aura")
eq(Training.title(0), Training.RookieTitle, "rookie title")
local p, nextAt = Training.toNext(0)
assert(p == 0 and nextAt == 1e3, "bar starts empty toward 1K")
local p2 = Training.toNext(math.sqrt(1e3 * 1e4))
assert(math.abs(p2 - 0.5) < 1e-6, "bar is log-scaled within a tier")
eq(select(2, Training.toNext(5e9)), nil, "no next tier at the top")
-- Body: grows, capped.
local b0, b1 = Training.bodyScale(0), Training.bodyScale(1e12)
eq(b0.width, 1, "normal body at zero")
assert(math.abs(b1.width - 1.6) < 1e-9 and math.abs(b1.height - 1.15) < 1e-9, "body capped")
-- Per rep.
eq(Training.perRep(1, 1, 1, 0), 1, "bare click")
eq(Training.perRep(4, 5, 2, 2), 8 * 5 * 2 * 2, "gear x station x champion x rebirths")
-- Buying.
assert(Training.canBuyGear(1, 2, 1e3), "buy wooden weights")
assert(Training.canBuyGear(1, 3, 1e9), "stock can skip ahead")
assert(not Training.canBuyGear(3, 2, 1e9), "never downgrade")
eq(select(2, Training.canBuyGear(10, 11, 1e18, 0)), "NEEDS REBIRTH 1", "rebirth-gated weights")
assert(Training.canBuyGear(10, 11, 1e18, 1, { Walled = true }, 1e18), "rebirth 1 unlocks the turtle shell")
assert(not Training.canBuyGear(1, 2, 999), "needs the cash")
eq(select(2, Training.canBuyGear(3, 4, 1e18, 0, {})), "OPEN THE ZONE FIRST", "zone-gated weights")
assert(Training.canBuyGear(3, 4, 1e18, 0, { Blossom = true }, 10e3), "sold once Blossom is open")
eq(select(2, Training.canBuyGear(3, 4, 1e18, 0, { Blossom = true }, 0)), "NEEDS POWER", "weights need Power too")
assert(not Training.canBuyGear(13, 14, 1e18, 9), "premium gear is never bought with cash")
eq(Training.bestGear(4, 14), 14, "premium gear worn over the ladder")
eq(Training.bestGear(13, 14), 14, "premium weights are always worn")
eq(Training.gearMult(4, 14), 700, "Nine-Tails early: its own x700")
eq(Training.gearMult(13, 14), 10000, "Nine-Tails late: 2x the best Ki weight, never outgrown")
eq(Training.gearMult(13, 15), 15000, "Shenron late: 3x the best Ki weight")
eq(Training.gearMult(4, 15), 1000, "Shenron early: its own x1000")
for ladder = 1, Training.LadderTop do
	assert(
		Training.gearMult(ladder, 15) > Training.gearMult(ladder, 14),
		"Shenron (R$599) always beats Nine-Tails (R$299)"
	)
end
eq(Training.perRep(13, 1, 1, 0, 1, 14), 10000, "perRep uses the premium multiplier")
eq(Training.bestGear(4, nil), 4, "ladder gear without premium")
assert(Training.canBuyStation("AcademyPost", 2e3, 500e3, false), "buy the academy post")
eq(select(2, Training.canBuyStation("AcademyPost", 1999, 1e9, false)), "NEEDS POWER", "academy post needs power")
eq(select(2, Training.canBuyStation("AcademyPost", 1e9, 1, false)), "NOT ENOUGH CASH", "academy post needs cash")
-- Rate cap.
eq(Training.accept(100, 0.2), math.floor(Training.MaxCps * 0.2 * 1.25 + 2), "batch capped")
eq(Training.accept(3, 0.2), 3, "honest batch kept")
eq(Training.accept(-5, 1), 0, "no negative reps")
-- Champion.
eq(Training.championMult(nil), 1, "no champion")
eq(Training.championMult("Legendary"), 3, "legendary champion")
eq(Training.championMult("Secret", "Huge"), 30, "huge secret")
assert(Training.championMult("Epic", "Golden") > Training.championMult("Epic"), "mutation adds")
-- Rebirth.
eq(Training.rebirthCost(0), 12e9, "first rebirth")
eq(Training.rebirthCost(2), 300e9, "third rebirth")
eq(Training.perRep(1, 1, 1, 2), 2, "two rebirths double training")
print("Training: checks passed")
