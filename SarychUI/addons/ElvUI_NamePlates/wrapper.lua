-- ElvUI NamePlates wrapper for SarychUI
-- Cursor-like valve: enable/disable immediate (runtime Start/Shutdown); no reload on enable.

local ADDON_NAME = "ElvUI_NamePlates"

local wrapper = {
	name = ADDON_NAME,
	title = "ElvUI NamePlates",
	author = "Elv, Bunny (ElvUI); SarychUI integration",
	version = "1.00",
	loaded = true,
	enabled = false,
}

local function GetEngine()
	return _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
end

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

function wrapper:IsRuntimeEnabled()
	local E = GetEngine()
	if E and E.initialized and E.IsNamePlatesRuntimeEnabled then
		return E:IsNamePlatesRuntimeEnabled()
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	local E = GetEngine()
	if E and E.CheckStandaloneConflict and E:CheckStandaloneConflict() then
		return false
	end

	enable = enable and true or false
	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable

	if E then
		if not E.initialized and E.loginReady and E.TryInitialize then
			E:TryInitialize()
		end

		if E.initialized then
			E.private = E.private or (E.privateData and E.privateData.profile)
			if E.private then
				E.private.nameplates = E.private.nameplates or {}
				E.private.nameplates.enable = enable
			end

			if enable then
				if E.StartNamePlatesRuntime then
					E:StartNamePlatesRuntime()
				end
			elseif E.ShutdownRuntime then
				E:ShutdownRuntime()
			end
		elseif E.privateVars and E.privateVars.profile then
			E.privateVars.profile.nameplates = E.privateVars.profile.nameplates or {}
			E.privateVars.profile.nameplates.enable = enable
		end
	end

	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()

	local E = GetEngine()
	if not E then return end

	if IsAddOnLoaded and IsAddOnLoaded("ElvUI_NamePlates_Standalone") then
		E.disabledByConflict = true
		wrapper.enabled = false
		SetRuntimeEnabledInDB(false)
		return
	end

	if E.loginReady and E.TryInitialize then
		E:TryInitialize()
	end
end

function wrapper:Enable()
	if wrapper:IsRuntimeEnabled() then return true end
	return wrapper:SetRuntimeEnabled(true)
end

function wrapper:Disable()
	if not wrapper:IsRuntimeEnabled() then return true end
	return wrapper:SetRuntimeEnabled(false)
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "ElvUI NamePlates",
		order = 15,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить ElvUI NamePlates. Включение и выключение работают сразу.",
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
				name = "Открыть настройки NamePlates",
				desc = "Открыть окно настроек ElvUI NamePlates (/enp)",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					if not SarychUI then
						return
					end
					if not SarychUI.OpenNamePlatesConfig then
						if SarychUI.Print then
							SarychUI:Print("OpenNamePlatesConfig missing (options.lua not loaded?)")
						end
						return
					end
					SarychUI:OpenNamePlatesConfig()
				end,
			},
			description = {
				type = "description",
				name = "ElvUI NamePlates — стилизация и настройка nameplates в стиле ElvUI.\nВключение и выключение работают сразу.\n\nКоманды: |cff1784d1/enp|r, |cff1784d1/elvnp|r, |cff1784d1/elvnameplates|r\n\nАвтор: " .. (wrapper.author or "") .. "\nВерсия: " .. (wrapper.version or ""),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsAddOnLoaded and IsAddOnLoaded("ElvUI_NamePlates_Standalone") then
						return "|cffff0000Внимание:|r отключите отдельный аддон |cff1784d1ElvUI_NamePlates_Standalone|r — иначе встроенный модуль не запустится."
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
	frame:SetScript("OnEvent", function(self, event, addonName)
		if addonName == "SarychUI" and RegisterWrapper() then
			self:UnregisterAllEvents()
		end
	end)
end

return wrapper
