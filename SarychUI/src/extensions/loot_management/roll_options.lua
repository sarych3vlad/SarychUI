-- Options owned by the component; shared rendering lives in src/options.
local moduleName = "tools"

local L = SarychUI.L

local module = SarychUI.modules.loot_management

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

function SarychUI.modules.loot_management:GetLootOptions()
    return {
						type = "group",
						name = "ui.loot_903cc320",
						order = 4,
						inline = true,
						args = {
							enableLootReanchor = {
								type = "toggle",
								name = "ui.rebind_loot_windows_fa91bfa9",
								desc = "ui.if_you_close_the_bottom_loot_roll_window_the_oth_68ed5d00",
								order = 1,
								width = "full",
								suiHelpIcon = true,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableLootReanchor = val and 1 or 0
									if module and SarychUI.modules.loot_management.ApplyLootReanchor then
										SarychUI.modules.loot_management:ApplyLootReanchor()
									end
									Refresh()
								end,
							},
							enableLootRollCounts = {
								type = "toggle",
								name = "ui.show_counters_on_loot_roll_icons_ee0c0f95",
								desc = "ui.default_loot_roll_buttons_show_how_many_players__24676001",
								order = 2,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableLootRollCounts = val and 1 or 0
									if module and SarychUI.modules.loot_management.ApplyLootRollCounts then
										SarychUI.modules.loot_management:ApplyLootRollCounts()
									end
									Refresh()
								end,
							},
							lootRollPreview = {
								type = "description",
								name = " ",
								order = 2.5,
								width = "full",
								suiPreview = "LootRollPreview",
								hidden = function() return not isOn("enableLootRollCounts") end,
							},
							lootRollCountFont = {
								type = "select",
								style = "dropdown",
								name = "ui.font_23997845",
								order = 3,
								values = function()
									local values = {}
									if SarychUI and SarychUI.Media and SarychUI.Media.GetFonts then
										for _, name in ipairs(SarychUI.Media.GetFonts()) do
											values[name] = name
										end
									end
									if not next(values) then
										values["Friz Quadrata TT"] = "Friz Quadrata TT"
									end
									return values
								end,
								hidden = function() return not isOn("enableLootRollCounts") end,
								get = function()
									local db = DB()
									return (db and db.lootRollCountFont) or "Friz Quadrata TT"
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									db.lootRollCountFont = value
									if SarychUI.LootRollPreview then
										SarychUI.LootRollPreview:SetLiveValue("font", value)
									end
									if _G.SarychUI_LootRollCounts then
										_G.SarychUI_LootRollCounts.ApplyStyleAll()
									end
								end,
							},
							lootRollCountFontOutline = {
								type = "select",
								style = "dropdown",
								name = "ui.border_6eeed8a0",
								order = 4,
								values = function()
									if SarychUI_FontOutlineValues and SarychUI_FontOutlineValues.GetSelectValues then
										return SarychUI_FontOutlineValues.GetSelectValues(L)
									end
									if AutolosFontFlags and AutolosFontFlags.GetValues then
										return AutolosFontFlags.GetValues(L)
									end
									return {
										NONE = SarychUI:T("ui.options_eea53a085d"),
										OUTLINE = "OUTLINE",
										MONOCHROME = "MONOCHROME",
										MONOCHROMEOUTLINE = "MONOCHROME OUTLINE",
										THICKOUTLINE = "THICK OUTLINE",
									}
								end,
								hidden = function() return not isOn("enableLootRollCounts") end,
								get = function()
									local db = DB()
									return (db and db.lootRollCountFontOutline) or "OUTLINE"
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									db.lootRollCountFontOutline = value
									if SarychUI.LootRollPreview then
										SarychUI.LootRollPreview:SetLiveValue("fontOutline", value)
									end
									if _G.SarychUI_LootRollCounts then
										_G.SarychUI_LootRollCounts.ApplyStyleAll()
									end
								end,
							},
							lootRollCountFontSize = {
								type = "range",
								name = "ui.size_572095d4",
								order = 5,
								min = 8, max = 24, step = 1,
								suiPreviewKey = "fontSize",
								hidden = function() return not isOn("enableLootRollCounts") end,
								get = function()
									local db = DB()
									return (db and db.lootRollCountFontSize) or 12
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									db.lootRollCountFontSize = value
									if _G.SarychUI_LootRollCounts then
										_G.SarychUI_LootRollCounts.ApplyStyleAll()
									end
								end,
							},
						},
					}
end
