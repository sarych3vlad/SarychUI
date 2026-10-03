local E = select(2, ...):unpack()
local P = E.Party
local BarFrameIconMixin = P.BarFrameIconMixin

function BarFrameIconMixin:SetCooldownElements()
	local noSwipe = self.isHighlighted or (self.statusBar and not E.db.extraBars[self.statusBar.key].nameBar)
	local noCount = noSwipe or not E.db.icons.showCounter
	--self.cooldown:SetDrawEdge(not self.isHighlighted)
	self.cooldown:SetDrawSwipe(not noSwipe)
	self.cooldown:SetHideCountdownNumbers(noCount)
end

function BarFrameIconMixin:ResetCooldown()
	local info = P.groupInfo[self.guid]
	if not info then
		return
	end



	local active = info.active[self.spellID]
	if not active then
		return
	end


	if (self.spellID == 45438) and E.db.icons.showForbearanceCounter then
		local duration, expTime = P:GetDebuffDuration(info.unit, 41425)
		if duration and duration > 0 then
			duration = expTime - GetTime()
			if duration > 0 then
				self:StartCooldown(duration, true)
			end
			return
		end
	end



	local statusBar = self.statusBar
	self.cooldown:Clear()
	if statusBar then
		statusBar.CastingBar:OnEvent("UNIT_SPELLCAST_FAILED")
	end
end

function BarFrameIconMixin:UpdateCooldown(reducedTime, updateActiveTimer)
	local info = P.groupInfo[self.guid]
	if not info then
		return
	end

	local active = info.active[self.spellID]
	if not active then
		return
	end

	local startTime = active.startTime
	local duration = active.duration
	local modRate = active.modRate or 1
	local now = GetTime()





	reducedTime = reducedTime * modRate



	if updateActiveTimer then
		local elapsed = (now - startTime) * updateActiveTimer
		startTime = now - elapsed
		duration = duration * updateActiveTimer

	end

	startTime = startTime - reducedTime

	self.cooldown:SetCooldown(startTime, duration, modRate)
	active.startTime = startTime
	active.duration = duration
	local statusBar = self.statusBar
	if statusBar then
		statusBar.CastingBar:OnEvent(statusBar.CastingBar.channeling and "UNIT_SPELLCAST_CHANNEL_UPDATE" or "UNIT_SPELLCAST_CAST_UPDATE")
	end
end

function BarFrameIconMixin:StartCooldown(cd, noGlow, reducedStartTime)
	local info = P.groupInfo[self.guid]
	if not info then
		return
	end

	local spellID = self.spellID

	cd = cd or self.duration

	if E.spell_cdmod_by_haste[spellID] and info.auras.mult_lust then
		cd = cd * 0.7
	end


	local modRate = self.modRate
	cd = cd * modRate

	info.active[spellID] = info.active[spellID] or {}
	local active = info.active[spellID]
	local now = GetTime()
	if reducedStartTime then
		reducedStartTime = reducedStartTime * modRate
		now = now - reducedStartTime
	end

	if reduceStartTimeInstead then
		now = now - (ocd - cd)
		cd = ocd * modRate
	end
	self.cooldown:SetCooldown(now, cd, modRate)

	active.startTime = now
	active.duration = cd
	active.modRate = modRate

	local statusBar = self.statusBar
	if info.preactiveIcons[spellID] then
		info.preactiveIcons[spellID] = nil

		if statusBar then
			statusBar:SetColors()
		end
	end

	self.active = 0

	local frame = self:GetParent():GetParent()
	local key = frame.key
	if type(key) == "number" then
		if not P.displayInactive then
			frame:UpdateLayout()
		end
	elseif frame.shouldRearrangeInterrupts then
		frame:UpdateLayout(true)
	end

	if not noGlow and E.db.highlight.glow then
		self:SetGlow()
	end
	self:SetCooldownElements()
	self:SetOpacity()
	self:SetColorSaturation()
	self:SetBorderGlow(info.isDeadOrOffline, E.db.highlight.glowBorderCondition)
	if statusBar then
		statusBar.CastingBar:OnEvent(E.db.extraBars[key].reverseFill and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START")
	end
end

local MIN_RESET_DURATION = (E.isWOTLKC) and 120 or 180
function P:ResetAllIcons(reason, clearSession)
	local notEncounterEnd = reason ~= "encounterEnd"
	for guid, info in pairs(self.groupInfo) do
		local isDeadOrOffline = info.isDeadOrOffline
		local condition = E.db.highlight.glowBorderCondition
		for spellID, icon in pairs(info.spellIcons) do
			if notEncounterEnd or not E.spell_noreset_onencounterend[spellID] and icon.baseCooldown >= MIN_RESET_DURATION then
				local statusBar = icon.statusBar
				if icon.active then
					info.active[spellID] = nil
					icon.active = nil
					icon.cooldown:Clear()
					if statusBar then
						statusBar.CastingBar:OnEvent("UNIT_SPELLCAST_FAILED")
					end
				end

				if info.preactiveIcons[spellID] then
					info.preactiveIcons[spellID] = nil
					if statusBar then
						statusBar:SetColors()
					end
				end

				if icon.isHighlighted then
					icon:RemoveHighlight()
				end
				icon:SetCooldownElements()
				icon:SetOpacity()
				icon:SetColorSaturation()
				icon:SetBorderGlow(isDeadOrOffline, condition)
			end
		end

		info:CancelTimers(not notEncounterEnd)
		if clearSession then
			info:ClearSessionItemData()
			info:SetupBar()
		elseif not self.displayInactive then
			info.bar:UpdateLayout()
		end
	end

	if not clearSession then
		self:RearrangeExBarIcons()
	end
end
