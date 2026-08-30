local lib, oldminor = LibStub:GetLibrary("LibInternalCooldowns-1.1");

-- Format is spellID = itemID | {itemID, itemID, ... itemID}
local spellToItem = {
	--сарыч
	[60318] = 44308,					-- rings
	
	[64411] = 46017,					-- Val'anyr, Hammer of Ancient Kings
	
	[60065] = {44914, 40684, 49074},	-- Anvil of the Titans, Mirror of Truth, Coren's Chromium 	Coaster
	[60488] = 40373,					-- Extract of Necromatic Power
	[64713] = 45518,					-- Flare of the Heavens
	[60064] = {44912, 40682, 49706, 49076},	-- Flow of Knowledge, Sundial of the Exiled, Mithril Pocketwatch, +49076

	[67703]	= {47303, 47115},			-- Death's Choice, Death's Verdict (AGI)
	[67708]	= {47303, 47115},			-- Death's Choice, Death's Verdict (STR)
	[67772] = {47464, 47131},			-- Death's Choice, Death's Verdict (Heroic) (AGI)
	[67773] = {47464, 47131},			-- Death's Choice, Death's Verdict (Heroic) (STR)
	
	-- RS Scales
	-- Sharpened Twilight Scale
	[75456] = 54590,
	[75458] = 54569,	
	-- Charred Twilight Scale
	[75473] = 54588,
	[75466] = 54572,
	-- Petrified Twilight Scale
	[75480] = 54591,
	[75477] = 54571,
	
	-- ICC epix
	-- Rep rings
	[72416] = {50398, 50397},
	[72412] = {50402, 50401, 52572, 52571},
	[72418] = {50399, 50400},
	[72414] = {50404, 50403},

	-- Deathbringer's Will (Non-heroic)	
	[71485] = 50362,
	[71492] = 50362,
	[71486] = 50362,
	[71484] = 50362,
	[71491] = 50362,
	[71487] = 50362,

	-- Deathbringer's Will (Heroic)
	[71556] = 50363,
	[71560] = 50363,
	[71558] = 50363,
	[71561] = 50363,
	[71559] = 50363,
	[71557] = 50363,	
	
	[71403] = 50198,			-- Needle-Encrusted Scorpion
	[71610] = 50359,			-- Althor's Abacus
	[71633] = 50352,			-- Corpse-tongue coin
	[71601] = 50353,			-- Dislodged Foreign Object
	[71584] = 50358,			-- Purified Lunar Dust
	[71401] = 50342,			-- Whispering Fanged Skull
	[71605] = 50360,			-- Phylactery of the Nameless Lich
	
	-- Heroic ICC trinkets
	[71636] = 50365,			-- Phylactery of the Nameless Lich
	[71541] = 50343,			-- Whispering Fanged Skull
	[71641] = 50366,			-- Althor's Abacus
	[71639] = 50349,			-- Corpse-tongue coin
	[71644] = 50348,			-- Dislodged Foreign Object
	
	-- DK T9 2pc
	[67117] = {48501, 48502, 48503, 48504, 48505, 48472, 48474, 48476, 48478, 48480, 48491, 48492, 48493, 48494, 48495, 48496, 48497, 48498, 48499, 48500, 48486, 48487, 48488, 48489, 48490, 48481, 48482, 48483, 48484, 48485},
	-- Hunter T8 4pc
	[64861] = {46145, 46144, 46143, 46142, 46141, 45364, 45363, 45362, 45361, 45360},
	-- Mage T8 2pc
	[64868] = {46134, 46133, 46132, 46130, 46129, 46131, 45369, 45368, 45367, 45365},
	
	-- WotLK Epix
	[64739] = 45535, 			-- Show of Faith
	[67671] = 47214,			-- Banner of Victory
	[67669] = 47213, 			-- Abyssal Rune 
	[64772] = 45609, 			-- Comet's Trail
	[65024] = 46038, 			-- Dark Matter
	[60443] = 40371,			-- Bandit's Insignia
	[64790] = 45522,			-- Blood of the Old God
	[60203] = 42990,			-- Darkmoon Card: Death
	[60494] = 40255,			-- Dying Curse
	[65004] = 65005,			-- Elemental Focus Stone
	[60492] = 39229,			-- Embrace of the Spider
	[60530] = 40258,			-- Forethought Talisman
	[60437] = 40256,			-- Grim Toll
	[49623] = 37835, 			-- Je'Tze's Bell
	[65019] = 45931, 			-- Mjolnir Runestone
	[64741] = 45490,			-- Pandora's Plea
	[65014] = 45286,			-- Pyrite Infuser
	[65003] = 45929, 			-- Sif's Remembrance
	[60538] = 40382,			-- Soul of the Dead
	[58904] = 43573,			-- Tears of Bitter Anguish
	[60062] = {40685, 49078},	-- The Egg of Mortal Essence, Ancient Pickled Egg
	[64765] = 45507, 			-- The General's Heart
	
	-- WotLK Blues
	[51353]	= 38358,			-- Arcane Revitalizer
	[60218] = 37220,			-- Essence of Gossamer
	[60479] = 37660,			-- Forge Ember
	[51348] = 38359,			-- Goblin Repetition Reducer
	[63250] = 45131,			-- Jouster's Fury
	[63250] = 45219,			-- Jouster's Fury
	[60302] = 37390,			-- Meteorite Whetstone
	[54808] = 40865, 			-- Noise Machine
	[60483] = 37264, 			-- Pendulum of Telluric Currents
	[52424] = 38675, 			-- Signet of the Dark Brotherhood
	[55018] = 40767,			-- Sonic Booster
	[52419] = 38674,			-- Soul Harvester's Charm
	-- [18350] = 37111,			-- Soul Preserver, no internal cooldown
	[60520] = 37657,			-- Spark of Life
	[60307] = 37064,			-- Vestige of Haldor
	
	-- Greatness cards
	[60233] = {44253, 44254, 44255, 42987},		-- Greatness, AGI
	[60235] = {44253, 44254, 44255, 42987},		-- Greatness, SPI
	[60229] = {44253, 44254, 44255, 42987},		-- Greatness, INT
	[60234] = {44253, 44254, 44255, 42987},		-- Greatness, STR
	
	-- TBC Rings
	[35087] = 29309,			-- Band of the Eternal Restorer
	[35084] = 29305,			-- Band of the Eternal Sage
	[35081] = 29301,			-- Band of the Eternal Champion
	[35078] = 29297,			-- Band of the Eternal Defender
	-- TBC Trinkets
	[45040] = 34427,			-- Memento of Tyrande
	[37656] = 32496,			-- Memento of Tyrande
	[37198] = 30447,			-- Tome of Fiery Redemption
	[37174] = 30450,			-- Warp-Spring Coil
	[38324] = 30619,			-- Fel Reaver's Piston
	[38348] = 30626,			-- Sextant of Unstable Currents
	[42084] = 30627,			-- Tsunami Talisman
	[37243] = 30663,			-- Fathom-Brooch of the Tidewalker
	[34775] = 28830,			-- Dragonspine Trophy
	[45055] = 34470,			-- Timbal's Focusing Crystal
	[45053] = 34472,			-- Shard of Contempt
	[33370] = {28190, 27683},	-- Scarab of the Infinite Cycle / Quagmirran's Eye
	[34321] = 28418,			-- Shiffar's Nexus-Horn
	[33649] = 28034,			-- Hourglass of the Unraveller
	[41263] = 32771,			-- Airman's Ribbon of Gallantry
	[41261] = 32770,			-- Skyguard Silver Cross
	[37658] = 28785,			-- Lightning Capacito
	[33523] = {27922, 27924, 27926, 27927}, -- PvP Low
	-- Vanilla Epix/Rares
	[23684] = 19288,			-- Darkmoon Card: Blue Dragon
	[22600] = 18168,			-- Force Reactive Disk
};

-- spell ID = {enchant ID, slot1[, slot2]}
local enchants = {
	[55637] = {3722, 15},			-- Lightweave
	[55775] = {3730, 15},			-- Swordguard
	[55767] = {3728, 15},			-- Darkglow
	[59626] = {3790, 16, 17}, 			-- Black Magic ?
	[59625] = {3790, 16, 17}, 			-- Black Magic ? 	
};

-- ICDs on metas assumed to be 45 sec. Needs testing.
local metas = {	
	[23454] = 25899,				-- Brutal Earthstorm Diamond
	[55341] = 41385, 				-- Invigorating Earthsiege Diamond
	[18803] = 25893,				-- Mystical Skyfire Diamond
	[32845]	= 25898,				-- Tenacious Earthstorm Diamond
	[39959] = 32410,				-- Thundering Skyfire Diamond
	[55379] = 41400					-- Thundering Skyflare Diamond
};

-- Spell ID => cooldown, in seconds
-- If an item isn't in here, 45 sec is assumed.
local cooldowns = {
	-- Scales 
	[75456] = 45,
	[75458] = 45,
	[75473] = 45,
	[75466] = 45,
	[75480] = 45,
	[75477] = 45,
	-- ICC rep rings
	[72416] = 60,
	[72412] = 60,
	[72418] = 60,
	[72414] = 60,

	[60488] = 15,
	[51348] = 10,
	[51353] = 10,
	[54808] = 60,
	[55018] = 60,
	[52419] = 30,
	[59620] = 90,
	
	[55382] = 15,
	[32848] = 15,
	[55341] = 90,		-- Invigorating Earthsiege, based on WowHead comments (lol?)
	
	[48517] = 30,
	[48518] = 30,
	
	[47755] = 12,
	
	[67117] = 45, 		-- DK T9 2pc
	[64861] = 45, 		-- Hunter T8 4pc
	[64868] = 45, 		-- Mage T8 2pc
	
	-- Phylactery of the Nameless Lich
	[71636] = 100,
	[71605] = 100,
	
	-- Deathbringer's Will
	[71485] = 105,
	[71492] = 105,
	[71486] = 105,
	[71484] = 105,
	[71491] = 105,
	[71487] = 105,

	-- Deathbringer's Will (Heroic)
	[71556] = 105,
	[71560] = 105,
	[71558] = 105,
	[71561] = 105,
	[71559] = 105,
	[71557] = 105,
	
	-- Black Magic
	[59626] = 35,
	[59625] = 35, 
	
	-- TBC Rings
	[35087] = 60,
	[35084] = 60,
	[35081] = 60,
	[35078] = 60,	
	
	-- TBC Trink
	[37656] = 50,
	[37174] = 30,
	[38324] = 15,
	[37243] = 40,
	[34775] = 20,
	[37658] = 2.5,
	[45055] = 15,
	[33649] = 50,
	[41263] = 10,
	[41261] = 10,
	[33523] = 25,
	-- Vanilla Epix/Rares
	[22600] = 1,
};


-- Procced spell effect ID = unique name
-- The name doesn't matter, as long as it's non-numeric and unique to the ICD.
local talents = {
	-- Druid
	[48517] = "Eclipse",
	[48518] = "Eclipse",
	
	-- Hunter
	[56453] = "Lock and Load",
	
	-- Death Knight
	[52286] = "Will of the Necropolis",
	
	-- Priest
	[47755] = "Rapture"
};
-----------------------------------------------------------------------
-- Don't edit past this line									--
-----------------------------------------------------------------------

------------------------------------
-- Upgrade this data into the lib
------------------------------------

lib.spellToItem = lib.spellToItem or {};
lib.cooldowns = lib.cooldowns or {};
lib.enchants = lib.enchants or {};
lib.metas = lib.metas or {};
lib.talents = lib.talents or {};

local tt, tts = {}, {}
local function merge(t1, t2)
	wipe(tts)
	for _, v in ipairs(t1) do
		tts[v] = true
	end
	for _, v in ipairs(t2) do
		if not tts[v] then
			tinsert(t1, v);
		end
	end
end;

for k, v in pairs(spellToItem) do
	local e = lib.spellToItem[k]
	if e and e ~= v then
		if type(e) == "table" then
			if type(v) ~= "table" then
				wipe(tt)
				tinsert(tt, v)
			end
			merge(e, tt);
		else
			lib.spellToItem[k] = {e, v};
		end
	else
		lib.spellToItem[k] = v;
	end
end;

for k, v in pairs(cooldowns) do
	lib.cooldowns[k] = v
end;

for k, v in pairs(enchants) do
	lib.enchants[k] = v
end;

for k, v in pairs(metas) do
	lib.metas[k] = v
end;

for k, v in pairs(talents) do
	lib.talents[k] = v
end;