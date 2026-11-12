local SuiTimer = select(2, ...).Compat.Timer
-- SarychUI Chat Module - Functionality Features
-- Функции для вкладки "Функционал" в настройках

-- Импорт функций
local tinsert, tremove = table.insert, table.remove
local gsub, format = string.gsub, string.format
local floor, max, min = math.floor, math.max, math.min
local tconcat = table.concat

-- Доступ к сохранённым настройкам (привязано к базе SarychUI)
local function sarChat_GetSetting(key, default)
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db then return default end
    return db[key] or default
end

-- Экспортируем функцию для использования в модуле
_G.sarChat_GetSetting = sarChat_GetSetting

-- Shared chat-extra settings (legacy profile storage)
local function ToolsDB()
    return SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.tools
end


local function ToolsSetting(key, default)
    local db = ToolsDB()
    if not db then return default end
    if db[key] ~= nil then return db[key] end
    -- Migrate once from old chat profile keys
    local chatDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if chatDb and chatDb[key] ~= nil then
        db[key] = chatDb[key]
        chatDb[key] = nil
        return db[key]
    end
    return default
end

-- ========================================
-- HOTKEYS FUNCTIONS (EXACT COPY FROM sarChat)
-- ========================================

-- Безопасная замена для SuiTimer.After на клиентах без SuiTimer (например, 3.3.5)
local function After(delaySeconds, callback)
    SuiTimer.After(delaySeconds, callback)
end

-- Функция применения горячих клавиш (ADAPTED FOR SarychUI)
local function ApplyHotkeyIfNeeded(editBox)
    -- ПРОВЕРЯЕМ СТАТУС МОДУЛЯ ПЕРВЫМ ДЕЛОМ!
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules or not SarychUI.db.profile.modules.chat or not SarychUI.db.profile.modules.chat.enabled then
            return
    end
    
    local hotkeysOn = sarChat_GetSetting and (sarChat_GetSetting("chatHotkeysEnabled", 1) == 1)
    if not hotkeysOn then 
        return 
    end

    local yellOn = (sarChat_GetSetting and sarChat_GetSetting("hotkeysYell", 1) == 1)
    local sayOn = (sarChat_GetSetting and sarChat_GetSetting("hotkeysSay", 1) == 1)
    local groupAutoOn = (sarChat_GetSetting and sarChat_GetSetting("hotkeysAuto", 1) == 1)

    if IsControlKeyDown() and IsShiftKeyDown() and yellOn then
        -- Ctrl+Shift+Enter: Крикнуть
        editBox:SetText("/yell ")
    elseif IsShiftKeyDown() and not IsControlKeyDown() and sayOn then
        -- Shift+Enter: Сказать
        editBox:SetText("/say ")
    elseif IsControlKeyDown() and not IsShiftKeyDown() and groupAutoOn then
        -- Ctrl+Enter: авто-выбор канала (группа/рейд/БГ/арена)
        if IsActiveBattlefieldArena and IsActiveBattlefieldArena() then
            editBox:SetText("/party ")
        elseif UnitInBattleground and UnitInBattleground("player") then
            editBox:SetText("/bg ")
        elseif SarychUI.Compat.IsInRaid and SarychUI.Compat.IsInRaid() then
            editBox:SetText("/raid ")
        elseif SarychUI.Compat.IsInGroup and SarychUI.Compat.IsInGroup() then
            editBox:SetText("/party ")
        else
            editBox:SetText("")
        end
    end
end

-- Функция подключения горячих клавиш (EXACT COPY FROM sarChat)
local function HookHotkeys(editBox)
    if not editBox or editBox._sarChatHotkeysHooked then 
        return 
    end
    editBox:HookScript("OnShow", function(self)
        ApplyHotkeyIfNeeded(self)
    end)
    editBox:HookScript("OnKeyDown", function(self, key)
        if key == "ENTER" then
            ApplyHotkeyIfNeeded(self)
        end
    end)
    editBox._sarChatHotkeysHooked = true
end

-- Функция отключения горячих клавиш
local function UnhookHotkeys(editBox)
    if not editBox or not editBox._sarChatHotkeysHooked then return end
    editBox:SetScript("OnShow", nil)
    editBox:SetScript("OnKeyDown", nil)
    editBox._sarChatHotkeysHooked = nil
end

-- ========================================
-- CHANNEL SHORTENING FUNCTIONS (ADAPTIVE)
-- ========================================

-- Empty / missing = keep Blizzard channel tag (do NOT invent [P]/[G]).
-- Never replace with "": that strips |h display text -> raw "|Hchannel:PARTY".
local function ResolveChannelAbbrev(key)
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    local v = db and db[key]
    if type(v) ~= "string" then
        return nil
    end
    v = v:match("^%s*(.-)%s*$") or ""
    if v == "" then
        return nil
    end
    return v
end

local chatModule = SarychUI:GetModule("chat")

-- Use the live joined list for identity and the client's current full name
-- for display (including zone suffixes), without invented labels.
function chatModule:GetJoinedChannels()
    local channels = { GetChannelList() }
    for index = 1, #channels, 2 do
        local number, name = GetChannelName(channels[index])
        if number and number > 0 and name and name ~= "" then
            channels[index + 1] = name
        end
    end
    return channels
end

function chatModule:GetChannelBaseName(name)
    return (tostring(name or ""):gsub("%s%-%s.*", ""))
end

-- Channel identity, readable label and legacy setting belong to one definition.
-- Custom channel names are never split heuristically (e.g. MyGuildChannel).
local standardChannels = {
    { id="General", key="abbrNumGeneral", en="General", ru="Общий", aliases={"Общий"} },
    { id="Trade", key="abbrNumTrade", en="Trade", ru="Торговля", aliases={"Торговля"} },
    { id="LocalDefense", key="abbrNumLocalDefense", en="Local Defense", ru="Оборона — локальный", aliases={"ОборонаЛокальный", "Оборона"} },
    { id="WorldDefense", key="abbrNumWorldDefense", en="World Defense", ru="Оборона — глобальный", aliases={"ОборонаГлобальный"} },
    { id="GuildRecruitment", key="abbrNumGuildRecruitment", en="Guild Recruitment", ru="Набор в гильдии", aliases={"Гильдии", "Набор в гильдии"} },
    { id="LookingForGroup", key="lfgAbbrev", en="Looking For Group", ru="Поиск спутников", aliases={"ПоискСпутников", "Поиск спутников"} },
}
local function ChannelNameKey(name)
    -- Lua's lower() does not lowercase UTF-8 Cyrillic.
    name = name:gsub("%s+", ""):gsub("Спутников", "спутников")
    return name:lower()
end
local channelDefinitions = {}
for _, def in ipairs(standardChannels) do
    channelDefinitions[ChannelNameKey(def.id)] = def
    channelDefinitions[ChannelNameKey(def.en)] = def
    channelDefinitions[ChannelNameKey(def.ru)] = def
    for _, alias in ipairs(def.aliases) do channelDefinitions[ChannelNameKey(alias)] = def end
end

function chatModule:GetChannelStorageKey(name)
    name = self:GetChannelBaseName(name)
    local def = channelDefinitions[ChannelNameKey(name)]
    return def and def.id or name
end

function chatModule:GetChannelDisplayName(name)
    name = self:GetChannelBaseName(name)
    local def = channelDefinitions[ChannelNameKey(name)]
    if not def then return name end
    -- Keep the language of the client-provided name.
    return name:find("[\128-\255]") and def.ru or def.en
end
_G.SarychUI_GetChatChannelDisplayName = function(name)
    return chatModule:GetChannelDisplayName(name)
end

function chatModule:GetChannelOverride(name)
    name = self:GetChannelBaseName(name)
    local db = SarychUI.db.profile.modules.chat
    local custom = db.channelAbbreviations
    local storageKey = self:GetChannelStorageKey(name)
    if custom and custom[storageKey] ~= nil then return custom[storageKey] end
    if custom and custom[name] ~= nil then return custom[name] end
    local def = channelDefinitions[ChannelNameKey(name)]
    if custom and def then
        -- Older profiles may store the readable name instead of the stable ID.
        if custom[def.en] ~= nil then return custom[def.en] end
        if custom[def.ru] ~= nil then return custom[def.ru] end
        for _, alias in ipairs(def.aliases) do
            if custom[alias] ~= nil then return custom[alias] end
        end
    end
    local key = def and def.key
    local value = key and db[key]
    -- The old Russian default must not rename channels on other clients.
    if key == "lfgAbbrev" and value == "[Поиск]" and name == "LookingForGroup" then return "" end
    if value ~= nil then return value end
    if name == "ПоискСпутников" or name == "Поиск спутников" then return "[Поиск]" end
    return ""
end

-- Функция получения сокращения канала (ADAPTIVE)
local function GetChannelAbbreviation(channelName, channelNumber)
    if not channelName then return "" end
    
    -- Проверяем статус модуля
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules or not SarychUI.db.profile.modules.chat or not SarychUI.db.profile.modules.chat.enabled then
        return ""
    end
    
    -- Проверяем, включены ли сокращения
    local shorteningEnabled = sarChat_GetSetting and (sarChat_GetSetting("channelShorteningEnabled", 1) == 1)
    if not shorteningEnabled then return "" end
    
    if channelNumber then
        local abbreviation = chatModule:GetChannelOverride(channelName)
        return (abbreviation:gsub("%%1", function() return tostring(channelNumber) end))
    end

    -- Для каналов без номера (Guild, Officer, Party, Raid, etc.)
    local staticChannels = {
        ["GUILD"] = "abbrGuild",
        ["OFFICER"] = "abbrOfficer",
        ["PARTY"] = "abbrParty",
        ["PARTY_LEADER"] = "abbrPartyLeader",
        ["PARTY_GUIDE"] = "abbrPartyGuide",
        ["SAY"] = "abbrSay", ["YELL"] = "abbrYell",
        ["WHISPER"] = "abbrWhisper", ["WHISPER_INFORM"] = "abbrWhisperInform",
        ["RAID"] = "abbrRaid",
        ["RAID_LEADER"] = "abbrRaidLeader",
        ["RAID_WARNING"] = "abbrRaidWarning",
        ["BATTLEGROUND"] = "abbrBattleground",
        ["BATTLEGROUND_LEADER"] = "abbrBattlegroundLeader"
    }
    
    for msgType, settingKey in pairs(staticChannels) do
        if channelName == msgType or channelName == "CHAT_MSG_" .. msgType then
            return sarChat_GetSetting and sarChat_GetSetting(settingKey, "") or ""
        end
    end
    
    return ""
end

-- Let Blizzard format the prefix from the message type. No text from the
-- player's message is searched or replaced for SAY, YELL, GUILD, etc.
local channelShorteningCache = { active = false }
local channelFormats = {}
local channelFormatKeys = {
    GUILD = "abbrGuild", OFFICER = "abbrOfficer",
    PARTY = "abbrParty", PARTY_LEADER = "abbrPartyLeader", PARTY_GUIDE = "abbrPartyGuide",
    RAID = "abbrRaid", RAID_LEADER = "abbrRaidLeader",
    RAID_WARNING = "abbrRaidWarning", SAY = "abbrSay", YELL = "abbrYell",
    BATTLEGROUND = "abbrBattleground", BATTLEGROUND_LEADER = "abbrBattlegroundLeader",
    WHISPER = "abbrWhisper", WHISPER_INFORM = "abbrWhisperInform",
}

chatModule.channelFormatKeys = channelFormatKeys

function chatModule:GetChannelFormatLabel(chatType)
    local name = "CHAT_" .. chatType .. "_GET"
    local fmt = channelFormats[name] and channelFormats[name].original or _G[name]
    if type(fmt) ~= "string" then return nil end
    local tag = fmt:match("%[.-%]")
    if tag then return tag end
    if chatType == "WHISPER_INFORM" then
        return fmt:match("^(.-)%s*|3%-2%(%%s%)") or fmt:match("^(.-)%s*%%s")
    end
    return fmt:match("%%s%s+(.-):%s*$")
end

local function RestoreChannelFormats()
    for name, saved in pairs(channelFormats) do
        if _G[name] == saved.applied then
            _G[name] = saved.original
        end
    end
    channelFormats = {}
    channelShorteningCache.active = false
end
_G.RestoreChannelShorteningFormats = RestoreChannelFormats

local function RefreshChannelShorteningCache()
    RestoreChannelFormats()
    local db = SarychUI.db.profile.modules.chat
    channelShorteningCache.active = (db.enabled == true or db.enabled == 1)
        and sarChat_GetSetting("channelShorteningEnabled", 1) == 1
    if not channelShorteningCache.active then return end
    for chatType, key in pairs(channelFormatKeys) do
        local rep = ResolveChannelAbbrev(key)
        local name = "CHAT_" .. chatType .. "_GET"
        if rep and type(_G[name]) == "string" then
            -- Escape percent signs because Blizzard passes this through format().
            rep = rep:gsub("%%", "%%%%")
            local original = _G[name]
            local label = chatModule:GetChannelFormatLabel(chatType)
            local prefix = original
            if label and label ~= "" then
                local first, last = original:find(label, 1, true)
                prefix = original:sub(1, first - 1) .. rep .. original:sub(last + 1)
            end
            channelFormats[name] = { original = _G[name], applied = prefix }
            _G[name] = prefix
        end
    end
end

-- Функция применения сокращений к сообщению чата (locale-aware via Blizzard / CHATBAR_*)
local function ApplyChannelShortening(message, chatType, channelName, channelNumber)
    if not message or message == "" then return message end

    if not channelShorteningCache.active then
        return message
    end

    local text = tostring(message)

    -- Replace only channel hyperlink labels, never matching text in the message body.
    -- Ordinary chat uses channel:channel:N; Blizzard's channel lists use
    -- channel:CHANNEL:N, and channel notices can use channel:N.
    text = text:gsub("(|Hchannel:([^|]+)|h)(.-)(|h)", function(link, target, label, close)
        local number = target:match("^%d+$") or target:lower():match("^channel:(%d+)$")
        if not number then return link .. label .. close end
        local id, name = GetChannelName(tonumber(number))
        if not id or id == 0 or not name then return link .. label .. close end
        local abbreviation = chatModule:GetChannelOverride(name)
        if abbreviation == "" then return link .. label .. close end
        abbreviation = abbreviation:gsub("%%1", function() return number end)
        return link .. abbreviation .. close
    end)

    return text
end

local function PrepareChatCopyText(msg)
    if not msg then return msg end
    if sarChat_GetSetting("emotionIcons", 1) == 1 then
        local emotions = _G.SarychUI_ChatEmotions
        if emotions and emotions.GetSmileyPlainText then
            return emotions.GetSmileyPlainText(msg)
        end
    end
    msg = msg:gsub("|T.-|t", "")
    msg = msg:gsub("|A.-|a", "")
    return msg
end

-- ========================================
-- CHAT COPYING FUNCTIONS (LEATRIX PLUS STYLE)
-- ========================================

-- Глобальная переменная для контроля копирования
_G.SarychUI_ChatCopyingEnabled = false

-- Создаем окно копирования чата в стиле Leatrix Plus
local function CreateChatCopyWindow()
    if _G._chatCopyingInitialized then return end
    _G._chatCopyingInitialized = true
    
    ----------------------------------------
    -- 1) Main frame (Leatrix look)      --
    ----------------------------------------
    local frame = CreateFrame("Frame", "SarychUI_ChatCopyFrame", UIParent)
    frame:Hide()
    frame:SetSize(600, 300)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 130)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:SetMinResize(600, 50)
    frame:SetMaxResize(600, 680)
    frame:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16,
        edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.6)

    -- Add to UISpecialFrames for ESC key functionality
    if _G.UISpecialFrames then
        tinsert(_G.UISpecialFrames, "SarychUI_ChatCopyFrame")
    end

    -- Define centralized cleanup logic
    local function PerformChatCopyFrameCleanup()
        local editorToClose = _G.SarychUI_ChatCopyEdit
        if editorToClose then
            if editorToClose:IsShown() and editorToClose:HasFocus() then
                editorToClose:ClearFocus()
            end
            editorToClose:SetText("")
            editorToClose:Hide()
            if _G.SarychUI_ChatCopyScroll and _G.SarychUI_ChatCopyScroll:GetScrollChild() == editorToClose then
                _G.SarychUI_ChatCopyScroll:SetScrollChild(nil)
            end
        end
        _G.SarychUI_ChatCopyEdit = nil
    end

    frame:SetScript("OnHide", PerformChatCopyFrameCleanup)

    ----------------------------------------
    -- 2) Title bar (drag/resize/close) --
    ----------------------------------------
    local title = CreateFrame("Frame", nil, frame)
    title:SetSize(600, 36)
    title:SetPoint("TOP", frame, "TOP", 0, 40)
    title:SetFrameStrata("MEDIUM")
    title:EnableMouse(true)
    title:SetMovable(true)
    title:SetBackdrop(frame:GetBackdrop())
    title:SetBackdropColor(0, 0, 0, 0.6)

    -- message count
    title.count = title:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title.count:SetPoint("LEFT", 9, 0)
    title.count:SetFont(title.count:GetFont(), 16)
    title.count:SetText(L and (L["Messages"] or "Сообщения: 0") or "Сообщения: 0")

    -- drag-to-size & close hint
    title.hint = title:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title.hint:SetPoint("RIGHT", -9, 0)
    title.hint:SetFont(title.hint:GetFont(), 16)
    title.hint:SetText(L and (L["Drag_to_size"] or "Перетащите для изменения размера | ПКМ для закрытия") or "Перетащите для изменения размера | ПКМ для закрытия")
    title.hint:SetWidth(600 - title.count:GetStringWidth() - 30)
    title.hint:SetJustifyH("RIGHT")

    -- Forward declare functions
    local Close, ShowChatbox, ResizeEdit, ScrollToBottomReliable

    Close = function()
        if frame:IsShown() then
            frame:Hide()
        end
    end

    -- drag, resize and close handlers for the title bar
    title:HookScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then
            frame:StartSizing("TOP")
        elseif btn == "RightButton" then
            Close()
        end
    end)
    title:HookScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" then
            frame:StopMovingOrSizing()
        elseif btn == "MiddleButton" then
            frame:SetSize(600, 170)
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 130)
    end
end)

    ----------------------------------------
    -- 3) ScrollFrame (ElvUI)           --
    ----------------------------------------
    local scroll = CreateFrame("ScrollFrame", "SarychUI_ChatCopyScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -36)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 8)

    local sb = scroll.ScrollBar or SarychUI_ChatCopyScrollScrollBar
    sb:ClearAllPoints()
    sb:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, -16)
    sb:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 16)

    -- right-click to close on all areas
    frame:HookScript("OnMouseDown", function(_, btn)
        if btn == "RightButton" then
            Close()
        end
    end)
    scroll:HookScript("OnMouseDown", function(_, btn)
        if btn == "RightButton" then
            Close()
        end
    end)

    -- dynamically resize edit-box height
    ResizeEdit = function(count)
        local currentEdit = _G.SarychUI_ChatCopyEdit
        if not currentEdit then return end
        local _, size = currentEdit:GetFont()
        local needed = count * (size + 2)
        currentEdit:SetHeight(max(needed, scroll:GetHeight()))
    end

    -- scroll with mouse-wheel
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local currentEdit = _G.SarychUI_ChatCopyEdit
        local maxScrollRange = self:GetVerticalScrollRange()
        if not maxScrollRange or maxScrollRange <= 0 then return end
        local currentScroll = self:GetVerticalScroll()
        local viewHeight = self:GetHeight()
        local stepAmount
        if IsAltKeyDown() then
            stepAmount = viewHeight
        else
            local fontHeight = 14
            if currentEdit and currentEdit:IsShown() then
                local _, fh = currentEdit:GetFont()
                if fh and fh > 0 then
                    fontHeight = fh
                end
            end
            local linesToScroll = 3
            stepAmount = fontHeight * linesToScroll
        end
        local newScrollPosition
        if delta > 0 then
            newScrollPosition = IsShiftKeyDown() and 0 or (currentScroll - stepAmount)
        else
            newScrollPosition = IsShiftKeyDown() and maxScrollRange or (currentScroll + stepAmount)
        end
        newScrollPosition = max(0, newScrollPosition)
        newScrollPosition = min(newScrollPosition, maxScrollRange)
        self:SetVerticalScroll(newScrollPosition)
    end)

    ----------------------------------------
    -- 4) Populate on Ctrl+Click tabs    --
    ----------------------------------------
    local chatTypeIndexToName = {}
    for chatType in pairs(ChatTypeInfo) do
        chatTypeIndexToName[GetChatTypeIndex(chatType)] = chatType
    end

    local function SnapScrollToBottom(scrollInstance)
        if not scrollInstance or not scrollInstance:IsShown() then
            return 0
        end
        local range = scrollInstance:GetVerticalScrollRange() or 0
        if range < 0 then
            range = 0
        end
        scrollInstance:SetVerticalScroll(range)
        local sb = scrollInstance.ScrollBar or _G.SarychUI_ChatCopyScrollScrollBar
        if sb and sb.SetMinMaxValues and sb.SetValue then
            sb:SetMinMaxValues(0, range)
            sb:SetValue(range)
        end
        return range
    end

    -- Content height / scroll range settle after Show(); keep snapping to bottom until stable.
    ScrollToBottomReliable = function(scrollInstance, editInstance, maxAttempts)
        maxAttempts = maxAttempts or 30
        local lastHeight, lastRange = -1, -1
        local attempts = 0
        local function tryScroll()
            attempts = attempts + 1
            if not scrollInstance or not frame:IsShown() then
                return
            end
            if editInstance and editInstance:IsShown() then
                local curHeight = editInstance:GetHeight() or 0
                local range = SnapScrollToBottom(scrollInstance)
                local stillGrowing = (curHeight ~= lastHeight) or (range ~= lastRange)
                lastHeight, lastRange = curHeight, range
                if stillGrowing and attempts < maxAttempts then
                    After(0.02, tryScroll)
                elseif attempts < 3 then
                    -- One extra push after layout finishes (ScrollFrame often resets to top once).
                    After(0.02, tryScroll)
                end
            elseif attempts < maxAttempts then
                After(0.02, tryScroll)
            end
        end
        tryScroll()
    end

    -- When scroll range changes after SetText, Blizzard resets to top - snap back down while opening.
    scroll:HookScript("OnScrollRangeChanged", function(self)
        if frame._suiSnapToBottom and frame:IsShown() then
            SnapScrollToBottom(self)
        end
    end)

    ShowChatbox = function(chatFrame)
        -- Clean up previous edit box if one exists
        if _G.SarychUI_ChatCopyEdit then
            local oldEdit = _G.SarychUI_ChatCopyEdit
            oldEdit:Hide()
            oldEdit:SetText("")
            if _G.SarychUI_ChatCopyScroll and _G.SarychUI_ChatCopyScroll:GetScrollChild() == oldEdit then
                _G.SarychUI_ChatCopyScroll:SetScrollChild(nil)
            end
        end
        _G.SarychUI_ChatCopyEdit = nil

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetFontObject(ChatFontNormal)
        edit:SetMultiLine(true)
        edit:SetMaxLetters(0)
        edit:SetAutoFocus(false)
        edit:EnableMouse(true)
        edit:EnableMouseWheel(true)
        edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
        edit:SetWidth(scroll:GetWidth())
        scroll:SetScrollChild(edit)
        _G.SarychUI_ChatCopyEdit = edit

        edit:HookScript("OnCursorChanged", function(self_hooked_edit)
            if not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton") then
                After(0.02, function()
                    local currentEdit = _G.SarychUI_ChatCopyEdit
                    local currentScroll = _G.SarychUI_ChatCopyScroll
                    if not currentEdit or not currentEdit:IsShown() or currentEdit ~= self_hooked_edit then return end
                    local fontHeight = select(2, currentEdit:GetFont()) or 14
                    local cursorPos = currentEdit:GetCursorPosition()
                    local text = currentEdit:GetText()
                    local n = 0
                    for i = 1, cursorPos do
                        if text:sub(i, i) == "\n" then
                            n = n + 1
            end
    end
                    local line = n + 1
                    local totalLines = 1
                    for _ in text:gmatch("\n") do
                        totalLines = totalLines + 1
                    end
                    local scrollMax = currentScroll:GetVerticalScrollRange()
                    if line == totalLines then
                        currentScroll:SetVerticalScroll(scrollMax)
                    else
                        local scrollMin = currentScroll:GetVerticalScroll()
                        local scrollHeight = currentScroll:GetHeight()
                        local minLine = floor(scrollMin / fontHeight + 1.5)
                        local maxLine = floor((scrollMin + scrollHeight) / fontHeight + 0.5)
                        if line < minLine then
                            currentScroll:SetVerticalScroll((line - 1) * fontHeight)
                        elseif line > maxLine then
                            currentScroll:SetVerticalScroll(max(0, (line - floor(scrollHeight / fontHeight)) * fontHeight))
                        end
                    end
                end)
            end
        end)

        edit:HookScript("OnMouseDown", function(_, btn)
            if btn == "RightButton" then
                Close()
            end
        end)
        edit:SetScript("OnEscapePressed", Close)

        edit:ClearFocus()
        edit:SetText("")
        local num = chatFrame:GetNumMessages()

        if num == 0 then
            title.count:SetText(L and (L["Messages"] or "Сообщения: 0") or "Сообщения: 0")
            ResizeEdit(0)
            frame:Show()
            return
        end

        local lines, count = {}, 0
        for i = 1, num do
            local msg, _, lineID = chatFrame:GetMessageInfo(i)
            if msg then
                msg = PrepareChatCopyText(msg)
                local info = ChatTypeInfo[chatTypeIndexToName[lineID]]
                local r, g, b = (info and info.r) or 1, (info and info.g) or 1, (info and info.b) or 1
                local hex = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
                msg = hex .. msg:gsub("|r", "|r" .. hex) .. "|r"
                tinsert(lines, msg)
                count = count + 1
            end
        end

        title.count:SetText((L and (L["Messages"] or "Сообщения: %d") or "Сообщения: %d"):format(count))
        edit:SetText(tconcat(lines, "\n"))
        ResizeEdit(count)
        frame._suiSnapToBottom = true
        frame:Show()
        SnapScrollToBottom(scroll)
        ScrollToBottomReliable(scroll, edit, 30)
        After(0.15, function()
            if frame:IsShown() then
                SnapScrollToBottom(scroll)
            end
            frame._suiSnapToBottom = nil
        end)
    end

    -- Store references
    _G.SarychUI_ChatCopyFrame = frame
    _G.SarychUI_ChatCopyTitle = title
    _G.SarychUI_ChatCopyScroll = scroll
    _G.SarychUI_ChatCopyShowChatbox = ShowChatbox
    _G.SarychUI_ChatCopyClose = Close
end

-- Функция включения/отключения копирования чата
local function EnableChatCopying(enabled)
    if not enabled then 
        _G.SarychUI_ChatCopyingEnabled = false
        return 
    end
    
    _G.SarychUI_ChatCopyingEnabled = true
    
    -- Создаем окно копирования
    CreateChatCopyWindow()
    
    -- Хукаем Ctrl+Click по вкладкам чата (как в Leatrix_Plus)
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrameTab = _G["ChatFrame" .. i .. "Tab"]
        if chatFrameTab and not chatFrameTab._copyHooksInstalled then
            chatFrameTab._copyHooksInstalled = true
            
            chatFrameTab:HookScript("OnMouseUp", function(self, button)
                -- Проверяем глобальный флаг
                if not _G.SarychUI_ChatCopyingEnabled then return end
                
                -- Проверяем статус модуля
                if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules or not SarychUI.db.profile.modules.chat or not SarychUI.db.profile.modules.chat.enabled then
                    return
                end
                
                -- Проверяем настройку
                local copyEnabled = sarChat_GetSetting and (sarChat_GetSetting("copyOnCtrlClickEnabled", 1) == 1)
                if not copyEnabled then
                    return
                end
                
                -- Проверяем Ctrl+Click (как в Leatrix_Plus)
                if button ~= "LeftButton" or not IsControlKeyDown() then
                            return
                        end
                
                local frame = _G.SarychUI_ChatCopyFrame
                local showChatbox = _G.SarychUI_ChatCopyShowChatbox
                local close = _G.SarychUI_ChatCopyClose
                
                if not frame or not showChatbox or not close then return end
                
                local chatFrame = _G["ChatFrame" .. self:GetID()]
                if not chatFrame then return end
                
                -- Если окно уже открыто для этого чата - закрываем, иначе открываем
                if frame:IsShown() and _G.SarychUI_CurrentChatSource == chatFrame then
                    close()
                else
                    _G.SarychUI_CurrentChatSource = chatFrame
                    showChatbox(chatFrame)
                end
            end)
        end
    end
end

-- Функция отключения копирования чата
local function DisableChatCopying()
    -- Отключаем глобальный флаг
    _G.SarychUI_ChatCopyingEnabled = false
    
    -- Скрываем окно копирования
    if _G.SarychUI_ChatCopyFrame then
        _G.SarychUI_ChatCopyFrame:Hide()
    end
end

-- ========================================
-- URL COPYING FUNCTIONS (EXACT COPY FROM sarChat)
-- ========================================

-- Глобальная переменная для контроля URL копирования
_G.SarychUI_UrlCopyingEnabled = false

-- URL patterns and functions (EXACT COPY FROM sarChat)
local color = "FFFFDEAD"
local pattern1 = '(([%w_.~!*:@&+$/?%%#-]-)(%w[-.%w]*%.)(%w+)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%%#=-]*))'
local pattern2 = '((%f[%w]%a+://)(%w[-.%w]*)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%%#=-]*))'
local domains = [[.aaa.aarp.abarth.abb.abbott.abbvie.abc.abogado.abudhabi.ac.academy.accenture.accountant.accountants.aco.active.actor.ad.ads.adult.ae.aeg.aero.aetna.af.afl.africa.ag.agakhan.agency.ai.aig.aigo.airbus.airforce.airtel.akdn.al.alfaromeo.alibaba.alipay.allfinanz.allstate.ally.alsace.alstom.am.amazon.americanexpress.amex.amica.amsterdam.an.analytics.android.anz.ao.aol.apartments.app.apple.aq.aquarelle.ar.arab.aramco.archi.army.arpa.art.arte.as.asia.associates.at.attorney.au.auction.audi.audible.audio.auspost.author.auto.autos.aw.aws.ax.axa.az.azure.ba.baby.baidu.bananarepublic.band.bank.bar.barcelona.barclaycard.barclays.barefoot.bargains.baseball.basketball.bauhaus.bayern.bb.bbc.bbt.bbva.bcg.bcn.bd.be.beauty.beer.bentley.berlin.best.bestbuy.bet.bf.bg.bh.bharti.bi.bible.bid.bike.bing.bingo.bio.biz.bj.black.blackfriday.blanco.blockbuster.blog.bloomberg.blue.bm.bms.bmw.bn.bnl.bnpparibas.bo.boehringer.bom.bond.boo.book.booking.boots.bosch.bostik.boston.bot.boutique.box.bq.br.bradesco.bridgestone.broadway.broker.brother.brussels.bs.bt.budapest.bugatti.build.builders.business.buy.buzz.bv.bw.by.bz.bzh.ca.cab.cafe.cal.call.calvinklein.cam.camera.camp.cancerresearch.canon.capetown.capital.capitalone.car.caravan.cards.care.career.careers.cars.cartier.casa.case.cash.casino.cat.catering.catholic.cba.cbn.cbre.cbs.cc.cd.center.ceo.cern.cf.cfa.cfd.cg.ch.chanel.channel.chase.chat.cheap.chintai.christmas.chrome.chrysler.church.ci.cipriani.circle.cisco.citadel.citi.citic.city.ck.cl.claims.cleaning.click.clinic.clinique.clothing.cloud.club.clubmed.cm.cn.co.coach.codes.coffee.college.cologne.com.comcast.commbank.community.company.compare.computer.condos.construction.consulting.contact.contractors.cooking.cool.coop.corsica.country.coupon.coupons.courses.cr.credit.creditcard.creditunion.cricket.crown.crs.cruise.cruises.cs.csc.cu.cuisinella.cv.cw.cx.cy.cymru.cz.dabur.dad.dance.data.date.dating.datsun.day.dd.de.deal.dealer.deals.degree.delivery.dell.deloitte.delta.democrat.dental.dentist.desi.design.dev.dhl.diamonds.diet.digital.direct.directory.discount.discover.dish.diy.dj.dk.dm.dnp.do.docs.doctor.dodge.dog.doha.domains.dot.download.drive.dubai.duck.dunlop.dupont.durban.dvag.dz.earth.eat.ec.eco.edeka.edu.education.ee.eg.eh.email.emerck.energy.engineer.engineering.enterprises.epost.epson.equipment.er.ericsson.erni.es.esq.estate.esurance.et.etisalat.eu.eurovision.eus.events.everbank.example.exchange.expert.exposed.express.extraspace.fage.fail.fairwinds.faith.family.fan.fans.farm.farmers.fashion.fast.fedex.feedback.ferrari.ferrero.fi.fiat.fidelity.film.final.finance.financial.fire.firestone.firm.firmdale.fish.fishing.fit.fitness.fj.fk.flickr.flights.flir.florist.flowers.flsmidth.fly.fm.fo.foo.food.foodnetwork.football.ford.forex.forsale.forum.foundation.fox.fr.free.fresenius.frl.frogans.frontdoor.frontier.fujitsu.fujixerox.fun.fund.furniture.futbol.fx.fyi.ga.gal.gallery.gallo.gallup.game.games.gap.garden.gay.gb.gbiz.gd.gdn.ge.gea.gent.genting.gf.gg.gh.gi.gift.gifts.gives.giving.gl.glass.gle.global.globo.gm.gmail.gmbh.gmo.gmx.gn.godaddy.gold.goldpoint.golf.goodyear.goog.google.gop.gov.gp.gq.gr.grainger.graphics.gratis.green.gripe.grocery.group.gs.gt.gu.guardian.gucci.guide.guitars.guru.gw.gy.hair.hamburg.hangout.haus.hbo.hdfc.hdfcbank.health.healthcare.help.helsinki.here.hermes.hiphop.hisamitsu.hitachi.hiv.hk.hkt.hm.hn.hockey.holdings.holiday.homegoods.homes.homesense.honda.honeywell.horse.hospital.host.hosting.hot.hoteles.hotels.hotmail.house.how.hr.hsbc.ht.hu.hughes.hyatt.hyundai.ibm.ice.icu.id.ie.ieee.ifm.ikano.il.im.imdb.immo.immobilien.in.industries.infiniti.info.ing.ink.institute.insurance.insure.int.intel.international.intuit.invalid.investments.io.ipiranga.iq.ir.irish.is.iselect.ist.istanbul.it.itau.itv.iveco.jaguar.java.jcb.jcp.je.jeep.jetzt.jewelry.jm.jo.jobs.joburg.joy.jp.jpmorgan.juegos.juniper.kaufen.kddi.ke.kerryhotels.kerrylogistics.kerryproperties.kfh.kg.kh.ki.kia.kim.kinder.kindle.kitchen.kiwi.km.kn.koeln.komatsu.kp.kpmg.kr.krd.kred.kuokgroup.kw.ky.kyoto.kz.la.lacaixa.ladbrokes.lamborghini.lancaster.lancia.lancome.land.landrover.lanxess.lasalle.lat.latrobe.law.lawyer.lb.lc.lds.lease.leclerc.legal.lego.lexus.lgbt.li.liaison.lidl.life.lifeinsurance.lifestyle.lighting.like.lilly.limited.limo.lincoln.linde.link.lipsy.live.living.lixil.lk.loan.loans.local.localhost.locker.locus.lol.london.lotte.lotto.love.lpl.lplfinancial.lr.ls.lt.ltd.ltda.lu.lundbeck.lupin.luxe.luxury.lv.ly.ma.macys.madrid.maif.maison.makeup.man.management.mango.map.market.marketing.markets.marriott.maserati.mattel.mba.mc.mckinsey.md.me.med.media.meet.melbourne.meme.memorial.men.menu.metlife.mg.mh.miami.microsoft.mil.mini.mint.mit.mitsubishi.mk.ml.mlb.mm.mma.mn.mo.mobi.mobile.mobily.moda.moe.moi.mom.monash.money.monster.mormon.mortgage.moscow.moto.motorcycles.mov.movie.movistar.mp.mq.mr.ms.msd.mt.mtn.mtr.mu.museum.music.mutual.mv.mw.mx.my.mz.na.nadex.nagoya.name.nationwide.nato.natura.navy.nba.nc.ne.nec.net.netflix.network.neustar.new.newholland.news.nexus.nf.nfl.ng.ngo.nhk.ni.nico.nike.nikon.ninja.nissan.nissay.nl.no.nokia.nom.northwesternmutual.norton.now.np.nr.nra.nrw.nt.ntt.nu.nyc.nz.obi.observer.off.office.okinawa.om.omega.one.ong.onion.onl.online.ooo.open.oracle.orange.org.organic.origins.osaka.otsuka.ovh.pa.page.panasonic.paris.partners.partners.parts.party.passagens.pay.pccw.pe.pet.pf.pfizer.pg.ph.pharmacy.philips.phone.photo.photography.photos.physio.piaget.pics.pictet.pictures.pid.pin.ping.pink.pioneer.pizza.pk.pl.place.play.playstation.plumbing.plus.pm.pn.pohl.poker.politie.porn.post.pr.praxi.press.prime.pro.prod.productions.prof.progressive.promo.properties.property.protection.pru.prudential.ps.pt.pub.pw.pwc.py.qa.qpon.quebec.quest.qvc.racing.radio.re.read.realestate.realtor.realty.recipes.red.redstone.rehab.reise.reisen.reit.reliance.ren.rent.rentals.repair.report.republican.rest.restaurant.review.reviews.rexroth.rich.ricoh.rio.rip.rmit.ro.rocher.rocks.rodeo.rogers.room.rs.rsvp.ru.rugby.ruhr.run.rw.rwe.ryukyu.sa.saarland.safe.safety.sakura.sale.samsung.sandvik.sandvikcoromant.sanofi.sap.sarl.save.saxo.sb.sbi.sbs.sc.sca.scb.schaeffler.schmidt.scholarships.school.schule.schwarz.science.scjohnson.scor.scot.sd.se.search.seat.secure.security.seek.select.sener.services.ses.seven.sew.sex.sexy.sfr.sg.sh.shangrila.sharp.shaw.shell.shiksha.shoes.shop.shopping.shouji.show.showtime.shriram.si.silk.sina.singles.site.sj.sk.ski.skin.sky.skype.sl.sling.sm.smart.smile.sn.sncf.so.soccer.social.softbank.software.sohu.solar.solutions.song.sony.soy.space.spiegel.sport.spot.spreadbetting.sr.ss.st.stada.staples.star.starhub.statebank.statefarm.statoil.stc.stcgroup.stockholm.storage.store.stream.studio.study.style.su.sucks.supplies.supply.support.surf.surgery.suzuki.sv.swatch.swiftcover.swiss.sx.sy.sydney.symantec.systems.sz.taipei.talk.taobao.target.tatamotors.tatar.tattoo.tax.taxi.tc.td.tdk.team.tech.technology.tel.telecity.telefonica.temasek.tennis.test.teva.tf.tg.th.theater.theatre.tickets.tienda.tiffany.tips.tires.tirol.tj.tjx.tk.tl.tm.tn.to.today.tokyo.tools.top.toray.toshiba.total.tours.town.toyota.toys.tp.tr.trade.trading.training.travel.travelchannel.travelers.travelersinsurance.trust.tt.tube.tui.tunes.tushu.tv.tvs.tw.tz.ua.ubs.uconnect.ug.uk.um.unicom.university.uno.uol.ups.us.uy.uz.va.vacations.vanguard.vc.ve.vegas.ventures.verisign.versicherung.vet.vg.vi.viajes.video.vig.viking.villas.vip.virgin.visa.vision.vista.vistaprint.vivo.vlaanderen.vn.vodka.volkswagen.volvo.vote.voting.voto.voyage.vu.vuelos.wales.walmart.walter.wang.wanggou.watch.watches.weather.weatherchannel.web.webcam.weber.website.wed.wedding.weibo.weir.wf.whoswho.wien.wiki.williamhill.win.windows.wine.winners.wme.wolterskluwer.woodside.work.works.world.wow.ws.wtc.wtf.xbox.xerox.xfinity.xihuan.xin.xxx.xyz.yachts.yahoo.yamaxun.yandex.ye.yodobashi.yoga.yokohama.you.youtube.yt.yu.za.zappos.zara.zero.zip.zippo.zm.zone.zr.zuerich.zw]]
local tlds = {}
for tld in domains:gmatch '%w+' do
    tlds[tld] = true
end
local function max4(a, b, c, d)
    return max(a + 0, b + 0, c + 0, d + 0)
end
local protocols = {
    [''] = 0,
    ['http://'] = 0,
    ['https://'] = 0,
    ['ftp://'] = 0
}

function formatURL(url)
    return ("|c%s|Hurl:%s|h[%s]|h|r"):format(color, url, url)
end

function makeClickable(self, event, msg, ...)
    -- Проверяем глобальный флаг
    if not _G.SarychUI_UrlCopyingEnabled then return false, msg, ... end
    
    local finished = {}
    local function escapePattern(s) return s:gsub("([%%%+%-%*%(%)%?%[%]%^])", "%%%1") end

    for url, prot, subd, tld, colon, port, slash, path in msg:gmatch(pattern1) do
        if not finished[url] and protocols[prot:lower()] == (1 - #slash) * #path and not subd:find '%W%W' and
            (colon == '' or port ~= '' and tonumber(port) and tonumber(port) < 65536) and
            (tlds[tld:lower()] or tld:find '^%d+$' and subd:find '^%d+%.%d+%.%d+%.$' and
                max4(tld, subd:match '^(%d+)%.(%d+)%.(%d+)%.$') < 256) then
            finished[url] = true
            msg = msg:gsub(escapePattern(url), formatURL(url))
        end
    end

    for url, prot, dom, colon, port, slash, path in msg:gmatch(pattern2) do
        if not finished[url] and not (dom .. '.'):find '%W%W' and protocols[prot:lower()] == (1 - #slash) * #path and
            (colon == '' or port ~= '' and tonumber(port) and tonumber(port) < 65536) then
            finished[url] = true
            msg = msg:gsub(escapePattern(url), formatURL(url))
            end
        end

    return false, msg, ...
end

-- Функция обработки клика по URL
local SetItemRef_orig = SetItemRef
function ClickURL_SetItemRef(link, text, button)
    if link:sub(1, 3) == "url" then
        local url = link:sub(5)
        -- Проверяем настройку
        if sarChat_GetSetting and sarChat_GetSetting("copyLinksEnabled", 1) ~= 1 then
            return SetItemRef_orig(link, text, button)
        end
        -- Вставляем URL в поле ввода чата
        local editBox = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend()) or _G["ChatFrame1EditBox"]
        if editBox then
            if ChatEdit_ActivateChat then
                ChatEdit_ActivateChat(editBox)
            else
                editBox:Show()
            end
            editBox:SetText(url)
            if editBox.HighlightText then
                editBox:HighlightText(0, editBox:GetNumLetters() or #url)
            end
            editBox:SetFocus()
        end
    else
        SetItemRef_orig(link, text, button)
                end
            end
            
-- Функция включения/отключения URL копирования
local urlFiltersRegistered = false

local URL_CHAT_TYPES = {
	"AFK", "BATTLEGROUND_LEADER", "BATTLEGROUND", "BN_WHISPER", "BN_WHISPER_INFORM", "CHANNEL", "DND",
	"EMOTE", "GUILD", "OFFICER", "PARTY_LEADER", "PARTY", "RAID_LEADER", "RAID_WARNING", "RAID", "SAY",
	"WHISPER", "WHISPER_INFORM", "YELL", "SYSTEM",
}

local function EnableUrlCopying(enabled)
    if not enabled then 
        _G.SarychUI_UrlCopyingEnabled = false
                        return
                    end
    
    _G.SarychUI_UrlCopyingEnabled = true
    
    -- Устанавливаем обработчик клика по URL
    SetItemRef = ClickURL_SetItemRef
    
    if urlFiltersRegistered then
        return
    end

    -- Регистрируем фильтры для всех типов чата
    for _, chat_type in pairs(URL_CHAT_TYPES) do
        ChatFrame_AddMessageEventFilter("CHAT_MSG_" .. chat_type, makeClickable)
    end
    urlFiltersRegistered = true
end

-- Функция отключения URL копирования
local function DisableUrlCopying()
    -- Отключаем глобальный флаг
    _G.SarychUI_UrlCopyingEnabled = false
    
    -- Восстанавливаем оригинальный SetItemRef
    SetItemRef = SetItemRef_orig
    
    if not urlFiltersRegistered then
        return
    end

    -- Удаляем фильтры для всех типов чата
    for _, chat_type in pairs(URL_CHAT_TYPES) do
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_" .. chat_type, makeClickable)
    end
    urlFiltersRegistered = false
end

-- ========================================
-- FAST SCROLL FUNCTIONS (EXACT COPY FROM sarChat)
-- ========================================

-- Глобальная переменная для контроля быстрой прокрутки
_G.SarychUI_FastScrollEnabled = false

-- Функция включения/отключения быстрой прокрутки
local function EnableFastScroll(enabled)
    if not enabled then 
        _G.SarychUI_FastScrollEnabled = false
        return 
    end
    
    _G.SarychUI_FastScrollEnabled = true
end

-- Хукаем FloatingChatFrame_OnMouseScroll для быстрой прокрутки (EXACT COPY FROM sarChat)
-- Этот хук устанавливается сразу при загрузке, как в оригинале
do
    local IsShiftKeyDown = IsShiftKeyDown
    local orig = FloatingChatFrame_OnMouseScroll
    local function FloatingChatFrame_OnMouseScroll_hk(...)
        -- ПРОВЕРЯЕМ СТАТУС МОДУЛЯ ПЕРВЫМ ДЕЛОМ!
        if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules or not SarychUI.db.profile.modules.chat or not SarychUI.db.profile.modules.chat.enabled then
            return
        end
        
        if not IsShiftKeyDown() then
            return
        end
        local enabled = true
        if sarChat_GetSetting then
            enabled = sarChat_GetSetting("fastScrollEnabled", 1) == 1
        end
        if not enabled then
            return
        end
        local steps = 5
        if sarChat_GetSetting then
            local v = sarChat_GetSetting("fastScrollSteps", 5)
            steps = tonumber(v) or 5
        end
        if steps < 1 then steps = 1 end
        for i = 1, steps do
            orig(...)
        end
    end
    hooksecurefunc("FloatingChatFrame_OnMouseScroll", FloatingChatFrame_OnMouseScroll_hk)
end

-- Функция отключения быстрой прокрутки
local function DisableFastScroll()
    -- Отключаем глобальный флаг
    _G.SarychUI_FastScrollEnabled = false
    -- Хуки остаются, но не работают из-за флага
end

-- ========================================
-- TRANSLIT ALIASES / CLEAR CHAT (owned by tools module)
-- ========================================

-- Глобальная переменная для контроля транслит-алиасов
_G.SarychUI_TranslitAliasesEnabled = false

-- Функция включения/отключения транслит-алиасов
local function EnableTranslitAliases(enabled)
    if not enabled then 
        _G.SarychUI_TranslitAliasesEnabled = false
        return 
    end
    
    _G.SarychUI_TranslitAliasesEnabled = true
end

-- Функция отключения транслит-алиасов
local function DisableTranslitAliases()
    -- Отключаем глобальный флаг
    _G.SarychUI_TranslitAliasesEnabled = false
end

local function ClearTranslitSlashCommands()
    if hash_SlashCmdList then
        hash_SlashCmdList["/кудщфв"] = nil
        hash_SlashCmdList["/аыефсл"] = nil
        hash_SlashCmdList["/jnrfp"] = nil
    end
    SlashCmdList["RELOADALIAS"] = nil
    SlashCmdList["FSTACKALIAS"] = nil
    SlashCmdList["OTKAZALIAS"] = nil
    SLASH_RELOADALIAS1 = nil
    SLASH_FSTACKALIAS1 = nil
    SLASH_OTKAZALIAS1 = nil
end

local function IsTranslitAliasesOn()
    if not SarychUI:IsBlizzardImprovementsEnabled() then
        return false
    end
    return (tonumber(ToolsSetting("translitAliasesEnabled", 1)) or 0) == 1
end

-- Функция применения транслит-алиасов
local function ApplyTranslitAliases(forceEnabled)
    if not SarychUI:IsBlizzardImprovementsEnabled() then
        ClearTranslitSlashCommands()
        return
    end
    
    local enabled
    if type(forceEnabled) == "boolean" then
        enabled = forceEnabled
    else
        local v = ToolsSetting("translitAliasesEnabled", 1)
        enabled = (tonumber(v) or 0) == 1
    end

    if enabled then
        -- /reload alias
        SLASH_RELOADALIAS1 = "/кудщфв"
        SlashCmdList["RELOADALIAS"] = function()
            if not IsTranslitAliasesOn() then return end
            ReloadUI()
        end
        if hash_SlashCmdList then hash_SlashCmdList["/кудщфв"] = "RELOADALIAS" end

        -- /fstack alias
        SLASH_FSTACKALIAS1 = "/аыефсл"
        SlashCmdList["FSTACKALIAS"] = function()
            if not IsTranslitAliasesOn() then return end
            local fn = SlashCmdList and SlashCmdList["FRAMESTACK"]
            if type(fn) == "function" then fn() end
        end
        if hash_SlashCmdList then hash_SlashCmdList["/аыефсл"] = "FSTACKALIAS" end

        -- /отказ alias via translit "/jnrfp"
        SLASH_OTKAZALIAS1 = "/jnrfp"
        SlashCmdList["OTKAZALIAS"] = function(msg)
            if not IsTranslitAliasesOn() then return end
            local extra = (type(msg) == "string" and msg ~= "") and (" " .. msg) or ""
            local editBox = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend()) or _G.ChatFrame1EditBox
            if not editBox then return end
            editBox:SetText("/отказ" .. extra)
            if ChatEdit_SendText then
                ChatEdit_SendText(editBox, 0)
            end
        end
        if hash_SlashCmdList then hash_SlashCmdList["/jnrfp"] = "OTKAZALIAS" end
    else
        ClearTranslitSlashCommands()
    end
end

local function ClearClearChatSlashCommands()
    if hash_SlashCmdList then
        hash_SlashCmdList["/clear"] = nil
        hash_SlashCmdList["/claer"] = nil
        hash_SlashCmdList["/сдуфк"] = nil
    end
    SlashCmdList["SARYCHUICLEARCHAT"] = nil
    SLASH_SARYCHUICLEARCHAT1 = nil
    SLASH_SARYCHUICLEARCHAT2 = nil
    SLASH_SARYCHUICLEARCHAT3 = nil
end

-- Команды /clear, /claer и «раскладочный» /сдуфк - очистка всех стандартных окон чата
local function ApplyClearChatSlashCommands(forceEnabled)
    if not SarychUI:IsBlizzardImprovementsEnabled() then
        ClearClearChatSlashCommands()
        return
    end

    local enabled
    if type(forceEnabled) == "boolean" then
        enabled = forceEnabled
    else
        local raw = ToolsSetting("clearChatSlashEnabled", 1)
        enabled = (tonumber(raw) or 0) == 1
    end

    if enabled then
        SLASH_SARYCHUICLEARCHAT1 = "/clear"
        SLASH_SARYCHUICLEARCHAT2 = "/claer"
        SLASH_SARYCHUICLEARCHAT3 = "/сдуфк"
        SlashCmdList["SARYCHUICLEARCHAT"] = function()
            if not SarychUI:IsBlizzardImprovementsEnabled() then return end
            if (tonumber(ToolsSetting("clearChatSlashEnabled", 1)) or 0) ~= 1 then return end
            local n = NUM_CHAT_WINDOWS or 10
            for i = 1, n do
                local cf = _G["ChatFrame"..i]
                if cf and cf.Clear then
                    cf:Clear()
                end
            end
        end
        if hash_SlashCmdList then
            hash_SlashCmdList["/clear"] = "SARYCHUICLEARCHAT"
            hash_SlashCmdList["/claer"] = "SARYCHUICLEARCHAT"
            hash_SlashCmdList["/сдуфк"] = "SARYCHUICLEARCHAT"
        end
    else
        ClearClearChatSlashCommands()
    end
end

-- Экспортируем функции для использования в модуле
_G.ApplyHotkeyIfNeeded = ApplyHotkeyIfNeeded
_G.HookHotkeys = HookHotkeys
_G.UnhookHotkeys = UnhookHotkeys
_G.After = After
_G.GetChannelAbbreviation = GetChannelAbbreviation
_G.RefreshChannelShorteningCache = RefreshChannelShorteningCache
_G.ApplyChannelShortening = ApplyChannelShortening
_G.EnableChatCopying = EnableChatCopying
_G.DisableChatCopying = DisableChatCopying
_G.EnableUrlCopying = EnableUrlCopying
_G.DisableUrlCopying = DisableUrlCopying
_G.EnableFastScroll = EnableFastScroll
_G.DisableFastScroll = DisableFastScroll
_G.EnableTranslitAliases = EnableTranslitAliases
_G.DisableTranslitAliases = DisableTranslitAliases
_G.ApplyTranslitAliases = ApplyTranslitAliases
_G.ApplyClearChatSlashCommands = ApplyClearChatSlashCommands

-- ========================================
-- CHAT TAB FONT SIZE MENU (ElvUI-style)
-- ElvUI/Core/Fonts.lua sets CHAT_FONT_HEIGHTS = {6..20}
-- Blizzard FCF dropdown reads CHAT_FONT_HEIGHTS for font size submenu
-- ElvUI/Modules/Chat/Chat.lua hooks FCF_SetChatWindowFontSize to re-apply custom font
-- ========================================

local SARYCH_CHAT_FONT_HEIGHTS = {6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}
local sarychOriginalChatFontHeights = nil
local sarychChatFontSizeHooked = false
local sarychChatFontSizeEventFrame = nil

local function IsChatModuleEnabled()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    return db and db.enabled
end

local function IsChatTabFontSizeMenuEnabled()
    return IsChatModuleEnabled() and sarChat_GetSetting("enableChatTabFontSizeMenu", 1) == 1
end

local function SaveOriginalChatFontHeights()
    if sarychOriginalChatFontHeights == nil and CHAT_FONT_HEIGHTS then
        sarychOriginalChatFontHeights = {}
        for i, v in ipairs(CHAT_FONT_HEIGHTS) do
            sarychOriginalChatFontHeights[i] = v
        end
    end
end

local function ApplyChatFontHeightsTable()
    if IsChatTabFontSizeMenuEnabled() then
        SaveOriginalChatFontHeights()
        CHAT_FONT_HEIGHTS = SARYCH_CHAT_FONT_HEIGHTS
    elseif sarychOriginalChatFontHeights then
        CHAT_FONT_HEIGHTS = sarychOriginalChatFontHeights
    end
end

local function GetChatFontSizesTable()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db then return nil end
    if type(db.chatFontSizes) ~= "table" then
        db.chatFontSizes = {}
    end
    return db.chatFontSizes
end

local function SaveChatFontSize(chatFrame, fontSize)
    if not chatFrame or type(fontSize) ~= "number" then return end
    local frameName = chatFrame.GetName and chatFrame:GetName()
    if not frameName then return end
    local sizes = GetChatFontSizesTable()
    if sizes then
        sizes[frameName] = fontSize
    end
end

local function ApplySavedChatFontSizes()
    if not FCF_SetChatWindowFontSize then return end
    local sizes = GetChatFontSizesTable()
    if not sizes then return end

    for frameName, fontSize in pairs(sizes) do
        if type(fontSize) == "number" and fontSize >= 6 and fontSize <= 20 then
            local chatFrame = _G[frameName]
            if chatFrame then
                FCF_SetChatWindowFontSize(nil, chatFrame, fontSize)
            end
        end
    end
end

local function SetupChatFontSizeHooks()
    if sarychChatFontSizeHooked or not hooksecurefunc or not FCF_SetChatWindowFontSize then return end

    hooksecurefunc("FCF_SetChatWindowFontSize", function(dropDown, chatFrame, fontSize)
        if not IsChatTabFontSizeMenuEnabled() then return end
        if not chatFrame and FCF_GetCurrentChatFrame then
            chatFrame = FCF_GetCurrentChatFrame()
        end
        if not fontSize and dropDown and dropDown.value then
            fontSize = dropDown.value
        end
        if chatFrame and fontSize then
            SaveChatFontSize(chatFrame, fontSize)
        end
    end)
    sarychChatFontSizeHooked = true
end

local function SetupChatFontSizeEvents()
    if sarychChatFontSizeEventFrame then return end

    sarychChatFontSizeEventFrame = CreateFrame("Frame")
    sarychChatFontSizeEventFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
    sarychChatFontSizeEventFrame:SetScript("OnEvent", function()
        if IsChatTabFontSizeMenuEnabled() then
            ApplySavedChatFontSizes()
        end
    end)

    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            if IsChatTabFontSizeMenuEnabled() then
                ApplySavedChatFontSizes()
            end
        end)
    end
end

local function EnableChatTabFontSizeMenu()
    ApplyChatFontHeightsTable()
    SetupChatFontSizeHooks()
    SetupChatFontSizeEvents()
    ApplySavedChatFontSizes()
end

local function DisableChatTabFontSizeMenu()
    ApplyChatFontHeightsTable()
end

-- ========================================
-- CHAT EDIT BOX CHARACTER COUNT (ElvUI-style)
-- ElvUI/Modules/Chat/Chat.lua StyleChat(): FontString + OnTextChanged + ChatEdit_UpdateHeader inset
-- ========================================

local CHAT_CHAR_INSET_EXTRA = 30
local CHAT_CHAR_FALLBACK_MAX = 255
local sarychChatCharCountHeaderHooked = false
local sarychChatCharCountEventFrame = nil
local sarychChatCharCountTempHooked = false

local function IsChatCharCountEnabled()
    return IsChatModuleEnabled() and sarChat_GetSetting("enableChatCharCount", 1) == 1
end

local function GetChatEditMaxLetters(editBox)
    if editBox and editBox.GetMaxLetters then
        local maxLetters = editBox:GetMaxLetters()
        if maxLetters and maxLetters > 0 then
            return maxLetters
        end
    end
    return CHAT_CHAR_FALLBACK_MAX
end

local function UpdateChatCharCount(editBox)
    if not editBox or not editBox.sarychCharCount then return end

    local counter = editBox.sarychCharCount
    if not IsChatCharCountEnabled() or not editBox:IsShown() then
        counter:Hide()
        counter:SetText("")
        return
    end

    local text = editBox:GetText() or ""
    local len = string.len(text)
    if len > 0 then
        local remaining = GetChatEditMaxLetters(editBox) - len
        counter:SetText(format(" %3d ", remaining))
        counter:Show()
    else
        counter:SetText("")
        counter:Hide()
    end
end

local function EnsureChatCharCountFontString(editBox)
    if not editBox or editBox.sarychCharCount then return end

    local charCount = editBox:CreateFontString(nil, "ARTWORK")
    charCount:SetFontObject(GameFontNormalSmall)
    charCount:SetTextColor(0.74, 0.74, 0.74, 0.6)
    charCount:SetPoint("TOPRIGHT", editBox, "TOPRIGHT", -5, 0)
    charCount:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", -5, 0)
    charCount:SetJustifyH("CENTER")
    charCount:SetWidth(40)
    charCount:Hide()
    editBox.sarychCharCount = charCount
end

local function ApplyChatCharCountInsets(editBox)
    if not editBox or not editBox.GetTextInsets or not editBox.SetTextInsets then return end

    local left, right, top, bottom = editBox:GetTextInsets()
    if editBox.sarychCharCountInsetBase == nil then
        editBox.sarychCharCountInsetBase = right or 0
    end

    if IsChatCharCountEnabled() then
        editBox:SetTextInsets(left, editBox.sarychCharCountInsetBase + CHAT_CHAR_INSET_EXTRA, top, bottom)
    else
        editBox:SetTextInsets(left, editBox.sarychCharCountInsetBase, top, bottom)
    end
end

local function HookChatEditBoxCharCount(editBox)
    if not editBox or editBox.sarychCharCountHooked then return end

    EnsureChatCharCountFontString(editBox)
    editBox.sarychCharCountHooked = true

    editBox:HookScript("OnTextChanged", function(self)
        UpdateChatCharCount(self)
    end)
    editBox:HookScript("OnShow", function(self)
        UpdateChatCharCount(self)
    end)
    editBox:HookScript("OnHide", function(self)
        if self.sarychCharCount then
            self.sarychCharCount:Hide()
            self.sarychCharCount:SetText("")
        end
    end)

    UpdateChatCharCount(editBox)
end

local function SetupAllChatEditBoxCharCounts()
    if NUM_CHAT_WINDOWS then
        for i = 1, NUM_CHAT_WINDOWS do
            local editBox = _G["ChatFrame"..i.."EditBox"]
            HookChatEditBoxCharCount(editBox)
            ApplyChatCharCountInsets(editBox)
        end
    end

    if CHAT_FRAMES then
        for _, frameName in ipairs(CHAT_FRAMES) do
            local editBox = _G[frameName.."EditBox"]
            HookChatEditBoxCharCount(editBox)
            ApplyChatCharCountInsets(editBox)
        end
    end
end

local function HookChatEditUpdateHeaderForCharCount()
    if sarychChatCharCountHeaderHooked or not hooksecurefunc then return end

    hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
        ApplyChatCharCountInsets(editBox)
        UpdateChatCharCount(editBox)
    end)
    sarychChatCharCountHeaderHooked = true
end

local function EnableChatCharCount()
    HookChatEditUpdateHeaderForCharCount()
    SetupAllChatEditBoxCharCounts()

    if not sarychChatCharCountEventFrame then
        sarychChatCharCountEventFrame = CreateFrame("Frame")
        sarychChatCharCountEventFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
        sarychChatCharCountEventFrame:SetScript("OnEvent", function()
            if IsChatCharCountEnabled() then
                SetupAllChatEditBoxCharCounts()
            end
        end)
    end

    if FCF_OpenTemporaryWindow and not sarychChatCharCountTempHooked then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            if IsChatCharCountEnabled() then
                SetupAllChatEditBoxCharCounts()
            end
        end)
        sarychChatCharCountTempHooked = true
    end
end

local function DisableChatCharCount()
    if NUM_CHAT_WINDOWS then
        for i = 1, NUM_CHAT_WINDOWS do
            local editBox = _G["ChatFrame"..i.."EditBox"]
            if editBox then
                if editBox.sarychCharCount then
                    editBox.sarychCharCount:Hide()
                    editBox.sarychCharCount:SetText("")
                end
                ApplyChatCharCountInsets(editBox)
            end
        end
    end

    if CHAT_FRAMES then
        for _, frameName in ipairs(CHAT_FRAMES) do
            local editBox = _G[frameName.."EditBox"]
            if editBox then
                if editBox.sarychCharCount then
                    editBox.sarychCharCount:Hide()
                    editBox.sarychCharCount:SetText("")
                end
                ApplyChatCharCountInsets(editBox)
            end
        end
    end
end

local function ApplyChatCharCountSettings()
    if IsChatCharCountEnabled() then
        EnableChatCharCount()
    else
        DisableChatCharCount()
    end
end

local function ApplyChatTabFontSizeMenuSettings()
    if IsChatTabFontSizeMenuEnabled() then
        EnableChatTabFontSizeMenu()
    else
        DisableChatTabFontSizeMenu()
    end
end

_G.EnableChatTabFontSizeMenu = EnableChatTabFontSizeMenu
_G.DisableChatTabFontSizeMenu = DisableChatTabFontSizeMenu
_G.ApplyChatTabFontSizeMenuSettings = ApplyChatTabFontSizeMenuSettings
_G.EnableChatCharCount = EnableChatCharCount
_G.DisableChatCharCount = DisableChatCharCount
_G.ApplyChatCharCountSettings = ApplyChatCharCountSettings

-- ========================================
-- CHANNEL NOTICE GlobalString SAFETY
-- Blizzard ChatFrame_MessageEventHandler does:
--   local globalstring = getglobal("CHAT_"..arg1.."_NOTICE")
--   format(globalstring, ...)
-- Private servers (e.g. AzerothCore NOT_IN_LFG) may send arg1 values with no
-- matching CHAT_*_NOTICE GlobalString, which errors. Ensure a string exists
-- before Blizzard reaches format().
-- ========================================

local CHANNEL_NOTICE_FALLBACK = "|Hchannel:%d|h[%s]|h"
local CONVERSATION_NOTICE_FALLBACK = "%s: %s"

local function ChatGlobalGet(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if type(getglobal) == "function" then
		return getglobal(name)
	end
	return _G[name]
end

local function ChatGlobalSet(name, value)
	if type(name) ~= "string" or name == "" then
		return
	end
	_G[name] = value
	if type(setglobal) == "function" then
		pcall(setglobal, name, value)
	end
end

local function EnsureChatNoticeGlobal(noticeType, keyPrefix, fallback)
	if type(noticeType) ~= "string" or noticeType == "" then
		return fallback
	end
	keyPrefix = keyPrefix or "CHAT_"
	local bnKey = keyPrefix .. noticeType .. "_NOTICE_BN"
	local key = keyPrefix .. noticeType .. "_NOTICE"

	-- Mirror Blizzard: prefer *_NOTICE_BN, then *_NOTICE.
	local globalstring = ChatGlobalGet(bnKey)
	if globalstring == nil then
		globalstring = ChatGlobalGet(key)
	end
	if globalstring == nil then
		globalstring = fallback or CHANNEL_NOTICE_FALLBACK
		ChatGlobalSet(key, globalstring)
	end
	return globalstring
end

local function SeedKnownMissingChannelNotices()
	-- AzerothCore LookingForGroup: arg1 = "NOT_IN_LFG", client has no CHAT_NOT_IN_LFG_NOTICE.
	if ChatGlobalGet("CHAT_NOT_IN_LFG_NOTICE") == nil then
		local locale = (GetLocale and GetLocale()) or "enUS"
		local text
		if locale == "ruRU" then
			text = "|Hchannel:%d|h[%s]|h Чтобы присоединиться к этому каналу, нужно стоять в очереди поиска группы."
		else
			text = "|Hchannel:%d|h[%s]|h You must be queued for Looking For Group to join this channel."
		end
		ChatGlobalSet("CHAT_NOT_IN_LFG_NOTICE", text)
	end
end

local channelNoticeHandlerHooked = false
local channelNoticeFiltersHooked = false

local function ChannelNoticeEnsureFilter(self, event, arg1, ...)
	-- Runs inside ChatFrame_MessageEventHandler before format(getglobal(...)).
	if event == "CHAT_MSG_BN_CONVERSATION_NOTICE" then
		EnsureChatNoticeGlobal(arg1, "CHAT_CONVERSATION_", CONVERSATION_NOTICE_FALLBACK)
	else
		EnsureChatNoticeGlobal(arg1, "CHAT_", CHANNEL_NOTICE_FALLBACK)
	end
	return false
end

local function InstallChannelNoticeGlobalStringGuard()
	SeedKnownMissingChannelNotices()

	if not channelNoticeFiltersHooked and type(ChatFrame_AddMessageEventFilter) == "function" then
		channelNoticeFiltersHooked = true
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", ChannelNoticeEnsureFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE_USER", ChannelNoticeEnsureFilter)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_CONVERSATION_NOTICE", ChannelNoticeEnsureFilter)
	end

	-- Outer guard: covers clients/addons where filters are skipped or installed late.
	if not channelNoticeHandlerHooked then
		local orig = _G.ChatFrame_MessageEventHandler
		if type(orig) == "function" then
			channelNoticeHandlerHooked = true
			_G.ChatFrame_MessageEventHandler = function(self, event, ...)
				if event == "CHAT_MSG_CHANNEL_NOTICE" or event == "CHAT_MSG_CHANNEL_NOTICE_USER" then
					local arg1 = ...
					EnsureChatNoticeGlobal(arg1, "CHAT_", CHANNEL_NOTICE_FALLBACK)
				elseif event == "CHAT_MSG_BN_CONVERSATION_NOTICE" then
					local arg1 = ...
					EnsureChatNoticeGlobal(arg1, "CHAT_CONVERSATION_", CONVERSATION_NOTICE_FALLBACK)
				end
				return orig(self, event, ...)
			end
		end
	end
end

InstallChannelNoticeGlobalStringGuard()
_G.SarychUI_InstallChannelNoticeGlobalStringGuard = InstallChannelNoticeGlobalStringGuard


-- Recall the last submitted chat message through SUI's binding owner.
local historyModule = SarychUI:GetModule("chat")
local historyEnabled, historyHooked = false, false
local lastHistoryText, lastHistoryFrame
local function CaptureChatHistory(box)
    if not historyEnabled then return end
    local text = box:GetText()
    if not text or not text:find("%S") then return end
    local kind = box:GetAttribute("chatType")
    local prefix = _G["SLASH_" .. tostring(kind) .. "1"] or ""
    if kind == "CHANNEL" then
        prefix = "/" .. tostring(box:GetAttribute("channelTarget"))
    elseif kind == "WHISPER" then
        prefix = prefix .. " " .. tostring(box:GetAttribute("tellTarget"))
    end
    lastHistoryText = prefix .. " " .. text
    lastHistoryFrame = box.chatFrame or box:GetParent()
end
local function RecallChatHistory()
    if historyEnabled and lastHistoryText then
        ChatFrame_OpenChat(lastHistoryText, lastHistoryFrame)
    end
end
function historyModule:DisableShiftHistory()
    historyEnabled = false
    lastHistoryText, lastHistoryFrame = nil, nil
    SarychUI.ToggleBindings:RemoveAction("chat.shiftHistory")
end
function historyModule:ApplyShiftHistorySettings()
    local db = SarychUI:GetModuleProfile("chat")
    if not db or not db.enabled or not db.shiftHistoryEnabled then self:DisableShiftHistory(); return end
    historyEnabled = true
    if not historyHooked then
        historyHooked = true
        hooksecurefunc("ChatEdit_AddHistory", CaptureChatHistory)
    end
    SarychUI.ToggleBindings:SetAction("chat.shiftHistory", "SHIFT-UP", RecallChatHistory)
end
