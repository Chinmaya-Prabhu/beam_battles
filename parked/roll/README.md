# Fighter Roll (parked 2026-10-30: rolls come later)

To bring it back: `Roll.lua` -> src/shared, `RollService.lua` -> src/server/Services, `RollClient.lua` ->
src/client/Roll.lua, `roll.spec.luau` -> tests (plus its block in tests/run_rules.sh). Add the `Roll` remote to
shared/Net.lua and the AutoRoll / TripleRoll passes to shared/Products.lua; start RollService in Main.server.lua
after the tutorial (deps Data, Training, Plots, Monetization, Clash, Zone) and the client module in Main.client.lua.
Hooks it used: TrainingService.onReps, ZoneService.onGuardian (first clears), ClashService.onPrize and
PlotService.onSteal (chained), a `Rolling` attribute that quiets the bag's banners, and the bottom pop-ups lifted
above its panel (Offers.lua, the Gifts hook card, Fx.lua phone banners). Tuning: tools/sim/roll_economy.py and
tools/sim/pacing.py (tickets: start 5, drop 3, guardian 10, 200 reps 1, steal 5, fee 20% of the banner cost).
