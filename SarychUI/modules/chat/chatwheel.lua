local ChatWheel = {}
_G.SarychUI_ChatWheel = ChatWheel

local floor = math.floor
local rad = math.rad
local atan2 = math.atan2 or function(y, x)
	if x == 0 then
		if y > 0 then return math.pi * 0.5 end
		if y < 0 then return -math.pi * 0.5 end
		return 0
	end
	local a = math.atan(y / x)
	if x < 0 then
		a = a + (y >= 0 and math.pi or -math.pi)
	end
	return a
end

local WHEEL_SIZE = 596
local SLICES_SIZE = 680
local PLATE_SIZE = 180
local PLATE_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\background_plate_png.dxt5.blp"
local SLICE_SECTOR_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\slice_sector.tga"
local CIRCLE_BG2_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\circle_bg2_png.dxt5.blp"
local CIRCLE_BG2_DEFAULTS = {
	x = 0,
	y = -5,
	width = 109,
	height = 109,
}
local CIRCLE_PNG_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\circle_png.dxt5.blp"
local CIRCLE_PNG_DEFAULTS = {
	x = 0,
	y = -5,
	width = 109,
	height = 109,
}
local CIRCLE_POINTER_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\circle_pointer_png.dxt5.blp"
local CIRCLE_POINTER_DEFAULTS = {
	x = -1,
	y = 0,
	width = 152,
	height = 152,
}
local CIRCLE_POINTER_ALPHA = 0.5
local ARROW_PSD_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\arrow_psd.dxt5.blp"
local CENTER_CURSOR_SIZE = 46
local CENTER_CURSOR_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\center_cursor_png.dxt5.blp"
local OUTER_CURSOR_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\icon_add_png.dxt5.blp"
local CURSOR_HIDDEN_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\cursor_hidden.tga"
local OUTER_CURSOR_DEFAULTS = {
	enabled = true,
	size = 32,
	safePadding = 14,
}
local OUTER_CURSOR_RADIUS_SCALE = 0.7
local PHRASE_DEFAULTS = {
	enabled = true,
	offset = 55,
	fontSize = 20,
	maxWidth = 260,
	selectedScale = 1.15,
	animSpeed = 30,
}
local PHRASE_ANIM_MAX_ELAPSED = 0.05
local PHRASE_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local PHRASE_TEXT_DEFAULTS = {
	"Фраза 1",
	"Фраза 2",
	"Фраза 3",
	"Фраза 4",
	"Фраза 5",
	"Фраза 6",
	"Фраза 7",
	"Подтверждаю",
}
local CHANNEL_MODES = {
	adaptive = true,
	say = true,
	party = true,
	raid = true,
	guild = true,
	yell = true,
	emote = true,
}
-- Sector 1 = top, clockwise. Anchor phrase frame so text grows away from center.
local PHRASE_ANCHOR_POINTS = { "CENTER", "LEFT", "LEFT", "LEFT", "CENTER", "RIGHT", "RIGHT", "RIGHT" }
local PHRASE_COLOR_DIM_FACTOR = 0.67
local PHRASE_COLOR_EMPTY = { 0.50, 0.50, 0.50 }

-- Framerate-independent lerp (same pattern as addons/SarychUI_Bags/Core/Smoothie.lua, lightspark).
local function LerpStep(speed, elapsed)
	return math.min(1, speed * elapsed)
end

local function LerpColorChannel(current, target, speed, elapsed)
	local step = LerpStep(speed, elapsed)
	local new = current + (target - current) * step
	if math.abs(new - target) < 0.01 then
		return target
	end
	return new
end

local function LerpScale(current, target, speed, elapsed)
	local step = LerpStep(speed, elapsed)
	local new = current + (target - current) * step
	if math.abs(new - target) < 0.001 then
		return target
	end
	return new
end

local function CopyPhraseColor(dst, src)
	dst[1] = src[1]
	dst[2] = src[2]
	dst[3] = src[3]
end

local function InitPhraseAnimState(phrase)
	if phrase.currentScale == nil then
		phrase.currentScale = 1
	end
	if phrase.targetScale == nil then
		phrase.targetScale = 1
	end
	if not phrase.currentColor then
		phrase.currentColor = { 1, 1, 1 }
	end
	if not phrase.targetColor then
		phrase.targetColor = { 1, 1, 1 }
	end
end

local function SetupPhraseLabelBox(phrase, idx, maxWidth, fontSize)
	local phraseFrame = phrase.frame
	local labelBox = phrase.labelBox
	local fontString = phrase.fontString
	if not phraseFrame or not labelBox or not fontString then
		return
	end

	labelBox:SetSize(maxWidth, fontSize + 8)
	if phrase.labelBoxDone then
		return
	end

	local anchorPoint = PHRASE_ANCHOR_POINTS[idx] or "CENTER"
	if anchorPoint == "CENTER" then
		labelBox:SetPoint("CENTER", phraseFrame, "CENTER", 0, 0)
		fontString:SetJustifyH("CENTER")
	elseif anchorPoint == "LEFT" then
		labelBox:SetPoint("RIGHT", phraseFrame, "RIGHT", 0, 0)
		fontString:SetJustifyH("LEFT")
	else
		labelBox:SetPoint("LEFT", phraseFrame, "LEFT", 0, 0)
		fontString:SetJustifyH("RIGHT")
	end
	fontString:SetPoint("TOPLEFT", labelBox, "TOPLEFT", 0, 0)
	fontString:SetPoint("TOPRIGHT", labelBox, "TOPRIGHT", 0, 0)
	labelBox:SetScale(1)
	phrase.labelBoxDone = true
end

local function ApplyPhraseFont(phrase, fontSize, maxWidth)
	local fontString = phrase.fontString
	if not fontString then
		return
	end
	if phrase.appliedFontSize == fontSize and phrase.appliedMaxWidth == maxWidth then
		return
	end
	if fontString.SetFontObject then
		fontString:SetFontObject(nil)
	end
	fontString:SetFont(PHRASE_FONT_PATH, fontSize, "OUTLINE")
	fontString:SetWidth(maxWidth)
	phrase.appliedFontSize = fontSize
	phrase.appliedMaxWidth = maxWidth
end

local ARROW_DEFAULTS = {
	enabled = true,
	size = 46,
	gap = 6,
	anchorOffset = 0,
	alpha = 0.9,
}
-- Fixed arrow reference circle (calibrated from debug box 93×93 at X=-1, Y=0); not tied to debugBox settings.
local ARROW_CIRCLE_X = -1
local ARROW_CIRCLE_Y = 0
local ARROW_CIRCLE_SIZE = 93
-- Sector index 1..8: math angle degrees (0° = right, texture default points right).
local ARROW_SECTOR_ANGLE_DEFAULTS = { 90, 45, 0, -43, -89, -136, 179, 135 }

local SLICE_COUNT = 8
local SLICE_SPAN_DEG = 360 / SLICE_COUNT
local SLICE_HALF_ANGLE = SLICE_SPAN_DEG * 0.5
local SLICE_OUTER_RADIUS = SLICES_SIZE * 0.5

-- dota_hud_chat_wheel.css — Panorama #RGBA (nibble * 17 / 255)
-- .SliceBackground          from #000f, stop #000c, to #0000
-- .SliceBackground.Even     from #333f, stop #333c, to #3330
-- .SliceBackground.SecondMod  from #000f, stop #333c, to #4440
-- .SliceBackground.ThirdMod   from #333f, stop #333c, to #3330
-- Cycle per sector: default, Even, SecondMod, ThirdMod (×2)
local SLICE_STYLES = {
	{ 0.20, 0.20, 0.20, 1.00 }, -- SliceBackground (inverted: was dark)
	{ 0.00, 0.00, 0.00, 1.00 }, -- .Even / #333 (inverted: was light)
	{ 0.20, 0.20, 0.20, 1.00 }, -- .SecondMod (inverted: was dark)
	{ 0.00, 0.00, 0.00, 1.00 }, -- .ThirdMod / #333 (inverted: was light)
}
-- .Slices #SlicesSelection — white radial, opacity 0.5
local SLICE_HOVER_COLOR = { 1.00, 1.00, 1.00, 1.00 }

local DEBUG_LINE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local DEBUG_LINE_THICKNESS = 0.5
local DEBUG_LINE_COLOR = { 0.10, 1.00, 0.10, 1.00 }
local DEBUG_CIRCLE_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\debug_circle.tga"
local DEBUG_BOX_DEFAULTS = {
	enabled = false,
	x = 0,
	y = 0,
	width = 180,
	height = 180,
}
local BuildFrames

local MOUSE_BINDINGS = {
	BUTTON1 = "LeftButton",
	BUTTON2 = "RightButton",
	BUTTON3 = "MiddleButton",
	BUTTON4 = "Button4",
	BUTTON5 = "Button5",
}

local KEY_ALIASES = {
	[" "] = "SPACE",
	SPACEBAR = "SPACE",
}

local State = {
	enabled = false,
	binding = nil,
	isBindingDown = false,
	isOpen = false,
	wheel = nil,
	slicesBox = nil,
	slicesBackgroundContainer = nil,
	slices = {},
	hoveredSlice = nil,
	plateBox = nil,
	backgroundPlate = nil,
	circleBG2Box = nil,
	circleBG2Texture = nil,
	circlePNGBox = nil,
	circlePNGTexture = nil,
	circlePointerBox = nil,
	circlePointerTexture = nil,
	arrowBox = nil,
	arrowTexture = nil,
	centerCursorBox = nil,
	centerCursorTexture = nil,
	outerCursorBox = nil,
	outerCursorTexture = nil,
	systemCursorHidden = false,
	cursorSafetyFrame = nil,
	virtualWheelX = nil,
	virtualWheelY = nil,
	lastMouseX = nil,
	lastMouseY = nil,
	skipVirtualCursorDelta = false,
	phrasesContainer = nil,
	phrases = {},
	debugBox = nil,
	debugBoxLines = nil,
	debugCircleTexture = nil,
	mouseDown = {},
	mouseHooked = false,
	listener = nil,
	holdButton = nil,
	keyCapture = nil,
	savedBindingKey = nil,
	savedBindingAction = nil,
	phraseChannelEventFrame = nil,
}

local function GetWheelDB()
	local chat = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
	if not chat then
		return nil
	end
	return chat.chatWheel
end

local function IsChatModuleEnabled()
	local chat = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
	return chat and (chat.enabled == true or chat.enabled == 1)
end

local function IsAlwaysShow()
	local db = GetWheelDB()
	return db and (db.alwaysShow == 1 or db.alwaysShow == true)
end

local function NormalizeKey(key)
	if not key or key == "" then
		return nil
	end
	key = key:upper()
	return KEY_ALIASES[key] or key
end

local function ParseBinding(bindingString)
	if not bindingString or bindingString == "" then
		return nil
	end

	local mods = { ALT = false, CTRL = false, SHIFT = false }
	local key = nil
	local raw = bindingString:upper()

	for token in raw:gmatch("[^-]+") do
		if token == "ALT" or token == "CTRL" or token == "SHIFT" then
			mods[token] = true
		else
			key = NormalizeKey(token)
		end
	end

	if not key then
		return nil
	end

	return {
		raw = raw,
		key = key,
		mods = mods,
		mouseButton = MOUSE_BINDINGS[key],
	}
end

local function ModifiersMatch(binding)
	if binding.mods.ALT and not IsAltKeyDown() then return false end
	if binding.mods.CTRL and not IsControlKeyDown() then return false end
	if binding.mods.SHIFT and not IsShiftKeyDown() then return false end
	return true
end

local function IsMouseBindingHeld(binding)
	if not binding or not binding.mouseButton then return false end
	if not ModifiersMatch(binding) then return false end
	return State.mouseDown[binding.mouseButton] == true
end

local function ApplySliceColor(texture, sliceIndex, hovered)
	if hovered then
		local h = SLICE_HOVER_COLOR
		texture:SetVertexColor(h[1], h[2], h[3], h[4])
		return
	end
	local style = SLICE_STYLES[((sliceIndex - 1) % #SLICE_STYLES) + 1]
	texture:SetVertexColor(style[1], style[2], style[3], style[4])
end

local function DisableFrameHitTest(frame)
	if frame and frame.EnableMouse then
		frame:EnableMouse(false)
	end
end

local function GetWheelCursorOffset()
	local wheel = State.wheel
	if not wheel or not wheel:IsShown() then
		return nil, nil
	end
	if State.isOpen and State.virtualWheelX ~= nil and State.virtualWheelY ~= nil then
		return State.virtualWheelX, State.virtualWheelY
	end
	local uiScale = UIParent:GetEffectiveScale()
	local mx, my = GetCursorPosition()
	mx, my = mx / uiScale, my / uiScale
	local cx, cy = wheel:GetCenter()
	if not cx or not cy then
		local left, bottom = wheel:GetLeft(), wheel:GetBottom()
		if not left or not bottom then
			return nil, nil
		end
		cx = left + wheel:GetWidth() * 0.5
		cy = bottom + wheel:GetHeight() * 0.5
	end
	return mx - cx, my - cy
end

local function GetCursorOffsetFromWheel()
	local dx, dy = GetWheelCursorOffset()
	return dx or 0, dy or 0
end

local function GetCursorOffsetFromFrameCenter(frame)
	if not frame or not frame:IsShown() then
		return 0, 0
	end
	local left, bottom = frame:GetLeft(), frame:GetBottom()
	if not left or not bottom then
		return 0, 0
	end
	local uiScale = UIParent:GetEffectiveScale()
	local mx, my = GetCursorPosition()
	mx, my = mx / uiScale, my / uiScale
	local cx = left + frame:GetWidth() * 0.5
	local cy = bottom + frame:GetHeight() * 0.5
	return mx - cx, my - cy
end

local function NormalizeDegrees(deg)
	deg = deg % 360
	if deg < 0 then
		deg = deg + 360
	end
	return deg
end

local function GetDebugBoxSettings()
	local db = GetWheelDB()
	if not db then
		return DEBUG_BOX_DEFAULTS.enabled, DEBUG_BOX_DEFAULTS.x, DEBUG_BOX_DEFAULTS.y, DEBUG_BOX_DEFAULTS.width, DEBUG_BOX_DEFAULTS.height
	end
	local enabled = db.debugBoxEnabled == 1 or db.debugBoxEnabled == true
	local x = tonumber(db.debugBoxX) or DEBUG_BOX_DEFAULTS.x
	local y = tonumber(db.debugBoxY) or DEBUG_BOX_DEFAULTS.y
	local w = tonumber(db.debugBoxWidth) or DEBUG_BOX_DEFAULTS.width
	local h = tonumber(db.debugBoxHeight) or DEBUG_BOX_DEFAULTS.height
	w = math.max(1, math.min(800, w))
	h = math.max(1, math.min(800, h))
	x = math.max(-400, math.min(400, x))
	y = math.max(-400, math.min(400, y))
	return enabled, x, y, w, h
end

local function GetDebugCircleGeometry()
	local _, debugCenterX, debugCenterY, debugW, debugH = GetDebugBoxSettings()
	local debugRadius = math.min(debugW, debugH) * 0.5
	return debugCenterX, debugCenterY, debugRadius
end

local function GetPhraseSettings()
	local db = GetWheelDB()
	local offset = PHRASE_DEFAULTS.offset
	local fontSize = PHRASE_DEFAULTS.fontSize
	local maxWidth = PHRASE_DEFAULTS.maxWidth
	if db then
		offset = tonumber(db.phraseOffset) or offset
		fontSize = tonumber(db.phraseFontSize) or fontSize
		maxWidth = tonumber(db.phraseMaxWidth) or maxWidth
	end
	offset = math.max(0, math.min(300, offset))
	fontSize = math.max(8, math.min(40, fontSize))
	maxWidth = math.max(40, math.min(600, maxWidth))
	return offset, fontSize, maxWidth
end

local function GetSelectedPhraseScale()
	local db = GetWheelDB()
	local _, fontSize = GetPhraseSettings()
	if db and db.selectedPhraseScale ~= nil then
		local scale = tonumber(db.selectedPhraseScale) or PHRASE_DEFAULTS.selectedScale
		return math.max(1.0, math.min(2.5, scale))
	end
	if db and db.selectedPhraseFontSize ~= nil then
		local selectedSize = tonumber(db.selectedPhraseFontSize) or fontSize
		if fontSize > 0 then
			return math.max(1.0, math.min(2.5, selectedSize / fontSize))
		end
	end
	return PHRASE_DEFAULTS.selectedScale
end

local function GetPhraseAnimSpeed()
	local db = GetWheelDB()
	local speed = PHRASE_DEFAULTS.animSpeed
	if db and db.phraseAnimSpeed ~= nil then
		speed = tonumber(db.phraseAnimSpeed) or speed
	end
	-- Legacy per-frame factors (0.05–1.0) are incompatible with points/sec model.
	if speed <= 1.0 then
		speed = PHRASE_DEFAULTS.animSpeed
	end
	return math.max(4, math.min(100, speed))
end

local GetPhraseColorNormal, GetPhraseColorDim, IsPhraseSlotEmpty, RefreshPhraseChannelColors

local function SetPhraseTargetsForSelection(selectedIdx)
	local selectedScale = GetSelectedPhraseScale()
	local hasSelection = selectedIdx ~= nil
	local normalR, normalG, normalB = GetPhraseColorNormal()
	local dimR, dimG, dimB = GetPhraseColorDim()

	for i, phrase in ipairs(State.phrases) do
		InitPhraseAnimState(phrase)
		local r, g, b
		if IsPhraseSlotEmpty(i) then
			r, g, b = PHRASE_COLOR_EMPTY[1], PHRASE_COLOR_EMPTY[2], PHRASE_COLOR_EMPTY[3]
		elseif hasSelection and i == selectedIdx then
			phrase.targetScale = selectedScale
			r, g, b = normalR, normalG, normalB
		else
			phrase.targetScale = 1
			if hasSelection then
				r, g, b = dimR, dimG, dimB
			else
				r, g, b = normalR, normalG, normalB
			end
		end
		phrase.targetColor[1] = r
		phrase.targetColor[2] = g
		phrase.targetColor[3] = b
	end
end

local function UpdatePhraseAnimation(elapsed)
	if not State.wheel or not State.wheel:IsShown() or not State.phrases[1] then
		return
	end

	elapsed = math.min(elapsed or 0, PHRASE_ANIM_MAX_ELAPSED)
	local speed = GetPhraseAnimSpeed()

	for _, phrase in ipairs(State.phrases) do
		local labelBox = phrase.labelBox
		local fontString = phrase.fontString
		if labelBox and fontString then
			InitPhraseAnimState(phrase)

			phrase.currentScale = LerpScale(phrase.currentScale, phrase.targetScale, speed, elapsed)
			labelBox:SetScale(phrase.currentScale)

			for c = 1, 3 do
				phrase.currentColor[c] = LerpColorChannel(
					phrase.currentColor[c],
					phrase.targetColor[c],
					speed,
					elapsed
				)
			end

			local r, g, b = phrase.currentColor[1], phrase.currentColor[2], phrase.currentColor[3]
			if phrase.appliedColorR ~= r or phrase.appliedColorG ~= g or phrase.appliedColorB ~= b then
				fontString:SetTextColor(r, g, b, 1)
				phrase.appliedColorR = r
				phrase.appliedColorG = g
				phrase.appliedColorB = b
			end
		end
	end
end

RefreshPhraseChannelColors = function()
	if not State.phrases[1] then
		return
	end
	SetPhraseTargetsForSelection(State.hoveredSlice)
	if not State.wheel or not State.wheel:IsShown() then
		return
	end
	for _, phrase in ipairs(State.phrases) do
		InitPhraseAnimState(phrase)
		CopyPhraseColor(phrase.currentColor, phrase.targetColor)
		local fontString = phrase.fontString
		if fontString then
			fontString:SetTextColor(phrase.currentColor[1], phrase.currentColor[2], phrase.currentColor[3], 1)
		end
		phrase.appliedColorR = nil
		phrase.appliedColorG = nil
		phrase.appliedColorB = nil
	end
end

function ChatWheel.RefreshPhraseChannelColors()
	RefreshPhraseChannelColors()
end

local function EnsurePhraseChannelEventFrame()
	if State.phraseChannelEventFrame then
		return
	end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	frame:RegisterEvent("RAID_ROSTER_UPDATE")
	frame:SetScript("OnEvent", function()
		if State.phrases[1] and State.wheel and State.wheel:IsShown() then
			RefreshPhraseChannelColors()
		end
	end)
	State.phraseChannelEventFrame = frame
end

local function GetPhrasePositionOffset(idx)
	local db = GetWheelDB()
	local x, y = 0, 0
	if db then
		x = tonumber(db["phrase" .. idx .. "X"]) or 0
		y = tonumber(db["phrase" .. idx .. "Y"]) or 0
	end
	return math.max(-400, math.min(400, x)), math.max(-400, math.min(400, y))
end

local function TrimText(value)
	if value == nil then
		return ""
	end
	return (tostring(value):match("^%s*(.-)%s*$")) or ""
end

local function GetPhraseText(idx)
	local db = GetWheelDB()
	local default = PHRASE_TEXT_DEFAULTS[idx] or ("Фраза " .. idx)
	if not db then
		return default
	end
	local key = "phrase" .. idx .. "Text"
	local value = db[key]
	if value == nil then
		return default
	end
	return value
end

IsPhraseSlotEmpty = function(idx)
	return TrimText(GetPhraseText(idx)) == ""
end

local function FormatPhraseDisplayText(text)
	if not text or text == "" then
		return text
	end
	local emotions = _G.SarychUI_ChatEmotions
	if emotions and emotions.GetSmileyReplacementText then
		return emotions.GetSmileyReplacementText(text)
	end
	if _G.SarychUI_ApplyEmotionIcons then
		return _G.SarychUI_ApplyEmotionIcons(text)
	end
	return text
end

local function GetPhraseEmote(idx)
	local db = GetWheelDB()
	if not db then
		return ""
	end
	local value = db["phrase" .. idx .. "Emote"]
	if value == nil then
		return ""
	end
	return value
end

local function GetChannelMode()
	local db = GetWheelDB()
	local mode = db and db.chatWheelChannelMode or "adaptive"
	if not CHANNEL_MODES[mode] then
		mode = "adaptive"
	end
	return mode
end

local function GetAdaptiveChatType()
	if (GetNumRaidMembers() or 0) > 0 then
		return "RAID"
	end
	if (GetNumPartyMembers() or 0) > 0 then
		return "PARTY"
	end
	return "SAY"
end

local function ResolveChatType(channelMode)
	if channelMode == "say" then
		return "SAY"
	elseif channelMode == "party" then
		return "PARTY"
	elseif channelMode == "raid" then
		return "RAID"
	elseif channelMode == "guild" then
		return "GUILD"
	elseif channelMode == "yell" then
		return "YELL"
	elseif channelMode == "emote" then
		return "EMOTE"
	end
	return GetAdaptiveChatType()
end

function ChatWheel.ResolveSendChannel()
	return ResolveChatType(GetChannelMode())
end

local function GetChannelColor(channel)
	if ChatTypeInfo and channel and ChatTypeInfo[channel] then
		local c = ChatTypeInfo[channel]
		return c.r or 1, c.g or 1, c.b or 1
	end
	return 1, 1, 1
end

GetPhraseColorNormal = function()
	return GetChannelColor(ChatWheel.ResolveSendChannel())
end

GetPhraseColorDim = function()
	local r, g, b = GetPhraseColorNormal()
	return r * PHRASE_COLOR_DIM_FACTOR, g * PHRASE_COLOR_DIM_FACTOR, b * PHRASE_COLOR_DIM_FACTOR
end

local function RunSlashCommand(cmd)
	local command = TrimText(cmd)
	if command == "" then
		return
	end
	if command:sub(1, 1) ~= "/" then
		command = "/" .. command
	end

	local editBox = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend()) or _G.ChatFrame1EditBox
	if not editBox then
		return
	end

	if ChatEdit_ActivateChat then
		ChatEdit_ActivateChat(editBox)
	else
		editBox:Show()
	end

	editBox:SetText(command)
	if ChatEdit_SendText then
		ChatEdit_SendText(editBox, 1)
	end

	if editBox:GetText() and editBox:GetText() ~= "" then
		editBox:SetText("")
	end
	if ChatEdit_DeactivateChat then
		ChatEdit_DeactivateChat(editBox)
	elseif editBox.Hide then
		editBox:Hide()
	end
end

local function SendPhraseChatMessage(text)
	local message = TrimText(text)
	if message == "" or message:sub(1, 1) == "/" then
		return
	end
	SendChatMessage(message, ChatWheel.ResolveSendChannel())
end

local function SendSelectedPhrase(sectorIdx)
	if not sectorIdx then
		return
	end

	local phraseText = GetPhraseText(sectorIdx)
	local phraseEmote = GetPhraseEmote(sectorIdx)
	local mainText = TrimText(phraseText)
	local emoteField = TrimText(phraseEmote)

	if mainText == "" and emoteField == "" then
		return
	end

	if emoteField ~= "" then
		RunSlashCommand(emoteField)
	end

	local message = mainText
	if message == "" then
		return
	end
	if message:sub(1, 1) == "/" then
		RunSlashCommand(message)
		return
	end
	SendPhraseChatMessage(message)
end

local function GetPhraseSectorAngleRad(idx)
	return rad(90 - ((idx - 1) * SLICE_SPAN_DEG))
end

local function ResetPhraseAnimation()
	if not State.phrases[1] then
		return
	end
	local normalR, normalG, normalB = GetPhraseColorNormal()
	for _, phrase in ipairs(State.phrases) do
		phrase.currentScale = 1
		phrase.targetScale = 1
		if phrase.labelBox then
			phrase.labelBox:SetScale(1)
		end
		if not phrase.currentColor then
			phrase.currentColor = { normalR, normalG, normalB }
		else
			phrase.currentColor[1] = normalR
			phrase.currentColor[2] = normalG
			phrase.currentColor[3] = normalB
		end
		if not phrase.targetColor then
			phrase.targetColor = { normalR, normalG, normalB }
		else
			phrase.targetColor[1] = normalR
			phrase.targetColor[2] = normalG
			phrase.targetColor[3] = normalB
		end
		phrase.appliedColorR = nil
		phrase.appliedColorG = nil
		phrase.appliedColorB = nil
	end
end

local function LayoutPhrasePositions()
	local container = State.phrasesContainer
	local wheel = State.wheel
	if not container or not wheel then
		return
	end

	local offset, fontSize, maxWidth = GetPhraseSettings()
	container:Show()

	local debugCenterX, debugCenterY, debugRadius = GetDebugCircleGeometry()
	local phraseDistance = debugRadius + offset
	local maxScale = GetSelectedPhraseScale()
	local frameWidth = maxWidth * maxScale
	local frameHeight = (fontSize + 8) * maxScale

	for i, phrase in ipairs(State.phrases) do
		local phraseFrame = phrase.frame
		local fontString = phrase.fontString
		if phraseFrame and fontString then
			local angle = GetPhraseSectorAngleRad(i)
			local offsetX, offsetY = GetPhrasePositionOffset(i)
			local baseX = debugCenterX + (math.cos(angle) * phraseDistance)
			local baseY = debugCenterY + (math.sin(angle) * phraseDistance)
			local px = baseX + offsetX
			local py = baseY + offsetY
			local anchorPoint = PHRASE_ANCHOR_POINTS[i] or "CENTER"

			phraseFrame:SetSize(frameWidth, frameHeight)
			phraseFrame:ClearAllPoints()
			phraseFrame:SetPoint(anchorPoint, wheel, "CENTER", px, py)

			SetupPhraseLabelBox(phrase, i, maxWidth, fontSize)
			ApplyPhraseFont(phrase, fontSize, maxWidth)

			local displayText = FormatPhraseDisplayText(GetPhraseText(i))
			if phrase.displayText ~= displayText then
				fontString:SetText(displayText)
				phrase.displayText = displayText
			end
		end
	end
	RefreshPhraseChannelColors()
end

local function LayoutPhrases()
	LayoutPhrasePositions()
end

local function GetInnerDeadRadius()
	local _, _, _, debugW, debugH = GetDebugBoxSettings()
	local debugRadius = math.min(debugW, debugH) * 0.5
	local db = GetWheelDB()
	if not db or db.innerDeadRadius == nil then
		return debugRadius
	end
	local value = tonumber(db.innerDeadRadius)
	if value == nil then
		return debugRadius
	end
	return math.max(0, math.min(200, value))
end

local function GetCursorOffsetFromDebugCircle()
	local mx, my = GetWheelCursorOffset()
	if not mx then
		return nil, nil
	end
	local debugCenterX, debugCenterY = GetDebugCircleGeometry()
	return mx - debugCenterX, my - debugCenterY
end

local function GetOuterCursorSettings()
	local db = GetWheelDB()
	local enabled = OUTER_CURSOR_DEFAULTS.enabled
	local size = OUTER_CURSOR_DEFAULTS.size
	if db then
		if db.outerCursorEnabled ~= nil then
			enabled = db.outerCursorEnabled == 1 or db.outerCursorEnabled == true
		end
		size = tonumber(db.outerCursorSize) or size
	end
	size = math.max(8, math.min(128, size))
	return enabled, size
end

local function GetOuterCursorMaxRadius(size)
	local db = GetWheelDB()
	local slicesRadius = SLICE_OUTER_RADIUS
	local halfSize = size * 0.5
	local edgePadding = halfSize
	if db and db.outerCursorEdgePadding ~= nil then
		edgePadding = tonumber(db.outerCursorEdgePadding) or edgePadding
	end
	edgePadding = math.max(0, math.min(200, edgePadding))

	local safePadding = OUTER_CURSOR_DEFAULTS.safePadding
	if db and db.outerCursorSafePadding ~= nil then
		safePadding = tonumber(db.outerCursorSafePadding) or safePadding
	end
	safePadding = math.max(0, math.min(40, safePadding))

	local maxRadius = (slicesRadius - edgePadding - safePadding) * OUTER_CURSOR_RADIUS_SCALE
	if db then
		if db.outerCursorMaxRadius ~= nil then
			local customMax = tonumber(db.outerCursorMaxRadius)
			if customMax and customMax > 0 then
				maxRadius = customMax
			end
		elseif db.outerCursorRadius ~= nil then
			local legacy = tonumber(db.outerCursorRadius)
			if legacy and legacy > 0 then
				maxRadius = legacy
			end
		end
	end

	maxRadius = math.max(0, math.min(slicesRadius, maxRadius))
	return maxRadius
end

local function InitVirtualCursor()
	local debugCenterX, debugCenterY = GetDebugCircleGeometry()
	State.virtualWheelX = debugCenterX
	State.virtualWheelY = debugCenterY
	local mouseX, mouseY = GetCursorPosition()
	State.lastMouseX = mouseX
	State.lastMouseY = mouseY
	State.skipVirtualCursorDelta = true
end

local function ResetVirtualCursor()
	State.virtualWheelX = nil
	State.virtualWheelY = nil
	State.lastMouseX = nil
	State.lastMouseY = nil
	State.skipVirtualCursorDelta = false
end

local function UpdateVirtualCursor()
	if not State.isOpen or not State.wheel then
		return
	end
	if State.virtualWheelX == nil or State.virtualWheelY == nil then
		InitVirtualCursor()
		return
	end

	local uiScale = UIParent:GetEffectiveScale()
	local mouseX, mouseY = GetCursorPosition()
	if State.lastMouseX == nil or State.lastMouseY == nil then
		State.lastMouseX = mouseX
		State.lastMouseY = mouseY
		return
	end

	if State.skipVirtualCursorDelta then
		State.lastMouseX = mouseX
		State.lastMouseY = mouseY
		State.skipVirtualCursorDelta = false
		return
	end

	local deltaX = (mouseX - State.lastMouseX) / uiScale
	local deltaY = (mouseY - State.lastMouseY) / uiScale
	State.virtualWheelX = State.virtualWheelX + deltaX
	State.virtualWheelY = State.virtualWheelY + deltaY
	State.lastMouseX = mouseX
	State.lastMouseY = mouseY

	local debugCenterX, debugCenterY = GetDebugCircleGeometry()
	local dx = State.virtualWheelX - debugCenterX
	local dy = State.virtualWheelY - debugCenterY
	local distSq = (dx * dx) + (dy * dy)
	if distSq > 0 then
		local _, size = GetOuterCursorSettings()
		local maxRadius = GetOuterCursorMaxRadius(size)
		local maxRadiusSq = maxRadius * maxRadius
		if distSq > maxRadiusSq then
			local dist = math.sqrt(distSq)
			dx = (dx / dist) * maxRadius
			dy = (dy / dist) * maxRadius
			State.virtualWheelX = debugCenterX + dx
			State.virtualWheelY = debugCenterY + dy
		end
	end
end

local function IsCursorInInnerDeadZone()
	local dx, dy = GetCursorOffsetFromDebugCircle()
	if not dx then
		return true
	end
	local distSq = (dx * dx) + (dy * dy)
	local innerDeadRadius = GetInnerDeadRadius()
	return distSq <= (innerDeadRadius * innerDeadRadius)
end

local function ShowSystemCursor()
	if IsAlwaysShow() then
		return
	end
	if not State.systemCursorHidden then
		return
	end
	State.systemCursorHidden = false
	SetCursor(nil)
end

local function HideSystemCursor()
	if IsAlwaysShow() then
		return
	end
	if State.systemCursorHidden then
		return
	end
	State.systemCursorHidden = true
	SetCursor(CURSOR_HIDDEN_TEXTURE)
end

local function EnsureCursorSafetyHooks()
	if State.cursorSafetyFrame then
		return
	end
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function()
		if not State.isOpen then
			ShowSystemCursor()
		end
	end)
	State.cursorSafetyFrame = frame
end

local function UpdateCenterCursor()
	local box = State.centerCursorBox
	local wheel = State.wheel
	if not box or not wheel or not State.isOpen then
		return
	end

	local mx, my = GetWheelCursorOffset()
	if not mx then
		return
	end

	local debugCenterX, debugCenterY, debugRadius = GetDebugCircleGeometry()
	local movementRadius = debugRadius - (CENTER_CURSOR_SIZE * 0.5)
	if movementRadius < 0 then
		movementRadius = 0
	end

	local dx = mx - debugCenterX
	local dy = my - debugCenterY
	local distSq = (dx * dx) + (dy * dy)
	local maxDistSq = movementRadius * movementRadius
	if distSq > maxDistSq and distSq > 0 then
		local dist = math.sqrt(distSq)
		dx = (dx / dist) * movementRadius
		dy = (dy / dist) * movementRadius
	end

	box:ClearAllPoints()
	box:SetPoint("CENTER", wheel, "CENTER", debugCenterX + dx, debugCenterY + dy)
end

local function UpdateOuterCursor()
	local box = State.outerCursorBox
	local wheel = State.wheel
	if not box or not wheel or not State.isOpen then
		return
	end

	local dx, dy = GetCursorOffsetFromDebugCircle()
	if not dx then
		return
	end

	local debugCenterX, debugCenterY = GetDebugCircleGeometry()
	box:ClearAllPoints()
	box:SetPoint("CENTER", wheel, "CENTER", debugCenterX + dx, debugCenterY + dy)
end

local function UpdateWheelCursors()
	if not State.isOpen then
		return
	end

	if State.systemCursorHidden and SetCursor then
		SetCursor(CURSOR_HIDDEN_TEXTURE)
	end

	local centerBox = State.centerCursorBox
	local outerBox = State.outerCursorBox
	if not centerBox or not outerBox then
		return
	end

	if IsCursorInInnerDeadZone() then
		centerBox:Show()
		outerBox:Hide()
		UpdateCenterCursor()
	else
		centerBox:Hide()
		local outerEnabled = select(1, GetOuterCursorSettings())
		if outerEnabled then
			outerBox:Show()
			UpdateOuterCursor()
		else
			outerBox:Hide()
		end
	end
end

local function HideWheelCursors()
	if State.centerCursorBox then
		State.centerCursorBox:Hide()
	end
	if State.outerCursorBox then
		State.outerCursorBox:Hide()
	end
end

local function GetSliceIndexFromCursor()
	local dx, dy = GetCursorOffsetFromDebugCircle()
	if not dx then
		return nil
	end

	local distSq = (dx * dx) + (dy * dy)
	local innerDeadRadius = GetInnerDeadRadius()
	if distSq <= (innerDeadRadius * innerDeadRadius) then
		return nil
	end

	-- 0° = top, increases clockwise (matches SetRotation(-(i-1)*45))
	local angleFromEast = math.deg(atan2(dy, dx))
	local fromTopCW = NormalizeDegrees(90 - angleFromEast)
	local idx = (floor((fromTopCW + SLICE_HALF_ANGLE) / SLICE_SPAN_DEG) % SLICE_COUNT) + 1
	return idx
end

local function SetSliceSubLevel(slice, subLevel)
	if slice.texture.SetDrawLayer then
		slice.texture:SetDrawLayer("BACKGROUND", subLevel)
		slice.subLevel = subLevel
	end
end

local UpdateArrow

local function UpdateSliceHover()
	if not State.isOpen or not State.slices[1] then
		return
	end
	-- Sector from cursor angle vs debug-circle center; not from slice texture hit-test.
	local idx = GetSliceIndexFromCursor()
	if idx == State.hoveredSlice then
		return
	end
	SetPhraseTargetsForSelection(idx)
	State.hoveredSlice = idx
	for i, slice in ipairs(State.slices) do
		local hovered = idx and (i == idx)
		SetSliceSubLevel(slice, hovered and 7 or (i - 1))
		ApplySliceColor(slice.texture, i, hovered)
	end
	UpdateArrow()
end

local function ResetCirclePointer()
	if State.circlePointerTexture then
		State.circlePointerTexture:SetRotation(0)
	end
end

local function UpdateCirclePointerRotation()
	local tex = State.circlePointerTexture
	local box = State.circlePointerBox
	if not tex or not box or not State.isOpen then
		return
	end
	local dx, dy = GetCursorOffsetFromDebugCircle()
	if not dx or (dx == 0 and dy == 0) then
		return
	end
	-- Texture default points up; match slice rotation convention (0° = top, CW positive).
	local angleFromEast = math.deg(atan2(dy, dx))
	local fromTopCW = NormalizeDegrees(90 - angleFromEast)
	tex:SetRotation(rad(-fromTopCW))
end

local function ResetArrow()
	if State.arrowBox then
		State.arrowBox:Hide()
	end
	if State.arrowTexture then
		State.arrowTexture:SetRotation(0)
	end
end

local function ResetSliceHover()
	State.hoveredSlice = nil
	ResetCirclePointer()
	ResetArrow()
	for i, slice in ipairs(State.slices) do
		SetSliceSubLevel(slice, i - 1)
		ApplySliceColor(slice.texture, i, false)
	end
	ResetPhraseAnimation()
end

local function PrepareWheelOpen()
	ResetSliceHover()
	ResetVirtualCursor()
	InitVirtualCursor()
end

local function BuildPhrases(parent, wheel)
	State.phrases = {}
	for i = 1, SLICE_COUNT do
		local phraseFrame = CreateFrame("Frame", "ChatWheelPhrase" .. i, parent)
		DisableFrameHitTest(phraseFrame)
		local labelBox = CreateFrame("Frame", nil, phraseFrame)
		DisableFrameHitTest(labelBox)
		local fontString = labelBox:CreateFontString(nil, "OVERLAY")
		fontString:SetWordWrap(true)
		State.phrases[i] = {
			frame = phraseFrame,
			labelBox = labelBox,
			fontString = fontString,
			index = i,
			currentScale = 1,
			targetScale = 1,
			currentColor = { 1, 1, 1 },
			targetColor = { 1, 1, 1 },
		}
	end
	LayoutPhrasePositions()
end

local function BuildSliceBackgrounds(parent)
	State.slices = {}
	for i = 1, SLICE_COUNT do
		-- Dota: each SliceBackground is 100%×100% (600×600), same z-order in container
		local tex = parent:CreateTexture(nil, "BACKGROUND", nil, i - 1)
		tex:SetTexture(SLICE_SECTOR_TEXTURE)
		tex:SetSize(SLICES_SIZE, SLICES_SIZE)
		tex:SetPoint("CENTER", parent, "CENTER", 0, 0)
		tex:SetRotation(rad(-(i - 1) * 45))
		tex:SetAlpha(1)
		if tex.SetBlendMode then
			tex:SetBlendMode("BLEND")
		end
		ApplySliceColor(tex, i, false)

		State.slices[i] = {
			texture = tex,
			index = i,
			subLevel = i - 1,
		}
	end
end

local function GetCircleBG2Settings()
	local db = GetWheelDB()
	if not db then
		return CIRCLE_BG2_DEFAULTS.x, CIRCLE_BG2_DEFAULTS.y, CIRCLE_BG2_DEFAULTS.width, CIRCLE_BG2_DEFAULTS.height
	end
	local x = tonumber(db.circleBG2X) or CIRCLE_BG2_DEFAULTS.x
	local y = tonumber(db.circleBG2Y) or CIRCLE_BG2_DEFAULTS.y
	local w = tonumber(db.circleBG2Width) or CIRCLE_BG2_DEFAULTS.width
	local h = tonumber(db.circleBG2Height) or CIRCLE_BG2_DEFAULTS.height
	w = math.max(1, math.min(800, w))
	h = math.max(1, math.min(800, h))
	x = math.max(-400, math.min(400, x))
	y = math.max(-400, math.min(400, y))
	return x, y, w, h
end

local function GetCirclePNGSettings()
	local db = GetWheelDB()
	if not db then
		return CIRCLE_PNG_DEFAULTS.x, CIRCLE_PNG_DEFAULTS.y, CIRCLE_PNG_DEFAULTS.width, CIRCLE_PNG_DEFAULTS.height
	end
	local x = tonumber(db.circlePNGX) or CIRCLE_PNG_DEFAULTS.x
	local y = tonumber(db.circlePNGY) or CIRCLE_PNG_DEFAULTS.y
	local w = tonumber(db.circlePNGWidth) or CIRCLE_PNG_DEFAULTS.width
	local h = tonumber(db.circlePNGHeight) or CIRCLE_PNG_DEFAULTS.height
	w = math.max(1, math.min(800, w))
	h = math.max(1, math.min(800, h))
	x = math.max(-400, math.min(400, x))
	y = math.max(-400, math.min(400, y))
	return x, y, w, h
end

local function GetCirclePointerSettings()
	local db = GetWheelDB()
	if not db then
		return CIRCLE_POINTER_DEFAULTS.x, CIRCLE_POINTER_DEFAULTS.y,
			CIRCLE_POINTER_DEFAULTS.width, CIRCLE_POINTER_DEFAULTS.height
	end
	local x = tonumber(db.circlePointerX) or CIRCLE_POINTER_DEFAULTS.x
	local y = tonumber(db.circlePointerY) or CIRCLE_POINTER_DEFAULTS.y
	local w = tonumber(db.circlePointerWidth) or CIRCLE_POINTER_DEFAULTS.width
	local h = tonumber(db.circlePointerHeight) or CIRCLE_POINTER_DEFAULTS.height
	w = math.max(1, math.min(800, w))
	h = math.max(1, math.min(800, h))
	x = math.max(-400, math.min(400, x))
	y = math.max(-400, math.min(400, y))
	return x, y, w, h
end

local function GetArrowSettings()
	local db = GetWheelDB()
	if not db then
		return ARROW_DEFAULTS.enabled, ARROW_DEFAULTS.size, ARROW_DEFAULTS.gap,
			ARROW_DEFAULTS.anchorOffset, ARROW_DEFAULTS.alpha
	end
	local enabled = db.arrowEnabled
	if enabled == nil then
		enabled = ARROW_DEFAULTS.enabled
	else
		enabled = enabled == 1 or enabled == true
	end
	local size = tonumber(db.arrowSize) or ARROW_DEFAULTS.size
	local gap = tonumber(db.arrowGap) or ARROW_DEFAULTS.gap
	local anchorOffset = tonumber(db.arrowAnchorOffset) or ARROW_DEFAULTS.anchorOffset
	local alpha = tonumber(db.arrowAlpha) or ARROW_DEFAULTS.alpha
	size = math.max(1, math.min(200, size))
	gap = math.max(0, math.min(50, gap))
	anchorOffset = math.max(0, math.min(30, anchorOffset))
	alpha = math.max(0, math.min(1, alpha))
	return enabled, size, gap, anchorOffset, alpha
end

local function GetArrowCircleGeometry()
	local radius = ARROW_CIRCLE_SIZE * 0.5
	return ARROW_CIRCLE_X, ARROW_CIRCLE_Y, radius
end

local function GetArrowSectorAngleDeg(idx)
	if not idx or idx < 1 or idx > SLICE_COUNT then
		return 0
	end
	local db = GetWheelDB()
	local default = ARROW_SECTOR_ANGLE_DEFAULTS[idx]
	if not db then
		return default
	end
	local key = "arrowAngle" .. idx
	local value = tonumber(db[key])
	if value == nil then
		return default
	end
	return math.max(-180, math.min(180, value))
end

local function GetArrowSectorAngleRad(idx)
	return rad(GetArrowSectorAngleDeg(idx))
end

UpdateArrow = function()
	local box = State.arrowBox
	local tex = State.arrowTexture
	if not box or not tex or not State.wheel or not State.isOpen then
		return
	end

	local arrowEnabled, size, gap, anchorOffset, alpha = GetArrowSettings()
	if not arrowEnabled then
		box:Hide()
		return
	end

	local idx = State.hoveredSlice
	if not idx then
		box:Hide()
		return
	end

	local circleCenterX, circleCenterY, circleRadius = GetArrowCircleGeometry()
	local angle = GetArrowSectorAngleRad(idx)
	local arrowDistance = circleRadius + gap + anchorOffset
	local arrowX = circleCenterX + (math.cos(angle) * arrowDistance)
	local arrowY = circleCenterY + (math.sin(angle) * arrowDistance)

	box:SetSize(size, size)
	box:ClearAllPoints()
	box:SetPoint("CENTER", State.wheel, "CENTER", arrowX, arrowY)
	tex:SetRotation(angle)
	tex:SetAlpha(alpha)
	box:Show()
end

local function IsDebugBoxEnabled()
	local db = GetWheelDB()
	return db and (db.debugBoxEnabled == 1 or db.debugBoxEnabled == true)
end

local function SyncWheelVisibilityForDebug()
	if not State.wheel then
		return
	end
	if IsDebugBoxEnabled() or IsAlwaysShow() or State.isOpen then
		State.wheel:Show()
	elseif not State.isBindingDown then
		State.wheel:Hide()
	end
end

local function LayoutDebugBoxLines(box, w, h)
	local lines = State.debugBoxLines
	if not lines then
		return
	end
	local t = DEBUG_LINE_THICKNESS
	local r, g, b, a = DEBUG_LINE_COLOR[1], DEBUG_LINE_COLOR[2], DEBUG_LINE_COLOR[3], DEBUG_LINE_COLOR[4]

	lines.top:ClearAllPoints()
	lines.top:SetHeight(t)
	lines.top:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	lines.top:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	lines.top:SetVertexColor(r, g, b, a)

	lines.bottom:ClearAllPoints()
	lines.bottom:SetHeight(t)
	lines.bottom:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	lines.bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	lines.bottom:SetVertexColor(r, g, b, a)

	lines.left:ClearAllPoints()
	lines.left:SetWidth(t)
	lines.left:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	lines.left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	lines.left:SetVertexColor(r, g, b, a)

	lines.right:ClearAllPoints()
	lines.right:SetWidth(t)
	lines.right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	lines.right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	lines.right:SetVertexColor(r, g, b, a)
end

local function LayoutDebugCircle(box, w, h)
	local circle = State.debugCircleTexture
	if not circle then
		return
	end
	local circleSize = math.min(w, h)
	local r, g, b, a = DEBUG_LINE_COLOR[1], DEBUG_LINE_COLOR[2], DEBUG_LINE_COLOR[3], DEBUG_LINE_COLOR[4]
	circle:SetSize(circleSize, circleSize)
	circle:ClearAllPoints()
	circle:SetPoint("CENTER", box, "CENTER", 0, 0)
	circle:SetVertexColor(r, g, b, a)
end

local function BuildDebugBox(wheel, baseLevel)
	if State.debugBox then
		return
	end

	local box = CreateFrame("Frame", "ChatWheelDebugBox", wheel)
	box:SetSize(DEBUG_BOX_DEFAULTS.width, DEBUG_BOX_DEFAULTS.height)
	box:SetPoint("CENTER", wheel, "CENTER", 0, 0)
	box:SetFrameLevel(baseLevel + 20)
	DisableFrameHitTest(box)
	box:Hide()
	State.debugBox = box

	local function CreateLine(subLevel)
		local line = box:CreateTexture(nil, "OVERLAY", nil, subLevel)
		line:SetTexture(DEBUG_LINE_TEXTURE)
		if line.SetBlendMode then
			line:SetBlendMode("BLEND")
		end
		return line
	end

	State.debugBoxLines = {
		top = CreateLine(1),
		bottom = CreateLine(2),
		left = CreateLine(3),
		right = CreateLine(4),
	}

	local circle = box:CreateTexture("DebugCircleTexture", "OVERLAY", nil, 10)
	circle:SetTexture(DEBUG_CIRCLE_TEXTURE)
	if circle.SetBlendMode then
		circle:SetBlendMode("BLEND")
	end
	State.debugCircleTexture = circle

	LayoutDebugBoxLines(box, DEBUG_BOX_DEFAULTS.width, DEBUG_BOX_DEFAULTS.height)
	LayoutDebugCircle(box, DEBUG_BOX_DEFAULTS.width, DEBUG_BOX_DEFAULTS.height)
end

function ChatWheel.ApplyCircleBG2()
	BuildFrames()
	if not State.circleBG2Box or not State.wheel then
		return
	end

	local x, y, w, h = GetCircleBG2Settings()
	State.circleBG2Box:SetSize(w, h)
	State.circleBG2Box:ClearAllPoints()
	State.circleBG2Box:SetPoint("CENTER", State.wheel, "CENTER", x, y)
end

function ChatWheel.ApplyCirclePNG()
	BuildFrames()
	if not State.circlePNGBox or not State.wheel then
		return
	end

	local x, y, w, h = GetCirclePNGSettings()
	State.circlePNGBox:SetSize(w, h)
	State.circlePNGBox:ClearAllPoints()
	State.circlePNGBox:SetPoint("CENTER", State.wheel, "CENTER", x, y)
end

function ChatWheel.ApplyCirclePointer()
	BuildFrames()
	if not State.circlePointerBox or not State.wheel then
		return
	end

	local x, y, w, h = GetCirclePointerSettings()
	State.circlePointerBox:SetSize(w, h)
	State.circlePointerBox:ClearAllPoints()
	State.circlePointerBox:SetPoint("CENTER", State.wheel, "CENTER", x, y)
end

function ChatWheel.ApplyArrow()
	BuildFrames()
	if not State.arrowBox then
		return
	end
	local _, size, _, _, alpha = GetArrowSettings()
	State.arrowBox:SetSize(size, size)
	if State.arrowTexture then
		State.arrowTexture:SetAlpha(alpha)
	end
	UpdateArrow()
end

function ChatWheel.ApplyOuterCursor()
	BuildFrames()
	if not State.outerCursorBox then
		return
	end
	local _, size = GetOuterCursorSettings()
	State.outerCursorBox:SetSize(size, size)
end

function ChatWheel.ApplyPhrases()
	BuildFrames()
	LayoutPhrases()
end

function ChatWheel.ApplyDebugBox()
	BuildFrames()
	if not State.debugBox or not State.wheel then
		return
	end

	local enabled, x, y, w, h = GetDebugBoxSettings()
	State.debugBox:SetSize(w, h)
	State.debugBox:ClearAllPoints()
	State.debugBox:SetPoint("CENTER", State.wheel, "CENTER", x, y)
	LayoutDebugBoxLines(State.debugBox, w, h)
	LayoutDebugCircle(State.debugBox, w, h)

	if enabled then
		SyncWheelVisibilityForDebug()
		State.debugBox:Show()
	else
		State.debugBox:Hide()
		SyncWheelVisibilityForDebug()
	end
	LayoutPhrasePositions()
end

BuildFrames = function()
	if State.wheel then
		return
	end

	local wheel = CreateFrame("Frame", "SarychUIChatWheelFrame", UIParent)
	wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
	wheel:SetPoint("CENTER")
	wheel:SetFrameStrata("DIALOG")
	wheel:EnableMouse(false)
	wheel:Hide()
	State.wheel = wheel
	local baseLevel = wheel:GetFrameLevel()

	local slicesBox = CreateFrame("Frame", nil, wheel)
	slicesBox:SetSize(SLICES_SIZE, SLICES_SIZE)
	slicesBox:SetPoint("CENTER", wheel, "CENTER", 0, 0)
	slicesBox:SetFrameLevel(baseLevel + 1)
	DisableFrameHitTest(slicesBox)
	State.slicesBox = slicesBox

	local slicesBackgroundContainer = CreateFrame("Frame", nil, slicesBox)
	slicesBackgroundContainer:SetAllPoints(slicesBox)
	slicesBackgroundContainer:SetFrameLevel(baseLevel + 1)
	DisableFrameHitTest(slicesBackgroundContainer)
	State.slicesBackgroundContainer = slicesBackgroundContainer
	BuildSliceBackgrounds(slicesBackgroundContainer)

	wheel:SetScript("OnUpdate", function(_, elapsed)
		if State.isOpen then
			UpdateVirtualCursor()
			UpdateSliceHover()
			UpdateCirclePointerRotation()
			UpdateWheelCursors()
			UpdatePhraseAnimation(elapsed)
		end
	end)

	local plateBox = CreateFrame("Frame", nil, wheel)
	plateBox:SetSize(PLATE_SIZE, PLATE_SIZE)
	plateBox:SetPoint("CENTER", wheel, "CENTER", 0, 0)
	plateBox:SetFrameLevel(baseLevel + 5)
	DisableFrameHitTest(plateBox)
	State.plateBox = plateBox

	local plate = plateBox:CreateTexture(nil, "ARTWORK", nil, 0)
	plate:SetTexture(PLATE_TEXTURE)
	plate:SetSize(PLATE_SIZE, PLATE_SIZE)
	plate:SetPoint("CENTER", plateBox, "CENTER", 0, 0)
	State.backgroundPlate = plate

	local circleBG2Box = CreateFrame("Frame", "ChatWheelCircleBG2Box", wheel)
	circleBG2Box:SetFrameLevel(baseLevel + 8)
	DisableFrameHitTest(circleBG2Box)
	State.circleBG2Box = circleBG2Box

	local circleBG2 = circleBG2Box:CreateTexture("circle_bg2_png", "ARTWORK", nil, 0)
	circleBG2:SetTexture(CIRCLE_BG2_TEXTURE)
	circleBG2:SetAllPoints(circleBG2Box)
	State.circleBG2Texture = circleBG2

	local circlePNGBox = CreateFrame("Frame", "ChatWheelCirclePNGBox", wheel)
	circlePNGBox:SetFrameLevel(baseLevel + 11)
	DisableFrameHitTest(circlePNGBox)
	State.circlePNGBox = circlePNGBox

	local circlePNG = circlePNGBox:CreateTexture("circle_png", "ARTWORK", nil, 0)
	circlePNG:SetTexture(CIRCLE_PNG_TEXTURE)
	circlePNG:SetAllPoints(circlePNGBox)
	State.circlePNGTexture = circlePNG

	local circlePointerBox = CreateFrame("Frame", "ChatWheelCirclePointerBox", wheel)
	circlePointerBox:SetFrameLevel(baseLevel + 14)
	DisableFrameHitTest(circlePointerBox)
	State.circlePointerBox = circlePointerBox

	local circlePointer = circlePointerBox:CreateTexture("circle_pointer_png", "ARTWORK", nil, 0)
	circlePointer:SetTexture(CIRCLE_POINTER_TEXTURE)
	circlePointer:SetAllPoints(circlePointerBox)
	circlePointer:SetAlpha(CIRCLE_POINTER_ALPHA)
	if circlePointer.SetBlendMode then
		circlePointer:SetBlendMode("BLEND")
	end
	State.circlePointerTexture = circlePointer

	local arrowBox = CreateFrame("Frame", "ChatWheelArrowBox", wheel)
	arrowBox:SetFrameLevel(baseLevel + 17)
	DisableFrameHitTest(arrowBox)
	arrowBox:Hide()
	State.arrowBox = arrowBox

	local arrow = arrowBox:CreateTexture("arrow_psd", "ARTWORK", nil, 0)
	arrow:SetTexture(ARROW_PSD_TEXTURE)
	arrow:SetAllPoints(arrowBox)
	arrow:SetAlpha(1)
	if arrow.SetBlendMode then
		arrow:SetBlendMode("BLEND")
	end
	State.arrowTexture = arrow

	local outerCursorBox = CreateFrame("Frame", "ChatWheelOuterCursorBox", wheel)
	outerCursorBox:SetSize(OUTER_CURSOR_DEFAULTS.size, OUTER_CURSOR_DEFAULTS.size)
	outerCursorBox:SetFrameLevel(baseLevel + 17)
	DisableFrameHitTest(outerCursorBox)
	outerCursorBox:Hide()
	State.outerCursorBox = outerCursorBox

	local outerCursor = outerCursorBox:CreateTexture("icon_add_png", "ARTWORK", nil, 0)
	outerCursor:SetTexture(OUTER_CURSOR_TEXTURE)
	outerCursor:SetAllPoints(outerCursorBox)
	if outerCursor.SetBlendMode then
		outerCursor:SetBlendMode("BLEND")
	end
	State.outerCursorTexture = outerCursor

	local centerCursorBox = CreateFrame("Frame", "ChatWheelCenterCursorBox", wheel)
	centerCursorBox:SetSize(CENTER_CURSOR_SIZE, CENTER_CURSOR_SIZE)
	centerCursorBox:SetFrameLevel(baseLevel + 18)
	DisableFrameHitTest(centerCursorBox)
	centerCursorBox:Hide()
	State.centerCursorBox = centerCursorBox

	local centerCursor = centerCursorBox:CreateTexture("center_cursor_png", "ARTWORK", nil, 0)
	centerCursor:SetTexture(CENTER_CURSOR_TEXTURE)
	centerCursor:SetAllPoints(centerCursorBox)
	if centerCursor.SetBlendMode then
		centerCursor:SetBlendMode("BLEND")
	end
	State.centerCursorTexture = centerCursor

	local phrasesContainer = CreateFrame("Frame", "ChatWheelPhrasesContainer", wheel)
	phrasesContainer:SetSize(WHEEL_SIZE, WHEEL_SIZE)
	phrasesContainer:SetPoint("CENTER", wheel, "CENTER", 0, 0)
	phrasesContainer:SetFrameLevel(baseLevel + 19)
	DisableFrameHitTest(phrasesContainer)
	State.phrasesContainer = phrasesContainer
	BuildPhrases(phrasesContainer, wheel)

	BuildDebugBox(wheel, baseLevel)
	ChatWheel.ApplyCircleBG2()
	ChatWheel.ApplyCirclePNG()
	ChatWheel.ApplyCirclePointer()
	ChatWheel.ApplyArrow()
	ChatWheel.ApplyOuterCursor()
	ChatWheel.ApplyPhrases()
	ChatWheel.ApplyDebugBox()
end

function ChatWheel.Open()
	if not State.enabled or State.isOpen or not State.wheel then
		return
	end
	State.isOpen = true
	State.wheel:Show()
	SyncWheelVisibilityForDebug()
	ChatWheel.ApplyCircleBG2()
	ChatWheel.ApplyCirclePNG()
	ChatWheel.ApplyCirclePointer()
	ChatWheel.ApplyArrow()
	ChatWheel.ApplyOuterCursor()
	HideSystemCursor()
	PrepareWheelOpen()
	RefreshPhraseChannelColors()
	UpdateWheelCursors()
end

function ChatWheel.Close()
	if IsAlwaysShow() then
		return
	end
	if not State.isOpen then
		return
	end
	State.isOpen = false
	State.isBindingDown = false
	ResetSliceHover()
	ResetVirtualCursor()
	HideWheelCursors()
	ShowSystemCursor()
	if State.wheel then
		State.wheel:Hide()
	end
end

local function ForceCloseWheel()
	if not State.isOpen then
		return
	end
	State.isOpen = false
	State.isBindingDown = false
	ResetSliceHover()
	ResetVirtualCursor()
	HideWheelCursors()
	ShowSystemCursor()
	if State.wheel then
		State.wheel:Hide()
	end
end

function ChatWheel.OnBindingPress()
	if not State.enabled or State.isBindingDown then
		return
	end
	State.isBindingDown = true
	ChatWheel.Open()
	if State.keyCapture and State.binding and not State.binding.mouseButton then
		State.keyCapture:EnableKeyboard(true)
		State.keyCapture:SetFocus()
	end
end

function ChatWheel.OnBindingRelease()
	if not State.isBindingDown then
		return
	end
	local selectedSector = State.hoveredSlice
	State.isBindingDown = false
	if State.keyCapture and State.keyCapture:HasFocus() then
		State.keyCapture:ClearFocus()
	end
	if selectedSector then
		SendSelectedPhrase(selectedSector)
	end
	if not IsAlwaysShow() then
		ChatWheel.Close()
	end
end

local function HookMouseState()
	if State.mouseHooked then
		return
	end
	State.mouseHooked = true
	WorldFrame:HookScript("OnMouseDown", function(_, button)
		State.mouseDown[button] = true
	end)
	WorldFrame:HookScript("OnMouseUp", function(_, button)
		State.mouseDown[button] = false
	end)
end

local function SafeSaveBindings()
	-- GetCurrentBindingSet() can return 0 during early login; SaveBindings only accepts 1|2.
	-- Note: in Lua, `0 or 1` is 0 (0 is truthy), so never use `set or 1`.
	if not SaveBindings or not GetCurrentBindingSet then
		return
	end
	local set = GetCurrentBindingSet()
	if set == 1 or set == 2 then
		SaveBindings(set)
		return
	end
	if State._pendingSaveBindings then
		return
	end
	State._pendingSaveBindings = true
	local waiter = CreateFrame("Frame")
	waiter:RegisterEvent("PLAYER_LOGIN")
	waiter:RegisterEvent("UPDATE_BINDINGS")
	waiter:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		self:SetScript("OnEvent", nil)
		State._pendingSaveBindings = nil
		local ready = GetCurrentBindingSet and GetCurrentBindingSet()
		if SaveBindings and (ready == 1 or ready == 2) then
			SaveBindings(ready)
		end
	end)
end

local function ClearBindingClick()
	if State.savedBindingKey and State.savedBindingAction ~= nil then
		if State.savedBindingAction == "" or State.savedBindingAction == "NONE" then
			SetBinding(State.savedBindingKey, nil)
		else
			SetBinding(State.savedBindingKey, State.savedBindingAction)
		end
		State.savedBindingKey = nil
		State.savedBindingAction = nil
	end
end

local function EnsureHoldButton()
	if State.holdButton then
		return
	end
	local btn = CreateFrame("Button", "SarychUIChatWheelHoldBtn", UIParent)
	btn:SetSize(1, 1)
	btn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -20, -20)
	btn:EnableMouse(true)
	btn:RegisterForClicks("AnyDown", "AnyUp")
	btn:SetScript("OnMouseDown", ChatWheel.OnBindingPress)
	btn:SetScript("OnMouseUp", ChatWheel.OnBindingRelease)
	btn:SetScript("OnClick", function(_, _, isDown)
		if isDown then
			ChatWheel.OnBindingPress()
		else
			ChatWheel.OnBindingRelease()
		end
	end)
	State.holdButton = btn
end

local function EnsureKeyCapture()
	if State.keyCapture then
		return
	end
	local eb = CreateFrame("EditBox", "SarychUIChatWheelKeyCapture", UIParent)
	eb:SetAutoFocus(false)
	eb:SetSize(1, 1)
	eb:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -10, -10)
	eb:Hide()
	eb:SetScript("OnKeyUp", function(_, key)
		if not State.isBindingDown or not State.binding or State.binding.mouseButton then
			return
		end
		if NormalizeKey(key) == State.binding.key then
			ChatWheel.OnBindingRelease()
		end
	end)
	eb:SetScript("OnEditFocusLost", function(self)
		if State.isBindingDown and State.binding and not State.binding.mouseButton then
			self:SetFocus()
		end
	end)
	State.keyCapture = eb
end

local function ApplyBindingClick(binding)
	ClearBindingClick()
	if not binding or binding.mouseButton then
		return
	end
	EnsureHoldButton()
	EnsureKeyCapture()
	State.savedBindingKey = binding.raw
	State.savedBindingAction = GetBindingAction(binding.raw) or ""
	SetBindingClick(binding.raw, "SarychUIChatWheelHoldBtn", "LeftButton")
	SafeSaveBindings()
end

local function EnsureListener()
	if State.listener then
		return
	end
	local listener = CreateFrame("Frame", nil, UIParent)
	listener:Hide()
	listener:SetScript("OnUpdate", function()
		if not State.enabled or not State.binding or not State.binding.mouseButton then
			return
		end
		local down = IsMouseBindingHeld(State.binding)
		if down and not State.isBindingDown then
			ChatWheel.OnBindingPress()
		elseif not down and State.isBindingDown then
			ChatWheel.OnBindingRelease()
		end
	end)
	State.listener = listener
end

function ChatWheel.ApplySettings()
	BuildFrames()
	EnsureCursorSafetyHooks()
	EnsureListener()
	EnsureHoldButton()
	EnsureKeyCapture()
	HookMouseState()

	local db = GetWheelDB()
	local alwaysShow = IsAlwaysShow()
	State.binding = ParseBinding(db and db.key or nil)
	State.enabled = IsChatModuleEnabled()
		and db
		and (db.enabled == 1 or db.enabled == true)
		and (State.binding ~= nil or alwaysShow)

	ClearBindingClick()
	if alwaysShow and State.enabled then
		ChatWheel.Open()
	elseif not State.isBindingDown then
		ForceCloseWheel()
	end

	if State.enabled and State.binding then
		if State.binding.mouseButton then
			State.listener:Show()
		else
			ApplyBindingClick(State.binding)
			State.listener:Hide()
		end
	else
		if State.listener then
			State.listener:Hide()
		end
		ForceCloseWheel()
	end

	ChatWheel.ApplyCircleBG2()
	ChatWheel.ApplyCirclePNG()
	ChatWheel.ApplyCirclePointer()
	ChatWheel.ApplyArrow()
	ChatWheel.ApplyOuterCursor()
	ChatWheel.ApplyPhrases()
	ChatWheel.ApplyDebugBox()
end

function ChatWheel.Init()
	BuildFrames()
	EnsureCursorSafetyHooks()
	EnsurePhraseChannelEventFrame()
	EnsureListener()
	EnsureHoldButton()
	EnsureKeyCapture()
	HookMouseState()
end

ChatWheel.Init()

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" and addon == "SarychUI" then
		self:SetScript("OnUpdate", function(frame)
			frame:SetScript("OnUpdate", nil)
			ChatWheel.ApplySettings()
		end)
	elseif event == "PLAYER_LOGIN" then
		ChatWheel.ApplySettings()
	end
end)
