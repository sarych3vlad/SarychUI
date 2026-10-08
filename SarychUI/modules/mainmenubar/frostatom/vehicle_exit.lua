-- Ported from FrostAtomUI Modules/ActionBar/VehicleExit.lua.
-- Vehicle exit / possess cancel button.
local FA = SarychUI.FrostAtomBars

local CanExitVehicle = CanExitVehicle
local GetPossessInfo = GetPossessInfo
local InCombatLockdown = InCombatLockdown
local IsPossessBarVisible = IsPossessBarVisible
local RegisterStateDriver = RegisterStateDriver
local UnitExists = UnitExists
local UnitHasVehicleUI = UnitHasVehicleUI
local GameTooltip = GameTooltip

local ActionBar = FA:GetModule("ActionBar")

local config = FA.config
local BUTTON_NAME = "SarychUIVehicleExitButton"
local EXIT_UP_TEXTURE = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up"
local EXIT_DOWN_TEXTURE = "Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down"
local EXIT_HIGHLIGHT_TEXTURE = "Interface\\Vehicles\\UI-Vehicles-Button-Highlight"
local EXIT_TEXCOORD_MIN, EXIT_TEXCOORD_MAX = 0.140625, 0.859375
local HIGHLIGHT_TEXCOORD_MIN, HIGHLIGHT_TEXCOORD_MAX = 0.130625, 0.879375
local POSSESS_CANCEL_SLOT = 2
local EXIT_MACRO = "/leavevehicle\n/stopcasting [bonusbar:5]"
local CANCEL_AURA_LINE = "\n/cancelaura [bonusbar:5] %s"
local VISIBILITY_CONDITION = "[target=vehicle,exists][bonusbar:5] show; hide"

local VISIBILITY_SNIPPET = [[
	if newstate == "show" then
		self:Show()
	else
		self:Hide()
	end
]]

local button

local function isPossessing()
	return IsPossessBarVisible() and true or false
end

local function setTooltip()
	if UnitExists("vehicle") or CanExitVehicle() then
		GameTooltip:SetText(LEAVE_VEHICLE)
	else
		GameTooltip:SetText(CANCEL)
	end
end

local function updateMacro()
	if InCombatLockdown() then
		return
	end
	local _, name = GetPossessInfo(POSSESS_CANCEL_SLOT)
	local macro = name and EXIT_MACRO .. CANCEL_AURA_LINE:format(name) or EXIT_MACRO
	if button:GetAttribute("macrotext") ~= macro then
		button:SetAttribute("macrotext", macro)
	end
end

local function hideAfterCombat()
	ActionBar:UnregisterEvent("PLAYER_REGEN_ENABLED", hideAfterCombat)
	if not UnitExists("vehicle") and not CanExitVehicle() and not isPossessing() then
		button:Hide()
	end
	button:SetAlpha(1)
end

local function onVehicleChanged(_, unit)
	if unit ~= "player" then
		return
	end
	if CanExitVehicle() or UnitHasVehicleUI("player") or isPossessing() then
		if not InCombatLockdown() then
			button:Show()
		end
		button:SetAlpha(1)
	elseif InCombatLockdown() then
		button:SetAlpha(0)
		ActionBar:RegisterEvent("PLAYER_REGEN_ENABLED", hideAfterCombat)
	elseif not UnitExists("vehicle") then
		button:Hide()
	end
end

function ActionBar:LayoutVehicleExit()
	if not button then
		return
	end
	local size = config.vehicleExit.buttonSize
	button:SetSize(size, size)
	FA.ApplyPoint(button, config.vehicleExit)
end

function ActionBar:HideVehicleExit()
	if button and not InCombatLockdown() then
		UnregisterStateDriver(button, "exit")
		button:Hide()
	end
end

function ActionBar:ApplyVehicleExitVisibility()
	if button and not InCombatLockdown() then
		RegisterStateDriver(button, "exit", VISIBILITY_CONDITION)
	end
end

function ActionBar:InitializeVehicleExit()
	button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate")
	button:Hide()
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", EXIT_MACRO)
	button.bindingName = "CLICK " .. BUTTON_NAME .. ":LeftButton"

	-- Exact artwork from MainMenuBarVehicleLeaveButton in MainMenuBar.xml.
	button:SetNormalTexture(EXIT_UP_TEXTURE)
	button:GetNormalTexture():SetTexCoord(EXIT_TEXCOORD_MIN, EXIT_TEXCOORD_MAX, EXIT_TEXCOORD_MIN, EXIT_TEXCOORD_MAX)
	button:SetPushedTexture(EXIT_DOWN_TEXTURE)
	button:GetPushedTexture():SetTexCoord(EXIT_TEXCOORD_MIN, EXIT_TEXCOORD_MAX, EXIT_TEXCOORD_MIN, EXIT_TEXCOORD_MAX)
	button:SetHighlightTexture(EXIT_HIGHLIGHT_TEXTURE, "ADD")
	button:GetHighlightTexture():SetTexCoord(HIGHLIGHT_TEXCOORD_MIN, HIGHLIGHT_TEXCOORD_MAX, HIGHLIGHT_TEXCOORD_MIN, HIGHLIGHT_TEXCOORD_MAX)

	button:RegisterForClicks("AnyUp")
	button:HookScript("OnShow", function(self)
		self:SetAlpha(1)
	end)
	self:AttachTooltip(button, setTooltip)

	button:SetAttribute("_onstate-exit", VISIBILITY_SNIPPET)
	RegisterStateDriver(button, "exit", VISIBILITY_CONDITION)

	self:RegisterEvent("UNIT_ENTERED_VEHICLE", onVehicleChanged)
	self:RegisterEvent("UNIT_EXITED_VEHICLE", onVehicleChanged)
	self:RegisterEvent("UPDATE_BONUS_ACTIONBAR", updateMacro)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", updateMacro)

	self:LayoutVehicleExit()
	FA.RegisterMover("vehicleExit", button, FA.Label("vehicleExit"))

	if not InCombatLockdown() and (CanExitVehicle() or UnitHasVehicleUI("player")) then
		button:Show()
	end
end
