-- Visual test on the actual CompactRaidFrameContainer and CompactUnitFrameTemplate.
-- Slot one is the player's real unit; the remaining slots are visual samples.
local module = SarychUI.modules.group_frames
if not module then return end

local samples = {
    { SarychUI:T("ui.options_4c5f0585f4"), "WARRIOR", "RAGE" }, { SarychUI:T("ui.options_3aece036e2"), "DRUID", "MANA" },
    { SarychUI:T("ui.options_b9a2d8a9c3"), "MAGE", "MANA" }, { SarychUI:T("ui.options_ddbc81acaf"), "PALADIN", "MANA" },
    { SarychUI:T("ui.options_047fc6fcde"), "ROGUE", "ENERGY" }, { SarychUI:T("ui.options_a7c3a865fc"), "SHAMAN", "MANA" },
    { SarychUI:T("ui.options_c690f9f1ef"), "HUNTER", "MANA" }, { SarychUI:T("ui.options_a0ec787cf6"), "WARLOCK", "MANA" },
    { SarychUI:T("ui.options_41ef8737e1"), "DEATHKNIGHT", "RUNIC_POWER" },
    { SarychUI:T("ui.options_73b4a59c4e"), "PRIEST", "MANA" },
}
local sampleRoles = { "TANK", "HEALER", "DAMAGER", "HEALER", "DAMAGER",
    "HEALER", "DAMAGER", "DAMAGER", "TANK", "HEALER" }
-- Keep one roster for the whole preview session, including cooldown samples.
-- Shuffle each full class set independently so raid groups do not repeat a pattern.
local testSamples = {}
local function RandomizeTestSamples(count)
    testSamples = {}
    local bag = {}
    for index = 2, count do
        if #bag == 0 then
            for sampleIndex = 1, #samples do bag[sampleIndex] = sampleIndex end
            for i = #bag, 2, -1 do
                local j = math.random(i)
                bag[i], bag[j] = bag[j], bag[i]
            end
        end
        testSamples[index] = table.remove(bag)
    end
end
local function TestSample(index)
    local sampleIndex = testSamples[index] or ((index - 2) % #samples) + 1
    return samples[sampleIndex], sampleRoles[sampleIndex]
end

local defaultPortraits = {
    "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human",
    "Interface\\CharacterFrame\\TemporaryPortrait-Male-NightElf",
    "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human",
    "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human",
}

local function ShowTestModeLabel(anchor)
    if module.GetMinimalPlayerLayoutTop then anchor = module:GetMinimalPlayerLayoutTop(anchor) end
    if not anchor then
        if module.testModeLabel then module.testModeLabel:Hide() end
        return
    end
    local label = module.testModeLabel
    if not label then
        label = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetFont([[Interface\AddOns\SarychUI\media\fonts\Homespun.ttf]], 12, "")
        label:SetTextColor(0.2, 1.0, 0.35, 0.95)
        label:SetText(SarychUI:T("ui.options_78147b12c1"))
        module.testModeLabel = label
    end
    label:ClearAllPoints()
    label:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 10)
    label:Show()
end

function module:GetCooldownPreviewFrames(contexts)
    if not self.testCount then return end
    local result = {}
    contexts = contexts or {}
    local classic = self.defaultPartyPreview and self.defaultPartyPreview:IsShown()
    local raidPreview = not classic and self.testCount > 5 and contexts.raid ~= false
    local partyPreview = contexts.group ~= false or contexts.arena ~= false
    for _, frame in pairs(classic and self.defaultPartySamples or self.testFrames or {}) do
        local index = frame._suiTestIndex
        if index and (raidPreview or (partyPreview and index <= 5)) and frame:IsVisible() then
            local sample = TestSample(index)
            local key = index == 1 and UnitGUID("player") or "sui:group-test:" .. index
            result[key] = {
                token = "player", class = index == 1 and select(2, UnitClass("player")) or sample[2],
                race = index == 1 and select(2, UnitRace("player")) or "Human", test = index ~= 1, player = index == 1,
                frame = frame, kind = classic and "blizzard" or "compact",
            }
        end
    end
    return result
end

local function RefreshCooldowns()
    local tracker = SarychUI.extensions and SarychUI.extensions.party_abilities
    if tracker and tracker.RefreshGroupFrames then tracker:RefreshGroupFrames() end
end

local function CreateDefaultPartySample(parent, index)
    local frame = CreateFrame("Frame", "SarychUIDefaultPartyTest" .. index, parent)
    frame.unit = "player"
    frame._suiDefaultPartyPreview = true
    frame._suiTestIndex = index + 1
    frame._suiTestData = { myHeal = 0, allHeal = 0, absorb = 0, healAbsorb = 0 }
    frame:SetSize(128, 53)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * 53)
    frame:EnableMouse(false)
    local shade = frame:CreateTexture(nil, "BACKGROUND")
    shade:SetTexture("Interface\\Buttons\\WHITE8X8")
    shade:SetVertexColor(0, 0, 0, 0.5)
    shade:SetSize(72, 20)
    shade:SetPoint("TOPLEFT", frame, "TOPLEFT", 45, -11)
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetTexture(defaultPortraits[index])
    portrait:SetSize(37, 37)
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -6)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    health:SetMinMaxValues(0, 100)
    health:SetValue(index == 4 and 100 or 78)
    health:SetSize(70, 8)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 47, -12)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    power:SetMinMaxValues(0, 100)
    power:SetValue(75)
    power:SetSize(70, 8)
    power:SetPoint("TOPLEFT", frame, "TOPLEFT", 47, -21)
    local chrome = CreateFrame("Frame", nil, frame)
    chrome:SetAllPoints(frame)
    chrome:SetFrameLevel(math.max(health:GetFrameLevel(), power:GetFrameLevel()) + 1)
    chrome:EnableMouse(false)
    local art = chrome:CreateTexture(nil, "ARTWORK")
    art:SetTexture("Interface\\TargetingFrame\\UI-PartyFrame")
    art:SetSize(128, 64)
    art:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
    local name = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 50, 43)
    name:SetWidth(68)
    name:SetJustifyH("LEFT")
    name:SetText((TestSample(index + 1))[1])
    local statusText = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("RIGHT", health, "RIGHT", -2, 0)
    frame.healthBar, frame.healthbar = health, health
    frame.powerBar = power
    frame.background = shade
    frame.name = name
    frame.statusText = statusText
    frame.uflSkipColor = true
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[(TestSample(index + 1))[2]]
    SarychUI.UnitFrameLayers:SetBarColor(frame, health,
        classColor and classColor.r or 0, classColor and classColor.g or 0.85,
        classColor and classColor.b or 0)
    SarychUI.UnitFrameLayers:SetBarColor(frame, power, 0, 0.35, 1)
    return frame
end

local function RefreshDefaultPartyLayers(frame)
    local enabled = SarychUI.UnitFrameLayers:IsEnabled()
    if enabled and not frame.myHealPredictionBar and UnitFrameLayers_AttachHealPrediction then
        UnitFrameLayers_AttachHealPrediction(frame, true, true)
    end
    if frame.myHealPredictionBar and UnitFrameLayers_SetHealPredictionEnabled then
        UnitFrameLayers_SetHealPredictionEnabled(frame, enabled)
    end
    if enabled and UnitFrameLayers_UpdateHealPrediction then
        UnitFrameLayers_UpdateHealPrediction(frame)
    end
    frame._suiTestLayersEnabled = enabled
end

function module:ShowDefaultPartyPreview()
    if GetNumPartyMembers() > 0 then
        self:HideDefaultPartyPreview()
        return
    end
    local host = self.defaultPartyPreview
    if not host then
        host = CreateFrame("Frame", "SarychUIDefaultPartyPreview", UIParent)
        if PartyMemberFrame1 then
            host:SetPoint("TOPLEFT", PartyMemberFrame1, "TOPLEFT", 0, 0)
        else
            host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -160)
        end
        host:SetSize(128, 4 * 53)
        self.defaultPartyPreview = host
        self.defaultPartySamples = {}
        for index = 1, 4 do
            self.defaultPartySamples[index] = CreateDefaultPartySample(host, index)
        end
    end
    local visible = math.min(4, math.max(1, (self.testCount or 2) - 1))
    for index, frame in ipairs(self.defaultPartySamples) do
        SarychUI.Compat.Widgets.SetShown(frame, index <= visible)
        if index <= visible then
            local sample = TestSample(index + 1)
            frame.name:SetText(sample[1])
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[sample[2]]
            SarychUI.UnitFrameLayers:SetBarColor(frame, frame.healthBar,
                color and color.r or 0, color and color.g or 0.85, color and color.b or 0)
            local power = PowerBarColor and PowerBarColor[sample[3]]
            SarychUI.UnitFrameLayers:SetBarColor(frame, frame.powerBar,
                power and power.r or 0, power and power.g or 0.35, power and power.b or 1)
            RefreshDefaultPartyLayers(frame)
        end
    end
    host:Show()
    for index = 1, visible do self:ApplyDistanceToFrame(self.defaultPartySamples[index]) end
end

function module:HideDefaultPartyPreview()
    if not self.defaultPartyPreview then return end
    self.defaultPartyPreview:Hide()
    for _, frame in ipairs(self.defaultPartySamples or {}) do
        if SarychUI.UnitFrameRange then SarychUI.UnitFrameRange:Unregister(frame) end
        if frame.myHealPredictionBar and UnitFrameLayers_SetHealPredictionEnabled then
            UnitFrameLayers_SetHealPredictionEnabled(frame, false)
        end
        if frame._suiTestLoss then frame._suiTestLoss:Hide() end
        frame._suiTestPhase = nil
    end
end

local roleOrder = { MAINTANK = 1, MAINASSIST = 2, TANK = 3,
    HEALER = 4, DAMAGER = 5, NONE = 6 }

local function TestOrder(count, mode)
    local entries = {}
    for index = 1, count do
        if index == 1 then
            entries[index] = { sourceIndex = index, player = true,
                name = UnitName("player") or SarychUI:T("ui.player_f54f58cf"),
                role = SarychUI.Compat.UnitGroupRoles and SarychUI.Compat.UnitGroupRoles("player") or "NONE" }
        else
            local sample, role = TestSample(index)
            entries[index] = { sourceIndex = index, name = sample[1], role = role }
        end
    end
    local db = SarychUI.db and SarychUI.db.profile.modules.group_frames
    local custom = db and db.sortOrder or "NONE"
    if custom == "HIDE" or custom == "MINIMAL_TOP" then table.remove(entries, 1) end
    if mode == "discrete" then return entries end
    local profile = GetActiveRaidProfile and GetActiveRaidProfile()
    local sortBy = profile and GetRaidProfileOption(profile, "sortBy") or "group"
    if custom == "ASC" or custom == "DESC" then
        table.sort(entries, function(a, b)
            if a.player then return custom == "DESC" end
            if b.player then return custom == "ASC" end
            if custom == "ASC" then return a.sourceIndex > b.sourceIndex end
            return a.sourceIndex < b.sourceIndex
        end)
    elseif sortBy == "alphabetical" or sortBy == "role" then
        table.sort(entries, function(a, b)
            if sortBy == "role" then
                local ar, br = roleOrder[a.role] or 6, roleOrder[b.role] or 6
                if ar ~= br then return ar < br end
            end
            if a.name ~= b.name then return a.name < b.name end
            return a.sourceIndex < b.sourceIndex
        end)
    end
    return entries
end
local sampleBuffs = SarychUI.Data.GroupAuras.previewBuffs
local sampleDebuffs = SarychUI.Data.GroupAuras.previewDebuffs

-- Repeat distinct layer and range states across all sample units.
local SHOWCASE_PHASE_SECONDS = 2
local SHOWCASE_PHASE_COUNT = 6
local SHOWCASE_HEALTH = { 78, 72, 82, 64 }
local function TestScenario(index)
    return index and index > 1 and index ~= 5 and ((index - 2) % 4) + 1 or nil
end

local function SetTestHealth(frame, health)
    frame.healthBar:SetValue(health)
    if frame._suiDefaultPartyPreview then
        frame.statusText:SetText("")
        frame.statusText:Hide()
        return
    end
    local rounded = math.floor(health + 0.5)
    local mode = DefaultCompactUnitFrameOptions.healthText
    if mode == "perc" then frame.statusText:SetText(rounded .. "%")
    elseif mode == "health" then frame.statusText:SetText(rounded .. " / 100")
    elseif mode == "losthealth" then frame.statusText:SetText("-" .. (100 - rounded))
    else frame.statusText:SetText("") end
    SarychUI.Compat.Widgets.SetShown(frame.statusText, mode ~= "none")
end

local function UpdateTestLoss(frame, now)
    local loss = frame._suiTestLoss
    if not loss then
        loss = frame.healthBar:CreateTexture(nil, "OVERLAY")
        loss:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        loss:SetVertexColor(1, 0.15, 0.12, 0.9)
        frame._suiTestLoss = loss
        SarychUI.UnitFrameLayers:TrackRangeTexture(frame, loss)
    end
    local start = frame._suiTestLossStart
    local elapsed = start and now - start or 2
    local width = frame.healthBar:GetWidth()
    local _, maximum = frame.healthBar:GetMinMaxValues()
    local current = maximum > 0 and frame.healthBar:GetValue() / maximum or 1
    if elapsed >= 1 or width <= 0 or current >= 1 then
        loss:Hide()
        return
    end
    local previous = (frame._suiTestLossPrevious or 100) / maximum
    local left = width * current
    local right = width * (previous - (previous - current) * math.max(0, elapsed))
    loss:ClearAllPoints()
    loss:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", left, 0)
    loss:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMLEFT", left, 0)
    loss:SetWidth(math.max(0.1, right - left))
    loss:Show()
end

local function UpdateTestShowcase(frame, phase, progress, now)
    local data = frame._suiTestData
    if not data then return end
    local scenario = TestScenario(frame._suiTestIndex)
    if not scenario then return end
    local changed = frame._suiTestPhase ~= phase
    if changed then
        frame._suiTestPhase = phase
        if scenario == 1 and phase == 1 then
            frame._suiTestLossPrevious = frame.healthBar:GetValue()
            frame._suiTestLossStart = now
        elseif frame._suiTestLoss then
            frame._suiTestLoss:Hide()
        end
    end
    data.myHeal, data.allHeal, data.absorb, data.healAbsorb = 0, 0, 0, 0
    local health = 78
    local animated = false
    if scenario == 1 then -- damage, recovery and incoming healing
        if phase == 1 then
            health = 55
        elseif phase == 2 then
            health = 55 + 35 * progress
            data.myHeal = 0.12 * (1 - progress)
            data.allHeal = 0.35 * (1 - progress)
            animated = true
        elseif phase == 3 then
            health = 95 + 5 * progress
            data.myHeal, data.allHeal = 0.18, 0.18
            animated = true
        elseif phase == 4 then
            health = 70
        elseif phase == 5 then
            health = 70 + 8 * progress
            data.myHeal, data.allHeal = 0.08, 0.15
            animated = true
        end
    elseif scenario == 2 then -- shield fill, tiled overlay and overflow glow
        health = 72
        data.absorb = 0.40
    elseif scenario == 3 then -- a distant ally
        health = 82
    else
        -- Heal absorb, incoming healing and overheal on the same unit.
        health = 64
        data.healAbsorb = 0.23
        if phase == 2 then
            health = 64 + 24 * progress
            data.healAbsorb = 0.18 * (1 - progress)
            data.myHeal = 0.12 * (1 - progress)
            data.allHeal = 0.24 * (1 - progress)
            animated = true
        elseif phase == 3 then
            health = 94 + 6 * progress
            data.healAbsorb = 0
            data.myHeal, data.allHeal = 0.12, 0.20
            animated = true
        elseif phase == 4 then
            health = 70
            data.healAbsorb, data.allHeal = 0.25, 0.04
        end
    end
    local outside = scenario == 3
    if frame._suiTestOutside ~= outside then
        frame._suiTestOutside = outside
        if SarychUI.UnitFrameRange then SarychUI.UnitFrameRange:Update(frame) end
    end
    if frame.healthBar:GetValue() ~= health then SetTestHealth(frame, health) end
    if changed or animated then
        if frame._suiDefaultPartyPreview then
            if UnitFrameLayers_UpdateHealPrediction then UnitFrameLayers_UpdateHealPrediction(frame) end
        else
            CompactUnitFrame_UpdateHealPrediction(frame)
        end
    end
    if scenario == 1 and phase == 1 and SarychUI.UnitFrameLayers:IsEnabled() then
        UpdateTestLoss(frame, now)
    end
end

function module:PaintTestAuras(frame)
    if not frame or not frame._suiTestData then return end
    if not frame._suiTestIndex or frame._suiTestIndex == 5 then
        CompactUnitFrame_HideAllBuffs(frame)
        CompactUnitFrame_HideAllDebuffs(frame)
        return
    end
    local now = GetTime()
    local variant = frame._suiAuraVariant or 1
    local buffA = sampleBuffs[((variant - 1) % #sampleBuffs) + 1]
    local buffB = sampleBuffs[(variant % #sampleBuffs) + 1]
    local debuffA = sampleDebuffs[((variant - 1) % #sampleDebuffs) + 1]
    local debuffB = sampleDebuffs[(variant % #sampleDebuffs) + 1]
    if frame.optionTable.displayOnlyDispellableDebuffs and debuffA[3] ~= "Magic" then
        debuffA = sampleDebuffs[1]
    end
    local buffs = frame.buffFrames or {}
    local debuffs = frame.debuffFrames or {}
    if frame.optionTable.displayBuffs then
        if buffs[1] then
            buffs[1]:EnableMouse(false)
            CompactUnitFrame_UtilSetBuff(buffs[1], 1, buffA[1], buffA[2], 1,
                nil, 22, now + 22, "player", false, nil, buffA[3], true)
        end
        if buffs[2] then
            buffs[2]:EnableMouse(false)
            CompactUnitFrame_UtilSetBuff(buffs[2], 2, buffB[1], buffB[2], 2,
                nil, 14, now + 14, "player", false, nil, buffB[3], true)
        end
        if buffs[3] then buffs[3]:Hide() end
    else
        CompactUnitFrame_HideAllBuffs(frame)
    end
    if frame.optionTable.displayDebuffs then
        if debuffs[1] then
            debuffs[1]:EnableMouse(false)
            CompactUnitFrame_UtilSetDebuff(debuffs[1], nil, 1, "HARMFUL",
                not frame.optionTable.displayNonBossDebuffs, false,
                debuffA[1], debuffA[2], 1, debuffA[3], 18, now + 18, "player", false, nil, debuffA[4])
        end
        if debuffs[2] and frame.optionTable.displayNonBossDebuffs
            and not frame.optionTable.displayOnlyDispellableDebuffs then
            debuffs[2]:EnableMouse(false)
            CompactUnitFrame_UtilSetDebuff(debuffs[2], nil, 2, "HARMFUL", false, false,
                debuffB[1], debuffB[2], 2, debuffB[3], 12, now + 12, "player", false, nil, debuffB[4])
        elseif debuffs[2] then debuffs[2]:Hide() end
        if debuffs[3] then debuffs[3]:Hide() end
    else
        CompactUnitFrame_HideAllDebuffs(frame)
    end
end

local function PaintSample(frame, index)
    local sample = TestSample(index)
    local scenario = TestScenario(index)
    local health = scenario and SHOWCASE_HEALTH[scenario] or 100
    frame._suiTestOutside = scenario == 3
    local color = DefaultCompactUnitFrameOptions.useClassColors and RAID_CLASS_COLORS
        and RAID_CLASS_COLORS[sample[2]]
    frame.healthBar:SetMinMaxValues(0, 100)
    SetTestHealth(frame, health)
    SarychUI.UnitFrameLayers:SetBarColor(frame, frame.healthBar, color and color.r or 0, color and color.g or 0.8,
        color and color.b or 0)
    frame.name:SetText(sample[1])
    frame.name:Show()
    if frame.powerBar and DefaultCompactUnitFrameSetupOptions.displayPowerBar then
        local power = 25 + (index * 13) % 70
        frame.powerBar:SetMinMaxValues(0, 100)
        frame.powerBar:SetValue(power)
        local powerColor = PowerBarColor and PowerBarColor[sample[3]]
        SarychUI.UnitFrameLayers:SetBarColor(frame, frame.powerBar, powerColor and powerColor.r or 0,
            powerColor and powerColor.g or 0.5, powerColor and powerColor.b or 1)
    end
    frame.roleIcon:Hide()
    frame.aggroHighlight:Hide()
    frame.ignoreParentAlpha.selectionHighlight:Hide()
    CompactUnitFrame_UpdateRaidTargetIcon(frame)
    module:PaintTestAuras(frame)
    CompactUnitFrame_UpdateHealPrediction(frame)
    frame._suiTestLayersDirty = true
end

local function DeactivateTestFrame(frame)
    if not frame then return end
    if SarychUI.UnitFrameRange then SarychUI.UnitFrameRange:Unregister(frame) end
    if not frame._suiTestData and frame.unit ~= "player" then
        frame:Hide()
        return
    end
    frame._suiTestData = nil
    frame._suiTestLayersDirty = nil
    frame._suiTestPredictionWidth = nil
    frame._suiTestLayersEnabled = nil
    frame._suiTestLossStart = nil
    frame._suiTestLossPrevious = nil
    frame._suiTestPhase = nil
    frame._suiTestOutside = nil
    if frame._suiTestLoss then frame._suiTestLoss:Hide() end
    frame:Hide()
    if frame.unit == "player" then
        if SarychUI.UnitFrameLayers then SarychUI.UnitFrameLayers:Unregister(frame) end
        frame._suiLayerUpdater = nil
        CompactUnitFrame_SetUnit(frame, nil)
        frame:UnregisterAllEvents()
    end
end

local function EnsureFlatFrame(pool, index, container)
    if not pool[index] then
        local frame = CreateFrame("Button", "CompactRaidFrameTest" .. index, container,
            "CompactUnitFrameTemplate")
        frame:UnregisterAllEvents()
        frame:SetScript("OnUpdate", nil)
        pool[index] = frame
    end
    return pool[index]
end

local function EnsurePetFrame(pool, index, container)
    if not pool[index] then
        local frame = CreateFrame("Button", "SarychUICompactRaidPetTest" .. index, container,
            "CompactUnitFrameTemplate")
        frame:UnregisterAllEvents()
        frame:SetScript("OnUpdate", nil)
        pool[index] = frame
    end
    return pool[index]
end

local function PaintPet(frame, index)
    frame._suiTestData = { myHeal = 0, allHeal = 0, absorb = 0, healAbsorb = 0 }
    frame._suiTestIndex = nil
    frame._suiTestOutside = false
    DefaultCompactMiniFrameSetup(frame)
    frame.healthBar:SetMinMaxValues(0, 100)
    SetTestHealth(frame, 100)
    SarychUI.UnitFrameLayers:SetBarColor(frame, frame.healthBar, 0.25, 0.75, 0.35)
    CompactUnitFrame_UpdateHealPrediction(frame)
    frame.name:SetText(SarychUI:T("ui.options_0c0cd4d7e2") .. index)
    frame.name:Show()
    frame.statusText:Hide()
    frame.roleIcon:Hide()
    frame.aggroHighlight:Hide()
    frame.ignoreParentAlpha.selectionHighlight:Hide()
    frame:EnableMouse(false)
    frame:Show()
end

local function EnsureTestGroup(pool, index, container)
    local group = pool[index]
    if group then return group end
    group = CreateFrame("Frame", "SarychUICompactRaidGroupTest" .. index, container,
        "CompactRaidGroupTemplate")
    group:UnregisterAllEvents()
    group.title:SetFormattedText(GROUP_NUMBER, index)
    for member = 1, 5 do
        local frame = _G[group:GetName() .. "Member" .. member]
        frame:UnregisterAllEvents()
        frame:SetScript("OnUpdate", nil)
        frame:EnableMouse(false)
        frame:Hide()
    end
    pool[index] = group
    return group
end

function module:LayoutTestFrames(container)
    if InCombatLockdown() then self.pendingTest = true; return end
    if not self.testFlowState then
        self.testFlowState = {
            maxPerLine = container.flowMaxPerLine,
            orientation = container.flowOrientation,
            maxPerLineOnly = container.flowMaxPerLineOnly,
        }
    end
    for i = 1, #container.flowFrames do
        local frame = container.flowFrames[i]
        if type(frame) == "table" and frame.unusedFunc then frame:unusedFunc() end
    end
    FlowContainer_RemoveAllObjects(container)
    CompactRaidFrameContainer_ReleaseAllReservedFrames(container)

    local manager = CompactRaidFrameManager
    local autoSize = not manager or manager.dynamicContainerPosition ~= false
    local mode = container.groupMode == "discrete" and "discrete" or "flush"
    if self.testLayoutMode and self.testLayoutMode ~= mode then
        for _, frame in pairs(self.testFrames or {}) do DeactivateTestFrame(frame) end
    end
    self.testLayoutMode = mode
    self.testFlatFrames = self.testFlatFrames or {}
    self.testGroupFrames = self.testGroupFrames or {}
    self.testPetFrames = self.testPetFrames or {}
    self.testGroups = self.testGroups or {}
    local pool = mode == "discrete" and self.testGroupFrames or self.testFlatFrames
    self.testFrames = pool
    for _, group in ipairs(self.testGroups) do group:Hide() end

    local count = self.testCount or 0
    local petCount = container.displayPets and math.ceil(count / 5) or 0
    local ordered = TestOrder(count, mode)
    count = #ordered
    local width = DefaultCompactUnitFrameSetupOptions.width or 72
    local height = DefaultCompactUnitFrameSetupOptions.height or 36
    local groupCount = math.ceil(count / 5)
    FlowContainer_PauseUpdates(container)
    -- Reuse the original buttons. Only the visible members and the five
    -- members needed by the native group border are touched on each layout.
    local lastSlot = math.max(#pool, mode == "discrete" and groupCount * 5 or count)
    for i = 1, lastSlot do
        local frame
        if mode == "discrete" then
            if i <= groupCount * 5 then
                local groupIndex = math.ceil(i / 5)
                local group = EnsureTestGroup(self.testGroups, groupIndex, container)
                frame = _G[group:GetName() .. "Member" .. (((i - 1) % 5) + 1)]
                pool[i] = frame
            else frame = pool[i] end
        elseif i <= count then
            frame = EnsureFlatFrame(pool, i, container)
        else frame = pool[i] end

        if frame and i <= count then
            local entry = ordered[i]
            frame._suiTestIndex = entry.sourceIndex
            if frame._suiTestSourceIndex ~= entry.sourceIndex then
                frame._suiAuraVariant = ((math.random(1, #sampleBuffs) + entry.sourceIndex - 2)
                    % #sampleBuffs) + 1
                frame._suiTestSourceIndex = entry.sourceIndex
            end
            -- The player uses the normal unit pipeline, including live aura
            -- callbacks and healing layers. Only sample allies carry fake data.
            if entry.player then frame._suiTestData = nil
            else frame._suiTestData = { myHeal = 0, allHeal = 0, absorb = 0, healAbsorb = 0 } end
            frame._suiTestLayersDirty = true
            frame._suiTestLossStart = nil
            frame._suiTestLossPrevious = nil
            frame._suiTestPhase = nil
            frame._suiTestOutside = nil
            if frame._suiTestLoss then frame._suiTestLoss:Hide() end
            if not entry.player and frame.unit == "player" then
                if SarychUI.UnitFrameLayers then SarychUI.UnitFrameLayers:Unregister(frame) end
                frame._suiLayerUpdater = nil
                CompactUnitFrame_SetUnit(frame, nil)
                frame:UnregisterAllEvents()
            end
            DefaultCompactUnitFrameSetup(frame)
            frame:EnableMouse(entry.player)
            if entry.player then
                if frame.unit ~= "player" then CompactUnitFrame_SetUnit(frame, "player") end
                CompactUnitFrame_RegisterEvents(frame)
                for _, buttons in ipairs({frame.buffFrames or {}, frame.debuffFrames or {}}) do
                    for _, button in ipairs(buttons) do button:EnableMouse(true) end
                end
                frame:RegisterEvent("PLAYER_TARGET_CHANGED")
                frame:RegisterEvent("RAID_TARGET_UPDATE")
                CompactUnitFrame_UpdateAll(frame)
                local layers = SarychUI.UnitFrameLayers
                if layers and layers.RegisterExternal then
                    layers:RegisterExternal(frame, "player", CompactUnitFrame_UpdateHealPrediction)
                end
            else PaintSample(frame, entry.sourceIndex) end
            frame:Show()
            module:ApplyDistanceToFrame(frame)
            if mode == "flush" then
                FlowContainer_AddObject(container, frame)
                if container.displayPets and (i % 5 == 0 or i == count) then
                    local petIndex = math.ceil(i / 5)
                    local pet = EnsurePetFrame(self.testPetFrames, petIndex, container)
                    PaintPet(pet, petIndex)
                    FlowContainer_AddObject(container, pet)
                    module:ApplyDistanceToFrame(pet)
                end
            end
        elseif frame then
            DeactivateTestFrame(frame)
            if mode == "discrete" and i <= groupCount * 5 then
                -- The stock border anchors to member five, including when
                -- only two or three sample players are shown.
                DefaultCompactUnitFrameSetup(frame)
            end
        end
    end

    if mode == "discrete" then
        container.flowMaxPerLineOnly = nil
        FlowContainer_SetMaxPerLine(container, nil)
        for groupIndex = 1, groupCount do
            local group = self.testGroups[groupIndex]
            group.title:SetFormattedText(GROUP_NUMBER, groupIndex)
            CompactRaidGroup_UpdateBorder(group)
            group:Show()
            FlowContainer_AddObject(container, group)
        end
        local first = self.testGroups[1]
        local groupWidth = first and first:GetWidth() or width
        local groupHeight = first and first:GetHeight() or height * 5 + 14
        if autoSize then
            if CUF_HORIZONTAL_GROUPS then
                container:SetSize(groupWidth, groupHeight * groupCount
                    + petCount * (DefaultCompactMiniFrameSetUpOptions.height or 18))
            else
                container:SetSize(groupWidth * groupCount
                    + petCount * (DefaultCompactMiniFrameSetUpOptions.width or width), groupHeight)
            end
        end
        FlowContainer_SetOrientation(container, "+")
    else
        local rows = math.min(5, count)
        local columns = math.ceil(count / 5)
        local petHeight = petCount > 0 and (DefaultCompactMiniFrameSetUpOptions.height or 18) or 0
        -- Use the native pixel-based wrapping, including while the resizer is dragged.
        container.flowMaxPerLineOnly = nil
        FlowContainer_SetMaxPerLine(container, nil)
        if autoSize then
            container:SetSize(width * columns, height * rows + petHeight)
        end
        FlowContainer_SetOrientation(container, "vertical")
    end
    for index = 1, math.max(#self.testPetFrames, petCount) do
        local frame = self.testPetFrames[index]
        if mode == "discrete" and index <= petCount then
            frame = EnsurePetFrame(self.testPetFrames, index, container)
            PaintPet(frame, index)
            FlowContainer_AddObject(container, frame)
            module:ApplyDistanceToFrame(frame)
        elseif index > petCount and frame then
            DeactivateTestFrame(frame)
        end
    end
    local header = self.RefreshMinimalPlayerHealth and self:RefreshMinimalPlayerHealth(container)
    if autoSize and header then container:SetHeight(container:GetHeight() + header:GetHeight()) end
    FlowContainer_ResumeUpdates(container)
    CompactRaidFrameContainer_UpdateBorder(container)
    if self.RefreshMinimalPlayerHealth then self:RefreshMinimalPlayerHealth(container) end
end

local auraTicker = CreateFrame("Frame")
auraTicker.elapsed = 0
auraTicker:SetScript("OnUpdate", function(self, elapsed)
    if not module.testCount then self:Hide(); return end
    local now = GetTime()
    local layersEnabled = SarychUI.UnitFrameLayers:IsEnabled()
    self.showcaseElapsed = (self.showcaseElapsed or 0) + (elapsed or 0)
    self.showcaseTick = (self.showcaseTick or 0) + (elapsed or 0)
    if self.showcaseTick >= 0.05 then
        self.showcaseTick = 0
        local position = self.showcaseElapsed % (SHOWCASE_PHASE_SECONDS * SHOWCASE_PHASE_COUNT)
        local phase = math.floor(position / SHOWCASE_PHASE_SECONDS)
        local progress = (position % SHOWCASE_PHASE_SECONDS) / SHOWCASE_PHASE_SECONDS
        for _, frame in pairs(module.testFrames or {}) do
            if frame._suiTestData and frame:IsShown() and frame._suiTestIndex then
                if not layersEnabled and frame._suiTestLoss then frame._suiTestLoss:Hide() end
                UpdateTestShowcase(frame, phase, progress, now)
            end
        end
        if module.defaultPartyPreview and module.defaultPartyPreview:IsShown() then
            for _, frame in ipairs(module.defaultPartySamples or {}) do
                if frame:IsShown() then
                    if not layersEnabled and frame._suiTestLoss then frame._suiTestLoss:Hide() end
                    UpdateTestShowcase(frame, phase, progress, now)
                end
            end
        end
    end
    self.elapsed = self.elapsed + (elapsed or 0)
    self.layerElapsed = (self.layerElapsed or 0) + (elapsed or 0)
    if self.layerElapsed >= 0.15 then
        self.layerElapsed = 0
        for _, frame in pairs(module.testFrames or {}) do
            if frame._suiTestData and frame:IsShown() then
                local width = frame.healthBar:GetWidth()
                if frame._suiTestLayersDirty or frame._suiTestPredictionWidth ~= width
                    or frame._suiTestLayersEnabled ~= layersEnabled then
                    frame._suiTestLayersDirty = nil
                    frame._suiTestPredictionWidth = width
                    frame._suiTestLayersEnabled = layersEnabled
                    CompactUnitFrame_UpdateHealPrediction(frame)
                end
            end
        end
        if module.defaultPartyPreview and module.defaultPartyPreview:IsShown() then
            for _, frame in ipairs(module.defaultPartySamples or {}) do
                if frame:IsShown() and frame._suiTestLayersEnabled ~= layersEnabled then
                    RefreshDefaultPartyLayers(frame)
                end
            end
        end
    end
    if self.elapsed < 7 then return end
    self.elapsed = 0
    for _, frame in pairs(module.testFrames or {}) do
        if frame._suiTestData and frame:IsShown() and frame._suiTestIndex ~= 5 then
            local previous = frame._suiAuraVariant or 1
            frame._suiAuraVariant = ((previous + math.random(1, #sampleBuffs - 1) - 1)
                % #sampleBuffs) + 1
            module:PaintTestAuras(frame)
        end
    end
end)
auraTicker:Hide()

function module:HideTest()
    if not self.testCount then return end
    if InCombatLockdown() then self.pendingTestHide = true; return end
    self:HideDefaultPartyPreview()
    if self.HideMinimalPlayerHealth then self:HideMinimalPlayerHealth() end
    if self.testModeLabel then self.testModeLabel:Hide() end
    self.testCount = nil
    self.testContainerShown = nil
    auraTicker:Hide()
    for _, frame in pairs(self.testFlatFrames or {}) do DeactivateTestFrame(frame) end
    for _, frame in pairs(self.testGroupFrames or {}) do DeactivateTestFrame(frame) end
    for _, frame in pairs(self.testPetFrames or {}) do DeactivateTestFrame(frame) end
    for _, group in ipairs(self.testGroups or {}) do group:Hide() end
    local manager = CompactRaidFrameManager
    if manager then
        local container = manager.container
        FlowContainer_RemoveAllObjects(container)
        if self.testFlowState then
            container.flowMaxPerLineOnly = self.testFlowState.maxPerLineOnly
            FlowContainer_SetMaxPerLine(container, self.testFlowState.maxPerLine)
            FlowContainer_SetOrientation(container, self.testFlowState.orientation or "vertical")
            self.testFlowState = nil
        end
        self.testLayoutMode = nil
        local profile = GetActiveRaidProfile and GetActiveRaidProfile()
        if profile then
            CompactRaidFrameManager_SetSetting("IsShown", GetRaidProfileOption(profile, "shown"))
        end
        RegisterStateDriver(manager, "visibility", "[group:party] show; [group:raid] show; [nogroup:party] hide")
        CompactRaidFrameContainer_UpdateDisplayedUnits(container)
        CompactRaidFrameContainer_TryUpdate(container)
        CompactRaidFrameManager_ResizeFrame_LoadPosition(manager)
        CompactRaidFrameManager_UpdateShown(manager)
        CompactRaidFrameManager_UpdateDisplayCounts(manager)
    end
    if SarychUI.NotifySarychUIOptionsChange then SarychUI:NotifySarychUIOptionsChange() end
    self:ApplyQuickControls()
    RefreshCooldowns()
end

function module:RefreshTest()
    if not self.testCount or InCombatLockdown() then return end
    local manager = CompactRaidFrameManager
    if not manager then return end
    if not SarychUI.Compat.IsInRaid() and (not CUF_CVar or not CUF_CVar:GetCVarBool("useCompactPartyFrames")) then
        UnregisterStateDriver(manager, "visibility")
        manager.container:Hide()
        manager:Show()
        if SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames then SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames() end
        self:ShowDefaultPartyPreview()
        if self.RefreshMinimalPlayerHealth then self:RefreshMinimalPlayerHealth() end
        ShowTestModeLabel(self.defaultPartyPreview)
        self:ApplyQuickControls()
    RefreshCooldowns()
        return
    end
    self:HideDefaultPartyPreview()
    UnregisterStateDriver(manager, "visibility")
    manager:Show()
    manager.container:Show()
    if manager.toggleButton then manager.toggleButton:Show() end
    CompactRaidFrameManager_UpdateOptionsFlowContainer(manager)
    CompactRaidFrameManager_UpdateLabel(manager)
    CompactRaidFrameManager_UpdateHeaderInfo(manager)
    CompactRaidFrameContainer_TryUpdate(manager.container)
    CompactRaidFrameManager_UpdateContainerVisibility()
    ShowTestModeLabel(manager.container)
    self:ApplyQuickControls()
    RefreshCooldowns()
end

function module:ToggleTest(count)
    if SarychUI.db.profile.modules.group_frames.enabled == false then return end
    if self.testCount == count then self:HideTest(); return end
    if InCombatLockdown() then self.pendingTestCount = count; return end
    RandomizeTestSamples(math.max(count, 5))
    self.testCount = count
    self.testContainerShown = true
    if CompactRaidFrameManager then
        CompactRaidFrameManager_SetSetting("IsShown", true)
    end
    auraTicker.elapsed = 0
    auraTicker.showcaseElapsed = 0
    auraTicker.showcaseTick = 0
    auraTicker:Show()
    self:RefreshTest()
    if SarychUI.NotifySarychUIOptionsChange then SarychUI:NotifySarychUIOptionsChange() end
end
