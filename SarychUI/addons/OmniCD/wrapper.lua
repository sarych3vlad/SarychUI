-- OmniCD wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "OmniCD"

local wrapper = {
	name = ADDON_NAME,
	title = "OmniCD",
	author = "Treebonker, Tsoukie",
	version = "1.7",
	loaded = true,
	enabled = false,
}

local function GetEngine()
	return OmniCD and OmniCD[1]
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

local function IsStandaloneEnabled()
	if not GetAddOnInfo then return false end
	local _, _, _, enabled, loadable = GetAddOnInfo("OmniCD")
	return loadable and enabled and true or false
end

local function ApplyOmniCDRuntime(enable)
	OmniCDEnabled = enable and true or false
	local E = GetEngine()
	if not E then
		return
	end

	if enable then
		if not E.DB and E.OnInitialize then
			E:OnInitialize()
		end
		if E.RegisterInterfaceOptions then
			E:RegisterInterfaceOptions()
		end
		if not E.isEnabled and E.OnEnable then
			if not E.userGUID then
				E.userGUID = UnitGUID("player")
			end
			E:OnEnable()
		elseif E.Party and E.Party.Enable then
			E.Party:Enable()
		end
	else
		if E.Party and E.Party.Disable then
			E.Party:Disable()
		end
		if E.Comm and E.Comm.Disable then
			E.Comm:Disable()
		end
		if E.Cooldowns and E.Cooldowns.Disable then
			E.Cooldowns:Disable()
		end
		E.isEnabled = false
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1OmniCD|r будет убран из «Интерфейс -> Модификации» после перезагрузки (/reload).")
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
			SarychUI:Print("|cffff0000Обнаружена standalone-версия OmniCD.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyOmniCDRuntime(enable)
	local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
	if tools and tools.ApplyAltOmniCD then
		tools:ApplyAltOmniCD()
	end
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	end
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	OmniCDEnabled = wrapper.enabled

	if IsStandaloneEnabled() then
		wrapper.enabled = false
		OmniCDEnabled = false
		ApplyOmniCDRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия OmniCD.|r Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.")
		end
		return
	end

	if wrapper.enabled then
		local E = GetEngine()
		if E then
			if not E.DB and E.OnInitialize then
				E:OnInitialize()
			end
			if E.RegisterInterfaceOptions then
				E:RegisterInterfaceOptions()
			end
		end
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyOmniCDRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyOmniCDRuntime(false)
	return true
end

local function OpenOmniCDOptions()
	ApplyOmniCDRuntime(true)
	local E = GetEngine()
	if not E then
		return false
	end

	if SarychUI and SarychUI.CloseOptions then
		SarychUI:CloseOptions()
	end

	if E.OpenOptionPanel then
		E:OpenOptionPanel()
		return true
	end
	return false
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900OmniCD:|r сначала включите аддон в |cff1784d1Настройки -> Аддоны|r.")
		end
		return false
	end
	if IsStandaloneEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Обнаружена standalone-версия OmniCD.|r Отключите её в списке аддонов.")
		end
		return false
	end

	local deferFrame = CreateFrame("Frame")
	deferFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		if not OpenOmniCDOptions() then
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffff8080OmniCD:|r настройки недоступны. Проверьте Lua errors.")
			end
		end
	end)
	return true
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "OmniCD",
		order = 6,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить OmniCD. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс -> Модификации».",
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
				desc = "Открыть настройки OmniCD",
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
				name = "Кулдауны группы на компактных рейдовых фреймах.\nВключение - сразу; выключение из списка Модификаций - после /reload.\n\nАвтор: "
					.. (wrapper.author or "Treebonker, Tsoukie")
					.. "\nВерсия: "
					.. (wrapper.version or "1.7"),
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
