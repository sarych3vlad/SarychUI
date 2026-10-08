-- UnitFrameLayers support for the player plate.
-- Registers the plate as a UFL unit frame so heal prediction, absorbs,
-- health-loss animation, power feedback and cast-cost prediction use the
-- same code path as PlayerFrame.

local moduleName = "player_resources"
local module = SarychUI and SarychUI.modules and SarychUI.modules[moduleName]
if not module then return end

local plateFrame
local healthBar
local powerBar
local attached
local predictedCost = 0
local castEvents

local function ToggleOn()
	local t = module:Sub("plate")
	if t and t.unitFrameLayers ~= nil then
		return t.unitFrameLayers == 1 or t.unitFrameLayers == true
	end
	return false
end

local function UFLAvailable()
	return type(UnitFrameLayers_AttachHealPrediction) == "function"
		and type(UnitFrameLayers_UpdateHealPrediction) == "function"
		and IsAddOnLoaded("UnitFrameLayers")
end

local function WantUFL()
	return ToggleOn() and UFLAvailable()
end

local function LossBar()
	return plateFrame and plateFrame.PlayerFrameHealthBarAnimatedLoss
end

-- Loss bar copies UnitHealthMax once at Attach; on /reload that can be 0.
local function SyncLossMinMax(loss)
	if not loss or not healthBar then
		return
	end
	local _, maxH = healthBar:GetMinMaxValues()
	local _, lossMax = loss:GetMinMaxValues()
	if maxH and maxH > 0 and lossMax ~= maxH then
		loss:SetMinMaxValues(0, maxH)
	end
end

local function Update()
	if not plateFrame or not attached then
		return
	end
	UnitFrameLayers_UpdateHealPrediction(plateFrame)
end

local function Attach()
	if attached or not plateFrame or not healthBar then
		return attached
	end
	if not UFLAvailable() then
		return false
	end
	local ok = pcall(UnitFrameLayers_AttachHealPrediction, plateFrame)
	if not ok or not plateFrame.myHealPredictionBar then
		return false
	end
	attached = true
	if not healthBar._suiUFLSizeHook then
		healthBar:HookScript("OnSizeChanged", function()
			if WantUFL() then
				Update()
			end
		end)
		healthBar._suiUFLSizeHook = true
	end
	return true
end

--------------------------------------------------------------------
-- Power bar: BuilderSpender feedback, full-power pulse, cast cost.
--------------------------------------------------------------------
local function PowerInfo(ptype)
	local _, token = UnitPowerType("player")
	local base = token and PowerBarColor and PowerBarColor[token]
	local r, g, b = module:PowerRGB(ptype)
	return {
		r = r, g = g, b = b,
		fullPowerAnim = base and base.fullPowerAnim or false,
	}
end

local function ResizePowerFX()
	if not powerBar or not powerBar.FullPowerFrame then
		return
	end
	local w, h = powerBar:GetWidth() or 0, powerBar:GetHeight() or 0
	if w <= 0 or h <= 0 then
		return
	end
	local fp = powerBar.FullPowerFrame
	local fw = math.min(119, w)
	fp:ClearAllPoints()
	fp:SetPoint("TOPRIGHT", powerBar, "TOPRIGHT", 0, 0)
	fp:SetSize(fw, h)
	if fp.SpikeFrame then
		fp.SpikeFrame:SetSize(fw, h)
	end
	if fp.PulseFrame then
		fp.PulseFrame:SetSize(fw, h)
	end
	local fb = powerBar.FeedbackFrame
	if fb and fb.initialized and powerBar._uflPtype then
		fb:Initialize(PowerInfo(powerBar._uflPtype), "player", powerBar._uflPtype)
	end
end

local function InitPowerFX(ptype)
	local fb, fp = powerBar.FeedbackFrame, powerBar.FullPowerFrame
	local info = PowerInfo(ptype)
	fb:StopFeedbackAnim()
	fb:Initialize(info, "player", ptype)
	fp:RemoveAnims()
	fp:Initialize(info.fullPowerAnim)
	fp:SetMaxValue(UnitPowerMax("player", ptype))
	powerBar._uflPtype = ptype
	powerBar._uflPrev = UnitPower("player", ptype)
	predictedCost = 0
end

local function EnsurePowerFX()
	if not powerBar then
		return false
	end
	if powerBar.FeedbackFrame and powerBar.FullPowerFrame then
		return true
	end
	if not BuilderSpender or not FullResourcePulse then
		return false
	end
	local ok = pcall(function()
		local fb = CreateFrame("Frame", nil, powerBar, "BuilderSpenderFrame")
		fb:SetAllPoints(powerBar)
		fb:SetFrameLevel(powerBar:GetFrameLevel() + 2)
		powerBar.FeedbackFrame = fb

		local fp = CreateFrame("Frame", nil, powerBar, "FullPowerFrameTemplate")
		fp:SetFrameLevel(powerBar:GetFrameLevel() + 3)
		powerBar.FullPowerFrame = fp
	end)
	if not ok then
		return false
	end
	ResizePowerFX()
	if not powerBar._uflSizeHook then
		powerBar:HookScript("OnSizeChanged", ResizePowerFX)
		powerBar._uflSizeHook = true
	end
	return true
end

local function HidePowerFX()
	if not powerBar then
		return
	end
	if powerBar.FeedbackFrame then
		powerBar.FeedbackFrame:StopFeedbackAnim()
	end
	if powerBar.FullPowerFrame then
		powerBar.FullPowerFrame:RemoveAnims()
	end
	if plateFrame and plateFrame.myManaCostPredictionBar then
		plateFrame.myManaCostPredictionBar:Hide()
	end
	predictedCost = 0
end

local function UpdateCastCost(isStarting, spellName)
	local cost = 0
	if isStarting and spellName and GetSpellPowerCost then
		local ptype = UnitPowerType("player")
		for _, costInfo in pairs(GetSpellPowerCost(spellName) or {}) do
			if costInfo.type == ptype then
				cost = costInfo.cost or 0
				break
			end
		end
	elseif not isStarting then
		if UnitCastingInfo("player") and predictedCost > 0 then
			cost = predictedCost
		end
	end
	predictedCost = cost
	module:PlateRequestPowerUpdate()
end

local function EnsureCastEvents()
	if castEvents then
		return
	end
	castEvents = CreateFrame("Frame", "SarychUIPlateUFLCast")
	castEvents:SetScript("OnEvent", function(_, event, unit)
		if unit ~= "player" then
			return
		end
		if not attached or not WantUFL() then
			return
		end
		if event == "UNIT_SPELLCAST_START" then
			local name, _, _, startTime, endTime = UnitCastingInfo("player")
			if name and startTime ~= endTime then
				UpdateCastCost(true, name)
			else
				UpdateCastCost(false)
			end
		else
			UpdateCastCost(false)
		end
	end)
end

local function SetCastEvents(on)
	EnsureCastEvents()
	if on then
		castEvents:RegisterEvent("UNIT_SPELLCAST_START")
		castEvents:RegisterEvent("UNIT_SPELLCAST_STOP")
		castEvents:RegisterEvent("UNIT_SPELLCAST_FAILED")
		castEvents:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	else
		castEvents:UnregisterAllEvents()
	end
end

function module:OnPlatePowerUpdate(bar, cur, maxP, ptype)
	if not attached or not WantUFL() or bar ~= powerBar then
		return
	end
	if not EnsurePowerFX() then
		return
	end
	local fb, fp = powerBar.FeedbackFrame, powerBar.FullPowerFrame
	if ptype ~= powerBar._uflPtype then
		InitPowerFX(ptype)
	end
	maxP = maxP or 0
	fb.maxValue = maxP
	fp:SetMaxValue(maxP)

	local costTex = plateFrame.myManaCostPredictionBar
	if predictedCost > 0 and maxP > 0 and costTex then
		local shown = math.max(cur - predictedCost, 0)
		powerBar:SetValue(shown)
		local fill = powerBar:GetStatusBarTexture()
		local w = (math.min(predictedCost, cur) / maxP) * (powerBar:GetWidth() or 0)
		if fill and w >= 1 then
			costTex:ClearAllPoints()
			costTex:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
			costTex:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
			costTex:SetWidth(w)
			costTex:Show()
		else
			costTex:Hide()
		end
	elseif costTex then
		costTex:Hide()
	end

	local prev = powerBar._uflPrev
	if prev and prev ~= cur then
		if maxP > 0 and math.abs(cur - prev) / maxP > 0.1 then
			fb:StartFeedbackAnim(prev, cur)
		end
		if fp.active then
			fp:StartAnimIfFull(prev, cur)
		end
	end
	powerBar._uflPrev = cur
end

function module:AttachPlatePrediction(plate, bar, power)
	if not plate or not bar then
		return
	end
	plateFrame = plate
	healthBar = bar
	powerBar = power
	plate.unit = plate.unit or "player"
	plate.healthbar = bar
	self:RefreshPlatePrediction()
end

function module:OnPlateHealthUpdate(cur)
	if not healthBar then
		return
	end
	local prev = healthBar._prevHealth
	healthBar._prevHealth = cur
	if not attached or not WantUFL() then
		return
	end
	local loss = LossBar()
	if loss and prev and prev ~= cur then
		SyncLossMinMax(loss)
		loss:UpdateHealth(cur, prev)
		loss:UpdateLossAnimation(cur)
	end
	Update()
end

function module:OnPlateMaxHealthUpdate()
	if not attached or not WantUFL() then
		return
	end
	local loss = LossBar()
	if loss then
		loss:UpdateHealthMinMax()
		SyncLossMinMax(loss)
	end
	Update()
end

function module:RefreshPlatePrediction()
	if not plateFrame or not healthBar then
		return
	end
	local on = WantUFL()
	if on then
		if Attach() then
			UnitFrameLayers_SetHealPredictionEnabled(plateFrame, true)
			SyncLossMinMax(LossBar())
			Update()
			if EnsurePowerFX() then
				powerBar._uflPtype = nil
				module:PlateRequestPowerUpdate()
			end
			SetCastEvents(true)
		end
	elseif attached then
		UnitFrameLayers_SetHealPredictionEnabled(plateFrame, false)
		HidePowerFX()
		SetCastEvents(false)
	end
end

function module:DisablePlatePrediction()
	if attached and plateFrame then
		UnitFrameLayers_SetHealPredictionEnabled(plateFrame, false)
		HidePowerFX()
		SetCastEvents(false)
	end
end
