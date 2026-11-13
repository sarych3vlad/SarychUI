local SuiTimer = select(2, ...).Compat.Timer
-- SarychUI Chat Module Options
local tinsert = table.insert

local moduleName = "chat"
local module = SarychUI:GetModule(moduleName)

-- Localization
local L = SarychUI.L

-- Helper function to check if module is enabled
local function isEnabled()
    local db = SarychUI:GetModuleProfile(moduleName)
    if db and db.enabled ~= nil then
        return db.enabled
    end
    return true
end

local function GetSetting(key, default)
    local db = SarychUI:GetModuleProfile(moduleName)
    if db and db[key] ~= nil then
        return db[key]
    end
    return default
end

local function DataBarRegionOptions(position, label, default, order)
    local key = "dataBar" .. position:gsub("^%l", string.upper)
    local function Apply()
        if _G.ApplyDataBarSettings then _G.ApplyDataBarSettings() end
    end
    return {
        type = "group", name = label, inline = true, order = order,
        disabled = function() return GetSetting("dataBarEnabled", 0) ~= 1 end,
        args = {
            content = {
                type = "select", name = "ui.chat.data_bar.content", order = 1, width = "full",
                values = function() return _G.SarychUI_ChatDataTexts:GetValues() end,
                get = function() return GetSetting(key, default) end,
                set = function(_, value)
                    SarychUI.db.profile.modules.chat[key] = value
                    Apply()
                end,
            },
            tooltip = {
                type = "toggle", name = "ui.chat.data_bar.tooltip", order = 2, width = "full",
                get = function()
                    local value = GetSetting(key .. "Tooltip", true)
                    return value ~= false and value ~= 0
                end,
                set = function(_, value)
                    SarychUI.db.profile.modules.chat[key .. "Tooltip"] = value
                    Apply()
                end,
            },
            text = {
                type = "toggle", name = "ui.chat.data_bar.text", order = 3, width = "full",
                desc = "ui.chat.data_bar.text_desc",
                get = function()
                    local value = GetSetting(key .. "Text", true)
                    return value ~= false and value ~= 0
                end,
                set = function(_, value)
                    SarychUI.db.profile.modules.chat[key .. "Text"] = value
                    Apply()
                end,
            },
            altEnabled = {
                type = "toggle", name = "ui.chat.data_bar.alt_enabled", order = 4, width = "full",
                desc = "ui.chat.data_bar.alt_desc",
                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                get = function()
                    local value = GetSetting(key .. "AltEnabled", false)
                    return value == true or value == 1
                end,
                set = function(_, value)
                    SarychUI.db.profile.modules.chat[key .. "AltEnabled"] = value
                    Apply()
                    if SarychUI.NotifySarychUIOptionsChange then SarychUI:NotifySarychUIOptionsChange() end
                end,
            },
            altContent = {
                type = "select", name = "ui.chat.data_bar.alt_content", order = 5, width = "full",
                hidden = function()
                    local value = GetSetting(key .. "AltEnabled", false)
                    return value ~= true and value ~= 1
                end,
                values = function()
                    local values = _G.SarychUI_ChatDataTexts:GetValues()
                    values.SAME = SarychUI:T("ui.chat.data_bar.alt_same")
                    return values
                end,
                get = function() return GetSetting(key .. "Alt", "SAME") end,
                set = function(_, value)
                    SarychUI.db.profile.modules.chat[key .. "Alt"] = value
                    Apply()
                end,
            },
        },
    }
end

-- ChatFrame1 is the main docked chat window. Blizzard stores its position as
-- normalized screen coordinates and its dimensions in UI units.
local function GetMainChatGeometry()
    local frame = _G.ChatFrame1 or _G.DEFAULT_CHAT_FRAME
    if not frame then return nil end
    local x, y = frame:GetLeft() or 0, frame:GetBottom() or 0
    local width, height = frame:GetWidth() or 400, frame:GetHeight() or 150
    local id = frame:GetID()
    if GetChatWindowSavedPosition then
        local point, nx, ny = GetChatWindowSavedPosition(id)
        if point == "BOTTOMLEFT" and nx and ny then
            x = nx * ((GetScreenWidth and GetScreenWidth()) or UIParent:GetWidth())
            y = ny * ((GetScreenHeight and GetScreenHeight()) or UIParent:GetHeight())
        end
    end
    if GetChatWindowSavedDimensions then
        local savedWidth, savedHeight = GetChatWindowSavedDimensions(id)
        width, height = savedWidth or width, savedHeight or height
    end
    return frame, x, y, width, height
end

local function SetMainChatGeometry(field, value)
    local frame, x, y, width, height = GetMainChatGeometry()
    if not frame then return end
    if field == "x" then x = value
    elseif field == "y" then y = value
    elseif field == "width" then width = value
    elseif field == "height" then height = value end

    local screenWidth = (GetScreenWidth and GetScreenWidth()) or UIParent:GetWidth()
    local screenHeight = (GetScreenHeight and GetScreenHeight()) or UIParent:GetHeight()
    local id = frame:GetID()
    local locked = GetChatWindowInfo and select(8, GetChatWindowInfo(id))
    if FCF_SetLocked then FCF_SetLocked(frame, false) end
    if SetChatWindowSavedDimensions then
        SetChatWindowSavedDimensions(id, width, height)
    end
    if SetChatWindowSavedPosition then
        SetChatWindowSavedPosition(id, "BOTTOMLEFT", x / screenWidth, y / screenHeight)
    end
    if FCF_RestorePositionAndDimensions then
        FCF_RestorePositionAndDimensions(frame)
    else
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
        frame:SetWidth(width)
        frame:SetHeight(height)
    end
    if frame.SetUserPlaced then frame:SetUserPlaced(true) end
    if FloatingChatFrame_UpdateBackgroundAnchors then
        FloatingChatFrame_UpdateBackgroundAnchors(frame)
    end
    if FCF_SetLocked and locked then FCF_SetLocked(frame, true) end
end

local CHAT_WHEEL_PHRASE_DEFAULTS = {
    "Фраза 1", "Фраза 2", "Фраза 3", "Фраза 4",
    "Фраза 5", "Фраза 6", "Фраза 7", "Подтверждаю",
}

local function EnsureChatWheelDb(db)
    if type(db.chatWheel) ~= "table" then
        local def = SarychUI.defaults.profile.modules.chat.chatWheel
        db.chatWheel = def and CopyTable(def) or {}
    end
end

local function ChatWheelModuleEnabled()
    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
    return cw and (cw.enabled == 1 or cw.enabled == true)
end

local pendingSpamFilterInput = ""

local function RefreshChatOptionsPanel()
    if SarychUI and SarychUI.NotifySarychUIOptionsChange then
        SarychUI:NotifySarychUIOptionsChange()
    elseif SarychUI and SarychUI.RefreshConfig then
        SarychUI:RefreshConfig()
    end
end



local function GetActiveSpamPatterns()
    if _G.sarChat_GetSpamPatterns then
        return _G.sarChat_GetSpamPatterns() or {}
    end
    return {}
end

local function AddSpamFilter(text)
    if not text then return false end
    local trimmed = (strtrim and strtrim(text)) or tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then return false end

    local patterns = GetActiveSpamPatterns()
    for _, filter in ipairs(patterns) do
        if filter == trimmed then
            print(SarychUI:T("ui.options_fff032acd7") .. trimmed)
            return false
        end
    end

    local enabledList = GetSetting("spamEnabledList", {})
    local customList = GetSetting("spamCustomList", {})
    for _, filter in ipairs(enabledList) do
        if filter == trimmed then
            print(SarychUI:T("ui.options_fff032acd7") .. trimmed)
            return false
        end
    end

    tinsert(enabledList, trimmed)
    tinsert(customList, trimmed)
    SarychUI.db.profile.modules[moduleName].spamEnabledList = enabledList
    SarychUI.db.profile.modules[moduleName].spamCustomList = customList
    print(SarychUI:T("ui.options_cb047cd2c3") .. trimmed)
    return true
end

local function RemoveSpamFilter(pattern)
    if not pattern or pattern == "" then return end
    local deletedList = GetSetting("spamDeletedList", {})
    for _, filter in ipairs(deletedList) do
        if filter == pattern then
            return
        end
    end
    tinsert(deletedList, pattern)
    SarychUI.db.profile.modules[moduleName].spamDeletedList = deletedList
    print(SarychUI:T("ui.options_40a78c68c5") .. pattern)
end

local function BuildSpamFilterListArgs()
    local args = {
        addInput = {
            type = "input",
            name = "",
            desc = "ui.message_text_or_part_of_it_to_filter_df921724",
            order = 1,
            width = "full",
            suiSaveButton = SarychUI:T("ui.options_559a87f7cc"),
            disabled = function() return GetSetting("spamFilterEnabled", 1) ~= 1 end,
            get = function() return pendingSpamFilterInput end,
            set = function(_, val)
                pendingSpamFilterInput = val or ""
                if AddSpamFilter(pendingSpamFilterInput) then
                    pendingSpamFilterInput = ""
                    module:ApplyAllSettings()
                    RefreshChatOptionsPanel()
                end
            end,
        },
    }
    local patterns = GetActiveSpamPatterns()
    for i, pattern in ipairs(patterns) do
        local captured = pattern
        args["spamRow_" .. i] = {
            type = "group",
            inline = true,
            name = "",
            order = 10 + i,
            suiCompactListRow = true,
            args = {
                label = {
                    type = "description",
                    name = captured,
                    order = 1,
                },
                removeBtn = {
                    type = "execute",
                    name = "ui.delete_be99b136",
                    order = 2,
                    func = function()
                        RemoveSpamFilter(captured)
                        module:ApplyAllSettings()
                        RefreshChatOptionsPanel()
                    end,
                },
            },
        }
    end
    return args
end

local function BuildChatWheelPhraseOptionEntries()
    local phraseArgs = {}
    for i = 1, 8 do
        local textKey = "phrase" .. i .. "Text"
        local emoteKey = "phrase" .. i .. "Emote"
        local defaultText = CHAT_WHEEL_PHRASE_DEFAULTS[i] or (SarychUI:T("ui.options_cb169ec8b4") .. i)
        phraseArgs["chat_wheel_phrase_" .. i] = {
            type = "input",
            name = function() return SarychUI:T("ui.options_e124d44478", i) end,
            suiPairedInputLabel = function() return SarychUI:T("ui.options_09ba471fba") end,
            desc = "ui.slash_command_after_the_text_for_example_dance_o_c8e8b347",
            order = i,
            width = "full",
            get = function()
                local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                local text = cw and cw[textKey]
                if text == nil or text == defaultText then text = SarychUI:T(defaultText) end
                return {text, cw and cw[emoteKey] or ""}
            end,
            set = function(_, values)
                local db = SarychUI.db.profile.modules[moduleName]
                EnsureChatWheelDb(db)
                db.chatWheel[textKey] = values[1] or ""
                db.chatWheel[emoteKey] = values[2] or ""
                if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyPhrases then
                    _G.SarychUI_ChatWheel.ApplyPhrases()
                end
            end,
            disabled = function() return not ChatWheelModuleEnabled() end,
        }
    end
    return {
        phraseTextsBox = {
            type = "group",
            name = "ui.phrase_texts_9d3f3515",
            hidden = function() return not ChatWheelModuleEnabled() end,
            inline = true,
            order = 1.5,
            args = phraseArgs,
        },
    }
end

-- Get options
function module:GetOptions()
    local baseOptions = {
        type = "group",
        name = L and (L["Chat"] or SarychUI:T("ui.chat_window_f5d1e5ea")) or SarychUI:T("ui.chat_window_f5d1e5ea"),
        desc = L and (L["Chat_Description"] or SarychUI:T("ui.options_d38324b1d5")) or SarychUI:T("ui.options_d38324b1d5"),
        childGroups = "tab",
        args = {
            -- General Tab (enable only - WrapModuleOptionsWithEnableHeader
            -- lifts it to the title bar and removes this empty tab)
            general = {
                type = "group",
                name = "ui.general_b250a3d6",
                order = 1,
                args = {
                    enabled = {
                        suiModuleEnable = true,
                        type = "toggle",
                        name = L and (L["Enable_Module"] or SarychUI:T("ui.enable_module_b623b573")) or SarychUI:T("ui.enable_module_b623b573"),
                        desc = "ui.enable_or_disable_the_module_ce99024f",
                        order = 1,
                        width = "full",
                        get = function()
                            return SarychUI.db.profile.modules[moduleName].enabled
                        end,
                        set = function(info, value)
                            SarychUI.db.profile.modules[moduleName].enabled = value
                            if value then
                                SarychUI:EnableModule(moduleName)
                            else
                                SarychUI:DisableModule(moduleName)
                            end
                        end,
                    },
                },
            },

            -- Functionality Tab
            functionality = {
                type = "group",
                name = L and (L["Functionality"] or SarychUI:T("ui.options_25a8c1834e")) or SarychUI:T("ui.options_25a8c1834e"),
                order = 2,
                disabled = function() return not isEnabled() end,
                childGroups = "tab",
                args = {
                    -- Management tab
                    management = {
                        type = "group",
                        name = "ui.general_b250a3d6",
                        order = 1,
                        args = {
                            generalBox = {
                                type = "group",
                                name = "ui.general_d40de76d",
                                order = 1,
                                inline = true,
                                args = {
                                    enableChatTabFontSizeMenu = {
                                        type = "toggle",
                                        name = "ui.font_size_in_the_chat_tab_menu_63fe4c3f",
                                        desc = "ui.adds_a_font_size_menu_6_20_to_the_chat_tab_menu_a7d6e22c",
                                        order = 1,
                                        width = "full",
                                        get = function() return GetSetting("enableChatTabFontSizeMenu", 1) == 1 end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].enableChatTabFontSizeMenu = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChatTabFontSizeMenuSettings()
                                            end
                                        end,
                                    },
                                    enableChatCharCount = {
                                        type = "toggle",
                                        name = "ui.show_remaining_characters_in_the_chat_edit_box_b9c3b65e",
                                        desc = "ui.shows_remaining_character_count_while_typing_a_c_62028679",
                                        order = 2,
                                        width = "full",
                                        get = function() return GetSetting("enableChatCharCount", 1) == 1 end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].enableChatCharCount = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChatCharCountSettings()
                                            end
                                        end,
                                    },
                                },
                            },
                            classMentionsBox = {
                                type = "group",
                                name = "ui.class_color_mentions_bffe31dd",
                                desc = "ui.color_player_names_by_class_when_they_are_mentio_325cbe24",
                                order = 1.5,
                                inline = true,
                                args = {
                                    classColorMentionsEnabled = {
                                        type = "toggle",
                                        name = "ui.enable_class_color_mentions_8f666276",
                                        desc = "ui.color_player_names_by_class_when_they_are_mentio_325cbe24",
                                        order = 1,
                                        width = "full",
                                        get = function() return GetSetting("classColorMentionsEnabled", 1) == 1 end,
                                        set = function(_, value)
                                            SarychUI.db.profile.modules[moduleName].classColorMentionsEnabled = value and 1 or 0
                                            if _G.ApplyClassMentions then
                                                _G.ApplyClassMentions()
                                            end
                                            RefreshChatOptionsPanel()
                                        end,
                                    },
                                    classMentionsDestinations = {
                                        type = "group",
                                        name = "",
                                        order = 2,
                                        inline = true,
                                        hidden = function() return GetSetting("classColorMentionsEnabled", 1) ~= 1 end,
                                        args = {
                                            classColorMentionsChat = {
                                                type = "toggle",
                                                name = "ui.chat_917bb522",
                                                desc = "ui.color_mentioned_player_names_by_class_in_the_cha_104444c3",
                                                order = 2,
                                                width = "full",
                                                get = function() return GetSetting("classColorMentionsChat", 1) == 1 end,
                                                set = function(_, value)
                                                    SarychUI.db.profile.modules[moduleName].classColorMentionsChat = value and 1 or 0
                                                    if _G.ApplyClassMentions then
                                                        _G.ApplyClassMentions()
                                                    end
                                                end,
                                            },
                                            classColorMentionsSpeech = {
                                                type = "toggle",
                                                name = "ui.chat_bubbles_d38e3070",
                                                desc = "ui.color_mentioned_player_names_by_class_in_speech__3b0345ca",
                                                order = 3,
                                                width = "full",
                                                get = function() return GetSetting("classColorMentionsSpeech", 1) == 1 end,
                                                set = function(_, value)
                                                    SarychUI.db.profile.modules[moduleName].classColorMentionsSpeech = value and 1 or 0
                                                    if _G.ApplyClassMentions then
                                                        _G.ApplyClassMentions()
                                                    end
                                                end,
                                            },
                                        },
                                    },
                                },
                            },
                            emojiBox = {
                                type = "group",
                                name = "ui.emoji_4cf89150",
                                order = 2,
                                inline = true,
                                suiHeaderIcon = "Interface\\AddOns\\SarychUI\\media\\chat_emojis\\emoticons.dxt5.blp",
                                args = {
                                    emotionIcons = {
                                        type = "toggle",
                                        name = "ui.enable_emoji_fc883107",
                                        desc = "ui.replaces_text_emoticons_in_chat_with_icons_8c0056be",
                                        order = 1,
                                        width = "full",
                                        get = function() return GetSetting("emotionIcons", 1) == 1 end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].emotionIcons = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyEmotionSettings()
                                            elseif _G.ApplyEmotionSettings then
                                                _G.ApplyEmotionSettings()
                                            end
                                            RefreshChatOptionsPanel()
                                        end,
                                    },
                                    emojiDetails = {
                                        type = "group",
                                        name = "",
                                        order = 2,
                                        inline = true,
                                        hidden = function() return GetSetting("emotionIcons", 1) ~= 1 end,
                                        args = {
                                            emotionBubbles = {
                                                type = "toggle",
                                                name = "ui.emoji_in_speech_bubbles_above_characters_4b10fbd9",
                                                desc = "ui.replaces_smileys_with_icons_in_speech_bubbles_ab_25bc65ae",
                                                order = 2,
                                                width = "full",
                                                get = function() return GetSetting("emotionBubbles", 0) == 1 end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].emotionBubbles = value and 1 or 0
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyEmotionSettings()
                                                    elseif _G.ApplyEmotionSettings then
                                                        _G.ApplyEmotionSettings()
                                                    end
                                                end,
                                            },
                                            emotionPickerEnabled = {
                                                type = "toggle",
                                                name = "ui.show_emoji_picker_button_0180a567",
                                                desc = "ui.shows_a_button_near_chat_to_open_the_emoji_picke_286b0048",
                                                order = 3,
                                                width = "full",
                                                get = function() return GetSetting("emotionPickerEnabled", 0) == 1 end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].emotionPickerEnabled = value and 1 or 0
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyEmotionSettings()
                                                    elseif _G.ApplyEmotionSettings then
                                                        _G.ApplyEmotionSettings()
                                                    end
                                                    RefreshChatOptionsPanel()
                                                end,
                                            },
                                            emotionPickerOnAlt = {
                                                type = "toggle",
                                                name = "ui.chat.emoji_button_alt",
                                                desc = "ui.chat.emoji_button_alt_desc",
                                                order = 3.1,
                                                width = "full",
                                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                                hidden = function() return GetSetting("emotionPickerEnabled", 0) ~= 1 end,
                                                get = function() return GetSetting("emotionPickerOnAlt", 0) == 1 end,
                                                set = function(_, value)
                                                    SarychUI.db.profile.modules[moduleName].emotionPickerOnAlt = value and 1 or 0
                                                    if _G.ApplyEmotionSettings then _G.ApplyEmotionSettings() end
                                                end,
                                            },
                                            emotionPickerTriggerEnabled = {
                                                type = "toggle",
                                                name = "ui.open_emoji_on_trigger_05a01e22",
                                                desc = "ui.opens_the_emoji_picker_when_the_set_text_is_type_5c6200b1",
                                                order = 4,
                                                width = "full",
                                                get = function() return GetSetting("emotionPickerTriggerEnabled", 1) == 1 end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].emotionPickerTriggerEnabled = value and 1 or 0
                                                    RefreshChatOptionsPanel()
                                                end,
                                            },
                                            emotionPickerTrigger = {
                                                type = "input",
                                                name = "ui.emoji_open_trigger_ab229167",
                                                desc = "ui.when_this_text_is_in_the_edit_box_the_emoji_pick_180e3449",
                                                order = 5,
                                                width = "full",
                                                suiSaveButton = "OK",
                                                suiKeepInput = true,
                                                get = function() return GetSetting("emotionPickerTrigger", "//") end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].emotionPickerTrigger = value or "//"
                                                end,
                                                hidden = function() return GetSetting("emotionPickerTriggerEnabled", 1) ~= 1 end,
                                            },
                                        },
                                    },
                                },
                            },
                            chatBarBox = {
                                type = "group",
                                name = "ui.chat_panel_a1c1b2a0",
                                order = 3,
                                inline = true,
                                args = {
                                    chatBarEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Chat_Bar"] or SarychUI:T("ui.options_087315c808")) or SarychUI:T("ui.options_087315c808"),
                                        desc = "ui.enable_or_disable_the_chat_panel_6231f59e",
                                        order = 1,
                                        width = "full",
                                        get = function() return GetSetting("chatBarEnabled", 1) == 1 end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].chatBarEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChatBarSettings()
                                            end
                                            RefreshChatOptionsPanel()
                                        end,
                                    },
                                    chatBarOnAlt = {
                                        type = "toggle",
                                        name = L and (L["Show_Chat_Bar_On_Alt"] or SarychUI:T("ui.options_b78415f4ae")) or SarychUI:T("ui.options_519bfe33ef"),
                                        desc = "ui.show_the_chat_panel_only_while_holding_alt_666ebf06",
                                        order = 2,
                                        width = "full",
                                        suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                        get = function() return GetSetting("chatBarOnAlt", 0) == 1 end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].chatBarOnAlt = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:UpdateChatBarVisibility()
                                            end
                                        end,
                                        disabled = function() return GetSetting("chatBarEnabled", 1) ~= 1 end,
                                    },
                                },
                            },
                            hotkeysBox = {
                                type = "group",
                                name = "ui.hotkeys_13b0a5cc",
                                order = 4,
                                inline = true,
                                args = {
                                    chatHotkeysEnabled = {
                                        type = "toggle",
                                        name = function()
                                            return SarychUI:T("ui.options_d13a6736fb")
                                        end,
                                        desc = "ui.enable_or_disable_all_chat_hotkeys_fef695d7",
                                        order = 1,
                                        width = "full",
                                        suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                        get = function() return GetSetting("chatHotkeysEnabled", 1) == 1 end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].chatHotkeysEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyHotkeysSettings()
                                            end
                                            RefreshChatOptionsPanel()
                                        end,
                                    },
                                    hotkeysDetails = {
                                        type = "group",
                                        name = "",
                                        order = 2,
                                        inline = true,
                                        args = {
                                            hotkeysYell = {
                                                type = "toggle",
                                                name = function()
                                                    return SarychUI:T("ui.options_c72081aa73")
                                                end,
                                                desc = "ui.enable_hotkey_for_yell_chat_7cad0170",
                                                order = 2,
                                                width = "full",
                                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                                get = function() return GetSetting("hotkeysYell", 1) == 1 end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].hotkeysYell = value and 1 or 0
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyHotkeysSettings()
                                                    end
                                                end,
                                                disabled = function()
                                                    return GetSetting("chatHotkeysEnabled", 1) ~= 1
                                                end,
                                            },
                                            hotkeysSay = {
                                                type = "toggle",
                                                name = function()
                                                    return SarychUI:T("ui.options_16a6afef56")
                                                end,
                                                desc = "ui.enable_hotkey_for_say_chat_8ec72e86",
                                                order = 3,
                                                width = "full",
                                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                                get = function() return GetSetting("hotkeysSay", 1) == 1 end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].hotkeysSay = value and 1 or 0
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyHotkeysSettings()
                                                    end
                                                end,
                                                disabled = function()
                                                    return GetSetting("chatHotkeysEnabled", 1) ~= 1
                                                end,
                                            },
                                            hotkeysAuto = {
                                                type = "toggle",
                                                name = function()
                                                    return SarychUI:T("ui.options_8ef9d9ec1a")
                                                end,
                                                desc = "ui.enable_hotkey_for_automatic_channel_selection_pa_040bae88",
                                                order = 4,
                                                width = "full",
                                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                                get = function() return GetSetting("hotkeysAuto", 1) == 1 end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].hotkeysAuto = value and 1 or 0
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyHotkeysSettings()
                                                    end
                                                end,
                                                disabled = function()
                                                    return GetSetting("chatHotkeysEnabled", 1) ~= 1
                                                end,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },

                    -- Chat Shortening tab
                    shortening = {
                        type = "group",
                        name = L and (L["Chat_Shortening"] or SarychUI:T("ui.options_88a8ecd3ff")) or SarychUI:T("ui.options_88a8ecd3ff"),
                        order = 2,
                        args = {
                            channelsBox = {
                                type = "group",
                                name = "ui.channel_abbreviations_96a4fe5f",
                                order = 1,
                                inline = true,
                                args = {
                                    channelShorteningEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Channel_Shortening"] or SarychUI:T("ui.options_d44594715f")) or SarychUI:T("ui.options_d44594715f"),
                                        desc = L and (L["Enable_Channel_Shortening_Desc"] or SarychUI:T("ui.options_f237cb4471")) or SarychUI:T("ui.options_f237cb4471"),
                                        order = 1,
                                        width = "full",
                                        get = function() return GetSetting("channelShorteningEnabled", 1) == 1 end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].channelShorteningEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                    },
                                    guild_abbrev = {
                                        type = "input",
                                        name = L and (L["Guild_Abbreviation"] or SarychUI:T("ui.options_3622927d80")) or SarychUI:T("ui.options_3622927d80"),
                                        desc = L and (L["Guild_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 3,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrGuild", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrGuild = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    officer_abbrev = {
                                        type = "input",
                                        name = L and (L["Officer_Abbreviation"] or SarychUI:T("ui.options_8e3bd54f88")) or SarychUI:T("ui.options_8e3bd54f88"),
                                        desc = L and (L["Officer_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 4,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrOfficer", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrOfficer = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    party_abbrev = {
                                        type = "input",
                                        name = L and (L["Party_Abbreviation"] or SarychUI:T("ui.party_907efbd4")) or SarychUI:T("ui.party_907efbd4"),
                                        desc = L and (L["Party_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 5,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrParty", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrParty = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    raid_abbrev = {
                                        type = "input",
                                        name = L and (L["Raid_Abbreviation"] or SarychUI:T("ui.options_2a85ca1699")) or SarychUI:T("ui.options_2a85ca1699"),
                                        desc = L and (L["Raid_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 6,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrRaid", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrRaid = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    say_abbrev = {
                                        type = "input",
                                        name = L and (L["Say_Abbreviation"] or SarychUI:T("ui.options_f53f2b3b89")) or SarychUI:T("ui.options_f53f2b3b89"),
                                        desc = L and (L["Say_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 7,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrSay", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrSay = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    yell_abbrev = {
                                        type = "input",
                                        name = L and (L["Yell_Abbreviation"] or SarychUI:T("ui.options_fb837a91d4")) or SarychUI:T("ui.options_fb837a91d4"),
                                        desc = L and (L["Yell_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 8,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrYell", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrYell = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    raid_warning_abbrev = {
                                        type = "input",
                                        name = L and (L["Raid_Warning_Abbreviation"] or SarychUI:T("ui.options_e84ffce0c5")) or SarychUI:T("ui.options_e84ffce0c5"),
                                        desc = L and (L["Raid_Warning_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 9,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrRaidWarning", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrRaidWarning = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    battleground_abbrev = {
                                        type = "input",
                                        name = L and (L["Battleground_Abbreviation"] or SarychUI:T("ui.options_32433d14d5")) or SarychUI:T("ui.options_32433d14d5"),
                                        desc = L and (L["Battleground_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 10,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrBattleground", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrBattleground = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    whisper_abbrev = {
                                        type = "input",
                                        name = L and (L["Whisper_Abbreviation"] or SarychUI:T("ui.options_6955f34e55")) or SarychUI:T("ui.options_6955f34e55"),
                                        desc = L and (L["Whisper_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 11,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrWhisper", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrWhisper = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    emote_abbrev = {
                                        type = "input",
                                        name = L and (L["Emote_Abbreviation"] or SarychUI:T("ui.options_09ba471fba")) or SarychUI:T("ui.options_09ba471fba"),
                                        desc = L and (L["Emote_Abbreviation_Desc"] or SarychUI:T("ui.options_0f5694fd5b")) or SarychUI:T("ui.options_0f5694fd5b"),
                                        order = 12,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("abbrEmote", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].abbrEmote = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- Other tab
                    other = {
                        type = "group",
                        name = "ui.extra_d51dd676",
                        order = 3,
                        args = {
                            messaging = {
                                type = "group", name = "ui.chat.message_tools", order = 0, inline = true,
                                args = {
                            foreign_faction_filter = {
                                type = "toggle",
                                name = L and (L["Foreign_Faction_Chat_Filter"] or SarychUI:T("ui.options_287d5be978")) or SarychUI:T("ui.options_287d5be978"),
                                desc = L and (L["Foreign_Faction_Chat_Filter_Desc"] or SarychUI:T("ui.options_71e826e02f")) or SarychUI:T("ui.options_71e826e02f"),
                                order = 2,
                                width = "full",
                                get = function()
                                    return GetSetting("foreignFactionFilterEnabled", 0) == 1
                                end,
                                set = function(_, value)
                                    SarychUI.db.profile.modules[moduleName].foreignFactionFilterEnabled = value and 1 or 0
                                    module:ApplyForeignFactionFilterSettings()
                                end,
                            },
                                    shiftHistory = {
                                        type = "toggle", name = "ui.chat.shift_history", desc = "ui.chat.shift_history_desc",
                                        order = 3, width = "full",
                                        get = function() return GetSetting("shiftHistoryEnabled", false) end,
                                        set = function(_, value)
                                            SarychUI:GetModuleProfile(moduleName).shiftHistoryEnabled = value
                                            module:ApplyShiftHistorySettings()
                                        end,
                                    },
                                },
                            },
                            copyBox = {
                                type = "group",
                                name = "ui.copy_cde00b19",
                                order = 1,
                                inline = true,
                                args = {
                                    copyOnCtrlClickEnabled = {
                                        type = "toggle",
                                        name = "ui.ctrl_left_click_a_tab_cffffd700copy_window_r_c5fa7205",
                                        desc = "ui.enable_chat_copy_via_ctrl_left_click_on_a_chat_t_be335f9e",
                                        order = 1,
                                        width = "full",
                                        get = function()
                                            return GetSetting("copyOnCtrlClickEnabled", 1) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].copyOnCtrlClickEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChatCopyingSettings()
                                            end
                                        end,
                                    },
                                    urlCopyingEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Chat_URL_Copying"] or SarychUI:T("ui.options_a2b2aa3e54")) or SarychUI:T("ui.options_a2b2aa3e54"),
                                        desc = L and (L["Enable_Chat_URL_Copying_Desc"] or SarychUI:T("ui.options_3bec05c3d6")) or SarychUI:T("ui.options_3bec05c3d6"),
                                        order = 2,
                                        width = "full",
                                        get = function()
                                            return GetSetting("urlCopyingEnabled", 1) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].urlCopyingEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                        end,
                                    },
                                },
                            },
                            scrollBox = {
                                type = "group",
                                name = "ui.fast_scroll_293951b5",
                                order = 2,
                                inline = true,
                                args = {
                                    fastScrollEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Fast_Scroll"] or SarychUI:T("ui.options_66314c66d1")) or SarychUI:T("ui.options_66314c66d1"),
                                        desc = L and (L["Enable_Fast_Scroll_Desc"] or SarychUI:T("ui.options_915933d44c")) or SarychUI:T("ui.options_915933d44c"),
                                        order = 1,
                                        width = "full",
                                        get = function()
                                            return GetSetting("fastScrollEnabled", 1) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].fastScrollEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                        end,
                                    },
                                    fastScrollSteps = {
                                        type = "range",
                                        name = L and (L["Fast_Scroll_Steps"] or SarychUI:T("ui.options_26413deed0")) or SarychUI:T("ui.options_26413deed0"),
                                        desc = L and (L["Fast_Scroll_Steps_Desc"] or SarychUI:T("ui.options_0c41ed0f37")) or SarychUI:T("ui.options_0c41ed0f37"),
                                        order = 2,
                                        min = 1,
                                        max = 20,
                                        step = 1,
                                        get = function()
                                            return GetSetting("fastScrollSteps", 5)
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].fastScrollSteps = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyFastScrollSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("fastScrollEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- Data bar tab
                    dataBar = {
                        type = "group",
                        name = "ui.chat.data_bar",
                        order = 4,
                        args = {
                            dataBarEnabled = {
                                type = "toggle",
                                name = "ui.chat.data_bar.enabled",
                                desc = "ui.chat.data_bar.desc",
                                order = 1,
                                width = "full",
                                get = function()
                                    return GetSetting("dataBarEnabled", 0) == 1
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules[moduleName].dataBarEnabled = value and 1 or 0
                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                        SarychUI.modules[moduleName]:ApplyDataBarSettings()
                                    elseif _G.ApplyDataBarSettings then
                                        _G.ApplyDataBarSettings()
                                    end
                                    RefreshChatOptionsPanel()
                                end,
                            },
                            dataBarDetails = {
                                type = "group",
                                name = "",
                                order = 2,
                                inline = true,
                                hidden = function() return GetSetting("dataBarEnabled", 0) ~= 1 end,
                                args = {
                                    left = DataBarRegionOptions("left", "ui.chat.data_bar.left", "Memory", 1),
                                    middle = DataBarRegionOptions("middle", "ui.chat.data_bar.middle", "MS", 2),
                                    right = DataBarRegionOptions("right", "ui.chat.data_bar.right", "FPS", 3),
                                },
                            },
                        },
                    },
                },
            },

            -- Appearance Tab
            appearance = {
                type = "group",
                name = L and (L["Chat_Appearance"] or SarychUI:T("ui.appearance_c407960b")) or SarychUI:T("ui.appearance_c407960b"),
                order = 3,
                disabled = function() return not isEnabled() end,
                childGroups = "tab",
                args = {
                    -- Chat Window tab
                    chat_window = {
                        type = "group",
                        name = "ui.chat_window_f5d1e5ea",
                        order = 1,
                        args = {
                            fadingBox = {
                                type = "group",
                                name = "ui.text_fade_out_695d55d7",
                                order = 1,
                                inline = true,
                                args = {
                                    visibleSecondsEnabled = {
                                        type = "toggle",
                                        name = "ui.enable_chat_fade_out_f1a4afbf",
                                        desc = "ui.enable_automatic_chat_text_fade_out_d1d0f30b",
                                        order = 1,
                                        width = "full",
                                        get = function() return GetSetting("visibleSecondsEnabled", 1) == 1 end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].visibleSecondsEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                        end,
                                    },
                                    visibleSeconds = {
                                        type = "range",
                                        name = L and (L["Visible_Seconds"] or SarychUI:T("ui.options_7fc8dae3df")) or SarychUI:T("ui.options_7fc8dae3df"),
                                        desc = "ui.how_long_chat_messages_stay_visible_seconds_37bc27b4",
                                        order = 2,
                                        width = "full",
                                        min = 1, max = 120, step = 1,
                                        disabled = function() return GetSetting("visibleSecondsEnabled", 1) ~= 1 end,
                                        get = function() return GetSetting("visibleSeconds", 7) end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].visibleSeconds = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                        end,
                                    },
                                },
                            },
                            lookBox = {
                                type = "group",
                                name = "ui.appearance_c407960b",
                                order = 2,
                                inline = true,
                                args = {
                                    friendsButtonModEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Friends_Button_Mod"] or SarychUI:T("ui.options_2e92adf083")) or SarychUI:T("ui.options_2e92adf083"),
                                        desc = L and (L["Enable_Friends_Button_Mod_Desc"] or SarychUI:T("ui.options_56c8918665")) or SarychUI:T("ui.options_56c8918665"),
                                        order = 1,
                                        width = "full",
                                        get = function()
                                            return GetSetting("friendsButtonModEnabled", 1) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].friendsButtonModEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                        end,
                                    },
                                    hideChatFrameButtonEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Hide_Chat_Frame_Button"] or SarychUI:T("ui.options_ffa0545d8e")) or SarychUI:T("ui.options_ffa0545d8e"),
                                        desc = L and (L["Enable_Hide_Chat_Frame_Button_Desc"] or SarychUI:T("ui.options_e797c4c765")) or SarychUI:T("ui.options_e797c4c765"),
                                        order = 2,
                                        width = "full",
                                        get = function()
                                            return GetSetting("hideChatFrameButtonEnabled", 1) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].hideChatFrameButtonEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                            RefreshChatOptionsPanel()
                                        end,
                                    },
                                    chatFrameButtonBox = {
                                        type = "group",
                                        name = "",
                                        order = 2.1,
                                        inline = true,
                                        hidden = function() return GetSetting("hideChatFrameButtonEnabled", 1) ~= 1 end,
                                        args = {
                                            altDefault = {
                                                type = "toggle",
                                                name = L and (L["Chat_Menu_Button_Alt_Default"] or SarychUI:T("ui.options_44ede853de")) or SarychUI:T("ui.options_44ede853de"),
                                                desc = L and (L["Chat_Menu_Button_Alt_Default_Desc"] or SarychUI:T("ui.options_b76c9ee681")) or SarychUI:T("ui.options_b76c9ee681"),
                                                order = 2,
                                                width = "full",
                                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                                get = function()
                                                    return GetSetting("chatFrameButtonAltDefaultEnabled", 1) == 1
                                                end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].chatFrameButtonAltDefaultEnabled = value and 1 or 0
                                                    if _G.FB_SyncAltNow then _G.FB_SyncAltNow() end
                                                end,
                                                hidden = function()
                                                    return GetSetting("hideChatFrameButtonEnabled", 1) ~= 1
                                                end,
                                                disabled = function()
                                                    return GetSetting("hideChatFrameButtonEnabled", 1) ~= 1
                                                end,
                                            },
                                        },
                                    },
                                    hideChatScrollButtonsEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Hide_Chat_Scroll_Buttons"] or SarychUI:T("ui.options_9390287d0c")) or SarychUI:T("ui.options_9390287d0c"),
                                        desc = L and (L["Enable_Hide_Chat_Scroll_Buttons_Desc"] or SarychUI:T("ui.options_0b5c5552ef")) or SarychUI:T("ui.options_0b5c5552ef"),
                                        order = 3,
                                        width = "full",
                                        get = function()
                                            return GetSetting("hideChatScrollButtonsEnabled", 1) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].hideChatScrollButtonsEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                        end,
                                    },
                                    hideChatBottomButtonEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Hide_Chat_Bottom_Button"] or SarychUI:T("ui.options_e19035f734")) or SarychUI:T("ui.options_e19035f734"),
                                        desc = L and (L["Enable_Hide_Chat_Bottom_Button_Desc"] or SarychUI:T("ui.options_9b9c1da045")) or SarychUI:T("ui.options_9b9c1da045"),
                                        order = 4,
                                        width = "full",
                                        get = function()
                                            return GetSetting("hideChatBottomButtonEnabled", 1) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].hideChatBottomButtonEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                        end,
                                    },
                                    tabsStyleEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Chat_Tabs_Style"] or SarychUI:T("ui.options_bf780a4030")) or SarychUI:T("ui.options_bf780a4030"),
                                        desc = L and (L["Enable_Chat_Tabs_Style_Desc"] or SarychUI:T("ui.options_44276bef65")) or SarychUI:T("ui.options_44276bef65"),
                                        order = 5,
                                        width = "full",
                                        get = function()
                                            return GetSetting("tabsStyleEnabled", 0) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].tabsStyleEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                            if _G.ApplyTabsStyle then
                                                _G.ApplyTabsStyle()
                                            end
                                            SuiTimer.After(0.1, function()
                                                if _G.ApplyTabsStyle then
                                                    _G.ApplyTabsStyle()
                                                end
                                            end)
                                        end,
                                    },
                                },
                            },
                            animBox = {
                                type = "group",
                                name = "ui.chat_animations_d31a304f",
                                order = 3,
                                inline = true,
                                args = {
                                    chatAnimationsEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Chat_Animations"] or SarychUI:T("ui.options_57ef6e5c13")) or SarychUI:T("ui.options_57ef6e5c13"),
                                        desc = L and (L["Enable_Chat_Animations_Desc"] or SarychUI:T("ui.options_432b603aca")) or SarychUI:T("ui.options_432b603aca"),
                                        order = 1,
                                        width = "full",
                                        get = function()
                                            return GetSetting("chatAnimationsEnabled", 0) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].chatAnimationsEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                            RefreshChatOptionsPanel()
                                        end,
                                    },
                                    animationTimings = {
                                        type = "group",
                                        name = "",
                                        order = 2,
                                        inline = true,
                                        hidden = function() return GetSetting("chatAnimationsEnabled", 0) ~= 1 end,
                                        args = {
                                            chatTabShowDelay = {
                                                type = "range",
                                                name = L and (L["Chat_Tab_Show_Delay"] or SarychUI:T("ui.options_2b044f3b8c")) or SarychUI:T("ui.options_2b044f3b8c"),
                                                desc = L and (L["Chat_Tab_Show_Delay_Desc"] or SarychUI:T("ui.options_37578788b5")) or SarychUI:T("ui.options_37578788b5"),
                                                order = 2,
                                                width = "full",
                                                min = 0,
                                                max = 2,
                                                step = 0.01,
                                                get = function()
                                                    return GetSetting("chatTabShowDelay", 0.0)
                                                end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].chatTabShowDelay = value
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyAllSettings()
                                                    end
                                                end,
                                            },
                                            chatTabHideDelay = {
                                                type = "range",
                                                name = L and (L["Chat_Tab_Hide_Delay"] or SarychUI:T("ui.options_e5c6dc8c32")) or SarychUI:T("ui.options_e5c6dc8c32"),
                                                desc = L and (L["Chat_Tab_Hide_Delay_Desc"] or SarychUI:T("ui.options_75a97fa7fd")) or SarychUI:T("ui.options_75a97fa7fd"),
                                                order = 3,
                                                width = "full",
                                                min = 0,
                                                max = 5,
                                                step = 0.01,
                                                get = function()
                                                    return GetSetting("chatTabHideDelay", 0.0)
                                                end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].chatTabHideDelay = value
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyAllSettings()
                                                    end
                                                end,
                                            },
                                            chatFrameFadeTime = {
                                                type = "range",
                                                name = "ui.chat_fade_in_animation_duration_sec_e068c480",
                                                desc = "ui.chat_fade_in_animation_duration_a76e4b0f",
                                                order = 4,
                                                width = "full",
                                                min = 0,
                                                max = 1,
                                                step = 0.01,
                                                get = function()
                                                    return GetSetting("chatFrameFadeTime", 0.10)
                                                end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].chatFrameFadeTime = value
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyAllSettings()
                                                    end
                                                end,
                                            },
                                            chatFrameFadeOutTime = {
                                                type = "range",
                                                name = "ui.chat_fade_out_animation_duration_sec_f2bee419",
                                                desc = "ui.chat_fade_out_animation_duration_66f69bc3",
                                                order = 5,
                                                width = "full",
                                                min = 0,
                                                max = 5,
                                                step = 0.01,
                                                get = function()
                                                    return GetSetting("chatFrameFadeOutTime", 0.15)
                                                end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].chatFrameFadeOutTime = value
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyAllSettings()
                                                    end
                                                end,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },

                    -- Tooltip tab
                    tooltip = {
                        type = "group",
                        name = "ui.chat_tooltip_window_373a9c2a",
                        order = 2,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiPreview = "ChatTooltipPreview",
                            },
                            iconsBox = {
                                type = "group",
                                name = "ui.icons_f52d3f2f",
                                order = 1,
                                inline = true,
                                args = {
                                    itemRefIconsEnabled = {
                                        type = "toggle",
                                        name = "ui.enable_icons_in_the_tooltip_window_93f56a27",
                                        desc = L and (L["Enable_Chat_Icons_Desc"] or SarychUI:T("ui.options_b6685a2624")) or SarychUI:T("ui.options_b6685a2624"),
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "itemRefIconsEnabled",
                                        get = function()
                                            return GetSetting("itemRefIconsEnabled", 1) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].itemRefIconsEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                            if SarychUI.ChatTooltipPreview then
                                                if SarychUI.ChatTooltipPreview.SetLiveValue then
                                                    SarychUI.ChatTooltipPreview:SetLiveValue("itemRefIconsEnabled", value and 1 or 0)
                                                elseif SarychUI.ChatTooltipPreview.RefreshAll then
                                                    SarychUI.ChatTooltipPreview:RefreshAll()
                                                end
                                            end
                                        end,
                                    },
                                },
                            },
                            tooltipBox = {
                                type = "group",
                                name = "ui.window_position_8bd803cf",
                                order = 2,
                                inline = true,
                                args = {
                                    tooltipPositionEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Tooltip_Position"] or SarychUI:T("ui.options_d87bcc3eca")) or SarychUI:T("ui.options_d87bcc3eca"),
                                        desc = L and (L["Enable_Tooltip_Position_Desc"] or SarychUI:T("ui.options_733f10ff49")) or SarychUI:T("ui.options_733f10ff49"),
                                        order = 1,
                                        width = "full",
                                        get = function()
                                            return GetSetting("tooltipPositionEnabled", 0) == 1
                                        end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].tooltipPositionEnabled = value and 1 or 0
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyAllSettings()
                                            end
                                            RefreshChatOptionsPanel()
                                        end,
                                    },
                                    tooltipOffsets = {
                                        type = "group",
                                        name = "",
                                        order = 2,
                                        inline = true,
                                        args = {
                                            tooltipBaseOffset = {
                                                type = "range",
                                                name = "ui.base_y_offset_2476b6cb",
                                                desc = "ui.base_tooltip_window_y_offset_e3188c0c",
                                                order = 2,
                                                min = -100,
                                                max = 100,
                                                step = 1,
                                                disabled = function() return GetSetting("tooltipPositionEnabled", 0) ~= 1 end,
                                                get = function()
                                                    return GetSetting("tooltipBaseOffset", 20)
                                                end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].tooltipBaseOffset = value
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyAllSettings()
                                                    end
                                                end,
                                            },
                                            tooltipPetOffset = {
                                                type = "range",
                                                name = "ui.y_offset_with_pet_bar_772d6200",
                                                desc = "ui.extra_tooltip_y_offset_when_the_pet_action_bar_i_f25b3718",
                                                order = 3,
                                                min = -100,
                                                max = 100,
                                                step = 1,
                                                disabled = function() return GetSetting("tooltipPositionEnabled", 0) ~= 1 end,
                                                get = function()
                                                    return GetSetting("tooltipPetOffset", 40)
                                                end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].tooltipPetOffset = value
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyAllSettings()
                                                    end
                                                end,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    size_position = {
                        type = "group",
                        name = "ui.size_and_position_890068de",
                        order = 3,
                        args = {
                            position = {
                                type = "group",
                                name = "ui.text_bc003cf9",
                                order = 1,
                                inline = true,
                                suiTwoCol = true,
                                args = {
                                    x = {
                                        type = "range",
                                        name = "ui.position_x_b3623749",
                                        desc = "ui.text_5c197234",
                                        order = 1,
                                        min = 0, max = math.max(2000, (GetScreenWidth and GetScreenWidth()) or UIParent:GetWidth()), step = 1,
                                        get = function()
                                            local _, x = GetMainChatGeometry()
                                            return x or 0
                                        end,
                                        set = function(_, value) SetMainChatGeometry("x", value) end,
                                    },
                                    y = {
                                        type = "range",
                                        name = "ui.position_y_444abafa",
                                        desc = "ui.text_2d9e9482",
                                        order = 2,
                                        min = 0, max = math.max(1200, (GetScreenHeight and GetScreenHeight()) or UIParent:GetHeight()), step = 1,
                                        get = function()
                                            local _, _, y = GetMainChatGeometry()
                                            return y or 0
                                        end,
                                        set = function(_, value) SetMainChatGeometry("y", value) end,
                                    },
                                },
                            },
                            size = {
                                type = "group",
                                name = "ui.text_b03d525a",
                                order = 2,
                                inline = true,
                                suiTwoCol = true,
                                args = {
                                    width = {
                                        type = "range",
                                        name = "ui.width_a97d46cd",
                                        order = 1,
                                        min = 100, max = math.max(1200, (GetScreenWidth and GetScreenWidth()) or UIParent:GetWidth()), step = 1,
                                        get = function()
                                            local _, _, _, width = GetMainChatGeometry()
                                            return width or 400
                                        end,
                                        set = function(_, value) SetMainChatGeometry("width", value) end,
                                    },
                                    height = {
                                        type = "range",
                                        name = "ui.height_cc838507",
                                        order = 2,
                                        min = 50, max = math.max(800, (GetScreenHeight and GetScreenHeight()) or UIParent:GetHeight()), step = 1,
                                        get = function()
                                            local _, _, _, _, height = GetMainChatGeometry()
                                            return height or 150
                                        end,
                                        set = function(_, value) SetMainChatGeometry("height", value) end,
                                    },
                                },
                            },
                        },
                    },
                },
            },

            -- Spam Filter Tab
            spam_filter = {
                type = "group",
                name = L and (L["Chat_Spam_Filter"] or SarychUI:T("ui.options_cf2a460431")) or SarychUI:T("ui.options_cf2a460431"),
                order = 4,
                disabled = function() return not isEnabled() end,
                args = {
                    enableBox = {
                        type = "group",
                        name = " ",
                        order = 1,
                        inline = true,
                        args = {
                            spam_filter_enabled = {
                                type = "toggle",
                                name = L and (L["Enable_Chat_Spam_Filter"] or SarychUI:T("ui.options_260257f93a")) or SarychUI:T("ui.options_260257f93a"),
                                desc = L and (L["Enable_Chat_Spam_Filter_Desc"] or SarychUI:T("ui.options_7bf08b7963")) or SarychUI:T("ui.options_7bf08b7963"),
                                order = 1,
                                width = "full",
                                get = function()
                                    return GetSetting("spamFilterEnabled", 1) == 1
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules[moduleName].spamFilterEnabled = value and 1 or 0
                                    module:ApplyAllSettings()
                                    RefreshChatOptionsPanel()
                                end,
                            },

                        },
                    },
                    listBox = {
                        type = "group",
                        name = "ui.filter_list_fd691308",
                        order = 2,
                        inline = true,
                        disabled = function() return GetSetting("spamFilterEnabled", 1) ~= 1 end,
                        args = {}, -- filled below via BuildSpamFilterListArgs()
                    },
                    resetBox = {
                        type = "group",
                        name = " ",
                        order = 3,
                        inline = true,
                        args = {
                            spam_filter_reset = {
                                type = "execute",
                                name = function()
                                    local enabled = GetSetting("spamFilterEnabled", 1) == 1
                                    local resetText = L and (L["Reset_Filters"] or SarychUI:T("ui.options_03ead01c5b")) or SarychUI:T("ui.options_03ead01c5b")
                                    return enabled and "|cFFFFD700" .. resetText .. "|r" or resetText
                                end,
                                desc = L and (L["Reset_Filters_Desc"] or SarychUI:T("ui.options_1d7ef1566c")) or SarychUI:T("ui.options_1d7ef1566c"),
                                order = 1,
                                width = "full",
                                disabled = function() return GetSetting("spamFilterEnabled", 1) ~= 1 end,
                                func = function()
                                    local defaultList = {}
                                    for i, pattern in ipairs(SarychUI.ChatSpamDefaults or {}) do
                                        defaultList[i] = pattern
                                    end
                                    SarychUI.db.profile.modules[moduleName].spamEnabledList = defaultList
                                    SarychUI.db.profile.modules[moduleName].spamCustomList = {}
                                    SarychUI.db.profile.modules[moduleName].spamDeletedList = {}
                                    module:ApplyAllSettings()
                                    RefreshChatOptionsPanel()
                                end,
                            },
                        },
                    },
                },
            },

            chat_wheel = {
                type = "group",
                name = L and (L["Chat_Wheel"] or SarychUI:T("ui.options_a94a7247c6")) or SarychUI:T("ui.options_a94a7247c6"),
                order = 5,
                disabled = function() return not isEnabled() end,
                args = {
                    enableBox = {
                        type = "group",
                        name = " ",
                        order = 1,
                        inline = true,
                        args = {
                            chat_wheel_enabled = {
                                type = "toggle",
                                name = "ui.enable_chat_wheel_2bf2f8fd",
                                desc = "ui.enables_a_dota_style_chat_wheel_hold_the_bound_k_72ec1976",
                                order = 1,
                                width = "full",
                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return cw and (cw.enabled == 1 or cw.enabled == true)
                                end,
                                set = function(info, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    if type(db.chatWheel) ~= "table" then
                                        local def = SarychUI.defaults.profile.modules.chat.chatWheel
                                        db.chatWheel = def and CopyTable(def) or {}
                                    end
                                    db.chatWheel.enabled = value and 1 or 0
                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                        SarychUI.modules[moduleName]:ApplyChatWheelSettings()
                                    end
                                    RefreshChatOptionsPanel()
                                end,
                            },
                            chat_wheel_enable_image = {
                                type = "description",
                                name = "",
                                order = 1.5,
                                width = "full",
                                image = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\settings_chatwheel",
                                disabled = function() return not ChatWheelModuleEnabled() end,
                                imageWidth = 100,
                                imageHeight = 100,
                                imageAlign = "CENTER",
                            },
                            chat_wheel_key = {
                                hidden = function() return not ChatWheelModuleEnabled() end,
                                type = "keybinding",
                                name = "ui.chat_wheel_keybind_282669b7",
                                desc = "ui.hold_this_keybind_to_open_the_wheel_release_to_c_f6a076a3",
                                order = 2,
                                width = "full",
                                disabled = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return not cw or (cw.enabled ~= 1 and cw.enabled ~= true)
                                end,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return cw and cw.key or nil
                                end,
                                set = function(info, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    if type(db.chatWheel) ~= "table" then
                                        local def = SarychUI.defaults.profile.modules.chat.chatWheel
                                        db.chatWheel = def and CopyTable(def) or {}
                                    end
                                    db.chatWheel.key = value
                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                        SarychUI.modules[moduleName]:ApplyChatWheelSettings()
                                    end
                                end,
                            },
                            chat_wheel_always_show = {
                                type = "toggle",
                                name = "ui.always_show_the_wheel_e2b56611",
                                desc = "ui.keep_the_wheel_on_screen_permanently_useful_for__177c09fe",
                                order = 3,
                                width = "full",
                                hidden = true,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return cw and (cw.alwaysShow == 1 or cw.alwaysShow == true)
                                end,
                                set = function(info, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    if type(db.chatWheel) ~= "table" then
                                        local def = SarychUI.defaults.profile.modules.chat.chatWheel
                                        db.chatWheel = def and CopyTable(def) or {}
                                    end
                                    db.chatWheel.alwaysShow = value and 1 or 0
                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                        SarychUI.modules[moduleName]:ApplyChatWheelSettings()
                                    end
                                end,
                                disabled = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return not cw or (cw.enabled ~= 1 and cw.enabled ~= true)
                                end,
                            },
                            chat_wheel_desc = {
                                hidden = function() return not ChatWheelModuleEnabled() end,
                                type = "description",
                                name = "ui.cffffd700tip_r_hold_the_keybind_to_open_the_whee_f059017d",
                                order = 4,
                                fontSize = "medium",
                            },
                        },
                    },
                    displayBox = {
                        hidden = function() return not ChatWheelModuleEnabled() end,
                        type = "group",
                        name = "ui.send_channel_d03792b0",
                        order = 2,
                        inline = true,
                        args = {
                            chat_wheel_channel_mode = {
                                type = "select",
                                name = "ui.send_channel_d03792b0",
                                desc = "ui.where_to_send_the_phrase_on_keybind_release_adap_f607e4eb",
                                order = 1,
                                width = "full",
                                values = {
                                    adaptive = SarychUI:T("ui.options_b36ea3e548"),
                                    say = SarychUI:T("ui.options_8c8b441c9c"),
                                    party = SarychUI:T("ui.options_3c9abba8b9"),
                                    raid = SarychUI:T("ui.options_00aa846cfd"),
                                    guild = SarychUI:T("ui.options_510188017f"),
                                    yell = SarychUI:T("ui.options_28a19844a0"),
                                    emote = SarychUI:T("ui.options_5e6790b8cd"),
                                },
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return cw and cw.chatWheelChannelMode or "adaptive"
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    EnsureChatWheelDb(db)
                                    db.chatWheel.chatWheelChannelMode = value
                                    if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.RefreshPhraseChannelColors then
                                        _G.SarychUI_ChatWheel.RefreshPhraseChannelColors()
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                        },
                    },
                },
            },

        },
    }

    local channelArgs = baseOptions.args.functionality.args.shortening.args.channelsBox.args
    local prefixHelp = SarychUI:T("ui.chat.prefix_help")
    for key, option in pairs(channelArgs) do
        if option.type == "input" then channelArgs[key] = nil end
    end
    local types = { "SAY", "YELL", "WHISPER", "WHISPER_INFORM", "GUILD", "OFFICER",
        "PARTY", "PARTY_LEADER", "PARTY_GUIDE", "RAID", "RAID_LEADER", "RAID_WARNING",
        "BATTLEGROUND", "BATTLEGROUND_LEADER" }
    for index, chatType in ipairs(types) do
        local key = module.channelFormatKeys[chatType]
        local label = module:GetChannelFormatLabel(chatType)
        if label and label ~= "" then
            channelArgs["format_" .. chatType] = {
                type = "input", name = label, desc = prefixHelp, order = index + 2,
                width = "full", suiSaveButton = "OK", suiKeepInput = true,
                get = function() return GetSetting(key, "") end,
                set = function(_, value)
                    SarychUI:GetModuleProfile(moduleName)[key] = tostring(value or ""):match("^%s*(.-)%s*$")
                    module:ApplyChannelShorteningSettings()
                end,
                hidden = function() return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled() end,
            }
        end
    end
    local channels = module:GetJoinedChannels()
    module.channelOptionsBuilt = true
    module.channelOptionsSignature = table.concat(channels, "\001")
    for index = 1, #channels, 2 do
        local number, fullName = channels[index], channels[index + 1]
        local channelName = module:GetChannelBaseName(fullName)
        channelArgs["channel_" .. number] = {
            type = "input", name = "[" .. number .. ". " .. fullName .. "]", order = 20 + number,
            desc = prefixHelp .. SarychUI:T("ui.chat.channel_number_hint"),
            width = "full", suiSaveButton = "OK", suiKeepInput = true,
            get = function() return module:GetChannelOverride(channelName) end,
            set = function(_, value)
                local db = SarychUI:GetModuleProfile(moduleName)
                db.channelAbbreviations = db.channelAbbreviations or {}
                db.channelAbbreviations[module:GetChannelStorageKey(channelName)] = tostring(value or ""):match("^%s*(.-)%s*$")
                module:ApplyChannelShorteningSettings()
            end,
            hidden = function() return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled() end,
        }
    end

    baseOptions.args.spam_filter.args.listBox.args = BuildSpamFilterListArgs()

    local phraseOpts = BuildChatWheelPhraseOptionEntries()
    local cwArgs = baseOptions.args.chat_wheel.args
    for key, option in pairs(phraseOpts) do
        cwArgs[key] = option
    end

    return baseOptions
end
