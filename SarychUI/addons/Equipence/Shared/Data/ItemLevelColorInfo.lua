--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

-- Broad display bands for average item level text. The feature stays disabled
-- by default because exact progression ranges differ between branches.
Engine.Shared.Data.ItemLevelColorInfo = {
	{ minLevel = 0,   maxLevel = 99,  quality = 1 },
	{ minLevel = 100, maxLevel = 149, quality = 1 },
	{ minLevel = 150, maxLevel = 185, quality = 2 },
	{ minLevel = 186, maxLevel = 200, quality = 3 },
	{ minLevel = 201, maxLevel = 277, quality = 4 },
	{ minLevel = 278, maxLevel = 296, quality = 5 },
	{ minLevel = 297,                 quality = 6 },
};
