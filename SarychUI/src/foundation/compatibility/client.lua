-- Only the client operations required by SarychUI. No global shim exports.
local _, private = ...
local C = private.Compat
local GetAddOnInfo, IsAddOnLoaded = GetAddOnInfo, IsAddOnLoaded
local IsAddOnLoadOnDemand, GetCVar = IsAddOnLoadOnDemand, GetCVar
C.AddOns = {}
function C.AddOns.GetInfo(index)
    local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(index)
    if loadable and not IsAddOnLoaded(index) and IsAddOnLoadOnDemand(index) then
        loadable, reason = false, "DEMAND_LOADED"
    end
    return name, title, notes, not not loadable, reason, security, nil
end
function C.AddOns.GetEnableState(character, index)
    local _, _, _, enabled = GetAddOnInfo(index or character)
    return enabled and 2 or 0
end
function C.AddOns.IsVersionCheckEnabled() return GetCVar("checkAddonVersion") == "1" end
local UnitHasVehicleUI = UnitHasVehicleUI
function C.HasVehicleActionBar() return UnitHasVehicleUI("player") end

C.Items = {}
function C.Items.GetID(value)
    if type(value) == "string" then value = tonumber(value:match("item:(%d+)") or value) end
    if type(value) == "number" and value > 0 and value == math.floor(value) then return value end
end
local GetItemInfo, GetInventoryItemID = GetItemInfo, GetInventoryItemID
function C.Items.IsTrinket(value)
    local id = C.Items.GetID(value)
    if not id then return false end
    -- Equipment locations are locale-independent; type/subtype names are not.
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(id)
    if equipLoc then return equipLoc == "INVTYPE_TRINKET" end
    -- An equipped item may not have populated the item cache yet.
    return GetInventoryItemID("player", 13) == id or GetInventoryItemID("player", 14) == id
end
