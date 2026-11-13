-- Adapted from ElvUI (WoW 3.3.5), Modules/DataTexts/HonorableKills.lua.
local DT = _G.SarychUI_ChatDataTexts
local E, L = DT.Engine, DT.L

--Lua functions
local join = string.join
--WoW API / Variables
local GetPVPLifetimeStats = GetPVPLifetimeStats
local KILLS = KILLS

local lastPanel
local displayNumberString = ""

local function OnEvent(self)
	lastPanel = self
	self.text:SetFormattedText(displayNumberString, (GetPVPLifetimeStats()))
end

local function ValueColorUpdate(hex)
	displayNumberString = join("", KILLS, ": ", hex, "%d|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Honorable Kills", {"PLAYER_PVP_KILLS_CHANGED", "PLAYER_PVP_RANK_CHANGED"}, OnEvent, nil, nil, nil, nil, HONORABLE_KILLS)