local mod = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns"):NewModule("Bartender4", "AceEvent-3.0");
local lib = LibStub("LibInternalCooldowns-1.1");
if not _G.Bartender4 then return end

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.InternalCooldowns then
		return SarychUI.db.profile.addons.InternalCooldowns.enabled ~= false;
	end
	return InternalCooldownsEnabled ~= false;
end

function mod:OnEnable()
    if not IsEnabled() then
        return
    end
	lib.RegisterCallback(self, "InternalCooldowns_Proc")
end;

function mod:OnDisable()
	lib.UnregisterCallback(self, "InternalCooldowns_Proc")
end;

function mod:InternalCooldowns_Proc()
	for i = 1, 120 do
		local f = _G["BT4Button" .. i]
		if f and f:IsVisible() then
			ActionButton_UpdateCooldown(f)
		end
	end	
end;