-- SarychUI Map Module Options

local moduleName = "map"
local L = SarychUI.L

local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)

local function DB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile(moduleName)
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules[moduleName]
end

local function RefreshMapOptions()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif ACR then
		ACR:NotifyChange("SarychUI")
	end
end

local function ShowReloadPopup(onCancel, text)
	text = text or (L and L["Map Type Reload"] or "При смене типа карты требуется перезагрузка интерфейса.")
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup(text, onCancel)
		return
	end
	if StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

local function GetMapMode()
	if SarychUI.GetMapMode then
		return SarychUI:GetMapMode()
	end
	local db = DB()
	return db and db.mapType or "sarychui"
end

local function GetMapTypeValues()
	local values = {
		classic = L and (L["Classic WoW Map"] or "Классическая карта WoW") or "Классическая карта WoW",
		sarychui = L and (L["SarychUI Maps"] or "Карта SarychUI") or "Карта SarychUI",
	}
	if SarychUI and SarychUI.IsExternalCarboniteAvailable and SarychUI:IsExternalCarboniteAvailable() then
		values.carbonite = "Carbonite"
	end
	return values
end

local function SetMapType(mapType)
	if mapType == "carbonite" and SarychUI and SarychUI.IsExternalCarboniteAvailable and not SarychUI:IsExternalCarboniteAvailable() then
		return
	end
	if SarychUI.SetMapType then
		SarychUI:SetMapType(mapType)
		return
	end

	local addons = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	local mapDb = DB()
	if not addons or not mapDb then return end

	mapDb.mapType = mapType
	if mapType == "carbonite" then
		addons.Carbonite = addons.Carbonite or {}
		addons.Carbonite.enabled = true
	else
		addons.Carbonite = addons.Carbonite or {}
		addons.Carbonite.enabled = false
	end
end

local function IsModuleEnabled()
	local db = DB()
	return db and db.enabled ~= false
end

local function IsSarychUIMap()
	return IsModuleEnabled() and GetMapMode() == "sarychui"
end

local function OpenMapSettings()
	local mode = GetMapMode()
	if mode == "carbonite" then
		if SarychUI and SarychUI.OpenCarboniteConfig then
			SarychUI:OpenCarboniteConfig()
		elseif _G.Nx and _G.Nx.Opt and _G.Nx.Opt.Ope then
			_G.Nx.Opt:Ope()
		end
		return
	end
	if mode == "sarychui" then
		local OC = SarychUI and SarychUI.OptionsCore
		if OC and OC.SelectTab then
			OC:SelectTab("appearance")
		end
	end
end

local function RefreshNativeMap()
	if SarychUI.Maps and SarychUI.Maps.Refresh then
		SarychUI.Maps:Refresh()
	elseif module.Refresh then
		module:Refresh()
	end
end

function module:GetOptions()
	local title = L and (L["World Map"] or "Карта мира") or "Карта мира"
	return {
		type = "group",
		name = title,
		desc = L and (L["Map Module Desc"] or "Выбор типа карты") or "Выбор типа карты",
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
						desc = L and (L["Map_Enable_Module_Desc"] or "Выключение модуля переключает карту на классическую WoW и требует перезагрузки.") or "Выключение модуля переключает карту на классическую WoW и требует перезагрузки.",
						order = 1,
						width = "full",
						get = function()
							return IsModuleEnabled()
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							local previousEnabled = db.enabled ~= false
							local preferredType = db.mapType or GetMapMode()
							value = value and true or false
							if previousEnabled == value then return end

							db.enabled = value
							if value then
								local restoreType = preferredType
								if restoreType ~= "sarychui" and restoreType ~= "carbonite" and restoreType ~= "classic" then
									restoreType = "sarychui"
								end
								if restoreType == "carbonite"
									and SarychUI and SarychUI.IsExternalCarboniteAvailable
									and not SarychUI:IsExternalCarboniteAvailable() then
									restoreType = "sarychui"
								end
								db.mapType = restoreType
								SetMapType(restoreType)
								if SarychUI.EnableModule then
									SarychUI:EnableModule(moduleName)
								end
								RefreshMapOptions()
								ShowReloadPopup(function()
									db.enabled = false
									SetMapType("classic")
									if SarychUI.DisableModule then
										SarychUI:DisableModule(moduleName)
									end
									RefreshMapOptions()
								end, "Для включения модуля карты требуется перезагрузка интерфейса.")
							else
								db.mapType = preferredType
								SetMapType("classic")
								if SarychUI.DisableModule then
									SarychUI:DisableModule(moduleName)
								end
								RefreshMapOptions()
								ShowReloadPopup(function()
									db.enabled = true
									SetMapType(preferredType)
									if SarychUI.EnableModule then
										SarychUI:EnableModule(moduleName)
									end
									RefreshMapOptions()
								end, "Модуль выключен: будет использована классическая карта WoW.\nДля применения требуется перезагрузка интерфейса.")
							end
						end,
					},
					typeRow = {
						type = "group",
						name = L and (L["Map Type"] or "Тип карты") or "Тип карты",
						order = 10,
						inline = true,
						suiSelectWithButton = true,
						disabled = function()
							return not IsModuleEnabled()
						end,
						args = {
							mapType = {
								type = "select",
								name = "",
								desc = L and (L["Map Type Desc"] or "Выберите, какую карту использовать.") or "Выберите, какую карту использовать.",
								order = 1,
								values = GetMapTypeValues,
								get = function()
									return GetMapMode()
								end,
								set = function(_, value)
									if value == "carbonite"
										and SarychUI and SarychUI.IsExternalCarboniteAvailable
										and not SarychUI:IsExternalCarboniteAvailable() then
										return
									end
									local previous = GetMapMode()
									if value == previous then return end
									SetMapType(value)
									RefreshMapOptions()
									ShowReloadPopup(function()
										SetMapType(previous)
										RefreshMapOptions()
									end)
								end,
							},
							openSettings = {
								type = "execute",
								name = L and (L["Settings"] or "Настройки") or "Настройки",
								desc = function()
									if GetMapMode() == "carbonite" then
										return L and (L["Open Carbonite Settings Desc"] or "Открыть окно настроек Carbonite (/carb options).") or "Открыть окно настроек Carbonite (/carb options)."
									end
									return L and (L["SarychUI Maps Button Desc"] or "Открыть настройки SarychUI -> Карта.") or "Открыть настройки SarychUI -> Карта."
								end,
								order = 2,
								hidden = function()
									local mode = GetMapMode()
									if mode == "sarychui" then
										return not IsSarychUIMap()
									end
									if mode == "carbonite" then
										return not (SarychUI and SarychUI.IsExternalCarboniteAvailable and SarychUI:IsExternalCarboniteAvailable())
									end
									return true
								end,
								func = OpenMapSettings,
							},
						},
					},
					modeHint = {
						type = "description",
						name = "|cFFFFD700Внимание:|r После смены типа карты потребуется перезагрузка интерфейса.",
						order = 30,
						width = "full",
					},
					creditNote = {
						type = "description",
						name = L and L["SarychUI Maps Credit"]
							or "|cFFFFD700Пометка:|r Модуль разработан благодаря предложению |cff1784d1Hannahmckay|r обратить внимание на Leatrix Maps 3.3.5 от 5Buttons.\n\nSarychUI Maps объединяет идеи и возможности Mapster, Leatrix Maps и WDM в единой реализации для SarychUI.",
						order = 31,
						width = "full",
						suiStickyBottom = true,
						hidden = function()
							return GetMapMode() ~= "sarychui"
						end,
					},
				},
			},
			appearance = {
				type = "group",
				name = L and (L["Settings"] or "Настройки") or "Настройки",
				order = 2,
				hidden = function()
					return not IsSarychUIMap()
				end,
				args = {
					panButton = {
						type = "select",
						name = L and (L["Map Pan Button"] or "Перемещение карты") or "Перемещение карты",
						desc = L and (L["Map Pan Button Desc"] or "Кнопка мыши для перемещения увеличенной карты. Колёсико масштабирует независимо.") or "Кнопка мыши для перемещения увеличенной карты. Колёсико масштабирует независимо.",
						order = 1,
						width = "double",
						values = {
							left = L and (L["Left Mouse Button"] or "Левая кнопка мыши") or "Левая кнопка мыши",
							middle = L and (L["Middle Mouse Button"] or "Средняя кнопка мыши") or "Средняя кнопка мыши",
							right = L and (L["Right Mouse Button"] or "Правая кнопка мыши") or "Правая кнопка мыши",
						},
						get = function()
							local db = DB()
							return (db and db.panButton) or "middle"
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.panButton = value
							RefreshNativeMap()
						end,
					},
					panSpeed = {
						type = "range",
						name = L and (L["Map Pan Speed"] or "Чувствительность перемещения") or "Чувствительность перемещения",
						desc = L and (L["Map Pan Speed Desc"] or "Насколько сильно сдвигается карта при перетаскивании с зажатой кнопкой перемещения.") or "Насколько сильно сдвигается карта при перетаскивании с зажатой кнопкой перемещения.",
						order = 2,
						width = "full",
						min = 0.15,
						max = 1.5,
						step = 0.05,
						get = function()
							local db = DB()
							return (db and db.panSpeed) or 0.9
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.panSpeed = value
						end,
					},
					zoneInfo = {
						type = "toggle",
						name = L and (L["Map Zone Info"] or "Информация о зоне") or "Информация о зоне",
						desc = L and (L["Map Zone Info Desc"] or "Рекомендуемый уровень, рыбалка, территория и список подземелий на карте мира.") or "Рекомендуемый уровень, рыбалка, территория и список подземелий на карте мира.",
						order = 3,
						width = "full",
						get = function()
							local db = DB()
							return not db or db.zoneInfo ~= false
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.zoneInfo = value and true or false
							RefreshNativeMap()
						end,
					},
					resetLayout = {
						type = "toggle",
						name = L and (L["Map Reset Layout"] or "Не запоминать положение") or "Не запоминать положение",
						desc = L and (L["Map Reset Layout Desc"] or "Каждое открытие карты сбрасывает положение и масштаб на значения по умолчанию.") or "Каждое открытие карты сбрасывает положение и масштаб на значения по умолчанию.",
						order = 4,
						width = "full",
						get = function()
							local db = DB()
							return db and db.resetLayout == true
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.resetLayout = value and true or false
							if SarychUI.Maps and SarychUI.Maps.worldmap then
								SarychUI.Maps.worldmap:SetScale()
								SarychUI.Maps.worldmap:SetPosition()
							end
							RefreshNativeMap()
						end,
					},
					fadeOnMove = {
						type = "toggle",
						name = L and (L["Map Fade On Move"] or "Прозрачность при движении") or "Прозрачность при движении",
						desc = L and (L["Map Fade On Move Desc"] or "Карта становится прозрачнее, пока персонаж идёт. Наведение мыши возвращает обычную непрозрачность.") or "Карта становится прозрачнее, пока персонаж идёт. Наведение мыши возвращает обычную непрозрачность.",
						order = 5,
						width = "full",
						get = function()
							local db = DB()
							return not db or db.fadeOnMove ~= false
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.fadeOnMove = value and true or false
							RefreshNativeMap()
						end,
					},
					fogStyle = {
						type = "select",
						name = L and (L["Map Fog Style"] or "Стиль тумана") or "Стиль тумана",
						desc = L and (L["Map Fog Style Desc"] or "Цвет неисследованных областей после раскрытия тумана войны.") or "Цвет неисследованных областей после раскрытия тумана войны.",
						order = 6,
						width = "double",
						values = {
							standard = L and (L["Map Fog Style Standard"] or "Стандартный") or "Стандартный",
							leatrix = L and (L["Map Fog Style Leatrix"] or "Стиль тумана Leatrix") or "Стиль тумана Leatrix",
						},
						get = function()
							local db = DB()
							return (db and db.fogStyle) or "leatrix"
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							if value ~= "standard" then
								value = "leatrix"
							end
							db.fogStyle = value
							if value == "standard" then
								db.fogTintR, db.fogTintG, db.fogTintB = 0.623, 0.623, 0.623
							else
								db.fogTintR, db.fogTintG, db.fogTintB = 0.6, 0.6, 1
							end
							RefreshNativeMap()
						end,
					},
					fogTransparency = {
						type = "range",
						name = L and (L["Map Fog Transparency"] or "Прозрачность тумана войны") or "Прозрачность тумана войны",
						desc = L and (L["Map Fog Transparency Desc"] or "Насколько прозрачны неисследованные области после раскрытия тумана войны.") or "Насколько прозрачны неисследованные области после раскрытия тумана войны.",
						order = 7,
						width = "full",
						min = 0,
						max = 1,
						step = 0.05,
						isPercent = true,
						get = function()
							local db = DB()
							local alpha = (db and db.fogTintA) or 1
							return 1 - alpha
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							db.fogTintA = 1 - (value or 0)
							RefreshNativeMap()
						end,
					},
				},
			},
		},
	}
end
