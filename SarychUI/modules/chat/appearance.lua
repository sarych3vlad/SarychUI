-- SarychUI Chat Module - Appearance Features
-- Функции для вкладки "Внешний вид" в настройках

local match = string.match

local function SafeForLimit(value, fallback)
	local n = tonumber(value)
	if not n then
		return fallback or 0
	end
	if n < 0 then
		return 0
	end
	return n
end

-- Доступ к сохранённым настройкам (привязано к базе SarychUI)
local function sarChat_GetSetting(key, default)
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db then return default end
    return db[key] or default
end

-- Экспортируем функцию для использования в модуле
_G.sarChat_GetSetting = sarChat_GetSetting

-- ========================================
-- ПОЗИЦИОНИРОВАНИЕ ТУЛТИПА (EXACT COPY FROM sarChat)
-- ========================================

-- Переменные для хранения оригинальной позиции тултипа
local defPoint, defRelTo, defRelPoint, defX, defY
local initialized = false

-- Функция для расчета динамического смещения (EXACT COPY)
local function GetDynamicYOffset()
    -- Проверяем, включена ли настройка позиционирования тултипа
    if sarChat_GetSetting and sarChat_GetSetting("tooltipPositionEnabled", 1) ~= 1 then
        return 0  -- Если отключено, не смещаем
    end
    
    local baseOffset = (sarChat_GetSetting and tonumber(sarChat_GetSetting("tooltipBaseOffset", 20))) or 20
    -- Проверяем наличие питомца в Classic WoW
    if PetActionBarFrame and PetActionBarFrame:IsVisible() then
        local petOffset = (sarChat_GetSetting and tonumber(sarChat_GetSetting("tooltipPetOffset", 60))) or 60
        return petOffset
    end
    return baseOffset
end

-- Функция для обновления позиции тултипа (EXACT COPY)
local function UpdateTooltipPosition()
    if initialized and ItemRefTooltip:IsVisible() then
        local dynamicOffset = GetDynamicYOffset()
        ItemRefTooltip:ClearAllPoints()
        ItemRefTooltip:SetPoint(defPoint, defRelTo, defRelPoint, defX, defY + dynamicOffset)
    end
end

-- Инициализация позиционирования тултипа (EXACT COPY)
local tooltipPositioningInitialized = false

local function InitializeTooltipPositioning()
    if not ItemRefTooltip then return end
    -- HookScript cannot be undone, and this runs on every settings Apply, so
    -- without this guard each Apply added another copy of every handler below.
    if tooltipPositioningInitialized then return end
    tooltipPositioningInitialized = true
    
    -- Хук для OnShow (EXACT COPY)
    ItemRefTooltip:HookScript("OnShow", function(self)
        if not initialized then
            local p, r, rp, x, y = self:GetPoint(1)
            if not p then p, r, rp, x, y = "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0 end

            defPoint, defRelTo, defRelPoint = p, r, rp
            defX, defY = x or 0, y or 0
            
            initialized = true
        end
        
        -- Применяем динамическое смещение при показе
        local dynamicOffset = GetDynamicYOffset()
        self:ClearAllPoints()
        self:SetPoint(defPoint, defRelTo, defRelPoint, defX, defY + dynamicOffset)
        self:SetUserPlaced(false)
    end)

    -- Хук для OnHide (EXACT COPY)
    ItemRefTooltip:HookScript("OnHide", function(self)
        if initialized then
            self:SetUserPlaced(false)
            self:ClearAllPoints()
            self:SetPoint(defPoint, defRelTo, defRelPoint, defX, defY)
        end
    end)

    -- Создаем фрейм для отслеживания событий PetActionBarFrame (EXACT COPY)
    local petBarTracker = CreateFrame("Frame")
    petBarTracker:RegisterEvent("PET_ATTACK_START")
    petBarTracker:RegisterEvent("PET_ATTACK_STOP") 
    petBarTracker:RegisterEvent("PET_BAR_UPDATE")
    petBarTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
    petBarTracker:RegisterEvent("PLAYER_LEAVING_WORLD")
    petBarTracker:RegisterEvent("PET_BAR_SHOW")
    petBarTracker:RegisterEvent("PET_BAR_HIDE")
    petBarTracker:RegisterEvent("UNIT_PET")
    petBarTracker:RegisterEvent("PET_DISMISS_START")
    petBarTracker:RegisterEvent("PET_DISMISS_STOP")

    -- Хук для отслеживания скрытия/показа PetActionBarFrame (EXACT COPY)
    if PetActionBarFrame then
        PetActionBarFrame:HookScript("OnShow", function()
            if ItemRefTooltip:IsVisible() then
                UpdateTooltipPosition()
            end
        end)
        
        PetActionBarFrame:HookScript("OnHide", function()
            if ItemRefTooltip:IsVisible() then
                UpdateTooltipPosition()
            end
        end)
    end

    petBarTracker:SetScript("OnEvent", function(self, event, ...)
        -- Обновляем позицию тултипа при изменении состояния PetActionBarFrame
        if ItemRefTooltip:IsVisible() then
            UpdateTooltipPosition()
        end
    end)

    -- Дополнительная проверка каждые 0.5 секунды для надежности (EXACT COPY)
    local lastPetBarState = nil
    petBarTracker:SetScript("OnUpdate", function(self, elapsed)
        if ItemRefTooltip:IsVisible() then
            local currentPetBarState = PetActionBarFrame and PetActionBarFrame:IsVisible()
            if currentPetBarState ~= lastPetBarState then
                UpdateTooltipPosition()
                lastPetBarState = currentPetBarState
            end
        end
    end)
end

-- Функция включения позиционирования тултипа
local function EnableTooltipPositioning()
    InitializeTooltipPositioning()
end

-- Функция отключения позиционирования тултипа
local function DisableTooltipPositioning()
    -- Восстанавливаем оригинальную позицию
    if initialized and ItemRefTooltip then
        ItemRefTooltip:ClearAllPoints()
        ItemRefTooltip:SetPoint(defPoint, defRelTo, defRelPoint, defX, defY)
    end
    
    -- Сбрасываем флаг инициализации для полного отключения
    initialized = false
end

-- Функция полного отключения позиционирования тултипа (для отключения модуля)
local function ForceDisableTooltipPositioning()
    -- Восстанавливаем оригинальную позицию
    if initialized and ItemRefTooltip then
        ItemRefTooltip:ClearAllPoints()
        ItemRefTooltip:SetPoint(defPoint, defRelTo, defRelPoint, defX, defY)
    end
    
    -- Сбрасываем флаг инициализации
    initialized = false
    
    -- ОТКЛЮЧАЕМ ВСЕ ХУКИ ДЛЯ ПОЗИЦИОНИРОВАНИЯ
    if ItemRefTooltip then
        ItemRefTooltip:SetScript("OnShow", nil)
        ItemRefTooltip:SetScript("OnHide", nil)
    end
    
    -- Отключаем хуки PetActionBarFrame
    if PetActionBarFrame then
        PetActionBarFrame:SetScript("OnShow", nil)
        PetActionBarFrame:SetScript("OnHide", nil)
    end
end

-- ========================================
-- ИКОНКИ В ТУЛТИПЕ (EXACT COPY FROM sarChat)
-- ========================================

-- Функция проверки включенности иконок (EXACT COPY)
local function sarChat_IconsEnabled()
    return (sarChat_GetSetting and sarChat_GetSetting("itemRefIconsEnabled", 1) == 1) or (not sarChat_GetSetting)
end

-- Инициализация иконок в тултипе (EXACT COPY)
local tooltipIconsInitialized = false

local function InitializeTooltipIcons()
    if not ItemRefTooltip then return end
    -- Guard against re-entry: this creates a frame and installs HookScripts, both
    -- of which leaked a fresh copy on every settings Apply.
    if tooltipIconsInitialized then return end
    tooltipIconsInitialized = true
    
    -- Создаем иконку (EXACT COPY)
    local icon = CreateFrame('Button', '$parentIcon', ItemRefTooltip)
    icon:SetSize(37, 37)
    icon:SetPoint("TOPRIGHT", ItemRefTooltip, "TOPLEFT", 0.5, -1.5)
    icon:Hide()
    icon.border = icon:CreateTexture(nil, 'OVERLAY')
    icon.border:SetTexture([[Interface\AchievementFrame\UI-Achievement-IconFrame]])
    icon.border:SetTexCoord(0, .5625, 0, .5625)
    icon.border:SetPoint("CENTER")
    icon.border:SetSize(icon:GetWidth() + 7.5, icon:GetHeight() + 7.5)
    icon.border:Hide()
    ItemRefTooltip.icon = icon

    -- Хук для предметов (EXACT COPY)
    ItemRefTooltip:HookScript('OnTooltipSetItem', function(self)
        if not sarChat_IconsEnabled() or not self.icon then
            if self.icon then self.icon:Hide() end
            if self.icon and self.icon.border then self.icon.border:Hide() end
            return
        end
        local link = select(2, self:GetItem())
        if not link then
            return
        end
        local icon = GetItemIcon(link)
        self.icon:SetNormalTexture(icon)
        self.icon:Show()
    end)

    -- Хук для заклинаний (EXACT COPY)
    ItemRefTooltip:HookScript('OnTooltipSetSpell', function(self)
        if not sarChat_IconsEnabled() or not self.icon then
            if self.icon then self.icon:Hide() end
            if self.icon and self.icon.border then self.icon.border:Hide() end
            return
        end
        local id = select(3, self:GetSpell())
        if not id then
            return
        end
        local icon = GetSpellTexture(id)
        self.icon:SetNormalTexture(icon)
        self.icon:Show()
    end)

    -- Хук для достижений (EXACT COPY)
    ItemRefTooltip:HookScript("OnTooltipSetAchievement", function(self, ...)
        if not sarChat_IconsEnabled() or not self.icon then
            if self.icon then self.icon:Hide() end
            if self.icon and self.icon.border then self.icon.border:Hide() end
            return
        end
        local link = ...  -- первый аргумент передается через varargs
        if not link then
            return
        end
        local id = link:match("achievement:(%d+)")
        if not id then
            return
        end
        local icon = select(10, GetAchievementInfo(id))
        if icon then
            self.icon:SetNormalTexture(icon)
            self.icon:Show()
            self.icon.border:Show()
        end
    end)

    -- Хук для очистки (EXACT COPY)
    ItemRefTooltip:HookScript('OnTooltipCleared', function(self)
        if self.icon then
            self.icon:Hide()
            if self.icon.border then
                self.icon.border:Hide()
            end
        end
    end)

    -- Хук для SetItemRef (EXACT COPY)
    hooksecurefunc("SetItemRef", function(link, text, button)
        if not sarChat_IconsEnabled() then
            return
        end
        local icon
        local type, id = match(link, "^([a-z]+):(%d+)")
        if (type == "spell" or type == "enchant") then
            icon = select(3, GetSpellInfo(id))
        elseif (type == "achievement") then
            icon = select(10, GetAchievementInfo(id))
            if icon then
                if ItemRefTooltip and ItemRefTooltip.icon then
                    ItemRefTooltip.icon:SetNormalTexture(icon)
                    ItemRefTooltip.icon:Show()
                    if ItemRefTooltip.icon.border then
                        ItemRefTooltip.icon.border:Show()
                    end
                end
            end
        end

        if (not icon) then
            ItemRefTooltipTexture10:Hide()

            ItemRefTooltipTextLeft1:ClearAllPoints()
            ItemRefTooltipTextLeft1:SetPoint("TOPLEFT", ItemRefTooltip, "TOPLEFT", 8, -10)

            ItemRefTooltipTextLeft2:ClearAllPoints()
            ItemRefTooltipTextLeft2:SetPoint("TOPLEFT", ItemRefTooltipTextLeft1, "BOTTOMLEFT", 0, -2)
            return
        end

        ItemRefTooltipTexture10:ClearAllPoints()
        ItemRefTooltipTexture10:SetPoint("TOPLEFT", ItemRefTooltip, "TOPLEFT", -36.5, -1.5)
        ItemRefTooltipTexture10:SetTexture(icon)
        ItemRefTooltipTexture10:SetHeight(37)
        ItemRefTooltipTexture10:SetWidth(37)
        ItemRefTooltipTexture10:Show()

        local textRight = ItemRefTooltipTextLeft1:GetRight()
        local closeLeft = ItemRefCloseButton:GetLeft()

        if (closeLeft <= textRight) then
            ItemRefTooltip:SetWidth(ItemRefTooltip:GetWidth() + (textRight - closeLeft))
        end
    end)
end

-- Функция включения иконок в тултипе
local function EnableTooltipIcons()
    InitializeTooltipIcons()
end

-- Функция отключения иконок в тултипе
local function DisableTooltipIcons()
    -- Скрываем иконку если она есть
    if ItemRefTooltip and ItemRefTooltip.icon then
        ItemRefTooltip.icon:Hide()
        if ItemRefTooltip.icon.border then
            ItemRefTooltip.icon.border:Hide()
        end
    end
    
    -- Скрываем текстуру ItemRefTooltipTexture10
    if ItemRefTooltipTexture10 then
        ItemRefTooltipTexture10:Hide()
    end
    
    -- Восстанавливаем оригинальные позиции текста
    if ItemRefTooltipTextLeft1 then
        ItemRefTooltipTextLeft1:ClearAllPoints()
        ItemRefTooltipTextLeft1:SetPoint("TOPLEFT", ItemRefTooltip, "TOPLEFT", 8, -10)
    end
    
    if ItemRefTooltipTextLeft2 then
        ItemRefTooltipTextLeft2:ClearAllPoints()
        ItemRefTooltipTextLeft2:SetPoint("TOPLEFT", ItemRefTooltipTextLeft1, "BOTTOMLEFT", 0, -2)
    end
    
    -- Принудительно скрываем все возможные иконки
    if ItemRefTooltip and ItemRefTooltip.icon then
        ItemRefTooltip.icon:Hide()
        if ItemRefTooltip.icon.border then
            ItemRefTooltip.icon.border:Hide()
        end
    end
    
    -- Скрываем текстуру ItemRefTooltipTexture10 еще раз для надежности
    if ItemRefTooltipTexture10 then
        ItemRefTooltipTexture10:Hide()
    end
end

-- Функция полного отключения иконок (для отключения модуля)
local function ForceDisableTooltipIcons()
    -- Скрываем все иконки
    if ItemRefTooltip then
        if ItemRefTooltip.icon then
            ItemRefTooltip.icon:Hide()
            if ItemRefTooltip.icon.border then
                ItemRefTooltip.icon.border:Hide()
            end
        end
        
        -- Скрываем текстуру ItemRefTooltipTexture10
        if ItemRefTooltipTexture10 then
            ItemRefTooltipTexture10:Hide()
        end
        
        -- Восстанавливаем оригинальные позиции текста
        if ItemRefTooltipTextLeft1 then
            ItemRefTooltipTextLeft1:ClearAllPoints()
            ItemRefTooltipTextLeft1:SetPoint("TOPLEFT", ItemRefTooltip, "TOPLEFT", 8, -10)
        end
        
        if ItemRefTooltipTextLeft2 then
            ItemRefTooltipTextLeft2:ClearAllPoints()
            ItemRefTooltipTextLeft2:SetPoint("TOPLEFT", ItemRefTooltipTextLeft1, "BOTTOMLEFT", 0, -2)
        end
        
        -- ОТКЛЮЧАЕМ ВСЕ ХУКИ - это ключевое изменение!
        -- Устанавливаем пустые обработчики для отключения функционала
        ItemRefTooltip:SetScript('OnTooltipSetItem', nil)
        ItemRefTooltip:SetScript('OnTooltipSetSpell', nil)
        ItemRefTooltip:SetScript('OnTooltipSetAchievement', nil)
        ItemRefTooltip:SetScript('OnTooltipCleared', nil)
    end
    
    -- Отключаем SetItemRef хук
    if _G.SetItemRef then
        -- Восстанавливаем оригинальную функцию SetItemRef
        -- Это сложно сделать безопасно, поэтому просто скрываем результат
    end
end

-- ========================================
-- СКРЫТИЕ КНОПКИ ДРУЗЕЙ (EXACT COPY FROM sarChat)
-- ========================================

-- Переменная для хранения фрейма счетчика друзей
local FriendsMicroButtonCount = nil

-- Функция обновления счетчика друзей (IMPROVED)
local function UpdateFriendsCount()
    if not FriendsMicroButtonCount then return end
    if not GetNumFriends or not GetFriendInfo then return end
    
    local totalFriends = GetNumFriends()
    local onlineFriends = 0
    
    -- Безопасный подсчет ТОЛЬКО друзей онлайн
    for i = 1, totalFriends do
        local success, name, level, class, area, connected, status, note, RAFInfo = pcall(GetFriendInfo, i)
        if success and connected and status ~= "Offline" and status ~= nil then 
            -- Дополнительная проверка: убеждаемся что друг действительно онлайн
            if name and name ~= "" then
                onlineFriends = onlineFriends + 1 
            end
        end
    end
    
    -- Обновляем отображение ТОЛЬКО если есть друзья онлайн
    if onlineFriends > 0 then
        FriendsMicroButtonCount.text:SetText(onlineFriends)
        FriendsMicroButtonCount:Show()
        -- Принудительно обновляем позицию
        FriendsMicroButtonCount.text:SetPoint("CENTER", MinimapCluster, "CENTER", 10, -47)
    else
        FriendsMicroButtonCount:Hide()
    end
end

-- Функция применения модификации кнопки друзей (EXACT COPY)
local function ApplyFriendsButtonMod(forceEnabled)
    local enabled
    if forceEnabled ~= nil then
        enabled = forceEnabled
    else
        local v = sarChat_GetSetting and sarChat_GetSetting("friendsButtonModEnabled", 1) or 1
        enabled = (tonumber(v) or 1) == 1
    end

    if enabled then
        if not FriendsMicroButtonCount then
            FriendsMicroButtonCount = CreateFrame("Frame", "FriendsMicroButtonCountFrame", UIParent)
            FriendsMicroButtonCount:SetSize(100, 30)
            FriendsMicroButtonCount.text = FriendsMicroButtonCount:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            FriendsMicroButtonCount.text:SetPoint("CENTER", MinimapCluster, "CENTER", 10, -47)
            FriendsMicroButtonCount.text:SetText("")
            -- Регистрируем все возможные события
            FriendsMicroButtonCount:RegisterEvent("FRIENDLIST_UPDATE")
            FriendsMicroButtonCount:RegisterEvent("PLAYER_ENTERING_WORLD")
            FriendsMicroButtonCount:RegisterEvent("PLAYER_LEAVING_WORLD")
            FriendsMicroButtonCount:RegisterEvent("FRIEND_OFFLINE")
            FriendsMicroButtonCount:RegisterEvent("FRIEND_ONLINE")
            FriendsMicroButtonCount:RegisterEvent("CHAT_MSG_SYSTEM")
            FriendsMicroButtonCount:RegisterEvent("PLAYER_LOGIN")
            FriendsMicroButtonCount:RegisterEvent("PLAYER_LOGOUT")
            FriendsMicroButtonCount:RegisterEvent("UPDATE_FRIEND_LIST")
            FriendsMicroButtonCount:RegisterEvent("FRIENDLIST_SHOW")
            FriendsMicroButtonCount:RegisterEvent("FRIENDLIST_CLOSED")
            FriendsMicroButtonCount:RegisterEvent("SOCIAL_QUEUE_UPDATE")
            FriendsMicroButtonCount:RegisterEvent("GROUP_ROSTER_UPDATE")
            FriendsMicroButtonCount:RegisterEvent("RAID_ROSTER_UPDATE")
            FriendsMicroButtonCount:RegisterEvent("PARTY_MEMBERS_CHANGED")
            
            FriendsMicroButtonCount:SetScript("OnEvent", function(self, event, ...)
                -- Обновляем при любом событии
                C_Timer.After(0.1, function()
                    UpdateFriendsCount()
                end)
            end)
        end
        -- Принудительное обновление при включении
        UpdateFriendsCount()
        -- Дополнительное обновление через небольшую задержку
        C_Timer.After(0.5, function()
            UpdateFriendsCount()
        end)
        if FriendsMicroButton then FriendsMicroButton:Hide() end
    else
        if FriendsMicroButtonCount then
            FriendsMicroButtonCount:UnregisterAllEvents()
            FriendsMicroButtonCount:Hide()
        end
        if FriendsMicroButton then FriendsMicroButton:Show() end
    end
end

-- Функция включения скрытия кнопки друзей
local function EnableFriendsButtonHiding()
    ApplyFriendsButtonMod(true)
end

-- Функция отключения скрытия кнопки друзей
local function DisableFriendsButtonHiding()
    ApplyFriendsButtonMod(false)
end

-- Функция полного отключения скрытия кнопки друзей (для отключения модуля)
local function ForceDisableFriendsButtonHiding()
    -- Принудительно восстанавливаем оригинальную кнопку друзей
    if FriendsMicroButtonCount then
        FriendsMicroButtonCount:UnregisterAllEvents()
        FriendsMicroButtonCount:Hide()
    end
    if FriendsMicroButton then 
        FriendsMicroButton:Show() 
    end
end


-- ========================================
-- ЗАТУХАНИЕ ЧАТА (EXACT COPY FROM sarChat)
-- ========================================

-- Функция инициализации затухания чата (EXACT COPY)
local function InitializeChatFading()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            frame:SetFading(true)
            local enabled = true
            if sarChat_GetSetting then
                enabled = sarChat_GetSetting("visibleSecondsEnabled", 1) == 1
            end
            if enabled then
                local visibleSeconds = sarChat_GetSetting and sarChat_GetSetting("visibleSeconds", 12) or 12
                if type(visibleSeconds) ~= "number" then visibleSeconds = 12 end
                frame:SetTimeVisible(visibleSeconds)
            else
                -- При отключенной опции возвращаем долгое время видимости
                frame:SetTimeVisible(120)
            end
        end
    end
end

-- Функция включения затухания чата
local function EnableChatFading()
    InitializeChatFading()
end

-- Функция отключения затухания чата
local function DisableChatFading()
    -- Восстанавливаем долгое время видимости для всех фреймов чата
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            frame:SetTimeVisible(120)
        end
    end
end

-- ========================================
-- СКРЫТИЕ СТРЕЛКИ ПЕРЕМЕЩЕНИЯ В КОНЕЦ (EXACT COPY FROM sarChat)
-- ========================================

-- ========================================
-- КЛОН КНОПКИ "В КОНЕЦ" (кастомное место) + РЕАЛЬНОЕ ВОССТАНОВЛЕНИЕ
-- (WotLK 3.3.5, 1-в-1 по визуалу и таймингам мигания)
-- ========================================

-- Текстуры под ваш билд (из FloatingChatFrame.xml)
local TEX_UP       = "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up"
local TEX_DOWN     = "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Down"
local TEX_DISABLED = "Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled"
local TEX_HL       = "Interface\\Buttons\\UI-Common-MouseHilight"
local TEX_GLOW     = "Interface\\ChatFrame\\UI-ChatIcon-BlinkHilight"

-- Внешний вид/позиция клона (меняй под себя)
local BUTTON_SIZE   = 32     -- размер 1-в-1 с оригиналом
local BUTTON_ALPHA  = 0.6    -- прозрачность самого значка (glow отдельно и не тускнеет)
local ANCHOR_POINT  = "BOTTOMRIGHT" -- точка якоря в ChatFrame
local OFFSET_X      = 0
local OFFSET_Y      = 0

-- Настройка (берём из твоей системы, по умолчанию ВКЛ)
local function BB_GetSetting(key, default)
    if type(sarChat_GetSetting) == "function" then
        local ok, val = pcall(sarChat_GetSetting, key, default)
        if ok and val ~= nil then return val end
    end
    return default
end
local function BB_Enabled()
    return tonumber(BB_GetSetting("hideChatBottomButtonEnabled", 1)) == 1
end

-- Утилиты
local function BB_GetOriginalBottomButton(frame)
    return frame and frame.buttonFrame and frame.buttonFrame.bottomButton or nil
end
local function BB_ScrollToBottom(frame)
    if frame and type(frame.ScrollToBottom) == "function" then
        frame:ScrollToBottom()
    elseif type(FCF_ScrollToBottom) == "function" then
        FCF_ScrollToBottom(frame)
    end
end

-- Оригинал: «якорь» — не двигаем контейнер, только глушим визуал и мышь
local function BB_MaskOriginal(orig)
    if not orig or orig._bbMasked then return end
    orig._bbMasked = true
    -- сохранить параметры для восстановления
    orig._bbSaveAlpha = orig:GetAlpha()
    orig._bbSaveMouse = orig:IsMouseEnabled()

    if orig.EnableMouse then orig:EnableMouse(false) end
    if orig.SetAlpha  then orig:SetAlpha(0) end

    -- спрятать его flash-слой (отдельная текстура вне альфы кнопки)
    local flash = _G[orig:GetName() and (orig:GetName().."Flash") or ""]
    if flash and flash.Hide then flash:Hide() end

    -- если оригинал попытаются показать — снова глушим визуал
    if orig.HookScript and not orig._bbShowHook then
        orig._bbShowHook = true
        orig:HookScript("OnShow", function(self)
            if self.EnableMouse then self:EnableMouse(false) end
            if self.SetAlpha  then self:SetAlpha(0) end
            local f2 = _G[self:GetName() and (self:GetName().."Flash") or ""]
            if f2 and f2.Hide then f2:Hide() end
        end)
    end
end

local function BB_UnmaskOriginal(orig)
    if not orig then return end
    if orig.EnableMouse then orig:EnableMouse(orig._bbSaveMouse ~= false) end
    if orig.SetAlpha  then orig:SetAlpha(orig._bbSaveAlpha or 1) end
    -- вернуть flash: Blizzard сам управляет показом/скрытием по состоянию скролла,
    -- но если он был скрыт нами, просто позволим ему снова показываться
    orig._bbMasked, orig._bbSaveAlpha, orig._bbSaveMouse = nil, nil, nil
end

-- Оверлей-хост внутри конкретного ChatFrame (сюда ставим клон)
local function BB_GetOrCreateHost(frame)
    if frame._bbHost and frame._bbHost:IsObjectType("Frame") then return frame._bbHost end
    local host = CreateFrame("Frame", nil, frame)
    host:SetAllPoints(frame)
    host:SetFrameLevel(frame:GetFrameLevel() + 20)
    host:EnableMouse(false)
    frame._bbHost = host

    if not frame._bbSizeHook then
        frame._bbSizeHook = true
        frame:HookScript("OnSizeChanged", function(self)
            local h = self._bbHost; if h then h:SetAllPoints(self) end
        end)
    end
    if not frame._bbShowHook then
        frame._bbShowHook = true
        frame:HookScript("OnShow", function(self)
            local h = self._bbHost; if h then h:SetAllPoints(self) end
        end)
    end
    return host
end

-- Создаём клон: якорим к ХОСТУ (кастомное место), glow — отдельным верхним слоем
local function BB_CreateClone(frame)
    local host = BB_GetOrCreateHost(frame)
    local clone = CreateFrame("Button", nil, host)
    clone:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    clone:SetPoint(ANCHOR_POINT, host, ANCHOR_POINT, OFFSET_X, OFFSET_Y)

    clone:SetNormalTexture(TEX_UP)
    clone:SetPushedTexture(TEX_DOWN)
    clone:SetDisabledTexture(TEX_DISABLED)
    clone:SetHighlightTexture(TEX_HL, "ADD")

    clone:SetAlpha(BUTTON_ALPHA)
    clone:RegisterForClicks("LeftButtonUp")
    clone:SetScript("OnClick", function(self)
        BB_ScrollToBottom(frame)
        if frame.AtBottom and frame:AtBottom() then self:Hide() else self:Show() end
    end)

    -- Отдельный верхний слой для glow, чтобы альфа кнопки его не тускнила
    local glowFrame = CreateFrame("Frame", nil, host)
    glowFrame:SetAllPoints(clone)
    glowFrame:SetFrameLevel(clone:GetFrameLevel() + 20)
    glowFrame:EnableMouse(false)

    local glow = glowFrame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(TEX_GLOW)
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(clone)
    glow:Hide()

    clone._bbGlowFrame = glowFrame
    clone.glow = glow
    clone._bbBlinkTimer = 0

    -- Мигание как у Blizzard: Show/Hide каждые CHAT_BUTTON_FLASH_TIME (0.5c по дефолту)
    clone:HookScript("OnHide", function(self)
        self._bbBlinkTimer = 0
        if self.glow then self.glow:Hide() end
    end)
    clone:HookScript("OnUpdate", function(self, elapsed)
        if not self:IsShown() then return end
        local atBottom = frame.AtBottom and frame:AtBottom()
        if atBottom then
            self._bbBlinkTimer = 0
            if self.glow then self.glow:Hide() end
            return
        end
        local t = (self._bbBlinkTimer or 0) + (elapsed or 0)
        local period = _G.CHAT_BUTTON_FLASH_TIME or 0.5
        if t >= period then
            t = t - period
            if self.glow then
                if self.glow:IsShown() then self.glow:Hide() else self.glow:Show() end
            end
        end
        self._bbBlinkTimer = t
    end)

    frame._bbClone = clone
    return clone
end

local function BB_GetOrCreateClone(frame)
    if frame._bbClone and frame._bbClone:IsObjectType("Button") then return frame._bbClone end
    return BB_CreateClone(frame)
end

-- Основная логика: показ клона/восстановление оригинала в реальном времени
local function BB_UpdateOne(frame)
    if not frame then return end
    
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or not db.enabled then
        return
    end
    
    local orig = BB_GetOriginalBottomButton(frame)
    if not orig then return end

    if not frame:IsShown() then
        if frame._bbClone then frame._bbClone:Hide() end
        return
    end

    if BB_Enabled() then
        -- скрыть визуал оригинала, но не двигать его (чтоб Up/Down/Menu не сдвинуло)
        BB_MaskOriginal(orig)

        local clone = BB_GetOrCreateClone(frame)
        if frame.AtBottom and frame:AtBottom() then
            clone:Hide()
            if clone.glow then clone.glow:Hide() end
        else
            clone:Show()
        end
    else
        -- выключено: спрятать клон и вернуть оригинал как было
        if frame._bbClone then
            if frame._bbClone.glow then frame._bbClone.glow:Hide() end
            frame._bbClone:Hide()
        end
        BB_UnmaskOriginal(orig)
    end
end

-- Применить ко всем ChatFrame
local function BB_ApplyAll()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or not db.enabled then
        return
    end
    
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame"..i]
        if f then
            -- навешиваем show-хук для пересчёта когда вкладка становится активной
            if f.HookScript and not f._bbVisHook then
                f._bbVisHook = true
                f:HookScript("OnShow", function(fr) BB_UpdateOne(fr) end)
            end
            -- создать хост и первично обновить
            BB_GetOrCreateHost(f)
            BB_UpdateOne(f)
        end
    end
end

-- Обновлять при прокрутке (смена AtBottom)
hooksecurefunc("FloatingChatFrame_OnMouseScroll", function(frame)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or not db.enabled then
        return
    end
    
    if frame then BB_UpdateOne(frame) end
end)

-- Инициализация/пересчёт при изменении окон
local BB_evt = CreateFrame("Frame")
BB_evt:RegisterEvent("PLAYER_LOGIN")
BB_evt:RegisterEvent("UPDATE_CHAT_WINDOWS")
BB_evt:SetScript("OnEvent", function()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or not db.enabled then
        return
    end
    
    BB_ApplyAll()
end)

-- Вызывай из сеттера опции, когда меняется галочка
_G.BB_ApplyBottomButtonSetting = BB_ApplyAll

-- ========================================
-- ChatFrameMenuButton: скрывать всегда, КРОМЕ активного EditBox (с фокусом)
-- Полное восстановление при отключении опции
-- ========================================

---------------------------
-- Настройка (ваша система)
---------------------------
local function FB_Enabled()
    if type(GetSetting) == "function" then
        local ok,v = pcall(GetSetting, "hideChatFrameButtonEnabled", 1)
        if ok then return v == 1 end
    end
    if type(sarChat_GetSetting) == "function" then
        local ok,v = pcall(sarChat_GetSetting, "hideChatFrameButtonEnabled", 1)
        if ok then return v == 1 end
    end
    return true
end

-- Настройка для Alt-режима: при зажатом Alt временно вернуть кнопку на дефолт
local function FB_AltModeEnabled()
    if type(GetSetting) == "function" then
        local ok, v = pcall(GetSetting, "chatFrameButtonAltDefaultEnabled", 1)
        if ok then return v == 1 end
    end
    if type(sarChat_GetSetting) == "function" then
        local ok, v = pcall(sarChat_GetSetting, "chatFrameButtonAltDefaultEnabled", 1)
        if ok then return v == 1 end
    end
    return true
end

---------------------------
-- Утилиты
---------------------------
local function FB_GetMenuButton()
    return _G.ChatFrameMenuButton
end

local function FB_IsActiveEditBox(eb)
    if not eb then return false end
    local aw = _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow() or nil
    if aw and aw == eb then return true end
    if eb.HasFocus and eb:HasFocus() then return true end
    return false
end

local function FB_SaveOriginalPoints(btn)
    if not btn or btn._fbOrigPoints then return end
    btn._fbOrigPoints = {}
    local n = SafeForLimit(btn:GetNumPoints(), 0)
    for i = 1, n do
        local p, rel, rp, x, y = btn:GetPoint(i)
        btn._fbOrigPoints[i] = { p, rel, rp, x, y }
    end
    btn._fbOrigStrata = btn:GetFrameStrata()
    btn._fbOrigLevel  = btn:GetFrameLevel()
    btn._fbOrigAlpha  = btn:GetAlpha()
    btn._fbOrigMouse  = btn:IsMouseEnabled()
end

local function FB_RestoreOriginalPoints(btn)
    if not btn or not btn._fbOrigPoints then return end
    btn:ClearAllPoints()
    for _, t in ipairs(btn._fbOrigPoints) do
        btn:SetPoint(t[1], t[2], t[3], t[4], t[5])
    end
    if btn.SetFrameStrata and btn._fbOrigStrata then btn:SetFrameStrata(btn._fbOrigStrata) end
    if btn.SetFrameLevel  and btn._fbOrigLevel  then btn:SetFrameLevel(btn._fbOrigLevel)     end
    if btn.SetAlpha       and btn._fbOrigAlpha  then btn:SetAlpha(btn._fbOrigAlpha)          end
    if btn.EnableMouse    and btn._fbOrigMouse ~= nil then btn:EnableMouse(btn._fbOrigMouse) end
end

local function FB_AnchorToEditBox(btn, eb)
    if not (btn and eb) then return end
    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", eb, "LEFT", 3, 0)                 -- рядом с EditBox
    btn:SetFrameStrata(eb:GetFrameStrata() or "HIGH")
    btn:SetFrameLevel((eb:GetFrameLevel() or 0) + 10)
end

local function FB_ShowNearEditBox(btn, eb)
    if not (btn and eb) then return end
    FB_SaveOriginalPoints(btn)
    FB_AnchorToEditBox(btn, eb)
    if btn.SetAlpha    then btn:SetAlpha(1) end
    if btn.EnableMouse then btn:EnableMouse(true) end
    if btn.Show        then btn:Show() end
end

local function FB_HideButton(btn)
    if btn and btn.Hide then btn:Hide() end
end

local function FB_RestoreDefault(btn)
    if not btn then return end
    FB_RestoreOriginalPoints(btn)
    if btn.SetAlpha    then btn:SetAlpha(btn._fbOrigAlpha or 1) end
    if btn.EnableMouse then btn:EnableMouse(btn._fbOrigMouse ~= false) end
    if btn.Show        then btn:Show() end
end

local function FB_AreScrollButtonsHidden()
    if type(GetSetting) == "function" then
        local ok, v = pcall(GetSetting, "hideChatScrollButtonsEnabled", 1)
        if ok then return tonumber(v) == 1 end
    end
    if type(sarChat_GetSetting) == "function" then
        local ok, v = pcall(sarChat_GetSetting, "hideChatScrollButtonsEnabled", 1)
        if ok then return tonumber(v) == 1 end
    end
    return false
end

-- FloatingChatFrame.xml: bottomButton -> BOTTOM, buttonFrame BOTTOM, (0, -7)
local function FB_AnchorMenuToBottomSlot(btn)
    local frame = _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
    local bf = frame and (frame.buttonFrame or _G.ChatFrame1ButtonFrame)
    local bottom = bf and (bf.bottomButton or _G.ChatFrame1ButtonFrameBottomButton)
    if not bf then
        return
    end

    btn:ClearAllPoints()
    if bottom and bottom.GetPoint then
        local p, rel, rp, x, y = bottom:GetPoint(1)
        if p and rel then
            btn:SetPoint(p, rel, rp or "BOTTOM", x or 0, y or -7)
            return
        end
    end
    btn:SetPoint("BOTTOM", bf, "BOTTOM", 0, -7)
end

local function FB_ShowMenuForAlt(btn)
    if not btn then return end
    FB_SaveOriginalPoints(btn)
    if FB_AreScrollButtonsHidden() then
        FB_AnchorMenuToBottomSlot(btn)
    else
        FB_RestoreOriginalPoints(btn)
    end
    if btn.SetAlpha    then btn:SetAlpha(btn._fbOrigAlpha or 1) end
    if btn.EnableMouse then btn:EnableMouse(btn._fbOrigMouse ~= false) end
    if btn.Show        then btn:Show() end
    if _G.ChatFrameMenu_UpdateAnchorPoint then
        _G.ChatFrameMenu_UpdateAnchorPoint()
    end
end

---------------------------
-- Хуки EditBox (только фокус)
---------------------------
local function FB_HookEditBox(eb)
    if not eb or eb._fbHooked then return end
    eb._fbHooked = true
    if eb.HookScript then
        eb:HookScript("OnEditFocusGained", function(self)
            if not FB_Enabled() then return end
            local btn = FB_GetMenuButton()
            if btn and FB_IsActiveEditBox(self) then
                FB_ShowNearEditBox(btn, self)
            end
        end)
        eb:HookScript("OnEditFocusLost", function(self)
            if not FB_Enabled() then return end
            local btn = FB_GetMenuButton()
            if not btn then return end
            local aw = _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow() or nil
            if aw then
                FB_ShowNearEditBox(btn, aw) -- фокус ушёл в другой EditBox
            else
                FB_HideButton(btn)          -- фокуса нет нигде
            end
        end)
        -- OnShow/OnHide не используем, чтобы не ловить ложные появления без фокуса
    end
end

---------------------------
-- Ресинхронизация состояния
---------------------------
local function FB_Resync()
    local btn = FB_GetMenuButton(); if not btn then return end
    -- Во время Alt-override только показываем кнопку (позиция задаётся стеком ButtonFrame)
    if _G.FB_AltOverride then
        FB_ShowMenuForAlt(btn)
        return
    end
    -- модуль отключён? вернём дефолт
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or not db.enabled then FB_RestoreDefault(btn); return end

    if not FB_Enabled() then
        FB_RestoreDefault(btn)
        return
    end

    local aw = _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow() or nil
    if aw and FB_IsActiveEditBox(aw) then
        FB_ShowNearEditBox(btn, aw)
    else
        FB_HideButton(btn)
    end
end

---------------------------
-- Alt Mode интеграция (универсальная система SarychUI.AltMode)
---------------------------
local FB_AltRegistered = false
_G.FB_AltOverride = false

local function FB_OnAltChanged(isAltPressed)
    if not FB_AltModeEnabled() then return end
    -- Модуль активен?
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not (db and db.enabled) then return end

    local btn = FB_GetMenuButton(); if not btn then return end
    
    if isAltPressed then
        _G.FB_AltOverride = true
        FB_ShowMenuForAlt(btn)
    else
        _G.FB_AltOverride = false
        if btn._fbOrigPoints then
            FB_RestoreOriginalPoints(btn)
        end
        FB_Resync()
    end
end

local function FB_RegisterAltCallback()
    if SarychUI and SarychUI.AltMode and not FB_AltRegistered then
        SarychUI.AltMode:RegisterCallback("chat_menu_button", FB_OnAltChanged)
        FB_AltRegistered = true
        -- Синхронизируем текущее состояние сразу после регистрации
        local isAlt = SarychUI.AltMode:IsAltPressed()
        FB_OnAltChanged(isAlt)
    end
end

local function FB_UnregisterAltCallback()
    if SarychUI and SarychUI.AltMode and FB_AltRegistered then
        SarychUI.AltMode:UnregisterCallback("chat_menu_button")
        FB_AltRegistered = false
        -- При снятии регистрации вернём обычное поведение
        FB_Resync()
    end
end

-- Вспомогательная функция для ручной синхронизации, если нужно из модуля
local function FB_SyncAltNow()
    if SarychUI and SarychUI.AltMode then
        FB_OnAltChanged(SarychUI.AltMode:IsAltPressed())
    else
        FB_Resync()
    end
end

---------------------------
-- Применение
---------------------------
local function FB_ApplyForFrame(frame)
    if not frame then return end
    local btn = FB_GetMenuButton(); if not btn then return end
    local eb = frame.editBox or _G[frame:GetName().."EditBox"]
    FB_HookEditBox(eb)
    FB_Resync()
end

local function FB_ApplyAll()
    local btn = FB_GetMenuButton(); if not btn then return end
    FB_SaveOriginalPoints(btn)

    -- хукнем все EditBox
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame"..i]
        if f then
            local eb = f.editBox or _G["ChatFrame"..i.."EditBox"]
            FB_HookEditBox(eb)
        end
    end

    FB_Resync()
end

---------------------------
-- Системные/пользовательские события
---------------------------
local FB_evt = CreateFrame("Frame")
FB_evt:RegisterEvent("PLAYER_LOGIN")
FB_evt:RegisterEvent("UPDATE_CHAT_WINDOWS")
FB_evt:SetScript("OnEvent", function() FB_ApplyAll() end)

-- Фокус чата
hooksecurefunc("ChatEdit_ActivateChat",   function(eb) FB_Resync() end)
hooksecurefunc("ChatEdit_DeactivateChat", function(eb) FB_Resync() end)

-- Переключение вкладок и управление окнами чата
if type(FCFTab_OnClick)=="function" then
    hooksecurefunc("FCFTab_OnClick", function() FB_Resync() end)
end
if type(FCFDock_UpdateTabs)=="function" then
    hooksecurefunc("FCFDock_UpdateTabs", function() FB_Resync() end)
end
if type(FCF_OpenTemporaryWindow)=="function" then
    hooksecurefunc("FCF_OpenTemporaryWindow", function() FB_Resync() end)
end
if type(FCF_Close)=="function" then
    hooksecurefunc("FCF_Close", function() FB_Resync() end)
end

---------------------------
-- Публичные функции для твоего модуля
---------------------------
function FB_ApplyChatFrameButtonSetting()  FB_ApplyAll() end

function FB_RestoreToDefaultNow()
    local btn = FB_GetMenuButton()
    if btn then FB_RestoreDefault(btn) end
end

function EnableChatFrameButtonHiding()
    FB_ApplyAll()
end

function DisableChatFrameButtonHiding()
    FB_ApplyAll()
    local btn = FB_GetMenuButton()
    if btn then FB_RestoreDefault(btn) end
end

function ApplyChatFrameButtonMod(forceEnabled)
    if forceEnabled == nil then FB_ApplyAll(); return end
    if forceEnabled then
        FB_ApplyAll()
    else
        local btn = FB_GetMenuButton()
        if btn then FB_RestoreDefault(btn) end
    end
end

function ForceDisableChatFrameButtonHiding()
    local btn = FB_GetMenuButton()
    if btn then FB_RestoreDefault(btn) end
end

-- Auto-register Alt callback on login
local function AutoRegisterAltCallback()
    if SarychUI and SarychUI.AltMode then
        FB_RegisterAltCallback()
    else
        -- Retry after a short delay if AltMode isn't ready yet
        C_Timer.After(1, function()
            if SarychUI and SarychUI.AltMode then
                FB_RegisterAltCallback()
            end
        end)
    end
end

-- Register on login
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    AutoRegisterAltCallback()
end)

-- Экспорт AltMode-обработчиков (регистрировать в Enable(), снимать в Disable())
_G.FB_RegisterAltCallback = FB_RegisterAltCallback
_G.FB_UnregisterAltCallback = FB_UnregisterAltCallback
_G.FB_SyncAltNow = FB_SyncAltNow

-- ========================================
-- СКРЫТИЕ СТРЕЛОК ВВЕРХ И ВНИЗ (real-time, all chat tabs)
-- ========================================

-- Безопасно читаем вашу настройку (поддерживает GetSetting/sarChat_GetSetting)
local function SB_GetSetting(key, default)
    if type(GetSetting) == "function" then
        local ok,v = pcall(GetSetting, key, default); if ok and v ~= nil then return v end
    end
    if type(sarChat_GetSetting) == "function" then
        local ok,v = pcall(sarChat_GetSetting, key, default); if ok and v ~= nil then return v end
    end
    return default
end
local function SB_Enabled()
    return tonumber(SB_GetSetting("hideChatScrollButtonsEnabled", 1)) == 1
end

-- Достаём ссылки на Up/Down для данного ChatFrame
local function SB_GetUpDown(frame, idx)
    local bf = frame and frame.buttonFrame
    local up   = bf and bf.upButton   or _G["ChatFrame"..idx.."ButtonFrameUpButton"]
    local down = bf and bf.downButton or _G["ChatFrame"..idx.."ButtonFrameDownButton"]
    return up, down
end

-- Один раз навешиваем хук и управляем скрытием/восстановлением по флагу _sbForceHidden
local function SB_EnsureHook(btn)
    if not btn or btn._sbHooked or not btn.HookScript then return end
    btn._sbHooked = true
    -- Сохраним исходные параметры для восстановления
    btn._sbOrigAlpha = btn:GetAlpha()
    btn._sbOrigMouse = btn:IsMouseEnabled()
    btn:HookScript("OnShow", function(self)
        if self._sbForceHidden then
            if self.Hide then self:Hide() end
            if self.SetAlpha then self:SetAlpha(0) end
            if self.EnableMouse then self:EnableMouse(false) end
        end
    end)
end

local function SB_ApplyMask(btn, enable)
    if not btn then return end
    SB_EnsureHook(btn)
    btn._sbForceHidden = enable and true or false
    if enable then
        if btn.Hide then btn:Hide() end
        if btn.SetAlpha then btn:SetAlpha(0) end
        if btn.EnableMouse then btn:EnableMouse(false) end
    else
        -- восстановление «в живом времени»
        if btn.SetAlpha then btn:SetAlpha(btn._sbOrigAlpha or 1) end
        if btn.EnableMouse then btn:EnableMouse(btn._sbOrigMouse ~= false) end
        if btn.Show then btn:Show() end
    end
end

local function SB_ApplyForFrame(frame, idx)
    if not frame then return end
    
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or not db.enabled then
        return
    end
    
    local up, down = SB_GetUpDown(frame, idx)
    local enable = SB_Enabled()
    SB_ApplyMask(up, enable)
    SB_ApplyMask(down, enable)
end

local function SB_ApplyAll()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or not db.enabled then
        return
    end
    
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame"..i]
        if f then SB_ApplyForFrame(f, i) end
    end
end

-- При логине/обновлении окон — применяем
local SB_evt = CreateFrame("Frame")
SB_evt:RegisterEvent("PLAYER_LOGIN")
SB_evt:RegisterEvent("UPDATE_CHAT_WINDOWS")
SB_evt:SetScript("OnEvent", function()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or not db.enabled then
        return
    end
    
    SB_ApplyAll()
end)

-- Вызывайте это из вашего сеттера (ApplyAllSettings уже делает вызов)
_G.SB_ApplyScrollButtonsSetting = SB_ApplyAll

-- ========================================
-- ФУНКЦИИ ДЛЯ МОДУЛЯ (согласно правилам)
-- ========================================

-- Объявлены ниже, но используются функциями включения/отключения
local ApplyBottomButtonMod, ApplyScrollButtonsMod

-- Функция включения скрытия стрелки перемещения в конец
local function EnableBottomButtonHiding()
    ApplyBottomButtonMod(true)
end

-- Функция отключения скрытия стрелки перемещения в конец
local function DisableBottomButtonHiding()
    ApplyBottomButtonMod(false)
    
    -- ПРИНУДИТЕЛЬНОЕ ВОССТАНОВЛЕНИЕ при отключении (как у кнопки друзей)
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame"..i]
        if f then
            local orig = BB_GetOriginalBottomButton(f)
            if orig then
                BB_UnmaskOriginal(orig)
                -- ПРИНУДИТЕЛЬНО ПОКАЗЫВАЕМ оригинальную кнопку
                if orig.Show then orig:Show() end
                if orig.SetAlpha then orig:SetAlpha(1) end
                if orig.EnableMouse then orig:EnableMouse(true) end
            end
            
            -- Скрываем клон если есть
            if f._bbClone then
                if f._bbClone.glow then f._bbClone.glow:Hide() end
                f._bbClone:Hide()
            end
        end
    end
end

-- Функция применения модификации стрелки перемещения в конец (как у кнопки друзей)
function ApplyBottomButtonMod(forceEnabled)
    if forceEnabled ~= nil then
        -- Принудительно включаем или отключаем
        if forceEnabled then
            BB_ApplyAll()
        else
            -- Принудительно восстанавливаем все оригинальные кнопки
            for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
                local f = _G["ChatFrame"..i]
                if f then
                    local orig = BB_GetOriginalBottomButton(f)
                    if orig then
                        BB_UnmaskOriginal(orig)
                        if orig.Show then orig:Show() end
                    end
                    
                    -- Скрываем клон если есть
                    if f._bbClone then
                        if f._bbClone.glow then f._bbClone.glow:Hide() end
                        f._bbClone:Hide()
                    end
                end
            end
        end
    else
        BB_ApplyAll()
    end
end

-- Функция полного отключения скрытия стрелки (для отключения модуля)
local function ForceDisableBottomButtonHiding()
    -- Принудительно восстанавливаем все оригинальные кнопки
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame"..i]
        if f then
            local orig = BB_GetOriginalBottomButton(f)
            if orig then
                BB_UnmaskOriginal(orig)
                -- ПРИНУДИТЕЛЬНО ПОКАЗЫВАЕМ оригинальную кнопку
                if orig.Show then orig:Show() end
                if orig.SetAlpha then orig:SetAlpha(1) end
                if orig.EnableMouse then orig:EnableMouse(true) end
            end
            
            -- Скрываем клон если есть
            if f._bbClone then
                if f._bbClone.glow then f._bbClone.glow:Hide() end
                f._bbClone:Hide()
            end
        end
    end
end

-- Функция включения скрытия стрелок вверх и вниз
local function EnableScrollButtonsHiding()
    ApplyScrollButtonsMod(true)
end

-- Функция отключения скрытия стрелок вверх и вниз
local function DisableScrollButtonsHiding()
    ApplyScrollButtonsMod(false)
    
    -- ПРИНУДИТЕЛЬНОЕ ВОССТАНОВЛЕНИЕ при отключении (как у кнопки друзей)
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame"..i]
        if f then
            local up, down = SB_GetUpDown(f, i)
            if up then
                up._sbForceHidden = false
                -- ПРИНУДИТЕЛЬНО ПОКАЗЫВАЕМ стрелку вверх
                if up.SetAlpha then up:SetAlpha(1) end
                if up.EnableMouse then up:EnableMouse(true) end
                if up.Show then up:Show() end
            end
            if down then
                down._sbForceHidden = false
                -- ПРИНУДИТЕЛЬНО ПОКАЗЫВАЕМ стрелку вниз
                if down.SetAlpha then down:SetAlpha(1) end
                if down.EnableMouse then down:EnableMouse(true) end
                if down.Show then down:Show() end
            end
        end
    end
end

-- Функция применения модификации стрелок вверх и вниз (как у кнопки друзей)
function ApplyScrollButtonsMod(forceEnabled)
    if forceEnabled ~= nil then
        -- Принудительно включаем или отключаем
        if forceEnabled then
            SB_ApplyAll()
        else
            -- Принудительно восстанавливаем все стрелки вверх и вниз
            for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
                local f = _G["ChatFrame"..i]
                if f then
                    local up, down = SB_GetUpDown(f, i)
                    if up then
                        up._sbForceHidden = false
                        if up.SetAlpha then up:SetAlpha(up._sbOrigAlpha or 1) end
                        if up.EnableMouse then up:EnableMouse(up._sbOrigMouse ~= false) end
                        if up.Show then up:Show() end
                    end
                    if down then
                        down._sbForceHidden = false
                        if down.SetAlpha then down:SetAlpha(down._sbOrigAlpha or 1) end
                        if down.EnableMouse then down:EnableMouse(down._sbOrigMouse ~= false) end
                        if down.Show then down:Show() end
                    end
                end
            end
        end
    else
        SB_ApplyAll()
    end
end

-- Функция полного отключения скрытия стрелок (для отключения модуля)
local function ForceDisableScrollButtonsHiding()
    -- Принудительно восстанавливаем все стрелки вверх и вниз
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame"..i]
        if f then
            local up, down = SB_GetUpDown(f, i)
            if up then
                up._sbForceHidden = false
                -- ПРИНУДИТЕЛЬНО ПОКАЗЫВАЕМ стрелку вверх
                if up.SetAlpha then up:SetAlpha(1) end
                if up.EnableMouse then up:EnableMouse(true) end
                if up.Show then up:Show() end
            end
            if down then
                down._sbForceHidden = false
                -- ПРИНУДИТЕЛЬНО ПОКАЗЫВАЕМ стрелку вниз
                if down.SetAlpha then down:SetAlpha(1) end
                if down.EnableMouse then down:EnableMouse(true) end
                if down.Show then down:Show() end
            end
        end
    end
end

-- ========================================
-- АНИМАЦИИ ЧАТА (задержки/фейды)
-- ========================================

-- Blizzard defaults (из FloatingChatFrame.lua)
local BLIZZ_DEFAULT_ANIM = {
    CHAT_TAB_SHOW_DELAY   = 0.2,  -- задержка перед показом вкладок
    CHAT_TAB_HIDE_DELAY   = 1.0,  -- задержка перед скрытием вкладок
    CHAT_FRAME_FADE_TIME  = 0.15, -- длительность фейд-ин
    CHAT_FRAME_FADE_OUT_TIME = 2.0, -- длительность фейд-аут
}

-- Кэш оригинальных значений Blizzard
local _origAnim = {}

local function SnapshotBlizzAnim()
    if _origAnim.CHAT_TAB_SHOW_DELAY then return end
    _origAnim = {
        CHAT_TAB_SHOW_DELAY   = _G.CHAT_TAB_SHOW_DELAY,
        CHAT_TAB_HIDE_DELAY   = _G.CHAT_TAB_HIDE_DELAY,
        CHAT_FRAME_FADE_TIME  = _G.CHAT_FRAME_FADE_TIME,
        CHAT_FRAME_FADE_OUT_TIME = _G.CHAT_FRAME_FADE_OUT_TIME,
    }
end

local function RestoreBlizzAnim()
    if not _origAnim.CHAT_TAB_SHOW_DELAY then return end
    for k, v in pairs(_origAnim) do 
        _G[k] = v 
    end
end

local function ApplyAnimSet(t)
    _G.CHAT_TAB_SHOW_DELAY      = t.CHAT_TAB_SHOW_DELAY
    _G.CHAT_TAB_HIDE_DELAY      = t.CHAT_TAB_HIDE_DELAY
    _G.CHAT_FRAME_FADE_TIME     = t.CHAT_FRAME_FADE_TIME
    _G.CHAT_FRAME_FADE_OUT_TIME = t.CHAT_FRAME_FADE_OUT_TIME
end

-- Обновим состояние уже существующих вкладок/фреймов:
-- «пну́ть» пересчёт альф (они зависят от фейдов/состояния)
local function RefreshAllTabsAfterAnimChange()
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame"..i]
        if cf and cf:IsShown() then
            if _G.FCFTab_UpdateAlpha then
                _G.FCFTab_UpdateAlpha(cf)
            end
        end
    end
end

local function ApplyChatAnimations_On()
    -- Получаем настройки из базы данных
    local db = SarychUI and SarychUI.db and SarychUI.db.profile
                and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db then return end
    
    local customAnim = {
        CHAT_TAB_SHOW_DELAY   = db.chatTabShowDelay or 0.0,
        CHAT_TAB_HIDE_DELAY   = db.chatTabHideDelay or 0.0,
        CHAT_FRAME_FADE_TIME  = db.chatFrameFadeTime or 0.10,
        CHAT_FRAME_FADE_OUT_TIME = db.chatFrameFadeOutTime or 0.15,
    }
    
    ApplyAnimSet(customAnim)
    RefreshAllTabsAfterAnimChange()
end

local function ApplyChatAnimations_Off()
    RestoreBlizzAnim()
    RefreshAllTabsAfterAnimChange()
end

-- Основной переключатель (используем флаг chatAnimationsEnabled)
local function ApplyChatAnimations()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile
                and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not db or db.enabled == 0 then return end

    local enabled = (db.chatAnimationsEnabled == 1)
    if enabled then
        ApplyChatAnimations_On()
    else
        ApplyChatAnimations_Off()
    end
end

-- Инициализация и «повтор», как делали для внешнего вида
local function InitializeChatAnimations()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UPDATE_CHAT_WINDOWS")
    f:SetScript("OnEvent", function(self)
        SnapshotBlizzAnim()
        ApplyChatAnimations()
        -- лёгкий повтор ~3 сек на случай поздних перерисовок
        local t = 0
        self:SetScript("OnUpdate", function(_, e)
            t = t + e
            if t < 3 then
                ApplyChatAnimations()
            else
                self:SetScript("OnUpdate", nil)
            end
        end)
    end)

    C_Timer.After(1, function()
        SnapshotBlizzAnim()
        ApplyChatAnimations()
    end)
end

-- Экспорт функций в глобальную область
_G.ApplyChatAnimations = ApplyChatAnimations
_G.InitializeChatAnimations = InitializeChatAnimations

-- Инициализация при загрузке модуля
InitializeChatAnimations()

-- ========================================
-- СТИЛЬ ВКЛАДОК ЧАТА (Blizzard-correct)
-- ========================================

-- Подставь своё имя модуля, если нужно
local MODULE = "chat"

-- Дефолты Blizzard из FloatingChatFrame.lua
-- Эти значения — «как в клиенте по умолчанию», не зависят от аддона.
local BLIZZ_DEFAULT_ALPHAS = {
  CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA = 1.0,  -- выбранная, hover
  CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA   = 0.4,  -- выбранная, no mouse
  CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA = 1.0,  -- alert, hover
  CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA   = 1.0,  -- alert, no mouse
  CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA   = 0.6,  -- обычная, hover
  CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA     = 0.2,  -- обычная, no mouse
}

-- Кастомные альфы: «прячем без курсора, показываем при наведении»
local CUSTOM_ALPHAS = {
  CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA = 1,
  CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA   = 0,
  CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA = 1,
  CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA   = 1,
  CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA   = 1,
  CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA     = 0,
}

-- Применить набор альф (любой таблицы выше)
local function ApplyAlphaSet(t)
  for k, v in pairs(t) do _G[k] = v end
end

-- Показать/скрыть бордер-текстуры вкладок
local function SetTabBordersVisible(visible)
  for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
    local base = "ChatFrame"..i.."Tab"
    local left  = _G[base.."Left"]
    local mid   = _G[base.."Middle"]
    local right = _G[base.."Right"]
    if visible then
      if left  and left.Show  then left:Show()  end
      if mid   and mid.Show   then mid:Show()   end
      if right and right.Show then right:Show() end
    else
      if left  and left.Hide  then left:Hide()  end
      if mid   and mid.Hide   then mid:Hide()   end
      if right and right.Hide then right:Hide() end
    end
  end
end

-- Принудительно обновить альфу всех вкладок с учётом новых глобалок
local function RefreshAllTabAlphas()
  for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
    local cf = _G["ChatFrame"..i]
    if cf and cf.GetName then
      if _G.FCFTab_UpdateAlpha then
        _G.FCFTab_UpdateAlpha(cf)  -- корректно пересчитает mouseOver/noMouse alpha
      else
        -- запасной вариант: «пнуть» фейд, если вдруг старая сборка
        local tab = _G[cf:GetName().."Tab"]
        if tab then tab:SetAlpha(tab.noMouseAlpha or 1) end
      end
    end
  end
end

-- Включено: кастом
local function ApplyTabsStyle_On()
  ApplyAlphaSet(CUSTOM_ALPHAS)
  SetTabBordersVisible(false)
  RefreshAllTabAlphas()
end

-- Выключено: дефолт Blizzard
local function ApplyTabsStyle_Off()
  ApplyAlphaSet(BLIZZ_DEFAULT_ALPHAS)   -- строго как в FloatingChatFrame.lua
  SetTabBordersVisible(true)
  RefreshAllTabAlphas()
end

-- Основная точка входа (читает твою настройку tabsStyleEnabled)
local function ApplyTabsStyle()
  local db = SarychUI and SarychUI.db and SarychUI.db.profile
            and SarychUI.db.profile.modules and SarychUI.db.profile.modules[MODULE]
  if not db or db.enabled == 0 then return end

  local enabled = (db.tabsStyleEnabled == 1)
  if enabled then
    ApplyTabsStyle_On()
  else
    ApplyTabsStyle_Off()
  end
end

-- Инициализация и авто-повтор (как у тебя)
local tabsStyleFrame

local function InitializeTabsStyle()
  -- Guard: exported globally and previously invoked twice from this file, which
  -- registered a second event frame doing the same work.
  if tabsStyleFrame then return end

  tabsStyleFrame = CreateFrame("Frame")
  local f = tabsStyleFrame
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("UPDATE_CHAT_WINDOWS")
  f:SetScript("OnEvent", function(self)
    ApplyTabsStyle()
    -- лёгкий повтор в течение ~3 сек на случай поздних перерисовок.
    -- Раз в 0.1с достаточно: перерисовки редки, а полный ApplyTabsStyle недёшев.
    local t, since = 0, 0
    self:SetScript("OnUpdate", function(_, elapsed)
      t = t + elapsed
      if t >= 3 then
        self:SetScript("OnUpdate", nil)
        return
      end
      since = since + elapsed
      if since >= 0.1 then
        since = 0
        ApplyTabsStyle()
      end
    end)
  end)

  C_Timer.After(1, ApplyTabsStyle)
end

-- Функции для модуля (согласно правилам)
local function EnableTabsStyle()
    ApplyTabsStyle_On()
end

local function DisableTabsStyle()
    ApplyTabsStyle_Off()
end

local function ForceDisableTabsStyle()
    -- Принудительное восстановление при отключении модуля
    ApplyTabsStyle_Off()
end

-- Вызови это из своего модуля при инициализации:
InitializeTabsStyle()

-- Если у тебя есть общая функция применения настроек модуля:
-- function SarychUI.modules[MODULE]:ApplyAllSettings()
--   ApplyTabsStyle()
--   -- другие настройки...
-- end


-- ========================================
-- ЭКСПОРТ ФУНКЦИЙ ДЛЯ МОДУЛЯ
-- ========================================

-- Экспортируем функции для использования в module.lua
_G.EnableTooltipPositioning = EnableTooltipPositioning
_G.DisableTooltipPositioning = DisableTooltipPositioning
_G.ForceDisableTooltipPositioning = ForceDisableTooltipPositioning
_G.EnableTooltipIcons = EnableTooltipIcons
_G.DisableTooltipIcons = DisableTooltipIcons
_G.ForceDisableTooltipIcons = ForceDisableTooltipIcons
_G.EnableChatFading = EnableChatFading
_G.DisableChatFading = DisableChatFading
_G.EnableFriendsButtonHiding = EnableFriendsButtonHiding
_G.DisableFriendsButtonHiding = DisableFriendsButtonHiding
_G.ForceDisableFriendsButtonHiding = ForceDisableFriendsButtonHiding
_G.EnableBottomButtonHiding = EnableBottomButtonHiding
_G.DisableBottomButtonHiding = DisableBottomButtonHiding
_G.ForceDisableBottomButtonHiding = ForceDisableBottomButtonHiding
_G.ApplyBottomButtonMod = ApplyBottomButtonMod
_G.EnableScrollButtonsHiding = EnableScrollButtonsHiding
_G.DisableScrollButtonsHiding = DisableScrollButtonsHiding
_G.ForceDisableScrollButtonsHiding = ForceDisableScrollButtonsHiding
_G.ApplyScrollButtonsMod = ApplyScrollButtonsMod
_G.EnableChatFrameButtonHiding = EnableChatFrameButtonHiding
_G.DisableChatFrameButtonHiding = DisableChatFrameButtonHiding
_G.ForceDisableChatFrameButtonHiding = ForceDisableChatFrameButtonHiding
_G.ApplyChatFrameButtonMod = ApplyChatFrameButtonMod
_G.EnableTabsStyle = EnableTabsStyle
_G.DisableTabsStyle = DisableTabsStyle
_G.ForceDisableTabsStyle = ForceDisableTabsStyle
_G.ApplyTabsStyle = ApplyTabsStyle
_G.InitializeTabsStyle = InitializeTabsStyle

-- ========================================
-- ChatFrame ButtonFrame BACKDROP:
--   скрытие альфой и восстановление из RGB/Alpha окна чата (без кешей)
-- ========================================

-- 4 ключа-настройки, от которых зависит скрытие
local SETTINGS_KEYS = {
    "hideChatBottomButtonEnabled",
    "hideChatScrollButtonsEnabled",
    "hideChatFrameButtonEnabled",
    "hideChatButtonFrameTextureEnabled", -- твоя 4-я галка
}

-- безопасное чтение настроек
local function CFG_Get(key, default)
    if type(GetSetting) == "function" then
        local ok,v = pcall(GetSetting, key, default); if ok and v ~= nil then return v end
    end
    if type(sarChat_GetSetting) == "function" then
        local ok,v = pcall(sarChat_GetSetting, key, default); if ok and v ~= nil then return v end
    end
    return default
end

-- все 4 галки включены и модуль чата активен?
local function AllFourOnAndModuleEnabled()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
    if not (db and db.enabled) then return false end
    for i=1,#SETTINGS_KEYS do
        if tonumber(CFG_Get(SETTINGS_KEYS[i], 1)) ~= 1 then return false end
    end
    return true
end

-- получить текущий цвет/альфу окна чата i
-- GetChatWindowInfo(i) -> name, fontSize, r, g, b, alpha, shown, locked, docked, ...
-- где alpha = opacity фона (0..1). Используем bgOpacity напрямую, как в чате.
local function GetChatRGBAlpha(i)
    local ok, name, fontSize, r, g, b, bgOpacity = pcall(GetChatWindowInfo, i)
    if ok and type(r)=="number" and type(g)=="number" and type(b)=="number" then
        local a = bgOpacity or 0.2  -- используем bgOpacity напрямую
        if a < 0 then a = 0 elseif a > 1 then a = 1 end
        
        return r, g, b, a
    end
    -- fallback: мягкая дымка по дефолту Blizzard
    return 0, 0, 0, 0.2
end

-- покрасить и выставить альфу ВСЕМ текстурам подложки/бордера в ButtonFrame
local function TintButtonFrameRegions(bf, r, g, b, a)
    if not bf or not bf.GetNumRegions then return end
    
    local n = SafeForLimit(bf:GetNumRegions(), 0)
    for j = 1, n do
        local tex = select(j, bf:GetRegions())
        if tex and tex.IsObjectType and tex:IsObjectType("Texture") then
            if tex.SetVertexColor then tex:SetVertexColor(r or 1, g or 1, b or 1) end
            if tex.SetAlpha       then tex:SetAlpha(a or 1) end
            if tex.Show           then tex:Show() end
        end
    end
    -- ВАЖНО: не трогаем bf:SetAlpha() вообще — пусть остаётся как в клиенте/скине
end

-- скрыть: только альфа=0 на всех текстурах (сохраняем цвет как есть)
local function HideButtonFrameRegions(bf)
    if not bf or not bf.GetNumRegions then return end
    local n = SafeForLimit(bf:GetNumRegions(), 0)
    for j = 1, n do
        local tex = select(j, bf:GetRegions())
        if tex and tex.IsObjectType and tex:IsObjectType("Texture") then
            if tex.SetAlpha then tex:SetAlpha(0) end
        end
    end
end

-- Полное отключение отображения текстур
local function ForceHideButtonFrameRegions(bf)
    if not bf or not bf.GetNumRegions then return end
    
    -- Просто скрываем фрейм целиком - никаких хуков, никаких обновлений
    bf:Hide()
    bf:SetAlpha(0)
    bf:EnableMouse(false)
    bf._bftForceHidden = true
end

-- Восстановление нормального поведения
local function RestoreButtonFrameRegions(bf)
    if not bf then return end
    
    if bf._bftForceHidden then
        bf._bftForceHidden = false
        -- Восстанавливаем фрейм
        bf:Show()
        bf:SetAlpha(1)
        bf:EnableMouse(true)
    end
end

-- применить режим ко всем ChatFrameXButtonFrame
local function ApplyBackdrop(showMode)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local bf = _G["ChatFrame"..i.."ButtonFrame"]
        if bf then
            if showMode then
                -- Восстанавливаем нормальное поведение
                RestoreButtonFrameRegions(bf)
                local r,g,b,a = GetChatRGBAlpha(i)
                TintButtonFrameRegions(bf, r, g, b, a)
            else
                -- Принудительно скрываем с хуками
                ForceHideButtonFrameRegions(bf)
            end
        end
    end
end

-- публичный апдейтер: дергай из ApplyAllSettings()
function BFT_ApplyButtonFrameTextures()
    if AllFourOnAndModuleEnabled() then
        -- все 4 галки и модуль включены -> скрыть
        ApplyBackdrop(false)
    else
        -- иначе -> восстановить «как в окне»: берем RGB/alpha из GetChatWindowInfo
        ApplyBackdrop(true)
    end
end

-- авто-подстройка при логине/перестройке окон
local BFT_evt = CreateFrame("Frame")
BFT_evt:RegisterEvent("PLAYER_LOGIN")
BFT_evt:RegisterEvent("UPDATE_CHAT_WINDOWS")
BFT_evt:SetScript("OnEvent", function()
    BFT_ApplyButtonFrameTextures()
end)


-- (опционально) если у тебя где-то меняется цвет/прозрачность окна на лету,
-- просто вызови BFT_ApplyButtonFrameTextures() после изменения — подложка сама перекрасится.

-- Функция для полного отключения системы (при отключении модуля)
function BFT_ForceDisableButtonFrameTextures()
    -- Восстанавливаем все ButtonFrame
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local bf = _G["ChatFrame"..i.."ButtonFrame"]
        if bf then
            RestoreButtonFrameRegions(bf)
            -- Восстанавливаем нормальные текстуры
            local r,g,b,a = GetChatRGBAlpha(i)
            TintButtonFrameRegions(bf, r, g, b, a)
        end
    end
end

-- Экспортируем функции в глобальную область
_G.BFT_ApplyButtonFrameTextures = BFT_ApplyButtonFrameTextures
_G.BFT_ForceDisableButtonFrameTextures = BFT_ForceDisableButtonFrameTextures