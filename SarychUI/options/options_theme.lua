-- SarychUI Options Theme — Details Cooltip-style textured chrome.
local SUI = SarychUI
SUI.OptionsTheme = SUI.OptionsTheme or {}
local T = SUI.OptionsTheme

local FLAT = "Interface\\Buttons\\WHITE8X8"
-- Same texture as options Cooltip / Details Cooltip Preset(2).
local COOLTIP_BG = "Interface\\AddOns\\SarychUI\\media\\cooltip\\background"

T.textures = {
	flat = FLAT,
	cooltipBg = COOLTIP_BG,
}

-- Colors tint the cooltip background texture (SetBackdropColor multiply).
-- Base gray matches Cooltip Preset(2): {0.37, 0.37, 0.37, 0.95}.
-- Alpha < 1 keeps the cooltip grain while letting the game world show through.
T.colors = {
	rootBg     = { 0.37, 0.37, 0.37, 0.68 },
	headerBg   = { 0.28, 0.28, 0.28, 1 },
	footerBg   = { 0.28, 0.28, 0.28, 0.55 },
	navBg      = { 0.30, 0.30, 0.30, 0.65 },
	navHover   = { 0.42, 0.42, 0.42, 0.82 },
	navActive  = { 0.48, 0.42, 0.28, 0.85 },
	contentBg  = { 0.34, 0.34, 0.34, 0.60 },
	panelBg    = { 0.32, 0.32, 0.32, 0.55 },
	tabBg      = { 0.30, 0.30, 0.30, 0.70 },
	tabActive  = { 0.46, 0.40, 0.26, 0.80 },
	border     = { 0.20, 0.20, 0.20, 1 },
	borderSoft = { 0.20, 0.20, 0.20, 1 },
	text       = { 0.92, 0.92, 0.92, 1 },
	textDim    = { 0.65, 0.65, 0.68, 1 },
	footerCredit = { 0.42, 0.42, 0.45, 0.50 },
	title      = { 0.95, 0.82, 0.20, 1 },
	accent     = { 0.95, 0.78, 0.15, 1 },
	buttonBg   = { 0.28, 0.28, 0.28, 0.75 },
	buttonHover= { 0.42, 0.42, 0.42, 0.88 },
	inputBg    = { 0.22, 0.22, 0.22, 0.78 },
	disabled   = { 0.45, 0.45, 0.45, 1 },
	checkOn    = { 0.95, 0.82, 0.20, 1 },
	scrollTrack= { 0.24, 0.24, 0.24, 0.65 },
	scrollThumb= { 0.42, 0.42, 0.42, 0.80 },
	scrollThumbHover = { 0.52, 0.48, 0.32, 0.90 },
}

-- Details-like density (~897x592 shell, compact rows).
T.sizes = {
	windowW = 900,
	windowH = 600,
	navW = 200,
	headerH = 36,
	footerH = 28,
	tabH = 24,
	pad = 8,
	panelPad = 8,
	contentPad = 4,
	rowH = 22,
	rowGap = 4,
	controlH = 20,
	navItemH = 22,
	controlW = 180,
	controlMaxW = 320,
	addonListW = 200,
	addonListScrollW = 8,
	fontSize = 12,
}

T.fonts = {
	title = "GameFontNormal",
	normal = "GameFontHighlightSmall",
	small = "GameFontHighlightSmall",
	nav = "GameFontHighlightSmall",
}

-- Cooltip Preset(2) backdrop: tiled background.tga + 1px WHITE8X8 edge.
local COOLTIP_BD = {
	bgFile = COOLTIP_BG,
	edgeFile = FLAT,
	tile = true,
	tileSize = 16,
	edgeSize = 1,
	insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

function T:ApplyFlat(frame, bg, border)
	if not frame or not frame.SetBackdrop then
		return
	end
	frame:SetBackdrop(COOLTIP_BD)
	bg = bg or self.colors.rootBg
	border = border or self.colors.border
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

function T:SetTextColor(fs, key)
	local c = self.colors[key or "text"]
	if fs and c and fs.SetTextColor then
		fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	end
end

function T:Backdrop()
	return COOLTIP_BD
end
