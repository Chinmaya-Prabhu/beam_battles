-- Codes (docs/CONTENT_CALENDAR.md): typed into the CODES window (client/Codes.lua) for free rewards, once per
-- player. Built-in codes ship with the game; new ones are added live through the LiveOps remote config
-- (`codes`, tools/liveops/push.py code ...) without republishing, and a remote code with the same name
-- overrides a built-in one. Rewards use shared/Rewards.lua's kinds, so Ki and Cash scale with the player
-- (`reps` of their training, `seconds` of their stands' income) and a code stays worth typing late game.
-- Pure data and maths (tests run it outside Roblox).
local Codes = {}

-- [CODE] = { rewards = { reward, ... }, expires = unix time (optional) }
Codes.Builtin = {
	RELEASE = {
		rewards = {
			{ kind = "cash", seconds = 600, floor = 100000 },
			{ kind = "ki", reps = 600, floor = 3000 },
		},
	},
	BEAMBATTLE = {
		rewards = { { kind = "boost", minutes = 15 } },
	},
	FIRSTFIGHTER = {
		rewards = { { kind = "fighter", rarity = "Epic" } },
	},
}

-- Upper case, letters and digits only: " release! " and "Release" are the same code.
function Codes.normalize(text)
	if type(text) ~= "string" then
		return ""
	end
	return (string.gsub(string.upper(text), "[^%w]", ""))
end

-- A remote entry from the config, checked (nil if it isn't a usable code).
local function clean(entry)
	if type(entry) ~= "table" or type(entry.rewards) ~= "table" or #entry.rewards == 0 then
		return nil
	end
	local rewards = {}
	for _, r in entry.rewards do
		if type(r) == "table" and (r.kind == "cash" or r.kind == "ki" or r.kind == "boost" or r.kind == "fighter") then
			table.insert(rewards, r)
		end
	end
	if #rewards == 0 then
		return nil
	end
	return { rewards = rewards, expires = tonumber(entry.expires) }
end

-- Whether `text` redeems now for a player who has used `used` ([CODE] = true). `remote` is the config's
-- codes table. Returns the code's entry and its normalized name, or nil and the reason to show.
function Codes.check(text, used, now, remote)
	local code = Codes.normalize(text)
	if code == "" then
		return nil, "TYPE A CODE"
	end
	local entry = remote and remote[code] and clean(remote[code]) or Codes.Builtin[code]
	if not entry then
		return nil, "THAT CODE DOESN'T EXIST"
	end
	if entry.expires and now >= entry.expires then
		return nil, "THAT CODE HAS EXPIRED"
	end
	if used and used[code] then
		return nil, "YOU ALREADY USED THAT CODE"
	end
	return entry, code
end

return Codes
