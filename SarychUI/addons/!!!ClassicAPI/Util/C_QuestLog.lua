local GetQuestsCompleted = GetQuestsCompleted
local QueryQuestsCompleted = QueryQuestsCompleted

local C_QuestLog = C_QuestLog or {}

function C_QuestLog.IsQuestFlaggedCompleted(QuestID)
	QueryQuestsCompleted()
	return GetQuestsCompleted()[QuestID] == true
end

--[[local QueryComplete = CreateFrame("Frame")
QueryComplete:SetScript("OnEvent", function(Self)
	QueryQuestsCompleted() -- Attempt to keep up-to-date.
end)
QueryComplete:RegisterEvent("QUEST_LOG_UPDATE")]]

-- Global
_G.C_QuestLog = C_QuestLog