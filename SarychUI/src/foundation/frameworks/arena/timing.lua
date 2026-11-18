-- Server timing differences are independent of client/message language.
local Timing = {}
SarychUI.ArenaTiming = Timing

local function IsCircle()
    local address = GetCVar and GetCVar("realmList")
    if type(address) == "string" then
        local host = address:lower():match("^%s*([^:%s]+)") or ""
        if host:match("^wowcircle%.%a+$") or host:match("%.wowcircle%.%a+$") then return true end
        -- A known connection address takes priority over a stale realm label.
        if host ~= "" then return false end
    end
    local realm = GetRealmName and GetRealmName()
    return type(realm) == "string" and realm:lower():match("^wow%s*circle[%s%-]") ~= nil
end

function Timing:DoorLead()
    -- Restore the pre-Warmane Circle calculation from ebe9915. The settings
    -- slider remains an additional user correction, including when it is zero.
    return IsCircle() and 0.8 or 0
end

function Timing:EyeRespawn()
    -- Circle: observed repeat pickup 30s before the old 120s clock expired.
    -- Keep the existing 120s baseline on other servers; this is not aura duration.
    return IsCircle() and 90 or 120
end
