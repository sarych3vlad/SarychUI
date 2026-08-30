-- SarychUI Health Indicators module options

local format = string.format

local moduleName = "health_indicators"
local ENP_ADDON = "ElvUI_NamePlates"
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

local function GetWrapper()
	return SarychUI.GetAddOn and SarychUI:GetAddOn(ENP_ADDON)
end

local function ShowReloadPopup(onCancel, text)
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup(text, onCancel)
		return
	end
	if StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

local function IsElvUINamePlatesRuntimeEnabled()
	local wrapper = GetWrapper()
	if wrapper and wrapper.IsRuntimeEnabled then
		return wrapper:IsRuntimeEnabled()
	end
	if SarychUI.IsAddOnEnabled then
		return SarychUI:IsAddOnEnabled(ENP_ADDON)
	end
	local addons = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	return addons and addons[ENP_ADDON] and addons[ENP_ADDON].enabled ~= false
end

local function SetElvUINamePlatesRuntime(enable)
	local wrapper = GetWrapper()
	if wrapper and wrapper.SetRuntimeEnabled then
		wrapper:SetRuntimeEnabled(enable)
	else
		if enable then
			SarychUI:EnableAddOn(ENP_ADDON)
		else
			SarychUI:DisableAddOn(ENP_ADDON)
		end
	end
end

local function GetCurrentNameplateMode()
	if SarychUI.GetNameplateMode then
		return SarychUI:GetNameplateMode()
	end
	return IsElvUINamePlatesRuntimeEnabled() and "elvui" or "classic"
end

local function ApplyNameplateMode(mode)
	if SarychUI.SetNameplateMode then
		SarychUI:SetNameplateMode(mode)
	else
		SetElvUINamePlatesRuntime(mode == "elvui")
	end
end

local function GetProfileModeLabel()
	local mode = module.GetAutolosProfileMode and module:GetAutolosProfileMode() or "classic"
	if mode == "elvui" then
		return L and (L["ElvUI Nameplates"] or "ElvUI индикаторы") or "ElvUI индикаторы"
	end
	return L and (L["Classic WoW Nameplates"] or "Классические WoW") or "Классические WoW"
end

local function ProfileModeInfoText()
	local mode = module.GetAutolosProfileMode and module:GetAutolosProfileMode() or "classic"
	local modeLabel = GetProfileModeLabel()
	local modeColor = (mode == "elvui") and "|cff00ff00" or "|cFFFFD700"
	return "Настройки параметров для: " .. modeColor .. tostring(modeLabel) .. "|r"
end

local function IsElvUIAutolosMode()
	return (module.GetAutolosProfileMode and module:GetAutolosProfileMode()) == "elvui"
end

local function GetAutolosProfile()
	if module.EnsureAutolosProfiles then
		module:EnsureAutolosProfiles()
	end
	local db = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.autolos
	if not db or not db.profiles then return {} end
	local mode = module.GetAutolosProfileMode and module:GetAutolosProfileMode() or "classic"
	db.profiles[mode] = db.profiles[mode] or {}
	return db.profiles[mode]
end

local function GetFontValues()
	local values = {}
	if SarychUI and SarychUI.Media and SarychUI.Media.GetFonts then
		for _, name in ipairs(SarychUI.Media.GetFonts()) do
			values[name] = name
		end
	end
	if not next(values) then
		values["Fonts\\FRIZQT__.TTF"] = "Fonts\\FRIZQT__.TTF"
	end
	return values
end

local function ApplyAutolosAndNotify()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
		return
	end
	local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)
	if AceConfigRegistry then
		AceConfigRegistry:NotifyChange("SarychUI")
	end
end

local function ApplyAutolosTextStyle()
	if module.ApplyAutolosTextStyle then
		module:ApplyAutolosTextStyle()
	end
	local preview = SarychUI.NameplateDistancePreview
	if preview and preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function ApplyAutolosLayout()
	if module.ApplyAutolosLayout then
		module:ApplyAutolosLayout()
	end
	local preview = SarychUI.NameplateDistancePreview
	if preview and preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function ApplyAutolosFull()
	if module.ApplyAutolosSettings then
		module:ApplyAutolosSettings()
	end
	local preview = SarychUI.NameplateDistancePreview
	if preview and preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function OnDistanceSetting(key, value, applyFn)
	local preview = SarychUI.NameplateDistancePreview
	local dragging = SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging()
	if preview and not dragging then
		if preview.ClearLiveValue then
			preview:ClearLiveValue(key)
		end
		if preview.SetActiveKey then
			preview:SetActiveKey(key)
		end
	end
	if applyFn then
		applyFn()
	end
	if dragging then
		return
	end
	if preview and preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function IsModuleEnabled()
	local db = DB()
	return db and db.enabled ~= false
end

function module:GetOptions()
	return {
		type = "group",
		name = "|TInterface\\AddOns\\SarychUI\\addons\\ElvUI_NamePlates\\Media\\Textures\\nameplates:20:20:0:0:256:128:0:38:45:81|t " .. (L and (L["Health Indicators"] or "Индикаторы здоровья") or "Индикаторы здоровья"),
		desc = L and (L["Health Indicators Desc"] or "Выбор системы индикаторов здоровья / nameplates.") or "Выбор системы индикаторов здоровья / nameplates.",
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
						desc = "Выключение модуля переключает индикаторы на классические WoW и требует перезагрузки.",
						order = 1,
						width = "full",
						get = function()
							return IsModuleEnabled()
						end,
						set = function(_, value)
							local db = DB()
							if not db then return end
							local previousEnabled = db.enabled ~= false
							local preferredMode = db.nameplateMode or GetCurrentNameplateMode()
							value = value and true or false
							if previousEnabled == value then return end

							db.enabled = value
							if value then
								local restoreMode = preferredMode
								if restoreMode ~= "elvui" and restoreMode ~= "classic" then
									restoreMode = "elvui"
								end
								db.nameplateMode = restoreMode
								ApplyNameplateMode(restoreMode)
								if SarychUI.EnableModule then
									SarychUI:EnableModule(moduleName)
								end
								ApplyAutolosLayout()
								ApplyAutolosAndNotify()
								ShowReloadPopup(function()
									db.enabled = false
									SetElvUINamePlatesRuntime(false)
									if SarychUI.DisableModule then
										SarychUI:DisableModule(moduleName)
									end
									ApplyAutolosLayout()
									ApplyAutolosAndNotify()
								end, "Для включения модуля индикаторов здоровья требуется перезагрузка интерфейса.")
							else
								-- Keep preferred mode in db; force classic runtime until re-enabled.
								db.nameplateMode = preferredMode
								SetElvUINamePlatesRuntime(false)
								if SarychUI.DisableModule then
									SarychUI:DisableModule(moduleName)
								end
								ApplyAutolosLayout()
								ApplyAutolosAndNotify()
								ShowReloadPopup(function()
									db.enabled = true
									ApplyNameplateMode(preferredMode)
									if SarychUI.EnableModule then
										SarychUI:EnableModule(moduleName)
									end
									ApplyAutolosLayout()
									ApplyAutolosAndNotify()
								end, "Модуль выключен: будут использованы классические индикаторы WoW.\nДля применения требуется перезагрузка интерфейса.")
							end
						end,
					},

					typeRow = {
						type = "group",
						name = L and (L["Health Indicator Type"] or "Тип индикаторов здоровья") or "Тип индикаторов здоровья",
						order = 2,
						inline = true,
						suiSelectWithButton = true,
						args = {
							indicatorType = {
								type = "select",
								name = "",
								desc = L and (L["Health Indicator Type Desc"] or "ElvUI — встроенные nameplates ElvUI. Классические WoW — стандартные индикаторы Blizzard.") or "ElvUI — встроенные nameplates ElvUI. Классические WoW — стандартные индикаторы Blizzard.",
								order = 1,
								values = {
									classic = L and (L["Classic WoW Nameplates"] or "Классические WoW") or "Классические WoW",
									elvui = L and (L["ElvUI Nameplates"] or "ElvUI индикаторы") or "ElvUI индикаторы",
								},
								get = function()
									return GetCurrentNameplateMode()
								end,
								set = function(_, value)
									local previous = GetCurrentNameplateMode()
									if value == previous then return end
									ApplyNameplateMode(value)
									ApplyAutolosLayout()
									ApplyAutolosAndNotify()
									ShowReloadPopup(function()
										ApplyNameplateMode(previous)
										ApplyAutolosLayout()
										ApplyAutolosAndNotify()
									end, L and (L["Health Indicators Reload Notice"] or "Для полного применения изменения типа индикаторов здоровья необходимо перезагрузить интерфейс.") or "Для полного применения изменения типа индикаторов здоровья необходимо перезагрузить интерфейс.")
								end,
							},
							openElvUISettings = {
								type = "execute",
								name = "Настройки",
								desc = L and (L["Open ElvUI NamePlates Settings Desc"] or "Открыть окно настроек ElvUI NamePlates (/enp).") or "Открыть окно настроек ElvUI NamePlates (/enp).",
								order = 2,
								hidden = function()
									return GetCurrentNameplateMode() ~= "elvui"
								end,
								func = function()
									if not SarychUI then
										return
									end
									if not SarychUI.OpenNamePlatesConfig then
										SarychUI:Print("OpenNamePlatesConfig missing (options.lua not loaded?)")
										return
									end
									SarychUI:OpenNamePlatesConfig()
								end,
							},
						},
					},
					modeHint = {
						type = "description",
						name = "|cFFFFD700Внимание:|r После применения потребуется перезагрузка интерфейса.",
						order = 3,
						width = "full",
					},
				},
			},

			distance = {
				type = "group",
				name = L and (L["Nameplate Distance Tab"] or "Дистанция до неймплейта") or "Дистанция до неймплейта",
				order = 2,
				disabled = function()
					return not IsModuleEnabled()
				end,
				args = {
					enableAutolos = {
						type = "toggle",
						name = L and (L["Nameplate Distance"] or "Включить отображение дистанции") or "Включить отображение дистанции",
						desc = L and (L["Nameplate Distance Desc"] or "Работает только при наличии nameplate_range.dll. Статус: Система -> Обзор.") or "Работает только при наличии nameplate_range.dll. Статус: Система -> Обзор.",
						order = 1,
						width = "full",
						suiHelpIcon = true,
						get = function()
							return module:IsAutolosEnabled()
						end,
						set = function(_, value)
							module:SetAutolosEnabled(value)
							ApplyAutolosFull()
							ApplyAutolosAndNotify()
						end,
					},

					totemSupport = {
						type = "toggle",
						name = "Включить поддержку тотемов",
						desc = "Для тотемов ElvUI, которые показаны как иконка (без полоски HP), ставить дистанцию сразу слева от иконки. Обычные неймплейты тотемов не меняются.",
						order = 1.5,
						width = "full",
						hidden = function()
							return not module:IsAutolosEnabled() or not IsElvUIAutolosMode()
						end,
						get = function()
							return GetAutolosProfile().totemSupport == true
						end,
						set = function(_, value)
							GetAutolosProfile().totemSupport = value and true or false
							OnDistanceSetting("totemSupport", value, ApplyAutolosLayout)
						end,
					},

					layoutPreview = {
						type = "description",
						name = " ",
						order = 2,
						width = "full",
						suiDistancePreview = true,
						suiDistancePreviewNotice = ProfileModeInfoText,
						hidden = function()
							return not module:IsAutolosEnabled()
						end,
					},

					distancePosition = {
						type = "group",
						name = "Позиция",
						order = 3,
						inline = true,
						suiTwoCol = true,
						hidden = function()
							return not module:IsAutolosEnabled()
						end,
						args = {
							anchorToName = {
								type = "toggle",
								name = "Привязать к нику",
								desc = "Дистанция слева от ника (все плейты ElvUI). Выкл. — позиция у полоски HP со смещениями ниже. На тотемы-иконки не влияет, если включена поддержка тотемов.",
								order = 1,
								width = "full",
								suiFullRow = true,
								hidden = function()
									return not IsElvUIAutolosMode()
								end,
								get = function()
									return GetAutolosProfile().anchorToName == true
								end,
								set = function(_, value)
									GetAutolosProfile().anchorToName = value and true or false
									OnDistanceSetting("anchorToName", value, ApplyAutolosLayout)
								end,
							},
							distanceOffsetX = {
								type = "range",
								name = L and (L["Position X"] or "Позиция X") or "Позиция X",
								desc = L and (L["Nameplate Distance Offset X Desc"] or "Горизонтальное смещение текста дистанции.") or "Горизонтальное смещение текста дистанции.",
								order = 2,
								min = -200,
								max = 200,
								step = 1,
								suiPreviewKey = "offsetX",
								get = function()
									return GetAutolosProfile().offsetX or -95
								end,
								set = function(_, value)
									GetAutolosProfile().offsetX = value
									OnDistanceSetting("offsetX", value, ApplyAutolosLayout)
								end,
							},
							distanceOffsetY = {
								type = "range",
								name = L and (L["Position Y"] or "Позиция Y") or "Позиция Y",
								desc = L and (L["Nameplate Distance Offset Y Desc"] or "Вертикальное смещение текста дистанции.") or "Вертикальное смещение текста дистанции.",
								order = 3,
								min = -100,
								max = 100,
								step = 1,
								suiPreviewKey = "offsetY",
								get = function()
									return GetAutolosProfile().offsetY or -9
								end,
								set = function(_, value)
									GetAutolosProfile().offsetY = value
									OnDistanceSetting("offsetY", value, ApplyAutolosLayout)
								end,
							},
						},
					},

					distanceSettings = {
						type = "group",
						name = "Настройки отображения",
						order = 4,
						inline = true,
						suiTwoCol = true,
						hidden = function()
							return not module:IsAutolosEnabled()
						end,
						args = {
							distanceFontSize = {
								type = "range",
								name = L and (L["Font Size"] or "Размер шрифта") or "Размер шрифта",
								desc = L and (L["Nameplate Distance Font Size Desc"] or "Размер текста дистанции.") or "Размер текста дистанции.",
								order = 1,
								min = 6,
								max = 32,
								step = 1,
								suiFullRow = true,
								suiPreviewKey = "fontSize",
								get = function()
									return GetAutolosProfile().fontSize or 12
								end,
								set = function(_, value)
									GetAutolosProfile().fontSize = value
									OnDistanceSetting("fontSize", value, ApplyAutolosTextStyle)
								end,
							},
							distanceFont = {
								type = "select",
								style = "dropdown",
								name = L and (L["Font"] or "Шрифт") or "Шрифт",
								desc = L and (L["Nameplate Distance Font Desc"] or "Шрифт текста дистанции на неймплейте.") or "Шрифт текста дистанции на неймплейте.",
								order = 2,
								values = GetFontValues,
								get = function()
									return GetAutolosProfile().font or "Friz Quadrata TT"
								end,
								set = function(_, value)
									GetAutolosProfile().font = value
									OnDistanceSetting("font", value, ApplyAutolosTextStyle)
								end,
							},
							distanceFontOutline = {
								type = "select",
								style = "dropdown",
								name = L and (L["Font Outline"] or "Граница шрифта") or "Граница шрифта",
								desc = L and (L["Nameplate Distance Font Outline Desc"] or "Стиль контура текста дистанции.") or "Стиль контура текста дистанции.",
								order = 3,
								values = function()
									if AutolosFontFlags and AutolosFontFlags.GetValues then
										return AutolosFontFlags.GetValues(L)
									end
									return {
										NONE = L and (L["None"] or "Без границы") or "Без границы",
										OUTLINE = "OUTLINE",
										MONOCHROME = "MONOCHROME",
										MONOCHROMEOUTLINE = "MONOCHROME OUTLINE",
										THICKOUTLINE = "THICK OUTLINE",
									}
								end,
								get = function()
									return GetAutolosProfile().fontOutline or GetAutolosProfile().fontFlags or "OUTLINE"
								end,
								set = function(_, value)
									GetAutolosProfile().fontOutline = value
									OnDistanceSetting("fontOutline", value, ApplyAutolosTextStyle)
								end,
							},
							distanceShadowX = {
								type = "range",
								name = L and (L["Shadow X"] or "Тень X") or "Тень X",
								desc = L and (L["Nameplate Distance Shadow X Desc"] or "Горизонтальное смещение тени текста.") or "Горизонтальное смещение тени текста.",
								order = 4,
								min = -5,
								max = 5,
								step = 1,
								suiPreviewKey = "shadowX",
								get = function()
									return GetAutolosProfile().shadowX or 2
								end,
								set = function(_, value)
									GetAutolosProfile().shadowX = value
									OnDistanceSetting("shadowX", value, ApplyAutolosTextStyle)
								end,
							},
							distanceShadowY = {
								type = "range",
								name = L and (L["Shadow Y"] or "Тень Y") or "Тень Y",
								desc = L and (L["Nameplate Distance Shadow Y Desc"] or "Вертикальное смещение тени текста.") or "Вертикальное смещение тени текста.",
								order = 5,
								min = -5,
								max = 5,
								step = 1,
								suiPreviewKey = "shadowY",
								get = function()
									return GetAutolosProfile().shadowY or -1
								end,
								set = function(_, value)
									GetAutolosProfile().shadowY = value
									OnDistanceSetting("shadowY", value, ApplyAutolosTextStyle)
								end,
							},
						},
					},
				},
			},
		},
	}
end
