-- GladiusEx wrapper for SarychUI
-- Cursor-like valve: Ace Enable/Disable immediately; /reload on disable clears Blizzard Mods.

local ADDON_NAME = "GladiusEx"
local CONFIG_APP = "GladiusEx"

local wrapper = {
	name = ADDON_NAME,
	title = "GladiusEx",
	author = "GladiusEx authors; SarychUI integration",
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

	local arena = SarychUI.db.profile.modules and SarychUI.db.profile.modules.arena
	if arena then
		arena.frameType = enable and "gladiusex" or "classic"
	end
end

local function IsStandaloneGladiusExEnabled()
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("GladiusEx")
	if not loadable then return false end
	return enabled and true or false
end

local function GetGladiusEx()
	return _G.GladiusEx
end

local function SyncArenaModuleRuntime(enableGladiusEx)
	local arena = SarychUI and SarychUI.modules and SarychUI.modules.arena
	if not arena then return end

	if enableGladiusEx then
		if arena.Disable then
			arena:Disable()
		end
		return
	end

	local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.arena
	if db and db.enabled and arena.Enable then
		arena:Enable()
	end
end

local function ApplyGladiusExRuntime(enable)
	local gx = GetGladiusEx()
	if not gx then return false end

	if enable then
		if not gx:IsEnabled() then
			gx:Enable()
		end
	else
		if gx:IsEnabled() then
			gx:Disable()
		end
	end

	return true
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1GladiusEx|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneGladiusExEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneGladiusExEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Отключите отдельный аддон GladiusEx|r — иначе встроенный модуль не запустится.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false

	if not ApplyGladiusExRuntime(enable) then
		return false
	end

	SyncArenaModuleRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneGladiusExEnabled() then
		wrapper.enabled = false
		SetRuntimeEnabledInDB(false)
		local gx = GetGladiusEx()
		if gx and gx.IsEnabled and gx:IsEnabled() and gx.Disable then
			gx:Disable()
		end
		return
	end

	local gx = GetGladiusEx()
	if not gx then return end

	if gx.SetEnabledState and not wrapper.enabled then
		gx:SetEnabledState(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyGladiusExRuntime(true)
	SyncArenaModuleRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyGladiusExRuntime(false)
	SyncArenaModuleRuntime(false)
	return true
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900GladiusEx:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end
	if GladiusEx and GladiusEx.ShowOptionsDialog then
		GladiusEx:ShowOptionsDialog()
		return true
	end

	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD then
		ACD:Open(CONFIG_APP)
		return true
	end

	return false
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "GladiusEx",
		order = 16,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить GladiusEx. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
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
				name = "Открыть настройки GladiusEx",
				desc = "Открыть окно настроек GladiusEx (/gex ui)",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					if SarychUI and SarychUI.OpenGladiusExConfig then
						SarychUI:OpenGladiusExConfig()
					elseif wrapper.OpenConfig then
						wrapper:OpenConfig()
					end
				end,
			},
			description = {
				type = "description",
				name = "GladiusEx — расширенные фреймы арены.\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nКоманды: |cff1784d1/gex ui|r, |cff1784d1/gex test 2-5|r\n\nАвтор: "
					.. (wrapper.author or "")
					.. "\nВерсия: "
					.. (wrapper.version or ""),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneGladiusExEnabled() then
						return "|cffff0000Внимание:|r отключите отдельный аддон |cff1784d1GladiusEx|r — иначе встроенный модуль не запустится."
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
