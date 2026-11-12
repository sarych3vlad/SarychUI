-- SarychUI MainMenuBar - action button text preview (hotkeys / macro names).

local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
local ipairs = ipairs
local tinsert = table.insert
local ceil = math.ceil

SarychUI = SarychUI or {}

local function Tr(s)
	if type(s) ~= "string" or s == "" then
		return s
	end
	if SarychUI.T then
		return SarychUI:T(s)
	end
	return s
end

local SAMPLE_ICONS = {
	"Interface\\Icons\\Spell_Holy_FlashHeal",
	"Interface\\Icons\\Spell_Fire_Fireball02",
	"Interface\\Icons\\Ability_Warrior_Charge",
	"Interface\\Icons\\Spell_Nature_StarFall",
}

local SAMPLE_HOTKEYS = { "1", "2", "3", "4" }
local SAMPLE_MACROS = { SarychUI:T("ui.options_d1e17ed1ea"), SarychUI:T("ui.options_330856c40b"), SarychUI:T("ui.options_b38424012a"), SarychUI:T("ui.options_cc32b393d7") }


local function GetMMBDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.mainmenubar
end

local function GetSetting(key, default)
	local db = GetMMBDB()
	if db and db[key] ~= nil then return db[key] end
	return default
end

local function GetPreviewFont(name)
	local media = SarychUI.Media
	if media and media.GetFont then
		local ok, path = pcall(media.GetFont, name)
		if ok and path then return path end
	end
	return "Fonts\\FRIZQT__.TTF"
end

local INDICATION_COLOR_DEFAULTS = {
	colorCooldownColor = { 0.4, 0.4, 0.4, 0.6 },
	colorManaColor = { 0.1, 0.1, 1.0, 1.0 },
	colorRangeColor = { 0.8, 0.2, 0.2, 1.0 },
	colorUnusableColor = { 0.2, 0.2, 0.2, 1.0 },
}

local function GetIndicationColor(key)
	local db = GetMMBDB()
	local color = db and db[key]
	local defaults = INDICATION_COLOR_DEFAULTS[key]
	local r = type(color) == "table" and color[1] or nil
	local g = type(color) == "table" and color[2] or nil
	local b = type(color) == "table" and color[3] or nil
	local a = type(color) == "table" and color[4] or nil
	if r == nil then r = defaults[1] end
	if g == nil then g = defaults[2] end
	if b == nil then b = defaults[3] end
	if a == nil and key == "colorCooldownColor" and db then
		a = db.colorCooldownAlpha
	end
	if a == nil then a = defaults[4] end
	return r, g, b, a
end

--------------------------------------------------------------------
SarychUI.ActionBarTextPreview = SarychUI.ActionBarTextPreview or {}
local Preview = SarychUI.ActionBarTextPreview
Preview._instances = Preview._instances or {}

local function TrackInstance(host)
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(Preview, host) else tinsert(Preview._instances, host) end
end

local function RefreshBucket()
	local alive = {}
	for _, inst in ipairs(Preview._instances) do
		if inst and inst.GetParent and inst:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	Preview._instances = alive
end

function Preview:RefreshAll()
	RefreshBucket()
end

function Preview:ClearStickyHosts()
    if SarychUI.OptionsPool then return SarychUI.OptionsPool:ClearPreviews(self) end
	for _, inst in ipairs(Preview._instances) do
		if inst then
			if inst.SetBackdrop then
				inst:SetBackdrop(nil)
			end
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	Preview._instances = {}
end

local function MakePreviewButton(parent, index)
	local btn = CreateFrame("Frame", nil, parent, nil, "action_bars.preview:1")
	btn:SetSize(44, 44)

	local slot = btn:CreateTexture(nil, "BACKGROUND")
	slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	slot:SetSize(64, 64)
	slot:SetPoint("CENTER", btn, "CENTER", 0, 0)
	btn._slot = slot

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(SAMPLE_ICONS[index] or SAMPLE_ICONS[1])
	icon:SetSize(36, 36)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	-- Hotkey (top-right), like Blizzard ActionButton HotKey.
	local hotkey = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	hotkey:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, -1)
	hotkey:SetJustifyH("RIGHT")
	hotkey:SetText(SAMPLE_HOTKEYS[index] or tostring(index))
	hotkey:SetTextColor(0.75, 0.75, 0.75)
	btn._hotkey = hotkey

	-- Macro name (bottom), like Blizzard ActionButton Name.
	local macro = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
	macro:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
	macro:SetJustifyH("CENTER")
	macro:SetWidth(40)
	macro:SetText(Tr(SAMPLE_MACROS[index] or ""))
	macro:SetTextColor(1, 1, 1)
	btn._macro = macro

	return btn
end

function Preview:Create(parent)
	self:ClearStickyHosts()

	local host, stage = SarychUI.OptionsPreviews:CreateHost(parent, 72)

	local buttons = {}
	local gap = 10
	local btnSize = 44
	local totalW = btnSize * 4 + gap * 3
	local startX = -totalW / 2 + btnSize / 2
	for i = 1, 4 do
		local btn = MakePreviewButton(stage, i)
		btn:SetPoint("CENTER", stage, "CENTER", startX + (i - 1) * (btnSize + gap), 0)
		buttons[i] = btn
	end
	host._buttons = buttons

	local function Layout()
		local hotkeyEnabled = GetSetting("hotkeyTextEnabled",
			GetSetting("hotkeyTextMode", "hide") == "custom" or GetSetting("hideHotkeysEnabled", true))
		local macroEnabled = GetSetting("macroTextEnabled",
			GetSetting("macroTextMode", "hide") == "custom" or GetSetting("hideMacroNames", true))
		local hotkeyMode = hotkeyEnabled and GetSetting("hotkeyTextMode", "hide") or "default"
		local macroMode = macroEnabled and GetSetting("macroTextMode", "hide") or "default"
		local hotkeyFont = GetPreviewFont(GetSetting("hotkeyFont", "Friz Quadrata TT"))
		local macroFont = GetPreviewFont(GetSetting("macroFont", "Friz Quadrata TT"))
		local macroColor = GetSetting("macroFontColor", { 1, 1, 1, 1 })
		for _, btn in ipairs(buttons) do
			local style = SarychUI_InterfaceStyle
			if style and style.enabled then
				local black = style:GetTextureMode() == "black"
				btn._slot:SetTexture(black and style.normalTexture or "Interface\\Buttons\\UI-Quickslot2")
				btn._slot:SetSize(black and 44 or 64, black and 44 or 64)
				local r, g, b, a = style.GetColor()
				local value = black and style:GetGlossBrightness()
				btn._slot:SetVertexColor(black and value or r,
					black and value or g, black and value or b, a)
			else
				btn._slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
				btn._slot:SetSize(64, 64)
				btn._slot:SetVertexColor(1, 1, 1, 1)
			end
			if hotkeyMode == "custom" then
				btn._hotkey:SetFont(hotkeyFont or "Fonts\\FRIZQT__.TTF", GetSetting("hotkeyFontSize", 12),
					GetSetting("hotkeyFontOutline", "NONE") == "NONE" and "" or GetSetting("hotkeyFontOutline", "NONE"))
			else
				btn._hotkey:SetFontObject(NumberFontNormalSmallGray)
			end
			if hotkeyMode == "hide" then
				btn._hotkey:SetAlpha(0)
			else
				btn._hotkey:SetAlpha(1)
			end
			if macroMode == "custom" then
				btn._macro:SetFont(macroFont or "Fonts\\FRIZQT__.TTF", GetSetting("macroFontSize", 12),
					GetSetting("macroFontOutline", "OUTLINE") == "NONE" and "" or GetSetting("macroFontOutline", "OUTLINE"))
				btn._macro:SetTextColor(macroColor[1], macroColor[2], macroColor[3], macroColor[4] or 1)
			else
				btn._macro:SetFontObject(GameFontHighlightSmallOutline)
				btn._macro:SetTextColor(1, 1, 1, 1)
			end
			if macroMode == "hide" then
				btn._macro:Hide()
			else
				btn._macro:Show()
			end
		end
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	TrackInstance(host)
	Layout()
	return host
end

--------------------------------------------------------------------
-- Color indication preview: 4 buttons (cooldown / mana / range / unusable)
--------------------------------------------------------------------
SarychUI.ActionBarColorPreview = SarychUI.ActionBarColorPreview or {}
local ColorPreview = SarychUI.ActionBarColorPreview
ColorPreview._instances = ColorPreview._instances or {}

local COLOR_LABELS = { SarychUI:T("ui.options_66182d457f"), SarychUI:T("ui.options_6af92380f7"), SarychUI:T("ui.options_3dfacb0e17"), SarychUI:T("ui.options_949ac1f255") }

local function TrackColorInstance(host)
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(ColorPreview, host) else tinsert(ColorPreview._instances, host) end
end

local function RefreshColorBucket()
	local alive = {}
	for _, inst in ipairs(ColorPreview._instances) do
		if inst and inst.GetParent and inst:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	ColorPreview._instances = alive
end

function ColorPreview:RefreshAll()
	RefreshColorBucket()
end

function ColorPreview:ClearStickyHosts()
    if SarychUI.OptionsPool then return SarychUI.OptionsPool:ClearPreviews(self) end
	for _, inst in ipairs(ColorPreview._instances) do
		if inst then
			if inst.SetBackdrop then
				inst:SetBackdrop(nil)
			end
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	ColorPreview._instances = {}
end

local function MakeColorPreviewButton(parent, index)
	local btn = CreateFrame("Frame", nil, parent, nil, "action_bars.preview:2")
	btn:SetSize(44, 44)

	local slot = btn:CreateTexture(nil, "BACKGROUND")
	slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	slot:SetSize(64, 64)
	slot:SetPoint("CENTER", btn, "CENTER", 0, 0)
	btn._slot = slot

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(SAMPLE_ICONS[index] or SAMPLE_ICONS[1])
	icon:SetSize(36, 36)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	btn._icon = icon

	return btn
end

local function ResetIconNormal(icon)
	icon:SetDesaturated(false)
	icon:SetVertexColor(1, 1, 1)
	icon:SetAlpha(1)
end

-- Matches panelColor.lua indication colors.
local function ApplyCooldownLook(icon, enabled, r, g, b, alpha)
	if enabled then
		icon:SetDesaturated(true)
		icon:SetVertexColor(r, g, b)
		icon:SetAlpha(alpha or 1)
	else
		ResetIconNormal(icon)
	end
end

local function ApplyManaLook(icon, enabled, r, g, b, alpha)
	if enabled then
		icon:SetDesaturated(false)
		icon:SetVertexColor(r, g, b)
		icon:SetAlpha(alpha or 1)
	else
		ResetIconNormal(icon)
	end
end

local function ApplyRangeLook(icon, enabled, r, g, b, alpha)
	if enabled then
		icon:SetDesaturated(false)
		icon:SetVertexColor(r, g, b)
		icon:SetAlpha(alpha or 1)
	else
		ResetIconNormal(icon)
	end
end

local function ApplyUnusableLook(icon, enabled, r, g, b, alpha)
	if enabled then
		icon:SetDesaturated(false)
		icon:SetVertexColor(r, g, b)
		icon:SetAlpha(alpha or 1)
	else
		ResetIconNormal(icon)
	end
end

function ColorPreview:Create(parent)
	self:ClearStickyHosts()

	local host, stage = SarychUI.OptionsPreviews:CreateHost(parent, 88)

	local buttons = {}
	local gap = 10
	local btnSize = 44
	local totalW = btnSize * 4 + gap * 3
	local startX = -totalW / 2 + btnSize / 2
	for i = 1, 4 do
		local btn = MakeColorPreviewButton(stage, i)
		btn:SetPoint("CENTER", stage, "CENTER", startX + (i - 1) * (btnSize + gap), 6)
		local caption = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		caption:SetPoint("TOP", btn, "BOTTOM", 0, -2)
		caption:SetText(Tr(COLOR_LABELS[i] or ""))
		caption:SetTextColor(0.7, 0.7, 0.7)
		buttons[i] = btn
	end
	host._buttons = buttons

	local function Layout()
		local style = SarychUI_InterfaceStyle
		for _, btn in ipairs(buttons) do
			if style and style.enabled then
				local black = style:GetTextureMode() == "black"
				btn._slot:SetTexture(black and style.normalTexture or "Interface\\Buttons\\UI-Quickslot2")
				btn._slot:SetSize(black and 44 or 64, black and 44 or 64)
				local r, g, b, a = style.GetColor()
				local value = black and style:GetGlossBrightness()
				btn._slot:SetVertexColor(black and value or r,
					black and value or g, black and value or b, a)
			else
				btn._slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
				btn._slot:SetSize(64, 64)
				btn._slot:SetVertexColor(1, 1, 1, 1)
			end
		end
		local cdOn = GetSetting("colorCooldownEnabled", false)
		local manaOn = GetSetting("colorManaEnabled", false)
		local rangeOn = GetSetting("colorRangeEnabled", false)
		local unusableOn = GetSetting("colorUnusableEnabled", false)
		local cdR, cdG, cdB, cdA = GetIndicationColor("colorCooldownColor")
		local manaR, manaG, manaB, manaA = GetIndicationColor("colorManaColor")
		local rangeR, rangeG, rangeB, rangeA = GetIndicationColor("colorRangeColor")
		local unusableR, unusableG, unusableB, unusableA = GetIndicationColor("colorUnusableColor")

		ApplyCooldownLook(buttons[1]._icon, cdOn, cdR, cdG, cdB, cdA)
		ApplyManaLook(buttons[2]._icon, manaOn, manaR, manaG, manaB, manaA)
		ApplyRangeLook(buttons[3]._icon, rangeOn, rangeR, rangeG, rangeB, rangeA)
		ApplyUnusableLook(buttons[4]._icon, unusableOn, unusableR, unusableG, unusableB, unusableA)
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	TrackColorInstance(host)
	Layout()
	return host
end

--------------------------------------------------------------------
-- Appearance / visual improvements preview
-- Layout copied from Blizzard 3.3.5 FrameXML/MainMenuBar.xml
-- (+ ActionBarFrame.xml page buttons, MainMenuBarBagButtons.xml keyring,
--   BonusActionBarFrame.xml shapeshift backgrounds). No action buttons.
--------------------------------------------------------------------
SarychUI.ActionBarAppearancePreview = SarychUI.ActionBarAppearancePreview or {}
local AppearancePreview = SarychUI.ActionBarAppearancePreview
AppearancePreview._instances = AppearancePreview._instances or {}

-- Original MainMenuBar is 1024 wide; scale to fit options content.
local APPEARANCE_SCALE = 0.42
local BAR_W, BAR_H = 1024, 53
local BFA_MEDIA = [[Interface\AddOns\SarychUI\media\mainmenubar\bfa\]]
local CENTRAL_MULTILEVEL_MEDIA = [[Interface\AddOns\SarychUI\media\mainmenubar\central_multilevel\]]
-- Extra room for EndCaps (128 tall, extend past bar) + shapeshift strip above.
local CANVAS_W, CANVAS_H = 1216, 180

local function TrackAppearanceInstance(host)
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(AppearancePreview, host) else tinsert(AppearancePreview._instances, host) end
end

local function RefreshAppearanceBucket()
	local alive = {}
	for _, inst in ipairs(AppearancePreview._instances) do
		if inst and inst.GetParent and inst:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	AppearancePreview._instances = alive
end

function AppearancePreview:RefreshAll()
	RefreshAppearanceBucket()
end

function AppearancePreview:ClearStickyHosts()
    if SarychUI.OptionsPool then return SarychUI.OptionsPool:ClearPreviews(self) end
	for _, inst in ipairs(AppearancePreview._instances) do
		if inst then
			if inst.SetBackdrop then
				inst:SetBackdrop(nil)
			end
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	AppearancePreview._instances = {}
end

local function SetShown(region, shown)
	if not region then return end
	if shown then region:Show() else region:Hide() end
end

local function MakeTex(parent, layer, file, w, h, point, rel, relPoint, x, y, l, r, t, b)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK")
	tex:SetTexture(file)
	tex:SetSize(w, h)
	tex:SetPoint(point or "BOTTOM", rel or parent, relPoint or point or "BOTTOM", x or 0, y or 0)
	if l then
		tex:SetTexCoord(l, r, t, b)
	end
	return tex
end

function AppearancePreview:Create(parent)
	self:ClearStickyHosts()

	local host, stage = SarychUI.OptionsPreviews:CreateHost(parent, ceil(CANVAS_H * APPEARANCE_SCALE) + 16)

	-- Unscaled canvas; whole composition is scaled to fit the options panel.
	local canvas = CreateFrame("Frame", nil, stage, nil, "action_bars.preview:3")
	canvas:SetSize(CANVAS_W, CANVAS_H)
	canvas:SetScale(APPEARANCE_SCALE)
	canvas:SetPoint("CENTER", stage, "CENTER", 0, 0)

	-- MainMenuBarArtFrame equivalent (1024 x 53), centered in canvas.
	local art = CreateFrame("Frame", nil, canvas, nil, "action_bars.preview:4")
	art:SetSize(BAR_W, BAR_H)
	art:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 8)

	--------------------------------------------------------------------
	-- MainMenuBarTexture0..3 - Interface\MainMenuBar\UI-MainMenuBar-Dwarf
	--------------------------------------------------------------------
	local barTex = {}
	local barSlices = {
		{ x = -384, top = 0.83203125, bottom = 1.0 },
		{ x = -128, top = 0.58203125, bottom = 0.75 },
		{ x = 128, top = 0.33203125, bottom = 0.5 },
		{ x = 384, top = 0.08203125, bottom = 0.25 },
	}
	for i, slice in ipairs(barSlices) do
		barTex[i] = MakeTex(
			art, "ARTWORK",
			"Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf",
			256, 43,
			"BOTTOM", art, "BOTTOM", slice.x, 0,
			0, 1, slice.top, slice.bottom
		)
	end

	--------------------------------------------------------------------
	-- BFA-style replacement artwork.  The 806-wide frame mirrors the
	-- in-game layout while the outer 1024-wide frame remains the classic
	-- preview canvas.
	--------------------------------------------------------------------
	local bfaArt = CreateFrame("Frame", nil, art, nil, "action_bars.preview:5")
	bfaArt:SetSize(806, BAR_H)
	bfaArt:SetPoint("BOTTOM", art, "BOTTOM", 0, 0)
	local bfaMain = {
		MakeTex(bfaArt, "ARTWORK", BFA_MEDIA .. "main_bar_left.blp", 256, 256,
			"BOTTOM", bfaArt, "BOTTOM", -275, 0),
		MakeTex(bfaArt, "ARTWORK", BFA_MEDIA .. "main_bar_center.blp", 256, 256,
			"BOTTOM", bfaArt, "BOTTOM", -19, 0),
		MakeTex(bfaArt, "ARTWORK", BFA_MEDIA .. "main_bar_right.blp", 256, 256,
			"BOTTOM", bfaArt, "BOTTOM", 237, 0),
		MakeTex(bfaArt, "ARTWORK", BFA_MEDIA .. "main_bar_endcap.blp", 256, 256,
			"BOTTOMRIGHT", bfaArt, "BOTTOMRIGHT", 2, 0),
	}
	local bfaTray = MakeTex(
		art, "BACKGROUND", BFA_MEDIA .. "right_tray.blp", 512, 256,
		"BOTTOM", art, "BOTTOM", 340, -22
	)

	--------------------------------------------------------------------
	-- End caps (gryphons) - UI-MainMenuBar-EndCap-Dwarf
	--------------------------------------------------------------------
	local leftCap = MakeTex(
		art, "OVERLAY",
		"Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf",
		128, 128,
		"BOTTOM", art, "BOTTOM", -544, 0
	)
	local rightCap = MakeTex(
		art, "OVERLAY",
		"Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf",
		128, 128,
		"BOTTOM", art, "BOTTOM", 544, 0,
		1, 0, 0, 1
	)

	--------------------------------------------------------------------
	-- Page number - CENTER +30, -5
	--------------------------------------------------------------------
	local pageNum = art:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pageNum:SetPoint("CENTER", art, "CENTER", 30, -5)
	pageNum:SetText("1")

	--------------------------------------------------------------------
	-- ActionBarUp/Down - TOPLEFT +522, -22 / -42
	--------------------------------------------------------------------
	local pageUp = MakeTex(
		art, "OVERLAY",
		"Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Up",
		32, 32,
		"CENTER", art, "TOPLEFT", 522, -22
	)
	local pageDown = MakeTex(
		art, "OVERLAY",
		"Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Up",
		32, 32,
		"CENTER", art, "TOPLEFT", 522, -42
	)

	--------------------------------------------------------------------
	-- KeyRingButton - right of bag slots chain (no bag buttons drawn).
	-- Backpack BOTTOMRIGHT -6,2 size 37; bags 30 wide with -5/-4 gaps;
	-- KeyRing RIGHT of CharacterBag3Slot LEFT -6, size 18x39.
	--------------------------------------------------------------------
	-- backpackLeft = 1024 - 6 - 37 = 981
	-- bag0Left = 981 - 5 - 30 = 946
	-- bag1Left = 946 - 4 - 30 = 912
	-- bag2Left = 912 - 4 - 30 = 878
	-- bag3Left = 878 - 4 - 30 = 844
	-- keyringRight = 844 - 6 = 838 -> left = 820
	local keyring = MakeTex(
		art, "OVERLAY",
		"Interface\\Buttons\\UI-Button-KeyRing",
		18, 39,
		"BOTTOMLEFT", art, "BOTTOMLEFT", 820, 2,
		0, 0.5625, 0, 0.609375
	)

	--------------------------------------------------------------------
	-- MainMenuBarMaxLevelBar - TOP of MainMenuBar -11, height 7
	--------------------------------------------------------------------
	local maxBar = CreateFrame("Frame", nil, art, nil, "action_bars.preview:6")
	maxBar:SetSize(BAR_W, 7)
	maxBar:SetPoint("TOP", art, "TOP", 0, -11)
	local maxSlices = {
		{ top = 0, bottom = 0.21875 },
		{ top = 0.25, bottom = 0.46875 },
		{ top = 0.5, bottom = 0.71875 },
		{ top = 0.75, bottom = 0.96875 },
	}
	local maxPrev
	local maxTextures = {}
	for i, slice in ipairs(maxSlices) do
		local tex = maxBar:CreateTexture(nil, "BACKGROUND")
		tex:SetTexture("Interface\\MainMenuBar\\UI-MainMenuBar-MaxLevel")
		tex:SetSize(256, 7)
		tex:SetTexCoord(0, 1, slice.top, slice.bottom)
		if i == 1 then
			tex:SetPoint("BOTTOM", maxBar, "TOP", -384, 0)
		else
			tex:SetPoint("LEFT", maxPrev, "RIGHT", 0, 0)
		end
		maxTextures[i] = tex
		maxPrev = tex
	end

	--------------------------------------------------------------------
	-- Secondary panel backgrounds (shapeshift / pet / possess)
	-- ShapeshiftBarLeft/Middle/Right from BonusActionBarFrame.xml
	--------------------------------------------------------------------
	local secondary = CreateFrame("Frame", nil, canvas, nil, "action_bars.preview:7")
	secondary:SetSize(127, 38) -- 47 + 37 + 43
	secondary:SetPoint("BOTTOMLEFT", art, "TOPLEFT", 30, 4)

	local stanceLeft = MakeTex(
		secondary, "ARTWORK",
		"Interface\\ShapeshiftBar\\ShapeshiftBar",
		47, 38,
		"BOTTOMLEFT", secondary, "BOTTOMLEFT", 0, 0,
		0, 0.734375, 0, 0.296875
	)
	local stanceMid = MakeTex(
		secondary, "ARTWORK",
		"Interface\\ShapeshiftBar\\ShapeshiftBarMiddle",
		37, 38,
		"LEFT", stanceLeft, "RIGHT", 0, 0,
		0, 1, 0, 1
	)
	MakeTex(
		secondary, "ARTWORK",
		"Interface\\ShapeshiftBar\\ShapeshiftBar",
		43, 38,
		"LEFT", stanceMid, "RIGHT", 0, 0,
		0.328125, 1, 0.3125, 0.6015625
	)

	-- Pet sliding bar textures (same secondary-backgrounds toggle).
	local petBar = CreateFrame("Frame", nil, canvas, nil, "action_bars.preview:8")
	petBar:SetSize(440, 44)
	petBar:SetPoint("LEFT", secondary, "RIGHT", 12, 0)
	local pet0 = MakeTex(
		petBar, "ARTWORK",
		"Interface\\PetActionBar\\UI-PetBar",
		256, 44,
		"TOPLEFT", petBar, "TOPLEFT", 0, 0,
		0, 1, 0.015625, 0.359375
	)
	MakeTex(
		petBar, "ARTWORK",
		"Interface\\PetActionBar\\UI-PetBar",
		184, 44,
		"LEFT", pet0, "RIGHT", 0, 0,
		0, 0.71875, 0.375, 0.71875
	)

	local emptyNotice = stage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyNotice:SetPoint("CENTER", stage, "CENTER", 0, 0)
	emptyNotice:SetText(Tr(SarychUI:T("ui.options_f848a83ffe")))
	emptyNotice:SetTextColor(0.7, 0.7, 0.7)
	emptyNotice:Hide()

	local function Layout()
		local isBFA = GetSetting("barStyle", "classic") == "bfa"
		local hideGryphons = GetSetting("hideGryphons", false)
		local hideBarBg = GetSetting("hideActionBarBackgrounds", false)
		local hideTray = GetSetting("hideBagMicroMenuBackground", true)
		local hideSecondary = GetSetting("hideSecondaryPanelsBackgrounds", false)
		local hideMax = GetSetting("hideMaxLevelBar", false)
		local hideKeyring = GetSetting("hideKeyringButton", false)
		local hidePageBtns = GetSetting("hidePageButtons", false)
		local hidePageNums = GetSetting("hidePageNumbers", false)

		leftCap:ClearAllPoints()
		rightCap:ClearAllPoints()
		if isBFA then
			leftCap:SetSize(115, 115)
			rightCap:SetSize(115, 115)
			leftCap:SetPoint("BOTTOM", bfaArt, "BOTTOM", -431, 0)
			rightCap:SetPoint("BOTTOM", bfaArt, "BOTTOM", 431, 0)
		else
			leftCap:SetSize(128, 128)
			rightCap:SetSize(128, 128)
			leftCap:SetPoint("BOTTOM", art, "BOTTOM", -544, 0)
			rightCap:SetPoint("BOTTOM", art, "BOTTOM", 544, 0)
		end
		SetShown(leftCap, not hideGryphons)
		SetShown(rightCap, not hideGryphons)

		for _, tex in ipairs(barTex) do
			SetShown(tex, not isBFA and not hideBarBg)
		end
		for _, tex in ipairs(bfaMain) do
			SetShown(tex, isBFA and not hideBarBg)
		end
		SetShown(bfaTray, isBFA and not hideTray)

		maxBar:ClearAllPoints()
		if isBFA then
			maxBar:SetSize(256, 9)
			maxBar:SetPoint("CENTER", bfaArt, "CENTER", 109, 11)
			for index = 1, 3 do
				local tex = maxTextures[index]
				tex:ClearAllPoints()
				tex:SetTexture(BFA_MEDIA .. "max_level_bar.blp")
				tex:SetSize(256, 7)
				if index == 2 then
					tex:SetTexCoord(0, 1, 0.25, 0.46875)
				else
					tex:SetTexCoord(0, 1, 0, 0.21875)
				end
				if index == 1 then
					tex:SetPoint("BOTTOM", maxBar, "TOP", -384, 0)
				else
					tex:SetPoint("LEFT", maxTextures[index - 1], "RIGHT", 0, 0)
				end
			end
			local cap = maxTextures[4]
			cap:ClearAllPoints()
			cap:SetTexture(BFA_MEDIA .. "max_level_bar_alt.blp")
			cap:SetSize(38, 7)
			cap:SetTexCoord(0, 38 / 256, 0.5, 0.71875)
			cap:SetPoint("LEFT", maxTextures[3], "RIGHT", 0, 0)
		else
			maxBar:SetSize(BAR_W, 7)
			maxBar:SetPoint("TOP", art, "TOP", 0, -11)
			for index, tex in ipairs(maxTextures) do
				local slice = maxSlices[index]
				tex:ClearAllPoints()
				tex:SetTexture("Interface\\MainMenuBar\\UI-MainMenuBar-MaxLevel")
				tex:SetSize(256, 7)
				tex:SetTexCoord(0, 1, slice.top, slice.bottom)
				if index == 1 then
					tex:SetPoint("BOTTOM", maxBar, "TOP", -384, 0)
				else
					tex:SetPoint("LEFT", maxTextures[index - 1], "RIGHT", 0, 0)
				end
			end
		end

		SetShown(secondary, not hideSecondary)
		SetShown(petBar, not hideSecondary)
		SetShown(maxBar, not hideMax)
		SetShown(keyring, not hideKeyring)
		SetShown(pageUp, not hidePageBtns)
		SetShown(pageDown, not hidePageBtns)
		SetShown(pageNum, not hidePageNums)

		local trayHidden = (not isBFA) or hideTray
		local allHidden = hideGryphons and hideBarBg and trayHidden and hideSecondary
			and hideMax and hideKeyring and hidePageBtns and hidePageNums
		SetShown(emptyNotice, allHidden)
		SetShown(canvas, not allHidden)
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	TrackAppearanceInstance(host)
	Layout()
	return host
end

--------------------------------------------------------------------
-- Transparency preview: action button border + full micro menu
--------------------------------------------------------------------
SarychUI.ActionBarTransparencyPreview = SarychUI.ActionBarTransparencyPreview or {}
local TransparencyPreview = SarychUI.ActionBarTransparencyPreview
TransparencyPreview._instances = TransparencyPreview._instances or {}

-- Order matches MainMenuBarMicroButtons.xml (3.3.5).
local MICRO_DF_TEX = [[Interface\AddOns\SarychUI\media\micromenu\uimicromenu2x]]
local MICRO_BUTTONS = {
	{ file = "Interface\\Buttons\\UI-MicroButtonCharacter-Up", portrait = true, dfKey = "character" },
	{ file = "Interface\\Buttons\\UI-MicroButton-Spellbook-Up", dfKey = "spellbook" },
	{ file = "Interface\\Buttons\\UI-MicroButton-Talent-Up", dfKey = "talent" },
	{ file = "Interface\\Buttons\\UI-MicroButton-Achievement-Up", dfKey = "achievement" },
	{ file = "Interface\\Buttons\\UI-MicroButton-Quest-Up", dfKey = "questlog" },
	{ file = "Interface\\Buttons\\UI-MicroButton-Socials-Up", dfKey = "socials" },
	{ file = "Interface\\Buttons\\UI-MicroButton-PVP-Up", dfKey = "pvp" },
	{ file = "Interface\\Buttons\\UI-MicroButton-LFG-Up", dfKey = "lfd" },
	{ file = "Interface\\Buttons\\UI-MicroButton-MainMenu-Up", dfKey = "mainmenu" },
	{ file = "Interface\\Buttons\\UI-MicroButton-Help-Up", dfKey = "help" },
}

-- DF atlas "up" coords (same as panelVisual)
local MICRO_DF_UP = {
	character = { 1 / 256, 39 / 256, 325 / 512, 377 / 512 },
	spellbook = { 121 / 256, 159 / 256, 55 / 512, 107 / 512 },
	talent = { 161 / 256, 199 / 256, 1 / 512, 53 / 512 },
	achievement = { 161 / 256, 199 / 256, 109 / 512, 161 / 512 },
	questlog = { 201 / 256, 239 / 256, 271 / 512, 323 / 512 },
	socials = { 41 / 256, 79 / 256, 55 / 512, 107 / 512 },
	pvp = { 1 / 256, 39 / 256, 271 / 512, 323 / 512 },
	lfd = { 1 / 256, 39 / 256, 163 / 512, 215 / 512 },
	mainmenu = { 1 / 256, 39 / 256, 109 / 512, 161 / 512 },
	help = { 201 / 256, 239 / 256, 217 / 512, 269 / 512 },
}

local function TrackTransparencyInstance(host)
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(TransparencyPreview, host) else tinsert(TransparencyPreview._instances, host) end
end

local function RefreshTransparencyBucket()
	local alive = {}
	for _, inst in ipairs(TransparencyPreview._instances) do
		if inst and inst.GetParent and inst:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	TransparencyPreview._instances = alive
end

function TransparencyPreview:RefreshAll()
	RefreshTransparencyBucket()
end

function TransparencyPreview:ClearStickyHosts()
    if SarychUI.OptionsPool then return SarychUI.OptionsPool:ClearPreviews(self) end
	for _, inst in ipairs(TransparencyPreview._instances) do
		if inst then
			if inst.SetBackdrop then
				inst:SetBackdrop(nil)
			end
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	TransparencyPreview._instances = {}
end

function TransparencyPreview:Create(parent)
	self:ClearStickyHosts()

	local host, stage = SarychUI.OptionsPreviews:CreateHost(parent, 168)

	--------------------------------------------------------------------
	-- Action button sample (icon + NormalTexture border = UI-Quickslot2)
	--------------------------------------------------------------------
	local actionWrap = CreateFrame("Frame", nil, stage, nil, "action_bars.preview:9")
	actionWrap:SetSize(44, 44)
	actionWrap:SetPoint("LEFT", stage, "LEFT", 16, 8)

	local actionCaption = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	actionCaption:SetPoint("BOTTOM", actionWrap, "TOP", 0, 4)
	actionCaption:SetText(Tr(SarychUI:T("ui.options_1cee14f351")))
	actionCaption:SetTextColor(0.7, 0.7, 0.7)

	local icon = actionWrap:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(SAMPLE_ICONS[2] or SAMPLE_ICONS[1])
	icon:SetSize(36, 36)
	icon:SetPoint("CENTER", actionWrap, "CENTER", 0, 0)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	-- Border / NormalTexture - this is what buttonBorderAlpha changes.
	local border = actionWrap:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	border:SetSize(64, 64)
	border:SetPoint("CENTER", actionWrap, "CENTER", 0, 0)
	actionWrap._border = border

	--------------------------------------------------------------------
	-- Micro menu row - original 28x58 buttons, -3 overlap between them
	--------------------------------------------------------------------
	local microWrap = CreateFrame("Frame", nil, stage, nil, "action_bars.preview:10")
	-- 10 * 28 + 9 * (-3) = 280 - 27 = 253
	microWrap:SetSize(253, 58)
	microWrap:SetPoint("TOPLEFT", actionWrap, "TOPRIGHT", 36, 7)

	local microCaption = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	microCaption:SetPoint("BOTTOM", microWrap, "TOP", 0, 4)
	microCaption:SetText(Tr(SarychUI:T("ui.micro_menu_0fc8f435")))
	microCaption:SetTextColor(0.7, 0.7, 0.7)

	local microTextures = {}
	local microButtons = {}
	local prev
	-- Classic button frames stay 28x58; DF only resizes the drawn texture.
	local classicW, classicH, classicGap = 28, 58, -3
	local dfTexW, dfTexH = 14 * 1.4, 19 * 1.4
	microWrap:SetSize(253, 58)

	for i, info in ipairs(MICRO_BUTTONS) do
		local btn = CreateFrame("Frame", nil, microWrap, nil, "action_bars.preview:11")
		btn:SetSize(classicW, classicH)
		if i == 1 then
			btn:SetPoint("BOTTOMLEFT", microWrap, "BOTTOMLEFT", 0, 0)
		else
			btn:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", classicGap, 0)
		end

		local tex = btn:CreateTexture(nil, "ARTWORK")
		tex:SetTexture(info.file)
		tex:SetAllPoints(btn)
		btn._tex = tex
		btn._info = info
		tinsert(microTextures, tex)
		tinsert(microButtons, btn)

		if info.portrait then
			local portrait = btn:CreateTexture(nil, "OVERLAY")
			portrait:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait-Male-Human")
			portrait:SetSize(18, 25)
			portrait:SetPoint("TOP", btn, "TOP", 0, -28)
			portrait:SetTexCoord(0.2, 0.8, 0.0666, 0.9)
			btn._portrait = portrait
		end

		prev = btn
	end

	--------------------------------------------------------------------
	-- Bag bar sample: backpack + 4 bag slots
	--------------------------------------------------------------------
	local BAG_PREVIEW = {
		"Interface\\Buttons\\Button-Backpack-Up",
		"Interface\\Icons\\INV_Misc_Bag_08",
		"Interface\\Icons\\INV_Misc_Bag_09",
		"Interface\\Icons\\INV_Misc_Bag_10",
		"Interface\\Icons\\INV_Misc_Bag_11",
	}
	local bagWrap = CreateFrame("Frame", nil, stage, nil, "action_bars.preview:12")
	local bagSize, bagGap = 28, 2
	bagWrap:SetSize(#BAG_PREVIEW * bagSize + (#BAG_PREVIEW - 1) * bagGap, bagSize)
	bagWrap:SetPoint("TOPLEFT", actionWrap, "BOTTOMLEFT", -6, -18)

	local bagCaption = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	bagCaption:SetPoint("BOTTOM", bagWrap, "TOP", 0, 4)
	bagCaption:SetText(Tr(SarychUI:T("ui.bags_a5b99f75")))
	bagCaption:SetTextColor(0.7, 0.7, 0.7)

	local bagButtons = {}
	prev = nil
	for i, file in ipairs(BAG_PREVIEW) do
		local btn = CreateFrame("Frame", nil, bagWrap, nil, "action_bars.preview:13")
		btn:SetSize(bagSize, bagSize)
		if i == 1 then
			btn:SetPoint("LEFT", bagWrap, "LEFT", 0, 0)
		else
			btn:SetPoint("LEFT", prev, "RIGHT", bagGap, 0)
		end

		local icon = btn:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(file)
		icon:SetPoint("TOPLEFT", 2, -2)
		icon:SetPoint("BOTTOMRIGHT", -2, 2)
		if i > 1 then
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end

		local rim = btn:CreateTexture(nil, "OVERLAY")
		rim:SetTexture("Interface\\Buttons\\UI-Quickslot2")
		rim:SetPoint("CENTER")
		rim:SetSize(bagSize + 14, bagSize + 14)
		btn._icon = icon
		btn._rim = rim
		tinsert(bagButtons, btn)
		prev = btn
	end

	local function Layout()
		local borderOn = GetSetting("buttonBorderAlphaEnabled", false)
		local borderAlpha = GetSetting("buttonBorderAlpha", 0.4) or 0.4
		local style = SarychUI_InterfaceStyle
		local newTextures = style and style.enabled and style:GetTextureMode() == "black"
		local rimPath = newTextures and style.normalTexture or "Interface\\Buttons\\UI-Quickslot2"
		local function SetRim(rim, classicSize, isBag)
			rim:SetTexture(isBag and "Interface\\Buttons\\UI-Quickslot2" or rimPath)
			rim:SetSize(classicSize, classicSize)
			if style and style.enabled then
				local r, g, b, a = style.GetColor()
				if not isBag and newTextures then
					local value = style:GetGlossBrightness()
					rim:SetVertexColor(value, value, value, a)
				else
					rim:SetVertexColor(r, g, b, a)
				end
			else
				rim:SetVertexColor(1, 1, 1, 1)
			end
			rim:SetAlpha(newTextures and 1 or (borderOn and borderAlpha or 1))
		end
		SetRim(border, newTextures and 44 or 64)
		local crop = 0.07
		icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)

		local useDf = GetSetting("microMenuStyle", "dragonflight") == "dragonflight"
		for _, btn in ipairs(microButtons) do
			local info = btn._info
			local tex = btn._tex
			tex:ClearAllPoints()
			if useDf then
				local c = info and MICRO_DF_UP[info.dfKey]
				if c then
					tex:SetTexture(MICRO_DF_TEX)
					tex:SetTexCoord(c[1], c[2], c[3], c[4])
				end
				tex:SetWidth(dfTexW)
				tex:SetHeight(dfTexH)
				tex:SetPoint("BOTTOM", btn, "BOTTOM", 0, 0)
				if btn._portrait then
					btn._portrait:SetAlpha(0)
				end
			else
				tex:SetTexture(info.file)
				tex:SetTexCoord(0, 1, 0, 1)
				tex:SetAllPoints(btn)
				if btn._portrait then
					btn._portrait:SetAlpha(1)
				end
			end
		end

		local microOn = GetSetting("microMenuAlphaEnabled", false)
		local microAlpha = GetSetting("microMenuAlpha", 0.95) or 0.95
		local a = microOn and microAlpha or 1
		for _, tex in ipairs(microTextures) do
			tex:SetAlpha(a)
		end

		local bagOn = GetSetting("bagAlphaEnabled", false)
		local bagAlpha = GetSetting("bagAlpha", 0.95) or 0.95
		local bagA = bagOn and bagAlpha or 1
		for _, btn in ipairs(bagButtons) do
			btn:SetAlpha(bagA)
			if btn._icon then btn._icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop) end
			if btn._rim then
				SetRim(btn._rim, bagSize + 14, true)
			end
		end
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	TrackTransparencyInstance(host)
	Layout()
	return host
end

--------------------------------------------------------------------
-- Bars preview: MainMenuExpBar + ReputationWatchBar (3.3.5 FrameXML)
--------------------------------------------------------------------
SarychUI.ActionBarBarsPreview = SarychUI.ActionBarBarsPreview or {}
local BarsPreview = SarychUI.ActionBarBarsPreview
BarsPreview._instances = BarsPreview._instances or {}

local BARS_SCALE = 0.42
local BARS_CANVAS_W, BARS_CANVAS_H = 1024, 90

local function TrackBarsInstance(host)
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(BarsPreview, host) else tinsert(BarsPreview._instances, host) end
end

local function RefreshBarsBucket()
	local alive = {}
	for _, inst in ipairs(BarsPreview._instances) do
		if inst and inst.GetParent and inst:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	BarsPreview._instances = alive
end

function BarsPreview:RefreshAll()
	RefreshBarsBucket()
end

function BarsPreview:ClearStickyHosts()
    if SarychUI.OptionsPool then return SarychUI.OptionsPool:ClearPreviews(self) end
	for _, inst in ipairs(BarsPreview._instances) do
		if inst then
			if inst.SetBackdrop then
				inst:SetBackdrop(nil)
			end
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	BarsPreview._instances = {}
end

local function MakeStatusFill(parent, width, height, r, g, b, fillRatio)
	local fill = parent:CreateTexture(nil, "ARTWORK")
	fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	fill:SetVertexColor(r, g, b)
	fill:SetSize(width * (fillRatio or 0.55), height)
	fill:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	return fill
end

function BarsPreview:Create(parent)
	self:ClearStickyHosts()

	local host, stage = SarychUI.OptionsPreviews:CreateHost(parent, ceil(BARS_CANVAS_H * BARS_SCALE) + 16)

	local canvas = CreateFrame("Frame", nil, stage, nil, "action_bars.preview:14")
	canvas:SetSize(BARS_CANVAS_W, BARS_CANVAS_H)
	canvas:SetScale(BARS_SCALE)
	canvas:SetPoint("CENTER", stage, "CENTER", 0, 0)

	-- MainMenuBar art strip (context under the bars).
	local art = CreateFrame("Frame", nil, canvas, nil, "action_bars.preview:15")
	art:SetSize(1024, 43)
	art:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 0)
	local artSlices = {
		{ x = -384, top = 0.83203125, bottom = 1.0 },
		{ x = -128, top = 0.58203125, bottom = 0.75 },
		{ x = 128, top = 0.33203125, bottom = 0.5 },
		{ x = 384, top = 0.08203125, bottom = 0.25 },
	}
	local classicArt = {}
	for _, slice in ipairs(artSlices) do
		classicArt[#classicArt + 1] = MakeTex(
			art, "ARTWORK",
			"Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf",
			256, 43,
			"BOTTOM", art, "BOTTOM", slice.x, 0,
			0, 1, slice.top, slice.bottom
		)
	end
	local bfaBarsArt = CreateFrame("Frame", nil, art, nil, "action_bars.preview:16")
	bfaBarsArt:SetSize(806, 43)
	bfaBarsArt:SetPoint("BOTTOM", art, "BOTTOM", 0, 0)
	MakeTex(bfaBarsArt, "ARTWORK", BFA_MEDIA .. "main_bar_left.blp", 256, 256,
		"BOTTOM", bfaBarsArt, "BOTTOM", -275, 0)
	MakeTex(bfaBarsArt, "ARTWORK", BFA_MEDIA .. "main_bar_center.blp", 256, 256,
		"BOTTOM", bfaBarsArt, "BOTTOM", -19, 0)
	MakeTex(bfaBarsArt, "ARTWORK", BFA_MEDIA .. "main_bar_right.blp", 256, 256,
		"BOTTOM", bfaBarsArt, "BOTTOM", 237, 0)
	MakeTex(bfaBarsArt, "ARTWORK", BFA_MEDIA .. "main_bar_endcap.blp", 256, 256,
		"BOTTOMRIGHT", bfaBarsArt, "BOTTOMRIGHT", 2, 0)
	local function MakeDragonStatus(y, fill)
		local frame = CreateFrame("Frame", nil, canvas, nil, "action_bars.preview:17")
		frame:SetSize(466, 14)
		frame:SetPoint("BOTTOM", canvas, "BOTTOM", 1, y)
		MakeTex(frame, "BACKGROUND", CENTRAL_MULTILEVEL_MEDIA .. "xp\\Background.tga", 466, 14,
			"CENTER", frame, "CENTER", 0, 0, 0, 466/842, 0, 1)
		MakeTex(frame, "ARTWORK", CENTRAL_MULTILEVEL_MEDIA .. fill, 258, 14,
			"LEFT", frame, "LEFT", 0, 0)
		MakeTex(frame, "OVERLAY", CENTRAL_MULTILEVEL_MEDIA .. "xp\\Overlay.tga", 466, 16,
			"CENTER", frame, "CENTER", 0, 0, 0, 466/842, 0, 1)
		return frame
	end
	local dragonXp = MakeDragonStatus(7, "xp\\Main.tga")
	local dragonRep = MakeDragonStatus(23, "reputation\\RepGreen.tga")

	--------------------------------------------------------------------
	-- MainMenuExpBar - TOP of MainMenuBar, 1024x13
	--------------------------------------------------------------------
	local xpBar = CreateFrame("Frame", nil, canvas, nil, "action_bars.preview:18")
	xpBar:SetSize(1024, 13)
	xpBar:SetPoint("TOP", art, "TOP", 0, 0)

	MakeStatusFill(xpBar, 1024, 13, 0.58, 0.0, 0.55, 0.62)

	local xpOverlaySlices = {
		{ x = -384, top = 0.79296875, bottom = 0.83203125 },
		{ x = -128, top = 0.54296875, bottom = 0.58203125 },
		{ x = 128, top = 0.29296875, bottom = 0.33203125 },
		{ x = 384, top = 0.04296875, bottom = 0.08203125 },
	}
	local xpOverlayTextures = {}
	for _, slice in ipairs(xpOverlaySlices) do
		xpOverlayTextures[#xpOverlayTextures + 1] = MakeTex(
			xpBar, "OVERLAY",
			"Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf",
			256, 10,
			"BOTTOM", xpBar, "BOTTOM", slice.x, 3,
			0, 1, slice.top, slice.bottom
		)
	end

	local xpLabel = xpBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	xpLabel:SetPoint("CENTER", xpBar, "CENTER", 0, 1)
	xpLabel:SetText(Tr(SarychUI:T("ui.options_c10c712468")))

	--------------------------------------------------------------------
	-- ReputationWatchBar - BOTTOM of MainMenuBar TOP -3, 1024x11
	--------------------------------------------------------------------
	local repBar = CreateFrame("Frame", nil, canvas, nil, "action_bars.preview:19")
	repBar:SetSize(1024, 11)
	repBar:SetPoint("BOTTOM", art, "TOP", 0, -3)

	local repStatus = CreateFrame("Frame", nil, repBar, nil, "action_bars.preview:20")
	repStatus:SetSize(1024, 8)
	repStatus:SetPoint("TOP", repBar, "TOP", 0, 0)
	MakeStatusFill(repStatus, 1024, 8, 0.26, 1.0, 0.26, 0.48)

	local repOverlay = {
		{ top = 0, bottom = 0.171875 },
		{ top = 0.171875, bottom = 0.34375 },
		{ top = 0.34375, bottom = 0.515625 },
		{ top = 0.515625, bottom = 0.6875 },
	}
	local prevRep
	local repOverlayTextures = {}
	for i, slice in ipairs(repOverlay) do
		local tex = repBar:CreateTexture(nil, "OVERLAY")
		tex:SetTexture("Interface\\PaperDollInfoFrame\\UI-ReputationWatchBar")
		tex:SetSize(256, 11)
		tex:SetTexCoord(0, 1, slice.top, slice.bottom)
		if i == 1 then
			tex:SetPoint("TOPLEFT", repBar, "TOPLEFT", 0, 2)
		else
			tex:SetPoint("LEFT", prevRep, "RIGHT", 0, 0)
		end
		repOverlayTextures[i] = tex
		prevRep = tex
	end

	local repLabel = repBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	repLabel:SetPoint("CENTER", repBar, "CENTER", 0, 3)
	repLabel:SetText(Tr(SarychUI:T("ui.options_44ca73a50a")))

	local emptyNotice = stage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyNotice:SetPoint("CENTER", stage, "CENTER", 0, 0)
	emptyNotice:SetText(Tr(SarychUI:T("ui.options_f848a83ffe")))
	emptyNotice:SetTextColor(0.7, 0.7, 0.7)
	emptyNotice:Hide()

	local function Layout()
		local isBFA = GetSetting("barStyle", "classic") == "bfa"
		local isDragon = GetSetting("barStyle", "classic") == "dragon"
		local hideRep = GetSetting("hideReputationBar", false)
		local hideXp = GetSetting("hideExperienceBar", false)
		local hideXpOverlay = GetSetting("hideExperienceOverlayTextures", false)
		local hideRepOverlay = GetSetting("hideReputationOverlayTextures", false)

		for _, tex in ipairs(classicArt) do
			SetShown(tex, not isBFA and not isDragon)
		end
		SetShown(bfaBarsArt, isBFA and not isDragon)
		local xpTexture = isBFA
			and (BFA_MEDIA .. "experience_bar.blp")
			or "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
		for _, tex in ipairs(xpOverlayTextures) do
			tex:SetTexture(xpTexture)
			SetShown(tex, not hideXpOverlay)
		end
		local repTexture = isBFA
			and (BFA_MEDIA .. "reputation_bar.blp")
			or "Interface\\PaperDollInfoFrame\\UI-ReputationWatchBar"
		for _, tex in ipairs(repOverlayTextures) do
			tex:SetTexture(repTexture)
			SetShown(tex, not hideRepOverlay)
		end

		SetShown(repBar, not isDragon and not hideRep)
		SetShown(xpBar, not isDragon and not hideXp)
		dragonRep:ClearAllPoints()
		dragonRep:SetPoint("BOTTOM", canvas, "BOTTOM", 1, hideXp and 7 or 23)
		SetShown(dragonRep, isDragon and not hideRep)
		SetShown(dragonXp, isDragon and not hideXp)

		local allHidden = hideRep and hideXp
		SetShown(emptyNotice, allHidden)
		SetShown(canvas, not allHidden)
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	TrackBarsInstance(host)
	Layout()
	return host
end
