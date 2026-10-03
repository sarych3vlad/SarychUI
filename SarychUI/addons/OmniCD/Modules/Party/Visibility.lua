local E = select(2, ...):unpack()
local P, CM, CD = E.Party, E.Comm, E.Cooldowns

local groupInfo = {}
local callbackTimers = {}

local GROUP_ROSTER_SIZE

local UPDATE_ROSTER_DELAY = 2
local MSG_INFO_REQUEST_DELAY = 3

local RAID_UNIT = {
	"raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7", "raid8", "raid9", "raid10",
	"raid11", "raid12", "raid13", "raid14", "raid15", "raid16", "raid17", "raid18", "raid19", "raid20",
	"raid21", "raid22", "raid23", "raid24", "raid25", "raid26", "raid27", "raid28", "raid29", "raid30",
	"raid31", "raid32", "raid33", "raid34", "raid35", "raid36", "raid37", "raid38", "raid39", "raid40",
}

local PARTY_UNIT = {
	"party1", "party2", "party3", "party4", "player"
}

function P:RegisterZoneEvents()
	if self.eventZone == self.zone then
		return
	end

	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self.eventZone = self.zone
end

function P:UnregisterZoneEvents()
	if not self.eventZone then
		return
	end

	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	self.eventZone = nil
end

local function InspectAllGroupMembers()
	CM:EnqueueInspect(true)
end

local function IsExtraBarDisabled()
	for key, db in pairs(E.db.extraBars) do
		if db.enabled and db.showPlayer then
			return false
		end
	end
	return true
end

local function GetRosterInfo(i, unit)
	local _, name, subgroup, level, fileName, online, isDead
	if unit == true then
		name, _, subgroup, level, _, fileName, _, online, isDead = GetRaidRosterInfo(i)
	else
		name = GetUnitName(unit, true)
		level = UnitLevel(unit)
		_, fileName = UnitClass(unit)
		online = UnitIsConnected(unit)
		isDead = UnitIsDeadOrGhost(unit)
	end
	return name, subgroup, level, fileName, online, isDead
end

local function RequestSync_OnDelayEnd()
	local success = CM:InspectUser()
	if success then
		CM:RequestSync()
		callbackTimers.syncDelay = nil
	else
		callbackTimers.syncDelay = C_Timer.NewTimer(2, RequestSync_OnDelayEnd)
	end
end

local function ScheduleSyncRequest()
	if callbackTimers.syncDelay then
		callbackTimers.syncDelay:Cancel()
	end
	callbackTimers.syncDelay = C_Timer.NewTimer(MSG_INFO_REQUEST_DELAY, RequestSync_OnDelayEnd)
end

local function UpdateAnchor_OnDelayEnd()
	P:UpdatePosition()
	callbackTimers.anchorBackup = nil
end

local function ScheduleAnchorUpdate()
	if callbackTimers.anchorBackup then
		callbackTimers.anchorBackup:Cancel()
	end
	callbackTimers.anchorBackup = C_Timer.NewTicker(3, UpdateAnchor_OnDelayEnd, 2)
end

local function ScheduleRosterUpdate()
	if callbackTimers.rosterDelay then
		callbackTimers.rosterDelay:Cancel()
	end
	callbackTimers.rosterDelay = C_Timer.NewTimer(UPDATE_ROSTER_DELAY, P.UpdateRosterInfo)
end

function P:ZONE_CHANGED_NEW_AREA(isRefresh)
	local _, instanceType = IsInInstance()

	local wasDisabled = self.disabledZone
	self.disabledZone = not self.isInTestMode and not E.profile.Party.visibility[instanceType]

	if isRefresh and not self.zone and not wasDisabled then
		return
	end

	if self.disabledZone then
		if not wasDisabled then
			self:ResetModule(true)
		end
		return
	end

	if not isRefresh and self.isInTestMode then
		self:Test()
		return
	end

	E.db = E:GetCurrentZoneSettings(self.isInTestMode and self.testZone or instanceType)
	self.isUserHidden = not self.isInTestMode and not E.db.general.showPlayer
	self.isUserDisabled = self.isUserHidden and IsExtraBarDisabled()
	self.isHighlightEnabled = E.db.highlight.glowBuffs
	self.zone = instanceType
	self.isInArena = instanceType == "arena"
	self.isInPvPInstance = self.isInArena or instanceType == "pvp"
	self.effectivePixelMult = nil

	self:RegisterZoneEvents()
	self:UpdateEnabledSpells()
	self:UpdatePositionValues()

	if self.isInPvPInstance then
		self:ResetAllIcons("joinedPvP")
	end

	if self.isInArena then
		if not callbackTimers.arenaTicker then
			callbackTimers.arenaTicker = C_Timer.NewTicker(12, InspectAllGroupMembers, 6)
		end
	else
		if callbackTimers.arenaTicker then
			callbackTimers.arenaTicker:Cancel()
			callbackTimers.arenaTicker = nil
		end
	end
	self:RefreshExBarFrames()

	if isRefresh or (not self.UpdateRosterInfoQueued and not callbackTimers.rosterDelay) then
		if not GROUP_ROSTER_SIZE and not self.isInTestMode then
			self.UpdateRosterInfoQueued = true
			C_Timer.After(.4, function()
				self:GROUP_ROSTER_UPDATE(true)
				self.UpdateRosterInfoQueued = nil
			end)
		else
			self:GROUP_ROSTER_UPDATE(true)
		end
	end
end

function P:PLAYER_ENTERING_WORLD()
	self:ZONE_CHANGED_NEW_AREA()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function P:UpdateRosterInfo(force, clearSession)
	local size = GROUP_ROSTER_SIZE
	local isInRaid = IsInRaid()

	local wasDisabled = P.disabled
	P.disabled = not P.isInTestMode and (
		size == 0 and not P.isInArena or
		size == 1 and P.isUserDisabled and not P.isInArena or
		not E.profile.Party.visibility.finder and ((P.isInArena and not select(2, IsActiveBattlefieldArena())) or IsPartyLFG()) or
		size > E.profile.Party.groupSize[P.zone] or
		isInRaid and not E.profile.Party.raidGroup[P.zone]
	)

	if P.disabled then
		if not wasDisabled then
			P:ResetModule()
		end
		return
	elseif wasDisabled then
		P:RefreshExBarFrames()
	end

	CM:Enable()
	CD:Enable()

	local isCallback = P ~= self
	local isReadyForSync = isCallback and P.groupJoined

	for guid, info in pairs(groupInfo) do
		if not UnitExists(info.name) then
			if P.isInArena then
				info.bar:Hide()
			else
				info:Delete()
			end
		elseif clearSession then
			info:ClearSessionItemData()
		end
	end

	for i = 1, size do
		local index = not isInRaid and i == size and 5 or i
		local unit = isInRaid and RAID_UNIT[index] or PARTY_UNIT[index]
		local guid = UnitGUID(unit)
		local info = groupInfo[guid]
		local name, subgroup, level, fileName, online, isDead = GetRosterInfo(i, isInRaid or unit)
		local isDeadOrOffline = isDead or not online

		if info and not isCallback then
			if force then
				info:SetUnit(unit, index, isDead, isDeadOrOffline)
				info:SetupBar(true)
				CM:AddToInspectList(guid)
			else
				if info.unit ~= unit then
					info:SetUnit(unit, index)
					info.bar:UnregisterAllEvents()
					info.bar:SetUnit(info, unit, index)
					info.bar:UpdatePosition()
				end

				if not info.spec then
					CM:AddToInspectList(guid)
				end

				if info.isDeadOrOffline ~= isDeadOrOffline then
					if not online then
						CM.syncedGroupMembers[guid] = nil
					end
					info.isDead = isDead
					info.isDeadOrOffline = isDeadOrOffline
					info:UpdateColorScheme()
				end
			end
		elseif not info and (isCallback or force) then
			if fileName then
				local petGUID = (fileName == "WARLOCK" or fileName == "HUNTER" or fileName == "DEATHKNIGHT")
					and E.UNIT_TO_PET[unit]
				if petGUID then
					petGUID = UnitGUID(petGUID)
					if petGUID then
						CD.minionGUIDS[petGUID] = guid
					end
				end

				info = P:GetUnitInfo(unit, guid, name, level, fileName)
				info:SetUnit(unit, index, isDead, isDeadOrOffline)
				info.petGUID = petGUID
				info:SetupBar(true)
				CM:AddToInspectList(guid)
			else
				ScheduleRosterUpdate()
				isReadyForSync = false
			end
		end
	end

	if P.groupUpdate or force or isCallback or clearSession then
		P:UpdateExBars()
		CM:EnqueueInspect()

		if force or isReadyForSync then
			if isReadyForSync then
				P.groupJoined = nil
			end
			ScheduleSyncRequest()
		end

		if isCallback then
			callbackTimers.rosterDelay = nil
		else
			ScheduleAnchorUpdate()

			if not callbackTimers.rosterDelay then
				ScheduleRosterUpdate()
			end
		end

		P.groupUpdate = nil
	end
end

local function GROUP_ROSTER_UPDATE_BUCKET()
	P.UpdateRosterInfoQueued = nil
	if P.eventZone then
		P:UpdateRosterInfo()
	end
end

function P:GROUP_ROSTER_UPDATE(isPEWOrRefresh)
	local GROUP_ROSTER_SIZE_LAST = GROUP_ROSTER_SIZE or 0
	GROUP_ROSTER_SIZE = self:GetEffectiveNumGroupMembers()

	if isPEWOrRefresh or GROUP_ROSTER_SIZE < GROUP_ROSTER_SIZE_LAST then
		self:UpdateRosterInfo(isPEWOrRefresh)
	elseif not self.UpdateRosterInfoQueued then
		if GROUP_ROSTER_SIZE ~= GROUP_ROSTER_SIZE_LAST then
			if GROUP_ROSTER_SIZE_LAST == 0 and GROUP_ROSTER_SIZE > 0 then
				self.groupJoined = true
			end
			self.groupUpdate = true
		end
		self.UpdateRosterInfoQueued = true
		C_Timer.After(.4, GROUP_ROSTER_UPDATE_BUCKET)
	end
end

P.groupInfo = groupInfo
P.callbackTimers = callbackTimers
