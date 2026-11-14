-- InspectEquip display, driven by SarychUI's registry and shared timer service.
-- Observe Blizzard inspection without replacing InspectUnit or sending requests.
local Timer = select(2, ...).Compat.Timer
local IE = SarychUI.InspectEquip
local L = LibStub("AceLocale-3.0"):GetLocale("SarychUI_InspectEquip")
local rows, hooks = {}, {}
local window, title, average, events, timer
local activeParent, activeUnit, activeGUID, retryUntil
local count = 0
local noEnchant = {[2]=true, [6]=true, [11]=true, [12]=true, [13]=true, [14]=true, [17]=true, [18]=true}

local function Visible(frame)
    return frame and frame:IsVisible()
end

local function CancelRefresh()
    if timer then timer:Cancel(); timer = nil end
end

local function HideWindow()
    CancelRefresh()
    activeParent, activeUnit, activeGUID, retryUntil = nil, nil, nil, nil
    if window then window:Hide() end
    if IE.rowTooltip then GameTooltip:Hide(); IE.rowTooltip = nil end
end

local function CreateWindow()
    if window then return end
    window = CreateFrame("Frame", "SarychUIInspectEquipWindow", UIParent)
    IE.window = window
    window:Hide()
    window:SetClampedToScreen(true)
    window:SetBackdrop({bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true,
        tileSize = 32, edgeSize = 16, insets = {left=5, right=5, top=5, bottom=5}})
    title = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 15, -17)
    average = window:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    average:SetPoint("BOTTOM", 0, 14)
end

local function AddRow(text, link, unenchanted)
    count = count + 1
    local row = rows[count]
    if not row then
        row = CreateFrame("Button", nil, window)
        rows[count] = row
        row:SetHeight(14)
        row:SetPoint("TOPLEFT", 15, -40 - (count - 1) * 15)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT")
        row:SetScript("OnEnter", function(self)
            if not IE.enabled or not self.link then return end
            IE.rowTooltip = self
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetHyperlink(self.link)
            if self.unenchanted then GameTooltip:AddLine(L["Item is not enchanted"], 1, 0, 0) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            if IE.rowTooltip == self then GameTooltip:Hide(); IE.rowTooltip = nil end
        end)
        row:SetScript("OnClick", function(self)
            if IE.enabled and self.link then HandleModifiedItemClick(self.link) end
        end)
    end
    row.link, row.unenchanted = link, unenchanted
    row.text:SetText(text)
    row:SetWidth(math.max(1, row.text:GetStringWidth()))
    row:EnableMouse(link ~= nil)
    row:Show()
end

local function QueueRefresh(delay)
    if timer or not IE.enabled or not activeParent then return end
    timer = Timer.NewTimer(delay, function()
        timer = nil
        IE:Refresh()
    end)
end

function IE:Refresh()
    if not self.enabled or not Visible(activeParent) or not UnitExists(activeUnit)
        or UnitGUID(activeUnit) ~= activeGUID then
        HideWindow()
        return
    end
    if (activeParent == CharacterFrame and (not Visible(PaperDollFrame) or Visible(GearManagerDialog) or Visible(OutfitterFrame)))
        or (activeParent == InspectFrame and InspectPaperDollFrame and not Visible(InspectPaperDollFrame)) then
        HideWindow()
        return
    end
    CreateWindow()
    window:SetParent(activeParent)
    window:SetFrameStrata(activeParent:GetFrameStrata())
    window:SetFrameLevel(activeParent:GetFrameLevel() + 5)
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", activeParent, "TOPRIGHT", -25, -13)
    local name, realm = UnitName(activeUnit)
    title:SetText("InspectEquip: " .. (name or "") .. (realm and realm ~= "" and "-" .. realm or ""))
    count = 0
    local groups, order, pending = {}, {}, false
    local sum, known = 0, 0
    for slot = 1, 18 do
        if slot ~= 4 then -- shirt and tabard do not contribute
            local link = GetInventoryItemLink(activeUnit, slot)
            if link then
                local itemName, _, _, level = GetItemInfo(link)
                if not itemName then pending = true end
                if level then sum, known = sum + level, known + 1 end
                local sources = self:FindItem(link, true)
                if sources then
                    local source = sources[1]
                    local label = source[1]
                    if source[2] then label = label .. ": " .. source[2] end
                    if source[3] then label = label .. " (" .. source[3] .. ")" end
                    local group = groups[label]
                    if not group then group = {}; groups[label] = group; order[#order + 1] = label end
                    group[#group + 1] = {link = link, level = level,
                        unenchanted = not noEnchant[slot] and link:match("item:%d+:(%d+):") == "0"}
                end
            elseif GetInventoryItemTexture(activeUnit, slot) then
                pending = true
            end
        end
    end
    table.sort(order, function(a, b)
        if #groups[a] == #groups[b] then return a < b end
        return #groups[a] > #groups[b]
    end)
    for _, label in ipairs(order) do
        local group = groups[label]
        AddRow(label .. " (" .. #group .. ")")
        for _, item in ipairs(group) do
            AddRow("  " .. (item.level and "|cffaaaaaa[" .. item.level .. "]|r " or "")
                .. item.link .. (item.unenchanted and "|cffff0000*|r" or ""), item.link, item.unenchanted)
        end
    end
    for i = count + 1, #rows do
        rows[i].link, rows[i].unenchanted = nil, nil
        rows[i]:Hide()
    end
    average:SetText(known > 0 and L["Avg. Item Level"] .. ": " .. string.format("%.2f", sum / known) or "")
    local width = math.max(title:GetStringWidth(), average:GetStringWidth())
    for i = 1, count do width = math.max(width, rows[i].text:GetStringWidth()) end
    window:SetSize(width + 35, count * 15 + 70)
    if count > 0 then window:Show() else window:Hide() end
    -- Native 3.3.5 may deliver inspection inventory after the first frame/event.
    -- Retry briefly while opening; never poll while idle or send NotifyInspect.
    if retryUntil and GetTime() < retryUntil and (activeUnit ~= "player" or pending) then
        QueueRefresh(.25)
    else
        retryUntil = nil
    end
end

local function BeginView(parent, unit)
    if not IE.enabled or not Visible(parent) or not unit or not UnitExists(unit) then return end
    CancelRefresh()
    activeParent, activeUnit, activeGUID = parent, unit, UnitGUID(unit)
    retryUntil = GetTime() + 3
    IE:Refresh()
end

local function ShowCharacter()
    if Visible(PaperDollFrame) then BeginView(CharacterFrame, "player") end
end

local function ShowInspect()
    if InspectFrame and (not InspectPaperDollFrame or Visible(InspectPaperDollFrame)) then
        BeginView(InspectFrame, InspectFrame.unit)
    end
end

local function HookView(frame, show, parent)
    if not frame or hooks[frame] then return end
    hooks[frame] = true
    frame:HookScript("OnShow", function() if IE.enabled then show() end end)
    frame:HookScript("OnHide", function()
        if IE.enabled and activeParent == parent then HideWindow() end
    end)
end

function IE:AttachViews()
    HookView(PaperDollFrame, ShowCharacter, CharacterFrame)
    HookView(CharacterFrame, ShowCharacter, CharacterFrame)
    HookView(InspectFrame, ShowInspect, InspectFrame)
    HookView(InspectPaperDollFrame, ShowInspect, InspectFrame)
    for _, frame in pairs({GearManagerDialog, OutfitterFrame}) do
        if not hooks[frame] then
            hooks[frame] = true
            frame:HookScript("OnShow", function()
                if IE.enabled and activeParent == CharacterFrame then HideWindow() end
            end)
            frame:HookScript("OnHide", function() if IE.enabled then ShowCharacter() end end)
        end
    end
    if InspectFrame_UnitChanged and not hooks.inspectUnit then
        hooks.inspectUnit = true
        hooksecurefunc("InspectFrame_UnitChanged", function() if IE.enabled then ShowInspect() end end)
    end
    if InspectFrame_Show and not hooks.inspectShow then
        hooks.inspectShow = true
        -- InspectUnit calls this even when the inspect window is already open.
        hooksecurefunc("InspectFrame_Show", function() if IE.enabled then ShowInspect() end end)
    end
end

function IE:Start()
    if not events then
        events = CreateFrame("Frame")
        self.events = events
        events:SetScript("OnEvent", function(_, event, unit)
            if not IE.enabled then return end
            if event == "ADDON_LOADED" then
                IE:AttachViews(); IE:HookTooltips()
                if unit == "Blizzard_InspectUI" then ShowInspect() end
            elseif event == "UNIT_INVENTORY_CHANGED" then
                if activeUnit and UnitIsUnit(unit, activeUnit) then QueueRefresh(.05) end
            elseif event == "PLAYER_TARGET_CHANGED" then
                -- Hide stale data immediately when the inspected token changes.
                if activeUnit and UnitGUID(activeUnit) ~= activeGUID then HideWindow() end
            else
                QueueRefresh(.05)
            end
        end)
    end
    for _, event in ipairs({"ADDON_LOADED", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
        "GET_ITEM_INFO_RECEIVED", "INSPECT_TALENT_READY", "PLAYER_TARGET_CHANGED"}) do
        events:RegisterEvent(event)
    end
    self:AttachViews()
    self:HookTooltips()
    if Visible(InspectFrame) then ShowInspect() else ShowCharacter() end
    self:RefreshTooltips()
end

function IE:Stop()
    if events then events:UnregisterAllEvents() end
    HideWindow()
    self:ClearTooltips()
end
