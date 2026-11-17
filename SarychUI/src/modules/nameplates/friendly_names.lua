-- Classic rendering adapter for the shared friendly-player class resolver.
local module = SarychUI.modules.health_indicators
local lib = LibStub("LibNameplates-1.0", true)
if not lib then return end

local driver = CreateFrame("Frame")
driver:Hide()
local active = false
local Classes = SarychUI.FriendlyNameplateClasses
local painted = setmetatable({}, {__mode = "k"})
local seen = {}
local changing = setmetatable({}, {__mode = "k"})
local hookedPlates = setmetatable({}, {__mode = "k"})
local hookedText = setmetatable({}, {__mode = "k"})
local Paint

local function UseAwesome()
    return Classes:UseAwesome()
end

local function DirectUnit(plate)
    return Classes:GetPlateUnit(plate)
end

local function SameName(name, unitName, realm)
    return name == unitName or (unitName and realm and name == unitName .. "-" .. realm)
end

local function SameColor(fs, color)
    local r,g,b,a = fs:GetTextColor()
    return math.abs(r-color[1]) < .001 and math.abs(g-color[2]) < .001
        and math.abs(b-color[3]) < .001 and math.abs((a or 1)-(color[4] or 1)) < .001
end

local function SameRGB(fs, color)
    local r,g,b = fs:GetTextColor()
    return math.abs(r-color[1]) < .001 and math.abs(g-color[2]) < .001
        and math.abs(b-color[3]) < .001
end

local function IsWhite(fs)
    local r,g,b = fs:GetTextColor()
    return math.abs(r-1) < .001 and math.abs(g-1) < .001 and math.abs(b-1) < .001
end

local function Restore(plate)
    local state = painted[plate]
    if not state then return end
    local wasChanging = changing[plate]
    changing[plate] = true
    painted[plate] = nil
    if SameColor(state.text, state.applied) then state.text:SetTextColor(unpack(state.original)) end
    changing[plate] = wasChanging
end

local function Prepare(plate)
    if plate.UnitFrame then return end
    local repaint = hookedPlates[plate]
    if not repaint then
        repaint = function()
            if active and not changing[plate] then
                Paint(plate, UseAwesome() and DirectUnit(plate) or nil)
            end
        end
        hookedPlates[plate] = repaint
        plate:HookScript("OnShow", repaint)
        plate:HookScript("OnHide", function() Restore(plate) end)
    end
    local fs = lib:GetNameRegion(plate)
    if fs and not hookedText[fs] and hooksecurefunc then
        hookedText[fs] = true
        for _, method in ipairs({"SetText", "SetFormattedText", "SetTextColor"}) do
            if fs[method] then hooksecurefunc(fs, method, repaint) end
        end
    end
end

local function PaintNow(plate, directUnit, beforeShow)
    Prepare(plate)
    if not active or plate.UnitFrame or (not beforeShow and not plate:IsShown()) then
        Restore(plate); return
    end
    if directUnit then
        -- Awesome gives authoritative identity/reaction, independent of bar colour
        -- and independent of LibNameplates' delayed mouseover/GUID discovery.
        if not UnitIsPlayer(directUnit) or not UnitIsFriend("player", directUnit) then Restore(plate); return end
    elseif UseAwesome() or (lib.plateChildren and not lib.plateChildren[plate])
        or lib:GetType(plate) ~= "PLAYER" or lib:GetReaction(plate) ~= "FRIENDLY" then
        Restore(plate); return
    end
    local fs = lib:GetNameRegion(plate)
    local name
    if fs and fs.GetText then
        name = fs:GetText()
        if name then name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
    elseif not lib.plateRegions or lib.plateRegions[plate] then
        name = lib:GetName(plate)
    end
    local state = painted[plate]
    if state and (state.name ~= name or state.text ~= fs) then Restore(plate); state = nil end
    if directUnit and not SameName(name, UnitName(directUnit)) then Restore(plate); return end
    if not fs then Restore(plate); return end
    -- Class colour replaces only neutral white (or our own previous colour).
    -- Native damage/reaction colours take ownership until white returns.
    if not IsWhite(fs) and not (state and SameRGB(fs, state.applied)) then
        painted[plate] = nil
        return
    end
    local class = name and Classes:ResolvePlate(plate, name, plate.namePlateUnitToken)
    local color = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or RAID_CLASS_COLORS[class])
    if not fs or not color then Restore(plate); return end
    if not state then
        state = {text=fs, name=name, original={fs:GetTextColor()}}
        painted[plate] = state
    else
        -- Alpha changes do not turn our class colour into a native base colour.
        state.original[4] = select(4, fs:GetTextColor()) or 1
    end
    state.applied = {color.r, color.g, color.b, state.original[4] or 1}
    if not SameColor(fs, state.applied) then fs:SetTextColor(unpack(state.applied)) end
end

Paint = function(plate, directUnit, beforeShow)
    if changing[plate] then return end
    changing[plate] = true
    PaintNow(plate, directUnit, beforeShow)
    changing[plate] = nil
end

-- Called as soon as the classic adapter discovers a frame, before its first show.
function module:PrepareFriendlyNameplate(plate)
    Prepare(plate)
    if active then Paint(plate, UseAwesome() and DirectUnit(plate) or nil) end
end

local function Refresh()
    local awesome = UseAwesome()
    if awesome then
        wipe(seen)
        for _, plate in pairs(C_NamePlate.GetNamePlates() or {}) do
            seen[plate] = true
            Paint(plate, DirectUnit(plate))
        end
        for plate in pairs(painted) do if not seen[plate] then Restore(plate) end end
        wipe(seen)
        return
    end
    for plate in pairs(painted) do Paint(plate) end
    if active then
        for _, plate in lib:IteratePlates() do
            local root = lib.realPlate[plate] or plate
            if not painted[root] then Paint(root) end
        end
    end
end

Classes.OnChanged = function(plate, beforeShow, removed)
    if active then
        if plate then
            if removed then Restore(plate) else Paint(plate, DirectUnit(plate), beforeShow) end
        else Refresh() end
    end
    if SarychUI:GetNameplateMode() == "elvui" then
        local E = _G.SarychUI_ElvUI_NamePlates and _G.SarychUI_ElvUI_NamePlates[1]
        local NP = E and E:GetModule("NamePlates", true)
        if NP and NP.Initialized and NP.RefreshFriendlyClasses then NP:RefreshFriendlyClasses(plate, removed) end
    end
end

local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < .1 then return end
    elapsed = 0
    Refresh()
end)

local function StopClassic()
    active = false
    elapsed = 0
    driver:UnregisterAllEvents(); driver:Hide()
    wipe(seen)
    for plate in pairs(painted) do Restore(plate) end
end

function module:DisableFriendlyClassNames()
    StopClassic()
    Classes:SetEnabled(false)
end

function module:RefreshFriendlyClassNames()
    local db = SarychUI:GetModuleProfile("health_indicators")
    local classic = SarychUI:GetNameplateMode() == "classic"
    local enabled = db and db.enabled ~= false
    local paint = enabled and classic and db.friendlyClassNames
    if not paint then StopClassic() end
    -- Identity belongs to the running nameplate module, not the colour toggle.
    -- Awesome emits ADDED once; stopping the shared resolver here loses tokens
    -- for already visible Classic frames which have no namePlateUnitToken field.
    -- Keep its existing lifetime bindings so enabling colour can paint at once.
    Classes:SetEnabled(enabled)
    if not paint then return end
    active = true
    Refresh(); driver:Show()
end
