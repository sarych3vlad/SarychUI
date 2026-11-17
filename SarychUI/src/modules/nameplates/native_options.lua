-- Native CVars are the source of truth for both nameplate renderers.
local module = SarychUI.modules.health_indicators
local controls = {
    {"overlap", "nameplateAllowOverlap", "AllowOverlap", "UNIT_NAMEPLATES_ALLOW_OVERLAP", "ui.nameplates.allow_overlap"},
    {"friends", "nameplateShowFriends", "Friends", "UNIT_NAMEPLATES_SHOW_FRIENDS", "ui.nameplates.show_friends"},
    {"enemies", "nameplateShowEnemies", "Enemies", "UNIT_NAMEPLATES_SHOW_ENEMIES", "ui.nameplates.show_enemies"},
    {"friendlyPets", "nameplateShowFriendlyPets", "FriendlyPets", "UNIT_NAMEPLATES_SHOW_FRIENDLY_PETS", "ui.pets_61161ec5", "nameplateShowFriends"},
    {"enemyPets", "nameplateShowEnemyPets", "EnemyPets", "UNIT_NAMEPLATES_SHOW_ENEMY_PETS", "ui.pets_61161ec5", "nameplateShowEnemies"},
    {"friendlyGuardians", "nameplateShowFriendlyGuardians", "FriendlyGuardians", "UNIT_NAMEPLATES_SHOW_FRIENDLY_GUARDIANS", "ui.nameplates.guardians", "nameplateShowFriends"},
    {"enemyGuardians", "nameplateShowEnemyGuardians", "EnemyGuardians", "UNIT_NAMEPLATES_SHOW_ENEMY_GUARDIANS", "ui.nameplates.guardians", "nameplateShowEnemies"},
    {"friendlyTotems", "nameplateShowFriendlyTotems", "FriendlyTotems", "UNIT_NAMEPLATES_SHOW_FRIENDLY_TOTEMS", "ui.nameplates.totems", "nameplateShowFriends"},
    {"enemyTotems", "nameplateShowEnemyTotems", "EnemyTotems", "UNIT_NAMEPLATES_SHOW_ENEMY_TOTEMS", "ui.nameplates.totems", "nameplateShowEnemies"},
}
local events = {}
for _, entry in ipairs(controls) do
    events[entry[2]:lower()] = true
    events[entry[4]:lower()] = true
end
local watcher, hooked, updating

local function Enabled(cvar) return GetCVar(cvar) == "1" end

local function SyncControls()
    for _, entry in ipairs(controls) do
        local control = _G["InterfaceOptionsNamesPanelUnitNameplates" .. entry[3]]
        if control then
            local enabled = Enabled(entry[2])
            control.value = enabled and "1" or "0"
            control:SetChecked(enabled)
            -- Keep oldValue: the native window owns its Cancel snapshot.
            if entry[6] then
                if Enabled(entry[6]) then control:Enable() else control:Disable() end
            end
        end
    end
    local pack = _G.SarychUI_ElvUI_NamePlates
    local E = pack and pack[1]
    local np = E and E:GetModule("NamePlates", true)
    local motion = Enabled("nameplateAllowOverlap") and "OVERLAP" or "STACKED"
    if E and E.db and E.db.nameplates then E.db.nameplates.motionType = motion end
    if np and np.db then np.db.motionType = motion end
end

local function Notify()
    if SarychUI.NotifySarychUIOptionsChange then SarychUI:NotifySarychUIOptionsChange() end
end

local function OnCVar(name)
    if not updating and events[tostring(name):lower()] then SyncControls(); Notify() end
end

function module:InitializeNativeNameplateOptions()
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:RegisterEvent("CVAR_UPDATE")
        watcher:SetScript("OnEvent", function(_, _, name) OnCVar(name) end)
    end
    if not hooked and hooksecurefunc and SetCVar then
        hooksecurefunc("SetCVar", OnCVar)
        hooked = true
    end
    SyncControls()
end

local function Option(entry, order)
    local cvar, event, parent = entry[2], entry[4], entry[6]
    return {
        type="toggle", name=entry[5], order=order,
        suiIndent=parent and 16 or nil,
        suiFullRow=order == 1 or nil, suiSpanTwoCols=order == 1 or nil,
        width=order == 1 and "full" or nil,
        disabled=function() return parent and not Enabled(parent) or false end,
        get=function() return Enabled(cvar) end,
        set=function(_, value)
            if parent and not Enabled(parent) then return end
            updating = true
            SetCVar(cvar, value and "1" or "0", event)
            updating = false
            SyncControls(); Notify()
        end,
    }
end

function module:GetNativeNameplateOptions()
    self:InitializeNativeNameplateOptions()
    local args = {}
    for order, entry in ipairs(controls) do args[entry[1]] = Option(entry, order) end
    return {type="group", name="ui.nameplates.native_settings", order=3,
        inline=true, suiTwoCol=true, args=args}
end
