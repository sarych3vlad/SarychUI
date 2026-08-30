-- TrufiGCD wrapper for SarychUI
-- Cursor-like valve: enable immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "TrufiGCD"

local wrapper = {
	name = ADDON_NAME,
	title = "TrufiGCD",
	author = "stevemyz",
	version = "1.0",
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

local function IsStandaloneTrufiGCDEnabled()
	if SarychUI_IsStandaloneTrufiGCDEnabled then
		return SarychUI_IsStandaloneTrufiGCDEnabled()
	end
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("TrufiGCD")
	return loadable and enabled and true or false
end

local function ApplyTrufiGCDRuntime(enable)
	if SarychUI_ApplyTrufiGCDRuntime then
		SarychUI_ApplyTrufiGCDRuntime(enable)
	else
		TrufiGCDEnabled = enable and true or false
		if enable and TrufiGCDTryInitialize then
			TrufiGCDTryInitialize()
		end
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1TrufiGCD|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneTrufiGCDEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneTrufiGCDEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия TrufiGCD.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyTrufiGCDRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneTrufiGCDEnabled() then
		wrapper.enabled = false
		ApplyTrufiGCDRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия TrufiGCD.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	ApplyTrufiGCDRuntime(wrapper.enabled)
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyTrufiGCDRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyTrufiGCDRuntime(false)
	return true
end

local function OpenTrufiGCDInterfaceOptions()
	ApplyTrufiGCDRuntime(true)
	if not TrGCDGUI then
		return false
	end

	if SarychUI and SarychUI.CloseOptions then
		SarychUI:CloseOptions()
	end

	if InterfaceOptionsFrame and InterfaceOptionsFrame.Show then
		InterfaceOptionsFrame:Show()
	end

	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(TrGCDGUI)
		InterfaceOptionsFrame_OpenToCategory(TrGCDGUI)
	end

	return true
end

function SarychUI_OpenTrufiGCDConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900TrufiGCD:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end
	if IsStandaloneTrufiGCDEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия TrufiGCD.|r Отключите её в списке аддонов.")
		end
		return false
	end

	local deferFrame = CreateFrame("Frame")
	deferFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		if not OpenTrufiGCDInterfaceOptions() then
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffff8080TrufiGCD:|r настройки недоступны. Проверьте Lua errors.")
			end
		end
	end)
	return true
end

function wrapper:OpenConfig()
	return SarychUI_OpenTrufiGCDConfig()
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "TrufiGCD",
		order = 18,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить TrufiGCD. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
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
				name = "Открыть настройки TrufiGCD",
				desc = "Открыть окно настроек TrufiGCD (/tgcd)",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					wrapper:OpenConfig()
				end,
			},
			description = {
				type = "description",
				name = "Показывает очередь последних использованных заклинаний.\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "stevemyz")
					.. "\nВерсия: "
					.. (wrapper.version or "1.0"),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneTrufiGCDEnabled() then
						return "|cffff0000Внимание:|r обнаружена standalone-версия. Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI."
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
