-- Shared friendly-player identity for Classic and ElvUI nameplate adapters.
local Classes = {}
SarychUI.FriendlyNameplateClasses = Classes
local driver = CreateFrame("Frame")
driver:Hide()
local active, awesome = false, false
local leavingWorld = false
local scoreElapsed = 0
local rosters, observed = {}, {}
local plateUnits = setmetatable({}, {__mode="k"})
local preparedPlates = setmetatable({}, {__mode="k"})
local currentUnits = {"target", "mouseover", "focus", "player"}
local observationEvents = {PLAYER_TARGET_CHANGED="target", UPDATE_MOUSEOVER_UNIT="mouseover",
    PLAYER_FOCUS_CHANGED="focus"}
local zoneEvents = {PLAYER_ENTERING_WORLD=true, ZONE_CHANGED=true,
    ZONE_CHANGED_INDOORS=true, ZONE_CHANGED_NEW_AREA=true}
local rosterEvents = {PARTY_MEMBERS_CHANGED=true, RAID_ROSTER_UPDATE=true,
    GUILD_ROSTER_UPDATE=true, PLAYER_GUILD_UPDATE=true, UPDATE_BATTLEFIELD_SCORE=true}

local function UseAwesome()
    local compat = SarychUI.Compatibility
    return compat and compat:IsAwesomeWotlkEnabled() or false
end

local function SameName(name, unitName, realm)
    return name == unitName or (unitName and realm and name == unitName .. "-" .. realm)
end

local function UnitPlayerClass(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsFriend("player", unit) then return end
    local _, class = UnitClass(unit)
    return class
end

local function AddPlayer(list, name, class)
    if not name or not class or not RAID_CLASS_COLORS[class] then return end
    local key = name:lower()
    local short = key:match("^[^-]+")
    for _, alias in ipairs({key, short}) do
        if list[alias] == nil or list[alias] == class then list[alias] = class
        else list[alias] = false end
    end
end

local function AddUnit(list, unit)
    local class = UnitPlayerClass(unit)
    if not class then return end
    local name, realm = UnitName(unit)
    if name and realm and realm ~= "" then name = name .. "-" .. realm end
    AddPlayer(list, name, class)
    return class
end

local function InBattleground()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    return inside and kind == "pvp"
end

local function RefreshRosters()
    wipe(rosters)
    if awesome then return end
    AddUnit(rosters, "player")
    for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do AddUnit(rosters, "party" .. i) end
    for i = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do AddUnit(rosters, "raid" .. i) end
    if IsInGuild and IsInGuild() and GetGuildRosterInfo and GetNumGuildMembers then
        for i = 1, GetNumGuildMembers(true) do
            local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
            AddPlayer(rosters, name, class)
        end
    end
    -- The client can retain scores from the previous match after leaving it.
    if InBattleground() and GetNumBattlefieldScores and GetBattlefieldScore then
        for i = 1, GetNumBattlefieldScores() do
            local name, _, _, _, _, _, _, _, _, class = GetBattlefieldScore(i)
            AddPlayer(rosters, name, class)
        end
    end
end

local function RequestRosters()
    if awesome then return end
    if IsInGuild and IsInGuild() and GuildRoster then GuildRoster() end
    if InBattleground() and RequestBattlefieldScoreData then RequestBattlefieldScoreData() end
end

local function Notify(plate, beforeShow, removed)
    if Classes.OnChanged then Classes.OnChanged(plate, beforeShow, removed) end
end

function Classes:UseAwesome()
    return UseAwesome()
end

function Classes:PreparePlate(plate)
    if not plate or preparedPlates[plate] then return end
    preparedPlates[plate] = true
    plate:HookScript("OnShow", function()
        if active and UseAwesome() then Notify(plate) end
    end)
    plate:HookScript("OnHide", function() plateUnits[plate] = nil end)
    plate:HookScript("OnUpdate", function()
        -- Identity/text may arrive after ADDED or after a renderer's OnShow.
        -- Read live unit data before drawing; do not cache classes by name.
        if active and not leavingWorld and UseAwesome() then Notify(plate) end
    end)
end

local function ValidPlateUnit(plate, unit)
    return unit and UnitExists(unit) and C_NamePlate.GetNamePlateForUnit(unit) == plate
end

function Classes:GetPlateUnit(plate)
    if not active or leavingWorld or not plate or not UseAwesome() then return end
    self:PreparePlate(plate)
    local unit = plateUnits[plate]
    -- ADDED may precede usable unit data. Keep only the lifetime binding,
    -- validating it against the API every time; never retain the player's class.
    if ValidPlateUnit(plate, unit) then return unit end
    unit = plate.namePlateUnitToken
    if ValidPlateUnit(plate, unit) then return unit end
    unit = plate.UnitFrame and plate.UnitFrame.unit
    if ValidPlateUnit(plate, unit) then return unit end
end

local function SyncAwesome()
    local enabled = active and UseAwesome() or false
    if awesome == enabled then return false end
    awesome = enabled
    wipe(plateUnits); wipe(observed); wipe(rosters)
    for _, event in ipairs({"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED"}) do
        if awesome then driver:RegisterEvent(event) else driver:UnregisterEvent(event) end
    end
    return true
end

function Classes:Resolve(name, unit)
    if not active or leavingWorld or not name then return end
    if unit and UnitExists(unit) and SameName(name, UnitName(unit)) then
        local class = UnitPlayerClass(unit)
        if class then
            if not UseAwesome() and (unit == "target" or unit == "mouseover" or unit == "focus") then AddUnit(observed, unit) end
            return class
        end
    end
    if UseAwesome() then return end
    for _, current in ipairs(currentUnits) do
        if UnitExists(current) and SameName(name, UnitName(current)) then
            local class = AddUnit(observed, current)
            if class then return class end
        end
    end
    local key = name:lower()
    local roster, seen = rosters[key], observed[key]
    if roster == false or seen == false or (roster and seen and roster ~= seen) then return end
    return roster or seen
end

function Classes:ResolvePlate(plate, name, legacyUnit)
    if UseAwesome() then
        return self:Resolve(name, self:GetPlateUnit(plate))
    end
    return self:Resolve(name, legacyUnit)
end

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if active and UseAwesome() then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            if plate then
                plateUnits[plate] = unit
                Classes:PreparePlate(plate)
                Notify(plate, true)
            end
        end
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        for plate, token in pairs(plateUnits) do
            if token == unit then plateUnits[plate] = nil; Notify(plate, false, true) end
        end
        for plate in pairs(preparedPlates) do
            if plate.namePlateUnitToken == unit then Notify(plate, false, true) end
        end
        return
    end
    if event == "PLAYER_LEAVING_WORLD" then
        leavingWorld = true
        wipe(observed); wipe(rosters); wipe(plateUnits); scoreElapsed = 0
        Notify()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then leavingWorld = false end
    if zoneEvents[event] then
        wipe(observed); scoreElapsed = 0; RefreshRosters()
    elseif rosterEvents[event] then
        RefreshRosters()
    elseif observationEvents[event] and not awesome then
        AddUnit(observed, observationEvents[event])
    end
    Notify()
    if event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_GUILD_UPDATE" and unit == "player") then RequestRosters() end
end)

driver:SetScript("OnUpdate", function(_, delta)
    if leavingWorld then return end
    if SyncAwesome() then
        RefreshRosters(); RequestRosters(); Notify()
    end
    if not awesome and InBattleground() and RequestBattlefieldScoreData then
        scoreElapsed = scoreElapsed + delta
        if scoreElapsed >= 10 then scoreElapsed = 0; RequestBattlefieldScoreData() end
    else
        scoreElapsed = 0
    end
end)

function Classes:SetEnabled(enabled)
    enabled = enabled and true or false
    if active == enabled then
        if SyncAwesome() then RefreshRosters(); RequestRosters(); Notify() end
        return
    end
    active = enabled
    if not enabled then
        driver:UnregisterAllEvents(); driver:Hide()
        awesome = false
        wipe(observed); wipe(rosters); wipe(plateUnits); scoreElapsed = 0
        return
    end
    leavingWorld = false
    SyncAwesome()
    for event in pairs(zoneEvents) do driver:RegisterEvent(event) end
    for event in pairs(rosterEvents) do driver:RegisterEvent(event) end
    for event in pairs(observationEvents) do driver:RegisterEvent(event) end
    driver:RegisterEvent("PLAYER_LEAVING_WORLD")
    RefreshRosters()
    if not awesome then for _, unit in ipairs(currentUnits) do AddUnit(observed, unit) end end
    driver:Show(); RequestRosters()
end
