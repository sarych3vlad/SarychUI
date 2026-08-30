-- SarychUI Arena Module Options

local moduleName = "arena"
local GLADIUS_ADDON = "GladiusEx"
local L = SarychUI.L
local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
local originalEnabledSnapshot = nil

-- Get module
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local function GetWrapper()
	return SarychUI.GetAddOn and SarychUI:GetAddOn(GLADIUS_ADDON)
end

local function ShowReloadPopup(onCancel)
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup(nil, onCancel)
		return
	end
	if StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

local function RefreshArenaOptions()
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif ACR then
		ACR:NotifyChange("SarychUI")
	end
end

local function NotifyArenaPreview(key, value, clear)
	local preview = SarychUI and SarychUI.ArenaPreview
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

local function IsGladiusExMode()
	if module.IsGladiusExMode then
		return module:IsGladiusExMode()
	end
	if SarychUI.IsAddOnEnabled then
		return SarychUI:IsAddOnEnabled(GLADIUS_ADDON)
	end
	local addons = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	return addons and addons[GLADIUS_ADDON] and addons[GLADIUS_ADDON].enabled == true
end

local function IsAwesomeWotlkDetected()
	local compat = SarychUI and SarychUI.Compatibility
	if not compat then
		return false
	end
	if compat.GetDllDetectionState then
		return compat:GetDllDetectionState("awesome_wotlk") == "detected"
	end
	if compat.DetectAwesomeWotlkDll then
		return compat:DetectAwesomeWotlkDll()
	end
	return false
end

local function GetDB()
	local root = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return root and root[moduleName]
end

local function SetGladiusExRuntime(enable)
	if SarychUI.SetArenaMode then
		SarychUI:SetArenaMode(enable and "gladiusex" or "classic")
		return
	end

	local wrapper = GetWrapper()
	if wrapper and wrapper.SetRuntimeEnabled then
		wrapper:SetRuntimeEnabled(enable)
	else
		if enable then
			SarychUI:EnableAddOn(GLADIUS_ADDON)
		else
			SarychUI:DisableAddOn(GLADIUS_ADDON)
		end
	end

	local db = GetDB()
	if db then
		db.frameType = enable and "gladiusex" or "classic"
	end
end

-- Helper
local function ToggleModule(enabled)
	local db = GetDB(); if not db then return end
	db.enabled = enabled and true or false
end

-- Options table
function module:GetOptions()
    -- snapshot original enabled when opening options (persist while panel is open)
    local db = GetDB()
    if originalEnabledSnapshot == nil then
        originalEnabledSnapshot = db and (db.enabled == true) or false
    end
    local originalEnabled = originalEnabledSnapshot
    return {
		type = "group",
		name = "Арена",
		desc = "Настройка фреймов арены",
		childGroups = "tab",
		args = {
			-- General tab — same layout pattern as Bags → Общее
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
						disabled = function()
							return IsGladiusExMode()
						end,
						get = function()
							local db = GetDB()
							return db and db.enabled or false
						end,
						set = function(_, value)
							local db = GetDB()
							if db then
								db.enabled = value and true or false
							end
						end,
					},
					reloadUI = {
						type = "execute",
						name = "Перезагрузить",
						desc = "Применить изменение статуса модуля (Reload UI)",
						order = 1.5,
						func = function()
							if ReloadUI then ReloadUI() end
						end,
						hidden = function()
							local db = GetDB(); if not db then return true end
							local current = db.enabled and true or false
							return current == (originalEnabled and true or false)
						end,
					},
					typeRow = {
						type = "group",
						name = L and (L["Arena Frame Type"] or "Тип фреймов арены") or "Тип фреймов арены",
						order = 2,
						inline = true,
						suiSelectWithButton = true,
						args = {
							frameType = {
								type = "select",
								name = "",
								desc = L and (L["Arena Frame Type Desc"] or "GladiusEx — встроенные фреймы GladiusEx. Классические WoW — стандартный модуль арены SarychUI.") or "GladiusEx — встроенные фреймы GladiusEx. Классические WoW — стандартный модуль арены SarychUI.",
								order = 1,
								values = {
									classic = L and (L["Classic WoW Arena Frames"] or "Классические WoW") or "Классические WoW",
									gladiusex = "GladiusEx",
								},
								get = function()
									return IsGladiusExMode() and "gladiusex" or "classic"
								end,
								set = function(_, value)
									local enable = (value == "gladiusex")
									local previous = IsGladiusExMode()
									if enable == previous then return end
									SetGladiusExRuntime(enable)
									RefreshArenaOptions()
									ShowReloadPopup(function()
										SetGladiusExRuntime(previous)
										RefreshArenaOptions()
									end)
								end,
							},
							openSettings = {
								type = "execute",
								name = "Настройки",
								desc = function()
									if IsGladiusExMode() then
										return L and (L["Open GladiusEx Settings Desc"] or "Открыть окно настроек GladiusEx (/gex ui).") or "Открыть окно настроек GladiusEx (/gex ui)."
									end
									return "Открыть настройки классических фреймов арены."
								end,
								order = 2,
								func = function()
									if IsGladiusExMode() then
										if SarychUI and SarychUI.OpenGladiusExConfig then
											SarychUI:OpenGladiusExConfig()
										else
											SarychUI:Print("OpenGladiusExConfig missing (options.lua not loaded?)")
										end
										return
									end
									local OC = SarychUI and SarychUI.OptionsCore
									if OC and OC.SelectTab then
										OC:SelectTab("appearance")
									end
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
					useAwesomeWotlk = {
						type = "group",
						name = "Использовать AwesomeWotlk",
						order = 4,
						inline = true,
						hidden = function()
							if IsGladiusExMode() then return true end
							local db = GetDB()
							return not (db and db.enabled)
						end,
						args = {
							notDetectedNotice = {
								type = "description",
								name = "|cffff4444AwesomeWotlk не обнаружен.|r |cff808080Статус: Система -> Обзор.|r",
								order = 0,
								width = "full",
								hidden = function()
									return IsAwesomeWotlkDetected()
								end,
							},
							enabled = {
								type = "toggle",
								name = "Включить поддержку AwesomeWotlk",
								desc = "Доступно только при обнаруженном AwesomeWotlk (Система -> Обзор).",
								order = 1,
								width = "full",
								disabled = function()
									return not IsAwesomeWotlkDetected()
								end,
								get = function()
									if not IsAwesomeWotlkDetected() then
										return false
									end
									local db = GetDB()
									return (db and db.useAwesomeWotlk == true) or false
								end,
								set = function(_, value)
									if not IsAwesomeWotlkDetected() then
										return
									end
									local db = GetDB(); if not db then return end
									db.useAwesomeWotlk = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									NotifyArenaPreview("useAwesomeWotlk", value and true or false)
									RefreshArenaOptions()
								end,
							},
						},
					},
					awesomeBenefitNote = {
						type = "description",
						name = "|cFFFFD700Пометка:|r Улучшает качество событий неймплейтов, повышает производительность и точность отображения арены.",
						order = 5,
						width = "full",
						hidden = function()
							if IsGladiusExMode() then return true end
							local db = GetDB()
							return not (db and db.enabled)
						end,
					},
				},
			},
			
			-- Settings tab (classic arena only)
			appearance = {
				type = "group",
				name = "Настройки",
				order = 2,
				hidden = function()
					return IsGladiusExMode()
				end,
				disabled = function()
					local db = GetDB()
					return not (db and db.enabled)
				end,
				args = {
					arenaPreview = {
						type = "description",
						name = "",
						order = 0,
						width = "full",
						suiArenaPreview = true,
					},
					displayBox = {
						type = "group",
						name = "Отображение",
						order = 1,
						inline = true,
						args = {
							scale = {
								type = "range",
								name = "Масштаб фреймов",
								desc = "Изменяет масштаб вражеских фреймов арены",
								order = 1,
								min = 0.5,
								max = 2.0,
								step = 0.01,
								isPercent = false,
								width = "full",
								suiPreviewKey = "scale",
								get = function()
									local db = GetDB()
									return db and (db.scale or 1.0) or 1.0
								end,
								set = function(_, value)
									local m = SarychUI.modules[moduleName]
									if m and m.SetScale then
										m:SetScale(value)
									end
									NotifyArenaPreview("scale", nil, true)
								end,
							},
							classColorHP = {
								type = "toggle",
								name = "Цвет класса для полосы здоровья",
								desc = "Красить полосу здоровья арены в цвет класса противника",
								order = 2,
								width = "full",
								get = function()
									local db = GetDB()
									-- default: enabled (true) when nil
									return db and (db.classColorHP ~= false)
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.classColorHP = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplyClassColoring then
										m:ApplyClassColoring()
									end
									NotifyArenaPreview("classColorHP", value and true or false)
								end,
							},
							distanceAlpha = {
								type = "toggle",
								name = "Включить прозрачность от дистанции",
								desc = "Делает арена фреймы полупрозрачными (50%), когда противник дальше 40 ярдов.\n\nРаботает только с AwesomeWotlk.",
								order = 3,
								width = "full",
								suiHelpIcon = true,
								hidden = function()
									local db = GetDB()
									return not (db and db.useAwesomeWotlk == true and IsAwesomeWotlkDetected())
								end,
								get = function()
									local db = GetDB()
									return (db and db.distanceAlpha == true) or false
								end,
								set = function(_, value)
									local db = GetDB(); if not db then return end
									db.distanceAlpha = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									NotifyArenaPreview("distanceAlpha", value and true or false)
								end,
							},
						},
					},
					positionTestBox = {
						type = "group",
						name = "Расположение и тестирование",
						order = 2,
						inline = true,
						args = {
							freeMove = {
								type = "execute",
								name = function()
									local db = GetDB() or {}
									if db.showDragFrame == 1 then
										return "Свободное перемещение |cff00ff00(вкл)|r"
									end
									return "Свободное перемещение"
								end,
								desc = "Показать зелёную рамку для перетаскивания контейнера арены",
								order = 1,
								width = "full",
								func = function()
									local db = GetDB()
									if not db then return end
									local val = not (db.showDragFrame == 1)
									db.showDragFrame = val and 1 or 0
									if val and db.showGrid ~= 1 then
										db.showGrid = 1
									end
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									RefreshArenaOptions()
								end,
							},
							showGrid = {
								type = "toggle",
								name = "Показать сетку выравнивания",
								desc = "Показать вспомогательную сетку при перемещении",
								order = 2,
								width = "full",
								disabled = function()
									local db = GetDB()
									return not (db and db.showDragFrame == 1)
								end,
								hidden = function()
									local db = GetDB()
									return not (db and db.showDragFrame == 1)
								end,
								get = function()
									local db = GetDB()
									return db and db.showGrid == 1
								end,
								set = function(_, value)
									local db = GetDB()
									if db then
										db.showGrid = value and 1 or 0
										local m = SarychUI.modules[moduleName]
										if m and m.ApplySettings then
											m:ApplySettings()
										end
									end
								end,
							},
							test2 = {
								type = "toggle",
								name = "Показать 2 арена фрейма",
								desc = "Показать 2 тестовых фрейма",
								order = 3,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.testMode == 2
								end,
								set = function(_, value)
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if value then
										db.testMode = 2
										if m.Test then m:Test(2) end
									else
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									end
								end,
							},
							test3 = {
								type = "toggle",
								name = "Показать 3 арена фрейма",
								desc = "Показать 3 тестовых фрейма",
								order = 4,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.testMode == 3
								end,
								set = function(_, value)
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if value then
										db.testMode = 3
										if m.Test then m:Test(3) end
									else
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									end
								end,
							},
							test5 = {
								type = "toggle",
								name = "Показать 5 арена фреймов",
								desc = "Показать 5 тестовых фреймов",
								order = 5,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.testMode == 5
								end,
								set = function(_, value)
									local db = GetDB()
									local m = SarychUI.modules[moduleName]
									if not db or not m then return end
									if value then
										db.testMode = 5
										if m.Test then m:Test(5) end
									else
										db.testMode = 0
										if m.HideArenaEnemyFrames then m:HideArenaEnemyFrames() end
									end
								end,
							},
						},
					},
					trinketsBox = {
						type = "group",
						name = "Тринкеты и расовые способности",
						order = 3,
						inline = true,
						args = {
							trinketEnabled = {
								type = "toggle",
								name = "Включить тринкеты",
								desc = "Включить отображение иконок тринкетов",
								order = 1,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and db.Trinkets.enabled or false
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.enabled = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									NotifyArenaPreview("trinketEnabled", value and true or false)
								end,
							},
							racialEnabled = {
								type = "toggle",
								name = "Включить расовую способность",
								desc = "Включить отображение иконок расовых способностей",
								order = 2,
								width = "full",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and db.Trinkets.racialEnabled or false
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.racialEnabled = value and true or false
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									NotifyArenaPreview("racialEnabled", value and true or false)
								end,
							},
							trinketsScale = {
								type = "range",
								name = "Масштаб иконок",
								desc = "Изменяет масштаб иконок тринкетов и расовых способностей",
								order = 3,
								min = 0.5,
								max = 2.0,
								step = 0.01,
								width = "full",
								suiPreviewKey = "trinketsScale",
								get = function()
									local db = GetDB()
									return db and db.Trinkets and (db.Trinkets.scale or 1.0) or 1.0
								end,
								set = function(_, value)
									local db = GetDB()
									if not db then return end
									db.Trinkets = db.Trinkets or {}
									db.Trinkets.scale = tonumber(value) or 1.0
									local m = SarychUI.modules[moduleName]
									if m and m.ApplySettings then
										m:ApplySettings()
									end
									NotifyArenaPreview("trinketsScale", nil, true)
								end,
							},
						},
					},
				},
			},
		},
	}
end


