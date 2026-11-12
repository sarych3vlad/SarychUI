local SUI = SarychUI
local extension = SUI.extensions.visibility_control

local function ModuleDB(key)
	local modules = SUI.db and SUI.db.profile and SUI.db.profile.modules
	return modules and modules[key]
end

local function VisibilityDB(moduleKey, field)
	local db = ModuleDB(moduleKey)
	if not db then return end
	if type(db[field]) ~= "table" then
		local defaults = SUI.defaults.profile.modules[moduleKey][field]
		db[field] = defaults and CopyTable(defaults) or {}
	end
	return db[field]
end

local function ModuleEnabled(key)
	local db = ModuleDB(key)
	return not extension:IsEnabled() or not db or (db.enabled ~= true and db.enabled ~= 1)
end

local function AuraBlacklistDisabled()
    local auras, groups = ModuleDB("auras"), ModuleDB("group_frames")
    local activeAuras = not ModuleEnabled("auras") and auras and (auras.playerAuraBlacklistEnabled or auras.frameAuraBlacklistEnabled)
    local activeGroups = not ModuleEnabled("group_frames") and groups and groups.auraBlacklistEnabled
    return not (activeAuras or activeGroups)
end

local function Apply(moduleKey, method)
	local module = SUI.modules and SUI.modules[moduleKey]
	if module and module[method] then module[method](module) end
end

local function Refresh()
	if SUI.NotifySarychUIOptionsChange then SUI:NotifySarychUIOptionsChange() end
end

local function IsOn(v)
	return v == true or v == 1
end

local function EnabledOption(moduleKey, field, method, description)
	return {
		type = "toggle", name = "ui.text_1d8bb213",
		desc = description, order = 1, width = "full",
		disabled = function() return field == "blacklistVisibility" and AuraBlacklistDisabled() or field ~= "blacklistVisibility" and ModuleEnabled(moduleKey) end,
		get = function()
			local db = VisibilityDB(moduleKey, field)
			return db and IsOn(db.enabled)
		end,
		set = function(_, value)
			local db = VisibilityDB(moduleKey, field)
			if not db then return end
			db.enabled = value and 1 or 0
			Apply(moduleKey, method)
			Refresh()
		end,
	}
end

local function KeyOption(moduleKey, field, method, label, description)
	return {
		type = "keybinding", name = label, desc = description,
		order = 2, width = "full",
		disabled = function() return field == "blacklistVisibility" and AuraBlacklistDisabled() or field ~= "blacklistVisibility" and ModuleEnabled(moduleKey) end,
		hidden = function()
			local db = VisibilityDB(moduleKey, field)
			return not db or not IsOn(db.enabled)
		end,
		get = function()
			local db = VisibilityDB(moduleKey, field)
			return db and db.key
		end,
		set = function(_, value)
			local db = VisibilityDB(moduleKey, field)
			if not db then return end
			db.key = value
			Apply(moduleKey, method)
		end,
	}
end

local function Choice(moduleKey, field, method, key, label, order)
	return {
		type = "toggle", name = label, order = order,
		disabled = function() return field == "blacklistVisibility" and AuraBlacklistDisabled() or field ~= "blacklistVisibility" and ModuleEnabled(moduleKey) end,
		hidden = function()
			local db = VisibilityDB(moduleKey, field)
			return not db or not IsOn(db.enabled)
		end,
		get = function()
			local db = VisibilityDB(moduleKey, field)
			return db and IsOn(db[key])
		end,
		set = function(_, value)
			local db = VisibilityDB(moduleKey, field)
			if not db then return end
			db[key] = value and 1 or 0
			Apply(moduleKey, method)
		end,
	}
end

function extension:GetOptions()
	local chatKey, chatField, chatApply = "chat", "chatVisibility", "ApplyChatVisibilitySettings"
	local frameKey, frameField, frameApply = "frame", "frameVisibility", "ApplyFrameVisibilitySettings"
	local minimapKey, minimapField, minimapApply = "minimap", "minimapVisibility", "ApplyVisibilitySettings"
	local barKey, barField, barApply = "mainmenubar", "barVisibility", "ApplyBarVisibilitySettings"
	return {
		type = "group", name = "ui.text_09f49033",
		childGroups = "tab",
		suiWrapTabs = true,
		suiBodyDisabled = function() return not extension:IsEnabled() end,
		suiTabIntro = SarychUI:T("ui.options_b0b79f8658"),
		args = {
			enabled = {
				type = "toggle", name = "ui.enable_a54eaf37", order = 1,
				get = function() return extension:IsEnabled() end,
				set = function(_, value)
					local db = extension:GetDB()
					if not db then return end
					db.enabled = value and true or false
					extension:RefreshConfig()
					Refresh()
					if SUI.OptionsCore and SUI.OptionsCore.ScheduleSmartRefresh then
						SUI.OptionsCore:ScheduleSmartRefresh(true)
					end
				end,
			},
            characterAuras = {
                type = "group", name = "ui.options_f00ebe5721", order = 7,
                disabled = AuraBlacklistDisabled,
                args = {
                    settings = { type = "group", name = "ui.visibility.blacklist", order = 1, inline = true, args = {
                        enabled = EnabledOption("auras", "blacklistVisibility", "ApplyBlacklistVisibilitySettings",
                            "ui.visibility.blacklist_toggle_desc"),
                        key = KeyOption("auras", "blacklistVisibility", "ApplyBlacklistVisibilitySettings",
                            "ui.visibility.blacklist_key", "ui.visibility.blacklist_key_desc"),
                    } },
                },
            },
			chat = {
				type = "group", name = "ui.chat_917bb522", order = 1,
				disabled = function() return ModuleEnabled(chatKey) end,
				args = {
					settings = { type = "group", name = "", order = 1, inline = true, args = {
					enabled = EnabledOption(chatKey, chatField, chatApply,
						SarychUI:T("ui.options_79b2efce08")),
					key = KeyOption(chatKey, chatField, chatApply, SarychUI:T("ui.options_a45f302f55"),
						SarychUI:T("ui.options_5193a48961")),
					} },
				},
			},
			frames = {
				type = "group", name = "ui.frames_ce7f103c", order = 2,
				disabled = function() return ModuleEnabled(frameKey) end,
				args = {
					settings = { type = "group", name = "", order = 1, inline = true, args = {
					enabled = EnabledOption(frameKey, frameField, frameApply,
						SarychUI:T("ui.options_d479075562")),
					key = KeyOption(frameKey, frameField, frameApply, SarychUI:T("ui.options_1892ee22c9"),
						SarychUI:T("ui.options_c977ec91f0")),
					player = Choice(frameKey, frameField, frameApply, "player", SarychUI:T("ui.player_f54f58cf"), 3),
					target = Choice(frameKey, frameField, frameApply, "target", SarychUI:T("ui.target_1d6ae787"), 4),
					focus = Choice(frameKey, frameField, frameApply, "focus", SarychUI:T("ui.focus_1913a1d2"), 5),
					} },
				},
			},
			minimap = {
				type = "group", name = "ui.minimap_0caefe45", order = 3,
				disabled = function() return ModuleEnabled(minimapKey) end,
				args = {
					settings = { type = "group", name = "", order = 1, inline = true, args = {
					enabled = EnabledOption(minimapKey, minimapField, minimapApply,
						SarychUI:T("ui.options_e896dc91b2")),
					key = KeyOption(minimapKey, minimapField, minimapApply, SarychUI:T("ui.options_7319085668"),
						SarychUI:T("ui.options_ab787aae35")),
					} },
				},
			},
			actionBars = {
				type = "group", name = "ui.action_bar_0b0a9a7e", order = 4,
				disabled = function() return ModuleEnabled(barKey) end,
				args = {
					settings = { type = "group", name = "", order = 1, inline = true, args = {
					enabled = EnabledOption(barKey, barField, barApply,
						SarychUI:T("ui.options_577eff453b")),
					key = KeyOption(barKey, barField, barApply, SarychUI:T("ui.options_c54c1f3618"),
						SarychUI:T("ui.options_9a4b981d07")),
					stance = Choice(barKey, barField, barApply, "stance", SarychUI:T("ui.options_2c489e3d4f"), 3),
					pet = Choice(barKey, barField, barApply, "pet", SarychUI:T("ui.options_ced4d28ab8"), 4),
					} },
				},
			},
			bags = {
				type = "group", name = "ui.bags_a5b99f75", order = 5,
				disabled = function() return ModuleEnabled(barKey) end,
				args = {
					settings = { type = "group", name = "", order = 1, inline = true, args = {
					enabled = EnabledOption(barKey, "bagsVisibility", barApply,
						SarychUI:T("ui.options_c4eda24a32")),
					key = KeyOption(barKey, "bagsVisibility", barApply, SarychUI:T("ui.options_14ec6fbaac"),
						SarychUI:T("ui.options_1dc2e93777")),
					} },
				},
			},
			micro = {
				type = "group", name = "ui.micro_menu_0fc8f435", order = 6,
				disabled = function() return ModuleEnabled(barKey) end,
				args = {
					settings = { type = "group", name = "", order = 1, inline = true, args = {
					enabled = EnabledOption(barKey, "microVisibility", barApply,
						SarychUI:T("ui.options_e5d1d25361")),
					key = KeyOption(barKey, "microVisibility", barApply, SarychUI:T("ui.options_3b8980991e"),
						SarychUI:T("ui.options_fa9cbea0d9")),
					} },
				},
			},
		},
	}
end
