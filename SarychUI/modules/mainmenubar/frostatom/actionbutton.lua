-- Ported from FrostAtomUI Modules/ActionBar/ActionButton.lua.
-- Action buttons, range / usability colors.
local FA = SarychUI.FrostAtomBars

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetActionTexture = GetActionTexture
local GetActionCount = GetActionCount
local GetActionText = GetActionText
local GetBindingKey = GetBindingKey
local GetBindingText = GetBindingText
local HasAction = HasAction
local IsActionInRange = IsActionInRange
local IsUsableAction = IsUsableAction
local IsEquippedAction = IsEquippedAction
local IsCurrentAction = IsCurrentAction
local IsAutoRepeatAction = IsAutoRepeatAction
local IsConsumableAction = IsConsumableAction
local IsStackableAction = IsStackableAction
local InCombatLockdown = InCombatLockdown
local PickupAction = PickupAction
local UnitExists = UnitExists
local GetTime = GetTime
local GameTooltip = GameTooltip
local max = math.max

local ActionBar = FA:GetModule("ActionBar")
local config = FA.config
local WHITE = { 1, 1, 1 }
local HOTKEY_GREY = { 0.6, 0.6, 0.6 }
local BUTTON_NAME = "SarychUIActionButton%d"
local BINDING_NAME = "CLICK " .. BUTTON_NAME .. ":LeftButton"
local SLOT_NAME = "SarychUIActionSlot%d"
ActionBar.BINDING_NAME = BINDING_NAME
local RANGE_INDICATOR = "●"
local NORMAL_TEXTURE = "Interface\\Buttons\\UI-Quickslot2"
local EMPTY_TEXTURE = "Interface\\Buttons\\UI-Quickslot"
local RANGE_CHECK_INTERVAL = 0.1
local GCD_DURATION = 1.5
local RECEIVE_DRAG_SNIPPET = [[
	if not kind then
		return false
	end
	return "action", self:GetAttribute("action")
]]
local SLOT_VISIBILITY_SNIPPET = [[
	local button = self:GetFrameRef("button")
	if self:IsShown() and button:GetAttribute("slotactive") then
		button:Show()
	else
		button:Hide()
	end
]]

local actionButtons = {}
ActionBar.actionButtons = actionButtons
local hasTarget = false

local ACTION_EVENTS = {
	UPDATE_SHAPESHIFT_FORM = "Update",
	UPDATE_MACROS = "Update",
	ACTIONBAR_UPDATE_USABLE = "UpdateUsable",
	ACTIONBAR_UPDATE_COOLDOWN = "UpdateCooldown",
	ACTIONBAR_UPDATE_STATE = "UpdateState",
	PLAYER_EQUIPMENT_CHANGED = "UpdateEquipped",
	UNIT_ENTERED_VEHICLE = "UpdateStateForUnit",
	UNIT_EXITED_VEHICLE = "UpdateStateForUnit",
	TRADE_SKILL_SHOW = "UpdateState",
	TRADE_SKILL_CLOSE = "UpdateState",
	COMPANION_UPDATE = "UpdateStateForCompanion",
	BAG_UPDATE = "UpdateName",
	SPELL_UPDATE_USABLE = "UpdateUsable",
}

local function updateHotkey(button)
	local key = button.blizzardBinding and GetBindingKey(button.blizzardBinding)
	if not key then
		key = GetBindingKey(button.bindingName)
	end
	local text = key and (GetBindingText and GetBindingText(key, "KEY_", 1) or key) or ""
	if text and text ~= "" then
		button.hotkeyIsRangeIndicator = false
		button.hotkey:SetText(text)
		button.hotkey:Show()
	else
		button.hotkeyIsRangeIndicator = button.sarychUsesActionText and true or false
		button.hotkey:SetText(button.hotkeyIsRangeIndicator and RANGE_INDICATOR or "")
		button.hotkey:Hide()
	end
	ActionBar:LayoutDefaultActionArtwork(button)
	if button.hotkeyIsRangeIndicator and button.UpdateColors and button.hasAction then
		button:UpdateColors()
	end
	-- Setting the binding text must not decide whether it is visible.  Reapply
	-- the shared Text-panel state after Blizzard/Frost updates the FontString.
	ActionBar:StyleHotkey(button.hotkey)
end
ActionBar.UpdateHotkey = updateHotkey

local ActionButtonMixin = {}

local function applyColors(button, r, g, b)
	button.icon:SetVertexColor(r, g, b)
end

local function updateRangeIndicator(button)
	if not button.hotkeyIsRangeIndicator then
		return
	end
	local valid = button.hasAction and button.rangeState
	FA.SetShown(button.hotkey, valid == 0 or valid == 1)
end

function ActionButtonMixin:UpdateColors()
	local mm = SarychUI.modules and SarychUI.modules.mainmenubar
	if mm and mm.UpdateButtonColorIndication then
		mm:UpdateButtonColorIndication(self, true)
		local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
			and SarychUI.db.profile.modules.mainmenubar
		if self.outOfRange and db and db.colorRangeEnabled then
			local c = db.colorRangeColor or { 0.8, 0.2, 0.2, 1 }
			self.hotkey:SetTextColor(c[1] or 0.8, c[2] or 0.2, c[3] or 0.2)
		else
			self.hotkey:SetTextColor(0.6, 0.6, 0.6)
		end
		updateRangeIndicator(self)
		return
	end
	local color
	if self.notEnoughMana then
		color = config.manaColor
	elseif self.outOfRange and config.rangeIconTint then
		color = config.rangeColor
	elseif self.usable then
		color = WHITE
	else
		color = config.unusableColor
	end
	applyColors(self, color[1], color[2], color[3])

	color = self.outOfRange and config.rangeHotkey and config.rangeColor or HOTKEY_GREY
	self.hotkey:SetTextColor(color[1], color[2], color[3])
	updateRangeIndicator(self)
end

function ActionButtonMixin:UpdateUsable()
	self.usable, self.notEnoughMana = IsUsableAction(self.action)
	self:UpdateColors()
end

function ActionButtonMixin:UpdateEquipped()
	ActionBar:SetButtonEquipped(self, IsEquippedAction(self.action))
end

function ActionButtonMixin:UpdateState()
	ActionBar:SetButtonChecked(self, IsCurrentAction(self.action) or IsAutoRepeatAction(self.action))
end

-- ActionBarButtonTemplate performs this after every secure click.  Our button
-- uses only ActionButtonTemplate, so reproduce that part explicitly; otherwise
-- CheckButton toggles itself and leaves the large checked glow looking like an
-- incorrect pressed border.
function ActionButtonMixin:PostClick()
	self:UpdateState()
	if SnowfallKeyPress_PlayButtonAnimation then
		SnowfallKeyPress_PlayButtonAnimation(self)
	end
end

function ActionButtonMixin:UpdateStateForUnit(unit)
	if unit == "player" then
		self:UpdateState()
	end
end

function ActionButtonMixin:UpdateStateForCompanion(companionType)
	if companionType == "MOUNT" then
		self:UpdateState()
	end
end

function ActionButtonMixin:UpdateBindings()
	updateHotkey(self)
end

function ActionButtonMixin:UpdateName()
	local action = self.action
	if IsConsumableAction(action) or IsStackableAction(action) then
		local count = GetActionCount(action)
		self.count:SetText(count)
		self.name:SetText("")
	else
		self.count:SetText("")
		self.name:SetText(GetActionText(action))
	end
end

function ActionButtonMixin:UpdateGrid()
	if InCombatLockdown() then
		return
	end
	local slot = self.slot
	local extra = (config.hideEmptyButtons and 0 or 1) + (ActionBar:IsBindMode() and 1 or 0)
	local grid = max(slot:GetAttribute("showgrid") - self.gridExtra + extra, 0)
	self.gridExtra = extra
	slot:SetAttribute("showgrid", grid)
	if grid > 0 then
		ActionButton_ShowGrid(slot)
	else
		ActionButton_HideGrid(slot)
	end
	FA.SetShown(self, self:GetAttribute("slotactive") and slot:IsShown())
end

function ActionButtonMixin:UpdateIcon()
	local texture = GetActionTexture(self.action)
	if texture then
		self.icon:SetTexture(texture)
		self.icon:Show()
		self:SetNormalTexture(NORMAL_TEXTURE)
	else
		self.icon:Hide()
		self.cooldown:Hide()
		self:SetNormalTexture(EMPTY_TEXTURE)
	end
	ActionBar:LayoutDefaultActionArtwork(self)
end

function ActionButtonMixin:UpdateCooldown()
	-- Look up the global each time so InternalCooldowns can hook item ICDs.
	-- A file-scope local would freeze the pre-hook Blizzard function.
	local start, duration, enable = GetActionCooldown(self.action)
	CooldownFrame_SetTimer(self.cooldown, start, duration, enable)

	local endTime = start + duration
	if enable == 1 and duration > GCD_DURATION and endTime > GetTime() then
		self.cooldownEnd, self.cooldownDuration = endTime, duration
	else
		self.cooldownEnd, self.cooldownDuration = 0, 0
	end

	local mm = SarychUI.modules and SarychUI.modules.mainmenubar
	if mm and mm.UpdateButtonColorIndication then
		mm:UpdateButtonColorIndication(self, true)
	else
		local desaturated = config.desaturateOnCooldown and self.cooldownEnd > 0 or false
		if desaturated ~= self.desaturated then
			self.desaturated = desaturated
			self.icon:SetDesaturated(desaturated)
		end
	end

	self.expiry = (self.cooldownEnd > 0) and self.cooldownEnd or nil
end

function ActionButtonMixin:Update()
	local action = self.action

	if HasAction(action) then
		for event, method in pairs(ACTION_EVENTS) do
			self:RegisterEvent(event, method)
		end

		self.usable, self.notEnoughMana = IsUsableAction(action)
		self.rangeState = hasTarget and IsActionInRange(action)
		self.outOfRange = self.rangeState == 0
		self.hasAction = true
	elseif self.hasAction then
		for event, method in pairs(ACTION_EVENTS) do
			self:UnregisterEvent(event, method)
		end

		self.usable = true
		self.notEnoughMana, self.outOfRange, self.rangeState = nil, nil, nil
		self.hasAction = false
	end

	self:UpdateGrid()
	self:UpdateEquipped()
	self:UpdateState()
	self:UpdateBindings()
	self:UpdateColors()
	self:UpdateIcon()
	self:UpdateCooldown()
	self:UpdateName()

	-- Cheese hooks Blizzard's ActionButton_Update, while Frost buttons use this
	-- independent updater.  Feed the finished action state into the same public
	-- Cheese adapter so it can register glow events and attach its overlay.
	if CheeseActionButton_Update then
		CheeseActionButton_Update(self)
	end
end

function ActionButtonMixin:UpdateRange()
	local rangeState = hasTarget and IsActionInRange(self.action)
	local outOfRange = rangeState == 0
	if outOfRange ~= self.outOfRange or rangeState ~= self.rangeState then
		self.rangeState = rangeState
		self.outOfRange = outOfRange
		self:UpdateColors()
	end
end

local nextRangeCheck = 0

local rangeTicker = CreateFrame("Frame")
rangeTicker:Hide()
rangeTicker:SetScript("OnUpdate", function()
	local now = GetTime()
	if now < nextRangeCheck then
		return
	end
	nextRangeCheck = now + RANGE_CHECK_INTERVAL

	for i = 1, #actionButtons do
		local button = actionButtons[i]
		if button.hasAction then
			local expiry = button.expiry
			if expiry and now >= expiry then
				button:UpdateCooldown()
			end
			if hasTarget and button:IsVisible() then
				button:UpdateRange()
			end
		end
	end
end)

function ActionBar:UpdateGrid()
	for i = 1, #actionButtons do
		actionButtons[i]:UpdateGrid()
	end
end

local function onTargetChanged()
	hasTarget = UnitExists("target") and true or false
	for i = 1, #actionButtons do
		local button = actionButtons[i]
		if button.hasAction then
			button:UpdateRange()
		end
	end
end

function ActionButtonMixin:OnAttributeChanged(attribute, value)
	if attribute == "action" then
		self.action = value
		self:Update()
	end
end

function ActionButtonMixin:OnDragStart()
	if ActionBar.CanDrag() then
		PickupAction(self.action)
	end
end

function ActionButtonMixin:ACTIONBAR_SLOT_CHANGED(slot)
	if slot == 0 or slot == self.action then
		self:Update()
	end
end

function ActionButtonMixin:SetTooltip()
	if HasAction(self.action) then
		GameTooltip:SetAction(self.action)
	else
		GameTooltip:Hide()
	end
end

function ActionBar:CreateActionButton(action, parent)
	local button = CreateFrame("CheckButton", BUTTON_NAME:format(action), parent, "SecureActionButtonTemplate, ActionButtonTemplate")
	FA.Mixin(button, FA.EventMixin, ActionButtonMixin)

	button:SetAttribute("checkselfcast", true)
	button:SetAttribute("checkfocuscast", true)
	button:SetAttribute("type", "action")
	button:SetAttribute("action", action)
	button:SetAttribute("slotactive", true)
	button.action = action
	button.bindingName = BINDING_NAME:format(action)
	button.sarychSnowfallPostClick = true

	self:AdoptActionButtonArtwork(button)
	self:StyleHotkey(button.hotkey)

	button:RegisterForClicks("LeftButtonDown")
	button:RegisterForDrag(config.dragButton)
	button:SetScript("OnDragStart", button.OnDragStart)
	button:SetScript("OnAttributeChanged", button.OnAttributeChanged)
	button:SetScript("PostClick", button.PostClick)
	parent:WrapScript(button, "OnReceiveDrag", RECEIVE_DRAG_SNIPPET)
	button:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	button:RegisterEvent("PLAYER_ENTERING_WORLD", "Update")
	button:RegisterEvent("UPDATE_BINDINGS", "UpdateBindings")
	self:AttachTooltip(button, button.SetTooltip)

	local slot = CreateFrame("CheckButton", SLOT_NAME:format(action), nil, "ActionBarButtonTemplate")
	slot:SetAlpha(0)
	slot:EnableMouse(false)
	slot:SetScript("OnUpdate", nil)
	-- The slot is only a hidden Blizzard state/grid proxy.  Its template hotkey
	-- must never participate in SarychUI text visibility or binding refreshes.
	slot:UnregisterEvent("UPDATE_BINDINGS")
	local slotHotkey = _G[slot:GetName() .. "HotKey"]
	if slotHotkey then
		slotHotkey:SetText("")
		slotHotkey:SetAlpha(0)
		slotHotkey:Hide()
	end
	slot:SetAttribute("action", action)
	SecureHandlerSetFrameRef(slot, "button", button)
	SecureHandlerSetFrameRef(button, "slot", slot)
	parent:WrapScript(slot, "OnShow", SLOT_VISIBILITY_SNIPPET)
	parent:WrapScript(slot, "OnHide", SLOT_VISIBILITY_SNIPPET)
	button.slot = slot
	button.gridExtra = 0

	button.usable = true
	button.cooldownEnd = 0
	button:Update()

	if #actionButtons == 0 then
		self:RegisterEvent("PLAYER_TARGET_CHANGED", onTargetChanged)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", onTargetChanged)
		rangeTicker:Show()
	end
	actionButtons[#actionButtons + 1] = button
	ActionBar.actionButtons = actionButtons
	return button
end
