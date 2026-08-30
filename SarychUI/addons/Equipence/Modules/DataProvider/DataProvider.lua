--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local Aegis = Engine.Aegis;
local Item = Aegis:GetNamespace("Item");
local ItemLocation = Aegis:GetNamespace("ItemLocation");
local C_Item = Aegis:GetNamespace("C_Item");
local LinkUtil = Aegis:GetNamespace("LinkUtil");

--@natives<wow>
local GetItemInfo = GetItemInfo;
local GetInventoryItemID = GetInventoryItemID;
local GetInventoryItemLink = GetInventoryItemLink;

---------------------------------------------------------------------------------------------------
-- DataProviderMixin builds resolved slot data for the controller and feature modules.
-- Socket and enchant extraction are split into companion files.
---------------------------------------------------------------------------------------------------

-- DataProviderMixin<driving>
local DataProviderMixin = {};
Engine.Modules.DataProviderMixin = DataProviderMixin;

function DataProviderMixin:OnLoad()
	self.unit = self.unit or "player";

	self.enchantTextByID = {};
	self.gemColorMaskByID = {};

	self:InitSocketData();
	self:InitEnchantData();
end

function DataProviderMixin:SetUnit(unit)
	self.unit = unit or "player";
end

function DataProviderMixin:GetUnit()
	return self.unit or "player";
end

function DataProviderMixin:GetCurrentItemID(slotID)
	local itemID = GetInventoryItemID(self:GetUnit(), slotID);
	if itemID and itemID > 0 then
		return itemID;
	end

	local itemLink = self:GetCurrentItemLink(slotID);
	return LinkUtil.GetItemIDFromLink(itemLink);
end

function DataProviderMixin:GetCurrentItemLink(slotID)
	return GetInventoryItemLink(self:GetUnit(), slotID);
end

function DataProviderMixin:GetCurrentItemToken(slotID)
	local itemLink = self:GetCurrentItemLink(slotID);
	return LinkUtil.GetItemStringFromLink(itemLink);
end

function DataProviderMixin:GetItemQuality(item, itemLink)
	if item and item.GetItemQuality then
		local quality = item:GetItemQuality();
		if quality ~= nil then
			return quality;
		end
	end

	local itemID;
	if item and item.GetItemID then
		itemID = item:GetItemID();
	else
		itemID = LinkUtil.GetItemIDFromLink(itemLink);
	end

	if itemID and itemID > 0 and C_Item.GetItemQualityByID then
		local quality = C_Item.GetItemQualityByID(itemID);
		if quality ~= nil then
			return quality;
		end
	end

	local _, _, quality = GetItemInfo(itemLink);
	return quality;
end

function DataProviderMixin:CreateSlotItem(slotID)
	local unit = self:GetUnit();

	if unit == "player" then
		local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID);
		if itemLocation and C_Item.DoesItemExist(itemLocation) then
			local item = Item:CreateFromItemLocation(itemLocation);
			local itemLink = self:GetCurrentItemLink(slotID);
			return item, itemLink;
		end
	end

	local itemLink = self:GetCurrentItemLink(slotID);
	if itemLink then
		local item = Item:CreateFromItemLink(itemLink);
		return item, itemLink;
	end

	return nil, nil;
end

function DataProviderMixin:BuildSlotData(slotID, item, itemLink, itemToken)
	local socketData = self:GetSocketData(slotID, itemLink);
	local enchantData = self:GetEnchantData(slotID, itemLink);

	return {
		slotID = slotID,
		inventorySlotID = slotID,
		item = item,
		itemID = item:GetItemID(),
		itemLink = itemLink,
		itemToken = itemToken,
		itemLevel = item:GetCurrentItemLevel(),
		itemQuality = self:GetItemQuality(item, itemLink),
		socketData = socketData,
		enchantData = enchantData,
	};
end

function DataProviderMixin:BuildSlotDataFromLink(slotID, item, itemLink, itemToken)
	local socketData = self:GetSocketData(nil, itemLink);
	local enchantData = self:GetEnchantData(nil, itemLink);

	return {
		slotID = slotID,
		item = item,
		itemID = item:GetItemID(),
		itemLink = itemLink,
		itemToken = itemToken,
		itemLevel = item:GetCurrentItemLevel(),
		itemQuality = self:GetItemQuality(item, itemLink),
		socketData = socketData,
		enchantData = enchantData,
	};
end

function DataProviderMixin:RequestSlotData(slotID, callback)
	if type(callback) ~= "function" then
		return;
	end

	local itemToken = self:GetCurrentItemToken(slotID);
	if not itemToken then
		callback(nil);
		return;
	end

	local item, itemLink = self:CreateSlotItem(slotID);
	if not item then
		callback(nil);
		return;
	end

	item:ContinueOnItemLoad(function()
		local resolvedItemLink = item:GetItemLink() or itemLink;
		if not resolvedItemLink then
			callback(nil);
			return;
		end

		local slotData = self:BuildSlotData(slotID, item, resolvedItemLink, itemToken);
		self:ContinueWithSocketGemData(slotData, callback);
	end);
end

function DataProviderMixin:RequestSlotDataFromLink(slotID, itemLink, itemToken, callback)
	if type(callback) ~= "function" or not itemLink then
		return;
	end

	local resolvedItemToken = itemToken or LinkUtil.GetItemStringFromLink(itemLink);
	local item = Item:CreateFromItemLink(itemLink);

	item:ContinueOnItemLoad(function()
		-- Snapshot links carry inspected gems/enchants; do not replace them with normalized item data.
		--
		local slotData = self:BuildSlotDataFromLink(slotID, item, itemLink, resolvedItemToken);
		self:ContinueWithSocketGemData(slotData, callback);
	end);
end
