-- SarychUI Automation Module - Options

local moduleName = "automation"
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

-- SarychUI сумка already has vendor greys; this block is only for classic / Baud Bag.
local function IsSarychUIBagsMode()
	local bags = SarychUI and SarychUI.modules and SarychUI.modules.bags
	return bags and bags.IsElvUIMode and bags:IsElvUIMode() and true or false
end

local function toggleGetter(info)
	local db = DB(); if not db then return false end
	local key = info[#info]
	local v = db[key]
	return v == 1 or v == true
end

local function toggleSetter(info, val)
	local db = DB(); if not db then return end
	local key = info[#info]
	db[key] = val and 1 or 0
	if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
end

function module:GetOptions()
	return {
		type = "group",
		name = "Автоматизация",
		desc = L and (L["Automation_Description"] or "Автоматизация различных игровых действий") or "Автоматизация различных игровых действий",
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = L["General"] or "Общее",
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = "Включить модуль",
						desc = "Включить или выключить модуль",
						order = 1,
						width = "full",
						get = function()
							return SarychUI.db.profile.modules.automation.enabled == true
						end,
						set = function(_, val)
							SarychUI.db.profile.modules.automation.enabled = val and true or false
							if val then SarychUI:EnableModule(moduleName) else SarychUI:DisableModule(moduleName) end
						end,
					},
				autoSellGreyBox = {
					type = "group",
					name = "Автопродажа серых предметов",
					order = 10,
					inline = true,
					hidden = IsSarychUIBagsMode,
					args = {
						enableAutoSellGrey = {
							type = "toggle",
							name = "Автопродажа серых предметов",
							desc = "При разговоре с торговцем автоматически продавать серые предметы",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = toggleSetter,
						},
						enableAutoSellGreyRequireKey = {
							type = "toggle",
							name = "Требовать клавишу-модификатор",
							order = 2,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.enableAutoSellGreyRequireKey = val and 1 or 0
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableAutoSellGrey") end,
						},
						autoSellGreyKey = {
							type = "select",
							name = "Клавиша-модификатор",
							order = 3,
							width = "full",
							values = { [1] = "SHIFT", [2] = "ALT", [3] = "CONTROL" },
							get = function()
								local db = DB(); return (db and db.autoSellGreyKey) or 1
							end,
							set = function(_, val)
								local db = DB(); if not db then return end
								db.autoSellGreyKey = val
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableAutoSellGrey") or not isOn("enableAutoSellGreyRequireKey") end,
						},
					},
				},
				autoReleasePvPBox = {
					type = "group",
					name = "|TInterface\\CURSOR\\PVP:15.3:15.3:0:0|t Покидание тела в PVP",
					desc = "Настройки автоматического покидания тела после смерти в PVP",
					order = 20,
					inline = true,
					args = {
						enableAutoReleasePvP = {
							type = "toggle",
							name = "Покидание тела в PVP",
							desc = "Если флажок установлен, то вы будете автоматически покидать тело после смерти на поле битвы.\n\nОднако, вы не возродитесь автоматически, если у вас есть возможность самовоскрешения (камень души, реинкарнация и т. д.).",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = toggleSetter,
						},
					},
				},
				autoRepairGearBox = {
					type = "group",
					name = "|TInterface\\CURSOR\\REPAIRNPC:15.3:15.3:0:0|t Ремонт снаряжения",
					desc = "Настройки автоматического ремонта снаряжения",
					order = 30,
					inline = true,
					args = {
						enableAutoRepairGear = {
							type = "toggle",
							name = "Ремонт снаряжения",
							desc = "Если флажок установлен, то ваше снаряжение будет починено автоматически, когда вы поговорите с подходящим торговцем",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = toggleSetter,
						},
						autoRepairGearRequireKey = {
							type = "toggle",
							name = "Требовать клавишу-модификатор",
							desc = "Если флажок установлен, то для ремонта нужно будет удерживать клавишу-модификатор.|n|nЕсли флажок снят, ремонт работает автоматически, но удерживание клавиши-модификатора запретит ремонт",
							order = 2,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.autoRepairGearRequireKey = val and 1 or 0
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableAutoRepairGear") end,
						},
						autoRepairGearKey = {
							type = "select",
							name = "Клавиша-модификатор",
							desc = "Выберите клавишу-модификатор для ремонта",
							order = 3,
							width = "full",
							values = { [1] = "SHIFT", [2] = "ALT", [3] = "CONTROL" },
							get = function()
								local db = DB(); return (db and db.autoRepairGearKey) or 1
							end,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.autoRepairGearKey = val
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableAutoRepairGear") or not isOn("autoRepairGearRequireKey") end,
						},
					},
				},
				questAutomationBox = {
					type = "group",
					name = "|TInterface\\GossipFrame\\AvailableQuestIcon:14:14:0:0|t Автоматизация квестов",
					desc = "Настройки автоматического приема и сдачи квестов",
					order = 40,
					inline = true,
					args = {
						enableQuestAutomation = {
							type = "toggle",
							name = "Автоматизация квестов",
							desc = "Включить автоматизацию квестов",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.enableQuestAutomation = val and 1 or 0
								if module and module.ApplyQuestAutomation then
									module:ApplyQuestAutomation()
								end
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
						},
						autoQuestAvailable = {
							type = "toggle",
							name = "Принимать доступные квесты автоматически",
							desc = "Если установлен этот флажок, доступные для вас квесты будут приниматься автоматически",
							order = 2,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.autoQuestAvailable = val and 1 or 0
								if module and module.ApplyQuestAutomation then
									module:ApplyQuestAutomation()
								end
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableQuestAutomation") end,
						},
						autoQuestCompleted = {
							type = "toggle",
							name = "Сдавать выполненные квесты автоматически",
							desc = "Если установлен этот флажок, выполненные квесты будут сдаваться автоматически|n|nЗадания требующие от вас отдать некоторое количество золотых монет - не будут сдаваться автоматически!",
							order = 3,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.autoQuestCompleted = val and 1 or 0
								if module and module.ApplyQuestAutomation then
									module:ApplyQuestAutomation()
								end
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableQuestAutomation") end,
						},
						autoQuestRequireKey = {
							type = "toggle",
							name = "Требовать клавишу-модификатор для автоматизации",
							desc = "Если флажок установлен, то для автоматизации сдачи и/или принятия квестов вам нужно будет удерживать клавишу-модификатор.|n|nЕсли флажок снят, удерживание клавиши-модификатора запретит автоматизацию квестов",
							order = 4,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.autoQuestRequireKey = val and 1 or 0
								if module and module.ApplyQuestAutomation then
									module:ApplyQuestAutomation()
								end
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableQuestAutomation") end,
						},
						autoQuestKey = {
							type = "select",
							name = "Клавиша-модификатор",
							desc = "Выберите клавишу-модификатор для автоматизации квестов",
							order = 5,
							width = "full",
							values = { [1] = "SHIFT", [2] = "ALT", [3] = "CONTROL" },
							get = function()
								local db = DB(); return (db and db.autoQuestKey) or 1
							end,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.autoQuestKey = val
								if module and module.ApplyQuestAutomation then
									module:ApplyQuestAutomation()
								end
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableQuestAutomation") or not isOn("autoQuestRequireKey") end,
						},
					},
				},
				autoTrainAllBox = {
					type = "group",
					name = "|TInterface\\GossipFrame\\TrainerGossipIcon:14:14:0:0|t Автоматическое изучение всех способностей",
					desc = "Настройки автоматического обучения всех доступных способностей у тренера",
					order = 50,
					inline = true,
					args = {
						enableAutoTrainAll = {
							type = "toggle",
							name = "Автоматическое изучение всех способностей",
							desc = "Включить автоматическое обучение всех доступных способностей у тренера при зажатии клавиши-модификатора",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.enableAutoTrainAll = val and 1 or 0
								if module and module.ApplyAutoTrainAll then
									module:ApplyAutoTrainAll()
								end
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
						},
						autoTrainAllKey = {
							type = "select",
							name = "Клавиша-модификатор",
							desc = "Выберите клавишу-модификатор для автоматического обучения (когда зажата и открыто окно тренера)",
							order = 2,
							width = "full",
							values = { [1] = "SHIFT", [2] = "ALT", [3] = "CONTROL" },
							get = function()
								local db = DB(); return (db and db.autoTrainAllKey) or 1
							end,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.autoTrainAllKey = val
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return not isOn("enableAutoTrainAll") end,
						},
					},
				},
				autoScreenshotBox = {
					type = "group",
					name = "|TInterface\\CURSOR\\Directions:14:14:0:0|t Автоскриншоты по достижениям",
					desc = "Настройки автоматических скриншотов при получении достижений",
					order = 60,
					inline = true,
					args = {
						enableAutoScreenshot = {
							type = "toggle",
							name = "Автоскриншоты по достижениям",
							desc = "Если установлен этот флажок, скриншот будет автоматически сделан при получении достижения (с задержкой 1 секунда)",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.enableAutoScreenshot = val and 1 or 0
								if module and module.ApplyAutoScreenshot then
									module:ApplyAutoScreenshot()
								end
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
						},
					},
				},
				},
			},
		},
	}
end
