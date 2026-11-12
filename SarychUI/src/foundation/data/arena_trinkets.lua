-- Arena racial spells, race names and PvP trinket item art.
local Data = SarychUI.Data
local Alliance = {
    ["Human"] = "Human",
    ["Dwarf"] = "Dwarf",
    ["Night Elf"] = "Night Elf",
    ["Gnome"] = "Gnome",
    ["Draenei"] = "Draenei",
}

local Horde = {
    ["Orc"] = "Orc",
    ["Undead"] = "Undead",
    ["Tauren"] = "Tauren",
    ["Troll"] = "Troll",
    ["Blood Elf"] = "Blood Elf",
}

local racialSpells = {
    ["Human"] = {id = 59752, icon = "Interface\\Icons\\Spell_Shadow_Charm", cd = 120},
    ["Orc"] = {id = 20572, icon = "Interface\\Icons\\racial_orc_berserkerstrength", cd = 120},
    ["Dwarf"] = {id = 20594, icon = "Interface\\Icons\\spell_shadow_unholystrength", cd = 120},
    ["Night Elf"] = {id = 58984, icon = "Interface\\Icons\\ability_ambush", cd = 120},
    ["Undead"] = {id = 7744, icon = "Interface\\Icons\\spell_shadow_raisedead", cd = 120},
    ["Tauren"] = {id = 20549, icon = "Interface\\Icons\\ability_warstomp", cd = 120},
    ["Gnome"] = {id = 20589, icon = "Interface\\Icons\\ability_rogue_trip", cd = 105},
    ["Troll"] = {id = 26297, icon = "Interface\\Icons\\racial_troll_berserk", cd = 180},
    ["Blood Elf"] = {id = 28730, icon = "Interface\\Icons\\spell_shadow_teleport", cd = 120},
    ["Draenei"] = {id = 28880, icon = "Interface\\Icons\\spell_holy_holyprotection", cd = 180},
}

-- Localized UnitRace() names -> racialSpells keys (fallback when raceFile unavailable)
local raceTranslation = {
    ["Человек"] = "Human",
    ["Орк"] = "Orc",
    ["Дворф"] = "Dwarf",
    ["Ночная эльфийка"] = "Night Elf",
    ["Ночной эльф"] = "Night Elf",
    ["Нежить"] = "Undead",
    ["Таурен"] = "Tauren",
    ["Гном"] = "Gnome",
    ["Тролль"] = "Troll",
    ["Эльф крови"] = "Blood Elf",
    ["Эльфийка крови"] = "Blood Elf",
    ["Дреней"] = "Draenei",
}

-- UnitRace() raceFile tokens (locale-independent) -> racialSpells keys
local raceFileToKey = {
    Human = "Human",
    Orc = "Orc",
    Dwarf = "Dwarf",
    NightElf = "Night Elf",
    Scourge = "Undead",
    Tauren = "Tauren",
    Gnome = "Gnome",
    Troll = "Troll",
    BloodElf = "Blood Elf",
    Draenei = "Draenei",
}


Data.ArenaTrinkets = {
    alliance = Alliance, horde = Horde, racialSpells = racialSpells,
    raceTranslation = raceTranslation, raceFileToKey = raceFileToKey,
    trinketSpellID = 42292, humanSpellID = 59752,
    allianceTexture = "Interface\\Icons\\inv_jewelry_trinketpvp_01",
    hordeTexture = "Interface\\Icons\\inv_jewelry_trinketpvp_02",
}
