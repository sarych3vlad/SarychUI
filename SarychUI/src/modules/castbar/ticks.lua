-- Channel tick marks for classic and Dragonflight cast bars.
-- Tick counts follow Gnosis SetupChanneledSpellsTable (WotLK / Cata).

local module = SarychUI and SarychUI.modules and SarychUI.modules.castbar
if not module then return end

local Ticks = {
	active = false,
	byName = {},
}
module.Ticks = Ticks

local min, max = math.min, math.max
local MAX_TICKS = 15
local UNITS = { "player", "target", "focus" }
local CLASSIC_TICK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"
local DF_TICK_TEXTURE = "Interface\\AddOns\\SarychUI\\media\\castbar\\CastingBarSpark"

local function GetTickTexture()
	if module.IsDragonflight and module:IsDragonflight() then
		return DF_TICK_TEXTURE
	end
	return CLASSIC_TICK_TEXTURE
end

-- id, ticks, instantFirst (penance / evocation-style)
local WOTLK_SPELLS = {
	{ 15407, 3 }, { 48156, 3 }, -- Mind Flay
	{ 48045, 5 }, { 53023, 5 }, -- Mind Sear
	{ 47540, 3, true }, { 52985, 3, true }, -- Penance
	{ 64843, 4 }, -- Divine Hymn
	{ 64901, 4 }, -- Hymn of Hope
	{ 10, 8 }, { 42940, 8 }, -- Blizzard
	{ 5143, 5 }, { 42846, 5 }, -- Arcane Missiles
	{ 12051, 4 }, -- Evocation
	{ 1120, 5 }, { 47855, 5 }, -- Drain Soul
	{ 689, 5 }, { 47857, 5 }, -- Drain Life
	{ 5138, 5 }, -- Drain Mana
	{ 5740, 4 }, { 4629, 4 }, { 47820, 4 }, -- Rain of Fire
	{ 1949, 15 }, { 47823, 15 }, -- Hellfire
	{ 755, 3 }, { 47856, 3 }, -- Health Funnel
	{ 740, 4 }, { 48447, 4 }, -- Tranquility
	{ 16914, 10 }, { 48467, 10 }, -- Hurricane
	{ 1510, 6 }, { 58434, 6 }, -- Volley
}

local CATA_SPELLS = {
	{ 15407, 3 }, { 48045, 5 },
	{ 47540, 3, true },
	{ 64843, 4 }, { 64901, 4 },
	{ 10, 8 }, { 5143, 5 }, { 12051, 5, true },
	{ 1120, 5 }, { 689, 3 }, { 5138, 3 },
	{ 5740, 4 }, { 1949, 15 }, { 755, 3 }, { 79268, 3 },
	{ 740, 4 }, { 16914, 10 },
}

local function GetDB()
	return module.DB and module:DB()
end

local function IsOn(value)
	return value == 1 or value == true
end

function Ticks:GetSettings()
	local db = GetDB()
	local color = db and db.castbarTickColor
	return {
		enabled = not db or IsOn(db.enableCastbarTicks ~= nil and db.enableCastbarTicks or 1),
		player = not db or IsOn(db.enableCastbarTicksPlayer ~= nil and db.enableCastbarTicksPlayer or 1),
		target = not db or IsOn(db.enableCastbarTicksTarget ~= nil and db.enableCastbarTicksTarget or 1),
		focus = not db or IsOn(db.enableCastbarTicksFocus ~= nil and db.enableCastbarTicksFocus or 1),
		width = db and tonumber(db.castbarTickWidth) or 2,
		r = color and color.r or 1,
		g = color and color.g or 1,
		b = color and color.b or 1,
		a = color and color.a or 0.9,
	}
end

function Ticks:RebuildSpellMap()
	for name in pairs(self.byName) do
		self.byName[name] = nil
	end
	local toc = select(4, GetBuildInfo())
	local list = (toc and toc >= 40000) and CATA_SPELLS or WOTLK_SPELLS
	for _, data in ipairs(list) do
		local name = GetSpellInfo(data[1])
		if name then
			self.byName[name] = {
				ticks = data[2],
				instant = data[3] and true or false,
			}
		end
	end
end

function Ticks:GetTickCount(spellName, unitType)
	if not spellName then
		return 0
	end
	local info = self.byName[spellName]
	if not info or not info.ticks or info.ticks <= 1 then
		return 0
	end
	return info.instant and (info.ticks - 1) or info.ticks
end

local function EnsureHolder(bar)
	if bar._suiTickHolder and bar._suiChannelTicks then
		return bar._suiTickHolder, bar._suiChannelTicks
	end

	-- StatusBar children follow the fill, so ticks must live on a sibling overlay.
	local parent = bar:GetParent() or bar
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetFrameLevel((bar.GetFrameLevel and bar:GetFrameLevel() or 0) + 6)
	holder:SetAllPoints(bar)
	holder:Hide()

	local ticks = {}
	for i = 1, MAX_TICKS do
		local tick = holder:CreateTexture(nil, "OVERLAY")
		tick:SetTexture(GetTickTexture())
		tick:SetBlendMode("ADD")
		tick:SetTexCoord(0, 1, 0, 1)
		tick:Hide()
		ticks[i] = tick
	end

	bar._suiTickHolder = holder
	bar._suiChannelTicks = ticks

	if not bar._suiTickSizeHooked and bar.HookScript then
		bar._suiTickSizeHooked = true
		bar:HookScript("OnSizeChanged", function(self)
			if self._suiTickUpdating or not self._suiTickSpell then
				return
			end
			Ticks:Update(self, self._suiTickSpell, self._suiTickUnit)
		end)
		bar:HookScript("OnHide", function(self)
			if self._suiTickHolder then
				self._suiTickHolder:Hide()
			end
		end)
	end
	return holder, ticks
end

function Ticks:Hide(bar)
	if not bar then
		return
	end
	bar._suiTickSpell = nil
	bar._suiTickUnit = nil
	bar._suiTickTimeline = nil
	if bar._suiTickHolder then
		bar._suiTickHolder:Hide()
	end
	local ticks = bar._suiChannelTicks
	if not ticks then
		return
	end
	for i = 1, MAX_TICKS do
		if ticks[i] then
			ticks[i]:Hide()
		end
	end
end

function Ticks:Update(bar, spellName, unitType, startTime, endTime, resetTimeline)
	if not bar or bar._suiTickUpdating then
		return
	end
	if not self.active then
		self:Hide(bar)
		return
	end
	local settings = self:GetSettings()
	if not settings.enabled then
		self:Hide(bar)
		return
	end
	if unitType == "player" and not settings.player then
		self:Hide(bar)
		return
	end
	if unitType == "target" and not settings.target then
		self:Hide(bar)
		return
	end
	if unitType == "focus" and not settings.focus then
		self:Hide(bar)
		return
	end
	local tickCount = self:GetTickCount(spellName, unitType)
	if tickCount <= 1 then
		self:Hide(bar)
		return
	end

	-- Keep the original channel's tick times. A channel pushback changes the
	-- end time, but it does not create a fresh, evenly spaced set of ticks.
	if not startTime or not endTime then
		local currentSpell, _, _, _, currentStart, currentEnd = UnitChannelInfo(unitType)
		if currentSpell == spellName then
			startTime, endTime = currentStart, currentEnd
		end
	end
	local timeline = bar._suiTickTimeline
	local guid = UnitGUID and UnitGUID(unitType)
	if startTime and endTime and endTime > startTime then
		if resetTimeline or not timeline or timeline.spell ~= spellName
			or timeline.unit ~= unitType or timeline.guid ~= guid
			or timeline.tickCount ~= tickCount then
			local duration = endTime - startTime
			timeline = {
				spell = spellName, unit = unitType, guid = guid,
				tickCount = tickCount, duration = duration, times = {},
			}
			for i = 1, tickCount do
				timeline.times[i] = endTime - (i - 1) * duration / tickCount
			end
			bar._suiTickTimeline = timeline
		end
		timeline.endTime = endTime
	end

	bar._suiTickUpdating = true
	local holder, ticks = EnsureHolder(bar)
	bar._suiTickSpell = spellName
	bar._suiTickUnit = unitType
	local width = bar:GetWidth() or 0
	local height = bar:GetHeight() or 0
	if width <= 1 or height <= 1 then
		bar._suiTickUpdating = nil
		return
	end

	holder:SetAllPoints(bar)
	holder:Show()

	-- Gnosis: N marks at 0, 1/N, … (N-1)/N. After pushback their original
	-- timestamps stay fixed while the channel end moves.
	local step = width / tickCount
	local isDF = module.IsDragonflight and module:IsDragonflight()
	local texture = GetTickTexture()
	local sparkW = isDF and (6 + (settings.width or 2) * 2) or (16 + (settings.width or 2) * 4)
	local sparkH = isDF and max(height * 2, 16) or max(height * 2.4, 32)
	local r, g, b, a = settings.r, settings.g, settings.b, settings.a
	if (r + g + b) < 0.2 then
		r, g, b = 1, 1, 1
	end

	for i = 1, MAX_TICKS do
		local tick = ticks[i]
		if tick then
			local offset = (i - 1) * step
			if i <= tickCount and timeline and timeline.duration > 0 then
				offset = width * (timeline.endTime - timeline.times[i]) / timeline.duration
			end
			if i <= tickCount and offset >= 0 and offset <= width then
				tick:SetTexture(texture)
				tick:SetBlendMode("ADD")
				tick:SetVertexColor(r, g, b, a)
				tick:SetSize(sparkW, sparkH)
				tick:ClearAllPoints()
				tick:SetPoint("CENTER", holder, "LEFT", offset, 0)
				tick:Show()
			else
				tick:Hide()
			end
		end
	end
	bar._suiTickUpdating = nil
end

function Ticks:GetBar(unitType)
	if module.GetStyleFrame then
		return module:GetStyleFrame(unitType)
	end
	return nil
end

function Ticks:RefreshUnit(unit, resetTimeline)
	if unit ~= "player" and unit ~= "target" and unit ~= "focus" then
		return
	end
	local bar = self:GetBar(unit)
	if not bar then
		return
	end
	local spell, _, _, _, startTime, endTime = UnitChannelInfo(unit)
	if spell then
		self:Update(bar, spell, unit, startTime, endTime, resetTimeline)
	else
		self:Hide(bar)
	end
end

function Ticks:RefreshAll()
	for i = 1, #UNITS do
		self:RefreshUnit(UNITS[i])
	end
end

function Ticks:HideAll()
	for i = 1, #UNITS do
		self:Hide(self:GetBar(UNITS[i]))
	end
	if CastingBarFrame then
		self:Hide(CastingBarFrame)
	end
	if TargetFrameSpellBar then
		self:Hide(TargetFrameSpellBar)
	end
	if FocusFrameSpellBar then
		self:Hide(FocusFrameSpellBar)
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:Hide()

eventFrame:SetScript("OnEvent", function(_, event, unit)
	if not Ticks.active then
		return
	end
	if event == "PLAYER_TARGET_CHANGED" then
		Ticks:Hide(Ticks:GetBar("target"))
		Ticks:RefreshUnit("target", true)
		return
	end
	if event == "PLAYER_FOCUS_CHANGED" then
		Ticks:Hide(Ticks:GetBar("focus"))
		Ticks:RefreshUnit("focus", true)
		return
	end
	if unit ~= "player" and unit ~= "target" and unit ~= "focus" then
		return
	end
	if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		Ticks:RefreshUnit(unit, event == "UNIT_SPELLCAST_CHANNEL_START")
	else
		Ticks:Hide(Ticks:GetBar(unit))
	end
end)

function Ticks:Enable()
	self:RebuildSpellMap()
	self.active = true
	if not self.eventsRegistered then
		eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
		eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
		self.eventsRegistered = true
	end
	eventFrame:Show()
	self:RefreshAll()
end

function Ticks:Disable()
	self.active = false
	eventFrame:Hide()
	self:HideAll()
end
