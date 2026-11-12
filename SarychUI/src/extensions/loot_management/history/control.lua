-- Native loot_management ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.loot_management

function owner:IsLootHistoryEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.LootHistory
    return cfg and cfg.enabled ~= false or false
end

function owner:IsLootHistoryRunning()
    return self.LootHistoryRunning == true
end

function owner:SetLootHistoryEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.LootHistory = profile.addons.LootHistory or {}
    profile.addons.LootHistory.enabled = enable and true or false
    return self:ApplyLootHistory()
end

function owner:ApplyLootHistory(forceOff)
    local cfg = SarychUI.db.profile.modules.loot_management
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:IsLootHistoryEnabled()
    LootHistoryEnabled = enable and true or false
    local running = false
    if SarychUI_SetLootHistoryUIRuntime then SarychUI_SetLootHistoryUIRuntime(enable) end
    if SarychUI_SetLootHistoryRuntime then SarychUI_SetLootHistoryRuntime(enable) end
    if not enable and LootHistoryFrame then LootHistoryFrame:Hide() end
    if LootHistory_UpdateLootTabButton then LootHistory_UpdateLootTabButton() end
    if LootHistory_UpdateButtonVisibility then LootHistory_UpdateButtonVisibility() end
    running = enable and LootHistoryFrame ~= nil
    self.LootHistoryRunning = running and true or false
    return self.LootHistoryRunning
end

function owner:GetLootHistoryOptions()
	return {
		type = "group",
		name = "LootHistory",
		order = 11,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить LootHistory",
				order = 1,
				get = function()
					return owner:IsLootHistoryEnabled()
				end,
				set = function(_, value)
					owner:SetLootHistoryEnabled(value)
					if _G.LootHistory_UpdateButtonVisibility then
						_G.LootHistory_UpdateButtonVisibility()
					end
				end,
			},
			lootTabButtonEnabled = {
				type = "toggle",
				name = "Включить кнопку на вкладке loot",
				desc = "Добавить кнопку на вкладку loot для быстрого доступа к LootHistory",
				order = 2,
				disabled = function()
					return not owner:IsLootHistoryEnabled()
				end,
				get = function()
					if not owner:IsLootHistoryEnabled() then
						return false
					end
					return SarychUI.db.profile.addons.LootHistory.lootTabButtonEnabled == true
				end,
				set = function(info, value)
					if not owner:IsLootHistoryEnabled() then
						return
					end
					SarychUI.db.profile.addons.LootHistory.lootTabButtonEnabled = value
					if _G.LootHistory_UpdateLootTabButton then
						_G.LootHistory_UpdateLootTabButton()
					end
				end,
			},
		},
	}
end
