-- SarychUI Floating Text Filter module options

local moduleName = "floating_text"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local function DB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile(moduleName)
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules[moduleName]
end

local function Tools()
	return SarychUI and SarychUI.modules and SarychUI.modules.floating_text
end

local function isOn(key)
	local db = DB()
	if not db then return false end
	local v = db[key]
	return v == 1 or v == true
end

local function toggleGetter(info)
	local db = DB()
	if not db then return false end
	local key = info[#info]
	local v = db[key]
	return v == 1 or v == true
end

local function numberGetter(info)
	local db = DB()
	if not db then return 0 end
	return db[info[#info]] or 0
end

local function IsModuleEnabled()
	local db = DB()
	return db and db.enabled ~= false
end

local function ApplyError()
	local tools = Tools()
	if tools and SarychUI.modules.floating_text.ApplyErrorFilter then
		SarychUI.modules.floating_text:ApplyErrorFilter()
	end
end

local function ApplyErrorSettings()
	local tools = Tools()
	if tools and SarychUI.modules.floating_text.UpdateErrorFilterSettings then
		SarychUI.modules.floating_text:UpdateErrorFilterSettings()
	end
end

local function ApplyCombat()
	local tools = Tools()
	if tools and SarychUI.modules.floating_text.ApplyCombatTextAdjust then
		SarychUI.modules.floating_text:ApplyCombatTextAdjust()
	end
end

local function ApplyBoss()
	local tools = Tools()
	if tools and SarychUI.modules.floating_text.ApplyRaidBossEmoteReposition then
		SarychUI.modules.floating_text:ApplyRaidBossEmoteReposition()
	end
end

local function RepositionBoss()
	local tools = Tools()
	if tools and SarychUI.modules.floating_text.RepositionRaidBossEmoteFrame then
		SarychUI.modules.floating_text:RepositionRaidBossEmoteFrame()
	end
end

local function ToggleDrag(frameId, enabled)
	local tools = Tools()
	if tools and SarychUI.modules.floating_text.ToggleCombatTextDrag then
		SarychUI.modules.floating_text:ToggleCombatTextDrag(frameId, enabled)
	end
end

local function ResetCombatTextPos(xKey, yKey, xFallback, yFallback, frameId, previewX, previewY)
	local db = DB()
	if not db then return end
	local def = SarychUI.defaults and SarychUI.defaults.profile.modules.floating_text
	local x = (def and def[xKey]) or xFallback
	local y = (def and def[yKey]) or yFallback
	db[xKey] = x
	db[yKey] = y
	local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
	if not (panel and panel.SyncDraftIfOpen and panel:SyncDraftIfOpen(frameId, x, y)) then
		ApplyCombat()
	end
	NotifyCombatPreview(previewX, nil, true)
	NotifyCombatPreview(previewY, nil, true)
	RefreshConfig()
end

local function RefreshConfig()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI and SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local function NotifyCombatPreview(key, value, clear)
	local preview = SarychUI and SarychUI.CombatTextPreview
	if not preview then return end
	if clear and key and preview.ClearLiveValue then
		preview:ClearLiveValue(key)
		if preview.RefreshAll then preview:RefreshAll() end
		return
	end
	if key ~= nil and preview.SetLiveValue then
		preview:SetLiveValue(key, value)
	elseif preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function SplitPatterns(text)
	local patterns = {}
	if type(text) ~= "string" then return patterns end
	for token in string.gmatch(text, "[^;]+") do
		token = token:gsub("^%s+", ""):gsub("%s+$", "")
		if token ~= "" then
			table.insert(patterns, token)
		end
	end
	return patterns
end

local function JoinPatterns(list)
	if type(list) ~= "table" or #list == 0 then return "" end
	return table.concat(list, ";")
end

local function GetPatternList(key, defaultText)
	local db = DB()
	if not db then return SplitPatterns(defaultText or "") end
	local raw = db[key]
	if raw == nil then raw = defaultText or "" end
	return SplitPatterns(raw)
end

local function SetPatternList(key, list)
	local db = DB()
	if not db then return end
	db[key] = JoinPatterns(list)
end

local function AddPattern(key, defaultText, value)
	value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" then
		if SarychUI and SarychUI.Print then
			SarychUI:Print(SarychUI:T("ui.options_45c6203add"))
		end
		return false
	end
	local list = GetPatternList(key, defaultText)
	for _, existing in ipairs(list) do
		if existing == value then
			if SarychUI and SarychUI.Print then
				SarychUI:Print(SarychUI:T("ui.options_11052eb54c"))
			end
			return false
		end
	end
	table.insert(list, value)
	SetPatternList(key, list)
	return true
end

local function RemovePattern(key, defaultText, value)
	local list = GetPatternList(key, defaultText)
	local nextList = {}
	for _, existing in ipairs(list) do
		if existing ~= value then
			table.insert(nextList, existing)
		end
	end
	SetPatternList(key, nextList)
end

local pendingHidePatternInput = ""
local pendingExceptionPatternInput = ""

local DEFAULT_HIDE_PATTERNS = "Способность пока недоступна."
local DEFAULT_EXCEPTION_PATTERNS = "Вы должны подождать;Нет места."

local function BuildPatternListArgs(key, defaultText, pendingGet, pendingSet, orderStart)
	local args = {
		addHeader = {
			type = "header",
			name = "ui.add_exception_c41bd283",
			order = orderStart or 10,
		},
		addInput = {
			type = "input",
			name = "",
			desc = "ui.message_text_or_part_of_it_to_add_to_the_list_4c5daeb5",
			order = (orderStart or 10) + 1,
			width = "full",
			suiSaveButton = SarychUI:T("ui.options_559a87f7cc"),
			get = pendingGet,
			set = function(_, val)
				pendingSet(val)
				if AddPattern(key, defaultText, val) then
					pendingSet("")
					ApplyErrorSettings()
					RefreshConfig()
				end
			end,
		},
	}

	local list = GetPatternList(key, defaultText)
	for i, pattern in ipairs(list) do
		local captured = pattern
		args["patternRow_" .. i] = {
			type = "group",
			inline = true,
			name = "",
			order = (orderStart or 10) + 10 + i,
			suiCompactListRow = true,
			args = {
				label = {
					type = "description",
					name = "|cffff1a1a" .. captured .. "|r",
					order = 1,
				},
				removeBtn = {
					type = "execute",
					name = "ui.delete_be99b136",
					order = 2,
					func = function()
						RemovePattern(key, defaultText, captured)
						ApplyErrorSettings()
						RefreshConfig()
					end,
				},
			},
		}
	end

	return args
end

function module:GetOptions()
	return {
		type = "group",
		name = "ui.floating_combat_text_98aee2fe",
		desc = "ui.filter_system_messages_configure_combat_text_and_046c5f0c",
		childGroups = "tab",
		suiTabBarExtra = {
			type = "execute",
			name = function()
				return SarychUI:T(module:IsTestModeEnabled()
					and "ui.options_2aa205e3d3" or "ui.options_ec1868c5a7")
			end,
			func = function()
				if module:IsTestModeEnabled() then module:StopTestMode() else module:StartTestMode() end
				RefreshConfig()
			end,
			disabled = function() return not IsModuleEnabled() end,
			hidden = function() return not IsModuleEnabled() end,
		},
		args = {
			general = {
				type = "group",
				name = "ui.general_b250a3d6",
				order = 1,
				childGroups = "tab",
				args = {
					enabled = {
						suiModuleEnable = true,
						type = "toggle",
						name = "ui.enable_module_b623b573",
						desc = "ui.enable_or_disable_the_module_ce99024f",
						order = 0,
						width = "full",
						get = function()
							return IsModuleEnabled()
						end,
						set = function(_, val)
							local db = DB()
							if not db then return end
							db.enabled = val and true or false
							if val then
								if SarychUI.EnableModule then
									SarychUI:EnableModule(moduleName)
								end
							else
								if SarychUI.DisableModule then
									SarychUI:DisableModule(moduleName)
								end
							end
							RefreshConfig()
						end,
					},
					errors = {
						type = "group",
						name = "ui.error_filter_92f36794",
						order = 1,
						args = {
							filterBox = {
								type = "group",
								name = "ui.error_filter_92f36794",
								order = 0,
								inline = true,
								args = {
									enableErrorFilter = {
										type = "toggle",
										name = "ui.enable_hiding_00e7e1b5",
										desc = "ui.enables_system_error_interception_hide_exception_a533c002",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.enableErrorFilter = val and 1 or 0
											ApplyError()
											RefreshConfig()
										end,
									},
									errorShowOriginalOnAlt = {
										type = "toggle",
										name = "ui.show_original_errors_only_with_cffffd700alt_r_496ec38a",
										desc = "ui.original_errors_are_only_visible_while_holding_c_45628329",
										order = 2,
										width = "full",
										suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
										disabled = function()
											return not isOn("enableErrorFilter")
										end,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorShowOriginalOnAlt = val and 1 or 0
											ApplyErrorSettings()
											RefreshConfig()
										end,
									},
								},
							},

							preview = {
								type = "description",
								name = "",
								order = 1,
								width = "full",
								suiPreview = "ErrorFilterPreview",
							},

							timingBox = {
							type = "group",
							name = "ui.display_settings_91ae2667",
							order = 2,
							inline = true,
							disabled = function()
								return not isOn("enableErrorFilter")
							end,
							args = {
								errorTimeVisible = {
									type = "range",
									name = "ui.visibility_time_7728fd5f",
									desc = "ui.how_long_a_message_stays_visible_before_fading_s_426eb11a",
									min = 0,
									max = 10,
									step = 0.1,
									order = 1,
									width = "full",
									suiPreviewKey = "errorTimeVisible",
									get = numberGetter,
									set = function(info, val)
										local db = DB()
										if not db then return end
										db.errorTimeVisible = val
										ApplyErrorSettings()
										if SarychUI.ErrorFilterPreview then
											if SarychUI.ErrorFilterPreview.ClearLiveValue then
												SarychUI.ErrorFilterPreview:ClearLiveValue("errorTimeVisible")
											end
											if SarychUI.ErrorFilterPreview.RefreshAll then
												SarychUI.ErrorFilterPreview:RefreshAll()
											end
										end
										-- No RefreshConfig: full rebuild leaves cooltip backdrop ghosts while typing.
									end,
								},
								errorFadeDuration = {
									type = "range",
									name = "ui.smoothness_26288c80",
									desc = "ui.message_fade_out_animation_duration_seconds_41f1cace",
									min = 0,
									max = 10,
									step = 0.1,
									order = 2,
									width = "full",
									suiPreviewKey = "errorFadeDuration",
									get = numberGetter,
									set = function(info, val)
										local db = DB()
										if not db then return end
										db.errorFadeDuration = val
										ApplyErrorSettings()
										if SarychUI.ErrorFilterPreview then
											if SarychUI.ErrorFilterPreview.ClearLiveValue then
												SarychUI.ErrorFilterPreview:ClearLiveValue("errorFadeDuration")
											end
											if SarychUI.ErrorFilterPreview.RefreshAll then
												SarychUI.ErrorFilterPreview:RefreshAll()
											end
										end
									end,
								},
								errorThrottleWindow = {
									type = "range",
									name = "ui.anti_spam_window_1dbac502",
									desc = "ui.temporary_window_to_prevent_repeated_identical_m_0b74dd94",
									min = 0,
									max = 5,
									step = 0.1,
									order = 3,
									width = "full",
									suiPreviewKey = "errorThrottleWindow",
									get = numberGetter,
									set = function(info, val)
										local db = DB()
										if not db then return end
										db.errorThrottleWindow = val
										if SarychUI.ErrorFilterPreview then
											if SarychUI.ErrorFilterPreview.ClearLiveValue then
												SarychUI.ErrorFilterPreview:ClearLiveValue("errorThrottleWindow")
											end
											if SarychUI.ErrorFilterPreview.RefreshAll then
												SarychUI.ErrorFilterPreview:RefreshAll()
											end
										end
									end,
								},
							},
						},

						hideBox = {
							type = "group",
							name = "ui.always_hide_001db559",
							desc = "ui.messages_in_this_list_are_never_shown_even_while_36c1c24f",
							order = 3,
							inline = true,
							disabled = function()
								return not isOn("enableErrorFilter")
							end,
							args = (function()
								local args = BuildPatternListArgs(
									"errorHidePatterns",
									DEFAULT_HIDE_PATTERNS,
									function() return pendingHidePatternInput end,
									function(v) pendingHidePatternInput = v or "" end,
									1
								)
								args.addHeader.name = SarychUI:T("ui.options_c483d128c4")
								args.addInput.desc = SarychUI:T("ui.options_59187c6c7c")
								return args
							end)(),
						},

						extraBox = {
							type = "group",
							name = "ui.extra_error_frame_5571a4e3",
							desc = "ui.a_separate_block_for_important_errors_you_still__838c4763",
							order = 4,
							inline = true,
							disabled = function()
								return not isOn("enableErrorFilter")
							end,
							args = (function()
								local extraDisabled = function()
									return not isOn("enableErrorFilter") or not isOn("errorExtraEnabled")
								end

								local args = {
									errorExtraEnabled = {
										type = "toggle",
										name = "ui.enable_extra_frame_7d3ac481",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorExtraEnabled = val and 1 or 0
											ApplyErrorSettings()
											RefreshConfig()
										end,
									},
									errorFilteredOffsetY = {
										type = "range",
										name = "ui.extra_exceptions_frame_y_offset_c601811d",
										desc = "ui.vertical_offset_of_the_extra_exceptions_frame_331992de",
										min = -1000,
										max = 1000,
										step = 1,
										order = 2,
										width = "full",
										disabled = extraDisabled,
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorFilteredOffsetY = val
											ApplyErrorSettings()
										end,
									},
									errorEchoToChat = {
										type = "toggle",
										name = "ui.echo_exception_text_to_chat_1698f29c",
										desc = "ui.send_filter_exceptions_to_chat_b4865e8b",
										order = 3,
										width = "full",
										disabled = extraDisabled,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorEchoToChat = val and 1 or 0
											RefreshConfig()
										end,
									},
									errorPlaySound = {
										type = "toggle",
										name = "ui.tinterface_common_voicechat_speaker_14_14_0_0_t__b1baf0f3",
										desc = "ui.play_a_sound_when_exceptions_appear_f5a4550e",
										order = 4,
										width = "full",
										disabled = extraDisabled,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorPlaySound = val and 1 or 0
											RefreshConfig()
										end,
									},
								}

								local listArgs = BuildPatternListArgs(
									"errorExceptionPatterns",
									DEFAULT_EXCEPTION_PATTERNS,
									function() return pendingExceptionPatternInput end,
									function(v) pendingExceptionPatternInput = v or "" end,
									10
								)
								for key, opt in pairs(listArgs) do
									if type(opt) == "table" then
										local prevDisabled = opt.disabled
										opt.disabled = function(...)
											if extraDisabled() then return true end
											if prevDisabled then return prevDisabled(...) end
											return false
										end
									end
									args[key] = opt
								end

								return args
							end)(),
						},
					},
					},
					notifications = {
						type = "group",
						name = "ui.game_notifications_fe17712d",
						desc = "ui.raid_boss_event_notification_settings_0f4ae846",
						order = 2,
						args = {
							displayBox = {
								type = "group",
								name = "ui.system_messages_b49f1ebf",
								desc = "ui.for_example_quest_completion_notifications_8918fbb8",
								order = 1,
								inline = true,
								args = {
									errorSysMsgOffsetY = {
										type = "range",
										name = "ui.y_axis_position_adjustment_7a98960a",
										desc = "ui.system_message_frame_vertical_offset_ef03980e",
										min = -1000,
										max = 1000,
										step = 1,
										order = 1,
										width = "full",
										suiPreviewKey = "errorSysMsgOffsetY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorSysMsgOffsetY = val
											ApplyErrorSettings()
											if SarychUI.SysMsgPreview then
												if SarychUI.SysMsgPreview.ClearLiveValue then
													SarychUI.SysMsgPreview:ClearLiveValue("errorSysMsgOffsetY")
												end
												if SarychUI.SysMsgPreview.RefreshAll then
													SarychUI.SysMsgPreview:RefreshAll()
												end
											end
											-- No RefreshConfig on range commit - rebuild orphans cooltip textures.
										end,
									},
								},
							},
							sysPreview = {
								type = "description",
								name = "",
								order = 2,
								width = "full",
								suiPreview = "SysMsgPreview",
							},
							notifBox = {
								type = "group",
								name = "ui.game_notifications_fe17712d",
								order = 3,
								inline = true,
								args = {
									enableRaidBossEmoteReposition = {
										type = "toggle",
										name = "ui.boss_notification_message_frame_06f631c4",
										desc = "ui.changes_the_position_and_width_of_the_raid_boss__4742cf1e",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.enableRaidBossEmoteReposition = val and 1 or 0
											ApplyBoss()
											if SarychUI.BossEmotePreview then
												if SarychUI.BossEmotePreview.SetLiveValue then
													SarychUI.BossEmotePreview:SetLiveValue("enableRaidBossEmoteReposition", val and 1 or 0)
												elseif SarychUI.BossEmotePreview.RefreshAll then
													SarychUI.BossEmotePreview:RefreshAll()
												end
											end
											RefreshConfig()
										end,
									},
									raidBossEmoteOffsetY = {
										type = "range",
										name = "ui.y_offset_f7f3fdd7",
										desc = "ui.boss_message_frame_vertical_offset_769b45ba",
										min = -1000,
										max = 1000,
										step = 1,
										order = 2,
										width = "full",
										suiPreviewKey = "raidBossEmoteOffsetY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.raidBossEmoteOffsetY = val
											RepositionBoss()
											if SarychUI.BossEmotePreview then
												if SarychUI.BossEmotePreview.ClearLiveValue then
													SarychUI.BossEmotePreview:ClearLiveValue("raidBossEmoteOffsetY")
												end
												if SarychUI.BossEmotePreview.RefreshAll then
													SarychUI.BossEmotePreview:RefreshAll()
												end
											end
										end,
										hidden = function()
											return not isOn("enableRaidBossEmoteReposition")
										end,
									},
									raidBossEmoteMaxWidth = {
										type = "range",
										name = "ui.width_px_3ae76a52",
										desc = "ui.maximum_boss_message_frame_width_in_pixels_f57756aa",
										min = 200,
										max = 1200,
										step = 10,
										order = 3,
										width = "full",
										suiPreviewKey = "raidBossEmoteMaxWidth",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.raidBossEmoteMaxWidth = val
											RepositionBoss()
											if SarychUI.BossEmotePreview then
												if SarychUI.BossEmotePreview.ClearLiveValue then
													SarychUI.BossEmotePreview:ClearLiveValue("raidBossEmoteMaxWidth")
												end
												if SarychUI.BossEmotePreview.RefreshAll then
													SarychUI.BossEmotePreview:RefreshAll()
												end
											end
										end,
										hidden = function()
											return not isOn("enableRaidBossEmoteReposition")
										end,
									},
								},
							},
							bossPreview = {
								type = "description",
								name = "",
								order = 4,
								width = "full",
								suiPreview = "BossEmotePreview",
							},
						},
					},
				},
			},

			combatText = {
				type = "group",
				name = "ui.combat_text_3528d535",
				desc = "ui.combat_text_offset_and_hide_settings_healing_dam_1b3c3367",
				order = 3,
				disabled = function()
					return not IsModuleEnabled()
				end,
				childGroups = "tab",
				args = {
					frames = {
						type = "group",
						name = "ui.frames_ce7f103c",
						order = 1,
						args = {
							framesPreview = {
								type = "description",
								name = "",
								order = 0,
								width = "full",
								suiPreview = "FrameHitPreview",
							},
							framesBox = {
								type = "group",
								name = "ui.combat_text_on_frames_54ab9429",
								order = 1,
								inline = true,
								args = {
									hidePlayerHitIndicator = {
										type = "toggle",
										name = "ui.disable_combat_text_on_the_cffffd700player_r_fra_a0a8fca4",
										desc = "ui.hide_damage_and_healing_text_on_the_cffffd700pla_32c58c87",
										order = 1,
										width = "full",
										get = function()
											local frameDb = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
											return frameDb and frameDb.hidePlayerHitIndicator == 1
										end,
										set = function(_, val)
											local frameDb = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
											if not frameDb then return end
											frameDb.hidePlayerHitIndicator = val and 1 or 0
											local frameMod = SarychUI.modules and SarychUI.modules.frame
											if frameMod and frameMod.ApplySettings then
												frameMod:ApplySettings()
											end
											if SarychUI.FrameHitPreview then
												if SarychUI.FrameHitPreview.SetLiveValue then
													SarychUI.FrameHitPreview:SetLiveValue("hidePlayerHitIndicator", val and 1 or 0)
												elseif SarychUI.FrameHitPreview.RefreshAll then
													SarychUI.FrameHitPreview:RefreshAll()
												end
											end
											RefreshConfig()
										end,
									},
									hidePetHitIndicator = {
										type = "toggle",
										name = "ui.disable_combat_text_on_the_cffffd700pet_r_frame_07302073",
										desc = "ui.hide_damage_and_healing_text_on_the_cffffd700pet_c00908fc",
										order = 2,
										width = "full",
										get = function()
											local frameDb = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
											return frameDb and frameDb.hidePetHitIndicator == 1
										end,
										set = function(_, val)
											local frameDb = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
											if not frameDb then return end
											frameDb.hidePetHitIndicator = val and 1 or 0
											local frameMod = SarychUI.modules and SarychUI.modules.frame
											if frameMod and frameMod.ApplySettings then
												frameMod:ApplySettings()
											end
											if SarychUI.FrameHitPreview then
												if SarychUI.FrameHitPreview.SetLiveValue then
													SarychUI.FrameHitPreview:SetLiveValue("hidePetHitIndicator", val and 1 or 0)
												elseif SarychUI.FrameHitPreview.RefreshAll then
													SarychUI.FrameHitPreview:RefreshAll()
												end
											end
											RefreshConfig()
										end,
									},
								},
							},
						},
					},
					incoming = {
						type = "group",
						name = "ui.incoming_damage_healing_proc_text_364880e4",
						order = 2,
						args = {
							combatBox = {
								type = "group",
								name = "ui.modify_combat_text_7190c89c",
								order = 1,
								inline = true,
								args = {
									enableHealCombatTextAdjust = {
										type = "toggle",
										name = "ui.enable_a54eaf37",
										desc = "ui.enable_combat_text_processing_healing_and_damage_68021d30",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.enableHealCombatTextAdjust = val and 1 or 0
											ApplyCombat()
											NotifyCombatPreview("enableHealCombatTextAdjust", val and 1 or 0)
											RefreshConfig()
										end,
									},
								},
							},
							combatPreview = {
								type = "description",
								name = "",
								order = 1.5,
								width = "full",
								suiPreview = "CombatTextPreview",
								hidden = function()
									return not isOn("enableHealCombatTextAdjust")
								end,
							},
							plusBox = {
								type = "group",
								name = "ui.modify_incoming_healing_248e5eff",
								desc = "ui.settings_for_combat_text_starting_with_healing_43350f9f",
								order = 2,
								inline = true,
								suiTwoCol = true,
								hidden = function()
									return not isOn("enableHealCombatTextAdjust")
								end,
								args = {
									healShiftPlus = {
										type = "toggle",
										name = "ui.enable_a54eaf37",
										desc = "ui.enable_healing_text_offset_lines_starting_with_6ea6fad1",
										order = 1,
										width = "full",
										suiFullRow = true,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healShiftPlus = val and 1 or 0
											ApplyCombat()
											NotifyCombatPreview("healShiftPlus", val and 1 or 0)
											RefreshConfig()
										end,
									},
									healPlusX = {
										type = "range",
										name = "ui.x_offset_0b923c73",
										desc = "ui.healing_text_horizontal_offset_0a6cec43",
										min = -1000,
										max = 1000,
										step = 1,
										order = 2,
										suiPreviewKey = "healPlusX",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healPlusX = val
											ApplyCombat()
											NotifyCombatPreview("healPlusX", nil, true)
										end,
										hidden = function()
											return not isOn("healShiftPlus")
										end,
									},
									healPlusY = {
										type = "range",
										name = "ui.y_offset_f7f3fdd7",
										desc = "ui.healing_text_vertical_offset_2e15e1d8",
										min = -1000,
										max = 1000,
										step = 1,
										order = 3,
										suiPreviewKey = "healPlusY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healPlusY = val
											ApplyCombat()
											NotifyCombatPreview("healPlusY", nil, true)
										end,
										hidden = function()
											return not isOn("healShiftPlus")
										end,
									},
									combatTextPlusDrag = {
										type = "execute",
										name = function()
											local db = DB() or {}
											if db.combatTextPlusDrag == 1 then
												return SarychUI:T("ui.options_76e4992833")
											end
											return SarychUI:T("ui.options_0510004a87")
										end,
										desc = "ui.show_a_drag_frame_for_healing_text_position_7802f8b4",
										order = 4,
										width = "full",
										suiFullRow = true,
										func = function()
											local db = DB()
											if not db then return end
											local val = not (db.combatTextPlusDrag == 1)
											db.combatTextPlusDrag = val and 1 or 0
											ToggleDrag("combatTextPlus", val)
											RefreshConfig()
										end,
										suiResetDefaults = function()
											ResetCombatTextPos("healPlusX", "healPlusY", -467, -45, "combatTextPlus", "healPlusX", "healPlusY")
										end,
										hidden = function()
											return not isOn("healShiftPlus")
										end,
									},
								},
							},
							minusBox = {
								type = "group",
								name = "ui.modify_incoming_damage_3280ebff",
								desc = "ui.settings_for_combat_text_starting_with_damage_f1a1c38f",
								order = 3,
								inline = true,
								suiTwoCol = true,
								hidden = function()
									return not isOn("enableHealCombatTextAdjust")
								end,
								args = {
									healShiftMinus = {
										type = "toggle",
										name = "ui.enable_a54eaf37",
										desc = "ui.enable_incoming_damage_text_offset_lines_startin_f4c0bc6b",
										order = 1,
										width = "full",
										suiFullRow = true,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healShiftMinus = val and 1 or 0
											ApplyCombat()
											NotifyCombatPreview("healShiftMinus", val and 1 or 0)
											RefreshConfig()
										end,
									},
									healMinusX = {
										type = "range",
										name = "ui.x_offset_0b923c73",
										desc = "ui.incoming_damage_text_horizontal_offset_ab4c9d31",
										min = -1000,
										max = 1000,
										step = 1,
										order = 2,
										suiPreviewKey = "healMinusX",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healMinusX = val
											ApplyCombat()
											NotifyCombatPreview("healMinusX", nil, true)
										end,
										hidden = function()
											return not isOn("healShiftMinus")
										end,
									},
									healMinusY = {
										type = "range",
										name = "ui.y_offset_f7f3fdd7",
										desc = "ui.incoming_damage_text_vertical_offset_20cdd40b",
										min = -1000,
										max = 1000,
										step = 1,
										order = 3,
										suiPreviewKey = "healMinusY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healMinusY = val
											ApplyCombat()
											NotifyCombatPreview("healMinusY", nil, true)
										end,
										hidden = function()
											return not isOn("healShiftMinus")
										end,
									},
									combatTextMinusDrag = {
										type = "execute",
										name = function()
											local db = DB() or {}
											if db.combatTextMinusDrag == 1 then
												return SarychUI:T("ui.options_76e4992833")
											end
											return SarychUI:T("ui.options_0510004a87")
										end,
										desc = "ui.show_a_drag_frame_for_incoming_damage_text_posit_16e942b2",
										order = 4,
										width = "full",
										suiFullRow = true,
										func = function()
											local db = DB()
											if not db then return end
											local val = not (db.combatTextMinusDrag == 1)
											db.combatTextMinusDrag = val and 1 or 0
											ToggleDrag("combatTextMinus", val)
											RefreshConfig()
										end,
										suiResetDefaults = function()
											ResetCombatTextPos("healMinusX", "healMinusY", 0, -50, "combatTextMinus", "healMinusX", "healMinusY")
										end,
										hidden = function()
											return not isOn("healShiftMinus")
										end,
									},
								},
							},
							lessBox = {
								type = "group",
								name = "ui.modify_proc_text_869095c0",
								desc = "ui.settings_for_combat_text_starting_with_damage_on_bf4a0f1a",
								order = 4,
								inline = true,
								suiTwoCol = true,
								hidden = function()
									return not isOn("enableHealCombatTextAdjust")
								end,
								args = {
									lessModifyEnabled = {
										type = "toggle",
										name = "ui.enable_a54eaf37",
										desc = "ui.enable_damage_text_processing_lines_starting_wit_6c02198e",
										order = 1,
										width = "full",
										suiFullRow = true,
										get = function()
											local db = DB() or {}
											return (db.healHideLess == 1 or db.healHideLess == true or db.healShiftLess == 1 or db.healShiftLess == true)
										end,
										set = function(_, val)
											local db = DB()
											if not db then return end
											if not val then
												db.healHideLess = 0
												db.healShiftLess = 0
											else
												db.healHideLess = 0
												db.healShiftLess = 1
											end
											ApplyCombat()
											NotifyCombatPreview("healHideLess", db.healHideLess)
											NotifyCombatPreview("healShiftLess", db.healShiftLess)
											RefreshConfig()
										end,
									},
									healLessMode = {
										type = "select",
										name = "ui.mode_3f53fb87",
										desc = "ui.damage_processing_mode_hide_completely_or_show_w_7b5a037a",
										order = 2,
										width = "full",
										suiFullRow = true,
										values = { hide = SarychUI:T("ui.options_ad938f88fe"), offset = SarychUI:T("ui.options_f11581b0bd") },
										get = function()
											local db = DB() or {}
											if db.healHideLess == 1 or db.healHideLess == true then
												return "hide"
											end
											return "offset"
										end,
										set = function(_, val)
											local db = DB()
											if not db then return end
											if val == "hide" then
												db.healHideLess = 1
												db.healShiftLess = 0
											else
												db.healHideLess = 0
												db.healShiftLess = 1
											end
											ApplyCombat()
											NotifyCombatPreview("healHideLess", db.healHideLess)
											NotifyCombatPreview("healShiftLess", db.healShiftLess)
											RefreshConfig()
										end,
										hidden = function()
											local db = DB() or {}
											local enabled = (db.healHideLess == 1 or db.healHideLess == true or db.healShiftLess == 1 or db.healShiftLess == true)
											return not enabled
										end,
									},
									healLessX = {
										type = "range",
										name = "ui.x_offset_0b923c73",
										desc = "ui.damage_text_horizontal_offset_57302fae",
										min = -1000,
										max = 1000,
										step = 1,
										order = 3,
										suiPreviewKey = "healLessX",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healLessX = val
											ApplyCombat()
											NotifyCombatPreview("healLessX", nil, true)
										end,
										hidden = function()
											local db = DB() or {}
											return not (db.healHideLess ~= 1 and db.healHideLess ~= true and (db.healShiftLess == 1 or db.healShiftLess == true))
										end,
									},
									healLessY = {
										type = "range",
										name = "ui.y_offset_f7f3fdd7",
										desc = "ui.damage_text_vertical_offset_31b05d57",
										min = -1000,
										max = 1000,
										step = 1,
										order = 4,
										suiPreviewKey = "healLessY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healLessY = val
											ApplyCombat()
											NotifyCombatPreview("healLessY", nil, true)
										end,
										hidden = function()
											local db = DB() or {}
											return not (db.healHideLess ~= 1 and db.healHideLess ~= true and (db.healShiftLess == 1 or db.healShiftLess == true))
										end,
									},
									combatTextLessDrag = {
										type = "execute",
										name = function()
											local db = DB() or {}
											if db.combatTextLessDrag == 1 then
												return SarychUI:T("ui.options_76e4992833")
											end
											return SarychUI:T("ui.options_0510004a87")
										end,
										desc = "ui.show_a_drag_frame_for_damage_text_position_fe3b4916",
										order = 5,
										width = "full",
										suiFullRow = true,
										func = function()
											local db = DB()
											if not db then return end
											local val = not (db.combatTextLessDrag == 1)
											db.combatTextLessDrag = val and 1 or 0
											ToggleDrag("combatTextLess", val)
											RefreshConfig()
										end,
										suiResetDefaults = function()
											ResetCombatTextPos("healLessX", "healLessY", -250, -30, "combatTextLess", "healLessX", "healLessY")
										end,
									hidden = function()
										local db = DB() or {}
										return not (db.healHideLess ~= 1 and db.healHideLess ~= true and (db.healShiftLess == 1 or db.healShiftLess == true))
									end,
								},
							},
						},
					},
					},
				},
			},
		},
	}
end
