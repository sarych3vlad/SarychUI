local mod = LibStub("AceAddon-3.0"):NewAddon("InternalCooldowns");
mod:SetEnabledState(false)
-- AceAddon queues children independently at login. The owner enables them
-- together with the engine, after the SarychUI runtime gate has been set.
mod:SetDefaultModuleState(false)

-- Global enabled state for SarychUI integration
InternalCooldownsEnabled = InternalCooldownsEnabled ~= false

-- Function to check if addon is enabled
local function IsEnabled()
	if InternalCooldownsEnabled == false then return false end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.InternalCooldowns then
		return SarychUI.db.profile.addons.InternalCooldowns.enabled ~= false;
	end
	return InternalCooldownsEnabled;
end

local options = {
	type = "group",
	args = {}
};


-- SavedVariables replace the global after file execution; normalize on initialization.
local function InitializeDatabase()
	InternalCooldownsDB = InternalCooldownsDB or {}
	InternalCooldownsDB.activeCooldowns = InternalCooldownsDB.activeCooldowns or {}
	InternalCooldownsDB.activeProcs = InternalCooldownsDB.activeProcs or {}
	if InternalCooldownsDB.persistCooldowns == nil then
		InternalCooldownsDB.persistCooldowns = true
	end
end

function mod:OnInitialize()
	-- Always initialize options, even if disabled
	self.options = options
	
	InitializeDatabase()
	
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
