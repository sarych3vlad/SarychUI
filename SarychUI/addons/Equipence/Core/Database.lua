--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@natives<lua>
local pairs = pairs;
local type = type;

local DB_NAME = Engine.Name .. "DB";

local DEFAULTS = {
	showGems = true,
	showEnchants = true,
	showItemLevel = true,
	itemLevelDisplayScope = "BOTH",
	showAverageItemLevel = true,
	averageItemLevelDisplayScope = "BOTH",
	averageItemLevelUseDecimals = true,
	showAverageItemLevelLabel = true,
	colorAverageItemLevel = false,
	averageItemLevelPosition = "BOTTOM",

	showMissingEnchants = true,
	showEmptySockets = true,

	animateGemsShine = true,
	shineSize = 8,
	shineSpeed = 1.0,

	useRoundedIcons = false,
	showIconTooltips = true,
	disableIconHover = false,

	socketIconSize = 24,
	enchantIconSize = 24,
	inlineIconGap = 3,

	showQualityBorder = true,
	colorItemQuality = true,

	layoutOffsets = {
		LEFT = { x = 33, y = -8 },
		RIGHT = { x = -33, y = -8 },
		BOTTOM = { x = 0, y = -4 },
		TOP = { x = 0, y = 38 },
	},

	hideCharacterAttributes = false,
	fadeCharacterAttributes = true,
	characterAttributesFadedAlpha = 0.010,
	characterAttributesFadeDuration = 0.15,

	showAmmoSlot = false,

	useModelCentering = true,
	paperDollModelLayout = {
		width = 231,
		height = 320,
		positionX = 0.25,
		positionY = 0,
		positionZ = 0,
	},

};

local function ResolveTable(tbl)
	if (type(tbl) ~= "table") then
		tbl = {};
		_G[DB_NAME] = tbl;
	end

	return tbl;
end

local function CopyDefaults(dst, src)
	for key, value in pairs(src) do
		if (type(value) == "table") then
			if (type(dst[key]) ~= "table") then
				dst[key] = {};
			end

			CopyDefaults(dst[key], value);
		elseif dst[key] == nil then
			dst[key] = value;
		end
	end
end


Engine.Database = Engine.Database or {};
Engine.Database.Defaults = DEFAULTS;

function Engine.Database:Init()
	local data = _G[DB_NAME];

	data = ResolveTable(data);
	CopyDefaults(data, DEFAULTS);

	self.name = DB_NAME;
	self.data = data;

	Engine.Settings = data;
end
