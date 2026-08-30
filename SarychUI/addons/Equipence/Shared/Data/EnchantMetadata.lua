--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

-- enchantID -> metadata bridge
-- 4.4.2.60895 .csv
Engine.Shared.Data.EnchantMetadataByID = {
	[13] = { spellID = 2829, itemIDs = { 2863 } }, -- Sharpened (+3 Damage) | Sharpen Blade II | items: Coarse Sharpening Stone
	[14] = { itemIDs = { 2871 } }, -- Sharpened (+4 Damage) | items: Heavy Sharpening Stone
	[15] = { itemIDs = { 2304 } }, -- Reinforced (+8 Armor) | items: Light Armor Kit
	[16] = { spellID = 2832, itemIDs = { 2313 } }, -- Reinforced (+16 Armor) | Armor +16 | items: Medium Armor Kit
	[17] = { spellID = 2833, itemIDs = { 4265 } }, -- Reinforced (+24 Armor) | Armor +24 | items: Heavy Armor Kit
	[18] = { spellID = 10344, itemIDs = { 8173 } }, -- Reinforced (+32 Armor) | Armor +32 | items: Thick Armor Kit
	[19] = { spellID = 3112, itemIDs = { 3239 } }, -- Weighted (+2 Damage) | Enhance Blunt Weapon | items: Rough Weightstone
	[20] = { spellID = 3113, itemIDs = { 3240 } }, -- Weighted (+3 Damage) | Enhance Blunt Weapon II | items: Coarse Weightstone
	[21] = { spellID = 3114, itemIDs = { 3241 } }, -- Weighted (+4 Damage) | Enhance Blunt Weapon III | items: Heavy Weightstone
	[24] = { spellID = 7443 }, -- +5 Mana | Enchant Chest - Minor Mana
	[25] = { spellID = 3594, itemIDs = { 3824 } }, -- Shadow Oil | items: Shadow Oil
	[26] = { spellID = 3595, itemIDs = { 3829 } }, -- Frost Oil | items: Frost Oil
	[30] = { spellID = 3974, itemIDs = { 4405 } }, -- Scope (+1 Damage) | Crude Scope | items: Crude Scope
	[32] = { spellID = 3975, itemIDs = { 4406 } }, -- Scope (+2 Damage) | Standard Scope | items: Standard Scope
	[33] = { spellID = 3976, itemIDs = { 4407 } }, -- Scope (+3 Damage) | Accurate Scope | items: Accurate Scope
	[34] = { spellID = 7218, itemIDs = { 6043 } }, -- Counterweight (+20 Haste Rating) | Weapon Counterweight | items: Iron Counterweight
	[36] = { spellID = 6296 }, -- Fiery Blaze Enchantmen
	[37] = { spellID = 7220, itemIDs = { 6041 } }, -- Steel Weapon Chain | Weapon Chain | items: Steel Weapon Chain
	[40] = { spellID = 2828, itemIDs = { 2862 } }, -- Sharpened (+2 Damage) | Sharpen Blade | items: Rough Sharpening Stone
	[41] = { spellID = 7418 }, -- +5 Health | Enchant Bracer - Minor Health
	[43] = { spellID = 7216, itemIDs = { 6042 } }, -- Iron Spike (8-12) | Iron Shield Spike | items: Iron Shield Spike
	[44] = { spellID = 7426 }, -- Absorption (10) | Enchant Chest - Minor Absorption
	[63] = { spellID = 13538 }, -- Absorption (25) | Enchant Chest - Lesser Absorption
	[66] = { spellID = 7457 }, -- +1 Stamina | Enchant Bracer - Minor Stamina
	[241] = { spellID = 7745 }, -- +2 Weapon Damage | Enchant 2H Weapon - Minor Impact
	[242] = { spellID = 7748 }, -- +15 Health | Enchant Chest - Lesser Health
	[243] = { spellID = 7766 }, -- +1 Spirit | Enchant Bracer - Minor Spirit
	[246] = { spellID = 7776 }, -- +20 Mana | Enchant Chest - Lesser Mana
	[247] = { spellID = 7779 }, -- +1 Agility | Enchant Bracer - Minor Agility
	[248] = { spellID = 7782 }, -- +1 Strength | Enchant Bracer - Minor Strength
	[249] = { spellID = 7786 }, -- +2 Beastslaying | Enchant Weapon - Minor Beastslayer
	[250] = { spellID = 7788 }, -- +1  Weapon Damage | Enchant Weapon - Minor Striking
	[254] = { spellID = 7857 }, -- +25 Health | Enchant Chest - Health
	[255] = { spellID = 7859 }, -- +3 Spirit | Enchant Bracer - Lesser Spirit
	[263] = { itemIDs = { 6529 } }, -- Fishing Lure (+25 Fishing Skill) | items: Shiny Bauble
	[264] = { itemIDs = { 6530 } }, -- Fishing Lure (+50 Fishing Skill) | items: Nightcrawlers
	[265] = { itemIDs = { 6532, 33820 } }, -- Fishing Lure (+75 Fishing Skill) | items: Bright Baubles / Weather-Beaten Fishing Hat
	[266] = { itemIDs = { 6533, 34861 } }, -- Fishing Lure (+100 Fishing Skill) | items: Aquadynamic Fish Attractor / Sharpened Fish Hook
	[368] = { spellID = 34004 }, -- +12 Agility | Enchant Cloak - Greater Agility
	[369] = { spellID = 34001 }, -- +12 Intellect | Enchant Bracer - Major Intellect
	[463] = { spellID = 9781, itemIDs = { 7967 } }, -- Mithril Spike (16-20) | Mithril Shield Spike | items: Mithril Shield Spike
	[464] = { spellID = 9783, itemIDs = { 7969 } }, -- +4% Mount Speed | Mithril Spurs | items: Mithril Spurs
	[483] = { spellID = 9900, itemIDs = { 7964 } }, -- Sharpened (+6 Damage) | Sharpen Blade IV | items: Solid Sharpening Stone
	[484] = { spellID = 9903, itemIDs = { 7965 } }, -- Weighted (+6 Damage) | Enhance Blunt Weapon IV | items: Solid Weightstone
	[663] = { spellID = 12459, itemIDs = { 10546 } }, -- Scope (+5 Damage) | Deadly Scope | items: Deadly Scope
	[664] = { spellID = 12460, itemIDs = { 10548 } }, -- Scope (+7 Damage) | Sniper Scope | items: Sniper Scope
	[684] = { spellID = 33995 }, -- +15 Strength | Enchant Gloves - Major Strength
	[723] = { spellID = 7793 }, -- +3 Intellect | Enchant 2H Weapon - Lesser Intellect
	[724] = { spellID = 13501 }, -- +3 Stamina | Enchant Bracer - Lesser Stamina
	[744] = { spellID = 13421 }, -- +20 Armor | Enchant Cloak - Lesser Protection
	[783] = { spellID = 7771 }, -- +10 Armor | Enchant Cloak - Minor Protection
	[803] = { spellID = 13898 }, -- Fiery Weapon | Enchant Weapon - Fiery Weapon
	[805] = { spellID = 13943 }, -- +4 Weapon Damage | Enchant Weapon - Greater Striking
	[823] = { spellID = 13536 }, -- +3 Strength | Enchant Bracer - Lesser Strength
	[843] = { spellID = 13607 }, -- +30 Mana | Enchant Chest - Mana
	[844] = { spellID = 13612 }, -- +2 Mining | Enchant Gloves - Mining
	[845] = { spellID = 13617 }, -- +2 Herbalism | Enchant Gloves - Herbalism
	[846] = { itemIDs = { 19971 } }, -- +5 Fishing | items: High Test Eternium Fishing Line
	[847] = { spellID = 13626 }, -- +1 All Stats | Enchant Chest - Minor Stats
	[848] = { spellID = 13464 }, -- +30 Armor | Enchant Shield - Lesser Protection
	[849] = { spellID = 13637 }, -- +3 Agility | Enchant Boots - Lesser Agility
	[850] = { spellID = 13640 }, -- +35 Health | Enchant Chest - Greater Health
	[851] = { spellID = 13642 }, -- +5 Spirit | Enchant Bracer - Spirit
	[852] = { spellID = 13648 }, -- +5 Stamina | Enchant Bracer - Stamina
	[853] = { spellID = 13653 }, -- +6 Beastslaying | Enchant Weapon - Lesser Beastslayer
	[854] = { spellID = 13655 }, -- +6 Elemental Slayer | Enchant Weapon - Lesser Elemental Slayer
	[856] = { spellID = 13661 }, -- +5 Strength | Enchant Bracer - Strength
	[857] = { spellID = 13663 }, -- +50 Mana | Enchant Chest - Greater Mana
	[863] = { spellID = 13689 }, -- +10 Parry Rating | Enchant Shield - Lesser Parry
	[865] = { spellID = 13698 }, -- +5 Skinning | Enchant Gloves - Skinning
	[866] = { spellID = 13700 }, -- +2 All Stats | Enchant Chest - Lesser Stats
	[884] = { spellID = 13746 }, -- +50 Armor | Enchant Cloak - Greater Defense
	[904] = { spellID = 13815 }, -- +5 Agility | Enchant Gloves - Agility
	[905] = { spellID = 13822 }, -- +5 Intellect | Enchant Bracer - Intellect
	[906] = { spellID = 13841 }, -- +5 Mining | Enchant Gloves - Advanced Mining
	[907] = { spellID = 13846 }, -- +7 Spirit | Enchant Bracer - Greater Spirit
	[908] = { spellID = 13858 }, -- +50 Health | Enchant Chest - Superior Health
	[909] = { spellID = 13868 }, -- +5 Herbalism | Enchant Gloves - Advanced Herbalism
	[910] = { spellID = 25083 }, -- +8 Agility and +8 Dodge Rating | Enchant Cloak - Stealth
	[911] = { spellID = 13890 }, -- Minor Speed Increase | Enchant Boots - Minor Speed
	[912] = { spellID = 13915 }, -- Demonslaying | Enchant Weapon - Demonslaying
	[913] = { spellID = 13917 }, -- +65 Mana | Enchant Chest - Superior Mana
	[923] = { spellID = 13931 }, -- +5 Dodge Rating | Enchant Bracer - Dodge
	[924] = { spellID = 7428 }, -- +2 Dodge Rating | Enchant Bracer - Minor Dodge
	[925] = { spellID = 13646 }, -- +3 Dodge Rating | Enchant Bracer - Lesser Dodge
	[927] = { spellID = 13939 }, -- +7 Strength | Enchant Bracer - Greater Strength
	[928] = { spellID = 13941 }, -- +3 All Stats | Enchant Chest - Stats
	[929] = { spellID = 13945 }, -- +7 Stamina | Enchant Bracer - Greater Stamina
	[930] = { spellID = 13947 }, -- +2% Mount Speed | Enchant Gloves - Riding Skill
	[931] = { spellID = 13948 }, -- +10 Haste Rating | Enchant Gloves - Minor Haste
	[943] = { spellID = 13529 }, -- +3 Weapon Damage | Enchant 2H Weapon - Lesser Impact
	[963] = { spellID = 13937 }, -- +7 Weapon Damage | Enchant 2H Weapon - Greater Impact
	[983] = { spellID = 44500 }, -- +16 Agility | Enchant Cloak - Superior Agility
	[1071] = { spellID = 34009 }, -- +18 Stamina | Enchant Shield - Major Stamina
	[1075] = { spellID = 44528 }, -- +22 Stamina | Enchant Boots - Greater Fortitude
	[1099] = { spellID = 60663 }, -- +22 Agility | Enchant Cloak - Major Agility
	[1103] = { spellID = 44633 }, -- +26 Agility | Enchant Weapon - Exceptional Agility
	[1119] = { spellID = 44555 }, -- +16 Intellect | Enchant Bracer - Exceptional Intellect
	[1128] = { spellID = 60653 }, -- +25 Intellect | Enchant Shield - Greater Intellect
	[1144] = { spellID = 33990 }, -- +15 Spirit | Enchant Chest - Major Spirit
	[1147] = { spellID = 44508 }, -- +18 Spirit | Enchant Boots - Greater Spirit
	[1483] = { itemIDs = { 11622 } }, -- +150 Mana | Lesser Arcane Amalgamation | items: Lesser Arcanum of Rumination
	[1503] = { itemIDs = { 11642 } }, -- +100 Health | Lesser Arcane Amalgamation | items: Lesser Arcanum of Constitution
	[1504] = { itemIDs = { 11643 } }, -- +125 Armor | Lesser Arcane Amalgamation | items: Lesser Arcanum of Tenacity
	[1505] = { itemIDs = { 11644 } }, -- +20 Fire Resistance | Lesser Arcane Amalgamation | items: Lesser Arcanum of Resilience
	[1506] = { itemIDs = { 11645 } }, -- +8 Strength | Lesser Arcane Amalgamation | items: Lesser Arcanum of Voracity
	[1507] = { itemIDs = { 11646 } }, -- +8 Stamina  | Lesser Arcane Amalgamation | items: Lesser Arcanum of Voracity
	[1508] = { itemIDs = { 11647 } }, -- +8 Agility | Lesser Arcane Amalgamation | items: Lesser Arcanum of Voracity
	[1509] = { itemIDs = { 11648 } }, -- +8 Intellect | Lesser Arcane Amalgamation | items: Lesser Arcanum of Voracity
	[1510] = { itemIDs = { 11649 } }, -- +8 Spirit | Lesser Arcane Amalgamation | items: Lesser Arcanum of Voracity
	[1593] = { spellID = 34002 }, -- +24 Attack Power | Enchant Bracer - Lesser Assault
	[1594] = { spellID = 33996 }, -- +26 Attack Power | Enchant Gloves - Assault
	[1597] = { spellID = 60763 }, -- +32 Attack Power | Enchant Boots - Greater Assault
	[1600] = { spellID = 60616 }, -- +38 Attack Power | Enchant Bracer - Assault
	[1603] = { spellID = 60668 }, -- +44 Attack Power | Enchant Gloves - Crusher
	[1606] = { spellID = 60621 }, -- +50 Attack Power | Enchant Weapon - Greater Potency
	[1643] = { spellID = 16138, itemIDs = { 12404 } }, -- Sharpened (+8 Damage) | Sharpen Blade V | items: Dense Sharpening Stone
	[1703] = { spellID = 16622, itemIDs = { 12643 } }, -- Weighted (+8 Damage) | Enhance Blunt Weapon V | items: Dense Weightstone
	[1704] = { spellID = 16623, itemIDs = { 12645 } }, -- Thorium Spike (20-30) | Thorium Shield Spike | items: Thorium Shield Spike
	[1843] = { spellID = 19057, itemIDs = { 15564 } }, -- Reinforced (+40 Armor) | Armor +40 | items: Rugged Armor Kit
	[1883] = { spellID = 20008 }, -- +7 Intellect | Enchant Bracer - Greater Intellect
	[1884] = { spellID = 20009 }, -- +9 Spirit | Enchant Bracer - Superior Spirit
	[1885] = { spellID = 20010 }, -- +9 Strength | Enchant Bracer - Superior Strength
	[1886] = { spellID = 20011 }, -- +9 Stamina | Enchant Bracer - Superior Stamina
	[1887] = { spellID = 20012 }, -- +7 Agility | Enchant Gloves - Greater Agility
	[1889] = { spellID = 20015 }, -- +70 Armor | Enchant Cloak - Superior Defense
	[1890] = { spellID = 20016 }, -- +10 Spirit and +10 Stamina | Enchant Shield - Vitality
	[1891] = { spellID = 20025 }, -- +4 All Stats | Enchant Chest - Greater Stats
	[1892] = { spellID = 20026 }, -- +100 Health | Enchant Chest - Major Health
	[1893] = { spellID = 20028 }, -- +100 Mana | Enchant Chest - Major Mana
	[1894] = { spellID = 20029 }, -- Icy Chill | Enchant Weapon - Icy Chill
	[1896] = { spellID = 20030 }, -- +9 Weapon Damage | Enchant 2H Weapon - Superior Impact
	[1897] = { spellID = 13695 }, -- +5 Weapon Damage | Enchant 2H Weapon - Impact
	[1898] = { spellID = 20032 }, -- Lifestealing | Enchant Weapon - Lifestealing
	[1899] = { spellID = 20033 }, -- Unholy Weapon | Enchant Weapon - Unholy Weapon
	[1900] = { spellID = 20034 }, -- Crusader | Enchant Weapon - Crusader
	[1903] = { spellID = 20035 }, -- +9 Spirit | Enchant 2H Weapon - Major Spirit
	[1904] = { spellID = 20036 }, -- +9 Intellect | Enchant 2H Weapon - Major Intellect
	[1951] = { spellID = 44591 }, -- +18 Dodge Rating | Enchant Cloak - Superior Dodge
	[1952] = { spellID = 44489 }, -- +20 Dodge Rating | Enchant Shield - Dodge
	[1953] = { spellID = 47766 }, -- +22 Dodge Rating | Enchant Chest - Greater Dodge
	[2322] = { spellID = 33999 }, -- +19 Spell Power | Enchant Gloves - Major Healing
	[2326] = { spellID = 44635 }, -- +23 Spell Power | Enchant Bracer - Greater Spellpower
	[2332] = { spellID = 60767 }, -- +30 Spell Power | Enchant Bracer - Superior Spellpower
	[2381] = { spellID = 44509 }, -- +20 Spirit | Enchant Chest - Greater Mana Restoration
	[2443] = { spellID = 21931 }, -- +7 Frost Spell Damage | Enchant Weapon - Winter's Might
	[2488] = { spellID = 22599 }, -- +5 All Resistances | Chromatic Mantle of the Dawn
	[2503] = { spellID = 22725, itemIDs = { 18251 } }, -- +5 Dodge Rating | Core Armor Kit | items: Core Armor Kit
	[2504] = { spellID = 22749 }, -- +30 Spell Power | Enchant Weapon - Spellpower
	[2505] = { spellID = 22750 }, -- +29 Spell Power | Enchant Weapon - Healing Power
	[2506] = { spellID = 22756, itemIDs = { 18262 } }, -- +28 Melee Critical Strike Rating | Elemental Sharpening Stone | items: Elemental Sharpening Stone
	[2523] = { itemIDs = { 18283 } }, -- +30 Ranged Hit Rating | items: Biznicks 247x128 Accurascope
	[2543] = { spellID = 22840, itemIDs = { 18329 } }, -- +10 Haste Rating | Arcanum of Rapidity | items: Arcanum of Rapidity
	[2544] = { spellID = 22844, itemIDs = { 18330 } }, -- +8 Spell Power | Arcanum of Focus | items: Arcanum of Focus
	[2545] = { spellID = 22846, itemIDs = { 18331 } }, -- +12 Dodge Rating | Arcanum of Protection | items: Arcanum of Protection
	[2563] = { spellID = 23799 }, -- +15 Strength | Enchant Weapon - Strength
	[2564] = { spellID = 23800 }, -- +15 Agility | Enchant Weapon - Agility
	[2565] = { spellID = 23801 }, -- +9 Spirit | Enchant Bracer - Mana Regeneration
	[2567] = { spellID = 23803 }, -- +20 Spirit | Enchant Weapon - Mighty Spirit
	[2568] = { spellID = 23804 }, -- +22 Intellect | Enchant Weapon - Mighty Intellect
	[2583] = { spellID = 24149, itemIDs = { 19782 } }, -- +10 Dodge Rating +10 Stamina +10 Parry Rating | Presence of Might | items: Presence of Might
	[2584] = { spellID = 24160, itemIDs = { 19783 } }, -- +10 Dodge Rating +10 Stamina and +10 Intellect | Syncretist's Sigil | items: Syncretist's Sigil
	[2587] = { spellID = 24163, itemIDs = { 19786 } }, -- +13 Spell Power and +15 Intellect | Vodouisant's Vigilant Embrace | items: Vodouisant's Vigilant Embrace
	[2588] = { spellID = 24164, itemIDs = { 19787 } }, -- +18 Spell Power and +8 Hit Rating | Presence of Sight | items: Presence of Sight
	[2589] = { spellID = 24165, itemIDs = { 19788 } }, -- +18 Spell Power and +10 Stamina | Hoodoo Hex | items: Hoodoo Hex
	[2590] = { spellID = 24167, itemIDs = { 19789 } }, -- +10 Intellect +10 Stamina and +10 Spirit | Prophetic Aura | items: Prophetic Aura
	[2591] = { spellID = 24168, itemIDs = { 19790 } }, -- +10 Intellect +10 Stamina +12 Spell Power | Animist's Caress | items: Animist's Caress
	[2603] = { spellID = 13620 }, -- +2 Fishing | Enchant Gloves - Fishing
	[2604] = { spellID = 24420 }, -- +18 Spell Power | Zandalar Signet of Serenity
	[2606] = { spellID = 24422 }, -- +30 Attack Power | Zandalar Signet of Might
	[2613] = { spellID = 25072 }, -- +2% Threat | Enchant Gloves - Threat
	[2614] = { spellID = 25073 }, -- +20 Shadow Spell Power | Enchant Gloves - Shadow Power
	[2615] = { spellID = 25074 }, -- +20 Frost Spell Power | Enchant Gloves - Frost Power
	[2616] = { spellID = 25078 }, -- +20 Fire Spell Power | Enchant Gloves - Fire Power
	[2617] = { spellID = 25079 }, -- +16 Spell Power | Enchant Gloves - Healing Power
	[2621] = { spellID = 25084 }, -- 2% Reduced Threat | Enchant Cloak - Subtlety
	[2622] = { spellID = 25086 }, -- +12 Dodge Rating | Enchant Cloak - Dodge
	[2623] = { spellID = 25117, itemIDs = { 20744 } }, -- Minor Wizard Oil | items: Minor Wizard Oil
	[2624] = { spellID = 25118, itemIDs = { 20745 } }, -- Minor Mana Oil | items: Minor Mana Oil
	[2625] = { spellID = 25120, itemIDs = { 20747 } }, -- Lesser Mana Oil | items: Lesser Mana Oil
	[2626] = { spellID = 25119, itemIDs = { 20746 } }, -- Lesser Wizard Oil | items: Lesser Wizard Oil
	[2627] = { spellID = 25121, itemIDs = { 20750 } }, -- Wizard Oil | items: Wizard Oil
	[2628] = { spellID = 25122, itemIDs = { 20749 } }, -- Brilliant Wizard Oil | items: Brilliant Wizard Oil
	[2629] = { spellID = 25123, itemIDs = { 20748 } }, -- Brilliant Mana Oil | items: Brilliant Mana Oil
	[2646] = { spellID = 27837 }, -- +25 Agility | Enchant 2H Weapon - Agility
	[2647] = { spellID = 27899 }, -- +12 Strength | Enchant Bracer - Brawn
	[2648] = { spellID = 27906 }, -- +14 Dodge Rating | Enchant Bracer - Greater Dodge
	[2649] = { spellID = 27914 }, -- +12 Stamina | Enchant Bracer - Fortitude
	[2650] = { spellID = 23802 }, -- +15 Spell Power | Enchant Bracer - Healing Power
	[2653] = { spellID = 27944 }, -- +12 Dodge Rating | Enchant Shield - Lesser Dodge
	[2654] = { spellID = 27945 }, -- +12 Intellect | Enchant Shield - Intellect
	[2655] = { spellID = 27946 }, -- +15 Parry Rating | Enchant Shield - Parry
	[2656] = { spellID = 27948 }, -- +10 Spirit and +10 Stamina | Enchant Boots - Vitality
	[2657] = { spellID = 27951 }, -- +12 Agility | Enchant Boots - Dexterity
	[2658] = { spellID = 27954 }, -- +10 Hit Rating and +10 Critical Strike Rating | Enchant Boots - Surefooted
	[2659] = { spellID = 27957 }, -- +150 Health | Enchant Chest - Exceptional Health
	[2661] = { spellID = 27960 }, -- +6 All Stats | Enchant Chest - Exceptional Stats
	[2662] = { spellID = 27961 }, -- +120 Armor | Enchant Cloak - Major Armor
	[2666] = { spellID = 27968 }, -- +30 Intellect | Enchant Weapon - Major Intellect
	[2667] = { spellID = 27971 }, -- +70 Attack Power | Enchant 2H Weapon - Savagery
	[2668] = { spellID = 27972 }, -- +20 Strength | Enchant Weapon - Potency
	[2669] = { spellID = 27975 }, -- +40 Spell Power | Enchant Weapon - Major Spellpower
	[2670] = { spellID = 27977 }, -- +35 Agility | Enchant 2H Weapon - Major Agility
	[2671] = { spellID = 27981 }, -- +50 Arcane and Fire Spell Power | Enchant Weapon - Sunfire
	[2672] = { spellID = 27982 }, -- +54 Shadow and Frost Spell Power | Enchant Weapon - Soulfrost
	[2673] = { spellID = 27984 }, -- Mongoose | Enchant Weapon - Mongoose
	[2674] = { spellID = 28003 }, -- Spellsurge | Enchant Weapon - Spellsurge
	[2675] = { spellID = 28004 }, -- Battlemaster | Enchant Weapon - Battlemaster
	[2677] = { spellID = 28013, itemIDs = { 22521 } }, -- Superior Mana Oil | items: Superior Mana Oil
	[2678] = { spellID = 28017, itemIDs = { 22522 } }, -- Superior Wizard Oil | items: Superior Wizard Oil
	[2679] = { spellID = 27913 }, -- +12 Spirit | Enchant Bracer - Restore Mana Prime
	[2712] = { spellID = 29452, itemIDs = { 23528 } }, -- Sharpened (+12 Damage) | Sharpen Blade | items: Fel Sharpening Stone
	[2713] = { itemIDs = { 23529 } }, -- Sharpened (+14 Critical Strike Rating and +12 Damage) | items: Adamantite Sharpening Stone
	[2714] = { spellID = 29454, itemIDs = { 23530 } }, -- Felsteel Spike (26-38) | Felsteel Shield Spike | items: Felsteel Shield Spike
	[2716] = { spellID = 29480, itemIDs = { 23549 } }, -- Fortitude of the Scourge | +16 Stamina and +100 Armor
	[2718] = { spellID = 32274 }, -- Lesser Rune of Warding
	[2719] = { spellID = 29507 }, -- Lesser Ward of Shielding
	[2721] = { spellID = 29467 }, -- +15 Spell Power and +14 Critical Strike Rating | Power of the Scourge
	[2722] = { spellID = 30250, itemIDs = { 23764 } }, -- Scope (+10 Damage) | Adamantite Scope | items: Adamantite Scope
	[2723] = { spellID = 30252, itemIDs = { 23765 } }, -- Scope (+12 Damage) | Khorium Scope | items: Khorium Scope
	[2724] = { itemIDs = { 23766 } }, -- Scope (+28 Critical Strike Rating) | items: Stabilized Eternium Scope
	[2745] = { spellID = 31369, itemIDs = { 24275 } }, -- +25 Spell Power and +15 Stamina | Silver Spellthread | items: Silver Spellthread
	[2746] = { spellID = 31370, itemIDs = { 24276 } }, -- +35 Spell Power and +20 Stamina | Golden Spellthread | items: Golden Spellthread
	[2747] = { spellID = 31371, itemIDs = { 24273 } }, -- +25 Spell Power and +15 Stamina | Mystic Spellthread | items: Mystic Spellthread
	[2748] = { spellID = 31372, itemIDs = { 24274 } }, -- +35 Spell Power and +20 Stamina | Runic Spellthread | items: Runic Spellthread
	[2791] = { spellID = 32282 }, -- Greater Rune of Warding
	[2792] = { spellID = 32397, itemIDs = { 25650 } }, -- +8 Stamina | Knothide Armor Kit | items: Knothide Armor Kit
	[2793] = { spellID = 32398, itemIDs = { 25651 } }, -- +8 Dodge Rating | Vindicator's Armor Kit | items: Vindicator's Armor Kit
	[2794] = { spellID = 32399, itemIDs = { 25652 } }, -- +8 Spirit | Magister's Armor Kit | items: Magister's Armor Kit
	[2795] = { spellID = 32426, itemIDs = { 25679 } }, -- Comfortable Insoles | items: Comfortable Insoles
	[2841] = { spellID = 44968, itemIDs = { 34330 } }, -- +10 Stamina | Heavy Knothide Armor Kit | items: Heavy Knothide Armor Kit
	[2928] = { spellID = 27924 }, -- +12 Spell Power | Enchant Ring - Spellpower
	[2929] = { spellID = 27920 }, -- +2 Weapon Damage | Enchant Ring - Striking
	[2930] = { spellID = 27926 }, -- +12 Spell Power | Enchant Ring - Healing Power
	[2931] = { spellID = 27927 }, -- +4 All Stats | Enchant Ring - Stats
	[2933] = { spellID = 33992 }, -- +15 Resilience Rating | Enchant Chest - Major Resilience
	[2934] = { spellID = 33993 }, -- +10 Critical Strike Rating | Enchant Gloves - Blasting
	[2935] = { spellID = 33994 }, -- +15 Hit Rating | Enchant Gloves - Precise Strikes
	[2937] = { spellID = 33997 }, -- +20 Spell Power | Enchant Gloves - Major Spellpower
	[2938] = { spellID = 34003 }, -- +20 Spell Penetration | Enchant Cloak - Spell Penetration
	[2939] = { spellID = 34007 }, -- Minor Speed and +6 Agility | Enchant Boots - Cat's Swiftness
	[2940] = { spellID = 34008 }, -- Minor Speed and +9 Stamina | Enchant Boots - Boar's Speed
	[2954] = { spellID = 34339, itemIDs = { 28420 } }, -- Weighted (+12 Damage) | Enhance Blunt Weapon | items: Fel Weightstone
	[2955] = { spellID = 34340, itemIDs = { 28421 } }, -- Weighted (+14 Critical Strike Rating and +12 Damage) | Weight Weapon | items: Adamantite Weightstone
	[2977] = { spellID = 35355, itemIDs = { 28882 } }, -- +13 Dodge Rating | Inscription of Warding | items: Inscription of Warding
	[2978] = { spellID = 35402, itemIDs = { 28889 } }, -- +15 Dodge Rating and +15 Stamina | Greater Inscription of Warding | items: Greater Inscription of Warding
	[2979] = { spellID = 35403, itemIDs = { 28878 } }, -- +15 Spell Power | Inscription of Faith | items: Inscription of Faith
	[2980] = { spellID = 35404, itemIDs = { 28887 } }, -- +15 Intellect and +10 Spirit | Greater Inscription of Faith | items: Greater Inscription of Faith
	[2981] = { spellID = 35405, itemIDs = { 28881 } }, -- +15 Spell Power | Inscription of Discipline | items: Inscription of Discipline
	[2982] = { spellID = 35406, itemIDs = { 28886 } }, -- +18 Spell Power and +10 Critical Strike Rating | Greater Inscription of Discipline | items: Greater Inscription of Discipline
	[2983] = { spellID = 35407, itemIDs = { 28885 } }, -- +26 Attack Power | Inscription of Vengeance | items: Inscription of Vengeance
	[2986] = { spellID = 35417, itemIDs = { 28888 } }, -- +30 Attack Power and +10 Critical Strike Rating | Greater Inscription of Vengeance | items: Greater Inscription of Vengeance
	[2990] = { spellID = 35432, itemIDs = { 28908 } }, -- +13 Dodge Rating | Inscription of the Knight | items: Inscription of the Knight
	[2991] = { spellID = 35433, itemIDs = { 28911 } }, -- +15 Parry Rating and +10 Dodge Rating | Greater Inscription of the Knight | items: Greater Inscription of the Knight
	[2992] = { spellID = 35434, itemIDs = { 28904 } }, -- +12 Spirit | Inscription of the Oracle | items: Inscription of the Oracle
	[2993] = { spellID = 35435, itemIDs = { 28912 } }, -- +10 Intellect and +16 Spirit | Greater Inscription of the Oracle | items: Greater Inscription of the Oracle
	[2994] = { spellID = 35436, itemIDs = { 28903 } }, -- +13 Critical Strike Rating | Inscription of the Orb | items: Inscription of the Orb
	[2995] = { spellID = 35437, itemIDs = { 28909 } }, -- +15 Critical Strike Rating and +12 Spell Power | Greater Inscription of the Orb | items: Greater Inscription of the Orb
	[2996] = { spellID = 35438, itemIDs = { 28907 } }, -- +13 Critical Strike Rating | Inscription of the Blade | items: Inscription of the Blade
	[2997] = { spellID = 35439, itemIDs = { 28910 } }, -- +15 Critical Strike Rating and +20 Attack Power | Greater Inscription of the Blade | items: Greater Inscription of the Blade
	[2999] = { spellID = 35443, itemIDs = { 29186 } }, -- +16 Parry Rating and +17 Dodge Rating | Arcanum of the Defender | items: Arcanum of the Defender
	[3001] = { spellID = 35445, itemIDs = { 29189, 29190 } }, -- +16 Intellect and +18 Spirit | Arcanum of Renewal | items: Arcanum of Renewal / Arcanum of Renewal
	[3002] = { spellID = 35447, itemIDs = { 29191 } }, -- +22 Spell Power and +14 Hit Rating | Arcanum of Power | items: Arcanum of Power
	[3003] = { spellID = 35452, itemIDs = { 29192 } }, -- +34 Attack Power and +16 Hit Rating | Arcanum of Ferocity | items: Arcanum of Ferocity
	[3004] = { spellID = 35453, itemIDs = { 29193 } }, -- +18 Stamina and +20 Resilience Rating | Arcanum of the Gladiator | items: Arcanum of the Gladiator
	[3005] = { spellID = 35454, itemIDs = { 29194 } }, -- +20 Nature Resistance | Arcanum of Nature Warding | items: Arcanum of Nature Warding
	[3010] = { spellID = 35488, itemIDs = { 29533 } }, -- +40 Attack Power and +10 Critical Strike Rating | Cobrahide Leg Armor | items: Cobrahide Leg Armor
	[3011] = { spellID = 35489, itemIDs = { 29534 } }, -- +30 Stamina and +10 Agility | Clefthide Leg Armor | items: Clefthide Leg Armor
	[3012] = { spellID = 35490, itemIDs = { 29535 } }, -- +50 Attack Power and +12 Critical Strike Rating | Nethercobra Leg Armor | items: Nethercobra Leg Armor
	[3013] = { spellID = 35495, itemIDs = { 29536 } }, -- +40 Stamina and +12 Agility | Nethercleft Leg Armor | items: Nethercleft Leg Armor
	[3096] = { spellID = 37891, itemIDs = { 30846 } }, -- +17 Strength and +16 Intellect | Arcanum of the Outcast | items: Arcanum of the Outcast
	[3150] = { spellID = 33991 }, -- +14 Spirit | Enchant Chest - Restore Mana Prime
	[3222] = { spellID = 42620 }, -- +20 Agility | Enchant Weapon - Greater Agility
	[3223] = { spellID = 42687, itemIDs = { 33185 } }, -- Adamantite Weapon Chain | items: Adamantite Weapon Chain
	[3225] = { spellID = 42974 }, -- Executioner | Enchant Weapon - Executioner
	[3229] = { spellID = 44383 }, -- +12 Resilience Rating | Enchant Shield - Resilience
	[3231] = { spellID = 44484 }, -- +15 Expertise Rating | Enchant Gloves - Expertise
	[3232] = { spellID = 47901 }, -- +15 Stamina and Minor Speed Increase | Enchant Boots - Tuskarr's Vitality
	[3233] = { spellID = 27958 }, -- +250 Mana | Enchant Chest - Exceptional Mana
	[3234] = { spellID = 44488 }, -- +20 Hit Rating | Enchant Gloves - Precision
	[3236] = { spellID = 44492 }, -- +200 Health | Enchant Chest - Mighty Health
	[3238] = { spellID = 44506 }, -- Gatherer | Enchant Gloves - Gatherer
	[3239] = { spellID = 44524 }, -- Icebreaker Weapon | Enchant Weapon - Icebreaker
	[3241] = { spellID = 44576 }, -- Lifeward | Enchant Weapon - Lifeward
	[3243] = { spellID = 44582 }, -- +35 Spell Penetration | Enchant Cloak - Spell Piercing
	[3244] = { spellID = 44584 }, -- +14 Spirit and +14 Stamina | Enchant Boots - Greater Vitality
	[3245] = { spellID = 44588 }, -- +20 Resilience Rating | Enchant Chest - Exceptional Resilience
	[3246] = { spellID = 44592 }, -- +28 Spell Power | Enchant Gloves - Exceptional Spellpower
	[3247] = { spellID = 44595 }, -- +140 Attack Power versus Undead | Enchant 2H Weapon - Scourgebane
	[3251] = { spellID = 44621 }, -- Giantslaying | Enchant Weapon - Giant Slayer
	[3252] = { spellID = 44623 }, -- +8 All Stats | Enchant Chest - Super Stats
	[3253] = { spellID = 44625 }, -- +2% Threat and 10 Parry Rating | Enchant Gloves - Armsman
	[3256] = { spellID = 44631 }, -- +10 Agility and +40 Armor | Enchant Cloak - Shadow Armor
	[3260] = { spellID = 44769, itemIDs = { 34207 } }, -- +240 Armor | Glove Reinforcements | items: Glove Reinforcements
	[3269] = { spellID = 45697, itemIDs = { 34836 } }, -- +3 Fishing | Truesilver Fishing Line | items: Spun Truesilver Fishing Line
	[3273] = { spellID = 46578 }, -- Deathfrost | Enchant Weapon - Deathfrost
	[3294] = { spellID = 47672 }, -- +225 Armor | Enchant Cloak - Mighty Armor
	[3296] = { spellID = 47899 }, -- +10 Spirit and 2% Reduced Threat | Enchant Cloak - Wisdom
	[3297] = { spellID = 47900 }, -- +275 Health | Enchant Chest - Super Health
	-- [3315] = { spellID = 47900, itemIDs = { 37312 } }, -- +3% Mount Speed | Carrot on a Stick
	[3325] = { spellID = 50901, itemIDs = { 38371 } }, -- +45 Stamina and +15 Agility | Jormungar Leg Armor | items: Jormungar Leg Armor
	[3326] = { spellID = 50902, itemIDs = { 38372 } }, -- +55 Attack Power and +15 Critical Strike Rating | Nerubian Leg Armor | items: Nerubian Leg Armor
	[3327] = { spellID = 60583 }, -- +55 Stamina and +22 Agility | Jormungar Leg Reinforcements
	[3328] = { itemIDs = { 38374 } }, -- +75 Attack Power and +22 Critical Strike Rating | items: Icescale Leg Armor
	[3329] = { spellID = 50906, itemIDs = { 38375 } }, -- +12 Stamina | Borean Armor Kit | items: Borean Armor Kit
	[3330] = { spellID = 50909, itemIDs = { 38376 } }, -- +18 Stamina | Heavy Borean Armor Kit | items: Heavy Borean Armor Kit
	[3331] = { spellID = 50911, itemIDs = { 38377 } }, -- +72 Stamina and +35 Agility | Dragonscale Leg Armor
	[3332] = { spellID = 50913, itemIDs = { 38378 } }, -- +100 Attack Power and +36 Critical Strike Rating | Wyrmscale Leg Armor | items: Wyrmscale Leg Armor
	[3365] = { spellID = 53323 }, -- Rune of Swordshattering
	[3366] = { spellID = 53331 }, -- Rune of Lichbane
	[3367] = { spellID = 53342 }, -- Rune of Spellshattering
	[3368] = { spellID = 53344 }, -- Rune of the Fallen Crusader
	[3369] = { spellID = 53341 }, -- Rune of Cinderglacier
	[3370] = { spellID = 53343 }, -- Rune of Razorice
	[3592] = { spellID = 28898, itemIDs = { 23123 } }, -- +100 Spell Power vs Undead | Blessed Wizard Oil | items: Blessed Wizard Oil
	[3594] = { spellID = 54446 }, -- Rune of Swordbreaking
	[3595] = { spellID = 54447 }, -- Rune of Spellbreaking
	[3597] = { itemIDs = { 40773 } }, -- Master Firestone | items: Master Firestone
	[3599] = { spellID = 54736 }, -- Electromagnetic Pulse Generator | Personal Electromagnetic Pulse Generator
	[3601] = { spellID = 54793 }, -- Frag Belt
	[3603] = { spellID = 54998 }, -- Hand-Mounted Pyro Rocket
	[3604] = { spellID = 54999 }, -- Hyperspeed Accelerators
	[3605] = { spellID = 55002 }, -- Flexweave Underlay
	[3606] = { spellID = 55016, itemIDs = { 41118 } }, -- Nitro Boosts
	[3607] = { spellID = 55076, itemIDs = { 41146 } }, -- +40 Ranged Haste Rating | Sun Scope | items: Sun Scope
	[3608] = { spellID = 55135, itemIDs = { 41167 } }, -- +40 Ranged Critical Strike | Heartseeker Scope | items: Heartseeker Scope
	[3609] = { itemIDs = { 41170 } }, -- Firestone | items: Firestone
	[3610] = { itemIDs = { 41169 } }, -- Firestone | items: Firestone
	[3611] = { itemIDs = { 41171 } }, -- Greater Firestone | items: Greater Firestone
	[3612] = { itemIDs = { 41172 } }, -- Major Firestone | items: Major Firestone
	[3613] = { itemIDs = { 41173 } }, -- Fel Firestone | items: Fel Firestone
	[3614] = { itemIDs = { 41174 } }, -- Grand Firestone | items: Grand Firestone
	[3717] = { spellID = 55628 }, -- Socket Bracer
	[3718] = { spellID = 55630, itemIDs = { 41601 } }, -- +35 Spell Power and +12 Spirit | Shining Spellthread | items: Shining Spellthread
	[3719] = { spellID = 55631, itemIDs = { 41602 } }, -- +50 Spell Power and +20 Spirit | Brilliant Spellthread | items: Brilliant Spellthread
	[3720] = { spellID = 29720, itemIDs = { 41603 } }, -- +35 Spell Power and +20 Stamina | Greater Ward of Shielding | items: Azure Spellthread
	[3721] = { spellID = 55634, itemIDs = { 41604 } }, -- +50 Spell Power and +30 Stamina | Sapphire Spellthread | items: Sapphire Spellthread
	[3722] = { spellID = 55642 }, -- Lightweave Embroidery
	[3723] = { spellID = 55641 }, -- Socket Gloves
	[3728] = { spellID = 55769 }, -- Darkglow Embroidery
	[3729] = { spellID = 55655, itemIDs = { 41611 } }, -- Socket Belt | Ebonsteel Belt Buckle | items: Eternal Belt Buckle
	[3730] = { spellID = 55777 }, -- Swordguard Embroidery
	[3731] = { spellID = 55836, itemIDs = { 41976 } }, -- Titanium Weapon Chain | items: Titanium Weapon Chain
	[3748] = { spellID = 56353, itemIDs = { 42500 } }, -- Titanium Spike (45-67) | Titanium Shield Spike | items: Titanium Shield Spike
	[3754] = { spellID = 24162, itemIDs = { 19785 } }, -- +24 Attack Power +10 Stamina +10 Hit Rating | Falcon's Call | items: Falcon's Call
	[3755] = { spellID = 24161, itemIDs = { 19784 } }, -- +28 Attack Power +12 Dodge Rating | Death's Embrace | items: Death's Embrace
	[3756] = { spellID = 57683 }, -- +130 Attack Power | Fur Lining - Attack Power
	[3757] = { spellID = 57690 }, -- +102 Stamina | Fur Lining - Stamina
	[3758] = { spellID = 57691 }, -- +76 Spell Power | Fur Lining - Spell Power
	[3775] = { spellID = 58126, itemIDs = { 43302 } }, -- +30 Spell Power and +15 Critical Strike Rating | Inscription of High Discipline
	[3776] = { itemIDs = { 43303 } }, -- +45 Attack Power and +15 Critical Strike Rating | Inscription of the Frostblade
	[3777] = { spellID = 58129, itemIDs = { 43304 } }, -- +20 Defense and +15 Dodge Rating | Inscription of Kings
	[3788] = { spellID = 59619 }, -- +25 Hit Rating and +25 Critical Strike Rating | Enchant Weapon - Accuracy
	[3789] = { spellID = 59621 }, -- Berserking | Enchant Weapon - Berserking
	[3790] = { spellID = 59625 }, -- Black Magic | Enchant Weapon - Black Magic
	[3791] = { spellID = 59636 }, -- +30 Stamina | Enchant Ring - Stamina
	[3793] = { spellID = 59771, itemIDs = { 44067 } }, -- +40 Attack Power and +15 Resilience Rating | Inscription of Triumph | items: Inscription of Triumph
	[3794] = { spellID = 59773, itemIDs = { 44068 } }, -- +23 Spell Power and +15 Resilience Rating | Inscription of Dominance | items: Inscription of Dominance
	[3795] = { spellID = 59777, itemIDs = { 44069 } }, -- +50 Attack Power and +20 Resilience Rating | Arcanum of Triumph | items: Arcanum of Triumph
	[3797] = { spellID = 59784, itemIDs = { 44075 } }, -- +29 Spell Power and +20 Resilience Rating | Arcanum of Dominance | items: Arcanum of Dominance
	[3806] = { spellID = 59927, itemIDs = { 44129 } }, -- +18 Spell Power and +10 Critical Strike Rating | Inscription of the Storm | items: Lesser Inscription of the Storm
	[3807] = { spellID = 59928, itemIDs = { 44130 } }, -- +15 Intellect and +10 Spirit | Inscription of the Crag | items: Lesser Inscription of the Crag
	[3808] = { spellID = 59934, itemIDs = { 44133 } }, -- +40 Attack Power and +15 Crit Rating | Greater Inscription of the Axe | items: Greater Inscription of the Axe
	[3809] = { spellID = 59936, itemIDs = { 44134 } }, -- +21 Intellect and +16 Spirit | Greater Inscription of the Crag | items: Greater Inscription of the Crag
	[3810] = { spellID = 59937, itemIDs = { 44135 } }, -- +24 Spell Power and +15 Critical Strike Rating | Greater Inscription of the Storm | items: Greater Inscription of the Storm
	[3811] = { spellID = 59941, itemIDs = { 44136 } }, -- +20 Dodge Rating and +22 Stamina | Greater Inscription of the Pinnacle | items: Greater Inscription of the Pinnacle
	[3817] = { spellID = 59954, itemIDs = { 50367 } }, -- +50 Attack Power and +20 Critical Strike Rating | Arcanum of Torment | items: Arcanum of Torment
	[3818] = { spellID = 59955, itemIDs = { 44150, 50369 } }, -- +37 Stamina and +20 Dodge Rating | Arcanum of the Stalwart Protector | items: Arcanum of the Stalwart Protector / Arcanum of the Stalwart Protector
	[3819] = { spellID = 59960, itemIDs = { 44152, 50370 } }, -- +26 Intellect and +20 Spirit | Arcanum of Blissful Mending | items: Arcanum of Blissful Mending / Arcanum of Blissful Mending
	[3820] = { spellID = 59970, itemIDs = { 44159, 50368 } }, -- +26 Intellect and 20 Critical strike rating | Arcanum of Burning Mysteries | items: Arcanum of Burning Mysteries / Arcanum of Burning Mysteries
	[3822] = { spellID = 60581, itemIDs = { 38373 } }, -- +55 Stamina and +22 Agility | Frosthide Leg Armor | items: Frosthide Leg Armor
	[3823] = { spellID = 60582, itemIDs = { 38374 } }, -- +75 Attack Power and +22 Critical Strike Rating | Icescale Leg Armor | items: Icescale Leg Armor
	[3824] = { spellID = 60606 }, -- +24 Attack Power | Enchant Boots - Assault
	[3825] = { spellID = 60609 }, -- +15 Haste Rating | Enchant Cloak - Speed
	[3826] = { spellID = 60623 }, -- +12 Hit Rating and +12 Critical Strike Rating | Enchant Boots - Icewalker
	[3827] = { spellID = 60691 }, -- +110 Attack Power | Enchant 2H Weapon - Massacre
	[3828] = { spellID = 44630 }, -- +85 Attack Power | Enchant 2H Weapon - Greater Savagery
	[3829] = { spellID = 44513 }, -- +35 Attack Power | Enchant Gloves - Greater Assault
	[3830] = { spellID = 44629 }, -- +50 Spell Power | Enchant Weapon - Exceptional Spellpower
	[3831] = { spellID = 47898 }, -- +23 Haste Rating | Enchant Cloak - Greater Speed
	[3832] = { spellID = 60692 }, -- +10 All Stats | Enchant Chest - Powerful Stats
	[3833] = { spellID = 60707 }, -- +65 Attack Power | Enchant Weapon - Superior Potency
	[3834] = { spellID = 60714 }, -- +63 Spell Power | Enchant Weapon - Mighty Spellpower
	[3835] = { spellID = 61117 }, -- +120 Attack Power and +15 Crit Rating | Master's Inscription of the Axe
	[3836] = { spellID = 61118 }, -- +60 Intellect and +15 Spirit | Master's Inscription of the Crag
	[3837] = { spellID = 61119 }, -- +60 Dodge Rating and +15 Parry Rating | Master's Inscription of the Pinnacle
	[3838] = { spellID = 61120 }, -- +70 Spell Power and +15 Crit Rating | Master's Inscription of the Storm
	[3839] = { spellID = 44645 }, -- +40 Attack Power | Enchant Ring - Assault
	[3840] = { spellID = 44636 }, -- +23 Spell Power | Enchant Ring - Greater Spellpower
	[3842] = { spellID = 61271, itemIDs = { 44701, 44702, 50372, 50373 } }, -- +30 Stamina and +25 Resilience Rating | Arcanum of the Savage Gladiator | items: Arcanum of the Savage Gladiator / Arcanum of the Savage Gladiator
	[3843] = { spellID = 61468, itemIDs = { 44739 } }, -- Scope (+15 Damage) | Diamond-cut Refractor Scope | items: Diamond-Cut Refractor Scope
	[3844] = { spellID = 44510 }, -- +45 Spirit | Enchant Weapon - Exceptional Spirit
	[3845] = { spellID = 44575 }, -- +50 Attack Power | Enchant Bracer - Greater Assault
	[3846] = { spellID = 34010 }, -- +40 Spell Power | Enchant Weapon - Major Healing
	[3847] = { spellID = 62158 }, -- Rune of the Stoneskin Gargoyle
	[3849] = { spellID = 62201, itemIDs = { 44936 } }, -- Titanium Plating | items: Titanium Plating
	[3850] = { spellID = 62256 }, -- +40 Stamina | Enchant Bracer - Major Stamina
	[3851] = { spellID = 62257 }, -- +50 Stamina | Enchant Weapon - Titanguard
	[3852] = { spellID = 62384, itemIDs = { 44957 } }, -- +30 Stamina and +15 Resilience Rating | Greater Inscription of the Gladiator | items: Greater Inscription of the Gladiator
	[3853] = { spellID = 62447, itemIDs = { 44963 } }, -- +40 Resilience Rating and +28 Stamina | Earthen Leg Armor | items: Earthen Leg Armor
	[3854] = { spellID = 62948 }, -- +81 Spell Power | Enchant Staff - Greater Spellpower
	[3855] = { spellID = 62959 }, -- +69 Spell Power | Enchant Staff - Spellpower
	[3858] = { spellID = 63746 }, -- +5 Hit Rating | Enchant Boots - Lesser Accuracy
	[3859] = { spellID = 63765 }, -- Springy Arachnoweave
	[3860] = { spellID = 63770 }, -- Reticulated Armor Webbing
	[3868] = { spellID = 64401, itemIDs = { 46006 } }, -- Fishing Lure (+100 Fishing Skill) | Glow Worm | items: Glow Worm
	[3869] = { spellID = 64441 }, -- Blade Ward | Enchant Weapon - Blade Ward
	[3870] = { spellID = 64579 }, -- Blood Draining | Enchant Weapon - Blood Draining
	[3872] = { spellID = 56039 }, -- +50 Spell Power and +20 Spirit | Sanctified Spellthread
	[3873] = { spellID = 56034 }, -- +50 Spell Power and +30 Stamina | Master's Spellthread
	[3875] = { spellID = 59929, itemIDs = { 44131 } }, -- +30 Attack Power and +10 Critical Strike Rating | Inscription of the Axe | items: Lesser Inscription of the Axe
	[3876] = { spellID = 59932, itemIDs = { 44132 } }, -- +15 Dodge Rating and +10 Parry Rating | Inscription of the Pinnacle | items: Lesser Inscription of the Pinnacle
	[3878] = { spellID = 67839 }, -- Mind Amplification Dish
	[3883] = { spellID = 70164 }, -- Rune of the Nerubian Carapace

	------------------------------------------------------------
	--# Cata 4.4.x
	------------------------------------------------------------
	[4061] = { spellID = 74132 }, -- +50 Mastery Rating | Enchant Gloves - Mastery
	[4062] = { spellID = 74189 }, -- +30 Stamina and Minor Movement Speed | Enchant Boots - Earthen Vitality
	[4063] = { spellID = 74191 }, -- +15 All Stats | Enchant Chest - Mighty Stats
	[4064] = { spellID = 74192 }, -- +70 Spell Penetration | Enchant Cloak - Greater Spell Piercing
	[4065] = { spellID = 74193 }, -- +50 Haste Rating | Enchant Bracer - Speed
	[4066] = { spellID = 74195 }, -- Mending | Enchant Weapon - Mending
	[4067] = { spellID = 74197 }, -- Avalanche | Enchant Weapon - Avalanche
	[4068] = { spellID = 74198 }, -- +50 Haste Rating | Enchant Gloves - Haste
	[4069] = { spellID = 74199 }, -- +50 Haste Rating | Enchant Boots - Haste
	[4070] = { spellID = 74200 }, -- +55 Stamina | Enchant Chest - Stamina
	[4071] = { spellID = 74201 }, -- +50 Critical Strike Rating | Enchant Bracer - Critical Strike
	[4072] = { spellID = 74202 }, -- +30 Intellect | Enchant Cloak - Intellect
	[4073] = { spellID = 74207 }, -- +160 Armor | Enchant Shield - Protection
	[4074] = { spellID = 74211 }, -- Elemental Slayer | Enchant Weapon - Elemental Slayer
	[4075] = { spellID = 74212 }, -- +35 Strength | Enchant Gloves - Exceptional Strength
	[4076] = { spellID = 74213 }, -- +35 Agility | Enchant Boots - Major Agility
	[4077] = { spellID = 74214 }, -- +40 Resilience Rating | Enchant Chest - Mighty Resilience
	[4078] = { spellID = 74215 }, -- +40 Strength | Enchant Ring - Strength
	[4079] = { spellID = 74216 }, -- +40 Agility | Enchant Ring - Agility
	[4080] = { spellID = 74217 }, -- +40 Intellect | Enchant Ring - Intellect
	[4081] = { spellID = 74218 }, -- +60 Stamina | Enchant Ring - Greater Stamina
	[4082] = { spellID = 74220 }, -- +50 Expertise Rating | Enchant Gloves - Greater Expertise
	[4083] = { spellID = 74223 }, -- Hurricane | Enchant Weapon - Hurricane
	[4084] = { spellID = 74225 }, -- Heartsong | Enchant Weapon - Heartsong
	[4085] = { spellID = 74226 }, -- +50 Mastery Rating | Enchant Shield - Mastery
	[4086] = { spellID = 74229 }, -- +50 Dodge Rating | Enchant Bracer - Superior Dodge
	[4087] = { spellID = 74230 }, -- +50 Critical Strike Rating | Enchant Cloak - Critical Strike
	[4088] = { spellID = 74231 }, -- +40 Spirit | Enchant Chest - Exceptional Spirit
	[4089] = { spellID = 74232 }, -- +50 Hit Rating | Enchant Bracer - Precision
	[4090] = { spellID = 74234 }, -- +250 Armor | Enchant Cloak - Protection
	[4091] = { spellID = 74235 }, -- +40 Intellect | Enchant Off-Hand - Superior Intellect
	[4092] = { spellID = 74236 }, -- +50 Hit Rating | Enchant Boots - Precision
	[4093] = { spellID = 74237 }, -- +50 Spirit | Enchant Bracer - Exceptional Spirit
	[4094] = { spellID = 74238 }, -- +50 Mastery Rating | Enchant Boots - Mastery
	[4095] = { spellID = 74239 }, -- +50 Expertise Rating | Enchant Bracer - Greater Expertise
	[4096] = { spellID = 74240 }, -- +50 Intellect | Enchant Cloak - Greater Intellect
	[4097] = { spellID = 74242 }, -- Power Torrent | Enchant Weapon - Power Torrent
	[4098] = { spellID = 74244 }, -- Windwalk | Enchant Weapon - Windwalk
	[4099] = { spellID = 74246 }, -- Landslide | Enchant Weapon - Landslide
	[4100] = { spellID = 74247 }, -- +65 Critical Strike Rating | Enchant Cloak - Greater Critical Strike
	[4101] = { spellID = 74248 }, -- +65 Critical Strike Rating | Enchant Bracer - Greater Critical Strike
	[4102] = { spellID = 74250 }, -- +20 All Stats | Enchant Chest - Peerless Stats
	[4103] = { spellID = 74251 }, -- +75 Stamina | Enchant Chest - Greater Stamina
	[4104] = { spellID = 74253 }, -- +35 Mastery Rating and Minor Movement Speed | Enchant Boots - Lavawalker
	[4105] = { spellID = 74252 }, -- +25 Agility and Minor Movement Speed | Enchant Boots - Assassin's Step
	[4106] = { spellID = 74254 }, -- +50 Strength | Enchant Gloves - Mighty Strength
	[4107] = { spellID = 74255 }, -- +65 Mastery Rating | Enchant Gloves - Greater Mastery
	[4108] = { spellID = 74256 }, -- +65 Haste Rating | Enchant Bracer - Greater Speed
	[4109] = { spellID = 75149, itemIDs = { 54449 } }, -- +55 Intellect and +45 Spirit | Ghostly Spellthread | items: Ghostly Spellthread
	[4110] = { spellID = 75310, itemIDs = { 54450 } }, -- +95 Intellect and +55 Spirit | Powerful Ghostly Spellthread | items: Powerful Ghostly Spellthread
	[4111] = { spellID = 75250 }, -- +55 Intellect and +65 Stamina | Enchanted Spellthread
	[4112] = { spellID = 75309 }, -- +95 Intellect and +80 Stamina | Powerful Enchanted Spellthread
	[4113] = { spellID = 75154 }, -- +95 Intellect and +80 Stamina | Master's Spellthread
	[4114] = { spellID = 75155 }, -- +95 Intellect and +55 Spirit | Sanctified Spellthread
	[4115] = { spellID = 75172 }, -- Lightweave Embroidery
	[4116] = { spellID = 75175 }, -- Darkglow Embroidery
	[4118] = { spellID = 75178 }, -- Swordguard Embroidery
	[4120] = { spellID = 78165, itemIDs = { 56477 } }, -- +36 Stamina | Savage Armor Kit | items: Savage Armor Kit
	[4121] = { spellID = 78166, itemIDs = { 56517 } }, -- +44 Stamina | Heavy Savage Armor Kit | items: Heavy Savage Armor Kit
	[4122] = { spellID = 78169, itemIDs = { 56502 } }, -- +110 Attack Power and +45 Critical Strike Rating | Scorched Leg Armor | items: Scorched Leg Armor
	[4124] = { spellID = 78170, itemIDs = { 56503 } }, -- +85 Stamina and +45 Agility | Twilight Leg Armor | items: Twilight Leg Armor
	[4126] = { spellID = 78171 }, -- +190 Attack Power and +55 Critical Strike Rating | Dragonscale Leg Armor
	[4127] = { spellID = 78172, itemIDs = { 56551 } }, -- +145 Stamina and +55 Agility | Charscale Leg Armor | items: Charscale Leg Armor
	[4175] = { spellID = 81932, itemIDs = { 59594 } }, -- Gnomish X-Ray Scope | items: Gnomish X-Ray Scope
	[4176] = { spellID = 84408 }, -- +88 Ranged Hit Rating | R19 Threatfinder
	[4177] = { spellID = 84410 }, -- +88 Ranged Haste Rating | Safety Catch Removal Kit
	[4179] = { spellID = 82175 }, -- Synapse Springs
	[4180] = { spellID = 82177 }, -- Quickflip Deflection Plates
	[4181] = { spellID = 82180 }, -- Tazik Shocker
	[4182] = { spellID = 82200 }, -- Spinal Healing Injector
	[4183] = { spellID = 82201 }, -- Z50 Mana Gulper
	[4187] = { spellID = 84424 }, -- Invisibility Field
	[4188] = { spellID = 84427 }, -- Grounded Plasma Shield
	[4189] = { spellID = 85007 }, -- +195 Stamina | Draconic Embossment - Stamina
	[4190] = { spellID = 85008 }, -- +130 Agility | Draconic Embossment - Agility
	[4191] = { spellID = 85009 }, -- +130 Strength | Draconic Embossment - Strength
	[4192] = { spellID = 85010 }, -- +130 Intellect | Draconic Embossment - Intellect
	[4193] = { spellID = 86375 }, -- +130 Agility and +25 Mastery Rating | Swiftsteel Inscription
	[4194] = { spellID = 86401 }, -- +130 Strength and +25 Critical Strike Rating | Lionsmane Inscription
	[4195] = { spellID = 86402 }, -- +195 Stamina and +25 Dodge Rating | Inscription of the Earth Prince
	[4196] = { spellID = 86403 }, -- +130 Intellect and +25 Haste Rating | Felfire Inscription
	[4197] = { spellID = 86847, itemIDs = { 62321 } }, -- +45 Stamina and +20 Dodge Rating | Inscription of Unbreakable Quartz | items: Lesser Inscription of Unbreakable Quartz
	[4198] = { spellID = 86854, itemIDs = { 68717 } }, -- +75 Stamina and +25 Dodge Rating | Greater Inscription of Unbreakable Quartz | items: Greater Inscription of Unbreakable Quartz
	[4199] = { spellID = 86898, itemIDs = { 62342 } }, -- +30 Intellect and +20 Haste Rating | Inscription of Charged Lodestone | items: Lesser Inscription of Charged Lodestone
	[4200] = { spellID = 86899, itemIDs = { 68715 } }, -- +50 Intellect and +25 Haste Rating | Greater Inscription of Charged Lodestone | items: Greater Inscription of Charged Lodestone
	[4201] = { spellID = 86900, itemIDs = { 62344 } }, -- +30 Strength and +20 Critical Strike Rating | Inscription of Jagged Stone | items: Lesser Inscription of Jagged Stone
	[4202] = { spellID = 86901, itemIDs = { 68716 } }, -- +50 Strength and +25 Critical Strike Rating | Greater Inscription of Jagged Stone | items: Greater Inscription of Jagged Stone
	[4204] = { spellID = 86907, itemIDs = { 68714 } }, -- +50 Agility and +25 Mastery Rating | Greater Inscription of Shattered Crystal | items: Greater Inscription of Shattered Crystal
	[4205] = { spellID = 86909, itemIDs = { 62347 } }, -- +30 Agility and +20 Mastery Rating | Inscription of Shattered Crystal | items: Lesser Inscription of Shattered Crystal
	[4206] = { spellID = 86931, itemIDs = { 62366 } }, -- +90 Stamina and 35 Dodge rating | Arcanum of the Earthern Ring | items: Arcanum of the Earthen Ring
	[4207] = { spellID = 86932, itemIDs = { 62367 } }, -- +60 Intellect and 35 Critical Strike rating | Arcanum of Hyjal | items: Arcanum of Hyjal
	[4208] = { spellID = 86933, itemIDs = { 62422 } }, -- +60 Strength and 35 mastery rating | Arcanum of the Highlands | items: Arcanum of the Wildhammer
	[4209] = { spellID = 86934, itemIDs = { 62369 } }, -- +60 Agility and 35 Haste rating | Arcanum of Ramkahen | items: Arcanum of the Ramkahen
	[4214] = { spellID = 84425 }, -- Cardboard Assassin
	[4215] = { spellID = 76441 }, -- Elementium Spike (90-133) | Elementium Shield Spike
	[4216] = { spellID = 76440 }, -- Pyrium Spike (210-350) | Pyrium Shield Spike
	[4217] = { spellID = 76442 }, -- Pyrium Weapon Chain
	[4222] = { spellID = 67839 }, -- Mind Amplification Dish
	[4223] = { spellID = 55016 }, -- Nitro Boosts
	[4227] = { spellID = 95471 }, -- +130 Agility | Enchant 2H Weapon - Mighty Agility
	[4245] = { spellID = 96245, itemIDs = { 68770 } }, -- +60 Intellect and 35 Resilience rating | Arcanum of Vicious Intellect | items: Arcanum of Vicious Intellect
	[4246] = { spellID = 96246, itemIDs = { 68769 } }, -- +60 Agility and 35 Resilience rating | Arcanum of Vicious Agility | items: Arcanum of Vicious Agility
	[4247] = { spellID = 96247, itemIDs = { 68768 } }, -- +60 Strength and 35 Resilience rating | Arcanum of Vicious Strength | items: Arcanum of Vicious Strength
	[4248] = { spellID = 96249, itemIDs = { 68772 } }, -- +50 Intellect and +25 Resilience Rating | Greater Inscription of Vicious Intellect | items: Greater Inscription of Vicious Intellect
	[4249] = { spellID = 96250, itemIDs = { 68773 } }, -- +50 Strength and +25 Resilience Rating | Greater Inscription of Vicious Strength | items: Greater Inscription of Vicious Strength
	[4250] = { spellID = 96251, itemIDs = { 68774, 68815 } }, -- +50 Agility and +25 Resilience Rating | Greater Inscription of Vicious Agility | items: Greater Inscription of Vicious Agility / Greater Inscription of Vicious Sententiousness
	[4256] = { spellID = 96261 }, -- +50 Strength | Enchant Bracer - Major Strength
	[4257] = { spellID = 96262 }, -- +50 Intellect | Enchant Bracer - Mighty Intellect
	[4258] = { spellID = 96264 }, -- +50 Agility | Enchant Bracer - Agility
	[4267] = { spellID = 99623 }, -- Flintlocke's Woodchucker
	[4270] = { spellID = 101598, itemIDs = { 71720 } }, -- +145 Stamina and +55 Dodge Rating | Drakehide Leg Armor | items: Drakehide Leg Armor

	------------------------------------------------------------
	--# MoP 5.5.x
	------------------------------------------------------------
	--[[
	[4359] = { spellID = 103461 },
	[4360] = { spellID = 103462 },
	[4361] = { spellID = 103463 },
	[4411] = { spellID = 104338 },
	[4412] = { spellID = 104385 },
	[4414] = { spellID = 104389 },
	[4415] = { spellID = 104390 },
	[4416] = { spellID = 104391 },
	[4417] = { spellID = 104392 },
	[4418] = { spellID = 104393 },
	[4419] = { spellID = 104395 },
	[4420] = { spellID = 104397 },
	[4421] = { spellID = 104398 },
	[4422] = { spellID = 104401 },
	[4423] = { spellID = 104403 },
	[4424] = { spellID = 104404 },
	[4426] = { spellID = 104407 },
	[4427] = { spellID = 104408 },
	[4428] = { spellID = 104409 },
	[4429] = { spellID = 104414 },
	[4430] = { spellID = 104416 },
	[4431] = { spellID = 104417 },
	[4432] = { spellID = 104419 },
	[4433] = { spellID = 104420 },
	[4434] = { spellID = 104445 },
	[4440] = { spellID = 78171 }, -- +190 Attack Power and +55 Critical Strike Rating | Dragonscale Leg Armor
	[4441] = { spellID = 104425 },
	[4442] = { spellID = 104427 },
	[4443] = { spellID = 104430 },
	[4444] = { spellID = 104434 },
	[4445] = { spellID = 104440 },
	[4446] = { spellID = 104442 },
	[4697] = { spellID = 108789 },
	[4698] = { spellID = 109077 },
	[4699] = { itemIDs = { 77529 } },
	[4700] = { itemIDs = { 77531 } },
	[4717] = { spellID = 110764 },
	[4732] = { spellID = 71692 }, -- Enchant Gloves - Angler
	[4803] = { spellID = 121192 },
	[4804] = { spellID = 121193 },
	[4805] = { spellID = 121194 },
	[4806] = { spellID = 121195 },
	[4807] = { spellID = 103465 },
	[4822] = { itemIDs = { 83764 } },
	[4823] = { itemIDs = { 83765 } },
	[4824] = { itemIDs = { 83763 } },
	[4825] = { itemIDs = { 82445 } },
	[4826] = { itemIDs = { 82444 } },
	[4869] = { itemIDs = { 85559 } },
	[4870] = { itemIDs = { 85570 } },
	[4871] = { itemIDs = { 85569 } },
	[4872] = { itemIDs = { 85568 } },
	[4873] = { spellID = 57683 }, -- Fur Lining - Attack Power
	[4875] = { spellID = 124551 },
	[4877] = { spellID = 124552 },
	[4878] = { spellID = 124553 },
	[4879] = { spellID = 124554 },
	[4880] = { spellID = 124559, itemIDs = { 83764 } },
	[4881] = { spellID = 124561 },
	[4882] = { spellID = 124563 },
	[4892] = { spellID = 125481 },
	[4893] = { spellID = 125482 },
	[4894] = { spellID = 125483 },
	[4895] = { spellID = 125496 },
	[4896] = { spellID = 125497 },
	[4897] = { spellID = 126392 },
	[4898] = { spellID = 126731 },
	[4907] = { spellID = 127015 },
	[4908] = { spellID = 127014 },
	[4909] = { spellID = 127013 },
	[4910] = { spellID = 127012 },
	[4912] = { spellID = 113048 },
	[4913] = { spellID = 113047 },
	[4914] = { spellID = 113046 },
	[4915] = { spellID = 113045 },
	[4916] = { spellID = 113044 },
	[4918] = { itemIDs = { 86597 } },
	[4992] = { spellID = 130749 },
	[4993] = { spellID = 130758 },
	[5000] = { spellID = 109099 },
	[5001] = { itemIDs = { 86599 } },
	[5002] = { spellID = 131467, itemIDs = { 90046 } },
	[5003] = { itemIDs = { 82443 } },
	[5004] = { itemIDs = { 82442 } },
	[5275] = { itemIDs = { 109120 } },
	[5276] = { itemIDs = { 109122 } },
	[5281] = { spellID = 158877 },
	[5284] = { spellID = 158907 },
	[5285] = { spellID = 158892 },
	[5292] = { spellID = 158893 },
	[5293] = { spellID = 158894 },
	[5294] = { spellID = 158895 },
	[5295] = { spellID = 158896 },
	[5297] = { spellID = 158908 },
	[5298] = { spellID = 158878 },
	[5299] = { spellID = 158909 },
	[5300] = { spellID = 158879 },
	[5301] = { spellID = 158910 },
	[5302] = { spellID = 158880 },
	[5303] = { spellID = 158911 },
	[5304] = { spellID = 158881 },
	[5310] = { spellID = 158884 },
	[5311] = { spellID = 158885 },
	[5312] = { spellID = 158886 },
	[5313] = { spellID = 158887 },
	[5314] = { spellID = 158889 },
	[5317] = { spellID = 158899 },
	[5318] = { spellID = 158900 },
	[5319] = { spellID = 158901 },
	[5320] = { spellID = 158902 },
	[5321] = { spellID = 158903 },
	[5324] = { spellID = 158914 },
	[5325] = { spellID = 158915 },
	[5326] = { spellID = 158916 },
	[5327] = { spellID = 158917 },
	[5328] = { spellID = 158918 },
	[5330] = { spellID = 159235 },
	[5331] = { spellID = 159236 },
	[5334] = { spellID = 159672 },
	[5335] = { spellID = 159673 },
	[5336] = { spellID = 159674 },
	[5337] = { spellID = 159671 },
	[5352] = { spellID = 170627 },
	[5353] = { spellID = 170628 },
	[5354] = { spellID = 170629 },
	[5355] = { spellID = 170630 },
	[5356] = { spellID = 170631 },
	[5383] = { itemIDs = { 118008 } },
	[5384] = { spellID = 173323 },
	[5394] = { spellID = 175165 },
	[5396] = { spellID = 178308 },
	[5397] = { spellID = 178309 },
	]]
};