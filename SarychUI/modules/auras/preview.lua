-- SarychUI Auras — live options preview (Target / Focus / ToT + aura icons).

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local tonumber = tonumber

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
SarychUI.AurasPreview = MakeBucket("AurasPreview")
local Preview = SarychUI.AurasPreview

-- Blizzard TargetFrame.lua aura layout constants (3.3.5).
-- LARGE_AURA_SIZE=21, SMALL_AURA_SIZE=17 — most target auras use small.
local AURA_START_X = 5
local AURA_START_Y = 32
local AURA_OFFSET_Y = 3
local AURA_SIZE = 17
local AURA_GAP = 2
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
local function MakeAuraIcon(parent, size, iconPath, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)

	local icon = f:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints()
	icon:SetTexture(iconPath)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	if opts.debuffColor then
		local border = f:CreateTexture(nil, "OVERLAY")
		border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		border:SetPoint("TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", 1, -1)
		local c = opts.debuffColor
		border:SetVertexColor(c[1], c[2], c[3])
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

	return f
end

-- Hostile-target style: debuffs on top row, buffs below (with stealable samples).
local function MakeTargetAuraBlock(parent)
	local block = CreateFrame("Frame", nil, parent)
	-- Two rows of SMALL_AURA_SIZE + gap; width for 5 icons.
	local rowW = 5 * AURA_SIZE + 4 * AURA_GAP
	local h = AURA_SIZE * 2 + AURA_OFFSET_Y
	block:SetSize(rowW, h)

	local debuffs = {}
	for i = 1, 4 do
		local icon = MakeAuraIcon(block, AURA_SIZE, DEBUFF_ICONS[i], {
			debuffColor = DEBUFF_COLORS[((i - 1) % #DEBUFF_COLORS) + 1],
		})
		if i == 1 then
			icon:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
		else
			icon:SetPoint("TOPLEFT", debuffs[i - 1], "TOPRIGHT", AURA_GAP, 0)
		end
		debuffs[i] = icon
	end

	local buffs = {}
	for i = 1, 5 do
		-- Icons 2 and 4 show Stealable (purge / dispel highlight).
		local steal = (i == 2 or i == 4)
		local icon = MakeAuraIcon(block, AURA_SIZE, BUFF_ICONS[((i - 1) % #BUFF_ICONS) + 1], {
			stealable = steal,
		})
		if i == 1 then
			icon:SetPoint("TOPLEFT", debuffs[1], "BOTTOMLEFT", 0, -AURA_OFFSET_Y)
		else
			icon:SetPoint("TOPLEFT", buffs[i - 1], "TOPRIGHT", AURA_GAP, 0)
		end
		buffs[i] = icon
	end

	block._buffs = buffs
	block._debuffs = debuffs
	return block
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

function Preview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	-- Target 100 + auras hang below (~48) + gap + Focus 100 + auras (~48) + pad
	host:SetHeight(320)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 10, -10)
	stage:SetPoint("BOTTOMRIGHT", -10, 10)

	-- Stage wide enough for Target + ToT hanging off the right.
	local stack = CreateFrame("Frame", nil, stage)
	stack:SetSize(300, 300)
	stack:SetPoint("CENTER", stage, "CENTER", -10, 0)

	local target = MakeTargetLike(stack, "Цель", 0.72, 0.55, PORTRAITS[1])
	target:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, 0)

	-- Blizzard: TargetofTargetFrame BOTTOMRIGHT of TargetFrame at -35, -10.
	local tot = MakeToTPreview(stack, "Цель цели", PORTRAITS[5])
	tot:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -35, -10)

	-- ToT debuffs: TOPLEFT relative TOPRIGHT of ToT +4, -10 (TargetFrame.xml).
	local totAuras = MakeToTDebuffs(stack)
	totAuras:SetPoint("TOPLEFT", tot, "TOPRIGHT", 4, -10)

	-- Hostile layout: auras under TargetFrame at AURA_START_X/Y.
	local targetAuras = MakeTargetAuraBlock(stack)
	targetAuras:SetPoint("TOPLEFT", target, "BOTTOMLEFT", AURA_START_X, AURA_START_Y)

	local focus = MakeTargetLike(stack, "Фокус", 0.58, 0.8, PORTRAITS[8])
	-- Sit below target aura block with a small gap.
	focus:SetPoint("TOPLEFT", targetAuras, "BOTTOMLEFT", -AURA_START_X, -16)

	local focusAuras = MakeTargetAuraBlock(stack)
	focusAuras:SetPoint("TOPLEFT", focus, "BOTTOMLEFT", AURA_START_X, AURA_START_Y)

	host._targetAuras = targetAuras
	host._focusAuras = focusAuras
	host._totAuras = totAuras

	local function SetStealableVisible(block, show)
		if not block or not block._buffs then return end
		for _, icon in ipairs(block._buffs) do
			if icon.stealable then
				if show then
					icon.stealable:Show()
				else
					icon.stealable:Hide()
				end
			end
		end
	end

	local function Layout()
		local hideFocus = LiveFlag("hideFocusAuras", true)
		local hideToT = LiveFlag("hideTargetOfTargetAuras", true)
		local showDispel = LiveFlag("enableDispelHighlight", true)

		-- Target auras always visible (no hide toggle).
		targetAuras:Show()
		SetStealableVisible(targetAuras, showDispel)

		if hideFocus then
			focusAuras:Hide()
		else
			focusAuras:Show()
			SetStealableVisible(focusAuras, showDispel)
		end

		if hideToT then
			totAuras:Hide()
		else
			totAuras:Show()
		end
	end

	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	Layout()
	tinsert(self._instances, host)
	return host
end
