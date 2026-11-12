-- Auctionator wrapper for SarychUI
-- Runtime and native SUI settings for the embedded Auctionator.

local ADDON_NAME = "Auctionator"

local wrapper = {
	name = ADDON_NAME,
	title = "Auctionator",
	author = "Zirco",
	version = "2.6.8",
	loaded = true,
	enabled = false,
}

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled == true
	end
	return false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function IsStandaloneAuctionatorEnabled()
	if SarychUI_IsStandaloneAuctionatorEnabled then
		return SarychUI_IsStandaloneAuctionatorEnabled()
	end
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("Auctionator")
	return loadable and enabled and true or false
end

local function ApplyAuctionatorRuntime(enable)
	AuctionatorEnabled = enable and true or false
	if enable then
		if Atr_OnLoad then
			Atr_OnLoad()
		end
		if Atr_Init and IsAddOnLoaded and IsAddOnLoaded("Blizzard_AuctionUI") then
			Atr_Init()
		end
	else
		if AuctionFrame and AuctionFrame:IsShown() and Atr_IsAuctionatorTab then
			local selectedTab = PanelTemplates_GetSelectedTab(AuctionFrame)
			if Atr_IsAuctionatorTab(selectedTab) and AuctionFrameTab1 then
				AuctionFrameTab1:Click()
			end
		end
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneAuctionatorEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneAuctionatorEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия Auctionator.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyAuctionatorRuntime(enable)
	if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneAuctionatorEnabled() then
		wrapper.enabled = false
		ApplyAuctionatorRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия Auctionator.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	if wrapper.enabled then
		ApplyAuctionatorRuntime(true)
	else
		ApplyAuctionatorRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyAuctionatorRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyAuctionatorRuntime(false)
	return true
end

function SarychUI_OpenAuctionatorConfig()
    if not SarychUI then return false end
    if not (SarychUI.IsSarychUIOptionsOpen and SarychUI:IsSarychUIOptionsOpen()) then
        SarychUI:OpenOptions()
    end
    local core = SarychUI.OptionsCore
    if not core then return false end
    core._addonListSelected = ADDON_NAME
    core:SelectSection("sui:addons")
    return true
end

function wrapper:OpenConfig()
    return SarychUI_OpenAuctionatorConfig()
end

function wrapper:GetOptions()
    return SarychUI:BuildAuctionatorOptions(self)
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
