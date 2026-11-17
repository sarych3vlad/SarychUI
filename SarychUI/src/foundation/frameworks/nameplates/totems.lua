-- Shared WotLK totem catalogue for Classic and ElvUI nameplates.
-- Spell ranks from the ElvUI filter; creature entries from player_resources/totem_data.lua.
local Totems = {Types={}, Names={}, Info={}, Entries={}, ByNPC={}}
SarychUI.NameplateTotems = Totems
local definitions = {
    {"a1", "air", {8177}, {5925}}, -- Grounding Totem
    {"a2", "air", {10595,10600,10601,25574,58746,58749}, {7467,7468,7469,15490,31173,31174}}, -- Nature Resistance Totem I
    {"a3", "air", {6495}, {3968}}, -- Sentry Totem
    {"a4", "air", {8512}, {6112}}, -- Windfury Totem
    {"a5", "air", {3738}, {15447}}, -- Wrath of Air Totem
    {"e1", "earth", {2062}, {15430}}, -- Earth Elemental Totem
    {"e2", "earth", {2484}, {2630}}, -- Earthbind Totem
    {"e3", "earth", {5730,6390,6391,6392,10427,10428,25525,58580,58581,58582}, {3579,3911,3912,3913,7398,7399,15478,31120,31121,31122}}, -- Stoneclaw Totem I
    {"e4", "earth", {8071,8154,8155,10406,10407,10408,25508,25509,58751,58753}, {5873,5919,5920,7366,7367,7368,15470,15474,31175,31176}}, -- Faction Champs
    {"e5", "earth", {8075,8160,8161,10442,25361,25528,57622,58643}, {5874,5921,5922,7403,15464,15479,30647,31129}}, -- Faction Champs
    {"e6", "earth", {8143}, {5913}}, -- Tremor Totem
    {"f1", "fire", {2894}, {15439}}, -- Fire Elemental Totem
    {"f2", "fire", {8227,8249,10526,16387,25557,58649,58652,58656}, {5950,6012,7423,10557,15485,31132,31158,31133}}, -- Faction Champs
    {"f3", "fire", {8181,10478,10479,25560,58741,58745}, {5926,7412,7413,15486,31171,31172}}, -- Frost Resistance Totem I
    {"f4", "fire", {8190,10585,10586,10587,25552,58731,58734}, {5929,7464,7465,7466,15484,31166,31167}}, -- Magma Totem I
    {"f5", "fire", {3599,6363,6364,6365,10437,10438,25533,58699,58703,58704}, {2523,3902,3903,3904,7400,7402,15480,31162,31164,31165}}, -- Faction Champs
    {"f6", "fire", {30706,57720,57721,57722}, {17539,30652,30653,30654}}, -- Totem of Wrath I
    {"w1", "water", {8170}, {5924}}, -- Cleansing Totem
    {"w2", "water", {8184,10537,10538,25563,58737,58739}, {5927,7424,7425,15487,31169,31170}}, -- Fire Resistance Totem I
    {"w3", "water", {5394,6375,6377,10462,10463,25567,58755,58756,58757}, {3527,3906,3907,3908,3909,15488,31181,31182,31185}}, -- Faction Champs
    {"w4", "water", {5675,10495,10496,10497,25570,58771,58773,58774}, {3573,7414,7415,7416,15489,31186,31189,31190}}, -- Mana Spring Totem I
    {"w5", "water", {16190}, {10467}}, -- Mana Tide Totem
    {"o1", "other", {724}, {}}, -- Lightwell
}

local ranks = {"", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X"}
-- On ruRU these creature names differ from their summoning spell names.
-- Keep the aliases used by player_resources/totem_data.lua here as well.
local creatureNames = GetLocale and GetLocale() == "ruRU" and {
    f3 = "Тотем сопротивления льду",
    w2 = "Тотем сопротивления огню",
    a2 = "Тотем сопротивления силам природы",
} or {}
for _, definition in ipairs(definitions) do
    local key, school, spells, creatures = unpack(definition)
    local entry = {key=key, school=school, spell=spells[1]}
    Totems.Entries[#Totems.Entries + 1] = entry
    Totems.Types[school] = Totems.Types[school] or {}
    for _, spell in ipairs(spells) do
        Totems.Types[school][spell] = key
        local name, rank, icon = GetSpellInfo(spell)
        if name then
            entry.name, entry.icon = entry.name or name, entry.icon or icon
            Totems.Names[name] = key
            local suffix = ranks[tonumber((rank or ""):match("%d+"))]
            if suffix then Totems.Names[name .. suffix] = key end
        end
    end
    local creatureName = creatureNames[key]
    if creatureName then
        entry.name = creatureName
        for rank = 1, #spells do Totems.Names[creatureName .. ranks[rank]] = key end
        Totems.Names[creatureName .. " I"] = key
    end
    for _, creature in ipairs(creatures) do Totems.ByNPC[creature] = key end
    Totems.Info[key] = {entry.name, school, entry.icon}
end

function Totems:Resolve(name, guid, isPlayer)
    if isPlayer then return end
    local key = self.ByNPC[SarychUI.NameplateIdentity:GetCreatureID(guid)]
    if key then return key end
    return name and self.Names[name]
end

function Totems:GetMode()
    local db = SarychUI:GetModuleProfile("health_indicators")
    return db and db.totemDisplay or (SarychUI:GetNameplateMode() == "classic" and "plates" or "icons")
end

local function HasPlateFallback(db, key)
    return db.totemEnabled and db.totemEnabled[key] == false
        and db.totemFallback and db.totemFallback[key] == "plates"
end

function Totems:ShouldHideAuras(plate, unit, guid)
    local db = SarychUI:GetModuleProfile("health_indicators")
    if not db or db.enabled == false then return false end
    if db.totemDisplay then
        if db.totemDisplay ~= "icons" then return false end
    else
        -- Legacy ElvUI filters can also replace a totem with an icon. Ordinary
        -- nameplates must keep their auras when the shared selector is unset.
        local frame = plate and plate.UnitFrame
        if not frame or not frame.IconOnlyChanged then return false end
    end
    -- Resolve the unit itself before consulting reusable plate text. The aura
    -- spell (including Grounding's 8178) must not blacklist its player recipients.
    if unit and UnitExists(unit) and (not guid or UnitGUID(unit) == guid) then
        local key = self:Resolve(UnitName(unit), guid, UnitIsPlayer(unit))
        return key ~= nil and key ~= "o1" and not HasPlateFallback(db, key)
    end
    local key = self:Resolve(nil, guid)
    if key then return key ~= "o1" and not HasPlateFallback(db, key) end
    local lib = LibStub and LibStub("LibNameplates-1.0", true)
    local text = lib and lib.GetNameRegion and lib:GetNameRegion(plate)
    local name
    if text and text.GetText then
        name = text:GetText()
    elseif plate and plate.UnitFrame then
        name = plate.UnitFrame.UnitName
    end
    if name then name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
    key = self:Resolve(name, guid)
    return key ~= nil and key ~= "o1" and not HasPlateFallback(db, key)
end

function Totems:GetAction(name, guid, isPlayer)
    local db = SarychUI:GetModuleProfile("health_indicators")
    if not db or db.enabled == false then return end
    local key = self:Resolve(name, guid, isPlayer)
    -- Lightwell remains available to legacy ElvUI filters, but is not a shaman totem.
    if not key or key == "o1" then return end
    if db.totemEnabled and db.totemEnabled[key] == false then
        return self:GetMode() == "icons" and HasPlateFallback(db, key) and "plates" or "hide", nil, key
    end
    -- Keep existing ElvUI filters until the shared display selector is configured.
    if not db.totemDisplay and SarychUI:GetNameplateMode() == "elvui" then return nil, nil, key end
    local action = self:GetMode()
    return action, self.Info[key][3], key
end
