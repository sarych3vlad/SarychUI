-- Native loot_management ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.loot_management

function owner:Ispretty_lootalertEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.pretty_lootalert
    return cfg and cfg.enabled ~= false or false
end

function owner:Ispretty_lootalertRunning()
    return self.pretty_lootalertRunning == true
end

function owner:Setpretty_lootalertEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.pretty_lootalert = profile.addons.pretty_lootalert or {}
    profile.addons.pretty_lootalert.enabled = enable and true or false
    return self:Applypretty_lootalert()
end

function owner:Applypretty_lootalert(forceOff)
    local cfg = SarychUI.db.profile.modules.loot_management
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:Ispretty_lootalertEnabled()
    pretty_lootalertEnabled = enable and true or false
    local running = false
    if LootAlertFrame then
        local events = {"CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "CHAT_MSG_MONEY", "UPDATE_BATTLEFIELD_STATUS", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED"}
        for _, event in ipairs(events) do
            if enable then LootAlertFrame:RegisterEvent(event) else LootAlertFrame:UnregisterEvent(event) end
        end
        if not enable then
            if LootAlertFrame.alertQueue then wipe(LootAlertFrame.alertQueue) end
            for _, button in pairs(LootAlertFrame.alertButton or {}) do button:Hide() end
        end
        running = enable
    end
    self.pretty_lootalertRunning = running and true or false
    return self.pretty_lootalertRunning
end

function owner:Getpretty_lootalertOptions()
	return {
		type = "group",
		name = "pretty_lootalert",
		order = 6,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить pretty_lootalert",
				order = 1,
				get = function()
					return owner:Ispretty_lootalertEnabled()
				end,
				set = function(_, value)
					owner:Setpretty_lootalertEnabled(value)
				end,
			},
			castbarOffsetEnabled = {
				type = "toggle",
				name = "Смещать по Y при касте",
				desc = "Когда отображается полоса заклинания игрока, сдвигать всплывающие уведомления о луте по вертикали, чтобы не перекрывали кастбар",
				order = 2,
				width = "full",
				disabled = function()
					return not owner:Ispretty_lootalertEnabled()
				end,
				get = function()
					local t = SarychUI.db.profile.addons.pretty_lootalert
					return t.castbarOffsetEnabled ~= false
				end,
				set = function(info, value)
					if not SarychUI.db.profile.addons.pretty_lootalert then
						SarychUI.db.profile.addons.pretty_lootalert = {}
					end
					SarychUI.db.profile.addons.pretty_lootalert.castbarOffsetEnabled = value
					if LootAlertFrame and LootAlertFrame.AdjustAnchors then
						LootAlertFrame:AdjustAnchors()
					end
				end,
			},
			castbarOffsetY = {
				type = "range",
				name = "Смещение Y при касте",
				desc = "Дополнительный отступ по вертикали (пиксели), пока открыта полоса каста. Положительные значения сдвигают тосты выше, отрицательные - ниже.",
				order = 3,
				min = -300,
				max = 300,
				step = 1,
				width = "full",
				disabled = function()
					local t = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.pretty_lootalert
					return not (owner:Ispretty_lootalertEnabled() and t and t.castbarOffsetEnabled ~= false)
				end,
				get = function()
					local t = SarychUI.db.profile.addons.pretty_lootalert
					local v = t.castbarOffsetY
					if v == nil then
						return 110
					end
					return v
				end,
				set = function(info, value)
					SarychUI.db.profile.addons.pretty_lootalert.castbarOffsetY = value
					if LootAlertFrame and LootAlertFrame.AdjustAnchors then
						LootAlertFrame:AdjustAnchors()
					end
				end,
			},
			castbarOffsetX = {
				type = "range",
				name = "ui.loot.castbar_offset_x",
				desc = "ui.loot.castbar_offset_x_desc",
				order = 4,
				min = -300,
				max = 300,
				step = 1,
				width = "full",
				disabled = function()
					local t = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.pretty_lootalert
					return not (owner:Ispretty_lootalertEnabled() and t and t.castbarOffsetEnabled ~= false)
				end,
				get = function()
					local t = SarychUI.db.profile.addons.pretty_lootalert
					local v = t.castbarOffsetX
					if v == nil then
						return 0
					end
					return v
				end,
				set = function(info, value)
					SarychUI.db.profile.addons.pretty_lootalert.castbarOffsetX = value
					if LootAlertFrame and LootAlertFrame.AdjustAnchors then
						LootAlertFrame:AdjustAnchors()
					end
				end,
			},
		},
	}
end
