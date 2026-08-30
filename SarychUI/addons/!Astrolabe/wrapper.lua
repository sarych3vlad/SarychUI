-- !Astrolabe Wrapper for SarychUI
-- Map/minimap coordinate library (dependency for WDM and other map addons).
-- Cursor-like valve: runtime flag only; no Blizzard Mods → no reload.

local ADDON_NAME = "!Astrolabe"

local wrapper = {
	name = ADDON_NAME,
	author = "Esamynn, Trimitor",
	version = "0.5",
	enabled = false,
	loaded = false,
}

AstrolabeEnabled = AstrolabeEnabled ~= false

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return AstrolabeEnabled ~= false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function IsStandaloneAstrolabeEnabled()
	if not GetNumAddOns or not GetAddOnInfo then return false end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable = GetAddOnInfo(i)
		if name == ADDON_NAME then
			return loadable and enabled and true or false
		end
	end
	return false
end

local function ApplyAstrolabeRuntime(enable)
	AstrolabeEnabled = enable and true or false
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneAstrolabeEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneAstrolabeEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Отключите отдельный аддон !Astrolabe|r — иначе встроенная библиотека не запустится.")
		end
		return false
	end

	enable = enable and true or false
	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable
	wrapper.loaded = true
	ApplyAstrolabeRuntime(enable)
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	ApplyAstrolabeRuntime(wrapper.enabled)
	wrapper.loaded = true

	if IsStandaloneAstrolabeEnabled() then
		wrapper.enabled = false
		ApplyAstrolabeRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Отключите отдельный аддон !Astrolabe|r — иначе встроенная библиотека не запустится.")
		end
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	return wrapper:SetRuntimeEnabled(true)
end

function wrapper:Disable()
	return wrapper:SetRuntimeEnabled(false)
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "Astrolabe",
		order = 16.5,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить встроенную библиотеку Astrolabe. Включение и выключение работают сразу (без /reload).",
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
				name = "Библиотека для размещения иконок на карте мира и миникарте. Используется WDM и другими аддонами карт.\nВключение и выключение работают сразу.\n\nАвтор: " .. (wrapper.author or "Неизвестен") .. "\nВерсия: " .. (wrapper.version or "Неизвестна"),
				order = 2,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneAstrolabeEnabled() then
						return "|cffff0000Внимание:|r отключите отдельный аддон |cff1784d1!Astrolabe|r — иначе встроенная библиотека не запустится."
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
