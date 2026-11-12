-- RaidRoll Wrapper for SarychUI
-- Single settings entry covers RaidRoll + RaidRoll_EPGP + RaidRoll_LootTracker

local ADDON_NAME = "RaidRoll"

local wrapper = {
	name = ADDON_NAME,
	title = "RaidRoll",
	author = "Musou, доработка Сарыч",
	version = "1.0",
	enabled = false,
	loaded = false,
}

if RaidRollEnabled == nil then RaidRollEnabled = true end

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return RaidRollEnabled ~= false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function ApplyRaidRollRuntime(enable)
	RaidRollEnabled = enable and true or false
	if not enable then
		if RR_RollFrame and RR_RollFrame.Hide then RR_RollFrame:Hide() end
		if RR_LOOT_FRAME and RR_LOOT_FRAME.Hide then RR_LOOT_FRAME:Hide() end
		if RR_OptionsFrame and RR_OptionsFrame.Hide then RR_OptionsFrame:Hide() end
	end
end

function wrapper:IsRuntimeEnabled()
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyRaidRollRuntime(enable)
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	wrapper.loaded = true
	RaidRollEnabled = wrapper.enabled
	if wrapper.enabled then
		ApplyRaidRollRuntime(true)
	else
		ApplyRaidRollRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	wrapper.loaded = true
	ApplyRaidRollRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyRaidRollRuntime(false)
	return true
end

function wrapper:GetOptions()
    local result={type="group",name="RaidRoll",order=50,childGroups="tab",args={
        enabled={type="toggle",name="Включить",order=1,
            get=function() return wrapper:IsRuntimeEnabled() end,
            set=function(_,value) wrapper:SetRuntimeEnabled(value) end},
    }}
    for key,group in pairs(SarychUI_GetRaidRollOptions()) do
        group.hidden=function() return not wrapper:IsRuntimeEnabled() end
        result.args[key]=group
    end
    return result
end

local function RegisterWrapper()
	if SarychUI and SarychUI.RegisterAddOn then
		SarychUI:RegisterAddOn(ADDON_NAME, wrapper)
		return true
	end
	return false
end

if not RegisterWrapper() then
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function(self, event, addonName)
		if event == "ADDON_LOADED" and addonName == "SarychUI" then
			if RegisterWrapper() then
				self:UnregisterEvent("ADDON_LOADED")
			end
		elseif event == "PLAYER_LOGIN" then
			if RegisterWrapper() then
				self:UnregisterEvent("PLAYER_LOGIN")
			end
		end
	end)
end

return wrapper
