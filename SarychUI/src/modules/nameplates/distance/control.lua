-- Native health_indicators ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.health_indicators

local function GetAutolos()
	return _G.Autolos
end

local function SyncGlobalEnabled(value)
	autolosEnabled = value and true or false
end

local function ApplyRuntimeState()
	local autolos = GetAutolos()
	if autolos then
		if autolos.EnsureProfiles then
			autolos.EnsureProfiles()
		end
		if autolos.ApplySettings then
			autolos.ApplySettings()
		end
	end
end

function owner:IsautolosEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.autolos
    return cfg and cfg.enabled ~= false or false
end

function owner:IsautolosRunning()
    return self.autolosRunning == true
end

function owner:SetautolosEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.autolos = profile.addons.autolos or {}
    profile.addons.autolos.enabled = enable and true or false
    return self:Applyautolos()
end

function owner:Applyautolos(forceOff)
    local cfg = SarychUI.db.profile.modules.health_indicators
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsautolosEnabled()
    autolosEnabled = enable and true or false
    local running = false
    SyncGlobalEnabled(enable)
    if Autolos and Autolos.SetRuntimeEnabled then Autolos.SetRuntimeEnabled(enable) else ApplyRuntimeState() end
    running = enable and GetAutolos() ~= nil
    self.autolosRunning = running and true or false
    return self.autolosRunning
end

function owner:GetautolosOptions()
	return {
		type = "group",
		name = "autolos",
		order = 3,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Показывать дистанцию на неймплейтах. Нужен nameplate_range.dll (статус: Система). Настройки шрифта и позиции - в Модули -> Индикаторы здоровья.",
				order = 1,
				get = function()
					return owner:IsautolosEnabled()
				end,
				set = function(_, value)
					owner:SetautolosEnabled(value)
				end,
			},
			description = {
				type = "description",
				name = "Показывает дистанцию до юнита на неймплейте (классические и ElvUI).\n\nТребуется nameplate_range.dll - без неё текст не появится. Статус DLL: Система.\n\nШрифт, размер, контур, тень и смещение настраиваются в Модули -> Индикаторы здоровья -> Дистанция до неймплейта.\n\nАвтор: " .. ("frostatom" or "Неизвестен") .. "\nВерсия: " .. ("1.0" or "Неизвестна"),
				order = 2,
				width = "full",
			},
		},
	}
end
