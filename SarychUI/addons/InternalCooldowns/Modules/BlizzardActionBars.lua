local addon = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns");
local mod = addon:NewModule("BlizzardActionBars", "AceEvent-3.0");
local lib = LibStub("LibInternalCooldowns-1.1");

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.InternalCooldowns then
		return SarychUI.db.profile.addons.InternalCooldowns.enabled ~= false;
	end
	return InternalCooldownsEnabled ~= false;
end

local updateFrame = nil;
local updateInterval = 0.1;
local lastUpdate = 0;

local function RefreshButtonCooldown(button)
	if button.UpdateCooldown then
		button:UpdateCooldown();
	elseif ActionButton_UpdateCooldown then
		ActionButton_UpdateCooldown(button);
	end
end

function mod:OnEnable()
    if not IsEnabled() then
        return
    end
    
    if not updateFrame then
        updateFrame = CreateFrame("Frame");
        updateFrame:SetScript("OnUpdate", function(self, elapsed)
            lastUpdate = lastUpdate + elapsed;
            if lastUpdate >= updateInterval then
                mod:UpdateActionButtonCooldowns();
                lastUpdate = 0;
            end
        end);
    end
    
    lib.RegisterCallback(self, "InternalCooldowns_Proc");
end;

function mod:OnDisable()
    if updateFrame then
        updateFrame:SetScript("OnUpdate", nil);
    end
    
    lib.UnregisterCallback(self, "InternalCooldowns_Proc");
end;

function mod:UpdateActionButtonCooldowns()
    addon:ForEachVisibleActionButton(RefreshButtonCooldown);
end;

function mod:InternalCooldowns_Proc(callback, itemID, spellID, start, duration, procSource)
    self:UpdateActionButtonCooldowns();
end;
