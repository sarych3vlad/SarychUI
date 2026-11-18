-- One Tremor clock per creature, shared by arena rows and nameplate icons.
local Ticks = { totems = {}, consumers = {} }
SarychUI.TremorTicks = Ticks
function Ticks:ClearOwnerTotems(owner)
    if not owner then return end
    for guid, totem in pairs(self.totems) do
        if totem.owner == owner then self.totems[guid] = nil end
    end
end
local function IsHostile(flags)
    return type(flags) == "number" and bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE or 64) ~= 0
end
function Ticks:CombatEvent(event, source, sourceName, flags, dest, spell, destName, destFlags, timestamp)
    local now = GetTime()
    if not self.pruneAt or now >= self.pruneAt then
        for guid, record in pairs(self.totems) do
            if now >= record.expires then self.totems[guid] = nil end
        end
        self.pruneAt = now + 30
    end
    timestamp = timestamp or now
    local catalog = SarychUI.NameplateTotems
    local earth = catalog and catalog.Types.earth[spell]
    local summoned = event == "SPELL_SUMMON"
    local cast = event == "SPELL_CAST_SUCCESS"
    local tremor = spell == 8143 or (summoned and catalog and catalog:Resolve(destName, dest) == "e6")
    if ((summoned or cast) and earth and earth ~= "e6")
        or (cast and spell == 36936) then
        self:ClearOwnerTotems(source)
    end
    if (summoned or cast) and tremor then
        local key = summoned and dest or source
        if not key then return end
        -- Cast-success supplies a fallback on servers without SPELL_SUMMON.
        -- When the summon arrives, bind the same clock to the creature GUID.
        local previous = self.totems[key]
        if previous and (previous.eventTime == timestamp or (summoned and not previous.pending)) then return end
        local pending = source and self.totems[source]
        if cast then
            for _, record in pairs(self.totems) do
                if record.owner == source and record.eventTime == timestamp then return end
            end
        end
        local start = summoned and pending and pending.pending and now - pending.start <= 2 and pending.start or now
        self:ClearOwnerTotems(source)
        self.totems[key] = { owner = source, name = sourceName, start = start,
            expires = start + 300, eventTime = timestamp, pending = not summoned,
            hostile = IsHostile(flags) or IsHostile(destFlags) }
    elseif event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
        if dest then self.totems[dest] = nil end
        self:ClearOwnerTotems(dest)
    elseif spell == 8146 and (event == "SPELL_CAST_SUCCESS" or event == "SPELL_DISPEL") then
        local record = source and self.totems[source]
        if record then record.start = now end
    end
end

function Ticks:Clear()
    for guid in pairs(self.totems) do self.totems[guid] = nil end
    self.pruneAt = nil
end

function Ticks:Get(guid, now)
    local record = guid and self.totems[guid]
    if record and (now or GetTime()) >= record.expires then
        self.totems[guid] = nil
        return
    end
    return record
end

function Ticks:SetConsumer(key, enabled)
    self.consumers[key] = enabled and true or nil
    if next(self.consumers) then
        if not self.watcher then
            self.watcher = CreateFrame("Frame")
            self.watcher:SetScript("OnEvent", function(_, event, ...)
                if event == "PLAYER_ENTERING_WORLD" then self:Clear()
                else self:CombatEvent(SarychUI.CombatLog.Parse(...)) end
            end)
        end
        self.watcher:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self.watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        if self.watcher then self.watcher:UnregisterAllEvents() end
        self:Clear()
    end
end
