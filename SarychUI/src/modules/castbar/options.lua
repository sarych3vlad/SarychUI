-- Options: Кастбар (after Action Bar, before Player resources).

local moduleName = "castbar"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local function DB()
	return SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
end

local function NotifyOptionsChange()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local function GetTimerSetting(key, default)
	local db = DB()
	if db and db[key] ~= nil then
		return db[key]
	end
	return default
end

local function isTimerOn(key)
	local v = GetTimerSetting(key, 1)
	return v == 1 or v == true
end

local function GetBarStyle()
	local db = DB()
	return (db and db.barStyle) or "classic"
end

local function IsDragonflightStyle()
	return GetBarStyle() == "dragonflight"
end

local function OpenCastbarSettings()
	local OC = SarychUI and SarychUI.OptionsCore
	if OC and OC.SelectTab then
		OC:SelectTab("settings")
	end
end

local function ApplyScale()
	if module.ApplyScale then
		module:ApplyScale()
	end
end

local function ApplyPlayerTimerOffset()
	if module.ApplyPlayerTimerOffset then
		module:ApplyPlayerTimerOffset()
	end
	if SarychUI.CastbarTimerPreview and SarychUI.CastbarTimerPreview.RefreshAll then
		SarychUI.CastbarTimerPreview:RefreshAll()
	end
end

local DF_FIRST_SCALE = 0.9
local DF_FIRST_TIMER_Y = 40

local function SeedDragonflightDefaults(db)
	if not db or db.dragonflightDefaultsApplied then
		return false
	end
	db.scale = DF_FIRST_SCALE
	db.playerTimerOffsetY = DF_FIRST_TIMER_Y
	db.dragonflightDefaultsApplied = true
	return true
end

local function UnseedDragonflightDefaults(db)
	if not db then
		return
	end
	db.scale = 1
	db.playerTimerOffsetY = 0
	db.dragonflightDefaultsApplied = nil
end

local function timerToggleGet(key)
	return function()
		return isTimerOn(key)
	end
end

local function timerToggleSet(key)
	return function(_, val)
		local db = DB()
		if not db then return end
		db[key] = val and 1 or 0
		local tools = SarychUI and SarychUI.modules and SarychUI.modules
		if tools and SarychUI.modules.castbar.ApplyCastbarTimers then
			SarychUI.modules.castbar:ApplyCastbarTimers()
		end
		if SarychUI.CastbarTimerPreview and SarychUI.CastbarTimerPreview.RefreshAll then
			SarychUI.CastbarTimerPreview:RefreshAll()
		end
		NotifyOptionsChange()
	end
end

local function tickToggleGet(key)
	return function()
		return isTimerOn(key)
	end
end

local function tickToggleSet(key)
	return function(_, val)
		local db = DB()
		if not db then return end
		db[key] = val and 1 or 0
		if module.ApplyChannelTicks then
			module:ApplyChannelTicks()
		end
		NotifyOptionsChange()
	end
end

function module:GetOptions()
	local options = {
		type = "group",
		name = "ui.cast_bar_f9f01465",
		desc = "ui.settings_for_player_target_and_focus_cast_bars_761b073e",
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = "ui.general_b250a3d6",
				order = 1,
				args = {
					enabled = {
						suiModuleEnable = true,
						type = "toggle",
						name = "ui.enable_module_b623b573",
						desc = "ui.enable_or_disable_the_cast_bar_module_427a9b60",
						order = 1,
						width = "full",
						get = function()
							return DB() and DB().enabled
						end,
						set = function(_, v)
							local db = DB()
							if not db then return end
							db.enabled = v and true or false
							if v then
								SarychUI:EnableModule(moduleName)
							else
								SarychUI:DisableModule(moduleName)
							end
							NotifyOptionsChange()
						end,
					},
					typeRow = {
						type = "group",
						name = "ui.cast_bar_type_54a6b97c",
						order = 10,
						inline = true,
						suiSelectWithButton = true,
						args = {
							select = {
								type = "select",
								name = "ui.appearance_c407960b",
								desc = "ui.classic_wow_cast_bars_or_dragonflight_artwork_ch_3cbe3d83",
								order = 1,
								values = {
									__order = { "classic", "dragonflight" },
									classic = SarychUI:T("ui.options_03ced8ccad"),
									dragonflight = "Dragonflight",
								},
								get = function()
									return GetBarStyle()
								end,
								set = function(_, value)
									local db = DB()
									if not db then return end
									local previous = db.barStyle or "classic"
									if previous == value then return end
									db.barStyle = value
									local seeded = value == "dragonflight" and SeedDragonflightDefaults(db)
									NotifyOptionsChange()
									local function revert()
										db.barStyle = previous
										if seeded then
											UnseedDragonflightDefaults(db)
										end
										NotifyOptionsChange()
									end
									local text = SarychUI:T("ui.options_a6b263348d")
									if SarychUI.T then text = SarychUI:T(text) end
									if SarychUI.ShowReloadPopup then
										SarychUI:ShowReloadPopup(text, revert)
									end
								end,
							},
							openSettings = {
								type = "execute",
								name = "ui.settings_985b5e0f",
								desc = "ui.text_977d7582",
								order = 2,
								func = OpenCastbarSettings,
							},
						},
					},
					modeHint = {
						type = "description",
						name = "ui.cffffd700warning_r_changing_the_cast_bar_type_re_e4466ce0",
						order = 30,
						width = "full",
					},
				},
			},
			settings = {
				type = "group",
				name = "ui.settings_985b5e0f",
				order = 2,
				disabled = function()
					local db = DB()
					return not (db and db.enabled)
				end,
				args = {
					appearanceBox = {
						type = "group",
						name = "ui.cast_bars_3981d22b",
						order = 2,
						inline = true,
						hidden = function() return not IsDragonflightStyle() end,
						args = {
							scale = {
								type = "range",
								name = "ui.scale_e037e967",
								desc = "ui.dragonflight_cast_bar_scale_fe0381dc",
								min = 0.5,
								max = 2.0,
								step = 0.05,
								order = 1,
								width = "full",
								suiFullRow = true,
								get = function()
									local db = DB()
									return db and db.scale or 1
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.scale = val
									ApplyScale()
								end,
							},
							showPlayerIcon = {
								type = "toggle",
								name = "ui.text_cb5e77c2",
								desc = "ui.text_ce053e70",
								order = 2,
								width = "full",
								get = function()
									local db = DB()
									return db and (db.showPlayerIcon == true or db.showPlayerIcon == 1) or false
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.showPlayerIcon = val and true or false
									if module.ApplyPlayerIcon then
										module:ApplyPlayerIcon()
									end
									NotifyOptionsChange()
								end,
							},
							showPlayerIconCooldown = {
								type = "toggle",
								name = "ui.text_b7abef91",
								desc = "ui.text_00375055",
								order = 3,
								width = "full",
								hidden = function()
									local db = DB()
									return not (db and (db.showPlayerIcon == true or db.showPlayerIcon == 1))
								end,
								get = function()
									local db = DB()
									return not db or db.showPlayerIconCooldown ~= false
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.showPlayerIconCooldown = val and true or false
									if module.ApplyPlayerIconCooldown then
										module:ApplyPlayerIconCooldown()
									end
									NotifyOptionsChange()
								end,
							},
						},
					},
					playerTimerBox = {
						type = "group",
						name = "ui.player_timer_26e9a94a",
						order = 2,
						inline = true,
						hidden = function() return not IsDragonflightStyle() end,
						args = {
							playerTimerOffsetX = {
								type = "range",
								name = "ui.x_offset_0b923c73",
								desc = "ui.horizontal_offset_of_the_player_timer_from_its_c_907abb0a",
								min = -200,
								max = 200,
								step = 1,
								order = 1,
								get = function()
									local db = DB()
									return db and db.playerTimerOffsetX or 0
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.playerTimerOffsetX = val
									ApplyPlayerTimerOffset()
								end,
							},
							playerTimerOffsetY = {
								type = "range",
								name = "ui.y_offset_f7f3fdd7",
								desc = "ui.vertical_offset_of_the_player_timer_from_its_cur_b5978d49",
								min = -200,
								max = 200,
								step = 1,
								order = 2,
								get = function()
									local db = DB()
									return db and db.playerTimerOffsetY or 0
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.playerTimerOffsetY = val
									ApplyPlayerTimerOffset()
								end,
							},
						},
					},
					classicCastbarBox = {
						type = "group",
						name = "ui.text_2597b987",
						order = 1,
						inline = true,
						hidden = IsDragonflightStyle,
						args = {
							classicCastbarOffsetY = {
								type = "range",
								name = "ui.y_offset_f7f3fdd7",
								desc = "ui.blizzard_bcc570e6",
								min = -300,
								max = 300,
								step = 1,
								order = 1,
								width = "full",
								get = function()
									local db = DB()
									return db and db.classicCastbarOffsetY or 0
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.classicCastbarOffsetY = val
									if module.ApplyClassicCastbarOffset then module:ApplyClassicCastbarOffset() end
								end,
							},
						},
					},
					dragonflightCastbarBox = {
						type = "group",
						name = "ui.text_2597b987",
						order = 1,
						inline = true,
						hidden = function() return not IsDragonflightStyle() end,
						args = {
							dragonflightCastbarOffsetY = {
								type = "range",
								name = "ui.y_offset_f7f3fdd7",
								desc = "ui.dragonflight_blizzard_335b5722",
								min = -300,
								max = 300,
								step = 1,
								order = 1,
								width = "full",
								get = function()
									local db = DB()
									return db and db.dragonflightCastbarOffsetY or 0
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.dragonflightCastbarOffsetY = val
									if module.ApplyDragonflightCastbarOffset then module:ApplyDragonflightCastbarOffset() end
								end,
							},
						},
					},
				},
			},
			timers = {
				type = "group",
				name = "ui.timers_46d928b9",
				order = 3,
				disabled = function()
					local db = DB()
					return not (db and db.enabled)
				end,
				args = {
					castbarBox = {
						type = "group",
						name = "ui.timers_on_cast_bars_05596314",
						desc = "ui.settings_for_timers_on_spell_cast_bars_fc2652df",
						order = 1,
						inline = true,
						args = {
							preview = {
								type = "description",
								name = "",
								order = 0,
								width = "full",
								suiPreview = "CastbarTimerPreview",
							},
							enableCastbarTimers = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.enable_timers_on_cast_bars_fbf818d1",
								order = 1,
								width = "full",
								get = timerToggleGet("enableCastbarTimers"),
								set = timerToggleSet("enableCastbarTimers"),
							},
							castbarTargets = {
								type = "group",
								name = "ui.display_on_1d702810",
								order = 2,
								inline = true,
								disabled = function() return not isTimerOn("enableCastbarTimers") end,
								args = {
									enableCastbarPlayer = {
										type = "toggle",
										name = "ui.player_f54f58cf",
										desc = "ui.show_timer_on_the_player_cast_bar_1e84cf71",
										order = 1,
										width = "full",
										disabled = function() return not isTimerOn("enableCastbarTimers") end,
										get = timerToggleGet("enableCastbarPlayer"),
										set = timerToggleSet("enableCastbarPlayer"),
									},
									enableCastbarTarget = {
										type = "toggle",
										name = "ui.target_1d6ae787",
										desc = "ui.show_timer_on_the_target_cast_bar_d453d24f",
										order = 2,
										width = "full",
										disabled = function() return not isTimerOn("enableCastbarTimers") end,
										get = timerToggleGet("enableCastbarTarget"),
										set = timerToggleSet("enableCastbarTarget"),
									},
									enableCastbarFocus = {
										type = "toggle",
										name = "ui.focus_1913a1d2",
										desc = "ui.show_timer_on_the_focus_cast_bar_937e6901",
										order = 3,
										width = "full",
										disabled = function() return not isTimerOn("enableCastbarTimers") end,
										get = timerToggleGet("enableCastbarFocus"),
										set = timerToggleSet("enableCastbarFocus"),
									},
								},
							},
						},
					},
					ticksBox = {
						type = "group",
						name = "ui.castbar_tick_marks",
						desc = "ui.vertical_tick_marks_on_channeled_spells_same_ide_1110cd00",
						order = 2,
						inline = true,
						args = {
							enableCastbarTicks = {
								type = "toggle",
								name = "ui.show_castbar_tick_marks",
								desc = "ui.show_ticks_on_player_target_and_focus_channeled__134fb19e",
								order = 1,
								width = "full",
								get = tickToggleGet("enableCastbarTicks"),
								set = tickToggleSet("enableCastbarTicks"),
							},
							tickTargets = {
								type = "group",
								name = "ui.display_on_1d702810",
								order = 2,
								inline = true,
								disabled = function() return not isTimerOn("enableCastbarTicks") end,
								args = {
									enableCastbarTicksPlayer = {
										type = "toggle",
										name = "ui.player_f54f58cf",
										desc = "ui.ticks_on_the_player_cast_bar_f635e56e",
										order = 1,
										width = "full",
										get = tickToggleGet("enableCastbarTicksPlayer"),
										set = tickToggleSet("enableCastbarTicksPlayer"),
									},
									enableCastbarTicksTarget = {
										type = "toggle",
										name = "ui.target_1d6ae787",
										desc = "ui.ticks_on_the_target_cast_bar_bb2f0d31",
										order = 2,
										width = "full",
										get = tickToggleGet("enableCastbarTicksTarget"),
										set = tickToggleSet("enableCastbarTicksTarget"),
									},
									enableCastbarTicksFocus = {
										type = "toggle",
										name = "ui.focus_1913a1d2",
										desc = "ui.ticks_on_the_focus_cast_bar_988f412a",
										order = 3,
										width = "full",
										get = tickToggleGet("enableCastbarTicksFocus"),
										set = tickToggleSet("enableCastbarTicksFocus"),
									},
								},
							},
							castbarTickColor = {
								type = "color",
								name = "ui.tick_color_65da6335",
								desc = "ui.color_of_the_vertical_tick_marks_on_the_channel__4b22d224",
								order = 3,
								hasAlpha = true,
								disabled = function() return not isTimerOn("enableCastbarTicks") end,
								get = function()
									local db = DB()
									local c = db and db.castbarTickColor
									if not c then
										return 1, 1, 1, 0.9
									end
									return c.r or 1, c.g or 1, c.b or 1, c.a or 0.9
								end,
								set = function(_, r, g, b, a)
									local db = DB()
									if not db then return end
									db.castbarTickColor = db.castbarTickColor or {}
									db.castbarTickColor.r = r
									db.castbarTickColor.g = g
									db.castbarTickColor.b = b
									db.castbarTickColor.a = a or 0.8
									if module.ApplyChannelTicks then
										module:ApplyChannelTicks()
									end
								end,
							},
							castbarTickWidth = {
								type = "range",
								name = "ui.thickness_3c149a80",
								desc = "ui.width_of_each_vertical_tick_mark_2725e403",
								order = 4,
								min = 1,
								max = 6,
								step = 1,
								disabled = function() return not isTimerOn("enableCastbarTicks") end,
								get = function()
									local db = DB()
									return db and db.castbarTickWidth or 2
								end,
								set = function(_, val)
									local db = DB()
									if not db then return end
									db.castbarTickWidth = val
									if module.ApplyChannelTicks then
										module:ApplyChannelTicks()
									end
								end,
							},

						},
					},
				},
			},
		},
	}
    -- Use the existing two-column layout: a wide slider and a compact reset
    -- button to its right, for whichever castbar style is currently visible.
    for _, spec in ipairs({
        {"classicCastbarBox", "classicCastbarOffsetY"},
        {"dragonflightCastbarBox", "dragonflightCastbarOffsetY"},
    }) do
        local box = options.args.settings.args[spec[1]]
        local key = spec[2]
        local slider = box.args[key]
        box.suiTwoCol = true
        slider.width = nil
        box.args.resetPosition = {
            type = "execute",
            name = "ui.options_469631cb16",
            order = 2,
            suiTrailingFit = true,
            func = function()
                local defaults = SarychUI.defaults and SarychUI.defaults.profile
                defaults = defaults and defaults.modules and defaults.modules.castbar
                slider.set(nil, defaults and defaults[key] or 0)
                if SarychUI.SyncOpenOptionsValues then
                    SarychUI:SyncOpenOptionsValues()
                else
                    NotifyOptionsChange()
                end
            end,
        }
    end
    local tickBox = options.args.timers.args.ticksBox
    tickBox.suiTwoCol = true
    tickBox.args.enableCastbarTicks.suiFullRow = true
    tickBox.args.resetWidth = {
        type = "execute",
        name = "ui.options_469631cb16",
        order = 5,
        suiTrailingFit = true,
        disabled = tickBox.args.castbarTickWidth.disabled,
        func = function()
            local defaults = SarychUI.defaults and SarychUI.defaults.profile
            defaults = defaults and defaults.modules and defaults.modules.castbar
            tickBox.args.castbarTickWidth.set(nil, defaults and defaults.castbarTickWidth or 2)
            if SarychUI.SyncOpenOptionsValues then
                SarychUI:SyncOpenOptionsValues()
            else
                NotifyOptionsChange()
            end
        end,
    }
	options.args.settings.args.ticksBox = options.args.timers.args.ticksBox
	options.args.settings.args.ticksBox.order = 3
	options.args.timers.args.ticksBox = nil
	options.args.timers.args.playerTimerBox = options.args.settings.args.playerTimerBox
	options.args.timers.args.playerTimerBox.order = 2
	options.args.settings.args.playerTimerBox = nil
	return options
end
