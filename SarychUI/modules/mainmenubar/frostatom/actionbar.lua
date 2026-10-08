-- Ported from FrostAtomUI Modules/ActionBar/ActionBar.lua.
-- Bars 1-6 (+ extra pages 7-10), stance / pet bars, shared button styling.
local FA = SarychUI.FrostAtomBars

local RegisterStateDriver = RegisterStateDriver
local GameTooltip = GameTooltip
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetCursorInfo = GetCursorInfo
local InCombatLockdown = InCombatLockdown
local max, min, ceil, floor = math.max, math.min, math.ceil, math.floor

local ActionBar = FA:NewModule("ActionBar")
FA.ActionBar = ActionBar

local config = FA.config
local BUTTONS_PER_BAR = 12
local NUM_BARS = 6
local FIRST_EXTRA_PAGE, LAST_EXTRA_PAGE = 7, 10
local BAR_KEYS = { "bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "stance", "pet" }
local AUTOCAST_BORDER_SCALE = 58 / 30

local PAGE_BINDINGS = {
	[1] = "ACTIONBUTTON%d",
	[3] = "MULTIACTIONBAR3BUTTON%d",
	[4] = "MULTIACTIONBAR4BUTTON%d",
	[5] = "MULTIACTIONBAR2BUTTON%d",
	[6] = "MULTIACTIONBAR1BUTTON%d",
}

ActionBar.NUM_BARS = NUM_BARS
ActionBar.BUTTONS_PER_BAR = BUTTONS_PER_BAR
ActionBar.FIRST_EXTRA_PAGE = FIRST_EXTRA_PAGE
ActionBar.LAST_EXTRA_PAGE = LAST_EXTRA_PAGE
ActionBar.BAR_KEYS = BAR_KEYS

ActionBar.bars = {}
ActionBar.petButtons = {}
ActionBar.shapeshiftButtons = {}

-- Resolve the config table of a bar key ("bar1".."bar10", "stance", "pet", ...).
function FA.BarConfig(key)
	local page = tonumber(key:match("^bar(%d+)$"))
	if page and page >= FIRST_EXTRA_PAGE then
		local extra = config.extraBars
		return extra and extra[key]
	end
	return config[key]
end

local BLIZZARD_BUTTON_SIZE = 36
local NORMAL_TEXTURE_SCALE = 66 / BLIZZARD_BUTTON_SIZE
local EQUIPPED_BORDER_SCALE = 62 / BLIZZARD_BUTTON_SIZE
local DEFAULT_PUSHED_TEXTURE = "Interface\\Buttons\\UI-Quickslot-Depress"

-- Preserve Blizzard artwork while giving Frost exclusive ownership of the
-- rendered binding label, as in the original FrostAtomUI implementation.
-- Reused pet/stance buttons keep updating their template label internally, so
-- optionally force that unused region to remain hidden after every Show().
function ActionBar:CreateOwnedHotkey(button, templateHotkey, suppressTemplateUpdates)
	if templateHotkey then
		templateHotkey:SetText("")
		templateHotkey:SetAlpha(0)
		templateHotkey:Hide()
		if suppressTemplateUpdates and hooksecurefunc then
			hooksecurefunc(templateHotkey, "Show", function(region)
				region:Hide()
			end)
		end
	end

	local hotkey = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmallGray")
	if templateHotkey and templateHotkey.GetPoint then
		local point, relativeTo, relativePoint, x, y = templateHotkey:GetPoint(1)
		if point then
			hotkey:SetPoint(point, relativeTo or button, relativePoint or point, x or 0, y or 0)
		else
			hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
		end
		local width, height = templateHotkey:GetWidth(), templateHotkey:GetHeight()
		if width and height and width > 0 and height > 0 then
			hotkey:SetSize(width, height)
		end
		local justifyH = templateHotkey.GetJustifyH and templateHotkey:GetJustifyH()
		local justifyV = templateHotkey.GetJustifyV and templateHotkey:GetJustifyV()
		if justifyH then hotkey:SetJustifyH(justifyH) end
		if justifyV then hotkey:SetJustifyV(justifyV) end
	else
		hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	end
	return hotkey
end

-- ActionButtonTemplate creates the artwork regions for us.  Keep those instead
-- of drawing a second skin; only the hotkey text is private because its alpha
-- must not be shared with Blizzard's binding refresh path.
function ActionBar:AdoptActionButtonArtwork(button)
	local name = button:GetName()
	-- Pin the exact 3.3.5 ActionButtonTemplate pressed artwork.  This also
	-- removes any texture inherited or supplied by another button skin before
	-- Frost adopts the frame.
	button:SetPushedTexture(DEFAULT_PUSHED_TEXTURE)
	button.icon = _G[name .. "Icon"]
	button.flash = _G[name .. "Flash"]
	-- ActionButtonTemplate provides a named Blizzard HotKey region.  The
	-- original Frost implementation deliberately owns a separate FontString;
	-- sharing the template region lets Blizzard/addon refreshes restore alpha 1
	-- behind SarychUI's visibility controller.  Keep the template artwork, but
	-- retire its HotKey and recreate only that region as Frost-owned text.
	local templateHotkey = _G[name .. "HotKey"]
	button.hotkey = self:CreateOwnedHotkey(button, templateHotkey, true)
	button.count = _G[name .. "Count"]
	button.name = _G[name .. "Name"]
	button.cooldown = _G[name .. "Cooldown"]
	button.equippedTexture = _G[name .. "Border"]
	button.checkedTexture = button:GetCheckedTexture()
	button.sarychDefaultActionArtwork = true
	button.sarychSupportsBorderAlpha = true
	button.sarychUsesActionText = true
	if button.equippedTexture then
		button.equippedTexture:SetVertexColor(0, 1, 0, 0.35)
	end

	if button.icon then
		button.icon:ClearAllPoints()
		button.icon:SetAllPoints(button)
	end
	if button.flash then
		button.flash:ClearAllPoints()
		button.flash:SetAllPoints(button)
	end
	local pushed = button:GetPushedTexture()
	if pushed then
		pushed:SetTexCoord(0, 1, 0, 1)
		pushed:SetVertexColor(1, 1, 1, 1)
		pushed:SetAlpha(1)
		pushed:SetBlendMode("BLEND")
	end
	for _, texture in ipairs({ pushed, button:GetHighlightTexture(), button:GetCheckedTexture() }) do
		if texture then
			texture:ClearAllPoints()
			texture:SetAllPoints(button)
		end
	end

	self:LayoutDefaultActionArtwork(button)
end

-- The source ActionButtonTemplate is 36x36.  Scale its exact 3.3.5 geometry
-- when SarychUI's configurable button size differs from Blizzard's size.
function ActionBar:LayoutDefaultActionArtwork(button)
	if not button or not button.sarychDefaultActionArtwork then
		return
	end
	local size = button:GetWidth()
	if not size or size == 0 then
		size = BLIZZARD_BUTTON_SIZE
	end
	local scale = size / BLIZZARD_BUTTON_SIZE

	local normal = button:GetNormalTexture()
	if normal then
		normal:ClearAllPoints()
		normal:SetPoint("CENTER", button, "CENTER", 0, -scale)
		normal:SetSize(size * NORMAL_TEXTURE_SCALE, size * NORMAL_TEXTURE_SCALE)
	end
	if button.equippedTexture then
		button.equippedTexture:ClearAllPoints()
		button.equippedTexture:SetPoint("CENTER")
		button.equippedTexture:SetSize(size * EQUIPPED_BORDER_SCALE, size * EQUIPPED_BORDER_SCALE)
	end
	if button.cooldown then
		button.cooldown:ClearAllPoints()
		button.cooldown:SetPoint("CENTER", button, "CENTER", 0, -scale)
		button.cooldown:SetSize(size, size)
	end
	if button.hotkey then
		button.hotkey:ClearAllPoints()
		button.hotkey:SetPoint("TOPLEFT", button, "TOPLEFT", (button.hotkeyIsRangeIndicator and 1 or -2) * scale, -2 * scale)
		button.hotkey:SetSize(size, 10 * scale)
		button.hotkey:SetJustifyH("RIGHT")
	end
	if button.count then
		button.count:ClearAllPoints()
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2 * scale, 2 * scale)
	end
	if button.name then
		button.name:ClearAllPoints()
		button.name:SetPoint("BOTTOM", button, "BOTTOM", 0, 2 * scale)
		button.name:SetSize(size, 10 * scale)
	end
end

function ActionBar:SetButtonColors(button, shade)
	button.icon:SetVertexColor(shade, shade, shade)
end

function ActionBar:SetButtonChecked(button, checked)
	if button.SetChecked then
		button:SetChecked(checked and 1 or 0)
	elseif button.checkedTexture then
		FA.SetShown(button.checkedTexture, checked)
	end
end

function ActionBar:SetButtonEquipped(button, equipped)
	if button.equippedTexture then
		FA.SetShown(button.equippedTexture, equipped)
	end
end

local DRAG_MODIFIERS = {
	shift = IsShiftKeyDown,
	ctrl = IsControlKeyDown,
	alt = IsAltKeyDown,
}

function ActionBar.CanDrag()
	local modifier = DRAG_MODIFIERS[config.dragModifier]
	return (not modifier or modifier()) and not InCombatLockdown()
end

function ActionBar:StyleHotkey(hotkey)
	local mm = SarychUI.modules and SarychUI.modules.mainmenubar
	if mm and mm.ApplyHotkeyRegion then
		-- panelText.lua is the only owner of hotkey alpha.  In particular, do
		-- not cancel its active fade when Frost refreshes bindings or actions.
		mm:ApplyHotkeyRegion(hotkey, "Frost:StyleHotkey")
	end
end

local TOOLTIP_REFRESH_INTERVAL = 0.2

local tooltipRefresher = CreateFrame("Frame")
tooltipRefresher:Hide()
tooltipRefresher:SetScript("OnUpdate", function(self, elapsed)
	self.timer = self.timer - elapsed
	if self.timer <= 0 then
		self.timer = TOOLTIP_REFRESH_INTERVAL
		self.button.setTooltip(self.button)
	end
end)

local function onTooltipEnter(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	button.setTooltip(button)
	tooltipRefresher.button = button
	tooltipRefresher.timer = TOOLTIP_REFRESH_INTERVAL
	tooltipRefresher:Show()
end

local function onTooltipLeave()
	tooltipRefresher:Hide()
	tooltipRefresher.button = nil
	GameTooltip:Hide()
end

function ActionBar:AttachTooltip(button, setTooltip)
	button.setTooltip = setTooltip
	button:SetScript("OnEnter", onTooltipEnter)
	button:SetScript("OnLeave", onTooltipLeave)
end

local function cursorHoldsAction()
	return GetCursorInfo() ~= nil
end

local function createBarFrame(name, buttons)
	local bar = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
	bar.fader = FA.CreateFader({ bar }, nil, cursorHoldsAction)
	bar.fader:SetMouseFrames(buttons)
	bar.buttons = buttons
	return bar
end

function ActionBar:CreateBar(page, onButtonCreated)
	local bar = createBarFrame("SarychUIActionBar" .. page, {})
	bar.limited = true
	local firstAction = (page - 1) * BUTTONS_PER_BAR
	local blizzardBinding = PAGE_BINDINGS[page]

	for i = 1, BUTTONS_PER_BAR do
		local button = self:CreateActionButton(firstAction + i, bar)
		if blizzardBinding then
			button.blizzardBinding = blizzardBinding:format(i)
			self.UpdateHotkey(button)
		end
		bar.buttons[i] = button
		if onButtonCreated then
			onButtonCreated(button, i)
		end
	end

	self.bars[page] = bar
	return bar
end

local CLASS_PAGE_CONDITIONS = {
	WARRIOR = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9;",
	DRUID = "[bonusbar:1,stealth] 8; [bonusbar:1] 7; [bonusbar:3] 9; [bonusbar:4] 10;",
	ROGUE = "[bonusbar:1] 7; [bonusbar:2] 8;",
	PRIEST = "[bonusbar:1] 7;",
}

local classPageCondition = CLASS_PAGE_CONDITIONS[FA.PLAYER_CLASS]
local PAGE_DRIVER_CONDITION = "[vehicleui] 11; [bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
	.. (classPageCondition and classPageCondition .. " " or "")
	.. "1"

local PAGE_CHANGED_SNIPPET = [[
	local action = (message - 1) * 12 + self:GetAttribute("id")
	self:SetAttribute("action", action)
	self:GetFrameRef("slot"):SetAttribute("action", action)
]]

local function setupPagedButton(button, index)
	button:SetAttribute("id", index)
	button:SetAttribute("_childupdate-page", PAGE_CHANGED_SNIPPET)
end

local LEFT_POINTS = {
	TOP = "TOPLEFT",
	TOPRIGHT = "TOPLEFT",
	CENTER = "LEFT",
	RIGHT = "LEFT",
	BOTTOM = "BOTTOMLEFT",
	BOTTOMRIGHT = "BOTTOMLEFT",
}

-- Stance bar grows to the right: keep the stored anchor on the left edge so
-- a changing number of forms never shifts the first button.
local function anchorLeft(barConfig, width)
	local point = barConfig.point or "CENTER"
	local leftPoint = LEFT_POINTS[point]
	if not leftPoint then
		return
	end
	local shift = point:find("RIGHT") and width or width / 2
	barConfig.point = leftPoint
	barConfig.relativePoint = barConfig.relativePoint or point
	barConfig.x = floor((barConfig.x or 0) - shift + 0.5)
end

local function layoutBar(bar, barConfig, count, growRight)
	local size, gap = barConfig.buttonSize, barConfig.spacing
	local slot = size + gap
	local columns = max(min(barConfig.columns, count), 1)
	local rows = max(ceil(count / columns), 1)
	local buttons = bar.buttons

	for i = 1, #buttons do
		local button = buttons[i]
		if i <= count then
			button:SetSize(size, size)
			ActionBar:LayoutDefaultActionArtwork(button)
			if button.autoCastable then
				button.autoCastable:SetSize(size * AUTOCAST_BORDER_SCALE, size * AUTOCAST_BORDER_SCALE)
			end
			button:ClearAllPoints()
			button:SetPoint(FA.GridPoint("BOTTOMLEFT", i, columns, slot))
			if bar.limited then
				button:SetAttribute("slotactive", true)
				button:UpdateGrid()
			end
		elseif bar.limited then
			button:SetAttribute("slotactive", false)
			button:UpdateGrid()
		end
	end

	bar:SetSize(columns * slot - gap, rows * slot - gap)
	if growRight and count > 0 then
		anchorLeft(barConfig, columns * slot - gap)
	end
	FA.ApplyPoint(bar, barConfig)
	bar.fader:Configure(barConfig.mouseover, barConfig.fadeAlpha, barConfig.combat)
	if barConfig.enabled ~= nil then
		FA.SetShown(bar, barConfig.enabled)
	end
end

function ActionBar:LayoutBar(key)
	local barConfig = FA.BarConfig(key)
	if not barConfig then
		return
	end
	if key == "vehicleExit" then
		self:LayoutVehicleExit()
	elseif key == "totemBar" then
		self:LayoutTotemBar()
	elseif key == "pet" then
		layoutBar(self.petBar, barConfig, #self.petButtons)
	elseif key == "stance" then
		layoutBar(self.stanceBar, barConfig, GetNumShapeshiftForms(), true)
	else
		local page = tonumber(key:match("%d+"))
		if page and page >= FIRST_EXTRA_PAGE then
			self:UpdateExtraBar(page)
			return
		end
		local bar = self.bars[page]
		if bar then
			layoutBar(bar, barConfig, barConfig.buttons)
		end
	end
end

function ActionBar:StyleBarButtons(bar)
	for _, button in ipairs(bar.buttons) do
		self:StyleHotkey(button.hotkey)
		button:RegisterForDrag(config.dragButton)
		button:UpdateGrid()
		button:UpdateColors()
		local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
			and SarychUI.db.profile.modules.mainmenubar
		FA.SetShown(button.name, not (db and db.hideMacroNames))
		FA.SetShown(button.count, true)
	end
end

function ActionBar:StyleButtons()
	for _, bar in pairs(self.bars) do
		self:StyleBarButtons(bar)
	end
	self:StylePetButtons()
	local mm = SarychUI.modules and SarychUI.modules.mainmenubar
	if mm and mm.ApplyButtonBorderAlpha then
		mm:ApplyButtonBorderAlpha()
	end
end

function ActionBar.NewExtraBar(page)
	return {
		enabled = true,
		point = "CENTER",
		relativePoint = "CENTER",
		x = 0,
		y = (FIRST_EXTRA_PAGE - page) * 40,
		buttons = BUTTONS_PER_BAR,
		columns = BUTTONS_PER_BAR,
		buttonSize = 36,
		spacing = 2,
		mouseover = false,
		combat = "any",
		fadeAlpha = 0.1,
	}
end

local function setButtonsActive(bar, active)
	for _, button in ipairs(bar.buttons) do
		button:SetAttribute("type", active and "action" or nil)
	end
end

function ActionBar:UpdateExtraBar(page)
	local key = "bar" .. page
	local extra = config.extraBars
	local barConfig = extra and extra[key]
	local bar = self.bars[page]
	if barConfig then
		if not bar then
			bar = self:CreateBar(page)
			self:StyleBarButtons(bar)
			local mm = SarychUI.modules and SarychUI.modules.mainmenubar
			if mm and mm.ApplyButtonBorderAlpha then
				mm:ApplyButtonBorderAlpha()
			end
		end
		if not bar.active then
			bar.active = true
			setButtonsActive(bar, true)
			FA.RegisterMover(key, bar, FA.Label(key))
		end
		layoutBar(bar, barConfig, barConfig.buttons)
	elseif bar and bar.active then
		bar.active = nil
		bar:Hide()
		setButtonsActive(bar, false)
		FA.UnregisterMover(key)
	end
end

function ActionBar:UpdateExtraBars()
	for page = FIRST_EXTRA_PAGE, LAST_EXTRA_PAGE do
		self:UpdateExtraBar(page)
	end
end

-- key == nil → full relayout; otherwise only the given bar.
function ActionBar:Layout(key)
	if key then
		local barConfig = FA.BarConfig(key)
		if type(barConfig) == "table" and barConfig.buttonSize then
			self:LayoutBar(key)
			return
		end
	end
	for _, barKey in ipairs(BAR_KEYS) do
		self:LayoutBar(barKey)
	end
	self:UpdateExtraBars()
	self:LayoutVehicleExit()
	self:LayoutTotemBar()
	self:StyleButtons()
end

function ActionBar:Initialize()
	if self.initialized then
		return
	end
	self.initialized = true

	local bar1 = self:CreateBar(1, setupPagedButton)
	bar1:SetAttribute("_onstate-page", [[ control:ChildUpdate("page", newstate) ]])
	RegisterStateDriver(bar1, "page", PAGE_DRIVER_CONDITION)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		if not InCombatLockdown() then
			RegisterStateDriver(bar1, "page", PAGE_DRIVER_CONDITION)
		end
	end)

	for page = 2, NUM_BARS do
		self:CreateBar(page)
	end

	self.stanceBar = createBarFrame("SarychUIStanceBar", self.shapeshiftButtons)
	self.petBar = createBarFrame("SarychUIPetBar", self.petButtons)
	self:InitializeShapeshiftBar(self.stanceBar)
	self:InitializePetBar(self.petBar)
	self:InitializeVehicleExit()
	self:InitializeTotemBar()

	self:Layout()

	for page = 1, NUM_BARS do
		FA.RegisterMover("bar" .. page, self.bars[page], FA.Label("bar" .. page))
	end
	FA.RegisterMover("stance", self.stanceBar, FA.Label("stance"))
	FA.RegisterMover("pet", self.petBar, FA.Label("pet"))

	local function layoutStance()
		if InCombatLockdown() then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", layoutStance)
			return
		end
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", layoutStance)
		self:LayoutBar("stance")
	end
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", layoutStance)
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", layoutStance)
	self:RegisterEvent("CHARACTER_POINTS_CHANGED", layoutStance)

	self:InitializeOverrideBindings()
end

-- Hide everything (module disabled at runtime; Blizzard bars return after /reload).
function ActionBar:HideAll()
	if InCombatLockdown() then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "HideAll")
		return
	end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "HideAll")
	for _, bar in pairs(self.bars) do
		bar:Hide()
	end
	if self.stanceBar then
		UnregisterStateDriver(self.stanceBar, "visibility")
		self.stanceBar:Hide()
	end
	if self.petBar then
		UnregisterStateDriver(self.petBar, "visibility")
		self.petBar:Hide()
	end
	if self.HideVehicleExit then
		self:HideVehicleExit()
	end
	if self.HideTotemBar then
		self:HideTotemBar()
	end
end
