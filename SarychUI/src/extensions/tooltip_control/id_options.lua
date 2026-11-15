local owner = SarychUI.modules.tooltip_control

function owner:IsIdTipEnabled() return self:GetDB().idEnabled ~= false end
function owner:IsIdTipRunning() return self.IdTipRunning == true end

function owner:SetIdTipEnabled(enable)
    self:GetDB().idEnabled = enable and true or false
    self:ApplyIdTip()
    self:RefreshOptions()
end

function owner:ApplyIdTip(forceOff)
    local enable = not forceOff and self:IsEnabled() and self:IsIdTipEnabled()
    self.IdTipRunning = enable and true or false
    IdTipEnabled = self.IdTipRunning
    SarychUI_SetIdTipRuntime(self.IdTipRunning)
    if self.IdTipRunning then IdTip_RefreshCurrentTooltip() end
    return self.IdTipRunning
end

function owner:GetIdTipOptions()
    return {
        type = "group", name = "ui.tooltip.id_title", order = 3, inline = true, suiTwoCol = true,
        args = {
            enabled = {
                type = "toggle", name = "ui.tooltip.show_ids", order = 1, width = "full", suiFullRow = true,
                get = function() return owner:IsIdTipEnabled() end,
                set = function(_, value) owner:SetIdTipEnabled(value) end,
            },
            altBox = {
                type = "group", name = "", inline = true, order = 2,
                hidden = function() return not owner:IsIdTipEnabled() end,
                args = {
                    showOnAlt = {
                        type = "toggle", name = "Показывать при зажатии {SUI_MODIFIER}",
                        desc = "Показывать ID только при зажатой клавише {SUI_MODIFIER}",
                        order = 1, width = "full", suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                        get = function() return owner:GetDB().idShowOnAlt ~= false end,
                        set = function(_, value)
                            owner:GetDB().idShowOnAlt = value and true or false
                            owner:ApplyIdTip()
                        end,
                    },
                },
            },
        },
    }
end
