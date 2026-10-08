-- Ported from FrostAtomUI Modules/ExperienceBar.lua.
-- One thin bar: experience (plus rested overlay) below max level, watched
-- reputation at max level.
local FA = SarychUI.FrostAtomBars

local UnitLevel = UnitLevel
local UnitXP, UnitXPMax = UnitXP, UnitXPMax
local GetXPExhaustion = GetXPExhaustion
local GetWatchedFactionInfo = GetWatchedFactionInfo
local GameTooltip = GameTooltip
local min = math.min
local MAX_LEVEL = MAX_PLAYER_LEVEL or 80

local ExperienceBar = FA:NewModule("ExperienceBar")
FA.ExperienceBar = ExperienceBar

local config = FA.config
local FACTION_COLORS = FACTION_BAR_COLORS
local holder, bar, rested, background

local function Label(ru)
	return (SarychUI and SarychUI.T and SarychUI:T(ru)) or ru
end

local function showExperience()
	local current, maxXP = UnitXP("player"), UnitXPMax("player")
	if not maxXP or maxXP <= 0 then
		holder:Hide()
		return
	end

	bar:SetMinMaxValues(0, maxXP)
	bar:SetValue(current)
	local color = config.experienceBar.xpColor
	bar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)

	local exhaustion = GetXPExhaustion()
	if exhaustion and exhaustion > 0 then
		rested:SetMinMaxValues(0, maxXP)
		rested:SetValue(min(current + exhaustion, maxXP))
		rested:Show()
	else
		rested:Hide()
	end

	holder.mode = "xp"
	holder:Show()
end

local function showReputation()
	local name, standing, minValue, maxValue, value = GetWatchedFactionInfo()
	if not name or not minValue or not maxValue or not value then
		holder:Hide()
		return
	end

	bar:SetMinMaxValues(0, maxValue - minValue)
	bar:SetValue(value - minValue)
	local color = FACTION_COLORS and FACTION_COLORS[standing]
	if color then
		bar:SetStatusBarColor(color.r, color.g, color.b)
	else
		bar:SetStatusBarColor(0, 0.6, 0.1)
	end
	rested:Hide()

	holder.mode = "reputation"
	holder:Show()
end

function ExperienceBar:Update()
	if not holder then return end
	local cfg = config.experienceBar
	if self.suspended or not FA.IsActive() or not cfg or cfg.enabled == false then
		holder:Hide()
	elseif UnitLevel("player") < MAX_LEVEL then
		showExperience()
	elseif cfg.showReputation ~= false then
		showReputation()
	else
		holder:Hide()
	end
end

local function onEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

	if self.mode == "xp" then
		local current, maxXP = UnitXP("player"), UnitXPMax("player")
		if maxXP and maxXP > 0 then
			GameTooltip:AddDoubleLine(Label("Опыт"), ("%d / %d (%d%%)"):format(current, maxXP, current / maxXP * 100))
			local exhaustion = GetXPExhaustion()
			if exhaustion and exhaustion > 0 then
				GameTooltip:AddDoubleLine(
					Label("Отдых"),
					("+%d (%d%%)"):format(exhaustion, exhaustion / maxXP * 100),
					0,
					0.6,
					1
				)
			end
		end
	else
		local name, standing, minValue, maxValue, value = GetWatchedFactionInfo()
		if name and minValue and maxValue and value then
			GameTooltip:AddDoubleLine(name, _G["FACTION_STANDING_LABEL" .. standing] or "")
			GameTooltip:AddDoubleLine(Label("Репутация"), ("%d / %d"):format(value - minValue, maxValue - minValue))
		end
	end

	GameTooltip:Show()
end

local function onLeave()
	GameTooltip:Hide()
end

function ExperienceBar:ApplyConfig()
	if not holder then return end
	local cfg = config.experienceBar
	if not cfg then return end

	holder:SetSize(tonumber(cfg.width) or 456, tonumber(cfg.height) or 5)
	FA.ApplyPoint(holder, cfg)
	background:SetTexture(0, 0, 0, tonumber(cfg.backgroundAlpha) or 0.6)

	local color = cfg.restedColor or { 0, 0.39, 0.88, 0.6 }
	rested:SetStatusBarColor(color[1], color[2], color[3], color[4] or 0.6)
	self:Update()
end

function ExperienceBar:SetSuspended(suspended)
	self.suspended = suspended and true or false
	self:Update()
end

function ExperienceBar:GetFrame()
	return holder
end

function ExperienceBar:Initialize()
	if self.initialized then return end
	self.initialized = true

	holder = CreateFrame("Frame", "SarychUIFrostExperienceBar", UIParent)
	holder:Hide()
	holder:SetFrameStrata("LOW")
	holder:EnableMouse(true)
	holder:SetScript("OnEnter", onEnter)
	holder:SetScript("OnLeave", onLeave)

	background = holder:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()

	rested = CreateFrame("StatusBar", "SarychUIFrostExperienceBarRested", holder)
	rested:Hide()
	rested:SetAllPoints()
	rested:SetFrameLevel(holder:GetFrameLevel() + 1)
	rested:SetStatusBarTexture(FA.Media.statusbar or FA.Media.blank)

	bar = CreateFrame("StatusBar", "SarychUIFrostExperienceBarValue", holder)
	bar:SetAllPoints()
	bar:SetFrameLevel(holder:GetFrameLevel() + 2)
	bar:SetStatusBarTexture(FA.Media.statusbar or FA.Media.blank)

	self:ApplyConfig()
	FA.RegisterMover("experienceBar", holder, FA.Label("experienceBar"))

	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD",
		"PLAYER_XP_UPDATE",
		"PLAYER_LEVEL_UP",
		"UPDATE_EXHAUSTION",
		"UPDATE_FACTION",
	}) do
		-- Some 3.3.5 derivatives omit PLAYER_XP_UPDATE.
		pcall(function() self:RegisterEvent(event, "Update") end)
	end
	pcall(function() self:RegisterUnitEvent("UNIT_EXPERIENCE", "player", "Update") end)
end

