-- SarychUI Frame PVP — sticky options preview (player frame + PVP icon/timer).

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local UnitFactionGroup = UnitFactionGroup

SarychUI = SarychUI or {}

local FRAME_SCALE = 0.85
local FRAME_W = 232 * FRAME_SCALE
local FRAME_H = 100 * FRAME_SCALE
local PREVIEW_H = 110

local KEY_TO_SLOT = {
	hidePlayerPVP = "icon",
	hideTargetPVP = "icon",
	hideFocusPVP = "icon",
	hidePVPTimer = "timer",
	pvpTimerOnAlt = "timer",
	classIconPortraits = "portrait",
	classIconPortraitsPlayer = "portrait",
}

local PORTRAIT = "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human"
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"

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
		-- Tint only the PVP emblem texture (no oversized box).
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

local function MakePlayer(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(FRAME_W, FRAME_H)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(S(119), S(41))
	bg:SetPoint("TOPLEFT", S(106), -S(22))
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	local portrait = f:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(S(64), S(64))
	portrait:SetPoint("TOPLEFT", S(42), -S(12))
	portrait:SetTexture(PORTRAIT)
	f.portrait = portrait

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetSize(S(100), S(12))
	nameFs:SetPoint("CENTER", S(50), S(19))
	nameFs:SetText("Игрок")
	nameFs:SetJustifyH("CENTER")
	nameFs:SetTextColor(1.0, 0.82, 0)

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
	border:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
	border:SetTexCoord(1.0, 0.09375, 0, 0.78125)

	-- Blizzard PlayerPVPIcon: TOPLEFT 18,-20, 64x64
	local pvpWrap = CreateFrame("Frame", nil, f)
	pvpWrap:SetSize(S(64), S(64))
	pvpWrap:SetPoint("TOPLEFT", f, "TOPLEFT", S(18), -S(20))
	pvpWrap:SetFrameLevel(f:GetFrameLevel() + 8)

	local pvpIcon = pvpWrap:CreateTexture(nil, "ARTWORK")
	pvpIcon:SetAllPoints()
	pvpIcon:SetTexture(FactionTexture())
	pvpWrap.tex = pvpIcon

	-- Soft ADD glow clipped to the same texture bounds (not a larger box).
	local pvpGlow = pvpWrap:CreateTexture(nil, "OVERLAY")
	pvpGlow:SetAllPoints(pvpIcon)
	pvpGlow:SetTexture(FactionTexture())
	pvpGlow:SetBlendMode("ADD")
	pvpGlow:SetVertexColor(1, 0.85, 0.2)
	pvpGlow:SetAlpha(0.55)
	pvpGlow:Hide()
	pvpWrap._glow = pvpGlow
	f.pvpIcon = pvpWrap

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
	player:SetPoint("CENTER", stage, "CENTER", 0, 0)

	host._player = player

	local function Layout()
		local hideIcon = LiveFlag("hidePlayerPVP", true)
		local hideTimer = LiveFlag("hidePVPTimer", true)
		local classPortrait = LiveFlag("classIconPortraits", false)
		local classPortraitPlayer = LiveFlag("classIconPortraitsPlayer", true)

		if player.portrait then
			if classPortrait and classPortraitPlayer then
				local _, class = UnitClass("player")
				local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
				player.portrait:SetTexture(CLASS_CIRCLES)
				if coords then
					player.portrait:SetTexCoord(unpack(coords))
				else
					player.portrait:SetTexCoord(0, 1, 0, 1)
				end
			else
				player.portrait:SetTexture(PORTRAIT)
				player.portrait:SetTexCoord(0, 1, 0, 1)
			end
			if IsActive("portrait") then
				player.portrait:SetVertexColor(1, 0.92, 0.35)
			else
				player.portrait:SetVertexColor(1, 1, 1)
			end
		end

		-- Hide options mean the element is not shown in preview.
		if hideIcon then
			player.pvpIcon:Hide()
		else
			player.pvpIcon:Show()
			player.pvpIcon:SetAlpha(1)
			ApplyIconHighlight(player.pvpIcon, IsActive("icon"))
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
