-- Global enabled state
CL_FixEnabled = CL_FixEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.CL_Fix then
		return SarychUI.db.profile.addons.CL_Fix.enabled ~= false;
	end
	return CL_FixEnabled;
end

local tCLFix = 0
local f = CreateFrame("frame")

local function fCLFix(self,elapsed)
	if not IsEnabled() then
		return
	end

	if SarychUI and SarychUI.Compatibility and SarychUI.Compatibility:ShouldSkipCombatLogClear() then
		return
	end
	
    tCLFix = tCLFix + elapsed
    if tCLFix >= 10 then --time (in seconds) it takes before it executes the command on line 6
		CombatLogClearEntries()
        tCLFix = 0 --resets the timer
    end
end

-- Store frame and function globally for wrapper access
CL_Fix = CL_Fix or {}
CL_Fix.f = f
CL_Fix.fCLFix = fCLFix

-- Set script only if enabled
if IsEnabled() then
	if not (SarychUI and SarychUI.Compatibility and SarychUI.Compatibility:ShouldSkipCombatLogClear()) then
		f:SetScript("OnUpdate", fCLFix)
	end
else
	f:SetScript("OnUpdate", nil)
end