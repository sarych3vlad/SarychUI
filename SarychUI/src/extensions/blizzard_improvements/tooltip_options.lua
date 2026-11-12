-- Options owned by the component; shared rendering lives in src/options.
local moduleName = "tools"

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

function SarychUI.modules.blizzard_improvements:GetTooltipCursorOptions()
 return {
tooltipCursorBox = {
						type = "group",
						name = "ui.tooltip.settings",
						desc = "ui.tooltip.settings_desc",
						order = 3,
						inline = true,
						args = {
							enableTooltipCursor = {
								type = "toggle",
								name = "Enable",
								suiFullRow = true,
								desc = "ui.tooltip.settings_desc",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableTooltipCursor = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyTooltipCursor then
										SarychUI.modules.blizzard_improvements:ApplyTooltipCursor()
									end
									Refresh()
								end,
							},
                            tooltipMode = {
                                type = "select", name = "ui.tooltip.mode", order = 2, width = "full",
                                suiFullRow = true,
                                values = { cursor = "ui.enable_tooltip_at_cursor_02992a7b", hidden = "ui.tooltip.hidden" },
                                get = function() local db = DB(); return db and db.tooltipMode or "cursor" end,
                                set = function(_, value)
                                    local db = DB(); if not db then return end
                                    db.tooltipMode = value
                                    module:ApplyTooltipCursor()
                                    Refresh()
                                end,
                                hidden = function() return not isOn("enableTooltipCursor") end,
                            },
							tooltipCursorAltOnly = {
								type = "toggle",
								name = "ui.only_while_holding_cffffd700alt_r_51e31293",
								desc = "ui.tooltip_at_cursor_only_works_while_holding_cffff_d0f0df5b",
								order = 3,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.tooltipCursorAltOnly = val and 1 or 0
									if module and SarychUI.modules.blizzard_improvements.ApplyTooltipCursor then
										SarychUI.modules.blizzard_improvements:ApplyTooltipCursor()
									end
									Refresh()
								end,
								hidden = function()
                                    local db = DB()
                                    return not isOn("enableTooltipCursor") or (db and db.tooltipMode == "hidden")
                                end,
							},
						},
					},
 }
end
