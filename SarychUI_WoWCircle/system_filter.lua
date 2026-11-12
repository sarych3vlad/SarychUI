-- WoWCircle system message filter (owned by tools module)
local function ToolsDB() return SarychUI.WoWCircle:GetDB() end

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


_G.CHAT_MSG_SYSTEM_wowcircle_filter = CHAT_MSG_SYSTEM_wowcircle_filter
