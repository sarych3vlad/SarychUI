local MAX_CUF_PROFILES = 10;
local PROFILES, CUF_CONFIG, PROFILE_COPY;

local DEFAULT_PROFILE = {
	name = DEFAULT_CUF_PROFILE_NAME,
	isDynamic = true,

	shown = true,
	locked = true,
	sortBy = "group",
	displayAggroHighlight = true,
	displayMainTankAndAssist = true,
	displayBorder = true,
	displayNonBossDebuffs = true,
	healthText = "none",
	frameWidth = 72,
	frameHeight = 36,
};

local ALL_OPTIONS = {
	shown = 0,
	locked = 0,
	keepGroupsTogether = 1,
	horizontalGroups = 1,
	sortBy = 1,
	displayPowerBar = 1,
	displayAggroHighlight = 1,
	useClassColors = 1,
	displayPets = 1,
	displayMainTankAndAssist = 1,
	displayBorder = 1,
	displayNonBossDebuffs = 1,
	displayOnlyDispellableDebuffs = 1,
	healthText = 1,
	frameWidth = 1,
	frameHeight = 1,
	autoActivate2Players = 1,
	autoActivate3Players = 1,
	autoActivate5Players = 1,
	autoActivate10Players = 1,
	autoActivate15Players = 1,
	autoActivate25Players = 1,
	autoActivate40Players = 1,
	autoActivatePvP = 1,
	autoActivatePvE = 1,
};

local ProfileAPI = CreateFrame("Frame");
ProfileAPI:SetScript("OnEvent", function(self, event, addon)
	if ( addon == "CompactRaidFrame" or addon == "SarychUI" ) then
		local ID = "CompactRaidFrameDB";
		local DB = _G[ID];

		if ( DB ) then
			-- Migration
			if ( DB.profileKeys or DB.profile ) then
				wipe(DB);
			else
				local P1 = DB[1];
				if ( P1 and (P1.autoActivateSpec1 or P1.autoActivateSpec2) ) then
					for i=1,#DB do
						local DB = DB[i];
						DB.autoActivateSpec1 = nil;
						DB.autoActivateSpec2 = nil;
					end
				end
			end
		else
			DB = {useCompactPartyFrames = "1"};
			_G[ID] = DB;
		end

		PROFILES = DB;
		CUF_CONFIG = DB;

		CompactUnitFrameProfiles_OnEvent(CompactUnitFrameProfiles, "COMPACT_UNIT_FRAME_PROFILES_LOADED");
		self:UnregisterEvent(event);
		self:SetScript("OnEvent", nil);
	end
end)
ProfileAPI:RegisterEvent("ADDON_LOADED");

function GetNumRaidProfiles()
	if ( not PROFILES ) then
		return 0;
	end

	return #PROFILES;
end

function GetRaidProfileName(index)
	if ( not PROFILES or not index ) then
		return;
	end

	if PROFILES[index] then
		return PROFILES[index].name;
	end
end

function RaidProfileExists(profile)
	if ( not PROFILES or not profile ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i];
		if ( profileData.name == profile ) then
			return true;
		end
	end
end

function HasLoadedCUFProfiles()
	return PROFILES and true or false;
end

function RaidProfileHasUnsavedChanges()
	if not ( PROFILES and PROFILE_COPY ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i]
		if ( profileData.name == PROFILE_COPY.name ) then
			for option, valid in pairs(ALL_OPTIONS) do
				if ( valid == 1 and profileData[option] ~= PROFILE_COPY[option] ) then
					return true;
				end
			end
		end
	end
end

function RestoreRaidProfileFromCopy()
	if ( not PROFILE_COPY or not RaidProfileHasUnsavedChanges() ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i]
		if ( profileData.name == PROFILE_COPY.name ) then
			for option, valid in pairs(ALL_OPTIONS) do
				if ( valid == 1 and profileData[option] ~= PROFILE_COPY[option] ) then
					profileData[option] = PROFILE_COPY[option];
				end
			end
			break;
		end
	end
end

function CreateNewRaidProfile(name, baseOnProfile)
	if ( not PROFILES or not name ) then
		return;
	end

	local profile
	if ( baseOnProfile and baseOnProfile ~= DEFAULTS ) then
		for i=1,#PROFILES do
			local profileData = PROFILES[i];
			if ( profileData.name == baseOnProfile ) then
				profile = CopyTable(profileData);
				break;
			end
		end
	else
		profile = CopyTable(DEFAULT_PROFILE);
	end

	profile.name = name;
	table.insert(PROFILES, profile);
end

function DeleteRaidProfile(profile)
	if ( not PROFILES or not profile ) then
		return;
	end

	if ( type(profile) == "number" ) then
		table.remove(PROFILES, profile);
	else
		for i=1,#PROFILES do
			local profileData = PROFILES[i];
			if ( profileData.name == profile ) then
				table.remove(PROFILES, i);
				break;
			end
		end
	end
end

function SaveRaidProfileCopy(profile)
	if ( not profile or (PROFILE_COPY and not RaidProfileHasUnsavedChanges()) ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i];
		if ( profileData.name == profile ) then
			PROFILE_COPY = CopyTable(profileData);
			break;
		end
	end
end

function SetRaidProfileOption(profile, optionName, value)
	if ( not PROFILES or not profile or not optionName ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i];
		if ( profileData.name == profile ) then
			PROFILES[i][optionName] = value or nil;
			break;
		end
	end
end

function GetRaidProfileOption(profile, optionName)
	if ( not PROFILES or not profile or not optionName ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i];
		if ( profileData.name == profile ) then
			return profileData[optionName];
		end
	end
end

function GetRaidProfileFlattenedOptions(profile)
	if ( not PROFILES or not profile ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i];
		if ( profileData.name == profile ) then
			local flattenedCache = {};
			for option, value in pairs(ALL_OPTIONS) do
				flattenedCache[option] = profileData[option] or false;
			end
			return flattenedCache;
		end
	end
end

function SetRaidProfileSavedPosition(profile, isDynamic, topPoint, topOffset, bottomPoint, bottomOffset, leftPoint, leftOffset)
	if ( not PROFILES or not profile ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i];
		if ( profileData.name == profile ) then
			profileData.isDynamic = isDynamic or nil;
			profileData.topPoint = topPoint;
			profileData.topOffset = topOffset;
			profileData.bottomPoint = bottomPoint;
			profileData.bottomOffset = bottomOffset;
			profileData.leftPoint = leftPoint;
			profileData.leftOffset = leftOffset;
			break;
		end
	end
end

function GetRaidProfileSavedPosition(profile)
	if ( not PROFILES or not profile ) then
		return;
	end

	for i=1,#PROFILES do
		local profileData = PROFILES[i];
		if ( profileData.name == profile ) then
			return profileData.isDynamic, profileData.topPoint, profileData.topOffset, profileData.bottomPoint, profileData.bottomOffset, profileData.leftPoint, profileData.leftOffset;
		end
	end
end

function GetMaxNumCUFProfiles()
	return MAX_CUF_PROFILES;
end

function SetActiveRaidProfile(profile)
	CUF_CVar:SetValue("ACTIVE_CUF_PROFILE", profile);
end

function GetActiveRaidProfile()
	return CUF_CVar:GetValue("ACTIVE_CUF_PROFILE");
end

CUF_CVar = {}
function CUF_CVar:SetValue(cvar, value)
	if ( not CUF_CONFIG ) then
		return;
	end

	CUF_CONFIG[cvar] = value ~= "0" and value or nil;
end

function CUF_CVar:GetValue(cvar, addon)
	if ( not CUF_CONFIG ) then
		return;
	end

	return CUF_CONFIG[cvar];
end

function CUF_CVar:GetCVarBool(cvar)
	return self:GetValue(cvar) == "1" and true or false;
end