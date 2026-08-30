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

--@class SettingsBridge<table>
local SettingsBridge = {};

function SettingsBridge:HasModernSettings()
	if not Settings then
		return false;
	end

	return Settings.RegisterVerticalLayoutCategory ~= nil
	   and Settings.RegisterAddOnCategory ~= nil
	   and Settings.OpenToCategory ~= nil
	   and Settings.RegisterProxySetting ~= nil
	   and Settings.CreateCheckbox ~= nil;
end

function SettingsBridge:CreateSlider(category, setting, minVal, maxVal, step)
	if not Settings or not Settings.CreateSlider then
		return;
	end

	if Settings.CreateSliderOptions then
		local options = Settings.CreateSliderOptions(minVal, maxVal, step);
		return Settings.CreateSlider(category, setting, options);
	end

	-- Branches around the Settings rewrite used direct range arguments.
	return Settings.CreateSlider(category, setting, minVal, maxVal, step);
end

function SettingsBridge:CreateDropdown(category, setting, items, tooltip)
	if not Settings or not Settings.CreateDropdown then
		return;
	end

	if Settings.CreateDropdownOptions then
		local options = Settings.CreateDropdownOptions();
		for i = 1, #items do
			options:Add(items[i].value, items[i].text);
		end
		return Settings.CreateDropdown(category, setting, options, tooltip);
	end

	if Settings.CreateControlTextContainer then
		local function GetOptions()
			local container = Settings.CreateControlTextContainer();
			for i = 1, #items do
				container:Add(items[i].value, items[i].text);
			end
			return container:GetData();
		end
		return Settings.CreateDropdown(category, setting, GetOptions, tooltip);
	end
end

--@export<ns>
Options.SettingsBridge = SettingsBridge;
