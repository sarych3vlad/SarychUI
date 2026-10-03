local E, L = select(2, ...):unpack()

do
	L["Looking for Dungeon"] = DUNGEONS_BUTTON
	L["Skirmish"] = ARENA_CASUAL
	L["Arena"] = ARENA
	L["Battlegrounds"] = BATTLEGROUNDS
	L["Dungeons"] = BUG_CATEGORY3
	L["Outdoor Zones"] = BUG_CATEGORY2
	L["Trinket"] = INVTYPE_TRINKET
	L["Interrupt"] = INTERRUPT
	L["Dispels"] = DISPELS
	L["Other"] = OTHER
	L["PvP Trinket"] = GetSpellInfo(42292) or GetSpellInfo(283167) or L["PvP Trinket"]
	L["Racial Traits"] = type(RACIAL_TRAITS) == "string" and gsub(RACIAL_TRAITS, ":", "") or L["Racial Traits"]
	L["Disrm, Root, Silence"] = format("%s, %s, %s", L["Disarm"], L["Root"], L["Silence"])
	L["Main Hand"] = INVTYPE_WEAPONMAINHAND
	L["Trinket, Main Hand"] = format("%s, %s, %s", L["Trinket"], L["Main Hand"], L["Consumables"])
	L["Max"] = MAXIMUM
	L["Spells"] = type(SPELLS) == "string" and SPELLS or L["Spells"]
	L["Highlighting"] = HIGHLIGHTING:gsub(":", "")
	L["Custom"] = CUSTOM
end

E.L_CFG_ZONE = {
	["arena"] = L["Arena"],
	["pvp"] = L["Battlegrounds"],
	["party"] = L["Dungeons"],
	["raid"] = L["Raids"],
}

E.L_ALL_ZONE = {
	["arena"] = L["Arena"],
	["pvp"] = L["Battlegrounds"],
	["party"] = L["Dungeons"],
	["raid"] = L["Raids"],
	["scenario"] = L["Scenarios"],
	["none"] = L["Outdoor Zones"],
}

E.L_PRIORITY = {
	["pvptrinket"] = L["PvP Trinket"],
	["racial"] = L["Racial Traits"],
	["interrupt"] = L["Interrupt"],
	["dispel"] = L["Dispels"],
	["cc"] = L["Hard CC"],
	["aoeCC"] = L["AOE CC"],
	["disarm"] = L["Soft CC"],
	["immunity"] = L["Immunity"],
	["defensive"] = L["Defensive"],
	["tankDefensive"] = L["Tank Defensive"],
	["externalDefensive"] = L["External Defensive"],
	["raidDefensive"] = L["Raid Defensive"],
	["heal"] = L["Heal"],
	["offensive"] = L["Offensive"],
	["counterCC"] = L["Counter CC"],
	["freedom"] = L["Freedom"],
	["movement"] = L["Movement"],
	["raidMovement"] = L["Raid Movement"],
	["other"] = L["Other"],
	["taunt"] = L["Taunt"],
	["trinket"] = L["Trinket"],
	["consumable"] = L["Consumables"],
	["custom1"] = L["Custom"] .. 1,
	["custom2"] = L["Custom"] .. 2,
}

E.L_HIGHLIGHTS = {
	["racial"] = L["Racial Traits"],
	["immunity"] = L["Immunity"],
	["defensive"] = L["Defensive"],
	["tankDefensive"] = L["Tank Defensive"],
	["externalDefensive"] = L["External Defensive"],
	["raidDefensive"] = L["Raid Defensive"],
	["heal"] = L["Heal"],
	["offensive"] = L["Offensive"],
	["counterCC"] = L["Counter CC"],
	["freedom"] = L["Freedom"],
	["movement"] = L["Movement"],
	["raidMovement"] = L["Raid Movement"],
	["other"] = L["Other"],
	["trinket"] = L["Trinket"],
}

E.TEXTURES = {
	["White8x8"] = "Interface\\BUTTONS\\White8x8",
	["CLASS"] = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
	["PVPTRINKET"] = "Interface\\Icons\\inv_jewelry_trinketpvp_01",
	["RACIAL"] = "Interface\\Icons\\achievement_character_troll_male",
	["TRINKET"] = "Interface\\Icons\\inv_misc_armorkit_10",
}

E.BORDERLESS_TCOORDS = { 0.07, 0.93, 0.07, 0.93 }

E.STR = {
	["RELOAD_UI"] = L["Reload UI?"],
	["UNSUPPORTED_ADDON"] = L["Raid Frames for testing doesn't exist for %s. If it fails to load, configure OmniCD while in a group or temporarily set it to \'Manual Mode\'."],
	["MAX_RANGE"] = L["Max"] .. ": 999",
	["MAX_RANGE_3600"] = L["Max"] .. ": 3600",
	["WHATS_NEW_ESCSEQ"] = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t ",
}

E.HEX_C = {
	[1] = "|cff99cdff",
	[2] = "|cff0291b0",
	[5] = "|cff7bbb4e",
	[11] = "|cff99cdff",
	[14] = "|cffA63416",
	["CURSE_ORANGE"] = "|cfff16436",
	["TWITCH_PURPLE"] = "|cff9146ff",
}

E.BOOKTYPE_CATEGORY = {
	["WARRIOR"] = 1,
	["PALADIN"] = 2,
	["HUNTER"] = 3,
	["ROGUE"] = 4,
	["PRIEST"] = 5,
	["DEATHKNIGHT"] = 6,
	["SHAMAN"] = 7,
	["MAGE"] = 8,
	["WARLOCK"] = 9,
	["DRUID"] = 11,

}

E.OTHER_SORT_ORDER = {
	["PVPTRINKET"] = L["PvP Trinket"],
	["RACIAL"] = L["Racial Traits"],
	["TRINKET"] = L["Trinket, Main Hand"],
	["CONSUMABLE"] = L["Consumables"],
}

E.BLANK = {}
