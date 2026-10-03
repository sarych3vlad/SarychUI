-- SarychUI client capability detection.
-- Runtime owns wow_optimize detection/backend selection; this module only
-- renders that result beside the optional nameplate APIs in System overview.

local pairs, type = pairs, type
local CreateFrame, GetTime = CreateFrame, GetTime
local pcall, select = pcall, select

local Compat = {
	_nameplateRangeConfirmed = false,
	_nameplateRangeNotDetected = false,
	_rangePollActive = false,
}

SarychUI.Compatibility = Compat

local DLL_REGISTRY = {
	{ id = "wow_optimize", label = "wow_optimize.dll" },
	{ id = "awesome_wotlk", label = "AwesomeWotlkLib.dll" },
	{ id = "nameplate_range", label = "nameplate_range.dll" },
}

local NAMEPLATE_RANGE_MARKERS = {
	"NameplateRange",
	"nameplate_range",
	"NAMEPLATE_RANGE",
	"NameplateRange_IsLoaded",
	"GetNameplateDistance",
}

local RANGE_SCAN_THROTTLE = 2
local DLL_STATUS_CACHE_TTL = 1.5
local NAMEPLATE_RANGE_VISIBLE_MISS_THRESHOLD = 2
local rangePollFrame

local STATUS_LABEL_KEYS = {
	detected = "Dll_Status_Detected",
	supported = "Dll_Status_Supported",
	incompatible = "Dll_Status_Incompatible",
	inactive = "Dll_Status_Inactive",
	not_detected = "Dll_Status_NotDetected",
	waiting_for_nameplates = "Dll_Status_WaitingNameplates",
}

local STATUS_LABEL_FALLBACK = {
	detected = "Обнаружен",
	supported = "Поддерживается",
	incompatible = "Несовместим",
	inactive = "Неактивен",
	not_detected = "Не обнаружен",
	waiting_for_nameplates = "Ожидает неймплейты",
}

local function GetStatusLabel(state)
	local L = SarychUI and SarychUI.L
	local key = STATUS_LABEL_KEYS[state]
	return (L and key and L[key]) or STATUS_LABEL_FALLBACK[state] or STATUS_LABEL_FALLBACK.not_detected
end

function Compat:DetectAwesomeWotlkDll()
	if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function"
		and type(C_NamePlate.GetNamePlateForUnit) == "function" then
		return true
	end
	return GetCVar and GetCVar("nameplateDistance") ~= nil or false
end

function Compat.IsNameplateRangeFrame(frame)
	if not frame or type(frame.GetName) ~= "function" or frame:GetName() then return false end
	return frame.guid ~= nil and frame.range ~= nil
end

function Compat:InvalidateDllStatusCache()
	self._dllStatusBlockCache = nil
	self._dllStatusBlockCacheTime = nil
end

function Compat:NotifyDllStatusUi()
	local options = SarychUI and SarychUI.OptionsCore
	if not options or not options._open or not options.Refresh then return end
	if SarychUI.OptionsWidgets and SarychUI.OptionsWidgets.IsDropdownOpen
		and SarychUI.OptionsWidgets:IsDropdownOpen() then
		options._refreshAfterDropdown = true
		return
	end
	options:Refresh()
end

function Compat:ConfirmNameplateRangeSession()
	self._nameplateRangeConfirmed = true
	self._nameplateRangeNotDetected = false
	self:StopNameplateRangePoll()
	self:InvalidateDllStatusCache()
	self:NotifyDllStatusUi()
end

function Compat:MarkNameplateRangeNotDetected()
	if self._nameplateRangeConfirmed or self._nameplateRangeNotDetected then return end
	self._nameplateRangeNotDetected = true
	self:StopNameplateRangePoll()
	self:InvalidateDllStatusCache()
	self:NotifyDllStatusUi()
end

function Compat:IsNameplateRangeConfirmed()
	return self._nameplateRangeConfirmed == true
end

function Compat:DetectNameplateRangeMarker()
	for i = 1, #NAMEPLATE_RANGE_MARKERS do
		local value = _G[NAMEPLATE_RANGE_MARKERS[i]]
		local valueType = type(value)
		if valueType == "function" or valueType == "table" or valueType == "boolean" or valueType == "number" then
			return true
		end
	end
	return false
end

local plateNameCache = {}
for i = 1, 40 do
	plateNameCache[i] = "NamePlate" .. i
	plateNameCache[i + 40] = "ENP_NamePlate" .. i
end

function Compat:HasVisibleNameplates()
	if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
		local plates = C_NamePlate.GetNamePlates()
		if type(plates) == "table" and #plates > 0 then return true end
	end
	for i = 1, 40 do
		local plate = _G[plateNameCache[i]] or _G[plateNameCache[i + 40]]
		if plate and plate.IsShown and plate:IsShown() then return true end
	end
	return false
end

local worldChildren = {}
local function FillWorldChildren(...)
	local count = select("#", ...)
	for i = 1, count do worldChildren[i] = select(i, ...) end
	for i = count + 1, #worldChildren do worldChildren[i] = nil end
	return count
end

function Compat:ScanNameplateRangeFrames()
	if self._nameplateRangeConfirmed then return true end
	if not WorldFrame or not WorldFrame.GetNumChildren then return false end
	local count = FillWorldChildren(WorldFrame:GetChildren())
	for i = 1, count do
		if Compat.IsNameplateRangeFrame(worldChildren[i]) then return true end
	end
	return false
end

function Compat:TryScanNameplateRangeFramesThrottled()
	if self._nameplateRangeConfirmed then return true end
	local now = SarychUI and SarychUI.Runtime and SarychUI.Runtime:GetTimeCached() or GetTime()
	if self._lastRangeScanTime and (now - self._lastRangeScanTime) < RANGE_SCAN_THROTTLE then
		return self._lastRangeScanResult == true
	end
	self._lastRangeScanTime = now
	self._lastRangeScanResult = self:ScanNameplateRangeFrames()
	return self._lastRangeScanResult
end

function Compat:DetectNameplateRangeDll()
	return self:GetNameplateRangeDetectionState() == "detected"
end

function Compat:GetNameplateRangeDetectionState()
	if self._nameplateRangeConfirmed then return "detected" end
	if self._nameplateRangeNotDetected then return "not_detected" end
	if self:DetectNameplateRangeMarker() or self:TryScanNameplateRangeFramesThrottled() then
		self:ConfirmNameplateRangeSession()
		return "detected"
	end
	self:StartNameplateRangePoll()
	return "waiting_for_nameplates"
end

function Compat:PollNameplateRange()
	if self._nameplateRangeConfirmed or self._nameplateRangeNotDetected then
		self:StopNameplateRangePoll()
		return
	end
	if self:ScanNameplateRangeFrames() or self:DetectNameplateRangeMarker() then
		self:ConfirmNameplateRangeSession()
		return
	end
	if self:HasVisibleNameplates() then
		self._nameplateVisibleMisses = (self._nameplateVisibleMisses or 0) + 1
		if self._nameplateVisibleMisses >= NAMEPLATE_RANGE_VISIBLE_MISS_THRESHOLD then
			self:MarkNameplateRangeNotDetected()
			return
		end
	else
		self._nameplateVisibleMisses = 0
	end
	self:InvalidateDllStatusCache()
	self:NotifyDllStatusUi()
end

function Compat:StopNameplateRangePoll()
	if not self._rangePollActive then return end
	self._rangePollActive = false
	if SarychUI and SarychUI.Runtime then
		SarychUI.Runtime:UnregisterUpdate("compat.nameplate_range")
	end
	if rangePollFrame then
		rangePollFrame:SetScript("OnUpdate", nil)
		rangePollFrame = nil
	end
end

function Compat:StartNameplateRangePoll()
	if self._nameplateRangeConfirmed or self._nameplateRangeNotDetected or self._rangePollActive then return end
	self._rangePollActive = true
	self._nameplateVisibleMisses = 0
	if SarychUI and SarychUI.Runtime then
		SarychUI.Runtime:RegisterUpdate("compat.nameplate_range", 2, function() Compat:PollNameplateRange() end)
		return
	end
	-- Early fallback; Runtime replaces this path once the addon finishes loading.
	rangePollFrame = CreateFrame("Frame")
	local elapsed = 0
	rangePollFrame:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + (delta or 0)
		if elapsed >= 2 then elapsed = 0; Compat:PollNameplateRange() end
	end)
end

function Compat:GetDllDetectionState(id)
	if id == "wow_optimize" then
		local runtime = SarychUI and SarychUI.Runtime
		if not runtime or not runtime.GetDLLState then return "not_detected" end
		local state = runtime:GetDLLState()
		if state == runtime.WOW_OPTIMIZE_SUPPORTED then return "supported" end
		if state == runtime.WOW_OPTIMIZE_INCOMPATIBLE then return "inactive" end
		return "not_detected"
	end
	if id == "awesome_wotlk" then
		return self:DetectAwesomeWotlkDll() and "detected" or "not_detected"
	end
	if id == "nameplate_range" then return self:GetNameplateRangeDetectionState() end
	return "not_detected"
end

function Compat:AreAllDllsDetected()
	for i = 1, #DLL_REGISTRY do
		local state = self:GetDllDetectionState(DLL_REGISTRY[i].id)
		if state ~= "detected" and state ~= "supported" then return false end
	end
	return true
end

function Compat:AreAllDllStatusesResolved()
	for i = 1, #DLL_REGISTRY do
		if self:GetDllDetectionState(DLL_REGISTRY[i].id) == "waiting_for_nameplates" then return false end
	end
	return true
end

function Compat:FormatDllStatusLine(entry)
	local state = self:GetDllDetectionState(entry.id)
	local color = (state == "detected" or state == "supported") and "00ff00"
		or (state == "incompatible" and "ff8800")
		or (state == "inactive" and "ffcc00")
		or (state == "waiting_for_nameplates" and "ffcc00" or "ff4444")
	local label = entry.label
	-- The Runtime keeps "supported" as an internal capability state, but the
	-- System overview reports the user-facing fact that the DLL was detected.
	local displayState = entry.id == "wow_optimize" and state == "supported" and "detected" or state
	local status = GetStatusLabel(displayState)
	if entry.id == "wow_optimize" then
		local info = SarychUI and SarychUI.Runtime and SarychUI.Runtime:GetDLLInfo()
		if info and info.version then label = label .. " v" .. tostring(info.version) end
	end
	return string.format("|cffcccccc%s:|r |cff%s%s|r", label, color, status)
end

function Compat:GetDllDetectionDetails(id)
	if id == "wow_optimize" then return "LUABOOST_DLL_* / LuaBoostC_*" end
	if id == "awesome_wotlk" then return "C_NamePlate.GetNamePlates / CVar nameplateDistance" end
	if id == "nameplate_range" then return "WorldFrame child .guid + .range" end
	return nil
end

function Compat:GetDllStatusBlock(forceRefresh)
	local now = GetTime()
	if not forceRefresh and self._dllStatusBlockCache and self._dllStatusBlockCacheTime
		and (now - self._dllStatusBlockCacheTime) < DLL_STATUS_CACHE_TTL then
		return self._dllStatusBlockCache
	end
	local lines = {}
	for i = 1, #DLL_REGISTRY do lines[#lines + 1] = self:FormatDllStatusLine(DLL_REGISTRY[i]) end
	self._dllStatusBlockCache = table.concat(lines, "\n")
	self._dllStatusBlockCacheTime = now
	return self._dllStatusBlockCache
end

function Compat:GetDllRegistry()
	return DLL_REGISTRY
end

-- Kept for callers that use compatibility-adjusted intervals. Native runtime
-- throttling is now the only optimization layer, so the normal value wins.
function Compat:GetInterval(_, fallbackNormal)
	return fallbackNormal or 0.1
end

function Compat:GetStatusText()
	return self:GetDllStatusBlock(true)
end

function Compat:Refresh()
	self:InvalidateDllStatusCache()
	self:StartNameplateRangePoll()
end

function Compat:Initialize()
	self:Refresh()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
	Compat:Initialize()
	self:UnregisterEvent("PLAYER_LOGIN")
end)
