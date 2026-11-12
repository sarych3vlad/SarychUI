-- Some clients emit UNIT_AURA without a unit token. Blizzard's 3.3.5
-- LFD handler calls strsub(unit, ...) and aborts the cooldown panel update.
local function Guard(handler)
    return function(self, event, unit, ...)
        if event == "UNIT_AURA" and type(unit) ~= "string" then
            -- This handler recomputes cooldowns for the entire party anyway.
            unit = "player"
        end
        return handler(self, event, unit, ...)
    end
end

local installed = false
local function Install()
    if installed then return true end
    local frame = LFDQueueFrameCooldownFrame
    local handler = LFDQueueFrameRandomCooldownFrame_OnEvent
    if not frame or type(handler) ~= "function" then return false end
    local current = frame:GetScript("OnEvent")
    if type(current) ~= "function" then return false end
    local guarded = Guard(handler)
    LFDQueueFrameRandomCooldownFrame_OnEvent = guarded
    -- XML stores the function itself, so replacing the global alone is insufficient.
    frame:SetScript("OnEvent", current == handler and guarded or Guard(current))
    installed = true
    return true
end

if not Install() then
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_LOGIN")
    watcher:SetScript("OnEvent", function(self)
        if Install() then self:UnregisterAllEvents() end
    end)
end
