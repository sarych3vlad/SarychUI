-- Shaman totem icons with cooldown swipe / pulse bars (FrostAtomUI Totems).

local moduleName = "player_resources"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

if module.PLAYER_CLASS ~= "SHAMAN" then
	function module:RefreshTotems() end
	function module:DisableTotems() end
	return
end

local MAX_TOTEMS = MAX_TOTEMS or 4
local SLOT_ORDER = TOTEM_PRIORITIES or { 2, 1, 3, 4 }
local SUMMON_TOLERANCE = 2
local PULSE_INSET = 3
-- Exact FrostAtomUI pulse look (Modules/Totems.lua + Core/Media.lua + Core/Config.lua):
--   bar texture : Media.statusbar = Interface\Buttons\WHITE8x8, colored by totems.pulseColor
--   frame       : ns.CreateBackdrop(8, 2) = bg WHITE8x8 + edge UI-Tooltip-Border (8px, inset 2)
--   frame colors: unitFrames.backdropColor {0,0,0,0.6}, unitFrames.borderColor {1,1,1}
local BAR_TEX = [[Interface\Buttons\WHITE8x8]]
local PULSE_BACKDROP = {
	bgFile = BAR_TEX,
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
local PULSE_BACKDROP_COLOR = { 0, 0, 0, 0.6 }
local PULSE_BORDER_COLOR = { 1, 1, 1 }

-- Tools → «Затемнение текстур интерфейса (LortiUI)»: tint icon borders and
-- pulse frame borders with the LortiUI color, like unit frames / class rings.
local function LortiColor()
	local L = SarychUI_LortiUI
	if L and L.IsSettingOn and L.IsSettingOn() and L.GetColor then
		local r, g, b, a = L.GetColor()
		return r, g, b, a or 1
	end
	return nil
end

local holder, buttons, pulses, playerGUID, ticker

local function ApplyVisibility(shown, alpha)
	if not holder then
		return
	end
	if not module:Flag("totems", "enabled", false) then
		holder:Hide()
		return
	end
	if module:Flag("totems", "showDragFrame", false) then
		holder:SetAlpha(1)
		holder:Show()
		return
	end
	if shown then
		holder:Show()
		holder:SetAlpha(alpha or 1)
	else
		holder:SetAlpha(1)
		holder:Hide()
	end
end

function module:SyncTotemsToPlateVisibility(shown, alpha)
	ApplyVisibility(shown, alpha)
end

-- ClassicAPI CombatLogGetCurrentEventInfo inserts hideCaster; raw CLEU does not.
local function ParseCLEU(...)
	if CombatLogGetCurrentEventInfo then
		local _, sub, _, srcGUID, _, _, _, dstGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo(...)
		return sub, srcGUID, dstGUID, spellId
	end
	local _, sub, a, b, c, d, e, f, g = ...
	-- WotLK: timestamp, sub, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId
	-- Cata-like: timestamp, sub, hideCaster, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId
	if type(a) == "boolean" or a == "1" or a == "0" then
		return sub, b, e, select(10, ...)
	end
	return sub, a, d, g
end

local function TotemData()
	return module.TotemData
end

local function PulseDataForSpell(spellId)
	local td = TotemData()
	local data = td and td.spells and td.spells[spellId]
	return data
end

local function PulseDataForName(name)
	if not name or name == "" then
		return nil
	end
	local td = TotemData()
	if not td or not td.byName then
		return nil
	end
	local spellId = td.byName[name]
	return spellId and td.spells[spellId]
end

local function EnsurePulseRecord(slot, startTime, spellId, totemName)
	local record = pulses[slot]
	if record and record.pulse then
		return record
	end
	local data = (spellId and PulseDataForSpell(spellId)) or PulseDataForName(totemName)
	if not data or not data.pulse then
		return nil
	end
	local now = startTime and startTime > 0 and startTime or GetTime()
	record = { guid = record and record.guid, pulse = data.pulse, start = now, lastTick = now }
	pulses[slot] = record
	return record
end

local function UpdatePulse(button, active, startTime, totemName)
	local slot = button:GetID()
	local record = pulses[slot]
	if active and module:Flag("totems", "pulse", true) then
		if not record or not record.pulse then
			record = EnsurePulseRecord(slot, startTime, nil, totemName)
		elseif startTime and startTime > 0 and record.start and math.abs(startTime - record.start) > SUMMON_TOLERANCE then
			-- Stale record from a previous totem in the same slot.
			pulses[slot] = nil
			record = EnsurePulseRecord(slot, startTime, nil, totemName)
		end
	end
	local show = module:Flag("totems", "pulse", true) and active and record and record.pulse
	if show then
		button.pulse:Show()
		if ticker then
			ticker:Show()
		end
	else
		button.pulse:Hide()
	end
end

local function UpdateButton(button)
	local haveTotem, totemName, startTime, duration, icon = GetTotemInfo(button:GetID())
	local active = haveTotem and duration and duration > 0
	if active then
		button.icon:SetTexture(icon)
		button.cooldown:SetCooldown(startTime, duration)
		button:SetAlpha(1)
	else
		button.cooldown:SetCooldown(0, 0)
		button:SetAlpha(0)
		-- Keep pulses[slot] until UNIT_DIED / new summon — SPELL_SUMMON often
		-- arrives before GetTotemInfo reports the totem as active.
	end
	button:EnableMouse(active and not module:Flag("totems", "clickThrough", false))
	UpdatePulse(button, active, startTime or 0, totemName)
end

local function OnSummon(dstGUID, spellId)
	local data = PulseDataForSpell(spellId)
	if not data then
		return
	end
	local slot = data.slot
	if data.pulse then
		local now = GetTime()
		pulses[slot] = { guid = dstGUID, pulse = data.pulse, start = now, lastTick = now }
	else
		pulses[slot] = nil
	end
	if buttons[slot] then
		UpdateButton(buttons[slot])
	end
end

local function OnTick(srcGUID, spellId)
	local td = TotemData()
	if not td or not td.tickSpells[spellId] then
		return
	end
	for _, record in pairs(pulses) do
		if record.pulse and record.pulse.ticks[spellId] then
			if srcGUID == record.guid or srcGUID == playerGUID then
				record.lastTick = GetTime()
			end
		end
	end
end

local function OnDestroyed(dstGUID)
	for slot, record in pairs(pulses) do
		if record.guid == dstGUID then
			pulses[slot] = nil
			if buttons[slot] then
				buttons[slot].pulse:Hide()
			end
		end
	end
end

local function CreateButton(slot)
	local button = CreateFrame("Button", nil, holder)
	button:SetID(slot)
	button:SetAlpha(0)
	button:RegisterForClicks("RightButtonUp")
	button:SetScript("OnClick", function(self)
		DestroyTotem(self:GetID())
	end)
	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetAllPoints()
	button.border = button:CreateTexture(nil, "ARTWORK")
	button.border:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	button.border:SetPoint("TOPLEFT", -8, 8)
	button.border:SetPoint("BOTTOMRIGHT", 8, -8)
	button.cooldown = CreateFrame("Cooldown", nil, button)
	button.cooldown:SetAllPoints()
	button.cooldown:SetReverse(true)
	button.cooldown:SetDrawEdge(true)
	-- Parent pulse to holder so button alpha does not hide it.
	local pulse = CreateFrame("Frame", nil, holder)
	pulse:SetBackdrop(PULSE_BACKDROP)
	pulse:Hide()
	local pulseBar = CreateFrame("StatusBar", nil, pulse)
	pulseBar:SetPoint("TOPLEFT", PULSE_INSET, -PULSE_INSET)
	pulseBar:SetPoint("BOTTOMRIGHT", -PULSE_INSET, PULSE_INSET)
	pulseBar:SetMinMaxValues(0, 1)
	-- FrostAtomUI ns.SkinStatusBar → Media.statusbar
	pulseBar:SetStatusBarTexture(BAR_TEX)
	pulse.bar = pulseBar
	button.pulse = pulse
	buttons[slot] = button
end

local function Ensure()
	if holder then return end
	holder = CreateFrame("Frame", "SarychUITotems", UIParent)
	buttons, pulses = {}, {}
	for slot = 1, MAX_TOTEMS do
		CreateButton(slot)
	end
	ticker = CreateFrame("Frame")
	ticker:Hide()
	ticker:SetScript("OnUpdate", function(self)
		local now = GetTime()
		local any
		for slot, record in pairs(pulses) do
			local bar = buttons[slot] and buttons[slot].pulse
			if bar and bar:IsShown() and record.pulse then
				local period = record.pulse.period
				if period and period > 0 then
					-- Same formula as FrostAtomUI Modules/Totems.lua
					bar.bar:SetValue((now - record.lastTick) % period / period)
					any = true
				end
			end
		end
		if not any then
			self:Hide()
		end
	end)
	module:RegisterDrag("playerTotems", holder, "totems", "Тотемы")
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_TOTEM_UPDATE")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	ev:SetScript("OnEvent", function(_, event, ...)
		if event == "PLAYER_TOTEM_UPDATE" then
			local slot = ...
			if buttons[slot] then
				UpdateButton(buttons[slot])
			end
		elseif event == "PLAYER_ENTERING_WORLD" then
			wipe(pulses)
			for i = 1, MAX_TOTEMS do
				if buttons[i] then UpdateButton(buttons[i]) end
			end
		else
			local sub, srcGUID, dstGUID, spellId = ParseCLEU(...)
			playerGUID = playerGUID or UnitGUID("player")
			local td = TotemData()
			if not sub or not td then
				return
			end
			if td.TICK_EVENTS[sub] then
				OnTick(srcGUID, spellId)
			elseif sub == "SPELL_SUMMON" then
				if srcGUID == playerGUID then
					OnSummon(dstGUID, spellId)
				end
			elseif sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" then
				OnDestroyed(dstGUID)
			end
		end
	end)
	module._totemEvents = ev
end

function module:RefreshTotems()
	if not module:Flag("totems", "enabled", false) then
		self:DisableTotems()
		return
	end
	Ensure()
	local size = module:Num("totems", "size", 30)
	local gap = module:Num("totems", "gap", 2)
	local pr, pg, pb = module:Color("totems", "pulseColor", { 0.3, 0.75, 1 })
	local pulseH = module:Num("totems", "pulseHeight", 4)
	-- Extra top space so the pulse bar above icons is inside the holder.
	local pulseSpace = module:Flag("totems", "pulse", true) and (pulseH + PULSE_INSET * 2 + gap) or 0
	holder:SetSize(MAX_TOTEMS * (size + gap) - gap, size + pulseSpace)
	for index, slot in ipairs(SLOT_ORDER) do
		local button = buttons[slot]
		button:SetSize(size, size)
		button:ClearAllPoints()
		button:SetPoint("BOTTOMLEFT", (index - 1) * (size + gap), 0)
		local pulse = button.pulse
		pulse:SetParent(holder)
		pulse:SetFrameLevel(button:GetFrameLevel() + 3)
		pulse:SetHeight(pulseH + PULSE_INSET * 2)
		pulse:ClearAllPoints()
		pulse:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, gap)
		pulse:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, gap)
		pulse:SetBackdropColor(unpack(PULSE_BACKDROP_COLOR))
		local lr, lg, lb, la = LortiColor()
		if lr then
			pulse:SetBackdropBorderColor(lr, lg, lb, la)
			button.border:SetVertexColor(lr, lg, lb, la)
		else
			pulse:SetBackdropBorderColor(unpack(PULSE_BORDER_COLOR))
			button.border:SetVertexColor(1, 1, 1, 1)
		end
		pulse.bar:SetStatusBarTexture(BAR_TEX)
		pulse.bar:SetStatusBarColor(pr, pg, pb)
		UpdateButton(button)
	end
	module:ApplyPoint(holder, "totems")
	module:UpdateDrag("playerTotems", "totems")
	if module.IsPlayerPanelWanted then
		ApplyVisibility(module:IsPlayerPanelWanted(), 1)
	else
		ApplyVisibility(true, 1)
	end
end

-- Called by LortiUI Apply/Disable to re-tint borders without a full refresh.
function module:ApplyTotemsDarkMode()
	if holder and module:Flag("totems", "enabled", false) then
		self:RefreshTotems()
	end
end

function module:DisableTotems()
	module:StopDrag("playerTotems")
	if holder then
		holder:Hide()
	end
end
