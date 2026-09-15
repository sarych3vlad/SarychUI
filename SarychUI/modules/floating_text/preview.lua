-- SarychUI Floating Text — error filter options preview (UIErrorsFrame look).
-- Animates appear → hold (timeVisible) → fade (fadeDuration) → gap (throttle).

local CreateFrame = CreateFrame
local GetTime = GetTime
local ipairs = ipairs
local pairs = pairs
local max = math.max
local min = math.min
local random = math.random
local sin = math.sin
local tinsert = table.insert
local tonumber = tonumber

SarychUI = SarychUI or {}

local SAMPLE_ERRORS = {
	"Способность пока недоступна.",
	"Вы должны подождать.",
	"Нет места.",
}

local PHASE_HOLD = 1
local PHASE_FADE = 2
local PHASE_GAP = 3

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

local function FloatingTextDB()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods.floating_text
end

--------------------------------------------------------------------
SarychUI.ErrorFilterPreview = SarychUI.ErrorFilterPreview or {}
local Preview = SarychUI.ErrorFilterPreview
Preview._instances = Preview._instances or {}
Preview._live = Preview._live or {}

local function TrackInstance(host)
	tinsert(Preview._instances, host)
end

function Preview:SetLiveValue(key, value)
	self._live[key] = value
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, value)
	else
		self:RefreshAll()
	end
end

function Preview:ClearLiveValue(key)
	if key then
		self._live[key] = nil
	else
		for k in pairs(self._live) do
			self._live[k] = nil
		end
	end
end

function Preview:RefreshAll()
	local alive = {}
	for _, inst in ipairs(Preview._instances) do
		if inst and inst.GetParent and inst:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	Preview._instances = alive
end

function Preview:ClearStickyHosts()
	for _, inst in ipairs(Preview._instances) do
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
	Preview._instances = {}
end

local function GetTiming()
	local live = Preview._live
	local db = FloatingTextDB() or {}
	local timeVisible = tonumber(live.errorTimeVisible)
	if timeVisible == nil then timeVisible = tonumber(db.errorTimeVisible) or 1 end
	local fadeDuration = tonumber(live.errorFadeDuration)
	if fadeDuration == nil then fadeDuration = tonumber(db.errorFadeDuration) or 1.5 end
	local throttle = tonumber(live.errorThrottleWindow)
	if throttle == nil then throttle = tonumber(db.errorThrottleWindow) or 0.5 end
	return max(0, timeVisible), max(0, fadeDuration), max(0, throttle)
end

function Preview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(72)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	local fs = stage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetJustifyH("CENTER")
	fs:SetPoint("CENTER", stage, "CENTER", 0, 0)
	fs:SetTextColor(1.0, 0.1, 0.1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	host._fs = fs

	local function ShowMessage(index)
		host._index = index
		fs:SetText(SAMPLE_ERRORS[index] or SAMPLE_ERRORS[1])
		fs:SetAlpha(1)
		host._phase = PHASE_HOLD
		host._phaseStart = GetTime()
	end

	local function NextMessage()
		local nextIndex = (host._index or 1) + 1
		if nextIndex > #SAMPLE_ERRORS then
			nextIndex = 1
		end
		ShowMessage(nextIndex)
	end

	local function RestartCycle()
		ShowMessage(host._index or 1)
	end

	host.Refresh = function(self)
		-- Keep current message; restart timing from hold so slider changes are visible immediately.
		local idx = self._index or 1
		ShowMessage(idx)
	end
	host.LayoutLive = host.Refresh
	host.RefreshStyle = host.Refresh

	host:SetScript("OnShow", function(self)
		RestartCycle()
	end)

	local function ErrorAnimTick(self)
		local timeVisible, fadeDuration, throttle = GetTiming()
		local now = GetTime()
		local elapsed = now - (self._phaseStart or now)
		local phase = self._phase or PHASE_HOLD

		if phase == PHASE_HOLD then
			fs:SetAlpha(1)
			if elapsed >= timeVisible then
				self._phase = PHASE_FADE
				self._phaseStart = now
				if fadeDuration <= 0 then
					fs:SetAlpha(0)
					self._phase = PHASE_GAP
					self._phaseStart = now
				end
			end
		elseif phase == PHASE_FADE then
			if fadeDuration <= 0 then
				fs:SetAlpha(0)
				self._phase = PHASE_GAP
				self._phaseStart = now
			else
				local a = 1 - min(1, elapsed / fadeDuration)
				fs:SetAlpha(max(0, a))
				if elapsed >= fadeDuration then
					fs:SetAlpha(0)
					self._phase = PHASE_GAP
					self._phaseStart = now
				end
			end
		elseif phase == PHASE_GAP then
			fs:SetAlpha(0)
			-- Antispam window = pause before the next error can appear.
			if elapsed >= throttle then
				NextMessage()
			end
		end
	end
	if SarychUI and SarychUI.BindOptionsPreviewAnim then
		SarychUI.BindOptionsPreviewAnim(host, ErrorAnimTick)
	else
		host:SetScript("OnUpdate", ErrorAnimTick)
	end

	ShowMessage(1)
	TrackInstance(host)
	return host
end

--------------------------------------------------------------------
-- System messages / boss emote position previews
--------------------------------------------------------------------
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

local function LiveOrDb(live, db, key, fallback)
	local v = tonumber(live and live[key])
	if v ~= nil then return v end
	v = tonumber(db and db[key])
	if v ~= nil then return v end
	return fallback
end

-- Map game offset (-1000..1000) into preview stage pixels.
local function OffsetToPreviewY(offsetY, maxPx)
	maxPx = maxPx or 36
	local y = (tonumber(offsetY) or 0) * 0.08
	if y > maxPx then return maxPx end
	if y < -maxPx then return -maxPx end
	return y
end

--------------------------------------------------------------------
SarychUI.SysMsgPreview = MakeBucket("SysMsgPreview")
local SysPreview = SarychUI.SysMsgPreview

local SYS_SAMPLE_LINES = {
	"Задание выполнено: Убить 10 волков",
	"Убить волков: 1/10",
}

function SysPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(72)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	local lines = {}
	for i, text in ipairs(SYS_SAMPLE_LINES) do
		local fs = stage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetJustifyH("CENTER")
		fs:SetText(text)
		fs:SetTextColor(1.0, 1.0, 0.0)
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
		lines[i] = fs
	end
	host._lines = lines

	local function Layout()
		local db = FloatingTextDB() or {}
		local offsetY = LiveOrDb(SysPreview._live, db, "errorSysMsgOffsetY", 0)
		local y = OffsetToPreviewY(offsetY, 22)
		lines[1]:ClearAllPoints()
		lines[1]:SetPoint("CENTER", stage, "CENTER", 0, y + 8)
		lines[2]:ClearAllPoints()
		lines[2]:SetPoint("TOP", lines[1], "BOTTOM", 0, -2)
	end

	host.Refresh = Layout
	host.LayoutLive = Layout
	host:SetScript("OnShow", Layout)
	host:SetScript("OnSizeChanged", Layout)
	Layout()
	tinsert(self._instances, host)
	return host
end

--------------------------------------------------------------------
SarychUI.BossEmotePreview = MakeBucket("BossEmotePreview")
local BossPreview = SarychUI.BossEmotePreview

function BossPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(72)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	local fs = stage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetJustifyH("CENTER")
	fs:SetText("Ануб'арак кричит: Ваша смерть неизбежна!")
	fs:SetTextColor(1.0, 0.82, 0.0)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	host._fs = fs

	local function Layout()
		local db = FloatingTextDB() or {}
		local enabled = LiveOrDb(BossPreview._live, db, "enableRaidBossEmoteReposition", db.enableRaidBossEmoteReposition or 0)
		local offsetY = LiveOrDb(BossPreview._live, db, "raidBossEmoteOffsetY", -600)
		local maxWidth = LiveOrDb(BossPreview._live, db, "raidBossEmoteMaxWidth", 600)

		local y = OffsetToPreviewY(offsetY + 430, 22)
		local stageW = stage:GetWidth() or 280
		if stageW < 40 then stageW = 280 end
		local t = (maxWidth - 200) / 1000
		if t < 0 then t = 0 elseif t > 1 then t = 1 end
		local textW = stageW * (0.40 + 0.55 * t)
		if textW < 80 then textW = 80 end

		fs:ClearAllPoints()
		fs:SetWidth(textW)
		fs:SetPoint("CENTER", stage, "CENTER", 0, y)
		fs:SetAlpha((enabled == 1 or enabled == true) and 1 or 0.45)
	end

	host.Refresh = Layout
	host.LayoutLive = Layout
	host:SetScript("OnShow", Layout)
	host:SetScript("OnSizeChanged", Layout)
	Layout()
	tinsert(self._instances, host)
	return host
end

--------------------------------------------------------------------
-- Frame hit-indicator preview — Blizzard PlayerFrame / PetFrame layout
-- Sizes, textures and anchors match FrameXML PlayerFrame.xml / PetFrame.xml
--------------------------------------------------------------------
SarychUI.FrameHitPreview = MakeBucket("FrameHitPreview")
local HitPreview = SarychUI.FrameHitPreview

local PLAYER_PORTRAITS = {
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Human",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-Human",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-Orc",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-NightElf",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-NightElf",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Tauren",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-BloodElf",
}

local PET_PORTRAITS = {
	"Interface\\Icons\\Ability_Hunter_Pet_Wolf",
	"Interface\\Icons\\Ability_Hunter_Pet_Bear",
	"Interface\\Icons\\Ability_Hunter_Pet_Cat",
	"Interface\\Icons\\Ability_Hunter_Pet_Raptor",
	"Interface\\Icons\\Ability_Hunter_Pet_Crab",
	"Interface\\Icons\\Spell_Nature_SpiritWolf",
}

local HIT_SAMPLES = {
	{ text = "-482", r = 1.0, g = 0.1, b = 0.1 },
	{ text = "+1256", r = 0.1, g = 1.0, b = 0.1 },
	{ text = "CRIT!", r = 1.0, g = 0.82, b = 0.0 },
	{ text = "-891", r = 1.0, g = 0.1, b = 0.1 },
	{ text = "+340", r = 0.1, g = 1.0, b = 0.1 },
}

local function FrameDb()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods.frame
end

local function LiveFlag(key, fallback)
	local live = HitPreview._live
	if live[key] ~= nil then
		local v = live[key]
		return v == 1 or v == true
	end
	local db = FrameDb() or {}
	local v = db[key]
	if v == nil then return fallback and true or false end
	return v == 1 or v == true
end

local function Pick(list)
	return list[random(1, #list)]
end

-- PlayerFrame.xml: Size 232x100
local function MakePlayerPreview(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(232, 100)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(119, 41)
	bg:SetPoint("TOPLEFT", 106, -22)
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	local portrait = f:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(64, 64)
	portrait:SetPoint("TOPLEFT", 42, -12)
	f.portrait = portrait

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetSize(100, 12)
	nameFs:SetPoint("CENTER", 50, 19)
	nameFs:SetText("Игрок")

	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(119, 12)
	health:SetPoint("TOPLEFT", 106, -41)
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.72)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local mana = CreateFrame("StatusBar", nil, f)
	mana:SetSize(119, 12)
	mana:SetPoint("TOPLEFT", 106, -52)
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(0.55)
	mana:SetStatusBarColor(0, 0, 1)
	mana:SetFrameLevel(f:GetFrameLevel() + 1)

	-- Border chrome above portrait/bars (same as Blizzard nested frame order).
	local borderFrame = CreateFrame("Frame", nil, f)
	borderFrame:SetAllPoints()
	borderFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints()
	border:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
	border:SetTexCoord(1.0, 0.09375, 0, 0.78125)

	-- PlayerHitIndicator: CENTER TOPLEFT 73,-42 ; NumberFontNormalHuge
	local hitFrame = CreateFrame("Frame", nil, f)
	hitFrame:SetAllPoints()
	hitFrame:SetFrameLevel(f:GetFrameLevel() + 4)
	local hit = hitFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
	hit:SetPoint("CENTER", f, "TOPLEFT", 73, -42)
	hit:SetAlpha(0)
	f.hit = hit

	return f
end

-- PetFrame.xml: Size 128x53, anchored TOPLEFT of PlayerFrame at 80,-60
local function MakePetPreview(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(128, 53)

	local portrait = f:CreateTexture(nil, "BACKGROUND")
	portrait:SetSize(37, 37)
	portrait:SetPoint("TOPLEFT", 7, -6)
	f.portrait = portrait

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetPoint("BOTTOMLEFT", 52, 33)
	nameFs:SetText("Питомец")

	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(69, 8)
	health:SetPoint("TOPLEFT", 47, -22)
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.8)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local mana = CreateFrame("StatusBar", nil, f)
	mana:SetSize(69, 8)
	mana:SetPoint("TOPLEFT", 47, -29)
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(0.4)
	mana:SetStatusBarColor(0, 0, 1)
	mana:SetFrameLevel(f:GetFrameLevel() + 1)

	local borderFrame = CreateFrame("Frame", nil, f)
	borderFrame:SetAllPoints()
	borderFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetSize(128, 64)
	border:SetPoint("TOPLEFT", 0, -2)
	border:SetTexture("Interface\\TargetingFrame\\UI-SmallTargetingFrame")

	-- PetHitIndicator: CENTER TOPLEFT 28,-27 ; NumberFontNormalHuge
	local hitFrame = CreateFrame("Frame", nil, f)
	hitFrame:SetAllPoints()
	hitFrame:SetFrameLevel(f:GetFrameLevel() + 4)
	local hit = hitFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
	hit:SetPoint("CENTER", f, "TOPLEFT", 28, -27)
	hit:SetAlpha(0)
	f.hit = hit

	return f
end

function HitPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	-- Player 100 + pet offset 60 + pet 53 ≈ 160; pad for panel
	host:SetHeight(168)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	local player = MakePlayerPreview(stage)
	player:SetPoint("TOPLEFT", stage, "TOPLEFT", 4, -2)

	local pet = MakePetPreview(stage)
	-- Same relative anchor as PetFrame → PlayerFrame: TOPLEFT 80,-60
	pet:SetPoint("TOPLEFT", player, "TOPLEFT", 80, -60)

	host._player = player
	host._pet = pet
	host._playerSample = 1
	host._petSample = 2
	host._playerPhase = "gap"
	host._petPhase = "gap"
	host._playerT = 0
	host._petT = 0.6

	local function ApplyHitText(fs, sample)
		fs:SetText(sample.text)
		fs:SetTextColor(sample.r, sample.g, sample.b)
	end

	local function Layout()
		local hidePlayer = LiveFlag("hidePlayerHitIndicator", true)
		local hidePet = LiveFlag("hidePetHitIndicator", true)
		host._hidePlayer = hidePlayer
		host._hidePet = hidePet
		if hidePlayer then
			player.hit:SetAlpha(0)
		end
		if hidePet then
			pet.hit:SetAlpha(0)
		end
	end

	local function Pulse(which, elapsed)
		local hide = which == "player" and host._hidePlayer or host._hidePet
		local fs = which == "player" and player.hit or pet.hit
		local phaseKey = which == "player" and "_playerPhase" or "_petPhase"
		local tKey = which == "player" and "_playerT" or "_petT"
		local sampleKey = which == "player" and "_playerSample" or "_petSample"

		if hide then
			fs:SetAlpha(0)
			host[phaseKey] = "gap"
			host[tKey] = 0
			return
		end

		host[tKey] = (host[tKey] or 0) + elapsed
		local phase = host[phaseKey] or "gap"
		local t = host[tKey]

		if phase == "gap" then
			fs:SetAlpha(0)
			if t >= 0.55 then
				local idx = (host[sampleKey] or 1) + 1
				if idx > #HIT_SAMPLES then idx = 1 end
				host[sampleKey] = idx
				ApplyHitText(fs, HIT_SAMPLES[idx])
				host[phaseKey] = "show"
				host[tKey] = 0
				fs:SetAlpha(1)
			end
		elseif phase == "show" then
			fs:SetAlpha(1)
			if t >= 0.85 then
				host[phaseKey] = "fade"
				host[tKey] = 0
			end
		elseif phase == "fade" then
			local a = 1 - min(1, t / 0.45)
			fs:SetAlpha(max(0, a))
			if t >= 0.45 then
				fs:SetAlpha(0)
				host[phaseKey] = "gap"
				host[tKey] = 0
			end
		end
	end

	host.Refresh = Layout
	host.LayoutLive = Layout
	host:SetScript("OnShow", function()
		player.portrait:SetTexture(Pick(PLAYER_PORTRAITS))
		pet.portrait:SetTexture(Pick(PET_PORTRAITS))
		Layout()
	end)
	if SarychUI and SarychUI.BindOptionsPreviewAnim then
		SarychUI.BindOptionsPreviewAnim(host, function(_, elapsed)
			Pulse("player", elapsed)
			Pulse("pet", elapsed)
		end)
	else
		host:SetScript("OnUpdate", function(_, elapsed)
			Pulse("player", elapsed)
			Pulse("pet", elapsed)
		end)
	end

	player.portrait:SetTexture(Pick(PLAYER_PORTRAITS))
	pet.portrait:SetTexture(Pick(PET_PORTRAITS))
	Layout()
	tinsert(self._instances, host)
	return host
end

--------------------------------------------------------------------
-- Incoming combat text preview (+ heal / - damage / < procs)
--------------------------------------------------------------------
SarychUI.CombatTextPreview = MakeBucket("CombatTextPreview")
local CombatPreview = SarychUI.CombatTextPreview

local function CombatDb()
	return FloatingTextDB() or {}
end

local function CombatLive(key, fallback)
	local live = CombatPreview._live
	if live[key] ~= nil then
		return live[key]
	end
	local db = CombatDb()
	local v = db[key]
	if v == nil then return fallback end
	return v
end

local function CombatFlag(key, fallback)
	local v = CombatLive(key, fallback)
	return v == 1 or v == true
end

-- Map game offsets into preview pixels relative to a scaled-down screen.
-- Same scale for X/Y (based on width) so -200/-70 keep real proportions.
local function CombatOffsetPx(stage, x, y)
	local sw = (stage and stage.GetWidth and stage:GetWidth()) or 0
	local sh = (stage and stage.GetHeight and stage:GetHeight()) or 0
	if sw < 40 then sw = 560 end
	if sh < 40 then sh = 200 end
	local screenW = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
	if screenW < 100 then screenW = 1920 end
	local scale = sw / screenW
	local sx = (tonumber(x) or 0) * scale
	local sy = (tonumber(y) or 0) * scale
	local maxX = sw * 0.48
	local maxY = sh * 0.48
	if sx > maxX then sx = maxX elseif sx < -maxX then sx = -maxX end
	if sy > maxY then sy = maxY elseif sy < -maxY then sy = -maxY end
	return sx, sy
end

function CombatPreview:Create(parent)
	self:ClearStickyHosts()

	local host = CreateFrame("Frame", nil, parent)
	host:SetHeight(220)
	host.spacer = host
	ApplyPanelBg(host)

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 8, -8)
	stage:SetPoint("BOTTOMRIGHT", -8, 8)

	-- Faint screen bounds so offsets read relative to the real UI.
	local screen = stage:CreateTexture(nil, "BACKGROUND")
	screen:SetPoint("TOPLEFT", stage, "TOPLEFT", 2, -2)
	screen:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -2, 2)
	screen:SetTexture("Interface\\Buttons\\WHITE8X8")
	screen:SetVertexColor(0.12, 0.12, 0.14, 0.55)

	local crossH = stage:CreateTexture(nil, "ARTWORK")
	crossH:SetHeight(1)
	crossH:SetPoint("LEFT", stage, "LEFT", 4, 0)
	crossH:SetPoint("RIGHT", stage, "RIGHT", -4, 0)
	crossH:SetTexture("Interface\\Buttons\\WHITE8X8")
	crossH:SetVertexColor(0.35, 0.35, 0.40, 0.35)

	local crossV = stage:CreateTexture(nil, "ARTWORK")
	crossV:SetWidth(1)
	crossV:SetPoint("TOP", stage, "TOP", 0, -4)
	crossV:SetPoint("BOTTOM", stage, "BOTTOM", 0, 4)
	crossV:SetTexture("Interface\\Buttons\\WHITE8X8")
	crossV:SetVertexColor(0.35, 0.35, 0.40, 0.35)

	-- Soft center mark (default combat-text origin).
	local origin = stage:CreateTexture(nil, "ARTWORK")
	origin:SetSize(6, 6)
	origin:SetPoint("CENTER", stage, "CENTER", 0, 0)
	origin:SetTexture("Interface\\Buttons\\WHITE8X8")
	origin:SetVertexColor(0.55, 0.55, 0.60, 0.7)

	local function MakeLine(r, g, b)
		local fs = stage:CreateFontString(nil, "OVERLAY")
		local font = (CombatTextFont and CombatTextFont.GetFont and CombatTextFont:GetFont())
			or (GameFontNormalLarge and GameFontNormalLarge.GetFont and GameFontNormalLarge:GetFont())
		if font then
			fs:SetFont(font, 18, "OUTLINE")
		else
			fs:SetFontObject(GameFontNormalLarge)
		end
		fs:SetJustifyH("CENTER")
		fs:SetTextColor(r, g, b)
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
		fs:SetAlpha(0)
		return fs
	end

	-- Blizzard floating combat text colors (approx).
	local plusFs = MakeLine(0.1, 1.0, 0.1)
	local minusFs = MakeLine(1.0, 0.1, 0.1)
	local lessFs = MakeLine(1.0, 0.82, 0.0)

	host._plus = plusFs
	host._minus = minusFs
	host._less = lessFs
	host._t = 0
	host._bob = 0

	local SAMPLES = {
		plus = { "+1256", "+482", "+2100" },
		minus = { "-891", "-340", "-1520" },
		less = { "<Проц>", "<Возмездие>", "<Блок>" },
	}
	host._si = { plus = 1, minus = 1, less = 1 }

	local function Place(fs, ox, oy, bob)
		fs:ClearAllPoints()
		fs:SetPoint("CENTER", stage, "CENTER", ox, oy + bob)
	end

	local function Layout()
		local master = CombatFlag("enableHealCombatTextAdjust", true)
		local shiftPlus = master and CombatFlag("healShiftPlus", true)
		local shiftMinus = master and CombatFlag("healShiftMinus", true)
		local hideLess = master and CombatFlag("healHideLess", true)
		local shiftLess = master and CombatFlag("healShiftLess", true) and not hideLess

		local plusX, plusY = 0, 0
		local minusX, minusY = 0, 0
		local lessX, lessY = 0, 0
		if shiftPlus then
			plusX, plusY = CombatOffsetPx(stage, CombatLive("healPlusX", -467), CombatLive("healPlusY", -45))
		end
		if shiftMinus then
			minusX, minusY = CombatOffsetPx(stage, CombatLive("healMinusX", 0), CombatLive("healMinusY", -50))
		end
		if shiftLess then
			lessX, lessY = CombatOffsetPx(stage, CombatLive("healLessX", -250), CombatLive("healLessY", -30))
		end

		host._plusPos = { plusX, plusY }
		host._minusPos = { minusX, minusY }
		host._lessPos = { lessX, lessY }
		host._showPlus = true
		host._showMinus = true
		host._showLess = not hideLess

		Place(plusFs, plusX, plusY, 0)
		Place(minusFs, minusX, minusY, 0)
		Place(lessFs, lessX, lessY, 0)

		plusFs:SetAlpha(host._showPlus and 1 or 0)
		minusFs:SetAlpha(host._showMinus and 1 or 0)
		lessFs:SetAlpha(host._showLess and 1 or 0)
	end

	host.Refresh = Layout
	host.LayoutLive = Layout
	host:SetScript("OnShow", Layout)
	host:SetScript("OnSizeChanged", Layout)
	if SarychUI and SarychUI.BindOptionsPreviewAnim then
		SarychUI.BindOptionsPreviewAnim(host, function(self, elapsed)
			self._t = (self._t or 0) + elapsed
			self._bob = (self._bob or 0) + elapsed

			if self._t >= 1.4 then
				self._t = 0
				for kind, list in pairs(SAMPLES) do
					local i = (self._si[kind] or 1) + 1
					if i > #list then i = 1 end
					self._si[kind] = i
				end
				plusFs:SetText(SAMPLES.plus[self._si.plus])
				minusFs:SetText(SAMPLES.minus[self._si.minus])
				lessFs:SetText(SAMPLES.less[self._si.less])
			end

			local bob = sin((self._bob or 0) * 2.2) * 3
			local pp = self._plusPos or { 0, 14 }
			local mp = self._minusPos or { 0, 0 }
			local lp = self._lessPos or { 0, -14 }
			if self._showPlus then Place(plusFs, pp[1], pp[2], bob) end
			if self._showMinus then Place(minusFs, mp[1], mp[2], bob * 0.85) end
			if self._showLess then Place(lessFs, lp[1], lp[2], bob * 1.1) end
		end)
	else
		host:SetScript("OnUpdate", function(self, elapsed)
			self._t = (self._t or 0) + elapsed
			self._bob = (self._bob or 0) + elapsed
			if self._t >= 1.4 then
				self._t = 0
				for kind, list in pairs(SAMPLES) do
					local i = (self._si[kind] or 1) + 1
					if i > #list then i = 1 end
					self._si[kind] = i
				end
				plusFs:SetText(SAMPLES.plus[self._si.plus])
				minusFs:SetText(SAMPLES.minus[self._si.minus])
				lessFs:SetText(SAMPLES.less[self._si.less])
			end
			local bob = sin((self._bob or 0) * 2.2) * 3
			local pp = self._plusPos or { 0, 14 }
			local mp = self._minusPos or { 0, 0 }
			local lp = self._lessPos or { 0, -14 }
			if self._showPlus then Place(plusFs, pp[1], pp[2], bob) end
			if self._showMinus then Place(minusFs, mp[1], mp[2], bob * 0.85) end
			if self._showLess then Place(lessFs, lp[1], lp[2], bob * 1.1) end
		end)
	end

	plusFs:SetText(SAMPLES.plus[1])
	minusFs:SetText(SAMPLES.minus[1])
	lessFs:SetText(SAMPLES.less[1])
	Layout()
	tinsert(self._instances, host)
	return host
end
