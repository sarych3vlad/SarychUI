-- Ported from FrostAtomUI Modules/ActionBar/Binder.lua.
-- Keybinding mode (/suibind) and Blizzard -> SarychUI override bindings.
local FA = SarychUI.FrostAtomBars

local InCombatLockdown = InCombatLockdown
local GetMouseFocus = GetMouseFocus
local GetBindingKey = GetBindingKey
local GetBindingAction = GetBindingAction
local GetBindingText = GetBindingText
local GetBinding = GetBinding
local GetNumBindings = GetNumBindings
local SetBinding = SetBinding
local SetBindingClick = SetBindingClick
local SaveBindings = SaveBindings
local LoadBindings = LoadBindings
local GetCurrentBindingSet = GetCurrentBindingSet
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local StaticPopup_Show = StaticPopup_Show
local StaticPopup_Hide = StaticPopup_Hide
local GameTooltip = GameTooltip
local concat = table.concat

local ActionBar = FA:GetModule("ActionBar")

local POPUP = "SARYCHUI_FA_KEYBIND_MODE"
local NO_KEY_COLOR = { 0.6, 0.6, 0.6 }

local IGNORED_KEYS = {
	LSHIFT = true,
	RSHIFT = true,
	LCTRL = true,
	RCTRL = true,
	LALT = true,
	RALT = true,
	UNKNOWN = true,
	LeftButton = true,
	RightButton = true,
}

local binder

local function isBindable(frame)
	return frame and frame.bindingName and frame:IsObjectType("Button") and frame:GetName()
end

local function addKeys(keys, key, ...)
	if key then
		if not FA.tContains(keys, key) then
			keys[#keys + 1] = key
		end
		return addKeys(keys, ...)
	end
	return keys
end

local function buttonKeys(button)
	local keys = addKeys({}, GetBindingKey(button.bindingName))
	if button.blizzardBinding then
		addKeys(keys, GetBindingKey(button.blizzardBinding))
	end
	return keys
end

local function showTooltip(target)
	GameTooltip:SetOwner(binder, "ANCHOR_RIGHT")
	GameTooltip:SetText(target:GetName(), 1, 1, 1)
	local keys = buttonKeys(target)
	if #keys == 0 then
		GameTooltip:AddLine(SarychUI:T("Клавиша не назначена"), NO_KEY_COLOR[1], NO_KEY_COLOR[2], NO_KEY_COLOR[3])
	else
		for i = 1, #keys do
			GameTooltip:AddLine(GetBindingText(keys[i], "KEY_"))
		end
	end
	GameTooltip:Show()
end

local function onUpdate(self)
	local focus = GetMouseFocus()
	if focus == self or focus == self.target then
		if focus == self and self.target and not GameTooltip:IsOwned(self) then
			showTooltip(self.target)
		end
		return
	end

	if isBindable(focus) then
		self:SetAllPoints(focus)
		self:SetAlpha(1)
		self.target = focus
	else
		self:SetAlpha(0)
		self:ClearAllPoints()
		if self.target then
			self.target = nil
			GameTooltip:Hide()
		end
	end
end

local function normalizeKey(key)
	if key == "MiddleButton" then
		return "BUTTON3"
	elseif key:find("^Button%d+$") then
		return key:upper()
	end
	return key
end

local function clearKeys(key, ...)
	if key then
		SetBinding(key, nil)
		return clearKeys(...)
	end
end

local function commandLabel(command)
	local buttonName = command:match("^CLICK (.+):")
	if buttonName then
		return buttonName
	end
	return GetBindingText(command, "BINDING_NAME_")
end

local function onKey(self, key)
	local target = self.target
	if not target or IGNORED_KEYS[key] then
		return
	end

	if key == "ESCAPE" then
		clearKeys(GetBindingKey(target.bindingName))
		if target.blizzardBinding then
			clearKeys(GetBindingKey(target.blizzardBinding))
		end
		showTooltip(target)
		return
	end

	local combo = normalizeKey(key)
	if IsShiftKeyDown() then
		combo = "SHIFT-" .. combo
	end
	if IsControlKeyDown() then
		combo = "CTRL-" .. combo
	end
	if IsAltKeyDown() then
		combo = "ALT-" .. combo
	end

	local previous = GetBindingAction(combo)
	if previous and previous ~= "" and previous ~= target.bindingName and previous ~= target.blizzardBinding then
		FA.Print("%s: снята привязка с %s", GetBindingText(combo, "KEY_"), commandLabel(previous))
	end
	SetBindingClick(combo, target:GetName())
	showTooltip(target)
end

local function onMouseWheel(self, delta)
	onKey(self, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end

local function closeBinder()
	binder:Hide()
	binder:ClearAllPoints()
	binder.target = nil
	GameTooltip:Hide()
	ActionBar:UpdateGrid()
end

local function createBinder()
	binder = CreateFrame("Frame")
	binder:Hide()
	binder:SetFrameStrata("DIALOG")
	binder:EnableMouse(true)
	binder:EnableMouseWheel(true)
	binder:EnableKeyboard(true)
	binder:SetScript("OnUpdate", onUpdate)
	binder:SetScript("OnKeyUp", onKey)
	binder:SetScript("OnMouseUp", onKey)
	binder:SetScript("OnMouseWheel", onMouseWheel)

	local highlight = binder:CreateTexture()
	highlight:SetAllPoints()
	highlight:SetTexture(0, 1, 0, 0.4)

	StaticPopupDialogs[POPUP] = {
		text = SarychUI:T("Наведите курсор на любую кнопку панели команд и нажмите клавишу, чтобы назначить её. Escape снимает все клавиши с кнопки под курсором."),
		button1 = SarychUI:T("Сохранить"),
		button2 = SarychUI:T("Отменить"),
		OnAccept = function()
			SaveBindings(GetCurrentBindingSet())
			closeBinder()
		end,
		OnCancel = function()
			LoadBindings(GetCurrentBindingSet())
			closeBinder()
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = false,
		preferredIndex = 3,
	}
end

function ActionBar:IsBindMode()
	return binder ~= nil and binder:IsShown()
end

function ActionBar:ToggleBindMode()
	if not binder then
		createBinder()
	end

	if binder:IsShown() then
		closeBinder()
		StaticPopup_Hide(POPUP)
	elseif InCombatLockdown() then
		FA.Print("нельзя менять привязки клавиш в бою")
	else
		StaticPopupDialogs[POPUP].text = SarychUI:T("Наведите курсор на любую кнопку панели команд и нажмите клавишу, чтобы назначить её. Escape снимает все клавиши с кнопки под курсором.")
		StaticPopupDialogs[POPUP].button1 = SarychUI:T("Сохранить")
		StaticPopupDialogs[POPUP].button2 = SarychUI:T("Отменить")
		binder:Show()
		ActionBar:UpdateGrid()
		StaticPopup_Show(POPUP)
	end
end

SlashCmdList.SARYCHUI_FA_BIND = function()
	if FA.IsActive() then
		ActionBar:ToggleBindMode()
	else
		FA.Print("режим привязки клавиш доступен только для свободных панелей")
	end
end
SLASH_SARYCHUI_FA_BIND1 = "/suibind"

local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:SetScript("OnEvent", function()
	if binder and binder:IsShown() then
		StaticPopupDialogs[POPUP].OnCancel()
		StaticPopup_Hide(POPUP)
		FA.Print("режим привязки клавиш закрыт: начался бой, изменения отменены")
	end
end)

local overrideOwner = CreateFrame("Frame")
local commandTargets = {}
local overrides, overrideCount = {}, 0
local overrideSignature

local function addOverrides(target, key, ...)
	if key then
		overrides[overrideCount + 1] = key
		overrides[overrideCount + 2] = target
		overrideCount = overrideCount + 2
		return addOverrides(target, ...)
	end
end

local function collectOverrides(command, ...)
	local target = commandTargets[command]
	if target then
		addOverrides(target, ...)
	end
end

function ActionBar:UpdateOverrideBindings()
	if InCombatLockdown() then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateOverrideBindings")
		return
	end
	self:UnregisterEvent("PLAYER_REGEN_ENABLED", "UpdateOverrideBindings")

	for i = overrideCount, 1, -1 do
		overrides[i] = nil
	end
	overrideCount = 0
	for i = 1, GetNumBindings() do
		collectOverrides(GetBinding(i))
	end

	local signature = concat(overrides, " ")
	if signature == overrideSignature then
		return
	end
	overrideSignature = signature
	-- Resolve these two APIs at call time. SnowfallKeyPress hooks their global
	-- versions after this file is loaded and replaces the binding with its
	-- key-down proxy (which also owns the flash animation).
	_G.ClearOverrideBindings(overrideOwner)
	for i = 1, overrideCount, 2 do
		-- These bindings replace Blizzard buttons which are deliberately removed
		-- in Frost mode.  They must be priority bindings: embedded key-down
		-- helpers such as Snowfall install ordinary overrides later and would
		-- otherwise send ACTIONBUTTON1..12 back to the removed ActionButtonN
		-- frames, making the keys appear completely dead.
		_G.SetOverrideBindingClick(overrideOwner, true, overrides[i], overrides[i + 1], "LeftButton")
	end
end

-- Re-register the same keys when SnowfallKeyPress is enabled at runtime so its
-- newly active secure hook can wrap the Frost buttons as well.
function ActionBar:RefreshOverrideBindings()
	overrideSignature = nil
	self:UpdateOverrideBindings()
end

local function mapButtons(buttons)
	for i = 1, #buttons do
		local button = buttons[i]
		if button.blizzardBinding then
			commandTargets[button.blizzardBinding] = button:GetName()
		end
	end
end

function ActionBar:InitializeOverrideBindings()
	for page = 1, self.NUM_BARS do
		mapButtons(self.bars[page].buttons)
	end
	mapButtons(self.petButtons)
	self:RegisterEvent("UPDATE_BINDINGS", "UpdateOverrideBindings")
	self:UpdateOverrideBindings()
end
