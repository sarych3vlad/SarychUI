--[[-------------------------------------------------------------------------
-- BlizzardFrames.lua
--
-- This file contains the definitions of the blizzard frame integration
-- options. These settings will not apply until the user interface is
-- reloaded.
--
-- Events registered:
--   * ADDON_LOADED - To watch for loading of the ArenaUI
-------------------------------------------------------------------------]]--

local _, private = ...
local addonName, addon = "SarychUIClique", private.Clique
local L = addon.L

-- Register a Blizzard frame for click-casting, with some additional protection
function addon:RegisterBlizzardFrame(frame)
    -- Stash the frame in case we later convert it
    local frameName = frame

    -- Convert a frame name to the global object
    if type(frame) == "string" then
        frameName = frame
        frame = _G[frameName]
        if not frame then
            addon:Printf("Error registering frame: %s", tostring(frameName))
            return
        end
    end

    if not frame then
        addon:Printf("Unable to register empty frame: %s", tostring(frameName))
        return
    end

    -- Never allow forbidden frames, we can't do anything with those!
    local forbidden = frame.IsForbidden and frame:IsForbidden()
    if forbidden then
        return
    end

    local buttonish = frame and frame.RegisterForClicks
    local protected = frame.IsProtected and frame:IsProtected()
    local anchorRestricted = frame.IsAnchoringRestricted and frame:IsAnchoringRestricted()

    -- A frame must be a button, and must be protected, and must not be a nameplate, anchor restricted
    local valid = buttonish and protected and (not anchorRestricted)
    if valid then
        addon:RegisterFrame(frame)
    end
end
