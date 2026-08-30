--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local tonumber = tonumber;
local tconcat = table.concat;
local type = type;
local unpack = unpack;

local VERSION = 1;

local LinkTypes = {
	Item = "item",
	Spell = "spell",
	Unit = "unit",
};

local function EnsureField(fields, index)
	while #fields < index do
		fields[#fields + 1] = "";
	end
end

Aegis:RegisterNamespace("LinkUtil", VERSION, function(core, _, namespace)
	local Enum = core:GetNamespace("Enum");
	local LinkUtil = namespace or {};

	LinkUtil.LinkTypes = LinkUtil.LinkTypes or LinkTypes;

	function LinkUtil.FormatLink(linkType, linkDisplayText, ...)
		local linkFormatTable = { ("|H%s"):format(linkType), ... };
		local returnLink = tconcat(linkFormatTable, ":");
		if linkDisplayText then
			return returnLink .. ("|h%s|h"):format(linkDisplayText);
		end

		return returnLink .. "|h";
	end

	function LinkUtil.SplitLinkData(linkData)
		if type(linkData) ~= "string" then
			return nil, "";
		end

		local linkType, linkOptions = linkData:match("^([^:]+):?(.*)$");
		return linkType, linkOptions or "";
	end

	function LinkUtil.SplitLink(link)
		if type(link) ~= "string" then
			return nil, nil;
		end

		return link:match("^|H(.+)|h(.*)|h$");
	end

	function LinkUtil.SplitLinkOptions(linkOptions)
		if type(linkOptions) ~= "string" or linkOptions == "" then
			return nil;
		end

		local fields = {};
		local startIndex = 1;

		while true do
			local colonIndex = linkOptions:find(":", startIndex, true);
			if not colonIndex then
				fields[#fields + 1] = linkOptions:sub(startIndex);
				break;
			end

			fields[#fields + 1] = linkOptions:sub(startIndex, colonIndex - 1);
			startIndex = colonIndex + 1;
		end

		return unpack(fields);
	end

	function LinkUtil.ExtractLink(text)
		if type(text) ~= "string" then
			return nil, nil, nil;
		end

		return text:match("|H([^:]*):([^|]*)|h(.*)|h");
	end

	function LinkUtil.IsLinkType(link, matchLinkType)
		local linkType = LinkUtil.ExtractLink(link);
		return linkType == matchLinkType;
	end

	function LinkUtil.GetLinkType(link)
		local linkType = LinkUtil.ExtractLink(link);
		if linkType then
			return linkType;
		end

		if type(link) ~= "string" then
			return nil;
		end

		return link:match("^([^:]+):");
	end

	function LinkUtil.GetTooltipDataType(link)
		local linkType = LinkUtil.GetLinkType(link);
		if linkType == LinkTypes.Item then
			return Enum.TooltipDataType.Item;
		end

		if linkType == LinkTypes.Spell then
			return Enum.TooltipDataType.Spell;
		end

		if linkType == LinkTypes.Unit then
			return Enum.TooltipDataType.Unit;
		end

		return nil;
	end

	function LinkUtil.GetItemStringFromLink(itemLink)
		if not itemLink then
			return nil;
		end

		local itemString = itemLink:match("|H(item:[^|]+)|h");
		if itemString then
			return itemString;
		end

		return itemLink:match("^(item:[^|]+)");
	end

	function LinkUtil.ParseItemString(itemLink)
		local itemString = LinkUtil.GetItemStringFromLink(itemLink);
		if not itemString then
			return nil;
		end

		local fields = {};
		local startIndex = 1;

		while true do
			local colonIndex = itemString:find(":", startIndex, true);
			if not colonIndex then
				fields[#fields + 1] = itemString:sub(startIndex);
				break;
			end

			fields[#fields + 1] = itemString:sub(startIndex, colonIndex - 1);
			startIndex = colonIndex + 1;
		end

		if fields[1] ~= LinkTypes.Item then
			return nil;
		end

		return fields;
	end

	function LinkUtil.BuildItemString(fields)
		return tconcat(fields, ":");
	end

	function LinkUtil.GetItemIDFromLink(itemLink)
		if not itemLink then
			return 0;
		end

		return tonumber(itemLink:match("item:(%-?%d+)")) or 0;
	end

	function LinkUtil.GetSpellIDFromLink(link)
		if not link then
			return 0;
		end

		local spellID = tonumber(link:match("|Hspell:(%d+)")) or tonumber(link:match("^spell:(%d+)"));
		return spellID or 0;
	end

	function LinkUtil.GetTooltipDataID(link, tooltipDataType)
		if tooltipDataType == Enum.TooltipDataType.Item then
			return LinkUtil.GetItemIDFromLink(link);
		end

		if tooltipDataType == Enum.TooltipDataType.Spell then
			return LinkUtil.GetSpellIDFromLink(link);
		end

		return 0;
	end

	function LinkUtil.GetEnchantIDFromLink(itemLink)
		if not itemLink then
			return 0;
		end

		local enchantID = tonumber(itemLink:match("item:[-%d]+:([-%d]+)"));
		if enchantID and enchantID > 0 then
			return enchantID;
		end

		return 0;
	end

	function LinkUtil.RemoveEnchantFromLink(itemLink)
		local fields = LinkUtil.ParseItemString(itemLink);
		if not fields then
			return nil;
		end

		EnsureField(fields, 3);
		fields[3] = "0";

		return LinkUtil.BuildItemString(fields);
	end

	function LinkUtil.RemoveGemsFromLink(itemLink)
		local fields = LinkUtil.ParseItemString(itemLink);
		if not fields then
			return nil;
		end

		for index = 4, 7 do
			EnsureField(fields, index);
			fields[index] = "0";
		end

		return LinkUtil.BuildItemString(fields);
	end

	function LinkUtil.GetSocketKey(itemLink)
		if not itemLink then
			return nil;
		end

		local itemKey = LinkUtil.RemoveGemsFromLink(itemLink);
		if itemKey then
			return itemKey;
		end

		return itemLink;
	end

	return LinkUtil;
end);
