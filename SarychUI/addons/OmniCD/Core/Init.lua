local loaderName, shared = ...

-- Always identity as OmniCD, even when TOC-loaded by SarychUI.
local AddOnName = "OmniCD"

local AddOn = CreateFrame("Frame")
AddOn.L = LibStub("AceLocale-3.0"):GetLocale(AddOnName)
AddOn.defaults = { global = {}, profile = { modules = { ["Party"] = true } } }

local NS = {
	AddOn,
	AddOn.L,
	AddOn.defaults.profile,
	AddOn.defaults.global,
}

function NS:unpack()
	return self[1], self[2], self[3], self[4]
end

-- Later OmniCD files call select(2, ...):unpack(). Keep ClassicAPI's private table intact.
function shared:unpack()
	return NS[1], NS[2], NS[3], NS[4]
end

NS[1].Libs = {}
NS[1].Libs.ACD = LibStub("AceConfigDialog-3.0-OmniCDC")
NS[1].Libs.ACR = LibStub("AceConfigRegistry-3.0")
NS[1].Libs.LSM = LibStub("LibSharedMedia-3.0")
NS[1].Libs.OmniCDC = LibStub("LibOmniCDC")

NS[1].Party = CreateFrame("Frame")
NS[1].Comm = CreateFrame("Frame")
NS[1].Cooldowns = CreateFrame("Frame")

NS[1].AddOn = AddOnName
NS[1].Version = "1.7"
NS[1].Author = "Treebonker, Tsoukie"
NS[1].Notes = "Party cooldown tracker. /oc"
NS[1].License = "All Rights Reserved"
NS[1].Localizations = "enUS, deDE, esMX, frFR, koKR, ruRU, zhCN, zhTW"

NS[1].userName = UnitName("player")
NS[1].userRealm = GetRealmName()
NS[1].userNameWithRealm = format("%s-%s", NS[1].userName, NS[1].userRealm)
NS[1].userClass = select(2, UnitClass("player"))
NS[1].userRaceID = select(2, UnitRace("player"))
NS[1].userLevel = UnitLevel("player")
NS[1].userFaction = UnitFactionGroup("player")
NS[1].userClassHexColor = "|c" .. select(4, GetClassColor(NS[1].userClass))

NS[1].TocVersion = select(4, GetBuildInfo())
NS[1].LoginMessage = format("%sOmniCD v%s|r - /oc", NS[1].userClassHexColor, NS[1].Version)

NS[1].isClassic = WOW_PROJECT_ID_RCE == WOW_PROJECT_CLASSIC
NS[1].isBCC = WOW_PROJECT_ID_RCE == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
NS[1].isWOTLKC = WOW_PROJECT_ID_RCE == WOW_PROJECT_WRATH_CLASSIC

_G.OmniCD = NS
_G.OmniCDEnabled = _G.OmniCDEnabled ~= false
