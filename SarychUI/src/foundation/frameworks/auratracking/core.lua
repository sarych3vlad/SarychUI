-- Shared indexed aura reads and UNIT_AURA dispatch for SUI aura consumers.
local A = { listeners = {}, combatListeners = {}, scans = 0 }
SarychUI.AuraTracking = A
local NativeAura, NativeBuff, NativeDebuff = UnitAura, UnitBuff, UnitDebuff
local unpack, select = unpack, select
local cache, cacheTime = {}, nil
local frame = CreateFrame("Frame")

local function Pack(...)
    return { n = select("#", ...), ... }
end

function A:Invalidate()
    cache, cacheTime = {}, GetTime()
end

local function Read(unit, index, filter, native, ...)
    -- Named lookups and special Blizzard filters keep their native semantics.
    if type(index) ~= "number" or (filter ~= "HELPFUL" and filter ~= "HARMFUL") or select("#", ...) > 0 then
        return native(unit, index, filter, ...)
    end
    local now = GetTime()
    if cacheTime ~= now then A:Invalidate() end
    local guid = UnitGUID(unit)
    if not guid then return native(unit, index, filter) end
    local key = guid .. ":" .. filter
    local snapshot = cache[key]
    if not snapshot then
        snapshot = {}
        cache[key] = snapshot
        A.scans = A.scans + 1
        for i = 1, 40 do
            local entry = Pack(NativeAura(unit, i, filter))
            if not entry[1] then break end
            snapshot[i] = entry
        end
    end
    local entry = snapshot[index]
    if entry then return unpack(entry, 1, entry.n) end
end

function A.UnitAura(unit, index, filter, ...)
    return Read(unit, index, filter or "HELPFUL", NativeAura, ...)
end
function A.UnitBuff(unit, index, filter, ...)
    if filter then return NativeBuff(unit, index, filter, ...) end
    return Read(unit, index, "HELPFUL", NativeAura, ...)
end
function A.UnitDebuff(unit, index, filter, ...)
    if filter then return NativeDebuff(unit, index, filter, ...) end
    return Read(unit, index, "HARMFUL", NativeAura, ...)
end

function A:Subscribe(key, callback)
    self.listeners[key] = callback
    frame:RegisterEvent("UNIT_AURA")
end
function A:Unsubscribe(key)
    self.listeners[key] = nil
    if not next(self.listeners) then frame:UnregisterEvent("UNIT_AURA") end
end
function A:SubscribeCombat(key, callback)
    self.combatListeners[key] = callback
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end
function A:UnsubscribeCombat(key)
    self.combatListeners[key] = nil
    if not next(self.combatListeners) then frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
end
frame:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local subEvent = select(1, ...)
        if subEvent and subEvent:find("^SPELL_AURA_") then A:Invalidate() end
        for _, callback in pairs(A.combatListeners) do
            local ok, err = pcall(callback, unit, ...)
            if not ok then geterrorhandler()(err) end
        end
        return
    end
    A:Invalidate()
    for _, callback in pairs(A.listeners) do
        local ok, err = pcall(callback, unit)
        if not ok then geterrorhandler()(err) end
    end
end)

-- Shared rank/name matching; consumer-specific priorities and overrides stay local.
local spellNames = {}
local function SpellName(id)
    if not spellNames[id] then spellNames[id] = GetSpellInfo(id) end
    return spellNames[id]
end
function A:BuildSpellIndex(data)
    local result = {}
    for id, entry in pairs(data) do
        if type(id) == "number" and (type(entry) ~= "table" or entry.enabled ~= false) then
            local name = SpellName(id)
            if name and (not result[name] or id > result[name]) then result[name] = id end
        end
    end
    return result
end
function A:ResolveSpell(data, id, names)
    if data[id] ~= nil then return data[id], id end
    local name = id and SpellName(id)
    local match = name and names and names[name]
    if match and data[match] ~= nil then return data[match], match end
    local record = SarychUI.Data.AuraTracking.records[id]
    local parent = record and record.bigDebuffs and record.bigDebuffs.parent
    if parent and data[parent] ~= nil then return data[parent], parent end
end
