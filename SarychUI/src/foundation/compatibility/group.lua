local _, private = ...
local C = private.Compat
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
function C.IsInGroup()
    return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0;
end

function C.IsInRaid()
    return GetNumRaidMembers() > 0;
end

function C.GetNumSubgroupMembers()
    return GetNumPartyMembers();
end

function C.GetNumGroupMembers()
    local raid, party = GetNumRaidMembers(), GetNumPartyMembers();
    return raid > 0 and raid or (party > 0 and party + 1 or 0);
end
