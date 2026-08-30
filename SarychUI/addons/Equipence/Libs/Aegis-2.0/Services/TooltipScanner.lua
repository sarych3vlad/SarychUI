--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local CreateFrame = CreateFrame;
local UIParent = UIParent;
local GetInventoryItemLink = GetInventoryItemLink;
local _G = _G;

local VERSION = 3;

local Enum = Aegis:GetNamespace("Enum");
local LinkUtil = Aegis:GetNamespace("LinkUtil");

local TooltipScannerMixin = {};

function TooltipScannerMixin:OnLoad()
	if self.scanTooltip then
		return;
	end

	local scanTooltip = CreateFrame("GameTooltip", "AegisTooltipScanner", nil, "GameTooltipTemplate");
	scanTooltip:SetOwner(UIParent, "ANCHOR_NONE");

	local queryTooltip = CreateFrame("GameTooltip", "AegisTooltipQuery", nil, "GameTooltipTemplate");
	queryTooltip:SetOwner(UIParent, "ANCHOR_NONE");

	self.scanTooltip = scanTooltip;
	self.queryTooltip = queryTooltip;

	self.scanTooltipName = scanTooltip:GetName();
end

function TooltipScannerMixin:Clear()
	self.scanTooltip:ClearLines();
end

function TooltipScannerMixin:BuildTooltipData(tooltip, tooltipName)
	local data = {
		lines = {}
	};

	-- Legacy fallback keeps line data minimal and only fills fields we can read
	-- directly from the hidden GameTooltip scan.
	for i = 1, tooltip:NumLines() do
		local left = _G[tooltipName .. "TextLeft" .. i];
		local right = _G[tooltipName .. "TextRight" .. i];

		local leftText = left and left:GetText() or nil;
		local rightText = right and right:GetText() or nil;

		local leftColor;
		if leftText and left.GetTextColor then
			local r, g, b = left:GetTextColor();
			leftColor = { r = r, g = g, b = b };
		end

		local rightColor;
		if rightText and right.GetTextColor then
			local r, g, b = right:GetTextColor();
			rightColor = { r = r, g = g, b = b };
		end

		if leftText or rightText then
			data.lines[#data.lines + 1] = {
				leftText = leftText,
				rightText = rightText,
				leftColor = leftColor,
				rightColor = rightColor,
			};
		end
	end

	return data;
end

function TooltipScannerMixin:GetInventoryItem(unit, slot)
	local hyperlink = GetInventoryItemLink(unit, slot);

	self.scanTooltip:ClearLines();
	self.scanTooltip:SetInventoryItem(unit, slot);

	local data = self:BuildTooltipData(self.scanTooltip, self.scanTooltipName);
	data.type = Enum.TooltipDataType.Item;
	data.hyperlink = hyperlink;
	data.id = LinkUtil.GetTooltipDataID(hyperlink, data.type);
	return data;
end

function TooltipScannerMixin:GetHyperlink(hyperlink)
	if not hyperlink or hyperlink == "" then
		return nil;
	end

	self.scanTooltip:ClearLines();
	self.scanTooltip:SetHyperlink(hyperlink);

	local data = self:BuildTooltipData(self.scanTooltip, self.scanTooltipName);
	data.type = LinkUtil.GetTooltipDataType(hyperlink);
	data.hyperlink = hyperlink;
	data.id = LinkUtil.GetTooltipDataID(hyperlink, data.type);
	return data;
end

function TooltipScannerMixin:RequestItemDataByID(itemID)
	if not itemID then
		return false;
	end

	self.queryTooltip:ClearLines();
	self.queryTooltip:SetHyperlink(("item:%d:0:0:0:0:0:0:0"):format(itemID));
	return true;
end

Aegis:RegisterService("TooltipScanner", VERSION, function(core, _, service)
	service = service or core:CreateFromMixins(TooltipScannerMixin);
	service:OnLoad();
	return service;
end);