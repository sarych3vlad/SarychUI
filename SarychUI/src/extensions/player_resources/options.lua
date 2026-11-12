-- Personal resource display extension settings.

local moduleName = "player_resources"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local _, PLAYER_CLASS = UnitClass("player")

local function DB()
	return SarychUI.db.profile.modules[moduleName]
end

local function Sub(key)
	return DB()[key]
end

local function RefreshConfig()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local function Apply()
	if module.Refresh then
		module:Refresh()
	end
	if SarychUI.PlayerResourcesPreview then
		SarychUI.PlayerResourcesPreview:RefreshAll()
	end
end

local function Toggle(sub, key)
	return {
		type = "toggle",
		get = function()
			return Sub(sub)[key] == 1
		end,
		set = function(_, v)
			Sub(sub)[key] = v and 1 or 0
			Apply()
		end,
	}
end

local function Range(sub, key, minV, maxV, step)
	return {
		type = "range",
		min = minV, max = maxV, step = step or 1,
		get = function()
			return Sub(sub)[key]
		end,
		set = function(_, v)
			Sub(sub)[key] = v
			Apply()
		end,
	}
end

local function Color(sub, key)
	return {
		type = "color",
		get = function()
			local c = Sub(sub)[key] or { 1, 1, 1 }
			return c[1], c[2], c[3]
		end,
		set = function(_, r, g, b)
			Sub(sub)[key] = { r, g, b }
			Apply()
		end,
	}
end

local DRAG_IDS = {
	plate = "playerPlate",
	shield = "playerShield",
	runes = "playerRunes",
	totems = "playerTotems",
}

local function SyncDragPosition(sub)
	local t = Sub(sub)
	local frameId = DRAG_IDS[sub]
	if not t or not frameId or not SarychUI.DragMode or not SarychUI.DragMode.SetFramePosition then
		return
	end
	SarychUI.DragMode:SetFramePosition(
		frameId,
		t.point or "CENTER",
		t.relativePoint or "CENTER",
		t.x or 0,
		t.y or 0
	)
end

local function CloseDragPanel(frameId)
	local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
	if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == frameId then
		panel:Close(false)
	end
end

local function PositionControls(sub, frameId, orderBase, hiddenFn)
	hiddenFn = hiddenFn or function()
		return Sub(sub).positioningEnabled ~= 1
	end
	return {
		positioningEnabled = {
			type = "toggle",
			name = "ui.enable_a54eaf37",
			desc = "ui.allow_moving_the_element_on_the_x_and_y_axes_63566fea",
			order = orderBase,
			width = "full",
			suiFullRow = true,
			get = function()
				return Sub(sub).positioningEnabled == 1
			end,
			set = function(_, v)
				local t = Sub(sub)
				t.positioningEnabled = v and 1 or 0
				if not v then
					t.showDragFrame = 0
					t.showGrid = 0
					CloseDragPanel(frameId)
				end
				Apply()
				RefreshConfig()
			end,
		},
		offsetX = {
			type = "range",
			name = "ui.x_offset_0b923c73",
			min = -800, max = 800, step = 1,
			order = orderBase + 1,
			get = function() return Sub(sub).x or 0 end,
			set = function(_, v)
				Sub(sub).x = v
				Apply()
				SyncDragPosition(sub)
			end,
			hidden = hiddenFn,
		},
		offsetY = {
			type = "range",
			name = "ui.y_offset_f7f3fdd7",
			min = -800, max = 800, step = 1,
			order = orderBase + 2,
			get = function() return Sub(sub).y or 0 end,
			set = function(_, v)
				Sub(sub).y = v
				Apply()
				SyncDragPosition(sub)
			end,
			hidden = hiddenFn,
		},
		freeMove = {
			type = "execute",
			name = function()
				if Sub(sub).showDragFrame == 1 then
					return SarychUI:T("ui.options_76e4992833")
				end
				return SarychUI:T("ui.options_0510004a87")
			end,
			desc = "ui.show_a_frame_and_window_to_drag_the_element_7ac0597e",
			order = orderBase + 3,
			width = "full",
			suiFullRow = true,
			func = function()
				local t = Sub(sub)
				local val = not (t.showDragFrame == 1)
				t.showDragFrame = val and 1 or 0
				t.showGrid = val and 1 or 0
				if val and t.positioningEnabled ~= 1 then
					t.positioningEnabled = 1
				end
				local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
				if panel and panel.Toggle then
					panel:Toggle(frameId, val)
				else
					Apply()
				end
				RefreshConfig()
			end,
			hidden = hiddenFn,
			suiResetDefaults = function()
				local t = Sub(sub)
				local def = SarychUI.defaults and SarychUI.defaults.profile.modules.player_resources
				def = def and def[sub]
				local fallback = ({
					plate = { 0, -133 },
					shield = { -114, -133 },
					runes = { 0, -294 },
					totems = { 0, -294 },
				})[sub] or { 0, 0 }
				local x = (def and def.x ~= nil) and def.x or fallback[1]
				local y = (def and def.y ~= nil) and def.y or fallback[2]
				t.x = x
				t.y = y
				if def and def.point then
					t.point = def.point
				end
				if def and def.relativePoint then
					t.relativePoint = def.relativePoint
				end
				Apply()
				SyncDragPosition(sub)
				local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
				if panel and panel.SyncDraftIfOpen then
					panel:SyncDraftIfOpen(frameId, x, y)
				end
				RefreshConfig()
			end,
		},
	}
end

function module:GetOptions()

	local options = {
		type = "group",
		name = "ui.personal_resource_display_5b847318",
		desc = "ui.compact_health_and_power_plate_runes_totems_and__bff83782",
		suiBodyDisabled = function() return not DB().enabled end,
		childGroups = "tab",
		args = {
            enabled = {
                type = "toggle", name = "ui.enable_a54eaf37", order = 0,
                desc = "ui.enable_or_disable_the_personal_resource_display__1acaf832",
                get = function() return DB().enabled end,
                set = function(_, value)
                    DB().enabled = value and true or false
                    if value then module:Enable() else module:Disable() end
                    if SarychUI.OptionsCore then SarychUI.OptionsCore:ScheduleSmartRefresh(true) end
                end,
            },
			plate = {
				type = "group",
				name = "ui.player_panel_b1ae4ece",
				order = 2,
				childGroups = "tab",
				disabled = function() return not DB().enabled end,
				args = {
					appearance = {
						type = "group",
						name = "ui.appearance_c407960b",
						order = 1,
						args = {
							preview = {
								type = "description",
								name = "",
								order = 0,
								width = "full",
								suiPreview = "PlayerResourcesPreview",
							},
							generalBox = {
								type = "group",
								name = "ui.player_panel_b1ae4ece",
								order = 1,
								inline = true,
								args = {
									visibilityMode = {
										type = "select",
										name = "ui.display_205c4b9e",
										desc = "ui.when_to_show_the_player_panel_2b5d34a4",
										order = 1,
										width = "full",
										values = {
											combat = SarychUI:T("ui.options_e3b5d18284"),
											always = SarychUI:T("ui.options_58fce5135b"),
											__order = { "combat", "always" },
										},
										get = function()
											return Sub("plate").alwaysShow == 1 and "always" or "combat"
										end,
										set = function(_, v)
											Sub("plate").alwaysShow = (v == "always") and 1 or 0
											Apply()
											RefreshConfig()
										end,
									},
									fadeTime = (function()
										local t = Range("plate", "fadeTime", 0, 3, 0.1)
										t.name = SarychUI:T("ui.options_cf594dc177")
										t.desc = SarychUI:T("ui.options_947c0bc344")
										t.order = 2
										t.width = "full"
										t.hidden = function()
											return Sub("plate").alwaysShow == 1
										end
										return t
									end)(),
								},
							},
							powerBox = {
								type = "group",
								name = "ui.power_bar_9f6484fc",
								order = 2,
								inline = true,
								args = {
									showPower = (function()
										local t = Toggle("plate", "showPower")
										t.name = SarychUI:T("ui.options_16b50a2431")
										t.desc = SarychUI:T("ui.options_06c304c2a6")
										t.order = 1
										t.width = "full"
										t.set = function(_, v)
											Sub("plate").showPower = v and 1 or 0
											Apply()
											RefreshConfig()
										end
										return t
									end)(),
									druidMana = (function()
										local t = Toggle("plate", "druidMana")
										t.name = SarychUI:T("ui.options_ecb2a9d8b4")
										t.desc = SarychUI:T("ui.options_5dc67f0d06")
										t.order = 2
										t.width = "full"
										t.hidden = function() return PLAYER_CLASS ~= "DRUID" end
										return t
									end)(),
								},
							},
							textBox = {
								type = "group",
								name = "ui.bar_text_f44fcc14",
								order = 3,
								inline = true,
								args = {
									showText = (function()
										local t = Toggle("plate", "showText")
										t.name = SarychUI:T("ui.options_985a8f82ae")
										t.desc = SarychUI:T("ui.options_e87984b05e")
										t.order = 1
										t.width = "full"
										t.set = function(_, v)
											Sub("plate").showText = v and 1 or 0
											Apply()
											RefreshConfig()
										end
										return t
									end)(),
									healthText = {
										type = "select",
										name = "ui.value_type_b71b2a2e",
										order = 2,
										width = "full",
										values = {
											percent = SarychUI:T("ui.options_1b1725098a"),
											value = SarychUI:T("ui.options_e807fbf3ce"),
											__order = { "percent", "value" },
										},
										hidden = function()
											return Sub("plate").showText ~= 1
										end,
										get = function() return Sub("plate").healthText or "percent" end,
										set = function(_, v) Sub("plate").healthText = v; Apply() end,
									},
									textAlign = {
										type = "select",
										name = "ui.text_position_2185be4f",
										desc = "ui.where_to_place_the_numbers_on_the_bar_5ff343cb",
										order = 3,
										width = "full",
										values = {
											left = SarychUI:T("ui.options_4af2530fc3"),
											center = SarychUI:T("ui.options_fd17e2f9ce"),
											right = SarychUI:T("ui.options_600c48eb0b"),
											__order = { "left", "center", "right" },
										},
										hidden = function()
											return Sub("plate").showText ~= 1
										end,
										get = function() return Sub("plate").textAlign or "right" end,
										set = function(_, v) Sub("plate").textAlign = v; Apply() end,
									},
									fontSize = (function()
										local t = Range("plate", "fontSize", 8, 20, 1)
										t.name = SarychUI:T("ui.font_size_9f9d637d")
										t.order = 4
										t.width = "full"
										t.hidden = function()
											return Sub("plate").showText ~= 1
										end
										return t
									end)(),
								},
							},
							layersBox = {
								type = "group",
								name = "ui.unitframelayers_support_2ed51314",
								order = 4,
								inline = true,
								args = {
									unitFrameLayers = (function()
										local t = Toggle("plate", "unitFrameLayers")
										t.name = SarychUI:T("ui.options_f2fff5d24b")
										t.desc = SarychUI:T("ui.options_b8beb4fe7c")
										t.order = 1
										t.width = "full"
										t.set = function(_, v)
											Sub("plate").unitFrameLayers = v and 1 or 0
											Apply()
											RefreshConfig()
										end
										return t
									end)(),
								},
							},
							colorBox = {
								type = "group",
								name = "ui.health_bar_color_0f25c3be",
								order = 5,
								inline = true,
								args = {
									healthColorMode = {
										type = "select",
										name = "ui.type_d4a6795c",
										order = 1,
										width = "full",
										values = {
											class = SarychUI:T("ui.options_e670d10107"),
											health = SarychUI:T("ui.options_86b6f8c04e"),
											custom = SarychUI:T("ui.options_e51629dea7"),
											__order = { "class", "health", "custom" },
										},
										get = function() return Sub("plate").healthColorMode or "class" end,
										set = function(_, v)
											Sub("plate").healthColorMode = v
											Apply()
											RefreshConfig()
										end,
									},
									healthColor = (function()
										local t = Color("plate", "healthColor")
										t.name = SarychUI:T("ui.color_92ab62ad")
										t.desc = SarychUI:T("ui.options_64efa0dc93")
										t.order = 2
										t.width = "full"
										t.hidden = function()
											return Sub("plate").healthColorMode ~= "custom"
										end
										return t
									end)(),
								},
							},
						},
					},
					position = {
						type = "group",
						name = "ui.size_and_position_890068de",
						order = 2,
						args = {
							sizeBox = {
								type = "group",
								name = "ui.panel_size_e70a0732",
								order = 1,
								inline = true,
								suiTwoCol = true,
								args = {
									width = (function()
										local t = Range("plate", "width", 60, 400, 1)
										t.name = SarychUI:T("ui.width_a97d46cd")
										t.order = 1
										return t
									end)(),
									gap = (function()
										local t = Range("plate", "gap", 0, 20, 1)
										t.name = SarychUI:T("ui.options_77e97b5ad2")
										t.order = 2
										t.disabled = function()
											return Sub("plate").showPower ~= 1
										end
										return t
									end)(),
									healthHeight = (function()
										local t = Range("plate", "healthHeight", 3, 40, 1)
										t.name = SarychUI:T("ui.options_028938c219")
										t.order = 3
										return t
									end)(),
									powerHeight = (function()
										local t = Range("plate", "powerHeight", 2, 40, 1)
										t.name = SarychUI:T("ui.options_c3da3d7c09")
										t.order = 4
										t.disabled = function()
											return Sub("plate").showPower ~= 1
										end
										return t
									end)(),
								},
							},
							positionBox = (function()
								local pos = PositionControls("plate", DRAG_IDS.plate, 1, function() return false end)
								pos.positioningEnabled = nil
								pos.offsetX.order = 1
								pos.offsetY.order = 2
								pos.freeMove.order = 3
								return {
									type = "group",
									name = "ui.change_player_panel_position_821bce78",
									order = 2,
									inline = true,
									suiTwoCol = true,
									args = pos,
								}
							end)(),
						},
					},
				},
			},
			shield = {
				type = "group",
				name = "ui.shield_indicator_5157898b",
				order = 3,
				hidden = function() return PLAYER_CLASS ~= "WARRIOR" end,
				disabled = function() return not DB().enabled end,
				args = {
					mainBox = {
						type = "group",
						name = "ui.shield_indicator_5157898b",
						order = 1,
						inline = true,
						args = {
							enabled = (function()
								local t = Toggle("shield", "enabled")
								t.name = SarychUI:T("ui.enable_a54eaf37")
								t.desc = SarychUI:T("ui.options_d69756e7e5")
								t.order = 1
								t.width = "full"
								t.set = function(_, v)
									local st = Sub("shield")
									st.enabled = v and 1 or 0
									if not v then
										st.showDragFrame = 0
										st.showGrid = 0
										CloseDragPanel(DRAG_IDS.shield)
									end
									Apply()
									RefreshConfig()
								end
								return t
							end)(),
							size = (function()
								local t = Range("shield", "size", 12, 64, 1)
								t.name = SarychUI:T("ui.options_5f1f71ccdc")
								t.order = 2
								t.width = "full"
								t.hidden = function() return Sub("shield").enabled ~= 1 end
								return t
							end)(),
						},
					},
					positionBox = (function()
						local shieldHidden = function()
							return Sub("shield").enabled ~= 1
						end
						local pos = PositionControls("shield", DRAG_IDS.shield, 1, shieldHidden)
						pos.positioningEnabled = nil
						pos.freeMove.disabled = shieldHidden
						pos.offsetX.order = 1
						pos.offsetY.order = 2
						pos.freeMove.order = 3
						return {
							type = "group",
							name = "ui.change_shield_indicator_position_eb1e7134",
							order = 2,
							inline = true,
							suiTwoCol = true,
							hidden = shieldHidden,
							args = pos,
						}
					end)(),
				},
			},
			runes = {
				type = "group",
				name = "ui.runes_9c7a204d",
				order = 4,
				hidden = function() return PLAYER_CLASS ~= "DEATHKNIGHT" end,
				disabled = function() return not DB().enabled end,
				args = {
					mainBox = {
						type = "group",
						name = "ui.runes_9c7a204d",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							enabled = (function()
								local t = Toggle("runes", "enabled")
								t.name = SarychUI:T("ui.enable_a54eaf37")
								t.desc = SarychUI:T("ui.options_7923e52d16")
								t.order = 1
								t.width = "full"
								t.suiFullRow = true
								t.set = function(_, v)
									local st = Sub("runes")
									st.enabled = v and 1 or 0
									if not v then
										st.showDragFrame = 0
										st.showGrid = 0
										CloseDragPanel(DRAG_IDS.runes)
									end
									Apply()
									RefreshConfig()
								end
								return t
							end)(),
							width = (function()
								local t = Range("runes", "width", 10, 100, 1)
								t.name = SarychUI:T("ui.options_d63c367d65")
								t.order = 2
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							height = (function()
								local t = Range("runes", "height", 4, 40, 1)
								t.name = SarychUI:T("ui.options_c557e80c9c")
								t.order = 3
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							gap = (function()
								local t = Range("runes", "gap", 0, 12, 1)
								t.name = SarychUI:T("ui.options_7a88372d69")
								t.order = 4
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							showIcons = (function()
								local t = Toggle("runes", "showIcons")
								t.name = SarychUI:T("ui.options_4d87f79b4e")
								t.desc = SarychUI:T("ui.options_caab0d60ca")
								t.order = 5
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							readyFlash = (function()
								local t = Toggle("runes", "readyFlash")
								t.name = SarychUI:T("ui.options_b8fdba9d86")
								t.desc = SarychUI:T("ui.options_d5f7cf4a2f")
								t.order = 6
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							showTimer = (function()
								local t = Toggle("runes", "showTimer")
								t.name = SarychUI:T("ui.options_2ae8f59c32")
								t.desc = SarychUI:T("ui.options_0b8d72a14d")
								t.order = 7
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								t.set = function(_, v)
									Sub("runes").showTimer = v and 1 or 0
									Apply()
									RefreshConfig()
								end
								return t
							end)(),
							timerFontSize = (function()
								local t = Range("runes", "timerFontSize", 8, 24, 1)
								t.name = SarychUI:T("ui.options_193760492d")
								t.order = 8
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function()
									return Sub("runes").enabled ~= 1 or Sub("runes").showTimer ~= 1
								end
								return t
							end)(),
						},
					},
					colorBox = {
						type = "group",
						name = "ui.rune_colors_adb15a03",
						order = 2,
						inline = true,
						suiTwoCol = true,
						hidden = function() return Sub("runes").enabled ~= 1 end,
						args = {
							bloodColor = (function()
								local t = Color("runes", "bloodColor")
								t.name = SarychUI:T("ui.options_3614f36155")
								t.order = 1
								return t
							end)(),
							unholyColor = (function()
								local t = Color("runes", "unholyColor")
								t.name = SarychUI:T("ui.options_e19117a435")
								t.order = 2
								return t
							end)(),
							frostColor = (function()
								local t = Color("runes", "frostColor")
								t.name = SarychUI:T("ui.options_616f4b8a79")
								t.order = 3
								return t
							end)(),
							deathColor = (function()
								local t = Color("runes", "deathColor")
								t.name = SarychUI:T("ui.options_fd2a79b9cb")
								t.desc = SarychUI:T("ui.options_fb69e13432")
								t.order = 4
								return t
							end)(),
							emptyColor = (function()
								local t = Color("runes", "emptyColor")
								t.name = SarychUI:T("ui.options_591471f237")
								t.desc = SarychUI:T("ui.options_55ab487ba7")
								t.order = 5
								return t
							end)(),
						},
					},
					positionBox = (function()
						local runesHidden = function()
							return Sub("runes").enabled ~= 1
						end
						local pos = PositionControls("runes", DRAG_IDS.runes, 1, runesHidden)
						pos.positioningEnabled = nil
						pos.freeMove.disabled = runesHidden
						pos.offsetX.order = 1
						pos.offsetY.order = 2
						pos.freeMove.order = 3
						return {
							type = "group",
							name = "ui.change_rune_position_edc68a8e",
							order = 3,
							inline = true,
							suiTwoCol = true,
							hidden = runesHidden,
							args = pos,
						}
					end)(),
				},
			},
			totems = {
				type = "group",
				name = "ui.totems_724bc4cf",
				order = 5,
				hidden = function() return PLAYER_CLASS ~= "SHAMAN" end,
				disabled = function() return not DB().enabled end,
				args = {
					mainBox = {
						type = "group",
						name = "ui.totems_724bc4cf",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							enabled = (function()
								local t = Toggle("totems", "enabled")
								t.name = SarychUI:T("ui.enable_a54eaf37")
								t.desc = SarychUI:T("ui.options_a9891086da")
								t.order = 1
								t.width = "full"
								t.suiFullRow = true
								t.set = function(_, v)
									local st = Sub("totems")
									st.enabled = v and 1 or 0
									if not v then
										st.showDragFrame = 0
										st.showGrid = 0
										CloseDragPanel(DRAG_IDS.totems)
									end
									Apply()
									RefreshConfig()
								end
								return t
							end)(),
							size = (function()
								local t = Range("totems", "size", 16, 64, 1)
								t.name = SarychUI:T("ui.options_5f1f71ccdc")
								t.order = 2
								t.hidden = function() return Sub("totems").enabled ~= 1 end
								return t
							end)(),
							gap = (function()
								local t = Range("totems", "gap", 0, 12, 1)
								t.name = SarychUI:T("ui.options_7a88372d69")
								t.order = 3
								t.hidden = function() return Sub("totems").enabled ~= 1 end
								return t
							end)(),
							pulse = (function()
								local t = Toggle("totems", "pulse")
								t.name = SarychUI:T("ui.options_7f69a7e3f4")
								t.desc = SarychUI:T("ui.options_3a9a8a436a")
								t.order = 4
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("totems").enabled ~= 1 end
								t.set = function(_, v)
									Sub("totems").pulse = v and 1 or 0
									Apply()
									RefreshConfig()
								end
								return t
							end)(),
							pulseHeight = (function()
								local t = Range("totems", "pulseHeight", 2, 12, 1)
								t.name = SarychUI:T("ui.options_d5bd3bf470")
								t.order = 5
								t.hidden = function()
									return Sub("totems").enabled ~= 1 or Sub("totems").pulse ~= 1
								end
								return t
							end)(),
							pulseColor = (function()
								local t = Color("totems", "pulseColor")
								t.name = SarychUI:T("ui.options_54150c0bca")
								t.order = 6
								t.hidden = function()
									return Sub("totems").enabled ~= 1 or Sub("totems").pulse ~= 1
								end
								return t
							end)(),
							clickThrough = (function()
								local t = Toggle("totems", "clickThrough")
								t.name = SarychUI:T("ui.options_8ed310f3e4")
								t.desc = SarychUI:T("ui.options_fa43b6d24b")
								t.order = 7
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("totems").enabled ~= 1 end
								return t
							end)(),
						},
					},
					positionBox = (function()
						local totemsHidden = function()
							return Sub("totems").enabled ~= 1
						end
						local pos = PositionControls("totems", DRAG_IDS.totems, 1, totemsHidden)
						pos.positioningEnabled = nil
						pos.freeMove.disabled = totemsHidden
						pos.offsetX.order = 1
						pos.offsetY.order = 2
						pos.freeMove.order = 3
						return {
							type = "group",
							name = "ui.change_totem_position_24afc17e",
							order = 2,
							inline = true,
							suiTwoCol = true,
							hidden = totemsHidden,
							args = pos,
						}
					end)(),
				},
			},
		},
	}
	local plate = options.args.plate
	options.args.appearance = plate.args.appearance
	options.args.appearance.order = 2
	options.args.appearance.disabled = plate.disabled
	options.args.position = plate.args.position
	options.args.position.order = 3
	options.args.position.disabled = plate.disabled
	options.args.plate = nil
	options.args.shield.order = 4
	options.args.runes.order = 5
	options.args.totems.order = 6
	return options
end
