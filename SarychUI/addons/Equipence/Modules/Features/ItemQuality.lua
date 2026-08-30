--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local EquipmentLayout = Engine.Modules.EquipmentLayout;


---------------------------------------------------------------------------------------------------
-- ItemQualityFeatureMixin an item quality border overlay on the slot button
-- based on the equipped item's quality. Driven by `slotData.itemQuality`.
---------------------------------------------------------------------------------------------------

--@class ItemQualityFeatureMixin<module>
local ItemQualityFeatureMixin = {};

function ItemQualityFeatureMixin:CreateSlotWidgets(controller, slotView)
	local border = slotView.button:CreateTexture(nil, "OVERLAY");
	border:SetTexture(Engine.Media.ITEM_BORDER);
	border:SetAllPoints();
	border:Hide();

	slotView.widgets.qualityBorder = border;
end

function ItemQualityFeatureMixin:ClearSlot(controller, slotView)
	self:ResetQualityBorder(slotView.widgets.qualityBorder);
end

function ItemQualityFeatureMixin:ResetQualityBorder(border)
	border:SetVertexColor(1, 1, 1);
	border:Hide();
end

function ItemQualityFeatureMixin:ApplyQualityBorder(controller, border, quality)
	if controller.settings.colorItemQuality == false then
		EquipmentLayout:ApplyDefaultBorderColor(border);
	else
		EquipmentLayout:ApplyQualityColor(border, quality);
	end

	border:Show();
end

-- Quality border states: hidden, visible;
function ItemQualityFeatureMixin:ApplySlotData(controller, slotView, slotData)
	local border = slotView.widgets.qualityBorder;

	if controller.settings.showQualityBorder == false then
		self:ResetQualityBorder(border);
		return;
	end

	if not slotData or not slotData.itemID or slotData.itemID <= 0 then
		self:ResetQualityBorder(border);
		return;
	end

	self:ApplyQualityBorder(controller, border, slotData.itemQuality);
end

Engine.Modules.ItemQualityFeatureMixin = ItemQualityFeatureMixin;
