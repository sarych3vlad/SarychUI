-- SarychUI optional compatibility layer for wow_optimize.dll
-- No hard dependency on the DLL or !LuaBoost.

local pairs, ipairs, type, tostring, wipe = pairs, ipairs, type, tostring, wipe
local CreateFrame = CreateFrame
local GetTime = GetTime
local IsAddOnLoaded = IsAddOnLoaded

DEBUG_WOW_OPTIMIZE_COMPAT = DEBUG_WOW_OPTIMIZE_COMPAT or false

local Compat = {
	_dllDetected = false,
	_active = false,
	_adaptations = {},
	_pollInProgress = false,
	_nameplateRangeConfirmed = false,
	_nameplateRangeNotDetected = false,
}

SarychUI.Compatibility = Compat

-- Marker globals exported by wow_optimize.dll (see !LuaBoost hasDLL()).
local WOW_OPTIMIZE_MARKERS = {
	"LUABOOST_DLL_LOADED",
	"LUABOOST_DLL_GC_ACTIVE",
	"LUABOOST_DLL_LUA_ALLOC",
}

local DLL_REGISTRY = {
	{
		id = "wow_optimize",
		label = "wow_optimize.dll",
		hasMarker = true,
	},
	{
		id = "awesome_wotlk",
		label = "AwesomeWotlkLib.dll",
		hasMarker = true,
	},
	{
		id = "nameplate_range",
		label = "nameplate_range.dll",
		hasMarker = true,
	},
}

-- Candidate globals for nameplate_range.dll (none confirmed in SarychUI/autolos sources).
local NAMEPLATE_RANGE_MARKERS = {
	"NameplateRange",
	"nameplate_range",
	"NAMEPLATE_RANGE",
	"NameplateRange_IsLoaded",
	"GetNameplateDistance",
}
local rangePollFrame
local RANGE_SCAN_THROTTLE = 2
local DLL_STATUS_CACHE_TTL = 1.5
-- No pure time-based "not detected": wait until nameplates are visible, then decide
-- from whether DLL range frames appear with them.
local NAMEPLATE_RANGE_VISIBLE_MISS_THRESHOLD = 2

local INTERVALS = {
	bubbleScan = { normal = 0.15, optimize = 0.25 },
	platesAuraRefreshDelay = { normal = 0, optimize = 0.10 },
	platesAuraConfigureDelay = { normal = 0, optimize = 0.15 },
	platesCleanup = { normal = 5, optimize = 8 },
}

local function GetProfileCompat()
	local db = SarychUI and SarychUI.db and SarychUI.db.profile
	return db and db.compatibility
end

function Compat:GetMode()
	local compat = GetProfileCompat()
	local mode = compat and compat.wowOptimize
	if mode == "enabled" or mode == "disabled" or mode == "auto" then
		return mode
	end
	return "auto"
end

function Compat:DetectWowOptimizeDll()
	if self._dllDetected then
		return true
	end
	for i = 1, #WOW_OPTIMIZE_MARKERS do
		if _G[WOW_OPTIMIZE_MARKERS[i]] ~= nil then
			self._dllDetected = true
			return true
		end
	end
	return false
end

function Compat:DetectDll()
	return self:DetectWowOptimizeDll()
end

function Compat:DetectAwesomeWotlkDll()
	if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" and type(C_NamePlate.GetNamePlateForUnit) == "function" then
		return true
	end
	if GetCVar and GetCVar("nameplateDistance") ~= nil then
		return true
	end
	return false
end

-- nameplate_range.dll API used by autolos (addons/autolos/main.lua IdentifyFrame):
-- anonymous WorldFrame children expose .guid and .range updated by the DLL.
-- Same heuristic as autolos IdentifyFrame: anonymous WorldFrame child with DLL range data.
function Compat.IsNameplateRangeFrame(frame)
	if not frame or type(frame.GetName) ~= "function" then
		return false
	end
	if frame:GetName() then
		return false
	end
	return frame.guid ~= nil and frame.range ~= nil
end

function Compat:ConfirmNameplateRangeSession()
	self._nameplateRangeConfirmed = true
	self._nameplateRangeNotDetected = false
	self:StopNameplateRangePoll()
	self:InvalidateDllStatusCache()
	self:NotifyDllStatusUi()
end

function Compat:MarkNameplateRangeNotDetected()
	if self._nameplateRangeConfirmed or self._nameplateRangeNotDetected then
		return
	end
	self._nameplateRangeNotDetected = true
	self:StopNameplateRangePoll()
	self:InvalidateDllStatusCache()
	self:NotifyDllStatusUi()
end

function Compat:NotifyDllStatusUi()
	-- Do not full-rebuild /sui options here: NameplateRange poll finishes
	-- "after a while" and was closing open dropdowns (e.g. Bags mode select).
	-- Status getters are live; refresh only when options are open and idle.
	local OC = SarychUI and SarychUI.OptionsCore
	if not OC or not OC._open or not OC.Refresh then
		return
	end
	if SarychUI.OptionsWidgets and SarychUI.OptionsWidgets.IsDropdownOpen and SarychUI.OptionsWidgets:IsDropdownOpen() then
		OC._refreshAfterDropdown = true
		return
	end
	OC:Refresh()
end

function Compat:IsNameplateRangeConfirmed()
	return self._nameplateRangeConfirmed == true
end

function Compat:DetectNameplateRangeMarker()
	for i = 1, #NAMEPLATE_RANGE_MARKERS do
		local value = _G[NAMEPLATE_RANGE_MARKERS[i]]
		if value ~= nil then
			local valueType = type(value)
			if valueType == "function" or valueType == "table" or valueType == "boolean" or valueType == "number" then
				return true
			end
		end
	end
	return false
end

-- Prebuilt plate frame names: 1..40 Blizzard, 41..80 ENP. Avoids 80 string
-- concatenations on every poll tick.
local plateNameCache = {}
for i = 1, 40 do
	plateNameCache[i] = "NamePlate" .. i
	plateNameCache[i + 40] = "ENP_NamePlate" .. i
end

-- True when nameplates are on screen (AwesomeWotlk C_NamePlate or named plate frames).
-- Used to stop "waiting" once plates exist but DLL range frames do not.
function Compat:HasVisibleNameplates()
	if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
		local plates = C_NamePlate.GetNamePlates()
		if type(plates) == "table" and #plates > 0 then
			return true
		end
	end
	-- Named plate frames (Blizzard / ENP). Avoid anonymous WorldFrame heuristics — too many false positives.
	local names = plateNameCache
	for i = 1, 40 do
		local plate = _G[names[i]] or _G[names[i + 40]]
		if plate and plate.IsShown and plate:IsShown() then
			return true
		end
	end
	return false
end

-- Reused buffer so the WorldFrame walk calls GetChildren() once per scan.
local worldChildren = {}

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

function Compat:ScanNameplateRangeFrames()
	if self._nameplateRangeConfirmed then
		return true
	end
	if not WorldFrame or not WorldFrame.GetNumChildren then
		return false
	end
	local numChildren = FillFrom(worldChildren, WorldFrame:GetChildren())
	for i = 1, numChildren do
		if Compat.IsNameplateRangeFrame(worldChildren[i]) then
			return true
		end
	end
	return false
end

function Compat:TryScanNameplateRangeFramesThrottled()
	if self._nameplateRangeConfirmed then
		return true
	end
	local now = GetTime()
	if self._lastRangeScanTime and (now - self._lastRangeScanTime) < RANGE_SCAN_THROTTLE then
		return self._lastRangeScanResult == true
	end
	self._lastRangeScanTime = now
	local found = self:ScanNameplateRangeFrames()
	self._lastRangeScanResult = found
	return found
end

function Compat:DetectNameplateRangeDll()
	return self:GetNameplateRangeDetectionState() == "detected"
end

function Compat:GetNameplateRangeDetectionState()
	if self._nameplateRangeConfirmed then
		return "detected"
	end
	if self._nameplateRangeNotDetected then
		return "not_detected"
	end
	if self:DetectNameplateRangeMarker() then
		self:ConfirmNameplateRangeSession()
		return "detected"
	end
	if self:TryScanNameplateRangeFramesThrottled() then
		self:ConfirmNameplateRangeSession()
		return "detected"
	end
	-- Keep waiting: DLL frames only appear with live nameplates. Do not time out.
	self:StartNameplateRangePoll()
	return "waiting_for_nameplates"
end

function Compat:StopNameplateRangePoll()
	if rangePollFrame then
		rangePollFrame:SetScript("OnUpdate", nil)
		rangePollFrame = nil
	end
end

function Compat:StartNameplateRangePoll()
	if self._nameplateRangeConfirmed or self._nameplateRangeNotDetected or rangePollFrame then
		return
	end

	self._nameplateVisibleMisses = 0
	rangePollFrame = CreateFrame("Frame")
	local elapsed = 0
	rangePollFrame:SetScript("OnUpdate", function(_, dt)
		if Compat._nameplateRangeConfirmed or Compat._nameplateRangeNotDetected then
			Compat:StopNameplateRangePoll()
			return
		end
		elapsed = elapsed + (dt or 0)
		if elapsed < 2 then
			return
		end
		elapsed = 0
		if Compat:ScanNameplateRangeFrames() or Compat:DetectNameplateRangeMarker() then
			Compat:ConfirmNameplateRangeSession()
			return
		end
		-- Only conclude "not detected" after nameplates are on screen without DLL frames.
		if Compat:HasVisibleNameplates() then
			Compat._nameplateVisibleMisses = (Compat._nameplateVisibleMisses or 0) + 1
			if Compat._nameplateVisibleMisses >= NAMEPLATE_RANGE_VISIBLE_MISS_THRESHOLD then
				Compat:MarkNameplateRangeNotDetected()
				return
			end
		else
			Compat._nameplateVisibleMisses = 0
		end
		Compat:InvalidateDllStatusCache()
		Compat:NotifyDllStatusUi()
	end)
end

function Compat:IsDllPollInProgress()
	return self._pollInProgress == true
end

function Compat:GetDllDetectionState(id)
	for i = 1, #DLL_REGISTRY do
		local entry = DLL_REGISTRY[i]
		if entry.id == id then
			if id == "nameplate_range" then
				return self:GetNameplateRangeDetectionState()
			end
			if not entry.hasMarker then
				return "no_marker"
			end
			if id == "wow_optimize" then
				if self:DetectWowOptimizeDll() then
					return "detected"
				end
				if self:IsDllPollInProgress() and self:GetMode() == "auto" then
					return "checking"
				end
				return "not_detected"
			end
			if id == "awesome_wotlk" then
				return self:DetectAwesomeWotlkDll() and "detected" or "not_detected"
			end
			return "not_detected"
		end
	end
	return "not_detected"
end

local STATUS_LABEL_KEYS = {
	detected = "Dll_Status_Detected",
	not_detected = "Dll_Status_NotDetected",
	checking = "Dll_Status_Checking",
	no_marker = "Dll_Status_NoMarker",
	api_detected = "Dll_Status_ApiDetected",
	waiting_for_nameplates = "Dll_Status_WaitingNameplates",
}

local STATUS_LABEL_FALLBACK = {
	detected = "Обнаружен",
	not_detected = "Не обнаружен",
	checking = "Проверка...",
	no_marker = "Нет Lua-маркера",
	api_detected = "API обнаружен",
	waiting_for_nameplates = "Ожидает неймплейты",
}

local function GetStatusLabel(state)
	local L = SarychUI and SarychUI.L
	local key = STATUS_LABEL_KEYS[state]
	if L and key and L[key] then
		return L[key]
	end
	return STATUS_LABEL_FALLBACK[state] or STATUS_LABEL_FALLBACK.not_detected
end

function Compat:AreAllDllsDetected()
	for i = 1, #DLL_REGISTRY do
		if self:GetDllDetectionState(DLL_REGISTRY[i].id) ~= "detected" then
			return false
		end
	end
	return true
end

-- True when every DLL row has a final answer (detected / not_detected / …), not still checking/waiting.
function Compat:AreAllDllStatusesResolved()
	for i = 1, #DLL_REGISTRY do
		local state = self:GetDllDetectionState(DLL_REGISTRY[i].id)
		if state == "checking" or state == "waiting_for_nameplates" then
			return false
		end
	end
	return true
end

function Compat:FormatDllStatusLine(entry)
	local state = self:GetDllDetectionState(entry.id)
	local colors = {
		detected = "00ff00",
		not_detected = "ff4444",
		checking = "ffaa00",
		no_marker = "808080",
		api_detected = "00ccff",
		waiting_for_nameplates = "ffcc00",
	}
	local color = colors[state] or colors.not_detected
	return string.format("|cffcccccc%s:|r |cff%s%s|r", entry.label, color, GetStatusLabel(state))
end

function Compat:GetDllDetectionDetails(id)
	if id == "wow_optimize" then
		return "LUABOOST_DLL_LOADED / LUABOOST_DLL_GC_ACTIVE / LUABOOST_DLL_LUA_ALLOC"
	end
	if id == "awesome_wotlk" then
		return "C_NamePlate.GetNamePlates / CVar nameplateDistance"
	end
	if id == "nameplate_range" then
		return "WorldFrame child .guid + .range (autolos); no Lua load marker — session cache after first plate"
	end
	return nil
end

function Compat:InvalidateDllStatusCache()
	self._dllStatusBlockCache = nil
	self._dllStatusBlockCacheTime = nil
end

function Compat:GetDllStatusBlock(forceRefresh)
	local now = GetTime()
	if not forceRefresh
		and self._dllStatusBlockCache
		and self._dllStatusBlockCacheTime
		and (now - self._dllStatusBlockCacheTime) < DLL_STATUS_CACHE_TTL then
		return self._dllStatusBlockCache
	end

	local lines = {}
	for i = 1, #DLL_REGISTRY do
		lines[#lines + 1] = self:FormatDllStatusLine(DLL_REGISTRY[i])
	end
	local block = table.concat(lines, "\n")
	self._dllStatusBlockCache = block
	self._dllStatusBlockCacheTime = now
	return block
end

function Compat:GetDllRegistry()
	return DLL_REGISTRY
end

function Compat:IsLuaBoostLoaded()
	if _G.LUABOOST_LOADED then
		return true
	end
	if not IsAddOnLoaded then
		return false
	end
	return IsAddOnLoaded("!LuaBoost") == true or IsAddOnLoaded("LuaBoost") == true
end

function Compat:IsWowOptimizeActive()
	local mode = self:GetMode()
	if mode == "disabled" then
		return false
	end
	if mode == "enabled" then
		return true
	end
	return self:DetectDll()
end

function Compat:IsDebugEnabled()
	if DEBUG_WOW_OPTIMIZE_COMPAT then
		return true
	end
	local compat = GetProfileCompat()
	return compat and compat.debug == true
end

function Compat:Log(msg, ...)
	if not self:IsDebugEnabled() then return end
	if select("#", ...) > 0 then
		msg = string.format(msg, ...)
	end
	if SarychUI.GetScopedChatPrefix then
		print(SarychUI:GetScopedChatPrefix("WowOptimize Compat") .. " " .. tostring(msg))
	else
		SarychUI:Print("|cffFFAA00WowOptimize Compat:|r " .. msg)
	end
end

function Compat:LogDllStatuses()
	if not self:IsDebugEnabled() then return end
	for i = 1, #DLL_REGISTRY do
		local entry = DLL_REGISTRY[i]
		local details = self:GetDllDetectionDetails(entry.id)
		if details then
			self:Log("%s: %s (%s)", entry.label, GetStatusLabel(self:GetDllDetectionState(entry.id)), details)
		else
			self:Log("%s: %s", entry.label, GetStatusLabel(self:GetDllDetectionState(entry.id)))
		end
	end
end

function Compat:RecordAdaptation(key, detail)
	self._adaptations[key] = detail or true
	self:Log("adaptation: %s (%s)", key, tostring(detail or "on"))
end

function Compat:ClearAdaptations()
	wipe(self._adaptations)
end

function Compat:GetAdaptations()
	return self._adaptations
end

function Compat:GetInterval(name, fallbackNormal, fallbackOptimize)
	local entry = INTERVALS[name]
	local normal = entry and entry.normal or fallbackNormal or 0.1
	local optimize = entry and entry.optimize or fallbackOptimize or normal
	if self:IsWowOptimizeActive() then
		return optimize
	end
	return normal
end

function Compat:ShouldSkipCombatLogClear()
	return self:IsWowOptimizeActive()
end

function Compat:ShouldThrottleWorldFrameScans()
	return self:IsWowOptimizeActive()
end

local function ApplyCLFixState(active)
	if not CL_Fix or not CL_Fix.f then return end
	if active then
		CL_Fix.f:SetScript("OnUpdate", nil)
	else
		local enabled = true
		if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.CL_Fix then
			enabled = SarychUI.db.profile.addons.CL_Fix.enabled ~= false
		elseif CL_FixEnabled ~= nil then
			enabled = CL_FixEnabled ~= false
		end
		if enabled and CL_Fix.fCLFix then
			CL_Fix.f:SetScript("OnUpdate", CL_Fix.fCLFix)
		end
	end
end

function Compat:ApplyAdaptations()
	local active = self:IsWowOptimizeActive()
	if active == self._active and next(self._adaptations) then
		return
	end

	local wasActive = self._active
	self._active = active
	self:ClearAdaptations()

	if not active then
		if wasActive then
			ApplyCLFixState(false)
			self:Log("compatibility mode inactive — restored defaults")
		end
		return
	end

	ApplyCLFixState(true)
	self:RecordAdaptation("CL_Fix", "CombatLogClearEntries disabled")

	if self:IsLuaBoostLoaded() then
		self:RecordAdaptation("LuaBoost", "companion addon detected")
	end

	self:Log(
		"active (mode=%s, dll=%s, !LuaBoost=%s)",
		self:GetMode(),
		tostring(self:DetectDll()),
		tostring(self:IsLuaBoostLoaded())
	)
	self:LogDllStatuses()
end

function Compat:Refresh(forceLog)
	local prevActive = self._active
	self:ApplyAdaptations()
	if forceLog or (prevActive ~= self._active) then
		local status = self._active and "active" or "inactive"
		self:Log("status: %s (setting=%s, dll=%s)", status, self:GetMode(), tostring(self:DetectDll()))
	end
end

function Compat:GetStatusText()
	local active = self:IsWowOptimizeActive()
	local mode = self:GetMode()
	local dll = self:DetectDll()
	if active then
		return string.format("active (mode=%s, dll=%s)", mode, dll and "yes" or "forced")
	end
	return string.format("inactive (mode=%s, dll=%s)", mode, dll and "yes" or "no")
end

local pollFrame

function Compat:StartDllPoll()
	if pollFrame then return end
	if self:GetMode() ~= "auto" then
		self:Refresh(true)
		return
	end

	self._pollInProgress = true
	pollFrame = CreateFrame("Frame")
	local elapsed = 0
	local timer = 0
	pollFrame:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + (dt or 0)
		timer = timer + (dt or 0)
		if timer >= 0.5 then
			timer = 0
			if Compat:DetectWowOptimizeDll() then
				Compat._pollInProgress = false
				Compat:Refresh(true)
				Compat:InvalidateDllStatusCache()
				Compat:NotifyDllStatusUi()
				self:SetScript("OnUpdate", nil)
				pollFrame = nil
				return
			end
		end
		if elapsed >= 5 then
			Compat._pollInProgress = false
			Compat:Refresh(true)
			Compat:InvalidateDllStatusCache()
			Compat:NotifyDllStatusUi()
			self:SetScript("OnUpdate", nil)
			pollFrame = nil
		end
	end)
end

function Compat:Initialize()
	self:Refresh(true)
	self:StartDllPoll()
	self:StartNameplateRangePoll()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		Compat:Initialize()
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)
