-- SarychUI MainMenuBar Module
-- Main menu bar customization module - BRAIN/COORDINATOR

local moduleName = "mainmenubar"
local module = {}

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

local function GetNumRegionsSafe(frame)
    if frame and frame.GetNumRegions then
        return SafeForLimit(frame:GetNumRegions(), 0)
    end
    return 0
end

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Enable module - COORDINATOR FUNCTION
function module:Enable()
    -- Get fresh db reference
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then 
        return 
    end
    
    -- Register Alt mode callback for all elements
    if SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("mainmenubar", function(isAltPressed)
            if isAltPressed then
                -- Show elements when Alt is pressed
                if module.ShowElementsOnAlt then 
                    module:ShowElementsOnAlt() 
                end
            else
                -- Hide elements when Alt is released
                if module.HideElementsOnAltRelease then 
                    module:HideElementsOnAltRelease() 
                end
            end
        end)
    end
    
    -- Register events for experience bar and exhaustion tick
    if not module.eventFrame then
        module.eventFrame = CreateFrame("Frame")
        -- Try to register PLAYER_XP_UPDATE (may not exist in 3.3.5)
        if pcall(function() module.eventFrame:RegisterEvent("PLAYER_XP_UPDATE") end) then
            -- Event exists, registered successfully
        end
        -- Register UNIT_EXPERIENCE for WoW 3.3.5 compatibility
        module.eventFrame:RegisterEvent("UNIT_EXPERIENCE")
        module.eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
        module.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        -- Reputation bar events
        module.eventFrame:RegisterEvent("UPDATE_FACTION")
        module.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
        
        module.eventFrame:SetScript("OnEvent", function(self, event, unitID, ...)
            if event == "PLAYER_XP_UPDATE" then
                if module.HandleXPUpdate then
                    module:HandleXPUpdate(event)
                end
            elseif event == "UNIT_EXPERIENCE" and unitID == "player" then
                if module.HandleXPUpdate then
                    module:HandleXPUpdate(event)
                end
            elseif event == "UPDATE_EXHAUSTION" then
                if module.UpdateExhaustionTick then
                    module:UpdateExhaustionTick()
                end
            elseif event == "PLAYER_TARGET_CHANGED" then
                local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.mainmenubar
                if db and db.enabled and db.showHotkeysWithTarget then
                    if module.UpdateAllHotkeys then module:UpdateAllHotkeys() end
                end
            elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
                if module.OnCombatFactionChangeEvent then
                    module:OnCombatFactionChangeEvent(unitID)
                end
            elseif event == "UPDATE_FACTION" then
                if module.OnUpdateFactionEvent then
                    module:OnUpdateFactionEvent()
                end
            end
        end)
    end
    
    -- Initialize all subsystems (if available)
    if self.InitializeTextSystem then self:InitializeTextSystem() end      -- panelText.lua
    if self.InitializeColorSystem then self:InitializeColorSystem() end     -- panelColor.lua  
    if self.InitializeVisualSystem then self:InitializeVisualSystem() end    -- panelVisual.lua
end

-- Disable module - COORDINATOR FUNCTION
function module:Disable()
    -- Unregister Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback("mainmenubar")
    end
    
    -- Unregister events
    if module.eventFrame then
        module.eventFrame:UnregisterAllEvents()
        module.eventFrame:SetScript("OnEvent", nil)
        module.eventFrame = nil
    end
    
    -- Reset all systems
    if module.ShowAllHotkeys then module:ShowAllHotkeys() end
    if module.ShowAllMacroNames then module:ShowAllMacroNames() end
    if module.ApplyDisabledColorsToAllButtons then module:ApplyDisabledColorsToAllButtons() end
    
    -- Force reset all elements to ensure complete restoration
    if module.ForceResetAllElements then module:ForceResetAllElements() end
    
    -- Reset visual elements - GRYPHONS
    if MainMenuBarLeftEndCap then 
        MainMenuBarLeftEndCap:Show()
        MainMenuBarLeftEndCap:SetAlpha(1)
    end
    if MainMenuBarRightEndCap then 
        MainMenuBarRightEndCap:Show()
        MainMenuBarRightEndCap:SetAlpha(1)
    end
    
    -- Reset KEYRING BUTTON
    if KeyRingButton then
        KeyRingButton:Show()
        KeyRingButton:SetAlpha(1)
        if KeyRingButton.SetScript then
            KeyRingButton:SetScript("OnShow", nil)
        end
    end
    
    -- Reset PAGE BUTTONS
    if ActionBarUpButton then
        ActionBarUpButton:Show()
        ActionBarUpButton:SetAlpha(1)
        if ActionBarUpButton.SetScript then
            ActionBarUpButton:SetScript("OnShow", nil)
        end
    end
    if ActionBarDownButton then
        ActionBarDownButton:Show()
        ActionBarDownButton:SetAlpha(1)
        if ActionBarDownButton.SetScript then
            ActionBarDownButton:SetScript("OnShow", nil)
        end
    end
    
    -- Reset PAGE NUMBERS
    if MainMenuBarPageNumber then
        MainMenuBarPageNumber:Show()
        MainMenuBarPageNumber:SetAlpha(1)
    end
    
    -- Reset EXPERIENCE BAR
    if MainMenuExpBar then
        MainMenuExpBar:Show()
        MainMenuExpBar:SetAlpha(1)
    end
    if ExhaustionTick then
        ExhaustionTick:Show()
        ExhaustionTick:SetAlpha(1)
    end
    
    -- Reset REPUTATION BAR (only if it exists and is being watched)
    if ReputationWatchBar and GetWatchedFactionInfo() then
        ReputationWatchBar:Show()
        ReputationWatchBar:SetAlpha(1)
    end
    
    -- Reset SIDE PANELS
    if MultiBarRight then
        MultiBarRight:SetAlpha(1)
        MultiBarRight:EnableMouse(true)
    end
    if MultiBarLeft then
        MultiBarLeft:SetAlpha(1)
        MultiBarLeft:EnableMouse(true)
    end
    
    -- Reset MAIN MENU BAR TEXTURES
    local mainTextures = {
        MainMenuBarTexture0, MainMenuBarTexture1, MainMenuBarTexture2, MainMenuBarTexture3,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture0) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture1) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture2) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture3) or nil
    }
    
    for _, texture in ipairs(mainTextures) do
        if texture then
            texture:Show()
            texture:SetAlpha(1)
            if texture.SetScript then
                texture:SetScript("OnShow", nil)
            end
        end
    end
    
    -- Reset ACTION BAR BACKGROUNDS
    local actionBars = {
        "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MainMenuBar", "BonusActionBarFrame"
    }
    
    for _, barName in ipairs(actionBars) do
        local bar = _G[barName]
        if bar then
            local numRegions = GetNumRegionsSafe(bar)
            for i = 1, numRegions do
                local region = select(i, bar:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    local texture = region:GetTexture()
                    if texture and (texture:find("UI%-ActionBar") or texture:find("ActionBar") or texture:find("Background") or texture:find("MainMenuBar")) then
                        region:SetTexture("Interface\\ActionBar\\UI-ActionBar-Background")
                    end
                end
            end
        end
    end
    
    -- Reset SHAPESHIFT BAR BACKGROUNDS
    if ShapeshiftBarFrame then
        for i = 1, GetNumRegionsSafe(ShapeshiftBarFrame) do
            local region = select(i, ShapeshiftBarFrame:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                local texture = region:GetTexture()
                if texture and (texture:find("ShapeshiftBar") or texture:find("ShapeshiftBarEnds") or texture:find("SHAPESHIFTBARMIDDLE")) then
                    region:SetTexture("Interface\\ShapeshiftBar\\UI-ShapeshiftBar")
                end
            end
        end

        for i = 1, GetNumShapeshiftFormsSafe() do
            local button = _G["ShapeshiftButton" .. i]
            if button then
                local normalTexture = button:GetNormalTexture()
                if normalTexture then
                    normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                end
                local border = _G["ShapeshiftButton" .. i .. "Border"]
                if border then
                    border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
                end
            end
        end
    end
    
    -- Reset PET BAR BACKGROUNDS
    if PetActionBarFrame then
        for i = 1, GetNumRegionsSafe(PetActionBarFrame) do
            local region = select(i, PetActionBarFrame:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                local texture = region:GetTexture()
                if texture and texture:find("UI%-PetBar") then
                    region:SetTexture("Interface\\PetBar\\UI-PetBar")
                end
            end
        end
    end
    
    -- Reset POSSESS BAR BACKGROUNDS
    if PossessBarFrame then
        for i = 1, GetNumRegionsSafe(PossessBarFrame) do
            local region = select(i, PossessBarFrame:GetRegions())
            if region and region:GetObjectType() == "Texture" then
                local texture = region:GetTexture()
                if texture and not texture:find("HIGHLIGHT") and not texture:find("BORDER") then
                    region:SetTexture("Interface\\PetBar\\UI-PetBar")
                end
            end
        end

        for i = 1, POSSESS_SLOTS do
            local button = _G["PossessButton" .. i]
            if button then
                local normalTexture = button:GetNormalTexture()
                if normalTexture then
                    normalTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                end
                local border = _G["PossessButton" .. i .. "Border"]
                if border then
                    border:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
                end
            end
        end
    end
    
    -- Reset BONUS BAR TEXTURES
    local bonusTextures = {
        BonusActionBarTexture0, BonusActionBarTexture1
    }
    for _, texture in ipairs(bonusTextures) do
        if texture then
            texture:Show()
            texture:SetAlpha(1)
            if texture.SetScript then
                texture:SetScript("OnShow", nil)
            end
        end
    end
    
    -- Reset BUTTON BORDER ALPHA
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
                        tex:SetAlpha(1.0)
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
                    tex:SetAlpha(1.0)
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
                    tex:SetAlpha(1.0)
                end
            end
        end
    end
    
    -- Reset MICRO MENU ALPHA
    local microButtons = {
        "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "AchievementMicroButton", "QuestLogMicroButton",
        "LFDMicroButton", "MainMenuMicroButton", "SocialsMicroButton", "PVPMicroButton", "HelpMicroButton"
    }

    for _, btn in ipairs(microButtons) do
        local button = _G[btn]
        if button then
            for _, tex in ipairs({button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()}) do
                if tex then 
                    tex:SetAlpha(1.0)
                end
            end
        end
    end
    
    -- Reset MAX LEVEL BAR
    if MainMenuBarMaxLevelBar then
        MainMenuBarMaxLevelBar:SetAlpha(1)
    end
end

function module:RefreshConfig()
    local modDb = SarychUI.GetModuleProfile and SarychUI:GetModuleProfile(moduleName)
    if not modDb or not modDb.enabled then
        if self.ForceResetAllElements then
            self:ForceResetAllElements()
        end
        return
    end
    self:Disable()
    self:Enable()
end

-- Force reset all elements (used when module is disabled via settings)
function module:ForceResetAllElements()
    -- This function is called when module is disabled via settings
    -- It ensures all elements are restored to their default state
    
    -- Reset all systems first
    if module.ShowAllHotkeys then module:ShowAllHotkeys() end
    if module.ShowAllMacroNames then module:ShowAllMacroNames() end
    if module.ApplyDisabledColorsToAllButtons then module:ApplyDisabledColorsToAllButtons() end
    
    -- Force show all visual elements
    if MainMenuBarLeftEndCap then 
        MainMenuBarLeftEndCap:Show()
        MainMenuBarLeftEndCap:SetAlpha(1)
    end
    if MainMenuBarRightEndCap then 
        MainMenuBarRightEndCap:Show()
        MainMenuBarRightEndCap:SetAlpha(1)
    end
    
    -- Force show keyring button
    if KeyRingButton then
        KeyRingButton:Show()
        KeyRingButton:SetAlpha(1)
        if KeyRingButton.SetScript then
            KeyRingButton:SetScript("OnShow", nil)
        end
    end
    
    -- Force show page buttons
    if ActionBarUpButton then
        ActionBarUpButton:Show()
        ActionBarUpButton:SetAlpha(1)
        if ActionBarUpButton.SetScript then
            ActionBarUpButton:SetScript("OnShow", nil)
        end
    end
    if ActionBarDownButton then
        ActionBarDownButton:Show()
        ActionBarDownButton:SetAlpha(1)
        if ActionBarDownButton.SetScript then
            ActionBarDownButton:SetScript("OnShow", nil)
        end
    end
    
    -- Force show page numbers
    if MainMenuBarPageNumber then
        MainMenuBarPageNumber:Show()
        MainMenuBarPageNumber:SetAlpha(1)
    end
    
    -- Force show experience bar
    if MainMenuExpBar then
        MainMenuExpBar:Show()
        MainMenuExpBar:SetAlpha(1)
    end
    if ExhaustionTick then
        ExhaustionTick:Show()
        ExhaustionTick:SetAlpha(1)
    end
    
    -- Force show reputation bar (only if it exists and is being watched)
    if ReputationWatchBar and GetWatchedFactionInfo() then
        ReputationWatchBar:Show()
        ReputationWatchBar:SetAlpha(1)
    end
    
    -- Force show side panels
    if MultiBarRight then
        MultiBarRight:SetAlpha(1)
        MultiBarRight:EnableMouse(true)
    end
    if MultiBarLeft then
        MultiBarLeft:SetAlpha(1)
        MultiBarLeft:EnableMouse(true)
    end
    
    -- Force show all textures
    local mainTextures = {
        MainMenuBarTexture0, MainMenuBarTexture1, MainMenuBarTexture2, MainMenuBarTexture3,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture0) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture1) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture2) or nil,
        (MainMenuBarArtFrame and MainMenuBarArtFrameTexture3) or nil
    }
    
    for _, texture in ipairs(mainTextures) do
        if texture then
            texture:Show()
            texture:SetAlpha(1)
            if texture.SetScript then
                texture:SetScript("OnShow", nil)
            end
        end
    end
    
    -- Force show bonus textures
    local bonusTextures = {
        BonusActionBarTexture0, BonusActionBarTexture1
    }
    for _, texture in ipairs(bonusTextures) do
        if texture then
            texture:Show()
            texture:SetAlpha(1)
            if texture.SetScript then
                texture:SetScript("OnShow", nil)
            end
        end
    end
    
    -- Force show max level bar
    if MainMenuBarMaxLevelBar then
        MainMenuBarMaxLevelBar:SetAlpha(1)
    end
end

-- Get options table for this module
function module:GetOptions()
    -- This will be populated with options from options.lua
    return {}
end