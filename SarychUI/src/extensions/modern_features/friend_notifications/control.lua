-- Native modern_features ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.modern_features

function owner:IsBNetToastEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.BNetToast
    return cfg and cfg.enabled ~= false or false
end

function owner:IsBNetToastRunning()
    return self.BNetToastRunning == true
end

function owner:SetBNetToastEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.BNetToast = profile.addons.BNetToast or {}
    profile.addons.BNetToast.enabled = enable and true or false
    return self:ApplyBNetToast()
end

function owner:ApplyBNetToast(forceOff)
    local cfg = SarychUI.db.profile.modules.modern_features
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsBNetToastEnabled()
    BNetToastEnabled = enable and true or false
    local running = false
    local frame = SarychUI_BNetToastFrame
    if frame then
        if enable then frame:RegisterEvent("CHAT_MSG_SYSTEM") else frame:UnregisterEvent("CHAT_MSG_SYSTEM") end
        running = enable
    end
    if not enable and BNToastFrame then BNToastFrame:Hide() end
    self.BNetToastRunning = running and true or false
    return self.BNetToastRunning
end

function owner:GetBNetToastOptions()
	return {
		type = "group",
		name = "BNetToast",
		order = 3,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить BNetToast",
				order = 1,
				get = function()
					return owner:IsBNetToastEnabled()
				end,
				set = function(_, value)
					owner:SetBNetToastEnabled(value)
				end,
			},
			description = {
				type = "description",
				name = "Уведомления о входе/выходе друзей из Battle.net (BNet Toast).\n\nАвтор: " .. ("Bonho, Bunny67" or "Неизвестен") .. "\nВерсия: " .. ("1.0" or "Неизвестна"),
				order = 2,
				width = "full",
			},
		},
	}
end
