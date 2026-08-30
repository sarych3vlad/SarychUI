--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local Aegis = Engine.Aegis;
local Constants = Engine.Shared.Constants;
local SharedData = Engine.Shared.Data;
local TextUtil = Engine.Shared.Utils.TextUtil;
local C_Item = Aegis:GetNamespace("C_Item");
local C_Spell = Aegis:GetNamespace("C_Spell");
local C_TooltipInfo = Aegis:GetNamespace("C_TooltipInfo");
local GlobalStrings = Aegis:GetNamespace("GlobalStrings");
local LinkUtil = Aegis:GetNamespace("LinkUtil");
local TooltipUtil = Aegis:GetNamespace("TooltipUtil");

--@natives<lua>
local strmatch = string.match;

--@imports<data>
local EnchantMetadataByID = SharedData.EnchantMetadataByID or {};

---------------------------------------------------------------------------------------------------
-- Enchant extraction for DataProviderMixin.
-- Owns enchant text resolution and spell or item display fallback.
---------------------------------------------------------------------------------------------------

local DataProviderMixin = Engine.Modules.DataProviderMixin;

local function CreateEnchantLineRule(globalStrings)
	local formatString = globalStrings:Get("ENCHANTED_TOOLTIP_LINE");
	if not formatString or formatString == "" then
		return nil;
	end

	local rule = TextUtil.EscapePattern(formatString);
	rule = rule:gsub("%%%%s", "(.+)");
	rule = "^" .. rule .. "$";
	return rule;
end


function DataProviderMixin:InitEnchantData()
	self.enchantLineRule = CreateEnchantLineRule(GlobalStrings);
end

do
	-- Prefer the explicit enchant line from the equipped tooltip.
	-- If that fails, diff enchanted and unenchanted tooltip text.
	local function GetNormalizedLeftText(lineData)
		return TextUtil.NormalizeTooltipText(lineData.leftText);
	end

	local function ExtractEnchantText(tooltipData, enchantLineRule)
		if not enchantLineRule then
			return nil;
		end

		local enchantText;
		TooltipUtil.FindFirstLine(tooltipData, function(lineData)
			local leftText = GetNormalizedLeftText(lineData);
			if leftText then
				enchantText = strmatch(leftText, enchantLineRule);
			end

			return enchantText ~= nil;
		end);

		return enchantText;
	end

	local function CountTooltipText(tooltipData)
		local counts = {};
		TooltipUtil.ForEachLine(tooltipData, function(lineData)
			local leftText = GetNormalizedLeftText(lineData);
			if leftText then
				counts[leftText] = (counts[leftText] or 0) + 1;
			end
		end);

		return counts;
	end

	local function FindUnmatchedTooltipText(tooltipData, baselineCounts)
		local unmatchedText;
		TooltipUtil.FindFirstLine(tooltipData, function(lineData)
			local leftText = GetNormalizedLeftText(lineData);

			if leftText then
				local count = baselineCounts[leftText];
				if count and count > 0 then
					baselineCounts[leftText] = count - 1;
					return false;
				end

				unmatchedText = leftText;
				return true;
			end
		end);

		return unmatchedText;
	end

	function DataProviderMixin:GetEnchantText(slotID, itemLink)
		local enchantID = LinkUtil.GetEnchantIDFromLink(itemLink);
		if enchantID <= 0 then
			return nil;
		end

		local cachedText = self.enchantTextByID[enchantID];
		if cachedText ~= nil then
			if cachedText == false then
				return nil;
			end

			return cachedText;
		end

		local resolvedTooltipData = self:GetResolvedTooltipData(slotID, itemLink);
		local enchantText = ExtractEnchantText(resolvedTooltipData, self.enchantLineRule);
		if enchantText then
			self.enchantTextByID[enchantID] = enchantText;
			return enchantText;
		end

		local unenchantedItemLink = LinkUtil.RemoveEnchantFromLink(itemLink);
		local enchantedTooltipData = C_TooltipInfo.GetHyperlink(itemLink);
		local unenchantedTooltipData;

		if unenchantedItemLink then
			unenchantedTooltipData = C_TooltipInfo.GetHyperlink(unenchantedItemLink);
		end

		if not enchantedTooltipData then
			self.enchantTextByID[enchantID] = false;
			return nil;
		end

		local baselineCounts = CountTooltipText(unenchantedTooltipData);
		enchantText = FindUnmatchedTooltipText(enchantedTooltipData, baselineCounts);

		if enchantText then
			self.enchantTextByID[enchantID] = enchantText;
			return enchantText;
		end

		self.enchantTextByID[enchantID] = false;
		return nil;
	end
end

do
	local function GetSpellDisplayInfo(spellID)
		if not spellID or spellID <= 0 then
			return nil, nil;
		end

		local spellInfo = C_Spell.GetSpellInfo(spellID);
		if spellInfo then
			return spellInfo.name, spellInfo.iconID or spellInfo.iconFileID or spellInfo.originalIconID;
		end

		return C_Spell.GetSpellName(spellID), C_Spell.GetSpellTexture(spellID);
	end

	local function GetPreferredEnchantItemID(enchantInfo)
		if not enchantInfo then
			return nil;
		end

		if enchantInfo.itemID and enchantInfo.itemID > 0 then
			return enchantInfo.itemID;
		end

		local itemIDs = enchantInfo.itemIDs;
		local itemID = itemIDs and itemIDs[1];
		if itemID and itemID > 0 then
			return itemID;
		end

		return nil;
	end

	function DataProviderMixin:GetEnchantData(slotID, itemLink)
		if not itemLink then
			return nil;
		end

		local enchantID = LinkUtil.GetEnchantIDFromLink(itemLink);
		if enchantID <= 0 then
			return nil;
		end

		local enchantInfo = EnchantMetadataByID[enchantID];
		local enchantText = self:GetEnchantText(slotID, itemLink);

		local itemID = GetPreferredEnchantItemID(enchantInfo);
		local itemIDs = enchantInfo and enchantInfo.itemIDs;
		local spellID = enchantInfo and enchantInfo.spellID;

		local itemIcon;
		local itemName;
		if itemID then
			itemIcon = C_Item.GetItemIconByID(itemID);
			itemName = C_Item.GetItemNameByID(itemID);
		end

		local spellName, spellIcon = GetSpellDisplayInfo(spellID);

		local text = spellName or enchantText or itemName;
		local fullText = enchantText or text;
		local icon = itemIcon or spellIcon or Constants.ENCHANT_FALLBACK_TEXTURE;

		return {
			id = enchantID,
			text = text,
			fullText = fullText,
			icon = icon,
			spellID = spellID,
			itemID = itemID,
			itemIDs = itemIDs,
		};
	end
end
