-- SarychUI MainMenuBar Panel Color Module
-- Color indication functions for main menu bar

local moduleName = "mainmenubar"

-- Get or create module reference
local function getModule()
    if SarychUI.modules and SarychUI.modules[moduleName] then
        return SarychUI.modules[moduleName]
    end
    -- If module doesn't exist yet, create a temporary one
    if not SarychUI.modules then
        SarychUI.modules = {}
    end
    if not SarychUI.modules[moduleName] then
        SarychUI.modules[moduleName] = {}
    end
    return SarychUI.modules[moduleName]
end

local module = getModule()

-- Keep runtime state outside protected action-button tables. Blizzard reads
-- those tables from secure code while paging bars in combat.
local updateTimerByButton = setmetatable({}, { __mode = "k" })
local iconByButton = setmetatable({}, { __mode = "k" })
local colorStateByButton = setmetatable({}, { __mode = "k" })

local INDICATION_COLOR_DEFAULTS = {
    colorCooldownColor = { 0.4, 0.4, 0.4, 0.6 },
    colorManaColor = { 0.1, 0.1, 1.0, 1.0 },
    colorRangeColor = { 0.8, 0.2, 0.2, 1.0 },
    colorUnusableColor = { 0.2, 0.2, 0.2, 1.0 },
}

local function GetIndicationColor(db, key)
    local color = db and db[key]
    local defaults = INDICATION_COLOR_DEFAULTS[key]
    local r = type(color) == "table" and color[1] or nil
    local g = type(color) == "table" and color[2] or nil
    local b = type(color) == "table" and color[3] or nil
    local a = type(color) == "table" and color[4] or nil
    if r == nil then r = defaults[1] end
    if g == nil then g = defaults[2] end
    if b == nil then b = defaults[3] end
    if a == nil and key == "colorCooldownColor" and db then
        a = db.colorCooldownAlpha
    end
    if a == nil then a = defaults[4] end
    return r, g, b, a
end

-- Initialize color system
function module:InitializeColorSystem()
    -- Hooks are permanent; re-running Initialize must not stack another copy.
    if module.__sarColorHooked then
        if module.UpdateColorIndication then module:UpdateColorIndication() end
        return
    end
    module.__sarColorHooked = true

    -- Hook into ActionButton_UpdateUsable to apply color indication
    hooksecurefunc("ActionButton_UpdateUsable", function(button)
        if SarychUI.modules and SarychUI.modules.mainmenubar and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.mainmenubar and SarychUI.db.profile.modules.mainmenubar.enabled then
            if module.UpdateButtonColorIndication then module:UpdateButtonColorIndication(button, true) end
        end
    end)
    
    -- Hook into ActionButton_OnUpdate for real-time updates
    hooksecurefunc("ActionButton_OnUpdate", function(self, elapsed)
        local timer = (updateTimerByButton[self] or TOOLTIP_UPDATE_TIME) - elapsed

        if timer <= 0 then
            -- Update only if button is visible and has action
            if self:IsVisible() and self.action then
                if SarychUI.modules and SarychUI.modules.mainmenubar and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.mainmenubar and SarychUI.db.profile.modules.mainmenubar.enabled then
                    if module.UpdateButtonColorIndication then module:UpdateButtonColorIndication(self) end
                end
            end
            timer = TOOLTIP_UPDATE_TIME
        end
        updateTimerByButton[self] = timer
    end)
    
    -- Apply initial color indication to all buttons
    if module.UpdateColorIndication then module:UpdateColorIndication() end
end

-- Update color indication for a specific button.
-- `force` must be set whenever Blizzard code just wrote to the icon itself
-- (ActionButton_UpdateUsable), because the cached values below no longer describe
-- what is actually on the texture.
function module:UpdateButtonColorIndication(button, force)
    -- Get fresh db reference
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then 
        return 
    end
    
    
    local icon = iconByButton[button]
    if icon == nil then
        local name = button.GetName and button:GetName()
        icon = name and _G[name .. "Icon"] or false
        iconByButton[button] = icon
    end
    if not icon then
        return
    end
    
    local isUsable, notEnoughMana = IsUsableAction(button.action)
    local inRange = IsActionInRange(button.action)
    local start, duration, enable = GetActionCooldown(button.action)

    -- Check settings for each type of indication
    local colorCooldownEnabled = currentDb.colorCooldownEnabled
    local colorManaEnabled = currentDb.colorManaEnabled
    local colorRangeEnabled = currentDb.colorRangeEnabled
    local colorUnusableEnabled = currentDb.colorUnusableEnabled

    -- Resolve the target appearance first, then write it only when it differs from
    -- what is already on the texture. This hook fires ~5x/sec per button.
    local desat, r, g, b, alpha

    if duration > 1.51 and colorCooldownEnabled then
        desat = true
        r, g, b, alpha = GetIndicationColor(currentDb, "colorCooldownColor")
    elseif duration > 1.51 and not colorCooldownEnabled then
        desat, r, g, b, alpha = false, 1.0, 1.0, 1.0, 1.0
    elseif notEnoughMana and colorManaEnabled then
        desat = false
        r, g, b, alpha = GetIndicationColor(currentDb, "colorManaColor")
    elseif notEnoughMana and not colorManaEnabled then
        desat, r, g, b, alpha = false, 0.5, 0.5, 1.0, 1.0
    elseif isUsable then
        if (inRange == false or inRange == 0) and colorRangeEnabled then
            desat = false
            r, g, b, alpha = GetIndicationColor(currentDb, "colorRangeColor")
        else
            desat, r, g, b, alpha = false, 1.0, 1.0, 1.0, 1.0
        end
    elseif colorUnusableEnabled then
        desat = false
        r, g, b, alpha = GetIndicationColor(currentDb, "colorUnusableColor")
    else
        desat, r, g, b, alpha = false, 0.4, 0.4, 0.4, 1.0
    end

    local state = colorStateByButton[button]
    if not state then
        state = {}
        colorStateByButton[button] = state
    end

    if force or state.desat ~= desat then
        state.desat = desat
        icon:SetDesaturated(desat)
    end
    if force or state.r ~= r or state.g ~= g or state.b ~= b then
        state.r, state.g, state.b = r, g, b
        icon:SetVertexColor(r, g, b)
    end
    if force or state.alpha ~= alpha then
        state.alpha = alpha
        icon:SetAlpha(alpha)
    end
end

-- Update color indication for all buttons
function module:UpdateColorIndication()
    -- Get fresh db reference
    if not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return
    end
    
    local currentDb = SarychUI.db.profile.modules.mainmenubar
    if not currentDb or not currentDb.enabled then 
        return 
    end
    
    
    -- Update all action buttons with color indication
    for i = 1, 12 do
        local buttons = {
            _G["ActionButton" .. i],
            _G["MultiBarBottomRightButton" .. i],
            _G["MultiBarBottomLeftButton" .. i],
            _G["MultiBarRightButton" .. i],
            _G["MultiBarLeftButton" .. i],
            _G["BonusActionButton" .. i]
        }
        
        for _, button in ipairs(buttons) do
            if button and button:IsVisible() and button.action then
                self:UpdateButtonColorIndication(button, true)
            end
        end
    end
end

-- Reset all buttons to normal state (used when disabling color indication)
function module:ResetAllButtonsToNormal()
    for i = 1, 12 do
        local buttons = {
            _G["ActionButton" .. i],
            _G["MultiBarBottomRightButton" .. i],
            _G["MultiBarBottomLeftButton" .. i],
            _G["MultiBarRightButton" .. i],
            _G["MultiBarLeftButton" .. i],
            _G["BonusActionButton" .. i]
        }
        
        for _, button in ipairs(buttons) do
            if button then
                local icon = _G[button:GetName() .. "Icon"]
                if icon then
                    icon:SetDesaturated(false)
                    icon:SetVertexColor(1.0, 1.0, 1.0)
                    icon:SetAlpha(1.0)
                    colorStateByButton[button] = nil
                end
            end
        end
    end
end

-- Apply "disabled" colors to all buttons (when module is disabled)
function module:ApplyDisabledColorsToAllButtons()
    for i = 1, 12 do
        local buttons = {
            _G["ActionButton" .. i],
            _G["MultiBarBottomRightButton" .. i],
            _G["MultiBarBottomLeftButton" .. i],
            _G["MultiBarRightButton" .. i],
            _G["MultiBarLeftButton" .. i],
            _G["BonusActionButton" .. i]
        }
        
        for _, button in ipairs(buttons) do
            if button and button.action then
                local icon = _G[button:GetName() .. "Icon"]
                if icon then
                    -- Получаем состояние кнопки
                    local isUsable, notEnoughMana = IsUsableAction(button.action)
                    local inRange = IsActionInRange(button.action)
                    local start, duration, enable = GetActionCooldown(button.action)
                    
                    -- Применяем "отключенные" цвета согласно логике
                    if duration > 1.5 then
                        -- Кулдаун отключен - нормальный цвет
                        icon:SetDesaturated(false)
                        icon:SetVertexColor(1.0, 1.0, 1.0)
                        icon:SetAlpha(1.0)
                    elseif notEnoughMana then
                        -- Недостаток ресурса отключен - светло-синий
                        icon:SetDesaturated(false)
                        icon:SetVertexColor(0.5, 0.5, 1.0)
                        icon:SetAlpha(1.0)
                    elseif isUsable then
                        if (inRange == false or inRange == 0) then
                            -- Вне радиуса отключен - нормальный цвет
                            icon:SetDesaturated(false)
                            icon:SetVertexColor(1.0, 1.0, 1.0)
                            icon:SetAlpha(1.0)
                        else
                            -- В радиусе - нормальный цвет
                            icon:SetDesaturated(false)
                            icon:SetVertexColor(1.0, 1.0, 1.0)
                            icon:SetAlpha(1.0)
                        end
                    else
                        -- Недоступно отключено - светло-серый
                        icon:SetDesaturated(false)
                        icon:SetVertexColor(0.4, 0.4, 0.4)
                        icon:SetAlpha(1.0)
                    end

                    colorStateByButton[button] = nil
                end
            end
        end
    end
end
