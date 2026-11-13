-- SarychUI Arena Module Options

local moduleName = "arena"
local L = SarychUI.L
local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)

-- Get module
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local function RefreshArenaOptions()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif ACR then
		ACR:NotifyChange("SarychUI")
	end
end

local function NotifyArenaPreview(key, value, clear)
	local preview = SarychUI and SarychUI.ArenaPreview
	if type(key) == "string" and (key:find("^arenaNumbers") or key == "hideGroupRaidText") then
		preview = SarychUI and SarychUI.ArenaNumbersPreview
	end
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

local function GetDB()
	local root = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return root and root[moduleName]
end

local function DRExtensionEnabled()
	local extension = SarychUI.extensions and SarychUI.extensions.diminishings
	return extension and extension:IsArenaEnabled() or false
end

local function LeftContentValues()
	local values = { none = SarychUI:T("ui.options_ad938f88fe"), procTrinkets = SarychUI:T("ui.options_8811f150aa") }
	values.__order = { "none", "procTrinkets" }
	if DRExtensionEnabled() then
		values.diminishings = SarychUI:T("ui.text_8cb12044")
		values.__order = { "none", "diminishings", "procTrinkets" }
	end
	return values
end

local function RightContentValues()
	local values = { none = SarychUI:T("ui.options_ad938f88fe"), enemyAbilities = SarychUI:T("ui.text_b0df4811"),
		procTrinkets = SarychUI:T("ui.options_8811f150aa") }
	values.__order = { "none", "enemyAbilities", "procTrinkets" }
	if DRExtensionEnabled() then
		values.diminishings = SarychUI:T("ui.text_8cb12044")
		values.__order = { "none", "enemyAbilities", "procTrinkets", "diminishings" }
	end
    local tracker = SarychUI.extensions and SarychUI.extensions.party_abilities
    if tracker and tracker.IsArenaDisplayEnabled and not tracker:IsArenaDisplayEnabled() then
        values.enemyAbilities = nil
        for index = #values.__order, 1, -1 do
            if values.__order[index] == "enemyAbilities" then table.remove(values.__order, index) end
        end
    end
	return values
end

local function ProcTrinketsSelected()
	local db = GetDB()
	if not db then return false end
	if db.frameType == "gladius" then
		return module:GetGladiusPrimaryContent() == "procTrinkets"
			or module:GetGladiusLeftContent() == "procTrinkets"
			or module:GetGladiusRightContent() == "procTrinkets"
	end
	return module:GetClassicPrimaryContent() == "procTrinkets"
		or module:GetClassicLeftContent() == "procTrinkets"
		or module:GetClassicRightContent() == "procTrinkets"
end

local function EnemyAbilitiesSelected()
	local db = GetDB()
	if not db then return false end
	if db.frameType == "gladius" then
		return module:GetGladiusRightContent() == "enemyAbilities"
	end
	return module:GetClassicRightContent() == "enemyAbilities"
end

local function GetToolsDB()
	local root = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return root and root.tools
end

local function StyleSettings()
	return module:GetStyleSettings()
end

local function SetDRDisplay(value)
	local db = GetDB()
	if not db then return end
	for _, kind in ipairs({ "classic", "gladius" }) do
		local style = module:GetStyleSettings(kind)
		if style.diminishingDisplay == nil then
			style.diminishingDisplay = db.diminishingDisplay == "show" and "show" or "none"
		end
	end
	StyleSettings().diminishingDisplay = value
	db.diminishingDisplay = value
end

local function EnemySettings()
	return module:GetEnemyAbilitySettings()
end

local function DRSettings()
	return module:GetDRSettings()
end

local function SetEnemySide(side)
	local settings = EnemySettings()
	if not settings or not settings.layout then return end
	settings.layout.side = side
	settings.layout.growth = side
	local offset = math.abs(tonumber(settings.layout.autoX) or 7)
	settings.layout.autoX = side == "LEFT" and -offset or offset
	settings.layout._signedAutoX = true
end

local function EnemySide()
	local settings = EnemySettings()
	return settings and settings.layout and settings.layout.side == "LEFT" and "LEFT" or "RIGHT"
end

local function DRSide()
	local cfg = DRSettings()
	return cfg and cfg.side == "RIGHT" and "RIGHT" or "LEFT"
end

local function SetDRSide(side)
	local cfg = DRSettings()
	if not cfg then return end
	local db = GetDB()
	if db and db.frameType == "classic" then
		cfg.sideOffsets = cfg.sideOffsets or {}
		local previous = cfg.side == "RIGHT" and "RIGHT" or "LEFT"
		if previous ~= side then
			cfg.sideOffsets[previous] = { x = cfg.x, y = cfg.y }
			local saved = cfg.sideOffsets[side]
			cfg.x = saved and saved.x or (side == "RIGHT" and 2 or -2)
			cfg.y = saved and saved.y or 0
		end
	end
	cfg.side, cfg.growth = side, side
	local offset = math.abs(tonumber(cfg.x) or 2)
	if side == "RIGHT" and offset == 0 then offset = 2 end
	cfg.x = side == "LEFT" and -offset or offset
end

local function RefreshDR()
	if module.Diminishings and module.Diminishings.ResetPreview then
		module.Diminishings:ResetPreview()
	end
	if module.Diminishings then module.Diminishings:Refresh() end
	RefreshArenaOptions()
end

local RefreshEnemyAbilities

local function DRRange(key, name, minimum, maximum, step, order, default)
	return {
		type = "range", name = name, order = order, width = "full",
		min = minimum, max = maximum, step = step,
		get = function()
			local cfg = DRSettings()
			if key == "size" then
				local settings = module:GetEnemyAbilitySettings("classic")
				return settings and tonumber(settings.layout.size) or default
			end
			return cfg and tonumber(cfg[key]) or default
		end,
		set = function(_, value)
			local cfg = DRSettings(); if not cfg then return end
			cfg[key] = value
			if key == "size" then
				local settings = module:GetEnemyAbilitySettings("classic")
				if settings then settings.layout.size = value end
				RefreshEnemyAbilities()
				NotifyArenaPreview()
			end
			RefreshDR()
		end,
	}
end

RefreshEnemyAbilities = function()
	local extension = SarychUI.extensions and SarychUI.extensions.party_abilities
	if extension and extension.RefreshConfig then extension:RefreshConfig() end
	local preview = SarychUI.PartyAbilitiesPreview
	if preview and preview.RefreshAll then preview:RefreshAll() end
end

local function EnemyRange(key, label, minimum, maximum, order)
	local defaults = { x = 2, y = 6, autoX = 7, autoY = 0, size = 24, spacing = 5, perRow = 5 }
	return {
		type = "range", name = function() return L[label] end,
		min = minimum, max = maximum, step = 1, order = order,
		get = function()
			local settings = EnemySettings()
			local actual = (key == "x" or key == "y") and (key == "x" and "autoX" or "autoY") or key
			return settings and tonumber(settings.layout[actual]) or defaults[actual]
		end,
		set = function(_, value)
			local settings = EnemySettings()
			if not settings then return end
			local actual = (key == "x" or key == "y") and (key == "x" and "autoX" or "autoY") or key
			settings.layout[actual] = value
			if key == "size" then
				local db = GetDB()
				if db and db.frameType == "classic" then
					local cfg = DRSettings()
					if cfg then cfg.size = value end
					RefreshDR()
					NotifyArenaPreview()
				end
			end
			RefreshEnemyAbilities()
		end,
	}
end

-- Options table
function module:GetOptions()
    local options = {
		type = "group",
		name = "ui.arena_cada76b8",
		desc = "ui.arena_frame_settings_aca20932",
		childGroups = "tab",
		args = {
			-- General tab - same layout pattern as Bags -> Общее
			general = {
				type = "group",
				name = L and (L["General"] or SarychUI:T("ui.general_b250a3d6")) or SarychUI:T("ui.general_b250a3d6"),
				order = 1,
				args = {
					enabled = {
						suiModuleEnable = true,
						type = "toggle",
						name = L and (L["Enable_Module"] or SarychUI:T("ui.enable_module_b623b573")) or SarychUI:T("ui.enable_module_b623b573"),
						desc = "ui.enable_or_disable_the_module_ce99024f",
						order = 1,
						width = "full",
						get = function()
							local db = GetDB()
							return db and db.enabled or false
						end,
						set = function(_, value)
							local db = GetDB()
							if db then
								module:SetEnabled(value)
							end
						end,
					},
					frameAppearance = {
						type = "group",
						name = "ui.text_72c0780f",
						order = 3,
						inline = true,
						hidden = function()
							local db = GetDB()
							return not (db and db.enabled)
						end,
						args = {
							frameType = {
								type = "select",
								name = "ui.appearance_c407960b",
								order = 1,
								values = { classic = SarychUI:T("ui.options_03ced8ccad"), gladius = "Gladius" },
								get = function()
									local db = GetDB()
									return db and db.frameType or "classic"
								end,
								set = function(_, value)
									local db = GetDB()
									if not db or (value ~= "classic" and value ~= "gladius") then return end
									if db.frameType == value then return end
									module:GetStyleSettings(value)
									module:GetEnemyAbilitySettings(value)
									module:GetDRSettings(value)
									local previous = db.frameType or "classic"
									db.frameType = value
									RefreshArenaOptions()
									SarychUI:ShowReloadPopup(SarychUI:T("ui.options_486b12a88c"), function()
										db.frameType = previous
										RefreshArenaOptions()
									end)
								end,
							},
						},
					},
					positionTestBox = {
						type = "group",
						name = "ui.layout_and_testing_f141a003",
						order = 3.5,
						inline = true,
						suiFitButtonRow = 5,
						hidden = function()
							local db = GetDB()
							return not (db and db.enabled)
						end,
						args = {
							test2 = {
								type = "execute",
								order = 1,
								suiFitText = true,
								name = function()
									local db = GetDB()
									return db and db.testMode == 2 and SarychUI:T("ui.options_f191b65fd4") or "2"
								end,
								func = function()
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if db.testMode == 2 then
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									else
										local oldMode = db.testMode or 0
										db.testMode = 2
										if not (m.Test and m:Test(2)) then db.testMode = oldMode end
									end
									RefreshArenaOptions()
								end,
							},
							test3 = {
								type = "execute",
								order = 2,
								suiFitText = true,
								name = function()
									local db = GetDB()
									return db and db.testMode == 3 and SarychUI:T("ui.options_c6ef888107") or "3"
								end,
								func = function()
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if db.testMode == 3 then
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									else
										local oldMode = db.testMode or 0
										db.testMode = 3
										if not (m.Test and m:Test(3)) then db.testMode = oldMode end
									end
									RefreshArenaOptions()
								end,
							},
							test5 = {
								type = "execute",
								order = 3,
								suiFitText = true,
								name = function()
									local db = GetDB()
									return db and db.testMode == 5 and SarychUI:T("ui.options_4f987accd8") or "5"
								end,
								func = function()
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if db.testMode == 5 then
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									else
										local oldMode = db.testMode or 0
										db.testMode = 5
										if not (m.Test and m:Test(5)) then db.testMode = oldMode end
									end
									RefreshArenaOptions()
								end,
							},
							freeMove = {
								type = "execute",
								name = function()
									local db = GetDB() or {}
									if db.showDragFrame == 1 then
										return SarychUI:T("ui.options_76e4992833")
									end
									return SarychUI:T("ui.options_0510004a87")
								end,
								desc = "ui.show_a_green_frame_to_drag_the_arena_container_340acd5f",
								order = 4,
								suiFitText = true,
								func = function()
									local db = GetDB()
									if not db then return end
									local val = not (db.showDragFrame == 1)
									db.showDragFrame = val and 1 or 0
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									local panel = SarychUI.PositionDragPanel
									if panel and panel.Toggle then panel:Toggle("arenaContainer", val) end
									RefreshArenaOptions()
								end,
							},
							resetDefaults = {
								type = "execute",
								name = "ui.options_469631cb16",
								order = 5,
								suiFitText = true,
								func = function()
									local db = GetDB(); if not db then return end
									local style = StyleSettings(); if not style then return end
									local def = SarychUI.defaults and SarychUI.defaults.profile.modules.arena
									style.arenaX = (def and def.arenaX) or -311
									style.arenaY = (def and def.arenaY) or 131
									style.arenaA = (def and def.arenaA) or "RIGHT"
									style.arenaR = (def and def.arenaR) or "RIGHT"
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									local panel = SarychUI.PositionDragPanel
									if panel and panel.SyncDraftIfOpen then
										panel:SyncDraftIfOpen("arenaContainer", style.arenaX, style.arenaY, style.arenaA, style.arenaR)
									end
									RefreshArenaOptions()
								end,
							},
						},
					},
				},
			},
			
			-- Arena settings
			appearance = {
				type = "group",
				name = "ui.settings_985b5e0f",
				order = 2,
				suiArenaSettingsSplit = true,
				disabled = function()
					local db = GetDB()
					return not (db and db.enabled)
				end,
				args = {
					arenaPreview = {
						type = "description",
						name = "",
						order = 0,
						width = "full",
						suiPreview = "ArenaPreview",
					},
					procTrinketsBlock = {
						type = "group",
						name = "",
						order = 0.8,
						inline = true,
						hidden = function()
							local db = GetDB()
							return not ProcTrinketsSelected()
						end,
						args = {
							procTrinkets = {
								type = "toggle", name = "ui.text_156d0d90",
								order = 1, width = "full",
								hidden = function()
									local db = GetDB()
									return true
								end,
								get = function()
									local db = GetDB()
									return db and db.procTrinkets and db.procTrinkets.enabled == true
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.procTrinkets = db.procTrinkets or {}
									db.procTrinkets.enabled = value and true or false
									if module.ProcTrinkets then module.ProcTrinkets:Refresh() end
									NotifyArenaPreview()
									RefreshArenaOptions()
								end,
							},
							procTrinketLayout = {
								type = "select", name = "ui.text_f9374155",
								order = 2, width = "full",
								values = { ROW = SarychUI:T("ui.options_71d6dac6f6"), COLUMN = SarychUI:T("ui.options_388892be39"), __order = { "ROW", "COLUMN" } },
								hidden = function()
									local db = GetDB()
									return not db or db.frameType ~= "classic" or not ProcTrinketsSelected()
								end,
								get = function()
									local db = GetDB()
									return db and db.procTrinkets and db.procTrinkets.layout or "ROW"
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.procTrinkets = db.procTrinkets or {}
									db.procTrinkets.layout = value == "COLUMN" and "COLUMN" or "ROW"
									module:ApplyFrameSpacing()
									if module.ProcTrinkets then module.ProcTrinkets:Refresh() end
									RefreshEnemyAbilities()
									RefreshDR()
									NotifyArenaPreview()
								end,
							},
							procTrinketDesaturate = {
								type = "toggle", name = "ui.text_3fda5970",
								order = 4, width = "full",
								hidden = function()
									return not ProcTrinketsSelected()
								end,
								get = function()
									local db = GetDB()
									return db and db.procTrinkets and db.procTrinkets.desaturateOnCooldown == true
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.procTrinkets = db.procTrinkets or {}
									db.procTrinkets.desaturateOnCooldown = value and true or false
									if module.ProcTrinkets then module.ProcTrinkets:Refresh() end
									NotifyArenaPreview()
								end,
							},
							procTrinketIcon = {
								type = "select", name = "ui.text_00fc77cd",
								order = 3, width = "full",
								values = { PROC = SarychUI:T("ui.options_9ef8b7f5c9"), ITEM = SarychUI:T("ui.options_7a95f3e4b5"),
									__order = { "PROC", "ITEM" } },
								hidden = function()
									return not ProcTrinketsSelected()
								end,
								get = function()
									local db = GetDB()
									return db and db.procTrinkets and db.procTrinkets.procIconMode or "PROC"
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.procTrinkets = db.procTrinkets or {}
									db.procTrinkets.procIconMode = value == "ITEM" and "ITEM" or "PROC"
									if module.ProcTrinkets then module.ProcTrinkets:Refresh() end
									NotifyArenaPreview()
								end,
							},
						},
					},
					appearanceToggles = {
						type = "group",
						name = "",
						order = 0.9,
						inline = true,
						args = {
							combatIndicator = {
								type = "toggle", name = "ui.combat_indicator_302a8b8d",
								order = 1, width = "full",
								get = function()
									local db = GetDB()
									return db and db.showCombatIndicator == true
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.showCombatIndicator = value and true or false
									module:UpdateArenaCombatIndicators()
									NotifyArenaPreview()
								end,
							},

							classicSpec = {
								type = "toggle", name = "ui.text_be9ed157",
								order = 2, width = "full",
								hidden = function() local db = GetDB(); return not db or db.frameType ~= "classic" end,
								get = function()
									local style = module:GetStyleSettings("classic")
									return style and style.showSpecText == true
								end,
								set = function(_, value)
									local style = module:GetStyleSettings("classic"); if not style then return end
									style.showSpecText = value and true or false
									module:UpdateClassicSpecVisuals()
									NotifyArenaPreview()
								end,
							},
							rangeCheckEnabled = {
								type = "toggle",
								name = "ui.text_8d859025",
								desc = "ui.text_1bd5830a",
								order = 3, width = "full",
								get = function()
									local db = GetDB()
									return not db or db.rangeCheckEnabled ~= false
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.rangeCheckEnabled = value and true or false
									if module.ApplySettings then module:ApplySettings() end
									if SarychUI.UnitFrameRange then SarychUI.UnitFrameRange:Refresh() end
									NotifyArenaPreview("rangeCheckEnabled", db.rangeCheckEnabled)
								end,
							},
						},
					},
					displayBox = {
						type = "group",
						name = "ui.display_205c4b9e",
						order = 1,
						inline = true,
						args = {
							showDarkBackground = {
								type = "toggle", name = "ui.arena.dark_background", order = 0.1, width = "full",
								hidden = function() local db = GetDB(); return not db or db.frameType ~= "gladius" end,
								get = function() return module:GetStyleSettings("gladius").showDarkBackground ~= false end,
								set = function(_, value)
									module:GetStyleSettings("gladius").showDarkBackground = value and true or false
									module:UpdateGladiusVisuals()
									NotifyArenaPreview()
								end,
							},
							showCastShield = {
								type = "toggle", name = "ui.arena.protected_cast_texture", order = 0.2, width = "full",
								get = function() return module:GetStyleSettings().showCastShield ~= false end,
								set = function(_, value)
									module:GetStyleSettings().showCastShield = value and true or false
									module:UpdateGladiusVisuals()
									module:UpdateClassicCastShields()
									NotifyArenaPreview()
									RefreshArenaOptions()
								end,
							},
							protectedCastEffects = {
								type = "group", name = "", order = 0.3, inline = true,
								hidden = function()
									local db = GetDB()
									return not db or db.frameType ~= "gladius"
										or module:GetStyleSettings("gladius").showCastShield == false
								end,
								args = {
									showCastShieldIcon = {
										type = "toggle", name = "ui.arena.protected_cast_icon_shield", order = 1, width = "full",
										get = function() return module:GetStyleSettings("gladius").showCastShieldIcon ~= false end,
										set = function(_, value)
											module:GetStyleSettings("gladius").showCastShieldIcon = value and true or false
											module:UpdateGladiusVisuals()
											NotifyArenaPreview()
										end,
									},
									colorProtectedCast = {
										type = "toggle", name = "ui.arena.protected_cast_silver_bar", order = 2, width = "full",
										get = function() return module:GetStyleSettings("gladius").colorProtectedCast ~= false end,
										set = function(_, value)
											module:GetStyleSettings("gladius").colorProtectedCast = value and true or false
											module:UpdateGladiusVisuals()
											NotifyArenaPreview()
										end,
									},
								},
							},
							scale = {
								type = "range",
								name = "ui.frame_scale_6bfd4954",
								desc = "ui.changes_the_scale_of_enemy_arena_frames_deae5396",
								order = 1,
								min = 0.5,
								max = 2.0,
								step = 0.01,
								isPercent = false,
								width = "full",
								get = function()
									local style = StyleSettings()
									return style and (style.scale or 1.0) or 1.0
								end,
								set = function(_, value)
									local m = SarychUI.modules[moduleName]
									if m and m.SetScale then
										m:SetScale(value)
									end
									NotifyArenaPreview("scale", value)
								end,
							},
							classicFontSize = {
							type = "range", name = "ui.arena_classic_font_size",
							order = 1.25, min = 6, max = 20, step = 1, width = "full",
							hidden = function() local db = GetDB(); return not db or db.frameType ~= "classic" end,
							get = function() return module:GetStyleSettings("classic").fontSize or 10 end,
							set = function(_, value)
							module:GetStyleSettings("classic").fontSize = value
							module:UpdateClassicFontSize()
							NotifyArenaPreview()
							end,
							},
							frameSpacing = {
								type = "range",
								name = "ui.text_227a2839",
								desc = "ui.text_a93804a3",
								order = 1.5,
								min = 0, max = 60, step = 1,
								width = "full",
								suiPreviewKey = "frameSpacing",
								get = function()
									local style = StyleSettings()
									return style and (style.frameSpacing or 40) or 40
								end,
								set = function(_, value)
									local style = StyleSettings(); if not style then return end
									style.frameSpacing = value
									if module.ApplyFrameSpacing then module:ApplyFrameSpacing() end
									NotifyArenaPreview("frameSpacing", value)
								end,
							},
							barWidth = {
								type = "range", name = "ui.text_51274595",
								order = 1.6, min = 80, max = 300, step = 1, width = "full",
								hidden = function() local db = GetDB(); return not db or db.frameType ~= "gladius" end,
								suiPreviewKey = "barWidth",
								get = function() local style = StyleSettings(); return style and style.barWidth or 165 end,
								set = function(_, value)
									local style = StyleSettings(); if not style then return end
									style.barWidth = value
									if module.ApplySettings then module:ApplySettings() end
									NotifyArenaPreview("barWidth", value)
								end,
							},
							castBarHeight = {
								type = "range", name = "ui.text_db155dc0",
								order = 1.7, min = 12, max = 30, step = 1, width = "full",
								hidden = function()
									local db, style = GetDB(), StyleSettings()
									return not db or db.frameType ~= "gladius" or (style and style.castBarPos == "LEFT")
								end,
								suiPreviewKey = "castBarHeight",
								get = function() local style = StyleSettings(); return style and style.castBarHeight or 18 end,
								set = function(_, value)
									local style = StyleSettings(); if not style then return end
									style.castBarHeight = value
									if module.ApplySettings then module:ApplySettings() end
									NotifyArenaPreview("castBarHeight", value)
								end,
							},
							castBarHeightLeft = {
								type = "range", name = "ui.text_db155dc0",
								order = 1.7, min = 12, max = 40, step = 1, width = "full",
								hidden = function()
									local db, style = GetDB(), StyleSettings()
									return not db or db.frameType ~= "gladius" or not style or style.castBarPos ~= "LEFT"
								end,
								suiPreviewKey = "castBarHeight",
								get = function() local style = StyleSettings(); return style and style.castBarHeight or 18 end,
								set = function(_, value)
									local style = StyleSettings(); if not style then return end
									style.castBarHeight = value
									if module.ApplySettings then module:ApplySettings() end
									NotifyArenaPreview("castBarHeight", value)
								end,
							},
							castBarPos = {
								type = "select", name = "ui.text_a7a1a357",
								order = 1.75, width = "full",
								values = { CENTER = SarychUI:T("ui.options_957dfa1dec"), LEFT = SarychUI:T("ui.options_4af2530fc3") },
								hidden = function() local db = GetDB(); return not db or db.frameType ~= "gladius" end,
								suiPreviewKey = "castBarPos",
								get = function() local style = StyleSettings(); return style and style.castBarPos or "CENTER" end,
								set = function(_, value)
									local style = StyleSettings(); if not style then return end
									style.castBarPos = value == "LEFT" and "LEFT" or "CENTER"
									if style.castBarPos == "CENTER" then
										style.castBarHeight = math.min(30, tonumber(style.castBarHeight) or 18)
									end
									if module.ApplySettings then module:ApplySettings() end
									NotifyArenaPreview("castBarPos", style.castBarPos)
									NotifyArenaPreview("castBarHeight", style.castBarHeight)
									RefreshArenaOptions()
								end,
							},
							diminishingDisplay = {
								type = "select", name = "ui.text_71cc30ee",
								order = 1.76, width = "full",
								disabled = function()
									local db = GetDB()
									local style = db and StyleSettings()
									return style and style.castBarPos == "LEFT"
								end,
								values = LeftContentValues,
								get = function()
									local db = GetDB()
									if db and db.frameType == "gladius" then
										return module:GetGladiusLeftContent(true)
									end
									return module:GetClassicLeftContent()
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									local wasLeftDR = module:IsDRShown() and DRSide() == "LEFT"
									local style = StyleSettings()
									local wasRightProc = db.frameType == "gladius"
										and module:GetGladiusRightContent() == "procTrinkets"
										or db.frameType == "classic" and module:GetClassicRightContent() == "procTrinkets"
									style.leftContent = value == "procTrinkets" and "procTrinkets" or "none"
									if value == "procTrinkets" then
										if style.rightPrimary == "procTrinkets" then style.rightPrimary = "none" end
										if wasRightProc then style.rightContent = "none" end
									end
									if value == "diminishings" and DRExtensionEnabled() then
										local wasRight = module:IsDRShown() and DRSide() == "RIGHT"
										SetDRDisplay("show")
										SetDRSide("LEFT")
										if wasRight then StyleSettings().rightContent = "none" end
									elseif wasLeftDR then
										SetDRDisplay("none")
									end
									RefreshDR()
									RefreshEnemyAbilities()
									module:ApplyFrameSpacing()
									if module.ProcTrinkets then module.ProcTrinkets:Refresh() end
									NotifyArenaPreview()
									RefreshArenaOptions()
								end,
							},
							rightPrimary = {
								type = "select", name = "ui.1_fa8032e1",
								order = 1.765, width = "full",
								values = { none = SarychUI:T("ui.options_ad938f88fe"), racial = SarychUI:T("ui.text_c08220b0"),
									procTrinkets = SarychUI:T("ui.options_8811f150aa"),
									__order = { "none", "racial", "procTrinkets" } },
								get = function()
									local db = GetDB()
									return db and db.frameType == "gladius"
										and module:GetGladiusPrimaryContent() or module:GetClassicPrimaryContent()
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									local style = StyleSettings(); if not style then return end
									local wasRightProc = db.frameType == "gladius"
										and module:GetGladiusRightContent() == "procTrinkets"
										or db.frameType == "classic" and module:GetClassicRightContent() == "procTrinkets"
									style.rightPrimary = (value == "racial" or value == "procTrinkets") and value or "none"
									if style.rightPrimary == "procTrinkets" then
										db.procTrinkets = db.procTrinkets or {}
										if style.leftContent == "procTrinkets" then
											style.leftContent = "none"
										end
										if wasRightProc then style.rightContent = "none" end
									end
									if module.Trinkets then module.Trinkets:RefreshIcons() end
									if db.testMode and db.testMode > 0 then
										module:ShowTestTrinkets(db.testMode, db.Trinkets)
									end
									if module.ApplySettings then module:ApplySettings() end
									local abilities = SarychUI.extensions and SarychUI.extensions.party_abilities
									if abilities and abilities.RefreshConfig then abilities:RefreshConfig() end
									NotifyArenaPreview()
									RefreshArenaOptions()
								end,
							},
							additionalInfo = {
								type = "select", name = "ui.2_bee6348d",
								order = 1.77, width = "full",
								values = RightContentValues,
								get = function()
									local db = GetDB()
									if db and db.frameType == "gladius" then
										return module:GetGladiusRightContent()
									end
									return module:GetClassicRightContent()
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									local style = StyleSettings()
									local wasRightDR = module:IsDRShown() and DRSide() == "RIGHT"
									style.rightContent = (value == "enemyAbilities" or value == "procTrinkets") and value or "none"
									if value == "diminishings" and DRExtensionEnabled() then
										SetDRDisplay("show")
										SetDRSide("RIGHT")
									elseif wasRightDR then
										SetDRDisplay("none")
									end
									if style.rightContent == "procTrinkets" then
										if style.rightPrimary == "procTrinkets" then style.rightPrimary = "none" end
										if style.leftContent == "procTrinkets" then style.leftContent = "none" end
									end
									if style.rightContent == "enemyAbilities" then SetEnemySide("RIGHT") end
									RefreshEnemyAbilities()
									RefreshDR()
									module:ApplyFrameSpacing()
									if module.ProcTrinkets then module.ProcTrinkets:Refresh() end
									NotifyArenaPreview()
									RefreshArenaOptions()
								end,
							},
							castTextSize = {
								type = "range", name = "ui.text_73237e89",
								order = 1.8, min = 1, max = 20, step = 1, width = "full",
								hidden = function() local db = GetDB(); return not db or db.frameType ~= "gladius" end,
								suiPreviewKey = "castTextSize",
								get = function() local style = StyleSettings(); return style and style.castTextSize or 10 end,
								set = function(_, value)
									local style = StyleSettings(); if not style then return end
									style.castTextSize = value
									if module.ApplySettings then module:ApplySettings() end
									NotifyArenaPreview("castTextSize", value)
								end,
							},
							showSpecText = {
								type = "toggle", name = "ui.text_6b248c95",
								order = 1.9, width = "full",
								hidden = function() local db = GetDB(); return not db or db.frameType ~= "gladius" end,
								suiPreviewKey = "showSpecText",
								get = function() local style = StyleSettings(); return not style or style.showSpecText ~= false end,
								set = function(_, value)
									local style = StyleSettings(); if not style then return end
									style.showSpecText = value and true or false
									if module.ApplySettings then module:ApplySettings() end
									NotifyArenaPreview("showSpecText", style.showSpecText)
								end,
							},
							showPets = {
								type = "toggle", name = "ui.pets_61161ec5",
								order = 1.95, width = "full",
								hidden = function() local db = GetDB(); return not db or db.frameType ~= "gladius" end,
								suiPreviewKey = "showPets",
								get = function() local style = StyleSettings(); return not style or style.showPets ~= false end,
								set = function(_, value)
									local style = StyleSettings(); if not style then return end
									style.showPets = value and true or false
									if module.ApplySettings then module:ApplySettings() end
									NotifyArenaPreview("showPets", style.showPets)
								end,
							},
						},
					},
					trinketsBox = {
						type = "group",
						name = "ui.display_205c4b9e",
						order = 3,
						inline = true,
						args = {
							trinketEnabled = {
								type = "toggle",
								name = "ui.text_4a86d52f",
								desc = "ui.text_ffeaf14e",
								order = 1,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and db.Trinkets.enabled or false
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.enabled = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									if m and m.Trinkets then m.Trinkets:RefreshIcons() end
									NotifyArenaPreview("trinketEnabled", value and true or false)
									RefreshArenaOptions()
								end,
							},
							racialEnabled = {
								type = "toggle",
								name = "ui.text_c08220b0",
								desc = "ui.text_46295980",
								order = 2,
								width = "full",
								hidden = function()
									local db = GetDB()
									return true
								end,
								get = function()
									local db = GetDB()
									return db and db.Trinkets and db.Trinkets.racialEnabled or false
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.racialEnabled = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									if m and m.Trinkets then m.Trinkets:RefreshIcons() end
									NotifyArenaPreview("racialEnabled", value and true or false)
									RefreshArenaOptions()
								end,
							},
							trinketLayout = {
								type = "select", name = "ui.text_f8a147f1",
								order = 2.1, width = "full",
								values = { ROW = SarychUI:T("ui.options_71d6dac6f6"), COLUMN = SarychUI:T("ui.options_388892be39"),
									__order = { "ROW", "COLUMN" } },
								hidden = function()
									local db = GetDB()
									local tr = db and db.Trinkets
									return not db or db.frameType ~= "classic" or not tr
										or not tr.enabled or not module:IsArenaRacialEnabled()
								end,
								get = function()
									local db = GetDB()
									return db and db.Trinkets and db.Trinkets.layout == "COLUMN" and "COLUMN" or "ROW"
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.layout = value == "COLUMN" and "COLUMN" or "ROW"
									module:UpdateTrinketArrangement()
									NotifyArenaPreview()
								end,
							},
							trinketSpacing = {
								type = "range", name = "ui.text_728bf07d",
								order = 2.2, width = "full", min = 0, max = 30, step = 1,
								hidden = function()
									local db = GetDB()
									local tr = db and db.Trinkets
									return not db or db.frameType ~= "classic" or not tr
										or not tr.enabled or not module:IsArenaRacialEnabled()
								end,
								get = function()
									local db = GetDB()
									return db and db.Trinkets and tonumber(db.Trinkets.spacing) or 5
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.spacing = tonumber(value) or 5
									module:UpdateTrinketArrangement()
									NotifyArenaPreview()
								end,
							},
							trinketsScale = {
								type = "range",
								name = "ui.icon_scale_f9e60300",
								desc = "ui.changes_the_scale_of_trinket_and_racial_ability__0874beee",
								order = 3,
								min = 0.5,
								max = 2.0,
								step = 0.01,
								width = "full",
								hidden = function() local db = GetDB(); return db and db.frameType == "gladius" end,
								suiPreviewKey = "trinketsScale",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and (db.Trinkets.scale or 1.0) or 1.0
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.scale = tonumber(value) or 1.0
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									if m and m.Trinkets then m.Trinkets:RefreshIcons() end
									NotifyArenaPreview("trinketsScale", nil, true)
								end,
							},
							trinketDesaturate = {
								type = "toggle", name = "ui.text_3fda5970",
								order = 4, width = "full",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and db.Trinkets.desaturateOnCooldown == true
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.desaturateOnCooldown = value and true or false
									if module.UpdateTrinketCooldownColors then module:UpdateTrinketCooldownColors() end
									NotifyArenaPreview()
									local preview = SarychUI.PartyAbilitiesPreview
									if preview and preview.RefreshAll then preview:RefreshAll() end
								end,
							},
						},
					},
				},
			},

			extra = {
				type = "group",
				name = L and (L["Extra"] or SarychUI:T("ui.extra_d51dd676")) or SarychUI:T("ui.extra_d51dd676"),
				order = 99,
				disabled = function()
					local db = GetDB()
					return not (db and db.enabled)
				end,
				args = {
					arenaExtraPreview = {
						type = "description",
						name = "",
						order = 0,
						width = "full",
						suiPreview = "ArenaNumbersPreview",
					},
					arenaNumbers = {
						type = "toggle",
						name = "ui.text_2d6755b7",
						desc = "ui.arena1_5_7d808d75",
						order = 1,
						width = "full",
						suiPreviewKey = "arenaNumbers",
						get = function()
							local db = GetDB()
							return db and (db.arenaNumbers == 1 or db.arenaNumbers == true)
						end,
						set = function(_, value)
							local db = GetDB(); if not db then return end
							db.arenaNumbers = value and 1 or 0
							local m = SarychUI.modules[moduleName]
							if m and m.UpdateArenaNameplates then m:UpdateArenaNameplates() end
							NotifyArenaPreview("arenaNumbers", value and 1 or 0)
							RefreshArenaOptions()
						end,
					},
					arenaNumbersNameplates = {
						type = "toggle",
						name = "ui.text_64c22039",
						desc = "ui.arena1_5_090f985d",
						order = 2,
						width = "full",
						suiPreviewKey = "arenaNumbersNameplates",
						disabled = function()
							local db = GetDB()
							return not (db and (db.arenaNumbers == 1 or db.arenaNumbers == true))
						end,
						get = function()
							local db = GetDB()
							return db and (db.arenaNumbersNameplates == nil
								or db.arenaNumbersNameplates == 1 or db.arenaNumbersNameplates == true)
						end,
						set = function(_, value)
							local db = GetDB(); if not db then return end
							db.arenaNumbersNameplates = value and 1 or 0
							local m = SarychUI.modules[moduleName]
							if m and m.UpdateArenaNameplates then m:UpdateArenaNameplates() end
							NotifyArenaPreview("arenaNumbersNameplates", value and 1 or 0)
						end,
					},
					arenaNumbersArenaFrames = {
						type = "toggle",
						name = "ui.text_339d1836",
						desc = "ui.text_fc7f8c42",
						order = 3,
						width = "full",
						suiPreviewKey = "arenaNumbersArenaFrames",
						disabled = function()
							local db = GetDB()
							return not (db and (db.arenaNumbers == 1 or db.arenaNumbers == true))
						end,
						get = function()
							local db = GetDB()
							return db and (db.arenaNumbersArenaFrames == nil
								or db.arenaNumbersArenaFrames == 1 or db.arenaNumbersArenaFrames == true)
						end,
						set = function(_, value)
							local db = GetDB(); if not db then return end
							db.arenaNumbersArenaFrames = value and 1 or 0
							local m = SarychUI.modules[moduleName]
							if m and m.UpdateArenaNameplates then m:UpdateArenaNameplates() end
							NotifyArenaPreview("arenaNumbersArenaFrames", value and 1 or 0)
						end,
					},
					retabBox = {
						type = "group",
						name = "ui.tab_retargeting_0985137c",
						desc = "ui.added_by_request_hannahmckay_c26de524",
						order = 3,
						inline = true,
						args = {
							retab = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.in_arena_and_battlegrounds_tab_selects_enemy_pla_7b064175",
								order = 1,
								width = "full",
								get = function()
									local db = GetDB()
									return db and (db.retab == 1 or db.retab == true)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.retab = value and 1 or 0
									local m = SarychUI.modules[moduleName]
									if m and m.UpdateRetab then
										m:UpdateRetab()
									end
								end,
							},
						},
					},
					hideGroupRaidBox = {
						type = "group",
						name = "ui.hide_party_raid_text_cfcf6ed3",
						order = 2,
						inline = true,
						args = {
							groupTitlesPreview = {
								type = "description",
								name = "",
								order = 0,
								width = "full",
								suiPreview = "ArenaGroupTitlesPreview",
							},
							hideGroupRaidText = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.on_arena_hides_the_party_and_raid_labels_above_u_c1060b99",
								order = 1,
								width = "full",
								suiPreviewKey = "hideGroupRaidText",
								get = function()
									local db = GetDB()
									return db and (db.hideGroupRaidText == 1 or db.hideGroupRaidText == true)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.hideGroupRaidText = value and 1 or 0
									local arenaModule = SarychUI.modules and SarychUI.modules.arena
									if arenaModule and arenaModule.UpdateGroupTitles then
										arenaModule:UpdateGroupTitles()
									end
									NotifyArenaPreview("hideGroupRaidText", value and 1 or 0)
								end,
							},
						},
					},
					pvpScoreboardBox = {
						type = "group",
						name = "ui.class_colored_names_in_the_pvp_scoreboard_a8d2a85c",
						order = 5,
						inline = true,
						disabled = function()
							local db = GetToolsDB()
							return not (db and db.enabled == true)
						end,
						args = {
							enablePvpScoreboardClassNames = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.colors_player_names_by_class_on_the_battleground_7bf9a828",
								order = 1,
								width = "full",
								get = function()
									local db = GetToolsDB()
									return db and (db.enablePvpScoreboardClassNames == 1 or db.enablePvpScoreboardClassNames == true)
								end,
								set = function(_, value)
									local db = GetToolsDB(); if not db then return end
									db.enablePvpScoreboardClassNames = value and 1 or 0
									local toolsModule = SarychUI.modules and SarychUI.modules
									if toolsModule and SarychUI.modules.arena.ApplyPvpScoreboardClassNames then
										SarychUI.modules.arena:ApplyPvpScoreboardClassNames()
									end
								end,
							},
						},
					},
					arenaPointsBox = {
						type = "group",
						name = "ui.tinterface_pvpframe_pvp_arenapoints_icon_15_4_15_0a51d461",
						order = 6,
						inline = true,
						disabled = function()
							local db = GetToolsDB()
							return not (db and db.enabled == true)
						end,
						args = {
							enableArenaPointer = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.next_to_your_team_rating_on_the_pvp_tab_shows_ho_5a06b2d9",
								order = 1,
								width = "full",
								suiHelpIcon = true,
								get = function()
									local db = GetToolsDB()
									return db and (db.enableArenaPointer == 1 or db.enableArenaPointer == true)
								end,
								set = function(_, value)
									local db = GetToolsDB(); if not db then return end
									db.enableArenaPointer = value and 1 or 0
									local toolsModule = SarychUI.modules and SarychUI.modules
									if toolsModule and SarychUI.modules.arena.ApplyArenaPointer then
										SarychUI.modules.arena:ApplyArenaPointer()
									end
									RefreshArenaOptions()
								end,
							},
						},
					},
				},
			},
		},
	}
	local extraArgs = options.args.extra.args
	extraArgs.arenaNumbers.name = SarychUI:T("ui.enable_a54eaf37")
	extraArgs.arenaNumbersNameplates.name = SarychUI:T("ui.options_f0b3349772")
	extraArgs.arenaNumbersArenaFrames.name = SarychUI:T("ui.options_3bcbea5a03")
	extraArgs.arenaNumbersBox = {
		type = "group",
		name = "ui.text_2d6755b7",
		order = 1,
		inline = true,
		suiThreeCol = true,
		args = {
			arenaNumbers = extraArgs.arenaNumbers,
			arenaNumbersNameplates = extraArgs.arenaNumbersNameplates,
			arenaNumbersArenaFrames = extraArgs.arenaNumbersArenaFrames,
		},
	}
	extraArgs.arenaNumbers = nil
	extraArgs.arenaNumbersNameplates = nil
	extraArgs.arenaNumbersArenaFrames = nil
	extraArgs.hideGroupRaidBox.args.groupTitlesPreview = nil
	if module.ArenaTimers then extraArgs.arenaTimers = module.ArenaTimers:GetOptions() end
	local numberOptions = extraArgs.arenaNumbersBox.args
	extraArgs.arenaNumbersBox.desc = SarychUI:T("ui.options_6628847c23")
	for _, option in pairs(numberOptions) do
		option.desc = nil
		option.suiHelpIcon = nil
	end
	numberOptions.arenaNumbers.desc = SarychUI:T("ui.enable_a54eaf37")
	extraArgs.arenaNumbersBox.suiHelpIcon = true
	for _, entry in ipairs({
		{ "hideGroupRaidBox", "hideGroupRaidText" },
		{ "retabBox", "retab" },
		{ "pvpScoreboardBox", "enablePvpScoreboardClassNames" },
		{ "arenaPointsBox", "enableArenaPointer" },
	}) do
		local box = extraArgs[entry[1]]
		local option = box.args[entry[2]]
		box.desc = option.desc
		box.suiHelpIcon = true
		option.desc = SarychUI:T("ui.enable_a54eaf37")
		option.suiHelpIcon = nil
	end
	options.args.enemyAbilities = {
		type = "group", name = "ui.text_b0df4811", order = 4,
		hidden = function()
			return not EnemyAbilitiesSelected()
		end,
		args = {
			activeStyle = { type = "description", order = 0, width = "full",
				name = function()
					local db = GetDB()
					return SarychUI:T("ui.options_c5768690ce")
						.. ((db and db.frameType == "gladius") and "Gladius" or SarychUI:T("ui.options_03ced8ccad")) .. "|r"
				end },
			display = {
				type = "select", name = function() return L["PA_Content"] end, order = 2,
				values = { all = SarychUI:T("ui.options_deb9e5d902"), cooldown = L["PA_CooldownAbilities"],
					__order = { "all", "cooldown" } },
				get = function()
					local settings = EnemySettings()
					return settings and settings.displayMode or "cooldown"
				end,
				set = function(_, value)
					local settings = EnemySettings()
					if not settings then return end
					settings.displayMode = value
					RefreshEnemyAbilities()
					RefreshArenaOptions()
				end,
			},
			anchorMode = { type = "description", name = "ui.text_626eb562", order = 2.5 },
			controls = { type = "group", inline = true, name = "", order = 3, suiTwoCol = true,
				args = {
					x = EnemyRange("x", "PA_OffsetX", -150, 150, 3),
					y = EnemyRange("y", "PA_OffsetY", -150, 150, 4),
					spacing = EnemyRange("spacing", "PA_Spacing", 0, 30, 5),
					perRow = EnemyRange("perRow", "PA_PerRow", 1, 20, 6),
					size = EnemyRange("size", "PA_Size", 12, 128, 7),
					largeSingleRow = {
						type = "toggle", name = "ui.text_cb5f2672", order = 8,
						desc = "ui.text_8f1fd093",
						width = "full",
						get = function()
							local settings = EnemySettings()
							return settings and settings.layout.largeSingleRow == true
						end,
						set = function(_, value)
							local settings = EnemySettings()
							if not settings then return end
							settings.layout.largeSingleRow = value and true or false
							RefreshEnemyAbilities()
						end,
					},
				} },
			cooldownEdge = { type = "toggle", name = function() return L["PA_CooldownEdge"] end, order = 4,
				get = function()
					local settings = EnemySettings()
					return settings and settings.layout.cooldownEdge == true
				end,
				set = function(_, value)
					local settings = EnemySettings()
					if not settings then return end
					settings.layout.cooldownEdge = value
					RefreshEnemyAbilities()
				end },
			desaturateOnCooldown = { type = "toggle", name = "ui.text_3fda5970",
				order = 5,
				hidden = function()
					local settings = EnemySettings()
					return not settings or settings.displayMode ~= "all"
				end,
				get = function()
					local settings = EnemySettings()
					return settings and settings.layout.desaturateOnCooldown == true
				end,
				set = function(_, value)
					local settings = EnemySettings(); if not settings then return end
					settings.layout.desaturateOnCooldown = value and true or false
					RefreshEnemyAbilities()
				end },
			spells = { type = "execute", name = "ui.text_4489c485", order = 99,
				width = "full", suiFullRow = true,
				func = function()
					local core = SarychUI.OptionsCore
					if not core then return end
					local section = core._sections and core._sections["sui:extensions"]
					if not section or not section.path then return end
					local pathKey = table.concat(section.path, "/")
					core._twoPaneSelected = core._twoPaneSelected or {}
					core._twoPaneSelected[pathKey] = "party_abilities"
					core._twoPaneDetailScroll = core._twoPaneDetailScroll or {}
					core._twoPaneDetailScroll[pathKey] = 0
					core._addonListTabState = core._addonListTabState or {}
					core._addonListTabState.party_abilities = "spells"
					core:SelectSection("sui:extensions")
					core:Refresh()
				end },
		},
	}
	options.args.diminishings = {
		type = "group", name = "ui.text_8cb12044", order = 4.5,
		hidden = function()
			local db = GetDB()
			return not db or not module:IsDRShown()
		end,
		args = {
			activeStyle = { type = "description", order = 0, width = "full",
				name = function()
					local db = GetDB()
					return SarychUI:T("ui.options_0caf7d4078")
						.. ((db and db.frameType == "gladius") and "Gladius" or SarychUI:T("ui.options_03ced8ccad")) .. "|r"
				end },
			layout = { type = "group", name = "ui.position_a70a9ff4", order = 1, inline = true,
				suiTwoCol = true, args = {
				x = DRRange("x", SarychUI:T("ui.options_a3d6a6c502"), -200, 200, 1, 3, -2),
				y = DRRange("y", SarychUI:T("ui.options_322c955d5f"), -100, 100, 1, 4, 0),
				size = DRRange("size", SarychUI:T("ui.icon_size_040a2fda"), 12, 128, 1, 5, 24),
				spacing = DRRange("spacing", SarychUI:T("ui.spacing_between_icons_a9f8eb20"), 0, 20, 1, 6, 3),
			} },
		},
	}
	options.args.diminishings.args.layout.args.size.hidden = function()
		local db = GetDB(); return db and db.frameType == "gladius"
	end
    options.args.general.args.outlandArt = {
        type = "description", name = "", order = 999, width = "full",
        image = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-Outland.blp",
        imageWidth = 256, imageHeight = 128, imageAlign = "RIGHT",
        suiFadedImage = true,
        suiImageCorner = "BOTTOMRIGHT",
    }
    -- Reload must remain reachable after the master switch hides the body.
	return options
end
