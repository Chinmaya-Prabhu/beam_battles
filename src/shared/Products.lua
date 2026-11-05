-- Everything sold for Robux (docs/MONETIZATION.md). Create each gamepass and developer product on the
-- Creator Dashboard, then paste its id here; `price` is only shown until the real price loads from Roblox.
-- With id = 0, Studio fakes the purchase (server/Services/MonetizationService.lua) so the flow can be tested;
-- in a live game an id of 0 shows "COMING SOON".
local Products = {}

-- Gamepasses: owned forever.
Products.Passes = {
	{
		key = "VIP",
		id = 2053343838,
		price = 299,
		name = "VIP",
		desc = "+50% cash · 2x daily rewards · gold name and chat tag",
	},
	-- One pass for three (owning it counts as owning each); the saving shown is from the live prices.
	{
		key = "ProBundle",
		id = 2053697923,
		price = 449,
		name = "Pro Bundle",
		desc = "2x Cash + 2x Power + Auto Train",
		includes = { "DoubleCash", "DoublePower", "AutoTrain" },
	},
	{ key = "DoubleCash", id = 2054027925, price = 199, name = "2x Cash", desc = "Your stands earn double, forever" },
	{
		key = "DoublePower",
		id = 2053127884,
		price = 249,
		name = "2x Power",
		desc = "Every rep gives double Power and Ki",
	},
	{
		key = "AutoTrain",
		id = 2053955908,
		price = 149,
		name = "Auto Train",
		desc = "Train while you're AFK (switch it in Settings)",
	},
	{
		key = "FastSteal",
		id = 2053427856,
		price = 299,
		name = "Fast Steal",
		desc = "Grab in 0.5s and run faster carrying",
	},
	{
		key = "DropLuck",
		id = 2053511926,
		price = 249,
		name = "x2 Drop Luck",
		desc = "Drops near you roll twice as rare",
	},
	{
		key = "MutationLuck",
		id = 2053391877,
		price = 349,
		name = "2x Mutations",
		desc = "Drops near you and your summons mutate twice as often",
	},
	{
		key = "ExtraStands",
		id = 2053763861,
		price = 299,
		name = "+2 Stands",
		desc = "Two extra gold stands at your base, forever",
	},
	{
		key = "Floor2",
		id = 2053637868,
		price = 249,
		name = "Floor 2",
		desc = "A second floor at your base: 8 more stands to fill",
	},
	-- Premium weights, shown glowing on every gear stall (the impulse buy).
	{
		key = "DragonWeights",
		id = 2053565913,
		price = 599,
		name = "Eternal Dragon Weights",
		desc = "x1000 per click, or 3x your best weights, forever",
		gear = 15,
	},
	{
		key = "ChakraWeights",
		id = 2052485933,
		price = 299,
		name = "Nine-Tail Fox Weights",
		desc = "x700 per click, or 2x your best weights, forever",
		gear = 14,
	},
	-- Beam skins (shared/BeamSkins.lua): cosmetic, equipped in the shop's BEAMS tab.
	{
		key = "BeamKamehameha",
		id = 2053577894,
		price = 99,
		name = "Turtle Wave",
		desc = "A blue-white wave beam",
		beam = "Kamehameha",
	},
	{
		key = "BeamHellfire",
		id = 2052599920,
		price = 149,
		name = "Hellfire",
		desc = "A roaring beam of flame",
		beam = "Hellfire",
	},
	{
		key = "BeamChidori",
		id = 2053241976,
		price = 199,
		name = "Thousand Birds",
		desc = "Crackling lightning",
		beam = "Chidori",
	},
	{
		key = "BeamCursed",
		id = 2052611937,
		price = 199,
		name = "Cursed Energy",
		desc = "Purple and black cursed energy",
		beam = "Cursed",
	},
	{
		key = "BeamGoldenGod",
		id = 2053349901,
		price = 249,
		name = "Golden God",
		desc = "A blinding golden beam",
		beam = "GoldenGod",
	},
	{
		key = "BeamPrism",
		id = 2054117830,
		price = 399,
		name = "Prism Rainbow",
		desc = "Every colour, always shifting",
		beam = "Prism",
	},
}

-- Developer products: bought again and again.
Products.Items = {
	{
		key = "ServerLuck",
		id = 3722149105,
		price = 99,
		name = "Server Luck",
		desc = "Rarer drops for EVERYONE for 15 min",
		minutes = 15,
	},
	{
		key = "PowerBoost",
		id = 3722149139,
		price = 49,
		name = "2x Training",
		desc = "Double Power and Ki for 15 min",
		minutes = 15,
	},
	{
		key = "Shield",
		id = 3722149148,
		price = 39,
		name = "Base Shield",
		desc = "Nobody can steal from you for 10 min",
		minutes = 10,
	},
	{
		key = "CashLarge",
		id = 3722149159,
		price = 99,
		name = "Cash Vault",
		desc = "1 hour of your stands' income",
		seconds = 3600,
	},
	{ key = "StandNow", id = 3722149172, price = 49, name = "Next Stand", desc = "Unlock your next stand right now" },
	{
		key = "CashHuge",
		id = 3722149181,
		price = 249,
		name = "Treasury",
		desc = "4 hours of your stands' income",
		seconds = 14400,
	},
	-- New players only (first Products.StarterDays days, once): the cheap first purchase.
	{
		key = "StarterPack",
		id = 3722149191,
		price = 49,
		name = "Starter Pack",
		desc = "Epic fighter · Iron Weights · 2x Training 30 min · $2.5M",
		minutes = 30,
	},
	-- Fighter summons (the lucky blocks): a fighter of at least `floor` rarity beams onto you.
	{
		key = "SummonLegendary",
		id = 3722149224,
		price = 175,
		name = "Legendary Summon",
		desc = "A Legendary or better fighter",
		floor = "Legendary",
		odds = { Legendary = 85, Mythic = 13, Secret = 2 },
	},
	{
		key = "SummonMythic",
		id = 3722149239,
		price = 599,
		name = "Mythic Summon",
		desc = "A Mythic or better fighter",
		floor = "Mythic",
		odds = { Mythic = 88, Secret = 12 },
	},
	-- The Fighter Market's price tiers (shared/Market.lua): whichever fighter on display the player walked up to.
	{
		key = "MarketT1",
		id = 3722149252,
		price = 79,
		name = "Market Fighter",
		desc = "An Epic from the Fighter Market",
		market = true,
	},
	{
		key = "MarketT2",
		id = 3722149267,
		price = 199,
		name = "Market Fighter",
		desc = "A Legendary from the Fighter Market",
		market = true,
	},
	{
		key = "MarketT3",
		id = 3722149282,
		price = 649,
		name = "Market Fighter",
		desc = "A rare fighter from the Fighter Market",
		market = true,
	},
	{
		key = "MarketT4",
		id = 3722149293,
		price = 1199,
		name = "Market Fighter",
		desc = "A Mythic from the Fighter Market",
		market = true,
	},
	{
		key = "MarketT5",
		id = 3722149310,
		price = 2499,
		name = "Market Fighter",
		desc = "The Fighter Market's best",
		market = true,
	},
	{
		key = "SummonSecret",
		id = 3722149332,
		price = 2399,
		name = "Secret Summon",
		desc = "A guaranteed Secret fighter",
		floor = "Secret",
		odds = { Secret = 100 },
	},
}

-- Perk numbers.
Products.VIPCash = 1.5
Products.VIPLock = 15
Products.FastStealCarry = 4
Products.AutoTrainRate = 4 -- reps per second while auto-training
Products.MinCashPack = 10000
Products.DropLuck = 2 -- luck for drops within DropLuckRange studs of an owner
Products.MutationLuck = 2 -- mutation luck for the same drops (and the owner's summons)
Products.ExtraStands = 2
Products.DropLuckRange = 90
Products.StarterDays = 3
Products.StarterCash = 2.5e6
Products.StarterGear = 4 -- Iron Weights
Products.RevealSeconds = 8.4 -- the summon reveal (client/SummonReveal.lua) before the fighter beams down

Products.ByKey = {}
Products.ById = {}
for _, list in { Products.Passes, Products.Items } do
	for _, p in list do
		Products.ByKey[p.key] = p
		if p.id ~= 0 then
			Products.ById[p.id] = p
		end
	end
end

return Products
