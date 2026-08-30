local E, L, V, P, G = unpack(_G.SarychUI_Bags)

V.bags = {
	enable = false,
	bagBar = false,
}

G.bags = {
	ignoredItems = {},
}

-- Per-character bank snapshots for offline "view bank" (keyed by realm-player).
G.bankCache = {}

G.general = {
	AceGUI = { width = 900, height = 600 },
}

P.layoutSetting = "ALL"
P.movers = {}

P.general = {
	font = "Friz Quadrata TT",
	fontSize = 12,
	fontStyle = "OUTLINE",
	stickyFrames = false,
	bordercolor = { r = 0, g = 0, b = 0 },
	backdropcolor = { r = 0.1, g = 0.1, b = 0.1 },
	backdropfadecolor = { r = 0.06, g = 0.06, b = 0.06, a = 0.8 },
	valuecolor = { r = 0.99, g = 0.48, b = 0.17 },
}

P.tooltip = {
	colorAlpha = 0.8,
}

P.cooldown = {
	enable = true,
	reverse = false,
	threshold = 3,
	checkSeconds = true,
	hhmmThreshold = 24,
	mmssThreshold = 60,
	useIndicatorColor = false,
	daysColor = "|cffeeeeee",
	hoursColor = "|cffeeeeee",
	minutesColor = "|cffeeeeee",
	secondsColor = "|cffeeeeee",
	expiringColor = "|cfffe0000",
	mmssColor = "|cff909090",
	hhmmColor = "|cff707070",
	daysIndicator = { r = 0.93, g = 0.93, b = 0.93 },
	hoursIndicator = { r = 0.93, g = 0.93, b = 0.93 },
	minutesIndicator = { r = 0.93, g = 0.93, b = 0.93 },
	secondsIndicator = { r = 0.93, g = 0.93, b = 0.93 },
	expireIndicator = { r = 0.99, g = 0, b = 0 },
	mmssColorIndicator = { r = 0.57, g = 0.57, b = 0.57 },
	hhmmColorIndicator = { r = 0.44, g = 0.44, b = 0.44 },
	fonts = {
		enable = false,
		font = "Friz Quadrata TT",
		fontSize = 18,
		fontOutline = "OUTLINE",
	},
}

P.bags = {
	sortInverted = true,
	bagSize = 34,
	bankSize = 34,
	bagWidth = 406,
	bankWidth = 406,
	bagColumns = 10,
	bankColumns = 10,
	splitMode = "classic", -- classic | adibags
	adiBagsCategories = true, -- visual category sections when splitMode is adibags
	consumableSplit = false,
	ammoSplit = false,
	questSplit = false,
	currencyFormat = "ICON",
	moneyFormat = "SMART",
	moneyCoins = true,
	junkIcon = false,
	junkDesaturate = true,
	ignoredItems = {},
	itemLevel = false,
	itemLevelThreshold = 1,
	itemLevelFont = "Friz Quadrata TT",
	itemLevelFontSize = 10,
	itemLevelFontOutline = "OUTLINE",
	countFont = "Friz Quadrata TT",
	countFontSize = 10,
	countFontOutline = "OUTLINE",
	countFontColor = { r = 1, g = 1, b = 1 },
	reverseSlots = false,
	clearSearchOnClose = false,
	disableBagSort = false,
	disableBankSort = false,
	strata = "DIALOG",
	qualityColors = true,
	showBindType = false,
	transparent = false,
	questIcon = true,
	professionBagColors = true,
	questItemColors = true,
	colors = {
		profession = {
			quiver = { r = 1, g = 0.69, b = 0.41 },
			ammoPouch = { r = 1, g = 0.69, b = 0.41 },
			soulBag = { r = 1, g = 0.69, b = 0.41 },
			leatherworking = { r = 0.88, g = 0.73, b = 0.29 },
			inscription = { r = 0.29, g = 0.30, b = 0.88 },
			herbs = { r = 0.07, g = 0.71, b = 0.13 },
			enchanting = { r = 0.76, g = 0.02, b = 0.8 },
			engineering = { r = 0.91, g = 0.46, b = 0.18 },
			gems = { r = 0.03, g = 0.71, b = 0.81 },
			mining = { r = 0.54, g = 0.40, b = 0.04 },
		},
		items = {
			questStarter = { r = 1, g = 1, b = 0 },
			questItem = { r = 1, g = 0.30, b = 0.30 },
		},
	},
	vendorGrays = {
		enable = false,
		interval = 0.2,
		details = false,
		progressBar = true,
	},
	split = {
		bagSpacing = 5,
		player = false,
		bank = false,
		bag1 = false,
		bag2 = false,
		bag3 = false,
		bag4 = false,
	},
	cooldown = {
		override = false,
		reverse = false,
		threshold = 3,
	},
	bagBar = {
		growthDirection = "VERTICAL",
		sortDirection = "ASCENDING",
		size = 30,
		spacing = 4,
		backdropSpacing = 4,
		showBackdrop = false,
		mouseover = false,
		visibility = "",
	},
}
