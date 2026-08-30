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
							hideFocusAuras = {
								type = "toggle",
								name = "Скрыть ауры |cFFFFD700фокуса|r",
								desc = "Скрыть ауры на фрейме |cFFFFD700фокуса|r",
								order = 1,
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
								order = 2,
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
				},
			},
		},
	}
end
