-- SarychUI Chat DataBar
-- FPS/ms: GetFramerate() and GetNetStats(), same as MainMenuBarPerformanceBar tooltip.
-- Memory: read GetAddOnMemoryUsage after the game already scanned it on menu hover.
-- Visibility follows the selected chat tab (same idea as the LootHistory loot-tab button).
-- Anchored under the chat; shifts below the edit box when it opens (like ChatFrameMenuButton).

local floor = math.floor
local DT = _G.SarychUI_ChatDataTexts

local UPDATE_INTERVAL = 1
local LAYOUT_INTERVAL = 0.15
local MEMORY_INTERVAL = 15
local ACTIVE_FACTOR = 1.0
local INACTIVE_FACTOR = 0.25
local TEXT_ALPHA = 0.8

local COLOR_WHITE = { 1, 1, 1 }
local COLOR_YELLOW = { 1, 0.82, 0 }
local COLOR_RED = { 1, 0.15, 0.15 }

local dataBarFrame
local dataBarDriver
local altCallbackRegistered = false
local lastSyncedAlpha
local lastHostFrame
local lastEditBoxOpen
local cachedMemoryMB = 0
local statsElapsed = 0
local layoutElapsed = 0
local memoryElapsed = 0
local memoryPrimed = false
local hooksInstalled = false
local performanceHooksInstalled = false
local UpdateDataBar
local UpdateStats

local function GetChatDb()
    return SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.chat
end

local function IsChatModuleEnabled()
    local db = GetChatDb()
    return db and db.enabled
end

local function IsDataBarEnabled()
    if not IsChatModuleEnabled() then
        return false
    end
    local db = GetChatDb()
    if db and db.dataBarEnabled ~= nil then
        return db.dataBarEnabled == 1
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
        fs:SetTextColor(color[1], color[2], color[3], 1)
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
    if UpdateStats and dataBarFrame and dataBarFrame:IsShown() then
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
        if not frame or frame._sarychDataBarMemHook then
            return
        end
        frame._sarychDataBarMemHook = true
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
    if not dataBarFrame or not dataBarFrame:IsShown() then
        return
    end

    local chatFrame = lastHostFrame or GetHostChatFrame()
    local alpha = ComputeAlphaFromTab(GetChatTab(chatFrame))
    if lastSyncedAlpha == alpha then
        return
    end
    lastSyncedAlpha = alpha
    dataBarFrame:SetAlpha(alpha)
end

function UpdateStats()
    if not dataBarFrame then return end
    local framerate = floor(GetFramerate() + 0.5)
    local _, _, latency = GetNetStats()
    latency = floor(latency or 0)
    for _, slot in ipairs(dataBarFrame.slots) do
        if slot.kind == "Memory" then
            slot.text:SetFormattedText(slot.textEnabled and "mb: %.1f" or "%.1f", cachedMemoryMB)
            SetStatColor(slot.text, GetMemoryColor(cachedMemoryMB))
        elseif slot.kind == "MS" then
            slot.text:SetFormattedText(slot.textEnabled and "ms: %d" or "%d", latency)
            SetStatColor(slot.text, GetLatencyColor(latency))
        elseif slot.kind == "FPS" then
            slot.text:SetFormattedText(slot.textEnabled and "fps: %d" or "%d", framerate)
            SetStatColor(slot.text, GetFramerateColor(framerate))
        end
    end
end

DT.RefreshMemory = function()
    RefreshAddonMemory(true)
    return cachedMemoryMB
end

local function AnchorDataBar(chatFrame)
    if not (dataBarFrame and chatFrame) then
        return
    end

    -- Parent stays UIParent: ChatFrame would clip a child drawn below its bounds.
    if dataBarFrame:GetParent() ~= UIParent then
        dataBarFrame:SetParent(UIParent)
    end

    dataBarFrame:SetFrameStrata(chatFrame:GetFrameStrata() or "LOW")
    dataBarFrame:SetFrameLevel((chatFrame:GetFrameLevel() or 0) + 5)

    local eb = GetOpenEditBox(chatFrame)
    local editBoxOpen = eb ~= nil

    dataBarFrame:ClearAllPoints()
    if editBoxOpen then
        dataBarFrame:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", 0, 4)
        dataBarFrame:SetPoint("TOPRIGHT", eb, "BOTTOMRIGHT", 0, 4)
    else
        dataBarFrame:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", 0, -8)
        dataBarFrame:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 0, -8)
    end

    lastHostFrame = chatFrame
    lastEditBoxOpen = editBoxOpen
end

local function HideDataBar()
    DT:Leave()
    lastSyncedAlpha = nil
    if dataBarFrame then
        dataBarFrame:Hide()
        dataBarFrame:SetAlpha(1)
    end
end

local function StopDriver()
    if altCallbackRegistered and SarychUI.AltMode then
        SarychUI.AltMode:UnregisterCallback("chat_data_bar")
        altCallbackRegistered = false
    end
    if dataBarDriver then
        dataBarDriver:Hide()
    end
end

local function RefreshLayout()
    local chatFrame = GetHostChatFrame()
    local editBoxOpen = GetOpenEditBox(chatFrame) ~= nil
    if chatFrame == lastHostFrame and editBoxOpen == lastEditBoxOpen then
        SyncAlphaFromTab()
        return
    end
    UpdateDataBar()
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
        if dataBarFrame and dataBarFrame:IsShown() then
            UpdateStats()
        end
    end

    memoryElapsed = memoryElapsed + elapsed
    local memoryNeed = memoryPrimed and MEMORY_INTERVAL or 2
    if memoryElapsed >= memoryNeed and DT:HasKind("Memory") then
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
    if not dataBarDriver then
        dataBarDriver = CreateFrame("Frame")
        dataBarDriver:SetScript("OnUpdate", OnDriverUpdate)
    end
    dataBarDriver:Show()
end

function UpdateDataBar()
    if not IsDataBarEnabled() then
        HideDataBar()
        StopDriver()
        DT:Stop()
        lastHostFrame = nil
        lastEditBoxOpen = nil
        return
    end

    local visibility = _G.SarychUI_ChatVisibility
    if visibility and visibility.IsHidden and visibility.IsHidden() then
        HideDataBar()
        return
    end

    if not dataBarFrame then
        return
    end

    local chatFrame = GetHostChatFrame()
    if not chatFrame or (chatFrame.IsShown and not chatFrame:IsShown()) then
        lastHostFrame = chatFrame
        lastEditBoxOpen = false
        HideDataBar()
        return
    end

    AnchorDataBar(chatFrame)
    dataBarFrame:Show()
    SyncAlphaFromTab()
end

local function EnsureDataBar()
    if dataBarFrame then
        return
    end

    local frame = CreateFrame("Frame", "SarychUIChatDataBar", UIParent)
    frame:SetHeight(16)
    frame:EnableMouse(false)
    frame:Hide()

    frame.slots = {}
    local function MakeValue(position, justify, point)
        local slot = CreateFrame("Button", nil, frame)
        slot.position = position
        slot.justify = justify
        -- One opacity for both text and ordinary icon regions.
        slot:SetAlpha(TEXT_ALPHA)
        slot:SetHeight(16)
        slot:SetPoint(point, frame, point, 0, 0)
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", slot, "LEFT", 2, 0)
        text:SetPoint("RIGHT", slot, "RIGHT", -2, 0)
        text:SetJustifyH(justify)
        text:SetTextColor(1, 1, 1, 1)
        text:SetWordWrap(false)
        slot.text = text
        slot:SetScript("OnSizeChanged", function(self) DT:LayoutInline(self) end)
        table.insert(frame.slots, slot)
    end
    MakeValue("left", "LEFT", "LEFT")
    MakeValue("middle", "CENTER", "CENTER")
    MakeValue("right", "RIGHT", "RIGHT")
    local function ResizeSlots(self)
        local width = math.max(1, self:GetWidth() / 3)
        for _, slot in ipairs(self.slots) do slot:SetWidth(width) end
    end
    frame:SetScript("OnSizeChanged", ResizeSlots)
    ResizeSlots(frame)
    dataBarFrame = frame
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

    HookIfPresent("ChatEdit_ActivateChat", UpdateDataBar)
    HookIfPresent("ChatEdit_DeactivateChat", UpdateDataBar)
    HookIfPresent("FCF_Tab_OnClick", UpdateDataBar)
    HookIfPresent("FCFTab_OnClick", UpdateDataBar)
    HookIfPresent("FCFDock_UpdateTabs", UpdateDataBar)
    HookIfPresent("ChatFrameMenu_UpdateAnchorPoint", UpdateDataBar)
end

local function OnDataBarAltChanged(pressed)
    if not IsDataBarEnabled() then return end
    local hovered = DT.hoveredSlot or (GetMouseFocus and GetMouseFocus())
    if not DT:SetAltState(pressed) then return end
    UpdateStats()
    -- The mouse need not leave/re-enter a region to get the new value's tooltip.
    for _, slot in ipairs(DT.slots) do
        if slot == hovered and slot:IsShown() then DT:Enter(slot); break end
    end
end

local function EnableDataBar()
    EnsureDataBar()
    InstallHooks()
    HookPerformanceBarMemoryCapture()
    DT:Apply(dataBarFrame, GetChatDb())
    if SarychUI.AltMode then
        if DT.altConfigured and not altCallbackRegistered then
            altCallbackRegistered = true
            SarychUI.AltMode:RegisterCallback("chat_data_bar", OnDataBarAltChanged)
        elseif not DT.altConfigured and altCallbackRegistered then
            SarychUI.AltMode:UnregisterCallback("chat_data_bar")
            altCallbackRegistered = false
        end
    end
    StartDriver()
    UpdateDataBar()
    if dataBarFrame and dataBarFrame:IsShown() then
        UpdateStats()
    end
end

local function DisableDataBar()
    DT:Stop()
    StopDriver()
    HideDataBar()
    lastHostFrame = nil
    lastEditBoxOpen = nil
    memoryPrimed = false
    memoryElapsed = 0
end

local function ApplyDataBarSettings()
    -- Imported/copied profiles may still contain settings from the old lag bar.
    SarychUI:MigrateChatDataBarSettings(GetChatDb())
    if IsDataBarEnabled() then
        EnableDataBar()
    else
        DisableDataBar()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
pcall(initFrame.RegisterEvent, initFrame, "CHAT_TAB_CHANGED")
initFrame:SetScript("OnEvent", function()
    if IsDataBarEnabled() then
        if dataBarFrame then UpdateDataBar() else ApplyDataBarSettings() end
    end
end)

_G.EnableDataBar = EnableDataBar
_G.DisableDataBar = DisableDataBar
_G.ApplyDataBarSettings = ApplyDataBarSettings
_G.SarychUI_UpdateChatDataBar = UpdateDataBar
