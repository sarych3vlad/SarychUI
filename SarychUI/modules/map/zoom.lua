-- SarychUI Maps: zoom and pan.
--
-- WorldMapDetailFrame is moved into a scroll frame so the map can be scaled
-- past its own bounds and scrolled around, and everything anchored to the detail
-- frame (POIs, quest blobs, units, corpse, flags, vehicles) is counter-scaled
-- against canvas zoom. Quest POIs still follow the scale of the map window so
-- they remain proportional to it. The mechanism follows Leatrix Maps, which in
-- turn follows Magnify; the per-frame update below replaces Blizzard's
-- WorldMapButton_OnUpdate because that one hard-codes an unzoomed map.

local Maps = SarychUI.Maps
local Api = Maps.Api

local zoom = Maps:RegisterComponent("zoom", {})

local MIN_ZOOM = 1.0
local WINDOWED_MIN_SCALE = 1.0
local WINDOWED_MAX_SCALE = 3.0
local WINDOWED_SCALE_STEP = 0.1
local PLAYER_ARROW_SIZE = 36

local abs, min, max, floor = math.abs, math.min, math.max, math.floor

local scrollFrame
local playerArrow
local poiMaxX, poiMaxY
local lastAreaID
local scriptsInstalled = false
local origWorldMapPingShow

local saved = { scroll = 0, vertical = 0, scale = 1, areaID = nil }

local PAN_BUTTONS = {
	left = "LeftButton",
	middle = "MiddleButton",
	right = "RightButton",
}

local function panButton()
	return PAN_BUTTONS[Maps:Get("panButton") or "middle"] or "MiddleButton"
end

local function maxZoom()
	return Maps:Get("maxZoom") or 4
end

local function zoomStep()
	return Maps:Get("zoomStep") or 0.1
end

----------------------------------------------------------------------
-- Scroll bounds
----------------------------------------------------------------------

local function updateScrollBounds()
	if not scrollFrame then return end
	local scale = WorldMapDetailFrame:GetScale()
	if not scale or scale <= 0 then scale = 1 end
	scrollFrame.maxX = ((WorldMapDetailFrame:GetWidth() * scale) - scrollFrame:GetWidth()) / scale
	scrollFrame.maxY = ((WorldMapDetailFrame:GetHeight() * scale) - scrollFrame:GetHeight()) / scale
	if scrollFrame.maxX < 0 then scrollFrame.maxX = 0 end
	if scrollFrame.maxY < 0 then scrollFrame.maxY = 0 end
	scrollFrame.zoomedIn = scale > MIN_ZOOM
end

local function rememberState()
	if not scrollFrame then return end
	saved.scroll = scrollFrame:GetHorizontalScroll()
	saved.vertical = scrollFrame:GetVerticalScroll()
	saved.scale = WorldMapDetailFrame:GetScale()
	saved.areaID = Api:GetCurrentAreaID()
end

local function afterScrollOrPan()
	rememberState()
	-- Quest blobs are drawn into a texture and have to be redrawn after the
	-- canvas moves, otherwise they smear across the map.
	if WORLDMAP_SETTINGS.selectedQuest then
		local questID = WORLDMAP_SETTINGS.selectedQuestId or WORLDMAP_SETTINGS.selectedQuest.questId
		if questID then
			WorldMapBlobFrame:DrawQuestBlob(questID, false)
			WorldMapBlobFrame:DrawQuestBlob(questID, true)
		end
	end
	if Maps.poi and Maps.poi.Rescale then
		Maps.poi:Rescale()
	end
end

zoom.AfterScrollOrPan = afterScrollOrPan

----------------------------------------------------------------------
-- Quest POI scaling
----------------------------------------------------------------------

function zoom:SetPOIMaxBounds()
	poiMaxY = WorldMapDetailFrame:GetHeight() * -WORLDMAP_SETTINGS.size + 12
	poiMaxX = WorldMapDetailFrame:GetWidth() * WORLDMAP_SETTINGS.size + 12
end

-- Leatrix counter-scales the quest button with size / effectiveScale. There are
-- two SarychUI adjustments: Blizzard writes fullscreen POI coordinates in
-- WORLDMAP_QUESTLIST_SIZE space even while the map itself is FULLMAP_SIZE, and
-- the visual size must follow WorldMapFrame scale instead of cancelling it out.
local function resizeQuestPOI(button)
	if not button then return end
	local _, _, _, x, y = button:GetPoint()
	if x == nil or y == nil then return end

	local effective = WorldMapDetailFrame:GetEffectiveScale()
	if not effective or effective == 0 then return end

	local windowScale = WorldMapFrame:GetScale() or 1
	if windowScale <= 0 then windowScale = 1 end
	local poiScale = tonumber(Maps:Get("poiScale")) or 0.8
	if poiScale <= 0 then poiScale = 0.8 end

	-- GetEffectiveScale includes WorldMapFrame:GetScale(). Multiplying that
	-- component back in leaves canvas zoom counter-scaled while allowing the
	-- window itself (including Ctrl+wheel resizing) to scale the POI normally.
	local factor = WORLDMAP_SETTINGS.size / effective * windowScale * poiScale
	if factor <= 0 then return end

	local sourceScale
	if WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
		sourceScale = WORLDMAP_WINDOWED_SIZE
	else
		sourceScale = WORLDMAP_QUESTLIST_SIZE
	end
	local coordinateScale = WORLDMAP_SETTINGS.size / sourceScale
	local posX = x * coordinateScale / factor
	local posY = y * coordinateScale / factor
	button:SetScale(factor)
	button:SetPoint("CENTER", button:GetParent(), "TOPLEFT", posX, posY)
end

function zoom:ResizeQuestPOIs()
	if not poiMaxY then return end
	for typeIndex = 1, 4 do
		for buttonIndex = 1, 25 do
			resizeQuestPOI(_G["poiWorldMapPOIFrame" .. typeIndex .. "_" .. buttonIndex])
		end
	end
	if QUEST_POI_SWAP_BUTTONS then
		resizeQuestPOI(QUEST_POI_SWAP_BUTTONS["WorldMapPOIFrame"])
	end
end

----------------------------------------------------------------------
-- Canvas scale
----------------------------------------------------------------------

function zoom:SetDetailScale(value)
	WorldMapDetailFrame:SetScale(value)
	self:SetPOIMaxBounds()

	local inverse = 1 / value
	WorldMapPOIFrame:SetScale(1 / WORLDMAP_SETTINGS.size)
	WorldMapBlobFrame:SetScale(value)

	if playerArrow then playerArrow:SetScale(inverse) end
	if WorldMapDeathRelease then WorldMapDeathRelease:SetScale(inverse) end
	if WorldMapCorpse then WorldMapCorpse:SetScale(inverse) end

	for i = 1, GetNumBattlefieldFlagPositions() do
		local flag = _G["WorldMapFlag" .. i]
		if flag then flag:SetScale(inverse) end
	end
	for i = 1, MAX_PARTY_MEMBERS do
		local frame = _G["WorldMapParty" .. i]
		if frame then frame:SetScale(inverse) end
	end
	for i = 1, MAX_RAID_MEMBERS do
		local frame = _G["WorldMapRaid" .. i]
		if frame then frame:SetScale(inverse) end
	end
	for i = 1, #MAP_VEHICLES do
		if MAP_VEHICLES[i] then MAP_VEHICLES[i]:SetScale(inverse) end
	end

	updateScrollBounds()
	WorldMapFrame_OnEvent(WorldMapFrame, "DISPLAY_SIZE_CHANGED")
	if WorldMapFrame_UpdateQuests() > 0 then
		self:RedrawSelectedQuest()
	end
	if Maps.poi and Maps.poi.Rescale then
		Maps.poi:Rescale()
	end
	if Maps.questie and Maps.questie.Rescale then
		Maps.questie:Rescale("SetDetailScale:" .. tostring(value))
	end
end

function zoom:RedrawSelectedQuest()
	if WORLDMAP_SETTINGS.selectedQuestId then
		WorldMapFrame_SelectQuestById(WORLDMAP_SETTINGS.selectedQuestId)
	elseif WorldMapFrame_SelectQuestFrame then
		WorldMapFrame_SelectQuestFrame(_G["WorldMapQuestFrame1"])
	end
end

function zoom:ResetView()
	if not scrollFrame then return end
	self:SetDetailScale(MIN_ZOOM)
	scrollFrame:SetHorizontalScroll(0)
	scrollFrame:SetVerticalScroll(0)
	scrollFrame.zoomedIn = false
	rememberState()
end

----------------------------------------------------------------------
-- Setup (runs on every map open and every size change)
----------------------------------------------------------------------

function zoom:CreateScrollFrame()
	if scrollFrame then return scrollFrame end

	-- Anonymous on purpose: nothing outside this module needs to find it, and a
	-- named frame would collide with the standalone Leatrix Maps addon.
	scrollFrame = CreateFrame("ScrollFrame", nil, WorldMapFrame)
	scrollFrame:SetWidth(1002)
	scrollFrame:SetHeight(668)
	scrollFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOPLEFT")
	scrollFrame:EnableMouse(true)
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScrollChild(WorldMapDetailFrame)

	Maps.scrollFrame = scrollFrame
	return scrollFrame
end

function zoom:Setup()
	if not Maps:IsActive() or not scrollFrame then return end

	scrollFrame.panning = false
	scrollFrame.moved = false
	WorldMapFrame:EnableMouse(not Maps:Get("disableMouse"))

	scrollFrame:ClearAllPoints()
	if WORLDMAP_SETTINGS.size == WORLDMAP_QUESTLIST_SIZE then
		scrollFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
	elseif WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
		scrollFrame:SetPoint("TOPLEFT", 37, -66)
	else
		scrollFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOPLEFT", 11, -70.5)
	end

	-- Keep the checkbox label on the same footer baseline as the coordinate text.
	-- OptionsCheckButtonTemplate is 24px high and centers its label 1px upward,
	-- so its frame sits 6-7px below the FontString's bottom anchor.
	WorldMapTrackQuest:ClearAllPoints()
	local trackQuestY = WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE and -9 or 4
	WorldMapTrackQuest:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOMLEFT", 16, trackQuestY)
	scrollFrame:SetScale(WORLDMAP_SETTINGS.size)

	self:SetDetailScale(MIN_ZOOM)
	WorldMapDetailFrame:SetAllPoints(scrollFrame)
	scrollFrame:SetHorizontalScroll(0)
	scrollFrame:SetVerticalScroll(0)

	local areaID = Api:GetCurrentAreaID()
	lastAreaID = areaID
	if Maps:Get("persistZoom") ~= false and saved.areaID and saved.areaID == areaID and saved.scale > MIN_ZOOM then
		self:SetDetailScale(saved.scale)
		updateScrollBounds()
		scrollFrame:SetHorizontalScroll(min(saved.scroll, scrollFrame.maxX or 0))
		scrollFrame:SetVerticalScroll(min(saved.vertical, scrollFrame.maxY or 0))
	end

	-- Everything that has to travel with the canvas hangs off the detail frame.
	WorldMapButton:SetScale(1)
	WorldMapButton:SetParent(WorldMapDetailFrame)
	WorldMapButton:SetAllPoints(WorldMapDetailFrame)

	WorldMapPOIFrame:SetParent(WorldMapDetailFrame)
	WorldMapBlobFrame:SetParent(WorldMapDetailFrame)
	WorldMapBlobFrame:ClearAllPoints()
	WorldMapBlobFrame:SetAllPoints(WorldMapDetailFrame)

	if playerArrow then
		playerArrow:SetParent(WorldMapDetailFrame)
	end

	updateScrollBounds()
	if Maps.questie and Maps.questie.Rescale then
		Maps.questie:Rescale("Setup")
	end
end

-- Zone or continent changed: a stale scroll offset would leave the map outside
-- the viewport, so the view is reset unless the area is unchanged.
function zoom:OnMapChanged()
	if not Maps:IsActive() or not scrollFrame then return end

	local areaID = Api:GetCurrentAreaID()
	if areaID == lastAreaID then
		updateScrollBounds()
		return
	end
	lastAreaID = areaID
	self:ResetView()
end

----------------------------------------------------------------------
-- Mouse handling
----------------------------------------------------------------------

local function onPan()
	local cursorX, cursorY = GetCursorPosition()
	local effective = scrollFrame:GetEffectiveScale()
	if not effective or effective == 0 then return end

	-- Divide by canvas zoom so a drag moves the map 1:1 on screen; then
	-- dampen so holding the pan button does not feel twitchy.
	local zoom = WorldMapDetailFrame:GetScale() or 1
	if zoom < 0.01 then zoom = 1 end
	local speed = tonumber(Maps:Get("panSpeed")) or 0.9
	local dX = (scrollFrame.cursorX - cursorX) / effective / zoom * speed
	local dY = (cursorY - scrollFrame.cursorY) / effective / zoom * speed

	if abs(dX) < 0.2 and abs(dY) < 0.2 then return end

	scrollFrame.moved = true
	local x = min(max(0, dX + scrollFrame.startX), scrollFrame.maxX or 0)
	local y = min(max(0, dY + scrollFrame.startY), scrollFrame.maxY or 0)
	scrollFrame:SetHorizontalScroll(x)
	scrollFrame:SetVerticalScroll(y)
	afterScrollOrPan()
end

local function onMouseWheel(self, delta)
	if not Maps:IsActive() then return end

	-- Ctrl+wheel scales the whole windowed frame instead of the canvas.
	if IsControlKeyDown() and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
		local newScale = (WorldMapFrame:GetScale() or 1) + delta * WINDOWED_SCALE_STEP
		newScale = min(max(WINDOWED_MIN_SCALE, newScale), WINDOWED_MAX_SCALE)
		if Maps:Get("resetLayout") then
			WorldMapFrame:SetScale(newScale)
		else
			LibStub("LibWindow-1.1").SetScale(WorldMapFrame, newScale)
		end
		return
	end

	local effective = scrollFrame:GetEffectiveScale()
	if not effective or effective == 0 then return end

	local oldScrollH = scrollFrame:GetHorizontalScroll()
	local oldScrollV = scrollFrame:GetVerticalScroll()

	local cursorX, cursorY = GetCursorPosition()
	cursorX = cursorX / effective
	cursorY = cursorY / effective

	local frameX = cursorX - scrollFrame:GetLeft()
	local frameY = scrollFrame:GetTop() - cursorY

	local oldScale = WorldMapDetailFrame:GetScale()
	local newScale = min(max(MIN_ZOOM, oldScale * (1.0 + delta * zoomStep())), maxZoom())
	if newScale == oldScale then return end

	zoom:SetDetailScale(newScale)
	updateScrollBounds()

	-- Keep the point under the cursor fixed while the canvas grows.
	local centerX = oldScrollH + frameX / oldScale
	local centerY = oldScrollV + frameY / oldScale
	local newScrollH = min(max(0, centerX - frameX / newScale), scrollFrame.maxX or 0)
	local newScrollV = min(max(0, centerY - frameY / newScale), scrollFrame.maxY or 0)

	scrollFrame:SetHorizontalScroll(newScrollH)
	scrollFrame:SetVerticalScroll(newScrollV)
	afterScrollOrPan()
end

local function clickWorldMap(mouseButton)
	if not mouseButton or not WorldMapButton_OnClick then
		return
	end
	-- This client's WorldMapButton_OnClick(self, button) calls GetBindingFromClick(button).
	-- Passing only the button name makes `button` nil and errors.
	local oldThis = this
	this = WorldMapButton
	WorldMapButton_OnClick(WorldMapButton, mouseButton)
	this = oldThis
end

local function onMouseDown(_, button)
	if not Maps:IsActive() then return end
	if button ~= panButton() then return end
	if not scrollFrame.zoomedIn then return end

	scrollFrame.panning = true
	scrollFrame.cursorX, scrollFrame.cursorY = GetCursorPosition()
	scrollFrame.startX = scrollFrame:GetHorizontalScroll()
	scrollFrame.startY = scrollFrame:GetVerticalScroll()
	scrollFrame.moved = false
end

local function onMouseUp(_, button)
	if not Maps:IsActive() then return end

	local wasPanMove = false
	if button == panButton() then
		scrollFrame.panning = false
		wasPanMove = scrollFrame.moved and true or false
		scrollFrame.moved = false
	end

	-- Leatrix: clicks go through OnMouseUp -> WorldMapButton_OnClick(frame, button).
	-- OnClick is cleared so the XML wrapper cannot call it with a nil button.
	if not wasPanMove then
		clickWorldMap(button)
	end
end

----------------------------------------------------------------------
-- Player arrow
----------------------------------------------------------------------

local function createPlayerArrow()
	if playerArrow then return end
	playerArrow = CreateFrame("Frame", nil, WorldMapDetailFrame)
	playerArrow:SetWidth(PLAYER_ARROW_SIZE)
	playerArrow:SetHeight(PLAYER_ARROW_SIZE)
	playerArrow:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL + 3)
	playerArrow.icon = playerArrow:CreateTexture(nil, "OVERLAY")
	playerArrow.icon:SetAllPoints(playerArrow)
	playerArrow.icon:SetTexture(Maps.MEDIA .. "WorldMapArrow")
	playerArrow:Hide()
	zoom.playerArrow = playerArrow
end

----------------------------------------------------------------------
-- Per-frame update (replaces WorldMapButton_OnUpdate)
----------------------------------------------------------------------

local function updateHighlight(self)
	local effective = self:GetEffectiveScale()
	if not effective or effective == 0 then return end

	local x, y = GetCursorPosition()
	x = x / effective
	y = y / effective

	local centerX, centerY = self:GetCenter()
	if not centerX then return end
	local width, height = self:GetWidth(), self:GetHeight()
	local adjustedY = (centerY + (height / 2) - y) / height
	local adjustedX = (x - (centerX - (width / 2))) / width

	local name, fileName, texPercentageX, texPercentageY, textureX, textureY, scrollChildX, scrollChildY
	if self:IsMouseOver() then
		name, fileName, texPercentageX, texPercentageY, textureX, textureY, scrollChildX, scrollChildY =
			UpdateMapHighlight(adjustedX, adjustedY)
	end

	WorldMapFrame.areaName = name
	if not WorldMapFrame.poiHighlight then
		WorldMapFrameAreaLabel:SetText(name)
	end

	if fileName then
		WorldMapHighlight:SetTexCoord(0, texPercentageX, 0, texPercentageY)
		WorldMapHighlight:SetTexture("Interface\\WorldMap\\" .. fileName .. "\\" .. fileName .. "Highlight")
		textureX = textureX * width
		textureY = textureY * height
		scrollChildX = scrollChildX * width
		scrollChildY = -scrollChildY * height
		if textureX > 0 and textureY > 0 then
			WorldMapHighlight:SetWidth(textureX)
			WorldMapHighlight:SetHeight(textureY)
			WorldMapHighlight:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT", scrollChildX, scrollChildY)
			WorldMapHighlight:Show()
		end
	else
		WorldMapHighlight:Hide()
	end
end

local function canvasOffsets(x, y)
	local scale = WorldMapDetailFrame:GetScale()
	return x * WorldMapDetailFrame:GetWidth() * scale, -y * WorldMapDetailFrame:GetHeight() * scale
end

local function updatePlayer()
	local x, y = GetPlayerMapPosition("player")
	if not x or (x == 0 and y == 0) then
		if playerArrow then playerArrow:Hide() end
		if WorldMapPing then WorldMapPing:Hide() end
		if ShowWorldMapArrowFrame then ShowWorldMapArrowFrame(nil) end
		return
	end

	local offsetX, offsetY = canvasOffsets(x, y)
	playerArrow:ClearAllPoints()
	playerArrow:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", offsetX, offsetY)

	local size = PLAYER_ARROW_SIZE * (Maps:Get("arrowScale") or 0.88)
	playerArrow:SetWidth(size)
	playerArrow:SetHeight(size)

	-- The Blizzard arrow is a 3D model that cannot be clipped by a scroll frame,
	-- so it is replaced with a flat texture that takes its facing.
	if UpdateWorldMapArrowFrames then UpdateWorldMapArrowFrames() end
	if ShowWorldMapArrowFrame then ShowWorldMapArrowFrame(nil) end
	if PlayerArrowFrame and PlayerArrowFrame.GetFacing then
		Api:SetTextureRotation(playerArrow.icon, PlayerArrowFrame:GetFacing())
	end
	if WorldMapPing then WorldMapPing:Hide() end
	playerArrow:Show()
end

local function updateGroup()
	local shown = 0

	if GetNumRaidMembers() > 0 then
		for i = 1, MAX_PARTY_MEMBERS do
			local frame = _G["WorldMapParty" .. i]
			if frame then frame:Hide() end
		end
		for i = 1, MAX_RAID_MEMBERS do
			local unit = "raid" .. i
			local x, y = GetPlayerMapPosition(unit)
			local frame = _G["WorldMapRaid" .. (shown + 1)]
			if not frame then break end
			if (x == 0 and y == 0) or UnitIsUnit(unit, "player") then
				frame:Hide()
			else
				local offsetX, offsetY = canvasOffsets(x, y)
				frame:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", offsetX, offsetY)
				frame.name = nil
				frame.unit = unit
				if Maps.groupicons then Maps.groupicons:UpdateUnit(frame, unit) end
				frame:Show()
				shown = shown + 1
			end
		end
	else
		for i = 1, MAX_PARTY_MEMBERS do
			local unit = "party" .. i
			local x, y = GetPlayerMapPosition(unit)
			local frame = _G["WorldMapParty" .. i]
			if frame then
				if x == 0 and y == 0 then
					frame:Hide()
				else
					local offsetX, offsetY = canvasOffsets(x, y)
					frame:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", offsetX, offsetY)
					frame.unit = unit
					if Maps.groupicons then Maps.groupicons:UpdateUnit(frame, unit) end
					frame:Show()
				end
			end
		end
	end

	-- Battleground team members reuse the raid frames after the raid units.
	local numTeamMembers = GetNumBattlefieldPositions()
	for i = shown + 1, MAX_RAID_MEMBERS do
		local frame = _G["WorldMapRaid" .. i]
		if not frame then break end
		local x, y, name = GetBattlefieldPosition(i - shown)
		if not x or (x == 0 and y == 0) then
			frame:Hide()
		else
			local offsetX, offsetY = canvasOffsets(x, y)
			frame:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", offsetX, offsetY)
			frame.name = name
			frame.unit = nil
			if Maps.groupicons then Maps.groupicons:ResetUnit(frame) end
			frame:Show()
		end
	end
	return numTeamMembers
end

local function updateFlags()
	local numFlags = GetNumBattlefieldFlagPositions()
	for i = 1, numFlags do
		local x, y, token = GetBattlefieldFlagPosition(i)
		local frame = _G["WorldMapFlag" .. i]
		if frame then
			if x == 0 and y == 0 then
				frame:Hide()
			else
				local offsetX, offsetY = canvasOffsets(x, y)
				frame:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", offsetX, offsetY)
				local texture = _G["WorldMapFlag" .. i .. "Texture"]
				if texture then
					texture:SetTexture("Interface\\WorldStateFrame\\" .. token)
				end
				frame:Show()
			end
		end
	end
	for i = numFlags + 1, NUM_WORLDMAP_FLAGS do
		local frame = _G["WorldMapFlag" .. i]
		if frame then frame:Hide() end
	end
end

local function updateCorpse()
	local x, y = GetCorpseMapPosition()
	if x == 0 and y == 0 then
		WorldMapCorpse:Hide()
	else
		local offsetX, offsetY = canvasOffsets(x, y)
		WorldMapCorpse:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", offsetX, offsetY)
		WorldMapCorpse:Show()
	end

	x, y = GetDeathReleasePosition()
	if (x == 0 and y == 0) or UnitIsGhost("player") then
		WorldMapDeathRelease:Hide()
	else
		local offsetX, offsetY = canvasOffsets(x, y)
		WorldMapDeathRelease:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", offsetX, offsetY)
		WorldMapDeathRelease:Show()
	end
end

local function updateVehicles()
	local numVehicles
	if GetCurrentMapContinent() == WORLDMAP_WORLD_ID
		or (GetCurrentMapContinent() ~= -1 and GetCurrentMapZone() == 0) then
		numVehicles = 0
	else
		numVehicles = GetNumBattlefieldVehicles()
	end

	local total = #MAP_VEHICLES
	local lastShown = 0
	for i = 1, numVehicles do
		if i > total then
			MAP_VEHICLES[i] = CreateFrame("Frame", "WorldMapVehicles" .. i, WorldMapButton, "WorldMapVehicleTemplate")
			MAP_VEHICLES[i].texture = _G["WorldMapVehicles" .. i .. "Texture"]
		end
		local x, y, unitName, isPossessed, vehicleType, orientation, isPlayer, isAlive = GetBattlefieldVehicleInfo(i)
		local frame = MAP_VEHICLES[i]
		if x and isAlive and not isPlayer and VEHICLE_TEXTURES[vehicleType] then
			local offsetX, offsetY = canvasOffsets(x, y)
			Api:SetTextureRotation(frame.texture, orientation)
			frame.texture:SetTexture(WorldMap_GetVehicleTexture(vehicleType, isPossessed))
			frame:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", offsetX, offsetY)
			frame:SetWidth(VEHICLE_TEXTURES[vehicleType].width)
			frame:SetHeight(VEHICLE_TEXTURES[vehicleType].height)
			frame.name = unitName
			frame:Show()
			lastShown = i
		else
			frame:Hide()
		end
	end
	for i = lastShown + 1, #MAP_VEHICLES do
		if MAP_VEHICLES[i] then MAP_VEHICLES[i]:Hide() end
	end
end

local function onUpdate(self)
	if not Maps:IsActive() then return end

	updateHighlight(self)
	updatePlayer()
	updateGroup()
	updateFlags()
	updateCorpse()
	updateVehicles()

	if scrollFrame.panning then
		onPan()
	end
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------

local eventFrame

function zoom:Enable()
	self:CreateScrollFrame()
	createPlayerArrow()

	WorldMapDetailFrame:SetParent(scrollFrame)

	-- The 3D ping model is not clipped by the scroll frame and sits in the
	-- wrong place once the canvas is scaled, so it is disabled while we own the map.
	if WorldMapPing and not origWorldMapPingShow then
		origWorldMapPingShow = WorldMapPing.Show
		WorldMapPing.Show = function() end
		if WorldMapPing.SetModelScale then
			WorldMapPing:SetModelScale(0)
		end
		WorldMapPing:Hide()
	end

	-- The zone name label must not scroll with the canvas.
	WorldMapFrameAreaFrame:SetParent(WorldMapFrame)
	WorldMapFrameAreaFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL)
	WorldMapFrameAreaFrame:ClearAllPoints()
	WorldMapFrameAreaFrame:SetPoint("TOP", scrollFrame, "TOP", 0, -10)

	if not scriptsInstalled then
		scriptsInstalled = true

		scrollFrame:SetScript("OnMouseWheel", onMouseWheel)
		WorldMapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
		WorldMapButton:SetScript("OnMouseDown", onMouseDown)
		WorldMapButton:SetScript("OnMouseUp", onMouseUp)
		WorldMapButton:SetScript("OnUpdate", onUpdate)
		-- Clicks are dispatched from OnMouseUp; the XML OnClick passes a nil
		-- button into GetBindingFromClick on this client.
		WorldMapButton:SetScript("OnClick", nil)

		hooksecurefunc("WorldMapFrame_UpdateQuests", function()
			if Maps:IsActive() then zoom:ResizeQuestPOIs() end
		end)
		if WorldMapFrame_SetFullMapView then
			hooksecurefunc("WorldMapFrame_SetFullMapView", function()
				if Maps:IsActive() then zoom:Setup() end
			end)
		end
		if WorldMapFrame_SetQuestMapView then
			hooksecurefunc("WorldMapFrame_SetQuestMapView", function()
				if Maps:IsActive() then zoom:Setup() end
			end)
		end
		hooksecurefunc("WorldMapFrame_SetPOIMaxBounds", function()
			if Maps:IsActive() then zoom:SetPOIMaxBounds() end
		end)
		hooksecurefunc("WorldMapQuestShowObjectives_AdjustPosition", function()
			if not Maps:IsActive() then return end
			local offset = WorldMapQuestShowObjectivesText:GetWidth()
			if WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
				WorldMapQuestShowObjectives:SetPoint("BOTTOMRIGHT", WorldMapPositioningGuide, "BOTTOMRIGHT", -30 - offset, -9)
			else
				WorldMapQuestShowObjectives:SetPoint("BOTTOMRIGHT", WorldMapPositioningGuide, "BOTTOMRIGHT", -15 - offset, 4)
			end
		end)

		eventFrame = CreateFrame("Frame")
		eventFrame:SetScript("OnEvent", function() zoom:OnMapChanged() end)
	end

	eventFrame:RegisterEvent("WORLD_MAP_UPDATE")
	self:Setup()
end

function zoom:Disable()
	if eventFrame then eventFrame:UnregisterAllEvents() end
	if playerArrow then playerArrow:Hide() end
	if WorldMapPing and origWorldMapPingShow then
		WorldMapPing.Show = origWorldMapPingShow
		origWorldMapPingShow = nil
		if WorldMapPing.SetModelScale then
			WorldMapPing:SetModelScale(1)
		end
	end
end

function zoom:Refresh()
	if not scrollFrame then return end
	updateScrollBounds()
	-- Lowering the maximum zoom below the current level must not leave the map
	-- scrolled past its bounds.
	if WorldMapDetailFrame:GetScale() > maxZoom() then
		self:SetDetailScale(maxZoom())
		updateScrollBounds()
		scrollFrame:SetHorizontalScroll(min(scrollFrame:GetHorizontalScroll(), scrollFrame.maxX or 0))
		scrollFrame:SetVerticalScroll(min(scrollFrame:GetVerticalScroll(), scrollFrame.maxY or 0))
	end
end

return zoom
