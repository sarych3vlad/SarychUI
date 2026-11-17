-- Summon lifetimes are separate from spell cooldowns and plate visibility.
local Lifetimes = {}
SarychUI.NameplatePetLifetimes = Lifetimes
local summons = {}
local ownGUID, ownTimer, ownDeadGUID
local lastSummon -- One diagnostic observation, never used to infer a timer.
local petInitialized, petGUID, recentPet, ownCast
local OWN_PET_WINDOW = 2
-- Spell.dbc 44557/44560/44561: Enduring Winter adds 5/10/15 seconds.
-- Eternal Water (70937) replaces the temporary summon with a permanent pet.
local elementalRule = {base=45, talents={{44557, seconds=5}},
    glyphs={{ids={70937}, permanent=true}}}

local function ElementalDuration(ownerGUID)
    local modifiers = SarychUI.SpellModifiers
    return modifiers and modifiers:Calculate(ownerGUID, elementalRule, nil, true)
end

-- WotLK Spell.dbc DurationIndex / SpellDuration.dbc (seconds).
-- https://github.com/Kaev/AzerothcoreDBCToSQL/blob/master/Spell.sql
-- Triggered summons include 42651, 57879, 58831/58833/58834 and 70907.
-- Use an observed, supported summon spell, never a duration guessed from NPC
-- kind alone. These standard durations are separate from ability cooldowns.
local summonSpells = {}
for _, rule in ipairs({
    {"shadowfiend",15,{34433}}, {"wolves",45,{51533}},
    {"armyofthedead",40,{42650,42651}},
    {"snakes",15,{34600,57879}}, {"mirrorimage",30,{55342,58831,58833,58834}},
    {"treants",30,{33831}}, {"waterelemental",45,{31687,70907}},
}) do
    for _, spell in ipairs(rule[3]) do summonSpells[spell] = rule end
end
-- 49206's DBC duration is not the gargoyle's actual server-controlled lifetime
-- (attack/flight/dismissal phases). Do not fabricate a foreign countdown from
-- that value. A real own-pet remaining-time API can still supply one below.

-- Some 3.3.5 servers omit SPELL_SUMMON for the player's controlled elemental.
-- Require BOTH a successful own cast and a newly observed pet GUID. Merely
-- seeing a pet (including after reload) must never start a database timer.
function Lifetimes:UpdateOwnPet()
    local now = GetTime()
    local guid = UnitExists("pet") and UnitGUID("pet") or nil
    if not petInitialized then
        petInitialized, petGUID = true, guid
        return
    end
    if guid ~= petGUID then
        petGUID = guid
        recentPet = guid and {guid=guid, time=now} or nil
    end
    if recentPet and now - recentPet.time > OWN_PET_WINDOW then recentPet = nil end
    if ownCast and now - ownCast.start > OWN_PET_WINDOW then ownCast = nil end
    if not ownCast or not recentPet or guid ~= recentPet.guid then return end
    -- 510 is the temporary elemental; 37994 (Eternal Water) is permanent.
    -- Unknown server entries do not receive a guessed deadline.
    if SarychUI.NameplateIdentity:GetCreatureID(guid) ~= 510
        or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet")) then return end
    if not summons[guid] then
        summons[guid] = {start=ownCast.start, duration=ownCast.duration,
            kind="waterelemental", spell=31687, source="ownCast"}
    end
    ownCast, recentPet = nil, nil
    return true
end

function Lifetimes:ObserveOwnCast(unit, spellName, _, _, spellID)
    if unit ~= "player" then return end
    -- Original clients may provide only the localized spell name.
    if spellID ~= 31687 then
        if spellID or not spellName or not GetSpellInfo or spellName ~= GetSpellInfo(31687) then return end
    end
    self:UpdateOwnPet()
    local duration = ElementalDuration(UnitGUID("player"))
    if not duration or duration <= 0 then ownCast = nil; return end
    ownCast = {start=GetTime(), duration=duration}
    return self:UpdateOwnPet()
end

function Lifetimes:Observe(event, guid, kind, spell, ownerGUID)
    if not guid then return end
    if event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
        local existed = summons[guid] ~= nil or ownGUID == guid
        summons[guid] = nil
        if recentPet and recentPet.guid == guid then recentPet, ownCast = nil, nil end
        if ownGUID == guid then ownGUID, ownTimer, ownDeadGUID = nil, nil, guid end
        return existed
    end
    if event ~= "SPELL_SUMMON" then return end
    lastSummon = {guid=guid, spell=spell, kind=kind, time=GetTime()}
    if not kind then return end
    if ownDeadGUID == guid then ownDeadGUID = nil end
    local entry = SarychUI.NameplateIdentity:GetCreatureID(guid)
    -- Eternal Water and permanent ghouls must never receive a guessed deadline.
    local rule = summonSpells[spell]
    local duration = rule and rule[1] == kind and rule[2]
    if duration and kind == "waterelemental" then duration = ElementalDuration(ownerGUID) end
    if kind == "waterelemental" and (entry == 37994 or spell == 70908) then duration = nil end
    if not duration or duration <= 0 then
        -- Missing foreign build data must not erase a confirmed own-cast clock.
        if entry == 37994 or spell == 70908 or duration == 0 then summons[guid] = nil end
        return
    end
    if summons[guid] then return end -- Duplicate notifications must not restart it.
    summons[guid] = {start=GetTime(), duration=duration, kind=kind, spell=spell, source="combatLog"}
    return true
end

function Lifetimes:GetDiagnostics(guid)
    return guid and summons[guid], lastSummon
end

function Lifetimes:GetForPlate(root)
    local kind, guid = SarychUI.NameplatePets:GetLifetimeIdentity(root)
    -- The regular DK ghoul never displays a lifetime, including native pet
    -- time. Army of the Dead is a separate, temporary summon category.
    if not kind or not guid or kind == "ghoul" then return end
    local now = GetTime()
    if guid and UnitExists("pet") and UnitGUID("pet") == guid and GetPetTimeRemaining then
        if guid == ownDeadGUID or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("pet")) then return end
        local remaining = GetPetTimeRemaining()
        if type(remaining) == "number" and remaining > 0 then
            remaining = remaining / 1000
            local expires = now + remaining
            if ownGUID ~= guid or not ownTimer then
                local observed = summons[guid]
                local start = observed and observed.start or now
                ownGUID, ownTimer = guid, {start=start, duration=expires-start}
            elseif math.abs(ownTimer.start + ownTimer.duration - expires) > .5 then
                ownTimer.duration = expires - ownTimer.start
            end
            return ownTimer
        end
        ownGUID, ownTimer = nil, nil
        -- An unavailable API is not a new start time. Only an already observed
        -- supported summon may supply a countdown below.
    end
    local timer = summons[guid]
    if timer and timer.kind == kind and timer.start + timer.duration > now then return timer end
end

function Lifetimes:Prune()
    local now = GetTime()
    for guid, timer in pairs(summons) do
        if timer.start + timer.duration <= now then summons[guid] = nil end
    end
end

function Lifetimes:Reset()
    wipe(summons)
    ownGUID, ownTimer, ownDeadGUID = nil, nil, nil
    lastSummon = nil
    petInitialized, petGUID, recentPet, ownCast = nil, nil, nil, nil
    self:UpdateOwnPet()
end
