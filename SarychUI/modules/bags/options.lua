-- SarychUI Bags Module - Options

local moduleName = "bags"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local function DB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile(moduleName)
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules[moduleName]
end

local function AutomationDB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile("automation")
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules.automation
end

local function ShowReloadPopup(onCancel)
	local text = "Для применения режима сумок требуется перезагрузка интерфейса."
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup(text, onCancel)
		return
	end
	if StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

local function isOn(key)
	local automation = AutomationDB()
	if not automation then return false end
	local v = automation[key]
	return v == 1 or v == true
end

local function toggleGetter(info)
	local automation = AutomationDB()
	if not automation then return false end
	local key = info[#info]
	local v = automation[key]
	return v == 1 or v == true
end

local function toggleSetter(info, val)
	local automation = AutomationDB()
	if not automation then return end
	automation[info[#info]] = val and 1 or 0
	if module.ApplyMode then module:ApplyMode() end
	if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
end

local pendingBagSortPinnedInput = ""

local function RefreshBagsOptionsPanel()
	-- Rebuild bags options (pinned list is built once per GetOptions call),
	-- then invalidate the custom /sui section cache so the open panel redraws.
	if SarychUI and SarychUI.RebuildModuleOptions then
		if SarychUI.OptionsCore and SarychUI.OptionsCore.InvalidateStructure then
			SarychUI.OptionsCore:InvalidateStructure()
		end
		SarychUI:RebuildModuleOptions("bags")
		return
	end
	local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)
	if not AceConfigRegistry or not module.GetOptions then return end
	local getter = AceConfigRegistry:GetOptionsTable("SarychUI")
	if not getter then return end
	local ok, optionsTable = pcall(getter, "dialog", "AceConfigDialog-3.0")
	if ok and optionsTable and optionsTable.args and optionsTable.args.modules and optionsTable.args.modules.args then
		if SarychUI.GetWrappedModuleOptions then
			optionsTable.args.modules.args.bags = SarychUI:GetWrappedModuleOptions(moduleName)
		else
			optionsTable.args.modules.args.bags = module:GetOptions()
		end
	end
	if SarychUI and SarychUI.OptionsCore and SarychUI.OptionsCore.InvalidateStructure then
		SarychUI.OptionsCore:InvalidateStructure()
	end
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	else
		AceConfigRegistry:NotifyChange("SarychUI")
	end
end

local HEARTHSTONE_ITEM_ID = 6948

local function FormatPinnedItemLabel(id)
	local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(id)
	local QUALITY_COLORS = _G.ITEM_QUALITY_COLORS
	local label
	if itemName then
		local color = QUALITY_COLORS and QUALITY_COLORS[itemQuality or 1]
		if color then
			label = string.format("|cff%02x%02x%02x%s|r (ID: %s)",
				(color.r or 1) * 255, (color.g or 1) * 255, (color.b or 1) * 255,
				itemName, tostring(id))
		else
			label = string.format("%s (ID: %s)", itemName, tostring(id))
		end
	else
		label = string.format("Неизвестный предмет (ID: %s)", tostring(id))
	end
	return label, itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function module:BuildBagSortPinnedOptionsArgs()
	local args = {
		pinnedHeader = {
			type = "header",
			name = "Добавить исключение (ID предмета)",
			desc = "Исключения всегда остаются в начале основной сумки. Камень возвращения всегда занимает первый слот.",
			order = 1,
		},
		pinnedInput = {
			type = "input",
			name = "",
			desc = "Числовой ID предмета из ссылки (item:12345:…)",
			order = 2,
			width = "full",
			suiSaveButton = "Добавить",
			get = function() return pendingBagSortPinnedInput end,
			set = function(_, val)
				pendingBagSortPinnedInput = val or ""
				local id = tonumber(pendingBagSortPinnedInput)
				if not id or id <= 0 then
					SarychUI:Print("Введите корректный itemID.")
					return
				end
				if id == HEARTHSTONE_ITEM_ID then
					SarychUI:Print("Камень возвращения уже закреплён первым слотом и не добавляется в список.")
					pendingBagSortPinnedInput = ""
					return
				end
				local ok, reason = module:AddBagSortPinnedItemID(id)
				if ok then
					pendingBagSortPinnedInput = ""
					RefreshBagsOptionsPanel()
				elseif reason == "duplicate" then
					SarychUI:Print("itemID " .. id .. " уже в списке.")
				end
			end,
		},
	}

	-- Always show hearthstone first (hardcoded in bag sort, not in the editable list).
	do
		local label, icon = FormatPinnedItemLabel(HEARTHSTONE_ITEM_ID)
		args.pinnedHearthstone = {
			type = "group",
			inline = true,
			name = "",
			order = 9,
			suiCompactListRow = true,
			icon = icon,
			args = {
				idLabel = {
					type = "description",
					name = label,
					order = 1,
				},
			},
		}
	end

	local list = module:GetBagSortPinnedItemIDs()
	local shown = 0
	for i, itemID in ipairs(list) do
		local id = tonumber(itemID) or itemID
		if id ~= HEARTHSTONE_ITEM_ID then
			shown = shown + 1
			local label, icon = FormatPinnedItemLabel(id)
			args["pinnedRow_" .. tostring(id)] = {
				type = "group",
				inline = true,
				name = "",
				order = 10 + shown,
				suiCompactListRow = true,
				icon = icon,
				args = {
					idLabel = {
						type = "description",
						name = label,
						order = 1,
					},
					removeBtn = {
						type = "execute",
						name = "Удалить",
						order = 2,
						func = function()
							module:RemoveBagSortPinnedItemID(id)
							RefreshBagsOptionsPanel()
						end,
					},
				},
			}
		end
	end

	return args
end

local ANCHOR_POINTS = {
	TOPLEFT = "TOPLEFT",
	TOP = "TOP",
	TOPRIGHT = "TOPRIGHT",
	LEFT = "LEFT",
	CENTER = "CENTER",
	RIGHT = "RIGHT",
	BOTTOMLEFT = "BOTTOMLEFT",
	BOTTOM = "BOTTOM",
	BOTTOMRIGHT = "BOTTOMRIGHT",
}

local BAG_POSITION_FALLBACK = {
	point = "BOTTOMRIGHT",
	relativePoint = "BOTTOMRIGHT",
	relativeTo = "UIParent",
	x = -20,
	y = 130,
}

local BANK_POSITION_FALLBACK = {
	point = "BOTTOMRIGHT",
	relativePoint = "BOTTOMLEFT",
	relativeTo = "ElvUI_ContainerFrame",
	x = -10,
	y = 0,
}

local function EnsureElvUIDefaultPosition(db)
	db.elvui = db.elvui or {}
	if type(db.elvui.defaultPosition) ~= "table" then
		local defaults = SarychUI.defaults
			and SarychUI.defaults.profile.modules.bags
			and SarychUI.defaults.profile.modules.bags.elvui
			and SarychUI.defaults.profile.modules.bags.elvui.defaultPosition
		if type(defaults) == "table" then
			db.elvui.defaultPosition = CopyTable(defaults)
		else
			db.elvui.defaultPosition = CopyTable(BAG_POSITION_FALLBACK)
		end
	end
	return db.elvui.defaultPosition
end

local function EnsureElvUIDefaultBankPosition(db)
	db.elvui = db.elvui or {}
	if type(db.elvui.defaultBankPosition) ~= "table" then
		local defaults = SarychUI.defaults
			and SarychUI.defaults.profile.modules.bags
			and SarychUI.defaults.profile.modules.bags.elvui
			and SarychUI.defaults.profile.modules.bags.elvui.defaultBankPosition
		if type(defaults) == "table" then
			db.elvui.defaultBankPosition = CopyTable(defaults)
		else
			db.elvui.defaultBankPosition = CopyTable(BANK_POSITION_FALLBACK)
		end
	end
	return db.elvui.defaultBankPosition
end

local function EnsureElvUISettings(db)
	db.elvui = db.elvui or {}
	local bagsDefaults = SarychUI.defaults and SarychUI.defaults.profile.modules.bags
		and SarychUI.defaults.profile.modules.bags.elvui
	if bagsDefaults then
		if db.elvui.bagFont == nil then
			db.elvui.bagFont = bagsDefaults.bagFont or "Arial Narrow"
		end
		if db.elvui.bagFontOutline == nil then
			db.elvui.bagFontOutline = bagsDefaults.bagFontOutline or "OUTLINE"
		end
		if db.elvui.bagFontShadowX == nil then
			db.elvui.bagFontShadowX = bagsDefaults.bagFontShadowX ~= nil and bagsDefaults.bagFontShadowX or 0
		end
		if db.elvui.bagFontShadowY == nil then
			db.elvui.bagFontShadowY = bagsDefaults.bagFontShadowY ~= nil and bagsDefaults.bagFontShadowY or 0
		end
		if db.elvui.stackFontSize == nil then
			db.elvui.stackFontSize = bagsDefaults.stackFontSize or 13
		end
		if db.elvui.itemLevelFontSize == nil then
			db.elvui.itemLevelFontSize = bagsDefaults.itemLevelFontSize or 13
		end
		if db.elvui.showItemLevel == nil then
			db.elvui.showItemLevel = false
		end
		if db.elvui.splitMode == nil then
			db.elvui.splitMode = bagsDefaults.splitMode or "classic"
		elseif db.elvui.splitMode ~= "adibags" then
			db.elvui.splitMode = "classic"
		end
		if db.elvui.adiBagsCategories == nil then
			db.elvui.adiBagsCategories = bagsDefaults.adiBagsCategories ~= false
		end
		if db.elvui.consumableSplit == nil then
			db.elvui.consumableSplit = bagsDefaults.consumableSplit == true
		end
		if db.elvui.ammoSplit == nil then
			db.elvui.ammoSplit = bagsDefaults.ammoSplit == true
		end
		if db.elvui.questSplit == nil then
			db.elvui.questSplit = bagsDefaults.questSplit == true
		end
		if db.elvui.sectionHeaderFont == nil then
			db.elvui.sectionHeaderFont = bagsDefaults.sectionHeaderFont or "Nimrod MT"
		end
		if db.elvui.sectionHeaderFontSize == nil then
			db.elvui.sectionHeaderFontSize = bagsDefaults.sectionHeaderFontSize or 14
		end
		if db.elvui.sectionHeaderFontScale == nil then
			db.elvui.sectionHeaderFontScale = bagsDefaults.sectionHeaderFontScale or 0.75
		end
		if db.elvui.sectionHeaderFontOutline == nil then
			db.elvui.sectionHeaderFontOutline = bagsDefaults.sectionHeaderFontOutline or "NONE"
		end
		if db.elvui.sectionHeaderShadowX == nil then
			db.elvui.sectionHeaderShadowX = bagsDefaults.sectionHeaderShadowX ~= nil and bagsDefaults.sectionHeaderShadowX or 0
		end
		if db.elvui.sectionHeaderShadowY == nil then
			db.elvui.sectionHeaderShadowY = bagsDefaults.sectionHeaderShadowY ~= nil and bagsDefaults.sectionHeaderShadowY or 0
		end
		if db.elvui.scale == nil then
			db.elvui.scale = bagsDefaults.scale or 1.05
		end
		if db.elvui.windowBackgroundAlpha == nil then
			db.elvui.windowBackgroundAlpha = bagsDefaults.windowBackgroundAlpha or 0.65
		end
		if db.elvui.categoriesBackgroundAlpha == nil then
			db.elvui.categoriesBackgroundAlpha = bagsDefaults.categoriesBackgroundAlpha or 0.85
		end
		if db.elvui.dragonflightHeader == nil then
			db.elvui.dragonflightHeader = bagsDefaults.dragonflightHeader ~= false
		end
		if db.elvui.bagColumns == nil then
			db.elvui.bagColumns = bagsDefaults.bagColumns or 10
		end
		if db.elvui.bankColumns == nil then
			db.elvui.bankColumns = bagsDefaults.bankColumns or 10
		end
		if db.elvui.footerFont == nil then
			db.elvui.footerFont = bagsDefaults.footerFont or "Arial Narrow"
		end
		if db.elvui.footerFontSize == nil then
			db.elvui.footerFontSize = bagsDefaults.footerFontSize or 13
		end
		if db.elvui.footerFontOutline == nil then
			db.elvui.footerFontOutline = bagsDefaults.footerFontOutline or "NONE"
		end
		if db.elvui.footerShadowX == nil then
			db.elvui.footerShadowX = bagsDefaults.footerShadowX ~= nil and bagsDefaults.footerShadowX or 1
		end
		if db.elvui.footerShadowY == nil then
			db.elvui.footerShadowY = bagsDefaults.footerShadowY ~= nil and bagsDefaults.footerShadowY or -1
		end
		if db.elvui.footerMoneyIconSize == nil then
			db.elvui.footerMoneyIconSize = bagsDefaults.footerMoneyIconSize or 14
		end
		if db.elvui.footerCurrencyIconSize == nil then
			db.elvui.footerCurrencyIconSize = bagsDefaults.footerCurrencyIconSize or 15
		end
	end
	EnsureElvUIDefaultPosition(db)
	EnsureElvUIDefaultBankPosition(db)
	return db.elvui
end

local function GetBagFontValues()
	local values = {}
	if SarychUI and SarychUI.Media and SarychUI.Media.GetFonts then
		for _, name in ipairs(SarychUI.Media.GetFonts()) do
			values[name] = name
		end
	end
	if not next(values) then
		values["Friz Quadrata TT"] = "Friz Quadrata TT"
	end
	return values
end

function module:GetOptions()
	local function isDefaultMode()
		local db = DB()
		local mode = db and db.mode or "default"
		return mode ~= "elvui" and mode ~= "baudbag"
	end

	local function isElvUIMode()
		local db = DB()
		return (db and db.mode or "default") == "elvui"
	end

	local function isBaudBagMode()
		local db = DB()
		return (db and db.mode or "default") == "baudbag"
	end

	return {
		type = "group",
		name = "Сумки",
		desc = "Режим сумок: классические, SarychUI сумка или Baud Bag",
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
						order = 1,
						width = "full",
						get = function() return DB().enabled == true end,
						set = function(_, val)
							DB().enabled = val and true or false
							if val then SarychUI:EnableModule(moduleName) else SarychUI:DisableModule(moduleName) end
						end,
					},
					typeRow = {
						type = "group",
						name = "Тип сумок",
						order = 2,
						inline = true,
						suiSelectWithButton = true,
						args = {
							mode = {
								type = "select",
								name = "",
								desc = "Классические сумки WoW, SarychUI сумка или Baud Bag. Требуется /reload.",
								order = 1,
								values = {
									default = "Классические WoW",
									elvui = "SarychUI сумка",
									baudbag = "Baud Bag",
								},
								get = function()
									return DB().mode or "default"
								end,
								set = function(_, val)
									local previous = DB().mode or "default"
									if previous == val then return end
									DB().mode = val
									if SarychUI.SetBagsMode then
										SarychUI:SetBagsMode(val)
									end
									ShowReloadPopup(function()
										DB().mode = previous
										if SarychUI.SetBagsMode then
											SarychUI:SetBagsMode(previous)
										end
										if SarychUI and SarychUI.NotifySarychUIOptionsChange then
											SarychUI:NotifySarychUIOptionsChange()
										end
									end)
								end,
							},
							openSettings = {
								type = "execute",
								name = "Настройки",
								desc = function()
									if isElvUIMode() then
										return "Открыть настройки SarychUI сумки."
									end
									if isBaudBagMode() then
										return "Открыть настройки Baud Bag."
									end
									return "Открыть настройки стандартных сумок."
								end,
								order = 2,
								func = function()
									local OC = SarychUI and SarychUI.OptionsCore
									if not OC or not OC.SelectTab then return end
									if isElvUIMode() then
										OC:SelectTab("elvuiBags")
									elseif isBaudBagMode() then
										OC:SelectTab("baudBags")
									else
										OC:SelectTab("defaultBags")
									end
								end,
							},
						},
					},
					modeHint = {
						type = "description",
						name = function()
							if IsAddOnLoaded and IsAddOnLoaded("ElvUI") then
								return "|cffff0000Внимание:|r установлен полный |cff1784d1ElvUI|r — встроенная ElvUI-сумка будет отключена."
							end
							return "|cFFFFD700Внимание:|r После применения потребуется перезагрузка интерфейса."
						end,
						order = 3,
						width = "full",
					},
				},
			},
			defaultBags = {
				type = "group",
				name = "Стандартные сумки",
				order = 2,
				hidden = function() return not isDefaultMode() end,
				disabled = function() return not DB().enabled end,
				args = {
					bagSearchBox = {
						type = "group",
						name = "Включить строку поиска",
						order = 1,
						inline = true,
						args = {
							enableBagSearch = {
								type = "toggle",
								name = "Включить строку поиска",
								desc = "Поле поиска на окне основного рюкзака (слева от кнопки сортировки)",
								order = 1,
								width = "full",
								get = function() return DB().enableBagSearch == true end,
								set = function(_, val)
									DB().enableBagSearch = val and true or false
									if not val and module.ResetClassicBagSearch then
										module:ResetClassicBagSearch()
									end
									if module.ApplyBagSortSettings then
										module:ApplyBagSortSettings()
									end
									if SarychUI.RefreshConfig then
										SarychUI:RefreshConfig()
									end
								end,
							},
						},
					},
					bagSortBox = {
						type = "group",
						name = "Включить сортировку сумок",
						order = 2,
						inline = true,
						args = (function()
							local args = {
								enableBagSortButton = {
									type = "toggle",
									name = "Включить сортировку сумок",
									desc = "Кнопка на окне основного рюкзака",
									order = 1,
									width = "full",
									get = toggleGetter,
									set = function(info, val)
										AutomationDB().enableBagSortButton = val and 1 or 0
										if module.ApplyBagSortSettings then module:ApplyBagSortSettings() end
										RefreshBagsOptionsPanel()
										if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
									end,
								},
							}
							if isOn("enableBagSortButton") then
								local pinned = module:BuildBagSortPinnedOptionsArgs()
								for key, opt in pairs(pinned) do
									if type(opt.order) == "number" then
										opt.order = opt.order + 1
									end
									args[key] = opt
								end
							end
							return args
						end)(),
					},
				},
			},
			elvuiBags = {
				type = "group",
				name = "SarychUI сумка",
				order = 3,
				hidden = function() return not isElvUIMode() end,
				disabled = function() return not DB().enabled end,
				args = {
					consumableSplitBox = {
						type = "group",
						name = "Разделение предметов",
						order = 1,
						inline = true,
						args = {
							splitMode = {
								type = "select",
								name = "Режим разделения",
								desc = "Классическая — три опциональных группы снизу.\nAdiBags — предметы раскладываются по секциям и сортируются как в AdiBags (квест, экипировка, расходники и т.д.).",
								order = 0,
								width = "full",
								values = {
									classic = "Классическая",
									adibags = "AdiBags",
								},
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.splitMode == "adibags" and "adibags" or "classic"
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if val == "adibags" then
										elv.splitMode = "adibags"
										elv.adiBagsCategories = true
									else
										elv.splitMode = "classic"
									end
									if module.ApplyElvUIBagLayoutSettings then
										module:ApplyElvUIBagLayoutSettings()
									end
									local E = module.GetElvUIEngine and module:GetElvUIEngine()
									local B = E and E.GetModule and E:GetModule("Bags", true)
									if B and B.UpdateAllSectionSplitButtons then
										B:UpdateAllSectionSplitButtons()
									end
									if SarychUI and SarychUI.NotifySarychUIOptionsChange then
										SarychUI:NotifySarychUIOptionsChange()
									end
								end,
							},
							consumableSplit = {
								type = "toggle",
								name = "Выносить еду и восстановление в нижний ряд",
								desc = "Еда/напитки и зелья/флаконы восстановления здоровья или маны будут показаны отдельным нижним рядом, а из основной сетки визуально убраны.",
								order = 1,
								width = "full",
								suiLiveApply = true,
								hidden = function()
									local elv = EnsureElvUISettings(DB())
									return elv.splitMode == "adibags"
								end,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.consumableSplit == true
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.consumableSplit = val and true or false
									if module.ApplyElvUIBagLayoutSettings then
										module:ApplyElvUIBagLayoutSettings()
									end
								end,
							},
							ammoSplit = {
								type = "toggle",
								name = "Выносить боеприпасы отдельно",
								desc = "Стрелы, пули и похожие боеприпасы будут показаны отдельной группой в нижнем разделении.",
								order = 2,
								width = "full",
								suiLiveApply = true,
								hidden = function()
									local elv = EnsureElvUISettings(DB())
									return elv.splitMode == "adibags"
								end,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.ammoSplit == true
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.ammoSplit = val and true or false
									if module.ApplyElvUIBagLayoutSettings then
										module:ApplyElvUIBagLayoutSettings()
									end
								end,
							},
							questSplit = {
								type = "toggle",
								name = "Выносить квестовые предметы отдельно",
								desc = "Квестовые предметы будут показаны отдельной группой в нижнем разделении.",
								order = 3,
								width = "full",
								suiLiveApply = true,
								hidden = function()
									local elv = EnsureElvUISettings(DB())
									return elv.splitMode == "adibags"
								end,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.questSplit == true
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.questSplit = val and true or false
									if module.ApplyElvUIBagLayoutSettings then
										module:ApplyElvUIBagLayoutSettings()
									end
								end,
							},
							sectionHeaderFontBox = {
								type = "group",
								name = "Шрифт заголовков секций",
								desc = "Шрифт названий секций (Задания, Экипировка и т.д.) в режиме AdiBags.",
								order = 10,
								inline = true,
								suiTwoCol = true,
								hidden = function()
									local elv = EnsureElvUISettings(DB())
									return elv.splitMode ~= "adibags"
								end,
								args = {
									sectionHeaderFont = {
										type = "select",
										style = "dropdown",
										name = "Шрифт",
										order = 1,
										width = "full",
										suiFullRow = true,
										values = GetBagFontValues,
										get = function()
											local elv = EnsureElvUISettings(DB())
											return elv.sectionHeaderFont or "Nimrod MT"
										end,
										set = function(_, val)
											local elv = EnsureElvUISettings(DB())
											elv.sectionHeaderFont = val
											if module.ApplyElvUIBagLayoutSettings then
												module:ApplyElvUIBagLayoutSettings()
											end
										end,
									},
									sectionHeaderFontSize = {
										type = "range",
										name = "Размер шрифта",
										order = 2,
										min = 8,
										max = 28,
										step = 1,
										suiLiveApply = true,
										get = function()
											local elv = EnsureElvUISettings(DB())
											return elv.sectionHeaderFontSize or 14
										end,
										set = function(_, val)
											local elv = EnsureElvUISettings(DB())
											if elv.sectionHeaderFontSize == val then return end
											elv.sectionHeaderFontSize = val
											if module.ApplyElvUIBagLayoutSettings then
												module:ApplyElvUIBagLayoutSettings()
											end
										end,
									},
									sectionHeaderFontScale = {
										type = "range",
										name = "Масштаб шрифта",
										desc = "Дополнительный масштаб текста заголовков категорий (1 = как размер выше).",
										order = 3,
										min = 0.7,
										max = 1.5,
										step = 0.05,
										suiLiveApply = true,
										get = function()
											local elv = EnsureElvUISettings(DB())
											return elv.sectionHeaderFontScale or 0.75
										end,
										set = function(_, val)
											local elv = EnsureElvUISettings(DB())
											if elv.sectionHeaderFontScale == val then return end
											elv.sectionHeaderFontScale = val
											if module.ApplyElvUIBagLayoutSettings then
												module:ApplyElvUIBagLayoutSettings()
											end
										end,
									},
									sectionHeaderFontOutline = {
										type = "select",
										style = "dropdown",
										name = "Обводка",
										order = 4,
										values = {
											NONE = "Нет",
											OUTLINE = "OUTLINE",
											THICKOUTLINE = "THICKOUTLINE",
											MONOCHROME = "MONOCHROME",
											MONOCHROMEOUTLINE = "MONOCHROMEOUTLINE",
										},
										get = function()
											local elv = EnsureElvUISettings(DB())
											return elv.sectionHeaderFontOutline or "NONE"
										end,
										set = function(_, val)
											local elv = EnsureElvUISettings(DB())
											elv.sectionHeaderFontOutline = val
											if module.ApplyElvUIBagLayoutSettings then
												module:ApplyElvUIBagLayoutSettings()
											end
										end,
									},
									sectionHeaderShadowX = {
										type = "range",
										name = "Тень X",
										order = 5,
										min = -5,
										max = 5,
										step = 1,
										suiLiveApply = true,
										get = function()
											local elv = EnsureElvUISettings(DB())
											return elv.sectionHeaderShadowX ~= nil and elv.sectionHeaderShadowX or 0
										end,
										set = function(_, val)
											local elv = EnsureElvUISettings(DB())
											if elv.sectionHeaderShadowX == val then return end
											elv.sectionHeaderShadowX = val
											if module.ApplyElvUIBagLayoutSettings then
												module:ApplyElvUIBagLayoutSettings()
											end
										end,
									},
									sectionHeaderShadowY = {
										type = "range",
										name = "Тень Y",
										order = 6,
										min = -5,
										max = 5,
										step = 1,
										suiLiveApply = true,
										get = function()
											local elv = EnsureElvUISettings(DB())
											return elv.sectionHeaderShadowY ~= nil and elv.sectionHeaderShadowY or 0
										end,
										set = function(_, val)
											local elv = EnsureElvUISettings(DB())
											if elv.sectionHeaderShadowY == val then return end
											elv.sectionHeaderShadowY = val
											if module.ApplyElvUIBagLayoutSettings then
												module:ApplyElvUIBagLayoutSettings()
											end
										end,
									},
								},
							},
						},
					},
					scaleBox = {
						type = "group",
						name = "Масштаб и фон",
						order = 2,
						inline = true,
						suiTwoCol = true,
						args = {
							scale = {
								type = "range",
								name = "Масштаб окна",
								desc = "Масштаб окон сумки и банка (1.0 = 100%). Независимо от остальных настроек размера.",
								order = 1,
								min = 0.5,
								max = 2.0,
								step = 0.05,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.scale or 1.05
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.scale == val then return end
									elv.scale = val
									if module.ApplyElvUIBagScaleSettings then
										module:ApplyElvUIBagScaleSettings()
									end
								end,
							},
							windowBackgroundAlpha = {
								type = "range",
								name = "Прозрачность фона окна",
								desc = "Фон окна сумки и банка без категорий предметов. По умолчанию 65%. 0 — полностью прозрачный, 1 — непрозрачный.",
								order = 2,
								min = 0,
								max = 1,
								step = 0.05,
								isPercent = true,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.windowBackgroundAlpha or 0.65
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.windowBackgroundAlpha == val then return end
									elv.windowBackgroundAlpha = val
									if module.ApplyElvUIBagChromeSettings then
										module:ApplyElvUIBagChromeSettings()
									end
								end,
							},
							categoriesBackgroundAlpha = {
								type = "range",
								name = "Прозрачность фона (категории)",
								desc = "Фон окна, когда включены «категории предметов» (AdiBags). По умолчанию 85%.",
								order = 3,
								min = 0,
								max = 1,
								step = 0.05,
								isPercent = true,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.categoriesBackgroundAlpha or 0.85
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.categoriesBackgroundAlpha == val then return end
									elv.categoriesBackgroundAlpha = val
									if module.ApplyElvUIBagChromeSettings then
										module:ApplyElvUIBagChromeSettings()
									end
								end,
							},
							dragonflightHeader = {
								type = "toggle",
								name = "Шапка в стиле Dragonflight",
								desc = "Декоративная полоса заголовка из текстуры трекера заданий (Dragonflight) на окне сумки и банка.",
								order = 4,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.dragonflightHeader ~= false
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									val = not not val
									if elv.dragonflightHeader == val then return end
									elv.dragonflightHeader = val
									if module.ApplyElvUIBagLayoutSettings then
										module:ApplyElvUIBagLayoutSettings()
									elseif module.ApplyElvUIBagChromeSettings then
										module:ApplyElvUIBagChromeSettings()
									end
								end,
							},
						},
					},
					layoutBox = {
						type = "group",
						name = "Раскладка",
						order = 3,
						inline = true,
						suiTwoCol = true,
						args = {
							bagColumns = {
								type = "range",
								name = "Ячеек в строке (сумка)",
								desc = "Количество слотов в одной строке окна сумки. Высота окна подстроится автоматически.",
								order = 1,
								min = 6,
								max = 14,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.bagColumns or 10
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.bagColumns == val then return end
									elv.bagColumns = val
									if module.ApplyElvUIBagLayoutSettings then
										module:ApplyElvUIBagLayoutSettings()
									end
								end,
							},
							bankColumns = {
								type = "range",
								name = "Ячеек в строке (банк)",
								desc = "Количество слотов в одной строке окна банка. Высота окна подстроится автоматически.",
								order = 2,
								min = 6,
								max = 14,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.bankColumns or 10
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.bankColumns == val then return end
									elv.bankColumns = val
									if module.ApplyElvUIBagLayoutSettings then
										module:ApplyElvUIBagLayoutSettings()
									end
								end,
							},
						},
					},
					generalBox = {
						type = "group",
						name = "Основные",
						order = 4,
						inline = true,
						args = {
							vendorGraysAuto = {
								type = "toggle",
								name = "Автопродажа серого у торговца",
								order = 1,
								width = "full",
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.vendorGraysAuto == true
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.vendorGraysAuto = val and true or false
									if module.ApplyMode then module:ApplyMode() end
								end,
							},
						},
					},
					fontBox = {
						type = "group",
						name = "Шрифт слотов",
						desc = "Шрифт, обводка и тень только для стаков и уровня предметов.",
						order = 5,
						inline = true,
						suiTwoCol = true,
						args = {
							bagFont = {
								type = "select",
								style = "dropdown",
								name = "Шрифт",
								desc = "Шрифт текста стаков и уровня предметов на слотах.",
								order = 1,
								width = "full",
								suiFullRow = true,
								values = GetBagFontValues,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.bagFont or "Arial Narrow"
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.bagFont = val
									if module.ApplyElvUIBagFontSettings then
										module:ApplyElvUIBagFontSettings()
									end
								end,
							},
							bagFontOutline = {
								type = "select",
								style = "dropdown",
								name = "Обводка",
								order = 2,
								values = {
									NONE = "Нет",
									OUTLINE = "OUTLINE",
									THICKOUTLINE = "THICKOUTLINE",
									MONOCHROME = "MONOCHROME",
									MONOCHROMEOUTLINE = "MONOCHROMEOUTLINE",
								},
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.bagFontOutline or "OUTLINE"
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.bagFontOutline = val
									if module.ApplyElvUIBagFontSettings then
										module:ApplyElvUIBagFontSettings()
									end
								end,
							},
							bagFontShadowX = {
								type = "range",
								name = "Тень X",
								order = 3,
								min = -5,
								max = 5,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.bagFontShadowX ~= nil and elv.bagFontShadowX or 0
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.bagFontShadowX == val then return end
									elv.bagFontShadowX = val
									if module.ApplyElvUIBagFontSettings then
										module:ApplyElvUIBagFontSettings()
									end
								end,
							},
							bagFontShadowY = {
								type = "range",
								name = "Тень Y",
								order = 4,
								min = -5,
								max = 5,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.bagFontShadowY ~= nil and elv.bagFontShadowY or 0
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.bagFontShadowY == val then return end
									elv.bagFontShadowY = val
									if module.ApplyElvUIBagFontSettings then
										module:ApplyElvUIBagFontSettings()
									end
								end,
							},
							stackFontSize = {
								type = "range",
								name = "Размер текста стаков",
								order = 5,
								min = 8,
								max = 24,
								step = 1,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.stackFontSize or 13
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.stackFontSize = val
									if module.ApplyElvUIBagFontSettings then
										module:ApplyElvUIBagFontSettings()
									end
								end,
							},
							showItemLevel = {
								type = "toggle",
								name = "Показывать уровень предметов",
								order = 6,
								width = "full",
								suiFullRow = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.showItemLevel == true
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.showItemLevel = val and true or false
									if module.ApplyElvUIBagFontSettings then
										module:ApplyElvUIBagFontSettings()
									end
								end,
							},
							itemLevelFontSize = {
								type = "range",
								name = "Размер текста уровня предмета",
								order = 7,
								min = 8,
								max = 24,
								step = 1,
								disabled = function()
									local elv = EnsureElvUISettings(DB())
									return elv.showItemLevel ~= true
								end,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.itemLevelFontSize or 13
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.itemLevelFontSize = val
									if module.ApplyElvUIBagFontSettings then
										module:ApplyElvUIBagFontSettings()
									end
								end,
							},
						},
					},
					footerBox = {
						type = "group",
						name = "Нижний ряд",
						desc = "Деньги и отслеживаемые валюты внизу окна сумки.",
						order = 6,
						inline = true,
						suiTwoCol = true,
						args = {
							footerFont = {
								type = "select",
								style = "dropdown",
								name = "Шрифт",
								order = 1,
								width = "full",
								suiFullRow = true,
								values = GetBagFontValues,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.footerFont or "Arial Narrow"
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.footerFont = val
									if module.ApplyElvUIBagFooterSettings then
										module:ApplyElvUIBagFooterSettings()
									end
								end,
							},
							footerFontSize = {
								type = "range",
								name = "Размер шрифта",
								order = 2,
								min = 8,
								max = 28,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.footerFontSize or 13
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.footerFontSize == val then return end
									elv.footerFontSize = val
									if module.ApplyElvUIBagFooterSettings then
										module:ApplyElvUIBagFooterSettings()
									end
								end,
							},
							footerFontOutline = {
								type = "select",
								style = "dropdown",
								name = "Обводка",
								order = 3,
								values = {
									NONE = "Нет",
									OUTLINE = "OUTLINE",
									THICKOUTLINE = "THICKOUTLINE",
									MONOCHROME = "MONOCHROME",
									MONOCHROMEOUTLINE = "MONOCHROMEOUTLINE",
								},
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.footerFontOutline or "NONE"
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									elv.footerFontOutline = val
									if module.ApplyElvUIBagFooterSettings then
										module:ApplyElvUIBagFooterSettings()
									end
								end,
							},
							footerShadowX = {
								type = "range",
								name = "Тень X",
								order = 4,
								min = -5,
								max = 5,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.footerShadowX ~= nil and elv.footerShadowX or 1
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.footerShadowX == val then return end
									elv.footerShadowX = val
									if module.ApplyElvUIBagFooterSettings then
										module:ApplyElvUIBagFooterSettings()
									end
								end,
							},
							footerShadowY = {
								type = "range",
								name = "Тень Y",
								order = 5,
								min = -5,
								max = 5,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.footerShadowY ~= nil and elv.footerShadowY or -1
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.footerShadowY == val then return end
									elv.footerShadowY = val
									if module.ApplyElvUIBagFooterSettings then
										module:ApplyElvUIBagFooterSettings()
									end
								end,
							},
							footerMoneyIconSize = {
								type = "range",
								name = "Иконки денег",
								order = 6,
								min = 10,
								max = 28,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.footerMoneyIconSize or 14
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.footerMoneyIconSize == val then return end
									elv.footerMoneyIconSize = val
									if module.ApplyElvUIBagFooterSettings then
										module:ApplyElvUIBagFooterSettings()
									end
								end,
							},
							footerCurrencyIconSize = {
								type = "range",
								name = "Иконки валют",
								order = 7,
								min = 10,
								max = 28,
								step = 1,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.footerCurrencyIconSize or 15
								end,
								set = function(_, val)
									local elv = EnsureElvUISettings(DB())
									if elv.footerCurrencyIconSize == val then return end
									elv.footerCurrencyIconSize = val
									if module.ApplyElvUIBagFooterSettings then
										module:ApplyElvUIBagFooterSettings()
									end
								end,
							},
						},
					},
					bagPositionGroup = {
						type = "group",
						name = "Окно сумки игрока",
						inline = true,
						suiTwoCol = true,
						order = 7,
						args = {
							bagPositionPoint = {
								type = "select",
								name = "Точка привязки",
								order = 1,
								width = "full",
								suiFullRow = true,
								values = ANCHOR_POINTS,
								get = function()
									local pos = EnsureElvUIDefaultPosition(DB())
									return pos.point or "BOTTOMRIGHT"
								end,
								set = function(_, val)
									local pos = EnsureElvUIDefaultPosition(DB())
									pos.point = val
									pos.relativePoint = val
									pos.relativeTo = pos.relativeTo or "UIParent"
									module:ApplyElvUIBagWindowPositionIfDefault()
								end,
							},
							bagPositionX = {
								type = "range",
								name = "X",
								order = 2,
								min = -1000,
								max = 1000,
								step = 1,
								get = function()
									local pos = EnsureElvUIDefaultPosition(DB())
									return pos.x or -20
								end,
								set = function(_, val)
									local pos = EnsureElvUIDefaultPosition(DB())
									pos.x = val
									module:ApplyElvUIBagWindowPositionIfDefault()
								end,
							},
							bagPositionY = {
								type = "range",
								name = "Y",
								order = 3,
								min = -1000,
								max = 1000,
								step = 1,
								get = function()
									local pos = EnsureElvUIDefaultPosition(DB())
									return pos.y or 130
								end,
								set = function(_, val)
									local pos = EnsureElvUIDefaultPosition(DB())
									pos.y = val
									module:ApplyElvUIBagWindowPositionIfDefault()
								end,
							},
							resetBagWindowPosition = {
								type = "execute",
								name = "Сбросить позицию сумки",
								order = 4,
								width = "full",
								func = function()
									module:ClearElvUIBagSavedWindowPosition()
									if SarychUI and SarychUI.Print then
										SarychUI:Print("Позиция окна SarychUI сумки сброшена.")
									end
								end,
							},
						},
					},
					bankPositionGroup = {
						type = "group",
						name = "Окно банка",
						inline = true,
						suiTwoCol = true,
						order = 8,
						args = {
							bankPositionPoint = {
								type = "select",
								name = "Точка привязки",
								order = 1,
								width = "full",
								suiFullRow = true,
								values = ANCHOR_POINTS,
								get = function()
									local pos = EnsureElvUIDefaultBankPosition(DB())
									return pos.point or "BOTTOMRIGHT"
								end,
								set = function(_, val)
									local pos = EnsureElvUIDefaultBankPosition(DB())
									pos.point = val
									pos.relativePoint = val
									if not pos.relativeTo or pos.relativeTo == "" then
										pos.relativeTo = "ElvUI_ContainerFrame"
									end
									module:ApplyElvUIBankWindowPositionIfDefault()
								end,
							},
							bankPositionX = {
								type = "range",
								name = "X",
								order = 2,
								min = -1000,
								max = 1000,
								step = 1,
								get = function()
									local pos = EnsureElvUIDefaultBankPosition(DB())
									return pos.x or -10
								end,
								set = function(_, val)
									local pos = EnsureElvUIDefaultBankPosition(DB())
									pos.x = val
									module:ApplyElvUIBankWindowPositionIfDefault()
								end,
							},
							bankPositionY = {
								type = "range",
								name = "Y",
								order = 3,
								min = -1000,
								max = 1000,
								step = 1,
								get = function()
									local pos = EnsureElvUIDefaultBankPosition(DB())
									return pos.y or 0
								end,
								set = function(_, val)
									local pos = EnsureElvUIDefaultBankPosition(DB())
									pos.y = val
									module:ApplyElvUIBankWindowPositionIfDefault()
								end,
							},
							resetBankWindowPosition = {
								type = "execute",
								name = "Сбросить позицию банка",
								order = 4,
								width = "full",
								func = function()
									module:ClearElvUIBankSavedWindowPosition()
									if SarychUI and SarychUI.Print then
										SarychUI:Print("Позиция окна банка SarychUI сумки сброшена.")
									end
								end,
							},
						},
					},
				},
			},
			baudBags = {
				type = "group",
				name = "Baud Bag",
				order = 4,
				hidden = function() return not isBaudBagMode() end,
				disabled = function() return not DB().enabled end,
				args = (function()
					local args = {
						bagSearchBox = {
							type = "group",
							name = "Включить строку поиска",
							order = 1,
							inline = true,
							args = {
								enableBagSearch = {
									type = "toggle",
									name = "Включить строку поиска",
									desc = "Поле поиска на окне основной сумки Baud Bag (слева от кнопки сортировки)",
									order = 1,
									width = "full",
									get = function() return DB().enableBagSearch == true end,
									set = function(_, val)
										DB().enableBagSearch = val and true or false
										if not val and module.ResetClassicBagSearch then
											module:ResetClassicBagSearch()
										end
										if module.ApplyBagSortSettings then
											module:ApplyBagSortSettings()
										end
										if SarychUI.RefreshConfig then
											SarychUI:RefreshConfig()
										end
									end,
								},
							},
						},
						bagSortBox = {
							type = "group",
							name = "Включить сортировку сумок",
							order = 2,
							inline = true,
							args = (function()
								local sortArgs = {
									enableBagSortButton = {
										type = "toggle",
										name = "Включить сортировку сумок",
										desc = "Кнопка на окне основной сумки Baud Bag",
										order = 1,
										width = "full",
										get = toggleGetter,
										set = function(info, val)
											AutomationDB().enableBagSortButton = val and 1 or 0
											if module.ApplyBagSortSettings then module:ApplyBagSortSettings() end
											RefreshBagsOptionsPanel()
											if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
										end,
									},
								}
								if isOn("enableBagSortButton") then
									local pinned = module:BuildBagSortPinnedOptionsArgs()
									for key, opt in pairs(pinned) do
										if type(opt.order) == "number" then
											opt.order = opt.order + 1
										end
										sortArgs[key] = opt
									end
								end
								return sortArgs
							end)(),
						},
						baudSettingsHeader = {
							type = "header",
							name = "Настройки Baud Bag",
							order = 3,
						},
						openBaudBagOptions = {
							type = "execute",
							name = "Открыть настройки Baud Bag",
							desc = "Открывает окно настроек Baud Bag (/baudbag).",
							order = 4,
							width = "full",
							func = function()
								local wrap = _G.SarychUI_BaudBag
								if wrap and wrap.ShowOptions then
									wrap:ShowOptions()
									return
								end
								if BaudBagOptionsFrame then
									BaudBagOptionsFrame:SetFrameStrata("FULLSCREEN_DIALOG")
									BaudBagOptionsFrame:Raise()
									BaudBagOptionsFrame:Show()
								end
							end,
						},
					}
					return args
				end)(),
			},
		},
	}
end
