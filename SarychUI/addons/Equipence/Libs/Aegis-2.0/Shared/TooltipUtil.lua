--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local type = type;

local VERSION = 1;
local EMPTY_LINES = {};

Aegis:RegisterNamespace("TooltipUtil", VERSION, function(_, _, namespace)
	local TooltipUtil = namespace or {};

	function TooltipUtil.GetLines(tooltipData)
		return tooltipData and tooltipData.lines or EMPTY_LINES;
	end

	function TooltipUtil.GetLineCount(tooltipData)
		return #TooltipUtil.GetLines(tooltipData);
	end

	function TooltipUtil.ForEachLine(tooltipData, callback)
		if type(callback) ~= "function" then
			return;
		end

		local lines = TooltipUtil.GetLines(tooltipData);
		for index = 1, #lines do
			callback(lines[index], index);
		end
	end

	function TooltipUtil.FindFirstLine(tooltipData, predicate)
		if type(predicate) ~= "function" then
			return nil;
		end

		local lines = TooltipUtil.GetLines(tooltipData);
		for index = 1, #lines do
			local lineData = lines[index];
			if predicate(lineData, index) then
				return lineData, index;
			end
		end

		return nil;
	end

	function TooltipUtil.FindLinesFromData(tooltipData, predicate)
		local result = {};
		if type(predicate) ~= "function" then
			return result;
		end

		local lines = TooltipUtil.GetLines(tooltipData);
		for index = 1, #lines do
			local lineData = lines[index];
			if predicate(lineData, index) then
				result[#result + 1] = lineData;
			end
		end

		return result;
	end

	return TooltipUtil;
end);