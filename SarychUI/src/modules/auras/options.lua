-- SarychUI Auras Module Options

local moduleName = "auras"
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

local function isEnabled()
	local db = DB()
	return db and db.enabled
end

local function isOn(key)
	local db = DB()
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

function module:SetConsolidationException(value, enabled, listKey)
    listKey = listKey or "consolidationExceptions"
    if listKey ~= "consolidationExceptions" and listKey ~= "playerBuffBlacklist" and listKey ~= "playerDebuffBlacklist" and listKey ~= "frameBuffBlacklist" and listKey ~= "frameDebuffBlacklist" and listKey ~= "groupBuffBlacklist" and listKey ~= "groupDebuffBlacklist" and listKey ~= "groupDispelExceptions" then return false end
    local id = tonumber(value)
    if not id or id <= 0 or id ~= math.floor(id) or id > 2147483647 then
        return false, SarychUI:T("ui.auras.invalid_id")
    end
    local db = (listKey == "groupBuffBlacklist" or listKey == "groupDebuffBlacklist" or listKey == "groupDispelExceptions")
        and SarychUI:GetModuleProfile("group_frames") or DB()
    if not db then return false, SarychUI:T("ui.auras.no_profile") end
    db[listKey] = db[listKey] or {}
    if enabled and SarychUI.AuraTracking:ResolveSpell(db[listKey], id, SarychUI.AuraTracking:BuildSpellIndex(db[listKey])) then return false, SarychUI:T("ui.auras.duplicate") end
    db[listKey][id] = enabled and true or nil
    self._playerAuraBlacklistIndexes = nil
    self._consolidationExceptionIndex = nil
    if listKey == "groupBuffBlacklist" or listKey == "groupDebuffBlacklist" or listKey == "groupDispelExceptions" then
        SarychUI.modules.group_frames:ApplyAuraBlacklist()
        return true
    end
    if self.RefreshAuraLayout then self:RefreshAuraLayout() elseif BuffFrame_Update then BuffFrame_Update() end
    return true
end

function module:OpenConsolidationExceptions(listKey)
    listKey = listKey or "consolidationExceptions"
    local db = (listKey == "groupBuffBlacklist" or listKey == "groupDebuffBlacklist" or listKey == "groupDispelExceptions")
        and SarychUI:GetModuleProfile("group_frames") or DB()
    if not (db and db.enabled) then return end
    if listKey == "consolidationExceptions" then
        if not (db.consolidateForeignBuffs and GetCVar("consolidateBuffs") == "1") then return end
    elseif listKey == "playerBuffBlacklist" or listKey == "playerDebuffBlacklist" then
        if not db.playerAuraBlacklistEnabled then return end
    elseif listKey == "frameBuffBlacklist" or listKey == "frameDebuffBlacklist" then
        if not db.frameAuraBlacklistEnabled then return end
    elseif listKey == "groupDispelExceptions" then
        local profile = GetActiveRaidProfile and GetActiveRaidProfile()
        if not profile or not GetRaidProfileOption(profile, "displayOnlyDispellableDebuffs") then return end
    elseif listKey == "groupBuffBlacklist" or listKey == "groupDebuffBlacklist" then
        if not db.auraBlacklistEnabled then return end
    else return end
    local SUI, W, T = SarychUI, SarychUI.OptionsWidgets, SarychUI.OptionsTheme
    local f = self.consolidationExceptionsWindow
    if not f then
        f = CreateFrame("Frame", "SarychUIConsolidationExceptions", UIParent)
        self.consolidationExceptionsWindow = f
        f:SetSize(320, 220)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:EnableMouse(true)
        T:ApplyFlat(f, T.colors.dialogBg, T.colors.border)
        table.insert(UISpecialFrames, "SarychUIConsolidationExceptions")
        local header = CreateFrame("Frame", nil, f)
        header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1)
        header:SetHeight(32)
        T:ApplyFlat(header, T.colors.headerBg, T.colors.borderSoft)
        header:EnableMouse(true); header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart", function() f:StartMoving() end)
        header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
        local title = header:CreateFontString(nil, "OVERLAY", T.fonts.title)
        title:SetPoint("LEFT", 12, 0); title:SetText(SarychUI:T("ui.auras.consolidation_exceptions"))
        title:SetPoint("RIGHT", header, "RIGHT", -38, 0)
        title:SetJustifyH("LEFT")
        f.title = title
        T:SetTextColor(title, "title")
        local close = W:Button(header, "X", function() f:Hide() end)
        close:SetSize(22, 22); close:SetPoint("RIGHT", -8, 0)
        local draft = ""
        local input = W:InputWithButton(f, SarychUI:T("ui.auras.id"), SarychUI:T("ui.options_559a87f7cc"), function() return draft end, function(value)
            if f:GetListProfile() ~= f.profile then f:Hide(); return end
            draft = value
            local ok, message = module:SetConsolidationException(value, true, f.listKey)
            if ok then draft = ""; f:RefreshList() end
            if message then SUI:Print(message) end
        end, false)
        input:SetPoint("TOPLEFT", 12, -42); input:SetPoint("TOPRIGHT", -(12 + T.sizes.scrollbarW + T.sizes.scrollbarGap), -42)
        local scroll = CreateFrame("ScrollFrame", nil, f)
        scroll:SetPoint("TOPLEFT", 12, -84)
        scroll:SetPoint("BOTTOMRIGHT", -(12 + T.sizes.scrollbarW + T.sizes.scrollbarGap), 12)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(320 - 24 - T.sizes.scrollbarW - T.sizes.scrollbarGap)
        content:SetHeight(1); scroll:SetScrollChild(content)
        local _, updateScroll = W:Scrollbar(f, scroll, function()
            return scroll:GetHeight(), content:GetHeight()
        end)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(_, delta)
            local limit = math.max(0, content:GetHeight() - scroll:GetHeight())
            scroll:SetVerticalScroll(math.max(0, math.min(limit, scroll:GetVerticalScroll() - delta * T.sizes.scrollStep)))
        end)
        function f:GetListProfile()
            if self.listKey == "groupBuffBlacklist" or self.listKey == "groupDebuffBlacklist" or self.listKey == "groupDispelExceptions" then
                return SUI:GetModuleProfile("group_frames")
            end
            return DB()
        end
        f.rows = {}
        function f:RefreshList()
            local current = self:GetListProfile()
            if current ~= self.profile then self:Hide(); return end
            local ids = {}
            for id, enabled in pairs(current[self.listKey] or {}) do
                if enabled and type(id) == "number" then ids[#ids+1] = id end
            end
            table.sort(ids)
            for _, row in ipairs(self.rows) do row:Hide() end
            local y = 0
            for i, id in ipairs(ids) do
                local name, _, texture = GetSpellInfo(id)
                texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"
                local row = self.rows[i]
                if not row then
                    row = W:CompactListRow(content, "", SarychUI:T("ui.delete_be99b136"), function()
                        if f:GetListProfile() ~= f.profile then f:Hide(); return end
                        module:SetConsolidationException(f.rows[i].spellID, false, f.listKey)
                        f:RefreshList()
                    end, texture)
                    self.rows[i] = row
                end
                row.spellID = id
                row.button.label:SetText(SarychUI:T("ui.delete_be99b136"))
                row.label:SetText(name or SarychUI:T("ui.auras.unknown"))
                row.button:SetSize(90, T.sizes.controlH or 20)
                row.icon:SetTexture(texture)
                row.label:SetWordWrap(false)
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetWidth(content:GetWidth())
                row:Show(); y = y + row:GetHeight() + 4
            end
            -- Grow with the list up to the compact window limit, then scroll.
            local listHeight = math.max(1, y > 0 and y - 4 or 0)
            content:SetHeight(listHeight)
            f:SetHeight(math.min(220, 84 + listHeight + 12))
            scroll:UpdateScrollChildRect(); updateScroll()
        end
        f:SetScript("OnHide", function()
            f:StopMovingOrSizing()
            draft = ""
            for _, child in ipairs({input:GetChildren()}) do
                if child:IsObjectType("EditBox") then child:ClearFocus() end
            end
        end)
        f:SetScript("OnShow", function()
            input:SetLabels(SarychUI:T("ui.auras.id"), SarychUI:T("ui.options_559a87f7cc"))
            draft = ""; input:Refresh(); scroll:SetVerticalScroll(0)
            f:RefreshList(); updateScroll()
        end)
        f:Hide()
    end
    f:Hide()
    f.profile, f.listKey = db, listKey
    f.title:SetText(listKey == "groupDispelExceptions" and SarychUI:T("ui.options_ea65534c79") or (listKey == "playerBuffBlacklist" or listKey == "frameBuffBlacklist" or listKey == "groupBuffBlacklist") and SarychUI:T("ui.auras.buff_blacklist")
        or (listKey == "playerDebuffBlacklist" or listKey == "frameDebuffBlacklist" or listKey == "groupDebuffBlacklist") and SarychUI:T("ui.auras.debuff_blacklist") or SarychUI:T("ui.auras.consolidation_exceptions"))
    f:Show(); f:RefreshList(); f:Raise()
end

local function NotifyAurasPreview(key, value)
	local preview = SarychUI and SarychUI.AurasPreview
	if not preview then return end
	if key ~= nil and preview.SetLiveValue then
		preview:SetLiveValue(key, value)
	elseif preview.RefreshAll then
		preview:RefreshAll()
	end
end

local function ApplyBuffs()
	if module and module.ApplyBuffManagement then
		module:ApplyBuffManagement()
	end
end

local function SeparatePlayerAuras()
	local db = DB()
	return db and db.playerAuraPositionMode == "separate"
end

local PLAYER_AURA_GROWTH_VALUES = {
	right_to_left = "ui.options_79b471d2d2",
	left_to_right = "ui.options_f80a0cc7d0",
	__order = { "right_to_left", "left_to_right" },
}

local function ClosePlayerAuraDragPanel()
	local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
	if panel and panel.IsOpen and panel:IsOpen() and panel.GetFrameId then
		local frameId = panel:GetFrameId()
		if frameId == "buffFrame" or frameId == "debuffFrame" then
			panel:Close(false)
		end
	end
end

local function TogglePlayerAuraDrag(frameId, dragKey, gridKey)
	local db = DB()
	if not db then return end
	local value = not (db[dragKey] == 1)
	db[dragKey] = value and 1 or 0
	db[gridKey] = value and 1 or 0
	local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
	if panel and panel.Toggle then
		panel:Toggle(frameId, value)
	else
		ApplyBuffs()
	end
	RefreshConfig()
end

local function AuraDefault(key, fallback)
	local def = SarychUI.defaults and SarychUI.defaults.profile
		and SarychUI.defaults.profile.modules
		and SarychUI.defaults.profile.modules.auras
	if def and def[key] ~= nil then
		return def[key]
	end
	return fallback
end

local function ResetPlayerAuraDefaults(frameId, xKey, yKey, xFallback, yFallback, growthKey, scaleKey)
	local db = DB(); if not db then return end
	local x = AuraDefault(xKey, xFallback)
	local y = AuraDefault(yKey, yFallback)
	db[xKey] = x
	db[yKey] = y
	if growthKey then
		db[growthKey] = AuraDefault(growthKey, "right_to_left")
	end
	if scaleKey then
		db[scaleKey] = AuraDefault(scaleKey, 1.0)
	end
	local panel = SarychUI and (SarychUI.PositionDragPanel or SarychUI.CombatTextDragPanel)
	if panel and panel.SyncDraftIfOpen then
		panel:SyncDraftIfOpen(frameId, x, y)
	end
	ApplyBuffs()
	RefreshConfig()
end

function module:GetOptions()
	return {
		type = "group",
		name = L and (L["Auras"] or SarychUI:T("ui.options_f00ebe5721")) or SarychUI:T("ui.options_f00ebe5721"),
		desc = L and (L["Auras_Description"] or SarychUI:T("ui.options_683a24c4cc")) or SarychUI:T("ui.options_683a24c4cc"),
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = L and (L["General"] or SarychUI:T("ui.general_b250a3d6")) or SarychUI:T("ui.general_b250a3d6"),
				order = 1,
				args = {
					enabled = {
						suiModuleEnable = true,
						type = "toggle",
						name = L and (L["Enable_Module"] or SarychUI:T("ui.enable_module_b623b573")) or SarychUI:T("ui.enable_module_b623b573"),
						desc = "ui.enable_or_disable_the_module_ce99024f",
						order = 1,
						width = "full",
						get = function()
							local db = DB()
							return db and db.enabled == true
						end,
						set = function(_, val)
							local db = DB()
							if not db then return end
							db.enabled = val and true or false
							if val then
								SarychUI:EnableModule(moduleName)
							else
								SarychUI:DisableModule(moduleName)
							end
						end,
					},
				},
			},

			frameAuras = {
				type = "group",
				name = L and (L["Frame Auras"] or SarychUI:T("ui.options_5e97f7923b")) or SarychUI:T("ui.options_5e97f7923b"),
				order = 2,
				disabled = function() return not isEnabled() end,
				args = {
                    frameAuraBlacklist = {
                        type = "group", name = SarychUI:T("ui.visibility.blacklist"), inline = true, order = 10,
                        args = {
                            enabled = {
                                type = "toggle", name = SarychUI:T("ui.enable_a54eaf37"), order = 1,
                                get = function() return DB().frameAuraBlacklistEnabled == true end,
                                set = function(_, value)
                                    DB().frameAuraBlacklistEnabled = value and true or false
                                    module:ApplyBlacklistVisibilitySettings()
                                    if module.consolidationExceptionsWindow then module.consolidationExceptionsWindow:Hide() end
                                    module._playerAuraSlots = nil
                                    if DB().enabled then module:UpdateLayoutHooks() end
                                    module:RefreshAuraLayout()
                                    RefreshConfig()
                                end,
                            },
                            buffs = {
                                type = "execute", name = SarychUI:T("ui.auras.buffs"), order = 2,
                                hidden = function() return not DB().frameAuraBlacklistEnabled end,
                                func = function() module:OpenConsolidationExceptions("frameBuffBlacklist") end,
                            },
                            debuffs = {
                                type = "execute", name = SarychUI:T("ui.auras.debuffs"), order = 3,
                                hidden = function() return not DB().frameAuraBlacklistEnabled end,
                                func = function() module:OpenConsolidationExceptions("frameDebuffBlacklist") end,
                            },
                        },
                    },

					preview = {
						type = "description",
						name = "",
						order = 1,
						width = "full",
						suiPreview = "AurasPreview",
					},

					hideAurasBox = {
						type = "group",
						name = "ui.hide_auras_cb2fefbd",
						order = 2,
						inline = true,
						args = {
							hideTargetAuras = {
								type = "toggle",
								name = "ui.hide_cffffd700target_r_auras_72df384d",
								desc = "ui.hide_auras_on_the_cffffd700target_r_frame_d941c4c1",
								order = 1,
								width = "full",
								suiPreviewKey = "hideTargetAuras",
								get = function()
									return isOn("hideTargetAuras")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.hideTargetAuras = v and 1 or 0
									if module.RefreshAuraLayout then
										module:RefreshAuraLayout()
									end
									if module.ForceUpdateAuras then
										module:ForceUpdateAuras()
									end
									NotifyAurasPreview("hideTargetAuras", v and 1 or 0)
								end,
							},
							hideFocusAuras = {
								type = "toggle",
								name = "ui.hide_cffffd700focus_r_auras_918bc10f",
								desc = "ui.hide_auras_on_the_cffffd700focus_r_frame_9031f385",
								order = 2,
								width = "full",
								get = function()
									return isOn("hideFocusAuras")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.hideFocusAuras = v and 1 or 0
									if module.ForceUpdateAuras then
										module:ForceUpdateAuras()
									end
									NotifyAurasPreview("hideFocusAuras", v and 1 or 0)
								end,
							},
							hideTargetOfTargetAuras = {
								type = "toggle",
								name = "ui.hide_cffffd700target_of_target_r_auras_8b4d30b8",
								desc = "ui.hide_auras_on_the_cffffd700target_of_target_r_fr_e69e25e8",
								order = 3,
								width = "full",
								get = function()
									return isOn("hideTargetOfTargetAuras")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.hideTargetOfTargetAuras = v and 1 or 0
									if module.ForceUpdateAuras then
										module:ForceUpdateAuras()
									end
									NotifyAurasPreview("hideTargetOfTargetAuras", v and 1 or 0)
								end,
							},
						},
					},

					growUpBox = {
						type = "group",
						name = "ui.place_auras_above_the_frame_a3459051",
						order = 2.5,
						inline = true,
						args = {
							frameAurasGrowUp = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.target_and_focus_buffs_and_debuffs_grow_upward_f_060bb2a1",
								order = 1,
								width = "full",
								suiPreviewKey = "frameAurasGrowUp",
								get = function()
									return isOn("frameAurasGrowUp")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.frameAurasGrowUp = v and 1 or 0
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAurasGrowUp", v and 1 or 0)
									RefreshConfig()
								end,
							},
							frameAurasGrowUpY = {
								type = "range",
								name = "ui.y_offset_f7f3fdd7",
								desc = "ui.vertical_offset_of_auras_from_the_top_of_the_fra_67c8c00e",
								min = -40,
								max = 80,
								step = 1,
								order = 2,
								width = "full",
								suiPreviewKey = "frameAurasGrowUpY",
								hidden = function() return not isOn("frameAurasGrowUp") end,
								get = function()
									local db = DB()
									if not db or db.frameAurasGrowUpY == nil then return -17 end
									return db.frameAurasGrowUpY
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.frameAurasGrowUpY = val
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAurasGrowUpY", val)
								end,
							},
						},
					},

					dispelBox = {
						type = "group",
						name = "ui.dispel_highlight_8492a126",
						order = 3,
						inline = true,
						args = {
							enableDispelHighlight = {
								type = "toggle",
								name = "ui.highlight_dispellable_buffs_on_target_focus_54acb02a",
								desc = "ui.highlights_dispellable_buffs_on_target_and_focus_e18eea88",
								order = 1,
								width = "full",
								get = function()
									return isOn("enableDispelHighlight")
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.enableDispelHighlight = val and 1 or 0
									local toolsModule = SarychUI.modules
									if toolsModule and SarychUI.modules.auras.ApplyDispelHighlight then
										SarychUI.modules.auras:ApplyDispelHighlight()
									end
									NotifyAurasPreview("enableDispelHighlight", val and 1 or 0)
								end,
							},
						},
					},

					auraSizeBox = {
						type = "group",
						name = "ui.change_aura_size_cfb1ee58",
						order = 4,
						inline = true,
						args = {
							changeFrameAuraSize = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.enables_buff_and_debuff_size_sliders_on_target_a_94a592d2",
								order = 1,
								width = "full",
								suiPreviewKey = "changeFrameAuraSize",
								get = function()
									return isOn("changeFrameAuraSize")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.changeFrameAuraSize = v and 1 or 0
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("changeFrameAuraSize", v and 1 or 0)
									RefreshConfig()
								end,
							},
							frameAuraOtherSize = {
								type = "range",
								name = "ui.target_aura_size_c6238bfa",
								desc = "ui.size_of_buffs_and_debuffs_on_target_and_focus_fr_fa7f4ea3",
								min = 15, max = 34, step = 1,
								order = 2,
								width = "full",
								suiPreviewKey = "frameAuraOtherSize",
								hidden = function() return not isOn("changeFrameAuraSize") end,
								get = function()
									local db = DB()
									return db and db.frameAuraOtherSize or 23
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.frameAuraOtherSize = val
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAuraOtherSize", val)
								end,
							},
							frameAuraSelfSize = {
								type = "range",
								name = "ui.own_aura_size_961747ec",
								desc = "ui.size_of_buffs_and_debuffs_on_target_and_focus_fr_040d0993",
								min = 15, max = 34, step = 1,
								order = 3,
								width = "full",
								suiPreviewKey = "frameAuraSelfSize",
								hidden = function() return not isOn("changeFrameAuraSize") end,
								get = function()
									local db = DB()
									return db and db.frameAuraSelfSize or 23
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.frameAuraSelfSize = val
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAuraSelfSize", val)
								end,
							},
							frameAuraRowWidth = {
								type = "range",
								name = "ui.aura_row_width_ab46558c",
								desc = "ui.how_many_buffs_fit_in_one_row_on_the_target_fram_d1470f6e",
								min = 108, max = 200, step = 14,
								order = 4,
								width = "full",
								suiPreviewKey = "frameAuraRowWidth",
								hidden = function() return not isOn("changeFrameAuraSize") end,
								get = function()
									local db = DB()
									return db and db.frameAuraRowWidth or 122
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.frameAuraRowWidth = val
									if module.ApplySettings then
										module:ApplySettings()
									end
									NotifyAurasPreview("frameAuraRowWidth", val)
								end,
							},
						},
					},
				},
			},

			characterAuras = {
				type = "group",
				name = L and (L["Character Auras"] or SarychUI:T("ui.options_d283701c45")) or SarychUI:T("ui.options_d283701c45"),
				order = 3,
				disabled = function() return not isEnabled() end,
				args = {
                    playerAuraBlacklist = {
                        type = "group", name = SarychUI:T("ui.visibility.blacklist"), inline = true, order = 3.5,
                        args = {
                            enabled = {
                                type = "toggle", name = SarychUI:T("ui.enable_a54eaf37"), order = 1,
                                get = function() return DB().playerAuraBlacklistEnabled == true end,
                                set = function(_, value)
                                    DB().playerAuraBlacklistEnabled = value and true or false
                                    module:ApplyBlacklistVisibilitySettings()
                                    if module.consolidationExceptionsWindow then module.consolidationExceptionsWindow:Hide() end
                                    module._playerAuraSlots = nil
                                    if DB().enabled then module:UpdateLayoutHooks() end
                                    if BuffFrame_Update then BuffFrame_Update() end
                                    RefreshConfig()
                                end,
                            },
                            buffs = {
                                type = "execute", name = SarychUI:T("ui.auras.buffs"), order = 2,
                                hidden = function() return not DB().playerAuraBlacklistEnabled end,
                                func = function() module:OpenConsolidationExceptions("playerBuffBlacklist") end,
                            },
                            debuffs = {
                                type = "execute", name = SarychUI:T("ui.auras.debuffs"), order = 3,
                                hidden = function() return not DB().playerAuraBlacklistEnabled end,
                                func = function() module:OpenConsolidationExceptions("playerDebuffBlacklist") end,
                            },
                        },
                    },
                    consolidation = {
                        type = "group", name = SarychUI:T("ui.auras.consolidation"), inline = true, order = 4,
                        args = {
                            enabled = {
                                type = "toggle", name = SarychUI:T("ui.enable_a54eaf37"), order = 1,
                                width = "full", suiFullRow = true,
                                desc = SarychUI:T("ui.auras.consolidation_desc"),
                                get = function() return GetCVar("consolidateBuffs") == "1" end,
                                set = function(_, value)
                                    SetCVar("consolidateBuffs", value and "1" or "0", "CONSOLIDATE_BUFFS_TEXT")
                                    module:OnConsolidationCVarUpdate("CVAR_UPDATE", "consolidateBuffs")
                                end,
                            },
                            exceptions = {
                                type = "execute", name = SarychUI:T("ui.options_ea65534c79"), order = 3,
                                desc = SarychUI:T("ui.auras.exceptions_desc"),
                                hidden = function()
                                    local db = DB()
                                    return GetCVar("consolidateBuffs") ~= "1" or not (db and db.consolidateForeignBuffs)
                                end,
                                func = function() module:OpenConsolidationExceptions() end,
                            },
                            foreignOnly = {
                                type = "toggle", name = SarychUI:T("ui.auras.foreign_only"), order = 2,
                                width = "full", suiFullRow = true,
                                desc = SarychUI:T("ui.auras.foreign_only_desc"),
                                hidden = function() return GetCVar("consolidateBuffs") ~= "1" end,
                                get = function() local db = DB(); return db and db.consolidateForeignBuffs == true end,
                                set = function(_, value)
                                    local db = DB(); if not db then return end
                                    db.consolidateForeignBuffs = value and true or false
                                    if not value and module.consolidationExceptionsWindow then module.consolidationExceptionsWindow:Hide() end
                                    if module.UpdateLayoutHooks and db.enabled then module:UpdateLayoutHooks() end
                                    if BuffFrame_Update then BuffFrame_Update() end
                                    RefreshConfig()
                                end,
                            },
                        },
                    },
					buff_management = {
						type = "group",
						name = "ui.change_character_aura_layout_b7eccd72",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							manageBuffs = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.text_36552cd7",
								order = 1,
								width = "full",
								suiFullRow = true,
								get = function()
									return isOn("manageBuffs")
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									db.manageBuffs = value and 1 or 0
									if value then
										ApplyBuffs()
									else
										ClosePlayerAuraDragPanel()
										db.showBuffDragFrame = 0
										db.showBuffGrid = 0
										db.showDebuffDragFrame = 0
										db.showDebuffGrid = 0
										if module.ResetBuffManagement then
											module:ResetBuffManagement()
										end
									end
									RefreshConfig()
								end,
							},
							playerAuraPositionMode = {
								type = "select",
								name = "ui.position_a70a9ff4",
								desc = "ui.text_46871c6e",
								order = 2,
								width = "full",
								suiFullRow = true,
								values = {
									together = SarychUI:T("ui.options_11688c1649"),
									separate = SarychUI:T("ui.options_c47561fc0e"),
									__order = { "together", "separate" },
								},
								hidden = function() return not isOn("manageBuffs") end,
								get = function()
									local db = DB()
									return db and db.playerAuraPositionMode or "together"
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									ClosePlayerAuraDragPanel()
									db.showBuffDragFrame = 0
									db.showBuffGrid = 0
									db.showDebuffDragFrame = 0
									db.showDebuffGrid = 0
									db.playerAuraPositionMode = value == "separate" and "separate" or "together"
									ApplyBuffs()
									RefreshConfig()
								end,
							},
							buffFrameX = {
								type = "range",
								name = "ui.x_offset_0b923c73",
								desc = "ui.text_a997b839",
								min = -5000,
								max = 5000,
								step = 1,
								order = 3,
								get = function()
									local db = DB()
									return db and db.buffFrameX or -205
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.buffFrameX = val
									ApplyBuffs()
								end,
								hidden = function()
									return not isOn("manageBuffs") or SeparatePlayerAuras()
								end,
							},
							buffFrameY = {
								type = "range",
								name = "ui.y_offset_f7f3fdd7",
								desc = "ui.text_a7f24ee5",
								min = -5000,
								max = 5000,
								step = 1,
								order = 4,
								get = function()
									local db = DB()
									return db and db.buffFrameY or -13
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.buffFrameY = val
									ApplyBuffs()
								end,
								hidden = function()
									return not isOn("manageBuffs") or SeparatePlayerAuras()
								end,
							},
							buffFrameScale = {
								type = "range",
								name = "ui.scale_e037e967",
								desc = "ui.text_063ea4a3",
								min = 0.5,
								max = 2.0,
								step = 0.05,
								order = 6,
								width = "full",
								suiFullRow = true,
								get = function()
									local db = DB()
									return db and db.buffFrameScale or 1.0
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.buffFrameScale = val
									ApplyBuffs()
								end,
								hidden = function()
									return not isOn("manageBuffs") or SeparatePlayerAuras()
								end,
							},
							playerAuraGrowthDirection = {
								type = "select",
								name = "ui.text_d6f132e5",
								desc = "ui.text_e1bbd340",
								order = 5,
								width = "full",
								suiFullRow = true,
								values = PLAYER_AURA_GROWTH_VALUES,
								hidden = function()
									return not isOn("manageBuffs") or SeparatePlayerAuras()
								end,
								get = function()
									local db = DB()
									return db and db.playerAuraGrowthDirection or "right_to_left"
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									db.playerAuraGrowthDirection = value == "left_to_right" and "left_to_right" or "right_to_left"
									ApplyBuffs()
								end,
							},
							showBuffDragFrame = {
								type = "execute",
								name = function()
									if isOn("showBuffDragFrame") then
										return SarychUI:T("ui.options_76e4992833")
									end
									return SarychUI:T("ui.options_0510004a87")
								end,
								desc = "ui.text_a56dd277",
								order = 7,
								width = "full",
								suiFullRow = true,
								func = function() TogglePlayerAuraDrag("buffFrame", "showBuffDragFrame", "showBuffGrid") end,
								suiResetDefaults = function()
									ResetPlayerAuraDefaults("buffFrame", "buffFrameX", "buffFrameY", -205, -13, "playerAuraGrowthDirection", "buffFrameScale")
								end,
								hidden = function()
									return not isOn("manageBuffs") or SeparatePlayerAuras()
								end,
							},
							separateBuffs = {
								type = "group",
								name = "ui.text_24a8a936",
								order = 10,
								inline = true,
								suiTwoCol = true,
								hidden = function() return not isOn("manageBuffs") or not SeparatePlayerAuras() end,
								args = {
									buffX = {
										type = "range", name = "ui.x_offset_0b923c73",
										desc = "ui.text_39fe3855",
										min = -5000, max = 5000, step = 1, order = 1,
										get = function() local db = DB(); return db and db.buffFrameX or -205 end,
										set = function(_, val) local db = DB(); if not db then return end; db.buffFrameX = val; ApplyBuffs() end,
									},
									buffY = {
										type = "range", name = "ui.y_offset_f7f3fdd7",
										desc = "ui.text_7f680edb",
										min = -5000, max = 5000, step = 1, order = 2,
										get = function() local db = DB(); return db and db.buffFrameY or -13 end,
										set = function(_, val) local db = DB(); if not db then return end; db.buffFrameY = val; ApplyBuffs() end,
									},
									buffScale = {
										type = "range", name = "ui.scale_e037e967",
										desc = "ui.text_7d7cdfe6",
										min = 0.5, max = 2.0, step = 0.05, order = 4,
										width = "full", suiFullRow = true,
										get = function() local db = DB(); return db and db.buffFrameScale or 1.0 end,
										set = function(_, val) local db = DB(); if not db then return end; db.buffFrameScale = val; ApplyBuffs() end,
									},
									buffGrowthDirection = {
										type = "select", name = "ui.text_d6f132e5",
										desc = "ui.text_68ffc289",
										order = 3, width = "full", suiFullRow = true,
										values = PLAYER_AURA_GROWTH_VALUES,
										get = function()
											local db = DB()
											return db and db.playerBuffGrowthDirection or "right_to_left"
										end,
										set = function(_, value)
											local db = DB(); if not db then return end
											db.playerBuffGrowthDirection = value == "left_to_right" and "left_to_right" or "right_to_left"
											ApplyBuffs()
										end,
									},
									buffDrag = {
										type = "execute",
										name = function()
											return isOn("showBuffDragFrame") and SarychUI:T("ui.options_76e4992833") or SarychUI:T("ui.options_0510004a87")
										end,
										desc = "ui.text_afcbea71",
										order = 5, width = "full", suiFullRow = true,
										func = function() TogglePlayerAuraDrag("buffFrame", "showBuffDragFrame", "showBuffGrid") end,
										suiResetDefaults = function()
											ResetPlayerAuraDefaults("buffFrame", "buffFrameX", "buffFrameY", -205, -13, "playerBuffGrowthDirection", "buffFrameScale")
										end,
									},
								},
							},
							separateDebuffs = {
								type = "group",
								name = "ui.text_4942ad78",
								order = 11,
								inline = true,
								suiTwoCol = true,
								hidden = function() return not isOn("manageBuffs") or not SeparatePlayerAuras() end,
								args = {
									debuffX = {
										type = "range", name = "ui.x_offset_0b923c73",
										desc = "ui.text_43288cb5",
										min = -5000, max = 5000, step = 1, order = 1,
										get = function() local db = DB(); return db and db.debuffFrameX or -205 end,
										set = function(_, val) local db = DB(); if not db then return end; db.debuffFrameX = val; ApplyBuffs() end,
									},
									debuffY = {
										type = "range", name = "ui.y_offset_f7f3fdd7",
										desc = "ui.text_185072e4",
										min = -5000, max = 5000, step = 1, order = 2,
										get = function() local db = DB(); return db and db.debuffFrameY or -105 end,
										set = function(_, val) local db = DB(); if not db then return end; db.debuffFrameY = val; ApplyBuffs() end,
									},
									debuffScale = {
										type = "range", name = "ui.scale_e037e967",
										desc = "ui.text_f7255d5f",
										min = 0.5, max = 2.0, step = 0.05, order = 4,
										width = "full", suiFullRow = true,
										get = function() local db = DB(); return db and db.debuffFrameScale or 1.0 end,
										set = function(_, val) local db = DB(); if not db then return end; db.debuffFrameScale = val; ApplyBuffs() end,
									},
									debuffGrowthDirection = {
										type = "select", name = "ui.text_d6f132e5",
										desc = "ui.text_00cfa448",
										order = 3, width = "full", suiFullRow = true,
										values = PLAYER_AURA_GROWTH_VALUES,
										get = function()
											local db = DB()
											return db and db.playerDebuffGrowthDirection or "right_to_left"
										end,
										set = function(_, value)
											local db = DB(); if not db then return end
											db.playerDebuffGrowthDirection = value == "left_to_right" and "left_to_right" or "right_to_left"
											ApplyBuffs()
										end,
									},
									debuffDrag = {
										type = "execute",
										name = function()
											return isOn("showDebuffDragFrame") and SarychUI:T("ui.options_76e4992833") or SarychUI:T("ui.options_0510004a87")
										end,
										desc = "ui.text_f5b5f122",
										order = 5, width = "full", suiFullRow = true,
										func = function() TogglePlayerAuraDrag("debuffFrame", "showDebuffDragFrame", "showDebuffGrid") end,
										suiResetDefaults = function()
											ResetPlayerAuraDefaults("debuffFrame", "debuffFrameX", "debuffFrameY", -205, -105, "playerDebuffGrowthDirection", "debuffFrameScale")
										end,
									},
								},
							},
						},
					},
					buffRowBox = {
						type = "group",
						name = "ui.change_auras_per_row_85ba23af",
						order = 2,
						inline = true,
						args = {
							changePlayerBuffRow = {
								type = "toggle",
								name = "ui.enable_a54eaf37",
								desc = "ui.how_many_auras_to_show_in_one_row_on_the_player__ad6458a4",
								order = 1,
								width = "full",
								get = function()
									return isOn("changePlayerBuffRow")
								end,
								set = function(_, v)
									local db = DB(); if not db then return end
									db.changePlayerBuffRow = v and 1 or 0
									if module.ApplySettings then
										module:ApplySettings()
									end
									RefreshConfig()
								end,
							},
							playerBuffsPerRow = {
								type = "range",
								name = "ui.auras_per_row_dc3844a7",
								desc = "ui.how_many_auras_to_show_in_one_row_on_the_player__ad6458a4",
								min = 1, max = 10, step = 1,
								order = 2,
								width = "full",
								hidden = function() return not isOn("changePlayerBuffRow") end,
								get = function()
									local db = DB()
									return db and db.playerBuffsPerRow or 8
								end,
								set = function(_, val)
									local db = DB(); if not db then return end
									db.playerBuffsPerRow = val
									if module.ApplySettings then
										module:ApplySettings()
									end
								end,
							},
						},
					},
					poisonIconsBox = {
						type = "group",
						name = L and (L["Poison Icons"] or SarychUI:T("ui.options_a7407e4f3b")) or SarychUI:T("ui.options_a7407e4f3b"),
						desc = L and (L["Added by suggestion: Hannahmckay"] or SarychUI:T("ui.options_5ab82ee598")) or SarychUI:T("ui.options_5ab82ee598"),
						order = 3,
						inline = true,
						suiHelpIcon = true,
						args = {
							showPoisonIcons = {
								type = "toggle",
								name = L and (L["Enable"] or SarychUI:T("ui.enable_a54eaf37")) or SarychUI:T("ui.enable_a54eaf37"),
								desc = L and (L["Poison Icons Desc"] or SarychUI:T("ui.options_725f58bb8e")) or SarychUI:T("ui.options_725f58bb8e"),
								order = 1,
								width = "full",
								get = function()
									return isOn("showPoisonIcons")
								end,
								set = function(_, value)
									local db = DB(); if not db then return end
									db.showPoisonIcons = value and 1 or 0
									if module.ApplyPoisonIcons then
										module:ApplyPoisonIcons()
									end
									RefreshConfig()
								end,
							},
						},
					},
				},
			},
		},
	}
end
