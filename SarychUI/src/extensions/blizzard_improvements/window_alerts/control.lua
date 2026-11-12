-- Native blizzard_improvements ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.blizzard_improvements

function owner:IsFlashWindowEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.FlashWindow
    return cfg and cfg.enabled ~= false or false
end

function owner:IsFlashWindowRunning()
    return self.FlashWindowRunning == true
end

function owner:SetFlashWindowEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.FlashWindow = profile.addons.FlashWindow or {}
    profile.addons.FlashWindow.enabled = enable and true or false
    return self:ApplyFlashWindow()
end

function owner:ApplyFlashWindow(forceOff)
    local cfg = SarychUI.db.profile.modules.blizzard_improvements
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsFlashWindowEnabled()
    FlashWindowEnabled = enable and true or false
    local running = false
    if SarychUI_FlashWindowRuntime then SarychUI_FlashWindowRuntime:RefreshRuntime() end
    running = enable and type(_G.FlashWindow) == "function" and not (IsAddOnLoaded("FlashWindow") or IsAddOnLoaded("Flash"))
    self.FlashWindowRunning = running and true or false
    return self.FlashWindowRunning
end

function owner:GetFlashWindowOptions()
	return {
		type = "group",
		name = "FlashWindow",
		order = 7,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить FlashWindow",
				order = 1,
				get = function()
					return owner:IsFlashWindowEnabled()
				end,
				set = function(_, value)
					owner:SetFlashWindowEnabled(value)
				end,
			},
			description = {
				type = "description",
				name = "Мигание окна игры при важных событиях (требует патч Wow.exe или FlashWindow() API).\n\nАвтор: " .. ("https://t.me/boredatom" or "Неизвестен") .. "\nВерсия: " .. ("1.0" or "Неизвестна"),
				order = 2,
				width = "full",
			},
		},
	}
end
