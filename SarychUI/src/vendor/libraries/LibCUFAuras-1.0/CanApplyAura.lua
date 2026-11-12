local lib, version = LibStub("LibCUFAuras-1.0");
if ( not lib ) then error("not found LibCUFAuras-1.0") end
if ( version > 1 ) then return end

local companion        = "MOUNT";
local UnitClass        = UnitClass;
local GetSpellInfo     = GetSpellInfo;
local GetCompanionInfo = GetCompanionInfo;
local GetNumCompanions = GetNumCompanions;
local PLAYER_CLASS     = select(2, UnitClass("player"));

local UNIT_CAN_APPLY_AURAS = SarychUI.Data.GroupAuras.canApply
lib.UNIT_CAN_APPLY_AURAS = UNIT_CAN_APPLY_AURAS;

local function SetNewCompanion(spellID)
    UNIT_CAN_APPLY_AURAS[PLAYER_CLASS][GetSpellInfo(spellID)] = { canApplyAura = true,  appliesOnlyYourself = true };
end

local function Companion_Inizialization()
    for index = 1, GetNumCompanions(companion) do
        local _, _, spellID = GetCompanionInfo(companion, index);
        SetNewCompanion(spellID);
    end
end

function lib.events:PLAYER_LOGIN()
    Companion_Inizialization();
end

function lib.events:COMPANION_UPDATE(_, arg1)
    if ( arg1 == companion ) then
        Companion_Inizialization();
    end
end

lib.events:RegisterEvent("COMPANION_UPDATE");
lib.events:RegisterEvent("PLAYER_LOGIN");
