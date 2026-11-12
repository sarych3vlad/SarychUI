-- Options owned by the component; shared rendering lives in src/options.
local moduleName = "tools"

local module = SarychUI.modules.focus_assignment

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

function SarychUI.modules.focus_assignment:GetFocusAssignmentOptions()
 return {
focuserBox = {
						type = "group",
						name = "ui.focus_with_modifier_left_click_d02a9468",
						desc = "ui.focus_target_settings_f315d58d",
						order = 1,
						inline = true,
						args = {
							enableFocuser = {
								type = "toggle",
								name = "ui.enable_focuser_dec5df90",
								desc = "ui.lets_you_focus_a_target_using_the_selected_modif_cb3c84b0",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableFocuser = val and 1 or 0
									if module and SarychUI.modules.focus_assignment.ApplyFocuser then SarychUI.modules.focus_assignment:ApplyFocuser() end
									Refresh()
								end,
							},
							focuserModifierKey = {
								type = "select",
								name = "ui.modifier_key_47d87a5e",
								desc = "ui.choose_a_modifier_key_for_focuser_f227e70c",
								order = 2,
								width = "full",
								values = { [1] = "SHIFT", [2] = "ALT", [3] = "CTRL", __order = { 1, 2, 3 } },
								get = function()
									local db = DB(); return (db and db.focuserModifierKey) or 2
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.focuserModifierKey = tonumber(val) or 2
									if module and SarychUI.modules.focus_assignment.ApplyFocuserModifier then SarychUI.modules.focus_assignment:ApplyFocuserModifier() end
									Refresh()
								end,
								disabled = function() return not isOn("enableFocuser") end,
							},
							enableArenaRightClickFocus = {
								type = "toggle",
								name = "ui.focus_an_arena_frame_with_cffffd700right_click_r_474592ee",
								desc = "ui.right_clicking_enemy_arena_frames_sets_them_as_f_cde93033",
								order = 3,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableArenaRightClickFocus = val and 1 or 0
									if module and SarychUI.modules.focus_assignment.ApplyArenaRightClickFocus then
										SarychUI.modules.focus_assignment:ApplyArenaRightClickFocus()
									end
									Refresh()
								end,
							},
						},
					},
 }
end
