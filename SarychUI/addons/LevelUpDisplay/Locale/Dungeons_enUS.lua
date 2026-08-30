do
    local currentLocale = GetLocale();
	if GetLocale() == "enUS" then

    local levelDungeons = {
        ["enUS"] = {
            [15] = {
                {name = "Ragefire Chasm", icon = "Interface\\LFGFrame\\LFGICON-RAGEFIRECHASM"},
                {name = "Deadmines", icon = "Interface\\LFGFrame\\LFGICON-DEADMINES"},
                {name = "Wailing Caverns", icon = "Interface\\LFGFrame\\LFGICON-WAILINGCAVERNS"}
            },
            [16] = {
                {name = "Shadowfang Keep", icon = "Interface\\LFGFrame\\LFGICON-SHADOWFANGKEEP"}
            },
            [19] = {
                {name = "Blackfathom Deeps", icon = "Interface\\LFGFrame\\LFGICON-BLACKFATHOMDEEPS"}
            },
            [20] = {
                {name = "Stormwind Stockade", icon = "Interface\\LFGFrame\\LFGICON-STORMWINDSTOCKADES"}
            },
            [22] = {
                {name = "Razorfen Kraul", icon = "Interface\\LFGFrame\\LFGICON-RAZORFENKRAUL"}
            },
            [23] = {
                {name = "Gnomeregan", icon = "Interface\\LFGFrame\\LFGICON-GNOMEREGAN"}
            },
            [27] = {
                {name = "Scarlet Monastery - Graveyard", icon = "Interface\\LFGFrame\\LFGICON-SCARLETMONASTERY"}
            },
            [30] = {
                {name = "Scarlet Monastery - Library", icon = "Interface\\LFGFrame\\LFGICON-SCARLETMONASTERY"}
            },
            [32] = {
                {name = "Razorfen Downs", icon = "Interface\\LFGFrame\\LFGICON-RAZORFENDOWNS"},
                {name = "Scarlet Monastery - Armory", icon = "Interface\\LFGFrame\\LFGICON-SCARLETMONASTERY"}
            },
            [35] = {
                {name = "Scarlet Monastery - Cathedral", icon = "Interface\\LFGFrame\\LFGICON-SCARLETMONASTERY"},
                {name = "Uldaman", icon = "Interface\\LFGFrame\\LFGICON-ULDAMAN"}
            },
            [39] = {
                {name = "Maraudon - Purple Crystals", icon = "Interface\\LFGFrame\\LFGICON-MARAUDON"}
            },
            [41] = {
                {name = "Zul'Farrak", icon = "Interface\\LFGFrame\\LFGICON-ZULFARAK"},
                {name = "Maraudon - Orange Crystals", icon = "Interface\\LFGFrame\\LFGICON-MARAUDON"}
            },
            [43] = {
                {name = "Maraudon - Pristine Waters", icon = "Interface\\LFGFrame\\LFGICON-MARAUDON"}
            },
            [45] = {
                {name = "Sunken Temple", icon = "Interface\\LFGFrame\\LFGICON-SUNKENTEMPLE"}
            },
            [47] = {
                {name = "Blackrock Depths - Prison", icon = "Interface\\LFGFrame\\LFGICON-BLACKROCKDEPTHS"}
            },
            [51] = {
                {name = "Blackrock Depths - Upper City", icon = "Interface\\LFGFrame\\LFGICON-BLACKROCKDEPTHS"}
            },
            [53] = {
                {name = "Dire Maul - East", icon = "Interface\\LFGFrame\\LFGICON-DIREMAUL"}
            },
            [55] = {
                {name = "Dire Maul - North", icon = "Interface\\LFGFrame\\LFGICON-DIREMAUL"},
                {name = "Dire Maul - West", icon = "Interface\\LFGFrame\\LFGICON-DIREMAUL"},
                {name = "Scholomance", icon = "Interface\\LFGFrame\\LFGICON-SCHOLOMANCE"},
                {name = "Lower Blackrock Spire", icon ="Interface\\LFGFrame\\LFGICON-BLACKROCKDEPTHS"},
                {name = "Stratholme - Main Gate", icon ="Interface\\LFGFrame\\LFGICON-STRATHOLME"},
                {name = "Stratholme - Service Entrance", icon ="Interface\\LFGFrame\\LFGICON-STRATHOLME"}
            },
            [57] = {
                {name = "Helfire Ramparts", icon ="Interface\\LFGFrame\\LFGICON-HELLFIRECITADEL"}
            },
            [59] = {
                {name = "Blood Furnace", icon ="Interface\\LFGFrame\\LFGICON-HELLFIRECITADEL"}
            },
            [60] = {
                {name = "Slave Pens", icon ="Interface\\LFGFrame\\LFGICON-COILFANG"}
            },
            [61] = {
                {name = "Underbog", icon ="Interface\\LFGFrame\\LFGICON-COILFANG"}
            },
            [62] = {
                {name = "Mana-Tombs", icon ="Interface\\LFGFrame\\LFGICON-AUCHINDOUN"}
            },
            [63] = {
                {name = "Auchenai Crypts", icon ="Interface\\LFGFrame\\LFGICON-AUCHINDOUN"}
            },
            [64] = {
                {name = "The Escape From Durnholde", icon ="Interface\\LFGFrame\\LFGICON-CAVERNSOFTIME"}
            },
            [65] = {
                {name = "Sethekk Halls", icon ="Interface\\LFGFrame\\LFGICON-AUCHINDOUN"}
            },
            [67] = {
                {name = "The Botanica", icon ="Interface\\LFGFrame\\LFGICON-TEMPESTKEEP"},
                {name = "The Mechanar", icon ="Interface\\LFGFrame\\LFGICON-TEMPESTKEEP"},
                {name = "The Steamvault", icon ="Interface\\LFGFrame\\LFGICON-COILFANG"},
                {name = "Shattered Halls", icon ="Interface\\LFGFrame\\LFGICON-HELLFIRECITADEL"},
                {name = "Shadow Labyrinth", icon ="Interface\\LFGFrame\\LFGICON-AUCHINDOUN"}
            },
            [68] = {
                {name = "The Arcatraz", icon ="Interface\\LFGFrame\\LFGICON-TEMPESTKEEP"},
                {name = "Magister's Terrace", icon ="Interface\\LFGFrame\\LFGICON-MAGISTERSTERRACE"},
                {name = "The Black Morass", icon ="Interface\\LFGFrame\\LFGICON-CAVERNSOFTIME"},
                {name = "Utgarde Keep", icon ="Interface\\LFGFrame\\LFGIcon-Utgarde"}
            },
            [69] = {
                {name = "The Nexus", icon ="Interface\\LFGFrame\\LFGIcon-TheNexus"}
            },
            [70] = {
                {name = "Azjol-Nerub", icon ="Interface\\LFGFrame\\LFGIcon-AzjolNerub"}
            },
            [71] = {
                {name = "Ahn'kahet: The Old Kingdom", icon ="Interface\\LFGFrame\\LFGIcon-Ahnkahet"}
            },
            [72] = {
                {name = "Drak'Tharon Keep", icon ="Interface\\LFGFrame\\LFGIcon-DrakTharon"}
            },
            [73] = {
                {name = "Violet Hold", icon ="Interface\\LFGFrame\\LFGIcon-TheVioletHold"}
            },
            [74] = {
                {name = "Gundrak", icon ="Interface\\LFGFrame\\LFGIcon-Gundrak"}
            },
            [75] = {
                {name = "Halls of Stone", icon ="Interface\\LFGFrame\\LFGIcon-HallsofStone"}
            },
            [77] = {
                {name = "Utgarde Pinnacle", icon ="Interface\\LFGFrame\\LFGIcon-UtgardePinnacle"},
                {name = "The Oculus", icon ="Interface\\LFGFrame\\LFGIcon-TheOculus"},
                {name = "The Cullling of Stratholme", icon ="Interface\\LFGFrame\\LFGICON-CAVERNSOFTIME"},
                {name = "Halls of Lightning", icon ="Interface\\LFGFrame\\LFGICON-HALLSOFLIGHTNING"}
            },
            [80] = {
                {name = "Halls of Reflection", icon ="Interface\\LFGFrame\\LFGIcon-HallsofReflection"},
                {name = "Trial of the Champion", icon ="Interface\\LFGFrame\\LFGIcon-ArgentRaid"},
                {name = "The Forge of Souls", icon ="Interface\\LFGFrame\\LFGIcon-TheForgeofSouls"},
                {name = "Pit of Saron", icon ="Interface\\LFGFrame\\LFGIcon-PitofSaron"}
            }
        }
    };
	
    function GetDungeonsForLevel(level)
        return (levelDungeons[currentLocale] and levelDungeons[currentLocale][level]) or {};
	end	
    end
end
