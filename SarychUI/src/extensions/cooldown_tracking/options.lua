local SUI = SarychUI
local extension = SUI.extensions.party_abilities
local L = SUI.L
local CLASS_LABEL_KEYS = {
	WARRIOR = "ui.options_4c5f0585f4", PALADIN = "ui.options_ddbc81acaf",
	HUNTER = "ui.options_c690f9f1ef", ROGUE = "ui.options_047fc6fcde",
	PRIEST = "ui.options_73b4a59c4e", DEATHKNIGHT = "ui.options_41ef8737e1",
	SHAMAN = "ui.options_a7c3a865fc", MAGE = "ui.options_b9a2d8a9c3",
	WARLOCK = "ui.options_a0ec787cf6", DRUID = "ui.options_3aece036e2",
}
local TAB_ICON = "|TInterface\\AddOns\\SarychUI\\media\\components\\modules\\nameplates\\engines\\elvui\\Media\\Textures\\nameplates:20:20:0:0:256:128:0:38:45:81|t "
local selectedSpell, newSpellID, selectedClass, viewClass = nil, "", "MAGE", nil
local classes = { "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR", "OTHER" }

local function DB() return extension:GetDB() end
local function ApplySpell()
	extension:RefreshConfig()
	if SUI.PartyAbilitiesPreview then SUI.PartyAbilitiesPreview:RefreshAll(true) end
end
local function Refresh()
	ApplySpell()
	SUI:NotifySarychUIOptionsChange()
end
local function RefreshAppearance()
	extension:RefreshConfig()
	if SUI.PartyAbilitiesPreview then SUI.PartyAbilitiesPreview:RefreshAll() end
end
local function Rebuild()
	extension:RefreshConfig()
	if SUI.PartyAbilitiesPreview then SUI.PartyAbilitiesPreview:RefreshAll(true) end
	if SUI.RefreshExtensionOptions then SUI:RefreshExtensionOptions() end
end
local function Spell()
	local db = DB()
	return db and db.spells and selectedSpell and db.spells[selectedSpell]
end
local function GlowEnabled()
	local spell = Spell()
	return spell and spell.highlight ~= nil and spell.highlight ~= false and spell.highlight ~= 0
end
local function GlowKind()
	local spell = Spell()
	return spell and (spell.glowType or "border") or "border"
end
local function BindSpellControls(controls, spellID)
	local bound = {}
	for key, option in pairs(controls) do
		local copy = {}
		for field, value in pairs(option) do copy[field] = value end
		if type(option.args) == "table" then
			copy.args = BindSpellControls(option.args, spellID)
		end
		for _, field in ipairs({ "get", "set", "hidden", "disabled", "func" }) do
			local callback = option[field]
			if type(callback) == "function" then
				copy[field] = function(...)
					local previous = selectedSpell
					selectedSpell = spellID
					local result = { callback(...) }
					selectedSpell = previous
					return unpack(result)
				end
			end
		end
		bound[key] = copy
	end
	return bound
end
local function Layout()
	local db = DB()
	local kind = extension:GetLayoutKind()
	db.layouts = db.layouts or {}
	db.layouts[kind] = db.layouts[kind] or {}
	return db.layouts[kind]
end
local function Range(key, label, min, max, step, order)
	return { type = "range", name = function() return L[label] end, min = min, max = max,
		step = step, order = order,
		get = function() return tonumber(Layout()[key]) or ({ x = 2, y = 0, size = 24, spacing = 2, perRow = 6 })[key] end,
		set = function(_, value) Layout()[key] = value; Refresh() end }
end

local function ContextToggle(key, label, order)
	return { type = "toggle", name = function() return L[label] end, order = order,
		get = function() return DB().contexts[key] ~= false end,
		set = function(_, value) DB().contexts[key] = value; Refresh() end }
end

function extension:GetOptions(forGroupFrames)
	local db = DB()
	if not viewClass then
		viewClass = selectedSpell and db.spells[selectedSpell] and db.spells[selectedSpell].class
			or selectedClass
	end
	if not selectedSpell or not db.spells[selectedSpell] or db.spells[selectedSpell].class ~= viewClass then
		selectedSpell = nil
		for id, data in pairs(db.spells) do
			if data.class == viewClass then selectedSpell = id; break end
		end
	end
	local classValues = { __order = classes }
	for _, class in ipairs(classes) do
		local label = class == "OTHER" and L["PA_Other"]
			or SUI:T(CLASS_LABEL_KEYS[class] or class)
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if color then
			label = string.format("|cff%02x%02x%02x%s|r",
				math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
				math.floor(color.b * 255 + 0.5), label)
		end
		classValues[class] = label
	end
	local group = {
		type = "group", name = function() return TAB_ICON .. L["PA_Title"] end,
		suiBodyDisabled = function() return DB().enabled == false end,
		args = {
			enabled = { type = "toggle", name = function() return L["Enable"] end, order = 1,
				get = function() return DB().enabled ~= false end,
				set = function(_, value)
					DB().enabled = value
					Refresh()
					if SUI.OptionsCore and SUI.OptionsCore.ScheduleSmartRefresh then
						SUI.OptionsCore:ScheduleSmartRefresh(true)
					end
				end },
			description = { type = "description", name = function() return L["PA_Description"] end,
				order = 2, width = "full" },
			general = { type = "group", name = function() return L["PA_General"] end, order = 10, args = {
				display = { type = "select", name = function() return L["PA_Content"] end, order = 1,
					values = { all = L["PA_AllAbilities"], cooldown = L["PA_CooldownAbilities"],
						cooldown_active = L["PA_CooldownOrActiveAbilities"],
						__order = { "all", "cooldown", "cooldown_active" } },
					get = function() return DB().displayMode or "all" end,
					set = function(_, value) DB().displayMode = value; Refresh() end },
				where = { type = "group", inline = true, name = function() return L["PA_Contexts"] end,
					order = 2, args = {
						arena = ContextToggle("arena", "PA_Arena", 1),
						group = ContextToggle("group", "PA_Party", 2),
						raid = ContextToggle("raid", "PA_Raid", 3),
					} },
				showPlayer = { type = "toggle", name = function() return L["PA_ShowPlayer"] end, order = 3,
					get = function() return DB().showPlayer ~= false end,
					set = function(_, value) DB().showPlayer = value; Refresh() end },
			} },
			position = { type = "group", name = function() return L["PA_Position"] end, order = 20, args = {
				preview = { type = "description", name = "", order = 1, width = "full",
					suiPreview = "PartyAbilitiesPreview" },
				controls = { type = "group", inline = true, name = "", order = 2, suiTwoCol = true, args = {
					side = { type = "select", name = function() return L["PA_Side"] end, order = 1,
						values = { LEFT = L["PA_Left"], RIGHT = L["PA_Right"], TOP = L["PA_Up"], BOTTOM = L["PA_Down"],
							__order = { "LEFT", "RIGHT", "TOP", "BOTTOM" } },
						get = function() return Layout().side or "RIGHT" end,
						set = function(_, value) Layout().side = value; Refresh() end },
					growth = { type = "select", name = function() return L["PA_Growth"] end, order = 2,
						values = { LEFT = L["PA_Left"], RIGHT = L["PA_Right"], UP = L["PA_Up"], DOWN = L["PA_Down"],
							__order = { "RIGHT", "LEFT", "UP", "DOWN" } },
						get = function() return Layout().growth or "RIGHT" end,
						set = function(_, value) Layout().growth = value; Refresh() end },
					x = Range("x", "PA_OffsetX", -150, 150, 1, 3),
					y = Range("y", "PA_OffsetY", -150, 150, 1, 4),
					spacing = Range("spacing", "PA_Spacing", 0, 30, 1, 5),
					perRow = Range("perRow", "PA_PerRow", 1, 20, 1, 6),
					size = Range("size", "PA_Size", 12, 128, 1, 7),
				} },
				cooldownEdge = { type = "toggle", name = function() return L["PA_CooldownEdge"] end, order = 4,
					get = function() return Layout().cooldownEdge == true end,
					set = function(_, value) Layout().cooldownEdge = value; RefreshAppearance() end },
			} },
			spells = { type = "group", name = function() return L["PA_Spells"] end,
				order = 30, suiTwoPane = true, suiKeepEmptyTwoPane = true, args = {
				newID = { type = "input", name = function() return L["PA_SpellID"] end, order = 1,
					get = function() return newSpellID end,
					set = function(_, value) newSpellID = value end },
				newClass = { type = "select", name = function() return L["PA_Class"] end, order = 2,
					values = classValues, get = function() return selectedClass end,
					set = function(_, value) selectedClass = value end },
				add = { type = "execute", name = function() return L["PA_Add"] end, order = 3,
					func = function()
						local id = tonumber(newSpellID)
						if not id or id <= 0 or id ~= math.floor(id) or not GetSpellInfo(id) then
							SUI:Print(L["PA_InvalidID"]); return
						end
					DB().spells[id] = DB().spells[id] or { class = selectedClass, cooldown = 0,
							order = 100, enabled = true, glowWhen = "cooldown" }
						selectedSpell = id; viewClass = DB().spells[id].class or selectedClass
						newSpellID = ""; Rebuild()
					end },
				remove = { type = "execute", name = function() return L["PA_Remove"] end, order = 99, width = "full",
					disabled = function() return not Spell() end,
					func = function() if selectedSpell then DB().spells[selectedSpell] = nil; selectedSpell = nil; Rebuild() end end },
				spellEnabled = { type = "toggle", name = function() return L["PA_SpellEnabled"] end, order = 10,
					disabled = function() return not Spell() end,
					get = function() return Spell() and Spell().enabled ~= false end,
					set = function(_, value) Spell().enabled = value; Refresh() end },
				tuning = { type = "group", inline = true, name = "", order = 11, args = {
					cooldown = { type = "range", name = function() return L["PA_Cooldown"] end, order = 1,
						min = 0, max = 1200, step = 1, disabled = function() return not Spell() end,
						get = function()
							local spell = Spell()
							local value = spell and tonumber(spell.cooldown)
							return value or 0
						end,
						set = function(_, value)
							local spell = Spell()
							if not spell then return end
							spell.cooldown = value
							ApplySpell()
						end },
					order = { type = "range", name = function() return L["PA_Order"] end, order = 2,
						min = 1, max = 999, step = 1, disabled = function() return not Spell() end,
						get = function()
							local spell = Spell()
							return (spell and tonumber(spell.order)) or 100
						end,
						set = function(_, value)
							local spell = Spell()
							if not spell then return end
							spell.order = value
							ApplySpell()
						end },
					iconSize = { type = "range", name = function() return L["PA_IconSize"] end, order = 3,
						min = 12, max = 64, step = 1, disabled = function() return not Spell() end,
						get = function()
							local spell = Spell()
							return (spell and tonumber(spell.size)) or 24
						end,
						set = function(_, value)
							local spell = Spell()
							if not spell then return end
							spell.size = value
							ApplySpell()
						end },
				} },
				glow = { type = "group", inline = true, name = function() return L["PA_Glow"] end,
					order = 20, suiTwoCol = true, args = {
				enabled = { type = "toggle", name = function() return L["PA_Glow"] end, order = 1,
					disabled = function() return not Spell() end,
					get = function()
						local value = Spell() and Spell().highlight
						return value ~= nil and value ~= false and value ~= 0
					end,
					set = function(_, value) Spell().highlight = value and 1 or 0; Refresh() end },
				glowType = { type = "select", name = function() return L["PA_GlowType"] end, order = 2,
					values = { border = L["PA_Border"], Pixel = L["PA_Pixel"], ACShine = L["PA_AutoCast"],
						buttonOverlay = L["PA_ButtonGlow"], proc = SUI:T("ui.cooldowns.proc_glow"), __order = { "border", "Pixel", "ACShine", "buttonOverlay", "proc" } },
					hidden = function() return not GlowEnabled() end,
					get = function() return GlowKind() end,
					set = function(_, value) Spell().glowType = value; Refresh() end },
				glowWhen = { type = "select", name = function() return L["PA_GlowWhen"] end, order = 3,
					values = { always = L["PA_Always"], cooldown = L["PA_OnlyCooldown"], ready = L["PA_OnlyReady"],
						active = L["PA_WhileActive"],
						__order = { "always", "cooldown", "ready", "active" } },
					hidden = function() return not GlowEnabled() end,
					get = function() return Spell() and (Spell().glowWhen or "cooldown") end,
					set = function(_, value) Spell().glowWhen = value; ApplySpell() end },
				useGlowColor = { type = "toggle", name = function() return L["PA_UseGlowColor"] end, order = 4,
					hidden = function() return not GlowEnabled() or GlowKind() == "border" end,
					get = function() return Spell() and Spell().useGlowColor and true or false end,
					set = function(_, value) Spell().useGlowColor = value and true or false; Refresh() end },
				glowColor = { type = "color", name = function() return L["PA_GlowColor"] end, order = 5,
					hasAlpha = true, hidden = function() return not GlowEnabled() end,
					disabled = function()
						if GlowKind() == "border" then return false end
						return not (Spell() and Spell().useGlowColor)
					end,
					get = function()
						local c = Spell() and Spell().highlightColor or { 0, 0.7, 1, 1 }
						return c[1] or 0, c[2] or 0.7, c[3] or 1, c[4] or 1
					end,
					set = function(_, r, g, b, a)
						Spell().highlightColor = { r, g, b, a }
						ApplySpell()
					end },
				glowDuration = { type = "range", name = function() return SUI:T("ui.cooldowns.glow_cycle_duration") end,
                    order = 5.5, min = 0.1, max = 5, step = 0.1,
                    hidden = function() return not GlowEnabled() or GlowKind() ~= "proc" end,
                    get = function() return tonumber(Spell() and Spell().glowDuration) or 1 end,
                    set = function(_, value) Spell().glowDuration = value; ApplySpell() end },
				glowLines = { type = "range", name = function() return L["PA_GlowLines"] end, order = 6,
					min = 1, max = 30, step = 1,
					hidden = function()
						local kind = GlowKind()
						return not GlowEnabled() or kind == "border" or kind == "buttonOverlay" or kind == "proc"
					end,
					get = function() return Spell() and (tonumber(Spell().glowLines) or 8) or 8 end,
					set = function(_, value) Spell().glowLines = value; ApplySpell() end },
				glowSpeed = { type = "range", name = function() return L["PA_GlowSpeed"] end, order = 7,
					min = -2, max = 2, step = 0.05,
					hidden = function()
						local kind = GlowKind()
						return not GlowEnabled() or kind == "border" or kind == "buttonOverlay" or kind == "proc"
					end,
					get = function() return Spell() and (tonumber(Spell().glowFrequency) or 0.25) or 0.25 end,
					set = function(_, value) Spell().glowFrequency = value; ApplySpell() end },
				glowLength = { type = "range", name = function() return L["PA_GlowLength"] end, order = 8,
					min = 1, max = 20, step = 0.05,
					hidden = function() return not GlowEnabled() or GlowKind() ~= "Pixel" end,
					get = function() return Spell() and (tonumber(Spell().glowLength) or 10) or 10 end,
					set = function(_, value) Spell().glowLength = value; ApplySpell() end },
				glowThickness = { type = "range", name = function() return L["PA_GlowThickness"] end, order = 9,
					min = 0.05, max = 20, step = 0.05,
					hidden = function() return not GlowEnabled() or GlowKind() ~= "Pixel" end,
					get = function() return Spell() and (tonumber(Spell().glowThickness) or 1) or 1 end,
					set = function(_, value) Spell().glowThickness = value; ApplySpell() end },
				glowX = { type = "range", name = function() return L["PA_GlowOffsetX"] end, order = 10,
					min = -100, max = 100, step = 0.5,
					hidden = function()
						local kind = GlowKind()
						return not GlowEnabled() or kind == "border" or kind == "buttonOverlay" or kind == "proc"
					end,
					get = function() return Spell() and (tonumber(Spell().glowXOffset) or 0) or 0 end,
					set = function(_, value) Spell().glowXOffset = value; ApplySpell() end },
				glowY = { type = "range", name = function() return L["PA_GlowOffsetY"] end, order = 11,
					min = -100, max = 100, step = 0.5,
					hidden = function()
						local kind = GlowKind()
						return not GlowEnabled() or kind == "border" or kind == "buttonOverlay" or kind == "proc"
					end,
					get = function() return Spell() and (tonumber(Spell().glowYOffset) or 0) or 0 end,
					set = function(_, value) Spell().glowYOffset = value; ApplySpell() end },
				glowScale = { type = "range", name = function() return L["PA_GlowScale"] end, order = 12,
					min = 0.05, max = 10, step = 0.05,
					hidden = function() return not GlowEnabled() or GlowKind() ~= "ACShine" end,
					get = function() return Spell() and (tonumber(Spell().glowScale) or 1) or 1 end,
					set = function(_, value) Spell().glowScale = value; ApplySpell() end },
				glowBorder = { type = "toggle", name = function() return L["PA_GlowBorder"] end, order = 13,
					hidden = function() return not GlowEnabled() or GlowKind() ~= "Pixel" end,
					get = function() return Spell() and Spell().glowBorder and true or false end,
					set = function(_, value) Spell().glowBorder = value and true or false; ApplySpell() end },
				} },
			} },
		},
	}
	if forGroupFrames then
		group.args.general.args.enabled = group.args.enabled
		group.args.enabled.name = SarychUI:T("ui.enable_a54eaf37")
		group.args.enabled.order = 0
		return group.args.general, group.args.position
	end
	group.args.general.args = {}
	group.args.general.args.enabled = {
		type = "toggle", name = "ui.enable_module_b623b573", order = 0,
		get = function() return DB().masterEnabled ~= false end,
		set = function(_, value)
			DB().masterEnabled = value
			extension:RefreshConfig()
		end,
	}
	group.args.position = nil
	group.args.enabled = nil
	group.args.description = nil
	group.suiBodyDisabled = nil
	local spells = group.args.spells
	local old = spells.args
	local controls = { enabled = old.spellEnabled }
	controls.enabled.name = function() return L["Enable"] end
	for key, option in pairs(old) do
		if key ~= "newID" and key ~= "newClass" and key ~= "add"
			and key ~= "spellEnabled" then controls[key] = option end
	end
	old.newID.suiSaveButton = L["PA_Add"]
	old.newID.suiOnDraft = function(value) newSpellID = value or "" end
	old.newID.set = function(_, value)
		newSpellID = value or ""
		old.add.func()
	end
	spells.args = {
		addSpell = { type = "group", inline = true, suiOneRowAdd = true,
			name = function() return L["PA_AddSpell"] end, order = 1,
			args = { spellType = old.newClass, spellID = old.newID } },
		configure = { type = "group", inline = true, suiSelectWithButton = true,
			name = function() return L["PA_ConfigureSpells"] end, order = 2,
			args = { select = { type = "select", order = 1,
				name = "", values = classValues,
				get = function() return viewClass end,
				set = function(_, value) viewClass = value; selectedSpell = nil; Rebuild() end },
				button = { type = "execute", order = 2, name = function() return L["PA_Default"] end,
					confirm = function() return L["PA_ResetConfirm"] end,
					func = function() extension:ResetSpellDefaults(); selectedSpell = nil; Rebuild() end } } },
	}
	for id, data in pairs(db.spells) do
		if data.class == viewClass then
			local spellID = id
			spells.args["spell" .. spellID] = { type = "group", order = tonumber(data.order) or 100,
				name = function() return extension:EntryLabel(spellID, DB().spells[spellID]) end,
				icon = function() return extension:EntryIcon(spellID, DB().spells[spellID]) end,
				desc = function()
					local spell = DB().spells[spellID]
					if spell and spell.item then return "Item: " .. spell.item end
					return "ID: " .. spellID
				end,
				suiOnSelect = function() selectedSpell = spellID end,
				args = BindSpellControls(controls, spellID) }
		end
	end
	if self.AddEnemyDisplayOptions then self:AddEnemyDisplayOptions(group) end
	return group
end
