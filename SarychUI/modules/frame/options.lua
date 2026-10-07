-- SarychUI Frame Module Options
-- Options UI for frame positioning, text and visuals

local moduleName = "frame"
local L = SarychUI.L

-- Get module
local module = SarychUI:GetModule(moduleName)
if not module then return end

-- Early exit if AceConfig not available
if not LibStub or not LibStub("AceConfig-3.0", true) then
    return
end

local function isEnabled()
    return SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName] and SarychUI.db.profile.modules[moduleName].enabled
end

local function FrameDB()
    return SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
end

local function isOn(key)
    local db = FrameDB()
    if not db then return false end
    local v = db[key]
    return v == 1 or v == true
end

local function RefreshConfig()
    if SarychUI and SarychUI.NotifySarychUIOptionsChange then
        SarychUI:NotifySarychUIOptionsChange()
    elseif SarychUI and SarychUI.RefreshConfig then
        SarychUI:RefreshConfig()
    end
end

local function ApplyFrameSettings()
    if SarychUI.ApplyLiveModule then
        SarychUI.ApplyLiveModule(module)
        return
    end
    if module.ApplySettings then
        module:ApplySettings()
    end
end

local function IsUnitFrameLayersEnabled()
    local addons = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
    local db = addons and addons.UnitFrameLayers
    if db then
        return db.enabled ~= false
    end
    local wrapper = SarychUI.GetAddOn and SarychUI:GetAddOn("UnitFrameLayers")
    if wrapper and wrapper.IsRuntimeEnabled then
        return wrapper:IsRuntimeEnabled()
    end
    return UnitFrameLayersEnabled ~= false
end

local function UnitFrameLayersDB()
    if not SarychUI.db or not SarychUI.db.profile then return nil end
    SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
    local db = SarychUI.db.profile.addons.UnitFrameLayers
    if not db then
        db = { enabled = true }
        SarychUI.db.profile.addons.UnitFrameLayers = db
    end
    return db
end

local function FrameForUnit(unit)
    if unit == "player" then return PlayerFrame end
    if unit == "target" then return TargetFrame end
    if unit == "focus" then return FocusFrame end
    local n = type(unit) == "string" and unit:match("^party(%d+)$")
    if n then return _G["PartyMemberFrame" .. n] end
    return _G[unit .. "Frame"]
end

local function RefreshUnitFrameLayersHealthColors()
    if type(UpdateHealthBarColor) ~= "function" then return end
    local units = { "player", "target", "focus", "party1", "party2", "party3", "party4" }
    for i = 1, #units do
        local unit = units[i]
        local frame = FrameForUnit(unit)
        if frame then
            frame.unit = frame.unit or unit
            if not frame.healthbar then
                local name = frame.GetName and frame:GetName()
                frame.healthbar = name and _G[name .. "HealthBar"] or nil
            end
            -- Только перекраска: UnitFrameHealthBar_Update после неё снова ставит зелёный.
            UpdateHealthBarColor(frame)
        end
    end
    -- Прямой проход по известным барам (на случай рассинхрона frame.healthbar)
    local bars = {
        { PlayerFrame, PlayerFrameHealthBar, "player" },
        { TargetFrame, TargetFrameHealthBar, "target" },
        { FocusFrame, FocusFrameHealthBar, "focus" },
    }
    for i = 1, #bars do
        local frame, bar, unit = bars[i][1], bars[i][2], bars[i][3]
        if frame and bar then
            frame.healthbar = bar
            frame.unit = frame.unit or unit
            UpdateHealthBarColor(frame)
        end
    end
    local preview = SarychUI.FramePvpPreview
    if preview and preview.SetLiveValue then
        local db = UnitFrameLayersDB()
        if db then
            preview:SetLiveValue("classColorHP", db.classColorHP ~= false)
            preview:SetLiveValue("playerClassColorHP", db.playerClassColorHP == true)
        else
            preview:RefreshAll()
        end
    elseif preview and preview.RefreshAll then
        preview:RefreshAll()
    end
end

local function ApplyPositionDrag()
    if module.ApplyPositionDragMode then
        module:ApplyPositionDragMode()
    end
end

local function ToggleFrameDrag(frameId, enabled)
    local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
    if panel and panel.Toggle then
        panel:Toggle(frameId, enabled)
        return
    end
    ApplyPositionDrag()
end

local function NotifyCombatPreview(key, value)
    local preview = SarychUI and SarychUI.CombatIndicatorPreview
    if not preview then return end
    if key ~= nil and preview.SetLiveValue then
        preview:SetLiveValue(key, value)
    elseif preview.RefreshAll then
        preview:RefreshAll()
    end
end

local function OnCombatSetting(key, value)
    -- During slider drag the preview already tracks via SetLiveValue/LayoutLive.
    if SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging() then
        return
    end
    local preview = SarychUI and SarychUI.CombatIndicatorPreview
    if preview then
        if preview.ClearLiveValue then
            preview:ClearLiveValue(key)
        end
        if preview.SetActiveKey then
            preview:SetActiveKey(key)
        end
        if preview.RefreshAll then
            preview:RefreshAll()
        end
    end
end

function module:GetOptions()
    return {
        type = "group",
        name = L and (L["Frames"] or "Фреймы") or "Фреймы",
        desc = L and (L["Frames_Description"] or "Настройки модификаций фреймов") or "Настройки модификаций фреймов",
        childGroups = "tab",
        args = {
            -- General tab
            general = {
                type = "group",
                name = L and (L["General"] or "Общее") or "Общее",
                order = 1,
                args = {
                    header = {
                        type = "header",
                        name = L and (L["Frames"] or "Фреймы") or "Фреймы",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = L and (L["Enable_Module"] or "Включить модуль") or "Включить модуль",
                        desc = "Включить или выключить модуль",
                        order = 2,
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

            -- Position & scale tab
            move = {
                type = "group",
                name = "Позиции и масштаб",
                order = 2,
                disabled = function() return not isEnabled() end,
                args = {
                    positionEnableBox = {
                        type = "group",
                        name = "Изменить расположение фреймов",
                        order = 1,
                        inline = true,
                        args = {
                            change_positions = {
                                type = "toggle",
                                name = "Включить",
                                desc = "Разрешить изменение позиций фреймов игрока, цели и фокуса",
                                order = 1,
                                width = "full",
                                get = function() return isOn("changePositions") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    db.changePositions = value and 1 or 0
                                    if not value then
                                        db.showPositionDragFrame = 0
                                        db.showPositionGrid = 0
                                        db.showPlayerDragFrame = 0
                                        db.showTargetDragFrame = 0
                                        db.showFocusDragFrame = 0
                                        local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
                                        if panel and panel.IsOpen and panel:IsOpen() then
                                            panel:Close(false)
                                        end
                                    end
                                    ApplyFrameSettings()
                                    ApplyPositionDrag()
                                    RefreshConfig()
                                end,
                            },
                        },
                    },

                    playerBox = {
                        type = "group",
                        name = "Игрок",
                        order = 2,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("changePositions") end,
                        args = {
                            player_x = {
                                type = "range",
                                name = "Смещение по X",
                                desc = "Горизонтальное смещение фрейма игрока",
                                min = -2000, max = 2000, step = 1,
                                order = 1,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.playerFrameX or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.playerFrameX = val
                                    ApplyFrameSettings()
                                end,
                            },
                            player_y = {
                                type = "range",
                                name = "Смещение по Y",
                                desc = "Вертикальное смещение фрейма игрока",
                                min = -2000, max = 2000, step = 1,
                                order = 2,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.playerFrameY or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.playerFrameY = val
                                    ApplyFrameSettings()
                                end,
                            },
                            playerDrag = {
                                type = "execute",
                                name = function()
                                    if isOn("showPlayerDragFrame") then
                                        return "Свободное перемещение |cff00ff00(вкл)|r"
                                    end
                                    return "Свободное перемещение"
                                end,
                                desc = "Показать рамку и окошко для перетаскивания фрейма игрока",
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                func = function()
                                    local db = FrameDB(); if not db then return end
                                    local val = not (db.showPlayerDragFrame == 1)
                                    db.showPlayerDragFrame = val and 1 or 0
                                    if val then
                                        db.showTargetDragFrame = 0
                                        db.showFocusDragFrame = 0
                                    end
                                    ToggleFrameDrag("playerFrame", val)
                                    RefreshConfig()
                                end,
                            },
                        },
                    },

                    targetBox = {
                        type = "group",
                        name = "Цель",
                        order = 3,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("changePositions") end,
                        args = {
                            target_x = {
                                type = "range",
                                name = "Смещение по X",
                                desc = "Горизонтальное смещение фрейма цели",
                                min = -2000, max = 2000, step = 1,
                                order = 1,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.targetFrameX or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.targetFrameX = val
                                    ApplyFrameSettings()
                                end,
                            },
                            target_y = {
                                type = "range",
                                name = "Смещение по Y",
                                desc = "Вертикальное смещение фрейма цели",
                                min = -2000, max = 2000, step = 1,
                                order = 2,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.targetFrameY or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.targetFrameY = val
                                    ApplyFrameSettings()
                                end,
                            },
                            targetDrag = {
                                type = "execute",
                                name = function()
                                    if isOn("showTargetDragFrame") then
                                        return "Свободное перемещение |cff00ff00(вкл)|r"
                                    end
                                    return "Свободное перемещение"
                                end,
                                desc = "Показать рамку и окошко для перетаскивания фрейма цели",
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                func = function()
                                    local db = FrameDB(); if not db then return end
                                    local val = not (db.showTargetDragFrame == 1)
                                    db.showTargetDragFrame = val and 1 or 0
                                    if val then
                                        db.showPlayerDragFrame = 0
                                        db.showFocusDragFrame = 0
                                    end
                                    ToggleFrameDrag("targetFrame", val)
                                    RefreshConfig()
                                end,
                            },
                        },
                    },

                    focusBox = {
                        type = "group",
                        name = "Фокус",
                        order = 4,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("changePositions") end,
                        args = {
                            focus_x = {
                                type = "range",
                                name = "Смещение по X",
                                desc = "Горизонтальное смещение фрейма фокуса",
                                min = -2000, max = 2000, step = 1,
                                order = 1,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.focusFrameX or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.focusFrameX = val
                                    ApplyFrameSettings()
                                end,
                            },
                            focus_y = {
                                type = "range",
                                name = "Смещение по Y",
                                desc = "Вертикальное смещение фрейма фокуса",
                                min = -2000, max = 2000, step = 1,
                                order = 2,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.focusFrameY or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.focusFrameY = val
                                    ApplyFrameSettings()
                                end,
                            },
                            focusDrag = {
                                type = "execute",
                                name = function()
                                    if isOn("showFocusDragFrame") then
                                        return "Свободное перемещение |cff00ff00(вкл)|r"
                                    end
                                    return "Свободное перемещение"
                                end,
                                desc = "Показать рамку и окошко для перетаскивания фрейма фокуса",
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                func = function()
                                    local db = FrameDB(); if not db then return end
                                    local val = not (db.showFocusDragFrame == 1)
                                    db.showFocusDragFrame = val and 1 or 0
                                    if val then
                                        db.showPlayerDragFrame = 0
                                        db.showTargetDragFrame = 0
                                    end
                                    ToggleFrameDrag("focusFrame", val)
                                    RefreshConfig()
                                end,
                            },
                        },
                    },

                    scaleBox = {
                        type = "group",
                        name = "Масштаб фреймов",
                        order = 5,
                        inline = true,
                        args = {
                            change_scale = {
                                type = "toggle",
                                name = "Включить",
                                desc = "Разрешить изменение масштаба фреймов игрока, цели и фокуса",
                                order = 1,
                                width = "full",
                                get = function() return isOn("changeScale") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    if value then
                                        db.frameScale = db.previousFrameScale or 1.0
                                    else
                                        db.previousFrameScale = db.frameScale or 1.0
                                    end
                                    db.changeScale = value and 1 or 0
                                    ApplyFrameSettings()
                                    RefreshConfig()
                                end,
                            },
                            frame_scale = {
                                type = "range",
                                name = "Масштаб",
                                desc = "Масштаб фреймов (0.5 = 50%, 1.0 = 100%, 2.0 = 200%)",
                                min = 0.5, max = 2.0, step = 0.05,
                                order = 2,
                                width = "full",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.frameScale or 1.0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.frameScale = val
                                    db.previousFrameScale = val
                                    ApplyFrameSettings()
                                end,
                                hidden = function() return not isOn("changeScale") end,
                            },
                        },
                    },
                },
            },

            -- Combat Indicator tab
            combat = {
                type = "group",
                name = "Индикатор боя",
                order = 3,
                disabled = function() return not isEnabled() end,
                args = {
                    preview = {
                        type = "description",
                        name = "",
                        order = 0,
                        width = "full",
                        suiCombatIndicatorPreview = true,
                    },
                    enableBox = {
                        type = "group",
                        name = "Настройки индикатора боя",
                        order = 1,
                        inline = true,
                        args = {
                            enable_combat_indicator = {
                                type = "toggle",
                                name = "|TInterface\\CharacterFrame\\UI-StateIcon:22:22:0:0:256:128:128:256:0:61|t Включить",
                                desc = "Показывать индикатор боя на фреймах игрока, цели и фокуса",
                                order = 1,
                                width = "full",
                                get = function() return isOn("enableCombatIndicator") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    db.enableCombatIndicator = value and 1 or 0
                                    ApplyFrameSettings()
                                    NotifyCombatPreview("enableCombatIndicator", value and 1 or 0)
                                    RefreshConfig()
                                end,
                            },
                            combat_scale = {
                                type = "range",
                                name = "Масштаб",
                                desc = "Масштаб индикатора боя (0.3 = 30%, 1.0 = 100%, 2.0 = 200%)",
                                min = 0.3, max = 2.0, step = 0.05,
                                order = 2,
                                width = "full",
                                suiPreviewKey = "combatIndicatorScale",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorScale or 0.85
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorScale = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorScale", v)
                                end,
                                hidden = function() return not isOn("enableCombatIndicator") end,
                            },
                        },
                    },
                    playerBox = {
                        type = "group",
                        name = "Игрок",
                        order = 2,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("enableCombatIndicator") end,
                        args = {
                            combat_player_x = {
                                type = "range",
                                name = "Смещение по X",
                                desc = "Горизонтальное смещение индикатора боя игрока",
                                min = -500, max = 500, step = 1,
                                order = 1,
                                suiPreviewKey = "combatIndicatorPlayerX",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorPlayerX or 33
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorPlayerX = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorPlayerX", v)
                                end,
                            },
                            combat_player_y = {
                                type = "range",
                                name = "Смещение по Y",
                                desc = "Вертикальное смещение индикатора боя игрока",
                                min = -500, max = 500, step = 1,
                                order = 2,
                                suiPreviewKey = "combatIndicatorPlayerY",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorPlayerY or 38
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorPlayerY = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorPlayerY", v)
                                end,
                            },
                        },
                    },
                    targetBox = {
                        type = "group",
                        name = "Цель",
                        order = 3,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("enableCombatIndicator") end,
                        args = {
                            combat_target_x = {
                                type = "range",
                                name = "Смещение по X",
                                desc = "Горизонтальное смещение индикатора боя цели",
                                min = -500, max = 500, step = 1,
                                order = 1,
                                suiPreviewKey = "combatIndicatorTargetX",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorTargetX or 57
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorTargetX = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorTargetX", v)
                                end,
                            },
                            combat_target_y = {
                                type = "range",
                                name = "Смещение по Y",
                                desc = "Вертикальное смещение индикатора боя цели",
                                min = -500, max = 500, step = 1,
                                order = 2,
                                suiPreviewKey = "combatIndicatorTargetY",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorTargetY or 0
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorTargetY = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorTargetY", v)
                                end,
                            },
                        },
                    },
                    focusBox = {
                        type = "group",
                        name = "Фокус",
                        order = 4,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("enableCombatIndicator") end,
                        args = {
                            combat_focus_x = {
                                type = "range",
                                name = "Смещение по X",
                                desc = "Горизонтальное смещение индикатора боя фокуса",
                                min = -500, max = 500, step = 1,
                                order = 1,
                                suiPreviewKey = "combatIndicatorFocusX",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorFocusX or 57
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorFocusX = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorFocusX", v)
                                end,
                            },
                            combat_focus_y = {
                                type = "range",
                                name = "Смещение по Y",
                                desc = "Вертикальное смещение индикатора боя фокуса",
                                min = -500, max = 500, step = 1,
                                order = 2,
                                suiPreviewKey = "combatIndicatorFocusY",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorFocusY or 0
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorFocusY = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorFocusY", v)
                                end,
                            },
                        },
                    },
                    specialBox = {
                        type = "group",
                        name = "Смещения для особых случаев",
                        order = 5,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("enableCombatIndicator") end,
                        args = {
                            combat_elite_offset = {
                                type = "range",
                                name = "Смещение для элитных мобов",
                                desc = "Дополнительное смещение индикатора для элитных, редких и боссов (пиксели)",
                                min = 0, max = 100, step = 1,
                                order = 1,
                                suiPreviewKey = "combatIndicatorEliteOffset",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorEliteOffset or 30
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorEliteOffset = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorEliteOffset", v)
                                end,
                            },
                            combat_rogue_offset = {
                                type = "range",
                                name = "Смещение для разбойника",
                                desc = "Дополнительное смещение индикатора для разбойника против обычных мобов (пиксели)",
                                min = 0, max = 50, step = 1,
                                order = 2,
                                suiPreviewKey = "combatIndicatorRogueOffset",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorRogueOffset or 10
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorRogueOffset = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorRogueOffset", v)
                                end,
                            },
                        },
                    },
                    focusComboBox = {
                        type = "group",
                        name = L and (L["Focus Combo Points"] or "Комбопоинты на фрейме фокуса") or "Комбопоинты на фрейме фокуса",
                        desc = L and (L["Added by suggestion: Hannahmckay"] or "Добавлено по предложению: Hannahmckay") or "Добавлено по предложению: Hannahmckay",
                        order = 6,
                        inline = true,
                        suiHelpIcon = true,
                        args = {
                            enable_focus_combo_points = {
                                type = "toggle",
                                name = L and (L["Enable"] or "Включить") or "Включить",
                                desc = L and (L["Focus Combo Points Desc"] or "Показывать накопленные на фокусе комбопоинты на его фрейме.") or "Показывать накопленные на фокусе комбопоинты на его фрейме.",
                                order = 1,
                                width = "full",
                                suiPreviewKey = "enableFocusComboPoints",
                                get = function() return isOn("enableFocusComboPoints") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    db.enableFocusComboPoints = value and 1 or 0
                                    ApplyFrameSettings()
                                    NotifyCombatPreview("enableFocusComboPoints", value and 1 or 0)
                                    RefreshConfig()
                                end,
                            },
                        },
                    },
                },
            },

            -- Text tab
            text = {
                type = "group",
                name = "Текст индикаторов",
                order = 4,
                disabled = function() return not isEnabled() end,
                args = {
                    visibilityBox = {
                        type = "group",
                        name = "Текстовые индикаторы",
                        order = 1,
                        inline = true,
                        args = {
                            show_on_alt = {
                                type = "toggle",
                                name = "Показывать при зажатии |cFFFFD700Alt|r",
                                desc = "Показывать текстовые индикаторы (HP/MP текст) только при зажатой клавише Alt",
                                order = 1,
                                width = "full",
                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                get = function() return SarychUI.db.profile.modules.frame.showOnAlt == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.showOnAlt = v and 1 or 0; ApplyFrameSettings() end,
                            },
                            show_in_combat = {
                                type = "toggle",
                                name = "Показывать во время боя",
                                desc = "Показывать текстовые индикаторы (HP/MP текст) всегда во время боя",
                                order = 2,
                                width = "full",
                                get = function() return SarychUI.db.profile.modules.frame.showTextIndicatorsInCombat == true end,
                                set = function(_, v)
                                    SarychUI.db.profile.modules.frame.showTextIndicatorsInCombat = v and true or false
                                    if module.UpdateCombatState then
                                        module:UpdateCombatState()
                                    end
                                    ApplyFrameSettings()
                                end,
                            },
                            fade_after_combat = {
                                type = "toggle",
                                name = "Плавное появление/исчезновение",
                                desc = "Плавное появление текстовых индикаторов при входе в бой и исчезновение при выходе",
                                order = 3,
                                width = "full",
                                disabled = function() return SarychUI.db.profile.modules.frame.showTextIndicatorsInCombat ~= true end,
                                get = function() return SarychUI.db.profile.modules.frame.textIndicatorsFadeAfterCombat == true end,
                                set = function(_, v)
                                    SarychUI.db.profile.modules.frame.textIndicatorsFadeAfterCombat = v and true or false
                                    ApplyFrameSettings()
                                end,
                            },
                            fade_time = {
                                type = "range",
                                name = "Время анимации",
                                desc = "Время плавного появления/исчезновения текстовых индикаторов (секунды)",
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                order = 4,
                                width = "full",
                                disabled = function() return SarychUI.db.profile.modules.frame.showTextIndicatorsInCombat ~= true or SarychUI.db.profile.modules.frame.textIndicatorsFadeAfterCombat ~= true end,
                                get = function() return SarychUI.db.profile.modules.frame.textIndicatorsFadeTime or 0.4 end,
                                set = function(_, v)
                                    SarychUI.db.profile.modules.frame.textIndicatorsFadeTime = v
                                    ApplyFrameSettings()
                                end,
                            },
                        },
                    },
                    fontSizeBox = {
                        type = "group",
                        name = "Размер шрифта здоровья и маны",
                        order = 2,
                        inline = true,
                        args = {
                            change_bar_font = {
                                type = "toggle",
                                name = "Включить",
                                desc = "Заменяет размер текста здоровья и маны на рамках персонажа, цели, фокуса и питомца.",
                                order = 1,
                                width = "full",
                                get = function() return isOn("changeBarFontSize") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    db.changeBarFontSize = value and 1 or 0
                                    ApplyFrameSettings()
                                    RefreshConfig()
                                end,
                            },
                            health_font_size = {
                                type = "range",
                                name = "Размер шрифта здоровья",
                                desc = "Размер текста здоровья на рамках. У питомца на 2 пункта меньше.",
                                min = 8, max = 16, step = 1,
                                order = 2,
                                width = "full",
                                hidden = function() return not isOn("changeBarFontSize") end,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.healthBarFontSize or 14
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.healthBarFontSize = val
                                    ApplyFrameSettings()
                                end,
                            },
                            mana_font_size = {
                                type = "range",
                                name = "Размер шрифта маны",
                                desc = "Размер текста маны на рамках. У питомца на 2 пункта меньше.",
                                min = 8, max = 16, step = 1,
                                order = 3,
                                width = "full",
                                hidden = function() return not isOn("changeBarFontSize") end,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.manaBarFontSize or 14
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.manaBarFontSize = val
                                    ApplyFrameSettings()
                                end,
                            },
                        },
                    },
                    percentagesBox = {
                        type = "group",
                        name = "Проценты здоровья",
                        order = 3,
                        inline = true,
                        args = {
                            target_percent = {
                                type = "toggle",
                                name = "Показывать процент здоровья |cFFFFD700цели|r",
                                desc = "Показывать процент здоровья |cFFFFD700цели|r на фрейме",
                                order = 1,
                                width = "full",
                                get = function() return SarychUI.db.profile.modules.frame.showTargetPercent == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.showTargetPercent = v and 1 or 0; ApplyFrameSettings() end,
                            },
                            focus_percent = {
                                type = "toggle",
                                name = "Показывать процент здоровья |cFFFFD700фокуса|r",
                                desc = "Показывать процент здоровья |cFFFFD700фокуса|r на фрейме",
                                order = 2,
                                width = "full",
                                get = function() return SarychUI.db.profile.modules.frame.showFocusPercent == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.showFocusPercent = v and 1 or 0; ApplyFrameSettings() end,
                            },
                            show_percentages_on_alt = {
                                type = "toggle",
                                name = "Показывать проценты при зажатии |cFFFFD700Alt|r",
                                desc = "Показывать проценты здоровья только при зажатой клавише Alt",
                                order = 3,
                                width = "full",
                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                get = function() return SarychUI.db.profile.modules.frame.showPercentagesOnAlt == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.showPercentagesOnAlt = v and 1 or 0; ApplyFrameSettings() end,
                            },
                        },
                    },
                    classBox = {
                        type = "group",
                        name = "Классовые правила отображения процентов",
                        order = 4,
                        inline = true,
                        args = {
                            warlock_always = {
                                type = "toggle",
                                name = "|cFFFFD700Чернокнижник|r: показывать всегда до порога (%)",
                                desc = "Для |cFFFFD700чернокнижника|r показывать процент здоровья |cFFFFD700цели|r всегда, пока здоровье выше указанного порога",
                                order = 1,
                                width = "full",
                                get = function() return SarychUI.db.profile.modules.frame.warlockAlways == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.warlockAlways = v and 1 or 0; ApplyFrameSettings() end,
                            },
                            warlock_threshold = {
                                type = "range",
                                name = "Порог здоровья |cFFFFD700цели|r (%)",
                                desc = "Пороговое значение здоровья |cFFFFD700цели|r в процентах (1-100)",
                                order = 2,
                                min = 1,
                                max = 100,
                                step = 1,
                                width = "full",
                                disabled = function() return SarychUI.db.profile.modules.frame.warlockAlways ~= 1 end,
                                get = function() return SarychUI.db.profile.modules.frame.warlockThreshold or 25 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.warlockThreshold = v; ApplyFrameSettings() end,
                            },
                        },
                    },
                },
            },

            -- Visual tab
            visual = {
                type = "group",
                name = "Внешний вид",
                order = 5,
                disabled = function() return not isEnabled() end,
                childGroups = "tab",
                args = {
                    -- Frames appearance tab (preview + PVP + portraits)
                    pvp = {
                        type = "group",
                        name = "Фреймы",
                        order = 1,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiFramePvpPreview = true,
                            },
                            hideLevelBox = {
                                type = "group",
                                name = "Скрыть уровень на рамках",
                                order = 1,
                                inline = true,
                                args = {
                                    hide_frame_level = {
                                        type = "toggle",
                                        name = "Включить",
                                        desc = "Скрывает цифру уровня на рамках персонажа, цели и фокуса.",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hideFrameLevel",
                                        get = function() return SarychUI.db.profile.modules.frame.hideFrameLevel == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hideFrameLevel = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                },
                            },
                            classNamesBox = {
                                type = "group",
                                name = "Имена в цвет класса",
                                order = 1.1,
                                inline = true,
                                args = {
                                    class_colored_names = {
                                        type = "toggle",
                                        name = "Включить",
                                        desc = "Окрашивает имена на рамках цели и фокуса в цвет класса персонажа.",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "classColoredNames",
                                        get = function() return SarychUI.db.profile.modules.frame.classColoredNames == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classColoredNames = v and 1 or 0
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    class_colored_names_exclude_player = {
                                        type = "toggle",
                                        name = "Исключить фрейм игрока",
                                        desc = "Не красить имя на рамке игрока. Настройка действует только на цель и фокус.",
                                        order = 2,
                                        width = "full",
                                        hidden = function() return SarychUI.db.profile.modules.frame.classColoredNames ~= 1 end,
                                        suiPreviewKey = "classColoredNamesExcludePlayer",
                                        get = function() return SarychUI.db.profile.modules.frame.classColoredNamesExcludePlayer == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classColoredNamesExcludePlayer = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                            classColorHPBox = {
                                type = "group",
                                name = "Цвет полосы здоровья",
                                desc = "Для работы требуется включённый UnitFrameLayers во вкладке Аддоны.",
                                order = 1.15,
                                inline = true,
                                suiHelpIcon = true,
                                disabled = function() return not IsUnitFrameLayersEnabled() end,
                                args = {
                                    classColorHP = {
                                        type = "toggle",
                                        name = "Цвет класса для полосы здоровья",
                                        desc = "Окрашивает полосу здоровья цели/фокуса (и других игроков) в цвет класса вместо зелёной.",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "classColorHP",
                                        get = function()
                                            local db = UnitFrameLayersDB()
                                            local val = db and db.classColorHP
                                            return val ~= false
                                        end,
                                        set = function(_, value)
                                            local db = UnitFrameLayersDB()
                                            if not db then return end
                                            db.classColorHP = value and true or false
                                            RefreshUnitFrameLayersHealthColors()
                                            RefreshConfig()
                                        end,
                                    },
                                    playerClassColorHP = {
                                        type = "toggle",
                                        name = "Плеер: цвет класса для полосы здоровья",
                                        desc = "Окрашивает полосу здоровья игрока в цвет класса. Если выключено — остаётся зелёной.",
                                        order = 2,
                                        width = "full",
                                        suiPreviewKey = "playerClassColorHP",
                                        -- При выключенном UnitFrameLayers обе галочки остаются видимыми (серыми).
                                        hidden = function()
                                            if not IsUnitFrameLayersEnabled() then
                                                return false
                                            end
                                            local db = UnitFrameLayersDB()
                                            return not db or db.classColorHP == false
                                        end,
                                        disabled = function()
                                            if not IsUnitFrameLayersEnabled() then
                                                return true
                                            end
                                            local db = UnitFrameLayersDB()
                                            return not db or db.classColorHP == false
                                        end,
                                        get = function()
                                            local db = UnitFrameLayersDB()
                                            return db and db.playerClassColorHP == true
                                        end,
                                        set = function(_, value)
                                            local db = UnitFrameLayersDB()
                                            if not db then return end
                                            db.playerClassColorHP = value and true or false
                                            RefreshUnitFrameLayersHealthColors()
                                        end,
                                    },
                                },
                            },
                            restStateBox = {
                                type = "group",
                                name = "Режим отдыха",
                                order = 1.2,
                                inline = true,
                                args = {
                                    hide_player_rest_state = {
                                        type = "toggle",
                                        name = "Скрыть обводку и значок отдыха",
                                        desc = "Скрывает обводку состояния и значок отдыха на рамке игрока. Боевые иконки справа остаются без изменений.",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hidePlayerRestState",
                                        get = function() return SarychUI.db.profile.modules.frame.hidePlayerRestState == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.hidePlayerRestState = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                            nameBgBox = {
                                type = "group",
                                name = "Фон имени",
                                order = 2,
                                inline = true,
                                suiSelectWithColor = true,
                                args = {
                                    enabled = {
                                        type = "toggle",
                                        name = "Включить",
                                        desc = "Заменяет стандартный цветной фон за именем на рамках.",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "nameBackgroundEnabled",
                                        get = function() return SarychUI.db.profile.modules.frame.nameBackgroundEnabled == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.nameBackgroundEnabled = v and 1 or 0
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    mode = {
                                        type = "select",
                                        name = "",
                                        desc = "Изменить фон - свой цвет и прозрачность. Цвет класса - фон в цвет класса персонажа.",
                                        order = 2,
                                        values = {
                                            custom = "Изменить фон",
                                            class = "Цвет класса",
                                            __order = { "custom", "class" },
                                        },
                                        hidden = function() return SarychUI.db.profile.modules.frame.nameBackgroundEnabled ~= 1 end,
                                        suiPreviewKey = "nameBackgroundMode",
                                        get = function() return SarychUI.db.profile.modules.frame.nameBackgroundMode or "custom" end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.nameBackgroundMode = v
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    color = {
                                        type = "color",
                                        name = "",
                                        desc = "Цвет и прозрачность фона за именем. Альфа 0 - фон полностью скрыт.",
                                        hasAlpha = true,
                                        order = 3,
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            return db.nameBackgroundEnabled ~= 1 or db.nameBackgroundMode ~= "custom"
                                        end,
                                        suiPreviewKey = "nameBackgroundColor",
                                        get = function()
                                            local c = SarychUI.db.profile.modules.frame.nameBackgroundColor or { 0, 0, 0, 0 }
                                            local r, g, b, a = c[1], c[2], c[3], c[4]
                                            if r == nil then r = 0 end
                                            if g == nil then g = 0 end
                                            if b == nil then b = 0 end
                                            if a == nil then a = 0 end
                                            return r, g, b, a
                                        end,
                                        set = function(_, r, g, b, a)
                                            SarychUI.db.profile.modules.frame.nameBackgroundColor = { r, g, b, a }
                                            ApplyFrameSettings()
                                        end,
                                    },
                                    excludePlayer = {
                                        type = "toggle",
                                        name = "Исключить фрейм игрока",
                                        desc = "Не менять фон имени на рамке игрока. Настройка действует только на цель и фокус.",
                                        order = 4,
                                        width = "full",
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            return db.nameBackgroundEnabled ~= 1 or db.nameBackgroundMode ~= "class"
                                        end,
                                        suiPreviewKey = "nameBackgroundExcludePlayer",
                                        get = function() return SarychUI.db.profile.modules.frame.nameBackgroundExcludePlayer == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.nameBackgroundExcludePlayer = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                            iconsBox = {
                                type = "group",
                                name = "PVP-иконки",
                                order = 4,
                                inline = true,
                                args = {
                                    hide_player_pvp = {
                                        type = "toggle",
                                        name = "Скрыть PVP-иконки |cFFFFD700игрока|r",
                                        desc = "Скрыть PVP-иконки на фрейме |cFFFFD700игрока|r",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hidePlayerPVP",
                                        get = function() return SarychUI.db.profile.modules.frame.hidePlayerPVP == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hidePlayerPVP = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                    hide_target_pvp = {
                                        type = "toggle",
                                        name = "Скрыть PVP-иконки |cFFFFD700цели|r",
                                        desc = "Скрыть PVP-иконки на фрейме |cFFFFD700цели|r",
                                        order = 2,
                                        width = "full",
                                        suiPreviewKey = "hideTargetPVP",
                                        get = function() return SarychUI.db.profile.modules.frame.hideTargetPVP == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hideTargetPVP = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                    hide_focus_pvp = {
                                        type = "toggle",
                                        name = "Скрыть PVP-иконки |cFFFFD700фокуса|r",
                                        desc = "Скрыть PVP-иконки на фрейме |cFFFFD700фокуса|r",
                                        order = 3,
                                        width = "full",
                                        suiPreviewKey = "hideFocusPVP",
                                        get = function() return SarychUI.db.profile.modules.frame.hideFocusPVP == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hideFocusPVP = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                },
                            },
                            timerBox = {
                                type = "group",
                                name = "PVP-таймер",
                                order = 5,
                                inline = true,
                                args = {
                                    pvp_timer = {
                                        type = "toggle",
                                        name = "Скрыть PVP-таймер",
                                        desc = "Скрыть таймер PVP-статуса",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hidePVPTimer",
                                        get = function() return SarychUI.db.profile.modules.frame.hidePVPTimer == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hidePVPTimer = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                    pvp_timer_on_alt = {
                                        type = "toggle",
                                        name = "Показывать PVP-таймер при зажатии |cFFFFD700Alt|r",
                                        desc = "Показывать PVP-таймер только при зажатой клавише Alt",
                                        order = 2,
                                        width = "full",
                                        suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                        suiPreviewKey = "pvpTimerOnAlt",
                                        disabled = function() return SarychUI.db.profile.modules.frame.hidePVPTimer ~= 1 end,
                                        get = function() return SarychUI.db.profile.modules.frame.pvpTimerOnAlt == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.pvpTimerOnAlt = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                },
                            },
                            portraitsBox = {
                                type = "group",
                                name = "Портреты",
                                order = 6,
                                inline = true,
                                args = {
                                    classIconPortraits = {
                                        type = "toggle",
                                        name = "Использовать иконки класса вместо портретов",
                                        desc = "Для игроков показывает круглую иконку класса вместо портрета. На мобах и NPC не действует (как цвет полосы HP по классу).",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "classIconPortraits",
                                        get = function() return SarychUI.db.profile.modules.frame.classIconPortraits == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconPortraits = v and 1 or 0
                                            ApplyFrameSettings()
                                            -- Rebuild so the player sub-toggle picks up disabled state.
                                            RefreshConfig()
                                        end,
                                    },
                                    classIconPortraitsPlayer = {
                                        type = "toggle",
                                        name = "Иконка класса на фрейме |cFFFFD700игрока|r",
                                        desc = "Заменять портрет на фрейме игрока иконкой класса. Доступно только при включённых иконках класса вместо портретов.",
                                        order = 2,
                                        width = "full",
                                        suiPreviewKey = "classIconPortraitsPlayer",
                                        disabled = function() return SarychUI.db.profile.modules.frame.classIconPortraits ~= 1 end,
                                        get = function() return SarychUI.db.profile.modules.frame.classIconPortraitsPlayer == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconPortraitsPlayer = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                            classIconBox = {
                                type = "group",
                                name = "Иконка класса",
                                desc = "Добавлено по просьбе: Elamaunt",
                                order = 7,
                                inline = true,
                                suiHelpIcon = true,
                                args = {
                                    classIconEnabled = {
                                        type = "toggle",
                                        name = "Включить",
                                        desc = "Показывает круглую иконку класса на фреймах игрока, цели и фокуса. На мобов и NPC не действует.",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "classIconEnabled",
                                        get = function() return SarychUI.db.profile.modules.frame.classIconEnabled == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconEnabled = v and 1 or 0
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    classIconMode = {
                                        type = "select",
                                        name = "",
                                        desc = "Вместо уровня прячет цифру и ставит иконку в кружок уровня. Отдельно оставляет уровень и ставит такой же кружок рядом с ним.",
                                        order = 2,
                                        width = "full",
                                        values = {
                                            replace = "Показывать иконку класса вместо уровня",
                                            separate = "Показывать отдельно иконку класса",
                                            __order = { "replace", "separate" },
                                        },
                                        hidden = function() return SarychUI.db.profile.modules.frame.classIconEnabled ~= 1 end,
                                        suiPreviewKey = "classIconMode",
                                        get = function() return SarychUI.db.profile.modules.frame.classIconMode or "replace" end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconMode = v
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    classIconPlayer = {
                                        type = "toggle",
                                        name = "Иконка класса на фрейме |cFFFFD700игрока|r",
                                        desc = "Показывать иконку класса на фрейме игрока. Если выключено, настройка действует только на цель и фокус.",
                                        order = 3,
                                        width = "full",
                                        suiPreviewKey = "classIconPlayer",
                                        disabled = function() return SarychUI.db.profile.modules.frame.classIconEnabled ~= 1 end,
                                        get = function() return SarychUI.db.profile.modules.frame.classIconPlayer ~= 0 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconPlayer = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                    classIconX = {
                                        type = "range",
                                        name = "Смещение по X",
                                        desc = "Сдвиг иконки класса по горизонтали от кружка уровня. Вправо — плюс, влево — минус.",
                                        min = -80, max = 80, step = 1,
                                        order = 4,
                                        width = "full",
                                        suiPreviewKey = "classIconX",
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            return db.classIconEnabled ~= 1 or (db.classIconMode or "replace") ~= "separate"
                                        end,
                                        get = function()
                                            local v = SarychUI.db.profile.modules.frame.classIconX
                                            if v == nil then return -73 end
                                            return v
                                        end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconX = v
                                            ApplyFrameSettings()
                                        end,
                                    },
                                    classIconY = {
                                        type = "range",
                                        name = "Смещение по Y",
                                        desc = "Сдвиг иконки класса по вертикали от кружка уровня. Вверх — плюс, вниз — минус.",
                                        min = -80, max = 80, step = 1,
                                        order = 5,
                                        width = "full",
                                        suiPreviewKey = "classIconY",
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            return db.classIconEnabled ~= 1 or (db.classIconMode or "replace") ~= "separate"
                                        end,
                                        get = function()
                                            local v = SarychUI.db.profile.modules.frame.classIconY
                                            if v == nil then return 43 end
                                            return v
                                        end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconY = v
                                            ApplyFrameSettings()
                                        end,
                                    },
                                    classIconMaxLevelOnly = {
                                        type = "toggle",
                                        name = "Только если максимальный уровень",
                                        desc = "Заменять уровень иконкой класса только у персонажей максимального уровня.",
                                        order = 6,
                                        width = "full",
                                        suiPreviewKey = "classIconMaxLevelOnly",
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            return db.classIconEnabled ~= 1 or (db.classIconMode or "replace") == "separate"
                                        end,
                                        get = function() return SarychUI.db.profile.modules.frame.classIconMaxLevelOnly == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconMaxLevelOnly = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- Pets tab
                    pets = {
                        type = "group",
                        name = "Питомцы",
                        order = 2,
                        args = {
                            petsBox = {
                                type = "group",
                                name = " ",
                                order = 1,
                                inline = true,
                                args = {
                                    enablePetNameShortening = {
                                        type = "toggle",
                                        name = "Сокращение длинных имён питомцев",
                                        desc = "Сокращает слишком длинные имена питомцев для лучшей читаемости",
                                        order = 1,
                                        width = "full",
                                        get = function()
                                            return SarychUI.db.profile.modules.frame.enablePetNameShortening == 1
                                        end,
                                        set = function(_, val)
                                            SarychUI.db.profile.modules.frame.enablePetNameShortening = val and 1 or 0
                                            local toolsModule = SarychUI:GetModule("tools", true)
                                            if toolsModule and toolsModule.ApplyPetNameShortening then
                                                toolsModule:ApplyPetNameShortening()
                                            end
                                        end,
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end
