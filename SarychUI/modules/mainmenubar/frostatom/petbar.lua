-- Ported from FrostAtomUI Modules/ActionBar/PetBar.lua.
-- Pet action bar.
local FA = SarychUI.FrostAtomBars

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetPetActionCooldown = GetPetActionCooldown
local GetPetActionInfo = GetPetActionInfo
local GetPetActionSlotUsable = GetPetActionSlotUsable
local PickupPetAction = PickupPetAction
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local AutoCastShine_AutoCastStart = AutoCastShine_AutoCastStart
local AutoCastShine_AutoCastStop = AutoCastShine_AutoCastStop
local GameTooltip = GameTooltip
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS

local ActionBar = FA:GetModule("ActionBar")
local config = FA.config
local buttons = ActionBar.petButtons
local updateHotkey = ActionBar.UpdateHotkey

local tokenTextures = setmetatable({}, {
	__index = function(self, token)
		local path = _G[token]
		self[token] = path or false
		return path
	end,
})

local function setTooltip(button)
	local id = button:GetID()
	if GetPetActionInfo(id) then
		GameTooltip:SetPetAction(id)
	else
		GameTooltip:Hide()
	end
end

local function onDragStart(button)
	if ActionBar.CanDrag() then
		PickupPetAction(button:GetID())
	end
end

local function onReceiveDrag(button)
	if not InCombatLockdown() then
		PickupPetAction(button:GetID())
	end
end

local function setAutoCast(button, allowed, enabled)
	FA.SetShown(button.autoCastable, allowed)
	enabled = enabled and true or false
	if enabled ~= button.autoCasting then
		button.autoCasting = enabled
		if enabled then
			AutoCastShine_AutoCastStart(button.shine)
		else
			AutoCastShine_AutoCastStop(button.shine)
		end
	end
end

function ActionBar:UpdatePetHotkeys()
	for i = 1, NUM_PET_ACTION_SLOTS do
		updateHotkey(buttons[i])
	end
end

function ActionBar:UpdatePetBar()
	if not self.petBar:IsShown() then
		return
	end

	for i = 1, NUM_PET_ACTION_SLOTS do
		local button = buttons[i]
		local _, _, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i)

		if texture then
			if isToken then
				texture = tokenTextures[texture]
			end
			button.icon:SetTexture(texture)
			button.icon:Show()
			button.icon:SetDesaturated(not GetPetActionSlotUsable(i))

			self:SetButtonChecked(button, isActive)
			self:SetButtonColors(button, isToken and not isActive and 0.4 or 1)
			setAutoCast(button, autoCastAllowed, autoCastEnabled)
		else
			button.icon:Hide()
			button.cooldown:Hide()
			button.icon:SetDesaturated(nil)
			self:SetButtonChecked(button, false)
			setAutoCast(button, false, false)
		end
	end

	self:UpdatePetCooldowns()
end

function ActionBar:UpdatePetCooldowns()
	for i = 1, NUM_PET_ACTION_SLOTS do
		CooldownFrame_SetTimer(buttons[i].cooldown, GetPetActionCooldown(i))
	end
end

function ActionBar:CreatePetButton(index, parent)
	local name = "PetActionButton" .. index
	local button = _G[name]
	button:SetParent(parent)
	button.bindingName = "CLICK " .. name .. ":LeftButton"
	button.blizzardBinding = "BONUSACTIONBUTTON" .. index
	button.icon = _G[name .. "Icon"]
	button.cooldown = _G[name .. "Cooldown"]
	button.autoCastable = _G[name .. "AutoCastable"]
	button.shine = _G[name .. "Shine"]
	button.hotkey = self:CreateOwnedHotkey(button, _G[name .. "HotKey"], true)
	button.checkedTexture = button:GetCheckedTexture()
	button.sarychSupportsBorderAlpha = true
	button.autoCasting = false

	button:RegisterForClicks("LeftButtonDown", "RightButtonUp")
	button:RegisterForDrag(config.dragButton)
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnReceiveDrag", onReceiveDrag)
	self:AttachTooltip(button, setTooltip)
	updateHotkey(button)

	buttons[index] = button
	return button
end

local function onPetUnitEvent(self, unit)
	if unit == "pet" then
		self:UpdatePetBar()
	end
end

local function onPlayerUnitEvent(self, unit)
	if unit == "player" then
		self:UpdatePetBar()
	end
end

function ActionBar:StylePetButtons()
	for i = 1, #buttons do
		local button = buttons[i]
		button:RegisterForDrag(config.dragButton)
	end
end

function ActionBar:ApplyPetVisibility()
	if self.petBar then
		RegisterStateDriver(self.petBar, "visibility", "[vehicleui] hide; [@pet,exists] show; hide")
	end
end

function ActionBar:InitializePetBar(parent)
	self.petBar = parent

	for i = 1, NUM_PET_ACTION_SLOTS do
		self:CreatePetButton(i, parent)
	end

	self:ApplyPetVisibility()
	parent:SetScript("OnShow", function()
		self:UpdatePetBar()
	end)

	self:RegisterEvent("UNIT_FLAGS", onPetUnitEvent)
	self:RegisterEvent("UNIT_AURA", onPetUnitEvent)
	self:RegisterEvent("UNIT_PET", onPlayerUnitEvent)
	for _, event in ipairs({
		"PET_BAR_UPDATE",
		"PET_BAR_UPDATE_USABLE",
		"PLAYER_CONTROL_LOST",
		"PLAYER_CONTROL_GAINED",
		"PLAYER_FARSIGHT_FOCUS_CHANGED",
	}) do
		self:RegisterEvent(event, "UpdatePetBar")
	end
	self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN", "UpdatePetCooldowns")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdatePetHotkeys")
end
