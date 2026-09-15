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

local function ShowReloadPopup(onCancel, text)
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup(text, onCancel)
		return
	end
	if StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

local function IsAwesomeWotlkDetected()
	local compat = SarychUI and SarychUI.Compatibility
	if not compat then
		return false
	end
	if compat.GetDllDetectionState then
		return compat:GetDllDetectionState("awesome_wotlk") == "detected"
	end
	if compat.DetectAwesomeWotlkDll then
		return compat:DetectAwesomeWotlkDll()
	end
	return false
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
		return L and (L["ElvUI Nameplates"] or "ElvUI индикаторы") or "ElvUI индикаторы"
	end
	return L and (L["Classic WoW Nameplates"] or "Classic WoW") or "Classic WoW"
end

local function ProfileModeInfoText()
	local mode = module.GetActiveProfileMode and module:GetActiveProfileMode() or "classic"
	local modeLabel = GetProfileModeLabel()
	-- ElvUI mode: same green as «Обнаружен»; classic stays gold.
	local modeColor = (mode == "elvui") and "|cff00ff00" or "|cFFFFD700"
	local coloredMode = modeColor .. tostring(modeLabel) .. "|r"
	return "Настройки параметров для: " .. coloredMode
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
	border = "Простая рамка",
	ACShine = "Свечение при автоприменении",
	Pixel = "Пиксельное свечение",
	buttonOverlay = "Свечение кнопки действия",
	__order = { "border", "ACShine", "Pixel", "buttonOverlay" },
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
						name = L and (L["Enabled"] or "Включить") or "Включить",
						desc = L and (L["Show this spell on nameplates"] or "Показывать это заклинание на неймплейтах") or "Показывать это заклинание на неймплейтах",
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
						name = L and (L["Spell Type"] or "Тип заклинания") or "Тип заклинания",
						args = {
							type = {
								name = L and (L["Type"] or "Тип") or "Тип",
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
						name = L and (L["Spell Priority"] or "Приоритет заклинания") or "Приоритет заклинания",
						args = {
							customPriority = {
								name = L and (L["Custom Priority"] or "Пользовательский приоритет") or "Пользовательский приоритет",
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
								name = L and (L["Priority"] or "Приоритет") or "Приоритет",
								desc = L and (L["Higher priority spells will take precedence regardless of duration"] or "Заклинания с более высоким приоритетом будут иметь приоритет независимо от длительности") or "Заклинания с более высоким приоритетом будут иметь приоритет независимо от длительности",
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
						name = "Свечение",
						suiTwoCol = true,
						args = {
							enabled = {
								name = "Показать свечение",
								desc = "Показывать свечение на иконке этого заклинания",
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
								name = "Тип",
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
								name = "Использовать свой цвет",
								desc = "Если не отмечено, используется цвет по умолчанию (обычно жёлтый)",
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
								name = "Цвет",
								desc = "Цвет и прозрачность свечения. Открывает стандартное окно выбора цвета.",
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
								name = "Линии или частицы",
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
									return glowType == "buttonOverlay" or glowType == "border"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowLines")) or 8
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowLines", value)
								end,
							},
							glowFrequency = {
								name = "Частота",
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
									return glowType == "buttonOverlay" or glowType == "border"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowFrequency")) or 0.25
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowFrequency", value)
								end,
							},
							glowLength = {
								name = "Длина",
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
								name = "Толщина",
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
								name = "Смещение по X",
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
									return glowType == "buttonOverlay" or glowType == "border"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowXOffset")) or 0
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowXOffset", value)
								end,
							},
							glowYOffset = {
								name = "Смещение по Y",
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
									return glowType == "buttonOverlay" or glowType == "border"
								end,
								get = function()
									return tonumber(GetSpellGlowField(spellID, spell, "glowYOffset")) or 0
								end,
								set = function(_, value)
									SetSpellGlowField(spellID, "glowYOffset", value)
								end,
							},
							glowScale = {
								name = "Масштаб",
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
								name = "Граница",
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
						name = L and (L["Allow from Other Players"] or "Разрешить от других игроков") or "Разрешить от других игроков",
						hidden = function()
							local db = SarychUI.db.profile.modules[moduleName]
							local currentType = (db.spells[spellID] and db.spells[spellID].type) or spell.type or "other"
							return currentType ~= "other"
						end,
						args = {
							enabled = {
								name = L and (L["Allow from Other Players"] or "Разрешить от других игроков") or "Разрешить от других игроков",
								desc = L and (L["Allow this spell to be displayed in 'other' category even if cast by other players"] or "Разрешить отображение этого заклинания в категории 'other' даже если оно наложено другим игроком") or "Разрешить отображение этого заклинания в категории 'other' даже если оно наложено другим игроком",
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
						name = L and (L["Remove Spell"] or "Удалить заклинание") or "Удалить заклинание",
						order = 999,
						args = {
							removeButton = {
								name = L and (L["Remove Spell"] or "Удалить заклинание") or "Удалить заклинание",
								desc = L and (L["Remove this spell from the list"] or "Удалить это заклинание из списка") or "Удалить это заклинание из списка",
								type = "execute",
								order = 1,
								width = "full",
								confirm = function()
									local spellName = GetSpellInfo(spellID) or ("ID " .. spellID)
									return format(L and (L["Are you sure you want to remove %s?"] or "Вы уверены, что хотите удалить %s?") or "Вы уверены, что хотите удалить %s?", spellName)
								end,
								func = function()
									local spellName = GetSpellInfo(spellID) or ("ID " .. spellID)
									local success, message = module:RemoveSpell(spellID)
									if not success then
										print("|cffffd200SarychUI:|r |cffff0000 Ошибка: " .. (message or "Неизвестная ошибка"))
										return
									end
									print("|cffffd200SarychUI:|r |cff00ff00 Заклинание удалено: " .. spellName .. " (ID: " .. spellID .. ")")
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
		type = "toggle",
		name = "Тестовый режим",
		desc = "Показать случайные иконки на ближайших существующих индикаторах (например, на тренировочном манекене).",
		get = function()
			local db = SarychUI.db.profile.modules[moduleName]
			return db and db.testModeEnabled or false
		end,
		set = function(info, value)
			local db = SarychUI.db.profile.modules[moduleName]
			if not db then return end
			db.testModeEnabled = value
			if value then
				module:StartTestMode()
				print("|cffffd200SarychUI:|r |cff00ff00 Тестовый режим включен")
			else
				module:StopTestMode()
				print("|cffffd200SarychUI:|r |cff00ff00 Тестовый режим выключен")
			end
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
		name = "|TInterface\\AddOns\\SarychUI\\addons\\ElvUI_NamePlates\\Media\\Textures\\nameplates:20:20:0:0:256:128:0:38:45:81|t " .. (L and (L["Plates Auras"] or "Ауры на индикаторах здоровья") or "Ауры на индикаторах здоровья"),
		desc = L and (L["Plates Auras module displays auras on nameplates."] or "Модуль отображает ауры на индикаторах здоровья.") or "Модуль отображает ауры на индикаторах здоровья.",
		childGroups = "tab",
		-- Always-visible toggle on the right of the module tab bar.
		suiTabBarExtra = testModeOpt,
		args = {
			-- General tab
			general = {
				type = "group",
				name = "Общее",
				order = 1,
				args = {
					enabled = {
						type = "toggle",
						name = "Включить модуль",
						desc = "Включить или выключить модуль",
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
					
					useAwesomeWotlk = {
						type = "group",
						name = "Использовать AwesomeWotlk",
						order = 3,
						inline = true,
						hidden = function() return not SarychUI.db.profile.modules[moduleName].enabled end,
						args = {
							notDetectedNotice = {
								type = "description",
								name = "|cffff4444AwesomeWotlk не обнаружен.|r |cff808080Статус: Система -> Обзор.|r",
								order = 0,
								width = "full",
								hidden = function()
									return IsAwesomeWotlkDetected()
								end,
							},
							enabled = {
								type = "toggle",
								name = "Включить поддержку AwesomeWotlk",
								desc = "Обходит лимиты API клиента: стабильнее, точнее, быстрее. Без Awesome — в рамках обычного клиента.",
								order = 1,
								width = "full",
								disabled = function()
									return not IsAwesomeWotlkDetected()
								end,
								get = function()
									if not IsAwesomeWotlkDetected() then
										-- Keep UI and runtime in sync when DLL is absent
										local db = SarychUI.db.profile.modules[moduleName]
										if db and db.useAwesomeWotlk then
											db.useAwesomeWotlk = false
										end
										return false
									end
									return SarychUI.db.profile.modules[moduleName].useAwesomeWotlk or false
								end,
								set = function(info, value)
									if not IsAwesomeWotlkDetected() then
										return
									end
									local db = SarychUI.db.profile.modules[moduleName]
									local previous = db.useAwesomeWotlk and true or false
									value = value and true or false
									if previous == value then
										return
									end
									db.useAwesomeWotlk = value
									if value then
										if _G.sarPlatesAuras_SetNameplateDistance and _G.sarPlatesAuras_SetNameplateDistance(42) then
											print("|cffffd200SarychUI:|r |cff00ff00 AwesomeWotlk поддержка включена. Установлено nameplateDistance = 42")
										else
											print("|cffffd200SarychUI:|r |cffff0000 CVar 'nameplateDistance' не найден. Убедитесь, что используете AwesomeWotlk.")
										end
									end
									ShowReloadPopup(function()
										db.useAwesomeWotlk = previous
										RefreshModule()
									end, "Смена режима аур на неймплейтах требует перезагрузки интерфейса.")
								end,
							},
						},
					},

					modeHint = {
						type = "description",
						name = "|cFFFFD700Внимание:|r После применения потребуется перезагрузка интерфейса.",
						order = 4,
						width = "full",
						hidden = function() return not SarychUI.db.profile.modules[moduleName].enabled end,
					},

					awesomeBenefitNote = {
						type = "description",
						name = "|cFFFFD700Пометка:|r Рекомендуется AwesomeWotlk — обходит ограничения API клиента, с ним стабильнее, точнее и производительнее. Без него модуль упирается в лимиты обычного клиента.",
						order = 5,
						width = "full",
						hidden = function() return not SarychUI.db.profile.modules[moduleName].enabled end,
					},
				},
			},
			
			-- Sizes and Display tab
			sizes = {
				type = "group",
				name = "Размеры и отображение",
				order = 2,
				disabled = function() return not SarychUI.db.profile.modules[moduleName].enabled end,
				args = {
					layoutPreview = LayoutPreviewOpt("sizes"),

					displayGroup = {
						type = "group",
						name = "Настройки отображения",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							alpha = {
								type = "range",
								name = "Прозрачность",
								desc = "Прозрачность иконок аур (0-1)",
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
								name = "Масштаб",
								desc = "Масштаб иконок аур (0.5-2.0)",
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
						name = "Большие иконки по центру",
						order = 2,
						inline = true,
						suiTwoCol = true,
						args = {
							iconSizeControl = {
								type = "range",
								name = "Размер: Контроль",
								desc = "Размер иконки контрольных эффектов (cc) по центру",
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
								name = "Размер: Каст",
								desc = "Размер иконки эффектов каста (silence, interrupts) справа от control",
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
						name = "Способности игрока",
						order = 3,
						inline = true,
						suiTwoCol = true,
						args = {
							iconSizePlayer = {
								type = "range",
								name = "Размер иконок",
								desc = "Размер иконок способностей игрока под основными иконками",
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
							iconSizePlayerWidth = {
								type = "range",
								name = "Ширина иконок",
								desc = "Ширина прямоугольных иконок способностей игрока",
								order = 2,
								min = 16,
								max = 80,
								step = 1,
								suiPreviewKey = "ICON_SIZE_PLAYER_WIDTH",
								get = function() return ProfileSizes().ICON_SIZE_PLAYER_WIDTH end,
								set = function(info, value)
									ProfileSizes().ICON_SIZE_PLAYER_WIDTH = value
									OnLayoutSetting("sizes", "ICON_SIZE_PLAYER_WIDTH", value)
								end,
							},
							iconSizePlayerHeight = {
								type = "range",
								name = "Высота иконок",
								desc = "Высота прямоугольных иконок способностей игрока",
								order = 3,
								min = 16,
								max = 80,
								step = 1,
								suiPreviewKey = "ICON_SIZE_PLAYER_HEIGHT",
								get = function() return ProfileSizes().ICON_SIZE_PLAYER_HEIGHT end,
								set = function(info, value)
									ProfileSizes().ICON_SIZE_PLAYER_HEIGHT = value
									OnLayoutSetting("sizes", "ICON_SIZE_PLAYER_HEIGHT", value)
								end,
							},
							maxPlayerAuras = {
								type = "range",
								name = "Максимальное количество",
								desc = "Максимальное количество способностей игрока, отображаемых под центром",
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
								name = "Расстояние между иконками",
								desc = "Расстояние между иконками способностей игрока (только блок «Способности игрока»)",
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
						name = "Иконки справа",
						order = 4,
						inline = true,
						suiTwoCol = true,
						args = {
							iconSizeMobility = {
								type = "range",
								name = "Размер: Мобильность",
								desc = "Размер иконки эффектов мобильности (snare, roots) справа от неймплейта",
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
								name = "Размер: Прочие",
								desc = "Размер иконки других эффектов (immunities, buffs) рядом с mobility",
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
						name = "Размер при изменении индикатора",
						order = 5,
						inline = true,
						hidden = function()
							return not IsElvUIProfileMode()
						end,
						args = {
							hint = {
								type = "description",
								name = "|cff808080Когда индикатор ElvUI увеличивается (цель и т.п.), центральные иконки (контроль/каст) тоже растут.\n• «Насколько растут» — сила роста (1.0 ≈ как сам индикатор).\n• «Предел роста» — потолок, например 0.20 = не больше +20%.|r",
								order = 0,
								width = "full",
							},
							centerEnabled = {
								type = "toggle",
								name = "Большие иконки по центру",
								desc = "Менять размер центральных иконок (контроль/каст), когда меняется размер индикатора ElvUI.",
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
								name = "Центр: насколько растут",
								desc = "Насколько центральные иконки увеличиваются вместе с индикатором. 0 — размер почти не меняется, 1 — растут почти как сам индикатор.",
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
								name = "Центр: предел роста",
								desc = "Максимум, на сколько могут вырасти центральные иконки. Например 0.20 = не больше +20% к обычному размеру.",
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
				name = "Позиции",
				order = 3,
				disabled = function() return not SarychUI.db.profile.modules[moduleName].enabled end,
				args = {
					layoutPreview = LayoutPreviewOpt("positions"),

					centerGroup = {
						type = "group",
						name = "Большие иконки по центру",
						order = 1,
						inline = true,
						suiTwoCol = true,
						args = {
							centrY = {
								type = "range",
								name = "Вертикальная позиция",
								desc = "Вертикальная позиция центральных иконок (control, cast)",
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
								name = "Смещение Cast по горизонтали",
								desc = "Горизонтальная позиция Cast иконки (справа от control)",
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
								name = "Смещение Cast по вертикали",
								desc = "Вертикальная позиция Cast иконки",
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
						name = "Способности игрока",
						order = 2,
						inline = true,
						suiTwoCol = true,
						args = {
							playerAltRight = {
								type = "toggle",
								name = "Альтернативное расположение справа",
								desc = "Переносит способности игрока вправо, над иконками «прочие» и «рывки». Иконки идут по две в ряд, квадратные как у mob, и растут вверх.\n\nПока справа ничего не горит, блок занимает их место; как только там появляется иконка — поднимается выше.\n\nЦентральные CC/cast остаются на обычном месте, как если бы способностей игрока под ними не было.\n\nДействует для текущего типа индикаторов (Classic или ElvUI) — у каждого профиля своя галочка.",
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
								name = "Вертикальное смещение",
								desc = "Вертикальное смещение способностей игрока относительно центральных иконок",
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
						name = "Иконки справа",
						order = 3,
						inline = true,
						suiTwoCol = true,
						args = {
							rightX = {
								type = "range",
								name = "Горизонтальная позиция",
								desc = "Горизонтальная позиция иконок справа (mobility/other) от неймплейта",
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
								name = "Вертикальная позиция",
								desc = "Вертикальная позиция иконок справа (mobility/other) от неймплейта",
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
								name = "Смещение Other по горизонтали",
								desc = "Горизонтальная позиция Other иконки (справа от mobility)",
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
								name = "Смещение Other по вертикали",
								desc = "Вертикальная позиция Other иконки",
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
						name = "Смещение при изменении индикатора",
						order = 4,
						inline = true,
						suiTwoCol = true,
						hidden = true,
						args = {
							hint = {
								type = "description",
								name = "|cff808080Индикаторы ElvUI динамические — могут увеличиваться и уменьшаться.\nПолзунки выше задают базовую позицию. Здесь — дополнительный сдвиг от ширины/высоты индикатора.\nВключите нужную группу и выставьте фактор ≠ 0 — иначе смещения не будет.|r",
								order = 0,
								width = "full",
							},
							centerProportional = {
								type = "toggle",
								name = "Большие иконки по центру",
								desc = "Дополнительно сдвигать центральные иконки в зависимости от размера индикатора.",
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
								name = "Способности игрока",
								desc = "Дополнительно сдвигать иконки способностей игрока в зависимости от размера индикатора.",
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
								name = "Иконки справа",
								desc = "Дополнительно сдвигать правые иконки в зависимости от размера индикатора.",
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
								name = "Центр: смещение по ширине",
								desc = "Доля ширины индикатора, добавляемая к горизонтальному смещению центральных иконок. Работает только если включено «Большие иконки по центру».",
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
								name = "Центр: смещение по высоте",
								desc = "Доля высоты индикатора, добавляемая к вертикальному смещению центральных иконок. Работает только если включено «Большие иконки по центру».",
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
								name = "Игрок: смещение по ширине",
								desc = "Доля ширины индикатора, добавляемая к горизонтальному смещению иконок игрока. Работает только если включено «Способности игрока».",
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
								name = "Игрок: смещение по высоте",
								desc = "Доля высоты индикатора, добавляемая к вертикальному смещению иконок игрока. Работает только если включено «Способности игрока».",
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
								name = "Справа: смещение по ширине",
								desc = "Доля ширины индикатора, добавляемая к горизонтальному смещению правых иконок. Работает только если включено «Иконки справа».",
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
								name = "Справа: смещение по высоте",
								desc = "Доля высоты индикатора, добавляемая к вертикальному смещению правых иконок. Работает только если включено «Иконки справа».",
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
			
			-- Spells tab: type subtabs (cc/cast/…) + two-pane list inside each.
			spells = {
				name = L and (L["Spell Settings"] or "Настройки заклинаний") or "Настройки заклинаний",
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
							print("|cffffd200SarychUI:|r |cffff0000 Неверный ID заклинания")
							return
						end
						local spellName = GetSpellInfo(spellID)
						if not spellName then
							print("|cffffd200SarychUI:|r |cffff0000 Заклинание с ID " .. spellID .. " не найдено")
							return
						end
						local success, message = module:AddSpell(spellID, selectedSpellType, 100, true, nil)
						if success then
							print("|cffffd200SarychUI:|r |cff00ff00 Заклинание добавлено: " .. spellName .. " (ID: " .. spellID .. ", тип: " .. (typeNames[selectedSpellType] or selectedSpellType) .. ")")
							spellIDToAdd = ""
							RefreshModule()
							if SarychUI.RebuildModuleOptions then
								SarychUI:RebuildModuleOptions(moduleName)
							elseif SarychUI.NotifySarychUIOptionsChange then
								SarychUI:NotifySarychUIOptionsChange()
							end
						else
							print("|cffffd200SarychUI:|r |cffff0000 Ошибка: " .. (message or "Неизвестная ошибка"))
						end
					end

					local function BuildArgs()
						local args = {
							addSpell = {
								type = "group",
								name = "Добавить заклинание",
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
										name = "Тип",
										desc = "Тип заклинания",
										order = 1,
										values = typeNames,
										get = function() return selectedSpellType end,
										set = function(info, value)
											selectedSpellType = value
										end,
									},
									spellID = {
										type = "input",
										name = "ID",
										desc = "ID заклинания",
										order = 2,
										suiSaveButton = "Добавить",
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
