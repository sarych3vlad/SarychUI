local lib, version = LibStub("LibCUFAuras-1.0");
if ( not lib ) then error("not found LibCUFAuras-1.0") end
if ( version > 1 ) then return end

lib.HealingTakenEffect = SarychUI.Data.GroupAuras.healingTaken
