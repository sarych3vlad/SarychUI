-- Options: Ресурсы игрока (after Action Bar, before Cooldown text).

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
			name = "Включить",
			desc = "Разрешить смещение элемента по осям X и Y.",
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
			name = "Смещение по X",
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
			name = "Смещение по Y",
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
					return "Свободное перемещение |cff00ff00(вкл)|r"
				end
				return "Свободное перемещение"
			end,
			desc = "Показать рамку и окошко для перетаскивания элемента.",
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
		},
	}
end

function module:GetOptions()

	return {
		type = "group",
		name = "Ресурсы игрока",
		desc = "Компактная панель здоровья и ресурса, руны, тотемы и индикатор щита.",
		suiNavTip = "Новое: добавлено в версии 1.2.0",
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = "Общее",
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = "Включить модуль",
						desc = "Включить или выключить модуль «Ресурсы игрока».",
						order = 1,
						width = "full",
						get = function() return DB().enabled end,
						set = function(_, v)
							DB().enabled = v and true or false
							if v then module:Enable() else module:Disable() end
							RefreshConfig()
						end,
					},
				},
			},
			plate = {
				type = "group",
				name = "Панель игрока",
				order = 2,
				childGroups = "tab",
				disabled = function() return not DB().enabled end,
				args = {
					appearance = {
						type = "group",
						name = "Внешний вид",
						order = 1,
						args = {
							generalBox = {
								type = "group",
								name = "Панель игрока",
								order = 1,
								inline = true,
								args = {
									visibilityMode = {
										type = "select",
										name = "Отображение",
										desc = "Когда показывать панель игрока.",
										order = 1,
										width = "full",
										values = {
											combat = "Только при изменении значений",
											always = "Всегда показывать",
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
										t.name = "Время исчезновения"
										t.desc = "Секунды до скрытия, когда здоровье снова полное и нет боя."
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
								name = "Полоса ресурса",
								order = 2,
								inline = true,
								args = {
									showPower = (function()
										local t = Toggle("plate", "showPower")
										t.name = "Включить полосу ресурса"
										t.desc = "Мана, ярость, энергия или сила рун под полосой здоровья."
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
										t.name = "Мана в обликах"
										t.desc = "Тонкая полоса маны в облике медведя или кошки."
										t.order = 2
										t.width = "full"
										t.hidden = function() return PLAYER_CLASS ~= "DRUID" end
										return t
									end)(),
								},
							},
							textBox = {
								type = "group",
								name = "Текст на индикаторах",
								order = 3,
								inline = true,
								args = {
									showText = (function()
										local t = Toggle("plate", "showText")
										t.name = "Показывать текст на индикаторах"
										t.desc = "Числа здоровья и ресурса на полосах."
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
										name = "Тип значений",
										order = 2,
										width = "full",
										values = {
											percent = "Проценты",
											value = "Текущее здоровье",
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
										name = "Расположение текста",
										desc = "Где на полосе размещать значения.",
										order = 3,
										width = "full",
										values = {
											left = "Слева",
											center = "По центру",
											right = "Справа",
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
										t.name = "Размер шрифта"
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
								name = "Поддержка UnitFrameLayers",
								order = 4,
								inline = true,
								args = {
									unitFrameLayers = (function()
										local t = Toggle("plate", "unitFrameLayers")
										t.name = "Включить анимацию"
										t.desc = "Предикт лечения, щиты, анимация потери HP и эффекты полосы ресурса (как на стандартном фрейме)."
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
								name = "Цвет полосы здоровья",
								order = 5,
								inline = true,
								args = {
									healthColorMode = {
										type = "select",
										name = "Тип",
										order = 1,
										width = "full",
										values = {
											class = "Цвет класса",
											health = "По проценту здоровья",
											custom = "Свой цвет",
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
										t.name = "Цвет"
										t.desc = "Используется при режиме «Свой цвет»."
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
						name = "Размер и расположение",
						order = 2,
						args = {
							sizeBox = {
								type = "group",
								name = "Размер панели",
								order = 1,
								inline = true,
								suiTwoCol = true,
								args = {
									width = (function()
										local t = Range("plate", "width", 60, 400, 1)
										t.name = "Ширина"
										t.order = 1
										return t
									end)(),
									gap = (function()
										local t = Range("plate", "gap", 0, 20, 1)
										t.name = "Отступ между полосами"
										t.order = 2
										t.disabled = function()
											return Sub("plate").showPower ~= 1
										end
										return t
									end)(),
									healthHeight = (function()
										local t = Range("plate", "healthHeight", 3, 40, 1)
										t.name = "Высота полосы здоровья"
										t.order = 3
										return t
									end)(),
									powerHeight = (function()
										local t = Range("plate", "powerHeight", 2, 40, 1)
										t.name = "Высота полосы ресурса"
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
									name = "Изменить расположение панели игрока",
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
				name = "Индикатор щита",
				order = 3,
				hidden = function() return PLAYER_CLASS ~= "WARRIOR" end,
				disabled = function() return not DB().enabled end,
				args = {
					mainBox = {
						type = "group",
						name = "Индикатор щита",
						order = 1,
						inline = true,
						args = {
							enabled = (function()
								local t = Toggle("shield", "enabled")
								t.name = "Включить"
								t.desc = "Иконка экипированного щита рядом с панелью игрока."
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
								t.name = "Размер иконки"
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
							name = "Изменить расположение индикатора щита",
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
				name = "Руны",
				order = 4,
				hidden = function() return PLAYER_CLASS ~= "DEATHKNIGHT" end,
				disabled = function() return not DB().enabled end,
				args = {
					mainBox = {
						type = "group",
						name = "Руны",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							enabled = (function()
								local t = Toggle("runes", "enabled")
								t.name = "Включить"
								t.desc = "Полосы рун с таймерами. Видимость совпадает с «Отображением» панели игрока."
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
								t.name = "Ширина руны"
								t.order = 2
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							height = (function()
								local t = Range("runes", "height", 4, 40, 1)
								t.name = "Высота руны"
								t.order = 3
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							gap = (function()
								local t = Range("runes", "gap", 0, 12, 1)
								t.name = "Отступ"
								t.order = 4
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							showIcons = (function()
								local t = Toggle("runes", "showIcons")
								t.name = "Иконки рун"
								t.desc = "Символ руны по центру полосы; серый, пока руна восстанавливается."
								t.order = 5
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							readyFlash = (function()
								local t = Toggle("runes", "readyFlash")
								t.name = "Вспышка готовности"
								t.desc = "Короткая вспышка, когда руна готова или становится руной смерти."
								t.order = 6
								t.width = "full"
								t.suiFullRow = true
								t.hidden = function() return Sub("runes").enabled ~= 1 end
								return t
							end)(),
							showTimer = (function()
								local t = Toggle("runes", "showTimer")
								t.name = "Таймер"
								t.desc = "Секунды до готовности руны."
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
								t.name = "Размер шрифта таймера"
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
						name = "Цвета рун",
						order = 2,
						inline = true,
						suiTwoCol = true,
						hidden = function() return Sub("runes").enabled ~= 1 end,
						args = {
							bloodColor = (function()
								local t = Color("runes", "bloodColor")
								t.name = "Кровь"
								t.order = 1
								return t
							end)(),
							unholyColor = (function()
								local t = Color("runes", "unholyColor")
								t.name = "Нечестивость"
								t.order = 2
								return t
							end)(),
							frostColor = (function()
								local t = Color("runes", "frostColor")
								t.name = "Лёд"
								t.order = 3
								return t
							end)(),
							deathColor = (function()
								local t = Color("runes", "deathColor")
								t.name = "Смерть"
								t.desc = "Руны, превращённые в руны смерти."
								t.order = 4
								return t
							end)(),
							emptyColor = (function()
								local t = Color("runes", "emptyColor")
								t.name = "Пустая"
								t.desc = "Руны на перезарядке."
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
							name = "Изменить расположение рун",
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
				name = "Тотемы",
				order = 5,
				hidden = function() return PLAYER_CLASS ~= "SHAMAN" end,
				disabled = function() return not DB().enabled end,
				args = {
					mainBox = {
						type = "group",
						name = "Тотемы",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							enabled = (function()
								local t = Toggle("totems", "enabled")
								t.name = "Включить"
								t.desc = "Иконки тотемов; ПКМ уничтожает тотем. Видимость совпадает с «Отображением» панели игрока."
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
								t.name = "Размер иконки"
								t.order = 2
								t.hidden = function() return Sub("totems").enabled ~= 1 end
								return t
							end)(),
							gap = (function()
								local t = Range("totems", "gap", 0, 12, 1)
								t.name = "Отступ"
								t.order = 3
								t.hidden = function() return Sub("totems").enabled ~= 1 end
								return t
							end)(),
							pulse = (function()
								local t = Toggle("totems", "pulse")
								t.name = "Полоса пульса тотема"
								t.desc = "Полоса над пульсирующими тотемами (Tremor, Earthbind, Cleansing, Magma, Healing Stream, Stoneclaw, Mana Tide) до следующего пульса."
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
								t.name = "Высота полосы пульса"
								t.order = 5
								t.hidden = function()
									return Sub("totems").enabled ~= 1 or Sub("totems").pulse ~= 1
								end
								return t
							end)(),
							pulseColor = (function()
								local t = Color("totems", "pulseColor")
								t.name = "Цвет полосы пульса"
								t.order = 6
								t.hidden = function()
									return Sub("totems").enabled ~= 1 or Sub("totems").pulse ~= 1
								end
								return t
							end)(),
							clickThrough = (function()
								local t = Toggle("totems", "clickThrough")
								t.name = "Клик насквозь"
								t.desc = "Иконки не перехватывают клики мыши."
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
							name = "Изменить расположение тотемов",
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
end
