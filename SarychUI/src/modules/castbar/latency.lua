-- Player cast acknowledgement latency; shared by Classic and Dragonflight.
local module = SarychUI.modules.castbar
local Latency = {}
module.Latency = Latency

local min, max, floor = math.min, math.max, math.floor
local DF_CHANNEL_LATENCY_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\castbar\\CastingBarInterrupted2"
local function IsOn(value) return value == true or value == 1 end

local function UpdateTextColor(text)
    -- Same network sample and thresholds as the native MainMenuMicroButton.
    -- Cast acknowledgement time remains the number displayed, not the colour input.
    local _, _, latency = GetNetStats()
    latency = tonumber(latency) or 0
    local db = module:DB()
    local alpha = min(1, max(0, tonumber(db and db.castbarLatencyTextAlpha) or 0.7))
    -- FontString colour writes also set its alpha; keep opacity in this path
    -- so native network colour updates cannot reset the slider to fully opaque.
    if latency > (PERFORMANCEBAR_MEDIUM_LATENCY or 600) then
        text:SetTextColor(1, 0, 0, alpha)
    elseif latency > (PERFORMANCEBAR_LOW_LATENCY or 300) then
        text:SetTextColor(1, 1, 0, alpha)
    else
        text:SetTextColor(1, 1, 1, alpha)
    end
end

local function RestoreClassicArt(regions)
    if not regions.holder then return end
    regions.holder:Hide()
    if regions.artParents then
        for region, parent in pairs(regions.artParents) do region:SetParent(parent) end
        regions.artParents = nil
    end
end

local function LayoutClassicOverlay(bar, regions)
    local holder = regions.holder
    local parent = bar:GetParent() or UIParent
    holder:SetParent(parent)
    holder:SetFrameStrata(bar:GetFrameStrata())
    holder:SetFrameLevel(bar:GetFrameLevel() + 1)
    holder:SetScale(bar:GetEffectiveScale() / parent:GetEffectiveScale())
    holder:SetAlpha(bar:GetAlpha())
    holder:ClearAllPoints()
    holder:SetAllPoints(bar)
    if not regions.artParents then
        regions.artParents = {}
        -- Move the real native artwork, not a duplicate. Blizzard continues to
        -- control its colour, visibility and flash through the same globals.
        for _, suffix in ipairs({ "Border", "BorderShield", "Text", "Spark", "Flash" }) do
            local region = _G["CastingBarFrame" .. suffix]
            if region then
                regions.artParents[region] = region:GetParent()
                region:SetParent(holder)
            end
        end
    end
    holder:Show()
end

function Latency:Hide()
    if self.bar and self.bar._suiLatency then
        self.bar._suiLatency.zone:Hide()
        self.bar._suiLatency.text:Hide()
        RestoreClassicArt(self.bar._suiLatency)
    end
end

function Latency:Clear()
    self:Hide()
    self.cast = nil
end

local function EnsureRegions(bar)
    if bar._suiLatency then return bar._suiLatency end
    local holder
    if not module:IsDragonflight() then
        -- Like channel ticks, keep the overlay outside the native StatusBar.
        holder = CreateFrame("Frame", nil, bar:GetParent() or UIParent)
        holder:EnableMouse(false)
        holder:Hide()
    end
    local parent = holder or bar
    local zone = parent:CreateTexture(nil, "BORDER", nil, 1)
    zone:SetVertexColor(1, 0, 0, 0.6)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    bar._suiLatency = { zone = zone, text = text, holder = holder }
    zone:Hide()
    text:Hide()
    bar:HookScript("OnHide", function(self)
        self._suiLatency.zone:Hide()
        self._suiLatency.text:Hide()
        RestoreClassicArt(self._suiLatency)
    end)
    local function Refresh(self)
        if Latency.active and Latency.bar == self then Latency:Refresh() end
    end
    bar:HookScript("OnShow", Refresh)
    bar:HookScript("OnSizeChanged", Refresh)
    if holder then
        hooksecurefunc(bar, "SetAlpha", function(self, alpha)
            if self._suiLatency.artParents then holder:SetAlpha(alpha) end
        end)
        hooksecurefunc(bar, "SetScale", Refresh)
    end
    return bar._suiLatency
end

function Latency:Refresh()
    local cast, bar = self.cast, self.bar
    if not self.active or not cast or not bar or not bar:IsShown() or cast.finish <= GetTime() then
        self:Hide()
        return
    end
    local duration = cast.finish - cast.start
    local width, height = bar:GetWidth(), bar:GetHeight()
    if duration <= 0 or width <= 0 or height <= 0 then self:Hide(); return end
    local fill = bar:GetStatusBarTexture()
    local texture = fill and fill:GetTexture()
    if not texture then self:Hide(); return end
    local regions = EnsureRegions(bar)
    local dragonflight = module:IsDragonflight()
    if dragonflight then
        regions.zone:SetDrawLayer("BORDER", 1)
    else
        LayoutClassicOverlay(bar, regions)
        -- The whole holder is above the native fill. Within it the zone is
        -- below the original ARTWORK border and OVERLAY spark/flash.
        regions.zone:SetDrawLayer("BACKGROUND", 0)
    end
    regions.text:SetDrawLayer("OVERLAY", 7)
    local side = cast.channel and "LEFT" or "RIGHT"
    local fraction = min(1, max(0, cast.lag / duration))
    -- Crop the corresponding end of the full fill image. Reusing the live
    -- fill's UVs would apply its progress clipping twice; mirroring/stretching
    -- a whole image would put the rounded edge in the middle of the bar.
    -- This existing red DF fill has exactly the same alpha as the channel
    -- fill. Avoid desaturation, which rendered the tinted zone grey in-client.
    -- Normal casts retain their original texture and appearance.
    if cast.channel and dragonflight then
        texture = DF_CHANNEL_LATENCY_TEXTURE
    end
    regions.zone:SetTexture(texture)
    regions.zone:SetDesaturated(false)
    regions.zone:SetVertexColor(1, 0, 0, cast.channel and 0.85 or 0.6)
    regions.zone:SetTexCoord(cast.channel and 0 or (1 - fraction), cast.channel and fraction or 1, 0, 1)
    regions.zone:ClearAllPoints()
    regions.zone:SetPoint("TOP" .. side, bar, "TOP" .. side, 0, 0)
    regions.zone:SetSize(width * fraction, height)
    if cast.lag > 0 then regions.zone:Show() else regions.zone:Hide() end
    local db = module:DB()
    local below = db and db.castbarLatencyTextPosition == "below"
    local textGap = dragonflight and 4 or (below and 4 or 9)
    regions.text:ClearAllPoints()
    regions.text:SetPoint((below and "TOP" or "BOTTOM") .. side, bar,
        (below and "BOTTOM" or "TOP") .. side, 0, below and -textGap or textGap)
    regions.text:SetText(string.format("%d ms", floor(cast.lag * 1000 + 0.5)))
    UpdateTextColor(regions.text)
    if db and (db.showCastbarLatencyText == nil or IsOn(db.showCastbarLatencyText)) then
        regions.text:Show()
    else
        regions.text:Hide()
    end
end

local function ReadCast(channel)
    local query = channel and UnitChannelInfo or UnitCastingInfo
    local name, rank, _, _, startTime, endTime, _, castID = query("player")
    if not name or not startTime or not endTime then return end
    return name, rank, startTime / 1000, endTime / 1000, not channel and castID or nil
end

function Latency:OnCastEvent(event, unit, spell, rank, castID)
    if not self.active or unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        self:Clear()
        local sent = self.sent
        self.sent = nil -- Each request can supply only one measurement.
        local channel = event == "UNIT_SPELLCAST_CHANNEL_START"
        local name, subtext, startTime, endTime, id = ReadCast(channel)
        local elapsed = sent and (GetTime() - sent.time)
        -- Ignore missing/stale requests (reload, automatic craft repeats) and
        -- requests for another spell. Do not display an old sample as new lag.
        if not name or not sent or elapsed < 0 or elapsed > 10
            or sent.spell ~= name or (sent.rank and subtext and sent.rank ~= subtext) then return end
        local bar = module:GetStyleFrame("player")
        if not bar then return end
        self.bar = bar
        self.cast = { spell = name, id = id, start = startTime, finish = endTime,
            lag = elapsed, channel = channel }
        self:Refresh()
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local cast = self.cast
        if not cast then return end
        local name, _, startTime, endTime, id = ReadCast(cast.channel)
        if name ~= cast.spell or (id and cast.id and id ~= cast.id) then self:Clear(); return end
        cast.start, cast.finish = startTime, endTime
        self:Refresh() -- Pushback changes duration, not the measured latency.
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local cast = self.cast
        if not cast or (spell and spell ~= cast.spell) then return end
        if castID and cast.id and castID ~= cast.id then return end
        if event == "UNIT_SPELLCAST_STOP" and cast.channel then return end
        if event == "UNIT_SPELLCAST_CHANNEL_STOP" and not cast.channel then return end
        self:Clear()
    end
end

function Latency:Enable()
    if self.active then self:Refresh(); return end
    self.active = true
    if MainMenuBarPerformanceBar and not self.networkColorHooked then
        self.networkColorHooked = true
        hooksecurefunc(MainMenuBarPerformanceBar, "SetVertexColor", function()
            local regions = Latency.bar and Latency.bar._suiLatency
            if Latency.active and Latency.cast and regions then UpdateTextColor(regions.text) end
        end)
    end
    -- Run after the selected renderer has processed the event; no event-order
    -- race with bar creation, visibility or the native cast/channel timeline.
    if CastingBarFrame and not self.classicHooked then
        self.classicHooked = true
        CastingBarFrame:HookScript("OnEvent", function(bar, event, ...)
            if Latency.active and module:GetStyleFrame("player") == bar then
                Latency:OnCastEvent(event, ...)
            end
        end)
    end
    if module.DF and not self.dfHooked then
        self.dfHooked = true
        hooksecurefunc(module.DF, "HandleCastingEvent", function(_, event, ...)
            if Latency.active and module:IsDragonflight() then Latency:OnCastEvent(event, ...) end
        end)
    end
    if not self.events then
        self.events = CreateFrame("Frame")
        self.events:SetScript("OnEvent", function(_, event, unit, spell, rank)
            if event == "PLAYER_ENTERING_WORLD" then
                Latency.sent = nil
                Latency:Clear()
            elseif unit == "player" then
                if event == "UNIT_SPELLCAST_SENT" then
                    Latency.sent = { time = GetTime(), spell = spell, rank = rank }
                elseif Latency.sent and Latency.sent.spell == spell then
                    Latency.sent = nil
                end
            end
        end)
    end
    self.events:RegisterEvent("UNIT_SPELLCAST_SENT")
    self.events:RegisterEvent("UNIT_SPELLCAST_FAILED")
    self.events:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self.events:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Latency:Disable()
    self.active = false
    self.sent = nil
    self:Clear()
    if self.events then self.events:UnregisterAllEvents() end
end

function module:ApplyLatency()
    local db = self:DB()
    if self:IsEnabled() and db and IsOn(db.enableCastbarLatency) then
        Latency:Enable()
    else
        Latency:Disable()
    end
end
