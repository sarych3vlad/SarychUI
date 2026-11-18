-- Native 3.3.5 inventory and tooltip integration. No inspection-ready gate,
-- server-specific transport, replacement Blizzard methods or global GS_* state.
local owner = SarychUI.modules.item_info
local scheduler = SarychUI.UpdateScheduler
local events = CreateFrame("Frame")
local tips, hover, targetRequest = {}, nil, nil
local inspectLabel, inspectBackground, personalLabel, personalBackground
local ticking, lastInspect = false, -10
local Tick, SyncTicker, AttachInspect

local function Setting(key)
    return owner.running and owner:IsScoreEnabled() and owner.settings and owner.settings[key] == 1
end

local function InspectVisible()
    return InspectFrame and InspectFrame:IsShown()
end

local function ClearLine(tip)
    local state = tips[tip]
    if state and state.line and state.line:GetText() == state.text then
        if state.text ~= "" then state.line:SetText("") end
        state.text = ""
        return
    end
    if state then state.line, state.text = nil, nil end
end

local function SetLine(tip, text, r, g, b)
    local state = tips[tip]
    if not state then return end
    if state.line and state.line:GetText() ~= state.text then state.line = nil end
    if not state.line then
        tip:AddLine(text, r, g, b)
        state.line = _G[tip:GetName() .. "TextLeft" .. tip:NumLines()]
    elseif state.text ~= text or state.r ~= r or state.g ~= g or state.b ~= b then
        if state.text ~= text then state.line:SetText(text) end
        state.line:SetTextColor(r, g, b)
    else
        return
    end
    state.text = text
    state.r, state.g, state.b = r, g, b
    -- Relayout only after a changed line, never SetUnit/SetHyperlink in a tick.
    if tip:IsShown() then tip:Show() end
end

local function TooltipUnit(tip)
    local name, unit = tip:GetUnit()
    if not name then return end
    if not unit then
        local frame = GetMouseFocus and GetMouseFocus()
        unit = frame and (frame.unit or frame.raidid) or "mouseover"
        if UnitName(unit) ~= name then return end
    end
    if UnitIsPlayer(unit) then
        -- Prefer the stable selected-unit token for its inventory/inspect API.
        if UnitGUID("target") and UnitIsUnit(unit, "target") then return "target" end
    end
end

local function UnitValue(unit)
    local equipment = owner:GetUnitEquipment(unit)
    local r, g, b = owner:ScoreColor(equipment.score)
    if owner:IsItemLevelMode() then
        return owner:FormatItemLevel(equipment.average), equipment.count, r, g, b, equipment.score
    end
    return owner:FormatGearScore(equipment.score), equipment.scoreCount, r, g, b, equipment.score
end

local function ValueCaption()
    return owner:IsItemLevelMode() and "Item Level" or "GearScore"
end

local function PaintUnit(tip, unit)
    if not Setting("Player") or not UnitGUID("target") or not UnitIsUnit(unit, "target") then
        ClearLine(tip); return
    end
    local value, count, r, g, b = UnitValue(unit)
    if count > 0 and value then SetLine(tip, ValueCaption() .. ": " .. value, r, g, b)
    else ClearLine(tip) end
    return count
end

local function RequestTarget(now)
    local request = targetRequest
    if not request or request.requests >= 2 or UnitGUID("target") ~= request.guid
        or UnitIsUnit("target", "player") or InspectVisible()
        or (Examiner and Examiner:IsShown()) or InCombatLockdown()
        or now - lastInspect < 2 then return end
    -- UnitPopup's INSPECT entry uses interaction distance 1 in native FrameXML.
    if not CanInspect("target") and not CheckInteractDistance("target", 1) then return end
    request.requests = request.requests + 1
    lastInspect = now
    NotifyInspect("target")
end

local function BeginTargetRequest(background)
    if Setting("Player") and UnitGUID("target") and UnitIsPlayer("target") then
        targetRequest = {guid = UnitGUID("target"), requests = 0, untilTime = GetTime() + 4, background = background}
        RequestTarget(GetTime())
    else targetRequest = nil end
end

local function UnitTooltip(tip)
    local state = tips[tip]
    state.kind, state.link = "unit", nil
    local unit = TooltipUnit(tip)
    if not unit or not Setting("Player") then
        ClearLine(tip); hover = nil; SyncTicker(); return
    end
    local guid, now = UnitGUID(unit), GetTime()
    if not hover or hover.guid ~= guid then
        hover = {unit = unit, guid = guid}
        if not targetRequest or targetRequest.guid ~= guid or now > targetRequest.untilTime then
            BeginTargetRequest()
        end
    else
        hover.unit = unit
    end
    PaintUnit(tip, unit)
    if targetRequest and targetRequest.requests == 0 then RequestTarget(now) end
    SyncTicker()
end

local function ItemTooltip(tip)
    local state = tips[tip]
    local _, link = tip:GetItem()
    state.kind, state.link = "item", link
    if tip == GameTooltip then hover = nil; SyncTicker() end
    -- Individual item levels belong to the native showItemLevel tooltip line.
    if not Setting("Item") or owner:IsItemLevelMode() then ClearLine(tip); return end
    local score, _, _, colorScore = owner:ItemScore(link)
    if score then
        SetLine(tip, "GearScore: " .. owner:FormatGearScore(score), owner:ScoreColor(colorScore))
    else ClearLine(tip) end
end

local function PaintLabel(label, unit, background)
    if not label then return end
    local value, count, r, g, b, score = UnitValue(unit)
    local text = (label == personalLabel or count > 0) and (value or "") or ""
    if label:GetText() ~= text then
        label:SetText(text)
    end
    -- Equal average ilvl can still have a different GS color (e.g. quality).
    if label.scoreR ~= r or label.scoreG ~= g or label.scoreB ~= b then
        label:SetTextColor(r, g, b)
        label.scoreR, label.scoreG, label.scoreB = r, g, b
    end
    -- Use raw GS even when the displayed number is average item level.
    local progress = math.max(0, math.min(1, (score or 0) / 5500))
    if background.scoreProgress ~= progress then
        background.scoreProgress = progress
        background:SetAlpha(progress)
        background.color:SetAlpha(progress)
        -- Legacy SetDesaturated is binary. Blend gray and color layers;
        -- compensate the lower layer for source-over opacity at mid scores.
        background.gray:SetAlpha(1 / (1 + progress))
        if progress >= 1 then background.gray:Hide() else background.gray:Show() end
    end
end

local function RefreshInspect()
    if not inspectLabel then return end
    if Setting("Inspect") then
        inspectLabel:Show()
        if InspectVisible() then PaintLabel(inspectLabel, InspectFrame.unit, inspectBackground) end
    else inspectLabel:Hide() end
    local text = inspectLabel:GetText()
    if Setting("Inspect") and InspectVisible() and text and text ~= "" then
        inspectBackground:Show()
    else inspectBackground:Hide() end
end

local function RefreshPersonal()
    if not personalLabel then return end
    if owner.running and owner:IsScoreEnabled() then
        personalLabel:Show()
        PaintLabel(personalLabel, "player", personalBackground)
        local text = personalLabel:GetText()
        if text and text ~= "" then personalBackground:Show()
        else personalBackground:Hide() end
    else personalLabel:Hide(); personalBackground:Hide() end
end

local function MakeLabel(parent, slot)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if slot then label:SetPoint("BOTTOM", slot, "TOP", 0, 10)
    else label:SetPoint("BOTTOM", parent, "BOTTOM", 0, 64) end
    return label
end

function owner:CreateEquipmentStrip(parent)
    -- Shared gold strip for score badges and the source window header.
    local background = parent:CreateTexture(nil, "ARTWORK")
    background:SetTexture([[Interface\AddOns\SarychUI\media\textures\questtracker\QuestTracker]])
    background:SetTexCoord(19/1024, 581/1024, 326/512, 382/512)
    background:SetAlpha(0.9)
    return background
end

local function MakeScoreBackground(parent, label)
    local background = CreateFrame("Frame", nil, parent)
    background:EnableMouse(false)
    background:SetFrameLevel(parent:GetFrameLevel() - 1)
    background.gray = owner:CreateEquipmentStrip(background)
    background.gray:SetDrawLayer("BACKGROUND")
    background.gray:SetAllPoints(background)
    background.gray:SetDesaturated(true)
    background.color = owner:CreateEquipmentStrip(background)
    background.color:SetAllPoints(background)
    background:SetAlpha(0)
    background:SetSize(120, 24)
    -- Preserve the existing badge center from the bottom-anchored number,
    -- then align the text inside the visible gold borders.
    local _, relativeTo, relativePoint, x, y = label:GetPoint(1)
    label:SetText("0")
    local textHeight = label:GetHeight()
    label:SetText("")
    background:SetPoint("CENTER", relativeTo, relativePoint, x, y + textHeight / 2)
    label:ClearAllPoints()
    -- In this 56px atlas slice the gold lines are at y=3 and y=46.
    -- The lower shadow extends further, so centering in the whole texture
    -- places the number below the center of the visible rectangle.
    label:SetPoint("TOPLEFT", background, "TOPLEFT", 0, -24 * 3 / 56)
    label:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 0, 24 * (56 - 46) / 56)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    return background
end

AttachInspect = function()
    if inspectLabel or not InspectPaperDollFrame then return end
    -- Draw the entire score strip above the native inspect model/background.
    -- A BACKGROUND texture on InspectPaperDollFrame can be covered by its art
    -- and child frames even while an OVERLAY font string remains visible.
    local host = CreateFrame("Frame", nil, InspectPaperDollFrame)
    host:SetAllPoints(InspectPaperDollFrame)
    host:EnableMouse(false)
    local function RaiseInspectScore()
        host:SetFrameLevel(math.max(InspectPaperDollFrame:GetFrameLevel(),
            InspectModelFrame and InspectModelFrame:GetFrameLevel() or 0) + 2)
        if inspectBackground then inspectBackground:SetFrameLevel(host:GetFrameLevel() - 1) end
    end
    RaiseInspectScore()
    inspectLabel = MakeLabel(host, InspectSecondaryHandSlot)
    inspectLabel:SetJustifyH("CENTER")
    inspectBackground = MakeScoreBackground(host, inspectLabel)
    owner.inspectLabel = inspectLabel
    owner.inspectBackground = inspectBackground
    owner.inspectHost = host
    InspectPaperDollFrame:HookScript("OnShow", function() RaiseInspectScore(); RefreshInspect(); SyncTicker() end)
    InspectPaperDollFrame:HookScript("OnHide", function() SyncTicker() end)
    InspectFrame:HookScript("OnShow", function() RaiseInspectScore(); RefreshInspect(); SyncTicker() end)
    InspectFrame:HookScript("OnHide", function() SyncTicker() end)
    RefreshInspect()
end

Tick = function(now)
    owner.unitSnapshots = {}
    if owner.Sources and owner.Sources:NeedsRefresh(now) then owner.Sources:Refresh() end
    if Setting("Inspect") and InspectVisible() and InspectPaperDollFrame and InspectPaperDollFrame:IsShown() then
        RefreshInspect()
    end
    if targetRequest and Setting("Player") and targetRequest.requests == 0
        and now < targetRequest.untilTime then
        RequestTarget(now)
    end
    if hover and Setting("Player") and GameTooltip:IsShown() then
        local unit = TooltipUnit(GameTooltip)
        if not unit or UnitGUID(unit) ~= hover.guid then
            ClearLine(GameTooltip); hover = nil
        else
            hover.unit = unit
            local count = PaintUnit(GameTooltip, unit)
            if targetRequest and (targetRequest.requests == 0 or count == 0) then RequestTarget(now) end
        end
    end
    SyncTicker()
    owner.unitSnapshots = nil
end

SyncTicker = function()
    local active = owner.running and (
        (owner.Sources and owner.Sources:NeedsRefresh(GetTime()))
        or
        (Setting("Inspect") and InspectVisible() and InspectPaperDollFrame and InspectPaperDollFrame:IsShown())
        or (Setting("Player") and hover and GameTooltip:IsShown())
        or (Setting("Player") and targetRequest and targetRequest.background and targetRequest.requests == 0
            and GetTime() < targetRequest.untilTime and UnitGUID("target") == targetRequest.guid))
    if active and not ticking then
        scheduler:RegisterUpdate("equipmentInfo", .25, Tick)
        ticking = true
    elseif not active and ticking then
        scheduler:UnregisterUpdate("equipmentInfo")
        ticking = false
    end
end

function owner:SyncEquipmentTicker() SyncTicker() end

function owner:RefreshEquipmentViews()
    self.unitSnapshots = {}
    if self.Sources and self.Sources.enabled then self.Sources:Refresh() end
    AttachInspect()
    RefreshPersonal()
    RefreshInspect()
    for tip, state in pairs(tips) do
        if tip:IsShown() then
            if state.kind == "unit" then
                local unit = TooltipUnit(tip)
                if unit and (not hover or UnitGUID(unit) == hover.guid) then
                    PaintUnit(tip, unit)
                else ClearLine(tip) end
            elseif state.kind == "item" then ItemTooltip(tip) end
        end
    end
    SyncTicker()
    self.unitSnapshots = nil
end

function owner:SetEquipmentRuntime(enabled)
    self.running = enabled and true or false
    events:UnregisterAllEvents()
    if enabled then
        for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
            "UNIT_INVENTORY_CHANGED", "INSPECT_TALENT_READY", "GET_ITEM_INFO_RECEIVED",
            "PLAYER_TARGET_CHANGED"}) do
            events:RegisterEvent(event)
        end
    end
    if not enabled or not self:IsScoreEnabled() then
        hover, targetRequest = nil, nil
        for tip in pairs(tips) do ClearLine(tip) end
    end
    self:RefreshEquipmentViews()
end

events:SetScript("OnEvent", function(_, event, unit)
    if owner.Sources and owner.Sources.enabled then owner.Sources:OnEquipmentEvent(event, unit) end
    if event == "ADDON_LOADED" then
        if unit == "Blizzard_InspectUI" then AttachInspect(); SyncTicker() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        hover = nil
        BeginTargetRequest(true)
        if GameTooltip:IsShown() and tips[GameTooltip].kind == "unit" then
            UnitTooltip(GameTooltip)
        end
        SyncTicker()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        RefreshPersonal()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if unit == "player" then RefreshPersonal() end
        if InspectVisible() and unit == InspectFrame.unit then RefreshInspect() end
        if hover and GameTooltip:IsShown() and UnitGUID(unit) == hover.guid
            and UnitGUID(hover.unit) == hover.guid then PaintUnit(GameTooltip, hover.unit) end
    else
        -- Notifications also complete a tooltip whose short polling window ended.
        owner:RefreshEquipmentViews()
    end
end)
owner.events = events

for _, tip in ipairs({GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2}) do
    tips[tip] = {}
    tip:HookScript("OnTooltipSetItem", ItemTooltip)
    tip:HookScript("OnTooltipCleared", function(self)
        tips[self] = {}
    end)
    tip:HookScript("OnHide", function(self)
        if self == GameTooltip then hover = nil; SyncTicker() end
    end)
end
GameTooltip:HookScript("OnTooltipSetUnit", UnitTooltip)
-- Observe other inspect users only to share the request throttle. Never clear
-- inspection data or send extra requests from inventory item tooltips.
hooksecurefunc("NotifyInspect", function() lastInspect = GetTime() end)
if PaperDollFrame then
    -- The native stats panel occupies the area above the weapon slots. Its
    -- child-frame background covers text drawn on PaperDollFrame itself.
    local host = CreateFrame("Frame", nil, PaperDollFrame)
    host:SetAllPoints(PaperDollFrame)
    host:EnableMouse(false)
    local function RaisePersonalScore()
        host:SetFrameLevel(math.max(PaperDollFrame:GetFrameLevel(),
            CharacterModelFrame and CharacterModelFrame:GetFrameLevel() or 0) + 2)
        if personalBackground then personalBackground:SetFrameLevel(host:GetFrameLevel() - 1) end
    end
    RaisePersonalScore()
    personalLabel = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    personalLabel:SetJustifyH("CENTER")
    -- Center below the model, above the native character stats panel.
    if CharacterModelFrame then
        personalLabel:SetPoint("BOTTOM", CharacterModelFrame, "BOTTOM", 0, 30)
    else personalLabel:SetPoint("BOTTOM", PaperDollFrame, "TOPLEFT", 181.5, -263) end
    personalBackground = MakeScoreBackground(host, personalLabel)
    owner.personalBackground = personalBackground
    owner.personalHost = host
    owner.personalLabel = personalLabel
    personalLabel:Hide()
    personalBackground:Hide()
    PaperDollFrame:HookScript("OnShow", function() RaisePersonalScore(); RefreshPersonal() end)
end
