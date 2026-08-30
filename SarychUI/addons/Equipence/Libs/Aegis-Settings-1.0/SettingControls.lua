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
local SettingsConstants = Options.SettingsConstants;
local SettingsBridge = Options.SettingsBridge;
local SettingsUtil = Options.SettingsUtil;

--@natives<lua>
local pairs = pairs;
local type = type;
local tonumber = tonumber;
local tconcat = table.concat;

--@class SettingControls<table>
Options.SettingControls = {};
local SettingControls = Options.SettingControls;

--@internal
function SettingControls:GetSettingID(config, item)
	local scope = item.settingScope or item.table;
	if not scope and item.path then
		scope = tconcat(item.path, "_");
	end

	if scope then
		scope = scope:upper() .. "_";
	else
		scope = "";
	end

	return config.settingIDPrefix .. scope .. item.key:upper();
end

--@class SettingsControlHandler<mixin>
local HandlerBase = {};

function HandlerBase:GetLabel(item)
	return item.label;
end

function HandlerBase:GetTooltip(item)
	return item.tooltip;
end

function HandlerBase:Apply(config, item, value, widget)
	SettingsUtil.InvokeApply(config, item.apply, value, widget);
end

function HandlerBase:ResolveTable(config, itemOrBinding)
	return SettingsUtil.ResolveTable(config.data, itemOrBinding);
end

function HandlerBase:ReadValue(config, item)
	local tbl = self:ResolveTable(config, item);
	local val = tbl[item.key];
	if val == nil then
		val = item.default;
	end
	return val;
end

function HandlerBase:WriteValue(config, item, value)
	local tbl = self:ResolveTable(config, item);
	tbl[item.key] = value;
end

function HandlerBase:IsRefreshing(config)
	return config.isRefreshingControls == true;
end

function HandlerBase:CommitValue(config, item, value, widget)
	if self:IsRefreshing(config) then
		return false;
	end

	if item.key then
		self:WriteValue(config, item, value);
	end

	self:Apply(config, item, value, widget);
	return true;
end

function HandlerBase:CreateBinding(widget, item, extras)
	local binding = {
		handler = self,
		widget  = widget,
		key     = item.key,
		tab     = item.table,
		path    = item.path,
		default = item.default,
	};

	if extras then
		for key, value in pairs(extras) do
			binding[key] = value;
		end
	end

	return binding;
end

function HandlerBase:DecorateControl(builder, item, binding)
	local widget = binding.widget;
	local deco   = item.deco or item;

	if deco.indent then
		builder:Indent(widget, deco.indent);
	end
	if deco.icon then
		builder:AttachIcon(widget, deco.icon);
	end
	if deco.backdrop then
		builder:ApplyBackdrop(widget);
	end
end

function SettingControls:CreateHandler(name)
	local handler = setmetatable({ name = name }, { __index = HandlerBase });
	self[name] = handler;
	return handler;
end


-- Section controls
--
local SectionBegin = SettingControls:CreateHandler(SettingsConstants.ControlType.SectionBegin);

function SectionBegin:AddToPanel(layout, config, item)
	layout:BeginSection(item);
end

function SectionBegin:Register(category, layout, config, item)
	local label = self:GetLabel(item);

	if Settings.CreateCategoryHeader then
		Settings.CreateCategoryHeader(category, label);
	elseif layout and CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(label));
	end
end

local SectionEnd = SettingControls:CreateHandler(SettingsConstants.ControlType.SectionEnd);

function SectionEnd:AddToPanel(layout)
	layout:EndSection();
end


-- Static text controls
--
local Description = SettingControls:CreateHandler(SettingsConstants.ControlType.Description);

function Description:AddToPanel(layout, config, item)
	layout:CreateDescription(item);
end

local Header = SettingControls:CreateHandler(SettingsConstants.ControlType.Header);

function Header:AddToPanel(layout, config, item)
	layout:CreateHeader(item);
end

function Header:Register(category, layout, config, item)
	SectionBegin:Register(category, layout, config, item);
end


-- Value controls
--
local CheckBox = SettingControls:CreateHandler(SettingsConstants.ControlType.CheckBox);

function CheckBox:AddToPanel(layout, config, item)
	local check = layout:CreateCheckbox(item);

	check:SetScript("OnClick", function(widget)
		local value = SettingsUtil.ValueToBoolean(widget:GetChecked());
		self:CommitValue(config, item, value, widget);
	end);

	return self:CreateBinding(check, item);
end

function CheckBox:Register(category, layout, config, item)
	local setting = Settings.RegisterProxySetting(category, SettingControls:GetSettingID(config, item),
		Settings.VarType.Boolean, self:GetLabel(item),
		SettingsUtil.ValueToBoolean(item.default),
		function() return SettingsUtil.ValueToBoolean(self:ReadValue(config, item)); end,
		function(value)
			local checked = SettingsUtil.ValueToBoolean(value);
			self:WriteValue(config, item, checked);
			self:Apply(config, item, checked);
		end
	);
	Settings.CreateCheckbox(category, setting, self:GetTooltip(item));
end

function CheckBox:Refresh(binding, config)
	local tbl = binding.handler:ResolveTable(config, binding);
	binding.widget:SetChecked(SettingsUtil.ValueToBoolean(SettingsUtil.GetValue(tbl, binding.key, binding.default)));
end


local Slider = SettingControls:CreateHandler(SettingsConstants.ControlType.Slider);

function Slider:ClampValue(item, value)
	value = tonumber(value) or item.min;
	value = SettingsUtil.Clamp(value, item.min, item.max);
	if item.decimals then
		value = SettingsUtil.Round(value, item.decimals);
	end

	return value;
end

function Slider:GetValueFormat(item)
	return "%." .. (item.decimals or 1) .. "f";
end

function Slider:UpdateDisplay(slider, item, value)
	slider.valueText:SetFormattedText(self:GetValueFormat(item), value);
end

function Slider:StepValue(item, slider, direction)
	local step = item.step or 1;
	slider:SetValue(self:ClampValue(item, slider:GetValue() + (step * direction)));
end

function Slider:AddToPanel(layout, config, item)
	local slider = layout:CreateSlider(item);

	slider:SetScript("OnValueChanged", function(widget, value)
		value = self:ClampValue(item, value);

		if self:CommitValue(config, item, value, widget) then
			self:UpdateDisplay(widget, item, value);
		end
	end);

	slider.Back:SetScript("OnClick", function()
		if self:IsRefreshing(config) then
			return;
		end

		self:StepValue(item, slider, -1);
	end);

	slider.Forward:SetScript("OnClick", function()
		if self:IsRefreshing(config) then
			return;
		end

		self:StepValue(item, slider, 1);
	end);

	return self:CreateBinding(slider, item, {
		min      = item.min,
		max      = item.max,
		decimals = item.decimals,
	});
end

function Slider:Register(category, layout, config, item)
	local function GetValue()
		return SettingsUtil.Clamp(self:ReadValue(config, item), item.min, item.max);
	end

	local function SetValue(value)
		value = self:ClampValue(item, value);
		self:WriteValue(config, item, value);
		self:Apply(config, item, value);
	end

	local setting = Settings.RegisterProxySetting(
		category,
		SettingControls:GetSettingID(config, item),
		Settings.VarType.Number,
		self:GetLabel(item),
		item.default,
		GetValue,
		SetValue
	);
	SettingsBridge:CreateSlider(category, setting, item.min, item.max, item.step);
end

function Slider:Refresh(binding, config)
	local tbl = binding.handler:ResolveTable(config, binding);
	local value = tbl[binding.key];
	if value == nil then
		value = binding.default;
	end

	value = SettingsUtil.Clamp(value, binding.min, binding.max);
	if binding.decimals then
		value = SettingsUtil.Round(value, binding.decimals);
	end

	binding.widget:SetValue(value);

	self:UpdateDisplay(binding.widget, binding, value);
end


-- Action controls
--
local Button = SettingControls:CreateHandler(SettingsConstants.ControlType.Button);

function Button:AddToPanel(layout, config, item)
	local button = layout:CreateButton(item);

	button:SetScript("OnClick", function(widget)
		self:CommitValue(config, item, true, widget);
	end);

	return { handler = self, widget = button };
end

function Button:Register(category, layout, config, item)
	if not layout or not CreateSettingsButtonInitializer then
		return;
	end

	local label = self:GetLabel(item);
	local init = CreateSettingsButtonInitializer(label, label,
		function()
			self:Apply(config, item, true);
		end,
		self:GetTooltip(item), false
	);
	layout:AddInitializer(init);
end


-- Selection controls
--
local Dropdown = SettingControls:CreateHandler(SettingsConstants.ControlType.Dropdown);

function Dropdown:AddToPanel(layout, config, item)
	local val   = self:ReadValue(config, item);
	local dd    = layout:CreateDropdown(item);
	local items = item.items;

	dd:SetItems(items);
	dd:SetSelectedValue(val, true);

	local handler = self;
	function dd:OnValueChanged(value)
		handler:CommitValue(config, item, value);
	end

	return self:CreateBinding(dd, item, {
		items = items
	});
end

function Dropdown:Register(category, layout, config, item)
	local items = item.items;
	if not items[1] then
		return;
	end

	local varType = Settings.VarType.Number;
	if type(items[1].value) == "string" then
		varType = Settings.VarType.String;
	end
	local setting = Settings.RegisterProxySetting(category, SettingControls:GetSettingID(config, item), varType,
		self:GetLabel(item), item.default,
		function() return self:ReadValue(config, item) end,
		function(value)
			self:WriteValue(config, item, value);
			self:Apply(config, item, value);
		end
	);
	SettingsBridge:CreateDropdown(category, setting, items, self:GetTooltip(item));
end

function Dropdown:Refresh(binding, config)
	local tbl   = binding.handler:ResolveTable(config, binding);
	local value = tbl[binding.key];
	if value == nil then
		value = binding.default;
	end

	if binding.widget:GetSelectedValue() == value then
		return;
	end

	binding.widget:SetSelectedValue(value, true);
end
