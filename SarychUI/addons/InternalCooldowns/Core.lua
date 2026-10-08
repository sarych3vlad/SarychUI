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

local BLIZZARD_ACTION_PREFIXES = {
	{ "ActionButton", 12 },
	{ "MultiBarBottomLeftButton", 12 },
	{ "MultiBarBottomRightButton", 12 },
	{ "MultiBarLeftButton", 12 },
	{ "MultiBarRightButton", 12 },
	{ "BonusActionButton", 12 },
	{ "PetActionButton", 10 },
	{ "ShapeshiftButton", 10 },
}

-- Classic bars plus FrostAtomUI SarychUIActionButtonN replacements.
function mod:ForEachVisibleActionButton(fn)
	if not fn then return end
	local seen = {}
	local function visit(button)
		if not button or seen[button] then return end
		if button.IsVisible and not button:IsVisible() then return end
		local slot = button.action
		if not slot or slot <= 0 then return end
		seen[button] = true
		fn(button)
	end

	local FA = SarychUI and SarychUI.FrostAtomBars
	if FA and FA.IsActive and FA.IsActive() and FA.ForEachStyledButton then
		FA.ForEachStyledButton(visit)
	end
	for i = 1, 120 do
		visit(_G["SarychUIActionButton" .. i])
	end
	for p = 1, #BLIZZARD_ACTION_PREFIXES do
		local prefix, count = BLIZZARD_ACTION_PREFIXES[p][1], BLIZZARD_ACTION_PREFIXES[p][2]
		for i = 1, count do
			visit(_G[prefix .. i])
		end
	end
end

function mod:RegisterModuleOptions(name, optionTbl, displayName)
	do return end
	options.args[name] = (type(optionTbl) == "function") and optionTbl() or optionTbl
	if not optionFrames.default then
		optionFrames.default = ACD3:AddToBlizOptions("InternalCooldowns", nil, nil, name)
	else
		optionFrames[name] = ACD3:AddToBlizOptions("InternalCooldowns", displayName, "InternalCooldowns", name)
	end
end;