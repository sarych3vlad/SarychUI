-- 3.3.5 FrameXML overwrites only the prefix of channelList/zoneChannelList
-- when registering saved channels. Stale entries can still route messages by
-- zone ID after the native checkbox has removed the saved subscription.
-- Keep the Lua cache in sync with Blizzard; never join or save channels here.
if type(hooksecurefunc) ~= "function"
    or type(ChatFrame_RegisterForChannels) ~= "function"
    or type(ChatFrame_RemoveChannel) ~= "function"
    or type(GetChatWindowChannels) ~= "function" then
    return
end

local function TrimChannelList(list, count)
    if type(list) ~= "table" then return end
    for index in pairs(list) do
        if type(index) == "number" and index > count then
            list[index] = nil
        end
    end
end

hooksecurefunc("ChatFrame_RegisterForChannels", function(frame, ...)
    local count = math.ceil(select("#", ...) / 2)
    TrimChannelList(frame.channelList, count)
    TrimChannelList(frame.zoneChannelList, count)
end)

hooksecurefunc("ChatFrame_RemoveChannel", function(frame)
    -- Native removal has already updated saved subscriptions. Reload that
    -- exact state so alternate spellings cannot survive in the Lua cache.
    ChatFrame_RegisterForChannels(frame, GetChatWindowChannels(frame:GetID()))
end)
