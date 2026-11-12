-- Shared pet identity and icon rendering for classic and embedded ElvUI plates.
-- Recognition adapted from the supplied SarychPetIcons companion.
local module = SarychUI.modules.health_indicators
local lib = LibStub("LibNameplates-1.0", true)
if not lib then return end
local driver = CreateFrame("Frame")
driver:Hide()
local active = false
local states = setmetatable({}, { __mode = "k" })
-- Both renderers share the same placement.
function module:AnchorPetIcon(icon, plate)
    if icon:GetNumPoints() == 1 then
        local point, relative, relativePoint, x, y = icon:GetPoint(1)
        if point == "CENTER" and relative == plate and relativePoint == "CENTER" and x == 0 and y == -6 then
            return
        end
    end
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", plate, "CENTER", 0, -6)
end

local pets = {
    shadowfiend = {key = "u1", spell = 34433, npc = 19668,
        icon = "Spell_Shadow_Shadowfiend", names = {"Shadowfiend", "Исчадие Тьмы", "Исчадие тьмы"}},
    wolves = {key = "sarychWolves", spell = 51533, npc = 29264,
        icon = "Spell_Shaman_FeralSpirit", names = {"Spirit Wolf", "Дух волка"}},
    gargoyle = {key = "sarychGargoyle", spell = 49206, npc = 27829,
        icon = "Ability_Hunter_Pet_Bat", names = {"Ebon Gargoyle", "Черная горгулья", "Чёрная горгулья"}},
    ghoul = {key = "sarychGhoul", spell = 46584, npc = 26125,
        icon = "Spell_Shadow_AnimateDead", names = {}},
    hunterpet = {key = "sarychHunterPet", spell = 883,
        icon = "Ability_Hunter_BeastCall", names = {}},
    succubus = {key = "sarychSuccubus", spell = 712, npc = 1863, family = 17,
        icon = "Spell_Shadow_SummonSuccubus", names = {}},
    felhunter = {key = "sarychFelhunter", spell = 691, npc = 417, family = 15,
        icon = "Spell_Shadow_SummonFelhunter", names = {}},
}
local byNPC, bySpell, byName, byFamily = {}, {}, {}, {}
local identities = {}
local TTL = 600


for kind, pet in pairs(pets) do
    if pet.npc then byNPC[pet.npc] = kind end
    if pet.spell then bySpell[pet.spell] = kind end
    if pet.family then
        byFamily[pet.family] = kind
        if GetPetFamilyInfo then
            local family = GetPetFamilyInfo(pet.family)
            if family then byFamily[family] = kind end
        end
    end
    for _, name in ipairs(pet.names) do byName[name] = kind end
end
byFamily.Succubus, byFamily["Суккуб"] = "succubus", "succubus"
byFamily.Felhunter, byFamily["Охотник Скверны"] = "felhunter", "felhunter"

local function KindFromGUID(guid)
    if type(guid) ~= "string" then return end
    -- 3.3.5: 0xF130 + four hex digits of creature entry + spawn counter.
    local prefix = string.upper(string.sub(guid, 1, 6))
    if prefix == "0XF130" or prefix == "0XF140" or prefix == "0XF150" then
        return byNPC[tonumber(string.sub(guid, 7, 10), 16)]
    end
    local entry = string.match(guid, "^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
        or string.match(guid, "^Pet%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
    return entry and byNPC[tonumber(entry)]
end

local function Remember(guid, name, kind)
    if not guid or not name or not kind then return end
    identities[guid] = {name = name, kind = kind, time = GetTime()}
end

local function OwnerClassForPetUnit(unit)
    if unit == "pet" then return select(2, UnitClass("player")) end
    local index=type(unit)=="string" and (string.match(unit,"^arenapet(%d+)$") or string.match(unit,"^arena(%d+)pet$"))
    local owner=index and ("arena"..index)
    if not owner then
        index=type(unit)=="string" and (string.match(unit,"^partypet(%d+)$") or string.match(unit,"^party(%d+)pet$"))
        owner=index and ("party"..index)
    end
    if not owner then
        index = type(unit) == "string" and unit:match("^raidpet(%d+)$")
        owner = index and ("raid" .. index)
    end
    if owner and UnitClass then return select(2,UnitClass(owner)) end
end

local function LearnUnit(unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local guid, name = UnitGUID(unit), UnitName(unit)
    local kind = KindFromGUID(guid)
    if not kind and UnitCreatureFamily then kind = byFamily[UnitCreatureFamily(unit)] end
    if not kind then
        local ownerClass=OwnerClassForPetUnit(unit)
        if ownerClass=="DEATHKNIGHT" then kind="ghoul"
        elseif ownerClass=="HUNTER" then kind="hunterpet" end
    end
    Remember(guid, name, kind)
    return kind
end

local function Root(plate)
    return lib.realPlate[plate] or plate
end

local function Resolve(plate)
    local root = Root(plate)
    local identity = root.UnitFrame
    local name
    if identity then name = identity.UnitName
    elseif lib.plateRegions[root] then name = lib:GetName(root) end
    if not name then return end
    local guid = identity and identity.guid or lib:GetGUID(root)
    local unit = root.namePlateUnitToken or (identity and identity.unit)
    if unit and UnitExists(unit) and (not guid or UnitGUID(unit) == guid) and UnitName(unit) == name then
        if UnitIsPlayer(unit) then return end
        local kind = LearnUnit(unit)
        if kind then return kind end
    end
    if identity then
        if identity.UnitType ~= "ENEMY_NPC" and identity.UnitType ~= "FRIENDLY_NPC" then return end
    elseif lib:GetType(root) ~= "NPC" then return end
    if guid then
        local kind = KindFromGUID(guid)
        if kind then return kind end
        local known = identities[guid]
        if known and GetTime() - known.time <= TTL then return known.kind end
        return
    end
    if byName[name] then return byName[name] end
    local found
    for _, known in pairs(identities) do
        if known.name == name and GetTime() - known.time <= TTL then
            if found and found ~= known.kind then return end
            found = known.kind
        end
    end
    return found
end

local function Restore(root)
    local state = states[root]
    if not state then return end
    if state.icon:IsShown() then state.icon:Hide() end
    if state.host then
        state.host:SetAlpha(state.alpha or 1)
        state.host = nil
    end
    if root._suiPetIconAnchor then
        root._suiPetIconAnchor = nil
        if _G.sarPlatesAuras_RefreshContainerParent then _G.sarPlatesAuras_RefreshContainerParent(root) end
    end
end

function module:GetPetIconTexture(plate)
    local root = Root(plate)
    local kind = active and root:IsShown() and Resolve(root)
    return kind and ("Interface\\Icons\\" .. pets[kind].icon) or nil
end

local function Paint(plate)
    local root = Root(plate)
    if root.UnitFrame then
        -- ElvUI owns its icon-only state. Never fade its UnitFrame or draw a
        -- competing overlay; notify the style engine only when identity changes.
        Restore(root)
        local frame = root.UnitFrame
        local texture = module:GetPetIconTexture(root)
        local previousTexture = frame._suiPetIconTexture
        local pack = _G.SarychUI_ElvUI_NamePlates
        local np = pack and pack[1] and pack[1]:GetModule("NamePlates", true)
        if np and (frame._suiPetIconTexture ~= texture
            or (texture and not frame.IconOnlyChanged and not frame.VisibilityChanged)) then
            np:StyleFilterUpdate(frame, "SARYCHUI_PET_ICON")
        end
        if texture and frame.IconOnlyChanged and frame.IconFrame then
            module:AnchorPetIcon(frame.IconFrame, root)
        end
        if previousTexture ~= texture then
            local layout = SarychUI.PlatesAurasElvUI
            if layout and layout.UpdateElvUIAuraAnchor then layout.UpdateElvUIAuraAnchor(root) end
        end
        return
    end
    local kind = active and root:IsShown() and Resolve(root)
    local host = root._suiClassicVisual
    if not kind or not host then Restore(root); return end
    local state = states[root]
    if not state then
        local icon = CreateFrame("Frame", nil, root)
        icon._suiPlateAura = true -- Keep it outside the classic visual wrapper.
        icon:EnableMouse(false)
        icon:SetSize(32, 32)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0, 1, 0, 1)
        state = { icon = icon }
        states[root] = state
        root:HookScript("OnHide", function() Restore(root) end)
    end
    if state.host ~= host then
        Restore(root)
        state.host, state.alpha = host, host:GetAlpha()
    end
    if host:GetAlpha() ~= 0 then host:SetAlpha(0) end
    local scale = module.GetNameplateScale and module:GetNameplateScale() or 1
    if state.icon:GetScale() ~= scale then state.icon:SetScale(scale) end
    -- Reapply after scale and on plate reuse, not just on first creation.
    module:AnchorPetIcon(state.icon, root)
    local level = root:GetFrameLevel() + 10
    if state.icon:GetFrameLevel() ~= level then state.icon:SetFrameLevel(level) end
    local texture = "Interface\\Icons\\" .. pets[kind].icon
    if state.icon.texture:GetTexture() ~= texture then state.icon.texture:SetTexture(texture) end
    if not state.icon:IsShown() then state.icon:Show() end
    if root._suiPetIconAnchor ~= state.icon then
        root._suiPetIconAnchor = state.icon
        if _G.sarPlatesAuras_RefreshContainerParent then _G.sarPlatesAuras_RefreshContainerParent(root) end
    end
end

local paintedRoots = {}
local function Refresh()
    wipe(paintedRoots)
    for root in pairs(states) do if not active or not root:IsShown() then Restore(root) end end
    if active then
        for _, plate in lib:IteratePlates() do
            local root = Root(plate)
            if not paintedRoots[root] then paintedRoots[root] = true; Paint(root) end
        end
    end
    local pack = _G.SarychUI_ElvUI_NamePlates
    local np = pack and pack[1] and pack[1]:GetModule("NamePlates", true)
    if np and np.VisiblePlates then
        for plate in pairs(np.VisiblePlates) do
            local root = Root(plate:GetParent())
            if not paintedRoots[root] then paintedRoots[root] = true; Paint(root) end
        end
    end
    wipe(paintedRoots)
end

local function LearnVisibleUnits()
    for _, unit in ipairs({"target", "mouseover", "focus", "pet"}) do LearnUnit(unit) end
    for i = 1, 5 do LearnUnit("arenapet" .. i) end
    for i = 1, 4 do LearnUnit("partypet" .. i) end
    for i = 1, 40 do LearnUnit("raidpet" .. i) end
end

driver:SetScript("OnEvent", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, sourceGUID, sourceName, _, destGUID, destName, _, spellID = ...
        if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
            identities[destGUID] = nil
        else
            Remember(sourceGUID, sourceName, KindFromGUID(sourceGUID))
            Remember(destGUID, destName, KindFromGUID(destGUID) or (subevent == "SPELL_SUMMON" and bySpell[spellID]))
        end
    else
        if event == "PLAYER_ENTERING_WORLD" then wipe(identities) end
        LearnVisibleUnits()
        Refresh()
    end
end)
local elapsed, cleanup = 0, 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed, cleanup = elapsed + delta, cleanup + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    if cleanup > 30 then
        cleanup = 0
        for guid, entry in pairs(identities) do
            if GetTime() - entry.time > TTL then identities[guid] = nil end
        end
    end
    Refresh()
end)

function module:RefreshPetIcons()
    local db = SarychUI:GetModuleProfile("health_indicators")
    if db then db.petIconOffsetY = nil end -- Retire the temporary positioning control.
    active = db and db.enabled ~= false and db.petIcons == true or false
    driver:UnregisterAllEvents()
    if active then
        for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_PET", "COMBAT_LOG_EVENT_UNFILTERED"}) do
            driver:RegisterEvent(event)
        end
        LearnVisibleUnits()
        driver:Show()
    else
        driver:Hide()
        wipe(identities)
    end
    Refresh()
end

function module:DisablePetIcons()
    active = false
    driver:UnregisterAllEvents()
    driver:Hide()
    Refresh()
    wipe(identities)
end
