-- Global enabled state
CL_FixEnabled = CL_FixEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if IsAddOnLoaded and IsAddOnLoaded("CombatLogFix") then return false end
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

    tCLFix = tCLFix + elapsed
    if tCLFix >= 10 then --time (in seconds) it takes before it executes the command on line 6
		CombatLogClearEntries()
        tCLFix = 0 --resets the timer
    end
end

-- Runtime handle used by the SarychUI core lifecycle.
CL_Fix = CL_Fix or {}
CL_Fix.f = f
CL_Fix.fCLFix = fCLFix

function CL_Fix:RefreshRuntime()
	local active = IsEnabled()
	if not active then tCLFix = 0 end
	f:SetScript("OnUpdate", active and fCLFix or nil)
end

-- CombatLogFix may load after SarychUI. Yield as soon as it appears.
local loadWatcher = CreateFrame("Frame")
loadWatcher:RegisterEvent("ADDON_LOADED")
loadWatcher:SetScript("OnEvent", function(self, _, addonName)
	if addonName == "CombatLogFix" then
		CL_Fix:RefreshRuntime()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

-- Set script only if enabled
CL_Fix:RefreshRuntime()
