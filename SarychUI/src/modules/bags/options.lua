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

local function ShowReloadPopup(onCancel, text)
	text = text or SarychUI:T("ui.options_3e8db8131c")
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup(text, onCancel)
		return
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
local pendingCustomCategoryName = ""
local pendingCustomCategoryID
local pendingCustomItemInput = ""

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
		label = string.format(SarychUI:T("ui.options_92b8f6200e"), tostring(id))
	end
	return label, itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ParseCustomCategoryItemID(value)
	value = tostring(value or "")
	local itemID = tonumber(value) or tonumber(value:match("item:(%d+)"))
	if itemID and itemID > 0 then return math.floor(itemID) end
	local _, link = GetItemInfo(value)
	return link and tonumber(link:match("item:(%d+)")) or nil
end

local function SortedCustomCategoryItemIDs(category)
	local result, seen = {}, {}
	for rawID, enabled in pairs((category and category.items) or {}) do
		local itemID = enabled and tonumber(rawID)
		if itemID and itemID > 0 and not seen[itemID] then
			seen[itemID] = true
			result[#result + 1] = itemID
		end
	end
	table.sort(result)
	return result
end

function module:BuildCustomCategoryOptionsArgs()
	local categories = self:GetCustomBagCategories()
	local categoryValues = {}
	local selectedExists
	for _, category in ipairs(categories) do
		local id = tonumber(category.id)
		if id then
			categoryValues[id] = category.name
			if id == tonumber(pendingCustomCategoryID) then selectedExists = true end
		end
	end
	if not selectedExists then
		pendingCustomCategoryID = categories[1] and tonumber(categories[1].id) or nil
	end
	if not next(categoryValues) then
		categoryValues[0] = SarychUI:T("ui.options_a652aa1e39")
	end

	local args = {
		intro = {
			type = "description",
			name = "ui.text_b6c9ee32",
			order = 1,
		},
		newCategory = {
			type = "input",
			name = "ui.text_1e01ce34",
			desc = "ui.text_a1b68a8d",
			order = 2,
			width = "full",
			suiSaveButton = SarychUI:T("ui.options_84370a2097"),
			get = function() return pendingCustomCategoryName end,
			set = function(_, value)
				pendingCustomCategoryName = value or ""
				local ok, result = module:AddCustomBagCategory(pendingCustomCategoryName)
				if ok then
					pendingCustomCategoryName = ""
					pendingCustomCategoryID = result
					module:ApplyCustomBagCategories()
					RefreshBagsOptionsPanel()
				elseif result == "duplicate" then
					SarychUI:Print(SarychUI:T("ui.options_0d59ff51bc"))
				elseif result == "reserved" then
					SarychUI:Print(SarychUI:T("ui.options_821ea586ac"))
				else
					SarychUI:Print(SarychUI:T("ui.options_88c062bcae"))
				end
			end,
		},
		category = {
			type = "select",
			name = "ui.text_362b0189",
			order = 3,
			width = "full",
			values = categoryValues,
			disabled = function() return #module:GetCustomBagCategories() == 0 end,
			get = function() return pendingCustomCategoryID or 0 end,
			set = function(_, value) pendingCustomCategoryID = tonumber(value) end,
		},
		newItem = {
			type = "input",
			name = "ui.text_47703f98",
			desc = "ui.itemid_5910af5f",
			order = 4,
			width = "full",
			suiSaveButton = SarychUI:T("ui.options_559a87f7cc"),
			disabled = function() return not pendingCustomCategoryID end,
			get = function() return pendingCustomItemInput end,
			set = function(_, value)
				pendingCustomItemInput = value or ""
				local itemID = ParseCustomCategoryItemID(pendingCustomItemInput)
				if not itemID then
					SarychUI:Print(SarychUI:T("ui.options_c06133658c"))
					return
				end
				local ok, reason = module:AddItemToCustomBagCategory(pendingCustomCategoryID, itemID)
				if ok then
					pendingCustomItemInput = ""
					module:ApplyCustomBagCategories()
					RefreshBagsOptionsPanel()
				elseif reason == "duplicate" then
					SarychUI:Print(SarychUI:T("ui.options_f6eaa84da9"))
				else
					SarychUI:Print(SarychUI:T("ui.options_b37b0742c3"))
				end
			end,
		},
	}

	for index, category in ipairs(categories) do
		local categoryID = tonumber(category.id)
		local itemIDs = SortedCustomCategoryItemIDs(category)
		local categoryArgs = {
			rename = {
				type = "input",
				name = "ui.text_0918b4ba",
				order = 1,
				width = "full",
				suiSaveButton = SarychUI:T("ui.options_715e8f0c32"),
				suiKeepInput = true,
				get = function()
					local current = module:FindCustomBagCategory(categoryID)
					return current and current.name or ""
				end,
				set = function(_, value)
					local ok, reason = module:RenameCustomBagCategory(categoryID, value)
					if ok then
						module:ApplyCustomBagCategories()
						RefreshBagsOptionsPanel()
					elseif reason == "duplicate" then
						SarychUI:Print(SarychUI:T("ui.options_0d59ff51bc"))
					elseif reason == "reserved" then
						SarychUI:Print(SarychUI:T("ui.options_821ea586ac"))
					else
						SarychUI:Print(SarychUI:T("ui.options_88c062bcae"))
					end
				end,
			},
			count = {
				type = "description",
				name = string.format(SarychUI:T("ui.options_448cd691ec"), #itemIDs),
				order = 2,
			},
			up = {
				type = "execute",
				name = "ui.text_357ccc3e",
				order = 3,
				disabled = index == 1,
				func = function()
					module:MoveCustomBagCategory(categoryID, "up")
					module:ApplyCustomBagCategories()
					RefreshBagsOptionsPanel()
				end,
			},
			down = {
				type = "execute",
				name = "ui.text_443c49da",
				order = 4,
				disabled = index == #categories,
				func = function()
					module:MoveCustomBagCategory(categoryID, "down")
					module:ApplyCustomBagCategories()
					RefreshBagsOptionsPanel()
				end,
			},
			removeCategory = {
				type = "execute",
				name = "ui.text_121c72af",
				order = 5,
				confirm = true,
				confirmText = "ui.text_4891095d",
				func = function()
					module:RemoveCustomBagCategory(categoryID)
					if tonumber(pendingCustomCategoryID) == categoryID then pendingCustomCategoryID = nil end
					module:ApplyCustomBagCategories()
					RefreshBagsOptionsPanel()
				end,
			},
		}

		for itemIndex, itemID in ipairs(itemIDs) do
			local id = itemID
			local label, icon = FormatPinnedItemLabel(id)
			categoryArgs["item_" .. id] = {
				type = "group",
				inline = true,
				name = "",
				order = 10 + itemIndex,
				suiCompactListRow = true,
				icon = icon,
				args = {
					label = { type = "description", name = label, order = 1 },
					remove = {
						type = "execute",
						name = "ui.text_07cb6508",
						order = 2,
						func = function()
							module:RemoveItemFromCustomBagCategory(categoryID, id)
							module:ApplyCustomBagCategories()
							RefreshBagsOptionsPanel()
						end,
					},
				},
			}
		end

		args["category_" .. tostring(categoryID or index)] = {
			type = "group",
			name = category.name,
			inline = true,
			order = 100 + index,
			args = categoryArgs,
		}
	end

	return args
end

function module:BuildBagSortPinnedOptionsArgs()
	local args = {
		pinnedHeader = {
			type = "header",
			name = "ui.add_exception_item_id_3880a256",
			desc = "ui.exceptions_always_stay_at_the_start_of_the_main__5c82d7e7",
			order = 1,
		},
		pinnedInput = {
			type = "input",
			name = "",
			desc = "ui.numeric_item_id_from_the_link_item_12345_f7bfcea7",
			order = 2,
			width = "full",
			suiSaveButton = SarychUI:T("ui.options_559a87f7cc"),
			get = function() return pendingBagSortPinnedInput end,
			set = function(_, val)
				pendingBagSortPinnedInput = val or ""
				local id = tonumber(pendingBagSortPinnedInput)
				if not id or id <= 0 then
					SarychUI:Print(SarychUI:T("ui.options_388272c1b7"))
					return
				end
				if id == HEARTHSTONE_ITEM_ID then
					SarychUI:Print(SarychUI:T("ui.options_b199f63f05"))
					pendingBagSortPinnedInput = ""
					return
				end
				local ok, reason = module:AddBagSortPinnedItemID(id)
				if ok then
					pendingBagSortPinnedInput = ""
					RefreshBagsOptionsPanel()
				elseif reason == "duplicate" then
					SarychUI:Print("itemID " .. id .. SarychUI:T("ui.options_43f62414bc"))
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
						name = "ui.delete_be99b136",
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
		db.elvui.splitMode = "adibags"
		if db.elvui.adiBagsCategories == nil then
			db.elvui.adiBagsCategories = bagsDefaults.adiBagsCategories ~= false
		end
		if type(db.elvui.customCategories) ~= "table" then
			db.elvui.customCategories = {}
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
			db.elvui.dragonflightHeader = bagsDefaults.dragonflightHeader == true
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
		local mode = db and db.mode or "elvui"
		return mode ~= "elvui"
	end

	local function isElvUIMode()
		local db = DB()
		return (db and db.mode or "elvui") == "elvui"
	end

	local options = {
		type = "group",
		name = "ui.bags_a5b99f75",
		desc = "ui.sarychui_e897e7a7",
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = "ui.general_b250a3d6",
				order = 1,
				args = {
					enabled = {
						suiModuleEnable = true,
						type = "toggle",
						name = "ui.enable_module_b623b573",
						desc = "ui.text_79fa573d",
						order = 1,
						width = "full",
						get = function() return DB().enabled == true end,
						set = function(_, val)
							local db = DB()
							if not db then return end

							local previous = db.enabled == true
							val = val and true or false
							if previous == val then return end

							if val then
								SarychUI:EnableModule(moduleName)
								return
							end

							-- The unified bags runtime replaces Blizzard container hooks and
							-- frames. Keep the current runtime intact until ReloadUI instead of
							-- leaving either implementation half-disabled in this session.
							db.enabled = false
							ShowReloadPopup(function()
								db.enabled = previous
								if SarychUI and SarychUI.NotifySarychUIOptionsChange then
									SarychUI:NotifySarychUIOptionsChange()
								end
							end, SarychUI:T("ui.options_fdd56e3842"))
						end,
					},
					typeRow = {
						type = "group",
						name = "ui.bag_type_9f34d553",
						order = 2,
						inline = true,
						suiSelectWithButton = true,
						args = {
							mode = {
								type = "select",
								name = "",
								desc = "ui.wow_sarychui_reload_6d3b77c3",
								order = 1,
								values = {
									default = SarychUI:T("ui.options_0c9679e136"),
									elvui = SarychUI:T("ui.sarychui_bag_6f4d87f0"),
												},
								get = function()
									return DB().mode or "elvui"
								end,
								set = function(_, val)
									local previous = DB().mode or "elvui"
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
								name = "ui.settings_985b5e0f",
								desc = function()
									if isElvUIMode() then
										return SarychUI:T("ui.options_84c7fe6d9a")
									end
									return SarychUI:T("ui.options_e392334068")
								end,
								order = 2,
								func = function()
									local OC = SarychUI and SarychUI.OptionsCore
									if not OC or not OC.SelectTab then return end
									if isElvUIMode() then
										OC:SelectTab("elvuiBags")
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
								return SarychUI:T("ui.options_69ff5576f9")
							end
							return SarychUI:T("ui.cffffd700note_r_applying_this_requires_a_ui_relo_a728615e")
						end,
						order = 3,
						width = "full",
					},
					ownership = {
						type = "group",
						name = "ui.text_b3e68b98",
						order = 4,
						inline = true,
						args = {
							enabled = {
								type = "toggle",
								name = "ui.text_0781c0a5",
								desc = "ui.text_3d3de752",
								order = 1,
								width = "full",
								get = function() return DB().ownerTrackingEnabled ~= false end,
								set = function(_, value)
									DB().ownerTrackingEnabled = value and true or false
									if SarychUI_BagOwnership_Sync then SarychUI_BagOwnership_Sync() end
								end,
							},
							showOnAlt = {
								type = "toggle",
								name = "ui.alt_0a202e3b",
								suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
								desc = "ui.alt_b8ac4fd2",
								order = 2,
								width = "full",
								disabled = function() return DB().ownerTrackingEnabled == false end,
								get = function() return DB().ownerTrackingShowOnAlt == true end,
								set = function(_, value)
									DB().ownerTrackingShowOnAlt = value and true or false
									if BagnonFT_UpdateAltState then BagnonFT_UpdateAltState() end
								end,
							},
						},
					},
				},
			},
			defaultBags = {
				type = "group",
				name = "ui.default_bags_ed7cb2d0",
				order = 2,
				hidden = function() return not isDefaultMode() end,
				disabled = function() return not DB().enabled end,
				args = {
					bagSearchBox = {
						type = "group",
						name = "ui.enable_search_bar_7567b8b3",
						order = 1,
						inline = true,
						args = {
							enableBagSearch = {
								type = "toggle",
								name = "ui.enable_search_bar_7567b8b3",
								desc = "ui.search_field_on_the_main_backpack_window_left_of_658c576d",
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
						name = "ui.enable_bag_sorting_c5d4fbe4",
						order = 2,
						inline = true,
						args = (function()
							local args = {
								enableBagSortButton = {
									type = "toggle",
									name = "ui.enable_bag_sorting_c5d4fbe4",
									desc = "ui.button_on_the_main_backpack_window_d965220e",
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
				name = "ui.sarychui_bag_6f4d87f0",
				order = 3,
				hidden = function() return not isElvUIMode() end,
				disabled = function() return not DB().enabled end,
				args = {
					consumableSplitBox = {
						type = "group",
						name = "ui.item_splitting_c1a8be68",
						order = 1,
						inline = true,
						args = {
							sectionHeaderFontBox = {
								type = "group",
								name = "ui.section_header_font_443e3a67",
								desc = "ui.font_for_section_titles_quests_equipment_etc_in__79295d69",
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
										name = "ui.font_23997845",
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
										name = "ui.font_size_9f9d637d",
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
										name = "ui.font_scale_5bee06e6",
										desc = "ui.extra_scale_for_category_header_text_1_the_size__221816f0",
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
										name = "ui.outline_8159d13a",
										order = 4,
										values = {
											NONE = SarychUI:T("ui.options_f82a821941"),
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
										name = "ui.shadow_x_4c4bf6e2",
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
										name = "ui.shadow_y_f6fb3086",
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
							customCategoriesBox = {
								type = "group",
								name = "ui.text_480389bb",
								desc = "ui.manual_filtering_adibags_3216f039",
								order = 20,
								inline = true,
								hidden = function()
									local elv = EnsureElvUISettings(DB())
									return elv.splitMode ~= "adibags"
								end,
								args = module:BuildCustomCategoryOptionsArgs(),
							},
						},
					},
					scaleBox = {
						type = "group",
						name = "ui.scale_and_background_467f0737",
						order = 2,
						inline = true,
						suiTwoCol = true,
						args = {
							scale = {
								type = "range",
								name = "ui.window_scale_7b7928a8",
								desc = "ui.scale_of_bag_and_bank_windows_1_0_100_independen_d85a69cc",
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
								name = "ui.window_background_opacity_868a5242",
								desc = "ui.bag_and_bank_window_background_without_item_cate_0e76b0e4",
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
								name = "ui.background_opacity_categories_bca21577",
								desc = "ui.window_background_when_item_categories_adibags_a_089748db",
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
								name = "ui.dragonflight_style_header_40e94434",
								desc = "ui.decorative_header_bar_from_the_quest_tracker_tex_bc9f1cf4",
								order = 4,
								suiLiveApply = true,
								get = function()
									local elv = EnsureElvUISettings(DB())
									return elv.dragonflightHeader == true
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
						name = "ui.bag_layout_settings",
						order = 3,
						inline = true,
						suiTwoCol = true,
						args = {
							bagColumns = {
								type = "range",
								name = "ui.slots_per_row_bags_9ab1c606",
								desc = "ui.number_of_slots_in_one_row_of_the_bag_window_win_9bd13c84",
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
								name = "ui.slots_per_row_bank_ddcd9b19",
								desc = "ui.number_of_slots_in_one_row_of_the_bank_window_wi_6e0811a8",
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
							showItemLevel = {
								type = "toggle",
								name = "ui.show_item_levels_6649107d",
								order = 3,
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
									RefreshBagsOptionsPanel()
								end,
							},
							itemLevelFontSize = {
								type = "range",
								name = "ui.item_level_text_size_ac5261bb",
								order = 4,
								min = 8,
								max = 24,
								step = 1,
								hidden = function()
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
					fontBox = {
						type = "group",
						name = "ui.slot_font_46a487aa",
						desc = "ui.font_outline_and_shadow_for_stack_and_item_level_6aa3f4b8",
						order = 5,
						inline = true,
						suiTwoCol = true,
						args = {
							bagFont = {
								type = "select",
								style = "dropdown",
								name = "ui.font_23997845",
								desc = "ui.font_for_stack_and_item_level_text_on_slots_135e8952",
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
								name = "ui.outline_8159d13a",
								order = 2,
								values = {
									NONE = SarychUI:T("ui.options_f82a821941"),
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
								name = "ui.shadow_x_4c4bf6e2",
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
								name = "ui.shadow_y_f6fb3086",
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
								name = "ui.stack_text_size_6e033e33",
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
						},
					},
					footerBox = {
						type = "group",
						name = "ui.bottom_row_4e95ca0d",
						desc = "ui.money_and_tracked_currencies_at_the_bottom_of_th_63f40670",
						order = 6,
						inline = true,
						suiTwoCol = true,
						args = {
							footerFont = {
								type = "select",
								style = "dropdown",
								name = "ui.font_23997845",
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
								name = "ui.font_size_9f9d637d",
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
								name = "ui.outline_8159d13a",
								order = 3,
								values = {
									NONE = SarychUI:T("ui.options_f82a821941"),
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
								name = "ui.shadow_x_4c4bf6e2",
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
								name = "ui.shadow_y_f6fb3086",
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
								name = "ui.money_icons_d6c88c45",
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
								name = "ui.currency_icons_208a9b14",
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
						name = "ui.player_bag_window_bc5f6679",
						inline = true,
						suiTwoCol = true,
						order = 7,
						args = {
							bagPositionPoint = {
								type = "select",
								name = "ui.anchor_point_222108b8",
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
								name = "ui.options_c032adc1ff",
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
								name = "ui.options_23eb4d3f41",
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
								name = "ui.reset_bag_position_bb9e3d7b",
								order = 4,
								width = "full",
								func = function()
									module:ClearElvUIBagSavedWindowPosition()
									if SarychUI and SarychUI.Print then
										SarychUI:Print(SarychUI:T("ui.options_3dd8e35325"))
									end
								end,
							},
						},
					},
					bankPositionGroup = {
						type = "group",
						name = "ui.bank_window_100c00b8",
						inline = true,
						suiTwoCol = true,
						order = 8,
						args = {
							bankPositionPoint = {
								type = "select",
								name = "ui.anchor_point_222108b8",
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
								name = "ui.options_c032adc1ff",
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
								name = "ui.options_23eb4d3f41",
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
								name = "ui.reset_bank_position_3f565b73",
								order = 4,
								width = "full",
								func = function()
									module:ClearElvUIBankSavedWindowPosition()
									if SarychUI and SarychUI.Print then
										SarychUI:Print(SarychUI:T("ui.options_f9c2715806"))
									end
								end,
							},
						},
					},
				},
			},
		},
	}
    local blocks = options.args.elvuiBags.args
    local ownership = options.args.general.args.ownership
    options.args.general.args.ownership = nil
    ownership.args.altDetails = {
        type = "group", name = "", order = 2, inline = true,
        args = { showOnAlt = ownership.args.showOnAlt },
    }
    ownership.args.showOnAlt = nil
    ownership.order = 1.5
    blocks.ownership = ownership
    options.args.defaultBags.args.ownership = CopyTable(ownership)
    options.args.defaultBags.args.ownership.order = 0
    local splitArgs = blocks.consumableSplitBox.args
    blocks.customCategoriesBox = splitArgs.customCategoriesBox
    blocks.sectionHeaderFontBox = splitArgs.sectionHeaderFontBox
    blocks.consumableSplitBox = nil
    blocks.sectionHeaderFontBox.hidden = nil
    blocks.customCategoriesBox.hidden = nil
    blocks.customCategoriesBox.order = 2
    blocks.layoutBox.order = 1
    local layout = blocks.layoutBox.args
    local itemLevelSize = layout.itemLevelFontSize
    layout.itemLevelDetails = {
        type = "group", name = "", order = 4, inline = true,
        width = "full", suiFullRow = true,
        hidden = itemLevelSize.hidden,
        args = { itemLevelFontSize = itemLevelSize },
    }
    layout.itemLevelFontSize = nil
    itemLevelSize.hidden = nil
    itemLevelSize.order = 1
    itemLevelSize.width = "full"
    itemLevelSize.suiFullRow = true
    blocks.layoutBox.args.dragonflightHeader = blocks.scaleBox.args.dragonflightHeader
    blocks.layoutBox.args.dragonflightHeader.order = 5
    blocks.layoutBox.args.dragonflightHeader.width = "full"
    blocks.layoutBox.args.dragonflightHeader.suiFullRow = true
    blocks.scaleBox.args.dragonflightHeader = nil
    blocks.deepSettingsBox = {
        type = "group", name = "ui.deep_settings", order = 3, inline = true,
        args = {
            showAdvanced = {
                type = "toggle", name = "ui.enable_a54eaf37", order = 1, width = "full",
                get = function() return module._advancedBagsOptionsShown == true end,
                set = function(_, value)
                    module._advancedBagsOptionsShown = value and true or false
                    if SarychUI.NotifySarychUIOptionsChange then
                        SarychUI:NotifySarychUIOptionsChange()
                    end
                end,
            },
        },
    }
    for index, key in ipairs({ "scaleBox", "fontBox", "sectionHeaderFontBox", "footerBox",
        "bagPositionGroup", "bankPositionGroup" }) do
        local block = blocks[key]
        if block then
            block.order = index + 3
            local originalHidden = block.hidden
            block.hidden = function(...)
                if not module._advancedBagsOptionsShown then return true end
                if type(originalHidden) == "function" then return originalHidden(...) end
                return originalHidden == true
            end
        end
    end
    return options
end
