-- SarychUI MainMenuBar Module Options
-- Options interface for main menu bar customization

local moduleName = "mainmenubar"
local L = SarychUI.L

local function InterfaceStyleActive()
	local style = _G.SarychUI_InterfaceStyle
	return style and style.enabled and style.UseStyleTextures and style.UseStyleTextures()
end

local function NotifyOptionsChange()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local function ToolsDB()
    local modules = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
    return modules and modules.tools
end

local function ToolsFpsEnabled()
    local db = ToolsDB()
    return db and (db.enableAltFPS == 1 or db.enableAltFPS == true) or false
end

local function RefreshStylePreviews()
	if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
		SarychUI.ActionBarAppearancePreview:RefreshAll()
	end
	if SarychUI.ActionBarBarsPreview and SarychUI.ActionBarBarsPreview.RefreshAll then
		SarychUI.ActionBarBarsPreview:RefreshAll()
	end
end

local function TextDB()
    return SarychUI.db.profile.modules.mainmenubar
end

local function HotkeyTextEnabled()
    local db = TextDB()
    if db.hotkeyTextEnabled ~= nil then return db.hotkeyTextEnabled end
    if db.hotkeyTextMode == "custom" then return true end
    return db.hideHotkeysEnabled
end

local function MacroTextEnabled()
    local db = TextDB()
    if db.macroTextEnabled ~= nil then return db.macroTextEnabled end
    if db.macroTextMode == "custom" then return true end
    return db.hideMacroNames
end

local function HideHotkeyOptions()
    return not HotkeyTextEnabled()
end

local function HideHotkeyVisibilityOptions()
    return not HotkeyTextEnabled() or TextDB().hotkeyTextMode ~= "hide"
end

local function HideHotkeyStyleOptions()
    return not HotkeyTextEnabled() or TextDB().hotkeyTextMode ~= "custom"
end

local function HideMacroOptions()
    return not MacroTextEnabled()
end

local function HideMacroStyleOptions()
    return not MacroTextEnabled() or TextDB().macroTextMode ~= "custom"
end

local function GetTextFontValues()
    local values = {}
    if SarychUI.Media and SarychUI.Media.GetFonts then
        for _, name in ipairs(SarychUI.Media.GetFonts()) do values[name] = name end
    end
    if not next(values) then values["Friz Quadrata TT"] = "Friz Quadrata TT" end
    return values
end

local function GetTextOutlineValues()
    if SarychUI_FontOutlineValues and SarychUI_FontOutlineValues.GetSelectValues then
        return SarychUI_FontOutlineValues.GetSelectValues(L)
    end
    return { NONE = SarychUI:T("ui.options_ce7c59f91a"), OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE",
        MONOCHROMEOUTLINE = "MONOCHROMEOUTLINE" }
end

local function RefreshActionBarText()
    local bar = SarychUI.modules and SarychUI.modules.mainmenubar
    if bar then
        bar:UpdateAllHotkeys()
        bar:UpdateAllMacroNames()
    end
    if SarychUI.ActionBarTextPreview and SarychUI.ActionBarTextPreview.RefreshAll then
        SarychUI.ActionBarTextPreview:RefreshAll()
    end
end

local INDICATION_COLOR_DEFAULTS = {
    colorCooldownColor = { 0.4, 0.4, 0.4, 0.6 },
    colorManaColor = { 0.1, 0.1, 1.0, 1.0 },
    colorRangeColor = { 0.8, 0.2, 0.2, 1.0 },
    colorUnusableColor = { 0.2, 0.2, 0.2, 1.0 },
}

local function GetIndicationColor(key)
    local db = SarychUI.db.profile.modules.mainmenubar
    local color = db[key]
    local defaults = INDICATION_COLOR_DEFAULTS[key]
    local r = type(color) == "table" and color[1] or nil
    local g = type(color) == "table" and color[2] or nil
    local b = type(color) == "table" and color[3] or nil
    local a = type(color) == "table" and color[4] or nil
    if r == nil then r = defaults[1] end
    if g == nil then g = defaults[2] end
    if b == nil then b = defaults[3] end
    if a == nil and key == "colorCooldownColor" then
        a = db.colorCooldownAlpha
    end
    if a == nil then a = defaults[4] end
    return r, g, b, a
end

local function SetIndicationColor(key, r, g, b, a)
    local db = SarychUI.db.profile.modules.mainmenubar
    db[key] = { r, g, b, a }
    -- Keep the retired standalone cooldown-alpha value synchronized for old
    -- profiles and external consumers that may still read it.
    if key == "colorCooldownColor" then
        db.colorCooldownAlpha = a
    end
    if SarychUI.modules and SarychUI.modules.mainmenubar then
        SarychUI.modules.mainmenubar:UpdateColorIndication()
    end
    if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
        SarychUI.ActionBarColorPreview:RefreshAll()
    end
end

-- Get options table for this module
local function GetOptions()
    local options = {
        name = L["MainMenuBar"],
        type = "group",
        desc = L and (L["MainMenuBar_Description"] or SarychUI:T("ui.options_1ad4dd9c28")) or SarychUI:T("ui.options_1ad4dd9c28"),
        childGroups = "tab",
        args = {
            -- General tab
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                args = {
						enabled = {
                        suiModuleEnable = true,
                        type = "toggle",
                        name = L["Enable_Module"],
                        desc = "ui.enable_or_disable_the_module_ce99024f",
                        order = 1,
                        width = "full",
                        get = function(info)
                            return SarychUI.db.profile.modules.mainmenubar.enabled
                        end,
                        set = function(info, value)
                            local db = SarychUI.db.profile.modules.mainmenubar
                            db.enabled = value
                            if value then
                                SarychUI:EnableModule(moduleName)
                            else
                                SarychUI:DisableModule(moduleName)
                            end
                            NotifyOptionsChange()
						end,
					},
					typeRow = {
						type = "group",
						name = "ui.bar_type_34b0f3c3",
						order = 10,
						inline = true,
						args = {
							bar_style = {
								type = "select",
								name = "",
								desc = "ui.reload_aeb62c69",
								order = 1,
								values = {
									__order = { "classic", "bfa", "dragon" },
									classic = SarychUI:T("ui.options_03ced8ccad"),
									bfa = SarychUI:T("ui.options_b7a531d730"),
									dragon = SarychUI:T("ui.options_7d7d01ff2c"),
								},
								get = function()
									return SarychUI.db.profile.modules.mainmenubar.barStyle or "classic"
								end,
								set = function(_, value)
									local db = SarychUI.db.profile.modules.mainmenubar
									local previous = db.barStyle or "classic"
									if previous == value then return end

									db.barStyle = value
									RefreshStylePreviews()
									NotifyOptionsChange()

									local function revert()
										db.barStyle = previous
										RefreshStylePreviews()
										NotifyOptionsChange()
									end
									local text = SarychUI:T("ui.options_42ee50cdd6")
									if SarychUI.T then text = SarychUI:T(text) end
									if SarychUI.ShowReloadPopup then
										SarychUI:ShowReloadPopup(text, revert)
									end
								end,
							},
						},
					},
					modeHint = {
						type = "description",
						name = "ui.cffffd700warning_r_changing_the_bar_type_require_330931fc",
						order = 30,
						width = "full",
					},
				},
			},

            -- Visual / Text tab
            visual = {
                type = "group",
                name = L["Visual"],
                order = 2,
                disabled = function() return not SarychUI.db.profile.modules.mainmenubar.enabled end,
                args = {
                    preview = {
                        type = "description",
                        name = "",
                        order = 1,
                        width = "full",
                        suiPreview = "ActionBarTextPreview",
                    },

                    hotkeysBox = {
                        type = "group",
                        name = L["Hotkeys"],
                        order = 10,
                        inline = true,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "ui.text_17440b8e",
                                order = 1,
                                width = "full",
                                get = HotkeyTextEnabled,
                                set = function(_, value)
                                    local db = TextDB()
                                    db.hotkeyTextEnabled = value
                                    db.hideHotkeysEnabled = value and db.hotkeyTextMode == "hide"
                                    RefreshActionBarText()
                                    NotifyOptionsChange()
                                end,
                            },
                            hide_hotkeys = {
                                type = "select",
                                name = "ui.text_8c4299ef",
                                order = 2,
                                values = { __order = { "hide", "custom" },
                                    hide = SarychUI:T("ui.options_db3d93669b"), custom = SarychUI:T("ui.options_5a4c6186b6") },
                                hidden = HideHotkeyOptions,
                                get = function()
                                    return TextDB().hotkeyTextMode or "hide"
                                end,
                                set = function(_, value)
                                    local db = TextDB()
                                    db.hotkeyTextEnabled = true
                                    db.hotkeyTextMode = value
                                    db.hideHotkeysEnabled = value == "hide"
                                    RefreshActionBarText()
                                    NotifyOptionsChange()
                                end,
                            },
                            show_in_combat = {
                                type = "toggle",
                                name = L["Show_In_Combat"],
                                desc = L["Show_In_Combat_Desc"],
                                order = 3,
                                width = "full",
                                hidden = HideHotkeyVisibilityOptions,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.showHotkeysInCombat
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.showHotkeysInCombat = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllHotkeys()
                                    end
                                end,
                            },
                            show_on_alt = {
                                type = "toggle",
                                name = L["Show_On_Alt"],
                                desc = L["Show_On_Alt_Desc"],
                                order = 4,
                                width = "full",
                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                hidden = HideHotkeyVisibilityOptions,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.showHotkeysOnAlt
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.showHotkeysOnAlt = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllHotkeys()
                                    end
                                end,
                            },
                            show_with_target = {
                                type = "toggle",
                                name = L["Show_With_Target"],
                                desc = L["Show_With_Target_Desc"],
                                order = 5,
                                width = "full",
                                hidden = HideHotkeyVisibilityOptions,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.showHotkeysWithTarget == true
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.showHotkeysWithTarget = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllHotkeys()
                                    end
                                end,
                            },
                            fade_after_combat = {
                                type = "toggle",
                                name = L["Fade_After_Combat"],
                                desc = L["Fade_After_Combat_Desc"],
                                order = 6,
                                width = "full",
                                hidden = HideHotkeyVisibilityOptions,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.hotkeysFadeAfterCombat
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.hotkeysFadeAfterCombat = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:HideHotkeys()
                                    end
                                    NotifyOptionsChange()
                                end,
                            },
                            fade_time = {
                                type = "range",
                                name = L["Fade_Time"],
                                desc = L["Fade_Time_Desc"],
                                order = 7,
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                hidden = function()
                                    return HideHotkeyVisibilityOptions() or not TextDB().hotkeysFadeAfterCombat
                                end,
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.hotkeysFadeTime
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.hotkeysFadeTime = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:HideHotkeys()
                                    end
                                end,
                            },
                            font = {
                                type = "select", name = "ui.font_23997845", order = 8,
                                values = GetTextFontValues, hidden = HideHotkeyStyleOptions,
                                get = function() return TextDB().hotkeyFont end,
                                set = function(_, value) TextDB().hotkeyFont = value; RefreshActionBarText() end,
                            },
                            fontSize = {
                                type = "range", name = "ui.text_fbbfdb37", order = 9,
                                min = 6, max = 32, step = 1, hidden = HideHotkeyStyleOptions,
                                get = function() return TextDB().hotkeyFontSize end,
                                set = function(_, value) TextDB().hotkeyFontSize = value; RefreshActionBarText() end,
                            },
                            fontOutline = {
                                type = "select", name = "ui.text_854b2110", order = 10,
                                values = GetTextOutlineValues, hidden = HideHotkeyStyleOptions,
                                get = function() return TextDB().hotkeyFontOutline end,
                                set = function(_, value) TextDB().hotkeyFontOutline = value; RefreshActionBarText() end,
                            },
                        },
                    },

                    macrosBox = {
                        type = "group",
                        name = L["Macros"],
                        order = 20,
                        inline = true,
                        args = {
                            enabled = {
                                type = "toggle", name = "ui.text_e314385b",
                                order = 1, width = "full",
                                get = MacroTextEnabled,
                                set = function(_, value)
                                    local db = TextDB()
                                    db.macroTextEnabled = value
                                    db.hideMacroNames = value and db.macroTextMode == "hide"
                                    RefreshActionBarText()
                                    NotifyOptionsChange()
                                end,
                            },
                            hide_macro_names = {
                                type = "select", name = "ui.text_41b082f8", order = 2,
                                values = { __order = { "hide", "custom" },
                                    hide = SarychUI:T("ui.options_8f8f9fd6cf"), custom = SarychUI:T("ui.options_9b456fc919") },
                                hidden = HideMacroOptions,
                                get = function()
                                    return TextDB().macroTextMode or "hide"
                                end,
                                set = function(_, value)
                                    local db = TextDB()
                                    db.macroTextEnabled = true
                                    db.macroTextMode = value
                                    db.hideMacroNames = value == "hide"
                                    RefreshActionBarText()
                                    NotifyOptionsChange()
                                end,
                            },
                            font = {
                                type = "select", name = "ui.font_23997845", order = 3,
                                values = GetTextFontValues, hidden = HideMacroStyleOptions,
                                get = function() return TextDB().macroFont end,
                                set = function(_, value) TextDB().macroFont = value; RefreshActionBarText() end,
                            },
                            fontSize = {
                                type = "range", name = "ui.text_fbbfdb37", order = 4,
                                min = 6, max = 32, step = 1, hidden = HideMacroStyleOptions,
                                get = function() return TextDB().macroFontSize end,
                                set = function(_, value) TextDB().macroFontSize = value; RefreshActionBarText() end,
                            },
                            fontOutline = {
                                type = "select", name = "ui.text_854b2110", order = 5,
                                values = GetTextOutlineValues, hidden = HideMacroStyleOptions,
                                get = function() return TextDB().macroFontOutline end,
                                set = function(_, value) TextDB().macroFontOutline = value; RefreshActionBarText() end,
                            },
                            fontColor = {
                                type = "color", name = "ui.text_d76a10ce", order = 6,
                                hasAlpha = true, hidden = HideMacroStyleOptions,
                                get = function()
                                    local c = TextDB().macroFontColor or { 1, 1, 1, 1 }
                                    return c[1], c[2], c[3], c[4]
                                end,
                                set = function(_, r, g, b, a)
                                    TextDB().macroFontColor = { r, g, b, a }
                                    RefreshActionBarText()
                                end,
                            },
                        },
                    },
                },
            },
                
                -- Color Indication tab
                colorIndication = {
                    type = "group",
                    name = L["Color Indication"],
                    order = 3,
                    disabled = function() return not SarychUI.db.profile.modules.mainmenubar.enabled end,
                    args = {
                        preview = {
                            type = "description",
                            name = "",
                            order = 1,
                            width = "full",
                            suiPreview = "ActionBarColorPreview",
                        },

                        cooldownBox = {
                            type = "group",
                            name = L["Color_Cooldown_Enabled"],
                            order = 10,
                            inline = true,
                            args = {
                                color_cooldown_enabled = {
                                    type = "toggle",
                                    name = L["Color_Cooldown_Enabled"],
                                    desc = L["Color_Cooldown_Enabled_Desc"],
                                    order = 1,
                                    width = "full",
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorCooldownEnabled
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorCooldownEnabled = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
                                        NotifyOptionsChange()
                                    end,
                                },
                                color_cooldown_color = {
                                    type = "color",
                                    name = L["Color_Indication_Color"] or SarychUI:T("ui.options_9f300febe4"),
                                    desc = L["Color_Indication_Color_Desc"] or SarychUI:T("ui.options_f9cc735288"),
                                    hasAlpha = true,
                                    order = 2,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorCooldownEnabled
                                    end,
                                    get = function()
                                        return GetIndicationColor("colorCooldownColor")
                                    end,
                                    set = function(_, r, g, b, a)
                                        SetIndicationColor("colorCooldownColor", r, g, b, a)
                                    end,
                                },
                            },
                        },

                        manaBox = {
                            type = "group",
                            name = L["Color_Mana_Enabled"],
                            order = 20,
                            inline = true,
                            args = {
                                color_mana_enabled = {
                                    type = "toggle",
                                    name = L["Color_Mana_Enabled"],
                                    desc = L["Color_Mana_Enabled_Desc"],
                                    order = 1,
                                    width = "full",
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorManaEnabled
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorManaEnabled = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
                                        NotifyOptionsChange()
                                    end,
                                },
                                color_mana_color = {
                                    type = "color",
                                    name = L["Color_Indication_Color"] or SarychUI:T("ui.options_9f300febe4"),
                                    desc = L["Color_Indication_Color_Desc"] or SarychUI:T("ui.options_f9cc735288"),
                                    hasAlpha = true,
                                    order = 2,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorManaEnabled
                                    end,
                                    get = function()
                                        return GetIndicationColor("colorManaColor")
                                    end,
                                    set = function(_, r, g, b, a)
                                        SetIndicationColor("colorManaColor", r, g, b, a)
                                    end,
                                },
                            },
                        },

                        rangeBox = {
                            type = "group",
                            name = L["Color_Range_Enabled"],
                            order = 30,
                            inline = true,
                            args = {
                                color_range_enabled = {
                                    type = "toggle",
                                    name = L["Color_Range_Enabled"],
                                    desc = L["Color_Range_Enabled_Desc"],
                                    order = 1,
                                    width = "full",
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorRangeEnabled
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorRangeEnabled = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
                                        NotifyOptionsChange()
                                    end,
                                },
                                color_range_color = {
                                    type = "color",
                                    name = L["Color_Indication_Color"] or SarychUI:T("ui.options_9f300febe4"),
                                    desc = L["Color_Indication_Color_Desc"] or SarychUI:T("ui.options_f9cc735288"),
                                    hasAlpha = true,
                                    order = 2,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorRangeEnabled
                                    end,
                                    get = function()
                                        return GetIndicationColor("colorRangeColor")
                                    end,
                                    set = function(_, r, g, b, a)
                                        SetIndicationColor("colorRangeColor", r, g, b, a)
                                    end,
                                },
                            },
                        },

                        unusableBox = {
                            type = "group",
                            name = L["Color_Unusable_Enabled"],
                            order = 40,
                            inline = true,
                            args = {
                                color_unusable_enabled = {
                                    type = "toggle",
                                    name = L["Color_Unusable_Enabled"],
                                    desc = L["Color_Unusable_Enabled_Desc"],
                                    order = 1,
                                    width = "full",
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorUnusableEnabled
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorUnusableEnabled = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
                                        NotifyOptionsChange()
                                    end,
                                },
                                color_unusable_color = {
                                    type = "color",
                                    name = L["Color_Indication_Color"] or SarychUI:T("ui.options_9f300febe4"),
                                    desc = L["Color_Indication_Color_Desc"] or SarychUI:T("ui.options_f9cc735288"),
                                    hasAlpha = true,
                                    order = 2,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorUnusableEnabled
                                    end,
                                    get = function()
                                        return GetIndicationColor("colorUnusableColor")
                                    end,
                                    set = function(_, r, g, b, a)
                                        SetIndicationColor("colorUnusableColor", r, g, b, a)
                                    end,
                                },
                            },
                        },
                    },
                },
                
                -- Appearance tab
                appearance = {
                    type = "group",
                    name = L["Appearance"],
                    order = 4,
                    disabled = function() return not SarychUI.db.profile.modules.mainmenubar.enabled end,
                    childGroups = "tab",
                    args = {
                        -- Visual improvements tab
                        visual = {
                            type = "group",
                            name = "ui.visual_improvements_dbe067b7",
                            order = 1,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiPreview = "ActionBarAppearancePreview",
                                    hidden = function()
                                        return SarychUI.db.profile.modules.mainmenubar.barStyle == "dragon"
                                    end,
                                },

                                gryphonsBox = {
                                    type = "group",
                                    name = "ui.griffons_5a1491cb",
                                    order = 10,
                                    inline = true,
                                    hidden = function()
                                        return SarychUI.db.profile.modules.mainmenubar.barStyle == "dragon"
                                    end,
                                    args = {
                                        hide_gryphons = {
                                            type = "toggle",
                                            name = L["Hide_Gryphons"] or SarychUI:T("ui.options_97b36536f2"),
                                            desc = L["Hide_Gryphons_Desc"] or SarychUI:T("ui.options_10050537e7"),
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideGryphons
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideGryphons = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:RefreshVisualImprovements()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },

                                backgroundsBox = {
                                    type = "group",
                                    name = "ui.background_textures_786ebba2",
                                    order = 20,
                                    inline = true,
                                    hidden = function()
                                        return SarychUI.db.profile.modules.mainmenubar.barStyle == "dragon"
                                    end,
                                    args = {
										hide_actionbar_backgrounds = {
                                            type = "toggle",
                                            name = L["Hide_ActionBar_Backgrounds"],
                                            desc = L["Hide_ActionBar_Backgrounds_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideActionBarBackgrounds
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideActionBarBackgrounds = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:RefreshVisualImprovements()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
											end,
										},
										hide_bag_micro_menu_background = {
											type = "toggle",
											name = "ui.hide_bags_and_micro_menu_background_27874e6c",
											desc = "ui.hides_the_decorative_bfa_tray_behind_the_bags_an_d034b8ee",
											order = 2,
											width = "full",
											hidden = function()
												return (SarychUI.db.profile.modules.mainmenubar.barStyle or "classic") ~= "bfa"
											end,
											get = function()
												return SarychUI.db.profile.modules.mainmenubar.hideBagMicroMenuBackground == true
											end,
											set = function(_, value)
												SarychUI.db.profile.modules.mainmenubar.hideBagMicroMenuBackground = value and true or false
												if SarychUI.modules and SarychUI.modules.mainmenubar then
													SarychUI.modules.mainmenubar:RefreshVisualImprovements()
												end
												RefreshStylePreviews()
											end,
										},
										hide_secondary_panels_backgrounds = {
                                            type = "toggle",
                                            name = L["Hide_Secondary_Panels_Backgrounds"],
                                            desc = L["Hide_Secondary_Panels_Backgrounds_Desc"],
											order = 3,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideSecondaryPanelsBackgrounds
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideSecondaryPanelsBackgrounds = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:RefreshVisualImprovements()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                        hide_maxlevel_bar = {
                                            type = "toggle",
                                            name = L["Hide_MaxLevel_Bar"],
                                            desc = L["Hide_MaxLevel_Bar_Desc"],
											order = 4,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideMaxLevelBar
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideMaxLevelBar = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:RefreshVisualImprovements()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
										hide_experience_overlay_textures = {
											type = "toggle",
											name = "ui.text_3935620d",
											desc = "ui.bfa_9429f5ac",
											order = 5,
											width = "full",
											get = function()
												return SarychUI.db.profile.modules.mainmenubar.hideExperienceOverlayTextures == true
											end,
											set = function(_, value)
												SarychUI.db.profile.modules.mainmenubar.hideExperienceOverlayTextures = value and true or false
												local bars = SarychUI.modules and SarychUI.modules.mainmenubar
												if bars and bars.ApplyExperienceOverlayVisibility then
													bars:ApplyExperienceOverlayVisibility()
												end
												RefreshStylePreviews()
											end,
										},
										hide_exhaustion_tick = {
											type = "toggle",
											name = "ui.text_87af228b",
											desc = "ui.exhaustiontick_dd2312e9",
											order = 7,
											width = "full",
											get = function()
												return SarychUI.db.profile.modules.mainmenubar.hideExhaustionTick == true
											end,
											set = function(_, value)
												SarychUI.db.profile.modules.mainmenubar.hideExhaustionTick = value and true or false
												local bars = SarychUI.modules and SarychUI.modules.mainmenubar
												if bars and bars.ApplyExhaustionTickVisibility then
													bars:ApplyExhaustionTickVisibility()
												end
											end,
										},
										hide_reputation_overlay_textures = {
											type = "toggle",
											name = "ui.text_eb95753f",
											desc = "ui.bfa_343bc453",
											order = 6,
											width = "full",
											get = function()
												return SarychUI.db.profile.modules.mainmenubar.hideReputationOverlayTextures == true
											end,
											set = function(_, value)
												SarychUI.db.profile.modules.mainmenubar.hideReputationOverlayTextures = value and true or false
												local bars = SarychUI.modules and SarychUI.modules.mainmenubar
												if bars and bars.ApplyReputationOverlayVisibility then
													bars:ApplyReputationOverlayVisibility()
												end
												RefreshStylePreviews()
											end,
										},
                                    },
                                },

                                dragonSpacingBox = {
                                    type = "group",
                                    name = "ui.text_b101eb63",
                                    order = 25,
                                    inline = true,
                                    hidden = function()
                                        return SarychUI.db.profile.modules.mainmenubar.barStyle ~= "dragon"
                                    end,
                                    args = {
                                        spacing = {
                                            type = "range",
                                            name = "ui.text_d6887791",
                                            desc = "ui.text_3b94034a",
                                            order = 1,
                                            min = 0,
                                            max = 20,
                                            step = 1,
                                            get = function()
                                                return SarychUI.db.profile.modules.mainmenubar.dragonSpacing or 6
                                            end,
                                            set = function(_, value)
                                                SarychUI.db.profile.modules.mainmenubar.dragonSpacing = value
                                                local bars = SarychUI.modules and SarychUI.modules.mainmenubar
                                                if bars and bars.DragonStyle and bars.DragonStyle.active then
                                                    bars.DragonStyle:Layout()
                                                end
                                            end,
                                        },
                                    },
                                },

                                microMenuStyleBox = {
                                    type = "group",
                                    name = "ui.micro_menu_0fc8f435",
                                    order = 28,
                                    inline = true,
                                    args = {
                                        microMenuStyle = {
                                            type = "select",
                                            name = "ui.appearance_c407960b",
                                            desc = "ui.micro_menu_button_textures_position_and_size_sta_9fb84928",
                                            order = 1,
                                            width = "full",
                                            values = {
                                                classic = SarychUI:T("ui.options_03ced8ccad"),
                                                dragonflight = "Dragonflight",
                                            },
                                            get = function()
                                                return SarychUI.db.profile.modules.mainmenubar.microMenuStyle or "dragonflight"
                                            end,
                                            set = function(_, value)
                                                local db = SarychUI.db.profile.modules.mainmenubar
                                                local previous = db.microMenuStyle or "dragonflight"
                                                if previous == value then return end
                                                db.microMenuStyle = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                                local text = SarychUI:T("ui.options_1a2759db3f")
                                                local function revert()
                                                    db.microMenuStyle = previous
                                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                        SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                    end
                                                    if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                        SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                    end
                                                    NotifyOptionsChange()
                                                end
                                                if SarychUI.ShowReloadPopup then
                                                    SarychUI:ShowReloadPopup(text, revert)
                                                end
                                            end,
                                        },
                                        microMenuHideGreenLatency = {
                                            type = "toggle",
                                            name = "ui.hide_latency_indicator_when_network_is_green_587322e2",
                                            desc = "ui.hides_the_latency_pip_on_the_menu_button_while_p_7794ebb0",
                                            order = 2,
                                            width = "full",
                                            hidden = function()
                                                local db = SarychUI.db.profile.modules.mainmenubar
                                                return (db.microMenuStyle or "dragonflight") ~= "dragonflight"
                                            end,
                                            get = function()
                                                local db = SarychUI.db.profile.modules.mainmenubar
                                                return db.microMenuHideGreenLatency ~= false
                                            end,
                                            set = function(_, value)
                                                SarychUI.db.profile.modules.mainmenubar.microMenuHideGreenLatency = value and true or false
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                    },
                                },
                                interfaceBox = {
                                    type = "group",
                                    name = "ui.interface_elements_3a0c9ba0",
                                    order = 30,
                                    inline = true,
                                    args = {
                                        hide_keyring_button = {
                                            type = "toggle",
                                            name = L["Hide_Keyring_Button"],
                                            desc = L["Hide_Keyring_Button_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideKeyringButton
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideKeyringButton = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateKeyringButton()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                        hide_page_buttons = {
                                            type = "toggle",
                                            name = L["Hide_Page_Buttons"],
                                            desc = L["Hide_Page_Buttons_Desc"],
                                            order = 2,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hidePageButtons
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hidePageButtons = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdatePageButtons()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },

                                pageNumbersBox = {
                                    type = "group",
                                    name = "ui.page_number_56f18b2b",
                                    order = 40,
                                    inline = true,
                                    args = {
                                        hide_page_numbers = {
                                            type = "toggle",
                                            name = L["Hide_Page_Numbers"],
                                            desc = L["Hide_Page_Numbers_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hidePageNumbers = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdatePageNumbers()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        show_page_numbers_in_combat = {
                                            type = "toggle",
                                            name = L["Show_Page_Numbers_In_Combat"],
                                            desc = L["Show_Page_Numbers_In_Combat_Desc"],
                                            order = 2,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showPageNumbersInCombat
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showPageNumbersInCombat = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                        show_page_numbers_on_alt = {
                                            type = "toggle",
                                            name = L["Show_Page_Numbers_On_Alt"],
                                            desc = L["Show_Page_Numbers_On_Alt_Desc"],
                                            order = 3,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showPageNumbersOnAlt
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showPageNumbersOnAlt = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdatePageNumbers()
                                                end
                                            end,
                                        },
                                        page_numbers_fade_after_combat = {
                                            type = "toggle",
                                            name = L["Page_Numbers_Fade_After_Combat"],
                                            desc = L["Page_Numbers_Fade_After_Combat_Desc"],
                                            order = 4,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeAfterCombat
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeAfterCombat = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        page_numbers_fade_time = {
                                            type = "range",
                                            name = L["Page_Numbers_Fade_Time"],
                                            desc = L["Page_Numbers_Fade_Time_Desc"],
                                            order = 5,
                                            min = 0.1,
                                            max = 2.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hidePageNumbers
                                                    or not SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeAfterCombat
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.pageNumbersFadeTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                    },
                                },
                            },
                        },
                        
                        -- Transparency tab
                        transparency = {
                            type = "group",
                            name = "ui.transparency_94a43d8b",
                            order = 2,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiPreview = "ActionBarTransparencyPreview",
                                },

                                borderBox = {
                                    type = "group",
                                    name = L["Button_Border_Alpha"],
                                    order = 10,
                                    inline = true,
                                    disabled = InterfaceStyleActive,
                                    args = {
                                        button_border_alpha_enabled = {
                                            type = "toggle",
                                            name = "ui.enable_transparency_33d8cb9a",
                                            desc = L["Button_Border_Alpha_Desc"],
                                            order = 1,
                                            width = "full",
                                            disabled = InterfaceStyleActive,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.buttonBorderAlphaEnabled
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.buttonBorderAlphaEnabled = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        button_border_alpha = {
                                            type = "range",
                                            name = "ui.outline_transparency_c422cce3",
                                            desc = "ui.button_outline_transparency_0_invisible_1_fully__73691cd0",
                                            order = 2,
                                            min = 0,
                                            max = 1,
                                            step = 0.05,
                                            width = "full",
                                            disabled = function()
                                                return InterfaceStyleActive()
                                                    or not SarychUI.db.profile.modules.mainmenubar.buttonBorderAlphaEnabled
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.buttonBorderAlpha
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.buttonBorderAlpha = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },

                                microBox = {
                                    type = "group",
                                    name = L["MicroMenu_Alpha"],
                                    order = 20,
                                    inline = true,
                                    args = {
                                        micro_menu_alpha_enabled = {
                                            type = "toggle",
                                            name = "ui.enable_transparency_33d8cb9a",
                                            desc = L["MicroMenu_Alpha_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.microMenuAlphaEnabled
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.microMenuAlphaEnabled = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        micro_menu_alpha = {
                                            type = "range",
                                            name = "ui.micro_menu_transparency_de97cb0a",
                                            desc = "ui.micro_menu_button_transparency_0_invisible_1_ful_404986db",
                                            order = 2,
                                            min = 0,
                                            max = 1,
                                            step = 0.05,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.microMenuAlphaEnabled
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.microMenuAlpha
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.microMenuAlpha = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                            end,
                                        },
                                        micro_menu_show_on_mouseover = {
                                            type = "toggle",
                                            name = "ui.text_f3cc55ce",
                                            desc = "ui.1_e57d364e",
                                            order = 3,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.microMenuAlphaEnabled
                                            end,
                                            get = function()
                                                return SarychUI.db.profile.modules.mainmenubar.microMenuShowOnMouseover == true
                                            end,
                                            set = function(_, value)
                                                SarychUI.db.profile.modules.mainmenubar.microMenuShowOnMouseover = value and true or false
                                                local bars = SarychUI.modules and SarychUI.modules.mainmenubar
                                                if bars then bars:ApplyAppearanceSettings() end
                                            end,
                                        },
                                    },
                                },

                                bagBox = {
                                    type = "group",
                                    name = L["Bags_Alpha"],
                                    order = 30,
                                    inline = true,
                                    args = {
                                        bag_alpha_enabled = {
                                            type = "toggle",
                                            name = "ui.enable_transparency_33d8cb9a",
                                            desc = L["Bags_Alpha_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.bagAlphaEnabled
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.bagAlphaEnabled = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        bag_alpha = {
                                            type = "range",
                                            name = "ui.bag_button_transparency_e844ea66",
                                            desc = "ui.bag_button_transparency_0_invisible_1_fully_visi_e03a0265",
                                            order = 2,
                                            min = 0,
                                            max = 1,
                                            step = 0.05,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.bagAlphaEnabled
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.bagAlpha
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.bagAlpha = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarTransparencyPreview and SarychUI.ActionBarTransparencyPreview.RefreshAll then
                                                    SarychUI.ActionBarTransparencyPreview:RefreshAll()
                                                end
                                            end,
                                        },
                                        bag_show_on_mouseover = {
                                            type = "toggle",
                                            name = "ui.text_f3cc55ce",
                                            desc = "ui.1_f239bfa5",
                                            order = 3,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.bagAlphaEnabled
                                            end,
                                            get = function()
                                                return SarychUI.db.profile.modules.mainmenubar.bagShowOnMouseover == true
                                            end,
                                            set = function(_, value)
                                                SarychUI.db.profile.modules.mainmenubar.bagShowOnMouseover = value and true or false
                                                local bars = SarychUI.modules and SarychUI.modules.mainmenubar
                                                if bars then bars:ApplyAppearanceSettings() end
                                            end,
                                        },
                                    },
                                },
                            },
                        },
                        
                        -- Bars tab
                        bars = {
                            type = "group",
                            name = "ui.bars_7dc1159f",
                            order = 3,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiPreview = "ActionBarBarsPreview",
                                },

                                reputationBox = {
                                    type = "group",
                                    name = "ui.reputation_bar_af35bfcb",
                                    order = 10,
                                    inline = true,
                                    args = {
                                        hide_reputation_bar = {
                                            type = "toggle",
                                            name = L["Hide_Reputation_Bar"],
                                            desc = L["Hide_Reputation_Bar_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideReputationBar = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateReputationBar()
                                                end
                                                if SarychUI.ActionBarBarsPreview and SarychUI.ActionBarBarsPreview.RefreshAll then
                                                    SarychUI.ActionBarBarsPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        show_reputation_bar_on_alt = {
                                            type = "toggle",
                                            name = L["Show_Reputation_Bar_On_Alt"],
                                            desc = L["Show_Reputation_Bar_On_Alt_Desc"],
                                            order = 2,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showReputationBarOnAlt
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showReputationBarOnAlt = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateReputationBar()
                                                end
                                            end,
                                        },
                                        show_reputation_bar_on_gain = {
                                            type = "toggle",
                                            name = L["Show_Reputation_Bar_On_Gain"],
                                            desc = L["Show_Reputation_Bar_On_Gain_Desc"],
                                            order = 3,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showReputationBarOnGain
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showReputationBarOnGain = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        reputation_bar_fade_time = {
                                            type = "range",
                                            name = L["Reputation_Bar_Fade_Time"],
                                            desc = L["Reputation_Bar_Fade_Time_Desc"],
                                            order = 4,
                                            min = 0.1,
                                            max = 2.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                                    or not SarychUI.db.profile.modules.mainmenubar.showReputationBarOnGain
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.reputationBarFadeTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.reputationBarFadeTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                        reputation_bar_show_time = {
                                            type = "range",
                                            name = L["Reputation_Bar_Show_Time"],
                                            desc = L["Reputation_Bar_Show_Time_Desc"],
                                            order = 5,
                                            min = 0.5,
                                            max = 5.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideReputationBar
                                                    or not SarychUI.db.profile.modules.mainmenubar.showReputationBarOnGain
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.reputationBarShowTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.reputationBarShowTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                    },
                                },

                                experienceBox = {
                                    type = "group",
                                    name = "ui.experience_bar_166a7881",
                                    order = 20,
                                    inline = true,
                                    args = {
                                        hide_experience_bar = {
                                            type = "toggle",
                                            name = L["Hide_Experience_Bar"],
                                            desc = L["Hide_Experience_Bar_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideExperienceBar = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateExperienceBar()
                                                end
                                                if SarychUI.ActionBarBarsPreview and SarychUI.ActionBarBarsPreview.RefreshAll then
                                                    SarychUI.ActionBarBarsPreview:RefreshAll()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        show_experience_bar_on_alt = {
                                            type = "toggle",
                                            name = L["Show_Experience_Bar_On_Alt"],
                                            desc = L["Show_Experience_Bar_On_Alt_Desc"],
                                            order = 2,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnAlt
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnAlt = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateExperienceBar()
                                                end
                                            end,
                                        },
                                        show_experience_bar_on_gain = {
                                            type = "toggle",
                                            name = L["Show_Experience_Bar_On_Gain"],
                                            desc = L["Show_Experience_Bar_On_Gain_Desc"],
                                            order = 3,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnGain
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnGain = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        experience_bar_fade_time = {
                                            type = "range",
                                            name = L["Experience_Bar_Fade_Time"],
                                            desc = L["Experience_Bar_Fade_Time_Desc"],
                                            order = 4,
                                            min = 0.1,
                                            max = 2.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                                    or not SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnGain
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.experienceBarFadeTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.experienceBarFadeTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                        experience_bar_show_time = {
                                            type = "range",
                                            name = L["Experience_Bar_Show_Time"],
                                            desc = L["Experience_Bar_Show_Time_Desc"],
                                            order = 5,
                                            min = 0.5,
                                            max = 5.0,
                                            step = 0.1,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideExperienceBar
                                                    or not SarychUI.db.profile.modules.mainmenubar.showExperienceBarOnGain
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.experienceBarShowTime
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.experienceBarShowTime = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                            end,
                                        },
                                    },
                                },
                            },
                        },
                        
                        -- Other tab
                        other = {
                            type = "group",
                            name = "ui.other_001f75c6",
                            order = 4,
                            args = {
                                fpsBox = {
                                    type = "group",
                                    name = "ui.options_fce204ae55",
                                    desc = "ui.fps_indicator_settings_while_alt_is_held_5b753e01",
                                    order = 20,
                                    inline = true,
                                    suiTwoCol = true,
                                    suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                    args = {
                                        enableAltFPS = {
                                            type = "toggle",
                                            name = "ui.show_fps_while_holding_cffffd700alt_r_ef22a0a6",
                                            desc = "ui.shows_fps_in_the_top_left_corner_while_holding_c_edc99e0d",
                                            order = 1,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            get = function() return ToolsFpsEnabled() end,
                                            set = function(_, val)
                                                local db = ToolsDB()
                                                if not db then return end
                                                db.enableAltFPS = val and 1 or 0
                                                local tools = SarychUI.modules and SarychUI.modules
                                                if tools and SarychUI.modules.mainmenubar.ApplyAltFPS then SarychUI.modules.mainmenubar:ApplyAltFPS() end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        fpsScale = {
                                            type = "range",
                                            name = "ui.fps_scale_5c092526",
                                            desc = "ui.fps_indicator_size_while_holding_cffffd700alt_r__4d314bdb",
                                            order = 2,
                                            width = "full",
                                            suiFullRow = true,
                                            min = 0.5, max = 2.0, step = 0.05,
                                            get = function()
                                                local db = ToolsDB()
                                                return (db and db.fpsScale) or 1.0
                                            end,
                                            set = function(_, val)
                                                local db = ToolsDB()
                                                if not db then return end
                                                db.fpsScale = val
                                                local tools = SarychUI.modules and SarychUI.modules
                                                if tools and SarychUI.modules.mainmenubar.ApplyFpsScale then SarychUI.modules.mainmenubar:ApplyFpsScale() end
                                            end,
                                            disabled = function() return not ToolsFpsEnabled() end,
                                        },
                                        fpsExtraOffsetX = {
                                            type = "range",
                                            name = "ui.x_offset_0b923c73",
                                            desc = "ui.extra_fps_indicator_horizontal_offset_from_the_b_b82e5264",
                                            order = 3,
                                            min = -300, max = 300, step = 1,
                                            get = function()
                                                local db = ToolsDB()
                                                return (db and db.fpsExtraOffsetX) or 0
                                            end,
                                            set = function(_, val)
                                                local db = ToolsDB()
                                                if not db then return end
                                                db.fpsExtraOffsetX = val
                                                local tools = SarychUI.modules and SarychUI.modules
                                                if tools and SarychUI.modules.mainmenubar.SetFpsPosition then SarychUI.modules.mainmenubar:SetFpsPosition() end
                                            end,
                                            disabled = function() return not ToolsFpsEnabled() end,
                                        },
                                        fpsExtraOffsetY = {
                                            type = "range",
                                            name = "ui.y_offset_f7f3fdd7",
                                            desc = "ui.extra_fps_indicator_vertical_offset_from_the_bas_0d065096",
                                            order = 4,
                                            min = -300, max = 300, step = 1,
                                            get = function()
                                                local db = ToolsDB()
                                                return (db and db.fpsExtraOffsetY) or 0
                                            end,
                                            set = function(_, val)
                                                local db = ToolsDB()
                                                if not db then return end
                                                db.fpsExtraOffsetY = val
                                                local tools = SarychUI.modules and SarychUI.modules
                                                if tools and SarychUI.modules.mainmenubar.SetFpsPosition then SarychUI.modules.mainmenubar:SetFpsPosition() end
                                            end,
                                            disabled = function() return not ToolsFpsEnabled() end,
                                        },
                                    },
                                },
                                sidePanelsBox = {
                                    type = "group",
                                    name = "ui.side_panels_d0eaeda0",
                                    order = 10,
                                    inline = true,
                                    args = {
                                        hide_side_panels = {
                                            type = "toggle",
                                            name = L["Hide_Side_Panels"],
                                            desc = L["Hide_Side_Panels_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideSidePanels
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideSidePanels = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateSidePanels()
                                                end
                                                NotifyOptionsChange()
                                            end,
                                        },
                                        show_side_panels_on_alt = {
                                            type = "toggle",
                                            name = L["Show_Side_Panels_On_Alt"],
                                            desc = L["Show_Side_Panels_On_Alt_Desc"],
                                            order = 2,
                                            width = "full",
                                            suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.hideSidePanels
                                            end,
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.showSidePanelsOnAlt
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.showSidePanelsOnAlt = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:UpdateSidePanels()
                                                end
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

    return options
end

-- Export options function
SarychUI.modules.mainmenubar.GetOptions = GetOptions
