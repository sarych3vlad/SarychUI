local module = SarychUI.modules.floating_text
-- Runtime owned by floating_text; legacy tools profile keys are preserved.
local S = {}
local SuiTimer = select(2, ...).Compat.Timer

local pairs, select, pcall = pairs, select, pcall

local floor, max, min = math.floor, math.max, math.min

local gsub, find, gmatch = string.gsub, string.find, string.gmatch

local tinsert = table.insert

local GetTime = GetTime

local FLOATING_TEXT_MODULE = "floating_text"

local function FloatingTextDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[FLOATING_TEXT_MODULE]
end

-- Session-only preview: use the real rendering paths, without broadcasting events,
-- echoing errors to chat, playing sounds, or persisting the test in a profile.
function module:IsTestModeEnabled()
    return S.testModeEnabled == true
end

function module:ShowTestMessages()
    local db = FloatingTextDB()
    if not S.testModeEnabled then return end
    if not db or not db.enabled then self:StopTestMode(); return end
    S.testStep = (S.testStep or 0) + 1
    local prefix = SarychUI:T("ui.options_ec1868c5a7") .. ": "
    -- Bypass the error router deliberately: hidden errors also need a visual
    -- sample, and test traffic must not affect its duplicate suppression.
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(prefix .. (ERR_SPELL_COOLDOWN or SPELL_FAILED_NOT_READY or
            SarychUI:T("ui.error_filter_92f36794")), 1, 0.1, 0.1, 1)
    end
    local frames = S.errorFilterFrames
    if frames.enabled and db.errorExtraEnabled == 1 and frames.filtered then
        frames.filtered:AddMessage(prefix .. SarychUI:T("ui.extra_error_frame_5571a4e3"), 1, 0.1, 0.1, 1)
    end
    local sys = frames.enabled and frames.sys or UIErrorsFrame
    if sys then
        sys:AddMessage(prefix .. SarychUI:T("ui.system_messages_b49f1ebf"), 1, 1, 0, 1)
    end
    if RaidNotice_AddMessage and RaidBossEmoteFrame then
        RaidNotice_AddMessage(RaidBossEmoteFrame,
            prefix .. SarychUI:T("ui.game_notifications_fe17712d"), {r = 1, g = 0.82, b = 0})
    end
    if CombatText_AddMessage then
        local scroll = COMBAT_TEXT_SCROLL_FUNCTION or CombatText_StandardScroll
        if scroll then
            CombatText_AddMessage("-" .. (1250 + S.testStep % 7 * 137), scroll, 1, 0.1, 0.1)
            CombatText_AddMessage("+" .. (2400 + S.testStep % 5 * 213), scroll, 0.1, 1, 0.1)
            CombatText_AddMessage("<" .. SarychUI:T("ui.options_ec1868c5a7") .. ">", scroll, 1, 0.82, 0)
        end
    end
    local frameDb = SarychUI.db.profile.modules.frame or {}
    if CombatFeedback_OnCombatEvent then
        local event = S.testStep % 2 == 0 and "HEAL" or "WOUND"
        if PlayerFrame and PlayerFrame.feedbackText and frameDb.hidePlayerHitIndicator ~= 1 then
            CombatFeedback_OnCombatEvent(PlayerFrame, event, "", 1250, 1)
        end
        if PetFrame and PetFrame.feedbackText and PetFrame:IsShown() and frameDb.hidePetHitIndicator ~= 1 then
            CombatFeedback_OnCombatEvent(PetFrame, event, "", 350, 1)
        end
    end
end

function module:StartTestMode()
    local db = FloatingTextDB()
    if S.testModeEnabled or not db or not db.enabled then return end
    if not CombatText_AddMessage and LoadAddOn then LoadAddOn("Blizzard_CombatText") end
    self:ApplyAll()
    S.testModeEnabled = true
    S.testStep = 0
    if CombatText then
        S.testCombatWasShown = CombatText:IsShown()
        CombatText:Show()
    end
    if not S.testFrame then S.testFrame = CreateFrame("Frame") end
    S.testFrame.elapsed = 0
    S.testFrame:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = frame.elapsed + elapsed
        if frame.elapsed >= 1.5 then
            frame.elapsed = 0
            module:ShowTestMessages()
        end
    end)
    S.testFrame:Show()
    self:ShowTestMessages()
end

function module:StopTestMode()
    if not S.testModeEnabled then return end
    S.testModeEnabled = false
    if S.testFrame then
        S.testFrame:SetScript("OnUpdate", nil)
        S.testFrame:Hide()
    end
    -- Do not clear shared frames: real notifications may have arrived during
    -- the test. Existing samples finish their normal fade.
    if CombatText and S.testCombatWasShown == false
        and GetCVar and GetCVar("enableFloatingCombatText") ~= "1" then
        CombatText:Hide()
    end
    S.testCombatWasShown = nil
end


S.combatTextHooked, S.combatTextHooks, S.combatTextFlag = false, {}, false

S.combatTextFrame, S.combatTextPlusAnchor, S.combatTextMinusAnchor, S.combatTextLessAnchor = nil, nil, nil, nil

S.raidBossEmoteHooked, S.raidBossEmoteFrame, S.raidBossRepositioned = false, nil, false

S.originalRaidBossPosition, S.originalRaidBossWidth, S.lastAppliedOffset = nil, nil, nil

S.errorFilterInitialized = false

S.errorFilterFrames = {
    created = false,
    enabled = false,
    altOnly = false,
    lastMsg = nil,
    lastAt = 0,
    origHandler = nil,
    filtered = nil, -- FilteredErrorsFrame
    sys = nil, -- SysMsgInfoFrame
}

function SarychUI.modules.floating_text:ApplyCombatTextAdjust()
    local db = FloatingTextDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.combatTextHooked then
            SarychUI.modules.floating_text:DisableCombatTextAdjust()
        end
        return
    end

    if db.enableHealCombatTextAdjust == 1 then
        -- Enable if not already enabled
        if not S.combatTextHooked then
            SarychUI.modules.floating_text:EnableCombatTextAdjust()
        end
    else
        -- Disable if enabled
        if S.combatTextHooked then
            SarychUI.modules.floating_text:DisableCombatTextAdjust()
        end
    end
end

function SarychUI.modules.floating_text:EnableCombatTextAdjust()
    local db = FloatingTextDB()
    if not db or not db.enabled then return end

    if S.combatTextHooked then return end -- Already enabled

    -- Ensure Blizzard floating combat text CVars are enabled so text cannot disappear due to client settings
    pcall(function()
        if GetCVar and SetCVar then
            if GetCVar("floatingCombatTextCombatDamage") ~= "1" then SetCVar("floatingCombatTextCombatDamage", 1) end
            if GetCVar("floatingCombatTextCombatHealing") ~= "1" then SetCVar("floatingCombatTextCombatHealing", 1) end
        end
    end)

    -- Hook CombatText frames when Blizzard_CombatText is loaded
    S.combatTextFrame = CreateFrame("Frame")
    S.combatTextFrame:RegisterEvent("ADDON_LOADED")
    S.combatTextFrame:SetScript("OnEvent", function(self, event, addonName)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then return end
        if checkDb.enableHealCombatTextAdjust ~= 1 then return end

        if addonName ~= "Blizzard_CombatText" then return end

        -- Hook SetPoint for all CombatText frames
        for i = 1, 20 do
            local region = _G["CombatText" .. i]
            if region and not region._SarychUICombatTextHooked then
                region._SarychUICombatTextHooked = true
                hooksecurefunc(region, "SetPoint", function(s, a, b, c, d, e)

                    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
                    local hookDb = FloatingTextDB()
                    if not hookDb or not hookDb.enabled then return end
                    if hookDb.enableHealCombatTextAdjust ~= 1 then return end

                    -- Prevent infinite loop
                    if S.combatTextFlag then
                        S.combatTextFlag = false
                        return
                    end

                    local text = s.GetText and s:GetText()
                    if text then

                        S.combatTextFlag = true
                        local first = text:sub(1, 1)

                        if first == '+' then
                            -- Shift "+" lines (incoming heal)
                            if hookDb.healShiftPlus == 1 then
                                local plusX = hookDb.healPlusX or -467
                                local plusY = hookDb.healPlusY or -45
                                s:SetPoint(a, b, c, d + plusX, e + plusY)
                            else
                                S.combatTextFlag = false
                            end
                        elseif first == '-' then
                            -- Shift "-" lines (incoming damage)
                            if hookDb.healShiftMinus == 1 then
                                local minusX = hookDb.healMinusX or 0
                                local minusY = hookDb.healMinusY
                                if minusY == nil then minusY = -50 end
                                s:SetPoint(a, b, c, d + minusX, e + minusY)
                            else
                                S.combatTextFlag = false
                            end
                        elseif first == '<' then
                            -- Handle "<" lines (procs / reactive text)
                            if hookDb.healHideLess == 1 then
                                -- Hide lines starting with "<"
                                s:SetText("")
                                S.combatTextFlag = false
                            elseif hookDb.healShiftLess == 1 then
                                -- Shift "<" lines
                                local lessX = hookDb.healLessX or -250
                                local lessY = hookDb.healLessY or -30
                                s:SetPoint(a, b, c, d + lessX, e + lessY)
                            else
                                S.combatTextFlag = false
                            end
                        else
                            S.combatTextFlag = false
                        end
                    end

                end)
            end
        end

        S.combatTextHooked = true
        S.combatTextFrame:UnregisterEvent("ADDON_LOADED")
    end)

    -- If Blizzard_CombatText is already loaded, hook immediately
    if IsAddOnLoaded("Blizzard_CombatText") then
        S.combatTextFrame:GetScript("OnEvent")(S.combatTextFrame, "ADDON_LOADED", "Blizzard_CombatText")
    end
end

function SarychUI.modules.floating_text:DisableCombatTextAdjust()
    if not S.combatTextHooked then return end

    -- Unregister events
    if S.combatTextFrame then
        S.combatTextFrame:UnregisterAllEvents()
        S.combatTextFrame:SetScript("OnEvent", nil)
        S.combatTextFrame = nil
    end

    -- We can't unhook hooksecurefunc; keep per-frame sentinel so we don't double-hook on re-enable
    S.combatTextFlag = false

    S.combatTextHooked = false
end

function SarychUI.modules.floating_text:ApplyRaidBossEmoteReposition()
    local db = FloatingTextDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.raidBossEmoteHooked then
            SarychUI.modules.floating_text:DisableRaidBossEmoteReposition()
        end
        return
    end

    if db.enableRaidBossEmoteReposition == 1 then
        -- Enable if not already enabled
        if not S.raidBossEmoteHooked then
            SarychUI.modules.floating_text:EnableRaidBossEmoteReposition()
        end
        -- Apply reposition immediately
        SarychUI.modules.floating_text:RepositionRaidBossEmoteFrame()
    else
        -- Disable if enabled
        if S.raidBossEmoteHooked then
            SarychUI.modules.floating_text:DisableRaidBossEmoteReposition()
        end
    end
end

function SarychUI.modules.floating_text:RepositionRaidBossEmoteFrame()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    if db.enableRaidBossEmoteReposition ~= 1 then
        -- If disabled, restore original position and width
        if RaidBossEmoteFrame then
            if S.raidBossRepositioned and S.originalRaidBossPosition then
                RaidBossEmoteFrame:ClearAllPoints()
                RaidBossEmoteFrame:SetPoint(unpack(S.originalRaidBossPosition))
            end
            if RaidBossEmoteFrame.slot1 and RaidBossEmoteFrame.slot2 then
                if S.originalRaidBossWidth then
                    RaidBossEmoteFrame.slot1:SetWidth(S.originalRaidBossWidth)
                    RaidBossEmoteFrame.slot2:SetWidth(S.originalRaidBossWidth)
                end
                if RaidBossEmoteFrame.slot1.SetNonSpaceWrap then
                    RaidBossEmoteFrame.slot1:SetNonSpaceWrap(false)
                    RaidBossEmoteFrame.slot2:SetNonSpaceWrap(false)
                end
            end
        end
        S.raidBossRepositioned = false
        S.originalRaidBossPosition = nil
        S.originalRaidBossWidth = nil
        S.lastAppliedOffset = nil
        return
    end

    if RaidBossEmoteFrame then
        -- Set max width and wrapping for slot1 and slot2
        local maxWidth = db.raidBossEmoteMaxWidth or 600
        if RaidBossEmoteFrame.slot1 and RaidBossEmoteFrame.slot2 then
            -- Save original width on first application
            if not S.originalRaidBossWidth then
                S.originalRaidBossWidth = RaidBossEmoteFrame.slot1:GetWidth()
            end

            RaidBossEmoteFrame.slot1:SetWidth(maxWidth)
            RaidBossEmoteFrame.slot2:SetWidth(maxWidth)
            if RaidBossEmoteFrame.slot1.SetNonSpaceWrap then
                RaidBossEmoteFrame.slot1:SetNonSpaceWrap(true)
                RaidBossEmoteFrame.slot2:SetNonSpaceWrap(true)
            end
        end

        local currentOffset = db.raidBossEmoteOffsetY or -600

        -- If frame not repositioned yet or offset changed
        if not S.raidBossRepositioned or S.lastAppliedOffset ~= currentOffset then
            -- If we have original position, use it
            if S.originalRaidBossPosition then
                RaidBossEmoteFrame:ClearAllPoints()
                RaidBossEmoteFrame:SetPoint(S.originalRaidBossPosition[1], S.originalRaidBossPosition[2], S.originalRaidBossPosition[3], S.originalRaidBossPosition[4], S.originalRaidBossPosition[5] + currentOffset)
                S.raidBossRepositioned = true
                S.lastAppliedOffset = currentOffset
            else
                -- First time - get original position
                local p, rel, rp, x, y = RaidBossEmoteFrame:GetPoint()
                if p and rel and rp and x and y then
                    S.originalRaidBossPosition = {p, rel, rp, x, y}
                    RaidBossEmoteFrame:ClearAllPoints()
                    RaidBossEmoteFrame:SetPoint(p, rel, rp, x, y + currentOffset)
                    S.raidBossRepositioned = true
                    S.lastAppliedOffset = currentOffset
                end
            end
        end
    end
end

function SarychUI.modules.floating_text:EnableRaidBossEmoteReposition()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end

    if S.raidBossEmoteHooked then return end -- Already enabled

    -- Hook ADDON_LOADED for Blizzard_RaidUI and Blizzard_CombatText
    S.raidBossEmoteFrame = CreateFrame("Frame")
    S.raidBossEmoteFrame:RegisterEvent("ADDON_LOADED")
    S.raidBossEmoteFrame:SetScript("OnEvent", function(self, event, addonName)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then return end
        if checkDb.enableRaidBossEmoteReposition ~= 1 then return end

        if addonName == "Blizzard_RaidUI" or addonName == "Blizzard_CombatText" then
            -- Small delay to ensure frame is created
            SuiTimer.After(0.1, function()
                SarychUI.modules.floating_text:RepositionRaidBossEmoteFrame()
            end)
        end
    end)

    -- Periodic check and apply repositioning (every second)
    local raidBossTimer = 0
    S.raidBossEmoteFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then return end
        if checkDb.enableRaidBossEmoteReposition ~= 1 then return end

        raidBossTimer = raidBossTimer + elapsed
        if raidBossTimer >= 1.0 then  -- Check every second
            raidBossTimer = 0
            if RaidBossEmoteFrame then
                SarychUI.modules.floating_text:RepositionRaidBossEmoteFrame()
            end
        end
    end)

    -- If addons already loaded, apply immediately
    if IsAddOnLoaded("Blizzard_RaidUI") or IsAddOnLoaded("Blizzard_CombatText") then
        SuiTimer.After(0.1, function()
            SarychUI.modules.floating_text:RepositionRaidBossEmoteFrame()
        end)
    end

    S.raidBossEmoteHooked = true
end

function SarychUI.modules.floating_text:DisableRaidBossEmoteReposition()
    if not S.raidBossEmoteHooked then return end

    -- Restore original position
    if RaidBossEmoteFrame and S.raidBossRepositioned and S.originalRaidBossPosition then
        RaidBossEmoteFrame:ClearAllPoints()
        RaidBossEmoteFrame:SetPoint(unpack(S.originalRaidBossPosition))
    end

    -- Restore original width and disable wrapping
    if RaidBossEmoteFrame and RaidBossEmoteFrame.slot1 and RaidBossEmoteFrame.slot2 then
        if S.originalRaidBossWidth then
            RaidBossEmoteFrame.slot1:SetWidth(S.originalRaidBossWidth)
            RaidBossEmoteFrame.slot2:SetWidth(S.originalRaidBossWidth)
        end
        if RaidBossEmoteFrame.slot1.SetNonSpaceWrap then
            RaidBossEmoteFrame.slot1:SetNonSpaceWrap(false)
            RaidBossEmoteFrame.slot2:SetNonSpaceWrap(false)
        end
    end

    -- Unregister events
    if S.raidBossEmoteFrame then
        S.raidBossEmoteFrame:UnregisterAllEvents()
        S.raidBossEmoteFrame:SetScript("OnEvent", nil)
        S.raidBossEmoteFrame:SetScript("OnUpdate", nil)
        S.raidBossEmoteFrame = nil
    end

    -- Reset state
    S.raidBossRepositioned = false
    S.originalRaidBossPosition = nil
    S.originalRaidBossWidth = nil
    S.lastAppliedOffset = nil

    S.raidBossEmoteHooked = false
end

local function SplitErrorPatterns(text)
    local patterns = {}
    if type(text) ~= "string" then return patterns end
    for token in gmatch(text, "[^;]+") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        if token ~= "" then tinsert(patterns, token) end
    end
    return patterns
end

local function GetDefaultErrorHidePatterns()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "ruRU" then
        return "Способность пока недоступна."
    end
    return "Ability is not ready yet."
end

local function GetDefaultErrorExceptionPatterns()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "ruRU" then
        return "Вы должны подождать;Нет места."
    end
    return "You must wait;Inventory is full."
end

local function SendToAllChatFrames(message, r, g, b)
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf then cf:AddMessage(message, r, g, b) end
    end
end

local function BuildErrorFrames()
    if S.errorFilterFrames.created then return end
    S.errorFilterFrames.created = true

    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end

    local timeVisible = db.errorTimeVisible or 1
    UIErrorsFrame:SetTimeVisible(timeVisible)
    UIErrorsFrame:SetAlpha(0)

    -- Create filtered errors frame
    local fef = CreateFrame("MessageFrame", nil, UIParent)
    fef:SetSize(UIErrorsFrame:GetWidth(), UIErrorsFrame:GetHeight())
    fef:SetInsertMode(UIErrorsFrame:GetInsertMode())
    fef:SetFontObject(UIErrorsFrame:GetFontObject())
    fef:SetTimeVisible(UIErrorsFrame:GetTimeVisible())
    fef:SetFadeDuration(UIErrorsFrame:GetFadeDuration())
    fef:SetJustifyH("CENTER")
    fef:SetFrameStrata(UIErrorsFrame:GetFrameStrata())
    fef:ClearAllPoints()
    local filteredOffsetY = db.errorFilteredOffsetY or -130
    fef:SetPoint("CENTER", UIParent, "CENTER", 0, filteredOffsetY)
    fef:SetAlpha(1)
    fef:Show()
    S.errorFilterFrames.filtered = fef

    -- Create system messages frame
    local sif = CreateFrame("MessageFrame", nil, UIParent)
    sif:SetSize(UIErrorsFrame:GetWidth(), UIErrorsFrame:GetHeight())
    sif:SetInsertMode(UIErrorsFrame:GetInsertMode())
    sif:SetFontObject(UIErrorsFrame:GetFontObject())
    sif:SetTimeVisible(UIErrorsFrame:GetTimeVisible())
    sif:SetFadeDuration(UIErrorsFrame:GetFadeDuration())
    sif:SetJustifyH("CENTER")
    sif:SetFrameStrata(UIErrorsFrame:GetFrameStrata())
    sif:ClearAllPoints()
    local sysOffsetY = db.errorSysMsgOffsetY or 0
    sif:SetPoint("BOTTOM", UIErrorsFrame, "TOP", 0, sysOffsetY)
    sif:SetAlpha(1)
    sif:Show()
    S.errorFilterFrames.sys = sif

    -- Unregister events from UIErrorsFrame and register on sys frame
    UIErrorsFrame:UnregisterEvent("SYSMSG")
    UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
    sif:RegisterEvent("SYSMSG")
    sif:RegisterEvent("UI_INFO_MESSAGE")
    sif:SetScript("OnEvent", function(self, event, ...)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then return end

        local msg = ...
        if event == "SYSMSG" or event == "UI_INFO_MESSAGE" then
            self:AddMessage(msg, 1, 1, 0, 1)
        end
    end)
end

local function UpdateErrorAltVisibility(isAltPressed)
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    if not S.errorFilterFrames.enabled then return end

    -- Hiding stays active unless the optional modifier override is held.
    UIErrorsFrame:SetAlpha(S.errorFilterFrames.altOnly and isAltPressed and 1 or 0)
end

local function InstallErrorHandler()
    if S.errorFilterFrames.origHandler then return end

    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end

    S.errorFilterFrames.origHandler = UIErrorsFrame:GetScript("OnEvent")
    UIErrorsFrame:SetScript("OnEvent", function(self, event, ...)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        local checkDb = FloatingTextDB()
        if not checkDb or not checkDb.enabled then
            if S.errorFilterFrames.origHandler then
                S.errorFilterFrames.origHandler(self, event, ...)
            end
            return
        end

        local msg = ...
        local now = GetTime()

        if event == "UI_ERROR_MESSAGE" and S.errorFilterFrames.enabled then
            local throttle = checkDb.errorThrottleWindow or 0.5
            if msg == S.errorFilterFrames.lastMsg and (now - (S.errorFilterFrames.lastAt or 0)) < throttle then
                return
            end

            -- Check hide patterns
            local hidePat = SplitErrorPatterns(checkDb.errorHidePatterns or GetDefaultErrorHidePatterns())
            for _, hidden in ipairs(hidePat) do
                if hidden ~= "" and msg:find(hidden) then
                    return
                end
            end

            S.errorFilterFrames.lastMsg, S.errorFilterFrames.lastAt = msg, now

            -- Check exception patterns (only if extra frame enabled)
            if checkDb.errorExtraEnabled == 1 then
                local excPat = SplitErrorPatterns(checkDb.errorExceptionPatterns or GetDefaultErrorExceptionPatterns())
                for _, exc in ipairs(excPat) do
                    if exc ~= "" and msg:find(exc) then
                        if S.errorFilterFrames.filtered then
                            S.errorFilterFrames.filtered:AddMessage(msg, 1, 0.1, 0.1, 1)
                        end
                        if checkDb.errorPlaySound == 1 then
                            PlaySound("TellMessage")
                        end
                        if checkDb.errorEchoToChat == 1 then
                            SendToAllChatFrames(msg, 1, 0.1, 0.1)
                        end
                        return
                    end
                end
            end
        end

        -- Call original handler
        if S.errorFilterFrames.origHandler then
            S.errorFilterFrames.origHandler(self, event, ...)
        end
    end)
end

function SarychUI.modules.floating_text:ApplyErrorFilter()
    local db = FloatingTextDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.errorFilterInitialized then
            SarychUI.modules.floating_text:DisableErrorFilter()
        end
        return
    end

    if db.enableErrorFilter == 1 then
        -- Enable if not already enabled
        if not S.errorFilterInitialized then
            SarychUI.modules.floating_text:EnableErrorFilter()
        end
        -- Apply settings
        SarychUI.modules.floating_text:UpdateErrorFilterSettings()
    else
        -- Disable if enabled
        if S.errorFilterInitialized then
            SarychUI.modules.floating_text:DisableErrorFilter()
        end
    end
end

function SarychUI.modules.floating_text:UpdateErrorFilterSettings()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end
    if db.enableErrorFilter ~= 1 then return end

    S.errorFilterFrames.enabled = true
    S.errorFilterFrames.altOnly = (db.errorShowOriginalOnAlt == 1)

    BuildErrorFrames()

    local timeVisible = db.errorTimeVisible or 1
    UIErrorsFrame:SetTimeVisible(timeVisible)
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")

    if S.errorFilterFrames.filtered then
        S.errorFilterFrames.filtered:ClearAllPoints()
        local filteredOffsetY = db.errorFilteredOffsetY or -130
        S.errorFilterFrames.filtered:SetPoint("CENTER", UIParent, "CENTER", 0, filteredOffsetY)
        S.errorFilterFrames.filtered:SetTimeVisible(UIErrorsFrame:GetTimeVisible())
        local fadeDuration = db.errorFadeDuration or 1.5
        S.errorFilterFrames.filtered:SetFadeDuration(fadeDuration)
        S.errorFilterFrames.filtered:SetAlpha(1)
        S.errorFilterFrames.filtered:Show()
    end

    if S.errorFilterFrames.sys then
        S.errorFilterFrames.sys:ClearAllPoints()
        local sysOffsetY = db.errorSysMsgOffsetY or 0
        S.errorFilterFrames.sys:SetPoint("BOTTOM", UIErrorsFrame, "TOP", 0, sysOffsetY)
        S.errorFilterFrames.sys:SetTimeVisible(UIErrorsFrame:GetTimeVisible())
        local fadeDuration = db.errorFadeDuration or 1.5
        S.errorFilterFrames.sys:SetFadeDuration(fadeDuration)
        S.errorFilterFrames.sys:SetAlpha(1)
        S.errorFilterFrames.sys:Show()
    end

    local fadeDuration = db.errorFadeDuration or 1.5
    UIErrorsFrame:SetFadeDuration(fadeDuration)

    InstallErrorHandler()
    UpdateErrorAltVisibility(SarychUI.AltMode and SarychUI.AltMode:IsAltPressed() or false)
end

function SarychUI.modules.floating_text:EnableErrorFilter()
    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
    local db = FloatingTextDB()
    if not db or not db.enabled then return end

    if S.errorFilterInitialized then return end -- Already enabled

    -- Register Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:RegisterCallback("errorFilter", UpdateErrorAltVisibility)
    end

    -- Apply settings
    SarychUI.modules.floating_text:UpdateErrorFilterSettings()

    S.errorFilterInitialized = true
end

function SarychUI.modules.floating_text:DisableErrorFilter()
    if not S.errorFilterInitialized then return end

    -- Restore original handler
    if S.errorFilterFrames.origHandler then
        UIErrorsFrame:SetScript("OnEvent", S.errorFilterFrames.origHandler)
        S.errorFilterFrames.origHandler = nil
    end

    -- Restore original events
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    UIErrorsFrame:RegisterEvent("SYSMSG")
    UIErrorsFrame:RegisterEvent("UI_INFO_MESSAGE")
    UIErrorsFrame:SetAlpha(1)
    UIErrorsFrame:Show()

    -- Hide and destroy custom frames
    if S.errorFilterFrames.filtered then
        S.errorFilterFrames.filtered:Hide()
        S.errorFilterFrames.filtered:UnregisterAllEvents()
        S.errorFilterFrames.filtered:SetScript("OnEvent", nil)
        S.errorFilterFrames.filtered = nil
    end

    if S.errorFilterFrames.sys then
        S.errorFilterFrames.sys:Hide()
        S.errorFilterFrames.sys:UnregisterAllEvents()
        S.errorFilterFrames.sys:SetScript("OnEvent", nil)
        S.errorFilterFrames.sys = nil
    end

    -- Restore system events to UIErrorsFrame
    if UIErrorsFrame then
        UIErrorsFrame:RegisterEvent("SYSMSG")
        UIErrorsFrame:RegisterEvent("UI_INFO_MESSAGE")
    end

    -- Unregister Alt mode callback
    if SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback("errorFilter")
    end

    -- Reset state
    S.errorFilterFrames.created = false
    S.errorFilterFrames.enabled = false
    S.errorFilterFrames.altOnly = false
    S.errorFilterFrames.lastMsg = nil
    S.errorFilterFrames.lastAt = 0

    S.errorFilterInitialized = false
end

function SarychUI.modules.floating_text:RegisterCombatTextDragFrames()
    local db = FloatingTextDB(); if not db then return end
    if not SarychUI or not SarychUI.DragMode then return end
    if not S.combatTextPlusAnchor then
        S.combatTextPlusAnchor = CreateFrame("Frame", "SarychUI_CombatTextPlusAnchor", UIParent)
        S.combatTextPlusAnchor:SetSize(220, 120)
    end
    if not S.combatTextMinusAnchor then
        S.combatTextMinusAnchor = CreateFrame("Frame", "SarychUI_CombatTextMinusAnchor", UIParent)
        S.combatTextMinusAnchor:SetSize(220, 120)
    end
    if not S.combatTextLessAnchor then
        S.combatTextLessAnchor = CreateFrame("Frame", "SarychUI_CombatTextLessDragAnchor", UIParent)
        S.combatTextLessAnchor:SetSize(220, 120)
    end
    local function CombatTextOnPositionChanged(frameId, xKey, yKey, xOfs, yOfs)
        local panel = SarychUI and SarychUI.CombatTextDragPanel
        if panel and panel.IsOpen and panel:IsOpen() and panel.OnDragPosition then
            if panel:OnDragPosition(frameId, xOfs, yOfs) then
                return
            end
        end
        -- Fallback when panel is not open: write immediately (legacy).
        local save = FloatingTextDB(); if not save then return end
        save[xKey] = xOfs
        save[yKey] = yOfs
        if module and SarychUI.modules.floating_text.ApplyCombatTextAdjust then SarychUI.modules.floating_text:ApplyCombatTextAdjust() end
    end

    SarychUI.DragMode:RegisterFrame("combatTextPlus", S.combatTextPlusAnchor, {
        dragText = "+ Текст боя",
        getPoint = function()
            local panel = SarychUI and SarychUI.CombatTextDragPanel
            if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "combatTextPlus" then
                local dx, dy = panel:GetDraft()
                if dx ~= nil then return {"CENTER", UIParent, "CENTER", dx, dy} end
            end
            local x = db and db.healPlusX or -467
            local y = db and db.healPlusY or -45
            return {"CENTER", UIParent, "CENTER", x, y}
        end,
        getScale = function() return 1.0 end,
        onPositionChanged = function(point, relativePoint, xOfs, yOfs)
            CombatTextOnPositionChanged("combatTextPlus", "healPlusX", "healPlusY", xOfs, yOfs)
        end,
    })
    SarychUI.DragMode:RegisterFrame("combatTextMinus", S.combatTextMinusAnchor, {
        dragText = "- Текст боя",
        getPoint = function()
            local panel = SarychUI and SarychUI.CombatTextDragPanel
            if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "combatTextMinus" then
                local dx, dy = panel:GetDraft()
                if dx ~= nil then return {"CENTER", UIParent, "CENTER", dx, dy} end
            end
            local x = db and db.healMinusX or 0
            local y = db and db.healMinusY
            if y == nil then y = -50 end
            return {"CENTER", UIParent, "CENTER", x, y}
        end,
        getScale = function() return 1.0 end,
        onPositionChanged = function(point, relativePoint, xOfs, yOfs)
            CombatTextOnPositionChanged("combatTextMinus", "healMinusX", "healMinusY", xOfs, yOfs)
        end,
    })
    SarychUI.DragMode:RegisterFrame("combatTextLess", S.combatTextLessAnchor, {
        dragText = "< Текст боя",
        getPoint = function()
            local panel = SarychUI and SarychUI.CombatTextDragPanel
            if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "combatTextLess" then
                local dx, dy = panel:GetDraft()
                if dx ~= nil then return {"CENTER", UIParent, "CENTER", dx, dy} end
            end
            local x = db and db.healLessX or -250
            local y = db and db.healLessY or -30
            return {"CENTER", UIParent, "CENTER", x, y}
        end,
        getScale = function() return 1.0 end,
        onPositionChanged = function(point, relativePoint, xOfs, yOfs)
            CombatTextOnPositionChanged("combatTextLess", "healLessX", "healLessY", xOfs, yOfs)
        end,
    })

    -- Убедимся, что начальная позиция применена для всех якорей
    do
        local x = db and db.healPlusX or -467
        local y = db and db.healPlusY or -45
        SarychUI.DragMode:SetFramePosition("combatTextPlus", "CENTER", "CENTER", x, y)
    end
    do
        local x = db and db.healMinusX or 0
        local y = db and db.healMinusY
        if y == nil then y = -50 end
        SarychUI.DragMode:SetFramePosition("combatTextMinus", "CENTER", "CENTER", x, y)
    end
    do
        local x = db and db.healLessX or -250
        local y = db and db.healLessY or -30
        SarychUI.DragMode:SetFramePosition("combatTextLess", "CENTER", "CENTER", x, y)
    end
end

function SarychUI.modules.floating_text:ToggleCombatTextDrag(frameId, enabled)
    if not SarychUI or not SarychUI.DragMode then return end
    -- Ensure frames are registered before toggling
    if frameId == "combatTextPlus" or frameId == "combatTextMinus" or frameId == "combatTextLess" then
        if not (SarychUI.DragMode:GetFrameData(frameId)) then
            SarychUI.modules.floating_text:RegisterCombatTextDragFrames()
        end
    end

    local panel = SarychUI.CombatTextDragPanel

    if enabled then
        -- Cancel other open combat-text panel session if switching type.
        if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() ~= frameId then
            panel:Close(false)
        end

        local db = FloatingTextDB() or {}
        if frameId == "combatTextPlus" then
            local x = db.healPlusX or -467
            local y = db.healPlusY or -45
            SarychUI.DragMode:SetFramePosition("combatTextPlus", "CENTER", "CENTER", x, y)
        elseif frameId == "combatTextMinus" then
            local x = db.healMinusX or 0
            local y = db.healMinusY
            if y == nil then y = -50 end
            SarychUI.DragMode:SetFramePosition("combatTextMinus", "CENTER", "CENTER", x, y)
        elseif frameId == "combatTextLess" then
            local x = db.healLessX or -250
            local y = db.healLessY or -30
            SarychUI.DragMode:SetFramePosition("combatTextLess", "CENTER", "CENTER", x, y)
        end

        -- Open panel first so it can snapshot grid state before we force it on.
        if panel and panel.Open then
            panel:Open(frameId)
        else
            SarychUI.DragMode:ShowGrid(true)
        end
        SarychUI.DragMode:EnableEditMode(frameId, true, true, true)
    else
        -- Disable without Apply: cancel draft via panel if this session is open.
        if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == frameId then
            panel:Close(false)
            return
        end
        SarychUI.DragMode:EnableEditMode(frameId, false, false, false)
        local data = SarychUI.DragMode:GetFrameData(frameId)
        if data and data.dragFrame then data.dragFrame:Hide() end
    end
end
