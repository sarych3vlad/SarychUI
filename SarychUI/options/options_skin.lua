-- SarychUI-only visual layer. Global AceGUI/AceConfig stay untouched.
-- Hooks here are dispatch only: they call skin functions after IsSarychUIOwned check.

local ADDON_NAME = "SarychUI"

local COMPACT_RAID_DROPDOWN_PREFIXES = {
	"CompactRaid",
	"CompactParty",
	"CompactUnitFrame",
}

local DEFAULT_DROPDOWN_CHECK_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"
local RADIO_CHECK_TEXTURE = "Interface\\AddOns\\SarychUI\\addons\\CompactRaidFrame\\Media\\COMMON\\UI-DropDownRadioChecks"

local CONFIG_TITLE_Y_ON_HEADER = -19

local PANE_BACKDROP_COLOR = { 0.1, 0.1, 0.1, 0.5 }
local PANE_BORDER_COLOR = { 0.4, 0.4, 0.4 }

function SarychUI:MarkSarychUIOwnedRoot(frame)
	if frame then
		frame.SarychUIOwnedRoot = true
	end
end

function SarychUI:IsSarychUIOwned(frame)
	if not frame then
		return false
	end

	local ownerDropdown = rawget(frame, "SarychUIOwnerDropdown")
	if ownerDropdown then
		return self:IsSarychUIOwned(ownerDropdown)
	end

	local f = frame
	local depth = 0
	while f and depth < 64 do
		if rawget(f, "SarychUIOwnedRoot") == true then
			return true
		end
		f = f.GetParent and f:GetParent() or nil
		depth = depth + 1
	end
	return false
end

local function ApplyPaneBackdrop(frame)
	if not frame or not frame.SetBackdropColor then
		return
	end
	frame:SetBackdropColor(PANE_BACKDROP_COLOR[1], PANE_BACKDROP_COLOR[2], PANE_BACKDROP_COLOR[3], PANE_BACKDROP_COLOR[4])
	frame:SetBackdropBorderColor(PANE_BORDER_COLOR[1], PANE_BORDER_COLOR[2], PANE_BORDER_COLOR[3])
end

local function ResolveFrameTitleBackground(widget, titletext)
	if widget and widget.titlebg then
		return widget.titlebg
	end
	if titletext and titletext.GetPoint then
		local _, relFrame = titletext:GetPoint(1)
		if not relFrame then
			_, relFrame = titletext:GetPoint()
		end
		if relFrame then
			return relFrame
		end
	end
	return widget and widget.frame
end

function SarychUI:ApplyConfigFrameTitleLayout(widget)
	if not widget or not widget.titletext then
		return
	end
	if not self:IsSarychUIOwned(widget.frame) then
		return
	end

	local titletext = widget.titletext
	local titleParent = ResolveFrameTitleBackground(widget, titletext)
	if not titleParent then
		return
	end

	titletext:ClearAllPoints()
	titletext:SetPoint("TOP", titleParent, "TOP", 0, CONFIG_TITLE_Y_ON_HEADER)

	local _, titlebg = titletext:GetPoint(1)
	if not titlebg then
		_, titlebg = titletext:GetPoint()
	end
	if titlebg and titlebg.SetWidth then
		titlebg:SetWidth((titletext:GetWidth() or 0) + 10)
	end
end

function SarychUI:EnsureSarychUIConfigFrameTitleHooks(widget)
	if not widget or widget._sarychTitleLayoutHooked then
		return
	end
	if not self:IsSarychUIOwned(widget.frame) then
		return
	end
	widget._sarychTitleLayoutHooked = true

	if widget.SetTitle then
		local originalSetTitle = widget.SetTitle
		widget.SetTitle = function(self, title)
			originalSetTitle(self, title)
			if SarychUI:IsSarychUIOwned(self.frame) then
				SarychUI:ApplyConfigFrameTitleLayout(self)
			end
		end
	end

	local nativeFrame = widget.frame
	if nativeFrame and not nativeFrame._sarychTitleShowHooked then
		nativeFrame._sarychTitleShowHooked = true
		nativeFrame:HookScript("OnShow", function()
			if SarychUI:IsSarychUIOwned(widget.frame) then
				SarychUI:ApplyConfigFrameTitleLayout(widget)
			end
		end)
	end

	self:ApplyConfigFrameTitleLayout(widget)
end

function SarychUI:RefreshSarychUIConfigFrameTitleLayout()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	local widget = ACD and ACD.OpenFrames and ACD.OpenFrames[ADDON_NAME]
	if not widget then
		return
	end
	self:EnsureSarychUIConfigFrameTitleHooks(widget)
	self:ApplyConfigFrameTitleLayout(widget)
end

local function LinkDropdownPulloutOwner(widget)
	if not widget or not widget.pullout or not widget.pullout.frame or not widget.frame then
		return
	end
	if not SarychUI:IsSarychUIOwned(widget.frame) then
		return
	end
	widget.pullout.frame.SarychUIOwnerDropdown = widget.frame
end

local function ClearDropdownPulloutOwner(widget)
	if widget and widget.pullout and widget.pullout.frame then
		widget.pullout.frame.SarychUIOwnerDropdown = nil
	end
end

function SarychUI:SkinSarychDropdown(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	if self.InstallOwnedDropdownEnhancements then
		self:InstallOwnedDropdownEnhancements(widget)
	end
	self:PatchOwnedDropdownDisplay(widget)
	LinkDropdownPulloutOwner(widget)

	if not widget._sarychDropdownReleaseHooked and widget.OnRelease then
		widget._sarychDropdownReleaseHooked = true
		local originalOnRelease = widget.OnRelease
		widget.OnRelease = function(self)
			ClearDropdownPulloutOwner(self)
			if originalOnRelease then
				originalOnRelease(self)
			end
		end
	end
end

function SarychUI:SkinSarychButton(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	if self.InstallOwnedButtonEnhancements then
		self:InstallOwnedButtonEnhancements(widget)
	end
end

function SarychUI:SkinSarychCheckBox(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	if self.InstallOwnedCheckBoxEnhancements then
		self:InstallOwnedCheckBoxEnhancements(widget)
	end
end

function SarychUI:SkinSarychSlider(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
end

function SarychUI:SkinSarychEditBox(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	if self.InstallOwnedEditBoxEnhancements then
		self:InstallOwnedEditBoxEnhancements(widget)
	end
end

function SarychUI:SkinSarychInlineGroup(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	ApplyPaneBackdrop(widget.border)
end

function SarychUI:SkinSarychTabGroup(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	ApplyPaneBackdrop(widget.border)
end

function SarychUI:SkinSarychTreeGroup(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	ApplyPaneBackdrop(widget.treeframe)
	ApplyPaneBackdrop(widget.border)
end

function SarychUI:SkinSarychDropdownGroup(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	ApplyPaneBackdrop(widget.border)
	if widget.dropdown then
		self:SkinSarychDropdown(widget.dropdown)
	end
end

function SarychUI:SkinSarychFrame(widget)
	if not widget or not self:IsSarychUIOwned(widget.frame) then
		return
	end
	if self.InstallOwnedFrameEnhancements then
		self:InstallOwnedFrameEnhancements(widget)
	end
	self:EnsureSarychUIConfigFrameTitleHooks(widget)
	self:ApplyConfigFrameTitleLayout(widget)
end

local OWNED_WIDGET_SKINNERS = {
	Frame = "SkinSarychFrame",
	Dropdown = "SkinSarychDropdown",
	DropdownGroup = "SkinSarychDropdownGroup",
	InlineGroup = "SkinSarychInlineGroup",
	TabGroup = "SkinSarychTabGroup",
	TreeGroup = "SkinSarychTreeGroup",
	Button = "SkinSarychButton",
	CheckBox = "SkinSarychCheckBox",
	Slider = "SkinSarychSlider",
	EditBox = "SkinSarychEditBox",
}

function SarychUI:ApplyOwnedAceGUIWidgetSkin(widget)
	if not widget or not widget.frame or not self:IsSarychUIOwned(widget.frame) then
		return
	end

	local widgetType = widget.type
	if widgetType == "Dropdown" then
		self:SkinSarychDropdown(widget)
	elseif widgetType == "DropdownGroup" then
		self:SkinSarychDropdownGroup(widget)
	else
		local methodName = OWNED_WIDGET_SKINNERS[widgetType]
		if methodName and self[methodName] then
			self[methodName](self, widget)
		end
	end
end

function SarychUI:SkinOwnedAceGUIWidgetTree(widget, seen)
	if not widget or type(widget) ~= "table" then
		return
	end
	seen = seen or {}
	if seen[widget] then
		return
	end
	seen[widget] = true

	if self:IsSarychUIOwned(widget.frame) then
		self:ApplyOwnedAceGUIWidgetSkin(widget)
	end

	if widget.children then
		for i = 1, #widget.children do
			self:SkinOwnedAceGUIWidgetTree(widget.children[i], seen)
		end
	end
	if widget.dropdown then
		self:SkinOwnedAceGUIWidgetTree(widget.dropdown, seen)
	end
end

function SarychUI:SkinOwnedSarychUIConfigTree()
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	local widget = ACD and ACD.OpenFrames and ACD.OpenFrames[ADDON_NAME]
	if not widget then
		return
	end
	self:SkinOwnedAceGUIWidgetTree(widget)
end

local function OnAceGUIWidgetParented(widget)
	if not widget or not widget.frame then
		return
	end
	if not SarychUI:IsSarychUIOwned(widget.frame) then
		return
	end
	SarychUI:ApplyOwnedAceGUIWidgetSkin(widget)
end

local function InstallAceGUIContainerAddChildDispatch()
	local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
	if not AceGUI or not AceGUI.WidgetContainerBase or AceGUI._sarychContainerAddChildDispatch then
		return
	end
	AceGUI._sarychContainerAddChildDispatch = true

	local originalAddChild = AceGUI.WidgetContainerBase.AddChild
	AceGUI.WidgetContainerBase.AddChild = function(self, child, beforeWidget)
		originalAddChild(self, child, beforeWidget)
		OnAceGUIWidgetParented(child)
	end

	local originalAddChildren = AceGUI.WidgetContainerBase.AddChildren
	if originalAddChildren then
		AceGUI.WidgetContainerBase.AddChildren = function(self, ...)
			originalAddChildren(self, ...)
			for i = 1, select("#", ...) do
				OnAceGUIWidgetParented(select(i, ...))
			end
		end
	end
end

local function IsCompactRaidDropdownOwner(dropdownFrame)
	if not dropdownFrame or not dropdownFrame.GetName then
		return false
	end
	local name = dropdownFrame:GetName() or ""
	for i = 1, #COMPACT_RAID_DROPDOWN_PREFIXES do
		local prefix = COMPACT_RAID_DROPDOWN_PREFIXES[i]
		if name:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function ResolveOpenDropdownMenuFrame()
	local openMenu = _G.UIDROPDOWNMENU_OPEN_MENU
	if type(openMenu) == "string" then
		openMenu = _G[openMenu]
	end
	return openMenu
end

function SarychUI:ShouldApplyDropdownListSkin()
	local openMenu = ResolveOpenDropdownMenuFrame()
	if not openMenu then
		return false
	end
	if self:IsSarychUIOwned(openMenu) then
		return true
	end
	return IsCompactRaidDropdownOwner(openMenu)
end

local function RestoreDropDownListButtonDefaults(listFrameName, index)
	local check = _G[listFrameName .. "Button" .. index .. "Check"]
	local uncheck = _G[listFrameName .. "Button" .. index .. "UnCheck"]
	if check then
		check:SetTexCoord(0, 1, 0, 1)
		check:SetTexture(DEFAULT_DROPDOWN_CHECK_TEXTURE)
		check:SetDesaturated(false)
		check:SetAlpha(1)
	end
	if uncheck then
		uncheck:Hide()
	end
end

local function RestoreDropDownListDefaults(level)
	local listFrame = _G["DropDownList" .. level]
	if not listFrame or not listFrame.GetName or not listFrame.numButtons then
		return
	end
	local listFrameName = listFrame:GetName()
	local numButtons = tonumber(listFrame.numButtons) or 0
	for index = 1, numButtons do
		RestoreDropDownListButtonDefaults(listFrameName, index)
	end
end

function SarychUI:InstallDropdownListSkinGuard()
	if self._dropdownListSkinGuardInstalled then
		return
	end
	self._dropdownListSkinGuardInstalled = true

	if not hooksecurefunc or not UIDropDownMenu_CreateUnChecked then
		return
	end

	-- True only while we mutated shared DropDownList for an owned/CRF menu.
	local skinnedOpen = false

	hooksecurefunc("UIDropDownMenu_AddButton", function(info, level)
		if not SarychUI:ShouldApplyDropdownListSkin() then
			return
		end

		if not level then
			level = 1
		end

		local listFrame = _G["DropDownList" .. level]
		local index = listFrame and listFrame.numButtons or 1
		listFrame = listFrame or _G["DropDownList" .. level]
		if not listFrame or not listFrame.GetName then
			return
		end
		local listFrameName = listFrame:GetName()

		local button = _G[listFrameName .. "Button" .. index]
		if not button then
			return
		end

		skinnedOpen = true
		UIDropDownMenu_CreateUnChecked(button)

		if not info.notCheckable then
			local check = _G[listFrameName .. "Button" .. index .. "Check"]
			local uncheck = _G[listFrameName .. "Button" .. index .. "UnCheck"]
			if info.disabled then
				check:SetDesaturated(true)
				check:SetAlpha(0.5)
				uncheck:SetDesaturated(true)
				uncheck:SetAlpha(0.5)
			else
				check:SetDesaturated(false)
				check:SetAlpha(1)
				uncheck:SetDesaturated(false)
				uncheck:SetAlpha(1)
			end

			if info.isRadio then
				check:SetTexCoord(0.0, 0.5, 0.5, 1.0)
				check:SetTexture(RADIO_CHECK_TEXTURE)
				uncheck:SetTexCoord(0.5, 1.0, 0.5, 1.0)
				uncheck:SetTexture(RADIO_CHECK_TEXTURE)
			else
				check:SetTexCoord(0, 1, 0, 1)
				check:SetTexture(DEFAULT_DROPDOWN_CHECK_TEXTURE)
			end

			local checked = info.checked
			if type(checked) == "function" then
				checked = checked(button)
			end
			if checked then
				button:LockHighlight()
				check:Show()
				uncheck:Hide()
			else
				button:UnlockHighlight()
				check:Hide()
				uncheck:Show()
			end
		else
			_G[listFrameName .. "Button" .. index .. "Check"]:Hide()
			_G[listFrameName .. "Button" .. index .. "UnCheck"]:Hide()
		end

		if not info.isRadio then
			_G[listFrameName .. "Button" .. index .. "UnCheck"]:Hide()
		end

		button.checked = info.checked
	end)

	-- Scrub only after an open we skinned — never on every random UI dropdown hide.
	if UIDropDownMenu_OnHide then
		hooksecurefunc("UIDropDownMenu_OnHide", function()
			if not skinnedOpen then
				return
			end
			skinnedOpen = false
			local maxLevels = tonumber(UIDROPDOWNMENU_MAXLEVELS) or 2
			for level = 1, maxLevels do
				RestoreDropDownListDefaults(level)
			end
		end)
	end
end

function SarychUI:InstallSarychUIOptionsSkinLayer()
	if self._sarychOptionsSkinLayerInstalled then
		return
	end
	self._sarychOptionsSkinLayerInstalled = true

	self:InstallDropdownListSkinGuard()
	InstallAceGUIContainerAddChildDispatch()
end
