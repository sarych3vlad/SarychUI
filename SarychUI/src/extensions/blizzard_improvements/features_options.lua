-- Options owned by the component; shared rendering lives in src/options.
local moduleName = "tools"

local L = SarychUI.L

local module = SarychUI.modules.blizzard_improvements

local function DB()
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
		return nil
	end
	return SarychUI.db.profile.modules[moduleName]
end

local function isOn(key)
	local db = DB(); if not db then return false end
	local v = db[key]
	return v == 1 or v == true
end

local function toggleGetter(info)
	local db = DB(); if not db then return false end
	local key = info[#info]
	local v = db[key]
	return v == 1 or v == true
end

local function Refresh()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

function SarychUI.modules.blizzard_improvements:GetBlizzardImprovementOptions()
    return {
blizzMoveBox = {
						type = "group",
						name = "ui.move_blizzard_windows_a183d3af",
						desc = "ui.blizzard_window_move_settings_76817d68",
						order = 5,
						inline = true,
						args = {
							enableBlizzMove = {
								type = "toggle",
								name = "ui.move_blizzard_windows_a183d3af",
								desc = "ui.makes_blizzard_windows_movable_drag_to_move_cont_4272ff82",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableBlizzMove = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyBlizzMove then SarychUI.modules.blizzard_improvements:ApplyBlizzMove() end
									Refresh()
								end,
							},
							blizzMoveMouseButton = {
								type = "select",
								name = "ui.mouse_button_for_moving_123aad3c",
								desc = "ui.choose_a_mouse_button_for_moving_windows_e71188c8",
								order = 2,
								width = "full",
								values = {
									LeftButton = SarychUI:T("ui.options_ec888e59e5"),
									RightButton = SarychUI:T("ui.options_d822ebb002"),
									MiddleButton = SarychUI:T("ui.options_446d8547a9"),
								},
								get = function()
									local db = DB(); return (db and db.blizzMoveMouseButton) or "LeftButton"
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.blizzMoveMouseButton = val
									if module and SarychUI.modules.blizzard_improvements.ApplyBlizzMove then SarychUI.modules.blizzard_improvements:ApplyBlizzMove() end
									Refresh()
								end,
								disabled = function() return not isOn("enableBlizzMove") end,
							},
						},
					},
quickActionsBox = {
						type = "group",
						name = "ui.quick_actions_29fa2be4",
						order = 6,
						inline = true,
						args = {
							enableEasyItemDestroy = {
								type = "toggle",
								name = "ui.easy_item_destruction_a21a8503",
								desc = "ui.if_checked_you_no_longer_need_to_type_delete_whe_1fd04e3c",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableEasyItemDestroy = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyEasyItemDestroy then
										SarychUI.modules.blizzard_improvements:ApplyEasyItemDestroy()
									end
									Refresh()
								end,
							},
							enableBadgeStackBuyer = {
								type = "toggle",
								name = "ui.tinterface_icons_spell_holy_summonchampion_14_14_bc0f8a6c",
								desc = "ui.shift_left_click_an_emblem_at_a_vendor_quantity__4f65d66d",
								order = 2,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableBadgeStackBuyer = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyBadgeStackBuyer then
										SarychUI.modules.blizzard_improvements:ApplyBadgeStackBuyer()
									end
									Refresh()
								end,
							},
						},
					},
interfaceBox = {
						type = "group",
						name = "ui.interface_517c6d91",
						order = 1,
						inline = true,
						args = {
							enableEscToOk = {
								type = "toggle",
								name = "ui.replace_cffffd700esc_cancel_r_with_cffffd700ok_r_a26b5667",
								desc = "ui.prevents_accidentally_closing_the_default_option_42ff541f",
								order = 1,
								width = "full",
								suiHelpIcon = true,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableEscToOk = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyEscToOk then SarychUI.modules.blizzard_improvements:ApplyEscToOk() end
									Refresh()
								end,
							},
						},
					},
travelBox = {
						type = "group",
						name = "ui.text_369f5bdc",
						order = 3,
						inline = true,
						args = {
							enableShowFlightTimes = {
								type = "toggle",
								name = "ui.tinterface_minimap_tracking_flightmaster_17_17_0_0e210569",
								desc = "ui.shows_remaining_flight_time_while_airborne_with__a62f782b",
								order = 1,
								width = "full",
								suiHelpIcon = true,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableShowFlightTimes = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyShowFlightTimes then
										SarychUI.modules.blizzard_improvements:ApplyShowFlightTimes()
									end
									Refresh()
								end,
							},
						},
					},
chatExtraBox = {
						type = "group",
						name = "ui.extra_chat_features_86a7ccac",
						order = 5,
						inline = true,
						args = {
							translitAliasesEnabled = {
								type = "toggle",
								name = L and (L["Enable_Chat_Translit"] or SarychUI:T("ui.options_e8e58be2b4")) or SarychUI:T("ui.options_a2ad364577"),
								desc = L and (L["Enable_Chat_Translit_Desc"] or SarychUI:T("ui.options_c177a2647f")) or SarychUI:T("ui.options_c177a2647f"),
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.translitAliasesEnabled = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyTranslitAliases then
										SarychUI.modules.blizzard_improvements:ApplyTranslitAliases()
									end
									Refresh()
								end,
							},
							clearChatSlashEnabled = {
								type = "toggle",
								name = "ui.cffffd700_clear_r_command_to_clear_chat_839d8607",
								desc = "ui.registers_slash_commands_cffffd700_clear_r_cffff_d4aaeb7c",
								order = 2,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.clearChatSlashEnabled = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyClearChatSlash then
										SarychUI.modules.blizzard_improvements:ApplyClearChatSlash()
									end
									Refresh()
								end,
							},
						},
					},
    }
end
