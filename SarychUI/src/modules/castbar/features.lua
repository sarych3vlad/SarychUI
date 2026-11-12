local module = SarychUI.modules.castbar
-- Runtime owned by castbar; legacy tools profile keys are preserved.
local S = {}
local floor, max, min = math.floor, math.max, math.min

local format = string.format

local GetTime = GetTime

function S.CastbarTimersDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules.castbar
end

S.castbarTimersHooked = false

local function CreateCastingBarTimer(parentFrame, offsetX, offsetY, fontSize)
    if not parentFrame then return nil end
    local timer = parentFrame:CreateFontString(nil, "OVERLAY")
    timer:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "")
    timer:SetShadowOffset(1, -1)
    timer:SetShadowColor(0, 0, 0, 1)
    timer:SetPoint("CENTER", parentFrame, "CENTER", offsetX, offsetY)
    timer:SetAlpha(1)
    return timer
end

function S.GetCastbarModule()
    return SarychUI and SarychUI.modules and SarychUI.modules.castbar
end

function S.GetCastbarStyleFrame(unitType)
    local castbarMod = S.GetCastbarModule()
    if castbarMod and castbarMod.GetStyleFrame then
        return castbarMod:GetStyleFrame(unitType)
    end
    if unitType == "player" then
        return CastingBarFrame
    elseif unitType == "target" then
        return TargetFrameSpellBar
    elseif unitType == "focus" then
        return FocusFrameSpellBar
    end
    return nil
end

function S.ResolveCastbarUnit(bar)
    if not bar then return nil end
    if bar == CastingBarFrame or bar == S.GetCastbarStyleFrame("player") then
        return "player"
    elseif bar == TargetFrameSpellBar or bar == S.GetCastbarStyleFrame("target") then
        return "target"
    elseif bar == FocusFrameSpellBar or bar == S.GetCastbarStyleFrame("focus") then
        return "focus"
    end
    return nil
end

function S.HideCastbarTimer(bar)
    if bar and bar.timer then
        bar.timer:SetText("")
        bar.timer:Hide()
    end
end

local function UpdateCastingBar(self, elapsed)
    if not self.timer then return end

    -- Settings live under «Кастбар».
    local db = S.CastbarTimersDB()
    if not db or not db.enabled then
        self.timer:SetText("")
        return
    end

    local unitType = S.ResolveCastbarUnit(self)
    local function IsCastbarEnabled()
        if db.enableCastbarTimers ~= 1 then return false end
        if unitType == "player" then
            return db.enableCastbarPlayer == 1
        elseif unitType == "target" then
            return db.enableCastbarTarget == 1
        elseif unitType == "focus" then
            return db.enableCastbarFocus == 1
        end
        return true
    end

    if not IsCastbarEnabled() then
        self.timer:SetText("")
        return
    end

    -- Update interval check
    if not self.updateInterval then
        self.updateInterval = 0.1
    end
    self.updateInterval = self.updateInterval - elapsed
    if self.updateInterval > 0 then return end
    self.updateInterval = 0.1

    local timeLeft, maxValue, casting, channeling
    if self.castingEx or self.channelingEx then
        maxValue = (self.endTime or 0) - (self.startTime or 0)
        if maxValue <= 0 then
            self.timer:SetText("")
            return
        end
        if self.channelingEx then
            timeLeft = max((self.endTime or 0) - GetTime(), 0)
            channeling = true
        else
            timeLeft = max((self.endTime or 0) - GetTime(), 0)
            casting = true
        end
    elseif self.casting then
        timeLeft = max((self.maxValue or 0) - (self.value or 0), 0)
        maxValue = self.maxValue or 0
        casting = true
    elseif self.channeling then
        timeLeft = max(self.value or 0, 0)
        maxValue = self.maxValue or 0
        channeling = true
    else
        self.timer:SetText("")
        return
    end

    if casting then
        if unitType == "player" then
            self.timer:SetText(format(" %2.1f / %1.1f ", timeLeft, maxValue))
        else
            self.timer:SetText(format(" %.1f ", timeLeft))
        end
    elseif channeling then
        self.timer:SetText(format(" %.1f ", timeLeft))
    else
        self.timer:SetText("")
    end
end

function SarychUI.modules.castbar:ApplyCastbarTimers()
    local db = S.CastbarTimersDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.castbarTimersHooked then
            SarychUI.modules.castbar:DisableCastbarTimers()
        end
        return
    end

    if db.enableCastbarTimers == 1 then
        SarychUI.modules.castbar:EnableCastbarTimers()
    else
        if S.castbarTimersHooked then
            SarychUI.modules.castbar:DisableCastbarTimers()
        end
    end
end

function S.GetPlayerCastbarTimerOffset()
    local ox, oy = 0, -20
    local castbarMod = S.GetCastbarModule()
    if castbarMod and castbarMod.IsDragonflight and castbarMod:IsDragonflight() then
        local db = S.CastbarTimersDB()
        ox = ox + (db and tonumber(db.playerTimerOffsetX) or 0)
        oy = oy + (db and tonumber(db.playerTimerOffsetY) or 0)
    end
    return ox, oy
end

function S.ApplyPlayerCastbarTimerOffset()
    local bar = S.GetCastbarStyleFrame("player")
    if not bar or not bar.timer then
        return
    end
    local ox, oy = S.GetPlayerCastbarTimerOffset()
    bar.timer:ClearAllPoints()
    bar.timer:SetPoint("CENTER", bar, "CENTER", ox, oy)
end

function S.EnsureCastbarTimer(bar, offsetX, offsetY, fontSize)
    if not bar then return end
    if not bar.timer then
        bar.timer = CreateCastingBarTimer(bar, offsetX, offsetY, fontSize)
    else
        bar.timer:ClearAllPoints()
        bar.timer:SetPoint("CENTER", bar, "CENTER", offsetX, offsetY)
        bar.timer:Show()
    end
    if not bar.updateInterval then
        bar.updateInterval = 0.1
    end
    if not bar._suiCastTimerHooked then
        bar:HookScript("OnUpdate", UpdateCastingBar)
        bar._suiCastTimerHooked = true
    end
end

function SarychUI.modules.castbar:ApplyPlayerCastbarTimerOffset()
    S.ApplyPlayerCastbarTimerOffset()
end

function SarychUI.modules.castbar:EnableCastbarTimers()
    local db = S.CastbarTimersDB()
    if not db or not db.enabled then return end

    local playerBar = S.GetCastbarStyleFrame("player") or CastingBarFrame
    local targetBar = S.GetCastbarStyleFrame("target") or TargetFrameSpellBar
    local focusBar = S.GetCastbarStyleFrame("focus") or FocusFrameSpellBar

    -- Hide leftover timers on the unused artwork set.
    if playerBar ~= CastingBarFrame then S.HideCastbarTimer(CastingBarFrame) end
    if targetBar ~= TargetFrameSpellBar then S.HideCastbarTimer(TargetFrameSpellBar) end
    if focusBar ~= FocusFrameSpellBar then S.HideCastbarTimer(FocusFrameSpellBar) end
    local castbarMod = S.GetCastbarModule()
    if castbarMod and castbarMod.DF and castbarMod.DF.GetFrame then
        local dfPlayer = castbarMod.DF:GetFrame("player")
        local dfTarget = castbarMod.DF:GetFrame("target")
        local dfFocus = castbarMod.DF:GetFrame("focus")
        if playerBar ~= dfPlayer then S.HideCastbarTimer(dfPlayer) end
        if targetBar ~= dfTarget then S.HideCastbarTimer(dfTarget) end
        if focusBar ~= dfFocus then S.HideCastbarTimer(dfFocus) end
    end

    local playerTimerX, playerTimerY = S.GetPlayerCastbarTimerOffset()
    S.EnsureCastbarTimer(playerBar, playerTimerX, playerTimerY, 13)
    S.EnsureCastbarTimer(targetBar, 92, 0, 12)
    S.EnsureCastbarTimer(focusBar, 92, 0, 12)

    S.castbarTimersHooked = true
end

function SarychUI.modules.castbar:DisableCastbarTimers()
    S.HideCastbarTimer(CastingBarFrame)
    S.HideCastbarTimer(TargetFrameSpellBar)
    S.HideCastbarTimer(FocusFrameSpellBar)
    local castbarMod = S.GetCastbarModule()
    if castbarMod and castbarMod.GetStyleFrame then
        S.HideCastbarTimer(castbarMod:GetStyleFrame("player"))
        S.HideCastbarTimer(castbarMod:GetStyleFrame("target"))
        S.HideCastbarTimer(castbarMod:GetStyleFrame("focus"))
    end
    if castbarMod and castbarMod.DF and castbarMod.DF.GetFrame then
        S.HideCastbarTimer(castbarMod.DF:GetFrame("player"))
        S.HideCastbarTimer(castbarMod.DF:GetFrame("target"))
        S.HideCastbarTimer(castbarMod.DF:GetFrame("focus"))
    end
    S.castbarTimersHooked = false
end
