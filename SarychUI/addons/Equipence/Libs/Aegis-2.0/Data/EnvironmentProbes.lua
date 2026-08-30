--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

Aegis.data = Aegis.data or {};
Aegis.data.EnvironmentProbes = Aegis.data.EnvironmentProbes or {
	-- Unknown/suspicious environment fallback probes.
	-- These are NOT used for known branches like 30300 / mainline / classic.
	-- They are only used when tocVersion did not classify the client cleanly.

	modern = {
		{
			name = "C_Item",
			globalName = "C_Item",
			requiredMethods = {
				"GetItemInfo",
				"GetItemInfoInstant",
				"DoesItemExistByID",
				"IsItemDataCachedByID",
			},
		},
		{
			name = "C_TooltipInfo",
			globalName = "C_TooltipInfo",
			requiredMethods = {
				"GetInventoryItem",
			},
		},
		{
			name = "C_Spell",
			globalName = "C_Spell",
			requiredMethods = {
				"GetSpellInfo",
				"GetSpellName",
			},
		},
		{
			name = "C_Texture",
			globalName = "C_Texture",
			requiredMethods = {
				"GetAtlasInfo",
			},
		},
	},

	-- Require at least 2 strong probes before classifying an unknown client
	-- as modern/mainline-like.
	modernThreshold = 2,
};