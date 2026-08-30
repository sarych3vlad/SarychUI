local PATTERN = " %0.1f "
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_OUTLINE = "OUTLINE"
local DEFAULT_SHADOW_X = 2
local DEFAULT_SHADOW_Y = -1
local ALPHA_DECREASE_BEGIN_AT = 40
local ALPHA_DECREASE_PERC_PER_YARD = 80
local ALPHA_DECREASE_LIMIT = 0
local ALPHA_DECREASE_NON_TARGET_LIMIT = 50

autolosEnabled = autolosEnabled or true

local Autolos = {}
_G.Autolos = Autolos

local math_max, math_min = math.max, math.min
local format = string.format
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local driverFrame = CreateFrame("Frame")
local targetGuid
local lastChildrensCount = 0

local DEBUG_AUTOLOS_PERF = false
local DEBUG_AUTOLOS_POSITION = false

local pendingLayoutRetry = {}
local layoutRetryScheduled = false

local function PerfAutolosLog(stage, startTime)
	if not DEBUG_AUTOLOS_PERF then return end
	if startTime then
		local prefix = (SarychUI and SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("Autolos Perf")) or "|cffffd200SarychUI Autolos Perf:|r"
		print(string.format("%s %s: %.2f ms", prefix, stage, debugprofilestop() - startTime))
	end
end

local function DebugPositionLog(nameplate, source, details)
	if not DEBUG_AUTOLOS_POSITION or not nameplate then return end
	if nameplate.__autolosPosDebugDone then return end
	nameplate.__autolosPosDebugDone = true
	local anchorName = "nil"
	if details.anchor then
		anchorName = details.anchor.GetName and (details.anchor:GetName() or "unnamed") or "frame"
		if details.anchor == nameplate.UnitFrame and nameplate.UnitFrame then
			anchorName = "UnitFrame"
		elseif nameplate.UnitFrame and details.anchor == nameplate.UnitFrame.Health then
			anchorName = "Health"
		elseif details.anchor == nameplate then
			anchorName = "root"
		end
	end
	print(string.format(
		"|cff66ccff[autolos pos]|r source=%s mode=%s anchor=%s point=%s rel=%s offsetX=%s offsetY=%s textPointChanged=%s",
		tostring(source),
		tostring(details.mode or "?"),
		anchorName,
		tostring(details.point or "?"),
		tostring(details.relativePoint or "?"),
		tostring(details.offsetX or "?"),
		tostring(details.offsetY or "?"),
		tostring(details.textPointChanged or false)
	))
end

local function ScheduleLayoutRetry(nameplate)
	if not nameplate then return end
	pendingLayoutRetry[nameplate] = true
	if layoutRetryScheduled then return end
	layoutRetryScheduled = true
	local function flushRetries()
		layoutRetryScheduled = false
		if not Autolos.IsEnabled() then
			wipe(pendingLayoutRetry)
			return
		end
		local profile = Autolos.GetActiveProfile()
		for plate in pairs(pendingLayoutRetry) do
			pendingLayoutRetry[plate] = nil
			if plate.fontStringRange then
				Autolos.ApplyLayout(plate, plate.fontStringRange, profile)
			end
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.1, flushRetries)
	else
		flushRetries()
	end
end

local function CopyTable(src, dest)
	if type(src) ~= "table" then return src end
	if type(dest) ~= "table" then dest = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dest[k] = CopyTable(v, dest[k])
		else
			dest[k] = v
		end
	end
	return dest
end

local function GetAddonDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		return SarychUI.db.profile.addons.autolos
	end
	return nil
end

-- Lightweight, throttled debug logging. Disabled by default; enable with
-- /run SarychUI.db.profile.addons.autolos.debug = true
local lastDebugTime = {}
local function IsDebug()
	local db = GetAddonDB()
	return db and db.debug == true
end

local function DebugLog(nameplate, reason)
	if not IsDebug() then return end
	local key = tostring(nameplate) .. "|" .. tostring(reason)
	local now = (GetTime and GetTime()) or 0
	if lastDebugTime[key] and (now - lastDebugTime[key]) < 2 then
		return
	end
	lastDebugTime[key] = now
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffAutolos|r " .. tostring(reason))
	end
end

function Autolos.IsEnabled()
	local db = GetAddonDB()
	if db then
		return db.enabled ~= false
	end
	return autolosEnabled ~= false
end

function Autolos.GetNameplateMode()
	if SarychUI and SarychUI.GetNameplateMode then
		return SarychUI:GetNameplateMode()
	end
	return "classic"
end

local function IsElvUIMode()
	return Autolos.GetNameplateMode() == "elvui"
end

function Autolos.GetDefaultProfile(mode)
	local defaults = SarychUI and SarychUI.defaults and SarychUI.defaults.profile and SarychUI.defaults.profile.addons and SarychUI.defaults.profile.addons.autolos
	if defaults and defaults.profiles and defaults.profiles[mode] then
		return CopyTable(defaults.profiles[mode], {})
	end
	if defaults and defaults.profiles and defaults.profiles.classic then
		return CopyTable(defaults.profiles.classic, {})
	end
	return {
		font = "Friz Quadrata TT",
		fontSize = 12,
		fontOutline = DEFAULT_FONT_OUTLINE,
		shadowX = DEFAULT_SHADOW_X,
		shadowY = DEFAULT_SHADOW_Y,
		offsetX = -95,
		offsetY = -9,
	}
end

function Autolos.ResolveFontOutline(profile)
	local outline = profile and (profile.fontOutline or profile.fontFlags) or DEFAULT_FONT_OUTLINE
	if outline == "NONE" or outline == "" or outline == nil then
		return ""
	end
	return outline
end

function Autolos.EnsureProfiles()
	local db = GetAddonDB()
	if not db then return end

	db.profiles = db.profiles or {}
	for _, mode in ipairs({ "classic", "elvui" }) do
		if not db.profiles[mode] then
			db.profiles[mode] = Autolos.GetDefaultProfile(mode)
		end
		local profile = db.profiles[mode]
		local profileDefaults = Autolos.GetDefaultProfile(mode)
		for key, value in pairs(profileDefaults) do
			if profile[key] == nil then
				profile[key] = value
			end
		end
		if profile.fontOutline == nil and profile.fontFlags then
			profile.fontOutline = profile.fontFlags
		end
	end

	if not db.profileVersion or db.profileVersion < 2 then
		db.profileVersion = 2
	end

	-- ElvUI totemSupport defaults to on (migrate profiles that still have the old off default).
	if db.profileVersion < 3 then
		local elvui = db.profiles and db.profiles.elvui
		if elvui then
			elvui.totemSupport = true
		end
		db.profileVersion = 3
	end
end

function Autolos.GetActiveProfile()
	Autolos.EnsureProfiles()
	local db = GetAddonDB()
	if not db or not db.profiles then
		return Autolos.GetDefaultProfile("classic")
	end

	local mode = IsElvUIMode() and "elvui" or "classic"
	return db.profiles[mode] or Autolos.GetDefaultProfile(mode)
end

function Autolos.ResolveFontPath(profile)
	local font = profile and profile.font or "Friz Quadrata TT"
	if type(font) ~= "string" or font == "" then
		font = "Friz Quadrata TT"
	end

	if LSM then
		if LSM:IsValid("font", font) then
			return LSM:Fetch("font", font)
		end
	end

	if SarychUI and SarychUI.Media and SarychUI.Media.GetFont then
		local path = SarychUI.Media:GetFont(font)
		if path and path ~= "" then
			return path
		end
	end

	if font:find("\\") or font:find("/") then
		return font
	end

	return FALLBACK_FONT
end

function Autolos.GetElvUIHealthAnchor(nameplate)
	if not nameplate or not nameplate.UnitFrame then
		return nil
	end
	return nameplate.UnitFrame.Health or nil
end

local function GetElvUINamePlatesModule()
	local engine = _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
	if engine and engine.GetModule then
		return engine:GetModule("NamePlates", true)
	end
	return nil
end

-- ElvUI "Icon Only" totem (or unique unit): Health/Name hidden, IconFrame shown.
function Autolos.IsElvUITotemIconPlate(nameplate)
	local unitFrame = nameplate and nameplate.UnitFrame
	if not unitFrame or not unitFrame.IconOnlyChanged then
		return false
	end
	local iconFrame = unitFrame.IconFrame
	if not iconFrame or (iconFrame.IsShown and not iconFrame:IsShown()) then
		return false
	end
	-- Prefer real totems; UniqueUnits with icon-only get the same layout (Health is hidden).
	local NP = GetElvUINamePlatesModule()
	if NP and NP.Totems and unitFrame.UnitName then
		if NP.Totems[unitFrame.UnitName] then
			return true
		end
		-- Icon-only unique units still need a left-of-icon anchor.
		if NP.UniqueUnits and NP.UniqueUnits[unitFrame.UnitName] then
			return true
		end
	end
	-- IconOnlyChanged is only set for totem/unique filters — treat as icon plate.
	return true
end

function Autolos.GetElvUITotemIconAnchor(nameplate)
	if not Autolos.IsElvUITotemIconPlate(nameplate) then
		return nil
	end
	return nameplate.UnitFrame.IconFrame
end

function Autolos.GetElvUIDistanceAlpha(nameplate)
	local unitFrame = nameplate and nameplate.UnitFrame
	if not unitFrame then
		return 1
	end

	local alpha = unitFrame:GetAlpha() or 1
	if unitFrame.Name and unitFrame.Name:IsShown() then
		local nameAlpha = unitFrame.Name:GetAlpha()
		if nameAlpha and nameAlpha > 0 and nameAlpha < 1 then
			alpha = alpha * nameAlpha
		end
	end

	if alpha < 0 then
		alpha = 0
	elseif alpha > 1 then
		alpha = 1
	end

	return alpha
end

function Autolos.UpdateElvUIAlpha(nameplate)
	if not IsElvUIMode() or not nameplate or not nameplate.fontStringRange then
		return
	end

	local fontString = nameplate.fontStringRange
	local alpha = Autolos.GetElvUIDistanceAlpha(nameplate)
	if fontString.autolosSyncedAlpha ~= alpha then
		fontString:SetAlpha(alpha)
		fontString.autolosSyncedAlpha = alpha
	end
end

function Autolos.ApplyTextStyle(fontString, profile)
	if not fontString then return end
	profile = profile or Autolos.GetActiveProfile()

	local fontPath = Autolos.ResolveFontPath(profile)
	local fontSize = tonumber(profile.fontSize) or 12
	local outline = Autolos.ResolveFontOutline(profile)
	local shadowX = tonumber(profile.shadowX) or DEFAULT_SHADOW_X
	local shadowY = tonumber(profile.shadowY) or DEFAULT_SHADOW_Y

	if fontString.autolosFontPath == fontPath
		and fontString.autolosFontSize == fontSize
		and fontString.autolosFontOutline == outline
		and fontString.autolosShadowX == shadowX
		and fontString.autolosShadowY == shadowY then
		return
	end

	fontString:SetFont(fontPath, fontSize, outline)
	local _, height = fontString:GetFont()
	if not height or height <= 0 then
		fontPath = FALLBACK_FONT
		fontString:SetFont(fontPath, fontSize, outline)
	end

	fontString:SetShadowOffset(shadowX, shadowY)
	fontString:SetShadowColor(0, 0, 0, 1)

	local text = fontString:GetText()
	if text and text ~= "" then
		fontString:SetText(text)
	end

	fontString.autolosFontPath = fontPath
	fontString.autolosFontSize = fontSize
	fontString.autolosFontOutline = outline
	fontString.autolosShadowX = shadowX
	fontString.autolosShadowY = shadowY
end

function Autolos.ApplyLayout(nameplate, fontString, profile)
	if not nameplate or not fontString then return false end
	profile = profile or Autolos.GetActiveProfile()

	local offsetX = tonumber(profile.offsetX) or -95
	local offsetY = tonumber(profile.offsetY) or -9
	local mode = IsElvUIMode() and "elvui" or "classic"
	local point = "CENTER"
	local relativePoint = "CENTER"
	local anchor = nameplate

	if mode == "elvui" then
		point = "RIGHT"
		relativePoint = "LEFT"
		local anchorKind = "health"

		-- Totem (icon-only) plates: Health/Name are hidden — sit immediately left of IconFrame.
		if profile.totemSupport and Autolos.IsElvUITotemIconPlate(nameplate) then
			anchor = Autolos.GetElvUITotemIconAnchor(nameplate)
			offsetX = -2
			offsetY = 0
			anchorKind = "totemIcon"
		elseif profile.anchorToName then
			anchor = nameplate.UnitFrame and nameplate.UnitFrame.Name
			offsetX = 0
			offsetY = 0
			anchorKind = "name"
		else
			anchor = Autolos.GetElvUIHealthAnchor(nameplate)
			anchorKind = "health"
		end

		if not anchor then
			ScheduleLayoutRetry(nameplate)
			DebugPositionLog(nameplate, "ApplyLayout-missingAnchor", {
				mode = mode,
				anchor = nil,
				point = point,
				relativePoint = relativePoint,
				offsetX = offsetX,
				offsetY = offsetY,
				textPointChanged = false,
			})
			DebugLog(nameplate, "ElvUI anchor (" .. anchorKind .. ") not ready, layout retry scheduled")
			return false
		end

		if nameplate.autolosAnchorMode == "elvui"
			and nameplate.autolosAnchorKind == anchorKind
			and fontString.autolosAnchor == anchor
			and fontString.autolosPoint == point
			and fontString.autolosRelativePoint == relativePoint
			and fontString.autolosOffsetX == offsetX
			and fontString.autolosOffsetY == offsetY then
			DebugPositionLog(nameplate, "ApplyLayout-cacheHit", {
				mode = mode,
				anchor = anchor,
				point = point,
				relativePoint = relativePoint,
				offsetX = offsetX,
				offsetY = offsetY,
				textPointChanged = false,
			})
			return true
		end

		fontString:ClearAllPoints()
		fontString:SetPoint(point, anchor, relativePoint, offsetX, offsetY)
		fontString.autolosAnchor = anchor
		fontString.autolosPoint = point
		fontString.autolosRelativePoint = relativePoint
		fontString.autolosOffsetX = offsetX
		fontString.autolosOffsetY = offsetY
		nameplate.autolosAnchorMode = "elvui"
		nameplate.autolosAnchorKind = anchorKind
		DebugPositionLog(nameplate, "ApplyLayout-applied", {
			mode = mode,
			anchor = anchor,
			point = point,
			relativePoint = relativePoint,
			offsetX = offsetX,
			offsetY = offsetY,
			textPointChanged = true,
		})
		DebugLog(nameplate, "applied elvui layout (" .. anchorKind .. ")")
		return true
	end

	if nameplate.autolosAnchorMode == "classic"
		and fontString.autolosAnchor == anchor
		and fontString.autolosPoint == point
		and fontString.autolosRelativePoint == relativePoint
		and fontString.autolosOffsetX == offsetX
		and fontString.autolosOffsetY == offsetY then
		return true
	end

	fontString:ClearAllPoints()
	fontString:SetPoint(point, anchor, relativePoint, offsetX, offsetY)
	fontString.autolosAnchor = anchor
	fontString.autolosPoint = point
	fontString.autolosRelativePoint = relativePoint
	fontString.autolosOffsetX = offsetX
	fontString.autolosOffsetY = offsetY
	nameplate.autolosAnchorMode = "classic"
	DebugLog(nameplate, "applied classic layout")
	return true
end

function Autolos.ApplyFont(fontString, profile)
	Autolos.ApplyTextStyle(fontString, profile)
end

function Autolos.ApplyPosition(nameplate, fontString, profile)
	return Autolos.ApplyLayout(nameplate, fontString, profile)
end

-- Reused buffer so WorldFrame walks call GetChildren() once per scan instead of
-- once per index.
local worldChildren = {}

local function FillWorldChildren(...)
	local n = select("#", ...)
	for i = 1, n do
		worldChildren[i] = select(i, ...)
	end
	for i = n + 1, #worldChildren do
		worldChildren[i] = nil
	end
	return n
end

local refreshChildren = {}

local function FillRefreshChildren(...)
	local n = select("#", ...)
	for i = 1, n do
		refreshChildren[i] = select(i, ...)
	end
	for i = n + 1, #refreshChildren do
		refreshChildren[i] = nil
	end
	return n
end

local function ForEachDistanceText(callback)
	local numChildren = FillWorldChildren(WorldFrame:GetChildren())
	for i = 1, numChildren do
		local child = worldChildren[i]
		if child and child.fontStringRange then
			callback(child, child.fontStringRange)
		end
	end
end

function Autolos.ApplyTextStylesAll()
	if not Autolos.IsEnabled() then return end
	local profile = Autolos.GetActiveProfile()
	ForEachDistanceText(function(_, fontString)
		Autolos.ApplyTextStyle(fontString, profile)
	end)
end

function Autolos.ApplyLayoutsAll()
	if not Autolos.IsEnabled() then return end
	local profile = Autolos.GetActiveProfile()
	ForEachDistanceText(function(nameplate, fontString)
		Autolos.ApplyLayout(nameplate, fontString, profile)
	end)
end

function Autolos.ApplyAlphasAll()
	if not Autolos.IsEnabled() or not IsElvUIMode() then return end
	ForEachDistanceText(function(nameplate)
		Autolos.UpdateElvUIAlpha(nameplate)
	end)
end

function Autolos.RefreshExistingPlate(nameplate, profile)
	if not nameplate or not nameplate.fontStringRange then return end
	profile = profile or Autolos.GetActiveProfile()

	if IsElvUIMode() then
		-- Always re-apply: totem icon-only can flip Health↔IconFrame while mode stays "elvui".
		Autolos.ApplyLayout(nameplate, nameplate.fontStringRange, profile)
		Autolos.UpdateElvUIAlpha(nameplate)
	end
end

function Autolos.RefreshNameplate(nameplate, options)
	if not nameplate or not nameplate.fontStringRange then return end
	options = options or {}
	local profile = Autolos.GetActiveProfile()

	if options.alphaOnly then
		Autolos.UpdateElvUIAlpha(nameplate)
	elseif options.layoutOnly then
		Autolos.ApplyLayout(nameplate, nameplate.fontStringRange, profile)
	elseif options.styleOnly then
		Autolos.ApplyTextStyle(nameplate.fontStringRange, profile)
	else
		Autolos.ApplyTextStyle(nameplate.fontStringRange, profile)
		Autolos.ApplyLayout(nameplate, nameplate.fontStringRange, profile)
		if IsElvUIMode() then
			Autolos.UpdateElvUIAlpha(nameplate)
		end
	end
end

local function IdentifyFrame(self)
	if self.guid and self.range and not self:GetName() then
		return "NamePlate"
	end
end

local function ApplyClassicPlateAlpha(nameplate, range, guid)
	local alpha = 1
	if targetGuid == guid then
		alpha = 1
	elseif range > ALPHA_DECREASE_BEGIN_AT then
		alpha = math_max(ALPHA_DECREASE_LIMIT, 100 - (range - ALPHA_DECREASE_BEGIN_AT) * ALPHA_DECREASE_PERC_PER_YARD)
		if targetGuid then alpha = math_min(alpha, ALPHA_DECREASE_NON_TARGET_LIMIT) end
		alpha = alpha / 100
	elseif targetGuid then
		alpha = ALPHA_DECREASE_NON_TARGET_LIMIT / 100
	else
		alpha = 1
	end
	if nameplate.autolosLastAlpha ~= alpha then
		nameplate:SetAlpha(alpha)
		nameplate.autolosLastAlpha = alpha
	end
end

local function nameplate_OnUpdate(self, elapsed)
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	if not Autolos.IsEnabled() then
		if self.fontStringRange and self.fontStringRange.autolosLastText ~= "" then
			self.fontStringRange:SetText("")
			self.fontStringRange.autolosLastText = ""
		end
		return
	end

	local range, guid = self.range, self.guid
	if not self.fontStringRange then return end

	local text
	if range == 0 then
		text = ""
	else
		text = format(PATTERN, range)
	end
	if self.fontStringRange.autolosLastText ~= text then
		self.fontStringRange:SetText(text)
		self.fontStringRange.autolosLastText = text
	end

	if IsElvUIMode() then
		Autolos.UpdateElvUIAlpha(self)
	else
		ApplyClassicPlateAlpha(self, range, guid)
	end
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("AutoLOS", "NameplateOnUpdateSlow", perfStart, self.GetName and self:GetName() or guid, 2)
	end
end

-- Single robust entry point for a detected nameplate.
-- Base logic (find plate, create text, show, keep updating) must never be broken
-- by the visual layer (font / layout / alpha). Each visual step is isolated so a
-- failure falls back to safe defaults instead of leaving the plate without text.
function Autolos.EnsurePlate(nameplate, profile)
	if not nameplate then return false end
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil

	if not Autolos.IsEnabled() then
		if nameplate.fontStringRange then
			nameplate.fontStringRange:SetText("")
		end
		DebugLog(nameplate, "skipped: autolos disabled")
		return false
	end

	profile = profile or Autolos.GetActiveProfile()

	local fontString = nameplate.fontStringRange
	local justCreated = false
	if not fontString then
		fontString = nameplate:CreateFontString(nil, "OVERLAY")
		nameplate.fontStringRange = fontString
		justCreated = true
		DebugLog(nameplate, "created text")
	end

	-- Visual: font/shadow/outline. Failure must not stop the text from rendering.
	local okStyle = pcall(Autolos.ApplyTextStyle, fontString, profile)
	if not okStyle then
		pcall(fontString.SetFont, fontString, FALLBACK_FONT, tonumber(profile.fontSize) or 12, Autolos.ResolveFontOutline(profile))
		DebugLog(nameplate, "font missing fallback")
	end

	-- Visual: layout. New plates only — existing plates use RefreshExistingPlate.
	local okLayout = pcall(Autolos.ApplyLayout, nameplate, fontString, profile)
	if not okLayout and not IsElvUIMode() then
		local offsetX = tonumber(profile.offsetX) or -95
		local offsetY = tonumber(profile.offsetY) or -9
		pcall(function()
			fontString:ClearAllPoints()
			fontString:SetPoint("CENTER", nameplate, "CENTER", offsetX, offsetY)
			nameplate.autolosAnchorMode = "classic"
		end)
		DebugLog(nameplate, "layout error classic fallback anchor")
	elseif not okLayout and IsElvUIMode() then
		ScheduleLayoutRetry(nameplate)
	end

	-- Visual: ElvUI alpha sync (classic alpha is handled in OnUpdate).
	if IsElvUIMode() then
		pcall(Autolos.UpdateElvUIAlpha, nameplate)
	end

	-- Base: update distance value and keep it updating.
	if justCreated then
		if SarychUI_PerfLog then
			SarychUI_PerfLog("AutoLOS", "CreatePlateText", nameplate.GetName and nameplate:GetName() or "nameplate")
		end
		nameplate_OnUpdate(nameplate)
		nameplate:HookScript("OnUpdate", nameplate_OnUpdate)
	end

	fontString:Show()
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("AutoLOS", "EnsurePlateSlow", perfStart, nameplate.GetName and nameplate:GetName() or "nameplate", 3)
	end
	return true
end

local function InitNamePlate(frame)
	Autolos.EnsurePlate(frame)
end

function Autolos.CleanupOrphanedDistanceText()
	ForEachDistanceText(function(plate, fontString)
		if IdentifyFrame(plate) ~= "NamePlate" then
			fontString:SetText("")
		end
	end)
end

function Autolos.RefreshAllNameplates()
	local refreshStart = DEBUG_AUTOLOS_PERF and debugprofilestop() or nil
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	Autolos.CleanupOrphanedDistanceText()
	-- Own buffer: CleanupOrphanedDistanceText above uses the shared one.
	local numChildren = FillRefreshChildren(WorldFrame:GetChildren())
	local enabled = Autolos.IsEnabled()
	local profile = enabled and Autolos.GetActiveProfile() or nil
	for i = 1, numChildren do
		local child = refreshChildren[i]
		if not child then
		elseif IdentifyFrame(child) == "NamePlate" then
			if enabled then
				if child.fontStringRange then
					Autolos.RefreshExistingPlate(child, profile)
				else
					Autolos.EnsurePlate(child, profile)
				end
			elseif child.fontStringRange then
				child.fontStringRange:SetText("")
			end
		elseif child.fontStringRange then
			if enabled then
				Autolos.RefreshExistingPlate(child, profile)
			else
				child.fontStringRange:SetText("")
			end
		end
	end
	PerfAutolosLog("RefreshAllNameplates (" .. numChildren .. " children)", refreshStart)
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("AutoLOS", "RefreshAllNameplatesSlow", perfStart, numChildren .. " children", 3)
	end
end

function Autolos.RescanNameplates()
	if SarychUI_PerfLog then
		SarychUI_PerfLog("AutoLOS", "RescanNameplates", WorldFrame:GetNumChildren())
	end
	lastChildrensCount = WorldFrame:GetNumChildren()
	Autolos.RefreshAllNameplates()
end

function Autolos.ApplySettings()
	Autolos.EnsureProfiles()

	if not Autolos.IsEnabled() then
		ForEachDistanceText(function(_, fontString)
			fontString:SetText("")
		end)
		return
	end

	Autolos.RescanNameplates()
	Autolos.ApplyTextStylesAll()
	Autolos.ApplyLayoutsAll()

	local layout = SarychUI and SarychUI.AutolosElvUI
	if layout and layout.TryInstallHooks then
		layout.TryInstallHooks()
	end
end

local function iterateChildren(...)
	for i = 1, select("#", ...) do
		local object = select(i, ...)
		if IdentifyFrame(object) == "NamePlate" then
			InitNamePlate(object)
		end
	end
end

local targetScanPending = false

local function SyncWorldFrameChildren()
	if not Autolos.IsEnabled() then
		return
	end
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	local numChildren = WorldFrame:GetNumChildren()
	if numChildren > lastChildrensCount then
		if SarychUI_PerfLog then
			SarychUI_PerfLog("AutoLOS", "WorldFrameChildrenAdded", tostring(lastChildrensCount) .. "->" .. tostring(numChildren))
		end
		iterateChildren(select(lastChildrensCount + 1, WorldFrame:GetChildren()))
	elseif numChildren < lastChildrensCount then
		if SarychUI_PerfLog then
			SarychUI_PerfLog("AutoLOS", "WorldFrameChildrenRemoved", tostring(lastChildrensCount) .. "->" .. tostring(numChildren))
		end
		Autolos.CleanupOrphanedDistanceText()
	end
	lastChildrensCount = numChildren
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("AutoLOS", "SyncWorldFrameChildrenSlow", perfStart, numChildren .. " children", 3)
	end
end

driverFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
if C_NamePlate then
	driverFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
end
driverFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_TARGET_CHANGED" then
		if SarychUI_PerfLog then
			SarychUI_PerfLog("AutoLOS", "PLAYER_TARGET_CHANGED", UnitGUID("target"))
		end
		targetGuid = UnitGUID("target")
		if targetScanPending then
			return
		end
		targetScanPending = true
		local function runTargetScan()
			targetScanPending = false
			Autolos.RescanNameplates()
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0.1, runTargetScan)
		else
			runTargetScan()
		end
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		local function runPlateScan()
			if Autolos.IsEnabled() then
				Autolos.RescanNameplates()
			end
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0.05, runPlateScan)
		else
			runPlateScan()
		end
	end
end)

local FULL_RESCAN_INTERVAL = 0.25
local LIGHTWEIGHT_INTERVAL = 2.0
local lightweightElapsed = 0
local fullRescanElapsed = 0

if SarychUI and SarychUI.RegisterPerfOnUpdate then
	SarychUI:RegisterPerfOnUpdate("autolos.driver", driverFrame)
end

driverFrame:SetScript("OnUpdate", function(_, elapsed)
	if not Autolos.IsEnabled() then return end
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil

	local dt = elapsed or 0

	-- Fast path: pick up new plates / clear stale text when WorldFrame child count changes.
	local numChildren = WorldFrame:GetNumChildren()
	if numChildren ~= lastChildrensCount then
		SyncWorldFrameChildren()
	end

	-- Lightweight path: ElvUI alpha sync only; classic plates update via per-plate OnUpdate.
	lightweightElapsed = lightweightElapsed + dt
	if lightweightElapsed >= LIGHTWEIGHT_INTERVAL then
		lightweightElapsed = 0
		if IsElvUIMode() then
			Autolos.ApplyAlphasAll()
		end
	end

	-- Safety rescan: pick up plates when DLL attaches .guid/.range without child-count change.
	fullRescanElapsed = fullRescanElapsed + dt
	if fullRescanElapsed >= FULL_RESCAN_INTERVAL then
		fullRescanElapsed = 0
		Autolos.RescanNameplates()
	end
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("AutoLOS", "DriverOnUpdateSlow", perfStart, nil, 3)
	end
end)

return Autolos
