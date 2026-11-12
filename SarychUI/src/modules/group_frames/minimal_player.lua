-- Passive player health strip, independent of compact unit-frame decorations.
local module = SarychUI.modules.group_frames
local frame
local extendedBorder, borderMember

local function RestoreGroupBorder()
    if extendedBorder then
        extendedBorder:SetPoint("TOPLEFT", borderMember, "TOPLEFT", -3, 5)
        extendedBorder, borderMember = nil, nil
    end
end

local function Enabled()
    local db = SarychUI.db and SarychUI.db.profile.modules.group_frames
    return db and db.enabled ~= false and db.sortOrder == "MINIMAL_TOP"
end

local function UpdateLayers(self)
    local layers = SarychUI.UnitFrameLayers
    if not layers or not layers:IsEnabled() then return end
    UnitFrameLayers_AttachHealPrediction(self, false, true)
    UnitFrameLayers_SetHealPredictionEnabled(self, true)
    UnitFrameLayers_UpdateHealPrediction(self)
end

local function UpdateHealth(self)
    local health, maximum = UnitHealth("player"), math.max(1, UnitHealthMax("player"))
    local previous = self.previousHealth
    self.healthbar:SetMinMaxValues(0, maximum)
    self.healthbar:SetValue(health)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and colors[select(2, UnitClass("player"))]
    self.healthbar:SetStatusBarColor(color and color.r or 0, color and color.g or 1, color and color.b or 0)
    local layers = SarychUI.UnitFrameLayers
    local enabled = layers and layers:IsEnabled()
    if layers and layers.frames[self] ~= "player" then
        layers:RegisterExternal(self, "player", UpdateLayers)
    end
    if enabled then UpdateLayers(self)
    elseif UnitFrameLayers_SetHealPredictionEnabled then UnitFrameLayers_SetHealPredictionEnabled(self, false) end
    local loss = self.PlayerFrameHealthBarAnimatedLoss
    if enabled and loss then
        loss:SetMinMaxValues(0, maximum)
        if previous and previous ~= health then loss:UpdateHealth(health, previous) end
        loss:UpdateLossAnimation(health)
    end
    self.previousHealth = health
end

local function Create(container)
    local self = CreateFrame("Frame", "SarychUIGroupPlayerHealth", container)
    self:Hide()
    self:EnableMouse(false)
    self.unit = "player"
    self:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    self:SetBackdropColor(0.08, 0.08, 0.08, 1)
    self:SetBackdropBorderColor(0, 0, 0, 1)
    local bar = CreateFrame("StatusBar", nil, self)
    self.healthbar = bar
    bar:EnableMouse(false)
    bar:SetFrameLevel(self:GetFrameLevel() + 2)
    bar:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\Raid-Bar-Hp-Fill")
    self:SetScript("OnShow", function(f)
        f.previousHealth = nil
        for _, event in ipairs({"UNIT_HEALTH", "UNIT_MAXHEALTH", "PLAYER_ALIVE", "PLAYER_DEAD", "PLAYER_UNGHOST"}) do f:RegisterEvent(event) end
        UpdateHealth(f)
    end)
    self:SetScript("OnHide", function(f)
        f:UnregisterAllEvents()
        if SarychUI.UnitFrameLayers then SarychUI.UnitFrameLayers:Unregister(f) end
        f.previousHealth = nil
    end)
    self:SetScript("OnEvent", function(f, event, unit)
        if event:sub(1, 5) ~= "UNIT_" or (unit and UnitIsUnit(unit, "player")) then UpdateHealth(f) end
    end)
    self:SetScript("OnUpdate", function(f, elapsed)
        f.elapsed = (f.elapsed or 0) + elapsed
        if f.elapsed >= 0.1 then f.elapsed = 0; UpdateHealth(f) end
        local loss = f.PlayerFrameHealthBarAnimatedLoss
        if loss and loss.animationStartTime then loss:UpdateLossAnimation(UnitHealth("player")) end
    end)
    return self
end

function module:HideMinimalPlayerHealth()
    RestoreGroupBorder()
    if frame then frame:Hide() end
end

function module:RefreshMinimalPlayerHealth(container)
    container = container or CompactRaidFrameContainer
    local classicPreview = self.testCount and self.defaultPartyPreview
        and self.defaultPartyPreview:IsShown() and self.defaultPartyPreview
    if classicPreview then container = classicPreview end
    if not Enabled() or not container or not container:IsShown()
        or (not self.testCount and (GetNumRaidMembers() or 0) <= 1 and (GetNumPartyMembers() or 0) == 0) then
        self:HideMinimalPlayerHealth()
        return
    end
    local anchor, member
    if classicPreview then
        member = self.defaultPartySamples and self.defaultPartySamples[1]
        anchor = member
    end
    for _, object in ipairs(container.flowFrames or {}) do
        if type(object) == "table" then
            if object.healthBar and (object.unit or object._suiTestData) then
                anchor, member = object, object
            elseif object.GetName and object:GetName() then
                local first = _G[object:GetName() .. "Member1"]
                if first and (first.unit or first._suiTestData) then anchor, member = object, first end
            end
            if member then break end
        end
    end
    if not member then self:HideMinimalPlayerHealth(); return end
    if not frame then frame = Create(container)
    elseif frame:GetParent() ~= container then frame:SetParent(container) end
    frame:ClearAllPoints()
    if classicPreview then
        frame:SetPoint("BOTTOMLEFT", member, "TOPLEFT", 0, 0)
    else
        -- The flow layout reserves this header's height before placing members.
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    end
    RestoreGroupBorder()
    if anchor ~= member and anchor.borderFrame then
        extendedBorder, borderMember = anchor.borderFrame, member
        extendedBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 5)
    end
    frame:SetSize(member:GetWidth(), member:GetHeight() / 2)
    frame:Show()
    UpdateHealth(frame)
    if self.testModeLabel and self.testCount then
        self.testModeLabel:ClearAllPoints()
        self.testModeLabel:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 10)
    end
    return frame
end

function module:GetMinimalPlayerLayoutTop(fallback)
    return frame and frame:IsShown() and frame or fallback
end

hooksecurefunc("CompactRaidFrameContainer_UpdateBorder", function(container)
    module:RefreshMinimalPlayerHealth(container)
end)
if CompactRaidFrameContainer then
    CompactRaidFrameContainer.flowHeaderFunc = function(container)
        return module:RefreshMinimalPlayerHealth(container)
    end
    CompactRaidFrameContainer:HookScript("OnShow", function(container) module:RefreshMinimalPlayerHealth(container) end)
end
