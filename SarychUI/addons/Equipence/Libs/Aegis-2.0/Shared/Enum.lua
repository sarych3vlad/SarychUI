--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local VERSION = 2;

local _ENUMS = {
	ItemSocketType = {
		None = 0,
		Meta = 1,
		Red = 2,
		Yellow = 3,
		Blue = 4,
		Hydraulic = 5,
		Cogwheel = 6,
		Prismatic = 7,
		Iron = 8,
		Blood = 9,
		Shadow = 10,
		Fel = 11,
		Arcane = 12,
		Frost = 13,
		Fire = 14,
		Water = 15,
		Life = 16,
		Wind = 17,
		Holy = 18,
		PunchcardRed = 19,
		PunchcardYellow = 20,
		PunchcardBlue = 21,
		Domination = 22,
		Cypher = 23,
		Tinker = 24,
		Primordial = 25,
		Fragrance = 26,
		SingingThunder = 27,
		SingingSea = 28,
		SingingWind = 29,
		Fiber = 30,
	},
	ItemGemColor = {
		Meta = 0x1,
		Red = 0x2,
		Yellow = 0x4,
		Blue = 0x8,
		Hydraulic = 0x10,
		Cogwheel = 0x20,
		Iron = 0x40,
		Blood = 0x80,
		Shadow = 0x100,
		Fel = 0x200,
		Arcane = 0x400,
		Frost = 0x800,
		Fire = 0x1000,
		Water = 0x2000,
		Life = 0x4000,
		Wind = 0x8000,
		Holy = 0x10000,
		PunchcardRed = 0x20000,
		PunchcardYellow = 0x40000,
		PunchcardBlue = 0x80000,
		DominationBlood = 0x100000,
		DominationFrost = 0x200000,
		DominationUnholy = 0x400000,
		Cypher = 0x800000,
		Tinker = 0x1000000,
		Primordial = 0x2000000,
		Fragrance = 0x4000000,
		SingingThunder = 0x8000000,
		SingingSea = 0x10000000,
		SingingWind = 0x20000000,
		Fiber = 0x40000000,
	},
	ItemGemSubclass = {
		Intellect = 0,
		Agility = 1,
		Strength = 2,
		Stamina = 3,
		Spirit = 4,
		Criticalstrike = 5,
		Mastery = 6,
		Haste = 7,
		Versatility = 8,
		Other = 9,
		Multiplestats = 10,
		Artifactrelic = 11,
	},
	TooltipDataType = {
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
		Outfit = 27,
	},
	TooltipDataLineType = {
		None = 0,
		Blank = 1,
		UnitName = 2,
		GemSocket = 3,
		AzeriteEssenceSlot = 4,
		AzeriteEssencePower = 5,
		LearnableSpell = 6,
		UnitThreat = 7,
		QuestObjective = 8,
		AzeriteItemPowerDescription = 9,
		RuneforgeLegendaryPowerDescription = 10,
		SellPrice = 11,
		ProfessionCraftingQuality = 12,
		SpellName = 13,
		CurrencyTotal = 14,
		ItemEnchantmentPermanent = 15,
		UnitOwner = 16,
		QuestTitle = 17,
		QuestPlayer = 18,
		NestedBlock = 19,
		ItemBinding = 20,
		EquipSlot = 21,
		ItemName = 22,
		Separator = 23,
		ToyName = 24,
		ToyText = 25,
		ToyEffect = 26,
		ToyDuration = 27,
		ToyDescription = 28,
		ToySource = 29,
		GemSocketEnchantment = 30,
		ItemLevel = 31,
		ItemUpgradeLevel = 32,
		SpellPassive = 33,
		SpellDescription = 34,
		ItemQuality = 35,
		TradeTimeRemaining = 36,
		FlavorText = 37,
		ItemSpellTriggerLearn = 38,
		LearnTransmogSet = 39,
		LearnTransmogIllusion = 40,
		ErrorLine = 41,
		DisabledLine = 42,
		UsageRequirement = 43,
	},
	TooltipDataItemBinding = {
		Quest = 0,
		Account = 1,
		BnetAccount = 2,
		Soulbound = 3,
		BindToAccount = 4,
		BindToBnetAccount = 5,
		BindOnPickup = 6,
		BindOnEquip = 7,
		BindOnUse = 8,
		AccountUntilEquipped = 9,
		BindToAccountUntilEquipped = 10,
	},
};

local function CopyMissingEntries(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			target[key] = value;
		end
	end
end

local function CopyEntries(target, source)
	if not source then
		return;
	end

	for key, value in pairs(source) do
		target[key] = value;
	end
end

Aegis:RegisterNamespace("Enum", VERSION, function(_, _, namespace, native)
	local Enum = namespace or {};

	for enumName, defaults in pairs(_ENUMS) do
		local enum = {};
		CopyEntries(enum, native and native[enumName]);
		CopyMissingEntries(enum, defaults);
		Enum[enumName] = enum;
	end

	return Enum;
end, { trustNative = true, wrapNative = true });