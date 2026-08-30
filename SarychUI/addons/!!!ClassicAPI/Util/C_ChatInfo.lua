local _, Private = ...

local _G = _G
local pairs = pairs
local ChatTypeInfo = ChatTypeInfo
local GetNumLanguages = GetNumLanguages
local SendAddonMessage = SendAddonMessage
local GetLanguageByIndex = GetLanguageByIndex
local GetNumDisplayChannels = GetNumDisplayChannels

local C_ChatInfo = C_ChatInfo or {}
local LanguageIDList

function C_ChatInfo.CanPlayerSpeakLanguage(languageId)
	if ( not LanguageIDList ) then
		LanguageIDList = { -- https://warcraft.wiki.gg/wiki/LanguageID
			[1] = "Orcish",
			[2] = "Darnassian",
			[3] = "Taurahe",
			[6] = "Dwarvish",
			[7] = "Common",
			[8] = "Demonic",
			[9] = "Titan",
			[10] = "Thalassian",
			[11] = "Draconic",
			[12] = "Kalimag",
			[13] = "Gnomish",
			[14] = "Zandali",
			[33] = "Forsaken",
			[35] = "Draenei",
			[36] = "Zombie",
			[37] = "Gnomish Binary",
			[38] = "Goblin Binary" 
		}
	end

	local languageId = LanguageIDList[languageId]

	for i=1, GetNumLanguages() do
		if ( languageId == GetLanguageByIndex(i) ) then
			return true
		end
	end
end

function C_ChatInfo.SendAddonMessage(...)
	local _, _, Type = ...
	if ( Type ~= "PARTY" and Type ~= "RAID" and Type ~= "GUILD" and Type ~= "BATTLEGROUND" and Type ~= "WHISPER" ) then
		return
	end
	return SendAddonMessage(...)
end

function C_ChatInfo.GetColorForChatType(chatType)
	local ChatInfo = ChatTypeInfo[chatType]
	return CreateColor(ChatInfo.r, ChatInfo.g, ChatInfo.b, 1)
end

function C_ChatInfo.GetChatTypeName(typeID)
	local Index = 1
	for Name, Data in pairs(ChatTypeInfo) do
		if ( typeID == Index ) then
			return Name
		end
		Index = Index + 1
	end
end

C_ChatInfo.GetChannelRosterInfo = GetChannelRosterInfo
C_ChatInfo.GetNumActiveChannels = GetNumDisplayChannels
C_ChatInfo.IsAddonMessagePrefixRegistered = Private.True

C_ChatInfo.RegisterAddonMessagePrefix = Private.Void
C_ChatInfo.GetRegisteredAddonMessagePrefixes = Private.Void

-- INCOMPLETE
--[[
C_ChatInfo.GetChannelInfoFromIdentifier
C_ChatInfo.GetChannelRuleset
C_ChatInfo.GetChannelShortcut
C_ChatInfo.GetChatLineSenderGUID
C_ChatInfo.GetChatLineSenderName
C_ChatInfo.GetChatLineText
C_ChatInfo.GetClubStreamIDs
C_ChatInfo.GetGeneralChannelID
C_ChatInfo.GetGeneralChannelLocalID
C_ChatInfo.GetMentorChannelID
C_ChatInfo.GetNumReservedChatWindows
C_ChatInfo.IsChannelRegional
C_ChatInfo.IsChatLineCensored
C_ChatInfo.IsPartyChannelType
C_ChatInfo.IsRegionalServiceAvailable
C_ChatInfo.IsValidChatLine
C_ChatInfo.ReplaceIconAndGroupExpressions
C_ChatInfo.RequestCanLocalWhisperTarget
C_ChatInfo.ResetDefaultZoneChannels
C_ChatInfo.SwapChatChannelsByChannelIndex
C_ChatInfo.UncensorChatLine
]]

-- Global
_G.C_ChatInfo = C_ChatInfo

--[[ CHATTHROTTLELIB ]]
local CTL = _G.ChatThrottleLib
local CTL_SendAddonMessage = CTL.SendAddonMessage
CTL.version = 50 -- Force ClassicAPI CTL.
CTL.SendAddonMessage = function(...)
	local _, _, _, _, Type = ...
	if ( Type ~= "PARTY" and Type ~= "RAID" and Type ~= "GUILD" and Type ~= "BATTLEGROUND" and Type ~= "WHISPER" ) then
		return
	end
	return CTL_SendAddonMessage(...)
end