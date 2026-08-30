-- _Cursor wrapper for SarychUI
-- Client has no loadfile: core is in TOC; valve = runtime + deferred Blizzard options.

local ADDON_NAME = "_Cursor"

local wrapper = {
	name = ADDON_NAME,
	title = "_Cursor",
	author = "Saiket",
	version = "3.3.0.2",
	loaded = false,
	enabled = false,
}

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		local v = SarychUI.db.profile.addons[ADDON_NAME].enabled
		return v == true or v == 1
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

local function IsStandaloneCursorEnabled()
	if SarychUI_IsStandaloneCursorEnabled then
		return SarychUI_IsStandaloneCursorEnabled()
	end
	return false
end

local function CoreLoaded()
	if SarychUI_IsCursorCoreLoaded then
		return SarychUI_IsCursorCoreLoaded()
	end
	return _G._Cursor ~= nil
end

local function ApplyCursorRuntime(enable)
	if SarychUI_ApplyCursorRuntime then
		SarychUI_ApplyCursorRuntime(enable)
	else
		_CursorEnabled = enable and true or false
	end
end

local function ActivateCursor()
	if not CoreLoaded() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff8080_Cursor:|r ядро не загружено. Проверьте TOC / Lua errors.")
		end
		return false
	end
	if SarychUI_InitEmbeddedCursor then
		SarychUI_InitEmbeddedCursor()
	end
	ApplyCursorRuntime(true)
	wrapper.loaded = true
	return true
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneCursorEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneCursorEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия _Cursor.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false

	if enable then
		ActivateCursor()
	else
		ApplyCursorRuntime(false)
		if SarychUI and SarychUI.ShowReloadPopup then
			SarychUI:ShowReloadPopup("|cff1784d1_Cursor|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
		elseif StaticPopup_Show then
			StaticPopup_Show("SARYCHUI_RELOAD_UI")
		end
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	wrapper.loaded = CoreLoaded()

	if IsStandaloneCursorEnabled() then
		wrapper.enabled = false
		ApplyCursorRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия _Cursor.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	if wrapper.enabled then
		ActivateCursor()
	else
		ApplyCursorRuntime(false)
	end
end

function wrapper:Enable()
	if IsStandaloneCursorEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия _Cursor.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end
	wrapper.enabled = GetRuntimeEnabledFromDB()
	if not wrapper.enabled then
		return false
	end
	return ActivateCursor()
end

function wrapper:Disable()
	return wrapper:SetRuntimeEnabled(false)
end

local function OpenCursorInterfaceOptions()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	ActivateCursor()
	local options = _Cursor and _Cursor.Options
	if not options then
		return false
	end

	if SarychUI and SarychUI.CloseOptions then
		SarychUI:CloseOptions()
	end

	if InterfaceOptionsFrame and InterfaceOptionsFrame.Show then
		InterfaceOptionsFrame:Show()
	end

	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(options)
		InterfaceOptionsFrame_OpenToCategory(options)
	end

	return true
end

function SarychUI_OpenCursorConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900_Cursor:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end
	if IsStandaloneCursorEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия _Cursor.|r Отключите её в списке аддонов.")
		end
		return false
	end

	local deferFrame = CreateFrame("Frame")
	deferFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		if not OpenCursorInterfaceOptions() then
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffff8080_Cursor:|r настройки недоступны. Проверьте Lua errors.")
			end
		end
	end)
	return true
end

function wrapper:OpenConfig()
	return SarychUI_OpenCursorConfig()
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "_Cursor",
		order = 19,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить _Cursor. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
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
				name = "Открыть настройки _Cursor",
				desc = "Открыть окно настроек _Cursor",
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
				name = "Добавляет пользовательские эффекты к курсору.\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "Saiket")
					.. "\nВерсия: "
					.. (wrapper.version or "3.3.0.2"),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneCursorEnabled() then
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
