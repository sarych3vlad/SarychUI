-- BASpammer bootstrap for SarychUI embedding (valve: core loads only when enabled).

BASpammerEnabled = false

local ADDON_NAME = "BASpammer"

local function IsTruthyEnabled(v)
	return v == true or v == 1
end

local function GetSavedProfile()
	if SarychUI and SarychUI.db and type(SarychUI.db.profile) == "table" then
		return SarychUI.db.profile
	end
	if type(SarychUIDB) ~= "table" then
		return nil
	end

	local general = SarychUIDB.global and SarychUIDB.global.general
	if general and general.alwaysUseProfile == true then
		local shared = general.alwaysUseProfileName
		if (type(shared) ~= "string" or shared == "") and type(SarychUIDB.profileKeys) == "table" then
			shared = SarychUIDB.profileKeys["*"]
		end
		if type(shared) == "string" and shared ~= ""
			and type(SarychUIDB.profiles) == "table"
			and type(SarychUIDB.profiles[shared]) == "table" then
			return SarychUIDB.profiles[shared]
		end
	end

	local key = SarychUI_ResolveSavedProfileKey and SarychUI_ResolveSavedProfileKey() or "Default"
	if type(SarychUIDB.profiles) == "table" and type(SarychUIDB.profiles[key]) == "table" then
		return SarychUIDB.profiles[key]
	end
	if type(SarychUIDB.profile) == "table" then
		return SarychUIDB.profile
	end
	return nil
end

local function GetBASpammerEnabledFromSaved()
	local profile = GetSavedProfile()
	local cfg = profile and profile.addons and profile.addons[ADDON_NAME]
	if type(cfg) == "table" and cfg.enabled ~= nil then
		return IsTruthyEnabled(cfg.enabled)
	end
	return false
end

function SarychUI_IsStandaloneBASpammerEnabled()
	if not GetNumAddOns or not GetAddOnInfo then
		return false
	end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable, reason = GetAddOnInfo(i)
		if name == "BASpammer" and reason ~= "MISSING" and enabled and loadable then
			return true
		end
	end
	return false
end

function SarychUI_IsBASpammerCoreLoaded()
	return type(BASpammer_OnEvent) == "function"
end

function SarychUI_ShouldLoadBASpammerEmbedded()
	if _G.SarychUI_BASpammerLoadDecisionAtStartup ~= nil then
		return _G.SarychUI_BASpammerLoadDecisionAtStartup
	end
	if SarychUI_IsStandaloneBASpammerEnabled() then
		_G.SarychUI_BASpammerLoadDecisionAtStartup = false
		return false
	end
	local load = GetBASpammerEnabledFromSaved()
	_G.SarychUI_BASpammerLoadDecisionAtStartup = load
	return load
end

function SarychUI_NeuterBASpammerFrames()
	local main = _G.BASpammer
	if main then
		main:Hide()
		main:EnableMouse(false)
		main:SetScript("OnUpdate", nil)
		main:SetScript("OnMouseDown", nil)
		main:SetScript("OnMouseUp", nil)
		main:SetScript("OnEnter", nil)
		main:SetScript("OnLeave", nil)
		main:UnregisterAllEvents()
	end
	local settings = _G.BASpammerSetting
	if settings then
		settings:Hide()
		settings:EnableMouse(false)
		settings:SetScript("OnMouseDown", nil)
		settings:SetScript("OnMouseUp", nil)
		settings:UnregisterAllEvents()
	end
end

function SarychUI_ApplyBASpammerRuntime(enable)
	BASpammerEnabled = enable and true or false
	if not SarychUI_IsBASpammerCoreLoaded() then
		return
	end
	if _G.BASpammer then
		if enable then
			_G.BASpammer:Show()
		else
			_G.BASpammer:Hide()
			if _G.BASpammerSetting then
				_G.BASpammerSetting:Hide()
			end
			if BASpammerDB then
				BASpammerDB.Tumbler = false
			end
			if type(BASpammer_SetText) == "function" then
				BASpammer_SetText()
			end
		end
	end
end

function SarychUI_InitEmbeddedBASpammer()
	if not SarychUI_IsBASpammerCoreLoaded() then
		return false, "requires_reload"
	end
	if _G.BASpammerEmbeddedInitialized then
		return true, "loaded"
	end
	_G.BASpammerEmbeddedInitialized = true
	if _G.BASpammer and _G.BASpammer.SetupFrames then
		_G.BASpammer:SetupFrames()
	end
	if _G.BASpammerSettingTextSymbols and _G.BASpammer_InsertAchievementBtn then
		_G.BASpammerSettingTextSymbols:ClearAllPoints()
		_G.BASpammerSettingTextSymbols:SetPoint("BOTTOMLEFT", _G.BASpammer_InsertAchievementBtn, "TOPLEFT", 124, -19)
		_G.BASpammerSettingTextSymbols:SetJustifyH("LEFT")
	end
	return true, "loaded"
end
