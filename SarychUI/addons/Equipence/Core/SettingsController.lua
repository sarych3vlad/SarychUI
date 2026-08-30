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
local SettingsUtil = Options.SettingsUtil;
local SettingsPanel = Options.SettingsPanel;
local SettingsRegistrar = Options.SettingsRegistrar;
local SettingsSchema = Options.SettingsSchema;

--@natives<lua,wow>
local _G = _G;
local gsub = string.gsub;
local strlower = string.lower;
local strupper = string.upper;
local HideUIPanel = HideUIPanel;
local ShowUIPanel = ShowUIPanel;
local ToggleCharacter = ToggleCharacter;
local InCombatLockdown = InCombatLockdown;

---------------------------------------------------------------------------------------------------
-- Host binds the reusable Options layer to this addon: saved data, schema,
-- localization, metadata, and runtime apply handlers stay outside Options.
---------------------------------------------------------------------------------------------------

--@class SettingsController<table>
local SettingsController = {};
Engine.SettingsController = SettingsController;

function SettingsController:Init(controller, schema)
	if not controller or not schema then
		return;
	end

	self:ApplySchemaDefaults(schema, Engine.Database.Defaults);

	local host = self:CreateHost(controller, schema);

	self.host = host;
	self.schema = schema;
	self.config = self:CreateConfig(host);
	self.mode = self:GetPanelMode();

	if self.mode == SettingsConstants.PanelMode.Settings then
		self.registrar = SettingsRegistrar:Create(self.config, schema);
	end

	self.settingsPanel = SettingsPanel:Create(self.config, schema, {
		registerInterface = self.mode == SettingsConstants.PanelMode.InterfaceOptions,
	});

	self:RegisterSlashCommand();
end

function SettingsController:GetPanelMode()
	if SettingsRegistrar:IsAvailable() then
		return SettingsConstants.PanelMode.Settings;
	end

	return SettingsConstants.PanelMode.InterfaceOptions;
end

function SettingsController:ResolveDefault(item, defaults)
	if not item.key then
		return nil;
	end

	local data = defaults;
	if item.path then
		for i = 1, #item.path do
			data = data[item.path[i]];
		end
	elseif item.table or item.tab then
		data = data[item.table or item.tab];
	end

	return data[item.key];
end

function SettingsController:ApplySchemaDefaults(schema, defaults)
	local items = SettingsSchema.FlattenItems(schema.items);
	for i = 1, #items do
		local item = items[i];
		if item.key and item.default == nil then
			item.default = self:ResolveDefault(item, defaults);
		end
	end
end

function SettingsController:CreateHost(controller, schema)
	local addOnToken = gsub(Engine.Name, "[^%w]", "");
	local settingIDPrefix = strupper(addOnToken) .. "_";
	local slashCommandName = strupper(addOnToken) .. "OPTIONS";
	local slashCommand = "/" .. strlower(Engine.Name);

	local host = {
		name = Engine.Name .. "Options",
		title = Engine.Title,
		data = Engine.Settings,
		schema = schema,
		controller = controller,
		settingIDPrefix = settingIDPrefix,
		slashCommandName = slashCommandName,
		slashCommand = slashCommand,
		shortSlashCommand = "/eqc",
		metadata = {
			title = Engine.Title,
			notes = Engine.Notes,
			version = Engine.Version,
			author = Engine.Author,
			website = Engine.Website,
		},
	};

	function host:GetLocaleText(localeKey)
		return Engine.Localization:GetLocaleText(localeKey);
	end

	return host;
end

function SettingsController:CreateConfig(host)
	return {
		host = host,
		name = host.name,
		title = host.title,
		data = host.data,
		controller = host.controller,
		settingIDPrefix = host.settingIDPrefix,
		slashCommandName = host.slashCommandName,
		slashCommand = host.slashCommand,
		shortSlashCommand = host.shortSlashCommand,
		options = self,
		metadata = host.metadata,
		isRefreshingControls = false,
	};
end

function SettingsController:RegisterSlashCommand()
	if self.slashRegistered then
		return;
	end

	local slashCommandName = self.config.slashCommandName;
	self.slashRegistered = true;

	_G["SLASH_" .. slashCommandName .. "1"] = self.config.slashCommand;
	_G["SLASH_" .. slashCommandName .. "2"] = self.config.shortSlashCommand;

	_G.SlashCmdList[slashCommandName] = function(msg)
		msg = msg or "";
		if msg == "native" then
			self:OpenNative();
		else
			self:OpenRuntime();
		end
	end;
end

function SettingsController:HideUIPanelFrame(frame)
	if not frame or not frame:IsShown() then
		return;
	end

	if InCombatLockdown() then
		return;
	end

	if HideUIPanel then
		SettingsUtil.CallSecure(HideUIPanel, frame);
	else
		frame:Hide();
	end
end

function SettingsController:CloseBlockingPanels()
	self:HideUIPanelFrame(_G.InterfaceOptionsFrame);
	self:HideUIPanelFrame(_G.SettingsPanel);
	self:HideUIPanelFrame(_G.GameMenuFrame);
end

function SettingsController:ShowPaperDollPreview()
	if InCombatLockdown() then
		return;
	end

	local characterFrame = _G.CharacterFrame;
	if characterFrame and characterFrame:IsShown() then
		if _G.CharacterFrame_ShowSubFrame then
			SettingsUtil.CallSecure(_G.CharacterFrame_ShowSubFrame, "PaperDollFrame");
		end
		return;
	end

	if ToggleCharacter then
		SettingsUtil.CallSecure(ToggleCharacter, "PaperDollFrame");
	elseif characterFrame and ShowUIPanel then
		SettingsUtil.CallSecure(ShowUIPanel, characterFrame);
	end
end

function SettingsController:OpenRuntime()
	if not self.config then
		return;
	end

	self:CloseBlockingPanels();
	self:ShowPaperDollPreview();

	self.settingsPanel:OpenRuntime();
end

function SettingsController:OpenNative()
	if not self.config then
		return;
	end

	if InCombatLockdown() then
		return;
	end

	if self.mode == SettingsConstants.PanelMode.Settings then
		self.registrar:Open();
	elseif self.mode == SettingsConstants.PanelMode.InterfaceOptions then
		self.settingsPanel:Open();
	end
end

function SettingsController:ResetDefaults()
	if not self.config or not self.schema then
		return;
	end

	self.settingsPanel:ResetDefaults(self.config, self.schema);

	self:ApplyAll();
	self:Refresh();
end

function SettingsController:RefreshDisplay()
	local controllers = Engine.Controllers;

	controllers.CharacterController:RefreshDisplay();

	if controllers.InspectController then
		controllers.InspectController:RefreshDisplay();
	end
end

function SettingsController:RefreshPaperDollLayout()
	local controller = Engine.Controllers.CharacterController;
	controller:ApplyPaperDollLayout();
	controller:RefreshPaperDollLayout();
end

function SettingsController:ApplyAll()
	self:RefreshDisplay();
	self:RefreshPaperDollLayout();
end

function SettingsController:Refresh()
	self.settingsPanel:Refresh(self.config);
end
