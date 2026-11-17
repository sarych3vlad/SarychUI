-- WotLK GUID layout: high type (16 bits), creature entry (24), spawn counter (24).
-- Parse only the entry substring; converting the whole 64-bit GUID loses precision.
local Identity = {}
SarychUI.NameplateIdentity = Identity

function Identity:IsPetGUID(guid)
    if not self:GetCreatureID(guid) then return false end
    if guid:match("^Pet%-") then return true end
    local high = guid:sub(3,5):upper()
    return high == "F14" or high == "F54"
end

function Identity:GetCreatureID(guid)
    if type(guid) ~= "string" then return end
    if #guid == 18 and guid:match("^0[xX]%x+$") then
        local high = guid:sub(3,5):upper()
        if high == "F13" or high == "F14" or high == "F15"
            or high == "F53" or high == "F54" or high == "F55" then
            return tonumber(guid:sub(7,12),16)
        end
        return
    end
    local entry = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
        or guid:match("^Pet%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
    return entry and tonumber(entry)
end
