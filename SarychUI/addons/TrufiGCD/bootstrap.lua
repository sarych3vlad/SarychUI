-- TrufiGCD bootstrap for SarychUI embedding
-- Cursor-like valve: core in TOC; runtime off until AceDB enables it.

TrufiGCDEnabled = false

function SarychUI_IsStandaloneTrufiGCDEnabled()
	if not GetNumAddOns or not GetAddOnInfo then
		return false
	end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable = GetAddOnInfo(i)
		if name == "TrufiGCD" and enabled and loadable then
			return true
		end
	end
	return false
end

local function HideTrufiQueues()
	if type(TrGCDQueueFr) == "table" then
		for i = 1, 12 do
			local fr = TrGCDQueueFr[i]
			if fr and fr.Hide then
				fr:Hide()
			end
		end
	end
end

local function NeuterTrufiRuntime()
	if TrGCDEventFrame then
		TrGCDEventFrame:SetScript("OnUpdate", nil)
		TrGCDEventFrame:UnregisterAllEvents()
	end
	if TrGCDEnterEventFrame then
		TrGCDEnterEventFrame:UnregisterAllEvents()
	end
	if TrGCDEventBuffFrame then
		TrGCDEventBuffFrame:UnregisterAllEvents()
	end
	HideTrufiQueues()
end

local function RestoreTrufiRuntime()
	if TrGCDEventFrame then
		TrGCDEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		TrGCDEventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		TrGCDEventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
		TrGCDEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		TrGCDEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
		if TrGCDUpdate then
			TrGCDEventFrame:SetScript("OnUpdate", TrGCDUpdate)
		end
		if BackPortedUnitEventCaller then
			TrGCDEventFrame:SetScript("OnEvent", BackPortedUnitEventCaller)
		end
	end
	if TrGCDEnterEventFrame and TrGCDEnterEventHandler then
		TrGCDEnterEventFrame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
		TrGCDEnterEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		TrGCDEnterEventFrame:SetScript("OnEvent", TrGCDEnterEventHandler)
	end
	if TrGCDEventBuffFrame and TrGCDEventBuffHandler then
		TrGCDEventBuffFrame:RegisterEvent("UNIT_AURA")
		TrGCDEventBuffFrame:SetScript("OnEvent", TrGCDEventBuffHandler)
	end
end

function SarychUI_ApplyTrufiGCDRuntime(enable)
	TrufiGCDEnabled = enable and true or false
	if enable then
		if TrufiGCDTryInitialize then
			TrufiGCDTryInitialize()
		end
		RestoreTrufiRuntime()
	else
		NeuterTrufiRuntime()
	end
end
