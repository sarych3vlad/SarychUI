local SUI = SarychUI
local modern = SUI:RegisterExtension("modern_features", {})
local modernAddons = { "BNetToast", "LevelUpDisplay", "Cheese" }
local testActive = {}

local function RefreshTestButtons()
    if SUI.NotifySarychUIOptionsChange then SUI:NotifySarychUIOptionsChange() end
end

local function TrackTestFrame(key, frame)
    if not frame or frame._suiModernTestTracked then return end
    frame._suiModernTestTracked = true
    frame:HookScript("OnHide", function()
        if testActive[key] then
            testActive[key] = nil
            RefreshTestButtons()
        end
    end)
end

local function ModernDB()
    local modules = SUI.db.profile.modules
    modules.modern_features = modules.modern_features or {}
    return modules.modern_features
end

function modern:GetOptions()
    local function IsEnabled()
        return ModernDB().enabled ~= false
    end
    local args = {
        enabled = {
            type = "toggle", name = "ui.enable_a54eaf37", order = 0,
            get = IsEnabled,
            set = function(_, value)
                local db = ModernDB()
                if value == IsEnabled() then return end
                db.enabled = value and true or false
                if value then modern:Enable() else modern:Disable() end
                if SarychUI.modules.modern_features.ApplyQuestTrackerStyle then
                    SarychUI.modules.modern_features:ApplyQuestTrackerStyle()
                end
                if SUI.OptionsCore then SUI.OptionsCore:ScheduleSmartRefresh(true) end
            end,
        },
    }
    local entries = {
        { "BNetToast", SarychUI:T("ui.options_c90d5279c2") },
        { "LevelUpDisplay", SarychUI:T("ui.options_eb72c9bc90") },
        { "Cheese", SarychUI:T("ui.options_f0b5055d1a") },
    }
    for order, entry in ipairs(entries) do
        local key, title = entry[1], entry[2]
        local available = modern["Apply" .. key]
        if available then
            local source = modern["Get" .. key .. "Options"](modern).args
            local enabled = source.enabled
            enabled.width, enabled.desc = "normal", nil
            local originalSet = enabled.set
            enabled.set = function(info, value)
                originalSet(info, value)
                if SUI.OptionsCore then SUI.OptionsCore:ScheduleSmartRefresh(true) end
            end
            local controls = { enabled = enabled }
            if key == "BNetToast" then
                TrackTestFrame(key, BNToastFrame)
                controls.test = {
                    type = "execute", order = 1.1,
                    name = function() return testActive[key] and SarychUI:T("ui.options_2aa205e3d3") or SarychUI:T("ui.options_ec1868c5a7") end,
                    hidden = function() return not modern["Is" .. key .. "Enabled"](modern) end,
                    func = function()
                        if not modern["Is" .. key .. "Enabled"](modern) then return end
                        local name = UnitName("player") or SarychUI:T("ui.options_97fb0d0928")
                        if testActive[key] and BNToastFrame then
                            testActive[key] = nil
                            if BNToastFrame_RemoveToast then
                                BNToastFrame_RemoveToast("SarychUI_FriendOnline", name)
                            end
                            BNToastFrame:Hide()
                        elseif BNToastFrame_AddToast then
                            -- Character names use our private renderer, not native presence IDs.
                            BNToastFrame_AddToast("SarychUI_FriendOnline", name)
                            -- Blizzard can queue the toast before its frame becomes visible.
                            -- The button state follows the click, not the frame's visibility now.
                            testActive[key] = true
                            TrackTestFrame(key, BNToastFrame)
                        end
                        RefreshTestButtons()
                    end,
                }
            elseif key == "LevelUpDisplay" then
                TrackTestFrame(key, LevelUpDisplay)
                controls.test = {
                    type = "execute", order = 1.1,
                    name = function() return testActive[key] and SarychUI:T("ui.options_2aa205e3d3") or SarychUI:T("ui.options_ec1868c5a7") end,
                    hidden = function() return not modern["Is" .. key .. "Enabled"](modern) end,
                    func = function()
                        if not modern["Is" .. key .. "Enabled"](modern) then return end
                        if testActive[key] and LevelUpDisplay then
                            testActive[key] = nil
                            LevelUpDisplay:Hide()
                            if LevelUpDisplaySide then LevelUpDisplaySide:Hide() end
                        elseif LevelUpDisplay_Test then
                            LevelUpDisplay_Test()
                            testActive[key] = LevelUpDisplay and LevelUpDisplay:IsShown() or false
                        end
                        RefreshTestButtons()
                    end,
                }
            elseif key == "Cheese" then
                controls.showSpellAlerts = source.showSpellAlerts
                controls.spellAlertOpacity = source.spellAlertOpacity
                enabled.suiFullRow = true
            end
            args[key] = { type = "group", name = title, order = order,
                inline = true, suiTwoCol = true, args = controls }
        end
    end
    args.questTracker = SarychUI.modules.modern_features:GetQuestTrackerOptions()
    args.questTracker.order = #entries + 1
    return { type = "group", name = "ui.text_16bc7fbe", args = args,
        suiBodyDisabled = function() return not IsEnabled() end }
end

function modern:RefreshConfig()
    self:ApplyQuestTrackerStyle()
    self:ApplyBNetToast()
    self:ApplyLevelUpDisplay()
    self:ApplyCheese()
end
function modern:Enable() self:RefreshConfig() end
function modern:Disable()
    self:RestoreQuestTrackerClassic()
    self:ApplyBNetToast(true)
    self:ApplyLevelUpDisplay(true)
    self:ApplyCheese(true)
end

function modern:Initialize()
    local parent = SUI.db.profile.modules.modern_features
    if parent and parent.enabled == false and parent.savedEnabled then
        for _, child in ipairs({"BNetToast","LevelUpDisplay","Cheese"}) do
            if parent.savedEnabled[child] ~= nil then
                SUI.db.profile.addons[child].enabled = parent.savedEnabled[child]
                parent.savedEnabled[child] = nil
            end
        end
    end

    self:ApplyBNetToast(true)
    self:ApplyLevelUpDisplay(true)
    self:ApplyCheese(true)
end
