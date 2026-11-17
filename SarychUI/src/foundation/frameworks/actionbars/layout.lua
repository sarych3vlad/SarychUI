local Framework = SarychUI.ActionBars

function Framework:HasTotemBar()
    return HasMultiCastActionBar and HasMultiCastActionBar()
end

function Framework:HasClassBar()
    return (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) > 0
        or self:HasTotemBar()
end

-- Keep FrameXML's totem buttons, pages, flyouts and slide animation intact.
-- The caller supplies the same row origin it uses for stance buttons.
function Framework:LayoutTotemBar(style, parent, left, bottom)
    local frame = MultiCastActionBarFrame
    if not frame or not parent or InCombatLockdown() then return end
    if not style._totemLayout then
        local state = {frame=frame, parent=frame:GetParent(), points={},
            x=MULTICASTACTIONBAR_XPOS, y=MULTICASTACTIONBAR_YPOS, managed={}}
        for i = 1, frame:GetNumPoints() do state.points[i] = {frame:GetPoint(i)} end
        if UIPARENT_MANAGED_FRAME_POSITIONS then
            for _, name in ipairs({"MultiCastActionBarFrame", "MULTICASTACTIONBAR_YPOS"}) do
                state.managed[name] = UIPARENT_MANAGED_FRAME_POSITIONS[name]
                UIPARENT_MANAGED_FRAME_POSITIONS[name] = nil
            end
        end
        style._totemLayout = state
    end
    if frame:GetParent() ~= parent then frame:SetParent(parent) end
    -- The first visible native button has a (+3,+3) inset. Native slides use
    -- BOTTOMLEFT -> parent's TOPLEFT, so convert the row's bottom-centre origin.
    MULTICASTACTIONBAR_XPOS = parent:GetWidth() / 2 + left - 3
    MULTICASTACTIONBAR_YPOS = bottom - parent:GetHeight() - 3
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", MULTICASTACTIONBAR_XPOS, MULTICASTACTIONBAR_YPOS)
end

function Framework:RestoreTotemBar(style)
    local state = style._totemLayout
    if not state or InCombatLockdown() then return end
    local frame = state.frame
    frame:SetParent(state.parent)
    frame:ClearAllPoints()
    for _, point in ipairs(state.points) do frame:SetPoint(unpack(point)) end
    MULTICASTACTIONBAR_XPOS, MULTICASTACTIONBAR_YPOS = state.x, state.y
    if UIPARENT_MANAGED_FRAME_POSITIONS then
        for _, name in ipairs({"MultiCastActionBarFrame", "MULTICASTACTIONBAR_YPOS"}) do
            UIPARENT_MANAGED_FRAME_POSITIONS[name] = state.managed[name]
        end
    end
    style._totemLayout = nil
end

-- Shared policy: beside stances, align right; otherwise centre the pet row.
-- Coordinates and dimensions belong to the consuming layout.
function Framework:PetLeft(left, right, width, forms, centerOffset)
    if forms > 0 then return right - width end
    return (left + right - width) / 2 + (centerOffset or 0)
end

-- Reserve the row even while the pet is absent, ready for a secure combat summon.
function Framework:PetRow(left, right, width, forms, bottom, height, gap, centerOffset)
    if self:HasTotemBar() then return left, bottom + height + gap end
    return self:PetLeft(left, right, width, forms, centerOffset), bottom
end

local function NativeRowY(position)
    if not position or type(position.baseY) ~= "number" then return end
    local y = position.baseY + (position.yOffset or 0)
    if not Framework:InVehicle() then
        if MultiBarBottomLeft and MultiBarBottomLeft:IsShown() then y = y + (position.bottomLeft or 0) end
        if ReputationWatchBar and ReputationWatchBar:IsShown() and MainMenuExpBar and MainMenuExpBar:IsShown() then
            y = y + (position.reputation or 0)
        end
        if MainMenuBarMaxLevelBar and MainMenuBarMaxLevelBar:IsShown() then y = y + (position.maxLevel or 0) end
    end
    return y
end

function Framework:UpdateNativePetPosition(style)
    if not style.active or not MainMenuBar or not PetActionBarFrame then return end
    local position = UIPARENT_MANAGED_FRAME_POSITIONS and UIPARENT_MANAGED_FRAME_POSITIONS.PETACTIONBAR_YPOS
    if position and type(position.baseY) == "number" then
        -- Pets are beside stances, so ignore the stock extra row named
        -- justBottomRightAndShapeshift. Rebuild Y instead of subtracting twice.
        PETACTIONBAR_YPOS = NativeRowY(position)
    end
    if not ActionButton1 or not ActionButton12 or not PetActionButton1 or not PetActionButton10 then return end
    local left, right = ActionButton1:GetLeft(), ActionButton12:GetRight()
    local petLeft, petRight = PetActionButton1:GetLeft(), PetActionButton10:GetRight()
    local barLeft, frameLeft = MainMenuBar:GetLeft(), PetActionBarFrame:GetLeft()
    if not left or not right or not petLeft or not petRight or not barLeft or not frameLeft then return end
    left = left * ActionButton1:GetEffectiveScale()
    right = right * ActionButton12:GetEffectiveScale()
    petLeft = petLeft * PetActionButton1:GetEffectiveScale()
    petRight = petRight * PetActionButton10:GetEffectiveScale()
    local petScale = PetActionBarFrame:GetEffectiveScale()
    local inset = petLeft - frameLeft * petScale
    if self:HasTotemBar() and MultiCastActionBarFrame then
        -- Use the resting native anchor, not the transient position during a slide.
        local totemScale = MultiCastActionBarFrame:GetEffectiveScale()
        local mainScale = MainMenuBar:GetEffectiveScale()
        local totemY = NativeRowY(UIPARENT_MANAGED_FRAME_POSITIONS
            and UIPARENT_MANAGED_FRAME_POSITIONS.MULTICASTACTIONBAR_YPOS) or MULTICASTACTIONBAR_YPOS or 0
        local totemLeft = barLeft * mainScale + ((MULTICASTACTIONBAR_XPOS or 30) + 3) * totemScale
        local totemBottom = MainMenuBar:GetHeight() * mainScale + (totemY + 3) * totemScale
        local targetLeft, targetBottom = self:PetRow(totemLeft, right, petRight - petLeft,
            0, totemBottom, 30 * totemScale, 6 * totemScale)
        local _, buttonY = PetActionButton1:GetCenter()
        local _, frameY = PetActionBarFrame:GetCenter()
        local bottomInset = (buttonY - PetActionButton1:GetHeight()/2) * PetActionButton1:GetEffectiveScale()
            - (frameY - PetActionBarFrame:GetHeight()/2) * petScale
        PETACTIONBAR_XPOS = (targetLeft - barLeft * mainScale - inset) / petScale
        PETACTIONBAR_YPOS = (targetBottom - bottomInset) / petScale + PetActionBarFrame:GetHeight()
        return
    end
    local forms = self:HasClassBar() and 1 or 0
    local targetLeft = self:PetLeft(left, right, petRight - petLeft, forms)
    PETACTIONBAR_XPOS = (targetLeft - barLeft * MainMenuBar:GetEffectiveScale() - inset) / petScale
end
