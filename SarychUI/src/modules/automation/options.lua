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

local function IsSarychUIBagsMode()
	local bags = SarychUI and SarychUI.modules and SarychUI.modules.bags
	return bags and bags.IsEnabled and bags:IsEnabled()
		and bags.IsElvUIMode and bags:IsElvUIMode() and true or false
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
		name = "ui.automation_ef3f5a55",
		desc = L and (L["Automation_Description"] or SarychUI:T("ui.options_4d9463a4a7")) or SarychUI:T("ui.options_4d9463a4a7"),
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = L["General"] or SarychUI:T("ui.general_b250a3d6"),
				order = 1,
				args = {
					enabled = {
						suiModuleEnable = true,
						type = "toggle",
						name = "ui.enable_module_b623b573",
						desc = "ui.enable_or_disable_the_module_ce99024f",
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
						name = "|TInterface\\CURSOR\\LootAll.blp:15.3:15.3:0:0|t " .. SarychUI:T("ui.auto_sell_junk_at_vendors_89f0188e"),
					order = 10,
					inline = true,
					args = {
						enableAutoSellGrey = {
							type = "toggle",
							name = "ui.auto_sell_junk_at_vendors_89f0188e",
							desc = "ui.automatically_sell_gray_items_when_talking_to_a__79f9d89b",
							order = 1,
							width = "full",
							get = function(info)
                                if IsSarychUIBagsMode() then
                                    local bags = SarychUI:GetModuleProfile("bags")
                                    return bags and bags.elvui and bags.elvui.vendorGraysAuto == true
                                end
                                return toggleGetter(info)
                            end,
                            set = function(info, val)
                                if IsSarychUIBagsMode() then
                                    local bags = SarychUI:GetModuleProfile("bags")
                                    if not bags then return end
                                    bags.elvui = bags.elvui or {}
                                    bags.elvui.vendorGraysAuto = val and true or false
                                    local bagModule = SarychUI:GetModule("bags")
                                    if bagModule and bagModule.ApplyMode then bagModule:ApplyMode() end
                                    return
                                end
                                toggleSetter(info, val)
                            end,
						},
						enableAutoSellGreyRequireKey = {
							type = "toggle",
							name = "ui.require_modifier_key_ce65d54d",
							order = 2,
							width = "full",
							get = toggleGetter,
							set = function(info, val)
								local db = DB(); if not db then return end
								db.enableAutoSellGreyRequireKey = val and 1 or 0
								if SarychUI.RefreshConfig then SarychUI:RefreshConfig() end
							end,
							hidden = function() return IsSarychUIBagsMode() or not isOn("enableAutoSellGrey") end,
						},
						autoSellGreyKey = {
							type = "select",
							name = "ui.modifier_key_47d87a5e",
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
							hidden = function() return IsSarychUIBagsMode() or not isOn("enableAutoSellGrey") or not isOn("enableAutoSellGreyRequireKey") end,
						},
					},
				},
				merchantStackBuyBox = {
					type = "group",
					name = "|TInterface\\CURSOR\\Buy.blp:15.3:15.3:0:0|t " .. SarychUI:T("ui.options_53ad79db21"),
					order = 70,
					inline = true,
					args = {
						enableMerchantStackBuy = {
							type = "toggle",
							name = "ui.options_41efb9e962",
							desc = "ui.options_663857bbc3",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = toggleSetter,
						},
						merchantStackBuyKey = {
							type = "select",
							name = "ui.modifier_key_47d87a5e",
							order = 2,
							width = "full",
							values = { ALT = "ALT", CTRL = "CTRL" },
							get = function()
								local db = DB(); return (db and db.merchantStackBuyKey) or "ALT"
							end,
							set = function(_, val)
								local db = DB(); if not db then return end
								db.merchantStackBuyKey = val
							end,
							hidden = function() return not isOn("enableMerchantStackBuy") end,
						},
					},
				},
				autoReleasePvPBox = {
					type = "group",
					name = "ui.tinterface_cursor_pvp_15_3_15_3_0_0_t_release_sp_59cc5fcf",
					desc = "ui.settings_for_automatic_spirit_release_after_pvp__384ac560",
					order = 20,
					inline = true,
					args = {
						enableAutoReleasePvP = {
							type = "toggle",
							name = "ui.release_spirit_in_pvp_aa101ea7",
							desc = "ui.if_checked_you_automatically_release_after_dying_104af709",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = toggleSetter,
						},
					},
				},
				autoRepairGearBox = {
					type = "group",
					name = "ui.tinterface_cursor_repairnpc_15_3_15_3_0_0_t_equi_da1fe9fe",
					desc = "ui.settings_for_automatic_equipment_repair_63e48fb9",
					order = 30,
					inline = true,
					args = {
						enableAutoRepairGear = {
							type = "toggle",
							name = "ui.equipment_repair_806245d8",
							desc = "ui.if_checked_your_gear_is_repaired_automatically_w_4401d1d4",
							order = 1,
							width = "full",
							get = toggleGetter,
							set = toggleSetter,
						},
						autoRepairGearRequireKey = {
							type = "toggle",
							name = "ui.require_modifier_key_ce65d54d",
							desc = "ui.if_checked_hold_a_modifier_to_repair_n_nif_unche_f1f52f7c",
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
							name = "ui.modifier_key_47d87a5e",
							desc = "ui.choose_a_modifier_key_for_repair_a4e4cc9e",
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
					name = "ui.tinterface_gossipframe_availablequesticon_14_14__52f6f76c",
					desc = "ui.settings_for_automatic_quest_accept_and_turn_in_fd524cf9",
					order = 40,
					inline = true,
					args = {
						enableQuestAutomation = {
							type = "toggle",
							name = "ui.quest_automation_9b8e89fc",
							desc = "ui.enable_quest_automation_d958c908",
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
							name = "ui.accept_available_quests_automatically_abb42250",
							desc = "ui.if_checked_available_quests_are_accepted_automat_bcf045d7",
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
							name = "ui.turn_in_completed_quests_automatically_47a2354a",
							desc = "ui.if_checked_completed_quests_are_turned_in_automa_5f531398",
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
							name = "ui.require_modifier_key_for_automation_2b876ce5",
							desc = "ui.if_checked_hold_a_modifier_to_automate_turning_i_9d8bd8d8",
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
							name = "ui.modifier_key_47d87a5e",
							desc = "ui.choose_a_modifier_key_for_quest_automation_20d70ca5",
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
					name = "ui.tinterface_gossipframe_trainergossipicon_14_14_0_4984ef1b",
					desc = "ui.settings_for_auto_learning_all_available_trainer_73d06575",
					order = 50,
					inline = true,
					args = {
						enableAutoTrainAll = {
							type = "toggle",
							name = "ui.auto_learn_all_abilities_5e664afa",
							desc = "ui.enable_auto_learning_all_available_trainer_abili_c6d03eed",
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
							name = "ui.modifier_key_47d87a5e",
							desc = "ui.choose_a_modifier_key_for_auto_learning_held_whi_0ff5cc2d",
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
					name = "ui.tinterface_cursor_directions_14_14_0_0_t_achieve_e70d1ba9",
					desc = "ui.settings_for_automatic_screenshots_on_achievemen_c4fdcb84",
					order = 60,
					inline = true,
					args = {
						enableAutoScreenshot = {
							type = "toggle",
							name = "ui.achievement_auto_screenshots_5e9d2343",
							desc = "ui.if_checked_a_screenshot_is_taken_automatically_w_64f3431d",
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
			lootRolls = SarychUI.LootRolls and SarychUI.LootRolls:GetOptions(),
			quickstart = SarychUI.BuildQuickStartOptionsGroup and SarychUI:BuildQuickStartOptionsGroup(),
		},
	}
end
