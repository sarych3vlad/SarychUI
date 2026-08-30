-- Equipence wrapper for SarychUI
-- Cursor-like valve: enable immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "Equipence"

local wrapper = {
	name = ADDON_NAME,
	title = "Equipence",
	author = "s0high",
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

local function IsStandaloneEquipenceEnabled()
	if SarychUI_IsStandaloneEquipenceEnabled then
		return SarychUI_IsStandaloneEquipenceEnabled()
	end
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("Equipence")
	return loadable and enabled and true or false
end

local function ApplyEquipenceRuntime(enable)
	if SarychUI_ApplyEquipenceRuntime then
		SarychUI_ApplyEquipenceRuntime(enable)
	else
		EquipenceEnabled = enable and true or false
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1Equipence|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneEquipenceEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneEquipenceEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия Equipence.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyEquipenceRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneEquipenceEnabled() then
		wrapper.enabled = false
		ApplyEquipenceRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия Equipence.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	ApplyEquipenceRuntime(wrapper.enabled)
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyEquipenceRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyEquipenceRuntime(false)
	return true
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900Equipence:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end
	ApplyEquipenceRuntime(true)
	local engine = _G.EquipenceEngine
	if engine and engine.SettingsController and engine.SettingsController.OpenRuntime then
		engine.SettingsController:OpenRuntime()
		return true
	end
	if SlashCmdList and SlashCmdList["EQUIPENCEOPTIONS"] then
		SlashCmdList["EQUIPENCEOPTIONS"]("")
		return true
	end
	return false
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "Equipence",
		order = 17,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Equipence. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
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
				name = "Открыть настройки Equipence",
				desc = "Открыть окно настроек Equipence",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					if not wrapper:OpenConfig() and SarychUI and SarychUI.Print then
						SarychUI:Print("Не удалось открыть настройки Equipence.")
					end
				end,
			},
			description = {
				type = "description",
				name = "Детальный обзор снаряжения при осмотре персонажей: самоцветы, чары и уровни предметов.\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "s0high")
					.. "\nВерсия: "
					.. (wrapper.version or "1.0"),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneEquipenceEnabled() then
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
