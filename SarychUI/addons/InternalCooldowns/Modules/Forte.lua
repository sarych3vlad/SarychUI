local mod = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns"):NewModule("Forte Cooldown", "AceEvent-3.0");
local lib = LibStub("LibInternalCooldowns-1.1");

if not _G.FW then return end

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
	lib.RegisterCallback(mod, "InternalCooldowns_Proc")
	lib.RegisterCallback(mod, "InternalCooldowns_TalentProc")
end;

function mod:OnDisable()
	lib.UnregisterCallback(mod, "InternalCooldowns_Proc")
	lib.UnregisterCallback(mod, "InternalCooldowns_TalentProc")
end;

function mod:InternalCooldowns_TalentProc(callback, spellID, start, duration)
	local name, _, icon = GetSpellInfo(spellID)
	FW:HiddenCooldown(name, duration, icon)
end;

function mod:InternalCooldowns_Proc(callback, itemID, spellID, start, duration)
	local name = GetSpellInfo(spellID)
	local texture = select(10, GetItemInfo(itemID))
	FW:HiddenCooldown(name, duration, texture)
end;