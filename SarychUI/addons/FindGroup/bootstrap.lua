-- FindGroup bootstrap for SarychUI embedding

FindGroupEnabled = false

local function ResolveSarychUIProfile()
	if type(SarychUIDB) ~= "table" or type(SarychUIDB.profiles) ~= "table" then
		return nil
	end

	local profileKey = (SarychUI_ResolveSavedProfileKey and SarychUI_ResolveSavedProfileKey()) or "Default"
	local profile = SarychUIDB.profiles[profileKey]
	if type(profile) == "table" then
		return profile
	end
	return SarychUIDB.profiles.Default
end

function SarychUI_GetEmbeddedFindGroupEnabledFromSavedDB()
	local profile = ResolveSarychUIProfile()
	if profile and profile.addons and profile.addons.FindGroup then
		return profile.addons.FindGroup.enabled == true
	end
	return false
end

function SarychUI_IsStandaloneFindGroupEnabled()
	if not GetNumAddOns or not GetAddOnInfo then
		return false
	end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable = GetAddOnInfo(i)
		if name == "FindGroup" and enabled and loadable then
			return true
		end
	end
	return false
end

function SarychUI_FindGroup_RegisterChatFilters()
	if SarychUI_FindGroup_RegisterFindChatFilters then
		SarychUI_FindGroup_RegisterFindChatFilters()
	end
	if SarychUI_FindGroup_RegisterSavesChatFilters then
		SarychUI_FindGroup_RegisterSavesChatFilters()
	end
end

function SarychUI_FindGroup_UnregisterChatFilters()
	if SarychUI_FindGroup_UnregisterSavesChatFilters then
		SarychUI_FindGroup_UnregisterSavesChatFilters()
	end
	if SarychUI_FindGroup_UnregisterFindChatFilters then
		SarychUI_FindGroup_UnregisterFindChatFilters()
	end
end

function SarychUI_ApplyFindGroupRuntime(enable)
	FindGroupEnabled = enable and true or false
	if FGL and FGL.db then
		FGL.db.includeaddon = FindGroupEnabled and 1 or 0
	end

	if enable then
		if type(SarychUI_InitEmbeddedFindGroup) == "function" then
			SarychUI_InitEmbeddedFindGroup()
		end
		SarychUI_FindGroup_RegisterChatFilters()
	else
		SarychUI_FindGroup_UnregisterChatFilters()
		if type(LeaveChannelByName) == "function" and FGL and FGL.ChannelName then
			pcall(LeaveChannelByName, FGL.ChannelName)
		end
		if type(SarychUI_HideEmbeddedFindGroupUI) == "function" then
			SarychUI_HideEmbeddedFindGroupUI()
		end
		if SlashCmdList then
			SlashCmdList["FindGroup"] = function() end
		end
	end
end

if SarychUI_IsStandaloneFindGroupEnabled() then
	FindGroupEnabled = false
else
	FindGroupEnabled = SarychUI_GetEmbeddedFindGroupEnabledFromSavedDB() and true or false
end

function SarychUI_FindGroupIsActive()
	if FindGroupEnabled ~= true then
		return false
	end
	if SarychUI_IsStandaloneFindGroupEnabled and SarychUI_IsStandaloneFindGroupEnabled() then
		return false
	end
	if not FindGroupCharVars then
		return false
	end
	if FGL and FGL.db and (not FGL.db.includeaddon or FGL.db.includeaddon == 0) then
		return false
	end
	return true
end
