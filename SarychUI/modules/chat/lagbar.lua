-- SarychUI Chat LagBar
-- FPS/ms: GetFramerate() and GetNetStats(), same as MainMenuBarPerformanceBar tooltip.
-- Memory: read GetAddOnMemoryUsage after the game already scanned it on menu hover.
-- Visibility follows the selected chat tab (same idea as the LootHistory loot-tab button).
-- Anchored under the chat; shifts below the edit box when it opens (like ChatFrameMenuButton).

local floor = math.floor

local UPDATE_INTERVAL = 1
local LAYOUT_INTERVAL = 0.15
local MEMORY_INTERVAL = 15
local ACTIVE_FACTOR = 1.0
local INACTIVE_FACTOR = 0.25
local TEXT_ALPHA = 0.8

local COLOR_WHITE = { 1, 1, 1 }
local COLOR_YELLOW = { 1, 0.82, 0 }
local COLOR_RED = { 1, 0.15, 0.15 }

local lagBarFrame
local lagBarMemText
local lagBarMsText
local lagBarFpsText
local lagBarDriver
local lastSyncedAlpha
local lastHostFrame
local lastEditBoxOpen
local lastFramerate
local lastFramerateColor
local lastLatency
local lastLatencyColor
local lastMemoryValue
local lastMemoryColor
local lastLabelsEnabled
local cachedMemoryMB = 0
local statsElapsed = 0
local layoutElapsed = 0
local memoryElapsed = 0
local memoryPrimed = false
local hooksInstalled = false
local performanceHooksInstalled = false
local UpdateLagBar
local UpdateStats

local function GetChatDb()
    return SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
end

local function IsChatModuleEnabled()
    local db = GetChatDb()
    return db and db.enabled
end

local function IsLagBarEnabled()
    if not IsChatModuleEnabled() then
        return false
    end
    local db = GetChatDb()
    if db and db.lagBarEnabled ~= nil then
        return db.lagBarEnabled == 1
    end
    return false
end

local function IsLagBarLabelsEnabled()
    if not IsLagBarEnabled() then
        return false
    end
    local db = GetChatDb()
    if db and db.lagBarLabelsEnabled ~= nil then
        return db.lagBarLabelsEnabled == 1
    end
    return false
end

local function GetHostChatFrame()
    local frame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME or _G.ChatFrame1
    if frame and frame.IsShown and not frame:IsShown() then
        frame = DEFAULT_CHAT_FRAME or _G.ChatFrame1
    end
    return frame
end

local function GetChatTab(chatFrame)
    if not chatFrame or not chatFrame.GetName then
        return nil
    end
    return _G[chatFrame:GetName() .. "Tab"]
end

local function GetEditBox(chatFrame)
    if not chatFrame then
        return nil
    end
    if chatFrame.editBox then
        return chatFrame.editBox
    end
    if chatFrame.GetName then
        return _G[chatFrame:GetName() .. "EditBox"]
    end
    return nil
end

local function IsEditBoxOpen(eb)
    if not eb then
        return false
    end
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active and active == eb then
        return true
    end
    if eb.HasFocus and eb:HasFocus() then
        return true
    end
    return eb.IsShown and eb:IsShown()
end

-- Enter in 3.3.5 usually activates ChatFrame1EditBox (or last-active),
-- not the selected tab's own box. Follow the actually open line.
local function GetOpenEditBox(chatFrame)
    local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if IsEditBoxOpen(active) then
        return active
    end
    if ChatEdit_ChooseBoxForSend then
        local preferred = ChatEdit_ChooseBoxForSend(chatFrame)
        if IsEditBoxOpen(preferred) then
            return preferred
        end
    end
    local own = GetEditBox(chatFrame)
    if IsEditBoxOpen(own) then
        return own
    end
    local n = NUM_CHAT_WINDOWS or 10
    for i = 1, n do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if IsEditBoxOpen(eb) then
            return eb
        end
    end
    return nil
end

local function SetStatColor(fs, color)
    if fs then
        fs:SetTextColor(color[1], color[2], color[3], TEXT_ALPHA)
        fs:SetAlpha(TEXT_ALPHA)
    end
end

-- White by default; yellow/red only when the value is in a warning range.
-- Latency uses Blizzard performance-bar thresholds (300 / 600).
local function GetLatencyColor(ms)
    local low = PERFORMANCEBAR_LOW_LATENCY or 300
    local medium = PERFORMANCEBAR_MEDIUM_LATENCY or 600
    if ms > medium then
        return COLOR_RED
    elseif ms > low then
        return COLOR_YELLOW
    end
    return COLOR_WHITE
end

local function GetFramerateColor(fps)
    if fps < 15 then
        return COLOR_RED
    elseif fps < 30 then
        return COLOR_YELLOW
    end
    return COLOR_WHITE
end

local function GetMemoryColor(mb)
    if mb >= 201 then
        return COLOR_RED
    elseif mb >= 151 then
        return COLOR_YELLOW
    end
    return COLOR_WHITE
end

local function IsPlayerInCombat()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    return false
end

-- Same total as the Game Menu tooltip: sum of GetAddOnMemoryUsage after a scan.
local function ReadGameAddonMemoryMB()
    local total = 0
    local count = GetNumAddOns and GetNumAddOns() or 0
    for i = 1, count do
        total = total + (GetAddOnMemoryUsage(i) or 0)
    end
    return total / 1024
end

local function RefreshAddonMemory(forceScan)
    if forceScan and UpdateAddOnMemoryUsage and not IsPlayerInCombat() then
        UpdateAddOnMemoryUsage()
    end
    cachedMemoryMB = ReadGameAddonMemoryMB()
    if UpdateStats and lagBarFrame and lagBarFrame:IsShown() then
        UpdateStats()
    end
end

local function CaptureGameAddonMemory()
    -- Blizzard already called UpdateAddOnMemoryUsage in the tooltip OnEnter.
    RefreshAddonMemory(false)
end

local function HookPerformanceBarMemoryCapture()
    if performanceHooksInstalled then
        return
    end
    performanceHooksInstalled = true

    if hooksecurefunc and type(MainMenuBarPerformanceBarFrame_OnEnter) == "function" then
        hooksecurefunc("MainMenuBarPerformanceBarFrame_OnEnter", CaptureGameAddonMemory)
    end

    local function HookEnter(frame)
        if not frame or frame._sarychLagBarMemHook then
            return
        end
        frame._sarychLagBarMemHook = true
        if frame.HookScript then
            frame:HookScript("OnEnter", CaptureGameAddonMemory)
        elseif frame.GetScript and frame.SetScript then
            local original = frame:GetScript("OnEnter")
            frame:SetScript("OnEnter", function(self, ...)
                if original then
                    original(self, ...)
                end
                CaptureGameAddonMemory()
            end)
        end
    end

    HookEnter(_G.MainMenuBarPerformanceBarFrame)
    HookEnter(_G.MainMenuBarPerformanceBarFrameButton)
    HookEnter(_G.MainMenuMicroButton)
end

local function ComputeAlphaFromTab(tab)
    if not tab then
        return ACTIVE_FACTOR
    end

    local tabAlpha = tab:GetAlpha() or 1
    local mouseOver = tab.mouseOverAlpha or CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA or 1
    local noMouse = tab.noMouseAlpha or CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA or 0.4

    if mouseOver <= noMouse + 0.001 then
        if tabAlpha > noMouse + 0.08 then
            return ACTIVE_FACTOR
        end
        return INACTIVE_FACTOR
    end

    local t = (tabAlpha - noMouse) / (mouseOver - noMouse)
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end
    return INACTIVE_FACTOR + (ACTIVE_FACTOR - INACTIVE_FACTOR) * t
end

local function SyncAlphaFromTab()
    if not lagBarFrame or not lagBarFrame:IsShown() then
        return
    end

    local chatFrame = lastHostFrame or GetHostChatFrame()
    local alpha = ComputeAlphaFromTab(GetChatTab(chatFrame))
    if lastSyncedAlpha == alpha then
        return
    end
    lastSyncedAlpha = alpha
    lagBarFrame:SetAlpha(alpha)
end

function UpdateStats()
    if not (lagBarMemText and lagBarMsText and lagBarFpsText) then
        return
    end

    local framerate = floor(GetFramerate() + 0.5)
    local framerateColor = GetFramerateColor(framerate)
    local _, _, latency = GetNetStats()
    local latencyValue = floor(latency or 0)
    local latencyColor = GetLatencyColor(latencyValue)
    local memoryMB = cachedMemoryMB
    local memoryColor = GetMemoryColor(memoryMB)
    local memoryValue = floor(memoryMB * 10 + 0.5)

    local labelsEnabled = IsLagBarLabelsEnabled()

    if framerate == lastFramerate
        and framerateColor == lastFramerateColor
        and latencyValue == lastLatency
        and latencyColor == lastLatencyColor
        and memoryValue == lastMemoryValue
        and memoryColor == lastMemoryColor
        and labelsEnabled == lastLabelsEnabled then
        return
    end

    lastFramerate = framerate
    lastFramerateColor = framerateColor
    lastLatency = latencyValue
    lastLatencyColor = latencyColor
    lastMemoryValue = memoryValue
    lastMemoryColor = memoryColor
    lastLabelsEnabled = labelsEnabled

    if labelsEnabled then
        lagBarMemText:SetFormattedText("mb: %5.1f ", memoryMB)
        lagBarMsText:SetFormattedText("ms: %4d ", latencyValue)
        lagBarFpsText:SetFormattedText("fps: %3d ", framerate)
    else
        lagBarMemText:SetFormattedText(" %5.1f ", memoryMB)
        lagBarMsText:SetFormattedText(" %4d ", latencyValue)
        lagBarFpsText:SetFormattedText(" %3d ", framerate)
    end
    SetStatColor(lagBarMemText, memoryColor)
    SetStatColor(lagBarMsText, latencyColor)
    SetStatColor(lagBarFpsText, framerateColor)
end

local function AnchorLagBar(chatFrame)
    if not (lagBarFrame and chatFrame) then
        return
    end

    -- Parent stays UIParent: ChatFrame would clip a child drawn below its bounds.
    if lagBarFrame:GetParent() ~= UIParent then
        lagBarFrame:SetParent(UIParent)
    end

    lagBarFrame:SetFrameStrata(chatFrame:GetFrameStrata() or "LOW")
    lagBarFrame:SetFrameLevel((chatFrame:GetFrameLevel() or 0) + 5)

    local eb = GetOpenEditBox(chatFrame)
    local editBoxOpen = eb ~= nil

    lagBarFrame:ClearAllPoints()
    if editBoxOpen then
        lagBarFrame:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, 4)
        lagBarFrame:SetPoint("TOPRIGHT", eb, "BOTTOMRIGHT", 0, 4)
    else
        lagBarFrame:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", 0, -8)
        lagBarFrame:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 0, -8)
    end

    lastHostFrame = chatFrame
    lastEditBoxOpen = editBoxOpen
end

local function HideLagBar()
    lastSyncedAlpha = nil
    if lagBarFrame then
        lagBarFrame:Hide()
        lagBarFrame:SetAlpha(1)
    end
end

local function StopDriver()
    if lagBarDriver then
        lagBarDriver:Hide()
    end
end

local function RefreshLayout()
    local chatFrame = GetHostChatFrame()
    local editBoxOpen = GetOpenEditBox(chatFrame) ~= nil
    if chatFrame == lastHostFrame and editBoxOpen == lastEditBoxOpen then
        SyncAlphaFromTab()
        return
    end
    UpdateLagBar()
end

local function OnDriverUpdate(self, elapsed)
    elapsed = elapsed or 0

    layoutElapsed = layoutElapsed + elapsed
    if layoutElapsed >= LAYOUT_INTERVAL then
        layoutElapsed = 0
        RefreshLayout()
    end

    statsElapsed = statsElapsed + elapsed
    if statsElapsed >= UPDATE_INTERVAL then
        statsElapsed = 0
        if lagBarFrame and lagBarFrame:IsShown() then
            UpdateStats()
        end
    end

    memoryElapsed = memoryElapsed + elapsed
    local memoryNeed = memoryPrimed and MEMORY_INTERVAL or 2
    if memoryElapsed >= memoryNeed then
        if IsPlayerInCombat() then
            memoryElapsed = memoryNeed - 1
        else
            memoryElapsed = 0
            memoryPrimed = true
            RefreshAddonMemory(true)
        end
    end
end

local function StartDriver()
    if not lagBarDriver then
        lagBarDriver = CreateFrame("Frame")
        lagBarDriver:SetScript("OnUpdate", OnDriverUpdate)
    end
    lagBarDriver:Show()
end

function UpdateLagBar()
    if not IsLagBarEnabled() then
        HideLagBar()
        StopDriver()
        lastHostFrame = nil
        lastEditBoxOpen = nil
        return
    end

    if not lagBarFrame then
        return
    end

    local chatFrame = GetHostChatFrame()
    if not chatFrame or (chatFrame.IsShown and not chatFrame:IsShown()) then
        lastHostFrame = chatFrame
        lastEditBoxOpen = false
        HideLagBar()
        return
    end

    AnchorLagBar(chatFrame)
    lagBarFrame:Show()
    SyncAlphaFromTab()
end

local function EnsureLagBar()
    if lagBarFrame then
        return
    end

    local frame = CreateFrame("Frame", "SarychUIChatLagBar", UIParent)
    frame:SetHeight(16)
    frame:EnableMouse(false)
    frame:Hide()

    local function MakeValue(justify, point)
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint(point, frame, point, 0, 0)
        text:SetJustifyH(justify)
        text:SetTextColor(1, 1, 1, TEXT_ALPHA)
        text:SetAlpha(TEXT_ALPHA)
        text:Show()
        return text
    end

    lagBarMemText = MakeValue("LEFT", "LEFT")
    lagBarMsText = MakeValue("CENTER", "CENTER")
    lagBarFpsText = MakeValue("RIGHT", "RIGHT")
    lagBarFrame = frame
end

local function HookIfPresent(funcName, hook)
    local fn = _G[funcName]
    if type(fn) == "function" and hooksecurefunc then
        hooksecurefunc(funcName, hook)
    end
end

local function InstallHooks()
    if hooksInstalled then
        return
    end
    hooksInstalled = true

    HookIfPresent("ChatEdit_ActivateChat", UpdateLagBar)
    HookIfPresent("ChatEdit_DeactivateChat", UpdateLagBar)
    HookIfPresent("FCF_Tab_OnClick", UpdateLagBar)
    HookIfPresent("FCFTab_OnClick", UpdateLagBar)
    HookIfPresent("FCFDock_UpdateTabs", UpdateLagBar)
    HookIfPresent("ChatFrameMenu_UpdateAnchorPoint", UpdateLagBar)
end

local function EnableLagBar()
    EnsureLagBar()
    InstallHooks()
    HookPerformanceBarMemoryCapture()
    StartDriver()
    UpdateLagBar()
    if lagBarFrame and lagBarFrame:IsShown() then
        UpdateStats()
    end
end

local function DisableLagBar()
    StopDriver()
    HideLagBar()
    lastHostFrame = nil
    lastEditBoxOpen = nil
    memoryPrimed = false
    memoryElapsed = 0
end

local function ApplyLagBarSettings()
    if IsLagBarEnabled() then
        EnableLagBar()
    else
        DisableLagBar()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
pcall(initFrame.RegisterEvent, initFrame, "CHAT_TAB_CHANGED")
initFrame:SetScript("OnEvent", function()
    if IsLagBarEnabled() then
        ApplyLagBarSettings()
    end
end)

_G.EnableLagBar = EnableLagBar
_G.DisableLagBar = DisableLagBar
_G.ApplyLagBarSettings = ApplyLagBarSettings
_G.SarychUI_UpdateChatLagBar = UpdateLagBar
