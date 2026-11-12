-- Shared health-layer framework. Load before templates, layers and events.
SarychUI.UnitFrameLayers = SarychUI.UnitFrameLayers or {}
local UFL = SarychUI.UnitFrameLayers
UFL.frames = UFL.frames or setmetatable({}, { __mode = "k" })
UFL.healComm = LibStub:GetLibrary("LibHealComm-4.0", true)
UFL.absorbMonitor = LibStub:GetLibrary("AbsorbsMonitor-1.0", true)

function UFL:GetRangeColorFactor(frame)
    return frame and frame._suiRangeColorFactor or 1
end

-- Keep each bar's original color separate from the range brightness. Color
-- updates can arrive while a unit is out of range, so never derive the next
-- color from the already darkened status bar.
function UFL:ApplyBarColor(frame, bar, r, g, b, a)
    local factor = self:GetRangeColorFactor(frame)
    if frame and frame._suiFullHealthMuted and
        (bar == frame.healthBar or bar == frame.powerBar) then
        local gray = (r * 0.299 + g * 0.587 + b * 0.114) * 0.55
        r, g, b = gray, gray, gray
    end
    bar:SetStatusBarColor(r * factor, g * factor, b * factor, a)
    if frame and (bar == frame.healthBar or bar == frame.powerBar) then
        local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
        if texture then texture:SetVertexColor(r * factor, g * factor, b * factor, a) end
    end
end

function UFL:SetFullHealthMuted(frame, muted)
    muted = not not muted
    if frame._suiFullHealthMuted == muted then return end
    frame._suiFullHealthMuted = muted
    for bar, color in pairs(frame._suiLayerBarColors or {}) do
        self:ApplyBarColor(frame, bar, unpack(color))
    end
end

function UFL:SetBarColor(frame, bar, r, g, b, a)
    if not bar then return end
    if not frame then bar:SetStatusBarColor(r, g, b, a); return end
    local colors = frame._suiLayerBarColors
    if not colors then
        colors = setmetatable({}, { __mode = "k" })
        frame._suiLayerBarColors = colors
    end
    local color = colors[bar] or {}
    color[1], color[2], color[3], color[4] = r, g, b, a
    colors[bar] = color
    self:ApplyBarColor(frame, bar, r, g, b, a)
end

function UFL:SetTextColor(frame, text, r, g, b, a, vertex)
    if not text then return end
    if not frame then
        if vertex then text:SetVertexColor(r, g, b, a)
        else text:SetTextColor(r, g, b, a) end
        return
    end
    local colors = frame._suiLayerTextColors
    if not colors then
        colors = setmetatable({}, { __mode = "k" })
        frame._suiLayerTextColors = colors
    end
    colors[text] = { r, g, b, a, vertex }
    local factor = self:GetRangeColorFactor(frame)
    if vertex then text:SetVertexColor(r * factor, g * factor, b * factor, a)
    else text:SetTextColor(r * factor, g * factor, b * factor, a) end
end

function UFL:TrackRangeTexture(frame, texture)
    if not frame or not texture or not texture.GetVertexColor or not texture.SetVertexColor then return end
    local colors = frame._suiLayerTextureColors
    if not colors then
        colors = setmetatable({}, { __mode = "k" })
        frame._suiLayerTextureColors = colors
    end
    local color = colors[texture]
    if not color then
        local r, g, b, a = texture:GetVertexColor()
        if not r then return end
        color = { r, g, b, a }
        colors[texture] = color
    end
    local factor = self:GetRangeColorFactor(frame)
    texture:SetVertexColor(color[1] * factor, color[2] * factor,
        color[3] * factor, color[4])
end

function UFL:SetRangeTextureColor(frame, texture, r, g, b, a)
    if not texture then return end
    if not frame then texture:SetVertexColor(r, g, b, a); return end
    local colors = frame._suiLayerTextureColors
    if not colors then
        colors = setmetatable({}, { __mode = "k" })
        frame._suiLayerTextureColors = colors
    end
    local color = colors[texture] or {}
    color[1], color[2], color[3], color[4] = r, g, b, a
    colors[texture] = color
    local factor = self:GetRangeColorFactor(frame)
    texture:SetVertexColor(r * factor, g * factor, b * factor, a)
end

function UFL:SetRangeGradient(frame, texture, orientation, r1, g1, b1, r2, g2, b2)
    if not texture then return end
    if frame then
        local gradients = frame._suiLayerGradientColors
        if not gradients then
            gradients = setmetatable({}, { __mode = "k" })
            frame._suiLayerGradientColors = gradients
        end
        gradients[texture] = { orientation, r1, g1, b1, r2, g2, b2 }
    end
    local factor = self:GetRangeColorFactor(frame)
    texture:SetGradient(orientation, r1 * factor, g1 * factor, b1 * factor,
        r2 * factor, g2 * factor, b2 * factor)
end

local predictionTextures = {
    "myHealPredictionBar", "otherHealPredictionBar", "totalAbsorbBar",
    "totalAbsorbBarOverlay", "overAbsorbGlow", "overHealAbsorbGlow",
    "healAbsorbBar", "healAbsorbBarLeftShadow", "healAbsorbBarRightShadow",
    "myManaCostPredictionBar", "myHealAbsorb", "myHealAbsorbLeftShadow",
    "myHealAbsorbRightShadow", "totalAbsorb", "totalAbsorbOverlay",
}

function UFL:TrackPredictionTextures(frame)
    if not frame then return end
    for _, key in ipairs(predictionTextures) do
        local texture = frame[key]
        if texture and not (frame._suiLayerTextureColors and frame._suiLayerTextureColors[texture]) then
            self:TrackRangeTexture(frame, texture)
        end
    end
end

function UFL:SetRangeColorFactor(frame, factor)
    if not frame then return end
    factor = math.max(0, math.min(1, tonumber(factor) or 1))
    if frame._suiRangeColorFactor == factor and factor == 1 then return end
    frame._suiRangeColorFactor = factor
    local colors = frame._suiLayerBarColors
    for _, bar in pairs({ frame.healthbar, frame.healthBar, frame.manabar,
        frame.powerBar, frame.PlayerFrameHealthBarAnimatedLoss }) do
        if bar then
            local color = colors and colors[bar]
            if not color and bar.GetStatusBarColor then
                local r, g, b, a = bar:GetStatusBarColor()
                if r then
                    colors = colors or setmetatable({}, { __mode = "k" })
                    frame._suiLayerBarColors = colors
                    color = { r, g, b, a }
                    colors[bar] = color
                end
            end
            if color then
                self:ApplyBarColor(frame, bar, unpack(color))
            end
        end
    end
    local texts = frame._suiLayerTextColors
    for _, region in pairs({ frame.name, frame.statusText,
        frame.healthbar and frame.healthbar._suiGladiusValueText,
        frame.manabar and frame.manabar._suiGladiusValueText,
        frame.manabar and frame.manabar._suiGladiusSpecText }) do
        if region then
            local color = texts and texts[region]
            if not color and region.GetTextColor then
                local r, g, b, a = region:GetTextColor()
                if r then
                    texts = texts or setmetatable({}, { __mode = "k" })
                    frame._suiLayerTextColors = texts
                    color = { r, g, b, a, false }
                    texts[region] = color
                end
            end
        end
    end
    if texts then
        for region, color in pairs(texts) do
            if color[5] then
                region:SetVertexColor(color[1] * factor, color[2] * factor,
                    color[3] * factor, color[4])
            else
                region:SetTextColor(color[1] * factor, color[2] * factor,
                    color[3] * factor, color[4])
            end
        end
    end
    self:TrackPredictionTextures(frame)
    local textures = frame._suiLayerTextureColors
    if textures then
        for texture, color in pairs(textures) do
            texture:SetVertexColor(color[1] * factor, color[2] * factor,
                color[3] * factor, color[4])
        end
    end
    local gradients = frame._suiLayerGradientColors
    if gradients then
        for texture, color in pairs(gradients) do
            texture:SetGradient(color[1], color[2] * factor, color[3] * factor,
                color[4] * factor, color[5] * factor, color[6] * factor,
                color[7] * factor)
        end
    end
end

function UFL:GetIncomingHeals(unit, healer)
    if not unit or not self.healComm then return 0 end
    local guid = UnitGUID(unit)
    if not guid then return 0 end
    local caster = healer and UnitGUID(healer)
    return self.healComm:GetHealAmount(guid, self.healComm.ALL_HEALS, GetTime() + 5, caster) or 0
end

function UFL:GetAbsorbs(unit)
    if not unit or not self.absorbMonitor then return 0 end
    local guid = UnitGUID(unit)
    return guid and (self.absorbMonitor.Unit_Total(guid) or 0) or 0
end

function UFL:Settings()
    local profile = SarychUI.db and SarychUI.db.profile
    if not profile then return nil end
    profile.frameworks = profile.frameworks or {}
    local settings = profile.frameworks.unitframelayers
    if not settings then
        settings = profile.addons and profile.addons.UnitFrameLayers
        if not settings then
            settings = { enabled = true, classColorHP = true, playerClassColorHP = false }
        end
        profile.frameworks.unitframelayers = settings
    end
    if profile.addons then profile.addons.UnitFrameLayers = nil end
    return settings
end

function UFL:IsEnabled()
    local settings = self:Settings()
    return not settings or settings.enabled ~= false
end

function UFL:AreUnitFrameColorsEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local config = profile and profile.modules and profile.modules.frame
    return not self._unitFrameColorsDisabled and config and config.enabled ~= false and config.enabled ~= 0
end

function UFL:SetUnitFrameColorsEnabled(enabled)
    self._unitFrameColorsDisabled = not enabled
    local frames = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }
    for i = 1, 4 do
        frames[#frames + 1] = "PartyMemberFrame" .. i
        frames[#frames + 1] = "PartyMemberFrame" .. i .. "PetFrame"
    end
    for _, name in ipairs(frames) do
        local frame = _G[name]
        local bar = frame and (frame.healthbar or _G[name .. "HealthBar"])
        if bar and not frame.uflSkipColor then
            if enabled then
                if UpdateHealthBarColor then UpdateHealthBarColor(frame) end
            elseif frame._suiLayerBarColors and frame._suiLayerBarColors[bar] then
                frame._suiLayerBarColors[bar] = nil
                if UnitFrameHealthBar_Update then
                    UnitFrameHealthBar_Update(bar, frame.unit or bar.unit)
                end
            end
        end
    end
end

function UFL:Register(frame, unit)
    if not frame or type(unit) ~= "string" then return nil end
    if not frame.unit then frame.unit = unit end
    if not frame.healthbar and frame.healthBar then frame.healthbar = frame.healthBar end
    self.frames[frame] = unit
    if self:IsEnabled() and frame.healthbar and UnitFrameLayers_AttachHealPrediction
        and not (InCombatLockdown and InCombatLockdown()) then
        local skipCallback = unit:match("^arena%d+$") ~= nil
        UnitFrameLayers_AttachHealPrediction(frame, frame.uflSkipColor == true, skipCallback)
        if UnitFrameLayers_SetHealPredictionEnabled then
            UnitFrameLayers_SetHealPredictionEnabled(frame, true)
        end
        UnitFrameLayers_UpdateHealPrediction(frame)
    end
    return frame
end

function UFL:RegisterExternal(frame, unit, update)
    if not frame or type(unit) ~= "string" or type(update) ~= "function" then return end
    self.frames[frame] = unit
    frame._suiLayerUpdater = update
    if self.RegisterLibraryCallbacks and not frame._suiLayerCallbacks then
        self.RegisterLibraryCallbacks(frame)
        frame._suiLayerCallbacks = true
    end
    self:Update(frame)
end

function UFL:Unregister(frame)
    if not frame then return end
    self.frames[frame] = nil
    if frame._suiResourceGain then frame._suiResourceGain:Hide() end
    if UnitFrameLayers_SetHealPredictionEnabled then
        UnitFrameLayers_SetHealPredictionEnabled(frame, false)
    end
end

function UFL:Update(frame)
    if frame and self:IsEnabled() then
        if frame._suiLayerUpdater then
            frame._suiLayerUpdater(frame)
        elseif UnitFrameLayers_UpdateHealPrediction then
            UnitFrameLayers_UpdateHealPrediction(frame)
        end
    end
end

-- PartyMemberFrame is protected. Keep prediction artwork on an independent
-- overlay so the native frame and its event handler remain unmodified.
function UFL:RefreshPartyOverlays()
    if InCombatLockdown and InCombatLockdown() then return end
    self.partyOverlays = self.partyOverlays or {}
    local showParty = self:IsEnabled() and SarychUI.Compat.GetDisplayedAllyFrames
        and SarychUI.Compat.GetDisplayedAllyFrames() == "party"
    for index = 1, 4 do
        local native = _G["PartyMemberFrame" .. index]
        local bar = _G["PartyMemberFrame" .. index .. "HealthBar"]
            or (native and native.healthbar)
        if native and bar and (showParty or self.partyOverlays[index]) then
            local overlay = self.partyOverlays[index]
            if not overlay then
                overlay = CreateFrame("Frame", "SarychUIPartyLayers" .. index, UIParent)
                overlay:SetAllPoints(bar)
                overlay:SetFrameStrata(native:GetFrameStrata())
                overlay:SetFrameLevel(bar:GetFrameLevel() + 1)
                overlay:EnableMouse(false)
                overlay.unit = "party" .. index
                overlay.healthbar = bar
                overlay.uflSkipColor = true
                overlay.uflNoAnimatedLoss = true
                self.partyOverlays[index] = overlay
                if UnitFrameLayers_AttachHealPrediction then
                    UnitFrameLayers_AttachHealPrediction(overlay, true, true)
                end
                self:RegisterExternal(overlay, overlay.unit, UnitFrameLayers_UpdateHealPrediction)
            end
            local shown = showParty and native:IsVisible()
            SarychUI.WidgetAPI.SetShown(overlay, shown)
            if shown then self:Update(overlay) end
        end
    end
end
