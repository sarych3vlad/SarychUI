--[[
    Aegis Settings
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

--@class Options<ns>
local Options = LibStub("Aegis-Settings-1.0");
if Options.MINOR ~= 5 then
	return;
end

--@natives<lua,wow>
local CreateFrame = CreateFrame;
local UIParent = UIParent;

--@constants
local DROPDOWN_MENU_PADDING = 6;
local DROPDOWN_LIST_HEIGHT = 18;

--@internal<util>
local SettingsDropdownState = {};
do
	local active;
	local catcher;

	local function GetCatcher()
		if catcher then
			return catcher;
		end

		catcher = CreateFrame("Button", nil, UIParent);
		catcher:SetAllPoints(UIParent);
		catcher:EnableMouse(true);
		catcher:EnableMouseWheel(true);
		catcher:RegisterForClicks("AnyDown");
		catcher:SetFrameStrata("DIALOG");
		catcher:SetScript("OnClick", function()
			if active then
				active:Close();
			end
		end);
		catcher:SetScript("OnMouseWheel", function()
			if active then
				active:Close();
			end
		end);

		catcher:Hide();
		return catcher;
	end

	function SettingsDropdownState.Open(dd)
		if active and active ~= dd then
			active:Close();
		end
		active = dd;

		local cc = GetCatcher();
		cc:Show();

		-- The catcher sits below the menu so outside clicks close the dropdown
		-- without stealing interaction from the active menu frame.
		local level = (dd.menu:GetFrameLevel() - 1);
		if level <= 0 then
			level = 1;
		end
		cc:SetFrameLevel(level);

		dd.menu:Show();
	end

	function SettingsDropdownState.Close(dd)
		dd.menu:Hide();
		if active == dd then
			active = nil;
		end

		if catcher then
			catcher:Hide();
		end
	end
end


--@class SettingsDropdownMixin<mixin>
local SettingsDropdownMixin = {};

function SettingsDropdownMixin:SetItems(items)
	self.items = items;
	self:LayoutLines();
	self:UpdateText();
end

function SettingsDropdownMixin:SetSelectedValue(value, silent)
	self.value = value;
	self:UpdateText();

	if not silent and self.OnValueChanged then
		self:OnValueChanged(value);
	end
end

function SettingsDropdownMixin:GetSelectedValue()
	return self.value;
end

-- ----- internal

function SettingsDropdownMixin:FindItemText(value)
	local items = self.items;
	for i = 1, #items do
		if items[i].value == value then
			return items[i].text;
		end
	end

	return "";
end

function SettingsDropdownMixin:UpdateText()
	local itemText = self:FindItemText(self.value);
	self.Dropdown.SelectedText:SetText(itemText);
end

function SettingsDropdownMixin:AcquireLine(i)
	local menu = self.menu;
	local line = menu.lines[i];
	if line then
		return line;
	end

	line = CreateFrame("Button", nil, menu, "AegisSettingsDropdownLineTemplate");
	line:SetScript("OnClick", function(button)
		local owner = button.owner;
		owner:SetSelectedValue(button.value);
		owner:Close();
	end);

	menu.lines[i] = line;
	return line;
end

function SettingsDropdownMixin:LayoutLines()
	local menu  = self.menu;
	local items = self.items;

	for i = 1, #menu.lines do
		menu.lines[i]:Hide();
	end

	local height = DROPDOWN_MENU_PADDING * 2;
	for i = 1, #items do
		local line = self:AcquireLine(i);
		line.owner = self;
		line.value = items[i].value;

		line.Text:SetText(items[i].text);
		line:SetHeight(DROPDOWN_LIST_HEIGHT);
		line:ClearAllPoints();
		line:SetPoint("TOPLEFT", DROPDOWN_MENU_PADDING, -(DROPDOWN_MENU_PADDING + (i - 1) * DROPDOWN_LIST_HEIGHT));
		line:SetPoint("RIGHT", -DROPDOWN_MENU_PADDING, 0);
		line:Show();

		height = height + DROPDOWN_LIST_HEIGHT;
	end

	menu:SetHeight(height);
end

-- ----- open/close

function SettingsDropdownMixin:Open()
	if self.menu:IsShown() then
		return;
	end

	SettingsDropdownState.Open(self);
end

function SettingsDropdownMixin:Close()
	if not self.menu:IsShown() then
		return;
	end

	SettingsDropdownState.Close(self);
end

function SettingsDropdownMixin:Toggle()
	if self.menu:IsShown() then
		self:Close();
	else
		self:Open();
	end
end

--@export<ns>
Options.SettingsDropdownMixin = SettingsDropdownMixin;
