-- SarychUI Maps: dungeon, travel, spirit and zone-crossing pins.
-- Dataset is modules/map/data/pois.lua (area ID keyed, percent coordinates).
-- Pins sit on WorldMapDetailFrame and are counter-scaled with zoom, the same
-- way Leatrix Maps places WDM atlas icons without Astrolabe.

local Maps = SarychUI.Maps
local Api = Maps.Api
local L = SarychUI.L
local poi = Maps:RegisterComponent("poi", {})

local tinsert = table.insert
local format = string.format

local MEDIA = Maps.MEDIA
local ATLAS = MEDIA .. "objecticonsatlas"
local ATLAS2 = MEDIA .. "objecticonsatlas2"
local ARROW = MEDIA .. "ZoneCrossingArrow"
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"

-- {width, height, left, right, top, bottom, texture, hitWidth, hitHeight}
local ATLAS_ICONS = {
	["Dungeon"]                     = {32, 32, 0.198242, 0.247070, 0.313477, 0.362305},
	["Raid"]                        = {32, 32, 0.198242, 0.247070, 0.364258, 0.413086},
	["TaxiNode_Alliance"]           = {21, 21, 0.534180, 0.565430, 0.535156, 0.566406},
	["TaxiNode_Horde"]              = {21, 21, 0.534180, 0.565430, 0.568359, 0.599609},
	["TaxiNode_Neutral"]            = {21, 21, 0.534180, 0.565430, 0.601562, 0.632812},
	["TaxiNode_Continent_Alliance"] = {28, 28, 0.778320, 0.840820, 0.127930, 0.190430},
	["TaxiNode_Continent_Horde"]    = {28, 28, 0.907227, 0.969727, 0.127930, 0.190430},
	["TaxiNode_Continent_Neutral"]  = {28, 28, 0.133789, 0.196289, 0.256836, 0.319336},
	["Spirit"]                      = {32, 32, 827/1024, 859/1024, 655/1024, 687/1024, ATLAS2},
	["Arrow"]                       = {64, 64, 0, 1, 0, 1, ARROW, 33, 39},
}

local pinColors = {
	["Spirit"] = {0.1, 0.9, 0.1},
	["Arrow"]  = {1.0, 0.9, 0.0},
}

local pinPool = {}
local activePins = {}
local pinCounter = 0
local eventFrame
local playerFaction

local function pinOnEnter(self)
	WorldMapFrame.poiHighlight = 1
	if self.glow then
		self.glow:SetAlpha(0.7)
	end
	if self.description and self.description ~= "" then
		WorldMapFrameAreaLabel:SetText(self.name)
		WorldMapFrameAreaDescription:SetText(self.description)
	else
		WorldMapFrameAreaLabel:SetText(self.name)
		WorldMapFrameAreaDescription:SetText("")
	end
end

local function pinOnLeave(self)
	WorldMapFrame.poiHighlight = nil
	if self.glow then
		self.glow:SetAlpha(0)
	end
	WorldMapFrameAreaLabel:SetText(WorldMapFrame.areaName)
	WorldMapFrameAreaDescription:SetText("")
end

local function colorCode(r, g, b)
	return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function acquirePin()
	local pin = table.remove(pinPool)
	if not pin then
		pinCounter = pinCounter + 1
		local name = "SarychUIMapPOI" .. pinCounter
		pin = CreateFrame("Button", name, WorldMapButton or WorldMapDetailFrame)
		pin:SetWidth(32)
		pin:SetHeight(32)
		pin:EnableMouse(true)
		pin:RegisterForClicks("LeftButtonUp")
		pin.tex = pin:CreateTexture(name .. "Texture", "BACKGROUND")
		pin.tex:SetWidth(16)
		pin.tex:SetHeight(16)
		pin.tex:SetPoint("CENTER", 0, 0)
		pin.tex:SetTexture(ATLAS)
		pin.glow = pin:CreateTexture(name .. "GlowTexture", "OVERLAY")
		pin.glow:SetAllPoints(pin.tex)
		pin.glow:SetTexture(ATLAS)
		pin.glow:SetBlendMode("ADD")
		pin.glow:SetAlpha(0)
		pin.hi = pin:CreateTexture(name .. "HighlightTexture", "HIGHLIGHT")
		pin.hi:SetAllPoints(pin.tex)
		pin.hi:SetTexture(ATLAS)
		pin.hi:SetBlendMode("ADD")
		pin.hi:SetAlpha(0.4)
	end
	pin:SetParent(WorldMapButton or WorldMapDetailFrame)
	if WorldMapButton then
		pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 10)
	end
	pin:EnableMouse(true)
	pin:Show()
	return pin
end

local function releasePin(pin)
	pin:Hide()
	pin:ClearAllPoints()
	pin:SetScript("OnEnter", nil)
	pin:SetScript("OnLeave", nil)
	pin:SetScript("OnMouseUp", nil)
	tinsert(pinPool, pin)
end

local function releaseAll()
	for i = #activePins, 1, -1 do
		releasePin(activePins[i])
		activePins[i] = nil
	end
end

local function positionPin(pin)
	local zoom = WorldMapDetailFrame:GetScale()
	if not zoom or zoom <= 0 then
		zoom = 1
	end
	pin:SetScale(1 / zoom)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", pin.px * zoom, pin.py * zoom)
end

function poi:Rescale()
	for i = 1, #activePins do
		positionPin(activePins[i])
	end
end

local function shouldShow(pType)
	if pType == "Dungeon" or pType == "Raid" or pType == "Dunraid" then
		return Maps:Get("showDungeon") ~= false
	end
	if pType == "Spirit" then
		return Maps:Get("showSpirit") == true
	end
	if pType == "Arrow" then
		return Maps:Get("showArrow") ~= false
	end

	if not playerFaction then
		playerFaction = UnitFactionGroup("player")
	end

	local ownFlight = Maps:Get("showFlight") ~= false
	local oppFlight = Maps:Get("showFlightOpposite") == true
	local ownTravel = Maps:Get("showTravel") ~= false
	local oppTravel = Maps:Get("showTravelOpposite") == true

	if pType == "FlightN" then
		return ownFlight
	end
	if pType == "TravelN" then
		return ownTravel
	end
	if pType == "FlightA" then
		if playerFaction == "Alliance" then
			return ownFlight
		end
		return oppFlight
	end
	if pType == "FlightH" then
		if playerFaction == "Horde" then
			return ownFlight
		end
		return oppFlight
	end
	if pType == "TravelA" then
		if playerFaction == "Alliance" then
			return ownTravel
		end
		return oppTravel
	end
	if pType == "TravelH" then
		if playerFaction == "Horde" then
			return ownTravel
		end
		return oppTravel
	end
	return false
end

local function dungeonName(pinInfo, pType)
	local nameText = pinInfo[4] or ""
	local isDungeon = (pType == "Dungeon" or pType == "Raid" or pType == "Dunraid")
	if isDungeon and pinInfo[7] and pinInfo[8] then
		local playerLevel = UnitLevel("player")
		local dMin, dMax = pinInfo[7], pinInfo[8]
		local color
		if GetQuestDifficultyColor then
			if playerLevel < dMin then
				color = GetQuestDifficultyColor(dMin)
			elseif playerLevel > dMax then
				color = GetQuestDifficultyColor(dMax - 2)
			end
		end
		if not color then
			color = { r = 1, g = 0.82, b = 0 }
		end
		local cs = colorCode(color.r, color.g, color.b)
		if dMin ~= dMax then
			nameText = nameText .. " " .. cs .. "(" .. dMin .. "-" .. dMax .. ")|r"
		else
			nameText = nameText .. " " .. cs .. "(" .. dMax .. ")|r"
		end
	end
	return nameText
end

local function applyIcon(pin, pType, pinInfo)
	local atlasIcon = ATLAS_ICONS[pinInfo[6]] or ATLAS_ICONS[pType]
	if atlasIcon then
		local iw, ih = atlasIcon[1], atlasIcon[2]
		local l, r, t, b = atlasIcon[3], atlasIcon[4], atlasIcon[5], atlasIcon[6]
		local tex = atlasIcon[7] or ATLAS
		local hitW, hitH = atlasIcon[8] or iw, atlasIcon[9] or ih
		local rot = (pType == "Arrow") and (pinInfo[12] or 0) or 0
		pin:SetWidth(hitW)
		pin:SetHeight(hitH)
		pin.tex:SetWidth(iw)
		pin.tex:SetHeight(ih)
		pin.tex:SetTexture(tex)
		pin.tex:SetVertexColor(1, 1, 1, 1)
		pin.tex:SetTexCoord(l, r, t, b)
		pin.glow:SetTexture(tex)
		pin.glow:SetTexCoord(l, r, t, b)
		pin.glow:SetAlpha(0)
		pin.hi:SetTexture(tex)
		pin.hi:SetTexCoord(l, r, t, b)
		pin.hi:SetAlpha(0.4)
		-- SetRotation replaces atlas tex coords on clients that have it, so it
		-- is only used for full-file artwork (zone-crossing arrows).
		if pType == "Arrow" then
			Api:SetTextureRotation(pin.tex, rot)
			Api:SetTextureRotation(pin.glow, rot)
			Api:SetTextureRotation(pin.hi, rot)
		end
	else
		pin.tex:SetTexture(FLAT)
		pin.tex:SetTexCoord(0, 1, 0, 1)
		pin.glow:SetTexture("")
		pin.glow:SetAlpha(0)
		pin.hi:SetTexture("")
		pin.hi:SetAlpha(0)
		local col = pinColors[pType]
		if col then
			pin.tex:SetVertexColor(col[1], col[2], col[3], 1)
		else
			pin.tex:SetVertexColor(1, 1, 1, 1)
		end
		pin.tex:SetWidth(14)
		pin.tex:SetHeight(14)
		pin:SetWidth(14)
		pin:SetHeight(14)
	end
end

function poi:Refresh()
	if not Maps:IsActive() then
		releaseAll()
		return
	end
	if not WorldMapFrame:IsShown() then
		return
	end

	local mapID = Api:GetCurrentAreaID()
	releaseAll()

	if Maps:Get("showPOI") == false then
		return
	end

	local data = Maps.PoiData
	if not mapID or not data or not data[mapID] then
		return
	end

	local mapW = WorldMapDetailFrame:GetWidth()
	local mapH = WorldMapDetailFrame:GetHeight()
	if not mapW or mapW == 0 then
		return
	end

	playerFaction = UnitFactionGroup("player")

	local list = data[mapID]
	for i = 1, #list do
		local pinInfo = list[i]
		if pinInfo then
			local pType = pinInfo[1]
			if shouldShow(pType) then
				local pin = acquirePin()
				pin.px = (pinInfo[2] / 100) * mapW
				pin.py = -(pinInfo[3] / 100) * mapH
				positionPin(pin)
				applyIcon(pin, pType, pinInfo)

				pin.name = dungeonName(pinInfo, pType)
				pin.description = pinInfo[5]
				pin.zoneCrossingMapID = (pType == "Arrow") and pinInfo[13] or nil
				pin:SetScript("OnEnter", pinOnEnter)
				pin:SetScript("OnLeave", pinOnLeave)
				pin:SetScript("OnMouseUp", function(self, btn)
					if btn == "LeftButton" and self.zoneCrossingMapID then
						Api:NavigateToAreaID(self.zoneCrossingMapID)
					end
				end)

				tinsert(activePins, pin)
			end
		end
	end
end

local function addSituationalPins()
	if poi._situationalAdded then
		return
	end
	poi._situationalAdded = true
	local data = Maps.PoiData
	if not data then
		return
	end
	local L = Maps.PoiNames or setmetatable({}, { __index = function(_, k) return k end })

	local standingID
	if GetFactionInfoByID then
		local _
		_, _, standingID = GetFactionInfoByID(989)
	end
	if standingID and standingID >= 7 then
		data[482] = data[482] or {}
		tinsert(data[482], {"TravelN", 74.7, 31.4, L["Caverns of Time"], L["Portal from Zephyr"], "TaxiNode_Continent_Neutral"})
	end

	local _, class = UnitClass("player")
	if class == "DRUID" then
		data[242] = data[242] or {}
		tinsert(data[242], {"FlightA", 44.1, 45.2, L["Nighthaven"] .. ", " .. L["Moonglade"], L["Druid only flight point to Darnassus"], "TaxiNode_Alliance"})
		tinsert(data[242], {"FlightH", 44.3, 45.9, L["Nighthaven"] .. ", " .. L["Moonglade"], L["Druid only flight point to Thunder Bluff"], "TaxiNode_Horde"})
	end
end

----------------------------------------------------------------------
-- WDM tracking button: same artwork, anchor and menu as AtlasPOI.
----------------------------------------------------------------------

local filterBtn
local filterMenu

local function loc(key, fallback)
	if L and L[key] then
		return L[key]
	end
	return fallback
end

local function atlasMarkup(iconKey)
	local d = ATLAS_ICONS[iconKey]
	if not d then
		return ""
	end
	local w, h, left, right, top, bottom = d[1], d[2], d[3], d[4], d[5], d[6]
	local tex = d[7] or ATLAS
	local x1 = math.floor(left * 1024 + 0.5)
	local x2 = math.floor(right * 1024 + 0.5)
	local y1 = math.floor(top * 1024 + 0.5)
	local y2 = math.floor(bottom * 1024 + 0.5)
	return format("|T%s:%d:%d:0:0:1024:1024:%d:%d:%d:%d|t ", tex, w, h, x1, x2, y1, y2)
end

local function playerFactionKey(opposite)
	local faction = string.lower(UnitFactionGroup("player") or "Alliance")
	if opposite then
		if faction == "alliance" then
			faction = "horde"
		else
			faction = "alliance"
		end
	end
	return faction
end

local function taxiMenuText(continent, opposite)
	local faction = playerFactionKey(opposite)
	local iconKey
	local text
	if continent then
		if faction == "alliance" then
			iconKey = "TaxiNode_Continent_Alliance"
			text = loc("show_taxinode_continent_alliance_text", "Корабли Альянса")
		else
			iconKey = "TaxiNode_Continent_Horde"
			text = loc("show_taxinode_continent_horde_text", "Дирижабли Орды")
		end
	else
		if faction == "alliance" then
			iconKey = "TaxiNode_Alliance"
			text = loc("show_taxinode_alliance_text", "Полеты Альянса")
		else
			iconKey = "TaxiNode_Horde"
			text = loc("show_taxinode_horde_text", "Полеты Орды")
		end
	end
	return atlasMarkup(iconKey) .. text
end

local function dbOn(key, defaultOn)
	if defaultOn then
		return Maps:Get(key) ~= false
	end
	return Maps:Get(key) == true
end

local function toggleKey(key, defaultOn)
	Maps:Set(key, not dbOn(key, defaultOn))
	poi:Refresh()
	if Maps.zoneinfo and Maps.zoneinfo.Refresh then
		Maps.zoneinfo:Refresh()
	end
	if Maps.coords and Maps.coords.Refresh then
		Maps.coords:Refresh()
	end
end

local function buildFilterMenu()
	return {
		{
			text = loc("atlas_tracking_title_text", "Показать:"),
			isTitle = true,
			notCheckable = 1,
		},
		{
			text = taxiMenuText(false, false),
			keepShownOnClick = 1,
			checked = function()
				return dbOn("showFlight", true)
			end,
			func = function()
				toggleKey("showFlight", true)
			end,
			hasArrow = true,
			menuList = {
				{
					text = taxiMenuText(false, true),
					keepShownOnClick = 1,
					checked = function()
						return dbOn("showFlightOpposite", false)
					end,
					func = function()
						toggleKey("showFlightOpposite", false)
					end,
				},
			},
		},
		{
			text = taxiMenuText(true, false),
			keepShownOnClick = 1,
			checked = function()
				return dbOn("showTravel", true)
			end,
			func = function()
				toggleKey("showTravel", true)
			end,
			hasArrow = true,
			menuList = {
				{
					text = taxiMenuText(true, true),
					keepShownOnClick = 1,
					checked = function()
						return dbOn("showTravelOpposite", false)
					end,
					func = function()
						toggleKey("showTravelOpposite", false)
					end,
				},
			},
		},
		{
			text = loc("show_instance_text", "Входы в подземелья"),
			keepShownOnClick = 1,
			checked = function()
				return dbOn("showDungeon", true)
			end,
			func = function()
				toggleKey("showDungeon", true)
			end,
		},
		{
			text = loc("show_zonelevel_text", "Уровни локаций"),
			keepShownOnClick = 1,
			checked = function()
				return dbOn("zoneInfo", true)
			end,
			func = function()
				toggleKey("zoneInfo", true)
			end,
		},
		{
			text = loc("Map Coordinates", "Координаты"),
			keepShownOnClick = 1,
			checked = function()
				return dbOn("showCoords", true)
			end,
			func = function()
				toggleKey("showCoords", true)
			end,
		},
		{
			text = loc("Map POI Spirit", "Целители душ"),
			keepShownOnClick = 1,
			checked = function()
				return dbOn("showSpirit", false)
			end,
			func = function()
				toggleKey("showSpirit", false)
			end,
		},
		{
			text = loc("Map POI Crossings", "Переходы зон"),
			keepShownOnClick = 1,
			checked = function()
				return dbOn("showArrow", true)
			end,
			func = function()
				toggleKey("showArrow", true)
			end,
		},
	}
end

local function updateFilterButtonScale()
	if not filterBtn or not filterBtn.GetParent then
		return
	end

	-- This is map chrome, not a map pin. Keep it outside WorldMapButton and
	-- WorldMapDetailFrame so canvas zoom and panning cannot move it.
	local viewport = Maps.scrollFrame
	if WorldMapFrame and viewport then
		if filterBtn:GetParent() ~= WorldMapFrame then
			filterBtn:SetParent(WorldMapFrame)
		end
		filterBtn:ClearAllPoints()
		filterBtn:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", -4, -4)
		filterBtn:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 20)
	end

	local parent = filterBtn:GetParent()
	if not parent then
		return
	end
	local parentScale = parent.GetEffectiveScale and parent:GetEffectiveScale() or parent:GetScale() or 1
	local frameScale = WorldMapFrame and WorldMapFrame.GetEffectiveScale and WorldMapFrame:GetEffectiveScale() or 1
	if parentScale == 0 then
		parentScale = 1
	end
	filterBtn:SetScale(frameScale / parentScale)
end

function poi:UpdateMapSize(windowed)
	updateFilterButtonScale()
	if filterBtn then
		if windowed and Maps:Get("hideBorder") and not WorldMapFrame:IsMouseOver() then
			filterBtn:Hide()
		elseif not (Maps.worldmap and Maps.worldmap.elementsHidden) then
			filterBtn:Show()
		end
	end
	if WorldMapFrame and WorldMapFrame:IsShown() then
		self:Refresh()
	end
end

local function createFilterButton()
	if filterBtn then
		return
	end

	local parent = WorldMapFrame
	local anchor = Maps.scrollFrame or WorldMapFrame
	filterBtn = CreateFrame("Button", "SarychUIMapPOIFilterButton", parent)
	filterBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	filterBtn:ClearAllPoints()
	filterBtn:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -4, -4)
	filterBtn:SetFrameStrata("TOOLTIP")
	filterBtn:SetFrameLevel(parent:GetFrameLevel() + 2)
	filterBtn:SetWidth(32)
	filterBtn:SetHeight(32)
	filterBtn:RegisterForClicks("LeftButtonUp")

	local background = filterBtn:CreateTexture(nil, "BACKGROUND")
	background:SetWidth(25)
	background:SetHeight(25)
	background:SetPoint("TOPLEFT", 2, -4)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

	local icon = filterBtn:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetPoint("TOPLEFT", 6, -5)
	icon:SetTexture("Interface\\Minimap\\Tracking\\None")
	filterBtn.icon = icon

	local border = filterBtn:CreateTexture(nil, "OVERLAY")
	border:SetWidth(54)
	border:SetHeight(54)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	filterMenu = CreateFrame("Frame", "SarychUIMapPOIFilterMenu", UIParent, "UIDropDownMenuTemplate")

	local menuClosedAt = 0
	local function hookMenuHide(list)
		if not list or list._suiPoiHideHooked then
			return
		end
		list._suiPoiHideHooked = true
		list:HookScript("OnHide", function()
			menuClosedAt = GetTime()
		end)
	end

	local function hideFilterMenu()
		if CloseDropDownMenus then
			CloseDropDownMenus()
		end
		if C_CloseDropDownMenus then
			C_CloseDropDownMenus()
		end
		if DropDownList1 then
			DropDownList1:Hide()
		end
		local classicList = _G["C_DropDownList1"]
		if classicList then
			classicList:Hide()
		end
		local classicList2 = _G["C_DropDownList2"]
		if classicList2 then
			classicList2:Hide()
		end
	end

	local function isFilterMenuShown()
		if DropDownList1 and DropDownList1:IsShown() then
			return true
		end
		local classicList = _G["C_DropDownList1"]
		return classicList and classicList:IsShown()
	end

	filterBtn:SetScript("OnClick", function(self)
		hookMenuHide(DropDownList1)
		hookMenuHide(_G["C_DropDownList1"])
		if isFilterMenuShown() or (GetTime() - menuClosedAt) < 0.2 then
			hideFilterMenu()
			return
		end
		local easyMenu = EasyMenu or C_EasyMenu
		if easyMenu then
			easyMenu(buildFilterMenu(), filterMenu, self, 0, 0, "MENU", 0)
		end
	end)

	if Maps.worldmap and Maps.worldmap.elementsToHide then
		tinsert(Maps.worldmap.elementsToHide, filterBtn)
	end
	if (Maps.windowed and Maps:Get("hideBorder") and not WorldMapFrame:IsMouseOver())
		or (Maps.worldmap and Maps.worldmap.elementsHidden) then
		filterBtn:Hide()
	end

	updateFilterButtonScale()
	if not filterBtn.wdmScaleHooked then
		filterBtn.wdmScaleHooked = true
		if Maps.scrollFrame then
			Maps.scrollFrame:HookScript("OnShow", updateFilterButtonScale)
			Maps.scrollFrame:HookScript("OnSizeChanged", updateFilterButtonScale)
		end
		if WorldMapFrame then
			WorldMapFrame:HookScript("OnShow", updateFilterButtonScale)
			WorldMapFrame:HookScript("OnSizeChanged", updateFilterButtonScale)
		end
	end

	-- Questie registers before this component, so its map button may already
	-- exist. Re-anchor it now that the POI filter is available.
	if Maps.questie and Maps.questie.PositionMapButton then
		Maps.questie:PositionMapButton()
	end
end

function poi:Enable()
	addSituationalPins()
	if not eventFrame then
		eventFrame = CreateFrame("Frame")
		eventFrame:SetScript("OnEvent", function()
			if Maps:IsActive() then
				poi:Refresh()
			end
		end)
	end
	eventFrame:RegisterEvent("WORLD_MAP_UPDATE")
	if not poi._onShowHooked then
		poi._onShowHooked = true
		WorldMapFrame:HookScript("OnShow", function()
			if Maps:IsActive() then
				poi:Refresh()
			end
		end)
		WorldMapFrame:HookScript("OnHide", function()
			releaseAll()
		end)
	end
	createFilterButton()
	self:UpdateMapSize(Maps.windowed)
	self:Refresh()
end

function poi:Disable()
	if eventFrame then
		eventFrame:UnregisterAllEvents()
	end
	if filterBtn then
		filterBtn:Hide()
	end
	if CloseDropDownMenus then
		CloseDropDownMenus()
	end
	releaseAll()
end

return poi
