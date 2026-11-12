local E, L, V, P, G = unpack(_G.SarychUI_ElvUI_NamePlates) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local NP = E:GetModule("NamePlates")

--Lua functions
--WoW API / Variables

function NP:Update_IconFrame(frame)
	local db = self.db.units[frame.UnitType].iconFrame
	if not db then return end

	if db.enable or (frame.IconOnlyChanged or frame.IconChanged) then
		local totem, unit, icon = self.Totems[frame.UnitName], self.UniqueUnits[frame.UnitName], frame._suiPetIconTexture
		if not icon then
			if totem then
				icon = NP.TriggerConditions.totems[totem][3]
			elseif unit then
				icon = NP.TriggerConditions.uniqueUnits[unit][3]
			end
		end

		if type(icon) == "string" and icon ~= "" then
			if frame.IconFrame.texture._sarTexturePath ~= icon then
				frame.IconFrame.texture:SetTexture(icon)
				frame.IconFrame.texture._sarTexturePath = icon
			end
			frame.IconFrame:Show()

			self:StyleFrameColor(frame.IconFrame, frame.oldHealthBar:GetStatusBarColor())
		else
			frame.IconFrame:Hide()
		end
	else
		frame.IconFrame:Hide()
	end
end

function NP:Configure_IconFrame(frame, triggered)
	local db = self.db.units[frame.UnitType].iconFrame
	if not db then return end

	if db.enable or (frame.IconOnlyChanged or frame.IconChanged) then
		frame.IconFrame:SetSize(db.size, db.size)
		frame.IconFrame:ClearAllPoints()

		if frame._suiPetIconTexture then
			SarychUI.modules.health_indicators:AnchorPetIcon(frame.IconFrame, frame:GetParent())
		elseif triggered then
			frame.IconFrame:SetPoint("TOP", frame)
		else
			frame.IconFrame:SetPoint(E.InversePoints[db.position], db.parent == "Nameplate" and frame or frame[db.parent], db.position, db.xOffset, db.yOffset)
		end
	else
		frame.IconFrame:Hide()
	end
end

function NP:Construct_IconFrame(frame)
	local iconFrame = CreateFrame("Frame", nil, frame)
	iconFrame:Hide()

	iconFrame:SetSize(24, 24)
	iconFrame:SetPoint("CENTER")
	NP:StyleFrame(iconFrame, true)

	iconFrame.texture = iconFrame:CreateTexture()
	iconFrame.texture:SetAllPoints()
	iconFrame.texture:SetTexCoord(unpack(E.TexCoords))

	return iconFrame
end
