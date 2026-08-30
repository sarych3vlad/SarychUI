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

function module:BuildAddonButtonIconOptions()
	if SarychUI_ProfileOptionsStage then
		return SarychUI_ProfileOptionsStage("minimap.BuildAddonButtonIconOptions", module._BuildAddonButtonIconOptionsImpl, module)
	end
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
					name = "Управлять через SarychUI",
					desc = "SarychUI задаёт угол и отключает перетаскивание",
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
					name = "Показать кнопку",
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
					name = "Угол",
					desc = "0° = справа, 90° = сверху, 180° = слева, 270° = снизу",
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
	-- Если кнопки уже есть в профиле — сразу показываем настройки угла.
	if savedButtonCount > 0 then
		self._addonButtonOptionsExpanded = true
	end
	local iconOptions = {}
	local iconCount = savedButtonCount
	if self._addonButtonOptionsExpanded then
		iconOptions = self:BuildAddonButtonIconOptions()
		iconCount = self._cachedIconOptionsCount or savedButtonCount
	end
	if SarychUI and SarychUI.OptionsPerfFlag then
		SarychUI:OptionsPerfFlag("minimapIconControlCount", iconCount)
	end

	local buttonsArgs = {
		addonButtonsBox = {
			type = "group",
			name = "Управление кнопками аддонов",
			order = 1,
			inline = true,
			args = {
				buttonsEnabled = {
					type = "toggle",
					name = "Скрытие кнопок аддонов (|cFFFFD700Отображение: Левый клик мыши|r)",
					desc = "Скрывать управляемые кнопки и показывать их при клике по миникарте",
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
					name = "Задержка скрытия (сек)",
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
					name = "Время анимации (сек)",
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
			name = "Обновить список кнопок",
			desc = "Сканировать миникарту и добавить найденные кнопки аддонов",
			order = 2,
			width = "full",
			func = function()
				if module.ScanAddonMinimapButtons then
					if SarychUI_ProfileOptionsStage then
						SarychUI_ProfileOptionsStage("minimap.ScanAddonMinimapButtons(manual)", module.ScanAddonMinimapButtons, module)
					else
						module:ScanAddonMinimapButtons()
					end
					if SarychUI and SarychUI.OptionsPerfFlag then
						SarychUI:OptionsPerfFlag("minimapScanManual", true)
					end
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
					return "|cff888888Кнопки не найдены. Нажмите «Обновить список кнопок».|r"
				end
				return string.format("Найдено кнопок: |cff33ff99%d|r", count)
			end,
			order = 3,
			width = "full",
		},
		iconHeader = {
			type = "header",
			name = "Настройки кнопок",
			order = 10,
			hidden = function() return not module._addonButtonOptionsExpanded end,
		},
		loadIconControls = {
			type = "execute",
			name = "Загрузить настройки отдельных кнопок",
			desc = "Построить элементы управления для каждой найденной кнопки (тяжёлая операция, выполняется по запросу)",
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
		name = "Миникарта",
		desc = L and (L["Minimap_Description"] or "Настройка миникарты") or "Настройка миникарты",
		childGroups = "tab",
		args = {
			main = {
				type = "group",
				name = "Общее",
				order = 1,
				args = {
					header = {
						type = "header",
						name = L["Minimap"] or "Миникарта",
						order = 1,
					},
					enabled = {
						type = "toggle",
						name = "Включить модуль",
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
				name = "Позиция",
				order = 2,
				disabled = function() return not self.addon.db.profile.modules[moduleName].enabled end,
				args = {
					positionBox = {
						type = "group",
						name = "Изменить расположение миникарты",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							positioningEnabled = {
								type = "toggle",
								name = "Включить",
								desc = "Включить изменение позиции миникарты",
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
								name = "Смещение по X",
								order = 2,
								min = -500, max = 500, step = 1,
								get = function() return self.addon.db.profile.modules[moduleName].offsetX or 0 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].offsetX = value
									if self.ApplySettings then self:ApplySettings() end
								end,
								hidden = function() return not isOn("positioningEnabled") end,
							},
							offsetY = {
								type = "range",
								name = "Смещение по Y",
								order = 3,
								min = -500, max = 500, step = 1,
								get = function() return self.addon.db.profile.modules[moduleName].offsetY or 0 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].offsetY = value
									if self.ApplySettings then self:ApplySettings() end
								end,
								hidden = function() return not isOn("positioningEnabled") end,
							},
							showDragFrame = {
								type = "execute",
								name = function()
									if isOn("showDragFrame") then
										return "Свободное перемещение |cff00ff00(вкл)|r"
									end
									return "Свободное перемещение"
								end,
								desc = "Показать рамку и окошко для перетаскивания миникарты",
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
								hidden = function() return not isOn("positioningEnabled") end,
							},
						},
					},
					zoneTextBox = {
						type = "group",
						name = "Настройки текста зоны",
						order = 2,
						inline = true,
						suiTwoCol = true,
						args = {
							moveZoneText = {
								type = "toggle",
								name = "Включить",
								desc = "Переместить текст зоны на миникарте",
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
								name = "Смещение по X",
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
								name = "Смещение по Y",
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
				name = "Внешний вид",
				order = 3,
				disabled = function() return not self.addon.db.profile.modules[moduleName].enabled end,
				args = {
					preview = {
						type = "description",
						name = "",
						order = 1,
						width = "full",
						suiMinimapPreview = true,
					},
					appearanceBox = {
						type = "group",
						name = "Видимость элементов миникарты",
						order = 2,
						inline = true,
						args = {
							hideBorder = {
								type = "toggle", name = "Скрыть рамку вокруг текста зоны", order = 1, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideBorder == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideBorder = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideBorder", value and 1 or 0)
								end,
							},
							hideZoomButtons = {
								type = "toggle", name = "Скрыть кнопки масштаба", order = 2, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideZoomButtons == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideZoomButtons = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideZoomButtons", value and 1 or 0)
								end,
							},
							hideWorldMapButton = {
								type = "toggle", name = "Скрыть кнопку карты мира", order = 3, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideWorldMapButton == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideWorldMapButton = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideWorldMapButton", value and 1 or 0)
								end,
							},
							hideClock = {
								type = "toggle", name = "Скрыть часы", order = 4, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideClock == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideClock = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideClock", value and 1 or 0)
								end,
							},
							hideTracking = {
								type = "toggle", name = "Скрыть кнопку отслеживания", order = 5, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideTracking == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideTracking = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideTracking", value and 1 or 0)
								end,
							},
							hideCalendar = {
								type = "toggle", name = "Скрыть календарь", order = 6, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].hideCalendar == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].hideCalendar = value and 1 or 0
									if self.ApplySettings then self:ApplySettings() end
									NotifyMinimapPreview("hideCalendar", value and 1 or 0)
								end,
							},
						},
					},
				},
			},
			buttons = {
				type = "group",
				name = "Кнопки аддонов",
				order = 4,
				suiTwoPane = true,
				disabled = function() return not self.addon.db.profile.modules[moduleName].enabled end,
				args = buttonsArgs,
			},
			mouse = {
				type = "group",
				name = "Управление",
				order = 5,
				disabled = function() return not self.addon.db.profile.modules[moduleName].enabled end,
				args = {
					mouseBox = {
						type = "group",
						name = "Настройки управления мышью",
						order = 1,
						inline = true,
						args = {
							leftClickEnabled = {
								type = "toggle",
								name = "Shift + Левая кнопка мыши — |cFFFFD700Установить метку|r",
								order = 1, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].leftClickEnabled == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].leftClickEnabled = value and 1 or 0
								end,
							},
							rightClickEnabled = {
								type = "toggle",
								name = "Правая кнопка мыши — |cFFFFD700Открыть календарь|r",
								order = 2, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].rightClickEnabled == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].rightClickEnabled = value and 1 or 0
								end,
							},
							middleClickEnabled = {
								type = "toggle",
								name = "Средняя кнопка (клик колесом) мыши — |cFFFFD700Меню отслеживания|r",
								order = 3, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].middleClickEnabled == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].middleClickEnabled = value and 1 or 0
								end,
							},
							wheelEnabled = {
								type = "toggle",
								name = "Прокрутка колеса мыши — |cFFFFD700Приблизить и отдалить|r",
								order = 4, width = "full",
								get = function() return self.addon.db.profile.modules[moduleName].wheelEnabled == 1 end,
								set = function(_, value)
									self.addon.db.profile.modules[moduleName].wheelEnabled = value and 1 or 0
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
