local module = SarychUI.modules.mainmenubar
-- Runtime owned by mainmenubar; legacy tools profile keys are preserved.
local moduleName = "tools"
local S = {}

S.altFpsFrame, S.altFpsShown, S.altFpsAltPressed = nil, false, false

S.altFpsOriginalFonts, S.altFpsReapplyScale = {}, false

local function GetFpsScale(db)
    local scale = db and db.fpsScale
    if type(scale) ~= "number" then
        scale = 1.0
    elseif scale < 0.5 then
        scale = 0.5
    elseif scale > 2.0 then
        scale = 2.0
    end
    return scale
end

local FPS_FONT_FALLBACK = {
    path = "Fonts\\FRIZQT__.TTF",
    size = 10,
    flags = "",
}

local function CacheOriginalFpsFont(fontString, cacheKey)
    if not fontString or not fontString.GetFont or not cacheKey then return end
    if S.altFpsOriginalFonts[cacheKey] then return end

    local fontPath, fontSize, fontFlags = fontString:GetFont()
    if fontPath and fontSize then
        S.altFpsOriginalFonts[cacheKey] = {
            path = fontPath,
            size = fontSize,
            flags = fontFlags or FPS_FONT_FALLBACK.flags,
        }
    end
end

local function ForEachFpsFontString(callback)
    if FramerateLabel then callback(FramerateLabel, "label") end
    if FramerateText then callback(FramerateText, "text") end
end

local function ResetFpsFonts()
    ForEachFpsFontString(function(fontString, cacheKey)
        local cached = S.altFpsOriginalFonts[cacheKey]
        if cached and fontString.SetFont then
            fontString:SetFont(cached.path, cached.size, cached.flags)
        end
    end)

    if FramerateFrame and FramerateFrame.SetScale then
        FramerateFrame:SetScale(1.0)
    end
end

local function ApplyFpsFontScale(fontString, cacheKey, scale)
    if not fontString or not fontString.SetFont then return end

    CacheOriginalFpsFont(fontString, cacheKey)
    local cached = S.altFpsOriginalFonts[cacheKey]
    local fontPath = cached and cached.path or FPS_FONT_FALLBACK.path
    local fontSize = (cached and cached.size or FPS_FONT_FALLBACK.size) * scale
    local fontFlags = cached and cached.flags or FPS_FONT_FALLBACK.flags

    fontString:SetFont(fontPath, fontSize, fontFlags)
end

local function ApplyFpsScale(db)
    db = db or (SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName])

    if not FramerateLabel and not FramerateText then return end

    local altFpsActive = db and db.enabled and db.enableAltFPS == 1
    if not altFpsActive then
        ResetFpsFonts()
        return
    end

    local scale = GetFpsScale(db)
    ForEachFpsFontString(function(fontString, cacheKey)
        ApplyFpsFontScale(fontString, cacheKey, scale)
    end)
end

local function SetFpsPosition()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end

    if not FramerateLabel then return end

    local offsetX = db.fpsOffsetX or 664
    local offsetY = db.fpsOffsetY or 130
    local extraX = tonumber(db.fpsExtraOffsetX) or 0
    local extraY = tonumber(db.fpsExtraOffsetY) or 0
    local _, class = UnitClass("player")
    if class == "PRIEST" or class == "WARLOCK" then
        offsetY = offsetY - 20
    end
    FramerateLabel:ClearAllPoints()
    FramerateLabel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10 + offsetX + extraX, -10 + offsetY + extraY)
    ApplyFpsScale(db)
end

function SarychUI.modules.mainmenubar:SetFpsPosition()
    SetFpsPosition()
end

local function ShowAltFps(db)
    ToggleFramerate()
    SetFpsPosition()
    ApplyFpsScale(db)
    S.altFpsReapplyScale = true
    S.EnsureAltFpsDriver()
end

local function HideAltFps()
    if S.altFpsShown then
        ToggleFramerate()
        S.altFpsShown = false
    end
    -- Ничего не переприменяем на скрытом счётчике: иначе флаг остался бы висеть
    -- и держал драйвер запущенным.
    S.altFpsReapplyScale = false
end

function S.AltFpsNeedsDriver()
    return S.altFpsReapplyScale == true or SarychUI.AltMode == nil
end

function S.AltFpsOnUpdate(self)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local checkDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not checkDb or not checkDb.enabled then
        if S.altFpsShown then
            HideAltFps()
        end
        self:SetScript("OnUpdate", nil)
        return
    end

    -- Re-apply position and font scale next frame after ToggleFramerate (Blizzard may reset on show)
    if S.altFpsReapplyScale and S.altFpsShown then
        SetFpsPosition()
        ApplyFpsScale(checkDb)
        S.altFpsReapplyScale = false
    end

    -- Fallback to direct check if Alt Mode System not available
    if not SarychUI.AltMode then
        if checkDb.enableAltFPS == 1 and IsAltKeyDown() and not S.altFpsShown then
            ShowAltFps(checkDb)
            S.altFpsShown = true
        elseif (checkDb.enableAltFPS ~= 1 or not IsAltKeyDown()) and S.altFpsShown then
            HideAltFps()
        end
    end

    if not S.AltFpsNeedsDriver() then
        self:SetScript("OnUpdate", nil)
    end
end

function S.EnsureAltFpsDriver()
    if not S.altFpsFrame then return end
    if not S.AltFpsNeedsDriver() then return end
    if S.altFpsFrame:GetScript("OnUpdate") then return end
    S.altFpsFrame:SetScript("OnUpdate", S.AltFpsOnUpdate)
end

function SarychUI.modules.mainmenubar:ApplyAltFPS()
    local ownerDB = SarychUI.db.profile.modules.mainmenubar
    if ownerDB and ownerDB.enabled == false then self:DisableAltFPS(); return end
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.altFpsFrame then
            SarychUI.modules.mainmenubar:DisableAltFPS()
        end
        ApplyFpsScale(nil)
        return
    end

    if db.enableAltFPS == 1 then
        -- Enable if not already enabled
        if not S.altFpsFrame then
            SarychUI.modules.mainmenubar:EnableAltFPS()
        else
            -- Just update position if already enabled
            if FramerateLabel and FramerateLabel:IsShown() then
                SetFpsPosition()
            else
                ApplyFpsScale(db)
            end
        end
    else
        -- Disable if enabled
        if S.altFpsFrame then
            SarychUI.modules.mainmenubar:DisableAltFPS()
        end
        ApplyFpsScale(nil)
    end
end

function SarychUI.modules.mainmenubar:ApplyFpsScale()
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    ApplyFpsScale(db)
end

local function AltFPSAltCallback(isAltPressed)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end
    if db.enableAltFPS ~= 1 then
        if S.altFpsShown then
            HideAltFps()
        end
        return
    end

    S.altFpsAltPressed = isAltPressed

    if isAltPressed and not S.altFpsShown then
        ShowAltFps(db)
        S.altFpsShown = true
    elseif not isAltPressed and S.altFpsShown then
        HideAltFps()
    end
end

function SarychUI.modules.mainmenubar:EnableAltFPS()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
    if not db or not db.enabled then return end

    if S.altFpsFrame then return end -- Already enabled

    -- Cache Blizzard default fonts before any scaling
    ForEachFpsFontString(function(fontString, cacheKey)
        CacheOriginalFpsFont(fontString, cacheKey)
    end)

    -- Register Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("altFPS", AltFPSAltCallback)
        S.altFpsAltPressed = SarychUI.AltMode:IsAltPressed() or false
    end

    -- Create frame and register PLAYER_LOGIN event
    S.altFpsFrame = CreateFrame("Frame")
    S.altFpsShown = false

    S.altFpsFrame:RegisterEvent("PLAYER_LOGIN")
    S.altFpsFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            -- Set initial position
            SetFpsPosition()
        end
    end)

    -- Set initial position and scale if FramerateLabel exists
    if FramerateLabel then
        SetFpsPosition()
    end

    S.EnsureAltFpsDriver()
end

function SarychUI.modules.mainmenubar:DisableAltFPS()
    if not S.altFpsFrame then return end

    -- Unregister Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback("altFPS")
    end

    -- Hide FPS if shown
    HideAltFps()

    -- Restore original Blizzard FPS fonts so /fps is unaffected
    ResetFpsFonts()

    -- Unregister events and clear scripts
    S.altFpsFrame:UnregisterAllEvents()
    S.altFpsFrame:SetScript("OnEvent", nil)
    S.altFpsFrame:SetScript("OnUpdate", nil)
    S.altFpsFrame = nil
    S.altFpsShown = false
    S.altFpsAltPressed = false
    S.altFpsReapplyScale = false
end
