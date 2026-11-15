local module = SarychUI.modules.tooltip_control
local S = {}
local function DB() return module:GetDB() end

local function RebuildTooltip(anchorMode)
    if not GameTooltip then return end

    -- Restoring the default anchor must also work after disabling the extension.
    if anchorMode == "cursor" and not module:IsEnabled() then return end

    local mf = GetMouseFocus()
    GameTooltip:ClearAllPoints()
    if anchorMode == "cursor" then
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        S.tooltipCursorAnchored = true
    else
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        S.tooltipCursorAnchored = false
    end

    local rebuilt = false
    if mf and mf.GetScript then
        local onEnter = mf:GetScript("OnEnter")
        if onEnter then
            local ok = pcall(onEnter, mf)
            rebuilt = ok and (GameTooltip:NumLines() or 0) > 0
        end
    end
    if not rebuilt and UnitExists and UnitExists("mouseover") then
        local ok = pcall(GameTooltip.SetUnit, GameTooltip, "mouseover")
        rebuilt = ok and (GameTooltip:NumLines() or 0) > 0
    end
    if not rebuilt then
        GameTooltip:Show()
    end
end

-- Hooks are installed once; callbacks read the current profile and runtime state.
local function TooltipMode()
    local db = DB()
    if not S.tooltipCursorHooked or not db or not module:IsEnabled() then return nil end
    if db.enableTooltipCursor ~= 1 and db.enableTooltipCursor ~= true then return nil end
    return db.tooltipMode == "hidden" and "hidden" or "cursor"
end

-- FrameXML uses the same GameTooltip for both default and owner-anchored tips.
-- Keep our own flag: GameTooltip_OnHide clears tooltip.default, even when we hide it.
local function IsDefaultTooltip(tooltip)
    return tooltip == GameTooltip and (S.tooltipDefaultAnchor or S.tooltipCursorAnchored)
end
local function HideDisabledTooltip(tooltip)
    if TooltipMode() == "hidden" and IsDefaultTooltip(tooltip) then tooltip:Hide() end
end

local function TooltipCursorAltCallback(isAltPressed)
    S.tooltipCursorAltPressed = isAltPressed
    local db = DB()
    if TooltipMode() ~= "cursor" or not db or (db.tooltipCursorAltOnly ~= 1 and db.tooltipCursorAltOnly ~= true) then return end
    if GameTooltip and GameTooltip:IsShown() and IsDefaultTooltip(GameTooltip) then
        RebuildTooltip(isAltPressed and "cursor" or "default")
    end
end

function module:ApplyTooltipCursor()
    local db = DB()
    if not db or not module:IsEnabled()
        or (db.enableTooltipCursor ~= 1 and db.enableTooltipCursor ~= true) then
        self:DisableTooltipCursor()
        if self.ApplyTooltipPosition then self:ApplyTooltipPosition() end
        return
    end
    self:EnableTooltipCursor()
    -- Apply changes to an already visible tooltip immediately.
    if TooltipMode() == "hidden" then
        if GameTooltip then HideDisabledTooltip(GameTooltip) end
    elseif GameTooltip and GameTooltip:IsShown() and IsDefaultTooltip(GameTooltip) then
        local altOnly = db.tooltipCursorAltOnly == 1 or db.tooltipCursorAltOnly == true
        RebuildTooltip((GetMouseFocus() == WorldFrame and (not altOnly or S.tooltipCursorAltPressed)) and "cursor" or "default")
    end
    if self.ApplyTooltipPosition then self:ApplyTooltipPosition() end
end

function module:EnableTooltipCursor()
    if not module:IsEnabled() then return end
    if not S.tooltipCursorHooked and SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("tooltipCursor", TooltipCursorAltCallback)
        S.tooltipCursorAltPressed = SarychUI.AltMode:IsAltPressed() or false
    end
    S.tooltipCursorHooked = true
    self:EnsureTooltipHooks()
end

function module:EnsureTooltipHooks()
    if S.tooltipCursorHooksInstalled then return end
    S.tooltipCursorHooksInstalled = true
    S.tooltipDefaultAnchor = GameTooltip.default == 1
    hooksecurefunc(GameTooltip, "SetOwner", function()
        S.tooltipDefaultAnchor = false
        S.tooltipCursorAnchored = false
    end)
    GameTooltip:HookScript("OnShow", HideDisabledTooltip)
    hooksecurefunc(GameTooltip, "Show", HideDisabledTooltip)
    hooksecurefunc(GameTooltip, "FadeOut", function(tooltip)
        if not TooltipMode() or not IsDefaultTooltip(tooltip) then return end
        tooltip:SetAlpha(1)
        tooltip:Hide()
    end)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if tooltip ~= GameTooltip then return end
        S.tooltipDefaultAnchor = true
        if TooltipMode() == "hidden" then
            HideDisabledTooltip(tooltip)
            return
        end
        local db = DB()
        local altOnly = db.tooltipCursorAltOnly == 1 or db.tooltipCursorAltOnly == true
        if TooltipMode() == "cursor" and GetMouseFocus() == WorldFrame
            and (not altOnly or S.tooltipCursorAltPressed) then
            tooltip:SetOwner(parent or UIParent, "ANCHOR_CURSOR")
            S.tooltipCursorAnchored = true
        elseif module.ApplyDefaultTooltipPosition then
            module:ApplyDefaultTooltipPosition(tooltip)
        end
    end)
    GameTooltip:HookScript("OnHide", function() S.tooltipCursorAnchored = false end)
end

function module:DisableTooltipCursor()
    local wasAnchored = S.tooltipCursorAnchored
    S.tooltipCursorHooked = false
    if SarychUI.AltMode then SarychUI.AltMode:UnregisterCallback("tooltipCursor") end
    S.tooltipCursorAnchored = false
    S.tooltipCursorAltPressed = false
    if wasAnchored and GameTooltip and GameTooltip:IsShown() then RebuildTooltip("default") end
end

-- Position changes must never re-anchor a cursor or an explicitly owned tooltip.
function module:RefreshDefaultTooltipPosition()
    if GameTooltip and GameTooltip:IsShown() and IsDefaultTooltip(GameTooltip)
        and not S.tooltipCursorAnchored then
        GameTooltip_SetDefaultAnchor(GameTooltip, GameTooltip:GetOwner() or UIParent)
    end
end
