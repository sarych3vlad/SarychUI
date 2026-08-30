--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@natives<lua,wow>
local _G = _G;
local CreateFrame = CreateFrame;


-- Baseline model profile used when no settings override is present.
--
local DEFAULT_MODEL_LAYOUT = {
	width = 231,
	height = 320,
	positionX = 0.25,
	positionY = 0,
	positionZ = 0,
};

local DEFAULT_FADED_ALPHA = 0.12;
local DEFAULT_FADE_DURATION = 0.15;
local HOVER_UPDATE_INTERVAL = 0.05;


---------------------------------------------------------------------------------------------------
-- PaperDollLayout customizes the PaperDoll presentation around the character model,
-- stat frames, and optional slot visibility. It captures Blizzard defaults once and
-- reapplies layout changes from settings.
---------------------------------------------------------------------------------------------------

--@class PaperDollLayout<module>
local PaperDollLayout = {};

function PaperDollLayout:OnLoad(controller)
	self.defaults = {};
	self.settings = controller.settings;

	self.isApplied = false;
	self.attributesFadeEnabled = false;
	self.attributesHoverActive = false;
	self.attributesWatcher = nil;

	self:RefreshFrameRefs();
end

function PaperDollLayout:RefreshFrameRefs()
	self.paperDollFrame = _G.PaperDollFrame;
	self.characterModelFrame = _G.CharacterModelFrame;
	self.characterAttributesFrame = _G.CharacterAttributesFrame;
	self.characterResistanceFrame = _G.CharacterResistanceFrame;
	self.characterAmmoSlot = _G.CharacterAmmoSlot;
end

-- Captures default frame state before custom layout starts mutating PaperDoll UI.
-- If PaperDollFrame is not yet available, apply is deferred to the next OnShow.
function PaperDollLayout:Apply(controller)
	if self.isApplied then
		return;
	end

	self:RefreshFrameRefs();

	if not self.paperDollFrame then
		return;
	end

	self:CaptureModelDefaults("characterModelFrame", self.characterModelFrame);
	self:CaptureFrameDefaults("characterAttributesFrame", self.characterAttributesFrame);
	self:CaptureFrameDefaults("characterResistanceFrame", self.characterResistanceFrame);
	self:CaptureFrameDefaults("characterAmmoSlot", self.characterAmmoSlot);

	self.isApplied = true;
end

do
	--@natives<lua,wow>
	local unpack = unpack;
	local MouseIsOver = MouseIsOver;
	local UIFrameFadeIn = UIFrameFadeIn;
	local UIFrameFadeOut = UIFrameFadeOut;
	local UIFrameFadeRemoveFrame = UIFrameFadeRemoveFrame;

	-------------------------------------------------------------------
	-- Frame state capture / restore
	-------------------------------------------------------------------

	local function CapturePoints(frame)
		local points = {};
		for index = 1, frame:GetNumPoints() do
			points[index] = { frame:GetPoint(index) };
		end
		return points;
	end

	local function RestorePoints(frame, points)
		if not frame or not points or #points == 0 then
			return;
		end

		frame:ClearAllPoints();

		for index = 1, #points do
			frame:SetPoint(unpack(points[index]));
		end
	end

	function PaperDollLayout:CaptureFrameDefaults(key, frame)
		if not frame or self.defaults[key] then
			return;
		end

		self.defaults[key] = {
			points = CapturePoints(frame),
			width = frame:GetWidth(),
			height = frame:GetHeight(),
			alpha = frame:GetAlpha(),
			shown = frame:IsShown(),
		};
	end

	-- Model frames need the regular frame snapshot and actor position.
	function PaperDollLayout:CaptureModelDefaults(key, frame)
		if not frame or self.defaults[key] then
			return;
		end

		self:CaptureFrameDefaults(key, frame);

		local defaults = self.defaults[key];
		if frame.GetPosition then
			defaults.positionX, defaults.positionY, defaults.positionZ = frame:GetPosition();
		end
	end

	function PaperDollLayout:RestoreFrameDefaults(key, frame)
		local defaults = self.defaults[key];
		if not frame or not defaults then
			return;
		end

		RestorePoints(frame, defaults.points);

		if defaults.width and defaults.height then
			frame:SetSize(defaults.width, defaults.height);
		end

		if defaults.alpha ~= nil then
			frame:SetAlpha(defaults.alpha);
		end

		if defaults.positionX ~= nil and frame.SetPosition then
			frame:SetPosition(defaults.positionX, defaults.positionY, defaults.positionZ);
		end

		if defaults.shown then
			frame:Show();
		else
			frame:Hide();
		end
	end

	-- Fade state is driven by a passive hover watcher so stat frame hit testing stays intact.
	function PaperDollLayout:SetFrameAlpha(frame, alpha, instant)
		if not frame then
			return;
		end

		alpha = alpha or 1;

		local currentAlpha = frame:GetAlpha();
		if currentAlpha == alpha then
			return;
		end

		if UIFrameFadeRemoveFrame then
			UIFrameFadeRemoveFrame(frame);
		end

		if instant or not UIFrameFadeIn or not UIFrameFadeOut then
			frame:SetAlpha(alpha);
			return;
		end

		local duration = self:GetAttributesFadeDuration();
		if alpha > currentAlpha then
			UIFrameFadeIn(frame, duration, currentAlpha, alpha);
		else
			UIFrameFadeOut(frame, duration, currentAlpha, alpha);
		end
	end

	-------------------------------------------------------------------
	-- Attributes Region helpers
	-------------------------------------------------------------------

	function PaperDollLayout:SetAttributesRegionShown(isShown)
		local attributesFrame = self.characterAttributesFrame;
		if attributesFrame then
			if isShown then
				attributesFrame:Show();
			else
				attributesFrame:Hide();
			end
		end

		local resistanceFrame = self.characterResistanceFrame;
		if resistanceFrame then
			if isShown then
				resistanceFrame:Show();
			else
				resistanceFrame:Hide();
			end
		end
	end

	function PaperDollLayout:SetAttributesRegionAlpha(alpha, instant)
		local attributesFrame = self.characterAttributesFrame;
		if attributesFrame then
			self:SetFrameAlpha(attributesFrame, alpha, instant);
		end

		local resistanceFrame = self.characterResistanceFrame;
		if resistanceFrame then
			self:SetFrameAlpha(resistanceFrame, alpha, instant);
		end
	end

	function PaperDollLayout:RestoreAttributesRegionAlpha(instant)
		local attributesFrame = self.characterAttributesFrame;
		if attributesFrame then
			self:SetFrameAlpha(
				attributesFrame,
				self:GetDefaultFrameAlpha("characterAttributesFrame", 1),
				instant
			);
		end

		local resistanceFrame = self.characterResistanceFrame;
		if resistanceFrame then
			self:SetFrameAlpha(
				resistanceFrame,
				self:GetDefaultFrameAlpha("characterResistanceFrame", 1),
				instant
			);
		end
	end

	function PaperDollLayout:IsMouseOverAttributesRegion()
		local attributesFrame = self.characterAttributesFrame;
		if attributesFrame and attributesFrame:IsShown() and MouseIsOver(attributesFrame) then
			return true;
		end

		local resistanceFrame = self.characterResistanceFrame;
		if resistanceFrame and resistanceFrame:IsShown() and MouseIsOver(resistanceFrame) then
			return true;
		end

		return false;
	end
end

-- Refresh layout state that depends on settings or current Blizzard UI state.
--
function PaperDollLayout:OnHide()
	self:SetAttributesWatcher(false);
end

function PaperDollLayout:Restore()
	self:RefreshFrameRefs();
	self:SetAttributesWatcher(false);

	self.attributesFadeEnabled = false;
	self.attributesHoverActive = false;

	self:RestoreFrameDefaults("characterModelFrame", self.characterModelFrame);
	self:RestoreFrameDefaults("characterAttributesFrame", self.characterAttributesFrame);
	self:RestoreFrameDefaults("characterResistanceFrame", self.characterResistanceFrame);
	self:RestoreFrameDefaults("characterAmmoSlot", self.characterAmmoSlot);

	self.isApplied = false;
end

function PaperDollLayout:Refresh()
	self:RefreshFrameRefs();

	if not self.paperDollFrame then
		return;
	end

	self:RefreshSlotVisibility();
	self:RefreshModelLayout();
	self:RefreshAttributesLayout();
end

function PaperDollLayout:RefreshSlotVisibility()
	local ammoSlot = self.characterAmmoSlot;
	if not ammoSlot then
		return;
	end

	if self:ShouldShowAmmoSlot() then
		local defaults = self.defaults.characterAmmoSlot;
		ammoSlot:Show();
		ammoSlot:SetAlpha(defaults and defaults.alpha or 1);
	else
		ammoSlot:Hide();
	end
end

function PaperDollLayout:RefreshModelLayout()
	local modelFrame = self.characterModelFrame;
	if not modelFrame then
		return;
	end

	if not self:ShouldUseModelCentering() then
		self:RestoreFrameDefaults("characterModelFrame", modelFrame);
		return;
	end

	local profile = self:GetModelLayoutProfile();
	modelFrame:SetSize(profile.width, profile.height);

	if modelFrame.SetPosition then
		modelFrame:SetPosition(profile.positionX, profile.positionY, profile.positionZ);
	end
end

function PaperDollLayout:GetModelLayoutProfile()
	-- Settings may partially override DEFAULT_MODEL_LAYOUT; unset fields fallback to defaults.	
	local modelLayout = self.settings.paperDollModelLayout;

	return {
		width     = modelLayout and modelLayout.width     or DEFAULT_MODEL_LAYOUT.width,
		height    = modelLayout and modelLayout.height    or DEFAULT_MODEL_LAYOUT.height,
		positionX = modelLayout and modelLayout.positionX or DEFAULT_MODEL_LAYOUT.positionX,
		positionY = modelLayout and modelLayout.positionY or DEFAULT_MODEL_LAYOUT.positionY,
		positionZ = modelLayout and modelLayout.positionZ or DEFAULT_MODEL_LAYOUT.positionZ,
	};
end

-- Settings accessors.
--
function PaperDollLayout:ShouldUseModelCentering()
	return not self.settings or self.settings.useModelCentering ~= false;
end

function PaperDollLayout:ShouldHideCharacterAttributes()
	return self.settings and self.settings.hideCharacterAttributes == true;
end

function PaperDollLayout:ShouldFadeCharacterAttributes()
	return not self:ShouldHideCharacterAttributes()
		and self.settings.fadeCharacterAttributes == true;
end

function PaperDollLayout:ShouldShowAmmoSlot()
	return not self.settings or self.settings.showAmmoSlot ~= false;
end

function PaperDollLayout:GetAttributesFadedAlpha()
	return self.settings and self.settings.characterAttributesFadedAlpha or DEFAULT_FADED_ALPHA;
end

function PaperDollLayout:GetAttributesFadeDuration()
	return self.settings and self.settings.characterAttributesFadeDuration or DEFAULT_FADE_DURATION;
end

function PaperDollLayout:GetDefaultFrameAlpha(key, fallback)
	local defaults = self.defaults[key];
	if defaults and defaults.alpha ~= nil then
		return defaults.alpha;
	end

	return fallback or 1;
end

-- Attributes hover watcher.
--
function PaperDollLayout:CreateAttributesWatcher()
	if self.attributesWatcher or not self.paperDollFrame then
		return;
	end

	local watcher = CreateFrame("Frame", nil, self.paperDollFrame);
	watcher:Hide();
	watcher.elapsed = 0;

	watcher:SetScript("OnUpdate", function(frame, elapsed)
		frame.elapsed = frame.elapsed + elapsed;
		if frame.elapsed < HOVER_UPDATE_INTERVAL then
			return;
		end

		frame.elapsed = 0;
		self:UpdateAttributesHoverState();
	end);

	self.attributesWatcher = watcher;
end

function PaperDollLayout:SetAttributesWatcher(enabled)
	if enabled then
		self:CreateAttributesWatcher();
	end

	local watcher = self.attributesWatcher;
	if not watcher then
		return;
	end

	if enabled then
		watcher.elapsed = 0;
		watcher:Show();
		self:UpdateAttributesHoverState();
	else
		watcher:Hide();
		self.attributesHoverActive = false;
	end
end

function PaperDollLayout:UpdateAttributesHoverState()
	if not self.attributesFadeEnabled then
		return;
	end

	local isHovered = self:IsMouseOverAttributesRegion();
	if self.attributesHoverActive == isHovered then
		return;
	end

	self.attributesHoverActive = isHovered;

	if isHovered then
		self:RestoreAttributesRegionAlpha(false);
	else
		self:SetAttributesRegionAlpha(self:GetAttributesFadedAlpha(), false);
	end
end

function PaperDollLayout:RefreshAttributesLayout()
	local attributesFrame = self.characterAttributesFrame;
	local resistanceFrame = self.characterResistanceFrame;

	if not attributesFrame and not resistanceFrame then
		return;
	end

	if self:ShouldHideCharacterAttributes() then
		self.attributesFadeEnabled = false;
		self:SetAttributesWatcher(false);
		self:RestoreAttributesRegionAlpha(true);
		self:SetAttributesRegionShown(false);
		return;
	end

	if self:ShouldFadeCharacterAttributes() then
		self.attributesFadeEnabled = true;
		self:SetAttributesRegionShown(true);
		self:SetAttributesRegionAlpha(self:GetAttributesFadedAlpha(), true);
		self:SetAttributesWatcher(true);
		return;
	end

	self.attributesFadeEnabled = false;
	self:SetAttributesWatcher(false);
	self:SetAttributesRegionShown(true);
	self:RestoreAttributesRegionAlpha(true);
end

Engine.Modules.PaperDollLayout = PaperDollLayout;
