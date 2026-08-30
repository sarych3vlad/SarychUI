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

--@natives<lua>
local type = type;

--@class SettingsSchema<table>
Options.SettingsSchema = {};
local SettingsSchema = Options.SettingsSchema;

local function AddFlatItems(flat, items)
	for i = 1, #items do
		local entry = items[i];
		if entry.layout then
			AddFlatItems(flat, entry.items);
		elseif entry.type then
			flat[#flat + 1] = entry;
		else
			AddFlatItems(flat, entry);
		end
	end
end

local function CreateDropdownItems(config, items)
	local resolved = {};

	for i = 1, #items do
		local entry = items[i];
		if (type(entry) == "table") and entry.key then
			resolved[i] = {
				value = entry.value,
				text = SettingsUtil.Localize(config, entry.key),
			};
		else
			resolved[i] = entry;
		end
	end

	return resolved;
end

local function CreateControlInfo(config, item)
	local info = SettingsUtil.Mixin({}, item);
	info.label = SettingsUtil.Localize(config, item.labelKey);

	if item.items then
		info.items = CreateDropdownItems(config, item.items);
	end

	if item.tooltipKey then
		info.tooltip = SettingsUtil.Localize(config, item.tooltipKey);
	end

	return info;
end

local function AddLayoutEntries(config, list, items)
	for i = 1, #items do
		local entry = items[i];
		if entry.layout then
			local info = SettingsUtil.Mixin({}, entry);
			info.items = SettingsSchema.CreateLayoutList(config, entry.items);
			list[#list + 1] = info;
		elseif entry.type then
			list[#list + 1] = CreateControlInfo(config, entry);
		else
			AddLayoutEntries(config, list, entry);
		end
	end
end

function SettingsSchema.CreateLayoutList(config, items)
	local list = {};
	AddLayoutEntries(config, list, items);
	return list;
end

function SettingsSchema.CreateControlList(config, items)
	local flat = SettingsSchema.FlattenItems(items);
	local list = {};

	for i = 1, #flat do
		list[i] = CreateControlInfo(config, flat[i]);
	end

	return list;
end

function SettingsSchema.FlattenItems(items)
	local flat = {};
	AddFlatItems(flat, items);
	return flat;
end
