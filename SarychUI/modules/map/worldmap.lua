-- SarychUI Maps: world map presentation.
--
-- This is the part that gives the map its look: the frame is detached from the
-- UI panel system, made movable and scalable, the maximised and windowed
-- layouts are rebuilt, the Blizzard quest-objectives checkbox is replaced with a
-- dropdown and the surrounding artwork can be faded out. The layout numbers come
-- from Mapster, so the result matches the map SarychUI shipped before.

local Maps = SarychUI.Maps
local Api = Maps.Api
local L = SarychUI.L

local LibWindow = LibStub("LibWindow-1.1")

local worldmap = Maps:RegisterComponent("worldmap", {})

local QUEST_OBJECTIVE_DROPDOWN = "SarychUIMapQuestObjectivesDropDown"

local elementsToHide = {}
worldmap.elementsToHide = elementsToHide

local realZone
local savedBattlefieldOnUpdate
local hooksInstalled = false

local function zoneKey()
	return GetCurrentMapZone() + GetCurrentMapContinent() * 100
end

----------------------------------------------------------------------
-- Simple appliers
----------------------------------------------------------------------

function worldmap:SetStrata()
	WorldMapFrame:SetFrameStrata(Maps:Get("strata") or "HIGH")
	-- SetFrameStrata cascades into children, which would drag the map tooltips
	-- down behind the map artwork.
	for _, tip in ipairs({ WorldMapTooltip, WorldMapCompareTooltip1, WorldMapCompareTooltip2 }) do
		if tip then
			tip:SetFrameStrata("TOOLTIP")
		end
	end
end

function worldmap:SetAlpha()
	WorldMapFrame:SetAlpha(Maps:Get("alpha") or 1)
end

----------------------------------------------------------------------
-- Fade while moving (Leatrix Maps CheckMovement)
----------------------------------------------------------------------

local fadeTicker
local fadeFrame

local function setBlobAlpha(mult)
	if not WorldMapBlobFrame then
		return
	end
	mult = mult or 1
	if WorldMapBlobFrame.SetFillAlpha then
		WorldMapBlobFrame:SetFillAlpha(128 * mult)
	end
	if WorldMapBlobFrame.SetBorderAlpha then
		WorldMapBlobFrame:SetBorderAlpha(192 * mult)
	end
end

-- Same loop as Leatrix_Maps: every 0.2s, fade the whole WorldMapFrame over 0.3s
-- from the current alpha to moving/stationary opacity. Quest blobs are faded
-- separately because they do not inherit the frame alpha.
local function checkMovement()
	if not Maps:IsActive() or not WorldMapFrame:IsShown() then
		return
	end
	if Maps:Get("fadeOnMove") == false then
		return
	end
	local baseAlpha = Maps:Get("alpha") or 1
	local targetAlpha = Maps:Get("movingAlpha") or 0.4
	local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
	if speed ~= 0 and not WorldMapFrame:IsMouseOver() then
		if UIFrameFadeOut then
			UIFrameFadeOut(WorldMapFrame, 0.3, WorldMapFrame:GetAlpha(), targetAlpha)
		else
			WorldMapFrame:SetAlpha(targetAlpha)
		end
		setBlobAlpha(targetAlpha)
	else
		if UIFrameFadeIn then
			UIFrameFadeIn(WorldMapFrame, 0.3, WorldMapFrame:GetAlpha(), baseAlpha)
		else
			WorldMapFrame:SetAlpha(baseAlpha)
		end
		setBlobAlpha(1)
	end
end

function worldmap:StartFadeWatch()
	if not WorldMapFrame:IsShown() or Maps:Get("fadeOnMove") == false then
		self:StopFadeWatch()
		return
	end
	if fadeTicker or (fadeFrame and fadeFrame:GetScript("OnUpdate")) then
		return
	end
	if C_Timer and C_Timer.NewTicker then
		fadeTicker = C_Timer.NewTicker(0.2, checkMovement)
	else
		if not fadeFrame then
			fadeFrame = CreateFrame("Frame")
		end
		fadeFrame.elapsed = 0
		fadeFrame:SetScript("OnUpdate", function(self, elapsed)
			self.elapsed = self.elapsed + elapsed
			if self.elapsed < 0.2 then
				return
			end
			self.elapsed = 0
			checkMovement()
		end)
	end
	checkMovement()
end

function worldmap:StopFadeWatch()
	if fadeTicker then
		if fadeTicker.Cancel then
			fadeTicker:Cancel()
		end
		fadeTicker = nil
	end
	if fadeFrame then
		fadeFrame:SetScript("OnUpdate", nil)
	end
	if UIFrameFadeRemoveFrame then
		UIFrameFadeRemoveFrame(WorldMapFrame)
	end
end

function worldmap:SetScale()
	if Maps:Get("resetLayout") then
		WorldMapFrame:SetScale(1)
		return
	end
	WorldMapFrame:SetScale(Maps:Get("scale") or 1)
end

function worldmap:SetPosition()
	if Maps:Get("resetLayout") then
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		return
	end
	LibWindow.RestorePosition(WorldMapFrame)
end

function worldmap:SetArrow()
	local scale = Maps:Get("arrowScale") or 0.88
	if PlayerArrowFrame then PlayerArrowFrame:SetModelScale(scale) end
	if PlayerArrowEffectFrame then PlayerArrowEffectFrame:SetModelScale(scale) end
end

function worldmap:UpdateMouseInteractivity()
	local disabled = Maps:Get("disableMouse") and true or false
	WorldMapButton:EnableMouse(not disabled)
	WorldMapFrame:EnableMouse(not disabled)
end

----------------------------------------------------------------------
-- Quest blobs
----------------------------------------------------------------------

function worldmap:ShowBlobs()
	WorldMapBlobFrame_CalculateHitTranslations()
	local selected = WORLDMAP_SETTINGS.selectedQuest
	if selected and not selected.completed then
		WorldMapBlobFrame:DrawQuestBlob(selected.questId, true)
	end
end

function worldmap:HideBlobs()
	local selected = WORLDMAP_SETTINGS.selectedQuest
	if selected then
		WorldMapBlobFrame:DrawQuestBlob(selected.questId, false)
	end
end

-- WorldMapBlobFrame is protected in combat, so it is parked off screen for the
-- duration of the fight and restored afterwards.
local blobWasVisible, blobNewScale
local blobHideFunc = function() blobWasVisible = nil end
local blobShowFunc = function() blobWasVisible = true end
local blobScaleFunc = function(_, scale) blobNewScale = scale end

local blobRestoreFrame

function worldmap:OnCombatStart()
	blobWasVisible = WorldMapBlobFrame:IsShown()
	blobNewScale = nil
	WorldMapBlobFrame:SetParent(nil)
	WorldMapBlobFrame:ClearAllPoints()
	WorldMapBlobFrame:SetPoint("TOP", UIParent, "BOTTOM")
	WorldMapBlobFrame:Hide()
	WorldMapBlobFrame.Hide = blobHideFunc
	WorldMapBlobFrame.Show = blobShowFunc
	WorldMapBlobFrame.SetScale = blobScaleFunc
end

function worldmap:OnCombatEnd()
	WorldMapBlobFrame:SetParent(WorldMapDetailFrame)
	WorldMapBlobFrame:ClearAllPoints()
	WorldMapBlobFrame:SetAllPoints(WorldMapDetailFrame)
	WorldMapBlobFrame.Hide = nil
	WorldMapBlobFrame.Show = nil
	WorldMapBlobFrame.SetScale = nil

	if blobWasVisible then
		WorldMapBlobFrame:Show()
		if not blobRestoreFrame then
			blobRestoreFrame = CreateFrame("Frame")
		end
		blobRestoreFrame:SetScript("OnUpdate", function(self)
			self:SetScript("OnUpdate", nil)
			worldmap:ShowBlobs()
		end)
	end

	if blobNewScale then
		WorldMapBlobFrame:SetScale(blobNewScale)
		WorldMapBlobFrame.xRatio = nil
		blobNewScale = nil
	end

	if WORLDMAP_SETTINGS.selectedQuest then
		WorldMapBlobFrame:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuest.questId, false)
	end
end

----------------------------------------------------------------------
-- Quest objectives dropdown (replaces the Blizzard checkbox)
----------------------------------------------------------------------

local function questObjectiveTexts()
	return {
		[0] = L and L["Map Objectives Hidden"] or "Скрыть полностью",
		[1] = L and L["Map Objectives Blobs"] or "Только области на карте",
	}
end

local function refreshQuestObjectivesDisplay()
	WorldMapQuestShowObjectives:SetChecked(Maps:GetQuestObjectiveMode() ~= 0)
	local onClick = WorldMapQuestShowObjectives:GetScript("OnClick")
	if onClick then
		onClick(WorldMapQuestShowObjectives)
	end
end

local function questObjDropDownOnClick(button)
	UIDropDownMenu_SetSelectedValue(_G[QUEST_OBJECTIVE_DROPDOWN], button.value)
	Maps:Set("questObjectives", button.value)
	refreshQuestObjectivesDisplay()
end

local function questObjDropDownInit()
	local dropdown = _G[QUEST_OBJECTIVE_DROPDOWN]
	local texts = questObjectiveTexts()
	local value = Maps:GetQuestObjectiveMode()
	local info = UIDropDownMenu_CreateInfo()

	for i = 0, 1 do
		info.value = i
		info.text = texts[i]
		info.func = questObjDropDownOnClick
		if value == i then
			info.checked = 1
			UIDropDownMenu_SetText(dropdown, info.text)
		else
			info.checked = nil
		end
		UIDropDownMenu_AddButton(info)
	end
end

local function createQuestObjectivesDropDown()
	if _G[QUEST_OBJECTIVE_DROPDOWN] then return end

	WorldMapQuestShowObjectives:Hide()
	WorldMapQuestShowObjectives:SetChecked(Maps:GetQuestObjectiveMode() ~= 0)
	WorldMapQuestShowObjectives_Toggle()

	local dropdown = CreateFrame("Frame", QUEST_OBJECTIVE_DROPDOWN, WorldMapFrame, "UIDropDownMenuTemplate")
	dropdown:SetPoint("BOTTOMRIGHT", WorldMapPositioningGuide, "BOTTOMRIGHT", -5, -2)

	local label = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetText(L and L["Map Quest Objectives"] or "Цели задания")
	label:SetPoint("RIGHT", dropdown, "LEFT", 5, 3)

	UIDropDownMenu_Initialize(dropdown, questObjDropDownInit)
	UIDropDownMenu_SetWidth(dropdown, 150)
	local mode = Maps:GetQuestObjectiveMode()
	UIDropDownMenu_SetSelectedValue(dropdown, mode)
	UIDropDownMenu_SetText(dropdown, questObjectiveTexts()[mode])
end

-- Objective blobs always use the panel-free full-map layout.
function worldmap:ApplyQuestObjectiveView()
	if WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then return end
	if not (WatchFrame and WatchFrame.showObjectives) then return end
	if (WorldMapFrame.numQuests or 0) <= 0 then return end
	if Maps:GetQuestObjectiveMode() == 0 then return end

	WorldMapFrame_SetFullMapView()
	-- zoom:Setup() is hooked to the view function above and performs the
	-- Leatrix SetPOIMaxBounds/UpdateQuests pass. Repeating it here transforms
	-- poiWorldMapPOIFrame offsets a second time in full-map view.
	WorldMapBlobFrame.xRatio = nil
end

local QUEST_CHROME_FRAMES = {
	"WorldMapQuestScrollFrame",
	"WorldMapQuestDetailScrollFrame",
	"WorldMapQuestRewardScrollFrame",
	"WorldMapQuestHighlightedFrame",
	"WorldMapQuestSelectFrame",
}

local function setQuestFramesShown(shown)
	for i = 1, #QUEST_CHROME_FRAMES do
		local frame = _G[QUEST_CHROME_FRAMES[i]]
		if frame then
			if shown then
				frame:Show()
			else
				frame:Hide()
			end
		end
	end
end

-- Empty quest parchment stays visible after SizeUp. Cut the panels out when
-- there are no quests.
function worldmap:UpdateQuestChrome()
	if self._updatingChrome then
		return
	end
	self._updatingChrome = true

	if Maps.windowed or (WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE) then
		setQuestFramesShown(false)
	else
		local noQuests = (WorldMapFrame.numQuests or 0) <= 0
		local mode = Maps:GetQuestObjectiveMode()
		if noQuests or mode == 0 then
			setQuestFramesShown(false)
			if not self._emptyQuestFullView then
				self._emptyQuestFullView = true
				if WorldMapFrame_SetFullMapView then
					WorldMapFrame_SetFullMapView()
				end
				if WorldMapBlobFrame then
					WorldMapBlobFrame.xRatio = nil
				end
			end
		else
			self._emptyQuestFullView = nil
			self:ApplyQuestObjectiveView()
			setQuestFramesShown(false)
		end
	end

	self._updatingChrome = nil
end

----------------------------------------------------------------------
-- Border visibility and detail tiles
----------------------------------------------------------------------

local function hasOverlays()
	if Maps.fog and Maps.fog.HasOverlayData then
		return Maps.fog:HasOverlayData()
	end
	return GetNumMapOverlays() > 0
end

function worldmap:UpdateDetailTiles()
	local hide = Maps:Get("hideBorder") and GetCurrentMapZone() > 0 and hasOverlays()
	for i = 1, NUM_WORLDMAP_DETAIL_TILES do
		local tile = _G["WorldMapDetailTile" .. i]
		if tile then
			if hide then tile:Hide() else tile:Show() end
		end
	end
end

function worldmap:UpdateMapElements()
	local hideBorder = Maps:Get("hideBorder") and true or false
	local mouseOver = WorldMapFrame:IsMouseOver()

	if self.elementsHidden and (mouseOver or not hideBorder) then
		self.elementsHidden = nil
		local sizeButton = Maps.windowed and WorldMapFrameSizeUpButton or WorldMapFrameSizeDownButton
		if sizeButton then sizeButton:Show() end
		WorldMapFrameCloseButton:Show()
		for _, frame in pairs(elementsToHide) do
			frame:Show()
		end
	elseif not self.elementsHidden and not mouseOver and hideBorder then
		self.elementsHidden = true
		WorldMapFrameSizeUpButton:Hide()
		WorldMapFrameSizeDownButton:Hide()
		WorldMapFrameCloseButton:Hide()
		for _, frame in pairs(elementsToHide) do
			frame:Hide()
		end
	end
end

function worldmap:UpdateBorderVisibility()
	local hideBorder = Maps:Get("hideBorder") and true or false
	Maps.bordersVisible = not hideBorder

	if Maps.windowed then
		if hideBorder then
			WorldMapFrameMiniBorderLeft:Hide()
			WorldMapFrameMiniBorderRight:Hide()
		else
			WorldMapFrameMiniBorderLeft:Show()
			WorldMapFrameMiniBorderRight:Show()
		end
	end

	if hideBorder then
		WorldMapFrameTitle:Hide()
	else
		WorldMapFrameTitle:Show()
	end

	self:UpdateDetailTiles()
	self:UpdateMapElements()

	for i = 1, #Maps.components do
		local component = Maps.components[i]
		if component ~= self and component.BorderVisibilityChanged then
			component:BorderVisibilityChanged(not hideBorder)
		end
	end
end

----------------------------------------------------------------------
-- Sizing
----------------------------------------------------------------------

local function notifyMapSize()
	for i = 1, #Maps.components do
		local component = Maps.components[i]
		if component ~= worldmap and component.UpdateMapSize then
			component:UpdateMapSize(Maps.windowed)
		end
	end
end

local function onDragStart(frame)
	worldmap:HideBlobs()
	frame:StartMoving()
end

local function onDragStop(frame)
	frame:StopMovingOrSizing()
	if not Maps:Get("resetLayout") then
		LibWindow.SavePosition(frame)
	end
	worldmap:ShowBlobs()
end

local function layoutTitleDrag()
	local title = WorldMapTitleButton
	if not title then
		return
	end
	title:ClearAllPoints()
	if Maps.windowed then
		title:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 16, -8)
		title:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -80, -8)
		title:SetHeight(28)
	else
		title:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 40, 0)
		title:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -150, 0)
		title:SetHeight(32)
	end
	title:Show()
end

local function setupTitleDrag()
	local title = WorldMapTitleButton
	if not title then
		return
	end
	title:EnableMouse(true)
	title:RegisterForDrag("LeftButton", "RightButton")
	title:SetScript("OnDragStart", function()
		onDragStart(WorldMapFrame)
	end)
	title:SetScript("OnDragStop", function()
		onDragStop(WorldMapFrame)
	end)
	title:SetScript("OnClick", nil)
	layoutTitleDrag()
end

function worldmap:SizeUp()
	Maps.windowed = false
	WORLDMAP_SETTINGS.size = WORLDMAP_QUESTLIST_SIZE

	WorldMapFrame:SetWidth(1024)
	WorldMapFrame:SetHeight(768)

	WorldMapPositioningGuide:ClearAllPoints()
	WorldMapPositioningGuide:SetPoint("CENTER")

	WorldMapFrameAreaFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
	WorldMapBlobFrame.xRatio = nil

	WorldMapZoneMinimapDropDown:Show()
	WorldMapZoomOutButton:Show()
	WorldMapZoneDropDown:Show()
	WorldMapContinentDropDown:Show()
	WorldMapFrameSizeDownButton:Show()

	WorldMapFrameMiniBorderLeft:Hide()
	WorldMapFrameMiniBorderRight:Hide()
	WorldMapFrameSizeUpButton:Hide()

	WorldMapLevelDropDown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", -50, -35)
	WorldMapLevelDropDown.header:Show()

	WorldMapFrameCloseButton:SetPoint("TOPRIGHT", WorldMapPositioningGuide, 4, 4)
	WorldMapFrameSizeDownButton:SetPoint("TOPRIGHT", WorldMapPositioningGuide, -16, 4)
	WorldMapFrameTitle:ClearAllPoints()
	WorldMapFrameTitle:SetPoint("CENTER", 0, 372)

	local dropdown = _G[QUEST_OBJECTIVE_DROPDOWN]
	if dropdown then dropdown:Show() end

	layoutTitleDrag()

	self._emptyQuestFullView = nil
	Maps.zoom:Setup()
	WorldMapFrame_SetPOIMaxBounds()
	self:UpdateQuestChrome()
end

function worldmap:SizeDown()
	Maps.windowed = true
	WORLDMAP_SETTINGS.size = WORLDMAP_WINDOWED_SIZE

	WorldMapFrame:SetWidth(623)
	WorldMapFrame:SetHeight(437)

	WorldMapPositioningGuide:ClearAllPoints()
	WorldMapPositioningGuide:SetAllPoints()

	WorldMapFrameAreaFrame:SetScale(WORLDMAP_WINDOWED_SIZE)
	WorldMapBlobFrame.xRatio = nil
	WorldMapFrameMiniBorderLeft:SetPoint("TOPLEFT", 10, -14)

	WorldMapZoneMinimapDropDown:Hide()
	WorldMapZoomOutButton:Hide()
	WorldMapZoneDropDown:Hide()
	WorldMapContinentDropDown:Hide()
	WorldMapLevelDropDown:Hide()
	WorldMapLevelUpButton:Hide()
	WorldMapLevelDownButton:Hide()
	WorldMapQuestScrollFrame:Hide()
	WorldMapQuestDetailScrollFrame:Hide()
	WorldMapQuestRewardScrollFrame:Hide()
	WorldMapFrameSizeDownButton:Hide()

	WorldMapFrameMiniBorderLeft:Show()
	WorldMapFrameMiniBorderRight:Show()
	WorldMapFrameSizeUpButton:Show()

	WorldMapLevelDropDown:SetPoint("TOPRIGHT", WorldMapPositioningGuide, "TOPRIGHT", -441, -35)
	WorldMapLevelDropDown:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL + 2)
	WorldMapLevelDropDown.header:Hide()

	WorldMapFrameCloseButton:SetPoint("TOPRIGHT", WorldMapFrameMiniBorderRight, "TOPRIGHT", -44, 5)
	WorldMapFrameSizeDownButton:SetPoint("TOPRIGHT", WorldMapFrameMiniBorderRight, "TOPRIGHT", -66, 5)
	WorldMapFrameTitle:ClearAllPoints()
	WorldMapFrameTitle:SetPoint("TOP", WorldMapDetailFrame, 0, 20)

	local dropdown = _G[QUEST_OBJECTIVE_DROPDOWN]
	if dropdown then dropdown:Hide() end

	layoutTitleDrag()

	self._emptyQuestFullView = nil
	Maps.zoom:Setup()
	WorldMapFrame_SetPOIMaxBounds()
end

function worldmap:ToggleMapSize()
	local db = Maps:DB()
	if not db then return end

	local goingWindowed = not Maps.windowed
	ToggleFrame(WorldMapFrame)

	if goingWindowed then
		self:SizeDown()
	else
		self:SizeUp()
	end
	db.miniMap = goingWindowed

	self:SetAlpha()
	self:SetPosition()
	notifyMapSize()
	self:UpdateBorderVisibility()
	self:UpdateMouseInteractivity()

	ToggleFrame(WorldMapFrame)
end

----------------------------------------------------------------------
-- Frame plumbing
----------------------------------------------------------------------

-- Removing the map from the UI panel system stops it from pushing other frames
-- around (and stops them from repositioning it).
local function detachFromUIPanels()
	UIPanelWindows["WorldMapFrame"] = nil
	WorldMapFrame:SetAttribute("UIPanelLayout-defined", nil)
	WorldMapFrame:SetAttribute("UIPanelLayout-enabled", false)
	WorldMapFrame:SetAttribute("UIPanelLayout-area", nil)
	WorldMapFrame:SetAttribute("UIPanelLayout-pushable", nil)
	WorldMapFrame:SetAttribute("UIPanelLayout-allowOtherPanels", true)
end

local function onWorldMapShow()
	if not Maps:IsActive() then return end
	worldmap:SetStrata()
	worldmap:SetScale()
	worldmap:SetPosition()
	worldmap:SetAlpha()
	realZone = zoneKey()

	if BattlefieldMinimap then
		savedBattlefieldOnUpdate = BattlefieldMinimap:GetScript("OnUpdate")
		BattlefieldMinimap:SetScript("OnUpdate", nil)
	end

	if WORLDMAP_SETTINGS.selectedQuest then
		WorldMapFrame_SelectQuestFrame(WORLDMAP_SETTINGS.selectedQuest)
	end

	worldmap:StartFadeWatch()
end

local function onWorldMapHide()
	if not Maps:IsActive() then return end
	worldmap:StopFadeWatch()
	if UIFrameFadeRemoveFrame then
		UIFrameFadeRemoveFrame(WorldMapFrame)
	end
	worldmap:SetAlpha()
	SetMapToCurrentZone()
	if BattlefieldMinimap then
		BattlefieldMinimap:SetScript("OnUpdate", savedBattlefieldOnUpdate or BattlefieldMinimap_OnUpdate)
	end
end

-- Blizzard's dropdowns are drawn at UIParent scale; re-apply the map scale.
local function dropdownScaleFix(self)
	ToggleDropDownMenu(nil, nil, self:GetParent())
	DropDownList1:SetScale(Maps:Get("scale") or 1)
end

local eventFrame

local function onEvent(_, event)
	if not Maps:IsActive() then return end
	if event == "ZONE_CHANGED_NEW_AREA" then
		local current = zoneKey()
		if realZone == current or ((current % 100) > 0 and (GetPlayerMapPosition("player")) ~= 0) then
			SetMapToCurrentZone()
			realZone = zoneKey()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		worldmap:OnCombatStart()
	elseif event == "PLAYER_REGEN_ENABLED" then
		worldmap:OnCombatEnd()
	end
end

function worldmap:Enable()
	-- The advanced/mini world map CVars fight our own layout, so the map starts
	-- from its vanilla state and the size is driven by our setting instead.
	local advanced, mini = GetCVarBool("advancedWorldMap"), GetCVarBool("miniWorldMap")
	SetCVar("miniWorldMap", nil)
	SetCVar("advancedWorldMap", nil)
	if InterfaceOptionsObjectivesPanelAdvancedWorldMap then
		InterfaceOptionsObjectivesPanelAdvancedWorldMap:Disable()
		InterfaceOptionsObjectivesPanelAdvancedWorldMapText:SetTextColor(0.5, 0.5, 0.5)
	end
	if mini then WorldMap_ToggleSizeUp() end
	if advanced then WorldMapFrame_ToggleAdvanced() end

	LibWindow.RegisterConfig(WorldMapFrame, Maps.windowStorage)

	local wasVisible = WorldMapFrame:IsVisible()
	if wasVisible then
		HideUIPanel(WorldMapFrame)
	end
	-- Leaving the frame in a UI panel slot after detaching corrupts
	-- UpdateUIPanelPositions, so vacate the slot first.
	if GetUIPanel then
		for _, slot in ipairs({ "left", "center", "right", "doublewide" }) do
			if GetUIPanel(slot) == WorldMapFrame then
				HideUIPanel(WorldMapFrame, 1)
				break
			end
		end
	end

	detachFromUIPanels()
	-- WorldMap_ToggleSizeDown re-registers the map as a "center" panel.
	if not hooksInstalled then
		hooksecurefunc("WorldMap_ToggleSizeDown", detachFromUIPanels)
	end

	WorldMapFrame:SetScript("OnKeyDown", nil)
	WorldMapFrame:SetMovable(true)
	WorldMapFrame:RegisterForDrag("LeftButton", "RightButton")
	WorldMapFrame:SetScript("OnDragStart", onDragStart)
	WorldMapFrame:SetScript("OnDragStop", onDragStop)
	WorldMapFrame:SetParent(UIParent)
	WorldMapFrame:SetToplevel(true)
	WorldMapFrame:SetWidth(1024)
	WorldMapFrame:SetHeight(768)
	WorldMapFrame:SetClampedToScreen(false)

	BlackoutWorld:Hide()
	setupTitleDrag()

	WorldMapContinentDropDownButton:SetScript("OnClick", dropdownScaleFix)
	WorldMapZoneDropDownButton:SetScript("OnClick", dropdownScaleFix)
	WorldMapZoneMinimapDropDownButton:SetScript("OnClick", dropdownScaleFix)

	WorldMapFrameSizeDownButton:SetScript("OnClick", function() worldmap:ToggleMapSize() end)
	WorldMapFrameSizeUpButton:SetScript("OnClick", function() worldmap:ToggleMapSize() end)

	createQuestObjectivesDropDown()

	if not hooksInstalled then
		hooksInstalled = true
		WorldMapFrame:HookScript("OnShow", onWorldMapShow)
		WorldMapFrame:HookScript("OnHide", onWorldMapHide)
		WorldMapFrame:HookScript("OnUpdate", function()
			if not Maps:IsActive() then
				return
			end
			if Maps:Get("hideBorder") then
				worldmap:UpdateMapElements()
			end
		end)
		hooksecurefunc("WorldMapFrame_DisplayQuests", function()
			if Maps:IsActive() then worldmap:UpdateQuestChrome() end
		end)
		hooksecurefunc(WorldMapTooltip, "Show", function(self)
			self:SetFrameStrata("TOOLTIP")
		end)
		tinsert(UISpecialFrames, "WorldMapFrame")

		eventFrame = CreateFrame("Frame")
		eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		eventFrame:SetScript("OnEvent", onEvent)
	end

	Api:PrimeAreaLookup()

	if Maps:DB() and Maps:DB().miniMap then
		self:SizeDown()
	else
		self:SizeUp()
	end

	self:SetPosition()
	self:SetScale()
	self:SetAlpha()
	self:SetArrow()
	self:UpdateBorderVisibility()
	self:UpdateMouseInteractivity()
	if WorldMapFrame:IsShown() then
		self:StartFadeWatch()
	end
	notifyMapSize()

	WorldMapFrame_SetPOIMaxBounds()

	if wasVisible then
		-- UI panel layout is off; ShowUIPanel would corrupt panel positions.
		WorldMapFrame:Show()
	end
end

function worldmap:Disable()
	self:StopFadeWatch()
	if eventFrame then
		eventFrame:UnregisterAllEvents()
	end
end

function worldmap:Refresh()
	local db = Maps:DB()
	if not db then return end

	if db.miniMap and not Maps.windowed then
		self:SizeDown()
	elseif not db.miniMap and Maps.windowed then
		self:SizeUp()
	end

	self:SetStrata()
	self:SetAlpha()
	self:SetArrow()
	self:UpdateBorderVisibility()
	self:UpdateMouseInteractivity()
	if WorldMapFrame:IsShown() and Maps:Get("fadeOnMove") ~= false then
		self:StartFadeWatch()
	else
		self:StopFadeWatch()
	end
	notifyMapSize()
	self:UpdateQuestChrome()
end

return worldmap
