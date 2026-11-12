-- Group-frame aura data shared with LibCUFAuras and its preview.
local GroupAuras = {}
SarychUI.Data.GroupAuras = GroupAuras

local GetSpellInfo = GetSpellInfo
local PLAYER_CLASS = select(2, UnitClass("player"))

local function SetAuraInfo(canApplyAura, appliesOnlyYourself)
    return { canApplyAura = canApplyAura, appliesOnlyYourself = appliesOnlyYourself }
end

local function SetRaidCombatInfo(hasCustom, alwaysShowMine, showForMySpec)
    return { hasCustom = hasCustom, alwaysShowMine = alwaysShowMine, showForMySpec = showForMySpec }
end

local UNIT_CAN_APPLY_AURAS = {
    ["DEATHKNIGHT"] =
        {
            [GetSpellInfo(48265)] = SetAuraInfo(true, true),  -- Unholy Presence
            [GetSpellInfo(48263)] = SetAuraInfo(true, true),  -- Frost Presence
            [GetSpellInfo(48266)] = SetAuraInfo(true, true),  -- Blood Presence
            [GetSpellInfo(45529)] = SetAuraInfo(true, true),  -- Blood Tap
            [GetSpellInfo(49016)] = SetAuraInfo(true, false), -- Hysteria
        },
    ["DRUID"] =
        {
            [GetSpellInfo(29166)] = SetAuraInfo(true, false), -- Innervate
            [GetSpellInfo(9634)]  = SetAuraInfo(true, true),  -- Dire Bear Form
            [GetSpellInfo(768)]   = SetAuraInfo(true, true),  -- Cat Form
            [GetSpellInfo(48451)] = SetAuraInfo(true, false), -- Lifebloom
            [GetSpellInfo(48441)] = SetAuraInfo(true, false), -- Rejuvenation
            [GetSpellInfo(48443)] = SetAuraInfo(true, false), -- Regrowth
            [GetSpellInfo(53251)] = SetAuraInfo(true, false), -- Wild Growth
            [GetSpellInfo(61336)] = SetAuraInfo(true, true),  -- Survival Instincts
            [GetSpellInfo(50334)] = SetAuraInfo(true, true),  -- Berserk
            [GetSpellInfo(5229)]  = SetAuraInfo(true, true),  -- Enrage
            [GetSpellInfo(22812)] = SetAuraInfo(true, true),  -- Barkskin
            [GetSpellInfo(53312)] = SetAuraInfo(true, true),  -- Nature's Grasp
            [GetSpellInfo(22842)] = SetAuraInfo(true, true),  -- Frenzied Regeneration
            [GetSpellInfo(2893)]  = SetAuraInfo(true, false), -- Abolish Poison
        },
    ["HUNTER"] =
        {
            [GetSpellInfo(5384)]  = SetAuraInfo(true, true),  -- Feign Death
            [GetSpellInfo(3045)]  = SetAuraInfo(true, true),  -- Rapid Fire
            [GetSpellInfo(53480)] = SetAuraInfo(true, false), -- Roar of Sacrifice
            [GetSpellInfo(53271)] = SetAuraInfo(true, false), -- Master's Call
        },
    ["MAGE"] =
        {
            [GetSpellInfo(43039)] = SetAuraInfo(true, true),  -- Ice Barrier
            [GetSpellInfo(45438)] = SetAuraInfo(true, true),  -- Ice Block
            [GetSpellInfo(42995)] = SetAuraInfo(true, false), -- Arcane Intellect
            [GetSpellInfo(61316)] = SetAuraInfo(true, false), -- Dalaran Brilliance
            [GetSpellInfo(43002)] = SetAuraInfo(true, false), -- Arcane Brilliance
            [GetSpellInfo(43015)] = SetAuraInfo(true, false), -- Dampen Magic
            [GetSpellInfo(54646)] = SetAuraInfo(true, false), -- Focus Magic
            [GetSpellInfo(61024)] = SetAuraInfo(true, false), -- Dalaran Intellect
            [GetSpellInfo(43012)] = SetAuraInfo(true, true),  -- Frost Ward
            [GetSpellInfo(43008)] = SetAuraInfo(true, true),  -- Ice Armor
            [GetSpellInfo(7301)]  = SetAuraInfo(true, true),  -- Frost Armor
            [GetSpellInfo(12472)] = SetAuraInfo(true, true),  -- Icy Veins
            [GetSpellInfo(43010)] = SetAuraInfo(true, true),  -- Fire Ward
            [GetSpellInfo(43046)] = SetAuraInfo(true, true),  -- Molten Armor
            [GetSpellInfo(43020)] = SetAuraInfo(true, true),  -- Mana Shield
            [GetSpellInfo(43024)] = SetAuraInfo(true, true),  -- Mage Armor
            [GetSpellInfo(66)]    = SetAuraInfo(true, true),  -- Invisibility
            [GetSpellInfo(130)]   = SetAuraInfo(true, false), -- Slow Fall
            [GetSpellInfo(11213)] = SetAuraInfo(true, true),  -- Arcane Concentration
            [GetSpellInfo(12043)] = SetAuraInfo(true, true),  -- Presence of Mind
            [GetSpellInfo(12042)] = SetAuraInfo(true, true),  -- Arcane Power
            [GetSpellInfo(31579)] = SetAuraInfo(true, true),  -- Arcane Empowerment
        },
    ["PALADIN"] =
        {
            [GetSpellInfo(53601)] = SetAuraInfo(true, false), -- Sacred Shield
            [GetSpellInfo(53563)] = SetAuraInfo(true, false), -- Beacon of Light
            [GetSpellInfo(6940)]  = SetAuraInfo(true, false), -- Hand of Sacrifice
            [GetSpellInfo(64205)] = SetAuraInfo(true, true),  -- Divine Sacrifice
            [GetSpellInfo(31821)] = SetAuraInfo(true, true),  -- Aura Mastery
            [GetSpellInfo(642)]   = SetAuraInfo(true, true),  -- Divine Shield
            [GetSpellInfo(1022)]  = SetAuraInfo(true, false), -- Hand of Protection
            [GetSpellInfo(10278)] = SetAuraInfo(true, false), -- Hand of Protection
            [GetSpellInfo(1044)]  = SetAuraInfo(true, false), -- Hand of Freedom
            [GetSpellInfo(54428)] = SetAuraInfo(true, true),  -- Divine Plea
            [GetSpellInfo(20217)] = SetAuraInfo(true, false), -- Blessing of Kings
            [GetSpellInfo(25898)] = SetAuraInfo(true, false), -- Greater Blessing of Kings
            [GetSpellInfo(48936)] = SetAuraInfo(true, false), -- Blessing of Wisdom
            [GetSpellInfo(48938)] = SetAuraInfo(true, false), -- Greater Blessing of Wisdom
            [GetSpellInfo(48932)] = SetAuraInfo(true, false), -- Blessing of Might
            [GetSpellInfo(48934)] = SetAuraInfo(true, false), -- Greater Blessing of Might
            [GetSpellInfo(25899)] = SetAuraInfo(true, false), -- Greater Blessing of Sanctuary
            [GetSpellInfo(20911)] = SetAuraInfo(true, false), -- Blessing of Sanctuary
            [GetSpellInfo(70940)] = SetAuraInfo(true, false), -- Divine Guardian
            [GetSpellInfo(48952)] = SetAuraInfo(true, true),  -- Holy Shield
            [GetSpellInfo(48942)] = SetAuraInfo(true, true),  -- Devotion Aura
            [GetSpellInfo(54043)] = SetAuraInfo(true, true),  -- Retribution Aura
            [GetSpellInfo(19746)] = SetAuraInfo(true, true),  -- Concentration Aura
            [GetSpellInfo(48943)] = SetAuraInfo(true, true),  -- Shadow Resistance Aura
            [GetSpellInfo(48945)] = SetAuraInfo(true, true),  -- Frost Resistance Aura
            [GetSpellInfo(48947)] = SetAuraInfo(true, true),  -- Fire Resistance Aura
            [GetSpellInfo(32223)] = SetAuraInfo(true, true),  -- Crusader Aura
            [GetSpellInfo(31884)] = SetAuraInfo(true, true),  -- Avenging Wrath
            [GetSpellInfo(54203)] = SetAuraInfo(true, false), -- Sheath of Light
            [GetSpellInfo(20053)] = SetAuraInfo(true, true),  -- Vengeance
            [GetSpellInfo(59578)] = SetAuraInfo(true, true),  -- The Art of War
        },
    ["PRIEST"] =
        {
            [GetSpellInfo(48111)] = SetAuraInfo(true, false), -- Prayer of Mending
            [GetSpellInfo(33206)] = SetAuraInfo(true, false), -- Pain Suppression
            [GetSpellInfo(48068)] = SetAuraInfo(true, false), -- Renew
            [GetSpellInfo(48162)] = SetAuraInfo(true, false), -- Prayer of Fortitude
            [GetSpellInfo(48161)] = SetAuraInfo(true, false), -- Power Word: Fortitude
            [GetSpellInfo(48066)] = SetAuraInfo(true, false), -- Power Word: Shield
            [GetSpellInfo(48073)] = SetAuraInfo(true, false), -- Divine Spirit
            [GetSpellInfo(48074)] = SetAuraInfo(true, false), -- Prayer of Spirit
            [GetSpellInfo(48169)] = SetAuraInfo(true, false), -- Shadow Protection
            [GetSpellInfo(48170)] = SetAuraInfo(true, false), -- Prayer of Shadow Protection
            [GetSpellInfo(72418)] = SetAuraInfo(true, true),  -- Chilling Knowledge
            [GetSpellInfo(47930)] = SetAuraInfo(true, false), -- Grace
            [GetSpellInfo(10060)] = SetAuraInfo(true, true),  -- Power Infusion
            [GetSpellInfo(586)]   = SetAuraInfo(true, true),  -- Fade
            [GetSpellInfo(48168)] = SetAuraInfo(true, true),  -- Inner Fire
            [GetSpellInfo(14751)] = SetAuraInfo(true, true),  -- Inner Focus
            [GetSpellInfo(6346)]  = SetAuraInfo(true, true),  -- Fear Ward
            [GetSpellInfo(64901)] = SetAuraInfo(true, false), -- Hymn of Hope
            [GetSpellInfo(64904)] = SetAuraInfo(true, true),  -- Hymn of Hope
            [GetSpellInfo(1706)]  = SetAuraInfo(true, false), -- Levitate
            [GetSpellInfo(64843)] = SetAuraInfo(true, false), -- Divine Hymn
            [GetSpellInfo(59891)] = SetAuraInfo(true, true),  -- Borrowed Time
            [GetSpellInfo(552)]   = SetAuraInfo(true, false), -- Abolish Disease
            [GetSpellInfo(15473)] = SetAuraInfo(true, true),  -- Shadowform
            [GetSpellInfo(15286)] = SetAuraInfo(true, true),  -- Vampiric Embrace
            [GetSpellInfo(49694)] = SetAuraInfo(true, true),  -- Improved Spirit Tap
            [GetSpellInfo(47788)] = SetAuraInfo(true, false), -- Guardian Spirit
            [GetSpellInfo(33151)] = SetAuraInfo(true, true),  -- Surge of Light
            [GetSpellInfo(33151)] = SetAuraInfo(true, true),  -- Inspiration
            [GetSpellInfo(7001)]  = SetAuraInfo(true, false), -- Lightwell Renew
            [GetSpellInfo(27827)] = SetAuraInfo(true, true),  -- Spirit of Redemption
            [GetSpellInfo(63734)] = SetAuraInfo(true, true),  -- Serendipity
            [GetSpellInfo(65081)] = SetAuraInfo(true, false), -- Body and Soul
            [GetSpellInfo(63944)] = SetAuraInfo(true, false), -- Renewed Hope
        },
    ["ROGUE"] =
        {
            [GetSpellInfo(1784)]  = SetAuraInfo(true, true),  -- Stealth
            [GetSpellInfo(31665)] = SetAuraInfo(true, true),  -- Master of Subtlety
            [GetSpellInfo(26669)] = SetAuraInfo(true, true),  -- Evasion
            [GetSpellInfo(11305)] = SetAuraInfo(true, true),  -- Sprint
            [GetSpellInfo(26888)] = SetAuraInfo(true, true),  -- Vanish
            [GetSpellInfo(36554)] = SetAuraInfo(true, true),  -- Shadowstep
            [GetSpellInfo(48659)] = SetAuraInfo(true, true),  -- Feint
            [GetSpellInfo(31224)] = SetAuraInfo(true, true),  -- Clock of Shadow
            [GetSpellInfo(51713)] = SetAuraInfo(true, true),  -- Shadow dance
            [GetSpellInfo(14177)] = SetAuraInfo(true, true),  -- Cold Blood
            [GetSpellInfo(57934)] = SetAuraInfo(true, false), -- Tricks of the Trade
        },
    ["SHAMAN"] =
        {
            [GetSpellInfo(49284)] = SetAuraInfo(true, false), -- Earth Shield
            [GetSpellInfo(8515)]  = SetAuraInfo(true, false), -- Windfury Totem
            [GetSpellInfo(8177)]  = SetAuraInfo(true, false), -- Grounding Totem
            [GetSpellInfo(32182)] = SetAuraInfo(true, false), -- Heroism
            [GetSpellInfo(2825)]  = SetAuraInfo(true, false), -- Bloodlust
            [GetSpellInfo(61301)] = SetAuraInfo(true, false), -- Riptide
        },
    ["WARLOCK"] = {    },
    ["WARRIOR"] =
        {
            [GetSpellInfo(2687)]  = SetAuraInfo(true, true),  -- Bloodrage
            [GetSpellInfo(18499)] = SetAuraInfo(true, true),  -- Berserker Rage
            [GetSpellInfo(12328)] = SetAuraInfo(true, true),  -- Sweeping Strikes
            [GetSpellInfo(23920)] = SetAuraInfo(true, true),  -- Spell Reflection
            [GetSpellInfo(871)]   = SetAuraInfo(true, true),  -- Shield Wall
            [GetSpellInfo(2565)]  = SetAuraInfo(true, true),  -- Shield Block
            [GetSpellInfo(55694)] = SetAuraInfo(true, true),  -- Enraged Regeneration
            [GetSpellInfo(1719)]  = SetAuraInfo(true, true),  -- Recklessness
            [GetSpellInfo(57522)] = SetAuraInfo(true, true),  -- Enrage
            [GetSpellInfo(20230)] = SetAuraInfo(true, true),  -- Retaliation
            [GetSpellInfo(46924)] = SetAuraInfo(true, true),  -- Bladestorm
            [GetSpellInfo(47440)] = SetAuraInfo(true, false), -- Commanding Shout
            [GetSpellInfo(47436)] = SetAuraInfo(true, false), -- Battle Shout
            [GetSpellInfo(46913)] = SetAuraInfo(true, true),  -- Bloodsurge
            [GetSpellInfo(12292)] = SetAuraInfo(true, true),  -- Death Wish
            [GetSpellInfo(16492)] = SetAuraInfo(true, true),  -- Blood Craze
            [GetSpellInfo(65156)] = SetAuraInfo(true, true),  -- Juggernaut
            [GetSpellInfo(3411)]  = SetAuraInfo(true, false), -- Intervene
        },
};
GroupAuras.canApply = UNIT_CAN_APPLY_AURAS

local CLASS_AURAS = {
    --== PRIEST ==--
    -- Weakened Soul
    [GetSpellInfo(6788)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, PLAYER_CLASS == "PRIEST", PLAYER_CLASS == "PRIEST"),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, PLAYER_CLASS == "PRIEST", PLAYER_CLASS == "PRIEST"),
    },
    -- Divine Spirit
    [GetSpellInfo(48073)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "PRIEST"),
    },
    -- Prayer of Spirit
    [GetSpellInfo(48074)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "PRIEST"),
    },
    -- Shadow Protection
    [GetSpellInfo(48169)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "PRIEST"),
    },
    -- Prayer of Shadow Protection
    [GetSpellInfo(48170)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "PRIEST"),
    },
    -- Prayer of Fortitude
    [GetSpellInfo(48162)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "PRIEST"),
    },
    -- Power Word: Fortitude
    [GetSpellInfo(48161)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "PRIEST"),
    },

    --== DEATHKNIGHT ==--
    -- Winter Horn
    [GetSpellInfo(57623)] = {
        ["RAID_INCOMBAT"]   = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "DEATHKNIGHT"),
    },
    -- Path of Frost
    [GetSpellInfo(3714)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "DEATHKNIGHT"),
    },

    --== PALADIN ==--
    -- Blessing of Kings
    [GetSpellInfo(20217)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "PALADIN"),
    },
    -- Greater Blessing of Kings
    [GetSpellInfo(25898)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "PALADIN"),
    },
    -- Blessing of Wisdom
    [GetSpellInfo(48936)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "PALADIN"),
    },
    -- Greater Blessing of Wisdom
    [GetSpellInfo(48938)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "PALADIN"),
    },
    -- Blessing of Might
    [GetSpellInfo(48932)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "PALADIN"),
    },
    -- Greater Blessing of Might
    [GetSpellInfo(48934)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "PALADIN"),
    },
    -- Blessing of Sanctuary
    [GetSpellInfo(20911)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "PALADIN"),
    },
    -- Greater Blessing of Sanctuary
    [GetSpellInfo(25899)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "PALADIN"),
    },

    --== DRUID ==--
    -- Mark of the Wild
    [GetSpellInfo(48469)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "DRUID"),
    },
    -- Gift of the Wild
    [GetSpellInfo(48470)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "DRUID"),
    },
    -- Thorns
    [GetSpellInfo(53307)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "DRUID"),
    },

    --== SHAMAN ==--
    -- Earth Shield
    [GetSpellInfo(49284)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, true, PLAYER_CLASS == "SHAMAN"),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, true, PLAYER_CLASS == "SHAMAN"),
    },
    -- Windfury Totem
    [GetSpellInfo(8515)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, PLAYER_CLASS == "SHAMAN"),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "SHAMAN"),
    },
    -- Grounding Totem
    [GetSpellInfo(8177)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, PLAYER_CLASS == "SHAMAN"),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "SHAMAN"),
    },

    --== WARRIOR ==--
    -- Battle Shout
    [GetSpellInfo(47436)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "WARRIOR"),
    },
    -- Commanding Shout
    [GetSpellInfo(47440)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "WARRIOR"),
    },

    --== MAGE ==--
    -- Arcane Intellect
    [GetSpellInfo(42995)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "MAGE"),
    },
    -- Dalaran Intellect
    [GetSpellInfo(61024)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "MAGE"),
    },
    -- Dalaran Brilliance
    [GetSpellInfo(61316)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "MAGE"),
    },
    -- Arcane Brilliance
    [GetSpellInfo(43002)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "MAGE"),
    },
    -- Dampen Magic
    [GetSpellInfo(43015)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "MAGE"),
    },
    -- Focus Magic
    [GetSpellInfo(54646)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "MAGE"),
    },

    --== WARLOCK ==--
    -- Unending Breath
    [GetSpellInfo(5697)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, PLAYER_CLASS == "WARLOCK"),
    },

    --== ANY DEBUFF SPELLS ==--
    -- Chill of the Throne
    [GetSpellInfo(69127)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, true),
    },
    -- Deserter
    [GetSpellInfo(26013)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, true),
    },
    -- Strange Feeling
    [GetSpellInfo(31694)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, false),
    },
    -- Quel'Delar's Compulsion
    [GetSpellInfo(70013)] = {
        ["RAID_INCOMBAT"]    = SetRaidCombatInfo(true, false, false),
        ["RAID_OUTOFCOMBAT"] = SetRaidCombatInfo(true, false, false),
    },
};
GroupAuras.visibility = CLASS_AURAS

GroupAuras.healingTaken = {
    [6136]  = "Окоченение",
    [7068]  = "Пелена Тени",
    [7321]  = "Окоченение",
    [12294] = "Смертельный удар",
    [12484] = "Окоченение",
    [12485] = "Окоченение",
    [12486] = "Окоченение",
    [13218] = "Нейтрализующий яд",
    [13222] = "Нейтрализующий яд II",
    [13223] = "Нейтрализующий яд III",
    [13224] = "Нейтрализующий яд IV",
    [13583] = "Проклятие Мертвого Леса",
    [13737] = "Смертельный удар",
    [15708] = "Смертельный удар",
    [16856] = "Смертельный удар",
    [17547] = "Смертельный удар",
    [17820] = "Пелена Тени",
    [19434] = "Прицельный выстрел",
    [19643] = "Смертельный удар",
    [19716] = "Проклятие Гееннаса",
    [20900] = "Прицельный выстрел",
    [20901] = "Прицельный выстрел",
    [20902] = "Прицельный выстрел",
    [20903] = "Прицельный выстрел",
    [20904] = "Прицельный выстрел",
    [21551] = "Смертельный удар",
    [21552] = "Смертельный удар",
    [21553] = "Смертельный удар",
    [22687] = "Пелена Тени",
    [22842] = "Неистовое восстановление",
    [22859] = "Смертельный раскол",
    [23169] = "Чернокнижие: Зеленое",
    [23224] = "Пелена Тени",
    [23230] = "Кровавое неистовство",
    [23848] = "Тестовый удар W50",
    [23850] = "Тестовый удар W35",
    [24573] = "Смертельный удар",
    [24674] = "Пелена Тени",
    [24816] = "Тест: Смертельный удар",
    [25248] = "Смертельный удар",
    [25646] = "Смертельная рана",
    [27065] = "Прицельный выстрел",
    [27189] = "Нейтрализующий яд V",
    [27580] = "Смертельный удар",
    [28440] = "Пелена Тени",
    [28467] = "Смертельная рана",
    [28776] = "Некротический яд",
    [29572] = "Смертельный удар",
    [30330] = "Смертельный удар",
    [30423] = "Врата Пустоты - Господство",
    [30641] = "Смертельная рана",
    [30843] = "Ослабление",
    [31464] = "Смертельная рана",
    [31911] = "Смертельный удар",
    [31965] = "Отрицательные эффекты эаклинаний (80)",
    [32315] = "Удар души",
    [32378] = "Филе",
    [32736] = "Смертельный удар",
    [34073] = "Проклятие Кровавой Глазницы",
    [34366] = "Эбеновый яд",
    [34625] = "Разрушение",
    [35054] = "Смертельный удар",
    [35189] = "Солнечный удар",
    [36023] = "Убийственный удар",
    [36054] = "Убийственный удар",
    [36693] = "Некротический яд",
    [36814] = "Смертельная рана",
    [36917] = "Проклятие Метателя магмы",
    [37335] = "Смертельный удар",
    [38572] = "Смертельный раскол",
    [38770] = "Смертельная рана",
    [39171] = "Смертельный удар",
    [39595] = "Смертельный раскол",
    [39665] = "Нейтрализующий яд",
    [40220] = "Смертельный удар",
    [40599] = "Удар по дуге",
    [41292] = "Аура страдания",
    [43410] = "Рубящий удар",
    [43441] = "Смертельный удар",
    [43461] = "Нейтрализующий яд",
    [44268] = "Смертельный удар",
    [44475] = "Поле ослабления магии",
    [44534] = "Непригодный удар",
    [45347] = "Затронутый тьмой",
    [45885] = "Теневой шип",
    [45996] = "Мрак",
    [46296] = "Некротический яд",
    [47485] = "Смертельный удар",
    [47486] = "Смертельный удар",
    [48137] = "Смертельная рана",
    [48266] = "Власть крови",
    [48291] = "Смрадная гниль",
    [48301] = "Повреждение разума",
    [48871] = "Прицельный выстрел",
    [49049] = "Прицельный выстрел",
    [49050] = "Прицельный выстрел",
    [52645] = "Обессиливающий сглаз",
    [52771] = "Ранящий удар",
    [53803] = "Пелена Тени",
    [54074] = "Нейтрализующий яд",
    [54121] = "Некротический яд",
    [54378] = "Смертельная рана",
    [54525] = "Покров Тьмы",
    [54615] = "Прицельный выстрел",
    [54716] = "Смертельные удары",
    [55593] = "Мертвенная аура",
    [56112] = "Яростные атаки",
    [57789] = "Смертельный удар",
    [57974] = "Нейтрализующий яд VI",
    [57975] = "Нейтрализующий яд VII",
    [58830] = "Ранящий удар",
    [59243] = "Прицельный выстрел",
    [59265] = "Смертельная рана",
    [59300] = "Смрадная гниль",
    [59455] = "Смертельные удары",
    [59513] = "Объятия вампира",
    [59525] = "Луч боли",
    [59746] = "Покров Тьмы",
    [60084] = "Завеса теней",
    [60626] = "Некротический удар",
    [61042] = "Смертный бой",
    [63038] = "Темный залп",
    [63514] = "Улучшенная аура благочестия",
    [65883] = "Прицельный выстрел",
    [65926] = "Смертельный удар",
    [65962] = "Нейтрализующий яд",
    [67542] = "Смертельный удар",
    [67977] = "Прицельный выстрел",
    [67978] = "Прицельный выстрел",
    [67979] = "Прицельный выстрел",
    [68391] = "Вечная мерзлота",
    [68782] = "Смертельный удар",
    [68783] = "Смертельный удар",
    [68784] = "Смертельный удар",
    [68881] = "Нестабильное кольцо воды",
    [69633] = "Пелена Тени",
    [69651] = "Ранящий удар",
    [69674] = "Мутировавшая инфекция",
    [70588] = "Подавление",
    [70671] = "Обессиливающая гниль",
    [70710] = "Обессиливающая гниль",
    [71127] = "Смертельная рана",
    [71224] = "Мутировавшая инфекция",
    [71552] = "Смертельный удар",
    [72390] = "Безысходность",
    [72391] = "Безысходность",
    [72393] = "Безысходность",
    [72395] = "Безысходность",
    [72396] = "Безысходность",
    [72397] = "Безысходность",
    [72569] = "Ранящий удар",
    [72570] = "Ранящий удар",
    [72571] = "Ранящий удар",
    [73022] = "Мутировавшая инфекция",
    [73023] = "Мутировавшая инфекция",
};

GroupAuras.previewBuffs = {
    { "Омоложение", "Interface\\Icons\\Spell_Nature_Rejuvenation", 774 },
    { "Слово силы: Щит", "Interface\\Icons\\Spell_Holy_PowerWordShield", 17 },
    { "Обновление", "Interface\\Icons\\Spell_Holy_Renew", 139 },
    { "Восстановление", "Interface\\Icons\\Spell_Nature_ResistNature", 8936 },
    { "Чародейский интеллект", "Interface\\Icons\\Spell_Holy_MagicalSentry", 1459 },
}

GroupAuras.previewDebuffs = {
    { "Боль", "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Magic", 589 },
    { "Заморозка", "Interface\\Icons\\Spell_Frost_FrostNova", "Magic", 122 },
    { "Проклятие", "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", "Curse", 980 },
    { "Яд", "Interface\\Icons\\Ability_Poisons", "Poison", 2818 },
    { "Болезнь", "Interface\\Icons\\Spell_Shadow_PlagueCloud", "Disease", 55078 },
}
