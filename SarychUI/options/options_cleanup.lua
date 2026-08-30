-- SarychUI options UI cleanup
-- Hides orphaned AceGUI popups and resets transient UI when the config window closes.

local ADDON_NAME = "SarychUI"
local wipe = wipe
local pairs = pairs
local type = type

SarychUI._optionsExtraFrames = SarychUI._optionsExtraFrames or {}
SarychUI._optionsFadeDrivers = SarychUI._optionsFadeDrivers or {}

function SarychUI:RegisterOptionsFrame(frame)
	if not frame then return end
	self._optionsExtraFrames[frame] = frame
end

function SarychUI:UnregisterOptionsFrame(frame)
	if not frame then return end
	self._optionsExtraFrames[frame] = nil
end

function SarychUI:TrackOptionsFadeDriver(driver)
	if not driver then return end
	self._optionsFadeDrivers[#self._optionsFadeDrivers + 1] = driver
end

function SarychUI:CancelOptionsFadeDrivers()
	local drivers = self._optionsFadeDrivers
	if not drivers then return end
	for i = 1, #drivers do
		local driver = drivers[i]
		if driver then
			driver:SetScript("OnUpdate", nil)
			driver:Hide()
		end
	end
	wipe(drivers)
end

local function HideGlobalFramesByPrefix(prefix)
	local index = 1
	while true do
		local frame = _G[prefix .. index]
		if not frame then
			break
		end
		if frame.Hide then
			frame:Hide()
		end
		index = index + 1
	end
end

local function HideAceGUIPopupFrames()
	-- Do NOT hide AceGUI30Pullout*/DropDown* by global name: AceGUI pools those
	-- frames for all addons. Closing /sui must not tear down foreign options UIs.
	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
end

local function ClearKeyboardFocus()
	if GetCurrentKeyBoardFocus then
		local focus = GetCurrentKeyBoardFocus()
		if focus and focus.ClearFocus then
			-- Only clear focus belonging to SarychUI options.
			if SarychUI.IsSarychUIOwned and SarychUI:IsSarychUIOwned(focus) then
				focus:ClearFocus()
			elseif not (SarychUI.IsSarychUIOwned) then
				focus:ClearFocus()
			end
		end
	end
end

local function HideTooltipsAndPickers()
	if GameTooltip and GameTooltip.Hide then
		GameTooltip:Hide()
	end
	if SarychUI.OptionsWidgets and SarychUI.OptionsWidgets.HideCooltip then
		SarychUI.OptionsWidgets:HideCooltip()
	elseif SarychUIOptionsCooltip and SarychUIOptionsCooltip.Hide then
		SarychUIOptionsCooltip:Hide()
	end
	if ColorPickerFrame and ColorPickerFrame.Hide then
		if not ColorPickerFrame.IsShown or ColorPickerFrame:IsShown() then
			ColorPickerFrame:Hide()
		end
	end
end

local function ResetKeybindingWidget(widget)
	if not widget or widget.type ~= "Keybinding" then
		return
	end
	if widget.msgframe and widget.msgframe.Hide then
		widget.msgframe:Hide()
	end
	if widget.button then
		if widget.button.EnableKeyboard then
			widget.button:EnableKeyboard(false)
		end
		if widget.button.UnlockHighlight then
			widget.button:UnlockHighlight()
		end
	end
	widget.waitingForKey = nil
end

local function HideAceGUIKeybindingOverlays()
	local index = 1
	while true do
		local button = _G["AceGUI30KeybindingButton" .. index]
		if not button then
			break
		end
		local widget = button.obj
		if widget and widget.frame and SarychUI.IsSarychUIOwned and SarychUI:IsSarychUIOwned(widget.frame) then
			ResetKeybindingWidget(widget)
		end
		index = index + 1
	end
end

local function CloseWidgetTransientUI(widget, seen)
	if not widget or type(widget) ~= "table" then
		return
	end
	if seen[widget] then
		return
	end
	seen[widget] = true

	if widget.type == "Dropdown" and widget.open and widget.pullout and widget.pullout.Close then
		pcall(widget.pullout.Close, widget.pullout)
	end
	if widget.pullout and widget.pullout.Close then
		pcall(widget.pullout.Close, widget.pullout)
	end
	if widget.submenu and widget.submenu.Close then
		pcall(widget.submenu.Close, widget.submenu)
	end
	if widget.dropdown and widget.dropdown.pullout and widget.dropdown.pullout.Close then
		pcall(widget.dropdown.pullout.Close, widget.dropdown.pullout)
	end

	ResetKeybindingWidget(widget)

	if widget.ClearFocus then
		pcall(widget.ClearFocus, widget)
	end
	if widget.editbox and widget.editbox.ClearFocus then
		pcall(widget.editbox.ClearFocus, widget.editbox)
	end
	if widget.editBox and widget.editBox.ClearFocus then
		pcall(widget.editBox.ClearFocus, widget.editBox)
	end

	if widget.children then
		for _, child in pairs(widget.children) do
			CloseWidgetTransientUI(child, seen)
		end
	end
end

local function CloseOpenWidgetTransientUI(widget)
	if not widget then return end
	CloseWidgetTransientUI(widget, {})
end

local function GetSarychUIOpenWidget()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.OpenFrames then return end
	return ACD.OpenFrames[ADDON_NAME]
end

function SarychUI:CancelAceConfigDialogPendingRefresh(appName)
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.frame then
		return
	end
	local driver = ACD.frame
	if driver.apps then
		if appName then
			driver.apps[appName] = nil
		else
			wipe(driver.apps)
		end
	end
end

local STATIC_POPUP_FRAMES = {
	StaticPopup1 = true,
	StaticPopup2 = true,
	StaticPopup3 = true,
	StaticPopup4 = true,
}

local function IsProtectedGlobalFrame(frame)
	if not frame then
		return true
	end
	local name = frame.GetName and frame:GetName()
	if name and STATIC_POPUP_FRAMES[name] then
		return true
	end
	if GameTooltip and frame == GameTooltip then
		return true
	end
	if ColorPickerFrame and frame == ColorPickerFrame then
		return true
	end
	if DropDownList1 and (frame == DropDownList1 or frame == DropDownList2) then
		return true
	end
	return false
end

local function IsAceGUIOrphanFrame(child)
	if child.obj and child.obj.type then
		return true
	end
	local frameName = child.GetName and child:GetName()
	if type(frameName) == "string" then
		if frameName:find("^AceGUI30") or frameName:find("^AceGUI%-3%.0") then
			return true
		end
	end
	return false
end

-- Reused buffer so the UIParent walk calls GetChildren() once instead of once per
-- index (UIParent has hundreds of children).
local uiParentChildren = {}

local function FillUIParentChildren(...)
	local n = select("#", ...)
	for i = 1, n do
		uiParentChildren[i] = select(i, ...)
	end
	for i = n + 1, #uiParentChildren do
		uiParentChildren[i] = nil
	end
	return n
end

local function HideOrphanAceGUIFramesOnUIParent()
	local openWidget = GetSarychUIOpenWidget()
	local openNative = openWidget and openWidget.frame
	local numChildren = FillUIParentChildren(UIParent:GetChildren())
	for childIndex = 1, numChildren do
		local child = uiParentChildren[childIndex]
		if not child then
			break
		end
		if child.IsShown and child:IsShown() and child ~= openNative and not IsProtectedGlobalFrame(child) then
			local parent = child.GetParent and child:GetParent()
			if parent == UIParent and IsAceGUIOrphanFrame(child) then
				-- Only hide AceGUI frames that belong to SarychUI options.
				local owned = (SarychUI.IsSarychUIOwned and SarychUI:IsSarychUIOwned(child))
					or (child.obj and child.obj.frame and SarychUI.IsSarychUIOwned and SarychUI:IsSarychUIOwned(child.obj.frame))
				if owned then
					child:Hide()
					if child.SetAlpha then
						child:SetAlpha(1)
					end
				end
			end
		end
	end
end

function SarychUI:ScheduleDeferredOptionsCleanup()
	if not C_Timer or not C_Timer.After then
		return
	end
	if self._optionsDeferredCleanupScheduled then
		return
	end
	self._optionsDeferredCleanupScheduled = true
	C_Timer.After(0, function()
		SarychUI._optionsDeferredCleanupScheduled = nil
		if SarychUI.IsSarychUIOptionsOpen and SarychUI:IsSarychUIOptionsOpen() then
			return
		end
		if SarychUI.CancelAceConfigDialogPendingRefresh then
			SarychUI:CancelAceConfigDialogPendingRefresh(ADDON_NAME)
		end
		if SarychUI.CleanupOptionsUI then
			SarychUI:CleanupOptionsUI({ forceHideFrame = true, deferred = true })
		end
	end)
end

local function HideRegisteredOptionsFrames(forceHide)
	for frame in pairs(SarychUI._optionsExtraFrames) do
		if frame then
			if frame.SetAlpha then
				frame:SetAlpha(1)
			end
			if forceHide and frame.Hide then
				frame:Hide()
			elseif frame.IsShown and frame:IsShown() and frame.Hide then
				frame:Hide()
			end
		end
	end
end

local function HideDragModeElements()
	-- Intentionally empty: closing /sui must not tear down free-move / grid.
	-- Combat-text and other drag sessions stay until Apply, Cancel, ESC, or combat.
end

function SarychUI:CleanupOptionsUI(opts)
	if self._optionsCleaningUp then
		return
	end
	self._optionsCleaningUp = true
	opts = opts or {}

	self:CancelOptionsFadeDrivers()

	local openWidget = GetSarychUIOpenWidget()
	local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
	-- Only clear AceGUI focus when our options were open; never steal focus from foreign dialogs.
	if openWidget and AceGUI and AceGUI.ClearFocus then
		AceGUI:ClearFocus()
	end

	ClearKeyboardFocus()
	HideTooltipsAndPickers()

	if openWidget then
		CloseOpenWidgetTransientUI(openWidget)
	end

	HideAceGUIPopupFrames()
	HideAceGUIKeybindingOverlays()
	if SarychUI.OptionsWidgets and SarychUI.OptionsWidgets.CancelActiveKeybinding then
		SarychUI.OptionsWidgets:CancelActiveKeybinding()
	end

	if openWidget and openWidget.frame then
		openWidget.frame:SetAlpha(1)
		if opts.forceHideFrame and openWidget.frame.Hide then
			openWidget.frame:Hide()
		end
	end

	HideRegisteredOptionsFrames(opts.forceHideFrame)

	if self.GUIFrame then
		if self.GUIFrame.SetAlpha then
			self.GUIFrame:SetAlpha(1)
		end
		if opts.forceHideFrame and self.GUIFrame.Hide then
			self.GUIFrame:Hide()
		end
	end

	HideDragModeElements()
	HideOrphanAceGUIFramesOnUIParent()

	self._optionsCleaningUp = nil
end

function SarychUI:IsSarychUIOptionsOpen()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if not ACD or not ACD.OpenFrames then
		return false
	end
	local open = ACD.OpenFrames[ADDON_NAME]
	if not open then
		return false
	end
	if open.frame and open.frame.IsShown then
		return open.frame:IsShown()
	end
	if open.IsShown then
		return open:IsShown()
	end
	return true
end

function SarychUI:OnSarychUIConfigHidden()
	if self._optionsClosing then
		return
	end
	if self.CleanupOptionsUI then
		self:CleanupOptionsUI({ fromOnHide = true })
	end
end
