-- Adapted from ElvUI (WoW 3.3.5), Modules/DataTexts/CombatTime.lua.
local DT = _G.SarychUI_ChatDataTexts
local E, L = DT.Engine, DT.L

--Lua functions
local floor = math.floor
local format, join = string.format, string.join
--WoW API / Variables
local COMBAT = COMBAT

local timer = 0
local displayNumberString = ""

local lastPanel

local function OnUpdate(self, elapsed)
	timer = timer + elapsed
	self.text:SetFormattedText(displayNumberString, format("%02d:%02d:%02d", floor(timer / 60), timer % 60, (timer - floor(timer)) * 100))
end

local function OnEvent(self, event)
	if event == "PLAYER_REGEN_DISABLED" or (event == "ELVUI_FORCE_RUN" and UnitAffectingCombat("player")) then
		timer = 0
		self:SetScript("OnUpdate", OnUpdate)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:SetScript("OnUpdate", nil)
	else
		self.text:SetFormattedText(displayNumberString, "00:00:00")
	end

	lastPanel = self
end

local function ValueColorUpdate(hex)
	displayNumberString = join("", COMBAT, ": ", hex, "%s|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Combat Time", {"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}, OnEvent, nil, nil, nil, nil, L["Combat Time"])