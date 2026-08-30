-- SarychUI Minimap — live options preview.
-- Layout mirrors Blizzard 3.3.5 Minimap.xml / GameTime.xml exactly.

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local GetTime = GetTime
local floor = math.floor

SarychUI = SarychUI or {}

local function ApplyPanelBg(host)
	local T = SarychUI.OptionsTheme
	if T and T.ApplyFlat then
		T:ApplyFlat(host, T.colors.panelBg or { 0.07, 0.07, 0.09, 0.97 }, T.colors.borderSoft)
	else
		local bg = host:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
	end
end

local function MakeBucket(name)
	SarychUI[name] = SarychUI[name] or {}
	local bucket = SarychUI[name]
	bucket._instances = bucket._instances or {}
	bucket._live = bucket._live or {}

	function bucket:SetLiveValue(key, value)
		self._live[key] = value
		self:RefreshAll()
	end

	function bucket:ClearLiveValue(key)
		if key then
			self._live[key] = nil
		else
			for k in pairs(self._live) do
				self._live[k] = nil
			end
		end
	end

	function bucket:RefreshAll()
		local alive = {}
		for _, inst in ipairs(self._instances) do
			if inst and inst.GetParent and inst:GetParent() then
				tinsert(alive, inst)
				if inst.Refresh then inst:Refresh() end
			elseif inst then
				if inst.Hide then inst:Hide() end
				if inst.SetParent then inst:SetParent(nil) end
			end
		end
		self._instances = alive
	end

	function bucket:ClearStickyHosts()
		for _, inst in ipairs(self._instances) do
			if inst then
				if inst.SetScript then
					inst:SetScript("OnUpdate", nil)
					inst:SetScript("OnShow", nil)
					inst:SetScript("OnSizeChanged", nil)
				end
				if inst.SetBackdrop then
					inst:SetBackdrop(nil)
				end
				if inst.Hide then inst:Hide() end
				if inst.ClearAllPoints then inst:ClearAllPoints() end
				if inst.SetParent then inst:SetParent(nil) end
			end
		end
		self._instances = {}
	end

	return bucket
end

--------------------------------------------------------------------
SarychUI.MinimapPreview = MakeBucket("MinimapPreview")
local Preview = SarychUI.MinimapPreview

-- MinimapCluster.xml sizes
local CLUSTER_W, CLUSTER_H = 192, 192
local MAP_SIZE = 140

local function MinimapDB()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods.minimap or {}
end

local function Live(key, fallback)
	local live = Preview._live
	if live[key] ~= nil then
		return live[key]
	end
	local db = MinimapDB()
	local v = db[key]
	if v == nil then return fallback end
	return v
end

local function LiveFlag(key, fallback)
	local v = Live(key, fallback)
	return v == 1 or v == true
end

local function SetShown(frame, shown)
	if not frame then return end
	if shown then frame:Show() else frame:Hide() end
end

-- MiniMapButtonTemplate-style chrome: icon + TrackingBorder ring.
local function MakeTrackingStyleButton(parent, size, iconPath, iconSize)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(25, 25)
	bg:SetPoint("TOPLEFT", 2, -4)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetVertexColor(1, 1, 1, 0.6)

	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(iconSize or 20, iconSize or 20)
	icon:SetPoint("CENTER", -1, 1)
	icon:SetTexture(iconPath)

	local border = f:CreateTexture(nil, "OVERLAY")
	border:SetSize(52, 52)
	border:SetPoint("TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	f.icon = icon
	return f
end

function Preview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	-- Cluster 192 + clock hang below + GameTime hang right; pad for panel.
	host:SetHeight(250)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	--------------------------------------------------------------------
	-- MinimapCluster 192x192 (Minimap.xml)
	--------------------------------------------------------------------
	local cluster = CreateFrame("Frame", nil, stage)
	cluster:SetSize(CLUSTER_W, CLUSTER_H)
	cluster:SetPoint("CENTER", stage, "CENTER", -6, 6)

	-- MinimapBorderTop: 192x32 TOPRIGHT, TexCoords 0.25–1 / 0–0.125
	local borderTop = cluster:CreateTexture(nil, "ARTWORK")
	borderTop:SetSize(192, 32)
	borderTop:SetPoint("TOPRIGHT", cluster, "TOPRIGHT", 0, 0)
	borderTop:SetTexture("Interface\\Minimap\\UI-Minimap-Border")
	borderTop:SetTexCoord(0.25, 1.0, 0.0, 0.125)

	-- MinimapZoneTextButton: 150x12, CENTER of cluster +7,+83
	local zoneBtn = CreateFrame("Frame", nil, cluster)
	zoneBtn:SetSize(150, 12)
	zoneBtn:SetPoint("CENTER", cluster, "CENTER", 7, 83)

	local zoneFs = zoneBtn:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	zoneFs:SetSize(150, 12)
	zoneFs:SetPoint("CENTER", zoneBtn, "TOP", 0, -5)
	zoneFs:SetText("Штормград")
	zoneFs:SetTextColor(1, 0.82, 0)
	zoneFs:SetJustifyH("CENTER")

	--------------------------------------------------------------------
	-- Real Minimap widget: engine clips to a circle (no square terrain).
	-- CENTER relative TOP of cluster +9,-92 (Minimap.xml).
	--------------------------------------------------------------------
	local map = CreateFrame("Minimap", nil, cluster)
	map:SetSize(MAP_SIZE, MAP_SIZE)
	map:SetPoint("CENTER", cluster, "TOP", 9, -92)
	map:EnableMouse(false)
	map:EnableMouseWheel(false)
	map:SetScript("OnMouseDown", nil)
	map:SetScript("OnMouseUp", nil)
	map:SetScript("OnMouseWheel", nil)
	if map.SetZoom and map.GetZoomLevels then
		local levels = map:GetZoomLevels()
		if levels and levels > 1 then
			map:SetZoom(math.min(2, levels - 1))
		end
	end

	--------------------------------------------------------------------
	-- MinimapBackdrop 192x192: CENTER of cluster 0,-20
	-- Buttons are CHILDREN of backdrop (above MinimapBorder ring).
	--------------------------------------------------------------------
	local backdrop = CreateFrame("Frame", nil, cluster)
	backdrop:SetSize(192, 192)
	backdrop:SetPoint("CENTER", cluster, "CENTER", 0, -20)
	backdrop:SetFrameLevel(map:GetFrameLevel() + 3)

	-- Ring texture on backdrop (ARTWORK); buttons sit in Frames above it.
	local ring = backdrop:CreateTexture(nil, "ARTWORK")
	ring:SetAllPoints()
	ring:SetTexture("Interface\\Minimap\\UI-Minimap-Border")
	ring:SetTexCoord(0.25, 1.0, 0.125, 0.875)

	-- MinimapNorthTag: CENTER of Minimap 0,+67
	local north = backdrop:CreateTexture(nil, "OVERLAY")
	north:SetSize(16, 16)
	north:SetPoint("CENTER", map, "CENTER", 0, 67)
	north:SetTexture("Interface\\Minimap\\CompassNorthTag")

	--------------------------------------------------------------------
	-- Buttons parented to MinimapBackdrop (exact XML anchors vs backdrop)
	--------------------------------------------------------------------
	local btnLayer = CreateFrame("Frame", nil, backdrop)
	btnLayer:SetAllPoints()
	btnLayer:SetFrameLevel(backdrop:GetFrameLevel() + 5)

	-- MiniMapTracking: 32x32 TOPLEFT of backdrop 13,-40
	local tracking = MakeTrackingStyleButton(btnLayer, 32, "Interface\\Minimap\\Tracking\\None", 20)
	tracking:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 13, -40)

	-- MiniMapWorldMapButton: 33x33 TOPRIGHT of backdrop -21,-1
	local worldMap = MakeTrackingStyleButton(btnLayer, 33, "Interface\\WorldMap\\UI-World-Icon", 20)
	worldMap:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", -21, -1)

	-- MinimapZoomIn: 32x32 CENTER of backdrop +71,-20
	local zoomIn = CreateFrame("Frame", nil, btnLayer)
	zoomIn:SetSize(32, 32)
	zoomIn:SetPoint("CENTER", backdrop, "CENTER", 71, -20)
	local zoomInTex = zoomIn:CreateTexture(nil, "ARTWORK")
	zoomInTex:SetAllPoints()
	zoomInTex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")

	-- MinimapZoomOut: 32x32 CENTER of backdrop +51,-39
	local zoomOut = CreateFrame("Frame", nil, btnLayer)
	zoomOut:SetSize(32, 32)
	zoomOut:SetPoint("CENTER", backdrop, "CENTER", 51, -39)
	local zoomOutTex = zoomOut:CreateTexture(nil, "ARTWORK")
	zoomOutTex:SetAllPoints()
	zoomOutTex:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up")

	-- GameTimeFrame (calendar): parent=Minimap, TOPRIGHT +20,-17
	local calendar = CreateFrame("Frame", nil, btnLayer)
	calendar:SetSize(40, 40)
	calendar:SetPoint("TOPRIGHT", map, "TOPRIGHT", 20, -17)
	local calTex = calendar:CreateTexture(nil, "ARTWORK")
	calTex:SetAllPoints()
	calTex:SetTexture("Interface\\Calendar\\UI-Calendar-Button")
	calTex:SetTexCoord(0.0, 0.390625, 0.0, 0.78125)
	local calDay = calendar:CreateFontString(nil, "OVERLAY", "GameFontBlack")
	calDay:SetPoint("CENTER", -1, -1)
	calDay:SetText(tostring((GetTime and floor(GetTime() % 28) or 9) + 1))

	-- TimeManagerClockButton: parent=Minimap, CENTER 0,-68
	local clock = CreateFrame("Frame", nil, btnLayer)
	clock:SetSize(60, 28)
	clock:SetPoint("CENTER", map, "CENTER", 0, -68)
	local clockBg = clock:CreateTexture(nil, "BORDER")
	clockBg:SetAllPoints()
	clockBg:SetTexture("Interface\\TimeManager\\ClockBackground")
	clockBg:SetTexCoord(0.015625, 0.8125, 0.015625, 0.390625)
	local clockFs = clock:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	clockFs:SetPoint("CENTER", 0, 0)
	clockFs:SetText("12:34")

	host._borderTop = borderTop
	host._zoomIn = zoomIn
	host._zoomOut = zoomOut
	host._tracking = tracking
	host._calendar = calendar
	host._worldMap = worldMap
	host._clock = clock

	local function Layout()
		-- Fallbacks match core/defaults.lua (SarychUI profile defaults).
		local hideBorder = LiveFlag("hideBorder", true)
		local hideZoom = LiveFlag("hideZoomButtons", true)
		local hideWorld = LiveFlag("hideWorldMapButton", true)
		local hideClock = LiveFlag("hideClock", false)
		local hideTrack = LiveFlag("hideTracking", true)
		local hideCal = LiveFlag("hideCalendar", true)

		-- Module hides MinimapBorderTop only (zone strip), not the circular ring.
		SetShown(borderTop, not hideBorder)
		SetShown(zoomIn, not hideZoom)
		SetShown(zoomOut, not hideZoom)
		SetShown(worldMap, not hideWorld)
		SetShown(clock, not hideClock)
		SetShown(tracking, not hideTrack)
		SetShown(calendar, not hideCal)
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	Layout()
	tinsert(self._instances, host)
	return host
end
