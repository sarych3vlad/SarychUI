-- InspectEquip wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "InspectEquip"

local wrapper = {
	name = ADDON_NAME,
	title = "InspectEquip",
	author = "emelio",
	version = "1.7.7",
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

local function IsStandaloneInspectEquipEnabled()
	if SarychUI_IsStandaloneInspectEquipEnabled then
		return SarychUI_IsStandaloneInspectEquipEnabled()
	end
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("InspectEquip")
	return loadable and enabled and true or false
end

local function ApplyInspectEquipRuntime(enable)
	InspectEquipEnabled = enable and true or false
	local ie = _G.InspectEquip
	if not ie then
		return
	end
	if enable then
		if ie.RegisterInterfaceOptions then
			ie.RegisterInterfaceOptions()
		end
		if ie.Enable then
			ie:Enable()
		end
	elseif ie.Disable then
		ie:Disable()
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1InspectEquip|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneInspectEquipEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneInspectEquipEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия InspectEquip.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyInspectEquipRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneInspectEquipEnabled() then
		wrapper.enabled = false
		ApplyInspectEquipRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия InspectEquip.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	if wrapper.enabled then
		ApplyInspectEquipRuntime(true)
	else
		ApplyInspectEquipRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyInspectEquipRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyInspectEquipRuntime(false)
	return true
end

local function GetInspectEquipOptionsFrame()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.BlizOptions then
		return nil
	end
	local groups = ACD.BlizOptions["InspectEquip"]
	if not groups then
		return nil
	end
	local group = groups["InspectEquip"]
	if group and group.frame then
		return group.frame
	end
	return nil
end

local function OpenInspectEquipInterfaceOptions()
	ApplyInspectEquipRuntime(true)
	local category = GetInspectEquipOptionsFrame()
	if not category then
		return false
	end

	if SarychUI and SarychUI.CloseOptions then
		SarychUI:CloseOptions()
	end

	if InterfaceOptionsFrame and InterfaceOptionsFrame.Show then
		InterfaceOptionsFrame:Show()
	end

	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(category)
		InterfaceOptionsFrame_OpenToCategory(category)
	end
	return true
end

function SarychUI_OpenInspectEquipConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900InspectEquip:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end
	if IsStandaloneInspectEquipEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия InspectEquip.|r Отключите её в списке аддонов.")
		end
		return false
	end

	local deferFrame = CreateFrame("Frame")
	deferFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		if not OpenInspectEquipInterfaceOptions() then
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffff8080InspectEquip:|r настройки недоступны. Проверьте Lua errors.")
			end
		end
	end)
	return true
end

function wrapper:OpenConfig()
	return SarychUI_OpenInspectEquipConfig()
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "InspectEquip",
		order = 21,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить InspectEquip. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
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
				name = "Открыть настройки InspectEquip",
				desc = "Открыть окно настроек InspectEquip (Interface → AddOns → InspectEquip)",
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
				name = "Показывает, откуда взята экипировка осматриваемых персонажей (или вашей).\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "emelio")
					.. "\nВерсия: "
					.. (wrapper.version or "1.7.7"),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneInspectEquipEnabled() then
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
