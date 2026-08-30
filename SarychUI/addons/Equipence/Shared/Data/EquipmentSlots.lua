--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

-- @param data: type STRUCT_EquipmentSlotDefinition[]
Engine.Shared.Data.EquipmentSlots = {
	{ id = 1,  key = "Head",          side = "LEFT",  enchantable = true },
	{ id = 2,  key = "Neck",          side = "LEFT",  enchantable = false },
	{ id = 3,  key = "Shoulder",      side = "LEFT",  enchantable = true },
	{ id = 4,  key = "Shirt",         side = "LEFT",  enchantable = false, showItemLevel = false, countForAverage = false, trackUpdates = false },
	{ id = 5,  key = "Chest",         side = "LEFT",  enchantable = true },

	{ id = 6,  key = "Waist",         side = "RIGHT", enchantable = false, trackSocketLayout = true },
	{ id = 7,  key = "Legs",          side = "RIGHT", enchantable = true },
	{ id = 8,  key = "Feet",          side = "RIGHT", enchantable = true },

	{ id = 9,  key = "Wrist",         side = "LEFT",  enchantable = true,  trackSocketLayout = true },
	{ id = 10, key = "Hands",         side = "RIGHT", enchantable = true,  trackSocketLayout = true },
	{ id = 11, key = "Finger0",       side = "RIGHT", enchantable = false },
	{ id = 12, key = "Finger1",       side = "RIGHT", enchantable = false },
	{ id = 13, key = "Trinket0",      side = "RIGHT", enchantable = false },
	{ id = 14, key = "Trinket1",      side = "RIGHT", enchantable = false },

	{ id = 15, key = "Back",          side = "LEFT",  enchantable = true },

	{ id = 16, key = "MainHand",      side = "TOP",   align = "CENTER", growth = "UP", enchantable = true },
	{ id = 17, key = "SecondaryHand", side = "TOP",   align = "CENTER", growth = "UP", enchantable = true },
	{ id = 18, key = "Ranged",        side = "TOP",   align = "CENTER", growth = "UP", enchantable = false },

	{ id = 19, key = "Tabard",        side = "LEFT",  enchantable = false, showItemLevel = false, countForAverage = false, trackUpdates = false },
};