-- Native FrameXML casting bars embedded in the compact frame's header.
local module = SarychUI.modules.group_frames
local bars = {}
local serial = 0

local function DB()
    local profile = SarychUI.db and SarychUI.db.profile
    return profile and profile.modules and profile.modules.group_frames
end

function module:CanShowHeaderCast(frame)
    local db = DB()
    if self.headerCastsDisabled or not db or db.enabled == false or not db.castbarEnabled then return false end
    if not frame or not frame.unit or frame._suiTestData or not frame.name or not frame.roleIcon then return false end
    local unit = frame.displayedUnit or frame.unit
    if db.castbarHidePlayer and UnitIsUnit(unit, "player") then return false end
    return true
end

local function HeaderAlpha(bar, alpha)
    local frame = bar.owner
    if alpha < 1 and not bar.headerAlpha then
        bar.headerAlpha = {name = frame.name:GetAlpha(), role = frame.roleIcon:GetAlpha()}
    end
    local saved = bar.headerAlpha
    if saved then
        frame.name:SetAlpha(saved.name * alpha)
        frame.roleIcon:SetAlpha(saved.role * alpha)
        if alpha == 1 then bar.headerAlpha = nil end
    end
end

local function Reset(bar)
    bar.casting, bar.channeling, bar.flash, bar.fadeOut = nil, nil, nil, nil
    bar.holdTime, bar.fadeIn = 0, nil
    HeaderAlpha(bar, 1)
end

local function Layout(bar)
    local frame, name = bar.owner, bar:GetName()
    local width = math.max(8, frame:GetWidth() - 23)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -4)
    bar:SetSize(width, 10)
    bar:SetFrameLevel(frame:GetFrameLevel() + 5)
    -- Same small border, shield, flash, font and icon as TargetFrame's bar.
    SetTargetSpellbarAspect(bar)
    for _, suffix in ipairs({"Border", "BorderShield", "Flash"}) do
        _G[name .. suffix]:SetWidth(width * 197 / 150)
    end
    local text, icon = _G[name .. "Text"], _G[name .. "Icon"]
    text:SetWidth(width)
    text:SetWordWrap(false)
    icon:ClearAllPoints()
    icon:SetPoint("RIGHT", bar, "LEFT", -3, 0)
    icon:SetSize(12, 12)
    icon:Show()
end

local function HandleEvent(bar, event, ...)
    if not module:CanShowHeaderCast(bar.owner) then
        bar:Hide(); Reset(bar)
        return
    end
    local unit = bar.owner.displayedUnit or bar.owner.unit
    if bar.unit ~= unit then
        Reset(bar)
        bar.unit = unit
        event = "PLAYER_ENTERING_WORLD"
    end
    if event == "PLAYER_ENTERING_WORLD" and not UnitCastingInfo(unit) and not UnitChannelInfo(unit) then
        bar:Hide(); Reset(bar)
        return
    end
    local start = event == "PLAYER_ENTERING_WORLD" or
        ((event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") and (...) == unit)
    CastingBarFrame_OnEvent(bar, event, ...)
    if bar.fadeIn and bar.fadeOut then
        -- A short cast can finish before the incoming transition has completed.
        bar.fadeIn = nil
        bar:SetAlpha(1)
        HeaderAlpha(bar, 0)
    end
    if start and (bar.casting or bar.channeling) and bar:IsShown() then
        bar.fadeIn = 0
        bar:SetAlpha(0)
        HeaderAlpha(bar, 1)
    end
end

local function CreateBar(frame)
    serial = serial + 1
    local bar = CreateFrame("StatusBar", "SarychUIGroupHeaderCast" .. serial, frame, "CastingBarFrameTemplate")
    bar:UnregisterAllEvents()
    -- The template's OnLoad assigns "player" before we remove its events.
    -- Clear that provisional unit so the first player binding registers them.
    bar.unit = nil
    bar.owner = frame
    bar:EnableMouse(false)
    bar:SetScript("OnEvent", HandleEvent)
    bar:SetScript("OnHide", function(self) Reset(self) end)
    bar:SetScript("OnUpdate", function(self, elapsed)
        if not module:CanShowHeaderCast(frame) then self:Hide(); return end
        CastingBarFrame_OnUpdate(self, elapsed)
        if not self:IsShown() then return end
        if self.fadeIn and (self.casting or self.channeling) then
            self.fadeIn = math.min(1, self.fadeIn + elapsed / 0.2)
            self:SetAlpha(self.fadeIn)
            if self.fadeIn == 1 then self.fadeIn = nil end
        end
        HeaderAlpha(self, 1 - self:GetAlpha())
    end)
    bar:Hide()
    bars[frame] = bar
    frame:HookScript("OnShow", function() module:UpdateHeaderCast(frame, true) end)
    frame:HookScript("OnHide", function() Reset(bar) end)
    frame:HookScript("OnSizeChanged", function() Layout(bar) end)
    return bar
end

function module:UpdateHeaderCast(frame, resync)
    local bar = bars[frame]
    if not self:CanShowHeaderCast(frame) then
        if bar then bar:UnregisterAllEvents(); bar.unit = nil; bar:Hide(); Reset(bar) end
        return
    end
    if not bar then bar = CreateBar(frame) end
    Layout(bar)
    local unit = frame.displayedUnit or frame.unit
    if bar.unit ~= unit or resync then
        bar:Hide()
        bar:UnregisterAllEvents()
        CastingBarFrame_OnLoad(bar, unit, true, true)
        _G[bar:GetName() .. "Icon"]:Show()
        -- Do not run FinishSpell on an idle frame (which would flash an empty bar).
        if UnitCastingInfo(unit) or UnitChannelInfo(unit) then HandleEvent(bar, "PLAYER_ENTERING_WORLD") end
    end
end

function module:ApplyHeaderCastbars()
    local db = DB()
    self.headerCastsDisabled = not db or db.enabled == false
    if not self.headerCastHooks then
        hooksecurefunc("CompactUnitFrame_SetUnit", function(frame) module:UpdateHeaderCast(frame) end)
        hooksecurefunc("DefaultCompactUnitFrameSetup", function(frame) module:UpdateHeaderCast(frame) end)
        self.headerCastHooks = true
    end
    if CompactRaidFrameContainer and CompactRaidFrameContainer_ApplyToFrames then
        CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, "normal",
            function(frame) self:UpdateHeaderCast(frame, true) end)
    end
    for _, frame in pairs(self.testFrames or {}) do self:UpdateHeaderCast(frame, true) end
    for frame in pairs(bars) do self:UpdateHeaderCast(frame, true) end
end

function module:DisableHeaderCastbars()
    self.headerCastsDisabled = true
    for frame in pairs(bars) do self:UpdateHeaderCast(frame) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent", function() module:ApplyHeaderCastbars() end)
