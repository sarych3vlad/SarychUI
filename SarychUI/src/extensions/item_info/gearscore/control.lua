-- Standalone entry in SarychUI AddOns; legacy storage key remains stable.
local owner = SarychUI.addons.GearScoreLite

function owner:IsGearScoreLiteEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.GearScoreLite
    return cfg and cfg.enabled ~= false or false
end

function owner:IsGearScoreLiteRunning()
    return self.GearScoreLiteRunning == true
end

function owner:SetGearScoreLiteEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.GearScoreLite = profile.addons.GearScoreLite or {}
    profile.addons.GearScoreLite.enabled = enable and true or false
    return self:ApplyGearScoreLite()
end

function owner:ApplyGearScoreLite(forceOff)
    local cfg = SarychUI.db.profile.addons.GearScoreLite
    cfg.settings = cfg.settings or {}
    for _, key in ipairs({"Player", "Inspect", "Item"}) do
        if cfg.settings[key] == nil then cfg.settings[key] = 1 end
    end
    -- Migrate the old forced-off default; explicit off remains -1.
    if cfg.settings.Item == 2 then cfg.settings.Item = 1 end
    self.settings = cfg.settings
    local enable = not forceOff and self:IsGearScoreLiteEnabled()
    self.enabled = enable and true or false
    self:SetGearScoreRuntime(self.enabled)
    return self.GearScoreLiteRunning
end

function owner:GetGearScoreLiteOptions()
    local args = {
        enabled = {type = "toggle", name = "Включить", order = 1,
            get = function() return owner:IsGearScoreLiteEnabled() end,
            set = function(_, value) owner:SetGearScoreLiteEnabled(value) end},
    }
    local settings = {
        {"Player", "GS в подсказке персонажа"},
        {"Inspect", "GS в окне осмотра"},
        {"Item", "GS в подсказке предмета"},
    }
    for index, setting in ipairs(settings) do
        local key, label = setting[1], setting[2]
        args[key] = {type = "toggle", name = label, order = index + 1,
            disabled = function() return not owner:IsGearScoreLiteEnabled() end,
            get = function() return owner.settings and owner.settings[key] == 1 end,
            set = function(_, value)
                owner.settings[key] = value and 1 or -1
                owner:RefreshGearScoreViews()
            end}
    end
    return {type = "group", name = "Gear Score", args = args}
end
