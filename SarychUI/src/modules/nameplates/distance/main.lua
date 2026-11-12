local SuiTimer = select(2, ...).Compat.Timer
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

local pendingLayoutRetry = {}
local layoutRetryScheduled = false

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
	if SuiTimer and SuiTimer.After then
		SuiTimer.After(0.1, flushRetries)
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


function Autolos.IsEnabled()
    if autolosEnabled == false then return false end
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

local function GetClassicPlateVisual(nameplate)
	if not nameplate or not SarychUI or not SarychUI.GetModule then
		return nil
	end
	local hi = SarychUI:GetModule("health_indicators", true)
	if hi and hi.GetClassicPlateVisual then
		return hi:GetClassicPlateVisual(nameplate)
	end
	return nil
end

local function ResolveClassicAnchor(nameplate)
	return GetClassicPlateVisual(nameplate) or nameplate
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
		fontOutline = "NONE",
		shadowX = 0.5,
		shadowY = -0.5,
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

	-- Classic distance: no outline, softer shadow (old stock was OUTLINE / 2 / -1).
	if db.profileVersion < 4 then
		local classic = db.profiles and db.profiles.classic
		if classic then
			if classic.fontOutline == nil or classic.fontOutline == "OUTLINE" then
				classic.fontOutline = "NONE"
			end
			if classic.shadowX == nil or classic.shadowX == 2 then
				classic.shadowX = 0.5
			end
			if classic.shadowY == nil or classic.shadowY == -1 then
				classic.shadowY = -0.5
			end
		end
		db.profileVersion = 4
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
	if mode ~= "elvui" then
		anchor = ResolveClassicAnchor(nameplate)
		if fontString.GetParent and fontString.SetParent and fontString:GetParent() ~= anchor then
			fontString:SetParent(anchor)
		end
	end

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


			return false
		end

		if nameplate.autolosAnchorMode == "elvui"
			and nameplate.autolosAnchorKind == anchorKind
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
		nameplate.autolosAnchorMode = "elvui"
		nameplate.autolosAnchorKind = anchorKind


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
		local compat = SarychUI.Compatibility
		if compat and not compat:IsNameplateRangeConfirmed() then
			compat:ConfirmNameplateRangeSession()
		end
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

	if not Autolos.IsEnabled() then
		if self.fontStringRange and self.fontStringRange.autolosLastText ~= "" then
			self.fontStringRange:SetText("")
			self.fontStringRange.autolosLastText = ""
		end
		return
	end

	local range, guid = self.range, self.guid
	if not self.fontStringRange then return end

	local label = self.fontStringRange
	if label.autolosRawRange ~= range or label.autolosPattern ~= PATTERN then
		label.autolosRangeText = range == 0 and "" or format(PATTERN, range)
		label.autolosRawRange = range
		label.autolosPattern = PATTERN
	end
	local text = label.autolosRangeText
	if self.fontStringRange.autolosLastText ~= text then
		self.fontStringRange:SetText(text)
		self.fontStringRange.autolosLastText = text
	end

	if IsElvUIMode() then
		Autolos.UpdateElvUIAlpha(self)
	else
		ApplyClassicPlateAlpha(self, range, guid)
	end

end

-- Single robust entry point for a detected nameplate.
-- Base logic (find plate, create text, show, keep updating) must never be broken
-- by the visual layer (font / layout / alpha). Each visual step is isolated so a
-- failure falls back to safe defaults instead of leaving the plate without text.
function Autolos.EnsurePlate(nameplate, profile)
	if not nameplate then return false end


	if not Autolos.IsEnabled() then
		if nameplate.fontStringRange then
			nameplate.fontStringRange:SetText("")
		end

		return false
	end

	profile = profile or Autolos.GetActiveProfile()

	local fontString = nameplate.fontStringRange
	local justCreated = false
	if not fontString then
		local parent = nameplate
		if not IsElvUIMode() then
			parent = ResolveClassicAnchor(nameplate)
		end
		fontString = parent:CreateFontString(nil, "OVERLAY")
		nameplate.fontStringRange = fontString
		justCreated = true

	end

	-- Visual: font/shadow/outline. Failure must not stop the text from rendering.
	local okStyle = pcall(Autolos.ApplyTextStyle, fontString, profile)
	if not okStyle then
		pcall(fontString.SetFont, fontString, FALLBACK_FONT, tonumber(profile.fontSize) or 12, Autolos.ResolveFontOutline(profile))

	end

	-- Visual: layout. New plates only — existing plates use RefreshExistingPlate.
	local okLayout = pcall(Autolos.ApplyLayout, nameplate, fontString, profile)
	if not okLayout and not IsElvUIMode() then
		local offsetX = tonumber(profile.offsetX) or -95
		local offsetY = tonumber(profile.offsetY) or -9
		pcall(function()
			local anchor = ResolveClassicAnchor(nameplate)
			if fontString.SetParent then
				fontString:SetParent(anchor)
			end
			fontString:ClearAllPoints()
			fontString:SetPoint("CENTER", anchor, "CENTER", offsetX, offsetY)
			nameplate.autolosAnchorMode = "classic"
		end)

	elseif not okLayout and IsElvUIMode() then
		ScheduleLayoutRetry(nameplate)
	end

	-- Visual: ElvUI alpha sync (classic alpha is handled in OnUpdate).
	if IsElvUIMode() then
		pcall(Autolos.UpdateElvUIAlpha, nameplate)
	end

	-- Base: update distance value and keep it updating.
	if justCreated then

		nameplate_OnUpdate(nameplate)
		nameplate:HookScript("OnUpdate", nameplate_OnUpdate)
	end

	fontString:Show()

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

end

function Autolos.RescanNameplates()

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
local plateScanPending = false

local function SyncWorldFrameChildren()
	if not Autolos.IsEnabled() then
		return
	end

	local numChildren = WorldFrame:GetNumChildren()
	if numChildren > lastChildrensCount then

		iterateChildren(select(lastChildrensCount + 1, WorldFrame:GetChildren()))
	elseif numChildren < lastChildrensCount then

		Autolos.CleanupOrphanedDistanceText()
	end
	lastChildrensCount = numChildren

end

driverFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
if SarychUI.Compatibility:IsAwesomeWotlkEnabled() then
	driverFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
end
driverFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_TARGET_CHANGED" then

		targetGuid = UnitGUID("target")
		if targetScanPending then
			return
		end
		targetScanPending = true
		local function runTargetScan()
			targetScanPending = false
			Autolos.RescanNameplates()
		end
		if SuiTimer and SuiTimer.After then
			SuiTimer.After(0.1, runTargetScan)
		else
			runTargetScan()
		end
	elseif event == "NAME_PLATE_UNIT_ADDED" and SarychUI.Compatibility:IsAwesomeWotlkEnabled() then
		if plateScanPending then return end
		plateScanPending = true
		local function runPlateScan()
			plateScanPending = false
			if Autolos.IsEnabled() then
				Autolos.RescanNameplates()
			end
		end
		if SuiTimer and SuiTimer.After then
			SuiTimer.After(0.05, runPlateScan)
		else
			runPlateScan()
		end
	end
end)

local FULL_RESCAN_INTERVAL = 0.25
local LIGHTWEIGHT_INTERVAL = 2.0
local lightweightElapsed = 0
local fullRescanElapsed = 0

driverFrame:SetScript("OnUpdate", function(_, elapsed)
	if not Autolos.IsEnabled() then return end


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

end)


local ownedDriverUpdate = driverFrame:GetScript("OnUpdate")
function Autolos.SetRuntimeEnabled(enable)
    driverFrame:UnregisterAllEvents()
    driverFrame:SetScript("OnUpdate", enable and ownedDriverUpdate or nil)
    if enable then
        driverFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        if SarychUI.Compatibility:IsAwesomeWotlkEnabled() then driverFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED") end
    end
    Autolos.ApplySettings()
end

return Autolos
