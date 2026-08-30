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
local TextUtil = Engine.Shared.Utils.TextUtil;
local Enum = Aegis:GetNamespace("Enum");
local GlobalStrings = Aegis:GetNamespace("GlobalStrings");
local C_Item = Aegis:GetNamespace("C_Item");
local C_TooltipInfo = Aegis:GetNamespace("C_TooltipInfo");
local Item = Aegis:GetNamespace("Item");
local FlagsUtil = Aegis:GetNamespace("FlagsUtil");
local LinkUtil = Aegis:GetNamespace("LinkUtil");
local TooltipUtil = Aegis:GetNamespace("TooltipUtil");

--@natives<lua,wow>
local pairs = pairs;
local tostring = tostring;
local tconcat = table.concat;
local strupper = string.upper;
local GetItemInfo = GetItemInfo;

--@internal
local DebugSockets = false;

---------------------------------------------------------------------------------------------------
-- Socket extraction and gem hydration for DataProviderMixin.
-- Owns fresh tooltip socket resolution and gem matching.
---------------------------------------------------------------------------------------------------

local DataProviderMixin = Engine.Modules.DataProviderMixin;
local ItemSocketType = Enum.ItemSocketType;
local ItemGemColor = Enum.ItemGemColor;

local SocketType = {
	META = "META",
	RED = "RED",
	YELLOW = "YELLOW",
	BLUE = "BLUE",
	PRISMATIC = "PRISMATIC",
	NO_COLOR = "NO_COLOR",
};

local MatchSource = {
	EXACT = "EXACT",
	BONUS = "BONUS",
};

local UNIVERSAL_GEM_SOCKET_TYPES = {
	[SocketType.PRISMATIC] = true,
};

local SOCKET_TYPE_RULES = {
	{ enumName = "Meta",            colorMask = ItemGemColor.Meta },
	{ enumName = "Red",             colorMask = ItemGemColor.Red },
	{ enumName = "Yellow",          colorMask = ItemGemColor.Yellow },
	{ enumName = "Blue",            colorMask = ItemGemColor.Blue },
	{ enumName = "Prismatic" },
	{ enumName = "Hydraulic",       colorMask = ItemGemColor.Hydraulic },
	{ enumName = "Cogwheel",        colorMask = ItemGemColor.Cogwheel },
	{ enumName = "Iron",            colorMask = ItemGemColor.Iron },
	{ enumName = "Blood",           colorMask = ItemGemColor.Blood },
	{ enumName = "Shadow",          colorMask = ItemGemColor.Shadow },
	{ enumName = "Fel",             colorMask = ItemGemColor.Fel },
	{ enumName = "Arcane",          colorMask = ItemGemColor.Arcane },
	{ enumName = "Frost",           colorMask = ItemGemColor.Frost },
	{ enumName = "Fire",            colorMask = ItemGemColor.Fire },
	{ enumName = "Water",           colorMask = ItemGemColor.Water },
	{ enumName = "Life",            colorMask = ItemGemColor.Life },
	{ enumName = "Wind",            colorMask = ItemGemColor.Wind },
	{ enumName = "Holy",            colorMask = ItemGemColor.Holy },
	{ enumName = "PunchcardRed",    colorMask = ItemGemColor.PunchcardRed },
	{ enumName = "PunchcardYellow", colorMask = ItemGemColor.PunchcardYellow },
	{ enumName = "PunchcardBlue",   colorMask = ItemGemColor.PunchcardBlue },
	{ enumName = "Domination",      colorMask = FlagsUtil.CreateMask(ItemGemColor.DominationBlood, ItemGemColor.DominationFrost, ItemGemColor.DominationUnholy) },
	{ enumName = "Cypher",          colorMask = ItemGemColor.Cypher },
	{ enumName = "Tinker",          colorMask = ItemGemColor.Tinker },
	{ enumName = "Primordial",      colorMask = ItemGemColor.Primordial },
	{ enumName = "Fragrance",       colorMask = ItemGemColor.Fragrance },
	{ enumName = "SingingThunder",  colorMask = ItemGemColor.SingingThunder },
	{ enumName = "SingingSea",      colorMask = ItemGemColor.SingingSea },
	{ enumName = "SingingWind",     colorMask = ItemGemColor.SingingWind },
	{ enumName = "Fiber",           colorMask = ItemGemColor.Fiber },
};

local SOCKET_COLOR_ORDER = {};
local SOCKET_COLOR_MASK = {};
local SOCKET_TYPE_BY_ENUM = {};
local SOCKET_TYPE_BY_TOKEN = {
	[SocketType.NO_COLOR] = SocketType.PRISMATIC,
	[SocketType.PRISMATIC] = SocketType.PRISMATIC,
};

for index = 1, #SOCKET_TYPE_RULES do
	local rule = SOCKET_TYPE_RULES[index];
	local socketType = strupper(rule.enumName);

	SOCKET_TYPE_BY_ENUM[ItemSocketType[rule.enumName]] = socketType;
	SOCKET_TYPE_BY_TOKEN[socketType] = socketType;

	if rule.colorMask then
		SOCKET_COLOR_ORDER[#SOCKET_COLOR_ORDER + 1] = socketType;
		SOCKET_COLOR_MASK[socketType] = rule.colorMask;
	end
end

local EXCLUSIVE_GEM_SUBTYPE_RULES = {
	{ token = "meta", colorMask = ItemGemColor.Meta },
	{ token = "prismatic", matchesAnySocket = true },
};

-- Classic/Wrath coverage stays explicit here; expanding to more retail socket
-- families is now a data addition rather than more branching.
local ADDITIVE_GEM_SUBTYPE_RULES = {
	{ token = "red",    colorMask = ItemGemColor.Red },
	{ token = "blue",   colorMask = ItemGemColor.Blue },
	{ token = "yellow", colorMask = ItemGemColor.Yellow },
	{ token = "orange", colorMask = FlagsUtil.CreateMask(ItemGemColor.Red, ItemGemColor.Yellow) },
	{ token = "purple", colorMask = FlagsUtil.CreateMask(ItemGemColor.Red, ItemGemColor.Blue) },
	{ token = "green",  colorMask = FlagsUtil.CreateMask(ItemGemColor.Blue, ItemGemColor.Yellow) },
};

local function DebugSocket(msg, ...)
	if not DebugSockets then
		return;
	end

	Engine:DebugLog("[Sockets] " .. msg, ...);
end

local function FormatGemColorMask(mask)
	if not mask or mask == 0 then
		return "nil";
	end

	local parts = {};

	for index = 1, #SOCKET_COLOR_ORDER do
		local socketType = SOCKET_COLOR_ORDER[index];
		local flag = SOCKET_COLOR_MASK[socketType];
		if FlagsUtil.IsAnySet(mask, flag) then
			parts[#parts + 1] = socketType;
		end
	end

	if #parts == 0 then
		return "{}";
	end

	return tconcat(parts, "|");
end

local TooltipRules = {};
local SocketUtil = {};
local GemUtil = {};
local ExtractSocketData;
local ResolveGemColorInfoFromTooltip;

do
	local SOCKET_TOOLTIP_RULES = {
		{ key = "EMPTY_SOCKET_META",      socketType = SocketType.META },
		{ key = "EMPTY_SOCKET_RED",       socketType = SocketType.RED },
		{ key = "EMPTY_SOCKET_BLUE",      socketType = SocketType.BLUE },
		{ key = "EMPTY_SOCKET_YELLOW",    socketType = SocketType.YELLOW },
		{ key = "EMPTY_SOCKET_PRISMATIC", socketType = SocketType.PRISMATIC },
		{ key = "EMPTY_SOCKET_NO_COLOR",  socketType = SocketType.PRISMATIC },
	};

	function TooltipRules.CreateSocketLineRules(globalStrings)
		local rules = {};
		local seenTexts = {};

		for index = 1, #SOCKET_TOOLTIP_RULES do
			local entry = SOCKET_TOOLTIP_RULES[index];
			local socketText = globalStrings:Get(entry.key);
			socketText = TextUtil.NormalizeTooltipText(socketText);

			if socketText and not seenTexts[socketText] then
				seenTexts[socketText] = true;
				rules[#rules + 1] = {
					matcher = "^" .. TextUtil.EscapePattern(socketText) .. "$",
					socketType = entry.socketType,
				};
			end
		end

		return rules;
	end

	-- Gem tooltip lines usually embed the localized socket text directly.
	function TooltipRules.CreateGemSocketRules(globalStrings)
		local rules = {};
		local seenTexts = {};

		for index = 1, #SOCKET_TOOLTIP_RULES do
			local entry = SOCKET_TOOLTIP_RULES[index];
			local socketText = globalStrings:Get(entry.key);
			socketText = TextUtil.NormalizeTooltipText(socketText);

			if socketText and not seenTexts[socketText] then
				seenTexts[socketText] = true;
				rules[#rules + 1] = {
					text = socketText,
					socketType = entry.socketType,
				};
			end
		end

		return rules;
	end
end

function TooltipRules.CreateSocketBonusLineRule(globalStrings)
	local formatString = globalStrings:Get("ITEM_SOCKET_BONUS");
	if not formatString or formatString == "" then
		formatString = "Socket Bonus: %s";
	end

	local rule = TextUtil.EscapePattern(formatString);
	rule = rule:gsub("%%%%s", "(.+)");
	rule = "^" .. rule .. "$";
	return rule;
end

function TooltipRules.NormalizeSocketType(socketType)
	if not socketType then
		return nil;
	end

	local socketTypeFromEnum = SOCKET_TYPE_BY_ENUM[socketType];
	if socketTypeFromEnum then
		return socketTypeFromEnum;
	end

	return SOCKET_TYPE_BY_TOKEN[strupper(tostring(socketType))];
end

function TooltipRules.GetSocketTypeFromLineData(lineData)
	return TooltipRules.NormalizeSocketType(lineData.socketType);
end

function TooltipRules.FindSocketType(lineText, socketRules)
	if not lineText then
		return nil;
	end

	for index = 1, #socketRules do
		local rule = socketRules[index];
		if lineText:match(rule.matcher) then
			return rule.socketType;
		end
	end

	return nil;
end

function TooltipRules.FindGemColorMask(lineText, gemSocketRules, colorMask)
	if not lineText then
		return colorMask;
	end

	local lowerLineText = lineText:lower();

	for index = 1, #gemSocketRules do
		local rule = gemSocketRules[index];
		if lowerLineText:find(rule.text:lower(), 1, true) then
			local flag = SOCKET_COLOR_MASK[rule.socketType];
			if flag then
				colorMask = FlagsUtil.Combine(colorMask, flag, true);
			end
		end
	end

	return colorMask;
end

function TooltipRules.HasUniversalGemSocketText(lineText, gemSocketRules)
	if not lineText then
		return false;
	end

	local lowerLineText = lineText:lower();

	for index = 1, #gemSocketRules do
		local rule = gemSocketRules[index];
		if rule.socketType == SocketType.PRISMATIC and lowerLineText:find(rule.text:lower(), 1, true) then
			return true;
		end
	end

	return false;
end

function TooltipRules.IsSocketBonusActive(lineData)
	local color = lineData.leftColor;
	if not color then
		return false;
	end

	return color.g > 0.75 and color.g >= color.r and color.g >= color.b;
end

function SocketUtil.GetSocketCount(itemLink)
	local stats = C_Item.GetItemStats(itemLink);
	if not stats then
		return 0;
	end

	local total = 0;
	for statName, statValue in pairs(stats) do
		if statName and statName:find("EMPTY_SOCKET", 1, true) then
			total = total + statValue;
		end
	end

	return total;
end

function SocketUtil.GetGemSlotCount(itemLink)
	local highestIndex = 0;

	for index = 1, Constants.MAX_SOCKETS do
		local _, gemLink = C_Item.GetItemGem(itemLink, index);
		if gemLink then
			highestIndex = index;
		end
	end

	return highestIndex;
end

function SocketUtil.AddSocket(layout, socketType)
	layout[#layout + 1] = {
		socketType = socketType,
	};
end

function SocketUtil.CopyLayout(layout)
	local copy = {};

	for index = 1, #layout do
		local entry = layout[index];
		copy[index] = {
			socketType = entry.socketType,
		};
	end

	return copy;
end

function SocketUtil.CopySocketData(socketData)
	return {
		layout = SocketUtil.CopyLayout(socketData.layout),
		bonusText = socketData.bonusText,
		bonusActive = socketData.bonusActive == true,
	};
end

function SocketUtil.MergeLayout(targetLayout, sourceLayout)
	for index = 1, #sourceLayout do
		local sourceEntry = sourceLayout[index];
		local targetEntry = targetLayout[index];

		if not targetEntry then
			targetLayout[index] = {
				socketType = sourceEntry.socketType,
			};
		elseif not targetEntry.socketType then
			targetEntry.socketType = sourceEntry.socketType;
		end
	end
end

function SocketUtil.CountTypes(layout)
	local counts = {};

	for index = 1, #layout do
		local entry = layout[index];
		local socketType = entry.socketType;
		if socketType then
			counts[socketType] = (counts[socketType] or 0) + 1;
		end
	end

	return counts;
end

-- Tooltip paths do not always agree on socket order.
-- Reconcile missing socket types after the positional merge.
function SocketUtil.AppendMissingTypes(targetLayout, sourceLayout)
	local targetCounts = SocketUtil.CountTypes(targetLayout);
	local sourceCounts = SocketUtil.CountTypes(sourceLayout);

	for index = 1, #sourceLayout do
		local sourceEntry = sourceLayout[index];
		local socketType = sourceEntry.socketType;
		if socketType then
			local targetCount = targetCounts[socketType] or 0;
			local sourceCount = sourceCounts[socketType] or 0;

			if targetCount < sourceCount then
				SocketUtil.AddSocket(targetLayout, socketType);
				targetCounts[socketType] = targetCount + 1;
			end
		end
	end
end

function SocketUtil.BuildSocketSignature(layout)
	if #layout == 0 then
		return "";
	end

	local parts = {};
	for index = 1, #layout do
		local entry = layout[index];
		if entry.socketType then
			parts[index] = entry.socketType;
		else
			parts[index] = "UNKNOWN";
		end
	end

	return tconcat(parts, ":");
end

function SocketUtil.BuildSocketTypesFromMask(colorMask, matchesAnySocket)
	if matchesAnySocket then
		return UNIVERSAL_GEM_SOCKET_TYPES;
	end

	if not colorMask or colorMask == 0 then
		return nil;
	end

	local socketTypes = {};

	for index = 1, #SOCKET_COLOR_ORDER do
		local socketType = SOCKET_COLOR_ORDER[index];
		local flag = SOCKET_COLOR_MASK[socketType];
		if FlagsUtil.IsAnySet(colorMask, flag) then
			socketTypes[socketType] = true;
		end
	end

	return socketTypes;
end

local function CreateGemColorInfo(colorMask, matchesAnySocket)
	if colorMask == nil and matchesAnySocket ~= true then
		return nil;
	end

	return {
		mask = colorMask,
		matchesAnySocket = matchesAnySocket == true,
	};
end

local function ResolveGemColorInfoFromItemInfo(gemLink)
	local _, _, _, _, _, itemType, itemSubType = GetItemInfo(gemLink);
	if itemType ~= "Gem" then
		return nil, itemType, itemSubType;
	end

	if not itemSubType then
		return nil, itemType, itemSubType;
	end

	local text = itemSubType:lower();
	local colorMask;

	for index = 1, #EXCLUSIVE_GEM_SUBTYPE_RULES do
		local rule = EXCLUSIVE_GEM_SUBTYPE_RULES[index];
		if text:find(rule.token, 1, true) then
			return CreateGemColorInfo(rule.colorMask, rule.matchesAnySocket), itemType, itemSubType;
		end
	end

	for index = 1, #ADDITIVE_GEM_SUBTYPE_RULES do
		local rule = ADDITIVE_GEM_SUBTYPE_RULES[index];
		if text:find(rule.token, 1, true) then
			colorMask = FlagsUtil.Combine(colorMask, rule.colorMask, true);
		end
	end

	return CreateGemColorInfo(colorMask, false), itemType, itemSubType;
end

do
	local function GetNormalizedLeftText(lineData)
		return TextUtil.NormalizeTooltipText(lineData.leftText);
	end

	local function ResolveSocketLine(provider, lineData)
		local socketType = TooltipRules.GetSocketTypeFromLineData(lineData);
		local leftText = GetNormalizedLeftText(lineData);

		if not socketType then
			socketType = provider:GetSocketTypeFromLine(leftText);
		end

		return socketType, leftText;
	end

	local function ApplySocketBonusFromLine(provider, socketData, lineData, leftText)
		local rule = provider.socketBonusLineRule;
		if not leftText or not rule then
			return;
		end

		local bonusText = leftText:match(rule);
		if not bonusText then
			return;
		end

		socketData.bonusText = bonusText;
		socketData.bonusActive = TooltipRules.IsSocketBonusActive(lineData);
	end

	local function ApplySocketTooltipLine(provider, socketData, lineData)
		local socketType, leftText = ResolveSocketLine(provider, lineData);
		if socketType then
			SocketUtil.AddSocket(socketData.layout, socketType);
			return;
		end

		ApplySocketBonusFromLine(provider, socketData, lineData, leftText);
	end

	ExtractSocketData = function(provider, tooltipData)
		local socketData = {
			layout = {},
			bonusActive = false,
		};

		local lines = TooltipUtil.GetLines(tooltipData);
		for index = 1, #lines do
			ApplySocketTooltipLine(provider, socketData, lines[index]);
		end

		return socketData;
	end

	local function ApplyGemColorFromSocketType(state, socketType)
		if socketType == SocketType.PRISMATIC then
			state.matchesAnySocket = true;
			return;
		end

		local flag = SOCKET_COLOR_MASK[socketType];
		if flag then
			state.colorMask = FlagsUtil.Combine(state.colorMask, flag, true);
		end
	end

	local function ApplyGemColorFromText(provider, state, leftText)
		if not leftText then
			return;
		end

		state.colorMask = TooltipRules.FindGemColorMask(leftText, provider.gemSocketRules, state.colorMask);
		if TooltipRules.HasUniversalGemSocketText(leftText, provider.gemSocketRules) then
			state.matchesAnySocket = true;
		end
	end

	local function ApplyGemTooltipLine(provider, state, lineData)
		local socketType = TooltipRules.GetSocketTypeFromLineData(lineData);
		if socketType then
			ApplyGemColorFromSocketType(state, socketType);
			return;
		end

		ApplyGemColorFromText(provider, state, GetNormalizedLeftText(lineData));
	end

	ResolveGemColorInfoFromTooltip = function(provider, tooltipData)
		local state = {
			matchesAnySocket = false,
		};

		local lines = TooltipUtil.GetLines(tooltipData);
		for index = 1, #lines do
			ApplyGemTooltipLine(provider, state, lines[index]);
		end

		return CreateGemColorInfo(state.colorMask, state.matchesAnySocket);
	end
end

function GemUtil.DoesGemMatchSocket(socketType, gemColorInfo)
	if not socketType or not gemColorInfo then
		return nil;
	end

	if gemColorInfo.matchesAnySocket then
		return socketType ~= SocketType.META;
	end

	local gemColorMask = gemColorInfo.mask;
	if not gemColorMask then
		return nil;
	end

	if FlagsUtil.IsSet(gemColorMask, SOCKET_COLOR_MASK.META) then
		return socketType == SocketType.META;
	end

	if socketType == SocketType.META then
		return false;
	end

	if socketType == SocketType.PRISMATIC then
		return true;
	end

	local socketColorMask = SOCKET_COLOR_MASK[socketType];
	if socketColorMask then
		return FlagsUtil.IsAnySet(gemColorMask, socketColorMask);
	end

	return nil;
end

local function SelectPrimarySocketData(gemlessData, resolvedData)
	if #gemlessData.layout >= #resolvedData.layout then
		return SocketUtil.CopySocketData(gemlessData), "gemless";
	end

	return SocketUtil.CopySocketData(resolvedData), "resolved";
end

local function GetExpectedSocketCount(itemLink)
	local expectedCount = SocketUtil.GetSocketCount(itemLink);
	local gemSlotCount = SocketUtil.GetGemSlotCount(itemLink);

	if gemSlotCount > expectedCount then
		expectedCount = gemSlotCount;
	end

	return expectedCount;
end


function DataProviderMixin:InitSocketData()
	self.socketLineRules = TooltipRules.CreateSocketLineRules(GlobalStrings);
	self.gemSocketRules = TooltipRules.CreateGemSocketRules(GlobalStrings);
	self.socketBonusLineRule = TooltipRules.CreateSocketBonusLineRule(GlobalStrings);
end

-- Prefer the live inventory tooltip when it carries equipped-only state.
function DataProviderMixin:GetResolvedTooltipData(inventorySlotID, itemLink)
	local unit = self:GetUnit();

	if inventorySlotID then
		local tooltipData = C_TooltipInfo.GetInventoryItem(unit, inventorySlotID);
		if TooltipUtil.GetLineCount(tooltipData) > 0 then
			return tooltipData;
		end
	end

	return C_TooltipInfo.GetHyperlink(itemLink);
end

function DataProviderMixin:GetGemSourceItemLink(inventorySlotID, itemLink)
	if not inventorySlotID then
		return itemLink;
	end

	local tooltipData = self:GetResolvedTooltipData(inventorySlotID, itemLink);
	local resolvedItemLink = tooltipData and tooltipData.hyperlink;
	if resolvedItemLink and resolvedItemLink ~= "" then
		return resolvedItemLink;
	end

	return itemLink;
end

function DataProviderMixin:GetSocketTypeFromLine(lineText)
	return TooltipRules.FindSocketType(lineText, self.socketLineRules);
end

function DataProviderMixin:GetCurrentSocketSignature(slotID)
	local itemLink = self:GetCurrentItemLink(slotID);
	if not itemLink then
		return nil;
	end

	return self:GetSocketData(slotID, itemLink).signature;
end

function DataProviderMixin:ResolveGemColorInfo(gemLink)
	local itemID = LinkUtil.GetItemIDFromLink(gemLink);

	if itemID > 0 then
		local cachedInfo = self.gemColorMaskByID[itemID];
		if cachedInfo ~= nil then
			if cachedInfo == false then
				return nil;
			end

			return cachedInfo;
		end
	end

	local colorInfo = ResolveGemColorInfoFromItemInfo(gemLink);
	if colorInfo then
		if itemID > 0 then
			self.gemColorMaskByID[itemID] = colorInfo;
		end

		return colorInfo;
	end

	local tooltipData = C_TooltipInfo.GetHyperlink(gemLink);
	local fallbackInfo = ResolveGemColorInfoFromTooltip(self, tooltipData);

	if itemID > 0 then
		self.gemColorMaskByID[itemID] = fallbackInfo or false;
	end

	if not fallbackInfo then
		DebugSocket("gem color info unresolved itemID=%s gemLink='%s'", tostring(itemID), tostring(gemLink));
	end

	return fallbackInfo;
end

-- Build fresh socket data every time; tooltip identity changes are cheaper than stale socket state.
function DataProviderMixin:GetSocketData(inventorySlotID, itemLink)
	local gemlessItemLink = LinkUtil.RemoveGemsFromLink(itemLink);
	if not gemlessItemLink then
		gemlessItemLink = itemLink;
	end

	local gemlessData = ExtractSocketData(self, C_TooltipInfo.GetHyperlink(gemlessItemLink));
	local resolvedData = ExtractSocketData(self, self:GetResolvedTooltipData(inventorySlotID, itemLink));

	local socketData, socketSource = SelectPrimarySocketData(gemlessData, resolvedData);

	SocketUtil.MergeLayout(socketData.layout, gemlessData.layout);
	SocketUtil.MergeLayout(socketData.layout, resolvedData.layout);

	SocketUtil.AppendMissingTypes(socketData.layout, gemlessData.layout);
	SocketUtil.AppendMissingTypes(socketData.layout, resolvedData.layout);

	if resolvedData.bonusText then
		socketData.bonusText = resolvedData.bonusText;
	elseif gemlessData.bonusText then
		socketData.bonusText = gemlessData.bonusText;
	end

	socketData.bonusActive = resolvedData.bonusActive == true;

	local expectedCount = GetExpectedSocketCount(itemLink);
	while #socketData.layout < expectedCount do
		SocketUtil.AddSocket(socketData.layout, SocketType.PRISMATIC);
	end

	socketData.signature = SocketUtil.BuildSocketSignature(socketData.layout);

	DebugSocket(
		"socket data source=%s final=%d signature=%s",
		socketSource,
		#socketData.layout,
		tostring(socketData.signature)
	);

	return socketData;
end

function DataProviderMixin:ApplyGemToSocket(slotData, socketIndex, gemLink, gemItem)
	local socketData = slotData.socketData;
	local socketEntry = socketData.layout[socketIndex];
	if not socketEntry then
		return;
	end

	socketEntry.gemLink = gemLink;
	socketEntry.gemIcon = gemItem:GetItemIcon();

	local gemColorInfo = self:ResolveGemColorInfo(gemLink);
	local gemColorMask;
	local gemMatchesAnySocket = false;

	if gemColorInfo then
		gemColorMask = gemColorInfo.mask;
		gemMatchesAnySocket = gemColorInfo.matchesAnySocket == true;
	end

	socketEntry.gemColorMask = gemColorMask;
	socketEntry.gemMatchesAnySocket = gemMatchesAnySocket;
	socketEntry.gemSocketTypes = SocketUtil.BuildSocketTypesFromMask(gemColorMask, gemMatchesAnySocket);

	local matchesSocket = GemUtil.DoesGemMatchSocket(socketEntry.socketType, gemColorInfo);
	if matchesSocket ~= nil then
		socketEntry.matchesSocket = matchesSocket;
		socketEntry.matchSource = MatchSource.EXACT;
	elseif socketData.bonusActive then
		socketEntry.matchesSocket = true;
		socketEntry.matchSource = MatchSource.BONUS;
	end

	DebugSocket(
		"apply gem slot=%d socket=%d type=%s mask=%s match=%s source=%s",
		slotData.slotID,
		socketIndex,
		tostring(socketEntry.socketType),
		FormatGemColorMask(gemColorMask),
		tostring(socketEntry.matchesSocket),
		tostring(socketEntry.matchSource)
	);
end

function DataProviderMixin:ContinueWithSocketGemData(slotData, callback)
	local socketData = slotData.socketData;
	local layout = socketData.layout;

	if #layout == 0 then
		callback(slotData);
		return;
	end

	local requests = {};
	local pending = 0;
	local finished = false;
	local gemSourceItemLink = self:GetGemSourceItemLink(slotData.inventorySlotID, slotData.itemLink);

	if gemSourceItemLink ~= slotData.itemLink then
		slotData.itemLink = gemSourceItemLink;
		slotData.itemToken = LinkUtil.GetItemStringFromLink(gemSourceItemLink) or slotData.itemToken;
	end

	local function Finalize()
		if finished or pending > 0 then
			return;
		end

		finished = true;
		callback(slotData);
	end

	for socketIndex = 1, #layout do
		local _, gemLink = C_Item.GetItemGem(gemSourceItemLink, socketIndex);
		if gemLink then
			requests[#requests + 1] = {
				socketIndex = socketIndex,
				gemLink = gemLink,
			};
			pending = pending + 1;
		end
	end

	if pending == 0 then
		Finalize();
		return;
	end

	for index = 1, #requests do
		local request = requests[index];
		local gemItem = Item:CreateFromItemLink(request.gemLink);

		gemItem:ContinueOnItemLoad(function()
			self:ApplyGemToSocket(slotData, request.socketIndex, request.gemLink, gemItem);

			pending = pending - 1;
			Finalize();
		end);
	end
end
