local SuiTimer = select(2, ...).Compat.Timer
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

local GetSetting
local classicXpOriginal

local function SaveGeometry(region)
    if not region then return nil end
    local geometry = {
        width = region:GetWidth(),
        height = region:GetHeight(),
        points = {},
    }
    for index = 1, region:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = region:GetPoint(index)
        geometry.points[index] = { point, relativeTo, relativePoint, x, y }
    end
    return geometry
end

local function RestoreGeometry(region, geometry)
    if not region or not geometry then return end
    region:SetWidth(geometry.width)
    region:SetHeight(geometry.height)
    region:ClearAllPoints()
    for _, point in ipairs(geometry.points) do
        region:SetPoint(point[1], point[2], point[3], point[4], point[5])
    end
end

function module:ApplyClassicXpGeometry()
    if self._bootBarStyle ~= "classic" or not MainMenuExpBar then return end
    if not GetSetting('enabled', false) then return end

    if not classicXpOriginal then
        classicXpOriginal = {
            bar = SaveGeometry(MainMenuExpBar),
            textures = {},
            exhaustion = SaveGeometry(ExhaustionLevelFillBar),
        }
        for index = 0, 3 do
            classicXpOriginal.textures[index] = SaveGeometry(_G["MainMenuXPBarTexture" .. index])
        end
    end

    MainMenuExpBar:SetHeight(11)
    if ExhaustionLevelFillBar then ExhaustionLevelFillBar:SetHeight(11) end
    local offsets = { -384, -128, 128, 384 }
    for index = 0, 3 do
        local texture = _G["MainMenuXPBarTexture" .. index]
        if texture then
            texture:SetHeight(11)
            texture:ClearAllPoints()
            texture:SetPoint("BOTTOM", MainMenuExpBar, "BOTTOM", offsets[index + 1], 0)
        end
    end
end

function module:RestoreClassicXpGeometry()
    if not classicXpOriginal then return end
    RestoreGeometry(MainMenuExpBar, classicXpOriginal.bar)
    RestoreGeometry(ExhaustionLevelFillBar, classicXpOriginal.exhaustion)
    for index = 0, 3 do
        RestoreGeometry(_G["MainMenuXPBarTexture" .. index], classicXpOriginal.textures[index])
    end
    classicXpOriginal = nil
end

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
GetSetting = function(key, default)
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

local xpOverlayOriginalAlpha = {}

function module:ApplyExperienceOverlayVisibility()
    local hidden = GetSetting('enabled', false)
        and self._bootBarStyle ~= "dragon"
        and GetSetting('hideExperienceOverlayTextures', false)
    for index = 0, 3 do
        local texture = _G["MainMenuXPBarTexture" .. index]
        if texture then
            if hidden then
                if xpOverlayOriginalAlpha[index] == nil then
                    xpOverlayOriginalAlpha[index] = texture:GetAlpha()
                end
                texture:SetAlpha(0)
            elseif xpOverlayOriginalAlpha[index] ~= nil then
                texture:SetAlpha(xpOverlayOriginalAlpha[index])
                xpOverlayOriginalAlpha[index] = nil
            end
        end
    end
end

function module:RestoreExperienceOverlayVisibility()
    for index = 0, 3 do
        local texture = _G["MainMenuXPBarTexture" .. index]
        if texture and xpOverlayOriginalAlpha[index] ~= nil then
            texture:SetAlpha(xpOverlayOriginalAlpha[index])
        end
        xpOverlayOriginalAlpha[index] = nil
    end
end

local reputationOverlayOriginalAlpha = {}
local reputationOverlayPrefixes = { "ReputationXPBarTexture", "ReputationWatchBarTexture" }

function module:ApplyReputationOverlayVisibility()
    local hidden = GetSetting('enabled', false)
        and self._bootBarStyle ~= "dragon"
        and GetSetting('hideReputationOverlayTextures', false)
    for _, prefix in ipairs(reputationOverlayPrefixes) do
        for index = 0, 3 do
            local name = prefix .. index
            local texture = _G[name]
            if texture then
                if hidden then
                    if reputationOverlayOriginalAlpha[name] == nil then
                        reputationOverlayOriginalAlpha[name] = texture:GetAlpha()
                    end
                    texture:SetAlpha(0)
                elseif reputationOverlayOriginalAlpha[name] ~= nil then
                    texture:SetAlpha(reputationOverlayOriginalAlpha[name])
                    reputationOverlayOriginalAlpha[name] = nil
                end
            end
        end
    end
end

function module:RestoreReputationOverlayVisibility()
    for _, prefix in ipairs(reputationOverlayPrefixes) do
        for index = 0, 3 do
            local name = prefix .. index
            local texture = _G[name]
            if texture and reputationOverlayOriginalAlpha[name] ~= nil then
                texture:SetAlpha(reputationOverlayOriginalAlpha[name])
            end
            reputationOverlayOriginalAlpha[name] = nil
        end
    end
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
    self:ApplyClassicXpGeometry()

    isUpdatingBarsLayout = false
    LogBarsState("after collapsed layout")
end

-- Re-apply SarychUI hide/alpha after Blizzard repositioned bars
function module:ApplyBarsVisualStateAfterLayout()
    self:ApplyClassicXpGeometry()
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
    self:ApplyClassicXpGeometry()
    self:ApplyExhaustionTickVisibility()
    
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
-- Preserve the original file so toggles can restore the exact artwork.
local backgroundTextures = setmetatable({}, { __mode = "k" })

local function SetDecorTexture(region, hidden, matches)
    if not region or region:GetObjectType() ~= "Texture" then return end
    local original = backgroundTextures[region]
    if not original then
        local texture = region:GetTexture()
        if type(texture) ~= "string" or not matches(texture) then return end
        original = texture
        backgroundTextures[region] = original
    end
    if hidden then
        region:SetTexture(nil)
    else
        region:SetTexture(original)
    end
end

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
    local hidden = GetSetting('hideActionBarBackgrounds', false)
    for _, barName in ipairs({
        "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
        "MultiBarLeft", "MainMenuBar", "BonusActionBarFrame"
    }) do
        local bar = _G[barName]
        if bar then
            for _, region in ipairs(GetBarRegions(bar)) do
                SetDecorTexture(region, hidden, function(texture)
                    return texture:find("UI%-ActionBar") or texture:find("ActionBar")
                        or texture:find("Background") or texture:find("MainMenuBar")
                end)
            end
        end
    end

    -- Keep the parent visible for action buttons and BFA's child artwork.
    if MainMenuBarArtFrame then
        if MainMenuBarArtFrame.SetScript then MainMenuBarArtFrame:SetScript("OnShow", nil) end
        MainMenuBarArtFrame:Show()
    end

    local bfaActive = module.BFAStyle and module.BFAStyle.active
    local hideClassicArt = hidden or bfaActive
    for _, name in ipairs({
        "MainMenuBarTexture0", "MainMenuBarTexture1",
        "MainMenuBarTexture2", "MainMenuBarTexture3",
        "MainMenuBarArtFrameTexture0", "MainMenuBarArtFrameTexture1",
        "MainMenuBarArtFrameTexture2", "MainMenuBarArtFrameTexture3"
    }) do
        local texture = _G[name]
        if texture then
            if hideClassicArt then
                texture:Hide()
                if texture.SetScript then texture:SetScript("OnShow", texture.Hide) end
            else
                if texture.SetScript then texture:SetScript("OnShow", nil) end
                texture:Show()
            end
        end
    end

    for _, name in ipairs({ "BonusActionBarTexture0", "BonusActionBarTexture1" }) do
        local texture = _G[name]
        if texture then
            if hidden then
                texture:Hide()
                if texture.SetScript then texture:SetScript("OnShow", texture.Hide) end
            else
                if texture.SetScript then texture:SetScript("OnShow", nil) end
                texture:Show()
            end
        end
    end
end

-- Apply secondary panels backgrounds (shapeshift, pet, possess)
local function ApplySecondaryPanelsBackgrounds()
    local hidden = GetSetting('hideSecondaryPanelsBackgrounds', false)

    if ShapeshiftBarFrame then
        for _, region in ipairs(GetBarRegions(ShapeshiftBarFrame)) do
            SetDecorTexture(region, hidden, function(texture)
                return texture:find("ShapeshiftBar") or texture:find("SHAPESHIFTBARMIDDLE")
            end)
        end
        for i = 1, GetNumShapeshiftFormsSafe() do
            local button = _G["ShapeshiftButton" .. i]
            if button then
                local normal = button.GetNormalTexture and button:GetNormalTexture()
                if normal then
                    if hidden then normal:SetTexture(nil)
                    else normal:SetTexture("Interface\\Buttons\\UI-Quickslot2") end
                end
                local border = _G["ShapeshiftButton" .. i .. "Border"]
                if border then
                    if hidden then border:SetTexture(nil)
                    else border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress") end
                end
            end
        end
    end

    if PetActionBarFrame then
        for _, region in ipairs(GetBarRegions(PetActionBarFrame)) do
            SetDecorTexture(region, hidden, function(texture)
                return texture:find("UI%-PetBar")
            end)
        end
    end

    if PossessBarFrame then
        for _, region in ipairs(GetBarRegions(PossessBarFrame)) do
            SetDecorTexture(region, hidden, function(texture)
                return not texture:find("HIGHLIGHT") and not texture:find("BORDER")
            end)
        end
        for i = 1, POSSESS_SLOTS do
            local button = _G["PossessButton" .. i]
            if button then
                local normal = button.GetNormalTexture and button:GetNormalTexture()
                if normal then
                    if hidden then normal:SetTexture(nil)
                    else normal:SetTexture("Interface\\Buttons\\UI-Quickslot2") end
                end
                local border = _G["PossessButton" .. i .. "Border"]
                if border then
                    if hidden then border:SetTexture(nil)
                    else border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress") end
                end
            end
        end
    end
end


-- OnShow must be cleared before Show(). Otherwise the hide hook runs
-- inside Show() and the button stays hidden. A hidden frame also never
-- receives OnUpdate, so a "show until visible" ticker cannot recover it.
local function PageButtonKeepHidden(self)
    if GetSetting("hidePageButtons", false) then
        self:Hide()
    end
end

local function ApplyPageButtonsSettings()
    local hidePageButtons = GetSetting("hidePageButtons", false)
    local pageButtons = { ActionBarUpButton, ActionBarDownButton }
    for _, button in ipairs(pageButtons) do
        if button then
            if button.SetScript then
                button:SetScript("OnUpdate", nil)
            end
            if hidePageButtons then
                if button.SetScript then
                    button:SetScript("OnShow", PageButtonKeepHidden)
                end
                button:Hide()
                if button.SetAlpha then
                    button:SetAlpha(0)
                end
            else
                if button.SetScript then
                    button:SetScript("OnShow", nil)
                end
                if button.SetAlpha then
                    button:SetAlpha(1)
                end
                button:Show()
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
            if KeyRingButton.SetScript then
                KeyRingButton:SetScript("OnShow", nil)
            end
            KeyRingButton:Show()
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
    local style = _G.SarychUI_InterfaceStyle
    local newTextures = style and style.enabled and style.UseStyleTextures and style.UseStyleTextures()

    local function Paint(button)
        if not button then return end
        if newTextures then return end
        local nt = button.GetNormalTexture and button:GetNormalTexture()
        local name = button.GetName and button:GetName()
        local named = name and _G[name .. "NormalTexture"]
        local second = name and _G[name .. "NormalTexture2"]
        local a = buttonBorderAlphaEnabled and (buttonBorderAlpha or 0.4) or 1
        -- NormalTexture is the button rim. Pushed, highlight and checked
        -- textures cover the button interior and must not inherit its opacity.
        if nt then nt:SetAlpha(a) end
        if named and named ~= nt then named:SetAlpha(a) end
        if second and second ~= nt and second ~= named then second:SetAlpha(a) end
    end
    
    local buttonTypes = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton", "BonusActionButton",
        "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot"
    }

    for i = 1, 12 do
        for _, btnType in ipairs(buttonTypes) do
            Paint(_G[btnType .. i])
        end
    end
    Paint(_G["MainMenuBarBackpackButton"])
	for i = 0, 3 do Paint(_G["CharacterBag" .. i .. "Slot"]) end

    for i = 1, 10 do
        Paint(_G["PetActionButton" .. i])
    end
    
    for i = 1, POSSESS_SLOTS do
        Paint(_G["PossessButton" .. i])
    end
	if newTextures and style.RefreshButtonAppearance then style:RefreshButtonAppearance() end

	local castbar = SarychUI.modules and SarychUI.modules.castbar
	if castbar and castbar.ApplyPlayerIconBorderAlpha then
		castbar:ApplyPlayerIconBorderAlpha()
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
	{ button = "ParagonMicroButton", key = "achievement", dfOnly = true },
	{ button = "CollectionsMicroButton", key = "talent", dfOnly = true },
	{ button = "StoreMicroButton", key = "mainmenu", dfOnly = true },
}

local CLASSIC_MICRO_HILIGHT = [[Interface\Buttons\UI-MicroButton-Hilight]]
-- pretty_actionbar: button 14x19 + menu scale 1.4 -> draw textures at this size.
local MICRO_DF_TEX_W = 14 * 1.4
local MICRO_DF_TEX_H = 19 * 1.4
local microMenuStyleHooksInstalled
local applyingMicroMenu
local ApplyMicroMenuStyle
local ApplyMicroMenuAlpha

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
	if GetSetting("microMenuStyle", "dragonflight") == "dragonflight" then
		bar:SetWidth(module._microPerfBarW + 3)
		bar:SetHeight(math.floor(module._microPerfBarH * 0.32 + 0.5))
		bar:SetPoint("BOTTOM", button, "BOTTOM", 3, 3)
	else
		bar:SetWidth(module._microPerfBarW)
		bar:SetHeight(module._microPerfBarH)
		bar:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -34)
	end
end

-- Blizzard: green <= PERFORMANCEBAR_LOW_LATENCY (300), yellow <= MEDIUM (600), else red.
local function IsLatencyGreen()
	local _, _, latency = GetNetStats()
	if type(latency) ~= "number" then
		return true
	end
	local low = PERFORMANCEBAR_LOW_LATENCY or 300
	return latency <= low
end

local function ShouldHideGreenLatencyBar()
	return GetSetting("microMenuStyle", "dragonflight") == "dragonflight"
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

	-- Blizzard restores default Character/MainMenu textures (full-size chrome)
	-- after we swap in DF art. Re-apply so alpha hits the visible icon, not a
	-- leftover rim sitting under/over it.
	local function RefreshMicroMenuAfterBlizzard()
		if applyingMicroMenu then return end
		if ApplyMicroMenuStyle then
			ApplyMicroMenuStyle()
		end
	end

	local function HidePortraitIfDf()
		if GetSetting("microMenuStyle", "dragonflight") ~= "dragonflight" then return end
		if MicroButtonPortrait then
			MicroButtonPortrait:SetTexCoord(0, 0, 0, 0)
			MicroButtonPortrait:SetAlpha(0)
		end
		RefreshMicroMenuAfterBlizzard()
	end

	if type(hooksecurefunc) == "function" then
		if CharacterMicroButton_SetPushed then
			hooksecurefunc("CharacterMicroButton_SetPushed", HidePortraitIfDf)
		end
		if CharacterMicroButton_SetNormal then
			hooksecurefunc("CharacterMicroButton_SetNormal", HidePortraitIfDf)
		end
		if MainMenuMicroButton_SetPushed then
			hooksecurefunc("MainMenuMicroButton_SetPushed", function()
				UpdatePerformanceBar()
				RefreshMicroMenuAfterBlizzard()
			end)
		end
		if MainMenuMicroButton_SetNormal then
			hooksecurefunc("MainMenuMicroButton_SetNormal", function()
				UpdatePerformanceBar()
				RefreshMicroMenuAfterBlizzard()
			end)
		end
		if UpdateMicroButtons then
			hooksecurefunc("UpdateMicroButtons", RefreshMicroMenuAfterBlizzard)
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

ApplyMicroMenuStyle = function()
	if applyingMicroMenu then return end
	applyingMicroMenu = true
	EnsureMicroMenuStyleHooks()
	local useDf = GetSetting("microMenuStyle", "dragonflight") == "dragonflight"

	local function SnapshotMicroTex(tex)
		if not tex or not tex.GetTexture then
			return nil
		end
		return { path = tex:GetTexture(), coords = { tex:GetTexCoord() } }
	end

	local function RestoreMicroTex(tex, snap, button)
		if not tex or not snap then
			return
		end
		tex:SetTexture(snap.path)
		if snap.coords and snap.coords[1] then
			tex:SetTexCoord(unpack(snap.coords))
		else
			tex:SetTexCoord(0, 1, 0, 1)
		end
		tex:ClearAllPoints()
		tex:SetAllPoints(button)
	end

	local function EachExtraMicroIcon(button, callback)
		local keep = {}
		local normalTex = button:GetNormalTexture()
		local pushedTex = button:GetPushedTexture()
		local highlightTex = button:GetHighlightTexture()
		local disabledTex = button:GetDisabledTexture()
		if normalTex then keep[normalTex] = true end
		if pushedTex then keep[pushedTex] = true end
		if highlightTex then keep[highlightTex] = true end
		if disabledTex then keep[disabledTex] = true end

		if button.GetNumRegions then
			for i = 1, button:GetNumRegions() do
				local region = select(i, button:GetRegions())
				if region and not keep[region] and region.GetObjectType and region:GetObjectType() == "Texture" then
					callback(region)
				end
			end
		end

		local name = button.GetName and button:GetName()
		if name then
			for _, suffix in ipairs({ "Icon", "Texture", "IconTexture", "Portrait" }) do
				local tex = _G[name .. suffix]
				if tex and not keep[tex] then
					callback(tex)
				end
			end
		end
	end

	local function HideExtraMicroIcons(button)
		if not button._sarychExtraIcons then
			button._sarychExtraIcons = {}
		end
		local savedByTex = {}
		for _, info in ipairs(button._sarychExtraIcons) do
			if info.tex then
				savedByTex[info.tex] = info
			end
		end
		EachExtraMicroIcon(button, function(tex)
			if not savedByTex[tex] then
				local info = {
					tex = tex,
					alpha = tex.GetAlpha and tex:GetAlpha() or 1,
					shown = tex.IsShown and tex:IsShown() and true or false,
					coords = tex.GetTexCoord and { tex:GetTexCoord() } or nil,
				}
				button._sarychExtraIcons[#button._sarychExtraIcons + 1] = info
				savedByTex[tex] = info
			end
			tex:SetAlpha(0)
			if tex.SetTexCoord then
				tex:SetTexCoord(0, 0, 0, 0)
			end
			if tex.Hide then
				tex:Hide()
			end
		end)
	end

	local function ShowExtraMicroIcons(button)
		local saved = button._sarychExtraIcons
		if not saved then
			return
		end
		for _, info in ipairs(saved) do
			local tex = info.tex
			if tex then
				if tex.SetAlpha then
					tex:SetAlpha(info.alpha or 1)
				end
				if info.coords and info.coords[1] and tex.SetTexCoord then
					tex:SetTexCoord(unpack(info.coords))
				end
				if info.shown and tex.Show then
					tex:Show()
				end
			end
		end
	end

	for _, entry in ipairs(MICRO_MENU_BUTTONS) do
		local button = _G[entry.button]
		if button then
			local coords = MICRO_MENU_DF_COORDS[entry.key]
			local normal = button:GetNormalTexture()
			local pushed = button:GetPushedTexture()
			local highlight = button:GetHighlightTexture()
			local disabled = button:GetDisabledTexture()

			if useDf and coords then
				if entry.dfOnly and not button._sarychMicroOrig then
					button._sarychMicroOrig = {
						normal = SnapshotMicroTex(normal),
						pushed = SnapshotMicroTex(pushed),
						highlight = SnapshotMicroTex(highlight),
						disabled = SnapshotMicroTex(disabled),
					}
				end
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
				HideExtraMicroIcons(button)
			elseif entry.dfOnly then
				local snap = button._sarychMicroOrig
				if snap then
					RestoreMicroTex(normal, snap.normal, button)
					RestoreMicroTex(pushed, snap.pushed, button)
					RestoreMicroTex(disabled, snap.disabled, button)
					RestoreMicroTex(highlight, snap.highlight, button)
				end
				ShowExtraMicroIcons(button)
			else
				local base = entry.classic
				SetMicroTex(normal, ClassicMicroPath(base, "Up"), nil, false, button)
				SetMicroTex(pushed, ClassicMicroPath(base, "Down"), nil, false, button)
				SetMicroTex(disabled, ClassicMicroPath(base, "Disabled"), nil, false, button)
				SetMicroTex(highlight, CLASSIC_MICRO_HILIGHT, nil, false, button)
				if highlight and highlight.SetBlendMode then
					highlight:SetBlendMode("ADD")
				end
				ShowExtraMicroIcons(button)
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
	if ApplyMicroMenuAlpha then
		ApplyMicroMenuAlpha()
	end
	applyingMicroMenu = false
end

-- Apply micro menu alpha
local microMenuHovered = false
local bagsHovered = false

ApplyMicroMenuAlpha = function()
    local microMenuAlphaEnabled = GetSetting('microMenuAlphaEnabled', false)
    local microMenuAlpha = GetSetting('microMenuAlpha', 0.95)
    local a = microMenuHovered and 1 or (microMenuAlphaEnabled and (microMenuAlpha or 0.95) or 1)

    local seen = {}
    local function Paint(button)
        if not button or seen[button] then return end
        seen[button] = true
        for _, tex in ipairs({button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture(), button:GetDisabledTexture()}) do
            if tex then
                tex:SetAlpha(a)
            end
        end
    end

    for _, entry in ipairs(MICRO_MENU_BUTTONS) do
        Paint(_G[entry.button])
    end

    local holder = _G.SarychUIMicroMenu
    if holder and holder.GetChildren then
        for _, child in ipairs({ holder:GetChildren() }) do
            if child and child.GetNormalTexture then
                Paint(child)
            end
        end
    end
end

local BAG_ALPHA_BUTTONS = {
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "KeyRingButton",
}

local bagAlphaHooked

local function ApplyBagAlpha()
    local bagAlphaEnabled = GetSetting("bagAlphaEnabled", false)
    local bagAlpha = GetSetting("bagAlpha", 0.95)
    local a = bagsHovered and 1 or (bagAlphaEnabled and (bagAlpha or 0.95) or 1)
	local visibility = _G.SarychUI_BarVisibility
	if visibility and visibility.IsGroupHidden and visibility.IsGroupHidden("bags") then
		a = 0
	end

    for i = 1, #BAG_ALPHA_BUTTONS do
        local button = _G[BAG_ALPHA_BUTTONS[i]]
        if button and button.SetAlpha then
            button:SetAlpha(a)
        end
    end

    if not bagAlphaHooked and hooksecurefunc then
        if PaperDollItemSlotButton_Update then
            hooksecurefunc("PaperDollItemSlotButton_Update", function()
                ApplyBagAlpha()
            end)
        end
        bagAlphaHooked = true
    end
end

local function CursorOverButton(button, x, y)
    if not button or not button.IsVisible or not button:IsVisible() then
        return false
    end
    if button.IsMouseOver then
        return button:IsMouseOver()
    end
    if not button.GetRect then return false end
    local left, bottom, width, height = button:GetRect()
    return left and bottom and width and height
        and x >= left and x <= left + width and y >= bottom and y <= bottom + height
end

function module:UpdateTransparencyHover()
    local watchMicro = GetSetting('microMenuShown', true) ~= false
        and GetSetting('microMenuAlphaEnabled', false)
        and GetSetting('microMenuShowOnMouseover', false)
    local watchBags = GetSetting('bagsShown', true) ~= false
        and GetSetting('bagAlphaEnabled', false)
        and GetSetting('bagShowOnMouseover', false)

    if not self.transparencyHoverFrame then
        local frame = CreateFrame('Frame', nil, UIParent)
        local elapsedSinceCheck = 0
        frame:SetScript('OnUpdate', function(_, elapsed)
            elapsedSinceCheck = elapsedSinceCheck + elapsed
            if elapsedSinceCheck >= 0.05 then
                elapsedSinceCheck = 0
                module:UpdateTransparencyHover()
            end
        end)
        frame:Hide()
        self.transparencyHoverFrame = frame
    end

    if watchMicro or watchBags then self.transparencyHoverFrame:Show()
    else self.transparencyHoverFrame:Hide() end

    local x, y
    if watchMicro or watchBags then
        x, y = GetCursorPosition()
        local scale = UIParent:GetScale()
        x, y = x / scale, y / scale
    end

    local overMicro = false
    if watchMicro then
        for _, entry in ipairs(MICRO_MENU_BUTTONS) do
            if CursorOverButton(_G[entry.button], x, y) then overMicro = true; break end
        end
        local holder = _G.SarychUIMicroMenu
        if not overMicro and holder and holder.GetChildren then
            for _, child in ipairs({ holder:GetChildren() }) do
                if child and child.GetNormalTexture and CursorOverButton(child, x, y) then
                    overMicro = true
                    break
                end
            end
        end
    end
    if overMicro ~= microMenuHovered then
        microMenuHovered = overMicro
        ApplyMicroMenuAlpha()
    end

    local overBags = false
    if watchBags then
        for _, name in ipairs(BAG_ALPHA_BUTTONS) do
            if CursorOverButton(_G[name], x, y) then overBags = true; break end
        end
    end
    if overBags ~= bagsHovered then
        bagsHovered = overBags
        ApplyBagAlpha()
    end
end

function module:StopTransparencyHover()
    if self.transparencyHoverFrame then self.transparencyHoverFrame:Hide() end
    microMenuHovered = false
    bagsHovered = false
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
    
    -- Hotkey visibility is owned exclusively by the Text panel.
    if showHotkeysOnAlt then
        if module.UpdateAllHotkeys then module:UpdateAllHotkeys(0, nil, "Classic:AltMode:pressed") end
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
    if module.UpdateAllHotkeys then
        module:UpdateAllHotkeys(0, nil, "Classic:AltMode:released")
    elseif module.HideHotkeys then
        module:HideHotkeys()
    end
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

    if self.UpdateBarsLayout then
        self:UpdateBarsLayout("UpdateExperienceBar")
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

local function ShouldHideExhaustionTick()
    return GetSetting('enabled', false)
        and module._bootBarStyle ~= "dragon"
        and GetSetting('hideExhaustionTick', false)
end

function module:ApplyExhaustionTickVisibility()
    if not ExhaustionTick then return end
    if not self._exhaustionTickVisibilityHooked and ExhaustionTick.HookScript then
        ExhaustionTick:HookScript("OnShow", function(tick)
            if ShouldHideExhaustionTick() then tick:Hide() end
        end)
        self._exhaustionTickVisibilityHooked = true
    end
    self:UpdateExhaustionTick()
end

-- Set experience bar visibility (from original)
function module:SetExpBarVisibility(show)
    SetBarVisibility(MainMenuExpBar, show)
    if ExhaustionTick then
        -- ExhaustionTick должен показываться вместе с полосой опыта
        -- если у игрока есть бодрость
        if show and IsPlayerRested() and not ShouldHideExhaustionTick() then
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
        if IsPlayerRested() and not ShouldHideExhaustionTick() then
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

    if self.UpdateBarsLayout then
        self:UpdateBarsLayout("UpdateReputationBar")
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
    
    -- Не подавляем конечное состояние debounce'ом: fade короче 0.1 секунды,
    -- поэтому такой ранний выход оставлял панели на промежуточной alpha.

    -- Оптимизация: откладываем операции с панелями если идет выход из боя
    if isFadingOutAfterCombat then
        SuiTimer.After(0.1, function()
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
    
    -- Do not SetScript OnEnter/OnLeave on MultiBarLeft/Right buttons.
    -- Replacing those scripts taints the buttons, and a macro click then
    -- fails CastSpellByName. CheckMouseOverPanels already watches the bars.
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
            -- Нечего анимировать - выходим до чтения настроек (тик идёт 50 раз/сек).
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
            -- Нечего анимировать - выходим до чтения настроек.
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
    ApplyBagAlpha()
    self:UpdateTransparencyHover()
    
    -- Apply bar settings
	ApplyExperienceBarSettings()
	ApplyReputationBarSettings()
	ApplySidePanelsSettings()

	-- The generic settings above operate on the standard Blizzard frames.
	-- Re-apply the selected BFA artwork last so the same toggles also control it.
	if module.BFAStyle and module.BFAStyle.active then
		module.BFAStyle:ApplyAppearance()
	end
	self:ApplyExperienceOverlayVisibility()
	self:ApplyReputationOverlayVisibility()
	self:ApplyExhaustionTickVisibility()
	-- BFA shows MainMenuBarArtFrame after the first pass. Re-apply so the
	-- page arrows stay in the state chosen by hidePageButtons.
	ApplyPageButtonsSettings()
	ApplyBagAlpha()
	if self.ApplyAuxiliaryControls then self:ApplyAuxiliaryControls() end
	local style = _G.SarychUI_InterfaceStyle
	if style and style.enabled then
		if style.RefreshButtonAppearance then style:RefreshButtonAppearance() end
	end
end

-- Apply visibility controls directly when a checkbox changes. The full
-- appearance pass also updates unrelated bars and animations.
function module:RefreshVisualImprovements()
    ApplyGryphonsSettings()
    ApplyActionBarBackgrounds()
    ApplySecondaryPanelsBackgrounds()
    ApplyMaxLevelBarSettings()
    ApplyPageButtonsSettings()
    ApplyKeyringButtonSettings()
    if self.BFAStyle and self.BFAStyle.active then
        self.BFAStyle:ApplyAppearance()
        ApplyPageButtonsSettings()
    end
    self:ApplyExperienceOverlayVisibility()
    self:ApplyReputationOverlayVisibility()
    self:ApplyExhaustionTickVisibility()
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
module.ApplyBagAlpha = ApplyBagAlpha
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
            if KeyRingButton.SetScript then
                KeyRingButton:SetScript("OnShow", nil)
            end
            KeyRingButton:Show()
            -- Принудительно обновляем UI
            if KeyRingButton.GetParent then
                local parent = KeyRingButton:GetParent()
                if parent and parent.UpdateVisible then
                    parent:UpdateVisible()
                end
            end
            -- Дополнительная попытка обновления через таймер
            SuiTimer.After(0.1, function()
                if KeyRingButton and KeyRingButton:IsVisible() then
                    KeyRingButton:Show()
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

function module:UpdatePageButtons()
    ApplyPageButtonsSettings()
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
