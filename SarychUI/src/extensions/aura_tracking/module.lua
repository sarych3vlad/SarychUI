-- The extension owns the settings entry; existing engines retain their profiles.
local SUI = SarychUI
local extension = SUI:RegisterExtension("aura_tracking", {})
local TITLE = "Отслеживание аур"
local CONTROL_ICON = "Interface\\Icons\\Ability_Rogue_KidneyShot"
local TAB_ICON = "|TInterface\\AddOns\\SarychUI\\media\\components\\modules\\nameplates\\engines\\elvui\\Media\\Textures\\nameplates:20:20:0:0:256:128:0:38:45:81|t "
local TIMER_COLOR = {1, 1, 1, 1}

-- Aura timers retain their own font/format and share the cooldown warning color.
function extension:GetTimerColor(remaining, baseColor)
    local color = baseColor or TIMER_COLOR
    local cc = SUI.modules and SUI.modules.cc
    local settings = SUI.db and SUI.db.profile and SUI.db.profile.modules and SUI.db.profile.modules.cc
    if cc and cc.GetTimerColor and (not settings or settings.enabled ~= false) then
        return cc:GetTimerColor(remaining, color)
    end
    return color
end

local function IconLabel(name, spellID, fallback)
    local texture = GetSpellInfo and select(3, GetSpellInfo(spellID)) or nil
    return "|T" .. (texture or fallback) .. ":24:24:0:0|t " .. name
end

-- Copy option nodes only. Handler objects and callbacks must retain their identity.
local function CopyOptions(source)
    local result = {}
    for key, value in pairs(source) do
        if key == "args" then
            result.args = {}
            for name, child in pairs(value) do result.args[name] = CopyOptions(child) end
        elseif (key == "name" or key == "desc") and type(value) == "string" then
            result[key] = value:gsub("BigDebuffs", TITLE)
        else result[key] = value end
    end
    if result.type == "group" and result.inline then result.suiThreeCol = true end
    if result.width == "full" then result.suiFullRow = true end
    if result.width == "double" then result.suiSpanTwoCols = true end
    return result
end

local function LossOfControlOptions(source)
    local args = source.args
    -- Use the same flat control grid as the unit-frame tabs. Preserve the
    -- disabled state inherited from groups when moving their controls here.
    local controls = {}
    local function Add(key, option, order, disabled)
        local node = CopyOptions(option)
        node.order, node.width = order, "normal"
        node.suiFullRow, node.suiSpanTwoCols = nil, nil
        if node.disabled == nil then node.disabled = disabled end
        controls[key] = node
    end
    Add("enabled", args.enabled, 1)
    Add("lineStyle", args.lineStyle, 2)
    Add("displayMode", args.displayMode, 3)
    Add("positionX", args.position.args.positionX, 4, args.position.disabled)
    Add("positionY", args.position.args.positionY, 5, args.position.disabled)
    Add("scale", args.position.args.scale, 6, args.position.disabled)
    Add("nameFontSize", args.textSizes.args.nameFontSize, 7, args.textSizes.disabled)
    Add("timerFontSize", args.textSizes.args.timerFontSize, 8, args.textSizes.disabled)
    controls.timerFontSize.suiRowBreakAfter = true
    Add("unlock", args.position.args.unlock, 9, args.position.disabled)
    Add("reset", args.position.args.reset, 10, args.position.disabled)
    controls.unlock.suiWidthRatio = 2
    controls.reset.suiWidthRatio = 1
    controls.reset.suiRowBreakAfter = true
    Add("test", args.test, 11)

    local filters = CopyOptions(args.filters)
    filters.order, filters.suiThreeCol, filters.suiTwoCol = 12, nil, true
    filters.args.info = nil
    -- Keep "Остальной контроль" in the second column below "Немота".
    filters.args.showOtherControl.order = 5
    filters.args.showRoots.order = 6
    local icons = {
        showStuns = {408, CONTROL_ICON},
        showSilences = {15487, "Interface\\Icons\\Spell_Shadow_ImpPhaseShift"},
        showDisarms = {676, "Interface\\Icons\\Ability_Warrior_Disarm"},
        showRoots = {122, "Interface\\Icons\\Spell_Frost_FrostNova"},
        showOtherControl = {118, "Interface\\Icons\\Spell_Nature_Polymorph"},
    }
    for key, icon in pairs(icons) do
        local option = filters.args[key]
        option.name = IconLabel(option.name, icon[1], icon[2])
        option.suiRowHeight = 28
    end
    controls.filters = filters

    return {
        type = "group", name = TAB_ICON .. "Потеря контроля", order = 20, suiThreeCol = true,
        args = controls,
    }
end

function extension:OpenSettings()
    if not self:IsEnabled() then return end
    if InCombatLockdown and InCombatLockdown() then
        SUI:Print(SUI:T("Настройки недоступны в бою."))
        return
    end
    local engine = _G.BigDebuffs
    if not engine or not engine.db then
        SUI:Print(SUI:T("Отслеживание аур ещё не инициализировано."))
        return
    end
    if not engine.options then engine:SetupOptions() end
    -- Keep the original root paths: BigDebuffs callbacks use info[1] and info[2].
    local options = CopyOptions(engine.options)
    options.name = TITLE
    options.plugins = nil
    local loss = self
    if loss and loss.Getpw_lossofcontrolOptions then
        local node = LossOfControlOptions(loss:Getpw_lossofcontrolOptions())
        local display = options.args.unitFrames
        display.args.lossOfControl = node
        local sequence = {"player", "lossOfControl", "pet", "target", "focus", "party", "partypet", "arena", "arenapet"}
        for index, key in ipairs(sequence) do
            if display.args[key] then display.args[key].order = index * 10 end
        end
        local disabled = display.disabled
        display.disabled = function(info)
            if info[2] == "lossOfControl" then return false end
            if info[2] == "general" and info[3] == "enabled" then return false end
            return disabled and disabled(info) or false
        end
    end
    local owner = self
    if owner then
        -- Keep the original enable checkbox in its original position, including
        -- recovery from a previously disabled wrapper without an extra control.
        local enabled = options.args.unitFrames.args.general.args.enabled
        enabled.get = function() return owner:IsBigDebuffsEnabled() and engine.db.profile.unitFrames.enabled end
        enabled.set = function(_, value)
            engine.db.profile.unitFrames.enabled = value
            if value and not owner:IsBigDebuffsEnabled() then owner:SetBigDebuffsEnabled(true) end
            engine:Refresh()
        end
    end
    SUI.AuraTrackingOptionsCore:Open(options)
    if not self.refreshHooked then
        self.refreshHooked = true
        hooksecurefunc(engine, "Refresh", function()
            SUI.AuraTrackingOptionsCore:OnSettingChanged()
        end)
    end
end

function extension:GetOptions()
    return {
        type = "group", name = TAB_ICON .. TITLE,
        args = {
            enabled = {type = "toggle", name = "Включить", order = 0,
                get = function() return extension:IsEnabled() end,
                set = function(_, value)
                    if value then SUI:EnableModule("aura_tracking") else SUI:DisableModule("aura_tracking") end
                end},
            configure = {type = "execute", name = "Настройка", order = 1, width = "full",
                func = function() extension:OpenSettings() end},
        },
    }
end

function extension:IsEnabled()
    local db = SUI.db and SUI.db.profile.modules.aura_tracking
    return not db or db.enabled ~= false
end

function extension:Enable()
    self:ApplyBigDebuffs()
    self:Applypw_lossofcontrol()
end
function extension:RefreshConfig() self:Enable() end
function extension:Disable()
    if SUI.AuraTrackingOptionsCore then SUI.AuraTrackingOptionsCore:Close() end
    self:ApplyBigDebuffs(true)
    self:Applypw_lossofcontrol(true)
end

function extension:Initialize()
    self:ApplyBigDebuffs(true)
    self:Applypw_lossofcontrol(true)
end
