-- Shared ability presets for allies and arena opponents.
local Data = SarychUI.Data
Data.PartyAbilities = Data.PartyAbilities or {}
-- Spell list: ATT preset estimates and talent tabs, then IDs that only PAB has.
-- Entry: {spellID, cooldown, talentTab, talentIndex, faction, race, excludeRace, icon}
Data.PartyAbilities.presets = {
	DRUID = {
		{29166, 180}, -- Innervate
		{22812, 60}, -- Barkskin
		{8983, 60}, -- Bash
		{53201, 60, 1, 28}, -- Starfall
		{50334, 180, 2, 30}, -- Berserk
		{61336, 180, 2, 7}, -- Survival Instincts
		{16979, 15, 2, 14}, -- Feral Charge - Bear
		{17116, 180, 3, 12}, -- Nature's Swiftness
		{18562, 13, 3, 18}, -- Swiftmend
	},
	HUNTER = {
		{14311, 28}, -- Freezing Trap
		{60192, 28}, -- Freezing Arrow
		{13809, 28}, -- Frost Trap
		{19263, 90}, -- Deterrence
		{67481, 60}, -- Roar of Sacrifice
		{53271, 60}, -- Master's Call
		{19574, 120, 1, 18}, -- Bestial Wrath
		{34490, 20, 2, 24}, -- Silencing Shot
		{23989, 180, 2, 14}, -- Readiness
		{19503, 30, 3, 9}, -- Scatter Shot
		{49012, 30, 3, 20}, -- Wyvern Sting
	},
	MAGE = {
		{1953, 15}, -- Blink
		{2139, 24}, -- Counterspell
		{12051, 240}, -- Evocation
		{45438, 300}, -- Ice Block
		{44572, 30, 3, 28}, -- Deep Freeze
		{11958, 384, 3, 14}, -- Cold Snap
		{11129, 120, 2, 20}, -- Combustion
		{42950, 20, 2, 25}, -- Dragon's Breath
		{12043, 60, 1, 16}, -- Presence of Mind
	},
	PALADIN = {
		{10308, 40}, -- Hammer of Justice
		{1044, 25}, -- Hand of Freedom
		{54428, 60}, -- Divine Plea
		{6940, 120}, -- Hand of Sacrifice
		{10278, 180}, -- Hand of Protection
		{642, 300}, -- Divine Shield
		{31821, 120, 1, 6}, -- Aura Mastery
		{48825, 5, 1, 18}, -- Holy Shock
		{64205, 120, 2, 6}, -- Divine Sacrifice
		{48827, 30, 2, 22}, -- Avenger's Shield
		{66008, 60, 3, 18}, -- Repentance
	},
	PRIEST = {
		{10890, 27}, -- Psychic Scream
		{48158, 12}, -- Shadow Word: Death
		{34433, 300}, -- Shadowfiend
		{6346, 180}, -- Fear Ward
		{33206, 144, 1, 25}, -- Pain Suppression
		{47585, 75, 3, 27}, -- Dispersion
		{15487, 45, 3, 13}, -- Silence
		{64044, 120, 3, 23}, -- Psychic Horror
	},
	ROGUE = {
		{1766, 10}, -- Kick
		{8643, 20}, -- Kidney Shot
		{31224, 60}, -- Cloak of Shadows
		{51722, 60}, -- Dismantle
		{2094, 120}, -- Blind
		{26889, 120}, -- Vanish
		{14177, 180, 1, 13}, -- Cold Blood
		{51690, 120, 2, 28}, -- Killing Spree
		{14185, 300, 3, 14}, -- Preparation
		{51713, 60, 3, 28}, -- Shadow Dance
		{36554, 20, 3, 25}, -- Shadowstep
	},
	SHAMAN = {
		{57994, 6}, -- Wind Shear
		{51514, 45}, -- Hex
		{8177, 15}, -- Grounding Totem
		{51490, 45, 1, 25}, -- Thunderstorm (45s, glyph -10s)
		{16166, 180, 1, 16}, -- Elemental Mastery
		{30823, 60, 2, 26}, -- Shamanistic Rage
		{16188, 120, 3, 13}, -- Nature's Swiftness
	},
	WARLOCK = {
		{19647, 24}, -- Spell Lock
		{17925, 120}, -- Death Coil
		{48011, 8}, -- Devour Magic
		{48020, 30}, -- Demonic Circle: Teleport
		{18708, 180, 2, 10}, -- Fel Domination
		{47847, 20, 3, 23}, -- Shadowfury
	},
	WARRIOR = {
		{6552, 10}, -- Pummel
		{72, 12}, -- Shield Bash
		{11578, 13}, -- Charge
		{47996, 15}, -- Intercept
		{871, 300}, -- Shield Wall
		{2565, 60}, -- Shield Block
		{676, 60}, -- Disarm
		{46924, 90, 1, 31}, -- Bladestorm
		{12809, 30, 3, 14}, -- Concussion Blow
		{46968, 17, 3, 27}, -- Shockwave
	},
	DEATHKNIGHT = {
		{47528, 10}, -- Mind Freeze
		{48743, 120}, -- Death Pact
		{49576, 35}, -- Death Grip
		{48707, 45}, -- Anti-Magic Shell
		{47476, 120}, -- Strangulate
		{48792, 120}, -- Icebound Fortitude
		{49039, 120, 2, 8}, -- Lichborne
		{49203, 60, 2, 20}, -- Hungering Cold
		{51271, 60, 2, 24}, -- Unbreakable Armor
		{47481, 20}, -- Gnaw (shown for every DK; not a talent check in ATT)
		{51052, 120, 3, 22}, -- Anti-Magic Zone
		{49206, 180, 3, 31}, -- Summon Gargoyle
	},
	OTHER = {
		{42292, 120, nil, nil, nil, nil, "Human", "Interface\\Icons\\Inv_jewelry_trinketpvp_02"},
		{59752, 120, nil, nil, nil, "Human"},
		{20572, 120, nil, nil, nil, "Orc"},
		{20594, 120, nil, nil, nil, "Dwarf"},
		{58984, 120, nil, nil, nil, "NightElf"},
		{7744, 120, nil, nil, nil, "Scourge"},
		{20549, 120, nil, nil, nil, "Tauren"},
		{20589, 60, nil, nil, nil, "Gnome"},
		{26297, 180, nil, nil, nil, "Troll"},
		{28730, 120, nil, nil, nil, "BloodElf"},
		{71607, 120, nil, nil, nil, nil, nil, "Interface\\Icons\\inv_jewelcrafting_gem_28"},
	},
}

-- Trinket spells. Shown only when that item (or a trinket with the same use spell) is equipped.
Data.PartyAbilities.items = {
	[42292] = { trinket = true, name = "PvP Trinket", icon = "Interface\\Icons\\INV_Jewelry_TrinketPVP_02" },
	[71607] = { item = 50354, trinket = true, name = "Bauble of True Blood", icon = "Interface\\Icons\\INV_Jewelcrafting_Gem_28" },
}

-- The ATT preset values above often assume a full talent rank or a glyph.
-- Calculate the actual duration when LibGroupTalents knows the group member's
-- build. Spell IDs below are talent/glyph spell IDs from the WotLK client.
-- A custom cooldown entered in SUI overrides these rules.
Data.PartyAbilities.cooldownRules = {
	[8983]  = { base = 60, talents = { { 16940, seconds = -15 } } }, -- Bash / Brutal Impact
	[53201] = { base = 90, glyphs = { { ids = { 54828 }, seconds = -30 } } }, -- Starfall
	[18562] = { base = 15 }, -- Swiftmend (ATT's 13s assumes a set bonus)
	[19574] = { base = 120, talents = { { 53262, percent = -0.10 } } }, -- Bestial Wrath / Longevity
	[19263] = { base = 90, glyphs = { { ids = { 56850, 56875 }, seconds = -10 } } }, -- Deterrence
	[11958] = { base = 480, talents = { { 55091, percent = -0.10 } } }, -- Cold Snap / Cold as Ice
	[45438] = { base = 300, talents = { { 31670, percents = { 0, -0.07, -0.14, -0.20 } } } }, -- Ice Block
	[12043] = { base = 120, talents = { { 44378, percent = -0.15 } } }, -- Presence of Mind
	[10890] = { base = 27, talents = { { 15392, seconds = -2 } }, glyphs = { { ids = { 55676, 56177 }, seconds = 8 } } }, -- Psychic Scream; ATT preset includes a 3s bonus
	[34433] = { base = 300, talents = { { 15274, seconds = -60 } } }, -- Shadowfiend / Veiled Shadows
	[33206] = { base = 180, talents = { { 47507, percent = -0.10 } } }, -- Pain Suppression / Aspiration
	[47585] = { base = 120, glyphs = { { ids = { 63229, 63872 }, seconds = -45 } } }, -- Dispersion
	[6346]  = { base = 180, glyphs = { { ids = { 55678, 56165 }, seconds = -60 } } }, -- Fear Ward
	[10308] = { base = 60, talents = { { 20487, seconds = -10 }, { 53695, seconds = -5 } } }, -- Hammer of Justice
	[642]   = { base = 300, talents = { { 31848, seconds = -30 } } }, -- Divine Shield / Sacred Duty
	[26889] = { base = 180, talents = { { 13981, seconds = -30 } } }, -- Vanish / Elusiveness
	[2094]  = { base = 180, talents = { { 13981, seconds = -30 } } }, -- Blind / Elusiveness
	[31224] = { base = 90, talents = { { 13981, seconds = -15 } } }, -- Cloak of Shadows
	[14185] = { base = 480, talents = { { 58414, seconds = -90 } } }, -- Preparation / Filthy Tricks
	[36554] = { base = 30, talents = { { 58414, seconds = -5 } } }, -- Shadowstep
	[51690] = { base = 120, glyphs = { { ids = { 63879 }, seconds = -45 } } }, -- Killing Spree
	[51490] = { base = 45, glyphs = { { ids = { 63270, 63902 }, seconds = -10 } } }, -- Thunderstorm
	[57994] = { base = 6, talents = { { 16040, seconds = -0.2 } } }, -- Wind Shear / Reverberation
	[11578] = { base = 15, talents = { { 64976, seconds = 5 } }, glyphs = { { ids = { 58355 }, percent = -0.07 } } }, -- Charge
	[47996] = { base = 30, talents = { { 29888, seconds = -5 } } }, -- Intercept / Improved Intercept
	[871]   = { base = 300, talents = { { 12312, seconds = -30 } } }, -- Shield Wall
	[676]   = { base = 60, talents = { { 12313, seconds = -10 } } }, -- Disarm
	[46924] = { base = 90, glyphs = { { ids = { 63324 }, seconds = -15 } } }, -- Bladestorm
	[46968] = { base = 20, glyphs = { { ids = { 63325 }, seconds = -3 } } }, -- Shockwave
	[47476] = { base = 120, glyphs = { { ids = { 58618 }, seconds = -20 } } }, -- Strangulate
	[49576] = { base = 35, talents = { { 49588, seconds = -5 } } }, -- Death Grip / Unholy Command
}

-- Cast resets and shared cooldown groups.
local resetters = {
	[23989] = { 19503, 60192, 13809, 14311, 19574, 34490, 19263, 53271, 49012 }, -- Readiness
	[14185] = { 14177, 26669, 11305, 26889, 36554 }, -- Preparation (Kick/Dismantle need glyph)
	[11958] = { 42931, 42917, 43012, 43039, 45438, 31687, 44572, 44545, 12472 }, -- Cold Snap
}
local shared = {
	{ 16979, 49376 }, -- Feral Charge
	{ 49231, 49233, 49236 }, -- Shocks
	{ 60192, 14311, 13809 }, -- Freezing traps
	{ 49067, 49056 }, -- Fire traps
	{ 34600 }, -- Snake Trap
	{ 43010, 43012 }, -- Wards
}
-- ATT: using one of these also puts the others on a shorter shared cooldown.
local linkedUse = {
	Human = { cooldown = 45, 59752, 42292 },
	Scourge = { cooldown = 45, 7744, 42292 },
	Dwarf = { cooldown = 45, 20594, 42292 },
}

Data.PartyAbilities.resetters = resetters
Data.PartyAbilities.shared = shared
Data.PartyAbilities.linkedUse = linkedUse

-- Glow appearance from the configured Sarych x1 profile; trigger on active effects.
Data.PartyAbilities.glowDefaults = {
	[642] = { highlight = 1, glowType = "proc", glowWhen = "active", useGlowColor = true, highlightColor = { 0.9137254901960784, 0.6784313725490196, 0.9294117647058824, 1 } },
	[871] = { highlight = 1, glowType = "Pixel", glowWhen = "active" },
	[1044] = { highlight = 1, glowWhen = "active", highlightColor = { 1, 0.3333333333333333, 0.392156862745098, 1 } },
	[2565] = { highlight = 1, glowType = "Pixel", glowWhen = "active" },
	[6346] = { highlight = 1, glowType = "Pixel", glowWhen = "active", highlightColor = { 0.5450980392156862, 0, 1, 1 }, glowFrequency = -0.1, glowLength = 6.45 },
	[6940] = { highlight = 1, glowWhen = "active", highlightColor = { 1, 0.07058823529411765, 0, 1 } },
	[8177] = { highlight = 1, glowType = "border", glowWhen = "active", useGlowColor = true, highlightColor = { 1, 0.7490196078431373, 0, 1 } },
	[10278] = { highlight = 1, glowType = "Pixel", glowWhen = "active", useGlowColor = true, highlightColor = { 0.7098039215686275, 0.9529411764705882, 1, 1 } },
	[19263] = { highlight = 1, glowType = "Pixel", glowWhen = "active" },
	[22812] = { highlight = 1, glowType = "Pixel", glowWhen = "active" },
	[33206] = { highlight = 1, glowType = "proc", glowWhen = "active", useGlowColor = true, highlightColor = { 0.9607843137254902, 0.9490196078431372, 1, 1 } },
	[45438] = { highlight = 1, glowType = "Pixel", glowWhen = "active", useGlowColor = false, highlightColor = { 0.00784313725490196, 0.2745098039215687, 0.5411764705882353, 1 } },
	[46924] = { highlight = 1, glowType = "proc", glowWhen = "active" },
	[47585] = { highlight = 1, glowType = "proc", glowWhen = "active", useGlowColor = true, highlightColor = { 0.6078431372549019, 0.2627450980392157, 1, 1 } },
	[48707] = { highlight = 1, glowType = "Pixel", glowWhen = "active", useGlowColor = true, highlightColor = { 0.7411764705882353, 1, 0.4431372549019608, 1 } },
	[49206] = { highlight = 1, glowWhen = "active", highlightColor = { 0.2666666666666667, 0.06274509803921569, 1, 1 } },
	[51052] = { highlight = 1, glowWhen = "active", highlightColor = { 0.2627450980392157, 0, 1, 1 } },
	[51271] = { highlight = 1, glowType = "Pixel", glowWhen = "active" },
	[53201] = { highlight = 1, glowType = "ACShine", glowWhen = "active", useGlowColor = true, highlightColor = { 0.9725490196078431, 0.996078431372549, 1, 1 } },
	[61336] = { highlight = 1, glowType = "border", glowWhen = "active", useGlowColor = true, highlightColor = { 0.9294117647058824, 0.8470588235294118, 0.4784313725490196, 1 } },
	[64205] = { highlight = 1, glowWhen = "active", highlightColor = { 1, 0.05098039215686274, 0, 1 } },
}
