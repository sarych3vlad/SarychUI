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

local function ShowReloadPopup(onCancel, text)
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup(text, onCancel)
		return
	end
end

local function IsElvUINamePlatesRuntimeEnabled() return module:IsNamePlatesRunning() end
local function SetElvUINamePlatesRuntime(enable) module:ApplyNamePlates(enable) end

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
		return L and (L["ElvUI Nameplates"] or SarychUI:T("ui.options_e75dd9a064")) or SarychUI:T("ui.options_e75dd9a064")
	end
	return L and (L["Classic WoW Nameplates"] or SarychUI:T("ui.options_0c9679e136")) or SarychUI:T("ui.options_0c9679e136")
end

local function ProfileModeInfoText()
	local mode = module.GetAutolosProfileMode and module:GetAutolosProfileMode() or "classic"
	local modeLabel = GetProfileModeLabel()
	local modeColor = (mode == "elvui") and "|cff00ff00" or "|cFFFFD700"
	return SarychUI:T("ui.options_a5fe99b009") .. modeColor .. tostring(modeLabel) .. "|r"
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
		name = "|TInterface\\AddOns\\SarychUI\\media\\components\\modules\\nameplates\\engines\\elvui\\Media\\Textures\\nameplates:20:20:0:0:256:128:0:38:45:81|t " .. (L and (L["Health Indicators"] or SarychUI:T("ui.options_eebe535d96")) or SarychUI:T("ui.options_eebe535d96")),
		desc = L and (L["Health Indicators Desc"] or SarychUI:T("ui.options_0ad35c3fa3")) or SarychUI:T("ui.options_0ad35c3fa3"),
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
						desc = "ui.disabling_the_module_switches_indicators_to_clas_6bccb1d6",
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
								end, SarychUI:T("ui.options_9a544d2a7b"))
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
								end, SarychUI:T("ui.options_17e939dbc8"))
							end
						end,
					},

					typeRow = {
						type = "group",
						name = L and (L["Health Indicator Type"] or SarychUI:T("ui.options_dcfb3b1ca4")) or SarychUI:T("ui.options_dcfb3b1ca4"),
						order = 2,
						inline = true,
						suiSelectWithButton = true,
						args = {
							indicatorType = {
								type = "select",
								name = "",
								desc = L and (L["Health Indicator Type Desc"] or SarychUI:T("ui.options_f38223b85d")) or SarychUI:T("ui.options_f38223b85d"),
								order = 1,
								values = {
									classic = L and (L["Classic WoW Nameplates"] or SarychUI:T("ui.options_0c9679e136")) or SarychUI:T("ui.options_0c9679e136"),
									elvui = L and (L["ElvUI Nameplates"] or SarychUI:T("ui.options_e75dd9a064")) or SarychUI:T("ui.options_e75dd9a064"),
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
									end, L and (L["Health Indicators Reload Notice"] or SarychUI:T("ui.options_23d26b80fd")) or SarychUI:T("ui.options_23d26b80fd"))
								end,
							},
							openElvUISettings = {
								type = "execute",
								name = "ui.settings_985b5e0f",
								desc = L and (L["Open ElvUI NamePlates Settings Desc"] or SarychUI:T("ui.options_50a5b8f4ca")) or SarychUI:T("ui.options_50a5b8f4ca"),
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
					scaleBox = {
						type = "group",
						name = "ui.scale_e037e967",
						order = 3,
						inline = true,
						hidden = function()
							return GetCurrentNameplateMode() ~= "classic"
						end,
						args = {
							scale = {
								type = "range",
								name = "ui.nameplates.indicator_size",
								desc = L and (L["Nameplate Scale Desc"] or SarychUI:T("ui.options_6a2779ecd2")) or SarychUI:T("ui.options_6a2779ecd2"),
								order = 1,
								width = "full",
								suiFullRow = true,
								min = 0.5,
								max = 3,
								step = 0.05,
								get = function()
									if module.GetNameplateScale then
										return module:GetNameplateScale()
									end
									local db = DB()
									return (db and db.scale) or 1
								end,
								set = function(_, value)
									local db = DB()
									if not db then return end
									db.scale = value
									if module.ApplyNameplateScale then
										module:ApplyNameplateScale()
									end
								end,
							},
						},
					},
					modeHint = {
						type = "description",
						name = "ui.nameplates.mode_reload_hint",
						order = 2.5,
						width = "full",
					},
                    summonedCreatures = {
                        type = "group", name = "ui.nameplates.summoned_creatures",
                        inline = true, order = 5,
                        args = {
                            petIcons = {
                                type = "toggle", name = "ui.nameplates.pet_icons",
                                desc = "ui.nameplates.pet_icons_desc", order = 1, width = "full",
                                get = function() local db = DB(); return db and db.petIcons == true end,
                                set = function(_, value)
                                    local db = DB(); if not db then return end
                                    db.petIcons = value and true or false
                                    module:RefreshPetIcons()
                                end,
                                disabled = function() return not IsModuleEnabled() end,
                            },

                        },
                    },
				},
			},

			distance = {
				type = "group",
				name = L and (L["Nameplate Distance Tab"] or SarychUI:T("ui.options_2ab5f13e2e")) or SarychUI:T("ui.options_2ab5f13e2e"),
				order = 2,
				disabled = function()
					return not IsModuleEnabled()
				end,
				args = {
					dllStatus = {
						type = "description",
						name = function()
							local compat = SarychUI.Compatibility
							if compat and compat.FormatDllStatusLine then
								return compat:FormatDllStatusLine({ id = "nameplate_range", label = "nameplate_range.dll" })
							end
							return SarychUI:T("ui.options_aa79e26801")
						end,
						order = 0,
						width = "full",
					},
					enableAutolos = {
						type = "toggle",
						name = L and (L["Nameplate Distance"] or SarychUI:T("ui.options_1bdc369057")) or SarychUI:T("ui.options_1bdc369057"),
						desc = L and (L["Nameplate Distance Desc"] or SarychUI:T("ui.options_6e3d564b41")) or SarychUI:T("ui.options_6e3d564b41"),
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
						name = "ui.enable_totem_support_c9a57b38",
						desc = "ui.for_elvui_totems_shown_as_an_icon_no_hp_bar_plac_b5af2a7f",
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
						name = "ui.position_e0984603",
						order = 3,
						inline = true,
						suiTwoCol = true,
						hidden = function()
							return not module:IsAutolosEnabled()
						end,
						args = {
							anchorToName = {
								type = "toggle",
								name = "ui.anchor_to_name_9cf1406b",
								desc = "ui.distance_to_the_left_of_the_name_all_elvui_plate_ecc83eb9",
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
								name = L and (L["Position X"] or SarychUI:T("ui.position_x_b3623749")) or SarychUI:T("ui.position_x_b3623749"),
								desc = L and (L["Nameplate Distance Offset X Desc"] or SarychUI:T("ui.options_7d88179045")) or SarychUI:T("ui.options_7d88179045"),
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
								name = L and (L["Position Y"] or SarychUI:T("ui.position_y_444abafa")) or SarychUI:T("ui.position_y_444abafa"),
								desc = L and (L["Nameplate Distance Offset Y Desc"] or SarychUI:T("ui.options_95109bb3e6")) or SarychUI:T("ui.options_95109bb3e6"),
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
						name = "ui.display_settings_91ae2667",
						order = 4,
						inline = true,
						suiTwoCol = true,
						hidden = function()
							return not module:IsAutolosEnabled()
						end,
						args = {
							distanceFontSize = {
								type = "range",
								name = L and (L["Font Size"] or SarychUI:T("ui.font_size_9f9d637d")) or SarychUI:T("ui.font_size_9f9d637d"),
								desc = L and (L["Nameplate Distance Font Size Desc"] or SarychUI:T("ui.options_b2cbce1759")) or SarychUI:T("ui.options_b2cbce1759"),
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
								name = L and (L["Font"] or SarychUI:T("ui.font_23997845")) or SarychUI:T("ui.font_23997845"),
								desc = L and (L["Nameplate Distance Font Desc"] or SarychUI:T("ui.options_84eb7401b7")) or SarychUI:T("ui.options_84eb7401b7"),
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
								name = L and (L["Font Outline"] or SarychUI:T("ui.options_6cb0ac8643")) or SarychUI:T("ui.options_6cb0ac8643"),
								desc = L and (L["Nameplate Distance Font Outline Desc"] or SarychUI:T("ui.options_727a05c58e")) or SarychUI:T("ui.options_727a05c58e"),
								order = 3,
								values = function()
									if AutolosFontFlags and AutolosFontFlags.GetValues then
										return AutolosFontFlags.GetValues(L)
									end
									return {
										NONE = L and (L["None"] or SarychUI:T("ui.options_eea53a085d")) or SarychUI:T("ui.options_eea53a085d"),
										OUTLINE = "OUTLINE",
										MONOCHROME = "MONOCHROME",
										MONOCHROMEOUTLINE = "MONOCHROME OUTLINE",
										THICKOUTLINE = "THICK OUTLINE",
									}
								end,
								get = function()
									local p = GetAutolosProfile()
									return p.fontOutline or p.fontFlags or "NONE"
								end,
								set = function(_, value)
									GetAutolosProfile().fontOutline = value
									OnDistanceSetting("fontOutline", value, ApplyAutolosTextStyle)
								end,
							},
							distanceShadowX = {
								type = "range",
								name = L and (L["Shadow X"] or SarychUI:T("ui.shadow_x_4c4bf6e2")) or SarychUI:T("ui.shadow_x_4c4bf6e2"),
								desc = L and (L["Nameplate Distance Shadow X Desc"] or SarychUI:T("ui.options_76a68b2578")) or SarychUI:T("ui.options_76a68b2578"),
								order = 4,
								min = -5,
								max = 5,
								step = 0.5,
								suiPreviewKey = "shadowX",
								get = function()
									local p = GetAutolosProfile()
									if p.shadowX ~= nil then
										return p.shadowX
									end
									return IsElvUIAutolosMode() and 1 or 0.5
								end,
								set = function(_, value)
									GetAutolosProfile().shadowX = value
									OnDistanceSetting("shadowX", value, ApplyAutolosTextStyle)
								end,
							},
							distanceShadowY = {
								type = "range",
								name = L and (L["Shadow Y"] or SarychUI:T("ui.shadow_y_f6fb3086")) or SarychUI:T("ui.shadow_y_f6fb3086"),
								desc = L and (L["Nameplate Distance Shadow Y Desc"] or SarychUI:T("ui.options_ec3f61f8a2")) or SarychUI:T("ui.options_ec3f61f8a2"),
								order = 5,
								min = -5,
								max = 5,
								step = 0.5,
								suiPreviewKey = "shadowY",
								get = function()
									local p = GetAutolosProfile()
									if p.shadowY ~= nil then
										return p.shadowY
									end
									return IsElvUIAutolosMode() and -1 or -0.5
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
