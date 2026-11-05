-- VIP in chat: a gold [VIP] tag before VIP players' names (TextChatService), for everyone to see.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local VipChat = {}

function VipChat.start()
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if player and player:GetAttribute("VIP") then
			props.PrefixText = '<font color="#FFD24A">[VIP]</font> ' .. message.PrefixText
		end
		return props
	end
end

return VipChat
