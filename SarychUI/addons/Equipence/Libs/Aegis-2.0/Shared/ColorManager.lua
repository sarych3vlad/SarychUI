--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local _G = _G
local floor = math.floor
local format = string.format

local VERSION = 1

local function ClampByte(x)
	x = floor((x or 0) * 255 + 0.5)
	if x < 0 then
		return 0
	end
	if x > 255 then
		return 255
	end
	return x
end

local function BuildHexMarkup(r, g, b)
	return format("|cff%02x%02x%02x", ClampByte(r), ClampByte(g), ClampByte(b))
end

local function CreateSimpleColor(r, g, b)
	return {
		r = r,
		g = g,
		b = b,
		GetRGB = function(self)
			return self.r, self.g, self.b
		end,
	}
end

Aegis:RegisterNamespace("ColorManager", VERSION, function(_, _, namespace)
	local ColorManager = namespace or {};

	function ColorManager.GetColorDataForItemQuality(itemQuality)
		local colorData = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemQuality];
		if not colorData then
			return nil;
		end

		local r = colorData.r or 1
		local g = colorData.g or 1
		local b = colorData.b or 1

		return {
			r = r,
			g = g,
			b = b,
			hex = colorData.hex or BuildHexMarkup(r, g, b),
			color = colorData.color or CreateSimpleColor(r, g, b),
		};
	end

	return ColorManager;
end, { trustNative = true });