-- SarychUI MainMenuBar Panel Visual Module
-- Visual appearance functions for main menu bar

local tinsert = table.insert

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

-- Подключаем AceTimer для throttling OnUpdate скриптов (оптимизация производительности)
local AceTimer = LibStub("AceTimer-3.0", true)

-- Debug flag for bar visibility diagnostics (set to true to enable prints)
local DEBUG_BARS = false

local function BarsDebug(...)
    if DEBUG_BARS then
        local prefix = (SarychUI and SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("Bars")) or "|cffffd200SarychUI Bars:|r"
        print(prefix, ...)
    end
end

-- Helper function to get settings (must be defined before bar layout helpers)
local function GetSetting(key, default)
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return default
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb then
        return default
    end
    
    local v = currentDb[key]
    if v == nil then
        return default
    end
    return v
end

local MAX_LEVEL = tonumber(MAX_PLAYER_LEVEL) or 80
local POSSESS_SLOTS = tonumber(NUM_POSSESS_SLOTS) or 2

local function SafeForLimit(value, fallback)
    local n = tonumber(value)
    if n and n >= 0 then
        return math.floor(n)
    end
    return fallback or 0
end

local function GetNumShapeshiftFormsSafe()
    if type(GetNumShapeshiftForms) == "function" then
        return SafeForLimit(GetNumShapeshiftForms(), 0)
    end
    return 0
end

local function IsXPDisabled()
    if type(IsXPUserDisabled) == "function" then
        return IsXPUserDisabled()
    end
    return false
end

local function IsBelowMaxLevel()
    return UnitLevel("player") < MAX_LEVEL
end

local function GetBoolSetting(key, default)
    local value = GetSetting(key, default)
    if value == true or value == 1 or value == "1" or value == "true" then
        return true
    end
    if value == false or value == 0 or value == "0" or value == "false" then
        return false
    end
    return default and true or false
end

-- Флаг для отслеживания анимации XP Bar
local isXPBarAnimating = false
local xpBarAnimationFrame = nil
local xpBarFadeState = nil -- "fadeIn", "visible", "fadeOut"
local xpBarFadeStartTime = nil
local xpBarLastUpdateTime = nil
local xpBarFadeTime = 0.4
local xpBarShowTime = 1.1

-- Флаг для отслеживания анимации Reputation Bar
local isRepBarAnimating = false
local repBarAnimationFrame = nil
local repBarFadeState = nil
local repBarFadeStartTime = nil
local repBarFadeTime = 0.4
local repBarShowTime = 1.1
local lastRepTriggerTime = 0
local REP_TRIGGER_DEBOUNCE = 0.2
local isRepBarTemporarilyVisible = false
local blizzardRepBarHooked = false
local isUpdatingBarsLayout = false
local repGainSuppressUntil = 0
local watchedFactionSnapshot = nil

local function GetWatchedFactionSnapshot()
    local name, standing, min, max, value = GetWatchedFactionInfo()
    if not name then
        return nil
    end
    return { name = name, standing = standing, min = min, max = max, value = value }
end

local function CommitWatchedFactionSnapshot()
    watchedFactionSnapshot = GetWatchedFactionSnapshot()
    module.watchedFactionSnapshot = watchedFactionSnapshot
end

local function HasWatchedFactionValueChanged()
    local newSnapshot = GetWatchedFactionSnapshot()
    if not newSnapshot then
        return false
    end
    if not watchedFactionSnapshot or watchedFactionSnapshot.name ~= newSnapshot.name then
        return true
    end
    return watchedFactionSnapshot.value ~= newSnapshot.value
        or watchedFactionSnapshot.standing ~= newSnapshot.standing
end

local function IsRepGainSuppressed()
    return GetTime() < repGainSuppressUntil
end

local function SetRepGainSuppress(extraGrace)
    repBarFadeTime = GetSetting('reputationBarFadeTime', 0.4)
    repBarShowTime = GetSetting('reputationBarShowTime', 1.1)
    local duration = repBarFadeTime * 2 + repBarShowTime + (extraGrace or 0.3)
    repGainSuppressUntil = GetTime() + duration
    BarsDebug("rep gain suppressed until", repGainSuppressUntil, "for", duration, "sec")
end

local function LogBarsState(context)
    BarsDebug(context or "bars state",
        "rep temp:", isRepBarTemporarilyVisible,
        "rep anim:", isRepBarAnimating,
        "rep occupies:", module:IsReputationBarOccupyingSpace(),
        "exp occupies:", module:IsExperienceBarOccupyingSpace())
    if ReputationWatchBar then
        BarsDebug("rep frame shown:", ReputationWatchBar:IsShown(),
            "alpha:", ReputationWatchBar:GetAlpha())
    end
    if MainMenuExpBar then
        BarsDebug("xp frame shown:", MainMenuExpBar:IsShown(),
            "alpha:", MainMenuExpBar:GetAlpha())
    end
end

local function IsAltPressed()
    return SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()
end

local function PlayerHasXpBarSlot()
    return IsBelowMaxLevel() and not IsXPDisabled()
end

-- Does the reputation bar currently need layout space?
function module:IsReputationBarOccupyingSpace()
    if not GetWatchedFactionInfo() then
        return false
    end
    
    local hideReputationBar = GetSetting('hideReputationBar', false)
    if not hideReputationBar then
        return true
    end
    
    if isRepBarTemporarilyVisible or isRepBarAnimating then
        return true
    end
    
    if IsAltPressed() and GetSetting('showReputationBarOnAlt', false) then
        return true
    end
    
    return false
end

-- Does the experience bar currently need layout space?
function module:IsExperienceBarOccupyingSpace()
    if not PlayerHasXpBarSlot() then
        return false
    end
    
    local hideExperienceBar = GetSetting('hideExperienceBar', false)
    if not hideExperienceBar then
        return true
    end
    
    if isXPBarAnimating then
        return true
    end
    
    if IsAltPressed() and GetSetting('showExperienceBarOnAlt', false) then
        return true
    end
    
    -- Blizzard stacks rep above XP below max level; XP slot must stay for layout
    if self:IsReputationBarOccupyingSpace() and PlayerHasXpBarSlot() then
        return true
    end
    
    return false
end

-- Should Blizzard configure/show tracking bars for layout?
function module:ShouldConfigureBlizzardBars()
    if self:IsReputationBarOccupyingSpace() or self:IsExperienceBarOccupyingSpace() then
        return true
    end
    if not GetSetting('hideReputationBar', false) and GetWatchedFactionInfo() then
        return true
    end
    if not GetSetting('hideExperienceBar', false) and PlayerHasXpBarSlot() then
        return true
    end
    return false
end

-- Hide bars per SarychUI settings and reposition without ReputationWatchBar_Update
function module:ApplyCollapsedBarsLayout(reason)
    BarsDebug("ApplyCollapsedBarsLayout reason:", reason or "unknown")
    LogBarsState("before collapsed layout")
    
    isUpdatingBarsLayout = true
    
    local hideExperienceBar = GetSetting('hideExperienceBar', false)
    local hideReputationBar = GetSetting('hideReputationBar', false)
    
    if hideReputationBar and ReputationWatchBar then
        ReputationWatchBar:Hide()
        ReputationWatchBar:SetAlpha(0)
    end
    
    if hideExperienceBar and MainMenuExpBar then
        MainMenuExpBar:Hide()
        MainMenuExpBar:SetAlpha(0)
        if MainMenuExpBar.pauseUpdates ~= nil then
            MainMenuExpBar.pauseUpdates = true
        end
        self:SetExpBarVisibility(false)
        self:SetExpBarAlpha(0)
    end
    
    if not IsBelowMaxLevel() or IsXPDisabled() then
        if not GetWatchedFactionInfo() and MainMenuBarMaxLevelBar then
            local hideMaxLevelBar = GetSetting('hideMaxLevelBar', false)
            if hideMaxLevelBar then
                MainMenuBarMaxLevelBar:SetAlpha(0)
            else
                MainMenuBarMaxLevelBar:Show()
            end
        end
    end
    
    if UIParent_ManageFramePositions then
        UIParent_ManageFramePositions()
    end
    
    isUpdatingBarsLayout = false
    LogBarsState("after collapsed layout")
end

-- Re-apply SarychUI hide/alpha after Blizzard repositioned bars
function module:ApplyBarsVisualStateAfterLayout()
    if isXPBarAnimating then
        return
    end
    
    local hideExperienceBar = GetSetting('hideExperienceBar', false)
    local hideReputationBar = GetSetting('hideReputationBar', false)
    
    if self:IsExperienceBarOccupyingSpace() then
        if MainMenuExpBar then
            MainMenuExpBar:Show()
            local showVisually = not hideExperienceBar
                or (IsAltPressed() and GetSetting('showExperienceBarOnAlt', false))
            if showVisually then
                self:SetExpBarAlpha(1)
                self:SetExpBarVisibility(true)
            else
                self:SetExpBarAlpha(0)
            end
        end
    elseif MainMenuExpBar and hideExperienceBar and not isRepBarAnimating and not isRepBarTemporarilyVisible then
        MainMenuExpBar:Hide()
        MainMenuExpBar:SetAlpha(0)
        self:SetExpBarVisibility(false)
        self:SetExpBarAlpha(0)
    end
    
    if isRepBarAnimating then
        return
    end
    
    if self:IsReputationBarOccupyingSpace() then
        if ReputationWatchBar then
            ReputationWatchBar:Show()
            local showVisually = not hideReputationBar
                or (IsAltPressed() and GetSetting('showReputationBarOnAlt', false))
            if showVisually then
                self:SetRepBarAlpha(1)
            else
                self:SetRepBarAlpha(0)
            end
        end
    elseif ReputationWatchBar and hideReputationBar then
        ReputationWatchBar:Hide()
        ReputationWatchBar:SetAlpha(0)
    end
    
    if self.UpdateExhaustionTick then
        self:UpdateExhaustionTick()
    end
end

-- Refresh Blizzard bar anchors and managed frame positions
function module:UpdateBarsLayout(reason)
    if isUpdatingBarsLayout then
        BarsDebug("UpdateBarsLayout skipped: reentrant", reason or "unknown")
        return
    end
    
    BarsDebug("UpdateBarsLayout reason:", reason or "unknown")
    LogBarsState("UpdateBarsLayout")
    
    isUpdatingBarsLayout = true
    
    if self:ShouldConfigureBlizzardBars() then
        if ReputationWatchBar_Update then
            ReputationWatchBar_Update()
        elseif UIParent_ManageFramePositions then
            UIParent_ManageFramePositions()
        end
        self:ApplyBarsVisualStateAfterLayout()
    else
        self:ApplyCollapsedBarsLayout(reason or "UpdateBarsLayout")
    end
    
    isUpdatingBarsLayout = false
end

local function HookBlizzardReputationBarUpdate()
    if blizzardRepBarHooked or not hooksecurefunc then
        return
    end
    if ReputationWatchBar_Update then
        hooksecurefunc("ReputationWatchBar_Update", function()
            if isUpdatingBarsLayout then
                return
            end
            
            BarsDebug("ReputationWatchBar_Update hook fired")
            LogBarsState("ReputationWatchBar_Update hook")
            
            module:ApplyBarsVisualStateAfterLayout()
            
            if not module:ShouldConfigureBlizzardBars() then
                module:ApplyCollapsedBarsLayout("ReputationWatchBar_Update hook")
            end
        end)
        blizzardRepBarHooked = true
    end
end

-- Handle UPDATE_FACTION: only trigger temp show on real value change
function module:OnUpdateFactionEvent()
    BarsDebug("UPDATE_FACTION event")
    
    local newSnapshot = GetWatchedFactionSnapshot()
    if not newSnapshot then
        watchedFactionSnapshot = nil
        module.watchedFactionSnapshot = nil
        return
    end
    
    if not HasWatchedFactionValueChanged() then
        BarsDebug("UPDATE_FACTION: no value change, snapshot unchanged")
        watchedFactionSnapshot = newSnapshot
        module.watchedFactionSnapshot = newSnapshot
        return
    end
    
    if IsRepGainSuppressed() or isRepBarAnimating then
        BarsDebug("UPDATE_FACTION: suppressed or animation active, updating snapshot only")
        CommitWatchedFactionSnapshot()
        return
    end
    
    BarsDebug("UPDATE_FACTION: watched faction value changed")
    CommitWatchedFactionSnapshot()
    self:HandleReputationUpdate("UPDATE_FACTION")
end

-- Handle CHAT_MSG_COMBAT_FACTION_CHANGE
function module:OnCombatFactionChangeEvent(message)
    BarsDebug("CHAT_MSG_COMBAT_FACTION_CHANGE event:", message or "")
    
    local watchedName = GetWatchedFactionInfo()
    if not watchedName or not message or not message:find(watchedName, 1, true) then
        return
    end
    
    if IsRepGainSuppressed() or isRepBarAnimating then
        BarsDebug("CHAT_MSG: suppressed or animation active")
        CommitWatchedFactionSnapshot()
        return
    end
    
    CommitWatchedFactionSnapshot()
    self:HandleReputationUpdate("CHAT_MSG_COMBAT_FACTION_CHANGE")
end

-- Initialize visual system
function module:InitializeVisualSystem()
    BarsDebug("module loaded, initializing bar visual system")
    
    HookBlizzardReputationBarUpdate()
    
    CommitWatchedFactionSnapshot()
    
    -- Apply all appearance settings
    if module.ApplyAppearanceSettings then module:ApplyAppearanceSettings() end
    
    -- Update exhaustion tick on initialization (from original)
    if module.UpdateExhaustionTick then module:UpdateExhaustionTick() end
    
    -- Update page numbers on initialization
    if module.UpdatePageNumbers then module:UpdatePageNumbers() end
    
    -- Update experience bar on initialization
    if module.UpdateExperienceBar then module:UpdateExperienceBar() end
    
    -- Update reputation bar on initialization
    if module.UpdateReputationBar then module:UpdateReputationBar() end
    
    -- Update side panels on initialization
    if module.UpdateSidePanels then module:UpdateSidePanels() end
    
    -- Setup panel mouse handlers (from original)
    if module.SetupPanelMouseHandlers then module:SetupPanelMouseHandlers() end
    
    -- Setup OnUpdate handler for panels (from original)
    if module.SetupPanelOnUpdate then module:SetupPanelOnUpdate() end
end

-- Кэш регионов для баров (оптимизация производительности)
local barRegionsCache = {}

-- Функция для получения кэшированных регионов бара
local function GetBarRegions(bar)
    if not bar then return {} end
    
    -- Проверяем кэш
    if not barRegionsCache[bar] then
        barRegionsCache[bar] = {}
        local numRegions = SafeForLimit(bar:GetNumRegions(), 0)
        for i = 1, numRegions do
            local region = select(i, bar:GetRegions())
            if region then
                tinsert(barRegionsCache[bar], region)
            end
        end
    end
    
    return barRegionsCache[bar]
end

-- Функция для очистки кэша регионов (вызывать при необходимости обновления)
local function ClearBarRegionsCache(bar)
    if bar then
        barRegionsCache[bar] = nil
    else
        -- Очистить весь кэш
        wipe(barRegionsCache)
    end
end

-- Apply gryphons settings (from sarMainMenuBar/panelVisual.lua)
local function ApplyGryphonsSettings()
    local hideGryphons = GetSetting('hideGryphons', false)
    
    if MainMenuBarLeftEndCap then
        if hideGryphons then
            MainMenuBarLeftEndCap:Hide()
        else
            MainMenuBarLeftEndCap:Show()
        end
    end

    if MainMenuBarRightEndCap then
        if hideGryphons then
            MainMenuBarRightEndCap:Hide()
        else
            MainMenuBarRightEndCap:Show()
        end
    end
end


-- Apply action bar backgrounds
local function ApplyActionBarBackgrounds()
    local hideActionBarBackgrounds = GetSetting('hideActionBarBackgrounds', false)
    
    local actionBars = {
        "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MainMenuBar", "BonusActionBarFrame"
    }
    
    for _, barName in ipairs(actionBars) do
        local bar = _G[barName]
        if bar then
            -- Используем кэшированные регионы вместо повторных вызовов API
            local regions = GetBarRegions(bar)
            for _, region in ipairs(regions) do
                if region and region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    if texture and (texture:find("UI%-ActionBar") or texture:find("ActionBar") or texture:find("Background") or texture:find("MainMenuBar")) then
                        if hideActionBarBackgrounds then
                            region:SetTexture(nil)
                        else
                            region:SetTexture("Interface\\ActionBar\\UI-ActionBar-Background")
                        end
                    end
                end
            end
        end
    end
    
    -- Обрабатываем отдельные текстуры главной панели
    local mainTextures = {
        MainMenuBarTexture0, MainMenuBarTexture1, MainMenuBarTexture2, MainMenuBarTexture3,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture0) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture1) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture2) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture3) or nil
    }
    
    for i, texture in ipairs(mainTextures) do
        if texture then
            if hideActionBarBackgrounds then
                texture:Hide()
                if texture.SetScript then
                    texture:SetScript("OnShow", texture.Hide)
                end
            else
                if texture.SetScript then
                    texture:SetScript("OnShow", nil)
                end
                texture:Show()
            end
        end
    end
    
    -- Обрабатываем текстуры бонусной панели действий
    local bonusTextures = {
        BonusActionBarTexture0, BonusActionBarTexture1
    }
    for _, texture in ipairs(bonusTextures) do
        if texture then
            if hideActionBarBackgrounds then
                texture:Hide()
                if texture.SetScript then
                    texture:SetScript("OnShow", texture.Hide)
                end
            else
                texture:Show()
                if texture.SetScript then
                    texture:SetScript("OnShow", nil)
                end
            end
        end
    end
end

-- Apply secondary panels backgrounds (shapeshift, pet, possess)
local function ApplySecondaryPanelsBackgrounds()
    local hideSecondaryPanelsBackgrounds = GetSetting('hideSecondaryPanelsBackgrounds', false)
    
    -- Shapeshift bar backgrounds
    if ShapeshiftBarFrame then
        -- Используем кэшированные регионы вместо повторных вызовов API
        local regions = GetBarRegions(ShapeshiftBarFrame)
        for _, region in ipairs(regions) do
            if region and region:GetObjectType() == "Texture" then
                local texture = region:GetTexture()
                if texture and (texture:find("ShapeshiftBar") or texture:find("ShapeshiftBarEnds") or texture:find("SHAPESHIFTBARMIDDLE")) then
                    if hideSecondaryPanelsBackgrounds then
                        region:SetTexture(nil)
                    else
                        region:SetTexture("Interface\\ShapeshiftBar\\UI-ShapeshiftBar")
                    end
                end
            end
        end

        for i = 1, GetNumShapeshiftFormsSafe() do
            local button = _G["ShapeshiftButton" .. i]
            if button then
                local normalTexture = button:GetNormalTexture()
                if normalTexture then
                    if hideSecondaryPanelsBackgrounds then
                        normalTexture:SetTexture(nil)
                    else
                        normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                    end
                end
                local border = _G["ShapeshiftButton" .. i .. "Border"]
                if border then
                    if hideSecondaryPanelsBackgrounds then
                        border:SetTexture(nil)
                    else
                        border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
                    end
                end
            end
        end
    end
    
    -- Pet bar backgrounds
    if PetActionBarFrame then
        -- Используем кэшированные регионы вместо повторных вызовов API
        local regions = GetBarRegions(PetActionBarFrame)
        for _, region in ipairs(regions) do
            if region and region:GetObjectType() == "Texture" then
                local texture = region:GetTexture()
                if texture and texture:find("UI%-PetBar") then
                    if hideSecondaryPanelsBackgrounds then
                        region:SetTexture(nil)
                    else
                        region:SetTexture("Interface\\PetBar\\UI-PetBar")
                    end
                end
            end
        end
    end
    
    -- Possess bar backgrounds
    if PossessBarFrame then
        -- Используем кэшированные регионы вместо повторных вызовов API
        local regions = GetBarRegions(PossessBarFrame)
        for _, region in ipairs(regions) do
            if region and region:GetObjectType() == "Texture" then
                local texture = region:GetTexture()
                if texture and not texture:find("HIGHLIGHT") and not texture:find("BORDER") then
                    if hideSecondaryPanelsBackgrounds then
                        region:SetTexture(nil)
                    else
                        region:SetTexture("Interface\\PetBar\\UI-PetBar")
                    end
                end
            end
        end

        for i = 1, POSSESS_SLOTS do
            local button = _G["PossessButton" .. i]
            if button then
                local normalTexture = button:GetNormalTexture()
                if normalTexture then
                    if hideSecondaryPanelsBackgrounds then
                        normalTexture:SetTexture(nil)
                    else
                        normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                    end
                end
                local border = _G["PossessButton" .. i .. "Border"]
                if border then
                    if hideSecondaryPanelsBackgrounds then
                        border:SetTexture(nil)
                    else
                        border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
                    end
                end
            end
        end
    end
end


-- Apply page buttons settings
local function ApplyPageButtonsSettings()
    local hidePageButtons = GetSetting('hidePageButtons', false)
    
    local pageButtons = {
        ActionBarUpButton, ActionBarDownButton
    }
    for _, button in ipairs(pageButtons) do
        if button then
            if hidePageButtons then
                button:Hide()
                if button.SetScript then
                    button:SetScript("OnShow", button.Hide)
                end
            else
                button:Show()
                if button.SetScript then
                    button:SetScript("OnShow", nil)
                end
            end
        end
    end
end

-- Apply keyring button settings
local function ApplyKeyringButtonSettings()
    local hideKeyringButton = GetSetting('hideKeyringButton', false)
    
    if KeyRingButton then
        if hideKeyringButton then
            KeyRingButton:Hide()
            if KeyRingButton.SetScript then
                KeyRingButton:SetScript("OnShow", KeyRingButton.Hide)
            end
        else
            KeyRingButton:Show()
            if KeyRingButton.SetScript then
                KeyRingButton:SetScript("OnShow", nil)
            end
        end
    end
end

-- Apply max level bar settings
local function ApplyMaxLevelBarSettings()
    local hideMaxLevelBar = GetSetting('hideMaxLevelBar', false)
    
    if MainMenuBarMaxLevelBar then
        if hideMaxLevelBar then
            MainMenuBarMaxLevelBar:SetAlpha(0)
        else
            MainMenuBarMaxLevelBar:SetAlpha(1)
        end
    end
end

-- Apply button border alpha
local function ApplyButtonBorderAlpha()
    local buttonBorderAlphaEnabled = GetSetting('buttonBorderAlphaEnabled', false)
    local buttonBorderAlpha = GetSetting('buttonBorderAlpha', 0.4)
    
    local buttonTypes = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton", "BonusActionButton", "ShapeshiftButton",
        "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot"
    }

    for i = 1, 12 do
        for _, btnType in ipairs(buttonTypes) do
            local button = _G[btnType .. i]
            if button then
                for _, tex in ipairs({button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()}) do
                    if tex then 
                        if buttonBorderAlphaEnabled then
                            tex:SetAlpha(buttonBorderAlpha)
                        else
                            tex:SetAlpha(1.0)
                        end
                    end
                end
            end
        end
    end
    
    -- Apply to pet bar buttons
    for i = 1, 10 do
        local button = _G["PetActionButton" .. i]
        if button then
            for _, tex in ipairs({button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()}) do
                if tex then 
                    if buttonBorderAlphaEnabled then
                        tex:SetAlpha(buttonBorderAlpha)
                    else
                        tex:SetAlpha(1.0)
                    end
                end
            end
        end
    end
    
    -- Apply to possess bar buttons
    for i = 1, POSSESS_SLOTS do
        local button = _G["PossessButton" .. i]
        if button then
            for _, tex in ipairs({button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()}) do
                if tex then 
                    if buttonBorderAlphaEnabled then
                        tex:SetAlpha(buttonBorderAlpha)
                    else
                        tex:SetAlpha(1.0)
                    end
                end
            end
        end
    end
end

-- Micro menu art: only swap textures; leave Blizzard size/position alone.
local MICRO_MENU_DF_TEX = [[Interface\AddOns\SarychUI\media\micromenu\uimicromenu2x]]

local MICRO_MENU_DF_COORDS = {
	character = {
		up = { 1 / 256, 39 / 256, 325 / 512, 377 / 512 },
		down = { 121 / 256, 159 / 256, 163 / 512, 215 / 512 },
		disabled = { 1 / 256, 39 / 256, 217 / 512, 269 / 512 },
		mouseover = { 81 / 256, 119 / 256, 217 / 512, 269 / 512 },
	},
	spellbook = {
		up = { 121 / 256, 159 / 256, 55 / 512, 107 / 512 },
		down = { 81 / 256, 119 / 256, 433 / 512, 485 / 512 },
		disabled = { 1 / 256, 39 / 256, 55 / 512, 107 / 512 },
		mouseover = { 189 / 256, 227 / 256, 433 / 512, 485 / 512 },
	},
	talent = {
		up = { 161 / 256, 199 / 256, 1 / 512, 53 / 512 },
		down = { 81 / 256, 119 / 256, 271 / 512, 323 / 512 },
		disabled = { 81 / 256, 119 / 256, 55 / 512, 107 / 512 },
		mouseover = { 81 / 256, 119 / 256, 1 / 512, 53 / 512 },
	},
	achievement = {
		up = { 161 / 256, 199 / 256, 109 / 512, 161 / 512 },
		down = { 161 / 256, 199 / 256, 55 / 512, 107 / 512 },
		disabled = { 201 / 256, 239 / 256, 109 / 512, 161 / 512 },
		mouseover = { 201 / 256, 239 / 256, 55 / 512, 107 / 512 },
	},
	questlog = {
		up = { 201 / 256, 239 / 256, 271 / 512, 323 / 512 },
		down = { 121 / 256, 159 / 256, 271 / 512, 323 / 512 },
		disabled = { 41 / 256, 79 / 256, 379 / 512, 431 / 512 },
		mouseover = { 41 / 256, 79 / 256, 433 / 512, 485 / 512 },
	},
	socials = {
		up = { 41 / 256, 79 / 256, 55 / 512, 107 / 512 },
		down = { 1 / 256, 39 / 256, 1 / 512, 53 / 512 },
		disabled = { 201 / 256, 239 / 256, 1 / 512, 53 / 512 },
		mouseover = { 41 / 256, 79 / 256, 1 / 512, 53 / 512 },
	},
	lfd = {
		up = { 1 / 256, 39 / 256, 163 / 512, 215 / 512 },
		down = { 81 / 256, 119 / 256, 109 / 512, 161 / 512 },
		disabled = { 41 / 256, 79 / 256, 271 / 512, 323 / 512 },
		mouseover = { 41 / 256, 79 / 256, 109 / 512, 161 / 512 },
	},
	pvp = {
		up = { 1 / 256, 39 / 256, 271 / 512, 323 / 512 },
		down = { 201 / 256, 239 / 256, 163 / 512, 215 / 512 },
		disabled = { 81 / 256, 119 / 256, 163 / 512, 215 / 512 },
		mouseover = { 161 / 256, 199 / 256, 163 / 512, 215 / 512 },
	},
	mainmenu = {
		up = { 1 / 256, 39 / 256, 109 / 512, 161 / 512 },
		down = { 161 / 256, 199 / 256, 271 / 512, 323 / 512 },
		disabled = { 41 / 256, 79 / 256, 325 / 512, 377 / 512 },
		mouseover = { 121 / 256, 159 / 256, 325 / 512, 377 / 512 },
	},
	help = {
		up = { 201 / 256, 239 / 256, 217 / 512, 269 / 512 },
		down = { 121 / 256, 159 / 256, 217 / 512, 269 / 512 },
		disabled = { 41 / 256, 79 / 256, 217 / 512, 269 / 512 },
		mouseover = { 161 / 256, 199 / 256, 217 / 512, 269 / 512 },
	},
}

local MICRO_MENU_BUTTONS = {
	{ button = "CharacterMicroButton", key = "character", classic = "Character" },
	{ button = "SpellbookMicroButton", key = "spellbook", classic = "Spellbook" },
	{ button = "TalentMicroButton", key = "talent", classic = "Talent" },
	{ button = "AchievementMicroButton", key = "achievement", classic = "Achievement" },
	{ button = "QuestLogMicroButton", key = "questlog", classic = "Quest" },
	{ button = "SocialsMicroButton", key = "socials", classic = "Socials" },
	{ button = "PVPMicroButton", key = "pvp", classic = "PVP" },
	{ button = "LFDMicroButton", key = "lfd", classic = "LFG" },
	{ button = "MainMenuMicroButton", key = "mainmenu", classic = "MainMenu" },
	{ button = "HelpMicroButton", key = "help", classic = "Help" },
}

local CLASSIC_MICRO_HILIGHT = [[Interface\Buttons\UI-MicroButton-Hilight]]
-- pretty_actionbar: button 14x19 + menu scale 1.4 → draw textures at this size.
local MICRO_DF_TEX_W = 14 * 1.4
local MICRO_DF_TEX_H = 19 * 1.4
local microMenuStyleHooksInstalled

local function ClassicMicroPath(name, suffix)
	if name == "Character" then
		return "Interface\\Buttons\\UI-MicroButtonCharacter-" .. suffix
	end
	return "Interface\\Buttons\\UI-MicroButton-" .. name .. "-" .. suffix
end

-- useDfSize: pin texture to DF size at bottom of button (do not move the button itself).
local function SetMicroTex(tex, pathOrSheet, coords, useDfSize, button)
	if not tex then return end
	tex:SetTexture(pathOrSheet)
	if coords then
		tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		tex:SetTexCoord(0, 1, 0, 1)
	end
	tex:ClearAllPoints()
	if useDfSize and button then
		tex:SetWidth(MICRO_DF_TEX_W)
		tex:SetHeight(MICRO_DF_TEX_H)
		tex:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
	else
		tex:SetAllPoints(button or tex:GetParent())
	end
end

local function PositionPerformanceBar()
	local bar = MainMenuBarPerformanceBar
	local button = MainMenuMicroButton
	if not bar or not button then return end
	if not module._microPerfBarH then
		module._microPerfBarH = bar:GetHeight() or 64
		module._microPerfBarW = bar:GetWidth() or 8
	end
	bar:ClearAllPoints()
	if GetSetting("microMenuStyle", "classic") == "dragonflight" then
		bar:SetWidth(module._microPerfBarW + 3)
		bar:SetHeight(math.floor(module._microPerfBarH * 0.32 + 0.5))
		bar:SetPoint("BOTTOM", button, "BOTTOM", 3, 3)
	else
		bar:SetWidth(module._microPerfBarW)
		bar:SetHeight(module._microPerfBarH)
		bar:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -34)
	end
end

-- Blizzard: green ≤ PERFORMANCEBAR_LOW_LATENCY (300), yellow ≤ MEDIUM (600), else red.
local function IsLatencyGreen()
	local _, _, latency = GetNetStats()
	if type(latency) ~= "number" then
		return true
	end
	local low = PERFORMANCEBAR_LOW_LATENCY or 300
	return latency <= low
end

local function ShouldHideGreenLatencyBar()
	return GetSetting("microMenuStyle", "classic") == "dragonflight"
		and GetSetting("microMenuHideGreenLatency", true) ~= false
end

local function ApplyPerformanceBarVisibility()
	local bar = MainMenuBarPerformanceBar
	if not bar then return end
	if ShouldHideGreenLatencyBar() and IsLatencyGreen() then
		if bar:IsShown() then
			bar:Hide()
		end
	else
		if not bar:IsShown() then
			bar:Show()
		end
	end
end

local function UpdatePerformanceBar()
	PositionPerformanceBar()
	ApplyPerformanceBarVisibility()
end

local function EnsureMicroMenuStyleHooks()
	if microMenuStyleHooksInstalled then return end
	microMenuStyleHooksInstalled = true

	local function HidePortraitIfDf()
		if GetSetting("microMenuStyle", "classic") ~= "dragonflight" then return end
		if MicroButtonPortrait then
			MicroButtonPortrait:SetTexCoord(0, 0, 0, 0)
			MicroButtonPortrait:SetAlpha(0)
		end
	end

	if type(hooksecurefunc) == "function" then
		if CharacterMicroButton_SetPushed then
			hooksecurefunc("CharacterMicroButton_SetPushed", HidePortraitIfDf)
		end
		if CharacterMicroButton_SetNormal then
			hooksecurefunc("CharacterMicroButton_SetNormal", HidePortraitIfDf)
		end
		if MainMenuMicroButton_SetPushed then
			hooksecurefunc("MainMenuMicroButton_SetPushed", UpdatePerformanceBar)
		end
		if MainMenuMicroButton_SetNormal then
			hooksecurefunc("MainMenuMicroButton_SetNormal", UpdatePerformanceBar)
		end
	end

	local perfFrame = MainMenuBarPerformanceBarFrame
	if perfFrame and not perfFrame._sarychHideGreenHook then
		perfFrame._sarychHideGreenHook = true
		if perfFrame.HookScript then
			perfFrame:HookScript("OnUpdate", ApplyPerformanceBarVisibility)
		end
	end
end

local function ApplyMicroMenuStyle()
	EnsureMicroMenuStyleHooks()
	local useDf = GetSetting("microMenuStyle", "classic") == "dragonflight"

	for _, entry in ipairs(MICRO_MENU_BUTTONS) do
		local button = _G[entry.button]
		if button then
			local coords = MICRO_MENU_DF_COORDS[entry.key]
			local normal = button:GetNormalTexture()
			local pushed = button:GetPushedTexture()
			local highlight = button:GetHighlightTexture()
			local disabled = button:GetDisabledTexture()

			if useDf and coords then
				if not disabled and button.SetDisabledTexture then
					button:SetDisabledTexture("")
					disabled = button:GetDisabledTexture()
				end
				SetMicroTex(normal, MICRO_MENU_DF_TEX, coords.up, true, button)
				SetMicroTex(pushed, MICRO_MENU_DF_TEX, coords.down, true, button)
				SetMicroTex(disabled, MICRO_MENU_DF_TEX, coords.disabled, true, button)
				SetMicroTex(highlight, MICRO_MENU_DF_TEX, coords.mouseover, true, button)
				if highlight and highlight.SetBlendMode then
					highlight:SetBlendMode("ADD")
				end
			else
				local base = entry.classic
				SetMicroTex(normal, ClassicMicroPath(base, "Up"), nil, false, button)
				SetMicroTex(pushed, ClassicMicroPath(base, "Down"), nil, false, button)
				SetMicroTex(disabled, ClassicMicroPath(base, "Disabled"), nil, false, button)
				SetMicroTex(highlight, CLASSIC_MICRO_HILIGHT, nil, false, button)
				if highlight and highlight.SetBlendMode then
					highlight:SetBlendMode("ADD")
				end
			end
		end
	end

	if MicroButtonPortrait then
		if useDf then
			MicroButtonPortrait:SetTexCoord(0, 0, 0, 0)
			MicroButtonPortrait:SetAlpha(0)
		else
			if SetPortraitTexture then
				SetPortraitTexture(MicroButtonPortrait, "player")
			end
			MicroButtonPortrait:SetTexCoord(0.2, 0.8, 0.0666, 0.9)
			MicroButtonPortrait:SetAlpha(1)
		end
	end

	if PVPMicroButtonTexture then
		if useDf then
			PVPMicroButtonTexture:Hide()
		else
			PVPMicroButtonTexture:Show()
		end
	end

	PositionPerformanceBar()
	ApplyPerformanceBarVisibility()
end

-- Apply micro menu alpha
local function ApplyMicroMenuAlpha()
    local microMenuAlphaEnabled = GetSetting('microMenuAlphaEnabled', false)
    local microMenuAlpha = GetSetting('microMenuAlpha', 0.95)
    
    local microButtons = {
        "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton",
        "LFDMicroButton", "MainMenuMicroButton", "SocialsMicroButton", "PVPMicroButton", "HelpMicroButton"
    }

    for _, btn in ipairs(microButtons) do
        local button = _G[btn]
        if button then
            for _, tex in ipairs({button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture(), button:GetDisabledTexture()}) do
                if tex then 
                    if microMenuAlphaEnabled then
                        tex:SetAlpha(microMenuAlpha)
                    else
                        tex:SetAlpha(1.0)
                    end
                end
            end
        end
    end
end

-- Apply experience bar settings
local function ApplyExperienceBarSettings()
    -- Не обновляем полосу опыта во время анимации
    if isXPBarAnimating then
        BarsDebug("ApplyExperienceBarSettings skipped: XP animation in progress")
        return
    end
    
    if isRepBarAnimating or isRepBarTemporarilyVisible then
        module:ApplyBarsVisualStateAfterLayout()
        return
    end
    
    local hideExperienceBar = GetSetting('hideExperienceBar', false)
    local showExperienceBarOnAlt = GetSetting('showExperienceBarOnAlt', false)
    local showExperienceBarOnGain = GetSetting('showExperienceBarOnGain', false)
    
    BarsDebug("ApplyExperienceBarSettings hide=", hideExperienceBar)
    
    if not hideExperienceBar then
        -- Если скрытие отключено - показываем полосу опыта
        if PlayerHasXpBarSlot() then
            if MainMenuExpBar then
                MainMenuExpBar:Show()
                MainMenuExpBar:SetAlpha(1)
            end
        end
    else
        -- Если скрытие включено - скрываем по умолчанию
        if module.IsExperienceBarOccupyingSpace and module:IsExperienceBarOccupyingSpace() then
            if MainMenuExpBar then
                MainMenuExpBar:Show()
                MainMenuExpBar:SetAlpha(0)
            end
        elseif MainMenuExpBar then
            MainMenuExpBar:Hide()
            MainMenuExpBar:SetAlpha(0)
        end
    end
    
    -- ExhaustionTick должен обновляться независимо от настроек полосы опыта
    if module.UpdateExhaustionTick then
        module:UpdateExhaustionTick()
    end
end

-- Apply reputation bar settings
local function ApplyReputationBarSettings()
    if isRepBarAnimating or isRepBarTemporarilyVisible then
        BarsDebug("ApplyReputationBarSettings skipped: reputation animation in progress")
        return
    end
    
    local hideReputationBar = GetSetting('hideReputationBar', false)
    local showReputationBarOnAlt = GetSetting('showReputationBarOnAlt', false)
    
    BarsDebug("ApplyReputationBarSettings hide=", hideReputationBar, "frame=", ReputationWatchBar, ReputationWatchStatusBar)
    
    if not hideReputationBar then
        -- Если скрытие отключено - показываем полосу репутации
        if GetWatchedFactionInfo() then
            if ReputationWatchBar then
                ReputationWatchBar:Show()
                ReputationWatchBar:SetAlpha(1)
            end
        end
    else
        -- Если скрытие включено - скрываем по умолчанию
        if ReputationWatchBar then
            ReputationWatchBar:Hide()
            ReputationWatchBar:SetAlpha(0)
            BarsDebug("reputation bar hidden via frame Hide/SetAlpha(0)")
        else
            BarsDebug("reputation frame not found: ReputationWatchBar")
        end
    end
end

-- Apply side panels settings
local function ApplySidePanelsSettings()
    local hideSidePanels = GetSetting('hideSidePanels', false)
    
    if not hideSidePanels then
        -- Если скрытие отключено - показываем панели
        if MultiBarRight then
            MultiBarRight:SetAlpha(1)
            MultiBarRight:EnableMouse(true)
        end
        if MultiBarLeft then
            MultiBarLeft:SetAlpha(1)
            MultiBarLeft:EnableMouse(true)
        end
    else
        -- Если скрытие включено - скрываем по умолчанию
        if MultiBarRight then
            MultiBarRight:SetAlpha(0)
        end
        if MultiBarLeft then
            MultiBarLeft:SetAlpha(0)
        end
    end
end

-- Show elements on Alt key press
function module:ShowElementsOnAlt()
    BarsDebug("ALT pressed, showing bar elements")
    
    local showHotkeysOnAlt = GetSetting('showHotkeysOnAlt', false)
    local showPageNumbersOnAlt = GetSetting('showPageNumbersOnAlt', false)
    local showExperienceBarOnAlt = GetSetting('showExperienceBarOnAlt', false)
    local showReputationBarOnAlt = GetSetting('showReputationBarOnAlt', false)
    local showSidePanelsOnAlt = GetSetting('showSidePanelsOnAlt', false)
    
    -- Show hotkeys (только вне боя)
    if showHotkeysOnAlt then
        for i = 1, 12 do
            _G["ActionButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarBottomRightButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarBottomLeftButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarRightButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["MultiBarLeftButton" .. i .. "HotKey"]:SetAlpha(1)
            _G["BonusActionButton" .. i .. "HotKey"]:SetAlpha(1)
        end
    end
    
    -- Show page numbers (только вне боя)
    if showPageNumbersOnAlt and MainMenuBarPageNumber then
        MainMenuBarPageNumber:SetAlpha(1)
        MainMenuBarPageNumber:Show()
    end
    
    -- Show experience bar (только вне боя)
    if showExperienceBarOnAlt and PlayerHasXpBarSlot() then
        module:UpdateBarsLayout("ALT show experience bar")
        if MainMenuExpBar then
            MainMenuExpBar:Show()
            MainMenuExpBar:SetAlpha(1)
        end
        if module.SetExpBarVisibility then
            module:SetExpBarVisibility(true)
        end
        if module.SetExpBarAlpha then
            module:SetExpBarAlpha(1)
        end
    end
    
    -- Show reputation bar (только вне боя)
    if showReputationBarOnAlt and GetWatchedFactionInfo() then
        module:UpdateBarsLayout("ALT show reputation bar")
        if ReputationWatchBar then
            ReputationWatchBar:Show()
            ReputationWatchBar:SetAlpha(1)
        end
    end
    
    -- Show side panels (только вне боя)
    if showSidePanelsOnAlt then
        if MultiBarRight then
            MultiBarRight:SetAlpha(1)
        end
        if MultiBarLeft then
            MultiBarLeft:SetAlpha(1)
        end
    end
end

-- Hide elements when Alt key is released
function module:HideElementsOnAltRelease()
    BarsDebug("ALT released, hiding bar elements")
    
    -- Используем функции Hide*, которые содержат правильную логику приоритета боя
    if module.HideHotkeys then module:HideHotkeys() end
    if module.HidePageNumbers then module:HidePageNumbers() end
    if module.HideExperienceBar then module:HideExperienceBar() end
    if module.HideReputationBar then module:HideReputationBar() end
    
    if not isRepBarAnimating and not isXPBarAnimating then
        module:UpdateBarsLayout("ALT release")
    end
    
    -- Hide side panels (only if mouse is not over them)
    local hideSidePanels = GetSetting('hideSidePanels', false)
    if hideSidePanels then
        -- Check if mouse is over panels - if so, don't hide them
        local mouseOverPanels = false
        
        -- Проверяем позицию мыши в реальном времени
        local mouseX, mouseY = GetCursorPosition()
        local uiScale = UIParent:GetScale()
        mouseX = mouseX / uiScale
        mouseY = mouseY / uiScale
        
        -- Проверяем MultiBarRight
        if MultiBarRight and MultiBarRight:IsVisible() then
            local left, bottom, width, height = MultiBarRight:GetRect()
            if mouseX >= left and mouseX <= left + width and mouseY >= bottom and mouseY <= bottom + height then
                mouseOverPanels = true
            end
        end
        
        -- Проверяем MultiBarLeft
        if MultiBarLeft and MultiBarLeft:IsVisible() then
            local left, bottom, width, height = MultiBarLeft:GetRect()
            if mouseX >= left and mouseX <= left + width and mouseY >= bottom and mouseY <= bottom + height then
                mouseOverPanels = true
            end
        end
        
        -- Скрываем панели только если мышь не на них
        if not mouseOverPanels then
            if MultiBarRight then
                MultiBarRight:SetAlpha(0)
            end
            if MultiBarLeft then
                MultiBarLeft:SetAlpha(0)
            end
        end
    end
end

-- Page Numbers Functions
function module:ShowPageNumbers()
    local hidePageNumbers = GetSetting('hidePageNumbers', false)
    local showPageNumbersInCombat = GetSetting('showPageNumbersInCombat', false)
    local showPageNumbersOnAlt = GetSetting('showPageNumbersOnAlt', false)
    
    if not hidePageNumbers then
        -- Если скрытие отключено - показываем номера страниц
        if MainMenuBarPageNumber then
            MainMenuBarPageNumber:SetAlpha(1)
            MainMenuBarPageNumber:Show()
        end
        return
    end
    
    -- Показываем номера страниц только если:
    -- 1. "Скрыть номера страниц" включено И
	-- 2. (нажат Alt И включена опция "Показывать при нажатии Alt") ИЛИ (в бою И включена опция "Показывать во время боя")
    local isInCombat = UnitAffectingCombat("player")
    local isAltPressed = SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()
	local shouldShow = (isAltPressed and showPageNumbersOnAlt) or (isInCombat and showPageNumbersInCombat)
    if hidePageNumbers and shouldShow then
        if MainMenuBarPageNumber then
            MainMenuBarPageNumber:SetAlpha(1)
            MainMenuBarPageNumber:Show()
        end
    end
end

function module:HidePageNumbers()
    local hidePageNumbers = GetSetting('hidePageNumbers', false)
    local showPageNumbersInCombat = GetSetting('showPageNumbersInCombat', false)
    local showPageNumbersOnAlt = GetSetting('showPageNumbersOnAlt', false)
    
    if not hidePageNumbers then
        -- Если скрытие отключено - показываем номера страниц
        if MainMenuBarPageNumber then
            MainMenuBarPageNumber:SetAlpha(1)
            MainMenuBarPageNumber:Show()
        end
        return
    end
    
    -- ПРИОРИТЕТ: Если в бою и включена опция показа в бою - не скрываем (приоритет над Alt)
    if UnitAffectingCombat("player") and showPageNumbersInCombat then
        return
    end
    
    -- Если нажат Alt и включена опция показа при Alt - не скрываем
    if SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() and showPageNumbersOnAlt then
        return
    end
    
    -- Скрываем номера страниц
    if MainMenuBarPageNumber then
        MainMenuBarPageNumber:SetAlpha(0)
        MainMenuBarPageNumber:Hide()
    end
end

function module:UpdatePageNumbers()
    local hidePageNumbers = GetSetting('hidePageNumbers', false)
    
    if not hidePageNumbers then
        -- Если скрытие отключено - показываем номера страниц
        if MainMenuBarPageNumber then
            MainMenuBarPageNumber:SetAlpha(1)
            MainMenuBarPageNumber:Show()
        end
    else
        -- Если скрытие включено - скрываем по умолчанию
        if MainMenuBarPageNumber then
            MainMenuBarPageNumber:SetAlpha(0)
            MainMenuBarPageNumber:Hide()
        end
    end
end

-- Fade out page numbers function (from original)
function module:FadeOutPageNumber()
    local hidePageNumbers = GetSetting('hidePageNumbers', false)
    local showInCombat = GetSetting('showPageNumbersInCombat', false)
    
    -- Если "Скрыть номера страниц" отключено - не скрываем
    if not hidePageNumbers then return end
    
    local fadeEnabled = GetSetting('pageNumbersFadeAfterCombat', false)
    local fadeTime = GetSetting('pageNumbersFadeTime', 0.5)

    if MainMenuBarPageNumber and MainMenuBarPageNumber:IsVisible() then
        if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(MainMenuBarPageNumber) end
        if fadeEnabled and showInCombat then
            UIFrameFadeOut(MainMenuBarPageNumber, fadeTime, 1, 0)
        else
            MainMenuBarPageNumber:SetAlpha(0)
        end
    end
end

-- Fade in page numbers function (from original)
function module:FadeInPageNumber()
    local hidePageNumbers = GetSetting('hidePageNumbers', false)
    local showInCombat = GetSetting('showPageNumbersInCombat', false)
    
    -- Если "Скрыть номера страниц" отключено ИЛИ "Показывать во время боя" отключено - не показываем
    if not hidePageNumbers or not showInCombat then return end

    local fadeEnabled = GetSetting('pageNumbersFadeAfterCombat', false)
    local fadeTime = GetSetting('pageNumbersFadeTime', 0.5)
    
    if MainMenuBarPageNumber then
        if fadeEnabled then
            -- жёстко анимируем вручную: никто не перебьёт
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(MainMenuBarPageNumber) end
            UIFrameFadeIn(MainMenuBarPageNumber, fadeTime, 0, 1)
        else
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(MainMenuBarPageNumber) end
            MainMenuBarPageNumber:SetAlpha(1)
            MainMenuBarPageNumber:Show()
        end
    end
end

-- Experience Bar Functions
function module:ShowExperienceBar()
    local hideExperienceBar = GetSetting('hideExperienceBar', false)
    local showExperienceBarOnAlt = GetSetting('showExperienceBarOnAlt', false)
    
    if not hideExperienceBar then
        -- Если скрытие отключено - показываем полосу опыта
        if PlayerHasXpBarSlot() then
            if MainMenuExpBar then
                MainMenuExpBar:Show()
                MainMenuExpBar:SetAlpha(1)
            end
        end
        return
    end
    
    -- Показываем полосу опыта только если:
    -- 1. "Скрыть полосу опыта" включено И
	-- 2. нажат Alt И включена опция "Показывать при нажатии Alt"
    local isInCombat = UnitAffectingCombat("player")
    local isAltPressed = SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()
	if hideExperienceBar and isAltPressed and showExperienceBarOnAlt and PlayerHasXpBarSlot() then
        if MainMenuExpBar then
            MainMenuExpBar:Show()
            MainMenuExpBar:SetAlpha(1)
        end
        -- Also show ExhaustionTick (from original)
        if module.SetExpBarVisibility then
            module:SetExpBarVisibility(true)
        end
        if module.SetExpBarAlpha then
            module:SetExpBarAlpha(1)
        end
    end
end

function module:HideExperienceBar()
    local hideExperienceBar = GetBoolSetting('hideExperienceBar', false)
    local showExperienceBarOnAlt = GetBoolSetting('showExperienceBarOnAlt', false)
    
    if not hideExperienceBar then
        if PlayerHasXpBarSlot() then
            if MainMenuExpBar then
                MainMenuExpBar:Show()
                MainMenuExpBar:SetAlpha(1)
            end
        end
        return
    end
    
    if IsAltPressed() and showExperienceBarOnAlt then
        return
    end
    
    if isRepBarAnimating or isRepBarTemporarilyVisible then
        return
    end
    
    if not PlayerHasXpBarSlot() then
        return
    end
    
    if module.IsExperienceBarOccupyingSpace and module:IsExperienceBarOccupyingSpace() then
        if MainMenuExpBar then
            MainMenuExpBar:Show()
            MainMenuExpBar:SetAlpha(0)
        end
    elseif MainMenuExpBar then
        MainMenuExpBar:Hide()
        MainMenuExpBar:SetAlpha(0)
        if module.SetExpBarVisibility then
            module:SetExpBarVisibility(false)
        end
        if module.SetExpBarAlpha then
            module:SetExpBarAlpha(0)
        end
    end
end

function module:UpdateExperienceBar()
    -- Не обновляем полосу опыта во время анимации
    if isXPBarAnimating then
        return
    end
    
    local hideExperienceBar = GetSetting('hideExperienceBar', false)
    
    if not hideExperienceBar then
        -- Если скрытие отключено - показываем полосу опыта
        if PlayerHasXpBarSlot() then
            if MainMenuExpBar then
                MainMenuExpBar:Show()
                MainMenuExpBar:SetAlpha(1)
            end
            -- Also show ExhaustionTick (from original)
            if module.SetExpBarVisibility then
                module:SetExpBarVisibility(true)
            end
            if module.SetExpBarAlpha then
                module:SetExpBarAlpha(1)
            end
        end
    else
        -- Если скрытие включено - скрываем по умолчанию
        if PlayerHasXpBarSlot() then
            if module.IsExperienceBarOccupyingSpace and module:IsExperienceBarOccupyingSpace() then
                if MainMenuExpBar then
                    MainMenuExpBar:Show()
                    MainMenuExpBar:SetAlpha(0)
                end
            elseif MainMenuExpBar then
                MainMenuExpBar:Hide()
                MainMenuExpBar:SetAlpha(0)
                if module.SetExpBarVisibility then
                    module:SetExpBarVisibility(false)
                end
                if module.SetExpBarAlpha then
                    module:SetExpBarAlpha(0)
                end
            end
        end
    end
end

-- Helper functions for experience bar (from original)
local function IsPlayerRested()
    return GetXPExhaustion() ~= nil -- Если бодрость есть, вернет true
end

local function SetBarVisibility(bar, show)
    if bar then
        if show then bar:Show() else bar:Hide() end
    end
end

local function SetBarAlpha(bar, alpha)
    if bar then
        bar:SetAlpha(alpha)
    end
end

-- Set experience bar visibility (from original)
function module:SetExpBarVisibility(show)
    SetBarVisibility(MainMenuExpBar, show)
    if ExhaustionTick then
        -- ExhaustionTick должен показываться вместе с полосой опыта
        -- если у игрока есть бодрость
        if show and IsPlayerRested() then
            SetBarVisibility(ExhaustionTick, true)
        else
            SetBarVisibility(ExhaustionTick, false)
        end
    end
end

-- Set experience bar alpha (from original)
function module:SetExpBarAlpha(alpha)
    SetBarAlpha(MainMenuExpBar, alpha)
    SetBarAlpha(ExhaustionTick, alpha) -- Добавлено: изменяем прозрачность `ExhaustionTick`
end

-- Update exhaustion tick (from original)
function module:UpdateExhaustionTick()
    if ExhaustionTick then
        -- ExhaustionTick должен показываться независимо от настроек полосы опыта
        -- если у игрока есть бодрость
        if IsPlayerRested() then
            ExhaustionTick:Show()
        else
            ExhaustionTick:Hide()
        end
    end
end

-- Handle XP update with animation (from original)
function module:HandleXPUpdate(eventSource)
    BarsDebug("experience gain event:", eventSource or "unknown")
    
    local hideExperienceBar = GetSetting('hideExperienceBar', false)
    local showExperienceBarOnGain = GetSetting('showExperienceBarOnGain', false)
    
    -- Проверяем, что игрок не максимального уровня
    if not IsBelowMaxLevel() then
        return
    end
    
    -- Если "Скрыть полосу опыта" отключено - полоса опыта должна быть видна всегда
    if not hideExperienceBar then
        return
    end
    
    -- Если "Скрыть полосу опыта" включено, но "Показывать при получении опыта" отключено - не показываем
    if not showExperienceBarOnGain then
        BarsDebug("show experience bar on gain disabled")
        return
    end
    
    -- Если анимация уже идет, не запускаем новую
    if isXPBarAnimating then
        BarsDebug("XP animation already in progress")
        return
    end
    
    BarsDebug("show experience bar on gain, starting fade in")
    
    isXPBarAnimating = true
    
    if not xpBarAnimationFrame then
        xpBarAnimationFrame = CreateFrame("Frame")
    end
    
    xpBarAnimationFrame:Show()
    
    BarsDebug("layout before xp fade in")
    self:UpdateBarsLayout("xp fade in")
    
    self:SetExpBarAlpha(0)
    self:SetExpBarVisibility(true)

    -- Получаем настройки времени fade
    xpBarFadeTime = GetSetting('experienceBarFadeTime', 0.4)
    xpBarShowTime = GetSetting('experienceBarShowTime', 1.1)
    
    -- Инициализируем переменные для анимации
    xpBarFadeStartTime = GetTime()
    xpBarFadeState = "fadeIn"
    xpBarLastUpdateTime = GetTime()
    
    -- Устанавливаем OnUpdate скрипт
    xpBarAnimationFrame:SetScript("OnUpdate", function(self, elapsed)
        if not isXPBarAnimating or not xpBarFadeState then
            self:SetScript("OnUpdate", nil)
            return
        end
        
        local currentTime = GetTime()
        
        if xpBarFadeState == "fadeIn" then
            local elapsed = currentTime - xpBarFadeStartTime
            if elapsed >= xpBarFadeTime then
                -- Завершаем fade in
                module:SetExpBarAlpha(1)
                xpBarFadeState = "visible"
                xpBarFadeStartTime = currentTime
                BarsDebug("experience fade in complete")
            else
                -- Продолжаем fade in
                local alpha = elapsed / xpBarFadeTime
                module:SetExpBarAlpha(alpha)
            end
        elseif xpBarFadeState == "visible" then
            local elapsed = currentTime - xpBarFadeStartTime
            if elapsed >= xpBarShowTime then
                -- Начинаем fade out
                xpBarFadeState = "fadeOut"
                xpBarFadeStartTime = currentTime
            end
        elseif xpBarFadeState == "fadeOut" then
            local elapsed = currentTime - xpBarFadeStartTime
            if elapsed >= xpBarFadeTime then
                -- Завершаем fade out
                module:SetExpBarAlpha(0)
                module:SetExpBarVisibility(false)
                isXPBarAnimating = false
                xpBarFadeState = nil
                xpBarFadeStartTime = nil
                xpBarLastUpdateTime = nil
                self:SetScript("OnUpdate", nil)
                BarsDebug("experience fade out complete")
                BarsDebug("layout after xp hide")
                module:UpdateBarsLayout("xp fade out complete")
            else
                -- Продолжаем fade out
                local alpha = 1 - (elapsed / xpBarFadeTime)
                module:SetExpBarAlpha(alpha)
            end
        end
    end)
end

-- Set reputation bar visibility
function module:SetRepBarVisibility(show)
    if ReputationWatchBar then
        if show then
            ReputationWatchBar:Show()
        else
            ReputationWatchBar:Hide()
        end
    else
        BarsDebug("SetRepBarVisibility: ReputationWatchBar not found")
    end
end

-- Set reputation bar alpha
function module:SetRepBarAlpha(alpha)
    if ReputationWatchBar then
        ReputationWatchBar:SetAlpha(alpha)
    end
    if ReputationWatchStatusBar then
        ReputationWatchStatusBar:SetAlpha(alpha)
    end
end

-- Handle reputation update with animation (mirrors HandleXPUpdate)
function module:HandleReputationUpdate(eventSource)
    BarsDebug("reputation changed event:", eventSource or "unknown")
    BarsDebug("reputation frame:", ReputationWatchBar, ReputationWatchStatusBar)
    
    local now = GetTime()
    if now - lastRepTriggerTime < REP_TRIGGER_DEBOUNCE then
        BarsDebug("reputation trigger debounced")
        return
    end
    lastRepTriggerTime = now
    
    local hideReputationBar = GetSetting('hideReputationBar', false)
    local showReputationBarOnGain = GetSetting('showReputationBarOnGain', false)
    
    if not GetWatchedFactionInfo() then
        BarsDebug("no watched faction, skipping reputation show")
        return
    end
    
    if not hideReputationBar then
        BarsDebug("reputation bar not hidden, no temporary show needed")
        return
    end
    
    if not showReputationBarOnGain then
        BarsDebug("show reputation bar on gain disabled")
        return
    end
    
    if not ReputationWatchBar then
        BarsDebug("reputation frame not found, cannot show")
        return
    end
    
    if IsRepGainSuppressed() then
        BarsDebug("reputation gain suppressed until", repGainSuppressUntil)
        CommitWatchedFactionSnapshot()
        return
    end
    
    if isRepBarAnimating then
        BarsDebug("reputation animation already in progress")
        return
    end
    
    SetRepGainSuppress()
    
    BarsDebug("show reputation bar on reputation gain, starting fade in")
    
    isRepBarTemporarilyVisible = true
    BarsDebug("rep temporary visible = true")
    BarsDebug("layout before rep fade in")
    self:UpdateBarsLayout("rep fade in")
    
    isRepBarAnimating = true
    
    if not repBarAnimationFrame then
        repBarAnimationFrame = CreateFrame("Frame")
    end
    
    repBarAnimationFrame:Show()
    
    self:SetRepBarAlpha(0)
    
    repBarFadeTime = GetSetting('reputationBarFadeTime', 0.4)
    repBarShowTime = GetSetting('reputationBarShowTime', 1.1)
    
    repBarFadeStartTime = GetTime()
    repBarFadeState = "fadeIn"
    
    repBarAnimationFrame:SetScript("OnUpdate", function(self, elapsed)
        if not isRepBarAnimating or not repBarFadeState then
            self:SetScript("OnUpdate", nil)
            return
        end
        
        local currentTime = GetTime()
        
        if repBarFadeState == "fadeIn" then
            local fadeElapsed = currentTime - repBarFadeStartTime
            if fadeElapsed >= repBarFadeTime then
                module:SetRepBarAlpha(1)
                repBarFadeState = "visible"
                repBarFadeStartTime = currentTime
                BarsDebug("reputation fade in complete")
            else
                module:SetRepBarAlpha(fadeElapsed / repBarFadeTime)
            end
        elseif repBarFadeState == "visible" then
            local visibleElapsed = currentTime - repBarFadeStartTime
            if visibleElapsed >= repBarShowTime then
                repBarFadeState = "fadeOut"
                repBarFadeStartTime = currentTime
                BarsDebug("reputation fade out starting")
            end
        elseif repBarFadeState == "fadeOut" then
            -- Не скрываем, пока удерживается Alt (если включен показ по Alt)
            local showReputationBarOnAlt = GetSetting('showReputationBarOnAlt', false)
            if SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() and showReputationBarOnAlt then
                module:SetRepBarAlpha(1)
                repBarFadeState = "visible"
                repBarFadeStartTime = currentTime
                BarsDebug("reputation fade out paused: ALT held")
                return
            end
            
            local fadeElapsed = currentTime - repBarFadeStartTime
            if fadeElapsed >= repBarFadeTime then
                module:SetRepBarAlpha(0)
                module:SetRepBarVisibility(false)
                isRepBarAnimating = false
                isRepBarTemporarilyVisible = false
                repBarFadeState = nil
                repBarFadeStartTime = nil
                self:SetScript("OnUpdate", nil)
                BarsDebug("reputation fade out complete")
                BarsDebug("rep temporary visible = false")
                BarsDebug("layout after rep hide")
                module:UpdateBarsLayout("rep fade out complete")
            else
                module:SetRepBarAlpha(1 - (fadeElapsed / repBarFadeTime))
            end
        end
    end)
end

-- Reputation Bar Functions
function module:ShowReputationBar()
    local hideReputationBar = GetSetting('hideReputationBar', false)
    local showReputationBarOnAlt = GetSetting('showReputationBarOnAlt', false)
    
    if not hideReputationBar then
        -- Если скрытие отключено - показываем полосу репутации
        if GetWatchedFactionInfo() then
            if ReputationWatchBar then
                ReputationWatchBar:Show()
                ReputationWatchBar:SetAlpha(1)
            end
        end
        return
    end
    
    -- Показываем полосу репутации только если:
    -- 1. "Скрыть полосу репутации" включено И
	-- 2. нажат Alt И включена опция "Показывать при нажатии Alt"
    local isInCombat = UnitAffectingCombat("player")
    local isAltPressed = SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()
	if hideReputationBar and isAltPressed and showReputationBarOnAlt and GetWatchedFactionInfo() then
        if ReputationWatchBar then
            ReputationWatchBar:Show()
            ReputationWatchBar:SetAlpha(1)
        end
    end
end

function module:HideReputationBar()
    local hideReputationBar = GetSetting('hideReputationBar', false)
    local showReputationBarOnAlt = GetSetting('showReputationBarOnAlt', false)
    
    if not hideReputationBar then
        -- Если скрытие отключено - показываем полосу репутации
        if GetWatchedFactionInfo() then
            if ReputationWatchBar then
                ReputationWatchBar:Show()
                ReputationWatchBar:SetAlpha(1)
            end
        end
        return
    end
    
	-- Если нажат Alt и включена опция показа при Alt - не скрываем
	if SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() and showReputationBarOnAlt then
        return
    end
    
    -- Временный показ по изменению репутации управляется анимацией
    if isRepBarAnimating or isRepBarTemporarilyVisible then
        BarsDebug("HideReputationBar skipped: reputation animation in progress")
        return
    end
    
    -- Скрываем полосу репутации
    if ReputationWatchBar then
        ReputationWatchBar:Hide()
        ReputationWatchBar:SetAlpha(0)
        BarsDebug("reputation bar hidden")
    end
end

function module:UpdateReputationBar()
    if isRepBarAnimating or isRepBarTemporarilyVisible then
        BarsDebug("UpdateReputationBar skipped: reputation animation in progress")
        return
    end
    
    local hideReputationBar = GetSetting('hideReputationBar', false)
    
    BarsDebug("UpdateReputationBar hide=", hideReputationBar)
    
    if not hideReputationBar then
        -- Если скрытие отключено - показываем полосу репутации
        if GetWatchedFactionInfo() then
            if ReputationWatchBar then
                ReputationWatchBar:Show()
                ReputationWatchBar:SetAlpha(1)
            end
        end
    else
        -- Если скрытие включено - скрываем по умолчанию
        if ReputationWatchBar then
            ReputationWatchBar:Hide()
            ReputationWatchBar:SetAlpha(0)
        end
    end
end

-- Side Panels Functions
function module:ShowSidePanels()
    local hideSidePanels = GetSetting('hideSidePanels', false)
    local showSidePanelsOnAlt = GetSetting('showSidePanelsOnAlt', false)
    
    if not hideSidePanels then
        -- Если скрытие отключено - показываем панели
        if MultiBarRight then
            MultiBarRight:SetAlpha(1)
            MultiBarRight:EnableMouse(true)
        end
        if MultiBarLeft then
            MultiBarLeft:SetAlpha(1)
            MultiBarLeft:EnableMouse(true)
        end
        return
    end
    
    -- Показываем панели только если:
    -- 1. "Скрыть боковые панели" включено И
	-- 2. нажат Alt И включена опция "Показывать при нажатии Alt"
    local isInCombat = UnitAffectingCombat("player")
    local isAltPressed = SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()
	if hideSidePanels and isAltPressed and showSidePanelsOnAlt then
        if MultiBarRight then
            MultiBarRight:SetAlpha(1)
        end
        if MultiBarLeft then
            MultiBarLeft:SetAlpha(1)
        end
    end
end

function module:HideSidePanels()
    local hideSidePanels = GetSetting('hideSidePanels', false)
    local showSidePanelsOnAlt = GetSetting('showSidePanelsOnAlt', false)
    
    if not hideSidePanels then
        -- Если скрытие отключено - показываем панели
        if MultiBarRight then
            MultiBarRight:SetAlpha(1)
            MultiBarRight:EnableMouse(true)
        end
        if MultiBarLeft then
            MultiBarLeft:SetAlpha(1)
            MultiBarLeft:EnableMouse(true)
        end
        return
    end
    
	-- Если нажат Alt и включена опция показа при Alt - не скрываем
	if SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() and showSidePanelsOnAlt then
        return
    end
    
    -- Скрываем панели
    if MultiBarRight then
        MultiBarRight:SetAlpha(0)
    end
    if MultiBarLeft then
        MultiBarLeft:SetAlpha(0)
    end
end

function module:UpdateSidePanels()
    local hideSidePanels = GetSetting('hideSidePanels', false)
    
    if not hideSidePanels then
        -- Если скрытие отключено - показываем панели
        if MultiBarRight then
            MultiBarRight:SetAlpha(1)
            MultiBarRight:EnableMouse(true)
        end
        if MultiBarLeft then
            MultiBarLeft:SetAlpha(1)
            MultiBarLeft:EnableMouse(true)
        end
    else
        -- Если скрытие включено - скрываем по умолчанию
        if MultiBarRight then
            MultiBarRight:SetAlpha(0)
        end
        if MultiBarLeft then
            MultiBarLeft:SetAlpha(0)
        end
    end
end

-- Variables for mouse and panel control (from original) - EXACT COPY
local isMouseOverPanels = false -- Флаг для отслеживания наведения мыши на панели
local mouseLeaveTimer = 0 -- Таймер для задержки скрытия панелей
local isPanelsFading = false -- Флаг для отслеживания анимации исчезновения панелей
local panelsFadeTimer = 0 -- Таймер для анимации исчезновения панелей
local MOUSE_LEAVE_DELAY = 0.04 -- Задержка в секундах перед скрытием
local PANELS_FADE_DURATION = 0.04 -- Время плавного исчезновения панелей
local lastPanelUpdate = 0 -- Дебаунс для предотвращения избыточных обновлений
local PANEL_UPDATE_DEBOUNCE = 0.1 -- Дебаунс в секундах для обновлений панелей
local isFadingOutAfterCombat = false -- Флаг для откладывания операций с панелями при выходе из боя

-- Animation control now handled by SarychUI.CombatAnimations

-- Set panels visibility (from original) - EXACT COPY
function module:SetPanelsVisibility(show)
    local hideSidePanels = GetSetting('hideSidePanels', false)
    
    -- Если скрытие отключено - принудительно показываем панели и сбрасываем флаги мыши
    if not hideSidePanels then
        show = true
        isMouseOverPanels = false
        mouseLeaveTimer = 0
        isPanelsFading = false
        panelsFadeTimer = 0
    -- Если мышь наведена ИЛИ таймер еще идет - принудительно показываем
    elseif isMouseOverPanels or mouseLeaveTimer > 0 then
        show = true
    end
    
    -- Оптимизация: дебаунс для предотвращения избыточных обновлений панелей
    local currentTime = GetTime()
    if currentTime - lastPanelUpdate < PANEL_UPDATE_DEBOUNCE and not (isMouseOverPanels or mouseLeaveTimer > 0) then
        return -- Пропускаем слишком частые обновления, но не при наведении мыши или таймере
    end
    lastPanelUpdate = currentTime
    
    -- Оптимизация: откладываем операции с панелями если идет выход из боя
    if isFadingOutAfterCombat then
        C_Timer.After(0.1, function()
            module:SetPanelsVisibility(show)
        end)
        return
    end
    
    -- Управляем видимостью и взаимодействием с панелями
    if MultiBarRight then
        if show then
            MultiBarRight:SetAlpha(1)
            MultiBarRight:EnableMouse(true)
            -- Оптимизация: обновляем только видимые кнопки
            for i = 1, 12 do
                local button = _G["MultiBarRightButton" .. i]
                if button and button:IsVisible() then
                    button:EnableMouse(true)
                end
            end
        else
            MultiBarRight:SetAlpha(0)
            -- НЕ отключаем EnableMouse - оставляем возможность взаимодействия
            -- Оптимизация: обновляем только видимые кнопки
            for i = 1, 12 do
                local button = _G["MultiBarRightButton" .. i]
                if button and button:IsVisible() then
                    -- НЕ отключаем EnableMouse для кнопок
                end
            end
        end
    end
    
    if MultiBarLeft then
        if show then
            MultiBarLeft:SetAlpha(1)
            MultiBarLeft:EnableMouse(true)
            -- Оптимизация: обновляем только видимые кнопки
            for i = 1, 12 do
                local button = _G["MultiBarLeftButton" .. i]
                if button and button:IsVisible() then
                    button:EnableMouse(true)
                end
            end
        else
            MultiBarLeft:SetAlpha(0)
            -- НЕ отключаем EnableMouse - оставляем возможность взаимодействия
            -- Оптимизация: обновляем только видимые кнопки
            for i = 1, 12 do
                local button = _G["MultiBarLeftButton" .. i]
                if button and button:IsVisible() then
                    -- НЕ отключаем EnableMouse для кнопок
                end
            end
        end
    end
end

-- Handle mouse over panels (from original) - EXACT COPY
function module:HandleMouseOverPanels(show)
    -- Проверяем, включена ли настройка скрытия панелей
    local hideSidePanels = GetSetting('hideSidePanels', false)
    
    -- Если скрытие отключено - панели всегда видимы, не обрабатываем мышь
    if not hideSidePanels then
        return
    end
    
    isMouseOverPanels = show
    
    if show then
        -- Сбрасываем таймеры и показываем панели при наведении мыши
        mouseLeaveTimer = 0
        isPanelsFading = false
        panelsFadeTimer = 0
        module:SetPanelsVisibility(true)
    else
        -- Запускаем таймер для задержки скрытия панелей
        mouseLeaveTimer = MOUSE_LEAVE_DELAY
    end
end

-- Setup panel mouse handlers (from original) - EXACT COPY
function module:SetupPanelMouseHandlers()
    -- Enable() может вызываться повторно: без этой защиты каждый раз создавался
    -- новый трекер и ещё один повторяющийся таймер на 20 Гц.
    if module.mouseTrackerTimer or module.__sarMouseTracker then return end

    -- Создаем глобальный трекер мыши для панелей
    local mouseTracker = CreateFrame("Frame", "PanelMouseTracker", UIParent)
    module.__sarMouseTracker = mouseTracker
    local isMouseOverAnyPanel = false
    local lastMouseCheck = 0
    
    local function CheckMouseOverPanels()
        -- Проверяем, включена ли настройка скрытия панелей
        local hideSidePanels = GetSetting('hideSidePanels', false)
        if not hideSidePanels then
            return -- Если скрытие отключено, не проверяем наведение мыши
        end
        
        local mouseX, mouseY = GetCursorPosition()
        local uiScale = UIParent:GetScale()
        mouseX = mouseX / uiScale
        mouseY = mouseY / uiScale
        
        local overAnyPanel = false
        
        -- Проверяем MultiBarRight
        if MultiBarRight and MultiBarRight:IsVisible() then
            local left, bottom, width, height = MultiBarRight:GetRect()
            if mouseX >= left and mouseX <= left + width and mouseY >= bottom and mouseY <= bottom + height then
                overAnyPanel = true
            end
        end
        
        -- Проверяем MultiBarLeft
        if MultiBarLeft and MultiBarLeft:IsVisible() then
            local left, bottom, width, height = MultiBarLeft:GetRect()
            if mouseX >= left and mouseX <= left + width and mouseY >= bottom and mouseY <= bottom + height then
                overAnyPanel = true
            end
        end
        
        -- Обновляем состояние только при изменении
        if overAnyPanel ~= isMouseOverAnyPanel then
            isMouseOverAnyPanel = overAnyPanel
            module:HandleMouseOverPanels(overAnyPanel)
        end
    end
    
    -- Используем AceTimer вместо OnUpdate для снижения нагрузки (оптимизация производительности)
    -- Проверяем каждые 0.05 секунды вместо каждого кадра
    if AceTimer then
        module.mouseTrackerTimer = AceTimer:ScheduleRepeatingTimer(CheckMouseOverPanels, 0.05)
    else
        -- Fallback на OnUpdate, если AceTimer недоступен
        mouseTracker:SetScript("OnUpdate", function(self, elapsed)
            lastMouseCheck = lastMouseCheck + elapsed
            if lastMouseCheck > 0.05 then
                lastMouseCheck = 0
                CheckMouseOverPanels()
            end
        end)
    end
    
    -- Настройка для MultiBarRight
    if MultiBarRight then
        -- Добавляем обработчики для всех кнопок MultiBarRight
        for i = 1, 12 do
            local button = _G["MultiBarRightButton" .. i]
            if button then
                local originalOnEnter = button:GetScript("OnEnter")
                local originalOnLeave = button:GetScript("OnLeave")
                
                button:SetScript("OnEnter", function(self, ...)
                    -- Проверяем, включена ли настройка скрытия панелей
                    local hideSidePanels = GetSetting('hideSidePanels', false)
                    if hideSidePanels then
                        module:HandleMouseOverPanels(true)
                    end
                    if originalOnEnter then
                        originalOnEnter(self, ...)
                    end
                end)
                button:SetScript("OnLeave", function(self, ...)
                    -- Небольшая задержка перед скрытием, чтобы трекер мыши успел проверить позицию
                    C_Timer.After(0.05, function()
                        -- Проверяем, действительно ли мышь покинула область панели
                        local mouseX, mouseY = GetCursorPosition()
                        local uiScale = UIParent:GetScale()
                        mouseX = mouseX / uiScale
                        mouseY = mouseY / uiScale
                        
                        local stillOverPanel = false
                        if MultiBarRight and MultiBarRight:IsVisible() then
                            local left, bottom, width, height = MultiBarRight:GetRect()
                            if mouseX >= left and mouseX <= left + width and mouseY >= bottom and mouseY <= bottom + height then
                                stillOverPanel = true
                            end
                        end
                        if MultiBarLeft and MultiBarLeft:IsVisible() then
                            local left, bottom, width, height = MultiBarLeft:GetRect()
                            if mouseX >= left and mouseX <= left + width and mouseY >= bottom and mouseY <= bottom + height then
                                stillOverPanel = true
                            end
                        end
                        
                        if not stillOverPanel then
                            module:HandleMouseOverPanels(false)
                        end
                    end)
                    if originalOnLeave then
                        originalOnLeave(self, ...)
                    end
                end)
            end
        end
    end
    
    -- Настройка для MultiBarLeft
    if MultiBarLeft then
        -- Добавляем обработчики для всех кнопок MultiBarLeft
        for i = 1, 12 do
            local button = _G["MultiBarLeftButton" .. i]
            if button then
                local originalOnEnter = button:GetScript("OnEnter")
                local originalOnLeave = button:GetScript("OnLeave")
                
                button:SetScript("OnEnter", function(self, ...)
                    -- Проверяем, включена ли настройка скрытия панелей
                    local hideSidePanels = GetSetting('hideSidePanels', false)
                    if hideSidePanels then
                        module:HandleMouseOverPanels(true)
                    end
                    if originalOnEnter then
                        originalOnEnter(self, ...)
                    end
                end)
                button:SetScript("OnLeave", function(self, ...)
                    -- Проверяем, включена ли настройка показа панелей при Alt
                    local showSidePanelsOnAlt = GetSetting('showSidePanelsOnAlt', false)
                    if showSidePanelsOnAlt then
                        -- Небольшая задержка перед скрытием, чтобы трекер мыши успел проверить позицию
                        C_Timer.After(0.05, function()
                            -- Проверяем, действительно ли мышь покинула область панели
                            local mouseX, mouseY = GetCursorPosition()
                            local uiScale = UIParent:GetScale()
                            mouseX = mouseX / uiScale
                            mouseY = mouseY / uiScale
                            
                            local stillOverPanel = false
                            if MultiBarRight and MultiBarRight:IsVisible() then
                                local left, bottom, width, height = MultiBarRight:GetRect()
                                if mouseX >= left and mouseX <= left + width and mouseY >= bottom and mouseY <= bottom + height then
                                    stillOverPanel = true
                                end
                            end
                            if MultiBarLeft and MultiBarLeft:IsVisible() then
                                local left, bottom, width, height = MultiBarLeft:GetRect()
                                if mouseX >= left and mouseX <= left + width and mouseY >= bottom and mouseY <= bottom + height then
                                    stillOverPanel = true
                                end
                            end
                            
                            if not stillOverPanel then
                                module:HandleMouseOverPanels(false)
                            end
                        end)
                    end
                    if originalOnLeave then
                        originalOnLeave(self, ...)
                    end
                end)
            end
        end
    end
end

-- Setup throttled timer handler for panels (оптимизация производительности)
-- Используем AceTimer вместо OnUpdate для снижения нагрузки
function module:SetupPanelOnUpdate()
    if not module.panelUpdateFrame then
        module.panelUpdateFrame = CreateFrame("Frame")
    end
    
    -- Используем AceTimer вместо OnUpdate для снижения нагрузки
    if AceTimer then
        -- Отменяем предыдущий таймер, если он существует
        if module.panelUpdateTimer then
            AceTimer:CancelTimer(module.panelUpdateTimer)
            module.panelUpdateTimer = nil
        end
        
        -- Создаем throttled таймер (обновление каждые 0.02 секунды для плавной анимации)
        local updateInterval = 0.02
        module.panelUpdateTimer = AceTimer:ScheduleRepeatingTimer(function()
            -- Нечего анимировать — выходим до чтения настроек (тик идёт 50 раз/сек).
            if mouseLeaveTimer <= 0 and not isPanelsFading then return end

            local hideSidePanels = GetSetting('hideSidePanels', false)
            
            -- Обрабатываем таймер скрытия панелей только если настройка включена
            if hideSidePanels and mouseLeaveTimer > 0 then
                mouseLeaveTimer = mouseLeaveTimer - updateInterval
                if mouseLeaveTimer <= 0 then
                    -- Запускаем плавное исчезновение панелей только если Alt не нажат
                    if not (SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()) then
                        isPanelsFading = true
                        panelsFadeTimer = PANELS_FADE_DURATION
                    end
                end
            end
            
            -- Обрабатываем анимацию исчезновения панелей только если настройка включена
            if hideSidePanels and isPanelsFading then
                panelsFadeTimer = panelsFadeTimer - updateInterval
                if panelsFadeTimer <= 0 then
                    -- Завершаем анимацию и скрываем панели
                    isPanelsFading = false
                    module:SetPanelsVisibility(false)
                else
                    -- Плавно уменьшаем прозрачность панелей
                    local alpha = panelsFadeTimer / PANELS_FADE_DURATION
                    if MultiBarRight then
                        MultiBarRight:SetAlpha(alpha)
                    end
                    if MultiBarLeft then
                        MultiBarLeft:SetAlpha(alpha)
                    end
                end
            end
        end, updateInterval)
    else
        -- Fallback на OnUpdate, если AceTimer недоступен
        module.panelUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
            -- Нечего анимировать — выходим до чтения настроек.
            if mouseLeaveTimer <= 0 and not isPanelsFading then return end

            local hideSidePanels = GetSetting('hideSidePanels', false)
            
            -- Обрабатываем таймер скрытия панелей только если настройка включена
            if hideSidePanels and mouseLeaveTimer > 0 then
                mouseLeaveTimer = mouseLeaveTimer - elapsed
                if mouseLeaveTimer <= 0 then
                    -- Запускаем плавное исчезновение панелей только если Alt не нажат
                    if not (SarychUI.AltMode and SarychUI.AltMode:IsAltPressed()) then
                        isPanelsFading = true
                        panelsFadeTimer = PANELS_FADE_DURATION
                    end
                end
            end
            
            -- Обрабатываем анимацию исчезновения панелей только если настройка включена
            if hideSidePanels and isPanelsFading then
                panelsFadeTimer = panelsFadeTimer - elapsed
                if panelsFadeTimer <= 0 then
                    -- Завершаем анимацию и скрываем панели
                    isPanelsFading = false
                    module:SetPanelsVisibility(false)
                else
                    -- Плавно уменьшаем прозрачность панелей
                    local alpha = panelsFadeTimer / PANELS_FADE_DURATION
                    if MultiBarRight then
                        MultiBarRight:SetAlpha(alpha)
                    end
                    if MultiBarLeft then
                        MultiBarLeft:SetAlpha(alpha)
                    end
                end
            end
        end)
    end
end

-- Fade out page numbers function (delegated to CombatAnimations)
function module:FadeOutPageNumbers(fadeTime)
    if SarychUI.CombatAnimations then
        SarychUI.CombatAnimations:FadeOutPageNumbers(fadeTime)
    end
end

-- Fade in page numbers function (delegated to CombatAnimations)
function module:FadeInPageNumbers()
    if SarychUI.CombatAnimations then
        SarychUI.CombatAnimations:FadeInPageNumbers()
    end
end

-- Main function to apply all appearance settings
function module:ApplyAppearanceSettings()
    
    -- Apply gryphons
    ApplyGryphonsSettings()
    
    -- Apply page buttons
    ApplyPageButtonsSettings()
    
    -- Apply keyring button
    ApplyKeyringButtonSettings()
    
    -- Apply max level bar
    ApplyMaxLevelBarSettings()
    
    -- Apply background textures
    ApplyActionBarBackgrounds()
    ApplySecondaryPanelsBackgrounds()
    
    -- Apply transparency settings
    ApplyMicroMenuStyle()
    ApplyButtonBorderAlpha()
    ApplyMicroMenuAlpha()
    
    -- Apply bar settings
    ApplyExperienceBarSettings()
    ApplyReputationBarSettings()
    ApplySidePanelsSettings()
end

-- Export functions to module
module.ApplyGryphonsSettings = ApplyGryphonsSettings
module.ApplyPageButtonsSettings = ApplyPageButtonsSettings
module.ApplyKeyringButtonSettings = ApplyKeyringButtonSettings
module.ApplyMaxLevelBarSettings = ApplyMaxLevelBarSettings
module.ApplyActionBarBackgrounds = ApplyActionBarBackgrounds
module.ApplySecondaryPanelsBackgrounds = ApplySecondaryPanelsBackgrounds
module.ApplyButtonBorderAlpha = ApplyButtonBorderAlpha
module.ApplyMicroMenuStyle = ApplyMicroMenuStyle
module.ApplyMicroMenuAlpha = ApplyMicroMenuAlpha
module.ApplyExperienceBarSettings = ApplyExperienceBarSettings
module.ApplyReputationBarSettings = ApplyReputationBarSettings
module.ApplySidePanelsSettings = ApplySidePanelsSettings

-- Update keyring button visibility (for real-time settings) - EXACT COPY from original
function module:UpdateKeyringButton()
    local hideKeyringButton = GetSetting('hideKeyringButton', false)
    
    if hideKeyringButton then
        if KeyRingButton then
            KeyRingButton:Hide()
            if KeyRingButton.SetScript then
                KeyRingButton:SetScript("OnShow", KeyRingButton.Hide)
            end
            -- Принудительно обновляем UI
            if KeyRingButton.GetParent then
                local parent = KeyRingButton:GetParent()
                if parent and parent.UpdateVisible then
                    parent:UpdateVisible()
                end
            end
        end
    else
        if KeyRingButton then
            KeyRingButton:Show()
            if KeyRingButton.SetScript then
                KeyRingButton:SetScript("OnShow", nil)
            end
            -- Принудительно обновляем UI
            if KeyRingButton.GetParent then
                local parent = KeyRingButton:GetParent()
                if parent and parent.UpdateVisible then
                    parent:UpdateVisible()
                end
            end
            -- Альтернативный способ показа через SetShown
            if KeyRingButton.SetShown then
                KeyRingButton:SetShown(true)
            end
            -- Дополнительная попытка обновления через таймер
            C_Timer.After(0.1, function()
                if KeyRingButton and KeyRingButton:IsVisible() then
                    KeyRingButton:Show()
                    if KeyRingButton.SetShown then
                        KeyRingButton:SetShown(true)
                    end
                end
            end)
            -- Принудительное обновление главной панели
            if MainMenuBar and MainMenuBar.UpdateVisible then
                MainMenuBar:UpdateVisible()
            end
            -- Попытка обновления через SetAlpha
            if KeyRingButton.SetAlpha then
                KeyRingButton:SetAlpha(1)
            end
            -- Попытка обновления через OnUpdate
            if KeyRingButton.SetScript then
                KeyRingButton:SetScript("OnUpdate", function(self, elapsed)
                    if self:IsVisible() then
                        self:SetScript("OnUpdate", nil)
                    else
                        self:Show()
                    end
                end)
            end
        end
    end
end

-- Update page buttons visibility (for real-time settings) - EXACT COPY from original
function module:UpdatePageButtons()
    local hidePageButtons = GetSetting('hidePageButtons', false)
    
    if hidePageButtons then
        local pageButtons = {
            ActionBarUpButton, ActionBarDownButton
        }
        for _, button in ipairs(pageButtons) do
            if button then
                button:Hide()
                if button.SetScript then
                    button:SetScript("OnShow", button.Hide)
                end
                -- Принудительно обновляем UI
                if button.GetParent then
                    local parent = button:GetParent()
                    if parent and parent.UpdateVisible then
                        parent:UpdateVisible()
                    end
                end
            end
        end
    else
        local pageButtons = {
            ActionBarUpButton, ActionBarDownButton
        }
        for _, button in ipairs(pageButtons) do
            if button then
                button:Show()
                if button.SetScript then
                    button:SetScript("OnShow", nil)
                end
                -- Принудительно обновляем UI
                if button.GetParent then
                    local parent = button:GetParent()
                    if parent and parent.UpdateVisible then
                        parent:UpdateVisible()
                    end
                end
                -- Альтернативный способ показа через SetShown
                if button.SetShown then
                    button:SetShown(true)
                end
                -- Дополнительная попытка обновления через таймер
                C_Timer.After(0.1, function()
                    if button and button:IsVisible() then
                        button:Show()
                        if button.SetShown then
                            button:SetShown(true)
                        end
                    end
                end)
                -- Принудительное обновление главной панели
                if MainMenuBar and MainMenuBar.UpdateVisible then
                    MainMenuBar:UpdateVisible()
                end
                -- Попытка обновления через SetAlpha
                if button.SetAlpha then
                    button:SetAlpha(1)
                end
                -- Попытка обновления через OnUpdate
                if button.SetScript then
                    button:SetScript("OnUpdate", function(self, elapsed)
                        if self:IsVisible() then
                            self:SetScript("OnUpdate", nil)
                        else
                            self:Show()
                        end
                    end)
                end
            end
        end
    end
end

-- Export new functions for real-time updates
module.ShowPageNumbers = module.ShowPageNumbers
module.HidePageNumbers = module.HidePageNumbers
module.UpdatePageNumbers = module.UpdatePageNumbers
module.FadeOutPageNumber = module.FadeOutPageNumber
module.FadeInPageNumber = module.FadeInPageNumber
module.ShowExperienceBar = module.ShowExperienceBar
module.HideExperienceBar = module.HideExperienceBar
module.UpdateExperienceBar = module.UpdateExperienceBar
module.SetExpBarVisibility = module.SetExpBarVisibility
module.SetExpBarAlpha = module.SetExpBarAlpha
module.UpdateExhaustionTick = module.UpdateExhaustionTick
module.HandleXPUpdate = module.HandleXPUpdate
module.IsExperienceBarOccupyingSpace = module.IsExperienceBarOccupyingSpace
module.IsReputationBarOccupyingSpace = module.IsReputationBarOccupyingSpace
module.ApplyBarsVisualStateAfterLayout = module.ApplyBarsVisualStateAfterLayout
module.UpdateBarsLayout = module.UpdateBarsLayout
module.ApplyCollapsedBarsLayout = module.ApplyCollapsedBarsLayout
module.ShouldConfigureBlizzardBars = module.ShouldConfigureBlizzardBars
module.OnUpdateFactionEvent = module.OnUpdateFactionEvent
module.OnCombatFactionChangeEvent = module.OnCombatFactionChangeEvent
module.SetRepBarVisibility = module.SetRepBarVisibility
module.SetRepBarAlpha = module.SetRepBarAlpha
module.HandleReputationUpdate = module.HandleReputationUpdate
module.ShowReputationBar = module.ShowReputationBar
module.HideReputationBar = module.HideReputationBar
module.UpdateReputationBar = module.UpdateReputationBar
module.ShowSidePanels = module.ShowSidePanels
module.HideSidePanels = module.HideSidePanels
module.UpdateSidePanels = module.UpdateSidePanels
module.SetPanelsVisibility = module.SetPanelsVisibility
module.HandleMouseOverPanels = module.HandleMouseOverPanels
module.SetupPanelMouseHandlers = module.SetupPanelMouseHandlers
module.SetupPanelOnUpdate = module.SetupPanelOnUpdate
module.UpdateKeyringButton = module.UpdateKeyringButton
module.UpdatePageButtons = module.UpdatePageButtons
module.FadeOutPageNumbers = module.FadeOutPageNumbers
module.FadeInPageNumbers = module.FadeInPageNumbers

-- Combat events now handled by SarychUI.CombatAnimations