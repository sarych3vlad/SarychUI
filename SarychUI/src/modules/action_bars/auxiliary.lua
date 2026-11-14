-- Independent visibility and position controls for the stock button chains.
local module = SarychUI.modules.mainmenubar
local groups = {
    bags = {
        root = "MainMenuBarBackpackButton", shown = "bagsShown", position = "bagPosition",
        title = "ui.bags_a5b99f75", id = "ActionBarBags",
        buttons = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
            "CharacterBag2Slot", "CharacterBag3Slot", "KeyRingButton" },
    },
    micro = {
        root = "CharacterMicroButton", shown = "microMenuShown", position = "microMenuPosition",
        title = "ui.micro_menu_0fc8f435", id = "ActionBarMicroMenu",
        buttons = { "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
            "AchievementMicroButton", "QuestLogMicroButton", "SocialsMicroButton", "PVPMicroButton",
            "LFDMicroButton", "MainMenuMicroButton", "HelpMicroButton", "ParagonMicroButton",
            "CollectionsMicroButton", "StoreMicroButton", "SarychUIMicroMenu" },
    },
}
local active, applying, stopping, restoringDefaults
local parents, hooked = {}, {}
local hiddenParent
local backpackBaseScale, backpackClassicPoint, backpackClassicBagPoint
local watcher = CreateFrame("Frame")
watcher:Hide()

local function VehicleOwnsMicroMenu()
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return true end
    if VehicleMenuBarArtFrame then
        for _, name in ipairs(groups.micro.buttons) do
            local button = _G[name]
            if button and button:GetParent() == VehicleMenuBarArtFrame then return true end
        end
    end
    return false
end

local function LayoutAnimating()
    return (MainMenuBar and MainMenuBar.animating) or (VehicleMenuBar and VehicleMenuBar.animating)
end

local function QueueRefresh()
    if active and not stopping then watcher:Show() end
end

local function DB()
    return SarychUI.db.profile.modules.mainmenubar
end

function module:GetAuxiliaryPosition(group)
    local key = groups[group].position
    local db = DB()
    if type(db[key]) ~= "table" then db[key] = { enabled = false } end
    return db[key]
end

local function CloseEditor(def)
    local drag, panel = SarychUI.DragMode, SarychUI.PositionDragPanel
    if drag and panel and drag:IsPositionEditorOpen(def.id) then panel:Close(true) end
end

-- Layout owners pass their native anchor here before setting the button position.
-- DragMode writes the same saved coordinates; there is no second positioning pass.
local anchorOffset = {
    CENTER = {0, 0}, TOP = {0, .5}, BOTTOM = {0, -.5},
    LEFT = {-.5, 0}, RIGHT = {.5, 0}, TOPLEFT = {-.5, .5},
    TOPRIGHT = {.5, .5}, BOTTOMLEFT = {-.5, -.5}, BOTTOMRIGHT = {.5, -.5},
}

local function BackpackScaleFactor()
    local db = DB()
    if db.backpackScaleEnabled ~= true then return 1 end
    return math.max(0.5, math.min(2, tonumber(db.backpackScale) or 1))
end

-- Measure the row in the original backpack's units. Classic bags are centred
-- on its left edge; BFA/Dragon use a slightly lower row of 95%-scale slots.
local function BackpackRowGeometry()
    local root, bag = MainMenuBarBackpackButton, CharacterBag0Slot
    if not root or not bag then return 0, 1 end
    local base = backpackBaseScale or root:GetScale()
    local point, relative, relativePoint, x, y
    local bagScale = bag:GetScale()
    if module:GetBootBarStyle() == "classic" then
        if backpackClassicBagPoint then
            point, relative, relativePoint, x, y = unpack(backpackClassicBagPoint)
        else
            point, relative, relativePoint, x, y = bag:GetPoint()
        end
        if relative ~= root then return 0, 1 end
    else
        point, relativePoint, y, bagScale = "BOTTOMLEFT", "CENTER", -20, 0.95
    end
    local ratio = bagScale / base
    local rowY = anchorOffset[relativePoint][2] * root:GetHeight()
        + (y - anchorOffset[point][2] * bag:GetHeight()) * ratio
    return rowY, bag:GetHeight() * ratio / root:GetHeight()
end

local function BackpackScaleShift(factor)
    local root = MainMenuBarBackpackButton
    local rowY, equalHeight = BackpackRowGeometry()
    -- Interpolate through the untouched 100% layout and the exact point at
    -- which backpack and bag heights match. Do not measure live screen Y:
    -- it changes during dragging and Vehicle animation.
    local y = math.abs(equalHeight - 1) > 0.0001
        and rowY * (factor - 1) / (equalHeight - 1) or 0
    -- Keep the left edge fixed while retaining the row's vertical alignment.
    return root:GetWidth() * (factor - 1) / 2, y
end

local function ScaledBackpackPoint(point, x, y)
    local root = MainMenuBarBackpackButton
    local ratio = (backpackBaseScale or root:GetScale()) / root:GetScale()
    local dx, dy = BackpackScaleShift(1 / ratio)
    local offset = anchorOffset[point]
    return x * ratio + offset[1] * root:GetWidth() * (1 - ratio) + dx * ratio,
        y * ratio + offset[2] * root:GetHeight() * (1 - ratio) + dy * ratio
end

-- Retain the stock button chain, but anchor its first slot to the backpack's
-- original geometry. Scaling the backpack must not drag the whole row along.
function module:GetBackpackSlotPoint(frame, point, relativePoint, x, y)
    local root = MainMenuBarBackpackButton
    local factor = root:GetScale() / (backpackBaseScale or root:GetScale())
    local dx, dy = BackpackScaleShift(factor)
    local offset = anchorOffset[relativePoint]
    local ratio = root:GetEffectiveScale() / factor / frame:GetEffectiveScale()
    return point, root, relativePoint,
        x + (offset[1] * root:GetWidth() * (1 - factor) - dx) * ratio,
        y + (offset[2] * root:GetHeight() * (1 - factor) - dy) * ratio
end

local function ApplyBackpackScale(restore)
    local root = MainMenuBarBackpackButton
    if not root then return end
    backpackBaseScale = backpackBaseScale or root:GetScale()
    local scale = backpackBaseScale * (restore and 1 or BackpackScaleFactor())
    if root:GetScale() == scale then return end
    CloseEditor(groups.bags)
    if module:GetBootBarStyle() == "classic" and not backpackClassicPoint then
        backpackClassicPoint = { root:GetPoint() }
        if CharacterBag0Slot then backpackClassicBagPoint = { CharacterBag0Slot:GetPoint() } end
    end
    root:SetScale(scale)
    if backpackClassicPoint and module:GetBootBarStyle() == "classic" then
        local point, relative, relativePoint, x, y = unpack(backpackClassicPoint)
        x, y = ScaledBackpackPoint(point, x, y)
        root:ClearAllPoints()
        root:SetPoint(point, relative, relativePoint, x, y)
        if backpackClassicBagPoint then
            point, relative, relativePoint, x, y = unpack(backpackClassicBagPoint)
            if relative == root then
                CharacterBag0Slot:ClearAllPoints()
                CharacterBag0Slot:SetPoint(module:GetBackpackSlotPoint(CharacterBag0Slot, point, relativePoint, x, y))
            end
        end
        if scale == backpackBaseScale then backpackClassicPoint, backpackClassicBagPoint = nil, nil end
    end
end

local function CustomPosition(group)
    if restoringDefaults or module:GetBootBarStyle() == "classic" then return end
    local cfg = module:GetAuxiliaryPosition(group)
    if cfg.enabled and type(cfg.x) == "number" and type(cfg.y) == "number" then return cfg end
end

function module:GetAuxiliaryLayoutPoint(group, point, relative, relativePoint, x, y)
    groups[group].defaultPoint = {point, relative, relativePoint, x, y}
    local cfg = CustomPosition(group)
    if cfg then
        -- Saved/editor coordinates use UIParent, but the live buttons must ride
        -- MainMenuBar's native Vehicle slide. Both layouts rest at BOTTOM (0, 0).
        -- Convert against that resting position, never against an animation's
        -- current position (which would cancel the slide on every layout pass).
        local root = _G[groups[group].root]
        local ratio = UIParent:GetEffectiveScale() / root:GetEffectiveScale()
        local offset = anchorOffset[cfg.relativePoint or "CENTER"]
        return cfg.point or "CENTER", MainMenuBar, "BOTTOM",
            cfg.x + offset[1] * UIParent:GetWidth() * ratio,
            cfg.y + (offset[2] + .5) * UIParent:GetHeight() * ratio
    end
    -- Keep the default micro menu independent when only the bags have moved.
    -- Both layouts anchor the backpack to the main bar's bottom edge.
    local bagDefault = groups.bags.defaultPoint
    if group == "micro" and relative == MainMenuBarBackpackButton
        and (CustomPosition("bags") or (backpackBaseScale
            and MainMenuBarBackpackButton:GetScale() ~= backpackBaseScale)) and bagDefault then
        local from, to = anchorOffset[bagDefault[1]], anchorOffset[relativePoint]
        local root = MainMenuBarBackpackButton
        return point, bagDefault[2], bagDefault[3],
            bagDefault[4] + (to[1] - from[1]) * root:GetWidth() + x,
            bagDefault[5] + (to[2] - from[2]) * root:GetHeight() + y
    end
    if group == "bags" then x, y = ScaledBackpackPoint(point, x, y) end
    return point, relative, relativePoint, x, y
end

function module:SetAuxiliaryLayoutPoint(group, frame, ...)
    if not frame then return end
    local point, relative, relativePoint, x, y = self:GetAuxiliaryLayoutPoint(group, ...)
    local drag = SarychUI.DragMode
    local data = drag and drag:GetFrameData(groups[group].id)
    -- The native layout must not interrupt StartMoving or its two-frame settle.
    if data and (data.isMoving or (data._settleUpdater
        and data._settleUpdater:GetScript("OnUpdate"))) then return end
    frame:ClearAllPoints()
    frame:SetPoint(point, relative, relativePoint, x, y)
end

local function ApplyPlayerLayout()
    local style = module:GetBootBarStyle() == "bfa" and module.BFAStyle
        or module:GetBootBarStyle() == "dragon" and module.DragonStyle
    if style and style.active then style:LayoutBagsAndMicroMenu() end
end

local function Refresh()
    if not applying and not stopping then module:ApplyAuxiliaryControls() end
end

local function EnsureGroup(def)
    local root = _G[def.root]
    if not root then return end
    for _, name in ipairs(def.buttons) do
        local button = _G[name]
        if button then
            if not parents[button] then parents[button] = button:GetParent() end
            if not hooked[button] then
                hooked[button] = true
                hooksecurefunc(button, "SetParent", function(frame, parent)
                    if not active or applying then return end
                    parents[frame] = parent
                    -- Visibility waits for FrameXML to finish reparenting the chain.
                    QueueRefresh()
                end)
            end
        end
    end
    return root
end

local function CurrentCoordinates(root)
    local x, y = root:GetCenter()
    local cx, cy = UIParent:GetCenter()
    local scale = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    -- Saved offsets and DragMode's SetPoint use the moved frame's units.
    return (x or 0) - cx / scale, (y or 0) - cy / scale
end

local function GroupBounds(def)
    local left, bottom, right, top
    for _, name in ipairs(def.buttons) do
        local button = _G[name]
        -- The compatibility holder is not artwork; its rectangle may cover
        -- unrelated bars. Measure the concrete buttons inside the group.
        if button and name ~= "SarychUIMicroMenu" and button:IsVisible() then
            -- Micro art can be much smaller than its mouse hit area. Bag rims
            -- have transparent padding, so use their icon (or the slot itself).
            local art = def == groups.micro and button.GetNormalTexture and button:GetNormalTexture()
                or _G[name .. "IconTexture"]
            local x, y, w, h
            -- A pressed/disabled button temporarily hides its normal texture;
            -- the artwork's geometry still describes the same button.
            if art and (def == groups.micro or art:IsShown()) then
                x, y, w, h = art:GetLeft(), art:GetBottom(), art:GetWidth(), art:GetHeight()
            end
            if not (x and y and w and h and w > 0 and h > 0) then
                x, y, w, h = button:GetRect()
            end
            if x and y and w and h and w > 0 and h > 0 then
                local ratio = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
                x, y, w, h = x * ratio, y * ratio, w * ratio, h * ratio
                left = left and math.min(left, x) or x
                bottom = bottom and math.min(bottom, y) or y
                right = right and math.max(right, x + w) or x + w
                top = top and math.max(top, y + h) or y + h
            end
        end
    end
    return left, bottom, right, top
end

function module:ApplyAuxiliaryControls()
    if not active or applying or stopping then return end
    if InCombatLockdown() then
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if VehicleOwnsMicroMenu() or LayoutAnimating() then
        applying = true
        for _, def in pairs(groups) do CloseEditor(def) end
        applying = false
        -- Never impose player anchors/hidden parents on the native vehicle UI.
        -- Poll only an active animation; vehicle/combat waits use events.
        if LayoutAnimating() then QueueRefresh() end
        return
    end
    applying = true
    hiddenParent = hiddenParent or CreateFrame("Frame", nil, UIParent)
    hiddenParent:Hide()
    EnsureGroup(groups.bags)
    EnsureGroup(groups.micro)
    ApplyBackpackScale()
    ApplyPlayerLayout()
    local positioningAllowed = self:GetBootBarStyle() ~= "classic"
    for _, key in ipairs({ "bags", "micro" }) do
        local def = groups[key]
        local root = _G[def.root]
        if root then
            local cfg = self:GetAuxiliaryPosition(key)
            local shown = DB()[def.shown] ~= false
            if not shown or not cfg.enabled or not positioningAllowed then CloseEditor(def) end
            for _, name in ipairs(def.buttons) do
                local button = _G[name]
                if button then
                    local buttonShown = shown and not (key == "bags"
                        and DB().backpackOnly == true and name ~= def.root)
                    local parent = buttonShown and parents[button] or hiddenParent
                    if button:GetParent() ~= parent then button:SetParent(parent) end
                end
            end
            if cfg.enabled and positioningAllowed then
                if cfg.x == nil or cfg.y == nil then
                    cfg.x, cfg.y = CurrentCoordinates(root)
                    cfg.point, cfg.relativePoint = "CENTER", "CENTER"
                end
                local drag = SarychUI.DragMode
                if shown and drag and SarychUI.PositionDragPanel then
                    drag:RegisterPositionEditor(def.id, root, {
                        title = def.title,
                        getConfig = function() return module:GetAuxiliaryPosition(key) end,
                        onApply = Refresh, onClosed = Refresh, notifyPreview = Refresh,
                    }, {
                        clampToScreen = false,
                        getDragBounds = function() return GroupBounds(def) end,
                    })
                    if drag.RefreshDragOverlay then drag:RefreshDragOverlay(def.id) end
                elseif drag then
                    drag:UnregisterFrame(def.id)
                end
            else
                if SarychUI.DragMode then SarychUI.DragMode:UnregisterFrame(def.id) end
            end
        end
    end
    applying = false
end

function module:SetBackpackScale(enabled, value)
    if not InCombatLockdown() then CloseEditor(groups.bags) end
    local oldFactor = BackpackScaleFactor()
    if enabled ~= nil then DB().backpackScaleEnabled = enabled == true end
    if value ~= nil then
        value = math.max(0.5, math.min(2, tonumber(value) or 1))
        local _, equalHeight = BackpackRowGeometry()
        -- The 5% slider should be able to land on the exact slot height too.
        if equalHeight >= 0.5 and equalHeight <= 2 and math.abs(value - equalHeight) <= 0.025 then
            value = equalHeight
        end
        DB().backpackScale = value
    end
    local ratio = oldFactor / BackpackScaleFactor()
    local cfg = self:GetAuxiliaryPosition("bags")
    if cfg.enabled and cfg.x and cfg.y and ratio ~= 1 then
        local offset = anchorOffset[cfg.point or "CENTER"]
        local root = MainMenuBarBackpackButton
        local oldX, oldY = BackpackScaleShift(oldFactor)
        local newX, newY = BackpackScaleShift(BackpackScaleFactor())
        cfg.x = cfg.x * ratio + offset[1] * root:GetWidth() * (1 - ratio)
            + (newX - oldX) / BackpackScaleFactor()
        cfg.y = cfg.y * ratio + offset[2] * root:GetHeight() * (1 - ratio)
            + (newY - oldY) / BackpackScaleFactor()
    end
    self:ApplyAuxiliaryControls()
end

function module:SetBackpackOnly(enabled)
    DB().backpackOnly = enabled == true
    self:ApplyAuxiliaryControls()
    if self.UpdateTransparencyHover then self:UpdateTransparencyHover() end
end

function module:SetAuxiliaryShown(group, shown)
    DB()[groups[group].shown] = shown
    self:ApplyAuxiliaryControls()
    self:ApplyBarVisibilitySettings()
    self:UpdateTransparencyHover()
end

function module:SetAuxiliaryPositionEnabled(group, enabled)
    local def = groups[group]
    CloseEditor(def)
    local cfg = self:GetAuxiliaryPosition(group)
    cfg.enabled = enabled
    if not enabled then
        cfg.x, cfg.y, cfg.point, cfg.relativePoint = nil, nil, nil, nil
    end
    self:ApplyAuxiliaryControls()
end

function module:SetAuxiliaryCoordinate(group, axis, value)
    local cfg = self:GetAuxiliaryPosition(group)
    cfg[axis] = value
    local panel = SarychUI.PositionDragPanel
    if panel and panel:SyncDraftIfOpen(groups[group].id, cfg.x, cfg.y,
        cfg.point or "CENTER", cfg.relativePoint or "CENTER") then return end
    self:ApplyAuxiliaryControls()
end

function module:ToggleAuxiliaryMover(group)
    if InCombatLockdown() or VehicleOwnsMicroMenu() or LayoutAnimating() then return end
    self:ApplyAuxiliaryControls()
    local drag = SarychUI.DragMode
    if drag and drag:GetFrameData(groups[group].id) then
        drag:TogglePositionEditor(groups[group].id)
    end
end

function module:EnableAuxiliaryControls()
    active, stopping = true, false
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
    watcher:RegisterEvent("UI_SCALE_CHANGED")
    watcher:RegisterEvent("UNIT_ENTERING_VEHICLE")
    watcher:RegisterEvent("UNIT_ENTERED_VEHICLE")
    watcher:RegisterEvent("UNIT_EXITED_VEHICLE")
    self:ApplyAuxiliaryControls()
end

function module:DisableAuxiliaryControls()
    if InCombatLockdown() then
        stopping = true
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    stopping, active = true, false
    for _, def in pairs(groups) do
        CloseEditor(def)
        if SarychUI.DragMode then SarychUI.DragMode:UnregisterFrame(def.id) end
    end
    ApplyBackpackScale(true)
    if not VehicleOwnsMicroMenu() and not LayoutAnimating() then
        restoringDefaults = true
        ApplyPlayerLayout()
        restoringDefaults = false
    end
    for button, parent in pairs(parents) do button:SetParent(parent) end
    parents = {}
    backpackBaseScale, backpackClassicPoint, backpackClassicBagPoint = nil, nil, nil
    watcher:UnregisterAllEvents()
    watcher:Hide()
    stopping = false
end

watcher:SetScript("OnEvent", function(_, event, unit)
    if event:find("^UNIT_") and unit ~= "player" then return end
    if event == "UNIT_ENTERING_VEHICLE" and not InCombatLockdown() then
        applying = true
        for _, def in pairs(groups) do CloseEditor(def) end
        applying = false
    end
    if event == "PLAYER_REGEN_ENABLED" then
        watcher:UnregisterEvent(event)
        if stopping then module:DisableAuxiliaryControls(); return end
    end
    QueueRefresh()
end)

local elapsedSinceRefresh = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceRefresh = elapsedSinceRefresh + elapsed
    if elapsedSinceRefresh < 0.05 then return end
    elapsedSinceRefresh = 0
    self:Hide()
    module:ApplyAuxiliaryControls()
end)
