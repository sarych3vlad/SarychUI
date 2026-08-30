-- SarychUI Chat Emotions (ElvUI-style replacement + picker)
local DEBUG_EMOJIS = false
local DEBUG_EMOJI_BUBBLES = false
local DEBUG_EMOJI_BUBBLES_PERF = false

local find, gmatch, gsub, format, strsub, strlen = string.find, string.gmatch, string.gsub, string.format, string.sub, string.len
local wipe, tinsert = wipe, table.insert
local pairs, ipairs = pairs, ipairs
local GetTime = GetTime

local MEDIA_PATH = "Interface\\AddOns\\SarychUI\\media\\chat_emojis\\"
local TEXTURE_SIZE = ":16:16"

local Smileys = {}
local PickerEntries = {}
local emotionFilterRegistered = false
local emotionIconsCacheActive = false
local emotionButtons = {}
local pickerFrame = nil
local pickerOpen = false
local pickerOpenedByTrigger = false
local emojiTriggerEditing = false
local activeEmojiTrigger = {
	editBox = nil,
	startPos = nil,
	endPos = nil,
	text = nil,
}
local SyncEmotionButtonAppearance -- forward decl

local CHAT_TYPES = {
	"SAY", "YELL", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
	"GUILD", "OFFICER", "WHISPER", "WHISPER_INFORM", "CHANNEL",
	"BATTLEGROUND", "BATTLEGROUND_LEADER", "BN_WHISPER", "BN_WHISPER_INFORM",
	"EMOTE", "AFK", "DND",
}

local function DebugLog(...)
	if DEBUG_EMOJIS then
		print((SarychUI and SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("Emojis") or "|cffffd200SarychUI Emojis:|r"), ...)
	end
end

local function sarChat_GetSetting(key, default)
	local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function IsChatModuleEnabled()
	local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
	return db and (db.enabled == true or db.enabled == 1)
end

local function IsEmotionIconsEnabled()
	return IsChatModuleEnabled() and sarChat_GetSetting("emotionIcons", 1) == 1
end

local function RefreshEmotionIconsCache()
	emotionIconsCacheActive = IsEmotionIconsEnabled()
end

-- Bubbles are a strict subset of the emoji feature: replacing text inside them
-- requires polling WorldFrame, since chat bubbles are unnamed frames with no events.
local function IsEmotionBubblesEnabled()
	return IsEmotionIconsEnabled() and sarChat_GetSetting("emotionBubbles", 0) == 1
end

local function IsEmotionPickerEnabled()
	return IsChatModuleEnabled() and sarChat_GetSetting("emotionPickerEnabled", 0) == 1
end

local function IsEmotionPickerTriggerEnabled()
	return IsChatModuleEnabled() and sarChat_GetSetting("emotionPickerTriggerEnabled", 1) == 1
end

local function GetEmotionPickerTrigger()
	local trigger = sarChat_GetSetting("emotionPickerTrigger", "//")
	if not trigger or trigger == "" then
		return "//"
	end
	return trigger
end

local PROTECTED_SLASH_COMMANDS = {
	["/run"] = true,
	["/script"] = true,
	["/dump"] = true,
}

local function IsSlashCommandProtected(text)
	if not text or text == "" then
		return false
	end
	local cmd = text:match("^(/%S+)")
	return cmd and PROTECTED_SLASH_COMMANDS[cmd] or false
end

local function EscapeString(str)
	return gsub(str, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function NormalizeTextureFile(textureFile)
	if not textureFile then return textureFile end
	if textureFile:sub(-4):lower() == ".blp" then
		textureFile = textureFile:sub(1, -5) .. ".tga"
	end
	return gsub(textureFile, "/", "\\")
end

local function AddSmiley(key, textureFile)
	if not key or type(key) ~= "string" then
		return
	end
	if not textureFile then
		return
	end
	textureFile = NormalizeTextureFile(textureFile)
	Smileys[key] = format("|T%s%s%s|t", MEDIA_PATH, textureFile, TEXTURE_SIZE)
	if DEBUG_EMOJIS then
		DebugLog("AddSmiley", key, "->", MEDIA_PATH .. textureFile)
	end
end

local function RemoveSmiley(key)
	if key and type(key) == "string" then
		Smileys[key] = nil
	end
end

local function InsertEmotions(msg)
	for word in gmatch(msg, "%s-(%S+)%s*") do
		local emoji = Smileys[word]
		if emoji then
			local pattern = format("%s%s%s", "([%s%p]-)", EscapeString(word), "([%s%p]*)")
			if find(msg, pattern) then
				msg = gsub(msg, pattern, format("%s%s%s", "%1", emoji, "%2"))
			end
		end
	end
	return msg
end

local function GetSmileyReplacementText(msg)
	if not msg or not emotionIconsCacheActive then
		return msg
	end
	if find(msg, "/run") or find(msg, "/dump") or find(msg, "/script") then
		return msg
	end

	local origlen = strlen(msg)
	local startpos = 1
	local outstr = ""
	local pos, endpos

	while startpos <= origlen do
		pos = find(msg, "|H", startpos, true)
		endpos = pos or origlen
		outstr = outstr .. InsertEmotions(strsub(msg, startpos, endpos))
		startpos = endpos + 1

		if pos then
			_, endpos = find(msg, "|h.-|h", startpos)
			endpos = endpos or origlen
			if startpos < endpos then
				outstr = outstr .. strsub(msg, startpos, endpos)
				startpos = endpos + 1
			end
		end
	end

	return outstr
end

local function GetSmileyPlainText(msg)
	if not msg then return msg end
	for code, textureTag in pairs(Smileys) do
		msg = gsub(msg, EscapeString(textureTag), code)
	end
	msg = gsub(msg, "|T.-|t", "")
	msg = gsub(msg, "|A.-|a", "")
	return msg
end

local function emotionMessageFilter(self, event, msg, ...)
	local newMsg = GetSmileyReplacementText(msg)
	return false, newMsg, ...
end

local function RegisterEmotionFilter()
	if emotionFilterRegistered then return end
	for _, chatType in ipairs(CHAT_TYPES) do
		ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. chatType, emotionMessageFilter)
	end
	emotionFilterRegistered = true
	DebugLog("Emotion filter registered for", #CHAT_TYPES, "chat types")
end

local function UnregisterEmotionFilter()
	if not emotionFilterRegistered then return end
	for _, chatType in ipairs(CHAT_TYPES) do
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_" .. chatType, emotionMessageFilter)
	end
	emotionFilterRegistered = false
end

local function RegisterPickerEntry(key, textureFile)
	for _, entry in ipairs(PickerEntries) do
		if entry.key == key then
			return
		end
	end
	tinsert(PickerEntries, { key = key, texture = textureFile })
end

local function DefaultSmileys()
	if next(Smileys) then
		wipe(Smileys)
	end
	wipe(PickerEntries)
	if pickerFrame then
		pickerFrame:Hide()
		pickerFrame = nil
	end

	local data = _G.SarychUI_MemePackV2Data
	if not data then
		DebugLog("Meme Pack v2 data missing")
		return
	end

	local pickerSeen = {}
	local blpCount = 0

	local function registerPicker(key, file)
		if key and not pickerSeen[key] then
			RegisterPickerEntry(key, file)
			pickerSeen[key] = true
		end
	end

	for _, group in ipairs(data.classic or {}) do
		if group.picker then
			registerPicker(group.picker, group.file)
		end
	end

	for _, entry in ipairs(data.memes or {}) do
		AddSmiley(entry.code, entry.file)
		blpCount = blpCount + 1
		registerPicker(entry.code, entry.file)
		if DEBUG_EMOJIS then
			DebugLog("registered", entry.code, "->", entry.file)
		end
	end

	for _, group in ipairs(data.classic or {}) do
		for _, key in ipairs(group.keys or {}) do
			AddSmiley(key, group.file)
		end
	end

	local count = 0
	for _ in pairs(Smileys) do
		count = count + 1
	end
	DebugLog("Meme Pack v2 loaded:", blpCount, "blp,", count, "codes,", #PickerEntries, "picker entries")
end

local PICKER_BUTTON_TEXTURE = MEDIA_PATH .. "emoticons.dxt5.blp"
local PICKER_BUTTON_TEXCOORD = { 0, 1, 0, 1 }

local function IsTriggerInsideUrlScheme(text, startPos)
	if not startPos or startPos <= 1 then
		return false
	end
	-- Ignore :// in http://, https://, ftp://, etc.
	return strsub(text, startPos - 1, startPos - 1) == ":"
end

local function FindLastValidTriggerPosition(text, trigger)
	local lastStart, lastEndPos
	local searchFrom = 1
	while true do
		local startPos, endPos = find(text, trigger, searchFrom, true)
		if not startPos then
			break
		end
		if not IsTriggerInsideUrlScheme(text, startPos) then
			lastStart, lastEndPos = startPos, endPos
		end
		searchFrom = endPos + 1
	end
	return lastStart, lastEndPos
end

local function ClearActiveEmojiTrigger()
	activeEmojiTrigger.editBox = nil
	activeEmojiTrigger.startPos = nil
	activeEmojiTrigger.endPos = nil
	activeEmojiTrigger.text = nil
	pickerOpenedByTrigger = false
end

local function CloseTriggerPicker()
	if pickerFrame and pickerFrame:IsShown() then
		pickerFrame:Hide()
	end
	ClearActiveEmojiTrigger()
end

local function ClearTriggerPickerOnEditBoxClose(editBox)
	if pickerOpenedByTrigger and activeEmojiTrigger.editBox == editBox then
		CloseTriggerPicker()
	end
end

local function InsertSmileyIntoEditBox(text)
	local editBox = activeEmojiTrigger.editBox
		or (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend())
		or _G["ChatFrame1EditBox"]
	if not editBox then
		DebugLog("No edit box available for insert")
		return
	end

	if ChatEdit_ActivateChat then
		ChatEdit_ActivateChat(editBox)
	else
		editBox:Show()
	end

	local current = editBox:GetText() or ""
	local startPos = activeEmojiTrigger.startPos
	local endPos = activeEmojiTrigger.endPos
	local triggerText = activeEmojiTrigger.text

	if startPos and endPos and triggerText and activeEmojiTrigger.editBox == editBox then
		local slice = strsub(current, startPos, endPos)
		if slice ~= triggerText then
			startPos, endPos = FindLastValidTriggerPosition(current, triggerText)
		end
	elseif pickerOpenedByTrigger then
		triggerText = GetEmotionPickerTrigger()
		startPos, endPos = FindLastValidTriggerPosition(current, triggerText)
	end

	if startPos and endPos then
		local before = strsub(current, 1, startPos - 1)
		local after = strsub(current, endPos + 1)
		local newText = before .. text .. after
		local cursorPos = strlen(before) + strlen(text)

		emojiTriggerEditing = true
		editBox:SetText(newText)
		emojiTriggerEditing = false

		if editBox.SetCursorPosition then
			editBox:SetCursorPosition(cursorPos)
		end
	else
		if editBox.Insert then
			editBox:Insert(text)
		else
			editBox:SetText(current .. text)
		end
	end

	ClearActiveEmojiTrigger()
	editBox:SetFocus()
	DebugLog("Inserted smiley code:", text)
end

local PICKER_COLS = 8
local PICKER_BTN_SIZE = 24
local PICKER_PADDING = 4
local PICKER_FRAME_WIDTH = 280
local PICKER_FRAME_HEIGHT = 240

local function BuildPickerFrame()
	if pickerFrame then return pickerFrame end

	local frame = CreateFrame("Frame", "SarychUI_EmotionPicker", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetSize(PICKER_FRAME_WIDTH, PICKER_FRAME_HEIGHT)
	frame:Hide()
	frame:EnableMouse(true)
	tinsert(UISpecialFrames, "SarychUI_EmotionPicker")

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0, 0, 0, 0.85)

	local border = CreateFrame("Frame", nil, frame)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})

	local scroll = CreateFrame("ScrollFrame", "SarychUI_EmotionPickerScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -30, 8)

	local content = CreateFrame("Frame", nil, scroll)
	local rows = math.max(1, math.ceil(#PickerEntries / PICKER_COLS))
	local contentHeight = PICKER_PADDING * 2 + rows * (PICKER_BTN_SIZE + 2)
	content:SetSize(PICKER_FRAME_WIDTH - 40, contentHeight)
	scroll:SetScrollChild(content)

	for index, entry in ipairs(PickerEntries) do
		local row = math.floor((index - 1) / PICKER_COLS)
		local col = (index - 1) % PICKER_COLS
		local btn = CreateFrame("Button", nil, content)
		btn:SetSize(PICKER_BTN_SIZE, PICKER_BTN_SIZE)
		btn:SetPoint("TOPLEFT", content, "TOPLEFT", PICKER_PADDING + col * (PICKER_BTN_SIZE + 2), -PICKER_PADDING - row * (PICKER_BTN_SIZE + 2))

		local tex = btn:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		tex:SetTexture(MEDIA_PATH .. NormalizeTextureFile(entry.texture))

		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(entry.key, 1, 1, 1)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		btn:SetScript("OnClick", function()
			InsertSmileyIntoEditBox(entry.key)
			frame:Hide()
			pickerOpen = false
			SyncEmotionButtonAppearance()
		end)
	end

	frame:SetScript("OnHide", function()
		pickerOpen = false
		if pickerOpenedByTrigger then
			ClearActiveEmojiTrigger()
		end
		SyncEmotionButtonAppearance()
	end)

	pickerFrame = frame
	return frame
end

local function RepositionPickerNearFrame(anchorFrame)
	local frame = BuildPickerFrame()
	frame:ClearAllPoints()
	if anchorFrame then
		frame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 4)
	else
		frame:SetPoint("BOTTOMLEFT", ChatFrame1EditBox or UIParent, "TOPLEFT", 0, 4)
	end
end

local function OpenPickerNearFrame(anchorFrame, fromTrigger)
	local frame = BuildPickerFrame()
	local wasShown = frame:IsShown()

	RepositionPickerNearFrame(anchorFrame)

	if not wasShown then
		frame:Show()
		pickerOpen = true
		DebugLog("Picker opened")
	end

	if fromTrigger then
		pickerOpenedByTrigger = true
	end

	SyncEmotionButtonAppearance()
end

local function TogglePicker(anchorButton)
	local frame = BuildPickerFrame()
	if frame:IsShown() then
		frame:Hide()
		pickerOpen = false
		SyncEmotionButtonAppearance()
		return
	end

	OpenPickerNearFrame(anchorButton, false)
end

local function HandleEmotionPickerTrigger(editBox)
	if emojiTriggerEditing or not IsEmotionPickerTriggerEnabled() or not editBox then
		return
	end

	local text = editBox:GetText() or ""

	if IsSlashCommandProtected(text) then
		if pickerOpenedByTrigger and activeEmojiTrigger.editBox == editBox then
			CloseTriggerPicker()
		end
		return
	end

	local trigger = GetEmotionPickerTrigger()
	local startPos, endPos = FindLastValidTriggerPosition(text, trigger)

	if startPos then
		activeEmojiTrigger.editBox = editBox
		activeEmojiTrigger.startPos = startPos
		activeEmojiTrigger.endPos = endPos
		activeEmojiTrigger.text = trigger
		OpenPickerNearFrame(editBox, true)
		return
	end

	if pickerOpenedByTrigger and activeEmojiTrigger.editBox == editBox then
		CloseTriggerPicker()
	end
end

local function HookEmotionPickerTrigger(editBox)
	if not editBox or editBox._sarychEmotionTriggerHooked then
		return
	end
	editBox._sarychEmotionTriggerHooked = true
	editBox:HookScript("OnTextChanged", function(self)
		HandleEmotionPickerTrigger(self)
	end)
	editBox:HookScript("OnHide", function(self)
		ClearTriggerPickerOnEditBoxClose(self)
	end)
	editBox:HookScript("OnEscapePressed", function(self)
		ClearTriggerPickerOnEditBoxClose(self)
	end)
end

local function SetupAllEmotionPickerTriggers()
	HookEmotionPickerTrigger(_G["ChatFrame1EditBox"])
	if NUM_CHAT_WINDOWS then
		for i = 1, NUM_CHAT_WINDOWS do
			HookEmotionPickerTrigger(_G["ChatFrame" .. i .. "EditBox"])
		end
	end
end

local function GetMenuButton()
	return _G.ChatFrameMenuButton
end

-- DF micromenu-like states:
-- idle → soft white; hover → warm highlight;
-- picker open + hover → bright gold (like DF mouseover while selected);
-- picker open + cursor away → darker gold (like DF "down"/pushed while selected).
local COLOR_NORMAL = { 1.0, 1.0, 1.0, 0.65 }
local COLOR_HOVER = { 1.0, 0.98, 0.82, 0.95 }
local COLOR_ACTIVE = { 1.0, 0.82, 0.0, 1.0 }
local COLOR_ACTIVE_IDLE = { 0.55, 0.40, 0.0, 0.90 }

local function IsEmotionPickerShown()
	return pickerFrame and pickerFrame:IsShown()
end

local function UpdateEmotionButtonAppearance(btn)
	if not btn or not btn.icon then return end
	local active = IsEmotionPickerShown()
	local hovered = btn._emotionHovered and true or false
	local color
	local useAdd = false
	if active then
		if hovered then
			color = COLOR_ACTIVE
			useAdd = true
		else
			color = COLOR_ACTIVE_IDLE
		end
	elseif hovered then
		color = COLOR_HOVER
		useAdd = true
	else
		color = COLOR_NORMAL
	end
	if btn.icon.SetBlendMode then
		btn.icon:SetBlendMode(useAdd and "ADD" or "BLEND")
	end
	btn.icon:SetVertexColor(color[1], color[2], color[3], color[4])
end

SyncEmotionButtonAppearance = function()
	for _, btn in pairs(emotionButtons) do
		UpdateEmotionButtonAppearance(btn)
	end
end

local function AnchorEmotionButton(btn)
	local menuBtn = GetMenuButton()
	if not (btn and menuBtn) then return end
	btn:ClearAllPoints()
	btn:SetPoint("BOTTOM", menuBtn, "TOP", 0, 2)
	btn:SetFrameStrata(menuBtn:GetFrameStrata() or "HIGH")
	btn:SetFrameLevel((menuBtn:GetFrameLevel() or 0) + 1)
end

local function CreateEmotionButton(index)
	local menuBtn = GetMenuButton()
	local parent = menuBtn or UIParent
	local name = "SarychUI_EmotionButton" .. index
	local btn = CreateFrame("Button", name, parent)
	btn:SetSize(22, 22)
	AnchorEmotionButton(btn)

	local shadow = btn:CreateTexture(nil, "BACKGROUND")
	shadow:SetSize(22, 22)
	shadow:SetPoint("CENTER", btn, "CENTER", 1, -1)
	shadow:SetTexture(PICKER_BUTTON_TEXTURE)
	shadow:SetTexCoord(unpack(PICKER_BUTTON_TEXCOORD))
	shadow:SetVertexColor(0, 0, 0, 0.75)
	btn.shadow = shadow

	local tex = btn:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetTexture(PICKER_BUTTON_TEXTURE)
	tex:SetTexCoord(unpack(PICKER_BUTTON_TEXCOORD))
	tex:SetVertexColor(COLOR_NORMAL[1], COLOR_NORMAL[2], COLOR_NORMAL[3], COLOR_NORMAL[4])
	btn.icon = tex

	btn:SetScript("OnEnter", function(self)
		self._emotionHovered = true
		UpdateEmotionButtonAppearance(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Смайлики", 1, 1, 1)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function(self)
		self._emotionHovered = nil
		UpdateEmotionButtonAppearance(self)
		GameTooltip:Hide()
	end)
	btn:SetScript("OnClick", function(self)
		TogglePicker(self)
		UpdateEmotionButtonAppearance(self)
	end)

	btn:Hide()
	return btn
end

local function UpdateEmotionButtonVisibility(btn)
	if not btn then return end
	if not IsEmotionPickerEnabled() then
		btn:Hide()
		return
	end
	local menuBtn = GetMenuButton()
	if menuBtn and menuBtn:IsShown() then
		AnchorEmotionButton(btn)
		btn:Show()
	else
		btn:Hide()
	end
end

local function SyncEmotionButton()
	local btn = emotionButtons[1]
	if not btn then return end
	UpdateEmotionButtonVisibility(btn)
end

local function HookMenuButtonForEmotion()
	local menuBtn = GetMenuButton()
	if not menuBtn or menuBtn._sarychEmotionHooked then return end
	menuBtn._sarychEmotionHooked = true
	menuBtn:HookScript("OnShow", SyncEmotionButton)
	menuBtn:HookScript("OnHide", function()
		local btn = emotionButtons[1]
		if btn then btn:Hide() end
		if pickerFrame and pickerFrame:IsShown() then
			pickerFrame:Hide()
		end
	end)
end

local function SetupEmotionButton(editBox, index)
	HookMenuButtonForEmotion()

	local btn = emotionButtons[index]
	if not btn then
		btn = CreateEmotionButton(index)
		emotionButtons[index] = btn
	end

	if editBox and not editBox._sarychEmotionHooked then
		editBox._sarychEmotionHooked = true
		editBox:HookScript("OnEditFocusGained", SyncEmotionButton)
		editBox:HookScript("OnEditFocusLost", SyncEmotionButton)
		editBox:HookScript("OnHide", function()
			if pickerFrame and pickerFrame:IsShown() then
				pickerFrame:Hide()
			end
		end)
	end

	UpdateEmotionButtonVisibility(btn)
end

local function SetupAllEmotionButtons()
	if not IsEmotionPickerEnabled() then
		for _, btn in pairs(emotionButtons) do
			if btn then btn:Hide() end
		end
		if pickerFrame then pickerFrame:Hide() end
		return
	end

	SetupEmotionButton(_G["ChatFrame1EditBox"], 1)

	for i = 2, NUM_CHAT_WINDOWS do
		local eb = _G["ChatFrame" .. i .. "EditBox"]
		if eb and emotionButtons[i] then
			emotionButtons[i]:Hide()
		end
	end
end

local function HideAllEmotionButtons()
	for _, btn in pairs(emotionButtons) do
		if btn then btn:Hide() end
	end
	if pickerFrame then pickerFrame:Hide() end
	pickerOpen = false
end

-- ========================================
-- Chat bubble emoji support (ElvUI WorldFrame scan approach)
-- ========================================

local BUBBLE_BG_TEXTURE = [[Interface\Tooltips\ChatBubble-Background]]
local BUBBLE_SCAN_INTERVAL_NORMAL = 0.15
local BUBBLE_SCAN_INTERVAL_OPTIMIZE = 0.25

local function GetBubbleScanInterval()
	if SarychUI and SarychUI.Compatibility then
		return SarychUI.Compatibility:GetInterval("bubbleScan", BUBBLE_SCAN_INTERVAL_NORMAL, BUBBLE_SCAN_INTERVAL_OPTIMIZE)
	end
	return BUBBLE_SCAN_INTERVAL_NORMAL
end
local bubbleScanFrame = nil
local lastBubbleWorldChildCount = -1

local function PerfBubbleLog(stage, startTime)
	if DEBUG_EMOJI_BUBBLES_PERF and startTime then
		print(string.format("|cff00ff00[Emoji Bubbles Perf]|r %s: %.2f ms", stage, debugprofilestop() - startTime))
	end
end

local function DebugBubbleLog(...)
	if DEBUG_EMOJI_BUBBLES then
		print((SarychUI and SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("Emoji Bubbles") or "|cffffd200SarychUI Emoji Bubbles:|r"), ...)
	end
end

local NOT_BUBBLE_CACHE_TTL = 15

-- Copies a vararg list into a reused table. Callers pass the result of a single
-- GetRegions()/GetChildren() call so the C function is not re-invoked per index.
local function FillFrom(t, ...)
	local n = select("#", ...)
	for i = 1, n do
		t[i] = select(i, ...)
	end
	for i = n + 1, #t do
		t[i] = nil
	end
	return n
end

local regionBuffer = {}

local function IsChatBubble(frame)
	if not frame or not frame.GetNumRegions then return false end
	if frame.__SarychUIIsBubble == true then
		return true
	end
	local numRegions = FillFrom(regionBuffer, frame:GetRegions())
	for i = 1, numRegions do
		local region = regionBuffer[i]
		if region and region.GetTexture and region:GetTexture() == BUBBLE_BG_TEXTURE then
			frame.__SarychUIIsBubble = true
			frame.__SarychUINotBubbleUntil = nil
			return true
		end
	end
	frame.__SarychUINotBubbleUntil = GetTime() + NOT_BUBBLE_CACHE_TTL
	return false
end

local function GetBubbleFontString(frame)
	if frame.__SarychUIFontString then
		return frame.__SarychUIFontString
	end
	local numRegions = FillFrom(regionBuffer, frame:GetRegions())
	for i = 1, numRegions do
		local region = regionBuffer[i]
		if region and region.GetObjectType and region:GetObjectType() == "FontString" then
			frame.__SarychUIFontString = region
			DebugBubbleLog("found FontString on bubble", frame:GetName() or tostring(frame))
			return region
		end
	end
end

local function IsBubbleTextProcessed(text)
	return text and find(text, "|T", 1, true) and find(text, MEDIA_PATH, 1, true)
end

local function UpdateChatBubbleEmojis(frame)
	if not frame or not IsChatBubble(frame) then return end

	local fontString = GetBubbleFontString(frame)
	if not fontString or not fontString.GetText then return end

	local text = fontString:GetText()
	if not text or text == "" then return end

	if not IsEmotionBubblesEnabled() then
		if frame.__SarychUIEmojiOriginal and text ~= frame.__SarychUIEmojiOriginal then
			fontString:SetText(frame.__SarychUIEmojiOriginal)
			DebugBubbleLog("restored original", frame.__SarychUIEmojiOriginal)
		end
		frame.__SarychUIEmojiProcessed = nil
		return
	end

	if frame.__SarychUIEmojiProcessed and text == frame.__SarychUIEmojiProcessed then
		DebugBubbleLog("skip, already processed")
		return
	end

	local sourceText = frame.__SarychUIEmojiOriginal

	if not sourceText then
		if IsBubbleTextProcessed(text) then
			DebugBubbleLog("skip, processed without original")
			return
		end
		sourceText = text
		frame.__SarychUIEmojiOriginal = sourceText
	elseif text ~= frame.__SarychUIEmojiProcessed and not IsBubbleTextProcessed(text) then
		sourceText = text
		frame.__SarychUIEmojiOriginal = sourceText
		frame.__SarychUIEmojiProcessed = nil
	end

	if frame.__SarychUIEmojiProcessed and sourceText == frame.__SarychUIEmojiLastSource then
		if text ~= frame.__SarychUIEmojiProcessed then
			fontString:SetText(frame.__SarychUIEmojiProcessed)
			DebugBubbleLog("re-applied processed text")
		end
		return
	end

	local newText = GetSmileyReplacementText(sourceText)
	frame.__SarychUIEmojiLastSource = sourceText

	if newText ~= sourceText then
		frame.__SarychUIEmojiProcessed = newText
		fontString:SetText(newText)
		DebugBubbleLog("updated", sourceText, "->", newText)
	else
		frame.__SarychUIEmojiProcessed = sourceText
	end
end

local function HookChatBubble(frame)
	if not frame or frame.__SarychUIEmojiHooked then return end
	frame.__SarychUIEmojiHooked = true
	frame:HookScript("OnShow", function(self)
		UpdateChatBubbleEmojis(self)
	end)
	DebugBubbleLog("hooked bubble", frame:GetName() or tostring(frame))
end

-- Reused across scans: WorldFrame:GetChildren() must be called once per scan, not
-- once per index, otherwise the walk is O(children^2) in pushed stack values.
local worldChildren = {}

-- Single GetChildren() call, table reused so the scan produces no garbage.
local function CollectWorldChildren()
	return FillFrom(worldChildren, WorldFrame:GetChildren())
end

local function ScanKnownChatBubbles()
	for i = 1, #worldChildren do
		local child = worldChildren[i]
		if child and child.__SarychUIIsBubble == true then
			HookChatBubble(child)
			if not child.IsShown or child:IsShown() then
				UpdateChatBubbleEmojis(child)
			end
		end
	end
end

local function ScanChatBubbles()
	if not WorldFrame or not WorldFrame.GetNumChildren then return end

	local scanStart = DEBUG_EMOJI_BUBBLES_PERF and debugprofilestop() or nil
	local numChildren = WorldFrame:GetNumChildren()

	if numChildren == lastBubbleWorldChildCount then
		ScanKnownChatBubbles()
		PerfBubbleLog("scan known bubbles", scanStart)
		return
	end

	lastBubbleWorldChildCount = numChildren
	numChildren = CollectWorldChildren()
	local now = GetTime()
	for i = 1, numChildren do
		local child = worldChildren[i]
		if not child then
		elseif child.__SarychUIIsBubble == true then
			HookChatBubble(child)
			if not child.IsShown or child:IsShown() then
				UpdateChatBubbleEmojis(child)
			end
		elseif child.__SarychUINotBubbleUntil and now < child.__SarychUINotBubbleUntil then
			-- Recently confirmed not a bubble; skip GetRegions rescan.
		elseif IsChatBubble(child) then
			HookChatBubble(child)
			if not child.IsShown or child:IsShown() then
				UpdateChatBubbleEmojis(child)
			end
		end
	end
	PerfBubbleLog("scan full bubbles", scanStart)
end

local function EnableBubbleScanner()
	if bubbleScanFrame then return end

	bubbleScanFrame = CreateFrame("Frame")
	bubbleScanFrame.elapsed = 0
	bubbleScanFrame:SetScript("OnUpdate", function(self, elapsed)
		-- Accumulate before reading settings, so the profile lookups happen a few
		-- times per second instead of on every frame.
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < GetBubbleScanInterval() then return end
		self.elapsed = 0

		if not IsEmotionBubblesEnabled() then return end

		ScanChatBubbles()
	end)
	DebugBubbleLog("bubble scanner enabled")
end

local function DisableBubbleScanner()
	if bubbleScanFrame then
		bubbleScanFrame:SetScript("OnUpdate", nil)
		bubbleScanFrame = nil
	end
	lastBubbleWorldChildCount = -1
	DebugBubbleLog("bubble scanner disabled")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
eventFrame:SetScript("OnEvent", function()
	SetupAllEmotionButtons()
	SetupAllEmotionPickerTriggers()
end)

-- Starts or stops the bubble poll. Turning it off does one final pass first, so
-- bubbles already on screen get their plain text back instead of keeping icons.
local function ApplyBubbleSettings()
	if IsEmotionBubblesEnabled() then
		EnableBubbleScanner()
	elseif bubbleScanFrame then
		ScanChatBubbles()
		DisableBubbleScanner()
	end
end

local function EnableEmotionIcons()
	RefreshEmotionIconsCache()
	RegisterEmotionFilter()
	ApplyBubbleSettings()
end

local function DisableEmotionIcons()
	emotionIconsCacheActive = false
	UnregisterEmotionFilter()
	ApplyBubbleSettings()
end

local function EnableEmotionPicker()
	SetupAllEmotionButtons()
end

local function DisableEmotionPicker()
	HideAllEmotionButtons()
end

local function ApplyEmotionSettings()
	DefaultSmileys()
	RefreshEmotionIconsCache()

	if IsEmotionIconsEnabled() then
		EnableEmotionIcons()
	else
		DisableEmotionIcons()
	end

	if IsEmotionPickerEnabled() then
		EnableEmotionPicker()
	else
		DisableEmotionPicker()
	end
end

local function InitializeEmotions()
	DefaultSmileys()
	SetupAllEmotionPickerTriggers()
	ApplyEmotionSettings()
end

-- Public API (ElvUI-compatible subset)
_G.SarychUI_ChatEmotions = {
	Smileys = Smileys,
	AddSmiley = AddSmiley,
	RemoveSmiley = RemoveSmiley,
	InsertEmotions = InsertEmotions,
	GetSmileyReplacementText = GetSmileyReplacementText,
	GetSmileyPlainText = GetSmileyPlainText,
	UpdateChatBubbleEmojis = UpdateChatBubbleEmojis,
	DefaultSmileys = DefaultSmileys,
}

_G.SarychUI_ApplyEmotionIcons = GetSmileyReplacementText
_G.ApplyEmotionSettings = ApplyEmotionSettings
_G.EnableEmotionIcons = EnableEmotionIcons
_G.DisableEmotionIcons = DisableEmotionIcons
_G.EnableEmotionPicker = EnableEmotionPicker
_G.DisableEmotionPicker = DisableEmotionPicker
_G.InitializeEmotions = InitializeEmotions

InitializeEmotions()
