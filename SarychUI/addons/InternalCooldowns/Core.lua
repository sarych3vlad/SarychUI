local mod = LibStub("AceAddon-3.0"):NewAddon("InternalCooldowns");

-- Global enabled state for SarychUI integration
InternalCooldownsEnabled = InternalCooldownsEnabled or true

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.InternalCooldowns then
		return SarychUI.db.profile.addons.InternalCooldowns.enabled ~= false;
	end
	return InternalCooldownsEnabled;
end

local options = {
	type = "group",
	args = {}
};

local optionFrames = {};
local ACD3 = LibStub("AceConfigDialog-3.0");

-- Initialize InternalCooldownsDB ALWAYS, regardless of enabled state
-- This ensures settings are saved even when addon is disabled
if not InternalCooldownsDB then
	InternalCooldownsDB = {
		activeCooldowns = {},
		activeProcs = {},
		persistCooldowns = true
	}
else
	if not InternalCooldownsDB.activeCooldowns then
		InternalCooldownsDB.activeCooldowns = {}
	end
	if not InternalCooldownsDB.activeProcs then
		InternalCooldownsDB.activeProcs = {}
	end
	if InternalCooldownsDB.persistCooldowns == nil then
		InternalCooldownsDB.persistCooldowns = true
	end
end

function mod:OnInitialize()
	-- Always initialize options, even if disabled
	self.options = options
	
	-- Ensure DB is initialized (already done above, but double-check)
	if not InternalCooldownsDB then
		InternalCooldownsDB = {
			activeCooldowns = {},
			activeProcs = {},
			persistCooldowns = true
		}
	else
		if not InternalCooldownsDB.activeProcs then
			InternalCooldownsDB.activeProcs = {}
		end
	end
	
	-- Only continue if enabled
	if not IsEnabled() then
		return
	end
end;

function mod:RegisterModuleOptions(name, optionTbl, displayName)
	do return end
	options.args[name] = (type(optionTbl) == "function") and optionTbl() or optionTbl
	if not optionFrames.default then
		optionFrames.default = ACD3:AddToBlizOptions("InternalCooldowns", nil, nil, name)
	else
		optionFrames[name] = ACD3:AddToBlizOptions("InternalCooldowns", displayName, "InternalCooldowns", name)
	end
end;