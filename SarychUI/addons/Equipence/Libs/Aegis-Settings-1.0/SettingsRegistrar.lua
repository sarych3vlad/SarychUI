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
local SettingsSchema = Options.SettingsSchema;
local SettingsBridge = Options.SettingsBridge;
local SettingControls = Options.SettingControls;

--@class SettingsRegistrar<table>
Options.SettingsRegistrar = {};
local SettingsRegistrar = Options.SettingsRegistrar;

function SettingsRegistrar:IsAvailable()
	return SettingsBridge:HasModernSettings();
end

function SettingsRegistrar:Create(config, schema)
	local registrar = setmetatable({}, { __index = self });
	registrar:OnLoad(config, schema);
	return registrar;
end

function SettingsRegistrar:OnLoad(config, schema)
	local name = SettingsUtil.Localize(config, schema.nameKey);
	local category, layout = Settings.RegisterVerticalLayoutCategory(name);

	local items = SettingsSchema.CreateControlList(config, schema.items);

	for i = 1, #items do
		local item = items[i];
		local control = SettingControls[item.type];
		if control.Register then
			control:Register(category, layout, config, item, schema);
		end
	end

	Settings.RegisterAddOnCategory(category);
	self.category = category;
end

function SettingsRegistrar:Open()
	if not self.category or not Settings.OpenToCategory then
		return;
	end

	local categoryID;
	if self.category.GetID then
		categoryID = self.category:GetID();
	else
		categoryID = self.category.ID;
	end

	if categoryID then
		SettingsUtil.CallSecure(Settings.OpenToCategory, categoryID);
	end
end
