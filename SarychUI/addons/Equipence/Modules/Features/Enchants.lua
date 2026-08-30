--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local Constants = Engine.Shared.Constants;
local EquipmentLayout = Engine.Modules.EquipmentLayout;

--@natives<wow>
local GetItemInfo = GetItemInfo;
local GetSpellLink = GetSpellLink;

--@constants
local MISSING_ENCHANT_TEXT = "Missing enchant";

local function EnchantTooltipProvider(frame, tooltip)
	if frame.showMissingEnchant then
		tooltip:AddLine(MISSING_ENCHANT_TEXT, 1, 0.2, 0.2);
		return true;
	end

	local data = frame.enchantTooltipData;
	if not data then
		return false;
	end

	if data.spellID and GetSpellLink then
		local spellLink = GetSpellLink(data.spellID);
		if spellLink then
			tooltip:SetHyperlink(spellLink);
			return true;
		end
	end

	if data.itemID then
		local _, itemLink = GetItemInfo(data.itemID);
		if itemLink then
			tooltip:SetHyperlink(itemLink);
			return true;
		end
	end

	local text = data.fullText or data.text;
	if text and text ~= "" then
		tooltip:AddLine(text);
		return true;
	end

	return false;
end

---------------------------------------------------------------------------------------------------
-- EnchantsFeatureMixin renders enchant icons and missing enchant placeholders
-- for enchantable equipment slots. It operates on inline frames created by EquipmentLayout
-- and reads resolved data from `slotData.enchantData`.
---------------------------------------------------------------------------------------------------

--@class EnchantsFeatureMixin<module>
local EnchantsFeatureMixin = {};

function EnchantsFeatureMixin:IsSlotEnchantable(slotView)
	return slotView.slotInfo.enchantable == true;
end

function EnchantsFeatureMixin:CreateSlotWidgets(controller, slotView)
	if not self:IsSlotEnchantable(slotView) then
		return;
	end

	local frame = controller:CreateInlineIconFrame(slotView, EquipmentLayout:GetEnchantIconSize(controller.settings));

	slotView.widgets.enchantFrame = frame;
end

function EnchantsFeatureMixin:ResetEnchantFrame(frame)
	EquipmentLayout:ClearTooltip(frame);

	frame.texture:SetTexture(nil);

	EquipmentLayout:ResetTextureState(frame.texture);
	EquipmentLayout:ResetTextureGeometry(frame.texture, frame);

	frame.border:Hide();
	EquipmentLayout:ApplyDefaultBorderColor(frame.border);

	frame.enchantTooltipData = nil;
	frame.showMissingEnchant = nil;
	frame:Hide();
end

function EnchantsFeatureMixin:ClearSlot(controller, slotView)
	local frame = slotView.widgets.enchantFrame;
	if not frame then
		return;
	end

	self:ResetEnchantFrame(frame);
end

function EnchantsFeatureMixin:ApplyEnchantFrame(controller, frame, texturePath)
	EquipmentLayout:ApplyIconTexture(controller, frame.texture, texturePath);
	EquipmentLayout:ApplyBorderStyle(controller, frame.border);
	EquipmentLayout:ApplyDefaultBorderColor(frame.border);

	frame.border:Show();
end

-- Enchant frame states: hidden, enchanted, missing.
function EnchantsFeatureMixin:ApplyResolvedEnchantFrame(controller, frame, enchantData)
	self:ApplyEnchantFrame(controller, frame, enchantData.icon);

	frame.enchantTooltipData = enchantData;
	frame.showMissingEnchant = nil;
	EquipmentLayout:SetTooltipProvider(frame, EnchantTooltipProvider);
	frame:Show();
end

function EnchantsFeatureMixin:ApplyMissingEnchantFrame(controller, frame)
	self:ApplyEnchantFrame(controller, frame, Constants.ENCHANT_FALLBACK_TEXTURE);

	frame.texture:SetDesaturated(true);
	frame.texture:SetVertexColor(0.6, 0.6, 0.6);

	frame.enchantTooltipData = nil;
	frame.showMissingEnchant = true;
	EquipmentLayout:SetTooltipProvider(frame, EnchantTooltipProvider);
	frame:Show();
end

function EnchantsFeatureMixin:ApplySlotData(controller, slotView, slotData)
	local frame = slotView.widgets.enchantFrame;
	if not frame then
		return;
	end

	local settings = controller.settings;
	if settings.showEnchants == false then
		self:ResetEnchantFrame(frame);
		return;
	end

	EquipmentLayout:PropagateInlineIconMouse(controller, frame);
	EquipmentLayout:SetInlineIconFrameSize(controller, frame, EquipmentLayout:GetEnchantIconSize(settings));

	if not slotData or not slotData.itemID or slotData.itemID <= 0 then
		self:ResetEnchantFrame(frame);
		return;
	end

	local enchantData = slotData.enchantData;
	if enchantData and enchantData.icon then
		self:ApplyResolvedEnchantFrame(controller, frame, enchantData);
		return;
	end

	if settings.showMissingEnchants == false then
		self:ResetEnchantFrame(frame);
		return;
	end

	self:ApplyMissingEnchantFrame(controller, frame);
end

Engine.Modules.EnchantsFeatureMixin = EnchantsFeatureMixin;
