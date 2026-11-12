local SUI = SarychUI
local function Enabled(key)
    local modules = SUI.db and SUI.db.profile and SUI.db.profile.modules
    local db = modules and modules[key]
    local owner = SUI.modules and SUI.modules[key]
    return modules and not (owner and owner._runtimeDisabled) and (not db or db.enabled ~= false)
end
function SUI:IsAnnouncementsEnabled() return Enabled("announcements") end
function SUI:IsFocusAssignmentEnabled() return Enabled("focus_assignment") end

local function Register(key, title, optionsMethod, apply)
    local extension = SUI:RegisterExtension(key, {})
    local pending
    local function Apply(forceOff)
        extension._runtimeDisabled = forceOff == true
        -- Focus attributes and bindings must be updated outside combat.
        if InCombatLockdown and InCombatLockdown() then
            if not pending then
                pending = CreateFrame("Frame")
                pending:SetScript("OnEvent", function(self)
                    self:UnregisterAllEvents()
                    apply(extension, Enabled(key))
                end)
            end
            pending:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        apply(extension, Enabled(key))
    end
    function extension:Enable() Apply() end
    function extension:RefreshConfig() Apply() end
    function extension:Disable() Apply(true) end
    function extension:GetOptions()
        local args = extension[optionsMethod](extension)
        args.enabled = {
            type = "toggle", name = "ui.enable_a54eaf37", order = 0,
            get = function() return Enabled(key) end,
            set = function(_, value)
                local modules = SUI.db.profile.modules
                modules[key] = modules[key] or {}
                modules[key].enabled = value and true or false
                Apply()
                if SUI.OptionsCore then SUI.OptionsCore:ScheduleSmartRefresh(true) end
            end,
        }
        return { type = "group", name = title, args = args,
            suiBodyDisabled = function() return not Enabled(key) end }
    end
end

Register("announcements", "ui.options_118f9a2bd1", "GetAnnouncementOptions", function(tools, enabled)
    SarychUI.modules.announcements:ApplyAltCD()
    SarychUI.modules.announcements:ApplyAltUnitBars()
    SarychUI.modules.announcements:ApplyAltAuras()
    SarychUI.modules.announcements:ApplyInterruptAnnouncement()
    SarychUI.modules.focus_assignment:ApplyFocuser()
end)

Register("focus_assignment", "ui.options_cb7cb8d637", "GetFocusAssignmentOptions", function(tools, enabled)
    if enabled then
        SarychUI.modules.focus_assignment:ApplyFocuser()
        SarychUI.modules.focus_assignment:ApplyArenaRightClickFocus()
        SarychUI.modules.focus_assignment:StartFocusScanner()
    else
        SarychUI.modules.focus_assignment:StopFocusScanner()
        SarychUI.modules.focus_assignment:DisableFocuser()
        SarychUI.modules.focus_assignment:DisableArenaRightClickFocus()
    end
end)
