-- SarychUI Arena - live options preview (3 classic arena frames + trinket/racial).

local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
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
    if SarychUI.OptionsPool then return SarychUI.OptionsPool:ClearPreviews(self) end
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
local GAP = 40
local INFO_W = 128
-- Keep a three-row sized panel; fit all five sample rows inside it.
local PREVIEW_WINDOW_H = 3 * 56 + 2 * 32 + 40

local SAMPLES = {
	{ name = SarychUI:T("ui.options_4c5f0585f4"), class = "WARRIOR", hp = 0.82, mana = 0.35 },
	{ name = SarychUI:T("ui.options_73b4a59c4e"), class = "PRIEST", spec = "Discipline", hp = 0.61, mana = 0.78 },
	{ name = SarychUI:T("ui.options_b9a2d8a9c3"), class = "MAGE", spec = "Frost", hp = 0.44, mana = 0.92 },
	{ name = SarychUI:T("ui.options_047fc6fcde"), class = "ROGUE", spec = "Subtlety", hp = 0.77, mana = 0.35 },
	{ name = SarychUI:T("ui.options_c690f9f1ef"), class = "HUNTER", spec = "Marksmanship", hp = 0, mana = 0 },
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
	if key == "frameSpacing" or key == "scale"
		or key == "barWidth" or key == "castBarHeight" or key == "castTextSize" or key == "showSpecText"
		or key == "castBarPos" or key == "showPets" then
		local module = SarychUI.modules and SarychUI.modules.arena
		local style = module and module.GetStyleSettings and module:GetStyleSettings()
		if style and style[key] ~= nil then return style[key] end
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
	local arena = SarychUI.modules and SarychUI.modules.arena
	if arena and arena.IsArenaRacialEnabled then racial = arena:IsArenaRacialEnabled() end
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

-- Same pattern as src/extensions/cc/previews.lua MakeActionButton /
-- mainmenubar ActionBarTransparencyPreview: icon + CD swipe + Quickslot border ON TOP.
local function MakeIcon(parent, texture)
	local btn = CreateFrame("Frame", nil, parent, nil, "arena.preview:1")
	btn:SetSize(ICON, ICON)
	btn:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(btn)
	icon:SetTexture(texture)
	icon:SetTexCoord(0, 1, 0, 1)
	btn.icon = icon

	local cooldown = CreateFrame("Cooldown", nil, btn, nil, "arena.preview:2")
	cooldown:SetAllPoints(btn)
	cooldown:SetFrameLevel(btn:GetFrameLevel() + 1)
	cooldown:SetAlpha(0.65)
	cooldown.__sary_cc_noCount = true
	if cooldown.SetDrawEdge then
		cooldown:SetDrawEdge(true)
	end
	btn._cooldown = cooldown

	local textHost = CreateFrame("Frame", nil, btn, nil, "arena.preview:3")
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
		return format(SarychUI:T("ui.options_40f84160df"), floor(remain / 60 + 0.5))
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
		if not btn._readyUntil then
			btn._readyUntil = now + 5
			btn._cdEnds = nil
			btn._cooldown:Hide()
			if btn._cdText then btn._cdText:Hide() end
			btn.icon:SetDesaturated(false)
			return
		end
		if now < btn._readyUntil then return end
		btn._readyUntil = nil
		StartPreviewCooldown(btn, true)
		btn.icon:SetDesaturated((ArenaDB().Trinkets or {}).desaturateOnCooldown == true)
		return
	end
	if btn._cdText then
		btn._cdText:SetText(FormatCdText(ends - now))
	end
end

local function MakeRow(parent, sample)
	local row = CreateFrame("Frame", nil, parent, nil, "arena.preview:4")
	row:SetSize(ROW_W, ROW_H)

	-- BACKGROUND (under chrome): class portrait + dark fill - ArenaEnemyFrameTemplate.
	local portrait = row:CreateTexture(nil, "BACKGROUND")
	portrait:SetSize(30, 30)
	portrait:SetPoint("TOPRIGHT", -1, -4)
	SetClassIcon(portrait, sample.class)
	row.portrait = portrait
	local specPortrait = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	specPortrait:SetSize(26, 26)
	specPortrait:SetPoint("CENTER", portrait, "CENTER", 0.4, 1.3)
	specPortrait:Hide()
	row.specPortrait = specPortrait
	row.spec = sample.spec
	local classicSpecLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	classicSpecLabel:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
	classicSpecLabel:SetPoint("BOTTOM", portrait, "TOP", 0, 2)
	classicSpecLabel:SetWidth(110)
	classicSpecLabel:SetJustifyH("CENTER")
	classicSpecLabel:SetText(sample.spec or "")
	classicSpecLabel:Hide()
	row.classicSpecLabel = classicSpecLabel

	-- ArenaEnemyFrameTemplate places both 70x8 bars at these exact offsets.
	local health = CreateFrame("StatusBar", nil, row, nil, "arena.preview:5")
	health:SetSize(70, 8)
	health:SetPoint("TOPLEFT", 2, -12)
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(tonumber(sample.hp) or 0)
	health:SetFrameLevel(row:GetFrameLevel() + 1)
	row.health = health

	local mana = CreateFrame("StatusBar", nil, row, nil, "arena.preview:6")
	mana:SetSize(70, 8)
	mana:SetPoint("TOPLEFT", 2, -20)
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(tonumber(sample.mana) or 0)
	mana:SetStatusBarColor(0.2, 0.35, 0.95)
	mana:SetFrameLevel(row:GetFrameLevel() + 1)
	row.mana = mana
	row.barUnderlays = {}
	local function AddUnderlay(region, inset)
		local texture = row:CreateTexture(nil, "BACKGROUND", nil, -1)
		texture:SetTexture("Interface\\Buttons\\WHITE8X8")
		texture:SetVertexColor(0, 0, 0, 0.5)
		texture:SetPoint("TOPLEFT", region, "TOPLEFT", inset, -inset)
		texture:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -inset, inset)
		row.barUnderlays[#row.barUnderlays + 1] = texture
	end
	AddUnderlay(health, 0)
	AddUnderlay(mana, 0)
	AddUnderlay(portrait, 1)

	-- Frame chrome ON TOP (Blizzard ArenaEnemyFrameTexture).
	local chromeHost = CreateFrame("Frame", nil, row, nil, "arena.preview:7")
	chromeHost:SetAllPoints()
	chromeHost:SetFrameLevel(row:GetFrameLevel() + 2)
	local chrome = chromeHost:CreateTexture(nil, "BACKGROUND")
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
	row.nameR, row.nameG, row.nameB, row.nameA = name:GetTextColor()

	local trinket = MakeIcon(row, "Interface\\Icons\\inv_jewelry_trinketpvp_02")
	trinket:SetPoint("LEFT", row, "RIGHT", 2, -2)
	trinket._remain = 45
	row.trinket = trinket

	local racial = MakeIcon(row, "Interface\\Icons\\racial_orc_berserkerstrength")
	racial:SetPoint("LEFT", trinket, "RIGHT", 5, 0)
	racial._remain = 90
	row.racial = racial
	row.procIcons = {
		MakeIcon(row, select(3, GetSpellInfo(71485)) or "Interface\\Icons\\INV_Misc_QuestionMark"),
		MakeIcon(row, select(3, GetSpellInfo(71605)) or "Interface\\Icons\\INV_Misc_QuestionMark"),
	}
	for index, proc in ipairs(row.procIcons) do
		local spellID = index == 1 and 71485 or 71605
		local itemID = index == 1 and 50362 or 50360
		proc.procTexture = select(3, GetSpellInfo(spellID))
		proc.itemTexture = select(10, GetItemInfo(itemID))
			or "Interface\\Icons\\inv_jewelry_trinketpvp_02"
		proc.procTexture = proc.procTexture or proc.itemTexture
		proc.icon:SetTexCoord(0, 1, 0, 1)
		proc._remain = 42
		proc.equippedBorder = proc:CreateTexture(nil, "OVERLAY")
		proc.equippedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		proc.equippedBorder:SetBlendMode("ADD")
		proc.equippedBorder:SetPoint("CENTER")
		proc.equippedBorder:SetSize(ICON * 62 / 36, ICON * 62 / 36)
		proc.equippedBorder:SetVertexColor(0, 1, 0, 0.35)
		proc.pulseBorder = proc:CreateTexture(nil, "OVERLAY")
		proc.pulseBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		proc.pulseBorder:SetBlendMode("ADD")
		proc.pulseBorder:SetPoint("CENTER")
		proc.pulseBorder:SetSize(48, 48)
		proc.pulseBorder:SetVertexColor(1, 0.82, 0.28)
		proc.pulseBorder:Hide()
		proc:SetScript("OnUpdate", function(self)
			if self.pulseBorder:IsShown() and self._pulseStartedAt then
				self.pulseBorder:SetAlpha(0.65 + 0.35 * math.cos(
					(GetTime() - self._pulseStartedAt) * (2 * math.pi / 1.1)))
			end
		end)
	end

	row.class = sample.class
	if ArenaDB().frameType == "gladius" then
		for index = 1, #row.barUnderlays do row.barUnderlays[index]:Hide() end
		local barTexture = [[Interface\AddOns\SarychUI\media\arena\Minimalist]]
		row:SetSize(190, 56)
		chrome:SetAlpha(0)
		portrait:ClearAllPoints()
		portrait:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 0)
		portrait:SetSize(40, 41)
		if CLASS_BUTTONS and CLASS_BUTTONS[sample.class] then
			portrait:SetTexture([[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]])
			portrait:SetTexCoord(unpack(CLASS_BUTTONS[sample.class]))
		end
		health:ClearAllPoints()
		health:SetPoint("TOPLEFT", row, "TOPLEFT", 40, 0)
		health:SetSize(150, 25)
		health:SetStatusBarTexture(barTexture)
		local healthBg = health:CreateTexture(nil, "BACKGROUND")
		healthBg:SetAllPoints(health)
		healthBg:SetTexture("Interface\\Buttons\\WHITE8X8")
		healthBg:SetVertexColor(0, 0, 0, 1)
		healthBg:SetAlpha(0.4)
		local healthText = health:CreateFontString(nil, "OVERLAY")
		row.healthText = healthText
		healthText:SetFont(STANDARD_TEXT_FONT, 11)
		healthText:SetPoint("RIGHT", health, "RIGHT", -5, 0)
		healthText:SetText(sample.hp > 0 and format("%d%%", floor(sample.hp * 100 + 0.5)) or "")
		healthText:SetShadowOffset(1, -1)
		healthText:SetShadowColor(0, 0, 0, 1)
		mana:ClearAllPoints()
		mana:SetPoint("TOPLEFT", row, "TOPLEFT", 40, -26)
		mana:SetSize(150, 15)
		mana:SetStatusBarTexture(barTexture)
		if sample.class == "WARRIOR" then mana:SetStatusBarColor(1, 0, 0)
		elseif sample.class == "ROGUE" then mana:SetStatusBarColor(1, 1, 0)
		else mana:SetStatusBarColor(0.18, 0.44, 0.75) end
		local manaBg = mana:CreateTexture(nil, "BACKGROUND")
		manaBg:SetAllPoints(mana)
		manaBg:SetTexture("Interface\\Buttons\\WHITE8X8")
		manaBg:SetVertexColor(0, 0, 0, 1)
		manaBg:SetAlpha(0.4)
		local manaText = mana:CreateFontString(nil, "OVERLAY")
		row.manaText = manaText
		manaText:SetFont(STANDARD_TEXT_FONT, 10)
		manaText:SetPoint("RIGHT", mana, "RIGHT", -5, 0)
		manaText:SetText(format("%d/100", floor((sample.mana or 1) * 100 + 0.5)))
		manaText:SetShadowOffset(1, -1)
		manaText:SetShadowColor(0, 0, 0, 1)
		local specText = mana:CreateFontString(nil, "OVERLAY")
		specText:SetFont(STANDARD_TEXT_FONT, 10)
		specText:SetPoint("LEFT", mana, "LEFT", 21, 0)
		specText:SetText(sample.spec or "")
		specText:SetShadowOffset(1, -1)
		specText:SetShadowColor(0, 0, 0, 1)
		row.specText = specText
		local arenaModule = SarychUI.modules and SarychUI.modules.arena
		local specIconPath = arenaModule and arenaModule.GetArenaSpecIcon
			and arenaModule:GetArenaSpecIcon(sample.class, sample.spec)
		if specIconPath then
			local specIcon = mana:CreateTexture(nil, "OVERLAY")
			specIcon:SetSize(13, 13)
			specIcon:SetPoint("LEFT", mana, "LEFT", 4, 0)
			specIcon:SetTexture(specIconPath)
			row.specIcon = specIcon
		end
		name:ClearAllPoints()
		name:SetPoint("LEFT", health, "LEFT", 5, 0)
		name:SetFont(STANDARD_TEXT_FONT, 11)
		local cast = CreateFrame("StatusBar", nil, row, nil, "arena.preview:8")
		cast:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -43)
		cast:SetSize(178, 12)
		cast:SetStatusBarTexture(barTexture)
		cast:SetStatusBarColor(1, 1, 0)
		cast:SetMinMaxValues(0, 1)
		cast:SetValue(0.65)
		local castBg = cast:CreateTexture(nil, "BACKGROUND")
		castBg:SetPoint("RIGHT", cast, "RIGHT", 0, 0)
		castBg:SetSize(190, 12)
		castBg:SetTexture("Interface\\Buttons\\WHITE8X8")
		castBg:SetVertexColor(0.6, 0.6, 0.6, 1)
		castBg:SetAlpha(0.3)
		local castIcon = cast:CreateTexture(nil, "ARTWORK")
		castIcon:SetSize(12, 12)
		castIcon:SetPoint("RIGHT", cast, "LEFT", 0, 0)
		castIcon:SetTexture([[Interface\Icons\Spell_Fire_FlameBolt]])
		castIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		local castSpark = cast:CreateTexture(nil, "OVERLAY")
		castSpark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
		castSpark:SetBlendMode("ADD")
		castSpark:SetSize(24, 24)
		castSpark:SetPoint("CENTER", cast, "LEFT", 178 * 0.65, 0)
		local spellText = cast:CreateFontString(nil, "OVERLAY")
		spellText:SetFont(STANDARD_TEXT_FONT, 9)
		spellText:SetPoint("LEFT", cast, "LEFT", 5, 1)
		spellText:SetText(SarychUI:T("ui.options_b162ce333e"))
		spellText:SetShadowOffset(1, -1)
		spellText:SetShadowColor(0, 0, 0, 1)
		local timeText = cast:CreateFontString(nil, "OVERLAY")
		timeText:SetFont(STANDARD_TEXT_FONT, 9)
		timeText:SetPoint("RIGHT", cast, "RIGHT", -5, 1)
		timeText:SetText("1.5")
		timeText:SetShadowOffset(1, -1)
		timeText:SetShadowColor(0, 0, 0, 1)
		row.cast = cast
		row.castBg = castBg
		row.castIcon = castIcon
		row.castSpark = castSpark
		row.castSpellText = spellText
		row.castTimeText = timeText
		if sample == SAMPLES[1] then
			local pet = CreateFrame("StatusBar", nil, row, nil, "arena.preview:9")
			pet:SetStatusBarTexture(barTexture)
			pet:SetStatusBarColor(0.2, 0.9, 0.2)
			pet:SetMinMaxValues(0, 100)
			pet:SetValue(100)
			pet:SetSize(150, 15)
			pet:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -4)
			local petText = pet:CreateFontString(nil, "OVERLAY")
			petText:SetFont(STANDARD_TEXT_FONT, 9)
			petText:SetPoint("LEFT", pet, "LEFT", 5, 0)
			petText:SetText(SarychUI:T("ui.pet_31cd9c45"))
			row.pet = pet
		end
		local border = CreateFrame("Frame", nil, row, nil, "arena.preview:10")
		border:SetSize(199, 61)
		border:SetPoint("TOP", row, "TOP", -1, 3)
		border:SetBackdrop({ edgeFile = [[Interface\ChatFrame\ChatFrameBackground]], edgeSize = 1 })
		border:SetBackdropBorderColor(1, 0.7, 0, 1)
		border:Hide()
		row.gladiusBorder = border
		local highlight = health:CreateTexture(nil, "OVERLAY")
		highlight:SetAllPoints(health)
		highlight:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
		highlight:SetBlendMode("ADD")
		highlight:SetAlpha(0.5)
		highlight:Hide()
		row.gladiusHighlight = highlight
	end
	if sample.hp == 0 then
		local gladius = ArenaDB().frameType == "gladius"
		local deathFrame = CreateFrame("Frame", nil, row:GetParent(), nil, "arena.preview:11")
		deathFrame:SetFrameStrata("HIGH")
		deathFrame:SetFrameLevel(health:GetFrameLevel() + 4)
		deathFrame:SetSize(gladius and 27 or 20, gladius and 30 or 22)
		deathFrame:SetPoint("CENTER", health, "CENTER", 0, gladius and -25 / 13 or 0)
		local death = deathFrame:CreateTexture(nil, "ARTWORK")
		death:SetAllPoints()
		death:SetTexture([[Interface\AddOns\SarychUI\media\arena\TournamentOrganizer.blp]])
		death:SetTexCoord(0, 0.058, 0.295, 0.359)
		row.death = deathFrame
		portrait:SetAlpha(1)
		if row.cast then row.cast:Hide() end
	end
	local combatFrame = CreateFrame("Frame", nil, row:GetParent(), nil, "arena.preview:12")
	combatFrame:SetFrameStrata("HIGH")
	combatFrame:SetFrameLevel(health:GetFrameLevel() + 4)
	combatFrame:SetPoint("CENTER", health, "CENTER", 0, 0)
	local combatTexture = combatFrame:CreateTexture(nil, "BORDER")
	combatTexture:SetAllPoints()
	combatTexture:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	combatTexture:SetTexCoord(0.5, 1, 0, 0.48)
	local combatGlow = combatFrame:CreateTexture(nil, "OVERLAY")
	combatGlow:SetAllPoints()
	combatGlow:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	combatGlow:SetTexCoord(0.5, 1, 0.5, 1)
	combatGlow:SetBlendMode("ADD")
	combatGlow:SetAlpha(0)
	local combatPulse = combatGlow:CreateAnimationGroup()
	combatPulse:SetLooping("REPEAT")
	for order, change in ipairs({ 1, -1 }) do
		local fade = combatPulse:CreateAnimation("Alpha")
		fade:SetOrder(order)
		fade:SetDuration(0.5)
		fade:SetChange(change)
	end
	combatFrame:SetScript("OnShow", function() combatPulse:Play() end)
	combatFrame:SetScript("OnHide", function() combatPulse:Stop(); combatGlow:SetAlpha(0) end)
	combatFrame:Hide()
	row.combatIndicator = combatFrame
	local info = CreateFrame("Frame", nil, row, nil, "arena.preview:13")
	info:SetBackdrop({ bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1 })
	info:SetBackdropColor(0, 0, 0, 0.38)
	info:SetBackdropBorderColor(0.35, 0.35, 0.38, 0.7)
	local infoText = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	infoText:SetPoint("LEFT", info, "LEFT", 4, 0)
	infoText:SetPoint("RIGHT", info, "RIGHT", -4, 0)
	infoText:SetJustifyH("CENTER")
	row.infoPanel = info
	row.infoText = infoText
	local drPanel = CreateFrame("Frame", nil, row, nil, "arena.preview:14")
	drPanel.icons = {}
	for i, spellTexture in ipairs({
		"Interface\\Icons\\Spell_Nature_Polymorph",
		"Interface\\Icons\\Spell_Shadow_Possession",
	}) do
		local drIcon = CreateFrame("Frame", nil, drPanel, nil, "arena.preview:15")
		drIcon:SetBackdrop({ edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1 })
		drIcon:SetBackdropBorderColor(1, i == 1 and 1 or 0, 0, 1)
		local texture = drIcon:CreateTexture(nil, "ARTWORK")
		texture:SetPoint("TOPLEFT", drIcon, "TOPLEFT", 1, -1)
		texture:SetPoint("BOTTOMRIGHT", drIcon, "BOTTOMRIGHT", -1, 1)
		texture:SetTexture(spellTexture)
		drPanel.icons[i] = drIcon
	end
	row.drPanel = drPanel
	return row
end

function Preview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent, nil, "arena.preview:16")
	host:SetHeight(PREVIEW_WINDOW_H)
	host.spacer = host
	SarychUI.OptionsPreviews:Style(host)
	local title = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local theme = SarychUI.OptionsTheme
	if theme and theme.SetTextColor then theme:SetTextColor(title, "textDim") end
	title:SetPoint("TOPLEFT", host, "TOPLEFT", 10, -6)
	title:SetJustifyH("LEFT")
	title:SetText(SarychUI:T("ui.options_ffed32b809")
		.. (ArenaDB().frameType == "gladius" and "Gladius" or SarychUI:T("ui.options_03ced8ccad")) .. "|r")

	local stage = CreateFrame("Frame", nil, host, nil, "arena.preview:17")
	stage:SetPoint("TOPLEFT", 10, -24)
	stage:SetPoint("BOTTOMRIGHT", -10, 10)
	if stage.SetClipsChildren then stage:SetClipsChildren(true) end

	-- Stack centered in the preview panel.
	local rowH = ArenaDB().frameType == "gladius" and 56 or ROW_H
	local rowW = ArenaDB().frameType == "gladius" and 190 or ROW_W
	local STACK_W = rowW + 2 + ICON + 5 + ICON + 12
	local STACK_H = #SAMPLES * rowH + (#SAMPLES - 1) * GAP
	local stack = CreateFrame("Frame", nil, stage, nil, "arena.preview:18")
	stack:SetSize(STACK_W, STACK_H)
	stack:SetPoint("CENTER", stage, "CENTER", 0, 0)
	host._stack = stack

	local function FitStack()
		if host._fitting then return end
		local width, height = stage:GetWidth(), stage:GetHeight()
		if width <= 0 or height <= 0 then return end
		-- The Gladius background extends below the last row; include that overhang.
		local contentW = stack:GetWidth() + 32
		local top = host._fitTop or 0
		local bottom = host._fitBottom or 0
		local contentH = stack:GetHeight() + top + bottom + 10
		if contentW <= 0 or contentH <= 0 then return end
		local wantedScale = tonumber(Live("scale", 1)) or 1
		local scale = math.min(wantedScale, width / contentW, height / contentH)
		local offset = (bottom - top) * scale / 2
		host._fitting = true
		if not host._fitScale or math.abs(host._fitScale - scale) > 0.001 then
			host._fitScale = scale
			stack:SetScale(scale)
		end
		if not host._fitOffset or math.abs(host._fitOffset - offset) > 0.5 then
			host._fitOffset = offset
			stack:ClearAllPoints()
			stack:SetPoint("CENTER", stage, "CENTER", 0, offset)
		end
		host._fitting = nil
	end
	stage:SetScript("OnSizeChanged", FitStack)

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
	local infoHeading = stack:CreateFontString(nil, "OVERLAY")
	infoHeading:SetFont(STANDARD_TEXT_FONT, 10)
	infoHeading:SetSize(INFO_W, 24)
	infoHeading:SetPoint("BOTTOM", rows[1].infoPanel, "TOP", 0, 3)
	infoHeading:SetJustifyH("CENTER")
	infoHeading:SetTextColor(0.7, 0.7, 0.72)
	infoHeading:SetText(SarychUI:T("ui.text_b0df4811"))
	local visibleCount = 3
	if ArenaDB().frameType == "gladius" then
		local background = CreateFrame("Frame", nil, stack, nil, "arena.preview:19")
		background:SetPoint("TOPLEFT", rows[1], "TOPLEFT", -7.5, 6)
		background:SetPoint("BOTTOMRIGHT", rows[#rows], "BOTTOMRIGHT", 7.5, -5)
		background:SetBackdrop({ bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16 })
		background:SetBackdropColor(0, 0, 0, 0.3)
		background:SetFrameLevel(stack:GetFrameLevel())
		stack.gladiusBackground = background
		for i, row in ipairs(rows) do
			row:SetFrameLevel(stack:GetFrameLevel() + 1)
			if row.gladiusBorder then
				if i == 1 then
					row.gladiusBorder:SetBackdropBorderColor(1, 0.7, 0, 1)
					row.gladiusBorder:Show()
					row.gladiusHighlight:Show()
				elseif i == 2 then
					row.gladiusBorder:SetBackdropBorderColor(1, 0, 0, 1)
					row.gladiusBorder:Show()
				end
			end
		end
	end
	host._rows = rows
	host._t = 0

	local function LayoutLive()
		local db = ArenaDB()
		title:SetText(SarychUI:T("ui.options_ffed32b809")
			.. (db.frameType == "gladius" and "Gladius" or SarychUI:T("ui.options_03ced8ccad")) .. "|r")
		local defaultGap = db.frameType == "gladius" and 4 or GAP
		local gap = tonumber(Live("frameSpacing", defaultGap)) or defaultGap
		if gap < 0 then gap = 0 elseif gap > 60 then gap = 60 end
		local trinketsOn, racialOn, iconScale = TrinketsDB()
		local gladius = db.frameType == "gladius"
		local arenaModule = SarychUI.modules and SarychUI.modules.arena
		local classicStyle = arenaModule and arenaModule.GetStyleSettings
			and arenaModule:GetStyleSettings("classic")
		local showClassicSpec = not gladius and classicStyle and classicStyle.showSpecText == true
		local trinketSettings = db.Trinkets or {}
		local iconSpacing = tonumber(trinketSettings.spacing) or 5
		local iconColumn = not gladius and trinketsOn and racialOn
			and trinketSettings.layout == "COLUMN"
		local primaryContent = arenaModule and (gladius and arenaModule:GetGladiusPrimaryContent()
			or arenaModule:GetClassicPrimaryContent()) or nil
		local procsPrimary = primaryContent == "procTrinkets"
		local iconCount = gladius and ((trinketsOn and 1 or 0) + (racialOn and 1 or 0)
			+ (procsPrimary and 2 or 0)) or 0
		local barWidth = gladius and math.max(80, math.min(300, tonumber(Live("barWidth", 165)) or 165)) or 0
		local castLeft = gladius and Live("castBarPos", "CENTER") == "LEFT"
		local castHeight = gladius and math.max(12, math.min(castLeft and 40 or 30,
			tonumber(Live("castBarHeight", 18)) or 18)) or 0
		local castTextSize = gladius and math.max(1, math.min(20, tonumber(Live("castTextSize", 10)) or 10)) or 9
		local showSpecText = not gladius or LiveFlag("showSpecText", true)
		local showPets = gladius and LiveFlag("showPets", true)
		host._fitTop = math.max(34, gladius and 7 or math.max(0, (ICON * iconScale - rowH) / 2))
		host._fitBottom = gladius and (showPets and 24 or 6) or host._fitTop
		if showPets then gap = gap + 19 end
		if iconColumn then
			gap = math.max(gap,
				(2 * ICON + iconSpacing) * iconScale / 2 - rowH / 2 + 4)
		end
		local procSettings = db.procTrinkets or {}
		local procColumn = not gladius and procSettings.layout == "COLUMN"
		local procGap = tonumber(procSettings.spacing) or iconSpacing
		if procColumn and arenaModule and (arenaModule:GetClassicPrimaryContent() == "procTrinkets"
			or arenaModule:GetClassicLeftContent() == "procTrinkets"
			or arenaModule:GetClassicRightContent() == "procTrinkets") then
			gap = math.max(gap,
				(2 * ICON + procGap) * iconScale / 2 - rowH / 2 + 4)
		end
		local castWidth = gladius and (barWidth + 41 - castHeight) or 0
		local currentRowH = gladius and (castLeft and 43 or math.max(56, 43 + castHeight + 1)) or rowH
		local currentRowW = gladius and (barWidth + 40) or rowW
		local classicIconWidth = (trinketsOn or racialOn) and (2 + ICON * iconScale) or 0
		if trinketsOn and racialOn and not iconColumn then
			classicIconWidth = classicIconWidth + (iconSpacing + ICON) * iconScale
		end
		if not gladius and procsPrimary then
			local blockWidth = (procColumn and ICON or (2 * ICON + procGap)) * iconScale
			classicIconWidth = trinketsOn and (classicIconWidth + procGap * iconScale + blockWidth)
				or (2 + blockWidth)
		end
		local arenaModule = SarychUI.modules and SarychUI.modules.arena
		local drSettings = arenaModule and arenaModule.GetDRSettings
			and arenaModule:GetDRSettings() or nil
		local drSide = arenaModule and arenaModule:IsDRShown()
			and (drSettings and drSettings.side == "RIGHT" and "RIGHT" or "LEFT") or "none"
		if gladius and castLeft and drSide == "LEFT" then drSide = "none" end
		local abilitySettings = arenaModule and arenaModule.GetEnemyAbilitySettings
			and arenaModule:GetEnemyAbilitySettings() or nil
		local rightContent = arenaModule and (gladius and arenaModule:GetGladiusRightContent()
			or arenaModule:GetClassicRightContent()) or "none"
		local leftContent = arenaModule and (gladius and arenaModule:GetGladiusLeftContent()
			or arenaModule:GetClassicLeftContent()) or "none"
		local abilitySide = rightContent == "enemyAbilities" and "RIGHT" or "none"
		if drSide ~= "none" and drSide == abilitySide then
			drSide = abilitySide == "LEFT" and "RIGHT" or "LEFT"
		end
		local drIconSize = gladius and 40
			or tonumber(abilitySettings and abilitySettings.layout and abilitySettings.layout.size) or 24
		local drIconHeight = gladius and 41 or drIconSize
		local drWidth = drIconSize * 2 + 3
			+ (gladius and math.max(7, math.abs(tonumber(drSettings and drSettings.x) or 7)) or 7)
		local abilityWidth = INFO_W + 12
		local leftExtra = (drSide == "LEFT" and drWidth or 0)
			+ (abilitySide == "LEFT" and abilityWidth or 0)
		local rightExtra = (drSide == "RIGHT" and drWidth or 0)
			+ (abilitySide == "RIGHT" and abilityWidth or 0)
		local procsOn = procsPrimary or leftContent == "procTrinkets"
			or rightContent == "procTrinkets"
		local procsLeft = not procsPrimary and leftContent == "procTrinkets"
		if procsOn and not procsPrimary then
			if procsLeft then leftExtra = leftExtra + (gladius and 102
				or (procColumn and ICON + 7 or 2 * ICON + procGap + 7) * iconScale)
			else
				rightExtra = rightExtra + (gladius and 93
					or (procColumn and (ICON + 7) or (2 * ICON + 12)) * iconScale)
			end
		end
		local baseWidth = gladius and (currentRowW + iconCount * 41 + 15
			+ (castLeft and (barWidth + 41) or 0)) or (rowW + classicIconWidth + 18)
		stack:SetWidth(baseWidth + leftExtra + rightExtra)
		rows[1]:ClearAllPoints()
		rows[1]:SetPoint("TOPLEFT", stack, "TOPLEFT",
			leftExtra + (castLeft and (barWidth + 41) or 0), 0)
		if host._gap ~= gap or host._rowH ~= currentRowH or host._visibleCount ~= visibleCount then
			host._gap, host._rowH, host._visibleCount = gap, currentRowH, visibleCount
			for i = 2, #rows do
				rows[i]:ClearAllPoints()
				rows[i]:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -gap)
			end
			local height = visibleCount * currentRowH + (visibleCount - 1) * gap
			stack:SetHeight(height)
		end
		local rangeCheck = LiveFlag("rangeCheckEnabled", true)
		for i, row in ipairs(rows) do
            if not gladius then
                local font, _, flags = row.name:GetFont()
                if font then row.name:SetFont(font, tonumber(classicStyle and classicStyle.fontSize) or 10, flags) end
            end

			if i <= visibleCount then row:Show() else row:Hide() end
			if row.death then
				if i <= visibleCount then row.death:Show() else row.death:Hide() end
			end
			if row.combatIndicator then
				local frameDB = SarychUI.db and SarychUI.db.profile
					and SarychUI.db.profile.modules and SarychUI.db.profile.modules.frame
				local size = 26 * (tonumber(frameDB and frameDB.combatIndicatorScale) or 0.85)
				row.combatIndicator:SetSize(size, size)
				if db.showCombatIndicator == true and i <= visibleCount
					and (i == 1 or i == 3) then row.combatIndicator:Show()
				else row.combatIndicator:Hide() end
			end
			if gladius then
				row:SetSize(currentRowW, currentRowH)
				row.health:SetWidth(barWidth)
				row.mana:SetWidth(barWidth)
				row.cast:ClearAllPoints()
				row.cast:SetPoint("TOPLEFT", row, "TOPLEFT",
					castLeft and (-castWidth - 11) or (castHeight - 1), castLeft and 0 or -43)
				row.cast:SetSize(castWidth, castHeight)
				row.castBg:SetSize(castWidth + castHeight, castHeight)
				row.castIcon:SetSize(castHeight, castHeight)
				row.castSpark:SetSize(castHeight * 2, castHeight * 2)
				row.castSpark:ClearAllPoints()
				row.castSpark:SetPoint("CENTER", row.cast, "LEFT", castWidth * 0.65, 0)
				row.castSpellText:SetFont(STANDARD_TEXT_FONT, castTextSize)
				row.castTimeText:SetFont(STANDARD_TEXT_FONT, castTextSize)
				if row.pet then
					row.pet:SetWidth(barWidth)
					if showPets then row.pet:Show() else row.pet:Hide() end
				end
				if row.death then row.cast:Hide() end
				if showSpecText then
					row.specText:Show()
					if row.specIcon then row.specIcon:Show() end
				else
					row.specText:Hide()
					if row.specIcon then row.specIcon:Hide() end
				end
				row.gladiusBorder:SetSize(currentRowW + 9, currentRowH + 5)
				row.trinket:SetSize(40, 41)
				row.racial:SetSize(40, 41)
			else
				row.trinket:SetSize(ICON, ICON)
				row.racial:SetSize(ICON, ICON)
			end
			if showClassicSpec and row.spec then
				if row._classicSpecColumn ~= iconColumn then
					row.classicSpecLabel:ClearAllPoints()
					if iconColumn then
						row.classicSpecLabel:SetPoint("BOTTOMRIGHT", row.portrait, "TOPRIGHT", 0, 2)
						row.classicSpecLabel:SetJustifyH("RIGHT")
					else
						row.classicSpecLabel:SetPoint("BOTTOM", row.portrait, "TOP", 0, 2)
						row.classicSpecLabel:SetJustifyH("CENTER")
					end
					row._classicSpecColumn = iconColumn
				end
				local texture = arenaModule and arenaModule.GetArenaSpecIcon
					and arenaModule:GetArenaSpecIcon(row.class, row.spec)
				if texture then
					if SetPortraitToTexture then
						SetPortraitToTexture(row.specPortrait, texture)
					else
						row.specPortrait:SetTexture(texture)
						row.specPortrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					end
					row.portrait:SetAlpha(0)
					row.specPortrait:Show()
					row.classicSpecLabel:Show()
				else
					SetClassIcon(row.portrait, row.class)
					row.portrait:SetAlpha(1)
					row.specPortrait:Hide()
					row.classicSpecLabel:Hide()
				end
			else
				if not gladius then SetClassIcon(row.portrait, row.class) end
				row.portrait:SetAlpha(1)
				row.specPortrait:Hide()
				row.classicSpecLabel:Hide()
			end
			local r, g, b = ClassColor(row.class)
			row.health:SetStatusBarColor(r, g, b)
			local pr, pg, pb = 0.2, 0.35, 0.95
			if gladius then
				pr, pg, pb = 0.18, 0.44, 0.75
				if row.class == "WARRIOR" then pr, pg, pb = 1, 0, 0
				elseif row.class == "ROGUE" then pr, pg, pb = 1, 1, 0 end
			end
			row.mana:SetStatusBarColor(pr, pg, pb)
			if row.cast then row.cast:SetStatusBarColor(1, gladius and 1 or 0.7, 0) end
			if arenaModule and arenaModule.UpdateGladiusCastShield then
				arenaModule:UpdateGladiusCastShield(row.cast, row.castIcon, i == 2, gladius and "gladius" or "classic")
			end

			row.trinket:SetScale(gladius and 1 or iconScale)
			row.racial:SetScale(gladius and 1 or iconScale)
			row.trinket:ClearAllPoints()
			if gladius then row.trinket:SetPoint("TOPLEFT", row, "TOPRIGHT", 6, 0)
			elseif iconColumn then
				row.trinket:SetPoint("LEFT", row, "RIGHT", 2, (ICON + iconSpacing) / 2)
			else row.trinket:SetPoint("LEFT", row, "RIGHT", 2, -2) end

			if trinketsOn then
				row.trinket:Show()
				row.trinket.iconFrame:Show()
				row.racial:ClearAllPoints()
				if iconColumn then
					row.racial:SetPoint("TOP", row.trinket, "BOTTOM", 0, -iconSpacing)
				else
					row.racial:SetPoint("LEFT", row.trinket, "RIGHT",
						gladius and 1 or iconSpacing, 0)
				end
			else
				row.trinket:Hide()
				row.trinket.iconFrame:Hide()
				row.racial:ClearAllPoints()
				if gladius then row.racial:SetPoint("TOPLEFT", row, "TOPRIGHT", 6, 0)
				else row.racial:SetPoint("LEFT", row, "RIGHT", 2, -2) end
			end

			if racialOn then
				row.racial:Show()
				row.racial.iconFrame:Show()
			else
				row.racial:Hide()
				row.racial.iconFrame:Hide()
			end
			row.trinket:SetAlpha(i == 5 and 0 or 1)
			row.racial:SetAlpha(i == 5 and 0 or 1)
			local infoAnchor = iconColumn and row.trinket
				or racialOn and row.racial or trinketsOn and row.trinket or row
			local leftAnchor = gladius and row.portrait or row
			row.infoPanel:ClearAllPoints()
			if abilitySide == "LEFT" then
				row.infoPanel:SetPoint("RIGHT", leftAnchor, "LEFT", -7, 0)
			elseif procsPrimary and abilitySide == "RIGHT" then
				if gladius then
					row.infoPanel:SetPoint("TOPLEFT", row, "TOPRIGHT",
						87 + (trinketsOn and 41 or 0) + 7, 0)
				else
					row.infoPanel:SetPoint("LEFT", row, "RIGHT",
						classicIconWidth + 7, -2 * iconScale)
				end
			elseif iconColumn then
				row.infoPanel:SetPoint("LEFT", row, "RIGHT",
					28 * iconScale + 7, -2 * iconScale)
			else
				row.infoPanel:SetPoint("LEFT", infoAnchor, "RIGHT", 7, 0)
			end
			row.infoPanel:SetSize(INFO_W, gladius and 41 or ROW_H)
			row.infoText:SetText(SarychUI:T("ui.text_b0df4811"))
			row.infoText:SetTextColor(0.4, 1, 0.4)
			if abilitySide ~= "none" and i ~= 5 then row.infoPanel:Show()
			else row.infoPanel:Hide() end
			local procAnchor = abilitySide == "RIGHT" and row.infoPanel
				or iconColumn and row
				or racialOn and row.racial or trinketsOn and row.trinket or row
			local procCount = i == 2 and 1 or 2
			local procScale = gladius and 1 or iconScale
			local procGap = gladius and 1 or procGap
			local procWidth = gladius and 40 or ICON
			local procHeight = gladius and 41 or ICON
			local procEffectiveScale = procScale * row:GetEffectiveScale()
			local procX = gladius and 6 or 2
			if gladius then
				-- Preview icons have just been reanchored, so GetRight() may still
				-- describe their previous position. Reserve each 40px icon plus 1px.
				procX = procsPrimary and (6 + (trinketsOn and 41 or 0))
					or (6 + iconCount * 41 + 5)
			elseif procsPrimary then
				procX = (2 / iconScale) + (trinketsOn and (ICON + procGap) or 0)
			elseif not gladius and rightContent == "procTrinkets" then
				procX = (2 / iconScale) + (iconColumn and ICON
					or trinketsOn and racialOn and (2 * ICON + iconSpacing)
					or (trinketsOn or racialOn) and ICON or 0)
				if trinketsOn or racialOn then procX = procX + procGap end
			end
			local procY = gladius and (row:GetHeight() - 41) / 2 or -2
			local total, found = 0, 0
			if not gladius then
				for _, standard in pairs({ first = trinketsOn and row.trinket or nil,
					second = racialOn and row.racial or nil }) do
					local centerY = select(2, standard:GetCenter())
					if centerY then
						total, found = total + centerY * standard:GetEffectiveScale(), found + 1
					end
				end
			end
			local rowCenterY = select(2, row:GetCenter())
			if found > 0 and rowCenterY then
				procY = (total / found - rowCenterY * row:GetEffectiveScale()) / procEffectiveScale
			end
			for procIndex, proc in ipairs(row.procIcons) do
				proc:SetSize(procWidth, procHeight)
				proc:SetScale(procScale)
				proc.equippedBorder:SetSize(procWidth * 62 / 36, procHeight * 62 / 36)
				proc.pulseBorder:SetSize(procWidth * 48 / 26, procHeight * 48 / 26)
				proc._cdText:SetWidth(procWidth)
				proc:ClearAllPoints()
				if procsLeft then
					if procIndex == 1 then
						if gladius then proc:SetPoint("RIGHT", row.portrait, "LEFT", -11, 0)
						else proc:SetPoint("RIGHT", row, "LEFT", -2,
							procY + (procColumn and procCount == 2 and (procHeight + procGap) / 2 or 0)) end
					elseif procColumn and procCount == 2 then
						proc:SetPoint("TOP", row.procIcons[1], "BOTTOM", 0, -procGap)
					else
						proc:SetPoint("RIGHT", row.procIcons[procIndex - 1], "LEFT", -procGap, 0)
					end
				elseif procsPrimary then
					if procIndex == 1 then
						if gladius then proc:SetPoint("TOPLEFT", row, "TOPRIGHT", procX, 0)
						else proc:SetPoint("LEFT", row, "RIGHT", procX,
							procY + (procColumn and procCount == 2 and (procHeight + procGap) / 2 or 0)) end
					elseif procColumn and procCount == 2 then
						proc:SetPoint("TOP", row.procIcons[1], "BOTTOM", 0, -procGap)
					else
						proc:SetPoint("LEFT", row.procIcons[procIndex - 1], "RIGHT", procGap, 0)
					end
				elseif procIndex == 1 then
					proc:SetPoint("LEFT", row, "RIGHT",
						procX,
						procY + (procColumn and procCount == 2 and (procHeight + procGap) / 2 or 0))
				elseif procColumn and procCount == 2 then
					proc:SetPoint("TOP", row.procIcons[1], "BOTTOM", 0, -procGap)
				else
					proc:SetPoint("LEFT", row.procIcons[procIndex - 1], "RIGHT", procGap, 0)
				end
				if procsOn and procIndex <= procCount and i ~= 5 then proc:Show()
				else proc:Hide() end
			end
			row.drPanel:ClearAllPoints()
			row.drPanel:SetSize(drIconSize * 2 + 3, drIconHeight)
			if drSide == "LEFT" then
				row.drPanel:SetPoint("RIGHT", leftAnchor, "LEFT", -2, 0)
			elseif gladius then
				row.drPanel:SetPoint("TOPLEFT",
					procsPrimary and row.procIcons[2] or infoAnchor, "TOPRIGHT",
					math.abs(tonumber(drSettings and drSettings.x) or 7),
					tonumber(drSettings and drSettings.y) or 0)
			elseif procsPrimary then
				row.drPanel:SetPoint("LEFT", row, "RIGHT",
					classicIconWidth + (tonumber(drSettings and drSettings.x) or 2),
					tonumber(drSettings and drSettings.y) or 0)
			elseif iconColumn then
				row.drPanel:SetPoint("LEFT", row, "RIGHT",
					28 * iconScale + (tonumber(drSettings and drSettings.x) or 2),
					-2 * iconScale + (tonumber(drSettings and drSettings.y) or 0))
			else
				row.drPanel:SetPoint("LEFT", infoAnchor, "RIGHT",
					tonumber(drSettings and drSettings.x) or 2,
					tonumber(drSettings and drSettings.y) or 0)
			end
			for drIndex, drIcon in ipairs(row.drPanel.icons) do
				drIcon:SetSize(drIconSize, drIconHeight)
				drIcon:ClearAllPoints()
				local offset = drSide == "LEFT" and (#row.drPanel.icons - drIndex)
					or (drIndex - 1)
				drIcon:SetPoint("LEFT", row.drPanel, "LEFT", offset * (drIconSize + 3), 0)
			end
			if drSide ~= "none" and i ~= 5 then row.drPanel:Show()
			else row.drPanel:Hide() end

			local outside = rangeCheck and (i == 2 or i == 4)
			local range = SarychUI.UnitFrameRange
			local factor = range and range:ColorFactorForOutside(outside) or 1
			row.health:SetStatusBarColor(r * factor, g * factor, b * factor)
			row.mana:SetStatusBarColor(pr * factor, pg * factor, pb * factor)
			row.name:SetTextColor(row.nameR * factor, row.nameG * factor,
				row.nameB * factor, row.nameA)
			if row.healthText then row.healthText:SetTextColor(factor, factor, factor) end
			if row.manaText then row.manaText:SetTextColor(factor, factor, factor) end
			row.portrait:SetVertexColor(factor, factor, factor)
			row.specPortrait:SetVertexColor(factor, factor, factor)
			if row.specIcon then row.specIcon:SetVertexColor(factor, factor, factor) end
			row:SetAlpha(i == 5 and 0.40 or 1)
			row.health:SetAlpha(1)
		end
		if abilitySide ~= "none" then infoHeading:Show() else infoHeading:Hide() end
		if stack.gladiusBackground then
			local style = arenaModule and arenaModule:GetStyleSettings("gladius") or {}
			if style.showDarkBackground ~= false then stack.gladiusBackground:Show()
			else stack.gladiusBackground:Hide() end
			stack.gladiusBackground:ClearAllPoints()
			stack.gladiusBackground:SetPoint("TOPLEFT", rows[1], "TOPLEFT", -7.5, 6)
			stack.gladiusBackground:SetPoint("BOTTOMRIGHT", rows[visibleCount], "BOTTOMRIGHT",
				7.5 + iconCount * 41, -5 - (showPets and 19 or 0))
		end
		FitStack()
	end

	local function TickProcPreview(proc)
		if not proc._testStart then return end
		local now = GetTime()
		local cycle = 22
		local cycleStart = proc._testStart + math.floor((now - proc._testStart) / cycle) * cycle
		local elapsed = now - cycleStart
		local active, cooling = elapsed < 5, elapsed >= 5 and elapsed < 17
		local texture = active and (ArenaDB().procTrinkets or {}).procIconMode ~= "ITEM"
			and proc.procTexture or proc.itemTexture
		if proc._shownTexture ~= texture then
			proc.icon:SetTexture(texture)
			proc._shownTexture = texture
		end
		proc.icon:SetDesaturated(cooling and (ArenaDB().procTrinkets or {}).desaturateOnCooldown == true)
		if active then
			proc.equippedBorder:Hide()
			proc._pulseStartedAt = cycleStart
			if not proc.pulseBorder:IsShown() then
				proc.pulseBorder:SetAlpha(1)
				proc.pulseBorder:Show()
			end
		else
			proc.pulseBorder:Hide()
			proc.equippedBorder:Show()
		end
		if active or cooling then
			local start = active and cycleStart or cycleStart + 5
			local duration = active and 5 or 12
			local timerKey = (active and "proc:" or "cd:") .. start
			if proc._procTimerKey ~= timerKey then
				proc._cooldown:Show()
				proc._cooldown:SetCooldown(start, duration)
				proc._cdText:Show()
				proc._procTimerKey = timerKey
			end
			proc._cdText:SetText(FormatCdText(start + duration - now))
		elseif proc._procTimerKey then
			CooldownFrame_SetTimer(proc._cooldown, 0, 0, 0)
			proc._cooldown:Hide()
			proc._cdText:Hide()
			proc._procTimerKey = nil
		end
	end

	local function Layout()
		LayoutLive()
		local trinketsOn, racialOn = TrinketsDB()
		local trinketSettings = ArenaDB().Trinkets or {}
		local desaturate = trinketSettings.desaturateOnCooldown == true
		local procSamples = {
			{ { 71485, 50362, 1 }, { 71605, 50360, 8 } },
			{ { 64713, 45518, 19 } },
			{ { 67703, 47303, 12 }, { 75456, 54590, 2 } },
			{ { 60065, 40684, 20 } },
			{ { 71485, 50362, 14 }, { 71605, 50360, 21 } },
		}
		for rowIndex, row in ipairs(rows) do
			row.trinket._readyUntil = nil
			row.racial._readyUntil = nil
			if trinketsOn then
				StartPreviewCooldown(row.trinket, true)
			end
			if racialOn then
				StartPreviewCooldown(row.racial, true)
			end
			row.trinket.icon:SetDesaturated(desaturate and trinketsOn)
			row.racial.icon:SetDesaturated(desaturate and racialOn)
			for index, proc in ipairs(row.procIcons) do
				local sample = procSamples[rowIndex] and procSamples[rowIndex][index]
				if sample then
					proc.itemTexture = select(10, GetItemInfo(sample[2])) or proc.itemTexture
					proc.procTexture = select(3, GetSpellInfo(sample[1])) or proc.itemTexture
					proc._testStart = GetTime() - sample[3]
				end
				proc._shownTexture = nil
				proc._procTimerKey = nil
				CooldownFrame_SetTimer(proc._cooldown, 0, 0, 0)
				proc._cooldown:Hide()
				proc._cdText:Hide()
				TickProcPreview(proc)
			end
		end
	end

	local countChecks = {}
	local theme = SarychUI.OptionsTheme
	for index, count in ipairs({ 2, 3, 5 }) do
		local check = CreateFrame("Button", nil, host, nil, "arena.preview:20")
		check:SetSize(16, 16)
		check:SetPoint("TOPRIGHT", host, "TOPRIGHT", -26 - (3 - index) * 45, -5)
		if theme and theme.ApplyFlat then
			theme:ApplyFlat(check, theme.colors.inputBg, theme.colors.border)
		end
		local mark = check:CreateTexture(nil, "OVERLAY")
		mark:SetTexture("Interface\\Buttons\\WHITE8X8")
		mark:SetPoint("TOPLEFT", 3, -3)
		mark:SetPoint("BOTTOMRIGHT", -3, 3)
		local color = theme and theme.colors.checkOn or { 0.95, 0.82, 0.20 }
		mark:SetVertexColor(color[1], color[2], color[3], 1)
		check.mark = mark
		local label = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", check, "RIGHT", 6, 0)
		label:SetText(tostring(count))
		if count == visibleCount then mark:Show() else mark:Hide() end
		check:SetScript("OnClick", function()
			visibleCount = count
			for option, button in pairs(countChecks) do
				if option == visibleCount then button.mark:Show() else button.mark:Hide() end
			end
			Layout()
		end)
		countChecks[count] = check
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
				for _, proc in ipairs(row.procIcons) do TickProcPreview(proc) end
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
				for _, proc in ipairs(row.procIcons) do TickProcPreview(proc) end
			end
		end)
	end

	Layout()
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(self, host) else tinsert(self._instances, host) end
	return host
end

--------------------------------------------------------------------
SarychUI.ArenaNumbersPreview = MakeBucket("ArenaNumbersPreview")
local NumbersPreview = SarychUI.ArenaNumbersPreview
NumbersPreview._activeKey = nil

local NP_PLATE_W = 88
local NP_PLATE_H = 7
local NP_PLATE_ROW_H = 20
local NP_ACTIVE = { 1, 0.82, 0.2, 1 }
local NP_SAMPLES = {
	{ name = SarychUI:T("ui.options_4c5f0585f4"), class = "WARRIOR", hp = 0.82, mana = 0.35 },
	{ name = SarychUI:T("ui.options_73b4a59c4e"), class = "PRIEST", hp = 0.61, mana = 0.78 },
	{ name = SarychUI:T("ui.options_b9a2d8a9c3"), class = "MAGE", hp = 0.44, mana = 0.92 },
}
local NP_CONTENT_H = 24 + #NP_SAMPLES * NP_PLATE_ROW_H + 5 + 12 + 9
local NP_PREVIEW_H = NP_CONTENT_H + 16

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
	local f = CreateFrame("Frame", nil, parent, nil, "arena.preview:21")
	f:SetSize(NP_PLATE_W, NP_PLATE_ROW_H)

	local nameFs = f:CreateFontString(nil, "OVERLAY")
	nameFs:SetFont(STANDARD_TEXT_FONT, 10)
	nameFs:SetPoint("TOP", f, "TOP", 0, -1)
	nameFs:SetTextColor(1, 1, 1)
	f.nameFs = nameFs

	local plate = CreateFrame("Frame", nil, f, nil, "arena.preview:22")
	plate:SetSize(NP_PLATE_W, NP_PLATE_H)
	plate:SetPoint("BOTTOM", 0, 0)
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

local function MakeNumbersArenaFrame(parent, sample)
	local gladius = ArenaDB().frameType == "gladius"
	local frame = CreateFrame("Frame", nil, parent, nil, "arena.preview:23")
	frame:SetSize(gladius and 142 or 105, gladius and 34 or 32)
	local portrait = frame:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(gladius and 32 or 29, gladius and 32 or 29)
	portrait:SetPoint(gladius and "TOPLEFT" or "TOPRIGHT", frame, gladius and "TOPLEFT" or "TOPRIGHT", 0, gladius and 0 or -2)
	if gladius and CLASS_BUTTONS and CLASS_BUTTONS[sample.class] then
		portrait:SetTexture([[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]])
		portrait:SetTexCoord(unpack(CLASS_BUTTONS[sample.class]))
	else
		SetClassIcon(portrait, sample.class)
	end
	local barTexture = gladius and [[Interface\AddOns\SarychUI\media\arena\Minimalist]]
		or [[Interface\TargetingFrame\UI-StatusBar]]
	local health = CreateFrame("StatusBar", nil, frame, nil, "arena.preview:24")
	health:SetSize(gladius and 108 or 70, gladius and 20 or 9)
	health:SetPoint("TOPLEFT", frame, "TOPLEFT", gladius and 34 or 2, gladius and 0 or -12)
	health:SetStatusBarTexture(barTexture)
	health:SetMinMaxValues(0, 1)
	health:SetValue(sample.hp)
	health:SetStatusBarColor(ClassColor(sample.class))
	local mana = CreateFrame("StatusBar", nil, frame, nil, "arena.preview:25")
	mana:SetSize(gladius and 108 or 70, gladius and 10 or 7)
	mana:SetPoint("TOPLEFT", frame, "TOPLEFT", gladius and 34 or 2, gladius and -22 or -21)
	mana:SetStatusBarTexture(barTexture)
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(sample.mana)
	mana:SetStatusBarColor(0.23, 0.42, 0.88)
	if not gladius then
		local chrome = frame:CreateTexture(nil, "OVERLAY")
		chrome:SetSize(105, 33)
		chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		chrome:SetTexture([[Interface\ArenaEnemyFrame\UI-ArenaTargetingFrame]])
		chrome:SetTexCoord(0.0, 0.796, 0.0, 0.5)
	end
	local name = (gladius and health or frame):CreateFontString(nil, "OVERLAY")
	name:SetFont(STANDARD_TEXT_FONT, gladius and 11 or 10)
	name:SetPoint("LEFT", health, "LEFT", gladius and 5 or 2, gladius and 0 or 11)
	name:SetTextColor(1, 0.82, 0, 1)
	name:SetShadowOffset(1, -1)
	name:SetShadowColor(0, 0, 0, 1)
	frame.name = name
	return frame
end

local MakePreviewPlayer

function NumbersPreview:Create(parent)
	self:ClearStickyHosts()

	local host, stage = SarychUI.OptionsPreviews:CreateHost(parent, NP_PREVIEW_H)
	local content = CreateFrame("Frame", nil, stage, nil, "arena.preview:26")
	content:SetSize(550, NP_CONTENT_H)
	content:SetPoint("CENTER", stage, "CENTER", 0, 0)
	local plateColumn = CreateFrame("Frame", nil, stage, nil, "arena.preview:27")
	plateColumn:SetSize(NP_PLATE_W, #NP_SAMPLES * NP_PLATE_ROW_H)
	plateColumn:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -24)

	local plateTitle = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	plateTitle:SetPoint("TOP", plateColumn, "BOTTOM", 0, -5)
	plateTitle:SetText(Tr(SarychUI:T("ui.options_46806837b2")))
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
	local arenaFrame = MakeNumbersArenaFrame(stage, NP_SAMPLES[1])
	arenaFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 142, -35)
	local frameTitle = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frameTitle:SetPoint("TOP", arenaFrame, "BOTTOM", 0, -5)
	frameTitle:SetText(Tr(SarychUI:T("ui.options_7ff17c0b3a")))
	frameTitle:SetTextColor(0.72, 0.72, 0.72)
	local playerFrame = MakePreviewPlayer(stage)
	playerFrame:SetScale(0.8)
	playerFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 338, -15)
	local playerTitle = stage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	playerTitle:SetPoint("TOP", playerFrame, "BOTTOM", 0, -5)
	playerTitle:SetText(Tr(SarychUI:T("ui.options_cf5fc9adb7")))
	playerTitle:SetTextColor(0.72, 0.72, 0.72)

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
				plate.nameFs:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
				plate.nameFs:SetText(tostring(i))
			else
				plate.nameFs:SetFont(STANDARD_TEXT_FONT, 10, "")
				plate.nameFs:SetText(plate._sampleName)
			end
			if masterHovered or plateHovered then
				plate.nameFs:SetTextColor(NP_ACTIVE[1], NP_ACTIVE[2], NP_ACTIVE[3], 1)
			else
				plate.nameFs:SetTextColor(1, 1, 1, 1)
			end
		end
		if framesNumbered then
			arenaFrame.name:SetText("1")
		else
			arenaFrame.name:SetText(Tr(NP_SAMPLES[1].name))
		end
		if masterHovered or framesHovered then
			arenaFrame.name:SetTextColor(NP_ACTIVE[1], NP_ACTIVE[2], NP_ACTIVE[3], 1)
		else
			arenaFrame.name:SetTextColor(1, 0.82, 0, 1)
		end
		if NumbersLiveFlag("hideGroupRaidText", false) then
			playerFrame.group:Hide()
		else
			playerFrame.group:Show()
			local hovered = activeKey == "hideGroupRaidText"
			playerFrame.group.fs:SetTextColor(hovered and NP_ACTIVE[1] or 1,
				hovered and NP_ACTIVE[2] or 1, hovered and NP_ACTIVE[3] or 1)
		end
	end

	host.LayoutLive = Layout
	host.Refresh = Layout
	host:SetScript("OnShow", Layout)
	host:SetScript("OnSizeChanged", Layout)
	Layout()
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(self, host) else tinsert(self._instances, host) end
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
	local wrap = CreateFrame("Frame", nil, parent, nil, "arena.preview:28")
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
	fs:SetText(Tr(GROUP or SarychUI:T("ui.party_907efbd4")) .. " 1")
	fs:SetAlpha(0.7)
	wrap.left, wrap.right, wrap.mid, wrap.fs = left, right, mid, fs

	wrap:SetWidth((fs:GetStringWidth() or 36) + 40)
	return wrap
end

-- PlayerFrame.xml: 232x100, flipped UI-TargetingFrame, bars 119x12 at 106,-41 / 106,-52
MakePreviewPlayer = function(parent)
	local f = CreateFrame("Frame", nil, parent, nil, "arena.preview:29")
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
	nameFs:SetText((playerName and playerName ~= "") and playerName or Tr(SarychUI:T("ui.player_f54f58cf")))

	local health = CreateFrame("StatusBar", nil, f, nil, "arena.preview:30")
	health:SetSize(GS(119), GS(12))
	health:SetPoint("TOPLEFT", GS(106), -GS(41))
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.78)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local mana = CreateFrame("StatusBar", nil, f, nil, "arena.preview:31")
	mana:SetSize(GS(119), GS(12))
	mana:SetPoint("TOPLEFT", GS(106), -GS(52))
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(0.55)
	mana:SetStatusBarColor(0, 0, 1)
	mana:SetFrameLevel(f:GetFrameLevel() + 1)

	local borderFrame = CreateFrame("Frame", nil, f, nil, "arena.preview:32")
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

	local host = CreateFrame("Frame", nil, parent, nil, "arena.preview:33")
	host:SetHeight(GT_PREVIEW_H)
	host.spacer = host
	SarychUI.OptionsPreviews:Style(host)

	local stage = CreateFrame("Frame", nil, host, nil, "arena.preview:34")
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
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(self, host) else tinsert(self._instances, host) end
	return host
end
