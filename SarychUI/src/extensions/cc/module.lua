-- SarychUI Cooldowns and Timers extension
local format = string.format
local floor = math.floor
local min, max = math.min, math.max

local moduleName = "cc"
local module = {}

-- Register extension
SarychUI:RegisterExtension(moduleName, module)

-- Cached DB accessor
local function DB()
    return SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
end

-- Internal state
local isEnabledFlag = true
local hooksInstalled = false

-- Locale-dependent suffixes
local locale = GetLocale and GetLocale() or "enUS"
local daySuffix = (locale == "ruRU") and " д." or "d"
local hourSuffix = (locale == "ruRU") and " ч." or "h"
local minuteSuffix = (locale == "ruRU") and "м" or "m"

-- Helpers to access settings with sane fallbacks
local function getSetting(key, default)
    local db = DB()
    if db and db[key] ~= nil then return db[key] end
    return default
end

local function PartyAbilityExempt(frame)
    return frame and frame.__sary_partyAbility and getSetting("partyAbilitiesExempt", true)
end

local function ResolveFontPath(fontNameOrPath)
    if type(fontNameOrPath) == "string" and fontNameOrPath:find("\\") then
        return fontNameOrPath
    end
    if SarychUI and SarychUI.Media and SarychUI.Media.GetFont then
        local path = SarychUI.Media.GetFont(fontNameOrPath or "Friz Quadrata TT")
        if path and path ~= "" then return path end
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and fontNameOrPath then
        local path = LSM:Fetch("font", fontNameOrPath, true)
        if path and path ~= "" then return path end
    end
    return "Fonts\\FRIZQT__.TTF"
end

function module:GetTimerColor(seconds, baseColor)
    local color = baseColor or getSetting("defaultColor", {1, 1, 1, 1})
    -- Match the rounded number on screen: 5.4 seconds is already displayed as 5.
    if getSetting("lastFiveSecondsRed", false) and seconds > 0 and floor(seconds + 0.5) <= 5 then
        return {1, 0, 0, color[4] or 1}
    end
    return color
end

-- Time formatting based on remaining seconds and settings
local function formatCooldownText(seconds, appearance)
    local defaultColor = module:GetTimerColor(seconds, appearance and appearance.baseColor)
    local fontSizeSmall = getSetting("fontSizeSmall", 14)
    local fontSizeMedium = getSetting("fontSizeMedium", 12)
    local fontSizeLarge = getSetting("fontSizeLarge", 12)

    -- Existing aura labels use compact units and optional tenths, while their
    -- owner retains font, size and anchors. Both views share color and timing.
    if appearance and appearance.compactUnits then
        local threshold = appearance.decimalThreshold or 0
        if seconds <= threshold then
            return format(" %.01f ", seconds), defaultColor, 0.1, fontSizeSmall
        elseif seconds <= 60 then
            return format(" %d ", math.ceil(seconds)), defaultColor, 0.1, fontSizeSmall
        elseif seconds <= 3600 then
            return format("%d%s", math.ceil(seconds / 60), appearance.minuteSuffix or minuteSuffix), defaultColor, 1, fontSizeMedium
        else
            return format("%d%s", math.ceil(seconds / 3600), appearance.hourSuffix or hourSuffix), defaultColor, 60, fontSizeLarge
        end
    end

    if seconds >= 86400 then
        return format(" %d%s ", floor(seconds / 86400 + 0.5), daySuffix), defaultColor, 3600, fontSizeLarge
    elseif seconds >= 3600 then
        return format(" %d%s ", floor(seconds / 3600 + 0.5), hourSuffix), defaultColor, 60, fontSizeLarge
    elseif seconds >= 600 then
        return format(" %d%s ", floor(seconds / 60 + 0.5), minuteSuffix), defaultColor, 10, fontSizeLarge
    elseif seconds >= 60 then
        return format(" %d:%02d ", floor(seconds / 60), floor(seconds % 60)), defaultColor, 1, fontSizeMedium
    elseif seconds >= 10 then
        return format(" %02d ", floor(seconds + 0.5)), defaultColor, 0.1, fontSizeSmall
    else
        return format(" %d ", floor(seconds + 0.5)), defaultColor, 0.1, fontSizeSmall
    end
end

-- Shared formatting for cooldown views (bars and icon lists).
module.FormatTime = formatCooldownText

-- Render into an existing native label, without registering a second cooldown
-- overlay. The owning view controls its geometry and which auras have timers;
-- icon-size/min-duration filters only apply to the generic cooldown overlay.
function module:UpdateNativeTimerText(text, remaining, appearance)
    if not isEnabledFlag or not getSetting("enabled", true) or not remaining or remaining <= 0 then
        text:SetText("")
        text:Hide()
        return false
    end
    local value, color = formatCooldownText(remaining, appearance)
    text:SetText(value)
    text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    text:Show()
    return true
end

-- Native bar/list views keep their text anchor but use the same timer settings.
-- No Cooldown widget or second countdown is created for these text-only views.
function module:UpdateTimerText(text, remaining, duration, owner, preserveAppearance, timerOptions)
    local size = owner:GetHeight()
    -- Periodic ticks are not cooldowns: show their short cycle through its
    -- final fraction of a second, while retaining the shared text settings.
    local periodic = timerOptions and timerOptions.periodic
    local allowed = isEnabledFlag and getSetting("enabled", true)
        and remaining > (periodic and 0 or 0.5)
        and (periodic or duration > getSetting("minDuration", 3))
    if allowed and not PartyAbilityExempt(owner) then
        allowed = size >= getSetting("minIconSize", 23)
            and owner:GetEffectiveScale() / UIParent:GetEffectiveScale() >= getSetting("minScale", 0.5)
    end
    if not allowed then text:Hide(); return false end
    local value, color, _, fontSize = formatCooldownText(remaining, timerOptions)
    if not preserveAppearance then
        local font = ResolveFontPath(getSetting("font", "Friz Quadrata TT"))
        local flags = getSetting("fontFlags", "OUTLINE")
        local multiplier = timerOptions and timerOptions.fontSizeMultiplier or 1
        local adjustedSize = max(fontSize * min(size / 36, 1) * multiplier, 1)
        if text._ccFont ~= font or text._ccSize ~= adjustedSize or text._ccFlags ~= flags then
            text:SetFont(font, adjustedSize, flags)
            text._ccFont, text._ccSize, text._ccFlags = font, adjustedSize, flags
        end
        text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
    text:SetText(value)
    text:Show()
    return true
end

-- State stays off the cooldown widget. Writing fields, children or scripts onto
-- a Blizzard cooldown taints the parent action button, and combat Show/Hide is
-- then blocked as SarychUI.
local ccState = setmetatable({}, { __mode = "k" })
local activeCountdowns = setmetatable({}, { __mode = "k" })
local actionCountdowns = setmetatable({}, { __mode = "k" })

local function State(frame)
    local state = ccState[frame]
    if not state then
        state = {}
        ccState[frame] = state
    end
    return state
end

local function HideCountdown(state)
    if state.text then state.text:Hide() end
    if state.host then state.host:Hide() end
end

local function ClearCountdown(state, frame)
    if frame then activeCountdowns[frame] = nil end
    state.start = nil
    state.duration = nil
    state.nextUpdate = nil
    HideCountdown(state)
end

local ensureText
local function SyncCountdownLayer(frame, state)
    if not state.host then return end
    -- Every countdown stays in its cooldown's strata, directly above the sweep.
    -- Raising ordinary aura timers to HIGH makes them cover Blizzard windows.
    local strata = frame:GetFrameStrata() or "MEDIUM"
    -- Bag slots can be raised when an item moves. Track their current level
    -- independently of the text refresh interval (up to 10 seconds).
    local level = (frame:GetFrameLevel() or 0) + 1
    if state.host:GetFrameStrata() ~= strata then
        state.host:SetFrameStrata(strata)
    end
    if state.host:GetFrameLevel() ~= level then
        state.host:SetFrameLevel(level)
    end
end

local function CountdownTextureAlpha(frame)
    local owner = frame:GetParent()
    if not owner then return 1 end
    -- Countdown text lives on UIParent to avoid tainting protected cooldowns.
    -- It must mirror the button's inherited alpha (including side-bar fades).
    if not (frame.__sary_partyAbility or frame.__sary_arenaTrinket or frame.__sary_arenaDR) then
        return owner.GetEffectiveAlpha and owner:GetEffectiveAlpha() or owner:GetAlpha()
    end
    local texture = owner.texture or (owner.Icon and owner.Icon.Texture)
    if texture and texture.GetEffectiveAlpha then return texture:GetEffectiveAlpha() end
    local alpha = texture and texture.GetAlpha and texture:GetAlpha() or 1
    if owner.GetEffectiveAlpha then return alpha * owner:GetEffectiveAlpha() end
    return alpha * (owner:GetAlpha() or 1)
end

-- Per-frame update
local function cooldown_OnUpdate(frame, elapsed, now)
    local state = ccState[frame]
    local textObj = state and state.text
    if not state or not state.start then return end
    local remain = state.start + state.duration - now
    if remain <= 0.5 then
        ClearCountdown(state, frame)
        return
    end
    local owner = frame:GetParent()
    if not isEnabledFlag or not (owner and owner:IsVisible())
        or (frame.IsVisible and not frame:IsVisible()) then
        HideCountdown(state)
        state.nextUpdate = 0
        return
    end

    SyncCountdownLayer(frame, state)
    local textureAlpha = state.attached and 1 or CountdownTextureAlpha(frame)
    if state.host and state.host:GetAlpha() ~= textureAlpha then state.host:SetAlpha(textureAlpha) end

    state.nextUpdate = (state.nextUpdate or 0) - elapsed
    if state.nextUpdate > 0 then return end

    -- Short control effects (including DR) are not global cooldowns.
    if (not frame.__sary_controlAura and state.duration <= getSetting("minDuration", 3)) or frame.__sary_cc_noCount then
        HideCountdown(state)
        state.nextUpdate = 0
        return
    end

    if not PartyAbilityExempt(frame) then
        local minIconSize = getSetting("minIconSize", 23)
        if frame:GetWidth() < minIconSize or frame:GetHeight() < minIconSize then
            HideCountdown(state)
            state.nextUpdate = 0
            return
        end

        local minScale = getSetting("minScale", 0.5)
        if (frame:GetEffectiveScale() / UIParent:GetEffectiveScale()) < minScale then
            HideCountdown(state)
            state.nextUpdate = 0
            return
        end
    end

    textObj = textObj or ensureText(frame)
    if not textObj then
        state.nextUpdate = 0
        return
    end

    local displayText, color, interval, fontSize = formatCooldownText(remain)

    local fontPath = ResolveFontPath(getSetting("font", "Friz Quadrata TT"))
    local fontFlags = getSetting("fontFlags", "OUTLINE")
    local scale = min((frame:GetParent() and frame:GetParent():GetWidth() or 36) / 36, 1)
    local adjustedSize = max(fontSize * scale, 1)
    if state.fontPath ~= fontPath or state.fontSize ~= adjustedSize or state.fontFlags ~= fontFlags then
        textObj:SetFont(fontPath, adjustedSize, fontFlags)
        state.fontPath, state.fontSize, state.fontFlags = fontPath, adjustedSize, fontFlags
    end
    if state.displayText ~= displayText then
        textObj:SetText(displayText)
        state.displayText = displayText
    end
    local alpha = color[4] or 1
    local red, green, blue = color[1], color[2], color[3]
    if state.colorR ~= red or state.colorG ~= green or state.colorB ~= blue or state.colorA ~= alpha then
        textObj:SetTextColor(red, green, blue, alpha)
        state.colorR, state.colorG, state.colorB, state.colorA = red, green, blue, alpha
    end
    SyncCountdownLayer(frame, state)
    -- Keep local text alpha at one; the host mirrors the icon texture alpha.
    if textObj:GetAlpha() ~= 1 then textObj:SetAlpha(1) end
    state.host:Show()
    textObj:Show()

    state.nextUpdate = interval
end

ensureText = function(frame)
    local state = State(frame)
    if state.text then return state.text end
    if frame.__sary_cc_noCount then return nil end

    local parent = frame:GetParent()
    local pWidth = parent and parent:GetWidth() or 36
    local scale = min(pWidth / 36, 1)

    -- Owned, unprotected icons carry text anchored to their cooldown. Parent
    -- it to the icon so hiding/dimming only the sweep (e.g. DR) does not dim
    -- the digits. Blizzard widgets retain the detached, non-tainting path.
    state.attached = (frame.__sary_partyAbility or frame.__sary_arenaTrinket or frame.__sary_arenaDR)
        and not (frame.IsProtected and frame:IsProtected()) or false
    local host = CreateFrame("Frame", nil, state.attached and parent or UIParent)
    host:SetAllPoints(frame)
    host:SetAlpha(1)
    host:EnableMouse(false)
    state.host = host
    SyncCountdownLayer(frame, state)

    local text = host:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", host, "CENTER", 0, 1)

    local fontPath = ResolveFontPath(getSetting("font", "Friz Quadrata TT"))
    local fontFlags = getSetting("fontFlags", "OUTLINE")
    local fontSizeLarge = getSetting("fontSizeLarge", 12)
    local adjustedSize = max(fontSizeLarge * scale, 1)
    text:SetFont(fontPath, adjustedSize, fontFlags)

    local color = getSetting("defaultColor", {1, 1, 1, 1})
    text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    text:SetWidth(50)
    text:SetJustifyH("CENTER")

    state.text = text
    return text
end

-- Central SetCooldown bridge
local function handleSetCooldown(frame, start, duration, enable)
	if not frame then return end
    local state = State(frame)
    if enable == 0 or type(start) ~= "number" or type(duration) ~= "number"
        or start <= 0 or duration <= 0 or start + duration <= GetTime() + 0.5 then
        ClearCountdown(state, frame)
        return
    end
    activeCountdowns[frame] = state
    if state.start ~= start or state.duration ~= duration then
        state.start = start
        state.duration = duration
        state.nextUpdate = 0
    end
end

local BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarLeftButton",
    "MultiBarRightButton",
    "BonusActionButton",
}

local INVENTORY_SLOT_NAMES = {
    "AmmoSlot", "HeadSlot", "NeckSlot", "ShoulderSlot", "ShirtSlot",
    "ChestSlot", "WaistSlot", "LegsSlot", "FeetSlot", "WristSlot",
    "HandsSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
    "Trinket1Slot", "BackSlot", "MainHandSlot", "SecondaryHandSlot",
    "RangedSlot", "TabardSlot",
}
local inventorySlotIDs = {}
local function CaptureActionButton(button, cooldown)
    if not cooldown then return end
    local state = State(cooldown)
    state.button = button
    actionCountdowns[cooldown] = button and state or nil
    local action = button and button.action
    if state.action ~= action then
        ClearCountdown(state, cooldown)
        state.action = action
    end
    if button and button.action and button.action > 0 and GetActionCooldown then
        local start, duration, enable = GetActionCooldown(button.action)
        -- The action API is authoritative. A reset can turn a long cooldown
        -- into zero (or only the GCD) before its old end time is reached.
        handleSetCooldown(cooldown, start, duration, enable)
    else
        handleSetCooldown(cooldown, 0, 0)
    end
end

local function CaptureCooldownSources()
    if not isEnabledFlag then return end
    for p = 1, #BAR_PREFIXES do
        local prefix = BAR_PREFIXES[p]
        for i = 1, 12 do
            local button = _G[prefix .. i]
            local cooldown = _G[prefix .. i .. "Cooldown"]
            CaptureActionButton(button, cooldown)
        end
    end
    for i = 1, 120 do
        local button = _G["SarychUIActionButton" .. i]
        if button then
            CaptureActionButton(button, button.cooldown or button.Cooldown
                or _G["SarychUIActionButton" .. i .. "Cooldown"])
        end
    end
    local bars = SarychUI and SarychUI.FrostAtomBars
    if bars and bars.IsActive and bars.IsActive() and bars.ForEachStyledButton then
        bars.ForEachStyledButton(function(button)
            if button then
                local name = button.GetName and button:GetName()
                CaptureActionButton(button, button.cooldown or button.Cooldown
                    or (name and _G[name .. "Cooldown"]))
            end
        end)
    end
    for i = 1, 10 do
        local petCooldown = _G["PetActionButton" .. i .. "Cooldown"]
        if petCooldown and GetPetActionCooldown then
            local start, duration, enable = GetPetActionCooldown(i)
            handleSetCooldown(petCooldown, start, duration, enable)
        end
        local formCooldown = _G["ShapeshiftButton" .. i .. "Cooldown"]
        if formCooldown and GetShapeshiftFormCooldown then
            local start, duration, enable = GetShapeshiftFormCooldown(i)
            handleSetCooldown(formCooldown, start, duration, enable)
        end
    end
    if GetInventoryItemCooldown and GetInventorySlotInfo then
        for i = 1, #INVENTORY_SLOT_NAMES do
            local name = INVENTORY_SLOT_NAMES[i]
            local button = _G["Character" .. name]
            local cooldown = button and (_G["Character" .. name .. "Cooldown"] or button.Cooldown)
            if cooldown then
                local slotID = inventorySlotIDs[name]
                if not slotID then
                    slotID = GetInventorySlotInfo(name)
                    inventorySlotIDs[name] = slotID
                end
                if slotID then
                    local start, duration, enable = GetInventoryItemCooldown("player", slotID)
                    handleSetCooldown(cooldown, start, duration, enable)
                end
            end
        end
    end
end

-- Blizzard updates these cooldowns through CooldownFrame_SetTimer. Read the
-- aura data after its frame update without hooking that shared timer function.
local function CaptureFrameAuras(frame)
    if not isEnabledFlag or (frame ~= TargetFrame and frame ~= FocusFrame) then return end
    local unit = frame.unit
    local frameName = frame:GetName()
    if not unit or not frameName then return end

    local function Capture(kind, count, getter)
        for i = 1, count do
            local button = _G[frameName .. kind .. i]
            local cooldown = _G[frameName .. kind .. i .. "Cooldown"]
            if cooldown then
                if button and button:IsShown() then
                    local _, _, icon, _, _, duration, expirationTime = getter(unit, button:GetID())
                    if icon and duration and duration > 0 and expirationTime then
                        handleSetCooldown(cooldown, expirationTime - duration, duration, 1)
                    else
                        handleSetCooldown(cooldown, 0, 0)
                    end
                else
                    handleSetCooldown(cooldown, 0, 0)
                end
            end
        end
    end

    Capture("Buff", MAX_TARGET_BUFFS or 32, UnitBuff)
    Capture("Debuff", MAX_TARGET_DEBUFFS or 16, UnitDebuff)
end

local driver = CreateFrame("Frame")
local activeCheckElapsed = 0
driver:Hide()
driver:SetScript("OnEvent", function(self)
    self.refreshPending = true
end)
driver:SetScript("OnUpdate", function(_, elapsed)
    if driver.refreshPending then
        driver.refreshPending = nil
        CaptureCooldownSources()
    end
    activeCheckElapsed = activeCheckElapsed + elapsed
    local refreshActions = activeCheckElapsed >= 0.5
    if refreshActions then
        activeCheckElapsed = 0
    end
    for frame, state in pairs(actionCountdowns) do
        -- Keep the per-frame page/form guard, including idle action slots.
        if refreshActions or state.action ~= state.button.action then
            CaptureActionButton(state.button, frame)
        end
    end
    if next(activeCountdowns) then
        local now = GetTime()
        for frame in pairs(activeCountdowns) do
            cooldown_OnUpdate(frame, elapsed, now)
        end
    end
end)

-- Blizzard calls CooldownFrame_SetTimer before protected button updates. Hooking
-- that shared function can taint Show/Hide, so bar values are read on events.
-- Our own frames call SarychUI_NotifyCooldown directly.
function SarychUI_NotifyCooldown(frame, start, duration, enable)
    handleSetCooldown(frame, start, duration, enable)
end

-- Transient cooldown owners can drop their widget without leaving an anchored
-- text host behind for every proc.
function SarychUI_ReleaseCooldown(frame)
    local state = frame and ccState[frame]
    if not state then return end
    ClearCountdown(state, frame)
    if state.host then state.host:ClearAllPoints() end
    ccState[frame] = nil
    actionCountdowns[frame] = nil
end

local function installHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    for _, event in ipairs({
        "ACTIONBAR_UPDATE_COOLDOWN", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
        "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_COOLDOWN",
        "PET_BAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN",
        "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD",
    }) do
        driver:RegisterEvent(event)
    end
    if TargetFrame_UpdateAuras then
        hooksecurefunc("TargetFrame_UpdateAuras", CaptureFrameAuras)
    end
    if FocusFrame_UpdateAuras then
        hooksecurefunc("FocusFrame_UpdateAuras", CaptureFrameAuras)
    end
    driver:Show()
end

function module:ApplySettings()
    isEnabledFlag = DB() and DB().enabled ~= false
    if hooksInstalled then
        if isEnabledFlag then
            driver.refreshPending = true
            driver:Show()
        else
            driver:Hide()
        end
    end
    for _, state in pairs(ccState) do
        state.nextUpdate = 0
        if not isEnabledFlag then HideCountdown(state) end
    end
    -- Invite / arena countdown UI lives here; runtime stays in tools.
    local tools = SarychUI and SarychUI.modules and SarychUI.modules
    if tools then
        if SarychUI.modules.cc.ApplyInviteCountdown then SarychUI.modules.cc:ApplyInviteCountdown() end
        if SarychUI.modules.cc.ApplyArenaCountdown then SarychUI.modules.cc:ApplyArenaCountdown() end
    end
end

function module:Enable()
    isEnabledFlag = true
    installHooks()
    driver:Show()
    self:ApplySettings()
end

function module:Disable()
    isEnabledFlag = false
    driver:Hide()
    for _, state in pairs(ccState) do
        HideCountdown(state)
        state.nextUpdate = 0
    end

    -- Invite / arena countdown follow cc enable state.
    local tools = SarychUI and SarychUI.modules and SarychUI.modules
    if tools then
        if SarychUI.modules.cc.DisableInviteCountdown then SarychUI.modules.cc:DisableInviteCountdown() end
        if SarychUI.modules.cc.DisableArenaCountdown then SarychUI.modules.cc:DisableArenaCountdown() end
    end
end


