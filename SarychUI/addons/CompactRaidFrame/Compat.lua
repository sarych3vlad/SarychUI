local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local UnitExists = UnitExists
local GetInstanceInfo = GetInstanceInfo
local InCombatLockdown = InCombatLockdown
local UnitFrame_Initialize = UnitFrame_Initialize
local PartyMemberBackground = PartyMemberBackground
local PartyMemberFrame_OnLoad = PartyMemberFrame_OnLoad
local SecureUnitButton_OnLoad = SecureUnitButton_OnLoad

local PARTY_FRAME_DISABLED
local PARTY_FRAME_DISPLAY = "party"

function GetDisplayedAllyFrames()
	local UseCompact = CUF_CVar:GetCVarBool("useCompactPartyFrames")
	local _, InstanceType = GetInstanceInfo()

	if ( not UseCompact and InstanceType == "arena" ) then
		return "party"
	end

	if ( IsInGroup() ) then
		if ( UseCompact or IsInRaid() ) then
			return "raid"
		end
		return "party"
	end

	return nil
end

function RaidOptionsFrame_UpdatePartyFrames()
	if ( InCombatLockdown() ) then return end

	local DisplayState = GetDisplayedAllyFrames()
	if ( not DisplayState or PARTY_FRAME_DISPLAY == DisplayState ) then return end

	local IsDisplayRaid = (DisplayState == "raid")
	local UseCompact = CUF_CVar:GetCVarBool("useCompactPartyFrames")

	PartyMemberBackground:SetAlpha(IsDisplayRaid and 0 or 1)

	if ( IsDisplayRaid and UseCompact ) then
		if ( not PARTY_FRAME_DISABLED ) then
			for i = 1, 4 do
				local PartyFrame = _G["PartyMemberFrame"..i]
				PartyFrame:UnregisterAllEvents()
				PartyFrame.healthbar:UnregisterAllEvents()
				PartyFrame.manabar:UnregisterAllEvents()
				PartyFrame:Hide()

				local PartyFramePet = _G["PartyMemberFrame"..i.."PetFrame"]
				PartyFramePet:UnregisterAllEvents()
				PartyFramePet.healthbar:UnregisterAllEvents()
			end

			PARTY_FRAME_DISABLED = true
		end
	else
		for i = 1, 4 do
			local PartyFrame = _G["PartyMemberFrame"..i]
			local PartyFramePet = _G["PartyMemberFrame"..i.."PetFrame"]

			if ( IsDisplayRaid ) then
				PartyFrame:SetAlpha(0)
				PartyFrame:Hide()
				PartyFrame:UnregisterAllEvents()
			else
				if ( PARTY_FRAME_DISABLED ) then
					UnitFrame_Initialize(PartyFrame, PartyFrame.unit, PartyFrame.name, PartyFrame.portrait, PartyFrame.healthbar, PartyFrame.healthbar.TextString, PartyFrame.manabar, PartyFrame.manabar.TextString, PartyFrame.threatIndicator)
					UnitFrame_Initialize(PartyFramePet, PartyFramePet.unit, PartyFramePet.name, PartyFramePet.portrait, PartyFramePet.healthbar, PartyFramePet.healthbar.TextString, nil, nil, PartyFramePet.threatIndicator)
					SecureUnitButton_OnLoad(PartyFramePet, PartyFramePet.unit)
				end

				PartyMemberFrame_OnLoad(PartyFrame)
				PartyFrame:SetAlpha(1)
			end
		end

		PARTY_FRAME_DISABLED = nil
	end

	PARTY_FRAME_DISPLAY = DisplayState
end