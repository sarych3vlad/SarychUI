-- Native modern_features ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.modern_features

function owner:IsLevelUpDisplayEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.LevelUpDisplay
    return cfg and cfg.enabled ~= false or false
end

function owner:IsLevelUpDisplayRunning()
    return self.LevelUpDisplayRunning == true
end

function owner:SetLevelUpDisplayEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.LevelUpDisplay = profile.addons.LevelUpDisplay or {}
    profile.addons.LevelUpDisplay.enabled = enable and true or false
    return self:ApplyLevelUpDisplay()
end

function owner:ApplyLevelUpDisplay(forceOff)
    local cfg = SarychUI.db.profile.modules.modern_features
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsLevelUpDisplayEnabled()
    LevelUpDisplayEnabled = enable and true or false
    local running = false
    if LevelUpDisplay then
        if enable then LevelUpDisplay:RegisterEvent("PLAYER_LEVEL_UP") else
            LevelUpDisplay:UnregisterAllEvents(); LevelUpDisplay:Hide()
            if LevelUpDisplaySide then LevelUpDisplaySide:Hide() end
        end
        running = enable
    end
    self.LevelUpDisplayRunning = running and true or false
    return self.LevelUpDisplayRunning
end

function owner:GetLevelUpDisplayOptions()
	return {
		type = "group",
		name = "LevelUpDisplay",
		order = 9,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить LevelUpDisplay",
				order = 1,
				get = function()
					return owner:IsLevelUpDisplayEnabled()
				end,
				set = function(_, value)
					owner:SetLevelUpDisplayEnabled(value)
				end,
			},
			description = {
				type = "description",
				name = "Отображение уведомлений о повышении уровня персонажа и питомца.\n\nАвтор: " .. ("Mikki33" or "Неизвестен") .. "\nВерсия: " .. ("1.0" or "Неизвестна"),
				order = 2,
				width = "full",
			},
		},
	}
end
