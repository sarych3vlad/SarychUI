--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@namespaces<shared>
Engine.Shared.Data = {};
Engine.Shared.Utils = {};

Engine.Shared.Constants = {
	MAX_SOCKETS = 3,

	EMPTY_SOCKET_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark",
	ENCHANT_FALLBACK_TEXTURE = "Interface\\Icons\\INV_Scroll_03",

	EMPTY_SOCKET_TEXTURES = {
		META = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta",
		RED = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red",
		BLUE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue",
		YELLOW = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow",
		PRISMATIC = (SarychUI_EquipencePath or "Interface\\AddOns\\Equipence\\") .. "Media\\Textures\\UI-EmptySocket-Prismatic",
	},

	ITEM_SOCKET_ATLAS = "Interface\\ItemSocketingFrame\\UI-ItemSockets",

	GEM_SOCKET_INFO = {
		META = {
			left = 0.171875, right = 0.3984375, top = 0.40234375, bottom = 0.609375,
			CBLeft = 0.5546875, CBRight = 0.7578125, CBTop = 0, CBBottom = 0.20703125,
			OBLeft = 0.7578125, OBRight = 0.9921875, OBTop = 0, OBBottom = 0.22265625,
			desaturateBrackets = true,
		},
		RED = {
			left = 0.1796875, right = 0.34375, top = 0.640625, bottom = 0.80859375,
			CBLeft = 0.5546875, CBRight = 0.7578125, CBTop = 0.4765625, CBBottom = 0.68359375,
			OBLeft = 0.7578125, OBRight = 0.9921875, OBTop = 0.4765625, OBBottom = 0.69921875,
			desaturateBrackets = false,
		},
		BLUE = {
			left = 0.3515625, right = 0.51953125, top = 0.640625, bottom = 0.80859375,
			CBLeft = 0.5546875, CBRight = 0.7578125, CBTop = 0.23828125, CBBottom = 0.4453125,
			OBLeft = 0.7578125, OBRight = 0.9921875, OBTop = 0.23828125, OBBottom = 0.4609375,
			desaturateBrackets = false,
		},
		YELLOW = {
			left = 0, right = 0.16796875, top = 0.640625, bottom = 0.80859375,
			CBLeft = 0.5546875, CBRight = 0.7578125, CBTop = 0, CBRight = 0.7578125, CBBottom = 0.20703125,
			OBLeft = 0.7578125, OBRight = 0.9921875, OBTop = 0, OBBottom = 0.22265625,
			desaturateBrackets = false,
		},
		PRISMATIC = {
			left = 0.171875, right = 0.3984375, top = 0.40234375, bottom = 0.609375,
			CBLeft = 0.5546875, CBRight = 0.7578125, CBTop = 0, CBBottom = 0.20703125,
			OBLeft = 0.7578125, OBRight = 0.9921875, OBTop = 0, OBBottom = 0.22265625,
			desaturateBrackets = false,
		},
	},
};
