-- SarychUI Cooldowns and Timers extension options
local moduleName = "cc"
local module = SarychUI:GetModule(moduleName)

-- Localization
local L = SarychUI.L


-- Helpers
local function isEnabled()
    local db = SarychUI:GetModuleProfile(moduleName)
    if db and db.enabled ~= nil then
        return db.enabled
    end
    return true
end

local function GetSetting(key, default)
    local db = SarychUI:GetModuleProfile(moduleName)
    if db and db[key] ~= nil then return db[key] end
    return default
end

local function SetAndApply(key, value)
    local db = SarychUI:GetModuleProfile(moduleName)
    if not db then return end
    db[key] = value
    local dragging = SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging()
    if module and module.ApplySettings then
        module:ApplySettings()
    end
    -- While dragging, fonts update via SetLiveValue/RefreshStyle only.
    if dragging then
        return
    end
    if SarychUI.CooldownTextPreview and SarychUI.CooldownTextPreview.RefreshAll then
        SarychUI.CooldownTextPreview:RefreshAll()
    end
    if SarychUI.GcdCooldownPreview and SarychUI.GcdCooldownPreview.RefreshAll then
        SarychUI.GcdCooldownPreview:RefreshAll()
    end
end

local function SetAndPreview(key, value)
    SetAndApply(key, value)
    if SarychUI.CooldownTextPreview and SarychUI.CooldownTextPreview.SetLiveValue then
        SarychUI.CooldownTextPreview:SetLiveValue(key, value)
    end
    if SarychUI.GcdCooldownPreview and SarychUI.GcdCooldownPreview.SetLiveValue then
        SarychUI.GcdCooldownPreview:SetLiveValue(key, value)
    end
end

local function timerToggleGet(key)
    return function()
        return GetSetting(key, 1) == 1 or GetSetting(key, 1) == true
    end
end

local function timerToggleSet(key, applyFn)
    return function(_, val)
        local db = SarychUI:GetModuleProfile(moduleName)
        if not db then return end
        db[key] = val and 1 or 0
        local tools = SarychUI and SarychUI.modules and SarychUI.modules
        if tools and applyFn and tools[applyFn] then
            tools[applyFn](tools)
        end
        -- Update timer previews immediately (hide/show sample timers).
        if SarychUI.CastbarTimerPreview and SarychUI.CastbarTimerPreview.RefreshAll then
            SarychUI.CastbarTimerPreview:RefreshAll()
        end
        if SarychUI.CountdownTimerPreview and SarychUI.CountdownTimerPreview.RefreshAll then
            SarychUI.CountdownTimerPreview:RefreshAll()
        end
        -- Rebuild options UI so dependent disabled states update immediately.
        if SarychUI.NotifySarychUIOptionsChange then
            SarychUI:NotifySarychUIOptionsChange()
        elseif SarychUI.RefreshConfig then
            SarychUI:RefreshConfig()
        end
    end
end

function module:GetOptions()
    return {
        type = "group",
        name = L and (L["Cooldown Text"] or SarychUI:T("ui.options_3911356ba6")) or SarychUI:T("ui.options_3911356ba6"),
        desc = L and (L["CooldownText_Description"] or SarychUI:T("ui.options_7b235925d8")) or SarychUI:T("ui.options_7b235925d8"),
        suiBodyDisabled = function() return not isEnabled() end,
        childGroups = "tab",
        args = {
            enabled = {
                type = "toggle", name = "ui.enable_a54eaf37", order = 0,
                get = isEnabled,
                set = function(_, value)
                    if value then SarychUI:EnableModule(moduleName)
                    else SarychUI:DisableModule(moduleName) end
                    if SarychUI.OptionsCore then SarychUI.OptionsCore:ScheduleSmartRefresh(true) end
                end,
            },
            -- General
            general = {
                type = "group",
                name = L and (L["General"] or SarychUI:T("ui.general_b250a3d6")) or SarychUI:T("ui.general_b250a3d6"),
                order = 1,
                args = {
                    appearanceBox = {
                        type = "group",
                        name = L and (L["Cooldown_Text"] or SarychUI:T("ui.options_e47c642670")) or SarychUI:T("ui.options_e47c642670"),
                        order = 10,
                        inline = true,
                        suiTwoCol = true,
                        disabled = function() return not isEnabled() end,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiFullRow = true,
                                suiPreview = "CooldownTextPreview",
                            },
                            font = {
                                type = "select",
                                style = "dropdown",
                                name = L and (L["Font"] or SarychUI:T("ui.font_23997845")) or SarychUI:T("ui.font_23997845"),
                                order = 1,
                                values = function()
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
                                end,
                                get = function() return GetSetting("font", "Friz Quadrata TT") end,
                                set = function(_, v) SetAndPreview("font", v) end,
                            },
                            fontFlags = {
                                type = "select",
                                style = "dropdown",
                                name = L and (L["Font_Flags"] or SarychUI:T("ui.options_63a10b583e")) or SarychUI:T("ui.options_63a10b583e"),
                                desc = L and (L["Font_Flags_Desc"] or SarychUI:T("ui.options_7c755932a8")) or SarychUI:T("ui.options_7c755932a8"),
                                values = function()
                                    if SarychUI_FontOutlineValues and SarychUI_FontOutlineValues.GetSelectValues then
                                        return SarychUI_FontOutlineValues.GetSelectValues(L)
                                    end
                                    return {
                                        ["NONE"] = "NONE",
                                        ["OUTLINE"] = "OUTLINE",
                                        ["THICKOUTLINE"] = "THICKOUTLINE",
                                        ["MONOCHROMEOUTLINE"] = "MONOCHROMEOUTLINE",
                                    }
                                end,
                                order = 2,
                                get = function() return GetSetting("fontFlags", "OUTLINE") end,
                                set = function(_, v) SetAndPreview("fontFlags", v) end,
                            },
                            fontSizeSmall = {
                                type = "range",
                                name = L and (L["Font_Size_Small"] or SarychUI:T("ui.options_b5750a4f36")) or SarychUI:T("ui.options_b5750a4f36"),
                                desc = L and (L["Font_Size_Small_Desc"] or SarychUI:T("ui.options_f4140d1032")) or SarychUI:T("ui.options_f4140d1032"),
                                min = 6, max = 32, step = 1,
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                suiPreviewKey = "fontSizeSmall",
                                get = function() return GetSetting("fontSizeSmall", 14) end,
                                set = function(_, v) SetAndPreview("fontSizeSmall", v) end,
                            },
                            fontSizeMedium = {
                                type = "range",
                                name = L and (L["Font_Size_Medium"] or SarychUI:T("ui.options_6c97783056")) or SarychUI:T("ui.options_6c97783056"),
                                desc = L and (L["Font_Size_Medium_Desc"] or SarychUI:T("ui.options_7b679d13be")) or SarychUI:T("ui.options_7b679d13be"),
                                min = 6, max = 32, step = 1,
                                order = 4,
                                width = "full",
                                suiFullRow = true,
                                suiPreviewKey = "fontSizeMedium",
                                get = function() return GetSetting("fontSizeMedium", 12) end,
                                set = function(_, v) SetAndPreview("fontSizeMedium", v) end,
                            },
                            fontSizeLarge = {
                                type = "range",
                                name = L and (L["Font_Size_Large"] or SarychUI:T("ui.options_07fb4be23e")) or SarychUI:T("ui.options_07fb4be23e"),
                                desc = L and (L["Font_Size_Large_Desc"] or SarychUI:T("ui.options_1a9725134c")) or SarychUI:T("ui.options_1a9725134c"),
                                min = 6, max = 32, step = 1,
                                order = 5,
                                width = "full",
                                suiFullRow = true,
                                suiPreviewKey = "fontSizeLarge",
                                get = function() return GetSetting("fontSizeLarge", 12) end,
                                set = function(_, v) SetAndPreview("fontSizeLarge", v) end,
                            },
                            defaultColor = {
                                type = "color",
                                name = L and (L["Default_Color"] or SarychUI:T("ui.options_a4ea8f8010")) or SarychUI:T("ui.options_a4ea8f8010"),
                                hasAlpha = true,
                                order = 6,
                                width = "full",
                                suiFullRow = true,
                                get = function()
                                    local c = GetSetting("defaultColor", {1,1,1,1})
                                    return c[1], c[2], c[3], c[4]
                                end,
                                set = function(_, r, g, b, a)
                                    SetAndPreview("defaultColor", {r, g, b, a})
                                end,
                            },
                            lastFiveSecondsRed = {
                                type = "toggle", name = "ui.cc.last_five_red",
                                order = 7, width = "full", suiFullRow = true,
                                get = function() return GetSetting("lastFiveSecondsRed", false) end,
                                set = function(_, value) SetAndApply("lastFiveSecondsRed", value) end,
                            },
                        },
                    },

                    conditionsBox = {
                        type = "group",
                        name = L and (L["Display_Conditions_Settings"] or SarychUI:T("ui.options_3acfc67231")) or SarychUI:T("ui.options_3acfc67231"),
                        order = 20,
                        inline = true,
                        suiTwoCol = true,
                        disabled = function() return not isEnabled() end,
                        args = {
                            minScale = {
                                type = "range",
                                name = L and (L["Min_Scale"] or SarychUI:T("ui.options_74a0b56dc5")) or SarychUI:T("ui.options_74a0b56dc5"),
                                desc = L and (L["Min_Scale_Desc"] or SarychUI:T("ui.options_9152e2ebcc")) or "",
                                min = 0.1, max = 2.0, step = 0.05,
                                order = 1,
                                get = function() return GetSetting("minScale", 0.5) end,
                                set = function(_, v) SetAndApply("minScale", v) end,
                            },
                            minIconSize = {
                                type = "range",
                                name = L and (L["Min_Icon_Size"] or SarychUI:T("ui.options_cbd4b83753")) or SarychUI:T("ui.options_cbd4b83753"),
                                desc = L and (L["Min_Icon_Size_Desc"] or SarychUI:T("ui.options_8f97405999")) or SarychUI:T("ui.options_8f97405999"),
                                min = 8, max = 64, step = 1,
                                order = 2,
                                get = function() return GetSetting("minIconSize", 23) end,
                                set = function(_, v) SetAndApply("minIconSize", v) end,
                            },
                            partyAbilitiesExempt = {
                                type = "toggle",
                                name = L and L["CC_PartyAbilitiesExempt"] or SarychUI:T("ui.options_ad29df6958"),
                                desc = L and L["CC_PartyAbilitiesExempt_Desc"] or SarychUI:T("ui.options_ce260ee48d"),
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                get = function() return GetSetting("partyAbilitiesExempt", true) and true or false end,
                                set = function(_, v) SetAndApply("partyAbilitiesExempt", v and true or false) end,
                            },
                            gcdPreview = {
                                type = "description",
                                name = "",
                                order = 4,
                                width = "full",
                                suiFullRow = true,
                                suiPreview = "GcdCooldownPreview",
                            },
                            hideOnGCD = {
                                type = "toggle",
                                name = L and (L["Hide_On_GCD"] or SarychUI:T("ui.options_d12d271510")) or SarychUI:T("ui.options_d12d271510"),
                                desc = L and (L["Hide_On_GCD_Desc"] or SarychUI:T("ui.options_5572e0e356")) or SarychUI:T("ui.options_5572e0e356"),
                                order = 5,
                                width = "full",
                                suiFullRow = true,
                                get = function() return GetSetting("minDuration", 3) >= 3 end,
                                set = function(_, v)
                                    SetAndApply("minDuration", v and 3 or 0)
                                    if SarychUI.GcdCooldownPreview and SarychUI.GcdCooldownPreview.SetLiveValue then
                                        SarychUI.GcdCooldownPreview:SetLiveValue("minDuration", v and 3 or 0)
                                    end
                                end,
                            },
                        },
                    },
                },
            },

            -- Timers (invite / arena countdown; castbar timers live under Кастбар)
            timers = {
                type = "group",
                name = "ui.timers_46d928b9",
                order = 2,
                disabled = function() return not isEnabled() end,
                args = {
                    countdownBox = {
                        type = "group",
                        name = "ui.countdown_1f080ebd",
                        desc = "ui.countdown_timers_on_invites_the_party_raid_invit_f476f420",
                        order = 1,
                        inline = true,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiPreview = "CountdownTimerPreview",
                            },
                            enableInviteCountdown = {
                                type = "toggle",
                                name = "ui.on_invites_7cf9b0df",
                                desc = "ui.shows_a_countdown_on_party_raid_invite_and_dunge_ea691b2e",
                                order = 1,
                                width = "full",
                                get = timerToggleGet("enableInviteCountdown"),
                                set = timerToggleSet("enableInviteCountdown", "ApplyInviteCountdown"),
                            },
                            enableArenaCountdown = {
                                type = "toggle",
                                name = "ui.until_doors_open_8746f383",
                                desc = "ui.shows_a_countdown_timer_in_the_screen_center_unt_13b97172",
                                order = 2,
                                width = "full",
                                get = timerToggleGet("enableArenaCountdown"),
                                set = timerToggleSet("enableArenaCountdown", "ApplyArenaCountdown"),
                            },
                        },
                    },
                },
            },
        },
    }
end
