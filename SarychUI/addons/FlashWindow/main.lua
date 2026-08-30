local ADDON_NAME = ...

-- Global enabled state
FlashWindowEnabled = FlashWindowEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.FlashWindow then
		return SarychUI.db.profile.addons.FlashWindow.enabled ~= false;
	end
	return FlashWindowEnabled;
end

-- local caching
local event = event
local FlashWindow = FlashWindow

-- main code

local frame = CreateFrame("frame")

function frame:OnInitialize()
	if not IsEnabled() then
		return;
	end
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterEvent("LFG_PROPOSAL_SHOW")
    self:RegisterEvent("READY_CHECK")
    
    hooksecurefunc("StaticPopup_Show", function(name)
		if not IsEnabled() then
			return;
		end
        if name == "CONFIRM_BATTLEFIELD_ENTRY" or name == "PARTY_INVITE" then
            FlashWindow()
        end
    end)
end

frame:SetScript("OnEvent", function(self, event, ...)
	if not IsEnabled() then
		return;
	end
    if event == "PLAYER_LOGIN" then
        if FlashWindow then
            self:OnInitialize()
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "CHAT_MSG_WHISPER" or event == "LFG_PROPOSAL_SHOW" or event == "READY_CHECK" then
        FlashWindow()
    end
end)

frame:RegisterEvent("PLAYER_LOGIN")
