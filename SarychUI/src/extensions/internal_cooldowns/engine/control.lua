-- Native internal_cooldowns ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.internal_cooldowns

function owner:IsInternalCooldownsEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.InternalCooldowns
    return cfg and cfg.enabled ~= false or false
end

function owner:IsInternalCooldownsRunning()
    return self.InternalCooldownsRunning == true
end

function owner:SetInternalCooldownsEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.InternalCooldowns = profile.addons.InternalCooldowns or {}
    profile.addons.InternalCooldowns.enabled = enable and true or false
    return self:ApplyInternalCooldowns()
end

function owner:ApplyInternalCooldowns(forceOff)
    local cfg = SarychUI.db.profile.modules.internal_cooldowns
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsInternalCooldownsEnabled()
    InternalCooldownsEnabled = enable and true or false
    local running = false
    local engine = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns", true)
    if engine then
        for _, child in engine:IterateModules() do
            child:SetEnabledState(enable)
        end
        engine:SetEnabledState(enable)
        if enable then engine:Enable() else engine:Disable() end
        running = engine:IsEnabled() and true or false
    end
    self.InternalCooldownsRunning = running and true or false
    return self.InternalCooldownsRunning
end

function owner:GetInternalCooldownsOptions()
	return {
		type = "group",
		name = "InternalCooldowns",
		order = 3,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить InternalCooldowns (таймеры перезарядки для аксессуаров/чар/особых камней)",
				order = 1,
				get = function()
					return owner:IsInternalCooldownsEnabled()
				end,
				set = function(_, value)
					owner:SetInternalCooldownsEnabled(value)
				end,
			},
		},
	}
end
