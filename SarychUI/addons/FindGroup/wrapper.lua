-- FindGroup wrapper for SarychUI
-- Cursor-like valve: enable immediately; disable stops runtime (own UI, no Bliz Mods).

local ADDON_NAME = "FindGroup"

local wrapper = {
	name = ADDON_NAME,
	title = "FindGroup",
	author = "Mio, Maglink",
	version = "3.1",
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
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then
		return
	end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function IsStandaloneFindGroupEnabled()
	if SarychUI_IsStandaloneFindGroupEnabled then
		return SarychUI_IsStandaloneFindGroupEnabled()
	end
	if not GetAddOnInfo then
		return false
	end
	local _, _, _, enabled, loadable = GetAddOnInfo("FindGroup")
	return loadable and enabled and true or false
end

local function ApplyFindGroupRuntime(enable)
	if SarychUI_ApplyFindGroupRuntime then
		SarychUI_ApplyFindGroupRuntime(enable)
	else
		FindGroupEnabled = enable and true or false
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneFindGroupEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneFindGroupEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия FindGroup.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyFindGroupRuntime(enable)
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	ApplyFindGroupRuntime(wrapper.enabled)

	if IsStandaloneFindGroupEnabled() then
		wrapper.enabled = false
		ApplyFindGroupRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия FindGroup.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyFindGroupRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyFindGroupRuntime(false)
	return true
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "FindGroup",
		order = 45,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить FindGroup. Включение и выключение работают сразу.",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			description = {
				type = "description",
				name = "Поиск и мониторинг сообщений о сборе группы/рейда. Команды: /FindGroup, /fg.\nВключение и выключение работают сразу.\n\nАвтор: "
					.. (wrapper.author or "Mio, Maglink")
					.. "\nВерсия: "
					.. (wrapper.version or "3.1"),
				order = 2,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneFindGroupEnabled() then
						return "|cffff0000Внимание:|r обнаружена standalone-версия FindGroup. Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI."
					end
					return ""
				end,
				order = 3,
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
