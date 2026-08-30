--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0")

Aegis.data = Aegis.data or {}
Aegis.data.CommonAtlasData = Aegis.data.CommonAtlasData or {}

local AtlasData = Aegis.data.CommonAtlasData

-- Format:
-- ["atlas-name"] = { width, height, left, right, top, bottom, tileH, tileV, folder, file }

AtlasData["Aegis-minimal-scrollbar-arrow-bottom"] = { 17, 11, 31/128, 48/128, 52/64, 63/64, false, false, "Buttons", "MinimalScrollbarProportional" }
AtlasData["Aegis-minimal-scrollbar-arrow-top"] = { 17, 11, 88/128, 105/128, 1/64, 12/64, false, false, "Buttons", "MinimalScrollbarProportional" }


-- AtlasData["Aegis-test-custom-atlas"] = { 26, 33, 0.015625, 0.421875, 0.015625, 0.53125, false, false, "Navigation", "IngameNavigationUI" }

-- Add only shared/common atlases here.
-- Addon-specific atlases should be registered by the addon itself.