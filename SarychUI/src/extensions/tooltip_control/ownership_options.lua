local module = SarychUI.modules.tooltip_control

function module:GetItemOwnershipOptions()
    return {
        type = "group", name = "ui.tooltip.ownership_title", order = 4, inline = true, suiTwoCol = true,
        args = {
            enabled = {
                type = "toggle", name = "ui.text_0781c0a5", desc = "ui.text_3d3de752",
                order = 1, width = "full", suiFullRow = true,
                get = function() return module:GetDB().ownerTrackingEnabled ~= false end,
                set = function(_, value)
                    module:GetDB().ownerTrackingEnabled = value and true or false
                    module:ApplyItemOwnership()
                    module:RefreshOptions()
                end,
            },
            altDetails = {
                type = "group", name = "", order = 2, inline = true,
                hidden = function() return module:GetDB().ownerTrackingEnabled == false end,
                args = {
                    showOnAlt = {
                        type = "toggle", name = "ui.alt_0a202e3b", desc = "ui.alt_b8ac4fd2",
                        suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON, order = 1, width = "full",
                        get = function() return module:GetDB().ownerTrackingShowOnAlt == true end,
                        set = function(_, value)
                            module:GetDB().ownerTrackingShowOnAlt = value and true or false
                            if BagnonFT_UpdateAltState then BagnonFT_UpdateAltState() end
                        end,
                    },
                },
            },
        },
    }
end
