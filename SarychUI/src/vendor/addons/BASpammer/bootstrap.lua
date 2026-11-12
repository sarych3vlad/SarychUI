-- BASpammer runtime control for the embedded engine.

BASpammerEnabled = false

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
	if type(BASpammer_InstallHooks) == "function" then
		BASpammer_InstallHooks()
	end
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
