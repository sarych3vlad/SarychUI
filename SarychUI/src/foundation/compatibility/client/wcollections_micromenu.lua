-- WCollections injects CollectionsMicroButton into the micromenu and then
-- re-anchors every stock micro button — even when its option is "None".
-- That breaks SarychUI Classic BFA and the regular action bars. SarychUI
-- owns the micromenu layout; keep WCollections off it regardless of its UI.

local CORE_MICRO_BUTTONS = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"AchievementMicroButton",
	"QuestLogMicroButton",
	"SocialsMicroButton",
	"PVPMicroButton",
	"LFDMicroButton",
	"MainMenuMicroButton",
	"HelpMicroButton",
}

local installed
local neutralizing

local function IsWCollectionsBarAnchor(point, relativeTo, relativePoint, x, y)
	if point ~= "BOTTOMLEFT" then
		return false
	end
	local rel = type(relativeTo) == "string" and _G[relativeTo] or relativeTo
	if rel ~= MainMenuBarArtFrame then
		return false
	end
	if relativePoint ~= "BOTTOMLEFT" and relativePoint ~= point then
		return false
	end
	return (x == 545 or x == 552) and y == 2
end

local function HideCollectionsMicroButton()
	local button = _G.CollectionsMicroButton
	if button then
		if button.Hide then
			button:Hide()
		end
		if button.SetScript then
			button:SetScript("OnShow", button.Hide)
		end
	end
	local alert = _G.CollectionsMicroButtonAlert
	if alert then
		if alert.Hide then
			alert:Hide()
		end
		if alert.SetScript then
			alert:SetScript("OnShow", alert.Hide)
		end
	end
end

local function ForceWCollectionsNoMicroOption()
	local wardrobe = _G.WCollections and _G.WCollections.Config and _G.WCollections.Config.Wardrobe
	if wardrobe then
		wardrobe.MicroButtonsOption = 1
	end
end

local function RestoreSarychUIMicroLayout()
	local mmb = SarychUI and SarychUI.modules and SarychUI.modules.mainmenubar
	if not (mmb and mmb.BFAStyle and mmb.BFAStyle.active) then
		return
	end
	if mmb.BFAStyle.ApplyPlayerLayout then
		mmb.BFAStyle:ApplyPlayerLayout()
	end
end

local function ShowCoreMicroButtons()
	if UnitHasVehicleUI and UnitHasVehicleUI("player") then
		return
	end
	for i = 1, #CORE_MICRO_BUTTONS do
		local button = _G[CORE_MICRO_BUTTONS[i]]
		if button and button.Show and not button:IsShown() then
			button:Show()
		end
	end
end

local function RelinkIfAnchoredToCollections()
	local collections = _G.CollectionsMicroButton
	if not collections then
		return
	end
	local previous
	for i = 1, #CORE_MICRO_BUTTONS do
		local button = _G[CORE_MICRO_BUTTONS[i]]
		if button and button.GetPoint then
			local _, relativeTo = button:GetPoint(1)
			if relativeTo == collections and previous and button.ClearAllPoints then
				button:ClearAllPoints()
				button:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", -3, 0)
			end
			previous = button
		end
	end
end

local function NeutralizeWCollectionsMicro()
	if neutralizing then
		return
	end
	neutralizing = true
	ForceWCollectionsNoMicroOption()
	HideCollectionsMicroButton()
	ShowCoreMicroButtons()
	RelinkIfAnchoredToCollections()
	RestoreSarychUIMicroLayout()
	HideCollectionsMicroButton()
	neutralizing = false
end

local function WrapCollectionsShow(button)
	if not button or button._suiWColHideWrap then
		return
	end
	button._suiWColHideWrap = true
	local hide = button.Hide
	if type(hide) == "function" then
		button.Show = function(self)
			hide(self)
		end
	end
end

local function WrapMicroSetPoint(button)
	if not button or button._suiWColPointWrap or type(button.SetPoint) ~= "function" then
		return
	end
	button._suiWColPointWrap = true
	local orig = button.SetPoint
	button.SetPoint = function(self, point, relativeTo, relativePoint, x, y)
		if neutralizing then
			return orig(self, point, relativeTo, relativePoint, x, y)
		end
		local collections = _G.CollectionsMicroButton
		local rel = type(relativeTo) == "string" and _G[relativeTo] or relativeTo
		if collections and (self == collections or rel == collections) then
			return
		end
		if self == CharacterMicroButton and IsWCollectionsBarAnchor(point, relativeTo, relativePoint, x, y) then
			return
		end
		return orig(self, point, relativeTo, relativePoint, x, y)
	end
end

local function InstallWCollectionsMicroBlock()
	if installed then
		NeutralizeWCollectionsMicro()
		return
	end
	if not _G.CollectionsMicroButton and not (_G.WCollections and _G.WCollections.Config) then
		return
	end
	installed = true

	WrapCollectionsShow(_G.CollectionsMicroButton)
	WrapCollectionsShow(_G.CollectionsMicroButtonAlert)
	WrapMicroSetPoint(_G.CharacterMicroButton)
	for i = 1, #CORE_MICRO_BUTTONS do
		WrapMicroSetPoint(_G[CORE_MICRO_BUTTONS[i]])
	end
	WrapMicroSetPoint(_G.CollectionsMicroButton)

	if hooksecurefunc and UpdateMicroButtons then
		hooksecurefunc("UpdateMicroButtons", NeutralizeWCollectionsMicro)
	end
	if hooksecurefunc and VehicleMenuBar_MoveMicroButtons then
		hooksecurefunc("VehicleMenuBar_MoveMicroButtons", NeutralizeWCollectionsMicro)
	end

	local collections = _G.CollectionsMicroButton
	if collections and collections.HookScript then
		collections:HookScript("OnEvent", NeutralizeWCollectionsMicro)
	end

	ForceWCollectionsNoMicroOption()
	if collections and collections.GetScript then
		local onEvent = collections:GetScript("OnEvent")
		if type(onEvent) == "function" then
			pcall(onEvent, collections, "UPDATE_BINDINGS")
		end
	end
	NeutralizeWCollectionsMicro()
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" then
		if addonName == "WCollections" or addonName == "wCollections" or addonName == "SarychUI" then
			InstallWCollectionsMicroBlock()
		end
		return
	end
	InstallWCollectionsMicroBlock()
	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
end)

InstallWCollectionsMicroBlock()
