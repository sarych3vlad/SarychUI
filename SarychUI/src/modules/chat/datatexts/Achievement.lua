-- Adapted from ElvUI (WoW 3.3.5), Modules/DataTexts/Achievement.lua.
local DT = _G.SarychUI_ChatDataTexts
local E, L = DT.Engine, DT.L

--Lua functions
local join = string.join
--WoW API / Variables
local GetTotalAchievementPoints = GetTotalAchievementPoints
local ToggleAchievementFrame = ToggleAchievementFrame
local ACHIEVEMENTS = ACHIEVEMENTS

local displayNumberString = ""
local lastPanel

local function OnEvent(self)
	lastPanel = self
	self.text:SetFormattedText(displayNumberString, GetTotalAchievementPoints())
end

local function OnClick()
	ToggleAchievementFrame()
end

local function ValueColorUpdate(hex)
	displayNumberString = join("", ACHIEVEMENTS, ": ", hex, "%d|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Achievement", {"ACHIEVEMENT_EARNED"}, OnEvent, nil, OnClick, nil, nil, ACHIEVEMENTS)