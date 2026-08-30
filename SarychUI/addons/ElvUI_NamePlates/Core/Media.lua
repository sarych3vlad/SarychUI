local E, L, V, P, G = unpack(_G.SarychUI_ElvUI_NamePlates) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local LSM = E.Libs.LSM

local M = [[Interface\AddOns\SarychUI\addons\ElvUI_NamePlates\Media\]]

function E:TextureString(texString, dataString)
	return "|T"..texString..(dataString or "").."|t"
end

-- All media is shipped inside this addon's Media folder (fully self-contained).
E.Media = {
	Arrows = {},
	Fonts = {
		PTSansNarrow = M..[[Fonts\PTSansNarrow.ttf]],
		Homespun = M..[[Fonts\Homespun.ttf]],
		Expressway = M..[[Fonts\Expressway.ttf]],
		ContinuumMedium = M..[[Fonts\ContinuumMedium.ttf]],
		ActionMan = M..[[Fonts\ActionMan.ttf]],
		DieDieDie = M..[[Fonts\DieDieDie.ttf]],
		Invisible = M..[[Fonts\Invisible.ttf]],
	},
	Textures = {
		White8x8 = M..[[Textures\White8x8.tga]],
		Black8x8 = M..[[Textures\Black8x8.tga]],
		Spark = M..[[Textures\spark.tga]],
		Nameplates = M..[[Textures\nameplates.BLP]],
		Healer = M..[[Textures\healer.tga]],
		Tank = M..[[Textures\tank.tga]],
		DPS = M..[[Textures\dps.tga]],
		Highlight = M..[[Textures\Highlight.tga]],
		GlowTex = M..[[Textures\glowTex.tga]],
		NormTex = M..[[Textures\NormTex.tga]],
		NormTex2 = M..[[Textures\normTex2.tga]],
		Melli = M..[[Textures\Melli.tga]],
		Minimalist = M..[[Textures\Minimalist.tga]],
		Smooth = M..[[Textures\Smooth.tga]],
		RoleIcons = M..[[Textures\RoleIcons.tga]],
		RaidIcons = M..[[Textures\raidicons.blp]],
		ArrowUp = M..[[Textures\arrowup.tga]],
		Close = M..[[Textures\close.tga]],
		Minus = M..[[Textures\Minus.tga]],
		Plus = M..[[Textures\Plus.tga]],
	}
}

-- Build the full arrow set (Arrow0 .. Arrow72) used by the target indicator selector.
for i = 0, 72 do
	E.Media.Arrows["Arrow"..i] = M.."Arrows\\Arrow"..i..".tga"
end
E.Media.Arrows.ArrowRed = M..[[Arrows\ArrowRed.tga]]
E.Media.Arrows.OldArrow2 = M..[[Arrows\OldArrow2.tga]]
E.Media.Arrows.RLArrow = M..[[Arrows\RLArrow.tga]]
E.Media.Arrows.ArrowUp = M..[[Textures\arrowup.tga]]

-- Register media with LibSharedMedia so the names used by the module/options resolve.
LSM:Register("border", "ElvUI GlowBorder", E.Media.Textures.GlowTex)

LSM:Register("statusbar", "ElvUI Norm", E.Media.Textures.NormTex2)
LSM:Register("statusbar", "ElvUI Gloss", E.Media.Textures.NormTex)
LSM:Register("statusbar", "ElvUI Blank", E.Media.Textures.White8x8)
LSM:Register("statusbar", "Melli", E.Media.Textures.Melli)
LSM:Register("statusbar", "Minimalist", E.Media.Textures.Minimalist)
LSM:Register("statusbar", "Smooth", E.Media.Textures.Smooth)
LSM:Register("background", "ElvUI Blank", E.Media.Textures.White8x8)

LSM:Register("font", "Friz Quadrata TT", [[Fonts\FRIZQT__.TTF]], LSM.LOCALE_BIT_ruRU + LSM.LOCALE_BIT_western)
LSM:Register("font", "PT Sans Narrow", E.Media.Fonts.PTSansNarrow, LSM.LOCALE_BIT_ruRU + LSM.LOCALE_BIT_western)
LSM:Register("font", "Homespun", E.Media.Fonts.Homespun, LSM.LOCALE_BIT_ruRU + LSM.LOCALE_BIT_western)
LSM:Register("font", "Expressway", E.Media.Fonts.Expressway, LSM.LOCALE_BIT_ruRU + LSM.LOCALE_BIT_western)
LSM:Register("font", "Continuum Medium", E.Media.Fonts.ContinuumMedium)
LSM:Register("font", "Action Man", E.Media.Fonts.ActionMan)
LSM:Register("font", "Die Die Die!", E.Media.Fonts.DieDieDie, LSM.LOCALE_BIT_ruRU + LSM.LOCALE_BIT_western)

-- The AceGUI-3.0-SharedMediaWidgets library loads before this file (it lives in the
-- Libs section of the TOC) and builds the global AceGUIWidgetLSMlists from LSM:HashTable
-- snapshots. At that point no media is registered yet, so its sub-tables are nil.
-- Re-point them to the now-populated live LSM hash tables so the options dropdowns
-- (StatusBar Texture / Font selectors) resolve correctly, just like in ElvUI.
if AceGUIWidgetLSMlists then
	AceGUIWidgetLSMlists.font = LSM:HashTable("font")
	AceGUIWidgetLSMlists.sound = LSM:HashTable("sound")
	AceGUIWidgetLSMlists.statusbar = LSM:HashTable("statusbar")
	AceGUIWidgetLSMlists.border = LSM:HashTable("border")
	AceGUIWidgetLSMlists.background = LSM:HashTable("background")
end

-- E.media (lowercase) holds resolved colors/textures used by SetTemplate etc.
E.media = E.media or {}

function E:UpdateMedia()
	local db = self.db and self.db.general
	local fontName = (db and db.font) or "Friz Quadrata TT"
	self.media.normFont = LSM:Fetch("font", fontName)
	self.media.blankTex = LSM:Fetch("background", "ElvUI Blank")
	self.media.normTex = LSM:Fetch("statusbar", (db and db.statusbar) or "ElvUI Norm")
	self.media.glossTex = LSM:Fetch("statusbar", (db and db.statusbar) or "ElvUI Norm")
	self.media.bordercolor = {0, 0, 0}
	self.media.unitframeBorderColor = {0, 0, 0}
	self.media.backdropcolor = {0.06, 0.06, 0.06}
	self.media.backdropfadecolor = {0.06, 0.06, 0.06, 0.8}
	self.media.rgbvaluecolor = {1, 1, 1}
	self.media.hexvaluecolor = "|cffffffff"
end

-- Populate immediately so it is ready before frames are styled.
E:UpdateMedia()
