-- SarychUI Frame appearance - sticky options preview (player + target).

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local unpack = unpack
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitSelectionColor = UnitSelectionColor

SarychUI = SarychUI or {}

local function Tr(s)
	if type(s) ~= "string" or s == "" then return s end
	if SarychUI.T then return SarychUI:T(s) end
	return s
end

local FRAME_SCALE = 0.85
local FRAME_W = 232 * FRAME_SCALE
local FRAME_H = 100 * FRAME_SCALE
local PREVIEW_H = 110

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local KEY_TO_SLOT = {
	hidePlayerPVP = "playerIcon",
	hideTargetPVP = "targetIcon",
	hideFocusPVP = "focusIcon",
	hidePVPTimer = "timer",
	pvpTimerOnAlt = "timer",
	classIconPortraits = "portrait",
	classIconPortraitsPlayer = "playerPortrait",
	hideFrameLevel = "level",
	hidePlayerRestState = "restState",
	classIconEnabled = "classIcon",
	classIconMode = "classIcon",
	classIconMaxLevelOnly = "classIcon",
	classIconPlayer = "playerClassIcon",
	classIconX = "classIcon",
	classIconY = "classIcon",
	classColoredNames = "className",
	classColoredNamesExcludePlayer = "playerClassName",
	nameBackgroundEnabled = "nameBg",
	nameBackgroundMode = "nameBg",
	nameBackgroundColor = "nameBg",
	nameBackgroundExcludePlayer = "playerNameBg",
}

local PORTRAIT_PLAYER = "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human"
local PORTRAIT_TARGET = "Interface\\CharacterFrame\\TemporaryPortrait-Female-BloodElf"
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local MINIMAP_RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
-- Blizzard TargetFrameNameBackground uses this file, then tints it with UnitSelectionColor.
-- Friendly player selection color is pure blue (0, 0, 1).
local NAME_BG = "Interface\\TargetingFrame\\UI-TargetingFrame-LevelBackground"
local NAME_BG_CLASS = "Interface\\TargetingFrame\\UI-StatusBar"
local BORDER_NORMAL = "Interface\\TargetingFrame\\UI-TargetingFrame"
local BORDER_NOLEVEL = "Interface\\AddOns\\SarychUI\\media\\frames\\nolevel\\NoLevel-UI-TargetingFrame"

--------------------------------------------------------------------
SarychUI.FramePvpPreview = SarychUI.FramePvpPreview or {}
local Preview = SarychUI.FramePvpPreview
Preview._instances = Preview._instances or {}
Preview._live = Preview._live or {}
Preview._activeKey = nil

local function FrameDB()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods.frame or {}
end

local function LiveOr(key, fallback)
	local live = Preview._live
	if live[key] ~= nil then
		return live[key]
	end
	local db = FrameDB()
	local v = db[key]
	if v == nil then return fallback end
	return v
end

local function LiveFlag(key, fallback)
	local v = LiveOr(key, fallback)
	return v == 1 or v == true
end

local function IsActive(slotName)
	local key = Preview._activeKey
	if not key then return false end
	return KEY_TO_SLOT[key] == slotName
end

local function ApplyIconHighlight(wrap, active)
	if not wrap or not wrap.tex then return end
	if active then
		wrap.tex:SetVertexColor(1, 0.92, 0.35)
		if wrap._glow then
			wrap._glow:Show()
		end
	else
		wrap.tex:SetVertexColor(1, 1, 1)
		if wrap._glow then
			wrap._glow:Hide()
		end
	end
end

local function ApplyTimerHighlight(wrap, active)
	if not wrap or not wrap.fs then return end
	if active then
		wrap.fs:SetTextColor(1, 0.95, 0.4)
	else
		wrap.fs:SetTextColor(1, 0.82, 0)
	end
end

local function ApplyLevelHighlight(wrap, active)
	if not wrap or not wrap.fs then return end
	if active then
		wrap.fs:SetTextColor(1, 0.95, 0.4)
	else
		wrap.fs:SetTextColor(1.0, 0.82, 0)
	end
end

function Preview:SetActiveKey(key)
	self._activeKey = key
	self:RefreshAll()
end

function Preview:SetLiveValue(key, value)
	if key == nil then return end
	self._live[key] = value
	self._activeKey = key
	self:RefreshAll()
end

function Preview:ClearLiveValue(key)
	if key then
		self._live[key] = nil
	else
		for k in pairs(self._live) do
			self._live[k] = nil
		end
	end
	self:RefreshAll()
end

function Preview:RefreshAll()
	local alive = {}
	for _, inst in ipairs(self._instances) do
		if inst and inst.GetParent and inst:GetParent() and inst.spacer and inst.spacer:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	self._instances = alive
end

function Preview:ClearStickyHosts()
	for _, inst in ipairs(self._instances) do
		if inst then
			if inst.SetBackdrop then
				inst:SetBackdrop(nil)
			end
			if inst.Hide then inst:Hide() end
			if inst.ClearAllPoints then inst:ClearAllPoints() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	self._instances = {}
end

local function S(n)
	return n * FRAME_SCALE
end

local function FactionTexture()
	local faction = "Alliance"
	if UnitFactionGroup then
		local fg = UnitFactionGroup("player")
		if fg == "Horde" or fg == "Alliance" then
			faction = fg
		end
	end
	return "Interface\\TargetingFrame\\UI-PVP-" .. faction
end

local function MakeLevel(parent, x, y)
	local wrap = CreateFrame("Frame", nil, parent)
	wrap:SetSize(S(32), S(16))
	wrap:SetPoint("CENTER", parent, "CENTER", x, y)
	wrap:SetFrameLevel(parent:GetFrameLevel() + 5)

	local fs = wrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("CENTER")
	fs:SetText("80")
	fs:SetTextColor(1.0, 0.82, 0)
	wrap.fs = fs

	local ring = wrap:CreateTexture(nil, "OVERLAY")
	ring:SetSize(S(52), S(52))
	ring:SetTexture(MINIMAP_RING)
	ring:Hide()
	wrap.ring = ring

	local icon = wrap:CreateTexture(nil, "ARTWORK")
	icon:SetSize(S(20), S(20))
	icon:SetPoint("CENTER")
	icon:Hide()
	wrap.icon = icon
	return wrap
end

local function MakePvpIcon(parent, point, x, y)
	local pvpWrap = CreateFrame("Frame", nil, parent)
	pvpWrap:SetSize(S(64), S(64))
	pvpWrap:SetPoint(point, parent, point, x, y)
	pvpWrap:SetFrameLevel(parent:GetFrameLevel() + 8)

	local texPath = FactionTexture()
	local pvpIcon = pvpWrap:CreateTexture(nil, "ARTWORK")
	pvpIcon:SetAllPoints()
	pvpIcon:SetTexture(texPath)
	pvpWrap.tex = pvpIcon

	local pvpGlow = pvpWrap:CreateTexture(nil, "OVERLAY")
	pvpGlow:SetAllPoints(pvpIcon)
	pvpGlow:SetTexture(texPath)
	pvpGlow:SetBlendMode("ADD")
	pvpGlow:SetVertexColor(1, 0.85, 0.2)
	pvpGlow:SetAlpha(0.55)
	pvpGlow:Hide()
	pvpWrap._glow = pvpGlow
	return pvpWrap
end

local function ApplyPortrait(tex, useClass, classToken, highlight)
	if not tex then return end
	if useClass then
		local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
		tex:SetTexture(CLASS_CIRCLES)
		if coords then
			tex:SetTexCoord(unpack(coords))
		else
			tex:SetTexCoord(0, 1, 0, 1)
		end
	else
		tex:SetTexture(tex._defaultPortrait)
		tex:SetTexCoord(0, 1, 0, 1)
	end
	if highlight then
		tex:SetVertexColor(1, 0.92, 0.35)
	else
		tex:SetVertexColor(1, 1, 1)
	end
end

local function ApplyBorder(border, hideLevel, flipped)
	if not border then return end
	border:SetTexture(hideLevel and BORDER_NOLEVEL or BORDER_NORMAL)
	if flipped then
		border:SetTexCoord(1.0, 0.09375, 0, 0.78125)
	else
		border:SetTexCoord(0.09375, 1.0, 0, 0.78125)
	end
end

local function ClassRGB(classToken)
	local c = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
	if c then return c.r, c.g, c.b end
	return nil
end

local function PaintPreviewName(fs, classToken, isPlayer)
	if not fs then return end
	local skipPlayer = LiveFlag("classColoredNamesExcludePlayer", false)
	if isPlayer and skipPlayer then
		if IsActive("playerClassName") then
			fs:SetTextColor(1, 0.92, 0.35)
		else
			fs:SetTextColor(1.0, 0.82, 0)
		end
		return
	end
	if IsActive("className") then
		fs:SetTextColor(1, 0.92, 0.35)
		return
	end
	if LiveFlag("classColoredNames", false) then
		local r, g, b = ClassRGB(classToken)
		if r then
			fs:SetTextColor(r, g, b)
			return
		end
	end
	fs:SetTextColor(1.0, 0.82, 0)
end

local function PaintPreviewNameBg(tex, classToken, isPlayer)
	if not tex then return end
	local enabled = LiveFlag("nameBackgroundEnabled", false)
	local mode = LiveOr("nameBackgroundMode", "custom")
	local skipPlayer = LiveFlag("nameBackgroundExcludePlayer", false)
	local active = IsActive("nameBg")
	local activePlayer = IsActive("playerNameBg")

	if isPlayer and skipPlayer then
		if activePlayer then
			tex:Show()
			tex:SetTexture(NAME_BG_CLASS)
			tex:SetVertexColor(1, 0.92, 0.35)
		else
			tex:Hide()
		end
		return
	end

	if not enabled then
		if isPlayer then
			tex:Hide()
			return
		end
		tex:Show()
		tex:SetTexture(NAME_BG)
		if active then
			tex:SetVertexColor(1, 0.92, 0.35)
		else
			tex:SetVertexColor(tex._nameBgR or 0, tex._nameBgG or 0, tex._nameBgB or 1)
		end
		return
	end

	if mode == "class" then
		tex:Show()
		tex:SetTexture(NAME_BG_CLASS)
		local c = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
		local r, g, b = 0.5, 0.5, 0.5
		if c then
			r, g, b = c.r, c.g, c.b
		end
		if active then
			tex:SetVertexColor(1, 0.92, 0.35)
		else
			tex:SetVertexColor(r, g, b, 1)
		end
		return
	end

	if isPlayer then
		tex:Hide()
		return
	end
	tex:Show()
	tex:SetTexture(NAME_BG)
	local col = LiveOr("nameBackgroundColor", { 0, 0, 0, 0 })
	local r, g, b, a = 0, 0, 0, 0
	if type(col) == "table" then
		if col[1] ~= nil then r = col[1] end
		if col[2] ~= nil then g = col[2] end
		if col[3] ~= nil then b = col[3] end
		if col[4] ~= nil then a = col[4] end
	end
	if active then
		tex:SetVertexColor(1, 0.92, 0.35, math.max(a, 0.45))
	else
		tex:SetVertexColor(r, g, b, a)
	end
end

local function MakePlayer(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(FRAME_W, FRAME_H)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(S(119), S(41))
	bg:SetPoint("TOPLEFT", S(106), -S(22))
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	-- RougeUI ClassBG overlay: TOPLEFT PlayerFrameBackground / BOTTOMRIGHT 0,22 (119x19 name strip).
	local nameBg = f:CreateTexture(nil, "BORDER")
	nameBg:SetSize(S(119), S(19))
	nameBg:SetPoint("TOPLEFT", S(106), -S(22))
	nameBg:SetTexture(NAME_BG_CLASS)
	nameBg:Hide()
	f.nameBg = nameBg

	local portrait = f:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(S(64), S(64))
	portrait:SetPoint("TOPLEFT", S(42), -S(12))
	portrait:SetTexture(PORTRAIT_PLAYER)
	portrait._defaultPortrait = PORTRAIT_PLAYER
	f.portrait = portrait

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetSize(S(100), S(12))
	nameFs:SetPoint("CENTER", S(50), S(19))
	nameFs:SetText(Tr("Игрок"))
	nameFs:SetJustifyH("CENTER")
	nameFs:SetTextColor(1.0, 0.82, 0)
	f.name = nameFs

	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(S(119), S(12))
	health:SetPoint("TOPLEFT", S(106), -S(41))
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.78)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local mana = CreateFrame("StatusBar", nil, f)
	mana:SetSize(S(119), S(12))
	mana:SetPoint("TOPLEFT", S(106), -S(52))
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(0.55)
	mana:SetStatusBarColor(0, 0, 1)
	mana:SetFrameLevel(f:GetFrameLevel() + 1)

	local borderFrame = CreateFrame("Frame", nil, f)
	borderFrame:SetAllPoints()
	borderFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints()
	border:SetTexture(BORDER_NORMAL)
	border:SetTexCoord(1.0, 0.09375, 0, 0.78125)
	f.border = border

	-- Resting-state artwork from PlayerFrame.xml.  The combat artwork uses
	-- separate textures and is intentionally not part of this preview group.
	local restState = CreateFrame("Frame", nil, f)
	restState:SetAllPoints()
	restState:SetFrameLevel(f:GetFrameLevel() + 7)

	local status = restState:CreateTexture(nil, "ARTWORK")
	status:SetSize(S(190), S(66))
	status:SetPoint("TOPLEFT", S(35), -S(8))
	status:SetTexture("Interface\\CharacterFrame\\UI-Player-Status")
	status:SetTexCoord(0, 0.74609375, 0, 0.53125)
	status:SetBlendMode("ADD")

	local restIcon = restState:CreateTexture(nil, "OVERLAY")
	restIcon:SetSize(S(31), S(33))
	restIcon:SetPoint("TOPLEFT", S(37), -S(49))
	restIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	restIcon:SetTexCoord(0, 0.5, 0, 0.421875)

	local restGlow = restState:CreateTexture(nil, "OVERLAY")
	restGlow:SetSize(S(32), S(32))
	restGlow:SetPoint("TOPLEFT", S(37), -S(49))
	restGlow:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	restGlow:SetTexCoord(0, 0.5, 0.5, 1)
	restGlow:SetBlendMode("ADD")

	restState.status = status
	restState.icon = restIcon
	restState.glow = restGlow
	f.restState = restState

	-- PlayerFrame.xml: PlayerLevelText CENTER -63, -16
	f.levelWrap = MakeLevel(f, S(-63), S(-16))

	-- Blizzard PlayerPVPIcon: TOPLEFT 18,-20, 64x64
	f.pvpIcon = MakePvpIcon(f, "TOPLEFT", S(18), -S(20))

	-- Blizzard PlayerPVPTimerText: CENTER of TOPLEFT at 38,-8
	local timerWrap = CreateFrame("Frame", nil, f)
	timerWrap:SetSize(S(48), S(16))
	timerWrap:SetPoint("CENTER", f, "TOPLEFT", S(38), -S(8))
	timerWrap:SetFrameLevel(f:GetFrameLevel() + 9)

	local timerFs = timerWrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	timerFs:SetPoint("CENTER")
	timerFs:SetText("4:59")
	timerFs:SetTextColor(1, 0.82, 0)
	timerWrap.fs = timerFs
	f.pvpTimer = timerWrap

	return f
end

local function MakeTarget(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(FRAME_W, FRAME_H)

	-- TargetFrame.xml BACKGROUND: TargetFrameBackground 119x41 TOPRIGHT -106,-22, Color 0,0,0,0.5 (no file)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(S(119), S(41))
	bg:SetPoint("TOPRIGHT", -S(106), -S(22))
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	-- TargetFrame.xml BORDER: TargetFrameNameBackground
	-- file=Interface\TargetingFrame\UI-TargetingFrame-LevelBackground
	-- 119x19 TOPRIGHT -106,-22; vertex color from TargetFrame_CheckFaction -> UnitSelectionColor
	local nameBg = f:CreateTexture(nil, "BORDER")
	nameBg:SetSize(S(119), S(19))
	nameBg:SetPoint("TOPRIGHT", -S(106), -S(22))
	nameBg:SetTexture(NAME_BG)
	local nr, ng, nb = 0, 0, 1
	if UnitSelectionColor then
		nr, ng, nb = UnitSelectionColor("player")
	end
	nameBg:SetVertexColor(nr or 0, ng or 0, nb or 1)
	f.nameBg = nameBg
	f._nameBgR, f._nameBgG, f._nameBgB = nr or 0, ng or 0, nb or 1

	-- TargetFrame.xml BORDER: TargetPortrait 64x64 TOPRIGHT -42,-12
	local portrait = f:CreateTexture(nil, "BORDER")
	portrait:SetSize(S(64), S(64))
	portrait:SetPoint("TOPRIGHT", -S(42), -S(12))
	portrait:SetTexture(PORTRAIT_TARGET)
	portrait._defaultPortrait = PORTRAIT_TARGET
	f.portrait = portrait

	-- TargetFrame.xml: TargetName GameFontNormalSmall 100x10 CENTER -50,19
	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetSize(S(100), S(10))
	nameFs:SetPoint("CENTER", -S(50), S(19))
	nameFs:SetText(Tr("Цель"))
	nameFs:SetJustifyH("CENTER")
	nameFs:SetTextColor(1.0, 0.82, 0)
	f.name = nameFs

	-- TargetFrameHealthBar 119x12 TOPRIGHT -106,-41
	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(S(119), S(12))
	health:SetPoint("TOPRIGHT", -S(106), -S(41))
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.7)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	-- TargetFrameManaBar 119x12 TOPRIGHT -106,-52 BarColor 0,0,1
	local mana = CreateFrame("StatusBar", nil, f)
	mana:SetSize(S(119), S(12))
	mana:SetPoint("TOPRIGHT", -S(106), -S(52))
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(0.5)
	mana:SetStatusBarColor(0, 0, 1)
	mana:SetFrameLevel(f:GetFrameLevel() + 1)

	-- TargetFrameTexture UI-TargetingFrame texcoords 0.09375, 1.0, 0, 0.78125
	local borderFrame = CreateFrame("Frame", nil, f)
	borderFrame:SetAllPoints()
	borderFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints()
	border:SetTexture(BORDER_NORMAL)
	border:SetTexCoord(0.09375, 1.0, 0, 0.78125)
	f.border = border

	-- TargetLevelText CENTER 63,-16
	f.levelWrap = MakeLevel(f, S(63), S(-16))

	-- TargetPVPIcon 64x64 TOPRIGHT 3,-20
	f.pvpIcon = MakePvpIcon(f, "TOPRIGHT", S(3), -S(20))

	return f
end

function Preview:Create(parent)
	self:ClearStickyHosts()
	local OW = SarychUI.OptionsWindow
	local T = SarychUI.OptionsTheme

	local spacer = CreateFrame("Frame", nil, parent)
	spacer:SetHeight(PREVIEW_H + 4)

	local stickyParent = (OW and OW.content) or parent
	local host = CreateFrame("Frame", nil, stickyParent)
	host:SetHeight(PREVIEW_H)
	host.spacer = spacer
	host:SetFrameStrata((stickyParent.GetFrameStrata and stickyParent:GetFrameStrata()) or "DIALOG")
	host:SetFrameLevel((stickyParent:GetFrameLevel() or 1) + 40)

	if T and T.ApplyFlat then
		T:ApplyFlat(host, T.colors.panelBg or { 0.07, 0.07, 0.09, 0.97 }, T.colors.borderSoft)
	else
		local bg = host:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
	end

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 6, -6)
	stage:SetPoint("BOTTOMRIGHT", -6, 6)

	local player = MakePlayer(stage)
	player:SetPoint("CENTER", stage, "CENTER", -(FRAME_W / 2) - 6, 0)

	local target = MakeTarget(stage)
	target:SetPoint("CENTER", stage, "CENTER", (FRAME_W / 2) + 6, 0)

	host._player = player
	host._target = target

	local function Layout()
		local hidePlayerIcon = LiveFlag("hidePlayerPVP", true)
		local hideTargetIcon = LiveFlag("hideTargetPVP", true)
		local hideTimer = LiveFlag("hidePVPTimer", true)
		local hideLevel = LiveFlag("hideFrameLevel", false)
		local hideRestState = LiveFlag("hidePlayerRestState", false)
		local classPortrait = LiveFlag("classIconPortraits", false)
		local classPortraitPlayer = LiveFlag("classIconPortraitsPlayer", true)

		local classIconOn = LiveFlag("classIconEnabled", false)
		local classIconPlayer = LiveFlag("classIconPlayer", true)
		local classIconSeparate = LiveOr("classIconMode", "replace") == "separate"
		local classIconX = tonumber(LiveOr("classIconX", -73)) or -73
		local classIconY = tonumber(LiveOr("classIconY", 43)) or 43

		local _, playerClass = UnitClass("player")
		ApplyPortrait(player.portrait, classPortrait and classPortraitPlayer, playerClass, IsActive("portrait") or IsActive("playerPortrait"))
		ApplyPortrait(target.portrait, classPortrait, "PALADIN", IsActive("portrait"))

		ApplyBorder(player.border, hideLevel, true)
		ApplyBorder(target.border, hideLevel, false)

		if hideRestState then
			player.restState:Hide()
		else
			player.restState:Show()
			local active = IsActive("restState")
			local r, g, b = 1, 1, 1
			if active then r, g, b = 1, 0.92, 0.35 end
			player.restState.status:SetVertexColor(r, g, b)
			player.restState.icon:SetVertexColor(r, g, b)
			player.restState.glow:SetVertexColor(r, g, b)
		end

		PaintPreviewNameBg(player.nameBg, playerClass, true)
		PaintPreviewNameBg(target.nameBg, "PALADIN", false)
		PaintPreviewName(player.name, playerClass, true)
		PaintPreviewName(target.name, "PALADIN", false)

		local function PaintClassIcon(wrap, class, active, side)
			local icon = wrap.icon
			local ring = wrap.ring
			if not icon then return end
			if ring then ring:Hide() end
			if not classIconOn or hideLevel then
				icon:Hide()
				return
			end
			local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
			if not coords then
				icon:Hide()
				return
			end
			icon:SetTexture(CLASS_CIRCLES)
			icon:SetTexCoord(unpack(coords))
			icon:ClearAllPoints()
			if classIconSeparate then
				icon:SetPoint("CENTER", wrap, "CENTER", (side or 0) + classIconX, classIconY)
				wrap.fs:Show()
				if ring then
					ring:ClearAllPoints()
					ring:SetPoint("TOPLEFT", icon, "CENTER", -S(15), S(16))
					ring:Show()
				end
			else
				icon:SetPoint("CENTER", wrap, "CENTER", 0, 0)
				wrap.fs:Hide()
			end
			icon:Show()
			icon:SetAlpha(1)
			if active then
				icon:SetVertexColor(1, 0.92, 0.35)
				if ring and ring:IsShown() then
					ring:SetVertexColor(1, 0.92, 0.35)
				end
			else
				icon:SetVertexColor(1, 1, 1)
				if ring then
					local L = SarychUI_LortiUI
					if classIconSeparate and L and L.IsSettingOn and L.IsSettingOn() and L.GetColor then
						local r, g, b, a = L.GetColor()
						ring:SetVertexColor(r, g, b, a or 1)
					else
						ring:SetVertexColor(1, 1, 1)
					end
				end
			end
		end

		if hideLevel then
			player.levelWrap:Hide()
			target.levelWrap:Hide()
		else
			player.levelWrap:Show()
			target.levelWrap:Show()
			player.levelWrap.fs:Show()
			target.levelWrap.fs:Show()
			ApplyLevelHighlight(player.levelWrap, IsActive("level"))
			ApplyLevelHighlight(target.levelWrap, IsActive("level"))
			PaintClassIcon(player.levelWrap, classIconPlayer and playerClass or nil, IsActive("classIcon") or IsActive("playerClassIcon"), -S(22))
			PaintClassIcon(target.levelWrap, "PALADIN", IsActive("classIcon") and not IsActive("playerClassIcon"), S(22))
		end

		if hidePlayerIcon then
			player.pvpIcon:Hide()
		else
			player.pvpIcon:Show()
			player.pvpIcon:SetAlpha(1)
			ApplyIconHighlight(player.pvpIcon, IsActive("playerIcon"))
		end

		if hideTargetIcon then
			target.pvpIcon:Hide()
		else
			target.pvpIcon:Show()
			target.pvpIcon:SetAlpha(1)
			ApplyIconHighlight(target.pvpIcon, IsActive("targetIcon"))
		end

		if hideTimer then
			player.pvpTimer:Hide()
		else
			player.pvpTimer:Show()
			player.pvpTimer:SetAlpha(1)
			player.pvpTimer.fs:SetText("4:59")
			ApplyTimerHighlight(player.pvpTimer, IsActive("timer"))
		end
	end

	local function PinSticky()
		if not spacer:GetParent() or not spacer:IsShown() then
			host:Hide()
			return
		end
		host:Show()
		local scroll = OW and OW.contentScroll
		if scroll and stickyParent == (OW and OW.content) then
			host:SetParent(stickyParent)
			host:ClearAllPoints()
			host:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
			host:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
			host:SetHeight(PREVIEW_H)
			host:SetFrameLevel((stickyParent:GetFrameLevel() or 1) + 40)
		else
			host:SetParent(parent)
			host:ClearAllPoints()
			host:SetPoint("TOPLEFT", spacer, "TOPLEFT", 0, 0)
			host:SetPoint("TOPRIGHT", spacer, "TOPRIGHT", 0, 0)
		end
		Layout()
	end

	host.Refresh = function()
		PinSticky()
	end

	spacer:SetScript("OnShow", function() PinSticky() end)
	spacer:SetScript("OnHide", function() host:Hide() end)

	local scroll = OW and OW.contentScroll
	if scroll and not scroll._suiFramePvpPinHooked then
		scroll._suiFramePvpPinHooked = true
		scroll:HookScript("OnVerticalScroll", function()
			Preview:RefreshAll()
		end)
		scroll:HookScript("OnSizeChanged", function()
			Preview:RefreshAll()
		end)
	end

	PinSticky()
	tinsert(self._instances, host)
	return spacer
end
