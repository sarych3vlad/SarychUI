-- SarychUI: class-color player names when they are mentioned in chat / bubbles.
-- Logic follows ElvUI Chat + ChatBubbles, stored in the chat module profile.

local gsub, gmatch, lower, format = string.gsub, string.gmatch, string.lower, string.format
local pairs, select, type = pairs, select, type

local ClassNames = {}
local protectLinks = {}
local filterRegistered = false
local rosterFrame

local CHAT_TYPES = {
	"SAY", "YELL", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
	"GUILD", "OFFICER", "WHISPER", "WHISPER_INFORM", "CHANNEL",
	"BATTLEGROUND", "BATTLEGROUND_LEADER", "BN_WHISPER", "BN_WHISPER_INFORM",
	"EMOTE", "TEXT_EMOTE", "MONSTER_SAY", "MONSTER_YELL",
}

local function ChatDB()
	return SarychUI and SarychUI.db and SarychUI.db.profile
		and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
end

local function GetSetting(key, default)
	local db = ChatDB()
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function IsChatModuleEnabled()
	local db = ChatDB()
	return db and (db.enabled == true or db.enabled == 1)
end

local function IsMasterEnabled()
	return IsChatModuleEnabled() and GetSetting("classColorMentionsEnabled", 1) == 1
end

local function IsChatEnabled()
	return IsMasterEnabled() and GetSetting("classColorMentionsChat", 1) == 1
end

local function IsSpeechEnabled()
	return IsMasterEnabled() and GetSetting("classColorMentionsSpeech", 1) == 1
end

local function EscapePattern(text)
	return gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function RememberName(name, classFile)
	if type(name) ~= "string" or name == "" or type(classFile) ~= "string" or classFile == "" then
		return
	end
	local short = name:match("^([^-]+)") or name
	ClassNames[lower(short)] = classFile
	ClassNames[lower(name)] = classFile
end

local localizedClassToFile
local function LocalizedClassToFile(className)
	if not className or className == "" then
		return nil
	end
	if RAID_CLASS_COLORS and RAID_CLASS_COLORS[className] then
		return className
	end
	if not localizedClassToFile then
		localizedClassToFile = {}
		local function fill(tbl)
			if type(tbl) ~= "table" then
				return
			end
			for fileName, localized in pairs(tbl) do
				if type(localized) == "string" then
					localizedClassToFile[localized] = fileName
				end
			end
		end
		fill(_G.LOCALIZED_CLASS_NAMES_MALE)
		fill(_G.LOCALIZED_CLASS_NAMES_FEMALE)
	end
	return localizedClassToFile[className]
end

local function RememberFromGUID(guid)
	if not guid or guid == "" or not GetPlayerInfoByGUID then
		return
	end
	local ok, locClass, engClass, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
	if not ok or not name or name == "" then
		return
	end
	local classFile = engClass or LocalizedClassToFile(locClass)
	if realm and realm ~= "" then
		RememberName(name .. "-" .. realm, classFile)
	end
	RememberName(name, classFile)
end

local function RefreshRosterNames()
	RememberName(UnitName("player"), select(2, UnitClass("player")))

	local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
	if numRaid > 0 then
		for i = 1, numRaid do
			local name, _, _, _, _, classFile = GetRaidRosterInfo(i)
			RememberName(name, classFile)
		end
	else
		local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
		for i = 1, numParty do
			local unit = "party" .. i
			RememberName(UnitName(unit), select(2, UnitClass(unit)))
		end
	end

	if GetNumGuildMembers then
		for i = 1, (GetNumGuildMembers() or 0) do
			local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
			RememberName(name, classFile)
		end
	end

	if GetNumFriends then
		for i = 1, (GetNumFriends() or 0) do
			local name, _, className = GetFriendInfo(i)
			RememberName(name, LocalizedClassToFile(className))
		end
	end

	if GetNumWhoResults and GetWhoInfo then
		for i = 1, (GetNumWhoResults() or 0) do
			local name, _, _, _, className, _, classFile = GetWhoInfo(i)
			RememberName(name, classFile or LocalizedClassToFile(className))
		end
	end
end

local function ClassColorHex(classFile)
	local colors = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
	if not colors then
		return nil
	end
	return format("|cff%02x%02x%02x", colors.r * 255 + 0.5, colors.g * 255 + 0.5, colors.b * 255 + 0.5)
end

local function ColorizeMentions(message)
	if type(message) ~= "string" or message == "" then
		return message
	end
	if not next(ClassNames) then
		return message
	end

	for hyperLink in gmatch(message, "|%x+|H.-|h.-|h|r") do
		local tempLink = gsub(hyperLink, "%s", "|s")
		message = gsub(message, EscapePattern(hyperLink), tempLink)
		protectLinks[hyperLink] = tempLink
	end

	local rebuiltString
	local isFirstWord = true
	local protectLinksNext = next(protectLinks)

	for word in gmatch(message, "%s-%S+%s*") do
		if not protectLinksNext or not protectLinks[gsub(gsub(word, "%s", ""), "|s", " ")] then
			local tempWord = gsub(word, "^[%s%p]-([^%s%p]+)([%-]?[^%s%p]-)[%s%p]*$", "%1%2")
			local lowerCaseWord = lower(tempWord)
			local classMatch = ClassNames[lowerCaseWord]
			if classMatch then
				local hex = ClassColorHex(classMatch)
				if hex then
					word = gsub(word, gsub(tempWord, "%-", "%%-"), hex .. tempWord .. "|r")
				end
			end
		end

		if isFirstWord then
			rebuiltString = word
			isFirstWord = nil
		else
			rebuiltString = rebuiltString .. word
		end
	end

	for hyperLink, tempLink in pairs(protectLinks) do
		rebuiltString = gsub(rebuiltString or message, EscapePattern(tempLink), hyperLink)
		protectLinks[hyperLink] = nil
	end

	return rebuiltString or message
end

local function MessageFilter(frame, event, msg, author, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, ...)
	RememberFromGUID(arg12)
	if not IsChatEnabled() then
		return false, msg, author, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, ...
	end
	return false, ColorizeMentions(msg), author, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, ...
end

local function RegisterFilter()
	if filterRegistered or not ChatFrame_AddMessageEventFilter then
		return
	end
	for i = 1, #CHAT_TYPES do
		ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. CHAT_TYPES[i], MessageFilter)
	end
	filterRegistered = true
end

local function UnregisterFilter()
	if not filterRegistered or not ChatFrame_RemoveMessageEventFilter then
		return
	end
	for i = 1, #CHAT_TYPES do
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_" .. CHAT_TYPES[i], MessageFilter)
	end
	filterRegistered = false
end

local function EnsureRosterFrame()
	if rosterFrame then
		return
	end
	rosterFrame = CreateFrame("Frame")
	rosterFrame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			if GuildRoster then
				GuildRoster()
			end
		end
		RefreshRosterNames()
	end)
	rosterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	rosterFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	rosterFrame:RegisterEvent("RAID_ROSTER_UPDATE")
	rosterFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
	rosterFrame:RegisterEvent("FRIENDLIST_UPDATE")
	if rosterFrame.RegisterEvent then
		pcall(rosterFrame.RegisterEvent, rosterFrame, "WHO_LIST_UPDATE")
	end
end

local function ApplyClassMentions()
	if IsMasterEnabled() then
		EnsureRosterFrame()
		RefreshRosterNames()
		RegisterFilter()
	else
		UnregisterFilter()
	end
	local emotions = _G.SarychUI_ChatEmotions
	if emotions and emotions.ApplyBubbleSettings then
		emotions.ApplyBubbleSettings()
	elseif _G.ApplyEmotionSettings then
		_G.ApplyEmotionSettings()
	end
end

_G.SarychUI_ClassMentions = {
	ClassNames = ClassNames,
	Colorize = ColorizeMentions,
	IsMasterEnabled = IsMasterEnabled,
	IsChatEnabled = IsChatEnabled,
	IsSpeechEnabled = IsSpeechEnabled,
	ApplySettings = ApplyClassMentions,
}

_G.ApplyClassMentions = ApplyClassMentions

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	ApplyClassMentions()
end)
