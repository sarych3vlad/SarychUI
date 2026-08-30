-- Postal wrapper for SarychUI
-- Cursor-like valve: enable immediate when already loaded; reload when gated or on disable.

local ADDON_NAME = "Postal"

local wrapper = {
	name = ADDON_NAME,
	title = "Postal",
	author = "Xinhuan",
	version = "3.3.2",
	loaded = false,
	enabled = false,
}
local reloadHintShown = false
local initDiagnosticShown = false

local function GetRuntimeEnabledFromDB()
	if SarychUI_IsPostalRuntimeEnabled then
		return SarychUI_IsPostalRuntimeEnabled()
	end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled == true
	end
	return false
end

local function GetLoadModeFromDB()
	if SarychUI_GetPostalLoadMode then
		return SarychUI_GetPostalLoadMode()
	end
	return "embedded"
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
	SarychUI.db.profile.addons[ADDON_NAME].loadMode = "embedded"
end

local function IsStandalonePostalEnabled()
	if SarychUI_IsStandalonePostalEnabled then
		return SarychUI_IsStandalonePostalEnabled()
	end
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("Postal")
	return loadable and enabled and true or false
end

local function IsPostalLoaded()
	return SarychUI_IsEmbeddedPostalLoaded and SarychUI_IsEmbeddedPostalLoaded()
end

local function TryActivatePostal()
	if IsPostalLoaded() then
		wrapper.loaded = true
		return true, "loaded"
	end
	if SarychUI_InitializeEmbeddedPostal then
		local ok, reason = SarychUI_InitializeEmbeddedPostal()
		wrapper.loaded = ok and true or false
		return ok, reason
	end
	return false, "not_initialized"
end

function wrapper:IsRuntimeEnabled()
	if IsStandalonePostalEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandalonePostalEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия Postal.|r Отключите её, чтобы использовать встроенную версию.")
		end
		return false
	end

	enable = enable and true or false
	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable

	if enable then
		local ok, reason = TryActivatePostal()
		if ok then
			return true
		end
		if reason == "requires_reload" then
			if SarychUI and SarychUI.ShowReloadPopup then
				SarychUI:ShowReloadPopup("|cff1784d1Postal|r будет загружен после перезагрузки интерфейса (/reload).")
			elseif StaticPopup_Show then
				StaticPopup_Show("SARYCHUI_RELOAD_UI")
			end
		elseif reason == "not_initialized" and not initDiagnosticShown then
			initDiagnosticShown = true
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffff8080Postal:|r expected embedded init, but core object is missing. Check Lua errors, then /reload.")
			end
		end
	else
		if SarychUI and SarychUI.ShowReloadPopup then
			SarychUI:ShowReloadPopup("|cff1784d1Postal|r будет выгружен после перезагрузки интерфейса (/reload).")
		elseif StaticPopup_Show then
			StaticPopup_Show("SARYCHUI_RELOAD_UI")
		end
	end
	return true
end

function wrapper:Initialize()
	GetLoadModeFromDB() -- force migration of old loadMode values
	wrapper.enabled = GetRuntimeEnabledFromDB()

	if IsStandalonePostalEnabled() then
		wrapper.enabled = false
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия Postal.|r Отключите её, чтобы использовать встроенную версию.")
		end
		return
	end

	if wrapper.enabled and SarychUI_InitializeEmbeddedPostal then
		local ok, reason = SarychUI_InitializeEmbeddedPostal()
		wrapper.loaded = ok and true or false
		if not ok and reason == "not_initialized" and not initDiagnosticShown then
			initDiagnosticShown = true
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffff8080Postal:|r enabled at startup, but core object was not created. Check Lua errors, then /reload.")
			end
		end
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	local ok, reason = TryActivatePostal()
	if not ok and reason == "requires_reload" and not reloadHintShown then
		reloadHintShown = true
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900Postal:|r аддон был выключен при загрузке интерфейса и будет включён после |cff1784d1/reload|r.")
		end
	elseif not ok and reason == "not_initialized" and not initDiagnosticShown then
		initDiagnosticShown = true
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff8080Postal:|r expected embedded init, but core object is missing. Check Lua errors, then /reload.")
		end
	end
	return ok and true or false
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	return true
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900Postal:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end
	if IsStandalonePostalEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия Postal.|r Отключите её в списке аддонов.")
		end
		return false
	end
	if not IsPostalLoaded() then
		local reason
		if SarychUI_InitializeEmbeddedPostal then
			local _, initReason = SarychUI_InitializeEmbeddedPostal()
			reason = initReason
		end
		if SarychUI and SarychUI.Print then
			if reason == "requires_reload" then
				SarychUI:Print("|cffff9900Postal:|r аддон был выключен при загрузке и станет доступен после |cff1784d1/reload|r.")
			else
				SarychUI:Print("|cffff8080Postal:|r embedded core не инициализирован. Проверьте Lua errors и выполните |cff1784d1/reload|r.")
			end
		end
		return false
	end
	if SarychUI and SarychUI.CloseOptions then
		SarychUI:CloseOptions()
	end
	if MailFrame and MailFrame.Show and not MailFrame:IsShown() then
		MailFrame:Show()
	end
	if SarychUI and SarychUI.Print then
		SarychUI:Print("Postal: настройки модулей — в выпадающем меню почтового ящика (кнопка со стрелкой справа вверху).")
	end
	return true
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "Postal",
		order = 19,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Postal. Включение — сразу, если уже загружен; иначе /reload. Выключение — после /reload.",
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
				name = "Открыть настройки Postal",
				desc = "Открыть почтовый ящик — настройки Postal в меню справа вверху",
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
				name = function()
					local mode = GetLoadModeFromDB()
					return "Расширенная поддержка почтового ящика (Open All, Express, BlackBook и др.).\nВключение — сразу (если уже загружен); выключение — после /reload.\n\nНастройки модулей — в интерфейсе почтового ящика.\nБаза настроек: |cff1784d1Postal3DB|r.\nРежим загрузки: |cff1784d1" .. tostring(mode) .. "|r (strict embedded).\n\nАвтор: " .. (wrapper.author or "Xinhuan") .. "\nВерсия: " .. (wrapper.version or "3.3.2")
				end,
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandalonePostalEnabled() then
						return "|cffff0000Внимание:|r обнаружена standalone-версия Postal. Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI."
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
