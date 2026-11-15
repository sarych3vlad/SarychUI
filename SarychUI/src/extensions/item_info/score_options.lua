-- Score presentation options owned by equipment information.
local owner = SarychUI.modules.item_info

function owner:IsItemLevelMode()
    return self.settings and self.settings.DisplayMode == "itemlevel"
end

function owner:ApplyNativeItemLevel()
    -- This is a shared WoW preference. Enable it when applying this mode,
    -- but leave it to the user when disabling GS or selecting another mode.
    if owner.enabled and owner:IsScoreEnabled() and owner:IsItemLevelMode() and GetCVar("showItemLevel") ~= "1" then
        SetCVar("showItemLevel", "1")
    end
end

function owner:IsScoreEnabled()
    local cfg = self:GetDB()
    return cfg.enabled ~= false and cfg.enabled ~= 0 and cfg.score.enabled ~= false
end

function owner:GetGearScoreOptions()
    local args = {
        enabled = {type = "toggle", name = SarychUI:T("ui.equipment.score"), order = 1,
            disabled = function() return owner:GetDB().enabled == false end,
            get = function() return owner:GetDB().score.enabled ~= false end,
            set = function(_, value)
                owner:GetDB().score.enabled = value and true or false
                owner:ApplyEquipment()
                if SarychUI.OptionsCore and SarychUI.OptionsCore.ScheduleSmartRefresh then
                    SarychUI.OptionsCore:ScheduleSmartRefresh(true)
                end
            end},
        DisplayMode = {type = "select", name = SarychUI:T("ui.gearscore.display_mode"), order = 2,
            desc = SarychUI:T("ui.gearscore.display_mode_desc"),
            values = {gearscore = "GearScore", itemlevel = SarychUI:T("ui.gearscore.item_level")},
            hidden = function() return owner:GetDB().score.enabled == false end,
            disabled = function() return not owner:IsScoreEnabled() end,
            get = function() return owner:IsItemLevelMode() and "itemlevel" or "gearscore" end,
            set = function(_, value)
                if value ~= "gearscore" and value ~= "itemlevel" then return end
                owner.settings.DisplayMode = value
                owner:ApplyNativeItemLevel()
                owner:RefreshEquipmentViews()
            end},
        ThousandsSeparator = {type = "toggle", name = SarychUI:T("ui.gearscore.thousands_separator"), order = 2.5,
            desc = SarychUI:T("ui.gearscore.thousands_separator_desc"),
            hidden = function()
                return owner:GetDB().score.enabled == false
                    or (owner:IsItemLevelMode() and not owner:GetDB().sources.enabled)
            end,
            disabled = function() return not owner:IsScoreEnabled() end,
            get = function() return owner.settings and owner.settings.ThousandsSeparator == true or false end,
            set = function(_, value)
                owner.settings.ThousandsSeparator = value and true or false
                owner:RefreshEquipmentViews()
            end},
    }
    local settings = {
        {"Player", SarychUI:T("ui.gearscore.unit_tooltip")},
        {"Inspect", SarychUI:T("ui.gearscore.inspect")},
        {"Item", SarychUI:T("ui.gearscore.item_tooltip")},
    }
    for index, setting in ipairs(settings) do
        local key, label = setting[1], setting[2]
        args[key] = {type = "toggle", name = label, order = index + 2,
            hidden = function()
                return owner:GetDB().score.enabled == false or (key == "Item" and owner:IsItemLevelMode())
            end,
            disabled = function() return not owner:IsScoreEnabled() end,
            get = function() return owner.settings and owner.settings[key] == 1 end,
            set = function(_, value)
                owner.settings[key] = value and 1 or -1
                owner:RefreshEquipmentViews()
            end}
    end
    return {type = "group", name = "GearScore", args = args}
end
