-- Native aura_tracking ownership; legacy storage keys remain stable.
local owner = SarychUI.modules.aura_tracking

local ADDON_NAME = "pw_lossofcontrol"

local function GetAddonDB(create)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return nil end
	local profile = SarychUI.db.profile
	if create then
		profile.addons = profile.addons or {}
		profile.addons[ADDON_NAME] = profile.addons[ADDON_NAME] or {}
	end
	return profile.addons and profile.addons[ADDON_NAME]
end

local function GetOption(key, default)
	local db = GetAddonDB(false)
	if db and db[key] ~= nil then return db[key] end
	return default
end

local function SetOption(key, value)
	local db = GetAddonDB(true)
	if not db then return end
	db[key] = value
	if LossOfControlFrame_RefreshOptions then
		LossOfControlFrame_RefreshOptions()
	end
end

local function RunLossOfControlCommand(command)
	local handler = SlashCmdList and SlashCmdList[command]
	if handler then
		handler("")
	end
end

function owner:Ispw_lossofcontrolEnabled()
    local profile = SarychUI.db and SarychUI.db.profile
    local cfg = profile and profile.addons and profile.addons.pw_lossofcontrol
    return cfg and cfg.enabled ~= false or false
end

function owner:Ispw_lossofcontrolRunning()
    return self.pw_lossofcontrolRunning == true
end

function owner:Setpw_lossofcontrolEnabled(enable)
    local profile = SarychUI.db.profile
    profile.addons.pw_lossofcontrol = profile.addons.pw_lossofcontrol or {}
    profile.addons.pw_lossofcontrol.enabled = enable and true or false
    return self:Applypw_lossofcontrol()
end

function owner:Applypw_lossofcontrol(forceOff)
    local cfg = SarychUI.db.profile.modules.aura_tracking
    local enable = not forceOff and (not cfg or cfg.enabled ~= false) and self:Ispw_lossofcontrolEnabled()
    pw_lossofcontrolEnabled = enable and true or false
    local running = false
    if LossOfControlFrame_SetRuntimeEnabled then LossOfControlFrame_SetRuntimeEnabled(enable) end
    if not enable and LossOfControlFrame_SetTestMode then LossOfControlFrame_SetTestMode(false) end
    if LossOfControlFrame_RefreshOptions then LossOfControlFrame_RefreshOptions() end
    if not enable and LossOfControlFrame then LossOfControlFrame:Hide() end
    running = enable and LossOfControlFrame ~= nil
    self.pw_lossofcontrolRunning = running and true or false
    return self.pw_lossofcontrolRunning
end

function owner:Getpw_lossofcontrolOptions()
	return {
		type = "group",
		name = "pw_lossofcontrol",
		order = 2,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить pw_lossofcontrol",
				order = 1,
				get = function()
					return owner:Ispw_lossofcontrolEnabled()
				end,
				set = function(_, value)
					owner:Setpw_lossofcontrolEnabled(value)
				end,
			},
			description = {
				type = "description",
				name = "Отображение длительности эффектов контроля (Loss of Control) на экране.",
				order = 2,
				width = "full",
			},
			position = {
				type = "group",
				name = "Положение и масштаб",
				order = 3,
				inline = true,
				suiTwoCol = true,
				disabled = function() return not owner:Ispw_lossofcontrolEnabled() end,
				args = {
					unlock = {
						type = "execute",
						name = "Настроить положение",
						desc = "Включить перемещение индикатора. Масштаб также можно менять колесом мыши.",
						order = 1,
						width = "half",
						func = function() RunLossOfControlCommand("LOC") end,
					},
					reset = {
						type = "execute",
						name = "Сбросить положение",
						desc = "Вернуть стандартные положение и масштаб индикатора.",
						order = 2,
						width = "half",
						func = function() RunLossOfControlCommand("LOC1") end,
					},
					positionX = {
						type = "range",
						name = "Позиция по X",
						desc = "Горизонтальное смещение индикатора относительно центра экрана.",
						order = 3,
						min = -1000,
						max = 1000,
						step = 1,
						get = function()
							return LossOfControlFrame_GetPositionOffset and LossOfControlFrame_GetPositionOffset("x") or GetOption("positionX", 0)
						end,
						set = function(_, value) SetOption("positionX", value) end,
					},
					positionY = {
						type = "range",
						name = "Позиция по Y",
						desc = "Вертикальное смещение индикатора относительно центра экрана.",
						order = 4,
						min = -1000,
						max = 1000,
						step = 1,
						get = function()
							return LossOfControlFrame_GetPositionOffset and LossOfControlFrame_GetPositionOffset("y") or GetOption("positionY", -16)
						end,
						set = function(_, value) SetOption("positionY", value) end,
					},
					scale = {
						type = "range",
						name = "Масштаб",
						desc = "Изменить размер индикатора потери контроля.",
						order = 5,
						min = 0.5,
						max = 2,
						step = 0.05,
						isPercent = true,
						width = "full",
						suiFullRow = true,
						get = function() return GetOption("scale", 0.95) end,
						set = function(_, value) SetOption("scale", value) end,
					},
				},
			},
			lineStyle = {
				type = "select",
				name = "Стиль оформления",
				desc = "Оформление индикатора. «Нет» убирает красные полосы и фон.",
				order = 4,
				disabled = function() return not owner:Ispw_lossofcontrolEnabled() end,
				values = {
					default = "Обычный",
					thin = "Потоньше",
					none = "Нет",
				},
				get = function() return GetOption("lineStyle", "thin") end,
				set = function(_, value) SetOption("lineStyle", value) end,
			},
			displayMode = {
				type = "select",
				name = "Режим отображения",
				desc = "Показывать только самый приоритетный эффект или все выбранные эффекты одновременно.",
				order = 5,
				disabled = function() return not owner:Ispw_lossofcontrolEnabled() end,
				values = {
					single = "Одна приоритетная иконка",
					multiple = "Несколько иконок сразу",
				},
				get = function() return GetOption("displayMode", "multiple") end,
				set = function(_, value)
					SetOption("displayMode", value)
					if SarychUI and SarychUI.NotifySarychUIOptionsChange then
						SarychUI:NotifySarychUIOptionsChange()
					end
				end,
			},
			test = {
				type = "execute",
				name = function()
					return LossOfControlFrame_IsTestActive and LossOfControlFrame_IsTestActive()
						and "Остановить тест" or "Показать тест"
				end,
				desc = "Показать тестовые эффекты с учётом выбранного режима и фильтров.",
				order = 7,
				width = "full",
				disabled = function() return not owner:Ispw_lossofcontrolEnabled() end,
				func = function()
					RunLossOfControlCommand("LOCTEST")
					if SarychUI and SarychUI.NotifySarychUIOptionsChange then
						SarychUI:NotifySarychUIOptionsChange()
					end
				end,
			},
			textSizes = {
				type = "group",
				name = "Размер текста",
				order = 6,
				inline = true,
				suiTwoCol = true,
				disabled = function() return not owner:Ispw_lossofcontrolEnabled() end,
				args = {
					nameFontSize = {
						type = "range",
						name = "Название",
						desc = "Размер названия эффекта, когда показана одна иконка.",
						order = 1,
						min = 8,
						max = 40,
						step = 1,
						get = function()
							return LossOfControlFrame_GetNameFontSize and LossOfControlFrame_GetNameFontSize() or 20
						end,
						set = function(_, value) SetOption("nameFontSize", value) end,
					},
					timerFontSize = {
						type = "range",
						name = "Таймер",
						desc = "Размер таймера и подписи секунд, когда показана одна иконка.",
						order = 2,
						min = 8,
						max = 40,
						step = 1,
						get = function()
							return LossOfControlFrame_GetTimerFontSize and LossOfControlFrame_GetTimerFontSize() or 20
						end,
						set = function(_, value) SetOption("timerFontSize", value) end,
					},
				},
			},
			filters = {
				type = "group",
				name = "Иконки в режиме нескольких эффектов",
				order = 8,
				inline = true,
				suiTwoCol = true,
				disabled = function() return not owner:Ispw_lossofcontrolEnabled() end,
				hidden = function() return GetOption("displayMode", "multiple") ~= "multiple" end,
				args = {
					info = {
						type = "description",
						name = "Если активен только один выбранный эффект, он показывается с названием и таймером. При нескольких эффектах остаётся компактный ряд иконок.",
						order = 1,
						width = "full",
						suiFullRow = true,
					},
					showStuns = {
						type = "toggle", name = "Оглушения", order = 2,
						get = function() return GetOption("showStuns", true) end,
						set = function(_, value) SetOption("showStuns", value and true or false) end,
					},
					showSilences = {
						type = "toggle", name = "Немота", order = 3,
						get = function() return GetOption("showSilences", true) end,
						set = function(_, value) SetOption("showSilences", value and true or false) end,
					},
					showDisarms = {
						type = "toggle", name = "Обезоруживание", order = 4,
						get = function() return GetOption("showDisarms", true) end,
						set = function(_, value) SetOption("showDisarms", value and true or false) end,
					},
					showRoots = {
						type = "toggle", name = "Обездвиживание", order = 5,
						get = function() return GetOption("showRoots", true) end,
						set = function(_, value) SetOption("showRoots", value and true or false) end,
					},
					showOtherControl = {
						type = "toggle", name = "Остальной контроль", order = 6,
						get = function() return GetOption("showOtherControl", true) end,
						set = function(_, value) SetOption("showOtherControl", value and true or false) end,
					},
				},
			},
			author = {
				type = "description",
				name = "\nАвтор оригинальной версии:  " .. ("s0hight" or "Неизвестен"),
				order = 9,
				width = "full",
			},
		},
	}
end
