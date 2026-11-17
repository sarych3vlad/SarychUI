-- Native account/character settings, shared by every action-bar style.
-- Keep no profile copy: FrameXML globals and CVars own these values.
local module = SarychUI.modules.mainmenubar
local watcher
local hooked = {}
local updating = false
local bars = {"BottomLeft", "BottomRight", "Right", "RightTwo"}
local cvars = {
    lockActionBars = {control="LockActionBars", event="LOCK_ACTIONBAR_TEXT", global="LOCK_ACTIONBAR"},
    alwaysShowActionBars = {control="AlwaysShowActionBars", event="ALWAYS_SHOW_MULTIBARS_TEXT", global="ALWAYS_SHOW_MULTIBARS"},
    secureAbilityToggle = {control="SecureAbilityToggle", event="SECURE_ABILITY_TOGGLE"},
}
local cvarEvents = {}
for name, data in pairs(cvars) do
    cvarEvents[name:lower()] = name
    cvarEvents[data.event:lower()] = name
end

local function IsOn(value)
    return value == true or value == 1 or value == "1"
end

local function BarEnabled(index)
    return IsOn(_G["SHOW_MULTI_ACTIONBAR_" .. index])
end

local function Notify()
    if SarychUI.NotifySarychUIOptionsChange then SarychUI:NotifySarychUIOptionsChange() end
end

local function SyncControl(suffix, enabled)
    local control = _G["InterfaceOptionsActionBarsPanel" .. suffix]
    if not control then return end
    -- Native non-CVar controls cache .value even after closing the window.
    -- Do not change oldValue: the original window still owns its Cancel snapshot.
    control.value = enabled and "1" or "0"
    control:SetChecked(enabled)
end

local function SyncControls()
    for index, suffix in ipairs(bars) do SyncControl(suffix, BarEnabled(index)) end
    for name, data in pairs(cvars) do
        local enabled = GetCVar(name) == "1"
        -- Native drag handlers compare LOCK_ACTIONBAR to the string "1".
        if data.global then _G[data.global] = enabled and "1" or nil end
        SyncControl(data.control, enabled)
    end
    local dependent = _G.InterfaceOptionsActionBarsPanelRightTwo
    if dependent then
        if BarEnabled(3) then dependent:Enable() else dependent:Disable() end
    end
end

local function UpdateGridReference(enabled, previous)
    if enabled == previous then return end
    -- FrameXML only changes showgrid from secure code. Our options callback is
    -- addon code, so maintain this setting's one reference before refreshing.
    -- Keep other references (e.g. dragging a spell) and never touch main/pet bars.
    for _, prefix in ipairs({"MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft"}) do
        for i = 1, (NUM_MULTIBAR_BUTTONS or 12) do
            local button = _G[prefix .. "Button" .. i]
            if button then
                local count = button:GetAttribute("showgrid") or 0
                button:SetAttribute("showgrid", math.max(0, count + (enabled and 1 or -1)))
            end
        end
    end
end

local function RefreshNativeLayout(grid)
    if grid and MultiActionBar_UpdateGridVisibility then MultiActionBar_UpdateGridVisibility() end
    if InterfaceOptions_UpdateMultiActionBars then
        InterfaceOptions_UpdateMultiActionBars()
    else
        SetActionBarToggles(SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2,
            SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4, ALWAYS_SHOW_MULTIBARS)
        if MultiActionBar_Update then MultiActionBar_Update() end
        if UIParent_ManageFramePositions then UIParent_ManageFramePositions() end
    end
end

local function EnsureWatcher()
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:RegisterEvent("CVAR_UPDATE")
        watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        watcher:SetScript("OnEvent", function(_, event, name)
            if event ~= "CVAR_UPDATE" or cvarEvents[tostring(name):lower()] then
                if not updating then SyncControls(); Notify() end
            end
        end)
    end
    if not hooked.toggles and SetActionBarToggles and hooksecurefunc then
        hooksecurefunc("SetActionBarToggles", function(a, b, c, d)
            SHOW_MULTI_ACTIONBAR_1 = IsOn(a) and 1 or nil
            SHOW_MULTI_ACTIONBAR_2 = IsOn(b) and 1 or nil
            SHOW_MULTI_ACTIONBAR_3 = IsOn(c) and 1 or nil
            SHOW_MULTI_ACTIONBAR_4 = IsOn(d) and 1 or nil
            if not updating then SyncControls(); Notify() end
        end)
        hooked.toggles = true
    end
    if not hooked.cvar and SetCVar and hooksecurefunc then
        hooksecurefunc("SetCVar", function(name)
            if cvarEvents[tostring(name):lower()] and not updating then SyncControls(); Notify() end
        end)
        hooked.cvar = true
    end
end

local function Locked()
    return InCombatLockdown and InCombatLockdown()
end

local function BarOption(index, key, order)
    return {
        type="toggle", name=key, order=order,
        suiIndent=index == 4 and 16 or nil,
        disabled=function() return Locked() or (index == 4 and not BarEnabled(3)) end,
        get=function() return BarEnabled(index) end,
        set=function(_, value)
            if Locked() or (index == 4 and not BarEnabled(3)) then return end
            updating = true
            _G["SHOW_MULTI_ACTIONBAR_" .. index] = value and 1 or nil
            SyncControls()
            RefreshNativeLayout()
            updating = false
            SyncControls(); Notify()
        end,
    }
end

local function CVarOption(cvar, key, order)
    return {
        type="toggle", name=key, order=order, disabled=Locked,
        get=function() return GetCVar(cvar) == "1" end,
        set=function(_, value)
            if Locked() then return end
            local previous = GetCVar(cvar) == "1"
            updating = true
            SetCVar(cvar, value and "1" or "0", cvars[cvar].event)
            SyncControls()
            if cvar == "alwaysShowActionBars" then UpdateGridReference(value, previous) end
            if cvar ~= "secureAbilityToggle" then RefreshNativeLayout(cvar == "alwaysShowActionBars") end
            updating = false
            Notify()
        end,
    }
end

function module:GetNativeActionBarOptions()
    EnsureWatcher()
    return {
        type="group", name="ui.action_bars.native_settings", order=20,
        inline=true, suiTwoCol=true,
        args={
            bottomLeft=BarOption(1, "ui.action_bars.bottom_left", 1),
            lockBars=CVarOption("lockActionBars", "ui.action_bars.lock", 2),
            bottomRight=BarOption(2, "ui.action_bars.bottom_right", 3),
            alwaysShow=CVarOption("alwaysShowActionBars", "ui.action_bars.always_show", 4),
            right=BarOption(3, "ui.action_bars.right", 5),
            secureToggle=CVarOption("secureAbilityToggle", "ui.action_bars.secure_toggle", 6),
            rightTwo=BarOption(4, "ui.action_bars.right_two", 7),
        },
    }
end
