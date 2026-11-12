-- SarychUI Minimap Module Options
-- Full sarMinimap settings integration

local moduleName = "minimap"
local L = SarychUI.L

local module = SarychUI:GetModule(moduleName)
if not module then return end

if not LibStub or not LibStub("AceConfig-3.0", true) then
	return
end

local function GetIconSettings(db, buttonID)
	db.addonButtons = db.addonButtons or { icons = {} }
	db.addonButtons.icons = db.addonButtons.icons or {}
	if not db.addonButtons.icons[buttonID] then
		if module.GetDefaultIconSettings then
			db.addonButtons.icons[buttonID] = module:GetDefaultIconSettings(buttonID)
		else
			db.addonButtons.icons[buttonID] = {
				managed = true,
				shown = true,
				angle = 225,
				radius = 82,
				scale = 1.0,
			}
		end
	end
	return db.addonButtons.icons[buttonID]
end

local function SanitizeOptionKey(buttonID)
	return "icon_" .. (buttonID:gsub("[^%w]", "_"))
end

local function OnIconSettingChanged(buttonID, field, value)
	if module.OnAddonButtonSettingChanged then
		module:OnAddonButtonSettingChanged(buttonID, field, value)
	end
end

local function CountSavedAddonButtons(db)
	if not db or not db.addonButtons or not db.addonButtons.icons then
		return 0
	end
	local count = 0
	for buttonID in pairs(db.addonButtons.icons) do
		if module.IsBlizzardMinimapButton and module:IsBlizzardMinimapButton(buttonID) then
		elseif module.IsIgnoredMinimapButtonID and module:IsIgnoredMinimapButtonID(buttonID) then
		else
			count = count + 1
		end
	end
	return count
end

local function RefreshConfig()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI and SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local function NotifyMinimapPreview(key, value)
	local preview = SarychUI and SarychUI.MinimapPreview
	if not preview then return end
	if key ~= nil and preview.SetLiveValue then
		preview:SetLiveValue(key, value)
	elseif preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function isOn(key)
	local db = module.addon.db.profile.modules[moduleName]
	if not db then return false end
	local v = db[key]
	return v == 1 or v == true
end

local function WriteMinimapOffset(axis, value)
	local mdb = module.addon.db.profile.modules[moduleName]
	if not mdb then return end
	if axis == "x" then
		mdb.offsetX = value
		mdb.minimapX = value
		mdb.minimapSavedX = value
	else
		mdb.offsetY = value
		mdb.minimapY = value
		mdb.minimapSavedY = value
	end
	if module.ApplySettings then
		module:ApplySettings()
	end
end

function module:BuildAddonButtonIconOptions()

	return module:_BuildAddonButtonIconOptionsImpl()
end

function module:InvalidateAddonButtonIconOptionsCache()
	self._cachedIconOptions = nil
	self._cachedIconOptionsCount = nil
end

function module:_BuildAddonButtonIconOptionsImpl()
	if self._cachedIconOptions then
		return self._cachedIconOptions
	end

	local args = {}
	local db = self.addon.db.profile.modules[moduleName]
	if not db.addonButtons or not db.addonButtons.icons then
		self._cachedIconOptions = args
		self._cachedIconOptionsCount = 0
		return args
	end

	local ids = {}
	for buttonID in pairs(db.addonButtons.icons) do
		if module.IsBlizzardMinimapButton and module:IsBlizzardMinimapButton(buttonID) then
			-- skip Blizzard frames (managed in «Внешний вид»)
		elseif module.IsIgnoredMinimapButtonID and module:IsIgnoredMinimapButtonID(buttonID) then
			-- skip service / quest pin frames
		else
			ids[#ids + 1] = buttonID
		end
	end
	table.sort(ids)

	for i, buttonID in ipairs(ids) do
		local key = SanitizeOptionKey(buttonID)
		local displayName = self:GetButtonDisplayName(buttonID)
		args[key] = {
			type = "group",
			name = displayName,
			order = 20 + i,
			args = {
				managed = {
					type = "toggle",
					name = "ui.manage_via_sarychui_ae8c3a6e",
					desc = "ui.sarychui_sets_the_angle_you_can_also_drag_the_bu_91caec5f",
					order = 1,
					width = "full",
					get = function()
						return GetIconSettings(db, buttonID).managed == true
					end,
					set = function(_, value)
						local managed = value and true or false
						GetIconSettings(db, buttonID).managed = managed
						OnIconSettingChanged(buttonID, "managed", managed)
					end,
				},
				shown = {
					type = "toggle",
					name = "ui.show_button_3d63b405",
					order = 2,
					width = "full",
					get = function()
						return GetIconSettings(db, buttonID).shown ~= false
					end,
					set = function(_, value)
						local shown = value and true or false
						GetIconSettings(db, buttonID).shown = shown
						OnIconSettingChanged(buttonID, "shown", shown)
					end,
				},
				angle = {
					type = "range",
					name = "ui.angle_a2de2790",
					suiExternalSyncKey = "minimap.angle." .. buttonID,
					desc = "ui.0_right_90_top_180_left_270_bottom_you_can_also__ca8d4c86",
					order = 3,
					min = 0,
					max = 359,
					step = 1,
					disabled = function()
						return not GetIconSettings(db, buttonID).managed
					end,
					get = function()
						return GetIconSettings(db, buttonID).angle or 225
					end,
					set = function(_, value)
						GetIconSettings(db, buttonID).angle = value
						OnIconSettingChanged(buttonID, "angle", value)
					end,
				},
			},
		}
	end

	self._cachedIconOptions = args
	self._cachedIconOptionsCount = #ids
	return args
end

function module:GetOptions()
	local db = self.addon.db.profile.modules[moduleName]
	local savedButtonCount = CountSavedAddonButtons(db)
	-- Если кнопки уже есть в профиле - сразу показываем настройки угла.
	if savedButtonCount > 0 then
		self._addonButtonOptionsExpanded = true
	end
	local iconOptions = {}
	local iconCount = savedButtonCount
	if self._addonButtonOptionsExpanded then
		iconOptions = self:BuildAddonButtonIconOptions()
		iconCount = self._cachedIconOptionsCount or savedButtonCount
	end


	local buttonsArgs = {
		addonButtonsBox = {
			type = "group",
			name = "ui.manage_addon_buttons_8ac66e94",
			order = 1,
			inline = true,
			args = {
				buttonsEnabled = {
					type = "toggle",
					name = "ui.hide_addon_buttons_cffffd700display_left_click_r_f8ce48a6",
					desc = "ui.hide_managed_buttons_and_show_them_when_clicking_8d5c124a",
					order = 1,
					width = "full",
					get = function() return self.addon.db.profile.modules[moduleName].buttonsEnabled == 1 end,
					set = function(info, value)
						self.addon.db.profile.modules[moduleName].buttonsEnabled = value and 1 or 0
						if self.ApplySettings then self:ApplySettings() end
					end,
				},
				hideDelay = {
					type = "range",
					name = "ui.hide_delay_sec_876f99f1",
					order = 2,
					min = 0,
					max = 5,
					step = 0.1,
					disabled = function() return self.addon.db.profile.modules[moduleName].buttonsEnabled ~= 1 end,
					get = function() return self.addon.db.profile.modules[moduleName].hideDelay or 0.5 end,
					set = function(info, value)
						self.addon.db.profile.modules[moduleName].hideDelay = value
					end,
				},
				fadeTime = {
					type = "range",
					name = "ui.animation_time_sec_c17fb702",
					order = 3,
					min = 0.1,
					max = 2,
					step = 0.1,
					disabled = function() return self.addon.db.profile.modules[moduleName].buttonsEnabled ~= 1 end,
					get = function() return self.addon.db.profile.modules[moduleName].fadeTime or 0.1 end,
					set = function(info, value)
						self.addon.db.profile.modules[moduleName].fadeTime = value
					end,
				},
			},
		},
		refreshButtons = {
			type = "execute",
			name = "ui.refresh_button_list_e5228731",
			desc = "ui.scan_the_minimap_and_add_found_addon_buttons_37c2608d",
			order = 2,
			width = "full",
			func = function()
				if module.ScanAddonMinimapButtons then
						module:ScanAddonMinimapButtons()

				end
				module._addonButtonOptionsExpanded = true
				if module.InvalidateAddonButtonIconOptionsCache then
					module:InvalidateAddonButtonIconOptionsCache()
				end
				if SarychUI and SarychUI.RebuildModuleOptions then
					SarychUI:RebuildModuleOptions("minimap")
				else
					local reg = LibStub("AceConfigRegistry-3.0", true)
					if reg then
						reg:NotifyChange("SarychUI")
					end
				end
			end,
		},
		btnListInfo = {
			type = "description",
			name = function()
				local count = CountSavedAddonButtons(db)
				if count == 0 then
					return SarychUI:T("ui.options_e85b1186c9")
				end
				return string.format(SarychUI:T("ui.options_7a40ef4392"), count)
			end,
			order = 3,
			width = "full",
		},
		iconHeader = {
			type = "header",
			name = "ui.button_settings_3f16a9fc",
			order = 10,
			hidden = function() return not module._addonButtonOptionsExpanded end,
		},
		loadIconControls = {
			type = "execute",
			name = "ui.load_per_button_settings_da9cf32b",
			desc = "ui.build_controls_for_each_found_button_heavy_runs__66847608",
			order = 10.5,
			width = "full",
			hidden = function() return module._addonButtonOptionsExpanded end,
			func = function()
				module._addonButtonOptionsExpanded = true
				if module.InvalidateAddonButtonIconOptionsCache then
					module:InvalidateAddonButtonIconOptionsCache()
				end
				if SarychUI and SarychUI.RebuildModuleOptions then
					SarychUI:RebuildModuleOptions("minimap")
				end
			end,
		},
	}

	for key, opt in pairs(iconOptions) do
		buttonsArgs[key] = opt
	end

	return {
		type = "group",
		name = "ui.minimap_0caefe45",
		desc = L and (L["Minimap_Description"] or SarychUI:T("ui.options_985d072bbb")) or SarychUI:T("ui.options_985d072bbb"),
		childGroups = "tab",
		args = {
			main = {
				type = "group",
				name = "ui.general_b250a3d6",
				order = 1,
				args = {
					header = {
						type = "header",
						name = L["Minimap"] or SarychUI:T("ui.minimap_0caefe45"),
						order = 1,
					},
					enabled = {
						suiModuleEnable = true,
						type = "toggle",
						name = "ui.enable_module_b623b573",
						order = 2,
						width = "full",
						get = function() return self.addon.db.profile.modules[moduleName].enabled end,
						set = function(info, value)
							self.addon.db.profile.modules[moduleName].enabled = value
							if value then
								self.addon:EnableModule(moduleName)
							else
								self.addon:DisableModule(moduleName)
							end
						end,
					},
				},
			},
			position = {
				type = "group",
				name = "ui.positions_and_scale_14cee8fd",
				order = 2,
				disabled = function() return not self.addon.db.profile.modules[moduleName].enabled end,
				args = {
					positionIllustration = {
						type = "description",
						name = "",
						order = 0,
						width = "full",
						image = "Interface\\TUTORIALFRAME\\UI-TutorialFrame-SpiritRez.blp",
						imageWidth = 512,
						imageHeight = 128,
						imageAlign = "CENTER",
					},
					positionBox = {
						type = "group",
						name = "ui.change_minimap_layout_0e98428c",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							positioningEnabled = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.enable_minimap_position_changes_4c605c35",
								order = 1,
								width = "full",
								suiFullRow = true,
								get = function() return isOn("positioningEnabled") end,
								set = function(_, value)
									local mdb = self.addon.db.profile.modules[moduleName]
									mdb.positioningEnabled = value and 1 or 0
									if not value then
										mdb.showDragFrame = 0
										mdb.showGrid = 0
										local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
										if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "minimap" then
											panel:Close(false)
										end
									end
									if self.ApplySettings then self:ApplySettings() end
									RefreshConfig()
								end,
							},
							offsetX = {
								type = "range",
								name = "ui.x_offset_0b923c73",
								order = 2,
								min = -500, max = 500, step = 1,
								get = function() return self.addon.db.profile.modules[moduleName].offsetX or 0 end,
								set = function(_, value)
									WriteMinimapOffset("x", value)
								end,
								hidden = function() return not isOn("positioningEnabled") end,
							},
							offsetY = {
								type = "range",
								name = "ui.y_offset_f7f3fdd7",
								order = 3,
								min = -500, max = 500, step = 1,
								get = function() return self.addon.db.profile.modules[moduleName].offsetY or 0 end,
								set = function(_, value)
									WriteMinimapOffset("y", value)
								end,
								hidden = function() return not isOn("positioningEnabled") end,
							},
							showDragFrame = {
								type = "execute",
								name = function()
									if isOn("showDragFrame") then
										return SarychUI:T("ui.options_76e4992833")
									end
									return SarychUI:T("ui.options_0510004a87")
								end,
								desc = "ui.show_a_frame_and_box_to_drag_the_minimap_a2e3ff8d",
								order = 4,
								width = "full",
								suiFullRow = true,
								func = function()
									local mdb = self.addon.db.profile.modules[moduleName]
									local val = not (mdb.showDragFrame == 1)
									mdb.showDragFrame = val and 1 or 0
									mdb.showGrid = val and 1 or 0
									local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
									if panel and panel.Toggle then
										panel:Toggle("minimap", val)
									elseif self.ApplySettings then
										self:ApplySettings()
									end
									RefreshConfig()
								end,
								suiResetDefaults = function()
									local def = SarychUI.defaults and SarychUI.defaults.profile.modules.minimap
									WriteMinimapOffset("x", (def and def.offsetX) or -5)
									WriteMinimapOffset("y", (def and def.offsetY) or -5)
									local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
									if panel and panel.SyncDraftIfOpen then
										panel:SyncDraftIfOpen("minimap", (def and def.offsetX) or -5, (def and def.offsetY) or -5)
									end
									RefreshConfig()
								end,
								hidden = function() return not isOn("positioningEnabled") end,
							},
						},
					},
                    scaleBox = {
                        type = "group",
                        name = "ui.minimap.change_scale",
                        order = 1.5,
                        inline = true,
                        args = {
                            scalingEnabled = {
                                type = "toggle",
                                name = "ui.enable_a54eaf37",
                                order = 1,
                                width = "full",
                                get = function() return isOn("scalingEnabled") end,
                                set = function(_, value)
                                    self.addon.db.profile.modules[moduleName].scalingEnabled = value and 1 or 0
                                    if self.ApplySettings then self:ApplySettings() end
                                    RefreshConfig()
                                end,
                            },
                            minimapScale = {
                                type = "range",
                                name = "ui.scale_e037e967",
                                order = 2,
                                width = "full",
                                min = 0.5, max = 2.0, step = 0.05,
                                get = function() return self.addon.db.profile.modules[moduleName].minimapScale or 1.0 end,
                                set = function(_, value)
                                    self.addon.db.profile.modules[moduleName].minimapScale = value
                                    if self.ApplySettings then self:ApplySettings() end
                                end,
                                hidden = function() return not isOn("scalingEnabled") end,
                            },
                        },
                    },
					zoneTextBox = {
						type = "group",
						name = "ui.zone_text_settings_848cc28a",
						order = 2,
						inline = true,
						suiTwoCol = true,
						args = {
							moveZoneText = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.move_zone_text_onto_the_minimap_0b2b83a1",
								order = 1,
								width = "full",
								suiFullRow = true,
								get = function() return isOn("moveZoneText") end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].moveZoneText = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									RefreshConfig()
								end,
							},
							zoneTextOffsetX = {
								type = "range",
								name = "ui.x_offset_0b923c73",
								order = 2,
								min = -100, max = 100, step = 1,
								get = function() return self.addon.db.profile.modules[moduleName].zoneTextOffsetX or 0 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].zoneTextOffsetX = value
									if self.ApplySettings then self:ApplySettings() end
								end,
								hidden = function() return not isOn("moveZoneText") end,
							},
							zoneTextOffsetY = {
								type = "range",
								name = "ui.y_offset_f7f3fdd7",
								order = 3,
								min = -100, max = 100, step = 1,
								get = function() return self.addon.db.profile.modules[moduleName].zoneTextOffsetY or 4 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].zoneTextOffsetY = value
									if self.ApplySettings then self:ApplySettings() end
								end,
								hidden = function() return not isOn("moveZoneText") end,
							},
						},
					},
				},
			},
			elements = {
				type = "group",
				name = "ui.appearance_c407960b",
				order = 3,
				disabled = function() return not self.addon.db.profile.modules[moduleName].enabled end,
				args = {
					preview = {
						type = "description",
						name = "",
						order = 1,
						width = "full",
						suiPreview = "MinimapPreview",
					},
					appearanceBox = {
						type = "group",
						name = "ui.minimap_element_visibility_7d4ad6d8",
						order = 2,
						inline = true,
						args = {
							hideBorder = {
								type = "toggle", name = "ui.hide_the_border_around_zone_text_cf838d97", order = 1, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideBorder == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideBorder = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideBorder", value and 1 or 0)
								end,
							},
							hideZoomButtons = {
								type = "toggle", name = "ui.hide_zoom_buttons_e27a1f18", order = 2, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideZoomButtons == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideZoomButtons = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideZoomButtons", value and 1 or 0)
								end,
							},
							hideWorldMapButton = {
								type = "toggle", name = "ui.hide_world_map_button_64e5bca0", order = 3, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideWorldMapButton == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideWorldMapButton = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideWorldMapButton", value and 1 or 0)
								end,
							},
							hideClock = {
								type = "toggle", name = "ui.hide_clock_813eb2d2", order = 4, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideClock == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideClock = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideClock", value and 1 or 0)
								end,
							},
							hideTracking = {
								type = "toggle", name = "ui.hide_tracking_button_5fe9de65", order = 5, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideTracking == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideTracking = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideTracking", value and 1 or 0)
								end,
							},
							hideCalendar = {
								type = "toggle", name = "ui.hide_calendar_e1323dc8", order = 6, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideCalendar == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideCalendar = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideCalendar", value and 1 or 0)
								end,
							},
							hideInstanceDifficulty = {
								type = "toggle",
								name = "ui.text_c7e65b14",
								desc = "ui.10_25_33cc4988",
								order = 7,
								width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideInstanceDifficulty == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideInstanceDifficulty = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideInstanceDifficulty", value and 1 or 0)
								end,
							},
						},
					},
				},
			},
			buttons = {
				type = "group",
				name = "ui.addon_buttons_a8b1a2a2",
				order = 4,
				suiTwoPane = true,
				disabled = function() return not self.addon.db.profile.modules[moduleName].enabled end,
				args = buttonsArgs,
			},
			mouse = {
				type = "group",
				name = "ui.control_a4bba03c",
				order = 5,
				disabled = function() return not self.addon.db.profile.modules[moduleName].enabled end,
				args = {
					mouseBox = {
						type = "group",
						name = "ui.mouse_control_settings_c601f0a9",
						order = 1,
						inline = true,
						args = {
							leftClickEnabled = {
								type = "toggle",
								name = "ui.shift_left_click_cffffd700set_raid_target_r_cd8707b9",
								order = 1, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].leftClickEnabled == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].leftClickEnabled = value and 1 or 0
								end,
							},
							rightClickEnabled = {
								type = "toggle",
								name = "ui.right_click_cffffd700open_calendar_r_a49beabb",
								order = 2, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].rightClickEnabled == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].rightClickEnabled = value and 1 or 0
								end,
							},
							middleClickEnabled = {
								type = "toggle",
								name = "ui.middle_click_mouse_wheel_click_cffffd700tracking_938494e9",
								order = 3, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].middleClickEnabled == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].middleClickEnabled = value and 1 or 0
								end,
							},
							wheelEnabled = {
								type = "toggle",
								name = "ui.mouse_wheel_cffffd700zoom_in_and_out_r_9107be69",
								order = 4, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].wheelEnabled == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].wheelEnabled = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									RefreshConfig()
								end,
							},
							wheelZoomSound = {
								type = "toggle",
								name = "ui.sound_when_zooming_in_and_out_66b50559",
								desc = "ui.plays_the_standard_minimap_zoom_button_sound_whe_5bbb8616",
								order = 5, width = "full",
								disabled = function() return self.addon.db.profile.modules[moduleName].wheelEnabled ~= 1 end,
								get = function() return self.addon.db.profile.modules[moduleName].wheelZoomSound ~= 0 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].wheelZoomSound = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
								end,
							},
						},
					},
				},
			},
		},
	}
end
