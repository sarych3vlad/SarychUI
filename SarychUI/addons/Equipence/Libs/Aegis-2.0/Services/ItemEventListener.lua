--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local GetItemInfo = GetItemInfo
local tonumber = tonumber
local type = type
local tostring = tostring

local VERSION = 3;
local CHANNEL_NAME = "ItemData";

local function NormalizeItemKey(item)
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

Aegis:RegisterService("ItemEventListener", VERSION, function(core, state, service)
	local loader = core:GetService("AsyncLoader")
	local environment = core:GetService("Environment")
	local scanner = environment:IsLegacyClient() and core:GetService("TooltipScanner") or nil
	local C_Item = core:GetNamespace("C_Item")

	service = service or {};

	loader:RegisterChannel(CHANNEL_NAME, {
		normalizeKey = NormalizeItemKey,

		isReady = function(itemID)
			return GetItemInfo(itemID) ~= nil;
		end,
		kick = function(itemID)
			-- Unified API path:
			-- on modern this will usually be native,
			-- on legacy this will be our shim.
			C_Item.RequestLoadItemDataByID(itemID);

			-- GetItemInfo(itemID);
			-- Extra legacy kick through hidden tooltip scan.
			if scanner then
				scanner:RequestItemDataByID(itemID)
			end
		end,
		events = {
			"ITEM_DATA_LOAD_RESULT",  -- modern
			"GET_ITEM_INFO_RECEIVED", -- semi-modern
			"BAG_UPDATE",
			"PLAYER_EQUIPMENT_CHANGED",
			"UNIT_INVENTORY_CHANGED",
		},
		eventFilter = function(event, ...)
			if event == "UNIT_INVENTORY_CHANGED" then
				local unit = ...;
				return unit == "player";
			end

			if event == "ITEM_DATA_LOAD_RESULT" then
				local itemID, success = ...;
				return success ~= false;
			end

			if event == "GET_ITEM_INFO_RECEIVED" then
				local itemID, success = ...;
				return success ~= false;
			end

			return true;
		end,

		timeout = 12.0,
		requeryInterval = 1.0,

		onExpire = function(itemID)
			Aegis:Debug("ItemEventListener timeout: itemID=%s", tostring(itemID));
		end,
	});

	function service:AddCallback(itemID, callbackFunction)
		return loader:AddCallback(CHANNEL_NAME, itemID, callbackFunction);
	end

	function service:AddCancelableCallback(itemID, callbackFunction)
		return loader:AddCancelableCallback(CHANNEL_NAME, itemID, callbackFunction);
	end

	return service;
end);