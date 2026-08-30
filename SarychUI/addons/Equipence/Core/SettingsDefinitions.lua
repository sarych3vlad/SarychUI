--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<options>
local Options = Engine.Options;
local SettingsConstants = Options.SettingsConstants;
local ControlType = SettingsConstants.ControlType;
local LayoutType = SettingsConstants.LayoutType;
local Position = SettingsConstants.Position;

--@constants
local REFRESH_DISPLAY = { target = "options", method = "RefreshDisplay" };
local REFRESH_PAPERDOLL = { target = "options", method = "RefreshPaperDollLayout" };

local DisplayScope = { Both = "BOTH", Player = "PLAYER", Inspect = "INSPECT" };

local DISPLAY_SCOPE_ITEMS = {
	{ value = DisplayScope.Both, key = "OPTIONS_SCOPE_BOTH" },
	{ value = DisplayScope.Player, key = "OPTIONS_SCOPE_PLAYER" },
	{ value = DisplayScope.Inspect, key = "OPTIONS_SCOPE_INSPECT" },
};

local AVERAGE_POSITION_ITEMS = {
	{ value = Position.Top, key = "OPTIONS_POSITION_TOP" },
	{ value = Position.Bottom, key = "OPTIONS_POSITION_BOTTOM" },
	{ value = Position.Left, key = "OPTIONS_POSITION_LEFT" },
	{ value = Position.Right, key = "OPTIONS_POSITION_RIGHT" },
};

--@class SettingsDefinitions<table>
Engine.SettingsDefinitions = {
	nameKey = Engine.Title,
	titleKey = Engine.Title,
	subtitleFormat = "%s\nVersion: %s\nAuthor: %s\n%s",

	items = {
		{ type = ControlType.SectionBegin, labelKey = "OPTIONS_EQUIPMENT_DISPLAY" },
		{ type = ControlType.Description, labelKey = "OPTIONS_EQUIPMENT_DISPLAY_DESC" },
		{ type = ControlType.CheckBox, key = "showGems", labelKey = "OPTIONS_SHOW_GEMS", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "showEmptySockets", labelKey = "OPTIONS_SHOW_EMPTY_SOCKETS", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "showEnchants", labelKey = "OPTIONS_SHOW_ENCHANTS", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "showMissingEnchants", labelKey = "OPTIONS_SHOW_MISSING_ENCHANTS", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "showItemLevel", labelKey = "OPTIONS_SHOW_ITEM_LEVELS", apply = REFRESH_DISPLAY },
		{ type = ControlType.Dropdown, key = "itemLevelDisplayScope", labelKey = "OPTIONS_ITEM_LEVEL_SCOPE", items = DISPLAY_SCOPE_ITEMS, width = 130, labelWidth = 150, containerWidth = 320, apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "showAverageItemLevel", labelKey = "OPTIONS_SHOW_AVERAGE_ITEM_LEVEL", apply = REFRESH_DISPLAY },
		{ type = ControlType.Dropdown, key = "averageItemLevelDisplayScope", labelKey = "OPTIONS_AVERAGE_ITEM_LEVEL_SCOPE", items = DISPLAY_SCOPE_ITEMS, width = 130, labelWidth = 150, containerWidth = 320, apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "averageItemLevelUseDecimals", labelKey = "OPTIONS_AVERAGE_ITEM_LEVEL_DECIMALS", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "showAverageItemLevelLabel", labelKey = "OPTIONS_AVERAGE_ITEM_LEVEL_LABEL", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "colorAverageItemLevel", labelKey = "OPTIONS_AVERAGE_ITEM_LEVEL_COLOR", apply = REFRESH_DISPLAY },
		{ type = ControlType.Dropdown, key = "averageItemLevelPosition", labelKey = "OPTIONS_AVERAGE_ITEM_LEVEL_POSITION", items = AVERAGE_POSITION_ITEMS, width = 120, labelWidth = 150, containerWidth = 310, apply = REFRESH_DISPLAY },
		{ type = ControlType.SectionEnd },

		{ type = ControlType.Button, labelKey = "OPTIONS_RESET_SETTINGS", width = 160, apply = { target = "options", method = "ResetDefaults" } },

		{ type = ControlType.SectionBegin, labelKey = "OPTIONS_VISUALS" },
		{ type = ControlType.Description, labelKey = "OPTIONS_VISUALS_DESC" },
		{ type = ControlType.CheckBox, key = "useRoundedIcons", labelKey = "OPTIONS_USE_ROUNDED_ICONS", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "animateGemsShine", labelKey = "OPTIONS_ANIMATE_MATCHING_GEMS", apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "shineSize", labelKey = "OPTIONS_SHINE_SIZE", min = 4, max = 24, step = 1, decimals = 0, width = 180, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "shineSpeed", labelKey = "OPTIONS_SHINE_SPEED", min = 0.25, max = 3, step = 0.05, decimals = 2, width = 180, apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "showIconTooltips", labelKey = "OPTIONS_SHOW_ICON_TOOLTIPS", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "disableIconHover", labelKey = "OPTIONS_DISABLE_ICON_HOVER", apply = REFRESH_DISPLAY },

		{ type = ControlType.CheckBox, key = "showQualityBorder", labelKey = "OPTIONS_SHOW_QUALITY_BORDER", apply = REFRESH_DISPLAY },
		{ type = ControlType.CheckBox, key = "colorItemQuality", labelKey = "OPTIONS_COLOR_ITEM_QUALITY", apply = REFRESH_DISPLAY },
		{ type = ControlType.SectionEnd },

		{ type = ControlType.SectionBegin, labelKey = "OPTIONS_ICON_LAYOUT" },
		{ type = ControlType.Description, labelKey = "OPTIONS_ICON_LAYOUT_DESC" },

		{ type = ControlType.Button, labelKey = "OPTIONS_OPEN_RUNTIME_PREVIEW", width = 160, apply = { target = "options", method = "OpenRuntime" } },

		{ type = ControlType.Slider, key = "socketIconSize", labelKey = "OPTIONS_SOCKET_ICON_SIZE", min = 16, max = 40, step = 1, decimals = 0, width = 120, containerWidth = 300, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "enchantIconSize", labelKey = "OPTIONS_ENCHANT_ICON_SIZE", min = 16, max = 40, step = 1, decimals = 0, width = 120, containerWidth = 300, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "inlineIconGap", labelKey = "OPTIONS_ICON_GAP", min = 0, max = 16, step = 1, decimals = 0, width = 120, containerWidth = 300, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "x", path = { "layoutOffsets", "LEFT" }, settingScope = "layoutOffsetsLeft", labelKey = "OPTIONS_LEFT_HORIZONTAL", min = -60, max = 60, step = 1, decimals = 0, width = 120, containerWidth = 218, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "y", path = { "layoutOffsets", "LEFT" }, settingScope = "layoutOffsetsLeft", labelKey = "OPTIONS_LEFT_VERTICAL", min = -60, max = 60, step = 1, decimals = 0, width = 120, containerWidth = 218, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "x", path = { "layoutOffsets", "RIGHT" }, settingScope = "layoutOffsetsRight", labelKey = "OPTIONS_RIGHT_HORIZONTAL", min = -60, max = 60, step = 1, decimals = 0, width = 120, containerWidth = 218, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "y", path = { "layoutOffsets", "RIGHT" }, settingScope = "layoutOffsetsRight", labelKey = "OPTIONS_RIGHT_VERTICAL", min = -60, max = 60, step = 1, decimals = 0, width = 120, containerWidth = 218, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "x", path = { "layoutOffsets", "TOP" }, settingScope = "layoutOffsetsTop", labelKey = "OPTIONS_TOP_HORIZONTAL", min = -60, max = 60, step = 1, decimals = 0, width = 120, containerWidth = 218, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.Slider, key = "y", path = { "layoutOffsets", "TOP" }, settingScope = "layoutOffsetsTop", labelKey = "OPTIONS_TOP_VERTICAL", min = -60, max = 60, step = 1, decimals = 0, width = 120, containerWidth = 218, inlineLayout = true, labelWidth = 120, apply = REFRESH_DISPLAY },
		{ type = ControlType.SectionEnd },

		{ type = ControlType.SectionBegin, labelKey = "OPTIONS_PAPERDOLL_LAYOUT" },
		{ type = ControlType.Description, labelKey = "OPTIONS_PAPERDOLL_LAYOUT_DESC" },
		{ type = ControlType.CheckBox, key = "useModelCentering", labelKey = "OPTIONS_MODEL_CENTERING", apply = REFRESH_PAPERDOLL },
		{ type = ControlType.CheckBox, key = "fadeCharacterAttributes", labelKey = "OPTIONS_FADE_CHARACTER_ATTRIBUTES", apply = REFRESH_PAPERDOLL },
		{ type = ControlType.CheckBox, key = "hideCharacterAttributes", labelKey = "OPTIONS_HIDE_CHARACTER_ATTRIBUTES", apply = REFRESH_PAPERDOLL },
		{ type = ControlType.CheckBox, key = "showAmmoSlot", labelKey = "OPTIONS_SHOW_AMMO_SLOT", apply = REFRESH_PAPERDOLL },
		{ type = ControlType.Slider, key = "characterAttributesFadedAlpha", labelKey = "OPTIONS_FADED_ATTRIBUTES_ALPHA", min = 0, max = 1, step = 0.01, decimals = 2, width = 180, apply = REFRESH_PAPERDOLL },
		{ type = ControlType.Slider, key = "characterAttributesFadeDuration", labelKey = "OPTIONS_ATTRIBUTES_FADE_DURATION", min = 0, max = 1, step = 0.05, decimals = 2, width = 180, apply = REFRESH_PAPERDOLL },
		{ type = ControlType.SectionEnd },
	},
};
