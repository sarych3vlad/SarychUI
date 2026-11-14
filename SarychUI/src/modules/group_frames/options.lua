local module = SarychUI.modules.group_frames
if not module then return end

local function DB()
    return SarychUI.db and SarychUI.db.profile.modules.group_frames
end
local function ActiveProfile()
    return GetActiveRaidProfile and GetActiveRaidProfile()
end
local function Option(key, kind, name, order, values, min, max, step)
    return {
        type = kind, name = name, order = order, values = values,
        min = min, max = max, step = step,
        get = function()
            local profile = ActiveProfile()
            return profile and GetRaidProfileOption(profile, key)
        end,
        set = function(_, value)
            local profile = ActiveProfile()
            if not profile then return end
            SetRaidProfileOption(profile, key, value)
            CompactUnitFrameProfiles_ApplyProfile(profile)
            module:ApplySort()
            if module.RefreshTest then module:RefreshTest() end
            if key == "displayOnlyDispellableDebuffs" then
                SarychUI:NotifySarychUIOptionsChange()
            end
        end,
    }
end
local function PresetValues()
    local values = {}
    for name in pairs((DB() and DB().presets) or {}) do values[name] = name end
    return values
end
local function PresetControls()
    return {
        selected = {
            type = "select", name = "ui.text_faaa59ea", order = 1, values = PresetValues,
            get = function() return DB() and DB().activePreset end,
            set = function(_, name) module:ApplyPreset(name) end,
        },
        newName = {
            type = "input", name = "ui.text_c2a42dfa", order = 2,
            get = function() return module.newPresetName or "" end,
            set = function(_, value) module.newPresetName = value end,
        },
        save = {
            type = "execute", name = "ui.text_124a0743", order = 3,
            func = function()
                local name = module.newPresetName
                if module:SavePreset(name) then module.newPresetName = "" end
            end,
        },
        overwrite = {
            type = "execute", name = "ui.text_792dc3ff", order = 4,
            func = function() local db = DB(); if db then module:SavePreset(db.activePreset) end end,
        },
        autoSize = {
            type = "select", name = "ui.text_14132bdc", order = 5,
            values = { [0] = SarychUI:T("ui.options_db7a3d3a19"), [2] = "2", [3] = "3", [5] = "5",
                [10] = "10", [15] = "15", [25] = "25", [40] = "40" },
            get = function()
                local db = DB(); local p = db and db.presets and db.presets[db.activePreset]
                return p and tonumber(p.autoSize) or 0
            end,
            set = function(_, value)
                local db = DB(); local p = db and db.presets and db.presets[db.activePreset]
                if p then p.autoSize = value == 0 and nil or value end
            end,
        },
        autoSpec = {
            type = "select", name = "ui.text_5d38ac98", order = 6,
            values = { any = SarychUI:T("ui.options_2f5de61f6d"), [1] = SarychUI:T("ui.options_e62f0aa5ce"), [2] = SarychUI:T("ui.options_1d33de17df") },
            get = function()
                local db = DB(); local p = db and db.presets and db.presets[db.activePreset]
                return p and p.autoSpec or "any"
            end,
            set = function(_, value)
                local db = DB(); local p = db and db.presets and db.presets[db.activePreset]
                if p then p.autoSpec = value end
            end,
        },
        remove = {
            type = "execute", name = "ui.text_7634f307", order = 7,
            func = function()
                local db = DB()
                if db then module:DeletePreset(db.activePreset) end
            end,
        },
    }
end

local function AutoFlagOption(key, name, order)
    return {
        type = "toggle", name = name, order = order,
        get = function()
            local db = DB()
            local preset = db and db.presets and db.presets[db.activePreset]
            local profile = ActiveProfile()
            return profile and GetRaidProfileOption(profile, key) and true or false
        end,
        set = function(_, value)
            local db = DB()
            local preset = db and db.presets and db.presets[db.activePreset]
            local profile = ActiveProfile()
            if profile then SetRaidProfileOption(profile, key, value and true or false) end
        end,
    }
end

function module:GetOptions()
    local root = {
        type = "group", name = "ui.text_a45747bf", childGroups = "tab",
        args = {
            settings = {
                type = "group", name = "ui.settings_985b5e0f", order = 1, childGroups = "tab",
                args = {
                    enabled = {
                        suiModuleEnable = true,
                        type = "toggle", name = "ui.enable_module_b623b573", order = 0,
                        get = function() return DB() and DB().enabled ~= false end,
                        set = function(_, value)
                            local db = DB(); if not db then return end
                            db.enabled = value
                            if value then module:Enable() else module:Disable() end
                        end,
                    },
                    frames = { type = "group", name = "ui.text_539e8252", order = 1, args = {
                        frameWidth = Option("frameWidth", "range", SarychUI:T("ui.options_1406ca4f01"), 1, nil, 30, 200, 1),
                        frameHeight = Option("frameHeight", "range", SarychUI:T("ui.options_d4e6d35ce1"), 2, nil, 20, 100, 1),
                        healthText = Option("healthText", "select", SarychUI:T("ui.options_6289321afb"), 3,
                            { none = SarychUI:T("ui.options_f82a821941"), health = SarychUI:T("ui.options_08930838eb"), losthealth = SarychUI:T("ui.options_7a917fc410"), perc = SarychUI:T("ui.options_b5a569460b") }),
                        displayPowerBar = Option("displayPowerBar", "toggle", SarychUI:T("ui.options_ae05bb46a5"), 4),
                        useClassColors = Option("useClassColors", "toggle", SarychUI:T("ui.options_c4202b8ff3"), 5),
                        displayHealPrediction = Option("displayHealPrediction", "toggle", SarychUI:T("ui.options_239f0da0ee"), 6),
                        displayAggroHighlight = Option("displayAggroHighlight", "toggle", SarychUI:T("ui.options_8c13c02ee0"), 7),
                        displayBorder = Option("displayBorder", "toggle", SarychUI:T("ui.options_2ef8429521"), 8),
                        horizontalGroups = Option("horizontalGroups", "toggle", SarychUI:T("ui.options_9edd165db2"), 9),
                        raidStyleParty = {
                            type = "toggle", name = "ui.text_4b15f9ab", order = 12,
                            get = function() return CUF_CVar and CUF_CVar:GetCVarBool("useCompactPartyFrames") end,
                            set = function(_, value)
                                module:SetRaidStylePartyFrames(value)
                            end,
                        },
                        quickControls = {
                            type = "toggle", name = "ui.text_1adeab51", order = 13,
                            get = function() return DB() and DB().showQuickControls ~= false end,
                            set = function(_, value)
                                local db = DB(); if not db then return end
                                db.showQuickControls = value
                                module:ApplyQuickControls()
                            end,
                        },
                    } },
                    units = { type = "group", name = "ui.text_265c5bf7", order = 2, args = {
                        keepGroupsTogether = Option("keepGroupsTogether", "toggle", SarychUI:T("ui.options_8767894725"), 1),
                        displayPets = Option("displayPets", "toggle", SarychUI:T("ui.options_471f9e4430"), 2),
                        displayMainTankAndAssist = Option("displayMainTankAndAssist", "toggle", SarychUI:T("ui.options_6fbf89a550"), 3),
                        displayNonBossDebuffs = Option("displayNonBossDebuffs", "toggle", SarychUI:T("ui.options_71cf01a4a6"), 4),
                        displayOnlyDispellableDebuffs = Option("displayOnlyDispellableDebuffs", "toggle", SarychUI:T("ui.options_2c4bb65ef2"), 5),
                        sortBy = Option("sortBy", "select", SarychUI:T("ui.options_f8eb0fd5b3"), 6,
                            { role = SarychUI:T("ui.options_2f3034e4e5"), group = SarychUI:T("ui.options_aedaf0b5c6"), alphabetical = SarychUI:T("ui.options_48b527cb15") }),
                        customSort = {
                            type = "select", name = "ui.text_3c93accc", order = 7,
                            values = { NONE = SarychUI:T("ui.options_8d81f9a069"), DESC = SarychUI:T("ui.options_aa6b22c2d4"), ASC = SarychUI:T("ui.options_fa1881309a"), HIDE = SarychUI:T("ui.common.hide"), MINIMAL_TOP = SarychUI:T("ui.group_frames.minimal_player_top") },
                            get = function() return DB() and DB().sortOrder or "NONE" end,
                            set = function(_, value) local db = DB(); if db then db.sortOrder = value; module:ApplySort() end end,
                        },
                    } },
                    presets = { type = "group", name = "ui.text_d9c756b1", order = 5, args = PresetControls() },
                },
            },
        },
    }
    -- Each area is a top-level SUI tab.
    local old = root.args.settings.args
    local enabledOption = old.enabled
    root.args = old
    root.args.enabled = nil
    local testButtons = {}
    for order, count in ipairs({ 2, 3, 5, 10, 25, 40 }) do
        local sampleCount = count
        testButtons["test" .. count] = {
            type = "execute", order = order, suiFitText = true,
            name = function()
                return module.testCount == sampleCount
                    and (sampleCount .. SarychUI:T("ui.options_86bab9d866"))
                    or tostring(sampleCount)
            end,
            func = function() module:ToggleTest(sampleCount) end,
        }
    end
    root.args.general = {
        type = "group", name = "ui.general_b250a3d6", order = 1,
        args = {
            test = { type = "group", name = "ui.test_mode_562448df", order = 1,
                inline = true, args = testButtons },
        },
    }
    local frameOpts = old.frames.args
    local unitOpts = old.units.args
    local presetOpts = old.presets.args
    local function Place(option, order, full)
        option.order = order
        option.suiFullRow = full and true or nil
        return option
    end
    presetOpts.selected.values = function()
        local values = PresetValues()
        values.__new = SarychUI:T("ui.options_68d6d535f1")
        return values
    end
    presetOpts.selected.get = function()
        local db = DB()
        return db and db.activePreset ~= "" and db.activePreset or "__new"
    end
    presetOpts.selected.set = function(_, value)
        if value == "__new" then
            CompactUnitFrameProfiles_NewProfileButtonClicked()
        else
            module:ApplyPreset(value)
        end
    end
    presetOpts.selected.name = SarychUI:T("ui.text_faaa59ea")
    presetOpts.save.disabled = function() return not module:IsPresetDirty() end
    presetOpts.save.name = SarychUI:T("ui.options_4864057d62")
    presetOpts.save.func = function()
        local db = DB()
        if db and db.activePreset and db.activePreset ~= "" then
            module:SavePreset(db.activePreset)
        else
            CompactUnitFrameProfiles_NewProfileButtonClicked()
        end
    end
    presetOpts.remove.name = SarychUI:T("ui.delete_be99b136")
    presetOpts.remove.confirm = true
    presetOpts.remove.confirmText = SarychUI:T("ui.options_768d3688c7")
    presetOpts.remove.disabled = function()
        local db = DB()
        return not db or not db.presets or not db.presets[db.activePreset]
    end
    unitOpts.horizontalGroups = frameOpts.horizontalGroups
    unitOpts.horizontalGroups.hidden = function()
        local profile = ActiveProfile()
        return not profile or not GetRaidProfileOption(profile, "keepGroupsTogether")
    end
    unitOpts.sortBy.hidden = function()
        local profile = ActiveProfile()
        return profile and GetRaidProfileOption(profile, "keepGroupsTogether")
    end
    unitOpts.displayOnlyDispellableDebuffs.hidden = function()
        local profile = ActiveProfile()
        return not profile or not GetRaidProfileOption(profile, "displayNonBossDebuffs")
    end
    local autoArgs = {}
    for order, size in ipairs({ 2, 3, 5, 10, 15, 25, 40 }) do
        autoArgs["size" .. size] = AutoFlagOption("autoActivate" .. size .. "Players", SarychUI:T("ui.options_f8c5b8ce30") .. size .. SarychUI:T("ui.options_c55f91575a"), order)
        if size <= 5 then
            autoArgs["size" .. size].disabled = function()
                return not CUF_CVar or not CUF_CVar:GetCVarBool("useCompactPartyFrames")
            end
        end
    end
    autoArgs.spec1 = AutoFlagOption("autoActivateSpec1", SarychUI:T("ui.options_ffff1c1b58"), 8)
    autoArgs.spec2 = AutoFlagOption("autoActivateSpec2", SarychUI:T("ui.options_1371b3e2de"), 9)
    autoArgs.pvp = AutoFlagOption("autoActivatePvP", SarychUI:T("ui.options_a715e4b300"), 10)
    autoArgs.pve = AutoFlagOption("autoActivatePvE", SarychUI:T("ui.options_2d0d68b573"), 11)
    local sizeOptions = {}
    for _, size in ipairs({ 2, 3, 5, 10, 15, 25, 40 }) do
        sizeOptions["size" .. size] = autoArgs["size" .. size]
    end
    autoArgs = {
        groups = { type = "group", name = "ui.text_5490b592", order = 1,
            inline = true, args = sizeOptions },
        talents = { type = "group", name = "ui.text_e8e60d86", order = 2,
            inline = true, args = { spec1 = autoArgs.spec1, spec2 = autoArgs.spec2 } },
        mode = { type = "group", name = "ui.mode_3f53fb87", order = 3,
            inline = true, args = { pvp = autoArgs.pvp, pve = autoArgs.pve } },
    }
    root.args.settings = {
        type = "group", name = "ui.settings_985b5e0f", order = 2,
        suiGroupFramesSettings = true,
        args = {
            mainBlock = { type = "group", name = "ui.text_a45747bf", order = 1,
                inline = true, suiTwoCol = true,
                args = {
                    raidStyleParty = Place(frameOpts.raidStyleParty, 1, true),
                    selected = Place(presetOpts.selected, 2, true),
                    save = Place(presetOpts.save, 3),
                    remove = Place(presetOpts.remove, 4),
                    keepGroupsTogether = Place(unitOpts.keepGroupsTogether, 5, true),
                    sortBy = Place(unitOpts.sortBy, 6, true),
                    customSort = Place(unitOpts.customSort, 7, true),
                    horizontalGroups = Place(unitOpts.horizontalGroups, 8, true),
                    displayHealPrediction = Place(frameOpts.displayHealPrediction, 9, true),
                    displayPowerBar = Place(frameOpts.displayPowerBar, 10, true),
                    displayAggroHighlight = Place(frameOpts.displayAggroHighlight, 11, true),
                    useClassColors = Place(frameOpts.useClassColors, 12, true),
                    muteFullHealth = {
                        type = "toggle", name = "ui.group_frames.full_health_muted", order = 12.1,
                        desc = "ui.group_frames.full_health_muted_desc",
                        get = function() return DB() and DB().muteFullHealth == true end,
                        set = function(_, value)
                            if not DB() then return end
                            DB().muteFullHealth = value
                            module:RefreshRange()
                            if module.RefreshTest then module:RefreshTest() end
                        end,
                    },
                    displayPets = Place(unitOpts.displayPets, 13, true),
                    displayMainTankAndAssist = Place(unitOpts.displayMainTankAndAssist, 14, true),
                    displayBorder = Place(frameOpts.displayBorder, 15, true),
                    displayNonBossDebuffs = Place(unitOpts.displayNonBossDebuffs, 16, true),
                    displayOnlyDispellableDebuffs = Place(unitOpts.displayOnlyDispellableDebuffs, 17, true),
                    dispelExceptions = {
                        type = "execute", name = "ui.options_ea65534c79", order = 17.1, suiFitText = true,
                        desc = "ui.group_frames.dispel_exceptions_desc",
                        hidden = function()
                            local profile = ActiveProfile()
                            return not profile or not GetRaidProfileOption(profile, "displayNonBossDebuffs")
                                or not GetRaidProfileOption(profile, "displayOnlyDispellableDebuffs")
                        end,
                        func = function() SarychUI.modules.auras:OpenConsolidationExceptions("groupDispelExceptions") end,
                    },
                    healthText = Place(frameOpts.healthText, 18, true),
                    frameHeight = Place(frameOpts.frameHeight, 19),
                    frameWidth = Place(frameOpts.frameWidth, 20),
                    nameFontSizeEnabled = {
                        type = "toggle", name = "ui.group_frames.name_font_enabled", order = 20.1,
                        desc = "ui.group_frames.name_font_enabled_desc", suiFullRow = true,
                        get = function() return DB() and DB().nameFontSizeEnabled == true end,
                        set = function(_, value)
                            if not DB() then return end
                            DB().nameFontSizeEnabled = value and true or false
                            module:SaveNameTextSettings()
                            module:RefreshNameTexts()
                            module:RefreshPresetButtons()
                        end,
                    },
                    nameFontSize = {
                        type = "range", name = "ui.group_frames.name_font_size", order = 20.2,
                        min = 6, max = 24, step = 1,
                        hidden = function() return not DB() or not DB().nameFontSizeEnabled end,
                        get = function() return module:GetNameFontSize() end,
                        set = function(_, value)
                            if not DB() then return end
                            DB().nameFontSize = value
                            module:SaveNameTextSettings()
                            module:RefreshNameTexts()
                            module:RefreshPresetButtons()
                        end,
                    },
                    resetSizes = {
                        type = "execute", name = "ui.options_469631cb16", order = 20.3,
                        suiTrailingFit = true,
                        hidden = function() return not DB() or not DB().nameFontSizeEnabled end,
                        func = function()
                            local db = DB()
                            if not db then return end
                            db.nameFontSize = 10
                            module:SaveNameTextSettings()
                            module:RefreshNameTexts()
                            module:RefreshPresetButtons()
                        end,
                    },
                    quickControls = Place(frameOpts.quickControls, 21, true),
                } },
            autoBlock = { type = "group", name = "ui.text_e159ce7c", order = 2,
                inline = true, args = autoArgs },
            resetPosition = { type = "execute", name = "ui.text_08460f9f", order = 3,
                func = function()
                    if InCombatLockdown() then return end
                    CompactRaidFrameManager_ResetContainerPosition()
                end },
        },
    }
    root.args.settings.args.auraBlacklist = {
        type = "group", name = SarychUI:T("ui.visibility.blacklist"), inline = true, order = 4,
        args = {
            enabled = {type = "toggle", name = SarychUI:T("ui.enable_a54eaf37"), order = 1,
                get = function() return DB().auraBlacklistEnabled == true end,
                set = function(_, value)
                    DB().auraBlacklistEnabled = value and true or false
                    module:ApplyAuraBlacklist()
                    local auras = SarychUI.modules.auras
                    if auras and auras.consolidationExceptionsWindow then auras.consolidationExceptionsWindow:Hide() end
                    SarychUI:NotifySarychUIOptionsChange()
                end},
            buffs = {type = "execute", name = SarychUI:T("ui.auras.buffs"), order = 2,
                hidden = function() return not DB().auraBlacklistEnabled end,
                func = function() SarychUI.modules.auras:OpenConsolidationExceptions("groupBuffBlacklist") end},
            debuffs = {type = "execute", name = SarychUI:T("ui.auras.debuffs"), order = 3,
                hidden = function() return not DB().auraBlacklistEnabled end,
                func = function() SarychUI.modules.auras:OpenConsolidationExceptions("groupDebuffBlacklist") end},
        },
    }
    root.args.frames = nil
    root.args.units = nil
    root.args.presets = nil
    local tracker = SarychUI.extensions and SarychUI.extensions.party_abilities
    if tracker and tracker.GetOptions then
        local general, position = tracker:GetOptions(true)
        general.inline, general.order = true, 3.5
        general.name = SarychUI:T("ui.options_077ad54da2")
        root.args.settings.args.cooldowns = general
        position.order = 3
        position.name = SarychUI:T("ui.options_1db4cbac2e")
        position.hidden = function() return tracker:GetDB().enabled == false end
        position.args.preview = nil
        position.args.activeStyle = {
            type = "description", order = 0, width = "full",
            name = function()
                local kind = tracker:GetLayoutKind()
                return SarychUI:T("ui.options_ffed32b809")
                    .. (kind == "compact" and SarychUI:T("ui.options_d5b8baf712") or SarychUI:T("ui.options_97669bb5d5")) .. "|r"
            end,
        }
        position.args.display = general.args.display
        position.args.display.order = 1
        position.args.where = general.args.where
        position.args.where.order = 2
        position.args.showPlayer = general.args.showPlayer
        position.args.showPlayer.order = 3
        position.args.controls.order = 10
        position.args.cooldownEdge.order = 11
        general.args.display, general.args.where, general.args.showPlayer = nil, nil, nil
        position.args.spells = {
            type = "execute", name = "ui.text_4489c485", order = 99, width = "full",
            func = function()
                local core = SarychUI.OptionsCore
                if not core then return end
                local section = core._sections and core._sections["sui:extensions"]
                if not section or not section.path then return end
                local pathKey = table.concat(section.path, "/")
                core._twoPaneSelected = core._twoPaneSelected or {}
                core._twoPaneSelected[pathKey] = "party_abilities"
                core._twoPaneDetailScroll = core._twoPaneDetailScroll or {}
                core._twoPaneDetailScroll[pathKey] = 0
                core._addonListTabState = core._addonListTabState or {}
                core._addonListTabState.party_abilities = "spells"
                core:SelectSection("sui:extensions")
                core:Refresh()
            end,
        }
        root.args.allyAbilities = position
    end
    root.args.general.args.enabled = enabledOption
    local function CastbarToggle(key, name, order, child)
        return {type = "toggle", name = name, order = order, width = "full", suiFullRow = true,
            hidden = child and function() return not DB().castbarEnabled end or nil,
            get = function() return DB()[key] == true end,
            set = function(_, value)
                DB()[key] = value and true or false
                module:ApplyHeaderCastbars()
                SarychUI:NotifySarychUIOptionsChange()
            end}
    end
    root.args.settings.args.castbars = {
        type = "group", name = SarychUI:T("ui.cast_bar_f9f01465"), inline = true, order = 5, suiTwoCol = true,
        args = {
            enabled = CastbarToggle("castbarEnabled", SarychUI:T("ui.enable_a54eaf37"), 1),
            hidePlayer = CastbarToggle("castbarHidePlayer", SarychUI:T("ui.group_castbar.hide_player"), 2, true),
        },
    }
    root.args.general.args.direMaulArt = {
        type = "description", name = "", order = 99, width = "full",
        image = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-DireMaul.blp",
        imageWidth = 256, imageHeight = 128,
        suiFadedImage = true, suiImageCorner = "TOPRIGHT",
    }
    return root
end
