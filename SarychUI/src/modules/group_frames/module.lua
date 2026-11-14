-- One SarychUI module owns the compact group-frame engine and its extensions.
local module = {}
SarychUI:RegisterModule("group_frames", module)

local function DB()
    local profile = SarychUI.db and SarychUI.db.profile
    return profile and profile.modules and profile.modules.group_frames
end

function module:IsDispelFilterException(id)
    local db = DB()
    return db and db.enabled ~= false and db.groupDispelExceptions
        and db.groupDispelExceptions[id] == true or false
end

function module:IsAuraBlacklisted(id, filter)
    local db = DB()
    local auras = SarychUI.modules and SarychUI.modules.auras
    if not db or db.enabled == false or not db.auraBlacklistEnabled
        or (auras and auras._showBlacklistedAuras) or not id then return false end
    local key = filter == "HELPFUL" and "groupBuffBlacklist" or "groupDebuffBlacklist"
    local entries = db[key] or {}
    self._auraBlacklistIndexes = self._auraBlacklistIndexes or {}
    local cached = self._auraBlacklistIndexes[key]
    if not cached or cached.entries ~= entries then
        cached = {entries = entries, names = SarychUI.AuraTracking:BuildSpellIndex(entries)}
        self._auraBlacklistIndexes[key] = cached
    end
    return SarychUI.AuraTracking:ResolveSpell(entries, id, cached.names) == true
end

function module:RefreshBlacklistAuras()
    if not DB() or DB().enabled == false then return end
    if CompactRaidFrameContainer and CompactRaidFrameContainer_ApplyToFrames then
        for _, kind in ipairs({"normal", "mini"}) do
            CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, kind, CompactUnitFrame_UpdateAuras)
        end
    end
    -- Preview buttons are separate from the container's registered raid units.
    for _, frame in pairs(self.testFrames or {}) do
        if frame.unit == "player" and not frame._suiTestData and frame:IsShown() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end
end

function module:ApplyAuraBlacklist()
    self._auraBlacklistIndexes = nil
    local auras = SarychUI.modules and SarychUI.modules.auras
    if auras and auras.ApplyBlacklistVisibilitySettings then auras:ApplyBlacklistVisibilitySettings() end
    self:RefreshBlacklistAuras()
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = Copy(child) end
    return out
end

local function RosterSize()
    if SarychUI.Compat.IsInRaid() then return GetNumRaidMembers() end
    return (GetNumPartyMembers() or 0) + 1
end

local function SortUnits(a, b)
    local db = DB()
    local order = db and db.sortOrder or "NONE"
    if not UnitExists(a) then return false end
    if not UnitExists(b) then return true end
    if UnitIsUnit(a, "player") then return order == "DESC" end
    if UnitIsUnit(b, "player") then return order ~= "DESC" end
    if order == "ASC" then return a > b end
    return a < b
end

local function UpdateExistingBars(frame)
    local db = DB()
    if db and db.enabled ~= false then CompactUnitFrame_UpdateHealPrediction(frame) end
end

local function AttachFrameLayers(frame)
    if frame and frame.unit and frame.healthBar then
        SarychUI.UnitFrameLayers:RegisterExternal(frame, frame.unit, UpdateExistingBars)
    end
end

local rangeOptions = {
    owner = "group_frames",
    colorFade = true,
    bar = function(frame) return frame.healthBar end,
    background = function(frame) return frame.background end,
    enabled = function(frame)
        return not frame.optionTable or frame.optionTable.fadeOutOfRange ~= false
    end,
    testOutside = function(frame)
        return frame._suiTestData and frame._suiTestOutside == true
    end,
    applyOutside = function(frame, outside, alpha)
        -- Aura buttons sit on the health bar, whose range treatment changes
        -- colour rather than alpha. Fade the buttons with the same range state.
        local function Fade(buttons)
            if not buttons then return end
            for _, button in ipairs(buttons) do
                if button:GetAlpha() ~= alpha then button:SetAlpha(alpha) end
            end
        end
        Fade(frame.buffFrames)
        Fade(frame.debuffFrames)
    end,
}
local function RangeUnit(frame)
    return frame.displayedUnit or frame.unit or (frame._suiTestData and "player")
end

function module:UpdateFullHealthMuted(frame)
    if not frame or not frame.healthBar then return end
    local db = DB()
    local full = false
    if db and db.enabled ~= false and db.muteFullHealth then
        local health, maximum
        if frame._suiTestData then
            health = frame.healthBar:GetValue()
            local minimum
            minimum, maximum = frame.healthBar:GetMinMaxValues()
        else
            local unit = frame.displayedUnit or frame.unit
            if unit and UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
                health, maximum = UnitHealth(unit), UnitHealthMax(unit)
            end
        end
        full = maximum and maximum > 0 and health >= maximum * 0.99 or false
    end
    SarychUI.UnitFrameLayers:SetFullHealthMuted(frame, full)
end

function module:ApplyDistanceToFrame(frame)
    self:UpdateFullHealthMuted(frame)
    if DB() and DB().enabled == false then return end
    local range = SarychUI.UnitFrameRange
    if not range or not frame or not frame.healthBar then return end
    local unit = frame.unit or (frame._suiTestData and "player")
    if unit then range:Register(frame, RangeUnit, rangeOptions) end
end

function module:RefreshRange()
    local range = SarychUI.UnitFrameRange
    if not range then return end
    if not InCombatLockdown() and CompactRaidFrameContainer then
        CompactRaidFrameContainer:SetScale(1)
    end
    if CompactRaidFrameContainer and CompactRaidFrameContainer_ApplyToFrames then
        CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, "normal",
            function(frame) self:ApplyDistanceToFrame(frame) end)
    end
    for _, frame in pairs(self.testFrames or {}) do self:ApplyDistanceToFrame(frame) end
    for _, frame in ipairs(self.defaultPartySamples or {}) do
        if self.defaultPartyPreview and self.defaultPartyPreview:IsShown()
            and frame:IsShown() then self:ApplyDistanceToFrame(frame) end
    end
    range:Refresh()
end

function module:ShouldDisplayUnit(unit)
    local db = DB()
    return not (db and (db.sortOrder == "HIDE" or db.sortOrder == "MINIMAL_TOP") and UnitIsUnit(unit, "player"))
end

function module:ApplySort()
    if DB() and DB().enabled == false then return end
    if InCombatLockdown() then self.pending = true; return end
    local db = DB()
    local manager = CompactRaidFrameManager
    if not db or not manager or not manager.container then return end
    if db.sortOrder == "ASC" or db.sortOrder == "DESC" then
        local profile = GetActiveRaidProfile and GetActiveRaidProfile()
        if profile and GetRaidProfileOption(profile, "keepGroupsTogether") then
            SetRaidProfileOption(profile, "keepGroupsTogether", false)
            CompactUnitFrameProfiles_ApplyProfile(profile)
        end
        CompactRaidFrameContainer_SetFlowSortFunction(manager.container, SortUnits)
    else
        local mode = CompactRaidFrameManager_GetSetting("SortMode")
        CompactRaidFrameManager_SetSetting("SortMode", mode)
    end
    if self.testCount and self.RefreshTest then self:RefreshTest() end
    if self.RefreshMinimalPlayerHealth then self:RefreshMinimalPlayerHealth(manager.container) end
end

function module:ApplyQuickControls()
    if DB() and DB().enabled == false then return end
    if InCombatLockdown() then self.pending = true; return end
    local db = DB()
    local manager = CompactRaidFrameManager
    if not db or not manager or not manager.displayFrame then return end
    local toggle = manager.toggleButton or CompactRaidFrameManagerToggleButton
    if db.showQuickControls == false then
        if not self.quickControlsHidden then
            self.quickControlsRegions = {}
            for _, region in ipairs({ manager:GetRegions() }) do
                if region and region.GetAlpha and region.SetAlpha then
                    self.quickControlsRegions[#self.quickControlsRegions + 1] = {
                        region = region, alpha = region:GetAlpha(),
                    }
                end
            end
        end
        self.quickControlsHidden = true
        manager.displayFrame:Hide()
        if toggle then toggle:Hide() end
        for _, saved in ipairs(self.quickControlsRegions or {}) do saved.region:SetAlpha(0) end
    else
        if self.quickControlsHidden then
            for _, saved in ipairs(self.quickControlsRegions or {}) do
                saved.region:SetAlpha(saved.alpha)
            end
        end
        if toggle then toggle:Show() end
        if not manager.collapsed then manager.displayFrame:Show() end
        self.quickControlsHidden = nil
        self.quickControlsRegions = nil
    end
end

function module:SetRaidStylePartyFrames(enabled)
    if not CUF_CVar then return end
    CUF_CVar:SetValue("useCompactPartyFrames", enabled and "1" or "0")
    if InCombatLockdown() then
        self.pendingPartyFrameRefresh = true
        return
    end
    if SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames then SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames() end
    if CompactRaidFrameContainer then
        CompactRaidFrameContainer_OnEvent(CompactRaidFrameContainer, "PLAYER_ENTERING_WORLD")
    end
    if CompactRaidFrameManager then
        CompactRaidFrameManager_UpdateShown(CompactRaidFrameManager)
        CompactRaidFrameManager_UpdateDisplayCounts(CompactRaidFrameManager)
        CompactRaidFrameManager_UpdateLabel(CompactRaidFrameManager)
        CompactRaidFrameManager_UpdateContainerLockVisibility(CompactRaidFrameManager)
    end
    if self.testCount then self:RefreshTest() end
    if SarychUI.UnitFrameLayers and SarychUI.UnitFrameLayers.RefreshPartyOverlays then
        SarychUI.UnitFrameLayers:RefreshPartyOverlays()
    end
end

local presetFields = { "enabled", "showQuickControls", "castbarEnabled", "castbarHidePlayer", "muteFullHealth", "nameFontSize", "nameFontSizeEnabled",
    "auraBlacklistEnabled", "groupBuffBlacklist", "groupDebuffBlacklist", "groupDispelExceptions" }
local allyFields = { "enabled", "showPlayer", "displayMode", "contexts", "layouts" }
local function AllySettingsDB()
    local tracker = SarychUI.extensions and SarychUI.extensions.party_abilities
    return tracker and tracker:GetDB()
end
local function CaptureAllySettings()
    local source = AllySettingsDB()
    if not source then return nil end
    local result = {}
    for _, key in ipairs(allyFields) do result[key] = Copy(source[key]) end
    return result
end
local function SamePresetValue(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not SamePresetValue(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function module:IsPresetDirty()
    local db = DB()
    local saved = db and db.presets and db.presets[db.activePreset]
    local current = saved and self:CapturePreset()
    if not current then return false end
    return not SamePresetValue(current.settings, saved.settings)
        or not SamePresetValue(current.position, saved.position)
        or not SamePresetValue(current.moduleSettings, saved.moduleSettings)
        or not SamePresetValue(current.allySettings, saved.allySettings)
        or current.partyFrames ~= saved.partyFrames or current.sortOrder ~= saved.sortOrder
end

function module:RefreshPresetButtons()
    if CompactUnitFrameProfiles_UpdateManagementButtons then CompactUnitFrameProfiles_UpdateManagementButtons() end
    if SarychUI.NotifySarychUIOptionsChange then SarychUI:NotifySarychUIOptionsChange() end
end

function module:CapturePreset()
    local profile = GetActiveRaidProfile and GetActiveRaidProfile()
    if not profile or not GetRaidProfileFlattenedOptions then return nil end
    local settings = Copy(GetRaidProfileFlattenedOptions(profile))
    for _, key in ipairs({ "autoActivateSpec1", "autoActivateSpec2" }) do
        settings[key] = GetRaidProfileOption(profile, key)
    end
    local db = DB()
    local position
    if GetRaidProfileSavedPosition then
        local dynamic, top, topOffset, bottom, bottomOffset, left, leftOffset = GetRaidProfileSavedPosition(profile)
        position = { isDynamic=dynamic, topPoint=top, topOffset=topOffset,
            bottomPoint=bottom, bottomOffset=bottomOffset, leftPoint=left, leftOffset=leftOffset }
    end
    local extras = {}
    for _, key in ipairs(presetFields) do extras[key] = Copy(db and db[key]) end
    return { settings = settings, position = position, moduleSettings = extras, allySettings = CaptureAllySettings(),
        partyFrames = CUF_CVar and CUF_CVar:GetValue("useCompactPartyFrames"),
        sortOrder = db and db.sortOrder or "NONE" }
end

function module:SavePreset(name)
    local db = DB()
    if not db or type(name) ~= "string" or name == "" then return false end
    local preset = self:CapturePreset()
    if not preset then return false end
    db.presets = db.presets or {}
    local old = db.presets[name]
    if old then preset.autoSize, preset.autoSpec = old.autoSize, old.autoSpec end
    db.presets[name] = preset
    db.activePreset = name
    self._presetDB, self._presetName = db, name
    self:RefreshPresetButtons()
    if CompactUnitFrameProfilesProfileSelector then UIDropDownMenu_SetText(CompactUnitFrameProfilesProfileSelector, name) end
    if CompactRaidFrameManagerDisplayFrameProfileSelector then UIDropDownMenu_SetText(CompactRaidFrameManagerDisplayFrameProfileSelector, name) end
    return true
end

function module:SaveNameTextSettings()
    local db = DB()
    local preset = db and db.presets and db.presets[db.activePreset]
    if not preset then return end
    -- Name controls apply immediately. Keep their active preset in sync without
    -- implicitly saving unrelated edits to frame size, auras or ally abilities.
    if not preset.moduleSettings then
        preset.moduleSettings = {}
        for _, key in ipairs(presetFields) do preset.moduleSettings[key] = Copy(db[key]) end
    end
    preset.moduleSettings.nameFontSize = tonumber(db.nameFontSize) or 10
    preset.moduleSettings.nameFontSizeEnabled = db.nameFontSizeEnabled == true
end

function module:DeletePreset(name)
    local db = DB()
    if not db or not db.presets or not name or not db.presets[name] then return false end
    db.presets[name] = nil
    if self.pendingPreset == name then self.pendingPreset = nil end
    if self._presetDB == db and self._presetName == name then
        self._presetDB, self._presetName = nil, nil
    end
    if db.activePreset == name then
        db.activePreset = next(db.presets) or ""
        if db.activePreset ~= "" then self:ApplyPreset(db.activePreset) end
    end
    local label = db.activePreset ~= "" and db.activePreset or SarychUI:T("ui.options_68d6d535f1")
    for _, selectorName in ipairs({ "CompactUnitFrameProfilesProfileSelector", "CompactRaidFrameManagerDisplayFrameProfileSelector" }) do
        local selector = _G[selectorName]
        if selector then
            UIDropDownMenu_SetSelectedValue(selector, db.activePreset ~= "" and db.activePreset or nil)
            UIDropDownMenu_SetText(selector, label)
        end
    end
    self:RefreshPresetButtons()
    return true
end

function module:ApplyPreset(name)
    local db = DB()
    local preset = db and db.presets and db.presets[name]
    if not preset then return false end
    if InCombatLockdown() then self.pendingPreset = name; return false end
    local profile = GetActiveRaidProfile and GetActiveRaidProfile()
    if not profile then return false end
    self.pendingPreset = nil
    if self._presetDB == db and self._presetName == db.activePreset and name ~= db.activePreset then
        self:SavePreset(db.activePreset)
    end
    -- Old presets did not contain these fields; adopt the current values once.
    local current = self:CapturePreset()
    if preset.position == nil then preset.position = Copy(current.position) end
    if preset.moduleSettings == nil then preset.moduleSettings = Copy(current.moduleSettings) end
    if preset.partyFrames == nil then preset.partyFrames = current.partyFrames end
    local wasEnabled = db.enabled ~= false
    -- Upgrade presets created before the complete tab was included.
    if preset.moduleSettings.enabled == nil then preset.moduleSettings.enabled = db.enabled ~= false end
    if preset.moduleSettings.nameFontSize == nil then preset.moduleSettings.nameFontSize = 10 end
    if preset.moduleSettings.nameFontSizeEnabled == nil then preset.moduleSettings.nameFontSizeEnabled = false end
    if preset.allySettings == nil then preset.allySettings = Copy(current.allySettings) end
    for _, key in ipairs(presetFields) do db[key] = Copy(preset.moduleSettings[key]) end
    local allyDB = AllySettingsDB()
    if allyDB and preset.allySettings then
        for _, key in ipairs(allyFields) do allyDB[key] = Copy(preset.allySettings[key]) end
    end
    if preset.position and SetRaidProfileSavedPosition then
        local pos = preset.position
        SetRaidProfileSavedPosition(profile, pos.isDynamic, pos.topPoint, pos.topOffset,
            pos.bottomPoint, pos.bottomOffset, pos.leftPoint, pos.leftOffset)
    end
    for key, value in pairs(preset.settings or {}) do
        SetRaidProfileOption(profile, key, Copy(value))
    end
    CompactUnitFrameProfiles_ApplyProfile(profile)
    db.sortOrder = preset.sortOrder or "NONE"
    db.activePreset = name
    if CompactUnitFrameProfilesProfileSelector then UIDropDownMenu_SetText(CompactUnitFrameProfilesProfileSelector, name) end
    if CompactRaidFrameManagerDisplayFrameProfileSelector then UIDropDownMenu_SetText(CompactRaidFrameManagerDisplayFrameProfileSelector, name) end
    self._presetDB, self._presetName = db, name
    if preset.partyFrames ~= nil then self:SetRaidStylePartyFrames(preset.partyFrames == "1" or preset.partyFrames == 1 or preset.partyFrames == true) end
    self:ApplySort()
    self:ApplyQuickControls()
    self:RefreshRange()
    self:ApplyAuraBlacklist()
    if self.ApplyHeaderCastbars then self:ApplyHeaderCastbars() end
    if self.RefreshNameTexts then self:RefreshNameTexts() end
    if self.testCount and self.RefreshTest then self:RefreshTest() end
    local tracker = SarychUI.extensions and SarychUI.extensions.party_abilities
    if tracker and tracker.RefreshConfig then tracker:RefreshConfig() end
    if SarychUI.PartyAbilitiesPreview then SarychUI.PartyAbilitiesPreview:RefreshAll(true) end
    if wasEnabled ~= (db.enabled ~= false) then
        if db.enabled ~= false then self:Enable() else self:Disable() end
    end
    self:RefreshPresetButtons()
    return true
end

function module:RestoreActivePreset()
    local db = DB()
    if not db or self._presetDB == db or not db.presets or not db.presets[db.activePreset] then return end
    -- On login/profile activation the profile contains the latest saved controls.
    -- Older active snapshots can predate those edits; do not roll names back.
    self:SaveNameTextSettings()
    self:ApplyPreset(db.activePreset)
end

function module:AutoPreset()
    local db = DB()
    if not db or db.enabled == false then return end
    local count = RosterSize()
    local spec = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    local winner, best = nil, -1
    local _, instanceType = IsInInstance()
    local enemyType = (instanceType == "arena" or instanceType == "pvp") and "PvP" or "PvE"
    local buckets = { 2, 3, 5, 10, 15, 25, 40 }
    local bucket
    for _, size in ipairs(buckets) do if count <= size then bucket = size; break end end
    for name, preset in pairs(db.presets or {}) do
        local size = tonumber(preset.autoSize)
        if size and count <= size and (preset.autoSpec == "any" or tonumber(preset.autoSpec) == spec) then
            local score = 100 - size
            if tonumber(preset.autoSpec) == spec then score = score + 100 end
            if score > best then winner, best = name, score end
        end
        local settings = preset.settings or {}
        if bucket and settings["autoActivate" .. bucket .. "Players"]
            and settings["autoActivateSpec" .. spec]
            and settings["autoActivate" .. enemyType] then
            local score = 300 - bucket
            if score > best then winner, best = name, score end
        end
    end
    -- Repeated roster/combat events must not undo a manual selection. Revisit
    -- auto-selection only when its winner, environment, spec or SUI profile changes.
    if self._autoPresetDB == db and self._autoPresetWinner == winner
        and self._autoPresetInstance == instanceType and self._autoPresetSpec == spec then return end
    self._autoPresetDB, self._autoPresetWinner = db, winner
    self._autoPresetInstance, self._autoPresetSpec = instanceType, spec
    if winner and winner ~= db.activePreset then self:ApplyPreset(winner) end
end

function module:Enable()
    if self.RefreshNameTexts then self:RefreshNameTexts() end
    if self.ApplyHeaderCastbars then self:ApplyHeaderCastbars() end
    local db = DB()
    if not db or db.enabled == false then return end
    self:ApplyAuraBlacklist()
    self:SetRuntimeEvents(true)
    self.pendingDisable = nil
    if InCombatLockdown() then self.pendingEnable = true; return end
    CompactRaidFrameEnabled = true
    if CompactRaidFrameManager then
        RegisterStateDriver(CompactRaidFrameManager, "visibility", "[group:party] show; [group:raid] show; [nogroup:party] hide")
        CompactRaidFrameManager_UpdateShown(CompactRaidFrameManager)
    end
    if SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames then SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames() end
    local db = DB()
    if not db then return end
    for _, preset in pairs(db.presets or {}) do
        if type(preset) == "table" then
            preset.indicators = nil
            preset.distance = nil
            preset.frameScale = nil
        end
    end
    db.frameScale = nil
    db.customRangeCheck, db.customRange, db.rangeAlpha = nil, nil, nil
    db.rangeDarkeningFactor, db.backgroundAlpha = nil, nil
    local profile = SarychUI.db and SarychUI.db.profile
    if profile and profile.frameworks then profile.frameworks.unitframerange = nil end
    -- SUI presets replace Blizzard's automatic raid-profile switching.
    if not self.oldAutoActivation and CompactUnitFrameProfiles_CheckAutoActivation then
        self.oldAutoActivation = CompactUnitFrameProfiles_CheckAutoActivation
        CompactUnitFrameProfiles_CheckAutoActivation = function() end
    end
    self:RefreshRange()
    if not self.layerHooked and type(CompactUnitFrame_SetUnit) == "function" then
        hooksecurefunc("CompactUnitFrame_SetUnit", function(frame, unit)
            local db = DB(); if not db or db.enabled == false then return end
            if not frame or not frame.GetName then return end
            local name = frame:GetName()
            if name and (name:match("^CompactRaidFrame") or name:match("^CompactRaidGroup")
                or name:match("^CompactPartyFrame")) then
                if unit then
                    AttachFrameLayers(frame)
                    module:ApplyDistanceToFrame(frame)
                elseif SarychUI.UnitFrameRange then
                    SarychUI.UnitFrameRange:Unregister(frame)
                end
            end
        end)
        self.layerHooked = true
    end
    if CompactRaidFrameContainer and CompactRaidFrameContainer_ApplyToFrames then
        CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, "normal", AttachFrameLayers)
        CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, "mini", AttachFrameLayers)
    end
    if not self.quickControlsHooked and hooksecurefunc then
        hooksecurefunc("CompactRaidFrameManager_UpdateShown", function(manager)
            if manager == CompactRaidFrameManager then module:ApplyQuickControls() end
        end)
        self.quickControlsHooked = true
    end
    if not self.partyLayersHooked and hooksecurefunc
        and type(SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames) == "function" then
        hooksecurefunc(SarychUI.Compat, "RaidOptionsFrame_UpdatePartyFrames", function()
            local layers = SarychUI.UnitFrameLayers
            if layers and layers.RefreshPartyOverlays then layers:RefreshPartyOverlays() end
        end)
        self.partyLayersHooked = true
    end
    self:RestoreActivePreset()
    self:ApplySort()
    self:AutoPreset()
    self:ApplyQuickControls()
    if SarychUI.UnitFrameLayers and SarychUI.UnitFrameLayers.RefreshPartyOverlays then
        SarychUI.UnitFrameLayers:RefreshPartyOverlays()
    end
end

function module:Disable()
    if self.HideMinimalPlayerHealth then self:HideMinimalPlayerHealth() end
    if self.DisableHeaderCastbars then self:DisableHeaderCastbars() end
    self:ApplyAuraBlacklist()
    self:SetRuntimeEvents(false)
    self.pendingEnable = nil
    if InCombatLockdown() then self.pendingDisable = true; return end
    if self.HideTest then self:HideTest() end
    if SarychUI.UnitFrameRange then SarychUI.UnitFrameRange:UnregisterOwner("group_frames") end
    CompactRaidFrameEnabled = false
    self.pendingPreset, self.pendingTestCount, self.pendingTest = nil, nil, nil
    if self.oldAutoActivation then
        CompactUnitFrameProfiles_CheckAutoActivation = self.oldAutoActivation
        self.oldAutoActivation = nil
    end
    if CompactRaidFrameManager then
        RegisterStateDriver(CompactRaidFrameManager, "visibility", "hide")
        CompactRaidFrameManager:Hide()
    end
    if SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames then SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames() end
    if CompactRaidFrameManager and CompactRaidFrameManager.container then
        CompactRaidFrameManager.container:Hide()
    end
end

local events = CreateFrame("Frame")
function module:SetRuntimeEvents(enabled)
    events:UnregisterAllEvents()
    if enabled then
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED",
            "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_REGEN_ENABLED" }) do events:RegisterEvent(event) end
    elseif InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end
-- One startup reconciliation is needed even when the module starts disabled.
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then events:UnregisterEvent("PLAYER_LOGIN") end
    if event == "PLAYER_LOGIN" and DB() and DB().enabled == false then module:Disable(); return end
    if event == "PLAYER_REGEN_ENABLED" then
        if module.pendingDisable then module.pendingDisable = nil; module:Disable() end
        if module.pendingEnable then module.pendingEnable = nil; module:Enable() end
    end
    local db = DB()
    if not db or db.enabled == false then return end
    module:RestoreActivePreset()
    if event == "PLAYER_REGEN_ENABLED" then
        if module.pendingPreset then
            local preset = module.pendingPreset
            module.pendingPreset = nil
            module:ApplyPreset(preset)
        end
        if module.pending then module.pending = nil; module:ApplySort(); module:ApplyQuickControls() end
        if module.pendingTestHide then module.pendingTestHide = nil; module:HideTest() end
        if module.pendingTestCount then
            local count = module.pendingTestCount
            module.pendingTestCount = nil
            module:ToggleTest(count)
        elseif module.pendingTest then module.pendingTest = nil; module:RefreshTest() end
        if module.pendingPartyFrameRefresh then
            module.pendingPartyFrameRefresh = nil
            module:SetRaidStylePartyFrames(CUF_CVar and CUF_CVar:GetCVarBool("useCompactPartyFrames"))
        end
    end
    module:AutoPreset()
end)

