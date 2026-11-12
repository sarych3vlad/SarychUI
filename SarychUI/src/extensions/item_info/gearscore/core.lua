-- Native 3.3.5 inventory and tooltip integration. No inspection-ready gate,
-- server-specific transport, replacement Blizzard methods or global GS_* state.
local owner = SarychUI.addons.GearScoreLite
local scheduler = SarychUI.UpdateScheduler
local events = CreateFrame("Frame")
local tips, hover, targetRequest = {}, nil, nil
local inspectLabel, personalLabel, personalCaption
local ticking, lastInspect = false, -10
local Tick, SyncTicker, AttachInspect

local function Setting(key)
    return owner.GearScoreLiteRunning and owner.settings and owner.settings[key] == 1
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

local function SetLine(tip, score, r, g, b)
    local state = tips[tip]
    if not state then return end
    local text = "GearScore: " .. score
    if state.line and state.line:GetText() ~= state.text then state.line = nil end
    if not state.line then
        tip:AddLine(text, r, g, b)
        state.line = _G[tip:GetName() .. "TextLeft" .. tip:NumLines()]
    elseif state.text ~= text then
        state.line:SetText(text)
        state.line:SetTextColor(r, g, b)
    else
        return
    end
    state.text = text
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

local function PaintUnit(tip, unit)
    if not Setting("Player") or not UnitGUID("target") or not UnitIsUnit(unit, "target") then
        ClearLine(tip); return
    end
    local score, count = owner:UnitScore(unit)
    if count > 0 then SetLine(tip, score, owner:ScoreColor(score))
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
    if not Setting("Item") then ClearLine(tip); return end
    local score, _, _, colorScore = owner:ItemScore(link)
    if score then
        SetLine(tip, score, owner:ScoreColor(colorScore))
    else ClearLine(tip) end
end

local function PaintLabel(label, unit)
    if not label then return end
    local score, count = owner:UnitScore(unit)
    local text = label == personalLabel and tostring(score)
        or (count > 0 and ("GearScore: " .. score) or "")
    if label:GetText() ~= text then
        label:SetText(text)
        label:SetTextColor(owner:ScoreColor(score))
    end
end

local function RefreshInspect()
    if not inspectLabel then return end
    if Setting("Inspect") then
        inspectLabel:Show()
        if InspectVisible() then PaintLabel(inspectLabel, InspectFrame.unit) end
    else inspectLabel:Hide() end
end

local function RefreshPersonal()
    if not personalLabel then return end
    if owner.GearScoreLiteRunning then
        personalLabel:Show()
        personalCaption:Show()
        PaintLabel(personalLabel, "player")
    else personalLabel:Hide(); personalCaption:Hide() end
end

local function MakeLabel(parent, slot)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if slot then label:SetPoint("BOTTOM", slot, "TOP", 0, 10)
    else label:SetPoint("BOTTOM", parent, "BOTTOM", 0, 64) end
    return label
end

AttachInspect = function()
    if inspectLabel or not InspectPaperDollFrame then return end
    inspectLabel = MakeLabel(InspectPaperDollFrame, InspectSecondaryHandSlot)
    owner.inspectLabel = inspectLabel
    InspectPaperDollFrame:HookScript("OnShow", function() RefreshInspect(); SyncTicker() end)
    InspectPaperDollFrame:HookScript("OnHide", function() SyncTicker() end)
    InspectFrame:HookScript("OnShow", function() RefreshInspect(); SyncTicker() end)
    InspectFrame:HookScript("OnHide", function() SyncTicker() end)
    RefreshInspect()
end

Tick = function(now)
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
end

SyncTicker = function()
    local active = owner.GearScoreLiteRunning and (
        (Setting("Inspect") and InspectVisible() and InspectPaperDollFrame and InspectPaperDollFrame:IsShown())
        or (Setting("Player") and hover and GameTooltip:IsShown())
        or (Setting("Player") and targetRequest and targetRequest.background and targetRequest.requests == 0
            and GetTime() < targetRequest.untilTime and UnitGUID("target") == targetRequest.guid))
    if active and not ticking then
        scheduler:RegisterUpdate("gearScore", .25, Tick)
        ticking = true
    elseif not active and ticking then
        scheduler:UnregisterUpdate("gearScore")
        ticking = false
    end
end

function owner:RefreshGearScoreViews()
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
end

function owner:SetGearScoreRuntime(enabled)
    self.GearScoreLiteRunning = enabled and true or false
    events:UnregisterAllEvents()
    if enabled then
        for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
            "UNIT_INVENTORY_CHANGED", "INSPECT_TALENT_READY", "GET_ITEM_INFO_RECEIVED",
            "PLAYER_TARGET_CHANGED"}) do
            events:RegisterEvent(event)
        end
    else
        hover, targetRequest = nil, nil
        for tip in pairs(tips) do ClearLine(tip) end
    end
    self:RefreshGearScoreViews()
end

events:SetScript("OnEvent", function(_, event, unit)
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
        owner:RefreshGearScoreViews()
    end
end)

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
            CharacterModelFrame and CharacterModelFrame:GetFrameLevel() or 0) + 1)
    end
    RaisePersonalScore()
    personalLabel = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    personalLabel:SetFont("Fonts\\FRIZQT__.TTF", 12)
    -- Original GearScoreLite position, independent of the model's geometry.
    personalLabel:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 72, -253)
    personalCaption = host:CreateFontString(nil, "OVERLAY")
    personalCaption:SetFont("Fonts\\FRIZQT__.TTF", 12)
    personalCaption:SetText("GearScore")
    personalCaption:SetTextColor(1, 1, 1)
    personalCaption:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 72, -265)
    owner.personalCaption = personalCaption
    owner.personalHost = host
    owner.personalLabel = personalLabel
    personalLabel:Hide()
    personalCaption:Hide()
    PaperDollFrame:HookScript("OnShow", function() RaisePersonalScore(); RefreshPersonal() end)
end
