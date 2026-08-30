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
local SettingsUITemplates = Options.SettingsUITemplates;
local SettingsDropdownMixin = Options.SettingsDropdownMixin;

--@natives<lua,wow>
local _G = _G;
local tostring = tostring;
local abs = math.abs;
local CreateFrame = CreateFrame;
local UIParent = UIParent;

--@class SettingsLayout<table>
Options.SettingsLayout = {};
local SettingsLayout = Options.SettingsLayout;

--@templates
local Backdrop = SettingsUITemplates.Backdrop;
local Color = SettingsUITemplates.Color;
local Font = SettingsUITemplates.Font;
local ApplyBackdrop = SettingsUITemplates.ApplyBackdrop;
local SectionTemplate = SettingsUITemplates.GetBackdropFrameTemplate("AegisSettingsSectionTemplate");
local DropdownMenuTemplate = SettingsUITemplates.GetBackdropFrameTemplate("AegisSettingsDropdownMenuTemplate");

--@constants
local LAYOUT_LEFT_X = 16;
local LAYOUT_TOP_Y = -16;
local GAP_DEFAULT = -8;
local SCROLL_PADDING = 24;
local LAYOUT_ICON_SIZE = 22;
local LAYOUT_ICON_PADDING = 4;

local SECTION_PADDING_LEFT = 12;
local SECTION_PADDING_RIGHT = 8;
local SECTION_PADDING_TOP = 10;
local SECTION_PADDING_BOTTOM = 10;
local SECTION_TITLE_GAP = 18;
local SECTION_SPACING = 10;

local WIDGET_DROPDOWN_WIDTH = 90;
local WIDGET_SLIDER_WIDTH = 110;
local WIDGET_BUTTON_WIDTH = 120;
local WIDGET_BUTTON_HEIGHT = 24;

local SLIDER_CONTAINER_HEIGHT = 54;
local SLIDER_ROW_HEIGHT = 28;
local SLIDER_STEPPER_SIZE = 24;
local SLIDER_STEPPER_GAP = 4;
local SLIDER_VALUE_WIDTH = 36;
local SLIDER_ROW_LABEL_WIDTH = 110;

local DROPDOWN_PADDING = 40;
local DROPDOWN_HEIGHT = 26;

local CONTROL_GROUP_SPACING = 12;


--@class SettingsLayoutMixin<mixin>
local SettingsLayoutMixin = {};

function SettingsLayout:Create(panel, name)
	return setmetatable({
		panel     = panel,
		name      = name,
		nameIndex = 0,
		left      = LAYOUT_LEFT_X,
		top       = LAYOUT_TOP_Y,
		indent    = 0,
		maxHeight = 0,
		absHeight = 0,
	}, { __index  = SettingsLayoutMixin });
end

function SettingsLayoutMixin:GetContentHeight()
	return self.absHeight;
end

function SettingsLayoutMixin:GetScrollHeight()
	return self.absHeight + SCROLL_PADDING;
end

function SettingsLayoutMixin:GenerateName(suffix)
	self.nameIndex = self.nameIndex + 1;
	return self.name .. suffix .. self.nameIndex;
end

---------------------------------------------------------------------------------------------------
-- Control Groups
---------------------------------------------------------------------------------------------------

-- Scoped horizontal placement context; widget factories are inherited from the owner layout,
-- while placement and final height accounting stay local to the group.
--
--@class SettingsControlGroupMixin<mixin>
local SettingsControlGroupMixin = {};

local function GetControlGroupMethod(_, layoutType)
	return SettingsControlGroupMixin[layoutType] or SettingsLayoutMixin[layoutType];
end

function SettingsLayoutMixin:CreateControlGroup(item)
	local frame = CreateFrame("Frame", nil, self.panel);
	frame:SetSize(1, 1);

	return setmetatable({
		owner   = self,
		panel   = frame,
		spacing = item.spacing or CONTROL_GROUP_SPACING,
		offsetY = item.offsetY,
		width   = 0,
		height  = 1,
		indent  = 0,
	}, { __index = GetControlGroupMethod });
end

function SettingsControlGroupMixin:GenerateName(suffix)
	return self.owner:GenerateName(suffix);
end

function SettingsControlGroupMixin:Anchor(region)
	region:ClearAllPoints();

	local width = region:GetWidth() or 0;
	local height = region:GetHeight() or 0;

	if self.cursor then
		region:SetPoint("TOPLEFT", self.cursor, "TOPRIGHT", self.spacing, 0);
		self.width = self.width + self.spacing + width;
	else
		region:SetPoint("TOPLEFT", 0, 0);
		self.width = width;
	end

	if height > self.height then
		self.height = height;
	end

	self.cursor = region;
	return region;
end

function SettingsControlGroupMixin:ApplyLayout()
	self.panel:SetSize(self.width, self.height);
	self.owner:Anchor(self.panel, self.offsetY);
end

---------------------------------------------------------------------------------------------------
-- Vertical Flow
---------------------------------------------------------------------------------------------------

function SettingsLayoutMixin:Anchor(region, offsetY, offsetX)
	offsetY = offsetY or GAP_DEFAULT;
	offsetX = offsetX or 0;

	region:ClearAllPoints();

	if self.content then
		local extraYOffset = 0;
		local heightLeft = self.content:GetHeight() or 0;
		if self.maxHeight > heightLeft then
			extraYOffset = heightLeft - self.maxHeight;
		end

		region:SetPoint("TOPLEFT", self.content, "BOTTOMLEFT", -self.indent + offsetX, offsetY + extraYOffset);

		local gap = abs(offsetY);
		local height = region:GetHeight() or 0;

		self.cursor = region;
		self.content = region;
		self.indent = 0;
		self.maxHeight = height;
		self.absHeight = self.absHeight + gap + height;
	else
		region:SetPoint("TOPLEFT", self.left + offsetX, self.top);

		local height = region:GetHeight() or 0;

		self.cursor = region;
		self.content = region;
		self.indent = 0;
		self.maxHeight = height;
		self.absHeight = abs(self.top) + height;
	end

	return region;
end

function SettingsLayoutMixin:Indent(region, indent)
	if not indent or indent == 0 then
		return;
	end

	local point, parent, relativePoint, sourceX, sourceY = region:GetPoint(1);
	if not point then
		return;
	end

	region:ClearAllPoints();
	region:SetPoint(point, parent, relativePoint, (sourceX or 0) + indent, sourceY or 0);

	self.indent = self.indent + indent;
end


function SettingsLayoutMixin:AttachIcon(region, texture)
	if not texture then
		return;
	end

	local anchor = region.label or region.Text or region;
	local icon = region:CreateTexture(nil, "ARTWORK");
	icon:SetSize(LAYOUT_ICON_SIZE, LAYOUT_ICON_SIZE);
	icon:SetPoint("RIGHT", anchor, "LEFT", -LAYOUT_ICON_PADDING, 0);
	icon:SetTexture(texture);
	region.Icon = icon;

	return icon;
end


-- Section scopes mirror Blizzard Settings layouts: controls register sequentially,
-- while the layout owns geometry and scroll height accounting.
--
function SettingsLayoutMixin:BeginSection(item)
	self.stack = self.stack or {};
	self.stack[#self.stack + 1] = {
		panel     = self.panel,
		cursor    = self.cursor,
		content   = self.content,
		indent    = self.indent,
		maxHeight = self.maxHeight,
		absHeight = self.absHeight,
		left      = self.left,
		top       = self.top,
	};

	local section = CreateFrame("Frame", nil, self.panel, SectionTemplate);
	self:Anchor(section, -SECTION_SPACING);

	section:SetPoint("RIGHT", self.panel, "RIGHT", -SECTION_PADDING_RIGHT, 0);
	section:SetHeight(1);

	ApplyBackdrop(section, Backdrop.Section, Color.SectionBackdrop, Color.SectionBorder);

	local contentTop = -SECTION_PADDING_TOP;
	if item.label ~= "" then
		section.TitleText:SetText(item.label);
		section.TitleText:Show();

		contentTop = -(SECTION_PADDING_TOP + SECTION_TITLE_GAP);
	else
		section.TitleText:Hide();
	end

	self.panel     = section;
	self.cursor    = nil;
	self.content   = nil;
	self.indent    = 0;
	self.maxHeight = 0;
	self.absHeight = 0;
	self.left      = SECTION_PADDING_LEFT;
	self.top       = contentTop;
	self.section   = section;
end

function SettingsLayoutMixin:EndSection()
	local stack = self.stack;
	if not stack or #stack == 0 then
		return;
	end

	local totalHeight = self:GetContentHeight() + SECTION_PADDING_BOTTOM;
	self.section:SetHeight(totalHeight);

	local saved   = stack[#stack];
	stack[#stack] = nil;
	local section = self.section;

	self.panel     = saved.panel;
	self.cursor    = section;
	self.content   = section;
	self.indent    = 0;
	self.maxHeight = totalHeight;
	self.left      = saved.left;
	self.top       = saved.top;
	self.section   = nil;
	self.absHeight = saved.absHeight + SECTION_SPACING + totalHeight;
end


function SettingsLayoutMixin:CreateTitle(text)
	local fontString = self.panel:CreateFontString(nil, "ARTWORK", Font.Title);
	self:Anchor(fontString, 0);

	fontString:SetText(text);
	return fontString;
end

function SettingsLayoutMixin:CreateSubText(text)
	local fontString = self.panel:CreateFontString(nil, "ARTWORK", Font.Text);
	self:Anchor(fontString, -6);

	fontString:SetText(text);
	fontString:SetJustifyH("LEFT");
	fontString:SetNonSpaceWrap(true);
	fontString:SetHeight(64);
	fontString:SetPoint("RIGHT", self.panel, "RIGHT", -32, 0);
	return fontString;
end

function SettingsLayoutMixin:CreateHeader(item)
	local fontString = self.panel:CreateFontString(nil, "ARTWORK", Font.Header);
	self:Anchor(fontString, -18);

	fontString:SetText(item.label);
	return fontString;
end

function SettingsLayoutMixin:CreateDescription(item)
	local region = CreateFrame("Frame", nil, self.panel, "AegisSettingsDescriptionTemplate");
	region:SetHeight(34);
	self:Anchor(region, -2);

	region:SetPoint("RIGHT", self.panel, "RIGHT", -10, 0);

	local xOffset = 4;
	region.Icon:ClearAllPoints();

	if item.icon then
		region.Icon:SetSize(LAYOUT_ICON_SIZE, LAYOUT_ICON_SIZE);
		region.Icon:SetPoint("LEFT", xOffset, 0);
		region.Icon:SetTexture(item.icon);
		region.Icon:Show();

		xOffset = xOffset + LAYOUT_ICON_SIZE + LAYOUT_ICON_PADDING;
	else
		region.Icon:Hide();
	end

	region.Text:ClearAllPoints();
	region.Text:SetPoint("LEFT", xOffset, 0);
	region.Text:SetPoint("RIGHT", region, "RIGHT", -4, 0);
	region.Text:SetText(item.label);

	return region;
end

function SettingsLayoutMixin:CreateCheckbox(item)
	local name     = self:GenerateName("Checkbox");
	local checkBox = CreateFrame("CheckButton", name, self.panel, "InterfaceOptionsCheckButtonTemplate");
	self:Anchor(checkBox, -4);

	local label = item.label;
	local text = checkBox.Text or _G[name .. "Text"];
	if text then
		text:SetText(label);
	end

	checkBox.tooltipText = item.tooltip or label;
	return checkBox;
end

do
	local function IsSliderRowLayout(item)
		return item.inlineLayout == true;
	end

	local function ClearSliderPoints(frame)
		frame.Label:ClearAllPoints();
		frame.Back:ClearAllPoints();
		frame.Slider:ClearAllPoints();
		frame.Forward:ClearAllPoints();
		frame.ValueText:ClearAllPoints();
	end

	local function ApplySliderRowLayout(layout, frame, item)
		local sliderWidth = item.width or WIDGET_SLIDER_WIDTH;
		local label = frame.Label;
		local slider = frame.Slider;

		frame:SetSize(item.containerWidth or 320, SLIDER_ROW_HEIGHT);
		layout:Anchor(frame, -8);

		label:SetPoint("LEFT", 0, 0);
		label:SetWidth(item.labelWidth or SLIDER_ROW_LABEL_WIDTH);
		label:SetText(frame.labelText);
		label:Show();

		frame.Back:SetPoint("LEFT", label, "RIGHT", SLIDER_STEPPER_GAP, 0);
		slider:SetPoint("LEFT", frame.Back, "RIGHT", SLIDER_STEPPER_GAP, 0);
		frame.Forward:SetPoint("LEFT", slider, "RIGHT", SLIDER_STEPPER_GAP, 0);
		frame.ValueText:SetPoint("LEFT", frame.Forward, "RIGHT", SLIDER_STEPPER_GAP, 0);

		return sliderWidth;
	end

	local function ApplySliderColumnLayout(layout, frame, item)
		local sliderWidth = item.width or WIDGET_SLIDER_WIDTH;
		local containerWidth = item.containerWidth or (sliderWidth + (SLIDER_STEPPER_SIZE + SLIDER_STEPPER_GAP) * 2);
		local slider = frame.Slider;

		frame:SetSize(containerWidth, SLIDER_CONTAINER_HEIGHT);
		layout:Anchor(frame, -14);

		frame.Label:Hide();

		slider:SetPoint("TOPLEFT", SLIDER_STEPPER_SIZE + SLIDER_STEPPER_GAP, -18);
		frame.Back:SetPoint("RIGHT", slider, "LEFT", -SLIDER_STEPPER_GAP, 0);
		frame.Forward:SetPoint("LEFT", slider, "RIGHT", SLIDER_STEPPER_GAP, 0);
		frame.ValueText:SetPoint("TOP", slider, "BOTTOM", SLIDER_STEPPER_GAP, -4);

		return sliderWidth;
	end

	local function ApplySliderNativeText(frame, item, isRowLayout)
		local slider = frame.Slider;
		local sliderText = slider.Text or _G[slider:GetName() .. "Text"];
		local sliderLow  = slider.Low  or _G[slider:GetName() .. "Low"];
		local sliderHigh = slider.High or _G[slider:GetName() .. "High"];

		if isRowLayout then
			if sliderText then
				sliderText:Hide();
			end
			if sliderLow then
				sliderLow:Hide();
			end
			if sliderHigh then
				sliderHigh:Hide();
			end
			return;
		end

		if sliderText then
			sliderText:SetText(frame.labelText);
			sliderText:Show();
		end
		if sliderLow then
			sliderLow:SetText(tostring(item.min));
			sliderLow:Show();
		end
		if sliderHigh then
			sliderHigh:SetText(tostring(item.max));
			sliderHigh:Show();
		end
	end

	function SettingsLayoutMixin:CreateSlider(item)
		local name        = self:GenerateName("Slider");
		local container   = CreateFrame("Frame", nil, self.panel, "AegisSettingsSliderTemplate");
		local slider      = CreateFrame("Slider", name, container, "OptionsSliderTemplate");
		local isRowLayout = IsSliderRowLayout(item);
	
		container.Slider = slider;
		container.labelText = item.label;

		ClearSliderPoints(container);

		container.Back:SetSize(SLIDER_STEPPER_SIZE, SLIDER_STEPPER_SIZE);
		container.Forward:SetSize(SLIDER_STEPPER_SIZE, SLIDER_STEPPER_SIZE);
		container.ValueText:SetWidth(SLIDER_VALUE_WIDTH);

		local sliderWidth;
		if isRowLayout then
			sliderWidth = ApplySliderRowLayout(self, container, item);
		else
			sliderWidth = ApplySliderColumnLayout(self, container, item);
		end

		slider:SetWidth(sliderWidth);
		slider:SetMinMaxValues(item.min, item.max);
		local step = item.step;
		if step then
			slider:SetValueStep(step);
		end

		if step and slider.SetObeyStepOnDrag then
			slider:SetObeyStepOnDrag(true);
		end

		ApplySliderNativeText(container, item, isRowLayout);

		slider.valueText = container.ValueText;
		slider.label = isRowLayout and container.Label or (slider.Text or _G[name .. "Text"]);
		slider.Back = container.Back;
		slider.Forward = container.Forward;

		container.slider = slider;
		return slider;
	end
end

function SettingsLayoutMixin:CreateButton(item)
	local button = CreateFrame("Button", nil, self.panel, "AegisSettingsButtonTemplate");
	button:SetSize(item.width or WIDGET_BUTTON_WIDTH, item.height or WIDGET_BUTTON_HEIGHT);
	button:SetText(item.label);
	self:Anchor(button, -12);
	return button;
end

function SettingsLayoutMixin:CreateDropdown(item)
	local label = item.label;
	if label == "" then
		label = nil;
	end

	local width = item.width or WIDGET_DROPDOWN_WIDTH;
	local labelWidth = item.labelWidth or WIDGET_BUTTON_WIDTH;
	local containerWidth = item.containerWidth;
	if not containerWidth then
		if label then
			containerWidth = labelWidth + width + DROPDOWN_PADDING;
		else
			containerWidth = width;
		end
	end

	local container = CreateFrame("Frame", nil, self.panel, "AegisSettingsDropdownTemplate");
	container:SetSize(containerWidth, DROPDOWN_HEIGHT);
	self:Anchor(container, -4);

	local labelText = container.Label;
	if label then
		labelText:SetPoint("LEFT", 0, 0);
		labelText:SetWidth(labelWidth);
		labelText:SetText(label);
		labelText:Show();
	else
		labelText:Hide();
	end

	local dropdown = container.Dropdown;
	dropdown:SetSize(width, DROPDOWN_HEIGHT);
	if label then
		dropdown:SetPoint("LEFT", labelText, "RIGHT", 8, 0);
	else
		dropdown:SetPoint("TOPLEFT", 0, 0);
	end

	ApplyBackdrop(dropdown.Border, Backdrop.DropdownBorder, nil, Color.DropdownBorder);

	local menu = CreateFrame("Frame", nil, UIParent, DropdownMenuTemplate);
	menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2);
	menu:SetPoint("TOPRIGHT", dropdown, "BOTTOMRIGHT", 0, -2);
	menu:SetFrameStrata("DIALOG");
	menu:SetFrameLevel(dropdown:GetFrameLevel() + 20);
	menu:SetClampedToScreen(true);

	ApplyBackdrop(menu, Backdrop.DropdownMenu, Color.DropdownMenuBackdrop, Color.DropdownMenuBorder);

	menu.lines = {};

	SettingsUtil.Mixin(container, SettingsDropdownMixin);

	container.menu = menu;
	container.items = {};

	dropdown:SetScript("OnClick", function() container:Toggle(); end);
	return container;
end