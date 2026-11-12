--[[-------------------------------------------------------------------------
-- AddonCore.lua
--
-- This is a very simple, bare-minimum core for addon development. It provide
-- methods to register events, call initialization functions, and sets up the
-- localization table so it can be used elsewhere. This file is designed to be
-- loaded first, as it has no further dependencies.
--
-- Lifecycle is owned by SarychUI; this core only dispatches events/messages.
-------------------------------------------------------------------------]]--

local _, private = ...
private.Clique = {}
local addonName, addon = "SarychUIClique", private.Clique

-- Set global name of addon
_G[addonName] = addon

addon.version = "1.7-sui"

--[[-------------------------------------------------------------------------
--  Debug support
-------------------------------------------------------------------------]]--

local EMERGENCY_DEBUG = false
if EMERGENCY_DEBUG then
    local private = {}
    for k,v in pairs(addon) do
        rawset(private, k, v)
        rawset(addon, k, nil)
    end

    setmetatable(addon, {
        __index = function(t, k)
            local value = rawget(private, k)
            if type(value) == "function" then
                print("CALL", addonName .. "." .. tostring(k))
            end
            return value
        end,
        __newindex = function(t, k, v)
            print(addonName, "NEWINDEX", k, v)
            rawset(private, k, v)
        end,
    })
end

--[[-------------------------------------------------------------------------
--  Print/Printf support
-------------------------------------------------------------------------]]--

local printHeader = "|cFF33FF99%s|r: "

function addon:Printf(msg, ...)
    msg = printHeader .. msg
    local success, txt = pcall(string.format, msg, addonName, ...)
    if success then
        print(txt)
    else
        error(string.gsub(txt, "'%?'", string.format("'%s'", "Printf")), 3)
    end
end

--[[-------------------------------------------------------------------------
--  Event registration and dispatch
-------------------------------------------------------------------------]]--

addon.eventFrame = CreateFrame("Frame", addonName .. "EventFrame", UIParent)
local eventMap = {}

function addon:RegisterEvent(event, handler)
    assert(eventMap[event] == nil, "Attempt to re-register event: " .. tostring(event))
    eventMap[event] = handler and handler or event
    addon.eventFrame:RegisterEvent(event)
end

function addon:UnregisterEvent(event)
    assert(type(event) == "string", "Invalid argument to 'UnregisterEvent'")
    eventMap[event] = nil
    addon.eventFrame:UnregisterEvent(event)
end

addon.eventFrame:SetScript("OnEvent", function(frame, event, ...)
    local handler = eventMap[event]
    local handler_t = type(handler)
    if handler_t == "function" then
        handler(event, ...)
    elseif handler_t == "string" and addon[handler] then
        addon[handler](addon, event, ...)
    end
end)

--[[-------------------------------------------------------------------------
--  Message support
-------------------------------------------------------------------------]]--

local messageMap = {}

function addon:RegisterMessage(name, handler)
    assert(messageMap[name] == nil, "Attempt to re-register message: " .. tostring(name))
    messageMap[name] = handler and handler or name
end

function addon:UnregisterMessage(name)
    assert(type(name) == "string", "Invalid argument to 'UnregisterMessage'")
    messageMap[name] = nil
end

function addon:FireMessage(name, ...)
    assert(type(name) == "string", "Invalid argument to 'FireMessage'")
    local handler = messageMap[name]
    local handler_t = type(handler)
    if handler_t == "function" then
        handler(name, ...)
    elseif handler_t == "string" and addon[handler] then
        addon[handler](addon, name, ...)
    end
end

--[[-------------------------------------------------------------------------
--  Setup Initialize/Enable support
-------------------------------------------------------------------------]]--

-- Initialization is owned by the SarychUI addon registry.

--[[-------------------------------------------------------------------------
--  Support for deferred execution (when in-combat)
-------------------------------------------------------------------------]]--

local deferframe = CreateFrame("Frame")
deferframe.queue = {}

local function runDeferred(thing)
    local thing_t = type(thing)
    if thing_t == "string" and addon[thing] then
        addon[thing](addon)
    elseif thing_t == "function" then
        thing(addon)
    end
end

-- This method will defer the execution of a method or function until the
-- player has exited combat. If they are already out of combat, it will
-- execute the function immediately.
function addon:Defer(...)
    for i = 1, select("#", ...) do
        local thing = select(i, ...)
        local thing_t = type(thing)
        if thing_t == "string" or thing_t == "function" then
            if InCombatLockdown() then
                deferframe.queue[#deferframe.queue + 1] = select(i, ...)
            else
                runDeferred(thing)
            end
        else
            error("Invalid object passed to 'Defer'")
        end
    end
end

deferframe:RegisterEvent("PLAYER_REGEN_ENABLED")
deferframe:SetScript("OnEvent", function(self, event, ...)
    for idx, thing in ipairs(deferframe.queue) do
        runDeferred(thing)
    end
    table.wipe(deferframe.queue)
end)

--[[-------------------------------------------------------------------------
--  Localization
-------------------------------------------------------------------------]]--

addon.L = addon.L or setmetatable({}, {
    __index = function(t, k)
        rawset(t, k, k)
        return k
    end,
    __newindex = function(t, k, v)
        if v == true then
            rawset(t, k, k)
        else
            rawset(t, k, v)
        end
    end,
})

function addon:RegisterLocale(locale, tbl)
    if locale == "enUS" or locale == GetLocale() then
        for k,v in pairs(tbl) do
            if v == true then
                self.L[k] = k
            elseif type(v) == "string" then
                self.L[k] = v
            else
                self.L[k] = k
            end
        end
    end
end
