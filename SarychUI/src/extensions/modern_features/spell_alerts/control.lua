-- Native modern_features ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.modern_features

function owner:IsCheeseEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.Cheese
    return cfg and cfg.enabled ~= false or false
end

function owner:IsCheeseRunning()
    return self.CheeseRunning == true
end

function owner:SetCheeseEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.Cheese = profile.addons.Cheese or {}
    profile.addons.Cheese.enabled = enable and true or false
    return self:ApplyCheese()
end

function owner:ApplyCheese(forceOff)
    local cfg = SarychUI.db.profile.modules.modern_features
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsCheeseEnabled()
    CheeseEnabled = enable and true or false
    local running = false
    if Cheese_SetRuntimeEnabled then Cheese_SetRuntimeEnabled(enable) end
    if enable then
        local cfg = SarychUI.db.profile.addons.Cheese
        if CheeseSpellActivationOverlayFrame then CheeseSpellActivationOverlayFrame:SetAlpha(cfg.spellAlertOpacity or 1) end
        if Cheese_RefreshActionMappings then Cheese_RefreshActionMappings() end
        if Cheese_RefreshAuras then Cheese_RefreshAuras() end
    else
        if Cheese_ClearRuntime then Cheese_ClearRuntime() end
        if CheeseSpellActivationOverlayFrame then CheeseSpellActivationOverlay_HideAllOverlays(CheeseSpellActivationOverlayFrame) end
    end
    if CheeseActionButton_RefreshAll then CheeseActionButton_RefreshAll() end
    running = enable and CheeseSpellActivationOverlayFrame ~= nil
    self.CheeseRunning = running and true or false
    return self.CheeseRunning
end

function owner:GetCheeseOptions()
	return {
		type = "group",
		name = "Cheese",
		order = 4,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Cheese",
				order = 1,
				get = function()
					return owner:IsCheeseEnabled()
				end,
				set = function(_, value)
					owner:SetCheeseEnabled(value)
				end,
			},
			showSpellAlerts = {
				type = "toggle",
				name = "Показывать оповещения заклинаний",
				order = 2,
				hidden = function() return not owner:IsCheeseEnabled() end,
				get = function()
					return SarychUI.db.profile.addons.Cheese.showSpellAlerts ~= false
				end,
				set = function(_, value)
					SarychUI.db.profile.addons.Cheese.showSpellAlerts = value and true or false
					if not value and CheeseSpellActivationOverlayFrame then
						CheeseSpellActivationOverlay_HideAllOverlays(CheeseSpellActivationOverlayFrame)
					elseif value and Cheese_RefreshSpellOverlays then
						Cheese_RefreshSpellOverlays()
					end
				end,
			},
			spellAlertOpacity = {
				type = "range",
				name = "Прозрачность оповещений",
				min = 0.1, max = 1, step = 0.05,
				order = 3,
				hidden = function() return not owner:IsCheeseEnabled() end,
				disabled = function() return SarychUI.db.profile.addons.Cheese.showSpellAlerts == false end,
				get = function()
					return SarychUI.db.profile.addons.Cheese.spellAlertOpacity or 1
				end,
				set = function(_, value)
					SarychUI.db.profile.addons.Cheese.spellAlertOpacity = value
					if CheeseSpellActivationOverlayFrame then
						CheeseSpellActivationOverlayFrame:SetAlpha(value)
					end
				end,
			},
			description = {
				type = "description",
				name = "Визуальные алерты активации заклинаний (Cataclysm Visual Alerts).\n\nАвтор: " .. ("Неизвестен" or "Неизвестен") .. "\nВерсия: " .. ("1.0" or "Неизвестна"),
				order = 4,
				width = "full",
			},
		},
	}
end
