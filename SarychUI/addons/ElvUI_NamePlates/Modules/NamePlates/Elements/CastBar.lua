local E, L, V, P, G = unpack(_G.SarychUI_ElvUI_NamePlates) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

--Lua functions
local unpack = unpack
local abs = math.abs
--WoW API / Variables
local CreateFrame = CreateFrame
local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local FAILED = FAILED
local INTERRUPTED = INTERRUPTED

local function resetAttributes(self)
	self.casting = nil
	self.channeling = nil
	self.notInterruptible = nil
	self.spellName = nil
	self.interrupted = nil
	self.lastValue = nil
end

--[[
	Patched 3.3.5 clients drive the *default* nameplate castbar for every casting
	unit (not just the current target). Instead of re-detecting casts through
	UnitCastingInfo("target") / UnitIsUnit(unit, "target"), we treat the default
	nameplate castbar (`frame.oldCastBar`) as the single source of truth and mirror
	its show/hide/value onto the ElvUI castbar. This way the ElvUI castbar appears
	exactly when (and only when) the default one does.
]]

-- The default castbar visuals are parented to the root nameplate, so the client
-- can re-show/re-texture them on every cast. We keep them invisible (alpha 0)
-- without hiding them, so their OnShow/OnHide/OnValueChanged scripts still fire.
local function HideBlizzardCastVisuals(blizz)
	if not blizz then return end
	blizz:SetAlpha(0)
	if blizz.Icon then blizz.Icon:SetAlpha(0) end
	if blizz.Shield then blizz.Shield:SetAlpha(0) end
	if blizz.Border then blizz.Border:SetAlpha(0) end
end
NP.HideBlizzardCastVisuals = HideBlizzardCastVisuals

-- Desaturation must be deterministic and never leak between casts on a recycled
-- icon. We only desaturate when the cast is *known* non-interruptible from the
-- unit API (the default castbar's shield region is unreliable on this client, so
-- relying on it produced spurious grayscale icons). For everything else (incl.
-- all non-target casters) the icon stays in full color.
local function ApplyIconDesaturation(castBar)
	local desat = (castBar.notInterruptible and NP.db and NP.db.colors.castbarDesaturate) and true or false
	castBar.Icon.texture:SetDesaturated(desat)
end

local function UpdateCastTimeText(castBar)
	local maxValue = castBar.max
	if not maxValue or maxValue <= 0 then
		castBar.Time:SetText()
		return
	end

	local value = castBar.value or 0
	local elapsed = castBar.channeling and (maxValue - value) or value
	local remaining = castBar.channeling and value or (maxValue - value)
	local fmt = castBar.channeling and castBar.channelTimeFormat or castBar.castTimeFormat

	if fmt == "CURRENT" then
		castBar.Time:SetFormattedText(" %.1f ", elapsed)
	elseif fmt == "CURRENTMAX" then
		castBar.Time:SetFormattedText(" %.1f / %.2f ", elapsed, maxValue)
	elseif fmt == "REMAINING" then
		castBar.Time:SetFormattedText(" %.1f ", remaining)
	elseif fmt == "REMAININGMAX" then
		castBar.Time:SetFormattedText(" %.1f / %.2f ", remaining, maxValue)
	else
		castBar.Time:SetText()
	end
end

-- OnUpdate on the ElvUI castbar: while shown, keep mirroring the default castbar
-- and hide ourselves as soon as the default one is gone.
function NP:Update_CastBarOnUpdate(elapsed)
	if self.__ENPTest then return end

	local frame = self.__ENPFrame
	local blizz = frame and frame.oldCastBar

	if not blizz or not blizz:IsShown() then
		if self:IsShown() then
			resetAttributes(self)
			self:Hide()
			if frame then NP:StyleFilterUpdate(frame, "FAKE_Casting") end
		end
		return
	end

	HideBlizzardCastVisuals(blizz)

	-- Mirror the default castbar directly: its value/min/max ARE the real cast
	-- progress (in seconds) and are target-independent, so re-reading it stays
	-- correct across target/untarget instead of restarting a local timer.
	local minValue, maxValue = blizz:GetMinMaxValues()
	local value = blizz:GetValue()

	-- infer cast vs channel from the direction the default bar is moving
	if self.lastValue then
		if value < self.lastValue - 0.0001 then
			self.channeling, self.casting = true, nil
		elseif value > self.lastValue + 0.0001 then
			self.casting, self.channeling = true, nil
		end
	end
	self.lastValue = value

	self.value = value
	self.max = maxValue
	self:SetMinMaxValues(minValue, maxValue)
	self:SetValue(value)

	UpdateCastTimeText(self)
end

-- Find a visible plate for a caster, by GUID first then by (realm-stripped) name.
local function FindPlateByCaster(guid, name)
	if guid then
		for frame in pairs(NP.VisiblePlates) do
			if frame.guid == guid then return frame end
		end
	end
	if name then
		local short = name
		local dash = string.find(name, "-", 1, true)
		if dash then short = string.sub(name, 1, dash - 1) end
		for frame in pairs(NP.VisiblePlates) do
			if frame.UnitName == name or frame.UnitName == short then return frame end
		end
	end
end

-- Apply combat-log spell info (name/icon) onto a currently shown castbar.
function NP:ApplyCastInfo(frame)
	local castBar = frame.CastBar
	if frame.castSpellName then
		castBar.spellName = frame.castSpellName
		castBar.Name:SetText(frame.castSpellName)
		if frame.castSpellIcon then
			castBar.Icon.texture:SetTexture(frame.castSpellIcon)
			ApplyIconDesaturation(castBar)
		end
	end
end

-- The default nameplate castbar carries no spell name on 3.3.5, and non-target
-- casters have no unit token, so we read the spell name/icon from the combat log
-- and match it to the plate by caster GUID/name. SPELL_CAST_START covers normal
-- casts; SPELL_CAST_SUCCESS (fired at channel start on this client) covers
-- channels. This fills in the spell name for casters that are NOT the target.
function NP:COMBAT_LOG_EVENT_UNFILTERED(_, _, subevent, sourceGUID, sourceName, _, _, _, _, spellId, spellName)
	if subevent ~= "SPELL_CAST_START" and subevent ~= "SPELL_CAST_SUCCESS" then return end
	local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
	if SarychUI_PerfLog then
		SarychUI_PerfLog("ElvUI_NamePlates", "COMBAT_LOG_CAST", tostring(subevent) .. " " .. tostring(spellId))
	end

	local frame = FindPlateByCaster(sourceGUID, sourceName)
	if not frame then return end

	local _, _, icon = GetSpellInfo(spellId)
	frame.castSpellName = spellName
	frame.castSpellIcon = icon
	frame.castSpellAt = GetTime()

	if frame.CastBar:IsShown() then
		self:ApplyCastInfo(frame)
	end
	if SarychUI_PerfSlow then
		SarychUI_PerfSlow("ElvUI_NamePlates", "COMBAT_LOG_CASTSlow", perfStart, spellName, 2)
	end
end

-- Start (or refresh) the ElvUI castbar from the current default castbar state.
function NP:StartCastBarFromDefault(frame)
	local castBar = frame.CastBar
	local blizz = frame.oldCastBar

	if not blizz then return end

	HideBlizzardCastVisuals(blizz)

	local db = self.db.units[frame.UnitType] and self.db.units[frame.UnitType].castbar
	if not db or db.enable ~= true or not frame.Health:IsShown() or not blizz:IsShown() then
		resetAttributes(castBar)
		castBar:Hide()
		return
	end

	local bMin, bMax = blizz:GetMinMaxValues()
	local bVal = blizz:GetValue()

	local now = GetTime()
	local isResync = castBar:IsShown()

	-- Resolve spell name / icon / cast type. Priority for NAME:
	--   unit token (exact) > combat-log capture > what we already show (preserve).
	-- Priority for ICON:
	--   unit token > default castbar's own per-plate icon > combat-log > preserve.
	-- Preserving the current values means targeting/untargeting mid-cast never
	-- wipes the spell name or icon.
	--
	-- notInterruptible is only trusted from the unit API. The default castbar's
	-- shield region is unreliable on this client and caused spurious desaturated
	-- icons, so non-target casts are treated as interruptible (full-color icon).
	local name, texture, channeling, notInterruptible
	if frame.unit then
		local n, _, _, tex, _, _, _, _, ni = UnitCastingInfo(frame.unit)
		if n then
			name, texture, channeling, notInterruptible = n, tex, false, ni
		else
			local cn, _, _, ctex, _, _, _, cni = UnitChannelInfo(frame.unit)
			if cn then
				name, texture, channeling, notInterruptible = cn, ctex, true, cni
			end
		end
	end
	notInterruptible = notInterruptible or false
	castBar.notInterruptible = notInterruptible

	-- combat-log capture is only trusted briefly (so a stale instant-cast name
	-- can't leak onto a later cast); the live handler keeps it updated while shown.
	local clFresh = frame.castSpellAt and (now - frame.castSpellAt) < 0.6
	if not name and clFresh then
		name = frame.castSpellName
	end

	-- the default castbar's own icon region is per-plate and matches this caster
	if not texture and blizz.Icon then
		local t = blizz.Icon:GetTexture()
		if t and t ~= "" then texture = t end
	end
	if not texture and clFresh and frame.castSpellIcon then
		texture = frame.castSpellIcon
	end

	if isResync then
		if not name then name = castBar.spellName end
		if not texture then texture = castBar.Icon.texture:GetTexture() end
	end

	-- Mirror the default castbar's range/value directly. It is the real, target-
	-- independent cast progress (seconds), so it stays correct when you target or
	-- untarget mid-cast (no timer restart). Channel/cast direction comes from the
	-- unit when known, otherwise inferred from value movement in OnUpdate.
	if channeling == nil then
		channeling = (castBar.lastValue and bVal < castBar.lastValue - 0.0001) or false
	end

	castBar.value = bVal
	castBar.max = bMax
	castBar.lastValue = bVal
	castBar.interrupted = nil
	castBar.casting = not channeling
	castBar.channeling = channeling or nil
	castBar.spellName = name

	castBar:SetMinMaxValues(bMin, bMax)
	castBar:SetValue(bVal)

	-- keep the castbar above the health bar / nameplate regions
	if frame.Health then
		castBar:SetFrameLevel(frame.Health:GetFrameLevel() + 1)
	end

	if texture then castBar.Icon.texture:SetTexture(texture) end
	castBar.Spark:Show()
	castBar.Name:SetText(name or "")
	castBar.Time:SetText()

	if notInterruptible then
		castBar:SetStatusBarColor(self.db.colors.castNoInterruptColor.r, self.db.colors.castNoInterruptColor.g, self.db.colors.castNoInterruptColor.b)
	else
		castBar:SetStatusBarColor(self.db.colors.castColor.r, self.db.colors.castColor.g, self.db.colors.castColor.b)
	end
	ApplyIconDesaturation(castBar)

	castBar:Show()

	self:StyleFilterUpdate(frame, "FAKE_Casting")
end

-- Hide the ElvUI castbar when the default castbar goes away.
function NP:StopCastBarFromDefault(frame)
	local castBar = frame.CastBar
	resetAttributes(castBar)
	castBar.Icon.texture:SetDesaturated(false)
	castBar:Hide()
	frame.castSpellName = nil
	frame.castSpellIcon = nil
	frame.castSpellAt = nil
	self:StyleFilterUpdate(frame, "FAKE_Casting")
end

-- Default-castbar script hooks (called with the Blizzard castbar as `self`).
local function DefaultCastBar_OnShow(blizz)
	local frame = blizz.__ENPFrame
	if frame then NP:StartCastBarFromDefault(frame) end
end

local function DefaultCastBar_OnHide(blizz)
	local frame = blizz.__ENPFrame
	if frame then NP:StopCastBarFromDefault(frame) end
end

local function DefaultCastBar_OnValueChanged(blizz)
	local frame = blizz.__ENPFrame
	if not frame then return end

	-- (Re)start the ElvUI castbar if the default bar is shown but ours somehow isn't.
	if blizz:IsShown() and not frame.CastBar:IsShown() then
		NP:StartCastBarFromDefault(frame)
	end
end

-- Wire the default nameplate castbar of a unitFrame to the ElvUI castbar.
function NP:HookDefaultCastBar(unitFrame)
	local blizz = unitFrame and unitFrame.oldCastBar
	local castBar = unitFrame and unitFrame.CastBar

	if not blizz then return end
	if not castBar then return end
	if blizz.__ENPHooked then return end

	blizz.__ENPFrame = unitFrame
	unitFrame.CastBar.__ENPFrame = unitFrame

	HideBlizzardCastVisuals(blizz)

	blizz:HookScript("OnShow", DefaultCastBar_OnShow)
	blizz:HookScript("OnHide", DefaultCastBar_OnHide)
	blizz:HookScript("OnValueChanged", DefaultCastBar_OnValueChanged)
	blizz.__ENPHooked = true

	if blizz:IsShown() then
		DefaultCastBar_OnShow(blizz)
	end
end

-- Re-sync the ElvUI castbar with the default castbar's current state. Used by the
-- generic update paths (health refresh, target/mouseover changes) without making
-- the target the trigger for the castbar.
function NP:Update_CastBar(frame)
	local castBar = frame.CastBar
	local blizz = frame.oldCastBar

	if not blizz then return end

	HideBlizzardCastVisuals(blizz)

	local db = self.db.units[frame.UnitType] and self.db.units[frame.UnitType].castbar
	if not db or db.enable ~= true or not frame.Health:IsShown() then
		resetAttributes(castBar)
		castBar:Hide()
		return
	end

	if blizz:IsShown() then
		self:StartCastBarFromDefault(frame)
	else
		resetAttributes(castBar)
		castBar:Hide()
	end
end

function NP:Configure_CastBarScale(frame, scale, noPlayAnimation)
	if frame.currentScale == scale then return end
	local db = self.db.units[frame.UnitType].castbar
	if not db.enable then return end

	local castBar = frame.CastBar

	if noPlayAnimation then
		castBar:SetSize(db.width * scale, db.height * scale)
		castBar.Icon:SetSize(db.iconSize * scale, db.iconSize * scale)
	else
		if castBar.scale:IsPlaying() or castBar.Icon.scale:IsPlaying() then
			castBar.scale:Stop()
			castBar.Icon.scale:Stop()
		end

		castBar.scale.width:SetChange(db.width * scale)
		castBar.scale.height:SetChange(db.height * scale)
		castBar.scale:Play()

		castBar.Icon.scale.width:SetChange(db.iconSize * scale)
		castBar.Icon.scale.height:SetChange(db.iconSize * scale)
		castBar.Icon.scale:Play()
	end
end

function NP:Configure_CastBar(frame, configuring)
	local db = self.db.units[frame.UnitType].castbar
	local castBar = frame.CastBar

	castBar:SetPoint("TOP", frame.Health, "BOTTOM", db.xOffset, db.yOffset)

	if db.showIcon then
		castBar.Icon:ClearAllPoints()
		castBar.Icon:SetPoint(db.iconPosition == "RIGHT" and "BOTTOMLEFT" or "BOTTOMRIGHT", castBar, db.iconPosition == "RIGHT" and "BOTTOMRIGHT" or "BOTTOMLEFT", db.iconOffsetX, db.iconOffsetY)
		castBar.Icon:Show()
	else
		castBar.Icon:Hide()
	end

	castBar.Time:ClearAllPoints()
	castBar.Name:ClearAllPoints()

	-- Make sure the fill texture exists BEFORE we anchor the spark to it.
	castBar:SetStatusBarTexture(LSM:Fetch("statusbar", self.db.statusbar), "BORDER")

	castBar.Spark:SetPoint("CENTER", castBar:GetStatusBarTexture(), "RIGHT", 0, 0)
	castBar.Spark:SetHeight(db.height * 2)

	if db.textPosition == "BELOW" then
		castBar.Time:SetPoint("TOPRIGHT", castBar, "BOTTOMRIGHT")
		castBar.Name:SetPoint("TOPLEFT", castBar, "BOTTOMLEFT")
	elseif db.textPosition == "ABOVE" then
		castBar.Time:SetPoint("BOTTOMRIGHT", castBar, "TOPRIGHT")
		castBar.Name:SetPoint("BOTTOMLEFT", castBar, "TOPLEFT")
	else
		castBar.Time:SetPoint("RIGHT", castBar, "RIGHT", -4, 0)
		castBar.Name:SetPoint("LEFT", castBar, "LEFT", 4, 0)
	end

	if configuring then
		self:Configure_CastBarScale(frame, frame.currentScale or 1, configuring)
	end

	castBar.Name:FontTemplate(LSM:Fetch("font", db.font), db.fontSize, db.fontOutline)
	castBar.Time:FontTemplate(LSM:Fetch("font", db.font), db.fontSize, db.fontOutline)

	if db.hideSpellName then
		castBar.Name:Hide()
	else
		castBar.Name:Show()
	end
	if db.hideTime then
		castBar.Time:Hide()
	else
		castBar.Time:Show()
	end

	castBar.castTimeFormat = db.castTimeFormat
	castBar.channelTimeFormat = db.channelTimeFormat
end

function NP:Construct_CastBar(parent)
	local frame = CreateFrame("StatusBar", "$parentCastBar", parent)
	-- Set the fill texture immediately (like the health bar). Otherwise the bar
	-- has no statusbar texture until Configure runs, and an empty fill is invisible.
	frame:SetStatusBarTexture(LSM:Fetch("statusbar", self.db and self.db.statusbar or "ElvUI Norm"), "BORDER")
	NP:StyleFrame(frame)
	frame:SetScript("OnUpdate", NP.Update_CastBarOnUpdate)

	frame.Icon = CreateFrame("Frame", nil, frame)
	frame.Icon.texture = frame.Icon:CreateTexture(nil, "BORDER")
	frame.Icon.texture:SetAllPoints()
	frame.Icon.texture:SetTexCoord(unpack(E.TexCoords))
	NP:StyleFrame(frame.Icon)

	frame.Time = frame:CreateFontString(nil, "OVERLAY")
	frame.Time:SetJustifyH("RIGHT")
	frame.Time:SetWordWrap(false)

	frame.Name = frame:CreateFontString(nil, "OVERLAY")
	frame.Name:SetJustifyH("LEFT")
	frame.Name:SetWordWrap(false)

	frame.Spark = frame:CreateTexture(nil, "OVERLAY")
	frame.Spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	frame.Spark:SetBlendMode("ADD")
	frame.Spark:SetSize(15, 15)

	frame.holdTime = 0
	frame.interrupted = nil

	frame.scale = CreateAnimationGroup(frame)
	frame.scale.width = frame.scale:CreateAnimation("Width")
	frame.scale.width:SetDuration(0.2)
	frame.scale.height = frame.scale:CreateAnimation("Height")
	frame.scale.height:SetDuration(0.2)

	frame.Icon.scale = CreateAnimationGroup(frame.Icon)
	frame.Icon.scale.width = frame.Icon.scale:CreateAnimation("Width")
	frame.Icon.scale.width:SetDuration(0.2)
	frame.Icon.scale.height = frame.Icon.scale:CreateAnimation("Height")
	frame.Icon.scale.height:SetDuration(0.2)

	frame:Hide()

	return frame
end
