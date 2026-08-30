--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);

--@imports<ns>
local Aegis = Engine.Aegis;
local Data = Engine.Shared.Data;
local Controllers = Engine.Controllers;
local C_AddOns = Aegis:GetNamespace("C_AddOns");
local LinkUtil = Aegis:GetNamespace("LinkUtil");

--@natives<lua,wow>
local _G = _G;
local CreateFrame = CreateFrame;
local GetInventoryItemLink = GetInventoryItemLink;
local GetTime = GetTime;
local NotifyInspect = NotifyInspect;
local CanInspect = CanInspect;
local CheckInteractDistance = CheckInteractDistance;
local ClearInspectPlayer = ClearInspectPlayer;
local UnitExists = UnitExists;
local UnitGUID = UnitGUID;
local pcall = pcall;
local type = type;

---------------------------------------------------------------------------------------------------
-- InspectionControllerMixin owns inspect host, throttled `NotifyInspect` requests,
-- and immutable per-session equipment snapshots for the inspect equipment controller.
---------------------------------------------------------------------------------------------------

--@constants
local INSPECT_UI_ADDON = "Blizzard_InspectUI";
local WATCH_INTERVAL = 0.2;
local SNAPSHOT_POLL_DELAY = 0.4;
local SNAPSHOT_TIMEOUT = 3.0;

--@class InspectionControllerMixin<frame>
local InspectionControllerMixin = {};

local function GetFrameUnitToken(frame)
	if not frame then
		return nil;
	end

	local unitToken = frame.unit or frame.unitToken or frame.inspectUnit;
	if type(unitToken) == "string" and unitToken ~= "" then
		return unitToken;
	end

	return nil;
end

local function GetUnitTokenGUID(unitToken)
	if not unitToken or not UnitGUID then
		return nil;
	end

	return UnitGUID(unitToken);
end

local function TryRegisterEvent(frame, eventName)
	return pcall(frame.RegisterEvent, frame, eventName) == true;
end

local function ResolveSnapshotSlotData(targetController, slotID, callback)
	local snapshot = targetController.snapshot;
	local slotSnapshot = snapshot and snapshot.slots and snapshot.slots[slotID];
	if not slotSnapshot or not slotSnapshot.itemLink then
		callback(nil);
		return;
	end

	targetController.dataProvider:RequestSlotDataFromLink(
		slotID,
		slotSnapshot.itemLink,
		slotSnapshot.itemToken,
		callback
	);
end

function InspectionControllerMixin:OnLoad(config)
	-- configuration ---
	self.dataProviderMixin = config.dataProviderMixin;
	self.equipmentControllerMixin = config.equipmentControllerMixin;
	self.features = config.features;
	self.settings = config.settings;
	self.notifyInterval = config.notifyInterval or 1.0;

	self.controller = nil;
	self.dataProvider = nil;
	self.host = nil;

	self.inspectHostInitialized = false;
	self.inspectFrameHooked = false;
	self.isWatching = false;
	self.watchElapsed = 0;

	self.sessionRevision = 0;
	self.lastNotifyTime = 0;

	self.currentObservedGUID = nil;
	self.currentObservedUnitToken = nil;

	self.desiredGUID = nil;
	self.desiredUnitToken = nil;

	self.pendingGUID = nil;
	self.pendingUnitToken = nil;
	self.pendingSessionRevision = nil;
	self.pendingStartTime = nil;

	self.appliedGUID = nil;
	self.appliedUnitToken = nil;

	self:SetScript("OnEvent", self.OnEvent);
	self:RegisterSupportedEvent("ADDON_LOADED");
	self:RegisterSupportedEvent("INSPECT_READY");
	self:RegisterSupportedEvent("INSPECT_TALENT_READY");
	self:RegisterSupportedEvent("UNIT_INVENTORY_CHANGED");

	-- Attach to an existing inspect host only. If none exists yet, `ADDON_LOADED`
	-- will retry after Blizzard or a custom replacement creates the frame tree.
	self:TryInitializeInspectHost();
end

function InspectionControllerMixin:CreateEquipmentController(host)
	if not self.dataProviderMixin or not self.equipmentControllerMixin then
		return nil, nil;
	end

	-- Inspect runs on immutable snapshots, so it keeps its own controller/data provider
	-- instead of sharing player live state and revision tracking.
	local dataProvider = Aegis:CreateFromMixins(self.dataProviderMixin);
	local controller = CreateFrame("Frame");
	Aegis:Mixin(controller, self.equipmentControllerMixin);

	controller:OnLoad(dataProvider, {
		host = host,
		settings = self.settings,
		features = self.features,
		liveUpdates = false,
		slotDataResolver = ResolveSnapshotSlotData,
	});

	Controllers.InspectDataProvider = dataProvider;
	Controllers.InspectController = controller;

	return controller, dataProvider;
end

function InspectionControllerMixin:OnEvent(event, ...)
	if self[event] then
		self[event](self, ...);
	end
end

function InspectionControllerMixin:RegisterSupportedEvent(eventName)
	TryRegisterEvent(self, eventName);
end

function InspectionControllerMixin:TryInitializeInspectHost()
	if self.inspectHostInitialized then
		return true;
	end

	local host = Controllers:GetInspectHost();
	if not host then
		return false;
	end

	local controller, dataProvider = self:CreateEquipmentController(host);
	if not controller then
		return false;
	end

	self.controller = controller;
	self.dataProvider = dataProvider;
	self.host = host;
	self.inspectHostInitialized = true;

	self:HookInspectFrame(host.frame);

	if host.frame:IsShown() then
		self:OnInspectFrameShown();
	end

	return true;
end

function InspectionControllerMixin:AdvanceSession()
	self.sessionRevision = self.sessionRevision + 1;
	return self.sessionRevision;
end

function InspectionControllerMixin:HookInspectFrame(frame)
	if self.inspectFrameHooked or not frame then
		return;
	end

	self.inspectFrameHooked = true;

	frame:HookScript("OnShow", function()
		self:OnInspectFrameShown();
	end);

	frame:HookScript("OnHide", function()
		self:OnInspectFrameHidden();
	end);
end

function InspectionControllerMixin:GetInspectUnitToken()
	local inspectFrame = _G.InspectFrame or (self.host and self.host.frame);
	local unitToken = GetFrameUnitToken(inspectFrame);

	if unitToken then
		return unitToken;
	end

	if UnitExists("target") then
		return "target";
	end

	return nil;
end

function InspectionControllerMixin:SetWatchEnabled(enabled)
	if enabled then
		if self.isWatching then
			return;
		end

		self.isWatching = true;
		self.watchElapsed = 0;
		self:SetScript("OnUpdate", self.OnUpdate);
		return;
	end

	if not self.isWatching then
		return;
	end

	self.isWatching = false;
	self.watchElapsed = 0;
	self:SetScript("OnUpdate", nil);
end

function InspectionControllerMixin:OnUpdate(elapsed)
	self.watchElapsed = self.watchElapsed + elapsed;
	if self.watchElapsed < WATCH_INTERVAL then
		return;
	end

	self.watchElapsed = 0;
	self:RefreshInspectUnit();
	self:TrySendInspectRequest();
	self:TryBuildPendingSnapshot();
end

function InspectionControllerMixin:OnInspectFrameShown()
	self:SetWatchEnabled(true);
	self:RefreshInspectUnit(true);
end

function InspectionControllerMixin:ClearInspectState()
	self.currentObservedGUID = nil;
	self.currentObservedUnitToken = nil;

	self.desiredGUID = nil;
	self.desiredUnitToken = nil;

	self.pendingGUID = nil;
	self.pendingUnitToken = nil;
	self.pendingSessionRevision = nil;
	self.pendingStartTime = nil;

	self.appliedGUID = nil;
	self.appliedUnitToken = nil;
end

function InspectionControllerMixin:OnInspectFrameHidden()
	self:SetWatchEnabled(false);
	self:ClearInspectState();
	self:AdvanceSession();

	if self.controller then
		self.controller:ClearSnapshot(self.sessionRevision);
	end

	ClearInspectPlayer();
end

function InspectionControllerMixin:SetDesiredInspectUnit(unitToken, guid)
	if not unitToken or not guid then
		return;
	end

	if self.desiredGUID == guid and self.desiredUnitToken == unitToken then
		return;
	end

	self.desiredGUID = guid;
	self.desiredUnitToken = unitToken;
	self.pendingGUID = nil;
	self.pendingUnitToken = nil;
	self.pendingSessionRevision = nil;
	self.pendingStartTime = nil;
	self.appliedGUID = nil;
	self.appliedUnitToken = nil;

	self:AdvanceSession();

	if self.controller then
		self.controller:SetDataRevisionToken(self.sessionRevision);
	end
end

function InspectionControllerMixin:RefreshInspectUnit(force)
	if not self.inspectHostInitialized then
		return;
	end

	local unitToken = self:GetInspectUnitToken();
	if not unitToken or not UnitExists(unitToken) then
		return;
	end

	-- !`UnitGUID` Added in 2.4.0
	local guid = GetUnitTokenGUID(unitToken);
	if not guid then
		return;
	end

	if not force and self.currentObservedGUID == guid and self.currentObservedUnitToken == unitToken then
		return;
	end

	self.currentObservedGUID = guid;
	self.currentObservedUnitToken = unitToken;

	self:SetDesiredInspectUnit(unitToken, guid);
	self:TrySendInspectRequest();
end

function InspectionControllerMixin:CanSendInspectRequest()
	if not self.desiredGUID or not self.desiredUnitToken then
		return false;
	end

	if not CanInspect(self.desiredUnitToken) then
		return false;
	end

	if not CheckInteractDistance(self.desiredUnitToken, 1) then
		return false;
	end

	if GetUnitTokenGUID(self.desiredUnitToken) ~= self.desiredGUID then
		return false;
	end

	if self.pendingGUID == self.desiredGUID and self.pendingUnitToken == self.desiredUnitToken then
		return false;
	end

	if self.appliedGUID == self.desiredGUID and self.appliedUnitToken == self.desiredUnitToken then
		return false;
	end

	return (GetTime() - self.lastNotifyTime) >= self.notifyInterval;
end

function InspectionControllerMixin:TrySendInspectRequest()
	if not self:CanSendInspectRequest() then
		return;
	end

	NotifyInspect(self.desiredUnitToken);

	self.lastNotifyTime = GetTime();
	self.pendingGUID = self.desiredGUID;
	self.pendingUnitToken = self.desiredUnitToken;
	self.pendingSessionRevision = self.sessionRevision;
	self.pendingStartTime = self.lastNotifyTime;
end

function InspectionControllerMixin:BuildSnapshot(unitToken, guid, sessionRevision)
	local slots = {};
	local linkCount = 0;

	for index = 1, #Data.EquipmentSlots do
		local slotInfo = Data.EquipmentSlots[index];
		local itemLink = GetInventoryItemLink(unitToken, slotInfo.id);
		if itemLink then
			linkCount = linkCount + 1;
		end

		slots[slotInfo.id] = {
			itemLink = itemLink,
			itemToken = LinkUtil.GetItemStringFromLink(itemLink),
		};
	end

	return {
		guid = guid,
		unitToken = unitToken,
		sessionRevision = sessionRevision,
		slots = slots,
	}, linkCount;
end

function InspectionControllerMixin:ClearPendingRequest()
	self.pendingGUID = nil;
	self.pendingUnitToken = nil;
	self.pendingSessionRevision = nil;
	self.pendingStartTime = nil;
end

function InspectionControllerMixin:ApplySnapshot(snapshot)
	self:ClearPendingRequest();
	self.appliedGUID = snapshot.guid;
	self.appliedUnitToken = snapshot.unitToken;

	if self.controller then
		self.controller:SetSnapshot(snapshot, snapshot.sessionRevision);
	end
end

function InspectionControllerMixin:TryBuildPendingSnapshot(force)
	if not self.pendingGUID or not self.pendingUnitToken or not self.pendingStartTime then
		return false;
	end

	-- Some legacy branches only deliver inventory state through delayed updates, so
	-- poll links briefly after NotifyInspect and stop once the snapshot is populated.
	local elapsed = GetTime() - self.pendingStartTime;
	if not force and elapsed < SNAPSHOT_POLL_DELAY then
		return false;
	end

	if GetUnitTokenGUID(self.pendingUnitToken) ~= self.pendingGUID then
		self:ClearPendingRequest();
		return false;
	end

	local snapshot, linkCount = self:BuildSnapshot(self.pendingUnitToken, self.pendingGUID, self.pendingSessionRevision or self.sessionRevision);
	if linkCount and linkCount > 0 then
		self:ApplySnapshot(snapshot);
		return true;
	end

	if elapsed >= SNAPSHOT_TIMEOUT then
		self:ClearPendingRequest();
	end

	return false;
end

function InspectionControllerMixin:TryBuildDesiredSnapshot()
	if not self.desiredGUID or not self.desiredUnitToken then
		return false;
	end

	if GetUnitTokenGUID(self.desiredUnitToken) ~= self.desiredGUID then
		return false;
	end

	local snapshot, linkCount = self:BuildSnapshot(self.desiredUnitToken, self.desiredGUID, self.pendingSessionRevision or self.sessionRevision);
	if linkCount and linkCount > 0 then
		self:ApplySnapshot(snapshot);
		return true;
	end

	return false;
end

function InspectionControllerMixin:OnInspectDataReady(guid)
	if not self.inspectHostInitialized then
		return;
	end

	if not self.desiredGUID then
		self:RefreshInspectUnit(true);
	end

	guid = guid or (self.desiredUnitToken and GetUnitTokenGUID(self.desiredUnitToken));
	if not guid or guid ~= self.desiredGUID then
		return;
	end

	if self.pendingGUID and guid ~= self.pendingGUID then
		return;
	end

	local unitToken = self.desiredUnitToken;
	if not unitToken or (GetUnitTokenGUID(unitToken) ~= guid) then
		return;
	end

	local snapshot, linkCount = self:BuildSnapshot(unitToken, guid, self.pendingSessionRevision or self.sessionRevision);
	if linkCount and linkCount > 0 then
		self:ApplySnapshot(snapshot);
	end
end

function InspectionControllerMixin:INSPECT_READY(guid)
	self:OnInspectDataReady(guid);
end

function InspectionControllerMixin:INSPECT_TALENT_READY(guid)
	self:OnInspectDataReady(guid);
end

function InspectionControllerMixin:UNIT_INVENTORY_CHANGED(unitToken)
	if not self.inspectHostInitialized then
		return;
	end

	if unitToken ~= self.desiredUnitToken and unitToken ~= self.pendingUnitToken then
		return;
	end

	if not self:TryBuildPendingSnapshot(true) then
		self:TryBuildDesiredSnapshot();
	end
end

function InspectionControllerMixin:ADDON_LOADED()
	if self.inspectHostInitialized then
		return;
	end

	self:TryInitializeInspectHost();
end

Engine.Modules.InspectionControllerMixin = InspectionControllerMixin;
