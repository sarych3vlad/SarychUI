local E = select(2, ...):unpack()
local P, CM = E.Party, E.Comm

local pairs, tonumber, abs, floor, format, gsub, strmatch, strsplit = pairs, tonumber, abs, floor, format, gsub, strmatch, strsplit
local GetTime = GetTime

local LibDeflate = LibStub("LibDeflate")
local COOLDOWN_SYNC_INTERVAL = 2
local MSG_DESYNC = "DESYNC"
local MSG_INFO_REQUEST = "REQ"
local MSG_INFO_UPDATE = "UPD"
local NULL = ""

CM.syncedGroupMembers = {}
CM.serializedSyncData = NULL

function CM:SendComm(...)
	local message = strjoin(",", ...)
	if IsInRaid() then
		self:SendCommMessage(self.AddonPrefix, message, (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "RAID")
	elseif IsInGroup() then
		self:SendCommMessage(self.AddonPrefix, message, (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY")
	end
end

function CM:RequestSync()
	self:SendComm(MSG_INFO_REQUEST, E.userGUID, self.serializedSyncData)
end

function CM:SendUserSyncData(sender)
	if self.serializedSyncData == NULL then
		self:InspectUser()
	end
	self:SendComm(sender or MSG_INFO_UPDATE, E.userGUID, self.serializedSyncData)
end

function CM:DesyncUserFromGroup()
	wipe(self.syncedGroupMembers)
	self:SendComm(MSG_DESYNC, E.userGUID, 1)
end

function CM:IsVersionIncompatible(serializationVersion)
	return serializationVersion ~= self.SERIALIZATION_VERSION
end

local aceUserNameFix = CM.ACECOMM and E.userName or gsub(E.userNameWithRealm, " ", "")

function CM:CHAT_MSG_ADDON(prefix, message, _, sender)
	if prefix ~= self.AddonPrefix or sender == aceUserNameFix then
		return
	end

	local header, guid, body = strmatch(message, "(.-),(.-),(.+)")
	local info = P.groupInfo[guid]
	if not info then
		return
	end

	local unitIsSynced = self.syncedGroupMembers[guid]
	if header == MSG_INFO_REQUEST then
		self:SendUserSyncData(guid)
	elseif header == MSG_INFO_UPDATE then
		if not unitIsSynced then
			return
		end
	elseif header == MSG_DESYNC then
		if unitIsSynced then
			self.syncedGroupMembers[guid] = nil
		end
		return
	elseif header ~= E.userGUID then
		return
	end

	local decodedData = LibDeflate:DecodeForWoWAddonChannel(body)
	if not decodedData then
		error("Error decoding sync message from " .. info.name)
	end

	local decompressedData = LibDeflate:DecompressDeflate(decodedData)
	if not decompressedData then
		error("Error decompressing sync message from " .. info.name)
	end

	while ( decompressedData ) do
		local t, rest = strsplit("^", decompressedData, 2)
		decompressedData = rest

		local k, v = strsplit(",", t, 2)
		if ( k == "T" ) then
			while ( v ) do
				local id, idlist = strsplit(",", v, 2)
				v = idlist
				local spellID, rank = strsplit(":", id)
				spellID = tonumber(spellID)
				if ( spellID ) then
					if ( spellID > 0 ) then
						info.talentData[spellID] = tonumber(rank) or 1
					else
						info.talentData[-spellID] = "PVP"
					end
				end
			end
		elseif ( k == "M" ) then
			while ( v ) do
				local id, idlist = strsplit(",", v, 2)
				v = idlist
				local key, src = strsplit(":", id)
				local spellID = tonumber(key)
				local value = tonumber(src) or src or true
				if ( not spellID ) then
					info.talentData[key] = value
				elseif ( spellID > 0 ) then
					info.talentData[spellID] = value
				else
					info.talentData[-spellID] = value
				end
			end
		elseif ( k == "E" ) then
			while ( v ) do
				local id, idlist = strsplit(",", v, 2)
				v = idlist
				id = tonumber(id)
				if ( id ) then
					if ( id > 0 ) then
						info.itemData[id] = true
					else
						info.rangedWeaponSpeed = -id
					end
				end
			end
		elseif ( k == "C" ) then
			-- Tsoukie: REMOVED
		else
			k = tonumber(k)
			if ( not k or self:IsVersionIncompatible(k) ) then
				return
			end
			info.spec = v
			wipe(info.talentData)
			wipe(info.itemData)
		end
	end

	local unit = info.unit
	if info.name == "" or info.name == "Unknown" then
		info.name = GetUnitName(unit, true)
	end
	if info.level == 200 then
		local lvl = UnitLevel(unit)
		if lvl > 0 then
			info.level = lvl
		end
	end

	self.syncedGroupMembers[guid] = true
	self:DequeueInspect(guid)
	info:SetupBar()
end

local function SendUpdatedUserSyncData()
	CM:InspectUser()
	CM:SendUserSyncData()
end

local equipmentTimer

local SendUpdatedUserSyncData_OnTimerEnd = function()
	SendUpdatedUserSyncData()
	equipmentTimer = nil
end

function CM:PLAYER_EQUIPMENT_CHANGED(equipmentSlot)
	if not equipmentTimer and equipmentSlot < 18 then
		equipmentTimer = C_Timer.NewTicker(0.1, SendUpdatedUserSyncData_OnTimerEnd, 1)
	end
end

CM.PLAYER_TALENT_UPDATE = SendUpdatedUserSyncData
CM.PLAYER_LEAVING_WORLD = CM.DesyncUserFromGroup
