-- Normalize native Wrath and compatibility-layer combat-log payloads.
local CombatLog = {}
SarychUI.CombatLog = CombatLog

local function ParsePayload(...)
    local timestamp, event, third = ...
    local sourceIndex, destIndex, spellIndex = 3, 6, 9
    if type(third) == "boolean" or third == "0" or third == "1" then
        sourceIndex, destIndex, spellIndex = 4, 7, 10
        -- Later clients also insert source/destination raid flags.
        if type(select(7, ...)) == "number" then destIndex, spellIndex = 8, 12 end
    end
    local source, sourceName, sourceFlags = select(sourceIndex, ...)
    local dest, destName, destFlags = select(destIndex, ...)
    local spell = select(spellIndex, ...)
    return event, source, sourceName, sourceFlags, dest, spell, destName, destFlags, timestamp
end

function CombatLog.Parse(...)
    if select("#", ...) == 0 then
        if CombatLogGetCurrentEventInfo then return ParsePayload(CombatLogGetCurrentEventInfo()) end
        return
    end
    return ParsePayload(...)
end
