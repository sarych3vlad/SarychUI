-- Source view of equipment information, driven by its shared event frame/ticker.
-- Observe Blizzard inspection without replacing InspectUnit or sending requests.
local owner = SarychUI.modules.item_info
local IE = owner.Sources
local theme = SarychUI.OptionsTheme
local L = LibStub("AceLocale-3.0"):GetLocale("SarychUI_InspectEquip")
local rows, hooks = {}, {}
local window, header, headerValue, scroll, content, scrollbar, updateScrollbar, refreshPending
local activeParent, activeUnit, activeGUID, retryUntil
local count, rowY, naturalWidth = 0, 0, 1
local HEADER_HEIGHT, LIST_TOP, PADDING = 24, 32, 12
local PARENT_BOTTOM_INSET = 75 -- Native 45px lower inset plus 30px of extra space below the list.
local UpdateLayout
local noEnchant = {[2]=true, [6]=true, [11]=true, [12]=true, [13]=true, [14]=true, [17]=true, [18]=true}

local function Visible(frame)
    return frame and frame:IsVisible()
end

local function CancelRefresh()
    refreshPending = nil
end

local function ClearRowTooltip()
    if IE.rowTooltip then GameTooltip:Hide(); IE.rowTooltip = nil end
end

local function HideWindow()
    CancelRefresh()
    activeParent, activeUnit, activeGUID, retryUntil = nil, nil, nil, nil
    if window then window:Hide() end
    if scroll then scroll:SetVerticalScroll(0) end
    ClearRowTooltip()
    owner:SyncEquipmentTicker()
end

local function CreateWindow()
    if window then return end
    window = CreateFrame("Frame", "SarychUIInspectEquipWindow", UIParent)
    IE.window = window
    window:Hide()
    window:SetClampedToScreen(true)
    -- The header shares the body's background, without a separate opaque plate.
    local bodyColor = theme.colors.contentBg
    theme:ApplyFlat(window, {bodyColor[1], bodyColor[2], bodyColor[3], 0.80}, theme.colors.border)
    header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    header:SetFrameLevel(window:GetFrameLevel() + 6)
    local background = owner:CreateEquipmentStrip(header)
    background:SetPoint("TOPLEFT", header, "TOPLEFT", -6, 0)
    background:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 6, 0)
    background:SetVertexColor(0.90, 0.95, 1)
    background:SetAlpha(0.80)
    headerValue = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- Center the value between the atlas's visible gold borders, as on the score badge.
    headerValue:SetPoint("TOPLEFT", background, "TOPLEFT", PADDING + 22, -HEADER_HEIGHT * 3 / 56)
    headerValue:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -PADDING - 22, HEADER_HEIGHT * 10 / 56)
    headerValue:SetJustifyH("CENTER")
    headerValue:SetJustifyV("MIDDLE")
    theme:SetTextColor(headerValue, "title")
    IE.headerValue = headerValue

    scroll = CreateFrame("ScrollFrame", nil, window)
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, -LIST_TOP)
    scroll:SetSize(1, 1)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scrollbar, updateScrollbar = SarychUI.OptionsWidgets:Scrollbar(window, scroll, function()
        return scroll:GetHeight(), content:GetHeight()
    end, ClearRowTooltip)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        scrollbar:GetScript("OnMouseWheel")(scrollbar, delta)
    end)
    IE.header, IE.scroll, IE.content, IE.scrollbar = header, scroll, content, scrollbar
end

UpdateLayout = function()
    if not window or not activeParent then return end
    -- Account for the top offset and leave the native lower area clear.
    local maximum = math.max(LIST_TOP + PADDING + 1, activeParent:GetHeight() - 13 - PARENT_BOTTOM_INSET)
    local height = math.min(LIST_TOP + rowY + PADDING, maximum)
    local view = height - LIST_TOP - PADDING
    local gutter = rowY > view + 1 and theme.sizes.scrollbarW + theme.sizes.scrollbarGap or 0
    local width = naturalWidth + PADDING * 2 + gutter
    window:SetSize(width, height)
    scroll:SetSize(width - PADDING * 2 - gutter, view)
    content:SetSize(width - PADDING * 2 - gutter, math.max(1, rowY))
    updateScrollbar()
end

local function AddRow(text, link, unenchanted)
    count = count + 1
    local row = rows[count]
    if not row then
        row = CreateFrame("Button", nil, content)
        rows[count] = row
        row:SetHeight(14)
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
    -- Reused rows can move between groups when equipment changes.
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -rowY)
    rowY = rowY + 15
    row.text:SetText(text)
    row:SetWidth(math.max(1, row.text:GetStringWidth()))
    row:EnableMouse(link ~= nil)
    row:Show()
end

local function QueueRefresh()
    if not IE.enabled or not activeParent then return end
    refreshPending = true
    owner:SyncEquipmentTicker()
end

function IE:NeedsRefresh(now)
    return self.enabled and activeParent and (refreshPending ~= nil or (retryUntil and now < retryUntil))
end

function IE:Refresh()
    refreshPending = nil
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
    header:SetFrameLevel(window:GetFrameLevel() + 6)
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", activeParent, "TOPRIGHT", -25, -13)
    count, rowY = 0, 0
    local groups, order, pending = {}, {}, false
    local equipment = owner:GetUnitEquipment(activeUnit)
    -- Complement the main score display; sources alone retain the average ilvl.
    local value
    if owner:IsScoreEnabled() and owner:IsItemLevelMode() then
        value = equipment.scoreCount > 0 and owner:FormatGearScore(equipment.score)
    else
        value = equipment.count > 0 and owner:FormatItemLevel(equipment.average)
    end
    headerValue:SetText(value or "")
    pending = equipment.pending
    for slot = 1, 18 do
        if slot ~= 4 then -- shirt and tabard do not contribute
            local entry = equipment.slots[slot]
            local link = entry and entry.link
            if link then
                local level = entry.item and entry.item.level
                local sources = self:FindItem(link, true)
                if sources then
                    local source = sources[1]
                    local label = source[1]
                    if source[2] then label = label .. ": " .. source[2] end
                    if source[3] then label = label .. " (" .. source[3] .. ")" end
                    local group = groups[label]
                    if not group then
                        group = {priority = source.priority or 0}
                        groups[label] = group
                        order[#order + 1] = label
                    end
                    group[#group + 1] = {link = link, level = level,
                        unenchanted = not noEnchant[slot] and link:match("item:%d+:(%d+):") == "0"}
                end
            end
        end
    end
    table.sort(order, function(a, b)
        if groups[a].priority ~= groups[b].priority then return groups[a].priority > groups[b].priority end
        if #groups[a] == #groups[b] then return a < b end
        return #groups[a] > #groups[b]
    end)
    for index, label in ipairs(order) do
        if index > 1 then rowY = rowY + 8 end
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
    naturalWidth = headerValue:GetStringWidth() + 44
    for i = 1, count do naturalWidth = math.max(naturalWidth, rows[i].text:GetStringWidth()) end
    UpdateLayout()
    if count > 0 then window:Show() else window:Hide() end
    -- Native 3.3.5 may deliver inspection inventory after the first frame/event.
    -- Retry briefly while opening; never poll while idle or send NotifyInspect.
    if retryUntil and GetTime() < retryUntil and (activeUnit ~= "player" or pending) then
        QueueRefresh()
    else
        retryUntil = nil
    end
    owner:SyncEquipmentTicker()
end

local function BeginView(parent, unit)
    if not IE.enabled or not Visible(parent) or not unit or not UnitExists(unit) then return end
    CancelRefresh()
    if scroll and (activeParent ~= parent or activeGUID ~= UnitGUID(unit)) then scroll:SetVerticalScroll(0) end
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
    if frame == parent then
        frame:HookScript("OnSizeChanged", function()
            if IE.enabled and activeParent == frame then UpdateLayout() end
        end)
    end
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

function IE:OnEquipmentEvent(event, unit)
    if event == "ADDON_LOADED" then
        self:AttachViews(); self:HookTooltips()
        if unit == "Blizzard_InspectUI" then ShowInspect() end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if activeUnit and UnitIsUnit(unit, activeUnit) then QueueRefresh() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if activeUnit and UnitGUID(activeUnit) ~= activeGUID then HideWindow() end
    else
        QueueRefresh()
    end
end

function IE:Start()
    self:AttachViews()
    self:HookTooltips()
    if Visible(InspectFrame) then ShowInspect() else ShowCharacter() end
    self:RefreshTooltips()
end

function IE:Stop()
    HideWindow()
    self:ClearTooltips()
end
