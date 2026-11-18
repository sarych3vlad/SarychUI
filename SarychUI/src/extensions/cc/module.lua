-- SarychUI Cooldowns and Timers extension
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

-- Helpers to access settings with sane fallbacks
local function getSetting(key, default)
    local db = DB()
    if db and db[key] ~= nil then return db[key] end
    return default
end

local function PartyAbilityExempt(frame)
    return frame and frame.__sary_partyAbility and getSetting("partyAbilitiesExempt", true)
end

local function WithinDisplayLimit(remaining)
    return SarychUI.CooldownText.WithinDisplayLimit(remaining, DB() or {})
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

-- Context labels and runtime routing share the same keys. Default precision
-- locations are resolved by CooldownText; disabling one never hides its timer.
module.TimerContexts = {
    "actionBars", "petBar", "forms", "spellbook", "items", "playerAuras",
    "unitAuras", "groupAuras", "auraTracking", "trackedCooldowns", "arena",
    "diminishings", "petLifetime", "internalCooldowns", "castbar", "other",
}
local timerContexts = setmetatable({}, { __mode = "k" })
function module:SetTimerContext(frame, context)
    if frame then timerContexts[frame] = context end
end

function module:GetTimerContext(frame)
    -- Side table only: never write metadata onto protected Blizzard widgets.
    for _ = 1, 6 do
        if not frame then break end
        if timerContexts[frame] then return timerContexts[frame] end
        if frame.__sary_petLifetime then return "petLifetime" end
        if frame.__sary_arenaDR then return "diminishings" end
        if frame.__sary_arenaTrinket then return "arena" end
        if frame.__sary_partyAbility then return "trackedCooldowns" end
        local name = frame.GetName and frame:GetName() or ""
        if name:match("^PetActionButton") then return "petBar" end
        if name:match("^ShapeshiftButton") then return "forms" end
        if name:match("^SpellButton") then return "spellbook" end
        if name:match("^ActionButton") or name:match("^MultiBar") or name:match("^BonusActionButton")
            or name:match("^VehicleMenuBarActionButton") or name:match("^SarychUIActionButton") then return "actionBars" end
        if name:match("^ContainerFrame") or name:match("^Character.*Slot") then return "items" end
        if name:match("^BuffButton") or name:match("^DebuffButton") or name:match("^TempEnchant") then return "playerAuras" end
        if name:match("^TargetFrame") or name:match("^FocusFrame") or name:match("^PetFrame") then return "unitAuras" end
        frame = frame.GetParent and frame:GetParent()
    end
    return "other"
end

function module:GetTimerColor(seconds, baseColor)
    return SarychUI.CooldownText.Color(seconds, DB() or {}, baseColor)
end

local function formatCooldownText(seconds, appearance, owner)
    return SarychUI.CooldownText.Format(seconds, DB() or {}, appearance, module:GetTimerContext(owner))
end

-- Shared formatting for cooldown views (bars and icon lists).
module.FormatTime = formatCooldownText

-- Render into an existing native label, without registering a second cooldown
-- overlay. The owning view controls its geometry and which auras have timers;
-- icon-size/min-duration filters only apply to the generic cooldown overlay.
function module:UpdateNativeTimerText(text, remaining, appearance)
    if not isEnabledFlag or not getSetting("enabled", true) or not remaining or remaining <= 0
        or not WithinDisplayLimit(remaining) then
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
        and remaining > 0
        and WithinDisplayLimit(remaining)
        and (periodic or duration > getSetting("minDuration", 3))
    if allowed and not PartyAbilityExempt(owner) then
        allowed = size >= getSetting("minIconSize", 23)
            and owner:GetEffectiveScale() / UIParent:GetEffectiveScale() >= getSetting("minScale", 0.5)
    end
    if not allowed then text:Hide(); return false end
    local value, color, _, fontSize = formatCooldownText(remaining, timerOptions, owner)
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

-- Addon folder names are stable profile keys; titles are only display labels.
-- The client discovers installed addons at startup, including load-on-demand ones.
local timerAddons
local ignoredTimerFamilies = {
    sarychui = true, wcollections = true, atlasloot = true,
    details = true, awesomecvar = true,
}
function module:GetTimerAddons()
    if timerAddons then return timerAddons end
    local list, families = {}, {}
    if not GetNumAddOns or not GetAddOnInfo then return list end
    for _, addon in ipairs(SarychUI.AddonGrouping.GetInstalled()) do
        local family = addon.family
        if not ignoredTimerFamilies[family:lower()] then
            local entry = families[family]
            if not entry then
                entry = { name = family, title = family }
                families[family] = entry
                list[#list + 1] = entry
            end
            if addon.name == family then entry.title = addon.title end
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    timerAddons = list
    return list
end

local function NamedAddonOwner(frame)
    for _ = 1, 12 do
        if not frame or frame == UIParent then break end
        -- Explicit SUI contexts take precedence over a foreign ancestor.
        if timerContexts[frame] or frame.__sary_partyAbility or frame.__sary_arenaTrinket
            or frame.__sary_arenaDR or frame.__sary_petLifetime then return "SarychUI" end
        local name = frame.GetName and frame:GetName()
        if name then
            if name:lower():match("^sarychui") then return "SarychUI" end
            local addon = SarychUI.AddonGrouping.FindByName(name)
            if addon then return addon.family end
        end
        frame = frame.GetParent and frame:GetParent()
    end
end

local function CaptureAddonOwner(frame, state)
    local parent = frame.GetParent and frame:GetParent()
    if state.addonOwner ~= nil and state.addonParent == parent then return end
    module:GetTimerAddons()
    local owner = NamedAddonOwner(frame)
    if not owner and module:GetTimerContext(frame) ~= "other" then owner = "SarychUI" end
    if not owner and debugstack then
        -- Anonymous icons (notably WeakAuras) have no useful frame name.
        -- Inspect only their first live SetCooldown call, never the render loop.
        -- Skip shared libraries: their install folder need not own the widget.
        local stack = debugstack(2, 20, 0) or ""
        for line in stack:gmatch("[^\n]+") do
            local path = line:gsub("\\", "/"):lower()
            if not path:find("/extensions/cc/module.lua", 1, true)
                and not path:find("/libs/", 1, true) and not path:find("/lib/", 1, true)
                and not path:find("/libraries/", 1, true) then
                local addon = SarychUI.AddonGrouping.FindInPath(path)
                if addon then owner = addon.family end
                if owner then break end
            end
        end
    end
    -- Unknown/Blizzard widgets keep the existing behavior. Cache misses too.
    state.addonOwner, state.addonParent = owner or false, parent
end

local function AddonTimerAllowed(state)
    local settings = getSetting("addonTimers", {})
    -- Listed third-party families require explicit opt-in in the active profile.
    return not state.addonOwner or ignoredTimerFamilies[state.addonOwner:lower()]
        or settings[state.addonOwner] == true
end

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
    if remain <= 0 then
        ClearCountdown(state, frame)
        return
    end
    local owner = frame:GetParent()
    if not isEnabledFlag or not (owner and owner:IsVisible())
        or (frame.IsVisible and not frame:IsVisible()) or frame.__sary_cc_noCount
        or not AddonTimerAllowed(state)
        or not WithinDisplayLimit(remain)
        or (state.native and frame.noCooldownCount) then
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
    if not frame.__sary_controlAura and state.duration <= getSetting("minDuration", 3) then
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

    local displayText, color, interval, fontSize = formatCooldownText(remain, nil, frame)

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
    state.attached = (frame.__sary_partyAbility or frame.__sary_arenaTrinket or frame.__sary_arenaDR or frame.__sary_petLifetime)
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
local function handleSetCooldown(frame, start, duration, enable, native)
	if not frame then return end
    local state = State(frame)
    state.native = native and true or nil
    if enable == 0 or type(start) ~= "number" or type(duration) ~= "number"
        or start <= 0 or duration <= 0 or start + duration <= GetTime() then
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

-- Observe the shared native method, not CooldownFrame_SetTimer or individual
-- protected widgets. The hook only records data in our side table; rendering
-- happens later on the driver, after Blizzard finishes its Show/Hide updates.
local nativeCaptureInstalled = false
local function InstallNativeCapture()
    if nativeCaptureInstalled or not hooksecurefunc then return end
    local sample = _G.ActionButton1Cooldown
    local meta = sample and getmetatable(sample)
    local methods = meta and meta.__index
    if type(methods) ~= "table" or type(methods.SetCooldown) ~= "function" then return end
    hooksecurefunc(methods, "SetCooldown", function(frame, start, duration)
        -- Owners with their own timer can opt out. Explicit SarychUI_NotifyCooldown
        -- calls remain authoritative for SUI views that deliberately use this flag.
        if frame.noCooldownCount or frame.__sary_cc_noCount then return end
        if type(start) == "number" and type(duration) == "number"
            and start > 0 and duration > 0 and start + duration > GetTime() then
            CaptureAddonOwner(frame, State(frame))
        end
        handleSetCooldown(frame, start, duration, 1, true)
    end)
    nativeCaptureInstalled = true
end

local BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarLeftButton",
    "MultiBarRightButton",
    "BonusActionButton",
    "VehicleMenuBarActionButton",
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
    module:SetTimerContext(cooldown, "actionBars")
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
        handleSetCooldown(cooldown, start, duration, enable, true)
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
            handleSetCooldown(petCooldown, start, duration, enable, true)
        end
        local formCooldown = _G["ShapeshiftButton" .. i .. "Cooldown"]
        if formCooldown and GetShapeshiftFormCooldown then
            local start, duration, enable = GetShapeshiftFormCooldown(i)
            handleSetCooldown(formCooldown, start, duration, enable, true)
        end
    end
    -- Reconstruct a book that was painted before CC loaded/enabled. Subsequent
    -- page/rank/pet-book updates are covered by the shared SetCooldown hook.
    if SpellBookFrame and SpellBookFrame:IsShown() and SpellBook_GetSpellID and GetSpellCooldown then
        for i = 1, (SPELLS_PER_PAGE or 12) do
            local button = _G["SpellButton" .. i]
            local cooldown = _G["SpellButton" .. i .. "Cooldown"]
            if button and cooldown then
                local id = SpellBook_GetSpellID(button:GetID())
                if id and button:IsShown() and cooldown:IsShown() then
                    local start, duration, enable = GetSpellCooldown(id, SpellBookFrame.bookType)
                    handleSetCooldown(cooldown, start, duration, enable, true)
                else
                    handleSetCooldown(cooldown, 0, 0)
                end
            end
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
                    handleSetCooldown(cooldown, start, duration, enable, true)
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
                        handleSetCooldown(cooldown, expirationTime - duration, duration, 1, true)
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

-- Explicit notifications also support custom widgets that do not use the native
-- Cooldown prototype. API reads recover native buttons already running at startup.
function SarychUI_NotifyCooldown(frame, start, duration, enable, context)
    if context then module:SetTimerContext(frame, context) end
    handleSetCooldown(frame, start, duration, enable)
end

-- Transient cooldown owners can drop their widget without leaving an anchored
-- text host behind for every proc.
function SarychUI_ReleaseCooldown(frame)
    local state = frame and ccState[frame]
    if not state then return end
    ClearCountdown(state, frame)
    if state.host then state.host:ClearAllPoints() end
    timerContexts[frame] = nil
    ccState[frame] = nil
    actionCountdowns[frame] = nil
end

local function installHooks()
    InstallNativeCapture()
    if hooksInstalled then return end
    hooksInstalled = true
    for _, event in ipairs({
        "ACTIONBAR_UPDATE_COOLDOWN", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
        "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_COOLDOWN",
        "PET_BAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN",
        "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD",
        "PLAYER_LOGIN", "PET_BAR_UPDATE", "UNIT_PET", "UPDATE_SHAPESHIFT_FORMS", "SPELLS_CHANGED",
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

-- Capture initial cooldown updates before PLAYER_LOGIN enables the extension.
-- This never creates text or modifies the Blizzard frame while CC is disabled.
InstallNativeCapture()

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
        if not isEnabledFlag or not AddonTimerAllowed(state)
            or (state.start and not WithinDisplayLimit(state.start + state.duration - GetTime())) then
            HideCountdown(state)
        end
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


