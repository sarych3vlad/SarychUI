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

--@imports<options>
local SettingsUtil = Options.SettingsUtil;

--@natives<lua,wow>
local unpack = unpack;
local BackdropTemplateMixin = BackdropTemplateMixin;

--@class SettingsUITemplates<table>
local SettingsUITemplates = {
	BackdropTemplate = BackdropTemplateMixin and "BackdropTemplate",

	Font = {
		Title = "GameFontNormalLarge",
		Header = "GameFontNormal",
		Text = "GameFontHighlightSmall",
	},

	Backdrop = {
		Section = {
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		},
		DropdownBorder = {
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 12,
			insets = { left = 2, right = 2, top = 2, bottom = 2 },
		},
		DropdownMenu = {
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		},
		RuntimePanel = {
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		},
	},

	Color = {
		SectionBackdrop = { 0.06, 0.06, 0.06, 0.45 },
		SectionBorder = { 0.45, 0.45, 0.45, 0.45 },
		DropdownBorder = { 1, 1, 1, 1 },
		DropdownMenuBackdrop = { 0.10, 0.10, 0.10, 0.95 },
		DropdownMenuBorder = { 1, 1, 1, 1 },
		RuntimeBackdrop = { 0.04, 0.04, 0.04, 0.96 },
		RuntimeBorder = { 0.55, 0.55, 0.55, 0.95 },
	},

	RuntimePanel = {
		Width = 520,
		Height = 640,
		ContentWidth = 470,
		Point = "TOPRIGHT",
		RelativePoint = "TOPRIGHT",
		OffsetX = -32,
		OffsetY = -96,
	},
};

local function OnBackdropSizeChanged() end

local function MixinBackdropTemplate(frame)
	SettingsUtil.Mixin(frame, BackdropTemplateMixin);
	frame.OnBackdropSizeChanged = frame.OnBackdropSizeChanged or OnBackdropSizeChanged;

	if frame.OnBackdropLoaded then
		frame:OnBackdropLoaded();
	end
end

function SettingsUITemplates.ApplyBackdrop(frame, backdrop, backdropColor, borderColor)
	if not frame.SetBackdrop and BackdropTemplateMixin then
		MixinBackdropTemplate(frame);
	end

	if not frame.SetBackdrop then
		return;
	end

	frame:SetBackdrop(backdrop);

	if backdropColor then
		frame:SetBackdropColor(unpack(backdropColor));
	end

	if borderColor then
		frame:SetBackdropBorderColor(unpack(borderColor));
	end
end

function SettingsUITemplates.GetBackdropFrameTemplate(template)
	local backdropTemplate = SettingsUITemplates.BackdropTemplate or "AegisSettingsBackdropFrameTemplate";
	if backdropTemplate then
		if template then
			return backdropTemplate .. "," .. template;
		end

		return backdropTemplate;
	end

	return template;
end

Options.SettingsUITemplates = SettingsUITemplates;
