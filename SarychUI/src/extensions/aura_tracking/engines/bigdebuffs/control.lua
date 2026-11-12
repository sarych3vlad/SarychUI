-- Native aura_tracking ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.aura_tracking

function owner:IsBigDebuffsEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.BigDebuffs
    return cfg and cfg.enabled ~= false or false
end

function owner:IsBigDebuffsRunning()
    return self.BigDebuffsRunning == true
end

function owner:SetBigDebuffsEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.BigDebuffs = profile.addons.BigDebuffs or {}
    profile.addons.BigDebuffs.enabled = enable and true or false
    return self:ApplyBigDebuffs()
end

function owner:ApplyBigDebuffs(forceOff)
    local cfg = SarychUI.db.profile.modules.aura_tracking
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsBigDebuffsEnabled()
    BigDebuffsEnabled = enable and true or false
    local running = false
    if BigDebuffs then
        BigDebuffs:SetEnabledState(enable)
        if enable then BigDebuffs:Enable() else BigDebuffs:Disable() end
        running = BigDebuffs:IsEnabled() and true or false
    end
    self.BigDebuffsRunning = running and true or false
    return self.BigDebuffsRunning
end

function owner:GetBigDebuffsOptions()
	return {
		type = "group",
		name = "BigDebuffs",
		order = 12,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить BigDebuffs",
				order = 1,
				get = function()
					return owner:IsBigDebuffsEnabled()
				end,
				set = function(_, value)
					owner:SetBigDebuffsEnabled(value)
				end,
			},
			description = {
				type = "description",
				name = "Отображает информацию о контролях на фреймах в виде иконок (Increases the debuff size of crowd control effects on the Blizzard raid frames).\n\nАвтор: " .. ("Jordon, WotLK backport by Konjunktur, modify by Friskes" or "Неизвестен") .. "\nВерсия: " .. ("6.8" or "Неизвестна"),
				order = 2,
				width = "full",
			},
		},
	}
end
