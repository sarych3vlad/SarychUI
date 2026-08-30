-- SarychUI Default Settings
-- Centralized defaults for all modules

local pairs = pairs

-- Helper function to deep copy tables
local function CopyTable(src, dest)
	if type(src) ~= "table" then return src end
	if type(dest) ~= "table" then dest = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dest[k] = CopyTable(v, dest[k])
		else
			dest[k] = v
		end
	end
	return dest
end

local platesAurasDisplayDefaults = {
	positions = {
		CentrY = 47,
		CastX = 50,
		CastY = 0,
		RightX = 5,
		RightY = -10,
		OtherX = 35,
		OtherY = 0,
		PlayerOffsetY = -7,
	},
	sizes = {
		ICON_SIZE_CONTROL = 46,
		ICON_SIZE_CAST = 46,
		ICON_SIZE_MOBILITY = 30,
		ICON_SIZE_OTHER = 30,
		ICON_SIZE_PLAYER = 28,
		ICON_SIZE_PLAYER_WIDTH = 30,
		ICON_SIZE_PLAYER_HEIGHT = 20,
		MAX_PLAYER_AURAS = 6,
		MAX_AURAS = 1,
	},
	display = {
		alpha = 1,
		scale = 1,
	},
	layout = {
		player = {
			spacing = 2,
			-- Alternative shape: a block on the right above the mob/other icons,
			-- two icons per row growing upward, instead of one row under the center.
			altRight = false,
		},
	},
}

local platesAurasElvUILayoutDefaults = {
	center = {
		anchorFrame = "health",
		point = "BOTTOM",
		relativePoint = "TOP",
		offsetMode = "fixed",
		offsetX = 0,
		widthFactor = 0,
		heightFactor = 0,
		noPlayerLift = 30,
	},
	right = {
		anchorFrame = "health",
		point = "LEFT",
		relativePoint = "RIGHT",
		offsetMode = "fixed",
		widthFactor = 0,
		heightFactor = 0,
	},
	player = {
		anchorFrame = "centerContainer",
		point = "TOP",
		relativePoint = "BOTTOM",
		offsetMode = "fixed",
		offsetX = 0,
		widthFactor = 0,
		heightFactor = 0,
		spacing = 2,
		altRight = false,
	},
}

-- Classic WoW nameplates: unchanged legacy defaults.
local platesAurasClassicProfileDefaults = CopyTable(platesAurasDisplayDefaults, {})

-- ElvUI nameplates: tuned defaults (positions tab + layout anchors).
local platesAurasElvuiProfileDefaults = CopyTable(platesAurasDisplayDefaults, {})
platesAurasElvuiProfileDefaults.positions = CopyTable(platesAurasDisplayDefaults.positions, {
	CentrY = 50,
	RightX = 11,
	RightY = 0,
	PlayerOffsetY = -10,
})
platesAurasElvuiProfileDefaults.display = CopyTable(platesAurasDisplayDefaults.display, {
	scale = 0.8,
})
platesAurasElvuiProfileDefaults.layout = CopyTable(platesAurasElvUILayoutDefaults, {})
platesAurasElvuiProfileDefaults.layout.right.offsetX = 11
platesAurasElvuiProfileDefaults.layout.right.offsetY = 10
platesAurasElvuiProfileDefaults.layout.center.offsetY = 60
platesAurasElvuiProfileDefaults.layout.player.offsetY = 10
-- Center icons only: grow slightly when the ElvUI plate scales (target etc.).
platesAurasElvuiProfileDefaults.plateResponsiveScale = {
	center = {
		enabled = true,
		factor = 0.55,
		maxBonus = 0.20,
	},
}

SarychUI.defaults = {
	profile = {
		-- General settings
		general = {
			enabled = true,
			minimap = {
				hide = false,
			},
		},

		-- wow_optimize.dll compatibility (optional, no hard dependency)
		compatibility = {
			wowOptimize = "auto", -- auto | enabled | disabled
			debug = false,
		},

		-- System (Система) settings
			system = {
			enableSpeedyLoad = 1,
			speedyLoadMode = "safe", -- safe | aggressive
			runtime = {
				enabled = true,
				uiCacheEnabled = true,
				preset = "standard", -- light | standard | heavy
				frameStepKB = 50,
				combatStepKB = 15,
				idleStepKB = 150,
				loadingStepKB = 300,
				fullCollectThresholdMB = 300,
				idleTimeout = 15,
				debug = false,
			},
		},
		
		-- Module settings
		modules = {
            -- Arena module
            arena = {
                enabled = true,
                frameType = "classic",
                -- Position (DragMode)
                arenaA = "RIGHT",
                arenaR = "RIGHT",
                arenaX = -311,
                arenaY = 131,
                showDragFrame = 0,
                showGrid = 0,
                -- Scale
                scale = 1.0,
                -- Test mode (0 = none, 2 = test 2, 3 = test 3, 5 = test 5)
                testMode = 0,
                -- Trinkets and Racial abilities
                Trinkets = {
                    enabled = true,
                    racialEnabled = true,
                    alwaysShow = true,
                    scale = 1.0,
                },
            },
            -- Tools module (ported sarTools settings, excluding NoCombatErrors)
            tools = {
                enabled = true,
                -- General
                enableFocuser = 1,
                focuserModifierKey = 2,  -- 1 = SHIFT, 2 = ALT, 3 = CONTROL (по умолчанию ALT)
                enableArenaRightClickFocus = 1,  -- ПКМ по арена фреймам = focus
                enableEscToOk = 1,
                enableAltFPS = 1,
                fpsOffsetX = 664,
                fpsOffsetY = 130,
                fpsScale = 1.0,
                fpsExtraOffsetX = 0,
                fpsExtraOffsetY = 0,
                -- Quest tracker (classic Blizzard / Dragonflight header style)
                questTrackerStyle = "dragonflight",
                questTrackerShowHeader = true,
                questTrackerDragonflightPosition = true,
                questTrackerX = 0,
                questTrackerY = -260,
                questTrackerShowDragFrame = 0,
                questTrackerShowGrid = 0,
                questTrackerFontSize = 11,
                enableAltCD = 1,
                enableAltUnitBars = 1,
                enableAltAuras = 1,

                -- Visual / combat text (moved to floating_text)

                -- Loot reanchor
                enableLootReanchor = 1,
                lootStartX = 0,
                lootStartY = 150,
                lootSpacing = 8,

                -- Loot roll vote counters (default Blizzard GroupLootFrame icons)
                enableLootRollCounts = 1,
                lootRollCountFont = "Friz Quadrata TT",
                lootRollCountFontSize = 12,
                lootRollCountFontOutline = "OUTLINE",

                -- Tooltip
                enableTooltipCursor = 0,
                tooltipCursorAltOnly = 1,

                -- Arena pointer
                enableArenaPointer = 1,

                -- Flight times
                enableShowFlightTimes = 1,
                
                -- Easy item destroy
                enableEasyItemDestroy = 1,
                
                -- Easy badge purchase
                enableBadgeStackBuyer = 1,
				
				-- BlizzMove
				enableBlizzMove = 1,
				blizzMoveMouseButton = "RightButton",
                blizzMoveFrames = {
                    AchievementFrame = {save = true},
                    CalendarFrame = {save = true},
                    AuctionFrame = {save = true},
                    GuildBankFrame = {save = true},
                },
                
				-- DarkMode
				enableDarkMode = 0,
				darkModeColor = {r = 0.37, g = 0.37, b = 0.37, a = 1},

				-- Resync stuck Blizzard BossNTargetFrame with UnitExists(bossN)
				fixBossFrames = 1,

				-- Chat extras (moved from chat → Утилиты)
				translitAliasesEnabled = 1,
				clearChatSlashEnabled = 1,

				-- WoWCircle (moved from chat)
				enableCircleContextMenu = 1,
				ppMessageFixEnabled = 1,
				spamFilterCombatDifficulty = 1,
            },
            
			-- Health Indicators (nameplate type selector; settings-only module)
            health_indicators = {
                enabled = true,
                nameplateMode = "elvui",
            },

            -- Loot coordination (pretty_lootalert via mode; LootClicker/LootHistory independent)
            loot = {
                mode = "pretty",
            },

            -- Map module (classic / Mapster / Carbonite selector)
            map = {
                enabled = true,
                mapType = "mapster",
            },

            -- Plates Auras module
            plates_auras = {
                enabled = true,
                useAwesomeWotlk = false,
                testModeEnabled = false,
                profileVersion = 3,
                spells = {
                    -- structure: [spellId] = { enabled=true, type="cc"|..., priority=1.., highlight=optional }
                },
                profiles = {
                    classic = CopyTable(platesAurasClassicProfileDefaults, {}),
                    elvui = CopyTable(platesAurasElvuiProfileDefaults, {}),
                },
            },

            -- Bags module
            bags = {
                enabled = true,
                mode = "default", -- "default" | "elvui" | "baudbag"
                enableBagSearch = true,
                elvui = {
                    showKeyring = true,
                    vendorGraysAuto = false,
                    disableBagSort = false,
                    -- classic = 3 toggles below; adibags = AdiBags-like sections + sort
                    splitMode = "classic",
                    -- When splitMode is adibags: toolbar toggle for category headers (does not fall back to classic)
                    adiBagsCategories = true,
                    consumableSplit = false,
                    ammoSplit = false,
                    questSplit = false,
                    -- AdiBags section headers
                    sectionHeaderFont = "Nimrod MT",
                    sectionHeaderFontSize = 14,
                    sectionHeaderFontScale = 0.75,
                    sectionHeaderFontOutline = "NONE",
                    sectionHeaderShadowX = 0,
                    sectionHeaderShadowY = 0,
                    scale = 1.05,
                    -- Main bag/bank window backdrop alpha (classic / categories off)
                    windowBackgroundAlpha = 0.65,
                    -- When AdiBags «категории предметов» are on
                    categoriesBackgroundAlpha = 0.85,
                    -- Reuse Dragonflight quest-tracker header strip on bag/bank title bar
                    dragonflightHeader = true,
                    bagColumns = 10,
                    bankColumns = 10,
                    bagFont = "Arial Narrow",
                    bagFontOutline = "OUTLINE",
                    bagFontShadowX = 0,
                    bagFontShadowY = 0,
                    stackFontSize = 13,
                    showItemLevel = false,
                    itemLevelFontSize = 13,
                    -- Footer (money + currencies)
                    footerFont = "Arial Narrow",
                    footerFontSize = 13,
                    footerFontOutline = "NONE",
                    footerShadowX = 1,
                    footerShadowY = -1,
                    footerMoneyIconSize = 14,
                    footerCurrencyIconSize = 15,
                    defaultPosition = {
                        point = "BOTTOMRIGHT",
                        relativePoint = "BOTTOMRIGHT",
                        relativeTo = "UIParent",
                        x = -20,
                        y = 130,
                    },
                    defaultBankPosition = {
                        point = "BOTTOMRIGHT",
                        relativePoint = "BOTTOMLEFT",
                        relativeTo = "ElvUI_ContainerFrame",
                        x = -10,
                        y = 0,
                    },
                },
            },

            -- Automation module
            automation = {
                enabled = true,
                enableAutoSellGrey = 1,
                enableAutoSellGreyRequireKey = 0,
                autoSellGreyKey = 1, -- 1=SHIFT, 2=ALT, 3=CONTROL
                enableAutoReleasePvP = 1,
                autoReleaseDelay = 200,
                enableAutoRepairGear = 1,
                autoRepairGearRequireKey = 0,
                autoRepairGearKey = 1, -- 1=SHIFT, 2=ALT, 3=CONTROL

                -- Кнопка сортировки сумок (стак + порядок, без банка)
                enableBagSortButton = 1,
                
                -- Auto train all skills
                enableAutoTrainAll = 0,
                autoTrainAllKey = 1, -- 1=SHIFT, 2=ALT, 3=CONTROL
                
                -- Quest automation
                enableQuestAutomation = 0,
                autoQuestAvailable = 1,
                autoQuestCompleted = 1,
                autoQuestRequireKey = 0,
                autoQuestKey = 1, -- 1=SHIFT, 2=ALT, 3=CONTROL
                
                -- Auto screenshot
                enableAutoScreenshot = 1,
            },
			-- Crowd Control (Cooldown text) module
			cc = {
				enabled = true,
				-- Font settings (LibSharedMedia name; legacy path values migrated)
				font = "Friz Quadrata TT",
				fontFlags = "OUTLINE",
				fontSizeSmall = 14,
				fontSizeMedium = 12,
				fontSizeLarge = 12,
				defaultColor = { 1, 1, 1, 1 },
				-- Behaviour
				minScale = 0.5,
				minDuration = 3,
				minIconSize = 23,
				-- Timers (moved from tools)
				enableCastbarTimers = 1,
				enableCastbarPlayer = 1,
				enableCastbarTarget = 1,
				enableCastbarFocus = 1,
				enableInviteCountdown = 1,
				enableArenaCountdown = 1,
			},

			-- Floating text filter (moved from tools)
			floating_text = {
				enabled = true,
				-- Error filter
				enableErrorFilter = 1,
				errorShowOriginalOnAlt = 1,
				errorTimeVisible = 1,
				errorFadeDuration = 1.5,
				errorFilteredOffsetY = -130,
				errorSysMsgOffsetY = -100,
				errorThrottleWindow = 0.5,
				errorPlaySound = 1,
				errorEchoToChat = 1,
				errorExtraEnabled = 1,
				errorExceptionPatterns = (GetLocale() == "ruRU")
					and "Вы должны подождать;Нет места."
					or "You must wait;Inventory is full.",
				errorHidePatterns = (GetLocale() == "ruRU")
					and "Способность пока недоступна."
					or "Ability is not ready yet.",
				-- Combat text
				enableHealCombatTextAdjust = 1,
				healShiftPlus = 1,
				healShiftMinus = 0,
				healShiftLess = 1,
				healHideLess = 1,
				healPlusX = -200,
				healPlusY = -70,
				healMinusX = 0,
				healMinusY = 0,
				healLessX = -250,
				healLessY = -30,
				combatTextPlusDrag = 0,
				combatTextMinusDrag = 0,
				combatTextLessDrag = 0,
				-- Raid boss emotes
				enableRaidBossEmoteReposition = 1,
				raidBossEmoteOffsetY = -430,
				raidBossEmoteMaxWidth = 600,
			},
			
			-- Main Menu Bar module
			mainmenubar = {
				enabled = true,
				
				-- Hotkey settings
				hideHotkeysEnabled = true,
				showHotkeysInCombat = true,
				showHotkeysOnAlt = true,
				showHotkeysWithTarget = true,
				hotkeysFadeAfterCombat = true,
				hotkeysFadeTime = 0.4,
				
				-- Macro settings
				hideMacroNames = true,
				
				-- Color indication settings
				colorCooldownEnabled = true,
				colorCooldownAlpha = 0.6,
				colorManaEnabled = true,
				colorRangeEnabled = true,
				colorUnusableEnabled = true,
				
				-- Appearance settings
				hideGryphons = true,
				hideActionBarBackgrounds = true,
				hideSecondaryPanelsBackgrounds = true,
				hideMaxLevelBar = true,
				hideKeyringButton = true,
				hidePageButtons = true,
				hidePageNumbers = true,
				showPageNumbersInCombat = true,
				showPageNumbersOnAlt = true,
				pageNumbersFadeAfterCombat = true,
				pageNumbersFadeTime = 0.5,
				
				-- Additional appearance settings
				buttonBorderAlphaEnabled = true,
				buttonBorderAlpha = 0.4,
				microMenuAlphaEnabled = true,
				microMenuAlpha = 0.95,
				-- classic | dragonflight (только текстуры микроменю)
				microMenuStyle = "classic",
				-- DF only: hide latency pip while green; show on yellow/red
				microMenuHideGreenLatency = true,
				hideReputationBar = true,
				showReputationBarOnAlt = true,
				showReputationBarOnGain = true,
				reputationBarFadeTime = 0.4,
				reputationBarShowTime = 1.1,
				hideExperienceBar = true,
				showExperienceBarOnAlt = true,
				showExperienceBarOnGain = true,
				experienceBarFadeTime = 0.4,
				experienceBarShowTime = 1.1,
				
				-- Side panels settings
				hideSidePanels = false,
				showSidePanelsOnAlt = true,
			},
			
			-- Minimap module
			minimap = {
				enabled = true,
                offsetX = -5,
                offsetY = -5,
                -- Drag Mode positioning
                minimapA = "TOPRIGHT",
                minimapR = "TOPRIGHT",
                minimapX = -5,
                minimapY = -5,
                showDragFrame = 0,
                showGrid = 0,
				hideDelay = 0.5,
				fadeTime = 0.1,
				hideBorder = 1,
				hideZoomButtons = 1,
				hideWorldMapButton = 1,
				hideClock = 0,
				hideTracking = 1,
				hideCalendar = 1,
				moveZoneText = 1,
				zoneTextOffsetX = 0,
				zoneTextOffsetY = 4,
				positioningEnabled = 0,
				buttonsEnabled = 1,
				addonButtons = {
					icons = {
						["LibDBIcon10_DBM"] = { managed = true, shown = true, angle = 40, radius = 82, scale = 1.0 },
						["LibDBIcon10_WeakAuras"] = { managed = true, shown = true, angle = 60, radius = 82, scale = 1.0 },
						["LibDBIcon10_Details"] = { managed = true, shown = true, angle = 130, radius = 82, scale = 1.0 },
						["LibDBIcon10_AtlasLoot"] = { managed = true, shown = true, angle = 190, radius = 82, scale = 1.0 },
						["LibDBIcon10_Collections"] = { managed = true, shown = true, angle = 300, radius = 82, scale = 1.0 },
						["LibDBIcon10_Transmogrify"] = { managed = true, shown = true, angle = 320, radius = 82, scale = 1.0 },
						["LibDBIcon10_TransmorpherMinimapButton"] = { managed = true, shown = true, angle = 340, radius = 82, scale = 1.0 },
					},
				},
				leftClickEnabled = 1,
				rightClickEnabled = 1,
				middleClickEnabled = 1,
				wheelEnabled = 1,
			},
			
			-- Frame module
			frame = {
				enabled = true,
				-- Positioning
				changePositions = 1,
				playerFrameX = -514,
				playerFrameY = 200,
				targetFrameX = -240,
				targetFrameY = 200,
				focusFrameX = 350,
				focusFrameY = -150,
				-- Drag mode for positioning
				showPositionDragFrame = 0,  -- legacy shared flag
				showPositionGrid = 0,  -- legacy shared grid flag
				showPlayerDragFrame = 0,
				showTargetDragFrame = 0,
				showFocusDragFrame = 0,
				-- Scale
				changeScale = 0,
				frameScale = 1.0,
				previousFrameScale = 1.0,
				-- Combat indicator
				enableCombatIndicator = 1,
				combatIndicatorPlayerX = 57,
				combatIndicatorPlayerY = 38,
				combatIndicatorTargetX = 57,
				combatIndicatorTargetY = 0,
				combatIndicatorFocusX = 57,
				combatIndicatorFocusY = 0,
				combatIndicatorScale = 0.85,
				-- Combat indicator elite offset
				combatIndicatorEliteOffset = 30,
				-- Combat indicator rogue offset
				combatIndicatorRogueOffset = 10,
				-- Text indicators
				showOnAlt = 1,
				showTextIndicatorsInCombat = false,
				textIndicatorsFadeAfterCombat = false,
				textIndicatorsFadeTime = 0.4,
				showPercentagesOnAlt = 1,
				showTargetPercent = 1,
				showFocusPercent = 0,
				warlockAlways = 1,
				warlockThreshold = 25,
				warriorPercentAlways = 1,
				paladinPercentAlways = 1,
				-- Visual toggles
				hidePVPIcons = 1,
				hidePlayerPVP = 1,
				hideTargetPVP = 1,
				hideFocusPVP = 1,
				hidePVPTimer = 1,
				pvpTimerOnAlt = 1,
				hidePlayerHitIndicator = 1,
				hidePetHitIndicator = 1,
				-- Class icons instead of portraits (players only; NPCs keep default)
				classIconPortraits = 0,
				-- When classIconPortraits is on: also replace PlayerFrame portrait (1) or keep face (0)
				classIconPortraitsPlayer = 1,
				-- Legacy key (unused)
				enable3DPortraits = 0,
				-- Pet name shortening (UI under Frames → Appearance)
				enablePetNameShortening = 1,
			},

			-- Auras module (extracted from frame)
			auras = {
				enabled = true,
				hideFocusAuras = 1,
				hideTargetOfTargetAuras = 1,
				enableDispelHighlight = 1,
				manageBuffs = 0,
				buffFrameA = "TOPRIGHT",
				buffFrameR = "TOPRIGHT",
				buffFrameX = -205,
				buffFrameY = -13,
				buffFrameScale = 1.0,
				showBuffDragFrame = 0,
				showBuffGrid = 0,
			},
			
			-- Chat module
			chat = {
				enabled = true,
				
			-- Chat Bar settings
			chatBarEnabled = 1,
			chatBarOnAlt = 1,
				
				-- Chat Fading settings
				visibleSecondsEnabled = 1,
				visibleSeconds = 12,
				
			-- Chat Hotkeys settings
			chatHotkeysEnabled = 1,  -- Включить горячие клавиши чата по умолчанию
			hotkeysYell = 1,
			hotkeysSay = 1,
			hotkeysAuto = 1,

			-- Chat tab font size menu + character counter
			enableChatTabFontSizeMenu = 1,
			enableChatCharCount = 1,
			chatFontSizes = {},

			-- Chat emotion icons + picker
			emotionIcons = 1,
			-- Off by default: emoji in chat bubbles need a WorldFrame poll
			emotionBubbles = 0,
			emotionPickerEnabled = 0,
			emotionPickerTriggerEnabled = 1,
			emotionPickerTrigger = "//",
				
				-- Chat Icons settings
				iconsEnabled = 1,
				
				-- Chat Spam Filter settings
				spamFilterEnabled = 1,
				
                -- Chat URL Copying settings
                urlCopyingEnabled = 1,
                
                -- Chat Copy on Ctrl+Click settings
                copyOnCtrlClickEnabled = 1,
				
				-- Chat Fast Scroll settings
				fastScrollEnabled = 1,
				fastScrollSteps = 5,
				
				-- Chat Appearance settings
				friendsButtonModEnabled = 1,
				hideChatFrameButtonEnabled = 1,
				hideChatScrollButtonsEnabled = 1,
				hideChatBottomButtonEnabled = 1,
				tabsStyleEnabled = 1,
				
				-- Chat Animations settings
				chatAnimationsEnabled = 1,
				chatTabShowDelay = 0.0,
				chatTabHideDelay = 0.0,
				chatFrameFadeTime = 0.10,
				chatFrameFadeOutTime = 0.15,
				
				-- Chat Tooltip settings
				tooltipPositionEnabled = 1,
				tooltipBaseOffset = 20,
				tooltipPetOffset = 60,
				itemRefIconsEnabled = 1,
				
				-- Chat Abbreviation settings: empty = Blizzard default channel name (no rewrite)
				lfgAbbrev = "",
				abbrGuild = "",
				abbrOfficer = "",
				abbrParty = "",
				abbrRaid = "",
				abbrRaidLeader = "",
				abbrRaidWarning = "",
				abbrBattleground = "",
				abbrBattlegroundLeader = "",
				abbrNumGeneral = "",
				abbrNumTrade = "",
				abbrNumLocalDefense = "",
				abbrNumGuildRecruitment = "",
				abbrNumWorldDefense = "",
				
				-- Chat Tab Animation settings
				tabShowDelayEnabled = 1,
				tabShowDelay = 0,
				tabHideDelayEnabled = 1,
				tabHideDelay = 5,
				tabFadeInEnabled = 1,
				tabFadeIn = 0.07,
				tabFadeOutEnabled = 1,
				tabFadeOut = 0.12,
				
				-- Chat Fading settings
				visibleSecondsEnabled = 1,
				
				-- Chat Spam Filter settings
				spamEnabledList = {
					"[Анонс БГ]:", "Авто-объявление", "Рейтинговое поле боя",
					"Welcome to World of Warcraft Server - WoW Circle",
					"На этой неделе доступен Наксрамас на героической сложности!",
					"Отключить путешествия во времени по подземельям Короля Лича",
					"В личном кабинете имеется магазин, в котором вы можете воспользоваться множеством услуг, счет бонусов можно пополнить множеством разных способов.",
					"Наши официальные веб ресурсы",
					"Если у вашего персонажа появилась какая-то проблема, то сначала воспользуйтесь услугой AntiError в личном кабинете, а только потом пишите на форум.",
					"Вы можете голосовать за сервер в личном кабинете",
					"Остерегайтесь подделок! Все актуальные адреса личных кабинетов находятся на нашем главном сайте.",
					"Если Вы испытываете проблемы, когда квестовый предмет долго не выпадает с моба",
					"ознакомьтесь пожалуйста с темой ",
					"За битву на рейтинговом поле боя ты можешь получить боевые монеты! Надо торопиться, это долго не продлится!",
					"Перед завершением торговли пожалуйста проверьте передаваемые предметы и количество золота.",
					"На этой неделе доступно Плато Солнечного Колодца на героической сложности!",
				},
				spamCustomList = {},
				spamDeletedList = {},

				chatWheel = {
					enabled = 1,
					key = nil,
					alwaysShow = 0,
					debugBoxEnabled = 0,
					debugBoxX = 0,
					debugBoxY = 0,
					debugBoxWidth = 180,
					debugBoxHeight = 180,
					innerDeadRadius = nil,
					outerCursorEnabled = 1,
					outerCursorSize = 32,
					outerCursorEdgePadding = nil,
					outerCursorMaxRadius = nil,
					outerCursorSafePadding = 14,
					circleBG2X = 0,
					circleBG2Y = -5,
					circleBG2Width = 109,
					circleBG2Height = 109,
					circlePNGX = 0,
					circlePNGY = -5,
					circlePNGWidth = 109,
					circlePNGHeight = 109,
					circlePointerX = -1,
					circlePointerY = 0,
					circlePointerWidth = 152,
					circlePointerHeight = 152,
					arrowEnabled = 1,
					arrowSize = 46,
					arrowGap = 6,
					arrowAnchorOffset = 0,
					arrowAlpha = 0.9,
					arrowAngle1 = 90,
					arrowAngle2 = 45,
					arrowAngle3 = 0,
					arrowAngle4 = -43,
					arrowAngle5 = -89,
					arrowAngle6 = -136,
					arrowAngle7 = 179,
					arrowAngle8 = 135,
					phraseOffset = 55,
					phraseFontSize = 20,
					phraseMaxWidth = 260,
					selectedPhraseScale = 1.15,
					phraseAnimSpeed = 30,
					phrase1X = 0,
					phrase1Y = 0,
					phrase2X = 0,
					phrase2Y = 0,
					phrase3X = 0,
					phrase3Y = 0,
					phrase4X = 0,
					phrase4Y = 0,
					phrase5X = 0,
					phrase5Y = 0,
					phrase6X = 0,
					phrase6Y = 0,
					phrase7X = 0,
					phrase7Y = 0,
					phrase8X = 0,
					phrase8Y = 0,
					chatWheelChannelMode = "adaptive",
					phrase1Text = "Фраза 1",
					phrase1Emote = "",
					phrase2Text = "Фраза 2",
					phrase2Emote = "",
					phrase3Text = "Фраза 3",
					phrase3Emote = "",
					phrase4Text = "Фраза 4",
					phrase4Emote = "",
					phrase5Text = "Фраза 5",
					phrase5Emote = "",
					phrase6Text = "Фраза 6",
					phrase6Emote = "",
					phrase7Text = "Фраза 7",
					phrase7Emote = "",
					phrase8Text = "Подтверждаю",
					phrase8Emote = "/кивок"
				},
			},
			
		},
		
		-- AddOns settings (from addons folder)
		addons = {
			-- UnitFrameLayers addon
			UnitFrameLayers = {
				enabled = true,
			},
			-- pw_lossofcontrol addon
			pw_lossofcontrol = {
				enabled = true,
			},
			-- BNetToast addon
			BNetToast = {
				enabled = true,
			},
			-- Cheese addon
			Cheese = {
				enabled = true,
			},
			-- GearScoreLite addon
			GearScoreLite = {
				enabled = true,
			},
			-- pretty_lootalert addon
			pretty_lootalert = {
				enabled = true,
				-- смещение тоста по Y, когда видна полоса каста игрока
				castbarOffsetEnabled = true,
				castbarOffsetY = 110,
			},
			-- FlashWindow addon
			FlashWindow = {
				enabled = true,
			},
			-- IdTip addon
			IdTip = {
				enabled = true,
				showOnAlt = true,
			},
			-- LevelUpDisplay addon
			LevelUpDisplay = {
				enabled = true,
			},
			-- LootClicker addon
			LootClicker = {
				enabled = true,
			},
			-- LootHistory addon
			LootHistory = {
				enabled = true,
			},
			-- BigDebuffs addon
			BigDebuffs = {
				enabled = true,
			},
			-- InternalCooldowns addon
			InternalCooldowns = {
				enabled = true,
			},
			-- OmniBar addon
			OmniBar = {
				enabled = true,
			},
			-- ElvUI NamePlates (embedded)
			ElvUI_NamePlates = {
				enabled = true,
			},
			-- GladiusEx (embedded)
			GladiusEx = {
				enabled = false,
			},
			-- Cromulent addon
			Cromulent = {
				enabled = true,
			},
			-- Mapster addon
			Mapster = {
				enabled = true,
			},
			-- !Astrolabe (map library)
			["!Astrolabe"] = {
				enabled = true,
			},
			-- WDM (WoW Dungeon Maps)
			WDM = {
				enabled = true,
			},
			-- External Carbonite (map mode flag only; addon lives in Interface/AddOns/Carbonite)
			Carbonite = {
				enabled = false,
			},
			-- Equipence (embedded)
			Equipence = {
				enabled = false,
			},
			-- TrufiGCD (embedded)
			TrufiGCD = {
				enabled = false,
			},
			-- Postal (strict embedded)
			Postal = {
				enabled = false,
				loadMode = "embedded",
			},
			-- SnowfallKeyPress addon
			SnowfallKeyPress = {
				enabled = true,
			},
			-- CL_Fix addon
			CL_Fix = {
				enabled = true,
			},
			-- Auctionator addon
			Auctionator = {
				enabled = true,
			},
			-- AddonList (replaces ACP)
			AddonList = {
				enabled = true,
				collapsed = {},
			},
			-- autolos addon (display profiles edited in Health Indicators module)
			autolos = {
				enabled = true,
				debug = false,
				profileVersion = 2,
				profiles = {
					classic = {
						font = "Friz Quadrata TT",
						fontSize = 12,
						fontOutline = "OUTLINE",
						shadowX = 2,
						shadowY = -1,
						offsetX = -95,
						offsetY = -9,
					},
					elvui = {
						font = "Friz Quadrata TT",
						fontSize = 10,
						fontOutline = "NONE",
						shadowX = 1,
						shadowY = -1,
						offsetX = -6,
						offsetY = 1,
						anchorToName = false,
						-- When ElvUI shows a totem as IconFrame (icon-only), anchor distance left of the icon.
						totemSupport = true,
					},
				},
			},
			-- CompactRaidFrame addon
			CompactRaidFrame = {
				enabled = true,
			},
			-- !!!ClassicAPI addon
			["!!!ClassicAPI"] = {
				enabled = true,
			},
			-- Bagnon_FT addon
			Bagnon_FT = {
				enabled = true,
				showOnAlt = false,
			},
			-- BaudBag (bags mode: baudbag)
			BaudBag = {
				enabled = false,
			},
			-- SarychUI Bags (bags mode: elvui)
			SarychUI_Bags = {
				enabled = false,
			},
			-- _Cursor (embedded)
			["_Cursor"] = {
				enabled = false,
			},
			-- BASpammer (embedded)
			BASpammer = {
				enabled = false,
			},
			-- InspectEquip (embedded)
			InspectEquip = {
				enabled = false,
			},
			-- FindGroup (embedded)
			FindGroup = {
				enabled = false,
			},
			-- RaidRoll (embedded: includes EPGP + LootTracker)
			RaidRoll = {
				enabled = true,
				skinStyle = "SarychUI", -- SarychUI | ElvUI
			},
			-- Talented (embedded)
			Talented = {
				enabled = true,
				skinStyle = "SarychUI", -- SarychUI | ElvUI
				dragonflightHeader = true,
			},
		},
		
		-- UI settings
		ui = {
			showWelcome = true,
		},
	},
	
	-- Global settings (not per character)
	global = {
		version = "1.0.0",
		general = {
			-- Saved size of the config window (matches ElvUI / ElvUI_NamePlates_Standalone defaults).
			AceGUI = {
				width = 1000,
				height = 720,
			},
			-- Custom OptionsCore window position (Details-like shell).
			optionsWindow = {
				point = nil,
				relativePoint = nil,
				x = nil,
				y = nil,
			},
			-- Details-like: one profile for all characters when enabled.
			alwaysUseProfile = false,
			alwaysUseProfileName = nil,
			-- SarychUI options language (independent of client GetLocale).
			uiLocale = nil,
		},
	},
	
	-- Character-specific settings
	char = {
		firstLogin = true,
	},
}

-- Initialize any missing defaults
local function ResolveAceDBProfile()
	if type(SarychUIDB) ~= "table" or type(SarychUIDB.profiles) ~= "table" then
		return
	end

	-- Per-character key; shared "*" only when "use on all characters" is enabled.
	local profileKey = (SarychUI_ResolveSavedProfileKey and SarychUI_ResolveSavedProfileKey()) or "Default"

	local profile = SarychUIDB.profiles[profileKey]
	if type(profile) ~= "table" then
		-- Do not steal another character's profile: fall back to Default only.
		profile = SarychUIDB.profiles.Default
		profileKey = "Default"
	end

	if type(profile) == "table" then
		SarychUIDB.profile = profile
	end
end

local function MigrateProfileDefaults(profile)
	if type(profile) ~= "table" then
		return
	end

	if not profile.compatibility then
		profile.compatibility = CopyTable(SarychUI.defaults.profile.compatibility)
	end

	if not profile.system then
		profile.system = CopyTable(SarychUI.defaults.profile.system)
	else
		local sysDef = SarychUI.defaults.profile.system
		if profile.system.enableSpeedyLoad == nil then
			profile.system.enableSpeedyLoad = sysDef.enableSpeedyLoad
		end
		if profile.system.speedyLoadMode == nil then
			profile.system.speedyLoadMode = sysDef.speedyLoadMode
		end
		if not profile.system.runtime then
			profile.system.runtime = CopyTable(sysDef.runtime)
		else
			for k, v in pairs(sysDef.runtime) do
				if profile.system.runtime[k] == nil then
					profile.system.runtime[k] = v
				end
			end
		end
	end

	if not profile.modules then
		profile.modules = CopyTable(SarychUI.defaults.profile.modules)
	end

	for moduleName, moduleDefaults in pairs(SarychUI.defaults.profile.modules) do
		if not profile.modules[moduleName] then
			profile.modules[moduleName] = CopyTable(moduleDefaults)
		end
	end

	local bagsDb = profile.modules and profile.modules.bags
	local bagsDefaults = SarychUI.defaults.profile.modules.bags
	if bagsDb and bagsDefaults then
		if bagsDb.enabled == nil then
			bagsDb.enabled = bagsDefaults.enabled
		end
		if bagsDb.mode == nil then
			if bagsDb.bagType == "elvui" or bagsDb.bagType == "classic" then
				bagsDb.mode = bagsDb.bagType == "elvui" and "elvui" or "default"
			else
				bagsDb.mode = bagsDefaults.mode
			end
		end
		-- Синхронизация bags.mode ↔ addons.BaudBag / SarychUI_Bags
		local addonsForBags = profile.addons
		if addonsForBags then
			-- Migrate renamed embed key (ElvUI_Bags → SarychUI_Bags).
			if type(addonsForBags.ElvUI_Bags) == "table" and type(addonsForBags.SarychUI_Bags) ~= "table" then
				addonsForBags.SarychUI_Bags = CopyTable(addonsForBags.ElvUI_Bags)
			end
			addonsForBags.BaudBag = addonsForBags.BaudBag or { enabled = false }
			addonsForBags.SarychUI_Bags = addonsForBags.SarychUI_Bags or { enabled = false }
			local mode = bagsDb.mode
			if mode == "classic" then
				mode = "default"
				bagsDb.mode = "default"
			end
			addonsForBags.BaudBag.enabled = (mode == "baudbag")
			addonsForBags.SarychUI_Bags.enabled = (mode == "elvui")
		end
		if bagsDb.enableBagSearch == nil then
			bagsDb.enableBagSearch = bagsDefaults.enableBagSearch
		end
		if type(bagsDb.elvui) ~= "table" then
			bagsDb.elvui = CopyTable(bagsDefaults.elvui)
		end
		if bagsDb.elvui.defaultPosition == nil and bagsDefaults.elvui.defaultPosition then
			bagsDb.elvui.defaultPosition = CopyTable(bagsDefaults.elvui.defaultPosition)
		end
		if bagsDb.elvui.defaultBankPosition == nil and bagsDefaults.elvui.defaultBankPosition then
			bagsDb.elvui.defaultBankPosition = CopyTable(bagsDefaults.elvui.defaultBankPosition)
		end
		-- One-shot: lock approved slot-text baseline into existing profiles.
		if bagsDb.elvui._slotTextDefaultsRev ~= 1 then
			bagsDb.elvui.bagFont = bagsDefaults.elvui.bagFont or "Arial Narrow"
			bagsDb.elvui.bagFontOutline = bagsDefaults.elvui.bagFontOutline or "OUTLINE"
			bagsDb.elvui.bagFontShadowX = bagsDefaults.elvui.bagFontShadowX ~= nil and bagsDefaults.elvui.bagFontShadowX or 0
			bagsDb.elvui.bagFontShadowY = bagsDefaults.elvui.bagFontShadowY ~= nil and bagsDefaults.elvui.bagFontShadowY or 0
			bagsDb.elvui.stackFontSize = bagsDefaults.elvui.stackFontSize or 13
			bagsDb.elvui.itemLevelFontSize = bagsDefaults.elvui.itemLevelFontSize or 13
			bagsDb.elvui._slotTextDefaultsRev = 1
		end
		if bagsDb.elvui.showItemLevel == nil then
			bagsDb.elvui.showItemLevel = false
		end
		if bagsDb.elvui.splitMode == nil then
			bagsDb.elvui.splitMode = bagsDefaults.elvui.splitMode or "classic"
		elseif bagsDb.elvui.splitMode ~= "adibags" then
			bagsDb.elvui.splitMode = "classic"
		end
		if bagsDb.elvui.adiBagsCategories == nil then
			bagsDb.elvui.adiBagsCategories = bagsDefaults.elvui.adiBagsCategories ~= false
		end
		if bagsDb.elvui.consumableSplit == nil then
			bagsDb.elvui.consumableSplit = bagsDefaults.elvui.consumableSplit == true
		end
		if bagsDb.elvui.ammoSplit == nil then
			bagsDb.elvui.ammoSplit = bagsDefaults.elvui.ammoSplit == true
		end
		if bagsDb.elvui.questSplit == nil then
			bagsDb.elvui.questSplit = bagsDefaults.elvui.questSplit == true
		end
		-- One-shot: Nimrod 14 @ 0.75 scale, no outline/shadow for AdiBags section headers.
		if bagsDb.elvui._sectionHeaderDefaultsRev ~= 4 then
			bagsDb.elvui.sectionHeaderFont = bagsDefaults.elvui.sectionHeaderFont or "Nimrod MT"
			bagsDb.elvui.sectionHeaderFontSize = bagsDefaults.elvui.sectionHeaderFontSize or 14
			bagsDb.elvui.sectionHeaderFontScale = bagsDefaults.elvui.sectionHeaderFontScale or 0.75
			bagsDb.elvui.sectionHeaderFontOutline = bagsDefaults.elvui.sectionHeaderFontOutline or "NONE"
			bagsDb.elvui.sectionHeaderShadowX = bagsDefaults.elvui.sectionHeaderShadowX ~= nil and bagsDefaults.elvui.sectionHeaderShadowX or 0
			bagsDb.elvui.sectionHeaderShadowY = bagsDefaults.elvui.sectionHeaderShadowY ~= nil and bagsDefaults.elvui.sectionHeaderShadowY or 0
			bagsDb.elvui._sectionHeaderDefaultsRev = 4
		end
		if bagsDb.elvui.sectionHeaderFont == nil then
			bagsDb.elvui.sectionHeaderFont = bagsDefaults.elvui.sectionHeaderFont or "Nimrod MT"
		end
		if bagsDb.elvui.sectionHeaderFontSize == nil then
			bagsDb.elvui.sectionHeaderFontSize = bagsDefaults.elvui.sectionHeaderFontSize or 14
		end
		if bagsDb.elvui.sectionHeaderFontScale == nil then
			bagsDb.elvui.sectionHeaderFontScale = bagsDefaults.elvui.sectionHeaderFontScale or 0.75
		end
		if bagsDb.elvui.sectionHeaderFontOutline == nil then
			bagsDb.elvui.sectionHeaderFontOutline = bagsDefaults.elvui.sectionHeaderFontOutline or "NONE"
		end
		if bagsDb.elvui.sectionHeaderShadowX == nil then
			bagsDb.elvui.sectionHeaderShadowX = bagsDefaults.elvui.sectionHeaderShadowX ~= nil and bagsDefaults.elvui.sectionHeaderShadowX or 0
		end
		if bagsDb.elvui.sectionHeaderShadowY == nil then
			bagsDb.elvui.sectionHeaderShadowY = bagsDefaults.elvui.sectionHeaderShadowY ~= nil and bagsDefaults.elvui.sectionHeaderShadowY or 0
		end
		if bagsDb.elvui.scale == nil then
			bagsDb.elvui.scale = bagsDefaults.elvui.scale or 1.05
		end
		if bagsDb.elvui.dragonflightHeader == nil then
			bagsDb.elvui.dragonflightHeader = bagsDefaults.elvui.dragonflightHeader ~= false
		end
		-- One-shot: previous window alpha default was 0.85 → 0.65; add categories alpha.
		if bagsDb.elvui._windowAlphaDefaultsRev ~= 1 then
			if bagsDb.elvui.windowBackgroundAlpha == nil or bagsDb.elvui.windowBackgroundAlpha == 0.85 then
				bagsDb.elvui.windowBackgroundAlpha = bagsDefaults.elvui.windowBackgroundAlpha or 0.65
			end
			if bagsDb.elvui.categoriesBackgroundAlpha == nil then
				bagsDb.elvui.categoriesBackgroundAlpha = bagsDefaults.elvui.categoriesBackgroundAlpha or 0.85
			end
			bagsDb.elvui._windowAlphaDefaultsRev = 1
		end
		if bagsDb.elvui.windowBackgroundAlpha == nil then
			bagsDb.elvui.windowBackgroundAlpha = bagsDefaults.elvui.windowBackgroundAlpha or 0.65
		end
		if bagsDb.elvui.categoriesBackgroundAlpha == nil then
			bagsDb.elvui.categoriesBackgroundAlpha = bagsDefaults.elvui.categoriesBackgroundAlpha or 0.85
		end
		-- One-shot: migrate previous bag scale default (1) to 1.05.
		if bagsDb.elvui._bagScaleDefaultsRev ~= 1 then
			if bagsDb.elvui.scale == nil or bagsDb.elvui.scale == 1 then
				bagsDb.elvui.scale = bagsDefaults.elvui.scale or 1.05
			end
			bagsDb.elvui._bagScaleDefaultsRev = 1
		end
		if bagsDb.elvui.bagFont == nil and bagsDefaults.elvui.bagFont then
			bagsDb.elvui.bagFont = bagsDefaults.elvui.bagFont
		end
		if bagsDb.elvui.bagFontOutline == nil and bagsDefaults.elvui.bagFontOutline then
			bagsDb.elvui.bagFontOutline = bagsDefaults.elvui.bagFontOutline
		end
		if bagsDb.elvui.bagFontShadowX == nil and bagsDefaults.elvui.bagFontShadowX ~= nil then
			bagsDb.elvui.bagFontShadowX = bagsDefaults.elvui.bagFontShadowX
		end
		if bagsDb.elvui.bagFontShadowY == nil and bagsDefaults.elvui.bagFontShadowY ~= nil then
			bagsDb.elvui.bagFontShadowY = bagsDefaults.elvui.bagFontShadowY
		end
		if bagsDb.elvui.stackFontSize == nil and bagsDefaults.elvui.stackFontSize then
			bagsDb.elvui.stackFontSize = bagsDefaults.elvui.stackFontSize
		end
		if bagsDb.elvui.bagColumns == nil and bagsDefaults.elvui.bagColumns then
			bagsDb.elvui.bagColumns = bagsDefaults.elvui.bagColumns
		end
		if bagsDb.elvui.bankColumns == nil and bagsDefaults.elvui.bankColumns then
			bagsDb.elvui.bankColumns = bagsDefaults.elvui.bankColumns
		end
		if bagsDb.elvui.itemLevelFontSize == nil and bagsDefaults.elvui.itemLevelFontSize then
			bagsDb.elvui.itemLevelFontSize = bagsDefaults.elvui.itemLevelFontSize
		end
		-- One-shot: lock approved footer baseline into existing profiles.
		if bagsDb.elvui._footerDefaultsRev ~= 1 then
			bagsDb.elvui.footerFont = bagsDefaults.elvui.footerFont or "Arial Narrow"
			bagsDb.elvui.footerFontSize = bagsDefaults.elvui.footerFontSize or 13
			bagsDb.elvui.footerMoneyIconSize = bagsDefaults.elvui.footerMoneyIconSize or 14
			bagsDb.elvui.footerCurrencyIconSize = bagsDefaults.elvui.footerCurrencyIconSize or 15
			bagsDb.elvui._footerDefaultsRev = 1
		end
		if bagsDb.elvui.footerFont == nil and bagsDefaults.elvui.footerFont then
			bagsDb.elvui.footerFont = bagsDefaults.elvui.footerFont
		end
		if bagsDb.elvui.footerFontSize == nil and bagsDefaults.elvui.footerFontSize then
			bagsDb.elvui.footerFontSize = bagsDefaults.elvui.footerFontSize
		end
		if bagsDb.elvui.footerFontOutline == nil and bagsDefaults.elvui.footerFontOutline then
			bagsDb.elvui.footerFontOutline = bagsDefaults.elvui.footerFontOutline
		end
		if bagsDb.elvui.footerShadowX == nil and bagsDefaults.elvui.footerShadowX ~= nil then
			bagsDb.elvui.footerShadowX = bagsDefaults.elvui.footerShadowX
		end
		if bagsDb.elvui.footerShadowY == nil and bagsDefaults.elvui.footerShadowY ~= nil then
			bagsDb.elvui.footerShadowY = bagsDefaults.elvui.footerShadowY
		end
		if bagsDb.elvui.footerMoneyIconSize == nil and bagsDefaults.elvui.footerMoneyIconSize then
			bagsDb.elvui.footerMoneyIconSize = bagsDefaults.elvui.footerMoneyIconSize
		end
		if bagsDb.elvui.footerCurrencyIconSize == nil and bagsDefaults.elvui.footerCurrencyIconSize then
			bagsDb.elvui.footerCurrencyIconSize = bagsDefaults.elvui.footerCurrencyIconSize
		end
	end

	local mapDb = profile.modules and profile.modules.map
	local mapDefaults = SarychUI.defaults.profile.modules.map
	if mapDb and mapDefaults then
		if mapDb.enabled == nil then
			mapDb.enabled = mapDefaults.enabled
		end
		if mapDb.mapType == nil then
			mapDb.mapType = mapDefaults.mapType
		end
	end
	
	if not profile.addons then
		profile.addons = CopyTable(SarychUI.defaults.profile.addons)
	end

	for addonName, addonDefaults in pairs(SarychUI.defaults.profile.addons) do
		if not profile.addons[addonName] then
			profile.addons[addonName] = CopyTable(addonDefaults)
		end
	end
	if profile.addons.Talented and profile.addons.Talented.dragonflightHeader == nil then
		profile.addons.Talented.dragonflightHeader = true
	end

	local modules = profile.modules
	if modules and modules.tools and modules.tools.fpsScale == nil then
		modules.tools.fpsScale = 1.0
	end
	if modules and modules.tools and modules.tools.enableAltUnitBars == nil then
		modules.tools.enableAltUnitBars = SarychUI.defaults.profile.modules.tools.enableAltUnitBars
	end
	if modules and modules.tools and modules.tools.enableAltAuras == nil then
		modules.tools.enableAltAuras = SarychUI.defaults.profile.modules.tools.enableAltAuras
	end
	if modules and modules.tools and modules.tools.fixBossFrames == nil then
		modules.tools.fixBossFrames = SarychUI.defaults.profile.modules.tools.fixBossFrames
	end
	if modules and modules.tools and modules.tools.fpsExtraOffsetX == nil then
		modules.tools.fpsExtraOffsetX = 0
	end
	if modules and modules.tools and modules.tools.fpsExtraOffsetY == nil then
		modules.tools.fpsExtraOffsetY = 0
	end
	if modules and modules.tools and modules.tools.questTrackerStyle == nil then
		modules.tools.questTrackerStyle = "dragonflight"
	elseif modules and modules.tools and modules.tools.questTrackerStyle ~= "dragonflight" then
		modules.tools.questTrackerStyle = "classic"
	end
	if modules and modules.tools and modules.tools.questTrackerShowHeader == nil then
		modules.tools.questTrackerShowHeader = true
	end
	if modules and modules.tools and modules.tools.questTrackerDragonflightPosition == nil then
		modules.tools.questTrackerDragonflightPosition = true
	end
	if modules and modules.tools and modules.tools.questTrackerX == nil then
		modules.tools.questTrackerX = 0
	end
	-- One-shot: previous DF tracker default X was -10.
	if modules and modules.tools and modules.tools._questTrackerXDefaultRev ~= 1 then
		if modules.tools.questTrackerX == nil or modules.tools.questTrackerX == -10 then
			modules.tools.questTrackerX = 0
		end
		modules.tools._questTrackerXDefaultRev = 1
	end
	if modules and modules.tools and modules.tools.questTrackerY == nil then
		modules.tools.questTrackerY = -260
	end
	if modules and modules.tools and modules.tools.questTrackerShowDragFrame == nil then
		modules.tools.questTrackerShowDragFrame = 0
	end
	if modules and modules.tools and modules.tools.questTrackerShowGrid == nil then
		modules.tools.questTrackerShowGrid = 0
	end
	if modules and modules.tools and modules.tools.questTrackerFontSize == nil then
		modules.tools.questTrackerFontSize = 11
	end
	if modules and modules.tools and modules.tools.errorSysMsgOffsetY == nil then
		modules.tools.errorSysMsgOffsetY = SarychUI.defaults.profile.modules.tools.errorSysMsgOffsetY
	end

	local frameDb = modules and modules.frame
	local frameDef = SarychUI.defaults.profile.modules.frame
	local aurasDb = modules and modules.auras
	local aurasDef = SarychUI.defaults.profile.modules.auras
	local toolsDbForFrame = modules and modules.tools
	if frameDb and frameDef then
		if frameDb.enablePetNameShortening == nil then
			if toolsDbForFrame and toolsDbForFrame.enablePetNameShortening ~= nil then
				frameDb.enablePetNameShortening = toolsDbForFrame.enablePetNameShortening
			else
				frameDb.enablePetNameShortening = frameDef.enablePetNameShortening
			end
		end
		if frameDb.enable3DPortraits == nil then
			frameDb.enable3DPortraits = frameDef.enable3DPortraits
		end
		if frameDb.classIconPortraits == nil then
			frameDb.classIconPortraits = frameDef.classIconPortraits
		end
		if frameDb.classIconPortraitsPlayer == nil then
			frameDb.classIconPortraitsPlayer = frameDef.classIconPortraitsPlayer
		end
	end
	-- Migrate aura settings from frame → auras (and legacy tools dispel).
	-- If frame still holds legacy keys, copy them over (overwrite fresh defaults).
	if aurasDb then
		local auraKeys = {
			"hideFocusAuras",
			"hideTargetOfTargetAuras",
			"enableDispelHighlight",
			"manageBuffs",
			"buffFrameA",
			"buffFrameR",
			"buffFrameX",
			"buffFrameY",
			"buffFrameScale",
			"showBuffDragFrame",
			"showBuffGrid",
		}
		local hadLegacy = false
		if frameDb then
			for _, key in ipairs(auraKeys) do
				if frameDb[key] ~= nil then
					hadLegacy = true
					break
				end
			end
		end
		if hadLegacy and frameDb then
			for _, key in ipairs(auraKeys) do
				if frameDb[key] ~= nil then
					aurasDb[key] = frameDb[key]
				end
				frameDb[key] = nil
			end
		elseif toolsDbForFrame and toolsDbForFrame.enableDispelHighlight ~= nil and aurasDb.enableDispelHighlight == nil then
			aurasDb.enableDispelHighlight = toolsDbForFrame.enableDispelHighlight
		end
		if aurasDb.enabled == nil then
			aurasDb.enabled = true
		end
	end

	-- cc.font: migrate legacy file paths → LibSharedMedia font names
	local ccDb = modules and modules.cc
	local ccDef = SarychUI.defaults.profile.modules.cc
	if ccDb then
		local font = ccDb.font
		if type(font) == "string" and font:find("\\") then
			local lower = font:lower()
			if lower:find("frizqt") or lower:find("friz") then
				ccDb.font = "Friz Quadrata TT"
			elseif lower:find("arialn") then
				ccDb.font = "Arial Narrow"
			elseif lower:find("skurri") then
				ccDb.font = "Skurri"
			elseif lower:find("morpheus") then
				ccDb.font = "Morpheus"
			else
				ccDb.font = (ccDef and ccDef.font) or "Friz Quadrata TT"
			end
		elseif font == nil and ccDef then
			ccDb.font = ccDef.font
		end
	end

	if modules and modules.tools and modules.chat then
		if modules.chat.enableChatCharCount == nil and modules.tools.enableChatCharCount ~= nil then
			modules.chat.enableChatCharCount = modules.tools.enableChatCharCount
		end
	end

	local chatDb = modules and modules.chat
	local chatDef = SarychUI.defaults.profile.modules.chat
	if chatDb and chatDef and chatDef.chatWheel then
		if type(chatDb.chatWheel) ~= "table" then
			chatDb.chatWheel = CopyTable(chatDef.chatWheel)
		else
			local cw = chatDb.chatWheel
			if cw.enabled == nil then cw.enabled = chatDef.chatWheel.enabled end
			if cw.key == nil then cw.key = chatDef.chatWheel.key end
			if cw.alwaysShow == nil then cw.alwaysShow = chatDef.chatWheel.alwaysShow end
			if cw.debugBoxEnabled == nil then cw.debugBoxEnabled = chatDef.chatWheel.debugBoxEnabled end
			if cw.debugBoxX == nil then cw.debugBoxX = chatDef.chatWheel.debugBoxX end
			if cw.debugBoxY == nil then cw.debugBoxY = chatDef.chatWheel.debugBoxY end
			if cw.debugBoxWidth == nil then cw.debugBoxWidth = chatDef.chatWheel.debugBoxWidth end
			if cw.debugBoxHeight == nil then cw.debugBoxHeight = chatDef.chatWheel.debugBoxHeight end
			if cw.innerDeadRadius == nil then cw.innerDeadRadius = chatDef.chatWheel.innerDeadRadius end
			if cw.outerCursorEnabled == nil then cw.outerCursorEnabled = chatDef.chatWheel.outerCursorEnabled end
			if cw.outerCursorSize == nil then cw.outerCursorSize = chatDef.chatWheel.outerCursorSize end
			if cw.outerCursorEdgePadding == nil then cw.outerCursorEdgePadding = chatDef.chatWheel.outerCursorEdgePadding end
			if cw.outerCursorMaxRadius == nil then cw.outerCursorMaxRadius = chatDef.chatWheel.outerCursorMaxRadius end
			if cw.outerCursorSafePadding == nil then cw.outerCursorSafePadding = chatDef.chatWheel.outerCursorSafePadding end
			if cw.circleBG2X == nil then cw.circleBG2X = chatDef.chatWheel.circleBG2X end
			if cw.circleBG2Y == nil then cw.circleBG2Y = chatDef.chatWheel.circleBG2Y end
			if cw.circleBG2Width == nil then cw.circleBG2Width = chatDef.chatWheel.circleBG2Width end
			if cw.circleBG2Height == nil then cw.circleBG2Height = chatDef.chatWheel.circleBG2Height end
			if cw.circlePNGX == nil then cw.circlePNGX = chatDef.chatWheel.circlePNGX end
			if cw.circlePNGY == nil then cw.circlePNGY = chatDef.chatWheel.circlePNGY end
			if cw.circlePNGWidth == nil then cw.circlePNGWidth = chatDef.chatWheel.circlePNGWidth end
			if cw.circlePNGHeight == nil then cw.circlePNGHeight = chatDef.chatWheel.circlePNGHeight end
			if cw.circlePointerX == nil then cw.circlePointerX = chatDef.chatWheel.circlePointerX end
			if cw.circlePointerY == nil then cw.circlePointerY = chatDef.chatWheel.circlePointerY end
			if cw.circlePointerWidth == nil then cw.circlePointerWidth = chatDef.chatWheel.circlePointerWidth end
			if cw.circlePointerHeight == nil then cw.circlePointerHeight = chatDef.chatWheel.circlePointerHeight end
			if cw.arrowEnabled == nil then cw.arrowEnabled = chatDef.chatWheel.arrowEnabled end
			if cw.arrowSize == nil then cw.arrowSize = chatDef.chatWheel.arrowSize end
			if cw.arrowGap == nil then cw.arrowGap = chatDef.chatWheel.arrowGap end
			if cw.arrowAnchorOffset == nil then cw.arrowAnchorOffset = chatDef.chatWheel.arrowAnchorOffset end
			if cw.arrowAlpha == nil then cw.arrowAlpha = chatDef.chatWheel.arrowAlpha end
			for i = 1, 8 do
				local key = "arrowAngle" .. i
				if cw[key] == nil then cw[key] = chatDef.chatWheel[key] end
			end
			if cw.phraseOffset == nil then cw.phraseOffset = chatDef.chatWheel.phraseOffset end
			if cw.phraseFontSize == nil then cw.phraseFontSize = chatDef.chatWheel.phraseFontSize end
			if cw.phraseMaxWidth == nil then cw.phraseMaxWidth = chatDef.chatWheel.phraseMaxWidth end
			if cw.selectedPhraseScale == nil then cw.selectedPhraseScale = chatDef.chatWheel.selectedPhraseScale end
			if cw.phraseAnimSpeed == nil then cw.phraseAnimSpeed = chatDef.chatWheel.phraseAnimSpeed end
			if cw.chatWheelChannelMode == nil then cw.chatWheelChannelMode = chatDef.chatWheel.chatWheelChannelMode end
			for i = 1, 8 do
				local textKey = "phrase" .. i .. "Text"
				local emoteKey = "phrase" .. i .. "Emote"
				local xKey = "phrase" .. i .. "X"
				local yKey = "phrase" .. i .. "Y"
				if cw[textKey] == nil then cw[textKey] = chatDef.chatWheel[textKey] end
				if cw[emoteKey] == nil then cw[emoteKey] = chatDef.chatWheel[emoteKey] end
				if cw[xKey] == nil then cw[xKey] = chatDef.chatWheel[xKey] end
				if cw[yKey] == nil then cw[yKey] = chatDef.chatWheel[yKey] end
			end
		end
	end

	local addons = profile.addons
	if modules and modules.arena and addons and addons.GladiusEx then
		if addons.GladiusEx.enabled == true then
			modules.arena.frameType = "gladiusex"
		elseif modules.arena.frameType == nil then
			modules.arena.frameType = "classic"
		elseif modules.arena.frameType == "gladiusex" and addons.GladiusEx.enabled ~= true then
			addons.GladiusEx.enabled = true
		elseif modules.arena.frameType == "classic" and addons.GladiusEx.enabled == nil then
			addons.GladiusEx.enabled = false
		end
	end

	if modules and modules.map and addons then
		addons.Mapster = addons.Mapster or { enabled = true }
		addons.Carbonite = addons.Carbonite or { enabled = false }

		if modules.map.mapType == nil then
			modules.map.mapType = "mapster"
		end

		if modules.map.mapType == "carbonite" then
			if SarychUI and SarychUI.IsExternalCarboniteAvailable and not SarychUI:IsExternalCarboniteAvailable() then
				modules.map.mapType = "mapster"
				addons.Mapster.enabled = true
				addons.Carbonite.enabled = false
			else
				addons.Carbonite.enabled = true
				addons.Mapster.enabled = false
			end
		elseif modules.map.mapType == "mapster" then
			addons.Mapster.enabled = true
			addons.Carbonite.enabled = false
		elseif modules.map.mapType == "classic" then
			addons.Mapster.enabled = false
			addons.Carbonite.enabled = false
		end
	end

	if addons and addons.Postal then
		addons.Postal.loadMode = "embedded"
	end

	-- Removed: custom automation mail collect (CollectAllMail) — use embedded Postal only.
	-- Removed: sarAutoConfirm / WowCircle email confirm chain.
	local automationDb = modules and modules.automation
	if automationDb then
		automationDb.enableAutoCollectMail = nil
		automationDb.autoCollectMailRequireKey = nil
		automationDb.autoCollectMailKey = nil
		automationDb.enableAutoConfirm = nil
		automationDb.autoConfirmShowChat = nil
		automationDb.autoConfirmEmail = nil
	end

	-- Removed: weather density override (tools).
	-- Removed: raid target icons radial menu (tools.rti).
	-- Moved: SpeedyLoad → system (Система).
	-- Moved: castbar / invite / arena countdown timers → cc (Текст перезарядки).
	-- Moved: pet name shortening → frame (Фреймы).
	-- Moved: dispel highlight / buff management / focus-ToT auras → auras (Ауры).
	local toolsDb = modules and modules.tools
	local frameDb = modules and modules.frame
	local aurasDb = modules and modules.auras
	local ccDb = modules and modules.cc
	if toolsDb then
		toolsDb.enableWeatherDensity = nil
		toolsDb.weatherLevel = nil
		toolsDb.rti = nil
		if profile.system and profile.system.enableSpeedyLoad == nil and toolsDb.enableSpeedyLoad ~= nil then
			profile.system.enableSpeedyLoad = toolsDb.enableSpeedyLoad
		end
		toolsDb.enableSpeedyLoad = nil
		if frameDb then
			if frameDb.enablePetNameShortening == nil and toolsDb.enablePetNameShortening ~= nil then
				frameDb.enablePetNameShortening = toolsDb.enablePetNameShortening
			end
		end
		if aurasDb then
			if aurasDb.enableDispelHighlight == nil then
				if frameDb and frameDb.enableDispelHighlight ~= nil then
					aurasDb.enableDispelHighlight = frameDb.enableDispelHighlight
				elseif toolsDb.enableDispelHighlight ~= nil then
					aurasDb.enableDispelHighlight = toolsDb.enableDispelHighlight
				end
			end
		end
		toolsDb.enableDispelHighlight = nil
		toolsDb.enablePetNameShortening = nil
		if frameDb then
			frameDb.enableDispelHighlight = nil
		end
		if ccDb then
			local timerKeys = {
				"enableCastbarTimers",
				"enableCastbarPlayer",
				"enableCastbarTarget",
				"enableCastbarFocus",
				"enableInviteCountdown",
				"enableArenaCountdown",
			}
			for _, key in ipairs(timerKeys) do
				if ccDb[key] == nil and toolsDb[key] ~= nil then
					ccDb[key] = toolsDb[key]
				end
				toolsDb[key] = nil
			end
		else
			toolsDb.enableCastbarTimers = nil
			toolsDb.enableCastbarPlayer = nil
			toolsDb.enableCastbarTarget = nil
			toolsDb.enableCastbarFocus = nil
			toolsDb.enableInviteCountdown = nil
			toolsDb.enableArenaCountdown = nil
		end
	end

	-- Moved: floating text filter (errors / combat text / boss emotes) → floating_text.
	local floatingDb = modules and modules.floating_text
	if toolsDb then
		local floatingKeys = {
			"enableErrorFilter",
			"errorShowOriginalOnAlt",
			"errorTimeVisible",
			"errorFadeDuration",
			"errorFilteredOffsetY",
			"errorSysMsgOffsetY",
			"errorThrottleWindow",
			"errorPlaySound",
			"errorEchoToChat",
			"errorExtraEnabled",
			"errorExceptionPatterns",
			"errorHidePatterns",
			"enableHealCombatTextAdjust",
			"healShiftPlus",
			"healShiftMinus",
			"healShiftLess",
			"healHideLess",
			"healPlusX",
			"healPlusY",
			"healMinusX",
			"healMinusY",
			"healLessX",
			"healLessY",
			"combatTextPlusDrag",
			"combatTextMinusDrag",
			"combatTextLessDrag",
			"enableRaidBossEmoteReposition",
			"raidBossEmoteOffsetY",
			"raidBossEmoteMaxWidth",
		}
		if floatingDb then
			for _, key in ipairs(floatingKeys) do
				if floatingDb[key] == nil and toolsDb[key] ~= nil then
					floatingDb[key] = toolsDb[key]
				end
				toolsDb[key] = nil
			end
		else
			for _, key in ipairs(floatingKeys) do
				toolsDb[key] = nil
			end
		end
	end
end

local function CollectStoredProfiles()
	local seen = {}
	local list = {}
	local function add(profile)
		if type(profile) == "table" and not seen[profile] then
			seen[profile] = true
			list[#list + 1] = profile
		end
	end

	if type(SarychUIDB) == "table" and type(SarychUIDB.profiles) == "table" then
		for _, profile in pairs(SarychUIDB.profiles) do
			add(profile)
		end
	end

	ResolveAceDBProfile()
	add(SarychUIDB and SarychUIDB.profile)

	if SarychUI and SarychUI.GetActiveProfile then
		add(SarychUI:GetActiveProfile())
	end

	return list
end

local function InitializeDefaults()
	ResolveAceDBProfile()

	if not SarychUIDB then
		SarychUIDB = {}
	end

	if SarychUI and SarychUI.db and SarychUI.db.profile then
		SarychUIDB.profile = SarychUI.db.profile
	elseif not SarychUIDB.profile then
		SarychUIDB.profile = CopyTable(SarychUI.defaults.profile)
	end

	if not SarychUIDB.global then
		SarychUIDB.global = CopyTable(SarychUI.defaults.global)
	elseif not SarychUIDB.global.general then
		SarychUIDB.global.general = CopyTable(SarychUI.defaults.global.general)
	elseif not SarychUIDB.global.general.AceGUI then
		SarychUIDB.global.general.AceGUI = CopyTable(SarychUI.defaults.global.general.AceGUI)
	end

	for _, profile in ipairs(CollectStoredProfiles()) do
		MigrateProfileDefaults(profile)
	end

	if type(SarychUIDB.bagSortPinnedItemIDs) ~= "table" then
		SarychUIDB.bagSortPinnedItemIDs = { 43231, 43233 }
	end

	if SarychUI and SarychUI.ResolveFeatureConflicts then
		SarychUI:ResolveFeatureConflicts()
	end

	if SarychUI and SarychUI.SyncLegacyProfileStorage then
		SarychUI:SyncLegacyProfileStorage()
	end
end

-- Resolve AceDB profile before embedded addons read SarychUIDB during .toc load.
ResolveAceDBProfile()

-- Call initialization on addon load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "SarychUI" then
		InitializeDefaults()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
