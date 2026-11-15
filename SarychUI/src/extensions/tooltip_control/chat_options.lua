local module = SarychUI.modules.tooltip_control

local function GetSetting(key, fallback)
    local value = module:GetChatTooltipDB()[key]
    if value == nil then return fallback end
    return value
end

local function ApplySetting(key, value)
    module:GetChatTooltipDB()[key] = value
    module:ApplyChatTooltipSettings()
end

local function PositionDisabled()
    return GetSetting("tooltipPositionEnabled", 1) ~= 1
end

function module:GetChatTooltipOptions()
    return {
        type = "group", name = "ui.chat_tooltip_window_373a9c2a", order = 3,
        args = {
            preview = {
                type = "description", name = "", order = 0, width = "full", suiFullRow = true,
                suiPreview = "ChatTooltipPreview",
            },
            iconsBox = {
                type = "group", name = "ui.icons_f52d3f2f", order = 1, inline = true,
                args = {
                    itemRefIconsEnabled = {
                        type = "toggle", name = "ui.enable_icons_in_the_tooltip_window_93f56a27",
                        desc = "ui.options_b6685a2624", order = 1, width = "full", suiFullRow = true,
                        suiPreviewKey = "itemRefIconsEnabled",
                        get = function() return GetSetting("itemRefIconsEnabled", 1) == 1 end,
                        set = function(_, value)
                            ApplySetting("itemRefIconsEnabled", value and 1 or 0)
                            local preview = SarychUI.ChatTooltipPreview
                            if preview then preview:SetLiveValue("itemRefIconsEnabled", value and 1 or 0) end
                        end,
                    },
                },
            },
            tooltipBox = {
                type = "group", name = "ui.window_position_8bd803cf", order = 2, inline = true,
                suiTwoCol = true,
                args = {
                    tooltipPositionEnabled = {
                        type = "toggle", name = "ui.options_d87bcc3eca", desc = "ui.options_733f10ff49",
                        order = 1, width = "full", suiFullRow = true,
                        get = function() return not PositionDisabled() end,
                        set = function(_, value)
                            ApplySetting("tooltipPositionEnabled", value and 1 or 0)
                            module:RefreshOptions()
                        end,
                    },
                    tooltipBaseOffset = {
                        type = "range", name = "ui.base_y_offset_2476b6cb", desc = "ui.base_tooltip_window_y_offset_e3188c0c",
                        order = 2, min = -100, max = 100, step = 1, disabled = PositionDisabled,
                        get = function() return GetSetting("tooltipBaseOffset", 20) end,
                        set = function(_, value) ApplySetting("tooltipBaseOffset", value) end,
                    },
                    tooltipPetOffset = {
                        type = "range", name = "ui.y_offset_with_pet_bar_772d6200", desc = "ui.extra_tooltip_y_offset_when_the_pet_action_bar_i_f25b3718",
                        order = 3, min = -100, max = 100, step = 1, disabled = PositionDisabled,
                        get = function() return GetSetting("tooltipPetOffset", 60) end,
                        set = function(_, value) ApplySetting("tooltipPetOffset", value) end,
                    },
                },
            },
        },
    }
end
