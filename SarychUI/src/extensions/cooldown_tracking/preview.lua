local CreateFrame = SarychUI.OptionsPool and SarychUI.OptionsPool.CreateFrame or CreateFrame
-- Party Abilities options preview. Synthetic frames never register unit events.
local SUI = SarychUI
local extension = SUI.extensions.party_abilities
local Glow = SUI.PlatesAurasGlow
local Preview = { _instances = {} }
SUI.PartyAbilitiesPreview = Preview

local WHITE = "Interface\\Buttons\\WHITE8X8"
local STATUS = "Interface\\TargetingFrame\\UI-StatusBar"
local PARTY_ART = "Interface\\TargetingFrame\\UI-PartyFrame"
local RAID_ART = "Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\RaidFrame\\"
local PREVIEW_HEIGHT = 320
local samples = {
	{ class = "PRIEST", race = "Human", spec = "Discipline", portrait = "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human", power = { 0, 0.35, 1 } },
	{ class = "WARRIOR", race = "Orc", spec = "Arms", portrait = "Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc", power = { 0.72, 0.12, 0.1 } },
	{ class = "ROGUE", race = "NightElf", spec = "Subtlety", portrait = "Interface\\CharacterFrame\\TemporaryPortrait-Male-NightElf", power = { 1, 0.85, 0.05 } },
}

local function Color(class)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	return c and c.r or 0, c and c.g or 1, c and c.b or 0
end

local function Flat(parent, layer, r, g, b, a)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetTexture(WHITE)
	tex:SetVertexColor(r, g, b, a or 1)
	return tex
end

local Visible = SUI.WidgetAPI.SetShown

local function Bar(parent, texture, value)
	local bar = CreateFrame("StatusBar", nil, parent, nil, "cooldown_tracking.preview:1")
	bar:SetStatusBarTexture(texture)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(value)
	return bar
end

local function SampleName(class)
	return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
end

local function Classic(parent, sample)
	-- PartyMemberFrameTemplate in FrameXML/PartyFrameTemplates.xml: 128x53,
	-- 37x37 portrait at 7,-6 and 70x8 bars at 47,-12 / 47,-21.
	local frame = CreateFrame("Frame", nil, parent, nil, "cooldown_tracking.preview:2")
	frame:SetSize(128, 53)
	local shade = Flat(frame, "BACKGROUND", 0, 0, 0, 0.5)
	shade:SetSize(72, 20)
	shade:SetPoint("TOPLEFT", frame, "TOPLEFT", 45, -11)
	local portrait = frame:CreateTexture(nil, "ARTWORK")
	portrait:SetTexture(sample.portrait)
	portrait:SetSize(37, 37)
	portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -6)
	local health = Bar(frame, STATUS, 0.78)
	health:SetSize(70, 8)
	health:SetPoint("TOPLEFT", frame, "TOPLEFT", 47, -12)
	local power = Bar(frame, STATUS, 0.62)
	power:SetSize(70, 8)
	power:SetPoint("TOPLEFT", frame, "TOPLEFT", 47, -21)
	power:SetStatusBarColor(unpack(sample.power))
	local chrome = CreateFrame("Frame", nil, frame, nil, "cooldown_tracking.preview:3")
	chrome:SetAllPoints(frame)
	chrome:SetFrameLevel(math.max(health:GetFrameLevel(), power:GetFrameLevel()) + 1)
	chrome:EnableMouse(false)
	local art = chrome:CreateTexture(nil, "ARTWORK")
	art:SetTexture(PARTY_ART)
	art:SetSize(128, 64)
	art:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
	local name = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	name:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 50, 43)
	name:SetWidth(68)
	name:SetJustifyH("LEFT")
	name:SetText(SampleName(sample.class))
	frame.health, frame.power = health, power
	return frame
end

local function Arena(parent, sample)
	-- Blizzard ArenaEnemyFrameTemplate: 102x32, with 70x8 bars.
	local frame = CreateFrame("Frame", nil, parent, nil, "cooldown_tracking.preview:4")
	frame:SetSize(102, 32)
	local portrait = frame:CreateTexture(nil, "BACKGROUND")
	portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
	local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[sample.class]
	if coords then portrait:SetTexCoord(unpack(coords)) end
	portrait:SetSize(30, 30)
	portrait:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -4)
	local shade = Flat(frame, "BACKGROUND", 0, 0, 0, 0.5)
	shade:SetSize(72, 17)
	shade:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -10)
	local health = Bar(frame, STATUS, 0.78)
	health:SetSize(70, 8)
	health:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -12)
	local power = Bar(frame, STATUS, 0.62)
	power:SetSize(70, 8)
	power:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -20)
	power:SetStatusBarColor(unpack(sample.power))
	local chrome = CreateFrame("Frame", nil, frame, nil, "cooldown_tracking.preview:5")
	chrome:SetAllPoints(frame)
	chrome:SetFrameLevel(math.max(health:GetFrameLevel(), power:GetFrameLevel()) + 1)
	local art = chrome:CreateTexture(nil, "ARTWORK")
	art:SetTexture("Interface\\ArenaEnemyFrame\\UI-ArenaTargetingFrame")
	art:SetTexCoord(0, 0.796, 0, 0.5)
	art:SetSize(102, 32)
	art:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
	local name = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	name:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 24)
	name:SetText(SampleName(sample.class))
	frame.health, frame.power = health, power
	frame.portrait, frame.shade, frame.art, frame.name = portrait, shade, art, name
	local function SampleIcon(texture)
		local icon = CreateFrame("Frame", nil, frame, nil, "cooldown_tracking.preview:6")
		icon:SetSize(26, 26)
		local art = icon:CreateTexture(nil, "ARTWORK")
		art:SetAllPoints(icon)
		art:SetTexture(texture)
		art:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		return icon
	end
	frame.trinket = SampleIcon(sample.race == "Human" and "Interface\\Icons\\Spell_Shadow_Charm"
		or "Interface\\Icons\\INV_Jewelry_TrinketPVP_02")
	frame.racial = SampleIcon(sample.race == "Human" and "Interface\\Icons\\Spell_Shadow_Charm"
		or sample.race == "Orc" and "Interface\\Icons\\Racial_Orc_BerserkerStrength"
		or "Interface\\Icons\\Ability_Ambush")
	return frame
end

local function GladiusArena(parent, sample)
	local frame = Arena(parent, sample)
	local arenaModule = SUI.modules and SUI.modules.arena
	local style = arenaModule and arenaModule.GetStyleSettings and arenaModule:GetStyleSettings("gladius") or {}
	local barWidth = math.max(80, math.min(300, tonumber(style.barWidth) or 165))
	local castHeight = math.max(12, math.min(30, tonumber(style.castBarHeight) or 18))
	local castTextSize = math.max(1, math.min(20, tonumber(style.castTextSize) or 10))
	local castWidth = barWidth + 41 - castHeight
	local barTexture = [[Interface\AddOns\SarychUI\media\arena\Minimalist]]
	frame:SetSize(barWidth + 40, math.max(56, 44 + castHeight))
	frame:SetBackdrop({ bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16 })
	frame:SetBackdropColor(0, 0, 0, 0.3)
	frame.shade:Hide()
	frame.art:Hide()
	frame.portrait:ClearAllPoints()
	frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 0)
	frame.portrait:SetSize(40, 41)
	if CLASS_BUTTONS and CLASS_BUTTONS[sample.class] then
		frame.portrait:SetTexture([[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]])
		frame.portrait:SetTexCoord(unpack(CLASS_BUTTONS[sample.class]))
	end
	frame.health:ClearAllPoints()
	frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, 0)
	frame.health:SetSize(barWidth, 25)
	frame.health:SetStatusBarTexture(barTexture)
	frame.power:ClearAllPoints()
	frame.power:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -26)
	frame.power:SetSize(barWidth, 15)
	frame.power:SetStatusBarTexture(barTexture)
	for _, bar in ipairs({ frame.health, frame.power }) do
		local bg = bar:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(bar)
		bg:SetTexture(barTexture)
		bg:SetAlpha(0.3)
	end
	local function ValueText(bar, size, value)
		local label = bar:CreateFontString(nil, "OVERLAY")
		label:SetFont(STANDARD_TEXT_FONT, size)
		label:SetPoint("RIGHT", bar, "RIGHT", -5, 0)
		label:SetShadowColor(0, 0, 0, 1)
		label:SetShadowOffset(1, -1)
		label:SetText(value)
	end
	ValueText(frame.health, 11, "78%")
	ValueText(frame.power, 10, "62/100")
	if style.showSpecText ~= false then
		local spec = frame.power:CreateFontString(nil, "OVERLAY")
		spec:SetFont(STANDARD_TEXT_FONT, 10)
		spec:SetPoint("LEFT", frame.power, "LEFT", 21, 0)
		spec:SetText(sample.spec or "")
		local specFramework = SarychUI.UnitSpecialization
		local iconPath = specFramework and specFramework:GetIcon(sample.class, sample.spec)
		if iconPath then
			local specIcon = frame.power:CreateTexture(nil, "OVERLAY")
			specIcon:SetSize(13, 13)
			specIcon:SetPoint("LEFT", frame.power, "LEFT", 4, 0)
			specIcon:SetTexture(iconPath)
		end
	end
	frame.name:ClearAllPoints()
	frame.name:SetPoint("LEFT", frame.health, "LEFT", 5, 0)
	local cast = Bar(frame, barTexture, 0.65)
	cast:SetPoint("TOPLEFT", frame, "TOPLEFT", castHeight - 1, -43)
	cast:SetSize(castWidth, castHeight)
	cast:SetStatusBarColor(1, 1, 0)
	local castBg = cast:CreateTexture(nil, "BACKGROUND")
	castBg:SetPoint("RIGHT", cast, "RIGHT", 0, 0)
	castBg:SetSize(castWidth + castHeight, castHeight)
	castBg:SetTexture(barTexture)
	castBg:SetAlpha(0.3)
	local icon = cast:CreateTexture(nil, "ARTWORK")
	icon:SetSize(castHeight, castHeight)
	icon:SetPoint("RIGHT", cast, "LEFT", 0, 0)
	icon:SetTexture([[Interface\Icons\Spell_Fire_FlameBolt]])
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	local spell = cast:CreateFontString(nil, "OVERLAY")
	spell:SetFont(STANDARD_TEXT_FONT, castTextSize)
	spell:SetPoint("LEFT", cast, "LEFT", 5, 1)
	spell:SetText(SarychUI:T("ui.options_b162ce333e"))
	local remaining = cast:CreateFontString(nil, "OVERLAY")
	remaining:SetFont(STANDARD_TEXT_FONT, castTextSize)
	remaining:SetPoint("RIGHT", cast, "RIGHT", -5, 1)
	remaining:SetText("1.5")
	return frame
end

local function Compact(parent, sample)
	local frame = CreateFrame("Frame", nil, parent, nil, "cooldown_tracking.preview:7")
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(RAID_ART .. "Raid-Bar-Hp-Bg")
	bg:SetTexCoord(0, 1, 0, 0.53125)
	bg:SetAllPoints(frame)
	local health = Bar(frame, RAID_ART .. "Raid-Bar-Hp-Fill", 0.78)
	local power = Bar(frame, RAID_ART .. "Raid-Bar-Resource-Fill", 0.62)
	local powerBg = power:CreateTexture(nil, "BACKGROUND")
	powerBg:SetTexture(RAID_ART .. "Raid-Bar-Resource-Background")
	powerBg:SetAllPoints(power)
	power:SetStatusBarColor(unpack(sample.power))
	local border = CreateFrame("Frame", nil, frame, nil, "cooldown_tracking.preview:8")
	border:SetAllPoints(frame)
	local top = border:CreateTexture(nil, "OVERLAY")
	top:SetTexture(RAID_ART .. "Raid-HSeparator")
	top:SetPoint("BOTTOMLEFT", border, "TOPLEFT", 0, -7)
	top:SetPoint("BOTTOMRIGHT", border, "TOPRIGHT", 0, -7)
	top:SetHeight(8)
	local bottom = border:CreateTexture(nil, "OVERLAY")
	bottom:SetTexture(RAID_ART .. "Raid-HSeparator")
	bottom:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, 1)
	bottom:SetPoint("TOPRIGHT", border, "BOTTOMRIGHT", 0, 1)
	bottom:SetHeight(8)
	local left = border:CreateTexture(nil, "OVERLAY")
	left:SetTexture(RAID_ART .. "Raid-VSeparator")
	left:SetPoint("TOPRIGHT", border, "TOPLEFT", 7, 0)
	left:SetPoint("BOTTOMRIGHT", border, "BOTTOMLEFT", 7, 0)
	left:SetWidth(8)
	local right = border:CreateTexture(nil, "OVERLAY")
	right:SetTexture(RAID_ART .. "Raid-VSeparator")
	right:SetPoint("TOPLEFT", border, "TOPRIGHT", -1, 0)
	right:SetPoint("BOTTOMLEFT", border, "BOTTOMRIGHT", -1, 0)
	right:SetWidth(8)
	local divider = border:CreateTexture(nil, "OVERLAY")
	divider:SetTexture(RAID_ART .. "Raid-HSeparator")
	divider:SetHeight(8)
	local name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	name:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
	name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
	name:SetJustifyH("LEFT")
	name:SetText(SampleName(sample.class))
	local value = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	value:SetJustifyH("CENTER")
	frame.health, frame.power, frame.border, frame.divider, frame.value = health, power, border, divider, value
	return frame
end

local function CompactSettings()
	local profile = GetActiveRaidProfile and GetActiveRaidProfile()
	local function Option(key)
		return profile and GetRaidProfileOption and GetRaidProfileOption(profile, key)
	end
	local defaults = DefaultCompactUnitFrameOptions or {}
	local setup = DefaultCompactUnitFrameSetupOptions or {}
	local live = _G.CompactPartyFrameMember1 or _G.CompactRaidGroup1Member1 or _G.CompactRaidFrame1
	local width = tonumber(Option("frameWidth")) or tonumber(setup.width) or 72
	local height = tonumber(Option("frameHeight")) or tonumber(setup.height) or 36
	local power = Option("displayPowerBar")
	if power == nil then power = setup.displayPowerBar ~= false end
	local classColors = Option("useClassColors")
	if classColors == nil then classColors = defaults.useClassColors ~= false end
	local healthText = Option("healthText") or defaults.healthText or "perc"
	local displayBorder = Option("displayBorder")
	if displayBorder == nil then displayBorder = setup.displayBorder ~= false end
	local override = (live and live.optionTable and live.optionTable.healthBarColorOverride)
		or defaults.healthBarColorOverride
	return width, height, power, classColors, healthText, displayBorder, override
end

local function Abilities(db, sample)
	local list = {}
	for id, data in pairs(db.spells or {}) do
		if (data.class == sample.class or data.class == "OTHER")
			and (not data.race or data.race == sample.race)
			and (not data.excludeRace or data.excludeRace ~= sample.race)
			and data.enabled ~= false
			and not data.item and not data.trinket
			and (not db.arena or not data.race)
			and (GetSpellInfo(id) or data.icon) then
			list[#list + 1] = { id = id, data = data }
		end
	end
	table.sort(list, function(a, b)
		local ao, bo = tonumber(a.data.order) or 100, tonumber(b.data.order) or 100
		return ao == bo and a.id < b.id or ao < bo
	end)
	return list
end

local function NewIcon(parent)
	local icon = CreateFrame("Frame", nil, parent, nil, "cooldown_tracking.preview:9")
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)
	icon.texture:SetTexCoord(0, 1, 0, 1)
	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate", "cooldown_tracking.preview:10")
	icon.cooldown:SetAllPoints(icon)
	icon.cooldown:SetAlpha(0.65)
	icon.cooldown.__sary_partyAbility = true
	extension:PrepareIcon(icon)
	icon:SetScript("OnHide", function(self) self._procIntroPlayed = nil end)
	return icon
end

local function ShownAbilities(db, sample)
	local list = Abilities(db, sample)
	local shown = {}
	for index, item in ipairs(list) do
		local onCooldown = (tonumber(item.data.cooldown) or 0) > 0 and index % 2 == 1
		local activeEffect = index % 4 == 2
		local mode = db.displayMode or "all"
		if onCooldown or mode == "all" or (mode == "cooldown_active" and activeEffect) then
			shown[#shown + 1] = { id = item.id, data = item.data,
				onCooldown = onCooldown, activeEffect = activeEffect }
		end
	end
	return shown
end

local function IconSpan(shown, layout)
	local cellSize = tonumber(layout.size) or 24
	for _, item in ipairs(shown) do cellSize = math.max(cellSize, tonumber(item.data.size) or 0) end
	local perRow = math.max(1, tonumber(layout.perRow) or 6)
	local rows = math.ceil(#shown / perRow)
	return rows * (cellSize + (tonumber(layout.spacing) or 2)), cellSize
end

local function RefreshIcons(host, row, layout, frame, shown, cellSize, autoAnchor,
	anchorOffsetX, anchorOffsetY, desaturateAllowed)
	local now = GetTime()
	local rowCount = math.ceil(#shown / math.max(1, tonumber(layout.perRow) or 6))
	for index, item in ipairs(shown) do
		local icon = row.icons[index] or NewIcon(host)
		row.icons[index] = icon
		if icon.spellID ~= item.id then
			icon.spellID = item.id
			icon.texture:SetTexture(extension:EntryIcon(item.id, item.data))
			icon.timerStart = nil
		end
		extension:PositionIcon(icon, frame, layout, index, item.data, cellSize, autoAnchor, rowCount,
			host._mode == "arena", nil, nil, anchorOffsetX, anchorOffsetY)
		extension:ApplyIconAppearance(icon, layout)
		local desaturated = desaturateAllowed
			and layout.desaturateOnCooldown == true
			and item.onCooldown
		if icon._desaturated ~= desaturated then
			icon.texture:SetDesaturated(desaturated)
			icon._desaturated = desaturated
		end
		if item.onCooldown then
			local duration = math.max(1, tonumber(item.data.cooldown) or 60)
			local start = icon.timerStart
			if icon.timerDuration ~= duration or not start or now >= start + duration then
				start = now - duration * 0.25
			end
			extension:SetIconTimer(icon, start, duration)
		else
			extension:SetIconTimer(icon, nil)
		end
		icon.texture:SetVertexColor(1, 1, 1)
		local highlight = item.data.highlight ~= nil and item.data.highlight ~= false and item.data.highlight ~= 0
		local when = item.data.glowWhen or "cooldown"
		local glowNow = highlight and (when == "always" or (when == "cooldown" and item.onCooldown)
			or (when == "ready" and not item.onCooldown) or (when == "active" and item.activeEffect))
		if glowNow and (host._forceGlow or not icon.glowing or icon.glowData ~= item.data) then
			Glow.Start(icon, item.data, icon._procIntroPlayed)
			if item.data.glowType == "proc" then icon._procIntroPlayed = true end
			icon.glowing, icon.glowData = true, item.data
		elseif not glowNow and icon.glowing then
			Glow.Stop(icon); icon.glowing, icon.glowData = nil, nil
		end
		icon:Show()
	end
	for index = #shown + 1, #row.icons do
		local icon = row.icons[index]
		icon:Hide()
		if icon.timerStart and icon.cooldown then
			CooldownFrame_SetTimer(icon.cooldown, 0, 0, 0)
			if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, 0, 0, 0) end
			icon.timerStart, icon.timerDuration = nil, nil
		end
		if icon.glowing then Glow.Stop(icon); icon.glowing, icon.glowData = nil, nil end
	end
end

local function ReleaseIconCooldown(icon)
	if not icon then return end
	if icon.cooldown then
		CooldownFrame_SetTimer(icon.cooldown, 0, 0, 0)
		if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(icon.cooldown, 0, 0, 0) end
	end
	icon.timerStart, icon.timerDuration = nil, nil
	if icon.glowing then Glow.Stop(icon); icon.glowing, icon.glowData = nil, nil end
end

function Preview:RefreshAll(forceGlow)
	for _, host in ipairs(self._instances) do
		if host and host.GetParent and host:GetParent() and host.Refresh then
			host._forceGlow = forceGlow and true or false
			host:Refresh()
			host._forceGlow = nil
		end
	end
end

function Preview:ClearStickyHosts()
    if SarychUI.OptionsPool then return SarychUI.OptionsPool:ClearPreviews(self) end
	for _, host in ipairs(self._instances) do
		if host then
			host:SetScript("OnUpdate", nil)
			host:SetScript("OnShow", nil)
			for _, row in ipairs(host.rows or {}) do
				for _, icon in ipairs(row.icons) do ReleaseIconCooldown(icon) end
			end
			host:Hide()
			host:SetParent(nil)
		end
	end
	self._instances = {}
end

function Preview:Create(parent, mode)
	self:ClearStickyHosts()
	local host = CreateFrame("Frame", nil, parent, nil, "cooldown_tracking.preview:11")
	host:SetHeight(PREVIEW_HEIGHT)
	host._mode = mode
	host.spacer = host
	local theme = SUI.OptionsTheme
	if theme and theme.ApplyFlat then
		theme:ApplyFlat(host, theme.colors.panelBg, theme.colors.borderSoft)
	else
		local bg = Flat(host, "BACKGROUND", 0.07, 0.07, 0.09, 0.97)
		bg:SetAllPoints(host)
	end
	local title = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -5)
	title:SetPoint("TOPRIGHT", host, "TOPRIGHT", -8, -5)
	title:SetJustifyH("LEFT")
	host.rows = {}
	for index, sample in ipairs(samples) do
		if mode == "arena" and index > 2 then break end
		local row = { sample = sample, icons = {} }
		if mode == "arena" then
			row.arenaClassic = Arena(host, sample)
			row.arenaGladius = GladiusArena(host, sample)
		else
			row.classic = Classic(host, sample)
			row.compact = Compact(host, sample)
		end
		host.rows[index] = row
	end

	function host:Refresh()
		local hostWidth = self:GetWidth()
		if not hostWidth or hostWidth < 200 then return end
		self._laidOutWidth = hostWidth
		local db = extension:GetDB()
		local kind = self._mode == "arena" and "arena" or extension:GetLayoutKind()
		local arenaDB = SUI.db and SUI.db.profile and SUI.db.profile.modules and SUI.db.profile.modules.arena
		local arenaModule = SUI.modules and SUI.modules.arena
		local enemy = arenaModule and arenaModule.GetEnemyAbilitySettings and arenaModule:GetEnemyAbilitySettings() or {}
		local arenaStyle = arenaDB and arenaDB.frameType == "gladius" and "gladius" or "classic"
		local layout = kind == "arena" and (enemy.layout or {}) or (db.layouts and db.layouts[kind] or {})
		local trinkets = arenaDB and arenaDB.Trinkets or {}
		local teamHasPair = false
		if kind == "arena" and trinkets.enabled ~= false and trinkets.racialEnabled ~= false then
			for _, row in ipairs(self.rows) do
				if row.sample.race ~= "Human" then teamHasPair = true; break end
			end
		end
		local otherLayout = kind == "arena" and {} or (db.layouts and db.layouts[kind == "compact" and "blizzard" or "compact"] or {})
		local w, h, powerShown, classColors, healthText, borderShown, override
		if kind == "arena" then
			local style = arenaModule and arenaModule.GetStyleSettings and arenaModule:GetStyleSettings("gladius") or {}
			w = arenaStyle == "gladius" and (math.max(80, math.min(300, tonumber(style.barWidth) or 165)) + 40) or 102
			h = arenaStyle == "gladius" and math.max(56, 44 + math.max(12, tonumber(style.castBarHeight) or 18)) or 32
		else w, h, powerShown, classColors, healthText, borderShown, override = CompactSettings() end
		title:SetText(kind == "arena" and (SarychUI:T("ui.options_1441eb0020") .. (arenaStyle == "gladius" and "Gladius" or SarychUI:T("ui.options_03ced8ccad")))
			or SUI.L[kind == "compact" and "PA_Compact" or "PA_Blizzard"])
		local frameW = kind == "arena" and w or kind == "compact" and w or 128
		local x = math.max(110, math.floor((hostWidth - frameW) / 2))
		local y = -37
		for _, row in ipairs(self.rows) do
			local frame = kind == "arena" and (arenaStyle == "gladius" and row.arenaGladius or row.arenaClassic)
				or kind == "compact" and row.compact or row.classic
			for _, candidate in pairs({ row.classic, row.compact, row.arenaClassic, row.arenaGladius }) do
				if candidate ~= frame then candidate:Hide() end
			end
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
			if kind == "compact" then
				frame:SetSize(w, h)
				Visible(frame.border, borderShown)
				frame.divider:ClearAllPoints()
				frame.divider:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, powerShown and 9 or 1)
				frame.divider:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, powerShown and 9 or 1)
				Visible(frame.divider, borderShown and powerShown)
				frame.health:ClearAllPoints()
				frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
				frame.health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, powerShown and 9 or 1)
				frame.power:ClearAllPoints()
				frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, -2)
				frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
				Visible(frame.power, powerShown)
				frame.value:ClearAllPoints()
				frame.value:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, h / 3 - 2)
				frame.value:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, h / 3 - 2)
				frame.value:SetText(healthText == "none" and "" or healthText == "perc" and "78%" or "7800")
				local r, g, b = Color(row.sample.class)
				if override then r, g, b = override.r or r, override.g or g, override.b or b
				elseif not classColors then r, g, b = 0, 1, 0 end
				frame.health:SetStatusBarColor(r, g, b)
			else
				local framework = SUI.UnitFrameLayers
				local ufl = framework and framework:Settings()
				local classHP = framework and framework:IsEnabled() and (not ufl or ufl.classColorHP ~= false)
				local r, g, b = 0, 1, 0
				if classHP then r, g, b = Color(row.sample.class) end
				frame.health:SetStatusBarColor(r, g, b)
			end
			frame:Show()
			local autoAnchor, anchorOffsetX, anchorOffsetY
			if kind == "arena" then
				local tr = arenaDB and arenaDB.Trinkets or {}
				local gladius = arenaStyle == "gladius"
				local scale = gladius and 1 or (tonumber(tr.scale) or 1)
				local showTrinket = tr.enabled ~= false
				local showRacial = tr.racialEnabled ~= false and row.sample.race ~= "Human"
				local column = not gladius and showTrinket and showRacial and tr.layout == "COLUMN"
				local sharedColumn = not gladius and teamHasPair and tr.layout == "COLUMN"
				frame.trinket:SetSize(gladius and 40 or 26, gladius and 41 or 26)
				frame.racial:SetSize(gladius and 40 or 26, gladius and 41 or 26)
				frame.trinket:SetScale(scale)
				frame.racial:SetScale(scale)
				frame.trinket:ClearAllPoints()
				if gladius then frame.trinket:SetPoint("TOPLEFT", frame, "TOPRIGHT", 1, 0)
				elseif column then
					frame.trinket:SetPoint("LEFT", frame, "RIGHT", 2,
						(26 + (tonumber(tr.spacing) or 5)) / 2)
				else frame.trinket:SetPoint("LEFT", frame, "RIGHT", 2, -2) end
				frame.racial:ClearAllPoints()
				if gladius then
					if showTrinket then frame.racial:SetPoint("LEFT", frame.trinket, "RIGHT", 1, 0)
					else frame.racial:SetPoint("TOPLEFT", frame, "TOPRIGHT", 1, 0) end
				elseif column then
					frame.racial:SetPoint("TOP", frame.trinket, "BOTTOM", 0,
						-(tonumber(tr.spacing) or 5))
				else
					frame.racial:SetPoint("LEFT", showTrinket and frame.trinket or frame,
						"RIGHT", showTrinket and (tonumber(tr.spacing) or 5) or 2,
						showTrinket and 0 or -2)
				end
				if showTrinket then frame.trinket:Show() else frame.trinket:Hide() end
				if showRacial then frame.racial:Show() else frame.racial:Hide() end
				if layout.side == "LEFT" then
					autoAnchor = gladius and frame.portrait or frame
				elseif sharedColumn then
					autoAnchor = frame
					anchorOffsetX = 28 * scale
					anchorOffsetY = -2 * scale
				else
					autoAnchor = showRacial and frame.racial or showTrinket and frame.trinket or frame
					if teamHasPair and showTrinket and not showRacial then
						anchorOffsetX = gladius and 41 or (26 + (tonumber(tr.spacing) or 5)) * scale
					end
				end
			end
			local shown = ShownAbilities(kind == "arena"
				and { spells = db.spells, displayMode = enemy.displayMode or "all", arena = true } or db, row.sample)
			if kind == "arena" then
				local limit = row == self.rows[1] and 3
					or math.min(8, math.max(6, (tonumber(layout.perRow) or 5) + 1))
				for index = #shown, limit + 1, -1 do shown[index] = nil end
			end
			local iconSpan, cell = IconSpan(shown, layout)
			local otherSpan = kind == "arena" and 0 or IconSpan(shown, otherLayout)
			RefreshIcons(self, row, layout, frame, shown, cell, autoAnchor,
				anchorOffsetX, anchorOffsetY, kind == "arena" and (enemy.displayMode or "all") == "all")
			local rowHeight = math.max(h, iconSpan, otherSpan) + 22
			y = y - rowHeight
		end
		local height = math.max(PREVIEW_HEIGHT, -y + 10)
		if math.abs(self:GetHeight() - height) >= 1 then self:SetHeight(height) end
		if self._kind and self._kind ~= kind and SUI.NotifySarychUIOptionsChange then
			SUI:NotifySarychUIOptionsChange()
		end
		self._kind = kind
	end

	host:SetScript("OnShow", function(self)
		self:Refresh()
		if self._mode == "arena" and self._laidOutWidth then self:SetScript("OnSizeChanged", nil) end
	end)
	if mode == "arena" then
		-- The options window can report size changes while it is being dragged.
		-- Arena preview geometry only needs its initial width and explicit setting refreshes.
		host:SetScript("OnSizeChanged", function(self, width)
			if self._laidOutWidth or not width or width < 200 then return end
			self:Refresh()
			if self._laidOutWidth then self:SetScript("OnSizeChanged", nil) end
		end)
	else
		host:SetScript("OnSizeChanged", function(self, width)
			if width and width >= 200 and (not self._laidOutWidth or math.abs(width - self._laidOutWidth) >= 1) then self:Refresh() end
		end)
	end
	if mode ~= "arena" then host:SetScript("OnUpdate", function(self, delta)
		self._elapsed = (self._elapsed or 0) + delta
		if self._elapsed < 0.5 then return end
		self._elapsed = 0
		self:Refresh()
	end) end
	if SarychUI.OptionsPool then SarychUI.OptionsPool:TrackPreview(self, host) else table.insert(self._instances, host) end
	return host
end
