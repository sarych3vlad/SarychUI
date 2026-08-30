--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local _G = _G
local type = type
local tonumber = tonumber
local select = select

local GetItemInfo = GetItemInfo
local GetItemIcon = GetItemIcon
local GetItemGem = GetItemGem

local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink

local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemCount = GetInventoryItemCount
local GetInventoryItemQuality = GetInventoryItemQuality
local GetInventoryItemTexture = GetInventoryItemTexture
local IsInventoryItemLocked = IsInventoryItemLocked

local GetItemStats = GetItemStats
local GetItemCooldown = GetItemCooldown
local GetItemCount = GetItemCount
local GetItemSpell = GetItemSpell
local GetItemFamily = GetItemFamily
local GetItemStatDelta = GetItemStatDelta
local GetItemUniqueness = GetItemUniqueness

local IsConsumableItem = IsConsumableItem
local IsCurrentItem = IsCurrentItem
local IsDressableItem = IsDressableItem
local IsEquippableItem = IsEquippableItem
local IsEquippedItem = IsEquippedItem
local IsEquippedItemType = IsEquippedItemType
local IsHarmfulItem = IsHarmfulItem
local IsHelpfulItem = IsHelpfulItem
local IsItemInRange = IsItemInRange
local IsUsableItem = IsUsableItem
local ItemHasRange = ItemHasRange

local VERSION = 1

local function GetItemIDFromItemInfo(item)
	if type(item) == "number" then
		return item > 0 and item or nil
	end

	if type(item) == "string" then
		local itemID = tonumber(item:match("item:(%d+)"))
		if itemID then
			return itemID
		end

		itemID = tonumber(item)
		if itemID and itemID > 0 then
			return itemID
		end
	end

	return nil
end

local function GetItemLinkFromLocation(itemLocation)
	if not itemLocation then
		return nil
	end

	if itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() then
		local bagID, slotIndex = itemLocation:GetBagAndSlot()
		return GetContainerItemLink(bagID, slotIndex)
	end

	if itemLocation.IsEquipmentSlot and itemLocation:IsEquipmentSlot() then
		return GetInventoryItemLink("player", itemLocation:GetEquipmentSlot())
	end
	
	if itemLocation.IsUnitEquipmentSlot and itemLocation:IsUnitEquipmentSlot() then
		local unitToken, equipmentSlotIndex = itemLocation:GetUnitEquipmentSlot()
		return GetInventoryItemLink(unitToken, equipmentSlotIndex)
	end

	return nil
end

local function GetItemIDFromLocation(itemLocation)
	if not itemLocation then
		return nil
	end

	if itemLocation.IsEquipmentSlot and itemLocation:IsEquipmentSlot() and GetInventoryItemID then
		local itemID = GetInventoryItemID("player", itemLocation:GetEquipmentSlot())
		if itemID and itemID > 0 then
			return itemID
		end
	end

	return GetItemIDFromItemInfo(GetItemLinkFromLocation(itemLocation))
end

local function GetItemInfoFromLocation(itemLocation)
	local itemLink = GetItemLinkFromLocation(itemLocation)
	if not itemLink then
		return nil
	end

	return GetItemInfo(itemLink)
end

local function GetItemIconFromLocation(itemLocation)
	if not itemLocation then
		return nil
	end

	if itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() then
		local bagID, slotIndex = itemLocation:GetBagAndSlot()
		local texture = GetContainerItemInfo(bagID, slotIndex)
		return texture
	end

	if itemLocation.IsEquipmentSlot and itemLocation:IsEquipmentSlot() then
		return GetInventoryItemTexture("player", itemLocation:GetEquipmentSlot())
	end

	return nil
end

local function GetItemQualityFromLocation(itemLocation)
	if not itemLocation then
		return nil
	end

	if itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() then
		local bagID, slotIndex = itemLocation:GetBagAndSlot()
		local _, _, _, quality = GetContainerItemInfo(bagID, slotIndex)
		return quality
	end

	if itemLocation.IsEquipmentSlot and itemLocation:IsEquipmentSlot() then
		return GetInventoryItemQuality("player", itemLocation:GetEquipmentSlot())
	end

	return nil
end

local function GetStackCountFromLocation(itemLocation)
	if not itemLocation then
		return nil
	end

	if itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() then
		local bagID, slotIndex = itemLocation:GetBagAndSlot()
		local _, itemCount = GetContainerItemInfo(bagID, slotIndex)
		return itemCount
	end

	if itemLocation.IsEquipmentSlot and itemLocation:IsEquipmentSlot() then
		return GetInventoryItemCount("player", itemLocation:GetEquipmentSlot())
	end

	return nil
end

local function IsItemLocationLocked(itemLocation)
	if not itemLocation then
		return false
	end

	if itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() then
		local bagID, slotIndex = itemLocation:GetBagAndSlot()
		local _, _, isLocked = GetContainerItemInfo(bagID, slotIndex)
		return isLocked or false
	end

	if itemLocation.IsEquipmentSlot and itemLocation:IsEquipmentSlot() then
		return IsInventoryItemLocked(itemLocation:GetEquipmentSlot()) or false
	end

	return false
end

Aegis:RegisterNamespace("C_Item", VERSION, function(_, state, namespace)
	local C_Item = namespace or {};
	C_Item.SupportsItemGUID = false;

	function C_Item.GetItemIDForItemInfo(item)
		return GetItemIDFromItemInfo(item)
	end

	function C_Item.DoesItemExistByID(item)
		return GetItemIDFromItemInfo(item) ~= nil
	end

	function C_Item.DoesItemExist(itemLocation)
		return GetItemLinkFromLocation(itemLocation) ~= nil
	end

	function C_Item.GetItemID(itemLocation)
		return GetItemIDFromLocation(itemLocation)
	end

	function C_Item.GetItemGUID(itemLocation)
		return nil
	end

	function C_Item.GetItemLocation(itemGUID)
		return nil
	end

	function C_Item.GetItemInfo(item)
		return GetItemInfo(item)
	end

	function C_Item.GetItemInfoInstant(item)
		local itemID = GetItemIDFromItemInfo(item)
		if not itemID then
			return nil
		end

		local _, _, _, _, _, itemType, itemSubType, _, itemEquipLoc, icon = GetItemInfo(item)
		if not icon and GetItemIcon then
			icon = GetItemIcon(itemID);
		end

		return itemID, itemType, itemSubType, itemEquipLoc, icon, nil, nil
	end

	function C_Item.GetItemLink(itemLocation)
		return GetItemLinkFromLocation(itemLocation)
	end

	function C_Item.GetItemName(itemLocation)
		local itemName = GetItemInfoFromLocation(itemLocation);
		return itemName;
	end

	function C_Item.GetItemNameByID(item)
		local itemName = GetItemInfo(item);
		return itemName;
	end

	function C_Item.GetItemIcon(itemLocation)
		return GetItemIconFromLocation(itemLocation)
	end

	function C_Item.GetItemIconByID(item)
		if GetItemIcon then
			return GetItemIcon(item)
		end
		local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(item);
		return icon;
	end

	function C_Item.GetItemQuality(itemLocation)
		return GetItemQualityFromLocation(itemLocation)
	end

	function C_Item.GetItemQualityByID(item)
		local _, _, itemQuality = GetItemInfo(item);
		return itemQuality;
	end

	function C_Item.GetStackCount(itemLocation)
		return GetStackCountFromLocation(itemLocation)
	end

	function C_Item.GetDetailedItemLevelInfo(item)
		local _, _, _, itemLevel = GetItemInfo(item);
		return itemLevel;
	end

	function C_Item.GetCurrentItemLevel(itemLocation)
		local itemLink = GetItemLinkFromLocation(itemLocation)
		if not itemLink then
			return nil
		end
		return C_Item.GetDetailedItemLevelInfo(itemLink)
	end

	function C_Item.GetItemMaxStackSize(itemLocation)
		local itemLink = GetItemLinkFromLocation(itemLocation);
		if not itemLink then
			return nil;
		end

		local _, _, _, _, _, _, _, maxStackSize = GetItemInfo(itemLink);
		return maxStackSize;
	end

	function C_Item.GetItemMaxStackSizeByID(item)
		local _, _, _, _, _, _, _, maxStackSize = GetItemInfo(item);
		return maxStackSize;
	end

	function C_Item.GetItemInventoryType(itemLocation)
		local itemLink = GetItemLinkFromLocation(itemLocation);
		if not itemLink then
			return nil;
		end

		local _, _, _, _, _, _, _, _, inventoryType = GetItemInfo(itemLink);
		return inventoryType;
	end

	function C_Item.GetItemInventoryTypeByID(item)
		local _, _, _, _, _, _, _, _, inventoryType = GetItemInfo(item)
		return inventoryType
	end

	function C_Item.IsItemDataCached(itemLocation)
		local itemLink = GetItemLinkFromLocation(itemLocation)
		if not itemLink then
			return false
		end
		return GetItemInfo(itemLink) ~= nil
	end

	function C_Item.IsItemDataCachedByID(item)
		return GetItemInfo(item) ~= nil
	end

	function C_Item.RequestLoadItemDataByID(item)
		local itemID = GetItemIDFromItemInfo(item)
		if not itemID then
			return false
		end

		GetItemInfo(itemID)
		return C_Item.IsItemDataCachedByID(itemID)
	end

	function C_Item.IsLocked(itemLocation)
		return IsItemLocationLocked(itemLocation)
	end

	function C_Item.LockItem(itemLocation)
	end

	function C_Item.UnlockItem(itemLocation)
	end

	function C_Item.GetItemGem(item, index)
		if type(index) ~= "number" or index <= 0 then
			return nil, nil
		end

		local itemName;
		if type(item) == "table" and item.HasAnyLocation and item:HasAnyLocation() then
			item = GetItemLinkFromLocation(item)
		elseif type(item) ~= "string" then
			local itemID = GetItemIDFromItemInfo(item)
			if itemID then
				itemName, item = GetItemInfo(itemID);
				-- item = select(2, GetItemInfo(itemID))
			end
		end

		if not item then
			return nil, nil
		end

		return GetItemGem(item, index);
	end

	function C_Item.GetItemStats(item)
		return GetItemStats(item)
	end

	function C_Item.GetItemCooldown(item)
		return GetItemCooldown(item)
	end

	function C_Item.GetItemCount(item, includeBank, includeCharges)
		return GetItemCount(item, includeBank, includeCharges)
	end

	function C_Item.GetItemSpell(item)
		return GetItemSpell(item)
	end

	function C_Item.GetItemFamily(item)
		return GetItemFamily(item)
	end

	function C_Item.GetItemStatDelta(itemLink1, itemLink2)
		return GetItemStatDelta(itemLink1, itemLink2)
	end

	function C_Item.GetItemUniqueness(item)
		return GetItemUniqueness(item)
	end

	function C_Item.IsConsumableItem(item)
		return IsConsumableItem(item)
	end

	function C_Item.IsCurrentItem(item)
		return IsCurrentItem(item)
	end

	function C_Item.IsDressableItem(item)
		return IsDressableItem(item)
	end

	function C_Item.IsEquippableItem(item)
		return IsEquippableItem(item)
	end

	function C_Item.IsEquippedItem(item)
		return IsEquippedItem(item)
	end

	function C_Item.IsEquippedItemType(itemType)
		return IsEquippedItemType(itemType)
	end

	function C_Item.IsHarmfulItem(item)
		return IsHarmfulItem(item)
	end

	function C_Item.IsHelpfulItem(item)
		return IsHelpfulItem(item)
	end

	function C_Item.IsItemInRange(item, unit)
		return IsItemInRange(item, unit)
	end

	function C_Item.IsUsableItem(item)
		return IsUsableItem(item)
	end

	function C_Item.ItemHasRange(item)
		return ItemHasRange(item)
	end

	return C_Item;
end, { trustNative = true });
