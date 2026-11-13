-- Adapted from ElvUI (WoW 3.3.5), Modules/DataTexts/Crit.lua.
local DT = _G.SarychUI_ChatDataTexts
local E, L = DT.Engine, DT.L

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local GetCritChance = GetCritChance
local GetRangedCritChance = GetRangedCritChance
local GetSpellCritChance = GetSpellCritChance
local COMBAT_RATING_NAME11 = COMBAT_RATING_NAME11
local CRIT_ABBR = CRIT_ABBR
local CR_CRIT_MELEE = CR_CRIT_MELEE
local CR_CRIT_MELEE_TOOLTIP = CR_CRIT_MELEE_TOOLTIP
local CR_CRIT_RANGED = CR_CRIT_RANGED
local CR_CRIT_RANGED_TOOLTIP = CR_CRIT_RANGED_TOOLTIP
local MELEE_CRIT_CHANCE = MELEE_CRIT_CHANCE
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT
local RANGED_CRIT_CHANCE = RANGED_CRIT_CHANCE
local SPELL_CRIT_CHANCE = SPELL_CRIT_CHANCE

local critRating
local displayModifierString = ""
local lastPanel

local function OnEvent(self, event)
	lastPanel = self

	if event == "SPELL_UPDATE_USABLE" then
		self:UnregisterEvent(event)
	end

	if E.Role == "Caster"then
		critRating = GetSpellCritChance(2)
	elseif E.myclass == "HUNTER" then
		critRating = GetRangedCritChance()
	else
		critRating = GetCritChance()
	end

	self.text:SetFormattedText(displayModifierString, critRating)
end

local function OnEnter(self)
	if not DT:SetupTooltip(self) then return end

	local text, tooltip
	if E.Role == "Caster" then
		text = format("%s %.2f%%", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, SPELL_CRIT_CHANCE), critRating)
		tooltip = format("%s %d", COMBAT_RATING_NAME11, GetCombatRating(11))
	else
		if E.myclass == "HUNTER" then
			text = format("%s %.2f%%", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, RANGED_CRIT_CHANCE), critRating)
			tooltip = format(CR_CRIT_RANGED_TOOLTIP, GetCombatRating(CR_CRIT_RANGED), GetCombatRatingBonus(CR_CRIT_RANGED))
		else
			text = format("%s %.2f%%", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, MELEE_CRIT_CHANCE), critRating)
			tooltip = format(CR_CRIT_MELEE_TOOLTIP, GetCombatRating(CR_CRIT_MELEE), GetCombatRatingBonus(CR_CRIT_MELEE))
		end
	end

	DT.tooltip:AddLine(text, 1, 1, 1)
	DT.tooltip:AddLine(tooltip, nil, nil, nil, 1)

	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayModifierString = join("", CRIT_ABBR, ": ", hex, "%.2f%%|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Crit Chance", {"COMBAT_RATING_UPDATE", "SPELL_UPDATE_USABLE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_DAMAGE_DONE_MODS"}, OnEvent, nil, nil, OnEnter, nil, MELEE_CRIT_CHANCE)