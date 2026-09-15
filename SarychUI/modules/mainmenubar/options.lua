-- SarychUI MainMenuBar Module Options
-- Options interface for main menu bar customization

local moduleName = "mainmenubar"
local L = SarychUI.L

local function NotifyOptionsChange()
	if SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

-- Get options table for this module
local function GetOptions()
    return {
        name = L["MainMenuBar"],
        type = "group",
        desc = L and (L["MainMenuBar_Description"] or "Настройка главной панели команд и панелей действий") or "Настройка главной панели команд и панелей действий",
        childGroups = "tab",
        args = {
            -- General tab
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                args = {
                    header = {
                        type = "header",
                        name = L["MainMenuBar"],
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable_Module"],
                        desc = "Включить или выключить модуль",
                        order = 3,
                        width = "full",
                        get = function(info)
                            return SarychUI.db.profile.modules.mainmenubar.enabled
                        end,
                        set = function(info, value)
                            SarychUI.db.profile.modules.mainmenubar.enabled = value
                            if value then
                                SarychUI:EnableModule(moduleName)
                            else
                                SarychUI:DisableModule(moduleName)
                            end
                        end,
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
                        suiActionBarTextPreview = true,
                    },

                    hotkeysBox = {
                        type = "group",
                        name = L["Hotkeys"],
                        order = 10,
                        inline = true,
                        args = {
                            hide_hotkeys = {
                                type = "toggle",
                                name = L["Hide_Hotkeys"],
                                desc = L["Hide_Hotkeys_Desc"],
                                order = 1,
                                width = "full",
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllHotkeys()
                                    end
                                    if SarychUI.ActionBarTextPreview and SarychUI.ActionBarTextPreview.RefreshAll then
                                        SarychUI.ActionBarTextPreview:RefreshAll()
                                    end
                                    -- Refresh dependent disabled states in this block.
                                    NotifyOptionsChange()
                                end,
                            },
                            show_in_combat = {
                                type = "toggle",
                                name = L["Show_In_Combat"],
                                desc = L["Show_In_Combat_Desc"],
                                order = 2,
                                width = "full",
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
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
                                order = 3,
                                width = "full",
                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
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
                                order = 4,
                                width = "full",
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
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
                                order = 5,
                                width = "full",
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                end,
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
                                order = 6,
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                disabled = function()
                                    return not SarychUI.db.profile.modules.mainmenubar.hideHotkeysEnabled
                                        or not SarychUI.db.profile.modules.mainmenubar.hotkeysFadeAfterCombat
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
                        },
                    },

                    macrosBox = {
                        type = "group",
                        name = L["Macros"],
                        order = 20,
                        inline = true,
                        args = {
                            hide_macro_names = {
                                type = "toggle",
                                name = L["Hide_Macro_Names"],
                                desc = L["Hide_Macro_Names_Desc"],
                                order = 1,
                                width = "full",
                                get = function(info)
                                    return SarychUI.db.profile.modules.mainmenubar.hideMacroNames
                                end,
                                set = function(info, value)
                                    SarychUI.db.profile.modules.mainmenubar.hideMacroNames = value
                                    if SarychUI.modules and SarychUI.modules.mainmenubar then
                                        SarychUI.modules.mainmenubar:UpdateAllMacroNames()
                                    end
                                    if SarychUI.ActionBarTextPreview and SarychUI.ActionBarTextPreview.RefreshAll then
                                        SarychUI.ActionBarTextPreview:RefreshAll()
                                    end
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
                            suiActionBarColorPreview = true,
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
                                color_cooldown_alpha = {
                                    type = "range",
                                    name = L["Color_Cooldown_Alpha"],
                                    desc = L["Color_Cooldown_Alpha_Desc"],
                                    order = 2,
                                    min = 0,
                                    max = 1,
                                    step = 0.1,
                                    disabled = function()
                                        return not SarychUI.db.profile.modules.mainmenubar.colorCooldownEnabled
                                    end,
                                    get = function(info)
                                        return SarychUI.db.profile.modules.mainmenubar.colorCooldownAlpha
                                    end,
                                    set = function(info, value)
                                        SarychUI.db.profile.modules.mainmenubar.colorCooldownAlpha = value
                                        if SarychUI.modules and SarychUI.modules.mainmenubar then
                                            SarychUI.modules.mainmenubar:UpdateColorIndication()
                                        end
                                        if SarychUI.ActionBarColorPreview and SarychUI.ActionBarColorPreview.RefreshAll then
                                            SarychUI.ActionBarColorPreview:RefreshAll()
                                        end
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
                            name = "Визуальные улучшения",
                            order = 1,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiActionBarAppearancePreview = true,
                                },

                                gryphonsBox = {
                                    type = "group",
                                    name = "Грифоны",
                                    order = 10,
                                    inline = true,
                                    args = {
                                        hide_gryphons = {
                                            type = "toggle",
                                            name = L["Hide_Gryphons"],
                                            desc = L["Hide_Gryphons_Desc"],
                                            order = 1,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideGryphons
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideGryphons = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
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
                                    name = "Фоновые текстуры",
                                    order = 20,
                                    inline = true,
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
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                        hide_secondary_panels_backgrounds = {
                                            type = "toggle",
                                            name = L["Hide_Secondary_Panels_Backgrounds"],
                                            desc = L["Hide_Secondary_Panels_Backgrounds_Desc"],
                                            order = 2,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideSecondaryPanelsBackgrounds
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideSecondaryPanelsBackgrounds = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
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
                                            order = 3,
                                            width = "full",
                                            get = function(info)
                                                return SarychUI.db.profile.modules.mainmenubar.hideMaxLevelBar
                                            end,
                                            set = function(info, value)
                                                SarychUI.db.profile.modules.mainmenubar.hideMaxLevelBar = value
                                                if SarychUI.modules and SarychUI.modules.mainmenubar then
                                                    SarychUI.modules.mainmenubar:ApplyAppearanceSettings()
                                                end
                                                if SarychUI.ActionBarAppearancePreview and SarychUI.ActionBarAppearancePreview.RefreshAll then
                                                    SarychUI.ActionBarAppearancePreview:RefreshAll()
                                                end
                                            end,
                                        },
                                    },
                                },

                                interfaceBox = {
                                    type = "group",
                                    name = "Элементы интерфейса",
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
                                    name = "Номер страницы",
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
                            name = "Прозрачность",
                            order = 2,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiActionBarTransparencyPreview = true,
                                },

                                borderBox = {
                                    type = "group",
                                    name = L["Button_Border_Alpha"],
                                    order = 10,
                                    inline = true,
                                    args = {
                                        button_border_alpha_enabled = {
                                            type = "toggle",
                                            name = "Включить прозрачность",
                                            desc = L["Button_Border_Alpha_Desc"],
                                            order = 1,
                                            width = "full",
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
                                            name = "Прозрачность обводки",
                                            desc = "Прозрачность обводки кнопок (0 - невидимая, 1 - полностью видимая)",
                                            order = 2,
                                            min = 0,
                                            max = 1,
                                            step = 0.05,
                                            width = "full",
                                            disabled = function()
                                                return not SarychUI.db.profile.modules.mainmenubar.buttonBorderAlphaEnabled
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
                                            name = "Включить прозрачность",
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
                                            name = "Прозрачность микроменю",
                                            desc = "Прозрачность кнопок микроменю (0 - невидимая, 1 - полностью видимая)",
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
                                    },
                                },
                            },
                        },
                        
                        -- Bars tab
                        bars = {
                            type = "group",
                            name = "Полосы",
                            order = 3,
                            args = {
                                preview = {
                                    type = "description",
                                    name = "",
                                    order = 1,
                                    width = "full",
                                    suiActionBarBarsPreview = true,
                                },

                                reputationBox = {
                                    type = "group",
                                    name = "Полоса репутации",
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
                                    name = "Полоса опыта",
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
                            name = "Другое",
                            order = 4,
                            args = {
                                microMenuStyleBox = {
                                    type = "group",
                                    name = "Микроменю",
                                    order = 1,
                                    inline = true,
                                    args = {
                                        microMenuStyle = {
                                            type = "select",
                                            name = "Внешний вид",
                                            desc = "Текстуры кнопок микроменю. Расположение и размер не меняются.",
                                            order = 1,
                                            width = "full",
                                            values = {
                                                classic = "Классические",
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
                                                local text = "Для применения внешнего вида микроменю требуется перезагрузка интерфейса."
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
                                                elseif StaticPopup_Show then
                                                    StaticPopup_Show("SARYCHUI_RELOAD_UI")
                                                end
                                            end,
                                        },
                                        microMenuHideGreenLatency = {
                                            type = "toggle",
                                            name = "Скрывать индикатор при зелёной сети",
                                            desc = "Прячет индикатор задержки на кнопке меню, пока пинг зелёный. При жёлтом или красном — показывает. Только для внешнего вида Dragonflight.",
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
                                sidePanelsBox = {
                                    type = "group",
                                    name = "Боковые панели",
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
end

-- Export options function
SarychUI.modules.mainmenubar.GetOptions = GetOptions
