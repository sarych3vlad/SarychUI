do
    local currentLocale = GetLocale();
	if GetLocale() == "ruRU" then

    local levelDungeons = {
        ["ruRU"] = {
            [15] = {
                {name = "Огненная пропасть", icon = "Interface\\LFGFrame\\LFGICON-RAGEFIRECHASM"},
                {name = "Мертвые копи", icon = "Interface\\LFGFrame\\LFGICON-DEADMINES"},
                {name = "Пещеры Стенаний", icon = "Interface\\LFGFrame\\LFGICON-WAILINGCAVERNS"}
            },
            [16] = {
                {name = "Крепость Темного клыка", icon = "Interface\\LFGFrame\\LFGICON-SHADOWFANGKEEP"}
            },
            [19] = {
                {name = "Непроглядная Пучина", icon = "Interface\\LFGFrame\\LFGICON-BLACKFATHOMDEEPS"}
            },
            [20] = {
                {name = "Тюрьма Штормграда", icon = "Interface\\LFGFrame\\LFGICON-STORMWINDSTOCKADES"}
            },
            [22] = {
                {name = "Лабиринты Иглошкурых", icon = "Interface\\LFGFrame\\LFGICON-RAZORFENKRAUL"}
            },
            [23] = {
                {name = "Гномреган", icon = "Interface\\LFGFrame\\LFGICON-GNOMEREGAN"}
            },
            [27] = {
                {name = "Монастырь Алого ордена\n - кладбище", icon = "Interface\\LFGFrame\\LFGICON-SCARLETMONASTERY"}
            },
            [30] = {
                {name = "Монастырь Алого ордена\n - библиотека", icon = "Interface\\LFGFrame\\LFGICON-SCARLETMONASTERY"}
            },
            [32] = {
                {name = "Курганы Иглошкурых", icon = "Interface\\LFGFrame\\LFGICON-RAZORFENDOWNS"},
                {name = "Монастырь Алого ордена - оружейная", icon = "Interface\\LFGFrame\\LFGICON-SCARLETMONASTERY"}
            },
            [35] = {
                {name = "Монастырь Алого ордена - собор", icon = "Interface\\LFGFrame\\LFGICON-SCARLETMONASTERY"},
                {name = "Ульдаман", icon = "Interface\\LFGFrame\\LFGICON-ULDAMAN"}
            },
            [39] = {
                {name = "Мародон - Лиловые кристаллы", icon = "Interface\\LFGFrame\\LFGICON-MARAUDON"}
            },
            [41] = {
                {name = "Зул'Фаррак", icon = "Interface\\LFGFrame\\LFGICON-ZULFARAK"},
                {name = "Мародон - Оранжевые кристаллы", icon = "Interface\\LFGFrame\\LFGICON-MARAUDON"}
            },
            [43] = {
                {name = "Мародон - Чистые воды", icon = "Interface\\LFGFrame\\LFGICON-MARAUDON"}
            },
            [45] = {
                {name = "Затонувший храм", icon = "Interface\\LFGFrame\\LFGICON-SUNKENTEMPLE"}
            },
            [47] = {
                {name = "Глубины Черной горы - Тюрьма", icon = "Interface\\LFGFrame\\LFGICON-BLACKROCKDEPTHS"}
            },
            [51] = {
                {name = "Глубины Черной горы - Верхний город", icon = "Interface\\LFGFrame\\LFGICON-BLACKROCKDEPTHS"}
            },
            [53] = {
                {name = "Забытый Город - Восток", icon = "Interface\\LFGFrame\\LFGICON-DIREMAUL"}
            },
            [55] = {
                {name = "Забытый Город - Запад", icon = "Interface\\LFGFrame\\LFGICON-DIREMAUL"},
                {name = "Забытый Город - Север", icon = "Interface\\LFGFrame\\LFGICON-DIREMAUL"},
                {name = "Некроситет", icon = "Interface\\LFGFrame\\LFGICON-SCHOLOMANCE"},
                {name = "Нижняя часть Черной горы", icon ="Interface\\LFGFrame\\LFGICON-BLACKROCKDEPTHS"},
                {name = "Стратхольм - Главные врата", icon ="Interface\\LFGFrame\\LFGICON-STRATHOLME"},
                {name = "Стратхольм - Черный ход", icon ="Interface\\LFGFrame\\LFGICON-STRATHOLME"}
            },
            [57] = {
                {name = "Бастионы Адского Пламени", icon ="Interface\\LFGFrame\\LFGICON-HELLFIRECITADEL"}
            },
            [59] = {
                {name = "Кузня Крови", icon ="Interface\\LFGFrame\\LFGICON-HELLFIRECITADEL"}
            },
            [60] = {
                {name = "Узилище", icon ="Interface\\LFGFrame\\LFGICON-COILFANG"}
            },
            [61] = {
                {name = "Нижетопь", icon ="Interface\\LFGFrame\\LFGICON-COILFANG"}
            },
            [62] = {
                {name = "Гробницы маны", icon ="Interface\\LFGFrame\\LFGICON-AUCHINDOUN"}
            },
            [63] = {
                {name = "Аукенайские гробницы", icon ="Interface\\LFGFrame\\LFGICON-AUCHINDOUN"}
            },
            [64] = {
                {name = "Побег из Дарнхольда", icon ="Interface\\LFGFrame\\LFGICON-CAVERNSOFTIME"}
            },
            [65] = {
                {name = "Сетеккские залы", icon ="Interface\\LFGFrame\\LFGICON-AUCHINDOUN"}
            },
            [67] = {
                {name = "Ботаника", icon ="Interface\\LFGFrame\\LFGICON-TEMPESTKEEP"},
                {name = "Механар", icon ="Interface\\LFGFrame\\LFGICON-TEMPESTKEEP"},
                {name = "Паровое Подземелье", icon ="Interface\\LFGFrame\\LFGICON-COILFANG"},
                {name = "Разрушенные залы", icon ="Interface\\LFGFrame\\LFGICON-HELLFIRECITADEL"},
                {name = "Темный лабиринт", icon ="Interface\\LFGFrame\\LFGICON-AUCHINDOUN"}
            },
            [68] = {
                {name = "Аркатрац", icon ="Interface\\LFGFrame\\LFGICON-TEMPESTKEEP"},
                {name = "Терраса Магистров", icon ="Interface\\LFGFrame\\LFGICON-MAGISTERSTERRACE"},
                {name = "Черные топи", icon ="Interface\\LFGFrame\\LFGICON-CAVERNSOFTIME"},
                {name = "Крепость Утгард", icon ="Interface\\LFGFrame\\LFGIcon-Utgarde"}
            },
            [69] = {
                {name = "Нексус", icon ="Interface\\LFGFrame\\LFGIcon-TheNexus"}
            },
            [70] = {
                {name = "Азжол-Неруб", icon ="Interface\\LFGFrame\\LFGIcon-AzjolNerub"}
            },
            [71] = {
                {name = "Ан'кахет: Старое Королевство", icon ="Interface\\LFGFrame\\LFGIcon-Ahnkahet"}
            },
            [72] = {
                {name = "Крепость Драк'Тарон", icon ="Interface\\LFGFrame\\LFGIcon-DrakTharon"}
            },
            [73] = {
                {name = "Аметистовая крепость", icon ="Interface\\LFGFrame\\LFGIcon-TheVioletHold"}
            },
            [74] = {
                {name = "Гундрак", icon ="Interface\\LFGFrame\\LFGIcon-Gundrak"}
            },
            [75] = {
                {name = "Чертоги Камня", icon ="Interface\\LFGFrame\\LFGIcon-HallsofStone"}
            },
            [77] = {
                {name = "Вершина Утгард", icon ="Interface\\LFGFrame\\LFGIcon-UtgardePinnacle"},
                {name = "Окулус", icon ="Interface\\LFGFrame\\LFGIcon-TheOculus"},
                {name = "Очищение Стратхольма", icon ="Interface\\LFGFrame\\LFGICON-CAVERNSOFTIME"},
                {name = "Чертоги Молний", icon ="Interface\\LFGFrame\\LFGICON-HALLSOFLIGHTNING"}
            },
            [80] = {
                {name = "Залы Отражений", icon ="Interface\\LFGFrame\\LFGIcon-HallsofReflection"},
                {name = "Испытание чемпионов", icon ="Interface\\LFGFrame\\LFGIcon-ArgentRaid"},
                {name = "Кузня Душ", icon ="Interface\\LFGFrame\\LFGIcon-TheForgeofSouls"},
                {name = "Яма Сарона", icon ="Interface\\LFGFrame\\LFGIcon-PitofSaron"}
            }
        }
    };
	
    function GetDungeonsForLevel(level)
        return (levelDungeons[currentLocale] and levelDungeons[currentLocale][level]) or {};
	end	
    end
end
