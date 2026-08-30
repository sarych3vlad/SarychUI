-- SarychUI Health Indicators — live preview for nameplate distance text (autolos).

local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local type = type
local tonumber = tonumber
local tostring = tostring
local tinsert = table.insert
local pcall = pcall
local math_max = math.max
local math_min = math.min

SarychUI = SarychUI or {}
SarychUI.NameplateDistancePreview = SarychUI.NameplateDistancePreview or {}
local Preview = SarychUI.NameplateDistancePreview

local PREVIEW_H = 120
local NOTICE_H = 18
local PLATE_W = 128
local PLATE_H = 12
local ACTIVE_BORDER = { 1, 0.82, 0.2, 1 }
-- Defaults used by autolos; preview shows deltas from these so "43" stays visible.
local DEFAULT_OFFSET_X = -95
local DEFAULT_OFFSET_Y = -9

Preview._instances = Preview._instances or {}
Preview._activeKey = nil
Preview._live = Preview._live or {}

local function Module()
	return SarychUI and SarychUI.GetModule and SarychUI:GetModule("health_indicators")
end

local function ActiveProfile()
	local mod = Module()
	if mod and mod.EnsureAutolosProfiles then
		mod:EnsureAutolosProfiles()
	end
	if mod and mod.GetAutolosProfile then
		return mod:GetAutolosProfile() or {}
	end
	if _G.Autolos and _G.Autolos.GetActiveProfile then
		return _G.Autolos.GetActiveProfile() or {}
	end
	return {}
end

local function ModeNotice()
	local mod = Module()
	local mode = mod and mod.GetAutolosProfileMode and mod:GetAutolosProfileMode() or "classic"
	local L = SarychUI and SarychUI.L
	local label
	if mode == "elvui" then
		label = L and (L["ElvUI Nameplates"] or "ElvUI индикаторы") or "ElvUI индикаторы"
		return "Настройки параметров для: |cff00ff00" .. label .. "|r"
	end
	label = L and (L["Classic WoW Nameplates"] or "Классические WoW") or "Классические WoW"
	return "Настройки параметров для: |cFFFFD700" .. label .. "|r"
end

local function Num(v, fallback)
	v = tonumber(v)
	if v == nil then return fallback end
	return v
end

local function ResolveFontPath(fontName)
	if _G.Autolos and _G.Autolos.ResolveFontPath then
		local path = _G.Autolos.ResolveFontPath({ font = fontName })
		if path and path ~= "" then return path end
	end
	if SarychUI and SarychUI.Media and SarychUI.Media.GetFont then
		local path = SarychUI.Media:GetFont(fontName)
		if path and path ~= "" then return path end
	end
	return "Fonts\\FRIZQT__.TTF"
end

local function ResolveOutline(profile)
	if _G.Autolos and _G.Autolos.ResolveFontOutline then
		return _G.Autolos.ResolveFontOutline(profile)
	end
	local outline = profile and (profile.fontOutline or profile.fontFlags) or "OUTLINE"
	if outline == "NONE" or outline == "" or outline == nil then
		return ""
	end
	return outline
end

function Preview:SetActiveKey(key)
	self._activeKey = key
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, self._live[key])
	else
		self:RefreshAll()
	end
end

function Preview:SetLiveValue(key, value)
	self._live[key] = value
	self._activeKey = key
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, value)
	else
		for _, inst in ipairs(self._instances) do
			if inst and inst.LayoutLive then
				inst:LayoutLive(key)
			elseif inst and inst.Refresh then
				inst:Refresh()
			end
		end
	end
end

function Preview:ClearLiveValue(key)
	if key then
		self._live[key] = nil
	else
		for k in pairs(self._live) do
			self._live[k] = nil
		end
	end
end

function Preview:RefreshAll()
	local alive = {}
	for _, inst in ipairs(self._instances) do
		if inst and inst.GetParent and inst:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then
				inst:Refresh()
			end
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
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	self._instances = {}
end

function Preview:Create(parent, noticeText)
	self:ClearStickyHosts()
	local T = SarychUI.OptionsTheme

	-- Single frame (no spacer overlay) — avoids empty gap under the toggle.
	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(PREVIEW_H)
	host.spacer = host -- RefreshAll compatibility

	if type(noticeText) == "function" then
		host._noticeTextFn = noticeText
		local ok, text = pcall(noticeText)
		noticeText = (ok and text) or ""
	elseif noticeText == nil then
		noticeText = ModeNotice()
		host._noticeTextFn = ModeNotice
	end

	if T and T.ApplyFlat then
		T:ApplyFlat(host, T.colors.panelBg or { 0.07, 0.07, 0.09, 0.97 }, T.colors.borderSoft)
	else
		local bg = host:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
	end

	local notice = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	notice:SetPoint("TOPLEFT", 8, -5)
	notice:SetPoint("TOPRIGHT", -8, -5)
	notice:SetJustifyH("LEFT")
	notice:SetText(tostring(noticeText or ""))
	host._notice = notice

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -(NOTICE_H + 2))
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	local plate = CreateFrame("Frame", nil, stage)
	plate:SetSize(PLATE_W, PLATE_H)
	plate:SetFrameLevel((stage:GetFrameLevel() or 1) + 1)
	local plateEdge = plate:CreateTexture(nil, "BACKGROUND")
	plateEdge:SetPoint("TOPLEFT", -1, 1)
	plateEdge:SetPoint("BOTTOMRIGHT", 1, -1)
	plateEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
	plateEdge:SetVertexColor(0, 0, 0, 0.85)
	local plateBg = plate:CreateTexture(nil, "ARTWORK")
	plateBg:SetAllPoints()
	plateBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	plateBg:SetVertexColor(0.12, 0.72, 0.12, 0.95)

	-- Inherit a real font template so SetText always works; draw immediately.
	local dist = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	dist:SetJustifyH("RIGHT")
	dist:SetTextColor(1, 1, 1, 1)
	dist:SetText("43")
	dist:ClearAllPoints()
	dist:SetPoint("RIGHT", plate, "LEFT", -8, 0)
	host._dist = dist
	host._plate = plate

	local function LiveOr(key, fallback)
		if Preview._live[key] ~= nil then
			return Preview._live[key]
		end
		return fallback
	end

	local function IsActive(key)
		return Preview._activeKey == key
	end

	local function Layout()
		local profile = ActiveProfile()
		local fontSize = Num(LiveOr("fontSize", profile.fontSize), 12)
		local offsetX = Num(LiveOr("offsetX", profile.offsetX), DEFAULT_OFFSET_X)
		local offsetY = Num(LiveOr("offsetY", profile.offsetY), DEFAULT_OFFSET_Y)
		local shadowX = Num(LiveOr("shadowX", profile.shadowX), 2)
		local shadowY = Num(LiveOr("shadowY", profile.shadowY), -1)
		local fontPath = ResolveFontPath(LiveOr("font", profile.font) or profile.font)
		local outlineProfile = {
			fontOutline = LiveOr("fontOutline", profile.fontOutline or profile.fontFlags),
			fontFlags = profile.fontFlags,
		}
		local outline = ResolveOutline(outlineProfile)

		local mod = Module()
		local mode = mod and mod.GetAutolosProfileMode and mod:GetAutolosProfileMode() or "classic"
		local isElvui = mode == "elvui"

		-- Place plate so real offsets keep "43" inside the stage.
		-- classic: CENTER+CENTER with ~-95 → plate toward the right
		-- elvui: RIGHT of text to LEFT of health with ~-6 → plate more centered
		plate:ClearAllPoints()
		if isElvui then
			plate:SetPoint("CENTER", stage, "CENTER", 20, -2)
		else
			plate:SetPoint("CENTER", stage, "CENTER", 70, -2)
		end

		local okFont = pcall(dist.SetFont, dist, fontPath, fontSize, outline)
		if not okFont then
			pcall(dist.SetFont, dist, "Fonts\\FRIZQT__.TTF", fontSize or 12, outline or "OUTLINE")
		end
		if dist.SetShadowOffset then
			dist:SetShadowOffset(shadowX, shadowY)
			dist:SetShadowColor(0, 0, 0, 1)
		end

		-- Always show sample "43" — never wait for DLL / real distance.
		dist:SetText("43")
		dist:Show()

		-- Mirror Autolos.ApplyLayout exactly:
		-- classic → CENTER of nameplate + offset
		-- elvui   → RIGHT of text to LEFT of health + offset
		dist:ClearAllPoints()
		if isElvui then
			dist:SetPoint("RIGHT", plate, "LEFT", offsetX, offsetY)
		else
			dist:SetPoint("CENTER", plate, "CENTER", offsetX, offsetY)
		end

		local active = IsActive("offsetX") or IsActive("offsetY") or IsActive("fontSize")
			or IsActive("shadowX") or IsActive("shadowY") or IsActive("font") or IsActive("fontOutline")
		if active then
			dist:SetTextColor(ACTIVE_BORDER[1], ACTIVE_BORDER[2], ACTIVE_BORDER[3], 1)
		else
			dist:SetTextColor(1, 1, 1, 1)
		end
	end

	host.LayoutLive = function()
		Layout()
	end
	host.RefreshLayout = Layout
	host.Refresh = function()
		if host._notice and type(host._noticeTextFn) == "function" then
			local ok, text = pcall(host._noticeTextFn)
			if ok and text then
				host._notice:SetText(tostring(text))
			end
		end
		Layout()
	end

	host:SetScript("OnSizeChanged", Layout)
	host:SetScript("OnShow", Layout)
	host:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		Layout()
	end)

	tinsert(Preview._instances, host)
	Layout()
	return host
end
