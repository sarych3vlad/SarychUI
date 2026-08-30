--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local pairs = pairs;

local VERSION = 5;

local function NormalizeTooltipData(tooltipData)
	if not tooltipData then
		return nil;
	end

	if tooltipData.lines ~= nil then
		return tooltipData;
	end

	local normalized = {};
	for key, value in pairs(tooltipData) do
		normalized[key] = value;
	end
	normalized.lines = {};

	return normalized;
end

Aegis:RegisterNamespace("C_TooltipInfo", VERSION, function(core, _, namespace, native)
	local scanner = core:GetService("TooltipScanner");
	local C_TooltipInfo = namespace or {};

	local useNative = native ~= nil;

	function C_TooltipInfo.GetInventoryItem(unit, slot, hideUselessStats)
		if not unit or not slot then
			return nil;
		end

		if useNative and native.GetInventoryItem then
			return NormalizeTooltipData(native.GetInventoryItem(unit, slot, hideUselessStats));
		end

		-- hideUselessStats: ignored on legacy fallback
		return NormalizeTooltipData(scanner:GetInventoryItem(unit, slot));
	end

	-- C_TooltipInfo.GetHyperlink(hyperlink [, optionalArg1 [, optionalArg2 [, hideVendorPrice]]])
	function C_TooltipInfo.GetHyperlink(hyperlink, comparisonParams, alwaysShowItemComparison)
		if not hyperlink or hyperlink == "" then
			return nil;
		end

		if useNative and native.GetHyperlink then
			return NormalizeTooltipData(native.GetHyperlink(hyperlink, comparisonParams, alwaysShowItemComparison));
		end

		return NormalizeTooltipData(scanner:GetHyperlink(hyperlink));
	end

	return C_TooltipInfo;
end, { trustNative = true, wrapNative = true });