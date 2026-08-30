--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local _G = _G
local VERSION = 1

Aegis:RegisterNamespace("ItemLocation", VERSION, function(core, _, namespace)
	local native = _G.ItemLocation
	if native and _G.ItemLocationMixin then
		return native
	end

	local C_Item = core:GetNamespace("C_Item")

	local ItemLocation = namespace or {}
	local ItemLocationMixin = ItemLocation.Mixin or {}
	ItemLocation.Mixin = ItemLocationMixin

	function ItemLocation:CreateEmpty()
		return core:CreateFromMixins(ItemLocationMixin)
	end

	function ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
		local itemLocation = self:CreateEmpty()
		itemLocation:SetBagAndSlot(bagID, slotIndex)
		return itemLocation
	end

	function ItemLocation:CreateFromEquipmentSlot(equipmentSlotIndex)
		local itemLocation = self:CreateEmpty()
		itemLocation:SetEquipmentSlot(equipmentSlotIndex)
		return itemLocation
	end

	function ItemLocation:CreateFromUnitEquipmentSlot(unitToken, equipmentSlotIndex)
		local itemLocation = self:CreateEmpty()
		itemLocation:SetUnitEquipmentSlot(unitToken, equipmentSlotIndex)
		return itemLocation
	end

	function ItemLocation:ApplyLocationToTooltip(itemLocation, tooltip)
		if itemLocation:IsEquipmentSlot() then
			tooltip:SetInventoryItem("player", itemLocation:GetEquipmentSlot())
		elseif itemLocation:IsBagAndSlot() then
			tooltip:SetBagItem(itemLocation:GetBagAndSlot())
		end
	end

	function ItemLocationMixin:Clear()
		self.bagID = nil
		self.slotIndex = nil
		self.equipmentSlotIndex = nil
	end

	function ItemLocationMixin:SetBagAndSlot(bagID, slotIndex)
		self:Clear()
		self.bagID = bagID
		self.slotIndex = slotIndex
	end

	function ItemLocationMixin:GetBagAndSlot()
		return self.bagID, self.slotIndex
	end

	function ItemLocationMixin:SetEquipmentSlot(equipmentSlotIndex)
		self:Clear()
		self.equipmentSlotIndex = equipmentSlotIndex
	end

	function ItemLocationMixin:SetUnitEquipmentSlot(unitToken, equipmentSlotIndex)
		self:Clear()
		self.unitToken = unitToken
		self.equipmentSlotIndex = equipmentSlotIndex
		self.locationType = "unitEquipment"
	end

	function ItemLocationMixin:GetEquipmentSlot()
		return self.equipmentSlotIndex
	end

	function ItemLocationMixin:GetUnitEquipmentSlot()
		return self.unitToken, self.equipmentSlotIndex
	end

	function ItemLocationMixin:IsEquipmentSlot()
		return self.equipmentSlotIndex ~= nil
	end
	
	function ItemLocationMixin:IsUnitEquipmentSlot()
		return self.locationType == "unitEquipment"
	end

	function ItemLocationMixin:IsBagAndSlot()
		return self.bagID ~= nil and self.slotIndex ~= nil
	end

	function ItemLocationMixin:HasAnyLocation()
		return self:IsEquipmentSlot() or self:IsBagAndSlot()
	end

	function ItemLocationMixin:IsValid()
		return C_Item.DoesItemExist(self)
	end

	function ItemLocationMixin:IsEqualToBagAndSlot(otherBagID, otherSlotIndex)
		local bagID, slotIndex = self:GetBagAndSlot()
		if bagID and slotIndex then
			return bagID == otherBagID and slotIndex == otherSlotIndex
		end
		return false
	end

	function ItemLocationMixin:IsEqualToEquipmentSlot(otherEquipmentSlotIndex)
		local equipmentSlotIndex = self:GetEquipmentSlot()
		if equipmentSlotIndex then
			return equipmentSlotIndex == otherEquipmentSlotIndex
		end
		return false
	end

	function ItemLocationMixin:IsEqualTo(otherItemLocation)
		if not otherItemLocation then
			return false
		end

		local bagID, slotIndex = self:GetBagAndSlot()
		if bagID and slotIndex then
			local otherBagID, otherSlotIndex = otherItemLocation:GetBagAndSlot()
			return bagID == otherBagID and slotIndex == otherSlotIndex
		end

		local equipmentSlotIndex = self:GetEquipmentSlot()
		if equipmentSlotIndex then
			local otherEquipmentSlotIndex = otherItemLocation:GetEquipmentSlot()
			return equipmentSlotIndex == otherEquipmentSlotIndex
		end

		return not otherItemLocation:HasAnyLocation()
	end

	return ItemLocation
end)