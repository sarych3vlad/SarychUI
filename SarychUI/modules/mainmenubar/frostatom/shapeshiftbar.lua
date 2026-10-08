-- Ported from FrostAtomUI Modules/ActionBar/ShapeshiftBar.lua.
-- Stance / shapeshift bar (reuses Blizzard ShapeshiftButtonN).
local FA = SarychUI.FrostAtomBars

local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown
local GetSpellInfo = GetSpellInfo
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver
local GameTooltip = GameTooltip
local NUM_SHAPESHIFT_SLOTS = NUM_SHAPESHIFT_SLOTS

local ActionBar = FA:GetModule("ActionBar")
local PLACEHOLDER_TEXTURE = "Interface\\Icons\\Spell_Nature_WispSplode"

local buttons = ActionBar.shapeshiftButtons

-- Stance buttons do not use the large ActionButtonTemplate rim.  Clear any
-- UI-Quickslot2/Border region that an earlier generic skinning pass may have
-- attached to the reused Blizzard buttons.
local function RemoveShapeshiftBorder(button)
	if not button then
		return
	end
	local name = button:GetName()
	local normal = button.GetNormalTexture and button:GetNormalTexture()
	local namedNormal = name and _G[name .. "NormalTexture"]
	if normal then
		normal:SetTexture(nil)
		normal:Hide()
	end
	if namedNormal and namedNormal ~= normal then
		namedNormal:SetTexture(nil)
		namedNormal:Hide()
	end
	local border = name and _G[name .. "Border"]
	if border then
		border:SetTexture(nil)
		border:Hide()
	end
	-- LortiUI used to add a separate background/shadow frame to stance buttons.
	if button.bg then
		button.bg:Hide()
	end
end

local function setTooltip(button)
	local id = button:GetID()
	if id <= GetNumShapeshiftForms() then
		GameTooltip:SetShapeshift(id)
	else
		GameTooltip:Hide()
	end
end

function ActionBar:UpdateShapeshiftBar()
	local currentForm = GetShapeshiftForm()

	for i = 1, GetNumShapeshiftForms() do
		local button = buttons[i]
		local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i)

		if texture then
			if texture == PLACEHOLDER_TEXTURE then
				texture = select(3, GetSpellInfo(name))
			end
			button.icon:SetTexture(texture)
			button.cooldown:Show()
		else
			button.icon:SetTexture(nil)
			button.cooldown:Hide()
		end

		CooldownFrame_SetTimer(button.cooldown, GetShapeshiftFormCooldown(i))

		self:SetButtonChecked(button, currentForm == i)
		self:SetButtonColors(button, isCastable and (isActive or currentForm == 0) and 1 or 0.4)
		RemoveShapeshiftBorder(button)
	end
end

function ActionBar:UpdateShapeshiftCooldowns()
	for i = 1, GetNumShapeshiftForms() do
		CooldownFrame_SetTimer(buttons[i].cooldown, GetShapeshiftFormCooldown(i))
	end
end

function ActionBar:UpdateShapeshiftHotkeys()
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		local button = buttons[i]
		if button then
			self.UpdateHotkey(button)
		end
	end
end

function ActionBar:UpdateShapeshiftVisibility()
	local numForms = GetNumShapeshiftForms()
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		local button = buttons[i]
		local shouldShow = i <= numForms
		if shouldShow ~= (button:IsShown() and true or false) then
			if InCombatLockdown() then
				self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateShapeshiftVisibility")
				return
			end
			FA.SetShown(button, shouldShow)
		end
	end

	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateShapeshiftVisibility")
	self:UpdateShapeshiftBar()
end

function ActionBar:SetupShapeshiftButton(button)
	local name = button:GetName()
	RemoveShapeshiftBorder(button)
	if not button.sarychNoShapeshiftBorderHooked then
		button.sarychNoShapeshiftBorderHooked = true
		button:HookScript("OnShow", RemoveShapeshiftBorder)
		if hooksecurefunc and button.SetNormalTexture then
			hooksecurefunc(button, "SetNormalTexture", RemoveShapeshiftBorder)
		end
	end

	button.icon = _G[name .. "Icon"]
	button.cooldown = _G[name .. "Cooldown"]
	self:AttachTooltip(button, setTooltip)

	button.bindingName = "CLICK " .. name .. ":LeftButton"
	button.blizzardBinding = "SHAPESHIFTBUTTON" .. button:GetID()
	button.hotkey = self:CreateOwnedHotkey(button, _G[name .. "HotKey"], true)
	self:StyleHotkey(button.hotkey)
	self.UpdateHotkey(button)

	buttons[button:GetID()] = button
	return button
end

function ActionBar:InitializeShapeshiftBar(parent)
	for i = 1, NUM_SHAPESHIFT_SLOTS do
		self:SetupShapeshiftButton(_G["ShapeshiftButton" .. i]):SetParent(parent)
	end

	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", "UpdateShapeshiftCooldowns")
	self:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", "UpdateShapeshiftBar")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "UpdateShapeshiftBar")
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "UpdateShapeshiftVisibility")
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "UpdateShapeshiftVisibility")
	self:RegisterEvent("CHARACTER_POINTS_CHANGED", "UpdateShapeshiftVisibility")
	self:RegisterEvent("SPELL_UPDATE_USABLE", "UpdateShapeshiftBar")
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateShapeshiftHotkeys")
	self:UpdateShapeshiftBar()
	self:ApplyStanceVisibility()

	FA.DestroyFrame(ShapeshiftBarFrame)
	UIPARENT_MANAGED_FRAME_POSITIONS.ShapeshiftBarFrame = nil
end

function ActionBar:ApplyStanceVisibility()
	if self.stanceBar then
		RegisterStateDriver(self.stanceBar, "visibility", "[vehicleui][bonusbar:5] hide; show")
	end
end
