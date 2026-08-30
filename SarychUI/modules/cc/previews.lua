-- SarychUI «Перезарядка и таймеры» — options previews.
-- Layouts match Blizzard 3.3.5 FrameXML (CastingBarFrame / TargetSpellBar / LFDDungeonReadyDialog)
-- and SarychUI timer offsets from modules/tools/module.lua.

local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local type = type
local tonumber = tonumber
local tostring = tostring
local format = string.format
local floor = math.floor
local min, max = math.min, math.max
local tinsert = table.insert
local pcall = pcall
local next = next

SarychUI = SarychUI or {}

local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_NAME = "Friz Quadrata TT"
local SAMPLE_ICON_FLASH = "Interface\\Icons\\Spell_Holy_FlashHeal"
local SAMPLE_ICON_FIREBALL = "Interface\\Icons\\Spell_Fire_Fireball02"
local FLASH_OF_LIGHT = "Вспышка света"
local FIREBALL = "Огненный шар"
-- Glowing Twilight Scale (54589) for cooldown text preview buttons.
local COOLDOWN_PREVIEW_ITEM_ID = 54589
local COOLDOWN_PREVIEW_ICON = "Interface\\Icons\\INV_Misc_RubySanctum1"

local function ResolveCooldownPreviewIcon()
	if GetItemIcon then
		local path = GetItemIcon(COOLDOWN_PREVIEW_ITEM_ID)
		if path and path ~= "" then return path end
	end
	if GetItemInfo then
		local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(COOLDOWN_PREVIEW_ITEM_ID)
		if texture and texture ~= "" then return texture end
	end
	return COOLDOWN_PREVIEW_ICON
end


local function GetCcDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.cc
end

local function GetSetting(key, default)
	local db = GetCcDB()
	if db and db[key] ~= nil then return db[key] end
	return default
end

local function ResolveFontPath(fontNameOrPath)
	if type(fontNameOrPath) == "string" and fontNameOrPath:find("\\") then
		return fontNameOrPath
	end
	if SarychUI and SarychUI.Media and SarychUI.Media.GetFont then
		local path = SarychUI.Media.GetFont(fontNameOrPath or DEFAULT_FONT_NAME)
		if path and path ~= "" then return path end
	end
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM and fontNameOrPath then
		local path = LSM:Fetch("font", fontNameOrPath, true)
		if path and path ~= "" then return path end
	end
	return FALLBACK_FONT
end

local function ApplyPanelBg(host)
	local T = SarychUI.OptionsTheme
	if T and T.ApplyFlat then
		T:ApplyFlat(host, T.colors.panelBg or { 0.07, 0.07, 0.09, 0.97 }, T.colors.borderSoft)
	else
		local bg = host:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
	end
end

local function SafeSetFont(fs, path, size, flags)
	if not fs then return end
	local ok = pcall(fs.SetFont, fs, path or FALLBACK_FONT, size or 12, flags or "OUTLINE")
	if not ok then
		pcall(fs.SetFont, fs, FALLBACK_FONT, size or 12, flags or "OUTLINE")
	end
end

local function FormatCooldownPreview(seconds)
	local defaultColor = GetSetting("defaultColor", { 1, 1, 1, 1 })
	local fontSizeSmall = GetSetting("fontSizeSmall", 14)
	local fontSizeMedium = GetSetting("fontSizeMedium", 12)
	local fontSizeLarge = GetSetting("fontSizeLarge", 12)
	local locale = GetLocale and GetLocale() or "enUS"
	local daySuffix = (locale == "ruRU") and " д." or "d"
	local hourSuffix = (locale == "ruRU") and " ч." or "h"
	local minuteSuffix = (locale == "ruRU") and " м." or "m"

	if seconds >= 86400 then
		return format(" %d%s ", floor(seconds / 86400 + 0.5), daySuffix), defaultColor, fontSizeLarge
	elseif seconds >= 3600 then
		return format(" %d%s ", floor(seconds / 3600 + 0.5), hourSuffix), defaultColor, fontSizeLarge
	elseif seconds >= 600 then
		return format(" %d%s ", floor(seconds / 60 + 0.5), minuteSuffix), defaultColor, fontSizeLarge
	elseif seconds >= 60 then
		return format(" %d:%02d ", floor(seconds / 60), floor(seconds % 60)), defaultColor, fontSizeMedium
	elseif seconds >= 10 then
		return format(" %02d ", floor(seconds + 0.5)), defaultColor, fontSizeSmall
	else
		return format(" %d ", floor(seconds + 0.5)), defaultColor, fontSizeSmall
	end
end

local function TrackInstance(bucket, host)
	bucket._instances = bucket._instances or {}
	tinsert(bucket._instances, host)
end

local function IsOptionsSliderDragging()
	return SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging()
end

local function BindAnim(host, onUpdate)
	if SarychUI and SarychUI.BindOptionsPreviewAnim then
		SarychUI.BindOptionsPreviewAnim(host, onUpdate)
	else
		host:SetScript("OnUpdate", onUpdate)
	end
end

local function RefreshBucket(bucket, styleOnly)
	local alive = {}
	for _, inst in ipairs(bucket._instances or {}) do
		if inst and inst.GetParent and inst:GetParent() then
			tinsert(alive, inst)
			if styleOnly and inst.RefreshStyle then
				inst:RefreshStyle()
			elseif inst.Refresh then
				inst:Refresh()
			end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	bucket._instances = alive
end

local function ClearBucket(bucket)
	for _, inst in ipairs(bucket._instances or {}) do
		if inst then
			if inst.SetScript then
				inst:SetScript("OnUpdate", nil)
				inst:SetScript("OnShow", nil)
				inst:SetScript("OnSizeChanged", nil)
			end
			if inst.SetBackdrop then
				inst:SetBackdrop(nil)
			end
			if inst.Hide then inst:Hide() end
			if inst.ClearAllPoints then inst:ClearAllPoints() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	bucket._instances = {}
end

--------------------------------------------------------------------
-- 1) Cooldown text: 3 action buttons (<60s / 1–10m / >10m)
--------------------------------------------------------------------
SarychUI.CooldownTextPreview = SarychUI.CooldownTextPreview or {}
local CdPreview = SarychUI.CooldownTextPreview
CdPreview._instances = CdPreview._instances or {}
CdPreview._live = CdPreview._live or {}

function CdPreview:SetLiveValue(key, value)
	self._live[key] = value
	-- Style only — never restart SetCooldown on drag.
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, value)
	else
		RefreshBucket(self, true)
	end
end

function CdPreview:ClearLiveValue(key)
	if key then
		self._live[key] = nil
	else
		for k in pairs(self._live) do self._live[k] = nil end
	end
end

function CdPreview:RefreshAll()
	RefreshBucket(self, false)
end

function CdPreview:ClearStickyHosts()
	ClearBucket(self)
end

local function StartPreviewCooldown(btn, remain)
	if not btn or not btn._cooldown then return end
	remain = tonumber(remain) or 0
	if remain <= 0 then
		btn._cooldown:Hide()
		return
	end
	-- Mid-swipe look: duration a bit longer than remain so the circle is partially filled.
	local duration = remain * 1.35
	local start = GetTime() - (duration - remain)
	btn._cooldown:Show()
	btn._cooldown:SetCooldown(start, duration)
	btn._cdEnds = start + duration
end

local function MakeActionButton(parent)
	local btn = CreateFrame("Frame", nil, parent)
	btn:SetSize(44, 44)
	btn:EnableMouse(false)

	local slot = btn:CreateTexture(nil, "BACKGROUND")
	slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	slot:SetSize(64, 64)
	slot:SetPoint("CENTER", btn, "CENTER", 0, 0)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ResolveCooldownPreviewIcon())
	icon:SetSize(36, 36)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	btn._icon = icon

	local cooldown = CreateFrame("Cooldown", nil, btn)
	cooldown:SetAllPoints(icon)
	cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)
	cooldown:EnableMouse(false)
	-- Don't let the live CC hook attach countdown text to this preview swipe.
	cooldown.__sary_cc_noCount = true
	if cooldown.SetDrawEdge then
		cooldown:SetDrawEdge(true)
	end
	btn._cooldown = cooldown

	-- Text above the circular swipe.
	local textHost = CreateFrame("Frame", nil, btn)
	textHost:SetAllPoints(btn)
	textHost:SetFrameLevel(cooldown:GetFrameLevel() + 5)
	textHost:EnableMouse(false)

	local cdText = textHost:CreateFontString(nil, "OVERLAY")
	cdText:SetPoint("CENTER", btn, "CENTER", 0, 1)
	cdText:SetJustifyH("CENTER")
	cdText:SetWidth(50)
	cdText:SetShadowColor(0, 0, 0, 1)
	cdText:SetShadowOffset(1, -1)
	btn._cdText = cdText
	return btn
end

function CdPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(88)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	-- Fixed remain samples for the three size buckets used by formatCooldownText.
	local samples = {
		{ remain = 45, label = "< 60 сек" },
		{ remain = 185, label = "1–10 мин" }, -- 3:05
		{ remain = 720, label = "> 10 мин" }, -- 12 м.
	}

	local buttons = {}
	local gap = 28
	local totalW = 44 * 3 + gap * 2
	local startX = -totalW / 2 + 22
	for i, sample in ipairs(samples) do
		local btn = MakeActionButton(stage)
		btn:SetPoint("CENTER", stage, "CENTER", startX + (i - 1) * (44 + gap), 6)
		local caption = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		caption:SetPoint("TOP", btn, "BOTTOM", 0, -2)
		caption:SetText(sample.label)
		caption:SetTextColor(0.7, 0.7, 0.7)
		btn._remain = sample.remain
		buttons[i] = btn
	end
	host._buttons = buttons

	local function EnsureCooldowns()
		if IsOptionsSliderDragging() then return end
		local now = GetTime()
		for _, btn in ipairs(buttons) do
			-- Restart swipe when it finishes so the preview stays "on CD".
			if not btn._cdEnds or now >= (btn._cdEnds - 0.05) then
				StartPreviewCooldown(btn, btn._remain)
			end
		end
	end

	local function ApplyStyle()
		local live = CdPreview._live
		local fontName = live.font or GetSetting("font", DEFAULT_FONT_NAME)
		local fontPath = ResolveFontPath(fontName)
		local fontFlags = live.fontFlags or GetSetting("fontFlags", "OUTLINE")

		for _, btn in ipairs(buttons) do
			local text, baseColor, fontSize = FormatCooldownPreview(btn._remain)
			if live.fontSizeSmall and btn._remain < 60 then
				fontSize = tonumber(live.fontSizeSmall) or fontSize
			elseif live.fontSizeMedium and btn._remain >= 60 and btn._remain < 600 then
				fontSize = tonumber(live.fontSizeMedium) or fontSize
			elseif live.fontSizeLarge and btn._remain >= 600 then
				fontSize = tonumber(live.fontSizeLarge) or fontSize
			end
			local useColor = live.defaultColor or baseColor
			SafeSetFont(btn._cdText, fontPath, fontSize, fontFlags)
			btn._cdText:SetText(text)
			if type(useColor) == "table" then
				btn._cdText:SetTextColor(useColor[1] or 1, useColor[2] or 1, useColor[3] or 1, useColor[4] or 1)
			else
				btn._cdText:SetTextColor(1, 1, 1, 1)
			end
		end
	end

	local function Layout()
		ApplyStyle()
		EnsureCooldowns()
	end

	host.RefreshStyle = ApplyStyle
	host.Refresh = Layout
	host:EnableMouse(false)
	host:SetScript("OnShow", function()
		for _, btn in ipairs(buttons) do
			btn._cdEnds = nil
			StartPreviewCooldown(btn, btn._remain)
		end
		Layout()
	end)
	-- Anim only while this preview host is shown (active options tab).
	BindAnim(host, function(self, elapsed)
		self._cdTick = (self._cdTick or 0) + elapsed
		if self._cdTick < 0.5 then return end
		self._cdTick = 0
		EnsureCooldowns()
	end)
	TrackInstance(self, host)
	Layout()
	return host
end

--------------------------------------------------------------------
-- 1b) GCD preview: one action button above «Не отображать при ГКД»
-- hideOnGCD on  → icon + swipe, no text
-- hideOnGCD off → countdown 1.0 → 0.0 looping
--------------------------------------------------------------------
SarychUI.GcdCooldownPreview = SarychUI.GcdCooldownPreview or {}
local GcdPreview = SarychUI.GcdCooldownPreview
GcdPreview._instances = GcdPreview._instances or {}
GcdPreview._live = GcdPreview._live or {}

local GCD_PREVIEW_DURATION = 1.0

function GcdPreview:SetLiveValue(key, value)
	self._live[key] = value
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, value)
	else
		RefreshBucket(self, true)
	end
end

function GcdPreview:ClearLiveValue(key)
	if key then
		self._live[key] = nil
	else
		for k in pairs(self._live) do self._live[k] = nil end
	end
end

function GcdPreview:RefreshAll()
	RefreshBucket(self, false)
end

function GcdPreview:ClearStickyHosts()
	ClearBucket(self)
end

local function IsHideOnGCD()
	local live = GcdPreview._live
	if live.minDuration ~= nil then
		return tonumber(live.minDuration) >= 3
	end
	return GetSetting("minDuration", 3) >= 3
end

function GcdPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(72)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	local btn = MakeActionButton(stage)
	btn:SetPoint("CENTER", stage, "CENTER", 0, 0)
	host._btn = btn

	local function RestartGcd()
		if IsOptionsSliderDragging() then return end
		local now = GetTime()
		btn._gcdStart = now
		btn._gcdEnds = now + GCD_PREVIEW_DURATION
		StartPreviewCooldown(btn, GCD_PREVIEW_DURATION)
		-- Full swipe from the start (not mid-cycle like the static samples).
		btn._cooldown:SetCooldown(now, GCD_PREVIEW_DURATION)
		btn._cdEnds = now + GCD_PREVIEW_DURATION
	end

	local function ApplyTextStyle()
		local live = GcdPreview._live
		local fontName = live.font or GetSetting("font", DEFAULT_FONT_NAME)
		local fontPath = ResolveFontPath(fontName)
		local fontFlags = live.fontFlags or GetSetting("fontFlags", "OUTLINE")
		local fontSize = tonumber(live.fontSizeSmall) or GetSetting("fontSizeSmall", 14)
		local color = live.defaultColor or GetSetting("defaultColor", { 1, 1, 1, 1 })
		SafeSetFont(btn._cdText, fontPath, fontSize, fontFlags)
		if type(color) == "table" then
			btn._cdText:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
		else
			btn._cdText:SetTextColor(1, 1, 1, 1)
		end
	end

	local function ApplyStyle()
		ApplyTextStyle()
		if IsHideOnGCD() then
			btn._cdText:SetText("")
			btn._cdText:Hide()
		else
			btn._cdText:Show()
		end
	end

	local function Layout()
		ApplyStyle()
		if IsHideOnGCD() then
			btn._gcdStart = nil
			-- Keep a calm mid-swipe look while text is hidden.
			if not IsOptionsSliderDragging() then
				if not btn._cdEnds or GetTime() >= (btn._cdEnds - 0.05) then
					StartPreviewCooldown(btn, GCD_PREVIEW_DURATION)
				end
			end
		else
			if not btn._gcdStart then
				RestartGcd()
			end
		end
	end

	host.RefreshStyle = ApplyStyle
	host.Refresh = Layout
	host:EnableMouse(false)
	host:SetScript("OnShow", function()
		btn._gcdStart = nil
		btn._cdEnds = nil
		RestartGcd()
		Layout()
	end)
	BindAnim(host, function(self, elapsed)
		if IsHideOnGCD() then
			self._gcdTick = (self._gcdTick or 0) + elapsed
			if self._gcdTick >= 0.5 then
				self._gcdTick = 0
				if not btn._cdEnds or GetTime() >= (btn._cdEnds - 0.05) then
					StartPreviewCooldown(btn, GCD_PREVIEW_DURATION)
				end
			end
			return
		end

		local now = GetTime()
		if not btn._gcdStart or not btn._gcdEnds or now >= btn._gcdEnds then
			RestartGcd()
			now = GetTime()
		end
		local remain = max(0, (btn._gcdEnds or now) - now)
		btn._cdText:SetText(format(" %.1f ", remain))
	end)
	TrackInstance(self, host)
	Layout()
	return host
end

--------------------------------------------------------------------
-- 2) Castbar timers — player vs target Blizzard aspects + SarychUI offsets
-- Player: CastingBarFrameTemplate (Border 256x64), icon hidden
-- Target: SetTargetSpellbarAspect (Border-Small 197x49), icon shown
--------------------------------------------------------------------
SarychUI.CastbarTimerPreview = SarychUI.CastbarTimerPreview or {}
local CastPreview = SarychUI.CastbarTimerPreview
CastPreview._instances = CastPreview._instances or {}

function CastPreview:RefreshAll()
	RefreshBucket(self)
end

function CastPreview:ClearStickyHosts()
	ClearBucket(self)
end

local function IsCcFlagOn(key)
	local v = GetSetting(key, 1)
	return v == 1 or v == true
end

-- style: "player" | "target" — matches FrameXML CastingBarFrame / SetTargetSpellbarAspect
local function MakeBlizzardCastBar(parent, style, spellName, iconPath)
	local isTarget = style == "target"
	local width = isTarget and 150 or 195
	local height = isTarget and 10 or 13

	local wrap = CreateFrame("Frame", nil, parent)
	wrap:SetSize(width + (isTarget and 36 or 24), height + (isTarget and 44 or 52))

	-- StatusBar drawLayer=BORDER in CastingBarFrameTemplate so fill sits under ARTWORK border.
	local bar = CreateFrame("StatusBar", nil, wrap)
	bar:SetSize(width, height)
	bar:SetPoint("CENTER", wrap, "CENTER", isTarget and 8 or 0, 4)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(1.0, 0.7, 0.0)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0.62)
	local fill = bar:GetStatusBarTexture()
	if fill and fill.SetDrawLayer then
		fill:SetDrawLayer("BORDER")
	end

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	-- Border above the fill (ARTWORK > BORDER), same as Blizzard template.
	local border = bar:CreateTexture(nil, "ARTWORK")
	if isTarget then
		-- SetTargetSpellbarAspect()
		border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border-Small")
		border:SetSize(197, 49)
		border:SetPoint("TOP", bar, "TOP", 0, 20)
	else
		-- CastingBarFrameTemplate
		border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
		border:SetSize(256, 64)
		border:SetPoint("TOP", bar, "TOP", 0, 28)
	end

	-- Spell name sits centered on the bar (visually middle of the fill).
	local text = bar:CreateFontString(nil, "OVERLAY")
	if isTarget then
		if SystemFont_Shadow_Small then
			text:SetFontObject(SystemFont_Shadow_Small)
		else
			SafeSetFont(text, FALLBACK_FONT, 10, "OUTLINE")
		end
		text:SetWidth(150)
	else
		if GameFontHighlight then
			text:SetFontObject(GameFontHighlight)
		else
			SafeSetFont(text, FALLBACK_FONT, 12, "")
		end
		text:SetWidth(185)
	end
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
	-- Slightly above geometric center; player bar is taller so nudge a bit more.
	text:SetPoint("CENTER", bar, "CENTER", 0, isTarget and 2 or 3)
	text:SetText(spellName or "")

	local icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16)
	icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)
	icon:SetTexture(iconPath or SAMPLE_ICON_FIREBALL)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	if isTarget then
		icon:Show() -- TargetFrame_CreateSpellbar shows icon
	else
		icon:Hide() -- CastingBarFrame_OnLoad hides icon
	end

	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetSize(32, 32)
	spark:SetBlendMode("ADD")
	spark:SetPoint("CENTER", bar, "LEFT", width * 0.62, 0)

	return wrap, bar
end

local function AttachCastTimer(bar, offsetX, offsetY, fontSize, text)
	local timer = bar:CreateFontString(nil, "OVERLAY")
	SafeSetFont(timer, FALLBACK_FONT, fontSize, "")
	timer:SetShadowOffset(1, -1)
	timer:SetShadowColor(0, 0, 0, 1)
	timer:SetPoint("CENTER", bar, "CENTER", offsetX, offsetY)
	timer:SetAlpha(1)
	timer:SetText(text or "")
	timer:SetTextColor(1, 1, 1, 1)
	return timer
end

function CastPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(150)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -6)
	stage:SetPoint("BOTTOMRIGHT", -8, 6)

	local playerLabel = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	playerLabel:SetPoint("TOP", stage, "TOP", 0, -2)
	playerLabel:SetText("Игрок")
	playerLabel:SetTextColor(1, 0.82, 0, 1)

	local playerWrap, playerBar = MakeBlizzardCastBar(stage, "player", FLASH_OF_LIGHT, SAMPLE_ICON_FLASH)
	playerWrap:SetPoint("TOP", stage, "TOP", 0, -16)
	local playerTimer = AttachCastTimer(playerBar, 0, -20, 13, " 1.2 / 1.5 ")

	local targetLabel = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	targetLabel:SetPoint("TOP", stage, "TOP", 0, -78)
	targetLabel:SetText("Цель")
	targetLabel:SetTextColor(1, 0.82, 0, 1)

	local targetWrap, targetBar = MakeBlizzardCastBar(stage, "target", FIREBALL, SAMPLE_ICON_FIREBALL)
	targetWrap:SetPoint("TOP", stage, "TOP", 0, -92)
	local targetTimer = AttachCastTimer(targetBar, 92, 0, 12, " 2.4 ")

	host._playerTimer = playerTimer
	host._targetTimer = targetTimer

	local function Layout()
		local master = IsCcFlagOn("enableCastbarTimers")
		if master and IsCcFlagOn("enableCastbarPlayer") then
			playerTimer:Show()
		else
			playerTimer:Hide()
		end
		if master and IsCcFlagOn("enableCastbarTarget") then
			targetTimer:Show()
		else
			targetTimer:Hide()
		end
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	TrackInstance(self, host)
	Layout()
	return host
end

--------------------------------------------------------------------
-- 3) LFG countdown — LFDDungeonReadyDialog + animated Enter " (N)" 24→20
--------------------------------------------------------------------
SarychUI.CountdownTimerPreview = SarychUI.CountdownTimerPreview or {}
local CdwnPreview = SarychUI.CountdownTimerPreview
CdwnPreview._instances = CdwnPreview._instances or {}

function CdwnPreview:RefreshAll()
	RefreshBucket(self)
end

function CdwnPreview:ClearStickyHosts()
	ClearBucket(self)
end

local function MakePanelButton(parent, width, height, label)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width, height)
	btn:EnableMouse(false)

	local left = btn:CreateTexture(nil, "BACKGROUND")
	left:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	left:SetTexCoord(0, 0.078125, 0, 0.6875)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(12)

	local right = btn:CreateTexture(nil, "BACKGROUND")
	right:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	right:SetTexCoord(0.625, 0.75, 0, 0.6875)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(12)

	local mid = btn:CreateTexture(nil, "BACKGROUND")
	mid:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	mid:SetTexCoord(0.078125, 0.625, 0, 0.6875)
	mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
	mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	-- Nudge left so label looks centered on Blizzard panel-button chrome.
	fs:SetPoint("CENTER", btn, "CENTER", -4, 0)
	fs:SetJustifyH("CENTER")
	fs:SetJustifyV("MIDDLE")
	fs:SetText(label or "")
	btn._label = fs
	return btn
end

function CdwnPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(210)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	-- Exact LFDDungeonReadyDialog proportions from LFDFrame.xml (306x193).
	local dialog = CreateFrame("Frame", nil, stage)
	dialog:SetSize(306, 193)
	dialog:SetPoint("CENTER", stage, "CENTER", 0, 0)
	dialog:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})

	local bg = dialog:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-RANDOMDUNGEON")
	bg:SetSize(294, 118)
	bg:SetPoint("TOP", dialog, "TOP", 0, -11)
	bg:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 64)

	local filigree = dialog:CreateTexture(nil, "OVERLAY")
	filigree:SetTexture("Interface\\LFGFrame\\UI-LFG-FILIGREE")
	filigree:SetSize(292, 54)
	filigree:SetPoint("TOPLEFT", dialog, "TOPLEFT", 7, -3)
	filigree:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -7, -3)
	filigree:SetTexCoord(0.02734, 0.59765, 0.578125, 1.0)

	local bottomArt = dialog:CreateTexture(nil, "OVERLAY")
	bottomArt:SetTexture("Interface\\LFGFrame\\UI-LFG-FILIGREE")
	bottomArt:SetSize(287, 72)
	bottomArt:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 55)
	bottomArt:SetTexCoord(0.0, 0.5605, 0.0, 0.5625)

	local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetSize(150, 0)
	label:SetPoint("TOP", dialog, "TOP", 0, -15)
	label:SetJustifyH("CENTER")
	label:SetText("Случайное подземелье")

	local close = dialog:CreateTexture(nil, "ARTWORK")
	close:SetTexture("Interface\\Buttons\\UI-Panel-HideButton-Up")
	close:SetSize(32, 32)
	close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -2, -2)

	local enterBase = ENTER_DUNGEON or "Войти в подземелье"
	local leaveBase = LEAVE_QUEUE or "Покинуть очередь"

	local enterBtn = MakePanelButton(dialog, 115, 22, enterBase)
	enterBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -7, 25)

	local leaveBtn = MakePanelButton(dialog, 115, 22, leaveBase)
	leaveBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 7, 25)

	host._enterBtn = enterBtn
	host._enterBase = enterBase
	host._cdSec = 24
	host._cdAcc = 0

	local function SetEnterLabel(sec)
		if IsCcFlagOn("enableInviteCountdown") then
			enterBtn._label:SetText(enterBase .. " (" .. tostring(sec) .. ")")
		else
			enterBtn._label:SetText(enterBase)
		end
	end

	local function TickCountdown(self, elapsed)
		if not IsCcFlagOn("enableInviteCountdown") then
			SetEnterLabel(24)
			self._suiPreviewAnim = nil
			self:SetScript("OnUpdate", nil)
			return
		end
		self._cdAcc = (self._cdAcc or 0) + elapsed
		if self._cdAcc < 1 then return end
		self._cdAcc = 0
		self._cdSec = (self._cdSec or 24) - 1
		if self._cdSec < 20 then
			self._cdSec = 24
		end
		SetEnterLabel(self._cdSec)
	end

	local function Layout()
		if IsCcFlagOn("enableInviteCountdown") then
			host._cdSec = host._cdSec or 24
			SetEnterLabel(host._cdSec)
			BindAnim(host, TickCountdown)
		else
			host._suiPreviewAnim = nil
			host:SetScript("OnUpdate", nil)
			SetEnterLabel(24)
		end
	end

	host.Refresh = Layout
	host:EnableMouse(false)
	host:SetScript("OnShow", Layout)
	host:SetScript("OnHide", function(self)
		self._suiPreviewAnim = nil
		self:SetScript("OnUpdate", nil)
	end)
	TrackInstance(self, host)
	Layout()
	return host
end
