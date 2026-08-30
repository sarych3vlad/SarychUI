--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local Data = Engine.Shared.Data;
local EquipmentLayout = Engine.Modules.EquipmentLayout;

--@natives<lua>
local _G = _G;


---------------------------------------------------------------------------------------------------
-- EquipmentControllerMixin orchestrates slot data requests, features apply passes,
-- and PaperDoll integration. It requests resolved `slotData` from the DataProvider,
-- tracks slot state, and refresh feature widgets.
---------------------------------------------------------------------------------------------------

--@class EquipmentControllerMixin<frame>
local EquipmentControllerMixin = {};

function EquipmentControllerMixin:OnLoad(dataProvider, config)
	config = config or {};

	self.dataProvider = dataProvider;
	self.features = config.features or {};
	self.settings = config.settings;
	self.host = config.host or {};
	self.liveUpdates = config.liveUpdates ~= false;
	self.slotDataResolver = config.slotDataResolver;

	self.slots = {};
	self.trackedSlotIDs = {};
	self.widgets = {};

	self.isOpen = false;
	self.isDirty = true;
	self.hostFrameHooked = false;
	self.dataRevisionToken = 0;

	dataProvider:OnLoad();

	self:BuildSlotViews();
	self:CreateGlobalFeatureWidgets();

	self:SetPaperDollLayout(config.paperDollLayout);
	self:HookHostFrame();

	if self.liveUpdates then
		self:SetScript("OnEvent", self.OnEvent);
		self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
		self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	end
end

function EquipmentControllerMixin:OnEvent(event, ...)
	if self[event] then
		self[event](self, ...);
	end
end

function EquipmentControllerMixin:BuildSlotViews()
	local slotPrefix = self.host.slotPrefix or "Character";

	for index = 1, #Data.EquipmentSlots do
		local slotInfo = Data.EquipmentSlots[index];
		local button = _G[slotPrefix .. slotInfo.key .. "Slot"];

		if button then
			local slotView = {
				-- identity
				id       = slotInfo.id,
				slotInfo = slotInfo,

				-- layout
				side     = slotInfo.side,
				align    = slotInfo.align,
				growth   = slotInfo.growth,
				button   = button,

				-- tracking state
				revision   = 0,
				lastItemID = 0,

				-- inline layout
				inlineOffset = 0,
				widgets      = {},
			};

			for featureIndex = 1, #self.features do
				local feature = self.features[featureIndex];
				if feature.CreateSlotWidgets then
					feature:CreateSlotWidgets(self, slotView);
				end
			end

			self.slots[slotInfo.id] = slotView;

			if slotInfo.trackUpdates ~= false then
				self.trackedSlotIDs[#self.trackedSlotIDs + 1] = slotInfo.id;
			end
		end
	end
end

function EquipmentControllerMixin:CreateGlobalFeatureWidgets()
	for index = 1, #self.features do
		local feature = self.features[index];

		if feature.CreateGlobalWidgets then
			feature:CreateGlobalWidgets(self);
		end

		if feature.OnLoad then
			feature:OnLoad(self);
		end
	end
end


-------------------------------------------------------------------
-- Slot change detection
-------------------------------------------------------------------

function EquipmentControllerMixin:ShouldTrackSlot(slotID)
	local slotView = self.slots[slotID];
	if not slotView or not slotView.slotInfo then
		return false;
	end

	return slotView.slotInfo.trackUpdates ~= false;
end

function EquipmentControllerMixin:ShouldTrackSocketLayout(slotView)
	local slotInfo = slotView and slotView.slotInfo;
	return slotInfo and slotInfo.trackSocketLayout == true;
end

function EquipmentControllerMixin:HasSlotChanged(slotView)
	local slotID = slotView.id;
	local currentItemID = self.dataProvider:GetCurrentItemID(slotID);

	if slotView.lastItemID ~= currentItemID then
		return true;
	end

	if currentItemID and currentItemID > 0 then
		local currentItemToken = self.dataProvider:GetCurrentItemToken(slotID);
		if slotView.lastItemToken ~= currentItemToken then
			return true;
		end

		if self:ShouldTrackSocketLayout(slotView) then
			local currentSocketSignature = self.dataProvider:GetCurrentSocketSignature(slotID);
			if slotView.lastSocketSignature ~= currentSocketSignature then
				return true;
			end
		end
	end

	return false;
end

function EquipmentControllerMixin:PLAYER_EQUIPMENT_CHANGED(slotID)
	if not slotID or not self:ShouldTrackSlot(slotID) then
		return;
	end

	if self.isOpen then
		self:RefreshSlot(slotID);
	else
		self.isDirty = true;
	end
end

function EquipmentControllerMixin:UNIT_INVENTORY_CHANGED(unit)
	if unit ~= self.dataProvider:GetUnit() then
		return;
	end

	if not self.isOpen then
		self.isDirty = true;
		return;
	end

	self:RefreshChangedSlots();
end

-------------------------------------------------------------------
-- PaperDoll Layout integration
-------------------------------------------------------------------

function EquipmentControllerMixin:SetPaperDollLayout(layout)
	self.paperDollLayout = layout;

	if self.paperDollLayout and self.paperDollLayout.OnLoad then
		self.paperDollLayout:OnLoad(self);
	end
end

function EquipmentControllerMixin:ApplyPaperDollLayout()
	if self.paperDollLayout and self.paperDollLayout.Apply then
		self.paperDollLayout:Apply(self);
	end
end

function EquipmentControllerMixin:RefreshPaperDollLayout()
	if self.paperDollLayout and self.paperDollLayout.Refresh then
		self.paperDollLayout:Refresh(self);
	end
end

function EquipmentControllerMixin:NotifyPaperDollHidden()
	if self.paperDollLayout and self.paperDollLayout.OnHide then
		self.paperDollLayout:OnHide(self);
	end
end

function EquipmentControllerMixin:HookHostFrame()
	local hostFrame = self.host.frame;
	if self.hostFrameHooked or not hostFrame then
		return;
	end

	self.hostFrameHooked = true;

	hostFrame:HookScript("OnShow", function()
		self.isOpen = true;
		self:ApplyPaperDollLayout();

		if self.isDirty then
			self:Refresh();
		else
			self:RefreshDisplay();
		end

		self:RefreshPaperDollLayout();
	end);

	hostFrame:HookScript("OnHide", function()
		self.isOpen = false;
		self:NotifyPaperDollHidden();
	end);
end

-------------------------------------------------------------------
-- Inline widget layout
-------------------------------------------------------------------

function EquipmentControllerMixin:CreateInlineIconFrame(slotView, size)
	return EquipmentLayout:CreateInlineIconFrame(self, slotView, size);
end

function EquipmentControllerMixin:LayoutInlineIconFrame(slotView, frame, size)
	EquipmentLayout:LayoutInlineIconFrame(self, slotView, frame, size);
end

function EquipmentControllerMixin:UpdateInlineWidgetLayout(slotView)
	local inlineFrames = slotView.widgets.inlineFrames;
	if not inlineFrames then
		return;
	end

	slotView.inlineOffset = 0;

	for index = 1, #inlineFrames do
		local frame = inlineFrames[index];
		if frame and frame:IsShown() then
			self:LayoutInlineIconFrame(slotView, frame, frame:GetWidth());
		end
	end
end

-------------------------------------------------------------------
-- Refresh pipeline
-------------------------------------------------------------------

function EquipmentControllerMixin:MakeDirty()
	self.isDirty = true;
end

function EquipmentControllerMixin:CommitSlotData(slotView, slotData)
	if not slotData then
		slotView.lastItemID = 0;
		slotView.lastItemToken = nil;
		slotView.lastSocketSignature = nil;
		slotView.lastSlotData = nil;
		return;
	end

	slotView.lastItemID = slotData.itemID or 0;
	slotView.lastItemToken = slotData.itemToken;
	slotView.lastSocketSignature = slotData.socketData.signature;
	slotView.lastSlotData = slotData;
end

function EquipmentControllerMixin:ClearSlot(slotView)
	for index = 1, #self.features do
		local feature = self.features[index];
		if feature.ClearSlot then
			feature:ClearSlot(self, slotView);
		end
	end
end

function EquipmentControllerMixin:ApplyFeatureSummaries()
	for index = 1, #self.features do
		local feature = self.features[index];
		if feature.ApplySummary then
			feature:ApplySummary(self);
		end
	end
end

function EquipmentControllerMixin:ApplySlotData(slotView, slotData, suppressSummaryUpdate)
	self:CommitSlotData(slotView, slotData);

	for index = 1, #self.features do
		local feature = self.features[index];
		if feature.ApplySlotData then
			feature:ApplySlotData(self, slotView, slotData);
		end
	end

	self:UpdateInlineWidgetLayout(slotView);

	if not suppressSummaryUpdate then
		self:ApplyFeatureSummaries();
	end
end

function EquipmentControllerMixin:Refresh()
	self:RefreshAll();
	self.isDirty = false;
end

-- Refresh visuals from cached slot data without requesting new data.
function EquipmentControllerMixin:RefreshDisplay()
	for index = 1, #self.trackedSlotIDs do
		local slotID = self.trackedSlotIDs[index];
		local slotView = self.slots[slotID];

		if slotView then
			self:ClearSlot(slotView);
			self:ApplySlotData(slotView, slotView.lastSlotData, true);
		end
	end

	self:ApplyFeatureSummaries();
end

function EquipmentControllerMixin:ResolveSlotData(slotID, callback)
	if type(self.slotDataResolver) == "function" then
		self.slotDataResolver(self, slotID, callback);
		return;
	end

	self.dataProvider:RequestSlotData(slotID, callback);
end

function EquipmentControllerMixin:SetDataRevisionToken(token)
	self.dataRevisionToken = token or 0;
end

function EquipmentControllerMixin:SetSnapshot(snapshot, dataRevisionToken)
	self.snapshot = snapshot;

	if dataRevisionToken ~= nil then
		self:SetDataRevisionToken(dataRevisionToken);
	end

	self:MakeDirty();

	if self.isOpen then
		self:Refresh();
	end
end

function EquipmentControllerMixin:ClearSnapshot(dataRevisionToken)
	self.snapshot = nil;

	if dataRevisionToken ~= nil then
		self:SetDataRevisionToken(dataRevisionToken);
	end

	self:MakeDirty();

	if self.isOpen then
		self:Refresh();
	end
end

function EquipmentControllerMixin:SetUnit(unit)
	unit = unit or "player";

	if self.dataProvider:GetUnit() == unit then
		return;
	end

	self.dataProvider:SetUnit(unit);
	self:MakeDirty();

	if self.isOpen then
		self:Refresh();
	end
end

function EquipmentControllerMixin:RefreshAll()
	for index = 1, #self.trackedSlotIDs do
		self:RefreshSlot(self.trackedSlotIDs[index]);
	end
end

function EquipmentControllerMixin:RefreshChangedSlots()
	for index = 1, #self.trackedSlotIDs do
		local slotID = self.trackedSlotIDs[index];
		local slotView = self.slots[slotID];

		if slotView and self:HasSlotChanged(slotView) then
			self:RefreshSlot(slotID);
		end
	end
end

function EquipmentControllerMixin:RefreshSlot(slotID)
	local slotView = self.slots[slotID];
	if not slotView then
		return;
	end

	slotView.revision = slotView.revision + 1;
	local revision = slotView.revision;
	local dataRevisionToken = self.dataRevisionToken;

	self:ClearSlot(slotView);

	self:ResolveSlotData(slotID, function(slotData)
		-- Discard stale async callbacks.
		if slotView.revision ~= revision or self.dataRevisionToken ~= dataRevisionToken then
			return;
		end

		self:ApplySlotData(slotView, slotData);
	end);
end

Engine.Modules.EquipmentControllerMixin = EquipmentControllerMixin;
