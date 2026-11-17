local E, L, V, P, G = unpack(_G.SarychUI_ElvUI_NamePlates) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local ACD = E.Libs.AceConfigDialog

-- Standalone app name used to register the options table with AceConfig.
local APP = "SarychUI_ElvUI_NamePlates"

-- Navigate ElvUI NamePlates AceConfigDialog.
local function ENPSelectGroup(...)
	if ACD and ACD.SelectGroup then
		ACD:SelectGroup(APP, ...)
	end
end

-- Minimal config namespace (ElvUI_OptionsUI provides C.Values; we only need FontFlags).
local C = { Values = { FontFlags = {
	NONE = L["None"],
	OUTLINE = "OUTLINE",
	MONOCHROME = "MONOCHROME",
	MONOCHROMEOUTLINE = "MONOCHROME OUTLINE",
	THICKOUTLINE = "THICK OUTLINE"
} } }

-- Standalone options container. "NamePlates" (E.Options.args.nameplate) becomes the
-- root tree node; its children (General Options / unit groups) form the
-- left-hand tree exactly like the ElvUI config. This mirrors ElvUI 1:1 where the whole
-- NamePlates tree is adapted from the original ElvUI_OptionsUI/Nameplates.lua source.
E.Options = E.Options or { type = "group", name = "ElvUI NamePlates", args = {} }

local pairs = pairs

local ORDER = 100
local function GetUnitSettings(unit, name)
	local copyValues = {}
	for x, y in pairs(NP.db.units) do
		if type(y) == "table" and (x ~= unit) and (x ~= "TARGET") then
			copyValues[x] = L[x]
		end
	end
	local group = {
		order = ORDER,
		type = "group",
		name = name,
		childGroups = "tab",
		get = function(info) return E.db.nameplates.units[unit][info[#info]] end,
		set = function(info, value) E.db.nameplates.units[unit][info[#info]] = value NP:ConfigureAll() end,
		disabled = function() return not E.NamePlates.Initialized end,
		args = {
			showTestFrame = {
				order = -10,
				name = L["Show/Hide Test Frame"],
				type = "execute",
				func = function(info)
					NP:TogleTestFrame(unit)
				end
			},
			copySettings = {
				order = -9,
				type = "select",
				name = L["Copy Settings From"],
				desc = L["Copy settings from another unit."],
				values = copyValues,
				get = function() return "" end,
				set = function(info, value)
					NP:CopySettings(value, unit)
					NP:ConfigureAll()
				end
			},
			defaultSettings = {
				order = -8,
				type = "execute",
				name = L["Default Settings"],
				desc = L["Set Settings to Default"],
				func = function(info)
					NP:ResetSettings(unit)
					NP:ConfigureAll()
				end
			},
			healthGroup = {
				order = 1,
				type = "group",
				name = L["HEALTH"],
				get = function(info) return E.db.nameplates.units[unit].health[info[#info]] end,
				set = function(info, value) E.db.nameplates.units[unit].health[info[#info]] = value NP:ConfigureAll() end,
				args = {
					header = {
						order = 1,
						type = "header",
						name = L["HEALTH"]
					},
					enable = {
						order = 2,
						type = "toggle",
						name = L["Enable"]
					},
					height = {
						order = 3,
						type = "range",
						name = L["Height"],
						min = 4, max = 20, step = 1
					},
					width = {
						order = 4,
						type = "range",
						name = L["Width"],
						min = 50, max = 200, step = 1
					},
					textGroup = {
						order = 5,
						type = "group",
						name = L["Text"],
						guiInline = true,
						get = function(info)
							return E.db.nameplates.units[unit].health.text[info[#info]]
						end,
						set = function(info, value)
							E.db.nameplates.units[unit].health.text[info[#info]] = value
							NP:ConfigureAll()
						end,
						args = {
							enable = {
								order = 1,
								type = "toggle",
								name = L["Enable"]
							},
							format = {
								order = 2,
								type = "select",
								name = L["Format"],
								values = {
									["CURRENT"] = L["Current"],
									["CURRENT_MAX"] = L["Current / Max"],
									["CURRENT_PERCENT"] = L["Current - Percent"],
									["CURRENT_MAX_PERCENT"] = L["Current - Max | Percent"],
									["PERCENT"] = L["Percent"],
									["DEFICIT"] = L["Deficit"]
								}
							},
							position = {
								order = 3,
								type = "select",
								name = L["Position"],
								values = {
									["CENTER"] = "CENTER",
									["TOPLEFT"] = "TOPLEFT",
									["BOTTOMLEFT"] = "BOTTOMLEFT",
									["TOPRIGHT"] = "TOPRIGHT",
									["BOTTOMRIGHT"] = "BOTTOMRIGHT"
								}
							},
							parent = {
								order = 4,
								type = "select",
								name = L["Parent"],
								values = {
									["Nameplate"] = L["Nameplate"],
									["Health"] = L["Health"]
								}
							},
							xOffset = {
								order = 5,
								type = "range",
								name = L["X-Offset"],
								min = -100, max = 100, step = 1
							},
							yOffset = {
								order = 6,
								type = "range",
								name = L["Y-Offset"],
								min = -100, max = 100, step = 1
							},
							fontGroup = {
								type = "group",
								order = 7,
								name = L["Fonts"],
								guiInline = true,
								get = function(info)
									return E.db.nameplates.units[unit].health.text[info[#info]]
								end,
								set = function(info, value)
									E.db.nameplates.units[unit].health.text[info[#info]] = value
									NP:ConfigureAll()
								end,
								args = {
									font = {
										order = 1,
										type = "select",
										name = L["Font"],
										dialogControl = "LSM30_Font",
										values = AceGUIWidgetLSMlists.font
									},
									fontSize = {
										order = 2,
										name = L["FONT_SIZE"],
										type = "range",
										min = 4, max = 32, step = 1
									},
									fontOutline = {
										order = 3,
										type = "select",
										name = L["Font Outline"],
										desc = L["Set the font outline."],
										values = C.Values.FontFlags
									}
								}
							}
						}
					}
				}
			},
			castGroup = {
				order = 2,
				type = "group",
				name = L["Cast Bar"],
				get = function(info) return E.db.nameplates.units[unit].castbar[info[#info]] end,
				set = function(info, value) E.db.nameplates.units[unit].castbar[info[#info]] = value; NP:ConfigureAll() end,
				args = {
					header = {
						order = 0,
						type = "header",
						name = L["Cast Bar"]
					},
					enable = {
						order = 1,
						type = "toggle",
						name = L["Enable"]
					},
					timeToHold = {
						order = 2,
						type = "range",
						name = L["Time To Hold"],
						desc = L["How many seconds the castbar should stay visible after the cast failed or was interrupted."],
						min = 0, max = 4, step = 0.1
					},
					width = {
						order = 3,
						type = "range",
						name = L["Width"],
						min = 50, max = 250, step = 1
					},
					height = {
						order = 4,
						type = "range",
						name = L["Height"],
						min = 4, max = 20, step = 1
					},
					xOffset = {
						order = 5,
						type = "range",
						name = L["X-Offset"],
						min = -100, max = 100, step = 1
					},
					yOffset = {
						order = 6,
						type = "range",
						name = L["Y-Offset"],
						min = -100, max = 100, step = 1
					},
					textGroup = {
						order = 7,
						type = "group",
						name = L["Text"],
						get = function(info)
							return E.db.nameplates.units[unit].castbar[info[#info]]
						end,
						set = function(info, value)
							E.db.nameplates.units[unit].castbar[info[#info]] = value
							NP:ConfigureAll()
						end,
						guiInline = true,
						args = {
							hideSpellName = {
								order = 1,
								type = "toggle",
								name = L["Hide Spell Name"]
							},
							hideTime = {
								order = 2,
								type = "toggle",
								name = L["Hide Time"]
							},
							textPosition = {
								order = 3,
								type = "select",
								name = L["Text Position"],
								values = {
									["ONBAR"] = L["Cast Bar"],
									["ABOVE"] = L["Above"],
									["BELOW"] = L["Below"]
								}
							},
							castTimeFormat = {
								order = 4,
								type = "select",
								name = L["Cast Time Format"],
								values = {
									["CURRENT"] = L["Current"],
									["CURRENTMAX"] = L["Current / Max"],
									["REMAINING"] = L["Remaining"],
									["REMAININGMAX"] = L["Remaining / Max"]
								}
							},
							channelTimeFormat = {
								order = 5,
								type = "select",
								name = L["Channel Time Format"],
								values = {
									["CURRENT"] = L["Current"],
									["CURRENTMAX"] = L["Current / Max"],
									["REMAINING"] = L["Remaining"],
									["REMAININGMAX"] = L["Remaining / Max"]
								}
							}
						}
					},
					iconGroup = {
						order = 8,
						name = L["Icon"],
						type = "group",
						get = function(info)
							return E.db.nameplates.units[unit].castbar[info[#info]]
						end,
						set = function(info, value)
							E.db.nameplates.units[unit].castbar[info[#info]] = value
							NP:ConfigureAll()
						end,
						guiInline = true,
						args = {
							showIcon = {
								order = 11,
								type = "toggle",
								name = L["Show Icon"]
							},
							iconPosition = {
								order = 12,
								type = "select",
								name = L["Icon Position"],
								values = {
									["LEFT"] = L["Left"],
									["RIGHT"] = L["Right"]
								}
							},
							iconSize = {
								order = 13,
								name = L["Icon Size"],
								type = "range",
								min = 4, max = 40, step = 1
							},
							iconOffsetX = {
								order = 14,
								name = L["X-Offset"],
								type = "range",
								min = -100, max = 100, step = 1
							},
							iconOffsetY = {
								order = 15,
								name = L["Y-Offset"],
								type = "range",
								min = -100, max = 100, step = 1
							}
						}
					},
					fontGroup = {
						type = "group",
						order = 30,
						name = L["Font"],
						guiInline = true,
						get = function(info)
							return E.db.nameplates.units[unit].castbar[info[#info]]
						end,
						set = function(info, value)
							E.db.nameplates.units[unit].castbar[info[#info]] = value
							NP:ConfigureAll()
						end,
						args = {
							font = {
								order = 1,
								type = "select",
								name = L["Font"],
								dialogControl = "LSM30_Font",
								values = AceGUIWidgetLSMlists.font
							},
							fontSize = {
								order = 2,
								name = L["FONT_SIZE"],
								type = "range",
								min = 4, max = 60, step = 1
							},
							fontOutline = {
								order = 3,
								type = "select",
								name = L["Font Outline"],
								desc = L["Set the font outline."],
								values = C.Values.FontFlags
							}
						}
					}
				}
			},
			levelGroup = {
				order = 5,
				name = L["LEVEL"],
				type = "group",
				get = function(info)
					return E.db.nameplates.units[unit].level[info[#info]]
				end,
				set = function(info, value)
					E.db.nameplates.units[unit].level[info[#info]] = value
					NP:ConfigureAll()
				end,
				args = {
					header = {
						order = 0,
						type = "header",
						name = L["LEVEL"]
					},
					enable = {
						order = 1,
						type = "toggle",
						name = L["Enable"]
					},
					position = {
						order = 2,
						type = "select",
						name = L["Position"],
						values = {
							["TOP"] = "TOP",
							["LEFT"] = "LEFT",
							["BOTTOM"] = "BOTTOM",
							["CENTER"] = "CENTER",
							["TOPLEFT"] = "TOPLEFT",
							["BOTTOMLEFT"] = "BOTTOMLEFT",
							["BOTTOMRIGHT"] = "BOTTOMRIGHT",
							["RIGHT"] = "RIGHT",
							["TOPRIGHT"] = "TOPRIGHT"
						}
					},
					parent = {
						order = 3,
						type = "select",
						name = L["Parent"],
						values = {
							["Nameplate"] = L["Nameplate"],
							["Health"] = L["Health"]
						}
					},
					xOffset = {
						order = 4,
						name = L["X-Offset"],
						type = "range",
						min = -100,
						max = 100,
						step = 1
					},
					yOffset = {
						order = 5,
						name = L["Y-Offset"],
						type = "range",
						min = -100,
						max = 100,
						step = 1
					},
					fontGroup = {
						type = "group",
						order = 6,
						name = L["Fonts"],
						guiInline = true,
						get = function(info)
							return E.db.nameplates.units[unit].level[info[#info]]
						end,
						set = function(info, value)
							E.db.nameplates.units[unit].level[info[#info]] = value
							NP:ConfigureAll()
						end,
						args = {
							font = {
								order = 1,
								type = "select",
								name = L["Font"],
								dialogControl = "LSM30_Font",
								values = AceGUIWidgetLSMlists.font
							},
							fontSize = {
								order = 2,
								name = L["FONT_SIZE"],
								type = "range",
								min = 4, max = 32, step = 1
							},
							fontOutline = {
								order = 3,
								type = "select",
								name = L["Font Outline"],
								desc = L["Set the font outline."],
								values = C.Values.FontFlags
							}
						}
					}
				}
			},
			nameGroup = {
				order = 6,
				type = "group",
				name = L["Name"],
				get = function(info)
					return E.db.nameplates.units[unit].name[info[#info]]
				end,
				set = function(info, value)
					E.db.nameplates.units[unit].name[info[#info]] = value
					NP:ConfigureAll()
				end,
				args = {
					header = {
						order = 0,
						type = "header",
						name = L["Name"]
					},
					enable = {
						order = 1,
						type = "toggle",
						name = L["Enable"]
					},
					abbrev = {
						order = 2,
						type = "toggle",
						name = L["Abbreviation"]
					},
					noAbbreviation = {
						order = 2.1,
						type = "toggle",
						name = L["No Word Abbreviation"],
						desc = L["No Word Abbreviation Desc"],
						disabled = function()
							return not E.db.nameplates.units[unit].name.abbrev
						end
					},
					noAbbreviationMaxChars = {
						order = 2.2,
						type = "range",
						name = L["Name Max Characters"],
						desc = L["Name Max Characters Desc"],
						min = 5,
						max = 60,
						step = 1,
						disabled = function()
							local nameDB = E.db.nameplates.units[unit].name
							return not nameDB.abbrev or not nameDB.noAbbreviation
						end
					},
					position = {
						order = 3,
						type = "select",
						name = L["Position"],
						values = {
							["TOP"] = "TOP",
							["LEFT"] = "LEFT",
							["BOTTOM"] = "BOTTOM",
							["CENTER"] = "CENTER",
							["TOPLEFT"] = "TOPLEFT",
							["BOTTOMLEFT"] = "BOTTOMLEFT",
							["BOTTOMRIGHT"] = "BOTTOMRIGHT",
							["RIGHT"] = "RIGHT",
							["TOPRIGHT"] = "TOPRIGHT"
						}
					},
					parent = {
						order = 4,
						type = "select",
						name = L["Parent"],
						values = {
							["Nameplate"] = L["Nameplate"],
							["Health"] = L["Health"]
						}
					},
					xOffset = {
						order = 5,
						name = L["X-Offset"],
						type = "range",
						min = -100,
						max = 100,
						step = 1
					},
					yOffset = {
						order = 6,
						name = L["Y-Offset"],
						type = "range",
						min = -100,
						max = 100,
						step = 1
					},
					fontGroup = {
						type = "group",
						order = 7,
						name = L["Fonts"],
						guiInline = true,
						get = function(info)
							return E.db.nameplates.units[unit].name[info[#info]]
						end,
						set = function(info, value)
							E.db.nameplates.units[unit].name[info[#info]] = value
							NP:ConfigureAll()
						end,
						args = {
							font = {
								order = 1,
								type = "select",
								name = L["Font"],
								dialogControl = "LSM30_Font",
								values = AceGUIWidgetLSMlists.font
							},
							fontSize = {
								order = 2,
								name = L["FONT_SIZE"],
								type = "range",
								min = 4, max = 32, step = 1
							},
							fontOutline = {
								order = 3,
								type = "select",
								name = L["Font Outline"],
								desc = L["Set the font outline."],
								values = C.Values.FontFlags
							}
						}
					}
				}
			},
			raidTargetIndicator = {
				order = 7,
				name = L["Raid Icon"],
				type = "group",
				get = function(info)
					return E.db.nameplates.units[unit].raidTargetIndicator[info[#info]]
				end,
				set = function(info, value)
					E.db.nameplates.units[unit].raidTargetIndicator[info[#info]] = value
					NP:ConfigureAll()
				end,
				args = {
					header = {
						order = 0,
						type = "header",
						name = L["Raid Icon"]
					},
					size = {
						order = 1,
						type = "range",
						name = L["Size"],
						min = 12, max = 64, step = 1
					},
					position = {
						order = 2,
						type = "select",
						name = L["Icon Position"],
						values = {
							["LEFT"] = L["Left"],
							["RIGHT"] = L["Right"],
							["TOP"] = L["Top"],
							["BOTTOM"] = L["Bottom"],
							["CENTER"] = L["Center"]
						}
					},
					xOffset = {
						order = 3,
						name = L["X-Offset"],
						type = "range",
						min = -100, max = 100, step = 1
					},
					yOffset = {
						order = 4,
						name = L["Y-Offset"],
						type = "range",
						min = -100, max = 100, step = 1
					}
				}
			}
		}
	}

	if unit == "FRIENDLY_PLAYER" or unit == "ENEMY_PLAYER" then
		if unit == "ENEMY_PLAYER" then
			group.args.markHealers = {
				order = 7,
				type = "group",
				name = L["Healer Icon"],
				get = function(info) return E.db.nameplates.units.ENEMY_PLAYER[info[#info]] end,
				set = function(info, value) E.db.nameplates.units.ENEMY_PLAYER[info[#info]] = value NP:PLAYER_ENTERING_WORLD() NP:ConfigureAll() end,
				args = {
					header = {
						order = 1,
						type = "header",
						name = L["Healer Icon"]
					},
					markHealers = {
						order = 2,
						type = "toggle",
						name = L["Enable"],
						desc = L["Display a healer icon over known healers inside battlegrounds or arenas."]
					}
				}
			}
		end
		group.args.healthGroup.args.useClassColor = {
			order = 4.5,
			type = "toggle",
			name = L["Use Class Color"]
		}
		group.args.nameGroup.args.useClassColor = {
			order = 3,
			type = "toggle",
			name = L["Use Class Color"]
		}
	elseif unit == "ENEMY_NPC" or unit == "FRIENDLY_NPC" then
		group.args.eliteIcon = {
			order = 7,
			type = "group",
			name = L["Elite Icon"],
			get = function(info) return E.db.nameplates.units[unit].eliteIcon[info[#info]] end,
			set = function(info, value) E.db.nameplates.units[unit].eliteIcon[info[#info]] = value NP:ConfigureAll() end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["Elite Icon"]
				},
				enable = {
					order = 2,
					type = "toggle",
					name = L["Enable"]
				},
				position = {
					order = 3,
					type = "select",
					name = L["Position"],
					values = {
						["LEFT"] = L["Left"],
						["RIGHT"] = L["Right"],
						["TOP"] = L["Top"],
						["BOTTOM"] = L["Bottom"],
						["CENTER"] = L["Center"]
					},
					disabled = function() return not E.db.nameplates.units[unit].eliteIcon.enable end
				},
				spacer = {
					order = 4,
					type = "description",
					name = " "
				},
				size = {
					order = 5,
					type = "range",
					name = L["Size"],
					min = 12, max = 42, step = 1,
					disabled = function() return not E.db.nameplates.units[unit].eliteIcon.enable end
				},
				xOffset = {
					order = 6,
					type = "range",
					name = L["X-Offset"],
					min = -100, max = 100, step = 1,
					disabled = function() return not E.db.nameplates.units[unit].eliteIcon.enable end
				},
				yOffset = {
					order = 7,
					type = "range",
					name = L["Y-Offset"],
					min = -100, max = 100, step = 1,
					disabled = function() return not E.db.nameplates.units[unit].eliteIcon.enable end
				}
			}
		}
		group.args.iconFrame = {
			order = 8,
			type = "group",
			name = L["Icon Frame"],
			get = function(info) return E.db.nameplates.units[unit].iconFrame[info[#info]] end,
			set = function(info, value) E.db.nameplates.units[unit].iconFrame[info[#info]] = value NP:ConfigureAll() end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["Icon Frame"]
				},
				enable = {
					order = 2,
					type = "toggle",
					name = L["Enable"]
				},
				size = {
					order = 3,
					type = "range",
					name = L["Size"],
					min = 8, max = 60, step = 1,
				},
				position = {
					order = 4,
					type = "select",
					name = L["Position"],
					values = {
						["CENTER"] = "CENTER",
						["TOPLEFT"] = "TOPLEFT",
						["BOTTOMLEFT"] = "BOTTOMLEFT",
						["TOPRIGHT"] = "TOPRIGHT",
						["BOTTOMRIGHT"] = "BOTTOMRIGHT"
					}
				},
				parent = {
					order = 5,
					type = "select",
					name = L["Parent"],
					values = {
						["Nameplate"] = L["Nameplate"],
						["Health"] = L["Health"]
					}
				},
				xOffset = {
					order = 6,
					name = L["X-Offset"],
					type = "range",
					min = -100, max = 100, step = 1
				},
				yOffset = {
					order = 7,
					name = L["Y-Offset"],
					type = "range",
					min = -100, max = 100, step = 1
				}
			}
		}
	end

	ORDER = ORDER + 2
	return group
end

-- Build the NamePlates options tree. Deferred into a function (instead of running at
-- file load) because the tree reads NP.db / E.db, which only exist after E:Initialize
-- sets up the database. In ElvUI this file lives in a separate addon loaded after init;
-- standalone loads it at ADDON_LOADED, so we build on demand from E:RegisterOptions.
local function BuildNamePlateOptions()
E.Options.args.nameplate = {
	type = "group",
	name = L["NamePlates"],
	childGroups = "tree",
	get = function(info) return E.db.nameplates[info[#info]] end,
	set = function(info, value) E.db.nameplates[info[#info]] = value NP:ConfigureAll() end,
	args = {
		enable = {
			order = 1,
			type = "toggle",
			name = L["Enable"],
			get = function(info) return E.private.nameplates[info[#info]] end,
			set = function(info, value) E.private.nameplates[info[#info]] = value E:StaticPopup_Show("PRIVATE_RL") end
		},
		intro = {
			order = 2,
			type = "description",
			name = L["NAMEPLATE_DESC"]
		},
		header = {
			order = 3,
			type = "header",
			name = L["Shortcuts"]
		},
		spacer1 = {
			order = 4,
			type = "description",
			name = " "
		},
		generalShortcut = {
			order = 5,
			type = "execute",
			name = L["General"],
			func = function() ENPSelectGroup("nameplate", "generalGroup", "general") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		fontsShortcut = {
			order = 6,
			type = "execute",
			name = L["Fonts"],
			func = function() ENPSelectGroup("nameplate", "generalGroup", "fontGroup") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		threatShortcut = {
			order = 8,
			type = "execute",
			name = L["Threat"],
			func = function() ENPSelectGroup("nameplate", "generalGroup", "threatGroup") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		spacer2 = {
			order = 9,
			type = "description",
			name = " "
		},
		castBarShortcut = {
			order = 10,
			type = "execute",
			name = L["Cast Bar"],
			func = function() ENPSelectGroup("nameplate", "generalGroup", "castGroup") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		reactionShortcut = {
			order = 12,
			type = "execute",
			name = L["Reaction Colors"],
			func = function() ENPSelectGroup("nameplate", "generalGroup", "reactions") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		cutawayHealthShortcut = {
			order = 13,
			type = "execute",
			name = L["Cutaway Bars"],
			func = function() ENPSelectGroup("nameplate", "generalGroup", "cutawayHealth") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		spacer3 = {
			order = 14,
			type = "description",
			name = " "
		},
		friendlyPlayerShortcut = {
			order = 15,
			type = "execute",
			name = L["FRIENDLY_PLAYER"],
			func = function() ENPSelectGroup("nameplate", "friendlyPlayerGroup") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		friendlyNPCShortcut = {
			order = 16,
			type = "execute",
			name = L["FRIENDLY_NPC"],
			func = function() ENPSelectGroup("nameplate", "friendlyNPCGroup") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		enemyPlayerShortcut = {
			order = 17,
			type = "execute",
			name = L["ENEMY_PLAYER"],
			func = function() ENPSelectGroup("nameplate", "enemyPlayerGroup") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		enemyNPCShortcut = {
			order = 18,
			type = "execute",
			name = L["ENEMY_NPC"],
			func = function() ENPSelectGroup("nameplate", "enemyNPCGroup") end,
			disabled = function() return not E.NamePlates.Initialized end
		},
		generalGroup = {
			order = 21,
			type = "group",
			name = L["General Options"],
			childGroups = "tab",
			disabled = function() return not E.NamePlates.Initialized end,
			args = {
				general = {
					order = 1,
					type = "group",
					name = L["General"],
					get = function(info)
						return E.db.nameplates[info[#info]]
					end,
					set = function(info, value)
						E.db.nameplates[info[#info]] = value
						NP:ConfigureAll()
					end,
					args = {
						header = {
							order = 1,
							type = "header",
							name = L["General"]
						},
						statusbar = {
							order = 2,
							type = "select",
							dialogControl = "LSM30_Statusbar",
							name = L["StatusBar Texture"],
							values = AceGUIWidgetLSMlists.statusbar
						},
						motionType = {
							order = 3,
							type = "select",
							name = L["UNIT_NAMEPLATES_TYPES"],
							desc = L["Set to either stack nameplates vertically or allow them to overlap."],
							get = function() return GetCVar("nameplateAllowOverlap") == "1" and "OVERLAP" or "STACKED" end,
							set = function(_, value)
								E.db.nameplates.motionType = value
								SetCVar("nameplateAllowOverlap", value == "STACKED" and "0" or "1", "UNIT_NAMEPLATES_ALLOW_OVERLAP")
								NP:ConfigureAll()
							end,
							values = {
								["STACKED"] = L["UNIT_NAMEPLATES_TYPE_2"],
								["OVERLAP"] = L["UNIT_NAMEPLATES_TYPE_1"]
							}
						},
						lowHealthThreshold = {
							order = 4,
							name = L["Low Health Threshold"],
							desc = L["Make the unitframe glow yellow when it is below this percent of health, it will glow red when the health value is half of this value."],
							type = "range",
							isPercent = true,
							min = 0, max = 1, step = 0.01
						},
						showEnemyCombat = {
							order = 5,
							type = "select",
							name = L["Enemy Combat Toggle"],
							desc = L["Control enemy nameplates toggling on or off when in combat."],
							values = {
								["DISABLED"] = L["DISABLE"],
								["TOGGLE_ON"] = L["Toggle On While In Combat"],
								["TOGGLE_OFF"] = L["Toggle Off While In Combat"]
							},
							set = function(info, value)
								E.db.nameplates[info[#info]] = value
								NP:PLAYER_REGEN_ENABLED()
							end
						},
						showFriendlyCombat = {
							order = 6,
							type = "select",
							name = L["Friendly Combat Toggle"],
							desc = L["Control friendly nameplates toggling on or off when in combat."],
							values = {
								["DISABLED"] = L["DISABLE"],
								["TOGGLE_ON"] = L["Toggle On While In Combat"],
								["TOGGLE_OFF"] = L["Toggle Off While In Combat"]
							},
							set = function(info, value)
								E.db.nameplates[info[#info]] = value
								NP:PLAYER_REGEN_ENABLED()
							end
						},
						fadeIn = {
							order = 8,
							type = "toggle",
							name = L["Alpha Fading"]
						},
						smoothbars = {
							order = 9,
							type = "toggle",
							name = L["Smooth Bars"],
							desc = L["Bars will transition smoothly."],
							set = function(info, value)
								E.db.nameplates[info[#info]] = value
								NP:ConfigureAll()
							end
						},
						highlight = {
							order = 10,
							type = "toggle",
							name = L["Hover Highlight"]
						},
						nameColoredGlow = {
							order = 11,
							type = "toggle",
							name = L["Name Colored Glow"],
							desc = L["Use the Name Color of the unit for the Name Glow."],
							disabled = function() return not E.db.nameplates.highlight end
						},
						clickThrough = {
							order = 51,
							type = "group",
							childGroups = "tabs",
							name = L["Click Through"],
							get = function(info)
								return E.db.nameplates.clickThrough[info[#info]]
							end,
							set = function(info, value)
								E.db.nameplates.clickThrough[info[#info]] = value
								NP:ConfigureAll()
							end,
							args = {
								friendly = {
									order = 2,
									type = "toggle",
									name = L["Friendly"],
								},
								enemy = {
									order = 3,
									type = "toggle",
									name = L["Enemy"]
								}
							}
						},
						clickableRange = {
							order = 52,
							type = "group",
							childGroups = "tabs",
							name = L["Clickable Size"],
							args = {
								friendly = {
									order = 1,
									type = "group",
									guiInline = true,
									name = L["Friendly"],
									get = function(info)
										return E.db.nameplates.plateSize[info[#info]]
									end,
									set = function(info, value)
										E.db.nameplates.plateSize[info[#info]] = value
										NP:ConfigureAll()
									end,
									args = {
										friendlyWidth = {
											order = 1,
											type = "range",
											name = L["Clickable Width / Width"],
											desc = L["Change the width and controls how big of an area on the screen will accept clicks to target unit."],
											min = 50,
											max = 250,
											step = 1
										},
										friendlyHeight = {
											order = 2,
											type = "range",
											name = L["Clickable Height"],
											desc = L["Controls how big of an area on the screen will accept clicks to target unit."],
											min = 10,
											max = 75,
											step = 1
										},
										friendlyIncludeName = {
											order = 3,
											type = "toggle",
											name = L["Include Name"],
											desc = L["Expand the clickable area upward so hovering/clicking the name above the health bar also targets the unit. When enabled, the nameplate shifts slightly downward to compensate for the extra clickable height."],
										}
									}
								},
								enemy = {
									order = 2,
									type = "group",
									guiInline = true,
									name = L["Enemy"],
									get = function(info)
										return E.db.nameplates.plateSize[info[#info]]
									end,
									set = function(info, value)
										E.db.nameplates.plateSize[info[#info]] = value
										NP:ConfigureAll()
									end,
									args = {
										enemyWidth = {
											order = 1,
											type = "range",
											name = L["Clickable Width / Width"],
											desc = L["Change the width and controls how big of an area on the screen will accept clicks to target unit."],
											min = 50,
											max = 250,
											step = 1
										},
										enemyHeight = {
											order = 2,
											type = "range",
											name = L["Clickable Height"],
											desc = L["Controls how big of an area on the screen will accept clicks to target unit."],
											min = 10,
											max = 75,
											step = 1
										},
										enemyIncludeName = {
											order = 3,
											type = "toggle",
											name = L["Include Name"],
											desc = L["Expand the clickable area upward so hovering/clicking the name above the health bar also targets the unit. When enabled, the nameplate shifts slightly downward to compensate for the extra clickable height."],
										}
									}
								}
							}
						}
					}
				},
				colorsGroup = {
					order = 2,
					type = "group",
					name = L["COLORS"],
					args = {
						general = {
							order = 1,
							type = "group",
							name = L["General"],
							guiInline = true,
							get = function(info)
								local t = E.db.nameplates.colors[info[#info]]
								local d = P.nameplates.colors[info[#info]]
								return t.r, t.g, t.b, t.a, d.r, d.g, d.b, d.a
							end,
							set = function(info, r, g, b, a)
								local t = E.db.nameplates.colors[info[#info]]
								t.r, t.g, t.b, t.a = r, g, b, a
								NP:ConfigureAll()
							end,
							args = {
								glowColor = {
									name = L["Target Indicator Color"],
									type = "color",
									order = 5,
									hasAlpha = true
								}
							}
						},
						threat = {
							order = 2,
							type = "group",
							name = L["Threat"],
							guiInline = true,
							get = function(info)
								local t = E.db.nameplates.colors.threat[info[#info]]
								local d = P.nameplates.colors.threat[info[#info]]
								return t.r, t.g, t.b, t.a, d.r, d.g, d.b, d.a
							end,
							set = function(info, r, g, b, a)
								local t = E.db.nameplates.colors.threat[info[#info]]
								t.r, t.g, t.b, t.a = r, g, b, a
								NP:ConfigureAll()
							end,
							args = {
								goodColor = {
									type = "color",
									order = 1,
									name = L["Good Color"],
									hasAlpha = false,
									disabled = function()
										return not E.db.nameplates.threat.useThreatColor
									end
								},
								goodTransition = {
									type = "color",
									order = 2,
									name = L["Good Transition Color"],
									hasAlpha = false,
									disabled = function()
										return not E.db.nameplates.threat.useThreatColor
									end
								},
								badTransition = {
									name = L["Bad Transition Color"],
									order = 3,
									type = "color",
									hasAlpha = false,
									disabled = function()
										return not E.db.nameplates.threat.useThreatColor
									end
								},
								badColor = {
									name = L["Bad Color"],
									order = 4,
									type = "color",
									hasAlpha = false,
									disabled = function()
										return not E.db.nameplates.threat.useThreatColor
									end
								},
							}
						},
						castGroup = {
							order = 3,
							type = "group",
							name = L["Cast Bar"],
							guiInline = true,
							get = function(info)
								local t = E.db.nameplates.colors[info[#info]]
								local d = P.nameplates.colors[info[#info]]
								return t.r, t.g, t.b, t.a, d.r, d.g, d.b
							end,
							set = function(info, r, g, b)
								local t = E.db.nameplates.colors[info[#info]]
								t.r, t.g, t.b = r, g, b
								NP:ConfigureAll()
							end,
							args = {
								castColor = {
									order = 1,
									type = "color",
									name = L["Cast Color"],
									hasAlpha = false
								},
								castNoInterruptColor = {
									order = 2,
									type = "color",
									name = L["Cast No Interrupt Color"],
									hasAlpha = false
								},
								castInterruptedColor = {
									order = 3,
									type = "color",
									name = L["INTERRUPTED"],
									hasAlpha = false
								},
								castbarDesaturate = {
									order = 4,
									type = "toggle",
									name = L["Desaturated Icon"],
									desc = L["Show the castbar icon desaturated if a spell is not interruptible."],
									get = function(info)
										return E.db.nameplates.colors[info[#info]]
									end,
									set = function(info, value)
										E.db.nameplates.colors[info[#info]] = value
										NP:ConfigureAll()
									end
								}
							}
						},
						reactions = {
							order = 4,
							type = "group",
							name = L["Reaction Colors"],
							guiInline = true,
							get = function(info)
								local t = E.db.nameplates.colors.reactions[info[#info]]
								local d = P.nameplates.colors.reactions[info[#info]]
								return t.r, t.g, t.b, t.a, d.r, d.g, d.b
							end,
							set = function(info, r, g, b)
								local t = E.db.nameplates.colors.reactions[info[#info]]
								t.r, t.g, t.b = r, g, b
								NP:ConfigureAll()
							end,
							args = {
								friendlyPlayer = {
									order = 1,
									type = "color",
									name = L["FRIENDLY_PLAYER"],
									hasAlpha = false
								},
								bad = {
									order = 2,
									type = "color",
									name = L["ENEMY"],
									hasAlpha = false
								},
								neutral = {
									order = 3,
									type = "color",
									name = L["Neutral"],
									hasAlpha = false
								},
								good = {
									order = 4,
									type = "color",
									name = L["FRIENDLY_NPC"],
									hasAlpha = false
								}
							}
						},
						comboPoints = {
							order = 5,
							type = "group",
							name = L["COMBO_POINTS"],
							guiInline = true,
							args = {}
						},
					}
				},
				threatGroup = {
					order = 5,
					type = "group",
					name = L["Threat"],
					get = function(info)
						local t = E.db.nameplates.threat[info[#info]]
						local d = P.nameplates.threat[info[#info]]
						return t.r, t.g, t.b, t.a, d.r, d.g, d.b
					end,
					set = function(info, r, g, b)
						local t = E.db.nameplates.threat[info[#info]]
						t.r, t.g, t.b = r, g, b
					end,
					args = {
						header = {
							order = 1,
							type = "header",
							name = L["Threat"]
						},
						useThreatColor = {
							order = 2,
							type = "toggle",
							name = L["Use Threat Color"],
							get = function(info) return E.db.nameplates.threat.useThreatColor end,
							set = function(info, value) E.db.nameplates.threat.useThreatColor = value end
						},
						goodScale = {
							order = 3,
							type = "range",
							name = L["Good Scale"],
							get = function(info) return E.db.nameplates.threat[info[#info]] end,
							set = function(info, value) E.db.nameplates.threat[info[#info]] = value end,
							min = 0.3, max = 2, step = 0.01,
							isPercent = true
						},
						badScale = {
							order = 4,
							type = "range",
							name = L["Bad Scale"],
							get = function(info) return E.db.nameplates.threat[info[#info]] end,
							set = function(info, value) E.db.nameplates.threat[info[#info]] = value end,
							min = 0.3, max = 2, step = 0.01,
							isPercent = true
						},
					}
				},
				cutawayHealth = {
					order = 9,
					type = "group",
					name = L["Cutaway Bars"],
					args = {
						header = {
							order = 1,
							type = "header",
							name = L["Cutaway Bars"]
						},
						enabled = {
							order = 2,
							type = "toggle",
							name = L["Enable"],
							get = function(info) return E.db.nameplates.cutawayHealth end,
							set = function(info, value) E.db.nameplates.cutawayHealth = value end,
						},
						healthLength = {
							order = 3,
							type = "range",
							name = L["Health Length"],
							desc = L["How much time before the cutaway health starts to fade."],
							min = 0.1, max = 1, step = 0.1,
							get = function(info) return E.db.nameplates.cutawayHealthLength end,
							set = function(info, value) E.db.nameplates.cutawayHealthLength = value end,
							disabled = function() return not E.db.nameplates.cutawayHealth end
						},
						healthFadeOutTime = {
							order = 4,
							type = "range",
							name = L["Fade Out"],
							desc = L["How long the cutaway health will take to fade out."],
							min = 0.1, max = 1, step = 0.1,
							get = function(info) return E.db.nameplates.cutawayHealthFadeOutTime end,
							set = function(info, value) E.db.nameplates.cutawayHealthFadeOutTime = value end,
							disabled = function() return not E.db.nameplates.cutawayHealth end
						}
					}
				}
			}
		},
		friendlyPlayerGroup = GetUnitSettings("FRIENDLY_PLAYER", L["FRIENDLY_PLAYER"]),
		friendlyNPCGroup = GetUnitSettings("FRIENDLY_NPC", L["FRIENDLY_NPC"]),
		enemyPlayerGroup = GetUnitSettings("ENEMY_PLAYER", L["ENEMY_PLAYER"]),
		enemyNPCGroup = GetUnitSettings("ENEMY_NPC", L["ENEMY_NPC"]),
		targetGroup = {
			order = 200,
			type = "group",
			name = L["TARGET"],
			get = function(info)
				return E.db.nameplates.units.TARGET[info[#info]]
			end,
			set = function(info, value)
				E.db.nameplates.units.TARGET[info[#info]] = value
				NP:ConfigureAll()
			end,
			disabled = function()
				return not E.NamePlates.Initialized
			end,
			args = {
				useTargetScale = {
					order = 1,
					type = "toggle",
					name = L["Use Target Scale"],
					desc = L["Enable/Disable the scaling of targetted nameplates."],
					get = function(info) return E.db.nameplates.useTargetScale end,
					set = function(info, value)
						E.db.nameplates.useTargetScale = value
						NP:ConfigureAll()
					end
				},
				targetScale = {
					order = 2,
					type = "range",
					isPercent = true,
					name = L["Target Scale"],
					desc = L["Scale of the nameplate that is targetted."],
					min = 0.3, max = 2, step = 0.01,
					get = function(info) return E.db.nameplates.targetScale end,
					set = function(info, value)
						E.db.nameplates.targetScale = value
						NP:ConfigureAll()
					end,
					disabled = function() return E.db.nameplates.useTargetScale ~= true end
				},
				nonTargetTransparency = {
					order = 3,
					type = "range",
					isPercent = true,
					name = L["Non-Target Alpha"],
					min = 0, max = 1, step = 0.01,
					get = function(info) return E.db.nameplates.nonTargetTransparency end,
					set = function(info, value)
						E.db.nameplates.nonTargetTransparency = value
						NP:ConfigureAll()
					end
				},
				spacer1 = {
					order = 4,
					type = "description",
					name = " "
				},
				glowStyle = {
					order = 5,
					type = "select",
					name = L["Target/Low Health Indicator"],
					customWidth = 225,
					values = {
						["none"] = L["NONE"],
						["style1"] = L["Border Glow"],
						["style2"] = L["Background Glow"],
						["style3"] = L["Top Arrow"],
						["style4"] = L["Side Arrows"],
						["style5"] = L["Border Glow"].." + "..L["Top Arrow"],
						["style6"] = L["Background Glow"].." + "..L["Top Arrow"],
						["style7"] = L["Border Glow"].." + "..L["Side Arrows"],
						["style8"] = L["Background Glow"].." + "..L["Side Arrows"]
					}
				},
				arrowSize = {
					order = 6,
					type = "range",
					name = L["Arrow Size"],
					min = 1,
					max = 50,
					step = 1,
					isPercent = false
				},
				arrowXOffset = {
					order = 7,
					type = "range",
					name = L["Arrow X-Offset"],
					min = -20, max = 20, step = 1
				},
				arrowYOffset = {
					order = 8,
					type = "range",
					name = L["Arrow Y-Offset"],
					min = -20, max = 20, step = 1
				},
				alwaysShowTargetHealth = {
					order = 9,
					type = "toggle",
					name = L["Always Show Target Health"],
					get = function(info) return E.db.nameplates.alwaysShowTargetHealth end,
					set = function(info, value)
						E.db.nameplates.alwaysShowTargetHealth = value
						NP:ConfigureAll()
					end,
					customWidth = 200
				},
				comboPointsGroup = {
					order = 10,
					type = "group",
					name = L["COMBO_POINTS"],
					guiInline = true,
					get = function(info)
						return E.db.nameplates.units.TARGET.comboPoints[info[#info]]
					end,
					set = function(info, value)
						E.db.nameplates.units.TARGET.comboPoints[info[#info]] = value
						NP:ConfigureAll()
					end,
					args = {
						enable = {
							order = 1,
							type = "toggle",
							name = L["Enable"]
						},
						width = {
							order = 2,
							type = "range",
							name = L["Width"],
							min = 4, max = 30, step = 1,
							disabled = function() return not E.db.nameplates.units.TARGET.comboPoints.enable end
						},
						height = {
							order = 3,
							type = "range",
							name = L["Height"],
							min = 4, max = 30, step = 1,
							disabled = function() return not E.db.nameplates.units.TARGET.comboPoints.enable end
						},
						spacing = {
							order = 4,
							type = "range",
							name = L["Spacing"],
							min = 3, max = 20, step = 1,
							disabled = function() return not E.db.nameplates.units.TARGET.comboPoints.enable end
						},
						xOffset = {
							order = 5,
							type = "range",
							name = L["X-Offset"],
							min = -100, max = 100, step = 1,
							disabled = function() return not E.db.nameplates.units.TARGET.comboPoints.enable end
						},
						yOffset = {
							order = 6,
							type = "range",
							name = L["Y-Offset"],
							min = -100, max = 100, step = 1,
							disabled = function() return not E.db.nameplates.units.TARGET.comboPoints.enable end
						}
					}
				},
				arrows = {
					order = 11,
					name = L["Arrow Texture"],
					type = "multiselect",
					customWidth = 80,
					get = function(info, key)
						return E.db.nameplates.units.TARGET.arrow == key
					end,
					set = function(info, key, value)
						E.db.nameplates.units.TARGET.arrow = key
						NP:UpdateCVars()
						NP:ConfigureAll()
					end,
				}
			}
		},

	}
}

do -- target arrow textures
	local arrows = {}
	E.Options.args.nameplate.args.targetGroup.args.arrows.values = arrows

	for key, arrow in pairs(E.Media.Arrows) do
		arrows[key] = E:TextureString(arrow, ":45:45")
	end
end

for i = 1, 5 do
	E.Options.args.nameplate.args.generalGroup.args.colorsGroup.args.comboPoints.args["COMBO_POINTS" .. i] = {
		type = "color",
		order = i,
		name = L["COMBO_POINTS"] .. " #" .. i,
		get = function(info)
			local t = E.db.nameplates.colors.comboPoints[i]
			local d = P.nameplates.colors.comboPoints[i]
			return t.r, t.g, t.b, t.a, d.r, d.g, d.b
		end,
		set = function(info, r, g, b)
			local t = E.db.nameplates.colors.comboPoints[i]
			t.r, t.g, t.b = r, g, b
			NP:ConfigureAll()
		end
	}
end
end -- BuildNamePlateOptions

-- Standalone registration: "NamePlates" (E.Options.args.nameplate) is the root tree node
-- and its children (General Options / Friendly Player / Friendly NPC / Enemy Player /
-- Enemy NPC / Target Indicator) form the left-hand tree, exactly as in
-- ElvUI. Called from E:Initialize (Core.lua) which checks for self.RegisterOptions.
function E:RegisterOptions()
	local AC = self.Libs.AceConfig
	if not AC then return end

	BuildNamePlateOptions()
	AC:RegisterOptionsTable(APP, E.Options)
	if ACD then ACD:SetDefaultSize(APP, self:GetConfigDefaultSize()) end
end
