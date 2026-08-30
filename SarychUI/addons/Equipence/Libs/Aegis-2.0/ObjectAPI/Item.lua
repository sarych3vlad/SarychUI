--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local _G = _G
local type = type
local tostring = tostring

local VERSION = 1

Aegis:RegisterNamespace("Item", VERSION, function(core, _, namespace)
	local native = _G.Item
	if native and _G.ItemMixin then
		return native
	end

	local C_Item = core:GetNamespace("C_Item")
	local ColorManager = core:GetNamespace("ColorManager")
	local ItemLocation = core:GetNamespace("ItemLocation")
	local ItemEventListener = core:GetService("ItemEventListener")

	local Item = namespace or {}
	local ItemMixin = Item.Mixin or {}
	Item.Mixin = ItemMixin

	local function SupportsItemGUID()
		return C_Item and C_Item.SupportsItemGUID == true
	end

	function Item:CreateFromItemLocation(itemLocation)
		if type(itemLocation) ~= "table" or type(itemLocation.HasAnyLocation) ~= "function" or not itemLocation:HasAnyLocation() then
			error("Usage: Item:CreateFromItemLocation(notEmptyItemLocation)", 2)
		end

		local item = core:CreateFromMixins(ItemMixin)
		item:SetItemLocation(itemLocation)
		return item
	end

	function Item:CreateFromBagAndSlot(bagID, slotIndex)
		if type(bagID) ~= "number" or type(slotIndex) ~= "number" then
			error("Usage: Item:CreateFromBagAndSlot(bagID, slotIndex)", 2)
		end

		local item = core:CreateFromMixins(ItemMixin)
		item:SetItemLocation(ItemLocation:CreateFromBagAndSlot(bagID, slotIndex))
		return item
	end

	function Item:CreateFromEquipmentSlot(equipmentSlotIndex)
		if type(equipmentSlotIndex) ~= "number" then
			error("Usage: Item:CreateFromEquipmentSlot(equipmentSlotIndex)", 2)
		end

		local item = core:CreateFromMixins(ItemMixin)
		item:SetItemLocation(ItemLocation:CreateFromEquipmentSlot(equipmentSlotIndex))
		return item
	end

	function Item:CreateFromItemLink(itemLink)
		if type(itemLink) ~= "string" then
			error("Usage: Item:CreateFromItemLink(itemLinkString)", 2)
		end

		local item = core:CreateFromMixins(ItemMixin)
		item:SetItemLink(itemLink)
		return item
	end

	function Item:CreateFromItemID(itemID)
		if type(itemID) ~= "number" then
			error("Usage: Item:CreateFromItemID(itemID)", 2)
		end

		local item = core:CreateFromMixins(ItemMixin)
		item:SetItemID(itemID)
		return item
	end

	function Item:CreateFromItemGUID(itemGUID)
		if type(itemGUID) ~= "string" then
			error("Usage: Item:CreateFromItemGUID(itemGUIDString)", 2)
		end

		if not SupportsItemGUID() then
			error("Usage: Item:CreateFromItemGUID(itemGUIDString): unsupported on this client", 2)
		end

		local item = core:CreateFromMixins(ItemMixin)
		item:SetItemGUID(itemGUID)
		return item
	end

	function Item:DoItemsMatch(item1, item2)
		if not item1 or not item2 then
			return false
		end

		return item1:Matches(item2)
	end

	function ItemMixin:Matches(item)
		if not item then
			return false
		end

		local itemID = item:GetItemID()
		if itemID ~= nil and self:GetItemID() == itemID then
			return true
		end

		local itemLocation = item:GetItemLocation()
		local selfLocation = self:GetItemLocation()
		if itemLocation ~= nil and selfLocation ~= nil and itemLocation:IsEqualTo(selfLocation) then
			return true
		end

		return false
	end

	function ItemMixin:SetItemLocation(itemLocation)
		self:Clear()
		self.itemLocation = itemLocation
	end

	function ItemMixin:SetItemLink(itemLink)
		self:Clear()
		self.itemLink = itemLink
	end

	function ItemMixin:SetItemID(itemID)
		self:Clear()
		self.itemID = itemID
	end

	function ItemMixin:SetItemGUID(itemGUID)
		self:Clear()
		self.itemGUID = itemGUID
	end

	function ItemMixin:GetItemLocation()
		if self.itemLocation then
			return self.itemLocation
		end

		if self.itemGUID and SupportsItemGUID() then
			return C_Item.GetItemLocation(self.itemGUID)
		end

		return nil
	end

	function ItemMixin:GetItemGUID()
		if self.itemGUID then
			return self.itemGUID
		end

		if self.itemLocation and SupportsItemGUID() then
			return C_Item.GetItemGUID(self.itemLocation)
		end

		return nil
	end

	function ItemMixin:HasItemLocation()
		return self.itemLocation ~= nil
	end

	function ItemMixin:Clear()
		self.itemLocation = nil
		self.itemLink = nil
		self.itemID = nil
		self.itemGUID = nil
	end

	function ItemMixin:GetStaticBackingItem()
		return self.itemLink or self.itemID
	end

	function ItemMixin:IsItemInPlayersControl()
		local itemLocation = self:GetItemLocation()
		return itemLocation and C_Item.DoesItemExist(itemLocation)
	end

	function ItemMixin:IsItemEmpty()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return not C_Item.DoesItemExistByID(backingItem)
		end

		return not self:IsItemInPlayersControl()
	end

	function ItemMixin:GetItemID()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			local itemID = C_Item.GetItemInfoInstant(backingItem)
			if itemID then
				return itemID
			end
			return C_Item.GetItemIDForItemInfo(backingItem)
		end

		if not self:IsItemEmpty() then
			return C_Item.GetItemID(self:GetItemLocation())
		end

		return nil
	end

	function ItemMixin:IsItemLocked()
		return self:IsItemInPlayersControl() and C_Item.IsLocked(self:GetItemLocation())
	end

	function ItemMixin:LockItem()
		if self:IsItemInPlayersControl() then
			C_Item.LockItem(self:GetItemLocation())
		end
	end

	function ItemMixin:UnlockItem()
		if self:IsItemInPlayersControl() then
			C_Item.UnlockItem(self:GetItemLocation())
		end
	end

	function ItemMixin:GetItemIcon()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return C_Item.GetItemIconByID(backingItem)
		end

		if not self:IsItemEmpty() then
			return C_Item.GetItemIcon(self:GetItemLocation())
		end
	end

	function ItemMixin:GetItemName()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return C_Item.GetItemNameByID(backingItem)
		end

		if not self:IsItemEmpty() then
			return C_Item.GetItemName(self:GetItemLocation())
		end

		return nil
	end

	function ItemMixin:GetItemLink()
		if self.itemLink then
			return self.itemLink
		end

		if self.itemID then
			local _, itemLink = C_Item.GetItemInfo(self.itemID);
			return itemLink;
		end

		if not self:IsItemEmpty() then
			return C_Item.GetItemLink(self:GetItemLocation())
		end

		return nil
	end

	function ItemMixin:GetItemQuality()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return C_Item.GetItemQualityByID(backingItem)
		end

		if not self:IsItemEmpty() then
			return C_Item.GetItemQuality(self:GetItemLocation())
		end

		return nil
	end

	function ItemMixin:GetStackCount()
		if not self:IsItemEmpty() then
			return C_Item.GetStackCount(self:GetItemLocation())
		end

		return nil
	end

	function ItemMixin:GetCurrentItemLevel()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return C_Item.GetDetailedItemLevelInfo(backingItem)
		end

		if not self:IsItemEmpty() then
			return C_Item.GetCurrentItemLevel(self:GetItemLocation())
		end

		return nil
	end

	function ItemMixin:GetItemQualityColor()
		local itemQuality = self:GetItemQuality()
		return ColorManager.GetColorDataForItemQuality(itemQuality)
	end

	function ItemMixin:GetItemQualityColorRGB()
		local colorTable = self:GetItemQualityColor()
		if colorTable and colorTable.color then
			return colorTable.color:GetRGB()
		end
		return nil
	end

	function ItemMixin:GetItemMaxStackSize()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return C_Item.GetItemMaxStackSizeByID(backingItem)
		end

		if not self:IsItemEmpty() then
			return C_Item.GetItemMaxStackSize(self:GetItemLocation())
		end

		return nil
	end

	function ItemMixin:IsStackable()
		local maxStackSize = self:GetItemMaxStackSize()
		return maxStackSize and maxStackSize > 1
	end

	function ItemMixin:GetInventoryType()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return C_Item.GetItemInventoryTypeByID(backingItem)
		end

		if not self:IsItemEmpty() then
			return C_Item.GetItemInventoryType(self:GetItemLocation())
		end

		return nil
	end

	function ItemMixin:GetInventoryTypeName()
		if not self:IsItemEmpty() then
			return select(4, C_Item.GetItemInfoInstant(self:GetItemID()))
		end
	end

	function ItemMixin:IsItemDataCached()
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return C_Item.IsItemDataCachedByID(backingItem)
		end

		if not self:IsItemEmpty() then
			return C_Item.IsItemDataCached(self:GetItemLocation())
		end

		return true
	end

	function ItemMixin:IsDataEvictable()
		return true
	end

	function ItemMixin:GetItemGem(index)
		local backingItem = self:GetStaticBackingItem()
		if backingItem then
			return C_Item.GetItemGem(backingItem, index)
		end

		if not self:IsItemEmpty() then
			return C_Item.GetItemGem(self:GetItemLocation(), index)
		end

		return nil, nil
	end

	function ItemMixin:ValidateForContinueOnItemLoad(methodName, callbackFunction)
		if type(callbackFunction) ~= "function" then
			error(("Usage: NonEmptyItem:%s(callbackFunction): invalid callbackFunction"):format(methodName), 3)
		end

		if self:IsItemEmpty() then
			if self.itemLink then
				error(("Usage: NonEmptyItem:%s(callbackFunction) invalid itemLink: <%s>"):format(methodName, self.itemLink), 3)
			elseif self.itemID then
				error(("Usage: NonEmptyItem:%s(callbackFunction) invalid itemID: <%d>"):format(methodName, self.itemID), 3)
			end

			error(("Usage: NonEmptyItem:%s(callbackFunction): invalid item"):format(methodName), 3)
		elseif not self:GetItemID() then
			error(("Usage: NonEmptyItem:%s(callbackFunction): item appeared non-empty, but had invalid itemID. itemID: <%s>, itemLink: <%s>"):format(methodName, tostring(self.itemID), tostring(self.itemLink)), 3)
		end
	end

	function ItemMixin:ContinueOnItemLoad(callbackFunction)
		self:ValidateForContinueOnItemLoad("ContinueOnItemLoad", callbackFunction)
		ItemEventListener:AddCallback(self:GetItemID(), callbackFunction)
	end

	function ItemMixin:ContinueWithCancelOnItemLoad(callbackFunction)
		self:ValidateForContinueOnItemLoad("ContinueWithCancelOnItemLoad", callbackFunction)
		return ItemEventListener:AddCancelableCallback(self:GetItemID(), callbackFunction)
	end

	function ItemMixin:ContinueWithCancelOnRecordLoad(callbackFunction)
		return self:ContinueWithCancelOnItemLoad(callbackFunction)
	end

	function ItemMixin:IsRecordDataCached()
		return self:IsItemDataCached()
	end

	return Item
end)