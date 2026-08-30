-- BASpammer wrapper for SarychUI
-- Cursor-like valve: enable immediate if core loaded; reload if gated at TOC or on disable.

local ADDON_NAME = "BASpammer"

local wrapper = {
	name = ADDON_NAME,
	title = "BASpammer",
	author = "Bigalex + irlyhatemyselfandyou",
	version = "1.04",
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

local function IsStandaloneBASpammerEnabled()
	if SarychUI_IsStandaloneBASpammerEnabled then
		return SarychUI_IsStandaloneBASpammerEnabled()
	end
	return false
end

local function CoreLoaded()
	if SarychUI_IsBASpammerCoreLoaded then
		return SarychUI_IsBASpammerCoreLoaded()
	end
	return type(BASpammer_OnEvent) == "function"
end

local function ApplyBASpammerRuntime(enable)
	if SarychUI_ApplyBASpammerRuntime then
		SarychUI_ApplyBASpammerRuntime(enable)
	else
		BASpammerEnabled = enable and true or false
	end
end

local function ActivateBASpammer()
	if not CoreLoaded() then
		return false, "requires_reload"
	end
	if SarychUI_InitEmbeddedBASpammer then
		SarychUI_InitEmbeddedBASpammer()
	end
	ApplyBASpammerRuntime(true)
	wrapper.loaded = true
	return true, "loaded"
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneBASpammerEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneBASpammerEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия BASpammer.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	enable = enable and true or false
	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable

	if enable then
		local ok, reason = ActivateBASpammer()
		if not ok and reason == "requires_reload" then
			if SarychUI and SarychUI.ShowReloadPopup then
				SarychUI:ShowReloadPopup("|cff1784d1BASpammer|r будет загружен после перезагрузки интерфейса (/reload).")
			elseif StaticPopup_Show then
				StaticPopup_Show("SARYCHUI_RELOAD_UI")
			end
		end
	else
		ApplyBASpammerRuntime(false)
		if SarychUI and SarychUI.ShowReloadPopup then
			SarychUI:ShowReloadPopup("|cff1784d1BASpammer|r будет выгружен после перезагрузки интерфейса (/reload).")
		elseif StaticPopup_Show then
			StaticPopup_Show("SARYCHUI_RELOAD_UI")
		end
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	wrapper.loaded = CoreLoaded()

	if IsStandaloneBASpammerEnabled() then
		wrapper.enabled = false
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия BASpammer.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		if SarychUI_NeuterBASpammerFrames then
			SarychUI_NeuterBASpammerFrames()
		end
		return
	end

	if wrapper.enabled and wrapper.loaded then
		ActivateBASpammer()
	else
		ApplyBASpammerRuntime(false)
		if not wrapper.loaded and SarychUI_NeuterBASpammerFrames then
			SarychUI_NeuterBASpammerFrames()
		end
	end
end

function wrapper:Enable()
	if IsStandaloneBASpammerEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия BASpammer.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end
	wrapper.enabled = GetRuntimeEnabledFromDB()
	if not wrapper.enabled then
		return false
	end
	local ok = ActivateBASpammer()
	return ok and true or false
end

function wrapper:Disable()
	return wrapper:SetRuntimeEnabled(false)
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "BASpammer",
		order = 20,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить BASpammer. Включение — сразу, если ядро уже загружено; иначе /reload. Выключение — после /reload.",
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
				name = "Спамит в выбранный канал заданный текст с заданным интервалом. Настройки: ПКМ по панели BASpammer на экране.\nВключение — сразу (если уже загружен); выключение — после /reload.\n\nАвтор: "
					.. (wrapper.author or "Bigalex")
					.. "\nВерсия: "
					.. (wrapper.version or "1.04"),
				order = 2,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneBASpammerEnabled() then
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
