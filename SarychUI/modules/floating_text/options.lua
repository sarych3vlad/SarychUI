-- SarychUI Floating Text Filter module options

local moduleName = "floating_text"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local function DB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile(moduleName)
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules[moduleName]
end

local function Tools()
	return SarychUI and SarychUI.modules and SarychUI.modules.tools
end

local function isOn(key)
	local db = DB()
	if not db then return false end
	local v = db[key]
	return v == 1 or v == true
end

local function toggleGetter(info)
	local db = DB()
	if not db then return false end
	local key = info[#info]
	local v = db[key]
	return v == 1 or v == true
end

local function numberGetter(info)
	local db = DB()
	if not db then return 0 end
	return db[info[#info]] or 0
end

local function IsModuleEnabled()
	local db = DB()
	return db and db.enabled ~= false
end

local function ApplyError()
	local tools = Tools()
	if tools and tools.ApplyErrorFilter then
		tools:ApplyErrorFilter()
	end
end

local function ApplyErrorSettings()
	local tools = Tools()
	if tools and tools.UpdateErrorFilterSettings then
		tools:UpdateErrorFilterSettings()
	end
end

local function ApplyCombat()
	local tools = Tools()
	if tools and tools.ApplyCombatTextAdjust then
		tools:ApplyCombatTextAdjust()
	end
end

local function ApplyBoss()
	local tools = Tools()
	if tools and tools.ApplyRaidBossEmoteReposition then
		tools:ApplyRaidBossEmoteReposition()
	end
end

local function RepositionBoss()
	local tools = Tools()
	if tools and tools.RepositionRaidBossEmoteFrame then
		tools:RepositionRaidBossEmoteFrame()
	end
end

local function ToggleDrag(frameId, enabled)
	local tools = Tools()
	if tools and tools.ToggleCombatTextDrag then
		tools:ToggleCombatTextDrag(frameId, enabled)
	end
end

local function RefreshConfig()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI and SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local function NotifyCombatPreview(key, value, clear)
	local preview = SarychUI and SarychUI.CombatTextPreview
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

local function SplitPatterns(text)
	local patterns = {}
	if type(text) ~= "string" then return patterns end
	for token in string.gmatch(text, "[^;]+") do
		token = token:gsub("^%s+", ""):gsub("%s+$", "")
		if token ~= "" then
			table.insert(patterns, token)
		end
	end
	return patterns
end

local function JoinPatterns(list)
	if type(list) ~= "table" or #list == 0 then return "" end
	return table.concat(list, ";")
end

local function GetPatternList(key, defaultText)
	local db = DB()
	if not db then return SplitPatterns(defaultText or "") end
	local raw = db[key]
	if raw == nil then raw = defaultText or "" end
	return SplitPatterns(raw)
end

local function SetPatternList(key, list)
	local db = DB()
	if not db then return end
	db[key] = JoinPatterns(list)
end

local function AddPattern(key, defaultText, value)
	value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("Введите текст исключения.")
		end
		return false
	end
	local list = GetPatternList(key, defaultText)
	for _, existing in ipairs(list) do
		if existing == value then
			if SarychUI and SarychUI.Print then
				SarychUI:Print("Такое исключение уже есть в списке.")
			end
			return false
		end
	end
	table.insert(list, value)
	SetPatternList(key, list)
	return true
end

local function RemovePattern(key, defaultText, value)
	local list = GetPatternList(key, defaultText)
	local nextList = {}
	for _, existing in ipairs(list) do
		if existing ~= value then
			table.insert(nextList, existing)
		end
	end
	SetPatternList(key, nextList)
end

local pendingHidePatternInput = ""
local pendingExceptionPatternInput = ""

local DEFAULT_HIDE_PATTERNS = "Способность пока недоступна."
local DEFAULT_EXCEPTION_PATTERNS = "Вы должны подождать;Нет места."

local function BuildPatternListArgs(key, defaultText, pendingGet, pendingSet, orderStart)
	local args = {
		addHeader = {
			type = "header",
			name = "Добавить исключение",
			order = orderStart or 10,
		},
		addInput = {
			type = "input",
			name = "",
			desc = "Текст сообщения (или его часть), который нужно добавить в список",
			order = (orderStart or 10) + 1,
			width = "full",
			suiSaveButton = "Добавить",
			get = pendingGet,
			set = function(_, val)
				pendingSet(val)
				if AddPattern(key, defaultText, val) then
					pendingSet("")
					ApplyErrorSettings()
					RefreshConfig()
				end
			end,
		},
	}

	local list = GetPatternList(key, defaultText)
	for i, pattern in ipairs(list) do
		local captured = pattern
		args["patternRow_" .. i] = {
			type = "group",
			inline = true,
			name = "",
			order = (orderStart or 10) + 10 + i,
			suiCompactListRow = true,
			args = {
				label = {
					type = "description",
					name = "|cffff1a1a" .. captured .. "|r",
					order = 1,
				},
				removeBtn = {
					type = "execute",
					name = "Удалить",
					order = 2,
					func = function()
						RemovePattern(key, defaultText, captured)
						ApplyErrorSettings()
						RefreshConfig()
					end,
				},
			},
		}
	end

	return args
end

function module:GetOptions()
	return {
		type = "group",
		name = "Всплывающий текст",
		desc = "Фильтрация системных сообщений, настройка текста боя и игровых уведомлений",
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = "Общее",
				order = 1,
				childGroups = "tab",
				args = {
					enabled = {
						type = "toggle",
						name = "Включить модуль",
						desc = "Включить или выключить модуль",
						order = 0,
						width = "full",
						get = function()
							return IsModuleEnabled()
						end,
						set = function(_, val)
							local db = DB()
							if not db then return end
							db.enabled = val and true or false
							if val then
								if SarychUI.EnableModule then
									SarychUI:EnableModule(moduleName)
								end
							else
								if SarychUI.DisableModule then
									SarychUI:DisableModule(moduleName)
								end
							end
							RefreshConfig()
						end,
					},
					errors = {
						type = "group",
						name = "Фильтр ошибок",
						order = 1,
						args = {
							filterBox = {
								type = "group",
								name = "Фильтр ошибок",
								order = 0,
								inline = true,
								args = {
									enableErrorFilter = {
										type = "toggle",
										name = "Включить скрытие",
										desc = "Включает перехват системных ошибок: списки скрытия/исключений, тайминги и дополнительный фрейм. Без этого остальные настройки фильтра не работают.",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.enableErrorFilter = val and 1 or 0
											ApplyError()
											RefreshConfig()
										end,
									},
									errorShowOriginalOnAlt = {
										type = "toggle",
										name = "Показывать оригинальные ошибки только при |cFFFFD700Alt|r",
										desc = "Оригинальные ошибки будут видны только при зажатой клавише |cFFFFD700Alt|r",
										order = 2,
										width = "full",
										suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
										disabled = function()
											return not isOn("enableErrorFilter")
										end,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorShowOriginalOnAlt = val and 1 or 0
											ApplyErrorSettings()
											RefreshConfig()
										end,
									},
								},
							},

							preview = {
								type = "description",
								name = "",
								order = 1,
								width = "full",
								suiErrorFilterPreview = true,
							},

							timingBox = {
							type = "group",
							name = "Настройки отображения",
							order = 2,
							inline = true,
							disabled = function()
								return not isOn("enableErrorFilter")
							end,
							args = {
								errorTimeVisible = {
									type = "range",
									name = "Время видимости",
									desc = "Время отображения сообщения перед началом исчезновения (в секундах)",
									min = 0,
									max = 10,
									step = 0.1,
									order = 1,
									width = "full",
									suiPreviewKey = "errorTimeVisible",
									get = numberGetter,
									set = function(info, val)
										local db = DB()
										if not db then return end
										db.errorTimeVisible = val
										ApplyErrorSettings()
										if SarychUI.ErrorFilterPreview then
											if SarychUI.ErrorFilterPreview.ClearLiveValue then
												SarychUI.ErrorFilterPreview:ClearLiveValue("errorTimeVisible")
											end
											if SarychUI.ErrorFilterPreview.RefreshAll then
												SarychUI.ErrorFilterPreview:RefreshAll()
											end
										end
										-- No RefreshConfig: full rebuild leaves cooltip backdrop ghosts while typing.
									end,
								},
								errorFadeDuration = {
									type = "range",
									name = "Плавность",
									desc = "Длительность анимации исчезновения сообщения (в секундах)",
									min = 0,
									max = 10,
									step = 0.1,
									order = 2,
									width = "full",
									suiPreviewKey = "errorFadeDuration",
									get = numberGetter,
									set = function(info, val)
										local db = DB()
										if not db then return end
										db.errorFadeDuration = val
										ApplyErrorSettings()
										if SarychUI.ErrorFilterPreview then
											if SarychUI.ErrorFilterPreview.ClearLiveValue then
												SarychUI.ErrorFilterPreview:ClearLiveValue("errorFadeDuration")
											end
											if SarychUI.ErrorFilterPreview.RefreshAll then
												SarychUI.ErrorFilterPreview:RefreshAll()
											end
										end
									end,
								},
								errorThrottleWindow = {
									type = "range",
									name = "Антиспам окно",
									desc = "Временное окно для предотвращения повторного отображения одинаковых сообщений (в секундах)",
									min = 0,
									max = 5,
									step = 0.1,
									order = 3,
									width = "full",
									suiPreviewKey = "errorThrottleWindow",
									get = numberGetter,
									set = function(info, val)
										local db = DB()
										if not db then return end
										db.errorThrottleWindow = val
										if SarychUI.ErrorFilterPreview then
											if SarychUI.ErrorFilterPreview.ClearLiveValue then
												SarychUI.ErrorFilterPreview:ClearLiveValue("errorThrottleWindow")
											end
											if SarychUI.ErrorFilterPreview.RefreshAll then
												SarychUI.ErrorFilterPreview:RefreshAll()
											end
										end
									end,
								},
							},
						},

						hideBox = {
							type = "group",
							name = "Скрывать всегда",
							desc = "Сообщения из этого списка не показываются даже при зажатом |cFFFFD700Alt|r.",
							order = 3,
							inline = true,
							disabled = function()
								return not isOn("enableErrorFilter")
							end,
							args = (function()
								local args = BuildPatternListArgs(
									"errorHidePatterns",
									DEFAULT_HIDE_PATTERNS,
									function() return pendingHidePatternInput end,
									function(v) pendingHidePatternInput = v or "" end,
									1
								)
								args.addHeader.name = "Добавить в список скрытия"
								args.addInput.desc = "Текст сообщения (или его часть), которое нужно всегда скрывать"
								return args
							end)(),
						},

						extraBox = {
							type = "group",
							name = "Дополнительный фрейм для ошибок",
							desc = "Отдельный блок для важных ошибок, которые вы хотите видеть даже при включённом фильтре — например «Нет места» или «Вы должны подождать», чтобы они не терялись среди остальных сообщений.",
							order = 4,
							inline = true,
							disabled = function()
								return not isOn("enableErrorFilter")
							end,
							args = (function()
								local extraDisabled = function()
									return not isOn("enableErrorFilter") or not isOn("errorExtraEnabled")
								end

								local args = {
									errorExtraEnabled = {
										type = "toggle",
										name = "Включить дополнительный фрейм",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorExtraEnabled = val and 1 or 0
											ApplyErrorSettings()
											RefreshConfig()
										end,
									},
									errorFilteredOffsetY = {
										type = "range",
										name = "Смещение доп. фрейма исключений Y",
										desc = "Вертикальное смещение дополнительного фрейма для исключений",
										min = -1000,
										max = 1000,
										step = 1,
										order = 2,
										width = "full",
										disabled = extraDisabled,
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorFilteredOffsetY = val
											ApplyErrorSettings()
										end,
									},
									errorEchoToChat = {
										type = "toggle",
										name = "Дублировать текст исключения в чат",
										desc = "Отправлять исключения из фильтра в чат",
										order = 3,
										width = "full",
										disabled = extraDisabled,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorEchoToChat = val and 1 or 0
											RefreshConfig()
										end,
									},
									errorPlaySound = {
										type = "toggle",
										name = "|TInterface\\COMMON\\VOICECHAT-SPEAKER:14:14:0:0|t Звук при исключениях",
										desc = "Воспроизводить звук при появлении исключений",
										order = 4,
										width = "full",
										disabled = extraDisabled,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorPlaySound = val and 1 or 0
											RefreshConfig()
										end,
									},
								}

								local listArgs = BuildPatternListArgs(
									"errorExceptionPatterns",
									DEFAULT_EXCEPTION_PATTERNS,
									function() return pendingExceptionPatternInput end,
									function(v) pendingExceptionPatternInput = v or "" end,
									10
								)
								for key, opt in pairs(listArgs) do
									if type(opt) == "table" then
										local prevDisabled = opt.disabled
										opt.disabled = function(...)
											if extraDisabled() then return true end
											if prevDisabled then return prevDisabled(...) end
											return false
										end
									end
									args[key] = opt
								end

								return args
							end)(),
						},
					},
					},
					notifications = {
						type = "group",
						name = "Игровые уведомления",
						desc = "Настройки уведомлений о событиях рейдовых боссов",
						order = 2,
						args = {
							displayBox = {
								type = "group",
								name = "Системные сообщения",
								desc = "Например, уведомления о выполнении заданий.",
								order = 1,
								inline = true,
								args = {
									errorSysMsgOffsetY = {
										type = "range",
										name = "Изменение позиции по оси Y",
										desc = "Вертикальное смещение фрейма системных сообщений",
										min = -1000,
										max = 1000,
										step = 1,
										order = 1,
										width = "full",
										suiPreviewKey = "errorSysMsgOffsetY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.errorSysMsgOffsetY = val
											ApplyErrorSettings()
											if SarychUI.SysMsgPreview then
												if SarychUI.SysMsgPreview.ClearLiveValue then
													SarychUI.SysMsgPreview:ClearLiveValue("errorSysMsgOffsetY")
												end
												if SarychUI.SysMsgPreview.RefreshAll then
													SarychUI.SysMsgPreview:RefreshAll()
												end
											end
											-- No RefreshConfig on range commit — rebuild orphans cooltip textures.
										end,
									},
								},
							},
							sysPreview = {
								type = "description",
								name = "",
								order = 2,
								width = "full",
								suiSysMsgPreview = true,
							},
							notifBox = {
								type = "group",
								name = "Игровые уведомления",
								order = 3,
								inline = true,
								args = {
									enableRaidBossEmoteReposition = {
										type = "toggle",
										name = "Изменение фрейма сообщений уведомления боссов",
										desc = "Изменяет позицию и ширину фрейма сообщений рейдовых боссов",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.enableRaidBossEmoteReposition = val and 1 or 0
											ApplyBoss()
											if SarychUI.BossEmotePreview then
												if SarychUI.BossEmotePreview.SetLiveValue then
													SarychUI.BossEmotePreview:SetLiveValue("enableRaidBossEmoteReposition", val and 1 or 0)
												elseif SarychUI.BossEmotePreview.RefreshAll then
													SarychUI.BossEmotePreview:RefreshAll()
												end
											end
											RefreshConfig()
										end,
									},
									raidBossEmoteOffsetY = {
										type = "range",
										name = "Смещение по Y",
										desc = "Вертикальное смещение фрейма сообщений боссов",
										min = -1000,
										max = 1000,
										step = 1,
										order = 2,
										width = "full",
										suiPreviewKey = "raidBossEmoteOffsetY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.raidBossEmoteOffsetY = val
											RepositionBoss()
											if SarychUI.BossEmotePreview then
												if SarychUI.BossEmotePreview.ClearLiveValue then
													SarychUI.BossEmotePreview:ClearLiveValue("raidBossEmoteOffsetY")
												end
												if SarychUI.BossEmotePreview.RefreshAll then
													SarychUI.BossEmotePreview:RefreshAll()
												end
											end
										end,
										hidden = function()
											return not isOn("enableRaidBossEmoteReposition")
										end,
									},
									raidBossEmoteMaxWidth = {
										type = "range",
										name = "Ширина (px)",
										desc = "Максимальная ширина фрейма сообщений боссов в пикселях",
										min = 200,
										max = 1200,
										step = 10,
										order = 3,
										width = "full",
										suiPreviewKey = "raidBossEmoteMaxWidth",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.raidBossEmoteMaxWidth = val
											RepositionBoss()
											if SarychUI.BossEmotePreview then
												if SarychUI.BossEmotePreview.ClearLiveValue then
													SarychUI.BossEmotePreview:ClearLiveValue("raidBossEmoteMaxWidth")
												end
												if SarychUI.BossEmotePreview.RefreshAll then
													SarychUI.BossEmotePreview:RefreshAll()
												end
											end
										end,
										hidden = function()
											return not isOn("enableRaidBossEmoteReposition")
										end,
									},
								},
							},
							bossPreview = {
								type = "description",
								name = "",
								order = 4,
								width = "full",
								suiBossEmotePreview = true,
							},
						},
					},
				},
			},

			combatText = {
				type = "group",
				name = "Текст боя",
				desc = "Настройки смещения и скрытия текста боя (лечение, урон)",
				order = 3,
				disabled = function()
					return not IsModuleEnabled()
				end,
				childGroups = "tab",
				args = {
					frames = {
						type = "group",
						name = "Фреймы",
						order = 1,
						args = {
							framesPreview = {
								type = "description",
								name = "",
								order = 0,
								width = "full",
								suiFrameHitPreview = true,
							},
							framesBox = {
								type = "group",
								name = "Текст боя на фреймах",
								order = 1,
								inline = true,
								args = {
									hidePlayerHitIndicator = {
										type = "toggle",
										name = "Отключить текст боя на фрейме |cFFFFD700игрока|r",
										desc = "Скрыть текст урона и лечения на фрейме |cFFFFD700игрока|r",
										order = 1,
										width = "full",
										get = function()
											local frameDb = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
											return frameDb and frameDb.hidePlayerHitIndicator == 1
										end,
										set = function(_, val)
											local frameDb = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
											if not frameDb then return end
											frameDb.hidePlayerHitIndicator = val and 1 or 0
											local frameMod = SarychUI.modules and SarychUI.modules.frame
											if frameMod and frameMod.ApplySettings then
												frameMod:ApplySettings()
											end
											if SarychUI.FrameHitPreview then
												if SarychUI.FrameHitPreview.SetLiveValue then
													SarychUI.FrameHitPreview:SetLiveValue("hidePlayerHitIndicator", val and 1 or 0)
												elseif SarychUI.FrameHitPreview.RefreshAll then
													SarychUI.FrameHitPreview:RefreshAll()
												end
											end
											RefreshConfig()
										end,
									},
									hidePetHitIndicator = {
										type = "toggle",
										name = "Отключить текст боя на фрейме |cFFFFD700питомца|r",
										desc = "Скрыть текст урона и лечения на фрейме |cFFFFD700питомца|r",
										order = 2,
										width = "full",
										get = function()
											local frameDb = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
											return frameDb and frameDb.hidePetHitIndicator == 1
										end,
										set = function(_, val)
											local frameDb = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
											if not frameDb then return end
											frameDb.hidePetHitIndicator = val and 1 or 0
											local frameMod = SarychUI.modules and SarychUI.modules.frame
											if frameMod and frameMod.ApplySettings then
												frameMod:ApplySettings()
											end
											if SarychUI.FrameHitPreview then
												if SarychUI.FrameHitPreview.SetLiveValue then
													SarychUI.FrameHitPreview:SetLiveValue("hidePetHitIndicator", val and 1 or 0)
												elseif SarychUI.FrameHitPreview.RefreshAll then
													SarychUI.FrameHitPreview:RefreshAll()
												end
											end
											RefreshConfig()
										end,
									},
								},
							},
						},
					},
					incoming = {
						type = "group",
						name = "Входящий: урон, лечение, текст срабатываний",
						order = 2,
						args = {
							combatBox = {
								type = "group",
								name = "Изменить текст боя",
								order = 1,
								inline = true,
								args = {
									enableHealCombatTextAdjust = {
										type = "toggle",
										name = "Включить",
										desc = "Включить обработку текста боя (лечение и урон)",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.enableHealCombatTextAdjust = val and 1 or 0
											ApplyCombat()
											NotifyCombatPreview("enableHealCombatTextAdjust", val and 1 or 0)
											RefreshConfig()
										end,
									},
									gridToggle = {
										type = "toggle",
										name = "Сетка выравнивания",
										desc = "Показать/скрыть глобальную сетку выравнивания",
										order = 2,
										width = "full",
										hidden = function()
											return not isOn("enableHealCombatTextAdjust")
										end,
										get = function()
											if not SarychUI or not SarychUI.DragMode then return false end
											return SarychUI.DragMode:IsGridVisible()
										end,
										set = function(_, val)
											if not SarychUI or not SarychUI.DragMode then return end
											SarychUI.DragMode:ShowGrid(val and true or false)
											local db = DB() or {}
											local grid = SarychUI.DragMode:IsGridVisible()
											local enablePlus = (db.enableHealCombatTextAdjust == 1) and (db.healShiftPlus == 1) and (db.combatTextPlusDrag == 1)
											local enableMinus = (db.enableHealCombatTextAdjust == 1) and (db.healShiftMinus == 1) and (db.combatTextMinusDrag == 1)
											local enableLess = (db.enableHealCombatTextAdjust == 1) and (db.healShiftLess == 1) and (db.combatTextLessDrag == 1) and (db.healHideLess ~= 1)
											if SarychUI.DragMode.EnableEditMode then
												SarychUI.DragMode:EnableEditMode("combatTextPlus", enablePlus, enablePlus, grid)
												SarychUI.DragMode:EnableEditMode("combatTextMinus", enableMinus, enableMinus, grid)
												SarychUI.DragMode:EnableEditMode("combatTextLess", enableLess, enableLess, grid)
											end
										end,
									},
								},
							},
							combatPreview = {
								type = "description",
								name = "",
								order = 1.5,
								width = "full",
								suiCombatTextPreview = true,
								hidden = function()
									return not isOn("enableHealCombatTextAdjust")
								end,
							},
							plusBox = {
								type = "group",
								name = "Изменить входящие лечение",
								desc = "Настройки смещения текста боя, начинающегося с '+' (лечение)",
								order = 2,
								inline = true,
								suiTwoCol = true,
								hidden = function()
									return not isOn("enableHealCombatTextAdjust")
								end,
								args = {
									healShiftPlus = {
										type = "toggle",
										name = "Включить",
										desc = "Включить смещение текста лечения (со знаком +)",
										order = 1,
										width = "full",
										suiFullRow = true,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healShiftPlus = val and 1 or 0
											ApplyCombat()
											NotifyCombatPreview("healShiftPlus", val and 1 or 0)
											RefreshConfig()
										end,
									},
									healPlusX = {
										type = "range",
										name = "Смещение по X",
										desc = "Горизонтальное смещение текста лечения",
										min = -1000,
										max = 1000,
										step = 1,
										order = 2,
										suiPreviewKey = "healPlusX",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healPlusX = val
											ApplyCombat()
											NotifyCombatPreview("healPlusX", nil, true)
										end,
										hidden = function()
											return not isOn("healShiftPlus")
										end,
									},
									healPlusY = {
										type = "range",
										name = "Смещение по Y",
										desc = "Вертикальное смещение текста лечения",
										min = -1000,
										max = 1000,
										step = 1,
										order = 3,
										suiPreviewKey = "healPlusY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healPlusY = val
											ApplyCombat()
											NotifyCombatPreview("healPlusY", nil, true)
										end,
										hidden = function()
											return not isOn("healShiftPlus")
										end,
									},
									combatTextPlusDrag = {
										type = "execute",
										name = function()
											local db = DB() or {}
											if db.combatTextPlusDrag == 1 then
												return "Свободное перемещение |cff00ff00(вкл)|r"
											end
											return "Свободное перемещение"
										end,
										desc = "Показать рамку для перетаскивания позиции текста лечения (+)",
										order = 4,
										width = "full",
										suiFullRow = true,
										func = function()
											local db = DB()
											if not db then return end
											local val = not (db.combatTextPlusDrag == 1)
											db.combatTextPlusDrag = val and 1 or 0
											ToggleDrag("combatTextPlus", val)
											RefreshConfig()
										end,
										hidden = function()
											return not isOn("healShiftPlus")
										end,
									},
								},
							},
							minusBox = {
								type = "group",
								name = "Изменить входящий урон",
								desc = "Настройки смещения текста боя, начинающегося с '-' (урон)",
								order = 3,
								inline = true,
								suiTwoCol = true,
								hidden = function()
									return not isOn("enableHealCombatTextAdjust")
								end,
								args = {
									healShiftMinus = {
										type = "toggle",
										name = "Включить",
										desc = "Включить смещение текста входящего урона (со знаком -)",
										order = 1,
										width = "full",
										suiFullRow = true,
										get = toggleGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healShiftMinus = val and 1 or 0
											ApplyCombat()
											NotifyCombatPreview("healShiftMinus", val and 1 or 0)
											RefreshConfig()
										end,
									},
									healMinusX = {
										type = "range",
										name = "Смещение по X",
										desc = "Горизонтальное смещение текста входящего урона",
										min = -1000,
										max = 1000,
										step = 1,
										order = 2,
										suiPreviewKey = "healMinusX",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healMinusX = val
											ApplyCombat()
											NotifyCombatPreview("healMinusX", nil, true)
										end,
										hidden = function()
											return not isOn("healShiftMinus")
										end,
									},
									healMinusY = {
										type = "range",
										name = "Смещение по Y",
										desc = "Вертикальное смещение текста входящего урона",
										min = -1000,
										max = 1000,
										step = 1,
										order = 3,
										suiPreviewKey = "healMinusY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healMinusY = val
											ApplyCombat()
											NotifyCombatPreview("healMinusY", nil, true)
										end,
										hidden = function()
											return not isOn("healShiftMinus")
										end,
									},
									combatTextMinusDrag = {
										type = "execute",
										name = function()
											local db = DB() or {}
											if db.combatTextMinusDrag == 1 then
												return "Свободное перемещение |cff00ff00(вкл)|r"
											end
											return "Свободное перемещение"
										end,
										desc = "Показать рамку для перетаскивания позиции текста входящего урона (-)",
										order = 4,
										width = "full",
										suiFullRow = true,
										func = function()
											local db = DB()
											if not db then return end
											local val = not (db.combatTextMinusDrag == 1)
											db.combatTextMinusDrag = val and 1 or 0
											ToggleDrag("combatTextMinus", val)
											RefreshConfig()
										end,
										hidden = function()
											return not isOn("healShiftMinus")
										end,
									},
								},
							},
							lessBox = {
								type = "group",
								name = "Изменить текст срабатываний",
								desc = "Настройки обработки текста боя, начинающегося с '<' (урон по игроку)",
								order = 4,
								inline = true,
								suiTwoCol = true,
								hidden = function()
									return not isOn("enableHealCombatTextAdjust")
								end,
								args = {
									lessModifyEnabled = {
										type = "toggle",
										name = "Включить",
										desc = "Включить обработку текста урона (со знаком <)",
										order = 1,
										width = "full",
										suiFullRow = true,
										get = function()
											local db = DB() or {}
											return (db.healHideLess == 1 or db.healHideLess == true or db.healShiftLess == 1 or db.healShiftLess == true)
										end,
										set = function(_, val)
											local db = DB()
											if not db then return end
											if not val then
												db.healHideLess = 0
												db.healShiftLess = 0
											else
												db.healHideLess = 0
												db.healShiftLess = 1
											end
											ApplyCombat()
											NotifyCombatPreview("healHideLess", db.healHideLess)
											NotifyCombatPreview("healShiftLess", db.healShiftLess)
											RefreshConfig()
										end,
									},
									healLessMode = {
										type = "select",
										name = "Режим",
										desc = "Режим обработки урона: скрывать полностью или отображать со смещением",
										order = 2,
										width = "full",
										suiFullRow = true,
										values = { hide = "Не отображать", offset = "Отображать (со смещением)" },
										get = function()
											local db = DB() or {}
											if db.healHideLess == 1 or db.healHideLess == true then
												return "hide"
											end
											return "offset"
										end,
										set = function(_, val)
											local db = DB()
											if not db then return end
											if val == "hide" then
												db.healHideLess = 1
												db.healShiftLess = 0
											else
												db.healHideLess = 0
												db.healShiftLess = 1
											end
											ApplyCombat()
											NotifyCombatPreview("healHideLess", db.healHideLess)
											NotifyCombatPreview("healShiftLess", db.healShiftLess)
											RefreshConfig()
										end,
										hidden = function()
											local db = DB() or {}
											local enabled = (db.healHideLess == 1 or db.healHideLess == true or db.healShiftLess == 1 or db.healShiftLess == true)
											return not enabled
										end,
									},
									healLessX = {
										type = "range",
										name = "Смещение по X",
										desc = "Горизонтальное смещение текста урона",
										min = -1000,
										max = 1000,
										step = 1,
										order = 3,
										suiPreviewKey = "healLessX",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healLessX = val
											ApplyCombat()
											NotifyCombatPreview("healLessX", nil, true)
										end,
										hidden = function()
											local db = DB() or {}
											return not (db.healHideLess ~= 1 and db.healHideLess ~= true and (db.healShiftLess == 1 or db.healShiftLess == true))
										end,
									},
									healLessY = {
										type = "range",
										name = "Смещение по Y",
										desc = "Вертикальное смещение текста урона",
										min = -1000,
										max = 1000,
										step = 1,
										order = 4,
										suiPreviewKey = "healLessY",
										get = numberGetter,
										set = function(info, val)
											local db = DB()
											if not db then return end
											db.healLessY = val
											ApplyCombat()
											NotifyCombatPreview("healLessY", nil, true)
										end,
										hidden = function()
											local db = DB() or {}
											return not (db.healHideLess ~= 1 and db.healHideLess ~= true and (db.healShiftLess == 1 or db.healShiftLess == true))
										end,
									},
									combatTextLessDrag = {
										type = "execute",
										name = function()
											local db = DB() or {}
											if db.combatTextLessDrag == 1 then
												return "Свободное перемещение |cff00ff00(вкл)|r"
											end
											return "Свободное перемещение"
										end,
										desc = "Показать рамку для перетаскивания позиции текста урона (<)",
										order = 5,
										width = "full",
										suiFullRow = true,
										func = function()
											local db = DB()
											if not db then return end
											local val = not (db.combatTextLessDrag == 1)
											db.combatTextLessDrag = val and 1 or 0
											ToggleDrag("combatTextLess", val)
											RefreshConfig()
										end,
										hidden = function()
											local db = DB() or {}
											return not (db.healHideLess ~= 1 and db.healHideLess ~= true and (db.healShiftLess == 1 or db.healShiftLess == true))
										end,
									},
								},
							},
						},
					},
				},
			},
		},
	}
end
