-- Shared lifecycle for action-bar layouts. Styles own geometry and artwork.
local Framework = {}
SarychUI.ActionBars = Framework
local Runtime = {}
Runtime.__index = Runtime
local runtimes, hooks = {}, {}
local VEHICLE_DELAY = 0.60
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UNIT_ENTERING_VEHICLE",
    "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "DISPLAY_SIZE_CHANGED",
    "UI_SCALE_CHANGED", "CVAR_UPDATE", "UNIT_PET", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS",
    "UPDATE_MULTI_CAST_ACTIONBAR",
}
local BAR_CVARS = {
    bottomleftactionbar=true, bottomrightactionbar=true,
    multibarbottomleft=true, multibarbottomright=true,
    show_multibar1_text=true, show_multibar2_text=true,
}

function Framework:InVehicle()
    return UnitHasVehicleUI and UnitHasVehicleUI("player")
end

function Framework:VehicleLayoutBlocked()
    return self:InVehicle()
        or (MainMenuBar and (MainMenuBar.busy or MainMenuBar.animating))
        or (VehicleMenuBar and VehicleMenuBar.animating)
        or (MultiBarRight and MultiBarRight.animating)
end

function Framework:RegisterStyle(owner, key, style, options)
    owner.barStyles = owner.barStyles or {}
    assert(not owner.barStyles[key], "Action-bar style already registered: " .. key)
    owner.barStyles[key] = style
    if not options then return style end -- Native layout needs no extra controller.
    local runtime = setmetatable({style=style, options=options}, Runtime)
    style.runtime = runtime
    style.controller = options.controller or CreateFrame("Frame", options.controllerName)
    style.controller:Hide()
    runtimes[#runtimes + 1] = runtime
    return style
end

function Framework:GetStyle(owner, key)
    return owner.barStyles and owner.barStyles[key or owner._bootBarStyle or "classic"]
end

function Framework:GetActiveStyle(owner)
    local style = self:GetStyle(owner)
    return style and style.active and style or nil
end

function Runtime:ApplyLayout()
    if self.style.active then return self.style[self.options.layout](self.style) end
end

function Runtime:RequestLayout(delay)
    local style = self.style
    if not style.active then return end
    style.layoutPending = true
    style.layoutDelay = math.max(style.layoutDelay or 0, delay or 0)
    if InCombatLockdown() or Framework:InVehicle() then style.controller:Hide()
    else style.controller:Show() end
end

function Runtime:CanLayout()
    if not self.style.active then return false end
    if InCombatLockdown() or Framework:VehicleLayoutBlocked() then
        self:RequestLayout((InCombatLockdown() or Framework:InVehicle()) and 0 or 0.10)
        return false
    end
    return true
end

function Runtime:FinishLayout()
    self.style.layoutPending, self.style.layoutDelay = false, 0
    self.style.controller:Hide()
end

function Runtime:OnEvent(event, unit, ...)
    local style, options = self.style, self.options
    if not style.active then return end
    if event == "CVAR_UPDATE" then
        if BAR_CVARS[type(unit) == "string" and unit:lower() or ""] then self:RequestLayout() end
        return
    end
    if event == "UNIT_ENTERING_VEHICLE" then
        if unit == "player" then
            style.layoutPending, style.layoutDelay = true, 0
            style.controller:Hide()
        end
        return
    end
    if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if unit ~= "player" then return end
        if event == "UNIT_EXITED_VEHICLE" then self:RequestLayout(VEHICLE_DELAY) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if options.refreshVehicleHotkeys then options.refreshVehicleHotkeys(style) end
        self:RequestLayout()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "DISPLAY_SIZE_CHANGED"
        or event == "UI_SCALE_CHANGED" or event == "UNIT_PET" or event == "PET_BAR_UPDATE"
        or event == "UPDATE_SHAPESHIFT_FORMS" or event == "UPDATE_MULTI_CAST_ACTIONBAR"
        or (options.layoutEvents and options.layoutEvents[event]) then
        self:ApplyLayout()
    end
    if options.onEvent then options.onEvent(style, event, unit, ...) end
end

local function Dispatch(name, ...)
    for _, runtime in ipairs(runtimes) do
        local style, options = runtime.style, runtime.options
        if style.active then
            if name == "UIParent_ManageFramePositions" or name == "MultiActionBar_Update" then
                if options.immediateNativeLayout then runtime:ApplyLayout()
                else runtime:RequestLayout() end
            elseif name == "MainMenuBar_ToPlayerArt" then runtime:RequestLayout(VEHICLE_DELAY)
            elseif name == "VehicleMenuBar_MoveMicroButtons" then
                local skinName = ...
                if not skinName then
                    if options.positionMicroMenu then options.positionMicroMenu(style) end
                    runtime:RequestLayout(VEHICLE_DELAY)
                end
            elseif name == "VehicleMenuBar_UpdateActionBars" then
                if options.refreshVehicleHotkeys then options.refreshVehicleHotkeys(style) end
            elseif name == "PetActionBar_UpdatePositionValues" then
                if options.petPositionValues then options.petPositionValues(style) end
            else runtime:RequestLayout() end
        end
    end
end

function Runtime:Start()
    local controller = self.style.controller
    for _, event in ipairs(EVENTS) do controller:RegisterEvent(event) end
    for _, event in ipairs(self.options.events or {}) do controller:RegisterEvent(event) end
    controller:SetScript("OnEvent", function(_, ...) self:OnEvent(...) end)
    controller:SetScript("OnUpdate", function(_, elapsed)
        local style = self.style
        if not style.active or not style.layoutPending then return end
        if (style.layoutDelay or 0) > 0 then
            style.layoutDelay = style.layoutDelay - elapsed
            return
        end
        self:ApplyLayout()
    end)
    self:InstallHooks()
end

function Runtime:InstallHooks()
    -- Hook once for all styles; inactive consumers never receive callbacks.
    if not hooksecurefunc then return end
    for _, name in ipairs({"UIParent_ManageFramePositions", "MultiActionBar_Update",
        "MainMenuBar_ToPlayerArt", "VehicleMenuBar_MoveMicroButtons", "VehicleMenuBar_UpdateActionBars",
        "ReputationWatchBar_Update", "ShapeshiftBar_Update", "PetActionBar_UpdatePositionValues",
        "MultiCastActionBarFrame_Update"}) do
        if not hooks[name] and type(_G[name]) == "function" then
            local functionName = name
            hooksecurefunc(functionName, function(...) Dispatch(functionName, ...) end)
            hooks[name] = true
        end
    end
end

function Runtime:Stop()
    local controller = self.style.controller
    self:FinishLayout()
    controller:UnregisterAllEvents()
    controller:SetScript("OnEvent", nil)
    controller:SetScript("OnUpdate", nil)
end
