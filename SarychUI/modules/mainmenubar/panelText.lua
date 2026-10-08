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

-- Never cache addon data directly on protected Blizzard action buttons. Even
-- custom fields can carry insecure values into later secure update paths.
local hotkeyByButton = setmetatable({}, { __mode = "k" })

-- Hotkey alpha has one owner.  Frost action-button refreshes, binding updates
-- and visibility events can all happen in the same frame, so using a separate
-- UIFrameFade for every notification lets a later refresh cancel the fade and
-- snap the text back to 0/1.  Keep the desired alpha and all active animations
-- here instead.
local hotkeyTargets = setmetatable({}, { __mode = "k" })
local hotkeyAnimations = setmetatable({}, { __mode = "k" })
local hotkeyInternalWrites = setmetatable({}, { __mode = "k" })
local hotkeyOwnershipHooks = setmetatable({}, { __mode = "k" })
local HOTKEY_ALPHA_EPSILON = 0.001

local function WriteHotkeyAlpha(hotkey, alpha)
    hotkeyInternalWrites[hotkey] = (hotkeyInternalWrites[hotkey] or 0) + 1
    -- 3.3.5 FontString:SetText/Show redraws the glyph at full opacity even when
    -- GetAlpha() still reports 0.  Re-stamp alpha, and Hide() at 0 so a later
    -- Frost Show+SetText cannot leave the binding visible.
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

    if not running then
        self:Hide()
    end
end)

-- Classic buttons finish their refresh through ActionButton_Update, which is
-- hooked below.  Frost buttons update their binding FontString directly via
-- SetText/Show, so mirror the classic post-update reconciliation on those
-- mutations as well.
local function InstallHotkeyOwnershipHooks(hotkey)
    if not hotkey or hotkeyOwnershipHooks[hotkey] or not hooksecurefunc then return end
    hotkeyOwnershipHooks[hotkey] = true

    hooksecurefunc(hotkey, "SetAlpha", function(region, writtenAlpha)
        if hotkeyInternalWrites[region] then return end

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

    local function ReconcileFrostMutation(region, source)
        if hotkeyInternalWrites[region] then return end
        if module.ApplyHotkeyRegion then
            module:ApplyHotkeyRegion(region, source)
        end
    end
    hooksecurefunc(hotkey, "SetText", function(region)
        ReconcileFrostMutation(region, "Hotkey:SetText")
    end)
    hooksecurefunc(hotkey, "Show", function(region)
        ReconcileFrostMutation(region, "Hotkey:Show")
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

    alpha = tonumber(alpha) or 0
    if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
    local from = hotkey.GetAlpha and hotkey:GetAlpha() or alpha

    -- A repeated action-button/binding refresh must not interrupt an animation
    -- which is already moving this FontString to the same target.  Frost
    -- SetText/Show still redraws at full opacity while GetAlpha stays 0, so a
    -- restamp must write even when the stored alpha already matches.
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
    if db and db.hotkeysFadeAfterCombat then
        return tonumber(db.hotkeysFadeTime) or 0.4
    end
    return 0
end

-- The Text panel is the single source of truth for hotkey visibility.  Frost
-- buttons and Blizzard buttons both ask this function instead of deciding on
-- their own whether a label should appear.
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

    if inCombat then
        if currentDb.showHotkeysInCombat or (currentDb.showHotkeysWithTarget and hasTarget) then
            return 1
        end
        return 0
    end

    if SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() and currentDb.showHotkeysOnAlt then
        return 1
    end

    if currentDb.showHotkeysWithTarget and hasTarget then
        return 1
    end

    return 0
end

-- Combat coordinator.  Classic bars latch from UnitAffectingCombat; CircleL
-- often delivers PLAYER_REGEN_DISABLED before lockdown, so requiring lockdown
-- (or a post-exit "released" gate) hid Frost hotkeys in a real fight.
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

-- Reconcile one region after Blizzard/Frost has refreshed its text.  A repair
-- is immediate, but it preserves an active animation with the same target.
function module:ApplyHotkeyRegion(hotkey, source)
    if not hotkey then return end
    InstallHotkeyOwnershipHooks(hotkey)
    -- Stance bindings stay hidden on classic and Frost, matching FrostAtomUI's
    -- showShapeshiftHotkeys = false.  Combat / Alt / target never reveal them.
    if IsShapeshiftHotkeyRegion(hotkey) then
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
        -- SarychUIActionSlotN is an invisible Blizzard state proxy, not a
        -- rendered Frost button.  Its template receives ActionButton_Update
        -- events and used to become a second, conflicting hotkey owner.
        if name and name:find("^SarychUIActionSlot%d+$") then
            hotkeyByButton[button] = false
            return
        end
        -- Frost action buttons intentionally use their private FontString;
        -- the named template region is blank and permanently hidden.
        if name and name:find("^SarychUIActionButton%d+$") then
            hotkey = button.hotkey or false
        else
            local namedHotkey = name and _G[name .. "HotKey"]
            -- Frost reuses Blizzard pet/stance buttons but renders bindings in
            -- a private FontString.  Prefer it whenever it differs from the
            -- now-suppressed template region.
            if button.hotkey and button.hotkey ~= namedHotkey then
                hotkey = button.hotkey
            else
                hotkey = namedHotkey or button.hotkey or false
            end
        end
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
    -- Fade is only for combat enter/leave.  Alt, target, Frost refreshes and
    -- option changes must snap; otherwise the combat fade duration leaks onto
    -- Alt and a later refresh can restart a fade in the wrong direction.
    if fadeTime == nil then
        fadeTime = 0
    end

    local regions = GetHotkeyRegions()
    for i = 1, #regions do
        SetHotkeyAlpha(regions[i], alpha, fadeTime, force)
    end
    local FA = SarychUI.FrostAtomBars
    local forEachFrostHotkey = FA and (FA.ForEachHotkeyButton or FA.ForEachStyledButton)
    if FA and FA.IsActive and FA.IsActive() and forEachFrostHotkey then
        forEachFrostHotkey(function(button)
            if button and button.hotkey then
                SetHotkeyAlpha(button.hotkey, alpha, fadeTime, force)
            end
        end)
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
                local macroName = _G[button:GetName() .. "Name"] or button.name
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
    local FA = SarychUI.FrostAtomBars
    if FA and FA.IsActive and FA.IsActive() and FA.ForEachStyledButton then
        FA.ForEachStyledButton(function(button)
            local macroName = button and button.name
            if macroName then
                if hideMacroNames then
                    macroName:Hide()
                else
                    macroName:Show()
                end
            end
        end)
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
    
    local hideMacroNames = currentDb.hideMacroNames
    if not hideMacroNames then
        return
    end
    
    local macroName = button.GetName and _G[button:GetName() .. "Name"] or button.name
    if macroName then
        macroName:Hide()
    end
end

-- Show all hotkeys (used when disabling module)
function module:ShowAllHotkeys()
    local regions = GetHotkeyRegions()
    for i = 1, #regions do
        SetHotkeyAlpha(regions[i], 1, 0, true)
    end

    local FA = SarychUI.FrostAtomBars
    local forEachFrostHotkey = FA and (FA.ForEachHotkeyButton or FA.ForEachStyledButton)
    if forEachFrostHotkey then
        forEachFrostHotkey(function(button)
            if button and button.hotkey then
                SetHotkeyAlpha(button.hotkey, 1, 0, true)
            end
        end)
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
