--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local _G = _G
local GetLocale = GetLocale

local VERSION = 1

Aegis:RegisterNamespace("GlobalStrings", VERSION, function(core, _, namespace)
	local Strings = namespace or {}
	local locale = GetLocale() or "enUS"
	local langData = core.data.LocalizationFallbacks or {}

	local meta = {
		__index = function(_, key)
			local nativeValue = _G[key]
			if nativeValue ~= nil then
				return nativeValue
			end

			local localized = langData[key]
			if localized then
				return localized[locale] or localized.enUS
			end

			return nil
		end,
	}

	setmetatable(Strings, meta)

	function Strings:Get(key)
		return self[key]
	end

	function Strings:Has(key)
		return self[key] ~= nil
	end

	return Strings
end)
