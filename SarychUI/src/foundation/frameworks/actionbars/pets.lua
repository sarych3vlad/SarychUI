local Framework = SarychUI.ActionBars
local PET_VISIBILITY = "[pet,novehicleui,nobonusbar:5] show; hide"

function Framework:GetSecondaryFrames(owner)
    local frames, seen = {}, {}
    local function add(frame, group)
        if frame and not seen[frame] then
            frames[#frames + 1] = {frame=frame, group=group}
            seen[frame] = true
        end
    end
    add(ShapeshiftBarFrame, "stance")
    add(PetActionBarFrame, "pet")
    local style = self:GetActiveStyle(owner)
    if style then
        add(style.stanceHolder, "stance")
        add(style._totemLayout and style._totemLayout.frame, "stance")
        add(style._petState and style._petState.frame, "pet")
    end
    return frames
end

function Framework:EnablePet(style, frame, native)
    if not frame or InCombatLockdown() then return end
    if style._petState then return end
    if native and (not RegisterStateDriver or not UnregisterStateDriver) then return end
    style._petState = {frame=frame, native=native, grid=PetActionBarFrame and PetActionBarFrame.showgrid}
    if PetActionBarFrame then
        -- Reserve one grid reference so stock summon/dismiss slides stay inert.
        PetActionBarFrame.showgrid = (PetActionBarFrame.showgrid or 0) + 1
        PetActionBarFrame.mode = "none"
        PetActionBarFrame.slideTimer = nil
        PetActionBarFrame.completed = 1
    end
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local button = _G["PetActionButton" .. i]
        if button then button:Show() end
    end
    if RegisterStateDriver and UnregisterStateDriver then
        RegisterStateDriver(frame, "visibility", PET_VISIBILITY)
        style.petDriverRegistered = true
    else
        self:RefreshPet(style)
    end
end

function Framework:RefreshPet(style)
    local state = style._petState
    if not state or style.petDriverRegistered or InCombatLockdown() then return end
    local hasPet = UnitExists("pet") and UnitIsVisible("pet")
    local inVehicle = UnitInVehicle and UnitInVehicle("player")
    local hasVehicleBar = SarychUI.Compat and SarychUI.Compat.HasVehicleActionBar()
    if hasPet or (inVehicle and hasVehicleBar) then state.frame:Show()
    else state.frame:Hide() end
end

function Framework:DisablePet(style)
    local state = style._petState
    if not state or InCombatLockdown() then return end
    if style.petDriverRegistered then
        UnregisterStateDriver(state.frame, "visibility")
        style.petDriverRegistered = false
    end
    if PetActionBarFrame then PetActionBarFrame.showgrid = state.grid end
    style._petState = nil
    if not state.native then
        state.frame:Hide()
    else
        if PetActionBar_Update then PetActionBar_Update(PetActionBarFrame) end
        if PetHasActionBar and PetHasActionBar() and UnitIsVisible and UnitIsVisible("pet") then
            if ShowPetActionBar then ShowPetActionBar(true) end
        elseif HidePetActionBar then HidePetActionBar() end
    end
end
