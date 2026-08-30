-- WDM Wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "WDM"

local wrapper = {
	name = ADDON_NAME,
	author = "Trimitor",
	version = "1.0.9",
	enabled = false,
	loaded = false,
}

WDMEnabled = WDMEnabled ~= false

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return WDMEnabled
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	SarychUI.db.profile.addons[ADDON_NAME] = SarychUI.db.profile.addons[ADDON_NAME] or {}
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function IsStandaloneWDMEnabled()
	if not GetNumAddOns or not GetAddOnInfo then return false end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable = GetAddOnInfo(i)
		if name == ADDON_NAME then
			return loadable and enabled and true or false
		end
	end
	return false
end

local function ApplyWDMRuntime(enable)
	WDMEnabled = enable and true or false

	if WDM then
		if enable then
			if WDM.RegisterInterfaceOptions then
				WDM:RegisterInterfaceOptions()
			end
			if WDM.Enable and not WDM:IsEnabled() then
				WDM:Enable()
			end
		elseif WDM.Disable and WDM.IsEnabled and WDM:IsEnabled() then
			WDM:Disable()
		end
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1WDM|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneWDMEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneWDMEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Отключите отдельный аддон WDM|r — иначе встроенный модуль не запустится.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyWDMRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	WDMEnabled = wrapper.enabled
	wrapper.loaded = WDM ~= nil

	if IsStandaloneWDMEnabled() then
		wrapper.enabled = false
		WDMEnabled = false
		ApplyWDMRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Отключите отдельный аддон WDM|r — иначе встроенный модуль не запустится.")
		end
		return
	end

	if not wrapper.enabled then
		ApplyWDMRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyWDMRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyWDMRuntime(false)
	return true
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900WDM:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end

	ApplyWDMRuntime(true)

	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD then
		ACD:Open("WDM")
		return true
	end

	if InterfaceOptionsFrame_OpenToCategory and WDM and WDM.optionsFrame then
		InterfaceOptionsFrame_OpenToCategory(WDM.optionsFrame)
		return true
	end

	if SlashCmdList and SlashCmdList["WDM"] then
		SlashCmdList["WDM"]("")
		return true
	end

	return false
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "WDM",
		order = 16.6,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить WoW Dungeon Maps (WDM). При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			open = {
				type = "execute",
				name = "Открыть настройки WDM",
				desc = "Открыть окно настроек WDM (/wdm)",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					if SarychUI and SarychUI.OpenWDMConfig then
						SarychUI:OpenWDMConfig()
					elseif wrapper.OpenConfig then
						wrapper:OpenConfig()
					end
				end,
			},
			description = {
				type = "description",
				name = "Расширение карт подземелий для карты мира: POI, миникарта, микроподземелья и др.\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "Неизвестен")
					.. "\nВерсия: "
					.. (wrapper.version or "Неизвестна"),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneWDMEnabled() then
						return "|cffff0000Внимание:|r отключите отдельный аддон |cff1784d1WDM|r — иначе встроенный модуль не запустится."
					end
					return ""
				end,
				order = 4,
				width = "full",
			},
		},
	}
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
