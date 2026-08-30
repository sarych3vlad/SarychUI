-- SarychUI Tools Module - Options

local moduleName = "tools"
local L = SarychUI.L
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

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

local function IsModuleEnabled()
	return SarychUI and SarychUI.db and SarychUI.db.profile
		and SarychUI.db.profile.modules
		and SarychUI.db.profile.modules.tools
		and SarychUI.db.profile.modules.tools.enabled == true
end

local function Refresh()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

function module:GetOptions()
	return {
		type = "group",
		name = L and (L["Tools"] or "Инструменты и утилиты") or "Инструменты и утилиты",
		desc = L and (L["Tools_Description"] or "Различные инструменты и утилиты") or "Различные инструменты и утилиты",
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = L and (L["General"] or "Общее") or "Общее",
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = "Включить модуль",
						desc = "Включить или выключить модуль",
						order = 1,
						width = "full",
						get = function()
							return IsModuleEnabled()
						end,
						set = function(_, val)
							SarychUI.db.profile.modules.tools.enabled = val and true or false
							if val then
								SarychUI:EnableModule(moduleName)
							else
								SarychUI:DisableModule(moduleName)
							end
						end,
					},
				},
			},

			-- Active tools / interactions
			tools = {
				type = "group",
				name = "Инструменты",
				order = 2,
				disabled = function() return not IsModuleEnabled() end,
				args = {
					focuserBox = {
						type = "group",
						name = "Взять в фокус по Модификатор + Левая кнопка мыши",
						desc = "Настройки установки фокуса на цель",
						order = 1,
						inline = true,
						args = {
							enableFocuser = {
								type = "toggle",
								name = "Включить focuser",
								desc = "Позволяет установить фокус на цель, используя выбранный модификатор + левую кнопку мыши",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableFocuser = val and 1 or 0
									if module and module.ApplyFocuser then module:ApplyFocuser() end
									Refresh()
								end,
							},
							focuserModifierKey = {
								type = "select",
								name = "Клавиша-модификатор",
								desc = "Выберите клавишу-модификатор для Focuser",
								order = 2,
								width = "full",
								values = { [1] = "SHIFT", [2] = "ALT", [3] = "CTRL" },
								get = function()
									local db = DB(); return (db and db.focuserModifierKey) or 2
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.focuserModifierKey = val
									if module and module.ApplyFocuser then module:ApplyFocuser() end
									Refresh()
								end,
								disabled = function() return not isOn("enableFocuser") end,
							},
							enableArenaRightClickFocus = {
								type = "toggle",
								name = "Взять арена фрейм в фокус при помощи |cFFFFD700Правой кнопки мыши|r",
								desc = "Правый клик мыши (ПКМ) по фреймам противников на арене устанавливает их в фокус (без модификатора)",
								order = 3,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableArenaRightClickFocus = val and 1 or 0
									if module and module.ApplyArenaRightClickFocus then
										module:ApplyArenaRightClickFocus()
									end
									Refresh()
								end,
							},
						},
					},

					altAnnounceBox = {
						type = "group",
						name = "Объявления по |cFFFFD700Alt|r + Левая кнопка мыши",
						desc = "Быстрый отчёт статуса в чат: зажмите |cFFFFD700Alt|r и кликните левой кнопкой мыши по способности, полоске HP/MP или ауре — удобно сообщить группе готовность, ресурсы или эффект.",
						order = 2,
						inline = true,
						suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
						args = {
							enableAltCD = {
								type = "toggle",
								name = "Объявлять статус способности",
								desc = "При |cFFFFD700Alt|r + ЛКМ по кнопке способности отправляет в чат статус: готова / перезаряжается / не хватает ресурса. Только клик мышью, не бинды.",
								order = 1,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableAltCD = val and 1 or 0
									if module and module.ApplyAltCD then module:ApplyAltCD() end
									Refresh()
								end,
							},
							enableAltUnitBars = {
								type = "toggle",
								name = "Объявлять здоровье и ману",
								desc = "При |cFFFFD700Alt|r + ЛКМ по полоскам HP/MP игрока, цели и фокуса отправляет в чат текущий процент здоровья или маны. Только клик мышью, не бинды.",
								order = 2,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableAltUnitBars = val and 1 or 0
									if module and module.ApplyAltUnitBars then module:ApplyAltUnitBars() end
									Refresh()
								end,
							},
							enableAltAuras = {
								type = "toggle",
								name = "Объявлять бафы и дебафы",
								desc = "При |cFFFFD700Alt|r + ЛКМ по иконке бафа или дебафа игрока, цели и фокуса отправляет в чат линк заклинания. Только клик мышью, не бинды.",
								order = 3,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableAltAuras = val and 1 or 0
									if module and module.ApplyAltAuras then module:ApplyAltAuras() end
									Refresh()
								end,
							},
						},
					},

					tooltipCursorBox = {
						type = "group",
						name = "Показывать тултип у курсора",
						desc = "Настройки позиции тултипа и мгновенного скрытия",
						order = 3,
						inline = true,
						args = {
							enableTooltipCursor = {
								type = "toggle",
								name = "Включить тултип у курсора",
								desc = "Привязывает тултип к курсору и делает его скрытие мгновенным",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableTooltipCursor = val and 1 or 0
									if module and module.ApplyTooltipCursor then
										module:ApplyTooltipCursor()
									end
									Refresh()
								end,
							},
							tooltipCursorAltOnly = {
								type = "toggle",
								name = "Только при зажатом |cFFFFD700Alt|r",
								desc = "Тултип у курсора работает только при зажатой клавише |cFFFFD700Alt|r",
								order = 2,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.tooltipCursorAltOnly = val and 1 or 0
									if module and module.ApplyTooltipCursor then
										module:ApplyTooltipCursor()
									end
									Refresh()
								end,
								disabled = function() return not isOn("enableTooltipCursor") end,
							},
						},
					},

					lootBox = {
						type = "group",
						name = "Добыча",
						order = 4,
						inline = true,
						suiThreeCol = true,
						args = {
							enableLootReanchor = {
								type = "toggle",
								name = "Перепривязка окон добычи",
								desc = "Если закрыть нижний разыгрываемый предмет, остальные окна сдвинутся вниз, а не останутся висеть в воздухе.",
								order = 1,
								width = "full",
								suiHelpIcon = true,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableLootReanchor = val and 1 or 0
									if module and module.ApplyLootReanchor then
										module:ApplyLootReanchor()
									end
									Refresh()
								end,
							},
							enableLootRollCounts = {
								type = "toggle",
								name = "Показывать счётчики на иконках разролла",
								desc = "На кнопках стандартного окна разролла отображается число игроков, выбравших этот вариант.",
								order = 2,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableLootRollCounts = val and 1 or 0
									if module and module.ApplyLootRollCounts then
										module:ApplyLootRollCounts()
									end
									Refresh()
								end,
							},
							lootRollPreview = {
								type = "description",
								name = " ",
								order = 2.5,
								width = "full",
								suiLootRollPreview = true,
								hidden = function() return not isOn("enableLootRollCounts") end,
							},
							lootRollCountFont = {
								type = "select",
								style = "dropdown",
								name = "Шрифт",
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
								name = "Граница",
								order = 4,
								values = function()
									if SarychUI_FontOutlineValues and SarychUI_FontOutlineValues.GetSelectValues then
										return SarychUI_FontOutlineValues.GetSelectValues(L)
									end
									if AutolosFontFlags and AutolosFontFlags.GetValues then
										return AutolosFontFlags.GetValues(L)
									end
									return {
										NONE = "Без границы",
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
								name = "Размер",
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
					},


					blizzMoveBox = {
						type = "group",
						name = "Перемещение окон Blizzard",
						desc = "Настройки перемещения окон Blizzard",
						order = 5,
						inline = true,
						args = {
							enableBlizzMove = {
								type = "toggle",
								name = "Перемещение окон Blizzard",
								desc = "Делает окна Blizzard перемещаемыми. Перетаскивайте окна для перемещения, используйте Control+колесико мыши для изменения масштаба, Control+клик для включения/выключения сохранения позиции.",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableBlizzMove = val and 1 or 0
									if module and module.ApplyBlizzMove then module:ApplyBlizzMove() end
									Refresh()
								end,
							},
							blizzMoveMouseButton = {
								type = "select",
								name = "Кнопка мыши для перемещения",
								desc = "Выберите кнопку мыши для перемещения окон",
								order = 2,
								width = "full",
								values = {
									LeftButton = "Левая кнопка мыши",
									RightButton = "Правая кнопка мыши",
									MiddleButton = "Средняя кнопка мыши",
								},
								get = function()
									local db = DB(); return (db and db.blizzMoveMouseButton) or "LeftButton"
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.blizzMoveMouseButton = val
									if module and module.ApplyBlizzMove then module:ApplyBlizzMove() end
									Refresh()
								end,
								disabled = function() return not isOn("enableBlizzMove") end,
							},
						},
					},


					quickActionsBox = {
						type = "group",
						name = "Быстрые действия",
						order = 6,
						inline = true,
						args = {
							enableEasyItemDestroy = {
								type = "toggle",
								name = "Лёгкое уничтожение предметов",
								desc = "Если флажок установлен, вам больше не нужно будет вводить слово DELETE при уничтожении редких предметов.|n|nКроме того, ссылки на предметы будут отображаться во всех окнах подтверждения уничтожения предметов.",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableEasyItemDestroy = val and 1 or 0
									if module and module.ApplyEasyItemDestroy then
										module:ApplyEasyItemDestroy()
									end
									Refresh()
								end,
							},
							enableBadgeStackBuyer = {
								type = "toggle",
								name = "|TInterface\\Icons\\Spell_Holy_SummonChampion:14:14:0:0|t Лёгкая покупка эмблем",
								desc = "Shift+ЛКМ по эмблеме у торговца — окно количества. Покупка идёт по 1 шт. за кадр (без фриза).",
								order = 2,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableBadgeStackBuyer = val and 1 or 0
									if module and module.ApplyBadgeStackBuyer then
										module:ApplyBadgeStackBuyer()
									end
									Refresh()
								end,
							},
						},
					},


									},
			},

			-- QoL / UI helpers
			utilities = {
				type = "group",
				name = "Утилиты",
				order = 3,
				disabled = function() return not IsModuleEnabled() end,
				args = {
					interfaceBox = {
						type = "group",
						name = "Интерфейс",
						order = 1,
						inline = true,
						args = {
							enableEscToOk = {
								type = "toggle",
								name = "Заменить |cFFFFD700ESC/Отмена|r на |cFFFFD700ОК|r в окне стандартных настроек",
								desc = "Предотвращает случайное закрытие окон стандартных настроек: |cFFFFD700ESC|r сохраняет изменения, как кнопка |cFFFFD700ОК|r, вместо отмены.",
								order = 1,
								width = "full",
								suiHelpIcon = true,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableEscToOk = val and 1 or 0
									if module and module.ApplyEscToOk then module:ApplyEscToOk() end
									Refresh()
								end,
							},
						},
					},

					questTrackerBox = {
						type = "group",
						name = "Трекер заданий",
						order = 1.5,
						inline = true,
						args = {
							questTrackerStyle = {
								type = "select",
								name = "Внешний вид",
								desc = "Классический — стандартный WatchFrame WotLK.\nDragonflight — шапка и шрифт; положение по умолчанию у WoW, опционально сдвиг как в DragonUI.",
								order = 1,
								width = "full",
								values = {
									classic = "Классический",
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
									if module and module.ApplyQuestTrackerStyle then
										module:ApplyQuestTrackerStyle()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Apply then
										_G.SarychUI_QuestTracker.Apply()
									end
									Refresh()
								end,
							},
							questTrackerShowHeader = {
								type = "toggle",
								name = "Показывать фон шапки",
								desc = "Декоративная текстура шапки трекера (только Dragonflight).",
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
									if module and module.RefreshQuestTracker then
										module:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
								end,
							},
							questTrackerDragonflightPosition = {
								type = "toggle",
								name = "Расположение как в Dragonflight",
								desc = "Сдвигает трекер от стандартной позиции WoW (с учётом боковых панелей) к раскладке DragonUI. Можно донастроить X/Y и свободным перемещением.",
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
									if module and module.RefreshQuestTracker then
										module:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
									Refresh()
								end,
							},
							questTrackerX = {
								type = "range",
								name = "Смещение по X",
								desc = "Горизонталь относительно раскладки Dragonflight (без боковых панелей; панели добавляются автоматически).",
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
									if module and module.RefreshQuestTracker then
										module:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
								end,
							},
							questTrackerY = {
								type = "range",
								name = "Смещение по Y",
								desc = "Вертикаль относительно раскладки Dragonflight.",
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
									if module and module.RefreshQuestTracker then
										module:RefreshQuestTracker()
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
										return "Свободное перемещение |cff00ff00(вкл)|r"
									end
									return "Свободное перемещение"
								end,
								desc = "Показать рамку и окошко для перетаскивания трекера (как у миникарты / фреймов).",
								order = 6,
								width = "full",
								hidden = function()
									local db = DB()
									return not db or db.questTrackerStyle ~= "dragonflight" or db.questTrackerDragonflightPosition == false
								end,
								func = function()
									local db = DB(); if not db then return end
									local val = not (db.questTrackerShowDragFrame == 1)
									db.questTrackerShowDragFrame = val and 1 or 0
									db.questTrackerShowGrid = val and 1 or 0
									if module and module.ApplyQuestTrackerDragMode then
										module:ApplyQuestTrackerDragMode()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.ApplyDragMode then
										_G.SarychUI_QuestTracker.ApplyDragMode()
									end
									local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
									if panel and panel.Toggle then
										panel:Toggle("questTracker", val)
									end
									if module and module.RefreshQuestTracker then
										module:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
									Refresh()
								end,
							},
							questTrackerFontSize = {
								type = "range",
								name = "Размер шрифта",
								desc = "Размер текста трекера заданий (только Dragonflight). По умолчанию 11, как у стандартного UI.",
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
									if module and module.RefreshQuestTracker then
										module:RefreshQuestTracker()
									elseif _G.SarychUI_QuestTracker and _G.SarychUI_QuestTracker.Refresh then
										_G.SarychUI_QuestTracker.Refresh()
									end
								end,
							},
						},
					},

					fpsBox = {
						type = "group",
						name = "FPS",
						desc = "Настройки индикатора FPS при зажатом Alt",
						order = 2,
						inline = true,
						suiTwoCol = true,
						suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
						args = {
							enableAltFPS = {
								type = "toggle",
								name = "Показывать FPS при зажатом |cFFFFD700Alt|r",
								desc = "Показывает FPS в левом верхнем углу при зажатой клавише |cFFFFD700Alt|r",
								order = 1,
								width = "full",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableAltFPS = val and 1 or 0
									if module and module.ApplyAltFPS then module:ApplyAltFPS() end
									Refresh()
								end,
							},
							fpsScale = {
								type = "range",
								name = "Масштаб FPS",
								desc = "Размер FPS-индикатора при зажатом |cFFFFD700Alt|r (0.50 — 2.00)",
								order = 2,
								width = "full",
								suiFullRow = true,
								min = 0.5, max = 2.0, step = 0.05,
								get = function()
									local db = DB()
									return (db and db.fpsScale) or 1.0
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.fpsScale = val
									if module and module.ApplyFpsScale then module:ApplyFpsScale() end
								end,
								disabled = function() return not isOn("enableAltFPS") end,
							},
							fpsExtraOffsetX = {
								type = "range",
								name = "Смещение по X",
								desc = "Дополнительное горизонтальное смещение FPS-индикатора относительно базовой позиции",
								order = 3,
								min = -300, max = 300, step = 1,
								get = function()
									local db = DB()
									return (db and db.fpsExtraOffsetX) or 0
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.fpsExtraOffsetX = val
									if module and module.SetFpsPosition then module:SetFpsPosition() end
								end,
								disabled = function() return not isOn("enableAltFPS") end,
							},
							fpsExtraOffsetY = {
								type = "range",
								name = "Смещение по Y",
								desc = "Дополнительное вертикальное смещение FPS-индикатора относительно базовой позиции",
								order = 4,
								min = -300, max = 300, step = 1,
								get = function()
									local db = DB()
									return (db and db.fpsExtraOffsetY) or 0
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.fpsExtraOffsetY = val
									if module and module.SetFpsPosition then module:SetFpsPosition() end
								end,
								disabled = function() return not isOn("enableAltFPS") end,
							},
						},
					},


					travelBox = {
						type = "group",
						name = "Путешествия и PvP",
						order = 3,
						inline = true,
						args = {
							enableShowFlightTimes = {
								type = "toggle",
								name = "|TInterface\\Minimap\\Tracking\\FlightMaster:17:17:0:0|t Время полётов",
								desc = "Показывает оставшееся время полёта, пока вы в воздухе у распорядителя полётов — сколько ещё лететь до пункта назначения.",
								order = 1,
								width = "full",
								suiHelpIcon = true,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableShowFlightTimes = val and 1 or 0
									if module and module.ApplyShowFlightTimes then
										module:ApplyShowFlightTimes()
									end
									Refresh()
								end,
							},
							enableArenaPointer = {
								type = "toggle",
								name = "|TInterface\\PVPFrame\\PVP-ArenaPoints-Icon:15.4:15.4:0:0|t Показать ожидаемое количество очков арены",
								desc = "Рядом с рейтингом вашей команды в PvP-вкладке показывает, сколько очков арены вы получите при текущем рейтинге.",
								order = 2,
								width = "full",
								suiHelpIcon = true,
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableArenaPointer = val and 1 or 0
									if module and module.ApplyArenaPointer then
										module:ApplyArenaPointer()
									end
									Refresh()
								end,
							},
						},
					},

					darkModeBox = {
						type = "group",
						name = "Затемнение текстур интерфейса (LortiUI)",
						desc = "Настройки затемнения текстур интерфейса Blizzard",
						order = 4,
						inline = true,
						args = {
							enableDarkMode = {
								type = "toggle",
								name = "Затемнение текстур интерфейса",
								desc = "Затемняет текстуры интерфейса Blizzard выбранным цветом",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableDarkMode = val and 1 or 0
									if module and module.ApplyDarkMode then module:ApplyDarkMode() end
									Refresh()
								end,
							},
							darkModeColor = {
								type = "color",
								name = "Цвет текстур",
								desc = "Цвет для затемнения текстур интерфейса",
								order = 2,
								width = "full",
								hasAlpha = true,
								get = function()
									local db = DB()
									if not db or not db.darkModeColor then
										return 0.37, 0.37, 0.37, 1
									end
									return db.darkModeColor.r or 0.37, db.darkModeColor.g or 0.37, db.darkModeColor.b or 0.37, db.darkModeColor.a or 1
								end,
								set = function(_, r, g, b, a)
									local db = DB(); if not db then return end
									db.darkModeColor = db.darkModeColor or {}
									db.darkModeColor.r = r
									db.darkModeColor.g = g
									db.darkModeColor.b = b
									db.darkModeColor.a = a or 1
									if module and module.ApplyDarkMode then module:ApplyDarkMode() end
									Refresh()
								end,
								hidden = function() return not isOn("enableDarkMode") end,
							},
						},
					},

					bossFramesBox = {
						type = "group",
						name = "Фреймы боссов",
						desc = "Исправление залипания стандартных Blizzard Boss1–Boss5 TargetFrame",
						order = 4.5,
						inline = true,
						args = {
							fixBossFrames = {
								type = "toggle",
								name = "Исправлять залипание фреймов боссов",
								desc = "Синхронизирует BossNTargetFrame с UnitExists и надпись «Мертва» с UnitHealth (как TargetFrame_CheckDead). Нужно, когда сервер не шлёт engage/UNIT_HEALTH — в т.ч. боссы, которые воскресают.",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.fixBossFrames = val and 1 or 0
									if module and module.ApplyFixBossFrames then
										module:ApplyFixBossFrames()
									end
									Refresh()
								end,
							},
						},
					},

					chatExtraBox = {
						type = "group",
						name = "Дополнительные функции чата",
						order = 5,
						inline = true,
						args = {
							translitAliasesEnabled = {
								type = "toggle",
								name = L and (L["Enable_Chat_Translit"] or "Включить распознаватель транслита \"/куцдуф\" как \"/reload\"") or "Включить распознаватель транслита |cFFFFD700\"/куцдуф\"|r как |cFFFFD700\"/reload\"|r",
								desc = L and (L["Enable_Chat_Translit_Desc"] or "Включить алиасы команд на транслите (например: /куцдуф -> /reload)") or "Включить алиасы команд на транслите (например: /куцдуф -> /reload)",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.translitAliasesEnabled = val and 1 or 0
									if module and module.ApplyTranslitAliases then
										module:ApplyTranslitAliases()
									end
									Refresh()
								end,
							},
							clearChatSlashEnabled = {
								type = "toggle",
								name = "Команда |cFFFFD700/clear|r для очистки чата",
								desc = "Регистрирует slash-команды |cFFFFD700/clear|r, |cFFFFD700/claer|r (опечатка) и |cFFFFD700/сдуфк|r (те же клавиши в русской раскладке): очищают текст во всех стандартных окнах чата (аналог скрипта с ChatFrame:Clear()).",
								order = 2,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.clearChatSlashEnabled = val and 1 or 0
									if module and module.ApplyClearChatSlash then
										module:ApplyClearChatSlash()
									end
									Refresh()
								end,
							},
						},
					},
				},
			},

			wowcircle = {
				type = "group",
				name = "WoWCircle",
				order = 4,
				disabled = function() return not IsModuleEnabled() end,
				args = {
					wowcircleBox = {
						type = "group",
						name = "Функции WoWCircle",
						order = 1,
						inline = true,
						args = {
							enableCircleContextMenu = {
								type = "toggle",
								name = L and (L["Enable_Chat_Circle_Menu"] or "[WoWCircle] |TInterface\\ChatFrame\\UI-ChatIcon-Chat-Up:14:14|t Дополнительные VIP команды при нажатии ПКМ") or "[WoWCircle] |TInterface\\ChatFrame\\UI-ChatIcon-Chat-Up:14:14|t Дополнительные VIP команды при нажатии ПКМ",
								desc = L and (L["Enable_Chat_Circle_Menu_Desc"] or "Включить дополнительные VIP команды при нажатии правой кнопки мыши") or "Включить дополнительные VIP команды при нажатии правой кнопки мыши",
								order = 1,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.enableCircleContextMenu = val and 1 or 0
									if module and module.ApplyVipCommands then
										module:ApplyVipCommands()
									end
									Refresh()
								end,
							},
							ppMessageFixEnabled = {
								type = "toggle",
								name = L and (L["Enable_PP_Message_Fix"] or "[WoWCircle] Фикс \"|cFFFFD700Обмениваться личными сообщениями можно только с союзниками.|r\" для ПП") or "[WoWCircle] Фикс \"|cFFFFD700Обмениваться личными сообщениями можно только с союзниками.|r\" для ПП",
								desc = L and (L["Enable_PP_Message_Fix_Desc"] or "Включить исправление сообщения \"Обмениваться личными сообщениями можно только с союзниками.\" для ПП") or "Включить исправление сообщения \"Обмениваться личными сообщениями можно только с союзниками.\" для ПП",
								order = 2,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.ppMessageFixEnabled = val and 1 or 0
									if module and module.ApplyPpMessageFix then
										module:ApplyPpMessageFix()
									end
									Refresh()
								end,
							},
							spamFilterCombatDifficulty = {
								type = "toggle",
								name = "[WoWCircle] Скрыть сообщения информации после боя",
								desc = "Скрывать сообщения о сложности боя, времени боя, iLvl и PvE очках после битвы с боссами",
								order = 3,
								width = "full",
								get = toggleGetter,
								set = function(info, val)
									local db = DB(); if not db then return end
									db.spamFilterCombatDifficulty = val and 1 or 0
									if module and module.ApplyWoWCircleSystemFilter then
										module:ApplyWoWCircleSystemFilter()
									end
									Refresh()
								end,
							},
						},
					},
				},
			},
		},
	}
end
