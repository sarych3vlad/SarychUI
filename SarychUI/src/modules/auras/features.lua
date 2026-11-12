local module = SarychUI.modules.auras
-- Runtime owned by auras; legacy tools profile keys are preserved.
local S = {}
local SuiTimer = select(2, ...).Compat.Timer

local pairs, select, pcall = pairs, select, pcall

local AURAS_MODULE = "auras"

local function AurasDB()
	local modules = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return modules and modules[AURAS_MODULE]
end

local AceTimer = LibStub("AceTimer-3.0", true)

S.updateTimers = {}

S.dispelEventFrame, S.dispelUpdateFrame = nil, nil

local DISPEL_TICK = 0.1

local _, playerClass = UnitClass("player")

local function CanRemoveEnemyBuff(dtype, isStealable)
    if dtype == "Magic" then
        if playerClass == "MAGE" then
            return isStealable and true or false
        elseif playerClass == "PRIEST" then
            return IsSpellKnown and IsSpellKnown(527) or false
        elseif playerClass == "SHAMAN" then
            return IsSpellKnown and IsSpellKnown(370) or false
        elseif playerClass == "HUNTER" then
            return IsSpellKnown and IsSpellKnown(19801) or false
        elseif playerClass == "WARRIOR" then
            return IsSpellKnown and IsSpellKnown(23922) or false
        elseif playerClass == "WARLOCK" then
            return IsSpellKnown and IsSpellKnown(19505, true) or false
        end
    elseif dtype == "Enrage" then
        if playerClass == "HUNTER" then
            return IsSpellKnown and IsSpellKnown(19801) or false
        elseif playerClass == "DRUID" then
            return IsSpellKnown and IsSpellKnown(2908) or false
        end
        return playerClass == "ROGUE"
    end
    return false
end

local MarkDispellablesOnFrame

local function ScheduleDispelMark(frame, unit)
    if not frame or not unit then
        return
    end

    local function runMark()
        if not UnitExists(unit) then
            return
        end
        MarkDispellablesOnFrame(frame, unit)
    end

    if SuiTimer and SuiTimer.After then
        SuiTimer.After(0, runMark)
    elseif AceTimer then
        AceTimer:ScheduleTimer(runMark, 0)
    else
        runMark()
    end
end

local function IsDispelHighlightEnabled()
    local db = AurasDB()
    if not db or not db.enabled then return false end
    return db.enableDispelHighlight == 1
end

function MarkDispellablesOnFrame(frame, unit)
    if not IsDispelHighlightEnabled() then return end
    if not unit then return end
    if not frame then return end

    local buffFrames = frame.buffFrames
    local frameName = (not buffFrames) and frame.GetName and frame:GetName() or nil
    local hostile = UnitCanAttack("player", unit)

    for idx = 1, 32 do
        local name, _, _, _, dtype, _, _, _, isStealable = UnitBuff(unit, idx)
        local button = buffFrames and buffFrames[idx] or (frameName and _G[frameName .. "Buff" .. idx])
        if not name or not button then break end

        local border = button.__sarStealable
        if border == nil then
            border = _G[button:GetName() .. "Stealable"] or button.Stealable or false
            button.__sarStealable = border
        end

        if border then
            local show = hostile and CanRemoveEnemyBuff(dtype, isStealable)
            if show then
                if not border:IsShown() then border:Show() end
            elseif border:IsShown() then
                border:Hide()
            end
        end
    end
end

local function ClearDispellableMarks(frame)
    if not frame then return end
    for idx = 1, 32 do
        local button = frame and frame.buffFrames and frame.buffFrames[idx]
                    or (frame and frame.GetName and _G[frame:GetName().."Buff"..idx])
        if not button then break end
        local border = _G[button:GetName().."Stealable"] or button.Stealable
        if border then border:Hide() end
    end
end

function SarychUI.modules.auras:ApplyDispelHighlight()
    local db = AurasDB()
    if not db or not db.enabled then
        ClearDispellableMarks(TargetFrame)
        ClearDispellableMarks(FocusFrame)
        if S.dispelEventFrame or S.dispelUpdateFrame then
            SarychUI.modules.auras:DisableDispelHighlight()
        end
        return
    end

    if not IsDispelHighlightEnabled() then
        ClearDispellableMarks(TargetFrame)
        ClearDispellableMarks(FocusFrame)
        if S.dispelEventFrame or S.dispelUpdateFrame then
            SarychUI.modules.auras:DisableDispelHighlight()
        end
    else
        if not S.dispelEventFrame and not S.dispelUpdateFrame then
            SarychUI.modules.auras:EnableDispelHighlight()
        else
            ScheduleDispelMark(TargetFrame, "target")
            ScheduleDispelMark(FocusFrame, "focus")
        end
    end
end

function SarychUI.modules.auras:EnableDispelHighlight()
    local db = AurasDB()
    if not db or not db.enabled then return end

    if S.dispelEventFrame then return end -- Already enabled

    -- Create event frame
    S.dispelEventFrame = CreateFrame("Frame")
    S.dispelEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    S.dispelEventFrame:RegisterEvent("UNIT_AURA")
    S.dispelEventFrame:RegisterEvent("UNIT_FACTION")
    S.dispelEventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    S.dispelEventFrame:RegisterEvent("PET_BAR_UPDATE")
    S.dispelEventFrame:SetScript("OnEvent", function(self, event, unit)
        if not IsDispelHighlightEnabled() then return end
        if (event == "UNIT_AURA" or event == "UNIT_FACTION") and unit ~= "target" and unit ~= "focus" then return end

        ScheduleDispelMark(TargetFrame, "target")
        ScheduleDispelMark(FocusFrame, "focus")
    end)

    -- Используем AceTimer вместо OnUpdate для снижения нагрузки (оптимизация производительности)
    if AceTimer then
        S.updateTimers.dispel = AceTimer:ScheduleRepeatingTimer(function()
            if not IsDispelHighlightEnabled() then return end
            if TargetFrame then MarkDispellablesOnFrame(TargetFrame, "target") end
            if FocusFrame then MarkDispellablesOnFrame(FocusFrame, "focus") end
        end, DISPEL_TICK)
    else
        -- Fallback на OnUpdate, если AceTimer недоступен
        S.dispelUpdateFrame = CreateFrame("Frame")
        local dispelUpdateAcc = 0
        S.dispelUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
            dispelUpdateAcc = dispelUpdateAcc + elapsed
            if dispelUpdateAcc < DISPEL_TICK then return end
            dispelUpdateAcc = 0

            if not IsDispelHighlightEnabled() then return end
            if TargetFrame then MarkDispellablesOnFrame(TargetFrame, "target") end
            if FocusFrame then MarkDispellablesOnFrame(FocusFrame, "focus") end
        end)
    end

    -- Update marks on the next frame (avoid re-entering TargetFrame_Update during target clicks)
    ScheduleDispelMark(TargetFrame, "target")
    ScheduleDispelMark(FocusFrame, "focus")
end

function SarychUI.modules.auras:DisableDispelHighlight()
    -- Clear marks
    ClearDispellableMarks(TargetFrame)
    ClearDispellableMarks(FocusFrame)

    -- Unregister events and clear scripts
    if S.dispelEventFrame then
        S.dispelEventFrame:UnregisterAllEvents()
        S.dispelEventFrame:SetScript("OnEvent", nil)
        S.dispelEventFrame = nil
    end

    -- Отменяем таймер, если он активен (оптимизация производительности)
    if S.updateTimers.dispel and AceTimer then
        AceTimer:CancelTimer(S.updateTimers.dispel)
        S.updateTimers.dispel = nil
    end
    if S.dispelUpdateFrame then
        S.dispelUpdateFrame:SetScript("OnUpdate", nil)
        S.dispelUpdateFrame = nil
    end
end
