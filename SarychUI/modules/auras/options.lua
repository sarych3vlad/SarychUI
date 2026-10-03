-- SarychUI Auras Module Options

local moduleName = "auras"
local L = SarychUI.L

local module = SarychUI:GetModule(moduleName)
if not module then return end

local function DB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile(moduleName)
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules[moduleName]
end

local function isEnabled()
	local db = DB()
	return db and db.enabled
end

local function isOn(key)
	local db = DB()
	if not db then return false end
	local v = db[key]
	return v == 1 or v == true
end

local function RefreshConfig()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI and SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local function NotifyAurasPreview(key, value)
	local preview = SarychUI and SarychUI.AurasPreview
	if not preview then return end
	if key ~= nil and preview.SetLiveValue then
		preview:SetLiveValue(key, value)
	elseif preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function ApplyBuffs()
	if module and module.ApplyBuffManagement then
		module:ApplyBuffManagement()
	end
end

function module:GetOptions()
	return {
		type = "group",
		name = L and (L["Auras"] or "Ауры") or "Ауры",
		desc = L and (L["Auras_Description"] or "Скрытие аур, подсветка развеивания и управление баффами персонажа") or "Скрытие аур, подсветка развеивания и управление баффами персонажа",
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = L and (L["General"] or "Общее") or "Общее",
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = L and (L["Enable_Module"] or "Включить модуль") or "Включить модуль",
						desc = "Включить или выключить модуль",
						order = 1,
						width = "full",
						get = function()
							local db = DB()
							return db and db.enabled == true
						end,
						set = function(_, val)
							local db = DB()
							if not db then return end
							db.enabled = val and true or false
							if val then
								SarychUI:EnableModule(moduleName)
							else
								SarychUI:DisableModule(moduleName)
							end
						end,
					},
				},
			},

			frameAuras = {
				type = "group",
				name = L and (L["Frame Auras"] or "Ауры фреймов") or "Ауры фреймов",
				order = 2,
				disabled = function() return not isEnabled() end,
				args = {
					preview = {
						type = "description",
						name = "",
						order = 1,
						width = "full",
						suiAurasPreview = true,
					},

					hideAurasBox = {
						type = "group",
						name = "Скрыть ауры",
						order = 2,
						inline = true,
						args = {
							hideTargetAuras = {
								type = "toggle",
								name = "Скрыть ауры |cFFFFD700цели|r",
								desc = "Скрыть ауры на фрейме |cFFFFD700цели|r",
								order = 1,
								width = "full",
								suiPreviewKey = "hideTargetAuras",
								get = function()
									return isOn("hideTargetAuras")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.hideTargetAuras = v and 1 or 0
									if module.RefreshAuraLayout then
										module:RefreshAuraLayout()
									end
									if module.ForceUpdateAuras then
										module:ForceUpdateAuras()
									end
									NotifyAurasPreview("hideTargetAuras", v and 1 or 0)
								end,
							},
							hideFocusAuras = {
								type = "toggle",
								name = "Скрыть ауры |cFFFFD700фокуса|r",
								desc = "Скрыть ауры на фрейме |cFFFFD700фокуса|r",
								order = 2,
								width = "full",
								get = function()
									return isOn("hideFocusAuras")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.hideFocusAuras = v and 1 or 0
									if module.ForceUpdateAuras then
										module:ForceUpdateAuras()
									end
									NotifyAurasPreview("hideFocusAuras", v and 1 or 0)
								end,
							},
							hideTargetOfTargetAuras = {
								type = "toggle",
								name = "Скрыть ауры \"|cFFFFD700цели цели|r\"",
								desc = "Скрыть ауры на фрейме \"|cFFFFD700цели цели|r\"",
								order = 3,
								width = "full",
								get = function()
									return isOn("hideTargetOfTargetAuras")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.hideTargetOfTargetAuras = v and 1 or 0
									if module.ForceUpdateAuras then
										module:ForceUpdateAuras()
									end
									NotifyAurasPreview("hideTargetOfTargetAuras", v and 1 or 0)
								end,
							},
						},
					},

					growUpBox = {
						type = "group",
						name = "Расположить ауры над фреймом",
						order = 2.5,
						inline = true,
						args = {
							frameAurasGrowUp = {
								type = "toggle",
								name = "Включить",
								desc = "Баффы и дебаффы цели и фокуса растут вверх от рамки.",
								order = 1,
								width = "full",
								suiPreviewKey = "frameAurasGrowUp",
								get = function()
									return isOn("frameAurasGrowUp")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.frameAurasGrowUp = v and 1 or 0
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAurasGrowUp", v and 1 or 0)
									RefreshConfig()
								end,
							},
							frameAurasGrowUpY = {
								type = "range",
								name = "Смещение по Y",
								desc = "Вертикальное смещение аур относительно верхнего края рамки.",
								min = -40,
								max = 80,
								step = 1,
								order = 2,
								width = "full",
								suiPreviewKey = "frameAurasGrowUpY",
								hidden = function() return not isOn("frameAurasGrowUp") end,
								get = function()
									local db = DB()
									if not db or db.frameAurasGrowUpY == nil then return -17 end
									return db.frameAurasGrowUpY
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.frameAurasGrowUpY = val
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAurasGrowUpY", val)
								end,
							},
						},
					},

					dispelBox = {
						type = "group",
						name = "Подсветка развеивания",
						order = 3,
						inline = true,
						args = {
							enableDispelHighlight = {
								type = "toggle",
								name = "Подсветка бафов у целей/фокуса которые можно развеять",
								desc = "Выделяет баффы на цели и фокусе, которые можно развеять (магические эффекты)",
								order = 1,
								width = "full",
								get = function()
									return isOn("enableDispelHighlight")
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.enableDispelHighlight = val and 1 or 0
									local toolsModule = SarychUI:GetModule("tools", true)
									if toolsModule and toolsModule.ApplyDispelHighlight then
										toolsModule:ApplyDispelHighlight()
									end
									NotifyAurasPreview("enableDispelHighlight", val and 1 or 0)
								end,
							},
						},
					},

					auraSizeBox = {
						type = "group",
						name = "Изменить размер аур",
						order = 4,
						inline = true,
						args = {
							changeFrameAuraSize = {
								type = "toggle",
								name = "Включить",
								desc = "Включает ползунки размера баффов и дебаффов на рамках цели и фокуса.",
								order = 1,
								width = "full",
								suiPreviewKey = "changeFrameAuraSize",
								get = function()
									return isOn("changeFrameAuraSize")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.changeFrameAuraSize = v and 1 or 0
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("changeFrameAuraSize", v and 1 or 0)
									RefreshConfig()
								end,
							},
							frameAuraOtherSize = {
								type = "range",
								name = "Размер аур цели",
								desc = "Размер баффов и дебаффов на рамках цели и фокуса, которые наложил не вы.",
								min = 15, max = 34, step = 1,
								order = 2,
								width = "full",
								suiPreviewKey = "frameAuraOtherSize",
								hidden = function() return not isOn("changeFrameAuraSize") end,
								get = function()
									local db = DB()
									return db and db.frameAuraOtherSize or 23
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.frameAuraOtherSize = val
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAuraOtherSize", val)
								end,
							},
							frameAuraSelfSize = {
								type = "range",
								name = "Размер своих аур",
								desc = "Размер баффов и дебаффов на рамках цели и фокуса, которые наложили вы (или питомец).",
								min = 15, max = 34, step = 1,
								order = 3,
								width = "full",
								suiPreviewKey = "frameAuraSelfSize",
								hidden = function() return not isOn("changeFrameAuraSize") end,
								get = function()
									local db = DB()
									return db and db.frameAuraSelfSize or 23
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.frameAuraSelfSize = val
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAuraSelfSize", val)
								end,
							},
							frameAuraRowWidth = {
								type = "range",
								name = "Ширина ряда аур",
								desc = "Сколько баффов помещается в одном ряду на рамке цели. Чем больше значение, тем длиннее ряд.",
								min = 108, max = 200, step = 14,
								order = 4,
								width = "full",
								suiPreviewKey = "frameAuraRowWidth",
								hidden = function() return not isOn("changeFrameAuraSize") end,
								get = function()
									local db = DB()
									return db and db.frameAuraRowWidth or 122
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.frameAuraRowWidth = val
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAuraRowWidth", val)
								end,
							},
						},
					},
				},
			},

			characterAuras = {
				type = "group",
				name = L and (L["Character Auras"] or "Ауры персонажа") or "Ауры персонажа",
				order = 3,
				disabled = function() return not isEnabled() end,
				args = {
					buff_management = {
						type = "group",
						name = "Изменить расположение аур персонажа",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							manageBuffs = {
								type = "toggle",
								name = "Включить",
								desc = "Включить изменение позиции и масштаба фрейма баффов персонажа",
								order = 1,
								width = "full",
								suiFullRow = true,
								get = function()
									return isOn("manageBuffs")
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									db.manageBuffs = value and 1 or 0
									if value then
										ApplyBuffs()
									else
										db.showBuffDragFrame = 0
										db.showBuffGrid = 0
										if module.ResetBuffManagement then
											module:ResetBuffManagement()
										end
									end
									RefreshConfig()
								end,
							},
							buffFrameX = {
								type = "range",
								name = "Смещение по X",
								desc = "Горизонтальное смещение фрейма баффов (относительно правого верхнего угла)",
								min = -2000,
								max = 2000,
								step = 1,
								order = 2,
								get = function()
									local db = DB()
									return db and db.buffFrameX or -205
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.buffFrameX = val
									ApplyBuffs()
								end,
								hidden = function()
									return not isOn("manageBuffs")
								end,
							},
							buffFrameY = {
								type = "range",
								name = "Смещение по Y",
								desc = "Вертикальное смещение фрейма баффов (относительно правого верхнего угла)",
								min = -2000,
								max = 2000,
								step = 1,
								order = 3,
								get = function()
									local db = DB()
									return db and db.buffFrameY or -13
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.buffFrameY = val
									ApplyBuffs()
								end,
								hidden = function()
									return not isOn("manageBuffs")
								end,
							},
							buffFrameScale = {
								type = "range",
								name = "Масштаб",
								desc = "Масштаб фрейма баффов",
								min = 0.5,
								max = 2.0,
								step = 0.05,
								order = 4,
								width = "full",
								suiFullRow = true,
								get = function()
									local db = DB()
									return db and db.buffFrameScale or 1.0
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.buffFrameScale = val
									ApplyBuffs()
								end,
								hidden = function()
									return not isOn("manageBuffs")
								end,
							},
							showBuffDragFrame = {
								type = "execute",
								name = function()
									if isOn("showBuffDragFrame") then
										return "Свободное перемещение |cff00ff00(вкл)|r"
									end
									return "Свободное перемещение"
								end,
								desc = "Показать рамку и окошко для перетаскивания фрейма баффов",
								order = 5,
								width = "full",
								suiFullRow = true,
								func = function()
									local db = DB()
									if not db then return end
									local val = not (db.showBuffDragFrame == 1)
									db.showBuffDragFrame = val and 1 or 0
									db.showBuffGrid = val and 1 or 0
									local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
									if panel and panel.Toggle then
										panel:Toggle("buffFrame", val)
									else
										ApplyBuffs()
									end
									RefreshConfig()
								end,
								hidden = function()
									return not isOn("manageBuffs")
								end,
							},
						},
					},
					buffRowBox = {
						type = "group",
						name = "Изменить кол-во аур в ряду",
						order = 2,
						inline = true,
						args = {
							changePlayerBuffRow = {
								type = "toggle",
								name = "Включить",
								desc = "Сколько аур показывать в одном ряду на панели баффов игрока.",
								order = 1,
								width = "full",
								get = function()
									return isOn("changePlayerBuffRow")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.changePlayerBuffRow = v and 1 or 0
									if module.ApplySettings then
										module:ApplySettings()
									end
									RefreshConfig()
								end,
							},
							playerBuffsPerRow = {
								type = "range",
								name = "Аур в ряду",
								desc = "Сколько аур показывать в одном ряду на панели баффов игрока.",
								min = 1, max = 10, step = 1,
								order = 2,
								width = "full",
								hidden = function() return not isOn("changePlayerBuffRow") end,
								get = function()
									local db = DB()
									return db and db.playerBuffsPerRow or 8
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.playerBuffsPerRow = val
									if module.ApplySettings then
										module:ApplySettings()
									end
								end,
							},
						},
					},
					poisonIconsBox = {
						type = "group",
						name = L and (L["Poison Icons"] or "Иконки ядов вместо оружия") or "Иконки ядов вместо оружия",
						desc = L and (L["Added by suggestion: Hannahmckay"] or "Добавлено по предложению: Hannahmckay") or "Добавлено по предложению: Hannahmckay",
						order = 3,
						inline = true,
						suiHelpIcon = true,
						args = {
							showPoisonIcons = {
								type = "toggle",
								name = L and (L["Enable"] or "Включить") or "Включить",
								desc = L and (L["Poison Icons Desc"] or "Для разбойника показывать иконку нанесённого яда вместо иконки оружия среди временных эффектов.") or "Для разбойника показывать иконку нанесённого яда вместо иконки оружия среди временных эффектов.",
								order = 1,
								width = "full",
								get = function()
									return isOn("showPoisonIcons")
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									db.showPoisonIcons = value and 1 or 0
									if module.ApplyPoisonIcons then
										module:ApplyPoisonIcons()
									end
									RefreshConfig()
								end,
							},
						},
					},
				},
			},
		},
	}
end
