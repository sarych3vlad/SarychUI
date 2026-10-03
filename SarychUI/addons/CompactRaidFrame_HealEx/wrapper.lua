-- CompactRaidFrame_HealEx wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload.

local ADDON_NAME = "CompactRaidFrame_HealEx"

local wrapper = {
	name = ADDON_NAME,
	title = "CompactRaidFrame_HealEx",
	author = "Tsoukie",
	version = "1.7",
	loaded = true,
	enabled = false,
}

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return true
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function IsStandaloneEnabled()
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("CompactRaidFrame_HealEx")
	return loadable and enabled and true or false
end

local function ApplyHealExRuntime(enable)
	if CompactRaidFrame_HealEx_Apply then
		CompactRaidFrame_HealEx_Apply(enable)
	else
		CompactRaidFrame_HealExEnabled = enable and true or false
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1CompactRaidFrame_HealEx|r будет полностью выключен после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия CompactRaidFrame_HealEx.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyHealExRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneEnabled() then
		wrapper.enabled = false
		ApplyHealExRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия CompactRaidFrame_HealEx.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	ApplyHealExRuntime(wrapper.enabled)
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyHealExRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyHealExRuntime(false)
	return true
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "CompactRaidFrame_HealEx",
		order = 4,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить CompactRaidFrame_HealEx. При выключении нужен /reload.",
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
				name = "Входящее лечение, HoT и поглощения на компактных рейдовых фреймах.\nВключение - сразу; полное выключение - после /reload.\n\nАвтор: "
					.. (wrapper.author or "Tsoukie")
					.. "\nВерсия: "
					.. (wrapper.version or "1.7"),
				order = 2,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneEnabled() then
						return "|cffff0000Внимание:|r обнаружена standalone-версия. Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI."
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
