-- Shared pet catalogue, identity and display policy for Classic and ElvUI.
local Pets = {}
SarychUI.NameplatePets = Pets
local lib = LibStub("LibNameplates-1.0", true)

local pets = {
    shadowfiend = {key = "u1", spell = 34433, npc = 19668,
        icon = "Spell_Shadow_Shadowfiend", names = {"Shadowfiend", "Исчадие Тьмы", "Исчадие тьмы"}},
    wolves = {key = "sarychWolves", spell = 51533, npc = 29264,
        icon = "Spell_Shaman_FeralSpirit", names = {"Spirit Wolf", "Дух волка"}},
    gargoyle = {key = "sarychGargoyle", spell = 49206, npc = 27829,
        icon = "Ability_Hunter_Pet_Bat", names = {"Ebon Gargoyle", "Черная горгулья", "Чёрная горгулья"}},
    ghoul = {key = "sarychGhoul", spell = 46584, npc = 26125, npcs = {59150}, family = 40,
        icon = "Spell_Shadow_AnimateDead", names = {}},
    armyofthedead = {key = "sarychArmyOfTheDead", spell = 42650, npc = 24207,
        icon = "Spell_DeathKnight_ArmyOfTheDead", names = {"Army of the Dead Ghoul", "Вурдалак из войска мертвых", "Вурдалак из войска мёртвых"}},
    hunterpet = {key = "sarychHunterPet", spell = 883,
        icon = "Ability_Hunter_BeastCall", names = {}},
    imp = {key = "sarychImp", spell = 688, npc = 60465, family = 23,
        icon = "Spell_Shadow_SummonImp", names = {}},
    voidwalker = {key = "sarychVoidwalker", spell = 67, npc = 64507, family = 16,
        icon = "Spell_Shadow_SummonVoidWalker", names = {}},
    succubus = {key = "sarychSuccubus", spell = 712, npc = 1863, npcs = {64509}, family = 17,
        icon = "Spell_Shadow_SummonSuccubus", names = {}},
    felhunter = {key = "sarychFelhunter", spell = 691, npc = 417, npcs = {64508}, family = 15,
        icon = "Spell_Shadow_SummonFelhunter", names = {}},
    felguard = {key = "sarychFelguard", spell = 30146, npc = 64510, family = 29,
        icon = "Spell_Shadow_SummonFelGuard", names = {}},
    snakes = {key = "sarychSnakes", spell = 34600, npc = 19833, npcs = {19921},
        icon = "Ability_Hunter_SnakeTrap", names = {"Venomous Snake", "Viper", "Ядовитая змея", "Гадюка"}},
    mirrorimage = {key = "sarychMirrorImage", spell = 55342, npc = 31216,
        icon = "Spell_Magic_LesserInvisibilty", names = {"Mirror Image", "Зеркальное изображение"}},
    waterelemental = {key = "sarychWaterElemental", spell = 31687, npc = 510, npcs = {37994},
        icon = "Spell_Frost_SummonWaterElemental_2", names = {"Water Elemental", "Элементаль воды"}},
    treants = {key = "sarychTreants", spell = 33831, npc = 1964,
        icon = "Ability_Druid_ForceofNature", names = {"Treant", "Древень"}},
}
Pets.Entries = pets
Pets.Order = {"shadowfiend", "wolves", "gargoyle", "ghoul", "armyofthedead", "hunterpet", "imp", "voidwalker", "succubus", "felhunter", "felguard",
    "snakes", "mirrorimage", "waterelemental", "treants"}

function Pets:GetMode()
    local db = SarychUI:GetModuleProfile("health_indicators")
    return db and (db.petDisplay or (db.petIcons and "icons")) or "plates"
end
local byNPC, bySpell, byName, byFamily = {}, {}, {}, {}
local identities = {}
local TTL = 600
local confirmedPlates = setmetatable({}, {__mode="k"})
local inferredImages = setmetatable({}, {__mode="k"})
local identityHooks = setmetatable({}, {__mode="k"})
local awesomeUnits = setmetatable({}, {__mode="k"})

local function UseAwesome()
    local compat = SarychUI.Compatibility
    return compat and compat:IsAwesomeWotlkEnabled() or false
end

local function TrackLifetime(root)
    if not identityHooks[root] then
        identityHooks[root] = true
        root:HookScript("OnHide", function()
            confirmedPlates[root], inferredImages[root], awesomeUnits[root] = nil, nil, nil
        end)
    end
end

local function ConfirmPet(root, kind, name, guid)
    local previous = confirmedPlates[root]
    if not previous or previous.name ~= name or previous.guid ~= guid or previous.kind ~= kind then
        confirmedPlates[root] = {kind=kind, name=name, guid=guid}
    end
    TrackLifetime(root)
    return kind
end


for kind, pet in pairs(pets) do
    if pet.npc then byNPC[pet.npc] = kind end
    for _, id in ipairs(pet.npcs or {}) do byNPC[id] = kind end
    if pet.spell then bySpell[pet.spell] = kind end
    if pet.family then
        byFamily[pet.family] = kind
        if GetPetFamilyInfo then
            local family = GetPetFamilyInfo(pet.family)
            if family then byFamily[family] = kind end
        end
    end
    for _, name in ipairs(pet.names) do byName[name] = kind end
end
byFamily.Succubus, byFamily["Суккуб"] = "succubus", "succubus"
-- Combat log uses the triggered summon, not always the spell on the action bar.
for spell, kind in pairs({[42651]="armyofthedead", [57879]="snakes", [46585]="ghoul",
    [58831]="mirrorimage", [58833]="mirrorimage", [58834]="mirrorimage",
    [70907]="waterelemental", [70908]="waterelemental"}) do bySpell[spell] = kind end
byFamily.Felhunter, byFamily["Охотник Скверны"] = "felhunter", "felhunter"
-- Named demons may have a pet-specific GUID and already exist at login,
-- before any summon event can be observed. Resolve their unit family too.
byFamily.Imp, byFamily["Бес"] = "imp", "imp"
byFamily.Voidwalker, byFamily["Демон Бездны"], byFamily["Демон бездны"] = "voidwalker", "voidwalker", "voidwalker"
byFamily.Felguard, byFamily["Страж Скверны"], byFamily["Страж скверны"] = "felguard", "felguard", "felguard"
byFamily.Ghoul, byFamily["Вурдалак"] = "ghoul", "ghoul"

-- CreatureFamily.dbc IDs (https://www.azerothcore.org/eluna/Creature/GetCreatureFamily.html).
-- Keep hunter families separate: wild creatures have the same families, so
-- these matches require a pet GUID rather than an ordinary creature GUID.
local hunterFamilies = {}
for _, family in ipairs({
    {1,"Wolf","Волк"}, {2,"Cat","Кошка"}, {3,"Spider","Паук"},
    {4,"Bear","Медведь"}, {5,"Boar","Кабан"}, {6,"Crocolisk","Кроколиск"},
    {7,"Carrion Bird","Падальщик"}, {8,"Crab","Краб"}, {9,"Gorilla","Горилла"},
    {11,"Raptor","Ящер"}, {12,"Tallstrider","Долгоног"}, {20,"Scorpid","Скорпид"},
    {21,"Turtle","Черепаха"}, {24,"Bat","Летучая мышь"}, {25,"Hyena","Гиена"},
    {26,"Bird of Prey","Хищная птица"}, {27,"Wind Serpent","Крылатый змей"},
    {30,"Dragonhawk","Дракондор"}, {31,"Ravager","Опустошитель"},
    {32,"Warp Stalker","Прыгуана"}, {33,"Sporebat","Спороскат"},
    {34,"Nether Ray","Скат Пустоты"}, {35,"Serpent","Змей"},
    {37,"Moth","Мотылек","Мотылёк"}, {38,"Chimaera","Химера"},
    {39,"Devilsaur","Дьявозавр"}, {41,"Silithid","Силитид"}, {42,"Worm","Червь"},
    {43,"Rhino","Люторог"}, {44,"Wasp","Оса"},
    {45,"Core Hound","Гончая недр","Гончая Недр"}, {46,"Spirit Beast","Дух зверя"},
}) do
    for _, value in ipairs(family) do hunterFamilies[value] = true end
    local localized = GetPetFamilyInfo and GetPetFamilyInfo(family[1])
    if localized then hunterFamilies[localized] = true end
end

local function KindFromGUID(guid)
    return byNPC[SarychUI.NameplateIdentity:GetCreatureID(guid)]
end

local function Remember(guid, name, kind)
    if not guid or not name or not kind or not SarychUI.NameplateIdentity:GetCreatureID(guid) then return end
    local observed = identities[guid]
    if not observed then observed = {}; identities[guid] = observed end
    observed.name, observed.kind, observed.time = name, kind, GetTime()
end

local function OwnerClassForPetUnit(unit)
    if unit == "pet" then return select(2, UnitClass("player")) end
    local index=type(unit)=="string" and (string.match(unit,"^arenapet(%d+)$") or string.match(unit,"^arena(%d+)pet$"))
    local owner=index and ("arena"..index)
    if not owner then
        index=type(unit)=="string" and (string.match(unit,"^partypet(%d+)$") or string.match(unit,"^party(%d+)pet$"))
        owner=index and ("party"..index)
    end
    if not owner then
        index = type(unit) == "string" and unit:match("^raidpet(%d+)$")
        owner = index and ("raid" .. index)
    end
    if owner and UnitClass then return select(2,UnitClass(owner)) end
end

local function LearnUnit(unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local guid, name = UnitGUID(unit), UnitName(unit)
    local kind = KindFromGUID(guid)
    if not kind and UnitCreatureFamily then
        local family = UnitCreatureFamily(unit)
        kind = byFamily[family]
        -- Named DK pets have pet-specific GUID entries. Their family identifies
        -- them without knowing the owner; wild undead must not match this path.
        if kind == "ghoul" and not SarychUI.NameplateIdentity:IsPetGUID(guid) then kind = nil end
        if not kind and hunterFamilies[family] and SarychUI.NameplateIdentity:IsPetGUID(guid) then
            kind = "hunterpet"
        end
    end
    if not kind then
        local ownerClass=OwnerClassForPetUnit(unit)
        if ownerClass=="DEATHKNIGHT" then kind="ghoul"
        elseif ownerClass=="HUNTER" then kind="hunterpet"
        elseif ownerClass=="MAGE" then kind="waterelemental" end
    end
    Remember(guid, name, kind)
    return kind
end

local function Root(plate)
    return lib.realPlate[plate] or plate
end

local function DirectUnit(root)
    if not UseAwesome() then return end
    local unit = awesomeUnits[root]
    if unit and UnitExists(unit) and C_NamePlate.GetNamePlateForUnit(unit) == root then return unit end
    awesomeUnits[root] = nil
    unit = root.namePlateUnitToken
    if unit and UnitExists(unit) and C_NamePlate.GetNamePlateForUnit(unit) == root then return unit end
    unit = root.UnitFrame and root.UnitFrame.unit
    if unit and UnitExists(unit) and C_NamePlate.GetNamePlateForUnit(unit) == root then return unit end
end

local function PlateName(root)
    if root.UnitFrame then return root.UnitFrame.UnitName end
    -- Native regions are already available when the scale layer creates its
    -- wrapper, even if LibNameplates has not indexed this root yet.
    local fs = lib.GetNameRegion and lib:GetNameRegion(root)
    local name = fs and fs.GetText and fs:GetText()
    if not name and lib.plateRegions[root] then name = lib:GetName(root) end
    if name then
        name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if name ~= "" then return name end
    end
end

local function Resolve(plate)
    local root = Root(plate)
    local identity = root.UnitFrame
    local directUnit = DirectUnit(root)
    local name = directUnit and UnitName(directUnit) or PlateName(root)
    if name == "" then name = nil end
    local guid = directUnit and UnitGUID(directUnit) or (identity and identity.guid) or lib:GetGUID(root)
    if name and inferredImages[root] ~= name then inferredImages[root] = nil end
    if inferredImages[root] then
        -- Legacy categories come from health-bar colour and may change while
        -- an image is still visible. ElvUI can then guess its owner's GUID by
        -- their shared name. Neither is new evidence about this particular copy.
        -- Only a plate-bound unit/library GUID can revoke the inference before
        -- native OnHide or a name change. Never use this to infer a new image.
        local verifiedUnit = directUnit
        if not verifiedUnit then
            if lib.IsTarget and lib:IsTarget(root) then verifiedUnit = "target"
            elseif lib.IsMouseover and lib:IsMouseover(root) then verifiedUnit = "mouseover" end
            if verifiedUnit and (not UnitExists(verifiedUnit)
                or (name and UnitName(verifiedUnit) ~= name)) then verifiedUnit = nil end
        end
        local verifiedGUID = verifiedUnit and UnitGUID(verifiedUnit) or lib:GetGUID(root)
        if verifiedUnit and UnitIsPlayer(verifiedUnit) then
            inferredImages[root] = nil
            return
        end
        if not verifiedGUID then return "mirrorimage" end
        inferredImages[root] = nil
        guid = verifiedGUID
    end
    local known = confirmedPlates[root]
    if known and ((name and known.name ~= name) or (directUnit and guid and known.guid ~= guid)) then
        confirmedPlates[root] = nil
        known = nil
    end
    -- The creature entry is stronger evidence than class-coloured player/NPC
    -- categories. This rule applies equally to every supported summon.
    local kind = KindFromGUID(guid)
    if kind then
        name = name or (known and known.name)
        Remember(guid, name, kind)
        return ConfirmPet(root, kind, name, guid)
    end
    if known and not directUnit then return known.kind end
    local unit = directUnit or root.namePlateUnitToken or (identity and identity.unit)
    if unit and UnitExists(unit) and (not guid or UnitGUID(unit) == guid)
        and (directUnit or UnitName(unit) == name) then
        if UnitIsPlayer(unit) then confirmedPlates[root] = nil; inferredImages[root] = nil; return end
        kind = LearnUnit(unit)
        if kind then return ConfirmPet(root, kind, UnitName(unit), UnitGUID(unit)) end
    end
    if not name then return known and known.kind end
    if guid then
        local observed = identities[guid]
        if observed and GetTime() - observed.time <= TTL then
            return ConfirmPet(root, observed.kind, name, guid)
        end
        return
    end
    -- Name-only fallback is intentionally weaker and never locks a player
    -- category to a summon. It does not overwrite a confirmed creature identity.
    if identity then
        if identity.UnitType ~= "ENEMY_NPC" and identity.UnitType ~= "FRIENDLY_NPC" then inferredImages[root] = nil; return end
    elseif not lib.plateRegions[root] or lib:GetType(root) ~= "NPC" then inferredImages[root] = nil; return end
    if byName[name] then return byName[name] end
    local found
    for _, observed in pairs(identities) do
        -- A wolf/ravager's name alone cannot distinguish a hunter pet from a
        -- wild beast. Hunter pets need their GUID or a verified unit binding.
        if observed.kind ~= "hunterpet" and observed.name == name and GetTime() - observed.time <= TTL then
            if found and found ~= observed.kind then return end
            found = observed.kind
        end
    end
    if found == "mirrorimage" then
        inferredImages[root] = name
        TrackLifetime(root)
    end
    return found
end

function Pets:ForgetPlate(root)
    confirmedPlates[root], awesomeUnits[root] = nil, nil
    inferredImages[root] = nil
end

local trackedUnits = {"target", "mouseover", "focus", "pet"}
function Pets:LearnTrackedUnits()
    for _, unit in ipairs(trackedUnits) do
        LearnUnit(unit)
        if UseAwesome() and UnitExists(unit) then
            local root = C_NamePlate.GetNamePlateForUnit(unit)
            -- Keep a stable nameplate token learned from ADDED over target.
            if root and not awesomeUnits[root] then awesomeUnits[root] = unit end
        end
    end
end

function Pets:LearnVisibleUnits()
    self:LearnTrackedUnits()
    for i = 1, 5 do LearnUnit("arenapet" .. i) end
    for i = 1, 4 do LearnUnit("partypet" .. i) end
    for i = 1, 40 do LearnUnit("raidpet" .. i) end
end


function Pets:GetAction(root)
    local db = SarychUI:GetModuleProfile("health_indicators")
    if not db or db.enabled == false then return end
    local kind = Resolve(root)
    if not kind then return end
    if db.petEnabled and db.petEnabled[kind] == false then
        local fallback = db.petFallback and db.petFallback[kind]
        return self:GetMode() == "icons" and fallback == "plates" and "plates" or "hide", nil, kind
    end
    local mode = self:GetMode()
    if mode == "icons" and db.petPlateOnTarget and UnitExists("target") then
        -- Match the actual plate, never the name shared by a mage and its copies.
        local plate = Root(root)
        local targeted
        if UseAwesome() then targeted = C_NamePlate.GetNamePlateForUnit("target") == plate
        else targeted = lib.IsTarget and lib:IsTarget(plate) end
        if targeted then return "plates", nil, kind end
    end
    return mode, mode == "icons" and ("Interface\\Icons\\" .. pets[kind].icon) or nil, kind
end

function Pets:ShowCastBar(action)
    local db = SarychUI:GetModuleProfile("health_indicators")
    return action == "icons" and db and db.enabled ~= false and db.petIconCastBars == true or false
end

function Pets:UseAwesome() return UseAwesome() end
function Pets:Resolve(root) return Resolve(root) end
function Pets:GetLifetimeIdentity(plate)
    local root = Root(plate)
    local kind = Resolve(root)
    if not kind then return end
    local unit = DirectUnit(root)
    -- A timer needs a unit/library binding to this particular creature. The
    -- icon's name-based inference and ElvUI's guessed GUID are insufficient.
    local guid = unit and UnitGUID(unit) or lib:GetGUID(root)
    return kind, guid
end
function Pets:IterateBoundPlates() return pairs(awesomeUnits) end
function Pets:BindUnit(unit)
    if not UseAwesome() then return end
    local root = C_NamePlate.GetNamePlateForUnit(unit)
    if root then
        -- A new binding starts a new lifetime, even if the frame never hid
        -- between REMOVED and ADDED (or the token string was reused).
        if awesomeUnits[root] ~= unit then self:ForgetPlate(root) end
        awesomeUnits[root] = unit
    end
    return root
end
function Pets:RemoveUnit(unit)
    local removed = {}
    for root, token in pairs(awesomeUnits) do
        if token == unit then
            -- REMOVED can precede the native frame's OnHide. Keep its verified
            -- visual identity through that final visible frame; OnHide or a new
            -- BindUnit clears it. Never restore a health bar during fade-out.
            awesomeUnits[root] = nil
            removed[#removed+1] = root
        end
    end
    return removed
end
function Pets:ObserveCombat(...)
    local _, event, sourceGUID, sourceName, _, destGUID, destName, _, spellID = ...
    local lifetimes = SarychUI.NameplatePetLifetimes
    if event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
        if destGUID then identities[destGUID] = nil end
        return lifetimes and lifetimes:Observe(event, destGUID)
    end
    local sourceKind = KindFromGUID(sourceGUID)
    local destKind = KindFromGUID(destGUID) or (event == "SPELL_SUMMON" and bySpell[spellID])
    local sourceNew = sourceKind and not identities[sourceGUID]
    local destNew = destKind and not identities[destGUID]
    Remember(sourceGUID, sourceName, sourceKind)
    Remember(destGUID, destName, destKind)
    local timerChanged = lifetimes and lifetimes:Observe(event, destGUID, destKind, spellID, sourceGUID)
    return sourceNew or destNew or timerChanged
end
function Pets:Prune()
    if SarychUI.NameplatePetLifetimes then SarychUI.NameplatePetLifetimes:Prune() end
    local now = GetTime()
    for guid, entry in pairs(identities) do
        if now - entry.time > TTL then identities[guid] = nil end
    end
end
function Pets:Reset(clearBindings)
    if SarychUI.NameplatePetLifetimes then SarychUI.NameplatePetLifetimes:Reset() end
    wipe(identities); wipe(confirmedPlates); wipe(inferredImages)
    if clearBindings then wipe(awesomeUnits) end
end
function Pets:SyncCompatibility()
    if not UseAwesome() then wipe(awesomeUnits) end
end

-- On-demand diagnostics only: no logging or allocations in the normal repaint.
function Pets:Describe(plate)
    local root = Root(plate)
    local frame = root.UnitFrame
    local unit = DirectUnit(root)
    local name = unit and UnitName(unit) or (frame and frame.UnitName)
        or (lib.plateRegions[root] and lib:GetName(root))
    local libraryGUID = frame and frame.guid or lib:GetGUID(root)
    local guid = unit and UnitGUID(unit) or libraryGUID
    local action, _, kind = self:GetAction(root)
    return string.format("name=%s unit=%s guid=%s npc=%s libGUID=%s type=%s kind=%s action=%s",
        tostring(name), tostring(unit), tostring(guid), tostring((SarychUI.NameplateIdentity:GetCreatureID(guid))),
        tostring(libraryGUID), tostring(frame and frame.UnitType or (lib.plateRegions[root] and lib:GetType(root))),
        tostring(kind), tostring(action))
end
