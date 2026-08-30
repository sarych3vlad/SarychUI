-- SarychUI Combat Indicator — sticky options preview (5 frames + combat icons).

local CreateFrame = CreateFrame
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local tonumber = tonumber

SarychUI = SarychUI or {}

-- Compact sticky preview (~half options content height).
-- 2 rows × scaled frames ≈ half the options pane.
local FRAME_SCALE = 0.85
local FRAME_W = 232 * FRAME_SCALE -- ~197
local FRAME_H = 100 * FRAME_SCALE -- ~85
local PREVIEW_H = 200

local KEY_TO_SLOT = {
	combatIndicatorPlayerX = "player",
	combatIndicatorPlayerY = "player",
	combatIndicatorTargetX = "target",
	combatIndicatorTargetY = "target",
	combatIndicatorFocusX = "focus",
	combatIndicatorFocusY = "focus",
	combatIndicatorScale = "all",
	combatIndicatorEliteOffset = "elite",
	combatIndicatorRogueOffset = "combo",
	enableCombatIndicator = "all",
}

local PORTRAITS = {
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Human",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-Human",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-Orc",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-NightElf",
	"Interface\\CharacterFrame\\TemporaryPortrait-Female-BloodElf",
	"Interface\\CharacterFrame\\TemporaryPortrait-Male-Tauren",
}

--------------------------------------------------------------------
SarychUI.CombatIndicatorPreview = SarychUI.CombatIndicatorPreview or {}
local Preview = SarychUI.CombatIndicatorPreview
Preview._instances = Preview._instances or {}
Preview._live = Preview._live or {}
Preview._activeKey = nil

local function FrameDB()
	local mods = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
	return mods and mods.frame or {}
end

local function LiveOr(key, fallback)
	local live = Preview._live
	if live[key] ~= nil then
		return live[key]
	end
	local db = FrameDB()
	local v = db[key]
	if v == nil then return fallback end
	return v
end

local function LiveFlag(key, fallback)
	local v = LiveOr(key, fallback)
	return v == 1 or v == true
end

local function Num(v, fallback)
	v = tonumber(v)
	if v == nil then return fallback end
	return v
end

local function IsActive(slotName)
	local key = Preview._activeKey
	if not key then return false end
	local mapped = KEY_TO_SLOT[key]
	if mapped == "all" then return true end
	return mapped == slotName
end

local function ApplyHighlight(frame, active)
	if not frame or not frame._icon then return end
	if active then
		-- Tint only the combat icon texture (same style as PVP preview).
		frame._icon:SetVertexColor(1, 0.92, 0.35)
		if frame._hlGlow then
			frame._hlGlow:Show()
		end
		frame:SetAlpha(1)
	else
		frame._icon:SetVertexColor(1, 1, 1)
		if frame._hlGlow then
			frame._hlGlow:Hide()
		end
		frame:SetAlpha(Preview._activeKey and 0.5 or 1)
	end
end

function Preview:SetActiveKey(key)
	self._activeKey = key
	-- Highlight only — do not rebuild sticky host.
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, self._live[key])
	else
		self:RefreshAll()
	end
end

function Preview:SetLiveValue(key, value)
	if key == nil then return end
	self._live[key] = value
	self._activeKey = key
	-- Move only icons (LayoutLive), never PinSticky / full RefreshAll.
	if SarychUI and SarychUI.ApplyOptionsPreviewLive then
		SarychUI.ApplyOptionsPreviewLive(self, key, value)
	else
		for _, inst in ipairs(self._instances) do
			if inst and inst.LayoutLive then
				inst:LayoutLive(key)
			elseif inst and inst.RefreshLayout then
				inst:RefreshLayout()
			end
		end
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
	if SarychUI and SarychUI.IsOptionsSliderDragging and SarychUI.IsOptionsSliderDragging() then
		return
	end
	self:RefreshAll()
end

function Preview:RefreshAll()
	local alive = {}
	for _, inst in ipairs(self._instances) do
		if inst and inst.GetParent and inst:GetParent() and inst.spacer and inst.spacer:GetParent() then
			tinsert(alive, inst)
			if inst.Refresh then inst:Refresh() end
		elseif inst then
			if inst.Hide then inst:Hide() end
			if inst.SetParent then inst:SetParent(nil) end
		end
	end
	self._instances = alive
end

function Preview:ClearStickyHosts()
	for _, inst in ipairs(self._instances) do
		if inst then
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

local function S(n)
	return n * FRAME_SCALE
end

-- Portrait as a Frame so SetPoint offsets match the real TargetFramePortrait region.
local function MakePortraitAnchor(parent, size, point, x, y, path)
	local anchor = CreateFrame("Frame", nil, parent)
	anchor:SetSize(size, size)
	anchor:SetPoint(point, parent, point, x, y)
	local tex = anchor:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetTexture(path or PORTRAITS[1])
	anchor.tex = tex
	return anchor
end

-- PlayerFrame-style (portrait LEFT).
local function MakePlayer(parent, label, portraitPath)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(FRAME_W, FRAME_H)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(S(119), S(41))
	bg:SetPoint("TOPLEFT", S(106), -S(22))
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	f.portrait = MakePortraitAnchor(f, S(64), "TOPLEFT", S(42), -S(12), portraitPath or PORTRAITS[1])

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetSize(S(100), S(12))
	nameFs:SetPoint("CENTER", S(50), S(19))
	nameFs:SetText(label or "Игрок")
	nameFs:SetJustifyH("CENTER")
	nameFs:SetTextColor(1.0, 0.82, 0)

	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(S(119), S(12))
	health:SetPoint("TOPLEFT", S(106), -S(41))
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(0.78)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local mana = CreateFrame("StatusBar", nil, f)
	mana:SetSize(S(119), S(12))
	mana:SetPoint("TOPLEFT", S(106), -S(52))
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
	border:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
	border:SetTexCoord(1.0, 0.09375, 0, 0.78125)

	return f
end

-- Blizzard ComboFrame.xml: TOPRIGHT of TargetFrame -44,-9; points chain TOP→BOTTOM.
local function MakeComboPoints(parent)
	local combo = CreateFrame("Frame", nil, parent)
	combo:SetSize(S(40), S(90))
	combo:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -S(44), -S(9))
	combo:SetFrameLevel(parent:GetFrameLevel() + 6)

	local prev
	for i = 1, 5 do
		local cp = CreateFrame("Frame", nil, combo)
		if i == 5 then
			cp:SetSize(S(15), S(18))
		else
			cp:SetSize(S(12), S(12))
		end

		if i == 1 then
			cp:SetPoint("TOPRIGHT", combo, "TOPRIGHT", 0, 0)
		else
			-- Exact Blizzard chain offsets from ComboFrame.xml
			local ox, oy
			if i == 2 then
				ox, oy = S(7), S(4)
			elseif i == 3 then
				ox, oy = S(5), S(2)
			elseif i == 4 then
				ox, oy = S(2), S(1)
			else
				ox, oy = 0, S(1)
			end
			cp:SetPoint("TOP", prev, "BOTTOM", ox, oy)
		end

		local bg = cp:CreateTexture(nil, "BACKGROUND")
		bg:SetSize(S(12), S(16))
		bg:SetPoint("TOPLEFT")
		bg:SetTexture("Interface\\ComboFrame\\ComboPoint")
		bg:SetTexCoord(0, 0.375, 0, 1)

		local highlight = cp:CreateTexture(nil, "ARTWORK")
		highlight:SetSize(S(8), S(16))
		highlight:SetPoint("TOPLEFT", S(2), 0)
		highlight:SetTexture("Interface\\ComboFrame\\ComboPoint")
		highlight:SetTexCoord(0.375, 0.5625, 0, 1)

		-- First 3 filled (active), last 2 empty — like having 3 combo points.
		if i > 3 then
			highlight:SetAlpha(0)
			bg:SetVertexColor(0.45, 0.45, 0.45, 0.85)
		else
			highlight:SetAlpha(1)
		end

		prev = cp
	end
	return combo
end

-- TargetFrame-style (portrait RIGHT). opts: elite, combo
local function MakeTarget(parent, label, portraitPath, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(FRAME_W, FRAME_H)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(S(119), S(41))
	bg:SetPoint("TOPRIGHT", -S(106), -S(22))
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0, 0, 0, 0.5)

	f.portrait = MakePortraitAnchor(f, S(64), "TOPRIGHT", -S(42), -S(12), portraitPath or PORTRAITS[3])

	local nameFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameFs:SetSize(S(100), S(12))
	nameFs:SetPoint("CENTER", -S(50), S(19))
	nameFs:SetText(label or "Цель")
	nameFs:SetJustifyH("CENTER")
	nameFs:SetTextColor(1.0, 0.82, 0)

	local health = CreateFrame("StatusBar", nil, f)
	health:SetSize(S(119), S(12))
	health:SetPoint("TOPRIGHT", -S(106), -S(41))
	health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	health:SetMinMaxValues(0, 1)
	health:SetValue(opts.hp or 0.65)
	health:SetStatusBarColor(0, 1, 0)
	health:SetFrameLevel(f:GetFrameLevel() + 1)

	local mana = CreateFrame("StatusBar", nil, f)
	mana:SetSize(S(119), S(12))
	mana:SetPoint("TOPRIGHT", -S(106), -S(52))
	mana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mana:SetMinMaxValues(0, 1)
	mana:SetValue(opts.mana or 0.4)
	mana:SetStatusBarColor(0, 0, 1)
	mana:SetFrameLevel(f:GetFrameLevel() + 1)

	local borderFrame = CreateFrame("Frame", nil, f)
	borderFrame:SetAllPoints()
	borderFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	local border = borderFrame:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints()
	if opts.elite then
		border:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
	else
		border:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
	end
	border:SetTexCoord(0.09375, 1.0, 0, 0.78125)

	if opts.combo then
		f._combo = MakeComboPoints(f)
	end

	return f
end

local function MakeCombatIcon(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(18, 18)
	frame:SetFrameLevel(parent:GetFrameLevel() + 12)

	local t = frame:CreateTexture(nil, "BORDER")
	t:SetAllPoints()
	t:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	t:SetTexCoord(0.5, 1.0, 0, 0.48)

	local glow = frame:CreateTexture(nil, "OVERLAY")
	glow:SetAllPoints()
	glow:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	glow:SetTexCoord(0.5, 1.0, 0.5, 1.0)
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.65)

	-- Soft ADD glow clipped to the same icon texture (no oversized box).
	local hlGlow = frame:CreateTexture(nil, "OVERLAY")
	hlGlow:SetAllPoints(t)
	hlGlow:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	hlGlow:SetTexCoord(0.5, 1.0, 0, 0.48)
	hlGlow:SetBlendMode("ADD")
	hlGlow:SetVertexColor(1, 0.85, 0.2)
	hlGlow:SetAlpha(0.55)
	hlGlow:Hide()

	frame._icon = t
	frame._glow = glow
	frame._hlGlow = hlGlow

	return frame
end

function Preview:Create(parent)
	self:ClearStickyHosts()
	local OW = SarychUI.OptionsWindow
	local T = SarychUI.OptionsTheme

	local spacer = CreateFrame("Frame", nil, parent)
	spacer:SetHeight(PREVIEW_H + 4)

	local stickyParent = (OW and OW.content) or parent
	local host = CreateFrame("Frame", nil, stickyParent)
	host:SetHeight(PREVIEW_H)
	host.spacer = spacer
	host:SetFrameStrata((stickyParent.GetFrameStrata and stickyParent:GetFrameStrata()) or "DIALOG")
	host:SetFrameLevel((stickyParent:GetFrameLevel() or 1) + 40)

	if T and T.ApplyFlat then
		T:ApplyFlat(host, T.colors.panelBg or { 0.07, 0.07, 0.09, 0.97 }, T.colors.borderSoft)
	else
		local bg = host:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		bg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
	end

	local stage = CreateFrame("Frame", nil, host)
	stage:SetPoint("TOPLEFT", 4, -4)
	stage:SetPoint("BOTTOMRIGHT", -4, 4)

	local gapY = 6

	-- Row 1: Player | Target | Focus  (fits half options pane)
	local player = MakePlayer(stage, "Игрок", PORTRAITS[1])
	player:SetPoint("TOPLEFT", stage, "TOPLEFT", 2, -2)

	local target = MakeTarget(stage, "Цель", PORTRAITS[6], { hp = 0.7, mana = 0.5 })
	target:SetPoint("TOP", stage, "TOP", 0, -2)

	local focus = MakeTarget(stage, "Фокус", PORTRAITS[5], { hp = 0.55, mana = 0.8 })
	focus:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -2, -2)

	-- Row 2: Elite | Combo
	local elite = MakeTarget(stage, "Элита", PORTRAITS[7], { elite = true, hp = 0.9, mana = 0.3 })
	elite:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -gapY)

	local combo = MakeTarget(stage, "Комбо", PORTRAITS[3], { combo = true, hp = 0.4, mana = 0.2 })
	combo:SetPoint("TOPRIGHT", focus, "BOTTOMRIGHT", 0, -gapY)

	local iconPlayer = MakeCombatIcon(player)
	local iconTarget = MakeCombatIcon(target)
	local iconFocus = MakeCombatIcon(focus)
	local iconElite = MakeCombatIcon(elite)
	local iconCombo = MakeCombatIcon(combo)

	host._player = player
	host._target = target
	host._focus = focus
	host._elite = elite
	host._combo = combo
	host._icons = {
		player = iconPlayer,
		target = iconTarget,
		focus = iconFocus,
		elite = iconElite,
		combo = iconCombo,
	}

	-- Scale full-size module offsets into preview frame scale.
	local function SX(v) return v * FRAME_SCALE end

	local function PlaceIcon(icon, anchor, relativePoint, x, y, size, slot)
		local s = size or 18
		icon:SetSize(s, s)
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", anchor, relativePoint or "CENTER", x, y)
		-- Only combat icons highlight on hover — never the unit frames.
		ApplyHighlight(icon, IsActive(slot) or IsActive("all"))
	end

	local function Layout()
		local enabled = LiveFlag("enableCombatIndicator", true)
		local scale = Num(LiveOr("combatIndicatorScale", 0.85), 0.85)
		-- Module: 32 * combatIndicatorScale; preview also shrinks with FRAME_SCALE.
		local size = (32 * scale) * FRAME_SCALE

		local pX = Num(LiveOr("combatIndicatorPlayerX", 33), 33)
		local pY = Num(LiveOr("combatIndicatorPlayerY", 38), 38)
		local tX = Num(LiveOr("combatIndicatorTargetX", 57), 57)
		local tY = Num(LiveOr("combatIndicatorTargetY", 0), 0)
		local fX = Num(LiveOr("combatIndicatorFocusX", 57), 57)
		local fY = Num(LiveOr("combatIndicatorFocusY", 0), 0)
		local eliteOff = Num(LiveOr("combatIndicatorEliteOffset", 30), 30)
		local rogueOff = Num(LiveOr("combatIndicatorRogueOffset", 10), 10)

		-- Exact module anchors (scaled):
		--   player: CENTER ← PlayerFrame LEFT (posX-24, posY)
		--   target/focus: CENTER ← *Portrait* CENTER (posX, posY)
		--   elite: same as target + eliteOffset
		--   combo/rogue: same as target + rogueOffset (normal mob)
		PlaceIcon(iconPlayer, player, "LEFT", SX(pX - 24), SX(pY), size, "player")
		PlaceIcon(iconTarget, target.portrait, "CENTER", SX(tX), SX(tY), size, "target")
		PlaceIcon(iconFocus, focus.portrait, "CENTER", SX(fX), SX(fY), size, "focus")
		PlaceIcon(iconElite, elite.portrait, "CENTER", SX(tX + eliteOff), SX(tY), size, "elite")
		PlaceIcon(iconCombo, combo.portrait, "CENTER", SX(tX + rogueOff), SX(tY), size, "combo")

		local show = enabled and true or false
		for _, icon in pairs(host._icons) do
			if show then icon:Show() else icon:Hide() end
		end

		-- Keep unit frames fully visible; only icons dim when another slot is active.
		player:SetAlpha(1)
		target:SetAlpha(1)
		focus:SetAlpha(1)
		elite:SetAlpha(1)
		combo:SetAlpha(1)
	end

	local function PinOnly()
		if not spacer:GetParent() or not spacer:IsShown() then
			host:Hide()
			return
		end
		host:Show()
		local scroll = OW and OW.contentScroll
		if scroll and stickyParent == (OW and OW.content) then
			host:SetParent(stickyParent)
			host:ClearAllPoints()
			host:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
			host:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
			host:SetHeight(PREVIEW_H)
			host:SetFrameLevel((stickyParent:GetFrameLevel() or 1) + 40)
		else
			host:SetParent(parent)
			host:ClearAllPoints()
			host:SetPoint("TOPLEFT", spacer, "TOPLEFT", 0, 0)
			host:SetPoint("TOPRIGHT", spacer, "TOPRIGHT", 0, 0)
		end
	end

	local function PinSticky()
		PinOnly()
		if host:IsShown() then
			Layout()
		end
	end

	host.LayoutLive = function()
		Layout()
	end
	host.RefreshLayout = Layout
	host.Refresh = function()
		PinSticky()
	end
	host.PinOnly = PinOnly

	spacer:SetScript("OnShow", function() PinSticky() end)
	spacer:SetScript("OnHide", function() host:Hide() end)

	local scroll = OW and OW.contentScroll
	if scroll and not scroll._suiCombatIndPinHooked then
		scroll._suiCombatIndPinHooked = true
		scroll:HookScript("OnVerticalScroll", function()
			for _, inst in ipairs(Preview._instances) do
				if inst and inst.PinOnly then inst:PinOnly() end
			end
		end)
		scroll:HookScript("OnSizeChanged", function()
			for _, inst in ipairs(Preview._instances) do
				if inst and inst.PinOnly then inst:PinOnly() end
			end
		end)
	end

	PinSticky()
	tinsert(self._instances, host)
	return spacer
end
