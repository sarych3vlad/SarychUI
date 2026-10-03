-- SarychUI Arena - live options preview (3 classic arena frames + trinket/racial).

local CreateFrame = CreateFrame
local GetTime = GetTime
local ipairs = ipairs
local pairs = pairs
local floor = math.floor
local tinsert = table.insert
local tonumber = tonumber
local format = string.format

SarychUI = SarychUI or {}

local function Tr(s)
	if type(s) ~= "string" or s == "" then return s end
	if SarychUI.T then return SarychUI:T(s) end
	return s
end

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
		if SarychUI and SarychUI.ApplyOptionsPreviewLive then
			SarychUI.ApplyOptionsPreviewLive(self, key, value)
		else
			self:RefreshAll()
		end
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
SarychUI.ArenaPreview = MakeBucket("ArenaPreview")
local Preview = SarychUI.ArenaPreview

-- Blizzard ArenaEnemyFrameTemplate: 102x32
local ROW_W, ROW_H = 102, 32
local ICON = 26
local GAP = 8

local SAMPLES = {
	{ name = "Воин", class = "WARRIOR", hp = 0.82, mana = 0.35 },
	{ name = "Жрец", class = "PRIEST", hp = 0.61, mana = 0.78 },
	{ name = "Маг", class = "MAGE", hp = 0.44, mana = 0.92 },
}

local function ArenaDB()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods.arena or {}
end

local function Live(key, fallback)
	local live = Preview._live
	if live[key] ~= nil then
		return live[key]
	end
	local db = ArenaDB()
	local v = db[key]
	if v == nil then return fallback end
	return v
end

local function LiveFlag(key, fallback)
	local v = Live(key, fallback)
	return v == 1 or v == true
end

local function TrinketsDB()
	local live = Preview._live
	local db = ArenaDB()
	local tr = db.Trinkets or {}
	local enabled = live.trinketEnabled
	if enabled == nil then enabled = tr.enabled end
	if enabled == nil then enabled = true end
	local racial = live.racialEnabled
	if racial == nil then racial = tr.racialEnabled end
	if racial == nil then racial = true end
	local scale = tonumber(live.trinketsScale)
	if scale == nil then scale = tonumber(tr.scale) or 1.0 end
	return enabled == true or enabled == 1, racial == true or racial == 1, scale
end

local function ClassColor(class)
	local colors = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if colors then
		return colors.r, colors.g, colors.b
	end
	return 0.2, 0.8, 0.2
end

local function SetClassIcon(tex, class)
	tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
	local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if coords then
		tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		tex:SetTexCoord(0, 1, 0, 1)
	end
end

-- Same pattern as modules/cc/previews.lua MakeActionButton /
-- mainmenubar ActionBarTransparencyPreview: icon + CD swipe + Quickslot border ON TOP.
local function MakeIcon(parent, texture)
	local btn = CreateFrame("Frame", nil, parent)
	btn:SetSize(ICON, ICON)
	btn:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON - 2, ICON - 2)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
	icon:SetTexture(texture)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	btn.icon = icon

	local cooldown = CreateFrame("Cooldown", nil, btn)
	cooldown:SetAllPoints(icon)
	cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)
	cooldown.__sary_cc_noCount = true
	if cooldown.SetDrawEdge then
		cooldown:SetDrawEdge(true)
	end
	btn._cooldown = cooldown

	-- Border above icon (and above swipe rim) - same as Панель действий NormalTexture.
	local borderHost = CreateFrame("Frame", nil, btn)
	borderHost:SetAllPoints()
	borderHost:SetFrameLevel(btn:GetFrameLevel() + 3)
	local slot = borderHost:CreateTexture(nil, "OVERLAY")
	slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	slot:SetSize(ICON + 14, ICON + 14)
	slot:SetPoint("CENTER", btn, "CENTER", 0, 0)
	btn._border = slot
	btn._borderHost = borderHost

	local textHost = CreateFrame("Frame", nil, btn)
	textHost:SetAllPoints(btn)
	textHost:SetFrameLevel(btn:GetFrameLevel() + 6)
	local cdText = textHost:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	cdText:SetPoint("CENTER", btn, "CENTER", 0, 1)
	cdText:SetJustifyH("CENTER")
	cdText:SetWidth(40)
	cdText:SetShadowColor(0, 0, 0, 1)
	cdText:SetShadowOffset(1, -1)
	btn._cdText = cdText

	-- Compat aliases used by Layout show/hide.
	btn.iconFrame = btn
	btn.Icon = btn
	btn._remain = 18
	btn._cdEnds = nil
	return btn
end

local function FormatCdText(remain)
	remain = tonumber(remain) or 0
	if remain < 0 then remain = 0 end
	if remain >= 60 then
		return format("%dм", floor(remain / 60 + 0.5))
	end
	return tostring(floor(remain + 0.5))
end

local function StartPreviewCooldown(btn, forceRestart)
	if not btn or not btn._cooldown then return end
	local remain = tonumber(btn._remain) or 18
	local now = GetTime()
	if not forceRestart and btn._cdEnds and now < (btn._cdEnds - 0.05) then
		return
	end
	-- Mid-swipe look (same as CC action-button preview).
	local duration = remain * 1.35
	local start = now - (duration - remain)
	btn._cooldown:Show()
	btn._cooldown:SetCooldown(start, duration)
	btn._cdEnds = start + duration
	if btn._cdText then
		btn._cdText:SetText(FormatCdText(remain))
		btn._cdText:Show()
	end
end

local function TickPreviewCooldown(btn)
	if not btn or not btn:IsShown() or not btn._cooldown then return end
	local now = GetTime()
	local ends = btn._cdEnds
	if not ends or now >= (ends - 0.05) then
		StartPreviewCooldown(btn, true)
		return
	end
	if btn._cdText then
		btn._cdText:SetText(FormatCdText(ends - now))
	end
end

local function MakeRow(parent, sample)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(ROW_W, ROW_H)

	-- BACKGROUND (under chrome): class portrait + dark fill - ArenaEnemyFrameTemplate.
	local portrait = row:CreateTexture(nil, "BACKGROUND")
	portrait:SetSize(30, 30)
	portrait:SetPoint("TOPRIGHT", -1, -4)
	SetClassIcon(portrait, sample.class)
	row.portrait = portrait

	local fill = row:CreateTexture(nil, "BACKGROUND")
	fill:SetSize(72, 17)
	fill:SetPoint("TOPLEFT", 2, -10)
	fill:SetTexture("Interface\\Buttons\\WHITE8X8")
	fill:SetVertexColor(0, 0, 0, 0.5)

	-- Visible bars fill the dark cutout (72x17). XML StatusBar AbsDimension 42x4
	-- is the interactive hit-box; the painted bar spans the background region.
	local health = CreateFrame("StatusBar", nil, row)
	health:SetSize(70, 8)
	health:SetPoint("TOPLEFT", 3, -11)
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(tonumber(sample.hp) or 0)
	health:SetFrameLevel(row:GetFrameLevel() + 1)
	row.health = health

	local mana = CreateFrame("StatusBar", nil, row)
	mana:SetSize(70, 7)
	mana:SetPoint("TOPLEFT", 3, -19)
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(tonumber(sample.mana) or 0)
	mana:SetStatusBarColor(0.2, 0.35, 0.95)
	mana:SetFrameLevel(row:GetFrameLevel() + 1)
	row.mana = mana

	-- Frame chrome ON TOP (Blizzard ArenaEnemyFrameTexture).
	local chromeHost = CreateFrame("Frame", nil, row)
	chromeHost:SetAllPoints()
	chromeHost:SetFrameLevel(row:GetFrameLevel() + 5)
	local chrome = chromeHost:CreateTexture(nil, "ARTWORK")
	chrome:SetSize(102, 32)
	chrome:SetPoint("TOPLEFT", 0, -2)
	chrome:SetTexture("Interface\\ArenaEnemyFrame\\UI-ArenaTargetingFrame")
	chrome:SetTexCoord(0.0, 0.796, 0.0, 0.5)
	chrome:SetVertexColor(1, 1, 1, 1)
	row.chrome = chrome
	row.chromeHost = chromeHost

	local name = chromeHost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	name:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 24)
	name:SetJustifyH("LEFT")
	name:SetText(Tr(sample.name))
	row.name = name

	local trinket = MakeIcon(row, "Interface\\Icons\\inv_jewelry_trinketpvp_02")
	trinket:SetPoint("LEFT", row, "RIGHT", 2, -2)
	trinket._remain = 45
	row.trinket = trinket

	local racial = MakeIcon(row, "Interface\\Icons\\racial_orc_berserkerstrength")
	racial:SetPoint("LEFT", trinket, "RIGHT", 5, 0)
	racial._remain = 90
	row.racial = racial

	row.class = sample.class
	return row
end

function Preview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(3 * (ROW_H + GAP) + 24)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 10, -10)
	stage:SetPoint("BOTTOMRIGHT", -10, 10)

	-- Stack centered in the preview panel (frame + trinket/racial to the right).
	local STACK_W = ROW_W + 2 + ICON + 5 + ICON + 12
	local STACK_H = 3 * ROW_H + 2 * GAP
	local stack = CreateFrame("Frame", nil, stage)
	stack:SetSize(STACK_W, STACK_H)
	stack:SetPoint("CENTER", stage, "CENTER", 0, 0)
	host._stack = stack

	local rows = {}
	for i, sample in ipairs(SAMPLES) do
		local row = MakeRow(stack, sample)
		if i == 1 then
			row:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, 0)
		else
			row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -GAP)
		end
		rows[i] = row
	end
	host._rows = rows
	host._t = 0

	local function LayoutLive()
		local scale = tonumber(Live("scale", 1.0)) or 1.0
		if scale < 0.5 then scale = 0.5 elseif scale > 2 then scale = 2 end
		local classColor = LiveFlag("classColorHP", true)
		local trinketsOn, racialOn, iconScale = TrinketsDB()
		local distanceAlpha = LiveFlag("distanceAlpha", false) and LiveFlag("useAwesomeWotlk", false)
		local farAlpha = distanceAlpha and 0.5 or 1.0

		stack:SetScale(scale)
		stack:ClearAllPoints()
		stack:SetPoint("CENTER", stage, "CENTER", 0, 0)

		for i, row in ipairs(rows) do
			local r, g, b
			if classColor then
				r, g, b = ClassColor(row.class)
			else
				r, g, b = 0.0, 0.85, 0.0
			end
			row.health:SetStatusBarColor(r, g, b)

			row.trinket:SetScale(iconScale)
			row.racial:SetScale(iconScale)

			if trinketsOn then
				row.trinket:Show()
				row.trinket.iconFrame:Show()
				row.racial:ClearAllPoints()
				row.racial:SetPoint("LEFT", row.trinket, "RIGHT", 5, 0)
			else
				row.trinket:Hide()
				row.trinket.iconFrame:Hide()
				row.racial:ClearAllPoints()
				row.racial:SetPoint("LEFT", row, "RIGHT", 2, -2)
			end

			if racialOn then
				row.racial:Show()
				row.racial.iconFrame:Show()
			else
				row.racial:Hide()
				row.racial.iconFrame:Hide()
			end

			row:SetAlpha(i == 1 and 1.0 or farAlpha)
		end
	end

	local function Layout()
		LayoutLive()
		local trinketsOn, racialOn = TrinketsDB()
		for _, row in ipairs(rows) do
			if trinketsOn then
				StartPreviewCooldown(row.trinket, true)
			end
			if racialOn then
				StartPreviewCooldown(row.racial, true)
			end
		end
	end

	host.LayoutLive = LayoutLive
	host.RefreshStyle = LayoutLive
	host.Refresh = Layout
	host:SetScript("OnShow", function()
		Layout()
	end)
	if SarychUI and SarychUI.BindOptionsPreviewAnim then
		SarychUI.BindOptionsPreviewAnim(host, function(self, elapsed)
			self._t = (self._t or 0) + elapsed
			if self._t < 0.1 then return end
			self._t = 0
			for _, row in ipairs(rows) do
				TickPreviewCooldown(row.trinket)
				TickPreviewCooldown(row.racial)
			end
		end)
	else
		host:SetScript("OnUpdate", function(self, elapsed)
			self._t = (self._t or 0) + elapsed
			if self._t < 0.1 then return end
			self._t = 0
			for _, row in ipairs(rows) do
				TickPreviewCooldown(row.trinket)
				TickPreviewCooldown(row.racial)
			end
		end)
	end

	Layout()
	tinsert(self._instances, host)
	return host
end

--------------------------------------------------------------------
SarychUI.ArenaNumbersPreview = MakeBucket("ArenaNumbersPreview")
local NumbersPreview = SarychUI.ArenaNumbersPreview
NumbersPreview._activeKey = nil

local NP_PREVIEW_H = 152
local NP_PLATE_W = 110
local NP_PLATE_H = 12
local NP_COLUMN_GAP = 54
local NP_ACTIVE = { 1, 0.82, 0.2, 1 }
local NP_SAMPLES = {
	{ name = "Воин", class = "WARRIOR", hp = 0.82, mana = 0.35 },
	{ name = "Жрец", class = "PRIEST", hp = 0.61, mana = 0.78 },
	{ name = "Маг", class = "MAGE", hp = 0.44, mana = 0.92 },
}

function NumbersPreview:SetActiveKey(key)
	self._activeKey = key
	self:RefreshAll()
end

function NumbersPreview:SetLiveValue(key, value)
	self._live[key] = value
	self._activeKey = key
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, value)
	else
		self:RefreshAll()
	end
end

local function NumbersLiveFlag(key, fallback)
	local live = NumbersPreview._live
	if live[key] ~= nil then
		local v = live[key]
		return v == 1 or v == true
	end
	local db = ArenaDB()
	local v = db[key]
	if v == nil then return fallback == true end
	return v == 1 or v == true
end

local function MakeMiniPlate(parent, sample, index)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(NP_PLATE_W, 36)

	local nameFs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameFs:SetPoint("BOTTOM", f, "TOP", 0, -14)
	nameFs:SetTextColor(1, 1, 1)
	f.nameFs = nameFs

	local plate = CreateFrame("Frame", nil, f)
	plate:SetSize(NP_PLATE_W, NP_PLATE_H)
	plate:SetPoint("BOTTOM", 0, 2)
	plate:SetFrameLevel((f:GetFrameLevel() or 1) + 1)

	local edge = plate:CreateTexture(nil, "BACKGROUND")
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	edge:SetTexture("Interface\\Buttons\\WHITE8X8")
	edge:SetVertexColor(0, 0, 0, 0.85)

	local bar = plate:CreateTexture(nil, "ARTWORK")
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("BOTTOMLEFT")
	bar:SetWidth(NP_PLATE_W * (sample.hp or 0.7))
	local colors = RAID_CLASS_COLORS and RAID_CLASS_COLORS[sample.class]
	if colors then
		bar:SetTexture("Interface\\Buttons\\WHITE8X8")
		bar:SetVertexColor(colors.r, colors.g, colors.b, 0.95)
	else
		bar:SetTexture("Interface\\Buttons\\WHITE8X8")
		bar:SetVertexColor(0.12, 0.72, 0.12, 0.95)
	end

	local fillBg = plate:CreateTexture(nil, "BACKGROUND")
	fillBg:SetAllPoints()
	fillBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	fillBg:SetVertexColor(0.08, 0.08, 0.08, 0.95)

	f._index = index
	f._sampleName = Tr(sample.name)
	return f
end

function NumbersPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(NP_PREVIEW_H)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -10)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	local plateColumn = CreateFrame("Frame", nil, stage)
	plateColumn:SetSize(NP_PLATE_W, 3 * 36)
	plateColumn:SetPoint("RIGHT", stage, "CENTER", -(NP_COLUMN_GAP / 2), -7)

	local plateTitle = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	plateTitle:SetPoint("BOTTOM", plateColumn, "TOP", 0, 3)
	plateTitle:SetText(Tr("Неймплейты"))
	plateTitle:SetTextColor(0.72, 0.72, 0.72)

	local plates = {}
	for i, sample in ipairs(NP_SAMPLES) do
		local plate = MakeMiniPlate(plateColumn, sample, i)
		plates[i] = plate
		if i == 1 then
			plate:SetPoint("TOP", plateColumn, "TOP", 0, 0)
		else
			plate:SetPoint("TOP", plates[i - 1], "BOTTOM", 0, 0)
		end
	end

	-- Reuse the arena rows from Arena -> Settings, but keep this preview focused
	-- on names: racial and PvP-trinket icons are intentionally hidden here.
	local frameColumnWidth = ROW_W
	local frameColumn = CreateFrame("Frame", nil, stage)
	frameColumn:SetSize(frameColumnWidth, 3 * ROW_H + 2 * GAP)
	frameColumn:SetPoint("LEFT", stage, "CENTER", NP_COLUMN_GAP / 2, -3)

	local frameTitle = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frameTitle:SetPoint("BOTTOM", frameColumn, "TOP", 0, 3)
	frameTitle:SetText(Tr("Арена-фреймы"))
	frameTitle:SetTextColor(0.72, 0.72, 0.72)

	local arenaRows = {}
	for i, sample in ipairs(NP_SAMPLES) do
		local row = MakeRow(frameColumn, sample)
		row.trinket:Hide()
		row.racial:Hide()
		if i == 1 then
			row:SetPoint("TOPLEFT", frameColumn, "TOPLEFT", 0, 0)
		else
			row:SetPoint("TOPLEFT", arenaRows[i - 1], "BOTTOMLEFT", 0, -GAP)
		end
		arenaRows[i] = row
	end

	local function Layout()
		local activeKey = NumbersPreview._activeKey
		local masterHovered = activeKey == "arenaNumbers"
		local plateHovered = activeKey == "arenaNumbersNameplates"
		local framesHovered = activeKey == "arenaNumbersArenaFrames"
		-- Hover only highlights the affected text. The actual preview state always
		-- follows the toggle value, matching the Group/Raid-title preview.
		local enabled = NumbersLiveFlag("arenaNumbers", false)
		local platesNumbered = enabled and NumbersLiveFlag("arenaNumbersNameplates", true)
		local framesNumbered = enabled and NumbersLiveFlag("arenaNumbersArenaFrames", true)

		for i, plate in ipairs(plates) do
			if platesNumbered then
				plate.nameFs:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
				plate.nameFs:SetText(tostring(i))
			else
				plate.nameFs:SetFont(STANDARD_TEXT_FONT, 12, "")
				plate.nameFs:SetText(plate._sampleName)
			end
			if masterHovered or plateHovered then
				plate.nameFs:SetTextColor(NP_ACTIVE[1], NP_ACTIVE[2], NP_ACTIVE[3], 1)
			else
				plate.nameFs:SetTextColor(1, 1, 1, 1)
			end
		end

		for i, row in ipairs(arenaRows) do
			if framesNumbered then
				row.name:SetText(tostring(i))
			else
				row.name:SetText(Tr(NP_SAMPLES[i].name))
			end
			if masterHovered or framesHovered then
				row.name:SetTextColor(NP_ACTIVE[1], NP_ACTIVE[2], NP_ACTIVE[3], 1)
			else
				row.name:SetTextColor(1, 0.82, 0, 1)
			end

			local r, g, b = ClassColor(row.class)
			row.health:SetStatusBarColor(r, g, b)
		end
	end

	host.LayoutLive = Layout
	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	host:SetScript("OnSizeChanged", Layout)
	Layout()
	tinsert(self._instances, host)
	return host
end

--------------------------------------------------------------------
-- Hide Group/Raid titles - player frame (PlayerFrame.xml) + compact party title
--------------------------------------------------------------------
SarychUI.ArenaGroupTitlesPreview = MakeBucket("ArenaGroupTitlesPreview")
local TitlesPreview = SarychUI.ArenaGroupTitlesPreview
TitlesPreview._activeKey = nil

local GT_SCALE = 0.85
local GT_FRAME_W = 232 * GT_SCALE
local GT_FRAME_H = 100 * GT_SCALE
local GT_PREVIEW_H = 110
local GT_ACTIVE = { 1, 0.92, 0.35, 1 }
local GT_INDICATOR = "Interface\\CharacterFrame\\UI-CharacterFrame-GroupIndicator"
local GT_BORDER = "Interface\\TargetingFrame\\UI-TargetingFrame"
local GT_PORTRAIT = "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human"

function TitlesPreview:SetActiveKey(key)
	self._activeKey = key
	self:RefreshAll()
end

function TitlesPreview:SetLiveValue(key, value)
	self._live[key] = value
	self._activeKey = key
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, value)
	else
		self:RefreshAll()
	end
end

local function GS(n)
	return n * GT_SCALE
end

local function TitlesLiveFlag()
	local live = TitlesPreview._live
	if live.hideGroupRaidText ~= nil then
		local v = live.hideGroupRaidText
		return v == 1 or v == true
	end
	local db = ArenaDB()
	return db.hideGroupRaidText == 1 or db.hideGroupRaidText == true
end

-- PlayerFrame.xml: PlayerFrameGroupIndicator (UI-CharacterFrame-GroupIndicator + GROUP n)
local function MakeGroupIndicator(parent)
	local wrap = CreateFrame("Frame", nil, parent)
	wrap:SetHeight(GS(16))
	wrap:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", GS(97), -GS(20))
	wrap:SetFrameLevel((parent:GetFrameLevel() or 1) + 6)

	local left = wrap:CreateTexture(nil, "BACKGROUND")
	left:SetSize(GS(24), GS(16))
	left:SetPoint("TOPLEFT")
	left:SetTexture(GT_INDICATOR)
	left:SetTexCoord(0, 0.1875, 0, 1)
	left:SetAlpha(0.3)

	local right = wrap:CreateTexture(nil, "BACKGROUND")
	right:SetSize(GS(24), GS(16))
	right:SetPoint("TOPRIGHT")
	right:SetTexture(GT_INDICATOR)
	right:SetTexCoord(0.53125, 0.71875, 0, 1)
	right:SetAlpha(0.3)

	local mid = wrap:CreateTexture(nil, "BACKGROUND")
	mid:SetPoint("LEFT", left, "RIGHT")
	mid:SetPoint("RIGHT", right, "LEFT")
	mid:SetHeight(GS(16))
	mid:SetTexture(GT_INDICATOR)
	mid:SetTexCoord(0.1875, 0.53125, 0, 1)
	mid:SetAlpha(0.3)

	local fs = wrap:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("LEFT", wrap, "LEFT", GS(20), -GS(2))
	fs:SetText(Tr(GROUP or "Группа") .. " 1")
	fs:SetAlpha(0.7)
	wrap.left, wrap.right, wrap.mid, wrap.fs = left, right, mid, fs

	wrap:SetWidth((fs:GetStringWidth() or 36) + 40)
	return wrap
end

-- PlayerFrame.xml: 232x100, flipped UI-TargetingFrame, bars 119x12 at 106,-41 / 106,-52
local function MakePreviewPlayer(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(GT_FRAME_W, GT_FRAME_H)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(GS(119), GS(41))
	bg:SetPoint("TOPLEFT", GS(106), -GS(22))
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	local portrait = f:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(GS(64), GS(64))
	portrait:SetPoint("TOPLEFT", GS(42), -GS(12))
	portrait:SetTexture(GT_PORTRAIT)

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetSize(GS(100), GS(12))
	nameFs:SetPoint("CENTER", GS(50), GS(19))
	nameFs:SetJustifyH("CENTER")
	nameFs:SetTextColor(1.0, 0.82, 0)
	local playerName = UnitName and UnitName("player")
	nameFs:SetText((playerName and playerName ~= "") and playerName or Tr("Игрок"))

	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(GS(119), GS(12))
	health:SetPoint("TOPLEFT", GS(106), -GS(41))
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.78)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local mana = CreateFrame("StatusBar", nil, f)
	mana:SetSize(GS(119), GS(12))
	mana:SetPoint("TOPLEFT", GS(106), -GS(52))
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(0.55)
	mana:SetStatusBarColor(0, 0, 1)
	mana:SetFrameLevel(f:GetFrameLevel() + 1)

	local borderFrame = CreateFrame("Frame", nil, f)
	borderFrame:SetAllPoints()
	borderFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints()
	border:SetTexture(GT_BORDER)
	border:SetTexCoord(1.0, 0.09375, 0, 0.78125)

	local level = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	level:SetPoint("CENTER", f, "CENTER", GS(-63), GS(-16))
	level:SetText("80")
	level:SetTextColor(1.0, 0.82, 0)

	f.group = MakeGroupIndicator(f)
	return f
end

function TitlesPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(GT_PREVIEW_H)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 6, -6)
	stage:SetPoint("BOTTOMRIGHT", -6, 6)

	local player = MakePreviewPlayer(stage)
	player:SetPoint("CENTER", stage, "CENTER", 0, -2)

	local function Layout()
		local hovered = TitlesPreview._activeKey == "hideGroupRaidText"
		if TitlesLiveFlag() then
			player.group:Hide()
			return
		end
		player.group:Show()
		local r, g, b = 1, 1, 1
		local textAlpha = 0.7
		if hovered then
			r, g, b = GT_ACTIVE[1], GT_ACTIVE[2], GT_ACTIVE[3]
			textAlpha = 1
		end
		player.group.fs:SetTextColor(r, g, b)
		player.group.fs:SetAlpha(textAlpha)
		player.group.left:SetVertexColor(r, g, b)
		player.group.right:SetVertexColor(r, g, b)
		player.group.mid:SetVertexColor(r, g, b)
	end

	host.LayoutLive = Layout
	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	host:SetScript("OnSizeChanged", Layout)
	Layout()
	tinsert(self._instances, host)
	return host
end
