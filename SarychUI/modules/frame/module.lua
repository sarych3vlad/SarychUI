-- SarychUI Frame Module
-- Integrates former sarFrame behaviors under SarychUI framework

local select = select
local format = string.format

local moduleName = "frame"
local module = {}

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Embed Ace libraries
local AceEvent = LibStub("AceEvent-3.0")
local AceTimer = LibStub("AceTimer-3.0")
local AceHook = LibStub("AceHook-3.0")
local AceBucket = LibStub("AceBucket-3.0")

AceEvent:Embed(module)
AceTimer:Embed(module)
AceHook:Embed(module)
AceBucket:Embed(module)

-- Local references
local L = SarychUI.L

-- Local variables
local defaultPositions = {}
local customPositions = {}
local initialPositionsSet = false

-- Font settings
local percentFontSize = 10.5
local defaultFontPath, defaultFontHeight, defaultFontFlags = GameFontNormalSmall:GetFont()
local targetPercentOffsetX, targetPercentOffsetY = -8, 0
local focusPercentOffsetX, focusPercentOffsetY = -8, 0

-- LibSharedMedia for fonts
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Combat indicator variables
local CTT, CFT, CTP
local isRogue = select(2, UnitClass("player")) == "ROGUE"
-- Cache last positions to avoid unnecessary updates
local lastCombatIndicatorPositions = {
    target = { x = nil, y = nil },
    focus = { x = nil, y = nil },
    player = { x = nil, y = nil }
}

-- === ALT show/hide for HP/MP text (Blizzard-safe state machine) ===

-- Перечисляем бары для управления
local bars = {
    PlayerFrameHealthBar, PlayerFrameManaBar,
    TargetFrameHealthBar, TargetFrameManaBar,
    PetFrameHealthBar, PetFrameManaBar,
    FocusFrameHealthBar, FocusFrameManaBar,
}

-- Для надёжности: в некоторых билдах бары также доступны как поля frame.healthbar/manabar
local function NormalizeBars()
    if not PlayerFrameHealthBar and PlayerFrame and PlayerFrame.healthbar then
        PlayerFrameHealthBar = PlayerFrame.healthbar
    end
    if not PlayerFrameManaBar and PlayerFrame and PlayerFrame.manabar then
        PlayerFrameManaBar = PlayerFrame.manabar
    end
    if not TargetFrameHealthBar and TargetFrame and TargetFrame.healthbar then
        TargetFrameHealthBar = TargetFrame.healthbar
    end
    if not TargetFrameManaBar and TargetFrame and TargetFrame.manabar then
        TargetFrameManaBar = TargetFrame.manabar
    end
    if not PetFrameHealthBar and PetFrame and PetFrame.healthbar then
        PetFrameHealthBar = PetFrame.healthbar
    end
    if not PetFrameManaBar and PetFrame and PetFrame.manabar then
        PetFrameManaBar = PetFrame.manabar
    end
    if not FocusFrameHealthBar and FocusFrame and FocusFrame.healthbar then
        FocusFrameHealthBar = FocusFrame.healthbar
    end
    if not FocusFrameManaBar and FocusFrame and FocusFrame.manabar then
        FocusFrameManaBar = FocusFrame.manabar
    end
    -- Обновляем список баров после нормализации
    bars = {
        PlayerFrameHealthBar, PlayerFrameManaBar,
        TargetFrameHealthBar, TargetFrameManaBar,
        PetFrameHealthBar, PetFrameManaBar,
        FocusFrameHealthBar, FocusFrameManaBar,
    }
end

-- Состояния по каждому бару: bar -> {alt=false, hover=false, combat=false, shown=false}
local st = setmetatable({}, { __mode = "k" })

-- Helper function to get settings — always reads active profile (no cached db).
local function GetSetting(key, default)
    local db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
        or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
    if db and db[key] ~= nil then
        return db[key]
    end
    return default
end

local function SettingOn(key, default)
    local v = GetSetting(key, default)
    return v == 1 or v == true
end

local function GetPVPTimerElement()
    return _G["PlayerPVPTimerText"] or _G["PVPTimerText"] or _G["PlayerFramePVPTimerText"] or _G["PlayerFrameTextureFramePVPTimerText"]
end

local function GetPVPIconElements()
    return {
        { tex = _G["PlayerPVPIcon"] or _G["PlayerFramePVPIcon"], hideKey = "hidePlayerPVP" },
        { tex = _G["TargetFrameTextureFramePVPIcon"] or _G["TargetFramePVPIcon"], hideKey = "hideTargetPVP" },
        { tex = _G["FocusFrameTextureFramePVPIcon"] or _G["FocusFramePVPIcon"], hideKey = "hideFocusPVP" },
    }
end

-- Получение текстового элемента из бара
local function GetBarText(bar)
    if not bar then return nil end
    local barName = bar:GetName()
    if not barName then return nil end
    
    -- Маппинг баров на их текстовые элементы
    if bar == PlayerFrameHealthBar then
        return PlayerFrameHealthBarText
    elseif bar == PlayerFrameManaBar then
        return PlayerFrameManaBarText
    elseif bar == TargetFrameHealthBar then
        return TargetFrameTextureFrameHealthBarText
    elseif bar == TargetFrameManaBar then
        return TargetFrameTextureFrameManaBarText
    elseif bar == PetFrameHealthBar then
        return PetFrameHealthBarText
    elseif bar == PetFrameManaBar then
        return PetFrameManaBarText
    elseif bar == FocusFrameHealthBar then
        return FocusFrameHealthBarText
    elseif bar == FocusFrameManaBar then
        return FocusFrameManaBarText
    end
    return nil
end

local function want_visible(s)
    return s.alt or s.hover or s.combat
end

-- Универсальная функция анимации альфы
local function AnimateAlpha(frame, duration, fromA, toA)
    if not frame or not frame.SetAlpha then return end
    if duration <= 0 then
        frame:SetAlpha(toA or 1)
        return
    end

    -- Снимем любые системные фейды
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(frame)
    end

    frame:Show()
    frame:SetAlpha(fromA or 0)

    -- Используем встроенную анимацию WoW
    if UIFrameFadeIn and toA == 1 then
        UIFrameFadeIn(frame, duration, fromA or 0, toA or 1)
    elseif UIFrameFadeOut and toA == 0 then
        UIFrameFadeOut(frame, duration, fromA or 1, toA or 0)
    else
        frame:SetAlpha(toA or 1)
    end
end

local function apply(bar, useAnimation)
    if not bar then return end
    local s = st[bar]
    if not s then
        s = {alt=false, hover=false, combat=false, shown=false}
        st[bar] = s
    end
    local want = want_visible(s)
    local textElement = GetBarText(bar)
    
    -- Синхронизируем состояние: если хотим показать и не показано - показываем
    -- Если не хотим показать и показано - скрываем
    -- Это нужно, чтобы синхронизировать состояние при релоаде, когда CVars могут показывать текст
    if want and not s.shown then
        ShowTextStatusBarText(bar)
        if TextStatusBar_UpdateTextString then
            TextStatusBar_UpdateTextString(bar)
        end
        
        -- Плавное появление текста
        if textElement and useAnimation then
            local fadeEnabled = GetSetting('textIndicatorsFadeAfterCombat', false)
            local fadeTime = GetSetting('textIndicatorsFadeTime', 0.4) or 0.4
            if fadeEnabled and fadeTime > 0 then
                AnimateAlpha(textElement, fadeTime, 0, 1)
            else
                if textElement.SetAlpha then
                    textElement:SetAlpha(1)
                end
            end
        elseif textElement and textElement.SetAlpha then
            textElement:SetAlpha(1)
        end
        
        s.shown = true
    elseif not want then
        -- Если не хотим показать, всегда скрываем (даже если s.shown уже false)
        -- Это нужно для синхронизации при релоаде, когда CVars могут показывать текст
        if s.shown then
            HideTextStatusBarText(bar)
            if TextStatusBar_UpdateTextString then
                TextStatusBar_UpdateTextString(bar)
            end
        else
            -- Если текст уже скрыт в нашем состоянии, но виден из-за CVars, скрываем его явно
            -- Проверяем, виден ли текст через альфу текстового элемента
            if textElement and textElement.GetAlpha then
                local currentAlpha = textElement:GetAlpha() or 1
                if currentAlpha > 0 then
                    -- Текст виден из-за CVars, скрываем его
                    HideTextStatusBarText(bar)
                    if TextStatusBar_UpdateTextString then
                        TextStatusBar_UpdateTextString(bar)
                    end
                    if textElement.SetAlpha then
                        textElement:SetAlpha(0)
                    end
                end
            else
                -- Если нет текстового элемента, просто скрываем через API
                HideTextStatusBarText(bar)
                if TextStatusBar_UpdateTextString then
                    TextStatusBar_UpdateTextString(bar)
                end
            end
        end
        
        -- Плавное исчезновение текста (только если текст был показан)
        if s.shown and textElement and useAnimation then
            local fadeEnabled = GetSetting('textIndicatorsFadeAfterCombat', false)
            local fadeTime = GetSetting('textIndicatorsFadeTime', 0.4) or 0.4
            if fadeEnabled and fadeTime > 0 then
                local currentAlpha = textElement:GetAlpha() or 1
                AnimateAlpha(textElement, fadeTime, currentAlpha, 0)
            else
                if textElement.SetAlpha then
                    textElement:SetAlpha(0)
                end
            end
        elseif s.shown and textElement and textElement.SetAlpha then
            textElement:SetAlpha(0)
        end
        
        s.shown = false
    end
end

local function set_alt(bar, v)
    if not bar then return end
    local s = st[bar] or {}
    s.alt = v
    st[bar] = s
    apply(bar, false) -- Alt не использует анимацию
end

local function set_hover(bar, v)
    if not bar then return end
    local s = st[bar] or {}
    s.hover = v
    st[bar] = s
    apply(bar, false) -- Hover не использует анимацию
end

local function set_combat(bar, v)
    if not bar then return end
    local s = st[bar] or {}
    s.combat = v
    st[bar] = s
    apply(bar, true) -- Combat использует анимацию
end

-- Сохранённые оригинальные скрипты для восстановления
local saved = {}

-- Initialize module
function module:Initialize()
end

-- Enable module
function module:Enable()
    self.db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
        or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
    if not self.db or not self.db.enabled then return end

    -- Unregister vehicle events from PlayerFrame immediately
    -- This makes vehicle behave like pet, so PlayerFrame won't change position
    self:UnregisterVehicleEvents()
    
    -- Hook RegisterEvent to prevent Blizzard from re-registering vehicle events
    if PlayerFrame and not self:IsHooked(PlayerFrame, "RegisterEvent") then
        self:SecureHook(PlayerFrame, "RegisterEvent", function(frame, event)
            if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_ENTERING_VEHICLE" or 
               event == "UNIT_EXITING_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
                frame:UnregisterEvent(event)
            end
        end)
    end

    -- Register events using AceEvent
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")
    self:RegisterEvent("PLAYER_UNGHOST", "OnEvent")
    self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
    self:RegisterEvent("PLAYER_LOGIN", "OnEvent")
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE", "OnEvent")
    self:RegisterEvent("UNIT_MODEL_CHANGED", "OnEvent")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", "OnEvent")
    self:RegisterEvent("UNIT_EXITED_VEHICLE", "OnEvent")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnEvent")
    self:RegisterEvent("UNIT_FACTION", "OnEvent")
    self:RegisterEvent("PLAYER_FLAGS_CHANGED", "OnEvent")
    -- Use bucket events for frequent events to reduce load
    self:RegisterBucketEvent("UNIT_COMBAT", 0.1, "OnCombatUpdate")
    self:RegisterBucketEvent("UNIT_HEALTH", 0.2, "OnHealthUpdate")
    self:RegisterBucketEvent("UNIT_MAXHEALTH", 0.2, "OnHealthUpdate")
    
    -- Register Alt Mode callback for percent updates
    self:RegisterAltModeCallback()
    
    -- Normalize bars (ensure they exist)
    NormalizeBars()
    
    -- Сохраняем оригинальные обработчики тултипов и восстанавливаем их
    -- Это необходимо для показа тултипов при наведении на фреймы
    for _, fr in ipairs({PlayerFrame, TargetFrame, PetFrame, FocusFrame}) do
        if fr then
            saved[fr] = saved[fr] or {
                OnEnter = fr:GetScript("OnEnter"),
                OnLeave = fr:GetScript("OnLeave"),
            }
            -- Восстанавливаем обработчики тултипов
            -- Если оригинальный обработчик был сохранен, используем его
            -- Иначе используем стандартные функции UnitFrame_OnEnter/OnLeave
            if saved[fr].OnEnter then
                fr:SetScript("OnEnter", saved[fr].OnEnter)
            elseif UnitFrame_OnEnter then
                fr:SetScript("OnEnter", UnitFrame_OnEnter)
            end
            if saved[fr].OnLeave then
                fr:SetScript("OnLeave", saved[fr].OnLeave)
            elseif UnitFrame_OnLeave then
                fr:SetScript("OnLeave", UnitFrame_OnLeave)
            end
        end
    end
    
    -- Включаем свой «баровый» ховер
    local function WireBarHover(bar)
        if not bar then return end
        bar:EnableMouse(true)
        
        -- Функция для поиска родительского unit-фрейма
        local function FindUnitFrame(frame)
            if not frame then return nil end
            -- Проверяем текущий фрейм
            if frame.unit and (frame == PlayerFrame or frame == TargetFrame or frame == PetFrame or frame == FocusFrame) then
                return frame
            end
            -- Проверяем родителя
            local parent = frame:GetParent()
            if parent then
                if parent.unit and (parent == PlayerFrame or parent == TargetFrame or parent == PetFrame or parent == FocusFrame) then
                    return parent
                end
                -- Рекурсивно проверяем родителя родителя (на случай вложенности)
                return FindUnitFrame(parent)
            end
            return nil
        end
        
        bar:SetScript("OnEnter", function(self)
            -- Показываем текст HP/MP при наведении
            set_hover(self, true)
            -- Показываем тултип юнита
            local unitFrame = FindUnitFrame(self)
            if unitFrame and unitFrame.unit then
                -- Вызываем оригинальный обработчик тултипа для unit-фрейма
                if UnitFrame_OnEnter then
                    UnitFrame_OnEnter(unitFrame)
                elseif saved[unitFrame] and saved[unitFrame].OnEnter then
                    saved[unitFrame].OnEnter(unitFrame)
                end
            end
        end)
        bar:SetScript("OnLeave", function(self)
            -- Скрываем текст HP/MP при уходе мыши
            set_hover(self, false)
            -- Скрываем тултип юнита
            local unitFrame = FindUnitFrame(self)
            if unitFrame and unitFrame.unit then
                -- Вызываем оригинальный обработчик скрытия тултипа
                if UnitFrame_OnLeave then
                    UnitFrame_OnLeave()
                elseif saved[unitFrame] and saved[unitFrame].OnLeave then
                    saved[unitFrame].OnLeave()
                end
            end
        end)
    end
    
    for _, bar in ipairs(bars) do
        WireBarHover(bar)
    end
    
    -- Create text indicators first
    self:CreateTextIndicators()
    
    -- Регистрируем фреймы позиционирования для редактирования (если доступна утилита)
    if SarychUI.DragMode then
        self:RegisterPositionFrames()
    end
    
    -- Apply all frame modifications
    self:ApplyFramePositions()
    self:ApplyFrameScale()
    self:ApplyTextIndicators()
    self:ApplyVisualSettings()
    self:ApplyCombatIndicator()
    if self.Enable3DPortraitEvents then
        self:Enable3DPortraitEvents()
    end

    -- Pet name shortening runtime lives in tools; setting owned by this module.
    local toolsModule = SarychUI:GetModule("tools", true)
    if toolsModule and toolsModule.ApplyPetNameShortening then
        toolsModule:ApplyPetNameShortening()
    end
    
    -- Инициализируем текстовые индикаторы
    self:UpdateTextIndicators()
    
    -- Обновляем состояние боя для текстовых индикаторов
    self:UpdateCombatState()
    
    -- Синхронизируем состояние текстовых индикаторов при загрузке
    -- Это нужно, чтобы скрыть текст при релоаде, даже если CVars включены
    -- Применяем состояние для всех баров без анимации
    for _, bar in ipairs(bars) do
        if bar then
            apply(bar, false)
        end
    end
end

-- Disable module
function module:Disable()
    self._pvpHooksInstalled = false
    -- Unregister Alt Mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback(moduleName)
    end
    
    -- Unregister all events (AceEvent handles this automatically)
    self:UnregisterAllEvents()
    
    -- OnUpdate frames will continue to run but will hide indicators when disabled
    
    -- Unhook all hooks (AceHook handles this automatically)
    self:UnhookAll()
    
    -- Reset all frame modifications
    self:ResetFramePositions()
    self:ResetFrameScale()
    self:HideTextIndicators()
    self:ResetVisualSettings()
    self:HideCombatIndicator()
    if self.Disable3DPortraitEvents then
        self:Disable3DPortraitEvents()
    end

    -- Pet name shortening runtime lives in tools; setting owned by this module.
    local toolsModule = SarychUI:GetModule("tools", true)
    if toolsModule and toolsModule.DisablePetNameShortening then
        toolsModule:DisablePetNameShortening()
    end
    
    -- Отключаем drag mode для позиционирования
    if SarychUI.DragMode then
        if PlayerFrame then
            SarychUI.DragMode:EnableEditMode("playerFrame", false, false, false)
        end
        if TargetFrame then
            SarychUI.DragMode:EnableEditMode("targetFrame", false, false, false)
        end
        if FocusFrame then
            SarychUI.DragMode:EnableEditMode("focusFrame", false, false, false)
        end
        SarychUI.DragMode:ShowGrid(false)
    end
    
    for _, fr in ipairs({PlayerFrame, TargetFrame, PetFrame, FocusFrame}) do
        if fr and saved and saved[fr] then
            fr:SetScript("OnEnter", saved[fr].OnEnter)
            fr:SetScript("OnLeave", saved[fr].OnLeave)
        end
    end
    
    -- Снимаем свой hover с баров и сбрасываем состояния
    for _, bar in ipairs(bars) do
        if bar then
            bar:SetScript("OnEnter", nil)
            bar:SetScript("OnLeave", nil)
            -- снимаем все наши флаги и видимость
            st[bar] = {alt=false, hover=false, combat=false, shown=false}
            HideTextStatusBarText(bar)
            if TextStatusBar_UpdateTextString then
                TextStatusBar_UpdateTextString(bar)
            end
            -- Сбрасываем альфу текстового элемента
            local textElement = GetBarText(bar)
            if textElement and textElement.SetAlpha then
                textElement:SetAlpha(1) -- Возвращаем дефолтную альфу
            end
        end
    end
    
    -- Force reset all elements to ensure complete restoration
    self:ForceResetAllElements()
end

-- Refresh configuration
function module:RefreshConfig()
    if SarychUI.InvalidateModuleProfileCaches then
        SarychUI:InvalidateModuleProfileCaches()
    end
    if not SarychUI.db or not SarychUI.db.profile then return end
    self:Disable()
    self:Enable()
end

-- Alt Mode callback registration (only for percent updates)
function module:RegisterAltModeCallback()
    if SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback(moduleName, function(isAltPressed)
            self:OnAltStateChanged(isAltPressed)
        end)
    end
end

-- Helper function to get Alt state
local function IsAltPressed()
    if SarychUI and SarychUI.AltMode and SarychUI.AltMode.IsAltPressed then
        local v = SarychUI.AltMode:IsAltPressed()
        if v ~= nil then return v end
    end
    return IsAltKeyDown()
end

-- Alt state change handler (updates percents and HP/MP text via state machine)
function module:SyncBarAltFlags(pressed)
    if pressed == nil then
        pressed = IsAltPressed()
    end
    local showOnAlt = SettingOn("showOnAlt", 1)
    for _, bar in ipairs(bars) do
        set_alt(bar, showOnAlt and pressed)
    end
end

function module:OnAltStateChanged(pressed)
    self:SyncBarAltFlags(pressed)
    self:UpdateTextIndicators()
    self:HidePVPTimer()
end

-- Обновление состояния боя для всех баров
function module:UpdateCombatState()
    local showInCombat = GetSetting('showTextIndicatorsInCombat', false) == true
    local isInCombat = UnitAffectingCombat("player")
    for _, bar in ipairs(bars) do
        set_combat(bar, showInCombat and isInCombat)
    end
end

-- Обработчик входа в бой
function module:OnEnterCombat()
    local showInCombat = GetSetting('showTextIndicatorsInCombat', false)
    if showInCombat ~= true then return end
    
    -- Показываем все бары с плавной анимацией
    for _, bar in ipairs(bars) do
        set_combat(bar, true)
    end
end

-- Обработчик выхода из боя
function module:OnLeaveCombat()
    local showInCombat = GetSetting('showTextIndicatorsInCombat', false)
    if showInCombat ~= true then return end
    
    -- Скрываем все бары с плавной анимацией (если нет других флагов)
    for _, bar in ipairs(bars) do
        set_combat(bar, false)
    end
end

-- Apply settings (called from options)
function module:ApplySettings()
    self.db = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
        or (SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])
        or self.db
    if self.db and self.db.enabled then
        local sliderBusy = SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging()
        -- Сначала применяем позиции (это обновит фреймы при изменении слайдеров)
        self:ApplyFramePositions()
        -- During slider drag: only move frames. Re-running EnableEditMode recreates
        -- mouse-enabled drag chrome and steals LMB from the options slider.
        if not sliderBusy then
            self:ApplyPositionDragMode()
        end
        self:ApplyFrameScale()
        if not sliderBusy then
            self:ApplyTextIndicators()
            self:ApplyVisualSettings()
        end
        self:ApplyCombatIndicator()
        if not sliderBusy and self.Apply3DPortraits then
            self:Apply3DPortraits()
        end
    end
end


-- Event registration is now done directly in Enable() using AceEvent

-- Event handler
function module:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Сохраняем стандартные позиции при входе в мир
        self:SaveDefaultPositions()
        -- Применяем настройки позиций
        self:ApplyFramePositions()
        -- Инициализируем текстовые индикаторы
        self:UpdateTextIndicators()
        -- Принудительно обновляем отображение процентов
        self:ForceUpdateTargetPercentDisplay()
        -- Проверяем состояние боя при входе в мир
        self:UpdateCombatState()
        if self.Apply3DPortraits then
            self:Apply3DPortraits()
        end
        if self.SchedulePortraitRefresh then
            self:SchedulePortraitRefresh()
        end
        
        -- Синхронизируем состояние текстовых индикаторов при входе в мир
        -- Это нужно, чтобы скрыть текст при релоаде, даже если CVars включены
        for _, bar in ipairs(bars) do
            if bar then
                apply(bar, false)
            end
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" or event == "PLAYER_LOGIN" then
        -- Применяем настройки позиций при смене зоны, воскрешении и т.д.
        self:ApplyFramePositions()
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        local unit = ...
        if self.Update3DPortraits then
            if unit == "player" or unit == "target" or unit == "focus" then
                self:Update3DPortraits(true, unit)
            elseif unit and UnitIsUnit(unit, "player") then
                self:Update3DPortraits(true, "player")
            elseif unit and UnitExists("target") and UnitIsUnit(unit, "target") then
                self:Update3DPortraits(true, "target")
            elseif unit and UnitExists("focus") and UnitIsUnit(unit, "focus") then
                self:Update3DPortraits(true, "focus")
            end
        end
        -- Legacy: also re-apply frame positions on portrait update (was bundled before).
        if event == "UNIT_PORTRAIT_UPDATE" then
            self:ApplyFramePositions()
        end
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        self:HandleVehicleEvents()
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:OnTargetChanged()
    elseif event == "PLAYER_FOCUS_CHANGED" then
        self:OnFocusChanged()
    elseif event == "UNIT_FACTION" or event == "PLAYER_FLAGS_CHANGED" then
        self:HidePVPIcons()
        self:HidePVPTimer()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Вход в бой - показываем текстовые индикаторы
        self:OnEnterCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Выход из боя - скрываем текстовые индикаторы
        self:OnLeaveCombat()
    end
end

-- Bucket event handlers for frequent events
function module:OnCombatUpdate(units)
    -- OnUpdate scripts handle combat indicator updates automatically
end

function module:OnHealthUpdate(units)
    -- Update health bar percentages for target and focus
    if units then
        for unit in pairs(units) do
            if unit == "target" then
                self:UpdateHealthBarPercent(TargetFrameHealthBarPercent, "target")
                self:ForceUpdateTargetPercentDisplay()
            elseif unit == "focus" then
                self:UpdateHealthBarPercent(FocusFrameHealthBarPercent, "focus")
            end
        end
    end
end


-- Initialize frames
function module:InitializeFrames()
    self:SaveDefaultPositions()
    self:CreateTextIndicators()
    self:ApplyFramePositions()
    self:ApplyFrameScale()
    self:ApplyTextIndicators()
    self:ApplyVisualSettings()
    self:ApplyCombatIndicator()
    if self.Apply3DPortraits then
        self:Apply3DPortraits()
    end
end


-- Vehicle event handlers
function module:HandleVehicleEvents()
    -- Just keep vehicle events unregistered
    -- Vehicle events are unregistered at module initialization
    -- This makes vehicle behave like pet, so PlayerFrame won't change position
    self:UnregisterVehicleEvents()
end

function module:UnregisterVehicleEvents()
    if PlayerFrame then
        PlayerFrame:UnregisterEvent("UNIT_ENTERED_VEHICLE")
        PlayerFrame:UnregisterEvent("UNIT_ENTERING_VEHICLE")
        PlayerFrame:UnregisterEvent("UNIT_EXITING_VEHICLE")
        PlayerFrame:UnregisterEvent("UNIT_EXITED_VEHICLE")
    end
end

-- Frame positioning functions
function module:SaveDefaultPositions()
    if PlayerFrame and TargetFrame and FocusFrame and PetFrame then
        defaultPositions.PlayerFrame = { PlayerFrame:GetPoint() }
        defaultPositions.TargetFrame = { TargetFrame:GetPoint() }
        defaultPositions.FocusFrame = { FocusFrame:GetPoint() }
        defaultPositions.PetFrame = { PetFrame:GetPoint() }
        defaultPositions.PetFrameRelative = { PetFrame:GetPoint() }
    end
end

function module:ApplyFramePositions()
    -- Проверяем, включено ли изменение позиций
    if GetSetting('changePositions', 0) == 0 then
        -- Если настройка отключена, НЕ восстанавливаем близовские дефолтные позиции
        -- Фреймы остаются там, где они были (Blizzard сам управляет ими)
        -- Мы просто не управляем позициями, но не сбрасываем их
        return
    end
    
    -- Проверяем, не происходит ли сейчас drag - если да, не применяем позицию
    -- Это предотвращает перезапись позиции во время drag
    if SarychUI.DragMode then
        local playerData = SarychUI.DragMode:GetFrameData("playerFrame")
        local targetData = SarychUI.DragMode:GetFrameData("targetFrame")
        local focusData = SarychUI.DragMode:GetFrameData("focusFrame")
        
        -- Если фрейм только что был перемещен через drag или сейчас перемещается, не применяем позицию
        if (playerData and (playerData.justDragged or playerData.isMoving)) or
           (targetData and (targetData.justDragged or targetData.isMoving)) or
           (focusData and (focusData.justDragged or focusData.isMoving)) then
            return
        end
    end
    
    if PlayerFrame then
        PlayerFrame:ClearAllPoints()
        PlayerFrame:SetPoint("CENTER", UIParent, "CENTER", GetSetting('playerFrameX', -514), GetSetting('playerFrameY', 200))
    end
    
    if TargetFrame then
        TargetFrame:ClearAllPoints()
        TargetFrame:SetPoint("CENTER", UIParent, "CENTER", GetSetting('targetFrameX', -240), GetSetting('targetFrameY', 200))
    end
    
    if FocusFrame then
        FocusFrame:ClearAllPoints()
        FocusFrame:SetPoint("CENTER", UIParent, "CENTER", GetSetting('focusFrameX', 350), GetSetting('focusFrameY', -150))
    end
end

function module:ResetFramePositions()
    -- Восстанавливаем близовские дефолтные позиции
    if PlayerFrame then
        PlayerFrame:ClearAllPoints()
        PlayerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -19, -4)
    end
    
    if TargetFrame then
        TargetFrame:ClearAllPoints()
        TargetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -4)
    end
    
    if FocusFrame then
        FocusFrame:ClearAllPoints()
        FocusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -19, -4)
    end
end

-- Restore default frame positions (same as ResetFramePositions but with different name for clarity)
function module:RestoreDefaultFramePositions()
    if PlayerFrame and defaultPositions.PlayerFrame then
        PlayerFrame:ClearAllPoints()
        PlayerFrame:SetPoint(unpack(defaultPositions.PlayerFrame))
    end
    
    if TargetFrame and defaultPositions.TargetFrame then
        TargetFrame:ClearAllPoints()
        TargetFrame:SetPoint(unpack(defaultPositions.TargetFrame))
    end
    
    if FocusFrame and defaultPositions.FocusFrame then
        FocusFrame:ClearAllPoints()
        FocusFrame:SetPoint(unpack(defaultPositions.FocusFrame))
    end
end

-- Restore Blizzard default frame positions (hardcoded default positions)
function module:RestoreBlizzardDefaultPositions()
    -- Близовские дефолтные позиции фреймов
    if PlayerFrame then
        PlayerFrame:ClearAllPoints()
        PlayerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -19, -4)
    end
    
    if TargetFrame then
        TargetFrame:ClearAllPoints()
        TargetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -4)
    end
    
    if FocusFrame then
        FocusFrame:ClearAllPoints()
        FocusFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -19, -4)
    end
end

-- Frame scaling functions
function module:ApplyFrameScale()
    -- Проверяем, включено ли изменение масштаба
    if GetSetting('changeScale', 0) == 0 then
        -- Если настройка отключена, сбрасываем масштаб на 1.0
        if PlayerFrame then PlayerFrame:SetScale(1.0) end
        if TargetFrame then TargetFrame:SetScale(1.0) end
        if FocusFrame then FocusFrame:SetScale(1.0) end
        if PetFrame then PetFrame:SetScale(1.0) end
        return
    end
    
    local scale = GetSetting('frameScale', 1.0)
    if PlayerFrame then PlayerFrame:SetScale(scale) end
    if TargetFrame then TargetFrame:SetScale(scale) end
    if FocusFrame then FocusFrame:SetScale(scale) end
    if PetFrame then PetFrame:SetScale(scale) end
end

function module:ResetFrameScale()
    if PlayerFrame then PlayerFrame:SetScale(1.0) end
    if TargetFrame then TargetFrame:SetScale(1.0) end
    if FocusFrame then FocusFrame:SetScale(1.0) end
    if PetFrame then PetFrame:SetScale(1.0) end
end

-- Text indicators functions
function module:CreateTextIndicators()
    self:CreateTargetFrameTexts()
    self:CreateFocusFrameTexts()
end

function module:CreateTargetFrameTexts()
    if TargetFrame and TargetFrame.healthbar then
        if not TargetFrameHealthBarPercent then
            TargetFrameHealthBarPercent = TargetFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            TargetFrameHealthBarPercent:SetPoint("RIGHT", TargetFrame.healthbar, "LEFT", targetPercentOffsetX, targetPercentOffsetY)
            TargetFrameHealthBarPercent:SetJustifyH("RIGHT")
        end
        if TargetFrameHealthBarPercent then
            -- Use LibSharedMedia if available, otherwise use default font
            local fontPath = defaultFontPath
            if LSM and SarychUI.Media then
                local customFont = GetSetting('percentFont', nil)
                if customFont then
                    fontPath = SarychUI.Media:GetFont(customFont) or defaultFontPath
                end
            end
            TargetFrameHealthBarPercent:SetFont(fontPath, percentFontSize, defaultFontFlags)
        end
    end
end

function module:CreateFocusFrameTexts()
    if FocusFrame and FocusFrame.healthbar and FocusFrame.manabar then
        if not FocusFrameHealthBarText then
            FocusFrameHealthBarText = FocusFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            FocusFrameHealthBarText:SetPoint("CENTER", FocusFrame.healthbar, "CENTER", 0, 0)
        end
        if not FocusFrameManaBarText then
            FocusFrameManaBarText = FocusFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            FocusFrameManaBarText:SetPoint("CENTER", FocusFrame.manabar, "CENTER", 0, 0)
        end
        if not FocusFrameHealthBarPercent then
            FocusFrameHealthBarPercent = FocusFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            FocusFrameHealthBarPercent:SetPoint("RIGHT", FocusFrame.healthbar, "LEFT", focusPercentOffsetX, focusPercentOffsetY)
            FocusFrameHealthBarPercent:SetJustifyH("RIGHT")
        end
        if FocusFrameHealthBarPercent then
            -- Use LibSharedMedia if available, otherwise use default font
            local fontPath = defaultFontPath
            if LSM and SarychUI.Media then
                local customFont = GetSetting('percentFont', nil)
                if customFont then
                    fontPath = SarychUI.Media:GetFont(customFont) or defaultFontPath
                end
            end
            FocusFrameHealthBarPercent:SetFont(fontPath, percentFontSize, defaultFontFlags)
        end
    end
end

function module:ApplyTextIndicators()
    -- Update fonts if LibSharedMedia is available
    self:UpdateTextIndicatorFonts()
    self:SyncBarAltFlags()
    self:UpdateTextIndicators()
    -- Update combat state to show/hide text indicators in combat
    self:UpdateCombatState()
end

-- Update text indicator fonts using LibSharedMedia
function module:UpdateTextIndicatorFonts()
    if not LSM or not SarychUI.Media then return end
    
    local customFont = GetSetting('percentFont', nil)
    local fontPath = defaultFontPath
    if customFont then
        fontPath = SarychUI.Media:GetFont(customFont) or defaultFontPath
    end
    
    -- Update target frame percent font
    if TargetFrameHealthBarPercent then
        TargetFrameHealthBarPercent:SetFont(fontPath, percentFontSize, defaultFontFlags)
    end
    
    -- Update focus frame percent font
    if FocusFrameHealthBarPercent then
        FocusFrameHealthBarPercent:SetFont(fontPath, percentFontSize, defaultFontFlags)
    end
end

function module:UpdateTextIndicators()
    local pctOnAlt = SettingOn("showPercentagesOnAlt", 1)
    local isAltPressed = IsAltPressed()

    local function ShouldShowPercent(enabled)
        if not enabled then
            return false
        end
        if pctOnAlt then
            return isAltPressed
        end
        return true
    end

    if FocusFrameHealthBarPercent then
        if ShouldShowPercent(SettingOn("showFocusPercent", 1)) then
            FocusFrameHealthBarPercent:Show()
            self:UpdateHealthBarPercent(FocusFrameHealthBarPercent, "focus")
        else
            FocusFrameHealthBarPercent:Hide()
        end
    end

    self:ForceUpdateTargetPercentDisplay()
    self:HidePVPTimer()
end

function module:HideTextIndicators()
    if TargetFrameHealthBarPercent then TargetFrameHealthBarPercent:Hide() end
    if FocusFrameHealthBarPercent then FocusFrameHealthBarPercent:Hide() end
end

-- Функция для получения процента здоровья цели
function module:GetTargetHealthPercent()
    if UnitExists("target") then
        local health = UnitHealth("target")
        local maxHealth = UnitHealthMax("target")
        if maxHealth > 0 then
            return (health / maxHealth) * 100
        end
    end
    return 0
end


-- Функция для проверки класса игрока
local function GetPlayerClass()
    local _, playerClass = UnitClass("player")
    return playerClass
end

-- Функция для проверки, должен ли чернокнижник всегда показывать проценты
function module:ShouldWarlockAlwaysShowPercent()
	local playerClass = GetPlayerClass()
	if playerClass == "WARLOCK" then
		local warlockAlways = GetSetting('warlockAlways', 0) == 1
		if warlockAlways then
			local targetHealthPercent = self:GetTargetHealthPercent()
			local warlockThreshold = GetSetting('warlockThreshold', 25) or 25
			return targetHealthPercent <= warlockThreshold and targetHealthPercent >= 0.1
		end
	end
	return false
end

-- Общая функция для проверки, должен ли класс всегда показывать проценты
-- Только для чернокнижника
function module:ShouldClassAlwaysShowPercent()
	return self:ShouldWarlockAlwaysShowPercent()
end

-- Функция для принудительного обновления отображения процентов цели
function module:ForceUpdateTargetPercentDisplay()
    if not TargetFrameHealthBarPercent then return end
    local shouldShowTargetPercent = false
    local classAlwaysShow = self:ShouldClassAlwaysShowPercent()
    local isAltPressed = IsAltPressed()
    local pctOnAlt = SettingOn("showPercentagesOnAlt", 1)

    if classAlwaysShow then
        shouldShowTargetPercent = SettingOn("showTargetPercent", 1)
    elseif pctOnAlt then
        shouldShowTargetPercent = isAltPressed and SettingOn("showTargetPercent", 1)
    else
        shouldShowTargetPercent = SettingOn("showTargetPercent", 1)
    end

    if shouldShowTargetPercent then
        TargetFrameHealthBarPercent:Show()
        self:UpdateHealthBarPercent(TargetFrameHealthBarPercent, "target")
    else
        TargetFrameHealthBarPercent:Hide()
    end
end

function module:UpdateHealthBarPercent(frame, unit)
    if frame and unit then
        local health = UnitHealth(unit)
        local maxHealth = UnitHealthMax(unit)
        if maxHealth > 0 then
            local percent = (health / maxHealth) * 100
            -- Скрываем текст если процент меньше или равен 0.00 (мертвая цель)
            if percent <= 0.00 then
                frame:SetText("")
            else
                frame:SetText(format("%d%%", percent))
            end
        else
            frame:SetText("")
        end
    end
end

-- Функция для управления видимостью PVP-таймера
function module:SetPlayerPVPTimerTextVisibility(enable)
    self:HidePVPTimer()
end

function module:ApplyVisualSettings()
    self:EnsurePVPHooks()
    self:HidePVPIcons()
    self:HidePVPTimer()
    self:DisableHitIndicators()
end

function module:HidePVPIcons()
    local icons = GetPVPIconElements()
    for i = 1, #icons do
        local entry = icons[i]
        local tex = entry.tex
        if tex then
            if SettingOn(entry.hideKey, 0) then
                tex:SetAlpha(0)
            else
                tex:SetAlpha(1)
            end
        end
    end
end

function module:HidePVPTimer()
    local pvpTimerElement = GetPVPTimerElement()
    if not pvpTimerElement then return end
    if not SettingOn("hidePVPTimer", 1) then
        pvpTimerElement:SetAlpha(1)
        return
    end
    if SettingOn("pvpTimerOnAlt", 1) and IsAltPressed() then
        pvpTimerElement:SetAlpha(1)
    else
        pvpTimerElement:SetAlpha(0)
    end
end

function module:EnsurePVPHooks()
    if self._pvpHooksInstalled then return end
    self._pvpHooksInstalled = true
    local function reapply()
        if not self.db or not self.db.enabled then return end
        self:HidePVPIcons()
        self:HidePVPTimer()
    end
    local function hookShow(tex)
        if not tex or self:IsHooked(tex, "Show") then return end
        self:SecureHook(tex, "Show", reapply)
    end
    local icons = GetPVPIconElements()
    for i = 1, #icons do
        hookShow(icons[i].tex)
    end
    hookShow(GetPVPTimerElement())
    if _G.PlayerFrame_UpdatePvPStatus then
        self:SecureHook("PlayerFrame_UpdatePvPStatus", reapply)
    end
    if _G.PlayerFrame_UpdatePvP then
        self:SecureHook("PlayerFrame_UpdatePvP", reapply)
    end
    if _G.TargetFrame_CheckFaction then
        self:SecureHook("TargetFrame_CheckFaction", reapply)
    end
    if _G.FocusFrame_CheckFaction then
        self:SecureHook("FocusFrame_CheckFaction", reapply)
    end
end

function module:DisableHitIndicators()
    if GetSetting('hidePlayerHitIndicator', 0) == 1 and PlayerHitIndicator then
        PlayerHitIndicator:Hide()
        PlayerHitIndicator.Show = function() end
    elseif PlayerHitIndicator then
        PlayerHitIndicator.Show = nil
    end

    if GetSetting('hidePetHitIndicator', 0) == 1 and PetHitIndicator then
        PetHitIndicator:Hide()
        PetHitIndicator.Show = function() end
    elseif PetHitIndicator then
        PetHitIndicator.Show = nil
    end
end

function module:ResetVisualSettings()
    if PlayerPVPIcon then PlayerPVPIcon:SetAlpha(1) end
    if TargetFrameTextureFramePVPIcon then TargetFrameTextureFramePVPIcon:SetAlpha(1) end
    if FocusFrameTextureFramePVPIcon then FocusFrameTextureFramePVPIcon:SetAlpha(1) end
    
    if PlayerHitIndicator then PlayerHitIndicator.Show = nil end
    if PetHitIndicator then PetHitIndicator.Show = nil end
end

-- Base Blizzard combat icon size, scaled by combatIndicatorScale.
local function GetCombatIndicatorSize()
    local scale = tonumber(GetSetting('combatIndicatorScale', 0.85)) or 0.85
    local base = 32
    return base * scale, base * scale
end

local function UpdateCombatIndicatorScale(frame)
    if not frame then return end
    local w, h = GetCombatIndicatorSize()
    frame:SetSize(w, h)
end

function module:ApplyCombatIndicator()
    if GetSetting('enableCombatIndicator', 0) == 0 then 
        self:HideCombatIndicator()
        return 
    end
    
    -- Create indicators if they don't exist
    self:CreateCombatIndicators()
    
    -- Update scale of existing indicators without recreating
    if CTT then
        UpdateCombatIndicatorScale(CTT)
    end
    if CFT then
        UpdateCombatIndicatorScale(CFT)
    end
    if CTP then
        UpdateCombatIndicatorScale(CTP)
    end
    
    -- Update positions with forceUpdate=true to apply changes in real-time
    self:UpdateCombatIndicatorPositions(true)
end

-- Helper function to get combat icon offset with classification logic
local function GetCombatIconOffset(unit)
    local posX = GetSetting('combatIndicatorTargetX', 57)
    if unit == "player" then
        posX = GetSetting('combatIndicatorPlayerX', 33)
    elseif unit == "focus" then
        posX = GetSetting('combatIndicatorFocusX', 57)
    end
    
    if UnitExists(unit) then
        local classification = UnitClassification(unit)

        -- Смещение для всех элитных и редких мобов
        if classification == "elite" or classification == "rare" or classification == "rareelite" or classification == "worldboss" then
            posX = posX + GetSetting('combatIndicatorEliteOffset', 30)
        end

        -- Дополнительное смещение, если игрок разбойник и цель обычный моб
        if isRogue and classification == "normal" then
            posX = posX + GetSetting('combatIndicatorRogueOffset', 10)
        end
    end
    return posX
end

-- Create pulsing frame with animation using WoW's built-in animation system
local function CreatePulsingFrame(parentFrame, point, relativePoint, xOffset, yOffset)
    local frame = CreateFrame("Frame", nil, parentFrame)
    frame:SetPoint(point, parentFrame, relativePoint, xOffset, yOffset)
    
    local textureWidth, textureHeight = GetCombatIndicatorSize()
    frame:SetSize(textureWidth, textureHeight)
    frame:SetFrameLevel(parentFrame:GetFrameLevel() + 10)

    frame.t = frame:CreateTexture(nil, "BORDER")
    frame.t:SetAllPoints()
    frame.t:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    frame.t:SetTexCoord(0.5, 1.0, 0, 0.48)
    frame.t:Show()

    frame.glow = frame:CreateTexture(nil, "OVERLAY")
    frame.glow:SetAllPoints()
    frame.glow:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    frame.glow:SetTexCoord(0.5, 1.0, 0.5, 1.0)
    frame.glow:SetBlendMode("ADD")
    frame.glow:SetAlpha(0)

    -- Use WoW's built-in animation system instead of OnUpdate
    -- Create animation group on the glow texture itself
    local pulseGroup = frame.glow:CreateAnimationGroup()
    pulseGroup:SetLooping("REPEAT")
    
    local fadeIn = pulseGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.5)
    fadeIn:SetOrder(1)
    
    local fadeOut = pulseGroup:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.5)
    fadeOut:SetOrder(2)
    
    frame.pulseGroup = pulseGroup

    frame:SetScript("OnShow", function(self)
        if self.t then self.t:Show() end
        if self.pulseGroup then
            self.pulseGroup:Play()
        end
    end)
    
    frame:SetScript("OnHide", function(self)
        if self.t then self.t:Hide() end
        if self.pulseGroup then
            self.pulseGroup:Stop()
        end
        if self.glow then self.glow:SetAlpha(0) end
    end)

    -- Hide by default - will be shown only in combat
    frame:Hide()

    return frame
end

function module:CreateCombatIndicators()
    if GetSetting('enableCombatIndicator', 0) == 0 then return end
    
    -- Проверяем, что основные фреймы WoW готовы
    if not PlayerFrame or not TargetFrame or not FocusFrame then
        return
    end
    
    -- Создаем фреймы только если они еще не созданы
    if not CTT and TargetFrame then
        local posX = GetSetting('combatIndicatorTargetX', 57)
        local posY = GetSetting('combatIndicatorTargetY', 0)
        CTT = CreatePulsingFrame(TargetFrame, "CENTER", "CENTER", posX, posY)
    end
    
    if not CFT and FocusFrame then
        local posX = GetSetting('combatIndicatorFocusX', 57)
        local posY = GetSetting('combatIndicatorFocusY', 0)
        CFT = CreatePulsingFrame(FocusFrame, "CENTER", "CENTER", posX, posY)
    end
    
    if not CTP and PlayerFrame then
        local posX = GetSetting('combatIndicatorPlayerX', 33)
        local posY = GetSetting('combatIndicatorPlayerY', 38)
        CTP = CreatePulsingFrame(PlayerFrame, "CENTER", PlayerFrame, "CENTER", posX, posY)
        CTP:SetPoint("CENTER", PlayerFrame, "LEFT", posX-24, posY)
    end
end

-- Recreate combat indicators with new scale
function module:RecreateCombatIndicators()
    if GetSetting('enableCombatIndicator', 0) == 0 then return end
    
    -- Удаляем старые фреймы
    if CTT then
        CTT:Hide()
        CTT = nil
    end
    if CFT then
        CFT:Hide()
        CFT = nil
    end
    if CTP then
        CTP:Hide()
        CTP = nil
    end
    
    -- Создаем новые с новым масштабом
    self:CreateCombatIndicators()
end

-- Update icon position with classification logic (only if position changed)
local function UpdateIconPosition(frame, unit)
    if not frame then return end
    
    local xOffset = GetCombatIconOffset(unit)
    local posY = GetSetting('combatIndicatorTargetY', 0)
    if unit == "player" then
        posY = GetSetting('combatIndicatorPlayerY', 38)
    elseif unit == "focus" then
        posY = GetSetting('combatIndicatorFocusY', 0)
    end
    
    -- Check if position actually changed
    local lastPos = lastCombatIndicatorPositions[unit]
    if lastPos and lastPos.x == xOffset and lastPos.y == posY then
        return -- Position hasn't changed, skip update
    end
    
    -- Update cached position
    lastCombatIndicatorPositions[unit] = { x = xOffset, y = posY }
    
    if unit == "target" then
        frame:SetPoint("CENTER", TargetFramePortrait, "CENTER", xOffset, posY)
    elseif unit == "focus" then
        frame:SetPoint("CENTER", FocusFramePortrait, "CENTER", xOffset, posY)
    end
end

function module:UpdateCombatIndicatorPositions(forceUpdate)
    if GetSetting('enableCombatIndicator', 0) == 0 then
        self:HideCombatIndicator()
        -- Clear cached positions
        lastCombatIndicatorPositions.target = { x = nil, y = nil }
        lastCombatIndicatorPositions.focus = { x = nil, y = nil }
        lastCombatIndicatorPositions.player = { x = nil, y = nil }
        return
    end
    
    -- Only create indicators if they don't exist
    self:CreateCombatIndicators()
    
    -- If forceUpdate is true, clear cache to force position update
    if forceUpdate then
        lastCombatIndicatorPositions.target = { x = nil, y = nil }
        lastCombatIndicatorPositions.focus = { x = nil, y = nil }
        lastCombatIndicatorPositions.player = { x = nil, y = nil }
    end
    
    -- Update positions (will update if changed or if forceUpdate)
    if CTT then
        UpdateIconPosition(CTT, "target")
    end
    if CFT then
        UpdateIconPosition(CFT, "focus")
    end
    if CTP then
        local posX = GetSetting('combatIndicatorPlayerX', 33)
        local posY = GetSetting('combatIndicatorPlayerY', 38)
        local lastPos = lastCombatIndicatorPositions.player
        -- Update if position changed or if forceUpdate
        if forceUpdate or not lastPos or lastPos.x ~= posX or lastPos.y ~= posY then
            lastCombatIndicatorPositions.player = { x = posX, y = posY }
            CTP:SetPoint("CENTER", PlayerFrame, "LEFT", posX-24, posY)
        end
    end
end

local function SetIndicatorShown(frame, shouldShow)
    if shouldShow then
        if not frame:IsVisible() then
            frame:Show()
        end
    elseif frame:IsVisible() then
        frame:Hide()
    end
end

-- One driver for all three combat indicators. Previously each ran its own
-- per-frame handler and resolved the enable setting separately, which cost three
-- DB walks every frame; here the setting is read once per tick and the unit checks
-- are skipped entirely while the feature is off.
local COMBAT_INDICATOR_INTERVAL = 0.05

local combatIndicatorDriver = CreateFrame("Frame")
combatIndicatorDriver.elapsed = 0
combatIndicatorDriver:SetScript("OnUpdate", function(self, dt)
    local acc = self.elapsed + (dt or 0)
    if acc < COMBAT_INDICATOR_INTERVAL then
        self.elapsed = acc
        return
    end
    self.elapsed = 0

    local enabled = GetSetting('enableCombatIndicator', 0) == 1

    if CTT then
        SetIndicatorShown(CTT, enabled and UnitAffectingCombat("target") and true or false)
    end
    if CFT then
        SetIndicatorShown(CFT, enabled and UnitAffectingCombat("focus") and true or false)
    end
    if CTP then
        SetIndicatorShown(CTP, enabled and UnitAffectingCombat("player") and IsResting() and true or false)
    end
end)

function module:HideCombatIndicator()
    if CTT then CTT:Hide() end
    if CFT then CFT:Hide() end
    if CTP then CTP:Hide() end
end

-- Target changed handler
function module:OnTargetChanged()
    -- Reset cached position for target (classification may have changed)
    lastCombatIndicatorPositions.target = { x = nil, y = nil }
    if CTT and GetSetting('enableCombatIndicator', 0) == 1 then
        UpdateIconPosition(CTT, "target")
    end
    -- Обновляем видимость индикаторов боя (проверяет UnitAffectingCombat для новой цели)
    -- OnUpdate скрипт автоматически обновит видимость
    self:UpdateHealthBarPercent(TargetFrameHealthBarPercent, "target")
    self:ForceUpdateTargetPercentDisplay()
    if self.Update3DPortraits then
        self:Update3DPortraits(true, "target")
    end
    
    -- Сбрасываем состояние hover для баров цели при смене цели
    if TargetFrameHealthBar then
        set_hover(TargetFrameHealthBar, false)
    end
    if TargetFrameManaBar then
        set_hover(TargetFrameManaBar, false)
    end
    self:HidePVPIcons()
    self:HidePVPTimer()
end

-- Focus changed handler
function module:OnFocusChanged()
    -- Reset cached position for focus (classification may have changed)
    lastCombatIndicatorPositions.focus = { x = nil, y = nil }
    if CFT and GetSetting('enableCombatIndicator', 0) == 1 then
        UpdateIconPosition(CFT, "focus")
    end
    -- Обновляем видимость индикаторов боя (проверяет UnitAffectingCombat для нового фокуса)
    -- OnUpdate скрипт автоматически обновит видимость
    self:UpdateHealthBarPercent(FocusFrameHealthBarPercent, "focus")
    if self.Update3DPortraits then
        self:Update3DPortraits(true, "focus")
    end
    self:HidePVPIcons()
    self:HidePVPTimer()
end

-- Force reset all elements to ensure complete restoration
function module:ForceResetAllElements()
    -- Reset PVP timer visibility
    if PlayerPVPTimerText then
        PlayerPVPTimerText:SetAlpha(1)
    end
    
    -- Force update all text status bars
    if TextStatusBar_UpdateTextString then
        if PlayerFrameHealthBar then TextStatusBar_UpdateTextString(PlayerFrameHealthBar) end
        if PlayerFrameManaBar then TextStatusBar_UpdateTextString(PlayerFrameManaBar) end
        if TargetFrameHealthBar then TextStatusBar_UpdateTextString(TargetFrameHealthBar) end
        if TargetFrameManaBar then TextStatusBar_UpdateTextString(TargetFrameManaBar) end
        if PetFrameHealthBar then TextStatusBar_UpdateTextString(PetFrameHealthBar) end
        if PetFrameManaBar then TextStatusBar_UpdateTextString(PetFrameManaBar) end
    end
    
    
    -- Reset PVP icons
    if PlayerPVPIcon then PlayerPVPIcon:SetAlpha(1) end
    if TargetFrameTextureFramePVPIcon then TargetFrameTextureFramePVPIcon:SetAlpha(1) end
    if FocusFrameTextureFramePVPIcon then FocusFrameTextureFramePVPIcon:SetAlpha(1) end
    
    -- Reset hit indicators
    if PlayerHitIndicator then PlayerHitIndicator.Show = nil end
    if PetHitIndicator then PetHitIndicator.Show = nil end
end

-- Register position frames for drag mode
function module:RegisterPositionFrames()
    if not SarychUI.DragMode then return end

    local function FrameGetPoint(frameId, xKey, yKey, defX, defY)
        return function()
            local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
            if panel and panel.IsOpen and panel:IsOpen()
                and panel.GetFrameId and panel:GetFrameId() == frameId
                and panel.GetDraft then
                local dx, dy = panel:GetDraft()
                if dx ~= nil and dy ~= nil then
                    return { "CENTER", UIParent, "CENTER", dx, dy }
                end
            end
            return {
                "CENTER",
                UIParent,
                "CENTER",
                GetSetting(xKey, defX),
                GetSetting(yKey, defY),
            }
        end
    end

    local function FrameOnPositionChanged(frameId, xKey, yKey, point, relativePoint, xOfs, yOfs)
        local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
        if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
            if panel:OnDragPosition(frameId, xOfs, yOfs, point, relativePoint) then
                return
            end
        end
        local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
            and SarychUI.db.profile.modules[moduleName]
        if not db then return end
        db[xKey] = xOfs
        db[yKey] = yOfs
        if SarychUI.SyncOpenOptionsValues then
            SarychUI:SyncOpenOptionsValues()
        end
    end
    
    -- Register PlayerFrame
    if PlayerFrame then
        SarychUI.DragMode:RegisterFrame("playerFrame", PlayerFrame, {
            dragPoint = "CENTER",
            dragOffsetX = 0,
            dragOffsetY = 0,
            dragWidth = 200,
            dragHeight = 100,
            dragText = "Игрок",
            interceptSetPoint = false,
            getPoint = FrameGetPoint("playerFrame", "playerFrameX", "playerFrameY", -514, 200),
            onPositionChanged = function(point, relativePoint, xOfs, yOfs)
                FrameOnPositionChanged("playerFrame", "playerFrameX", "playerFrameY", point, relativePoint, xOfs, yOfs)
            end
        })
    end
    
    -- Register TargetFrame
    if TargetFrame then
        SarychUI.DragMode:RegisterFrame("targetFrame", TargetFrame, {
            dragPoint = "CENTER",
            dragOffsetX = 0,
            dragOffsetY = 0,
            dragWidth = 200,
            dragHeight = 100,
            dragText = "Цель",
            interceptSetPoint = false,
            getPoint = FrameGetPoint("targetFrame", "targetFrameX", "targetFrameY", -240, 200),
            onPositionChanged = function(point, relativePoint, xOfs, yOfs)
                FrameOnPositionChanged("targetFrame", "targetFrameX", "targetFrameY", point, relativePoint, xOfs, yOfs)
            end
        })
    end
    
    -- Register FocusFrame
    if FocusFrame then
        SarychUI.DragMode:RegisterFrame("focusFrame", FocusFrame, {
            dragPoint = "CENTER",
            dragOffsetX = 0,
            dragOffsetY = 0,
            dragWidth = 200,
            dragHeight = 100,
            dragText = "Фокус",
            interceptSetPoint = false,
            getPoint = FrameGetPoint("focusFrame", "focusFrameX", "focusFrameY", 350, -150),
            onPositionChanged = function(point, relativePoint, xOfs, yOfs)
                FrameOnPositionChanged("focusFrame", "focusFrameX", "focusFrameY", point, relativePoint, xOfs, yOfs)
            end
        })
    end
end

-- Apply position drag mode settings
function module:ApplyPositionDragMode()
    if not SarychUI.DragMode then return end
    
    -- Проверяем, включено ли изменение позиций
    if GetSetting('changePositions', 0) == 0 then
        -- Do not overwrite DB from GetPoint here — after free-move anchors can
        -- disagree with slider CENTER offsets and would desync /sui.
        if PlayerFrame then
            SarychUI.DragMode:EnableEditMode("playerFrame", false, false, false)
        end
        if TargetFrame then
            SarychUI.DragMode:EnableEditMode("targetFrame", false, false, false)
        end
        if FocusFrame then
            SarychUI.DragMode:EnableEditMode("focusFrame", false, false, false)
        end
        SarychUI.DragMode:ShowGrid(false)
        return
    end
    
    local showPlayer = GetSetting('showPlayerDragFrame', 0) == 1
        or GetSetting('showPositionDragFrame', 0) == 1
    local showTarget = GetSetting('showTargetDragFrame', 0) == 1
        or GetSetting('showPositionDragFrame', 0) == 1
    local showFocus = GetSetting('showFocusDragFrame', 0) == 1
        or GetSetting('showPositionDragFrame', 0) == 1
    local showGrid = GetSetting('showPositionGrid', 0) == 1
        or showPlayer or showTarget or showFocus
    
    if PlayerFrame then
        SarychUI.DragMode:EnableEditMode("playerFrame", true, showPlayer, showGrid)
    end
    if TargetFrame then
        SarychUI.DragMode:EnableEditMode("targetFrame", true, showTarget, showGrid)
    end
    if FocusFrame then
        SarychUI.DragMode:EnableEditMode("focusFrame", true, showFocus, showGrid)
    end
    
    SarychUI.DragMode:ShowGrid(showGrid)
end

-- Export options hook (populated in options.lua)
function module:GetOptions()
    return {}
end