-- SarychUI Chat Module
local moduleName = "chat"
local module = {}

local spamFilterRegistered = false

-- Register module first
SarychUI:RegisterModule(moduleName, module)

-- Localization
local L = SarychUI.L

-- Helper function to get settings
local function GetSetting(key, default)
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if db and db[key] ~= nil then
        return db[key]
    end
    return default
end

-- Internal: force-disable chat animations even if module is globally disabled
local function ForceDisableChatAnimations()
    if not _G.ApplyChatAnimations then return end
    local dbRoot = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
    local db = dbRoot and dbRoot[moduleName]
    if not db then return end

    -- Temporarily mark module enabled so ApplyChatAnimations executes its OFF branch
    local prevEnabled = db.enabled
    local prevAnim = db.chatAnimationsEnabled
    db.enabled = 1
    db.chatAnimationsEnabled = 0
    _G.ApplyChatAnimations()
    -- Restore flags
    db.chatAnimationsEnabled = prevAnim
    db.enabled = prevEnabled
end

-- Initialize module
function module:Initialize()
    -- Basic initialization
end

-- Enable module
function module:Enable()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end

    -- Отключаем стандартное сообщение об ошибке интерфейса (Blizzard показывает его только один раз)
    INTERFACE_ACTION_BLOCKED_SHOWN = true

    -- Register Alt mode callback for ChatBar visibility
    if SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("chat", function(isAltPressed)
            self:UpdateChatBarVisibility()
        end)
    end

    -- Apply all settings
    self:ApplyAllSettings()
end

-- Disable module
function module:Disable()
    -- Восстанавливаем стандартное сообщение об ошибке интерфейса
    INTERFACE_ACTION_BLOCKED_SHOWN = false

    -- Unregister Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback("chat")
    end

    -- Ensure chat animations are switched off immediately when module is disabled
    ForceDisableChatAnimations()

    -- Disable ChatBar completely
    self:DisableChatBar()

    -- Disable Hotkeys completely
    self:DisableHotkeys()

    -- Disable chat font size menu + character counter
    self:DisableChatTabFontSizeMenu()
    self:DisableChatCharCount()

    -- Disable Channel Shortening completely
    self:DisableChannelShortening()

    -- Disable Chat Copying completely
    self:DisableChatCopying()

    -- Disable URL Copying completely
    self:DisableUrlCopying()

    -- Disable emotion icons and picker
    self:DisableEmotionSettings()

    -- Disable Fast Scroll completely
    self:DisableFastScroll()

    -- Disable Spam Filter completely
    self:DisableSpamFilter()

    -- Disable Chat Wheel completely
    self:DisableChatWheel()
    
    -- Disable Tooltip Position completely
    self:ForceDisableTooltipPositioning()
    
    -- ПРИНУДИТЕЛЬНОЕ ОТКЛЮЧЕНИЕ ПОЗИЦИОНИРОВАНИЯ ПРЯМО ЗДЕСЬ
    if ItemRefTooltip then
        -- Отключаем все хуки для позиционирования
        ItemRefTooltip:SetScript("OnShow", nil)
        ItemRefTooltip:SetScript("OnHide", nil)
    end
    
    -- Отключаем хуки PetActionBarFrame
    if PetActionBarFrame then
        PetActionBarFrame:SetScript("OnShow", nil)
        PetActionBarFrame:SetScript("OnHide", nil)
    end
    
    -- Disable Tooltip Icons completely
    self:ForceDisableTooltipIcons()
    
    -- Disable Chat Fading completely
    self:DisableChatFading()
    
    -- Disable Friends Button Hiding completely
    self:DisableFriendsButtonHiding()
    
    -- ПРИНУДИТЕЛЬНОЕ ОТКЛЮЧЕНИЕ FRIENDS BUTTON ПРЯМО ЗДЕСЬ
    if _G.ForceDisableFriendsButtonHiding then
        _G.ForceDisableFriendsButtonHiding()
    end
    
    -- Disable Bottom Button Hiding completely
    self:DisableBottomButtonHiding()
    
    -- ПРИНУДИТЕЛЬНОЕ ОТКЛЮЧЕНИЕ BOTTOM BUTTON ПРЯМО ЗДЕСЬ (как у кнопки друзей)
    if _G.ForceDisableBottomButtonHiding then
        _G.ForceDisableBottomButtonHiding()
    end
    
    -- Disable Scroll Buttons Hiding completely
    self:DisableScrollButtonsHiding()
    
    -- ПРИНУДИТЕЛЬНОЕ ОТКЛЮЧЕНИЕ SCROLL BUTTONS ПРЯМО ЗДЕСЬ (как у кнопки друзей)
    if _G.ForceDisableScrollButtonsHiding then
        _G.ForceDisableScrollButtonsHiding()
    end
    
    -- Disable Chat Frame Button Hiding completely
    self:DisableChatFrameButtonHiding()
    
    -- ПРИНУДИТЕЛЬНОЕ ОТКЛЮЧЕНИЕ CHAT FRAME BUTTON ПРЯМО ЗДЕСЬ
    if _G.ForceDisableChatFrameButtonHiding then
        _G.ForceDisableChatFrameButtonHiding()
    end
    
    -- Disable Tabs Style completely
    if _G.ForceDisableTabsStyle then
        _G.ForceDisableTabsStyle()
    end
    
    -- ПРИНУДИТЕЛЬНОЕ ПОКАЗАНИЕ ПОДЛОЖКИ ПРИ ОТКЛЮЧЕНИИ МОДУЛЯ
    if _G.BFT_ApplyButtonFrameTextures then
        _G.BFT_ApplyButtonFrameTextures()
    end
    
    -- ПРИНУДИТЕЛЬНОЕ ОТКЛЮЧЕНИЕ ИКОНОК ПРЯМО ЗДЕСЬ
    if ItemRefTooltip then
        -- Скрываем все иконки
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
        
        -- ОТКЛЮЧАЕМ ВСЕ ХУКИ ПРЯМО ЗДЕСЬ
        ItemRefTooltip:SetScript('OnTooltipSetItem', nil)
        ItemRefTooltip:SetScript('OnTooltipSetSpell', nil)
        ItemRefTooltip:SetScript('OnTooltipSetAchievement', nil)
        ItemRefTooltip:SetScript('OnTooltipCleared', nil)
    end
    
    -- Восстанавливаем оригинальное поведение кнопки меню чата при отключении модуля
    local menuButton = _G["ChatFrameMenuButton"]
    if menuButton then
        -- Восстанавливаем оригинальные обработчики
        if menuButton._sarychUIOriginalRegisterForClicks then
            menuButton:_sarychUIOriginalRegisterForClicks("AnyUp")
        else
            menuButton:RegisterForClicks("AnyUp")
        end
        
        if menuButton._sarychUIOriginalOnClick then
            menuButton:SetScript("OnClick", menuButton._sarychUIOriginalOnClick)
        else
            -- Если не было оригинального, устанавливаем стандартный обработчик Blizzard
            menuButton:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    local chatMenu = _G["ChatMenu"]
                    if chatMenu then
                        if chatMenu:IsShown() then
                            chatMenu:Hide()
                        else
                            chatMenu:Show()
                            -- Воспроизводим звук как в оригинальном Blizzard
                            PlaySound("igChatEmoteButton")
                        end
                    end
                elseif button == "RightButton" then
                    -- ПКМ ничего не делает при отключенном модуле
                    return
                end
            end)
        end
    end

    -- Reset all functionality
    self:ResetAllFunctionality()
end

-- Apply all module settings
function module:ApplyAllSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then 
        -- Если модуль отключен, принудительно отключаем все функции
        self:DisableChatBar()
        self:DisableHotkeys()
        self:DisableChatTabFontSizeMenu()
        self:DisableChatCharCount()
        self:DisableChannelShortening()
        self:DisableChatCopying()
        self:DisableUrlCopying()
        self:DisableEmotionSettings()
        self:DisableFastScroll()
        self:DisableSpamFilter()
        self:DisableChatWheel()
        self:DisableTooltipPositioning()
        self:DisableTooltipIcons()
        self:DisableChatFading()
        self:DisableFriendsButtonHiding()
        self:DisableBottomButtonHiding()
        self:DisableScrollButtonsHiding()
        self:DisableChatFrameButtonHiding()
        -- Disable Tabs Style when module is disabled
        if _G.ForceDisableTabsStyle then
            _G.ForceDisableTabsStyle()
        end
        -- Принудительно показываем подложку при отключении модуля
        if _G.BFT_ApplyButtonFrameTextures then
            _G.BFT_ApplyButtonFrameTextures()
        end
        -- Принудительно отключаем анимации чата в реальном времени
        ForceDisableChatAnimations()
        return
    end
    
    -- Apply ChatBar settings
    self:ApplyChatBarSettings()
    
    -- Apply Hotkeys settings
    self:ApplyHotkeysSettings()

    -- Apply chat tab font size menu + character counter
    self:ApplyChatTabFontSizeMenuSettings()
    self:ApplyChatCharCountSettings()
    
    -- Apply Channel Shortening settings
    self:ApplyChannelShorteningSettings()
    
    -- Apply Chat Copying settings
    self:ApplyChatCopyingSettings()
    
    -- Apply URL Copying settings
    self:ApplyUrlCopyingSettings()

    -- Apply emotion icons + picker settings
    self:ApplyEmotionSettings()
    
    -- Apply Fast Scroll settings
    self:ApplyFastScrollSettings()
    
    -- Apply Spam Filter settings
    self:ApplySpamFilterSettings()

    -- Apply Chat Wheel settings
    self:ApplyChatWheelSettings()
    
    -- Apply Tooltip Position settings
    self:ApplyTooltipPositionSettings()
    
    -- Apply Tooltip Icons settings
    self:ApplyTooltipIconsSettings()
    
    -- Apply Chat Fading settings
    self:ApplyChatFadingSettings()
    
    -- Apply Friends Button settings
    self:ApplyFriendsButtonSettings()
    
    -- Apply Bottom Button settings
    self:ApplyBottomButtonSettings()
    
    -- Apply Scroll Buttons settings
    self:ApplyScrollButtonsSettings()
    
    -- Apply Chat Frame Button settings
    self:ApplyChatFrameButtonSettings()
    
    -- Apply Button Frame Textures settings (подложка)
    if _G.BFT_ApplyButtonFrameTextures then
        _G.BFT_ApplyButtonFrameTextures()
    end
    
    -- Apply Tabs Style settings
    if _G.ApplyTabsStyle then
        _G.ApplyTabsStyle()
    end
    
    -- Apply Chat Animations settings
    if _G.ApplyChatAnimations then
        _G.ApplyChatAnimations()
    end
    
    -- Apply other settings will be added here
end

-- Reset all module functionality
function module:ResetAllFunctionality()
    -- Reset all functionality to default state
end

-- Force complete restoration to default state
function module:ForceResetAllElements()
    -- Force complete restoration to default state
end

-- Apply ChatBar settings
function module:ApplyChatBarSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    if db.chatBarEnabled == 1 then
        self:EnableChatBar()
    else
        self:DisableChatBar()
    end
end

-- Enable ChatBar functionality
function module:EnableChatBar()
    -- Enable ChatBar by setting ChatBar_Active = true
    if _G.ChatBar_Active ~= nil then
        _G.ChatBar_Active = true
    end
    
    -- ChatBar is already created by ChatBar.lua
    -- We just need to show it and apply Alt mode behavior
    if _G.ChatBarFrame then
        _G.ChatBarFrame:Show()
    end
    
    -- Update visibility based on current Alt state
    self:UpdateChatBarVisibility()
end

-- Disable ChatBar functionality
function module:DisableChatBar()
    -- Hide ChatBar
    if _G.ChatBarFrame then
        _G.ChatBarFrame:Hide()
    end
    
    -- Disable ChatBar completely by setting ChatBar_Active = false
    if _G.ChatBar_Active then
        _G.ChatBar_Active = false
    end
end

-- Apply Hotkeys settings
function module:ApplyHotkeysSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    -- Используем GetSetting для получения значения с дефолтом, если настройка не установлена
    local chatHotkeysEnabled = GetSetting("chatHotkeysEnabled", 1)
    if chatHotkeysEnabled == 1 then
        self:EnableHotkeys()
    else
        self:DisableHotkeys()
    end
end

-- Enable Hotkeys functionality
function module:EnableHotkeys()
    -- Hook hotkeys to all chat edit boxes
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox and _G.HookHotkeys then
            _G.HookHotkeys(editBox)
        end
    end
    
    -- Also hook to any new edit boxes that might be created
    if not self.hotkeysHooked then
        self.hotkeysHooked = true
        -- Hook to PLAYER_ENTERING_WORLD event to catch new edit boxes
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:SetScript("OnEvent", function(self, event)
            if event == "PLAYER_ENTERING_WORLD" then
                -- Re-hook hotkeys to all chat edit boxes
                for i = 1, NUM_CHAT_WINDOWS do
                    local editBox = _G["ChatFrame"..i.."EditBox"]
                    if editBox and _G.HookHotkeys then
                        _G.HookHotkeys(editBox)
                    end
                end
            end
        end)
    end
end

-- Disable Hotkeys functionality
function module:DisableHotkeys()
    -- Unhook hotkeys from all chat edit boxes
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame"..i.."EditBox"]
        if editBox and _G.UnhookHotkeys then
            _G.UnhookHotkeys(editBox)
        end
    end
end

-- Apply Channel Shortening settings
function module:ApplyChannelShorteningSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end

    if _G.RefreshChannelShorteningCache then
        _G.RefreshChannelShorteningCache()
    end
    
    -- Проверяем значение настройки (по умолчанию 1, если не установлено)
    local channelShorteningEnabled = db.channelShorteningEnabled
    if channelShorteningEnabled == nil then
        channelShorteningEnabled = 1 -- Значение по умолчанию
    end
    
    if channelShorteningEnabled == 1 then
        self:EnableChannelShortening()
    else
        self:DisableChannelShortening()
    end
end

-- Enable Channel Shortening functionality
function module:EnableChannelShortening()
    -- Replace AddMessage function for all chat frames (like in original)
    if not self.channelShorteningHooked then
        self.channelShorteningHooked = true
        
        -- Store original functions and replace with our version
        for i = 1, NUM_CHAT_WINDOWS do
            local chatFrame = _G["ChatFrame" .. i]
            if chatFrame and chatFrame.AddMessage then
                -- Store original function
                if not self.originalAddMessage then
                    self.originalAddMessage = {}
                end
                self.originalAddMessage[chatFrame] = chatFrame.AddMessage
                
                -- Replace with our function
                chatFrame.AddMessage = function(frame, text, r, g, b, id)
                    if text and _G.ApplyChannelShortening then
                        local shortenedText = _G.ApplyChannelShortening(text, nil, nil, nil)
                        if shortenedText and shortenedText ~= text then
                            -- Use shortened text
                            text = shortenedText
                        end

                    end
                    -- Call original function with (possibly modified) text
                    return self.originalAddMessage[frame](frame, text, r, g, b, id)
                end
            end
        end
    end
end

-- Disable Channel Shortening functionality
function module:DisableChannelShortening()
    if self.channelShorteningHooked then
        -- Restore original AddMessage functions
        if self.originalAddMessage then
            for i = 1, NUM_CHAT_WINDOWS do
                local chatFrame = _G["ChatFrame" .. i]
                if chatFrame and self.originalAddMessage[chatFrame] then
                    chatFrame.AddMessage = self.originalAddMessage[chatFrame]
                end
            end
            self.originalAddMessage = nil
        end
        self.channelShorteningHooked = false
    end
end

-- Apply Chat Copying settings
function module:ApplyChatCopyingSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    if db.copyOnCtrlClickEnabled == 1 then
        self:EnableChatCopying()
    else
        self:DisableChatCopying()
    end
end

-- Enable Chat Copying functionality
function module:EnableChatCopying()
    -- Устанавливаем глобальный флаг
    _G.SarychUI_ChatCopyingEnabled = true
    
    -- Вызываем функцию из functionality.lua если она доступна
    if _G.EnableChatCopying then
        _G.EnableChatCopying(true)
    end
end

-- Disable Chat Copying functionality
function module:DisableChatCopying()
    -- Отключаем глобальный флаг
    _G.SarychUI_ChatCopyingEnabled = false
    
    -- Вызываем функцию из functionality.lua если она доступна
    if _G.DisableChatCopying then
        _G.DisableChatCopying()
    end
end

-- Apply URL Copying settings
function module:ApplyUrlCopyingSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    if db.urlCopyingEnabled == 1 then
        self:EnableUrlCopying()
    else
        self:DisableUrlCopying()
    end
end

-- Enable URL Copying functionality
function module:EnableUrlCopying()
    if _G.EnableUrlCopying then
        _G.EnableUrlCopying(true)
    end
end

-- Disable URL Copying functionality
function module:DisableUrlCopying()
    if _G.DisableUrlCopying then
        _G.DisableUrlCopying()
    end
end

-- Apply Fast Scroll settings
function module:ApplyFastScrollSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    if db.fastScrollEnabled == 1 then
        self:EnableFastScroll()
    else
        self:DisableFastScroll()
    end
end

-- Enable Fast Scroll functionality
function module:EnableFastScroll()
    if _G.EnableFastScroll then
        _G.EnableFastScroll(true)
    end
end

-- Disable Fast Scroll functionality
function module:DisableFastScroll()
    if _G.DisableFastScroll then
        _G.DisableFastScroll()
    end
end

-- Apply Spam Filter settings
function module:ApplySpamFilterSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    -- Используем правильное имя настройки из options.lua
    if db.spamFilterEnabled == 1 then
        self:EnableSpamFilter()
        -- Обновляем список паттернов при каждом применении настроек
        self:UpdateSpamFilterPatterns()
    else
        self:DisableSpamFilter()
    end
end

-- Update Spam Filter patterns
function module:UpdateSpamFilterPatterns()
    if _G.SarychUI_RefreshCachedSpamPatterns then
        _G.SarychUI_RefreshCachedSpamPatterns()
    end
end

-- Enable Spam Filter functionality
function module:EnableSpamFilter()
    if _G.EnableSpamFilter then
        _G.EnableSpamFilter(true)
    end
    
    if spamFilterRegistered then
        return
    end

    -- Регистрируем фильтр системных сообщений
    if _G.CHAT_MSG_SYSTEM_filter then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", _G.CHAT_MSG_SYSTEM_filter)
        spamFilterRegistered = true
    end
end

-- Disable Spam Filter functionality
function module:DisableSpamFilter()
    if _G.DisableSpamFilter then
        _G.DisableSpamFilter()
    end
    
    if not spamFilterRegistered then
        return
    end

    -- Удаляем фильтр системных сообщений
    if _G.CHAT_MSG_SYSTEM_filter then
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", _G.CHAT_MSG_SYSTEM_filter)
    end
    spamFilterRegistered = false
end

-- Apply Chat Wheel settings
function module:ApplyChatWheelSettings()
    if _G.SarychUI_ChatWheel and _G.SarychUI_ChatWheel.ApplySettings then
        _G.SarychUI_ChatWheel.ApplySettings()
    end
end

function module:DisableChatWheel()
    if _G.SarychUI_ChatWheel then
        if _G.SarychUI_ChatWheel.Close then
            _G.SarychUI_ChatWheel.Close()
        end
        if _G.SarychUI_ChatWheel.ApplySettings then
            _G.SarychUI_ChatWheel.ApplySettings()
        end
    end
end

-- Update ChatBar visibility based on Alt mode
function module:UpdateChatBarVisibility()
    if not SarychUI.AltMode then return end
    
    local isAltPressed = SarychUI.AltMode:IsAltPressed()
    local chatBarOnAlt = GetSetting("chatBarOnAlt", 0) == 1
    local chatBarEnabled = GetSetting("chatBarEnabled", 1) == 1
    
    if not chatBarEnabled then return end
    
    if chatBarOnAlt then
        if isAltPressed then
            -- Show ChatBar when Alt is pressed
            if _G.ChatBarFrame then
                _G.ChatBarFrame:SetAlpha(1.0)
                _G.ChatBarFrame:Show()
            end
        else
            -- Hide ChatBar when Alt is released (only if not in initial animation)
            if _G.ChatBarFrame and not _G.ChatBarFrame.shouldHideAfterLoad then
                _G.ChatBarFrame:Hide()
            end
        end
    else
        -- Always show ChatBar when Alt mode is disabled
        if _G.ChatBarFrame then
            _G.ChatBarFrame:Show()
        end
    end
end

-- Apply Tooltip Position settings
function module:ApplyTooltipPositionSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    if db.tooltipPositionEnabled == 1 then
        self:EnableTooltipPositioning()
    else
        self:DisableTooltipPositioning()
    end
end

-- Enable Tooltip Position functionality
function module:EnableTooltipPositioning()
    if _G.EnableTooltipPositioning then
        _G.EnableTooltipPositioning()
    end
end

-- Disable Tooltip Position functionality
function module:DisableTooltipPositioning()
    if _G.DisableTooltipPositioning then
        _G.DisableTooltipPositioning()
    end
end

-- Force Disable Tooltip Position functionality (for module disable)
function module:ForceDisableTooltipPositioning()
    if _G.ForceDisableTooltipPositioning then
        _G.ForceDisableTooltipPositioning()
    end
end

-- Apply Tooltip Icons settings
function module:ApplyTooltipIconsSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    if db.itemRefIconsEnabled == 1 then
        self:EnableTooltipIcons()
    else
        self:DisableTooltipIcons()
    end
end

-- Enable Tooltip Icons functionality
function module:EnableTooltipIcons()
    if _G.EnableTooltipIcons then
        _G.EnableTooltipIcons()
    end
end

-- Disable Tooltip Icons functionality
function module:DisableTooltipIcons()
    if _G.DisableTooltipIcons then
        _G.DisableTooltipIcons()
    end
end

-- Force Disable Tooltip Icons functionality (for module disable)
function module:ForceDisableTooltipIcons()
    if _G.ForceDisableTooltipIcons then
        _G.ForceDisableTooltipIcons()
    end
end

-- Apply Chat Fading settings
function module:ApplyChatFadingSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    if db.visibleSecondsEnabled == 1 then
        self:EnableChatFading()
    else
        self:DisableChatFading()
    end
end

-- Enable Chat Fading functionality
function module:EnableChatFading()
    if _G.EnableChatFading then
        _G.EnableChatFading()
    end
end

-- Disable Chat Fading functionality
function module:DisableChatFading()
    if _G.DisableChatFading then
        _G.DisableChatFading()
    end
end

-- Apply Friends Button settings
function module:ApplyFriendsButtonSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then return end
    
    if db.friendsButtonModEnabled == 1 then
        self:EnableFriendsButtonHiding()
    else
        self:DisableFriendsButtonHiding()
    end
end

-- Enable Friends Button Hiding functionality
function module:EnableFriendsButtonHiding()
    if _G.EnableFriendsButtonHiding then
        _G.EnableFriendsButtonHiding()
    end
end

-- Disable Friends Button Hiding functionality
function module:DisableFriendsButtonHiding()
    if _G.DisableFriendsButtonHiding then
        _G.DisableFriendsButtonHiding()
    end
end

-- Apply Bottom Button settings
function module:ApplyBottomButtonSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then 
        return 
    end
    
    if db.hideChatBottomButtonEnabled == 1 then
        self:EnableBottomButtonHiding()
    else
        self:DisableBottomButtonHiding()
    end
end

-- Enable Bottom Button Hiding functionality
function module:EnableBottomButtonHiding()
    if _G.EnableBottomButtonHiding then
        _G.EnableBottomButtonHiding()
    end
end

-- Disable Bottom Button Hiding functionality
function module:DisableBottomButtonHiding()
    if _G.DisableBottomButtonHiding then
        _G.DisableBottomButtonHiding()
    end
end

-- Apply Scroll Buttons settings
function module:ApplyScrollButtonsSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then 
        return 
    end
    
    if db.hideChatScrollButtonsEnabled == 1 then
        self:EnableScrollButtonsHiding()
    else
        self:DisableScrollButtonsHiding()
    end
end

-- Enable Scroll Buttons Hiding functionality
function module:EnableScrollButtonsHiding()
    if _G.EnableScrollButtonsHiding then
        _G.EnableScrollButtonsHiding()
    end
end

-- Disable Scroll Buttons Hiding functionality
function module:DisableScrollButtonsHiding()
    if _G.DisableScrollButtonsHiding then
        _G.DisableScrollButtonsHiding()
    end
end

--- Apply Chat Frame Button settings
function module:ApplyChatFrameButtonSettings()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db then 
        return 
    end
    
    if db.hideChatFrameButtonEnabled == 1 then
        self:EnableChatFrameButtonHiding()
    else
        self:DisableChatFrameButtonHiding()
    end
end

--- Enable Chat Frame Button Hiding functionality
function module:EnableChatFrameButtonHiding()
    if _G.EnableChatFrameButtonHiding then
        _G.EnableChatFrameButtonHiding()
    end
end

--- Disable Chat Frame Button Hiding functionality
function module:DisableChatFrameButtonHiding()
    if _G.DisableChatFrameButtonHiding then
        _G.DisableChatFrameButtonHiding()
    end
end

function module:ApplyChatTabFontSizeMenuSettings()
    if _G.ApplyChatTabFontSizeMenuSettings then
        _G.ApplyChatTabFontSizeMenuSettings()
    end
end

function module:DisableChatTabFontSizeMenu()
    if _G.DisableChatTabFontSizeMenu then
        _G.DisableChatTabFontSizeMenu()
    end
end

function module:ApplyChatCharCountSettings()
    if _G.ApplyChatCharCountSettings then
        _G.ApplyChatCharCountSettings()
    end
end

function module:DisableChatCharCount()
    if _G.DisableChatCharCount then
        _G.DisableChatCharCount()
    end
end

function module:ApplyEmotionSettings()
    if _G.ApplyEmotionSettings then
        _G.ApplyEmotionSettings()
    end
end

function module:DisableEmotionSettings()
    if _G.DisableEmotionIcons then
        _G.DisableEmotionIcons()
    end
    if _G.DisableEmotionPicker then
        _G.DisableEmotionPicker()
    end
end
