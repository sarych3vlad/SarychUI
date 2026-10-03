-- EnhancedRaidFrames wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "EnhancedRaidFrames"

local wrapper = {
	name = ADDON_NAME,
	title = "EnhancedRaidFrames",
	author = "Britt W. Yazel, Tsoukie",
	version = "1.8",
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
	local _, _, _, enabled, loadable = GetAddOnInfo("EnhancedRaidFrames")
	return loadable and enabled and true or false
end

local function ApplyEnhancedRaidFramesRuntime(enable)
	if not EnhancedRaidFrames then
		return
	end

	if enable then
		if EnhancedRaidFrames.RegisterInterfaceOptions then
			EnhancedRaidFrames:RegisterInterfaceOptions()
		end
		if EnhancedRaidFrames.Enable and not EnhancedRaidFrames:IsEnabled() then
			EnhancedRaidFrames:Enable()
		elseif EnhancedRaidFrames.OnEnable and not EnhancedRaidFrames:IsEnabled() then
			EnhancedRaidFrames:OnEnable()
		end
	else
		if EnhancedRaidFrames.Disable and EnhancedRaidFrames.IsEnabled and EnhancedRaidFrames:IsEnabled() then
			EnhancedRaidFrames:Disable()
		end
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1EnhancedRaidFrames|r будет убран из «Интерфейс -> Модификации» после перезагрузки (/reload).")
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
			SarychUI:Print("|cffff0000Обнаружена standalone-версия EnhancedRaidFrames.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyEnhancedRaidFramesRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneEnabled() then
		wrapper.enabled = false
		ApplyEnhancedRaidFramesRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия EnhancedRaidFrames.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	ApplyEnhancedRaidFramesRuntime(wrapper.enabled)
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyEnhancedRaidFramesRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyEnhancedRaidFramesRuntime(false)
	return true
end

local function OpenEnhancedRaidFramesOptions()
	ApplyEnhancedRaidFramesRuntime(true)

	if SarychUI and SarychUI.CloseOptions then
		SarychUI:CloseOptions()
	end

	if InterfaceOptionsFrame and InterfaceOptionsFrame.Show then
		InterfaceOptionsFrame:Show()
	end

	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory("Enhanced Raid Frames")
		InterfaceOptionsFrame_OpenToCategory("Enhanced Raid Frames")
		return true
	end
	return false
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900EnhancedRaidFrames:|r сначала включите аддон в |cff1784d1Настройки -> Аддоны|r.")
		end
		return false
	end
	if IsStandaloneEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия EnhancedRaidFrames.|r Отключите её в списке аддонов.")
		end
		return false
	end

	local deferFrame = CreateFrame("Frame")
	deferFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		if not OpenEnhancedRaidFramesOptions() then
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffff8080EnhancedRaidFrames:|r настройки недоступны. Проверьте Lua errors.")
			end
		end
	end)
	return true
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "EnhancedRaidFrames",
		order = 5,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить EnhancedRaidFrames. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс -> Модификации».",
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
				name = "Настройка",
				desc = "Открыть настройки Enhanced Raid Frames",
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
				name = "Индикаторы баффов и дебаффов на компактных рейдовых фреймах.\nВключение - сразу; выключение из списка Модификаций - после /reload.\n\nАвтор: "
					.. (wrapper.author or "Britt W. Yazel, Tsoukie")
					.. "\nВерсия: "
					.. (wrapper.version or "1.8"),
				order = 3,
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
