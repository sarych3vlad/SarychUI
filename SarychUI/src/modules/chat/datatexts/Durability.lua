-- Adapted from ElvUI (WoW 3.3.5), Modules/DataTexts/Durability.lua.
local DT = _G.SarychUI_ChatDataTexts
local E, L = DT.Engine, DT.L

--Lua functions
local ipairs = ipairs
local format, join = string.format, string.join
--WoW API / Variables
local GetInventoryItemDurability = GetInventoryItemDurability
local GetInventorySlotInfo = GetInventorySlotInfo
local ToggleCharacter = ToggleCharacter
local DURABILITY = DURABILITY

local displayString = ""
local tooltipString = "%d%%"
local lastPanel
local totalDurability, current, maxDur
local invDurability = {}

local slots = {
	"HeadSlot",
	"ShoulderSlot",
	"ChestSlot",
	"WristSlot",
	"HandsSlot",
	"WaistSlot",
	"LegsSlot",
	"FeetSlot",
	"MainHandSlot",
	"SecondaryHandSlot",
	"RangedSlot",
}

local slotsLocales = {
	["HeadSlot"] = HEADSLOT,
	["ShoulderSlot"] = SHOULDERSLOT,
	["ChestSlot"] = CHESTSLOT,
	["WristSlot"] = WRISTSLOT,
	["HandsSlot"] = HANDSSLOT,
	["WaistSlot"] = WAISTSLOT,
	["LegsSlot"] = LEGSSLOT,
	["FeetSlot"] = FEETSLOT,
	["MainHandSlot"] = MAINHANDSLOT,
	["SecondaryHandSlot"] = SECONDARYHANDSLOT,
	["RangedSlot"] = RANGEDSLOT,
}

local function OnEvent(self)
	lastPanel = self
	totalDurability = 100

	for _, sType in ipairs(slots) do
		local slot = GetInventorySlotInfo(sType)
		current, maxDur = GetInventoryItemDurability(slot)

		if current then
			invDurability[sType] = (current / maxDur) * 100

			if invDurability[sType] < totalDurability then
				totalDurability = invDurability[sType]
			end
		else
			invDurability[sType] = nil
		end
	end

	self.text:SetFormattedText(displayString, totalDurability)
end

local function OnClick()
	ToggleCharacter("PaperDollFrame")
end

local function OnEnter(self)
	if not DT:SetupTooltip(self) then return end

	for _, sType in ipairs(slots) do
		if invDurability[sType] then
			DT.tooltip:AddDoubleLine(slotsLocales[sType], format(tooltipString, invDurability[sType]), 1, 1, 1, E:ColorGradient(invDurability[sType] * 0.01, 1, 0, 0, 1, 1, 0, 0, 1, 0))
		end
	end

	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", DURABILITY, ": ", hex, "%d%%|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel, "ELVUI_COLOR_UPDATE")
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Durability", {"PLAYER_ENTERING_WORLD", "UPDATE_INVENTORY_DURABILITY", "MERCHANT_SHOW"}, OnEvent, nil, OnClick, OnEnter, nil, DURABILITY)