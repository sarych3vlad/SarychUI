local SUI = SarychUI
local extension = SUI.extensions.diminishings

-- One recognizable spell from each WotLK DR category, used only for option labels.
local categoryIconSpells = {
	incapacitate = 118, stun = 853, random_stun = 12355,
	random_root = 12494, root = 339, disarm = 676,
	fear = 5782, scatter = 19503, silence = 15487,
	horror = 64044, mind_control = 605, cyclone = 33786,
	charge = 7922, opener_stun = 1833, counterattack = 19306,
}

local function CategoryLabel(category, label)
	local spellID = categoryIconSpells[category]
	local texture = spellID and GetSpellInfo and select(3, GetSpellInfo(spellID))
	texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"
	return string.format("|T%s:22:22:0:0|t %s", texture, label)
end

local function Refresh()
	extension:ResetPreview()
	extension:Refresh()
end

local function RefreshArena()
	local arena = SUI.modules and SUI.modules.arena
	if arena then
		if arena.ApplyFrameSpacing then arena:ApplyFrameSpacing() end
		if arena.ApplySettings then arena:ApplySettings() end
	end
	if SUI.ArenaPreview and SUI.ArenaPreview.RefreshAll then
		SUI.ArenaPreview:RefreshAll()
	end
	if SUI.OptionsCore and SUI.OptionsCore.InvalidateStructure then
		SUI.OptionsCore:InvalidateStructure()
	end
	if SUI.NotifySarychUIOptionsChange then SUI:NotifySarychUIOptionsChange() end
end

local function Toggle(key, name, order)
	return {
		type = "toggle", name = name, order = order,
		get = function() return extension:GetDB()[key] ~= false end,
		set = function(_, value)
			extension:GetDB()[key] = value and true or false
			Refresh()
		end,
	}
end

local function Color(key, name, order, fallback)
	return {
		type = "color", name = name, order = order,
		get = function()
			local c = extension:GetDB()[key] or fallback
			return c.r, c.g, c.b
		end,
		set = function(_, r, g, b)
			extension:GetDB()[key] = { r = r, g = g, b = b }
			Refresh()
		end,
	}
end

function extension:GetOptions()
	local options = {
		type = "group", name = "ui.text_8cb12044",
		childGroups = "tab", suiWrapTabs = true,
		suiBodyDisabled = function() return not extension:IsEnabled() end,
		args = {
			enabled = {
				type = "toggle", name = "ui.enable_a54eaf37", order = 1,
				get = function() return extension:IsEnabled() end,
				set = function(_, value)
					if value then SUI:EnableModule("diminishings")
					else SUI:DisableModule("diminishings") end
					RefreshArena()
				end,
			},
			general = {
				type = "group", name = "ui.main_11355a29", order = 1,
				args = {
					where = {
						type = "group", name = "ui.enable_a54eaf37", order = 1,
						inline = true, args = {
							arena = {
								type = "toggle", name = "ui.arena_cada76b8", order = 1,
								get = function() return extension:GetDB().arena ~= false end,
								set = function(_, value)
									extension:GetDB().arena = value and true or false
									Refresh()
									RefreshArena()
								end,
							},
							player = {
								type = "toggle", name = "ui.player_f54f58cf", order = 2,
								get = function() return extension:GetDB().player == true end,
								set = function(_, value)
									if not value and extension.StopFreeMoveKind then
										extension:StopFreeMoveKind("player")
									end
									extension:GetDB().player = value and true or false
									Refresh(); RefreshArena()
								end,
							},
							target = {
								type = "toggle", name = "ui.target_1d6ae787", order = 3,
								get = function() return extension:GetDB().target == true end,
								set = function(_, value)
									if not value and extension.StopFreeMoveKind then
										extension:StopFreeMoveKind("target")
									end
									extension:GetDB().target = value and true or false
									Refresh(); RefreshArena()
								end,
							},
							focus = {
								type = "toggle", name = "ui.focus_1913a1d2", order = 4,
								get = function() return extension:GetDB().focus == true end,
								set = function(_, value)
									if not value and extension.StopFreeMoveKind then
										extension:StopFreeMoveKind("focus")
									end
									extension:GetDB().focus = value and true or false
									Refresh(); RefreshArena()
								end,
							},
							party = {
								type = "toggle", name = "ui.party_907efbd4", order = 5,
								get = function() return extension:GetDB().party == true end,
								set = function(_, value)
									if not value and extension.StopFreeMoveKind then
										extension:StopFreeMoveKind("party")
									end
									extension:GetDB().party = value and true or false
									Refresh(); RefreshArena()
								end,
							},
						},
					},
					scope = {
						type = "group", name = "ui.text_c9dd9d4e", order = 2,
						inline = true, args = {
							mode = {
								type = "select", name = "ui.show_d61d6efc", order = 1,
								values = { arena = SarychUI:T("ui.options_530d64934f"), all = SarychUI:T("ui.options_eb3a227136"),
									__order = { "arena", "all" } },
								get = function()
									return extension:GetDB().displayScope == "all" and "all" or "arena"
								end,
								set = function(_, value)
									extension:GetDB().displayScope = value == "all" and "all" or "arena"
									Refresh()
								end,
							},
						},
					},
					test = {
						type = "group", name = "ui.test_mode_562448df", order = 3,
						inline = true, args = {
							enabled = {
								type = "execute", order = 1, width = "full", suiFullRow = true,
								name = function()
									return extension.previewEnabled
										and SarychUI:T("ui.options_e3cfa5d003")
										or SarychUI:T("ui.options_98d7deec1d")
								end,
								func = function()
									extension.previewEnabled = not extension.previewEnabled
									Refresh()
									if SUI.NotifySarychUIOptionsChange then SUI:NotifySarychUIOptionsChange() end
								end,
							},
						},
					},
				},
			},
			settings = {
				type = "group", name = "ui.dr_54e62d9a", order = 2,
				args = {
			timer = {
				type = "group", name = "ui.dr_a32578d7", order = 1,
				inline = true, suiTwoCol = true, args = {
					duration = {
						type = "range", name = "ui.dr_24b3c447", order = 1,
						min = 15, max = 20, step = 0.1, width = "full", suiSpanTwoCols = true,
						get = function() return tonumber(extension:GetDB().duration) or 18 end,
						set = function(_, value)
							extension:GetDB().duration = value
							Refresh()
						end,
					},
				},
			},
			categories = {
				type = "group", name = "ui.text_117a6f88", order = 3,
				inline = true, suiTwoCol = true, args = {},
			},
			pulse = {
				type = "group", name = "ui.dr_713b70b0", order = 2,
				inline = true, suiTwoCol = true, args = {
					pulseLastFive = Toggle("pulseLastFive", SarychUI:T("ui.options_fdf0d000b0"), 1),
					pulseThreshold = {
						type = "range", name = "ui.text_463fa48e", order = 2,
						min = 1, max = 20, step = 0.5, width = "full",
						disabled = function() return extension:GetDB().pulseLastFive == false end,
						get = function() return tonumber(extension:GetDB().pulseThreshold) or 5 end,
						set = function(_, value)
							extension:GetDB().pulseThreshold = value
							Refresh()
						end,
					},
				},
			},
				},
			},
			appearance = {
				type = "group", name = "ui.appearance_c407960b", order = 3,
				args = {
			display = {
				type = "group", name = "ui.text_7bd23f05", order = 1,
				inline = true, suiTwoCol = true, args = {
					showSweep = Toggle("showSweep", SarychUI:T("ui.options_2213ea6ce0"), 1),
					cooldownEdge = {
						type = "toggle", name = "ui.text_b5c7e6df", order = 2,
						desc = "ui.text_59ed60d3",
						get = function() return extension:GetDB().cooldownEdge == true end,
						set = function(_, value)
							extension:GetDB().cooldownEdge = value and true or false
							Refresh()
						end,
					},
					borderColors = Toggle("borderColors", SarychUI:T("ui.options_4ae4c22b51"), 3),
				},
			},
			colors = {
				type = "group", name = "ui.text_175f108b", order = 2,
				inline = true, suiThreeCol = true, args = {
					half = Color("halfColor", SarychUI:T("ui.options_a939f994e8"), 1, { r = 1, g = 1, b = 0 }),
					quarter = Color("quarterColor", SarychUI:T("ui.options_00c4edc34f"), 2, { r = 1, g = 0.4, b = 0 }),
					immune = Color("immuneColor", SarychUI:T("ui.options_41cefae364"), 3, { r = 1, g = 0, b = 0 }),
				},
			},
				},
			},
			frameSettings = {
				type = "group", name = "ui.text_f19b13c1", order = 4,
				childGroups = "tab", args = {},
				hidden = function()
					local db = extension:GetDB()
					return not (db.player or db.target or db.focus or db.party)
				end,
			},
		},
	}
	local anchors = {
		NONE = SarychUI:T("ui.options_dc3a407310"),
		TOPLEFT = SarychUI:T("ui.options_2049f0b17e"), TOP = SarychUI:T("ui.options_aa6b22c2d4"), TOPRIGHT = SarychUI:T("ui.options_d94b5bdb98"),
		LEFT = SarychUI:T("ui.options_4af2530fc3"), CENTER = SarychUI:T("ui.options_fd17e2f9ce"), RIGHT = SarychUI:T("ui.options_600c48eb0b"),
		BOTTOMLEFT = SarychUI:T("ui.options_1730600b76"), BOTTOM = SarychUI:T("ui.options_fa1881309a"), BOTTOMRIGHT = SarychUI:T("ui.options_083baaa71e"),
		__order = { "NONE", "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT",
			"BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
	}
	local directions = { RIGHT = SarychUI:T("ui.options_85d9486df1"), LEFT = SarychUI:T("ui.options_b52750122c"), UP = SarychUI:T("ui.options_7032fca89d"), DOWN = SarychUI:T("ui.options_7e3eb48e2c"),
		__order = { "RIGHT", "LEFT", "UP", "DOWN" } }
	local defaults = {
		player = { x = 40, y = 20, size = 30, spacing = 3, anchor = "TOPLEFT", growth = "RIGHT" },
		target = { x = -40, y = 20, size = 30, spacing = 3, anchor = "TOPRIGHT", growth = "LEFT" },
		focus = { x = -40, y = 20, size = 30, spacing = 3, anchor = "TOPRIGHT", growth = "LEFT" },
		party = { x = 0, y = 15, size = 20, spacing = 3, anchor = "TOPLEFT", growth = "RIGHT" },
	}
	local frameNames = { player = SarychUI:T("ui.player_f54f58cf"), target = SarychUI:T("ui.target_1d6ae787"), focus = SarychUI:T("ui.focus_1913a1d2"), party = SarychUI:T("ui.party_907efbd4") }
	local function FrameOption(kind, key, name, order, optionType, extra)
		local option = { type = optionType, name = name, order = order }
		for field, value in pairs(extra or {}) do option[field] = value end
		option.get = function()
			local db = extension:GetDB()
			local settings = db.frames and db.frames[kind]
			return settings and settings[key] ~= nil and settings[key] or defaults[kind][key]
		end
		option.set = function(_, value)
			if key == "anchor" and value ~= "NONE" and extension.StopFreeMoveKind then
				extension:StopFreeMoveKind(kind)
			end
			local db = extension:GetDB()
			db.frames = db.frames or {}
			db.frames[kind] = db.frames[kind] or {}
			db.frames[kind][key] = value
			Refresh()
		end
		return option
	end
	for order, kind in ipairs({ "player", "target", "focus", "party" }) do
		options.args.frameSettings.args[kind] = {
			type = "group", name = frameNames[kind], order = order,
			hidden = function() return extension:GetDB()[kind] ~= true end,
			args = {
				anchor = FrameOption(kind, "anchor", SarychUI:T("ui.options_d04329afc1"), 1, "select", { values = anchors }),
				growth = FrameOption(kind, "growth", SarychUI:T("ui.text_d6f132e5"), 2, "select", { values = directions }),
				x = FrameOption(kind, "x", SarychUI:T("ui.options_a3d6a6c502"), 3, "range", { min = -300, max = 300, step = 1 }),
				y = FrameOption(kind, "y", SarychUI:T("ui.options_322c955d5f"), 4, "range", { min = -300, max = 300, step = 1 }),
				size = FrameOption(kind, "size", SarychUI:T("ui.icon_size_040a2fda"), 5, "range", { min = 12, max = 80, step = 1 }),
				spacing = FrameOption(kind, "spacing", SarychUI:T("ui.spacing_between_icons_a9f8eb20"), 6,
					"range", { min = 0, max = 30, step = 1 }),
			},
		}
		local args = options.args.frameSettings.args[kind].args
		local units = kind == "party" and { "party1", "party2", "party3", "party4" } or { kind }
		for i, unit in ipairs(units) do
			local token = unit
			local member = i
			args["freeMove" .. i] = {
				type = "execute", order = 7 + i,
				name = function()
					local label = kind == "party" and (SarychUI:T("ui.options_71d19ee81f") .. member)
						or SarychUI:T("ui.options_0510004a87")
						if extension.IsFreeMoveActive and extension:IsFreeMoveActive(token) then
							return label .. SarychUI:T("ui.options_86bab9d866")
						end
						return label
				end,
				desc = "ui.dr_7b3e1403",
				width = "full", suiFullRow = true,
				hidden = function()
					local db = extension:GetDB()
					return not (db.frames and db.frames[kind]
						and db.frames[kind].anchor == "NONE")
				end,
				func = function()
					if extension.ToggleFreeMove then extension:ToggleFreeMove(token) end
					if SUI.NotifySarychUIOptionsChange then SUI:NotifySarychUIOptionsChange() end
				end,
			}
		end
		for _, key in ipairs({ "x", "y" }) do
			args[key].hidden = function()
				local db = extension:GetDB()
				return db.frames and db.frames[kind] and db.frames[kind].anchor == "NONE"
			end
		end
	end
	local library = LibStub and LibStub("DRList-1.0", true)
	if library then
		local names = {
			incapacitate = SarychUI:T("ui.options_77e6d89434"), stun = SarychUI:T("ui.options_f613a40d8a"), random_stun = SarychUI:T("ui.options_ec80e21f79"),
			random_root = SarychUI:T("ui.options_b5ed0fd19b"), root = SarychUI:T("ui.options_925561e157"), disarm = SarychUI:T("ui.options_1546bb4b80"),
			fear = SarychUI:T("ui.options_2daa1dda18"), scatter = SarychUI:T("ui.options_1add2bf047"), silence = SarychUI:T("ui.options_c7d6916b66"), horror = SarychUI:T("ui.options_a780bf0d28"),
			mind_control = SarychUI:T("ui.options_d93e04f383"), cyclone = SarychUI:T("ui.options_282793904f"), charge = SarychUI:T("ui.options_b38424012a"),
			opener_stun = SarychUI:T("ui.options_aaa0ad4b38"), counterattack = SarychUI:T("ui.options_032f264197"),
		}
		local categories = {}
		for category in pairs(library:GetCategories()) do categories[#categories + 1] = category end
		table.sort(categories)
		for order, category in ipairs(categories) do
			local key = category
			local label = names[key] or library:GetCategoryName(key) or key
			options.args.settings.args.categories.args[key] = {
				type = "toggle", name = function() return CategoryLabel(key, label) end,
				order = order,
				get = function()
					local cfg = extension:GetDB()
					return not cfg.categories or cfg.categories[key] ~= false
				end,
				set = function(_, value)
					local cfg = extension:GetDB()
					cfg.categories = cfg.categories or {}
					cfg.categories[key] = value and true or false
					extension:Refresh()
				end,
			}
		end
	end
	return options
end
