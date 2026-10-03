-- SarychUI Auras - live options preview (Target / Focus / ToT + aura icons).

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local tonumber = tonumber

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
SarychUI.AurasPreview = MakeBucket("AurasPreview")
local Preview = SarychUI.AurasPreview

-- Blizzard TargetFrame.lua aura layout constants (3.3.5).
-- LARGE_AURA_SIZE=21, SMALL_AURA_SIZE=17 - most target auras use small.
local AURA_START_X = 5
local AURA_START_Y = 32
local AURA_OFFSET_Y = 3
local AURA_SIZE = 17
local BLIZZ_SMALL = 17
local BLIZZ_LARGE = 21
local BLIZZ_ROW = 122
local TOT_AURA_ROW_WIDTH = 101
local NUM_TOT_AURA_ROWS = 2
local BUFF_OFFSET_X = 3
local DEBUFF_OFFSET_X = 4
local TOT_DEBUFF_SIZE = 12

local PORTRAITS = {
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Human",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-Human",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-Orc",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-NightElf",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-NightElf",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Tauren",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-BloodElf",
}

local BUFF_ICONS = {
	"Interface\\Icons\\Spell_Holy_FlashHeal",
	"Interface\\Icons\\Spell_Nature_Rejuvenation",
	"Interface\\Icons\\Ability_Warrior_BattleShout",
	"Interface\\Icons\\Spell_Magic_LesserInvisibilty",
	"Interface\\Icons\\Spell_Holy_PowerWordShield",
}

local DEBUFF_ICONS = {
	"Interface\\Icons\\Spell_Shadow_ShadowWordPain",
	"Interface\\Icons\\Spell_Frost_FrostBolt02",
	"Interface\\Icons\\Ability_DualWield",
	"Interface\\Icons\\Spell_Nature_FaerieFire",
}

-- DebuffTypeColor-style borders (Blizzard DebuffTypeColor).
local DEBUFF_COLORS = {
	{ 0.80, 0.00, 0.00 }, -- none / physical
	{ 0.20, 0.60, 1.00 }, -- Magic (dispellable)
	{ 0.00, 0.60, 0.00 }, -- Poison
	{ 0.60, 0.00, 1.00 }, -- Curse
}

local function AurasDB()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods.auras or {}
end

local function Live(key, fallback)
	local live = Preview._live
	if live[key] ~= nil then
		return live[key]
	end
	local db = AurasDB()
	local v = db[key]
	if v == nil then return fallback end
	return v
end

local function LiveFlag(key, fallback)
	local v = Live(key, fallback)
	return v == 1 or v == true
end

-- One aura icon (buff or debuff). Optional Stealable glow / debuff border.
local LORTI_GLOSS = [[Interface\AddOns\SarychUI\addons\LortiUI\media\gloss]]

local function ToolsDarkMode()
	local mods = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	local db = mods and mods.tools
	if not (db and db.enabled and (db.enableDarkMode == 1 or db.enableDarkMode == true)) then
		return false
	end
	return true, db.darkModeColor
end

local function MakeAuraIcon(parent, size, iconPath, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f._selfAura = opts.selfAura and true or false

	local dark, color = ToolsDarkMode()
	local icon = f:CreateTexture(nil, "BACKGROUND")
	if dark then
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	else
		icon:SetAllPoints()
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	icon:SetTexture(iconPath)

	if opts.debuffColor then
		local border = f:CreateTexture(nil, "OVERLAY")
		local c = opts.debuffColor
		if dark then
			border:SetTexture(LORTI_GLOSS)
			border:SetTexCoord(0, 1, 0, 1)
			border:SetAllPoints(f)
		else
			border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
			border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
			border:SetPoint("TOPLEFT", -1, 1)
			border:SetPoint("BOTTOMRIGHT", 1, -1)
		end
		border:SetVertexColor(c[1], c[2], c[3])
		f.border = border
	elseif dark then
		local border = f:CreateTexture(nil, "OVERLAY")
		border:SetTexture(LORTI_GLOSS)
		border:SetTexCoord(0, 1, 0, 1)
		border:SetAllPoints(f)
		if color then
			border:SetVertexColor(color.r or 0.37, color.g or 0.37, color.b or 0.37, color.a or 1)
		else
			border:SetVertexColor(0, 0, 0, 0.9)
		end
		f.border = border
	end

	if opts.stealable then
		local steal = f:CreateTexture(nil, "OVERLAY")
		steal:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
		steal:SetBlendMode("ADD")
		steal:SetSize(size + 3, size + 3)
		steal:SetPoint("CENTER", 0, 0)
		f.stealable = steal
	end

	function f:ApplySize(newSize)
		self:SetSize(newSize, newSize)
		if self.stealable then
			self.stealable:SetSize(newSize + 3, newSize + 3)
		end
	end

	return f
end

local function AuraPreviewSizes()
	local custom = LiveFlag("changeFrameAuraSize", false)
	local small = custom and tonumber(Live("frameAuraOtherSize", 23)) or BLIZZ_SMALL
	local large = custom and tonumber(Live("frameAuraSelfSize", 23)) or BLIZZ_LARGE
	local maxRow = custom and tonumber(Live("frameAuraRowWidth", 122)) or BLIZZ_ROW
	return small or BLIZZ_SMALL, large or BLIZZ_LARGE, maxRow or BLIZZ_ROW
end

-- TargetFrame_UpdateBuffAnchor / TargetFrame_UpdateDebuffAnchor (3.3.5).
-- Grow-up flips TOPLEFT/BOTTOMLEFT so new rows stack above the frame.
local function AuraGrowPoints()
	if LiveFlag("frameAurasGrowUp", false) then
		return "BOTTOM", "TOP", tonumber(Live("frameAurasGrowUpY", -17)) or -17
	end
	return "TOP", "BOTTOM", AURA_START_Y
end

local function UpdateBuffAnchor(unitFrame, icons, index, numDebuffs, anchorIndex, size, offsetX, offsetY)
	local buff = icons[index]
	if not buff then return end
	buff:ApplySize(size)
	buff:ClearAllPoints()
	local buffs = unitFrame.buffs
	local debuffs = unitFrame.debuffs
	local point, relativePoint, startY = AuraGrowPoints()
	local stackY = LiveFlag("frameAurasGrowUp", false) and offsetY or -offsetY
	local containerY = LiveFlag("frameAurasGrowUp", false) and AURA_OFFSET_Y or -AURA_OFFSET_Y

	if index == 1 then
		if unitFrame._friendly or numDebuffs == 0 then
			buff:SetPoint(point .. "LEFT", unitFrame, relativePoint .. "LEFT", AURA_START_X, startY)
		else
			buff:SetPoint(point .. "LEFT", debuffs, relativePoint .. "LEFT", 0, stackY)
		end
		buffs:ClearAllPoints()
		buffs:SetPoint(point .. "LEFT", buff, point .. "LEFT", 0, 0)
		buffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, containerY)
	elseif anchorIndex ~= (index - 1) then
		buff:SetPoint(point .. "LEFT", icons[anchorIndex], relativePoint .. "LEFT", 0, stackY)
		buffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, containerY)
	else
		buff:SetPoint(point .. "LEFT", icons[anchorIndex], point .. "RIGHT", offsetX, 0)
	end
end

local function UpdateDebuffAnchor(unitFrame, icons, index, numBuffs, anchorIndex, size, offsetX, offsetY)
	local buff = icons[index]
	if not buff then return end
	buff:ApplySize(size)
	buff:ClearAllPoints()
	local buffs = unitFrame.buffs
	local debuffs = unitFrame.debuffs
	local point, relativePoint, startY = AuraGrowPoints()
	local stackY = LiveFlag("frameAurasGrowUp", false) and offsetY or -offsetY
	local containerY = LiveFlag("frameAurasGrowUp", false) and AURA_OFFSET_Y or -AURA_OFFSET_Y

	if index == 1 then
		if unitFrame._friendly and numBuffs > 0 then
			buff:SetPoint(point .. "LEFT", buffs, relativePoint .. "LEFT", 0, stackY)
		else
			buff:SetPoint(point .. "LEFT", unitFrame, relativePoint .. "LEFT", AURA_START_X, startY)
		end
		debuffs:ClearAllPoints()
		debuffs:SetPoint(point .. "LEFT", buff, point .. "LEFT", 0, 0)
		debuffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, containerY)
	elseif anchorIndex ~= (index - 1) then
		buff:SetPoint(point .. "LEFT", icons[anchorIndex], relativePoint .. "LEFT", 0, stackY)
		debuffs:SetPoint(relativePoint .. "LEFT", buff, relativePoint .. "LEFT", 0, containerY)
	else
		buff:SetPoint(point .. "LEFT", icons[index - 1], point .. "RIGHT", offsetX, 0)
	end
end

-- TargetFrame_UpdateAuraPositions: wrap by maxRowWidth, chain TOPLEFT.
local function UpdateAuraPositions(unitFrame, icons, numOpposite, updateFunc, maxRowWidth, offsetX, small, large, fullRowWidth)
	local offsetY = AURA_OFFSET_Y
	local rowWidth = 0
	local firstOnRow = 1
	local n = #icons
	for i = 1, n do
		local size
		if icons[i]._selfAura then
			size = large
			offsetY = AURA_OFFSET_Y + AURA_OFFSET_Y
		else
			size = small
		end
		if i == 1 then
			rowWidth = size
			unitFrame.auraRows = (unitFrame.auraRows or 0) + 1
		else
			rowWidth = rowWidth + size + offsetX
		end
		if rowWidth > maxRowWidth then
			updateFunc(unitFrame, icons, i, numOpposite, firstOnRow, size, offsetX, offsetY)
			rowWidth = size
			unitFrame.auraRows = (unitFrame.auraRows or 0) + 1
			firstOnRow = i
			offsetY = AURA_OFFSET_Y
			if unitFrame.auraRows > NUM_TOT_AURA_ROWS then
				maxRowWidth = fullRowWidth
			end
		else
			updateFunc(unitFrame, icons, i, numOpposite, i - 1, size, offsetX, offsetY)
		end
	end
end

local function LayoutUnitAuras(unitFrame, haveToT)
	if not unitFrame or not unitFrame._buffIcons then return end
	local small, large, rowW = AuraPreviewSizes()
	local custom = LiveFlag("changeFrameAuraSize", false)
	local growUp = LiveFlag("frameAurasGrowUp", false)
	local totRow = (haveToT and not custom and not growUp) and TOT_AURA_ROW_WIDTH or rowW
	unitFrame.auraRows = 0

	local buffIcons = unitFrame._buffIcons
	local debuffIcons = unitFrame._debuffIcons
	local numBuffs = #buffIcons
	local numDebuffs = #debuffIcons

	-- Same order as TargetFrame_UpdateAuras: buffs, then debuffs.
	UpdateAuraPositions(unitFrame, buffIcons, numDebuffs, UpdateBuffAnchor, totRow, BUFF_OFFSET_X, small, large, rowW)
	local debuffRow = (haveToT and not custom and not growUp and (unitFrame.auraRows or 0) < NUM_TOT_AURA_ROWS) and TOT_AURA_ROW_WIDTH or rowW
	UpdateAuraPositions(unitFrame, debuffIcons, numBuffs, UpdateDebuffAnchor, debuffRow, DEBUFF_OFFSET_X, small, large, rowW)
end

local function AttachAuras(unitFrame, friendly)
	local lvl = (unitFrame:GetFrameLevel() or 1) + 4
	local buffs = CreateFrame("Frame", nil, unitFrame)
	buffs:SetSize(10, 10)
	buffs:SetFrameLevel(lvl)
	local debuffs = CreateFrame("Frame", nil, unitFrame)
	debuffs:SetSize(10, 10)
	debuffs:SetFrameLevel(lvl)
	unitFrame.buffs = buffs
	unitFrame.debuffs = debuffs
	unitFrame._friendly = friendly and true or false

	-- Hostile frame: debuffs on top. Own (large) auras sit together first,
	-- then other (small) auras - same visual as player DoTs leading the row.
	local buffIcons = {}
	for i = 1, 6 do
		buffIcons[i] = MakeAuraIcon(unitFrame, AURA_SIZE, BUFF_ICONS[((i - 1) % #BUFF_ICONS) + 1], {
			stealable = (i == 2 or i == 4),
			selfAura = false,
		})
		buffIcons[i]:SetFrameLevel(lvl)
	end
	local debuffIcons = {}
	for i = 1, 4 do
		debuffIcons[i] = MakeAuraIcon(unitFrame, AURA_SIZE, DEBUFF_ICONS[((i - 1) % #DEBUFF_ICONS) + 1], {
			debuffColor = DEBUFF_COLORS[((i - 1) % #DEBUFF_COLORS) + 1],
			selfAura = (i <= 2),
		})
		debuffIcons[i]:SetFrameLevel(lvl)
	end
	unitFrame._buffIcons = buffIcons
	unitFrame._debuffIcons = debuffIcons
end

local function SetUnitAurasShown(unitFrame, shown)
	if not unitFrame then return end
	local function setList(list)
		if not list then return end
		for _, icon in ipairs(list) do
			if shown then icon:Show() else icon:Hide() end
		end
	end
	setList(unitFrame._buffIcons)
	setList(unitFrame._debuffIcons)
end

local function SetStealableVisible(unitFrame, show)
	if not unitFrame or not unitFrame._buffIcons then return end
	for _, icon in ipairs(unitFrame._buffIcons) do
		if icon.stealable then
			if show then
				icon.stealable:Show()
			else
				icon.stealable:Hide()
			end
		end
	end
end

local function MakeToTDebuffs(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(TOT_DEBUFF_SIZE * 2 + 1, TOT_DEBUFF_SIZE * 2 + 1)
	local icons = {}
	for i = 1, 4 do
		local icon = MakeAuraIcon(row, TOT_DEBUFF_SIZE, DEBUFF_ICONS[((i - 1) % #DEBUFF_ICONS) + 1], {
			debuffColor = DEBUFF_COLORS[1],
		})
		if i == 1 then
			icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		elseif i == 2 then
			icon:SetPoint("LEFT", icons[1], "RIGHT", 1, 0)
		elseif i == 3 then
			icon:SetPoint("TOPLEFT", icons[1], "BOTTOMLEFT", 0, -1)
		else
			icon:SetPoint("LEFT", icons[3], "RIGHT", 1, 0)
		end
		icons[i] = icon
	end
	row._icons = icons
	return row
end

-- TargetFrame-style: portrait RIGHT, bars LEFT (UI-TargetingFrame).
local function MakeTargetLike(parent, label, hp, mana, portraitPath)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(232, 100)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(119, 41)
	bg:SetPoint("TOPRIGHT", -106, -22)
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	local portrait = f:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(64, 64)
	portrait:SetPoint("TOPRIGHT", -42, -12)
	portrait:SetTexture(portraitPath or PORTRAITS[1])
	f.portrait = portrait

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetSize(100, 12)
	nameFs:SetPoint("CENTER", -50, 19)
	nameFs:SetText(label)

	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(119, 12)
	health:SetPoint("TOPRIGHT", -106, -41)
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(hp or 0.7)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local power = CreateFrame("StatusBar", nil, f)
	power:SetSize(119, 12)
	power:SetPoint("TOPRIGHT", -106, -52)
	power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	power:SetMinMaxValues(0, 1)
	power:SetValue(mana or 0.5)
	power:SetStatusBarColor(0, 0, 1)
	power:SetFrameLevel(f:GetFrameLevel() + 1)

	local borderFrame = CreateFrame("Frame", nil, f)
	borderFrame:SetAllPoints()
	borderFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints()
	border:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
	border:SetTexCoord(0.09375, 1.0, 0, 0.78125)

	return f
end

-- TargetofTargetFrameTemplate: 93x45, BOTTOMRIGHT of Target -35,-10.
-- Visual chrome matches UI-TargetofTargetFrame (same family as small targeting frame).
local function MakeToTPreview(parent, label, portraitPath)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(93, 45)

	local portrait = f:CreateTexture(nil, "BACKGROUND")
	portrait:SetSize(35, 35)
	portrait:SetPoint("TOPLEFT", 6, -5)
	portrait:SetTexture(portraitPath or PORTRAITS[3])
	f.portrait = portrait

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetPoint("BOTTOMLEFT", 42, 2)
	nameFs:SetText(label)

	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(46, 7)
	health:SetPoint("TOPRIGHT", -2, -15)
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.65)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local mana = CreateFrame("StatusBar", nil, f)
	mana:SetSize(46, 7)
	mana:SetPoint("TOPRIGHT", -2, -23)
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(0.4)
	mana:SetStatusBarColor(0, 0, 1)
	mana:SetFrameLevel(f:GetFrameLevel() + 1)

	local borderFrame = CreateFrame("Frame", nil, f)
	borderFrame:SetAllPoints()
	borderFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetSize(93, 45)
	border:SetPoint("TOPLEFT", 0, 0)
	border:SetTexture("Interface\\TargetingFrame\\UI-TargetofTargetFrame")
	border:SetTexCoord(0.015625, 0.7265625, 0, 0.703125)

	return f
end

local FRAME_SCALE = 0.85
local FRAME_W = 232
local FRAME_H = 100
local FRAME_GAP = 12
local PREVIEW_H = 158
local GROW_UP_PAD = 80

function Preview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(PREVIEW_H)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 6, -6)
	stage:SetPoint("BOTTOMRIGHT", -6, 6)

	-- Same two-frame row as Frames preview: target left, focus right.
	local wrap = CreateFrame("Frame", nil, stage)
	wrap:SetSize(FRAME_W * 2 + FRAME_GAP, FRAME_H + 72)
	wrap:SetScale(FRAME_SCALE)
	wrap:SetPoint("TOP", stage, "TOP", 0, -2)

	local target = MakeTargetLike(wrap, Tr("Цель"), 0.72, 0.55, PORTRAITS[1])
	target:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)
	AttachAuras(target, false)

	local tot = MakeToTPreview(wrap, Tr("Цель цели"), PORTRAITS[5])
	tot:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -35, -10)
	tot:SetFrameLevel((target:GetFrameLevel() or 1) + 6)

	local totAuras = MakeToTDebuffs(tot)
	totAuras:SetPoint("TOPLEFT", tot, "TOPRIGHT", 4, -10)

	local focus = MakeTargetLike(wrap, Tr("Фокус"), 0.58, 0.8, PORTRAITS[8])
	focus:SetPoint("TOPRIGHT", wrap, "TOPRIGHT", 0, 0)
	AttachAuras(focus, false)

	host._target = target
	host._focus = focus
	host._totAuras = totAuras
	host._tot = tot

	local function Layout()
		local hideFocus = LiveFlag("hideFocusAuras", true)
		local hideTarget = LiveFlag("hideTargetAuras", false)
		local hideToT = LiveFlag("hideTargetOfTargetAuras", true)
		local showDispel = LiveFlag("enableDispelHighlight", true)
		local growUp = LiveFlag("frameAurasGrowUp", false)
		local startY = tonumber(Live("frameAurasGrowUpY", -17)) or -17
		local topPad = growUp and math.max(GROW_UP_PAD, 48 + startY) or 0

		wrap:SetHeight(FRAME_H + (growUp and (topPad + 12) or 72))
		target:ClearAllPoints()
		focus:ClearAllPoints()
		target:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, -topPad)
		focus:SetPoint("TOPRIGHT", wrap, "TOPRIGHT", 0, -topPad)

		if hideToT then
			totAuras:Hide()
		else
			totAuras:Show()
		end

		-- ToT frame stays shown; Blizzard uses that for TOT_AURA_ROW_WIDTH on the first rows.
		LayoutUnitAuras(target, tot:IsShown() and not growUp)
		if hideTarget then
			SetUnitAurasShown(target, false)
		else
			SetUnitAurasShown(target, true)
			SetStealableVisible(target, showDispel)
		end

		LayoutUnitAuras(focus, false)
		if hideFocus then
			SetUnitAurasShown(focus, false)
		else
			SetUnitAurasShown(focus, true)
			SetStealableVisible(focus, showDispel)
		end
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	Layout()
	tinsert(self._instances, host)
	return host
end
