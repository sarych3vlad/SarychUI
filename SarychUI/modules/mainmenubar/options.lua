-- SarychUI MainMenuBar Module Options
-- Options interface for main menu bar customization

local moduleName = "mainmenubar"
local L = SarychUI.L

local function NotifyOptionsChange()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local INDICATION_COLOR_DEFAULTS = {
    colorCooldownColor = { 0.4, 0.4, 0.4, 0.6 },
    colorManaColor = { 0.1, 0.1, 1.0, 1.0 },
    colorRangeColor = { 0.8, 0.2, 0.2, 1.0 },
    colorUnusableColor = { 0.2, 0.2, 0.2, 1.0 },
}

local function GetIndicationColor(key)
    local db = SarychUI.db.profile.modules.mainmenubar
    local color = db[key]
    local defaults = INDICATION_COLOR_DEFAULTS[key]
    local r = type(color) == "table" and color[1] or nil
    local g = type(color) == "table" and color[2] or nil
    local b = type(color) == "table" and color[3] or nil
    local a = type(color) == "table" and color[4] or nil
    if r == nil then r = defaults[1] end
    if g == nil then g = defaults[2] end
    if b == nil then b = defaults[3] end
    if a == nil and key == "colorCooldownColor" then
        a = db.colorCooldownAlpha
    end
    if a == nil then a = defaults[4] end
    return r, g, b, a
end

local function SetIndicationColor(key, r, g, b, a)
    local db = SarychUI.db.profile.modules.mainmenubar
    db[key] = { r, g, b, a }
    -- Keep the retired standalone cooldown-alpha value synchronized for old
    -- profiles and external consumers that may still read it.
    if key == "colorCooldownColor" then
        db.colorCooldownAlpha = a
    end
    if SarychUI.modules and SarychUI.modules.mainmenubar then
        SarychUI.modules.mainmenubar:UpdateColorIndication()
    end
    if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
        SarychUI.ActionBarColorPreview:RefreshAll()
    end
end

--------------------------------------------------------------------
-- FrostAtomUI action bars (barMode == "frostatom")
--------------------------------------------------------------------
local function FA()
    return SarychUI.FrostAtomBars
end

local function IsFrostSelected()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
        and SarychUI.db.profile.modules.mainmenubar
    return db ~= nil and db.barMode == "frostatom"
end

local function FADB()
    local db = SarychUI.db.profile.modules.mainmenubar
    return db.frostatom
end

local function FABar(key)
    local fa = FA()
    if fa and fa.BarConfig then
        return fa.BarConfig(key)
    end
    return FADB()[key]
end

-- Re-layout live bars (only when the session runs FrostAtomUI bars).
local function FAApply(key)
    local fa = FA()
    if fa and fa.IsActive and fa.IsActive() and fa.IsInitialized and fa.IsInitialized() then
        fa.Refresh(key)
    end
end

local function FADisabled()
    return not SarychUI.db.profile.modules.mainmenubar.enabled
end

local VISIBILITY_VALUES = {
    any = "Всегда",
    combat = "В бою",
    nocombat = "Вне боя",
    __order = { "any", "combat", "nocombat" },
}

local DRAG_BUTTON_VALUES = {
    LeftButton = "Левая кнопка",
    RightButton = "Правая кнопка",
    MiddleButton = "Средняя кнопка",
    __order = { "LeftButton", "RightButton", "MiddleButton" },
}

local DRAG_MODIFIER_VALUES = {
    none = "Без модификатора",
    shift = "Shift",
    ctrl = "Ctrl",
    alt = "Alt",
    __order = { "none", "shift", "ctrl", "alt" },
}

local CLASS_PAGE_SPELLS = {
    WARRIOR = { [7] = 2457, [8] = 71, [9] = 2458 },
    DRUID = { [7] = 768, [8] = 5215, [9] = 5487, [10] = 24858 },
    ROGUE = { [7] = 1784, [8] = 51713 },
    PRIEST = { [7] = 15473 },
}

local function PageOwner(page)
    local class = select(2, UnitClass("player"))
    local spells = CLASS_PAGE_SPELLS[class]
    local spell = spells and spells[page]
    return spell and GetSpellInfo(spell)
end

local function PageLabel(page)
    local owner = PageOwner(page)
    if owner then
        return SarychUI:T("Страница %d (%s)", page, owner)
    end
    return SarychUI:T("Страница %d", page)
end

-- Positioning block: X / Y + free move button (PositionDragPanel).
local function FAPositionArgs(key, orderBase)
    local function bar() return FABar(key) end
    return {
        posHeader = {
            type = "header",
            name = "Расположение",
            order = orderBase,
        },
        offsetX = {
            type = "range",
            name = "Смещение по X",
            min = -1600, max = 1600, step = 1,
            order = orderBase + 1,
            get = function() local t = bar() return t and t.x or 0 end,
            set = function(_, v)
                local t = bar()
                if not t then return end
                t.x = v
                FAApply(key)
            end,
        },
        offsetY = {
            type = "range",
            name = "Смещение по Y",
            min = -1600, max = 1600, step = 1,
            order = orderBase + 2,
            get = function() local t = bar() return t and t.y or 0 end,
            set = function(_, v)
                local t = bar()
                if not t then return end
                t.y = v
                FAApply(key)
            end,
        },
        freeMove = {
            type = "execute",
            name = function()
                local t = bar()
                if t and t.showDragFrame == 1 then
                    return "Свободное перемещение |cff00ff00(вкл)|r"
                end
                return "Свободное перемещение"
            end,
            desc = "Показать рамку и окошко для перетаскивания панели мышью.",
            order = orderBase + 3,
            width = "full",
            suiFullRow = true,
            disabled = function()
                local fa = FA()
                return FADisabled() or not (fa and fa.IsActive and fa.IsActive() and fa.IsInitialized and fa.IsInitialized())
            end,
            func = function()
                local fa = FA()
                if fa and fa.ToggleDrag then
                    fa.ToggleDrag(key)
                end
                NotifyOptionsChange()
            end,
        },
    }
end

local function ToolsDB()
    local mods = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
    return mods and mods.tools
end

local function ToolsModule()
    return SarychUI.modules and SarychUI.modules.tools
end

local function ToolsFpsArgs()
    return {
        enableAltFPS = {
            type = "toggle",
            name = "Показывать FPS при зажатом |cFFFFD700Alt|r",
            desc = "Показывает FPS в левом верхнем углу при зажатой клавише |cFFFFD700Alt|r",
            order = 1,
            width = "full",
            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
            get = function()
                local db = ToolsDB()
                local v = db and db.enableAltFPS
                return v == 1 or v == true
            end,
            set = function(_, val)
                local db = ToolsDB(); if not db then return end
                db.enableAltFPS = val and 1 or 0
                local tools = ToolsModule()
                if tools and tools.ApplyAltFPS then tools:ApplyAltFPS() end
                NotifyOptionsChange()
            end,
        },
        fpsScale = {
            type = "range",
            name = "Масштаб FPS",
            desc = "Размер FPS-индикатора при зажатом |cFFFFD700Alt|r (0.50 - 2.00)",
            order = 2,
            width = "full",
            suiFullRow = true,
            min = 0.5, max = 2.0, step = 0.05,
            get = function()
                local db = ToolsDB()
                return (db and db.fpsScale) or 1.0
            end,
            set = function(_, val)
                local db = ToolsDB(); if not db then return end
                db.fpsScale = val
                local tools = ToolsModule()
                if tools and tools.ApplyFpsScale then tools:ApplyFpsScale() end
            end,
            disabled = function()
                local db = ToolsDB()
                local v = db and db.enableAltFPS
                return not (v == 1 or v == true)
            end,
        },
        fpsExtraOffsetX = {
            type = "range",
            name = "Смещение по X",
            desc = "Дополнительное горизонтальное смещение FPS-индикатора относительно базовой позиции",
            order = 3,
            min = -300, max = 300, step = 1,
            get = function()
                local db = ToolsDB()
                return (db and db.fpsExtraOffsetX) or 0
            end,
            set = function(_, val)
                local db = ToolsDB(); if not db then return end
                db.fpsExtraOffsetX = val
                local tools = ToolsModule()
                if tools and tools.SetFpsPosition then tools:SetFpsPosition() end
            end,
            disabled = function()
                local db = ToolsDB()
                local v = db and db.enableAltFPS
                return not (v == 1 or v == true)
            end,
        },
        fpsExtraOffsetY = {
            type = "range",
            name = "Смещение по Y",
            desc = "Дополнительное вертикальное смещение FPS-индикатора относительно базовой позиции",
            order = 4,
            min = -300, max = 300, step = 1,
            get = function()
                local db = ToolsDB()
                return (db and db.fpsExtraOffsetY) or 0
            end,
            set = function(_, val)
                local db = ToolsDB(); if not db then return end
                db.fpsExtraOffsetY = val
                local tools = ToolsModule()
                if tools and tools.SetFpsPosition then tools:SetFpsPosition() end
            end,
            disabled = function()
                local db = ToolsDB()
                local v = db and db.enableAltFPS
                return not (v == 1 or v == true)
            end,
        },
    }
end

-- Visibility block: mouseover / combat / faded alpha.
local function FAVisibilityArgs(key, orderBase)
    local function bar() return FABar(key) end
    return {
        visHeader = {
            type = "header",
            name = "Видимость",
            order = orderBase,
        },
        mouseover = {
            type = "toggle",
            name = "Показывать при наведении",
            desc = "Панель приглушена и проявляется, когда курсор над ней или когда на курсоре заклинание.",
            order = orderBase + 1,
            width = "full",
            suiFullRow = true,
            get = function() local t = bar() return t and t.mouseover end,
            set = function(_, v)
                local t = bar()
                if not t then return end
                t.mouseover = v and true or false
                FAApply(key)
                NotifyOptionsChange()
            end,
        },
        combat = {
            type = "select",
            name = "Показывать",
            desc = "Приглушать вне боя или в бою. При показе по наведению курсор всё равно проявляет панель.",
            order = orderBase + 2,
            values = VISIBILITY_VALUES,
            get = function() local t = bar() return t and t.combat or "any" end,
            set = function(_, v)
                local t = bar()
                if not t then return end
                t.combat = v
                FAApply(key)
                NotifyOptionsChange()
            end,
        },
        fadeAlpha = {
            type = "range",
            name = "Прозрачность в приглушении",
            desc = "Прозрачность панели, пока она приглушена из-за наведения или видимости в бою.",
            min = 0, max = 1, step = 0.05,
            order = orderBase + 3,
            disabled = function()
                local t = bar()
                return FADisabled() or not t or (not t.mouseover and (t.combat or "any") == "any")
            end,
            get = function() local t = bar() return t and t.fadeAlpha or 0.1 end,
            set = function(_, v)
                local t = bar()
                if not t then return end
                t.fadeAlpha = v
                FAApply(key)
            end,
        },
    }
end

-- Full bar block (size / layout + visibility + position).
-- opts: showEnabled, showButtons, maxColumns, removable(page)
local function FABarArgs(key, opts)
    opts = opts or {}
    local function bar() return FABar(key) end
    local args = {}

    if opts.showEnabled then
        args.enabled = {
            type = "toggle",
            name = "Показывать панель",
            order = 1,
            width = "full",
            suiFullRow = true,
            get = function() local t = bar() return t and t.enabled ~= false end,
            set = function(_, v)
                local t = bar()
                if not t then return end
                t.enabled = v and true or false
                if not v then
                    local fa = FA()
                    if fa and fa.CloseDrag then fa.CloseDrag(key) end
                end
                FAApply(key)
                NotifyOptionsChange()
            end,
        }
    end

    args.sizeHeader = {
        type = "header",
        name = "Размер и раскладка",
        order = 5,
    }
    if opts.showButtons then
        args.buttons = {
            type = "range",
            name = "Кнопок",
            min = 1, max = 12, step = 1,
            order = 6,
            get = function() local t = bar() return t and t.buttons or 12 end,
            set = function(_, v)
                local t = bar()
                if not t then return end
                t.buttons = v
                if t.columns and t.columns > v then t.columns = v end
                FAApply(key)
            end,
        }
    end
    args.buttonSize = {
        type = "range",
        name = "Размер кнопки",
        min = 16, max = 64, step = 1,
        order = 7,
        get = function() local t = bar() return t and t.buttonSize or 36 end,
        set = function(_, v)
            local t = bar()
            if not t then return end
            t.buttonSize = v
            FAApply(key)
        end,
    }
    args.columns = {
        type = "range",
        name = "Колонок",
        desc = "Кнопок в ряду. Остальные переносятся на следующие ряды.",
        min = 1, max = opts.maxColumns or 12, step = 1,
        order = 8,
        get = function() local t = bar() return t and t.columns or 12 end,
        set = function(_, v)
            local t = bar()
            if not t then return end
            t.columns = v
            FAApply(key)
        end,
    }
    args.spacing = {
        type = "range",
        name = "Отступ",
        min = 0, max = 16, step = 1,
        order = 9,
        get = function() local t = bar() return t and t.spacing or 2 end,
        set = function(_, v)
            local t = bar()
            if not t then return end
            t.spacing = v
            FAApply(key)
        end,
    }

    for k, v in pairs(FAVisibilityArgs(key, 20)) do args[k] = v end
    for k, v in pairs(FAPositionArgs(key, 30)) do args[k] = v end

    if opts.removable then
        local page = opts.removable
        args.remove = {
            type = "execute",
            name = "Удалить панель",
            desc = function()
                local owner = PageOwner(page)
                if owner then
                    return SarychUI:T("Страница действий %d - команды формы «%s». Привязки клавиш её кнопок будут сброшены.", page, owner)
                end
                return SarychUI:T("Страница действий %d. Привязки клавиш её кнопок будут сброшены.", page)
            end,
            order = 40,
            width = "full",
            suiFullRow = true,
            confirm = true,
            confirmText = ("Удалить панель команд %d? Привязки клавиш её кнопок будут сброшены."):format(page),
            func = function()
                if InCombatLockdown() then
                    print(SarychUI:T("|cffffd200SarychUI:|r нельзя менять привязки клавиш в бою"))
                    return
                end
                local fa = FA()
                if fa and fa.CloseDrag then fa.CloseDrag(key) end
                -- Clear CLICK bindings of this page's buttons.
                local first = (page - 1) * 12
                for i = 1, 12 do
                    local command = ("CLICK SarychUIActionButton%d:LeftButton"):format(first + i)
                    local k = GetBindingKey(command)
                    local guard = 0
                    while k and guard < 10 do
                        SetBinding(k)
                        k = GetBindingKey(command)
                        guard = guard + 1
                    end
                end
                SaveBindings(GetCurrentBindingSet())
                FADB().extraBars[key] = nil
                FAApply("extraBars")
                NotifyOptionsChange()
            end,
        }
    end

    return args
end

local function BarTab(key, order, name, opts)
    return {
        type = "group",
        name = name,
        order = order,
        disabled = FADisabled,
        args = {
            box = {
                type = "group",
                name = name,
                order = 1,
                inline = true,
                suiTwoCol = true,
                args = FABarArgs(key, opts),
            },
        },
    }
end

local function ExtraBarsArgs()
    local args = {}
    args.addBar = {
        type = "select",
        name = "Добавить панель",
        desc = "Ещё одна панель на свободной странице действий (7-10). Страница вашей стойки или формы показывает команды этой стойки или формы.",
        order = 1,
        width = "full",
        values = function()
            local values = { __order = {} }
            local extra = FADB().extraBars or {}
            for page = 7, 10 do
                if not extra["bar" .. page] then
                    values[tostring(page)] = PageLabel(page)
                    values.__order[#values.__order + 1] = tostring(page)
                end
            end
            if #values.__order == 0 then
                values.none = "Все свободные страницы заняты"
                values.__order[1] = "none"
            end
            return values
        end,
        get = function() return nil end,
        set = function(_, v)
            local page = tonumber(v)
            if not page then return end
            local fa = FA()
            local extra = FADB().extraBars
            if not extra then
                FADB().extraBars = {}
                extra = FADB().extraBars
            end
            if fa and fa.ActionBar and fa.ActionBar.NewExtraBar then
                extra["bar" .. page] = fa.ActionBar.NewExtraBar(page)
            else
                extra["bar" .. page] = {
                    enabled = true, point = "CENTER", relativePoint = "CENTER", x = 0, y = (7 - page) * 40,
                    buttons = 12, columns = 12, buttonSize = 36, spacing = 2,
                    mouseover = false, combat = "any", fadeAlpha = 0.1,
                }
            end
            FAApply("extraBars")
            NotifyOptionsChange()
        end,
    }
    args.hint = {
        type = "description",
        name = "Панели 7-10 используют запасные страницы действий. У воинов, друидов, разбойников и жрецов часть страниц занята стойками и формами - такая панель покажет команды этой стойки.",
        order = 2,
        width = "full",
    }
    for page = 7, 10 do
        local key = "bar" .. page
        args[key] = {
            type = "group",
            name = ("Панель команд %d"):format(page),
            order = 10 + page,
            inline = true,
            suiTwoCol = true,
            hidden = function()
                local extra = FADB().extraBars
                return not (extra and extra[key])
            end,
            args = FABarArgs(key, { showEnabled = true, showButtons = true, removable = page }),
        }
    end
    return args
end

local function BuildFrostBarsTab()
    return {
        type = "group",
        name = "Панели",
        order = 2,
        hidden = function() return not IsFrostSelected() end,
        disabled = FADisabled,
        childGroups = "tab",
        args = {
            bar1 = BarTab("bar1", 1, "Панель 1", { showButtons = true }),
            bar2 = BarTab("bar2", 2, "Панель 2", { showEnabled = true, showButtons = true }),
            bar3 = BarTab("bar3", 3, "Панель 3", { showEnabled = true, showButtons = true }),
            bar4 = BarTab("bar4", 4, "Панель 4", { showEnabled = true, showButtons = true }),
            bar5 = BarTab("bar5", 5, "Панель 5", { showEnabled = true, showButtons = true }),
            bar6 = BarTab("bar6", 6, "Панель 6", { showEnabled = true, showButtons = true }),
            extra = {
                type = "group",
                name = "Доп. панели",
                order = 7,
                disabled = FADisabled,
                args = ExtraBarsArgs(),
            },
        },
    }
end

local function BuildFrostOtherTab()
    local totemArgs = FABarArgs("totemBar", { showEnabled = true, maxColumns = 6 })
    totemArgs.flyoutHeader = {
        type = "header",
        name = "Выпадающий список тотемов",
        order = 12,
    }
    totemArgs.flyoutButtonSize = {
        type = "range",
        name = "Размер кнопки списка",
        min = 16, max = 48, step = 1,
        order = 13,
        get = function() return FABar("totemBar").flyoutButtonSize or 24 end,
        set = function(_, v) FABar("totemBar").flyoutButtonSize = v FAApply("totemBar") end,
    }
    totemArgs.flyoutSpacing = {
        type = "range",
        name = "Отступ в списке",
        min = 0, max = 10, step = 1,
        order = 14,
        get = function() return FABar("totemBar").flyoutSpacing or 2 end,
        set = function(_, v) FABar("totemBar").flyoutSpacing = v FAApply("totemBar") end,
    }
    totemArgs.flyoutRows = {
        type = "range",
        name = "Кнопок в колонке списка",
        min = 1, max = 20, step = 1,
        order = 15,
        get = function() return FABar("totemBar").flyoutRows or 10 end,
        set = function(_, v) FABar("totemBar").flyoutRows = v FAApply("totemBar") end,
    }

    local vehicleArgs = {
        buttonSize = {
            type = "range",
            name = "Размер кнопки",
            min = 16, max = 64, step = 1,
            order = 1,
            get = function() return FABar("vehicleExit").buttonSize or 32 end,
            set = function(_, v) FABar("vehicleExit").buttonSize = v FAApply("vehicleExit") end,
        },
    }
	for k, v in pairs(FAPositionArgs("vehicleExit", 30)) do vehicleArgs[k] = v end

	local experienceArgs = {
		enabled = {
			type = "toggle",
			name = "Показывать полосу",
			order = 1,
			width = "full",
			suiFullRow = true,
			get = function() return FABar("experienceBar").enabled ~= false end,
			set = function(_, v)
				FABar("experienceBar").enabled = v and true or false
				if not v then
					local fa = FA()
					if fa and fa.CloseDrag then fa.CloseDrag("experienceBar") end
				end
				FAApply("experienceBar")
			end,
		},
		showReputation = {
			type = "toggle",
			name = "Репутация на максимальном уровне",
			desc = "Показывать отслеживаемую репутацию вместо опыта на максимальном уровне.",
			order = 2,
			width = "full",
			suiFullRow = true,
			get = function() return FABar("experienceBar").showReputation ~= false end,
			set = function(_, v)
				FABar("experienceBar").showReputation = v and true or false
				FAApply("experienceBar")
			end,
		},
		width = {
			type = "range",
			name = "Ширина",
			min = 100, max = 1200, step = 1,
			order = 5,
			get = function() return FABar("experienceBar").width or 456 end,
			set = function(_, v) FABar("experienceBar").width = v FAApply("experienceBar") end,
		},
		height = {
			type = "range",
			name = "Высота",
			min = 2, max = 30, step = 1,
			order = 6,
			get = function() return FABar("experienceBar").height or 5 end,
			set = function(_, v) FABar("experienceBar").height = v FAApply("experienceBar") end,
		},
	}
	for k, v in pairs(FAPositionArgs("experienceBar", 30)) do experienceArgs[k] = v end

    return {
        type = "group",
        name = "Другие панели",
        order = 3,
        hidden = function() return not IsFrostSelected() end,
        disabled = FADisabled,
        childGroups = "tab",
        args = {
            stance = {
                type = "group",
                name = "Стойки",
                order = 1,
                args = {
                    box = {
                        type = "group",
                        name = "Панель стоек",
                        order = 1,
                        inline = true,
                        suiTwoCol = true,
                        args = FABarArgs("stance", { maxColumns = 10 }),
                    },
                    hint = {
                        type = "description",
                        name = "Панель растёт вправо от левого края: число стоек и форм зависит от класса и талантов. Привязки клавиш стоек включаются во вкладке «Настройки».",
                        order = 2,
                        width = "full",
                    },
                },
            },
            pet = {
                type = "group",
                name = "Питомец",
                order = 2,
                args = {
                    box = {
                        type = "group",
                        name = "Панель питомца",
                        order = 1,
                        inline = true,
                        suiTwoCol = true,
                        args = FABarArgs("pet", { maxColumns = 10 }),
                    },
                },
            },
            totem = {
                type = "group",
                name = "Тотемы",
                order = 3,
                hidden = function() return select(2, UnitClass("player")) ~= "SHAMAN" end,
                args = {
                    box = {
                        type = "group",
                        name = "Панель тотемов",
                        order = 1,
                        inline = true,
                        suiTwoCol = true,
                        args = totemArgs,
                    },
                },
            },
			vehicle = {
                type = "group",
                name = "Транспорт",
                order = 4,
                args = {
                    box = {
                        type = "group",
                        name = "Кнопка выхода из транспорта",
                        order = 1,
                        inline = true,
                        suiTwoCol = true,
                        args = vehicleArgs,
				},
			},
			experience = {
				type = "group",
				name = "Опыт / репутация",
				order = 5,
				args = {
					box = {
						type = "group",
						name = "Полоса опыта и репутации",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = experienceArgs,
					},
				},
			},
		},
        },
    }
end

local function BuildFrostMenusTab()
    local microArgs = {
        microMenuScale = {
            type = "range",
            name = "Масштаб",
            min = 0.5, max = 2, step = 0.05,
            order = 1,
            get = function() return FADB().microMenuScale or 1 end,
            set = function(_, v)
                FADB().microMenuScale = v
                FAApply("microMenuScale")
            end,
        },
        visHeader = { type = "header", name = "Видимость", order = 10 },
        microMenuMouseover = {
            type = "toggle",
            name = "Показывать при наведении",
            order = 11,
            width = "full",
            suiFullRow = true,
            get = function() return FADB().microMenuMouseover end,
            set = function(_, v)
                FADB().microMenuMouseover = v and true or false
                FAApply("menus")
                NotifyOptionsChange()
            end,
        },
        microMenuCombat = {
            type = "select",
            name = "Показывать",
            order = 12,
            values = VISIBILITY_VALUES,
            get = function() return FADB().microMenuCombat or "any" end,
            set = function(_, v)
                FADB().microMenuCombat = v
                FAApply("menus")
                NotifyOptionsChange()
            end,
        },
    }
    for k, v in pairs(FAPositionArgs("microMenu", 30)) do microArgs[k] = v end

    local bagArgs = {
        showKeyRing = {
            type = "toggle",
            name = "Показывать связку ключей",
            desc = "Кнопка связки ключей слева от кнопки сумки.",
            order = 1,
            width = "full",
            suiFullRow = true,
            get = function() return FADB().showKeyRing and true or false end,
            set = function(_, v)
                FADB().showKeyRing = v and true or false
                FAApply("menus")
            end,
        },
        visHeader = { type = "header", name = "Видимость", order = 10 },
        bagButtonMouseover = {
            type = "toggle",
            name = "Показывать при наведении",
            order = 11,
            width = "full",
            suiFullRow = true,
            get = function() return FADB().bagButtonMouseover end,
            set = function(_, v)
                FADB().bagButtonMouseover = v and true or false
                FAApply("menus")
                NotifyOptionsChange()
            end,
        },
        bagButtonCombat = {
            type = "select",
            name = "Показывать",
            order = 12,
            values = VISIBILITY_VALUES,
            get = function() return FADB().bagButtonCombat or "any" end,
            set = function(_, v)
                FADB().bagButtonCombat = v
                FAApply("menus")
                NotifyOptionsChange()
            end,
        },
    }
    for k, v in pairs(FAPositionArgs("bagButton", 30)) do bagArgs[k] = v end

    return {
        type = "group",
        name = "Микроменю и сумки",
        order = 4,
        hidden = function() return not IsFrostSelected() end,
        disabled = FADisabled,
        args = {
            styleBox = {
                type = "group",
                name = "Внешний вид",
                order = 1,
                inline = true,
                args = {
                    microMenuStyle = {
                        type = "select",
                        name = "Внешний вид кнопок",
                        desc = "Текстуры кнопок микроменю. Расположение и размер не меняются.",
                        order = 1,
                        width = "full",
                        values = {
                            classic = "Классические",
                            dragonflight = "Dragonflight",
                            __order = { "classic", "dragonflight" },
                        },
                        get = function()
                            return SarychUI.db.profile.modules.mainmenubar.microMenuStyle or "dragonflight"
                        end,
                        set = function(_, value)
                            local db = SarychUI.db.profile.modules.mainmenubar
                            local previous = db.microMenuStyle or "dragonflight"
                            if previous == value then return end
                            db.microMenuStyle = value
                            if SarychUI.modules and SarychUI.modules.mainmenubar then
                                if SarychUI.modules.mainmenubar.ApplyMicroMenuStyle then
                                    SarychUI.modules.mainmenubar:ApplyMicroMenuStyle()
                                else
                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                end
                            end
                            NotifyOptionsChange()
                            local function revert()
                                db.microMenuStyle = previous
                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                    if SarychUI.modules.mainmenubar.ApplyMicroMenuStyle then
                                        SarychUI.modules.mainmenubar:ApplyMicroMenuStyle()
                                    else
                                        SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                    end
                                end
                                NotifyOptionsChange()
                            end
                            if SarychUI.ShowReloadPopup then
                                SarychUI:ShowReloadPopup("Для применения внешнего вида микроменю требуется перезагрузка интерфейса.", revert)
                            elseif StaticPopup_Show then
                                StaticPopup_Show("SARYCHUI_RELOAD_UI")
                            end
                        end,
                    },
                    microMenuHideGreenLatency = {
                        type = "toggle",
                        name = "Скрывать индикатор при зелёной сети",
                        desc = "Прячет индикатор задержки на кнопке меню, пока пинг зелёный. При жёлтом или красном - показывает. Только для внешнего вида Dragonflight.",
                        order = 2,
                        width = "full",
                        hidden = function()
                            local db = SarychUI.db.profile.modules.mainmenubar
                            return (db.microMenuStyle or "dragonflight") ~= "dragonflight"
                        end,
                        get = function()
                            local db = SarychUI.db.profile.modules.mainmenubar
                            return db.microMenuHideGreenLatency ~= false
                        end,
                        set = function(_, value)
                            SarychUI.db.profile.modules.mainmenubar.microMenuHideGreenLatency = value and true or false
                            if SarychUI.modules and SarychUI.modules.mainmenubar then
                                if SarychUI.modules.mainmenubar.ApplyMicroMenuStyle then
                                    SarychUI.modules.mainmenubar:ApplyMicroMenuStyle()
                                else
                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                end
                            end
                        end,
                    },
                },
            },
            microBox = {
                type = "group",
                name = "Микроменю",
                order = 2,
                inline = true,
                suiTwoCol = true,
                args = microArgs,
            },
            bagBox = {
                type = "group",
                name = "Кнопка сумки",
                order = 3,
                inline = true,
                suiTwoCol = true,
                args = bagArgs,
            },
            fadeBox = {
                type = "group",
                name = "Приглушение",
                order = 4,
                inline = true,
                suiTwoCol = true,
                args = {
                    menuFadeAlpha = {
                        type = "range",
                        name = "Прозрачность в приглушении (микроменю, сумка)",
                        desc = "Используется только при показе по наведению или когда видимость не «Всегда».",
                        min = 0, max = 1, step = 0.05,
                        order = 1,
                        width = "full",
                        suiFullRow = true,
                        get = function() return FADB().menuFadeAlpha or 0.1 end,
                        set = function(_, v)
                            FADB().menuFadeAlpha = v
                            FAApply("menus")
                        end,
                    },
                },
            },
        },
    }
end

local function BuildFrostSettingsTab()
    local function toggle(key, name, desc, order, refreshKey, extraSet)
        return {
            type = "toggle",
            name = name,
            desc = desc,
            order = order,
            width = "full",
            suiFullRow = true,
            get = function() return FADB()[key] and true or false end,
            set = function(_, v)
                FADB()[key] = v and true or false
                if extraSet then extraSet(v) end
                FAApply(refreshKey or "buttons")
                NotifyOptionsChange()
            end,
        }
    end

    return {
        type = "group",
        name = "Настройки",
        order = 5,
        hidden = function() return not IsFrostSelected() end,
        disabled = FADisabled,
        args = {
            bindBox = {
                        type = "group",
                        name = "Привязка клавиш",
                        order = 1,
                        inline = true,
                        args = {
                            bind = {
                                type = "execute",
                                name = "Назначить клавиши",
                                desc = "Режим привязки: наведите курсор на кнопку и нажмите клавишу. Escape снимает привязки с кнопки. Команда: /suibind",
                                order = 1,
                                width = "full",
                                suiFullRow = true,
                                disabled = function()
                                    local fa = FA()
                                    return FADisabled() or not (fa and fa.IsActive and fa.IsActive() and fa.IsInitialized and fa.IsInitialized())
                                end,
                                func = function()
                                    local fa = FA()
                                    if fa and fa.ActionBar and fa.ActionBar.ToggleBindMode then
                                        fa.ActionBar:ToggleBindMode()
                                    end
                                end,
                            },
                            bindHint = {
                                type = "description",
                                name = "Стандартные привязки Blizzard (панели 1-6, питомец) продолжают работать и переносятся на новые кнопки автоматически.",
                                order = 2,
                                width = "full",
                            },
                        },
                    },
                    behaviorBox = {
                        type = "group",
                        name = "Поведение",
                        order = 2,
                        inline = true,
                        suiTwoCol = true,
                        args = {
                            hideEmptyButtons = toggle("hideEmptyButtons", "Скрывать пустые кнопки", "Пустые ячейки показываются только при перетаскивании заклинания и в режиме привязки.", 1),
                            dragButton = {
                                type = "select",
                                name = "Перетаскивать кнопкой",
                                desc = "Какой кнопкой мыши перетаскивать заклинания с панелей.",
                                order = 2,
                                values = DRAG_BUTTON_VALUES,
                                get = function() return FADB().dragButton or "RightButton" end,
                                set = function(_, v)
                                    FADB().dragButton = v
                                    FAApply("buttons")
                                end,
                            },
                            dragModifier = {
                                type = "select",
                                name = "Модификатор перетаскивания",
                                desc = "Клавиша, которую нужно удерживать, чтобы перетащить заклинание.",
                                order = 3,
                                values = DRAG_MODIFIER_VALUES,
                                get = function() return FADB().dragModifier or "none" end,
                                set = function(_, v)
                                    FADB().dragModifier = v
                                end,
                            },
                        },
                    },
                    borderBox = {
                        type = "group",
                        name = "Обводка кнопок",
                        order = 3,
                        inline = true,
                        args = {
                            buttonBorderAlpha = {
                                type = "range",
                                name = L["Button_Border_Alpha"],
                                desc = L["Button_Border_Alpha_Desc"],
                                order = 1,
                                min = 0,
                                max = 1,
                                step = 0.05,
                                width = "full",
                                suiFullRow = true,
                                get = function()
                                    return SarychUI.db.profile.modules.mainmenubar.buttonBorderAlpha or 0.4
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules.mainmenubar
                                    db.buttonBorderAlpha = value
                                    -- FrostAtomUI exposes a single opacity control without a separate enable toggle.
                                    db.buttonBorderAlphaEnabled = true
                                    if SarychUI.modules and SarychUI.modules.mainmenubar
                                        and SarychUI.modules.mainmenubar.ApplyButtonBorderAlpha then
                                        SarychUI.modules.mainmenubar:ApplyButtonBorderAlpha()
                                    end
                                end,
                            },
                        },
                    },
        },
    }
end

-- Get options table for this module
local function GetOptions()
    local options = {
        name = L["MainMenuBar"],
        type = "group",
        desc = L and (L["MainMenuBar_Description"] or "Настройка главной панели команд и панелей действий") or "Настройка главной панели команд и панелей действий",
        suiNavTip = "Новое: добавлены свободные панели в версии 1.2.0",
        childGroups = "tab",
        args = {
            -- General tab
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable_Module"],
                        desc = "Включить или выключить модуль",
                        order = 1,
                        width = "full",
                        get = function(info)
                            return SarychUI.db.profile.modules.mainmenubar.enabled
                        end,
                        set = function(info, value)
                            local db = SarychUI.db.profile.modules.mainmenubar
                            db.enabled = value
                            if value then
                                SarychUI:EnableModule(moduleName)
                            else
                                SarychUI:DisableModule(moduleName)
                            end
                            NotifyOptionsChange()
                            -- FrostAtomUI bars replace the Blizzard bars: turning the module off in
                            -- FrostAtom mode (or on, when the selected type differs from the booted one)
                            -- needs /reload.
                            local FA = SarychUI.FrostAtomBars
                            local needReload = FA and FA.bootMode and (
                                (not value and FA.bootMode == "frostatom")
                                or (value and FA.bootMode ~= (db.barMode or "classic"))
                            )
                            if needReload and SarychUI.ShowReloadPopup then
                                SarychUI:ShowReloadPopup(
                                    value and "Для включения свободных панелей требуется перезагрузка интерфейса."
                                        or "Модуль выключен: панели Blizzard вернутся после перезагрузки интерфейса.",
                                    function()
                                        db.enabled = not value
                                        if db.enabled then
                                            SarychUI:EnableModule(moduleName)
                                        else
                                            SarychUI:DisableModule(moduleName)
                                        end
                                        NotifyOptionsChange()
                                    end
                                )
                            end
                        end,
                    },
                    typeRow = {
                        type = "group",
                        name = "Тип панелей",
                        order = 2,
                        inline = true,
                        suiSelectWithButton = true,
                        disabled = function() return not SarychUI.db.profile.modules.mainmenubar.enabled end,
                        args = {
                            mode = {
                                type = "select",
                                name = "",
                                desc = "«Классические панели» - стандартные панели Blizzard с настройками SarychUI (текст, цветовая индикация, внешний вид).\n«Свободные панели» - полностью свои панели команд, микроменю и кнопка сумки: свободное расположение, размеры, видимость, привязки клавиш.",
                                order = 1,
                                values = {
                                    classic = "Классические панели",
                                    frostatom = "Свободные панели",
                                    __order = { "classic", "frostatom" },
                                },
                                get = function()
                                    return SarychUI.db.profile.modules.mainmenubar.barMode or "classic"
                                end,
                                set = function(_, value)
                                    local db = SarychUI.db.profile.modules.mainmenubar
                                    local previous = db.barMode or "classic"
                                    if previous == value then return end
                                    db.barMode = value
                                    NotifyOptionsChange()
                                    local text = value == "frostatom"
                                        and "Свободные панели заменяют стандартные панели Blizzard.\n\nДля применения требуется перезагрузка интерфейса."
                                        or "Возврат к классическим панелям Blizzard.\n\nДля применения требуется перезагрузка интерфейса."
                                    local function revert()
                                        db.barMode = previous
                                        NotifyOptionsChange()
                                    end
                                    if SarychUI.ShowReloadPopup then
                                        SarychUI:ShowReloadPopup(text, revert)
                                    elseif StaticPopup_Show then
                                        StaticPopup_Show("SARYCHUI_RELOAD_UI")
                                    end
                                end,
                            },
                            openSettings = {
                                type = "execute",
                                name = "Настройки",
                                desc = function()
                                    if IsFrostSelected() then
                                        return "Открыть настройки свободных панелей (раскладка, микроменю, сумка)."
                                    end
                                    return "Открыть настройки классических панелей (текст, цветовая индикация, внешний вид)."
                                end,
                                order = 2,
                                func = function()
                                    local OC = SarychUI and SarychUI.OptionsCore
                                    if not OC or not OC.SelectTab then return end
                                    if IsFrostSelected() then
                                        OC:SelectTab("faBars")
                                    else
                                        OC:SelectTab("visual")
                                    end
                                end,
                            },
                        },
                    },
                    modeHint = {
                        type = "description",
                        name = "|cFFFFD700Внимание:|r После смены типа панелей потребуется перезагрузка интерфейса.",
                        order = 3,
                        width = "full",
                    },
                    pendingHint = {
                        type = "description",
                        name = function()
                            local FA = SarychUI.FrostAtomBars
                            local selected = SarychUI.db.profile.modules.mainmenubar.barMode or "classic"
                            local booted = FA and FA.bootMode
                            if booted and booted ~= selected then
                                if booted == "frostatom" then
                                    return "|cffff6060Выбранный тип панелей ещё не применён:|r сейчас работают свободные панели. Выполните /reload."
                                end
                                return "|cffff6060Выбранный тип панелей ещё не применён:|r сейчас работают классические панели. Выполните /reload."
                            end
                            return ""
                        end,
                        order = 4,
                        width = "full",
                        hidden = function()
                            local FA = SarychUI.FrostAtomBars
                            local selected = SarychUI.db.profile.modules.mainmenubar.barMode or "classic"
                            return not (FA and FA.bootMode and FA.bootMode ~= selected)
                        end,
                    },
                    playerCastbarBox = {
                        type = "group",
                        name = "Полоса каста игрока",
                        desc = "Смещение относительно стандартной позиции кастбара.",
                        order = 5,
                        inline = true,
                        hidden = function() return not IsFrostSelected() end,
                        disabled = FADisabled,
                        args = (function()
                            local args = FAPositionArgs("playerCastbar", 2)
                            args.castDesc = {
                                type = "description",
                                name = "X и Y задаются относительно стандартной позиции кастбара (низ экрана).",
                                order = 1,
                                width = "full",
                            }
                            return args
                        end)(),
                    },
                    fpsBox = {
                        type = "group",
                        name = "FPS",
                        desc = "Настройки индикатора FPS при зажатом Alt",
                        order = 6,
                        inline = true,
                        suiTwoCol = true,
                        suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                        hidden = function() return not IsFrostSelected() end,
                        args = ToolsFpsArgs(),
                    },
                },
            },

            -- FrostAtomUI tabs (shown when barMode == "frostatom")
            faBars = BuildFrostBarsTab(),
            faOther = BuildFrostOtherTab(),
            faMenus = BuildFrostMenusTab(),
            faSettings = BuildFrostSettingsTab(),
            
            -- Visual / Text tab
            visual = {
                type = "group",
                name = L["Visual"],
                order = 2,
                disabled = function() return not SarychUI.db.profile.modules.mainmenubar.enabled end,
                args = {
                    preview = {
                        type = "description",
                        name = "",
                        order = 1,
                        width = "full",
                        suiActionBarTextPreview = true,
                    },

                    hotkeysBox = {
                        type = "group",
                        name = L["Hotkeys"],
                        order = 10,
                        inline = true,
                        args = {
                            hide_hotkeys = {
                                type = "toggle",
                                name = L["Hide_Hotkeys"],
                                desc = L["Hide_Hotkeys_Desc"],
                                order = 1,
                                width = "full",
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllHotkeys()
                                    end
                                    if SarychUI.ActionBarTextPreview and SarychUI.ActionBarTextPreview.RefreshAll then
                                        SarychUI.ActionBarTextPreview:RefreshAll()
                                    end
                                    -- Refresh dependent disabled states in this block.
                                    NotifyOptionsChange()
                                end,
                            },
                            show_in_combat = {
                                type = "toggle",
                                name = L["Show_In_Combat"],
                                desc = L["Show_In_Combat_Desc"],
                                order = 2,
                                width = "full",
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.showHotkeysInCombat
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.showHotkeysInCombat = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllHotkeys()
                                    end
                                end,
                            },
                            show_on_alt = {
                                type = "toggle",
                                name = L["Show_On_Alt"],
                                desc = L["Show_On_Alt_Desc"],
                                order = 3,
                                width = "full",
                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.showHotkeysOnAlt
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.showHotkeysOnAlt = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllHotkeys()
                                    end
                                end,
                            },
                            show_with_target = {
                                type = "toggle",
                                name = L["Show_With_Target"],
                                desc = L["Show_With_Target_Desc"],
                                order = 4,
                                width = "full",
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.showHotkeysWithTarget == true
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.showHotkeysWithTarget = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllHotkeys()
                                    end
                                end,
                            },
                            fade_after_combat = {
                                type = "toggle",
                                name = L["Fade_After_Combat"],
                                desc = L["Fade_After_Combat_Desc"],
                                order = 5,
                                width = "full",
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.hotkeysFadeAfterCombat
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.hotkeysFadeAfterCombat = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:HideHotkeys()
                                    end
                                    NotifyOptionsChange()
                                end,
                            },
                            fade_time = {
                                type = "range",
                                name = L["Fade_Time"],
                                desc = L["Fade_Time_Desc"],
                                order = 6,
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                        or not SarychUI.db.profile.modules.mainmenubar.hotkeysFadeAfterCombat
                                end,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.hotkeysFadeTime
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.hotkeysFadeTime = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:HideHotkeys()
                                    end
                                end,
                            },
                        },
                    },

                    macrosBox = {
                        type = "group",
                        name = L["Macros"],
                        order = 20,
                        inline = true,
                        args = {
                            hide_macro_names = {
                                type = "toggle",
                                name = L["Hide_Macro_Names"],
                                desc = L["Hide_Macro_Names_Desc"],
                                order = 1,
                                width = "full",
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.hideMacroNames
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.hideMacroNames = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllMacroNames()
                                    end
                                    if SarychUI.ActionBarTextPreview and SarychUI.ActionBarTextPreview.RefreshAll then
                                        SarychUI.ActionBarTextPreview:RefreshAll()
                                    end
                                end,
                            },
                        },
                    },
                },
            },
                
                -- Color Indication tab
                colorIndication = {
                    type = "group",
                    name = L["Color Indication"],
                    order = 3,
                    disabled = function() return not SarychUI.db.profile.modules.mainmenubar.enabled end,
                    args = {
                        preview = {
                            type = "description",
                            name = "",
                            order = 1,
                            width = "full",
                            suiActionBarColorPreview = true,
                        },

                        cooldownBox = {
                            type = "group",
                            name = L["Color_Cooldown_Enabled"],
                            order = 10,
                            inline = true,
                            args = {
                                color_cooldown_enabled = {
                                    type = "toggle",
                                    name = L["Color_Cooldown_Enabled"],
                                    desc = L["Color_Cooldown_Enabled_Desc"],
                                    order = 1,
                                    width = "full",
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorCooldownEnabled
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorCooldownEnabled = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
                                        NotifyOptionsChange()
                                    end,
                                },
                                color_cooldown_color = {
                                    type = "color",
                                    name = L["Color_Indication_Color"] or "Цвет и интенсивность",
                                    desc = L["Color_Indication_Color_Desc"] or "Выберите цвет; альфа регулирует интенсивность эффекта.",
                                    hasAlpha = true,
                                    order = 2,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorCooldownEnabled
                                    end,
                                    get = function()
                                        return GetIndicationColor("colorCooldownColor")
                                    end,
                                    set = function(_, r, g, b, a)
                                        SetIndicationColor("colorCooldownColor", r, g, b, a)
                                    end,
                                },
                            },
                        },

                        manaBox = {
                            type = "group",
                            name = L["Color_Mana_Enabled"],
                            order = 20,
                            inline = true,
                            args = {
                                color_mana_enabled = {
                                    type = "toggle",
                                    name = L["Color_Mana_Enabled"],
                                    desc = L["Color_Mana_Enabled_Desc"],
                                    order = 1,
                                    width = "full",
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorManaEnabled
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorManaEnabled = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
                                        NotifyOptionsChange()
                                    end,
                                },
                                color_mana_color = {
                                    type = "color",
                                    name = L["Color_Indication_Color"] or "Цвет и интенсивность",
                                    desc = L["Color_Indication_Color_Desc"] or "Выберите цвет; альфа регулирует интенсивность эффекта.",
                                    hasAlpha = true,
                                    order = 2,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorManaEnabled
                                    end,
                                    get = function()
                                        return GetIndicationColor("colorManaColor")
                                    end,
                                    set = function(_, r, g, b, a)
                                        SetIndicationColor("colorManaColor", r, g, b, a)
                                    end,
                                },
                            },
                        },

                        rangeBox = {
                            type = "group",
                            name = L["Color_Range_Enabled"],
                            order = 30,
                            inline = true,
                            args = {
                                color_range_enabled = {
                                    type = "toggle",
                                    name = L["Color_Range_Enabled"],
                                    desc = L["Color_Range_Enabled_Desc"],
                                    order = 1,
                                    width = "full",
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorRangeEnabled
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorRangeEnabled = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
                                        NotifyOptionsChange()
                                    end,
                                },
                                color_range_color = {
                                    type = "color",
                                    name = L["Color_Indication_Color"] or "Цвет и интенсивность",
                                    desc = L["Color_Indication_Color_Desc"] or "Выберите цвет; альфа регулирует интенсивность эффекта.",
                                    hasAlpha = true,
                                    order = 2,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorRangeEnabled
                                    end,
                                    get = function()
                                        return GetIndicationColor("colorRangeColor")
                                    end,
                                    set = function(_, r, g, b, a)
                                        SetIndicationColor("colorRangeColor", r, g, b, a)
                                    end,
                                },
                            },
                        },

                        unusableBox = {
                            type = "group",
                            name = L["Color_Unusable_Enabled"],
                            order = 40,
                            inline = true,
                            args = {
                                color_unusable_enabled = {
                                    type = "toggle",
                                    name = L["Color_Unusable_Enabled"],
                                    desc = L["Color_Unusable_Enabled_Desc"],
                                    order = 1,
                                    width = "full",
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorUnusableEnabled
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorUnusableEnabled = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
                                        NotifyOptionsChange()
                                    end,
                                },
                                color_unusable_color = {
                                    type = "color",
                                    name = L["Color_Indication_Color"] or "Цвет и интенсивность",
                                    desc = L["Color_Indication_Color_Desc"] or "Выберите цвет; альфа регулирует интенсивность эффекта.",
                                    hasAlpha = true,
                                    order = 2,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorUnusableEnabled
                                    end,
                                    get = function()
                                        return GetIndicationColor("colorUnusableColor")
                                    end,
                                    set = function(_, r, g, b, a)
                                        SetIndicationColor("colorUnusableColor", r, g, b, a)
                                    end,
                                },
                            },
                        },
                    },
                },
                
                -- Appearance tab
                appearance = {
                    type = "group",
                    name = L["Appearance"],
                    order = 4,
                    hidden = IsFrostSelected,
                    disabled = function() return not SarychUI.db.profile.modules.mainmenubar.enabled end,
                    childGroups = "tab",
                    args = {
                        -- Visual improvements tab
                        visual = {
                            type = "group",
                            name = "Визуальные улучшения",
                            order = 1,
                            hidden = IsFrostSelected,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiActionBarAppearancePreview = true,
                                },

                                gryphonsBox = {
                                    type = "group",
                                    name = "Грифоны",
                                    order = 10,
                                    inline = true,
                                    args = {
                                        hide_gryphons = {
                                            type = "toggle",
                                            name = L["Hide_Gryphons"] or "Скрыть грифонов",
                                            desc = L["Hide_Gryphons_Desc"] or "Скрыть грифонов по бокам панели действий",
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideGryphons
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideGryphons = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },

                                backgroundsBox = {
                                    type = "group",
                                    name = "Фоновые текстуры",
                                    order = 20,
                                    inline = true,
                                    args = {
                                        hide_actionbar_backgrounds = {
                                            type = "toggle",
                                            name = L["Hide_ActionBar_Backgrounds"],
                                            desc = L["Hide_ActionBar_Backgrounds_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideActionBarBackgrounds
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideActionBarBackgrounds = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                        hide_secondary_panels_backgrounds = {
                                            type = "toggle",
                                            name = L["Hide_Secondary_Panels_Backgrounds"],
                                            desc = L["Hide_Secondary_Panels_Backgrounds_Desc"],
                                            order = 2,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideSecondaryPanelsBackgrounds
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideSecondaryPanelsBackgrounds = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                        hide_maxlevel_bar = {
                                            type = "toggle",
                                            name = L["Hide_MaxLevel_Bar"],
                                            desc = L["Hide_MaxLevel_Bar_Desc"],
                                            order = 3,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideMaxLevelBar
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideMaxLevelBar = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },

                                interfaceBox = {
                                    type = "group",
                                    name = "Элементы интерфейса",
                                    order = 30,
                                    inline = true,
                                    args = {
                                        hide_keyring_button = {
                                            type = "toggle",
                                            name = L["Hide_Keyring_Button"],
                                            desc = L["Hide_Keyring_Button_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideKeyringButton
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideKeyringButton = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateKeyringButton()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                        hide_page_buttons = {
                                            type = "toggle",
                                            name = L["Hide_Page_Buttons"],
                                            desc = L["Hide_Page_Buttons_Desc"],
                                            order = 2,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hidePageButtons
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hidePageButtons = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdatePageButtons()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },

                                pageNumbersBox = {
                                    type = "group",
                                    name = "Номер страницы",
                                    order = 40,
                                    inline = true,
                                    args = {
                                        hide_page_numbers = {
                                            type = "toggle",
                                            name = L["Hide_Page_Numbers"],
                                            desc = L["Hide_Page_Numbers_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hidePageNumbers = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdatePageNumbers()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        show_page_numbers_in_combat = {
                                            type = "toggle",
                                            name = L["Show_Page_Numbers_In_Combat"],
                                            desc = L["Show_Page_Numbers_In_Combat_Desc"],
                                            order = 2,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showPageNumbersInCombat
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showPageNumbersInCombat = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                        show_page_numbers_on_alt = {
                                            type = "toggle",
                                            name = L["Show_Page_Numbers_On_Alt"],
                                            desc = L["Show_Page_Numbers_On_Alt_Desc"],
                                            order = 3,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showPageNumbersOnAlt
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showPageNumbersOnAlt = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdatePageNumbers()
                                                end
                                            end,
                                        },
                                        page_numbers_fade_after_combat = {
                                            type = "toggle",
                                            name = L["Page_Numbers_Fade_After_Combat"],
                                            desc = L["Page_Numbers_Fade_After_Combat_Desc"],
                                            order = 4,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeAfterCombat
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeAfterCombat = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        page_numbers_fade_time = {
                                            type = "range",
                                            name = L["Page_Numbers_Fade_Time"],
                                            desc = L["Page_Numbers_Fade_Time_Desc"],
                                            order = 5,
                                            min = 0.1,
                                            max = 2.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                                    or not SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeAfterCombat
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                    },
                                },
                            },
                        },
                        
                        -- Transparency tab
                        transparency = {
                            type = "group",
                            name = "Прозрачность",
                            order = 2,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiActionBarTransparencyPreview = true,
                                },

                                borderBox = {
                                    type = "group",
                                    name = L["Button_Border_Alpha"],
                                    order = 10,
                                    inline = true,
                                    args = {
                                        button_border_alpha_enabled = {
                                            type = "toggle",
                                            name = "Включить прозрачность",
                                            desc = L["Button_Border_Alpha_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.buttonBorderAlphaEnabled
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.buttonBorderAlphaEnabled = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        button_border_alpha = {
                                            type = "range",
                                            name = "Прозрачность обводки",
                                            desc = "Прозрачность обводки кнопок (0 - невидимая, 1 - полностью видимая)",
                                            order = 2,
                                            min = 0,
                                            max = 1,
                                            step = 0.05,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.buttonBorderAlphaEnabled
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.buttonBorderAlpha
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.buttonBorderAlpha = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },

                                microBox = {
                                    type = "group",
                                    name = L["MicroMenu_Alpha"],
                                    order = 20,
                                    inline = true,
                                    args = {
                                        micro_menu_alpha_enabled = {
                                            type = "toggle",
                                            name = "Включить прозрачность",
                                            desc = L["MicroMenu_Alpha_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.microMenuAlphaEnabled
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.microMenuAlphaEnabled = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        micro_menu_alpha = {
                                            type = "range",
                                            name = "Прозрачность микроменю",
                                            desc = "Прозрачность кнопок микроменю (0 - невидимая, 1 - полностью видимая)",
                                            order = 2,
                                            min = 0,
                                            max = 1,
                                            step = 0.05,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.microMenuAlphaEnabled
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.microMenuAlpha
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.microMenuAlpha = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },
                            },
                        },
                        
                        -- Bars tab
                        bars = {
                            type = "group",
                            name = "Полосы",
                            order = 3,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiActionBarBarsPreview = true,
                                },

                                reputationBox = {
                                    type = "group",
                                    name = "Полоса репутации",
                                    order = 10,
                                    inline = true,
                                    args = {
                                        hide_reputation_bar = {
                                            type = "toggle",
                                            name = L["Hide_Reputation_Bar"],
                                            desc = L["Hide_Reputation_Bar_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideReputationBar = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateReputationBar()
                                                end
                                                if SarychUI.ActionBarBarsPreview and SarychUI.ActionBarBarsPreview.RefreshAll then
                                                    SarychUI.ActionBarBarsPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        show_reputation_bar_on_alt = {
                                            type = "toggle",
                                            name = L["Show_Reputation_Bar_On_Alt"],
                                            desc = L["Show_Reputation_Bar_On_Alt_Desc"],
                                            order = 2,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showReputationBarOnAlt
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showReputationBarOnAlt = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateReputationBar()
                                                end
                                            end,
                                        },
                                        show_reputation_bar_on_gain = {
                                            type = "toggle",
                                            name = L["Show_Reputation_Bar_On_Gain"],
                                            desc = L["Show_Reputation_Bar_On_Gain_Desc"],
                                            order = 3,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showReputationBarOnGain
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showReputationBarOnGain = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        reputation_bar_fade_time = {
                                            type = "range",
                                            name = L["Reputation_Bar_Fade_Time"],
                                            desc = L["Reputation_Bar_Fade_Time_Desc"],
                                            order = 4,
                                            min = 0.1,
                                            max = 2.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                                    or not SarychUI.db.profile.modules.mainmenubar.showReputationBarOnGain
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.reputationBarFadeTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.reputationBarFadeTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                        reputation_bar_show_time = {
                                            type = "range",
                                            name = L["Reputation_Bar_Show_Time"],
                                            desc = L["Reputation_Bar_Show_Time_Desc"],
                                            order = 5,
                                            min = 0.5,
                                            max = 5.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                                    or not SarychUI.db.profile.modules.mainmenubar.showReputationBarOnGain
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.reputationBarShowTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.reputationBarShowTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                    },
                                },

                                experienceBox = {
                                    type = "group",
                                    name = "Полоса опыта",
                                    order = 20,
                                    inline = true,
                                    args = {
                                        hide_experience_bar = {
                                            type = "toggle",
                                            name = L["Hide_Experience_Bar"],
                                            desc = L["Hide_Experience_Bar_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideExperienceBar = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateExperienceBar()
                                                end
                                                if SarychUI.ActionBarBarsPreview and SarychUI.ActionBarBarsPreview.RefreshAll then
                                                    SarychUI.ActionBarBarsPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        show_experience_bar_on_alt = {
                                            type = "toggle",
                                            name = L["Show_Experience_Bar_On_Alt"],
                                            desc = L["Show_Experience_Bar_On_Alt_Desc"],
                                            order = 2,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnAlt
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnAlt = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateExperienceBar()
                                                end
                                            end,
                                        },
                                        show_experience_bar_on_gain = {
                                            type = "toggle",
                                            name = L["Show_Experience_Bar_On_Gain"],
                                            desc = L["Show_Experience_Bar_On_Gain_Desc"],
                                            order = 3,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnGain
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnGain = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        experience_bar_fade_time = {
                                            type = "range",
                                            name = L["Experience_Bar_Fade_Time"],
                                            desc = L["Experience_Bar_Fade_Time_Desc"],
                                            order = 4,
                                            min = 0.1,
                                            max = 2.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                                    or not SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnGain
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.experienceBarFadeTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.experienceBarFadeTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                        experience_bar_show_time = {
                                            type = "range",
                                            name = L["Experience_Bar_Show_Time"],
                                            desc = L["Experience_Bar_Show_Time_Desc"],
                                            order = 5,
                                            min = 0.5,
                                            max = 5.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                                    or not SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnGain
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.experienceBarShowTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.experienceBarShowTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                    },
                                },
                            },
                        },
                        
                        -- Other tab
                        other = {
                            type = "group",
                            name = "Другое",
                            order = 4,
                            hidden = IsFrostSelected,
                            args = {
                                microMenuStyleBox = {
                                    type = "group",
                                    name = "Микроменю",
                                    order = 1,
                                    inline = true,
                                    args = {
                                        microMenuStyle = {
                                            type = "select",
                                            name = "Внешний вид",
                                            desc = "Текстуры кнопок микроменю. Расположение и размер не меняются.",
                                            order = 1,
                                            width = "full",
                                            values = {
                                                classic = "Классические",
                                                dragonflight = "Dragonflight",
                                            },
                                            get = function()
                                                return SarychUI.db.profile.modules.mainmenubar.microMenuStyle or "dragonflight"
                                            end,
                                            set = function(_, value)
                                                local db = SarychUI.db.profile.modules.mainmenubar
                                                local previous = db.microMenuStyle or "dragonflight"
                                                if previous == value then return end
                                                db.microMenuStyle = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                                local text = "Для применения внешнего вида микроменю требуется перезагрузка интерфейса."
                                                local function revert()
                                                    db.microMenuStyle = previous
                                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                        SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                    end
                                                    if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                        SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                    end
                                                    NotifyOptionsChange()
                                                end
                                                if SarychUI.ShowReloadPopup then
                                                    SarychUI:ShowReloadPopup(text, revert)
                                                elseif StaticPopup_Show then
                                                    StaticPopup_Show("SARYCHUI_RELOAD_UI")
                                                end
                                            end,
                                        },
                                        microMenuHideGreenLatency = {
                                            type = "toggle",
                                            name = "Скрывать индикатор при зелёной сети",
                                            desc = "Прячет индикатор задержки на кнопке меню, пока пинг зелёный. При жёлтом или красном - показывает. Только для внешнего вида Dragonflight.",
                                            order = 2,
                                            width = "full",
                                            hidden = function()
                                                local db = SarychUI.db.profile.modules.mainmenubar
                                                return (db.microMenuStyle or "dragonflight") ~= "dragonflight"
                                            end,
                                            get = function()
                                                local db = SarychUI.db.profile.modules.mainmenubar
                                                return db.microMenuHideGreenLatency ~= false
                                            end,
                                            set = function(_, value)
                                                SarychUI.db.profile.modules.mainmenubar.microMenuHideGreenLatency = value and true or false
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                    },
                                },
                                sidePanelsBox = {
                                    type = "group",
                                    name = "Боковые панели",
                                    order = 10,
                                    inline = true,
                                    args = {
                                        hide_side_panels = {
                                            type = "toggle",
                                            name = L["Hide_Side_Panels"],
                                            desc = L["Hide_Side_Panels_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideSidePanels
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideSidePanels = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateSidePanels()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        show_side_panels_on_alt = {
                                            type = "toggle",
                                            name = L["Show_Side_Panels_On_Alt"],
                                            desc = L["Show_Side_Panels_On_Alt_Desc"],
                                            order = 2,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideSidePanels
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showSidePanelsOnAlt
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showSidePanelsOnAlt = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateSidePanels()
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

    -- In FrostAtomUI mode the shared text/color controls belong to one final
    -- Appearance tab.  Keep the classic layout unchanged, but hide its two
    -- standalone tabs so each setting has exactly one visible owner.
    local textOptions = options.args.visual
    local colorOptions = options.args.colorIndication
    textOptions.hidden = IsFrostSelected
    colorOptions.hidden = IsFrostSelected
    options.args.faAppearance = {
        type = "group",
        name = "Внешний вид",
        order = 6,
        hidden = function() return not IsFrostSelected() end,
        disabled = function() return not SarychUI.db.profile.modules.mainmenubar.enabled end,
        childGroups = "tab",
        args = {
            text = {
                type = "group",
                name = "Текст",
                order = 1,
                args = textOptions.args,
            },
            colorIndication = {
                type = "group",
                name = L["Color Indication"],
                order = 2,
                args = colorOptions.args,
            },
        },
    }

    return options
end

-- Export options function
SarychUI.modules.mainmenubar.GetOptions = GetOptions
