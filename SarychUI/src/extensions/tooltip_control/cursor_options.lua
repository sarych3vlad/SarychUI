local module = SarychUI.modules.tooltip_control
local function DB() return module:GetDB() end
local function isOn(key) return DB()[key] == 1 or DB()[key] == true end
local function cursorOff() return not isOn("enableTooltipCursor") end
local function positionOff() return not isOn("positioningEnabled") end

function module:GetTooltipCursorOptions()
    return {
        tooltipCursorBox = {
            type = "group", name = "ui.tooltip.settings", desc = "ui.tooltip.settings_desc",
            order = 1, inline = true, suiTwoCol = true,
            args = {
                enableTooltipCursor = {
                    type = "toggle", name = "Enable", order = 1, width = "full", suiFullRow = true,
                    desc = "ui.tooltip.settings_desc",
                    get = function() return isOn("enableTooltipCursor") end,
                    set = function(_, value)
                        DB().enableTooltipCursor = value and 1 or 0
                        module:ApplyTooltipCursor(); module:RefreshOptions()
                    end,
                },
                tooltipMode = {
                    type = "select", name = "ui.tooltip.mode", order = 2, width = "full", suiFullRow = true,
                    values = { cursor = "ui.enable_tooltip_at_cursor_02992a7b", hidden = "ui.tooltip.hidden" },
                    get = function() return DB().tooltipMode or "cursor" end,
                    set = function(_, value)
                        DB().tooltipMode = value
                        module:ApplyTooltipCursor(); module:RefreshOptions()
                    end,
                    hidden = cursorOff,
                },
                altBox = {
                    type = "group", name = "", inline = true, order = 3,
                    hidden = function() return cursorOff() or DB().tooltipMode == "hidden" end,
                    args = {
                        tooltipCursorAltOnly = {
                            type = "toggle", name = "ui.only_while_holding_cffffd700alt_r_51e31293",
                            desc = "ui.tooltip_at_cursor_only_works_while_holding_cffff_d0f0df5b",
                            order = 1, width = "full", suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                            get = function() return isOn("tooltipCursorAltOnly") end,
                            set = function(_, value)
                                DB().tooltipCursorAltOnly = value and 1 or 0
                                module:ApplyTooltipCursor(); module:RefreshOptions()
                            end,
                        },
                    },
                },
            },
        },
        positionBox = {
            type = "group", name = "ui.tooltip.position_title", order = 2, inline = true, suiTwoCol = true,
            hidden = function() return module:IsDefaultTooltipHidden() end,
            args = {
                positioningEnabled = {
                    type = "toggle", name = "ui.enable_a54eaf37", desc = "ui.tooltip.position_desc",
                    order = 1, width = "full", suiFullRow = true,
                    get = function() return isOn("positioningEnabled") end,
                    set = function(_, value)
                        DB().positioningEnabled = value and 1 or 0
                        module:ApplyTooltipPosition(); module:RefreshOptions()
                    end,
                },
                offsetX = {
                    type = "range", name = "ui.x_offset_0b923c73", order = 2, min = -3000, max = 3000, step = 1,
                    get = function() return DB().offsetX or 0 end,
                    set = function(_, value) module:SetTooltipPositionOffset("offsetX", value) end,
                    hidden = positionOff,
                },
                offsetY = {
                    type = "range", name = "ui.y_offset_f7f3fdd7", order = 3, min = -3000, max = 3000, step = 1,
                    get = function() return DB().offsetY or 0 end,
                    set = function(_, value) module:SetTooltipPositionOffset("offsetY", value) end,
                    hidden = positionOff,
                },
                showDragFrame = {
                    type = "execute", order = 4, width = "full", suiFullRow = true,
                    name = function()
                        return SarychUI:T(isOn("showDragFrame") and "ui.options_76e4992833" or "ui.options_0510004a87")
                    end,
                    desc = "ui.tooltip.position_desc",
                    func = function() module:ToggleTooltipPositionDrag() end,
                    suiResetDefaults = function()
                        module:SetTooltipPositionOffset("offsetX", 0)
                        module:SetTooltipPositionOffset("offsetY", 0)
                        module:RefreshOptions()
                    end,
                    hidden = positionOff,
                },
            },
        },
    }
end
