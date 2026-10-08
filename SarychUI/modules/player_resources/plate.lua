-- Compact health / power bars under the character (FrostAtomUI PlayerPlate).

local moduleName = "player_resources"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local MANA = 0
local IS_DRUID = module.PLAYER_CLASS == "DRUID"
local plate, health, power, mana

local function IsWanted()
	if module:Flag("plate", "alwaysShow", false) then
		return true
	end
	-- На входе в мир /reload max HP ещё 0 — не считаем это «изменением», иначе вспышка.
	local maxH = UnitHealthMax("player")
	if not maxH or maxH <= 0 then
		return false
	end
	return UnitAffectingCombat("player") or UnitHealth("player") < maxH
end

-- Shared with runes / other companions that follow plate visibility.
function module:IsPlayerPanelWanted()
	return IsWanted()
end

local function NotifyVisibility(shown, alpha)
	if module.SyncRunesToPlateVisibility then
		module:SyncRunesToPlateVisibility(shown, alpha)
	end
	if module.SyncTotemsToPlateVisibility then
		module:SyncTotemsToPlateVisibility(shown, alpha)
	end
end

local function HealthColor()
	local t = module:Sub("plate")
	local mode = (t and t.healthColorMode) or "class"
	if mode == "class" then
		return module:ClassRGB()
	elseif mode == "health" then
		local maxH = UnitHealthMax("player")
		local pct = maxH > 0 and UnitHealth("player") / maxH or 0
		if pct > 0.5 then
			return (1 - pct) * 2, 1, 0
		end
		return 1, pct * 2, 0
	end
	return module:Color("plate", "healthColor", { 0, 0.8, 0 })
end

local function UpdateHealth()
	if not health then return end
	local cur, maxH = UnitHealth("player"), UnitHealthMax("player")
	health:SetMinMaxValues(0, maxH > 0 and maxH or 1)
	health:SetValue(cur)
	if module.OnPlateHealthUpdate then
		module:OnPlateHealthUpdate(cur)
	end
	local t = module:Sub("plate")
	if t and t.healthText == "value" then
		health.text:SetText(module:FormatValue(cur))
	else
		health.text:SetFormattedText("%d%%", maxH > 0 and (cur / maxH * 100) or 0)
	end
	if t and t.healthColorMode == "health" then
		module:SetBarColor(health, HealthColor())
	end
end

local function UpdatePower()
	if not power then return end
	local cur, maxP = UnitPower("player"), UnitPowerMax("player")
	power:SetMinMaxValues(0, maxP > 0 and maxP or 1)
	local ptype = UnitPowerType("player")
	if ptype ~= power._ptype then
		power._ptype = ptype
		module:SetBarColor(power, module:PowerRGB(ptype))
	end
	power:SetValue(cur)
	power.text:SetText(module:FormatValue(cur))
	-- UnitFrameLayers: feedback glow / full-power pulse / cast cost prediction
	if module.OnPlatePowerUpdate then
		module:OnPlatePowerUpdate(power, cur, maxP, ptype)
	end
end

-- Forces UpdatePower on the next OnUpdate tick (used by cast cost prediction).
function module:PlateRequestPowerUpdate()
	if plate then
		plate._p = nil
	end
end

local function UpdateMana()
	if not mana then return end
	local maxM = UnitPowerMax("player", MANA)
	mana:SetMinMaxValues(0, maxM > 0 and maxM or 1)
	mana:SetValue(UnitPower("player", MANA))
end

local function ManaWanted()
	return IS_DRUID and module:Flag("plate", "druidMana", true) and UnitPowerType("player") ~= MANA
end

local function Layout()
	if not plate then return end
	local w = module:Num("plate", "width", 150)
	local hh = module:Num("plate", "healthHeight", 14)
	local ph = module:Num("plate", "powerHeight", 6)
	local gap = module:Num("plate", "gap", 0)
	local showPower = module:Flag("plate", "showPower", true)
	local showMana = ManaWanted()
	local manaH = math.max(math.floor(ph * 0.5), 2)
	local powerSpace = showPower and (gap + ph) or 0
	local manaSpace = showMana and (gap + manaH) or 0
	plate:SetSize(w + 4, hh + powerSpace + manaSpace + 4)
	health:SetSize(w, hh)
	health:ClearAllPoints()
	health:SetPoint("TOP", 0, -2)
	power:SetSize(w, ph)
	power:ClearAllPoints()
	power:SetPoint("TOP", health, "BOTTOM", 0, -gap)
	if showPower then power:Show() else power:Hide() end
	mana:SetSize(w, manaH)
	mana:ClearAllPoints()
	mana:SetPoint("TOP", showPower and power or health, "BOTTOM", 0, -gap)
	if showMana then mana:Show() else mana:Hide() end
end

local function Ensure()
	if plate then return end
	plate = CreateFrame("Frame", "SarychUIPlayerPlate", UIParent)
	plate:SetFrameStrata("MEDIUM")
	plate:SetBackdrop({
		bgFile = [[Interface\Buttons\WHITE8X8]],
		edgeFile = [[Interface\Buttons\WHITE8X8]],
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	plate:SetBackdropColor(0, 0, 0, 0.55)
	plate:SetBackdropBorderColor(0, 0, 0, 1)
	health = module:MakeBar(plate)
	power = module:MakeBar(plate)
	mana = module:MakeBar(plate)
	mana.text:Hide()
	module:SetBarColor(mana, module:PowerRGB(MANA))

	-- UnitFrameLayers: animated loss bar sits between plate background and the
	-- health fill (health level-1), so the health background must live on the
	-- plate instead of the StatusBar.
	health:SetFrameLevel(plate:GetFrameLevel() + 2)
	local healthBg = plate:CreateTexture(nil, "BACKGROUND")
	healthBg:SetTexture([[Interface\Buttons\WHITE8X8]])
	healthBg:SetAllPoints(health)
	healthBg:SetVertexColor(0.1, 0.1, 0.1, 0.85)
	health.bg:Hide()
	health.bg = healthBg
	plate.unit = "player"
	plate.healthbar = health

	module:RegisterDrag("playerPlate", plate, "plate", "Панель игрока")
	plate:Hide()
	plate:SetScript("OnUpdate", function(self, elapsed)
		local curH, curP = UnitHealth("player"), UnitPower("player")
		if curH ~= self._h then
			self._h = curH
			UpdateHealth()
		elseif health and health.AnimatedLossBar and health.AnimatedLossBar.animationStartTime then
			health.AnimatedLossBar:UpdateLossAnimation(curH)
		end
		if curP ~= self._p then
			self._p = curP
			UpdatePower()
		end
		if mana:IsShown() then
			local curM = UnitPower("player", MANA)
			if curM ~= self._m then
				self._m = curM
				UpdateMana()
			end
		end
		if IsWanted() then
			self:SetAlpha(1)
			NotifyVisibility(true, 1)
			return
		end
		local fade = module:Num("plate", "fadeTime", 0.5)
		local a = fade > 0 and self:GetAlpha() - elapsed / fade or 0
		if a > 0 then
			self:SetAlpha(a)
			NotifyVisibility(true, a)
		else
			self:Hide()
			NotifyVisibility(false, 0)
		end
	end)
end

local function ShowIfWanted()
	if not IsWanted() then
		if plate then
			plate:SetAlpha(1)
			plate:Hide()
		end
		NotifyVisibility(false, 0)
		return
	end
	Ensure()
	plate._h, plate._p, plate._m = nil, nil, nil
	plate:SetAlpha(1)
	plate:Show()
	NotifyVisibility(true, 1)
	UpdateHealth()
	UpdatePower()
	UpdateMana()
end

function module:RefreshPlate()
	Ensure()
	if self.AttachPlatePrediction then
		self:AttachPlatePrediction(plate, health, power)
	end
	plate:Hide()
	Layout()
	module:ApplyPoint(plate, "plate")
	local showText = module:Flag("plate", "showText", true)
	local fontSize = module:Num("plate", "fontSize", 10)
	module:SetFont(health.text, fontSize)
	module:SetFont(power.text, fontSize)
	local t = module:Sub("plate")
	local align = t and t.textAlign or "right"
	local point, xOff = "RIGHT", -2
	if align == "left" then
		point, xOff = "LEFT", 2
	elseif align == "center" then
		point, xOff = "CENTER", 0
	end
	for _, bar in ipairs({ health, power }) do
		bar.text:ClearAllPoints()
		bar.text:SetPoint(point, bar, point, xOff, 0)
		bar.text:SetJustifyH(string.upper(align))
	end
	if showText then
		health.text:Show()
		power.text:Show()
	else
		health.text:Hide()
		power.text:Hide()
	end
	module:SetBarColor(health, HealthColor())
	power._ptype = nil
	UpdatePower()
	ShowIfWanted()
	if self.RefreshPlatePrediction then
		self:RefreshPlatePrediction()
	end
	module:UpdateDrag("playerPlate", "plate")

	if not self._plateEvents then
		self._plateEvents = CreateFrame("Frame")
		self._plateEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
		self._plateEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
		self._plateEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
		self._plateEvents:RegisterEvent("UNIT_HEALTH")
		self._plateEvents:RegisterEvent("UNIT_MAXHEALTH")
		if IS_DRUID then
			self._plateEvents:RegisterEvent("UNIT_DISPLAYPOWER")
		end
		self._plateEvents:SetScript("OnEvent", function(_, event, unit)
			if event == "PLAYER_REGEN_DISABLED" then
				ShowIfWanted()
			elseif event == "UNIT_DISPLAYPOWER" and unit == "player" then
				Layout()
				ShowIfWanted()
			elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
				if unit == "player" then
					if event == "UNIT_MAXHEALTH" and module.OnPlateMaxHealthUpdate then
						module:OnPlateMaxHealthUpdate()
					end
					ShowIfWanted()
				end
			else
				ShowIfWanted()
			end
		end)
	end
end

function module:DisablePlate()
	module:StopDrag("playerPlate")
	if self.DisablePlatePrediction then
		self:DisablePlatePrediction()
	end
	if plate then
		plate:Hide()
	end
	NotifyVisibility(false, 0)
	if self._plateEvents then
		self._plateEvents:UnregisterAllEvents()
		self._plateEvents:SetScript("OnEvent", nil)
		self._plateEvents = nil
	end
end
