-- SarychUI Chat Module - Spam Filter Features
-- Функции для вкладки "Фильтр сообщений" в настройках

local tinsert = table.insert

-- Доступ к сохранённым настройкам (привязано к базе SarychUI)
local function sarChat_GetSetting(key, default)
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db then return default end
    return db[key] or default
end

-- Экспортируем функцию для использования в модуле
_G.sarChat_GetSetting = sarChat_GetSetting

-- ========================================
-- SPAM FILTER FUNCTIONS (EXACT COPY FROM sarChat)
-- ========================================

-- Список сообщений по умолчанию для фильтрации (EXACT COPY FROM sarChat)
local DEFAULT_SPAM_LIST = {
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

-- Функция получения паттернов для фильтрации (EXACT COPY FROM sarChat)
local function sarChat_GetSpamPatterns()
    local enabled = sarChat_GetSetting and sarChat_GetSetting('spamEnabledList', nil)
    if type(enabled) == 'table' then
        local deleted = sarChat_GetSetting and sarChat_GetSetting('spamDeletedList', {}) or {}
        local deletedSet = {}
        if type(deleted) == 'table' then
            for _, s in ipairs(deleted) do deletedSet[s] = true end
        end
        if next(deletedSet) ~= nil then
            local filtered = {}
            for _, s in ipairs(enabled) do
                if not deletedSet[s] then tinsert(filtered, s) end
            end
            return filtered
        end
        return enabled
    end
    -- Fallback: сформировать список из дефолтных и пользовательских, исключив удалённые
    local deleted = sarChat_GetSetting and sarChat_GetSetting('spamDeletedList', {}) or {}
    local deletedSet = {}
    if type(deleted) == 'table' then
        for _, s in ipairs(deleted) do deletedSet[s] = true end
    end
    local result = {}
    -- custom
    local custom = sarChat_GetSetting and sarChat_GetSetting('spamCustomList', {}) or {}
    if type(custom) == 'table' then
        for _, s in ipairs(custom) do
            if not deletedSet[s] then tinsert(result, s) end
        end
    end
    -- defaults
    for _, s in ipairs(DEFAULT_SPAM_LIST) do
        if not deletedSet[s] then tinsert(result, s) end
    end
    return result
end

local cachedSpamPatterns = nil

local function RefreshCachedSpamPatterns()
    cachedSpamPatterns = sarChat_GetSpamPatterns()
end

-- Глобальная переменная для контроля фильтра спама
_G.SarychUI_SpamFilterEnabled = false

-- Функция включения/отключения фильтра спама
local function EnableSpamFilter(enabled)
    if not enabled then 
        _G.SarychUI_SpamFilterEnabled = false
        return 
    end
    
    _G.SarychUI_SpamFilterEnabled = true
end

-- Функция отключения фильтра спама
local function DisableSpamFilter()
    -- Отключаем глобальный флаг
    _G.SarychUI_SpamFilterEnabled = false
end

-- Функция фильтрации системных сообщений (chat spam list only)
local function CHAT_MSG_SYSTEM_filter(_, _, message)
    -- ПРОВЕРЯЕМ СТАТУС МОДУЛЯ ПЕРВЫМ ДЕЛОМ!
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules or not SarychUI.db.profile.modules.chat or not SarychUI.db.profile.modules.chat.enabled then
        return
    end
    
    -- Проверка на стандартные шаблоны
    local patterns = cachedSpamPatterns
    if not patterns then
        patterns = sarChat_GetSpamPatterns()
        cachedSpamPatterns = patterns
    end
    for i = 1, #patterns do
        if message:find(patterns[i], 1, true) then
            return true
        end
    end
end

-- WoWCircle system message filter (owned by tools module)
local function ToolsDB()
    return SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.tools
end

local function IsToolsModuleEnabled()
    local db = ToolsDB()
    return db and db.enabled == true
end

local function ToolsSetting(key, default)
    local db = ToolsDB()
    if not db then return default end
    if db[key] ~= nil then return db[key] end
    local chatDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if chatDb and chatDb[key] ~= nil then
        db[key] = chatDb[key]
        chatDb[key] = nil
        return db[key]
    end
    return default
end

local function CHAT_MSG_SYSTEM_wowcircle_filter(_, _, message)
    if not IsToolsModuleEnabled() then
        return
    end

    -- PP whisper restriction message in instances
    if message == "Обмениваться личными сообщениями можно только с союзниками." and IsInInstance() then
        if (tonumber(ToolsSetting("ppMessageFixEnabled", 1)) or 0) == 1 then
            return true
        end
    end

    -- Post-combat difficulty / iLvl / PvE points spam
    if (tonumber(ToolsSetting("spamFilterCombatDifficulty", 1)) or 0) == 1 then
        if message:find("Сложность боя:", 1, true) or
           message:find("Время боя:", 1, true) or
           message:find("iLvl боя:", 1, true) or
           message:find("Завершено энкаунтеров:", 1, true) or
           message:find("Время в подземелье:", 1, true) or
           message:find("iLvl подземелья:", 1, true) or
           message:find("Энкаунтер был запущен персонажем", 1, true) or
           message:find("Каждый персонаж заработал PvE очков:", 1, true) or
           message:find("Макс./Макс.ср. iLvl", 1, true) or
           message:find("Зачетный макс./макс.ср. iLvl", 1, true) then
            return true
        end
    end
end

-- Экспортируем функции для использования в модуле
_G.EnableSpamFilter = EnableSpamFilter
_G.DisableSpamFilter = DisableSpamFilter
_G.sarChat_GetSpamPatterns = sarChat_GetSpamPatterns
_G.SarychUI_RefreshCachedSpamPatterns = RefreshCachedSpamPatterns
_G.CHAT_MSG_SYSTEM_filter = CHAT_MSG_SYSTEM_filter
_G.CHAT_MSG_SYSTEM_wowcircle_filter = CHAT_MSG_SYSTEM_wowcircle_filter
