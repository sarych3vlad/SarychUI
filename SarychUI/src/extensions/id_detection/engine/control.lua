-- Native id_detection ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.id_detection

function owner:IsIdTipEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.IdTip
    return cfg and cfg.enabled ~= false or false
end

function owner:IsIdTipRunning()
    return self.IdTipRunning == true
end

function owner:SetIdTipEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.IdTip = profile.addons.IdTip or {}
    profile.addons.IdTip.enabled = enable and true or false
    return self:ApplyIdTip()
end

function owner:ApplyIdTip(forceOff)
    local cfg = SarychUI.db.profile.modules.id_detection
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsIdTipEnabled()
    IdTipEnabled = enable and true or false
    local running = false
    if SarychUI_SetIdTipRuntime then SarychUI_SetIdTipRuntime(enable) end
    if enable and IdTip_UpdateAltState then IdTip_UpdateAltState() end
    running = enable
    self.IdTipRunning = running and true or false
    return self.IdTipRunning
end

function owner:GetIdTipOptions()
	return {
		type = "group",
		name = "IdTip",
		order = 8,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить IdTip",
				order = 1,
				get = function()
					return owner:IsIdTipEnabled()
				end,
				set = function(_, value)
					owner:SetIdTipEnabled(value)
				end,
			},
			showOnAlt = {
				type = "toggle",
				name = "Показывать при зажатии {SUI_MODIFIER}",
				disabled = function()
					return not owner:IsIdTipEnabled()
				end,
				desc = "Показывать ID только при зажатой клавише {SUI_MODIFIER}",
				order = 2,
				width = "double",
				suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
				get = function()
					-- Если значение не установлено, возвращаем true (по умолчанию включено)
					local val = SarychUI.db.profile.addons.IdTip.showOnAlt
					return val ~= false  -- nil или true = включено, false = выключено
				end,
				set = function(info, value)
					-- Сохраняем значение (true или false)
					SarychUI.db.profile.addons.IdTip.showOnAlt = value
					-- Немедленно обновляем состояние Alt
					if IdTip_UpdateAltState then
						IdTip_UpdateAltState()
					end
				end,
			},
		},
	}
end
