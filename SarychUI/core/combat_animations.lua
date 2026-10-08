-- SarychUI Combat Animations Utility
-- Универсальная утилита для анимаций во время боя (хоткеи, номера страниц и т.д.)

local ipairs = ipairs
local tinsert = table.insert

local CombatAnimations = {}

-- Флаги анимации для разных элементов
local animationFlags = {
    hotkeys = false,
    pageNumbers = false,
    textIndicators = false
}

-- Универсальная функция анимации альфы
local function AnimateAlpha(frame, duration, fromA, toA)
    if not frame or not frame.SetAlpha then return end
    if duration <= 0 then frame:SetAlpha(toA or 1) return end

    -- Снимем любые системные фейды
    if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end

    frame:Show()
    frame:SetAlpha(fromA or 0)

    -- Оптимизация: используем встроенную анимацию WoW вместо самодельной
    if UIFrameFadeIn and toA == 1 then
        UIFrameFadeIn(frame, duration, fromA or 0, toA or 1)
    elseif UIFrameFadeOut and toA == 0 then
        UIFrameFadeOut(frame, duration, fromA or 1, toA or 0)
    else
        -- Fallback для других случаев
        frame:SetAlpha(toA or 1)
    end
end

-- Универсальная функция для получения настроек модуля
local function GetModuleSettings(moduleName)
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    
    local currentDb = SarychUI.db.profile.modules[moduleName]
    if not currentDb or not currentDb.enabled then 
        return nil 
    end
    -- FrostAtomUI bars: Blizzard hotkeys / page numbers no longer exist.
    if moduleName == "mainmenubar" then
        local FA = SarychUI.FrostAtomBars
        if FA and FA.bootMode == "frostatom" then
            return nil
        end
    end
    
    return currentDb
end

-- Универсальная функция для анимации множественных элементов
local function AnimateMultipleElements(elements, duration, fromA, toA, animationType)
    if not elements or #elements == 0 then return end
    
    -- Обрабатываем все элементы за один проход
    for _, element in ipairs(elements) do
        if element and element:IsVisible() then
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(element) end
            if duration > 0 and fromA ~= toA then
                AnimateAlpha(element, duration, fromA, toA)
            else
                element:SetAlpha(toA)
            end
        end
    end
    
    -- Сбрасываем флаг анимации для соответствующего типа
    if animationType and toA == 1 then
        C_Timer.After(duration, function()
            animationFlags[animationType] = false
        end)
    end
end

-- Hotkey alpha has one owner: modules/mainmenubar/panelText.lua.  This combat
-- coordinator only tells it that the combat state changed; it never writes a
-- FontString alpha itself.
local function UpdateMainMenuBarHotkeys(fadeTime, inCombat, source)
    local mainmenubar = SarychUI.modules and SarychUI.modules.mainmenubar
    if mainmenubar and mainmenubar.SetHotkeyCombatState then
        mainmenubar:SetHotkeyCombatState(inCombat, fadeTime, source)
    elseif mainmenubar and mainmenubar.UpdateAllHotkeys then
        mainmenubar:UpdateAllHotkeys(fadeTime, nil, source)
    end
end

function CombatAnimations:FadeOutHotkeys(fadeTime, source)
    UpdateMainMenuBarHotkeys(fadeTime, false, source or "CombatAnimations:FadeOut")
end

function CombatAnimations:FadeInHotkeys(source)
    local settings = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
        and SarychUI.db.profile.modules.mainmenubar
    local fadeTime = settings and settings.hotkeysFadeAfterCombat and settings.hotkeysFadeTime or 0
    UpdateMainMenuBarHotkeys(fadeTime, true, source or "CombatAnimations:FadeIn")
end

-- Функция для номеров страниц
function CombatAnimations:FadeOutPageNumbers(fadeTime)
    local settings = GetModuleSettings("mainmenubar")
    if not settings then return end
    
    -- Проверяем иерархию настроек для номеров страниц
    local hidePageNumbers = settings.hidePageNumbers
    local showInCombat = settings.showPageNumbersInCombat
    
    -- Если "Скрыть номера страниц" отключено - не скрываем
    if not hidePageNumbers then return end
    
    local fadeEnabled = settings.pageNumbersFadeAfterCombat
    local fadeTime = fadeTime or settings.pageNumbersFadeTime or 0.4
    
    -- Обрабатываем номер страницы (как в оригинале - проверяем IsVisible)
    if MainMenuBarPageNumber and MainMenuBarPageNumber:IsVisible() then
        if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(MainMenuBarPageNumber) end
        if fadeEnabled and showInCombat then
            UIFrameFadeOut(MainMenuBarPageNumber, fadeTime, 1, 0)
        else
            MainMenuBarPageNumber:SetAlpha(0)
        end
    end
end

function CombatAnimations:FadeInPageNumbers()
    local settings = GetModuleSettings("mainmenubar")
    if not settings then return end
    
    -- Проверяем иерархию настроек для номеров страниц
    local hidePageNumbers = settings.hidePageNumbers
    local showInCombat = settings.showPageNumbersInCombat
    
    -- Если "Скрыть номера страниц" отключено ИЛИ "Показывать во время боя" отключено - не показываем
    if not hidePageNumbers or not showInCombat then 
        return 
    end

    local fadeEnabled = settings.pageNumbersFadeAfterCombat
    local fadeTime = settings.pageNumbersFadeTime or 0.4

    if MainMenuBarPageNumber then
        -- Убираем активные анимации перед началом новой
        if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(MainMenuBarPageNumber) end
        
        if fadeEnabled then
            -- Устанавливаем флаг анимации только если включена анимация
            animationFlags.pageNumbers = true
            
            -- жёстко анимируем вручную: никто не перебьёт
            MainMenuBarPageNumber:Show()
            MainMenuBarPageNumber:SetAlpha(0)
            UIFrameFadeIn(MainMenuBarPageNumber, fadeTime, 0, 1)
            
            -- Сбрасываем флаг анимации
            C_Timer.After(fadeTime, function()
                animationFlags.pageNumbers = false
            end)
        else
            -- Резкое появление без анимации - сбрасываем флаг сразу
            animationFlags.pageNumbers = false
            MainMenuBarPageNumber:Show()
            MainMenuBarPageNumber:SetAlpha(1)
        end
    end
end

-- Функция для текстовых индикаторов
function CombatAnimations:FadeOutTextIndicators(fadeTime)
    local settings = GetModuleSettings("frame")
    if not settings then return end
    
    -- Проверяем иерархию настроек для текстовых индикаторов
    local showOnAlt = settings.showOnAlt == 1
    local showInCombat = settings.showTextIndicatorsInCombat
    
    -- Если "Показывать при Alt" отключено - не скрываем
    if not showOnAlt then return end
    
    local fadeEnabled = settings.textIndicatorsFadeAfterCombat
    local fadeTime = fadeTime or settings.textIndicatorsFadeTime or 0.4
    
    -- Собираем все текстовые индикаторы
    local textIndicators = {}
    
    -- PlayerFrame
    if PlayerFrameHealthBarText then tinsert(textIndicators, PlayerFrameHealthBarText) end
    if PlayerFrameManaBarText then tinsert(textIndicators, PlayerFrameManaBarText) end
    
    -- TargetFrame
    if TargetFrameTextureFrameHealthBarText then tinsert(textIndicators, TargetFrameTextureFrameHealthBarText) end
    if TargetFrameTextureFrameManaBarText then tinsert(textIndicators, TargetFrameTextureFrameManaBarText) end
    
    -- PetFrame
    if PetFrameHealthBarText then tinsert(textIndicators, PetFrameHealthBarText) end
    if PetFrameManaBarText then tinsert(textIndicators, PetFrameManaBarText) end
    
    -- FocusFrame
    if FocusFrameHealthBarText then tinsert(textIndicators, FocusFrameHealthBarText) end
    if FocusFrameManaBarText then tinsert(textIndicators, FocusFrameManaBarText) end
    
    -- Обрабатываем все индикаторы
    for _, indicator in ipairs(textIndicators) do
        if indicator then
            local currentAlpha = indicator:GetAlpha() or 1
            if currentAlpha > 0 then
                if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(indicator) end
                if fadeEnabled and fadeTime > 0 then
                    indicator:Show() -- Убеждаемся что фрейм видим для анимации
                    AnimateAlpha(indicator, fadeTime, currentAlpha, 0)
                else
                    indicator:SetAlpha(0)
                end
            end
        end
    end
end

function CombatAnimations:FadeInTextIndicators()
    -- Убираем проверку флага - при входе в бой всегда показываем, даже если предыдущая анимация не завершилась
    -- CancelTextFades() уже вызван в OnEnterCombat(), так что старые анимации прерваны
    
    local settings = GetModuleSettings("frame")
    if not settings then return end
    
    -- Проверяем настройку "Показывать во время боя"
    local showInCombat = settings.showTextIndicatorsInCombat
    
    -- Если "Показывать во время боя" отключено - не показываем
    -- showOnAlt НЕ проверяем - в бою Alt не влияет
    if not showInCombat then 
        return 
    end

    -- Для входа в бой всегда используем анимацию (если включена настройка fadeAfterCombat)
    -- Это настройка для выхода из боя, но используем её и для входа
    local fadeEnabled = settings.textIndicatorsFadeAfterCombat
    local fadeTime = settings.textIndicatorsFadeTime or 0.4
    
    -- Устанавливаем флаг анимации только если включена анимация
    if fadeEnabled then
        animationFlags.textIndicators = true
    end

    -- Собираем все текстовые индикаторы
    local textIndicators = {}
    
    -- PlayerFrame
    if PlayerFrameHealthBarText then tinsert(textIndicators, PlayerFrameHealthBarText) end
    if PlayerFrameManaBarText then tinsert(textIndicators, PlayerFrameManaBarText) end
    
    -- TargetFrame
    if TargetFrameTextureFrameHealthBarText then tinsert(textIndicators, TargetFrameTextureFrameHealthBarText) end
    if TargetFrameTextureFrameManaBarText then tinsert(textIndicators, TargetFrameTextureFrameManaBarText) end
    
    -- PetFrame
    if PetFrameHealthBarText then tinsert(textIndicators, PetFrameHealthBarText) end
    if PetFrameManaBarText then tinsert(textIndicators, PetFrameManaBarText) end
    
    -- FocusFrame
    if FocusFrameHealthBarText then tinsert(textIndicators, FocusFrameHealthBarText) end
    if FocusFrameManaBarText then tinsert(textIndicators, FocusFrameManaBarText) end
    
    -- Обрабатываем все индикаторы
    for _, indicator in ipairs(textIndicators) do
        if indicator then
            if fadeEnabled then
                -- Убираем активные анимации перед началом новой
                if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(indicator) end
                -- Показываем фрейм и устанавливаем альфу в 0 перед анимацией
                indicator:Show()
                indicator:SetAlpha(0)
                -- жёстко анимируем вручную: никто не перебьёт
                AnimateAlpha(indicator, fadeTime, 0, 1)
                
                -- Сбрасываем флаг анимации
                C_Timer.After(fadeTime, function()
                    animationFlags.textIndicators = false
                end)
            else
                -- Резкое появление без анимации
                if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(indicator) end
                indicator:Show()
                indicator:SetAlpha(1)
            end
        end
    end
end

-- Универсальная функция для проверки состояния анимации
function CombatAnimations:IsAnimating(animationType)
    return animationFlags[animationType] or false
end

-- Универсальная функция для сброса флага анимации
function CombatAnimations:ResetAnimationFlag(animationType)
    animationFlags[animationType] = false
end

-- Регистрация событий боя.  Keep the same ordering used by the classic bars:
-- check UnitAffectingCombat immediately on entry (CircleL can emit a false
-- PLAYER_REGEN_DISABLED for a residual DoT), but defer the exit check by one
-- frame because the live unit flag can clear just after PLAYER_REGEN_ENABLED.
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Classic and Frost share this path.  CircleL may fire the event
        -- before lockdown; SetHotkeyCombatState still latches from the live
        -- unit flag so in-combat hotkeys stay visible without a target.
        CombatAnimations:FadeInHotkeys("PLAYER_REGEN_DISABLED")
        CombatAnimations:FadeInPageNumbers()
        -- Текстовые индикаторы управляются через module.lua
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Выход из боя - скрываем элементы
        local rawSettings = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
            and SarychUI.db.profile.modules.mainmenubar
        if rawSettings and rawSettings.enabled then
            local hotkeysFadeTime = rawSettings.hotkeysFadeAfterCombat and (rawSettings.hotkeysFadeTime or 0.4) or 0
            local delayFrame = CreateFrame("Frame")
            local delayElapsed = 0
            delayFrame:SetScript("OnUpdate", function(self, elapsed)
                delayElapsed = delayElapsed + elapsed
                if delayElapsed >= 0.01 then
                    CombatAnimations:FadeOutHotkeys(hotkeysFadeTime, "PLAYER_REGEN_ENABLED+0.01")
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end

        local mainmenubarSettings = GetModuleSettings("mainmenubar")
        if mainmenubarSettings and mainmenubarSettings.enabled then
            -- Номера страниц
            local pageNumbersFadeEnabled = mainmenubarSettings.pageNumbersFadeAfterCombat
            local pageNumbersFadeTime = mainmenubarSettings.pageNumbersFadeTime or 0.4
            
            if pageNumbersFadeEnabled then
                -- Создаем временный фрейм для задержки через OnUpdate
                local delayFrame = CreateFrame("Frame")
                local delayElapsed = 0
                delayFrame:SetScript("OnUpdate", function(self, elapsed)
                    delayElapsed = delayElapsed + elapsed
                    if delayElapsed >= 0.01 then
                        CombatAnimations:FadeOutPageNumbers(pageNumbersFadeTime)
                        self:SetScript("OnUpdate", nil)
                    end
                end)
            else
                CombatAnimations:FadeOutPageNumbers(0)
            end
        end
        -- Текстовые индикаторы управляются через module.lua
    end
end)

-- Экспортируем утилиту в глобальное пространство
SarychUI.CombatAnimations = CombatAnimations
