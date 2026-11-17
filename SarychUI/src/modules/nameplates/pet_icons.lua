-- Rendering adapters for Classic and ElvUI. Identity/policy: NameplatePets.
local module = SarychUI.modules.health_indicators
local lib = LibStub("LibNameplates-1.0", true)
if not lib then return end
local driver = CreateFrame("Frame")
driver:Hide()
local active = false
local states = setmetatable({}, { __mode = "k" })
local prepared = setmetatable({}, {__mode="k"})
local pending = setmetatable({}, {__mode="k"})
local hiddenRoots = setmetatable({}, {__mode="k"})
local lifetimeVisuals = setmetatable({}, {__mode="k"})
local Paint

local function HideLifetime(visual)
    if not visual then return end
    visual:Hide()
    if visual.countdownActive then
        if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(visual.cooldown, 0, 0, 0) end
        visual.countdownActive = nil
    end
end

-- One overlay implementation for both renderers. Its parent is always the
-- existing icon, so casts, scaling and side labels keep their usual anchors.
function module:UpdatePetLifetime(root, icon)
    local visual = lifetimeVisuals[root]
    local db = SarychUI:GetModuleProfile("health_indicators")
    local lifetimes = SarychUI.NameplatePetLifetimes
    local timer = active and icon and db and db.petIconLifetime and lifetimes and lifetimes:GetForPlate(root)
    local remaining = timer and timer.start + timer.duration - GetTime()
    if not remaining or remaining <= 0 then
        HideLifetime(visual)
        return
    end
    if not visual then
        visual = CreateFrame("Frame", nil, icon)
        visual:EnableMouse(false)
        visual:SetAllPoints(icon)
        visual.cooldown = CreateFrame("Cooldown", nil, visual)
        visual.cooldown.__sary_petLifetime = true
        visual.cooldown:SetAllPoints(visual)
        visual.cooldown:SetReverse(true)
        visual.cooldown:SetDrawEdge(true)
        lifetimeVisuals[root] = visual
    elseif visual:GetParent() ~= icon then
        visual:SetParent(icon)
        visual:ClearAllPoints()
        visual:SetAllPoints(icon)
    end
    local level = icon:GetFrameLevel() + 1
    if visual:GetFrameLevel() ~= level then visual:SetFrameLevel(level) end
    if visual.cooldown:GetFrameLevel() ~= level + 1 then visual.cooldown:SetFrameLevel(level + 1) end
    if visual.start ~= timer.start or visual.duration ~= timer.duration then
        visual.start, visual.duration = timer.start, timer.duration
        visual.cooldown:SetCooldown(timer.start, timer.duration)
    end
    -- Same bridge as party ability icons: CC owns digits, font, colours and
    -- thresholds, and can be toggled while the native sweep keeps running.
    if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(visual.cooldown, timer.start, timer.duration, 1) end
    visual.countdownActive = true
    if not visual:IsShown() then visual:Show() end
end
local function SetPetHidden(root, hidden)
    hidden = hidden and true or nil
    hiddenRoots[root] = hidden
    SarychUI.NameplateVisibility:SetHidden(root, "pet", hidden)
end
-- Both renderers share the same placement.
function module:AnchorPetIcon(icon, plate)
    local frame = plate.UnitFrame
    local bar = plate._suiPetCastBar or (frame and frame._suiPetCastAllowed and frame.CastBar)
    local point, relative, relativePoint, x, y = "CENTER", plate, "CENTER", 0, -6
    -- Classic reserves its cast slot while the option is enabled. Repeated
    -- gargoyle strikes must not raise/lower the icon on every Show/Hide.
    if bar and (not frame or bar:IsShown()) then
        point, relative, relativePoint, y = "BOTTOM", bar, "TOP", frame and frame._suiPetCastGap or 8
        local art = SarychUI and SarychUI.ClassicNameplateArt
        local offset = not frame and art and art:HorizontalOffset(bar, plate)
        if offset then
            x = -offset / icon:GetEffectiveScale()
        elseif not frame and plate.GetCenter and bar.GetCenter then
            -- The native Classic cast bar can be horizontally offset (e.g.
            -- to leave space for its spell icon). Follow its height only;
            -- keep the pet over the same plate center, in screen coordinates.
            local plateX, barX = plate:GetCenter(), bar:GetCenter()
            if plateX and barX then
                x = (plateX * plate:GetEffectiveScale() - barX * bar:GetEffectiveScale()) / icon:GetEffectiveScale()
            else
                point, relative, relativePoint, y = "CENTER", plate, "CENTER", -6
            end
        end
    end
    if icon:GetNumPoints() == 1 then
        local p, r, rp, offsetX, offsetY = icon:GetPoint(1)
        if p == point and r == relative and rp == relativePoint and offsetX == x and offsetY == y then
            return
        end
    end
    icon:ClearAllPoints()
    icon:SetPoint(point, relative, relativePoint, x, y)
end

local pets = SarychUI.NameplatePets.Entries
local Pets = SarychUI.NameplatePets
module.NameplatePets, module.NameplatePetOrder = pets, Pets.Order
function module:GetPetDisplayMode() return Pets:GetMode() end
function module:ShouldShowPetCastBar(action) return active and Pets:ShowCastBar(action) or false end
local function Root(plate) return lib.realPlate[plate] or plate end

local function RestoreCastMask(root, state)
    root._suiPetCastBar = nil
    SarychUI.ClassicNameplateArt:RestoreMask(state)
end

local function ApplyCastMask(root, state)
    SarychUI.ClassicNameplateArt:ApplyMask(root, state)
    root._suiPetCastBar = state.host.castBar
end

local function HideIcon(root, state)
    module:UpdatePetLifetime(root)
    if state.icon and state.icon:IsShown() then state.icon:Hide() end
    if root._suiPetIconAnchor then
        root._suiPetIconAnchor = nil
        if _G.sarPlatesAuras_RefreshContainerParent then _G.sarPlatesAuras_RefreshContainerParent(root) end
        if _G.Autolos and _G.Autolos.RefreshNameplate then _G.Autolos.RefreshNameplate(root, {layoutOnly=true}) end
    end
end

local function Restore(root)
    local state = states[root]
    if not state then return end
    RestoreCastMask(root, state)
    HideIcon(root, state)
    if state.host then
        state.host:SetAlpha(state.alpha or 1)
        state.host = nil
    end
end

function module:GetPetDisplay(plate)
    local root = Root(plate)
    if active and root:IsShown() then return Pets:GetAction(root) end
end

function module:GetPetIconTexture(plate)
    local action, texture = self:GetPetDisplay(plate)
    return action == "icons" and texture or nil
end

Paint = function(plate)
    local root = Root(plate)
    local action, texture = module:GetPetDisplay(root)
    SetPetHidden(root, action == "hide")
    if root.UnitFrame then
        -- ElvUI owns its icon-only state. Never fade its UnitFrame or draw a
        -- competing overlay; notify the style engine only when identity changes.
        Restore(root)
        local frame = root.UnitFrame
        local previousTexture = frame._suiPetIconTexture
        local pack = _G.SarychUI_ElvUI_NamePlates
        local np = pack and pack[1] and pack[1]:GetModule("NamePlates", true)
        if np and (frame._suiPetAction ~= action or frame._suiPetIconTexture ~= texture
            or (frame._suiPetCastAllowed == true) ~= module:ShouldShowPetCastBar(action)
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
        module:UpdatePetLifetime(root, texture and frame.IconOnlyChanged and not frame.VisibilityChanged and frame.IconFrame or nil)
        return
    end
    local host = root._suiClassicVisual
    if action then pending[root] = nil end
    if (action ~= "icons" and action ~= "hide") or not host then Restore(root); return end
    local state = states[root]
    if not state then
        state = {}
        states[root] = state
    end
    if state.host ~= host then
        Restore(root)
        state.host, state.alpha = host, host:GetAlpha()
    end
    if module:ShouldShowPetCastBar(action) then
        ApplyCastMask(root, state)
    else
        RestoreCastMask(root, state)
        if host:GetAlpha() ~= 0 then host:SetAlpha(0) end
    end
    if action == "hide" then
        -- Restore aura/distance parenting before hiding the ordinary artwork.
        HideIcon(root, state)
        return
    end
    if not state.icon then
        local icon = CreateFrame("Frame", nil, root)
        icon._suiPlateAura = true -- Keep it outside the classic visual wrapper.
        icon:EnableMouse(false)
        icon:SetSize(32, 32)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0, 1, 0, 1)
        state.icon = icon
    end
    local scale = module.GetNameplateScale and module:GetNameplateScale() or 1
    if state.icon:GetScale() ~= scale then state.icon:SetScale(scale) end
    -- Reapply after scale and on plate reuse, not just on first creation.
    module:AnchorPetIcon(state.icon, root)
    local level = root:GetFrameLevel() + 10
    if state.icon:GetFrameLevel() ~= level then state.icon:SetFrameLevel(level) end
    if state.icon.texture:GetTexture() ~= texture then state.icon.texture:SetTexture(texture) end
    if not state.icon:IsShown() then state.icon:Show() end
    if root._suiPetIconAnchor ~= state.icon then
        root._suiPetIconAnchor = state.icon
        if _G.sarPlatesAuras_RefreshContainerParent then _G.sarPlatesAuras_RefreshContainerParent(root) end
        if _G.Autolos and _G.Autolos.RefreshNameplate then _G.Autolos.RefreshNameplate(root, {layoutOnly=true}) end
    end
    module:UpdatePetLifetime(root, state.icon)
end

function module:PreparePetNameplate(plate)
    local root = Root(plate)
    if not active then return end
    if not prepared[root] then
        prepared[root] = true
        root:HookScript("OnShow", function()
            if active then pending[root] = GetTime() + .25; Paint(root) end
        end)
        root:HookScript("OnHide", function()
            module:UpdatePetLifetime(root)
            pending[root] = nil
            Pets:ForgetPlate(root)
            SetPetHidden(root, false)
            Restore(root)
        end)
        root:HookScript("OnUpdate", function()
            if not active or root.UnitFrame then return end
            -- A short first-show retry handles native text/GUID arriving after
            -- OnShow. Once resolved, only repair an invalidated visual layer;
            -- there is no full identity scan on every rendered frame.
            local deadline = pending[root]
            if deadline then
                if GetTime() <= deadline then Paint(root) else pending[root] = nil end
            else
                local state = states[root]
                if state and state.host then
                    if state.masked then
                        ApplyCastMask(root, state)
                        if state.icon then module:AnchorPetIcon(state.icon, root) end
                    elseif state.host:GetAlpha() ~= 0 then Paint(root) end
                end
            end
        end)
        pending[root] = GetTime() + .25
    end
    Paint(root)
end

local paintedRoots = {}
local function Refresh()
    wipe(paintedRoots)
    for root, visual in pairs(lifetimeVisuals) do
        if not active or not root:IsShown() then HideLifetime(visual) end
    end
    for root in pairs(hiddenRoots) do
        if not active or not root:IsShown() then SetPetHidden(root, false) end
    end
    for root in pairs(states) do if not active or not root:IsShown() then Restore(root) end end
    if active then
        for root in Pets:IterateBoundPlates() do
            if root:IsShown() and not paintedRoots[root] then paintedRoots[root] = true; module:PreparePetNameplate(root) end
        end
        for _, plate in lib:IteratePlates() do
            local root = Root(plate)
            if not paintedRoots[root] then paintedRoots[root] = true; module:PreparePetNameplate(root) end
        end
    end
    local pack = _G.SarychUI_ElvUI_NamePlates
    local np = pack and pack[1] and pack[1]:GetModule("NamePlates", true)
    if np and np.VisiblePlates then
        for plate in pairs(np.VisiblePlates) do
            local root = Root(plate:GetParent())
            if not paintedRoots[root] then
                paintedRoots[root] = true
                if active then module:PreparePetNameplate(root) else Paint(root) end
            end
        end
    end
    wipe(paintedRoots)
end

driver:SetScript("OnEvent", function(_, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if active then
            local root = Pets:BindUnit(...)
            if root then module:PreparePetNameplate(root) end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        for _, root in ipairs(Pets:RemoveUnit(...)) do
            -- The native plate may still be visible after this event. Its
            -- OnHide hook restores artwork safely once nothing can be drawn.
            if not root:IsShown() then SetPetHidden(root, false); Restore(root) end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if Pets:ObserveCombat(...) then Refresh() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local lifetimes = SarychUI.NameplatePetLifetimes
        if lifetimes and lifetimes:ObserveOwnCast(...) then Refresh() end
    else
        -- Keep verified token bindings when ADDED precedes ENTERING_WORLD.
        if event == "PLAYER_ENTERING_WORLD" then Pets:Reset(false) end
        if SarychUI.NameplatePetLifetimes then SarychUI.NameplatePetLifetimes:UpdateOwnPet() end
        Pets:LearnVisibleUnits()
        Refresh()
    end
end)

local callbackOwner = {}
local callbacksRegistered = false
local function SyncCallbacks()
    if not lib.RegisterCallback or not lib.UnregisterCallback or callbacksRegistered == active then return end
    callbacksRegistered = active
    for _, event in ipairs({"LibNameplates_NewNameplate", "LibNameplates_FoundGUID"}) do
        if active then
            lib.RegisterCallback(callbackOwner, event, function(_, plate)
                module:PreparePetNameplate(plate)
            end)
        else
            lib.UnregisterCallback(callbackOwner, event)
        end
    end
end
local elapsed, cleanup = 0, 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed, cleanup = elapsed + delta, cleanup + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    if SarychUI.NameplatePetLifetimes then SarychUI.NameplatePetLifetimes:UpdateOwnPet() end
    if cleanup > 30 then
        cleanup = 0
        Pets:Prune()
    end
    -- Target/mouseover identity can arrive after their change event on the
    -- original client. Retry only these four tokens, not the whole raid roster.
    if not Pets:UseAwesome() then Pets:LearnTrackedUnits() end
    Refresh()
end)

function module:RefreshPetIcons()
    local db = SarychUI:GetModuleProfile("health_indicators")
    if db then db.petIconOffsetY = nil end -- Retire the temporary positioning control.
    local configured = db and (db.petDisplay ~= nil or module:GetPetDisplayMode() == "icons")
    if db and db.petEnabled then
        for _, enabled in pairs(db.petEnabled) do
            if enabled == false then configured = true; break end
        end
    end
    active = db and db.enabled ~= false and configured or false
    SyncCallbacks()
    driver:UnregisterAllEvents()
    if active then
        for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_PET", "UNIT_SPELLCAST_SUCCEEDED", "COMBAT_LOG_EVENT_UNFILTERED"}) do
            driver:RegisterEvent(event)
        end
        if Pets:UseAwesome() then
            driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
            driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        else
            Pets:SyncCompatibility()
        end
        Pets:LearnVisibleUnits()
        if SarychUI.NameplatePetLifetimes then SarychUI.NameplatePetLifetimes:UpdateOwnPet() end
        driver:Show()
    else
        driver:Hide()
        Pets:Reset(true)
        wipe(pending)
    end
    Refresh()
end

function module:DisablePetIcons()
    active = false
    SyncCallbacks()
    driver:UnregisterAllEvents()
    driver:Hide()
    Refresh()
    Pets:Reset(true)
    wipe(pending)
end

function module:DebugPetNameplates()
    local db = SarychUI:GetModuleProfile("health_indicators")
    local lifetimes = SarychUI.NameplatePetLifetimes
    SarychUI:Print(string.format("[Pets] mode=%s display=%s active=%s awesome=%s lifetime=%s castbars=%s targetPlate=%s",
        tostring(SarychUI:GetNameplateMode()), Pets:GetMode(), tostring(active), tostring(Pets:UseAwesome()),
        tostring(db and db.petIconLifetime), tostring(db and db.petIconCastBars), tostring(db and db.petPlateOnTarget)))
    if lifetimes then
        local guid = UnitExists("pet") and UnitGUID("pet") or nil
        local observed, last = lifetimes:GetDiagnostics(guid)
        SarychUI:Print(string.format("[Pets] ownGUID=%s apiRemainingMS=%s summonSpell=%s summonRemaining=%s source=%s",
            tostring(guid), tostring(guid and GetPetTimeRemaining and GetPetTimeRemaining()),
            tostring(observed and observed.spell),
            tostring(observed and math.max(0, math.ceil(observed.start + observed.duration - GetTime()))),
            tostring(observed and observed.source)))
        if last then
            SarychUI:Print(string.format("[Pets] lastSummon guid=%s spell=%s kind=%s age=%s",
                tostring(last.guid), tostring(last.spell), tostring(last.kind), tostring(math.floor(GetTime() - last.time))))
        else SarychUI:Print("[Pets] lastSummon=none") end
    end
    for _, unit in ipairs({"target", "mouseover"}) do
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            SarychUI:Print(string.format("[Pets] %s name=%s guid=%s npc=%s player=%s family=%s",
                unit, tostring(UnitName(unit)), tostring(guid),
                tostring((SarychUI.NameplateIdentity:GetCreatureID(guid))), tostring((UnitIsPlayer(unit))),
                tostring(UnitCreatureFamily and UnitCreatureFamily(unit))))
        end
    end
    local seen, count = {}, 0
    local function Dump(plate)
        local root = Root(plate)
        if seen[root] or not root:IsShown() or count >= 15 then return end
        seen[root] = true; count = count + 1
        local host = root._suiClassicVisual
        local _, timerGUID = Pets:GetLifetimeIdentity(root)
        local timer = lifetimes and lifetimes:GetForPlate(root)
        local visual = lifetimeVisuals[root]
        local state = states[root]
        SarychUI:Print("[Pets] " .. Pets:Describe(root) .. " hostAlpha="
            .. tostring(host and host:GetAlpha()) .. " icon=" .. tostring(root._suiPetIconAnchor ~= nil)
            .. " hpMask=" .. tostring(state and state.masked and state.maskHost and state.maskHost:GetAlpha())
            .. " casting=" .. tostring(root._suiPetCastBar and root._suiPetCastBar:IsShown() or false)
            .. " timerGUID=" .. tostring(timerGUID)
            .. " remaining=" .. tostring(timer and math.ceil(timer.start + timer.duration - GetTime()))
            .. " timerShown=" .. tostring(visual and visual:IsShown() or false))
    end
    for root in Pets:IterateBoundPlates() do Dump(root) end
    for _, plate in lib:IteratePlates() do Dump(plate) end
end

if SarychUI.RegisterChatCommand then
    SarychUI:RegisterChatCommand("suipets", function() module:DebugPetNameplates() end)
end
