local E, L, V, P, G = unpack(_G.SarychUI_ElvUI_NamePlates) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

-----------------------------------------------------------------------
-- Private (per character) defaults  --> V / E.private
-----------------------------------------------------------------------
V.general = {
	font = "Friz Quadrata TT",
	pixelPerfect = true,
}
V.nameplates = {
	enable = true,
}
V.skins = {
	checkBoxSkin = true,
	ace3 = {
		enable = true, -- skin the options window to look like ElvUI
	},
}

-----------------------------------------------------------------------
-- Global defaults  --> G / E.global
-----------------------------------------------------------------------
G.general = {
	UIScale = 0.71,
	eyefinity = false,
	-- Saved size/position of the config window (matches ElvUI defaults).
	AceGUI = {
		width = 1000,
		height = 720,
	},
}
G.nameplates = {}

-----------------------------------------------------------------------
-- Profile defaults  --> P / E.db
-----------------------------------------------------------------------
P.general = {
	font = "Friz Quadrata TT",
	fontSize = 12,
	fontStyle = "OUTLINE",
	statusbar = "ElvUI Norm",
	numberPrefixStyle = "ENGLISH",
	decimalLength = 1,
}

P.cooldown = {
	enable = true,
	threshold = 3,
	expiringColor = {r = 1, g = 0, b = 0},
	secondsColor = {r = 1, g = 1, b = 0},
	minutesColor = {r = 1, g = 1, b = 1},
	hoursColor = {r = 0.4, g = 1, b = 1},
	daysColor = {r = 0.4, g = 0.4, b = 1},
	expireIndicator = {r = 1, g = 1, b = 1},
	secondsIndicator = {r = 1, g = 1, b = 1},
	minutesIndicator = {r = 1, g = 1, b = 1},
	hoursIndicator = {r = 1, g = 1, b = 1},
	daysIndicator = {r = 1, g = 1, b = 1},
	hhmmColorIndicator = {r = 1, g = 1, b = 1},
	mmssColorIndicator = {r = 1, g = 1, b = 1},
	checkSeconds = false,
	hhmmColor = {r = 0.43, g = 0.43, b = 0.43},
	mmssColor = {r = 0.56, g = 0.56, b = 0.56},
	hhmmThreshold = -1,
	mmssThreshold = -1,
	fonts = {
		enable = false,
		font = "Friz Quadrata TT",
		fontOutline = "OUTLINE",
		fontSize = 18
	}
}


P.nameplates = {
	statusbar = "ElvUI Norm",
	smoothbars = false,
	clickThrough = {
		friendly = false,
		enemy = false,
	},
	plateSize ={
		friendlyWidth = 150,
		friendlyHeight = 30,
		friendlyIncludeName = true,
		enemyWidth = 150,
		enemyHeight = 30,
		enemyIncludeName = true,
	},
	font = "Friz Quadrata TT",
	fontSize = 11,
	fontOutline = "OUTLINE",

	useTargetScale = true,
	targetScale = 1.15,
	nonTargetTransparency = 0.40,

	motionType = "OVERLAP",

	lowHealthThreshold = 0.4,

	showFriendlyCombat = "DISABLED",
	showEnemyCombat = "DISABLED",

	nameColoredGlow = false,
	highlight = true,

	cutawayHealth = false,
	cutawayHealthLength = 0.3,
	cutawayHealthFadeOutTime = 0.6,

	alwaysShowTargetHealth = true,

	colors = {
		glowColor = {r = 1, g = 1, b = 1, a = 1},
		castColor = {r = 1, g = 0.81, b = 0},
		castNoInterruptColor = {r = 0.78, g = 0.25, b = 0.25},
		castInterruptedColor = {r = 0.30, g = 0.30, b = 0.30},
		castbarDesaturate = true,
		reactions = {
			friendlyPlayer = {r = 0.31, g = 0.45, b = 0.63},
			good = {r = .29, g = .68, b = .30},
			neutral = {r = .85, g = .77, b = .36},
			bad = {r = 0.78, g = 0.25, b = 0.25},
		},
		threat = {
			goodColor = {r = 75/255, g = 175/255, b = 76/255},
			badColor = {r = 0.78, g = 0.25, b = 0.25},
			goodTransition = {r = 218/255, g = 197/255, b = 92/255},
			badTransition = {r = 235/255, g = 163/255, b = 40/255},
		},
		comboPoints = {
			[1] = {r = .69, g = .31, b = .31},
			[2] = {r = .69, g = .31, b = .31},
			[3] = {r = .65, g = .63, b = .35},
			[4] = {r = .65, g = .63, b = .35},
			[5] = {r = .33, g = .59, b = .33}
		}
	},
	cooldown = {
		override = true,
		reverse = false,
		threshold = 3,
		expiringColor = {r = 1, g = 0, b = 0},
		secondsColor = {r = 1, g = 1, b = 1},
		minutesColor = {r = 1, g = 1, b = 1},
		hoursColor = {r = 1, g = 1, b = 1},
		daysColor = {r = 1, g = 1, b = 1},
		expireIndicator = {r = 1, g = 1, b = 1},
		secondsIndicator = {r = 1, g = 1, b = 1},
		minutesIndicator = {r = 1, g = 1, b = 1},
		hoursIndicator = {r = 1, g = 1, b = 1},
		daysIndicator = {r = 1, g = 1, b = 1},
		hhmmColorIndicator = {r = 1, g = 1, b = 1},
		mmssColorIndicator = {r = 1, g = 1, b = 1},

		checkSeconds = false,
		hhmmColor = {r = 0.43, g = 0.43, b = 0.43},
		mmssColor = {r = 0.56, g = 0.56, b = 0.56},
		hhmmThreshold = -1,
		mmssThreshold = -1,

		fonts = {
			enable = false,
			font = "Friz Quadrata TT",
			fontOutline = "OUTLINE",
			fontSize = 18
		}
	},
	fadeIn = true,
	threat = {
		goodScale = 0.8,
		badScale = 1.2,
		useThreatColor = true
	},
	filters = {
		ElvUI_Boss = {triggers = {enable = false}},
		ElvUI_Totem = {triggers = {enable = true}}
	},
	units = {
		TARGET = {
			enable = true,
			glowStyle = "style2",
			arrow = "ArrowUp",
			arrowSize = 20,
			arrowXOffset = 3,
			arrowYOffset = 0,
			comboPoints = {
				enable = true,
				width = 8,
				height = 4,
				spacing = 5,
				xOffset = 0,
				yOffset = 0
			},
		},
		FRIENDLY_PLAYER = {
			health = {
				enable = false,
				height = 10,
				width = 150,
				glowStyle = "TARGET_THREAT",
				text = {
					enable = false,
					format = "CURRENT",
					position = "CENTER",
					parent = "Health",
					xOffset = 0,
					yOffset = 0,
					font = "Friz Quadrata TT",
					fontOutline = "OUTLINE",
					fontSize = 11,
				},
				useClassColor = true,
			},
			name = {
				enable = true,
				useClassColor = true,
				abbrev = true,
				noAbbreviation = true,
				noAbbreviationMaxChars = 30,
				position = "TOPLEFT",
				parent = "Health",
				xOffset = 0,
				yOffset = 2,
				font = "Friz Quadrata TT",
				fontOutline = "OUTLINE",
				fontSize = 11
			},
			level = {
				enable = false,
				position = "TOPRIGHT",
				parent = "Health",
				xOffset = 0,
				yOffset = 2,
				font = "Friz Quadrata TT",
				fontOutline = "OUTLINE",
				fontSize = 10
			},
			castbar = {
				enable = true,
				width = 150,
				height = 8,
				hideSpellName = false,
				hideTime = false,
				textPosition = "BELOW",
				castTimeFormat = "CURRENT",
				channelTimeFormat = "CURRENT",
				timeToHold = 0,
				iconPosition = "RIGHT",
				iconSize = 20,
				iconOffsetX = 2,
				iconOffsetY = 0,
				showIcon = true,
				xOffset = 0,
				yOffset = -2,
				font = "Friz Quadrata TT",
				fontSize = 11,
				fontOutline = "OUTLINE"
			},
			buffs = {
				enable = true,
				perrow = 6,
				size = 24,
				numrows = 1,
				attachTo = "FRAME",
				anchorPoint = "TOPLEFT",
				growthX = "RIGHT",
				growthY = "UP",
				spacing = 1,
				yOffset = 20,
				xOffset = 0,
				cooldownOrientation = "VERTICAL",
				reverseCooldown = false,
				countFont = "Friz Quadrata TT",
				countFontOutline = "OUTLINE",
				countFontSize = 11,
				countPosition = "BOTTOMRIGHT",
				countXOffset = -1,
				countYOffset = 1,
				durationFont = "Friz Quadrata TT",
				durationFontOutline = "OUTLINE",
				durationFontSize = 11,
				durationPosition = "CENTER",
				durationXOffset = 0,
				durationYOffset = 0,
				filters = {
					minDuration = 0,
					maxDuration = 0,
					priority = "Blacklist,blockNoDuration,Personal,TurtleBuffs" --NamePlate FriendlyPlayer Buffs
				},
			},
			debuffs = {
				enable = true,
				perrow = 6,
				size = 24,
				numrows = 1,
				yOffset = 1,
				xOffset = 0,
				attachTo = "BUFFS",
				anchorPoint = "TOPRIGHT",
				growthX = "LEFT",
				growthY = "UP",
				onlyShowPlayer = false,
				spacing = 1,
				cooldownOrientation = "VERTICAL",
				reverseCooldown = false,
				countFont = "Friz Quadrata TT",
				countFontOutline = "OUTLINE",
				countFontSize = 11,
				countPosition = "BOTTOMRIGHT",
				countXOffset = -1,
				countYOffset = 1,
				durationFont = "Friz Quadrata TT",
				durationFontOutline = "OUTLINE",
				durationFontSize = 11,
				durationPosition = "CENTER",
				durationXOffset = 0,
				durationYOffset = 0,
				filters = {
					minDuration = 0,
					maxDuration = 0,
					priority = "Blacklist,blockNoDuration,Personal,CCDebuffs" --NamePlate FriendlyPlayer Debuffs
				},
			},
			raidTargetIndicator = {
				size = 24,
				position = "LEFT",
				xOffset = -4,
				yOffset = 0
			}
		},
		ENEMY_PLAYER = {
			markHealers = true,
			health = {
				enable = true,
				height = 10,
				width = 150,
				glowStyle = "TARGET_THREAT",
				text = {
					enable = false,
					format = "CURRENT",
					position = "CENTER",
					parent = "Health",
					xOffset = 0,
					yOffset = 0,
					font = "Friz Quadrata TT",
					fontOutline = "OUTLINE",
					fontSize = 11
				},
				useClassColor = true
			},
			name = {
				enable = true,
				useClassColor = true,
				abbrev = true,
				noAbbreviation = true,
				noAbbreviationMaxChars = 30,
				position = "TOPLEFT",
				parent = "Health",
				xOffset = 0,
				yOffset = 2,
				font = "Friz Quadrata TT",
				fontOutline = "OUTLINE",
				fontSize = 11
			},
			level = {
				enable = true,
				position = "TOPRIGHT",
				parent = "Health",
				xOffset = 0,
				yOffset = 2,
				font = "Friz Quadrata TT",
				fontOutline = "OUTLINE",
				fontSize = 10
			},
			castbar = {
				enable = true,
				width = 150,
				height = 8,
				hideSpellName = false,
				hideTime = false,
				textPosition = "BELOW",
				castTimeFormat = "CURRENT",
				channelTimeFormat = "CURRENT",
				timeToHold = 0,
				iconPosition = "LEFT",
				iconSize = 20,
				iconOffsetX = 2,
				iconOffsetY = 0,
				showIcon = true,
				xOffset = 0,
				yOffset = -2,
				font = "Friz Quadrata TT",
				fontSize = 11,
				fontOutline = "OUTLINE"
			},
			comboPoints = {
				enable = true,
				width = 8,
				height = 4,
				spacing = 5,
				xOffset = 0,
				yOffset = 0
			},
			buffs = {
				enable = true,
				perrow = 6,
				size = 24,
				numrows = 1,
				yOffset = 20,
				xOffset = 0,
				attachTo = "FRAME",
				anchorPoint = "TOPLEFT",
				growthX = "RIGHT",
				growthY = "UP",
				onlyShowPlayer = false,
				cooldownOrientation = "VERTICAL",
				reverseCooldown = false,
				spacing = 1,
				countFont = "Friz Quadrata TT",
				countFontOutline = "OUTLINE",
				countFontSize = 11,
				countPosition = "BOTTOMRIGHT",
				countXOffset = -1,
				countYOffset = 1,
				durationFont = "Friz Quadrata TT",
				durationFontOutline = "OUTLINE",
				durationFontSize = 11,
				durationPosition = "CENTER",
				durationXOffset = 0,
				durationYOffset = 0,
				filters = {
					minDuration = 0,
					maxDuration = 300,
					priority = "Blacklist,PlayerBuffs,TurtleBuffs" --NamePlate EnemyPlayer Buffs
				},
			},
			debuffs = {
				enable = true,
				perrow = 6,
				size = 24,
				numrows = 1,
				yOffset = 1,
				xOffset = 0,
				attachTo = "BUFFS",
				anchorPoint = "TOPRIGHT",
				growthX = "LEFT",
				growthY = "UP",
				onlyShowPlayer = false,
				spacing = 1,
				cooldownOrientation = "VERTICAL",
				reverseCooldown = false,
				countFont = "Friz Quadrata TT",
				countFontOutline = "OUTLINE",
				countFontSize = 11,
				countPosition = "BOTTOMRIGHT",
				countXOffset = -1,
				countYOffset = 1,
				durationFont = "Friz Quadrata TT",
				durationFontOutline = "OUTLINE",
				durationFontSize = 11,
				durationPosition = "CENTER",
				durationXOffset = 0,
				durationYOffset = 0,
				filters = {
					minDuration = 0,
					maxDuration = 0,
					priority = "Blacklist,blockNoDuration,Personal,CCDebuffs,RaidDebuffs" --NamePlate EnemyPlayer Debuffs
				},
			},
			raidTargetIndicator = {
				size = 24,
				position = "LEFT",
				xOffset = -4,
				yOffset = 0
			},
		},
		FRIENDLY_NPC = {
			health = {
				enable = false,
				height = 10,
				width = 150,
				glowStyle = "TARGET_THREAT",
				text = {
					enable = false,
					format = "CURRENT",
					position = "CENTER",
					parent = "Health",
					xOffset = 0,
					yOffset = 0,
					font = "Friz Quadrata TT",
					fontOutline = "OUTLINE",
					fontSize = 11
				}
			},
			name = {
				enable = true,
				abbrev = true,
				noAbbreviation = true,
				noAbbreviationMaxChars = 30,
				position = "TOPLEFT",
				parent = "Health",
				xOffset = 0,
				yOffset = 2,
				font = "Friz Quadrata TT",
				fontOutline = "OUTLINE",
				fontSize = 11
			},
			level = {
				enable = true,
				position = "TOPRIGHT",
				parent = "Health",
				xOffset = 0,
				yOffset = 2,
				font = "Friz Quadrata TT",
				fontOutline = "OUTLINE",
				fontSize = 10
			},
			castbar = {
				enable = true,
				width = 150,
				height = 8,
				hideSpellName = false,
				hideTime = false,
				textPosition = "BELOW",
				castTimeFormat = "CURRENT",
				channelTimeFormat = "CURRENT",
				timeToHold = 0,
				iconPosition = "RIGHT",
				iconSize = 20,
				iconOffsetX = 2,
				iconOffsetY = 0,
				showIcon = true,
				xOffset = 0,
				yOffset = -2,
				font = "Friz Quadrata TT",
				fontSize = 11,
				fontOutline = "OUTLINE"
			},
			buffs = {
				enable = true,
				perrow = 6,
				size = 24,
				numrows = 1,
				yOffset = 20,
				xOffset = 0,
				attachTo = "FRAME",
				anchorPoint = "TOPLEFT",
				growthX = "RIGHT",
				growthY = "UP",
				onlyShowPlayer = false,
				spacing = 1,
				cooldownOrientation = "VERTICAL",
				reverseCooldown = false,
				countFont = "Friz Quadrata TT",
				countFontOutline = "OUTLINE",
				countFontSize = 11,
				countPosition = "BOTTOMRIGHT",
				countXOffset = -1,
				countYOffset = 1,
				durationFont = "Friz Quadrata TT",
				durationFontOutline = "OUTLINE",
				durationFontSize = 11,
				durationPosition = "CENTER",
				durationXOffset = 0,
				durationYOffset = 0,
				filters = {
					minDuration = 0,
					maxDuration = 0,
					priority = "Blacklist,blockNoDuration,Personal,TurtleBuffs" --NamePlate FriendlyNPC Buffs
				},
			},
			debuffs = {
				enable = true,
				perrow = 6,
				size = 24,
				numrows = 1,
				yOffset = 1,
				xOffset = 0,
				attachTo = "BUFFS",
				anchorPoint = "TOPRIGHT",
				growthX = "LEFT",
				growthY = "UP",
				onlyShowPlayer = false,
				spacing = 1,
				cooldownOrientation = "VERTICAL",
				reverseCooldown = false,
				countFont = "Friz Quadrata TT",
				countFontOutline = "OUTLINE",
				countFontSize = 11,
				countPosition = "BOTTOMRIGHT",
				countXOffset = -1,
				countYOffset = 1,
				durationFont = "Friz Quadrata TT",
				durationFontOutline = "OUTLINE",
				durationFontSize = 11,
				durationPosition = "CENTER",
				durationXOffset = 0,
				durationYOffset = 0,
				filters = {
					minDuration = 0,
					maxDuration = 0,
					priority = "Blacklist,CCDebuffs,RaidDebuffs" --NamePlate FriendlyNPC Debuffs
				},
			},
			eliteIcon = {
				enable = false,
				size = 15,
				position = "RIGHT",
				xOffset = 10,
				yOffset = 0
			},
			raidTargetIndicator = {
				size = 24,
				position = "LEFT",
				xOffset = -4,
				yOffset = 0
			},
			iconFrame = {
				enable = false,
				size = 24,
				parent = "Nameplate",
				position = "CENTER",
				xOffset = 0,
				yOffset = 42
			}
		},
		ENEMY_NPC = {
			health = {
				enable = true,
				height = 10,
				width = 150,
				glowStyle = "TARGET_THREAT",
				text = {
					enable = false,
					format = "CURRENT",
					position = "CENTER",
					parent = "Health",
					xOffset = 0,
					yOffset = 0,
					font = "Friz Quadrata TT",
					fontOutline = "OUTLINE",
					fontSize = 11
				}
			},
			name = {
				enable = true,
				abbrev = true,
				noAbbreviation = true,
				noAbbreviationMaxChars = 30,
				position = "TOPLEFT",
				parent = "Health",
				xOffset = 0,
				yOffset = 2,
				font = "Friz Quadrata TT",
				fontOutline = "OUTLINE",
				fontSize = 11
			},
			level = {
				enable = true,
				position = "TOPRIGHT",
				parent = "Health",
				xOffset = 0,
				yOffset = 2,
				font = "Friz Quadrata TT",
				fontOutline = "OUTLINE",
				fontSize = 10
			},
			castbar = {
				enable = true,
				width = 150,
				height = 8,
				hideSpellName = false,
				hideTime = false,
				textPosition = "BELOW",
				castTimeFormat = "CURRENT",
				channelTimeFormat = "CURRENT",
				timeToHold = 0,
				iconPosition = "LEFT",
				iconSize = 20,
				iconOffsetX = 2,
				iconOffsetY = 0,
				showIcon = true,
				xOffset = 0,
				yOffset = -2,
				font = "Friz Quadrata TT",
				fontSize = 11,
				fontOutline = "OUTLINE"
			},
			comboPoints = {
				enable = true,
				width = 8,
				height = 4,
				spacing = 5,
				xOffset = 0,
				yOffset = 0
			},
			buffs = {
				enable = true,
				perrow = 6,
				size = 24,
				numrows = 1,
				yOffset = 20,
				xOffset = 0,
				attachTo = "FRAME",
				anchorPoint = "TOPLEFT",
				growthX = "RIGHT",
				growthY = "UP",
				spacing = 1,
				cooldownOrientation = "VERTICAL",
				reverseCooldown = false,
				countFont = "Friz Quadrata TT",
				countFontOutline = "OUTLINE",
				countFontSize = 11,
				countPosition = "BOTTOMRIGHT",
				countXOffset = -1,
				countYOffset = 1,
				durationFont = "Friz Quadrata TT",
				durationFontOutline = "OUTLINE",
				durationFontSize = 11,
				durationPosition = "CENTER",
				durationXOffset = 0,
				durationYOffset = 0,
				filters = {
					minDuration = 0,
					maxDuration = 0,
					priority = "Blacklist,blockNoDuration,PlayerBuffs,TurtleBuffs" --NamePlate EnemyNPC Buffs
				},
			},
			debuffs = {
				enable = true,
				perrow = 6,
				size = 24,
				numrows = 1,
				yOffset = 1,
				xOffset = 0,
				attachTo = "BUFFS",
				anchorPoint = "TOPRIGHT",
				growthX = "LEFT",
				growthY = "UP",
				spacing = 1,
				cooldownOrientation = "VERTICAL",
				reverseCooldown = false,
				countFont = "Friz Quadrata TT",
				countFontOutline = "OUTLINE",
				countFontSize = 11,
				countPosition = "BOTTOMRIGHT",
				countXOffset = -1,
				countYOffset = 1,
				durationFont = "Friz Quadrata TT",
				durationFontOutline = "OUTLINE",
				durationFontSize = 11,
				durationPosition = "CENTER",
				durationXOffset = 0,
				durationYOffset = 0,
				filters = {
					minDuration = 0,
					maxDuration = 0,
					priority = "Blacklist,Personal,CCDebuffs" --NamePlate EnemyNPC Debuffs
				},
			},
			eliteIcon = {
				enable = false,
				size = 15,
				position = "RIGHT",
				xOffset = 10,
				yOffset = 0
			},
			raidTargetIndicator = {
				size = 24,
				position = "LEFT",
				xOffset = -4,
				yOffset = 0
			},
			iconFrame = {
				enable = false,
				size = 24,
				parent = "Nameplate",
				position = "CENTER",
				xOffset = 0,
				yOffset = 42
			}
		}
	}
}

