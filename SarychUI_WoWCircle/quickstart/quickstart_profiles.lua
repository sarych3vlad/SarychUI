-- SarychUI Quick Start profiles
-- Account-wide profile storage, compact options cards and the standalone editor.

local SUI = SarychUI
if not SUI then
	return
end

local BUILTIN_KEY = "__builtin"
local PROFILE_VERSION = 1
local editor
local socketLayoutCache = {}

local GOLD = { 0.95, 0.82, 0.20 }
local TEXT = { 0.92, 0.92, 0.94 }
local DIM = { 0.62, 0.62, 0.66 }
local GREEN = { 0.35, 0.90, 0.45 }
local RED = { 0.90, 0.38, 0.38 }

local SLOT_DEFS = {
	{ id = 1,  name = "Голова", side = "left" },
	{ id = 2,  name = "Шея", side = "left", enchantable = false },
	{ id = 3,  name = "Плечи", side = "left" },
	{ id = 15, name = "Спина", side = "left" },
	{ id = 5,  name = "Грудь", side = "left" },
	{ id = 4,  name = "Рубашка", side = "left", enchantable = false },
	{ id = 19, name = "Накидка", side = "left", enchantable = false },
	{ id = 9,  name = "Наручи", side = "left" },
	{ id = 10, name = "Кисти рук", side = "right" },
	{ id = 6,  name = "Пояс", side = "right" },
	{ id = 7,  name = "Ноги", side = "right" },
	{ id = 8,  name = "Ступни", side = "right" },
	{ id = 11, name = "Кольцо 1", side = "right" },
	{ id = 12, name = "Кольцо 2", side = "right" },
	{ id = 13, name = "Аксессуар 1", side = "right", enchantable = false },
	{ id = 14, name = "Аксессуар 2", side = "right", enchantable = false },
	{ id = 16, name = "Правая рука", side = "bottom" },
	{ id = 17, name = "Левая рука", side = "bottom" },
	{ id = 18, name = "Дальний бой", side = "bottom" },
}

local SLOT_BY_ID = {}
for i = 1, #SLOT_DEFS do
	SLOT_BY_ID[SLOT_DEFS[i].id] = SLOT_DEFS[i]
end

local function IsEnchantableSlot(slot)
	local slotDef = SLOT_BY_ID[tonumber(slot)]
	return slotDef and slotDef.enchantable ~= false
end

local PROFESSION_DEFS = {
	{ key = "alchemy", label = "Алхимия", needles = { "алхим", "alchemy" } },
	{ key = "blacksmithing", label = "Кузнечное дело", needles = { "кузнеч", "blacksmith" } },
	{ key = "enchanting", label = "Наложение чар", needles = { "наложени", "зачаров", "enchant" } },
	{ key = "engineering", label = "Инженерное дело", needles = { "инженер", "engineer" } },
	{ key = "herbalism", label = "Травничество", needles = { "травнич", "herbal" } },
	{ key = "inscription", label = "Начертание", needles = { "начерт", "inscription" } },
	{ key = "jewelcrafting", label = "Ювелирное дело", needles = { "ювелир", "jewel" } },
	{ key = "leatherworking", label = "Кожевничество", needles = { "кожевн", "leather" } },
	{ key = "mining", label = "Горное дело", needles = { "горн", "mining" } },
	{ key = "skinning", label = "Снятие шкур", needles = { "сняти", "skinning" } },
	{ key = "tailoring", label = "Портняжное дело", needles = { "портн", "tailor" } },
	{ key = "cooking", label = "Кулинария", needles = { "кулинар", "cooking" }, secondary = true },
	{ key = "firstaid", label = "Первая помощь", needles = { "первую помощь", "первой помощи", "first aid" }, secondary = true },
	{ key = "fishing", label = "Рыбная ловля", needles = { "рыбн", "fishing" }, secondary = true },
}

local function T(text)
	return SUI.T and SUI:T(text) or text
end

local function DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[DeepCopy(key)] = DeepCopy(child)
	end
	return copy
end

local function Trim(text)
	return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function AddCount(map, order, id, count)
	id = tonumber(id)
	count = math.floor(tonumber(count) or 1)
	if not id or id < 1 or count < 1 then
		return
	end
	if not map[id] then
		map[id] = 0
		order[#order + 1] = id
	end
	map[id] = map[id] + count
end

local function AccountStore()
	local root
	if SUI.db then
		SUI.db.global = SUI.db.global or {}
		root = SUI.db.global
	else
		SarychUIDB = SarychUIDB or {}
		SarychUIDB.global = SarychUIDB.global or {}
		root = SarychUIDB.global
	end
	if type(root.quickStartProfiles) ~= "table" then
		root.quickStartProfiles = { version = PROFILE_VERSION, nextID = 1, order = {}, entries = {} }
	end
	local store = root.quickStartProfiles
	store.version = PROFILE_VERSION
	store.nextID = tonumber(store.nextID) or 1
	store.order = type(store.order) == "table" and store.order or {}
	store.entries = type(store.entries) == "table" and store.entries or {}
	return store, root
end

local function FindNPC(runtime, predicate)
	for i = 1, #(runtime.setupNPCs or {}) do
		local npc = runtime.setupNPCs[i]
		if predicate(npc) then
			return npc
		end
	end
end

local builtinProfile
local function BuildBuiltinProfile()
	if builtinProfile then
		return builtinProfile
	end
	local runtime = SUI:GetQuickStartBuiltinRuntime()
	local catalog = SUI.QuickStartDefaultCatalog
	local profile = {
		version = PROFILE_VERSION,
		name = runtime.name or "Bonjourepta",
		serverKey = type(catalog) == "table" and catalog.serverKey or "wowcirclefun",
		talentTemplate = runtime.talentTemplate or "Bonjourepta",
		bag = { itemID = runtime.quickBuyItemID, count = runtime.quickBuyCount },
		mount = { itemID = runtime.mountItemID, spellID = runtime.mountSpellID },
		gear = {},
		glyphs = DeepCopy(runtime.glyphItems or {}),
		professions = { blacksmithing = true, jewelcrafting = true, cooking = true, firstaid = true },
		extraItems = {},
		vendorItems = {},
		sellItems = {},
		professionSockets = DeepCopy(runtime.professionSockets or {}),
	}

	for i = 1, #(runtime.wearItems or {}) do
		local row = runtime.wearItems[i]
		local id, slot = tonumber(row.id or row[1]), tonumber(row.slot or row[2])
		if id and slot then
			profile.gear[slot] = { itemID = id, gems = {} }
		end
	end
	for i = 1, #(runtime.itemEnchants or {}) do
		local row = runtime.itemEnchants[i]
		local slot = tonumber(row.slot)
		if slot then
			profile.gear[slot] = profile.gear[slot] or { gems = {} }
			profile.gear[slot].enchantID = tonumber(row.id)
			profile.gear[slot].enchantName = row.name
		end
	end
	for i = 1, #(runtime.itemSockets or {}) do
		local target = runtime.itemSockets[i]
		local slot = tonumber(target.slot)
		if slot then
			profile.gear[slot] = profile.gear[slot] or { gems = {} }
			profile.gear[slot].socketName = target.name
			profile.gear[slot].gems = DeepCopy(target.gems or {})
		end
	end

	local vendor = FindNPC(runtime, function(npc) return npc and npc.kind == "vendor" end)
	if vendor then
		profile.vendorItems = DeepCopy(vendor.items or {})
		profile.sellItems = DeepCopy(vendor.sellItems or {})
	end

	local vendorIDs = {}
	for i = 1, #profile.vendorItems do
		local row = profile.vendorItems[i]
		vendorIDs[tonumber(row.id or row[1])] = true
	end
	local consumed, consumedOrder = {}, {}
	AddCount(consumed, consumedOrder, profile.bag.itemID, profile.bag.count)
	for _, gear in pairs(profile.gear) do
		if gear.itemID and not vendorIDs[gear.itemID] then
			AddCount(consumed, consumedOrder, gear.itemID, 1)
		end
		AddCount(consumed, consumedOrder, gear.enchantID, 1)
		for i = 1, #(gear.gems or {}) do
			AddCount(consumed, consumedOrder, gear.gems[i].id or gear.gems[i], 1)
		end
	end
	for i = 1, #profile.glyphs do
		AddCount(consumed, consumedOrder, profile.glyphs[i], 1)
	end
	AddCount(consumed, consumedOrder, profile.mount.itemID, 1)
	for i = 1, #profile.professionSockets do
		for j = 1, #(profile.professionSockets[i].reagents or {}) do
			local reagent = profile.professionSockets[i].reagents[j]
			AddCount(consumed, consumedOrder, reagent.id or reagent[1], reagent.count or reagent[2])
		end
	end
	for i = 1, #(runtime.quickBuyItems or {}) do
		local row = runtime.quickBuyItems[i]
		local id, count = tonumber(row.id or row[1]), tonumber(row.count or row[2]) or 1
		local used = id and (consumed[id] or 0) or 0
		local left = count - used
		if id and left > 0 then
			profile.extraItems[#profile.extraItems + 1] = { id = id, count = left }
		end
		if id then
			consumed[id] = math.max(0, used - count)
		end
	end

	builtinProfile = profile
	return builtinProfile
end

local function NormalizeItemRows(rows, limit)
	local result = {}
	for i = 1, #(type(rows) == "table" and rows or {}) do
		local row = rows[i]
		local id = tonumber(type(row) == "table" and (row.id or row[1]) or row)
		local count = tonumber(type(row) == "table" and (row.count or row[2]) or 1) or 1
		if id and id > 0 then
			result[#result + 1] = { id = math.floor(id), count = math.max(1, math.floor(count)) }
			if limit and #result >= limit then
				break
			end
		end
	end
	return result
end

local function NormalizeProfile(profile)
	local base = BuildBuiltinProfile()
	profile = type(profile) == "table" and profile or {}
	profile.version = PROFILE_VERSION
	profile.name = Trim(profile.name)
	if profile.name == "" then
		profile.name = T("Новый шаблон")
	end
	profile.serverKey = Trim(profile.serverKey)
	if profile.serverKey == "" then
		profile.serverKey = base.serverKey
	end
	profile.talentTemplate = Trim(profile.talentTemplate)
	if profile.talentTemplate == "" then
		profile.talentTemplate = base.talentTemplate
	end
	profile.bag = type(profile.bag) == "table" and profile.bag or {}
	profile.bag.itemID = tonumber(profile.bag.itemID) or base.bag.itemID
	profile.bag.count = math.max(1, math.floor(tonumber(profile.bag.count) or base.bag.count or 1))
	profile.mount = type(profile.mount) == "table" and profile.mount or {}
	profile.mount.itemID = tonumber(profile.mount.itemID) or base.mount.itemID
	profile.mount.spellID = tonumber(profile.mount.spellID)
	if not profile.mount.spellID and profile.mount.itemID == base.mount.itemID then
		profile.mount.spellID = base.mount.spellID
	end
	profile.gear = type(profile.gear) == "table" and profile.gear or {}
	for key, gear in pairs(profile.gear) do
		local slot = tonumber(key)
		if not slot or type(gear) ~= "table" then
			profile.gear[key] = nil
		else
			if key ~= slot then
				profile.gear[key] = nil
				profile.gear[slot] = gear
			end
			gear.itemID = tonumber(gear.itemID)
			gear.enchantID = IsEnchantableSlot(slot) and tonumber(gear.enchantID) or nil
			if not gear.enchantID then gear.enchantName = nil end
			gear.gems = type(gear.gems) == "table" and gear.gems or {}
			local normalizedGems = {}
			for i = 1, 3 do
				local gem = gear.gems[i]
				local id = tonumber(type(gem) == "table" and (gem.id or gem[1]) or gem)
				if id and id > 0 then
					if type(gem) ~= "table" then
						gem = { id = id, fallback = #normalizedGems + 1, name = T("гнездо") }
					else
						gem.id = id
						gem.fallback = tonumber(gem.fallback) or (#normalizedGems + 1)
					end
					normalizedGems[#normalizedGems + 1] = gem
				end
			end
			gear.gems = normalizedGems
		end
	end
	local glyphs = {}
	for i = 1, #(type(profile.glyphs) == "table" and profile.glyphs or {}) do
		local id = tonumber(profile.glyphs[i])
		if id and id > 0 and #glyphs < 6 then
			glyphs[#glyphs + 1] = math.floor(id)
		end
	end
	profile.glyphs = glyphs
	profile.professions = type(profile.professions) == "table" and profile.professions or {}
	-- Built-in and imported profiles may contain a full character consumables
	-- loadout. The editor shows the first 12 rows, but must not silently discard
	-- the remaining purchases when the profile is normalized and activated.
	profile.extraItems = NormalizeItemRows(profile.extraItems, 32)
	profile.vendorItems = NormalizeItemRows(profile.vendorItems, 8)
	profile.sellItems = type(profile.sellItems) == "table" and profile.sellItems or {}
	profile.professionSockets = type(profile.professionSockets) == "table" and profile.professionSockets or DeepCopy(base.professionSockets)
	return profile
end

local function UniqueProfileName(wanted)
	wanted = Trim(wanted)
	if wanted == "" then
		wanted = T("Новый шаблон")
	end
	local used = { [BuildBuiltinProfile().name] = true }
	local store = AccountStore()
	for _, profile in pairs(store.entries) do
		if type(profile) == "table" and profile.name then
			used[profile.name] = true
		end
	end
	if not used[wanted] then
		return wanted
	end
	local n = 2
	while used[wanted .. " " .. n] do
		n = n + 1
	end
	return wanted .. " " .. n
end

local function NewProfileKey()
	local store = AccountStore()
	local key
	repeat
		key = "profile_" .. tostring(store.nextID)
		store.nextID = store.nextID + 1
	until not store.entries[key]
	return key
end

function SUI:GetQuickStartProfile(profileKey, mutable)
	if not profileKey or profileKey == BUILTIN_KEY then
		return mutable and DeepCopy(BuildBuiltinProfile()) or BuildBuiltinProfile(), BUILTIN_KEY
	end
	local store = AccountStore()
	local profile = store.entries[profileKey]
	if type(profile) ~= "table" then
		return mutable and DeepCopy(BuildBuiltinProfile()) or BuildBuiltinProfile(), BUILTIN_KEY
	end
	NormalizeProfile(profile)
	return mutable and DeepCopy(profile) or profile, profileKey
end

local function BuildProfessionSteps(profile)
	local primary, secondary = {}, {}
	for i = 1, #PROFESSION_DEFS do
		local def = PROFESSION_DEFS[i]
		if profile.professions[def.key] then
			local step = { needles = DeepCopy(def.needles), wait = "trainer" }
			if def.secondary then
				secondary[#secondary + 1] = step
			else
				primary[#primary + 1] = step
			end
		end
	end
	if #secondary > 0 then
		primary[#primary + 1] = { needles = { "вторичн", "secondary" }, wait = "gossip" }
		for i = 1, #secondary do
			primary[#primary + 1] = secondary[i]
		end
	end
	return primary
end

local function BuildSetupNPCs(profile)
	local base = SUI:GetQuickStartBuiltinRuntime()
	local result = {}
	local professionSteps = BuildProfessionSteps(profile)
	for i = 1, #(base.setupNPCs or {}) do
		local npc = DeepCopy(base.setupNPCs[i])
		if npc and npc.id == 99204 then
			if #professionSteps > 0 then
				npc.steps = professionSteps
				result[#result + 1] = npc
			end
		elseif npc and npc.kind == "vendor" then
			npc.items = {}
			for j = 1, #profile.vendorItems do
				local row = profile.vendorItems[j]
				npc.items[#npc.items + 1] = { row.id, row.count }
			end
			npc.sellItems = DeepCopy(profile.sellItems)
			if #npc.items > 0 or #npc.sellItems > 0 then
				result[#result + 1] = npc
			end
		else
			result[#result + 1] = npc
		end
	end
	return result
end

local function BuildRuntime(profile)
	profile = NormalizeProfile(DeepCopy(profile))
	local base = SUI:GetQuickStartBuiltinRuntime()
	local wearItems, enchants, sockets = {}, {}, {}
	local vendorIDs = {}
	for i = 1, #profile.vendorItems do
		vendorIDs[profile.vendorItems[i].id] = true
	end
	for i = 1, #SLOT_DEFS do
		local slot = SLOT_DEFS[i].id
		local gear = profile.gear[slot]
		if gear and gear.itemID then
			wearItems[#wearItems + 1] = { gear.itemID, slot }
		end
		if gear and gear.itemID and gear.enchantID and IsEnchantableSlot(slot) then
			enchants[#enchants + 1] = {
				id = gear.enchantID,
				slot = slot,
				name = gear.enchantName or (SLOT_BY_ID[slot] and SLOT_BY_ID[slot].name) or tostring(slot),
			}
		end
		if gear and gear.itemID and #gear.gems > 0 then
			sockets[#sockets + 1] = {
				slot = slot,
				name = gear.socketName or (SLOT_BY_ID[slot] and SLOT_BY_ID[slot].name) or tostring(slot),
				gems = DeepCopy(gear.gems),
			}
		end
	end

	local counts, order = {}, {}
	AddCount(counts, order, profile.bag.itemID, profile.bag.count)
	for i = 1, #wearItems do
		local id = wearItems[i][1]
		if not vendorIDs[id] then
			AddCount(counts, order, id, 1)
		end
	end
	for i = 1, #enchants do
		AddCount(counts, order, enchants[i].id, 1)
	end
	for i = 1, #sockets do
		for j = 1, #sockets[i].gems do
			AddCount(counts, order, sockets[i].gems[j].id, 1)
		end
	end
	local professionSockets = profile.professions.blacksmithing and DeepCopy(profile.professionSockets) or {}
	for i = 1, #professionSockets do
		for j = 1, #(professionSockets[i].reagents or {}) do
			local reagent = professionSockets[i].reagents[j]
			AddCount(counts, order, reagent.id or reagent[1], reagent.count or reagent[2])
		end
	end
	for i = 1, #profile.glyphs do
		AddCount(counts, order, profile.glyphs[i], 1)
	end
	AddCount(counts, order, profile.mount.itemID, 1)
	for i = 1, #profile.extraItems do
		AddCount(counts, order, profile.extraItems[i].id, profile.extraItems[i].count)
	end
	local quickBuyItems = {}
	for i = 1, #order do
		quickBuyItems[#quickBuyItems + 1] = { order[i], counts[order[i]] }
	end

	return {
		name = profile.name,
		talentTemplate = profile.talentTemplate,
		setupNPCs = BuildSetupNPCs(profile),
		quickBuyItemID = profile.bag.itemID,
		quickBuyCount = profile.bag.count,
		quickBuyFallbackPath = DeepCopy(base.quickBuyFallbackPath),
		quickBuyItems = quickBuyItems,
		wearItems = wearItems,
		mountItemID = profile.mount.itemID,
		mountSpellID = profile.mount.spellID,
		glyphItems = DeepCopy(profile.glyphs),
		itemEnchants = enchants,
		professionSockets = professionSockets,
		itemSockets = sockets,
	}
end

function SUI:ActivateQuickStartProfile(profileKey)
	local store, root = AccountStore()
	profileKey = profileKey or root.quickStartSelectedProfile or BUILTIN_KEY
	local profile, resolvedKey = self:GetQuickStartProfile(profileKey)
	root.quickStartSelectedProfile = resolvedKey
	self._activeQuickStartProfileKey = resolvedKey
	self:ApplyQuickStartRuntimeProfile(BuildRuntime(profile))
	return profile, resolvedKey
end

local function SaveProfile(profile, profileKey)
	local store, root = AccountStore()
	profile = NormalizeProfile(DeepCopy(profile))
	if not profileKey or profileKey == BUILTIN_KEY or not store.entries[profileKey] then
		profileKey = NewProfileKey()
		store.order[#store.order + 1] = profileKey
	end
	store.entries[profileKey] = profile
	root.quickStartSelectedProfile = profileKey
	return profileKey
end

function SUI:CloneQuickStartProfile(profileKey, openEditor)
	local source = self:GetQuickStartProfile(profileKey, true)
	source.name = UniqueProfileName((source.name or T("Шаблон")) .. " - " .. T("копия"))
	local newKey = SaveProfile(source)
	self:RefreshQuickStartProfileOptions()
	if openEditor then
		self:ShowQuickStartProfileEditor(newKey)
	end
	return newKey
end

function SUI:DeleteQuickStartProfile(profileKey)
	if not profileKey or profileKey == BUILTIN_KEY then
		return false
	end
	local store, root = AccountStore()
	if type(store.entries[profileKey]) ~= "table" then
		return false
	end
	store.entries[profileKey] = nil
	for i = #store.order, 1, -1 do
		if store.order[i] == profileKey then
			table.remove(store.order, i)
		end
	end
	if root.quickStartSelectedProfile == profileKey then
		root.quickStartSelectedProfile = BUILTIN_KEY
		self:ActivateQuickStartProfile(BUILTIN_KEY)
	end
	self:RefreshQuickStartProfileOptions()
	return true
end

local TALENT_TREE_ICONS = {
	WarriorArms = "Interface\\Icons\\Ability_Rogue_Ambush",
	WarriorFury = "Interface\\Icons\\Ability_Warrior_InnerRage",
	WarriorProtection = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
	PaladinHoly = "Interface\\Icons\\Spell_Holy_HolyBolt",
	PaladinProtection = "Interface\\Icons\\Spell_Holy_DevotionAura",
	PaladinCombat = "Interface\\Icons\\Spell_Holy_AuraOfLight",
	HunterBeastMastery = "Interface\\Icons\\Ability_Hunter_BeastTaming",
	HunterMarksmanship = "Interface\\Icons\\Ability_Marksmanship",
	HunterSurvival = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
	RogueAssassination = "Interface\\Icons\\Ability_Rogue_Eviscerate",
	RogueCombat = "Interface\\Icons\\Ability_BackStab",
	RogueSubtlety = "Interface\\Icons\\Ability_Stealth",
	PriestDiscipline = "Interface\\Icons\\Spell_Holy_WordFortitude",
	PriestHoly = "Interface\\Icons\\Spell_Holy_HolyBolt",
	PriestShadow = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
	DeathKnightBlood = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
	DeathKnightFrost = "Interface\\Icons\\Spell_Deathknight_FrostPresence",
	DeathKnightUnholy = "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
	ShamanElementalCombat = "Interface\\Icons\\Spell_Nature_Lightning",
	ShamanEnhancement = "Interface\\Icons\\Spell_Nature_LightningShield",
	ShamanRestoration = "Interface\\Icons\\Spell_Nature_MagicImmunity",
	MageArcane = "Interface\\Icons\\Spell_Holy_MagicalSentry",
	MageFire = "Interface\\Icons\\Spell_Fire_FireBolt02",
	MageFrost = "Interface\\Icons\\Spell_Frost_FrostBolt02",
	WarlockCurses = "Interface\\Icons\\Spell_Shadow_DeathCoil",
	WarlockSummoning = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
	WarlockDestruction = "Interface\\Icons\\Spell_Shadow_RainOfFire",
	DruidBalance = "Interface\\Icons\\Spell_Nature_StarFall",
	DruidFeralCombat = "Interface\\Icons\\Ability_Racial_BearForm",
	DruidRestoration = "Interface\\Icons\\Spell_Nature_HealingTouch",
}

local CLASS_CIRCLES = [[Interface\TargetingFrame\UI-Classes-Circles]]

local function TalentTemplateInfo(templateName)
	local talented = _G.Talented
	if not talented or not templateName then return nil, nil, nil end
	if talented.EnsureBuiltinTemplates then
		pcall(talented.EnsureBuiltinTemplates, talented)
	end
	local templates = talented.db and talented.db.global and talented.db.global.templates
	local template = type(templates) == "table" and templates[templateName]
	if not template and talented.BUILTIN_TEMPLATES and talented.BUILTIN_TEMPLATES[templateName] then
		local code = talented.BUILTIN_TEMPLATES[templateName]
		local class = talented.GetTemplateStringClass and talented:GetTemplateStringClass(code)
		template = { name = templateName, code = code, class = class }
	end
	if type(template) ~= "table" or type(talented.GetTemplateInfo) ~= "function" then return nil, nil, nil end

	local ok, detail = pcall(talented.GetTemplateInfo, talented, template)
	if not ok or type(detail) ~= "string" then return nil, nil, template.class end
	local plain = detail:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	local a, b, c = plain:match("(%d+)%s*/%s*(%d+)%s*/%s*(%d+)")
	if not a then return nil, nil, template.class end
	local points = { tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0 }
	local primary = 1
	for i = 2, 3 do
		if points[i] > points[primary] then primary = i end
	end

	local class = template.class
	if not class and template.code and talented.GetTemplateStringClass then
		class = talented:GetTemplateStringClass(template.code)
	end
	if class and talented.UncompressSpellData then
		pcall(talented.UncompressSpellData, talented, class)
	end
	local tab = class and talented.tabdata and talented.tabdata[class] and talented.tabdata[class][primary]
	local icon = tab and (tab.icon or TALENT_TREE_ICONS[tab.background])
	local distribution = table.concat(points, " / ")
	return icon, distribution, class
end

local function ProfileCardTitle(profile)
	local name = "|cffffffff" .. tostring(profile and profile.name or "") .. "|r"
	return name .. "  |cff9a9aa2" .. T("Human Alliance") .. "|r"
end

local function ProfileCardTalentText(profile)
	local _, distribution = TalentTemplateInfo(profile and profile.talentTemplate)
	return distribution and ("|cffffd24a" .. distribution .. "|r") or ""
end

local function ProfileCardIcon(profile)
	local icon = TalentTemplateInfo(profile and profile.talentTemplate)
	return icon
end

local function ProfileCardClassIcon(profile)
	local _, _, class = TalentTemplateInfo(profile and profile.talentTemplate)
	local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if not coords then
		return nil
	end
	return { texture = CLASS_CIRCLES, coords = coords }
end

function SUI:BuildQuickStartGeneralArgs()
	local args = {
		serverHeader = {
			type = "header",
			name = T("WoWCircle Fun"),
			order = 1,
		},
	}
	local store = AccountStore()
	local rows = { { key = BUILTIN_KEY, profile = BuildBuiltinProfile(), builtin = true } }
	local seen = {}
	for i = 1, #store.order do
		local key = store.order[i]
		local profile = store.entries[key]
		if type(profile) == "table" and not seen[key] then
			seen[key] = true
			rows[#rows + 1] = { key = key, profile = NormalizeProfile(profile) }
		end
	end
	for key, profile in pairs(store.entries) do
		if type(profile) == "table" and not seen[key] then
			store.order[#store.order + 1] = key
			rows[#rows + 1] = { key = key, profile = NormalizeProfile(profile) }
		end
	end
	for i = 1, #rows do
		local row = rows[i]
		local key = row.key
		local profile = row.profile
		args["profile_" .. i] = {
			type = "group",
			name = "",
			order = 10 + i,
			inline = true,
			suiThreeCol = true,
			args = {
				summary = {
					type = "description",
					name = function() return ProfileCardTitle(profile) end,
					-- Rightmost: talent tree. Left of it: class (same as Transfer presets).
					suiRightIcon = function() return ProfileCardIcon(profile) end,
					suiRightIcon2 = function() return ProfileCardClassIcon(profile) end,
					suiRightIconSize = 24,
					suiRightText = function() return ProfileCardTalentText(profile) end,
					order = 1,
					width = "full",
					suiFullRow = true,
				},
				apply = {
					type = "execute",
					name = T("Применить"),
					desc = T("Открыть маршрут и применить этот шаблон."),
					order = 2,
					suiSkipWritableProfile = true,
					func = function()
						SUI:BeginQuickStartBuy(key)
						SUI:RefreshQuickStartProfileOptions()
					end,
				},
				clone = {
					type = "execute",
					name = T("Клонировать"),
					desc = T("Создать независимую копию, доступную всем персонажам."),
					order = 3,
					suiSkipWritableProfile = true,
					func = function() SUI:CloneQuickStartProfile(key, false) end,
				},
				edit = {
					type = "execute",
					name = T("Редактировать"),
					desc = row.builtin and T("Открыть встроенный шаблон. Сохранение создаст пользовательскую копию.") or T("Открыть отдельное окно редактора."),
					order = 4,
					suiSkipWritableProfile = true,
					func = function() SUI:ShowQuickStartProfileEditor(key) end,
				},
			},
		}
	end
	return args
end

function SUI:RefreshQuickStartProfileOptions()
	local qs = self.GetQuickStartOptionsGroup and self:GetQuickStartOptionsGroup()
	local general = qs and qs.args and qs.args.general
	if general then
		general.args = self:BuildQuickStartGeneralArgs()
	end
	if self.OptionsCore and self.OptionsCore.InvalidateStructure then
		self.OptionsCore:InvalidateStructure()
	end
	if self.NotifySarychUIOptionsChange then
		self:NotifySarychUIOptionsChange()
	end
end

-- --------------------------------------------------------------------------
-- Standalone profile editor
-- --------------------------------------------------------------------------

local EDITOR_W = 780
local EDITOR_H = 540
local EDITOR_HEADER_H = 28
local EDITOR_FOOTER_H = 30
local EDITOR_TAB_W = 144
local EDITOR_TAB_H = 22
local EDITOR_COL = 372
local EDITOR_COL2 = 390
local EDITOR_ROW_H = 40
local EDITOR_ROW_STEP = 42
local EDITOR_ITEM = 34
local EDITOR_MINI = 20
local EDITOR_EDIT_H = 22
local EDITOR_BTN_H = 22
local PROMPT_BG = { 0.34, 0.34, 0.34, 0.94 }
local PROMPT_BORDER = { 0.22, 0.22, 0.22, 1 }

local function ThemeFrame(frame, bg, border)
	local theme = SUI.OptionsTheme
	if theme and theme.ApplyFlat then
		theme:ApplyFlat(frame, bg or theme.colors.panelBg, border or theme.colors.border)
		return
	end
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})
		frame:SetBackdropColor(unpack(bg or { 0.32, 0.32, 0.32, 0.92 }))
		frame:SetBackdropBorderColor(unpack(border or { 0.22, 0.22, 0.22, 1 }))
	end
end

local function ThemeColor(key, fallback)
	local theme = SUI.OptionsTheme
	return theme and theme.colors and theme.colors[key] or fallback
end

local function PromptChrome()
	local bg = ThemeColor("contentBg", PROMPT_BG)
	local border = ThemeColor("border", PROMPT_BORDER)
	return { bg[1], bg[2], bg[3], 0.94 }, border
end

local function ThemeFont(key, fallback)
	local theme = SUI.OptionsTheme
	return theme and theme.fonts and theme.fonts[key] or fallback
end

local function SetTooltip(owner, title, body)
	if not GameTooltip then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if title and title ~= "" then
		GameTooltip:AddLine(title, 1, 0.86, 0.28)
	end
	if body and body ~= "" then
		GameTooltip:AddLine(body, 0.88, 0.88, 0.90, true)
	end
	GameTooltip:Show()
end

local function ItemName(id)
	id = tonumber(id)
	if not id then return T("Не выбрано") end
	if type(GetItemInfo) == "function" then
		local name = GetItemInfo(id)
		if name then return name end
		pcall(GetItemInfo, id)
	end
	return T("Предмет") .. " " .. id
end

local function ItemIcon(id, fallback)
	id = tonumber(id)
	if id and type(GetItemIcon) == "function" then
		local icon = GetItemIcon(id)
		if icon then return icon end
	end
	if id then return fallback or "Interface\\Icons\\INV_Misc_QuestionMark" end
	return fallback
end

local function GlyphSlotLabel(index)
	index = tonumber(index) or 1
	if index <= 3 then
		return T("Малый символ") .. " " .. index
	end
	return T("Большой символ") .. " " .. (index - 3)
end

local function CreateText(parent, font, text, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	fs:SetText(text or "")
	if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
	return fs
end

local function CreateButton(parent, text, width, height, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width or 96, height or EDITOR_BTN_H)
	button:RegisterForClicks("LeftButtonUp")
	ThemeFrame(button, ThemeColor("buttonBg", { 0.17, 0.17, 0.20, 1 }), ThemeColor("borderSoft", { 0.34, 0.34, 0.38, 1 }))
	local label = CreateText(button, ThemeFont("normal", "GameFontHighlightSmall"), text, TEXT)
	label:SetPoint("CENTER")
	button.label = label
	button:SetScript("OnEnter", function(self)
		ThemeFrame(self, ThemeColor("buttonHover", { 0.23, 0.23, 0.27, 1 }), ThemeColor("accent", GOLD))
	end)
	button:SetScript("OnLeave", function(self)
		ThemeFrame(self, ThemeColor("buttonBg", { 0.17, 0.17, 0.20, 1 }), ThemeColor("borderSoft", { 0.34, 0.34, 0.38, 1 }))
		if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end)
	button:SetScript("OnClick", onClick)
	return button
end

local function CreateEdit(parent, width, height, numeric)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(width or 160, height or EDITOR_EDIT_H)
	box:SetAutoFocus(false)
	box:SetFontObject(ThemeFont("small", "GameFontHighlightSmall"))
	box:SetTextInsets(6, 6, 0, 0)
	if numeric and box.SetNumeric then box:SetNumeric(true) end
	ThemeFrame(box, ThemeColor("inputBg", { 0.09, 0.09, 0.11, 1 }), ThemeColor("border", { 0.30, 0.30, 0.34, 1 }))
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEditFocusGained", function(self)
		ThemeFrame(self, ThemeColor("inputBg", { 0.11, 0.11, 0.14, 1 }), ThemeColor("accent", GOLD))
		self:HighlightText()
	end)
	box:SetScript("OnEditFocusLost", function(self)
		ThemeFrame(self, ThemeColor("inputBg", { 0.09, 0.09, 0.11, 1 }), ThemeColor("border", { 0.30, 0.30, 0.34, 1 }))
		self:HighlightText(0, 0)
	end)
	return box
end

local function CreateItemButton(parent, size, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)
	button:RegisterForClicks("LeftButtonUp")
	ThemeFrame(button, ThemeColor("inputBg", { 0.09, 0.09, 0.11, 1 }), ThemeColor("borderSoft", { 0.30, 0.30, 0.34, 1 }))
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", -1, 1)
	icon:SetTexture(nil)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button.icon = icon
	local emptyLabel = CreateText(button, "GameFontNormal", "+", DIM)
	emptyLabel:SetPoint("CENTER", 0, 0)
	button.emptyLabel = emptyLabel
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(self)
		ThemeFrame(self, ThemeColor("inputBg", { 0.09, 0.09, 0.11, 1 }), ThemeColor("accent", GOLD))
		if self.itemID and GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if GameTooltip.SetHyperlink then GameTooltip:SetHyperlink("item:" .. self.itemID) end
			GameTooltip:Show()
		else
			SetTooltip(self, self.tooltipTitle, self.tooltipText)
		end
	end)
	button:SetScript("OnLeave", function(self)
		ThemeFrame(self, ThemeColor("inputBg", { 0.09, 0.09, 0.11, 1 }), ThemeColor("borderSoft", { 0.30, 0.30, 0.34, 1 }))
		if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end)
	return button
end

local function SetItemButton(button, itemID, emptyTexture)
	button.itemID = tonumber(itemID)
	if button.itemID then
		button.icon:SetTexture(ItemIcon(itemID, emptyTexture))
		button.icon:SetVertexColor(1, 1, 1, 1)
		button.icon:SetDesaturated(false)
		button.icon:SetAlpha(1)
		button.emptyLabel:Hide()
	elseif emptyTexture then
		button.icon:SetTexture(emptyTexture)
		button.icon:SetVertexColor(1, 1, 1, 1)
		button.icon:SetDesaturated(false)
		button.icon:SetAlpha(0.72)
		button.emptyLabel:Hide()
	else
		button.icon:SetTexture(nil)
		button.icon:SetVertexColor(1, 1, 1, 1)
		button.icon:SetDesaturated(false)
		button.icon:SetAlpha(0)
		button.emptyLabel:Show()
	end
end

local function GetGear(profile, slot, create)
	local gear = profile and profile.gear and profile.gear[slot]
	if not gear and create and profile then
		profile.gear = profile.gear or {}
		gear = { gems = {} }
		profile.gear[slot] = gear
	end
	if gear then gear.gems = gear.gems or {} end
	return gear
end

local function TalentTemplateNames()
	local result, seen = {}, {}
	local talented = _G.Talented
	if talented and talented.EnsureBuiltinTemplates then
		pcall(talented.EnsureBuiltinTemplates, talented)
	end
	local templates = talented and talented.db and talented.db.global and talented.db.global.templates
	for name in pairs(type(templates) == "table" and templates or {}) do
		if type(name) == "string" and name ~= "" and not seen[name] then
			seen[name] = true
			result[#result + 1] = name
		end
	end
	if #result == 0 then result[1] = BuildBuiltinProfile().talentTemplate end
	table.sort(result)
	return result
end

local function ProbeSocketLayout(itemID)
	itemID = tonumber(itemID)
	if not itemID then return nil end
	local cached = socketLayoutCache[itemID]
	if cached ~= nil then
		return cached or nil
	end
	local layout = SUI.ProbeQuickstartSocketLayout and SUI.ProbeQuickstartSocketLayout(itemID)
	if not layout then return nil end
	socketLayoutCache[itemID] = DeepCopy(layout)
	return socketLayoutCache[itemID]
end

local function EmptySocketTexture(socketType)
	socketType = tostring(socketType or "PRISMATIC"):upper()
	if socketType == "META" then return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta" end
	if socketType == "RED" then return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red" end
	if socketType == "BLUE" then return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue" end
	if socketType == "YELLOW" then return "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow" end
	return "Interface\\AddOns\\SarychUI_WoWCircle\\media\\UI-EmptySocket-Prismatic"
end

local function EditorMessage(text, color)
	if not editor or not editor.message then return end
	editor.message:SetText(text or "")
	color = color or DIM
	editor.message:SetTextColor(color[1], color[2], color[3])
end

local function CloseValuePrompt()
	if editor and editor.valuePrompt then
		editor.valuePrompt:Hide()
		editor.valuePrompt.onSave = nil
	end
end

local function CloseDeletePrompt()
	if editor and editor.deletePrompt then
		editor.deletePrompt:Hide()
	end
end

local function OpenDeletePrompt()
	if not editor or not editor.deletePrompt or editor.sourceKey == BUILTIN_KEY then return end
	local name = editor.draft and editor.draft.name or T("Шаблон")
	editor.deletePrompt.body:SetText(T("Удалить шаблон") .. " «" .. name .. "»?")
	editor.deletePrompt:Show()
	if editor.deletePrompt.Raise then editor.deletePrompt:Raise() end
end

local function OpenValuePrompt(title, value, onSave)
	if not editor then return end
	local prompt = editor.valuePrompt
	prompt.title:SetText(title or T("Введите ID предмета"))
	prompt.edit:SetText(value and tostring(value) or "")
	prompt.onSave = onSave
	prompt:SetFrameStrata("TOOLTIP")
	prompt:SetFrameLevel(900)
	prompt:Show()
	if prompt.Raise then prompt:Raise() end
	prompt.edit:SetFocus()
	prompt.edit:HighlightText()
end

local function RefreshEquipmentPage()
	if not editor or not editor.draft then return end
	for i = 1, #(editor.equipmentRows or {}) do
		local row = editor.equipmentRows[i]
		local gear = GetGear(editor.draft, row.slot)
		local itemID = gear and gear.itemID
		SetItemButton(row.item, itemID)
		row.item.tooltipTitle = row.slotName
		row.item.tooltipText = T("Нажмите, чтобы изменить предмет")
		row.name:SetText(itemID and (ItemName(itemID) .. "\n|cff8f8f98ID " .. itemID .. "|r") or "|cff777780" .. T("Пусто") .. "|r")
		if row.enchant then
			local enchantID = gear and gear.enchantID
			SetItemButton(row.enchant, enchantID, "Interface\\Icons\\INV_Scroll_03")
			row.enchant.tooltipTitle = T("Чары")
			row.enchant.tooltipText = enchantID and (ItemName(enchantID) .. " (" .. enchantID .. ")") or T("Нажмите, чтобы назначить чары")
		end
		local socketLayout = itemID and ProbeSocketLayout(itemID) or nil
		local socketCount = 0
		if itemID and gear then
			-- The item template only knows native sockets. Extra sockets added by
			-- Eternal Belt Buckle or profession effects exist in the saved profile,
			-- so a successful template probe must not hide or delete them.
			local detectedCount = type(socketLayout) == "table" and #socketLayout or 0
			local savedCount = tonumber(gear.socketCount) or 0
			local gemCount = #(gear.gems or {})
			local buckleCount = 0
			if row.slot == 6 and tonumber(gear.enchantID) == 41611 then
				buckleCount = detectedCount + 1
			end
			socketCount = math.min(3, math.max(detectedCount, savedCount, gemCount, buckleCount))
			gear.socketCount = socketCount
		end
		for socketIndex = 1, 3 do
			local socket = row.sockets[socketIndex]
			if socketIndex <= socketCount then
				local gem = gear.gems[socketIndex]
				local gemID = gem and tonumber(gem.id or gem[1] or gem)
				local socketType = socketLayout and socketLayout[socketIndex] and socketLayout[socketIndex].socketType
				SetItemButton(socket, gemID, EmptySocketTexture(socketType))
				socket.tooltipTitle = T("Гнездо") .. " " .. socketIndex
				socket.tooltipText = gemID and (ItemName(gemID) .. " (" .. gemID .. ")") or T("Нажмите, чтобы назначить камень")
				socket:Show()
			else
				socket:Hide()
			end
		end
	end
end

local function RefreshGlyphPage()
	if not editor or not editor.draft then return end
	for i = 1, #(editor.glyphButtons or {}) do
		local card = editor.glyphButtons[i]
		local id = editor.draft.glyphs[i]
		SetItemButton(card.item, id)
		card.item.tooltipTitle = GlyphSlotLabel(i)
		card.item.tooltipText = T("Нажмите, чтобы изменить предмет символа")
		card.name:SetText(id and (ItemName(id) .. "\n|cff8f8f98ID " .. id .. "|r") or "|cff777780" .. T("Свободное место") .. "|r")
	end
end

local function RefreshProfessionPage()
	if not editor or not editor.draft then return end
	for i = 1, #(editor.professionChecks or {}) do
		local row = editor.professionChecks[i]
		row.check:SetChecked(editor.draft.professions[row.key] and true or false)
	end
end

local function RefreshPurchasePage()
	if not editor or not editor.draft then return end
	editor._refreshingPurchases = true
	for _, list in ipairs(editor.purchaseLists or {}) do
		local rows = editor.draft[list.key] or {}
		for i = 1, #list.rows do
			local widget = list.rows[i]
			local row = rows[i]
			widget.id:SetText(row and row.id and tostring(row.id) or "")
			widget.count:SetText(row and row.count and tostring(row.count) or "")
			SetItemButton(widget.icon, row and row.id)
			if row and row.id then widget.remove:Show() else widget.remove:Hide() end
		end
	end
	editor._refreshingPurchases = nil
end

local function RefreshGeneralPage()
	if not editor or not editor.draft then return end
	editor._refreshingGeneral = true
	editor.nameEdit:SetText(editor.draft.name or "")
	editor.talentButton.label:SetText(editor.draft.talentTemplate or T("Выбрать"))
	local mountID = editor.draft.mount and editor.draft.mount.itemID
	SetItemButton(editor.mountItem, mountID)
	editor.mountName:SetText(mountID and (ItemName(mountID) .. "\n|cff8f8f98ID " .. mountID .. "|r") or T("Маунт не выбран"))
	editor.bagIDEdit:SetText(editor.draft.bag and tostring(editor.draft.bag.itemID or "") or "")
	editor.bagCountEdit:SetText(editor.draft.bag and tostring(editor.draft.bag.count or "") or "")
	editor._refreshingGeneral = nil
end

local function RefreshEditor()
	RefreshGeneralPage()
	RefreshEquipmentPage()
	RefreshGlyphPage()
	RefreshProfessionPage()
	RefreshPurchasePage()
end

local function ShowEditorTab(key)
	if not editor then return end
	editor.activeTab = key
	for tabKey, page in pairs(editor.pages) do
		if tabKey == key then page:Show() else page:Hide() end
		local button = editor.tabs[tabKey]
		if tabKey == key then
			ThemeFrame(button, ThemeColor("tabActive", { 0.23, 0.23, 0.27, 1 }), ThemeColor("accent", GOLD))
			button.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		else
			ThemeFrame(button, ThemeColor("tabBg", { 0.14, 0.14, 0.17, 1 }), ThemeColor("borderSoft", { 0.28, 0.28, 0.31, 1 }))
			button.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		end
	end
	if key == "equipment" then RefreshEquipmentPage() end
	if key == "glyphs" then RefreshGlyphPage() end
	if key == "professions" then RefreshProfessionPage() end
	if key == "purchases" then RefreshPurchasePage() end
end

local function CreateValuePrompt(parent)
	-- Keep the prompt independent from editor pages.  On the 3.3.5 client a
	-- high-level child can draw its backdrop above its own controls, resulting
	-- in a featureless black rectangle.
	local frame = CreateFrame("Frame", "SarychUI_QuickStartValuePrompt", UIParent)
	frame:SetSize(300, 108)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 8)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetFrameLevel(900)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	local promptBg, promptBorder = PromptChrome()
	ThemeFrame(frame, promptBg, promptBorder)
	frame:Hide()
	local title = CreateText(frame, "GameFontNormal", "", GOLD)
	title:SetPoint("TOPLEFT", 12, -12)
	title:SetPoint("RIGHT", -12, 0)
	title:SetJustifyH("LEFT")
	frame.title = title
	local edit = CreateEdit(frame, 276, EDITOR_EDIT_H, true)
	edit:SetFrameStrata("TOOLTIP")
	edit:SetFrameLevel(frame:GetFrameLevel() + 2)
	edit:SetPoint("TOPLEFT", 12, -38)
	frame.edit = edit
	local save = CreateButton(frame, T("Сохранить"), 100, EDITOR_BTN_H, function()
		local value = tonumber(frame.edit:GetText())
		local callback = frame.onSave
		CloseValuePrompt()
		if callback then callback(value) end
	end)
	save:SetFrameStrata("TOOLTIP")
	save:SetFrameLevel(frame:GetFrameLevel() + 2)
	save:SetPoint("BOTTOMLEFT", 12, 10)
	local cancel = CreateButton(frame, T("Отмена"), 88, EDITOR_BTN_H, CloseValuePrompt)
	cancel:SetFrameStrata("TOOLTIP")
	cancel:SetFrameLevel(frame:GetFrameLevel() + 2)
	cancel:SetPoint("BOTTOMRIGHT", -12, 10)
	edit:SetScript("OnEnterPressed", function()
		local value = tonumber(edit:GetText())
		local callback = frame.onSave
		CloseValuePrompt()
		if callback then callback(value) end
	end)
	edit:SetScript("OnEscapePressed", CloseValuePrompt)
	return frame
end

local function CreateDeletePrompt(parent)
	local frame = CreateFrame("Frame", "SarychUI_QuickStartDeletePrompt", UIParent)
	frame:SetSize(340, 108)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 8)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetFrameLevel(920)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	local promptBg, promptBorder = PromptChrome()
	ThemeFrame(frame, promptBg, promptBorder)
	frame:Hide()

	local title = CreateText(frame, ThemeFont("title", "GameFontNormal"), T("Удаление шаблона"), RED)
	title:SetPoint("TOPLEFT", 12, -12)
	title:SetPoint("RIGHT", -12, 0)
	title:SetJustifyH("LEFT")

	local body = CreateText(frame, ThemeFont("normal", "GameFontHighlightSmall"), "", TEXT)
	body:SetPoint("TOPLEFT", 12, -36)
	body:SetPoint("RIGHT", -12, 0)
	body:SetJustifyH("LEFT")
	frame.body = body

	local cancel = CreateButton(frame, T("Отмена"), 96, EDITOR_BTN_H, CloseDeletePrompt)
	cancel:SetFrameStrata("TOOLTIP")
	cancel:SetFrameLevel(frame:GetFrameLevel() + 2)
	cancel:SetPoint("BOTTOMRIGHT", -12, 10)

	local confirm = CreateButton(frame, T("Удалить"), 96, EDITOR_BTN_H, function()
		local key = editor and editor.sourceKey
		CloseDeletePrompt()
		if key and key ~= BUILTIN_KEY and SUI:DeleteQuickStartProfile(key) then
			parent:Hide()
		end
	end)
	confirm:SetFrameStrata("TOOLTIP")
	confirm:SetFrameLevel(frame:GetFrameLevel() + 2)
	confirm:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
	confirm.label:SetTextColor(RED[1], RED[2], RED[3])

	return frame
end

local function CreateGeneralPage(page)
	local nameLabel = CreateText(page, "GameFontNormal", T("Название шаблона"), TEXT)
	nameLabel:SetPoint("TOPLEFT", 8, -10)
	local nameEdit = CreateEdit(page, EDITOR_COL, EDITOR_EDIT_H, false)
	nameEdit:SetPoint("TOPLEFT", 8, -28)
	nameEdit:SetScript("OnTextChanged", function(self)
		if editor and editor.draft and not editor._refreshingGeneral then editor.draft.name = self:GetText() end
	end)
	editor.nameEdit = nameEdit

	local talentLabel = CreateText(page, "GameFontNormal", T("Шаблон Talented"), TEXT)
	talentLabel:SetPoint("TOPLEFT", EDITOR_COL2, -10)
	local talentButton = CreateButton(page, T("Выбрать"), EDITOR_COL, EDITOR_EDIT_H, function(self)
		local list = editor.talentList
		if list:IsShown() then list:Hide() return end
		local names = TalentTemplateNames()
		for i = 1, #list.buttons do list.buttons[i]:Hide() end
		local height = 6
		for i = 1, #names do
			local button = list.buttons[i]
			if not button then
				button = CreateButton(list, "", EDITOR_COL - 16, EDITOR_BTN_H, nil)
				button:SetPoint("TOPLEFT", 8, -6 - (i - 1) * (EDITOR_BTN_H + 2))
				button.label:SetJustifyH("LEFT")
				list.buttons[i] = button
			end
			button.label:SetText(names[i])
			button.value = names[i]
			button:SetScript("OnClick", function(choice)
				editor.draft.talentTemplate = choice.value
				editor.talentButton.label:SetText(choice.value)
				list:Hide()
			end)
			button:Show()
			height = height + EDITOR_BTN_H + 2
		end
		list:SetHeight(math.min(260, height + 6))
		list:Show()
	end)
	talentButton:SetPoint("TOPLEFT", EDITOR_COL2, -28)
	talentButton.label:SetJustifyH("LEFT")
	editor.talentButton = talentButton

	local talentList = CreateFrame("Frame", nil, page)
	talentList:SetSize(EDITOR_COL, 80)
	talentList:SetPoint("TOPLEFT", talentButton, "BOTTOMLEFT", 0, -2)
	talentList:SetFrameLevel(page:GetFrameLevel() + 30)
	talentList:EnableMouse(true)
	ThemeFrame(talentList, ThemeColor("navBg", PROMPT_BG), ThemeColor("border", PROMPT_BORDER))
	talentList.buttons = {}
	talentList:Hide()
	editor.talentList = talentList

	local mountBox = CreateFrame("Frame", nil, page)
	mountBox:SetPoint("TOPLEFT", 8, -72)
	mountBox:SetSize(EDITOR_COL, 70)
	ThemeFrame(mountBox, ThemeColor("panelBg", { 0.32, 0.32, 0.32, 0.55 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
	local mountTitle = CreateText(mountBox, "GameFontNormal", T("Маунт"), GOLD)
	mountTitle:SetPoint("TOPLEFT", 10, -8)
	local mountItem = CreateItemButton(mountBox, EDITOR_ITEM, function()
		OpenValuePrompt(T("Item ID маунта"), editor.draft.mount.itemID, function(value)
			editor.draft.mount.itemID = value
			RefreshGeneralPage()
		end)
	end)
	mountItem:SetPoint("BOTTOMLEFT", 10, 8)
	mountItem.tooltipText = T("Нажмите, чтобы изменить маунта")
	editor.mountItem = mountItem
	local mountName = CreateText(mountBox, "GameFontHighlightSmall", "", TEXT)
	mountName:SetPoint("LEFT", mountItem, "RIGHT", 8, 0)
	mountName:SetPoint("RIGHT", -10, 0)
	mountName:SetJustifyH("LEFT")
	editor.mountName = mountName

	local bagBox = CreateFrame("Frame", nil, page)
	bagBox:SetPoint("TOPLEFT", EDITOR_COL2, -72)
	bagBox:SetSize(EDITOR_COL, 70)
	ThemeFrame(bagBox, ThemeColor("panelBg", { 0.32, 0.32, 0.32, 0.55 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
	local bagTitle = CreateText(bagBox, "GameFontNormal", T("Сумки экипировки"), GOLD)
	bagTitle:SetPoint("TOPLEFT", 10, -8)
	local bagIDLabel = CreateText(bagBox, "GameFontHighlightSmall", "Item ID", DIM)
	bagIDLabel:SetPoint("TOPLEFT", 10, -28)
	local bagID = CreateEdit(bagBox, 168, EDITOR_EDIT_H, true)
	bagID:SetPoint("TOPLEFT", 10, -42)
	bagID:SetScript("OnTextChanged", function(self)
		if editor and editor.draft and not editor._refreshingGeneral then editor.draft.bag.itemID = tonumber(self:GetText()) end
	end)
	editor.bagIDEdit = bagID
	local bagCountLabel = CreateText(bagBox, "GameFontHighlightSmall", T("Количество"), DIM)
	bagCountLabel:SetPoint("TOPLEFT", 190, -28)
	local bagCount = CreateEdit(bagBox, 168, EDITOR_EDIT_H, true)
	bagCount:SetPoint("TOPLEFT", 190, -42)
	bagCount:SetScript("OnTextChanged", function(self)
		if editor and editor.draft and not editor._refreshingGeneral then editor.draft.bag.count = tonumber(self:GetText()) end
	end)
	editor.bagCountEdit = bagCount

end

local function CreateEquipmentRow(page, slotDef, x, y, width)
	local row = CreateFrame("Frame", nil, page)
	row:SetSize(width, EDITOR_ROW_H)
	row:SetPoint("TOPLEFT", x, y)
	ThemeFrame(row, ThemeColor("panelBg", { 0.32, 0.32, 0.32, 0.55 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
	row.slot = slotDef.id
	row.slotName = slotDef.name
	local item = CreateItemButton(row, EDITOR_ITEM, function()
		local gear = GetGear(editor.draft, slotDef.id, true)
		OpenValuePrompt(slotDef.name .. ": Item ID", gear.itemID, function(value)
			if gear.itemID ~= value then
				gear.gems = {}
				gear.socketCount = nil
				gear.enchantID = nil
				gear.enchantName = nil
			end
			gear.itemID = value
			RefreshEquipmentPage()
		end)
	end)
	item:SetPoint("LEFT", 3, 0)
	row.item = item
	local slotName = CreateText(row, "GameFontHighlightSmall", slotDef.name, GOLD)
	slotName:SetPoint("TOPLEFT", item, "TOPRIGHT", 6, -2)
	local name = CreateText(row, "GameFontHighlightSmall", "", TEXT)
	name:SetPoint("TOPLEFT", item, "TOPRIGHT", 6, -16)
	name:SetPoint("RIGHT", -102, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	row.name = name
	if slotDef.enchantable ~= false then
		local enchant = CreateItemButton(row, EDITOR_MINI, function()
			local gear = GetGear(editor.draft, slotDef.id, true)
			OpenValuePrompt(slotDef.name .. ": " .. T("чары"), gear.enchantID, function(value)
				gear.enchantID = value
				RefreshEquipmentPage()
			end)
		end)
		enchant:SetPoint("RIGHT", -72, 0)
		row.enchant = enchant
		local eMark = CreateText(enchant, "GameFontHighlightSmall", "E", GOLD)
		eMark:SetPoint("BOTTOMRIGHT", -1, 1)
	end
	row.sockets = {}
	for socketIndex = 1, 3 do
		local index = socketIndex
		local socket = CreateItemButton(row, EDITOR_MINI, function()
			local gear = GetGear(editor.draft, slotDef.id, true)
			local targetIndex = math.min(index, #gear.gems + 1)
			local gem = gear.gems[targetIndex]
			local current = gem and tonumber(gem.id or gem[1] or gem)
			OpenValuePrompt(slotDef.name .. ": " .. T("камень") .. " " .. targetIndex, current, function(value)
				if value then
					gear.gems[targetIndex] = type(gem) == "table" and gem or { fallback = targetIndex, name = T("гнездо") }
					gear.gems[targetIndex].id = value
				else
					table.remove(gear.gems, targetIndex)
				end
				RefreshEquipmentPage()
			end)
		end)
		socket:SetPoint("RIGHT", -3 - (3 - index) * 22, 0)
		row.sockets[index] = socket
	end
	editor.equipmentRows[#editor.equipmentRows + 1] = row
	return row
end

local function CreateEquipmentPage(page)
	local heading = CreateText(page, ThemeFont("title", "GameFontNormal"), T("Экипировка и сокеты"), GOLD)
	heading:SetPoint("TOPLEFT", 8, -4)
	local hint = CreateText(page, "GameFontHighlightSmall", T("Нажмите предмет, чару или гнездо, чтобы изменить его Item ID."), DIM)
	hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -2)
	editor.equipmentRows = {}
	local leftIndex, rightIndex = 0, 0
	for i = 1, #SLOT_DEFS do
		local def = SLOT_DEFS[i]
		if def.side == "left" then
			CreateEquipmentRow(page, def, 8, -36 - leftIndex * EDITOR_ROW_STEP, EDITOR_COL)
			leftIndex = leftIndex + 1
		elseif def.side == "right" then
			CreateEquipmentRow(page, def, EDITOR_COL2, -36 - rightIndex * EDITOR_ROW_STEP, EDITOR_COL)
			rightIndex = rightIndex + 1
		end
	end
	for i = 1, #SLOT_DEFS do
		local def = SLOT_DEFS[i]
		if def.side == "bottom" then
			local index = def.id - 16
			CreateEquipmentRow(page, def, 8 + index * 250, -378, 244)
		end
	end
	local legend = CreateText(page, "GameFontHighlightSmall", T("E - чары; справа показаны только реальные сокеты предмета. Пустой сокет можно нажать и назначить камень."), DIM)
	legend:SetPoint("BOTTOMLEFT", 8, 2)
end

local function CreateGlyphPage(page)
	local heading = CreateText(page, ThemeFont("title", "GameFontNormal"), T("Символы"), GOLD)
	heading:SetPoint("TOPLEFT", 8, -6)
	local hint = CreateText(page, "GameFontHighlightSmall", T("Доступно 3 малых и 3 больших символа."), DIM)
	hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
	editor.glyphButtons = {}
	for i = 1, 6 do
		local index = i
		local col = (index - 1) % 3
		local rowIndex = math.floor((index - 1) / 3)
		local card = CreateFrame("Frame", nil, page)
		card:SetSize(244, 56)
		card:SetPoint("TOPLEFT", 8 + col * 252, -46 - rowIndex * 64)
		ThemeFrame(card, ThemeColor("panelBg", { 0.32, 0.32, 0.32, 0.55 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
		local number = CreateText(card, "GameFontHighlightSmall", GlyphSlotLabel(index), GOLD)
		number:SetPoint("TOPLEFT", 8, -6)
		local item = CreateItemButton(card, EDITOR_ITEM, function()
			local targetIndex = math.min(index, #editor.draft.glyphs + 1)
			local current = editor.draft.glyphs[targetIndex]
			OpenValuePrompt(GlyphSlotLabel(targetIndex) .. ": Item ID", current, function(value)
				if value then
					editor.draft.glyphs[targetIndex] = value
				elseif editor.draft.glyphs[targetIndex] then
					table.remove(editor.draft.glyphs, targetIndex)
				end
				RefreshGlyphPage()
			end)
		end)
		item:SetPoint("BOTTOMLEFT", 8, 6)
		local name = CreateText(card, "GameFontHighlightSmall", "", TEXT)
		name:SetPoint("LEFT", item, "RIGHT", 8, 0)
		name:SetPoint("RIGHT", -8, 0)
		name:SetJustifyH("LEFT")
		name:SetWordWrap(true)
		editor.glyphButtons[index] = { item = item, name = name }
	end
end

local function CreateProfessionPage(page)
	local heading = CreateText(page, ThemeFont("title", "GameFontNormal"), T("Профессии"), GOLD)
	heading:SetPoint("TOPLEFT", 8, -6)
	local hint = CreateText(page, "GameFontHighlightSmall", T("Отмеченные профессии будут открыты у тренера и полностью изучены."), DIM)
	hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
	editor.professionChecks = {}
	for i = 1, #PROFESSION_DEFS do
		local def = PROFESSION_DEFS[i]
		local professionKey = def.key
		local col = (i - 1) % 2
		local rowIndex = math.floor((i - 1) / 2)
		local holder = CreateFrame("Frame", nil, page)
		holder:SetSize(EDITOR_COL, 34)
		holder:SetPoint("TOPLEFT", 8 + col * EDITOR_COL2, -46 - rowIndex * 38)
		ThemeFrame(holder, ThemeColor("panelBg", { 0.32, 0.32, 0.32, 0.55 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
		local check = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
		check:SetSize(24, 24)
		check:SetPoint("LEFT", 6, 0)
		check:SetScript("OnClick", function(self)
			editor.draft.professions[professionKey] = self:GetChecked() and true or nil
		end)
		local label = CreateText(holder, "GameFontHighlight", def.label, TEXT)
		label:SetPoint("LEFT", check, "RIGHT", 5, 0)
		if def.secondary then
			local badge = CreateText(holder, "GameFontHighlightSmall", T("вторичная"), DIM)
			badge:SetPoint("RIGHT", -10, 0)
		end
		editor.professionChecks[#editor.professionChecks + 1] = { key = professionKey, check = check }
	end
	local note = CreateText(page, "GameFontHighlightSmall", T("Профессиональные гнёзда наручей и перчаток выполняются только если выбрано кузнечное дело."), DIM)
	note:SetPoint("BOTTOMLEFT", 8, 12)
	note:SetPoint("RIGHT", -8, 0)
	note:SetJustifyH("LEFT")
end

local function CreatePurchaseList(page, title, key, x, maxRows)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetPoint("TOPLEFT", x, -42)
	holder:SetSize(EDITOR_COL, 392)
	ThemeFrame(holder, ThemeColor("navBg", { 0.30, 0.30, 0.30, 0.65 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
	local heading = CreateText(holder, "GameFontNormal", title, GOLD)
	heading:SetPoint("TOPLEFT", 8, -8)
	local idHead = CreateText(holder, "GameFontHighlightSmall", "Item ID", DIM)
	idHead:SetPoint("TOPLEFT", 42, -26)
	local countHead = CreateText(holder, "GameFontHighlightSmall", T("Кол-во"), DIM)
	countHead:SetPoint("TOPLEFT", 236, -26)
	local list = { key = key, rows = {} }
	for i = 1, maxRows do
		local index = i
		local y = -42 - (index - 1) * 28
		local icon = CreateItemButton(holder, 24, function()
			local targetIndex = math.min(index, #editor.draft[key] + 1)
			local row = editor.draft[key][targetIndex]
			OpenValuePrompt(title .. ": Item ID", row and row.id, function(value)
				editor.draft[key][targetIndex] = editor.draft[key][targetIndex] or { count = 1 }
				editor.draft[key][targetIndex].id = value
				RefreshPurchasePage()
			end)
		end)
		icon:SetPoint("TOPLEFT", 8, y)
		local idEdit = CreateEdit(holder, 186, EDITOR_EDIT_H, true)
		idEdit:SetPoint("TOPLEFT", 38, y)
		local countEdit = CreateEdit(holder, 64, EDITOR_EDIT_H, true)
		countEdit:SetPoint("TOPLEFT", 230, y)
		local remove = CreateButton(holder, "X", 24, EDITOR_EDIT_H, function()
			table.remove(editor.draft[key], index)
			RefreshPurchasePage()
		end)
		remove:SetPoint("TOPRIGHT", -8, y)
		idEdit:SetScript("OnTextChanged", function(self)
			if not editor or editor._refreshingPurchases then return end
			local value = tonumber(self:GetText())
			local targetIndex = math.min(index, #editor.draft[key] + 1)
			if value or editor.draft[key][targetIndex] then
				editor.draft[key][targetIndex] = editor.draft[key][targetIndex] or { count = 1 }
				editor.draft[key][targetIndex].id = value
				SetItemButton(icon, value)
				if targetIndex ~= index then RefreshPurchasePage() end
			end
		end)
		countEdit:SetScript("OnTextChanged", function(self)
			if not editor or editor._refreshingPurchases then return end
			local value = tonumber(self:GetText())
			if editor.draft[key][index] then
				editor.draft[key][index].count = value
			end
		end)
		list.rows[index] = { icon = icon, id = idEdit, count = countEdit, remove = remove }
	end
	editor.purchaseLists[#editor.purchaseLists + 1] = list
end

local function CreatePurchasesPage(page)
	local heading = CreateText(page, ThemeFont("title", "GameFontNormal"), T("Покупки"), GOLD)
	heading:SetPoint("TOPLEFT", 8, -6)
	local hint = CreateText(page, "GameFontHighlightSmall", T("Дополнительные предметы идут в сумки; справа - отдельные покупки у чемпиона Рос'слая."), DIM)
	hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
	editor.purchaseLists = {}
	CreatePurchaseList(page, T("Оставить в сумках"), "extraItems", 8, 12)
	CreatePurchaseList(page, T("Купить у Рос'слая"), "vendorItems", EDITOR_COL2, 8)
	local note = CreateText(page, "GameFontHighlightSmall", T("Пустые строки не сохраняются. Экипировка и расходники из других вкладок добавляются автоматически."), DIM)
	note:SetPoint("BOTTOMLEFT", 8, 0)
	note:SetPoint("RIGHT", -8, 0)
end

local function EnsureEditor()
	if editor then return editor end
	local frame = CreateFrame("Frame", "SarychUI_QuickStartProfileEditor", UIParent)
	frame:SetSize(EDITOR_W, EDITOR_H)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame.baseWidth = EDITOR_W
	frame.baseHeight = EDITOR_H
	-- Keep the editor above the still-open /sui window.  On the 3.3.5 client
	-- frame levels do not reliably win against another toplevel DIALOG frame.
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(100)
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	if frame.SetClampRectInsets then frame:SetClampRectInsets(0, 0, 0, 0) end
	ThemeFrame(frame, ThemeColor("rootBg", { 0.37, 0.37, 0.37, 0.68 }), ThemeColor("border", { 0.20, 0.20, 0.20, 1 }))
	frame:Hide()
	editor = frame
	if UISpecialFrames then table.insert(UISpecialFrames, "SarychUI_QuickStartProfileEditor") end

	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(EDITOR_HEADER_H)
	ThemeFrame(header, ThemeColor("headerBg", { 0.28, 0.28, 0.28, 1 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() frame:StartMoving() end)
	header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
	local title = CreateText(header, ThemeFont("title", "GameFontNormal"), T("Редактор быстрого старта"), GOLD)
	title:SetPoint("LEFT", 14, 0)
	title:SetPoint("RIGHT", -52, 0)
	title:SetJustifyH("LEFT")
	frame.title = title
	local close = CreateButton(header, "X", 22, 22, function() frame:Hide() end)
	close:SetPoint("RIGHT", -10, 0)

	frame.tabs = {}
	frame.pages = {}
	local tabDefs = {
		{ "general", T("Основное") },
		{ "equipment", T("Экипировка") },
		{ "glyphs", T("Символы") },
		{ "professions", T("Профессии") },
		{ "purchases", T("Покупки") },
	}
	for i = 1, #tabDefs do
		local key, label = tabDefs[i][1], tabDefs[i][2]
		local tabKey = key
		local tab = CreateButton(frame, label, EDITOR_TAB_W, EDITOR_TAB_H, function() ShowEditorTab(tabKey) end)
		tab:SetPoint("TOPLEFT", 10 + (i - 1) * (EDITOR_TAB_W + 6), -32)
		frame.tabs[key] = tab
		local page = CreateFrame("Frame", nil, frame)
		page:SetPoint("TOPLEFT", 10, -58)
		page:SetPoint("BOTTOMRIGHT", -10, 34)
		ThemeFrame(page, ThemeColor("contentBg", { 0.34, 0.34, 0.34, 0.60 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
		page:Hide()
		frame.pages[key] = page
	end

	CreateGeneralPage(frame.pages.general)
	CreateEquipmentPage(frame.pages.equipment)
	CreateGlyphPage(frame.pages.glyphs)
	CreateProfessionPage(frame.pages.professions)
	CreatePurchasesPage(frame.pages.purchases)

	local footer = CreateFrame("Frame", nil, frame)
	footer:SetPoint("BOTTOMLEFT", 1, 1)
	footer:SetPoint("BOTTOMRIGHT", -1, 1)
	footer:SetHeight(EDITOR_FOOTER_H)
	ThemeFrame(footer, ThemeColor("footerBg", { 0.28, 0.28, 0.28, 0.55 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
	frame.footer = footer

	local message = CreateText(footer, ThemeFont("small", "GameFontHighlightSmall"), "", DIM)
	message:SetPoint("LEFT", 12, 0)
	message:SetPoint("RIGHT", -320, 0)
	message:SetJustifyH("LEFT")
	frame.message = message
	local cancel = CreateButton(footer, T("Закрыть"), 88, EDITOR_BTN_H, function() frame:Hide() end)
	cancel:SetPoint("RIGHT", -8, 0)
	local save = CreateButton(footer, T("Сохранить"), 128, EDITOR_BTN_H, function()
		if not frame.draft then return end
		frame.draft.name = Trim(frame.nameEdit:GetText())
		if frame.draft.name == "" then
			EditorMessage(T("Введите название шаблона."), RED)
			ShowEditorTab("general")
			frame.nameEdit:SetFocus()
			return
		end
		if frame.sourceKey == BUILTIN_KEY then
			frame.draft.name = UniqueProfileName(frame.draft.name)
		end
		local savedKey = SaveProfile(frame.draft, frame.sourceKey == BUILTIN_KEY and nil or frame.sourceKey)
		SUI:ActivateQuickStartProfile(savedKey)
		frame:Hide()
		SUI:RefreshQuickStartProfileOptions()
	end)
	save:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
	frame.saveButton = save
	local deleteButton = CreateButton(footer, T("Удалить"), 88, EDITOR_BTN_H, OpenDeletePrompt)
	deleteButton:SetPoint("RIGHT", save, "LEFT", -8, 0)
	deleteButton.label:SetTextColor(RED[1], RED[2], RED[3])
	frame.deleteButton = deleteButton
	frame.valuePrompt = CreateValuePrompt(frame)
	frame.deletePrompt = CreateDeletePrompt(frame)
	frame:SetScript("OnHide", function()
		CloseValuePrompt()
		CloseDeletePrompt()
		if frame.talentList then frame.talentList:Hide() end
	end)
	frame:SetScript("OnUpdate", function(self, elapsed)
		self.itemRefreshElapsed = (self.itemRefreshElapsed or 0) + elapsed
		if self.itemRefreshElapsed < 0.75 then return end
		self.itemRefreshElapsed = 0
		if self.activeTab == "equipment" then RefreshEquipmentPage()
		elseif self.activeTab == "glyphs" then RefreshGlyphPage()
		elseif self.activeTab == "general" then
			local id = self.draft and self.draft.mount and self.draft.mount.itemID
			if id then
				SetItemButton(self.mountItem, id)
				self.mountName:SetText(ItemName(id) .. "\n|cff8f8f98ID " .. id .. "|r")
			end
		end
	end)
	return frame
end

function SUI:ShowQuickStartProfileEditor(profileKey)
	local ok, result = pcall(function()
		local frame = EnsureEditor()
		local profile, resolvedKey = self:GetQuickStartProfile(profileKey, true)
		frame.sourceKey = resolvedKey
		frame.draft = NormalizeProfile(profile)
		if resolvedKey == BUILTIN_KEY then
			frame.title:SetText(T("Редактор быстрого старта") .. " - " .. (frame.draft.name or "Bonjourepta"))
			frame.saveButton.label:SetText(T("Сохранить как новый"))
			frame.deleteButton:Hide()
			EditorMessage("")
		else
			frame.title:SetText(T("Редактор быстрого старта") .. " - " .. (frame.draft.name or ""))
			frame.saveButton.label:SetText(T("Сохранить"))
			frame.deleteButton:Show()
			EditorMessage(T("Изменения сохраняются для всех персонажей."), GREEN)
		end
		local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or frame.baseWidth
		local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or frame.baseHeight
		local fitScale = math.max(0.10, math.min(
			1.00,
			(parentWidth - 24) / frame.baseWidth,
			(parentHeight - 24) / frame.baseHeight
		))
		frame:SetScale(fitScale)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		RefreshEditor()
		ShowEditorTab("general")
		frame:Show()
		if frame.Raise then frame:Raise() end
		return frame
	end)
	if ok then
		return result
	end
	if editor and editor.Hide then editor:Hide() end
	local message = "|cffff5555SarychUI:|r " .. T("Не удалось открыть редактор быстрого старта") .. ": " .. tostring(result)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(message)
	end
	return nil
end

SUI.QuickStartProfileEditor = {
	BUILTIN_KEY = BUILTIN_KEY,
	Slots = SLOT_DEFS,
	Professions = PROFESSION_DEFS,
	BuildRuntime = BuildRuntime,
}
