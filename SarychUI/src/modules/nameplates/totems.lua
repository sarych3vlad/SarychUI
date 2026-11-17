-- Rendering adapters; recognition and display policy live in NameplateTotems.
local module = SarychUI.modules.health_indicators
local Totems = SarychUI.NameplateTotems
local lib = LibStub("LibNameplates-1.0", true)
if not lib then return end
local driver = CreateFrame("Frame")
driver:Hide()
local active = false
local states, hooked = {}, setmetatable({}, {__mode="k"})
local Paint

local function SetDistanceAnchor(root, icon)
    if root._suiTotemIconAnchor == icon then return end
    root._suiTotemIconAnchor = icon
    if _G.Autolos and _G.Autolos.RefreshNameplate then
        _G.Autolos.RefreshNameplate(root, {layoutOnly=true})
    end
end

local function Restore(root)
    SarychUI.NameplateVisibility:SetHidden(root, "totem", false)
    local state = states[root]
    if not state then return end
    if state.icon then state.icon:Hide() end
    SetDistanceAnchor(root, nil)
    if state.host then state.host:SetAlpha(state.alpha); state.host = nil end
end

local function ClassicAction(root)
    local fs = lib:GetNameRegion(root)
    local name = fs and fs.GetText and fs:GetText()
    if not name and lib.plateRegions[root] then name = lib:GetName(root) end
    if not name or (lib.plateChildren and not lib.plateChildren[root]) then return end
    return Totems:GetAction(name, lib:GetGUID(root), lib:GetType(root) ~= "NPC")
end

function module:GetTotemDisplay(frame)
    if not active then return end
    return Totems:GetAction(frame.UnitName, frame.guid,
        frame.UnitType ~= "FRIENDLY_NPC" and frame.UnitType ~= "ENEMY_NPC")
end

function module:PrepareTotemNameplate(root)
    if not active then return end
    if not hooked[root] then
        hooked[root] = true
        root:HookScript("OnShow", function() if active then Paint(root) end end)
        root:HookScript("OnHide", function() Restore(root) end)
    end
    if active then Paint(root) end
end

Paint = function(root)
    if root.UnitFrame then
        Restore(root)
        local frame = root.UnitFrame
        local action, texture = module:GetTotemDisplay(frame)
        local pack = _G.SarychUI_ElvUI_NamePlates
        local np = pack and pack[1] and pack[1]:GetModule("NamePlates", true)
        if np and (frame._suiTotemAction ~= action or frame._suiTotemTexture ~= texture) then
            np:StyleFilterUpdate(frame, "SARYCHUI_TOTEM")
        end
        return
    end
    if not active or not root:IsShown() or SarychUI:GetNameplateMode() ~= "classic" then Restore(root); return end
    local action, texture = ClassicAction(root)
    local host = root._suiClassicVisual
    if not host or (action ~= "hide" and action ~= "icons") then Restore(root); return end
    local state = states[root]
    if not state then state = {}; states[root] = state end
    if state.host ~= host then
        Restore(root)
        state.host, state.alpha = host, host:GetAlpha()
    end
    host:SetAlpha(0)
    SarychUI.NameplateVisibility:SetHidden(root, "totem", action == "hide")
    if action == "hide" or not texture then
        if state.icon then state.icon:Hide() end
        SetDistanceAnchor(root, nil)
        return
    end
    if not state.icon then
        local icon = CreateFrame("Frame", nil, root)
        icon._suiPlateAura = true
        icon:EnableMouse(false)
        icon:SetSize(32,32)
        icon:SetPoint("CENTER", root, "CENTER", 0, -6)
        icon.texture = icon:CreateTexture(nil,"ARTWORK")
        icon.texture:SetAllPoints()
        state.icon = icon
    end
    local scale = module.GetNameplateScale and module:GetNameplateScale() or 1
    if state.icon:GetScale() ~= scale then state.icon:SetScale(scale) end
    local level = root:GetFrameLevel() + 10
    if state.icon:GetFrameLevel() ~= level then state.icon:SetFrameLevel(level) end
    if state.icon.texture:GetTexture() ~= texture then state.icon.texture:SetTexture(texture) end
    if not state.icon:IsShown() then state.icon:Show() end
    SetDistanceAnchor(root, state.icon)
end

local function Refresh()
    for root in pairs(states) do if not active or not root:IsShown() then Restore(root) end end
    for _, plate in lib:IteratePlates() do
        local root = lib.realPlate[plate] or plate
        module:PrepareTotemNameplate(root)
        if not active then Paint(root) end
    end
    local pack = _G.SarychUI_ElvUI_NamePlates
    local np = pack and pack[1] and pack[1]:GetModule("NamePlates", true)
    if np and np.VisiblePlates then
        for frame in pairs(np.VisiblePlates) do Paint(frame:GetParent()) end
    end
end

driver:SetScript("OnEvent", Refresh)
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < .1 then return end
    elapsed = 0; Refresh()
end)

function module:RefreshTotems()
    local db = SarychUI:GetModuleProfile("health_indicators")
    local configured = db and db.totemDisplay ~= nil
    if db and db.totemEnabled then
        for _, enabled in pairs(db.totemEnabled) do if enabled == false then configured = true; break end end
    end
    active = db and db.enabled ~= false and configured or false
    driver:UnregisterAllEvents()
    -- ElvUI already calls its style engine on show and identity updates.
    if active and SarychUI:GetNameplateMode() == "classic" then
        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
        driver:RegisterEvent("PLAYER_TARGET_CHANGED")
        driver:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        driver:Show()
    else
        driver:Hide()
    end
    Refresh()
end

function module:DisableTotems()
    active = false; elapsed = 0
    driver:UnregisterAllEvents(); driver:Hide()
    Refresh()
end
