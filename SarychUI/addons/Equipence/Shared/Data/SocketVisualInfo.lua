--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

Engine.Shared.Data.SocketVisualInfo = {
	META = { textureKit = "meta", r = 1, g = 1, b = 1, desaturateBrackets = true },
	RED = { textureKit = "red", r = 1, g = 0.47, b = 0.47 },
	YELLOW = { textureKit = "yellow", r = 0.97, g = 0.82, b = 0.29 },
	BLUE = { textureKit = "blue", r = 0.47, g = 0.67, b = 1 },
	PRISMATIC = { textureKit = "prismatic", r = 1, g = 1, b = 1 },

	HYDRAULIC = { textureKit = "hydraulic", r = 1, g = 1, b = 1, legacySocketType = "PRISMATIC" },
	COGWHEEL = { textureKit = "cogwheel", r = 1, g = 1, b = 1, legacySocketType = "PRISMATIC" },
	IRON = { r = 1, g = 1, b = 1, legacySocketType = "PRISMATIC" },
	BLOOD = { r = 1, g = 0.47, b = 0.47, legacySocketType = "RED" },
	SHADOW = { r = 0.47, g = 0.67, b = 1, legacySocketType = "BLUE" },
	FEL = { r = 0.47, g = 1, b = 0.47, legacySocketType = "YELLOW" },
	ARCANE = { r = 1, g = 1, b = 1, legacySocketType = "PRISMATIC" },
	FROST = { r = 0.47, g = 0.67, b = 1, legacySocketType = "BLUE" },
	FIRE = { r = 1, g = 0.47, b = 0.47, legacySocketType = "RED" },
	WATER = { r = 0.47, g = 0.67, b = 1, legacySocketType = "BLUE" },
	LIFE = { r = 0.47, g = 1, b = 0.47, legacySocketType = "YELLOW" },
	WIND = { r = 0.97, g = 0.82, b = 0.29, legacySocketType = "YELLOW" },
	HOLY = { r = 0.97, g = 0.82, b = 0.29, legacySocketType = "YELLOW" },

	PUNCHCARDRED = { textureKit = "punchcard-red", r = 1, g = 0.47, b = 0.47, legacySocketType = "RED" },
	PUNCHCARDYELLOW = { textureKit = "punchcard-yellow", r = 0.97, g = 0.82, b = 0.29, legacySocketType = "YELLOW" },
	PUNCHCARDBLUE = { textureKit = "punchcard-blue", r = 0.47, g = 0.67, b = 1, legacySocketType = "BLUE" },
	DOMINATION = { textureKit = "domination", r = 1, g = 1, b = 1, legacySocketType = "PRISMATIC" },
	CYPHER = { textureKit = "meta", r = 1, g = 1, b = 1, legacySocketType = "META" },
	TINKER = { textureKit = "punchcard-red", r = 1, g = 0.47, b = 0.47, legacySocketType = "RED" },
	PRIMORDIAL = { textureKit = "meta", r = 1, g = 1, b = 1, legacySocketType = "META" },
	FRAGRANCE = { textureKit = "hydraulic", r = 1, g = 1, b = 1, legacySocketType = "PRISMATIC" },
	SINGINGTHUNDER = { textureKit = "yellow", r = 0.97, g = 0.82, b = 0.29, legacySocketType = "YELLOW" },
	SINGINGSEA = { textureKit = "blue", r = 0.47, g = 0.67, b = 1, legacySocketType = "BLUE" },
	SINGINGWIND = { textureKit = "red", r = 1, g = 0.47, b = 0.47, legacySocketType = "RED" },
	FIBER = { textureKit = "hydraulic", r = 1, g = 1, b = 1, legacySocketType = "PRISMATIC" },
};
