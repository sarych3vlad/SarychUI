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

local SPAM_DEFAULT_LIST = {
    "[Анонс БГ]", "Авто-объявление", "Рейтинговое поле боя",
    "Welcome to World of Warcraft Server - WoW Circle",
    "На этой неделе доступен Наксрамас на героической сложности!",
    "Отключить путешествия во времени по подземельям Короля Лича",
    "В личном кабинете имеется магазин, в котором вы можете воспользоваться множеством услуг, счет бонусов можно пополнить множеством разных способов",
    "Наши официальные веб ресурсы",
    "Если у вашего персонажа появилась какая-то проблема, то сначала воспользуйтесь услугой AntiError в личном кабинете, а только потом пишите на форум",
    "Вы можете голосовать за сервер в личном кабинете",
    "Остерегайтесь подделок! Все актуальные адреса личных кабинетов находятся на нашем главном сайте",
    "Если Вы испытываете проблемы, когда квестовый предмет долго не выпадает с моба",
    "Ознакомьтесь пожалуйста с темой",
    "За битву на рейтинговом поле боя ты можешь получить боевые монеты! Надо торопиться, это долго не продлится!",
    "Перед завершением торговли пожалуйста проверьте передаваемые предметы и количество золота",
    "На этой неделе доступно Плато Солнечного Колодца на героической сложности!",
}

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
            print("|cffffd200SarychUI Chat:|r Фильтр уже существует: " .. trimmed)
            return false
        end
    end

    local enabledList = GetSetting("spamEnabledList", {})
    local customList = GetSetting("spamCustomList", {})
    for _, filter in ipairs(enabledList) do
        if filter == trimmed then
            print("|cffffd200SarychUI Chat:|r Фильтр уже существует: " .. trimmed)
            return false
        end
    end

    tinsert(enabledList, trimmed)
    tinsert(customList, trimmed)
    SarychUI.db.profile.modules[moduleName].spamEnabledList = enabledList
    SarychUI.db.profile.modules[moduleName].spamCustomList = customList
    print("|cffffd200SarychUI Chat:|r Фильтр добавлен: " .. trimmed)
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
    print("|cffffd200SarychUI Chat:|r Фильтр удален: " .. pattern)
end

local function BuildSpamFilterListArgs()
    local args = {
        addInput = {
            type = "input",
            name = "",
            desc = "Текст сообщения (или его часть) для фильтрации",
            order = 1,
            width = "full",
            suiSaveButton = "Добавить",
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
                    name = "Удалить",
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
        local defaultText = CHAT_WHEEL_PHRASE_DEFAULTS[i] or ("Фраза " .. i)
        phraseArgs["chat_wheel_phrase_" .. i .. "_text"] = {
            type = "input",
            name = "Фраза " .. i .. " — текст",
            order = 1 + (i - 1) * 2,
            width = "full",
            suiSaveButton = "OK",
            suiKeepInput = true,
            get = function()
                local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                if not cw or cw[textKey] == nil then return defaultText end
                return cw[textKey]
            end,
            set = function(_, value)
                local db = SarychUI.db.profile.modules[moduleName]
                EnsureChatWheelDb(db)
                db.chatWheel[textKey] = value
                if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyPhrases then
                    _G.SarychUI_ChatWheel.ApplyPhrases()
                end
            end,
            disabled = function()
                return not ChatWheelModuleEnabled()
            end,
        }
        phraseArgs["chat_wheel_phrase_" .. i .. "_emote"] = {
            type = "input",
            name = "Фраза " .. i .. " — эмоция",
            desc = "Slash-команда после текста, например /dance или /танец",
            order = 2 + (i - 1) * 2,
            width = "full",
            suiSaveButton = "OK",
            suiKeepInput = true,
            get = function()
                local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                return cw and cw[emoteKey] or ""
            end,
            set = function(_, value)
                local db = SarychUI.db.profile.modules[moduleName]
                EnsureChatWheelDb(db)
                db.chatWheel[emoteKey] = value
            end,
            disabled = function()
                return not ChatWheelModuleEnabled()
            end,
        }
    end
    return {
        phraseTextsBox = {
            type = "group",
            name = "Тексты фраз",
            inline = true,
            order = 1.5,
            args = phraseArgs,
        },
    }
end

local function BuildChatWheelPhrasePositionEntries()
    local posArgs = {
        desc = {
            type = "description",
            name = "Дополнительное смещение поверх базовой позиции по кругу (phraseDistance + угол).",
            order = 1,
            fontSize = "medium",
        },
    }
    for i = 1, 8 do
        local xKey = "phrase" .. i .. "X"
        local yKey = "phrase" .. i .. "Y"
        posArgs["chat_wheel_phrase_" .. i .. "_x"] = {
            type = "range",
            name = "Фраза " .. i .. " — X",
            order = 2 + (i - 1) * 2,
            min = -400,
            max = 400,
            step = 1,
            get = function()
                local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                return cw and cw[xKey] or 0
            end,
            set = function(_, value)
                local db = SarychUI.db.profile.modules[moduleName]
                EnsureChatWheelDb(db)
                db.chatWheel[xKey] = value
                if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyPhrases then
                    _G.SarychUI_ChatWheel.ApplyPhrases()
                end
            end,
            disabled = function()
                return not ChatWheelModuleEnabled()
            end,
        }
        posArgs["chat_wheel_phrase_" .. i .. "_y"] = {
            type = "range",
            name = "Фраза " .. i .. " — Y",
            order = 3 + (i - 1) * 2,
            min = -400,
            max = 400,
            step = 1,
            get = function()
                local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                return cw and cw[yKey] or 0
            end,
            set = function(_, value)
                local db = SarychUI.db.profile.modules[moduleName]
                EnsureChatWheelDb(db)
                db.chatWheel[yKey] = value
                if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyPhrases then
                    _G.SarychUI_ChatWheel.ApplyPhrases()
                end
            end,
            disabled = function()
                return not ChatWheelModuleEnabled()
            end,
        }
    end
    return {
        phrasePositionsBox = {
            type = "group",
            name = "Позиции фраз",
            inline = true,
            order = 40,
            args = posArgs,
        },
    }
end

-- Get options
function module:GetOptions()
    local baseOptions = {
        type = "group",
        name = L and (L["Chat"] or "Окно чата") or "Окно чата",
        desc = L and (L["Chat_Description"] or "Настройка чата и сообщений") or "Настройка чата и сообщений",
        childGroups = "tab",
        args = {
            -- General Tab (enable only — WrapModuleOptionsWithEnableHeader
            -- lifts it to the title bar and removes this empty tab)
            general = {
                type = "group",
                name = "Общее",
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L and (L["Enable_Module"] or "Включить модуль") or "Включить модуль",
                        desc = "Включить или выключить модуль",
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
                name = L and (L["Functionality"] or "Функционал") or "Функционал",
                order = 2,
                disabled = function() return not isEnabled() end,
                childGroups = "tab",
                args = {
                    -- Management tab
                    management = {
                        type = "group",
                        name = "Общее",
                        order = 1,
                        args = {
                            generalBox = {
                                type = "group",
                                name = "Основные",
                                order = 1,
                                inline = true,
                                args = {
                                    enableChatTabFontSizeMenu = {
                                        type = "toggle",
                                        name = "Размер шрифта в меню вкладки чата",
                                        desc = "Добавляет в меню вкладки чата выбор размера шрифта от 6 до 20.",
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
                                        name = "Показывать оставшиеся символы в строке чата",
                                        desc = "Показывает количество оставшихся символов при вводе сообщения в чат.",
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
                            emojiBox = {
                                type = "group",
                                name = "Эмодзи",
                                order = 2,
                                inline = true,
                                suiHeaderIcon = "Interface\\AddOns\\SarychUI\\media\\chat_emojis\\emoticons.dxt5.blp",
                                args = {
                                    emotionIcons = {
                                        type = "toggle",
                                        name = "Включить эмодзи",
                                        desc = "Заменяет текстовые смайлики в чате на иконки.",
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
                                        end,
                                    },
                                    emotionBubbles = {
                                        type = "toggle",
                                        name = "Эмодзи в облачках над персонажами",
                                        desc = "Заменяет смайлики на иконки в облачках речи над персонажами.\n\n|cffff8080Влияет на производительность:|r облачка — безымянные фреймы без событий, поэтому их приходится искать постоянным опросом WorldFrame несколько раз в секунду. В людных местах это заметно нагружает процессор. В самом чате эмодзи работают без этой платы.",
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
                                        disabled = function() return GetSetting("emotionIcons", 1) ~= 1 end,
                                    },
                                    emotionPickerEnabled = {
                                        type = "toggle",
                                        name = "Показать кнопку выбора эмодзи",
                                        desc = "Показывает кнопку возле чата для открытия окна выбора эмодзи.",
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
                                        end,
                                    },
                                    emotionPickerTriggerEnabled = {
                                        type = "toggle",
                                        name = "Открывать эмодзи по триггеру",
                                        desc = "Открывает окно выбора эмодзи при вводе заданного текста в строку чата.",
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
                                        name = "Триггер открытия эмодзи",
                                        desc = "Когда этот текст есть в строке ввода, открывается окно выбора эмодзи. При выборе эмодзи триггер заменяется на его код.",
                                        order = 5,
                                        width = "full",
                                        get = function() return GetSetting("emotionPickerTrigger", "//") end,
                                        set = function(info, value)
                                            SarychUI.db.profile.modules[moduleName].emotionPickerTrigger = value or "//"
                                        end,
                                        disabled = function() return GetSetting("emotionPickerTriggerEnabled", 1) ~= 1 end,
                                    },
                                },
                            },
                            chatBarBox = {
                                type = "group",
                                name = "Панель чата",
                                order = 3,
                                inline = true,
                                args = {
                                    chatBarEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Chat_Bar"] or "Включить панель чата |cFFFFD700ChatBar|r") or "Включить панель чата |cFFFFD700ChatBar|r",
                                        desc = "Включить или выключить панель чата",
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
                                        name = L and (L["Show_Chat_Bar_On_Alt"] or "Скрыть и показывать при зажатии |cFFFFD700Alt|r") or "Скрывать и показывать при зажатии |cFFFFD700Alt|r",
                                        desc = "Показывать панель чата только при зажатии клавиши Alt",
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
                                name = "Горячие клавиши",
                                order = 4,
                                inline = true,
                                args = {
                                    chatHotkeysEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Chat_Hotkeys"] or "Включить горячие клавиши чата") or "Включить горячие клавиши чата",
                                        desc = "Включить или выключить все горячие клавиши чата",
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
                                    hotkeysYell = {
                                        type = "toggle",
                                        name = function()
                                            local color = "|cFFFFD700"
                                            return L and (L["Hotkey_Yell"] or color .. "Ctrl+Shift+Enter|r: Крик") or color .. "Ctrl+Shift+Enter|r: Крик"
                                        end,
                                        desc = "Включить горячую клавишу для крика в чате",
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
                                            local color = "|cFFFFD700"
                                            return L and (L["Hotkey_Say"] or color .. "Shift+Enter|r: Сказать") or color .. "Shift+Enter|r: Сказать"
                                        end,
                                        desc = "Включить горячую клавишу для обычного сообщения в чате",
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
                                            local color = "|cFFFFD700"
                                            return L and (L["Hotkey_Auto"] or color .. "Ctrl+Enter|r: Авто") or color .. "Ctrl+Enter|r: Авто"
                                        end,
                                        desc = "Включить горячую клавишу для автоматического выбора канала (группа/рейд/поле боя/арена)",
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

                    -- Chat Shortening tab
                    shortening = {
                        type = "group",
                        name = L and (L["Chat_Shortening"] or "Каналы") or "Каналы",
                        order = 2,
                        args = {
                            channelsBox = {
                                type = "group",
                                name = "Сокращения каналов",
                                order = 1,
                                inline = true,
                                args = {
                                    channelShorteningEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Channel_Shortening"] or "Включить сокращения каналов") or "Включить сокращения каналов",
                                        desc = L and (L["Enable_Channel_Shortening_Desc"] or "Включить или выключить сокращения названий каналов в чате") or "Включить или выключить сокращения названий каналов в чате",
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
                                    lfg_abbrev = {
                                        type = "input",
                                        name = L and (L["LFG_Abbreviation"] or "Поиск спутников") or "Поиск спутников",
                                        desc = L and (L["LFG_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
                                        order = 2,
                                        width = "full",
                                        suiSaveButton = "OK",
                                        suiKeepInput = true,
                                        get = function()
                                            return GetSetting("lfgAbbrev", "")
                                        end,
                                        set = function(info, value)
                                            if type(value) == "string" then
                                                value = value:match("^%s*(.-)%s*$") or ""
                                            else
                                                value = ""
                                            end
                                            SarychUI.db.profile.modules[moduleName].lfgAbbrev = value
                                            if SarychUI.modules and SarychUI.modules[moduleName] then
                                                SarychUI.modules[moduleName]:ApplyChannelShorteningSettings()
                                            end
                                        end,
                                        hidden = function()
                                            return GetSetting("channelShorteningEnabled", 1) ~= 1 or not isEnabled()
                                        end,
                                    },
                                    guild_abbrev = {
                                        type = "input",
                                        name = L and (L["Guild_Abbreviation"] or "Гильдия") or "Гильдия",
                                        desc = L and (L["Guild_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Officer_Abbreviation"] or "Офицеры") or "Офицеры",
                                        desc = L and (L["Officer_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Party_Abbreviation"] or "Группа") or "Группа",
                                        desc = L and (L["Party_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Raid_Abbreviation"] or "Рейд") or "Рейд",
                                        desc = L and (L["Raid_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Say_Abbreviation"] or "Обычный чат") or "Обычный чат",
                                        desc = L and (L["Say_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Yell_Abbreviation"] or "Крик") or "Крик",
                                        desc = L and (L["Yell_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Raid_Warning_Abbreviation"] or "Предупреждения рейда") or "Предупреждения рейда",
                                        desc = L and (L["Raid_Warning_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Battleground_Abbreviation"] or "Поле боя") or "Поле боя",
                                        desc = L and (L["Battleground_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Whisper_Abbreviation"] or "Личные сообщения") or "Личные сообщения",
                                        desc = L and (L["Whisper_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                                        name = L and (L["Emote_Abbreviation"] or "Эмоции") or "Эмоции",
                                        desc = L and (L["Emote_Abbreviation_Desc"] or "Пусто = название Blizzard. Ввод применяется кнопкой OK.") or "Пусто = название Blizzard. Ввод применяется кнопкой OK.",
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
                        name = "Дополнительно",
                        order = 3,
                        args = {
                            copyBox = {
                                type = "group",
                                name = "Копирование",
                                order = 1,
                                inline = true,
                                args = {
                                    copyOnCtrlClickEnabled = {
                                        type = "toggle",
                                        name = "Ctrl + левая кнопка мыши по вкладке – |cFFFFD700окно копирования|r",
                                        desc = "Включить копирование чата по Ctrl + левая кнопка мыши по вкладке чата",
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
                                        name = L and (L["Enable_Chat_URL_Copying"] or "Включить копирование ссылок URL") or "Включить копирование ссылок URL",
                                        desc = L and (L["Enable_Chat_URL_Copying_Desc"] or "Включить возможность копирования URL-адресов из чата") or "Включить возможность копирования URL-адресов из чата",
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
                                name = "Быстрая прокрутка",
                                order = 2,
                                inline = true,
                                args = {
                                    fastScrollEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Fast_Scroll"] or "Включить быструю прокрутку при зажатом Shift") or "Включить быструю прокрутку при зажатом Shift",
                                        desc = L and (L["Enable_Fast_Scroll_Desc"] or "Включить быструю прокрутку чата при зажатой клавише Shift") or "Включить быструю прокрутку чата при зажатой клавише Shift",
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
                                        name = L and (L["Fast_Scroll_Steps"] or "Количество шагов") or "Количество шагов",
                                        desc = L and (L["Fast_Scroll_Steps_Desc"] or "Количество шагов для быстрой прокрутки") or "Количество шагов для быстрой прокрутки",
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
                },
            },

            -- Appearance Tab
            appearance = {
                type = "group",
                name = L and (L["Chat_Appearance"] or "Внешний вид") or "Внешний вид",
                order = 3,
                disabled = function() return not isEnabled() end,
                childGroups = "tab",
                args = {
                    -- Chat Window tab
                    chat_window = {
                        type = "group",
                        name = "Окно чата",
                        order = 1,
                        args = {
                            fadingBox = {
                                type = "group",
                                name = "Исчезновение текста",
                                order = 1,
                                inline = true,
                                args = {
                                    visibleSecondsEnabled = {
                                        type = "toggle",
                                        name = "Включить исчезновение чата",
                                        desc = "Включить автоматическое исчезновение текста чата",
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
                                        name = L and (L["Visible_Seconds"] or "Время видимости (сек)") or "Время видимости (сек)",
                                        desc = "Время, в течение которого сообщения чата будут видны (в секундах)",
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
                                name = "Внешний вид",
                                order = 2,
                                inline = true,
                                args = {
                                    friendsButtonModEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Friends_Button_Mod"] or "|TInterface\\CHATFRAME\\UI-ChatIcon-BattleBro-Up:15.3:15.3:0:0|t Скрыть кнопку друзей") or "|TInterface\\CHATFRAME\\UI-ChatIcon-BattleBro-Up:15.3:15.3:0:0|t Скрыть кнопку друзей",
                                        desc = L and (L["Enable_Friends_Button_Mod_Desc"] or "Скрыть кнопку друзей в чате") or "Скрыть кнопку друзей в чате",
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
                                    chatFrameButtonBox = {
                                        type = "group",
                                        name = L and (L["Enable_Hide_Chat_Frame_Button_Tittle"] or "Скрыть кнопку общения") or "Скрыть кнопку общения",
                                        order = 2,
                                        inline = true,
                                        args = {
                                            enabled = {
                                                type = "toggle",
                                                name = L and (L["Enable_Hide_Chat_Frame_Button"] or "|TInterface\\CHATFRAME\\UI-ChatIcon-Chat-Up:15.3:15.3:0:0|t Скрыть кнопку общения") or "|TInterface\\CHATFRAME\\UI-ChatIcon-Chat-Up:15.3:15.3:0:0|t Скрыть кнопку общения",
                                                desc = L and (L["Enable_Hide_Chat_Frame_Button_Desc"] or "Скрыть кнопку общения в чате") or "Скрыть кнопку общения в чате",
                                                order = 1,
                                                width = "full",
                                                get = function()
                                                    return GetSetting("hideChatFrameButtonEnabled", 1) == 1
                                                end,
                                                set = function(info, value)
                                                    SarychUI.db.profile.modules[moduleName].hideChatFrameButtonEnabled = value and 1 or 0
                                                    if SarychUI.modules and SarychUI.modules[moduleName] then
                                                        SarychUI.modules[moduleName]:ApplyAllSettings()
                                                    end
                                                end,
                                            },
                                            altDefault = {
                                                type = "toggle",
                                                name = L and (L["Chat_Menu_Button_Alt_Default"] or "Показывать кнопку общения при зажатии |cFFFFD700Alt|r") or "Показывать кнопку общения при зажатии |cFFFFD700Alt|r",
                                                desc = L and (L["Chat_Menu_Button_Alt_Default_Desc"] or "Пока удерживается |cFFFFD700Alt|r, кнопка общения будет в стандартном состоянии и месте. При отпускании вернётся к настройке скрытия.") or "Пока удерживается |cFFFFD700Alt|r, кнопка общения будет в стандартном состоянии и месте. При отпускании вернётся к настройке скрытия.",
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
                                        name = L and (L["Enable_Hide_Chat_Scroll_Buttons"] or "|TInterface\\CHATFRAME\\UI-ChatIcon-ScrollUp-Up:18:18:0:0|t Скрыть стрелки вверх и вниз") or "|TInterface\\CHATFRAME\\UI-ChatIcon-ScrollUp-Up:18:18:0:0|t Скрыть стрелки вверх и вниз",
                                        desc = L and (L["Enable_Hide_Chat_Scroll_Buttons_Desc"] or "Скрыть стрелки прокрутки вверх и вниз в чате") or "Скрыть стрелки прокрутки вверх и вниз в чате",
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
                                        name = L and (L["Enable_Hide_Chat_Bottom_Button"] or "|TInterface\\CHATFRAME\\UI-ChatIcon-ScrollEnd-Up:18:18:0:0|t Скрыть стрелку перемещения в конец") or "|TInterface\\CHATFRAME\\UI-ChatIcon-ScrollEnd-Up:18:18:0:0|t Скрыть стрелку перемещения в конец",
                                        desc = L and (L["Enable_Hide_Chat_Bottom_Button_Desc"] or "Скрыть стрелку перемещения в конец чата") or "Скрыть стрелку перемещения в конец чата",
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
                                        name = L and (L["Enable_Chat_Tabs_Style"] or "|TInterface\\CHATFRAME\\ChatFrameTab:16:32:0:0|t Изменить внешний вид вкладок чата") or "|TInterface\\CHATFRAME\\ChatFrameTab:16:32:0:0|t Изменить внешний вид вкладок чата",
                                        desc = L and (L["Enable_Chat_Tabs_Style_Desc"] or "Включить кастомный внешний вид вкладок чата") or "Включить кастомный внешний вид вкладок чата",
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
                                            C_Timer.After(0.1, function()
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
                                name = "Анимации чата",
                                order = 3,
                                inline = true,
                                args = {
                                    chatAnimationsEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Chat_Animations"] or "Включить анимации чата") or "Включить анимации чата",
                                        desc = L and (L["Enable_Chat_Animations_Desc"] or "Включить кастомные анимации чата") or "Включить кастомные анимации чата",
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
                                        end,
                                    },
                                    chatTabShowDelay = {
                                        type = "range",
                                        name = L and (L["Chat_Tab_Show_Delay"] or "Задержка показа вкладок (сек)") or "Задержка показа вкладок (сек)",
                                        desc = L and (L["Chat_Tab_Show_Delay_Desc"] or "Задержка перед показом вкладок чата") or "Задержка перед показом вкладок чата",
                                        order = 2,
                                        width = "full",
                                        min = 0,
                                        max = 2,
                                        step = 0.01,
                                        hidden = function() return GetSetting("chatAnimationsEnabled", 0) ~= 1 end,
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
                                        name = L and (L["Chat_Tab_Hide_Delay"] or "Задержка скрытия вкладок (сек)") or "Задержка скрытия вкладок (сек)",
                                        desc = L and (L["Chat_Tab_Hide_Delay_Desc"] or "Задержка перед скрытием вкладок чата") or "Задержка перед скрытием вкладок чата",
                                        order = 3,
                                        width = "full",
                                        min = 0,
                                        max = 5,
                                        step = 0.01,
                                        hidden = function() return GetSetting("chatAnimationsEnabled", 0) ~= 1 end,
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
                                        name = "Длительность анимации появления чата (сек)",
                                        desc = "Длительность анимации появления чата",
                                        order = 4,
                                        width = "full",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        hidden = function() return GetSetting("chatAnimationsEnabled", 0) ~= 1 end,
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
                                        name = "Длительность анимации исчезновения чата (сек)",
                                        desc = "Длительность анимации исчезновения чата",
                                        order = 5,
                                        width = "full",
                                        min = 0,
                                        max = 5,
                                        step = 0.01,
                                        hidden = function() return GetSetting("chatAnimationsEnabled", 0) ~= 1 end,
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

                    -- Tooltip tab
                    tooltip = {
                        type = "group",
                        name = "Окно подсказок чата",
                        order = 2,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiChatTooltipPreview = true,
                            },
                            iconsBox = {
                                type = "group",
                                name = "Иконки",
                                order = 1,
                                inline = true,
                                args = {
                                    itemRefIconsEnabled = {
                                        type = "toggle",
                                        name = "Включить иконки в окне подсказок",
                                        desc = L and (L["Enable_Chat_Icons_Desc"] or "Показывать иконки предметов, заклинаний и достижений в окне подсказок чата") or "Показывать иконки предметов, заклинаний и достижений в окне подсказок чата",
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
                                name = "Позиция окна",
                                order = 2,
                                inline = true,
                                args = {
                                    tooltipPositionEnabled = {
                                        type = "toggle",
                                        name = L and (L["Enable_Tooltip_Position"] or "Изменить позицию окна") or "Изменить позицию окна",
                                        desc = L and (L["Enable_Tooltip_Position_Desc"] or "Включить кастомную позицию окна подсказок") or "Включить кастомную позицию окна подсказок",
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
                                    tooltipBaseOffset = {
                                        type = "range",
                                        name = "Базовое смещение по оси Y",
                                        desc = "Базовое смещение окна подсказок по оси Y",
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
                                        name = "Смещение при панеле питомца по оси Y",
                                        desc = "Дополнительное смещение окна подсказок по оси Y, когда видна панель питомца",
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

            -- Spam Filter Tab
            spam_filter = {
                type = "group",
                name = L and (L["Chat_Spam_Filter"] or "Фильтр сообщений") or "Фильтр сообщений",
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
                                name = L and (L["Enable_Chat_Spam_Filter"] or "Включить фильтр") or "Включить фильтр",
                                desc = L and (L["Enable_Chat_Spam_Filter_Desc"] or "Включить фильтрацию сообщений в чате") or "Включить фильтрацию сообщений в чате",
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
                        name = "Список фильтров",
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
                                    local resetText = L and (L["Reset_Filters"] or "Сбросить фильтры") or "Сбросить фильтры"
                                    return enabled and "|cFFFFD700" .. resetText .. "|r" or resetText
                                end,
                                desc = L and (L["Reset_Filters_Desc"] or "Восстановить фильтры по умолчанию") or "Восстановить фильтры по умолчанию",
                                order = 1,
                                width = "full",
                                disabled = function() return GetSetting("spamFilterEnabled", 1) ~= 1 end,
                                func = function()
                                    local defaultList = {}
                                    for i = 1, #SPAM_DEFAULT_LIST do
                                        defaultList[i] = SPAM_DEFAULT_LIST[i]
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
                name = L and (L["Chat_Wheel"] or "Колесо чата") or "Колесо чата",
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
                                name = "Включить колесо чата",
                                desc = "Включает колесо чата в стиле Dota: удерживайте назначенную кнопку, чтобы открыть колесо фраз.",
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
                                end,
                            },
                            chat_wheel_enable_image = {
                                type = "description",
                                name = "",
                                order = 1.5,
                                width = "full",
                                image = "Interface\\AddOns\\SarychUI\\media\\ChatWheel\\settings_chatwheel",
                                imageWidth = 100,
                                imageHeight = 100,
                                imageAlign = "CENTER",
                            },
                            chat_wheel_key = {
                                type = "keybinding",
                                name = "Кнопка колеса чата",
                                desc = "Удерживайте эту кнопку, чтобы открыть колесо. Отпустите, чтобы закрыть.",
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
                                name = "Показывать колесо всегда",
                                desc = "Колесо остаётся на экране постоянно. Удобно для разметки и настройки.",
                                order = 3,
                                width = "full",
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
                                type = "description",
                                name = "|cFFFFD700Пометка:|r Зажмите кнопку, чтобы открыть колесо. Отпустите, чтобы закрыть.",
                                order = 4,
                                fontSize = "medium",
                            },
                        },
                    },
                    displayBox = {
                        type = "group",
                        name = "Отображение фраз",
                        order = 2,
                        inline = true,
                        args = {
                            chat_wheel_channel_mode = {
                                type = "select",
                                name = "Канал отправки",
                                desc = "Куда отправлять фразу при отпускании бинда. Адаптивно: рейд → группа → сказать.",
                                order = 1,
                                width = "full",
                                values = {
                                    adaptive = "Адаптивно",
                                    say = "/сказать",
                                    party = "/группа",
                                    raid = "/рейд",
                                    guild = "/гильдия",
                                    yell = "/крик",
                                    emote = "/эмоция",
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
                            chat_wheel_phrase_offset = {
                                type = "range",
                                name = "Смещение фраз",
                                desc = "Расстояние фраз от края центрального круга.",
                                order = 2,
                                min = 0,
                                max = 300,
                                step = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return cw and cw.phraseOffset or 55
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    if type(db.chatWheel) ~= "table" then
                                        local def = SarychUI.defaults.profile.modules.chat.chatWheel
                                        db.chatWheel = def and CopyTable(def) or {}
                                    end
                                    db.chatWheel.phraseOffset = value
                                    if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyPhrases then
                                        _G.SarychUI_ChatWheel.ApplyPhrases()
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                            chat_wheel_phrase_font_size = {
                                type = "range",
                                name = "Размер шрифта фраз",
                                order = 3,
                                min = 8,
                                max = 40,
                                step = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return cw and cw.phraseFontSize or 20
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    if type(db.chatWheel) ~= "table" then
                                        local def = SarychUI.defaults.profile.modules.chat.chatWheel
                                        db.chatWheel = def and CopyTable(def) or {}
                                    end
                                    db.chatWheel.phraseFontSize = value
                                    if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyPhrases then
                                        _G.SarychUI_ChatWheel.ApplyPhrases()
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                            chat_wheel_phrase_max_width = {
                                type = "range",
                                name = "Макс. ширина фразы",
                                order = 4,
                                min = 40,
                                max = 600,
                                step = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return cw and cw.phraseMaxWidth or 260
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    if type(db.chatWheel) ~= "table" then
                                        local def = SarychUI.defaults.profile.modules.chat.chatWheel
                                        db.chatWheel = def and CopyTable(def) or {}
                                    end
                                    db.chatWheel.phraseMaxWidth = value
                                    if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyPhrases then
                                        _G.SarychUI_ChatWheel.ApplyPhrases()
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                            chat_wheel_selected_phrase_scale = {
                                type = "range",
                                name = "Масштаб выбранной фразы",
                                desc = "Масштаб выбранной фразы (1.0 = без увеличения).",
                                order = 5,
                                min = 1.0,
                                max = 2.5,
                                step = 0.05,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    if cw and cw.selectedPhraseScale ~= nil then
                                        return cw.selectedPhraseScale
                                    end
                                    if cw and cw.selectedPhraseFontSize and cw.phraseFontSize then
                                        local base = tonumber(cw.phraseFontSize) or 20
                                        if base > 0 then
                                            return math.max(1.0, math.min(2.5, (tonumber(cw.selectedPhraseFontSize) or base) / base))
                                        end
                                    end
                                    return 1.15
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    EnsureChatWheelDb(db)
                                    db.chatWheel.selectedPhraseScale = value
                                    if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyPhrases then
                                        _G.SarychUI_ChatWheel.ApplyPhrases()
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                            chat_wheel_phrase_anim_speed = {
                                type = "range",
                                name = "Скорость анимации фразы",
                                desc = "Скорость плавного увеличения выбранной фразы.",
                                order = 6,
                                min = 4,
                                max = 100,
                                step = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    local speed = cw and cw.phraseAnimSpeed or 30
                                    if speed <= 1.0 then
                                        speed = 30
                                    end
                                    return speed
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    EnsureChatWheelDb(db)
                                    db.chatWheel.phraseAnimSpeed = value
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                        },
                    },
                    cursorBox = {
                        type = "group",
                        name = "Внешний курсор",
                        order = 3,
                        inline = true,
                        args = {
                            chat_wheel_outer_cursor_enabled = {
                                type = "toggle",
                                name = "Внешний курсор",
                                desc = "Показывать курсор при выборе секторов (вне центрального круга).",
                                order = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    if not cw or cw.outerCursorEnabled == nil then return true end
                                    return cw.outerCursorEnabled == 1 or cw.outerCursorEnabled == true
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    EnsureChatWheelDb(db)
                                    db.chatWheel.outerCursorEnabled = value and 1 or 0
                                    if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyOuterCursor then
                                        _G.SarychUI_ChatWheel.ApplyOuterCursor()
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                            chat_wheel_outer_cursor_size = {
                                type = "range",
                                name = "Размер внешнего курсора",
                                desc = "Размер текстуры внешнего курсора.",
                                order = 2,
                                min = 8,
                                max = 128,
                                step = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    return cw and cw.outerCursorSize or 32
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    EnsureChatWheelDb(db)
                                    db.chatWheel.outerCursorSize = value
                                    if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplyOuterCursor then
                                        _G.SarychUI_ChatWheel.ApplyOuterCursor()
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                            chat_wheel_outer_cursor_edge_padding = {
                                type = "range",
                                name = "Отступ от края слайсов",
                                desc = "Отступ курсора от края слайсов (по умолчанию — половина размера иконки).",
                                order = 3,
                                min = 0,
                                max = 200,
                                step = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    if cw and cw.outerCursorEdgePadding ~= nil then
                                        return cw.outerCursorEdgePadding
                                    end
                                    local size = cw and cw.outerCursorSize or 32
                                    return size * 0.5
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    EnsureChatWheelDb(db)
                                    local size = db.chatWheel.outerCursorSize or 32
                                    if math.abs(value - (size * 0.5)) < 0.01 then
                                        db.chatWheel.outerCursorEdgePadding = nil
                                    else
                                        db.chatWheel.outerCursorEdgePadding = value
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                            chat_wheel_outer_cursor_max_radius = {
                                type = "range",
                                name = "Макс. радиус курсора",
                                desc = "Максимальное расстояние курсора от центра (0 = автоматически).",
                                order = 4,
                                min = 0,
                                max = 400,
                                step = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    if cw and cw.outerCursorMaxRadius ~= nil then
                                        return cw.outerCursorMaxRadius
                                    end
                                    return 0
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    EnsureChatWheelDb(db)
                                    if value == 0 then
                                        db.chatWheel.outerCursorMaxRadius = nil
                                    else
                                        db.chatWheel.outerCursorMaxRadius = value
                                    end
                                end,
                                disabled = function()
                                    return not ChatWheelModuleEnabled()
                                end,
                            },
                            chat_wheel_outer_cursor_safe_padding = {
                                type = "range",
                                name = "Запасной отступ курсора",
                                desc = "Дополнительный отступ курсора от края слайсов, чтобы не терять фокус сектора.",
                                order = 5,
                                min = 0,
                                max = 40,
                                step = 1,
                                get = function()
                                    local cw = SarychUI.db.profile.modules[moduleName].chatWheel
                                    if cw and cw.outerCursorSafePadding ~= nil then
                                        return cw.outerCursorSafePadding
                                    end
                                    return 14
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules[moduleName]
                                    EnsureChatWheelDb(db)
                                    db.chatWheel.outerCursorSafePadding = value
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

    baseOptions.args.spam_filter.args.listBox.args = BuildSpamFilterListArgs()

    local phraseOpts = BuildChatWheelPhraseOptionEntries()
    local phrasePosOpts = BuildChatWheelPhrasePositionEntries()
    local cwArgs = baseOptions.args.chat_wheel.args
    for key, option in pairs(phraseOpts) do
        cwArgs[key] = option
    end
    for key, option in pairs(phrasePosOpts) do
        cwArgs[key] = option
    end

    return baseOptions
end
