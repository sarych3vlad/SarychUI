-- SarychUI Bags: сортировка стандартных сумок (JPack-style, слоты 0–4)
-- Загружается после modules/bags/module.lua

local moduleName = "bags"

-- Constants live on one table: Lua 5.1 caps a file at 200 locals and this
-- chunk had almost no room left.
local K = {}
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local format = string.format
local strlower = string.lower
local ipairs, pairs, wipe = ipairs, pairs, wipe
local tinsert, tremove, sort = table.insert, table.remove, table.sort
local min = math.min

K.DEBUG_BAG_SORT = false
K.DEBUG_ELVUI_BAGS_SORT = false
K.DEBUG_BAG_SORT_ITEM_ID = nil

local GetAuctionItemClasses = GetAuctionItemClasses
local GetAuctionItemSubClasses = GetAuctionItemSubClasses
local ARMOR, ENCHSLOT_WEAPON = ARMOR, ENCHSLOT_WEAPON
local ITEM_BIND_ON_EQUIP = _G.ITEM_BIND_ON_EQUIP
local ITEM_BIND_ON_PICKUP = _G.ITEM_BIND_ON_PICKUP
local ITEM_BIND_ON_USE = _G.ITEM_BIND_ON_USE
local ITEM_SOULBOUND = _G.ITEM_SOULBOUND
local ITEM_ACCOUNTBOUND = _G.ITEM_ACCOUNTBOUND

-- ElvUI Modules/Bags/Sort.lua — порядок категорий через аукционные классы/подклассы
local itemTypes, itemSubTypes = {}, {}
local itemTypesBuilt = false

local inventorySlots = {
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
    INVTYPE_TRINKET = 12,
    INVTYPE_CLOAK = 13,
    INVTYPE_WEAPON = 14,
    INVTYPE_SHIELD = 15,
    INVTYPE_2HWEAPON = 16,
    INVTYPE_WEAPONMAINHAND = 18,
    INVTYPE_WEAPONOFFHAND = 19,
    INVTYPE_HOLDABLE = 20,
    INVTYPE_RANGED = 21,
    INVTYPE_THROWN = 22,
    INVTYPE_RANGEDRIGHT = 23,
    INVTYPE_RELIC = 24,
    INVTYPE_TABARD = 25,
}

local dbg = {}
function dbg.format(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        parts[i] = tostring(select(i, ...))
    end
    return "BagSort: " .. table.concat(parts, " ")
end
function dbg.emit(...)
    local text = dbg.format(...)
    if SarychUI and SarychUI.Print then
        SarychUI:Print(text)
    else
        print("|cffffd200SarychUI:|r " .. text)
    end
end
function dbg.bag(...)
    if not K.DEBUG_BAG_SORT then return end
    dbg.emit(...)
end
function dbg.elv(...)
    if not K.DEBUG_ELVUI_BAGS_SORT then return end
    print("[SarychUI_Bags Sort]", ...)
end

-- Глобальные алиасы без local — не тратят лимит 200 local.
bagSortDebug = dbg.bag
sortElvDebug = dbg.elv
emitBagSortDebug = dbg.emit

local elvuiSortBagFrame = nil

local function finishElvUIBagSort()
    local bagFrame = elvuiSortBagFrame
    elvuiSortBagFrame = nil
    if not bagFrame then return end

    local engine = _G.SarychUI_Bags and _G.SarychUI_Bags[1]
    local B = engine and engine.GetModule and engine:GetModule("Bags", true)
    if engine and bagFrame.holderFrame then
        engine:StopSpinnerFrame(bagFrame.holderFrame)
    end
    if B and B.RegisterUpdateDelayed then
        B:RegisterUpdateDelayed()
    end
    dbg.elv("sort finished, UI restored")
end

-- BoE: tooltip scan с кэшем по itemLink (статус привязки зависит от экземпляра).
local bindStateCache = {}
local bindScanTooltip

local BOE_TOOLTIP_PATTERNS = {
    "binds when equipped",
    "становится персональным при надевании",
}

local NOT_BOE_TOOLTIP_PATTERNS = {
    "soulbound",
    "персональный предмет",
    "binds when picked up",
    "становится персональным при получении",
    "binds when used",
    "становится персональным при использовании",
    "account bound",
    "привязан к аккаунту",
    "binds to account",
    "привязано к бNET",
}

local function tooltipLineMatches(text, patterns)
    if not text then return false end
    text = strlower(text)
    for i = 1, #patterns do
        if text:find(patterns[i], 1, true) then
            return true
        end
    end
    return false
end

local function tooltipLineEquals(text, expected)
    return expected and text and text == expected
end

local function clearBindStateCache()
    wipe(bindStateCache)
end

local function getBindScanTooltip()
    if not bindScanTooltip then
        bindScanTooltip = CreateFrame("GameTooltip", "SarychUIBagSortBindTooltip", UIParent, "GameTooltipTemplate")
        bindScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return bindScanTooltip
end

local function getBindState(itemLink, bag, slot)
    if not itemLink then
        return { soulbound = false, boe = false }
    end
    if bindStateCache[itemLink] then
        return bindStateCache[itemLink]
    end

    local tooltip = getBindScanTooltip()
    tooltip:ClearLines()
    if bag and slot and tooltip.SetBagItem then
        tooltip:SetBagItem(bag, slot)
    else
        tooltip:SetHyperlink(itemLink)
    end

    local isSoulbound, isBoE = false, false
    local tipName = tooltip:GetName()
    for i = 1, tooltip:NumLines() do
        local left = _G[tipName .. "TextLeft" .. i]
        local right = _G[tipName .. "TextRight" .. i]
        for _, fs in ipairs({ left, right }) do
            if fs then
                local text = fs:GetText()
                if tooltipLineEquals(text, ITEM_SOULBOUND)
                    or tooltipLineEquals(text, ITEM_BIND_ON_PICKUP)
                    or tooltipLineEquals(text, ITEM_BIND_ON_USE)
                    or tooltipLineEquals(text, ITEM_ACCOUNTBOUND)
                    or tooltipLineMatches(text, NOT_BOE_TOOLTIP_PATTERNS) then
                    isSoulbound = true
                end
                if tooltipLineEquals(text, ITEM_BIND_ON_EQUIP)
                    or tooltipLineMatches(text, BOE_TOOLTIP_PATTERNS) then
                    isBoE = true
                end
            end
        end
    end

    if isSoulbound then
        isBoE = false
    end

    local state = { soulbound = isSoulbound, boe = isBoE }
    bindStateCache[itemLink] = state
    return state
end

local function IsSoulboundItem(itemLink, bag, slot)
    return getBindState(itemLink, bag, slot).soulbound
end

local function IsBindOnEquip(itemLink, bag, slot)
    local state = getBindState(itemLink, bag, slot)
    return state.boe and not state.soulbound
end

local function sortBoEItems(items)
    sort(items, function(a, b)
        local aRarity, bRarity = a.rarity or 0, b.rarity or 0
        if aRarity ~= bRarity then
            return aRarity > bRarity
        end
        local aLvl, bLvl = a.level or 0, b.level or 0
        if aLvl ~= bLvl then
            return aLvl > bLvl
        end
        local aType, bType = a.type or "", b.type or ""
        if aType ~= bType then
            return aType < bType
        end
        local aSub, bSub = a.subType or "", b.subType or ""
        if aSub ~= bSub then
            return aSub < bSub
        end
        local aName, bName = a.name or "", b.name or ""
        if aName ~= bName then
            return aName < bName
        end
        return (a.itemid or 0) < (b.itemid or 0)
    end)
end

local function BuildSortOrder()
    if itemTypesBuilt then return end
    wipe(itemTypes)
    wipe(itemSubTypes)
    for i, iType in ipairs({ GetAuctionItemClasses() }) do
        itemTypes[iType] = i
        itemSubTypes[iType] = {}
        for ii, isType in ipairs({ GetAuctionItemSubClasses(i) }) do
            itemSubTypes[iType][isType] = ii
        end
    end
    itemTypesBuilt = true
    if K.DEBUG_BAG_SORT then
        bagSortDebug("BuildSortOrder: classes", #({ GetAuctionItemClasses() }))
    end
end

local function GetElvUISortCategoryLabel(it)
    if not it then return "empty" end
    local typeName = it.type or "?"
    local classId = itemTypes[typeName] or 99
    local subId = itemSubTypes[typeName] and itemSubTypes[typeName][it.subType or ""] or 99
    return format("%d/%s/%s(%d)", classId, typeName, it.subType or "?", subId)
end

-- ElvUI PrimarySort: уровень ↓, цена продажи ↓, имя ↑
local function PrimarySort(a, b)
    local aLvl, bLvl = a.level or 0, b.level or 0
    local aPrice, bPrice = a.vendorPrice or 0, b.vendorPrice or 0
    local aName, bName = a.name or "", b.name or ""

    if aLvl ~= bLvl and aLvl > 0 and bLvl > 0 then
        return aLvl > bLvl
    end
    if aPrice ~= bPrice and aPrice > 0 and bPrice > 0 then
        return aPrice > bPrice
    end
    if aName ~= bName then
        return aName < bName
    end
    return false
end

-- ElvUI DefaultSort: редкость ↓, класс, подкласс, слот экипировки, PrimarySort
local function ElvUIDefaultSort(a, b)
    BuildSortOrder()

    local aID = a.itemid or 0
    local bID = b.itemid or 0
    if aID == 0 or bID == 0 then
        return aID ~= 0
    end

    local aOrder, bOrder = a.packOrder or 0, b.packOrder or 0

    if aID == bID then
        local aCount = a.count or 1
        local bCount = b.count or 1
        if aCount == bCount then
            return aOrder < bOrder
        end
        return aCount < bCount
    end

    local aRarity, bRarity = a.rarity or 0, b.rarity or 0
    if aRarity ~= bRarity then
        return aRarity > bRarity
    end

    local aType, bType = a.type or "", b.type or ""
    if itemTypes[aType] ~= itemTypes[bType] then
        return (itemTypes[aType] or 99) < (itemTypes[bType] or 99)
    end

    local aItemClassId = itemTypes[aType] or 99
    local bItemClassId = itemTypes[bType] or 99
    local aItemSubClassId = itemSubTypes[aType] and itemSubTypes[aType][a.subType or ""] or 99
    local bItemSubClassId = itemSubTypes[bType] and itemSubTypes[bType][b.subType or ""] or 99

    if aItemClassId ~= bItemClassId then
        return aItemClassId < bItemClassId
    end

    if aItemClassId == ARMOR or aItemClassId == ENCHSLOT_WEAPON then
        local aEquipLoc = inventorySlots[a.equipLoc] or -1
        local bEquipLoc = inventorySlots[b.equipLoc] or -1
        if aEquipLoc ~= bEquipLoc then
            return aEquipLoc < bEquipLoc
        end
        return PrimarySort(a, b)
    end

    if aItemClassId == bItemClassId and aItemSubClassId == bItemSubClassId then
        return PrimarySort(a, b)
    end

    return aItemSubClassId < bItemSubClassId
end

local function compareElvUI(a, b)
    if a == b then return 0 end
    if not a and not b then return 0 end
    if not a then return 1 end
    if not b then return -1 end
    if ElvUIDefaultSort(a, b) then return -1 end
    if ElvUIDefaultSort(b, a) then return 1 end
    return 0
end

local function sortItemsElvUI(items, fromIndex, toIndex)
    fromIndex = fromIndex or 1
    toIndex = toIndex or #items
    if toIndex <= fromIndex then return end
    sort(items, function(a, b)
        return ElvUIDefaultSort(a, b)
    end)
    if K.DEBUG_BAG_SORT then
        for i = fromIndex, toIndex do
            local it = items[i]
            if it then
                bagSortDebug("sorted", i, it.name or "?", "id", it.itemid or 0, "cat", GetElvUISortCategoryLabel(it))
            end
        end
    end
end

local function DB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules[moduleName]
end

local function AutomationDB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules.automation
end

local function BagsDB()
    if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.modules then
        return nil
    end
    return SarychUI.db.profile.modules.bags
end

-- Одна таблица вместо нескольких local (лимит Lua 5.1: 200 local в чанке).
local baudUI = {
	SORT_GAP = 1,
	SEARCH_GAP = 1,
	SEARCH_WIDTH = 78,
	SEARCH_ICON = 9,
	SORT_SIZE = 22,
}

function baudUI.isMode()
	return module and module.IsEnabled and module:IsEnabled()
		and module.IsBaudBagMode and module:IsBaudBagMode()
end

function baudUI.menuButton(parent)
	if parent and parent.GetName then
		local menu = _G[parent:GetName() .. "MenuButton"]
		if menu then
			return menu
		end
	end
	return _G.BBCont1_1MenuButton
end

local function IsBagSortEnabled()
    local automation = AutomationDB()
    return automation and automation.enabled and automation.enableBagSortButton == 1
end

local function IsClassicBagsUIMode()
    if not module or not module.IsEnabled or not module:IsEnabled() then return false end
    if baudUI.isMode() then return true end
    if module.IsDefaultMode and module:IsDefaultMode() then return true end
    return false
end

local function IsBagSearchEnabled()
    local db = BagsDB()
    return db and db.enableBagSearch == true
end

local function IsDefaultBagSortActive()
    return IsClassicBagsUIMode() and IsBagSortEnabled()
end

local JPackDB = { asc = true }

local JP = {
    bankOpened = false,
    bagGroups = {},
    packingBags = {},
    updatePeriod = 0.1,
}

K.JPACK_STOPPED = 0
K.JPACK_STARTED = 1
K.JPACK_STACK_OVER = 5
K.JPACK_PACKING = 7
K.JPACK_MAXMOVE_ONCE = 3
K.PACKING_MAX_TICKS = 5000

local JPACK_STEP = K.JPACK_STOPPED
local bagSize = 0
local packCurrent, packTo
local lockedSlots
local lockedCache = {}
local elapsed = 0
local packingTickCount = 0
local FinishSortRun

-- Видимый фрейм: у скрытых parent OnUpdate не вызывается — сортировка не шла
local sortDriver = CreateFrame("Frame", "SarychUIBagSortDriver", UIParent)
sortDriver:SetSize(1, 1)
sortDriver:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -20, 20)
sortDriver:Hide()

local sortButton
local sortButtonHooksInstalled = false
local baudBagSortHooksInstalled = false
local searchEditBox
local sortLoaderActive = false
local sortLoaderFailsafeElapsed = 0

K.BACKPACK_BAG_ID = 0
K.PLAYER_BAG_MAX = 4
K.NUM_CONTAINER_FRAMES = _G.NUM_CONTAINER_FRAMES or 13
K.JPACK_FINISHING = 8
K.SORT_LOADER_FAILSAFE_SEC = 30
K.SEARCH_BOX_WIDTH = 115
K.SEARCH_BOX_HEIGHT = 20
K.SEARCH_BOX_GAP = 3
-- Sort button anchor on the backpack (must stay in sync with CreateFrame below).
K.SORT_BTN_SIZE = 28
K.SORT_BTN_OFFSET_X = -4
K.SORT_BTN_OFFSET_Y = -24

function baudUI.anchor(parent)
    local menu = baudUI.isMode() and baudUI.menuButton(parent) or nil
    -- XML: MenuButton = 16x16; берём факт. размер кнопки.
    local menuW, menuH = 16, 16
    if menu then
        menuW = menu:GetWidth() or 16
        menuH = menu:GetHeight() or 16
        if menuW < 1 then menuW = 16 end
        if menuH < 1 then menuH = 16 end
    end

    if sortButton and sortButton:IsShown() then
        if sortButton:GetParent() ~= parent then
            sortButton:SetParent(parent)
        end
        sortButton:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 50)
        if menu then
            sortButton:SetSize(baudUI.SORT_SIZE, baudUI.SORT_SIZE)
            sortButton:ClearAllPoints()
            sortButton:SetPoint("RIGHT", menu, "LEFT", baudUI.SORT_GAP, 0)
        else
            sortButton:SetSize(K.SORT_BTN_SIZE, K.SORT_BTN_SIZE)
            sortButton:ClearAllPoints()
            sortButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", K.SORT_BTN_OFFSET_X, K.SORT_BTN_OFFSET_Y)
        end
    end

    if searchEditBox and searchEditBox:IsShown() then
        if searchEditBox:GetParent() ~= parent then
            searchEditBox:SetParent(parent)
        end
        searchEditBox:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 50)
        if menu then
            searchEditBox:SetSize(baudUI.SEARCH_WIDTH, menuH)
            if searchEditBox.searchIcon then
                searchEditBox.searchIcon:Show()
                searchEditBox.searchIcon:SetSize(baudUI.SEARCH_ICON, baudUI.SEARCH_ICON)
            end
            searchEditBox:SetTextInsets(baudUI.SEARCH_ICON + 6, 4, 0, 0)
        else
            searchEditBox:SetSize(K.SEARCH_BOX_WIDTH, K.SEARCH_BOX_HEIGHT)
            if searchEditBox.searchIcon then
                searchEditBox.searchIcon:Hide()
            end
            searchEditBox:SetTextInsets(6, 6, 0, 0)
        end
        searchEditBox:ClearAllPoints()
        if sortButton and sortButton:IsShown() then
            searchEditBox:SetPoint("RIGHT", sortButton, "LEFT", baudUI.SEARCH_GAP, 0)
        elseif menu then
            searchEditBox:SetPoint("RIGHT", menu, "LEFT", baudUI.SEARCH_GAP, 0)
        else
            local x = K.SORT_BTN_OFFSET_X - K.SORT_BTN_SIZE + K.SEARCH_BOX_GAP
            local y = K.SORT_BTN_OFFSET_Y - math.floor((K.SORT_BTN_SIZE - K.SEARCH_BOX_HEIGHT) / 2)
            searchEditBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
        end
    end
end

local function PrintMsg(text)
    if SarychUI and SarychUI.Print then
        SarychUI:Print(text)
    else
        print("|cffffd200SarychUI:|r " .. tostring(text))
    end
end

local function CursorHoldsItem()
    return GetCursorInfo() ~= nil
end

local function IndexOfTable(t, v)
    for i = 1, #t do
        if t[i] == v then return i end
    end
    return 0
end

local debugTrackItem

local function getJPackItem(bag, slot, packOrder)
    local link = GetContainerItemLink(bag, slot)
    if not link then return end
    local _, count = GetContainerItemInfo(bag, slot)
    local item = {}
    item.link = link
    item.name, item.link, item.rarity,
    item.level, item.minLevel, item.type, item.subType, item.stackCount,
    item.equipLoc, item.texture, item.vendorPrice = GetItemInfo(link)
    item.count = count or 1
    item.packOrder = packOrder or 0
    item.bag = bag
    item.slot = slot
    item.itemid = tonumber(link:match("item:(%-?%d+)")) or 0
    if (item.itemid or 0) <= 0 and GetContainerItemID then
        item.itemid = tonumber(GetContainerItemID(bag, slot)) or 0
    end
    if item.itemid == 0 and GetItemInfoInstant then
        item.itemid = tonumber(GetItemInfoInstant(link)) or 0
    end
    if not item.name then
        item.name = link
        item.type = item.type or ""
        item.subType = item.subType or ""
        item.rarity = item.rarity or 0
        item.level = item.level or 0
        item.minLevel = item.minLevel or 0
        item.stackCount = item.stackCount or 1
        item.vendorPrice = item.vendorPrice or 0
    end
    debugTrackItem(item, "scan")
    return item
end

local function SafeBagNumSlots(bag)
    return tonumber(GetContainerNumSlots(bag)) or 0
end

local function isBagReady(bag)
    for i = 1, SafeBagNumSlots(bag) do
        local _, _, locked = GetContainerItemInfo(bag, i)
        if locked then return false end
    end
    return true
end

local function isAllBagReady()
    for i = 1, #JP.bagGroups do
        for j = 1, #JP.bagGroups[i] do
            if not isBagReady(JP.bagGroups[i][j]) then return false end
        end
    end
    return true
end

K.HEARTHSTONE_ITEM_ID = 6948

K.SORT_BTN_TEX_UP = "Interface\\GLUES\\CHARACTERCREATE\\UI-RotationRight-Big-Up.blp"
K.SORT_BTN_TEX_DOWN = "Interface\\GLUES\\CHARACTERCREATE\\UI-RotationRight-Big-Down.blp"

-- Список закреплённых itemID: SarychUIDB.bagSortPinnedItemIDs
local function getBagSortPinnedItemIDs()
    if module and module.GetBagSortPinnedItemIDs then
        return module:GetBagSortPinnedItemIDs()
    end
    if SarychUIDB and type(SarychUIDB.bagSortPinnedItemIDs) == "table" then
        return SarychUIDB.bagSortPinnedItemIDs
    end
    return { 43231, 43233 }
end

local function isPinnedMainBagItem(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return false end
    local list = getBagSortPinnedItemIDs()
    for i = 1, #list do
        if tonumber(list[i]) == itemID then
            return true
        end
    end
    return false
end

-- itemID из item.itemid, ссылки или GetItemInfoInstant (без опоры на имя).
local function resolveItemID(it)
    if not it then return 0 end
    local id = tonumber(it.itemid) or 0
    if id > 0 then return id end
    local link = it.link
    if link then
        id = tonumber(link:match("item:(%-?%d+)")) or 0
        if id > 0 then return id end
        if GetItemInfoInstant then
            id = tonumber(GetItemInfoInstant(link)) or 0
            if id > 0 then return id end
        end
    end
    if GetItemInfoInstant and id > 0 then
        return tonumber(GetItemInfoInstant(id)) or 0
    end
    return 0
end

local function itemsMatch(a, b)
    if not a or not b then return false end
    local ida, idb = resolveItemID(a), resolveItemID(b)
    if ida > 0 and idb > 0 then
        return ida == idb
    end
    if a.link and b.link and a.link == b.link then
        return true
    end
    return a.name ~= nil and a.name == b.name
end

local function shouldDebugTrackItem(it)
    if not it then return false end
    if K.DEBUG_BAG_SORT_ITEM_ID and resolveItemID(it) == K.DEBUG_BAG_SORT_ITEM_ID then return true end
    return false
end

debugTrackItem = function(it, stage, extra)
    if not shouldDebugTrackItem(it) then return end
    local bind = it.link and getBindState(it.link, it.bag, it.slot) or { soulbound = false, boe = false }
    local locked = false
    if it.bag and it.slot then
        local _, _, isLocked = GetContainerItemInfo(it.bag, it.slot)
        locked = isLocked and true or false
    end
    emitBagSortDebug(
        "trackItem", resolveItemID(it), stage,
        "bag", it.bag, "slot", it.slot,
        "link", it.link or "?",
        "locked", locked,
        "pinned", isPinnedMainBagItem(resolveItemID(it)),
        "boe", bind.boe,
        "soulbound", bind.soulbound,
        "category", it.sortCategory or "?",
        "quality", it.rarity or 0,
        "ilvl", it.level or 0,
        extra or ""
    )
end

-- API id контейнеров (см. GetContainerNumSlots / PickupContainerItem).
-- В UI слева направо: CharacterBag3 → Bag2 → Bag1 → Bag0 → MainMenuBarBackpackButton.
K.BAG_BACKPACK = 0           -- MainMenuBarBackpackButton
K.BAG_CHARACTER_0 = 1        -- CharacterBag0Slot
K.BAG_CHARACTER_1 = 2        -- CharacterBag1Slot
K.BAG_CHARACTER_2 = 3        -- CharacterBag2Slot
K.BAG_CHARACTER_3 = 4        -- CharacterBag3Slot

-- Порядок заполнения обычным инвентарём (от дальней сумки к рюкзаку).
local GENERAL_FILL_BAG_ORDER = {
    K.BAG_CHARACTER_3,
    K.BAG_CHARACTER_2,
    K.BAG_CHARACTER_1,
    K.BAG_CHARACTER_0,
    K.BAG_BACKPACK,
}

local function isHearthstoneItem(it)
    return it and resolveItemID(it) == K.HEARTHSTONE_ITEM_ID
end

local function isArrowAmmoItem(it)
    if not it then return false end
    local el = strlower(it.equipLoc or "")
    if el == "invtype_ammo" or el:find("ammo") or el:find("боеприпас") then return true end
    -- Экипируемое оружие (в т.ч. луки/ружья) — не боеприпасы.
    if el == "invtype_weapon" or el == "invtype_2hweapon"
        or el == "invtype_ranged" or el == "invtype_rangedright"
        or el == "invtype_thrown" or el:find("weapon") then
        return false
    end
    local t = strlower(it.type or "")
    local s = strlower(it.subType or "")
    if t:find("projectil") or t:find("боеприпас") then return true end
    -- «стрел» без якоря совпадает с «огнестрельное»; «дроб» — с «дробящее».
    if s:find("arrow") or s:find("стрелы") or s:find("стрела")
        or s:find("bullet") or s:find("пул")
        or s:find("shot") or s:find("дробь") or s:find("дробов") then
        return true
    end
    return false
end

local function isPoisonItem(it)
    if not it then return false end
    local s = strlower(it.subType or "")
    local t = strlower(it.type or "")
    if s:find("poison") or s:find("яд") then return true end
    if t:find("poison") or t:find("яд") then return true end
    return false
end

-- Прочие классовые реагенты/расходники (тотемы, осколки души, рунные реагенты и т.п.).
local function isOtherClassReagentItem(it)
    if not it then return false end
    local n = strlower(it.name or "")
    local s = strlower(it.subType or "")
    if n:find("soul shard") or n:find("осколок душ") then return true end
    if s:find("totem") or s:find("тотем") then return true end
    if n:find("rune of telepor") or n:find("руна телепор") or n:find("телепортации") then return true end
    if n:find("sacred candle") or n:find("священн") and n:find("свеч") then return true end
    if n:find("wild berry") or n:find("дикие ягоды") or n:find("дикая ягода") then return true end
    if n:find("maple seed") or n:find("кленов") and n:find("сем") then return true end
    if n:find("ankh") or n:find("анкх") then return true end
    if n:find("symbol of kings") or n:find("символ корол") then return true end
    if n:find("holy candle") or n:find("святая свеча") then return true end
    return false
end

-- Прочие классовые предметы в рюкзаке (не 43231/43233 — они в isPinnedMainBagItem).
local function isClassPinnedItem(it)
    if not it or isHearthstoneItem(it) then return false end
    if isPinnedMainBagItem(resolveItemID(it)) then return false end
    return isArrowAmmoItem(it) or isPoisonItem(it) or isOtherClassReagentItem(it)
end

local function isBoEItem(it)
    if not it or not it.link then return false end
    if isHearthstoneItem(it) then return false end
    if isPinnedMainBagItem(resolveItemID(it)) then return false end
    if isClassPinnedItem(it) then return false end
    if IsSoulboundItem(it.link, it.bag, it.slot) then return false end
    return IsBindOnEquip(it.link, it.bag, it.slot)
end

local function getItemSortCategory(it)
    if not it then return "empty" end
    if isHearthstoneItem(it) then return "HEARTHSTONE" end
    if isPinnedMainBagItem(resolveItemID(it)) then return "PINNED" end
    if isClassPinnedItem(it) then return "CLASS_PINNED" end
    if isBoEItem(it) then return "BOE" end
    return "REGULAR"
end

local function logItemSortDebug(it, category)
    if not K.DEBUG_BAG_SORT or not it then return end
    local boe = category == "BOE"
    bagSortDebug(
        "item:", it.link or it.name or "?",
        "id:", it.itemid or 0,
        "pinned:", (category == "PINNED" or category == "HEARTHSTONE" or category == "CLASS_PINNED") and "true" or "false",
        "boe:", boe and "true" or "false",
        "quality:", it.rarity or 0,
        "ilvl:", it.level or 0,
        "category:", category
    )
end

local function packRangeForBagId(bagId)
    local lo, hi = nil, nil
    local acc = 0
    for i = 1, #JP.packingBags do
        local bid = JP.packingBags[i]
        local num = SafeBagNumSlots(JP.packingBags[i])
        if bid == bagId then
            lo = acc + 1
            hi = acc + num
            return lo, hi
        end
        acc = acc + num
    end
    return nil, nil
end

local function packIndexToBagSlot(packIndex)
    local slot = packIndex
    if JPackDB.asc then
        for i = 1, #JP.packingBags do
            local num = SafeBagNumSlots(JP.packingBags[i])
            if slot <= num then
                return JP.packingBags[i], slot
            end
            slot = slot - num
        end
    else
        for i = #JP.packingBags, 1, -1 do
            local num = SafeBagNumSlots(JP.packingBags[i])
            if slot <= num then
                return JP.packingBags[i], 1 + num - slot
            end
            slot = slot - num
        end
    end
    return -1, -1
end

local function debugFindTrackedItemInArray(arr, label)
    if not K.DEBUG_BAG_SORT_ITEM_ID or not arr then return end
    for i = 1, bagSize do
        local it = arr[i]
        if it and resolveItemID(it) == K.DEBUG_BAG_SORT_ITEM_ID then
            local bag, slot = packIndexToBagSlot(i)
            bagSortDebug(
                "tracked item in", label,
                "packIndex", i, "bag", bag, "slot", slot,
                "name", it.name or "?", "category", it.sortCategory or "?"
            )
        end
    end
end

local function debugReportTrackedItemFinalLocation()
    if not K.DEBUG_BAG_SORT_ITEM_ID then return end
    for _, bagId in ipairs({ 0, 1, 2, 3, 4 }) do
        local num = SafeBagNumSlots(bagId)
        for slot = 1, num do
            local id = GetContainerItemID(bagId, slot)
            if id == K.DEBUG_BAG_SORT_ITEM_ID then
                bagSortDebug("FINAL actual location bag", bagId, "slot", slot)
            end
        end
    end
end

local function logPlacement(category, packIndex, it)
    if it then
        local bag, slot = packIndexToBagSlot(packIndex)
        debugTrackItem(it, "placing:" .. category, format("packIndex=%s bag=%s slot=%s", tostring(packIndex), tostring(bag), tostring(slot)))
    end
    if not K.DEBUG_BAG_SORT or not it then return end
    local bag, slot = packIndexToBagSlot(packIndex)
    bagSortDebug(
        "placing", category,
        "packIndex", packIndex, "bag", bag, "slot", slot,
        "item", it.name or "?", "id", it.itemid or 0
    )
end

local function assignItemCategory(it, category)
    if not it then return end
    it.sortCategory = category
    debugTrackItem(it, "split:" .. category)
    logItemSortDebug(it, category)
end

-- Камень → закреплённые itemID (43231, 43233) → прочие классовые → BoE → общая сортировка.
local function splitItemsForLayout(sorted)
    local hearthstone = nil
    local pinnedFound = {}
    local pinnedExtraStacks = {}
    local classPinned, boeItems, general = {}, {}, {}

    for i = 1, bagSize do
        local it = sorted[i]
        if not it then
        elseif isHearthstoneItem(it) then
            if not hearthstone then
                hearthstone = it
                assignItemCategory(it, "HEARTHSTONE")
            else
                general[#general + 1] = it
                assignItemCategory(it, "REGULAR")
            end
        else
            local id = resolveItemID(it)
            if id > 0 then
                it.itemid = id
            end
            if isPinnedMainBagItem(id) then
                if not pinnedFound[id] then
                    pinnedFound[id] = it
                else
                    pinnedExtraStacks[#pinnedExtraStacks + 1] = it
                end
                assignItemCategory(it, "PINNED")
            elseif isClassPinnedItem(it) then
                classPinned[#classPinned + 1] = it
                assignItemCategory(it, "CLASS_PINNED")
            elseif isBoEItem(it) then
                it.isBoE = true
                boeItems[#boeItems + 1] = it
                assignItemCategory(it, "BOE")
            else
                it.isBoE = false
                general[#general + 1] = it
                assignItemCategory(it, "REGULAR")
            end
        end
    end

    local pinnedMain = {}
    for _, id in ipairs(getBagSortPinnedItemIDs()) do
        id = tonumber(id)
        if id and pinnedFound[id] then
            pinnedMain[#pinnedMain + 1] = pinnedFound[id]
        end
    end
    for i = 1, #pinnedExtraStacks do
        pinnedMain[#pinnedMain + 1] = pinnedExtraStacks[i]
    end

    sortItemsElvUI(classPinned)
    sortBoEItems(boeItems)
    sortItemsElvUI(general)

    if K.DEBUG_BAG_SORT then
        bagSortDebug("split: pinned", #pinnedMain, "classPinned", #classPinned, "boe", #boeItems, "general", #general)
        for i = 1, #pinnedMain do
            bagSortDebug("pinned order", i, pinnedMain[i].name, pinnedMain[i].itemid)
        end
        for i = 1, #boeItems do
            local it = boeItems[i]
            bagSortDebug("boe order", i, it.name, "id", it.itemid, "quality", it.rarity or 0, "ilvl", it.level or 0)
        end
    end

    return hearthstone, pinnedMain, classPinned, boeItems, general
end

-- Слот 1 рюкзака — камень → закреплённые itemID → классовые → BoE (сразу после pinned).
local function placeBackpackPinned(out, backpackLo, backpackHi, hearthstone, pinnedMain, classPinned, boeItems)
    if not backpackLo or not backpackHi then
        return nil, {}
    end

    boeItems = boeItems or {}
    local pos = backpackLo
    local classUnplaced = {}
    local boeOverflow = {}

    local function placeList(list, category, overflowTarget)
        for i = 1, #list do
            if pos <= backpackHi then
                out[pos] = list[i]
                logPlacement(category, pos, list[i])
                pos = pos + 1
            else
                overflowTarget[#overflowTarget + 1] = list[i]
            end
        end
    end

    if hearthstone then
        out[pos] = hearthstone
        logPlacement("PINNED", pos, hearthstone)
        pos = pos + 1
    end

    placeList(pinnedMain, "PINNED", classUnplaced)
    placeList(classPinned, "CLASS_PINNED", classUnplaced)
    placeList(boeItems, "BOE", boeOverflow)

    -- Переполнение классовых — с конца рюкзака, всё ещё в основной сумке.
    if #classUnplaced > 0 then
        local hi = backpackHi
        for i = #classUnplaced, 1, -1 do
            while hi >= backpackLo and out[hi] ~= nil do
                hi = hi - 1
            end
            if hi >= backpackLo then
                out[hi] = classUnplaced[i]
                logPlacement("CLASS_PINNED", hi, classUnplaced[i])
                hi = hi - 1
            end
        end
    end

    for p = backpackLo, backpackHi do
        if out[p] == nil then
            return p, boeOverflow
        end
    end
    return backpackHi + 1, boeOverflow
end

-- Pack-индексы regular-зоны: Bag3 → Bag2 → Bag1 → Bag0 → хвост рюкзака (без front-зоны pinned/BoE).
local function isPositionListed(positions, packIndex)
    for i = 1, #positions do
        if positions[i] == packIndex then
            return true
        end
    end
    return false
end

local function isFrontZonePackIndex(packIndex, backpackLo, backpackGeneralFrom)
    if not backpackLo or not backpackGeneralFrom then return false end
    return packIndex >= backpackLo and packIndex < backpackGeneralFrom
end

local function getPlacementZone(packIndex, backpackLo, backpackGeneralFrom)
    if isFrontZonePackIndex(packIndex, backpackLo, backpackGeneralFrom) then
        return "FRONT"
    end
    return "REGULAR"
end

local function buildRegularFillPositions(backpackGeneralFrom)
    local positions = {}
    for _, bagId in ipairs(GENERAL_FILL_BAG_ORDER) do
        if SafeBagNumSlots(bagId) > 0 then
            local lo, hi = packRangeForBagId(bagId)
            if lo and hi then
                local startPos = lo
                if bagId == K.BAG_BACKPACK then
                    startPos = backpackGeneralFrom or (hi + 1)
                end
                if startPos <= hi then
                    for packIndex = startPos, hi do
                        positions[#positions + 1] = packIndex
                    end
                end
            end
        end
    end
    return positions
end

local function appendExtraRegularPositions(positions, out, backpackGeneralFrom)
    for _, bagId in ipairs(GENERAL_FILL_BAG_ORDER) do
        local lo, hi = packRangeForBagId(bagId)
        if lo and hi then
            local startPos = lo
            if bagId == K.BAG_BACKPACK then
                startPos = backpackGeneralFrom or (hi + 1)
            end
            if startPos <= hi then
                for packIndex = startPos, hi do
                    if not out[packIndex] and not isPositionListed(positions, packIndex) then
                        positions[#positions + 1] = packIndex
                    end
                end
            end
        end
    end
end

local function placeBoeOverflowInFront(out, boeOverflow, backpackLo, backpackHi, backpackGeneralFrom)
    if not boeOverflow or #boeOverflow == 0 then
        return backpackGeneralFrom
    end
    if not backpackLo or not backpackHi then
        return backpackGeneralFrom
    end

    local pos = backpackGeneralFrom or backpackLo
    for i = 1, #boeOverflow do
        while pos <= backpackHi and out[pos] do
            pos = pos + 1
        end
        if pos <= backpackHi then
            out[pos] = boeOverflow[i]
            logPlacement("BOE", pos, boeOverflow[i])
            pos = pos + 1
        end
    end

    for p = backpackLo, backpackHi do
        if not out[p] then
            return p
        end
    end
    return backpackHi + 1
end

local function logRegularPlacement(packIndex, it, backpackLo, backpackGeneralFrom)
    local zone = getPlacementZone(packIndex, backpackLo, backpackGeneralFrom)
    local bag, slot = packIndexToBagSlot(packIndex)
    debugTrackItem(it, "placing:REGULAR", format("packIndex=%s bag=%s slot=%s zone=%s", tostring(packIndex), tostring(bag), tostring(slot), zone))
    if shouldDebugTrackItem(it) then
        bagSortDebug(
            "50303 category=REGULAR targetBag=", bag, "targetSlot=", slot,
            "packIndex=", packIndex, "zone=", zone
        )
    end
    if zone == "FRONT" and it and it.sortCategory == "REGULAR" then
        bagSortDebug("ERROR regular item in front zone:", it.name, "id", resolveItemID(it), "packIndex", packIndex)
    end
    if K.DEBUG_BAG_SORT and it then
        bagSortDebug("placing REGULAR zone=", zone, "packIndex", packIndex, "bag", bag, "slot", slot, "item", it.name, "id", resolveItemID(it))
    end
end

local function ensureItemsPlacedInPositions(out, itemList, positions, zoneLabel, backpackLo, backpackGeneralFrom)
    local placed = {}
    for i = 1, bagSize do
        if out[i] then
            placed[out[i]] = true
        end
    end

    local missing = {}
    for i = 1, #itemList do
        local it = itemList[i]
        if it and not placed[it] then
            missing[#missing + 1] = it
        end
    end
    if #missing == 0 then return end

    bagSortDebug("ensureAllItemsPlaced", zoneLabel, "missing:", #missing)
    local mi = 1
    for pi = 1, #positions do
        local packIndex = positions[pi]
        if not out[packIndex] and mi <= #missing then
            local it = missing[mi]
            out[packIndex] = it
            if zoneLabel == "REGULAR" then
                logRegularPlacement(packIndex, it, backpackLo, backpackGeneralFrom)
                if resolveItemID(it) == K.DEBUG_BAG_SORT_ITEM_ID then
                    bagSortDebug("ensureAllItemsPlaced item=50303 category=REGULAR using regularPositions")
                end
            else
                logPlacement(it.sortCategory or zoneLabel, packIndex, it)
            end
            mi = mi + 1
        end
    end

    if mi <= #missing then
        bagSortDebug("WARNING", zoneLabel, "could not place", #missing - mi + 1, "items")
    end
end

local function applyBagLayout(sorted)
    if not sorted or bagSize < 1 or not JPackDB.asc then return end

    local hearthstone, pinnedMain, classPinned, boeItems, general = splitItemsForLayout(sorted)
    local backpackLo, backpackHi = packRangeForBagId(K.BAG_BACKPACK)

    if K.DEBUG_BAG_SORT and backpackLo and backpackHi then
        bagSortDebug("slot order start (backpack pack indices", backpackLo, "to", backpackHi, "):")
        for packIndex = backpackLo, backpackHi do
            local bag, slot = packIndexToBagSlot(packIndex)
            bagSortDebug(packIndex - backpackLo + 1, "packIndex", packIndex, "bag", bag, "slot", slot)
        end
    end

    local out = {}
    for i = 1, bagSize do
        out[i] = nil
    end

    local backpackGeneralFrom, boeOverflow = placeBackpackPinned(
        out, backpackLo, backpackHi, hearthstone, pinnedMain, classPinned, boeItems
    )

    backpackGeneralFrom = placeBoeOverflowInFront(out, boeOverflow, backpackLo, backpackHi, backpackGeneralFrom)

    local regularPositions = buildRegularFillPositions(backpackGeneralFrom)
    if #general > #regularPositions then
        appendExtraRegularPositions(regularPositions, out, backpackGeneralFrom)
    end

    if K.DEBUG_BAG_SORT then
        bagSortDebug("front zone backpack packIndex", backpackLo, "to", (backpackGeneralFrom or 0) - 1)
        bagSortDebug("regular positions:", #regularPositions)
    end

    for i = 1, #general do
        local packIndex = regularPositions[i]
        if packIndex then
            local it = general[i]
            out[packIndex] = it
            logRegularPlacement(packIndex, it, backpackLo, backpackGeneralFrom)
        end
    end

    ensureItemsPlacedInPositions(out, general, regularPositions, "REGULAR", backpackLo, backpackGeneralFrom)

    for i = 1, bagSize do
        sorted[i] = out[i]
        if sorted[i] then
            local zone = getPlacementZone(i, backpackLo, backpackGeneralFrom)
            debugTrackItem(sorted[i], "final-layout", format("packIndex=%s zone=%s", i, zone))
        end
    end
end

local function compare(a, b)
    return compareElvUI(a, b)
end

local function swap(items, i, j)
    items[i], items[j] = items[j], items[i]
end

local function qsort(items, from, to_)
    local i, j = from, to_
    local ix = items[i]
    local x = i
    while i < j do
        while j > x do
            if compare(items[j], ix) == 1 then
                swap(items, j, x)
                x = j
            else
                j = j - 1
            end
        end
        while i < x do
            if compare(items[i], ix) == -1 then
                swap(items, i, x)
                x = i
            else
                i = i + 1
            end
        end
    end
    if x - 1 > from then qsort(items, from, x - 1) end
    if x + 1 < to_ then qsort(items, x + 1, to_) end
end

local function jsort(items)
    local clone = {}
    for i = 1, bagSize do
        clone[i] = items[i]
    end
    qsort(clone, 1, bagSize)
    return clone
end

local function sortTo(_current, _to)
    packCurrent = _current
    packTo = _to
    lockedSlots = {}
    packingTickCount = 0
    JPACK_STEP = K.JPACK_PACKING
end

local function groupBagsSimple()
    wipe(JP.bagGroups)
    JP.bagGroups[1] = { 0, 1, 2, 3, 4 }
end

local function getPackingItems()
    local c = 1
    local items = {}
    if JPackDB.asc then
        for i = 1, #JP.packingBags do
            local num = SafeBagNumSlots(JP.packingBags[i])
            for j = 1, num do
                items[c] = getJPackItem(JP.packingBags[i], j, c)
                c = c + 1
            end
        end
    else
        for i = #JP.packingBags, 1, -1 do
            local num = SafeBagNumSlots(JP.packingBags[i])
            for j = num, 1, -1 do
                items[c] = getJPackItem(JP.packingBags[i], j, c)
                c = c + 1
            end
        end
    end
    if K.DEBUG_BAG_SORT then
        local found = 0
        for i = 1, c - 1 do
            if items[i] then found = found + 1 end
        end
        bagSortDebug("scan:", found, "items in", c - 1, "slots")
    end
    return items, c - 1
end

-- packIndex -> (bag, slot). Rebuilt at the start of every sort tick: bag sizes cannot
-- change between two rebuildPackCurrentFromBags calls inside one frame, and a single
-- moveOnce pass asks for the same indices hundreds of times.
local slotMap = { bag = {}, slot = {}, size = 0 }

local function rebuildSlotMap()
    local mapBag, mapSlot = slotMap.bag, slotMap.slot
    local n = 0
    if JPackDB.asc then
        for i = 1, #JP.packingBags do
            local bag = JP.packingBags[i]
            for j = 1, SafeBagNumSlots(bag) do
                n = n + 1
                mapBag[n], mapSlot[n] = bag, j
            end
        end
    else
        for i = #JP.packingBags, 1, -1 do
            local bag = JP.packingBags[i]
            local num = SafeBagNumSlots(bag)
            for j = num, 1, -1 do
                n = n + 1
                mapBag[n], mapSlot[n] = bag, j
            end
        end
    end
    for k = n + 1, slotMap.size do
        mapBag[k], mapSlot[k] = nil, nil
    end
    slotMap.size = n
end

local function getSlotId(packIndex)
    local bag = slotMap.bag[packIndex]
    if bag then
        return bag, slotMap.slot[packIndex]
    end
    return -1, -1
end

-- Должна быть ниже getSlotId: иначе Lua видит getSlotId как глобальную (nil)
local function rebuildPackCurrentFromBags()
    if bagSize <= 0 then return end
    rebuildSlotMap()
    wipe(lockedCache)
    for idx = 1, bagSize do
        local bag, slot = getSlotId(idx)
        packCurrent[idx] = getJPackItem(bag, slot)
    end
end

local function moveTo(oldIndex, newIndex)
    PickupContainerItem(getSlotId(oldIndex))
    PickupContainerItem(getSlotId(newIndex))
end

-- Lock state is stable between two rebuildPackCurrentFromBags calls, so one probe per
-- slot per tick is enough; GetLastSlotMatchingTarget alone asks up to 3x bagSize times.
local function isLocked(index)
    local cached = lockedCache[index]
    if cached ~= nil then
        return cached
    end
    local il = IndexOfTable(lockedSlots, index)
    local texture, _, locked = GetContainerItemInfo(getSlotId(index))
    if not texture then
        locked = il > 0
    elseif il > 0 then
        tremove(lockedSlots, il)
    end
    locked = locked and true or false
    if K.DEBUG_BAG_SORT and locked then
        local bag, slot = getSlotId(index)
        bagSortDebug("skip locked slot", bag, slot, "packIndex", index)
    end
    lockedCache[index] = locked
    return locked
end

-- Сначала по itemid (разные вещи с одним имени), иначе по имени — самый правый индекс
local function GetLastSlotMatchingTarget(items, target)
    if not target then return -1 end
    local id = resolveItemID(target)
    if id > 0 then
        for i = bagSize, 1, -1 do
            if items[i] and not isLocked(i) and resolveItemID(items[i]) == id then
                return i
            end
        end
    end
    if target.link then
        for i = bagSize, 1, -1 do
            if items[i] and not isLocked(i) and items[i].link == target.link then
                return i
            end
        end
    end
    local key = target.name
    for i = bagSize, 1, -1 do
        if items[i] and not isLocked(i) and items[i].name == key then
            return i
        end
    end
    return -1
end

local function sameItemAtSlot(i)
    local a, b = packTo[i], packCurrent[i]
    if not a and not b then return true end
    if not a or not b then return false end
    return itemsMatch(a, b)
end

local function isPackAlreadySorted()
    if bagSize <= 0 then
        return true
    end
    rebuildPackCurrentFromBags()
    for i = 1, bagSize do
        if not sameItemAtSlot(i) then
            return false
        end
    end
    return true
end

local function moveOnce()
    rebuildPackCurrentFromBags()

    if K.DEBUG_BAG_SORT_ITEM_ID and packingTickCount == 1 then
        debugFindTrackedItemInArray(packTo, "packTo (target)")
        debugFindTrackedItemInArray(packCurrent, "packCurrent (actual)")
    end

    local working = false
    local lockCount = 0
    for i = 1, bagSize do
        if not packTo[i] then
            -- В «пустом» по плану слоте лежит лишнее — переносим туда, где этот itemid ещё не на месте
            if packCurrent[i] and not isLocked(i) then
                working = true
                local id = resolveItemID(packCurrent[i])
                local nm = packCurrent[i].name
                local curLink = packCurrent[i].link
                for m = 1, bagSize do
                    if packTo[m] and not sameItemAtSlot(m) and not isLocked(m) then
                        local match = id > 0 and resolveItemID(packTo[m]) == id
                        if not match and curLink and packTo[m].link == curLink then
                            match = true
                        end
                        if not match and nm and packTo[m].name == nm and id <= 0 then
                            match = true
                        end
                        if match then
                            if K.DEBUG_BAG_SORT or (K.DEBUG_BAG_SORT_ITEM_ID and (id == K.DEBUG_BAG_SORT_ITEM_ID or resolveItemID(packTo[m]) == K.DEBUG_BAG_SORT_ITEM_ID)) then
                                bagSortDebug("move empty-slot fix", i, "->", m, packCurrent[i] and packCurrent[i].name, "id", id)
                            end
                            moveTo(i, m)
                            rebuildPackCurrentFromBags()
                            return true
                        end
                    end
                end
            end
        else
            local locked = isLocked(i)
            if locked == nil then locked = false end
            if locked then
                lockCount = lockCount + 1
            end
            if lockCount > K.JPACK_MAXMOVE_ONCE then
                return true
            end
            if not sameItemAtSlot(i) then
                working = true
                if not locked then
                    local slot = GetLastSlotMatchingTarget(packCurrent, packTo[i])
                    if slot > 0 and slot ~= i then
                        if K.DEBUG_BAG_SORT or (K.DEBUG_BAG_SORT_ITEM_ID and resolveItemID(packTo[i]) == K.DEBUG_BAG_SORT_ITEM_ID) then
                            bagSortDebug("move", slot, "->", i, packTo[i] and packTo[i].name, "id", packTo[i] and resolveItemID(packTo[i]))
                        end
                        moveTo(slot, i)
                        rebuildPackCurrentFromBags()
                        if packCurrent[slot] == nil then
                            lockedSlots[#lockedSlots + 1] = i
                        end
                        return true
                    end
                end
            end
        end
    end
    return working or lockCount > 0
end

local function stackOnce()
    local bags = { 4, 3, 2, 1, 0 }
    local pendingStack = {}
    local complet = true
    for bi = 1, #bags do
        local bag = bags[bi]
        local numSlots = SafeBagNumSlots(bag)
        for slot = numSlots, 1, -1 do
            local texture, itemCount, locked = GetContainerItemInfo(bag, slot)
            local item = getJPackItem(bag, slot)
            if item then
                if not locked then
                    if (item.stackCount ~= 1) and (itemCount < item.stackCount) then
                        local slotInfo = pendingStack[item.itemid]
                        if slotInfo then
                            PickupContainerItem(bag, slot)
                            PickupContainerItem(slotInfo[1], slotInfo[2])
                            pendingStack[item.itemid] = nil
                            complet = false
                        else
                            pendingStack[item.itemid] = { bag, slot }
                        end
                    end
                else
                    complet = false
                end
            end
        end
    end
    return complet
end

local function startPack()
    clearBindStateCache()
    local items, count = getPackingItems()
    bagSize = count
    BuildSortOrder()
    local sorted = jsort(items)
    applyBagLayout(sorted)
    if K.DEBUG_BAG_SORT or K.DEBUG_BAG_SORT_ITEM_ID then
        bagSortDebug("=== DEBUG ON itemID", K.DEBUG_BAG_SORT_ITEM_ID or "all", "===")
    end
    if K.DEBUG_BAG_SORT then
        bagSortDebug("layout applied, target order:")
        for i = 1, bagSize do
            local it = sorted[i]
            if it then
                bagSortDebug(
                    "target", i, it.name, "id", it.itemid,
                    "cat", getItemSortCategory(it),
                    "elv", GetElvUISortCategoryLabel(it)
                )
            end
        end
    end
    sortTo(items, sorted)
    if isPackAlreadySorted() then
        FinishSortRun()
    end
end

local function IsSortInProgress()
    return JPACK_STEP ~= K.JPACK_STOPPED
end

local function GetContainerFrameForBagID(bagID)
    if baudUI.isMode() then
        if bagID and bagID >= 0 and bagID <= K.PLAYER_BAG_MAX then
            local sub = _G["BaudBagSubBag" .. bagID]
            if sub and sub:IsShown() then
                local parent = sub:GetParent()
                if parent and parent:IsShown() then
                    return parent
                end
            end
        end
        return nil
    end

    if IsBagOpen then
        local frameIndex = IsBagOpen(bagID)
        if frameIndex then
            local frame = _G["ContainerFrame" .. frameIndex]
            if frame and frame:IsShown() then
                return frame
            end
        end
    end

    for i = 1, K.NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() and frame.GetID and frame:GetID() == bagID then
            return frame
        end
    end

    if bagID == K.BACKPACK_BAG_ID then
        local combined = _G.ContainerFrameCombinedBags
        if combined and combined:IsShown() and combined.GetID and combined:GetID() == K.BACKPACK_BAG_ID then
            return combined
        end
    end

    return nil
end

local function GetBackpackContainerFrame()
    if baudUI.isMode() then
        local sub = _G.BaudBagSubBag0
        local parent = sub and sub:GetParent()
        if parent and parent:IsShown() then
            return parent
        end
        local fallback = _G.BBCont1_1
        if fallback and fallback:IsShown() then
            return fallback
        end
        return nil
    end
    return GetContainerFrameForBagID(K.BACKPACK_BAG_ID)
end

local function IsBackpackContainerFrame(frame)
    if not frame then return false end
    if baudUI.isMode() then
        local sub = _G.BaudBagSubBag0
        if sub and sub:GetParent() == frame then
            return true
        end
        return frame == _G.BBCont1_1
    end
    return frame.GetID and frame:GetID() == K.BACKPACK_BAG_ID
end

local function IsPlayerBagID(bagID)
    return bagID >= 0 and bagID <= K.PLAYER_BAG_MAX
end

local function ForEachBackpackSlot(callback)
    if baudUI.isMode() then
        local sub = _G.BaudBagSubBag0
        if not sub or not sub:IsShown() then return end
        local numSlots = sub.size or SafeBagNumSlots(K.BACKPACK_BAG_ID)
        for slot = 1, numSlots do
            local button = _G[sub:GetName() .. "Item" .. slot]
            if button then
                callback(button, slot)
            end
        end
        return
    end

    local container = GetBackpackContainerFrame()
    if not container then return end

    local numSlots = SafeBagNumSlots(K.BACKPACK_BAG_ID)
    for slot = 1, numSlots do
        local button = _G[container:GetName() .. "Item" .. slot]
        if button then
            callback(button, slot)
        end
    end
end

local function ResetSlotButtonVisual(button)
    if not button then return end

    SetItemButtonDesaturated(button, 0)
    button:SetAlpha(1)

    local icon = button.icon
    local buttonName = button.GetName and button:GetName()
    if not icon and buttonName then
        icon = _G[buttonName .. "IconTexture"]
    end
    if not icon and button.IconTexture then
        icon = button.IconTexture
    end
    if icon then
        icon:SetAlpha(1)
        if icon.SetDesaturated then
            icon:SetDesaturated(false)
        end
        if icon.SetVertexColor then
            icon:SetVertexColor(1, 1, 1)
        end
    end

    if button.GetNormalTexture then
        local normal = button:GetNormalTexture()
        if normal then
            normal:SetAlpha(1)
        end
    end
    if button.GetPushedTexture then
        local pushed = button:GetPushedTexture()
        if pushed then
            pushed:SetAlpha(1)
        end
    end
end

local SEARCH_PLACEHOLDERS = {
    ["Search"] = true,
    ["Поиск"] = true,
}
if _G.SEARCH then
    SEARCH_PLACEHOLDERS[_G.SEARCH] = true
end

local function ForEachOpenClassicBagFrame(callback)
    if baudUI.isMode() then
        for bagID = 0, K.PLAYER_BAG_MAX do
            local sub = _G["BaudBagSubBag" .. bagID]
            if sub and sub:IsShown() then
                local parent = sub:GetParent()
                if parent and parent:IsShown() then
                    callback(parent, bagID)
                end
            end
        end
        return
    end

    for bagID = 0, K.PLAYER_BAG_MAX do
        local container = GetContainerFrameForBagID(bagID)
        if container and container:IsShown() then
            callback(container, bagID)
        end
    end
end

local function ForEachOpenClassicBagButton(callback)
    if baudUI.isMode() then
        for bagID = 0, K.PLAYER_BAG_MAX do
            local sub = _G["BaudBagSubBag" .. bagID]
            if sub and sub:IsShown() then
                local parent = sub:GetParent()
                if parent and parent:IsShown() then
                    local numSlots = sub.size or SafeBagNumSlots(bagID)
                    for slot = 1, numSlots do
                        local button = _G[sub:GetName() .. "Item" .. slot]
                        if button and button:IsShown() then
                            callback(button, bagID, slot)
                        end
                    end
                end
            end
        end
        return
    end

    ForEachOpenClassicBagFrame(function(container, bagID)
        local numSlots = SafeBagNumSlots(bagID)
        for slot = 1, numSlots do
            local button = _G[container:GetName() .. "Item" .. slot]
            if button then
                callback(button, bagID, slot)
            end
        end
    end)
end

local function GetClassicBagSearchText()
    if not searchEditBox then
        return nil
    end

    local text = searchEditBox:GetText()
    if text == nil then
        return nil
    end
    if type(text) ~= "string" then
        text = tostring(text)
    end
    if text == "" then
        return nil
    end
    if SEARCH_PLACEHOLDERS[text] then
        return nil
    end

    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" or SEARCH_PLACEHOLDERS[trimmed] then
        return nil
    end

    return strlower(trimmed)
end

local function IsClassicBagSearchActive()
    return GetClassicBagSearchText() ~= nil
end

local function EnsureClassicSearchOverlay(button)
    if button.SarychUISearchOverlay then
        return button.SarychUISearchOverlay
    end
    if button.sarychSearchOverlay then
        button.SarychUISearchOverlay = button.sarychSearchOverlay
        return button.SarychUISearchOverlay
    end

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    overlay:SetVertexColor(0, 0, 0)
    overlay:SetAlpha(0.55)
    overlay:SetAllPoints(button)
    overlay:Hide()
    button.SarychUISearchOverlay = overlay
    return overlay
end

local function GetClassicBagButtonBagSlot(button)
    if not button then
        return nil
    end
    local slot = button.GetID and button:GetID()
    local parent = button:GetParent()
    local bagID = parent and parent.GetID and parent:GetID()
    if bagID and slot and IsPlayerBagID(bagID) then
        return bagID, slot
    end
end

local function ItemButtonMatchesClassicSearch(button, query)
    local bagID, slot = GetClassicBagButtonBagSlot(button)
    if not bagID then
        return false
    end

    local link = GetContainerItemLink(bagID, slot)
    if not link then
        return false
    end

    local name = GetItemInfo(link)
    if not name then
        name = link:match("%[(.-)%]")
    end
    if not name then
        return false
    end

    return strlower(name):find(query, 1, true) ~= nil
end

local function ResetClassicBagSearchVisuals()
    ForEachOpenClassicBagButton(function(button)
        if button.SarychUISearchOverlay then
            button.SarychUISearchOverlay:Hide()
        end
        if button.sarychSearchOverlay then
            button.sarychSearchOverlay:Hide()
        end
    end)
end

local function ApplyClassicBagSearch()
    if sortLoaderActive or IsSortInProgress() then
        return
    end

    local query = GetClassicBagSearchText()
    if not query then
        ResetClassicBagSearchVisuals()
        return
    end

    ForEachOpenClassicBagButton(function(button)
        local overlay = EnsureClassicSearchOverlay(button)
        if ItemButtonMatchesClassicSearch(button, query) then
            overlay:Hide()
        else
            overlay:Show()
        end
    end)
end

local function ReapplyClassicBagSearchIfNeeded()
    if not IsBagSearchEnabled() then
        ResetClassicBagSearchVisuals()
        return
    end
    if not searchEditBox or not searchEditBox:IsShown() then
        ResetClassicBagSearchVisuals()
        return
    end
    ApplyClassicBagSearch()
end

local classicBagSearchRefreshScheduled = false

local function ScheduleClassicBagSearchRefresh()
    if not IsClassicBagsUIMode() or sortLoaderActive or not IsBagSearchEnabled() or IsSortInProgress() then
        return
    end

    if classicBagSearchRefreshScheduled then
        return
    end

    classicBagSearchRefreshScheduled = true
    local function runRefresh()
        classicBagSearchRefreshScheduled = false
        if not IsClassicBagsUIMode() or sortLoaderActive or not IsBagSearchEnabled() or IsSortInProgress() then
            return
        end
        local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
        if IsClassicBagSearchActive() then
            ApplyClassicBagSearch()
        else
            ResetClassicBagSearchVisuals()
        end
        if SarychUI_PerfSlow then
            SarychUI_PerfSlow("Bags", "ClassicSearchRefreshSlow", perfStart, nil, 3)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, runRefresh)
    elseif IsClassicBagSearchActive() then
        runRefresh()
    else
        ResetClassicBagSearchVisuals()
    end
end

local function RestoreSlotSortVisual(button, bagID, slot)
    if not button then return end

    local _, _, locked = GetContainerItemInfo(bagID, slot)
    SetItemButtonDesaturated(button, locked and 1 or 0)
    button:SetAlpha(1)

    local buttonName = button.GetName and button:GetName()
    local icon = button.icon
    if not icon and buttonName then
        icon = _G[buttonName .. "IconTexture"]
    end
    if not icon and button.IconTexture then
        icon = button.IconTexture
    end
    if icon then
        icon:SetAlpha(1)
        if icon.SetDesaturated then
            icon:SetDesaturated(false)
        end
        if icon.SetVertexColor then
            icon:SetVertexColor(1, 1, 1)
        end
    end
end

local function ShowSortSpinner(parent)
	if parent and SarychUI and SarychUI.ShowSpinnerOn then
		SarychUI:ShowSpinnerOn(parent)
	end
end

local function HideSortSpinner(parent)
	if SarychUI and SarychUI.HideSpinner then
		SarychUI:HideSpinner(parent)
	end
end

local function ApplySortingVisualToFrame(frame, active)
    if not frame or not IsClassicBagsUIMode() then
        return
    end
    if active then
        ShowSortSpinner(frame)
    else
        HideSortSpinner(frame)
    end
end

local function UpdateClassicBagsSortingOverlays()
    if not IsClassicBagsUIMode() then
        return
    end
    ForEachOpenClassicBagFrame(function(frame)
        ApplySortingVisualToFrame(frame, sortLoaderActive)
    end)
end

local function FinalizeClassicBagSortVisualState()
    sortLoaderActive = false
    sortLoaderFailsafeElapsed = 0
    HideSortSpinner()

    if sortButton then
        sortButton:Enable()
    end

    local searchActive = IsClassicBagSearchActive()

    ForEachOpenClassicBagButton(function(button, bagID, slot)
        RestoreSlotSortVisual(button, bagID, slot)
        if not searchActive then
            if button.SarychUISearchOverlay then
                button.SarychUISearchOverlay:Hide()
            end
            if button.sarychSearchOverlay then
                button.sarychSearchOverlay:Hide()
            end
        end
    end)

    if searchActive then
        ApplyClassicBagSearch()
    else
        ResetClassicBagSearchVisuals()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if sortLoaderActive or IsSortInProgress() then
                return
            end
            ForEachOpenClassicBagButton(RestoreSlotSortVisual)
            if IsClassicBagSearchActive() then
                ApplyClassicBagSearch()
            else
                ResetClassicBagSearchVisuals()
            end
        end)
    end
end

local function StopSortLoader()
    FinalizeClassicBagSortVisualState()
end

local function StartSortLoader()
    if sortLoaderActive then return end
    sortLoaderActive = true
    sortLoaderFailsafeElapsed = 0

    UpdateClassicBagsSortingOverlays()

    if sortButton then
        sortButton:Disable()
    end
end

FinishSortRun = function(message)
    if message then
        PrintMsg(message)
    end
    JPACK_STEP = K.JPACK_STOPPED
    sortDriver:SetScript("OnUpdate", nil)
    sortDriver:Hide()
    packCurrent, packTo = nil, nil
    packingTickCount = 0
    FinalizeClassicBagSortVisualState()
    finishElvUIBagSort()
end

local function stopPacking()
    elapsed = 0
    FinishSortRun()
end

local function onSortUpdate(self, el)
    local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
    if sortLoaderActive then
        sortLoaderFailsafeElapsed = sortLoaderFailsafeElapsed + el
        if sortLoaderFailsafeElapsed >= K.SORT_LOADER_FAILSAFE_SEC then
            FinishSortRun("Сортировка остановлена: превышено время ожидания.")
            return
        end
    end

    elapsed = elapsed + el
    if elapsed < JP.updatePeriod then return end
    elapsed = 0

    if JPACK_STEP == K.JPACK_STARTED then
        if stackOnce() then
            JPACK_STEP = K.JPACK_STACK_OVER
        elseif not CursorHoldsItem() then
            JPACK_STEP = K.JPACK_STACK_OVER
        end
    elseif JPACK_STEP == K.JPACK_STACK_OVER then
        if isAllBagReady() or not CursorHoldsItem() then
            JP.packingBags = JP.bagGroups[1]
            startPack()
            if JPACK_STEP == K.JPACK_STOPPED then
                return
            end
            StartSortLoader()
        end
    elseif JPACK_STEP == K.JPACK_PACKING then
        packingTickCount = packingTickCount + 1
        if packingTickCount > K.PACKING_MAX_TICKS then
            FinishSortRun("Сортировка остановлена: слишком много шагов (проверьте заблокированные слоты или положите предмет с курсора).")
            return
        end
        if not moveOnce() then
            if isAllBagReady() then
                FinishSortRun()
            else
                JPACK_STEP = K.JPACK_FINISHING
            end
        end
    elseif JPACK_STEP == K.JPACK_FINISHING then
        if isAllBagReady() then
            if K.DEBUG_BAG_SORT or K.DEBUG_BAG_SORT_ITEM_ID then
                debugReportTrackedItemFinalLocation()
            end
            FinishSortRun()
        end
    end
    if SarychUI_PerfSlow then
        SarychUI_PerfSlow("Bags", "SortOnUpdateSlow", perfStart, tostring(JPACK_STEP), 3)
    end
end

local function beginPack()
    if IsSortInProgress() then
        return
    end
    if CursorHoldsItem() then
        PrintMsg("Уберите предмет с курсора перед сортировкой.")
        return
    end
    if InCombatLockdown() then
        PrintMsg("Нельзя сортировать сумки в бою.")
        return
    end
    if not GetBackpackContainerFrame() then
        PrintMsg("Откройте основную сумку для сортировки.")
        return
    end
    groupBagsSimple()
    JP.packingBags = JP.bagGroups[1]
    JPACK_STEP = K.JPACK_STARTED
    elapsed = JP.updatePeriod
    if SarychUI_PerfLog then
        SarychUI_PerfLog("Bags", "BeginSort", "classic")
    end
    sortDriver:Show()
    sortDriver:SetScript("OnUpdate", onSortUpdate)
end

local function SetSortButtonTexture(btn, layer, texPath)
    local getter = (layer == "PUSHED") and btn.GetPushedTexture
        or (layer == "HIGHLIGHT") and btn.GetHighlightTexture
        or btn.GetNormalTexture
    local tex = getter(btn)
    if not tex then
        tex = btn:CreateTexture(nil, "ARTWORK")
        if layer == "PUSHED" then
            btn:SetPushedTexture(tex)
        elseif layer == "HIGHLIGHT" then
            btn:SetHighlightTexture(tex)
        else
            btn:SetNormalTexture(tex)
        end
    end
    tex:SetTexture(texPath)
    tex:SetAllPoints(btn)
end

local function ShowBagSortTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    local tip = "Сортировать сумки"
    if SarychUI and SarychUI.T then
        tip = SarychUI:T(tip)
    end
    GameTooltip:SetText(tip, 1, 1, 1)
    GameTooltip:Show()
end

local function UpdateSearchBoxVisibility()
    if not searchEditBox then return end

    local parent = GetBackpackContainerFrame()
    if not IsBagSearchEnabled() or not parent or not parent:IsShown() or not IsBackpackContainerFrame(parent) then
        searchEditBox:Hide()
        return
    end

    searchEditBox:Show()
    baudUI.anchor(parent)
end

local function EnsureSearchEditBox(parent)
    if searchEditBox then return searchEditBox end

    local box = CreateFrame("EditBox", "SarychUIBagSearchBox", parent)
    box:SetSize(K.SEARCH_BOX_WIDTH, K.SEARCH_BOX_HEIGHT)
    box:SetAutoFocus(false)
    box:SetMaxLetters(50)
    box:SetFontObject(ChatFontNormal)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetFrameStrata("HIGH")
    box:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 50)

    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.75)
        box:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
    end

    local icon = box:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", box, "LEFT", 4, -1)
    icon:Hide() -- classic bags: no magnifying glass (BaudBag may show it)
    box.searchIcon = icon

    box:SetScript("OnTextChanged", function(self)
        ApplyClassicBagSearch()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        ResetClassicBagSearchVisuals()
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    box:SetText("")

    searchEditBox = box
    return box
end

local function UpdateSortButtonVisibility()
    if not sortButton then return end
    if not IsBagSortEnabled() then
        sortButton:Hide()
        return
    end
    local parent = GetBackpackContainerFrame()
    if not parent or not parent:IsShown() or not IsBackpackContainerFrame(parent) then
        sortButton:Hide()
        return
    end
    sortButton:Show()
    baudUI.anchor(parent)
end

local function InstallBagSortFrameHooks()
    local function onBagFrameToggle()
        if sortLoaderActive then
            UpdateClassicBagsSortingOverlays()
        end
        if module.ApplyBagSortSettings then
            module:ApplyBagSortSettings()
        end
        ScheduleClassicBagSearchRefresh()
    end

    local function onContainerFrameHide(self)
        -- BaudBag starts close with a fade: OnHide fires once while Closing+FadeStart, then re-Shows.
        if self and self.Closing and self.FadeStart then
            return
        end
        if IsBackpackContainerFrame(self) then
            if IsSortInProgress() then
                stopPacking()
            else
                StopSortLoader()
            end
            if searchEditBox then
                searchEditBox:Hide()
                searchEditBox:SetText("")
            end
            ResetClassicBagSearchVisuals()
        elseif self.GetID and IsPlayerBagID(self:GetID()) then
            ScheduleClassicBagSearchRefresh()
        elseif baudUI.isMode() and self.BagSet == 1 then
            ScheduleClassicBagSearchRefresh()
        end
        -- Defer layout refresh: sync ApplyBagSortSettings inside OpenAllBags Hide()
        -- re-enters bag slot loops and can error with nil GetContainerNumSlots.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if module.ApplyBagSortSettings then
                    module:ApplyBagSortSettings()
                end
            end)
        elseif module.ApplyBagSortSettings then
            module:ApplyBagSortSettings()
        end
    end

    if not sortButtonHooksInstalled then
        sortButtonHooksInstalled = true

        local combined = _G.ContainerFrameCombinedBags
        if combined and combined.HookScript then
            combined:HookScript("OnShow", onBagFrameToggle)
            combined:HookScript("OnHide", onContainerFrameHide)
        end

        for i = 1, K.NUM_CONTAINER_FRAMES do
            local frame = _G["ContainerFrame" .. i]
            if frame and frame.HookScript then
                frame:HookScript("OnShow", onBagFrameToggle)
                frame:HookScript("OnHide", onContainerFrameHide)
            end
        end
    end

    if not baudBagSortHooksInstalled and (BaudBagContainer_OnShow or _G.BBCont1_1) then
        baudBagSortHooksInstalled = true
        if hooksecurefunc then
            if BaudBagContainer_OnShow then
                hooksecurefunc("BaudBagContainer_OnShow", function(self)
                    if not baudUI.isMode() then return end
                    if self and self.BagSet == 1 then
                        onBagFrameToggle()
                    end
                end)
            end
            if BaudBagContainer_OnHide then
                hooksecurefunc("BaudBagContainer_OnHide", function(self)
                    if not baudUI.isMode() then return end
                    onContainerFrameHide(self)
                end)
            end
        end
        local baudMain = _G.BBCont1_1
        if baudMain and baudMain.HookScript then
            baudMain:HookScript("OnShow", onBagFrameToggle)
            baudMain:HookScript("OnHide", onContainerFrameHide)
        end
    end
end

function module:ApplyBagSortSettings()
    if not IsClassicBagsUIMode() then
        self:DisableBagSortButton()
        return
    end

    InstallBagSortFrameHooks()

    local parent = GetBackpackContainerFrame() or UIParent

    if IsBagSortEnabled() then
        if not sortButton then
            sortButton = CreateFrame("Button", "SarychUIBagSortButton", parent)
            sortButton:SetSize(K.SORT_BTN_SIZE, K.SORT_BTN_SIZE)
            sortButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", K.SORT_BTN_OFFSET_X, K.SORT_BTN_OFFSET_Y)
            sortButton:SetFrameStrata("HIGH")
            sortButton:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 50)
            sortButton:RegisterForClicks("LeftButtonUp")
            sortButton:EnableMouse(true)
            sortButton:SetScript("OnEnter", function(btn)
                ShowBagSortTooltip(btn)
            end)
            sortButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            sortButton:SetScript("OnClick", function()
                if not IsDefaultBagSortActive() then return end
                if IsSortInProgress() then return end
                beginPack()
            end)
        end

        SetSortButtonTexture(sortButton, "NORMAL", K.SORT_BTN_TEX_UP)
        SetSortButtonTexture(sortButton, "PUSHED", K.SORT_BTN_TEX_DOWN)
        SetSortButtonTexture(sortButton, "HIGHLIGHT", K.SORT_BTN_TEX_UP)
        local highlight = sortButton:GetHighlightTexture()
        if highlight then
            highlight:SetAlpha(0.4)
        end

        UpdateSortButtonVisibility()
    elseif sortButton then
        sortButton:Hide()
    end

    if IsBagSearchEnabled() then
        EnsureSearchEditBox(parent)
        UpdateSearchBoxVisibility()
        if not sortLoaderActive then
            ReapplyClassicBagSearchIfNeeded()
        end
    else
        if searchEditBox then
            searchEditBox:Hide()
            searchEditBox:SetText("")
        end
        ResetClassicBagSearchVisuals()
    end

    if sortLoaderActive then
        UpdateClassicBagsSortingOverlays()
    end
end

function module:ResetClassicBagSearch()
    if searchEditBox then
        searchEditBox:SetText("")
        searchEditBox:Hide()
    end
    ResetClassicBagSearchVisuals()
end

function module:DisableBagSortButton()
    stopPacking()
    StopSortLoader()
    self:ResetClassicBagSearch()
    if sortButton then
        sortButton:Hide()
    end
end

-- ElvUI mode uses embedded SarychUI_Bags Sort.lua (B.SortBags), not SarychUI JPack sort.
function module:BeginElvUIBagSort()
    sortElvDebug("blocked: elvui mode uses SarychUI_Bags SortBags")
    return false, "elvui_native_sort"
end

local bagSortSettingsRefreshScheduled = false

local function ScheduleApplyBagSortSettings()
    if bagSortSettingsRefreshScheduled then
        return
    end
    bagSortSettingsRefreshScheduled = true
    local function runRefresh()
        bagSortSettingsRefreshScheduled = false
        if module.ApplyBagSortSettings then
            local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
            module:ApplyBagSortSettings()
            if SarychUI_PerfSlow then
                SarychUI_PerfSlow("Bags", "ApplyBagSortSettingsSlow", perfStart, nil, 3)
            end
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, runRefresh)
    else
        runRefresh()
    end
end

local bagSortPew = CreateFrame("Frame")
local bagSortEventsRegistered = false

function SarychUI_BagSort_RegisterEvents()
    if bagSortEventsRegistered then
        return
    end
    if not IsClassicBagsUIMode() then
        return
    end
    bagSortPew:RegisterEvent("PLAYER_ENTERING_WORLD")
    bagSortPew:RegisterEvent("BAG_UPDATE")
    bagSortPew:RegisterEvent("BAG_FRAME_UPDATE")
    bagSortEventsRegistered = true
end

function SarychUI_BagSort_UnregisterEvents()
    if not bagSortEventsRegistered then
        return
    end
    bagSortPew:UnregisterEvent("PLAYER_ENTERING_WORLD")
    bagSortPew:UnregisterEvent("BAG_UPDATE")
    bagSortPew:UnregisterEvent("BAG_FRAME_UPDATE")
    bagSortEventsRegistered = false
end

bagSortPew:SetScript("OnEvent", function(_, event, bagID)
    if not IsClassicBagsUIMode() then
        return
    end
    if SarychUI_PerfLog then
        SarychUI_PerfLog("Bags", event, bagID)
    end
    if IsSortInProgress() and not GetBackpackContainerFrame() then
        stopPacking()
    elseif sortLoaderActive and not GetBackpackContainerFrame() then
        StopSortLoader()
    end
    ScheduleApplyBagSortSettings()
    if event == "BAG_UPDATE" or event == "BAG_FRAME_UPDATE" then
        ScheduleClassicBagSearchRefresh()
    end
end)
