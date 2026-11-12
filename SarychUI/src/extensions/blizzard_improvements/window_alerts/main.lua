-- Built-in window alerts yield to separately loaded FlashWindow or Flash addons.
FlashWindowEnabled = FlashWindowEnabled or true

local function ExternalFlashLoaded()
    return IsAddOnLoaded and (IsAddOnLoaded("FlashWindow") or IsAddOnLoaded("Flash"))
end

local function IsEnabled()
	if FlashWindowEnabled == false then return false end
    if ExternalFlashLoaded() then return false end
    local addons = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
    if addons and addons.FlashWindow then return addons.FlashWindow.enabled ~= false end
    return FlashWindowEnabled ~= false
end

local frame = CreateFrame("Frame")
SarychUI_FlashWindowRuntime = frame
local alertEvents = { "PLAYER_REGEN_DISABLED", "CHAT_MSG_WHISPER", "LFG_PROPOSAL_SHOW", "READY_CHECK" }

function frame:RefreshRuntime()
    local active = IsEnabled() and type(_G.FlashWindow) == "function"
    for _, eventName in ipairs(alertEvents) do
        if active then self:RegisterEvent(eventName) else self:UnregisterEvent(eventName) end
    end
end

frame:SetScript("OnEvent", function(self, eventName, addonName)
    if eventName == "PLAYER_LOGIN" then
        if not self.popupHooked then
            self.popupHooked = true
            hooksecurefunc("StaticPopup_Show", function(name)
                if IsEnabled() and type(_G.FlashWindow) == "function"
                    and (name == "CONFIRM_BATTLEFIELD_ENTRY" or name == "PARTY_INVITE") then
                    _G.FlashWindow()
                end
            end)
        end
        self:RefreshRuntime()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif eventName == "ADDON_LOADED" then
        if addonName == "FlashWindow" or addonName == "Flash" then
            self:RefreshRuntime()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif IsEnabled() and type(_G.FlashWindow) == "function" then
        _G.FlashWindow()
    end
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
