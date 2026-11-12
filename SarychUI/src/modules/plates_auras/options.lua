-- SarychUI Plates Auras Module Options

local format = string.format

local moduleName = "plates_auras"
local L = SarychUI.L

-- Get module
local module = SarychUI:GetModule(moduleName)
if not module then return end

-- Check if Ace3 is available
if not LibStub or not LibStub("AceConfig-3.0", true) then
	return
end

-- Full refresh (enable/init/system toggles only)
local function RefreshModule()
	if module and module.ApplySettings then
		module:ApplySettings()
	end
end

local function OnDisplaySetting(key, value)
	if module.OnAuraDisplaySettingChanged then
		module:OnAuraDisplaySettingChanged(key, value)
	end
end


local function OnLayoutSetting(section, key, value)
	local dragging = SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging()
	if module.OnAuraLayoutSettingChanged then
		module:OnAuraLayoutSettingChanged(section, key, value)
	end
	-- Preview already follows via SetLiveValue/LayoutLive while dragging.
	if dragging then
		return
	end
	local preview = SarychUI.PlatesAurasLayoutPreview
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

local function OnDisplaySettingPreview(key, value)
	local dragging = SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging()
	OnDisplaySetting(key, value)
	if dragging then
		return
	end
	local preview = SarychUI.PlatesAurasLayoutPreview
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

local function GetProfileModeLabel()
	local mode = module.GetActiveProfileMode and module:GetActiveProfileMode() or "classic"
	if mode == "elvui" then
		return L and (L["ElvUI Nameplates"] or SarychUI:T("ui.options_e75dd9a064")) or SarychUI:T("ui.options_e75dd9a064")
	end
	return L and (L["Classic WoW Nameplates"] or "Classic WoW") or "Classic WoW"
end

local function ProfileModeInfoText()
	local mode = module.GetActiveProfileMode and module:GetActiveProfileMode() or "classic"
	local modeLabel = GetProfileModeLabel()
	-- ElvUI mode: same green as «Обнаружен»; classic stays gold.
	local modeColor = (mode == "elvui") and "|cff00ff00" or "|cFFFFD700"
	local coloredMode = modeColor .. tostring(modeLabel) .. "|r"
	return SarychUI:T("ui.options_a5fe99b009") .. coloredMode
end

local function LayoutPreviewOpt(tab)
	return {
		type = "description",
		name = " ",
		order = 0,
		width = "full",
		suiLayoutPreview = tab or "sizes",
		suiLayoutPreviewNotice = ProfileModeInfoText,
	}
end

local function OnDataSetting(spellID, field, value)
	if module.OnAuraDataSettingChanged then
		module:OnAuraDataSettingChanged(spellID, field, value)
	end
end

local function DisplayProfile()
	if module.EnsureProfiles then
		module:EnsureProfiles()
	end
	if module.GetActiveDisplayProfile then
		return module:GetActiveDisplayProfile()
	end
	return nil
end

local function ProfileSizes()
	local profile = DisplayProfile()
	if not profile then return {} end
	profile.sizes = profile.sizes or {}
	return profile.sizes
end

local function ProfilePositions()
	local profile = DisplayProfile()
	if not profile then return {} end
	profile.positions = profile.positions or {}
	return profile.positions
end

local function ProfileDisplay()
	local profile = DisplayProfile()
	if not profile then return {} end
	profile.display = profile.display or {}
	return profile.display
end

local function ProfileLayoutPlayer()
	local profile = DisplayProfile()
	if not profile then return {} end
	profile.layout = profile.layout or {}
	profile.layout.player = profile.layout.player or {}
	return profile.layout.player
end

local function IsElvUIProfileMode()
	return (module.GetActiveProfileMode and module:GetActiveProfileMode()) == "elvui"
end

local function ProfileLayoutSlot(slotName)
	local profile = DisplayProfile()
	if not profile then return {} end
	profile.layout = profile.layout or {}
	profile.layout[slotName] = profile.layout[slotName] or {}
	return profile.layout[slotName]
end

local function RefreshOptionsDisabledState()
	-- Options window re-evaluates dependents after every set on its own; this is
	-- only kept for paths that write the profile outside a set handler.
	if SarychUI and SarychUI.NotifySarychUIOptionsChange then
		SarychUI:NotifySarychUIOptionsChange()
	elseif SarychUI and SarychUI.RefreshConfig then
		SarychUI:RefreshConfig()
	end
end

local GLOW_DEFAULTS = (SarychUI.PlatesAurasGlow and SarychUI.PlatesAurasGlow.defaults) or {
	glowType = "border",
	useGlowColor = false,
	glowLines = 8,
	glowFrequency = 0.25,
	glowLength = 10,
	glowThickness = 1,
	glowScale = 1,
	glowBorder = false,
	glowXOffset = 0,
	glowYOffset = 0,
}

local GLOW_TYPE_VALUES = {
	border = "ui.options_bc95a266c9",
	ACShine = "ui.options_a7997a24f2",
	Pixel = "ui.options_9037862e2c",
	buttonOverlay = "ui.options_322e460afc",
	proc = "ui.cooldowns.proc_glow",
	__order = { "border", "ACShine", "Pixel", "buttonOverlay", "proc" },
}

local function SpellOverride(spellID)
	local db = SarychUI.db.profile.modules[moduleName]
	db.spells = db.spells or {}
	if not db.spells[spellID] then
		db.spells[spellID] = {}
	end
	return db.spells[spellID]
end

local function IsSpellHighlightOn(spellID, spell)
	local db = SarychUI.db.profile.modules[moduleName]
	local spellDb = db.spells and db.spells[spellID]
	if spellDb and spellDb.highlight ~= nil then
		return spellDb.highlight ~= false and spellDb.highlight ~= 0
	end
	return spell.highlight ~= nil and spell.highlight ~= false and spell.highlight ~= 0
end

local function GetSpellGlowField(spellID, spell, field)
	local db = SarychUI.db.profile.modules[moduleName]
	local spellDb = db.spells and db.spells[spellID]
	if spellDb and spellDb[field] ~= nil then
		return spellDb[field]
	end
	if spell and spell[field] ~= nil then
		return spell[field]
	end
	return GLOW_DEFAULTS[field]
end

local function SetSpellGlowField(spellID, field, value, refresh)
	local spellDb = SpellOverride(spellID)
	spellDb[field] = value
	OnDataSetting(spellID, field, value)
	if refresh then
		RefreshOptionsDisabledState()
	end
end

local function GetSpellGlowType(spellID, spell)
	return GetSpellGlowField(spellID, spell, "glowType") or "border"
end

local function OnLayoutSlotSetting(slotName, key, value)
	local slot = ProfileLayoutSlot(slotName)
	slot[key] = value
	OnLayoutSetting("layout", slotName .. "." .. key, value)
	-- offsetMode toggles lock/unlock sibling factor sliders.
	if key == "offsetMode" then
		RefreshOptionsDisabledState()
	end
end

-- Center-only: grow CC/cast icons when ElvUI plate scale changes.
local RESPONSIVE_SCALE_DEFAULTS = {
	center = { enabled = true, factor = 0.55, maxBonus = 0.20 },
}

local function ProfileResponsiveScale(slotName)
	local profile = DisplayProfile()
	if not profile then return {} end
	profile.plateResponsiveScale = profile.plateResponsiveScale or {}
	local defaults = RESPONSIVE_SCALE_DEFAULTS[slotName]
	local cfg = profile.plateResponsiveScale[slotName]
	if type(cfg) ~= "table" then
		cfg = {}
		profile.plateResponsiveScale[slotName] = cfg
	end
	if defaults then
		if cfg.enabled == nil then cfg.enabled = defaults.enabled end
		if cfg.factor == nil then cfg.factor = defaults.factor end
		if cfg.maxBonus == nil then cfg.maxBonus = defaults.maxBonus end
	end
	return cfg
end

local function ResponsiveScaleValue(slotName, key)
	local cfg = ProfileResponsiveScale(slotName)
	local value = cfg[key]
	if value ~= nil then
		return value
	end
	local defaults = RESPONSIVE_SCALE_DEFAULTS[slotName]
	return defaults and defaults[key]
end

local function OnResponsiveScaleSetting(slotName, key, value)
	local cfg = ProfileResponsiveScale(slotName)
	cfg[key] = value
	OnLayoutSetting("plateResponsiveScale", slotName .. "." .. key, value)
end

local function IsSlotProportional(slotName)
	return ProfileLayoutSlot(slotName).offsetMode == "proportional"
end

-- Hook AceConfigDialog to remove character limit from EditBox inputs
local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
if AceConfigDialog then
	-- Hook the creation of input controls
	local originalBuildGroup = AceConfigDialog.BuildGroup
	if originalBuildGroup then
		local function BuildGroupHook(self, group, parent, options, path, appName)
			local result = originalBuildGroup(self, group, parent, options, path, appName)
			-- After building, find all EditBox controls and remove character limit
			if result and result.children then
				for i = 1, #result.children do
					local child = result.children[i]
					if child and child.type == "EditBox" and child.editbox then
						-- Remove character limit (0 means unlimited)
						child.editbox:SetMaxBytes(0)
						child.editbox:SetMaxLetters(0)
					end
				end
			end
			return result
		end
		AceConfigDialog.BuildGroup = BuildGroupHook
	end
end

-- Spell type order (matching BigDebuffs structure)
local order = {
	immunities = 1,
	cc = 2,
	silence = 3,
	interrupts = 4,
	roots = 5,
	disarm = 6,
	buffs_defensive = 7,
	buffs_offensive = 8,
	buffs_other = 9,
	snare = 10,
	cast = 11,
	other = 12,
}

-- Localized spell type names
local typeNames = {
	immunities = L and (L["immunities"] or "immunities") or "immunities",
	cc = L and (L["cc"] or "cc") or "cc",
	silence = L and (L["silence"] or "silence") or "silence",
	interrupts = L and (L["interrupts"] or "interrupts") or "interrupts",
	roots = L and (L["roots"] or "roots") or "roots",
	disarm = L and (L["disarm"] or "disarm") or "disarm",
	buffs_defensive = L and (L["buffs_defensive"] or "buffs_defensive") or "buffs_defensive",
	buffs_offensive = L and (L["buffs_offensive"] or "buffs_offensive") or "buffs_offensive",
	buffs_other = L and (L["buffs_other"] or "buffs_other") or "buffs_other",
	snare = L and (L["snare"] or "snare") or "snare",
	cast = L and (L["cast"] or "cast") or "cast",
	other = L and (L["other"] or "other") or "other",
}

-- Cache spell names and icons
local SpellNames = {}
local SpellIcons = {}

-- Build spells configuration table (similar to BigDebuffs)
-- This function rebuilds the structure dynamically
local function BuildSpells()
	local Spells = {}
	local spellData = module:GetSpellData() or {}
	
	for spellID, spell in pairs(spellData) do
		if type(spell) == "table" and spell.type then
			-- Create group for spell type if not exists
			Spells[spell.type] = Spells[spell.type] or {
				name = typeNames[spell.type] or spell.type,
				type = "group",
				order = order[spell.type] or 100,
				args = {},
			}
			
			-- Create spell entry
			local key = "spell" .. spellID
			Spells[spell.type].args[key] = {
				type = "group",
				get = function(info)
					local name = info[#info]
					local db = SarychUI.db.profile.modules[moduleName]
					return db.spells[spellID] and db.spells[spellID][name]
				end,
				set = function(info, value)
					local name = info[#info]
					local db = SarychUI.db.profile.modules[moduleName]
					if not db.spells[spellID] then
						db.spells[spellID] = {}
					end
					db.spells[spellID][name] = value
					OnDataSetting(spellID, name, value)
				end,
				name = function(info)
					local name = SpellNames[spellID]
					if not name then
						name = GetSpellInfo(spellID) or ("ID " .. spellID)
						SpellNames[spellID] = name
					end
					return name
				end,
				icon = function()
					local icon = SpellIcons[spellID]
					if not icon then
						icon = select(3, GetSpellInfo(spellID))
						SpellIcons[spellID] = icon
					end
					return icon
				end,
				desc = function()
					return "|cffFFD100Spell ID: |r" .. spellID
				end,
				args = {
					-- Top-level so two-pane detail lifts it to the title «Включить».
					-- Own get/set: custom /sui UI does not inherit parent group handlers.
					enabled = {
						type = "toggle",
						name = L and (L["Enabled"] or SarychUI:T("ui.enable_a54eaf37")) or SarychUI:T("ui.enable_a54eaf37"),
						desc = L and (L["Show this spell on nameplates"] or SarychUI:T("ui.options_66b639a969")) or SarychUI:T("ui.options_66b639a969"),
						width = "normal",
						order = 1,
						get = function()
							local db = SarychUI.db.profile.modules[moduleName]
							local spellDb = db.spells and db.spells[spellID]
							local value
							if spellDb and spellDb.enabled ~= nil then
								value = spellDb.enabled
							else
								value = spell.enabled
							end
							if value == nil then
								return true
							end
							return value ~= false and value ~= 0
						end,
						set = function(_, value)
							local db = SarychUI.db.profile.modules[moduleName]
							db.spells = db.spells or {}
							if not db.spells[spellID] then
								db.spells[spellID] = {}
							end
							local on = (value == true or value == 1)
							db.spells[spellID].enabled = on
							OnDataSetting(spellID, "enabled", on)
						end,
					},
					type = {
						type = "group",
						inline = true,
						name = L and (L["Spell Type"] or SarychUI:T("ui.spell_type_a8e05dbc")) or SarychUI:T("ui.spell_type_a8e05dbc"),
						args = {
							type = {
								name = L and (L["Type"] or SarychUI:T("ui.type_d4a6795c")) or SarychUI:T("ui.type_d4a6795c"),
								type = "select",
								order = 1,
								values = typeNames,
								get = function()
									local db = SarychUI.db.profile.modules[moduleName]
									return (db.spells[spellID] and db.spells[spellID].type) or spell.type or "other"
								end,
								set = function(info, value)
									local db = SarychUI.db.profile.modules[moduleName]
									if not db.spells[spellID] then
										db.spells[spellID] = {}
									end
									db.spells[spellID].type = value
									OnDataSetting(spellID, "type", value)
								end,
							},
						},
					},
					priority = {
						type = "group",
						inline = true,
						name = L and (L["Spell Priority"] or SarychUI:T("ui.options_f7d08f1402")) or SarychUI:T("ui.options_f7d08f1402"),
						args = {
							customPriority = {
								name = L and (L["Custom Priority"] or SarychUI:T("ui.options_11a48e654b")) or SarychUI:T("ui.options_11a48e654b"),
								type = "toggle",
								order = 1,
								get = function()
									local db = SarychUI.db.profile.modules[moduleName]
									return db.spells[spellID] and db.spells[spellID].customPriority or false
								end,
								set = function(info, value)
									local db = SarychUI.db.profile.modules[moduleName]
									if not db.spells[spellID] then
										db.spells[spellID] = {}
									end
									db.spells[spellID].customPriority = value
									if not value then
										db.spells[spellID].priority = nil
									end
									OnDataSetting(spellID, "customPriority", value)
								end,
							},
							priority = {
								name = L and (L["Priority"] or SarychUI:T("ui.options_b5b6ddbf62")) or SarychUI:T("ui.options_b5b6ddbf62"),
								desc = L and (L["Higher priority spells will take precedence regardless of duration"] or SarychUI:T("ui.options_4638a5102c")) or SarychUI:T("ui.options_4638a5102c"),
								type = "range",
								min = 1,
								max = 999,
								step = 1,
								order = 2,
								disabled = function()
									local db = SarychUI.db.profile.modules[moduleName]
									return not db.spells[spellID] or not db.spells[spellID].customPriority
								end,
								get = function()
									local db = SarychUI.db.profile.modules[moduleName]
									-- Use custom priority if set, otherwise use default from spell data
									return (db.spells[spellID] and db.spells[spellID].priority) or spell.priority or 1
								end,
								set = function(info, value)
									local db = SarychUI.db.profile.modules[moduleName]
									if not db.spells[spellID] then
										db.spells[spellID] = {}
									end
									db.spells[spellID].priority = value
									db.spells[spellID].customPriority = true
									OnDataSetting(spellID, "priority", value)
								end,
							},
						},
					},
					highlight = {
						type = "group",
						inline = true,
						name = "ui.glow_a4d6b553",
						suiTwoCol = true,
						args = {
							enabled = {
								name = "ui.show_glow_66edb6d2",
								desc = "ui.show_a_glow_on_this_spell_s_icon_ef0abc3a",
								type = "toggle",
								order = 1,
								get = function()
									return IsSpellHighlightOn(spellID, spell)
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "highlight", value and 1 or 0, true)
								end,
							},
							glowType = {
								name = "ui.type_d4a6795c",
								type = "select",
								order = 2,
								values = GLOW_TYPE_VALUES,
								get = function()
									return GetSpellGlowType(spellID, spell)
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowType", value, true)
								end,
							},
							useGlowColor = {
								name = "ui.use_custom_color_007e9eca",
								desc = "ui.if_unchecked_the_default_color_is_used_usually_y_063d6364",
								type = "toggle",
								order = 3,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									return GetSpellGlowType(spellID, spell) == "border"
								end,
								get = function()
									return GetSpellGlowField(spellID, spell, "useGlowColor") and true or false
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "useGlowColor", value and true or false, true)
								end,
							},
							color = {
								name = "ui.color_92ab62ad",
								desc = "ui.glow_color_and_opacity_opens_the_standard_color__7cf23acb",
								type = "color",
								hasAlpha = true,
								order = 4,
								hidden = function()
									return not IsSpellHighlightOn(spellID, spell)
								end,
								disabled = function()
									if GetSpellGlowType(spellID, spell) == "border" then
										return false
									end
									return not GetSpellGlowField(spellID, spell, "useGlowColor")
								end,
								get = function()
									local named = {
										blue = {0, 0.2, 0.5, 1},
										gold = {0.8, 0.6, 0.2, 1},
										purple = {0.6, 0, 1.0, 1},
										green = {0.1, 0.6, 0.1, 1},
									}
									local db = SarychUI.db.profile.modules[moduleName]
									local spellDb = db.spells[spellID]
									local hc = (spellDb and spellDb.highlightColor) or spell.highlightColor
									if type(hc) == "table" then
										if type(hc[1]) == "number" then
											return hc[1], hc[2] or 0.2, hc[3] or 0.5, hc[4] or 1
										end
										if type(hc.r) == "number" then
											return hc.r, hc.g or 0.2, hc.b or 0.5, hc.a or 1
										end
									elseif type(hc) == "string" and named[hc] then
										local c = named[hc]
										return c[1], c[2], c[3], c[4]
									end
									return 0, 0.2, 0.5, 1
								end,
								set = function(_, r, g, b, a)
									SetSpellGlowField(spellID, "highlightColor", { r or 0, g or 0.2, b or 0.5, a or 1 })
								end,
							},
							glowLines = {
								name = "ui.lines_or_particles_f8c2a0e0",
								type = "range",
								order = 5,
								min = 1,
								max = 30,
								step = 1,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									local glowType = GetSpellGlowType(spellID, spell)
									return glowType == "buttonOverlay" or glowType == "border" or glowType == "proc"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowLines")) or 8
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowLines", value)
								end,
							},
							glowFrequency = {
								name = "ui.frequency_913df43b",
								type = "range",
								order = 6,
								min = -2,
								max = 2,
								step = 0.05,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									local glowType = GetSpellGlowType(spellID, spell)
									return glowType == "buttonOverlay" or glowType == "border" or glowType == "proc"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowFrequency")) or 0.25
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowFrequency", value)
								end,
							},
							glowLength = {
								name = "ui.length_f3954de2",
								type = "range",
								order = 7,
								min = 1,
								max = 20,
								step = 0.05,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									return GetSpellGlowType(spellID, spell) ~= "Pixel"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowLength")) or 10
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowLength", value)
								end,
							},
							glowThickness = {
								name = "ui.thickness_3c149a80",
								type = "range",
								order = 8,
								min = 0.05,
								max = 20,
								step = 0.05,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									return GetSpellGlowType(spellID, spell) ~= "Pixel"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowThickness")) or 1
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowThickness", value)
								end,
							},
							glowXOffset = {
								name = "ui.x_offset_0b923c73",
								type = "range",
								order = 9,
								min = -100,
								max = 100,
								step = 0.5,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									local glowType = GetSpellGlowType(spellID, spell)
									return glowType == "buttonOverlay" or glowType == "border" or glowType == "proc"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowXOffset")) or 0
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowXOffset", value)
								end,
							},
							glowYOffset = {
								name = "ui.y_offset_f7f3fdd7",
								type = "range",
								order = 10,
								min = -100,
								max = 100,
								step = 0.5,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									local glowType = GetSpellGlowType(spellID, spell)
									return glowType == "buttonOverlay" or glowType == "border" or glowType == "proc"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowYOffset")) or 0
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowYOffset", value)
								end,
							},
							glowScale = {
								name = "ui.scale_e037e967",
								type = "range",
								order = 11,
								min = 0.05,
								max = 10,
								step = 0.05,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									return GetSpellGlowType(spellID, spell) ~= "ACShine"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowScale")) or 1
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowScale", value)
								end,
							},
							glowBorder = {
								name = "ui.border_6eeed8a0",
								type = "toggle",
								order = 12,
								hidden = function()
									if not IsSpellHighlightOn(spellID, spell) then
										return true
									end
									return GetSpellGlowType(spellID, spell) ~= "Pixel"
								end,
								get = function()
									return GetSpellGlowField(spellID, spell, "glowBorder") and true or false
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowBorder", value and true or false)
								end,
							},
						},
					},
					allowFromOthers = {
						type = "group",
						inline = true,
						name = L and (L["Allow from Other Players"] or SarychUI:T("ui.options_d784ec939b")) or SarychUI:T("ui.options_d784ec939b"),
						hidden = function()
							local db = SarychUI.db.profile.modules[moduleName]
							local currentType = (db.spells[spellID] and db.spells[spellID].type) or spell.type or "other"
							return currentType ~= "other"
						end,
						args = {
							enabled = {
								name = L and (L["Allow from Other Players"] or SarychUI:T("ui.options_d784ec939b")) or SarychUI:T("ui.options_d784ec939b"),
								desc = L and (L["Allow this spell to be displayed in 'other' category even if cast by other players"] or SarychUI:T("ui.options_2fbdc8d396")) or SarychUI:T("ui.options_2fbdc8d396"),
								type = "toggle",
								order = 1,
								get = function()
									local db = SarychUI.db.profile.modules[moduleName]
									return db.spells[spellID] and db.spells[spellID].allowFromOthers == true
								end,
								set = function(info, value)
									local db = SarychUI.db.profile.modules[moduleName]
									if not db.spells[spellID] then
										db.spells[spellID] = {}
									end
									db.spells[spellID].allowFromOthers = value
									OnDataSetting(spellID, "allowFromOthers", value)
								end,
							},
						},
					},
					remove = {
						type = "group",
						inline = true,
						name = L and (L["Remove Spell"] or SarychUI:T("ui.options_f45839d47b")) or SarychUI:T("ui.options_f45839d47b"),
						order = 999,
						args = {
							removeButton = {
								name = L and (L["Remove Spell"] or SarychUI:T("ui.options_f45839d47b")) or SarychUI:T("ui.options_f45839d47b"),
								desc = L and (L["Remove this spell from the list"] or SarychUI:T("ui.options_caf17335ee")) or SarychUI:T("ui.options_caf17335ee"),
								type = "execute",
								order = 1,
								width = "full",
								confirm = function()
									local spellName = GetSpellInfo(spellID) or ("ID " .. spellID)
									return format(L and (L["Are you sure you want to remove %s?"] or SarychUI:T("ui.options_063f16be19")) or SarychUI:T("ui.options_063f16be19"), spellName)
								end,
								func = function()
									local spellName = GetSpellInfo(spellID) or ("ID " .. spellID)
									local success, message = module:RemoveSpell(spellID)
									if not success then
										print(SarychUI:T("ui.options_f429c3179b") .. (message or SarychUI:T("ui.options_1047bb7bef")))
										return
									end
									print(SarychUI:T("ui.options_9912d87de8") .. spellName .. " (ID: " .. spellID .. ")")
									RefreshModule()
									-- Same path as adding a spell: GetOptions() rebuilds the list.
									if SarychUI.RebuildModuleOptions then
										SarychUI:RebuildModuleOptions(moduleName)
									elseif SarychUI.NotifySarychUIOptionsChange then
										SarychUI:NotifySarychUIOptionsChange()
									end
								end,
							},
						},
					},
				},
		}  -- End of Spells[spell.type].args[key]
		end  -- End of if type(spell) == "table" and spell.type then
	end  -- End of for spellID, spell in pairs(spellData) do
	
	return Spells
end  -- End of function BuildSpells()

-- Module options
function module:GetOptions()
	local testModeOpt = {
		type = "execute",
		name = function()
			local db = SarychUI.db.profile.modules[moduleName]
			return SarychUI:T(db and db.testModeEnabled
				and "ui.options_2aa205e3d3" or "ui.options_ec1868c5a7")
		end,
		desc = "ui.show_random_icons_on_nearby_existing_nameplates__c2e599f3",
		func = function()
			local db = SarychUI.db.profile.modules[moduleName]
			if not db then return end
			local value = not db.testModeEnabled
			db.testModeEnabled = value
			if value then
				module:StartTestMode()
			else
				module:StopTestMode()
			end
			SarychUI:NotifySarychUIOptionsChange()
		end,
		disabled = function()
			return not (SarychUI.db.profile.modules[moduleName] and SarychUI.db.profile.modules[moduleName].enabled)
		end,
		hidden = function()
			return not (SarychUI.db.profile.modules[moduleName] and SarychUI.db.profile.modules[moduleName].enabled)
		end,
	}

	return {
		type = "group",
		name = "|TInterface\\AddOns\\SarychUI\\media\\components\\modules\\nameplates\\engines\\elvui\\Media\\Textures\\nameplates:20:20:0:0:256:128:0:38:45:81|t " .. (L and (L["Plates Auras"] or SarychUI:T("ui.options_c1d832336d")) or SarychUI:T("ui.options_c1d832336d")),
		desc = L and (L["Plates Auras module displays auras on nameplates."] or SarychUI:T("ui.options_193776ba59")) or SarychUI:T("ui.options_193776ba59"),
		childGroups = "tab",
		-- Test button on the right of the module tab bar.
		suiTabBarExtra = testModeOpt,
		args = {
			enabled = {
				suiModuleEnable = true,
				type = "toggle",
				name = "ui.enable_module_b623b573",
				desc = "ui.enable_or_disable_the_module_ce99024f",
				order = 2,
				width = "full",
				get = function() return SarychUI.db.profile.modules[moduleName].enabled end,
				set = function(info, value)
					SarychUI.db.profile.modules[moduleName].enabled = value
					if value then
						SarychUI:EnableModule(moduleName)
					else
						SarychUI:DisableModule(moduleName)
					end
				end,
			},
			-- Sizes and Display tab
			sizes = {
				type = "group",
				name = "ui.sizes_and_display_b2c242b8",
				order = 2,
				disabled = function() return not SarychUI.db.profile.modules[moduleName].enabled end,
				args = {
					layoutPreview = LayoutPreviewOpt("sizes"),

					displayGroup = {
						type = "group",
						name = "ui.display_settings_91ae2667",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							alpha = {
								type = "range",
								name = "ui.transparency_94a43d8b",
								desc = "ui.aura_icon_transparency_0_1_e6fef222",
								order = 1,
								min = 0,
								max = 1,
								step = 0.1,
								suiPreviewKey = "alpha",
								get = function()
									return ProfileDisplay().alpha or 1
								end,
								set = function(info, value)
									ProfileDisplay().alpha = value
									OnDisplaySettingPreview("alpha", value)
								end,
							},
							scale = {
								type = "range",
								name = "ui.scale_e037e967",
								desc = "ui.aura_icon_scale_0_5_2_0_5d50bf2b",
								order = 2,
								min = 0.5,
								max = 2.0,
								step = 0.1,
								suiPreviewKey = "scale",
								get = function()
									return ProfileDisplay().scale or 1
								end,
								set = function(info, value)
									ProfileDisplay().scale = value
									OnDisplaySettingPreview("scale", value)
								end,
							},
						},
					},

					centerGroup = {
						type = "group",
						name = "ui.large_icons_centered_5e26f3ff",
						order = 2,
						inline = true,
						suiTwoCol = true,
						args = {
							iconSizeControl = {
								type = "range",
								name = "ui.size_control_9c7a5988",
								desc = "ui.size_of_center_control_effect_icons_cc_e8dc73f5",
								order = 1,
								min = 16,
								max = 80,
								step = 1,
								suiPreviewKey = "ICON_SIZE_CONTROL",
								get = function() return ProfileSizes().ICON_SIZE_CONTROL end,
								set = function(info, value)
									ProfileSizes().ICON_SIZE_CONTROL = value
									OnLayoutSetting("sizes", "ICON_SIZE_CONTROL", value)
								end,
							},
							iconSizeCast = {
								type = "range",
								name = "ui.size_cast_b446bc98",
								desc = "ui.size_of_cast_effect_icons_silence_interrupts_rig_1e3677da",
								order = 2,
								min = 16,
								max = 80,
								step = 1,
								suiPreviewKey = "ICON_SIZE_CAST",
								get = function() return ProfileSizes().ICON_SIZE_CAST end,
								set = function(info, value)
									ProfileSizes().ICON_SIZE_CAST = value
									OnLayoutSetting("sizes", "ICON_SIZE_CAST", value)
								end,
							},
						},
					},

					playerGroup = {
						type = "group",
						name = "ui.player_abilities_8dc65c16",
						order = 3,
						inline = true,
						suiTwoCol = true,
						args = {
                            standardPlayerIcons = {
                                type = "toggle", name = "ui.plates_auras.standard_player_icons",
                                desc = "ui.plates_auras.standard_player_icons_desc",
                                order = 0, width = "full",
                                suiPreviewKey = "player.standardIcons",
                                get = function() return ProfileLayoutPlayer().standardIcons == true end,
                                set = function(_, value)
                                    OnLayoutSlotSetting("player", "standardIcons", value and true or false)
                                end,
                            },
							iconSizePlayer = {
								type = "range",
								name = "ui.icon_size_040a2fda",
								desc = "ui.size_of_player_ability_icons_under_the_main_icon_a2b811be",
								order = 1,
								min = 16,
								max = 80,
								step = 1,
								suiPreviewKey = "ICON_SIZE_PLAYER",
								get = function() return ProfileSizes().ICON_SIZE_PLAYER end,
								set = function(info, value)
									ProfileSizes().ICON_SIZE_PLAYER = value
									OnLayoutSetting("sizes", "ICON_SIZE_PLAYER", value)
								end,
							},
							maxPlayerAuras = {
								type = "range",
								name = "ui.maximum_amount_c742e541",
								desc = "ui.maximum_player_abilities_shown_under_center_eb282904",
								order = 4,
								min = 0,
								max = 12,
								step = 1,
								suiPreviewKey = "MAX_PLAYER_AURAS",
								get = function() return ProfileSizes().MAX_PLAYER_AURAS end,
								set = function(info, value)
									ProfileSizes().MAX_PLAYER_AURAS = value
									OnLayoutSetting("sizes", "MAX_PLAYER_AURAS", value)
								end,
							},
							playerIconSpacing = {
								type = "range",
								name = "ui.spacing_between_icons_a9f8eb20",
								desc = "ui.spacing_between_player_ability_icons_player_abil_8180c607",
								order = 5,
								min = 0,
								max = 20,
								step = 1,
								suiPreviewKey = "spacing",
								get = function()
									return ProfileLayoutPlayer().spacing or 2
								end,
								set = function(_, value)
									ProfileLayoutPlayer().spacing = value
									OnLayoutSetting("layout", "spacing", value)
								end,
							},
						},
					},

					rightGroup = {
						type = "group",
						name = "ui.right_side_icons_1e27bd5d",
						order = 4,
						inline = true,
						suiTwoCol = true,
						args = {
							iconSizeMobility = {
								type = "range",
								name = "ui.size_mobility_470c942f",
								desc = "ui.size_of_mobility_effect_icons_snare_roots_right__dc57e8f0",
								order = 1,
								min = 16,
								max = 80,
								step = 1,
								suiPreviewKey = "ICON_SIZE_MOBILITY",
								get = function() return ProfileSizes().ICON_SIZE_MOBILITY end,
								set = function(info, value)
									ProfileSizes().ICON_SIZE_MOBILITY = value
									OnLayoutSetting("sizes", "ICON_SIZE_MOBILITY", value)
								end,
							},
							iconSizeOther = {
								type = "range",
								name = "ui.size_other_1dfc1618",
								desc = "ui.size_of_other_effect_icons_immunities_buffs_next_ca5f4016",
								order = 2,
								min = 16,
								max = 80,
								step = 1,
								suiPreviewKey = "ICON_SIZE_OTHER",
								get = function() return ProfileSizes().ICON_SIZE_OTHER end,
								set = function(info, value)
									ProfileSizes().ICON_SIZE_OTHER = value
									OnLayoutSetting("sizes", "ICON_SIZE_OTHER", value)
								end,
							},
						},
					},

					-- ElvUI only: center icons grow when the nameplate scales (target etc.).
					responsiveScaleGroup = {
						type = "group",
						name = "ui.size_when_the_nameplate_changes_9977f219",
						order = 5,
						inline = true,
						hidden = function()
							return not IsElvUIProfileMode()
						end,
						args = {
							hint = {
								type = "description",
								name = "ui.cff808080when_an_elvui_nameplate_grows_target_et_f32196aa",
								order = 0,
								width = "full",
							},
							centerEnabled = {
								type = "toggle",
								name = "ui.large_icons_centered_5e26f3ff",
								desc = "ui.resize_center_icons_control_cast_when_the_elvui__21f50f0c",
								order = 1,
								suiPreviewKey = "center.enabled",
								get = function()
									return ResponsiveScaleValue("center", "enabled")
								end,
								set = function(_, value)
									OnResponsiveScaleSetting("center", "enabled", value and true or false)
									RefreshOptionsDisabledState()
								end,
							},
							centerFactor = {
								type = "range",
								name = "ui.center_growth_amount_871488ab",
								desc = "ui.how_much_center_icons_grow_with_the_nameplate_0__df28993b",
								order = 2,
								min = 0,
								max = 1,
								step = 0.01,
								suiLiveApply = true,
								suiPreviewKey = "center.factor",
								disabled = function()
									return ResponsiveScaleValue("center", "enabled") == false
								end,
								get = function()
									return ResponsiveScaleValue("center", "factor")
								end,
								set = function(_, value)
									OnResponsiveScaleSetting("center", "factor", value)
								end,
							},
							centerMaxBonus = {
								type = "range",
								name = "ui.center_growth_cap_00f9051e",
								desc = "ui.maximum_extra_size_for_center_icons_for_example__70aeff5b",
								order = 3,
								min = 0,
								max = 0.5,
								step = 0.01,
								suiLiveApply = true,
								suiPreviewKey = "center.maxBonus",
								disabled = function()
									return ResponsiveScaleValue("center", "enabled") == false
								end,
								get = function()
									return ResponsiveScaleValue("center", "maxBonus")
								end,
								set = function(_, value)
									OnResponsiveScaleSetting("center", "maxBonus", value)
								end,
							},
						},
					},
				},
			},
			
			-- Positions tab
			positions = {
				type = "group",
				name = "ui.positions_915474ec",
				order = 3,
				disabled = function() return not SarychUI.db.profile.modules[moduleName].enabled end,
				args = {
					layoutPreview = LayoutPreviewOpt("positions"),

					centerGroup = {
						type = "group",
						name = "ui.large_icons_centered_5e26f3ff",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							centrY = {
								type = "range",
								name = "ui.vertical_position_769cbe51",
								desc = "ui.vertical_position_of_center_icons_control_cast_c53c2af4",
								order = 1,
								min = -200,
								max = 200,
								step = 1,
								suiPreviewKey = "CentrY",
								get = function() return ProfilePositions().CentrY end,
								set = function(info, value)
									ProfilePositions().CentrY = value
									OnLayoutSetting("positions", "CentrY", value)
								end,
							},
							castX = {
								type = "range",
								name = "ui.cast_horizontal_offset_12b0629b",
								desc = "ui.cast_icon_horizontal_position_right_of_control_6718062b",
								order = 2,
								min = -200,
								max = 200,
								step = 1,
								suiPreviewKey = "CastX",
								get = function() return ProfilePositions().CastX or 50 end,
								set = function(info, value)
									ProfilePositions().CastX = value
									OnLayoutSetting("positions", "CastX", value)
								end,
							},
							castY = {
								type = "range",
								name = "ui.cast_vertical_offset_2aa792c5",
								desc = "ui.cast_icon_vertical_position_5dde7a79",
								order = 3,
								min = -200,
								max = 200,
								step = 1,
								suiPreviewKey = "CastY",
								get = function() return ProfilePositions().CastY or 0 end,
								set = function(info, value)
									ProfilePositions().CastY = value
									OnLayoutSetting("positions", "CastY", value)
								end,
							},
						},
					},

					playerGroup = {
						type = "group",
						name = "ui.player_abilities_8dc65c16",
						order = 2,
						inline = true,
						suiTwoCol = true,
						args = {
							playerAltRight = {
								type = "toggle",
								name = "ui.alternate_layout_on_the_right_b005c4ef",
								desc = "ui.mob_cc_cast_classic_elvui_aee59767",
								order = 1,
								width = "full",
								suiPreviewKey = "player.altRight",
								get = function() return ProfileLayoutPlayer().altRight == true end,
								set = function(_, value)
									OnLayoutSlotSetting("player", "altRight", value and true or false)
									RefreshOptionsDisabledState()
									-- Remount rebuilds widgets; refresh the new preview so the
									-- toggle is visible immediately both ways.
									local preview = SarychUI.PlatesAurasLayoutPreview
									if preview then
										if preview.ClearLiveValue then
											preview:ClearLiveValue("player.altRight")
										end
										if preview.RefreshAll then
											preview:RefreshAll()
										end
									end
								end,
							},
							playerOffsetY = {
								type = "range",
								name = "ui.vertical_offset_7c6782fb",
								desc = "ui.vertical_offset_of_player_abilities_relative_to__c2b512f7",
								order = 2,
								min = -100,
								max = 100,
								step = 1,
								suiPreviewKey = "PlayerOffsetY",
								get = function() return ProfilePositions().PlayerOffsetY end,
								set = function(info, value)
									ProfilePositions().PlayerOffsetY = value
									OnLayoutSetting("positions", "PlayerOffsetY", value)
								end,
								disabled = function() return ProfileLayoutPlayer().altRight == true end,
							},
						},
					},

					rightGroup = {
						type = "group",
						name = "ui.right_side_icons_1e27bd5d",
						order = 3,
						inline = true,
						suiTwoCol = true,
						args = {
							rightX = {
								type = "range",
								name = "ui.horizontal_position_61d6f187",
								desc = "ui.mobility_other_elvui_ca36cecd",
								order = 1,
								min = -200,
								max = 200,
								step = 1,
								suiPreviewKey = "RightX",
								get = function() return ProfilePositions().RightX end,
								set = function(info, value)
									ProfilePositions().RightX = value
									OnLayoutSetting("positions", "RightX", value)
								end,
							},
							rightY = {
								type = "range",
								name = "ui.vertical_position_769cbe51",
								desc = "ui.vertical_position_of_right_side_icons_mobility_o_bc6051af",
								order = 2,
								min = -200,
								max = 200,
								step = 1,
								suiPreviewKey = "RightY",
								get = function() return ProfilePositions().RightY end,
								set = function(info, value)
									ProfilePositions().RightY = value
									OnLayoutSetting("positions", "RightY", value)
								end,
							},
							otherX = {
								type = "range",
								name = "ui.other_horizontal_offset_ab32f329",
								desc = "ui.other_icon_horizontal_position_right_of_mobility_d9a92a09",
								order = 3,
								min = -200,
								max = 200,
								step = 1,
								suiPreviewKey = "OtherX",
								get = function() return ProfilePositions().OtherX or 35 end,
								set = function(info, value)
									ProfilePositions().OtherX = value
									OnLayoutSetting("positions", "OtherX", value)
								end,
							},
							otherY = {
								type = "range",
								name = "ui.other_vertical_offset_ff442f1f",
								desc = "ui.other_icon_vertical_position_ab3f910a",
								order = 4,
								min = -200,
								max = 200,
								step = 1,
								suiPreviewKey = "OtherY",
								get = function() return ProfilePositions().OtherY or 0 end,
								set = function(info, value)
									ProfilePositions().OtherY = value
									OnLayoutSetting("positions", "OtherY", value)
								end,
							},
						},
					},

					-- Hidden: proportional ElvUI offsets are unused for now.
					proportionalOffsetGroup = {
						type = "group",
						name = "ui.offset_when_the_nameplate_changes_f17b1503",
						order = 4,
						inline = true,
						suiTwoCol = true,
						hidden = true,
						args = {
							hint = {
								type = "description",
								name = "ui.cff808080elvui_nameplates_are_dynamic_they_can_g_ee549964",
								order = 0,
								width = "full",
							},
							centerProportional = {
								type = "toggle",
								name = "ui.large_icons_centered_5e26f3ff",
								desc = "ui.further_shift_center_icons_based_on_nameplate_si_82a6a3fb",
								order = 1,
								suiPreviewKey = "center.offsetMode",
								get = function()
									return IsSlotProportional("center")
								end,
								set = function(_, value)
									OnLayoutSlotSetting("center", "offsetMode", value and "proportional" or "fixed")
								end,
							},
							playerProportional = {
								type = "toggle",
								name = "ui.player_abilities_8dc65c16",
								desc = "ui.further_shift_player_ability_icons_based_on_name_cd15cf79",
								order = 2,
								suiPreviewKey = "player.offsetMode",
								get = function()
									return IsSlotProportional("player")
								end,
								set = function(_, value)
									OnLayoutSlotSetting("player", "offsetMode", value and "proportional" or "fixed")
								end,
							},
							rightProportional = {
								type = "toggle",
								name = "ui.right_side_icons_1e27bd5d",
								desc = "ui.further_shift_right_side_icons_based_on_nameplat_36c6039f",
								order = 3,
								suiPreviewKey = "right.offsetMode",
								get = function()
									return IsSlotProportional("right")
								end,
								set = function(_, value)
									OnLayoutSlotSetting("right", "offsetMode", value and "proportional" or "fixed")
								end,
							},
							centerWidthFactor = {
								type = "range",
								name = "ui.center_width_offset_3479d255",
								desc = "ui.fraction_of_nameplate_width_added_to_the_horizon_81c4438e",
								order = 4,
								min = -1,
								max = 1,
								step = 0.01,
								suiLiveApply = true,
								suiPreviewKey = "center.widthFactor",
								disabled = function()
									return not IsSlotProportional("center")
								end,
								get = function()
									return ProfileLayoutSlot("center").widthFactor or 0
								end,
								set = function(_, value)
									OnLayoutSlotSetting("center", "widthFactor", value)
								end,
							},
							centerHeightFactor = {
								type = "range",
								name = "ui.center_height_offset_4deb8b88",
								desc = "ui.fraction_of_nameplate_height_added_to_the_vertic_4513528e",
								order = 5,
								min = -1,
								max = 1,
								step = 0.01,
								suiLiveApply = true,
								suiPreviewKey = "center.heightFactor",
								disabled = function()
									return not IsSlotProportional("center")
								end,
								get = function()
									return ProfileLayoutSlot("center").heightFactor or 0
								end,
								set = function(_, value)
									OnLayoutSlotSetting("center", "heightFactor", value)
								end,
							},
							playerWidthFactor = {
								type = "range",
								name = "ui.player_width_offset_567c8644",
								desc = "ui.fraction_of_plate_width_added_to_the_horizontal__d9247376",
								order = 6,
								min = -1,
								max = 1,
								step = 0.01,
								suiLiveApply = true,
								suiPreviewKey = "player.widthFactor",
								disabled = function()
									return not IsSlotProportional("player")
								end,
								get = function()
									return ProfileLayoutSlot("player").widthFactor or 0
								end,
								set = function(_, value)
									OnLayoutSlotSetting("player", "widthFactor", value)
								end,
							},
							playerHeightFactor = {
								type = "range",
								name = "ui.player_height_offset_fb7fb1d6",
								desc = "ui.fraction_of_plate_height_added_to_the_vertical_o_ed36fe5d",
								order = 7,
								min = -1,
								max = 1,
								step = 0.01,
								suiLiveApply = true,
								suiPreviewKey = "player.heightFactor",
								disabled = function()
									return not IsSlotProportional("player")
								end,
								get = function()
									return ProfileLayoutSlot("player").heightFactor or 0
								end,
								set = function(_, value)
									OnLayoutSlotSetting("player", "heightFactor", value)
								end,
							},
							rightWidthFactor = {
								type = "range",
								name = "ui.right_width_offset_c61b4722",
								desc = "ui.fraction_of_nameplate_width_added_to_the_horizon_37b4234a",
								order = 8,
								min = -1,
								max = 1,
								step = 0.01,
								suiLiveApply = true,
								suiPreviewKey = "right.widthFactor",
								disabled = function()
									return not IsSlotProportional("right")
								end,
								get = function()
									return ProfileLayoutSlot("right").widthFactor or 0
								end,
								set = function(_, value)
									OnLayoutSlotSetting("right", "widthFactor", value)
								end,
							},
							rightHeightFactor = {
								type = "range",
								name = "ui.right_height_offset_f47c6caa",
								desc = "ui.fraction_of_nameplate_height_added_to_the_vertic_2b5550e2",
								order = 9,
								min = -1,
								max = 1,
								step = 0.01,
								suiLiveApply = true,
								suiPreviewKey = "right.heightFactor",
								disabled = function()
									return not IsSlotProportional("right")
								end,
								get = function()
									return ProfileLayoutSlot("right").heightFactor or 0
								end,
								set = function(_, value)
									OnLayoutSlotSetting("right", "heightFactor", value)
								end,
							},
						},
					},
				},
			},
			
			-- Spells tab: type subtabs (cc/cast/...) + two-pane list inside each.
			spells = {
				name = L and (L["Spell Settings"] or SarychUI:T("ui.options_f56a97f56d")) or SarychUI:T("ui.options_f56a97f56d"),
				type = "group",
				childGroups = "tab",
				order = 5,
				disabled = function() return not SarychUI.db.profile.modules[moduleName].enabled end,
				args = (function()
					local selectedSpellType = "other"
					local spellIDToAdd = ""

					local function TryAddSpell(value)
						spellIDToAdd = value or ""
						local spellID = tonumber(spellIDToAdd)
						if not spellID then
							print(SarychUI:T("ui.options_113fb3578e"))
							return
						end
						local spellName = GetSpellInfo(spellID)
						if not spellName then
							print(SarychUI:T("ui.options_38a1135102") .. spellID .. SarychUI:T("ui.options_29f17fb7d8"))
							return
						end
						local success, message = module:AddSpell(spellID, selectedSpellType, 100, true, nil)
						if success then
							print(SarychUI:T("ui.options_bf7af6689a") .. spellName .. " (ID: " .. spellID .. SarychUI:T("ui.options_cccedc8768") .. (typeNames[selectedSpellType] or selectedSpellType) .. ")")
							spellIDToAdd = ""
							RefreshModule()
							if SarychUI.RebuildModuleOptions then
								SarychUI:RebuildModuleOptions(moduleName)
							elseif SarychUI.NotifySarychUIOptionsChange then
								SarychUI:NotifySarychUIOptionsChange()
							end
						else
							print(SarychUI:T("ui.options_f429c3179b") .. (message or SarychUI:T("ui.options_1047bb7bef")))
						end
					end

					local function BuildArgs()
						local args = {
							addSpell = {
								type = "group",
								name = "ui.add_spell_7324ee9c",
								order = 0,
								inline = true,
								suiOneRowAdd = true,
								_syncSpellType = function(typeKey)
									if typeKey and typeNames[typeKey] then
										selectedSpellType = typeKey
									end
								end,
								args = {
									spellType = {
										type = "select",
										name = "ui.type_d4a6795c",
										desc = "ui.spell_type_a8e05dbc",
										order = 1,
										values = typeNames,
										get = function() return selectedSpellType end,
										set = function(info, value)
											selectedSpellType = value
										end,
									},
									spellID = {
										type = "input",
										name = "ui.options_89f89c02cf",
										desc = L and (L["Spell ID All Ranks Desc"] or SarychUI:T("ui.options_d982ee50e1")) or SarychUI:T("ui.options_d982ee50e1"),
										order = 2,
										suiSaveButton = SarychUI:T("ui.options_559a87f7cc"),
										get = function() return spellIDToAdd end,
										suiOnDraft = function(text)
											spellIDToAdd = text or ""
										end,
										set = function(info, value)
											TryAddSpell(value)
										end,
									},
								},
							},
						}

						local Spells = BuildSpells()
						for key, value in pairs(Spells) do
							if type(value) == "table" then
								value.suiTwoPane = true
								if value.order then
									value.order = value.order + 1
								end
								args[key] = value
							end
						end

						return args
					end

					return BuildArgs()
				end)(),
			},
		},
	}
end
