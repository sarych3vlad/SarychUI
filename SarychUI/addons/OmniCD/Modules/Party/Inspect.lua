local E = select(2, ...):unpack()
local P, CM = E.Party, E.Comm

local pairs, type, gsub = pairs, type, gsub
local UnitIsConnected, CanInspect, CheckInteractDistance = UnitIsConnected, CanInspect, CheckInteractDistance
local GetTalentInfo, GetGlyphSocketInfo = GetTalentInfo, GetGlyphSocketInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local InspectQueueFrame = CreateFrame("Frame")
local InspectTooltip = CreateFrame("GameTooltip", "OmniCDInspectToolTip", nil, "GameTooltipTemplate")
InspectTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local LibDeflate = LibStub("LibDeflate")
local INSPECT_INTERVAL = 2
local INSPECT_TIMEOUT = 300
local queriedGUID

local inspectOrderList = {}
local queueEntries = {}
local staleEntries = {}

CM.SERIALIZATION_VERSION = 6
CM.ACECOMM = LibStub("AceComm-3.0"):Embed(CM)

function CM:Enable()
	if self.isEnabled then
		return
	end

	self.AddonPrefix = E.AddOn
	self:RegisterComm(self.AddonPrefix, "CHAT_MSG_ADDON")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("PLAYER_TALENT_UPDATE")
	self:SetScript("OnEvent", function(self, event, ...)
		self[event](self, ...)
	end)

	self:InitInspect()
	self.isEnabled = true
end

function CM:Disable()
	if not self.isEnabled then
		return
	end
	self:UnregisterAllEvents()
	self:DisableInspect()
	self:DesyncUserFromGroup()
	self.isEnabled = false
end

local timeSinceUpdate = 0

local function InspectQueueFrame_OnUpdate(_, elapsed)
	timeSinceUpdate = timeSinceUpdate + elapsed


	if timeSinceUpdate > INSPECT_INTERVAL then
		CM:RequestInspect()
		timeSinceUpdate = 0
	end
end

function CM:InitInspect()
	if self.initInspect then
		return
	end
	InspectQueueFrame:Hide()
	InspectQueueFrame:SetScript("OnUpdate", InspectQueueFrame_OnUpdate)
	self.initInspect = true
end

function CM:EnableInspect()
	if self.enabledInspect or #inspectOrderList == 0 then
		return
	end
	InspectQueueFrame:Show()
	self:RegisterEvent("INSPECT_READY")
	self.enabledInspect = true
end

function CM:DisableInspect()
	if not self.enabledInspect then
		return
	end
	ClearInspectPlayer()
	InspectQueueFrame:Hide()
	self:UnregisterEvent("INSPECT_READY")

	wipe(inspectOrderList)
	wipe(queueEntries)
	wipe(staleEntries)
	queriedGUID = nil
	self.enabledInspect = false
end

local function PendingInspect(guid)
	return queueEntries[guid] or staleEntries[guid]
end

function CM:AddToInspectList(guid)
	if not PendingInspect(guid) then
		inspectOrderList[#inspectOrderList + 1] = guid
	end
end

function CM:AddToInspectListAndQueue(guid, addedTime)
	if guid == E.userGUID then
		self:InspectUser()
	elseif not PendingInspect(guid) then
		queueEntries[guid] = addedTime
		inspectOrderList[#inspectOrderList + 1] = guid
	end
end

function CM:EnqueueInspect(force, guid)
	local addedTime = GetTime()
	if force then
		for infoGUID in pairs(P.groupInfo) do
			self:AddToInspectListAndQueue(infoGUID, addedTime)
		end
	elseif guid then
		self:AddToInspectListAndQueue(guid, addedTime)
	else
		local n = #inspectOrderList
		if n == 0 then
			return
		end
		for i = 1, n do
			local listGUID = inspectOrderList[i]
			if not PendingInspect(guid) then
				queueEntries[listGUID] = addedTime
			end
		end
	end

	self:EnableInspect()
end

function CM:DequeueInspect(guid, moveToStale)
	if queriedGUID == guid then
		ClearInspectPlayer()
		queriedGUID = nil
	end

	if moveToStale then
		staleEntries[guid] = queueEntries[guid]
	else
		for i = #inspectOrderList, 1, -1 do
			local listGUID = inspectOrderList[i]
			if guid == listGUID then
				tremove(inspectOrderList, i)
			end
		end
	end
	queueEntries[guid] = nil
end

function CM:RequestInspect()
	if UnitIsDead("player") or InspectFrame and InspectFrame:IsShown() then
		return
	end

	if #inspectOrderList == 0 then
		self:DisableInspect()
		return
	end


	if queriedGUID then
		ClearInspectPlayer()
		staleEntries[queriedGUID] = queueEntries[queriedGUID]
		queueEntries[queriedGUID] = nil
		queriedGUID = nil
	end

	if next(queueEntries) == nil and next(staleEntries) then
		local copy = queueEntries
		queueEntries = staleEntries
		staleEntries = copy
	end

	local now = GetTime()
	local inCombat = InCombatLockdown()

	for i = 1, #inspectOrderList do
		local guid = inspectOrderList[i]
		local addedTime = queueEntries[guid]
		if addedTime then
			local info = P.groupInfo[guid]
			local unitIsSynced = self.syncedGroupMembers[guid]
			if guid == E.userGUID then
				self:InspectUser()
				self:DequeueInspect(guid)
			elseif info and not unitIsSynced then
				local unit = info.unit
				local elapsed = now - addedTime
				if not UnitIsConnected(unit) or elapsed > INSPECT_TIMEOUT then
					self:DequeueInspect(guid)
				elseif (inCombat or not CheckInteractDistance(unit,1))


					or not CanInspect(unit) then

					staleEntries[guid] = addedTime
					queueEntries[guid] = nil
				else
					queriedGUID = guid
					NotifyInspect(unit)
					return
				end
			else
				self:DequeueInspect(guid)
			end
		end
	end
end

function CM:INSPECT_READY(guid)
	if queriedGUID == guid then
		self:InspectUnit(guid)
	end
end

local INVSLOT_INDEX = {
	INVSLOT_HEAD,
	INVSLOT_NECK,
	INVSLOT_SHOULDER,

	INVSLOT_CHEST,
	INVSLOT_WAIST,
	INVSLOT_LEGS,
	INVSLOT_FEET,
	INVSLOT_WRIST,
	INVSLOT_HAND,
	INVSLOT_FINGER1,
	INVSLOT_FINGER2,
	INVSLOT_TRINKET1,
	INVSLOT_TRINKET2,
	INVSLOT_BACK,
	INVSLOT_MAINHAND,
	INVSLOT_OFFHAND,
}

local NUM_INVSLOTS = #INVSLOT_INDEX

local function GetTooltipLineData(i)
	local lineData
	lineData = _G["OmniCDInspectToolTipTextLeft" .. i]
	return lineData, lineData:GetText()
end

local S_ITEM_SET_NAME = "^" .. ITEM_SET_NAME:gsub("([%(%)])", "%%%1"):gsub("%%%d?$?d", "(%%d+)"):gsub("%%%d?$?s", "(.+)") .. "$"

local function FindSetBonus(info, specBonus, list)
	local bonusID, numRequired = specBonus[1], specBonus[2]
	local numLines = InspectTooltip:NumLines()
	for j = 10, numLines do
		local _, text = GetTooltipLineData(j)
		if text and text ~= "" then
			local name, numEquipped, numFullSet = strmatch(text, S_ITEM_SET_NAME)
			if name and numEquipped and numFullSet then
				numEquipped = tonumber(numEquipped)
				if numEquipped and numEquipped >= numRequired then
					info.talentData[bonusID] = "S"
					if list then list[#list + 1] = bonusID .. ":S" end

					local bonusID2 = specBonus[3]
					if bonusID2 and numEquipped >= specBonus[4] then
						info.talentData[bonusID2] = "S"
						if list then list[#list + 1] = bonusID2 .. ":S" end
					end
				end
				return bonusID
			end
		end
	end
end

local function GetEquippedItemData(info, unit, specID, list)
	local moveToStale
	local numTierSetBonus = 0
	local foundTierSpecBonus
	local e
	if list then list[#list + 1] = "^M"; e = { "^E" }; end

	for i = 1, NUM_INVSLOTS do
		local slotID = INVSLOT_INDEX[i]
		local itemLink = GetInventoryItemLink(unit, slotID)
		if itemLink then
			local itemID, _,_,_,_,_, subclassID = GetItemInfoInstant(itemLink)
			if itemID then
				if i < 10 then
					local tierSetBonus = E.item_set_bonus[itemID]
					local equipBonusID = E.item_equip_bonus[itemID]
					subclassID = subclassID == 0 and 1 or subclassID
					InspectTooltip:SetInventoryItem(unit, slotID)

					if equipBonusID then
						info.talentData[equipBonusID] = true
						if list then list[#list + 1] = equipBonusID .. ":S" end
					end
					if tierSetBonus then
						local specBonus = tierSetBonus
						if specBonus and numTierSetBonus < 2 and specBonus[1] ~= foundTierSpecBonus then
							foundTierSpecBonus = FindSetBonus(info, specBonus, list)
							if foundTierSpecBonus then
								numTierSetBonus = numTierSetBonus + 1
							end
						end
					end
					if InspectTooltip then
						InspectTooltip:ClearLines()
					end
				end
				itemID = E.item_merged[itemID] or itemID
				info.itemData[itemID] = true
				if e then e[#e + 1] = itemID end
			elseif not moveToStale then
				moveToStale = true
			end
		end
	end
	if e then
		list[#list + 1] = table.concat(e, ",")
		e = nil
	end

	return moveToStale
end

local MAX_NUM_TALENTS = E.isWOTLKC and 31 or 25

local GetSelectedTalentData = function(info, unit, isInspect)
	local list
	if not isInspect then
		list = { CM.SERIALIZATION_VERSION, info.spec, "^T" }
	end

	local talentGroup = GetActiveTalentGroup and GetActiveTalentGroup(isInspect, nil)

	if list and E.isWOTLKC then
		for i = 1, 6 do
			local _,_, glyphSpellID = GetGlyphSocketInfo(i, talentGroup)
			if glyphSpellID then
				info.talentData[glyphSpellID] = true
				list[#list + 1] = glyphSpellID
			end
		end
	end

	for tabIndex = 1, 3 do
		for talentIndex = 1, MAX_NUM_TALENTS do
			local name, _,_,_, currentRank = GetTalentInfo(tabIndex, talentIndex, isInspect, unit, talentGroup)
			if not name then
				break
			end
			if currentRank > 0 then
				local talentRankIDs = E.talentNameToRankIDs[name]
				if talentRankIDs then
					if type(talentRankIDs[1]) == "table" then
						for _, t in pairs(talentRankIDs) do
							local talentID = t[currentRank]
							if talentID then
								info.talentData[talentID] = true
								if list then list[#list + 1] = talentID end
							end
						end
					else
						local talentID = talentRankIDs[currentRank]
						if talentID then
							info.talentData[talentID] = true
							if list then list[#list + 1] = talentID end
						end
					end
				end
			end
		end
	end

	return list
end

function CM:InspectUnit(guid)
	local info = P.groupInfo[guid]


	if not info or self.syncedGroupMembers[guid] then
		self:DequeueInspect(guid)
		return
	end

	local unit = info.unit
	local specID = info.raceID


	if not specID then
		return
	end

	info.spec = specID
	if info.name == "" or info.name == UNKNOWN then
		info.name = GetUnitName(unit, true)
		info.nameWithoutRealm = UnitName(unit)
	end
	if info.level == 200 then
		local lvl = UnitLevel(unit)
		if lvl > 0 then
			info.level = lvl
		end
	end

	wipe(info.talentData)
	wipe(info.itemData)

	GetSelectedTalentData(info, unit, true)
	local failed = GetEquippedItemData(info, unit, specID)

	self:DequeueInspect(guid, failed)
	info:SetupBar()
end

function CM:InspectUser()
	local info = P.userInfo
	local specID = info.raceID

	if not specID then
		return false
	end
	info.spec = specID

	wipe(info.talentData)
	wipe(info.itemData)

	local dataList = GetSelectedTalentData(info, "player")
	GetEquippedItemData(info, "player", specID, dataList)

	if E.isClassic or E.isBCC then
		local speed = UnitRangedDamage("player")
		if speed and speed > 0 then
			info.rangedWeaponSpeed = speed
			dataList[#dataList + 1] = -speed
		end
	end

	local serializedData = table.concat(dataList, ","):gsub(",%^", "^")
	local compressedData = LibDeflate:CompressDeflate(serializedData)
	local encodedData = LibDeflate:EncodeForWoWAddonChannel(compressedData)
	self.serializedSyncData = encodedData


	if P.groupInfo[info.guid] then
		info:SetupBar()
	end

	return true
end
