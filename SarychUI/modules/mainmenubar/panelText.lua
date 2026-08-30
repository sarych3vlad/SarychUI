-- SarychUI MainMenuBar Panel Text Module
-- Text functions for hotkeys and macro names

local moduleName = "mainmenubar"

-- Get or create module reference
local function getModule()
    if SarychUI.modules and SarychUI.modules[moduleName] then
        return SarychUI.modules[moduleName]
    end
    -- If module doesn't exist yet, create a temporary one
    if not SarychUI.modules then
        SarychUI.modules = {}
    end
    if not SarychUI.modules[moduleName] then
        SarychUI.modules[moduleName] = {}
    end
    return SarychUI.modules[moduleName]
end

local module = getModule()

-- Animation control now handled by SarychUI.CombatAnimations

local BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomRightButton",
    "MultiBarBottomLeftButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "BonusActionButton",
}

-- The 72 hotkey FontStrings never change identity, so the name concatenation and
-- _G lookups are done once instead of on every hotkey pass.
local hotkeyRegions
local function GetHotkeyRegions()
    if hotkeyRegions then return hotkeyRegions end
    hotkeyRegions = {}
    for p = 1, #BAR_PREFIXES do
        local prefix = BAR_PREFIXES[p]
        for i = 1, 12 do
            local region = _G[prefix .. i .. "HotKey"]
            if region then
                hotkeyRegions[#hotkeyRegions + 1] = region
            end
        end
    end
    return hotkeyRegions
end

-- Alpha the hotkeys should have right now, or nil when the current alpha must be
-- left alone (combat/Alt/target overrides and fade animations own it then).
function module:GetHotkeyTargetAlpha()
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end

    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then
        return nil
    end

    if not currentDb.hideHotkeysEnabled then
        return 1
    end

    -- Combat takes priority over Alt.
    if UnitAffectingCombat("player") and currentDb.showHotkeysInCombat then
        return nil
    end

    if SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() and currentDb.showHotkeysOnAlt then
        return nil
    end

    if currentDb.showHotkeysWithTarget and UnitExists("target") then
        return nil
    end

    return 0
end

-- Applies the current hotkey alpha to a single button.
function module:ApplyHotkeyAlpha(button)
    if not button then return end

    local hotkey = button.__sarHotKey
    if hotkey == nil then
        local name = button.GetName and button:GetName()
        hotkey = name and _G[name .. "HotKey"] or false
        button.__sarHotKey = hotkey
    end
    if not hotkey then return end

    local alpha = self:GetHotkeyTargetAlpha()
    if alpha == nil then return end
    hotkey:SetAlpha(alpha)
end

-- Initialize text system
function module:InitializeTextSystem()
    -- Hooks are permanent; re-running Initialize must not stack another copy.
    if not module.__sarTextHooked then
        module.__sarTextHooked = true
        hooksecurefunc("ActionButton_Update", function(button)
            if SarychUI.modules and SarychUI.modules.mainmenubar and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.mainmenubar and SarychUI.db.profile.modules.mainmenubar.enabled then
                module:ApplyHotkeyAlpha(button)
                if module.UpdateMacroNames then module:UpdateMacroNames(button) end
            end
        end)
    end
    
    -- Combat events will be registered at the end of file
    
    -- Apply initial settings
    if module.HideHotkeys then module:HideHotkeys() end
    
    -- Apply initial settings to all buttons
    for i = 1, 12 do
        local buttons = {
            _G["ActionButton" .. i],
            _G["MultiBarBottomRightButton" .. i],
            _G["MultiBarBottomLeftButton" .. i],
            _G["MultiBarRightButton" .. i],
            _G["MultiBarLeftButton" .. i],
            _G["BonusActionButton" .. i]
        }
        
        for _, button in ipairs(buttons) do
            if button and module.UpdateMacroNames then
                module:UpdateMacroNames(button)
            end
        end
    end
end

-- Update all hotkeys (for real-time settings changes)
function module:UpdateAllHotkeys()
    -- Get fresh db reference
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then 
        return 
    end
    
    local regions = GetHotkeyRegions()
    
    -- Check if hide hotkeys is enabled
    local hideHotkeysEnabled = currentDb.hideHotkeysEnabled
    if not hideHotkeysEnabled then
        -- Show all hotkeys
        for i = 1, #regions do
            regions[i]:SetAlpha(1)
        end
        return
    end
    
    -- Check combat and Alt state
    local showHotkeysInCombat = currentDb.showHotkeysInCombat
    local showHotkeysOnAlt = currentDb.showHotkeysOnAlt
    local showHotkeysWithTarget = currentDb.showHotkeysWithTarget
    local isInCombat = UnitAffectingCombat("player")
    local isAltPressed = SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()
    local hasTarget = UnitExists("target")
    
    -- Determine if hotkeys should be shown
    -- В бою: показывать только если showHotkeysInCombat включено (Alt НЕ влияет)
    -- Вне боя: показывать если Alt нажат И showHotkeysOnAlt включено
    -- С целью: показывать если включено и есть target (вместе с боем/Alt по ИЛИ)
    local shouldShow = (isInCombat and showHotkeysInCombat)
        or (not isInCombat and isAltPressed and showHotkeysOnAlt)
        or (showHotkeysWithTarget and hasTarget)
    
    local alpha = shouldShow and 1 or 0
    for i = 1, #regions do
        regions[i]:SetAlpha(alpha)
    end
end

-- Update all macro names (for real-time settings changes)
function module:UpdateAllMacroNames()
    -- Get fresh db reference
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then 
        return 
    end
    
    local hideMacroNames = currentDb.hideMacroNames
    
    for i = 1, 12 do
        local buttons = {
            _G["ActionButton" .. i],
            _G["MultiBarBottomRightButton" .. i],
            _G["MultiBarBottomLeftButton" .. i],
            _G["MultiBarRightButton" .. i],
            _G["MultiBarLeftButton" .. i],
            _G["BonusActionButton" .. i]
        }
        
        for _, button in ipairs(buttons) do
            if button then
                local macroName = _G[button:GetName() .. "Name"]
                if macroName then
                    if hideMacroNames then
                        macroName:Hide()
                    else
                        macroName:Show()
                    end
                end
            end
        end
    end
end

-- === UNIVERSAL ALPHA ANIMATOR (manual, uninterruptible) ===
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
    
    -- Сбрасываем флаг анимации для хоткеев и номера страницы
    if toA == 1 and frame:GetName() and (frame:GetName():find("HotKey") or frame:GetName():find("PageNumber")) then
        C_Timer.After(duration, function()
            isFadingInHotkeys = false
        end)
    end
end

-- Applies the current hotkey alpha to every action button.
function module:HideHotkeys()
    local alpha = self:GetHotkeyTargetAlpha()
    if alpha == nil then return end

    local regions = GetHotkeyRegions()
    for i = 1, #regions do
        regions[i]:SetAlpha(alpha)
    end
end

-- Show hotkeys function (EXACT COPY from original)
function module:ShowHotkeys()
    -- Не перебиваем анимацию появления
    if isFadingInHotkeys then return end
    
    -- Get fresh db reference
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then 
        return 
    end
    
    -- Проверяем настройку: включено ли скрытие горячих клавиш
    local hideHotkeysEnabled = currentDb.hideHotkeysEnabled
    if not hideHotkeysEnabled then
        -- Если отключено, показываем горячие клавиши (они должны быть видны)
        for i = 1, 12 do
            _G["ActionButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarBottomRightButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarBottomLeftButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarRightButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarLeftButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["BonusActionButton" .. i .. "HotKey"]:SetAlpha(1)
        end
        return
    end
    
    -- Проверяем иерархию настроек
    local showHotkeysInCombat = currentDb.showHotkeysInCombat
    local showHotkeysOnAlt = currentDb.showHotkeysOnAlt
    local showHotkeysWithTarget = currentDb.showHotkeysWithTarget
    local isInCombat = UnitAffectingCombat("player")
    local isAltPressed = SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()
    
    -- Показываем хоткеи только если:
    -- 1. "Скрыть хоткеи" включено И
    -- 2. (В бою И включена опция "Показывать во время боя") ИЛИ (НЕ в бою И нажат Alt И включена опция "Показывать при нажатии Alt")
    --    ИЛИ (включён показ с целью и есть target)
    -- В бою Alt НЕ должен влиять на видимость
    local shouldShow = (isInCombat and showHotkeysInCombat)
        or (not isInCombat and isAltPressed and showHotkeysOnAlt)
        or (showHotkeysWithTarget and UnitExists("target"))
    if hideHotkeysEnabled and shouldShow then
        for i = 1, 12 do
            _G["ActionButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarBottomRightButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarBottomLeftButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarRightButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarLeftButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["BonusActionButton" .. i .. "HotKey"]:SetAlpha(1)
        end
    end
end

-- Fade out hotkeys function (delegated to CombatAnimations)
function module:FadeOutHotkeys(fadeTime)
    if SarychUI.CombatAnimations then
        SarychUI.CombatAnimations:FadeOutHotkeys(fadeTime)
    end
end

-- Fade in hotkeys function (delegated to CombatAnimations)
function module:FadeInHotkeys()
    if SarychUI.CombatAnimations then
        SarychUI.CombatAnimations:FadeInHotkeys()
    end
end

-- Update macro names for a specific button
function module:UpdateMacroNames(button)
    -- Get fresh db reference
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then 
        return 
    end
    
    local hideMacroNames = currentDb.hideMacroNames
    if not hideMacroNames then
        return
    end
    
    local macroName = _G[button:GetName() .. "Name"]
    if macroName then
        macroName:Hide()
    end
end

-- Show all hotkeys (used when disabling module)
function module:ShowAllHotkeys()
    for i = 1, 12 do
        local hotkeys = {
            _G["ActionButton" .. i .. "HotKey"],
            _G["MultiBarBottomRightButton" .. i .. "HotKey"],
            _G["MultiBarBottomLeftButton" .. i .. "HotKey"],
            _G["MultiBarRightButton" .. i .. "HotKey"],
            _G["MultiBarLeftButton" .. i .. "HotKey"],
            _G["BonusActionButton" .. i .. "HotKey"]
        }
        
        for _, hotkey in ipairs(hotkeys) do
            if hotkey then
                hotkey:SetAlpha(1)
                hotkey:Show()
            end
        end
    end
end

-- Show all macro names (used when disabling module)
function module:ShowAllMacroNames()
    for i = 1, 12 do
        local macroNames = {
            _G["ActionButton" .. i .. "Name"],
            _G["MultiBarBottomRightButton" .. i .. "Name"],
            _G["MultiBarBottomLeftButton" .. i .. "Name"],
            _G["MultiBarRightButton" .. i .. "Name"],
            _G["MultiBarLeftButton" .. i .. "Name"],
            _G["BonusActionButton" .. i .. "Name"]
        }
        
        for _, macroName in ipairs(macroNames) do
            if macroName then
                macroName:Show()
            end
        end
    end
end

-- Combat events now handled by SarychUI.CombatAnimations

