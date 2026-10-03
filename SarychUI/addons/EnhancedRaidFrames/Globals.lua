-- Enhanced Raid Frames is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- This code is licensed under the MIT license (see LICENSE for details)

-- Create a local handle to our addon table
---@type EnhancedRaidFrames
local EnhancedRaidFrames = _G.EnhancedRaidFrames

-- Import libraries
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

-- Set Classic and Classic_Era flags
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	EnhancedRaidFrames.isWoWClassicEra = true
elseif WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then
	EnhancedRaidFrames.isWoWClassic = true
end

-- Declare Color Global Constants
EnhancedRaidFrames.NORMAL_COLOR = CreateColor(1.0, 0.82, 0.0) --the default game yellow text color
EnhancedRaidFrames.WHITE_COLOR = CreateColor(1.0, 1.0, 1.0) --default game white color for text
EnhancedRaidFrames.RED_COLOR = CreateColor(0.8, 0.1, 0.1) --solid red color
EnhancedRaidFrames.YELLOW_COLOR = CreateColor(1.0, 0.82, 0.0) --solid yellow color
EnhancedRaidFrames.GREEN_COLOR = CreateColor(0.6627, 0.8235, 0.4431) --poison text color
EnhancedRaidFrames.PURPLE_COLOR = CreateColor(0.6392, 0.1882, 0.7882) --curse text color
EnhancedRaidFrames.BROWN_COLOR = CreateColor(0.7804, 0.6118, 0.4314) --disease text color
EnhancedRaidFrames.BLUE_COLOR = CreateColor(0.0, 0.4392, 0.8706) --magic text color

-- Declare Global positions table
EnhancedRaidFrames.POSITIONS = {}
EnhancedRaidFrames.POSITIONS[1] = L["Top-Left"]
EnhancedRaidFrames.POSITIONS[2] = L["Top"]
EnhancedRaidFrames.POSITIONS[3] = L["Top-Right"]
EnhancedRaidFrames.POSITIONS[4] = L["Left"]
EnhancedRaidFrames.POSITIONS[5] = L["Center"]
EnhancedRaidFrames.POSITIONS[6] = L["Right"]
EnhancedRaidFrames.POSITIONS[7] = L["Bottom-Left"]
EnhancedRaidFrames.POSITIONS[8] = L["Bottom"]
EnhancedRaidFrames.POSITIONS[9] = L["Bottom-Right"]

-- Declare Global iconCache table with pre-populated values
EnhancedRaidFrames.iconCache = {}
EnhancedRaidFrames.iconCache["poison"] = [[Interface\ICONS\Ability_creature_poison_02]]
EnhancedRaidFrames.iconCache["disease"] = [[Interface\ICONS\Ability_creature_disease_02]]
EnhancedRaidFrames.iconCache["curse"] = [[Interface\ICONS\Ability_creature_cursed_03]]
EnhancedRaidFrames.iconCache["magic"] = [[Interface\ICONS\Spell_holy_dispelmagic]]

EnhancedRaidFrames.RAID_MARKER_COORDS = {
	{0, .25, 0, .25},
	{.25, .5, 0, .25},
	{.5, .75, 0, .25},
	{.75, 1, 0, .25},
	{0, .25, .25, .5},
	{.25, .5, .25, .5},
	{.5, .75, .25, .5},
	{.75, 1, .25, .5},
}