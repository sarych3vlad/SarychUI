--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local Constants = Engine.Shared.Constants;
local Data = Engine.Shared.Data;
local EquipmentLayout = Engine.Modules.EquipmentLayout;
local ShineUtil = Engine.Modules.ShineUtil;
local TextureUtil = Engine.Aegis:GetNamespace("TextureUtil");

--@natives<wow>
local SetDesaturation = SetDesaturation;

--@constants
local MAX_SOCKETS = Constants.MAX_SOCKETS;
local SOCKET_ATLAS = Constants.ITEM_SOCKET_ATLAS;
local SOCKET_BACKGROUND_ATLAS = "socket-%s-background";
local SOCKET_CLOSED_ATLAS = "socket-%s-closed";
local SOCKET_OPEN_ATLAS = "socket-%s-open";


---------------------------------------------------------------------------------------------------
-- GemsFeatureMixin renders socket icons, empty socket states, and bracket overlays
-- for each equipment slot. It operates on inline frames created by EquipmentLayout
-- and reads resolved data from `slotData.socketData`.
---------------------------------------------------------------------------------------------------

--@class GemsFeatureMixin<module>
local GemsFeatureMixin = {};

function GemsFeatureMixin:CreateSlotWidgets(controller, slotView)
	slotView.widgets.socketFrames = {};

	for index = 1, MAX_SOCKETS do
		local frame = controller:CreateInlineIconFrame(slotView, EquipmentLayout:GetSocketIconSize(controller.settings));

		frame.socketBackdrop = frame:CreateTexture(nil, "BACKGROUND");
		frame.socketBackdrop:Hide();

		frame.openBracket = frame:CreateTexture(nil, "OVERLAY");
		frame.openBracket:Hide();

		frame.closedBracket = frame:CreateTexture(nil, "OVERLAY");
		frame.closedBracket:Hide();

		frame.matchShine = ShineUtil:CreateGlow(frame);

		slotView.widgets.socketFrames[index] = frame;
	end
end

function GemsFeatureMixin:ClearSocketIcon(frame)
	frame.texture:SetTexture(nil);

	EquipmentLayout:ResetTextureState(frame.texture);
	EquipmentLayout:ResetTextureGeometry(frame.texture, frame);
end

function GemsFeatureMixin:ResetSocketFrame(frame)
	self:ClearSocketIcon(frame);

	frame.socketBackdrop:Hide();
	frame.border:Hide();

	frame.openBracket:Hide();
	frame.closedBracket:Hide();

	ShineUtil:StopAnim(frame.matchShine);

	EquipmentLayout:ClearTooltip(frame);
	frame:Hide();
end

function GemsFeatureMixin:ClearSlot(controller, slotView)
	local socketFrames = slotView.widgets.socketFrames;

	for index = 1, MAX_SOCKETS do
		self:ResetSocketFrame(socketFrames[index]);
	end
end

function GemsFeatureMixin:ShouldAnimateMatchedGems(controller)
	return controller.settings.animateGemsShine == true;
end

function GemsFeatureMixin:GetSocketAtlasInfo(socketType)
	local socketVisual = self:GetSocketVisualInfo(socketType);
	local legacySocketType = socketVisual.legacySocketType or socketType or "PRISMATIC";

	return Constants.GEM_SOCKET_INFO[legacySocketType] or Constants.GEM_SOCKET_INFO.PRISMATIC;
end

function GemsFeatureMixin:GetEmptySocketTexture(socketType)
	local socketVisual = self:GetSocketVisualInfo(socketType);
	local legacySocketType = socketVisual.legacySocketType or socketType or "PRISMATIC";

	return Constants.EMPTY_SOCKET_TEXTURES[legacySocketType] or Constants.EMPTY_SOCKET_TEXTURE;
end

function GemsFeatureMixin:GetSocketVisualInfo(socketType)
	return Data.SocketVisualInfo[socketType] or Data.SocketVisualInfo.PRISMATIC;
end

function GemsFeatureMixin:GetSocketColor(socketType)
	local socketVisual = self:GetSocketVisualInfo(socketType);

	return socketVisual.r, socketVisual.g, socketVisual.b;
end

function GemsFeatureMixin:ApplySocketVertexColor(textureObject, socketType)
	local r, g, b = self:GetSocketColor(socketType);
	textureObject:SetVertexColor(r, g, b);
end

-- Try native/custom atlas data first; legacy clients fall back to UI-ItemSockets below.
function GemsFeatureMixin:ApplySocketTextureKit(textureObject, parent, socketType, atlasFormat, styleKey)
	local socketVisual = self:GetSocketVisualInfo(socketType);
	local textureKit = socketVisual.textureKit;
	if not textureKit then
		return false;
	end

	if styleKey then
		EquipmentLayout:ApplyTextureGeometry(textureObject, parent, styleKey);
	else
		EquipmentLayout:ResetTextureGeometry(textureObject, parent);
	end

	local success = TextureUtil.SetupTextureKitOnFrame(textureKit, textureObject, atlasFormat, nil, false);
	if success then
		EquipmentLayout:ResetTextureState(textureObject);
	end

	return success;
end

function GemsFeatureMixin:UpdateSocketShine(controller, frame, socketEntry)
	if not self:ShouldAnimateMatchedGems(controller) then
		ShineUtil:StopAnim(frame.matchShine);
		return;
	end

	if socketEntry and socketEntry.matchesSocket == true then
		local r, g, b = self:GetSocketColor(socketEntry.socketType);
		ShineUtil:StartAnim(frame.matchShine, r, g, b, controller.settings.shineSize, controller.settings.shineSpeed);
	else
		ShineUtil:StopAnim(frame.matchShine);
	end
end

-- Applies open or closed socket `bracket` for `socketType`.
function GemsFeatureMixin:ApplySocketAtlas(frame, socketType, hasGem)
	frame.openBracket:Hide();
	frame.closedBracket:Hide();

	local bracket = hasGem and frame.openBracket or frame.closedBracket;
	local atlasFormat = hasGem and SOCKET_OPEN_ATLAS or SOCKET_CLOSED_ATLAS;
	local socketVisual = self:GetSocketVisualInfo(socketType);

	if self:ApplySocketTextureKit(bracket, frame, socketType, atlasFormat, "BRACKET") then
		bracket:Show();

		if SetDesaturation then
			SetDesaturation(bracket, socketVisual.desaturateBrackets == true);
		end

		return;
	end

	local left, right, top, bottom;
	local socketInfo = self:GetSocketAtlasInfo(socketType);
	if hasGem then
		left, right, top, bottom = socketInfo.CBLeft, socketInfo.CBRight, socketInfo.CBTop, socketInfo.CBBottom;
	else
		left, right, top, bottom = socketInfo.OBLeft, socketInfo.OBRight, socketInfo.OBTop, socketInfo.OBBottom;
	end

	EquipmentLayout:ApplyTextureGeometry(bracket, frame, "BRACKET");

	bracket:SetTexture(SOCKET_ATLAS);
	bracket:SetTexCoord(left, right, top, bottom);
	bracket:Show();

	if SetDesaturation then
		SetDesaturation(bracket, socketVisual.desaturateBrackets == true);
	end
end

-- Rounded sockets use the shared border layer.
-- Square mode only draws a shell behind filled sockets.
function GemsFeatureMixin:ApplySocketShell(frame, socketType, hasGem, useRounded)
	frame.socketBackdrop:Hide();
	frame.border:Hide();

	if useRounded then
		local texturePath = hasGem and Engine.Media.ROUND_BORDER or Engine.Media.ROUND_SOCKET_BACKDROP;
		local styleKey = hasGem and "BORDER_ROUND" or "SOCKET_BACKDROP_ROUND";
		if not texturePath then
			return;
		end

		frame.border:SetTexture(texturePath);
		EquipmentLayout:ApplyTextureGeometry(frame.border, frame, styleKey);
		self:ApplySocketVertexColor(frame.border, socketType);

		frame.border:SetDesaturated(false);
		frame.border:Show();
		return;
	end

	-- Square mode: backdrop only under filled gems, empty socket uses `frame.texture` directly.
	if not hasGem then
		return;
	end

	if self:ApplySocketTextureKit(frame.socketBackdrop, frame, socketType, SOCKET_BACKGROUND_ATLAS, "SOCKET_BACKDROP_SQUARE") then
		frame.socketBackdrop:Show();
		return;
	end

	local texturePath = self:GetEmptySocketTexture(socketType);
	if not texturePath then
		return;
	end

	frame.socketBackdrop:SetTexture(texturePath);
	EquipmentLayout:ApplyTextureGeometry(frame.socketBackdrop, frame, "SOCKET_BACKDROP_SQUARE");

	frame.socketBackdrop:SetDesaturated(false);
	frame.socketBackdrop:SetVertexColor(1, 1, 1);
	frame.socketBackdrop:Show();
end

-- Socket frame states: hidden, empty, gemmed.
function GemsFeatureMixin:ApplyGemmedSocketFrame(controller, frame, socketEntry, useRounded, gemStyleKey)
	self:ApplySocketShell(frame, socketEntry.socketType, true, useRounded);

	EquipmentLayout:ApplyIconTexture(controller, frame.texture, socketEntry.gemIcon);
	EquipmentLayout:ApplyTextureGeometry(frame.texture, frame, gemStyleKey);

	self:ApplySocketAtlas(frame, socketEntry.socketType, true);
	self:UpdateSocketShine(controller, frame, socketEntry);

	EquipmentLayout:SetTooltipHyperlink(frame, socketEntry.gemLink);

	frame:Show();
end

function GemsFeatureMixin:ApplyEmptySocketFrame(frame, socketType, useRounded)
	self:ClearSocketIcon(frame);
	self:ApplySocketShell(frame, socketType, false, useRounded);

	if not useRounded then
		if not self:ApplySocketTextureKit(frame.texture, frame, socketType, SOCKET_BACKGROUND_ATLAS) then
			frame.texture:SetTexture(self:GetEmptySocketTexture(socketType));
		end
	end

	self:ApplySocketAtlas(frame, socketType, false);
	ShineUtil:StopAnim(frame.matchShine);

	EquipmentLayout:ClearTooltip(frame);

	frame:Show();
end

function GemsFeatureMixin:ApplySlotData(controller, slotView, slotData)
	local socketFrames = slotView.widgets.socketFrames;

	local settings = controller.settings;
	if settings.showGems == false then
		self:ClearSlot(controller, slotView);
		return;
	end

	if not slotData then
		self:ClearSlot(controller, slotView);
		return;
	end

	local socketLayout = slotData.socketData.layout;
	local useRounded = settings.useRoundedIcons == true;
	local gemStyleKey = useRounded and "GEM_ICON_ROUND" or "GEM_ICON_SQUARE";
	local iconSize = EquipmentLayout:GetSocketIconSize(settings);

	for index = 1, MAX_SOCKETS do
		local frame = socketFrames[index];
		local socketEntry = socketLayout[index];

		EquipmentLayout:PropagateInlineIconMouse(controller, frame);
		EquipmentLayout:SetInlineIconFrameSize(controller, frame, iconSize);

		if not socketEntry then
			self:ResetSocketFrame(frame);
		elseif socketEntry.gemIcon then
			self:ApplyGemmedSocketFrame(controller, frame, socketEntry, useRounded, gemStyleKey);
		elseif settings.showEmptySockets ~= false then
			self:ApplyEmptySocketFrame(frame, socketEntry.socketType, useRounded);
		else
			self:ResetSocketFrame(frame);
		end
	end
end

Engine.Modules.GemsFeatureMixin = GemsFeatureMixin;
