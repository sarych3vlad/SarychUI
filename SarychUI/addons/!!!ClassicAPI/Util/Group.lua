local _, Private = ...

local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsEnemy = UnitIsEnemy
local UnitIsPlayer = UnitIsPlayer
local NewTicker = C_Timer.NewTicker
local DemoteAssistant = DemoteAssistant
local UnitIsConnected = UnitIsConnected
local UnitIsRaidOfficer = UnitIsRaidOfficer
local GetNumRaidMembers = GetNumRaidMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local PromoteToAssistant = PromoteToAssistant
local GetNumPartyMembers = GetNumPartyMembers
local GetPartyLeaderIndex = GetPartyLeaderIndex
local GetRealNumRaidMembers = GetRealNumRaidMembers
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE

local EventHandler = Private.EventHandler
local EventHandler_Register = EventHandler.Register

function IsInGroup(LE_CATEGORY)
	if ( LE_CATEGORY and LE_CATEGORY == LE_PARTY_CATEGORY_INSTANCE ) then
		return false
	end
	return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

function IsInRaid(LE_CATEGORY)
	if ( LE_CATEGORY and LE_CATEGORY ~= LE_PARTY_CATEGORY_INSTANCE ) then
		return false
	end
	return GetNumRaidMembers() > 0
end

function GetNumSubgroupMembers()
	return GetNumPartyMembers()
end

function GetNumGroupMembers()
	local Total = GetNumRaidMembers()

	if ( Total < 1 ) then
		Total = GetNumPartyMembers()
		Total = (Total > 0) and Total+1 or 0
	end

	return Total
end

function UnitIsGroupLeader(unit)
	local isLeader

	if ( not IsInGroup() ) then
		isLeader = false
	elseif ( unit == "player" ) then
		isLeader = IsInRaid() and IsRaidLeader() or IsPartyLeader()
	else
		local index = unit:match("%d+")
		isLeader = index and GetPartyLeaderIndex() == index
	end
	
	return isLeader
end

function UnitIsGroupAssistant(unit)
	local isAssistant = false
	if ( IsInRaid() ) then
		-- UnitIsRaidOfficer return correctly also for party
		isAssistant = UnitIsRaidOfficer(unit) and not UnitIsGroupLeader(unit)
	end
	return isAssistant
end

local isAllAssistant = false
function IsEveryoneAssistant()
	return isAllAssistant
end

local assistantTicker
function SetEveryoneIsAssistant(enable)
	local numMembers = GetRealNumRaidMembers()

	if ( numMembers > 0 ) then
		if ( assistantTicker ) then
			assistantTicker:Cancel()
			assistantTicker = nil
		end

		isAllAssistant = enable
		assistantTicker = NewTicker(0.15, function(self)
			local unit = "raid"..self.index
			if ( IsEveryoneAssistant() ) then
				PromoteToAssistant(unit)
			else
				DemoteAssistant(unit)
			end
			self.index = self.index + 1
		end, numMembers)
		assistantTicker.index = 1
	end
end

function CanBeRaidTarget(unit)
	if ( not unit ) then
		return
	end

	if ( UnitExists(unit) and UnitIsConnected(unit) ) then
		return not ( UnitIsPlayer(unit) and UnitIsEnemy("player", unit) )
	end
end

function UnitInOtherParty(unit)
	if not C_Map.IsWorldMap(GetZoneText()) or UnitPhaseReason(unit) then
		return false
	end

	if not ( IsInRaid() and UnitIsConnected(unit) ) then
		return
	end

	for i = 1, GetRealNumRaidMembers() do
		local name, rank, subgroup, level, class, fileName, zone = GetRaidRosterInfo(i)
		if ( name == UnitName(unit) ) then
			return not C_Map.IsWorldMap(zone)
		end
	end
end

_G.GetDisplayedAllyFrames = Private.Void

-- Export functions globally
_G.IsInRaid = IsInRaid
_G.IsInGroup = IsInGroup
_G.GetNumSubgroupMembers = GetNumSubgroupMembers
_G.GetNumGroupMembers = GetNumGroupMembers
_G.UnitIsGroupLeader = UnitIsGroupLeader
_G.UnitIsGroupAssistant = UnitIsGroupAssistant
_G.IsEveryoneAssistant = IsEveryoneAssistant
_G.SetEveryoneIsAssistant = SetEveryoneIsAssistant
_G.CanBeRaidTarget = CanBeRaidTarget
_G.UnitInOtherParty = UnitInOtherParty

--[[
	EventHandler: GROUP_ROSTER_UPDATE / GROUP_JOINED / GROUP_LEFT
]]

EventHandler_Register("Event", "GROUP_ROSTER_UPDATE", {"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE"})
EventHandler_Register("OnEvent", "GROUP_ROSTER_UPDATE", function(_, Event)
	if ( Event == "PARTY_MEMBERS_CHANGED" and GetNumRaidMembers() > 0 ) then
		return false
	end
end)