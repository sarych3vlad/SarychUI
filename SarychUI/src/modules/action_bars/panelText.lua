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

local originalTextStyle = setmetatable({}, { __mode = "k" })

local function TextMode(db, enabledKey, legacyKey, modeKey)
    local enabled = db[enabledKey]
    if enabled == nil then enabled = db[modeKey] == "custom" or db[legacyKey] end
    if not enabled then return "default" end
    return db[modeKey] or "hide"
end

local function ApplyTextStyle(region, mode, fontName, fontSize, outline, color)
    if not region or not region.GetFont or not region.SetFont then return end
    local original = originalTextStyle[region]
    if not original and mode ~= "custom" then return end
    if not original then
        local path, size, flags = region:GetFont()
        local r, g, b, a = region:GetTextColor()
        original = { path, size, flags, r, g, b, a }
        originalTextStyle[region] = original
    end
    if mode == "custom" then
        local media = SarychUI.Media
        local path
        if media and media.GetFont and fontName then
            local ok, found = pcall(media.GetFont, fontName)
            if ok then path = found end
        end
        region:SetFont(path or original[1] or "Fonts\\FRIZQT__.TTF", fontSize or original[2] or 12,
            outline == "NONE" and "" or (outline or ""))
        if color then region:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
    else
        region:SetFont(original[1] or "Fonts\\FRIZQT__.TTF", original[2] or 12, original[3] or "")
        if color then region:SetTextColor(original[4] or 1, original[5] or 1, original[6] or 1, original[7] or 1) end
        originalTextStyle[region] = nil
    end
end

local function StyleHotkey(region, db)
    ApplyTextStyle(region, TextMode(db, "hotkeyTextEnabled", "hideHotkeysEnabled", "hotkeyTextMode"),
        db.hotkeyFont, db.hotkeyFontSize, db.hotkeyFontOutline)
end

local function StyleMacro(region, db)
    ApplyTextStyle(region, TextMode(db, "macroTextEnabled", "hideMacroNames", "macroTextMode"),
        db.macroFont, db.macroFontSize, db.macroFontOutline, db.macroFontColor or { 1, 1, 1, 1 })
end

-- Never cache addon data directly on protected Blizzard action buttons. Even
-- custom fields can carry insecure values into later secure update paths.
local hotkeyByButton = setmetatable({}, { __mode = "k" })

-- Hotkey alpha has one owner. Action-button refreshes, binding updates and
-- visibility events can all happen in the same frame, so using a separate
-- UIFrameFade for every notification lets a later refresh cancel the fade and
-- snap the text back to 0/1.  Keep the desired alpha and all active animations
-- here instead.
local hotkeyTargets = setmetatable({}, { __mode = "k" })
local hotkeyAnimations = setmetatable({}, { __mode = "k" })
local hotkeyInternalWrites = setmetatable({}, { __mode = "k" })
local hotkeyOwnershipHooks = setmetatable({}, { __mode = "k" })
local HOTKEY_ALPHA_EPSILON = 0.001
-- FrameXML ActionButton.lua writes RANGE_INDICATOR ("●") when a slot has no
-- binding.  That glyph is a range placeholder, not a hotkey, and must never
-- appear through Alt / combat / target visibility.
local RANGE_INDICATOR_GLYPH = "●"

local function HasBindingHotkeyText(hotkey)
    if not hotkey or not hotkey.GetText then
        return false
    end
    local text = hotkey:GetText()
    if not text or text == "" then
        return false
    end
    if text == RANGE_INDICATOR_GLYPH then
        return false
    end
    if RANGE_INDICATOR and text == RANGE_INDICATOR then
        return false
    end
    return true
end

local function WriteHotkeyAlpha(hotkey, alpha)
    hotkeyInternalWrites[hotkey] = (hotkeyInternalWrites[hotkey] or 0) + 1
    -- 3.3.5 FontString:SetText/Show redraws the glyph at full opacity even when
    -- GetAlpha() still reports 0.  Re-stamp alpha, and Hide() at 0 so a later
    -- a later Show+SetText cannot leave the binding visible.
    if alpha <= HOTKEY_ALPHA_EPSILON then
        hotkey:SetAlpha(0)
        if hotkey.Hide then
            hotkey:Hide()
        end
    else
        if hotkey.Show then
            hotkey:Show()
        end
        hotkey:SetAlpha(alpha)
    end
    local remaining = hotkeyInternalWrites[hotkey] - 1
    hotkeyInternalWrites[hotkey] = remaining > 0 and remaining or nil
end

local function GetAnimationAlpha(animation)
    local progress = animation.elapsed / animation.duration
    if progress > 1 then progress = 1 end
    return animation.fromAlpha + (animation.toAlpha - animation.fromAlpha) * progress
end

local hotkeyFadeDriver = CreateFrame("Frame")
hotkeyFadeDriver:Hide()
hotkeyFadeDriver:SetScript("OnUpdate", function(self, elapsed)
    local running = false

    for hotkey, animation in pairs(hotkeyAnimations) do
        if not HasBindingHotkeyText(hotkey) then
            WriteHotkeyAlpha(hotkey, 0)
            hotkeyAnimations[hotkey] = nil
        else
            animation.elapsed = animation.elapsed + elapsed
            local progress = animation.elapsed / animation.duration
            if progress >= 1 then
                WriteHotkeyAlpha(hotkey, animation.toAlpha)
                hotkeyAnimations[hotkey] = nil
            else
                WriteHotkeyAlpha(hotkey, animation.fromAlpha + (animation.toAlpha - animation.fromAlpha) * progress)
                running = true
            end
        end
    end

    if not running then
        self:Hide()
    end
end)

-- Action buttons finish their refresh through ActionButton_Update, which is
-- hooked below.
local function InstallHotkeyOwnershipHooks(hotkey)
    if not hotkey or hotkeyOwnershipHooks[hotkey] or not hooksecurefunc then return end
    hotkeyOwnershipHooks[hotkey] = true

    hooksecurefunc(hotkey, "SetAlpha", function(region, writtenAlpha)
        if hotkeyInternalWrites[region] then return end

        if not HasBindingHotkeyText(region) then
            if module.ApplyHotkeyRegion then
                module:ApplyHotkeyRegion(region, "external:SetAlpha:unbound")
            end
            return
        end

        local expected = module:GetHotkeyTargetAlpha()
        local actual = tonumber(writtenAlpha)
        if actual == nil and region.GetAlpha then actual = region:GetAlpha() end
        local animation = hotkeyAnimations[region]
        local ownedAlpha = animation and GetAnimationAlpha(animation) or expected
        if expected == nil or actual == nil or ownedAlpha == nil
            or math.abs(actual - ownedAlpha) <= HOTKEY_ALPHA_EPSILON
        then
            return
        end

        if module.ApplyHotkeyRegion then
            module:ApplyHotkeyRegion(region, "external:SetAlpha:repair")
        end
    end)
end

local BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomRightButton",
    "MultiBarBottomLeftButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "BonusActionButton",
}

local function IsShapeshiftHotkeyRegion(hotkey)
    local parent = hotkey and hotkey.GetParent and hotkey:GetParent()
    while parent do
        local name = parent.GetName and parent:GetName()
        if name and name:find("^ShapeshiftButton%d+$") then
            return true
        end
        parent = parent.GetParent and parent:GetParent()
    end
    return false
end

-- Named HotKey FontStrings never change identity, so the name concatenation and
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

local function SetHotkeyAlpha(hotkey, alpha, fadeTime, force, restamp)
    if not hotkey then return end
    InstallHotkeyOwnershipHooks(hotkey)

    -- Unbound slots keep RANGE_INDICATOR / empty text.  Never reveal that
    -- placeholder, even when the Text panel wants hotkeys at alpha 1.
    if not HasBindingHotkeyText(hotkey) then
        alpha = 0
        fadeTime = 0
        force = true
        restamp = true
    end

    alpha = tonumber(alpha) or 0
    if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
    local from = hotkey.GetAlpha and hotkey:GetAlpha() or alpha

    -- A repeated action-button/binding refresh must not interrupt an animation
    -- which is already moving this FontString to the same target. A restamp
    -- must still write when the stored alpha already matches.
    if not force and hotkeyTargets[hotkey] == alpha then
        local animation = hotkeyAnimations[hotkey]
        if animation then
            WriteHotkeyAlpha(hotkey, GetAnimationAlpha(animation))
            return
        end
        if restamp or math.abs(from - alpha) > HOTKEY_ALPHA_EPSILON then
            WriteHotkeyAlpha(hotkey, alpha)
        end
        return
    end

    fadeTime = tonumber(fadeTime) or 0
    if fadeTime < 0 then fadeTime = 0 end

    -- Remove legacy/system fades once before taking ownership of the region.
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(hotkey)
    end
    hotkeyAnimations[hotkey] = nil
    hotkeyTargets[hotkey] = alpha

    if fadeTime > 0 and math.abs(from - alpha) > HOTKEY_ALPHA_EPSILON then
        hotkeyAnimations[hotkey] = {
            elapsed = 0,
            duration = fadeTime,
            fromAlpha = from,
            toAlpha = alpha,
        }
        hotkeyFadeDriver:Show()
        return
    end

    WriteHotkeyAlpha(hotkey, alpha)
end

function module:GetHotkeyFadeTime()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
        and SarychUI.db.profile.modules.mainmenubar
    if db and TextMode(db, "hotkeyTextEnabled", "hideHotkeysEnabled", "hotkeyTextMode") == "hide"
        and db.hotkeysFadeAfterCombat then
        return tonumber(db.hotkeysFadeTime) or 0.4
    end
    return 0
end

-- The Text panel is the single source of truth for hotkey visibility.
function module:GetHotkeyTargetAlpha()
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end

    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then
        return nil
    end

    if TextMode(currentDb, "hotkeyTextEnabled", "hideHotkeysEnabled", "hotkeyTextMode") ~= "hide" then
        return 1
    end

    local hasTarget = UnitExists("target")
    -- Same rule as classic bars: live combat shows immediately, even when
    -- CircleL fires PLAYER_REGEN_DISABLED before InCombatLockdown is true.
    -- _hotkeyCombatState only holds visibility across the short exit gap.
    local liveCombat = UnitAffectingCombat("player") or (InCombatLockdown and InCombatLockdown())
    local inCombat = self._hotkeyCombatState
    if liveCombat then
        inCombat = true
        self._hotkeyCombatState = true
    elseif inCombat == nil then
        inCombat = false
        self._hotkeyCombatState = false
    end

    -- Modifier reveal is independent of automatic combat visibility.
    if SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() and currentDb.showHotkeysOnAlt then
        return 1
    end

    if inCombat then
        if currentDb.showHotkeysInCombat or (currentDb.showHotkeysWithTarget and hasTarget) then
            return 1
        end
        return 0
    end

    if currentDb.showHotkeysWithTarget and hasTarget then
        return 1
    end

    return 0
end

-- Combat coordinator.  Classic bars latch from UnitAffectingCombat; CircleL
-- often delivers PLAYER_REGEN_DISABLED before lockdown, so requiring lockdown
-- can hide hotkeys in a real fight.
function module:SetHotkeyCombatState(inCombat, fadeTime, source)
    if inCombat then
        if (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player") then
            self._hotkeyCombatState = true
        elseif self._hotkeyCombatState == nil then
            self._hotkeyCombatState = false
        end
    else
        self._hotkeyCombatState = false
    end
    self:UpdateAllHotkeys(fadeTime, nil, source)
end

-- Reconcile one region after Blizzard has refreshed its text. A repair
-- is immediate, but it preserves an active animation with the same target.
function module:ApplyHotkeyRegion(hotkey, source)
    if not hotkey then return end
    InstallHotkeyOwnershipHooks(hotkey)
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
        and SarychUI.db.profile.modules.mainmenubar
    if db then StyleHotkey(hotkey, db) end
    -- Stance bindings stay hidden. Combat / Alt / target never reveal them.
    if IsShapeshiftHotkeyRegion(hotkey) then
        SetHotkeyAlpha(hotkey, 0, 0, true, true)
        return
    end
    -- No bind → no label.  RANGE_INDICATOR must not follow Alt/combat rules.
    if not HasBindingHotkeyText(hotkey) then
        SetHotkeyAlpha(hotkey, 0, 0, true, true)
        return
    end
    local alpha = self:GetHotkeyTargetAlpha()
    if alpha == nil then return end
    SetHotkeyAlpha(hotkey, alpha, 0, false, true)
end

-- Applies the current hotkey alpha to a single button.
function module:ApplyHotkeyAlpha(button, source)
    if not button then return end

    local hotkey = hotkeyByButton[button]
    if hotkey == nil then
        local name = button.GetName and button:GetName()
        hotkey = (name and _G[name .. "HotKey"]) or button.hotkey or false
        hotkeyByButton[button] = hotkey
    end
    if not hotkey then return end

    self:ApplyHotkeyRegion(hotkey, source)
end

-- Initialize text system
function module:InitializeTextSystem()
    if module._hotkeyCombatState == nil then
        module._hotkeyCombatState = (UnitAffectingCombat("player") or (InCombatLockdown and InCombatLockdown())) and true or false
    end

    -- Hooks are permanent; re-running Initialize must not stack another copy.
    if not module.__sarTextHooked then
        module.__sarTextHooked = true
        hooksecurefunc("ActionButton_Update", function(button)
            if SarychUI.modules and SarychUI.modules.mainmenubar and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.mainmenubar and SarychUI.db.profile.modules.mainmenubar.enabled then
                module:ApplyHotkeyAlpha(button, "Blizzard:ActionButton_Update")
                if module.UpdateMacroNames then module:UpdateMacroNames(button) end
            end
        end)
        -- FrameXML writes RANGE_INDICATOR on UPDATE_BINDINGS without going
        -- through ActionButton_Update.  Hide that placeholder immediately.
        if ActionButton_UpdateHotkeys then
            hooksecurefunc("ActionButton_UpdateHotkeys", function(button)
                if SarychUI.modules and SarychUI.modules.mainmenubar and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.mainmenubar and SarychUI.db.profile.modules.mainmenubar.enabled then
                    module:ApplyHotkeyAlpha(button, "Blizzard:ActionButton_UpdateHotkeys")
                end
            end)
        end
    end
    
    -- Combat events will be registered at the end of file
    
    -- Apply initial settings
    if module.UpdateAllHotkeys then module:UpdateAllHotkeys(0, true, "InitializeTextSystem") end
    
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
function module:UpdateAllHotkeys(fadeTime, force, source)
    -- Get fresh db reference
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then 
        return 
    end
    
    local alpha = self:GetHotkeyTargetAlpha()
    if alpha == nil then return end
    -- Fade is only for combat enter/leave. Alt, target and option changes must
    -- snap; otherwise the combat fade duration leaks onto
    -- Alt and a later refresh can restart a fade in the wrong direction.
    if fadeTime == nil then
        fadeTime = 0
    end

    local regions = GetHotkeyRegions()
    for i = 1, #regions do
        StyleHotkey(regions[i], currentDb)
        SetHotkeyAlpha(regions[i], alpha, fadeTime, force)
    end
    local shapeshiftSlots = tonumber(NUM_SHAPESHIFT_SLOTS) or 10
    for i = 1, shapeshiftSlots do
        local button = _G["ShapeshiftButton" .. i]
        if button then
            self:ApplyHotkeyAlpha(button, "shapeshift-hide")
        end
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
    
    local mode = TextMode(currentDb, "macroTextEnabled", "hideMacroNames", "macroTextMode")
    
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
                local macroName = _G[button:GetName() .. "Name"] or button.name
                if macroName then
                    StyleMacro(macroName, currentDb)
                    if mode == "hide" then
                        macroName:Hide()
                    else
                        macroName:Show()
                    end
                end
            end
        end
    end
end

-- Applies the current hotkey alpha to every action button.
function module:HideHotkeys()
    self:UpdateAllHotkeys()
end

-- Compatibility entry point.  Visibility still comes exclusively from the
-- Text panel settings; callers cannot force the labels on independently.
function module:ShowHotkeys()
    self:UpdateAllHotkeys()
end

-- Compatibility entry points used by the combat coordinator.  Their names are
-- historical; visibility conditions still decide the final target.
function module:FadeOutHotkeys(fadeTime)
    self:SetHotkeyCombatState(false, fadeTime, "module:FadeOutHotkeys")
end

function module:FadeInHotkeys()
    local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
        and SarychUI.db.profile.modules.mainmenubar
    local fadeTime = db and db.hotkeysFadeAfterCombat and db.hotkeysFadeTime or 0
    self:SetHotkeyCombatState(true, fadeTime, "module:FadeInHotkeys")
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
    
    local macroName = button.GetName and _G[button:GetName() .. "Name"] or button.name
    if macroName then
        StyleMacro(macroName, currentDb)
        if TextMode(currentDb, "macroTextEnabled", "hideMacroNames", "macroTextMode") == "hide" then
            macroName:Hide()
        end
    end
end

-- Show all hotkeys (used when disabling module)
function module:ShowAllHotkeys()
    local regions = GetHotkeyRegions()
    for i = 1, #regions do
        ApplyTextStyle(regions[i], "default")
        SetHotkeyAlpha(regions[i], 1, 0, true)
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
                ApplyTextStyle(macroName, "default", nil, nil, nil, true)
                macroName:Show()
            end
        end
    end
end

-- Combat events now handled by SarychUI.CombatAnimations
