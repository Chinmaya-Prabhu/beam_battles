-- Offline checks for shared/Codes.lua and LiveOps.nextUpdate (run with tests/run_rules.sh).
local Codes, LiveOps = CODES()
local now = 1793000000
assert(Codes.normalize(" release! ") == "RELEASE", "codes ignore case, spaces and symbols")
local entry, code = Codes.check("Release", {}, now, nil)
assert(entry and code == "RELEASE" and #entry.rewards == 2, "a built-in code redeems")
local none, why = Codes.check("RELEASE", { RELEASE = true }, now, nil)
assert(not none and why == "YOU ALREADY USED THAT CODE", "once per player")
assert(select(2, Codes.check("NOPE", {}, now, nil)) == "THAT CODE DOESN'T EXIST", "unknown code")
assert(select(2, Codes.check("", {}, now, nil)) == "TYPE A CODE", "empty")
local remote = {
	SPIRIT = { rewards = { { kind = "boost", minutes = 15 } }, expires = now + 60 },
	OLD = { rewards = { { kind = "boost", minutes = 15 } }, expires = now - 1 },
	BAD = { rewards = { { kind = "robux", amount = 1e9 } } },
	RELEASE = { rewards = { { kind = "fighter", rarity = "Mythic" } } },
}
assert(Codes.check("spirit", {}, now, remote), "a remote code redeems")
assert(select(2, Codes.check("OLD", {}, now, remote)) == "THAT CODE HAS EXPIRED", "expired")
assert(not Codes.check("BAD", {}, now, remote), "unknown reward kinds are refused")
assert(Codes.check("RELEASE", {}, now, remote).rewards[1].rarity == "Mythic", "remote overrides built-in")
-- The update countdown: every Saturday 17:00 UTC, unless the config names one still ahead.
local at = LiveOps.nextUpdate(now, nil)
assert(at > now and at - now <= 7 * 86400, "next update within a week")
assert(os.date("!%w %H", at) == "6 17", "a Saturday at 17:00 UTC")
assert(LiveOps.nextUpdate(at, nil) == at + 7 * 86400, "at the moment it starts, the next is a week on")
local t, title = LiveOps.nextUpdate(now, { at = now + 100, title = "SPIRIT TEMPLE" })
assert(t == now + 100 and title == "SPIRIT TEMPLE", "the config's update wins while ahead")
assert(LiveOps.nextUpdate(now, { at = now - 5, title = "OLD" }) == at, "a past config update falls back")
print("Codes: checks passed")
