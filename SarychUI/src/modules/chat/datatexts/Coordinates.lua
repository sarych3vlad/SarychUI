-- Adapted from ElvUI (WoW 3.3.5), Modules/DataTexts/Coordinates.lua.
local DT = _G.SarychUI_ChatDataTexts
local E, L = DT.Engine, DT.L

--Lua functions
local join = string.join
--WoW API / Variables
local GetPlayerMapPosition = GetPlayerMapPosition
local ToggleFrame = ToggleFrame

local displayString = ""
local x, y = 0, 0

local timeSinceUpdate = 0

local function OnUpdate(self, elapsed)
	timeSinceUpdate = timeSinceUpdate + elapsed

	if timeSinceUpdate > 0.2 then
		timeSinceUpdate = 0

		if not WorldMapFrame:IsShown() then SetMapToCurrentZone() end
		x, y = GetPlayerMapPosition("player")

		self.text:SetFormattedText(displayString, x * 100, y * 100)
	end
end

local function OnClick()
	ToggleFrame(WorldMapFrame)
end

local function ValueColorUpdate(hex)
	displayString = join("", hex, "%.2f|r", " , ", hex, "%.2f|r")
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Coords", nil, nil, OnUpdate, OnClick, nil, nil, L["Coords"])