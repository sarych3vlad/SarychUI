--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local Data = Engine.Shared.Data;
local ItemLevelColorInfo = Data.ItemLevelColorInfo;

--@natives<lua,wow>
local _G = _G;
local format = string.format;
local pairs = pairs;
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS;


---------------------------------------------------------------------------------------------------
-- ItemLevelsFeatureMixin renders per-slot item level text and average item level summary.
-- Driven by `slotData.itemLevel` and host scoped display settings.
---------------------------------------------------------------------------------------------------

--@constants
local BASE_FRAME_LEVEL_OFFSET = 2;

local DISPLAY_SCOPE_PLAYER = "PLAYER";
local DISPLAY_SCOPE_INSPECT = "INSPECT";
local DISPLAY_SCOPE_NONE = "NONE";

local DEFAULT_AVERAGE_POSITION = "BOTTOM";

local AVERAGE_POSITION = {
	TOP = {
		point = "TOP",
		relativePoint = "BOTTOM",
		x = -8,
		y = -50,
		anchorKeys = { "NameFrame", "TitleText" },
	},
	BOTTOM = {
		point = "TOP",
		relativePoint = "BOTTOM",
		x = 22,
		y = 60,
		anchorKeys = { "MainHandSlot", "SecondaryHandSlot" },
	},
	LEFT = {
		point = "RIGHT",
		relativePoint = "LEFT",
		x = -6,
		y = -8,
		anchorKeys = { "MainHandSlot", "SecondaryHandSlot" },
	},
	RIGHT = {
		point = "LEFT",
		relativePoint = "RIGHT",
		x = 6,
		y = -8,
		anchorKeys = { "RangedSlot", "SecondaryHandSlot" },
	},
};

--@class ItemLevelsFeatureMixin<module>
local ItemLevelsFeatureMixin = {};

local function ResetItemLevelText(text)
	text:SetText("");
	text:SetTextColor(1, 1, 1);
end

local function ResetAverageItemLevelText(text)
	text:SetText("");
	text:SetTextColor(1, 1, 1);
end

local function ItemLevels_IsDisplayScope(displayScope, isInspect)
	if displayScope == DISPLAY_SCOPE_NONE then
		return false;
	end

	if displayScope == DISPLAY_SCOPE_PLAYER then
		return not isInspect;
	end

	if displayScope == DISPLAY_SCOPE_INSPECT then
		return isInspect;
	end

	return true;
end

local function IsInspectController(controller)
	return controller.host.slotPrefix == "Inspect";
end

local function InRange(value, minValue, maxValue)
	return value >= minValue and (not maxValue or value <= maxValue);
end

local function GetItemLevelColor(itemLevel)
	for index = 1, #ItemLevelColorInfo do
		local colorInfo = ItemLevelColorInfo[index];
		if InRange(itemLevel, colorInfo.minLevel, colorInfo.maxLevel) then
			return ITEM_QUALITY_COLORS[colorInfo.quality];
		end
	end
end

local function FormatAverageValue(settings, averageItemLevel)
	if settings.averageItemLevelUseDecimals == false then
		return format("%.0f", averageItemLevel);
	end

	return format("%.1f", averageItemLevel);
end

local function FormatItemLevelLabel(valueText)
	return format(Engine.Localization:GetLocaleText("AVERAGE_ITEM_LEVEL_FORMAT"), valueText);
end

local function GetAverageItemLevelAnchor(host, layout)
	local prefix = host.slotPrefix or "Character";
	local anchorKeys = layout.anchorKeys;

	for index = 1, #anchorKeys do
		local anchor = _G[prefix .. anchorKeys[index]];
		if anchor then
			return anchor;
		end
	end

	return host.summaryAnchor or host.frame;
end

function ItemLevelsFeatureMixin:ShouldShowItemLevels(controller)
	local settings = controller.settings;
	return settings.showItemLevel ~= false
	   and ItemLevels_IsDisplayScope(settings.itemLevelDisplayScope, IsInspectController(controller));
end

function ItemLevelsFeatureMixin:ShouldShowAverageItemLevel(controller)
	local settings = controller.settings;
	return settings.showAverageItemLevel ~= false
	   and ItemLevels_IsDisplayScope(settings.averageItemLevelDisplayScope, IsInspectController(controller));
end

function ItemLevelsFeatureMixin:CreateGlobalWidgets(controller)
	local parentFrame = controller.host.summaryAnchor or controller.host.frame;
	if not parentFrame then
		return;
	end

	local frame = CreateFrame("Frame", nil, parentFrame);
	frame:SetAllPoints();
	frame:SetFrameLevel(parentFrame:GetFrameLevel() + BASE_FRAME_LEVEL_OFFSET);

	local text = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Outline");
	text:SetJustifyH("CENTER");
	text:SetText("");

	controller.widgets.avgItemLevelText = text;
end

function ItemLevelsFeatureMixin:CreateSlotWidgets(controller, slotView)
	local text = slotView.button:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small");
	text:SetPoint("TOP", slotView.button, "BOTTOM", 0, 12);
	text:SetText("");

	slotView.widgets.itemLevelText = text;
end

function ItemLevelsFeatureMixin:ClearSlot(controller, slotView)
	ResetItemLevelText(slotView.widgets.itemLevelText);
end

function ItemLevelsFeatureMixin:ApplySlotItemLevelText(controller, text, itemLevel, itemQuality)
	text:SetText(itemLevel);

	if controller.settings.colorItemQuality == false then
		text:SetTextColor(1, 1, 1);
		return;
	end

	-- local color = itemQuality and ITEM_QUALITY_COLORS[itemQuality];
	local color = GetItemLevelColor(itemLevel);
	if color then
		text:SetTextColor(color.r, color.g, color.b);
	else
		text:SetTextColor(1, 1, 1);
	end
end

function ItemLevelsFeatureMixin:ApplySlotData(controller, slotView, slotData)
	local text = slotView.widgets.itemLevelText;

	if not self:ShouldShowItemLevels(controller) or slotView.slotInfo.showItemLevel == false then
		ResetItemLevelText(text);
		return;
	end

	if not slotData then
		ResetItemLevelText(text);
		return;
	end

	local itemLevel = slotData.itemLevel;
	if not itemLevel or itemLevel <= 0 then
		ResetItemLevelText(text);
		return;
	end

	self:ApplySlotItemLevelText(controller, text, itemLevel, slotData.itemQuality);
end

function ItemLevelsFeatureMixin:GetAverageItemLevel(controller)
	local total = 0;
	local count = 0;

	for _, slotView in pairs(controller.slots) do
		local slotInfo = slotView.slotInfo;

		if slotInfo.countForAverage ~= false then
			local slotData = slotView.lastSlotData;
			local itemLevel = slotData and slotData.itemLevel;

			if itemLevel and itemLevel > 0 then
				total = total + itemLevel;
				count = count + 1;
			end
		end
	end

	if count == 0 then
		return nil;
	end

	return total / count;
end

function ItemLevelsFeatureMixin:LayoutAverageItemLevelText(controller, text)
	local layout = AVERAGE_POSITION[controller.settings.averageItemLevelPosition] or AVERAGE_POSITION[DEFAULT_AVERAGE_POSITION];
	local anchor = GetAverageItemLevelAnchor(controller.host, layout);

	text:ClearAllPoints();
	text:SetPoint(layout.point, anchor, layout.relativePoint, layout.x, layout.y);
end

function ItemLevelsFeatureMixin:ApplyAverageItemLevelColor(controller, text, averageItemLevel)
	if controller.settings.colorAverageItemLevel ~= true then
		text:SetTextColor(1, 1, 1);
		return;
	end

	local color = GetItemLevelColor(averageItemLevel);
	if color then
		text:SetTextColor(color.r, color.g, color.b);
	else
		text:SetTextColor(1, 1, 1);
	end
end

function ItemLevelsFeatureMixin:ApplyAverageItemLevelText(controller, text, averageItemLevel)
	local settings = controller.settings;
	local valueText = FormatAverageValue(settings, averageItemLevel);

	if settings.showAverageItemLevelLabel == false then
		text:SetText(valueText);
	else
		text:SetText(FormatItemLevelLabel(valueText));
	end

	if CharacterItemLevelFrame then -- deprecated
		CharacterItemLevelFrame.ilvltext:SetText(valueText);
		self:ApplyAverageItemLevelColor(controller, CharacterItemLevelFrame.ilvltext, averageItemLevel);
	end
	self:ApplyAverageItemLevelColor(controller, text, averageItemLevel);
end

function ItemLevelsFeatureMixin:ApplySummary(controller)
	local text = controller.widgets.avgItemLevelText;
	if not text then
		return;
	end

	self:LayoutAverageItemLevelText(controller, text);

	if not self:ShouldShowAverageItemLevel(controller) then
		ResetAverageItemLevelText(text);
		return;
	end

	local averageItemLevel = self:GetAverageItemLevel(controller);
	if not averageItemLevel then
		ResetAverageItemLevelText(text);
		return;
	end

	self:ApplyAverageItemLevelText(controller, text, averageItemLevel);
end

Engine.Modules.ItemLevelsFeatureMixin = ItemLevelsFeatureMixin;
