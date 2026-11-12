local SUI = SarychUI
local extension = SUI:RegisterExtension("blizzard_improvements", {})

function SUI:IsBlizzardImprovementsEnabled()
    local modules = self.db and self.db.profile and self.db.profile.modules
    local db = modules and modules.blizzard_improvements
    return modules and not extension._runtimeDisabled and (not db or db.enabled ~= false)
end

local features = {
    "BlizzMove", "EasyItemDestroy", "BadgeStackBuyer", "EscToOk",
    "ShowFlightTimes", "TranslitAliases", "ClearChatSlash", "TooltipCursor",
}

function extension:Enable()
    self._runtimeDisabled = false
    self:ApplyFlashWindow()
    local tools = extension
    for _, feature in ipairs(features) do tools["Apply" .. feature](tools) end
end

function extension:Disable()
    self._runtimeDisabled = true
    self:ApplyFlashWindow(true)
    local tools = extension
    for _, feature in ipairs(features) do tools["Disable" .. feature](tools) end
end

function extension:GetOptions()
    local args = SarychUI.modules.blizzard_improvements:GetBlizzardImprovementOptions()
    args.glyphIconsBox = nil
    args.tooltipCursorBox = SarychUI.modules.blizzard_improvements:GetTooltipCursorOptions().tooltipCursorBox
    for order, key in ipairs({ "blizzMoveBox", "quickActionsBox", "interfaceBox",
        "travelBox", "chatExtraBox", "tooltipCursorBox" }) do
        args[key].order = order
        args[key].suiTwoCol = true
    end
    args.enabled = {
        type = "toggle", name = "ui.enable_a54eaf37", order = 0,
        get = function() return SUI:IsBlizzardImprovementsEnabled() end,
        set = function(_, value)
            local modules = SUI.db.profile.modules
            modules.blizzard_improvements = modules.blizzard_improvements or {}
            modules.blizzard_improvements.enabled = value and true or false
            if value then extension:Enable() else extension:Disable() end
            if SUI.OptionsCore then SUI.OptionsCore:ScheduleSmartRefresh(true) end
        end,
    }
    return { type = "group", name = "ui.blizzard_7ad4bb99", args = args,
        suiBodyDisabled = function() return not SUI:IsBlizzardImprovementsEnabled() end }
end

function extension:RefreshConfig()
    self._runtimeDisabled = false
    if SUI:IsBlizzardImprovementsEnabled() then self:Enable() else self:Disable() end
end

function extension:Initialize() self:ApplyFlashWindow(true) end
