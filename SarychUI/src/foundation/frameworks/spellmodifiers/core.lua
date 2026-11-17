-- Shared talent/glyph modifiers. No private build cache or inspect driver.
local Modifiers = {}
SarychUI.SpellModifiers = Modifiers

local function TalentLibrary()
    return LibStub and LibStub("LibGroupTalents-1.0", true)
end

function Modifiers:GetTalentRank(guid, spellID)
    if not guid then return end
    local name = GetSpellInfo and GetSpellInfo(spellID)
    if not name then return end
    if UnitGUID and guid == UnitGUID("player") and GetNumTalentTabs and GetNumTalents and GetTalentInfo then
        for tab = 1, GetNumTalentTabs() do
            for index = 1, GetNumTalents(tab) do
                local talentName, _, _, _, rank = GetTalentInfo(tab, index)
                if talentName == name then return tonumber(rank) end
            end
        end
        return -- Incomplete native data is not a known zero rank.
    end
    local lib = TalentLibrary()
    if lib and lib.GetGUIDTalents and lib:GetGUIDTalents(guid) and lib.GUIDHasTalent then
        return tonumber(lib:GUIDHasTalent(guid, name)) or 0
    end
end

function Modifiers:HasGlyph(guid, ids)
    if not guid then return end
    if UnitGUID and guid == UnitGUID("player") and GetGlyphSocketInfo then
        local known = false
        for socket = 1, NUM_GLYPH_SLOTS or 6 do
            local enabled, _, spell = GetGlyphSocketInfo(socket)
            if enabled ~= nil then known = true end
            for _, id in ipairs(ids) do if spell == id then return true end end
        end
        if known then return false end
        return
    end
    local lib = TalentLibrary()
    if lib and lib.GetGUIDGlyphs and lib:GetGUIDGlyphs(guid) ~= nil and lib.GUIDHasGlyph then
        for _, id in ipairs(ids) do if lib:GUIDHasGlyph(guid, id) then return true end end
        return false
    end
end

-- strict=true: no duration when relevant build data is missing.
-- Otherwise retain the cooldown tracker's configured/partial estimate.
-- Second result distinguishes a complete calculation from an estimate.
function Modifiers:Calculate(guid, rule, fallback, strict)
    if not rule then return fallback, true end
    local ranks, glyphs = {}, {}
    local talentsKnown, glyphsKnown = true, true
    for i, modifier in ipairs(rule.talents or {}) do
        ranks[i] = self:GetTalentRank(guid, modifier[1])
        if ranks[i] == nil then talentsKnown = false end
    end
    for i, modifier in ipairs(rule.glyphs or {}) do
        glyphs[i] = self:HasGlyph(guid, modifier.ids)
        if glyphs[i] == nil then glyphsKnown = false end
        if glyphs[i] and modifier.permanent then return 0, true end
    end
    local known = talentsKnown and glyphsKnown
    if strict and not known then return nil, false end
    if not talentsKnown or (not glyphsKnown and not rule.talents) then return fallback, false end
    local duration = glyphsKnown and rule.base or (rule.unknownGlyphBase or fallback)
    if not duration then return nil, false end
    for i, modifier in ipairs(rule.talents or {}) do
        local rank = ranks[i]
        if modifier.percents then
            duration = duration * (1 + (modifier.percents[math.min(rank, #modifier.percents - 1) + 1] or 0))
        else
            if modifier.percent then duration = duration * (1 + modifier.percent * rank) end
            if modifier.seconds then duration = duration + modifier.seconds * rank end
        end
    end
    for i, modifier in ipairs(rule.glyphs or {}) do
        if glyphsKnown and glyphs[i] then
            if modifier.percent then duration = duration * (1 + modifier.percent) end
            if modifier.seconds then duration = duration + modifier.seconds end
        end
    end
    return math.max(0.5, duration), known
end
