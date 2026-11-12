-- Settings use Auctionator's original saved variables and stacking API.
function Atr_EnsureOptions()
    if not AUCTIONATOR_SAVEDVARS then Atr_ResetSavedVars() end
    if not AUCTIONATOR_STACKING_PREFS then Atr_StackingPrefs_Init() end
    if AUCTIONATOR_SCAN_MINLEVEL == nil then AUCTIONATOR_SCAN_MINLEVEL = 1 end
end

local function Refresh()
    if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
end
local function Toggle(name, key, order, changed)
    return { type = "toggle", name = name, order = order,
        get = function() return _G[key] == 1 end,
        set = function(_, value)
            _G[key] = value and 1 or 0
            if changed then changed() end
            Refresh()
        end }
end
local function Select(name, key, order, values)
    return { type = "select", name = name, order = order, values = values,
        get = function() return _G[key] end,
        set = function(_, value) _G[key] = value; Refresh() end }
end
local function Integer(name, order, get, set, minimum, maximum)
    return { type = "input", name = name, order = order,
        get = function() return tostring(get()) end,
        validate = function(_, text)
            local n = tonumber(text)
            return (n and n == math.floor(n) and n >= minimum and (not maximum or n <= maximum))
                or "Введите целое число в допустимом диапазоне."
        end,
        set = function(_, text)
            local n = tonumber(text)
            if n and n == math.floor(n) and n >= minimum and (not maximum or n <= maximum) then
                set(n); Refresh()
            end
        end }
end
local function Box(name, order, args)
    return { type = "group", name = name, order = order, inline = true, args = args }
end
local selectedStack = "*_glyphs"
local newItem = ""
local categories = {
    ["*_glyphs"] = "Символы", ["*_gemscut"] = "Огранённые камни",
    ["*_gemsuncut"] = "Неогранённые камни", ["*_itemenh"] = "Улучшения предметов",
    ["*_potelix"] = "Зелья и эликсиры", ["*_flasks"] = "Настои", ["*_herbs"] = "Травы",
}
local function StackValues()
    Atr_EnsureOptions()
    local values = {}
    for key, name in pairs(categories) do values[key] = name end
    for key, pref in pairs(AUCTIONATOR_STACKING_PREFS) do
        if pref.numstacks ~= 0 then values[key] = categories[key] or key end
    end
    return values
end
local function StackPrefs()
    Atr_EnsureOptions()
    local count, size = Atr_Get_StackingPrefs(selectedStack)
    return count, size
end
local function SetStack(count, size)
    Atr_Set_StackingPrefs_numstacks(selectedStack, count)
    Atr_Set_StackingPrefs_stacksize(selectedStack, size)
end

function SarychUI:BuildAuctionatorOptions(wrapper)
    Atr_EnsureOptions()
    local basic = {
        general = Box("Основные настройки", 1, {
            alt = Toggle("Alt + щелчок по предмету для продажи", "AUCTIONATOR_ENABLE_ALT", 1),
            bags = Toggle("Открывать все сумки", "AUCTIONATOR_OPEN_ALL_BAGS", 2),
            startingPrice = Toggle("Показывать начальную ставку", "AUCTIONATOR_SHOW_ST_PRICE", 3,
                function() if Atr_StartingPriceText and Atr_StartingPrice and Atr_StartingPriceDiscountText and Atr_Duration_Text then Atr_ShowHide_StartingPrice() end end),
            tab = Select("Вкладка аукциона по умолчанию", "AUCTIONATOR_DEFTAB", 4,
                { __order = {0,1,2,3}, [0] = "Стандартная", [1] = "Продажа", [2] = "Покупка", [3] = "Ещё" }),
            duration = Select("Длительность аукциона", "AUCTIONATOR_DEF_DURATION", 5,
                { __order = {"N","S","M","L"}, N = "Не менять", S = "12 часов", M = "24 часа", L = "48 часов" }),
        }),
    }
    local tips = {
        prices = Box("Цены в подсказках", 1, {
            vendor = Toggle("Цена продажи торговцу", "AUCTIONATOR_V_TIPS", 1),
            auction = Toggle("Цена на аукционе", "AUCTIONATOR_A_TIPS", 2),
            disenchant = Toggle("Стоимость распыления", "AUCTIONATOR_D_TIPS", 3),
            shift = Select("При нажатом Shift показывать", "AUCTIONATOR_SHIFT_TIPS", 4,
                { __order = {1,2}, [1] = "Цену пачки", [2] = "Цену одного предмета" }),
            details = Select("Подробности распыления", "AUCTIONATOR_DE_DETAILS_TIPS", 5,
                { __order = {1,2,3,4,5}, [1] = "При нажатом Shift", [2] = "При нажатом Ctrl",
                    [3] = "При нажатом Alt", [4] = "Никогда", [5] = "Всегда" }),
        }),
    }
    local undercut = {}
    for i, entry in ipairs({ {5000000,"Более 500 золотых"}, {1000000,"Более 100 золотых"},
        {200000,"Более 20 золотых"}, {50000,"Более 5 золотых"}, {10000,"Более 1 золотого"},
        {2000,"Более 20 серебряных"}, {500,"Более 5 серебряных"} }) do
        local key = "_" .. entry[1]
        local fields = {}
        for j, unit in ipairs({ {"gold","Золото",10000}, {"silver","Серебро",100}, {"copper","Медь",1} }) do
            local divisor = unit[3]
            local function Component()
                local amount = math.floor((AUCTIONATOR_SAVEDVARS[key] or 0) / divisor)
                return divisor == 10000 and amount or amount % 100
            end
            fields[unit[1]] = Integer(unit[2], j, Component,
                function(value)
                    AUCTIONATOR_SAVEDVARS[key] = (AUCTIONATOR_SAVEDVARS[key] or 0) + (value - Component()) * divisor
                end, 0, divisor ~= 10000 and 99 or nil)
        end
        undercut[key] = Box(entry[2] .. " — снижение цены", i, fields)
        undercut[key].suiThreeCol = true
    end
    undercut.discount = Integer("Скидка начальной ставки (%)", 8,
        function() return AUCTIONATOR_SAVEDVARS.STARTING_DISCOUNT end,
        function(value) AUCTIONATOR_SAVEDVARS.STARTING_DISCOUNT = value end, 0, 100)
    undercut.reset = { type = "execute", name = "По умолчанию", order = 9,
        func = function() Atr_ResetSavedVars(); Refresh() end }

    local selling = {
        add = Box("Добавить предмет", 1, {
            name = { type = "input", name = "Название предмета или ссылка", order = 1,
                get = function() return newItem end, set = function(_, value) newItem = value end },
            add = { type = "execute", name = "Добавить", order = 2,
                func = function()
                    local name = newItem:match("|h%[(.-)%]|h") or newItem:match("^%s*(.-)%s*$")
                    if name and name ~= "" then
                        selectedStack = name:lower()
                        local count = Atr_Get_StackingPrefs(selectedStack)
                        if not count or count == 0 then SetStack(-1, 1) end
                        newItem = ""; Refresh()
                    end
                end },
        }),
        rules = Box("Продажа пачками", 2, {
            item = { type = "select", name = "Предмет или категория", order = 1, width = "full", values = StackValues,
                get = function() return selectedStack end,
                set = function(_, key) selectedStack = key; Refresh() end },
            count = { type = "select", name = "Количество пачек", order = 2,
                values = { __order = {-2,-1,1,2,3,4,5,10}, [-2] = "По умолчанию", [-1] = "Как можно больше",
                    [1] = "1", [2] = "2", [3] = "3", [4] = "4", [5] = "5", [10] = "10" },
                get = function() local count = StackPrefs(); return (count and count ~= 0) and count or -2 end,
                set = function(_, count)
                    local _, size = StackPrefs()
                    if count == -2 then Atr_Clear_StackingPrefs(selectedStack)
                    else SetStack(count, size or 1) end
                    Refresh()
                end },
            size = Integer("Предметов в пачке (0 — полная пачка)", 3,
                function() local _, size = StackPrefs(); return size or 1 end,
                function(size) local count = StackPrefs(); SetStack((count and count ~= 0) and count or -1, size) end, 0),
            remove = { type = "execute", order = 4,
                name = function() return categories[selectedStack] and "По умолчанию" or "Удалить предмет" end,
                func = function()
                    Atr_Clear_StackingPrefs(selectedStack)
                    if not categories[selectedStack] then selectedStack = "*_glyphs" end
                    Refresh()
                end },
        }),
    }
    local scanning = { quality = Select("Минимальное качество для базы цен", "AUCTIONATOR_SCAN_MINLEVEL", 1,
        { __order = {1,2,3,4,5}, [1] = "|cff9d9d9dНизкое (все)|r", [2] = "|cffffffffОбычное|r",
            [3] = "|cff1eff00Необычное|r", [4] = "|cff0070ddРедкое|r", [5] = "|cffa335eeЭпическое|r" }) }
    local function Tab(name, order, args)
        return { type = "group", name = name, order = order, args = args,
            hidden = function() return not wrapper:IsRuntimeEnabled() end }
    end
    return { type = "group", name = "Auctionator", order = 19, childGroups = "tab", args = {
        enabled = { type = "toggle", name = "Включить", order = 0,
            get = function() return wrapper:IsRuntimeEnabled() end,
            set = function(_, value) wrapper:SetRuntimeEnabled(value) end },
        basic = Tab("Основное", 1, basic),
        tips = Tab("Подсказки", 2, tips),
        undercut = Tab("Снижение цены", 3, undercut),
        selling = Tab("Продажа", 4, selling),
        scanning = Tab("Сканирование", 5, scanning),
    } }
end
