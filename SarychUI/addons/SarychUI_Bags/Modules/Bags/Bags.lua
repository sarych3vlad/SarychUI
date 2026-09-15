local E, L, V, P, G = unpack(_G.SarychUI_Bags) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local B = E:GetModule("Bags")
local Skins = E:GetModule("Skins")
local Search = E.Libs.ItemSearch

--Lua functions
local _G = _G
local type, ipairs, pairs, unpack, select, assert, pcall = type, ipairs, pairs, unpack, select, assert, pcall
local floor, ceil, abs, max = math.floor, math.ceil, math.abs, math.max
local format, sub, gsub, strmatch, strlower = string.format, string.sub, string.gsub, string.match, string.lower
local tinsert, tremove, twipe = table.insert, table.remove, table.wipe
--WoW API / Variables
local BankFrameItemButton_Update = BankFrameItemButton_Update
local BankFrameItemButton_UpdateLocked = BankFrameItemButton_UpdateLocked
local CloseBag, CloseBackpack, CloseBankFrame = CloseBag, CloseBackpack, CloseBankFrame
local CooldownFrame_SetTimer = CooldownFrame_SetTimer
local CreateFrame = CreateFrame
local DeleteCursorItem = DeleteCursorItem
local GameTooltip_Hide = GameTooltip_Hide
local GetBackpackCurrencyInfo = GetBackpackCurrencyInfo
local GetContainerItemCooldown = GetContainerItemCooldown
local GetContainerItemID = GetContainerItemID
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemQuestInfo = GetContainerItemQuestInfo
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local Blizzard_GetContainerNumSlots = GetContainerNumSlots
local GetCurrentGuildBankTab = GetCurrentGuildBankTab
local ContainerIDToInventoryID = ContainerIDToInventoryID
local GetInventoryItemLink = GetInventoryItemLink
local NUM_BANKBAGSLOTS = NUM_BANKBAGSLOTS or 7
local GetCVarBool = GetCVarBool
local GetGuildBankItemLink = GetGuildBankItemLink
local GetGuildBankTabInfo = GetGuildBankTabInfo
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor
local GetMoney = GetMoney
local GetNumBankSlots = GetNumBankSlots
local GetKeyRingSize = GetKeyRingSize
local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight
local IsBagOpen, IsOptionFrameOpen = IsBagOpen, IsOptionFrameOpen
local IsModifiedClick = IsModifiedClick
local IsShiftKeyDown, IsControlKeyDown = IsShiftKeyDown, IsControlKeyDown
local PickupContainerItem = PickupContainerItem
local PlaySound = PlaySound
local PutItemInBackpack = PutItemInBackpack
local PutItemInBag = PutItemInBag
local SetItemButtonCount = SetItemButtonCount
local SetItemButtonDesaturated = SetItemButtonDesaturated
local SetItemButtonTexture = SetItemButtonTexture
local SetItemButtonTextureVertexColor = SetItemButtonTextureVertexColor
local ToggleFrame = ToggleFrame
local UseContainerItem = UseContainerItem

local BACKPACK_TOOLTIP = BACKPACK_TOOLTIP
local BINDING_NAME_TOGGLEKEYRING = BINDING_NAME_TOGGLEKEYRING
local CONTAINER_OFFSET_X, CONTAINER_OFFSET_Y = CONTAINER_OFFSET_X, CONTAINER_OFFSET_Y
local CONTAINER_SCALE = CONTAINER_SCALE
local CONTAINER_SPACING, VISIBLE_CONTAINER_SPACING = CONTAINER_SPACING, VISIBLE_CONTAINER_SPACING
local CONTAINER_WIDTH = CONTAINER_WIDTH
local ITEM_ACCOUNTBOUND = ITEM_ACCOUNTBOUND
local ITEM_BIND_ON_EQUIP = ITEM_BIND_ON_EQUIP
local ITEM_BIND_ON_USE = ITEM_BIND_ON_USE
local ITEM_BNETACCOUNTBOUND = ITEM_BNETACCOUNTBOUND
local ITEM_SOULBOUND = ITEM_SOULBOUND
local KEYRING_CONTAINER = KEYRING_CONTAINER
local MAX_CONTAINER_ITEMS = MAX_CONTAINER_ITEMS
local MAX_WATCHED_TOKENS = MAX_WATCHED_TOKENS
local NUM_BAG_FRAMES = NUM_BAG_FRAMES
local NUM_CONTAINER_FRAMES = NUM_CONTAINER_FRAMES
local SEARCH = SEARCH

local SEARCH_STRING = ""

-- Offline bank view (Baud Bag-style cache). Live bank session sets bankIsOpen.
B.bankIsOpen = false
B.bankOfflineView = false

local BANK_BAG_IDS = {-1, 5, 6, 7, 8, 9, 10, 11}

local function BankCacheCharKey()
	return (GetRealmName() or "?") .. "-" .. (UnitName("player") or "?")
end

function B:IsBankBagID(bagID)
	return bagID == -1 or (type(bagID) == "number" and bagID >= 5 and bagID <= 11)
end

function B:GetBankCache()
	if not E.global then return nil end
	E.global.bankCache = E.global.bankCache or {}
	local key = BankCacheCharKey()
	E.global.bankCache[key] = E.global.bankCache[key] or {}
	return E.global.bankCache[key]
end

function B:GetCachedBankBag(bagID)
	local cache = B:GetBankCache()
	return cache and cache[bagID] or nil
end

function B:GetCachedBankSlot(bagID, slotID)
	local bag = B:GetCachedBankBag(bagID)
	return bag and bag[slotID] or nil
end

function B:HasBankCache()
	local bag = B:GetCachedBankBag(-1)
	return bag and type(bag.Size) == "number" and bag.Size > 0
end

function B:CacheBankContents()
	if not B.bankIsOpen or not E.embeddedInSarychUI then return end
	local cache = B:GetBankCache()
	if not cache then return end

	cache.numSlots = GetNumBankSlots() or 0

	for _, bagID in ipairs(BANK_BAG_IDS) do
		local size = Blizzard_GetContainerNumSlots(bagID) or 0
		local bag = cache[bagID] or {}
		twipe(bag)
		bag.Size = size
		if bagID >= 5 and ContainerIDToInventoryID then
			local invID = ContainerIDToInventoryID(bagID)
			if invID then
				bag.BagLink = GetInventoryItemLink("player", invID)
			end
		end
		for slotID = 1, size do
			local link = GetContainerItemLink(bagID, slotID)
			if link then
				bag[slotID] = {
					Link = link,
					Count = select(2, GetContainerItemInfo(bagID, slotID)) or 1,
				}
			end
		end
		cache[bagID] = bag
	end
end

function B:HasCachedBankBag(bagID)
	local bag = B:GetCachedBankBag(bagID)
	if not bag then return false end
	-- Real bag present: equipped bag link and/or a non-empty container size.
	return (bag.BagLink and bag.BagLink ~= "") or ((bag.Size or 0) > 0)
end

function B:GetOfflineNumBankSlots()
	-- Offline "Toggle Bags" should list only bags that actually exist in cache,
	-- not empty purchased bank slots (those looked like phantom bags).
	local n = 0
	for bagID = 5, 11 do
		if B:HasCachedBankBag(bagID) then
			n = n + 1
		end
	end
	return n
end

function B:UpdateBankInteractionButtons()
	local f = B.BankFrame
	if not f then return end
	local offline = E.embeddedInSarychUI and not B.bankIsOpen
	if f.sortButton then
		if offline or E.db.bags.disableBankSort then
			f.sortButton:Disable()
		else
			f.sortButton:Enable()
		end
	end
	-- Purchase Bags / vendor grays are not used on the bank toolbar.
	if f.purchaseBagButton then
		f.purchaseBagButton:Hide()
	end
	if f.vendorGraysButton then
		f.vendorGraysButton:Hide()
	end
end

-- Shadow Blizzard API so Layout/UpdateSlot see cached sizes while viewing offline bank.
local function GetContainerNumSlots(bagID)
	if E.embeddedInSarychUI and B:IsBankBagID(bagID) and not B.bankIsOpen then
		local bag = B:GetCachedBankBag(bagID)
		if bag and type(bag.Size) == "number" then
			return bag.Size
		end
		if B.bankOfflineView then
			return 0
		end
	end
	return Blizzard_GetContainerNumSlots(bagID)
end

-- Side inset for slots, search, toolbar buttons, and footer (same value everywhere).
local function GetBagEdgePad()
	return (E.Border * 2) + 6
end

local function HasAnyText(text, ...)
	if type(text) ~= "string" then return false end
	local lowered = strlower(text)
	for i = 1, select("#", ...) do
		local needle = select(i, ...)
		if type(needle) == "string" and needle ~= "" then
			if lowered:find(strlower(needle), 1, true) or text:find(needle, 1, true) then
				return true
			end
		end
	end
	return false
end

local function IsFoodDrinkSubType(itemSubType)
	return type(itemSubType) == "string"
		and ((ITEM_SUBCLASS_FOOD_DRINK and itemSubType == ITEM_SUBCLASS_FOOD_DRINK)
			or HasAnyText(itemSubType, "Food", "Drink", "Еда", "Напит"))
end

local function IsRecoverySubType(itemSubType)
	return type(itemSubType) == "string"
		and ((ITEM_SUBCLASS_POTION and itemSubType == ITEM_SUBCLASS_POTION)
			or (ITEM_SUBCLASS_FLASK and itemSubType == ITEM_SUBCLASS_FLASK)
			or (ITEM_SUBCLASS_ELIXIR and itemSubType == ITEM_SUBCLASS_ELIXIR)
			or HasAnyText(itemSubType, "Potion", "Flask", "Elixir", "Зель", "Фляг", "Настой"))
end

local function IsAmmoSubType(itemSubType)
	return type(itemSubType) == "string"
		and ((ITEM_SUBCLASS_ARROW and itemSubType == ITEM_SUBCLASS_ARROW)
			or (ITEM_SUBCLASS_BULLET and itemSubType == ITEM_SUBCLASS_BULLET)
			or HasAnyText(itemSubType, "Arrow", "Bullet", "Стрела", "Стрелы", "Пуля", "Пули"))
end

local function IsAmmoItem(itemType, itemSubType, equipLoc)
	if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_AMMO" then
		return false
	end

	local isProjectileClass = type(itemType) == "string"
		and ((ITEM_CLASS_PROJECTILE and itemType == ITEM_CLASS_PROJECTILE)
			or HasAnyText(itemType, "Projectile", "Боеприпасы"))

	if equipLoc == "INVTYPE_AMMO" then
		return isProjectileClass or IsAmmoSubType(itemSubType)
	end

	return isProjectileClass and IsAmmoSubType(itemSubType)
end

local function IsQuestItemType(itemType)
	return type(itemType) == "string"
		and ((ITEM_CLASS_QUESTITEM and itemType == ITEM_CLASS_QUESTITEM)
			or HasAnyText(itemType, "Quest", "Задани"))
end

function B:IsAdiBagsModeSelected()
	return E.embeddedInSarychUI and B.db and B.db.splitMode == "adibags"
end

-- True only when AdiBags mode is selected AND category layout is toggled on.
function B:IsAdiBagsSplitMode()
	if not B:IsAdiBagsModeSelected() then
		return false
	end
	return B.db.adiBagsCategories ~= false
end

function B:UpdateSectionSplitButton(btn)
	if not btn then return end
	local enabled = B:IsAdiBagsSplitMode()
	btn.ttText = L["Item Categories"]
	btn.ttText2 = enabled and L["Item Categories On"] or L["Item Categories Off"]
	local tex = btn:GetNormalTexture()
	if tex then
		if enabled then
			tex:SetVertexColor(1, 0.82, 0)
		else
			tex:SetVertexColor(1, 1, 1)
		end
	end
	local pushed = btn:GetPushedTexture()
	if pushed then
		if enabled then
			pushed:SetVertexColor(1, 0.82, 0)
		else
			pushed:SetVertexColor(1, 1, 1)
		end
	end
	if btn.SetBackdropBorderColor then
		if enabled then
			btn:SetBackdropBorderColor(0.95, 0.78, 0.15, 1)
		else
			btn:SetBackdropBorderColor(0.20, 0.20, 0.20, 1)
		end
	end
end

function B:UpdateAllSectionSplitButtons()
	if B.BagFrame and B.BagFrame.sectionSplitButton then
		B:UpdateSectionSplitButton(B.BagFrame.sectionSplitButton)
	end
	for _, f in ipairs(B.BagFrames or {}) do
		if f and f.sectionSplitButton then
			B:UpdateSectionSplitButton(f.sectionSplitButton)
		end
	end
end

-- Toolbar toggle: only shows/hides AdiBags category sections (never falls back to classic splits).
function B:SetAdiBagsCategoriesEnabled(enabled)
	if not E.embeddedInSarychUI then return end
	enabled = enabled and true or false
	if B.db then
		-- Keep/select AdiBags mode; do not switch to classic when turning categories off.
		B.db.splitMode = "adibags"
		B.db.adiBagsCategories = enabled
	end
	local elvui = B:EnsureElvUISettingsTable()
	if elvui then
		elvui.splitMode = "adibags"
		elvui.adiBagsCategories = enabled
	end
	B:UpdateAllSectionSplitButtons()

	-- Defer heavy Layout + options rebuild off the click frame (first-toggle hitch).
	B._suiPendingCatLayout = true
	local driver = B._suiCatLayoutDriver
	if not driver then
		driver = CreateFrame("Frame")
		B._suiCatLayoutDriver = driver
		driver:SetScript("OnUpdate", function(self)
			self:Hide()
			if not B._suiPendingCatLayout then return end
			B._suiPendingCatLayout = nil
			if B.BagFrame then
				B:Layout()
			end
			-- Bank only when visible — offline bank Layout is costly and unused here.
			if B.BankFrame and B.BankFrame:IsShown() then
				B:Layout(true)
			end
			local optionsOpen = (SarychUI and SarychUI.OptionsCore and SarychUI.OptionsCore._open)
				or (SarychUI and SarychUI.IsSarychUIOptionsOpen and SarychUI:IsSarychUIOptionsOpen())
			if optionsOpen and SarychUI and SarychUI.NotifySarychUIOptionsChange then
				SarychUI:NotifySarychUIOptionsChange()
			end
		end)
	end
	driver:Show()
end

function B:ToggleSectionSplitMode()
	PlaySound("igMainMenuOptionCheckBoxOn")
	B:SetAdiBagsCategoriesEnabled(not B:IsAdiBagsSplitMode())
end

function B:IsAdditionalSplitEnabled(isBank)
	if not E.embeddedInSarychUI or isBank or not B.db then
		return false
	end
	-- AdiBags mode: categories on/off only — never use classic bottom-group toggles.
	if B:IsAdiBagsModeSelected() then
		return B.db.adiBagsCategories ~= false
	end
	return B.db.consumableSplit == true or B.db.ammoSplit == true or B.db.questSplit == true
end

-- AdiBags-like section keys (display order).
local ADIBAGS_SECTION_ORDER = {
	"quest",
	"equipment",
	"consumable",
	"tradeGoods",
	"recipe",
	"ammo",
	"miscellaneous",
	"junk",
	"empty",
}

-- Labels match AdiBags category headers (RU UI).
local ADIBAGS_SECTION_LABELS = {
	quest = "Задания",
	equipment = "Экипировка",
	consumable = "Расходные материалы",
	tradeGoods = "Хозяйственные товары",
	recipe = "Рецепты",
	ammo = "Боеприпасы",
	miscellaneous = "Разное",
	junk = "Хлам",
	empty = "Свободно",
}

local ADIBAGS_HEADER_SIZE = 14
local ADIBAGS_HEADER_GAP = 2
-- Extra air under the toolbar for the first category header row.
local ADIBAGS_FIRST_HEADER_TOP_PAD = 2

function B:ClearAdiBagsFreeSpaceFlags(slot)
	if not slot then return end
	slot._suiFreeSpaceStack = nil
	slot._suiFreeSpaceHidden = nil
end

-- AdiBags-style virtual free-space stack: one empty cell with total free count.
function B:ApplyAdiBagsFreeSpaceDisplay(slot, count)
	if not slot then return end
	count = tonumber(count) or 0
	slot._suiFreeSpaceStack = count
	slot._suiFreeSpaceHidden = nil
	if not slot.Count then return end
	if count > 1 then
		if E.embeddedInSarychUI and B.ApplySlotTextFont then
			B:ApplySlotTextFont(slot.Count, B:GetStackFontSize())
		end
		local color = E.db and E.db.bags and E.db.bags.countFontColor
		if color then
			slot.Count:SetTextColor(color.r or 1, color.g or 1, color.b or 1)
		end
		slot.Count:SetText(tostring(count))
		slot.Count:Show()
	else
		slot.Count:SetText("")
		slot.Count:Hide()
	end
end

function B:CollapseAdiBagsEmptySlots(slots)
	if not slots or #slots == 0 then
		return slots
	end
	local count = #slots
	local representative = slots[1]
	for i = 2, count do
		local slot = slots[i]
		if slot then
			slot._suiFreeSpaceHidden = true
			slot._suiFreeSpaceStack = nil
			if slot:GetPoint() then
				slot:ClearAllPoints()
			end
			slot:Hide()
		end
	end
	B:ApplyAdiBagsFreeSpaceDisplay(representative, count)
	return { representative }
end

local ADIBAGS_EQUIP_LOCS = {
	INVTYPE_AMMO = 0,
	INVTYPE_HEAD = 1,
	INVTYPE_NECK = 2,
	INVTYPE_SHOULDER = 3,
	INVTYPE_BODY = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8,
	INVTYPE_WRIST = 9,
	INVTYPE_HAND = 10,
	INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 13,
	INVTYPE_CLOAK = 15,
	INVTYPE_WEAPON = 16,
	INVTYPE_SHIELD = 17,
	INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16,
	INVTYPE_WEAPONOFFHAND = 17,
	INVTYPE_HOLDABLE = 17,
	INVTYPE_RANGED = 18,
	INVTYPE_THROWN = 18,
	INVTYPE_RANGEDRIGHT = 18,
	INVTYPE_RELIC = 18,
	INVTYPE_TABARD = 19,
	INVTYPE_BAG = 20,
}

local adiBagsAuctionMap

local function BuildAdiBagsAuctionMap()
	if adiBagsAuctionMap then
		return adiBagsAuctionMap
	end
	adiBagsAuctionMap = {}
	if type(GetAuctionItemClasses) ~= "function" then
		return adiBagsAuctionMap
	end
	local classes = { GetAuctionItemClasses() }
	-- Typical 3.3.5 order: Weapon, Armor, Container, Consumable, Glyph?, Trade Goods, Projectile, Quiver, Recipe, Gem, Miscellaneous, Quest
	for i, name in ipairs(classes) do
		if type(name) == "string" then
			local key
			if HasAnyText(name, "Quest", "Задани") then
				key = "quest"
			elseif HasAnyText(name, "Weapon", "Armor", "Оружие", "Доспех", "Броня") then
				key = "equipment"
			elseif HasAnyText(name, "Consumable", "Расход") then
				key = "consumable"
			elseif HasAnyText(name, "Trade", "Товар", "Хозяйствен", "Реагент")
				or HasAnyText(name, "Gem", "Самоцвет", "Glyph", "Символ") then
				key = "tradeGoods"
			elseif HasAnyText(name, "Recipe", "Рецепт") then
				key = "recipe"
			elseif HasAnyText(name, "Projectile", "Quiver", "Боеприпас", "Колчан", "Подсумок") then
				key = "ammo"
			else
				key = "miscellaneous"
			end
			adiBagsAuctionMap[name] = key
		end
	end
	return adiBagsAuctionMap
end

function B:GetAdiBagsSectionKey(bagID, slotID)
	local link = GetContainerItemLink(bagID, slotID)
	if not link then
		return "empty"
	end

	local isQuestItem, questId = GetContainerItemQuestInfo(bagID, slotID)
	if isQuestItem or questId then
		return "quest"
	end

	local name, _, quality, itemLevel, _, itemType, itemSubType, _, equipLoc = GetItemInfo(link)
	if not itemType and not itemSubType and not equipLoc then
		return "miscellaneous"
	end

	if IsQuestItemType(itemType) then
		return "quest"
	end

	if IsAmmoItem(itemType, itemSubType, equipLoc) then
		return "ammo"
	end

	if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
		-- Bags/quivers stay misc unless ammo; wearable gear → equipment.
		if equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_QUIVER" then
			return "miscellaneous"
		end
		if equipLoc ~= "INVTYPE_AMMO" and equipLoc ~= "INVTYPE_TABARD" and equipLoc ~= "INVTYPE_BODY" then
			return "equipment"
		end
		if equipLoc == "INVTYPE_TABARD" or equipLoc == "INVTYPE_BODY" then
			return "miscellaneous"
		end
	end

	if quality == 0 then
		return "junk"
	end

	local map = BuildAdiBagsAuctionMap()
	local mapped = itemType and map[itemType]
	if mapped then
		return mapped
	end

	if HasAnyText(itemType, "Consumable", "Расход") then
		return "consumable"
	end
	if HasAnyText(itemType, "Trade", "Товар", "Хозяйствен") then
		return "tradeGoods"
	end
	if HasAnyText(itemType, "Recipe", "Рецепт") then
		return "recipe"
	end
	if HasAnyText(itemType, "Weapon", "Armor", "Оружие", "Доспех", "Броня") then
		return "equipment"
	end

	return "miscellaneous"
end

function B:BuildAdiBagsSortKey(slot)
	if not slot then
		return nil
	end
	local bagID, slotID = slot.bagID, slot.slotID
	local link = (bagID and slotID) and GetContainerItemLink(bagID, slotID)
	if not link then
		return {
			empty = true,
			bagID = bagID or 0,
			slotID = slotID or 0,
		}
	end
	local name, _, quality, level, _, class, subclass, _, equipSlot = GetItemInfo(link)
	local _, count = GetContainerItemInfo(bagID, slotID)
	return {
		empty = false,
		equipLoc = ADIBAGS_EQUIP_LOCS[equipSlot or ""] or 999,
		class = class or "",
		subclass = subclass or "",
		quality = quality or 0,
		level = level or 0,
		name = name or "",
		count = count or 0,
		slotID = slotID or 0,
		bagID = bagID or 0,
	}
end

function B:CompareAdiBagsSortKeys(keyA, keyB)
	if not keyA then return false end
	if not keyB then return true end
	if keyA.empty and keyB.empty then
		if keyA.bagID ~= keyB.bagID then
			return keyA.bagID < keyB.bagID
		end
		return keyA.slotID < keyB.slotID
	end
	if keyA.empty then return false end
	if keyB.empty then return true end

	if keyA.equipLoc ~= keyB.equipLoc and keyA.equipLoc ~= 999 and keyB.equipLoc ~= 999 then
		return keyA.equipLoc < keyB.equipLoc
	elseif keyA.class ~= keyB.class then
		return keyA.class < keyB.class
	elseif keyA.subclass ~= keyB.subclass then
		return keyA.subclass < keyB.subclass
	elseif keyA.quality ~= keyB.quality then
		return keyA.quality > keyB.quality
	elseif keyA.level ~= keyB.level then
		return keyA.level > keyB.level
	elseif keyA.name ~= keyB.name then
		return keyA.name < keyB.name
	elseif keyA.count ~= keyB.count then
		return keyA.count > keyB.count
	end
	return keyA.slotID < keyB.slotID
end

function B:CompareAdiBagsSlots(slotA, slotB)
	return B:CompareAdiBagsSortKeys(B:BuildAdiBagsSortKey(slotA), B:BuildAdiBagsSortKey(slotB))
end

function B:SortAdiBagsSection(slots)
	if not slots or #slots < 2 then return end
	-- Precompute GetItemInfo once per slot — table.sort otherwise re-queries O(n log n) times.
	local keys = {}
	for i = 1, #slots do
		local slot = slots[i]
		keys[slot] = B:BuildAdiBagsSortKey(slot)
	end
	table.sort(slots, function(a, b)
		return B:CompareAdiBagsSortKeys(keys[a], keys[b])
	end)
end

function B:WarmAdiBagsLayoutCaches(bagFrame)
	if not E.embeddedInSarychUI then return end
	BuildAdiBagsAuctionMap()
	if bagFrame and bagFrame.holderFrame then
		bagFrame._suiAdiBagsHeaders = bagFrame._suiAdiBagsHeaders or {}
		for i = 1, #ADIBAGS_SECTION_ORDER do
			if not bagFrame._suiAdiBagsHeaders[i] then
				local fs = bagFrame.holderFrame:CreateFontString(nil, "OVERLAY")
				if B.ApplySectionHeaderFont then
					B:ApplySectionHeaderFont(fs)
				end
				fs:Hide()
				bagFrame._suiAdiBagsHeaders[i] = fs
			end
		end
	end
	-- Touch item cache so first categories toggle does not cold-load every link.
	for bagID = 0, NUM_BAG_SLOTS or 4 do
		local numSlots = GetContainerNumSlots(bagID) or 0
		for slotID = 1, numSlots do
			local link = GetContainerItemLink(bagID, slotID)
			if link then
				GetItemInfo(link)
			end
		end
	end
end

function B:TooltipHasRecoveryText(link)
	if not link then return false end
	if not self.consumableSplitTooltip then
		self.consumableSplitTooltip = CreateFrame("GameTooltip", "SarychUIBagsConsumableSplitTooltip", UIParent, "GameTooltipTemplate")
		self.consumableSplitTooltip:SetOwner(UIParent, "ANCHOR_NONE")
		self.consumableSplitTooltip:SetScript("OnTooltipAddMoney", function() end)
	end

	local tooltip = self.consumableSplitTooltip
	tooltip:ClearLines()
	tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	tooltip:SetScript("OnTooltipAddMoney", function() end)
	if not pcall(tooltip.SetHyperlink, tooltip, link) then
		return false
	end

	local tooltipName = tooltip:GetName()
	local numLines = tooltip.NumLines and tooltip:NumLines() or 12
	for i = 1, numLines do
		local line = _G[tooltipName.."TextLeft"..i]
		local text = line and line:GetText()
		if HasAnyText(text, "health", "mana", "restore", "restores", "heals", "Здоров", "здоров", "Ман", "ман", "Восполн", "восполн", "Восстанов", "восстанов") then
			return true
		end
	end

	return false
end

function B:GetAdditionalSplitKind(bagID, slotID)
	if B.db.questSplit then
		local isQuestItem, questId = GetContainerItemQuestInfo(bagID, slotID)
		if isQuestItem or questId then
			return "quest"
		end
	end

	local link = GetContainerItemLink(bagID, slotID)
	if not link then return nil end

	self.consumableSplitCache = self.consumableSplitCache or {}
	local cacheKey = (B.db.consumableSplit and "c" or "-")..(B.db.ammoSplit and "a" or "-")..(B.db.questSplit and "q" or "-")..link
	local cached = self.consumableSplitCache[cacheKey]
	if cached ~= nil then
		return cached or nil
	end

	local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(link)
	if not itemType and not itemSubType then return nil end

	local kind
	if B.db.questSplit and IsQuestItemType(itemType) then
		kind = "quest"
	elseif B.db.ammoSplit and IsAmmoItem(itemType, itemSubType, equipLoc) then
		kind = "ammo"
	elseif B.db.consumableSplit and IsFoodDrinkSubType(itemSubType) then
		kind = "food"
	elseif B.db.consumableSplit and IsRecoverySubType(itemSubType) and self:TooltipHasRecoveryText(link) then
		kind = "recovery"
	end

	if kind then
		self.consumableSplitCache[cacheKey] = kind
	end
	return kind
end

local DEBUG_ELVUI_BAGS = false
local DEBUG_ELVUI_BAGS_SORT = false
local DEBUG_ELVUI_BAGS_SHIFT = false
local DEBUG_ELVUI_BAGS_TOOLTIP = false
local DEBUG_ELVUI_BAGS_SKIN = false
local DEBUG_ELVUI_BAGS_BUTTONS = false
local DEBUG_ELVUI_BAGS_GHOST = false
local DEBUG_ELVUI_BAGS_REFRESH = false

local BAG_WINDOW_FONT_DEFAULT = "Friz Quadrata TT"
local BAG_POSITION_FALLBACK = {
	point = "BOTTOMRIGHT",
	relativePoint = "BOTTOMRIGHT",
	relativeTo = "UIParent",
	x = -20,
	y = 130,
}

local BANK_POSITION_FALLBACK = {
	point = "BOTTOMRIGHT",
	relativePoint = "BOTTOMLEFT",
	relativeTo = "ElvUI_ContainerFrame",
	x = -10,
	y = 0,
}

local MoveTooltip = CreateFrame("GameTooltip", "ElvUIBagsMoveTooltip", UIParent, "GameTooltipTemplate")
MoveTooltip:SetClampedToScreen(true)

local BAG_BAR_BUTTONS = {
	"MainMenuBarBackpackButton",
	"CharacterBag0Slot",
	"CharacterBag1Slot",
	"CharacterBag2Slot",
	"CharacterBag3Slot",
}

local function SarychChatPrefix(scope)
	if SarychUI and SarychUI.GetScopedChatPrefix then
		return SarychUI:GetScopedChatPrefix(scope)
	end
	return "|cffffd200SarychUI " .. scope .. ":|r"
end

local function bagDebug(...)
	if not DEBUG_ELVUI_BAGS and not _G.SarychUI_DebugBagsPosition then return end
	print(SarychChatPrefix("Bags"), ...)
end

local function bagsDragDebug(...)
	if not _G.SarychUI_DebugBagsDrag then return end
	print(SarychChatPrefix("Bags Drag"), ...)
end

local function FrameDebugName(frame)
	if not frame then return "nil" end
	if frame.GetName then
		return frame:GetName() or tostring(frame)
	end
	return tostring(frame)
end

local function positionDebug(label, frame, pos)
	if not _G.SarychUI_DebugBagsPosition then return end
	if not frame then
		bagDebug(label, "frame=nil")
		return
	end
	local name = frame.GetName and frame:GetName() or "?"
	if pos then
		bagDebug(label, name, pos.point, pos.relativePoint, pos.relativeTo, pos.x, pos.y)
	else
		local point, anchor, relativePoint, x, y = frame:GetPoint()
		local anchorName = anchor and anchor.GetName and anchor:GetName() or "?"
		bagDebug(label, name, "live", point, relativePoint, anchorName, x, y)
	end
end

local function sortElvDebug(...)
	if not DEBUG_ELVUI_BAGS_SORT then return end
	print("[SarychUI_Bags Sort]", ...)
end

local function buttonDebug(...)
	if not DEBUG_ELVUI_BAGS_BUTTONS then return end
	print("[SarychUI_Bags Buttons]", ...)
end

local function shiftDebug(...)
	if not DEBUG_ELVUI_BAGS_SHIFT then return end
	print("[SarychUI_Bags Shift]", ...)
end

local function moveTooltipDebug(...)
	if not DEBUG_ELVUI_BAGS_TOOLTIP and not DEBUG_ELVUI_BAGS_SKIN then return end
	print("[SarychUI_Bags Skin]", ...)
end

local function skinDebug(...)
	if not DEBUG_ELVUI_BAGS_SKIN then return end
	print("[SarychUI_Bags Skin]", ...)
end

local function ghostDebug(...)
	if not DEBUG_ELVUI_BAGS_GHOST then return end
	print("[SarychUI_Bags Ghost]", ...)
end

local function refreshDebug(...)
	if not DEBUG_ELVUI_BAGS_REFRESH then return end
	print("[SarychUI_Bags Refresh]", ...)
end

function B:EnsureSlotLayers(slot)
	if not slot or slot._layersResolved then return end

	local name = slot.GetName and slot:GetName()
	if name then
		slot.iconTexture = slot.iconTexture or _G[name .. "IconTexture"]
		slot.iconBorder = slot.iconBorder or _G[name .. "IconBorder"]
		slot.cooldown = slot.cooldown or _G[name .. "Cooldown"]
		slot.Count = slot.Count or _G[name .. "Count"]
		slot.questIcon = slot.questIcon or _G[name .. "IconQuestTexture"]
	end

	slot._layersResolved = true
end

function B:PreferSarychUICooldown(cooldown)
	if not cooldown then return end

	cooldown.forceDisabled = true
	cooldown.CooldownOverride = nil
	cooldown.__sary_cc_noCount = nil

	if cooldown.timer and E.Cooldown_StopTimer then
		E:Cooldown_StopTimer(cooldown.timer)
	end
end

function B:ClearEmptySlotVisuals(slot)
	if not slot then return end

	B:EnsureSlotLayers(slot)

	SetItemButtonTexture(slot, nil)
	SetItemButtonCount(slot, 0)
	SetItemButtonDesaturated(slot, false)
	SetItemButtonTextureVertexColor(slot, 1, 1, 1)

	if slot.iconTexture then
		slot.iconTexture:SetTexture(nil)
		slot.iconTexture:SetTexCoord(0, 1, 0, 1)
		slot.iconTexture:SetVertexColor(1, 1, 1)
		slot.iconTexture:Hide()
	end

	if slot.iconBorder then
		slot.iconBorder:SetTexture(nil)
		slot.iconBorder:Hide()
	end

	if slot.Count then
		slot.Count:SetText("")
		slot.Count:Hide()
	end

	if slot.cooldown then
		CooldownFrame_SetTimer(slot.cooldown, 0, 0, 0)
		slot.cooldown:Hide()
	end

	if slot.itemLevel then
		slot.itemLevel:SetText("")
		slot.itemLevel:Hide()
	end

	if slot.bindType then
		slot.bindType:SetText("")
		slot.bindType:Hide()
	end

	if slot.questIcon then
		slot.questIcon:Hide()
	end

	if slot.JunkIcon then
		slot.JunkIcon:Hide()
	end

	if slot.searchOverlay then
		slot.searchOverlay:Hide()
	end

	if slot.hoverOverlay and not slot:IsMouseOver() then
		slot.hoverOverlay:Hide()
	end

	if slot.hover and slot.hover ~= slot.hoverOverlay and not slot:IsMouseOver() then
		slot.hover:Hide()
	end

	if slot.pushed and slot.pushed.Hide then
		slot.pushed:Hide()
	end

	if slot.SetButtonState then
		slot:SetButtonState("NORMAL")
	end

	if slot.UnlockHighlight then
		slot:UnlockHighlight()
	end

	slot.hasItem = nil
	slot.itemLink = nil
	slot.itemID = nil
end

function B:ClearSlotTransientVisuals(slot)
	if not slot then return end

	B:EnsureSlotLayers(slot)

	if slot.searchOverlay then
		slot.searchOverlay:Hide()
	end

	slot:SetAlpha(1)

	if slot.UnlockHighlight then
		slot:UnlockHighlight()
	end

	if slot.hoverOverlay and not slot:IsMouseOver() then
		slot.hoverOverlay:Hide()
	elseif slot.hover and slot.hover ~= slot.hoverOverlay and not slot:IsMouseOver() then
		slot.hover:Hide()
	end

	if slot.pushed and slot.pushed.Hide then
		slot.pushed:Hide()
	end

	if slot.SetButtonState then
		slot:SetButtonState("NORMAL")
	end
end

function B:ClearTransientSlotVisuals(bagFrame)
	if not (bagFrame and bagFrame.BagIDs) then return end

	for _, bagID in ipairs(bagFrame.BagIDs) do
		local bags = bagFrame.Bags[bagID]
		if bags then
			for slotID = 1, GetContainerNumSlots(bagID) do
				B:ClearSlotTransientVisuals(bags[slotID])
			end
		end
	end
end

function B:DebugGhostSlots(bagFrame)
	if not DEBUG_ELVUI_BAGS_GHOST or not (bagFrame and bagFrame.BagIDs) then return end

	for _, bagID in ipairs(bagFrame.BagIDs) do
		local bags = bagFrame.Bags[bagID]
		if bags then
			for slotID = 1, GetContainerNumSlots(bagID) do
				local slot = bags[slotID]
				if slot then
					B:EnsureSlotLayers(slot)
					local apiTexture = GetContainerItemInfo(bagID, slotID)
					local iconTexture = slot.iconTexture and slot.iconTexture:GetTexture()
					local iconShown = slot.iconTexture and slot.iconTexture:IsShown()
					if (not apiTexture) and iconTexture and iconShown then
						ghostDebug("bag=", bagID, "slot=", slotID)
						ghostDebug("api texture=", tostring(apiTexture))
						ghostDebug("button.icon texture=", tostring(iconTexture))
						ghostDebug("hover shown=", tostring(slot.hoverOverlay and slot.hoverOverlay:IsShown()))
						ghostDebug("overlay shown=", tostring(slot.searchOverlay and slot.searchOverlay:IsShown()))
						ghostDebug("cooldown shown=", tostring(slot.cooldown and slot.cooldown:IsShown()))
						ghostDebug("count text=", slot.Count and slot.Count:GetText() or "")
					end
				end
			end
		end
	end
end

function B:RestoreBagFrameEvents(bagFrame)
	if not bagFrame then return end

	bagFrame:RegisterEvent("BAG_UPDATE")
	bagFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")

	if bagFrame.events then
		for _, event in pairs(bagFrame.events) do
			bagFrame:RegisterEvent(event)
		end
	end
end

function B:ForceRefreshAllBagSlots(bagFrame, reason)
	if not (bagFrame and bagFrame.BagIDs) then return end

	reason = reason or "manual"
	bagFrame.registerUpdate = nil

	B:ClearSortingFade(bagFrame)

	for _, bagID in ipairs(bagFrame.BagIDs) do
		local bags = bagFrame.Bags[bagID]
		if bags then
			for slotID = 1, GetContainerNumSlots(bagID) do
				local slot = bags[slotID]
				if slot then
					B:EnsureSlotLayers(slot)
					local oldTexture = slot.iconTexture and slot.iconTexture:GetTexture()
					local apiTexture = GetContainerItemInfo(bagID, slotID)
					local isEmpty = not apiTexture

					B:UpdateSlot(bagFrame, bagID, slotID)

					if DEBUG_ELVUI_BAGS_REFRESH then
						local newTexture = slot.iconTexture and slot.iconTexture:GetTexture()
						local mismatch = (isEmpty and newTexture and slot.iconTexture:IsShown())
							or (apiTexture and (not newTexture or not slot.iconTexture:IsShown()))
						if mismatch or oldTexture ~= newTexture then
							refreshDebug("bag=", bagID, "slot=", slotID, "reason=", reason)
							refreshDebug("api texture=", tostring(apiTexture))
							refreshDebug("old button texture=", tostring(oldTexture))
							refreshDebug("new button texture=", tostring(newTexture))
							refreshDebug("empty=", tostring(isEmpty))
							if isEmpty and newTexture then
								refreshDebug("clearing stale icon")
							end
						end
					end
				end
			end
		end
	end

	B:ClearTransientSlotVisuals(bagFrame)
	B:DebugGhostSlots(bagFrame)

	if B:RefreshAdditionalSplitLayout(bagFrame, reason) then
		B:ClearTransientSlotVisuals(bagFrame)
	end

	if B:IsSearching() then
		B:RefreshSearch()
	end
end

function B:RefreshAdditionalSplitLayout(bagFrame, reason)
	if not (bagFrame and bagFrame:IsShown() and B:IsAdditionalSplitEnabled(bagFrame.isBank)) then return false end
	B:Layout(bagFrame.isBank)
	if DEBUG_ELVUI_BAGS_REFRESH then
		refreshDebug("additional split layout", reason or "layout")
	end
	return true
end

function B:ForceRefreshAllBagFrames(reason)
	for _, bagFrame in pairs(B.BagFrames or {}) do
		B:ForceRefreshAllBagSlots(bagFrame, reason)
	end
end

function B:ScheduleSortSlotRefresh(bagFrame)
	if not bagFrame then return end

	local function runRefresh(tag)
		if not bagFrame:IsShown() and tag ~= "sort-complete" then
			return
		end
		B:RestoreBagFrameEvents(bagFrame)
		B:ForceRefreshAllBagSlots(bagFrame, tag)
		B:StopSortSpinner(bagFrame)
	end

	runRefresh("sort-complete")
	E:Delay(0, function() runRefresh("after-0") end)
	E:Delay(0.1, function() runRefresh("after-0.1") end)
end

function B:FinishSortVisualRefresh(bagFrame)
	if not bagFrame then return end
	B:RestoreBagFrameEvents(bagFrame)
	B:ForceRefreshAllBagSlots(bagFrame, "finish-sort")
	B:StopSortSpinner(bagFrame)
end

local function GetArialFontPath()
	if E.Libs and E.Libs.LSM then
		return E.Libs.LSM:Fetch("font", "Arial Narrow") or [[Fonts\ARIALN.TTF]]
	end
	return [[Fonts\ARIALN.TTF]]
end

local function ResolveOutlineFlag(outline)
	if not outline or outline == "NONE" then
		return ""
	end
	return outline
end

-- Chrome (title / search / buttons): fixed style, not tied to slot-text options.
function B:GetBagWindowFontName()
	return BAG_WINDOW_FONT_DEFAULT
end

function B:GetBagWindowFont()
	if not E.Libs or not E.Libs.LSM then
		return [[Fonts\FRIZQT__.TTF]]
	end
	return E.Libs.LSM:Fetch("font", BAG_WINDOW_FONT_DEFAULT) or [[Fonts\FRIZQT__.TTF]]
end

-- Slot text (stacks / item level): driven by "Шрифт сумки" options.
function B:GetSlotTextFontStyle()
	local elvui = B:EnsureElvUISettingsTable() or {}
	local fontName = elvui.bagFont
	if type(fontName) ~= "string" or fontName == "" then
		fontName = "Arial Narrow"
	end
	local fontPath = [[Fonts\ARIALN.TTF]]
	if E.Libs and E.Libs.LSM then
		fontPath = E.Libs.LSM:Fetch("font", fontName) or E.Libs.LSM:Fetch("font", "Arial Narrow") or fontPath
	end
	return {
		fontName = fontName,
		path = fontPath,
		outline = ResolveOutlineFlag(elvui.bagFontOutline or "OUTLINE"),
		shadowX = tonumber(elvui.bagFontShadowX) or 0,
		shadowY = tonumber(elvui.bagFontShadowY) or 0,
	}
end

function B:ApplySlotTextFont(fs, size)
	if not fs or not fs.SetFont then return end
	local style = B:GetSlotTextFontStyle()
	fs:SetFont(style.path, size or 12, style.outline)
	fs:SetShadowOffset(style.shadowX, style.shadowY)
	fs:SetShadowColor(0, 0, 0, 1)
end

-- AdiBags section headers: tunable via SarychUI bags → «Шрифт заголовков секций».
function B:GetSectionHeaderStyle()
	local elvui = B:EnsureElvUISettingsTable() or {}
	local fontName = elvui.sectionHeaderFont
	if type(fontName) ~= "string" or fontName == "" then
		fontName = "Nimrod MT"
	end
	local fontPath = [[Fonts\NIM_____.ttf]]
	if E.Libs and E.Libs.LSM then
		fontPath = E.Libs.LSM:Fetch("font", fontName)
			or E.Libs.LSM:Fetch("font", "Nimrod MT")
			or fontPath
	end
	local baseSize = tonumber(elvui.sectionHeaderFontSize) or 14
	local scale = tonumber(elvui.sectionHeaderFontScale) or 0.75
	if scale < 0.5 then scale = 0.5 end
	if scale > 2 then scale = 2 end
	local fontSize = math.max(8, math.floor(baseSize * scale + 0.5))
	return {
		fontName = fontName,
		path = fontPath,
		fontSize = fontSize,
		baseSize = baseSize,
		scale = scale,
		outline = ResolveOutlineFlag(elvui.sectionHeaderFontOutline or "NONE"),
		shadowX = tonumber(elvui.sectionHeaderShadowX) or 0,
		shadowY = tonumber(elvui.sectionHeaderShadowY) or 0,
		headerHeight = math.max(fontSize + 2, 12),
	}
end

function B:ApplySectionHeaderFont(fs)
	if not fs or not fs.SetFont then return end
	local style = B:GetSectionHeaderStyle()
	fs:SetFont(style.path, style.fontSize, style.outline or "")
	fs:SetShadowOffset(style.shadowX or 0, style.shadowY or 0)
	if (style.shadowX or 0) == 0 and (style.shadowY or 0) == 0 then
		fs:SetShadowColor(0, 0, 0, 0)
	else
		fs:SetShadowColor(0, 0, 0, 1)
	end
	-- Barely-visible label: soft white at low alpha.
	fs:SetTextColor(1, 1, 1, 0.28)
end

local function SoftFont(fs, size, fontPath)
	if not fs or not fs.SetFont then return end
	fs:SetFont(fontPath or B:GetBagWindowFont(), size or 12, "")
	fs:SetShadowOffset(1, -0.5)
	fs:SetShadowColor(0, 0, 0, 1)
end

-- Footer style: currencies left, money right. Tunable via SarychUI bags options.
local FOOTER_ICON_TEXT = 4
local FOOTER_TOKEN_GAP = 12
local FOOTER_BOTTOM = 6

function B:GetFooterStyle()
	local elvui = B:EnsureElvUISettingsTable() or {}
	local fontName = elvui.footerFont
	if type(fontName) ~= "string" or fontName == "" then
		fontName = "Arial Narrow"
	end
	local fontPath = [[Fonts\ARIALN.TTF]]
	if E.Libs and E.Libs.LSM then
		fontPath = E.Libs.LSM:Fetch("font", fontName) or E.Libs.LSM:Fetch("font", "Arial Narrow") or fontPath
	end
	local fontSize = tonumber(elvui.footerFontSize) or 13
	local moneyIcon = tonumber(elvui.footerMoneyIconSize) or 14
	local currencyIcon = tonumber(elvui.footerCurrencyIconSize) or 15
	local rowH = math.max(fontSize, moneyIcon, currencyIcon, 16)
	return {
		fontName = fontName,
		fontPath = fontPath,
		fontSize = fontSize,
		outline = ResolveOutlineFlag(elvui.footerFontOutline),
		shadowX = tonumber(elvui.footerShadowX) or 1,
		shadowY = tonumber(elvui.footerShadowY) or -1,
		moneyIcon = moneyIcon,
		currencyIcon = currencyIcon,
		rowH = rowH,
	}
end

function B:GetSarychUIBagFooterHeight()
	local style = B:GetFooterStyle()
	return style.rowH + FOOTER_BOTTOM + 4
end

local function StripCurrencyBackdrop(button)
	if not button then return end
	if button.SetBackdrop then button:SetBackdrop(nil) end
	if button.iborder then button.iborder:Hide() end
	if button.oborder then button.oborder:Hide() end
end

local function StyleFooterFont(fs, style)
	if not fs then return end
	style = style or B:GetFooterStyle()
	fs:SetFont(style.fontPath, style.fontSize, style.outline)
	fs:SetShadowOffset(style.shadowX, style.shadowY)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetTextColor(0.95, 0.95, 0.95, 1)
end

function B:LayoutSarychUIBagFooter(bagFrame)
	if not E.embeddedInSarychUI or not bagFrame then return end

	local edgePad = GetBagEdgePad()
	local style = B:GetFooterStyle()
	local footerH = style.rowH

	-- Money (right)
	if bagFrame.goldText then
		if not bagFrame.suiMoneyFrame then
			bagFrame.suiMoneyFrame = CreateFrame("Frame", nil, bagFrame)
		end
		local mf = bagFrame.suiMoneyFrame
		mf:SetHeight(footerH)
		mf:SetFrameLevel((bagFrame:GetFrameLevel() or 0) + 5)

		local gt = bagFrame.goldText
		gt:SetParent(mf)
		gt:ClearAllPoints()
		gt:SetJustifyH("RIGHT")
		gt:SetDrawLayer("OVERLAY")
		StyleFooterFont(gt, style)
		gt:SetPoint("RIGHT", mf, "RIGHT", 0, 0)
		gt:Show()

		local textW = gt:GetStringWidth() or 0
		if textW < 8 then textW = 8 end
		mf:SetWidth(textW + 2)
		mf:ClearAllPoints()
		mf:SetPoint("BOTTOMRIGHT", bagFrame, "BOTTOMRIGHT", -edgePad, FOOTER_BOTTOM)
		mf:Show()
	end

	-- Currencies (left): icon + count
	local container = bagFrame.currencyButton
	if not container then return end

	local visible = {}
	for i = 1, MAX_WATCHED_TOKENS do
		local button = container[i]
		if button and button:IsShown() then
			visible[#visible + 1] = button
		end
	end

	if #visible == 0 then
		container:Hide()
		return
	end

	local tokenIcon = style.currencyIcon
	local totalWidth = 0
	for i = 1, #visible do
		local button = visible[i]
		StripCurrencyBackdrop(button)
		StyleFooterFont(button.text, style)

		local textW = (button.text and (button.text:GetStringWidth() or 0)) or 0
		local itemW = tokenIcon + FOOTER_ICON_TEXT + textW
		button:Size(itemW, footerH)
		button:ClearAllPoints()

		if button.icon then
			button.icon:ClearAllPoints()
			button.icon:Size(tokenIcon)
			button.icon:SetTexCoord(unpack(E.TexCoords))
			button.icon:Point("LEFT", button, "LEFT", 0, 0)
		end
		if button.text then
			button.text:ClearAllPoints()
			button.text:SetJustifyH("LEFT")
			button.text:Point("LEFT", button.icon or button, "RIGHT", FOOTER_ICON_TEXT, 0)
		end

		if i == 1 then
			button:Point("LEFT", container, "LEFT", 0, 0)
			totalWidth = itemW
		else
			button:Point("LEFT", visible[i - 1], "RIGHT", FOOTER_TOKEN_GAP, 0)
			totalWidth = totalWidth + FOOTER_TOKEN_GAP + itemW
		end
	end

	container:ClearAllPoints()
	container:Size(totalWidth, footerH)
	container:Point("BOTTOMLEFT", bagFrame, "BOTTOMLEFT", edgePad, FOOTER_BOTTOM)
	container:Show()
end

-- Compat aliases
function B:LayoutSarychUIBagMoney(bagFrame)
	B:LayoutSarychUIBagFooter(bagFrame)
end

function B:LayoutCurrencyTokens(bagFrame, numTokens)
	if not bagFrame then return end
	if not E.embeddedInSarychUI then
		local container = bagFrame.currencyButton
		if not container or not numTokens or numTokens <= 0 then return end
		if numTokens == 1 then
			container[1]:Point("BOTTOM", container, "BOTTOM", -(container[1].text:GetWidth() / 2), 3)
		elseif numTokens == 2 then
			container[1]:Point("BOTTOM", container, "BOTTOM", -(container[1].text:GetWidth()) - (container[1]:GetWidth() / 2), 3)
			container[2]:Point("BOTTOMLEFT", container, "BOTTOM", container[2]:GetWidth() / 2, 3)
		else
			container[1]:Point("BOTTOMLEFT", container, "BOTTOMLEFT", 3, 3)
			container[2]:Point("BOTTOM", container, "BOTTOM", -(container[2].text:GetWidth() / 3), 3)
			container[3]:Point("BOTTOMRIGHT", container, "BOTTOMRIGHT", -(container[3].text:GetWidth()) - (container[3]:GetWidth() / 2), 3)
		end
		return
	end
	B:LayoutSarychUIBagFooter(bagFrame)
end

function B:ApplyMoveTooltipFonts()
	local fontPath = B:GetBagWindowFont()
	for i = 1, MoveTooltip:NumLines() do
		local left = _G["ElvUIBagsMoveTooltipTextLeft" .. i]
		local right = _G["ElvUIBagsMoveTooltipTextRight" .. i]
		if left then
			left:SetFont(fontPath, 12, "OUTLINE")
		end
		if right then
			right:SetFont(fontPath, 12, "OUTLINE")
		end
	end
end

function B:ApplyCurrencyLayout()
	if E.embeddedInSarychUI and B.BagFrame then
		B:ApplyFooterSettings()
	end
end

-- Lightweight footer refresh for options sliders (no full bag font pass).
function B:ApplyFooterSettings()
	if not E.embeddedInSarychUI or not B.BagFrame then return end

	local newBottom = B:GetSarychUIBagFooterHeight()
	if B.BagFrame.bottomOffset ~= newBottom then
		B.BagFrame.bottomOffset = newBottom
		B:Layout()
	end

	if B.BagFrame.goldText then
		B.BagFrame.goldText:SetText(B:FormatBagMoney(GetMoney()))
	end
	B:LayoutSarychUIBagFooter(B.BagFrame)
end

function B:ApplyCurrencyBlockLayout()
	B:ApplyCurrencyLayout()
end

function B:UpdateCurrencyDisplay()
	if B.UpdateTokens then
		B:UpdateTokens()
	end
end

function B:ApplyBagWindowFonts()
	if not E.embeddedInSarychUI then return end

	-- Chrome stays on fixed SoftFont; slot text options apply only to stacks / ilvl.
	local function applyChrome(frame)
		if not frame then return end
		SoftFont(frame.bagText, 12)
		SoftFont(frame.editBox, 11)
		if frame.sortButton and frame.sortButton.text then
			SoftFont(frame.sortButton.text, 12)
		end
		if frame.suiTitle then
			SoftFont(frame.suiTitle, 12)
		end
		if frame.closeButton and frame.closeButton.suiCloseX then
			SoftFont(frame.closeButton.suiCloseX, 11)
		end
	end

	for _, bagFrame in ipairs(B.BagFrames or {}) do
		applyChrome(bagFrame)
	end
	applyChrome(B.BagFrame)
	applyChrome(B.BankFrame)

	if B.SellFrame then
		SoftFont(B.SellFrame.title, 12)
		if B.SellFrame.statusbar then
			SoftFont(B.SellFrame.statusbar.ValueText, 12)
		end
	end

	if B.UpdateCountDisplay then
		B:UpdateCountDisplay()
	end
	if B.UpdateItemLevelDisplay then
		B:UpdateItemLevelDisplay()
	end
end

-- Bags SarychUI chrome — mirrors Talented LayoutMainChrome (never touches NamePlates SetTemplate).
local BAG_FLAT = "Interface\\Buttons\\WHITE8X8"
local BAG_FLAT_BD = {
	bgFile = BAG_FLAT,
	edgeFile = BAG_FLAT,
	tile = false,
	tileSize = 0,
	edgeSize = 1,
	insets = { left = 0, right = 0, top = 0, bottom = 0 },
}
-- Same chrome metrics as Talented_Skin.lua
local TITLE_BAR_H = 28
local TOOLBAR_H = 28
local TOOL_BTN = 22
local BAGS_SCALE_MULT = 0.96
local BAG_TOOLBAR_H = TOOLBAR_H
-- QuestTracker.BLP atlas slices (1024x512) — NOT the ornate filigree header.
-- alt header = clean gold rails with soft side fade; line = thin footer underline.
local DF_BAG_HEADER = [[Interface\AddOns\SarychUI\media\textures\questtracker\QuestTracker.BLP]]
local DF_TEX_W, DF_TEX_H = 1024, 512
local DF_HDR = { l = 36, r = 566, t = 328, b = 376 }   -- clean header; 2px crop off bottom
local DF_LINE = { l = 21, r = 656, t = 384, b = 395 }   -- thin fade underline
local DF_TITLE_BAR_H = 24

local function GetBagsElvuiDb()
	local bagsDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
		and SarychUI.db.profile.modules.bags
	return bagsDb and bagsDb.elvui
end

local function IsDragonflightBagHeaderEnabled()
	local elvui = GetBagsElvuiDb()
	if elvui and elvui.dragonflightHeader ~= nil then
		return elvui.dragonflightHeader and true or false
	end
	local def = SarychUI and SarychUI.defaults and SarychUI.defaults.profile
		and SarychUI.defaults.profile.modules
		and SarychUI.defaults.profile.modules.bags
		and SarychUI.defaults.profile.modules.bags.elvui
	return def and def.dragonflightHeader == true
end

local function GetBagTitleBarH()
	if E.embeddedInSarychUI and IsDragonflightBagHeaderEnabled() then
		return DF_TITLE_BAR_H
	end
	return TITLE_BAR_H
end

-- Extra gap under the toolbar when AdiBags categories are off (classic grid).
local CLASSIC_SLOTS_TOP_PAD = 4

local function GetBagContentTopOffset(frame)
	local base = GetBagTitleBarH() + TOOLBAR_H
	if frame and not frame.isBank and not B:IsAdiBagsSplitMode() then
		return base + CLASSIC_SLOTS_TOP_PAD
	end
	return base
end

local function SetDfSlice(tex, slice)
	tex:SetTexture(DF_BAG_HEADER)
	tex:SetTexCoord(slice.l / DF_TEX_W, slice.r / DF_TEX_W, slice.t / DF_TEX_H, slice.b / DF_TEX_H)
end

local function EnsureDfHeaderLayer(titleBar, key, drawLayer, subLevel)
	local tex = titleBar[key]
	if not tex then
		tex = titleBar:CreateTexture(nil, drawLayer or "ARTWORK")
		if subLevel and tex.SetDrawLayer then
			tex:SetDrawLayer(drawLayer or "ARTWORK", subLevel)
		end
		titleBar[key] = tex
	end
	return tex
end

local function HideDfHeaderLayers(titleBar)
	for _, key in ipairs({ "suiDfGlow", "suiDfHeader", "suiDfLine" }) do
		local tex = titleBar[key]
		if tex then tex:Hide() end
	end
end

local function ApplyDragonflightTitleHeader(titleBar)
	if not titleBar then return end
	if not IsDragonflightBagHeaderEnabled() then
		HideDfHeaderLayers(titleBar)
		return
	end

	-- Fill the title bar edge-to-edge (no empty padding around the strip).
	if titleBar.suiDfGlow then
		titleBar.suiDfGlow:Hide()
	end

	local tex = EnsureDfHeaderLayer(titleBar, "suiDfHeader", "ARTWORK", 2)
	SetDfSlice(tex, DF_HDR)
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 0, 0)
	tex:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", 0, -1)
	tex:SetAlpha(1)
	tex:Show()

	-- Underline belongs on the window footer, not under the title.
	if titleBar.suiDfLine then
		titleBar.suiDfLine:Hide()
		titleBar.suiDfLine:ClearAllPoints()
	end

	-- Hide plate fill/border so only the DF strip shows (no gray gap / seam line).
	if titleBar.SetBackdrop then
		local bd = titleBar:GetBackdrop()
		if bd then
			bd.edgeFile = nil
			bd.edgeSize = 0
			titleBar:SetBackdrop(bd)
		end
	end
	if titleBar.SetBackdropColor then
		titleBar:SetBackdropColor(0, 0, 0, 0)
	end
	if titleBar.SetBackdropBorderColor then
		titleBar:SetBackdropBorderColor(0, 0, 0, 0)
	end
	if not titleBar.suiDfHeaderHooked then
		titleBar.suiDfHeaderHooked = true
		titleBar:HookScript("OnSizeChanged", function(self)
			if self.suiDfHeaderRelayout then return end
			self.suiDfHeaderRelayout = true
			ApplyDragonflightTitleHeader(self)
			self.suiDfHeaderRelayout = nil
		end)
	end
end

-- Thin QuestTracker fade line under the bag/bank toolbar (search + buttons).
local function ApplyDragonflightToolbarLine(toolBar)
	if not toolBar then return end
	local line = toolBar.suiDfToolbarLine
	if not IsDragonflightBagHeaderEnabled() then
		if line then line:Hide() end
		return
	end
	if not line then
		line = toolBar:CreateTexture(nil, "OVERLAY")
		toolBar.suiDfToolbarLine = line
	end
	SetDfSlice(line, DF_LINE)
	line:ClearAllPoints()
	line:SetPoint("BOTTOMLEFT", toolBar, "BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", toolBar, "BOTTOMRIGHT", 0, 0)
	line:SetHeight(2)
	line:SetAlpha(0.5)
	line:Show()
	if not toolBar.suiDfToolbarLineHooked then
		toolBar.suiDfToolbarLineHooked = true
		toolBar:HookScript("OnSizeChanged", function(self)
			if self.suiDfToolbarRelayout then return end
			self.suiDfToolbarRelayout = true
			ApplyDragonflightToolbarLine(self)
			self.suiDfToolbarRelayout = nil
		end)
	end
end

local function Round5(num)
	return math.floor(num * 100000 + 0.5) / 100000
end

local function PixelBestSize()
	local height = GetScreenHeight() or 1080
	if height < 1 then height = 1080 end
	local scale = Round5(768 / height)
	if scale < 0.4 then scale = 0.4 end
	if scale > 1.15 then scale = 1.15 end
	return scale
end

local function GetBagsUIScale()
	if E.global and E.global.general and type(E.global.general.UIScale) == "number" then
		return E.global.general.UIScale
	end
	if ElvDB and ElvDB.global and ElvDB.global.general and type(ElvDB.global.general.UIScale) == "number" then
		return ElvDB.global.general.UIScale
	end
	return PixelBestSize()
end

local function GetBagsTargetUIScale()
	local scale = Round5(GetBagsUIScale() * BAGS_SCALE_MULT)
	if scale < 0.4 then scale = 0.4 end
	if scale > 1.15 then scale = 1.15 end
	return scale
end

local function RawSetScale(frame, scale)
	if not frame then return end
	local mt = getmetatable(frame)
	local idx = mt and mt.__index
	local setScale = type(idx) == "table" and idx.SetScale
	if type(setScale) == "function" then
		setScale(frame, scale)
	end
end

local function ComputeBagsFrameScale()
	local parentScale = UIParent:GetScale() or 1
	if parentScale <= 0 then parentScale = 1 end
	local userScale = 1
	local bagsDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
		and SarychUI.db.profile.modules.bags
	if bagsDb and bagsDb.elvui and type(bagsDb.elvui.scale) == "number" then
		userScale = bagsDb.elvui.scale
	end
	local finalScale = Round5((GetBagsTargetUIScale() / parentScale) * userScale)
	if finalScale < 0.2 then finalScale = 0.2 end
	if finalScale > 3 then finalScale = 3 end
	return finalScale
end

function B:ApplySarychUIBagFrameScale(frame)
	if not E.embeddedInSarychUI or not frame then return end
	if not frame.suiScaleLocked then
		frame.suiScaleLocked = true
		frame.SetScale = function(self)
			RawSetScale(self, ComputeBagsFrameScale())
		end
		frame:HookScript("OnShow", function(self)
			RawSetScale(self, ComputeBagsFrameScale())
		end)
	end
	RawSetScale(frame, ComputeBagsFrameScale())
end

local function GetBagDefaultBorder()
	if E.embeddedInSarychUI then
		local T = SarychUI and SarychUI.OptionsTheme
		local c = T and T.colors and T.colors.border
		if c then return c[1], c[2], c[3], c[4] or 1 end
		return 0.20, 0.20, 0.20, 1
	end
	local bc = E.media and E.media.bordercolor
	if bc then return unpack(bc) end
	return 0, 0, 0, 1
end

function B:GetSarychUIBagHeaderHeight()
	return GetBagTitleBarH()
end

local function ThemeColor(key, fallback)
	local T = SarychUI and SarychUI.OptionsTheme
	local c = T and T.colors and T.colors[key]
	if c then return c end
	return fallback
end

local function ApplyThemePanel(frame, bg, border)
	if not frame or not frame.SetBackdrop then return end
	if frame.iborder then frame.iborder:Hide() end
	if frame.oborder then frame.oborder:Hide() end
	local T = SarychUI and SarychUI.OptionsTheme
	bg = bg or ThemeColor("contentBg", { 0.34, 0.34, 0.34, 0.60 })
	border = border or ThemeColor("border", { 0.20, 0.20, 0.20, 1 })
	if T and T.ApplyFlat then
		T:ApplyFlat(frame, bg, border)
	else
		frame:SetBackdrop(BAG_FLAT_BD)
		frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
		frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	end
end

local function ApplyFlatPlate(frame, bg)
	if not frame or not frame.SetBackdrop then return end
	if frame.iborder then frame.iborder:Hide() end
	if frame.oborder then frame.oborder:Hide() end
	local br, bgc, bb, ba
	if frame.ignoreBorderColors and frame.GetBackdropBorderColor then
		br, bgc, bb, ba = frame:GetBackdropBorderColor()
	end
	local border = ThemeColor("border", { 0.20, 0.20, 0.20, 1 })
	local c = bg or ThemeColor("buttonBg", { 0.28, 0.28, 0.28, 0.75 })
	frame:SetBackdrop(BAG_FLAT_BD)
	frame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
	if br then
		frame:SetBackdropBorderColor(br, bgc, bb, ba or 1)
	else
		frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
	end
end

-- Same close button as Talented SarychUI: 22×22 plate + "X".
function B:SkinSarychUIBagCloseButton(btn, parent)
	if not btn then return end

	if btn.StripTextures then btn:StripTextures() end
	if btn.SetNormalTexture then btn:SetNormalTexture("") end
	if btn.SetPushedTexture then btn:SetPushedTexture("") end
	if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
	if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
	if btn.Texture then btn.Texture:Hide() end

	local T = SarychUI and SarychUI.OptionsTheme
	btn:SetSize(TOOL_BTN - 4, TOOL_BTN - 4)
	btn:SetHitRectInsets(0, 0, 0, 0)
	if parent then
		btn:SetParent(parent)
		btn:ClearAllPoints()
		-- Slightly below bar center: DF header art hangs a bit under the title bar.
		btn:SetPoint("RIGHT", parent, "RIGHT", -GetBagEdgePad(), -1)
		btn:SetFrameLevel((parent:GetFrameLevel() or 0) + 2)
	end

	ApplyThemePanel(btn, ThemeColor("buttonBg", { 0.28, 0.28, 0.28, 0.75 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))

	if not btn.suiCloseX then
		local font = (T and T.fonts and T.fonts.normal) or "GameFontHighlightSmall"
		local x = btn:CreateFontString(nil, "OVERLAY", font)
		x:SetPoint("CENTER", 1, 0)
		x:SetText("X")
		SoftFont(x, 11)
		if T and T.SetTextColor then
			T:SetTextColor(x, "text")
		else
			x:SetTextColor(0.92, 0.92, 0.92, 1)
		end
		btn.suiCloseX = x
	end

	if not btn.suiCloseHoverHooked then
		btn.suiCloseHoverHooked = true
		btn:HookScript("OnEnter", function(self)
			ApplyThemePanel(self, ThemeColor("buttonHover", { 0.42, 0.42, 0.42, 0.88 }), ThemeColor("accent", { 0.95, 0.78, 0.15, 1 }))
		end)
		btn:HookScript("OnLeave", function(self)
			ApplyThemePanel(self, ThemeColor("buttonBg", { 0.28, 0.28, 0.28, 0.75 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
		end)
	end
end

local function SizeToolButton(btn)
	if not btn then return end
	btn:SetSize(TOOL_BTN, TOOL_BTN)
end

-- Talented-style shell: titleBar + toolBar + content (DF header optionally paints title).
function B:LayoutSarychUIBagChrome(f)
	if not E.embeddedInSarychUI or not f then return end

	local T = SarychUI and SarychUI.OptionsTheme
	local titleH = GetBagTitleBarH()
	f.suiHeaderH = titleH
	f.topOffset = GetBagContentTopOffset(f)
	if f.holderFrame then
		local edgePad = GetBagEdgePad()
		f.holderFrame:ClearAllPoints()
		-- Pin left+width so right inset matches toolbar buttons / search (not center-stretch).
		f.holderFrame:Point("TOPLEFT", f, "TOPLEFT", edgePad, -f.topOffset)
		f.holderFrame:Point("BOTTOMLEFT", f, "BOTTOMLEFT", edgePad, 8)
		if f._suiHolderWidth then
			f.holderFrame:Width(f._suiHolderWidth)
		end
	end

	if not f.suiTitleBar then
		local h = CreateFrame("Frame", (f:GetName() or "ElvUIBag").."SuiTitleBar", f)
		f.suiTitleBar = h

		local title = h:CreateFontString(nil, "OVERLAY")
		title:SetJustifyH("CENTER")
		f.suiTitle = title
	end

	if not f.suiToolBar then
		f.suiToolBar = CreateFrame("Frame", (f:GetName() or "ElvUIBag").."SuiToolBar", f)
	end

	local titleBar = f.suiTitleBar
	local toolBar = f.suiToolBar
	local level = (f:GetFrameLevel() or 0) + 6

	-- Drag LMB+RMB; no move-hint tooltip on the title bar
	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton", "RightButton")
	titleBar:SetScript("OnDragStart", function()
		B:SarychUIBagsDragStart(f)
	end)
	titleBar:SetScript("OnDragStop", function()
		B:SarychUIBagsDragStop(f)
	end)
	titleBar:SetScript("OnMouseUp", function(_, button)
		B:HandleBagFrameControlClick(f, button)
	end)
	titleBar:SetScript("OnEnter", nil)
	titleBar:SetScript("OnLeave", nil)
	B:HideBagMoveTooltip()

	titleBar:ClearAllPoints()
	titleBar:SetHeight(titleH)
	titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	titleBar:SetFrameLevel(level)
	ApplyThemePanel(titleBar, ThemeColor("headerBg", { 0.28, 0.28, 0.28, 1 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
	ApplyDragonflightTitleHeader(titleBar)

	if f.suiTitle then
		local locale = GetLocale and GetLocale() or "enUS"
		local titleText
		if f.isBank then
			titleText = (locale == "ruRU") and "Банк" or (L["Bank"] or BANK or "Bank")
		else
			titleText = (locale == "ruRU") and "Сумка" or (L["Bags"] or BACKPACK_TOOLTIP or "Bags")
		end
		-- Same soft title as WatchFrame «Задачи»: no OUTLINE, light shadow.
		SoftFont(f.suiTitle, 12)
		f.suiTitle:SetText(titleText)
		local accent = ThemeColor("accent", ThemeColor("title", { 0.95, 0.78, 0.15, 1 }))
		f.suiTitle:SetTextColor(accent[1], accent[2], accent[3], 1)
		f.suiTitle:ClearAllPoints()
		f.suiTitle:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
	end

	if f.closeButton then
		B:SkinSarychUIBagCloseButton(f.closeButton, titleBar)
	end

	toolBar:ClearAllPoints()
	toolBar:SetHeight(TOOLBAR_H)
	toolBar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
	toolBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
	toolBar:SetFrameLevel(level)
	ApplyThemePanel(toolBar, ThemeColor("contentBg", { 0.34, 0.34, 0.34, 0.60 }), ThemeColor("border", { 0.20, 0.20, 0.20, 1 }))
	-- Keep layout, but strip edgeFile so the top seam border cannot draw.
	if toolBar.SetBackdrop then
		local bd = toolBar:GetBackdrop()
		if bd then
			local bgR, bgG, bgB, bgA = 0.34, 0.34, 0.34, 0.60
			if toolBar.GetBackdropColor then
				bgR, bgG, bgB, bgA = toolBar:GetBackdropColor()
			end
			bd.edgeFile = nil
			bd.edgeSize = 0
			toolBar:SetBackdrop(bd)
			toolBar:SetBackdropColor(bgR, bgG, bgB, bgA or 1)
		end
	end
	if toolBar.SetBackdropBorderColor then
		toolBar:SetBackdropBorderColor(0, 0, 0, 0)
	end

	-- Re-home toolbar controls (Talented: buttons live on toolBar)
	local function adopt(ctrl)
		if ctrl and ctrl.SetParent then
			ctrl:SetParent(toolBar)
			if ctrl.SetFrameLevel then
				ctrl:SetFrameLevel(toolBar:GetFrameLevel() + 2)
			end
		end
	end

	adopt(f.sortButton)
	adopt(f.keyButton)
	adopt(f.bagsButton)
	adopt(f.bankButton)
	adopt(f.vendorGraysButton)
	adopt(f.sectionSplitButton)
	adopt(f.purchaseBagButton)
	adopt(f.editBox)
	if f.bagText then
		f.bagText:Hide()
	end

	SizeToolButton(f.sortButton)
	SizeToolButton(f.keyButton)
	SizeToolButton(f.bagsButton)
	SizeToolButton(f.bankButton)
	SizeToolButton(f.vendorGraysButton)
	SizeToolButton(f.sectionSplitButton)
	SizeToolButton(f.purchaseBagButton)

	local edgePad = GetBagEdgePad()
	local toolBtnTopInset = math.floor((TOOLBAR_H - TOOL_BTN) / 2 + 0.5)
	local rightAnchor = toolBar
	local function placeRight(btn)
		if not btn then return end
		btn:ClearAllPoints()
		if rightAnchor == toolBar then
			-- Same right inset as slots/search: from the bag frame edge, not toolbar border.
			btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -edgePad, -(titleH + toolBtnTopInset))
		else
			btn:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0)
			btn:SetPoint("TOP", rightAnchor, "TOP", 0, 0)
		end
		rightAnchor = btn
	end

	placeRight(f.sortButton)
	placeRight(f.keyButton)
	placeRight(f.bagsButton)
	placeRight(f.bankButton)
	-- Coin actions stay on bags only; bank toolbar does not need Purchase Bags / Vendor Grays.
	if not f.isBank then
		if f.vendorGraysButton then
			f.vendorGraysButton:Show()
		end
		placeRight(f.vendorGraysButton)
		if f.sectionSplitButton then
			f.sectionSplitButton:Show()
			placeRight(f.sectionSplitButton)
			B:UpdateSectionSplitButton(f.sectionSplitButton)
		end
		if f.purchaseBagButton then
			f.purchaseBagButton:Show()
		end
		placeRight(f.purchaseBagButton)
	else
		if f.vendorGraysButton then
			f.vendorGraysButton:Hide()
		end
		if f.sectionSplitButton then
			f.sectionSplitButton:Hide()
		end
		if f.purchaseBagButton then
			f.purchaseBagButton:Hide()
		end
	end

	-- Footer: currencies left, money right.
	if f.goldText or f.currencyButton then
		B:LayoutSarychUIBagFooter(f)
	end

	if f.editBox then
		local searchH = 20
		local searchTopInset = math.floor((TOOLBAR_H - searchH) / 2 + 0.5)
		f.editBox:ClearAllPoints()
		f.editBox:SetPoint("TOPLEFT", f, "TOPLEFT", edgePad, -(titleH + searchTopInset))
		if rightAnchor and rightAnchor ~= toolBar then
			f.editBox:SetPoint("RIGHT", rightAnchor, "LEFT", -edgePad, 0)
		else
			f.editBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -edgePad, -(titleH + searchTopInset))
		end
		B:StyleSarychUIBagSearchBox(f.editBox)
	end

	f.suiChromeHeight = titleH + TOOLBAR_H
	if f.suiDfFooterLine then
		f.suiDfFooterLine:Hide()
	end
	ApplyDragonflightToolbarLine(toolBar)
	B:ApplySarychUIBagFrameScale(f)
end

-- Compact SarychUI search field (options-style plate, no Blizzard magnifier).
function B:StyleSarychUIBagSearchBox(eb)
	if not eb or not E.embeddedInSarychUI then return end

	if eb.searchIcon then
		eb.searchIcon:SetTexture(nil)
		eb.searchIcon:Hide()
	end

	local searchH = 20
	eb:SetHeight(searchH)
	eb:SetTextInsets(8, 8, 0, 0)
	SoftFont(eb, 11)

	local inputBg = ThemeColor("inputBg", { 0.22, 0.22, 0.22, 0.78 })
	local borderSoft = ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 })
	local textDim = ThemeColor("textDim", { 0.65, 0.65, 0.68, 1 })
	local textCol = ThemeColor("text", { 0.92, 0.92, 0.92, 1 })
	local accent = ThemeColor("accent", { 0.95, 0.78, 0.15, 1 })

	if eb.backdrop then
		eb.backdrop:ClearAllPoints()
		eb.backdrop:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0)
		eb.backdrop:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
		if eb.backdrop.iborder then eb.backdrop.iborder:Hide() end
		if eb.backdrop.oborder then eb.backdrop.oborder:Hide() end
		ApplyThemePanel(eb.backdrop, inputBg, borderSoft)
		eb.backdrop:SetFrameLevel(math.max(0, (eb:GetFrameLevel() or 1) - 1))
	end

	local function syncSearchTextColor()
		local t = eb:GetText()
		if not t or t == "" or t == SEARCH then
			eb:SetTextColor(textDim[1], textDim[2], textDim[3], textDim[4] or 1)
		else
			eb:SetTextColor(textCol[1], textCol[2], textCol[3], textCol[4] or 1)
		end
	end

	if not eb.suiSearchStyled then
		eb.suiSearchStyled = true
		eb:HookScript("OnTextChanged", syncSearchTextColor)
		eb:HookScript("OnEditFocusGained", function(self)
			ApplyThemePanel(self.backdrop, inputBg, accent)
			if self:GetText() == SEARCH then
				self:SetText("")
			end
			self:SetTextColor(textCol[1], textCol[2], textCol[3], 1)
		end)
		eb:HookScript("OnEditFocusLost", function(self)
			ApplyThemePanel(self.backdrop, inputBg, borderSoft)
			if self:GetText() == "" then
				self:SetText(SEARCH)
			end
			syncSearchTextColor()
		end)
	else
		if eb.backdrop then
			ApplyThemePanel(eb.backdrop, inputBg, eb:HasFocus() and accent or borderSoft)
		end
	end
	syncSearchTextColor()
end

-- Compat alias used by ConfigureHeaderLayers
function B:EnsureSarychUIBagTitleBar(f)
	B:LayoutSarychUIBagChrome(f)
end

function B:ApplySarychUIBagChrome(frame)
	if not E.embeddedInSarychUI then return end

	local buttonBg = ThemeColor("buttonBg", { 0.28, 0.28, 0.28, 0.75 })
	local panelBg = ThemeColor("panelBg", { 0.32, 0.32, 0.32, 0.55 })
	local contentBg = ThemeColor("contentBg", { 0.34, 0.34, 0.34, 0.60 })
	local bagsDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
		and SarychUI.db.profile.modules.bags
	local elvui = bagsDb and bagsDb.elvui
	local normalAlpha = 0.65
	local categoriesAlpha = 0.85
	if elvui then
		if type(elvui.windowBackgroundAlpha) == "number" then
			normalAlpha = elvui.windowBackgroundAlpha
		end
		if type(elvui.categoriesBackgroundAlpha) == "number" then
			categoriesAlpha = elvui.categoriesBackgroundAlpha
		end
	end

	local function ResolveWindowAlpha(f)
		local useCategories = f and not f.isBank and B:IsAdiBagsSplitMode()
		local windowAlpha = useCategories and categoriesAlpha or normalAlpha
		if windowAlpha < 0 then windowAlpha = 0 end
		if windowAlpha > 1 then windowAlpha = 1 end
		return windowAlpha
	end

	-- Empty slots: Talented tree underlay (ELVUI_TREE_FILL / dark plate)
	local slotBg = { 0.08, 0.08, 0.08, 1 }

	local function restyleFrame(f)
		if not f then return end
		local windowBg = { contentBg[1], contentBg[2], contentBg[3], ResolveWindowAlpha(f) }
		B:LayoutSarychUIBagChrome(f)
		ApplyThemePanel(f, windowBg, ThemeColor("border", { 0.20, 0.20, 0.20, 1 }))
		-- Re-apply title/toolbar after main (main SetBackdrop can affect children visually)
		if f.suiTitleBar then
			ApplyThemePanel(f.suiTitleBar, ThemeColor("headerBg", { 0.28, 0.28, 0.28, 1 }), ThemeColor("borderSoft", { 0.20, 0.20, 0.20, 1 }))
			ApplyDragonflightTitleHeader(f.suiTitleBar)
		end
		if f.suiDfFooterLine then
			f.suiDfFooterLine:Hide()
		end
		if f.suiToolBar then
			ApplyThemePanel(f.suiToolBar, windowBg, ThemeColor("border", { 0.20, 0.20, 0.20, 1 }))
			if f.suiToolBar.SetBackdrop then
				local bd = f.suiToolBar:GetBackdrop()
				if bd then
					local bgR, bgG, bgB, bgA = f.suiToolBar:GetBackdropColor()
					bd.edgeFile = nil
					bd.edgeSize = 0
					f.suiToolBar:SetBackdrop(bd)
					f.suiToolBar:SetBackdropColor(bgR, bgG, bgB, bgA or 1)
				end
			end
			if f.suiToolBar.SetBackdropBorderColor then
				f.suiToolBar:SetBackdropBorderColor(0, 0, 0, 0)
			end
			ApplyDragonflightToolbarLine(f.suiToolBar)
		end
		ApplyThemePanel(f.ContainerHolder, panelBg, ThemeColor("border", { 0.20, 0.20, 0.20, 1 }))
		ApplyThemePanel(f.keyFrame, panelBg, ThemeColor("border", { 0.20, 0.20, 0.20, 1 }))

		for _, btnName in ipairs({
			"sortButton", "bagsButton", "bankButton", "keyButton", "vendorGraysButton", "sectionSplitButton", "purchaseBagButton",
		}) do
			ApplyFlatPlate(f[btnName], buttonBg)
			SizeToolButton(f[btnName])
		end
		if f.sectionSplitButton then
			B:UpdateSectionSplitButton(f.sectionSplitButton)
		end
		if f.editBox then
			B:StyleSarychUIBagSearchBox(f.editBox)
		end
		if f.closeButton and f.suiTitleBar then
			B:SkinSarychUIBagCloseButton(f.closeButton, f.suiTitleBar)
		end
		if f.Bags then
			for _, bag in pairs(f.Bags) do
				if type(bag) == "table" then
					for slotID = 1, #bag do
						ApplyFlatPlate(bag[slotID], slotBg)
					end
				end
			end
		end
		if f.ContainerHolder then
			for i = 1, #f.ContainerHolder do
				ApplyFlatPlate(f.ContainerHolder[i], slotBg)
			end
		end
		if f.keyFrame and f.keyFrame.slots then
			for i = 1, #f.keyFrame.slots do
				ApplyFlatPlate(f.keyFrame.slots[i], slotBg)
			end
		end
	end

	if frame then
		restyleFrame(frame)
		return
	end
	for _, f in ipairs(B.BagFrames or {}) do
		restyleFrame(f)
	end
	if B.BagFrame then restyleFrame(B.BagFrame) end
	if B.BankFrame then restyleFrame(B.BankFrame) end
	if B.SellFrame and B.SellFrame.backdrop then
		local sellBg = { contentBg[1], contentBg[2], contentBg[3], normalAlpha }
		ApplyThemePanel(B.SellFrame.backdrop, sellBg, ThemeColor("border", { 0.20, 0.20, 0.20, 1 }))
	end
end

function B:ApplyBagFont()
	B:ApplyBagWindowFonts()
	B:ApplyMoveTooltipFonts()
end

function B:EnsureMoveTooltipStyled()
	if MoveTooltip._elvBagsMoveStyled then return end

	if E.embeddedInSarychUI and MoveTooltip.SetBackdrop then
		local T = SarychUI and SarychUI.OptionsTheme
		local bg = (T and T.colors and T.colors.panelBg) or { 0.32, 0.32, 0.32, 0.55 }
		local border = (T and T.colors and T.colors.border) or { 0.20, 0.20, 0.20, 1 }
		if T and T.ApplyFlat then
			T:ApplyFlat(MoveTooltip, bg, border)
		else
			MoveTooltip:SetBackdrop(BAG_FLAT_BD)
			MoveTooltip:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
			MoveTooltip:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
		end
	elseif MoveTooltip.SetTemplate then
		MoveTooltip:SetTemplate("Transparent")
		local fade = E.media and E.media.backdropfadecolor
		if fade and MoveTooltip.SetBackdropColor then
			local alpha = (E.db and E.db.tooltip and E.db.tooltip.colorAlpha) or fade[4] or 0.8
			MoveTooltip:SetBackdropColor(fade[1], fade[2], fade[3], alpha)
		end
	end

	MoveTooltip._elvBagsMoveStyled = true
	moveTooltipDebug("move tooltip styled (isolated frame)")
end

function B:ShowBagMoveTooltip(owner)
	if not owner then return end

	moveTooltipDebug("move tooltip show", "owner=", owner.GetName and owner:GetName() or owner)

	B:EnsureMoveTooltipStyled()
	B._moveTooltipOwner = owner

	MoveTooltip:SetOwner(owner, "ANCHOR_TOPLEFT", 0, 4)
	MoveTooltip:ClearLines()
	if E.embeddedInSarychUI then
		MoveTooltip:AddDoubleLine(L["Hold Right Button + Drag:"], L["Move Window"], 1, 1, 1)
		MoveTooltip:AddDoubleLine(L["Hold Control + Right Click:"], L["Reset Position"], 1, 1, 1)
	else
		MoveTooltip:AddDoubleLine(L["Hold Shift + Drag:"], L["Temporary Move"], 1, 1, 1)
		MoveTooltip:AddDoubleLine(L["Hold Control + Right Click:"], L["Reset Position"], 1, 1, 1)
	end
	B:ApplyMoveTooltipFonts()
	MoveTooltip:Show()
end

function B:GetSarychUIBagFrameStrata()
	if E.embeddedInSarychUI then
		return "MEDIUM"
	end
	return E.db.bags.strata or "DIALOG"
end

function B:ApplySarychUIBagFrameLayers(frame)
	if not E.embeddedInSarychUI or not frame then return end
	local strata = B:GetSarychUIBagFrameStrata()
	frame:SetFrameStrata(strata)
	bagsDragDebug("frame layers", FrameDebugName(frame), strata, frame.GetFrameLevel and frame:GetFrameLevel() or "?")
end

function B:SarychUIBagsDragStart(frame)
	if not frame then return end
	bagsDragDebug("drag start", FrameDebugName(frame), frame.isBank and "bank" or "bag")
	frame:StartMoving()
end

function B:SarychUIBagsDragStop(frame)
	if not frame then return end
	frame:StopMovingOrSizing()
	bagsDragDebug("drag stop", FrameDebugName(frame), frame.isBank and "bank" or "bag")
	B.OnElvUIBagFrameDragStop(frame)
end

function B:SetupSarychUIBagFrameDrag(f)
	if not f or not f.dragHeader then return end

	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForClicks("AnyUp")
	f:SetScript("OnClick", function(frame, button)
		B:HandleBagFrameControlClick(frame, button)
	end)

	f.dragHeader:EnableMouse(true)
	f.dragHeader:RegisterForDrag("LeftButton", "RightButton")
	f.dragHeader:SetScript("OnDragStart", function()
		B:SarychUIBagsDragStart(f)
	end)
	f.dragHeader:SetScript("OnDragStop", function()
		B:SarychUIBagsDragStop(f)
	end)
	f.dragHeader:SetScript("OnMouseUp", function(_, button)
		B:HandleBagFrameControlClick(f, button)
	end)
	f.dragHeader:SetScript("OnEnter", nil)
	f.dragHeader:SetScript("OnLeave", nil)

	bagsDragDebug("drag handlers attached", f:GetName(), f.isBank and "bank" or "bag")
end

function B:HandleBagFrameControlClick(frame, button)
	if not frame or not IsControlKeyDown() or button ~= "RightButton" then return end

	if E.embeddedInSarychUI and frame.isBank then
		B:ClearElvUIBankSavedWindowPosition()
		B:ApplyElvUIBankWindowPosition(frame)
		return
	end

	if E.embeddedInSarychUI and not frame.isBank then
		B:ClearElvUIBagSavedWindowPosition()
		B:ApplyElvUIBagWindowPosition(frame)
		return
	end

	if not frame.mover then return end

	if frame.mover.textString and E.ResetMovers then
		E:ResetMovers(frame.mover.textString)
	end

	B.PostBagMove(frame.mover)
end

function B:HideBagMoveTooltip()
	moveTooltipDebug("move tooltip hide")

	if MoveTooltip:IsShown() then
		MoveTooltip:Hide()
	end

	B._moveTooltipOwner = nil
end

function B:ConfigureHeaderLayers(f)
	if not f or not f.dragHeader then return end

	if E.embeddedInSarychUI then
		B:LayoutSarychUIBagChrome(f)
	end

	f.dragHeader:ClearAllPoints()
	if E.embeddedInSarychUI and f.suiToolBar then
		-- Invisible hit area over the toolbar (title bar has its own drag)
		f.dragHeader:SetParent(f.suiToolBar)
		f.dragHeader:SetAllPoints(f.suiToolBar)
		f.dragHeader:SetFrameLevel((f.suiToolBar:GetFrameLevel() or 0) + 1)
	else
		f.dragHeader:Point("TOPLEFT", f, "TOPLEFT", 4, -4)
		f.dragHeader:Point("BOTTOMRIGHT", f.holderFrame, "TOPRIGHT", -4, 4)
		f.dragHeader:SetFrameLevel(f:GetFrameLevel() + 1)
	end

	local headerLevel = (f.suiToolBar and (f.suiToolBar:GetFrameLevel() + 3)) or (f.dragHeader:GetFrameLevel() + 25)
	local controls = {
		f.sortButton,
		f.keyButton,
		f.bagsButton,
		f.vendorGraysButton,
		f.sectionSplitButton,
		f.purchaseBagButton,
		f.editBox,
		f.bagText,
		f.goldText,
	}

	for _, ctrl in ipairs(controls) do
		if ctrl and ctrl.SetFrameLevel then
			ctrl:SetFrameLevel(headerLevel)
		end
	end

	if f.closeButton then
		if E.embeddedInSarychUI and f.suiTitleBar then
			f.closeButton:SetFrameLevel((f.suiTitleBar:GetFrameLevel() or 0) + 2)
		else
			f.closeButton:SetFrameLevel(headerLevel + 10)
		end
		f.closeButton:EnableMouse(true)
	end

	local hookHide = {
		f.sortButton,
		f.keyButton,
		f.bagsButton,
		f.vendorGraysButton,
		f.sectionSplitButton,
		f.purchaseBagButton,
	}

	for _, btn in ipairs(hookHide) do
		if btn and not btn._elvBagsMoveTooltipHooked then
			btn._elvBagsMoveTooltipHooked = true
			btn:HookScript("OnEnter", B.HideBagMoveTooltip)
		end
	end

	if f.editBox and not f.editBox._elvBagsMoveTooltipHooked then
		f.editBox._elvBagsMoveTooltipHooked = true
		f.editBox:HookScript("OnEnter", B.HideBagMoveTooltip)
	end
end

local function EnsureButtonTexture(btn, getterName, setterName, texPath)
	local getter, setter = btn[getterName], btn[setterName]
	if not getter or not setter or not texPath then return end

	setter(btn, texPath)
	local tex = getter(btn)
	if not tex then
		tex = btn:CreateTexture(nil, "ARTWORK")
		setter(btn, tex)
		tex:SetTexture(texPath)
	end

	if tex then
		tex:SetTexCoord(unpack(E.TexCoords))
		if tex.SetInside then
			tex:SetInside()
		end
	end

	return tex
end

local function SetupIconButton(btn, texPath, includeDisabled)
	EnsureButtonTexture(btn, "GetNormalTexture", "SetNormalTexture", texPath)
	EnsureButtonTexture(btn, "GetPushedTexture", "SetPushedTexture", texPath)

	if includeDisabled then
		local disabled = EnsureButtonTexture(btn, "GetDisabledTexture", "SetDisabledTexture", texPath)
		if disabled and disabled.SetDesaturated then
			disabled:SetDesaturated(true)
		end
	end
end

function B:UseDefaultBagPosition()
	return false
end

function B:ClearSortSpinnerFailsafe(f)
	if not f then return end
	f._spinnerFailsafeToken = (f._spinnerFailsafeToken or 0) + 1
	f._spinnerFailsafeTimer = nil
end

function B:StartSortSpinner(f)
	if not f or not f.holderFrame then return end
	B:ClearSortSpinnerFailsafe(f)
	local token = f._spinnerFailsafeToken
	E:StartSpinnerFrame(f.holderFrame)
	E:Delay(3, function()
		if not f or f._spinnerFailsafeToken ~= token then return end
		if B.SortUpdateTimer and B.SortUpdateTimer.IsShown and B.SortUpdateTimer:IsShown() then return end
		B:ScheduleSortSlotRefresh(f)
	end)
	sortElvDebug("spinner show")
end

function B:StopSortSpinner(f)
	if not f or not f.holderFrame then return end
	B:ClearSortSpinnerFailsafe(f)
	E:StopSpinnerFrame(f.holderFrame)
	sortElvDebug("spinner hide")
end

function B:HandleSortButtonClick(f, sortGroup)
	if not f then return end

	local isBank = sortGroup == "bank"
	sortElvDebug("button clicked")
	sortElvDebug("using original ElvUI sort")

	if isBank and E.embeddedInSarychUI and not B.bankIsOpen then
		return
	end
	if isBank and E.db.bags.disableBankSort then
		return
	end
	if not isBank and B:IsBagSortHidden() then
		return
	end
	if B.SortUpdateTimer and B.SortUpdateTimer.IsShown and B.SortUpdateTimer:IsShown() then
		return
	end

	-- ElvUI/Modules/Bags/Bags.lua sortButton OnClick
	f:UnregisterAllEvents()
	if not f.registerUpdate then
		B:SortingFadeBags(f, true)
	end

	B:StartSortSpinner(f)
	B:CommandDecorator(B.SortBags, sortGroup)()
	if not (B.SortUpdateTimer and B.SortUpdateTimer.IsShown and B.SortUpdateTimer:IsShown()) then
		B:ScheduleSortSlotRefresh(f)
	end
end

function B:GetSarychUIBagsModuleDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules then
		return SarychUI.db.profile.modules.bags
	end
	return nil
end

function B:NormalizeBagPosition(pos)
	if type(pos) ~= "table" then return end
	local point = pos.point
	if type(point) ~= "string" or point == "" then return end

	return {
		point = point,
		relativePoint = (type(pos.relativePoint) == "string" and pos.relativePoint ~= "") and pos.relativePoint or point,
		relativeTo = (type(pos.relativeTo) == "string" and pos.relativeTo ~= "") and pos.relativeTo or "UIParent",
		x = tonumber(pos.x) or BAG_POSITION_FALLBACK.x,
		y = tonumber(pos.y) or BAG_POSITION_FALLBACK.y,
	}
end

function B:EnsureElvUISettingsTable()
	local bagsDb = B:GetSarychUIBagsModuleDB()
	if not bagsDb then return end

	bagsDb.elvui = bagsDb.elvui or {}
	if type(bagsDb.elvui.defaultPosition) ~= "table" then
		local defaults
		if SarychUI and SarychUI.defaults and SarychUI.defaults.profile.modules.bags
			and SarychUI.defaults.profile.modules.bags.elvui
			and type(SarychUI.defaults.profile.modules.bags.elvui.defaultPosition) == "table" then
			defaults = CopyTable(SarychUI.defaults.profile.modules.bags.elvui.defaultPosition)
		end
		bagsDb.elvui.defaultPosition = B:NormalizeBagPosition(defaults) or CopyTable(BAG_POSITION_FALLBACK)
	end
	if type(bagsDb.elvui.defaultBankPosition) ~= "table" then
		local bankDefaults
		if SarychUI and SarychUI.defaults and SarychUI.defaults.profile.modules.bags
			and SarychUI.defaults.profile.modules.bags.elvui
			and type(SarychUI.defaults.profile.modules.bags.elvui.defaultBankPosition) == "table" then
			bankDefaults = CopyTable(SarychUI.defaults.profile.modules.bags.elvui.defaultBankPosition)
		end
		bagsDb.elvui.defaultBankPosition = B:NormalizeBagPosition(bankDefaults) or CopyTable(BANK_POSITION_FALLBACK)
	end

	return bagsDb.elvui
end

function B:GetElvUIBagPositionConfig()
	local elvui = B:EnsureElvUISettingsTable()
	if not elvui then return end

	local defaultPos = B:NormalizeBagPosition(elvui.defaultPosition) or CopyTable(BAG_POSITION_FALLBACK)
	local savedPos = B:NormalizeBagPosition(elvui.savedWindowPosition)
	return defaultPos, savedPos
end

function B:ResolveBagPositionAnchor(relativeToName)
	if not relativeToName or relativeToName == "UIParent" then
		return UIParent
	end
	local frame = _G[relativeToName]
	if not frame and relativeToName == "ElvUI_ContainerFrame" and B.BagFrame then
		frame = B.BagFrame
	end
	return frame or UIParent
end

function B:SaveElvUIBagWindowPosition(frame)
	if not E.embeddedInSarychUI or not frame or frame.isBank then return end

	local bagsDb = B:GetSarychUIBagsModuleDB()
	if not bagsDb then return end

	bagsDb.elvui = bagsDb.elvui or {}
	local point, anchor, relativePoint, x, y = frame:GetPoint()
	if not point then return end

	local anchorName = "UIParent"
	if anchor and anchor.GetName then
		anchorName = anchor:GetName() or "UIParent"
	end

	bagsDb.elvui.savedWindowPosition = {
		point = point,
		relativePoint = relativePoint or point,
		relativeTo = anchorName,
		x = E:Round(x or 0),
		y = E:Round(y or 0),
	}
	positionDebug("Saved bag position", frame)
end

function B:ClearElvUIBagSavedWindowPosition()
	local bagsDb = B:GetSarychUIBagsModuleDB()
	if bagsDb and bagsDb.elvui then
		bagsDb.elvui.savedWindowPosition = nil
	end
end

function B:GetElvUIBankPositionConfig()
	local elvui = B:EnsureElvUISettingsTable()
	if not elvui then return end

	local defaultPos = B:NormalizeBagPosition(elvui.defaultBankPosition) or CopyTable(BANK_POSITION_FALLBACK)
	local savedPos = B:NormalizeBagPosition(elvui.savedBankWindowPosition)
	return defaultPos, savedPos
end

function B:SaveElvUIBankWindowPosition(frame)
	if not E.embeddedInSarychUI or not frame or not frame.isBank then return end

	local bagsDb = B:GetSarychUIBagsModuleDB()
	if not bagsDb then return end

	bagsDb.elvui = bagsDb.elvui or {}
	local point, anchor, relativePoint, x, y = frame:GetPoint()
	if not point then return end

	local anchorName = "UIParent"
	if anchor and anchor.GetName then
		anchorName = anchor:GetName() or "UIParent"
	end

	bagsDb.elvui.savedBankWindowPosition = {
		point = point,
		relativePoint = relativePoint or point,
		relativeTo = anchorName,
		x = E:Round(x or 0),
		y = E:Round(y or 0),
	}
	positionDebug("Saved bank position", frame)
end

function B:ClearElvUIBankSavedWindowPosition()
	local bagsDb = B:GetSarychUIBagsModuleDB()
	if bagsDb and bagsDb.elvui then
		bagsDb.elvui.savedBankWindowPosition = nil
	end
end

function B:ApplyElvUIBagWindowPosition(frame)
	frame = frame or B.BagFrame
	if not E.embeddedInSarychUI or not frame or frame.isBank then return end

	B:ApplySarychUIBagFrameLayers(frame)

	local defaultPos, savedPos = B:GetElvUIBagPositionConfig()
	local pos = savedPos or defaultPos or BAG_POSITION_FALLBACK
	if not pos or not pos.point then
		pos = BAG_POSITION_FALLBACK
	end

	local relativeTo = B:ResolveBagPositionAnchor(pos.relativeTo)
	frame:ClearAllPoints()
	frame:Point(pos.point, relativeTo, pos.relativePoint, pos.x, pos.y)
	frame._sarychCustomPosition = savedPos ~= nil
	frame.mover = nil
	positionDebug("Applied bag position", frame, pos)
end

function B:ApplyElvUIBankWindowPosition(frame)
	frame = frame or B.BankFrame
	if not E.embeddedInSarychUI or not frame or not frame.isBank then return end

	B:ApplySarychUIBagFrameLayers(frame)

	local defaultPos, savedPos = B:GetElvUIBankPositionConfig()
	local pos = savedPos or defaultPos or BANK_POSITION_FALLBACK
	if not pos or not pos.point then
		pos = BANK_POSITION_FALLBACK
	end

	local relativeTo = B:ResolveBagPositionAnchor(pos.relativeTo)
	frame:ClearAllPoints()
	frame:Point(pos.point, relativeTo, pos.relativePoint, pos.x, pos.y)
	frame._sarychCustomPosition = savedPos ~= nil
	frame.mover = nil
	positionDebug("Applied bank position", frame, pos)
end

function B.OnElvUIBagFrameDragStop(frame)
	frame:StopMovingOrSizing()
	if E.embeddedInSarychUI and frame then
		if frame.isBank then
			B:SaveElvUIBankWindowPosition(frame)
		else
			B:SaveElvUIBagWindowPosition(frame)
		end
	end
end

function B:IsBagSortHidden()
	if E.embeddedInSarychUI then return false end
	return E.db.bags.disableBagSort
end

function B:ApplyDefaultBagPosition(frame, isBank)
	if not frame then return end

	frame:ClearAllPoints()

	if isBank then
		if B.BagFrame and B.BagFrame:IsShown() then
			frame:Point("BOTTOMRIGHT", B.BagFrame, "BOTTOMLEFT", -(CONTAINER_SPACING or 10), 0)
			bagDebug("Apply default bank position (left of bags)")
			return
		end

		if B._defaultBankAnchor then
			local a = B._defaultBankAnchor
			frame:Point(a[1], a[2], a[3], a[4], a[5])
			bagDebug("Apply default bank position (cached)")
			return
		end

		local bankRef = _G.BankFrame
		if bankRef and bankRef.GetPoint then
			local point, anchor, secondary, x, y = bankRef:GetPoint()
			if point and anchor then
				B._defaultBankAnchor = { point, anchor, secondary or point, x or 0, y or 0 }
				frame:Point(point, anchor, secondary or point, x or 0, y or 0)
				bagDebug("Apply default bank position from BankFrame")
				return
			end
		end

		frame:Point("BOTTOMLEFT", UIParent, "BOTTOMLEFT", CONTAINER_OFFSET_X or 9, CONTAINER_OFFSET_Y or 80)
		bagDebug("Apply default bank position fallback")
		return
	end

	if B._defaultBagAnchor then
		local a = B._defaultBagAnchor
		frame:Point(a[1], a[2], a[3], a[4], a[5])
		bagDebug("Apply default bag position (cached)")
		return
	end

	local bagRef = _G.ContainerFrame1
	if bagRef and bagRef.GetPoint then
		local point, anchor, secondary, x, y = bagRef:GetPoint()
		if point and anchor then
			B._defaultBagAnchor = { point, anchor, secondary or point, x or 0, y or 0 }
			frame:Point(point, anchor, secondary or point, x or 0, y or 0)
			bagDebug("Apply default bag position")
			return
		end
	end

	B._defaultBagAnchor = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", CONTAINER_OFFSET_X or -9, CONTAINER_OFFSET_Y or 80 }
	frame:Point(unpack(B._defaultBagAnchor))
	bagDebug("Apply default bag position fallback")
end

function B:GetContainerFrame(arg)
	if type(arg) == "boolean" and arg == true then
		return B.BankFrame
	elseif type(arg) == "number" then
		if B.BankFrame then
			for _, bagID in ipairs(B.BankFrame.BagIDs) do
				if bagID == arg then
					return B.BankFrame
				end
			end
		end
	end

	return B.BagFrame
end

function B:Tooltip_Show()
	GameTooltip:SetOwner(self)
	GameTooltip:ClearLines()
	GameTooltip:AddLine(self.ttText)

	if self.ttText2 then
		if self.ttText2desc then
			GameTooltip:AddLine(" ")
			GameTooltip:AddDoubleLine(self.ttText2, self.ttText2desc, 1, 1, 1)
		else
			GameTooltip:AddLine(self.ttText2)
		end
	end

	GameTooltip:Show()
end

function B:DisableBlizzard()
	-- BaudBag-style: unregister + swallow BankFrame_OnEvent so ShowUIPanel(BankFrame)
	-- never runs. Do NOT Hide() a shown BankFrame here — BankFrame_OnHide calls CloseBankFrame().
	BankFrame:UnregisterAllEvents()
	if not BankFrame:IsShown() then
		BankFrame:Hide()
	end

	if not B._blizzardBankSuppressed then
		B._blizzardBankSuppressed = true
		B._origBankFrame_OnEvent = BankFrame_OnEvent
		BankFrame_OnEvent = function(self, event, ...)
			if not (E.private and E.private.bags and E.private.bags.enable) then
				if B._origBankFrame_OnEvent then
					return B._origBankFrame_OnEvent(self, event, ...)
				end
				return
			end
			-- Swallow while SarychUI bags own the bank UI.
		end
	end

	for i = 1, NUM_CONTAINER_FRAMES do
		_G["ContainerFrame"..i]:Kill()
	end
end

function B:RestoreBlizzard()
	if self.hooksInstalled then
		self:UnhookAll()
		self.hooksInstalled = nil
	end

	if B._blizzardBankSuppressed and B._origBankFrame_OnEvent then
		BankFrame_OnEvent = B._origBankFrame_OnEvent
		B._origBankFrame_OnEvent = nil
		B._blizzardBankSuppressed = nil
	end

	BankFrame:RegisterEvent("BANKFRAME_OPENED")
	BankFrame:RegisterEvent("BANKFRAME_CLOSED")
end

function B:RestoreActionBarBagButtons()
	if not E.embeddedInSarychUI then return end

	-- SarychUI owns action bar bag buttons; never touch their parent/position/visibility.
	local noop = E.noop
	local protectedButtons = {
		"MainMenuBarBackpackButton",
		"CharacterBag0Slot",
		"CharacterBag1Slot",
		"CharacterBag2Slot",
		"CharacterBag3Slot",
		"KeyRingButton",
	}

	local function restoreSetParentMethod(frame)
		if not frame or frame.SetParent ~= noop then return end
		local ref = CreateFrame("CheckButton")
		local mt = getmetatable(frame)
		if mt and mt.__index and mt.__index.SetParent then
			frame.SetParent = mt.__index.SetParent
		else
			frame.SetParent = ref.SetParent
		end
	end

	for _, name in ipairs(protectedButtons) do
		restoreSetParentMethod(_G[name])
	end

	if _G.ElvUIBags then
		_G.ElvUIBags:Hide()
	end
	if _G.ElvUIKeyRingButton then
		_G.ElvUIKeyRingButton:Hide()
	end

	bagDebug("Skipped action bar bag button layout (SarychUI manages bar buttons)")
end

function B:IsElvUIBagsActive()
	if E.embeddedInSarychUI then
		return E:IsBagsRuntimeEnabled()
	end
	return E.private and E.private.bags and E.private.bags.enable
end

-- MainMenuBarBagButtons.lua: checked follows visible ContainerFrames.
-- ElvUI uses one unified window, so all bag bar buttons share one open/closed state.
function B:UpdateBlizzardBagButtonCheckedState()
	if not self:IsElvUIBagsActive() then return end

	local isOpen = B.BagFrame and B.BagFrame:IsShown()
	buttonDebug("Update checked state once", "unified shown=", tostring(isOpen))

	for _, name in ipairs(BAG_BAR_BUTTONS) do
		local button = _G[name]
		if button and button.SetChecked then
			button:SetChecked(isOpen)
		end
	end

	if ElvUIBags and ElvUIBags.buttons then
		for _, bagButton in pairs(ElvUIBags.buttons) do
			if bagButton.SetChecked then
				bagButton:SetChecked(isOpen)
			end
		end
	end
end

function B:OnBagSlotButtonUpdateChecked()
	if not self:IsElvUIBagsActive() then return end
	self:UpdateBlizzardBagButtonCheckedState()
end

function B:OnBackpackButtonUpdateChecked()
	if not self:IsElvUIBagsActive() then return end
	self:UpdateBlizzardBagButtonCheckedState()
end

function B:SearchReset()
	SEARCH_STRING = ""
end

function B:IsSearching()
	return SEARCH_STRING ~= "" and SEARCH_STRING ~= SEARCH
end

function B:UpdateSearch()
	local search = self:GetText()
	if self.Instructions then
		self.Instructions:SetShown(search == "")
	end

	local MIN_REPEAT_CHARACTERS = 3
	local prevSearch = SEARCH_STRING
	if #search > MIN_REPEAT_CHARACTERS then
		local repeatChar = true
		for i = 1, MIN_REPEAT_CHARACTERS, 1 do
			if sub(search,(0 - i), (0 - i)) ~= sub(search,(-1 - i),(-1 - i)) then
				repeatChar = false
				break
			end
		end

		if repeatChar then
			B:ResetAndClear()
			return
		end
	end

	--Keep active search term when switching between bank and reagent bank
	if search == SEARCH and prevSearch ~= "" then
		search = prevSearch
	elseif search == SEARCH then
		search = ""
	end

	SEARCH_STRING = search

	B:RefreshSearch()
	B:SetGuildBankSearch(SEARCH_STRING)
end

function B:OpenEditbox()
	B.BagFrame.detail:Hide()
	B.BagFrame.editBox:Show()
	B.BagFrame.editBox:SetText(SEARCH)
	B.BagFrame.editBox:HighlightText()
end

function B:ResetAndClear()
	B.BagFrame.editBox:SetText(SEARCH)
	B.BagFrame.editBox:ClearFocus()

	if B.BankFrame then
		B.BankFrame.editBox:SetText(SEARCH)
		B.BankFrame.editBox:ClearFocus()
	end

	B:SearchReset()
end

function B:SetSearch(query)
	local empty = (gsub(query, "%s+", "")) == ""

	for _, bagFrame in pairs(B.BagFrames) do
		if bagFrame.BagIDs and bagFrame.Bags then
			for _, bagID in ipairs(bagFrame.BagIDs) do
				local bag = bagFrame.Bags[bagID]
				if bag then
					for slotID = 1, GetContainerNumSlots(bagID) do
						local _, _, _, _, _, _, link = GetContainerItemInfo(bagID, slotID)
						local button = bag[slotID]
						if button then
							local success, result = pcall(Search.Matches, Search, link, query)

							if empty or (success and result) then
								SetItemButtonDesaturated(button, button.locked or button.junkDesaturate)
								button.searchOverlay:Hide()
								button:SetAlpha(1)
							else
								SetItemButtonDesaturated(button, 1)
								button.searchOverlay:Show()
								button:SetAlpha(0.5)
							end
						end
					end
				end
			end
		end
	end

	if ElvUIKeyFrameItem1 then
		local numKey = GetKeyRingSize()
		for slotID = 1, numKey do
			local button = _G["ElvUIKeyFrameItem"..slotID]
			if button then
				local _, _, _, _, _, _, link = GetContainerItemInfo(KEYRING_CONTAINER, slotID)
				local success, result = pcall(Search.Matches, Search, link, query)
				if empty or (success and result) then
					SetItemButtonDesaturated(button, button.locked or button.junkDesaturate)
					button.searchOverlay:Hide()
					button:SetAlpha(1)
				else
					SetItemButtonDesaturated(button, 1)
					button.searchOverlay:Show()
					button:SetAlpha(0.5)
				end
			end
		end
	end
end

function B:SetGuildBankSearch(query)
	if GuildBankFrame and GuildBankFrame:IsShown() then
		local tab = GetCurrentGuildBankTab()
		local _, _, isViewable = GetGuildBankTabInfo(tab)

		if isViewable then
			local empty = (gsub(query, "%s+", "")) == ""

			for slotID = 1, MAX_GUILDBANK_SLOTS_PER_TAB do
				local link = GetGuildBankItemLink(tab, slotID)
				--A column goes from 1-14, e.g. GuildBankColumn1Button14 (slotID 14) or GuildBankColumn2Button3 (slotID 17)
				local col = ceil(slotID / 14)
				local btn = (slotID % 14)
				if col == 0 then col = 1 end
				if btn == 0 then btn = 14 end

				local button = _G["GuildBankColumn"..col.."Button"..btn]
				local success, result = pcall(Search.Matches, Search, link, query)

				if empty or (success and result) then
					SetItemButtonDesaturated(button, button.locked or button.junkDesaturate)
					button:SetAlpha(1)
				else
					SetItemButtonDesaturated(button, 1)
					button:SetAlpha(0.5)
				end
			end
		end
	end
end

function B:UpdateItemLevelDisplay()
	if not E.private.bags.enable then return end
	if not B.BagFrames then return end

	local font = E.Libs.LSM:Fetch("font", E.db.bags.itemLevelFont)
	local itemLevelSize = E.embeddedInSarychUI and B:GetItemLevelFontSize() or E.db.bags.itemLevelFontSize

	for _, bagFrame in pairs(B.BagFrames) do
		if bagFrame.BagIDs and bagFrame.Bags then
			for _, bagID in ipairs(bagFrame.BagIDs) do
				local bag = bagFrame.Bags[bagID]
				if bag then
					for slotID = 1, GetContainerNumSlots(bagID) do
						local slot = bag[slotID]
						if slot and slot.itemLevel then
							if E.embeddedInSarychUI then
								B:ApplySlotTextFont(slot.itemLevel, itemLevelSize)
							else
								slot.itemLevel:FontTemplate(font, itemLevelSize, E.db.bags.itemLevelFontOutline)
							end
						end
						if slot and slot.bindType then
							if E.embeddedInSarychUI then
								B:ApplySlotTextFont(slot.bindType, itemLevelSize)
							else
								slot.bindType:FontTemplate(font, itemLevelSize, E.db.bags.itemLevelFontOutline)
							end
						end
					end
				end
			end
		end

		B:UpdateAllSlots(bagFrame)
	end
end

function B:UpdateCountDisplay()
	if not E.private.bags.enable then return end
	if not B.BagFrames then return end

	local font = E.Libs.LSM:Fetch("font", E.db.bags.countFont)
	local color = E.db.bags.countFontColor
	local countSize = E.embeddedInSarychUI and B:GetStackFontSize() or E.db.bags.countFontSize

	for _, bagFrame in pairs(B.BagFrames) do
		if bagFrame.BagIDs and bagFrame.Bags then
			for _, bagID in ipairs(bagFrame.BagIDs) do
				local bag = bagFrame.Bags[bagID]
				if bag then
					for slotID = 1, GetContainerNumSlots(bagID) do
						local slot = bag[slotID]
						if slot and slot.Count then
							if E.embeddedInSarychUI then
								B:ApplySlotTextFont(slot.Count, countSize)
							else
								slot.Count:FontTemplate(font, countSize, E.db.bags.countFontOutline)
							end
							slot.Count:SetTextColor(color.r, color.g, color.b)
						end
					end
				end
			end
		end

		B:UpdateAllSlots(bagFrame)
	end

	--Keyring
	if ElvUIKeyFrameItem1 then
		for i = 1, GetKeyRingSize() do
			local slot = _G["ElvUIKeyFrameItem"..i]
			if slot then
				if E.embeddedInSarychUI then
					B:ApplySlotTextFont(slot.Count, countSize)
				else
					slot.Count:FontTemplate(font, countSize, E.db.bags.countFontOutline)
				end
				slot.Count:SetTextColor(color.r, color.g, color.b)
				B:UpdateKeySlot(i)
			end
		end
	end
end

function B:UpdateAllBagSlots()
	if not E.private.bags.enable then return end
	if not B.BagFrames then return end

	for _, bagFrame in pairs(B.BagFrames) do
		B:UpdateAllSlots(bagFrame)
	end
end

function B:UpdateSlot(frame, bagID, slotID)
	if not (frame and frame.Bags) then return end
	if (frame.Bags[bagID] and frame.Bags[bagID].numSlots ~= GetContainerNumSlots(bagID)) or not frame.Bags[bagID] or not frame.Bags[bagID][slotID] then return end

	local slot = frame.Bags[bagID][slotID]
	local bagType = frame.Bags[bagID].type
	local useCache = E.embeddedInSarychUI and frame.isBank and not B.bankIsOpen
	local texture, count, locked, readable, clink

	if useCache then
		local entry = B:GetCachedBankSlot(bagID, slotID)
		slot.cachedLink = entry and entry.Link or nil
		if entry and entry.Link then
			clink = entry.Link
			count = entry.Count or 1
			texture = select(10, GetItemInfo(clink))
		end
		locked, readable = nil, nil
	else
		slot.cachedLink = nil
		texture, count, locked, _, readable = GetContainerItemInfo(bagID, slotID)
		clink = GetContainerItemLink(bagID, slotID)
	end

	slot.name, slot.rarity, slot.locked, slot.readable, slot.isJunk, slot.junkDesaturate = nil, nil, locked, readable, nil, nil

	B:EnsureSlotLayers(slot)

	slot:Show()
	-- Offline bank is view-only: disable mouse so Blizzard OnClick stays untainted.
	if slot.EnableMouse then
		local offlineBank = E.embeddedInSarychUI and frame.isBank and not B.bankIsOpen and B:IsBankBagID(bagID)
		slot:EnableMouse(not offlineBank)
	end
	slot.questIcon:Hide()
	slot.JunkIcon:Hide()
	slot.itemLevel:SetText("")
	slot.bindType:SetText("")

	if B.db.showBindType and not useCache then
		E.ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
		if slot.GetInventorySlot then -- this fixes bank bagid -1
			E.ScanTooltip:SetInventoryItem("player", slot:GetInventorySlot())
		else
			E.ScanTooltip:SetBagItem(bagID, slotID)
		end
		E.ScanTooltip:Show()
	end

	if B.db.professionBagColors and B.ProfessionColors[bagType] then
		slot:SetBackdropBorderColor(unpack(B.ProfessionColors[bagType]))
		slot.ignoreBorderColors = true
	elseif clink then
		local iLvl, iType, itemEquipLoc, itemPrice
		slot.name, _, slot.rarity, iLvl, _, iType, _, _, itemEquipLoc, _, itemPrice = GetItemInfo(clink)

		local isQuestItem, questId, isActiveQuest
		if not useCache then
			isQuestItem, questId, isActiveQuest = GetContainerItemQuestInfo(bagID, slotID)
		end
		local r, g, b

		if slot.rarity then
			r, g, b = GetItemQualityColor(slot.rarity)
		end

		if B.db.showBindType and not useCache and (slot.rarity and slot.rarity > 1) then
			local bindTypeLines = GetCVarBool("colorblindmode") and 8 or 7
			local BoE, BoU
			for i = 2, bindTypeLines do
				local line = _G["ElvUI_ScanTooltipTextLeft"..i]:GetText()
				if (not line or line == "") or (line == ITEM_SOULBOUND or line == ITEM_ACCOUNTBOUND or line == ITEM_BNETACCOUNTBOUND) then break end

				BoE, BoU = line == ITEM_BIND_ON_EQUIP, line == ITEM_BIND_ON_USE

				if not B.db.showBindType and (slot.rarity and slot.rarity > 1) or (BoE or BoU) then break end
			end

			if BoE or BoU then
				slot.bindType:SetText(BoE and L["BoE"] or L["BoU"])
				slot.bindType:SetVertexColor(r, g, b)
			end
		end

		-- Item Level
		if iLvl and B.db.itemLevel and (itemEquipLoc ~= nil and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_AMMO" and itemEquipLoc ~= "INVTYPE_BAG" and itemEquipLoc ~= "INVTYPE_QUIVER" and itemEquipLoc ~= "INVTYPE_TABARD") and (slot.rarity and slot.rarity > 1) and iLvl >= B.db.itemLevelThreshold then
			slot.itemLevel:SetText(iLvl)
			if B.db.itemLevelCustomColorEnable then
				slot.itemLevel:SetTextColor(B.db.itemLevelCustomColor.r, B.db.itemLevelCustomColor.g, B.db.itemLevelCustomColor.b)
			else
				slot.itemLevel:SetTextColor(r, g, b)
			end
		end

		slot.isJunk = (slot.rarity and slot.rarity == 0) and (itemPrice and itemPrice > 0) and (iType and iType ~= "Quest")
		slot.junkDesaturate = slot.isJunk and E.db.bags.junkDesaturate

		-- Junk Icon
		if slot.JunkIcon then
			if E.db.bags.junkIcon and slot.isJunk then
				slot.JunkIcon:Show()
			end
		end

		if B.db.questIcon and (questId and not isActiveQuest) then
			slot.questIcon:Show()
		end

		-- color slot according to item quality
		if B.db.questItemColors and (questId and not isActiveQuest) then
			slot:SetBackdropBorderColor(unpack(B.QuestColors.questStarter))
			slot.ignoreBorderColors = true
		elseif B.db.questItemColors and (questId or isQuestItem) then
			slot:SetBackdropBorderColor(unpack(B.QuestColors.questItem))
			slot.ignoreBorderColors = true
		elseif B.db.qualityColors and (slot.rarity and slot.rarity > 1) then
			slot:SetBackdropBorderColor(r, g, b)
			slot.ignoreBorderColors = true
		else
			slot:SetBackdropBorderColor(GetBagDefaultBorder())
			slot.ignoreBorderColors = nil
		end
	else
		slot:SetBackdropBorderColor(GetBagDefaultBorder())
		slot.ignoreBorderColors = nil
	end

	E.ScanTooltip:Hide()

	if texture then
		B:PreferSarychUICooldown(slot.cooldown)
		if not useCache then
			local start, duration, enable = GetContainerItemCooldown(bagID, slotID)
			CooldownFrame_SetTimer(slot.cooldown, start, duration, enable)
			if duration > 0 and enable == 0 then
				SetItemButtonTextureVertexColor(slot, 0.4, 0.4, 0.4)
			else
				SetItemButtonTextureVertexColor(slot, 1, 1, 1)
			end
		else
			if slot.cooldown then slot.cooldown:Hide() end
			SetItemButtonTextureVertexColor(slot, 1, 1, 1)
		end

		slot.hasItem = 1

		SetItemButtonTexture(slot, texture)
		if slot.iconTexture then
			slot.iconTexture:Show()
			slot.iconTexture:SetTexture(texture)
			slot.iconTexture:SetTexCoord(unpack(E.TexCoords))
			slot.iconTexture:SetVertexColor(1, 1, 1)
		end

		if slot.iconBorder and slot.rarity and slot.rarity > 1 then
			slot.iconBorder:Show()
		elseif slot.iconBorder then
			slot.iconBorder:Hide()
		end

		if slot.Count then
			slot.Count:Show()
		end
		if slot.itemLevel then
			slot.itemLevel:Show()
		end
		if slot.bindType then
			slot.bindType:Show()
		end

		SetItemButtonCount(slot, count or 0)
		SetItemButtonDesaturated(slot, slot.locked or slot.junkDesaturate)

		slot.itemLink = clink
		slot.itemID = clink and tonumber(strmatch(clink, "item:(%d+)")) or nil
	else
		B:ClearEmptySlotVisuals(slot)
	end

	if slot.searchOverlay then
		slot.searchOverlay:Hide()
	end
	slot:SetAlpha(1)
	B:ClearSlotTransientVisuals(slot)

	if GameTooltip:GetOwner() == slot and not slot.hasItem then
		GameTooltip_Hide()
	end

	-- Keep AdiBags free-space virtual stack visuals after empty-slot reset.
	if slot._suiFreeSpaceHidden then
		slot:Hide()
	elseif slot._suiFreeSpaceStack then
		B:ApplyAdiBagsFreeSpaceDisplay(slot, slot._suiFreeSpaceStack)
	end
end

function B:UpdateBagSlots(frame, bagID)
	for slotID = 1, GetContainerNumSlots(bagID) do
		B:UpdateSlot(frame, bagID, slotID)
	end
end

function B:RefreshSearch()
	B:SetSearch(SEARCH_STRING)
end

function B:SortingFadeBags(bagFrame, registerUpdate)
	if not (bagFrame and bagFrame.BagIDs and bagFrame.Bags) then return end
	bagFrame.registerUpdate = registerUpdate

	for _, bagID in ipairs(bagFrame.BagIDs) do
		for slotID = 1, GetContainerNumSlots(bagID) do
			local button = bagFrame.Bags[bagID] and bagFrame.Bags[bagID][slotID]
			if button then
				SetItemButtonDesaturated(button, 1)
				if button.searchOverlay then
					button.searchOverlay:Show()
				end
				button:SetAlpha(0.5)
			end
		end
	end
end

function B:ClearSortingFade(bagFrame)
	if not (bagFrame and bagFrame.BagIDs and bagFrame.Bags) then return end

	for _, bagID in ipairs(bagFrame.BagIDs) do
		local bags = bagFrame.Bags[bagID]
		if bags then
			for slotID = 1, GetContainerNumSlots(bagID) do
				local button = bags[slotID]
				if button then
					if button.searchOverlay then
						button.searchOverlay:Hide()
					end
					button:SetAlpha(1)
				end
			end
		end
	end
end

function B:UpdateCooldowns(frame)
	if not (frame and frame.BagIDs and frame.Bags) then return end

	for _, bagID in ipairs(frame.BagIDs) do
		for slotID = 1, GetContainerNumSlots(bagID) do
			local slot = frame.Bags[bagID] and frame.Bags[bagID][slotID]
			if slot then
				B:PreferSarychUICooldown(slot.cooldown)
				local start, duration, enable = GetContainerItemCooldown(bagID, slotID)
				CooldownFrame_SetTimer(slot.cooldown, start, duration, enable)
			end
		end
	end
end

function B:UpdateAllSlots(frame)
	if not (frame and frame.BagIDs and frame.Bags) then return end

	for _, bagID in ipairs(frame.BagIDs) do
		local bag = frame.Bags[bagID]
		if bag then B:UpdateBagSlots(frame, bagID) end
	end

	-- Refresh search in case we moved items around
	if not frame.registerUpdate and B:IsSearching() then
		B:RefreshSearch()
	end
end

function B:SetupSlotHover(slot)
	if not slot then return end

	-- Default Blizzard item-button highlight only (no custom overlay system).
	if slot.SetHighlightTexture and not slot._blizzardHighlightSet then
		slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		local ht = slot.GetHighlightTexture and slot:GetHighlightTexture()
		if ht then
			if ht.SetAllPoints then ht:SetAllPoints() end
			if ht.SetBlendMode then ht:SetBlendMode("ADD") end
		end
		slot._blizzardHighlightSet = true
	end

	if slot.hoverOverlay then
		slot.hoverOverlay:Hide()
		slot.hoverOverlay = nil
	end
	if slot.slotHover then
		slot.slotHover:Hide()
		slot.slotHover = nil
	end
	slot._neutralHighlightSet = nil

	if not slot._elvuiHoverSetup then
		slot._elvuiHoverSetup = true
		slot:HookScript("OnEnter", function(self)
			-- Offline bank: Blizzard bag tooltips have no data — show cached hyperlink.
			if self.cachedLink and not B.bankIsOpen then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetHyperlink(self.cachedLink)
				GameTooltip:Show()
			end
		end)
	end

	-- Never SetScript OnClick/OnDrag* on bag item buttons: that taints UseContainerItem.
	-- Offline bank is locked via EnableMouse in UpdateSlot instead.
end

function B:SetSlotAlphaForBag(f)
	if not (f and f.BagIDs and f.Bags) then return end
	for _, bagID in ipairs(f.BagIDs) do
		if f.Bags[bagID] then
			for slotID = 1, GetContainerNumSlots(bagID) do
				if f.Bags[bagID][slotID] then
					if bagID == self.id then
						f.Bags[bagID][slotID]:SetAlpha(1)
					else
						f.Bags[bagID][slotID]:SetAlpha(0.1)
					end
				end
			end
		end
	end
end

function B:ResetSlotAlphaForBags(f)
	if not (f and f.BagIDs and f.Bags) then return end
	for _, bagID in ipairs(f.BagIDs) do
		if f.Bags[bagID] then
			for slotID = 1, GetContainerNumSlots(bagID) do
				if f.Bags[bagID][slotID] then
					f.Bags[bagID][slotID]:SetAlpha(1)
				end
			end
		end
	end
end

function B:Layout(isBank)
	if not E.private.bags.enable then return end

	local f = B:GetContainerFrame(isBank)
	if not f then return end

	local buttonSize = isBank and B.db.bankSize or B.db.bagSize
	local buttonSpacing = E.Border*2
	local numContainerColumns
	local containerWidth
	local holderWidth
	if E.embeddedInSarychUI then
		local cols = isBank and (B.db.bankColumns or 10) or (B.db.bagColumns or 10)
		cols = tonumber(cols) or 10
		if cols < 6 then cols = 6 end
		if cols > 14 then cols = 14 end
		numContainerColumns = floor(cols + 0.5)
		holderWidth = ((buttonSize + buttonSpacing) * numContainerColumns) - buttonSpacing
		-- Keep side padding so slots are not flush with the window edge.
		local edgePad = GetBagEdgePad()
		containerWidth = holderWidth + (edgePad * 2)
	else
		containerWidth = ((isBank and B.db.bankWidth) or B.db.bagWidth)
		numContainerColumns = floor(containerWidth / (buttonSize + buttonSpacing))
		holderWidth = ((buttonSize + buttonSpacing) * numContainerColumns) - buttonSpacing
	end
	local numContainerRows = 0
	local numBags = 0
	local numBagSlots = 0
	local bagSpacing = B.db.split.bagSpacing
	local countColor = E.db.bags.countFontColor
	local isSplit = B.db.split[isBank and "bank" or "player"]
	local splitAdditional = B:IsAdditionalSplitEnabled(isBank)
	local adiBagsMode = splitAdditional and B:IsAdiBagsSplitMode()
	local splitFoodSlots, splitRecoverySlots, splitAmmoSlots, splitQuestSlots
	local adiBagsSections
	if splitAdditional then
		if adiBagsMode then
			adiBagsSections = {}
			for _, key in ipairs(ADIBAGS_SECTION_ORDER) do
				adiBagsSections[key] = {}
			end
		else
			splitFoodSlots, splitRecoverySlots, splitAmmoSlots, splitQuestSlots = {}, {}, {}, {}
		end
	end

	f._suiHolderWidth = holderWidth
	f.holderFrame:Width(holderWidth)
	if E.embeddedInSarychUI then
		f.topOffset = GetBagContentTopOffset(f)
		local edgePad = GetBagEdgePad()
		f.holderFrame:ClearAllPoints()
		f.holderFrame:Point("TOPLEFT", f, "TOPLEFT", edgePad, -f.topOffset)
		f.holderFrame:Point("BOTTOMLEFT", f, "BOTTOMLEFT", edgePad, 8)
	end

	f.totalSlots = 0
	local lastButton
	local lastRowButton
	local lastContainerButton
	local numContainerSlots = GetNumBankSlots()
	local offlineBank = E.embeddedInSarychUI and isBank and not B.bankIsOpen
	if offlineBank then
		numContainerSlots = B:GetOfflineNumBankSlots()
	end
	local newBag
	local bankBagButtons = 0

	local function PlaceMainSlot(slot, startNewBag)
		f.totalSlots = f.totalSlots + 1
		if slot:GetPoint() then
			slot:ClearAllPoints()
		end

		if lastButton then
			local anchorPoint, relativePoint = (B.db.reverseSlots and "BOTTOM" or "TOP"), (B.db.reverseSlots and "TOP" or "BOTTOM")
			if isSplit and startNewBag then
				slot:Point(anchorPoint, lastRowButton, relativePoint, 0, B.db.reverseSlots and (buttonSpacing + bagSpacing) or -(buttonSpacing + bagSpacing))
				lastRowButton = slot
				numContainerRows = numContainerRows + 1
				numBags = numBags + 1
				numBagSlots = 0
			elseif isSplit and numBagSlots % numContainerColumns == 0 then
				slot:Point(anchorPoint, lastRowButton, relativePoint, 0, B.db.reverseSlots and buttonSpacing or -buttonSpacing)
				lastRowButton = slot
				numContainerRows = numContainerRows + 1
			elseif (not isSplit) and (f.totalSlots - 1) % numContainerColumns == 0 then
				slot:Point(anchorPoint, lastRowButton, relativePoint, 0, B.db.reverseSlots and buttonSpacing or -buttonSpacing)
				lastRowButton = slot
				numContainerRows = numContainerRows + 1
			else
				anchorPoint, relativePoint = (B.db.reverseSlots and "RIGHT" or "LEFT"), (B.db.reverseSlots and "LEFT" or "RIGHT")
				slot:Point(anchorPoint, lastButton, relativePoint, B.db.reverseSlots and -buttonSpacing or buttonSpacing, 0)
			end
		else
			local anchorPoint = B.db.reverseSlots and "BOTTOMRIGHT" or "TOPLEFT"
			slot:Point(anchorPoint, f.holderFrame, anchorPoint, 0, B.db.reverseSlots and f.bottomOffset - 8 or 0)
			lastRowButton = slot
			numContainerRows = numContainerRows + 1
		end

		lastButton = slot
		numBagSlots = numBagSlots + 1
	end

	local function PlaceAdditionalSplitSlots()
		local groups = {}
		if adiBagsMode and adiBagsSections then
			for _, key in ipairs(ADIBAGS_SECTION_ORDER) do
				local slots = adiBagsSections[key]
				if slots and #slots > 0 then
					if key == "empty" then
						slots = B:CollapseAdiBagsEmptySlots(slots)
						adiBagsSections[key] = slots
					else
						B:SortAdiBagsSection(slots)
					end
					tinsert(groups, {
						key = key,
						slots = slots,
						label = ADIBAGS_SECTION_LABELS[key] or key,
					})
				end
			end
		elseif splitFoodSlots then
			if #splitFoodSlots > 0 then tinsert(groups, { slots = splitFoodSlots }) end
			if #splitRecoverySlots > 0 then tinsert(groups, { slots = splitRecoverySlots }) end
			if #splitAmmoSlots > 0 then tinsert(groups, { slots = splitAmmoSlots }) end
			if #splitQuestSlots > 0 then tinsert(groups, { slots = splitQuestSlots }) end
		end

		-- Hide leftover AdiBags headers from a previous layout/mode.
		f._suiAdiBagsHeaders = f._suiAdiBagsHeaders or {}
		for i = 1, #f._suiAdiBagsHeaders do
			f._suiAdiBagsHeaders[i]:Hide()
		end

		if not splitAdditional or #groups == 0 then
			return 0, false, 0
		end

		local hadMainRows = lastRowButton ~= nil
		local nextHeaderIndex = 0

		local sectionHeaderStyle = (E.embeddedInSarychUI and B.GetSectionHeaderStyle) and B:GetSectionHeaderStyle() or nil
		local sectionHeaderHeight = (sectionHeaderStyle and sectionHeaderStyle.headerHeight) or ADIBAGS_HEADER_SIZE

		local function AcquireSectionHeader(label)
			nextHeaderIndex = nextHeaderIndex + 1
			local fs = f._suiAdiBagsHeaders[nextHeaderIndex]
			if not fs then
				fs = f.holderFrame:CreateFontString(nil, "OVERLAY")
				f._suiAdiBagsHeaders[nextHeaderIndex] = fs
			end
			if E.embeddedInSarychUI and B.ApplySectionHeaderFont then
				B:ApplySectionHeaderFont(fs)
			elseif E.embeddedInSarychUI and B.ApplySlotTextFont then
				B:ApplySlotTextFont(fs, 12)
			else
				fs:SetFontObject(GameFontNormal)
			end
			fs:SetJustifyH("LEFT")
			fs:SetJustifyV("MIDDLE")
			fs:SetText(label)
			if not (E.embeddedInSarychUI and B.ApplySectionHeaderFont) then
				fs:SetTextColor(1, 1, 1, 0.28)
			end
			fs:Show()
			return fs
		end

		-- AdiBags: pack sections left-to-right; FitInSpace (incl. gap rule) decides
		-- whether a section may sit beside the previous one or must wrap.
		if adiBagsMode then
			local slotStep = buttonSize + buttonSpacing
			-- AdiBags: SECTION_SPACING = ITEM_SIZE/3 + ITEM_SPACING
			local sectionSpacing = floor(buttonSize / 3 + buttonSpacing)
			local headerBlock = sectionHeaderHeight + ADIBAGS_HEADER_GAP
			local rowWidthPx = holderWidth
			-- Soft vertical limit like AdiBags maxHeight (~60% screen); we only need
			-- enough room for FitInSpace math on a single bag column.
			local maxHeightPx = 100000

			local function SectionPixelWidth(cols)
				return buttonSize * cols + buttonSpacing * max(cols - 1, 0)
			end

			-- Port of AdiBags Section:FitInSpace
			local function FitInSpace(count, maxWidthPx, maxHeightAvail, xOffset, rowHeight)
				local maxColumns = floor((ceil(maxWidthPx) + buttonSpacing) / slotStep)
				local maxRows = floor((ceil(maxHeightAvail) - headerBlock + buttonSpacing) / slotStep)
				if maxColumns < 1 or maxRows < 1 then return end
				if maxColumns * maxRows < count then return end

				local numColumns, numRows
				if maxColumns >= count then
					numColumns, numRows = count, 1
				else
					numColumns, numRows = maxColumns, ceil(count / maxColumns)
				end

				local height = headerBlock + buttonSize * numRows + buttonSpacing * max(numRows - 1, 0)
				local available = maxWidthPx * maxHeightAvail
				local gap = max(0, height - rowHeight) * xOffset
				local occupation = count * slotStep * slotStep + numColumns * slotStep * headerBlock
				if gap < occupation / 2 then
					local wasted = available + gap - occupation
					return numColumns, numRows, wasted, height
				end
			end

			local originFrame = f.holderFrame
			local originRel = "TOPLEFT"
			local originX, originY = 0, 0
			if lastRowButton then
				originFrame = lastRowButton
				originRel = "BOTTOMLEFT"
				originX, originY = 0, -(buttonSize + buttonSpacing * 2)
			else
				originY = -ADIBAGS_FIRST_HEADER_TOP_PAD
			end

			local x, y = 0, 0
			local rowHeight = 0
			local contentHeight = 0

			local function PlacePackedSection(group)
				local slots = group.slots or group
				local count = slots and #slots or 0
				if count == 0 then return end

				local widthCols, heightRows, secH
				while true do
					widthCols, heightRows, _, secH = FitInSpace(count, rowWidthPx - x, maxHeightPx - y, x, rowHeight)
					if widthCols then
						break
					end
					if x <= 0 then
						-- Full-width fallback (should always succeed with huge maxHeight).
						widthCols, heightRows, _, secH = FitInSpace(count, rowWidthPx, maxHeightPx, 0, 0)
						if not widthCols then
							widthCols = numContainerColumns
							heightRows = ceil(count / max(numContainerColumns, 1))
							secH = headerBlock + buttonSize * heightRows + buttonSpacing * max(heightRows - 1, 0)
						end
						break
					end
					-- Does not fit beside current sections — wrap like AdiBags.
					y = y + rowHeight + buttonSpacing
					x = 0
					rowHeight = 0
				end

				local secW = SectionPixelWidth(widthCols)

				local fs = AcquireSectionHeader(group.label or "")
				fs:ClearAllPoints()
				fs:SetWidth(max(secW, 1))
				fs:SetHeight(sectionHeaderHeight)
				fs:SetPoint("TOPLEFT", originFrame, originRel, originX + x, originY - y)

				local slotsTop = y + headerBlock
				for index, slot in ipairs(slots) do
					local col = (index - 1) % widthCols
					local row = floor((index - 1) / widthCols)
					if slot:GetPoint() then
						slot:ClearAllPoints()
					end
					slot:SetPoint(
						"TOPLEFT",
						originFrame,
						originRel,
						originX + x + col * slotStep,
						originY - (slotsTop + row * slotStep)
					)
					slot:Show()
				end

				x = x + secW + sectionSpacing
				rowHeight = max(rowHeight, secH)
				contentHeight = max(contentHeight, y + rowHeight)
			end

			for _, group in ipairs(groups) do
				PlacePackedSection(group)
			end

			-- Exact pixel height of packed content (splitRows==0 → only headerExtra counts).
			if hadMainRows then
				return 0, false, contentHeight + (buttonSize + buttonSpacing * 2)
			end
			return 0, false, contentHeight + ADIBAGS_FIRST_HEADER_TOP_PAD
		end

		-- Classic bottom groups: each group continues the slot flow (optional gap between groups).
		local splitRows, splitColumn = 0, 0
		local previousSplitButton, splitRowButton
		local headerExtra = 0
		local pendingHeader = nil

		local function PlaceSectionHeader(label, afterPrevious)
			local fs = AcquireSectionHeader(label)
			fs:ClearAllPoints()
			fs:SetWidth(holderWidth)
			fs:SetHeight(sectionHeaderHeight)
			local topGap = afterPrevious and (buttonSpacing * 2) or 0
			if splitRowButton then
				fs:SetPoint("TOPLEFT", splitRowButton, "BOTTOMLEFT", 0, -max(topGap, ADIBAGS_HEADER_GAP))
			elseif lastRowButton then
				fs:SetPoint("TOPLEFT", lastRowButton, "BOTTOMLEFT", 0, -max(topGap, ADIBAGS_HEADER_GAP))
			else
				fs:SetPoint("TOPLEFT", f.holderFrame, "TOPLEFT", 0, 0)
			end
			pendingHeader = fs
			headerExtra = headerExtra + sectionHeaderHeight + ADIBAGS_HEADER_GAP + (afterPrevious and topGap or 0)
			previousSplitButton = nil
			splitColumn = 0
		end

		local function StartSplitRow(slot, withGroupSeparator)
			slot:ClearAllPoints()
			if pendingHeader then
				slot:Point("TOPLEFT", pendingHeader, "BOTTOMLEFT", 0, -ADIBAGS_HEADER_GAP)
				pendingHeader = nil
			elseif splitRowButton then
				slot:Point("TOP", splitRowButton, "BOTTOM", 0, withGroupSeparator and -(buttonSize + (buttonSpacing * 2)) or -buttonSpacing)
				if withGroupSeparator then
					splitRows = splitRows + 1
				end
			elseif lastRowButton then
				slot:Point("TOP", lastRowButton, "BOTTOM", 0, -(buttonSize + (buttonSpacing * 2)))
			else
				slot:Point("TOPLEFT", f.holderFrame, "TOPLEFT", 0, 0)
			end
			splitRowButton = slot
			previousSplitButton = slot
			splitRows = splitRows + 1
			splitColumn = 1
		end

		local function PlaceSplitSlot(slot, startNewGroup)
			if not slot then return end
			if slot:GetPoint() then
				slot:ClearAllPoints()
			end
			if startNewGroup then
				if previousSplitButton and splitColumn + 2 <= numContainerColumns then
					slot:Point("LEFT", previousSplitButton, "RIGHT", buttonSize + (buttonSpacing * 2), 0)
					previousSplitButton = slot
					splitColumn = splitColumn + 2
				else
					StartSplitRow(slot, true)
				end
			elseif splitColumn == 0 or splitColumn >= numContainerColumns then
				StartSplitRow(slot)
			else
				slot:Point("LEFT", previousSplitButton, "RIGHT", buttonSpacing, 0)
				previousSplitButton = slot
				splitColumn = splitColumn + 1
			end
			slot:Show()
		end

		local hasPlacedGroup = false
		local function PlaceGroup(group)
			local slots = group.slots or group
			if not slots or #slots == 0 then return end
			if group.label then
				PlaceSectionHeader(group.label, hasPlacedGroup)
			end
			local firstInGroup = true
			for _, slot in ipairs(slots) do
				local startNew = hasPlacedGroup and firstInGroup and not group.label
				PlaceSplitSlot(slot, startNew)
				firstInGroup = false
			end
			hasPlacedGroup = true
		end

		for _, group in ipairs(groups) do
			PlaceGroup(group)
		end

		return splitRows, hadMainRows, headerExtra
	end

	for i, bagID in ipairs(f.BagIDs) do
		if isSplit then
			newBag = (bagID ~= -1 or bagID ~= 0) and B.db.split["bag"..bagID] or false
		end

		-- Bag Containers
		local showBankBagButton = false
		if isBank then
			if bagID == -1 then
				-- Main bank (like backpack): always listed so hover can highlight its slots.
				showBankBagButton = true
			elseif offlineBank then
				-- Per-slot cache check (not "first N purchased") so missing bags stay hidden.
				showBankBagButton = B:HasCachedBankBag(bagID)
			else
				showBankBagButton = numContainerSlots >= 1 and (i - 1 <= numContainerSlots)
			end
		end
		if (not isBank) or showBankBagButton then
			if not f.ContainerHolder[i] then
				if isBank then
					if bagID == -1 then
						f.ContainerHolder[i] = CreateFrame("CheckButton", "ElvUIBankMainBag", f.ContainerHolder, "ItemButtonTemplate")
						f.ContainerHolder[i]:SetScript("OnEnter", function(holder)
							GameTooltip:SetOwner(holder, "ANCHOR_LEFT")
							local locale = GetLocale and GetLocale() or "enUS"
							GameTooltip:SetText((locale == "ruRU") and "Банк" or (L["Bank"] or BANK or "Bank"), 1, 1, 1)
							GameTooltip:Show()
						end)
						f.ContainerHolder[i]:SetScript("OnLeave", GameTooltip_Hide)
					else
						f.ContainerHolder[i] = CreateFrame("CheckButton", "ElvUIBankBag"..bagID - 4, f.ContainerHolder, "BankItemButtonBagTemplate")
						f.ContainerHolder[i]:SetScript("OnClick", function(holder)
							if E.embeddedInSarychUI and not B.bankIsOpen then return end
							local inventoryID = holder:GetInventorySlot()
							PutItemInBag(inventoryID)
						end)
					end
				else
					if bagID == 0 then
						f.ContainerHolder[i] = CreateFrame("CheckButton", "ElvUIMainBagBackpack", f.ContainerHolder, "ItemButtonTemplate")

						f.ContainerHolder[i].model = CreateFrame("Model", "$parentItemAnim", f.ContainerHolder[i], "ItemAnimTemplate")
						f.ContainerHolder[i].model:SetPoint("BOTTOMRIGHT", -10, 0)

						f.ContainerHolder[i]:SetScript("OnClick", function()
							PutItemInBackpack()
						end)
						f.ContainerHolder[i]:SetScript("OnReceiveDrag", function()
							PutItemInBackpack()
						end)
						f.ContainerHolder[i]:SetScript("OnEnter", function(holder)
							GameTooltip:SetOwner(holder, "ANCHOR_LEFT")
							GameTooltip:SetText(BACKPACK_TOOLTIP, 1, 1, 1)
							GameTooltip:Show()
						end)
						f.ContainerHolder[i]:SetScript("OnLeave", GameTooltip_Hide)
					else
						f.ContainerHolder[i] = CreateFrame("CheckButton", "ElvUIMainBag"..(bagID - 1).."Slot", f.ContainerHolder, "BagSlotButtonTemplate")
						f.ContainerHolder[i]:SetScript("OnClick", function(holder)
							local id = holder:GetID()
							PutItemInBag(id)
						end)
					end
				end

				f.ContainerHolder[i]:SetTemplate(E.db.bags.transparent and "Transparent", true)
				f.ContainerHolder[i]:StyleButton()
				f.ContainerHolder[i]:SetNormalTexture("")
				f.ContainerHolder[i]:SetCheckedTexture(nil)
				f.ContainerHolder[i]:SetPushedTexture("")
				f.ContainerHolder[i].id = bagID
				f.ContainerHolder[i]:HookScript("OnEnter", function(ch) B.SetSlotAlphaForBag(ch, f) end)
				f.ContainerHolder[i]:HookScript("OnLeave", function(ch) B.ResetSlotAlphaForBags(ch, f) end)

				if isBank and bagID ~= -1 then
					f.ContainerHolder[i]:SetID(bagID)
					if not f.ContainerHolder[i].tooltipText then
						f.ContainerHolder[i].tooltipText = ""
					end
				end

				f.ContainerHolder[i].iconTexture = _G[f.ContainerHolder[i]:GetName().."IconTexture"]
				if bagID == 0 then
					f.ContainerHolder[i].iconTexture:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
				elseif bagID == -1 then
					f.ContainerHolder[i].iconTexture:SetTexture("Interface\\Icons\\INV_Box_02")
				end
				f.ContainerHolder[i].iconTexture:SetInside()
				f.ContainerHolder[i].iconTexture:SetTexCoord(unpack(E.TexCoords))
			end

			if isBank then
				bankBagButtons = bankBagButtons + 1
			end
			local holderCount = isBank and bankBagButtons or i
			f.ContainerHolder:Size(((buttonSize + buttonSpacing) * holderCount) + buttonSpacing, buttonSize + (buttonSpacing * 2))

			if isBank and bagID == -1 then
				local icon = f.ContainerHolder[i].iconTexture
				if icon then
					icon:SetTexture("Interface\\Icons\\INV_Box_02")
				end
			elseif isBank and not offlineBank then
				BankFrameItemButton_Update(f.ContainerHolder[i])
				BankFrameItemButton_UpdateLocked(f.ContainerHolder[i])
			elseif isBank and offlineBank and f.ContainerHolder[i] then
				local cached = B:GetCachedBankBag(bagID)
				local icon = f.ContainerHolder[i].iconTexture
				if icon then
					local tex
					if cached and cached.BagLink then
						tex = (GetItemIcon and GetItemIcon(cached.BagLink)) or select(10, GetItemInfo(cached.BagLink))
					end
					if not tex and (cached and (cached.Size or 0) > 0) then
						tex = "Interface\\Icons\\INV_Misc_Bag_08"
					end
					icon:SetTexture(tex or "")
				end
			end

			f.ContainerHolder[i]:Show()
			f.ContainerHolder[i]:Size(buttonSize)
			f.ContainerHolder[i]:ClearAllPoints()
			if not lastContainerButton then
				f.ContainerHolder[i]:Point("BOTTOMLEFT", f.ContainerHolder, "BOTTOMLEFT", buttonSpacing, buttonSpacing)
			else
				f.ContainerHolder[i]:Point("LEFT", lastContainerButton, "RIGHT", buttonSpacing, 0)
			end

			lastContainerButton = f.ContainerHolder[i]
		elseif isBank and bagID ~= -1 and f.ContainerHolder[i] then
			-- Hide bag buttons for slots with no cached bag / not purchased.
			f.ContainerHolder[i]:Hide()
		end

		-- Bag Slots
		local numSlots = GetContainerNumSlots(bagID)
		if numSlots > 0 then
			if not f.Bags[bagID] then
				f.Bags[bagID] = CreateFrame("Frame", f:GetName().."Bag"..bagID, f.holderFrame)
				f.Bags[bagID]:SetID(bagID)
			end

			f.Bags[bagID].numSlots = numSlots
			if offlineBank then
				f.Bags[bagID].type = 0
			else
				f.Bags[bagID].type = select(2, GetContainerNumFreeSlots(bagID))
			end

			--Hide unused slots
			for y = 1, MAX_CONTAINER_ITEMS do
				if f.Bags[bagID][y] then
					f.Bags[bagID][y]:Hide()
				end
			end

			local placedThisBag = false
			for slotID = 1, numSlots do
				if not f.Bags[bagID][slotID] then
					f.Bags[bagID][slotID] = CreateFrame("CheckButton", f.Bags[bagID]:GetName().."Slot"..slotID, f.Bags[bagID], bagID == -1 and "BankItemButtonGenericTemplate" or "ContainerFrameItemButtonTemplate")
					f.Bags[bagID][slotID]:StyleButton(true)
					f.Bags[bagID][slotID]:SetTemplate(E.db.bags.transparent and "Transparent", true)
					f.Bags[bagID][slotID]:SetNormalTexture(nil)
					f.Bags[bagID][slotID]:SetCheckedTexture(nil)

					f.Bags[bagID][slotID].Count = _G[f.Bags[bagID][slotID]:GetName().."Count"]
					f.Bags[bagID][slotID].Count:ClearAllPoints()
					f.Bags[bagID][slotID].Count:Point("BOTTOMRIGHT", -1, 3)
					if E.embeddedInSarychUI then
						B:ApplySlotTextFont(f.Bags[bagID][slotID].Count, B:GetStackFontSize())
					else
						f.Bags[bagID][slotID].Count:FontTemplate(E.Libs.LSM:Fetch("font", E.db.bags.countFont), E.db.bags.countFontSize, E.db.bags.countFontOutline)
					end
					f.Bags[bagID][slotID].Count:SetTextColor(countColor.r, countColor.g, countColor.b)

					if not f.Bags[bagID][slotID].questIcon then
						f.Bags[bagID][slotID].questIcon = _G[f.Bags[bagID][slotID]:GetName().."IconQuestTexture"] or _G[f.Bags[bagID][slotID]:GetName()].IconQuestTexture
						f.Bags[bagID][slotID].questIcon:SetTexture(E.Media.Textures.BagQuestIcon)
						f.Bags[bagID][slotID].questIcon:SetTexCoord(0, 1, 0, 1)
						f.Bags[bagID][slotID].questIcon:SetInside()
						f.Bags[bagID][slotID].questIcon:Hide()
					end

					if not f.Bags[bagID][slotID].JunkIcon then
						local JunkIcon = f.Bags[bagID][slotID]:CreateTexture(nil, "OVERLAY")
						JunkIcon:SetTexture(E.Media.Textures.BagJunkIcon)
						JunkIcon:Point("TOPLEFT", 1, 0)
						JunkIcon:Hide()
						f.Bags[bagID][slotID].JunkIcon = JunkIcon
					end

					f.Bags[bagID][slotID].iconTexture = _G[f.Bags[bagID][slotID]:GetName().."IconTexture"]
					f.Bags[bagID][slotID].iconTexture:SetInside(f.Bags[bagID][slotID])
					f.Bags[bagID][slotID].iconTexture:SetTexCoord(unpack(E.TexCoords))

					if not f.Bags[bagID][slotID].searchOverlay then
						local searchOverlay = f.Bags[bagID][slotID]:CreateTexture(nil, "ARTWORK")
						searchOverlay:SetTexture(E.media.blankTex)
						searchOverlay:SetVertexColor(0, 0, 0)
						searchOverlay:SetAllPoints()
						searchOverlay:Hide()
						f.Bags[bagID][slotID].searchOverlay = searchOverlay
					end

					f.Bags[bagID][slotID].cooldown = _G[f.Bags[bagID][slotID]:GetName().."Cooldown"]
					B:PreferSarychUICooldown(f.Bags[bagID][slotID].cooldown)
					f.Bags[bagID][slotID].bagID = bagID
					f.Bags[bagID][slotID].slotID = slotID

					f.Bags[bagID][slotID].itemLevel = f.Bags[bagID][slotID]:CreateFontString(nil, "OVERLAY")
					f.Bags[bagID][slotID].itemLevel:Point("BOTTOMRIGHT", -1, 3)
					if E.embeddedInSarychUI then
						B:ApplySlotTextFont(f.Bags[bagID][slotID].itemLevel, B:GetItemLevelFontSize())
					else
						f.Bags[bagID][slotID].itemLevel:FontTemplate(E.Libs.LSM:Fetch("font", E.db.bags.itemLevelFont), E.db.bags.itemLevelFontSize, E.db.bags.itemLevelFontOutline)
					end

					f.Bags[bagID][slotID].bindType = f.Bags[bagID][slotID]:CreateFontString(nil, "OVERLAY")
					f.Bags[bagID][slotID].bindType:Point("TOP", 0, -2)
					if E.embeddedInSarychUI then
						B:ApplySlotTextFont(f.Bags[bagID][slotID].bindType, B:GetItemLevelFontSize())
					else
						f.Bags[bagID][slotID].bindType:FontTemplate(E.Libs.LSM:Fetch("font", E.db.bags.itemLevelFont), E.db.bags.itemLevelFontSize, E.db.bags.itemLevelFontOutline)
					end
				end

				f.Bags[bagID][slotID]:SetID(slotID)
				f.Bags[bagID][slotID]:Size(buttonSize)

				if f.Bags[bagID][slotID].JunkIcon then
					f.Bags[bagID][slotID].JunkIcon:Size(buttonSize/2)
				end

				B:SetupSlotHover(f.Bags[bagID][slotID])
				local slot = f.Bags[bagID][slotID]
				B:ClearAdiBagsFreeSpaceFlags(slot)
				B:UpdateSlot(f, bagID, slotID)

				if adiBagsMode and adiBagsSections then
					if slot:GetPoint() then
						slot:ClearAllPoints()
					end
					local sectionKey = B:GetAdiBagsSectionKey(bagID, slotID)
					local section = adiBagsSections[sectionKey] or adiBagsSections.miscellaneous
					tinsert(section, slot)
				else
					local splitKind = splitAdditional and B:GetAdditionalSplitKind(bagID, slotID)
					if splitKind == "food" then
						if slot:GetPoint() then
							slot:ClearAllPoints()
						end
						tinsert(splitFoodSlots, slot)
					elseif splitKind == "recovery" then
						if slot:GetPoint() then
							slot:ClearAllPoints()
						end
						tinsert(splitRecoverySlots, slot)
					elseif splitKind == "ammo" then
						if slot:GetPoint() then
							slot:ClearAllPoints()
						end
						tinsert(splitAmmoSlots, slot)
					elseif splitKind == "quest" then
						if slot:GetPoint() then
							slot:ClearAllPoints()
						end
						tinsert(splitQuestSlots, slot)
					else
						PlaceMainSlot(slot, isSplit and newBag and not placedThisBag)
						placedThisBag = true
					end
				end
			end
		else
			--Hide unused slots
			for y = 1, MAX_CONTAINER_ITEMS do
				if f.Bags[bagID] and f.Bags[bagID][y] then
					f.Bags[bagID][y]:Hide()
				end
			end

			if f.Bags[bagID] then
				f.Bags[bagID].numSlots = numSlots
			end

			local container = isBank and f.ContainerHolder[i]
			if container and not offlineBank then
				BankFrameItemButton_Update(container)
				BankFrameItemButton_UpdateLocked(container)
			end
		end
	end

	local splitRows, splitHadMainRows, splitHeaderExtra = PlaceAdditionalSplitSlots()
	splitHeaderExtra = splitHeaderExtra or 0
	if splitRows and splitRows > 0 then
		if splitHadMainRows then
			numContainerRows = numContainerRows + splitRows + 1
		else
			numContainerRows = splitRows
		end
	end

	local numKey = GetKeyRingSize()
	local numKeyColumns = 6
	if not isBank then
		local totalSlots, numKeyRows, lastRowKey = 0, 1

		for i = 1, numKey do
			totalSlots = totalSlots + 1

			if not f.keyFrame.slots[i] then
				f.keyFrame.slots[i] = CreateFrame("CheckButton", "ElvUIKeyFrameItem"..i, f.keyFrame, "ContainerFrameItemButtonTemplate")
				f.keyFrame.slots[i]:StyleButton(true, nil, true)
				f.keyFrame.slots[i]:SetTemplate("Default", true)
				f.keyFrame.slots[i]:SetNormalTexture(nil)
				f.keyFrame.slots[i]:SetID(i)

				f.keyFrame.slots[i].Count = _G[f.keyFrame.slots[i]:GetName().."Count"]
				f.keyFrame.slots[i].Count:ClearAllPoints()
				f.keyFrame.slots[i].Count:Point("BOTTOMRIGHT", 0, 2)
				if E.embeddedInSarychUI then
					B:ApplySlotTextFont(f.keyFrame.slots[i].Count, B:GetStackFontSize())
				else
					f.keyFrame.slots[i].Count:FontTemplate(E.Libs.LSM:Fetch("font", E.db.bags.countFont), E.db.bags.countFontSize, E.db.bags.countFontOutline)
				end
				f.keyFrame.slots[i].Count:SetTextColor(countColor.r, countColor.g, countColor.b)

				f.keyFrame.slots[i].cooldown = _G[f.keyFrame.slots[i]:GetName().."Cooldown"]
				B:PreferSarychUICooldown(f.keyFrame.slots[i].cooldown)

				if not f.keyFrame.slots[i].questIcon then
					f.keyFrame.slots[i].questIcon = _G[f.keyFrame.slots[i]:GetName().."IconQuestTexture"] or _G[f.keyFrame.slots[i]:GetName()].IconQuestTexture
					f.keyFrame.slots[i].questIcon:SetTexture(E.Media.Textures.BagQuestIcon)
					f.keyFrame.slots[i].questIcon:SetTexCoord(0, 1, 0, 1)
					f.keyFrame.slots[i].questIcon:SetInside()
					f.keyFrame.slots[i].questIcon:Hide()
				end

				f.keyFrame.slots[i].iconTexture = _G[f.keyFrame.slots[i]:GetName().."IconTexture"]
				f.keyFrame.slots[i].iconTexture:SetInside(f.keyFrame.slots[i])
				f.keyFrame.slots[i].iconTexture:SetTexCoord(unpack(E.TexCoords))

				if not f.keyFrame.slots[i].searchOverlay then
					local searchOverlay = f.keyFrame.slots[i]:CreateTexture(nil, "ARTWORK")
					searchOverlay:SetTexture(E.media.blankTex)
					searchOverlay:SetVertexColor(0, 0, 0)
					searchOverlay:SetAllPoints()
					searchOverlay:Hide()
					f.keyFrame.slots[i].searchOverlay = searchOverlay
				end

			end

			B:SetupSlotHover(f.keyFrame.slots[i])
			f.keyFrame.slots[i]:ClearAllPoints()
			f.keyFrame.slots[i]:Size(buttonSize)
			if f.keyFrame.slots[i - 1] then
				if (totalSlots - 1) % numKeyColumns == 0 then
					f.keyFrame.slots[i]:Point("TOP", lastRowKey, "BOTTOM", 0, -buttonSpacing)
					lastRowKey = f.keyFrame.slots[i]
					numKeyRows = numKeyRows + 1
				else
					f.keyFrame.slots[i]:Point("RIGHT", f.keyFrame.slots[i - 1], "LEFT", -buttonSpacing, 0)
				end
			else
				f.keyFrame.slots[i]:Point("TOPRIGHT", f.keyFrame, "TOPRIGHT", -buttonSpacing, -buttonSpacing)
				lastRowKey = f.keyFrame.slots[i]
			end

			B:UpdateKeySlot(i)
		end

		if numKey < numKeyColumns then
			numKeyColumns = numKey
		end
		f.keyFrame:Size(((buttonSize + buttonSpacing) * numKeyColumns) + buttonSpacing, ((buttonSize + buttonSpacing) * numKeyRows) + buttonSpacing)
	end

	local gridHeight = 0
	if numContainerRows > 0 then
		gridHeight = ((buttonSize + buttonSpacing) * numContainerRows) - buttonSpacing
	end
	f:Size(containerWidth, gridHeight + (splitHeaderExtra or 0) + (isSplit and (numBags * bagSpacing) or 0) + f.topOffset + f.bottomOffset) -- 8 is the cussion of the f.holderFrame

	if E.embeddedInSarychUI then
		B:ApplySarychUIBagChrome(f)
		B:ApplyBagWindowFonts()
	end
end

function B:UpdateKeySlot(slotID)
	assert(slotID)
	local bagID = KEYRING_CONTAINER
	local texture, count, locked = GetContainerItemInfo(bagID, slotID)
	local clink = GetContainerItemLink(bagID, slotID)
	local slot = _G["ElvUIKeyFrameItem"..slotID]
	if not slot then return end

	B:EnsureSlotLayers(slot)

	slot:Show()
	slot.questIcon:Hide()

	slot.name, slot.rarity, slot.locked = nil, nil, locked

	if clink then
		local name, _, rarity = GetItemInfo(clink)
		local isQuestItem, questId, isActiveQuest = GetContainerItemQuestInfo(bagID, slotID)

		slot.name, slot.rarity = name, rarity

		if B.db.questIcon and (questId and not isActiveQuest) then
			slot.questIcon:Show()
		end

		-- color slot according to item quality
		if B.db.questItemColors and (questId and not isActiveQuest) then
			slot:SetBackdropBorderColor(unpack(B.QuestColors.questStarter))
			slot.ignoreBorderColors = true
		elseif B.db.questItemColors and (questId or isQuestItem) then
			slot:SetBackdropBorderColor(unpack(B.QuestColors.questItem))
			slot.ignoreBorderColors = true
		elseif B.db.qualityColors and (slot.rarity and slot.rarity > 1) then
			slot:SetBackdropBorderColor(GetItemQualityColor(slot.rarity))
			slot.ignoreBorderColors = true
		else
			slot:SetBackdropBorderColor(GetBagDefaultBorder())
			slot.ignoreBorderColors = nil
		end
	else
		slot:SetBackdropBorderColor(GetBagDefaultBorder())
		slot.ignoreBorderColors = nil
	end

	if texture then
		B:PreferSarychUICooldown(slot.cooldown)
		local start, duration, enable = GetContainerItemCooldown(bagID, slotID)
		CooldownFrame_SetTimer(slot.cooldown, start, duration, enable)
		if duration > 0 and enable == 0 then
			SetItemButtonTextureVertexColor(slot, 0.4, 0.4, 0.4)
		else
			SetItemButtonTextureVertexColor(slot, 1, 1, 1)
		end

		SetItemButtonTexture(slot, texture)
		if slot.iconTexture then
			slot.iconTexture:Show()
			slot.iconTexture:SetTexture(texture)
			slot.iconTexture:SetTexCoord(unpack(E.TexCoords))
		end
		if slot.Count then
			slot.Count:Show()
		end
		SetItemButtonCount(slot, count or 0)
		SetItemButtonDesaturated(slot, slot.locked)
	else
		B:ClearEmptySlotVisuals(slot)
	end

	B:ClearSlotTransientVisuals(slot)
end

function B:UpdateAll()
	if B.BagFrame then B:Layout() end
	if B.BankFrame then B:Layout(true) end
end

function B:OnEvent(event, ...)
	if event == "ITEM_LOCK_CHANGED" or event == "ITEM_UNLOCKED" then
		local bag, slot = ...
		if bag == KEYRING_CONTAINER then
			B:UpdateKeySlot(slot)
		elseif bag and slot then
			B:UpdateSlot(self, bag, slot)
		end
		if event == "ITEM_UNLOCKED" and B:RefreshAdditionalSplitLayout(self, event) then
			if B:IsSearching() then B:RefreshSearch() end
			return
		end
	elseif event == "BAG_UPDATE" then
		local bag = ...
		if bag == KEYRING_CONTAINER then
			for slotID = 1, GetKeyRingSize() do
				B:UpdateKeySlot(slotID)
			end
		end

		for _, bagID in ipairs(self.BagIDs) do
			local numSlots = GetContainerNumSlots(bagID)
			if (not self.Bags[bagID] and numSlots ~= 0) or (self.Bags[bagID] and numSlots ~= self.Bags[bagID].numSlots) then
				B:Layout(self.isBank)
				return
			end
		end

		if bag and self.Bags[bag] then
			B:UpdateBagSlots(self, bag)
		else
			B:UpdateAllSlots(self)
		end

		if self.isBank and B.bankIsOpen then
			B:CacheBankContents()
		end

		if B:RefreshAdditionalSplitLayout(self, "bag-update") then
			if B:IsSearching() then B:RefreshSearch() end
			return
		end

		if B:IsSearching() then B:RefreshSearch() end
	elseif event == "BAG_UPDATE_COOLDOWN" then
		if not self:IsShown() then return end
		B:UpdateCooldowns(self)
	elseif event == "PLAYERBANKSLOTS_CHANGED" then
		B:UpdateBagSlots(self, -1)
		if B.bankIsOpen then
			B:CacheBankContents()
		end
	elseif (event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_LOG_UPDATE") and self:IsShown() then
		if not B:RefreshAdditionalSplitLayout(self, event) then
			B:UpdateAllSlots(self)
		end
		for slotID = 1, GetKeyRingSize() do
			B:UpdateKeySlot(slotID)
		end
	end
end

function B:UpdateTokens()
	local f = B.BagFrame
	if not f or not f.currencyButton then return end

	local numTokens = 0
	for i = 1, MAX_WATCHED_TOKENS do
		local name, count, cType, icon, itemID = GetBackpackCurrencyInfo(i)
		local button = f.currencyButton[i]
		if not button then break end

		if cType == 1 then
			icon = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
		elseif cType == 2 then
			icon = "Interface\\PVPFrame\\PVP-Currency-"..E.myfaction
		end

		button:ClearAllPoints()
		if name then
			button.icon:SetTexture(icon)
			button.currencyName = name
			button.itemID = itemID
			button.text:SetText(tostring(count))
			button:Show()
			numTokens = numTokens + 1
		else
			button.currencyName = nil
			button.itemID = nil
			button.text:SetText("")
			button:Hide()
		end
	end

	-- Footer always reserves space for money (+ currencies when watched).
	local wantFooter = E.embeddedInSarychUI or numTokens > 0
	local newBottom = wantFooter and (E.embeddedInSarychUI and B:GetSarychUIBagFooterHeight() or 28) or 8
	local shown = f.currencyButton:IsShown()
	if numTokens > 0 and not shown then
		f.bottomOffset = newBottom
		f.currencyButton:Show()
		B:Layout()
	elseif numTokens == 0 and shown then
		f.bottomOffset = newBottom
		f.currencyButton:Hide()
		B:Layout()
	else
		f.bottomOffset = newBottom
	end

	if E.embeddedInSarychUI then
		B:LayoutSarychUIBagFooter(f)
	elseif numTokens > 0 then
		B:LayoutCurrencyTokens(f, numTokens)
	end
end

function B:Token_OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetBackpackToken(self:GetID())
end

function B:Token_OnClick()
	if IsModifiedClick("CHATLINK") then
		ChatEdit_InsertLink(select(2, GetItemInfo(self.itemID)))
	end
end

function B:GetStackFontSize()
	local elvui = B:EnsureElvUISettingsTable()
	if elvui and tonumber(elvui.stackFontSize) then
		return elvui.stackFontSize
	end
	return (E.db and E.db.bags and E.db.bags.countFontSize) or 13
end

function B:GetItemLevelFontSize()
	local elvui = B:EnsureElvUISettingsTable()
	if elvui and tonumber(elvui.itemLevelFontSize) then
		return elvui.itemLevelFontSize
	end
	return (E.db and E.db.bags and E.db.bags.itemLevelFontSize) or 13
end

function B:FormatBagMoney(amount)
	amount = amount or 0
	local size = B:GetFooterStyle().moneyIcon
	local iconCopper = format("|TInterface\\MoneyFrame\\UI-CopperIcon:%d:%d|t", size, size)
	local iconSilver = format("|TInterface\\MoneyFrame\\UI-SilverIcon:%d:%d|t", size, size)
	local iconGold = format("|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d|t", size, size)

	local value = abs(amount)
	local gold = floor(value / 10000)
	local silver = floor((value / 100) % 100)
	local copper = floor(value % 100)

	local str = ""
	if gold > 0 then
		str = format("%d%s%s", gold, iconGold, (silver > 0 or copper > 0) and " " or "")
	end
	if silver > 0 then
		str = format("%s%d%s%s", str, silver, iconSilver, copper > 0 and " " or "")
	end
	if copper > 0 or value == 0 then
		str = format("%s%d%s", str, copper, iconCopper)
	end
	return str
end

function B:UpdateGoldText()
	if not B.BagFrame or not B.BagFrame.goldText then return end

	local money = GetMoney()
	if E.embeddedInSarychUI then
		B.BagFrame.goldText:SetText(B:FormatBagMoney(money))
		B:LayoutSarychUIBagFooter(B.BagFrame)
	else
		B.BagFrame.goldText:SetText(E:FormatMoney(money, E.db.bags.moneyFormat, not E.db.bags.moneyCoins))
	end
end

function B:FormatMoney(amount)
	local str, coppername, silvername, goldname = "", "|cffeda55fc|r", "|cffc7c7cfs|r", "|cffffd700g|r"

	local value = abs(amount)
	local gold = floor(value / 10000)
	local silver = floor((value / 100) % 100)
	local copper = floor(value % 100)

	if gold > 0 then
		str = format("%d%s%s", gold, goldname, (silver > 0 or copper > 0) and " " or "")
	end
	if silver > 0 then
		str = format("%s%d%s%s", str, silver, silvername, copper > 0 and " " or "")
	end
	if copper > 0 or value == 0 then
		str = format("%s%d%s", str, copper, coppername)
	end

	return str
end

function B:GetGraysInfo()
	if #self.SellFrame.Info.itemList > 0 then
		twipe(self.SellFrame.Info.itemList)
	end

	local itemList = self.SellFrame.Info.itemList
	local value = 0

	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local itemID = GetContainerItemID(bag, slot)

			if itemID then
				local _, link, rarity, _, _, iType, _, _, _, _, itemPrice = GetItemInfo(itemID)

				if (rarity and rarity == 0) and (iType and iType ~= "Quest") and (itemPrice and itemPrice > 0) then
					local stackCount = select(2, GetContainerItemInfo(bag, slot)) or 1
					itemPrice = itemPrice * stackCount

					value = value + itemPrice
					tinsert(itemList, {bag, slot, link, itemPrice, stackCount})
				end
			end
		end
	end

	return #itemList, value
end

function B:VendorGrays(delete)
	if self.SellFrame:IsShown() then return end

	local itemCount = #self.SellFrame.Info.itemList
	if itemCount == 0 then return end

	local info = self.SellFrame.Info

	info.delete = delete or false
	info.SellTimer = 0
	info.ProgressMax = itemCount
	info.ProgressTimer = (itemCount - 1) * info.SellInterval
	info.UpdateTimer = 0
	info.goldGained = 0
	info.itemsSold = 0

	self.SellFrame.statusbar:SetValue(0)
	self.SellFrame.statusbar:SetMinMaxValues(0, itemCount)
	self.SellFrame.statusbar.ValueText:SetFormattedText("0 / %d", itemCount)

	self.SellFrame:Show()
end

function B:VendorGrayCheck()
	local itemCount, value = B:GetGraysInfo()

	if itemCount == 0 then
		E:Print(L["No gray items to delete."])
	elseif not MerchantFrame:IsShown() then
		E.PopupDialogs.DELETE_GRAYS.Money = value
		E:StaticPopup_Show("DELETE_GRAYS")
	else
		B:VendorGrays()
	end
end

function B:ContructContainerFrame(name, isBank)
	local strata = B:GetSarychUIBagFrameStrata()

	local f = CreateFrame("Button", name, E.UIParent)
	f:SetTemplate("Transparent")
	f:SetFrameStrata(strata)
	f:RegisterEvent("BAG_UPDATE") -- Has to be on both frames
	f:RegisterEvent("BAG_UPDATE_COOLDOWN") -- Has to be on both frames
	f.events = isBank and {"PLAYERBANKSLOTS_CHANGED"} or {"ITEM_LOCK_CHANGED", "ITEM_UNLOCKED", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE"}

	for _, event in ipairs(f.events) do
		f:RegisterEvent(event)
	end

	f:SetScript("OnEvent", B.OnEvent)
	f:Hide()

	f.isBank = isBank
	f.bottomOffset = isBank and 8 or 28
	f.topOffset = 50
	if E.embeddedInSarychUI then
		-- Talented chrome: title + toolbar (+ classic slots top pad when categories off)
		local titleH = GetBagTitleBarH()
		f.suiHeaderH = titleH
		f.topOffset = GetBagContentTopOffset(f)
		if not isBank then
			f.bottomOffset = B:GetSarychUIBagFooterHeight()
		end
	end
	f.BagIDs = isBank and {-1, 5, 6, 7, 8, 9, 10, 11} or {0, 1, 2, 3, 4}
	f.Bags = {}

	local mover = (isBank and ElvUIBankMover) or ElvUIBagMover
	if E.embeddedInSarychUI and isBank then
		B:ApplyElvUIBankWindowPosition(f)
	elseif E.embeddedInSarychUI and not isBank then
		B:ApplyElvUIBagWindowPosition(f)
	elseif mover and mover.POINT then
		f:Point(mover.POINT, mover)
		f.mover = mover
	end

	if E.embeddedInSarychUI then
		B:ApplySarychUIBagFrameLayers(f)
	else
		f:SetMovable(true)
		f:SetClampedToScreen(true)
		f:RegisterForDrag("LeftButton", "RightButton")
		f:RegisterForClicks("AnyUp")
		f:SetScript("OnDragStart", function(frame) if IsShiftKeyDown() then frame:StartMoving() end end)
		f:SetScript("OnDragStop", B.OnElvUIBagFrameDragStop)
		f:SetScript("OnClick", function(frame, button)
			B:HandleBagFrameControlClick(frame, button)
		end)
	end

	f.closeButton = CreateFrame("Button", name.."CloseButton", f, "UIPanelCloseButton")
	f.closeButton:Point("TOPRIGHT", 0, 2)

	if E.embeddedInSarychUI then
		-- Title bar + SarychUI "X" close applied in EnsureSarychUIBagTitleBar
	else
		Skins:HandleCloseButton(f.closeButton)
	end
	f.closeButton:SetScript("OnClick", function()
		B:HideBagMoveTooltip()
		PlaySound("igMainMenuClose")
		f:Hide()
	end)

	f.holderFrame = CreateFrame("Frame", nil, f)
	f.holderFrame:Point("TOP", f, "TOP", 0, -f.topOffset)
	f.holderFrame:Point("BOTTOM", f, "BOTTOM", 0, 8)

	f.dragHeader = CreateFrame("Frame", name.."DragHeader", f)
	if E.embeddedInSarychUI then
		B:SetupSarychUIBagFrameDrag(f)
	else
		f.dragHeader:EnableMouse(true)
		f.dragHeader:RegisterForDrag("LeftButton", "RightButton")
		f.dragHeader:SetScript("OnDragStart", function()
			B:HideBagMoveTooltip()
			if IsShiftKeyDown() then
				f:StartMoving()
			end
		end)
		f.dragHeader:SetScript("OnDragStop", function()
			B.OnElvUIBagFrameDragStop(f)
		end)
		f.dragHeader:SetScript("OnMouseUp", function(_, button)
			B:HandleBagFrameControlClick(f, button)
		end)
		f.dragHeader:SetScript("OnEnter", function(header)
			B:ShowBagMoveTooltip(header)
		end)
		f.dragHeader:SetScript("OnLeave", B.HideBagMoveTooltip)
	end

	f.ContainerHolder = CreateFrame("Button", name.."ContainerHolder", f)
	f.ContainerHolder:Point("BOTTOMLEFT", f, "TOPLEFT", 0, 1)
	f.ContainerHolder:SetTemplate("Transparent")
	f.ContainerHolder:Hide()

	if isBank then
		--Bag Text
		f.bagText = f:CreateFontString(nil, "OVERLAY")
		f.bagText:FontTemplate()
		f.bagText:Point("BOTTOMRIGHT", f.holderFrame, "TOPRIGHT", -2, 4)
		f.bagText:SetJustifyH("RIGHT")
		f.bagText:SetText(L["Bank"])

		--Sort Button
		f.sortButton = CreateFrame("Button", name.."SortButton", f)
		f.sortButton:Size(16 + E.Border)
		f.sortButton:SetTemplate()
		f.sortButton:Point("RIGHT", f.bagText, "LEFT", -5, E.Border * 2)
		SetupIconButton(f.sortButton, E.Media.Textures.Broom, true)
		f.sortButton:StyleButton(nil, true)
		f.sortButton.ttText = L["Sort Bags"]
		f.sortButton:SetScript("OnEnter", self.Tooltip_Show)
		f.sortButton:SetScript("OnLeave", GameTooltip_Hide)
		f.sortButton:SetScript("OnClick", function()
			B:HandleSortButtonClick(f, "bank")
		end)
		if E.db.bags.disableBankSort then
			f.sortButton:Disable()
		end

		--Toggle Bags Button
		f.bagsButton = CreateFrame("Button", name.."BagsButton", f.holderFrame)
		f.bagsButton:Size(16 + E.Border)
		f.bagsButton:SetTemplate()
		f.bagsButton:Point("RIGHT", f.sortButton, "LEFT", -5, 0)
		SetupIconButton(f.bagsButton, "Interface\\Buttons\\Button-Backpack-Up")
		f.bagsButton:StyleButton(nil, true)
		f.bagsButton.ttText = L["Toggle Bags"]
		f.bagsButton:SetScript("OnEnter", B.Tooltip_Show)
		f.bagsButton:SetScript("OnLeave", GameTooltip_Hide)
		f.bagsButton:SetScript("OnClick", function()
			local numSlots = GetNumBankSlots()
			if E.embeddedInSarychUI and not B.bankIsOpen then
				-- Offline strip always has main bank (+ any cached bags).
				numSlots = B:GetOfflineNumBankSlots() + 1
			end
			PlaySound("igMainMenuOption")
			if numSlots >= 1 then
				ToggleFrame(f.ContainerHolder)
			else
				E:StaticPopup_Show("NO_BANK_BAGS")
			end
		end)

		--Purchase Bags Button
		f.purchaseBagButton = CreateFrame("Button", nil, f.holderFrame)
		f.purchaseBagButton:Size(16 + E.Border)
		f.purchaseBagButton:SetTemplate()
		f.purchaseBagButton:Point("RIGHT", f.bagsButton, "LEFT", -5, 0)
		SetupIconButton(f.purchaseBagButton, "Interface\\ICONS\\INV_Misc_Coin_01")
		f.purchaseBagButton:StyleButton(nil, true)
		f.purchaseBagButton.ttText = L["Purchase Bags"]
		f.purchaseBagButton:SetScript("OnEnter", B.Tooltip_Show)
		f.purchaseBagButton:SetScript("OnLeave", GameTooltip_Hide)
		f.purchaseBagButton:SetScript("OnClick", function()
			local _, full = GetNumBankSlots()
			if full then
				E:StaticPopup_Show("CANNOT_BUY_BANK_SLOT")
			else
				E:StaticPopup_Show("BUY_BANK_SLOT")
			end
		end)

		f:SetScript("OnShow", B.RefreshSearch)
		f:SetScript("OnHide", function()
			B:HideBagMoveTooltip()
			B:StopSortSpinner(f)
			-- Only close the real bank session when we were actually at a banker.
			if B.bankIsOpen then
				CloseBankFrame()
			end
			B.bankOfflineView = false
			B:UpdateBankTitle()

			if E.db.bags.clearSearchOnClose then
				B.ResetAndClear(f.editBox)
			end
		end)

		--Search
		f.editBox = CreateFrame("EditBox", name.."EditBox", f)
		f.editBox:SetFrameLevel(f.editBox:GetFrameLevel() + 2)
		f.editBox:CreateBackdrop()
		f.editBox.backdrop:Point("TOPLEFT", f.editBox, "TOPLEFT", -20, 2)
		f.editBox:Height(15)
		f.editBox:Point("BOTTOMLEFT", f.holderFrame, "TOPLEFT", (E.Border * 2) + 18, E.Border * 2 + 2)
		f.editBox:Point("RIGHT", f.purchaseBagButton, "LEFT", -5, 0)
		f.editBox:SetAutoFocus(false)
		f.editBox:SetScript("OnEscapePressed", B.ResetAndClear)
		f.editBox:SetScript("OnEnterPressed", function(eb) eb:ClearFocus() end)
		f.editBox:SetScript("OnEditFocusGained", f.editBox.HighlightText)
		f.editBox:SetScript("OnTextChanged", B.UpdateSearch)
		f.editBox:SetScript("OnChar", B.UpdateSearch)
		f.editBox:SetText(SEARCH)
		f.editBox:FontTemplate()

		f.editBox.searchIcon = f.editBox:CreateTexture(nil, "OVERLAY")
		f.editBox.searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
		f.editBox.searchIcon:Point("LEFT", f.editBox.backdrop, "LEFT", E.Border + 1, -1)
		f.editBox.searchIcon:Size(15)
	else
		f.keyFrame = CreateFrame("Frame", name.."KeyFrame", f)
		f.keyFrame:Point("TOPRIGHT", f, "TOPLEFT", -(E.PixelMode and 1 or 3), 0)
		f.keyFrame:SetTemplate("Transparent")
		f.keyFrame:SetID(KEYRING_CONTAINER)
		f.keyFrame.slots = {}
		f.keyFrame:Hide()

		--Gold Text
		f.goldText = f:CreateFontString(nil, "OVERLAY")
		f.goldText:FontTemplate()
		f.goldText:Point("BOTTOMRIGHT", f.holderFrame, "TOPRIGHT", -2, 4)
		f.goldText:SetJustifyH("RIGHT")

		--Sort Button
		f.sortButton = CreateFrame("Button", name.."SortButton", f)
		f.sortButton:Size(16 + E.Border)
		f.sortButton:SetTemplate()
		f.sortButton:Point("RIGHT", f.goldText, "LEFT", -5, E.Border * 2)
		SetupIconButton(f.sortButton, E.Media.Textures.Broom, true)
		f.sortButton:StyleButton(nil, true)
		f.sortButton.ttText = L["Sort Bags"]
		f.sortButton:SetScript("OnEnter", self.Tooltip_Show)
		f.sortButton:SetScript("OnLeave", GameTooltip_Hide)
		f.sortButton:SetScript("OnClick", function()
			B:HandleSortButtonClick(f, "bags")
		end)
		if B:IsBagSortHidden() then
			f.sortButton:Disable()
		else
			f.sortButton:Enable()
			f.sortButton:Show()
		end

		--Key Button
		f.keyButton = CreateFrame("Button", name.."KeyButton", f)
		f.keyButton:Size(16 + E.Border)
		f.keyButton:SetTemplate()
		f.keyButton:Point("RIGHT", f.sortButton, "LEFT", -5, 0)
		SetupIconButton(f.keyButton, "Interface\\ICONS\\INV_Misc_Key_14")
		f.keyButton:StyleButton(nil, true)
		f.keyButton.ttText = BINDING_NAME_TOGGLEKEYRING
		f.keyButton:SetScript("OnEnter", self.Tooltip_Show)
		f.keyButton:SetScript("OnLeave", GameTooltip_Hide)
		f.keyButton:SetScript("OnClick", function() ToggleFrame(f.keyFrame) end)

		--Bags Button
		f.bagsButton = CreateFrame("Button", name.."BagsButton", f)
		f.bagsButton:Size(16 + E.Border)
		f.bagsButton:SetTemplate()
		f.bagsButton:Point("RIGHT", f.keyButton, "LEFT", -5, 0)
		SetupIconButton(f.bagsButton, "Interface\\Buttons\\Button-Backpack-Up")
		f.bagsButton:StyleButton(nil, true)
		f.bagsButton.ttText = L["Toggle Bags"]
		f.bagsButton:SetScript("OnEnter", B.Tooltip_Show)
		f.bagsButton:SetScript("OnLeave", GameTooltip_Hide)
		f.bagsButton:SetScript("OnClick", function() ToggleFrame(f.ContainerHolder) end)

		-- View Bank (Baud Bag-style anytime bank from cache)
		if E.embeddedInSarychUI then
			f.bankButton = CreateFrame("Button", name.."BankButton", f)
			f.bankButton:Size(16 + E.Border)
			f.bankButton:SetTemplate()
			f.bankButton:Point("RIGHT", f.bagsButton, "LEFT", -5, 0)
			SetupIconButton(f.bankButton, "Interface\\Icons\\INV_Box_02")
			f.bankButton:StyleButton(nil, true)
			local locale = GetLocale and GetLocale() or "enUS"
			f.bankButton.ttText = (locale == "ruRU") and "Показать банк" or "Show Bank"
			f.bankButton:SetScript("OnEnter", B.Tooltip_Show)
			f.bankButton:SetScript("OnLeave", GameTooltip_Hide)
			f.bankButton:SetScript("OnClick", function()
				PlaySound("igMainMenuOption")
				B:ToggleBankView()
			end)
		end

		--Vendor Grays
		f.vendorGraysButton = CreateFrame("Button", nil, f.holderFrame)
		f.vendorGraysButton:Size(16 + E.Border)
		f.vendorGraysButton:SetTemplate()
		f.vendorGraysButton:Point("RIGHT", (f.bankButton or f.bagsButton), "LEFT", -5, 0)
		SetupIconButton(f.vendorGraysButton, "Interface\\ICONS\\INV_Misc_Coin_01")
		f.vendorGraysButton:StyleButton(nil, true)
		f.vendorGraysButton.ttText = L["Vendor / Delete Grays"]
		f.vendorGraysButton:SetScript("OnEnter", B.Tooltip_Show)
		f.vendorGraysButton:SetScript("OnLeave", GameTooltip_Hide)
		f.vendorGraysButton:SetScript("OnClick", B.VendorGrayCheck)

		-- Toggle AdiBags-like categorical layout (SarychUI only)
		if E.embeddedInSarychUI then
			f.sectionSplitButton = CreateFrame("Button", name.."SectionSplitButton", f.holderFrame)
			f.sectionSplitButton:Size(16 + E.Border)
			f.sectionSplitButton:SetTemplate()
			f.sectionSplitButton:Point("RIGHT", f.vendorGraysButton, "LEFT", -5, 0)
			SetupIconButton(f.sectionSplitButton, "Interface\\Icons\\INV_Misc_Book_09")
			f.sectionSplitButton:StyleButton(nil, true)
			f.sectionSplitButton:SetScript("OnEnter", B.Tooltip_Show)
			f.sectionSplitButton:SetScript("OnLeave", GameTooltip_Hide)
			f.sectionSplitButton:SetScript("OnClick", function()
				B:ToggleSectionSplitMode()
			end)
			B:UpdateSectionSplitButton(f.sectionSplitButton)
		end

		--Search
		f.editBox = CreateFrame("EditBox", name.."EditBox", f)
		f.editBox:SetFrameLevel(f.editBox:GetFrameLevel() + 2)
		f.editBox:CreateBackdrop()
		f.editBox.backdrop:Point("TOPLEFT", f.editBox, "TOPLEFT", -20, 2)
		f.editBox:Height(15)
		f.editBox:Point("BOTTOMLEFT", f.holderFrame, "TOPLEFT", (E.Border * 2) + 18, E.Border * 2 + 2)
		f.editBox:Point("RIGHT", (f.sectionSplitButton or f.vendorGraysButton), "LEFT", -5, 0)
		f.editBox:SetAutoFocus(false)
		f.editBox:SetScript("OnEscapePressed", B.ResetAndClear)
		f.editBox:SetScript("OnEnterPressed", function(eb) eb:ClearFocus() end)
		f.editBox:SetScript("OnEditFocusGained", f.editBox.HighlightText)
		f.editBox:SetScript("OnTextChanged", B.UpdateSearch)
		f.editBox:SetScript("OnChar", B.UpdateSearch)
		f.editBox:SetText(SEARCH)
		f.editBox:FontTemplate()

		f.editBox.searchIcon = f.editBox:CreateTexture(nil, "OVERLAY")
		f.editBox.searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
		f.editBox.searchIcon:Point("LEFT", f.editBox.backdrop, "LEFT", E.Border + 1, -1)
		f.editBox.searchIcon:Size(15)

		--Currency
		f.currencyButton = CreateFrame("Frame", nil, f)
		f.currencyButton:Point("BOTTOM", 0, 4)
		f.currencyButton:Point("TOPLEFT", f.holderFrame, "BOTTOMLEFT", 0, 18)
		f.currencyButton:Point("TOPRIGHT", f.holderFrame, "BOTTOMRIGHT", 0, 18)
		f.currencyButton:Height(22)

		for i = 1, MAX_WATCHED_TOKENS do
			f.currencyButton[i] = CreateFrame("Button", name.."CurrencyButton"..i, f.currencyButton)
			f.currencyButton[i]:Size(16)
			if not E.embeddedInSarychUI then
				f.currencyButton[i]:SetTemplate()
			end
			f.currencyButton[i]:SetID(i)
			f.currencyButton[i].icon = f.currencyButton[i]:CreateTexture(nil, "OVERLAY")
			f.currencyButton[i].icon:SetInside()
			f.currencyButton[i].icon:SetTexCoord(unpack(E.TexCoords))
			f.currencyButton[i].text = f.currencyButton[i]:CreateFontString(nil, "OVERLAY")
			f.currencyButton[i].text:Point("LEFT", f.currencyButton[i], "RIGHT", 2, 0)
			f.currencyButton[i].text:FontTemplate()

			f.currencyButton[i]:SetScript("OnEnter", B.Token_OnEnter)
			f.currencyButton[i]:SetScript("OnLeave", GameTooltip_Hide)
			f.currencyButton[i]:SetScript("OnClick", B.Token_OnClick)
			f.currencyButton[i]:Hide()
		end

		f:SetScript("OnShow", B.RefreshSearch)
		f:SetScript("OnHide", function()
			B:HideBagMoveTooltip()
			B:StopSortSpinner(f)
			CloseBackpack()
			for i = 1, NUM_BAG_FRAMES do
				CloseBag(i)
			end

			B:UpdateBlizzardBagButtonCheckedState()

			if E.db.bags.clearSearchOnClose then
				B.ResetAndClear(f.editBox)
			end
		end)
	end

	B:ConfigureHeaderLayers(f)
	if E.embeddedInSarychUI then
		B:ApplySarychUIBagChrome(f)
		B:ApplyBagWindowFonts()
	end

	tinsert(UISpecialFrames, f:GetName())
	tinsert(B.BagFrames, f)
	return f
end

function B:OpenBagsFromShiftClick()
	shiftDebug("Open unified bags from shift-click")
	B:OpenBags()
	PlaySound("igBackPackOpen")
	B:UpdateBlizzardBagButtonCheckedState()
end

function B:OnBagSlotButtonModifiedClick()
	if not self:IsElvUIBagsActive() then return end
	if IsModifiedClick("OPENALLBAGS") then
		shiftDebug("ToggleBag shift=true (bag slot modified click)")
		self:OpenBagsFromShiftClick()
	end
end

function B:OnBackpackButtonModifiedClick()
	if not self:IsElvUIBagsActive() then return end
	if IsModifiedClick("OPENALLBAGS") then
		shiftDebug("ToggleBackpack shift=true (backpack modified click)")
		self:OpenBagsFromShiftClick()
	end
end

function B:ToggleBags(id)
	if not self:IsElvUIBagsActive() then return end
	if id and (GetContainerNumSlots(id) == 0) then return end --Closes a bag when inserting a new container..

	-- ToggleBackpack() calls ToggleBag(0) before our ToggleBackpack hook runs.
	-- Handling bagID 0 here would open unified bags and then ToggleBackpack immediately closes them.
	if id == 0 then
		buttonDebug("ToggleBag bagID=0 skipped (handled by ToggleBackpack)")
		return
	end

	buttonDebug("ToggleBag bagID=", tostring(id), "shift=", tostring(IsShiftKeyDown()))

	if IsShiftKeyDown() or IsModifiedClick("OPENALLBAGS") then
		shiftDebug("ToggleBag bagID=", tostring(id), "shift=true")
		B:OpenBagsFromShiftClick()
		return
	end

	if B.BagFrame and B.BagFrame:IsShown() then
		B:CloseBags()
	else
		B:OpenBags()
	end
end

function B:ToggleBackpack()
	if IsOptionFrameOpen() then return end
	if not self:IsElvUIBagsActive() then return end

	buttonDebug("ToggleBackpack shift=", tostring(IsShiftKeyDown()))

	if IsShiftKeyDown() or IsModifiedClick("OPENALLBAGS") then
		shiftDebug("ToggleBackpack shift=true")
		B:OpenBagsFromShiftClick()
		return
	end

	if B.BagFrame and B.BagFrame:IsShown() then
		B:CloseBags()
		PlaySound("igBackPackClose")
	else
		B:OpenBags()
		PlaySound("igBackPackOpen")
	end
end

function B:OpenAllBags(forceOpen)
	if not self:IsElvUIBagsActive() then
		-- Classic / disabled ElvUI bags: fall through to Blizzard.
		if self.hooks and self.hooks.OpenAllBags then
			return self.hooks.OpenAllBags(forceOpen)
		end
		return
	end
	if not UIParent:IsShown() then return end

	shiftDebug("OpenAllBags forceOpen=", tostring(forceOpen))

	local isOpen = B.BagFrame and B.BagFrame:IsShown()
	if forceOpen or not isOpen then
		B:OpenBags()
		PlaySound("igBackPackOpen")
	elseif isOpen then
		B:CloseBags()
		PlaySound("igBackPackClose")
	end
end

function B:ToggleSortButtonState(isBank)
	local button, disable
	if isBank and B.BankFrame then
		button = B.BankFrame.sortButton
		disable = E.db.bags.disableBankSort
	elseif not isBank and B.BagFrame then
		button = B.BagFrame.sortButton
		disable = B:IsBagSortHidden()
	end

	if button and disable then
		button:Disable()
	elseif button then
		button:Enable()
		button:Show()
	end
end

function B:OpenBags()
	if not B.BagFrame then return end

	if E.embeddedInSarychUI then
		B:ApplySarychUIBagFrameLayers(B.BagFrame)
		B:WarmAdiBagsLayoutCaches(B.BagFrame)
	end

	if B.Layout then
		B:Layout()
	end
	B:UpdateTokens()
	if E.embeddedInSarychUI then
		B:ApplySarychUIBagChrome(B.BagFrame)
		B:UpdateGoldText()
	end
	B.BagFrame:Show()
	bagDebug("Open unified bags")
	B:UpdateBlizzardBagButtonCheckedState()
end

function B:CloseBags()
	if B.BagFrame then
		B:StopSortSpinner(B.BagFrame)
		B.BagFrame:Hide()
	end

	if B.BankFrame then
		B:StopSortSpinner(B.BankFrame)
		B.BankFrame:Hide()
	end

	B:UpdateBlizzardBagButtonCheckedState()
end

function B:UpdateBankTitle()
	if not B.BankFrame or not E.embeddedInSarychUI then return end
	local locale = GetLocale and GetLocale() or "enUS"
	local base = (locale == "ruRU") and "Банк" or (L["Bank"] or BANK or "Bank")
	local offline = B.bankOfflineView or (B.BankFrame:IsShown() and not B.bankIsOpen)
	local title = offline and (base .. ((locale == "ruRU") and " (оффлайн)" or " (Offline)")) or base
	if B.BankFrame.suiTitle then
		B.BankFrame.suiTitle:SetText(title)
		SoftFont(B.BankFrame.suiTitle, 12)
		local accent = ThemeColor("accent", ThemeColor("title", { 0.95, 0.78, 0.15, 1 }))
		if offline then
			local dim = ThemeColor("textDim", { 0.65, 0.65, 0.68, 1 })
			B.BankFrame.suiTitle:SetTextColor(dim[1], dim[2], dim[3], 1)
		else
			B.BankFrame.suiTitle:SetTextColor(accent[1], accent[2], accent[3], 1)
		end
	elseif B.BankFrame.bagText then
		B.BankFrame.bagText:SetText(title)
	end
end

function B:OpenOfflineBank()
	if not E.embeddedInSarychUI then return end
	if not B:HasBankCache() then
		local locale = GetLocale and GetLocale() or "enUS"
		local msg = (locale == "ruRU")
			and "Сначала откройте банк у банкира — содержимое сохранится для просмотра."
			or "Visit a banker once to cache your bank for offline viewing."
		if SarychUI and SarychUI.Print then
			SarychUI:Print(msg)
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1SarychUI|r: "..msg)
		end
		return
	end

	B.bankOfflineView = true
	if not B.BankFrame then
		B.BankFrame = B:ContructContainerFrame("ElvUI_BankContainerFrame", true)
	end
	B:Layout(true)
	if B.UpdateAllSlots then
		B:UpdateAllSlots(B.BankFrame)
	end
	B:ApplyElvUIBankWindowPosition(B.BankFrame)
	B:ApplySarychUIBagChrome(B.BankFrame)
	B:UpdateBankTitle()
	B:UpdateBankInteractionButtons()
	B.BankFrame:Show()
end

function B:ToggleBankView()
	if not E.embeddedInSarychUI then return end
	if B.BankFrame and B.BankFrame:IsShown() then
		B.BankFrame:Hide()
		return
	end
	if B.bankIsOpen then
		B:OpenBank()
	else
		B:OpenOfflineBank()
	end
end

function B:OpenBank()
	local alreadyOpen = B.bankIsOpen and B.BankFrame and B.BankFrame:IsShown()
	B.bankIsOpen = true
	B.bankOfflineView = false

	-- BaudBag: keep Blizzard bank from receiving OPENED (OnHide would CloseBankFrame).
	if BankFrame then
		BankFrame:UnregisterEvent("BANKFRAME_OPENED")
	end

	if not B.BankFrame then
		B.BankFrame = B:ContructContainerFrame("ElvUI_BankContainerFrame", true)
	end

	--Call :Layout first so all elements are created before we update
	B:Layout(true)

	B:OpenBags()
	B:UpdateTokens()
	B:CacheBankContents()

	if E.embeddedInSarychUI then
		B:ApplyElvUIBankWindowPosition(B.BankFrame)
		B:UpdateBankTitle()
		B:UpdateBankInteractionButtons()
	end

	B.BankFrame:Show()
	-- Default BankFrame_OnShow sound (Blizzard bank UI is suppressed).
	if not alreadyOpen then
		PlaySound("igMainMenuOpen")
	end
	positionDebug("OpenBank", B.BankFrame)
	positionDebug("OpenBank bag ref", B.BagFrame)
end

function B:PLAYERBANKBAGSLOTS_CHANGED()
	B:Layout(true)
	if B.bankIsOpen then
		B:CacheBankContents()
	end
end

function B:GUILDBANKBAGSLOTS_CHANGED()
	B:SetGuildBankSearch(SEARCH_STRING)
end

function B:CloseBank()
	local wasLiveBank = B.bankIsOpen and B.BankFrame and B.BankFrame:IsShown()
	if B.bankIsOpen then
		B:CacheBankContents()
	end
	B.bankIsOpen = false
	B.bankOfflineView = false

	if not B.BankFrame then return end

	B.BankFrame:Hide()
	if B.BagFrame then
		B.BagFrame:Hide()
	end
	-- Default BankFrame_OnHide sound.
	if wasLiveBank then
		PlaySound("igMainMenuClose")
	end
end

function B:updateContainerFrameAnchors()
	local xOffset, yOffset, screenHeight, freeScreenHeight, leftMostPoint, column
	local screenWidth = GetScreenWidth()
	local containerScale = 1
	local leftLimit = 0

	if BankFrame:IsShown() then
		leftLimit = BankFrame:GetRight() - 25
	end

	while containerScale > CONTAINER_SCALE do
		screenHeight = GetScreenHeight() / containerScale
		-- Adjust the start anchor for bags depending on the multibars
		xOffset = CONTAINER_OFFSET_X / containerScale
		yOffset = CONTAINER_OFFSET_Y / containerScale
		-- freeScreenHeight determines when to start a new column of bags
		freeScreenHeight = screenHeight - yOffset
		leftMostPoint = screenWidth - xOffset
		column = 1

		for _, frameName in ipairs(ContainerFrame1.bags) do
			local frameHeight = _G[frameName]:GetHeight()

			if freeScreenHeight < frameHeight then
				-- Start a new column
				column = column + 1
				leftMostPoint = screenWidth - (column * CONTAINER_WIDTH * containerScale) - xOffset
				freeScreenHeight = screenHeight - yOffset
			end

			freeScreenHeight = freeScreenHeight - frameHeight - VISIBLE_CONTAINER_SPACING
		end

		if leftMostPoint < leftLimit then
			containerScale = containerScale - 0.01
		else
			break
		end
	end

	if containerScale < CONTAINER_SCALE then
		containerScale = CONTAINER_SCALE
	end

	screenHeight = GetScreenHeight() / containerScale
	-- Adjust the start anchor for bags depending on the multibars
	-- xOffset = CONTAINER_OFFSET_X / containerScale
	yOffset = CONTAINER_OFFSET_Y / containerScale
	-- freeScreenHeight determines when to start a new column of bags
	freeScreenHeight = screenHeight - yOffset
	column = 0

	local bagsPerColumn = 0
	for index, frameName in ipairs(ContainerFrame1.bags) do
		local frame = _G[frameName]
		frame:SetScale(1)

		if index == 1 then
			-- First bag
			frame:Point("BOTTOMRIGHT", ElvUIBagMover, "BOTTOMRIGHT", E.Spacing, -E.Border)
			bagsPerColumn = bagsPerColumn + 1
		elseif freeScreenHeight < frame:GetHeight() then
			-- Start a new column
			column = column + 1
			freeScreenHeight = screenHeight - yOffset
			if column > 1 then
				frame:Point("BOTTOMRIGHT", ContainerFrame1.bags[(index - bagsPerColumn) - 1], "BOTTOMLEFT", -CONTAINER_SPACING, 0)
			else
				frame:Point("BOTTOMRIGHT", ContainerFrame1.bags[index - bagsPerColumn], "BOTTOMLEFT", -CONTAINER_SPACING, 0)
			end
			bagsPerColumn = 0
		else
			-- Anchor to the previous bag
			frame:Point("BOTTOMRIGHT", ContainerFrame1.bags[index - 1], "TOPRIGHT", 0, CONTAINER_SPACING)
			bagsPerColumn = bagsPerColumn + 1
		end

		freeScreenHeight = freeScreenHeight - frame:GetHeight() - VISIBLE_CONTAINER_SPACING
	end
end

function B:PostBagMove()
	if E.embeddedInSarychUI then
		if not E:IsBagsRuntimeEnabled() then return end
	elseif not E.private or not E.private.bags or not E.private.bags.enable then
		return
	end

	-- self refers to the mover (bag or bank)
	local x, y = self:GetCenter()
	local screenHeight = E.UIParent:GetTop()
	local screenWidth = E.UIParent:GetRight()

	if y > (screenHeight / 2) then
		self:SetText(self.textGrowDown)
		self.POINT = ((x > (screenWidth / 2)) and "TOPRIGHT" or "TOPLEFT")
	else
		self:SetText(self.textGrowUp)
		self.POINT = ((x > (screenWidth / 2)) and "BOTTOMRIGHT" or "BOTTOMLEFT")
	end

	local bagFrame
	if self.name == "ElvUIBankMover" then
		bagFrame = B.BankFrame
	else
		bagFrame = B.BagFrame
	end

	if bagFrame and E.embeddedInSarychUI then
		return
	end

	if bagFrame then
		bagFrame:ClearAllPoints()
		bagFrame:Point(self.POINT, self)
	end
end

function B:MERCHANT_CLOSED()
	B.SellFrame:Hide()
end

function B:ProgressQuickVendor()
	local info = B.SellFrame.Info
	local bag, slot, link, itemPrice, stackCount = unpack(info.itemList[1])

	if info.delete then
		itemPrice = 0
		PickupContainerItem(bag, slot)
		DeleteCursorItem()
	else
		UseContainerItem(bag, slot)

		if link and info.details then
			E:Print(format("%s|cFF00DDDDx%d|r %s", link, stackCount, B:FormatMoney(itemPrice)))
		end

		E.callbacks:Fire("VendorGreys_ItemSold", itemPrice)
	end

	tremove(info.itemList, 1)

	return itemPrice, #info.itemList == 0
end

function B.VendorGreys_OnUpdate(self, elapsed)
	local info = self.Info
	info.SellTimer = info.SellTimer - elapsed

	if info.SellTimer <= 0 then
		info.SellTimer = info.SellInterval

		local goldGained, lastItem = B:ProgressQuickVendor()
		info.goldGained = info.goldGained + goldGained

		if lastItem then
			self:Hide()

			if info.goldGained > 0 then
				if SarychUI and SarychUI.PrintGrayItemsSold then
					SarychUI:PrintGrayItemsSold(info.goldGained)
				else
					E:Print(format(L["Vendored gray items for: %s"], B:FormatMoney(info.goldGained)))
				end
			end

			return
		else
			info.itemsSold = info.itemsSold + 1

			self.statusbar:SetValue(info.itemsSold)
		end
	end

	info.UpdateTimer = info.UpdateTimer + elapsed

	if info.UpdateTimer >= 0.033 then
		info.ProgressTimer = info.ProgressTimer - info.UpdateTimer
		info.UpdateTimer = 0

		self.statusbar.ValueText:SetFormattedText("%d / %d ( %.1fs )", info.itemsSold, info.ProgressMax, info.ProgressTimer + 0.05)
	end
end

function B:CreateSellFrame()
	B.SellFrame = CreateFrame("Frame", "ElvUIVendorGraysFrame", E.UIParent)
	B.SellFrame:Size(200, 40)
	B.SellFrame:SetPoint("CENTER")
	B.SellFrame:CreateBackdrop("Transparent")
	B.SellFrame:SetAlpha(E.db.bags.vendorGrays.progressBar and 1 or 0)
	B.SellFrame:Hide()

	B.SellFrame.title = B.SellFrame:CreateFontString(nil, "OVERLAY")
	B.SellFrame.title:FontTemplate(nil, 12, "OUTLINE")
	B.SellFrame.title:Point("TOP", 0, -2)
	B.SellFrame.title:SetText(L["Vendoring Grays"])

	B.SellFrame.statusbar = CreateFrame("StatusBar", "ElvUIVendorGraysFrameStatusbar", B.SellFrame)
	B.SellFrame.statusbar:Size(180, 16)
	B.SellFrame.statusbar:Point("BOTTOM", 0, 4)
	B.SellFrame.statusbar:SetStatusBarTexture(E.media.normTex)
	B.SellFrame.statusbar:SetStatusBarColor(1, 0, 0)
	B.SellFrame.statusbar:CreateBackdrop("Transparent")

	B.SellFrame.statusbar.ValueText = B.SellFrame.statusbar:CreateFontString(nil, "OVERLAY")
	B.SellFrame.statusbar.ValueText:FontTemplate(nil, 12, "OUTLINE")
	B.SellFrame.statusbar.ValueText:SetPoint("CENTER")
	B.SellFrame.statusbar.ValueText:SetText("0 / 0 ( 0s )")

	B.SellFrame.Info = {
		SellInterval = E.db.bags.vendorGrays.interval,
		details = E.db.bags.vendorGrays.details,
		itemList = {}
	}

	B.SellFrame:SetScript("OnUpdate", B.VendorGreys_OnUpdate)
end

function B:UpdateSellFrameSettings()
	if not B.SellFrame then return end

	B.SellFrame.Info.SellInterval = E.db.bags.vendorGrays.interval
	B.SellFrame.Info.details = E.db.bags.vendorGrays.details

	B.SellFrame:SetAlpha(E.db.bags.vendorGrays.progressBar and 1 or 0)
end

B.BagIndice = {
	quiver = 0x0001,
	ammoPouch = 0x0002,
	soulBag = 0x0004,
	leatherworking = 0x0008,
	inscription = 0x0010,
	herbs = 0x0020,
	enchanting = 0x0040,
	engineering = 0x0080,
	gems = 0x0200,
	mining = 0x0400,
}

B.QuestKeys = {
	questStarter = "questStarter",
	questItem = "questItem",
}

function B:UpdateBagColors(table, indice, r, g, b)
	B[table][B.BagIndice[indice]] = {r, g, b}
end

function B:UpdateQuestColors(table, indice, r, g, b)
	B[table][B.QuestKeys[indice]] = {r, g, b}
end

function B:RestoreNativeGameTooltip()
	if GameTooltip and GameTooltip.template then
		GameTooltip.template = nil
		if GameTooltip.SetBackdrop then
			GameTooltip:SetBackdrop(nil)
		end
		GameTooltip:Hide()
	end
end

function B:Initialize()
	if B.Initialized and B.BagFrame then return end
	if B.Initialized and not B.BagFrame then
		B.Initialized = false
	end

	B:RestoreNativeGameTooltip()
	B:RestoreActionBarBagButtons()
	if E.ApplySarychUIBagFonts then
		E:ApplySarychUIBagFonts()
	end

	--Creating vendor grays frame
	B:CreateSellFrame()
	B:RegisterEvent("MERCHANT_CLOSED")

	--Bag Mover (We want it created even if Bags module is disabled, so we can use it for default bags too)
	local BagFrameHolder = CreateFrame("Frame", nil, E.UIParent)
	BagFrameHolder:Width(200)
	BagFrameHolder:Height(22)
	BagFrameHolder:SetFrameLevel(BagFrameHolder:GetFrameLevel() + 400)

	if not E.private.bags.enable then
		-- Set a different default anchor
		BagFrameHolder:Point("BOTTOMRIGHT", RightChatPanel, "BOTTOMRIGHT", E.PixelMode and 1 or -E.Border, 22 + E.Border*4 - E.Spacing*2)
		E:CreateMover(BagFrameHolder, "ElvUIBagMover", L["Bag Mover"], nil, nil, B.PostBagMove, nil, nil, "bags,general")

		B:SecureHook("updateContainerFrameAnchors")

		B.Initialized = true
		return
	end

	B.db = E.db.bags
	B.BagFrames = {}
	B.ProfessionColors = {
		[0x0001] = {B.db.colors.profession.quiver.r, B.db.colors.profession.quiver.g, B.db.colors.profession.quiver.b},
		[0x0002] = {B.db.colors.profession.ammoPouch.r, B.db.colors.profession.ammoPouch.g, B.db.colors.profession.ammoPouch.b},
		[0x0004] = {B.db.colors.profession.soulBag.r, B.db.colors.profession.soulBag.g, B.db.colors.profession.soulBag.b},
		[0x0008] = {B.db.colors.profession.leatherworking.r, B.db.colors.profession.leatherworking.g, B.db.colors.profession.leatherworking.b},
		[0x0010] = {B.db.colors.profession.inscription.r, B.db.colors.profession.inscription.g, B.db.colors.profession.inscription.b},
		[0x0020] = {B.db.colors.profession.herbs.r, B.db.colors.profession.herbs.g, B.db.colors.profession.herbs.b},
		[0x0040] = {B.db.colors.profession.enchanting.r, B.db.colors.profession.enchanting.g, B.db.colors.profession.enchanting.b},
		[0x0080] = {B.db.colors.profession.engineering.r, B.db.colors.profession.engineering.g, B.db.colors.profession.engineering.b},
		[0x0200] = {B.db.colors.profession.gems.r, B.db.colors.profession.gems.g, B.db.colors.profession.gems.b},
		[0x0400] = {B.db.colors.profession.mining.r, B.db.colors.profession.mining.g, B.db.colors.profession.mining.b},
	}

	B.QuestColors = {
		["questStarter"] = {B.db.colors.items.questStarter.r, B.db.colors.items.questStarter.g, B.db.colors.items.questStarter.b},
		["questItem"] = {B.db.colors.items.questItem.r, B.db.colors.items.questItem.g, B.db.colors.items.questItem.b},
	}

	BagFrameHolder:Point("BOTTOMRIGHT", RightChatPanel, "BOTTOMRIGHT", 0, 22 + E.Border*4 - E.Spacing*2)
	E:CreateMover(BagFrameHolder, "ElvUIBagMover", L["Bag Mover (Grow Up)"], nil, nil, B.PostBagMove, nil, nil, "bags,general")

	local BankFrameHolder = CreateFrame("Frame", nil, E.UIParent)
	BankFrameHolder:Width(200)
	BankFrameHolder:Height(22)
	BankFrameHolder:Point("BOTTOMLEFT", LeftChatPanel, "BOTTOMLEFT", 0, 22 + E.Border*4 - E.Spacing*2)
	BankFrameHolder:SetFrameLevel(BankFrameHolder:GetFrameLevel() + 400)
	E:CreateMover(BankFrameHolder, "ElvUIBankMover", L["Bank Mover (Grow Up)"], nil, nil, B.PostBagMove, nil, nil, "bags,general")

	if ElvUIBagMover then
		ElvUIBagMover.textGrowUp = L["Bag Mover (Grow Up)"]
		ElvUIBagMover.textGrowDown = L["Bag Mover (Grow Down)"]
		ElvUIBagMover.POINT = "BOTTOM"
	end
	if ElvUIBankMover then
		ElvUIBankMover.textGrowUp = L["Bank Mover (Grow Up)"]
		ElvUIBankMover.textGrowDown = L["Bank Mover (Grow Down)"]
		ElvUIBankMover.POINT = "BOTTOM"
	end

	--Create Bag Frame
	B.BagFrame = B:ContructContainerFrame("ElvUI_ContainerFrame")
	B:ApplyElvUIBagWindowPosition(B.BagFrame)

	--Hook onto Blizzard Functions
	-- RawHook: Blizzard OpenAllBags must NOT run first (it touches ContainerFrames
	-- that DisableBlizzard() kills, and can error on Shift+open-all).
	B:RawHook("OpenAllBags", true)
	B:SecureHook("CloseAllBags", "CloseBags")
	B:SecureHook("ToggleBag", "ToggleBags")
	B:SecureHook("OpenBackpack", "OpenBags")
	B:SecureHook("CloseBackpack", "CloseBags")
	B:SecureHook("ToggleBackpack")
	B:SecureHook("BagSlotButton_UpdateChecked", "OnBagSlotButtonUpdateChecked")
	B:SecureHook("BackpackButton_UpdateChecked", "OnBackpackButtonUpdateChecked")
	B:SecureHook("BagSlotButton_OnModifiedClick", "OnBagSlotButtonModifiedClick")
	B:SecureHook("BackpackButton_OnModifiedClick", "OnBackpackButtonModifiedClick")
	B:SecureHook("BackpackTokenFrame_Update", "UpdateTokens")
	B.hooksInstalled = true
	B:Layout()

	B:DisableBlizzard()
	B:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateGoldText")
	B:RegisterEvent("PLAYER_MONEY", "UpdateGoldText")
	B:RegisterEvent("PLAYER_TRADE_MONEY", "UpdateGoldText")
	B:RegisterEvent("TRADE_MONEY_CHANGED", "UpdateGoldText")
	B:RegisterEvent("BANKFRAME_OPENED", "OpenBank")
	B:RegisterEvent("BANKFRAME_CLOSED", "CloseBank")
	B:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
	B:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")

	B:ApplyBagFont()

	B.Initialized = true
end

local function InitializeCallback()
	B:Initialize()
end

E:RegisterModule(B:GetName(), InitializeCallback)
