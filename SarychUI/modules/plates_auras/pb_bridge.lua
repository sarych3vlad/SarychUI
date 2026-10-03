--[[
	Non-Awesome plate->GUID->paint (PlateBuffs-style via LibNameplates + CLEU).

	Only adaptation: UpdateAuras needs the WorldFrame root under ENP, so we
	ResolvePaintPlate before paint/hide.
]]

local LibNameplates = LibStub("LibNameplates-1.0", true)
if not LibNameplates then
	return
end

local nametoGUIDs = {}
local plateToGUID = {}
local guidToPlate = {}
local owner = {}
local enabled = false

local function UseAwesomeWotlk()
	if _G.sarPlatesAuras_UseAwesomeWotlk then
		return _G.sarPlatesAuras_UseAwesomeWotlk()
	end
	return false
end

local function IsModuleEnabled()
	local mod = SarychUI and SarychUI.GetModule and SarychUI:GetModule("plates_auras", true)
	return not mod or not mod.IsModuleEnabled or mod.IsModuleEnabled()
end

-- Same helpers PlateBuffs uses (thin Lib wrappers)
local function GetPlateGUID(plate)
	return LibNameplates:GetGUID(plate)
end

local function GetPlateName(plate)
	return LibNameplates:GetName(plate)
end

local function GetPlateType(plate)
	return LibNameplates:GetType(plate)
end

local function PlateIsBoss(plate)
	return LibNameplates:IsBoss(plate)
end

local function GetPlateByGUID(guid)
	local plate = LibNameplates:GetNameplateByGUID(guid)
	if plate then
		return plate
	end
	plate = guidToPlate[guid]
	if plate and plate.IsShown and plate:IsShown() then
		return plate
	end
	guidToPlate[guid] = nil
	return nil
end

local function GetPlateByName(name, maxhp)
	return LibNameplates:GetNameplateByName(name, maxhp)
end

local function GetTargetPlate()
	return LibNameplates:GetTargetNameplate()
end

-- ENP: Lib passes UnitFrame; our aura frames live on the WorldFrame root.
local function ResolvePaintPlate(plate)
	if not plate then
		return nil
	end
	if plate.UnitFrame then
		return plate
	end
	if LibNameplates.realPlate and LibNameplates.realPlate[plate] then
		return LibNameplates.realPlate[plate]
	end
	local parent = plate.GetParent and plate:GetParent()
	if parent and parent.UnitFrame == plate then
		return parent
	end
	return plate
end

local function GetIdentityFrame(plate)
	local root = ResolvePaintPlate(plate)
	if root and root.UnitFrame then
		return root.UnitFrame, root
	end
	return plate, root
end

local function RememberPlateGUID(plate, GUID)
	local root = ResolvePaintPlate(plate)
	if not root or not GUID then return end
	local oldGUID = plateToGUID[root]
	if oldGUID and oldGUID ~= GUID and guidToPlate[oldGUID] == root then
		guidToPlate[oldGUID] = nil
	end
	plateToGUID[root] = GUID
	guidToPlate[GUID] = root
end

local function ForgetPlateGUID(plate)
	local root = ResolvePaintPlate(plate)
	if not root then return end
	local GUID = plateToGUID[root]
	if GUID and guidToPlate[GUID] == root then
		guidToPlate[GUID] = nil
	end
	plateToGUID[root] = nil
end

-- Prefer exact unit tokens exposed by the nameplate API/ElvUI. LibNameplates on
-- 3.3.5 often learns a GUID only after mouseover, while these sources are already
-- available for group units and for clients that expose nameplate unit tokens.
local function GetDirectPlateUnit(plate, expectedGUID)
	local identity, root = GetIdentityFrame(plate)
	local rootUnit = root and root.namePlateUnitToken
	if rootUnit and UnitExists(rootUnit) then
		local GUID = UnitGUID(rootUnit)
		if GUID and (not expectedGUID or GUID == expectedGUID) then
			return rootUnit
		end
	end

	local unit = identity and identity.unit
	if unit and UnitExists(unit) then
		local GUID = UnitGUID(unit)
		if GUID and (not expectedGUID or GUID == expectedGUID) then
			local expectedName = identity.UnitName or GetPlateName(plate)
			local unitName = UnitName(unit)
			if not expectedName or not unitName or expectedName == unitName then
				return unit
			end
		end
	end
	return nil
end

local function GetDirectPlateGUID(plate)
	local unit = GetDirectPlateUnit(plate)
	if unit then
		return UnitGUID(unit), unit
	end
	local identity = GetIdentityFrame(plate)
	local GUID = identity and identity.guid
	if GUID and type(GUID) == "string" then
		return GUID, nil
	end
	return nil, nil
end

local function ShortName(name)
	if not name then return nil end
	return name:match("^(.-)-") or name
end

local function FindKnownPlayerGUIDByName(name)
	name = ShortName(name)
	if not name then return nil end
	local LibAI = LibStub("LibAuraInfo-1.0", true)
	if not LibAI or not LibAI.GUIDData_name then return nil end

	local found
	for GUID, knownName in pairs(LibAI.GUIDData_name) do
		local flags = LibAI.GUIDData_flags and LibAI.GUIDData_flags[GUID]
		if flags and bit and bit.band and bit.band(flags, 0x00000400) ~= 0
			and ShortName(knownName) == name then
			if found and found ~= GUID then
				return nil -- same short name from two realms: never guess a plate
			end
			found = GUID
		end
	end
	return found
end

-- PlateBuffs:HidePlateSpells(plate)
local function HidePlateSpells(plate)
	if not plate or not _G.sarPlatesAuras_HidePlateAuras then
		return
	end
	_G.sarPlatesAuras_HidePlateAuras(plate)
	local root = ResolvePaintPlate(plate)
	if root and root ~= plate then
		_G.sarPlatesAuras_HidePlateAuras(root)
	end
end

-- PlateBuffs:AddBuffsToPlate(plate, GUID)
local function AddBuffsToPlate(plate, GUID, unitID)
	plate = ResolvePaintPlate(plate)
	if not plate or not GUID or not _G.UpdateAuras then
		return
	end
	-- A delayed LibAuraInfo callback can arrive after LibNameplates has recycled
	-- this frame. If the plate exposes its current identity, never paint an old
	-- GUID onto the new owner.
	local directGUID, directUnit = GetDirectPlateGUID(plate)
	if directGUID and directGUID ~= GUID then
		HidePlateSpells(plate)
		return
	end
	unitID = unitID or directUnit
	RememberPlateGUID(plate, GUID)
	_G.UpdateAuras(plate, unitID, GUID)
end

-- PlateBuffs:UpdatePlateByGUID
local function UpdatePlateByGUID(GUID)
	local plate = GetPlateByGUID(GUID)
	if plate then
		AddBuffsToPlate(plate, GUID, GetDirectPlateUnit(plate, GUID))
		return true
	end
	return false
end

-- PlateBuffs:UpdatePlateByName (players / unique names only)
local function UpdatePlateByName(name, maxhp)
	local GUID = nametoGUIDs[name]
	if not GUID then
		return false
	end
	local plate = GetPlateByName(name, maxhp)
	if plate then
		AddBuffsToPlate(plate, GUID, GetDirectPlateUnit(plate, GUID))
		return true
	end
	return false
end

-- PlateBuffs:UpdateTargetPlate
local function UpdateTargetPlate(GUID)
	if UnitExists("target") and UnitGUID("target") == GUID then
		local plate = GetTargetPlate()
		if plate then
			AddBuffsToPlate(plate, GUID, "target")
			return true
		end
	end
	return false
end

-- PlateBuffs:ForceNameplateUpdate
local function ForceNameplateUpdate(dstGUID)
	if not dstGUID then
		return
	end
	if UpdateTargetPlate(dstGUID) then
		return
	end
	if UpdatePlateByGUID(dstGUID) then
		return
	end
	local dstName, dstFlags
	local LibAI = LibStub("LibAuraInfo-1.0", true)
	if LibAI and LibAI.GetGUIDInfo then
		dstName, dstFlags = LibAI:GetGUIDInfo(dstGUID)
	end
	-- PlateBuffs FlagIsPlayer (0x400)
	if dstFlags and bit and bit.band and bit.band(dstFlags, 0x00000400) ~= 0 and dstName then
		local shortName = ShortName(dstName)
		local uniqueGUID = FindKnownPlayerGUIDByName(shortName)
		if uniqueGUID == dstGUID then
			nametoGUIDs[shortName] = dstGUID
			UpdatePlateByName(shortName)
		else
			nametoGUIDs[shortName] = nil
		end
	end
end

-- PlateBuffs:CollectUnitInfo
local function CollectUnitInfo(unitID)
	if UseAwesomeWotlk() or not IsModuleEnabled() then
		return
	end
	if not unitID or not UnitExists(unitID) then
		return
	end
	if UnitIsUnit and UnitIsUnit(unitID, "player") then
		return
	end

	local GUID = UnitGUID(unitID)
	if not GUID then
		return
	end

	local unitName = UnitName(unitID)
	-- PlateBuffs operator precedence: (name and player) or worldboss
	if unitName and UnitIsPlayer(unitID) or (unitName and UnitClassification(unitID) == "worldboss") then
		nametoGUIDs[unitName] = GUID
	end

	if _G.sarPlatesAuras_FindAllAuras then
		_G.sarPlatesAuras_FindAllAuras(unitID)
	end

	-- Even in fallback mode an installed nameplate API may expose the exact root.
	-- Use it as an identity source without switching the aura backend to Awesome.
	local directPlate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
		and C_NamePlate.GetNamePlateForUnit(unitID)
	if directPlate then
		AddBuffsToPlate(directPlate, GUID, unitID)
		return
	end

	if not UpdatePlateByGUID(GUID) and (UnitIsPlayer(unitID) or UnitClassification(unitID) == "worldboss") then
		UpdatePlateByName(unitName, UnitHealthMax(unitID))
	end
end

-- PlateBuffs:AddOurStuffToPlate
local function AddOurStuffToPlate(plate)
	local GUID, unitID = GetDirectPlateGUID(plate)
	if not GUID then
		GUID = GetPlateGUID(plate)
	end
	if GUID and type(GUID) == "string" then
		AddBuffsToPlate(plate, GUID, unitID or GetDirectPlateUnit(plate, GUID))
		return
	end

	local plateName = GetPlateName(plate) or "UNKNOWN"
	if GetPlateType(plate) == "PLAYER" and not nametoGUIDs[plateName] then
		nametoGUIDs[plateName] = FindKnownPlayerGUIDByName(plateName)
	end
	if nametoGUIDs[plateName] and (GetPlateType(plate) == "PLAYER" or PlateIsBoss(plate)) then
		AddBuffsToPlate(plate, nametoGUIDs[plateName], GetDirectPlateUnit(plate, nametoGUIDs[plateName]))
		return
	end

	HidePlateSpells(plate)
end

-- PlateBuffs:LibNameplates_NewNameplate
function owner:LibNameplates_NewNameplate(event, plate)
	if UseAwesomeWotlk() or not IsModuleEnabled() then
		return
	end
	AddOurStuffToPlate(plate)
end

-- PlateBuffs:LibNameplates_FoundGUID - always paint the plate Lib passed
function owner:LibNameplates_FoundGUID(event, plate, GUID, unitID)
	if UseAwesomeWotlk() or not IsModuleEnabled() then
		return
	end
	if not GUID then
		return
	end
	RememberPlateGUID(plate, GUID)
	if unitID and UnitExists(unitID) and not (_G.sarPlatesAuras_HasGuidAuras and _G.sarPlatesAuras_HasGuidAuras(GUID)) then
		CollectUnitInfo(unitID)
	end
	AddBuffsToPlate(plate, GUID, unitID)
end

-- PlateBuffs:LibNameplates_RecycleNameplate
function owner:LibNameplates_RecycleNameplate(event, plate)
	if UseAwesomeWotlk() then
		return
	end
	ForgetPlateGUID(plate)
	HidePlateSpells(plate)
end

function _G.sarPlatesAuras_PB_Enable()
	if enabled or UseAwesomeWotlk() then
		return
	end
	LibNameplates.RegisterCallback(owner, "LibNameplates_NewNameplate")
	LibNameplates.RegisterCallback(owner, "LibNameplates_FoundGUID")
	LibNameplates.RegisterCallback(owner, "LibNameplates_RecycleNameplate")
	enabled = true
end

function _G.sarPlatesAuras_PB_Disable()
	if not enabled then
		return
	end
	LibNameplates.UnregisterAllCallbacks(owner)
	-- Release every glow/timer owned by fallback before dropping the lookup
	-- tables. Merely hiding the parent container leaves pooled glow OnUpdates
	-- alive and can expose a stale border when the plate is reused later.
	for plate in pairs(plateToGUID) do
		HidePlateSpells(plate)
	end
	wipe(plateToGUID)
	wipe(guidToPlate)
	enabled = false
end

function _G.sarPlatesAuras_PB_ForceNameplateUpdate(guid)
	if UseAwesomeWotlk() then
		return
	end
	ForceNameplateUpdate(guid)
end

function _G.sarPlatesAuras_PB_CollectUnitInfo(unitId)
	CollectUnitInfo(unitId)
end

_G.sarPlatesAuras_UpdatePlateByGUID = function(guid)
	if UseAwesomeWotlk() then
		return false
	end
	return UpdatePlateByGUID(guid)
end

_G.sarPlatesAuras_CollectUnitInfo = CollectUnitInfo
_G.sarPlatesAuras_OnNonAwesomePlate = function(plate)
	if UseAwesomeWotlk() or not IsModuleEnabled() then
		return
	end
	AddOurStuffToPlate(plate)
end
