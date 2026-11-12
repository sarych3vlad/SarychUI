-- Postal wrapper for SarychUI
-- The Addons checkbox saves the desired state; enabling applies after /reload.

local ADDON_NAME = "Postal"

local wrapper = {
	name = ADDON_NAME,
	title = "Postal",
	author = "Xinhuan",
	version = "3.3.2",
	loaded = false,
	enabled = false,
}
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

local function SetPostalChromeShown(shown)
	local menu = _G.Postal_ModuleMenuButton
	if menu then
		if shown then menu:Show() else menu:Hide() end
	end
	for i = 1, 7 do
		local hover = _G["PostalSubjectHover" .. i]
		if hover then
			if shown then hover:Show() else hover:Hide() end
		end
	end
end

-- Ace Disable drops module hooks. Enable again restores the ones the user left on.
local function ApplyPostalRuntime(enable)
	local Postal = _G.Postal
	if not Postal then
		wrapper.loaded = false
		return false
	end
	wrapper.loaded = true
	if enable then
		if Postal.db and Postal.db.settings and Postal.IterateModules then
			local state = Postal.db.settings.ModuleEnabledState
			for name, module in Postal:IterateModules() do
				local on = not (type(state) == "table" and state[name] == false)
				if module.SetEnabledState then
					module:SetEnabledState(on)
				end
			end
		end
		if Postal.SetEnabledState then
			Postal:SetEnabledState(true)
		end
		if Postal.Enable then
			pcall(Postal.Enable, Postal)
		end
		SetPostalChromeShown(true)
		return true
	end
	if Postal.Disable then
		pcall(Postal.Disable, Postal)
	elseif Postal.SetEnabledState then
		Postal:SetEnabledState(false)
	end
	if Postal.IterateModules then
		for _, module in Postal:IterateModules() do
			if module.Disable then module:Disable() end
		end
	end
	SetPostalChromeShown(false)
	return true
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
		-- Keep this session inactive; the next load initializes the full core
		-- against the selected profile and enables its modules in order.
		ApplyPostalRuntime(false)
		if SarychUI and SarychUI.ShowReloadPopup then
			SarychUI:ShowReloadPopup("|cff1784d1Postal|r будет загружен после перезагрузки интерфейса (/reload).")
		elseif SarychUI and SarychUI.Print then
			SarychUI:Print("|cff1784d1Postal|r будет загружен после перезагрузки интерфейса (/reload).")
		end
	else
		ApplyPostalRuntime(false)
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

	ApplyPostalRuntime(wrapper.enabled)
	if wrapper.enabled and not wrapper.loaded and not initDiagnosticShown then
		initDiagnosticShown = true
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff8080Postal:|r ядро не создано. Проверьте ошибки Lua.")
		end
	end
end

function wrapper:Enable()
	if IsStandalonePostalEnabled() or not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	return ApplyPostalRuntime(true)
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyPostalRuntime(false)
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
				desc = "Включить или выключить Postal. Если он не загружен, для включения нужен /reload.",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
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

-- Stop Ace from enabling Postal on login when the checkbox is off.
if _G.Postal and _G.Postal.SetEnabledState and not GetRuntimeEnabledFromDB() then
	_G.Postal:SetEnabledState(false)
end

return wrapper
