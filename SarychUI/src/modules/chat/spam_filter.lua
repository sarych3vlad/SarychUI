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


-- Функция получения паттернов для фильтрации (EXACT COPY FROM sarChat)
local function sarChat_GetSpamPatterns()
    local deleted, result, seen = {}, {}, {}
    for _, value in ipairs(sarChat_GetSetting("spamDeletedList", {})) do deleted[value] = true end
    local function Add(list)
        for _, value in ipairs(list or {}) do
            if not deleted[value] and not seen[value] then
                seen[value] = true
                tinsert(result, value)
            end
        end
    end
    Add(sarChat_GetSetting("spamCustomList", {}))
    Add(SarychUI.ChatSpamDefaults)
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

-- Экспортируем функции для использования в модуле
_G.EnableSpamFilter = EnableSpamFilter
_G.DisableSpamFilter = DisableSpamFilter
_G.sarChat_GetSpamPatterns = sarChat_GetSpamPatterns
_G.SarychUI_RefreshCachedSpamPatterns = RefreshCachedSpamPatterns
_G.CHAT_MSG_SYSTEM_filter = CHAT_MSG_SYSTEM_filter
