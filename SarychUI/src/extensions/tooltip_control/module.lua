local SUI = SarychUI
local module = SUI:RegisterExtension("tooltip_control", { _runtimeDisabled = true })

function module:GetDB()
    local profile = SUI.db.profile
    profile.modules = profile.modules or {}
    local modules = profile.modules
    modules.tooltip_control = modules.tooltip_control or { enabled = true }
    local db = modules.tooltip_control
    if not db.settingsMigrated then
        local tools = modules.tools or {}
        local ids = profile.addons and profile.addons.IdTip or {}
        local oldOwner = modules.id_detection or {}
        local blizzard = modules.blizzard_improvements or {}
        if db.enableTooltipCursor == nil then
            if blizzard.enabled == false then db.enableTooltipCursor = 0
            elseif tools.enableTooltipCursor ~= nil then db.enableTooltipCursor = tools.enableTooltipCursor
            else db.enableTooltipCursor = 1 end
        end
        if db.tooltipMode == nil then db.tooltipMode = tools.tooltipMode or "cursor" end
        if db.tooltipCursorAltOnly == nil then
            if tools.tooltipCursorAltOnly ~= nil then db.tooltipCursorAltOnly = tools.tooltipCursorAltOnly
            else db.tooltipCursorAltOnly = 1 end
        end
        if db.idEnabled == nil then db.idEnabled = ids.enabled ~= false and oldOwner.enabled ~= false end
        if db.idShowOnAlt == nil then db.idShowOnAlt = ids.showOnAlt ~= false end
        tools.enableTooltipCursor, tools.tooltipMode, tools.tooltipCursorAltOnly = nil, nil, nil
        if profile.addons then profile.addons.IdTip = nil end
        modules.id_detection = nil
        db.settingsMigrated = true
    end
    if not db.ownershipMigrated then
        local bags = modules.bags or {}
        local legacy = profile.addons and profile.addons.Bagnon_FT or {}
        if db.ownerTrackingEnabled == nil then
            if legacy.enabled ~= nil then db.ownerTrackingEnabled = legacy.enabled ~= false
            else db.ownerTrackingEnabled = bags.ownerTrackingEnabled ~= false end
        end
        if db.ownerTrackingShowOnAlt == nil then
            if legacy.showOnAlt ~= nil then db.ownerTrackingShowOnAlt = legacy.showOnAlt == true
            else db.ownerTrackingShowOnAlt = bags.ownerTrackingShowOnAlt == true end
        end
        bags.ownerTrackingEnabled, bags.ownerTrackingShowOnAlt = nil, nil
        if profile.addons then profile.addons.Bagnon_FT = nil end
        db.ownershipMigrated = true
    end
    if not db.chatTooltipMigrated then
        local chat = modules.chat or {}
        db.chatTooltip = db.chatTooltip or {}
        for key, default in pairs({ tooltipPositionEnabled = 1, tooltipBaseOffset = 20,
            tooltipPetOffset = 60, itemRefIconsEnabled = 1 }) do
            if db.chatTooltip[key] == nil then
                local old = chat[key]
                if old == nil then old = default end
                db.chatTooltip[key] = old
            end
            chat[key] = nil
        end
        db.chatTooltipMigrated = true
    end
    return db
end

function module:GetChatTooltipDB() return self:GetDB().chatTooltip end

function module:IsEnabled()
    return not self._runtimeDisabled and self:GetDB().enabled ~= false
end

function module:IsDefaultTooltipHidden()
    local db = self:GetDB()
    return (db.enableTooltipCursor == 1 or db.enableTooltipCursor == true) and db.tooltipMode == "hidden"
end

function module:IsItemOwnershipEnabled()
    return self:IsEnabled() and self:GetDB().ownerTrackingEnabled ~= false
end

function module:ApplyItemOwnership()
    if SarychUI_TooltipOwnership_Sync then SarychUI_TooltipOwnership_Sync() end
end

function module:RefreshOptions()
    if SUI.OptionsCore then SUI.OptionsCore:ScheduleSmartRefresh(true) end
end

function module:Enable()
    self._runtimeDisabled = false
    self:ApplyTooltipCursor()
    self:ApplyIdTip()
    self:ApplyItemOwnership()
    self:ApplyChatTooltipSettings()
end

function module:Disable()
    self._runtimeDisabled = true
    self:ApplyChatTooltipSettings()
    self:ApplyItemOwnership()
    self:ApplyIdTip(true)
    self:DisableTooltipCursor()
    self:ApplyTooltipPosition()
end

function module:RefreshConfig()
    if self:GetDB().enabled ~= false then self:Enable() else self:Disable() end
end

function module:Initialize()
    self:GetDB()
    self:Disable()
end

function module:GetOptions()
    local args = {
        settings = { type = "group", name = "ui.settings_985b5e0f", order = 1,
            args = self:GetTooltipCursorOptions() },
        additional = { type = "group", name = "ui.extra_d51dd676", order = 2,
            args = { idBox = self:GetIdTipOptions(), ownershipBox = self:GetItemOwnershipOptions() } },
        chatTooltip = self:GetChatTooltipOptions(),
    }
    args.enabled = {
        type = "toggle", name = "ui.enable_a54eaf37", order = 0,
        get = function() return module:GetDB().enabled ~= false end,
        set = function(_, value)
            module:GetDB().enabled = value and true or false
            module:RefreshConfig()
            module:RefreshOptions()
        end,
    }
    return { type = "group", name = "ui.tooltip.control_title", args = args, childGroups = "tab",
        suiBodyDisabled = function() return not module:IsEnabled() end }
end
