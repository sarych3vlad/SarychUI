local E = select(2, ...):unpack()
local P, CM, CD = E.Party, E.Comm, E.Cooldowns

local pairs, ipairs, type = pairs, ipairs, type
local GetSpellLevelLearned = E.spell_requiredLevel and function(id)
		return not P.isInTestMode and E.spell_requiredLevel[id] or 0
	end
	or function() return 0 end

local GroupInfoMixin = {}

function GroupInfoMixin:ProcessAura(spellID)
	local icon = E.spellcast_merged[spellID] and self:FindIconFromCastID(spellID) or self.spellIcons[spellID]

	if icon and icon.duration > 0 and not icon.isHighlighted then
		icon:SetHighlight()
		icon:SetCooldownElements()
		icon:SetOpacity()
		icon:SetColorSaturation()
	end
end

function GroupInfoMixin:ProcessSpell(spellID)

	local guid = self.guid

	if E.specTalentChangeIDs[spellID] then
		if guid ~= E.userGUID and not CM.syncedGroupMembers[guid] then
			CM:EnqueueInspect(nil, guid)
		end
		return
	end

	local icon, mergedID
	if E.spellcast_merged[spellID] then
		icon, mergedID = self:FindIconFromCastID(spellID)
	else
		icon = self.spellIcons[spellID]
	end

	local linked = E.spellcast_linked[mergedID or spellID]
	if linked then
		for _, linkedID in pairs(linked) do
			local icon = self.spellIcons[linkedID]
			if icon then
				if linkedID == mergedID then
					if P.isHighlightEnabled and mergedID and icon.buff == mergedID then
						icon.buff = spellID
					end
				end

				icon:StartCooldown((E.isWOTLKC) and (spellID == 6552 and 10 or (spellID == 72 and 12)) or icon.duration)
				self.active[linkedID].castedLink = mergedID or spellID
			end
		end
		return
	end


	if icon and icon.duration > 0 then
		if P.isHighlightEnabled and mergedID and icon.buff == mergedID then
			icon.buff = spellID
		end

		if E.spell_auraremoved_cdstart_preactive[spellID] then
			if icon.active then
				icon.cooldown:Clear()
			end
			self.preactiveIcons[icon.spellID] = icon

			icon:SetHighlight()
			icon:SetCooldownElements()
			icon:SetOpacity()
			icon:SetColorSaturation()

			if icon.statusBar then
				icon.statusBar:SetColors()
			end


			if spellID == 5384 then
				self.bar:RegisterUnitEvent("UNIT_AURA", self.unit)
			end
			return
		end

		local updateSpell = E.spellcast_merged_updateoncast[spellID]
		if updateSpell then
			local cd = updateSpell[1] or icon.duration

			local iconID = self.talentData[ updateSpell[3] ] and updateSpell[4] or updateSpell[2]
			if iconID then
				icon.icon:SetTexture(iconID)
			end
			icon:StartCooldown(cd)
			return
		end

		icon:StartCooldown()
	end

	local shared = E.spellcast_shared_cdstart[spellID]
	if shared then
		local now = GetTime()
		for i = 1, #shared, 2 do
			local sharedID = shared[i]
			local sharedCD = shared[i+1]
			if type(sharedCD) == "function" then
				sharedCD = sharedCD(self.spec)
			end
			local sharedIcon = self.spellIcons[sharedID]
			if sharedIcon then
				local active = sharedIcon.active and self.active[sharedID]
				if not active or (active.startTime + active.duration - now < sharedCD) then
					sharedIcon:StartCooldown(sharedCD)
				end
			end
		end
		return
	end

	local reset = E.spellcast_cdreset[spellID]
	if reset then
		if self:IsTalentForPvpStatus(reset[1]) then
			self:ResetCdByCast(reset)
		end
	end
end

local wotlkcReadinessExcluded = {
	[23989] = true,
	[19574] = true,
	[53480] = true,
	[54044] = true,
	[53490] = true,
	[53517] = true,
	[26090] = true,
}

function GroupInfoMixin:ResetClassicSpellsOnReadinessPrep()
	for id, icon in pairs(self.spellIcons) do
		if icon.active and icon.isBookType and not wotlkcReadinessExcluded[id] then
			icon:ResetCooldown()
		end
	end
end

function GroupInfoMixin:ResetClassicWardsOnColdSnap(icon, resetID)

	if self.active[resetID] and resetID == self.active[resetID].castedLink then
		local linkedIcon = self.spellIcons[543]
		if linkedIcon and linkedIcon.active then
			linkedIcon:ResetCooldown()
		end
		icon:ResetCooldown()
	end
end

function GroupInfoMixin:ResetCdByCast(reset)
	for i = 2, #reset do
		local resetID = reset[i]
		if type(resetID) == "table" then
			if self:IsTalentForPvpStatus(resetID[1]) then
				self:ResetCdByCast(resetID)
			end
		elseif resetID == "*" then
			self:ResetClassicSpellsOnReadinessPrep()
		else
			local icon = self.spellIcons[resetID]
			if icon and icon.active then
				if resetID == 6143 then
					self:ResetClassicWardsOnColdSnap(icon, resetID)
				elseif resetID ~= 120 then
					icon:ResetCooldown()
				end
			end
		end
	end
end

--[[ Tsoukie: This isn't currently used.
function GroupInfoMixin:ReduceCdByCast(talentRank, pvpMult, duration, target)
	if type(target) == "table" then
		for targetID, reducedTime in pairs(target) do
			self:ReduceCdByCast(talentRank, pvpMult, reducedTime, targetID)
		end
	else
		local icon = self.spellIcons[target]
		if icon and icon.active then
			if type(duration) == "table" then
				duration = duration[talentRank]
			end
			if pvpMult then
				duration = pvpMult * duration
			end
			icon:UpdateCooldown(duration)
		end
	end
end]]

function GroupInfoMixin:FindIconFromCastID(spellID)
	local icon = self.spellIcons[spellID]
	if icon then
		return icon, spellID
	end
	spellID = E.spellcast_merged[spellID]
	if spellID then
		return self:FindIconFromCastID(spellID)
	end
	return nil
end

function GroupInfoMixin:AddOnCast(spellID, itemID, castID)
	castID = castID or spellID

	if not P.spell_enabled[spellID] then
		return
	end

	if itemID then
		self.sessionItemData[itemID] = true
	end

	self:SetupBar()

	return self.spellIcons[spellID]
end

function GroupInfoMixin:SetupBar(isUpdateBarsOrGRU)
	local guid, index, unit, raceID, specID, class, name, lvl = self.guid, self.index, self.unit, self.raceID, self.spec, self.class, self.name, self.level
	local isUser = guid == E.userGUID

	wipe(self.spellIcons)

	local bar = self.bar or self:GetBarFrame()
	bar:UnregisterAllEvents()
	bar:SetUnit(self, unit, index)
	bar:RefreshUnitBarFrames()

	local iconIndex = 0
	for spellID, spell in pairs(E.hash_spelldb) do
		local cat, spellType, spec, race, item, talent = spell.class, spell.type, spell.spec, spell.race, spell.item, spell.talent

		local isValidSpell
		local enabledSpell = P.spell_enabled[spellID]

		local extraBarKey, extraBarFrame
		if enabledSpell and enabledSpell > 0 then
			extraBarKey = P.extraBarKeys[enabledSpell]
			extraBarFrame = P.activeExBars[extraBarKey]
		end

		local isUserEnabled
		if isUser then
			isUserEnabled = enabledSpell and (enabledSpell > 0 and extraBarFrame.db.showPlayer or enabledSpell == 0 and not P.isUserHidden)
		end

		if not isUser and enabledSpell or isUserEnabled then
			if cat == "RACIAL" then
				if type(race) == "table" then
					for k = 1, #race do
						local id = race[k]
						if id == raceID then
							isValidSpell = true
						end
					end
				elseif race == raceID then
					isValidSpell = true
				end
			elseif specID then
				if cat == class then
					isValidSpell = self:IsSpecOrTalentForPvpStatus(spec==true and spellID or spec, lvl >= GetSpellLevelLearned(spellID))
						and (not talent or not self:IsSpecOrTalentForPvpStatus(talent, true))
				elseif not E.BOOKTYPE_CATEGORY[cat] then
					isValidSpell = self:IsEquipped(item) or self.sessionItemData[item]
				end
			else

				if cat == class then
					isValidSpell = lvl >= GetSpellLevelLearned(spellID) and (not spec or (sessionData and sessionData[spec])) and not talent
				elseif cat == "TRINKET" then
					isValidSpell = not item or self.sessionItemData[item]
				end
			end
		end

		if isValidSpell then
			local cd = self:GetValueByType(spell.duration)
			if cd and (not P.isInArena or cd < 600) then
				local buffID, iconTexture = spell.buff, spell.icon
				local baseCooldown = cd
				if specID then
					if cat == class then
						local modData = E.spell_cdmod_talents[spellID]
						if modData then
							for k = 1, #modData, 2 do
								local rank = self:IsTalentForPvpStatus(modData[k])
								if rank then
									local rt = modData[k+1]
									if type(rt) == "table" then
										rt = self:FindReducedTime(rt, specID, rank)
									end
									if rt then cd = cd - rt end
								end
							end
						end

						modData = E.spell_cdmod_by_haste[spellID]
						if modData == true or modData == specID then
							cd = cd + (self.rangedWeaponSpeed or 0)
						end

						modData = E.spell_cdmod_talents_mult[spellID]
						if modData then
							for k = 1, #modData, 2 do
								local rank = self:IsTalentForPvpStatus(modData[k])
								if rank then
									local mult = modData[k+1]
									if type(mult) == "table" then
										mult = self:FindReducedTime(mult, specID, rank, true)
									end
									if mult then cd = cd * mult end
								end
							end
						end
					elseif cat == "RACIAL" then
						local modData = E.spell_cdmod_talents[spellID]
						if modData then
							for k = 1, #modData, 2 do
								local tal = modData[k]
								local rank = self:IsTalentForPvpStatus(tal)
								if rank then
									local rt = modData[k+1]
									rt = type(rt) == "table" and (rt[rank] or rt[1]) or rt
									cd = cd - rt
								end
							end
						end
					end
				end

				local icon
				if extraBarFrame then
					icon = P.IconPool:Acquire()
					if extraBarFrame.db.unitBar then
						local unitBar = bar.activeUnitBars[enabledSpell]
						icon:SetParent(unitBar)
						icon.parent = unitBar
						unitBar.icons[#unitBar.icons + 1] = icon
					else
						icon:SetParent(extraBarFrame.container)
						icon.parent = extraBarFrame.container
					end
					extraBarFrame.numIcons = extraBarFrame.numIcons + 1
					extraBarFrame.icons[extraBarFrame.numIcons] = icon
				else
					iconIndex = iconIndex + 1
					icon = bar.icons[iconIndex]
					if not icon then
						icon = P.IconPool:Acquire()
						bar.icons[iconIndex] = icon
					end
					icon:SetParent(bar.container)
					icon.parent = bar.container
				end
				icon.name:Hide()
				icon.guid = guid
				icon.spellID = spellID
				icon.class = class
				icon.unit = unit
				icon.unitName = name
				icon.type = spellType
				icon.priority = E.db.spellPriority[spellID] or E.db.priority[spellType]
				icon.category = cat

				icon.isBookType = E.BOOKTYPE_CATEGORY[cat]
				icon.buff = buffID
				icon.duration = cd and cd < 1 and 1 or cd
				icon.baseCooldown = baseCooldown

				icon.icon:SetTexture(iconTexture)
				icon.iconTexture = iconTexture

				icon.active = nil
				icon.tooltipID = nil
				icon.modRate = self.spellModRates[spellID] or 1
				icon.glowBorder = (not extraBarFrame or extraBarFrame.db.unitBar) and E.db.highlight.glowBorder and E.db.spellGlow[spellID]
				icon.Glow:Hide()
				icon:HideOverlayGlow()

				local active = self.active[spellID]
				if active and active.startTime then
					icon.cooldown:SetCooldown(active.startTime, active.duration, active.modRate)
					icon.active = 0

					icon:SetHighlight(true)
				else
					icon.cooldown:Clear()
				end


				if self.preactiveIcons[spellID] then

					if spellID == 642 and self.talentData[146956] then
						self.preactiveIcons[spellID] = nil
					else
						self.preactiveIcons[spellID] = icon
					end
					icon:SetHighlight(true)
				end
				self.spellIcons[spellID] = icon


				if extraBarFrame and extraBarFrame.shouldShowProgressBar then
					P:GetStatusBarFrame(icon, extraBarKey, self.nameWithoutRealm)
				end
			end
		end
	end

	bar:ReleaseIcons(iconIndex)

	bar:UpdatePosition()
	bar:UpdateLayout(true)
	bar:UpdateSettings()

	if not isUpdateBarsOrGRU then
		P:UpdateExBars()
	end
end

function GroupInfoMixin:GetBarFrame()

	local bar = P.BarPool:Acquire()
	bar.guid = self.guid
	bar.class = self.class
	bar.raceID = self.raceID
	bar.info = self
	self.bar = bar
	return bar
end

function GroupInfoMixin:IsSpecOrTalentForPvpStatus(talentID, isLearnedLevel)
	if not talentID then
		return isLearnedLevel
	end
	if type(talentID) == "table" then
		for _, id in ipairs(talentID) do
			local talent = self:IsSpecOrTalentForPvpStatus(id, isLearnedLevel)
			if talent then
				return talent
			end
		end
	else
		if talentID < 0 then
			return not self.talentData[-talentID]
		end
		local talent = self.talentData[talentID]
		if talent == "PVP" then
			return 1
		end
		return talent
	end
end

function GroupInfoMixin:IsEquipped(item, item2)
	if not item then
		return true
	end
	return self.itemData[item] or self.itemData[item2]
end

function GroupInfoMixin:GetValueByType(value)
	if not value then
		return
	elseif type(value) == "table" then
		return value[self.spec] or value.default
	end
	return value
end

function GroupInfoMixin:IsTalentForPvpStatus(talentID)
	if not talentID then
		return true
	end
	local talent = self.talentData[talentID]
	if talent == "PVP" then
		return 1
	end
	return talent
end

function GroupInfoMixin:FindReducedTime(rt, specID, rank, isMult)
	local pvpMult = rt.pvp
	if rt[1] and rt[1] > 999 then
		rt = self:IsTalentForPvpStatus(rt[1]) and rt[2] or rt[3]
	end
	if type(rt) == "table" then
		rt = rt[specID] or rt[rank] or rt[1]
		if not rt then
			return
		end
		if pvpMult then
			rt = (isMult and 1 - (1 - rt) * pvpMult) or rt * pvpMult
		end
	end
	return rt
end

function GroupInfoMixin:UpdateColorScheme()
	local isDeadOrOffline = self.isDeadOrOffline
	local condition = E.db.highlight.glowBorderCondition

	for id, icon in pairs(self.spellIcons) do

		if isDeadOrOffline and icon.isHighlighted then
			icon:RemoveHighlight()
		end

		icon:SetCooldownElements()
		icon:SetOpacity()
		icon:SetColorSaturation()
		icon:SetBorderGlow(isDeadOrOffline, condition)
		if icon.statusBar then
			icon.statusBar:SetColors()
		end
	end
	P:RearrangeExBarIcons()

	if isDeadOrOffline then
		self.bar:RegisterUnitEvent("UNIT_HEALTH", self.unit)
	end
end

function GroupInfoMixin:Delete()
	local minionGUID = self.petGUID
	if minionGUID then
		CD.minionGUIDS[minionGUID] = nil
	end

	local guid = self.guid
	CM.syncedGroupMembers[guid] = nil
	CM:DequeueInspect(guid)

	self:CancelTimers()

	P.BarPool:Release(self.bar)
	P.groupInfo[guid] = nil

	if guid == E.userGUID then


		wipe(P.userInfo.active)
		wipe(P.userInfo.sessionItemData)
	end
end

function GroupInfoMixin:CancelTimers(isEncounterEnd)
	for k, timer in pairs(self.callbackTimers) do

		if not isEncounterEnd or k ~= "inCombatTicker" then
			if type(timer) == "table" then
				timer:Cancel()
			end
			self.callbackTimers[k] = nil
		end
	end
end

function GroupInfoMixin:ClearSessionItemData()
	wipe(self.sessionItemData)
end

function GroupInfoMixin:SetUnit(unit, index, ...)
	self.unit = unit
	self.index = index

	local numArguments = select("#", ...)
	if numArguments > 0 then
		local isDead, isDeadOrOffline, petGUID = ...
		self.isDead = isDead
		self.isDeadOrOffline = isDeadOrOffline
	end
end

function P:CreateUnitInfo(unit, guid, name, level, class, raceID, nameWithoutRealm)

	local info = CreateFromMixins(GroupInfoMixin)
	info.guid = guid
	info.name = name
	info.class = class
	info.level = level > 0 and level or 200
	info.raceID = raceID or select(2, UnitRace(unit))
	info.nameWithoutRealm = nameWithoutRealm or UnitName(unit)
	info.preactiveIcons = {}
	info.spellIcons = {}
	info.glowIcons = {}
	info.active = {}
	info.auras = {}
	info.itemData = {}
	info.talentData = {}
	info.callbackTimers = {}
	info.spellModRates = {}
	info.sessionItemData = {}
	return info
end

function P:GetUnitInfo(unit, guid, name, level, class)

	if self.groupInfo[guid] then
		return
	end

	local info = guid == E.userGUID and self.userInfo or self:CreateUnitInfo(unit, guid, name, level, class)
	self.groupInfo[guid] = info
	return info
end
