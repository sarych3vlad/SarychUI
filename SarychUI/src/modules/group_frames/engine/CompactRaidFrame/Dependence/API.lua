local CompatMath = select(2, ...).Compat.Math
local CalculateDistance = CompatMath.CalculateDistance
local SuiTimer = select(2, ...).Compat.Timer
local UnitName					= UnitName;
local UnitGUID					= UnitGUID;
local UnitIsUnit				= UnitIsUnit;
local UnitExists				= UnitExists;
local UnitIsEnemy				= UnitIsEnemy
local GetSpellInfo				= GetSpellInfo;
local UnitIsPlayer				= UnitIsPlayer;
local UnitIsConnected			= UnitIsConnected;
local DemoteAssistant			= DemoteAssistant;
local SendChatMessage			= SendChatMessage;
local GetRaidRosterInfo			= GetRaidRosterInfo;
local GetNumRaidMembers			= GetNumRaidMembers;
local PromoteToAssistant		= PromoteToAssistant;
local GetNumPartyMembers		= GetNumPartyMembers;
local GetPartyLeaderIndex		= GetPartyLeaderIndex;
local GetPlayerMapPosition		= GetPlayerMapPosition;
local GetRealNumRaidMembers		= GetRealNumRaidMembers;
local IsActiveBattlefieldArena	= IsActiveBattlefieldArena;

local MAX_RAID_MEMBERS = MAX_RAID_MEMBERS;

SarychUI.Compat.SOUNDKIT = SarychUI.Compat.SOUNDKIT or {};
SarychUI.Compat.SOUNDKIT.IG_MAINMENU_OPTION 			= "Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\Sounds\\SOUNDKIT\\852.ogg";
SarychUI.Compat.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON = "Interface\\AddOns\\SarychUI\\media\\components\\modules\\group_frames\\engine\\CompactRaidFrame\\Media\\Sounds\\SOUNDKIT\\856.ogg";

hooksecurefunc("BlizzardOptionsPanel_OnEvent", function(self, event, ...)
    if ( self:GetName() == "CompactUnitFrameProfiles" ) then
        CompactUnitFrameProfiles_OnEvent(self, event, ...);
    end
end)

function SarychUI.Compat.IsRaidMarkerActive(index)
    return false;
end

function SarychUI.Compat.PassClickToParent(self, ...)
    self:GetParent():Click(...);
end

function SarychUI.Compat.ApplyCoordFix(v, default)
    return ( v > 10001 or v < -10001 ) and ( default or 1 ) or v;
end

function SarychUI.Compat.GetDisplayedAllyFrames()
    if CompactRaidFrameEnabled == false then return nil end
    local testModule = SarychUI and SarychUI.modules and SarychUI.modules.group_frames;
    local useCompact = CUF_CVar:GetCVarBool("useCompactPartyFrames");
    if testModule and testModule.testCount and useCompact then return "raid"; end
    if ( IsActiveBattlefieldArena() and not useCompact ) then
        return "party";
    elseif ( SarychUI.Compat.IsInGroup() and ( SarychUI.Compat.IsInRaid() or useCompact ) ) then
        return "raid";
    elseif ( SarychUI.Compat.IsInGroup() ) then
        return "party";
    else
        return nil;
    end
end

function SarychUI.Compat.UnitIsGroupLeader(unit)
    if not unit or not UnitExists(unit) or not SarychUI.Compat.IsInGroup() then return false end
    if SarychUI.Compat.IsInRaid() then
        for i = 1, GetNumRaidMembers() do
            if UnitIsUnit(unit, "raid"..i) then
                local _, rank = GetRaidRosterInfo(i)
                return rank == 2
            end
        end
        return false
    end
    if UnitIsUnit(unit, "player") then return not not IsPartyLeader() end
    local index = GetPartyLeaderIndex()
    return index and index > 0 and not not UnitIsUnit(unit, "party"..index) or false
end

function SarychUI.Compat.UnitIsGroupAssistant(unit)
    local isAssistant = false;
    if ( not SarychUI.Compat.IsInRaid() ) then
        isAssistant = false;
    else
        -- UnitIsRaidOfficer return correctly also for party
        isAssistant = UnitIsRaidOfficer(unit) and not SarychUI.Compat.UnitIsGroupLeader(unit);
    end
    return isAssistant;
end

-- Legacy CUF map-coordinate estimate, NOT squared yards. Retains the existing
-- icon threshold; do not use it for spell range or change the selected map.
local mapSnapshot = {}
local function InvalidateMapSnapshot()
    mapSnapshot.time = nil
end
local mapSnapshotEvents = CreateFrame("Frame")
mapSnapshotEvents:RegisterEvent("WORLD_MAP_UPDATE")
mapSnapshotEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
mapSnapshotEvents:SetScript("OnEvent", InvalidateMapSnapshot)
-- Invalidate synchronously when addons change map selection between unit updates.
-- These hooks never select a map themselves.
if hooksecurefunc then
    for _, name in ipairs({"SetMapToCurrentZone", "SetMapZoom", "SetDungeonMapLevel", "SetMapByID"}) do
        if type(_G[name]) == "function" then hooksecurefunc(name, InvalidateMapSnapshot) end
    end
end
local function PlayerMapPositionForTick()
    local now = GetTime()
    if mapSnapshot.time ~= now then
        mapSnapshot.x, mapSnapshot.y = GetPlayerMapPosition("player")
        mapSnapshot.time = now
    end
    return mapSnapshot.x, mapSnapshot.y
end

function SarychUI.Compat.GetMapDistanceEstimate(unit, sharedTick)
    if ( UnitIsConnected(unit) ) then
        local px, py
        if sharedTick then px, py = PlayerMapPositionForTick()
        else px, py = GetPlayerMapPosition("player") end
        local ux, uy = GetPlayerMapPosition(unit);
        if (px == 0 and py == 0) or (ux == 0 and uy == 0) then return 0, false end
        return CalculateDistance(px, py, ux, uy) * 100000, true;
    end
    return 0, false;
end

function SarychUI.Compat.CanBeRaidTarget(unit)
    if ( not unit ) then
        return;
    end

    if ( UnitExists(unit) and UnitIsConnected(unit) ) then
        return not ( UnitIsPlayer(unit) and UnitIsEnemy("player", unit) );
    end
end

local MAX_BATTLEGOUND_UNIT = {
    AlteracValley 		= 40,
    ArathiBasin 		= 15,
    NetherstormArena 	= 15,
    WarsongGulch 		= 10,
    IsleofConquest 		= 40,
    StrandoftheAncients = 15,
    LakeWintergrasp 	= 40,
};

local CrossLocation = {
    ["Кратер Азшары"] = true,
};

SarychUI.Compat.C_PvP = SarychUI.Compat.C_PvP or {};
function SarychUI.Compat.C_PvP.IsPvPMap()
    local inInstance, instanceType = IsInInstance();
    if ( not inInstance ) then
        return;
    end

    return instanceType == "pvp" or instanceType == "arena";
end

function SarychUI.Compat.UnitPhaseReason(unit)
    if ( SarychUI.Compat.C_PvP.IsPvPMap() or UnitIsUnit("player", unit) ) then
        return;
    end

    if not ( SarychUI.Compat.IsInRaid() and UnitIsConnected(unit) ) then
        return;
    end

    for i = 1, MAX_RAID_MEMBERS do
        local name, rank, subgroup, level, class, fileName, zone = GetRaidRosterInfo(i)
        if ( not name ) then
            break;
        end

        if name == UnitName(unit) then
            return CrossLocation[zone];
        end
    end

end

function SarychUI.Compat.GetMaxUnitNumberBattleground()
    return MAX_BATTLEGOUND_UNIT[GetMapInfo()];
end

SarychUI.Compat.C_Map = SarychUI.Compat.C_Map or {};
SarychUI.Compat.C_Map.WorldMap = {};

local function LoadZones(obj, ...)
    local n = select('#', ...);
    for i=1, n do
        local zone = select(i, ...);
        tinsert(obj, zone);
    end
end

for continentIndex = 1, 4 do
    LoadZones(SarychUI.Compat.C_Map.WorldMap, GetMapZones(continentIndex));
end

function SarychUI.Compat.C_Map.IsWorldMap(uiMap)
    for _, value in pairs(SarychUI.Compat.C_Map.WorldMap) do
        if ( value == uiMap ) then
            return true;
        end
    end
end

function SarychUI.Compat.UnitInOtherParty(unit)
    if not SarychUI.Compat.C_Map.IsWorldMap(GetZoneText()) or SarychUI.Compat.UnitPhaseReason(unit) then
        return false;
    end

    if not ( SarychUI.Compat.IsInRaid() and UnitIsConnected(unit) ) then
        return;
    end

    for i = 1, GetRealNumRaidMembers() do
        local name, rank, subgroup, level, class, fileName, zone = GetRaidRosterInfo(i);
        if ( name == UnitName(unit) ) then
            return not SarychUI.Compat.C_Map.IsWorldMap(zone);
        end
    end

end

function SarychUI.Compat.GetTexCoordsForRoleSmallCircle(role)
    if ( role == "TANK" ) then
        return 0, 19/64, 22/64, 41/64;
    elseif ( role == "HEALER" ) then
        return 20/64, 39/64, 1/64, 20/64;
    elseif ( role == "DAMAGER" ) then
        return 20/64, 39/64, 22/64, 41/64;
    else
        error("Unknown role: "..tostring(role));
    end
end

function SarychUI.Compat.CooldownFrame_Clear(self)
    self:Hide();
    if SarychUI_NotifyCooldown then SarychUI_NotifyCooldown(self, 0, 0, 0) end
end

SarychUI.Compat.Enum = SarychUI.Compat.Enum or {};
SarychUI.Compat.Enum.SummonStatus = {
    None = 0,
    Pending = 1,
    Accepted = 2,
    Declined = 3
};

SarychUI.Compat.C_IncomingSummon = SarychUI.Compat.C_IncomingSummon or {};
SarychUI.Compat.C_IncomingSummon.HasIncomingSummon = function(unit)
    return false;
end

SarychUI.Compat.C_IncomingSummon.IncomingSummonStatus = function(unit)
    return 0;
end


SarychUI.Compat.C_PartyInfo = SarychUI.Compat.C_PartyInfo or {};

do

    local countdownTicker;
    SarychUI.Compat.C_PartyInfo.DoCountdown = function(count)
        if ( countdownTicker ) then
            return;
        end

        local channel = SarychUI.Compat.IsInRaid() and "RAID_WARNING" or "PARTY";
        local countdown = count;

        local func = function()
            local timer = string.format(COMPACT_UNIT_FRAME_COUNTDOWN_START, countdown);
            local now = COMPACT_UNIT_FRAME_COUNTDOWN_NOW;
            if ( countdown == 0 ) then
                countdownTicker = nil;
            end
            SendChatMessage(countdown > 0 and timer or now, channel);
            countdown = countdown - 1;
        end

        countdownTicker = SuiTimer.NewTicker(1, func, count + 1)
    end

    local isAllAssistant = false;
    function SarychUI.Compat.IsEveryoneAssistant()
        return isAllAssistant;
    end

    SarychUI.Compat.CUF_SET_ASSIST_DELAY = 0.15;

    local assistantTicker;
    function SarychUI.Compat.SetEveryoneIsAssistant(enable)
        if ( assistantTicker ) then
            assistantTicker:Cancel();
            assistantTicker = nil;
        end

        local index = 1;
        local numMembers = GetRealNumRaidMembers();
        if numMembers == 0 then isAllAssistant = false; return end

        local func = function()
            local unit = "raid"..index;
            if SarychUI.Compat.UnitIsGroupLeader(unit) then
                index = index + 1; return;
            end
            if ( SarychUI.Compat.IsEveryoneAssistant() ) then
                PromoteToAssistant(unit);
            else
                DemoteAssistant(unit);
            end
            index = index + 1;
        end

        isAllAssistant = enable;
        assistantTicker = SuiTimer.NewTicker(SarychUI.Compat.CUF_SET_ASSIST_DELAY, func, numMembers);
    end

end

local PARTY_MEMBER_FRAME_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "PARTY_MEMBERS_CHANGED",
    "PARTY_LEADER_CHANGED",
    "PARTY_LOOT_METHOD_CHANGED",
    "MUTELIST_UPDATE",
    "IGNORELIST_UPDATE",
    "UNIT_FACTION",
    "UNIT_AURA",
    "UNIT_PET",
    "VOICE_START",
    "VOICE_STOP",
    "VARIABLES_LOADED",
    "VOICE_STATUS_UPDATE",
    "READY_CHECK",
    "READY_CHECK_CONFIRM",
    "READY_CHECK_FINISHED",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "UNIT_HEALTH",
    "UNIT_NAME_UPDATE",
    "UNIT_PORTRAIT_UPDATE",
    "UNIT_DISPLAYPOWER",
    "UNIT_THREAT_SITUATION_UPDATE",
}

local function RegisterPartyMemberFrameEvents(frame)
    -- Do not call PartyMemberFrame_OnLoad. It reaches UnitFrame_SetUnit, which
    -- SetScript's OnEvent. From addon code that taints the party frame, and the
    -- next combat Show/SetPoint/SetAttribute is blocked.
    local i
    for i = 1, #PARTY_MEMBER_FRAME_EVENTS do
        frame:RegisterEvent(PARTY_MEMBER_FRAME_EVENTS[i])
    end
end

local function HidePartyFrame()
    for i=1, MAX_PARTY_MEMBERS, 1 do
        _G["PartyMemberFrame"..i]:SetAlpha(0);
        _G["PartyMemberFrame"..i]:Hide();
        _G["PartyMemberFrame"..i]:UnregisterAllEvents();
    end
end

local function ShowPartyFrame()
    for i=1, MAX_PARTY_MEMBERS, 1 do
        if ( UnitExists("party"..i) ) then
            local frame = _G["PartyMemberFrame"..i]
            frame:SetAlpha(1);
            frame:Show();
            RegisterPartyMemberFrameEvents(frame);
            if PartyMemberFrame_UpdateMember then
                PartyMemberFrame_UpdateMember(frame);
            end
        end
    end
end

function SarychUI.Compat.RaidOptionsFrame_UpdatePartyFrames()
    if ( InCombatLockdown() ) then
        return;
    end
    if CompactRaidFrameEnabled == false then
        HidePartyFrame()
        for i = 1, MAX_PARTY_MEMBERS do
            RegisterPartyMemberFrameEvents(_G["PartyMemberFrame"..i])
        end
        if not SarychUI.Compat.IsInRaid() then ShowPartyFrame() end
        return
    end
    if ( SarychUI.Compat.GetDisplayedAllyFrames() ~= "party" ) then
        HidePartyFrame();
    else
        HidePartyFrame();
        ShowPartyFrame();
    end
    UpdatePartyMemberBackground();
end

local LibGT      = LibStub:GetLibrary("LibGroupTalents-1.0");
local LibAura    = LibStub:GetLibrary("LibCUFAuras-1.0");
local LibResComm = LibStub:GetLibrary("LibResComm-1.0");

do

    local function CompactUnitFrame_FireEvent(self, event)
        CompactUnitFrame_OnEvent(self, event, self.unit or self.displayedUnit);
    end

    local function LibEventCallback(self, event, ... )
        local arg1, arg2, arg3, arg4, arg5 = ...;
        if ( not UnitExists(self.unit) ) then
            return;
        end

        if ( event == "LibGroupTalents_RoleChange" ) then
            CompactUnitFrame_FireEvent(self, "PLAYER_ROLES_ASSIGNED");
        elseif ( event == "ResComm_ResStart" and arg3 == UnitName(self.unit) ) then
            CompactUnitFrame_FireEvent(self, "INCOMING_RESURRECT_CHANGED");
        elseif ( event == "ResComm_ResEnd" and arg2 == UnitName(self.unit) ) then
            CompactUnitFrame_FireEvent(self, "INCOMING_RESURRECT_CHANGED");
        elseif ( event == "EffectApplied" and arg3 == UnitGUID(self.unit) ) then
            CompactUnitFrame_FireEvent(self, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED");
        else
            local unitMatches = arg1 == UnitGUID(self.unit) or arg5 == UnitGUID(self.unit);
            if ( unitMatches ) then
                if ( event == "HealComm_HealUpdated" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_PREDICTION");
                elseif ( event == "HealComm_HealStarted" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_PREDICTION");
                elseif ( event == "HealComm_HealDelayed" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_PREDICTION");
                elseif ( event == "HealComm_HealStopped" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_PREDICTION");
                elseif ( event == "HealComm_ModifierChanged" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_PREDICTION");
                elseif ( event == "HealComm_GUIDDisappeared" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_PREDICTION");
                elseif ( event == "UnitUpdated" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED");
                elseif ( event == "EffectRemoved" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED");
                elseif ( event == "UnitCleared" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED");
                elseif ( event == "AreaCreated" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED");
                elseif ( event == "AreaCleared" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED");
                elseif ( event == "UnitAbsorbed" ) then
                    CompactUnitFrame_FireEvent(self, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED");
                elseif ( event == "COMPACT_UNIT_FRAME_UNIT_AURA" ) then
                    CompactUnitFrame_FireEvent(self, "COMPACT_UNIT_FRAME_UNIT_AURA");
                end
            end
        end
    end

    function CompactUnitFrame_RegisterCallback(self)
        LibGT.RegisterCallback(self, "LibGroupTalents_RoleChange", LibEventCallback, self);

        -- Heal and absorb callbacks are registered once by UnitFrameLayers
        -- after CompactUnitFrame_SetUnit assigns a unit to this frame.
        LibAura.RegisterCallback(self, "COMPACT_UNIT_FRAME_UNIT_AURA", LibEventCallback, self);

        LibResComm.RegisterCallback(self, "ResComm_CanRes", LibEventCallback, self)
        LibResComm.RegisterCallback(self, "ResComm_Ressed", LibEventCallback, self)
        LibResComm.RegisterCallback(self, "ResComm_ResExpired", LibEventCallback, self)
        LibResComm.RegisterCallback(self, "ResComm_ResStart", LibEventCallback, self)
        LibResComm.RegisterCallback(self, "ResComm_ResEnd", LibEventCallback, self)
    end

end

do
    local function LibEventCallback(self, event, ... )
        if ( event == "LibGroupTalents_RoleChange" ) then
            CompactRaidFrameManager_OnEvent(self, "UPDATE_ACTIVE_BATTLEFIELD");
        end
    end

    function CompactRaidFrameManager_RegisterCallback(self)
        LibGT.RegisterCallback(self, "LibGroupTalents_RoleChange", LibEventCallback, self);
    end
end

function SarychUI.Compat.UnitHasIncomingResurrection(unit)
    if not ( unit and LibResComm ) then
        return;
    end

    return LibResComm:IsUnitBeingRessed(UnitName(unit));
end




local LibGTConvertRole = {
    ["melee"]   = "DAMAGER",
    ["caster"]  = "DAMAGER",
    ["healer"]  = "HEALER",
    ["tank"]    = "TANK",
};

function SarychUI.Compat.GetSpecializationRole(specIndex)
    if ( not LibGT ) then
        return "NONE";
    end

    return LibGTConvertRole[LibGT:GetUnitRole("player")] or "NONE";
end

function SarychUI.Compat.UnitGroupRoles(unit)
    local role;
    -- For 3.3.5 roles are assigned only for LFG, so the API UnitGroupRolesAssigned works only for LFG
    -- For LFG, do not need to use third-party methods to define a role that is not always defined correctly.
    local isTank, isHealer, isDamage = UnitGroupRolesAssigned(unit);
    if ( isTank ) then
        role = "TANK";
    elseif ( isHealer ) then
        role = "HEALER";
    elseif ( isDamage ) then
        role = "DAMAGER";
    else
        -- It makes no sense to use third-party methods to define a role if the role of this class is only one.
        local _,class = UnitClass(unit);
        local damager = class == "HUNTER" or class == "ROGUE" or class == "MAGE" or class == "WARLOCK";
        if ( damager ) then
            role = "DAMAGER";
        elseif ( LibGT ) then
            role = LibGTConvertRole[LibGT:GetUnitRole(unit)];
        end
    end

    return role or "NONE";
end

function SarychUI.Compat.UnitShouldDisplayName(unitToken)
    return unitToken;
end

function SarychUI.Compat.UnitNameplateShowsWidgetsOnly(unitToken)
    return not unitToken;
end

function SarychUI.Compat.SpellIsPriorityAura(spellId)
    if ( not SarychUI.Data.GroupAuras.lossOfControl ) then
        return false;
    end

    return SarychUI.Data.GroupAuras.lossOfControl[spellId] and true;
end

function SarychUI.Compat.SpellIsSelfBuff(spellId)
    local info = LibAura:SpellIsSelfBuff(spellId)
    if ( not info ) then
        return false;
    end

    return info.appliesOnlyYourself;
end

function SarychUI.Compat.SpellGetVisibilityInfo(spellId, visType)
    if ( not LibAura ) then
        return false;
    end

    return LibAura:SpellGetVisibilityInfo(spellId, visType)
end

function SarychUI.Compat.UnitAuraBySlot(unit, slot)
    if not ( unit and LibAura ) then
        return;
    end

    return LibAura:UnitAuraBySlot(unit, slot);
end

-- Returned slots are unpacked before callbacks run, so this scratch array is reusable.
local auraSlots = {}
function SarychUI.Compat.UnitAuraSlots(unit, filter, maxCount, continuationToken)
    local tracker = unit and LibAura.CASHE[UnitGUID(unit)]
    if not tracker or (maxCount and maxCount <= 0) then return nil end
    local slots, nextToken = auraSlots, nil
    for i = #slots, 1, -1 do slots[i] = nil end
    for i = (continuationToken or 0) + 1, #tracker do
        if tracker[i].filterType == filter then
            if maxCount and #slots >= maxCount then nextToken = slots[#slots]; break end
            slots[#slots + 1] = i
        end
    end
    return nextToken, unpack(slots)
end
