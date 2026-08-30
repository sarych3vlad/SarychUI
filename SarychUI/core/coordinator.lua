-- SarychUI Feature Coordinator
-- Mutual exclusion and runtime gating for overlapping modules/addons.

local ipairs, pairs = ipairs, pairs
local format = string.format
local tinsert = table.insert

SarychUI.Coordinator = SarychUI.Coordinator or {}
local Coordinator = SarychUI.Coordinator

Coordinator._state = Coordinator._state or {
	standalone = {},
	gated = {},
	disabledByCoordinator = {},
	blizzMoveBlocked = {},
}

local STANDALONE_EMBEDDED = {
	Mapster = true,
	Postal = true,
	GladiusEx = true,
	FindGroup = true,
	WDM = true,
	["!Astrolabe"] = true,
}

local LOOT_EXCLUSIVE_MODE = {
	pretty = "pretty_lootalert",
}

local LOOT_INDEPENDENT = {
	LootClicker = true,
	LootHistory = true,
}

-- Legacy map kept for GetAddOnArea / conflict checks.
local LOOT_ADDONS = {
	pretty = LOOT_EXCLUSIVE_MODE.pretty,
	history = "LootHistory",
	clicker = "LootClicker",
}

local AREA_ADDON_OWNERS = {
	map = {
		mapster = "Mapster",
		carbonite = "Carbonite",
	},
	loot = LOOT_ADDONS,
}

local function Profile()
	local db = SarychUI and SarychUI.db and SarychUI.db.profile
	return db
end

local function AddonsDB()
	local db = Profile()
	return db and db.addons
end

local function ModulesDB()
	local db = Profile()
	return db and db.modules
end

-- GetAddOnInfo results are fixed for the session, and this is queried from hot
-- paths (tooltips, 41 SetMoveHandler sites), so memoize per addon name.
local wowAddOnEnabledCache = {}

function Coordinator:IsWoWAddOnEnabled(addonName)
	if not addonName or not GetAddOnInfo then
		return false
	end

	local cached = wowAddOnEnabledCache[addonName]
	if cached ~= nil then
		return cached
	end

	local result = false
	local _, _, _, enabled, loadable = GetAddOnInfo(addonName)
	if loadable then
		result = enabled and true or false
	end

	wowAddOnEnabledCache[addonName] = result
	return result
end

function Coordinator:HasExternalBagnon()
	return self:IsWoWAddOnEnabled("Bagnon") or self:IsWoWAddOnEnabled("BagnonForever")
end

function Coordinator:NormalizeBagsMode(mode)
	mode = mode or "default"
	if mode == "default" then
		mode = "classic"
	end
	if mode == "bagnon" and not self:HasExternalBagnon() then
		return "classic"
	end
	if mode == "elvui" and self:IsWoWAddOnEnabled("ElvUI") then
		return "classic"
	end
	if mode == "baudbag" then
		return "baudbag"
	end
	return mode
end

-- Built once: every input comes from the session-static addon list.
local standaloneConflicts

function Coordinator:GetStandaloneConflicts()
	if standaloneConflicts then
		return standaloneConflicts
	end

	local conflicts = {}
	for standalone, _ in pairs(STANDALONE_EMBEDDED) do
		if self:IsWoWAddOnEnabled(standalone) then
			conflicts[standalone] = true
		end
	end
	if self:IsWoWAddOnEnabled("ElvUI") then
		conflicts.ElvUI = true
	end

	standaloneConflicts = conflicts
	self._state.standalone = conflicts
	return conflicts
end

function Coordinator:GetActiveFeatureOwner(area)
	local modules = ModulesDB()
	local addons = AddonsDB()
	if not modules then
		return nil
	end

	if area == "map" then
		if SarychUI.GetMapMode then
			return SarychUI:GetMapMode()
		end
		return modules.map and modules.map.mapType or "mapster"
	end

	if area == "bags" then
		local bags = modules.bags
		return self:NormalizeBagsMode(bags and bags.mode)
	end

	if area == "nameplates" then
		if SarychUI.GetNameplateMode then
			return SarychUI:GetNameplateMode()
		end
		local hi = modules.health_indicators
		if hi and hi.nameplateMode then
			return hi.nameplateMode
		end
		if addons and addons.ElvUI_NamePlates and addons.ElvUI_NamePlates.enabled ~= false then
			return "elvui"
		end
		return "classic"
	end

	if area == "arena" then
		local arena = modules.arena
		if arena and arena.frameType then
			return arena.frameType
		end
		if addons and addons.GladiusEx and addons.GladiusEx.enabled == true then
			return "gladiusex"
		end
		return "classic"
	end

	if area == "loot" then
		local loot = modules.loot
		if loot and loot.mode and LOOT_EXCLUSIVE_MODE[loot.mode] then
			return loot.mode
		end
		if addons then
			if addons.pretty_lootalert and addons.pretty_lootalert.enabled ~= false then return "pretty" end
		end
		return "classic"
	end

	if area == "mail" then
		if self:IsWoWAddOnEnabled("Postal") then
			return "postal_standalone"
		end
		if addons and addons.Postal and addons.Postal.enabled then
			return "postal_embedded"
		end
		return "classic"
	end

	return nil
end

function Coordinator:RecordGate(key, reason)
	self._state.gated[key] = reason
	tinsert(self._state.disabledByCoordinator, { key = key, reason = reason })
end

function Coordinator:ClearState()
	self._state.gated = {}
	self._state.disabledByCoordinator = {}
	self._state.blizzMoveBlocked = {}
end

function Coordinator:SyncNameplateModeFromDB()
	local modules = ModulesDB()
	local addons = AddonsDB()
	if not modules or not addons then return end

	modules.health_indicators = modules.health_indicators or { enabled = true }
	local hi = modules.health_indicators
	addons.ElvUI_NamePlates = addons.ElvUI_NamePlates or { enabled = true }

	-- Module off → runtime classic, but keep nameplateMode as the user's preferred choice for re-enable.
	if hi.enabled == false then
		addons.ElvUI_NamePlates.enabled = false
		return
	end

	if hi.nameplateMode == nil then
		if addons.ElvUI_NamePlates.enabled ~= false then
			hi.nameplateMode = "elvui"
		else
			hi.nameplateMode = "classic"
		end
	end

	if hi.nameplateMode == "elvui" then
		addons.ElvUI_NamePlates.enabled = true
	else
		hi.nameplateMode = "classic"
		addons.ElvUI_NamePlates.enabled = false
	end
end

function Coordinator:SyncLootModeFromDB()
	local modules = ModulesDB()
	local addons = AddonsDB()
	if not modules or not addons then return end

	modules.loot = modules.loot or { mode = "pretty" }
	local mode = modules.loot.mode

	local db = Profile()
	if db then
		db.coordination = db.coordination or {}
		if not db.coordination.lootIndependentMigrated then
			db.coordination.lootIndependentMigrated = true
			if mode == "clicker" then
				addons.LootClicker = addons.LootClicker or { enabled = false }
				addons.LootClicker.enabled = true
				modules.loot.mode = "classic"
				mode = "classic"
			elseif mode == "history" then
				addons.LootHistory = addons.LootHistory or { enabled = false }
				addons.LootHistory.enabled = true
				modules.loot.mode = "classic"
				mode = "classic"
			end
		end
	end

	if mode == nil then
		if addons.pretty_lootalert and addons.pretty_lootalert.enabled ~= false then
			mode = "pretty"
		else
			mode = "classic"
		end
		modules.loot.mode = mode
	end

	addons.pretty_lootalert = addons.pretty_lootalert or { enabled = false }
	addons.LootClicker = addons.LootClicker or { enabled = true }
	addons.LootHistory = addons.LootHistory or { enabled = true }

	if mode == "classic" then
		addons.pretty_lootalert.enabled = false
	elseif LOOT_EXCLUSIVE_MODE[mode] then
		addons.pretty_lootalert.enabled = (mode == "pretty")
	else
		modules.loot.mode = "classic"
		addons.pretty_lootalert.enabled = false
	end
end

function Coordinator:SyncBagsModeFromDB()
	local modules = ModulesDB()
	local addons = AddonsDB()
	if not modules or not addons then return end

	modules.bags = modules.bags or { enabled = true, mode = "default" }
	-- Bagnon_FT: тултипы/учёт предметов по персонажам — совместим с SarychUI Bags, classic и Bagnon UI.
	-- Не входит в bags.mode; включается отдельным тумблером в списке аддонов.
	addons.Bagnon_FT = addons.Bagnon_FT or { enabled = true }
	addons.BaudBag = addons.BaudBag or { enabled = false }
	-- Migrate renamed embed key (ElvUI_Bags → SarychUI_Bags).
	if type(addons.ElvUI_Bags) == "table" and type(addons.SarychUI_Bags) ~= "table" then
		addons.SarychUI_Bags = CopyTable(addons.ElvUI_Bags)
	end
	addons.SarychUI_Bags = addons.SarychUI_Bags or { enabled = false }

	local mode = modules.bags.mode or "default"
	if mode == "classic" then
		mode = "default"
		modules.bags.mode = "default"
	end

	local owner = self:NormalizeBagsMode(mode)
	-- Режим сумок — источник истины; флаги аддонов синхронизируются с ним.
	addons.BaudBag.enabled = (owner == "baudbag")
	addons.SarychUI_Bags.enabled = (owner == "elvui")
end

function Coordinator:SyncArenaModeFromDB()
	local modules = ModulesDB()
	local addons = AddonsDB()
	if not modules or not addons then return end

	modules.arena = modules.arena or { enabled = true, frameType = "classic" }
	addons.GladiusEx = addons.GladiusEx or { enabled = false }

	if modules.arena.frameType == "gladiusex" then
		addons.GladiusEx.enabled = true
	elseif modules.arena.frameType == nil then
		modules.arena.frameType = addons.GladiusEx.enabled == true and "gladiusex" or "classic"
	else
		if modules.arena.frameType == "classic" then
			addons.GladiusEx.enabled = false
		end
	end

	if addons.GladiusEx.enabled == true then
		modules.arena.frameType = "gladiusex"
	else
		if modules.arena.frameType == "gladiusex" then
			modules.arena.frameType = "classic"
		end
	end
end

function Coordinator:SyncMapModeFromDB()
	local modules = ModulesDB()
	local addons = AddonsDB()
	if not modules or not modules.map or not addons then return end

	local mapType = modules.map.mapType or "mapster"
	addons.Mapster = addons.Mapster or { enabled = true }
	addons.Carbonite = addons.Carbonite or { enabled = false }

	if mapType == "carbonite" then
		if SarychUI and SarychUI.IsExternalCarboniteAvailable and not SarychUI:IsExternalCarboniteAvailable() then
			mapType = "mapster"
			modules.map.mapType = mapType
		end
	end

	if mapType == "carbonite" then
		addons.Carbonite.enabled = true
		addons.Mapster.enabled = false
	elseif mapType == "mapster" then
		addons.Mapster.enabled = true
		addons.Carbonite.enabled = false
	else
		addons.Mapster.enabled = false
		addons.Carbonite.enabled = false
	end
end

function Coordinator:ApplyStandaloneBlocks()
	local addons = AddonsDB()
	if not addons then return end

	local standalone = self:GetStandaloneConflicts()

	for name, _ in pairs(standalone) do
		if STANDALONE_EMBEDDED[name] and addons[name] then
			addons[name].enabled = false
			self:RecordGate(name, format("Заблокировано: включён standalone %s", name))
		end
	end

	if standalone.ElvUI then
		if addons.SarychUI_Bags then
			addons.SarychUI_Bags.enabled = false
			self:RecordGate("SarychUI_Bags", "Заблокировано: установлен полный ElvUI")
		end
		if addons.ElvUI_NamePlates then
			addons.ElvUI_NamePlates.enabled = false
			self:RecordGate("ElvUI_NamePlates", "Заблокировано: установлен полный ElvUI")
		end
		local modules = ModulesDB()
		if modules and modules.bags and modules.bags.mode == "elvui" then
			modules.bags.mode = "default"
		end
		if modules and modules.health_indicators then
			modules.health_indicators.nameplateMode = "classic"
		end
	end
end

function Coordinator:UpdateBlizzMoveBlocks()
	local blocks = {}
	-- Postal дополняет почту (кнопки, Open All), но не позицию окна — MailFrame можно двигать через BlizzMove.

	local bagsOwner = self:GetActiveFeatureOwner("bags")
	if bagsOwner == "elvui" then
		blocks.BankFrame = "SarychUI Bags управляет банком"
		self:RecordGate("BlizzMove:BankFrame", blocks.BankFrame)
	elseif bagsOwner == "baudbag" then
		blocks.BankFrame = "Baud Bag управляет банком"
		self:RecordGate("BlizzMove:BankFrame", blocks.BankFrame)
	end

	self._state.blizzMoveBlocked = blocks
end

function Coordinator:MigrateBagnonFTDecoupling()
	local db = Profile()
	local modules = ModulesDB()
	local addons = AddonsDB()
	if not db or not modules or not addons then return end

	db.coordination = db.coordination or {}
	if db.coordination.bagnonFtDecoupled then
		return
	end
	db.coordination.bagnonFtDecoupled = true

	addons.Bagnon_FT = addons.Bagnon_FT or {}
	if addons.Bagnon_FT.enabled == nil then
		addons.Bagnon_FT.enabled = true
	end
	if addons.Bagnon_FT.showOnAlt == nil then
		addons.Bagnon_FT.showOnAlt = false
	end
end

function SarychUI:ResolveFeatureConflicts()
	if not Coordinator.ClearState then return end
	Coordinator:ClearState()
	Coordinator._state.resolved = true

	local modules = ModulesDB()
	if not modules then return end

	modules.loot = modules.loot or { mode = "pretty" }
	modules.health_indicators = modules.health_indicators or { enabled = true }

	Coordinator:MigrateBagnonFTDecoupling()
	Coordinator:SyncMapModeFromDB()
	Coordinator:SyncArenaModeFromDB()
	Coordinator:SyncNameplateModeFromDB()
	Coordinator:SyncBagsModeFromDB()
	Coordinator:SyncLootModeFromDB()
	Coordinator:ApplyStandaloneBlocks()
	Coordinator:UpdateBlizzMoveBlocks()
end

function Coordinator:ApplyRuntimeForAddon(addonName, shouldEnable)
	if not SarychUI then return end
	local wrapper = SarychUI.GetAddOn and SarychUI:GetAddOn(addonName)
	if not wrapper then return end

	if shouldEnable then
		if wrapper.Enable then
			wrapper:Enable()
		end
	else
		if wrapper.Disable then
			wrapper:Disable()
		end
	end
end

function Coordinator:SyncArenaRuntime()
	local arena = SarychUI.modules and SarychUI.modules.arena
	if not arena then return end

	local owner = self:GetActiveFeatureOwner("arena")
	if owner == "gladiusex" then
		if arena.Disable then
			arena:Disable()
		end
		local gx = SarychUI.GetAddOn and SarychUI:GetAddOn("GladiusEx")
		if gx and gx.SetRuntimeEnabled then
			gx:SetRuntimeEnabled(true)
		else
			self:ApplyRuntimeForAddon("GladiusEx", true)
		end
	else
		self:ApplyRuntimeForAddon("GladiusEx", false)
		local modules = ModulesDB()
		if modules and modules.arena and modules.arena.enabled and arena.Enable then
			arena:Enable()
		end
	end
end

function Coordinator:ApplyAddonRuntimeFlags()
	local addons = AddonsDB()
	if not addons or not SarychUI then return end

	SarychUI._coordinatorApplying = true

	local mapOwner = self:GetActiveFeatureOwner("map")
	if mapOwner == "carbonite" and SarychUI and SarychUI.IsExternalCarboniteAvailable and not SarychUI:IsExternalCarboniteAvailable() then
		if SarychUI.SetMapType then
			SarychUI:SetMapType("mapster")
		end
		mapOwner = "mapster"
	end

	for mapMode, addonName in pairs(AREA_ADDON_OWNERS.map) do
		local want = (mapOwner == mapMode)
		if addons[addonName] then
			addons[addonName].enabled = want and true or false
		end
		if addonName ~= "Carbonite" then
			self:ApplyRuntimeForAddon(addonName, want)
		end
	end

	for lootMode, addonName in pairs(LOOT_EXCLUSIVE_MODE) do
		local lootOwner = self:GetActiveFeatureOwner("loot")
		local want = (lootOwner == lootMode)
		if addons[addonName] then
			addons[addonName].enabled = want and true or false
		end
		self:ApplyRuntimeForAddon(addonName, want)
	end

	for addonName in pairs(LOOT_INDEPENDENT) do
		local want = addons[addonName] and addons[addonName].enabled == true
		self:ApplyRuntimeForAddon(addonName, want)
	end

	local npOwner = self:GetActiveFeatureOwner("nameplates")
	local wantNP = (npOwner == "elvui")
	if addons.ElvUI_NamePlates then
		addons.ElvUI_NamePlates.enabled = wantNP
	end
	local npWrapper = SarychUI.GetAddOn and SarychUI:GetAddOn("ElvUI_NamePlates")
	if npWrapper and npWrapper.SetRuntimeEnabled then
		npWrapper:SetRuntimeEnabled(wantNP)
	else
		self:ApplyRuntimeForAddon("ElvUI_NamePlates", wantNP)
	end

	local bagsOwner = self:GetActiveFeatureOwner("bags")
	local wantBagnonFT = addons.Bagnon_FT and addons.Bagnon_FT.enabled ~= false
	self:ApplyRuntimeForAddon("Bagnon_FT", wantBagnonFT)

	local mailOwner = self:GetActiveFeatureOwner("mail")
	local wantPostal = (mailOwner == "postal_embedded")
	if addons.Postal then
		if self:IsWoWAddOnEnabled("Postal") then
			addons.Postal.enabled = false
			wantPostal = false
		end
		addons.Postal.enabled = wantPostal
	end
	self:ApplyRuntimeForAddon("Postal", wantPostal)

	self:SyncArenaRuntime()

	SarychUI._coordinatorApplying = nil
end

function SarychUI:ApplyFeatureCoordination(opts)
	opts = opts or {}
	if not Coordinator.ClearState then return end

	if not opts.skipResolve then
		self:ResolveFeatureConflicts()
	end

	Coordinator:ApplyAddonRuntimeFlags()

	local tools = self.modules and self.modules.tools
	if tools and tools.ApplyBlizzMove then
		tools:ApplyBlizzMove()
	end

	local plates = self.modules and self.modules.plates_auras
	if plates and plates.ApplySettings and opts.refreshPlates ~= false then
		plates:ApplySettings()
	end
end

function SarychUI:GetActiveFeatureOwner(area)
	return Coordinator:GetActiveFeatureOwner(area)
end

function SarychUI:IsBlizzMoveFrameAllowed(frameName)
	if not frameName then return true end
	local blocked = Coordinator._state.blizzMoveBlocked
	if blocked[frameName] then
		return false
	end
	-- Resolve lazily, but only while the state has never been built. An empty
	-- blocked table is the normal case, so keying off next(blocked) made every
	-- caller (41 SetMoveHandler sites at login) run a full resolve pass.
	if SarychUI.ResolveFeatureConflicts and not Coordinator._state.resolved then
		SarychUI:ResolveFeatureConflicts()
		blocked = Coordinator._state.blizzMoveBlocked
	end
	return not blocked[frameName]
end

function SarychUI:GetCoordinationBlockReason(key)
	return Coordinator._state.gated[key]
end

function Coordinator:GetAddOnArea(addonName)
	if AREA_ADDON_OWNERS.map[addonName] or addonName == "Mapster" or addonName == "Carbonite" then
		return "map"
	end
	if LOOT_ADDONS.pretty == addonName or LOOT_ADDONS.history == addonName or LOOT_ADDONS.clicker == addonName then
		return "loot"
	end
	if addonName == "ElvUI_NamePlates" then return "nameplates" end
	if addonName == "BaudBag" or addonName == "SarychUI_Bags" then return "bags" end
	if addonName == "GladiusEx" then return "arena" end
	if addonName == "Postal" then return "mail" end
	return nil
end

function SarychUI:CanEnableCoordinatedAddOn(addonName)
	local standalone = Coordinator:GetStandaloneConflicts()
	if standalone[addonName] and STANDALONE_EMBEDDED[addonName] then
		return false, format("|cffff0000Включите только один %s|r — отключите standalone в списке аддонов WoW.", addonName)
	end
	if standalone.ElvUI and (addonName == "SarychUI_Bags" or addonName == "ElvUI_NamePlates") then
		return false, "|cffff0000Встроенный модуль недоступен:|r установлен полный ElvUI."
	end

	local area = Coordinator:GetAddOnArea(addonName)
	if not area then
		return true
	end

	if area == "map" then
		for mapMode, name in pairs(AREA_ADDON_OWNERS.map) do
			if name == addonName then
				if addonName == "Carbonite" and SarychUI and SarychUI.IsExternalCarboniteAvailable and not SarychUI:IsExternalCarboniteAvailable() then
					return false, "|cffff0000Carbonite недоступен:|r установите и включите аддон Carbonite в списке аддонов WoW."
				end
				return true
			end
		end
	end

	if area == "loot" then
		for mode, name in pairs(LOOT_ADDONS) do
			if name == addonName then
				return true
			end
		end
	end

	if area == "nameplates" and addonName == "ElvUI_NamePlates" then
		return true
	end

	if area == "bags" and (addonName == "BaudBag" or addonName == "SarychUI_Bags") then
		return true
	end

	if area == "arena" and addonName == "GladiusEx" then
		return true
	end

	if area == "mail" and addonName == "Postal" then
		if standalone.Postal then
			return false, "|cffff0000Встроенный Postal заблокирован|r — включён standalone Postal."
		end
		return true
	end

	return true
end

function SarychUI:IsCoordinatedAddOnAllowed(addonName)
	local addons = AddonsDB()
	if not addons or not addons[addonName] then
		return false
	end
	if not addons[addonName].enabled then
		return false
	end

	local standalone = Coordinator:GetStandaloneConflicts()
	if standalone[addonName] then
		return false
	end
	if standalone.ElvUI and (addonName == "SarychUI_Bags" or addonName == "ElvUI_NamePlates") then
		return false
	end

	for lootMode, name in pairs(LOOT_EXCLUSIVE_MODE) do
		if name == addonName then
			return Coordinator:GetActiveFeatureOwner("loot") == lootMode
		end
	end

	if LOOT_INDEPENDENT[addonName] then
		return addons[addonName].enabled == true
	end

	if addonName == "Mapster" then
		return Coordinator:GetActiveFeatureOwner("map") == "mapster"
	end
	if addonName == "Carbonite" then
		if not (SarychUI and SarychUI.IsExternalCarboniteAvailable and SarychUI:IsExternalCarboniteAvailable()) then
			return false
		end
		return Coordinator:GetActiveFeatureOwner("map") == "carbonite"
	end
	if addonName == "ElvUI_NamePlates" then
		return Coordinator:GetActiveFeatureOwner("nameplates") == "elvui"
	end
	if addonName == "BaudBag" then
		return Coordinator:GetActiveFeatureOwner("bags") == "baudbag"
	end
	if addonName == "SarychUI_Bags" then
		return Coordinator:GetActiveFeatureOwner("bags") == "elvui"
	end
	if addonName == "GladiusEx" then
		return Coordinator:GetActiveFeatureOwner("arena") == "gladiusex"
	end
	if addonName == "Postal" then
		local mailOwner = Coordinator:GetActiveFeatureOwner("mail")
		return mailOwner == "postal_embedded"
	end

	return true
end

function SarychUI:SetBagsMode(mode)
	local modules = ModulesDB()
	if not modules then return end
	modules.bags = modules.bags or { enabled = true }
	modules.bags.mode = mode
	self:ApplyFeatureCoordination({ refreshPlates = false })
	local bags = self.modules and self.modules.bags
	if bags and bags.IsEnabled and bags:IsEnabled() and bags.ApplyMode then
		bags:ApplyMode()
	end
end

function SarychUI:SetNameplateMode(mode)
	local modules = ModulesDB()
	if not modules then return end
	modules.health_indicators = modules.health_indicators or { enabled = true }
	modules.health_indicators.nameplateMode = (mode == "elvui") and "elvui" or "classic"
	self:ApplyFeatureCoordination()
end

function SarychUI:SetLootMode(mode)
	local modules = ModulesDB()
	if not modules then return end
	modules.loot = modules.loot or {}
	modules.loot.mode = mode or "classic"
	self:ApplyFeatureCoordination({ refreshPlates = false })
end

function SarychUI:SetArenaMode(mode)
	local modules = ModulesDB()
	if not modules then return end
	modules.arena = modules.arena or { enabled = true }
	modules.arena.frameType = (mode == "gladiusex") and "gladiusex" or "classic"
	self:ApplyFeatureCoordination({ refreshPlates = false })
end

function SarychUI:PrintConflictsReport()
	local function line(label, value, extra)
		print(format("  %s: |cff00ff00%s|r%s", label, value or "?", extra or ""))
	end

	print("|cffffd200SarychUI|r — координация функций:")
	line("Карта", self:GetActiveFeatureOwner("map"))
	line("Сумки", self:GetActiveFeatureOwner("bags"))
	line("Nameplates", self:GetActiveFeatureOwner("nameplates"))
	line("Арена", self:GetActiveFeatureOwner("arena"))
	line("Loot", self:GetActiveFeatureOwner("loot"))
	line("Почта", self:GetActiveFeatureOwner("mail"))

	local standalone = Coordinator:GetStandaloneConflicts()
	local standaloneList = {}
	for name in pairs(standalone) do
		tinsert(standaloneList, name)
	end
	if #standaloneList == 0 then
		print("  Standalone конфликты: |cff00ff00нет|r")
	else
		print("  Standalone конфликты: |cffff0000" .. table.concat(standaloneList, ", ") .. "|r")
	end

	if Coordinator._state.gated and next(Coordinator._state.gated) then
		print("  Автоотключено координатором:")
		for key, reason in pairs(Coordinator._state.gated) do
			print(format("    - %s: %s", key, reason))
		end
	else
		print("  Автоотключено координатором: |cff808080нет|r")
	end

	local blocked = Coordinator._state.blizzMoveBlocked
	if blocked and next(blocked) then
		print("  BlizzMove заблокирован на:")
		for frameName, reason in pairs(blocked) do
			print(format("    - %s (%s)", frameName, reason))
		end
	end

	print("  |cff808080Подсказка:|r после смены режима карты/сумок/nameplates может потребоваться /reload")
end
