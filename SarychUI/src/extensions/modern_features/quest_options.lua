-- Options owned by the component; shared rendering lives in src/options.
local moduleName = "tools"

local module = SarychUI.modules.modern_features

local function DB()
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
		return nil
	end
	return SarychUI.db.profile.modules[moduleName]
end

local function Refresh()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

function SarychUI.modules.modern_features:GetQuestTrackerOptions()
    return {
						type = "group",
						name = "ui.quest_tracker_caa65768",
						order = 1.5,
						inline = true,
						args = {
							questTrackerStyle = {
								type = "select",
								name = "ui.appearance_c407960b",
								desc = "ui.classic_standard_wotlk_watchframe_dragonflight_h_cd268693",
								order = 1,
								width = "full",
								values = {
									classic = SarychUI:T("ui.options_cfdb8b654b"),
									dragonflight = "Dragonflight",
								},
								get = function()
									local db = DB()
									return (db and db.questTrackerStyle == "dragonflight") and "dragonflight" or "classic"
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									local nextStyle = (value == "dragonflight") and "dragonflight" or "classic"
									if db.questTrackerStyle == nextStyle then return end
									db.questTrackerStyle = nextStyle
									if module and SarychUI.modules.modern_features.ApplyQuestTrackerStyle then
										SarychUI.modules.modern_features:ApplyQuestTrackerStyle()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Apply then
										_G.SarychUI_QuestTracker.Apply()
									end
									Refresh()
								end,
							},
							questTrackerShowHeader = {
								type = "toggle",
								name = "ui.show_header_background_7dd547e5",
								desc = "ui.decorative_tracker_header_texture_dragonflight_o_edd5913b",
								order = 2,
								width = "full",
								hidden = function()
									local db = DB()
									return not db or db.questTrackerStyle ~= "dragonflight"
								end,
								get = function()
									local db = DB()
									return not db or db.questTrackerShowHeader ~= false
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.questTrackerShowHeader = val and true or false
									if module and SarychUI.modules.modern_features.RefreshQuestTracker then
										SarychUI.modules.modern_features:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
								end,
							},
							questTrackerDragonflightPosition = {
								type = "toggle",
								name = "ui.dragonflight_style_placement_ec9f03e3",
								desc = "ui.moves_the_tracker_from_the_default_wow_position__9045109d",
								order = 3,
								width = "full",
								hidden = function()
									local db = DB()
									return not db or db.questTrackerStyle ~= "dragonflight"
								end,
								get = function()
									local db = DB()
									return not db or db.questTrackerDragonflightPosition ~= false
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.questTrackerDragonflightPosition = val and true or false
									if not val then
										db.questTrackerShowDragFrame = 0
										db.questTrackerShowGrid = 0
										local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
										if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "questTracker" then
											panel:Close(false)
										end
									end
									if module and SarychUI.modules.modern_features.RefreshQuestTracker then
										SarychUI.modules.modern_features:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
									Refresh()
								end,
							},
							questTrackerX = {
								type = "range",
								name = "ui.x_offset_0b923c73",
								desc = "ui.horizontal_offset_relative_to_the_dragonflight_l_c3c32fd5",
								order = 4,
								min = -600,
								max = 0,
								step = 1,
								suiLiveApply = true,
								hidden = function()
									local db = DB()
									return not db or db.questTrackerStyle ~= "dragonflight" or db.questTrackerDragonflightPosition == false
								end,
								get = function()
									local db = DB()
									return (db and db.questTrackerX) or 0
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									if db.questTrackerX == val then return end
									db.questTrackerX = val
									if module and SarychUI.modules.modern_features.RefreshQuestTracker then
										SarychUI.modules.modern_features:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
								end,
							},
							questTrackerY = {
								type = "range",
								name = "ui.y_offset_f7f3fdd7",
								desc = "ui.vertical_offset_relative_to_the_dragonflight_lay_06910402",
								order = 5,
								min = -600,
								max = 0,
								step = 1,
								suiLiveApply = true,
								hidden = function()
									local db = DB()
									return not db or db.questTrackerStyle ~= "dragonflight" or db.questTrackerDragonflightPosition == false
								end,
								get = function()
									local db = DB()
									return (db and db.questTrackerY) or -260
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									if db.questTrackerY == val then return end
									db.questTrackerY = val
									if module and SarychUI.modules.modern_features.RefreshQuestTracker then
										SarychUI.modules.modern_features:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
								end,
							},
							questTrackerDrag = {
								type = "execute",
								name = function()
									local db = DB()
									if db and db.questTrackerShowDragFrame == 1 then
										return SarychUI:T("ui.options_76e4992833")
									end
									return SarychUI:T("ui.options_0510004a87")
								end,
								desc = "ui.show_a_frame_and_drag_handle_for_the_tracker_lik_7d1458af",
								order = 6,
								width = "full",
								suiFullRow = true,
								hidden = function()
									local db = DB()
									return not db or db.questTrackerStyle ~= "dragonflight" or db.questTrackerDragonflightPosition == false
								end,
								func = function()
									local db = DB(); if not db then return end
									local val = not (db.questTrackerShowDragFrame == 1)
									db.questTrackerShowDragFrame = val and 1 or 0
									db.questTrackerShowGrid = val and 1 or 0
									if module and SarychUI.modules.modern_features.ApplyQuestTrackerDragMode then
										SarychUI.modules.modern_features:ApplyQuestTrackerDragMode()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.ApplyDragMode then
										_G.SarychUI_QuestTracker.ApplyDragMode()
									end
									local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
									if panel and panel.Toggle then
										panel:Toggle("questTracker", val)
									end
									if module and SarychUI.modules.modern_features.RefreshQuestTracker then
										SarychUI.modules.modern_features:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
									Refresh()
								end,
								suiResetDefaults = function()
									local db = DB(); if not db then return end
									local def = SarychUI.defaults and SarychUI.defaults.profile.modules.tools
									local x = (def and def.questTrackerX) or 0
									local y = (def and def.questTrackerY) or -260
									db.questTrackerX = x
									db.questTrackerY = y
									local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
									if not (panel and panel.SyncDraftIfOpen and panel:SyncDraftIfOpen("questTracker", x, y)) then
										if module and SarychUI.modules.modern_features.RefreshQuestTracker then
											SarychUI.modules.modern_features:RefreshQuestTracker()
										elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
											_G.SarychUI_QuestTracker.Refresh()
										end
									end
									Refresh()
								end,
							},
							questTrackerFontSize = {
								type = "range",
								name = "ui.font_size_9f9d637d",
								desc = "ui.quest_tracker_text_size_dragonflight_only_defaul_5d6251be",
								order = 7,
								min = 8,
								max = 18,
								step = 1,
								suiLiveApply = true,
								hidden = function()
									local db = DB()
									return not db or db.questTrackerStyle ~= "dragonflight"
								end,
								get = function()
									local db = DB()
									return (db and db.questTrackerFontSize) or 11
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									if db.questTrackerFontSize == val then return end
									db.questTrackerFontSize = val
									if module and SarychUI.modules.modern_features.RefreshQuestTracker then
										SarychUI.modules.modern_features:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
								end,
							},
						},
					}
end
