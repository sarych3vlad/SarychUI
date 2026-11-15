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
    return db and db.enabled and (db.enableArenaCountdown == 1 or db.enableArenaCountdown == true)
end

local function ArenaCountdownOffset()
    local db = TimersDB()
    local offset = tonumber(db and db.arenaCountdownOffset) or 0
    if offset ~= offset then return 0 end
    return max(-5, min(5, offset))
end

-- DBM-Warmane DBM-PvP: arena and battleground preparation announcements,
-- including Strand of the Ancients round 2. Match both languages regardless
-- of GetLocale(), since private servers can send English to a Russian client.
local doorWarnings = {
    -- en
    ["The battle begins in 2 minutes"] = 120,
    ["The Battle for Alterac Valley begins in 2 minutes"] = 120,
    ["The battle for Arathi Basin begins in 2 minutes"] = 120,
    ["The battle for Eye of the Storm begins in 2 minutes"] = 120,
    ["The battle will begin in two minutes"] = 120,
    ["The battle for Strand of the Ancients begins in 2 minutes"] = 120,
    ["The battle for Warsong Gulch begins in 2 minutes"] = 120,
    ["The battle begins in 1 minute"] = 60,
    ["The Battle for Alterac Valley begins in 1 minute"] = 60,
    ["1 minute until the battle for Alterac Valley begins"] = 60,
    ["The Battle for Arathi Basin begins in 1 minute"] = 60,
    ["The Battle for Eye of the Storm begins in 1 minute"] = 60,
    ["The battle will begin in 1 minute"] = 60,
    ["The battle for Strand of the Ancients begins in 1 minute"] = 60,
    ["Round 2 of the Battle for the Strand of the Ancients begins in 1 minute"] = 60,
    ["The battle for Warsong Gulch begins in 1 minute"] = 60,
    ["The battle begins in 30 seconds"] = 30,
    ["The Battle for Alterac Valley begins in 30 seconds. Prepare yourselves"] = 30,
    ["30 seconds until the battle for Alterac Valley begins"] = 30,
    ["The Battle for Arathi Basin begins in 30 seconds. Prepare yourselves"] = 30,
    ["The Battle for Eye of the Storm begins in 30 seconds"] = 30,
    ["The battle will begin in 30 seconds"] = 30,
    ["The battle for Strand of the Ancients begins in 30 seconds. Prepare yourselves"] = 30,
    ["Round 2 begins in 30 seconds. Prepare yourselves"] = 30,
    ["The battle for Warsong Gulch begins in 30 seconds. Prepare yourselves"] = 30,
    ["One minute until the Arena battle begins"] = 60,
    ["Thirty seconds until the Arena battle begins"] = 30,
    ["Fifteen seconds until the Arena battle begins"] = 15,
    -- ru
    ["Битва начнется через 2 минуты"] = 120,
    ["Битва начнется через минуту"] = 60,
    ["Битва начнется через 60 секунд"] = 60,
    ["До начала сражения за Альтеракскую долину остается 1 минута"] = 60,
    ["Сражение за Берег Древних начнется через 1 минуту"] = 60,
    ["Второй раунд сражения за Берег Древних начнется через 1 минуту"] = 60,
    ["Битва за Ущелье Песни Войны начнется через 1 минуту"] = 60,
    ["Битва за Низину Арати начнется через минуту"] = 60,
    ["Битва начнется через 30 секунд"] = 30,
    ["30 секунд до начала битвы в Альтеракской долине"] = 30,
    ["Сражение за Берег Древних начнется через 30 секунд. Готовьтесь"] = 30,
    ["Второй раунд начинается через 30 секунд. Приготовьтесь"] = 30,
    ["Битва за Ущелье Песни Войны начнется через 30 секунд. Приготовиться"] = 30,
    ["Битва за Низину Арати начнется через 30 секунд"] = 30,
    ["Одна минута до начала боя на арене"] = 60,
    ["Тридцать секунд до начала боя на арене"] = 30,
    ["Пятнадцать секунд до начала боя на арене"] = 15,
}

local function ParseDoorAnnouncement(message)
    -- Some Russian cores put a space before '!'. Ignore terminal punctuation.
    message = message:gsub("%s+", " "):gsub("^%s+", ""):gsub("[%s!%.]+$", "")
    if doorWarnings[message] then return doorWarnings[message] end
    if message == "The battle has begun" or message == "The Arena battle has begun"
        or message == "Битва началась" or message == "Бой на арене начался" then
        return 0
    end
    -- Preserve the existing generic battleground countdown announcements.
    if message:find("The battle begins", 1, true) == 1 then
        local minutes = message:match("in (%d+) minute")
        local seconds = message:match("in (%d+) second")
        if minutes then return tonumber(minutes) * 60 end
        if seconds then return tonumber(seconds) end
    elseif message:find("Битва начнется", 1, true) == 1 then
        local minutes = message:match("через (%d+) минут")
        local seconds = message:match("через (%d+) секунд")
        if minutes then return tonumber(minutes) * 60 end
        if seconds then return tonumber(seconds) end
        if message:find("через минуту", 1, true) then return 60 end
    end
end

function module:ApplyArenaCountdown()
    if not IsArenaCountdownEnabled() then
        self:DisableArenaCountdown()
        return
    end
    self:EnableArenaCountdown()
    if S.arenaTracker.active then
        -- Always apply to the original announcement, never accumulate corrections.
        S.arenaTracker.deadline = S.arenaTracker.baseDeadline + ArenaCountdownOffset()
        local left = S.arenaTracker.deadline - GetTime()
        if left <= 0 then S.stopArenaCountdownFunc()
        else S.setArenaSmartTextFunc(left) end
    end
end

function module:EnableArenaCountdown()
    if not IsArenaCountdownEnabled() or S.arenaCountdownInitialized then return end

    -- Reuse the frames when toggling the feature or switching profiles.
    if not S.arenaCountdownFrame then
        S.arenaCountdownFrame = CreateFrame("Frame", nil, UIParent)
        S.arenaCountdownFrame:SetSize(110, 24)
        S.arenaCountdownFrame:SetFrameStrata("DIALOG")
        S.arenaCountdownFrame:SetFrameLevel(1000)
        S.arenaCountdownFrame:SetPoint("CENTER", 0, 240)
        S.arenaCountdownFrame.text = S.arenaCountdownFrame:CreateFontString(nil, "OVERLAY")
        S.arenaCountdownFrame.text:SetAllPoints()
        S.arenaCountdownFrame.text:SetShadowColor(0, 0, 0, 1)
        S.arenaCountdownFrame.text:SetShadowOffset(1, -1)
    end
    GetInviteFontSize(S.arenaCountdownFrame.text, 18)
    S.arenaCountdownFrame:Hide()
    S.arenaTracker = { active = false, baseDeadline = 0, deadline = 0 }
    local arenaAcc = 0

    S.setArenaSmartTextFunc = function(sec)
        S.arenaCountdownFrame.text:SetTextColor(1, 1, 1)
        -- Spaces around the value keep the outline from jittering as digits change.
        if sec < 1 then
            S.arenaCountdownFrame.text:SetText(format(" %.1f ", floor(sec * 10) / 10))
        else
            S.arenaCountdownFrame.text:SetText(format(" %d ", floor(sec + 0.5)))
        end
    end

    S.stopArenaCountdownFunc = function()
        S.arenaTracker.active = false
        S.arenaTracker.baseDeadline, S.arenaTracker.deadline = 0, 0
        S.arenaCountdownFrame:Hide()
        arenaAcc = 0
    end

    S.startArenaCountdownFunc = function(duration)
        if not IsArenaCountdownEnabled() then return end
        S.arenaTracker.baseDeadline = GetTime() + duration
        S.arenaTracker.deadline = S.arenaTracker.baseDeadline + ArenaCountdownOffset()
        local left = S.arenaTracker.deadline - GetTime()
        if left <= 0 then S.stopArenaCountdownFunc(); return end
        S.arenaTracker.active = true
        arenaAcc = 0
        S.setArenaSmartTextFunc(left)
        S.arenaCountdownFrame:Show()
    end

    S.arenaCountdownFrame:SetScript("OnUpdate", function(self, elapsed)
        if not IsArenaCountdownEnabled() then S.stopArenaCountdownFunc(); return end
        if not S.arenaTracker.active then return end
        arenaAcc = arenaAcc + elapsed
        if arenaAcc < S.INVITE_TICK then return end
        arenaAcc = 0
        local left = S.arenaTracker.deadline - GetTime()
        if left <= 0 then S.stopArenaCountdownFunc()
        else S.setArenaSmartTextFunc(left) end
    end)

    S.arenaCountdownEventFrame = S.arenaCountdownEventFrame or CreateFrame("Frame")
    S.arenaCountdownEventFrame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    S.arenaCountdownEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    S.arenaCountdownEventFrame:SetScript("OnEvent", function(self, event, message)
        if event == "PLAYER_ENTERING_WORLD" then S.stopArenaCountdownFunc(); return end
        if not IsArenaCountdownEnabled() or type(message) ~= "string" then return end
        if event ~= "CHAT_MSG_BG_SYSTEM_NEUTRAL" then return end
        local _, instanceType = IsInInstance()
        if instanceType ~= "arena" and instanceType ~= "pvp" then return end
        local duration = ParseDoorAnnouncement(message)
        if duration == 0 then S.stopArenaCountdownFunc()
        elseif duration then S.startArenaCountdownFunc(duration) end
    end)
    S.arenaCountdownInitialized = true
end

function module:DisableArenaCountdown()
    if not S.arenaCountdownInitialized then return end
    S.stopArenaCountdownFunc()
    S.arenaCountdownFrame:SetScript("OnUpdate", nil)
    S.arenaCountdownEventFrame:UnregisterAllEvents()
    S.arenaCountdownEventFrame:SetScript("OnEvent", nil)
    S.arenaTracker = nil
    S.startArenaCountdownFunc = nil
    S.stopArenaCountdownFunc = nil
    S.setArenaSmartTextFunc = nil
    S.arenaCountdownInitialized = false
end
