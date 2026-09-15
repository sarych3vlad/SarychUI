--[[
	Enum tables that ClassicAPI 1.23 shipped and 1.27 no longer defines.
	Kept because addons bundled with SarychUI still read them
	(Equipence/Aegis uses Enum.TooltipDataType).
]]

local Enum = Enum

Enum.ItemReagentSubclass = Enum.ItemReagentSubclass or {
	Reagent = 0,
	Keystone = 1,
	ContextToken = 2,
}

Enum.BattlePetTypes = Enum.BattlePetTypes or {
	Humanoid = 0,
	Dragonkin = 1,
	Flying = 2,
	Undead = 3,
	Critter = 4,
	Magic = 5,
	Elemental = 6,
	Beast = 7,
	Aquatic = 8,
	Mechanical = 9,
	NonCombat = 10,
}

Enum.ItemProfessionSubclass = Enum.ItemProfessionSubclass or {
	Blacksmithing = 0,
	Leatherworking = 1,
	Alchemy = 2,
	Herbalism = 3,
	Cooking = 4,
	Mining = 5,
	Tailoring = 6,
	Engineering = 7,
	Enchanting = 8,
	Fishing = 9,
	Skinning = 10,
	Jewelcrafting = 11,
	Inscription = 12,
	Archaeology = 13,
}

Enum.AuctionHouseNotification = Enum.AuctionHouseNotification or {
	BidPlaced = 0,
	AuctionRemoved = 1,
	AuctionWon = 2,
	AuctionOutbid = 3,
	AuctionSold = 4,
	AuctionExpired = 5,
}

Enum.AuctionHouseSortOrder = Enum.AuctionHouseSortOrder or {
	Price = 0,
	Name = 1,
	Level = 2,
	Bid = 3,
	Buyout = 4,
	TimeRemaining = 5,
}

Enum.CraftingReagentType = Enum.CraftingReagentType or {
	Modifying = 0,
	Basic = 1,
	Finishing = 2,
	Automatic = 3,
}

Enum.MountType = Enum.MountType or {
	Ground = 0,
	Flying = 1,
	Aquatic = 2,
	Dragonriding = 3,
	RideAlong = 4,
}

Enum.TooltipDataType = Enum.TooltipDataType or {
	Item = 0,
	Spell = 1,
	Unit = 2,
	Corpse = 3,
	Object = 4,
	Currency = 5,
	BattlePet = 6,
	UnitAura = 7,
	AzeriteEssence = 8,
	CompanionPet = 9,
	Mount = 10,
	PetAction = 11,
	Achievement = 12,
	EnhancedConduit = 13,
	EquipmentSet = 14,
	InstanceLock = 15,
	PvPBrawl = 16,
	RecipeRankInfo = 17,
	Totem = 18,
	Toy = 19,
	CorruptionCleanser = 20,
	MinimapMouseover = 21,
	Flyout = 22,
	Quest = 23,
	QuestPartyProgress = 24,
	Macro = 25,
	Debug = 26,
}

Enum.GossipNpcOption = Enum.GossipNpcOption or {
	None = 0,
	Vendor = 1,
	Taxinode = 2,
	Trainer = 3,
	SpiritHealer = 4,
	Binder = 5,
	Banker = 6,
	PetitionVendor = 7,
	GuildTabardVendor = 8,
	Battlemaster = 9,
	Auctioneer = 10,
	TalentMaster = 11,
	Stablemaster = 12,
	PetUntrainer = 13,
	GuildBanker = 14,
	Spellclick = 15,
	DisableXPGain = 16,
	EnableXPGain = 17,
	Mailbox = 18,
	WorldPvPQueue = 19,
	LFGDungeon = 20,
	ArtifactRespec = 21,
	CemeterySelect = 22,
	SpecializationMaster = 23,
	GlyphMaster = 24,
	QueueScenario = 25,
	GarrisonArchitect = 26,
	GarrisonMissionNpc = 27,
	ShipmentCrafter = 28,
	GarrisonTradeskillNpc = 29,
	GarrisonRecruitment = 30,
	AdventureMap = 31,
	GarrisonTalent = 32,
	ContributionCollector = 33,
	Transmogrify = 34,
	AzeriteRespec = 35,
	IslandsMissionNpc = 36,
	UIItemInteraction = 37,
	WorldMap = 38,
	Soulbind = 39,
	ChromieTimeNpc = 40,
	CovenantPreviewNpc = 41,
	RuneforgeLegendaryCrafting = 42,
	NewPlayerGuide = 43,
	RuneforgeLegendaryUpgrade = 44,
	CovenantRenownNpc = 45,
	BlackMarketAuctionHouse = 46,
	PerksProgramVendor = 47,
	ProfessionsCraftingOrder = 48,
	ProfessionsOpen = 49,
	ProfessionsCustomerOrder = 50,
	TraitSystem = 51,
	BarbersChoice = 52,
	MajorFactionRenown = 53,
	PersonalTabardVendor = 54,
	ForgeMaster = 55,
	CharacterBanker = 56,
	AccountBanker = 57,
}
