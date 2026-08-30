-- SarychUI Crowd Control (Cooldown Text) Module Options
local moduleName = "cc"
local module = SarychUI:GetModule(moduleName)

-- Localization
local L = SarychUI.L


-- Helpers
local function isEnabled()
    local db = SarychUI:GetModuleProfile(moduleName)
    if db and db.enabled ~= nil then
        return db.enabled
    end
    return true
end

local function GetSetting(key, default)
    local db = SarychUI:GetModuleProfile(moduleName)
    if db and db[key] ~= nil then return db[key] end
    return default
end

local function SetAndApply(key, value)
    local db = SarychUI:GetModuleProfile(moduleName)
    if not db then return end
    db[key] = value
    local dragging = SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging()
    if module and module.ApplySettings then
        module:ApplySettings()
    end
    -- While dragging, fonts update via SetLiveValue/RefreshStyle only.
    if dragging then
        return
    end
    if SarychUI.CooldownTextPreview and SarychUI.CooldownTextPreview.RefreshAll then
        SarychUI.CooldownTextPreview:RefreshAll()
    end
    if SarychUI.GcdCooldownPreview and SarychUI.GcdCooldownPreview.RefreshAll then
        SarychUI.GcdCooldownPreview:RefreshAll()
    end
end

local function SetAndPreview(key, value)
    SetAndApply(key, value)
    if SarychUI.CooldownTextPreview and SarychUI.CooldownTextPreview.SetLiveValue then
        SarychUI.CooldownTextPreview:SetLiveValue(key, value)
    end
    if SarychUI.GcdCooldownPreview and SarychUI.GcdCooldownPreview.SetLiveValue then
        SarychUI.GcdCooldownPreview:SetLiveValue(key, value)
    end
end

local function timerToggleGet(key)
    return function()
        return GetSetting(key, 1) == 1 or GetSetting(key, 1) == true
    end
end

local function timerToggleSet(key, applyFn)
    return function(_, val)
        local db = SarychUI:GetModuleProfile(moduleName)
        if not db then return end
        db[key] = val and 1 or 0
        local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
        if tools and applyFn and tools[applyFn] then
            tools[applyFn](tools)
        end
        -- Update timer previews immediately (hide/show sample timers).
        if SarychUI.CastbarTimerPreview and SarychUI.CastbarTimerPreview.RefreshAll then
            SarychUI.CastbarTimerPreview:RefreshAll()
        end
        if SarychUI.CountdownTimerPreview and SarychUI.CountdownTimerPreview.RefreshAll then
            SarychUI.CountdownTimerPreview:RefreshAll()
        end
        -- Rebuild options UI so dependent disabled states update immediately.
        if SarychUI.NotifySarychUIOptionsChange then
            SarychUI:NotifySarychUIOptionsChange()
        elseif SarychUI.RefreshConfig then
            SarychUI:RefreshConfig()
        end
    end
end

local function isTimerOn(key)
    local v = GetSetting(key, 1)
    return v == 1 or v == true
end

function module:GetOptions()
    return {
        type = "group",
        name = L and (L["Cooldown Text"] or "Перезарядка и таймеры") or "Перезарядка и таймеры",
        desc = L and (L["CooldownText_Description"] or "Настройка отображения текста перезарядки и таймеров") or "Настройка отображения текста перезарядки и таймеров",
        childGroups = "tab",
        args = {
            -- General
            general = {
                type = "group",
                name = L and (L["General"] or "Общее") or "Общее",
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L and (L["Enable_Module"] or "Включить модуль") or "Включить модуль",
                        desc = L and (L["Enable_Module_Desc"] or "Включить или выключить модуль") or "Включить или выключить модуль",
                        order = 1,
                        width = "full",
                        get = function()
                            return SarychUI.db.profile.modules[moduleName].enabled
                        end,
                        set = function(_, v)
                            SarychUI.db.profile.modules[moduleName].enabled = v
                            if v then
                                SarychUI:EnableModule(moduleName)
                            else
                                SarychUI:DisableModule(moduleName)
                            end
                        end,
                    },

                    appearanceBox = {
                        type = "group",
                        name = L and (L["Cooldown_Text"] or "Текст перезарядки") or "Текст перезарядки",
                        order = 10,
                        inline = true,
                        suiTwoCol = true,
                        disabled = function() return not isEnabled() end,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiFullRow = true,
                                suiCooldownTextPreview = true,
                            },
                            font = {
                                type = "select",
                                style = "dropdown",
                                name = L and (L["Font"] or "Шрифт") or "Шрифт",
                                order = 1,
                                values = function()
                                    local values = {}
                                    if SarychUI and SarychUI.Media and SarychUI.Media.GetFonts then
                                        for _, name in ipairs(SarychUI.Media.GetFonts()) do
                                            values[name] = name
                                        end
                                    end
                                    if not next(values) then
                                        values["Friz Quadrata TT"] = "Friz Quadrata TT"
                                    end
                                    return values
                                end,
                                get = function() return GetSetting("font", "Friz Quadrata TT") end,
                                set = function(_, v) SetAndPreview("font", v) end,
                            },
                            fontFlags = {
                                type = "select",
                                style = "dropdown",
                                name = L and (L["Font_Flags"] or "Стиль шрифта") or "Стиль шрифта",
                                desc = L and (L["Font_Flags_Desc"] or "Варианты: NONE, OUTLINE, THICKOUTLINE, MONOCHROMEOUTLINE") or "Варианты: NONE, OUTLINE, THICKOUTLINE, MONOCHROMEOUTLINE",
                                values = function()
                                    if SarychUI_FontOutlineValues and SarychUI_FontOutlineValues.GetSelectValues then
                                        return SarychUI_FontOutlineValues.GetSelectValues(L)
                                    end
                                    return {
                                        ["NONE"] = "NONE",
                                        ["OUTLINE"] = "OUTLINE",
                                        ["THICKOUTLINE"] = "THICKOUTLINE",
                                        ["MONOCHROMEOUTLINE"] = "MONOCHROMEOUTLINE",
                                    }
                                end,
                                order = 2,
                                get = function() return GetSetting("fontFlags", "OUTLINE") end,
                                set = function(_, v) SetAndPreview("fontFlags", v) end,
                            },
                            fontSizeSmall = {
                                type = "range",
                                name = L and (L["Font_Size_Small"] or "Размер текста (< 60 сек)") or "Размер текста (< 60 сек)",
                                desc = L and (L["Font_Size_Small_Desc"] or "Размер текста для оставшегося времени менее 60 секунд") or "Размер текста для оставшегося времени менее 60 секунд",
                                min = 6, max = 32, step = 1,
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                suiPreviewKey = "fontSizeSmall",
                                get = function() return GetSetting("fontSizeSmall", 14) end,
                                set = function(_, v) SetAndPreview("fontSizeSmall", v) end,
                            },
                            fontSizeMedium = {
                                type = "range",
                                name = L and (L["Font_Size_Medium"] or "Размер текста (1–10 мин)") or "Размер текста (1–10 мин)",
                                desc = L and (L["Font_Size_Medium_Desc"] or "Размер текста для 1:00–9:59 и ≥10 минут") or "Размер текста для 1:00–9:59 и ≥10 минут",
                                min = 6, max = 32, step = 1,
                                order = 4,
                                width = "full",
                                suiFullRow = true,
                                suiPreviewKey = "fontSizeMedium",
                                get = function() return GetSetting("fontSizeMedium", 12) end,
                                set = function(_, v) SetAndPreview("fontSizeMedium", v) end,
                            },
                            fontSizeLarge = {
                                type = "range",
                                name = L and (L["Font_Size_Large"] or "Размер текста (>10 мин)") or "Размер текста (>10 мин)",
                                desc = L and (L["Font_Size_Large_Desc"] or "Размер текста для значений в минутах ≥ 10") or "Размер текста для значений в минутах ≥ 10",
                                min = 6, max = 32, step = 1,
                                order = 5,
                                width = "full",
                                suiFullRow = true,
                                suiPreviewKey = "fontSizeLarge",
                                get = function() return GetSetting("fontSizeLarge", 12) end,
                                set = function(_, v) SetAndPreview("fontSizeLarge", v) end,
                            },
                            defaultColor = {
                                type = "color",
                                name = L and (L["Default_Color"] or "Цвет текста по умолчанию") or "Цвет текста по умолчанию",
                                hasAlpha = true,
                                order = 6,
                                width = "full",
                                suiFullRow = true,
                                get = function()
                                    local c = GetSetting("defaultColor", {1,1,1,1})
                                    return c[1], c[2], c[3], c[4]
                                end,
                                set = function(_, r, g, b, a)
                                    SetAndPreview("defaultColor", {r, g, b, a})
                                end,
                            },
                        },
                    },

                    conditionsBox = {
                        type = "group",
                        name = L and (L["Display_Conditions_Settings"] or "Настройки условий отображения") or "Настройки условий отображения",
                        order = 20,
                        inline = true,
                        suiTwoCol = true,
                        disabled = function() return not isEnabled() end,
                        args = {
                            minScale = {
                                type = "range",
                                name = L and (L["Min_Scale"] or "Минимальный масштаб") or "Минимальный масштаб",
                                desc = L and (L["Min_Scale_Desc"] or "Не показывать текст, если итоговый масштаб иконки меньше") or "",
                                min = 0.1, max = 2.0, step = 0.05,
                                order = 1,
                                get = function() return GetSetting("minScale", 0.5) end,
                                set = function(_, v) SetAndApply("minScale", v) end,
                            },
                            minIconSize = {
                                type = "range",
                                name = L and (L["Min_Icon_Size"] or "Минимальный размер иконки") or "Минимальный размер иконки",
                                desc = L and (L["Min_Icon_Size_Desc"] or "Не показывать текст, если ширина/высота иконки меньше") or "Не показывать текст, если ширина/высота иконки меньше",
                                min = 8, max = 64, step = 1,
                                order = 2,
                                get = function() return GetSetting("minIconSize", 23) end,
                                set = function(_, v) SetAndApply("minIconSize", v) end,
                            },
                            gcdPreview = {
                                type = "description",
                                name = "",
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                suiGcdCooldownPreview = true,
                            },
                            hideOnGCD = {
                                type = "toggle",
                                name = L and (L["Hide_On_GCD"] or "Не отображать при ГКД") or "Не отображать при ГКД",
                                desc = L and (L["Hide_On_GCD_Desc"] or "Скрывать текст кулдауна на способностях с глобальным временем восстановления (ГКД ~1.5 сек)") or "Скрывать текст кулдауна на способностях с глобальным временем восстановления (ГКД ~1.5 сек)",
                                order = 4,
                                width = "full",
                                suiFullRow = true,
                                get = function() return GetSetting("minDuration", 3) >= 3 end,
                                set = function(_, v)
                                    SetAndApply("minDuration", v and 3 or 0)
                                    if SarychUI.GcdCooldownPreview and SarychUI.GcdCooldownPreview.SetLiveValue then
                                        SarychUI.GcdCooldownPreview:SetLiveValue("minDuration", v and 3 or 0)
                                    end
                                end,
                            },
                        },
                    },
                },
            },

            -- Timers (moved from Инструменты и утилиты)
            timers = {
                type = "group",
                name = "Таймеры",
                order = 2,
                disabled = function() return not isEnabled() end,
                args = {
                    castbarBox = {
                        type = "group",
                        name = "Таймер на каст барах",
                        desc = "Настройки отображения таймеров на панелях каста заклинаний",
                        order = 1,
                        inline = true,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiCastbarTimerPreview = true,
                            },
                            enableCastbarTimers = {
                                type = "toggle",
                                name = "Включить",
                                desc = "Включить отображение таймеров на каст барах",
                                order = 1,
                                width = "full",
                                get = timerToggleGet("enableCastbarTimers"),
                                set = timerToggleSet("enableCastbarTimers", "ApplyCastbarTimers"),
                            },
                            castbarTargets = {
                                type = "group",
                                name = "Отображать на",
                                order = 2,
                                inline = true,
                                disabled = function() return not isTimerOn("enableCastbarTimers") end,
                                args = {
                                    enableCastbarPlayer = {
                                        type = "toggle",
                                        name = "Игрок",
                                        desc = "Показывать таймер на каст баре игрока",
                                        order = 1,
                                        width = "full",
                                        disabled = function() return not isTimerOn("enableCastbarTimers") end,
                                        get = timerToggleGet("enableCastbarPlayer"),
                                        set = timerToggleSet("enableCastbarPlayer", "ApplyCastbarTimers"),
                                    },
                                    enableCastbarTarget = {
                                        type = "toggle",
                                        name = "Цель",
                                        desc = "Показывать таймер на каст баре цели",
                                        order = 2,
                                        width = "full",
                                        disabled = function() return not isTimerOn("enableCastbarTimers") end,
                                        get = timerToggleGet("enableCastbarTarget"),
                                        set = timerToggleSet("enableCastbarTarget", "ApplyCastbarTimers"),
                                    },
                                    enableCastbarFocus = {
                                        type = "toggle",
                                        name = "Фокус",
                                        desc = "Показывать таймер на каст баре фокуса",
                                        order = 3,
                                        width = "full",
                                        disabled = function() return not isTimerOn("enableCastbarTimers") end,
                                        get = timerToggleGet("enableCastbarFocus"),
                                        set = timerToggleSet("enableCastbarFocus", "ApplyCastbarTimers"),
                                    },
                                },
                            },
                        },
                    },
                    countdownBox = {
                        type = "group",
                        name = "Обратный отсчёт",
                        desc = "Таймеры обратного отсчёта:\n• При приглашениях — на окне приглашения в группу/рейд и в диалоге готовности подземелья (LFG).\n• До открытия дверей — в центре экрана перед стартом арены или поля боя.",
                        order = 2,
                        inline = true,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiCountdownTimerPreview = true,
                            },
                            enableInviteCountdown = {
                                type = "toggle",
                                name = "При приглашениях",
                                desc = "Показывает таймер обратного отсчёта на окне приглашения в группу/рейд и в диалоге готовности подземелья",
                                order = 1,
                                width = "full",
                                get = timerToggleGet("enableInviteCountdown"),
                                set = timerToggleSet("enableInviteCountdown", "ApplyInviteCountdown"),
                            },
                            enableArenaCountdown = {
                                type = "toggle",
                                name = "До открытия дверей",
                                desc = "Показывает таймер обратного отсчёта в центре экрана до начала арены или поля боя",
                                order = 2,
                                width = "full",
                                get = timerToggleGet("enableArenaCountdown"),
                                set = timerToggleSet("enableArenaCountdown", "ApplyArenaCountdown"),
                            },
                        },
                    },
                },
            },
        },
    }
end
