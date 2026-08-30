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

--@natives<lua,wow>
local floor = math.floor;
local max = math.max;
local min = math.min;
local pairs = pairs;
local unpack = unpack;
local securecallfunction = securecallfunction;

local EMPTY_LOCALE_STRING = "";

--@class SettingsUtil<table>
Options.SettingsUtil = {};
local SettingsUtil = Options.SettingsUtil;

function SettingsUtil.Localize(config, localeKey)
	if not localeKey then
		return EMPTY_LOCALE_STRING;
	end
	return config.host:GetLocaleText(localeKey) or localeKey;
end

function SettingsUtil.Clamp(value, minValue, maxValue)
	return min(max(value, minValue), maxValue);
end

function SettingsUtil.Round(value, decimals)
	local precision = 10 ^ (decimals or 0);
	return floor(value * precision + 0.5) / precision;
end

function SettingsUtil.GetValue(storage, key, default)
	local value = storage[key];
	if value == nil then
		return default;
	end

	return value;
end

function SettingsUtil.ValueToBoolean(value)
	return value ~= nil and value ~= false;
end

function SettingsUtil.ResolveTable(storage, item)
	if item.path then
		local tbl = storage;
		for i = 1, #item.path do
			tbl = tbl[item.path[i]];
		end
		return tbl;
	end

	local tableKey = item.table or item.tab;
	if tableKey then
		return storage[tableKey];
	end

	return storage;
end

function SettingsUtil.Mixin(object, mixin)
	for key, value in pairs(mixin) do
		object[key] = value;
	end

	return object;
end

function SettingsUtil.CallSecure(func, ...)
	if securecallfunction then
		return securecallfunction(func, ...);
	end

	return func(...);
end

function SettingsUtil.InvokeApply(config, apply, value, widget)
	if not apply then
		return;
	end

	local target = config;
	if apply.target then
		target = config[apply.target];
	end

	if apply.field then
		if apply.passValue then
			target[apply.field] = value;
		else
			target[apply.field] = apply.value;
		end
		return;
	end

	local method = apply.method and target[apply.method];
	if not method then
		return;
	end

	if apply.args then
		return method(target, unpack(apply.args));
	end

	if apply.passValue then
		return method(target, value, widget);
	end

	return method(target);
end
