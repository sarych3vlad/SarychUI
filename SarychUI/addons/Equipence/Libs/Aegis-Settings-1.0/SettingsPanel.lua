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
local SettingsUtil = Options.SettingsUtil;
local SettingsUITemplates = Options.SettingsUITemplates;
local SettingsSchema = Options.SettingsSchema;
local SettingsLayout = Options.SettingsLayout;
local SettingControls = Options.SettingControls;

--@natives<lua,wow>
local format = string.format;
local CreateFrame = CreateFrame;
local UIParent = UIParent;

--@class SettingsPanel<table>
Options.SettingsPanel = {};
local SettingsPanel = Options.SettingsPanel;

--@constants
local Backdrop = SettingsUITemplates.Backdrop;
local Color = SettingsUITemplates.Color;
local ApplyBackdrop = SettingsUITemplates.ApplyBackdrop;
local RuntimePanel = SettingsUITemplates.RuntimePanel;
local LayoutType = SettingsConstants.LayoutType;
local InterfacePanelTemplate = "AegisSettingsInterfacePanelTemplate";
local RuntimePanelTemplate = SettingsUITemplates.GetBackdropFrameTemplate("AegisSettingsRuntimePanelTemplate");
local EntryHandlers = {};

function SettingsPanel:Create(config, schema, options)
	local panel = setmetatable({}, { __index = self });
	panel:OnLoad(config, schema, options);
	return panel;
end

function SettingsPanel:OnLoad(config, schema, options)
	self.config = config;
	self.schema = schema;

	if options.registerInterface == false then
		return;
	end

	local name   = config.name .. "Panel";
	local parent = InterfaceOptionsFramePanelContainer or UIParent;
	local panel  = CreateFrame("Frame", name, parent, InterfacePanelTemplate);
	panel.name   = SettingsUtil.Localize(config, schema.nameKey);
	panel:SetAllPoints(parent);

	self.panel = panel;

	local scroll = panel.Scroll;
	local child = scroll.Content;
	child:SetWidth(560);
	child:SetHeight(1);
	scroll:SetScrollChild(child);

	local view = {
		name = name,
		panel = panel,
		scroll = scroll,
		content = child,
		bindings = {},
		controlsInitialized = false,
	};

	local function OnRefresh()
		self:RefreshView(view, config, schema);
	end

	panel.refresh = OnRefresh;
	panel.okay    = function() end;
	panel.cancel  = function() end;
	panel.default = function()
		self:ResetDefaults(config, schema);
		self:Refresh(config, view);

		config.options:ApplyAll();
	end;

	panel:HookScript("OnShow", OnRefresh);
	self.interfaceView = view;

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel);
	end
end

function SettingsPanel:CreateRuntimeView()
	if self.runtimeView then
		return self.runtimeView;
	end

	local config = self.config;
	local schema = self.schema;
	local name   = config.name .. "RuntimeFrame";
	local frame  = CreateFrame("Frame", name, UIParent, RuntimePanelTemplate);
	frame:SetSize(RuntimePanel.Width, RuntimePanel.Height);
	frame:SetPoint(RuntimePanel.Point, UIParent, RuntimePanel.RelativePoint, RuntimePanel.OffsetX, RuntimePanel.OffsetY);
	frame:SetClampedToScreen(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", frame.StartMoving);
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing);

	ApplyBackdrop(frame, Backdrop.RuntimePanel, Color.RuntimeBackdrop, Color.RuntimeBorder);

	frame.Title:SetText(SettingsUtil.Localize(config, schema.titleKey));

	frame.CloseButton:SetScript("OnClick", function()
		frame:Hide();
	end);

	local scroll = frame.Scroll;
	local child = scroll.Content;
	child:SetWidth(RuntimePanel.ContentWidth);
	child:SetHeight(1);
	scroll:SetScrollChild(child);

	local view = {
		name = name,
		panel = frame,
		scroll = scroll,
		content = child,
		bindings = {},
		controlsInitialized = false,
	};

	-- Runtime editing stays in a floating panel so PaperDoll can remain visible;
	-- `SettingsRegistrar` owns native Settings API registration separately.
	frame:HookScript("OnShow", function()
		self:RefreshView(view, config, schema);
	end);

	self.runtimeView = view;
	return view;
end

function SettingsPanel:RefreshView(view, config, schema)
	if not view.controlsInitialized then
		local width = view.scroll:GetWidth();
		if width and width > 0 then
			view.content:SetWidth(width);
		end

		self:Build(view.content, view, config, schema);
	end

	self:Refresh(config, view);
end

function SettingsPanel:AddControl(layout, view, config, schema, item)
	local control = SettingControls[item.type];
	local binding = control:AddToPanel(layout, config, item, schema);
	if binding then
		control:DecorateControl(layout, item, binding);

		if control.Refresh then
			view.bindings[#view.bindings + 1] = binding;
		end
	end
end

function SettingsPanel:AddControlGroup(layout, view, config, schema, item)
	local group = layout:CreateControlGroup(item);
	for i = 1, #item.items do
		self:AddControl(group, view, config, schema, item.items[i]);
	end
	group:ApplyLayout();
end

EntryHandlers[LayoutType.ControlGroup] = SettingsPanel.AddControlGroup;

function SettingsPanel:AddEntry(layout, view, config, schema, item)
	local handler = EntryHandlers[item.layout];
	if handler then
		handler(self, layout, view, config, schema, item);
		return;
	end

	self:AddControl(layout, view, config, schema, item);
end

function SettingsPanel:Build(content, view, config, schema)
	local meta = config.metadata;
	local layout = SettingsLayout:Create(content, view.name);
	layout:CreateTitle(SettingsUtil.Localize(config, schema.titleKey));
	layout:CreateSubText(format(schema.subtitleFormat, meta.notes, meta.version, meta.author, meta.website));

	view.bindings = {};
	local items = SettingsSchema.CreateLayoutList(config, schema.items);

	for i = 1, #items do
		self:AddEntry(layout, view, config, schema, items[i]);
	end

	content:SetHeight(layout:GetScrollHeight());
	view.controlsInitialized = true;
end

function SettingsPanel:RefreshControls(config, view)
	if not view or not view.controlsInitialized then
		return;
	end

	config.isRefreshingControls = true;
	for i = 1, #view.bindings do
		local bind = view.bindings[i];
		bind.handler:Refresh(bind, config);
	end
	config.isRefreshingControls = false;
end

function SettingsPanel:Refresh(config, view)
	if view then
		self:RefreshControls(config, view);
		return;
	end

	self:RefreshControls(config, self.interfaceView);
	self:RefreshControls(config, self.runtimeView);
end

function SettingsPanel:ResetDefaults(config, schema)
	local data = config.data;
	local items = SettingsSchema.FlattenItems(schema.items);

	for i = 1, #items do
		local item = items[i];
		if item.key and item.default ~= nil then
			local tbl = SettingsUtil.ResolveTable(data, item);
			tbl[item.key] = item.default;
		end
	end
end

function SettingsPanel:Open()
	if not self.panel or not InterfaceOptionsFrame_OpenToCategory then
		return false;
	end

	SettingsUtil.CallSecure(InterfaceOptionsFrame_OpenToCategory, self.panel);
	SettingsUtil.CallSecure(InterfaceOptionsFrame_OpenToCategory, self.panel);
	return true;
end

function SettingsPanel:OpenRuntime()
	local view = self:CreateRuntimeView();
	self:RefreshView(view, self.config, self.schema);
	view.panel:Show();
	return true;
end
