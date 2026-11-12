-- Remaining resource recovery from active effects. Providers return
-- power type and amount; the renderer clips the result to the missing resource.
local UFL = SarychUI.UnitFrameLayers
local providers = {}
local driver = CreateFrame("Frame")
local elapsed = 0
local predictionEnabled
local auraDirty = true
local dispersionDuration, dispersionExpiration
local Tick

function UFL:RegisterResourceGainProvider(key, provider)
    providers[key] = provider
end

UFL:RegisterResourceGainProvider("dispersion", function()
    if select(2, UnitClass("player")) ~= "PRIEST" then return end
    if auraDirty then
        auraDirty = false
        dispersionDuration, dispersionExpiration = nil, nil
        local name = GetSpellInfo(47585)
        for index = 1, 40 do
            local aura, _, _, _, _, duration, expiration, _, _, _, id = UnitBuff("player", index)
            if not aura then break end
            if id == 47585 or (name and aura == name) then
                dispersionDuration, dispersionExpiration = duration, expiration
                break
            end
        end
    end
    local now = GetTime()
    if not dispersionExpiration or dispersionExpiration <= now then return end
    local remaining = math.min(6, dispersionDuration or 6, dispersionExpiration - now)
    return 0, UnitPowerMax("player", 0) * 0.06 * math.max(0, math.ceil(remaining))
end)

function UFL:GetPredictedResourceGain(unit, powerType)
    if unit ~= "player" or UnitIsDeadOrGhost(unit) then return 0 end
    -- Alternatives are not added together: display the largest available recovery.
    local gain = 0
    for _, provider in pairs(providers) do
        local kind, amount = provider(unit, powerType)
        if kind == powerType and type(amount) == "number" then gain = math.max(gain, amount) end
    end
    return math.max(0, math.min(gain, UnitPowerMax(unit, powerType) - UnitPower(unit, powerType)))
end

local function UpdateFrame(self, frame, unit, gain, maximum, current)
    local bar = frame._suiResourcePredictionBar or frame.manabar or frame.powerBar
    local fill = frame._suiResourceGain
    if unit == "player" and bar and not frame.uflDisabled and frame:IsVisible()
        and bar:IsVisible() and gain > 0 and maximum > 0 then
        if not fill then
            fill = bar:CreateTexture(nil, "ARTWORK", nil, 1)
            fill:SetTexture("Interface\\Buttons\\WHITE8X8")
            frame._suiResourceGain = fill
        end
        fill:SetParent(bar)
        local width, height = bar:GetWidth(), bar:GetHeight()
        if width > 0 and height > 0 then
            local vertical = bar.GetOrientation and bar:GetOrientation() == "VERTICAL"
            local reverse = bar.GetReverseFill and bar:GetReverseFill()
            fill:ClearAllPoints()
            if vertical then
                fill:SetPoint(reverse and "TOPLEFT" or "BOTTOMLEFT", bar,
                    reverse and "TOPLEFT" or "BOTTOMLEFT", 0, (reverse and -1 or 1) * height * current / maximum)
                fill:SetSize(width, height * gain / maximum)
            else
                fill:SetPoint(reverse and "TOPRIGHT" or "TOPLEFT", bar,
                    reverse and "TOPRIGHT" or "TOPLEFT", (reverse and -1 or 1) * width * current / maximum, 0)
                fill:SetSize(width * gain / maximum, height)
            end
            self:SetRangeTextureColor(frame, fill, 0.48, 0.44, 0.68, 0.3)
            fill:Show()
        else fill:Hide() end
    elseif fill then fill:Hide() end
end

function UFL:RefreshResourcePrediction(useAuraCache)
    if not useAuraCache then auraDirty = true end
    local settings = self:Settings()
    local enabled = self:IsEnabled() and (not settings or settings.resourceGainPrediction ~= false)
    if predictionEnabled ~= enabled then
        predictionEnabled = enabled
        elapsed = 0
        driver:SetScript("OnUpdate", enabled and Tick or nil)
    end
    if not enabled then
        for frame in pairs(self.frames) do
            if frame._suiResourceGain then frame._suiResourceGain:Hide() end
        end
        if PlayerFrame and PlayerFrame._suiResourceGain then PlayerFrame._suiResourceGain:Hide() end
        return
    end
    local powerType = UnitPowerType("player")
    local maximum = UnitPowerMax("player", powerType)
    local current = UnitPower("player", powerType)
    local gain = enabled and self:GetPredictedResourceGain("player", powerType) or 0
    for frame, unit in pairs(self.frames) do UpdateFrame(self, frame, unit, gain, maximum, current) end
    -- Stock PlayerFrame uses FrameXML hooks, not the external-frame registry.
    if PlayerFrame and not self.frames[PlayerFrame] then UpdateFrame(self, PlayerFrame, "player", gain, maximum, current) end
end

function UFL:SyncResourcePredictionState()
    local settings = self:Settings()
    local enabled = self:IsEnabled() and (not settings or settings.resourceGainPrediction ~= false)
    if predictionEnabled ~= enabled then self:RefreshResourcePrediction() end
end

Tick = function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    UFL:RefreshResourcePrediction(true)
end

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    auraDirty = true
    UFL:RefreshResourcePrediction(true)
end)
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "UNIT_AURA"}) do
    driver:RegisterEvent(event)
end
-- Initial activation also occurs through the shared UFL driver after profile load.
