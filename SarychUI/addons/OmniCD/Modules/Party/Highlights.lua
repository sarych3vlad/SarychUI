local E = select(2, ...):unpack()
local P = E.Party
local BarFrameIconMixin = P.BarFrameIconMixin

local function ShowOverlayGlowNoAnim(overlay)
	local frameWidth, frameHeight = overlay:GetSize()
	overlay.spark:SetSize(frameWidth, frameHeight)
	overlay.spark:SetAlpha(0)
	overlay.innerGlow:SetSize(frameWidth, frameHeight)
	overlay.innerGlow:SetAlpha(0)
	overlay.innerGlowOver:SetAlpha(0)
	overlay.outerGlow:SetSize(frameWidth, frameHeight)
	overlay.outerGlow:SetAlpha(1.0)
	overlay.outerGlowOver:SetAlpha(0)
	overlay.ants:SetSize(frameWidth * 0.85, frameHeight * 0.85)
	overlay.ants:SetAlpha(1.0)
	overlay:Show()
end

local RemoveHighlight_OnTimerEnd
RemoveHighlight_OnTimerEnd = function(icon)
	local info = P.groupInfo[icon.guid]
	if not info or not icon.isHighlighted then
		return
	end


	local duration, expTime = P:GetBuffDuration(info.unit, icon.buff)
	if duration and duration > 0 then
		duration = expTime - GetTime()
		if duration > 0 then
			icon.isHighlighted = C_Timer.NewTimer(duration + 0.1, function() RemoveHighlight_OnTimerEnd(icon) end)
			return
		end
	end
	icon:RemoveHighlight()
	icon:SetCooldownElements()
	icon:SetOpacity()
	icon:SetColorSaturation()
end

function BarFrameIconMixin:ShowOverlayGlow(duration, isRefresh)
	if E.db.highlight.glowType == "wardrobe" then
		if not self.isHighlighted then
			self.PendingFrame:Show()
			if not isRefresh then
				self.AnimFrame.animIn:Play()
			end
		end
	else
		ActionButton_ShowOverlayGlow(self)
		if isRefresh then
			self.overlay.animIn:Stop()
			ShowOverlayGlowNoAnim(self.overlay)
		end
	end

	if type(self.isHighlighted) == "table" then
		self.isHighlighted:Cancel()
	end

	self.isHighlighted = C_Timer.NewTimer(duration + 0.1, function() RemoveHighlight_OnTimerEnd(self) end)
end

function BarFrameIconMixin:HideOverlayGlow()
	if self.overlay then
		ActionButton_HideOverlayGlow(self)
	elseif self.isHighlighted then
		self.PendingFrame:Hide()
		if self:IsVisible() then
			self.AnimFrame.animOut:Play()
		else
			self.AnimFrame:Hide()
		end
	end

	if type(self.isHighlighted) == "table" then
		self.isHighlighted:Cancel()
	end

	self.isHighlighted = nil
end

function BarFrameIconMixin:RemoveHighlight()
	local info = P.groupInfo[self.guid]
	if not info or not info.glowIcons[self.buff] then
		return
	end
	info.glowIcons[self.buff] = nil
	self:HideOverlayGlow()
end

function BarFrameIconMixin:SetHighlight(isRefresh)
	if not E.db.highlight.glowBuffs or not E.db.highlight.glowBuffTypes[self.type] then
		return
	end

	local spellID = self.spellID

	local buff = self.buff
	if buff == 0 or not E.spell_highlighted[buff] or self.spellID == 59752 or self.spellID == 42292 then
		return
	end

	local info = P.groupInfo[self.guid]
	if not info then
		return
	end

	local duration, expTime = P:GetBuffDuration(info.unit, buff)
	if duration and duration > 0 then
		duration = expTime - GetTime()
	end

	if duration and duration > 0 then
		self.AnimFrame:Hide()
		self:ShowOverlayGlow(duration, isRefresh)
		info.glowIcons[buff] = self
		return true
	end
end

function BarFrameIconMixin:SetGlow()
	self.AnimFrame.animIn:Play()
end
