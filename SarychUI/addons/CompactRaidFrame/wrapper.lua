-- CompactRaidFrame wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "CompactRaidFrame"

local wrapper = {
	name = ADDON_NAME,
	title = "CompactRaidFrame",
	author = "RomanSpector & Blizzard",
	version = "1.2.2",
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

local function IsStandaloneCompactRaidFrameEnabled()
	if SarychUI_IsStandaloneCompactRaidFrameEnabled then
		return SarychUI_IsStandaloneCompactRaidFrameEnabled()
	end
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("CompactRaidFrame")
	return loadable and enabled and true or false
end

local function ApplyCompactRaidFrameRuntime(enable)
	CompactRaidFrameEnabled = enable and true or false
	if enable then
		if CompactRaidFrameContainer and CompactRaidFrameContainer._suiNeedsInit and CompactRaidFrameContainer_OnLoad then
			CompactRaidFrameContainer_OnLoad(CompactRaidFrameContainer)
		end
		if CompactRaidFrameManager and CompactRaidFrameManager._suiNeedsInit and CompactRaidFrameManager_OnLoad then
			CompactRaidFrameManager_OnLoad(CompactRaidFrameManager)
		end
		if CompactUnitFrameProfiles_RegisterInterfaceOptions then
			CompactUnitFrameProfiles_RegisterInterfaceOptions()
		end
		if CompactRaidFrameManager then
			CompactRaidFrameManager:Show()
		end
		if CompactRaidFrameContainer then
			CompactRaidFrameContainer:Show()
		end
	else
		if CompactRaidFrameManager then
			CompactRaidFrameManager:Hide()
		end
		if CompactRaidFrameContainer then
			CompactRaidFrameContainer:Hide()
		end
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1CompactRaidFrame|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneCompactRaidFrameEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneCompactRaidFrameEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия CompactRaidFrame.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyCompactRaidFrameRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandaloneCompactRaidFrameEnabled() then
		wrapper.enabled = false
		ApplyCompactRaidFrameRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия CompactRaidFrame.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	if wrapper.enabled then
		ApplyCompactRaidFrameRuntime(true)
	else
		ApplyCompactRaidFrameRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyCompactRaidFrameRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyCompactRaidFrameRuntime(false)
	return true
end

local function OpenCompactRaidFrameInterfaceOptions()
	ApplyCompactRaidFrameRuntime(true)
	local category = CompactUnitFrameProfiles
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

function SarychUI_OpenCompactRaidFrameConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900CompactRaidFrame:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end
	if IsStandaloneCompactRaidFrameEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия CompactRaidFrame.|r Отключите её в списке аддонов.")
		end
		return false
	end

	local deferFrame = CreateFrame("Frame")
	deferFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		if not OpenCompactRaidFrameInterfaceOptions() then
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffff8080CompactRaidFrame:|r настройки недоступны. Проверьте Lua errors.")
			end
		end
	end)
	return true
end

function wrapper:OpenConfig()
	return SarychUI_OpenCompactRaidFrameConfig()
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "CompactRaidFrame",
		order = 3,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить CompactRaidFrame. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
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
				name = "Открыть настройки CompactRaidFrame",
				desc = "Открыть панель профилей рейдовых фреймов (Interface → AddOns)",
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
				name = "Портированные компактные рейдовые фреймы из retail версии WoW.\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "RomanSpector & Blizzard")
					.. "\nВерсия: "
					.. (wrapper.version or "1.2.2"),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneCompactRaidFrameEnabled() then
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
