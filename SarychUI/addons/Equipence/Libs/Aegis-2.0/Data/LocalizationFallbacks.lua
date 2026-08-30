--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

Aegis.data = Aegis.data or {};
Aegis.data.LocalizationFallbacks = Aegis.data.LocalizationFallbacks or {};

local Strings = Aegis.data.LocalizationFallbacks

Strings.ENCHANTED_TOOLTIP_LINE = {
	enUS = "Enchanted: %s",
	ruRU = "Наложено чар: %s",
};

-- Strings.EMPTY_SOCKET_PRISMATIC = {
	-- enUS = "Prismatic Socket",
	-- ruRU = "Prismatic Socket",
-- };
-- EMPTY_SOCKET_NO_COLOR

-- Add more fallback strings here when needed.