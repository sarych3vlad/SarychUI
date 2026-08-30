--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local C_Texture = Engine.Aegis:GetNamespace("C_Texture");

--@natives<lua,wow>
local floor = math.floor;
local max = math.max;
local CreateFrame = CreateFrame;
local GameTooltip = GameTooltip;
local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS;

--@constants
local BASE_ICON_SIZE = 16;
local BASE_FRAME_LEVEL_OFFSET = 7;
local DEFAULT_SOCKET_ICON_SIZE = 24;
local DEFAULT_ENCHANT_ICON_SIZE = 24;
local DEFAULT_INLINE_ICON_GAP = 3;


-- inset/outset are in BASE_ICON_SIZE units.
local INLINE_VISUAL_STYLE = {
	BORDER_ROUND			= { inset = 0,  outset = 2,  texCoord = { 0.062, 0.94, 0.062, 0.94 } },
	BORDER_SQUARE			= { inset = 0,  outset = 4,  texCoord = { 0.018, 0.94, 0.018, 0.94 } },
	BRACKET					= { inset = 0,  outset = 0 },
	GEM_ICON_ROUND			= { inset = 0,  outset = 0 },
	GEM_ICON_SQUARE			= { inset = 1,  outset = 0 },
	SOCKET_BACKDROP_ROUND   = { inset = 0,  outset = 1,  texCoord = { 0.062, 0.94, 0.062, 0.94 } },
	SOCKET_BACKDROP_SQUARE  = { inset = 0,  outset = .5 },
};

----------------------------------------------------------------------
-- AnchorUtil
----------------------------------------------------------------------
local AnchorUtil = {};

-- Fallback align when the slot does not override it.
local DEFAULT_ALIGN = {
	LEFT   = "TOP",
	RIGHT  = "TOP",
	TOP    = "CENTER",
	BOTTOM = "CENTER",
};

-- Default growth mode
-- `HORIZONTAL` growth is resolved against the slot side.
local DEFAULT_GROWTH = {
	LEFT   = "HORIZONTAL",
	RIGHT  = "HORIZONTAL",
	TOP    = "HORIZONTAL",
	BOTTOM = "HORIZONTAL",
};

-- [side][align] = { anchorPoint, relativePoint }
-- Inline spacing uses `inlineOffset`, so both points stay on the same edge.
local SLOT_ANCHOR_MAP = {
	LEFT = {
		TOP    = { "TOPRIGHT",    "TOPRIGHT" },
		CENTER = { "RIGHT",       "RIGHT" },
		BOTTOM = { "BOTTOMRIGHT", "BOTTOMRIGHT" },
	},
	RIGHT = {
		TOP    = { "TOPLEFT",     "TOPLEFT" },
		CENTER = { "LEFT",        "LEFT" },
		BOTTOM = { "BOTTOMLEFT",  "BOTTOMLEFT" },
	},
	TOP = {
		LEFT   = { "TOPLEFT",     "TOPLEFT" },
		CENTER = { "TOP",         "TOP" },
		RIGHT  = { "TOPRIGHT",    "TOPRIGHT" },
	},
	BOTTOM = {
		LEFT   = { "BOTTOMLEFT",  "BOTTOMLEFT" },
		CENTER = { "BOTTOM",      "BOTTOM" },
		RIGHT  = { "BOTTOMRIGHT", "BOTTOMRIGHT" },
	},
};

-- Side slots grow toward the character model by default.
local GROWTH_VECTOR_MAP = {
	LEFT   = { HORIZONTAL = {  1,  0 }, VERTICAL = { 0, -1 } },
	RIGHT  = { HORIZONTAL = { -1,  0 }, VERTICAL = { 0, -1 } },
	TOP    = { HORIZONTAL = {  1,  0 }, VERTICAL = { 0,  1 } },
	BOTTOM = { HORIZONTAL = {  1,  0 }, VERTICAL = { 0, -1 } },
};

-- Explicit directions bypass side-based growth.
local EXPLICIT_GROWTH_VECTOR = {
	UP    = { 0,  1 },
	DOWN  = { 0, -1 },
	LEFT  = { -1, 0 },
	RIGHT = { 1,  0 },
};

function AnchorUtil.GetDefaultAlign(side)
	return DEFAULT_ALIGN[side] or "TOP";
end

function AnchorUtil.GetDefaultGrowth(side)
	return DEFAULT_GROWTH[side] or "HORIZONTAL";
end

function AnchorUtil.GetSlotAnchorPoint(side, align)
	local sideMap = SLOT_ANCHOR_MAP[side];
	if not sideMap then
		return "TOPRIGHT", "TOPRIGHT";
	end

	local entry = sideMap[align] or sideMap[DEFAULT_ALIGN[side]];
	if not entry then
		return "TOPRIGHT", "TOPRIGHT";
	end

	return entry[1], entry[2];
end

-- Weapon slots use explicit growth ("UP")
function AnchorUtil.GetGrowthVector(side, growth)
	local explicit = EXPLICIT_GROWTH_VECTOR[growth];
	if explicit then
		return explicit[1], explicit[2];
	end

	local resolved = growth or DEFAULT_GROWTH[side];
	local sideMap = GROWTH_VECTOR_MAP[side];
	local vector = sideMap and sideMap[resolved];
	if vector then
		return vector[1], vector[2];
	end

	return 1, 0;
end


---------------------------------------------------------------------------------------------------
-- EquipmentLayout owns the shared layout for inline equipment widgets.
-- It creates the base frames, positions them relative to equipment slots,
-- and provides common helpers for icon geometry, borders and tooltips.
---------------------------------------------------------------------------------------------------

--@class EquipmentLayout<system>
local EquipmentLayout = {};

function EquipmentLayout:GetOffset(settings, side)
	local sideOffsets = settings.layoutOffsets[side];

	return sideOffsets.x, sideOffsets.y;
end

function EquipmentLayout:GetSocketIconSize(settings)
	return settings.socketIconSize or DEFAULT_SOCKET_ICON_SIZE;
end

function EquipmentLayout:GetEnchantIconSize(settings)
	return settings.enchantIconSize or DEFAULT_ENCHANT_ICON_SIZE;
end

function EquipmentLayout:GetInlineIconGap(settings)
	return settings.inlineIconGap or DEFAULT_INLINE_ICON_GAP;
end

function EquipmentLayout:PropagateInlineIconMouse(controller, frame)
	frame:EnableMouse(controller.settings.disableIconHover ~= true);
end

function EquipmentLayout:LayoutInlineIconFrame(controller, slotView, frame, size)
	if not frame then
		return;
	end

	frame:ClearAllPoints();

	local side = slotView.side;
	local align = slotView.align or AnchorUtil.GetDefaultAlign(side);
	local growth = slotView.growth or AnchorUtil.GetDefaultGrowth(side);

	local anchorPoint, relativePoint = AnchorUtil.GetSlotAnchorPoint(side, align);
	local axisX, axisY = AnchorUtil.GetGrowthVector(side, growth);
	local offsetX, offsetY = self:GetOffset(controller.settings, side);

	frame:SetPoint(
		anchorPoint,
		slotView.button,
		relativePoint,
		offsetX + (axisX * slotView.inlineOffset),
		offsetY + (axisY * slotView.inlineOffset)
	);

	slotView.inlineOffset = slotView.inlineOffset + size + self:GetInlineIconGap(controller.settings);
end

-- Base inline icon frame
-- Features attach content; layout owns shell and positioning.
function EquipmentLayout:CreateInlineIconFrame(controller, slotView, size)
	local parent = slotView.button;
	local frame = CreateFrame("BUTTON", nil, parent);
	frame:SetSize(size, size);
	frame:SetFrameLevel(parent:GetFrameLevel() + BASE_FRAME_LEVEL_OFFSET);

	frame.ownerController = controller;
	self:PropagateInlineIconMouse(controller, frame);

	frame.texture = frame:CreateTexture(nil, "BORDER");
	self:ResetTextureGeometry(frame.texture, frame);

	frame.border = frame:CreateTexture(nil, "ARTWORK");
	self:ApplyBorderStyle(controller, frame.border);
	frame.border:Hide();

	slotView.widgets.inlineFrames = slotView.widgets.inlineFrames or {};
	slotView.widgets.inlineFrames[#slotView.widgets.inlineFrames + 1] = frame;

	return frame;
end

function EquipmentLayout:SetInlineIconFrameSize(controller, frame, size)
	if frame:GetWidth() == size and frame:GetHeight() == size then
		return;
	end

	frame:SetSize(size, size);
	self:ResetTextureGeometry(frame.texture, frame);
	self:ApplyBorderStyle(controller, frame.border);
end

-- Scale style geometry from the base icon size.
function EquipmentLayout:ApplyTextureGeometry(textureObject, parent, styleKey)
	if not textureObject or not parent then
		return;
	end

	local style = INLINE_VISUAL_STYLE[styleKey];
	if not style then
		self:ResetTextureGeometry(textureObject, parent);
		return;
	end

	local width = parent:GetWidth() or BASE_ICON_SIZE;
	local height = parent:GetHeight() or BASE_ICON_SIZE;
	local scale = max(width, height) / BASE_ICON_SIZE;

	local inset = max(0, floor(style.inset * scale + 0.5));
	local outset = max(0, floor(style.outset * scale + 0.5));
	local expand = outset - inset;

	textureObject:ClearAllPoints();
	textureObject:SetPoint("CENTER", parent, "CENTER", 0, 0);
	textureObject:SetSize(max(1, width + expand * 2), max(1, height + expand * 2));

	local texCoord = style.texCoord;
	if texCoord then
		textureObject:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4]);
	else
		textureObject:SetTexCoord(0, 1, 0, 1);
	end
end

function EquipmentLayout:ApplyIconTexture(controller, textureObject, texturePath)
	if not textureObject then
		return;
	end

	local useRounded = controller.settings.useRoundedIcons;
	if useRounded and texturePath then
		C_Texture.SetPortraitToTexture(textureObject, texturePath);
	else
		C_Texture.ClearPortraitMask(textureObject);
		textureObject:SetTexture(texturePath);
		textureObject:SetTexCoord(0, 1, 0, 1);
	end

	self:ResetTextureState(textureObject);
end

function EquipmentLayout:ApplyBorderStyle(controller, borderTexture)
	if not borderTexture then
		return;
	end

	local parent = borderTexture:GetParent();
	if not parent then
		return;
	end

	local useRounded = controller.settings.useRoundedIcons == true;
	local styleKey = useRounded and "BORDER_ROUND" or "BORDER_SQUARE";

	self:ApplyTextureGeometry(borderTexture, parent, styleKey);

	if useRounded then
		borderTexture:SetTexture(Engine.Media.ROUND_BORDER);
	else
		borderTexture:SetTexture("Interface\\Buttons\\UI-Quickslot2");
	end
end

-- Border Colors.
--
function EquipmentLayout:ApplyDefaultBorderColor(textureObject)
	if not textureObject then
		return;
	end

	textureObject:SetVertexColor(1, 1, 1);
end

function EquipmentLayout:ApplyQualityColor(textureObject, quality)
	if not textureObject then
		return;
	end

	local color = quality and ITEM_QUALITY_COLORS[quality];
	if color then
		textureObject:SetVertexColor(color.r, color.g, color.b);
	else
		textureObject:SetVertexColor(1, 1, 1);
	end
end

-- Reset textures.
--
function EquipmentLayout:ResetTextureState(textureObject)
	if not textureObject then
		return;
	end

	-- `texCoord` is owned by caller/style pass
	textureObject:SetVertexColor(1, 1, 1);
	textureObject:SetDesaturated(false);
end

-- Restore full parent geometry with no crop.
function EquipmentLayout:ResetTextureGeometry(textureObject, parent)
	if not textureObject or not parent then
		return;
	end

	textureObject:ClearAllPoints();
	textureObject:SetAllPoints(parent);
	textureObject:SetTexCoord(0, 1, 0, 1);
end

-- Tooltip Scripts.
--
do
	local function InlineTooltip_OnEnter(frame)
		local controller = frame.ownerController;
		if controller.settings.showIconTooltips == false then
			return;
		end

		local tooltipMode = frame.inlineTooltipMode;
		if tooltipMode == "link" and frame.inlineTooltipLink then
			GameTooltip:SetOwner(frame, frame.inlineTooltipAnchor or "ANCHOR_RIGHT");
			GameTooltip:SetHyperlink(frame.inlineTooltipLink);
			GameTooltip:Show();
			return;
		end

		if tooltipMode == "text" and frame.inlineTooltipText and frame.inlineTooltipText ~= "" then
			GameTooltip:SetOwner(frame, frame.inlineTooltipAnchor or "ANCHOR_RIGHT");
			GameTooltip:ClearLines();
			GameTooltip:AddLine(frame.inlineTooltipText);
			GameTooltip:Show();
			return;
		end

		if tooltipMode == "provider" and frame.inlineTooltipProvider then
			GameTooltip:SetOwner(frame, frame.inlineTooltipAnchor or "ANCHOR_RIGHT");
			GameTooltip:ClearLines();

			if frame.inlineTooltipProvider(frame, GameTooltip) then
				GameTooltip:Show();
			else
				GameTooltip:Hide();
			end
		end
	end

	local function InlineTooltip_OnLeave(frame)
		if GameTooltip:GetOwner() == frame then
			GameTooltip:Hide();
		end
	end

	function EquipmentLayout:InitTooltipScripts(frame)
		if not frame or frame.inlineTooltipScriptsHooked then
			return;
		end

		frame.inlineTooltipScriptsHooked = true;
		frame:SetScript("OnEnter", InlineTooltip_OnEnter);
		frame:SetScript("OnLeave", InlineTooltip_OnLeave);
	end
end

function EquipmentLayout:ClearTooltip(frame)
	if not frame then
		return;
	end

	if GameTooltip:GetOwner() == frame then
		GameTooltip:Hide();
	end

	frame.inlineTooltipMode = nil;
	frame.inlineTooltipLink = nil;
	frame.inlineTooltipText = nil;
	frame.inlineTooltipProvider = nil;
	frame.inlineTooltipAnchor = nil;
end

function EquipmentLayout:SetTooltipHyperlink(frame, link, anchor)
	if not frame or not link then
		if frame then
			self:ClearTooltip(frame);
		end
		return;
	end

	self:InitTooltipScripts(frame);

	frame.inlineTooltipMode = "link";
	frame.inlineTooltipLink = link;
	frame.inlineTooltipText = nil;
	frame.inlineTooltipProvider = nil;
	frame.inlineTooltipAnchor = anchor;
end

function EquipmentLayout:SetTooltipText(frame, text, anchor)
	if not frame or not text or text == "" then
		if frame then
			self:ClearTooltip(frame);
		end
		return;
	end

	self:InitTooltipScripts(frame);

	frame.inlineTooltipMode = "text";
	frame.inlineTooltipText = text;
	frame.inlineTooltipLink = nil;
	frame.inlineTooltipProvider = nil;
	frame.inlineTooltipAnchor = anchor;
end

function EquipmentLayout:SetTooltipProvider(frame, provider, anchor)
	if not frame or not provider then
		if frame then
			self:ClearTooltip(frame);
		end
		return;
	end

	self:InitTooltipScripts(frame);

	frame.inlineTooltipMode = "provider";
	frame.inlineTooltipProvider = provider;
	frame.inlineTooltipLink = nil;
	frame.inlineTooltipText = nil;
	frame.inlineTooltipAnchor = anchor;
end


Engine.Modules.EquipmentLayout = EquipmentLayout;
