local E, L, V, P, G = unpack(_G.SarychUI_ElvUI_NamePlates) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

--Lua functions
--WoW API / Variables

function NP:Update_Highlight(frame)
	if not NP.db.highlight then return end

	local showNameGlow = false
	local showHealthHighlight = false

	if frame.isMouseover and ((frame.IconOnlyChanged or frame.NameOnlyChanged) or (not self.db.units[frame.UnitType].health.enable and self.db.units[frame.UnitType].name.enable)) and not frame.isTarget then
		showNameGlow = true
		showHealthHighlight = true
	elseif frame.isMouseover and (not frame.NameOnlyChanged or self.db.units[frame.UnitType].health.enable) and not frame.isTarget then
		showHealthHighlight = true
	end

	local nameGlow = frame.Name.NameOnlyGlow
	local healthHighlight = frame.Health.Highlight

	if showNameGlow then
		if not nameGlow:IsShown() then
			nameGlow:Show()
		end
	else
		if nameGlow:IsShown() then
			nameGlow:Hide()
		end
	end

	if showHealthHighlight then
		if not healthHighlight:IsShown() then
			healthHighlight:Show()
		end
	else
		if healthHighlight:IsShown() then
			healthHighlight:Hide()
		end
	end
end

function NP:Configure_Highlight(frame)
	frame.Health.Highlight:ClearAllPoints()
	frame.Health.Highlight:SetPoint("TOPLEFT", frame.Health, "TOPLEFT")
	frame.Health.Highlight:SetPoint("BOTTOMRIGHT", frame.Health:GetStatusBarTexture(), "BOTTOMRIGHT")
	frame.Health.Highlight:SetTexture(LSM:Fetch("statusbar", self.db.statusbar))
end

function NP:Construct_Highlight(frame)
	local highlight = frame.Health:CreateTexture("$parentHighlight", "OVERLAY")
	highlight:SetVertexColor(1, 1, 1, 0.3)
	highlight:Hide()
	return highlight
end
