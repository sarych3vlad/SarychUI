--[[
    Equipence
    Copyright (c) 2026 s0high. All rights reserved.

    Source-available proprietary software. See LICENSE for terms.
]]

--@class Engine<ns>
local Engine = select(2, ...);
local Aegis = Engine.Aegis;

--@natives<lua,wow>
local _G = _G;
local CreateFrame = CreateFrame;
local CharacterModelFrame = CharacterModelFrame;
local CharacterModelScene = CharacterModelScene;
local PaperDollFrame = PaperDollFrame;

Engine.Controllers = Engine.Controllers or {};

function Engine.Controllers:GetFeatures()
	if self.features then
		return self.features;
	end

	self.features = {
		Engine.Modules.EnchantsFeatureMixin,
		Engine.Modules.GemsFeatureMixin,
		Engine.Modules.ItemQualityFeatureMixin,
		Engine.Modules.ItemLevelsFeatureMixin,
	};

	return self.features;
end

function Engine.Controllers:GetCharacterHost()
	return {
		frame = PaperDollFrame,
		slotPrefix = "Character",
		summaryAnchor = PaperDollFrame,
		paperDollLayout = nil,
	};
end

function Engine.Controllers:GetInspectHost()
	local headSlot = _G.InspectHeadSlot;
	local frame = _G.InspectFrame or _G.InspectPaperDollFrame;
	if not frame or not headSlot then
		return nil;
	end

	local paperDollFrame = _G.InspectPaperDollFrame or headSlot:GetParent() or frame;

	return {
		frame = frame,
		slotPrefix = "Inspect",
		summaryAnchor = paperDollFrame,
		paperDollLayout = nil,
	};
end

function Engine.Controllers:Init()
	local modules = Engine.Modules;
	local settings = Engine.Settings;
	local features = self:GetFeatures();
	local characterHost = self:GetCharacterHost();

	local paperDollLayout = Aegis:CreateFromMixins(modules.PaperDollLayout);
	local dataProvider = Aegis:CreateFromMixins(modules.DataProviderMixin);
	dataProvider:SetUnit("player");

	local equipmentController = CreateFrame("Frame");
	Aegis:Mixin(equipmentController, modules.EquipmentControllerMixin);

	equipmentController:OnLoad(dataProvider, {
		host = characterHost,
		settings = settings,
		features = features,
		paperDollLayout = paperDollLayout,
		liveUpdates = true,
	});

	local inspectionController = CreateFrame("Frame");
	Aegis:Mixin(inspectionController, modules.InspectionControllerMixin);

	inspectionController:OnLoad({
		features = features,
		settings = settings,
		dataProviderMixin = modules.DataProviderMixin,
		equipmentControllerMixin = modules.EquipmentControllerMixin,
	});

	--@export<ns>
	self.DataProvider = dataProvider;
	self.CharacterController = equipmentController;
	self.InspectionController = inspectionController;

	local environment = Aegis:GetService("Environment");
	if environment then
		environment:SetDebugWarningsEnabled(Engine.Debug);
	end
end
