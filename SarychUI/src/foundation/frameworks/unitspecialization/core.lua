-- Shared specialization detection for allies and arena opponents (WoW 3.3.5a).
-- Get(unit, enemy?) returns canonical spec key, class token, icon path; nil
-- spec means talents/clues are not known yet. Enemy spell clues are derived
-- from Gladius 1.2.0 (speclist.lua).
SarychUI.UnitSpecialization = SarychUI.UnitSpecialization or {}
local Spec = SarychUI.UnitSpecialization
local talentLib = LibStub and LibStub("LibGroupTalents-1.0", true)

local buffIDs = {
	WARRIOR = { Arms = {56638,64976,29842,52437}, Fury = {29801,46916}, Protection = {50227,50720,46947} },
	PALADIN = { Retribution = {20053,59578,54203}, Holy = {31834,53563,54153,53659}, Protection = {20132} },
	ROGUE = { Assassination = {58427,52910}, Subtlety = {36554,51713,31223,45182} },
	PRIEST = { Holy = {47788,48085,63725,33143,65081,63734}, Discipline = {52800,45242,63944,47753,47930}, Shadow = {15473,15286} },
	DEATHKNIGHT = { Unholy = {49222,66803}, Blood = {49016,53138}, Frost = {55610,50485} },
	MAGE = { Frost = {43039,74396,57761}, Fire = {28682,48108,54741}, Arcane = {31583,44401,44413} },
	WARLOCK = { Destruction = {30302,63244,54277}, Affliction = {64371}, Demonology = {63167} },
	SHAMAN = { Elemental = {57663,65264,51470}, Restoration = {49284,53390,31616}, Enhancement = {30809,53817} },
	HUNTER = { BeastMastery = {20895,53257}, Marksmanship = {19506,53220}, Survival = {34501,34837,64420} },
	DRUID = { Feral = {24932}, Restoration = {34123,53251,45283,48504}, Balance = {24907,24858,48391,48517} },
}

local spellIDs = {
	WARRIOR = { Arms = {47486,46924}, Fury = {23881,60970}, Protection = {12809,47498,46968} },
	PALADIN = { Protection = {48827,53595,48952}, Holy = {48825,31842,53563}, Retribution = {35395,53385,20066} },
	ROGUE = { Assassination = {48666,51662}, Combat = {51690,13877,13750}, Subtlety = {36554,51713,48660,14183} },
	PRIEST = { Discipline = {53007,10060,33206}, Holy = {47788,34861,48087}, Shadow = {15473,15286,15487,48160,64044,47585} },
	DEATHKNIGHT = { Blood = {55262,49028,49016,55233}, Frost = {49203,55268,51411,51271}, Unholy = {49222,55271,51052,63560,49206} },
	MAGE = { Arcane = {44781,31589,12042}, Fire = {55360,42950,42945,11129}, Frost = {43039,44572,31687} },
	WARLOCK = { Affliction = {59164,47843,59092}, Demonology = {59672,30146,47193}, Destruction = {59172,47847,17962} },
	SHAMAN = { Elemental = {59159,16166,52179}, Enhancement = {51533,30823,17364,60103}, Restoration = {49284,61301,51886,16190} },
	HUNTER = { BeastMastery = {19577,19574}, Marksmanship = {34490,53209}, Survival = {60053,49012,63672} },
	DRUID = { Balance = {53201,61384,33831}, Feral = {48566,48564,50334}, Restoration = {18562} },
}

local specOrder = {
	WARRIOR = { "Arms", "Fury", "Protection" },
	PALADIN = { "Holy", "Protection", "Retribution" },
	ROGUE = { "Assassination", "Combat", "Subtlety" },
	PRIEST = { "Discipline", "Holy", "Shadow" },
	DEATHKNIGHT = { "Blood", "Frost", "Unholy" },
	MAGE = { "Arcane", "Fire", "Frost" },
	WARLOCK = { "Affliction", "Demonology", "Destruction" },
	SHAMAN = { "Elemental", "Enhancement", "Restoration" },
	HUNTER = { "BeastMastery", "Marksmanship", "Survival" },
	DRUID = { "Balance", "Feral", "Restoration" },
}

-- Gladius' spec badge textures. Talented's tab icon is used when populated.
local specIcons = {
	WARRIOR = { Arms = "Ability_warrior_savageblow", Fury = "Ability_warrior_innerrage", Protection = "Ability_warrior_defensivestance" },
	PALADIN = { Holy = "Spell_holy_holybolt", Protection = "Spell_holy_devotionaura", Retribution = "Spell_holy_auraoflight" },
	ROGUE = { Assassination = "Ability_rogue_shadowstrikes", Combat = "Ability_backstab", Subtlety = "Ability_stealth" },
	PRIEST = { Discipline = "Spell_holy_wordfortitude", Holy = "Spell_holy_holybolt", Shadow = "Spell_shadow_shadowwordpain" },
	DEATHKNIGHT = { Blood = "Spell_deathknight_bloodpresence", Frost = "Spell_deathknight_frostpresence", Unholy = "Spell_deathknight_unholypresence" },
	MAGE = { Arcane = "Spell_holy_magicalsentry", Fire = "Spell_fire_firebolt02", Frost = "Spell_frost_frostbolt02" },
	WARLOCK = { Affliction = "Spell_shadow_deathcoil", Demonology = "Spell_shadow_metamorphosis", Destruction = "Spell_shadow_rainoffire" },
	SHAMAN = { Elemental = "Spell_nature_lightning", Enhancement = "Spell_nature_lightningshield", Restoration = "Spell_nature_magicimmunity" },
	HUNTER = { BeastMastery = "Ability_hunter_beasttaming", Marksmanship = "Ability_marksmanship", Survival = "Ability_hunter_swiftstrike" },
	DRUID = { Balance = "Spell_nature_starfall", Feral = "Ability_druid_catform", Restoration = "Spell_nature_healingtouch" },
}

function Spec:GetIcon(class, spec)
	local order = specOrder[class]
	local talented = _G.Talented
	if order and talented and talented.tabdata and talented.tabdata[class] then
		for index, name in ipairs(order) do
			if name == spec then
				local tab = talented.tabdata[class][index]
				if tab and tab.icon then return tab.icon end
				break
			end
		end
	end
	local name = specIcons[class] and specIcons[class][spec]
	return name and ("Interface\\Icons\\" .. name)
end

function Spec:GetTestArenaSpec(index)
	if index == 1 then
		local _, class = UnitClass("player")
		-- The first test opponent shows the state before a specialization is detected.
		return nil, class
	end
	local samples = {
		[2] = { "PRIEST", "Discipline" }, [3] = { "MAGE", "Frost" },
		[4] = { "ROGUE", "Subtlety" }, [5] = { "SHAMAN", "Restoration" },
	}
	local sample = samples[index]
	return sample and sample[2], sample and sample[1]
end

local function BuildNames(source)
	local result = {}
	for class, specs in pairs(source) do
		local names = {}
		for spec, ids in pairs(specs) do
			for _, id in ipairs(ids) do
				local name = GetSpellInfo(id)
				if name then names[name] = spec end
			end
		end
		result[class] = names
	end
	return result
end

local buffNames, spellNames
local known = {}
local notesKnown = {}
local castClues = SarychUI.Data.EnemyAbilities and SarychUI.Data.EnemyAbilities.CastClues
local detector = CreateFrame("Frame")
local detectionActive = false

local function ArenaUnit(guid)
	if not guid then return end
	for i = 1, (MAX_ARENA_ENEMIES or 5) do
		local unit = "arena" .. i
		if UnitGUID(unit) == guid then return unit end
	end
end

local function Detect(unit, name, kind, spellID)
	if not unit or not UnitExists(unit) then return end
	local guid = UnitGUID(unit)
	if not guid then return end
	local _, class = UnitClass(unit)
	local names = kind == "buff" and buffNames or spellNames
	local clue = kind == "spell" and spellID and castClues and castClues[spellID]
	local spec = clue and clue.class == class and clue.spec
		or (name and names and names[class] and names[class][name])
	if spec then
		local priority = kind == "spell" and 2 or 1
		local previous = known[guid]
		if not previous or priority >= previous.priority then
			known[guid] = { spec = spec, priority = priority }
		end
	end
end

local function ScanAuras(unit)
	if not UnitExists(unit) then return end
	for index = 1, 40 do
		local name, _, _, _, _, _, _, caster = UnitAura(unit, index, "HELPFUL")
		if not name then break end
		if caster and caster:match("^arena%d+$") then
			Detect(caster, name, "buff")
		end
	end
end

function Spec:GetEnemySpec(unit)
	local guid = unit and UnitGUID(unit)
	if not guid then return nil end
	if known[guid] then return known[guid].spec end
	local api = _G.ArenaNotesAPI
	local hint = api and api.ready and api.GetSpec and api:GetSpec(unit)
	if type(hint) == "table" and (not hint.guid or hint.guid == guid) then
		local _, class = UnitClass(unit)
		if class and (not hint.classToken or hint.classToken == class) then
			local spec = hint.specKey
			if type(spec) == "string" then
				spec = spec:gsub("^" .. class .. "_", "")
				for _, name in ipairs(specOrder[class] or {}) do
					if name == spec or name:upper() == spec:upper() then
						notesKnown[guid] = name
						break
					end
				end
			end
		end
	end
	return notesKnown[guid]
end

function Spec:GetEnemySpecByGUID(guid)
	local entry = guid and known[guid]
	return entry and entry.spec
end

function Spec:ObserveEnemyCast(guid, spellID, spellName)
	local unit = ArenaUnit(guid)
	if unit then Detect(unit, spellName, "spell", spellID) end
end

local function TreeIndex(class, name)
	local order = specOrder[class]
	if not order or not name then return nil end
	if type(name) == "number" then return order[name] and name end
	for index, english in ipairs(order) do
		if english == name then return index end
	end
	if talentLib and talentLib.GetTreeNames then
		local first, second, third = talentLib:GetTreeNames(class)
		local localized = { first, second, third }
		for index = 1, 3 do
			if localized[index] == name then return index end
		end
	end
end

-- Friendly target/focus may be outside LibGroupTalents' group roster.
-- Use the shared LibTalentQuery queue and its validated results for those units.
local inspectLib = LibStub and LibStub("LibTalentQuery-1.0", true)
local inspected, requested = {}, {}
local function ReadTalentSpec(class, inspect)
    local order = specOrder[class]
    if not order or not GetTalentTabInfo then return nil end
    local group = GetActiveTalentGroup and GetActiveTalentGroup(inspect) or 1
    local best, points = nil, 0
    for index = 1, 3 do
        local _, _, spent = GetTalentTabInfo(index, inspect, nil, group)
        spent = tonumber(spent) or 0
        if spent > points then best, points = index, spent end
    end
    return best and order[best]
end

if inspectLib and inspectLib.RegisterCallback then
    local function Ready(_, name, realm, unit)
        local guid = unit and UnitGUID(unit)
        if not guid or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player")
            or (inspectLib.lastInspectGUID and inspectLib.lastInspectGUID ~= guid) then return end
        local _, class = UnitClass(unit)
        local spec = ReadTalentSpec(class, true)
        if spec then inspected[guid] = {class = class, spec = spec, time = GetTime()} end
        requested[guid] = nil
    end
    inspectLib.RegisterCallback(Spec, "TalentQuery_Ready", Ready)
    inspectLib.RegisterCallback(Spec, "TalentQuery_Ready_Outsider", Ready)
end

function Spec:GetAllySpec(unit)
	if not unit or not UnitExists(unit) then return nil end
	local _, class = UnitClass(unit)
	local order = specOrder[class]
	if not order then return nil end
    if UnitIsUnit(unit, "player") then return ReadTalentSpec(class, false) end
    local name, first, second, third
    if talentLib and talentLib.GetUnitTalentSpec then
        name, first, second, third = talentLib:GetUnitTalentSpec(unit)
    end
    first, second, third = tonumber(first) or 0, tonumber(second) or 0, tonumber(third) or 0
    if first + second + third == 0 then
        local entry = inspected[UnitGUID(unit)]
        return entry and entry.class == class and GetTime() - entry.time < 900 and entry.spec or nil
    end
	local index = TreeIndex(class, name)
	if not index then
		index = 1
		if second > first and second > third then index = 2
		elseif third > first and third > second then index = 3 end
	end
	return index and order[index]
end

function Spec:Get(unit, enemy)
	if not unit then return nil end
	if enemy == nil then
		enemy = (type(unit) == "string" and unit:match("^arena%d+$") ~= nil)
			or (UnitCanAttack and UnitCanAttack("player", unit))
	end
	local spec
	if enemy then spec = self:GetEnemySpec(unit)
	else spec = self:GetAllySpec(unit) end
	local _, class = UnitClass(unit)
	return spec, class, spec and self:GetIcon(class, spec)
end

function Spec:RequestUnit(unit)
    if not inspectLib or not unit or not UnitExists(unit) or not UnitIsPlayer(unit)
        or UnitIsUnit(unit, "player") or UnitCanAttack("player", unit)
        or not UnitIsVisible(unit) or not UnitIsConnected(unit)
        or not CanInspect(unit) or (UnitLevel(unit) or 0) < 10
        or self:GetAllySpec(unit) then return end
    local guid, now = UnitGUID(unit), GetTime()
    if not guid or (requested[guid] and now - requested[guid] < 5) then return end
    requested[guid] = now
    inspectLib:Query(unit)
end

function Spec:RequestAllyTalents(guid)
	return guid and talentLib and talentLib.GetGUIDTalents
		and talentLib:GetGUIDTalents(guid) or nil
end

function Spec:HasTalent(unit, guid, spellID, tab, index)
	if not guid or not talentLib or not talentLib.GetGUIDTalents
		or not talentLib:GetGUIDTalents(guid) then return nil end
	if tab and index and talentLib.GetTalentInfo then
		local _, _, _, _, spent = talentLib:GetTalentInfo(unit, tab, index)
		if spent ~= nil then return (tonumber(spent) or 0) > 0 end
	end
	local name = spellID and GetSpellInfo(spellID)
	if name and talentLib.GUIDHasTalent then
		return talentLib:GUIDHasTalent(guid, name) ~= nil
	end
	return nil
end

function Spec:StartEnemyDetection()
	if detectionActive then return end
	detectionActive = true
	if not buffNames then buffNames = BuildNames(buffIDs) end
	if not spellNames then spellNames = BuildNames(spellIDs) end
	detector:RegisterEvent("PLAYER_ENTERING_WORLD")
	detector:RegisterEvent("ARENA_OPPONENT_UPDATE")
	detector:RegisterEvent("UNIT_AURA")
	detector:RegisterEvent("UNIT_SPELLCAST_START")
	detector:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	detector:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	for i = 1, (MAX_ARENA_ENEMIES or 5) do ScanAuras("arena" .. i) end
end

function Spec:StopEnemyDetection(force)
	-- Other consumers may still need enemy specs after the arena UI is disabled.
	if not force and IsInInstance and select(2, IsInInstance()) == "arena" then return end
	if not detectionActive then return end
	detectionActive = false
	detector:UnregisterAllEvents()
	known = {}
	notesKnown = {}
end

detector:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		known = {}
		notesKnown = {}
		for i = 1, (MAX_ARENA_ENEMIES or 5) do ScanAuras("arena" .. i) end
	elseif event == "ARENA_OPPONENT_UPDATE" then
		local unit = ...
		if unit and unit:match("^arena%d+$") then ScanAuras(unit) end
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit and unit:match("^arena%d+$") then ScanAuras(unit) end
	elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, spell = ...
		if unit and unit:match("^arena%d+$") then
			if event == "UNIT_SPELLCAST_START" then spell = UnitCastingInfo(unit) or spell end
			Detect(unit, spell, "spell")
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subevent, sourceGUID, _, _, _, _, _, spellID, spellName = ...
		if subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_CAST_START" then
			Detect(ArenaUnit(sourceGUID), spellName or (spellID and GetSpellInfo(spellID)), "spell", spellID)
		elseif subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
			Detect(ArenaUnit(sourceGUID), spellName or (spellID and GetSpellInfo(spellID)), "buff")
		end
	end
end)

-- The detector belongs to the framework, not to the arena frame module.
local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycle:RegisterEvent("ZONE_CHANGED_NEW_AREA")
lifecycle:SetScript("OnEvent", function()
	if IsInInstance and select(2, IsInInstance()) == "arena" then
		Spec:StartEnemyDetection()
	else
		Spec:StopEnemyDetection(true)
	end
end)
