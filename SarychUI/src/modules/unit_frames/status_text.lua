local module = SarychUI:GetModule("frame")
local ApplyFontScale = SarychUI.Frameworks.ApplyFontScale
local states = {}
local active, hooked = false, false

local function Settings()
    return SarychUI:GetModuleProfile("frame")
end

function module:GetStatusTextScale()
    local db = Settings()
    return math.max(0.5, math.min(1.5, tonumber(db and db.statusTextScale) or 1))
end

local function HideSides(state)
    if state.left then
        state.left:Hide()
        state.right:Hide()
    end
end

local function CreateSide(bar, state, point, offset)
    local text = state.center:GetParent():CreateFontString(nil, "OVERLAY")
    text:SetPoint(point, bar, point, offset, 0)
    text:SetJustifyH(point)
    text:SetShadowColor(state.center:GetShadowColor())
    text:SetShadowOffset(state.center:GetShadowOffset())
    text:Hide()
    return text
end

-- Run after the original 3.3.5 formatter, preserving its CVars, hover locks,
-- zeroText and paused/invalid-bar handling. Layout follows 8.3 TextStatusBar's
-- BOTH mode: percentage on the left, current value on the right.
local function UpdateBar(bar)
    if not active then return end
    local state = states[bar]
    if not state then return end
    HideSides(state)
    local db = Settings()
    if not db or not db.enabled or db.textIndicatorMode ~= "bfa" then return end
    local value = bar:GetValue()
    local _, maximum = bar:GetMinMaxValues()
    if bar.pauseUpdates or not value or not maximum or maximum <= 0
        or (value == 0 and bar.zeroText) or not state.center:IsShown() then return end

    if not state.left then
        state.left = CreateSide(bar, state, "LEFT", 2)
        state.right = CreateSide(bar, state, "RIGHT", -2)
    end
    local scale = module:GetStatusTextScale()
    for _, text in ipairs({ state.left, state.right }) do
        ApplyFontScale(text, state.font, scale)
        text:SetTextColor(state.center:GetTextColor())
        text:SetAlpha(state.center:GetAlpha())
    end
    -- 3.3.5 stores powerType (0 = mana); later FrameXML stores powerToken.
    local supportsPercent = not bar.showNumeric and (not bar.powerType or bar.powerType == 0)
        and (not bar.powerToken or bar.powerToken == "MANA")
    if GetCVar("statusTextPercentage") == "1" and supportsPercent then
        state.left:SetText(math.ceil(value / maximum * 100) .. "%")
        state.left:Show()
    end
    local displayValue = value
    if db.bfaThousandsSeparator then
        displayValue = SarychUI.Frameworks.FormatThousands(value)
    elseif bar.capNumericDisplay then
        displayValue = TextStatusBar_CapDisplayOfNumericValue(value)
    end
    state.right:SetText(displayValue)
    state.right:Show()
    state.center:Hide()
end

function module:RefreshStatusText()
    if not active then return end
    local db = Settings()
    if not db or db.textIndicatorMode ~= "bfa" then return end
    for bar in pairs(states) do TextStatusBar_UpdateTextString(bar) end
end

function module:ApplyStatusTextStyle()
    local db = Settings()
    if not db or not db.enabled then return end
    active = true
    if not hooked then
        hooksecurefunc("TextStatusBar_UpdateTextString", UpdateBar)
        hooked = true
    end
    local scale = self:GetStatusTextScale()
    self:ForEachTextStatusBar(function(bar, center)
        if not center then return end
        local state = states[bar]
        if not state then
            state = { center = center }
            states[bar] = state
        end
        state.font = ApplyFontScale(center, state.font, scale)
        -- Hide mode owns visibility/fades. Do not overwrite them on resize.
        HideSides(state)
        if db.textIndicatorMode == "show" or db.textIndicatorMode == "bfa" then
            TextStatusBar_UpdateTextString(bar)
        end
    end, true)
end

function module:ResetStatusTextStyle()
    active = false
    for bar, state in pairs(states) do
        HideSides(state)
        if state.font then ApplyFontScale(state.center, state.font, 1) end
        state.font = nil
        TextStatusBar_UpdateTextString(bar)
    end
end
