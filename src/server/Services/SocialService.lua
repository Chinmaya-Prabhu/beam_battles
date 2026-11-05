-- Social and return hooks (Config.Social, Config.Badges; client/Social.lua draws them):
--   * the group reward: members of the game's group (Config.Social.groupId) earn +10% cash forever
--     (player attribute GroupMult, folded into CashMult by MonetizationService). Re-checked on join, every
--     few minutes and when the client says it joined (remote Tutorial "CheckGroup"),
--   * the friend boost: +10% cash and training for each friend in the same server, up to +50% (player
--     attribute FriendBoost, folded into CashMult and TrainBoost),
--   * badges: SocialService.award(player, key) gives Config.Badges[key] once (ids of 0 are skipped, so the
--     calls are safe before the badges exist). Other services call it at the moments.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local SocialService = {}
local S = Config.Social
local Shop -- MonetizationService (recomputes CashMult and TrainBoost)
local awarded = {} -- [player] = { [key] = true } this session (BadgeService is asked once per badge)

function SocialService.award(player, key)
	local id = Config.Badges[key]
	if not id or id == 0 or not player.Parent then
		return
	end
	awarded[player] = awarded[player] or {}
	if awarded[player][key] then
		return
	end
	awarded[player][key] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, id)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		end
	end)
end

local function checkGroup(player)
	if S.groupId == 0 then
		return
	end
	local ok, member = pcall(player.IsInGroup, player, S.groupId)
	local mult = (ok and member) and S.groupCash or nil
	if player:GetAttribute("GroupMult") ~= mult then
		player:SetAttribute("GroupMult", mult)
		if Shop then
			Shop.refresh(player)
		end
	end
end

-- Friends in this server, for everyone (a join or leave changes two people's boosts).
local friendCache = {} -- [a][b] = true when friends
local function friends(a, b)
	friendCache[a] = friendCache[a] or {}
	if friendCache[a][b] == nil then
		local ok, yes = pcall(a.IsFriendsWith, a, b.UserId)
		friendCache[a][b] = ok and yes or false
	end
	return friendCache[a][b]
end

local function refreshFriends()
	local list = Players:GetPlayers()
	for _, p in list do
		local n = 0
		for _, other in list do
			if other ~= p and friends(p, other) then
				n += 1
			end
		end
		local boost = n > 0 and (1 + S.friendStep * math.min(n, S.friendMax)) or nil
		if p:GetAttribute("FriendBoost") ~= boost then
			p:SetAttribute("FriendBoost", boost)
			p:SetAttribute("FriendsHere", n > 0 and n or nil)
			if Shop then
				Shop.refresh(p)
			end
		end
	end
end

function SocialService.start(DataService, MonetizationService)
	Shop = MonetizationService
	ReplicatedStorage:SetAttribute("GroupId", S.groupId ~= 0 and S.groupId or nil)
	DataService.onLoaded(function(player)
		SocialService.award(player, "Welcome")
		task.spawn(checkGroup, player)
		task.spawn(refreshFriends)
	end)
	Players.PlayerRemoving:Connect(function(player)
		awarded[player], friendCache[player] = nil, nil
		for _, cache in friendCache do
			cache[player] = nil
		end
		task.defer(refreshFriends)
	end)
	Net.get("Tutorial").OnServerEvent:Connect(function(player, kind)
		if kind == "CheckGroup" then
			task.delay(2, checkGroup, player) -- (the join takes a moment to register)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(300)
			for _, player in Players:GetPlayers() do
				task.spawn(checkGroup, player)
			end
		end
	end)
end

return SocialService
