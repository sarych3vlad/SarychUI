-- Postal bootstrap for strict embedded mode in SarychUI.
local STANDALONE_ADDON = "Postal"
local EMBEDDED_MODE = "embedded"

SarychUI_POSTAL_EMBEDDED_VERSION = "3.3.2"
SarychUI_POSTAL_EMBEDDED_TITLE = "Postal"
SarychUI_POSTAL_EMBEDDED_NOTES = "Postal: Enhanced Mailbox support"
local migrationWarned = false

local function GetCharacterProfileKey()
	if SarychUI_ResolveSavedProfileKey then
		return SarychUI_ResolveSavedProfileKey()
	end
	if type(SarychUIDB) ~= "table" or type(SarychUIDB.profileKeys) ~= "table" then
		return "Default"
	end
	local name = UnitName and UnitName("player")
	local realm = GetRealmName and GetRealmName()
	if name and realm and name ~= "" and name ~= "Unknown" and realm ~= "" then
		local charKey = name .. " - " .. realm
		local profileKey = SarychUIDB.profileKeys[charKey]
		if type(profileKey) == "string" and profileKey ~= "" then
			return profileKey
		end
	end
	return "Default"
end

local function GetSavedSarychUIProfile()
	if SarychUI and SarychUI.GetActiveProfile then
		return SarychUI:GetActiveProfile()
	end
	if SarychUI and SarychUI.db and SarychUI.db.profile then
		return SarychUI.db.profile
	end
	if type(SarychUIDB) ~= "table" or type(SarychUIDB.profiles) ~= "table" then
		return nil
	end
	local profile = SarychUIDB.profiles[GetCharacterProfileKey()]
	if type(profile) == "table" then
		return profile
	end
	return nil
end

local function GetPostalConfigFromProfile(profile)
	if type(profile) ~= "table" or type(profile.addons) ~= "table" then
		return nil
	end
	return profile.addons.Postal
end

local function GetPostalRuntimeEnabledState()
	local profile = (SarychUI and SarychUI.db and SarychUI.db.profile) or GetSavedSarychUIProfile()
	local cfg = GetPostalConfigFromProfile(profile)
	if cfg and cfg.enabled ~= nil then
		return cfg.enabled == true, true
	end
	return nil, false
end

local function EnsurePostalConfig()
	local profile = (SarychUI and SarychUI.db and SarychUI.db.profile) or GetSavedSarychUIProfile()
	if type(profile) ~= "table" then
		return nil
	end
	profile.addons = profile.addons or {}
	profile.addons.Postal = profile.addons.Postal or {}
	return profile.addons.Postal
end

function SarychUI_GetPostalLoadMode()
	local cfg = EnsurePostalConfig()
	if cfg and cfg.loadMode ~= EMBEDDED_MODE then
		cfg.loadMode = EMBEDDED_MODE
		if not migrationWarned then
			migrationWarned = true
			if SarychUI and SarychUI.Print then
				SarychUI:Print("|cffffff00Postal:|r legacy loadMode migrated to |cff1784d1embedded|r.")
			end
		end
	end
	return EMBEDDED_MODE
end

function SarychUI_IsPostalRuntimeEnabled()
	local enabled, known = GetPostalRuntimeEnabledState()
	if known then
		return enabled
	end
	return false
end

function SarychUI_IsStandalonePostalEnabled()
	if not _G.GetAddOnInfo then
		return false
	end
	local _, _, _, enabled, loadable = _G.GetAddOnInfo(STANDALONE_ADDON)
	return loadable and enabled and true or false
end

function SarychUI_IsEmbeddedPostalLoaded()
	return _G.Postal and _G.Postal.db ~= nil
end

function SarychUI_ShouldLoadPostalEmbedded()
	SarychUI_GetPostalLoadMode()
	local enabled, known = GetPostalRuntimeEnabledState()
	if known and not enabled then
		if _G.SarychUI_PostalLoadDecisionAtStartup == nil then
			_G.SarychUI_PostalLoadDecisionAtStartup = false
		end
		return false
	end
	if SarychUI_IsStandalonePostalEnabled() then
		if _G.SarychUI_PostalLoadDecisionAtStartup == nil then
			_G.SarychUI_PostalLoadDecisionAtStartup = false
		end
		return false
	end
	if _G.IsAddOnLoaded and _G.IsAddOnLoaded(STANDALONE_ADDON) then
		if _G.SarychUI_PostalLoadDecisionAtStartup == nil then
			_G.SarychUI_PostalLoadDecisionAtStartup = false
		end
		return false
	end
	-- Freeze first load-time decision so wrapper can distinguish
	-- "was disabled at startup" from real initialization failures.
	if _G.SarychUI_PostalLoadDecisionAtStartup == nil then
		_G.SarychUI_PostalLoadDecisionAtStartup = true
	end
	return true
end

function SarychUI_LoadEmbeddedPostal()
	SarychUI_GetPostalLoadMode()
	return SarychUI_IsEmbeddedPostalLoaded()
end

function SarychUI_InitializeEmbeddedPostal()
	SarychUI_GetPostalLoadMode()
	if not SarychUI_IsPostalRuntimeEnabled() then
		return false, "disabled"
	end
	if SarychUI_IsStandalonePostalEnabled() then
		return false, "standalone_conflict"
	end
	if SarychUI_IsEmbeddedPostalLoaded() then
		return true, "loaded"
	end
	if _G.SarychUI_PostalLoadDecisionAtStartup == false then
		return false, "requires_reload"
	end
	return false, "not_initialized"
end
