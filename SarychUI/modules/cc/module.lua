-- SarychUI Crowd Control (Cooldown Text) Module
local format = string.format
local floor = math.floor
local min, max = math.min, math.max

local moduleName = "cc"
local module = {}

-- Register module
SarychUI:RegisterModule(moduleName, module)

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
local minuteSuffix = (locale == "ruRU") and " м." or "m"

-- Helpers to access settings with sane fallbacks
local function getSetting(key, default)
    local db = DB()
    if db and db[key] ~= nil then return db[key] end
    return default
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

-- Time formatting based on remaining seconds and settings
local function formatCooldownText(seconds)
    local defaultColor = getSetting("defaultColor", {1, 1, 1, 1})
    local fontSizeSmall = getSetting("fontSizeSmall", 14)
    local fontSizeMedium = getSetting("fontSizeMedium", 12)
    local fontSizeLarge = getSetting("fontSizeLarge", 12)

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

-- Per-frame update
local function cooldown_OnUpdate(frame, elapsed)
	-- Проверяем, включен ли модуль
	if not isEnabledFlag then 
		local textObj = frame.SarychUI_ccText
		if textObj then textObj:Hide() end
		return 
	end
    
    local textObj = frame.SarychUI_ccText
    if not textObj or not textObj:IsShown() then return end

    frame.__sary_cc_nextUpdate = (frame.__sary_cc_nextUpdate or 0) - elapsed
    if frame.__sary_cc_nextUpdate > 0 then return end

    local minIconSize = getSetting("minIconSize", 23)
    if frame:GetWidth() < minIconSize or frame:GetHeight() < minIconSize then
        textObj:SetText("")
        textObj:Hide()
        return
    end

    local minScale = getSetting("minScale", 0.5)
    if (frame:GetEffectiveScale() / UIParent:GetEffectiveScale()) < minScale then
        textObj:SetText("")
        frame.__sary_cc_nextUpdate = 1
        return
    end

    local start = frame.__sary_cc_start or 0
    local duration = frame.__sary_cc_duration or 0
    local remain = duration - ((GetTime and GetTime() or 0) - start)
    if floor(remain + 0.5) <= 0 then
        textObj:Hide()
        return
    end

    local displayText, color, interval, fontSize = formatCooldownText(remain)

    local fontPath = ResolveFontPath(getSetting("font", "Friz Quadrata TT"))
    local fontFlags = getSetting("fontFlags", "OUTLINE")
    local scale = min((frame:GetParent() and frame:GetParent():GetWidth() or 36) / 36, 1)
    local adjustedSize = max(fontSize * scale, 1)
    textObj:SetFont(fontPath, adjustedSize, fontFlags)
    textObj:SetText(displayText)
    textObj:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    textObj:SetWidth(50)
    textObj:SetJustifyH("CENTER")

    frame.__sary_cc_nextUpdate = interval
end

local function ensureText(frame)
    if frame.SarychUI_ccCreated then return frame.SarychUI_ccText end

    local minScale = getSetting("minScale", 0.5)
    local parent = frame:GetParent()
    local pWidth = parent and parent:GetWidth() or 36
    local scale = min(pWidth / 36, 1)
    if scale < minScale then
        frame.__sary_cc_noCount = true
        return nil
    end

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", 0, 1)

    local fontPath = ResolveFontPath(getSetting("font", "Friz Quadrata TT"))
    local fontFlags = getSetting("fontFlags", "OUTLINE")
    local fontSizeLarge = getSetting("fontSizeLarge", 12)
    local adjustedSize = max(fontSizeLarge * scale, 1)
    text:SetFont(fontPath, adjustedSize, fontFlags)

    local color = getSetting("defaultColor", {1, 1, 1, 1})
    text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    text:SetWidth(50)
    text:SetJustifyH("CENTER")

    frame.SarychUI_ccText = text
    frame.SarychUI_ccCreated = true
    frame:SetScript("OnUpdate", cooldown_OnUpdate)
    return text
end

-- Central SetCooldown bridge
local function handleSetCooldown(frame, start, duration)
	if not isEnabledFlag then return end
	if not frame then return end

	local minDuration = getSetting("minDuration", 3)
    if start and start > 0 and duration and duration > minDuration then
        frame.__sary_cc_start = start
        frame.__sary_cc_duration = duration
        frame.__sary_cc_nextUpdate = 0
        if not frame.__sary_cc_noCount then
            local text = frame.SarychUI_ccText or ensureText(frame)
            if text then text:Show() end
        end
    else
        local text = frame.SarychUI_ccText
        if text then text:Hide() end
    end
end

-- Install hooks once
local function installHooks()
    if hooksInstalled then return end

    if ActionButton1Cooldown then
        local mt = getmetatable(ActionButton1Cooldown)
        local idx = mt and mt.__index
        if idx and idx.SetCooldown and not module._hookedSetMethod then
            hooksecurefunc(idx, "SetCooldown", handleSetCooldown)
            module._hookedSetMethod = true
        end
    end

    if type(CooldownFrame_SetTimer) == "function" and not module._hookedSetTimer then
        hooksecurefunc("CooldownFrame_SetTimer", function(frame, start, duration)
            handleSetCooldown(frame, start, duration)
        end)
        module._hookedSetTimer = true
    end

    hooksInstalled = true
end

function module:ApplySettings()
    isEnabledFlag = DB() and DB().enabled ~= false
    -- Timers tab (castbar / invite / arena) is hosted here; runtime stays in tools.
    local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
    if tools then
        if tools.ApplyCastbarTimers then tools:ApplyCastbarTimers() end
        if tools.ApplyInviteCountdown then tools:ApplyInviteCountdown() end
        if tools.ApplyArenaCountdown then tools:ApplyArenaCountdown() end
    end
end

function module:Enable()
    isEnabledFlag = true
    installHooks()
    self:ApplySettings()
    
    -- Восстанавливаем OnUpdate скрипты и перезапускаем активные кулдауны
    for i = 1, 120 do -- Проверяем все возможные кнопки действий
        local button = _G["ActionButton" .. i]
        if button and button.cooldown then
            local cooldownFrame = button.cooldown
            if cooldownFrame.SarychUI_ccCreated then
                cooldownFrame:SetScript("OnUpdate", cooldown_OnUpdate)
                -- Перезапускаем кулдаун если он активен
                local start = cooldownFrame.__sary_cc_start
                local duration = cooldownFrame.__sary_cc_duration
                if start and duration and start > 0 and duration > 0 then
                    local remain = duration - ((GetTime and GetTime() or 0) - start)
                    if remain > 0 then
                        cooldownFrame.__sary_cc_nextUpdate = 0
                        local text = cooldownFrame.SarychUI_ccText
                        if text then text:Show() end
                    end
                end
            end
        end
    end
    
    -- Также восстанавливаем на других возможных фреймах кулдаунов
    local function restoreCooldownScripts(frame)
        if frame.SarychUI_ccCreated then
            frame:SetScript("OnUpdate", cooldown_OnUpdate)
            -- Перезапускаем кулдаун если он активен
            local start = frame.__sary_cc_start
            local duration = frame.__sary_cc_duration
            if start and duration and start > 0 and duration > 0 then
                local remain = duration - ((GetTime and GetTime() or 0) - start)
                if remain > 0 then
                    frame.__sary_cc_nextUpdate = 0
                    local text = frame.SarychUI_ccText
                    if text then text:Show() end
                end
            end
        end
    end
    
    -- Проходим по всем дочерним фреймам UIParent
    local function traverseFrames(parent)
        local children = {parent:GetChildren()}
        for i = 1, #children do
            local child = children[i]
            restoreCooldownScripts(child)
            traverseFrames(child)
        end
    end
    
    if UIParent then
        traverseFrames(UIParent)
    end
end

function module:Disable()
    isEnabledFlag = false
    
    -- Скрываем все тексты кулдаунов и останавливаем OnUpdate
    for i = 1, 120 do -- Проверяем все возможные кнопки действий
        local button = _G["ActionButton" .. i]
        if button and button.cooldown then
            local cooldownFrame = button.cooldown
            if cooldownFrame.SarychUI_ccText then
                cooldownFrame.SarychUI_ccText:Hide()
            end
            if cooldownFrame:GetScript("OnUpdate") == cooldown_OnUpdate then
                cooldownFrame:SetScript("OnUpdate", nil)
            end
        end
    end
    
    -- Также проверяем другие возможные фреймы кулдаунов
    local function hideAllCooldownTexts(frame)
        if frame.SarychUI_ccText then
            frame.SarychUI_ccText:Hide()
        end
        if frame:GetScript("OnUpdate") == cooldown_OnUpdate then
            frame:SetScript("OnUpdate", nil)
        end
    end
    
    -- Проходим по всем дочерним фреймам UIParent
    local function traverseFrames(parent)
        local children = {parent:GetChildren()}
        for i = 1, #children do
            local child = children[i]
            hideAllCooldownTexts(child)
            traverseFrames(child)
        end
    end
    
    if UIParent then
        traverseFrames(UIParent)
    end

    -- Timers tab also follows cc enable state.
    local tools = SarychUI and SarychUI.modules and SarychUI.modules.tools
    if tools then
        if tools.DisableCastbarTimers then tools:DisableCastbarTimers() end
        if tools.DisableInviteCountdown then tools:DisableInviteCountdown() end
        if tools.DisableArenaCountdown then tools:DisableArenaCountdown() end
    end
end


