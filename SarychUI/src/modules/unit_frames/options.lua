-- SarychUI Frame Module Options
-- Options UI for frame positioning, text and visuals

local moduleName = "frame"
local L = SarychUI.L

-- Get module
local module = SarychUI:GetModule(moduleName)
if not module then return end

-- Early exit if AceConfig not available
if not LibStub or not LibStub("AceConfig-3.0", true) then
    return
end

local function isEnabled()
    return SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName] and SarychUI.db.profile.modules[moduleName].enabled
end

local function FrameDB()
    return SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
end

local function isOn(key)
    local db = FrameDB()
    if not db then return false end
    local v = db[key]
    return v == 1 or v == true
end

local function RefreshConfig()
    if SarychUI and SarychUI.NotifySarychUIOptionsChange then
        SarychUI:NotifySarychUIOptionsChange()
    elseif SarychUI and SarychUI.RefreshConfig then
        SarychUI:RefreshConfig()
    end
end

local function ApplyFrameSettings()
    local db = FrameDB()
    if db and db.classIconEnabled == 1 and db.classIconStyle == "replace" then
        db.hideFrameLevel = 0
    end
    if SarychUI.ApplyLiveModule then
        SarychUI.ApplyLiveModule(module)
        return
    end
    if module.ApplySettings then
        module:ApplySettings()
    end
end

-- Read Blizzard CVars directly: there is no second copy in the profile.
local statusTextCVars = {
    playerStatusText = "STATUS_TEXT_PLAYER",
    petStatusText = "STATUS_TEXT_PET",
    partyStatusText = "STATUS_TEXT_PARTY",
    targetStatusText = "STATUS_TEXT_TARGET",
    statusTextPercentage = "STATUS_TEXT_PERCENT",
}
local statusTextEvents = {}
for cvar, event in pairs(statusTextCVars) do
    statusTextEvents[string.lower(cvar)] = true
    statusTextEvents[string.lower(event)] = true
end
local statusTextWatcher = CreateFrame("Frame")
statusTextWatcher:RegisterEvent("CVAR_UPDATE")
statusTextWatcher:SetScript("OnEvent", function(_, _, name)
    if statusTextEvents[string.lower(tostring(name))] then
        RefreshConfig()
    end
end)
-- SetCVar without its optional event argument is also used by other addons.
hooksecurefunc("SetCVar", function(name)
    if statusTextEvents[string.lower(tostring(name))] then
        RefreshConfig()
    end
end)

local function StatusTextOption(cvar, name, order)
    return {
        type = "toggle", name = name, order = order,
        get = function() return GetCVar(cvar) == "1" end,
        set = function(_, value)
            SetCVar(cvar, value and "1" or "0", statusTextCVars[cvar])
        end,
    }
end

local function IsUnitFrameLayersEnabled()
    return SarychUI.UnitFrameLayers and SarychUI.UnitFrameLayers:IsEnabled()
end

local function UnitFrameLayersDB()
    return SarychUI.UnitFrameLayers and SarychUI.UnitFrameLayers:Settings()
end

local function FrameForUnit(unit)
    if unit == "player" then return PlayerFrame end
    if unit == "target" then return TargetFrame end
    if unit == "focus" then return FocusFrame end
    local n = type(unit) == "string" and unit:match("^party(%d+)$")
    if n then return _G["PartyMemberFrame" .. n] end
    return _G[unit .. "Frame"]
end

local function RefreshUnitFrameLayersHealthColors()
    if type(UpdateHealthBarColor) ~= "function" then return end
    local units = { "player", "target", "focus", "party1", "party2", "party3", "party4" }
    for i = 1, #units do
        local unit = units[i]
        local frame = FrameForUnit(unit)
        if frame then
            frame.unit = frame.unit or unit
            if not frame.healthbar then
                local name = frame.GetName and frame:GetName()
                frame.healthbar = name and _G[name .. "HealthBar"] or nil
            end
            -- Только перекраска: UnitFrameHealthBar_Update после неё снова ставит зелёный.
            UpdateHealthBarColor(frame)
        end
    end
    -- Прямой проход по известным барам (на случай рассинхрона frame.healthbar)
    local bars = {
        { PlayerFrame, PlayerFrameHealthBar, "player" },
        { TargetFrame, TargetFrameHealthBar, "target" },
        { FocusFrame, FocusFrameHealthBar, "focus" },
    }
    for i = 1, #bars do
        local frame, bar, unit = bars[i][1], bars[i][2], bars[i][3]
        if frame and bar then
            frame.healthbar = bar
            frame.unit = frame.unit or unit
            UpdateHealthBarColor(frame)
        end
    end
    local preview = SarychUI.FramePvpPreview
    if preview and preview.SetLiveValue then
        local db = UnitFrameLayersDB()
        if db then
            preview:SetLiveValue("classColorHP", db.classColorHP ~= false)
            preview:SetLiveValue("playerClassColorHP", db.playerClassColorHP == true)
        else
            preview:RefreshAll()
        end
    elseif preview and preview.RefreshAll then
        preview:RefreshAll()
    end
end

local function ApplyPositionDrag()
    if module.ApplyPositionDragMode then
        module:ApplyPositionDragMode()
    end
end

local function ToggleFrameDrag(frameId, enabled)
    local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
    if panel and panel.Toggle then
        panel:Toggle(frameId, enabled)
        return
    end
    ApplyPositionDrag()
end

local function FrameDefault(key, fallback)
	local d = SarychUI.defaults and SarychUI.defaults.profile.modules.frame
	if d and d[key] ~= nil then
		return d[key]
	end
	return fallback
end

-- Move only this unit frame — other "По умолчанию" buttons stay put.
local function ApplyOneFramePos(frame, frameId, x, y)
	if not frame or (InCombatLockdown and InCombatLockdown()) then
		return
	end
	if SarychUI.DragMode then
		local data = SarychUI.DragMode:GetFrameData(frameId)
		if data then
			data.justDragged = false
			data.isMoving = false
		end
	end
	if SarychUI.DragMode and SarychUI.DragMode.SetFramePosition then
		SarychUI.DragMode:SetFramePosition(frameId, "CENTER", "CENTER", x, y)
		return
	end
	local data = SarychUI.DragMode and SarychUI.DragMode:GetFrameData(frameId)
	local setPoint = (data and data.originalSetPoint) or frame.SetPoint
	frame:ClearAllPoints()
	setPoint(frame, "CENTER", UIParent, "CENTER", x, y)
end

local function ResetFramePos(xKey, yKey, xFallback, yFallback, frameId, frame)
	local db = FrameDB()
	if not db then return end
	local x = FrameDefault(xKey, xFallback)
	local y = FrameDefault(yKey, yFallback)
	db[xKey] = x
	db[yKey] = y
	local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
	if not (panel and panel.SyncDraftIfOpen and panel:SyncDraftIfOpen(frameId, x, y)) then
		ApplyOneFramePos(frame or _G[frameId], frameId, x, y)
	end
	if SarychUI.SyncOpenOptionsValues then
		SarychUI:SyncOpenOptionsValues()
	else
		RefreshConfig()
	end
end

local function NotifyCombatPreview(key, value)
    local preview = SarychUI and SarychUI.CombatIndicatorPreview
    if not preview then return end
    if key ~= nil and preview.SetLiveValue then
        preview:SetLiveValue(key, value)
    elseif preview.RefreshAll then
        preview:RefreshAll()
    end
end

local function OnCombatSetting(key, value)
    -- During slider drag the preview already tracks via SetLiveValue/LayoutLive.
    if SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging() then
        return
    end
    local preview = SarychUI and SarychUI.CombatIndicatorPreview
    if preview then
        if preview.ClearLiveValue then
            preview:ClearLiveValue(key)
        end
        if preview.SetActiveKey then
            preview:SetActiveKey(key)
        end
        if preview.RefreshAll then
            preview:RefreshAll()
        end
    end
end

function module:GetOptions()
    return {
        type = "group",
        name = L and (L["Frames"] or SarychUI:T("ui.frames_ce7f103c")) or SarychUI:T("ui.frames_ce7f103c"),
        desc = L and (L["Frames_Description"] or SarychUI:T("ui.options_c2c2b2642f")) or SarychUI:T("ui.options_c2c2b2642f"),
        childGroups = "tab",
        args = {
            -- General tab
            general = {
                type = "group",
                name = L and (L["General"] or SarychUI:T("ui.general_b250a3d6")) or SarychUI:T("ui.general_b250a3d6"),
                order = 1,
                args = {
                    header = {
                        type = "header",
                        name = L and (L["Frames"] or SarychUI:T("ui.frames_ce7f103c")) or SarychUI:T("ui.frames_ce7f103c"),
                        order = 1,
                    },
                    enabled = {
                        suiModuleEnable = true,
                        type = "toggle",
                        name = L and (L["Enable_Module"] or SarychUI:T("ui.enable_module_b623b573")) or SarychUI:T("ui.enable_module_b623b573"),
                        desc = "ui.enable_or_disable_the_module_ce99024f",
                        order = 2,
                        width = "full",
                        get = function()
                            return SarychUI.db.profile.modules[moduleName].enabled
                        end,
                        set = function(info, value)
                            SarychUI.db.profile.modules[moduleName].enabled = value
                            if value then
                                SarychUI:EnableModule(moduleName)
                            else
                                SarychUI:DisableModule(moduleName)
                            end
                        end,
                    },
                },
            },

            -- Position & scale tab
            move = {
                type = "group",
                name = "ui.positions_and_scale_14cee8fd",
                order = 2,
                disabled = function() return not isEnabled() end,
                childGroups = "tab",
                args = {
                  frames = {
                    type = "group",
                    name = "ui.frames_ce7f103c",
                    order = 1,
                    args = {
                    positionEnableBox = {
                        type = "group",
                        name = "ui.change_frame_layout_15df02f4",
                        order = 1,
                        inline = true,
                        args = {
                            change_positions = {
                                type = "toggle",
                                name = "ui.enable_a54eaf37",
                                desc = "ui.allow_repositioning_player_target_and_focus_fram_b20d754f",
                                order = 1,
                                width = "full",
                                get = function() return isOn("changePositions") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    db.changePositions = value and 1 or 0
                                    if not value then
                                        db.showPositionDragFrame = 0
                                        db.showPositionGrid = 0
                                        db.showPlayerDragFrame = 0
                                        db.showTargetDragFrame = 0
                                        db.showFocusDragFrame = 0
                                        local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
                                        if panel and panel.IsOpen and panel:IsOpen()
                                            and (not panel.GetFrameId or panel:GetFrameId() ~= "petFrame") then
                                            panel:Close(false)
                                        end
                                    end
                                    ApplyFrameSettings()
                                    ApplyPositionDrag()
                                    RefreshConfig()
                                end,
                            },
                        },
                    },

                    playerBox = {
                        type = "group",
                        name = "ui.player_f54f58cf",
                        order = 2,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("changePositions") end,
                        args = {
                            player_x = {
                                type = "range",
                                name = "ui.x_offset_0b923c73",
                                desc = "ui.player_frame_horizontal_offset_3f787562",
                                min = -2000, max = 2000, step = 1,
                                order = 1,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.playerFrameX or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.playerFrameX = val
                                    ApplyFrameSettings()
                                end,
                            },
                            player_y = {
                                type = "range",
                                name = "ui.y_offset_f7f3fdd7",
                                desc = "ui.player_frame_vertical_offset_3b0c8bb6",
                                min = -2000, max = 2000, step = 1,
                                order = 2,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.playerFrameY or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.playerFrameY = val
                                    ApplyFrameSettings()
                                end,
                            },
                            playerDrag = {
                                type = "execute",
                                name = function()
                                    if isOn("showPlayerDragFrame") then
                                        return SarychUI:T("ui.options_76e4992833")
                                    end
                                    return SarychUI:T("ui.options_0510004a87")
                                end,
                                desc = "ui.show_a_frame_and_box_to_drag_the_player_frame_273d79c4",
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                func = function()
                                    local db = FrameDB(); if not db then return end
                                    local val = not (db.showPlayerDragFrame == 1)
                                    db.showPlayerDragFrame = val and 1 or 0
                                    if val then
                                        db.showTargetDragFrame = 0
                                        db.showFocusDragFrame = 0
                                    end
                                    ToggleFrameDrag("playerFrame", val)
                                    RefreshConfig()
                                end,
                                suiResetDefaults = function()
                                    ResetFramePos("playerFrameX", "playerFrameY", -514, 200, "playerFrame", PlayerFrame)
                                end,
                            },
                        },
                    },

                    targetBox = {
                        type = "group",
                        name = "ui.target_1d6ae787",
                        order = 3,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("changePositions") end,
                        args = {
                            target_x = {
                                type = "range",
                                name = "ui.x_offset_0b923c73",
                                desc = "ui.target_frame_horizontal_offset_b338c1be",
                                min = -2000, max = 2000, step = 1,
                                order = 1,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.targetFrameX or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.targetFrameX = val
                                    ApplyFrameSettings()
                                end,
                            },
                            target_y = {
                                type = "range",
                                name = "ui.y_offset_f7f3fdd7",
                                desc = "ui.target_frame_vertical_offset_49088333",
                                min = -2000, max = 2000, step = 1,
                                order = 2,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.targetFrameY or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.targetFrameY = val
                                    ApplyFrameSettings()
                                end,
                            },
                            targetDrag = {
                                type = "execute",
                                name = function()
                                    if isOn("showTargetDragFrame") then
                                        return SarychUI:T("ui.options_76e4992833")
                                    end
                                    return SarychUI:T("ui.options_0510004a87")
                                end,
                                desc = "ui.show_a_frame_and_box_to_drag_the_target_frame_cc579683",
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                func = function()
                                    local db = FrameDB(); if not db then return end
                                    local val = not (db.showTargetDragFrame == 1)
                                    db.showTargetDragFrame = val and 1 or 0
                                    if val then
                                        db.showPlayerDragFrame = 0
                                        db.showFocusDragFrame = 0
                                    end
                                    ToggleFrameDrag("targetFrame", val)
                                    RefreshConfig()
                                end,
                                suiResetDefaults = function()
                                    ResetFramePos("targetFrameX", "targetFrameY", -240, 200, "targetFrame", TargetFrame)
                                end,
                            },
                        },
                    },

                    focusBox = {
                        type = "group",
                        name = "ui.focus_1913a1d2",
                        order = 4,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("changePositions") end,
                        args = {
                            focus_x = {
                                type = "range",
                                name = "ui.x_offset_0b923c73",
                                desc = "ui.focus_frame_horizontal_offset_e352e819",
                                min = -2000, max = 2000, step = 1,
                                order = 1,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.focusFrameX or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.focusFrameX = val
                                    ApplyFrameSettings()
                                end,
                            },
                            focus_y = {
                                type = "range",
                                name = "ui.y_offset_f7f3fdd7",
                                desc = "ui.focus_frame_vertical_offset_28c9aa48",
                                min = -2000, max = 2000, step = 1,
                                order = 2,
                                get = function()
                                    local db = FrameDB()
                                    return db and db.focusFrameY or 0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.focusFrameY = val
                                    ApplyFrameSettings()
                                end,
                            },
                            focusDrag = {
                                type = "execute",
                                name = function()
                                    if isOn("showFocusDragFrame") then
                                        return SarychUI:T("ui.options_76e4992833")
                                    end
                                    return SarychUI:T("ui.options_0510004a87")
                                end,
                                desc = "ui.show_a_frame_and_box_to_drag_the_focus_frame_85480b1a",
                                order = 3,
                                width = "full",
                                suiFullRow = true,
                                func = function()
                                    local db = FrameDB(); if not db then return end
                                    local val = not (db.showFocusDragFrame == 1)
                                    db.showFocusDragFrame = val and 1 or 0
                                    if val then
                                        db.showPlayerDragFrame = 0
                                        db.showTargetDragFrame = 0
                                    end
                                    ToggleFrameDrag("focusFrame", val)
                                    RefreshConfig()
                                end,
                                suiResetDefaults = function()
                                    ResetFramePos("focusFrameX", "focusFrameY", 350, -150, "focusFrame", FocusFrame)
                                end,
                            },
                        },
                    },

                    scaleBox = {
                        type = "group",
                        name = "ui.frame_scale_6bfd4954",
                        order = 5,
                        inline = true,
                        args = {
                            change_scale = {
                                type = "toggle",
                                name = "ui.enable_a54eaf37",
                                desc = "ui.text_971aaa97",
                                order = 1,
                                width = "full",
                                get = function() return isOn("changeScale") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    if value then
                                        db.frameScale = db.previousFrameScale or 1.0
                                    else
                                        db.previousFrameScale = db.frameScale or 1.0
                                    end
                                    db.changeScale = value and 1 or 0
                                    ApplyFrameSettings()
                                    RefreshConfig()
                                end,
                            },
                            playerFrameScale = {
                                type = "range",
                                name = "ui.player_f54f58cf",
                                desc = "ui.text_11383b2e",
                                min = 0.5, max = 2.0, step = 0.05,
                                order = 2,
                                width = "full",
                                get = function()
                                    local db = FrameDB()
                                    return db and (db.playerFrameScale or db.frameScale) or 1.0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.playerFrameScale = val
                                    ApplyFrameSettings()
                                end,
                                hidden = function() return not isOn("changeScale") end,
                            },
                            targetFrameScale = {
                                type = "range",
                                name = "ui.target_1d6ae787",
                                desc = "ui.text_9a67d135",
                                min = 0.5, max = 2.0, step = 0.05,
                                order = 3,
                                width = "full",
                                get = function()
                                    local db = FrameDB()
                                    return db and (db.targetFrameScale or db.frameScale) or 1.0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.targetFrameScale = val
                                    ApplyFrameSettings()
                                end,
                                hidden = function() return not isOn("changeScale") end,
                            },
                            focusFrameScale = {
                                type = "range",
                                name = "ui.focus_1913a1d2",
                                desc = "ui.text_6ec5daf7",
                                min = 0.5, max = 2.0, step = 0.05,
                                order = 4,
                                width = "full",
                                get = function()
                                    local db = FrameDB()
                                    return db and (db.focusFrameScale or db.frameScale) or 1.0
                                end,
                                set = function(_, val)
                                    local db = FrameDB(); if not db then return end
                                    db.focusFrameScale = val
                                    ApplyFrameSettings()
                                end,
                                hidden = function() return not isOn("changeScale") end,
                            }
                        },
                    },
                    },
                  },
                  pets = {
                    type = "group",
                    name = "ui.pets_61161ec5",
                    order = 2,
                    args = {
                      petPositionEnableBox = {
                        type = "group",
                        name = "ui.change_frame_layout_15df02f4",
                        order = 1,
                        inline = true,
                        args = {
                          change_pet_position = {
                            type = "toggle",
                            name = "ui.enable_a54eaf37",
                            desc = "ui.text_d299e722",
                            order = 1,
                            width = "full",
                            get = function() return isOn("changePetPosition") end,
                            set = function(_, value)
                              local db = FrameDB(); if not db then return end
                              if value and module.InitializePetPosition then
                                module:InitializePetPosition()
                              end
                              db.changePetPosition = value and 1 or 0
                              if not value then
                                db.showPetDragFrame = 0
                                local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
                                if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId and panel:GetFrameId() == "petFrame" then
                                  panel:Close(false)
                                end
                              end
                              ApplyFrameSettings()
                              RefreshConfig()
                            end,
                          },
                        },
                      },
                      petBox = {
                        type = "group",
                        name = "ui.pet_31cd9c45",
                        order = 2,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("changePetPosition") end,
                        args = {
                          pet_x = {
                            type = "range",
                            name = "ui.x_offset_0b923c73",
                            desc = "ui.text_2efabbc4",
                            min = -2000, max = 2000, step = 1,
                            order = 1,
                            get = function()
                              local db = FrameDB()
                              return db and db.petFrameX or 0
                            end,
                            set = function(_, val)
                              local db = FrameDB(); if not db then return end
                              db.petFrameX = val
                              ApplyFrameSettings()
                            end,
                          },
                          pet_y = {
                            type = "range",
                            name = "ui.y_offset_f7f3fdd7",
                            desc = "ui.text_e22a12d7",
                            min = -2000, max = 2000, step = 1,
                            order = 2,
                            get = function()
                              local db = FrameDB()
                              return db and db.petFrameY or 0
                            end,
                            set = function(_, val)
                              local db = FrameDB(); if not db then return end
                              db.petFrameY = val
                              ApplyFrameSettings()
                            end,
                          },
                          petDrag = {
                            type = "execute",
                            name = function()
                              if isOn("showPetDragFrame") then
                                return SarychUI:T("ui.options_76e4992833")
                              end
                              return SarychUI:T("ui.options_0510004a87")
                            end,
                            desc = "ui.text_9970f435",
                            order = 3,
                            width = "full",
                            suiFullRow = true,
                            func = function()
                              local db = FrameDB(); if not db then return end
                              local val = not isOn("showPetDragFrame")
                              db.showPetDragFrame = val and 1 or 0
                              if val then
                                db.showPlayerDragFrame = 0
                                db.showTargetDragFrame = 0
                                db.showFocusDragFrame = 0
                              end
                              ToggleFrameDrag("petFrame", val)
                              RefreshConfig()
                            end,
                            suiResetDefaults = function()
                              local db = FrameDB()
                              ResetFramePos("petFrameX", "petFrameY",
                                db and db.petFrameDefaultX or -514,
                                db and db.petFrameDefaultY or 100,
                                "petFrame", PetFrame)
                            end,
                          },
                        },
                      },
                      petScaleBox = {
                        type = "group",
                        name = "ui.frame_scale_6bfd4954",
                        order = 3,
                        inline = true,
                        args = {
                          change_pet_scale = {
                            type = "toggle",
                            name = "ui.enable_a54eaf37",
                            desc = "ui.text_82a8a795",
                            order = 1,
                            width = "full",
                            get = function() return isOn("changePetScale") end,
                            set = function(_, value)
                              local db = FrameDB(); if not db then return end
                              db.changePetScale = value and 1 or 0
                              ApplyFrameSettings()
                              RefreshConfig()
                            end,
                          },
                          petFrameScale = {
                            type = "range",
                            name = "ui.pet_31cd9c45",
                            desc = "ui.text_de7831eb",
                            min = 0.5, max = 2.0, step = 0.05,
                            order = 2,
                            width = "full",
                            get = function()
                              local db = FrameDB()
                              return db and db.petFrameScale or 1.0
                            end,
                            set = function(_, val)
                              local db = FrameDB(); if not db then return end
                              db.petFrameScale = val
                              ApplyFrameSettings()
                            end,
                            hidden = function() return not isOn("changePetScale") end,
                          },
                        },
                      },
                    },
                  },
                },
            },

            -- Combat Indicator tab
            combat = {
                type = "group",
                name = "ui.combat_indicator_302a8b8d",
                order = 3,
                disabled = function() return not isEnabled() end,
                args = {
                    preview = {
                        type = "description",
                        name = "",
                        order = 0,
                        width = "full",
                        suiPreview = "CombatIndicatorPreview",
                    },
                    enableBox = {
                        type = "group",
                        name = "ui.combat_indicator_settings_2df3007e",
                        order = 1,
                        inline = true,
                        args = {
                            enable_combat_indicator = {
                                type = "toggle",
                                name = "ui.tinterface_characterframe_ui_stateicon_22_22_0_0_39d775be",
                                desc = "ui.show_the_combat_indicator_on_player_target_and_f_efc174e8",
                                order = 1,
                                width = "full",
                                get = function() return isOn("enableCombatIndicator") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    db.enableCombatIndicator = value and 1 or 0
                                    ApplyFrameSettings()
                                    NotifyCombatPreview("enableCombatIndicator", value and 1 or 0)
                                    RefreshConfig()
                                end,
                            },
                            combat_scale = {
                                type = "range",
                                name = "ui.scale_e037e967",
                                desc = "ui.combat_indicator_scale_0_3_30_1_0_100_2_0_200_69def275",
                                min = 0.3, max = 2.0, step = 0.05,
                                order = 2,
                                width = "full",
                                suiPreviewKey = "combatIndicatorScale",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorScale or 0.85
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorScale = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorScale", v)
                                end,
                                hidden = function() return not isOn("enableCombatIndicator") end,
                            },
                        },
                    },
                    playerBox = {
                        type = "group",
                        name = "ui.player_f54f58cf",
                        order = 2,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("enableCombatIndicator") end,
                        args = {
                            combat_player_resting = {
                                type = "select",
                                name = "ui.combat.safe_zone",
                                order = 0,
                                width = "full",
                                suiFullRow = true,
                                values = {
                                    respect = SarychUI:T("ui.combat.respect_safe_zone"),
                                    ignore = SarychUI:T("ui.combat.ignore_safe_zone"),
                                    __order = { "respect", "ignore" },
                                },
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorPlayerRespectResting == 0 and "ignore" or "respect"
                                end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorPlayerRespectResting = value == "ignore" and 0 or 1
                                    ApplyFrameSettings()
                                    RefreshConfig()
                                end,
                            },
                            combat_player_x = {
                                type = "range",
                                name = "ui.x_offset_0b923c73",
                                desc = "ui.player_combat_indicator_horizontal_offset_b8b4902e",
                                min = -500, max = 500, step = 1,
                                order = 1,
                                suiPreviewKey = "combatIndicatorPlayerX",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorPlayerX or 33
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorPlayerX = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorPlayerX", v)
                                end,
                            },
                            combat_player_y = {
                                type = "range",
                                name = "ui.y_offset_f7f3fdd7",
                                desc = "ui.player_combat_indicator_vertical_offset_f6498e5b",
                                min = -500, max = 500, step = 1,
                                order = 2,
                                suiPreviewKey = "combatIndicatorPlayerY",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorPlayerY or 38
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorPlayerY = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorPlayerY", v)
                                end,
                            },
                        },
                    },
                    targetBox = {
                        type = "group",
                        name = "ui.target_1d6ae787",
                        order = 3,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("enableCombatIndicator") end,
                        args = {
                            combat_target_x = {
                                type = "range",
                                name = "ui.x_offset_0b923c73",
                                desc = "ui.target_combat_indicator_horizontal_offset_4f3c79b8",
                                min = -500, max = 500, step = 1,
                                order = 1,
                                suiPreviewKey = "combatIndicatorTargetX",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorTargetX or 57
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorTargetX = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorTargetX", v)
                                end,
                            },
                            combat_target_y = {
                                type = "range",
                                name = "ui.y_offset_f7f3fdd7",
                                desc = "ui.target_combat_indicator_vertical_offset_f3e679de",
                                min = -500, max = 500, step = 1,
                                order = 2,
                                suiPreviewKey = "combatIndicatorTargetY",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorTargetY or 0
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorTargetY = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorTargetY", v)
                                end,
                            },
                        },
                    },
                    focusBox = {
                        type = "group",
                        name = "ui.focus_1913a1d2",
                        order = 4,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("enableCombatIndicator") end,
                        args = {
                            combat_focus_x = {
                                type = "range",
                                name = "ui.x_offset_0b923c73",
                                desc = "ui.focus_combat_indicator_horizontal_offset_725ca9be",
                                min = -500, max = 500, step = 1,
                                order = 1,
                                suiPreviewKey = "combatIndicatorFocusX",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorFocusX or 57
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorFocusX = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorFocusX", v)
                                end,
                            },
                            combat_focus_y = {
                                type = "range",
                                name = "ui.y_offset_f7f3fdd7",
                                desc = "ui.focus_combat_indicator_vertical_offset_4e683b56",
                                min = -500, max = 500, step = 1,
                                order = 2,
                                suiPreviewKey = "combatIndicatorFocusY",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorFocusY or 0
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorFocusY = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorFocusY", v)
                                end,
                            },
                        },
                    },
                    specialBox = {
                        type = "group",
                        name = "ui.special_case_offsets_6580e057",
                        order = 5,
                        inline = true,
                        suiTwoCol = true,
                        hidden = function() return not isOn("enableCombatIndicator") end,
                        args = {
                            combat_elite_offset = {
                                type = "range",
                                name = "ui.elite_mob_offset_a1e8986d",
                                desc = "ui.extra_indicator_offset_for_elite_rare_and_boss_u_1aa497f3",
                                min = 0, max = 100, step = 1,
                                order = 1,
                                suiPreviewKey = "combatIndicatorEliteOffset",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorEliteOffset or 30
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorEliteOffset = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorEliteOffset", v)
                                end,
                            },
                            combat_rogue_offset = {
                                type = "range",
                                name = "ui.rogue_offset_acc825a0",
                                desc = "ui.extra_indicator_offset_for_rogue_vs_normal_mobs__8f6def7f",
                                min = 0, max = 50, step = 1,
                                order = 2,
                                suiPreviewKey = "combatIndicatorRogueOffset",
                                get = function()
                                    local db = FrameDB()
                                    return db and db.combatIndicatorRogueOffset or 10
                                end,
                                set = function(_, v)
                                    local db = FrameDB(); if not db then return end
                                    db.combatIndicatorRogueOffset = v
                                    ApplyFrameSettings()
                                    OnCombatSetting("combatIndicatorRogueOffset", v)
                                end,
                            },
                        },
                    },
                    focusComboBox = {
                        type = "group",
                        name = L and (L["Focus Combo Points"] or SarychUI:T("ui.options_7616685b4b")) or SarychUI:T("ui.options_7616685b4b"),
                        desc = L and (L["Added by suggestion: Hannahmckay"] or SarychUI:T("ui.options_5ab82ee598")) or SarychUI:T("ui.options_5ab82ee598"),
                        order = 6,
                        inline = true,
                        suiHelpIcon = true,
                        args = {
                            enable_focus_combo_points = {
                                type = "toggle",
                                name = L and (L["Enable"] or SarychUI:T("ui.enable_a54eaf37")) or SarychUI:T("ui.enable_a54eaf37"),
                                desc = L and (L["Focus Combo Points Desc"] or SarychUI:T("ui.options_ad7820d635")) or SarychUI:T("ui.options_ad7820d635"),
                                order = 1,
                                width = "full",
                                suiPreviewKey = "enableFocusComboPoints",
                                get = function() return isOn("enableFocusComboPoints") end,
                                set = function(_, value)
                                    local db = FrameDB(); if not db then return end
                                    db.enableFocusComboPoints = value and 1 or 0
                                    ApplyFrameSettings()
                                    NotifyCombatPreview("enableFocusComboPoints", value and 1 or 0)
                                    RefreshConfig()
                                end,
                            },
                        },
                    },
                },
            },

            -- Text tab
            text = {
                type = "group",
                name = "ui.indicator_text_771c2829",
                order = 4,
                disabled = function() return not isEnabled() end,
                args = {
                    textDisplayMode = {
                        type = "select",
                        name = "ui.text_indicators_612c7caf",
                        order = 0,
                        values = {
                            show = "ui.unit_frames.show_blizzard_text",
                            hide = "ui.unit_frames.hide_text",
                        },
                        get = function() return FrameDB().textIndicatorMode or "hide" end,
                        set = function(_, value)
                            FrameDB().textIndicatorMode = value
                            ApplyFrameSettings()
                            RefreshConfig()
                        end,
                    },
                    blizzardTextBox = {
                        type = "group",
                        name = "ui.text_indicators_612c7caf",
                        order = 1,
                        inline = true,
                        suiThreeCol = true,
                        hidden = function() return FrameDB().textIndicatorMode ~= "show" end,
                        args = {
                            player = StatusTextOption("playerStatusText", "ui.player_f54f58cf", 1),
                            pet = StatusTextOption("petStatusText", "ui.pet_31cd9c45", 2),
                            party = StatusTextOption("partyStatusText", "ui.party_907efbd4", 3),
                            target = StatusTextOption("targetStatusText", "ui.target_1d6ae787", 4),
                            percent = StatusTextOption("statusTextPercentage", "ui.options_1b1725098a", 5),
                        },
                    },
                    visibilityBox = {
                        type = "group",
                        name = "ui.text_indicators_612c7caf",
                        order = 1,
                        inline = true,
                        hidden = function() return FrameDB().textIndicatorMode == "show" end,
                        args = {
                            show_on_alt = {
                                type = "toggle",
                                name = "ui.show_while_holding_cffffd700alt_r_59389ba9",
                                desc = "ui.show_text_indicators_hp_mp_text_only_while_alt_i_62a2f79f",
                                order = 1,
                                width = "full",
                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                get = function() return SarychUI.db.profile.modules.frame.showOnAlt == 1 end,
								set = function(_, v)
									SarychUI.db.profile.modules.frame.showOnAlt = v and 1 or 0
									ApplyFrameSettings()
									RefreshConfig()
								end,
                            },
                            show_in_combat = {
                                type = "toggle",
                                name = "ui.show_during_combat_7ee0fb06",
                                desc = "ui.always_show_text_indicators_hp_mp_text_during_co_a0a7bf5c",
                                order = 2,
                                width = "full",
                                hidden = function() return not isOn("showOnAlt") end,
                                get = function() return SarychUI.db.profile.modules.frame.showTextIndicatorsInCombat == true end,
                                set = function(_, v)
                                    SarychUI.db.profile.modules.frame.showTextIndicatorsInCombat = v and true or false
                                    if module.UpdateCombatState then
                                        module:UpdateCombatState()
                                    end
                                    ApplyFrameSettings()
                                end,
                            },
                            fade_after_combat = {
                                type = "toggle",
                                name = "ui.smooth_fade_in_out_642867f1",
                                desc = "ui.smoothly_fade_text_indicators_in_when_entering_c_f5a16181",
                                order = 3,
                                width = "full",
                                hidden = function() return not isOn("showOnAlt") end,
                                disabled = function() return SarychUI.db.profile.modules.frame.showTextIndicatorsInCombat ~= true end,
                                get = function() return SarychUI.db.profile.modules.frame.textIndicatorsFadeAfterCombat == true end,
                                set = function(_, v)
                                    SarychUI.db.profile.modules.frame.textIndicatorsFadeAfterCombat = v and true or false
                                    ApplyFrameSettings()
                                end,
                            },
                            fade_time = {
                                type = "range",
                                name = "ui.animation_time_a171576d",
                                desc = "ui.fade_in_out_time_for_text_indicators_seconds_61038a21",
                                min = 0.1,
                                max = 2.0,
                                step = 0.1,
                                order = 4,
                                width = "full",
                                hidden = function() return not isOn("showOnAlt") end,
                                disabled = function() return SarychUI.db.profile.modules.frame.showTextIndicatorsInCombat ~= true or SarychUI.db.profile.modules.frame.textIndicatorsFadeAfterCombat ~= true end,
                                get = function() return SarychUI.db.profile.modules.frame.textIndicatorsFadeTime or 0.4 end,
                                set = function(_, v)
                                    SarychUI.db.profile.modules.frame.textIndicatorsFadeTime = v
                                    ApplyFrameSettings()
                                end,
                            },
                        },
                    },
                    percentagesBox = {
                        type = "group",
                        name = "ui.health_percents_21a5d614",
                        order = 3,
                        inline = true,
                        args = {
                            target_percent = {
                                type = "toggle",
                                name = "ui.show_cffffd700target_r_health_percent_98bb6aa1",
                                desc = "ui.show_cffffd700target_r_health_percent_on_the_fra_2cc2e515",
                                order = 1,
                                width = "full",
                                get = function() return SarychUI.db.profile.modules.frame.showTargetPercent == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.showTargetPercent = v and 1 or 0; ApplyFrameSettings() end,
                            },
                            focus_percent = {
                                type = "toggle",
                                name = "ui.show_cffffd700focus_r_health_percent_b9d9d628",
                                desc = "ui.show_cffffd700focus_r_health_percent_on_the_fram_b5847a0d",
                                order = 2,
                                width = "full",
                                get = function() return SarychUI.db.profile.modules.frame.showFocusPercent == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.showFocusPercent = v and 1 or 0; ApplyFrameSettings() end,
                            },
                            show_percentages_on_alt = {
                                type = "toggle",
                                name = "ui.show_percents_while_holding_cffffd700alt_r_c645b06e",
                                desc = "ui.show_health_percents_only_while_alt_is_held_720fab1a",
                                order = 3,
                                width = "full",
                                suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                get = function() return SarychUI.db.profile.modules.frame.showPercentagesOnAlt == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.showPercentagesOnAlt = v and 1 or 0; ApplyFrameSettings() end,
                            },
                        },
                    },
                    classBox = {
                        type = "group",
                        name = "ui.class_rules_for_percent_display_e60e5762",
                        order = 4,
                        inline = true,
                        args = {
                            warlock_always = {
                                type = "toggle",
                                name = "ui.cffffd700warlock_r_always_show_until_threshold_a0663dd5",
                                desc = "ui.for_cffffd700warlocks_r_always_show_cffffd700tar_a08386de",
                                order = 1,
                                width = "full",
                                get = function() return SarychUI.db.profile.modules.frame.warlockAlways == 1 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.warlockAlways = v and 1 or 0; ApplyFrameSettings() end,
                            },
                            warlock_threshold = {
                                type = "range",
                                name = "ui.cffffd700target_r_health_threshold_bb9e97c5",
                                desc = "ui.cffffd700target_r_health_threshold_percent_1_100_c5c99f42",
                                order = 2,
                                min = 1,
                                max = 100,
                                step = 1,
                                width = "full",
                                disabled = function() return SarychUI.db.profile.modules.frame.warlockAlways ~= 1 end,
                                get = function() return SarychUI.db.profile.modules.frame.warlockThreshold or 25 end,
                                set = function(_, v) SarychUI.db.profile.modules.frame.warlockThreshold = v; ApplyFrameSettings() end,
                            },
                        },
                    },
                },
            },

            -- Visual tab
            visual = {
                type = "group",
                name = "ui.appearance_c407960b",
                order = 5,
                disabled = function() return not isEnabled() end,
                childGroups = "tab",
                args = {
                    -- Frames appearance tab (preview + PVP + portraits)
                    pvp = {
                        type = "group",
                        name = "ui.frames_ce7f103c",
                        order = 1,
                        args = {
                            preview = {
                                type = "description",
                                name = "",
                                order = 0,
                                width = "full",
                                suiPreview = "FramePvpPreview",
                            },
                            hideLevelBox = {
                                type = "group",
                                name = "ui.hide_level_on_frames_ed781d3a",
                                order = 1,
                                inline = true,
                                hidden = function()
                                    local db = FrameDB()
                                    return db.classIconEnabled == 1 and db.classIconStyle == "replace"
                                end,
                                args = {
                                    hide_frame_level = {
                                        type = "toggle",
                                        name = "ui.enable_a54eaf37",
                                        desc = "ui.hides_the_level_number_on_player_target_and_focu_f1b80927",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hideFrameLevel",
                                        get = function() return SarychUI.db.profile.modules.frame.hideFrameLevel == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hideFrameLevel = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                },
                            },
                            classNamesBox = {
                                type = "group",
                                name = "ui.class_colored_names_07036e8e",
                                order = 1.1,
                                inline = true,
                                args = {
                                    class_colored_names = {
                                        type = "toggle",
                                        name = "ui.enable_a54eaf37",
                                        desc = "ui.colors_names_on_target_and_focus_frames_by_class_2ee662fd",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "classColoredNames",
                                        get = function() return SarychUI.db.profile.modules.frame.classColoredNames == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classColoredNames = v and 1 or 0
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    class_colored_names_exclude_player = {
                                        type = "toggle",
                                        name = "ui.exclude_player_frame_23a89d59",
                                        desc = "ui.do_not_color_the_name_on_the_player_frame_applie_ef2a4fbc",
                                        order = 2,
                                        width = "full",
                                        hidden = function() return SarychUI.db.profile.modules.frame.classColoredNames ~= 1 end,
                                        suiPreviewKey = "classColoredNamesExcludePlayer",
                                        get = function() return SarychUI.db.profile.modules.frame.classColoredNamesExcludePlayer == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classColoredNamesExcludePlayer = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                            classColorHPBox = {
                                type = "group",
                                name = "ui.health_bar_color_0f25c3be",
                                desc = "ui.text_43d43b39",
                                order = 1.15,
                                inline = true,
                                suiHelpIcon = true,
                                disabled = function() return not IsUnitFrameLayersEnabled() end,
                                args = {
                                    classColorHP = {
                                        type = "toggle",
                                        name = "ui.class_color_for_health_bar_820c8c62",
                                        desc = "ui.colors_the_target_focus_and_other_players_health_940bdce5",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "classColorHP",
                                        get = function()
                                            local db = UnitFrameLayersDB()
                                            local val = db and db.classColorHP
                                            return val ~= false
                                        end,
                                        set = function(_, value)
                                            local db = UnitFrameLayersDB()
                                            if not db then return end
                                            db.classColorHP = value and true or false
                                            RefreshUnitFrameLayersHealthColors()
                                            RefreshConfig()
                                        end,
                                    },
                                    playerClassColorHP = {
                                        type = "toggle",
                                        name = "ui.player_class_color_for_the_health_bar_d7b38a12",
                                        desc = "ui.colors_the_player_health_bar_by_class_if_disable_6dce8ef0",
                                        order = 2,
                                        width = "full",
                                        suiPreviewKey = "playerClassColorHP",
                                        hidden = function()
                                            if not IsUnitFrameLayersEnabled() then
                                                return false
                                            end
                                            local db = UnitFrameLayersDB()
                                            return not db or db.classColorHP == false
                                        end,
                                        disabled = function()
                                            if not IsUnitFrameLayersEnabled() then
                                                return true
                                            end
                                            local db = UnitFrameLayersDB()
                                            return not db or db.classColorHP == false
                                        end,
                                        get = function()
                                            local db = UnitFrameLayersDB()
                                            return db and db.playerClassColorHP == true
                                        end,
                                        set = function(_, value)
                                            local db = UnitFrameLayersDB()
                                            if not db then return end
                                            db.playerClassColorHP = value and true or false
                                            RefreshUnitFrameLayersHealthColors()
                                        end,
                                    },
                                    resourceGainPrediction = {
                                        type = "toggle", name = "ui.ufl.resource_gain", desc = "ui.ufl.resource_gain_desc",
                                        order = 3, width = "full",
                                        disabled = function() return not IsUnitFrameLayersEnabled() end,
                                        get = function() local db = UnitFrameLayersDB(); return not db or db.resourceGainPrediction ~= false end,
                                        set = function(_, value)
                                            local db = UnitFrameLayersDB(); if not db then return end
                                            db.resourceGainPrediction = value and true or false
                                            SarychUI.UnitFrameLayers:RefreshResourcePrediction()
                                        end,
                                    },
                                },
                            },
							leaderIconBox = {
                                type = "group",
                                name = "ui.text_2f1167b2",
                                order = 1.25,
                                inline = true,
                                args = {
                                    hide_leader_icon = {
                                        type = "toggle",
                                        name = "ui.text_46d6ed48",
                                        desc = "ui.text_b6ce1877",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hideLeaderIcon",
                                        get = function() return SarychUI.db.profile.modules.frame.hideLeaderIcon == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.hideLeaderIcon = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                            restStateBox = {
                                type = "group",
                                name = "ui.text_ca53b40d",
                                order = 1.2,
                                inline = true,
                                args = {
                                    hide_player_rest_state = {
                                        type = "toggle",
                                        name = "ui.text_2245ae1f",
                                        desc = "ui.text_76f80fdd",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hidePlayerRestState",
                                        get = function() return SarychUI.db.profile.modules.frame.hidePlayerRestState == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.hidePlayerRestState = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                            nameBgBox = {
                                type = "group",
                                name = "ui.name_background_9b08b4c8",
                                order = 2,
                                inline = true,
                                suiSelectWithColor = true,
                                args = {
                                    enabled = {
                                        type = "toggle",
                                        name = "ui.enable_a54eaf37",
                                        desc = "ui.replaces_the_default_colored_background_behind_n_a7385018",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "nameBackgroundEnabled",
                                        get = function() return SarychUI.db.profile.modules.frame.nameBackgroundEnabled == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.nameBackgroundEnabled = v and 1 or 0
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    mode = {
                                        type = "select",
                                        name = "",
                                        desc = "ui.custom_background_your_color_and_opacity_class_c_5d363890",
                                        order = 2,
                                        values = {
                                            custom = SarychUI:T("ui.options_d0b5b705b3"),
                                            class = SarychUI:T("ui.options_e670d10107"),
                                            __order = { "custom", "class" },
                                        },
                                        hidden = function() return SarychUI.db.profile.modules.frame.nameBackgroundEnabled ~= 1 end,
                                        suiPreviewKey = "nameBackgroundMode",
                                        get = function() return SarychUI.db.profile.modules.frame.nameBackgroundMode or "custom" end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.nameBackgroundMode = v
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    color = {
                                        type = "color",
                                        name = "",
                                        desc = "ui.color_and_opacity_of_the_background_behind_the_n_8510128f",
                                        hasAlpha = true,
                                        order = 3,
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            return db.nameBackgroundEnabled ~= 1 or db.nameBackgroundMode ~= "custom"
                                        end,
                                        suiPreviewKey = "nameBackgroundColor",
                                        get = function()
                                            local c = SarychUI.db.profile.modules.frame.nameBackgroundColor or { 0, 0, 0, 0 }
                                            local r, g, b, a = c[1], c[2], c[3], c[4]
                                            if r == nil then r = 0 end
                                            if g == nil then g = 0 end
                                            if b == nil then b = 0 end
                                            if a == nil then a = 0 end
                                            return r, g, b, a
                                        end,
                                        set = function(_, r, g, b, a)
                                            SarychUI.db.profile.modules.frame.nameBackgroundColor = { r, g, b, a }
                                            ApplyFrameSettings()
                                        end,
                                    },
                                    excludePlayer = {
                                        type = "toggle",
                                        name = "ui.exclude_player_frame_23a89d59",
                                        desc = "ui.do_not_change_the_name_background_on_the_player__f708825b",
                                        order = 4,
                                        width = "full",
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            return db.nameBackgroundEnabled ~= 1 or db.nameBackgroundMode ~= "class"
                                        end,
                                        suiPreviewKey = "nameBackgroundExcludePlayer",
                                        get = function() return SarychUI.db.profile.modules.frame.nameBackgroundExcludePlayer == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.nameBackgroundExcludePlayer = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                            iconsBox = {
                                type = "group",
                                name = "ui.pvp_icons_bc0c1b5c",
                                order = 4,
                                inline = true,
                                args = {
                                    hide_player_pvp = {
                                        type = "toggle",
                                        name = "ui.hide_cffffd700player_r_pvp_icons_24e7dd7c",
                                        desc = "ui.hide_pvp_icons_on_the_cffffd700player_r_frame_8fe0217e",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hidePlayerPVP",
                                        get = function() return SarychUI.db.profile.modules.frame.hidePlayerPVP == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hidePlayerPVP = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                    hide_target_pvp = {
                                        type = "toggle",
                                        name = "ui.hide_cffffd700target_r_pvp_icons_789ac413",
                                        desc = "ui.hide_pvp_icons_on_the_cffffd700target_r_frame_21dbbf96",
                                        order = 2,
                                        width = "full",
                                        suiPreviewKey = "hideTargetPVP",
                                        get = function() return SarychUI.db.profile.modules.frame.hideTargetPVP == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hideTargetPVP = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                    hide_focus_pvp = {
                                        type = "toggle",
                                        name = "ui.hide_cffffd700focus_r_pvp_icons_b7ad6da8",
                                        desc = "ui.hide_pvp_icons_on_the_cffffd700focus_r_frame_5975a54b",
                                        order = 3,
                                        width = "full",
                                        suiPreviewKey = "hideFocusPVP",
                                        get = function() return SarychUI.db.profile.modules.frame.hideFocusPVP == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hideFocusPVP = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                },
                            },
                            timerBox = {
                                type = "group",
                                name = "ui.pvp_timer_e22f7336",
                                order = 5,
                                inline = true,
                                args = {
                                    pvp_timer = {
                                        type = "toggle",
                                        name = "ui.hide_pvp_timer_47e95358",
                                        desc = "ui.hide_pvp_status_timer_838184ed",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "hidePVPTimer",
                                        get = function() return SarychUI.db.profile.modules.frame.hidePVPTimer == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.hidePVPTimer = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                    pvp_timer_on_alt = {
                                        type = "toggle",
                                        name = "ui.show_pvp_timer_while_holding_cffffd700alt_r_d864049e",
                                        desc = "ui.show_pvp_timer_only_while_alt_is_held_1762e166",
                                        order = 2,
                                        width = "full",
                                        suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
                                        suiPreviewKey = "pvpTimerOnAlt",
                                        disabled = function() return SarychUI.db.profile.modules.frame.hidePVPTimer ~= 1 end,
                                        get = function() return SarychUI.db.profile.modules.frame.pvpTimerOnAlt == 1 end,
                                        set = function(_, v) SarychUI.db.profile.modules.frame.pvpTimerOnAlt = v and 1 or 0; ApplyFrameSettings() end,
                                    },
                                },
                            },
                            portraitsBox = {
                                type = "group",
                                name = "ui.portrait_changes_6f93c307",
                                desc = "ui.class_spec_icon_instead_of_the_portrait_or_a_cla_b2df8ae9",
                                order = 6,
                                inline = true,
                                suiHelpIcon = true,
                                args = {
                                    portrait3D = {
                                        type = "toggle",
                                        name = "ui.3d_portraits_d165af74",
                                        desc = "ui.animated_3d_models_instead_of_portraits_on_all_f_c872f9a5",
                                        order = 0,
                                        width = "full",
                                        suiPreviewKey = "portrait3D",
                                        get = function() return SarychUI.db.profile.modules.frame.portrait3D == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.portrait3D = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                    classIconEnabled = {
                                        type = "toggle",
                                        name = "ui.enable_a54eaf37",
                                        desc = "ui.changes_the_portrait_to_a_class_spec_icon_or_sho_7cbbb711",
                                        order = 1,
                                        width = "full",
                                        suiPreviewKey = "classIconEnabled",
                                        get = function() return SarychUI.db.profile.modules.frame.classIconEnabled == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconEnabled = v and 1 or 0
                                            ApplyFrameSettings()
                                            RefreshConfig()
                                        end,
                                    },
                                    classIconStyle = {
                                        type = "select",
                                        name = "",
                                        desc = "ui.cffffd700class_icon_r_round_class_icon_instead_o_9e362fd5",
                                        order = 2,
                                        width = "full",
                                        values = {
                                            class = SarychUI:T("ui.options_b73f9f0b0b"),
                                            spec = SarychUI:T("ui.options_17291d5a96"),
                                            badge = SarychUI:T("ui.options_1f182fb97a"),
                                            separate = SarychUI:T("ui.options_ddbdbe7e31"),
                                            replace = SarychUI:T("ui.options_75b22b6fcb"),
                                            __order = { "class", "spec", "badge", "separate", "replace" },
                                        },
                                        hidden = function() return SarychUI.db.profile.modules.frame.classIconEnabled ~= 1 end,
                                        suiPreviewKey = "classIconStyle",
                                        get = function() return SarychUI.db.profile.modules.frame.classIconStyle or "class" end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconStyle = v
                                            ApplyFrameSettings()
                                            -- Rebuild so the options of the chosen style appear.
                                            RefreshConfig()
                                        end,
                                    },
                                    classIconPortraitsPlayer = {
                                        type = "toggle",
                                        name = "ui.class_icon_on_the_cffffd700player_r_frame_0361e0b9",
                                        desc = "ui.change_the_portrait_on_the_player_frame_if_off_t_31986cd4",
                                        order = 3,
                                        width = "full",
                                        suiPreviewKey = "classIconPortraitsPlayer",
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            local style = db.classIconStyle or "class"
                                            return db.classIconEnabled ~= 1 or style == "separate" or style == "replace"
                                        end,
                                        get = function() return SarychUI.db.profile.modules.frame.classIconPortraitsPlayer == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconPortraitsPlayer = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                    classIconPlayer = {
                                        type = "toggle",
                                        name = "ui.class_icon_on_the_cffffd700player_r_frame_0361e0b9",
                                        desc = "ui.show_the_class_icon_on_the_player_frame_if_off_t_6032551b",
                                        order = 4,
                                        width = "full",
                                        suiPreviewKey = "classIconPlayer",
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            local style = db.classIconStyle or "class"
                                            return db.classIconEnabled ~= 1 or (style ~= "separate" and style ~= "replace")
                                        end,
                                        get = function() return SarychUI.db.profile.modules.frame.classIconPlayer ~= 0 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconPlayer = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                    classIconOffsets = {
                                        type = "group", name = "", order = 5, inline = true,
                                        suiColumnGroups = true,
                                        hidden = function()
                                            local db = FrameDB()
                                            return db.classIconEnabled ~= 1 or db.classIconStyle ~= "separate"
                                        end,
                                        args = {
                                            other = {
                                                type = "group", name = "ui.frame.class_icon_offsets_other", order = 1, inline = true,
                                                args = {
                                                    classIconX = {
                                                        type = "range",
                                                        name = "ui.x_offset_0b923c73", desc = "ui.text_238254c1",
                                                        min = -80, max = 80, step = 1, order = 1, width = "full",
                                                        suiPreviewKey = "classIconX",
                                                        get = function()
                                                            local value = FrameDB().classIconX
                                                            if value == nil then return -73 end
                                                            return value
                                                        end,
                                                        set = function(_, value)
                                                            FrameDB().classIconX = value
                                                            ApplyFrameSettings()
                                                        end,
                                                    },
                                                    classIconY = {
                                                        type = "range",
                                                        name = "ui.y_offset_f7f3fdd7", desc = "ui.text_33112b35",
                                                        min = -80, max = 80, step = 1, order = 2, width = "full",
                                                        suiPreviewKey = "classIconY",
                                                        get = function()
                                                            local value = FrameDB().classIconY
                                                            if value == nil then return 43 end
                                                            return value
                                                        end,
                                                        set = function(_, value)
                                                            FrameDB().classIconY = value
                                                            ApplyFrameSettings()
                                                        end,
                                                    },
                                                },
                                            },
                                            player = {
                                                type = "group", name = "ui.frame.class_icon_offsets_player", order = 2, inline = true,
                                                hidden = function() return FrameDB().classIconPlayer == 0 end,
                                                args = {
                                                    classIconPlayerX = {
                                                        type = "range",
                                                        name = "ui.x_offset_0b923c73", desc = "ui.text_238254c1",
                                                        min = -80, max = 80, step = 1, order = 1, width = "full",
                                                        suiPreviewKey = "classIconPlayerX",
                                                        get = function()
                                                            local value = FrameDB().classIconPlayerX
                                                            if value == nil then return 73 end
                                                            return value
                                                        end,
                                                        set = function(_, value)
                                                            FrameDB().classIconPlayerX = value
                                                            ApplyFrameSettings()
                                                        end,
                                                    },
                                                    classIconPlayerY = {
                                                        type = "range",
                                                        name = "ui.y_offset_f7f3fdd7", desc = "ui.text_33112b35",
                                                        min = -80, max = 80, step = 1, order = 2, width = "full",
                                                        suiPreviewKey = "classIconPlayerY",
                                                        get = function()
                                                            local value = FrameDB().classIconPlayerY
                                                            if value == nil then return 43 end
                                                            return value
                                                        end,
                                                        set = function(_, value)
                                                            FrameDB().classIconPlayerY = value
                                                            ApplyFrameSettings()
                                                        end,
                                                    },
                                                },
                                            },
                                        },
                                    },
                                    classIconMaxLevelOnly = {
                                        type = "toggle",
                                        name = "ui.only_at_max_level_2d422377",
                                        desc = "ui.replace_the_level_with_the_class_icon_only_for_m_c92e9e65",
                                        order = 7,
                                        width = "full",
                                        suiPreviewKey = "classIconMaxLevelOnly",
                                        hidden = function()
                                            local db = SarychUI.db.profile.modules.frame
                                            return db.classIconEnabled ~= 1 or db.classIconStyle ~= "replace"
                                        end,
                                        get = function() return SarychUI.db.profile.modules.frame.classIconMaxLevelOnly == 1 end,
                                        set = function(_, v)
                                            SarychUI.db.profile.modules.frame.classIconMaxLevelOnly = v and 1 or 0
                                            ApplyFrameSettings()
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- Pets tab
                    pets = {
                        type = "group",
                        name = "ui.pets_61161ec5",
                        order = 2,
                        args = {
                            petsBox = {
                                type = "group",
                                name = " ",
                                order = 1,
                                inline = true,
                                args = {
                                    enablePetNameShortening = {
                                        type = "toggle",
                                        name = "ui.shorten_long_pet_names_97c879d9",
                                        desc = "ui.shortens_overly_long_pet_names_for_readability_ae487466",
                                        order = 1,
                                        width = "full",
                                        get = function()
                                            return SarychUI.db.profile.modules.frame.enablePetNameShortening == 1
                                        end,
                                        set = function(_, val)
                                            SarychUI.db.profile.modules.frame.enablePetNameShortening = val and 1 or 0
                                            local toolsModule = SarychUI.modules
                                            if toolsModule and SarychUI.modules.frame.ApplyPetNameShortening then
                                                SarychUI.modules.frame:ApplyPetNameShortening()
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
