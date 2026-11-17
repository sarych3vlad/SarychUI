local module = SarychUI.modules.automation
local requestFrame
local restoreUIParentEvent = false

local function IsTargetChallenger(challenger)
    if not challenger or not UnitIsPlayer("target") then return false end
    local name, realm = UnitName("target")
    if not name then return false end
    local localRealm = GetRealmName()
    realm = realm and realm ~= "" and realm or localRealm
    if challenger == name then return realm == localRealm end
    return challenger == name .. "-" .. realm:gsub("%s", "")
end

local function OnDuelRequested(_, event, challenger, ...)
    local db = SarychUI:GetModuleProfile("automation")
    if db and db.autoDeclineDuelTargetException == 1 and IsTargetChallenger(challenger) then
        -- Keep the normal confirmation; the exception never accepts a duel.
        if restoreUIParentEvent then
            local handler = UIParent:GetScript("OnEvent")
            if handler then handler(UIParent, event, challenger, ...) end
        end
        return
    end
    CancelDuel()
    StaticPopup_Hide("DUEL_REQUESTED")
end

function module:DisableAutoDeclineDuels()
    if requestFrame then requestFrame:UnregisterEvent("DUEL_REQUESTED") end
    if restoreUIParentEvent then
        UIParent:RegisterEvent("DUEL_REQUESTED")
        restoreUIParentEvent = false
    end
end

function module:ApplyAutoDeclineDuels()
    local db = SarychUI:GetModuleProfile("automation")
    if not db or db.enabled ~= true or db.enableAutoDeclineDuels ~= 1 then
        self:DisableAutoDeclineDuels()
        return
    end
    if not requestFrame then
        requestFrame = CreateFrame("Frame")
        requestFrame:SetScript("OnEvent", OnDuelRequested)
    end
    if requestFrame:IsEventRegistered("DUEL_REQUESTED") then return end
    -- Suppress the native popup/sound before dispatch, independent of event order.
    -- Restore only a subscription that this feature actually removed.
    restoreUIParentEvent = UIParent:IsEventRegistered("DUEL_REQUESTED") and true or false
    if restoreUIParentEvent then UIParent:UnregisterEvent("DUEL_REQUESTED") end
    requestFrame:RegisterEvent("DUEL_REQUESTED")
end
