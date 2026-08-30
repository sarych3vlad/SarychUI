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
	return db and db.mapType or "mapster"
end

local function GetMapTypeValues()
	local values = {
		classic = L and (L["Classic WoW Map"] or "Классическая карта WoW") or "Классическая карта WoW",
		mapster = "Mapster",
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
	if mapType == "mapster" then
		addons.Mapster = addons.Mapster or {}
		addons.Mapster.enabled = true
		addons.Carbonite = addons.Carbonite or {}
		addons.Carbonite.enabled = false
	elseif mapType == "carbonite" then
		addons.Mapster = addons.Mapster or {}
		addons.Mapster.enabled = false
		addons.Carbonite = addons.Carbonite or {}
		addons.Carbonite.enabled = true
	else
		addons.Mapster = addons.Mapster or {}
		addons.Mapster.enabled = false
		addons.Carbonite = addons.Carbonite or {}
		addons.Carbonite.enabled = false
	end
end

local function IsModuleEnabled()
	local db = DB()
	return db and db.enabled ~= false
end

local function OpenMapSettings()
	local mode = GetMapMode()
	if mode == "mapster" then
		if SarychUI and SarychUI.OpenMapsterConfig then
			SarychUI:OpenMapsterConfig()
		elseif SlashCmdList and SlashCmdList["MAPSTER"] then
			SlashCmdList["MAPSTER"]("")
		end
	elseif mode == "carbonite" then
		if SarychUI and SarychUI.OpenCarboniteConfig then
			SarychUI:OpenCarboniteConfig()
		elseif _G.Nx and _G.Nx.Opt and _G.Nx.Opt.Ope then
			_G.Nx.Opt:Ope()
		end
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
								if restoreType ~= "mapster" and restoreType ~= "carbonite" and restoreType ~= "classic" then
									restoreType = "mapster"
								end
								if restoreType == "carbonite"
									and SarychUI and SarychUI.IsExternalCarboniteAvailable
									and not SarychUI:IsExternalCarboniteAvailable() then
									restoreType = "mapster"
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
								desc = L and (L["Map Type Desc"] or "Выберите, какой аддон карты использовать.") or "Выберите, какой аддон карты использовать.",
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
									local mode = GetMapMode()
									if mode == "mapster" then
										return L and (L["Open Mapster Settings Desc"] or "Открыть окно настроек Mapster (/mapster).") or "Открыть окно настроек Mapster (/mapster)."
									end
									if mode == "carbonite" then
										return L and (L["Open Carbonite Settings Desc"] or "Открыть окно настроек Carbonite (/carb options).") or "Открыть окно настроек Carbonite (/carb options)."
									end
									return L and (L["Map Settings Unavailable"] or "Для классической карты отдельные настройки недоступны.") or "Для классической карты отдельные настройки недоступны."
								end,
								order = 2,
								hidden = function()
									local mode = GetMapMode()
									if mode == "classic" then
										return true
									end
									if mode == "carbonite" then
										return not (SarychUI and SarychUI.IsExternalCarboniteAvailable and SarychUI:IsExternalCarboniteAvailable())
									end
									return false
								end,
								func = OpenMapSettings,
							},
						},
					},
					modeHint = {
						type = "description",
						name = "|cFFFFD700Внимание:|r После применения потребуется перезагрузка интерфейса.",
						order = 20,
						width = "full",
					},
				},
			},
		},
	}
end
