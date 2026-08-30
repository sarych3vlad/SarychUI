--[[
    Aegis Settings
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

--@class Options<ns>
local MAJOR, MINOR = "Aegis-Settings-1.0", 5;
local Options = LibStub:NewLibrary(MAJOR, MINOR);
if not Options then
	return;
end

Options.MAJOR = MAJOR;
Options.MINOR = MINOR;

--@class SettingsConstants<table>
Options.SettingsConstants = {
	ControlType = {
		SectionBegin = "SectionBegin",
		SectionEnd = "SectionEnd",
		Description = "Description",
		Header = "Header",
		CheckBox = "CheckBox",
		Slider = "Slider",
		Button = "Button",
		Dropdown = "Dropdown",
	},

	LayoutType = {
		ControlGroup = "ControlGroup",
	},

	PanelMode = {
		Settings = "settings",
		InterfaceOptions = "interfaceOptions",
	},

	Position = {
		Top = "TOP",
		Bottom = "BOTTOM",
		Left = "LEFT",
		Right = "RIGHT",
	},
};
