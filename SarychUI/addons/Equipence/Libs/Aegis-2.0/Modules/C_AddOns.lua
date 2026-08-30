--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local GetNumAddOns = GetNumAddOns;
local GetAddOnInfo = GetAddOnInfo;
local GetAddOnMetadata = GetAddOnMetadata;
local GetAddOnDependencies = GetAddOnDependencies;
local GetAddOnEnableState = GetAddOnEnableState;

local EnableAddOn = EnableAddOn;
local DisableAddOn = DisableAddOn;
local EnableAllAddOns = EnableAllAddOns;
local DisableAllAddOns = DisableAllAddOns;

local IsAddOnLoaded = IsAddOnLoaded;
local IsAddOnLoadOnDemand = IsAddOnLoadOnDemand;
local LoadAddOn = LoadAddOn;
local ResetDisabledAddOns = ResetDisabledAddOns;

local VERSION = 1;

local function GetNormalizedLegacyAddOnInfo(addon)
	-- Legacy GetAddOnInfo:
	-- name, title, notes, enabled, loadable, reason, security
	local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(addon);

	-- Normalize to modern-style shape used by C_AddOns:
	-- name, title, notes, loadable, reason, security, newVersion
	return name, title, notes, loadable, reason, security, nil, enabled;
end

Aegis:RegisterNamespace("C_AddOns", VERSION, function(core, _, namespace, native)
	local C_AddOns = namespace or {};

	-- ---------- Primary wrappers ----------

	function C_AddOns.GetNumAddOns()
		if native and native.GetNumAddOns then
			return native.GetNumAddOns();
		end

		return GetNumAddOns();
	end

	function C_AddOns.GetAddOnInfo(addon)
		if native and native.GetAddOnInfo then
			return native.GetAddOnInfo(addon);
		end

		local name, title, notes, loadable, reason, security, newVersion = GetNormalizedLegacyAddOnInfo(addon);
		return name, title, notes, loadable, reason, security, newVersion;
	end

	function C_AddOns.GetAddOnMetadata(addon, field)
		if native and native.GetAddOnMetadata then
			return native.GetAddOnMetadata(addon, field);
		end

		return GetAddOnMetadata(addon, field);
	end

	function C_AddOns.GetAddOnDependencies(addon)
		if native and native.GetAddOnDependencies then
			return native.GetAddOnDependencies(addon);
		end

		return GetAddOnDependencies(addon);
	end

	function C_AddOns.LoadAddOn(addon)
		if native and native.LoadAddOn then
			return native.LoadAddOn(addon);
		end

		return LoadAddOn(addon);
	end

	function C_AddOns.DisableAddOn(addon, characterName)
		if native and native.DisableAddOn then
			return native.DisableAddOn(addon, characterName);
		end

		return DisableAddOn(addon, characterName);
	end

	function C_AddOns.EnableAddOn(addon, characterName)
		if native and native.EnableAddOn then
			return native.EnableAddOn(addon, characterName);
		end

		return EnableAddOn(addon, characterName);
	end

	function C_AddOns.EnableAllAddOns(characterName)
		if native and native.EnableAllAddOns then
			return native.EnableAllAddOns(characterName);
		end

		return EnableAllAddOns(characterName);
	end

	function C_AddOns.DisableAllAddOns(characterName)
		if native and native.DisableAllAddOns then
			return native.DisableAllAddOns(characterName);
		end

		return DisableAllAddOns(characterName);
	end

	function C_AddOns.GetAddOnEnableState(characterName, addon)
		if native and native.GetAddOnEnableState then
			return native.GetAddOnEnableState(characterName, addon);
		end

		if GetAddOnEnableState then
			return GetAddOnEnableState(characterName, addon);
		end

		-- Fallback approximation if API is missing
		local _, _, _, _, _, _, _, enabled = GetNormalizedLegacyAddOnInfo(addon);
		return enabled and 1 or 0;
	end

	function C_AddOns.IsAddOnLoadable(addon)
		if native and native.IsAddOnLoadable then
			return native.IsAddOnLoadable(addon);
		end

		local _, _, _, loadable = C_AddOns.GetAddOnInfo(addon);
		return loadable;
	end

	function C_AddOns.IsAddOnLoaded(addon)
		if native and native.IsAddOnLoaded then
			return native.IsAddOnLoaded(addon);
		end

		return IsAddOnLoaded(addon);
	end

	function C_AddOns.IsAddOnLoadOnDemand(addon)
		if native and native.IsAddOnLoadOnDemand then
			return native.IsAddOnLoadOnDemand(addon);
		end

		return IsAddOnLoadOnDemand(addon);
	end

	function C_AddOns.ResetDisabledAddOns()
		if native and native.ResetDisabledAddOns then
			return native.ResetDisabledAddOns();
		end

		if ResetDisabledAddOns then
			return ResetDisabledAddOns();
		end
	end

	-- ---------- Convenience helpers ----------

	function C_AddOns.GetAddOnName(addon)
		local name = C_AddOns.GetAddOnInfo(addon);
		return name;
	end

	function C_AddOns.GetAddOnTitle(addon)
		local _, title = C_AddOns.GetAddOnInfo(addon);
		return title;
	end

	function C_AddOns.GetAddOnNotes(addon)
		local _, _, notes = C_AddOns.GetAddOnInfo(addon);
		return notes;
	end

	return C_AddOns;
end, { trustNative = true, wrapNative = true });