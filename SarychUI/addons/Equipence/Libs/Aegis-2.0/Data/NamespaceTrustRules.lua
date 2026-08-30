--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

Aegis.data = Aegis.data or {};
Aegis.data.NamespaceTrustRules = Aegis.data.NamespaceTrustRules or {
	-- shorthand array form = required methods
	C_AddOns = {
		"GetNumAddOns",
		"GetAddOnInfo",
		"GetAddOnMetadata",
		"LoadAddOn",
	},

	C_Item = {
		"GetItemInfo",
		"GetItemInfoInstant",
		"DoesItemExistByID",
		"IsItemDataCachedByID",
	},

	C_Spell = {
		"GetSpellInfo",
		"GetSpellName",
		"GetSpellTexture",
	},

	C_TooltipInfo = {
		"GetInventoryItem",
		"GetHyperlink",
	},

	C_Texture = {
		"GetAtlasInfo",
	},

	ColorManager = {
		"GetColorDataForItemQuality",
	},

	Enum = function(namespace)
		return type(namespace) == "table"
			and type(namespace.ItemSocketType) == "table"
			and type(namespace.ItemGemColor) == "table"
			and type(namespace.ItemGemSubclass) == "table"
	end,

	-- custom validation functions for object APIs
	Item = function(namespace)
		return type(namespace) == "table"
			and type(namespace.CreateFromItemID) == "function"
			and type(_G.ItemMixin) == "table"
	end,

	ItemLocation = function(namespace)
		return type(namespace) == "table"
			and type(namespace.CreateFromBagAndSlot) == "function"
			and type(_G.ItemLocationMixin) == "table"
	end,
};
