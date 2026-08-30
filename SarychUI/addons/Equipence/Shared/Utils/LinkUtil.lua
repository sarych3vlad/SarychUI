--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@natives<lua>
local tonumber = tonumber;
local tconcat = table.concat;

-- LinkUtil provides item link parsing and rewriting helpers used by item data extraction.
--

local LinkUtil = {};

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

-- Item strings are positional. Preserve empty fields when rewriting enchant or gem slots.
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

	if fields[1] ~= "item" then
		return nil;
	end

	return fields;
end


local function EnsureField(fields, index)
	while #fields < index do
		fields[#fields + 1] = "";
	end
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

Engine.Shared.Utils.LinkUtil = LinkUtil;