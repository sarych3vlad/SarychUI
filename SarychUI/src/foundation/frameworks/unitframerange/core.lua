-- One range/appearance controller for all SarychUI unit frames (WoW 3.3.5a).
SarychUI.UnitFrameRange = SarychUI.UnitFrameRange or {}
local Range = SarychUI.UnitFrameRange
Range.frames = Range.frames or setmetatable({}, { __mode = "k" })
local ENEMY_SPELLS = {
    MAGE = 118, PRIEST = 32379, DRUID = 33786, SHAMAN = 10414,
    PALADIN = 10308, WARLOCK = 5782, WARRIOR = 25275,
    HUNTER = 1978, ROGUE = 36554, DEATHKNIGHT = 49576,
}
local spellSlots = {}
local RANGE_ALPHA = 0.55
local RANGE_DARKENING_FACTOR = 1.5

local function SetAlpha(region, alpha)
    if region and region.GetAlpha and region:GetAlpha() ~= alpha then
        region:SetAlpha(alpha)
    end
end

local function TrackColorTextures(layers, frame, ...)
    for i = 1, select("#", ...) do
        layers:TrackRangeTexture(frame, select(i, ...))
    end
end

-- Match Gladdy's numeric-ID path: resolve an actually learned spell, then
-- query its spellbook slot. The name overload is not used for range checks.
local function ResolveSpellSlot(spellID)
    if spellSlots[spellID] ~= nil then return spellSlots[spellID] or nil end
    local wanted = GetSpellInfo(spellID)
    local match
    if wanted and GetSpellName and GetSpellTabInfo then
        for tab = 1, (GetNumSpellTabs and GetNumSpellTabs() or MAX_SKILLLINE_TABS or 4) do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local name = GetSpellName(index, "spell")
                if name == wanted then
                    match = { index, "spell" }
                    local link = GetSpellLink and GetSpellLink(index, "spell")
                    if link and tonumber(link:match("spell:(%d+)")) == spellID then
                        spellSlots[spellID] = match
                        return match
                    end
                end
            end
        end
        if not match and HasPetSpells then
            local count = HasPetSpells()
            for index = 1, type(count) == "number" and count or 0 do
                if GetSpellName(index, "pet") == wanted then match = {index, "pet"} end
            end
        end
    end
    spellSlots[spellID] = match or false
    return match
end

local function SpellInRange(spellID, unit)
    if not spellID or not IsSpellInRange or not GetSpellInfo then return nil end
    local slot = ResolveSpellSlot(spellID)
    if not slot then return nil end
    local result = IsSpellInRange(slot[1], slot[2], unit)
    if result == nil or result == -1 then return nil end
    return result == 1 or result == true
end

local function InRangeResult(result)
    return result == 1 or result == true
end

function Range:IsInRange(unit, options)
    if not unit or not UnitExists(unit) then return nil end
    if UnitIsUnit(unit, "player") then return true end
    if UnitIsConnected and not UnitIsConnected(unit) then return false end
    if SarychUI.Compat.UnitPhaseReason and SarychUI.Compat.UnitPhaseReason(unit) then return false end

    -- Arena units are hostile: UnitInRange is intended for group members, and
    -- the party's custom interaction distance must not override spell range.
    if options and (options.spellID or options.enemy) then
        local spellID = options.spellID
        if type(spellID) == "function" then spellID = spellID() end
        if not spellID and options.enemy then
            local _, class = UnitClass("player")
            spellID = ENEMY_SPELLS[class]
        end
        -- Gladdy only falls back to interaction when no spell is configured.
        -- An unavailable configured spell must not silently become a 28-yard check.
        if spellID then return SpellInRange(spellID, unit) == true end
        return InRangeResult(CheckInteractDistance(unit, 4))
    end

    -- Party/raid frames represent allies. Combine the client range checks.
    if InRangeResult(CheckInteractDistance(unit, 4)) then return true end
    if UnitInRange then
        if InRangeResult(UnitInRange(unit)) then return true end
    end
    -- Vial of the Sunwell has a 40-yard range when the client can check it.
    if IsItemInRange and InRangeResult(IsItemInRange(34471, unit)) then return true end
    return false
end

function Range:ColorFactorForOutside(outside)
    if not outside then return 1 end
    -- Gladdy divides each RGB channel by its out-of-range factor.
    return 1 / RANGE_DARKENING_FACTOR
end

function Range:AlphaForOutside(outside)
    return outside and RANGE_ALPHA or 1
end

function Range:Update(frame)
    local entry = self.frames[frame]
    if not entry then return end
    local options = entry.options
    local bar = type(options.bar) == "function" and options.bar(frame) or options.bar or frame.healthBar or frame.healthbar
    if not bar and not options.wholeFrame then return end
    local background = type(options.background) == "function" and options.background(frame) or options.background
    SetAlpha(background, 1)
    local enabled = not options.enabled or options.enabled(frame) ~= false
    local active = not options.active or options.active(frame) ~= false
    local outside = false
    if enabled and active and frame.IsVisible and frame:IsVisible() then
        if options.testOutside and options.testOutside(frame) then
            outside = true
        else
            local unit = type(entry.unit) == "function" and entry.unit(frame) or entry.unit
            outside = self:IsInRange(unit, options) == false
        end
    end
    local target = options.wholeFrame and frame or bar
    local baseAlpha = entry.baseAlpha or 1
    local colorFade = options.colorFade and SarychUI.UnitFrameLayers
        and SarychUI.UnitFrameLayers.SetRangeColorFactor
    local appliedAlpha = baseAlpha * (colorFade and 1 or self:AlphaForOutside(outside))
    entry.appliedAlpha = appliedAlpha
    entry.outside = outside
    if colorFade then
        SarychUI.UnitFrameLayers:SetRangeColorFactor(frame, self:ColorFactorForOutside(outside))
        if options.colorTextures then
            local layers = SarychUI.UnitFrameLayers
            TrackColorTextures(layers, frame, options.colorTextures(frame))
        end
    end
    SetAlpha(target, appliedAlpha)
    if options.applyOutside then options.applyOutside(frame, outside, self:AlphaForOutside(outside)) end
end

function Range:SetBaseAlpha(frame, alpha)
    local entry = self.frames[frame]
    if not entry then
        SetAlpha(frame, alpha)
    elseif entry.baseAlpha ~= alpha then
        entry.baseAlpha = alpha
        self:Update(frame)
    elseif entry.options.wholeFrame and entry.appliedAlpha then
        SetAlpha(frame, entry.appliedAlpha)
    end
end

-- Separate UIParent visuals cannot inherit alpha from secure arena buttons.
-- Match the frame's effective alpha; descendants only need their local alpha.
function Range:ApplyLinkedAlpha(frame, region, localAlpha)
    if not frame or not region then return end
    local parent = region.GetParent and region:GetParent()
    while parent do
        if parent == frame then
            if localAlpha ~= nil then SetAlpha(region, localAlpha) end
            return
        end
        parent = parent.GetParent and parent:GetParent()
    end
    local alpha = frame.GetEffectiveAlpha and frame:GetEffectiveAlpha() or frame:GetAlpha()
    SetAlpha(region, (localAlpha or 1) * (alpha or 1))
end

function Range:Refresh()
    for frame in pairs(self.frames) do self:Update(frame) end
end

local ticker = CreateFrame("Frame")
ticker:RegisterEvent("SPELLS_CHANGED")
ticker:RegisterEvent("PLAYER_ENTERING_WORLD")
ticker:RegisterEvent("UNIT_PET")
ticker:SetScript("OnEvent", function() wipe(spellSlots) end)
ticker.elapsed = 0
ticker:Hide()
ticker:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.1 then
        self.elapsed = 0
        Range:Refresh()
    end
    -- Blizzard can repaint native bars after our range check. Repair only a
    -- changed bar before rendering, without querying distance every frame or
    -- hooking protected unit-frame event handlers.
    local layers = SarychUI.UnitFrameLayers
    if not layers then return end
    for frame, entry in pairs(Range.frames) do
        if entry.outside and entry.options.colorFade and frame:IsVisible() then
            local factor = Range:ColorFactorForOutside(true)
            for bar, color in pairs(frame._suiLayerBarColors or {}) do
                if bar.GetStatusBarColor then
                    local r, g, b = bar:GetStatusBarColor()
                    if math.abs(r - color[1] * factor) > 0.0001
                        or math.abs(g - color[2] * factor) > 0.0001
                        or math.abs(b - color[3] * factor) > 0.0001 then
                        layers:SetRangeColorFactor(frame, factor)
                        break
                    end
                end
            end
        end
    end
end)

-- Register(frame, unit, {bar, background, wholeFrame, colorFade, owner, enemy, enabled,
--                        active, testOutside}).
-- bar/background may be regions or frame-to-region functions; unit may be a
-- unit token or a frame-to-unit function. Call Unregister when a frame is retired.
function Range:Register(frame, unit, options)
    if not frame or not unit then return end
    local existing = self.frames[frame]
    if existing and existing.unit == unit and existing.options == options then
        self:Update(frame)
        return frame
    end
    self.frames[frame] = { unit = unit, options = options or {}, baseAlpha = existing and existing.baseAlpha or 1 }
    ticker:Show()
    self:Update(frame)
    return frame
end

function Range:Unregister(frame)
    local entry = self.frames[frame]
    if not entry then return end
    local options = entry.options
    if options.colorFade and SarychUI.UnitFrameLayers then
        SarychUI.UnitFrameLayers:SetRangeColorFactor(frame, 1)
    end
    local bar = type(options.bar) == "function" and options.bar(frame) or options.bar or frame.healthBar or frame.healthbar
    SetAlpha(options.wholeFrame and frame or bar, 1)
    local background = type(options.background) == "function" and options.background(frame) or options.background
    SetAlpha(background, 1)
    if options.applyOutside then options.applyOutside(frame, false, 1) end
    self.frames[frame] = nil
    if not next(self.frames) then ticker:Hide() end
end

function Range:UnregisterOwner(owner)
    for frame, entry in pairs(self.frames) do
        if entry.options.owner == owner then self:Unregister(frame) end
    end
end
