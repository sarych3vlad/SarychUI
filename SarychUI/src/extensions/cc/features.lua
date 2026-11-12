local module = SarychUI.modules.cc
-- Runtime owned by cc; legacy tools profile keys are preserved.
local S = {}
local floor, max, min = math.floor, math.max, math.min

local format = string.format

local gsub, find, gmatch = string.gsub, string.find, string.gmatch

local GetTime = GetTime

local TIMERS_MODULE = "cc"

local function TimersDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[TIMERS_MODULE]
end


S.inviteCountdownFrame, S.inviteCountdownEventFrame, S.inviteCountdownPopupTimerFrame = nil, nil, nil

S.inviteCountdownInitialized, S.inviteTrackers, S.pvpFirstTrigger, S.popupTimer = false, nil, 0, nil

S.startInviteTracker, S.stopInviteTracker, S.startInvitePopupTimer, S.stopInvitePopupTimer = nil, nil, nil, nil

S.updateInvitePopupTimer, S.anchorInviteUnder, S.setInviteSmartText, S.hookInvitePopupButtons = nil, nil, nil, nil

S.arenaCountdownFrame, S.arenaCountdownEventFrame, S.arenaCountdownInitialized, S.arenaTracker = nil, nil, false, nil

S.startArenaCountdownFunc, S.stopArenaCountdownFunc, S.setArenaSmartTextFunc = nil, nil, nil

S.INVITE_TICK, S.INVITE_FONT_SIZE = 0.02, 14

S.ARENA_DOOR_OFFSET = 0.8

S.INVITE_DEFAULTS = {
    PVP   = 59.5,   -- БГ/Арена
    LFG   = 46.2,   -- ПП
    PARTY = 60.5,   -- Пати-инвайт
}

local function GetInviteFontSize(fs, size)
    local BASE_FONT, BASE_FLAGS = GameFontNormal:GetFont()
    fs:SetFont(BASE_FONT, size, BASE_FLAGS)
end

local function IsInviteCountdownEnabled()
    local db = TimersDB()
    if not db or not db.enabled then return false end
    return db.enableInviteCountdown == 1
end

local function GetInviteDuration(kind)
    return S.INVITE_DEFAULTS[kind] or 30
end

local function GetInvitePopupButtons(frame)
    if not frame then return nil, nil end
    local b1 = frame.button1 or frame.Button1 or frame.AcceptButton
    local b2 = frame.button2 or frame.Button2 or frame.CancelButton
    b1 = b1 or frame.enterButton or frame.EnterDungeonButton
    b2 = b2 or frame.leaveButton or frame.LeaveQueueButton
    local fname = frame.GetName and frame:GetName()
    if not b1 and fname then
        b1 = _G[fname.."EnterDungeonButton"] or _G[fname.."EnterButton"] or _G[fname.."AcceptButton"]
    end
    if not b2 and fname then
        b2 = _G[fname.."LeaveQueueButton"] or _G[fname.."LeaveButton"] or _G[fname.."CancelButton"]
    end
    b1 = b1 or _G["LFDDungeonReadyDialogEnterDungeonButton"]
    b2 = b2 or _G["LFDDungeonReadyDialogLeaveQueueButton"] or _G["LFDDungeonReadyDialogCancelButton"]
    return b1, b2
end

local function InviteLFGDialog()
    return _G["LFGDungeonReadyDialog"] or _G["LFDDungeonReadyDialog"] or _G["LFDDungeonReadyPopup"]
end

local function InvitePartyPopupShown()
    for i=1,4 do
        local p = _G["StaticPopup"..i]
        if p and p:IsShown() and p.which == "PARTY_INVITE" then return p end
    end
end

local function InvitePVPConfirmPopupShown()
    for i=1,4 do
        local p = _G["StaticPopup"..i]
        if p and p:IsShown() and (p.which == "CONFIRM_BATTLEFIELD_ENTRY" or p.which == "CONFIRM_ARENA_ENTRY") then
            return p
        end
    end
end

function SarychUI.modules.cc:ApplyInviteCountdown()
    local db = TimersDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if S.inviteCountdownInitialized then
            SarychUI.modules.cc:DisableInviteCountdown()
        end
        return
    end

    if db.enableInviteCountdown == 1 then
        -- Enable if not already enabled
        if not S.inviteCountdownInitialized then
            SarychUI.modules.cc:EnableInviteCountdown()
        end

        -- Если сейчас уже открыт подходящий попап/диалог - запустить таймеры сразу
        if S.inviteCountdownInitialized then
            local dlg = InviteLFGDialog()
            if dlg and S.popupTimer and not S.popupTimer.active then
                S.startInvitePopupTimer(dlg, GetInviteDuration("LFG") or 30)
            end

            local pp = InvitePartyPopupShown()
            if pp and S.inviteTrackers and S.inviteTrackers.PARTY and not S.inviteTrackers.PARTY.active then
                S.startInviteTracker(S.inviteTrackers.PARTY, pp)
            end

            local pvp = InvitePVPConfirmPopupShown()
            if pvp and S.popupTimer and not S.popupTimer.active then
                S.startInvitePopupTimer(pvp, 59.5)
            end
        end
    else
        -- Disable if enabled
        if S.inviteCountdownInitialized then
            SarychUI.modules.cc:DisableInviteCountdown()
        end
    end
end

function SarychUI.modules.cc:EnableInviteCountdown()
    local db = TimersDB()
    if not db or not db.enabled then return end

    if S.inviteCountdownInitialized then return end -- Already enabled

    -- Create main countdown frame
    S.inviteCountdownFrame = CreateFrame("Frame", nil, UIParent)
    S.inviteCountdownFrame:SetSize(110, 24)
    S.inviteCountdownFrame:SetFrameStrata("DIALOG")
    S.inviteCountdownFrame:SetFrameLevel(1000)
    S.inviteCountdownFrame.text = S.inviteCountdownFrame:CreateFontString(nil, "OVERLAY")
    GetInviteFontSize(S.inviteCountdownFrame.text, S.INVITE_FONT_SIZE)
    S.inviteCountdownFrame.text:SetAllPoints()
    S.inviteCountdownFrame.text:SetShadowColor(0, 0, 0, 1)
    S.inviteCountdownFrame.text:SetShadowOffset(1, -1)
    S.inviteCountdownFrame:Hide()

    -- Trackers for different invite types
    S.inviteTrackers = {}
    local function NewTracker(kind)
        return {
            kind = kind,
            active = false,
            showAt = 0,
            deadline = 0,
            anchor = nil,
            userClicked = false,
        }
    end
    S.inviteTrackers.PVP = NewTracker("PVP")
    S.inviteTrackers.LFG = NewTracker("LFG")
    S.inviteTrackers.PARTY = NewTracker("PARTY")

    S.pvpFirstTrigger = 0

    -- Popup timer
    S.popupTimer = {
        active = false,
        popup = nil,
        deadline = 0,
        originalText1 = "",
        originalText2 = ""
    }

    -- Anchor function
    S.anchorInviteUnder = function(frame)
        local a = frame or UIParent
        S.inviteCountdownFrame:ClearAllPoints()
        S.inviteCountdownFrame:SetPoint("TOP", a, "BOTTOM", 0, -6)
    end

    -- Set text function
    S.setInviteSmartText = function(sec)
        GetInviteFontSize(S.inviteCountdownFrame.text, S.INVITE_FONT_SIZE)
        if sec < 1 then
            S.inviteCountdownFrame:Hide()
            return
        end
        S.inviteCountdownFrame.text:SetTextColor(1, 1, 1)
        S.inviteCountdownFrame.text:SetText(format(" %d ", floor(sec + 0.5)))
    end

    -- Start tracker
    S.startInviteTracker = function(tr, anchorFrame)
        if not IsInviteCountdownEnabled() then return end
        tr.active = true
        tr.userClicked = false
        tr.showAt = GetTime()
        tr.deadline = tr.showAt + (GetInviteDuration(tr.kind) or 30)
        tr.anchor = anchorFrame
        S.anchorInviteUnder(tr.anchor)
        S.inviteCountdownFrame:Show()
    end

    -- Stop tracker
    S.stopInviteTracker = function(tr)
        tr.active = false
        tr.showAt, tr.deadline, tr.anchor = 0, 0, nil
        if not (S.inviteTrackers.PVP.active or S.inviteTrackers.LFG.active or S.inviteTrackers.PARTY.active) then
            S.inviteCountdownFrame:Hide()
        end
    end

    -- Start popup timer
    S.startInvitePopupTimer = function(popup, duration)
        if not IsInviteCountdownEnabled() then return end
        if not popup then return end

        -- Если таймер уже активен для этого попапа, сначала останавливаем его
        if S.popupTimer.active and S.popupTimer.popup == popup then
            S.stopInvitePopupTimer()
        end

        local button1, button2 = GetInvitePopupButtons(popup)
        if button1 then
            -- Получаем текущий текст кнопки
            local currentText = button1:GetText() or ""

            -- Очищаем текст от предыдущего таймера (формат: "текст (число)")
            -- Удаляем паттерн " (число)" в конце строки
            local cleanText = currentText:gsub("%s*%(%d+%)%s*$", "")

            -- Сохраняем очищенный оригинальный текст
            S.popupTimer.active = true
            S.popupTimer.popup = popup
            S.popupTimer.deadline = GetTime() + duration
            S.popupTimer.originalText1 = cleanText
            S.popupTimer.originalText2 = button2 and (button2:GetText() or ""):gsub("%s*%(%d+%)%s*$", "") or ""

            -- Восстанавливаем очищенный текст на кнопке
            button1:SetText(cleanText)

            if S.inviteCountdownPopupTimerFrame then
                S.inviteCountdownPopupTimerFrame:Show()
            end
        end
    end

    -- Stop popup timer
    S.stopInvitePopupTimer = function()
        if S.popupTimer.active and S.popupTimer.popup then
            local button1 = GetInvitePopupButtons(S.popupTimer.popup)
            if button1 and S.popupTimer.originalText1 then
                button1:SetText(S.popupTimer.originalText1)
            end
        end
        S.popupTimer.active = false
        S.popupTimer.popup = nil
        S.popupTimer.deadline = 0
        S.popupTimer.originalText1 = ""
        S.popupTimer.originalText2 = ""
        if S.inviteCountdownPopupTimerFrame then
            S.inviteCountdownPopupTimerFrame:Hide()
        end
    end

    -- Update popup timer
    S.updateInvitePopupTimer = function()
        if not S.popupTimer.active or not S.popupTimer.popup then return end
        local left = S.popupTimer.deadline - GetTime()
        if left <= 0 then
            S.stopInvitePopupTimer()
            return
        end
        local seconds = floor(left + 0.5)
        local button1 = GetInvitePopupButtons(S.popupTimer.popup)
        if button1 and S.popupTimer.originalText1 then
            button1:SetText(S.popupTimer.originalText1 .. " (" .. seconds .. ")")
        end
    end

    -- Create popup timer frame
    S.inviteCountdownPopupTimerFrame = CreateFrame("Frame")
    S.inviteCountdownPopupTimerFrame:Hide()
    local pfAcc = 0
    S.inviteCountdownPopupTimerFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsInviteCountdownEnabled() then return end

        pfAcc = pfAcc + elapsed
        if pfAcc < S.INVITE_TICK then return end
        pfAcc = 0
        S.updateInvitePopupTimer()
    end)

    -- Hook popup buttons
    S.hookInvitePopupButtons = function(popup, tr)
        for i=1,3 do
            local btn = popup["button"..i]
            if btn and btn.HookScript and not btn.__ic_hooked then
                btn.__ic_hooked = true
                btn:HookScript("OnClick", function() tr.userClicked = true end)
            end
        end
    end

    -- Main OnUpdate
    local acc = 0
    S.inviteCountdownFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsInviteCountdownEnabled() then return end

        acc = acc + elapsed
        if acc < S.INVITE_TICK then return end
        acc = 0

        S.updateInvitePopupTimer()

        local order = {"LFG", "PVP", "PARTY"}
        local drawn = false

        for _,k in ipairs(order) do
            local tr = S.inviteTrackers[k]
            if tr.active then
                if tr.anchor and tr.anchor.IsShown and tr.anchor:IsShown() then
                    S.anchorInviteUnder(tr.anchor)
                end
                local left = tr.deadline - GetTime()
                if left <= 0 then
                    S.stopInviteTracker(tr)
                else
                    S.setInviteSmartText(left)
                    drawn = true
                    break
                end
            end
        end

        if not drawn and not (S.inviteTrackers.PVP.active or S.inviteTrackers.LFG.active or S.inviteTrackers.PARTY.active) then
            S.inviteCountdownFrame:Hide()
        end
    end)

    -- Hook StaticPopups function
    local function HookStaticPopups()
        for i=1,4 do
            local p = _G["StaticPopup"..i]
            if p and not p.__ic_hooked then
                p.__ic_hooked = true
                p:HookScript("OnShow", function(self)
                    -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
                    if not IsInviteCountdownEnabled() then return end

                    if self.which == "PARTY_INVITE" then
                        S.hookInvitePopupButtons(self, S.inviteTrackers.PARTY)
                        S.startInviteTracker(S.inviteTrackers.PARTY, self)
                    elseif self.which == "CONFIRM_BATTLEFIELD_ENTRY" or self.which == "CONFIRM_ARENA_ENTRY" then
                        S.hookInvitePopupButtons(self, S.inviteTrackers.PVP)
                        local currentTime = GetTime()
                        if S.pvpFirstTrigger == 0 then
                            S.pvpFirstTrigger = currentTime
                            S.startInvitePopupTimer(self, 59.5)
                        elseif currentTime - S.pvpFirstTrigger < 30 then
                            S.startInvitePopupTimer(self, 39.5)
                        else
                            S.pvpFirstTrigger = currentTime
                            S.startInvitePopupTimer(self, 59.5)
                        end
                    end
                end)
                p:HookScript("OnHide", function(self)
                    if not IsInviteCountdownEnabled() then return end

                    if self.which == "PARTY_INVITE" then
                        S.stopInviteTracker(S.inviteTrackers.PARTY)
                    elseif self.which == "CONFIRM_BATTLEFIELD_ENTRY" or self.which == "CONFIRM_ARENA_ENTRY" then
                        S.stopInviteTracker(S.inviteTrackers.PVP)
                        S.stopInvitePopupTimer()
                    end
                end)
            end
        end
    end

    -- Hook popups immediately if already logged in
    HookStaticPopups()

    -- Event frame
    S.inviteCountdownEventFrame = CreateFrame("Frame")
    S.inviteCountdownEventFrame:RegisterEvent("PLAYER_LOGIN")
    S.inviteCountdownEventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
    S.inviteCountdownEventFrame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
    S.inviteCountdownEventFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
    S.inviteCountdownEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    S.inviteCountdownEventFrame:RegisterEvent("PARTY_INVITE_REQUEST")
    S.inviteCountdownEventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

    S.inviteCountdownEventFrame:SetScript("OnEvent", function(self, event)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsInviteCountdownEnabled() then return end

        if event == "PLAYER_LOGIN" then
            -- Hook popups when player logs in
            HookStaticPopups()
        elseif event == "LFG_PROPOSAL_SHOW" then
            local dlg = InviteLFGDialog()
            if dlg then
                if S.inviteTrackers.LFG.active then S.stopInviteTracker(S.inviteTrackers.LFG) end
                S.startInvitePopupTimer(dlg, GetInviteDuration("LFG") or 30)
            end
        elseif event == "LFG_PROPOSAL_SUCCEEDED" or event == "LFG_PROPOSAL_FAILED" then
            S.stopInvitePopupTimer()
        elseif event == "PARTY_INVITE_REQUEST" or event == "GROUP_ROSTER_UPDATE" then
            local p = InvitePartyPopupShown()
            if p then
                if S.inviteTrackers.PARTY.active then S.stopInviteTracker(S.inviteTrackers.PARTY) end
                S.startInviteTracker(S.inviteTrackers.PARTY, p)
            end
        end
    end)

    S.inviteCountdownInitialized = true
end

function SarychUI.modules.cc:DisableInviteCountdown()
    if not S.inviteCountdownInitialized then return end

    -- Hide frame
    if S.inviteCountdownFrame then
        S.inviteCountdownFrame:Hide()
        S.inviteCountdownFrame:SetScript("OnUpdate", nil)
    end

    -- Stop popup timer
    if S.inviteCountdownPopupTimerFrame then
        S.inviteCountdownPopupTimerFrame:Hide()
        S.inviteCountdownPopupTimerFrame:SetScript("OnUpdate", nil)
    end

    -- Restore popup button texts
    if S.popupTimer and S.popupTimer.popup then
        local button1 = GetInvitePopupButtons(S.popupTimer.popup)
        if button1 and S.popupTimer.originalText1 then
            button1:SetText(S.popupTimer.originalText1)
        end
    end

    -- Unregister events
    if S.inviteCountdownEventFrame then
        S.inviteCountdownEventFrame:UnregisterAllEvents()
        S.inviteCountdownEventFrame:SetScript("OnEvent", nil)
    end

    -- Reset trackers and functions
    S.inviteTrackers = nil
    S.pvpFirstTrigger = 0
    S.popupTimer = nil
    S.startInviteTracker = nil
    S.stopInviteTracker = nil
    S.startInvitePopupTimer = nil
    S.stopInvitePopupTimer = nil
    S.updateInvitePopupTimer = nil
    S.anchorInviteUnder = nil
    S.setInviteSmartText = nil
    S.hookInvitePopupButtons = nil

    S.inviteCountdownInitialized = false
end

local function IsArenaCountdownEnabled()
    local db = TimersDB()
    if not db or not db.enabled then return false end
    return db.enableArenaCountdown == 1
end

function SarychUI.modules.cc:ApplyArenaCountdown()
    local db = TimersDB()
    if not db or not db.enabled then
        -- Disable if module is disabled
        if arenaCountdownInitialized then
            SarychUI.modules.cc:DisableArenaCountdown()
        end
        return
    end

    if db.enableArenaCountdown == 1 then
        -- Enable if not already enabled
        if not arenaCountdownInitialized then
            SarychUI.modules.cc:EnableArenaCountdown()
        end
    else
        -- Disable if enabled
        if arenaCountdownInitialized then
            SarychUI.modules.cc:DisableArenaCountdown()
        end
    end
end

function SarychUI.modules.cc:EnableArenaCountdown()
    local db = TimersDB()
    if not db or not db.enabled then return end

    if arenaCountdownInitialized then return end -- Already enabled

    -- Create arena countdown frame
    S.arenaCountdownFrame = CreateFrame("Frame", nil, UIParent)
    S.arenaCountdownFrame:SetSize(110, 24)
    S.arenaCountdownFrame:SetFrameStrata("DIALOG")
    S.arenaCountdownFrame:SetFrameLevel(1000)
    S.arenaCountdownFrame:SetPoint("CENTER", 0, 240)
    S.arenaCountdownFrame.text = S.arenaCountdownFrame:CreateFontString(nil, "OVERLAY")
    GetInviteFontSize(S.arenaCountdownFrame.text, 18)
    S.arenaCountdownFrame.text:SetAllPoints()
    S.arenaCountdownFrame.text:SetShadowColor(0, 0, 0, 1)
    S.arenaCountdownFrame.text:SetShadowOffset(1, -1)
    S.arenaCountdownFrame:Hide()

    -- Arena tracker
    S.arenaTracker = {
        active = false,
        deadline = 0,
    }

    -- Set text function
    S.setArenaSmartTextFunc = function(sec)
        GetInviteFontSize(S.arenaCountdownFrame.text, 18)
        if sec <= 0 then
            S.arenaCountdownFrame:Hide()
            return
        end
        S.arenaCountdownFrame.text:SetTextColor(1, 1, 1)
        -- Spaces around the value keep the outline from jittering as digits change.
        if sec < 1 then
            S.arenaCountdownFrame.text:SetText(format(" %.1f ", floor(sec * 10) / 10))
        else
            S.arenaCountdownFrame.text:SetText(format(" %d ", floor(sec + 0.5)))
        end
    end

    -- Stop arena countdown
    S.stopArenaCountdownFunc = function()
        S.arenaTracker.active = false
        S.arenaTracker.deadline = 0
        S.arenaCountdownFrame:Hide()
    end

    -- Start arena countdown
    S.startArenaCountdownFunc = function(duration)
        if not IsArenaCountdownEnabled() then return end
        if S.arenaTracker.active then S.stopArenaCountdownFunc() end
        S.arenaTracker.active = true
        -- Default: 15s arena warning minus door-open lead.
        duration = duration or (15 - S.ARENA_DOOR_OFFSET)
        S.arenaTracker.deadline = GetTime() + duration
        S.arenaCountdownFrame:Show()
    end

    -- OnUpdate for arena
    local arenaAcc = 0
    S.arenaCountdownFrame:SetScript("OnUpdate", function(self, elapsed)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsArenaCountdownEnabled() then return end
        if not S.arenaTracker.active then return end

        arenaAcc = arenaAcc + elapsed
        if arenaAcc < S.INVITE_TICK then return end
        arenaAcc = 0

        local left = S.arenaTracker.deadline - GetTime()
        if left <= 0 then
            S.stopArenaCountdownFunc()
        else
            S.setArenaSmartTextFunc(left)
        end
    end)

    -- Event frame for arena / BG countdown (locale-aware message matching)
    local countdownPatternsByLocale = {
        enUS = {
            arena15 = "Fifteen seconds until the Arena battle begins!",
            battlePrefix = "The battle begins",
            minutes = "in (%d+) minute",
            seconds = "in (%d+) second",
            oneMinute = "in 1 minute",
            begun = {
                "The battle has begun",
                "The Arena battle has begun",
            },
        },
        ruRU = {
            arena15 = "Пятнадцать секунд до начала боя на арене!",
            battlePrefix = "Битва начнется",
            minutes = "через (%d+) минут",
            seconds = "через (%d+) секунд",
            oneMinute = "через минуту",
            begun = {
                "Битва началась!",
                "Битва началась",
            },
        },
    }
    local function GetCountdownPatterns()
        local locale = GetLocale and GetLocale() or "enUS"
        return countdownPatternsByLocale[locale] or countdownPatternsByLocale.enUS
    end

    S.arenaCountdownEventFrame = CreateFrame("Frame")
    S.arenaCountdownEventFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    S.arenaCountdownEventFrame:SetScript("OnEvent", function(self, event, message)
        -- ПРОВЕРЯЕМ, ВКЛЮЧЕН ЛИ МОДУЛЬ
        if not IsArenaCountdownEnabled() then return end
        if event ~= "CHAT_MSG_BG_SYSTEM_NEUTRAL" or type(message) ~= "string" then return end

        local p = GetCountdownPatterns()

        local doorLead = S.ARENA_DOOR_OFFSET or 0.8

        if message:find(p.arena15, 1, true) then
            S.startArenaCountdownFunc(15 - doorLead)
            return
        end

        if message:find(p.battlePrefix, 1, true) then
            local minutes = message:match(p.minutes)
            local seconds = message:match(p.seconds)
            if minutes then
                local min = tonumber(minutes) or 1
                S.startArenaCountdownFunc(min * 60 - doorLead)
            elseif seconds then
                local sec = tonumber(seconds) or 30
                S.startArenaCountdownFunc(sec - doorLead)
            elseif message:find(p.oneMinute, 1, true) then
                S.startArenaCountdownFunc(60 - doorLead)
            end
            return
        end

        for _, begunPat in ipairs(p.begun) do
            if message:find(begunPat, 1, true) then
                S.stopArenaCountdownFunc()
                return
            end
        end
    end)

    arenaCountdownInitialized = true
end

function SarychUI.modules.cc:DisableArenaCountdown()
    if not arenaCountdownInitialized then return end

    -- Hide frame
    if S.arenaCountdownFrame then
        S.arenaCountdownFrame:Hide()
        S.arenaCountdownFrame:SetScript("OnUpdate", nil)
    end

    -- Unregister events
    if S.arenaCountdownEventFrame then
        S.arenaCountdownEventFrame:UnregisterAllEvents()
        S.arenaCountdownEventFrame:SetScript("OnEvent", nil)
    end

    -- Reset tracker and functions
    S.arenaTracker = nil
    S.startArenaCountdownFunc = nil
    S.stopArenaCountdownFunc = nil
    S.setArenaSmartTextFunc = nil

    arenaCountdownInitialized = false
end
