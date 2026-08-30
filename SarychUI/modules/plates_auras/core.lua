local function GetActiveDisplayProfile()
	local mod = SarychUI and SarychUI:GetModule("plates_auras", true)
	if mod and mod.GetActiveDisplayProfile then
		return mod:GetActiveDisplayProfile()
	end
	return nil
end

local function GetPlayerIconSpacing()
	local spacing = _G.PLAYER_ICON_SPACING
	if spacing == nil then
		local profile = GetActiveDisplayProfile()
		if profile and profile.layout and profile.layout.player then
			spacing = profile.layout.player.spacing
		end
	end
	return tonumber(spacing) or 2
end

local function UsesElvUILayout()
	local layout = SarychUI and SarychUI.PlatesAurasElvUI
	return layout and layout.IsActive and layout.IsActive()
end

local function GetAuraContainerParent(namePlate)
	if UsesElvUILayout() then
		local layout = SarychUI.PlatesAurasElvUI
		local unitFrame = layout and layout.GetElvUIUnitFrame and layout.GetElvUIUnitFrame(namePlate)
		if unitFrame then
			return unitFrame
		end
	end
	return namePlate
end

local function ApplyAuraContainerScale(namePlate, container, slotName, baseScale)
	if UsesElvUILayout() and slotName then
		local layout = SarychUI.PlatesAurasElvUI
		if layout and layout.ApplyContainerResponsiveScale then
			layout.ApplyContainerResponsiveScale(namePlate, container, slotName, baseScale)
			return
		end
	end
	if container then
		container:SetScale(baseScale or 1)
	end
end

local function HasVisiblePlayerIcons(namePlate)
	if not namePlate or not namePlate.playerFrame or not namePlate.playerFrame.auraIcons then
		return false
	end

	for _, auraFrame in ipairs(namePlate.playerFrame.auraIcons) do
		if auraFrame and auraFrame.icon and auraFrame.icon:IsShown() then
			return true
		end
	end

	return false
end

function _G.sarPlatesAuras_HasVisiblePlayerIcons(namePlate)
	return HasVisiblePlayerIcons(namePlate)
end

-- Helper function to check if CVar exists and set it if AwesomeWotlk is enabled
function _G.sarPlatesAuras_SetNameplateDistance(value)
	local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.plates_auras
	if db and db.useAwesomeWotlk then
		-- Check if CVar exists before setting
		local success, result = pcall(function()
			return GetCVar("nameplateDistance")
		end)
		if success and result then
			-- CVar exists, safe to set
			SetCVar("nameplateDistance", value or 42)
			return true
		end
	end
	return false
end

-- Set nameplate distance only if AwesomeWotlk is enabled
-- Use pcall to safely call it even if DB is not initialized yet
pcall(function()
	if _G.sarPlatesAuras_SetNameplateDistance then
		_G.sarPlatesAuras_SetNameplateDistance(42)
	end
end)

local removedPlates = {}
local tinsert = table.insert
local tsort = table.sort
local format = string.format
local floor, ceil = math.floor, math.ceil
local COOLDOWN_TEXT_UPDATE_INTERVAL = 0.10

-- Get LibNameplates-1.0 for fallback when AwesomeWotlk is disabled
local LibNameplates = LibStub("LibNameplates-1.0", true)
-- LibAuraInfo: combat-log aura feed for non-Awesome (same SPELL_DATA / UpdateAuras path)
local LibAuraInfo = LibStub("LibAuraInfo-1.0", true)

-- True only when the toggle is on AND C_NamePlate API actually exists.
-- Stale DB with useAwesomeWotlk=true but no Awesome DLL must fall back to LibNameplates.
local function IsAwesomeNameplateApiAvailable()
	return C_NamePlate
		and type(C_NamePlate.GetNamePlateForUnit) == "function"
		and type(C_NamePlate.GetNamePlates) == "function"
end

local function UseAwesomeWotlk()
	local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.plates_auras
	if not (db and db.useAwesomeWotlk == true) then
		return false
	end
	return IsAwesomeNameplateApiAvailable()
end
_G.sarPlatesAuras_UseAwesomeWotlk = UseAwesomeWotlk

local function IsTestModeEnabled()
	local db = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules.plates_auras
	if db and db.testModeEnabled then
		return true
	end
	return _G.SarPlatesAurasTest and _G.SarPlatesAurasTest.testTimer ~= nil
end

-- LibNameplates may fire UnitFrame (ENP fakePlate); UpdateAuras needs the WorldFrame root.
local function NormalizeRootPlate(plate)
	if not plate then
		return nil
	end
	if plate.UnitFrame then
		return plate
	end
	if LibNameplates and LibNameplates.realPlate and LibNameplates.realPlate[plate] then
		return LibNameplates.realPlate[plate]
	end
	local parent = plate.GetParent and plate:GetParent()
	if parent and parent.UnitFrame == plate then
		return parent
	end
	return plate
end

-- Helper function to get nameplate for unit (works with C_NamePlate or LibNameplates)
local function GetNamePlateForUnit(unitId)
	if not unitId then return nil end

	if UseAwesomeWotlk() then
		if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
			return C_NamePlate.GetNamePlateForUnit(unitId)
		end
		return nil
	end

	-- Non-Awesome: PlateBuffs bridge owns plate lookup. Prefer exact GUID, never name for NPCs.
	local guid = UnitGUID(unitId)
	if not guid or not LibNameplates then
		return nil
	end
	local plate = LibNameplates:GetNameplateByGUID(guid)
	if plate then
		return NormalizeRootPlate(plate)
	end
	if UnitIsUnit and UnitIsUnit(unitId, "target") and LibNameplates.GetTargetNameplate then
		return NormalizeRootPlate(LibNameplates:GetTargetNameplate())
	end
	return nil
end

local function HidePlateAuras(plate)
	if not plate then return end
	plate = NormalizeRootPlate(plate) or plate
	if plate.controlFrame then
		if plate.controlFrame.auraIcon then plate.controlFrame.auraIcon:Hide() end
		if plate.controlFrame.HideBorderEffect then plate.controlFrame.HideBorderEffect() end
	end
	if plate.castFrame then
		if plate.castFrame.auraIcon then plate.castFrame.auraIcon:Hide() end
		if plate.castFrame.HideBorderEffect then plate.castFrame.HideBorderEffect() end
	end
	if plate.mobilityFrame then
		if plate.mobilityFrame.auraIcon then plate.mobilityFrame.auraIcon:Hide() end
		if plate.mobilityFrame.HideBorderEffect then plate.mobilityFrame.HideBorderEffect() end
	end
	if plate.otherFrame then
		if plate.otherFrame.auraIcon then plate.otherFrame.auraIcon:Hide() end
		if plate.otherFrame.HideBorderEffect then plate.otherFrame.HideBorderEffect() end
	end
	if plate.playerFrame and plate.playerFrame.auraIcons then
		for i = 1, #plate.playerFrame.auraIcons do
			local auraFrame = plate.playerFrame.auraIcons[i]
			if auraFrame then
				if auraFrame.icon then auraFrame.icon:Hide() end
				if auraFrame.HideBorderEffect then auraFrame.HideBorderEffect() end
			end
		end
	end
end
_G.sarPlatesAuras_HidePlateAuras = HidePlateAuras

-- Reused buffer so the WorldFrame walk calls GetChildren() once per scan.
local worldChildren = {}

local function FillWorldChildren(...)
	local n = select("#", ...)
	for i = 1, n do
		worldChildren[i] = select(i, ...)
	end
	for i = n + 1, #worldChildren do
		worldChildren[i] = nil
	end
	return n
end

-- Helper function to get all nameplates
local function GetAllNamePlates()
	if UseAwesomeWotlk() then
		if C_NamePlate and C_NamePlate.GetNamePlates then
			return C_NamePlate.GetNamePlates()
		end
		return {}
	end

	local nameplates = {}
	local seen = {}

	local function addPlate(plate)
		plate = NormalizeRootPlate(plate)
		if plate and plate.IsShown and plate:IsShown() and not seen[plate] then
			seen[plate] = true
			tinsert(nameplates, plate)
		end
	end

	if LibNameplates and LibNameplates.GetAllNameplates then
		local frames = { LibNameplates:GetAllNameplates() }
		for i = 1, #frames do
			addPlate(frames[i])
		end
	end

	-- Also pick up ENP roots LibNameplates may only expose as UnitFrame fakePlates
	if WorldFrame and WorldFrame.GetNumChildren then
		local num = FillWorldChildren(WorldFrame:GetChildren())
		for i = 1, num do
			local child = worldChildren[i]
			if child and child.UnitFrame and child:IsShown() then
				addPlate(child)
			end
		end
	end

	return nameplates
end

-- Expose GetAllNamePlates globally for module.lua
_G.sarPlatesAuras_GetAllNamePlates = GetAllNamePlates

local frame = CreateFrame("Frame")
-- Register NAME_PLATE events if C_NamePlate is available (for AwesomeWotlk mode)
if C_NamePlate then
	frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
end

local namePlates = {}
local guidToUnitIdMap = {}
-- Cache auras by GUID (like PlateBuffs does)
local guidAuras = {}
-- LibAuraInfo callback owner (PlateBuffs-style CLEU path)
local libAuraOwner = {}
local libAuraInfoRegistered = false

-- Forward declare helpers used by LibNameplates / CLEU paths
local FindAllAuras
local UpdatePlateByGUID
local CollectUnitInfo

-- Non-Awesome plate→GUID→paint lives in pb_bridge.lua (PlateBuffs core).
UpdatePlateByGUID = function(guid)
	if not guid or UseAwesomeWotlk() then
		return false
	end
	if _G.sarPlatesAuras_PB_ForceNameplateUpdate then
		_G.sarPlatesAuras_PB_ForceNameplateUpdate(guid)
		return true
	end
	return false
end

CollectUnitInfo = function(unitId)
	if UseAwesomeWotlk() then
		return
	end
	if _G.sarPlatesAuras_PB_CollectUnitInfo then
		_G.sarPlatesAuras_PB_CollectUnitInfo(unitId)
	end
end

_G.sarPlatesAuras_UpdatePlateByGUID = UpdatePlateByGUID
_G.sarPlatesAuras_CollectUnitInfo = CollectUnitInfo
_G.sarPlatesAuras_HasGuidAuras = function(guid)
	return guid and guidAuras[guid] ~= nil
end

local function MakeAuraEntry(spellId, iconTexture, stackCount, duration, expirationTime, caster)
	local spellInfo = SPELL_DATA and SPELL_DATA[spellId]
	if not spellInfo or spellInfo.enabled == false then
		return nil
	end
	return {
		iconTexture = iconTexture,
		duration = duration or 0,
		expirationTime = expirationTime or 0,
		stackCount = stackCount or 0,
		caster = caster,
		type = spellInfo.type,
		priority = spellInfo.priority or 100,
	}
end

local function AddSpellToGuidCache(dstGUID, spellID, srcGUID, stackCount, duration, expirationTime)
	if not dstGUID or not spellID then
		return false
	end
	if not SPELL_DATA or not SPELL_DATA[spellID] or SPELL_DATA[spellID].enabled == false then
		return false
	end
	local _, _, iconTexture = GetSpellInfo(spellID)
	if not iconTexture then
		return false
	end
	local caster = (srcGUID and UnitGUID("player") == srcGUID) and "player" or nil
	local entry = MakeAuraEntry(spellID, iconTexture, stackCount, duration, expirationTime, caster)
	if not entry then
		return false
	end
	guidAuras[dstGUID] = guidAuras[dstGUID] or {}
	local existing = guidAuras[dstGUID][spellID]
	-- Prefer player-cast entry when both exist
	if existing and existing.caster == "player" and caster ~= "player" then
		return false
	end
	guidAuras[dstGUID][spellID] = entry
	return true
end

local function RemoveSpellFromGuidCache(dstGUID, spellID)
	if not dstGUID or not spellID or not guidAuras[dstGUID] then
		return false
	end
	if guidAuras[dstGUID][spellID] == nil then
		return false
	end
	guidAuras[dstGUID][spellID] = nil
	if not next(guidAuras[dstGUID]) then
		guidAuras[dstGUID] = nil
	end
	return true
end

local function ClearGuidCache(dstGUID)
	if dstGUID then
		guidAuras[dstGUID] = nil
	end
end

function libAuraOwner:LibAuraInfo_AURA_APPLIED(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
	if UseAwesomeWotlk() then
		return
	end
	if not LibAuraInfo or not dstGUID or dstGUID == UnitGUID("player") then
		return
	end
	local found, stackCount, debuffType, duration, expires = LibAuraInfo:GUIDAuraID(dstGUID, spellID, srcGUID)
	if not found then
		found, stackCount, debuffType, duration, expires = LibAuraInfo:GUIDAuraID(dstGUID, spellID)
	end
	if not found then
		return
	end
	if AddSpellToGuidCache(dstGUID, spellID, srcGUID, stackCount, duration, expires) then
		UpdatePlateByGUID(dstGUID)
	end
end

function libAuraOwner:LibAuraInfo_AURA_REMOVED(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
	if UseAwesomeWotlk() then
		return
	end
	if not dstGUID or dstGUID == UnitGUID("player") then
		return
	end
	if RemoveSpellFromGuidCache(dstGUID, spellID) then
		UpdatePlateByGUID(dstGUID)
	end
end

function libAuraOwner:LibAuraInfo_AURA_REFRESH(event, dstGUID, spellID, srcGUID, spellSchool, auraType, expirationTime)
	if UseAwesomeWotlk() then
		return
	end
	if not dstGUID or dstGUID == UnitGUID("player") then
		return
	end
	local cache = guidAuras[dstGUID]
	if cache and cache[spellID] then
		cache[spellID].expirationTime = expirationTime or cache[spellID].expirationTime
		cache[spellID].duration = cache[spellID].duration or 0
		UpdatePlateByGUID(dstGUID)
		return
	end
	self:LibAuraInfo_AURA_APPLIED(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
end

function libAuraOwner:LibAuraInfo_AURA_APPLIED_DOSE(event, dstGUID, spellID, srcGUID, spellSchool, auraType, stackCount, expirationTime)
	if UseAwesomeWotlk() then
		return
	end
	if not dstGUID or dstGUID == UnitGUID("player") then
		return
	end
	local cache = guidAuras[dstGUID]
	if cache and cache[spellID] then
		cache[spellID].stackCount = stackCount or cache[spellID].stackCount
		if expirationTime then
			cache[spellID].expirationTime = expirationTime
		end
		UpdatePlateByGUID(dstGUID)
		return
	end
	self:LibAuraInfo_AURA_APPLIED(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
end

function libAuraOwner:LibAuraInfo_AURA_CLEAR(event, dstGUID)
	if UseAwesomeWotlk() then
		return
	end
	if not dstGUID or dstGUID == UnitGUID("player") then
		return
	end
	if guidAuras[dstGUID] then
		ClearGuidCache(dstGUID)
		UpdatePlateByGUID(dstGUID)
	end
end

function _G.sarPlatesAuras_RegisterLibAuraInfo()
	if not LibAuraInfo or libAuraInfoRegistered or UseAwesomeWotlk() then
		return
	end
	LibAuraInfo.UnregisterAllCallbacks(libAuraOwner)
	LibAuraInfo.RegisterCallback(libAuraOwner, "LibAuraInfo_AURA_APPLIED")
	LibAuraInfo.RegisterCallback(libAuraOwner, "LibAuraInfo_AURA_REMOVED")
	LibAuraInfo.RegisterCallback(libAuraOwner, "LibAuraInfo_AURA_REFRESH")
	LibAuraInfo.RegisterCallback(libAuraOwner, "LibAuraInfo_AURA_APPLIED_DOSE")
	LibAuraInfo.RegisterCallback(libAuraOwner, "LibAuraInfo_AURA_CLEAR")
	if CombatLogClearEntries then
		pcall(CombatLogClearEntries)
	end
	libAuraInfoRegistered = true
end

function _G.sarPlatesAuras_UnregisterLibAuraInfo()
	if not LibAuraInfo then
		libAuraInfoRegistered = false
		return
	end
	LibAuraInfo.UnregisterAllCallbacks(libAuraOwner)
	libAuraInfoRegistered = false
end

-- Forward declare FindAllAuras before registering callbacks
FindAllAuras = function(unitId)
    local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
    local foundAuras = {}
    
    -- Get GUID for caching
    local unitGUID = UnitGUID(unitId)
    
    local function IsPlayerCaster(casterUnit)
        if not casterUnit then return false end
        if UnitIsUnit and UnitIsUnit(casterUnit, "player") then return true end
        return casterUnit == "player"
    end
    
    -- Один проход по всем баффам
    for i = 1, 40 do
        local _, _, iconTexture, stackCount, _, duration, expirationTime, caster, _, _, spellId = UnitBuff(unitId, i)
        if not spellId then
            break
        end
        if SPELL_DATA[spellId] and SPELL_DATA[spellId].enabled ~= false then
            local existing = foundAuras[spellId]
            if not existing or (not IsPlayerCaster(existing.caster) and IsPlayerCaster(caster)) then
                foundAuras[spellId] = {
                    iconTexture = iconTexture,
                    duration = duration,
                    expirationTime = expirationTime,
                    stackCount = stackCount,
                    caster = caster,
                    type = SPELL_DATA[spellId].type,
                    priority = SPELL_DATA[spellId].priority or 100
                }
            end
        end
    end
    
    -- Один проход по всем дебаффам
    for i = 1, 40 do
        local _, _, iconTexture, stackCount, _, duration, expirationTime, caster, _, _, spellId = UnitDebuff(unitId, i)
        if not spellId then
            break
        end
        if SPELL_DATA[spellId] and SPELL_DATA[spellId].enabled ~= false then
            local existing = foundAuras[spellId]
            if not existing or (not IsPlayerCaster(existing.caster) and IsPlayerCaster(caster)) then
                foundAuras[spellId] = {
                    iconTexture = iconTexture,
                    duration = duration,
                    expirationTime = expirationTime,
                    stackCount = stackCount,
                    caster = caster,
                    type = SPELL_DATA[spellId].type,
                    priority = SPELL_DATA[spellId].priority or 100
                }
            end
        end
    end
    
    -- Cache auras by GUID if available
    if unitGUID then
        guidAuras[unitGUID] = foundAuras
    end

    if SarychUI_PerfSlow then
        SarychUI_PerfSlow("Auras", "FindAllAurasSlow", perfStart, unitId, 2)
    end
    return foundAuras
end
_G.sarPlatesAuras_FindAllAuras = FindAllAuras

frame:SetScript("OnEvent", function(self, event, unit)
    -- Only process events if AwesomeWotlk mode is enabled
    if not UseAwesomeWotlk() then return end
    
    if event == "NAME_PLATE_UNIT_ADDED" then
        if SarychUI_PerfLog then
            SarychUI_PerfLog("Auras", "NAME_PLATE_UNIT_ADDED", unit)
        end
        local namePlate = GetNamePlateForUnit(unit)
        if namePlate then
            namePlates[unit] = namePlate
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if SarychUI_PerfLog then
            SarychUI_PerfLog("Auras", "NAME_PLATE_UNIT_REMOVED", unit)
        end
        namePlates[unit] = nil
    end
end)

-- Non-Awesome plate matching is owned by pb_bridge.lua (PlateBuffs core).
-- Do not register LibNameplates callbacks here — that was the duplicate-paint mess.

-- Use globals directly so settings changes apply immediately

local PRIORITY_ORDER = {
    immunities = 65,
    cc = 70,
    silence = 60,
    interrupts = 55,
    roots = 50,
    disarm = 45,
    buffs_defensive = 40,
    buffs_offensive = 35,
    buffs_other = 30,
    snare = 25,
    cast = 75,
    other = 20
}

local CENTER_AURA_TYPES = { "cc" }
local CAST_AURA_TYPES = { "silence", "interrupts" }
local MOBILITY_AURA_TYPES = { "snare", "roots" }
local OTHER_AURA_TYPES = { "immunities", "buffs_defensive", "buffs_offensive", "buffs_other", "disarm" }

-- Прямоугольные иконки сохраняют пропорции через обрезку, квадратные показывают
-- изображение целиком. Вызывается и при создании, и при смене формы на ходу.
local function ApplyIconGeometry(icon, size, width, height)
    if not icon then return end
    if width and height then
        icon:SetSize(width, height)
        -- Увеличиваем изображение на 17% (показываем меньшую центральную часть)
        local imageScale = 1.17
        local cropAmount = (imageScale - 1) / (2 * imageScale)  -- (1.17-1)/(2*1.17) = 0.073

        -- Простая обрезка: от 30x30 к 30x20 = отрезаем по 5px сверху и снизу
        local cropTop = (size - height) / (2 * size)  -- 5/60 = 0.083
        local cropBottom = 1 - cropTop  -- 0.917

        icon:SetTexCoord(cropAmount, 1 - cropAmount, cropTop + cropAmount, cropBottom - cropAmount)
    else
        icon:SetSize(size, size)
        icon:SetTexCoord(0, 1, 0, 1) -- Полная иконка для квадратных
    end
end

local function CreateAuraIcon(frame, size, width, height, noBorder)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    ApplyIconGeometry(icon, size, width, height)
    icon:SetPoint("CENTER", frame, "CENTER")

    if not frame.cooldownText then
        local cooldownText = frame:CreateFontString(nil, "OVERLAY")
        cooldownText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        cooldownText:SetPoint("CENTER", frame, "CENTER")
        cooldownText:SetTextColor(1, 1, 1, 1)
        frame.cooldownText = cooldownText
    end

    if not frame.stackText then
        local stackText = frame:CreateFontString(nil, "OVERLAY")
        stackText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        stackText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -4)
        stackText:SetTextColor(1, 1, 0, 1) -- Жёлтый цвет для стаков
        frame.stackText = stackText
    end

    if not noBorder and not frame.border then
        frame.border = frame:CreateTexture(nil, "OVERLAY")
        frame.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        frame.border:SetBlendMode("ADD")
        frame.border:SetAlpha(0)
        frame.border:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        frame.border:SetPoint("CENTER", icon, "CENTER", .4, .5)
    end

    local function UpdateBorderSize()
        if noBorder or not frame.border then return end
        
        local iconWidth, iconHeight = icon:GetSize()
        local borderWidth, borderHeight

        if size == ICON_SIZE_CONTROL then
            borderWidth = iconWidth * 1.67
            borderHeight = borderWidth
        elseif size == ICON_SIZE_CAST then
            borderWidth = iconWidth * 1.67
            borderHeight = borderWidth
        elseif size == ICON_SIZE_MOBILITY then
            borderWidth = iconWidth * 1.67
            borderHeight = borderWidth
        elseif size == ICON_SIZE_OTHER then
            borderWidth = iconWidth * 1.67
            borderHeight = borderWidth
        elseif size == ICON_SIZE_PLAYER then
            -- Для прямоугольных иконок делаем border прямоугольным с теми же пропорциями
            borderWidth = iconWidth * 1.67
            borderHeight = iconHeight * 1.67
        else
            borderWidth = iconWidth * 1.5
            borderHeight = borderWidth
        end

        frame.border:SetSize(borderWidth, borderHeight)
    end

    local GlowLib = SarychUI and SarychUI.PlatesAurasGlow
    if GlowLib and GlowLib.Install then
        GlowLib.Install(frame)
    else
        frame.ShowGlowEffect = frame.ShowGlowEffect or function() end
        frame.HideGlowEffect = frame.HideGlowEffect or function() end
        frame.ShowBorderEffect = frame.ShowGlowEffect
        frame.HideBorderEffect = frame.HideGlowEffect
    end
    frame.UpdateBorderSize = UpdateBorderSize
    frame.auraIcon = icon

    UpdateBorderSize()

    return icon
end

local function FormatTimeLeft(timeLeft)
    if timeLeft < 1 then
        return format(" %.1f ", timeLeft)
    elseif timeLeft < 60 then
        return format(" %.0f ", timeLeft)
    else
        local minutes = floor(timeLeft / 60)
        local seconds = timeLeft % 60
        return format(" %d:%02d ", minutes, seconds)
    end
end

local function GetAuraTexture(frame)
    return frame and (frame.auraIcon or frame.icon)
end

local function SetCooldownText(frame, text)
    if not frame or not frame.cooldownText then return end
    text = text or ""
    if frame.cooldownText.__SarychUILastText ~= text then
        frame.cooldownText:SetText(text)
        frame.cooldownText.__SarychUILastText = text
    end
    frame.__sarAuraLastCooldownText = text
end

local function SetStackText(frame, text)
    if not frame or not frame.stackText then return end
    text = text or ""
    if frame.stackText.__SarychUILastText ~= text then
        frame.stackText:SetText(text)
        frame.stackText.__SarychUILastText = text
    end
    frame.__sarAuraLastStackText = text
end

local function ClearAuraText(frame)
    SetCooldownText(frame, "")
    SetStackText(frame, "")
end

local function UpdateCooldownText(frame, expirationTime, duration, stackCount)
    if not frame.cooldownText then 
        -- Создаем cooldownText если его нет
        local cooldownText = frame:CreateFontString(nil, "OVERLAY")
        cooldownText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        cooldownText:SetPoint("CENTER", frame, "CENTER")
        cooldownText:SetTextColor(1, 1, 1, 1)
        frame.cooldownText = cooldownText
    end

    -- Обновляем стаки
    local stackText = ""
    if stackCount and stackCount > 1 then
        stackText = tostring(stackCount)
    end
    SetStackText(frame, stackText)

    local normalizedStack = stackCount or 0
    local hasOnUpdate = frame:GetScript("OnUpdate") ~= nil

    if not expirationTime or expirationTime == 0 or duration == 0 then
        ClearAuraText(frame)
        frame:SetScript("OnUpdate", nil)
        frame.__sarAuraExpirationTime = expirationTime
        frame.__sarAuraDuration = duration
        frame.__sarAuraLastStackCount = normalizedStack
        return
    end

    if hasOnUpdate
        and frame.__sarAuraExpirationTime == expirationTime
        and frame.__sarAuraDuration == duration
        and frame.__sarAuraLastStackCount == normalizedStack then
        return
    end

    frame.__sarAuraExpirationTime = expirationTime
    frame.__sarAuraDuration = duration
    frame.__sarAuraLastStackCount = normalizedStack

    local initialTimeLeft = expirationTime - GetTime()
    if initialTimeLeft > 0 then
        SetCooldownText(frame, FormatTimeLeft(initialTimeLeft))
    else
        ClearAuraText(frame)
        frame:SetScript("OnUpdate", nil)
        return
    end

    local function OnUpdate(self, elapsed)
        self.__sarAuraCooldownElapsed = (self.__sarAuraCooldownElapsed or 0) + (elapsed or 0)
        if self.__sarAuraCooldownElapsed < COOLDOWN_TEXT_UPDATE_INTERVAL then
            return
        end
        self.__sarAuraCooldownElapsed = 0
        -- Проверяем, что фрейм и иконка все еще существуют
        local auraTexture = GetAuraTexture(self)
        if not self or not self.cooldownText or not auraTexture then
            self:SetScript("OnUpdate", nil)
            return
        end

        if not auraTexture:IsShown() then
            ClearAuraText(self)
            self:SetScript("OnUpdate", nil)
            return
        end

        local timeLeft = (self.__sarAuraExpirationTime or 0) - GetTime()
        if timeLeft > 0 then
            local text = FormatTimeLeft(timeLeft)
            SetCooldownText(self, text)
        else
            ClearAuraText(self)
            if auraTexture then auraTexture:Hide() end
            if self.HideGlowEffect then self.HideGlowEffect() end
            if self.HideBorderEffect then self.HideBorderEffect() end
            self:SetScript("OnUpdate", nil)
        end
    end

    -- Устанавливаем скрипт
    frame:SetScript("OnUpdate", OnUpdate)
end

local function CreateOtherAuraIcons(frame, size)
    frame.auraIcons = {}
    frame._sarShapeAlt = nil
    frame._sarAncAlt = nil

    for i = 1, MAX_PLAYER_AURAS do
        local auraFrame = CreateFrame("Frame", nil, frame)
        auraFrame:SetSize(size, size * 0.67) -- размер фрейма зависит от ICON_SIZE_PLAYER

        local offsetX
        if i == 1 then
            offsetX = 0
        elseif i % 2 == 0 then
            offsetX = (i / 2) * (size + GetPlayerIconSpacing())
        else
            offsetX = -ceil(i / 2) * (size + GetPlayerIconSpacing())
        end

        auraFrame:SetPoint("CENTER", frame, "CENTER", offsetX, 0)

        local icon = CreateAuraIcon(auraFrame, size, size, size * 0.67, false)
        auraFrame.icon = icon
        frame.auraIcons[i] = auraFrame
    end
end

local function GetAuraPriority(spellId, desiredTypes)
    local spellInfo = SPELL_DATA[spellId]
    if spellInfo then
        for _, auraType in ipairs(desiredTypes) do
            if spellInfo.type == auraType then
                return PRIORITY_ORDER[auraType], spellInfo.priority or 100, auraType
            end
        end
    end
    return nil, nil, nil
end

local function FindBestAuraFromCache(foundAuras, auraTypes)
    local bestAura = nil
    local bestSpellId = nil
    local highestGroupPriority = 0
    local bestSpellPriority = 100

    for spellId, auraData in pairs(foundAuras) do
        local groupPriority, spellPriority, auraType = GetAuraPriority(spellId, auraTypes)
        if groupPriority then
            if (groupPriority > highestGroupPriority) or (groupPriority == highestGroupPriority and spellPriority < bestSpellPriority) then
                highestGroupPriority = groupPriority
                bestSpellPriority = spellPriority
                bestAura = { 
                    iconTexture = auraData.iconTexture, 
                    duration = auraData.duration, 
                    expirationTime = auraData.expirationTime, 
                    stackCount = auraData.stackCount 
                }
                bestSpellId = spellId
            end
        end
    end

    return bestAura, bestSpellId
end

local function FindOtherAurasFromCache(foundAuras)
    local otherAuras = {}

    for spellId, auraData in pairs(foundAuras) do
        if auraData.type == "other" then
            -- Проверяем, наложена ли аура игроком
            local isPlayerCaster = auraData.caster == "player"
            -- Проверяем, разрешено ли отображение от других игроков для этого заклинания
            local spellInfo = SPELL_DATA[spellId]
            local allowFromOthers = spellInfo and spellInfo.allowFromOthers == true
            
            -- Показываем ауру, если она наложена игроком ИЛИ разрешено от других
            if isPlayerCaster or allowFromOthers then
                tinsert(otherAuras, { 
                    iconTexture = auraData.iconTexture, 
                    duration = auraData.duration, 
                    expirationTime = auraData.expirationTime, 
                    spellId = spellId,
                    priority = auraData.priority,
                    stackCount = auraData.stackCount
                })
            end
        end
    end

    tsort(otherAuras, function(a, b)
        return a.priority < b.priority
    end)

    return otherAuras
end

local function IsSpellGlowEnabled(spellId)
	local data = spellId and SPELL_DATA and SPELL_DATA[spellId]
	if not data then
		return false
	end
	local highlight = data.highlight
	return highlight ~= nil and highlight ~= false and highlight ~= 0
end

local function HideAuraGlow(frame)
	if not frame then
		return
	end
	frame._sarGlowSpellId = nil
	frame._sarychGlowSpellApplied = nil
	if frame.HideGlowEffect then
		frame.HideGlowEffect()
	end
	if frame.HideBorderEffect then
		frame.HideBorderEffect()
	end
end

local function ApplyStoredAuraGlow(frame)
	if not frame then
		return
	end
	local spellId = frame._sarGlowSpellId
	if not IsSpellGlowEnabled(spellId) then
		HideAuraGlow(frame)
		return
	end
	if frame._sarychGlowSpellApplied == spellId and frame._sarychGlowType then
		local GlowLib = SarychUI and SarychUI.PlatesAurasGlow
		if GlowLib and GlowLib.Fit then
			GlowLib.Fit(frame)
		end
		return
	end
	if frame.ShowGlowEffect then
		frame.ShowGlowEffect(spellId)
	elseif frame.ShowBorderEffect then
		frame.ShowBorderEffect(spellId)
	end
	frame._sarychGlowSpellApplied = spellId
end

local function ApplyAllPlateGlows(namePlate)
	if not namePlate then
		return
	end
	ApplyStoredAuraGlow(namePlate.controlFrame)
	ApplyStoredAuraGlow(namePlate.castFrame)
	ApplyStoredAuraGlow(namePlate.mobilityFrame)
	ApplyStoredAuraGlow(namePlate.otherFrame)
	local icons = namePlate.playerFrame and namePlate.playerFrame.auraIcons
	if not icons then
		return
	end
	for i = 1, #icons do
		ApplyStoredAuraGlow(icons[i])
	end
end

local function UpdateAuraFrameFromCache(namePlate, frame, size, foundAuras, auraTypes)
	if not frame or not frame.auraIcon then return end
	
    local bestAura, bestSpellId = FindBestAuraFromCache(foundAuras, auraTypes)

    if bestAura then
        frame.auraIcon:SetTexture(bestAura.iconTexture)
        frame.auraIcon:Show()
        frame._sarGlowSpellId = IsSpellGlowEnabled(bestSpellId) and bestSpellId or nil
        
        if frame.cooldownText then
            if bestAura.duration and bestAura.duration > 0 and bestAura.expirationTime then
                UpdateCooldownText(frame, bestAura.expirationTime, bestAura.duration, bestAura.stackCount)
            else
                ClearAuraText(frame)
                frame:SetScript("OnUpdate", nil)
            end
        end
    else
        frame.auraIcon:Hide()
        HideAuraGlow(frame)
        ClearAuraText(frame)
        frame:SetScript("OnUpdate", nil)
    end
end

-- Player strip has two shapes. Default: one horizontal row under the center icons.
-- Alternative: a block on the right, two icons per row, growing upward, resting on
-- top of the mob/other icons.
local PLAYER_ALT_COLUMNS = 2

local function IsPlayerAltRight()
    -- Global first: ApplyProfileGlobals keeps it in sync, and reading the profile on
    -- every nameplate would rebuild the default tables each time.
    local altRight = _G.PLAYER_ALT_RIGHT
    if altRight == nil then
        local profile = GetActiveDisplayProfile()
        local player = profile and profile.layout and profile.layout.player
        altRight = player and player.altRight
    end
    return altRight and true or false
end

-- CC/cast only lift when the player strip sits under them. Alt-right hangs
-- those icons off the right block, so the center uses the empty-strip anchor.
local CLASSIC_NO_PLAYER_LIFT = 30

local function CenterLiftsForPlayerIcons(namePlate)
    if IsPlayerAltRight() then
        return false
    end
    return HasVisiblePlayerIcons(namePlate)
end

local function HasVisibleRightIcons(namePlate)
    if not namePlate then return false end
    if namePlate.mobilityFrame and namePlate.mobilityFrame.auraIcon and namePlate.mobilityFrame.auraIcon:IsShown() then
        return true
    end
    if namePlate.otherFrame and namePlate.otherFrame.auraIcon and namePlate.otherFrame.auraIcon:IsShown() then
        return true
    end
    return false
end

-- Alt mode shows whole square icons, exactly like the mob/other slots. Default mode
-- keeps the wide cropped strip.
local function GetPlayerIconSize()
    if IsPlayerAltRight() then
        return ICON_SIZE_PLAYER, ICON_SIZE_PLAYER
    end
    return ICON_SIZE_PLAYER, ICON_SIZE_PLAYER * 0.67
end

local function ApplyPlayerIconShape(auraFrame, altRight, width, height)
    if not auraFrame then return end
    if auraFrame._sarAlt == altRight and auraFrame._sarW == width and auraFrame._sarH == height then
        return
    end
    auraFrame:SetSize(width, height)
    if auraFrame.icon then
        if altRight then
            ApplyIconGeometry(auraFrame.icon, width)
        else
            ApplyIconGeometry(auraFrame.icon, ICON_SIZE_PLAYER, width, height)
        end
    end
    if auraFrame.UpdateBorderSize then auraFrame.UpdateBorderSize() end
    auraFrame._sarAlt = altRight
    auraFrame._sarW = width
    auraFrame._sarH = height
end

local function ApplyPlayerIconShapes(namePlate)
    if not namePlate or not namePlate.playerFrame or not namePlate.playerFrame.auraIcons then return end
    local altRight = IsPlayerAltRight()
    local width, height = GetPlayerIconSize()
    local playerFrame = namePlate.playerFrame
    if playerFrame._sarShapeAlt == altRight and playerFrame._sarShapeW == width and playerFrame._sarShapeH == height then
        return
    end
    for _, auraFrame in ipairs(playerFrame.auraIcons) do
        ApplyPlayerIconShape(auraFrame, altRight, width, height)
    end
    playerFrame._sarShapeAlt = altRight
    playerFrame._sarShapeW = width
    playerFrame._sarShapeH = height
end

-- Single owner of the player container's size and anchor, so every call site
-- (frame creation, size refresh, aura refresh, ElvUI re-anchor) agrees.
local function AnchorPlayerFrame(namePlate)
    if not namePlate or not namePlate.playerFrame then return end

    local spacing = GetPlayerIconSpacing()
    local iconWidth, iconHeight = GetPlayerIconSize()
    local altRight = IsPlayerAltRight() and namePlate.mobilityContainer and true or false
    local hasRight = altRight and HasVisibleRightIcons(namePlate)
    local elv = UsesElvUILayout()
    local offsetY = PlayerOffsetY or 0
    local healthW, healthH = 0, 0
    if elv and not altRight then
        local layout = SarychUI.PlatesAurasElvUI
        local unitFrame = layout and layout.GetElvUIUnitFrame and layout.GetElvUIUnitFrame(namePlate)
        local health = unitFrame and unitFrame.Health
        if health then
            healthW = health:GetWidth() or 0
            healthH = health:GetHeight() or 0
        end
    end

    local pf = namePlate.playerFrame
    if pf._sarAncAlt == altRight
        and pf._sarAncRight == hasRight
        and pf._sarAncW == iconWidth
        and pf._sarAncH == iconHeight
        and pf._sarAncSp == spacing
        and pf._sarAncElv == elv
        and pf._sarAncMax == MAX_PLAYER_AURAS
        and pf._sarAncOY == offsetY
        and pf._sarAncHW == healthW
        and pf._sarAncHH == healthH then
        return
    end

    pf:ClearAllPoints()

    if altRight then
        -- Own construction, not an offset off the center strip: the block hangs on the
        -- right container, which both backends already place (classic pins it to the
        -- plate, ElvUI to the health bar), so it follows the mob/other icons.
        pf:SetSize(PLAYER_ALT_COLUMNS * iconWidth + spacing, iconHeight)
        if elv then
            -- Keep it a sibling of the right container so SetScale stays absolute.
            local parent = namePlate.mobilityContainer:GetParent()
            if parent and pf:GetParent() ~= parent then
                pf:SetParent(parent)
            end
        end
        if hasRight then
            pf:SetPoint("BOTTOMLEFT", namePlate.mobilityContainer, "TOPLEFT", 0, spacing)
        else
            -- Nothing on the right: take that spot instead of floating above it.
            pf:SetPoint("BOTTOMLEFT", namePlate.mobilityContainer, "BOTTOMLEFT", 0, 0)
        end
    else
        pf:SetSize(ICON_SIZE_PLAYER * MAX_PLAYER_AURAS, iconHeight)

        if elv then
            local layout = SarychUI.PlatesAurasElvUI
            if layout and layout.ApplySlotAnchor then
                layout.ApplySlotAnchor(pf, namePlate, "player")
            end
        elseif namePlate.centerContainer then
            pf:SetPoint("TOP", namePlate.centerContainer, "BOTTOM", 0, offsetY)
        end
    end

    pf._sarAncAlt = altRight
    pf._sarAncRight = hasRight
    pf._sarAncW = iconWidth
    pf._sarAncH = iconHeight
    pf._sarAncSp = spacing
    pf._sarAncElv = elv
    pf._sarAncMax = MAX_PLAYER_AURAS
    pf._sarAncOY = offsetY
    pf._sarAncHW = healthW
    pf._sarAncHH = healthH
end

-- ElvUI's own anchor pass would otherwise drag the block back under the center icons.
_G.sarPlatesAuras_IsPlayerAltRight = IsPlayerAltRight
_G.sarPlatesAuras_AnchorPlayerFrame = AnchorPlayerFrame

local function UpdateCenterFramesPosition(namePlate)
    -- Check if centerContainer exists
    if not namePlate or not namePlate.centerContainer then return end
    
    local hasControlAura = namePlate.controlFrame and namePlate.controlFrame.auraIcon and namePlate.controlFrame.auraIcon:IsShown()
    local hasCastAura = namePlate.castFrame and namePlate.castFrame.auraIcon and namePlate.castFrame.auraIcon:IsShown()
    
    local activeCenterFrames = 0
    if hasControlAura then activeCenterFrames = activeCenterFrames + 1 end
    if hasCastAura then activeCenterFrames = activeCenterFrames + 1 end
    
    -- If the player strip sits under center, lift CC/cast; else use the empty-strip
    -- anchor. Alt-right never occupies that hole, so it always uses the lowered seat.
    local hasVisibleIcons = CenterLiftsForPlayerIcons(namePlate)
    local yOffset = hasVisibleIcons and CentrY or (CentrY - CLASSIC_NO_PLAYER_LIFT)
    
    -- Позиционируем контейнер
    if UsesElvUILayout() then
        local layout = SarychUI.PlatesAurasElvUI
        if layout and layout.UpdateElvUIAuraAnchor then
            layout.UpdateElvUIAuraAnchor(namePlate, {
                hasVisiblePlayerIcons = hasVisibleIcons,
            })
        end
    else
        namePlate.centerContainer:ClearAllPoints()
        namePlate.centerContainer:SetPoint("CENTER", namePlate, "TOP", 0, yOffset)
    end
    
    -- Позиционируем фреймы внутри контейнера - центрируем как раньше
    if activeCenterFrames == 0 then
        -- Нет активных фреймов - оба в центре контейнера
        namePlate.controlFrame:ClearAllPoints()
        namePlate.controlFrame:SetPoint("CENTER", namePlate.centerContainer, "CENTER", 0, 0)
        namePlate.castFrame:ClearAllPoints()
        namePlate.castFrame:SetPoint("CENTER", namePlate.centerContainer, "CENTER", 0, 0)
    elseif activeCenterFrames == 1 then
        -- Один активный фрейм - по центру контейнера
        if hasControlAura then
            namePlate.controlFrame:ClearAllPoints()
            namePlate.controlFrame:SetPoint("CENTER", namePlate.centerContainer, "CENTER", 0, 0)
        end
        if hasCastAura then
            namePlate.castFrame:ClearAllPoints()
            namePlate.castFrame:SetPoint("CENTER", namePlate.centerContainer, "CENTER", 0, 0)
        end
    else
        -- Два активных фрейма - по краям контейнера
        namePlate.controlFrame:ClearAllPoints()
        namePlate.controlFrame:SetPoint("LEFT", namePlate.centerContainer, "LEFT", 0, 0)
        namePlate.castFrame:ClearAllPoints()
        namePlate.castFrame:SetPoint("RIGHT", namePlate.centerContainer, "RIGHT", 0, 0)
    end
end

local function UpdateMobilityFramesPosition(namePlate)
    -- Check if mobilityContainer exists
    if not namePlate or not namePlate.mobilityContainer then return end
    
    local hasMobilityAura = namePlate.mobilityFrame and namePlate.mobilityFrame.auraIcon and namePlate.mobilityFrame.auraIcon:IsShown()
    local hasOtherAura = namePlate.otherFrame and namePlate.otherFrame.auraIcon and namePlate.otherFrame.auraIcon:IsShown()
    
    local activeMobilityFrames = 0
    if hasMobilityAura then activeMobilityFrames = activeMobilityFrames + 1 end
    if hasOtherAura then activeMobilityFrames = activeMobilityFrames + 1 end
    
    -- Позиционируем контейнер
    if not UsesElvUILayout() then
        namePlate.mobilityContainer:ClearAllPoints()
        namePlate.mobilityContainer:SetPoint("LEFT", namePlate, "RIGHT", RightX, RightY)
    end
    
    -- Позиционируем фреймы внутри контейнера - сначала OTHER, потом MOBILITY
    if activeMobilityFrames == 0 then
        -- Нет активных фреймов - оба скрыты
        namePlate.otherFrame:ClearAllPoints()
        namePlate.otherFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        namePlate.mobilityFrame:ClearAllPoints()
        namePlate.mobilityFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
    elseif activeMobilityFrames == 1 then
        -- Один активный фрейм - слева
        if hasOtherAura then
            namePlate.otherFrame:ClearAllPoints()
            namePlate.otherFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        end
        if hasMobilityAura then
            namePlate.mobilityFrame:ClearAllPoints()
            namePlate.mobilityFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        end
    else
        -- Два активных фрейма - сначала OTHER, потом MOBILITY
        namePlate.otherFrame:ClearAllPoints()
        namePlate.otherFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        namePlate.mobilityFrame:ClearAllPoints()
        namePlate.mobilityFrame:SetPoint("LEFT", namePlate.otherFrame, "RIGHT", 4, 0)
    end

    -- In the alternative shape the player block sits on top of these icons, so it
    -- has to be re-anchored whenever their visibility changes.
    if IsPlayerAltRight() then
        AnchorPlayerFrame(namePlate)
    end
end

local function UpdateOtherAurasFromCache(namePlate, foundAuras)
    local otherAuras = FindOtherAurasFromCache(foundAuras)
    local activeAuraCount = #otherAuras

    if not namePlate.playerFrame or not namePlate.playerFrame.auraIcons then
        return
    end
    
    -- Сначала позиционируем playerFrame
    AnchorPlayerFrame(namePlate)
    ApplyPlayerIconShapes(namePlate)
    if UsesElvUILayout() then
        local layout = SarychUI.PlatesAurasElvUI
        if layout and layout.UpdatePlateResponsiveScale then
            layout.UpdatePlateResponsiveScale(namePlate, {
                hasVisiblePlayerIcons = activeAuraCount > 0,
            })
        end
    end

    -- Скрываем все иконки и сбрасываем их позиции
    for i = 1, MAX_PLAYER_AURAS do
        local auraFrame = namePlate.playerFrame.auraIcons[i]
        if auraFrame and i > activeAuraCount then
            auraFrame:ClearAllPoints()
            auraFrame:Hide()  -- Скрываем весь фрейм, а не только иконку
            auraFrame.icon:Hide()
            ClearAuraText(auraFrame)
            auraFrame:SetScript("OnUpdate", nil)
            HideAuraGlow(auraFrame)
        end
    end

    if activeAuraCount == 0 then
        UpdateCenterFramesPosition(namePlate)
        return
    end

    local playerSpacing = GetPlayerIconSpacing()
    local altRight = IsPlayerAltRight()
    local iconWidth, iconHeight = GetPlayerIconSize()
    local stepX = iconWidth + playerSpacing
    local stepY = iconHeight + playerSpacing
    local startX = altRight and 0 or (-((activeAuraCount - 1) * stepX) / 2)

    -- Устанавливаем позиции и показываем только активные ауры
    for i = 1, activeAuraCount do
        local aura = otherAuras[i]
        local auraFrame = namePlate.playerFrame.auraIcons[i]

        -- Сбрасываем позицию и устанавливаем новую
        auraFrame:ClearAllPoints()
        if altRight then
            -- Fill left to right, two per row, then start a new row above.
            local column = (i - 1) % PLAYER_ALT_COLUMNS
            local row = floor((i - 1) / PLAYER_ALT_COLUMNS)
            auraFrame:SetPoint("BOTTOMLEFT", namePlate.playerFrame, "BOTTOMLEFT", column * stepX, row * stepY)
        else
            auraFrame:SetPoint("CENTER", namePlate.playerFrame, "CENTER", startX + (i - 1) * stepX, 0)
        end
        
        auraFrame:Show()  -- Показываем весь фрейм
        auraFrame.icon:SetTexture(aura.iconTexture)
        auraFrame.icon:Show()
        auraFrame._sarGlowSpellId = IsSpellGlowEnabled(aura.spellId) and aura.spellId or nil

        if aura.duration and aura.duration > 0 and aura.expirationTime then
            UpdateCooldownText(auraFrame, aura.expirationTime, aura.duration, aura.stackCount)
        else
            ClearAuraText(auraFrame)
        end
    end

    -- Обновляем позиции центральных фреймов
    UpdateCenterFramesPosition(namePlate)
end

local lastUnitAuraUpdate = {}

local function ShouldUpdateAura(unitId)
    local lastUpdateTime = lastUnitAuraUpdate[unitId] or 0
    if (GetTime() - lastUpdateTime) < 0.5 then
        return false
    end
    lastUnitAuraUpdate[unitId] = GetTime()
    return true
end

function _G.UpdateAuras(namePlate, unitId, forcedGuid)
    local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
    if IsTestModeEnabled() then
        return
    end

    namePlate = NormalizeRootPlate(namePlate) or namePlate
    if not namePlate then
        return
    end

    -- Get GUID from nameplate (primary method - most reliable)
    local plateGUID = nil
    if UseAwesomeWotlk() then
        -- For C_NamePlate, get GUID from unitId
        if unitId and namePlate.namePlateUnitToken == unitId then
            plateGUID = UnitGUID(unitId)
        elseif unitId and UnitExists(unitId) then
            plateGUID = UnitGUID(unitId)
        end
    else
        -- PlateBuffs bridge always passes forcedGuid (AddBuffsToPlate equivalent).
        -- Never invent GUID from unit token / name / alpha — that was the wrong-plate mess.
        plateGUID = forcedGuid
        if not plateGUID then
            HidePlateAuras(namePlate)
            return
        end
        if unitId and UnitExists(unitId) then
            local unitGUID = UnitGUID(unitId)
            if unitGUID and unitGUID ~= plateGUID then
                unitId = nil
            end
        end
    end
    
    -- Fallback for Awesome path only
    if UseAwesomeWotlk() and not plateGUID and unitId and UnitExists(unitId) then
        plateGUID = UnitGUID(unitId)
    end
    
    -- If we still don't have GUID, we can't reliably match this nameplate
    -- Don't show auras to avoid showing on wrong nameplates
    if not plateGUID then
        HidePlateAuras(namePlate)
        return
    end
    
    -- First, hide all aura icons to ensure disabled spells disappear.
    -- Do not restart glow here; it is reconciled after the aura pass.
    if namePlate.controlFrame then
        if namePlate.controlFrame.auraIcon then
            namePlate.controlFrame.auraIcon:Hide()
        end
    end
    if namePlate.castFrame then
        if namePlate.castFrame.auraIcon then
            namePlate.castFrame.auraIcon:Hide()
        end
    end
    if namePlate.mobilityFrame then
        if namePlate.mobilityFrame.auraIcon then
            namePlate.mobilityFrame.auraIcon:Hide()
        end
    end
    if namePlate.otherFrame then
        if namePlate.otherFrame.auraIcon then
            namePlate.otherFrame.auraIcon:Hide()
        end
    end
    if namePlate.playerFrame and namePlate.playerFrame.auraIcons then
        for i = 1, #namePlate.playerFrame.auraIcons do
            if namePlate.playerFrame.auraIcons[i] then
                if namePlate.playerFrame.auraIcons[i].icon then
                    namePlate.playerFrame.auraIcons[i].icon:Hide()
                end
            end
        end
    end

    -- Get display settings
    local profile = GetActiveDisplayProfile()
    local alpha = (profile and profile.display and profile.display.alpha) or 1
    local scale = (profile and profile.display and profile.display.scale) or 1
    
    -- Создаем общий контейнерный фрейм для центральных фреймов
    local containerParent = GetAuraContainerParent(namePlate)
    if not namePlate.centerContainer then
        namePlate.centerContainer = CreateFrame("Frame", nil, containerParent)
    elseif UsesElvUILayout() and namePlate.centerContainer:GetParent() ~= containerParent then
        namePlate.centerContainer:SetParent(containerParent)
    end
    namePlate.centerContainer:SetSize(ICON_SIZE_CONTROL + ICON_SIZE_CAST + 4, ICON_SIZE_CONTROL)
    if not UsesElvUILayout() then
        namePlate.centerContainer:ClearAllPoints()
        namePlate.centerContainer:SetPoint("CENTER", namePlate, "TOP", 0, CentrY)
    end
    namePlate.centerContainer:SetAlpha(alpha)
    ApplyAuraContainerScale(namePlate, namePlate.centerContainer, "center", scale)

    if not namePlate.controlFrame then
        namePlate.controlFrame = CreateFrame("Frame", nil, namePlate.centerContainer)
        namePlate.controlFrame:SetSize(ICON_SIZE_CONTROL, ICON_SIZE_CONTROL)
        namePlate.controlFrame:SetPoint("LEFT", namePlate.centerContainer, "LEFT", 0, 0)
    end

    if not namePlate.controlFrame.auraIcon then
        namePlate.controlFrame.auraIcon = CreateAuraIcon(namePlate.controlFrame, ICON_SIZE_CONTROL)
    end
    
    -- Убеждаемся, что cooldownText и stackText созданы
    if not namePlate.controlFrame.cooldownText then
        local cooldownText = namePlate.controlFrame:CreateFontString(nil, "OVERLAY")
        cooldownText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        cooldownText:SetPoint("CENTER", namePlate.controlFrame, "CENTER")
        cooldownText:SetTextColor(1, 1, 1, 1)
        namePlate.controlFrame.cooldownText = cooldownText
    end
    if not namePlate.controlFrame.stackText then
        local stackText = namePlate.controlFrame:CreateFontString(nil, "OVERLAY")
        stackText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        stackText:SetPoint("BOTTOMRIGHT", namePlate.controlFrame, "BOTTOMRIGHT", 2, -4)
        stackText:SetTextColor(1, 1, 0, 1)
        namePlate.controlFrame.stackText = stackText
    end

    if not namePlate.castFrame then
        namePlate.castFrame = CreateFrame("Frame", nil, namePlate.centerContainer)
        namePlate.castFrame:SetSize(ICON_SIZE_CAST, ICON_SIZE_CAST)
        namePlate.castFrame:SetPoint("RIGHT", namePlate.centerContainer, "RIGHT", 0, 0)
        namePlate.castFrame.auraIcon = CreateAuraIcon(namePlate.castFrame, ICON_SIZE_CAST)
    end
    
    -- Убеждаемся, что cooldownText и stackText созданы
    if not namePlate.castFrame.cooldownText then
        local cooldownText = namePlate.castFrame:CreateFontString(nil, "OVERLAY")
        cooldownText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        cooldownText:SetPoint("CENTER", namePlate.castFrame, "CENTER")
        cooldownText:SetTextColor(1, 1, 1, 1)
        namePlate.castFrame.cooldownText = cooldownText
    end
    if not namePlate.castFrame.stackText then
        local stackText = namePlate.castFrame:CreateFontString(nil, "OVERLAY")
        stackText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        stackText:SetPoint("BOTTOMRIGHT", namePlate.castFrame, "BOTTOMRIGHT", 2, -4)
        stackText:SetTextColor(1, 1, 0, 1)
        namePlate.castFrame.stackText = stackText
    end

    -- Создаем общий контейнерный фрейм для mobility фреймов
    if not namePlate.mobilityContainer then
        namePlate.mobilityContainer = CreateFrame("Frame", nil, containerParent)
    elseif UsesElvUILayout() and namePlate.mobilityContainer:GetParent() ~= containerParent then
        namePlate.mobilityContainer:SetParent(containerParent)
    end
    namePlate.mobilityContainer:SetSize(ICON_SIZE_MOBILITY + ICON_SIZE_OTHER + 4, ICON_SIZE_MOBILITY)
    if not UsesElvUILayout() then
        namePlate.mobilityContainer:ClearAllPoints()
        namePlate.mobilityContainer:SetPoint("LEFT", namePlate, "RIGHT", RightX, RightY)
    end
    namePlate.mobilityContainer:SetAlpha(alpha)
    namePlate.mobilityContainer:SetScale(scale)

    if not namePlate.mobilityFrame then
        namePlate.mobilityFrame = CreateFrame("Frame", nil, namePlate.mobilityContainer)
        namePlate.mobilityFrame:SetSize(ICON_SIZE_MOBILITY, ICON_SIZE_MOBILITY)
        namePlate.mobilityFrame:SetPoint("LEFT", namePlate.mobilityContainer, "LEFT", 0, 0)
        namePlate.mobilityFrame.auraIcon = CreateAuraIcon(namePlate.mobilityFrame, ICON_SIZE_MOBILITY)
    end
    
    -- Убеждаемся, что cooldownText и stackText созданы
    if not namePlate.mobilityFrame.cooldownText then
        local cooldownText = namePlate.mobilityFrame:CreateFontString(nil, "OVERLAY")
        cooldownText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        cooldownText:SetPoint("CENTER", namePlate.mobilityFrame, "CENTER")
        cooldownText:SetTextColor(1, 1, 1, 1)
        namePlate.mobilityFrame.cooldownText = cooldownText
    end
    if not namePlate.mobilityFrame.stackText then
        local stackText = namePlate.mobilityFrame:CreateFontString(nil, "OVERLAY")
        stackText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        stackText:SetPoint("BOTTOMRIGHT", namePlate.mobilityFrame, "BOTTOMRIGHT", 2, -4)
        stackText:SetTextColor(1, 1, 0, 1)
        namePlate.mobilityFrame.stackText = stackText
    end

    if not namePlate.otherFrame then
        namePlate.otherFrame = CreateFrame("Frame", nil, namePlate.mobilityContainer)
        namePlate.otherFrame:SetSize(ICON_SIZE_OTHER, ICON_SIZE_OTHER)
        namePlate.otherFrame:SetPoint("RIGHT", namePlate.mobilityContainer, "RIGHT", 0, 0)
        namePlate.otherFrame.auraIcon = CreateAuraIcon(namePlate.otherFrame, ICON_SIZE_OTHER)
    end
    
    -- Убеждаемся, что cooldownText и stackText созданы
    if not namePlate.otherFrame.cooldownText then
        local cooldownText = namePlate.otherFrame:CreateFontString(nil, "OVERLAY")
        cooldownText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        cooldownText:SetPoint("CENTER", namePlate.otherFrame, "CENTER")
        cooldownText:SetTextColor(1, 1, 1, 1)
        namePlate.otherFrame.cooldownText = cooldownText
    end
    if not namePlate.otherFrame.stackText then
        local stackText = namePlate.otherFrame:CreateFontString(nil, "OVERLAY")
        stackText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        stackText:SetPoint("BOTTOMRIGHT", namePlate.otherFrame, "BOTTOMRIGHT", 2, -4)
        stackText:SetTextColor(1, 1, 0, 1)
        namePlate.otherFrame.stackText = stackText
    end

    if not namePlate.playerFrame then
        -- Same parent as centerContainer (unitFrame/plate). ElvUI layout owns re-parent/scale.
        namePlate.playerFrame = CreateFrame("Frame", nil, containerParent)
        CreateOtherAuraIcons(namePlate.playerFrame, ICON_SIZE_PLAYER)
    elseif namePlate.playerFrame:GetParent() ~= containerParent then
        -- ElvUI ApplySlotAnchor may briefly move parent; keep classic path on containerParent.
        if not UsesElvUILayout() then
            namePlate.playerFrame:SetParent(containerParent)
        end
    end
    if not UsesElvUILayout() or IsPlayerAltRight() then
        AnchorPlayerFrame(namePlate)
    else
        namePlate.playerFrame:SetSize(ICON_SIZE_PLAYER * MAX_PLAYER_AURAS, ICON_SIZE_PLAYER * 0.67)
        namePlate.playerFrame:ClearAllPoints()
    end
    ApplyPlayerIconShapes(namePlate)
    namePlate.playerFrame:SetAlpha(alpha)
    if UsesElvUILayout() then
        local layout = SarychUI.PlatesAurasElvUI
        if layout and layout.UpdatePlateResponsiveScale then
            layout.UpdatePlateResponsiveScale(namePlate, { baseScale = scale, source = "ensure-frames" })
        else
            ApplyAuraContainerScale(namePlate, namePlate.playerFrame, "player", scale)
        end
    else
        ApplyAuraContainerScale(namePlate, namePlate.playerFrame, "player", scale)
    end

    -- Verify GUID matches unitId before showing auras (double-check)
    if unitId and UnitExists(unitId) then
        local unitGUID = UnitGUID(unitId)
        if unitGUID and unitGUID ~= plateGUID then
            HidePlateAuras(namePlate)
            return
        end
    end
    
    -- Prefer live UnitAura only when unit token matches THIS plate GUID
    local foundAuras
    if unitId and UnitExists(unitId) and UnitGUID(unitId) == plateGUID then
        foundAuras = FindAllAuras(unitId)
    else
        foundAuras = guidAuras[plateGUID] or {}
    end
    
    -- Используем найденные ауры для всех фреймов
    UpdateAuraFrameFromCache(namePlate, namePlate.controlFrame, ICON_SIZE_CONTROL, foundAuras, CENTER_AURA_TYPES)
    UpdateAuraFrameFromCache(namePlate, namePlate.castFrame, ICON_SIZE_CAST, foundAuras, CAST_AURA_TYPES)
    UpdateAuraFrameFromCache(namePlate, namePlate.mobilityFrame, ICON_SIZE_MOBILITY, foundAuras, MOBILITY_AURA_TYPES)
    UpdateAuraFrameFromCache(namePlate, namePlate.otherFrame, ICON_SIZE_OTHER, foundAuras, OTHER_AURA_TYPES)

    UpdateOtherAurasFromCache(namePlate, foundAuras)
    
    -- Обновляем позиции центральных фреймов после всех обновлений
    UpdateCenterFramesPosition(namePlate)
    UpdateMobilityFramesPosition(namePlate)  
	ApplyAllPlateGlows(namePlate)
    if SarychUI_PerfSlow then
        SarychUI_PerfSlow("Auras", "UpdateAurasSlow", perfStart, unitId, 3)
    end
end

function _G.sarPlatesAuras_UpdatePlateLayout(namePlate)
    if not namePlate then return end
    UpdateCenterFramesPosition(namePlate)
    UpdateMobilityFramesPosition(namePlate)
	ApplyAllPlateGlows(namePlate)
end

local function OnNamePlateAdded_Auras(unitId)
	if not unitId then return end
	
	-- Verify unit exists
	if not UnitExists(unitId) then return end
	
	local unitGUID = UnitGUID(unitId)
	if not unitGUID then return end

	if removedPlates[unitGUID] then
		 removedPlates[unitGUID] = nil
	end

	guidToUnitIdMap[unitGUID] = unitId
	
	-- Collect and cache auras by GUID
	FindAllAuras(unitId)
	
	-- Get nameplate by GUID (most reliable method)
	local namePlate = nil
	if UseAwesomeWotlk() then
		namePlate = GetNamePlateForUnit(unitId)
	else
		-- For LibNameplates, use GUID to get nameplate
		if LibNameplates then
			namePlate = LibNameplates:GetNameplateByGUID(unitGUID)
		end
		-- Fallback to unitId if GUID method fails
		if not namePlate then
			namePlate = GetNamePlateForUnit(unitId)
		end
	end
	
	-- Update auras using cached data by GUID
	if namePlate then
		_G.UpdateAuras(namePlate, unitId)
	end
end

-- Expose OnNamePlateAdded_Auras globally for module.lua
_G.OnNamePlateAdded_Auras = OnNamePlateAdded_Auras

local function IsNameplateAuraUnit(unitId)
    if not unitId then
        return false
    end
    if unitId:match("^nameplate") then
        return true
    end
    if namePlates and namePlates[unitId] then
        return true
    end
    if _G.ActiveNameplates and _G.ActiveNameplates[unitId] then
        return true
    end
    if GetNamePlateForUnit(unitId) then
        return true
    end
    local guid = UnitGUID(unitId)
    if guid and guidToUnitIdMap[guid] then
        return true
    end
    return false
end

local function IsPlatesAurasModuleEnabled()
    local mod = SarychUI and SarychUI.GetModule and SarychUI:GetModule("plates_auras", true)
    if mod and mod.IsModuleEnabled then
        return mod.IsModuleEnabled()
    end
    return true
end

local AURA_STATE_COMPARE_FIELDS = {
    "stackCount",
    "expirationTime",
    "duration",
    "caster",
    "type",
    "priority",
    "iconTexture",
}

local function AreAuraEntriesEqual(oldEntry, newEntry)
    if oldEntry == newEntry then
        return true
    end
    if not oldEntry or not newEntry then
        return false
    end
    for i = 1, #AURA_STATE_COMPARE_FIELDS do
        local field = AURA_STATE_COMPARE_FIELDS[i]
        if oldEntry[field] ~= newEntry[field] then
            return false
        end
    end
    return true
end

local function AreAuraStatesEqual(oldAuras, newAuras)
    if oldAuras == newAuras then
        return true
    end
    if not oldAuras or not newAuras then
        return false
    end
    for spellId, oldEntry in pairs(oldAuras) do
        if not AreAuraEntriesEqual(oldEntry, newAuras[spellId]) then
            return false
        end
    end
    for spellId in pairs(newAuras) do
        if oldAuras[spellId] == nil then
            return false
        end
    end
    return true
end

local function OnUnitAura(unitId)
    if not unitId then return end
    if not IsPlatesAurasModuleEnabled() then return end
    if not IsNameplateAuraUnit(unitId) then return end
    local perfStart = SarychUI_PerfDebug and SarychUI_PerfNow and SarychUI_PerfNow() or nil
    if SarychUI_PerfLog then
        SarychUI_PerfLog("Auras", "UNIT_AURA", unitId)
    end

    -- Verify unit still exists
    if not UnitExists(unitId) then return end
    
    local unitGUID = UnitGUID(unitId)
    if not unitGUID then return end
    
    -- Update guidToUnitIdMap
    guidToUnitIdMap[unitGUID] = unitId

    local previousAuras = guidAuras[unitGUID]
    local newAuras = FindAllAuras(unitId)
    
    -- Get nameplate by GUID (most reliable method)
    local namePlate = nil
    if UseAwesomeWotlk() then
        namePlate = GetNamePlateForUnit(unitId)
    else
        -- For LibNameplates, use GUID to get nameplate
        if LibNameplates then
            namePlate = LibNameplates:GetNameplateByGUID(unitGUID)
        end
        -- Fallback to unitId if GUID method fails
        if not namePlate then
            namePlate = GetNamePlateForUnit(unitId)
        end
    end
    
    -- Update auras using cached data by GUID
    if namePlate then
        if not previousAuras or not AreAuraStatesEqual(previousAuras, newAuras) then
            _G.UpdateAuras(namePlate, unitId)
        end
    end
    if SarychUI_PerfSlow then
        SarychUI_PerfSlow("Auras", "OnUnitAuraSlow", perfStart, unitId, 3)
    end
end

local function OnNamePlateRemoved(unitId)
	local unitGUID = UnitGUID(unitId)
	if not unitGUID then return end

	removedPlates[unitGUID] = GetTime()

	if _G["ActiveNameplates"] then
		_G["ActiveNameplates"][unitId] = nil
	end
end

local function CleanupOldPlates()
	local currentTime = GetTime()
	local removedCount = 0

	for guid, disappearTime in pairs(removedPlates) do
        if (currentTime - disappearTime) > 10 then
            local unitId = guidToUnitIdMap[guid]
            if unitId then
                local namePlate = GetNamePlateForUnit(unitId)
                if not namePlate then
                    if _G["ActiveNameplates"] then
                        _G["ActiveNameplates"][unitId] = nil
                    end
                    namePlates[unitId] = nil
                    guidToUnitIdMap[guid] = nil
                    removedPlates[guid] = nil
                end
            end
        end
    end    
end

local cleanupFrame = CreateFrame("Frame")
if SarychUI and SarychUI.RegisterPerfOnUpdate then
    SarychUI:RegisterPerfOnUpdate("plates_auras.cleanup", cleanupFrame)
end
cleanupFrame:SetScript("OnUpdate", function(self, elapsed)
    if not IsPlatesAurasModuleEnabled() then
        return
    end

    local interval = 5
    if SarychUI and SarychUI.Compatibility then
        interval = SarychUI.Compatibility:GetInterval("platesCleanup", 5, 8)
    end

    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < interval then
        return
    end
    self.elapsed = 0

    CleanupOldPlates()
end)

local f = CreateFrame("Frame")

function _G.sarPlatesAuras_RegisterEvents()
    if f.__sarychEventsRegistered then
        return
    end
    if C_NamePlate then
        f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    end
    f:RegisterEvent("UNIT_AURA")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    f:RegisterEvent("UNIT_TARGET")
    f.__sarychEventsRegistered = true
end

function _G.sarPlatesAuras_UnregisterEvents()
    f:UnregisterAllEvents()
    f.__sarychEventsRegistered = false
end

f:SetScript("OnEvent", function(self, event, unitId)
    if not IsPlatesAurasModuleEnabled() then
        return
    end
    if event == "NAME_PLATE_UNIT_ADDED" then
        if SarychUI_PerfLog then
            SarychUI_PerfLog("Auras", "NAME_PLATE_UNIT_ADDED", unitId)
        end
        -- Only process if AwesomeWotlk mode is enabled
        if UseAwesomeWotlk() then
            OnNamePlateAdded_Auras(unitId)
        end
    elseif event == "UNIT_AURA" then
        if UseAwesomeWotlk() then
            OnUnitAura(unitId)
        elseif unitId and UnitExists(unitId) then
            -- PlateBuffs:UNIT_AURA → CollectUnitInfo(unitID) for any existing unit
            CollectUnitInfo(unitId)
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if not UseAwesomeWotlk() then
            CollectUnitInfo("target")
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if not UseAwesomeWotlk() then
            CollectUnitInfo("mouseover")
        end
    elseif event == "UNIT_TARGET" then
        -- PlateBuffs:UNIT_TARGET
        if not UseAwesomeWotlk() and unitId and not (UnitIsUnit and UnitIsUnit(unitId, "player")) then
            local targetId = unitId .. "target"
            if UnitExists(targetId) then
                CollectUnitInfo(targetId)
            end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if SarychUI_PerfLog then
            SarychUI_PerfLog("Auras", "NAME_PLATE_UNIT_REMOVED", unitId)
        end
        -- Only process if AwesomeWotlk mode is enabled
        if UseAwesomeWotlk() then
            OnNamePlateRemoved(unitId)
        end
    end
end)

-- Set alpha for all aura frames
function _G.sarPlatesAuras_SetAlpha(alpha)
    alpha = alpha or 1
    
    local namePlates = GetAllNamePlates()
    if not namePlates or #namePlates == 0 then return end
    for _, namePlate in ipairs(namePlates) do
        if namePlate.centerContainer then
            namePlate.centerContainer:SetAlpha(alpha)
        end
        if namePlate.mobilityContainer then
            namePlate.mobilityContainer:SetAlpha(alpha)
        end
        if namePlate.playerFrame then
            namePlate.playerFrame:SetAlpha(alpha)
        end
    end
    
    -- Also update active display profile in DB
    local profile = GetActiveDisplayProfile()
    if profile then
        if not profile.display then
            profile.display = {}
        end
        profile.display.alpha = alpha
    end
end

-- Set scale for all aura frames
function _G.sarPlatesAuras_SetScale(scale)
    scale = scale or 1

    local profile = GetActiveDisplayProfile()
    if profile then
        if not profile.display then
            profile.display = {}
        end
        profile.display.scale = scale
    end

    local namePlates = GetAllNamePlates()
    if not namePlates or #namePlates == 0 then return end

    if UsesElvUILayout() then
        local layout = SarychUI.PlatesAurasElvUI
        for _, namePlate in ipairs(namePlates) do
            if layout and layout.UpdatePlateResponsiveScale then
                layout.UpdatePlateResponsiveScale(namePlate, {
                    source = "set-scale",
                    baseScale = scale,
                })
            end
            if namePlate.mobilityContainer then
                namePlate.mobilityContainer:SetScale(scale)
            end
        end
        return
    end

    for _, namePlate in ipairs(namePlates) do
        if namePlate.centerContainer then
            namePlate.centerContainer:SetScale(scale)
        end
        if namePlate.mobilityContainer then
            namePlate.mobilityContainer:SetScale(scale)
        end
        if namePlate.playerFrame then
            namePlate.playerFrame:SetScale(scale)
        end
    end
end

local function ApplySizesToPlate(namePlate)
    if not namePlate then return end
    if namePlate.centerContainer then
        namePlate.centerContainer:SetSize(ICON_SIZE_CONTROL + ICON_SIZE_CAST + 4, ICON_SIZE_CONTROL)
        if not UsesElvUILayout() then
            namePlate.centerContainer:ClearAllPoints()
            namePlate.centerContainer:SetPoint("CENTER", namePlate, "TOP", 0, CentrY)
        end
    end
    if namePlate.controlFrame then
        namePlate.controlFrame:SetSize(ICON_SIZE_CONTROL, ICON_SIZE_CONTROL)
        if namePlate.controlFrame.auraIcon then
            namePlate.controlFrame.auraIcon:SetSize(ICON_SIZE_CONTROL, ICON_SIZE_CONTROL)
        end
        if namePlate.controlFrame.UpdateBorderSize then namePlate.controlFrame.UpdateBorderSize() end
    end
    if namePlate.castFrame then
        namePlate.castFrame:SetSize(ICON_SIZE_CAST, ICON_SIZE_CAST)
        if namePlate.castFrame.auraIcon then
            namePlate.castFrame.auraIcon:SetSize(ICON_SIZE_CAST, ICON_SIZE_CAST)
        end
        if namePlate.castFrame.UpdateBorderSize then namePlate.castFrame.UpdateBorderSize() end
    end
    if namePlate.mobilityContainer then
        namePlate.mobilityContainer:SetSize(ICON_SIZE_MOBILITY + ICON_SIZE_OTHER + 4, ICON_SIZE_MOBILITY)
        if not UsesElvUILayout() then
            namePlate.mobilityContainer:ClearAllPoints()
            namePlate.mobilityContainer:SetPoint("LEFT", namePlate, "RIGHT", RightX, RightY)
        end
    end
    if namePlate.mobilityFrame then
        namePlate.mobilityFrame:SetSize(ICON_SIZE_MOBILITY, ICON_SIZE_MOBILITY)
        if namePlate.mobilityFrame.auraIcon then
            namePlate.mobilityFrame.auraIcon:SetSize(ICON_SIZE_MOBILITY, ICON_SIZE_MOBILITY)
        end
        if namePlate.mobilityFrame.UpdateBorderSize then namePlate.mobilityFrame.UpdateBorderSize() end
    end
    if namePlate.otherFrame then
        namePlate.otherFrame:SetSize(ICON_SIZE_OTHER, ICON_SIZE_OTHER)
        if namePlate.otherFrame.auraIcon then
            namePlate.otherFrame.auraIcon:SetSize(ICON_SIZE_OTHER, ICON_SIZE_OTHER)
        end
        if namePlate.otherFrame.UpdateBorderSize then namePlate.otherFrame.UpdateBorderSize() end
    end
    if namePlate.playerFrame and namePlate.playerFrame.auraIcons then
        AnchorPlayerFrame(namePlate)
        ApplyPlayerIconShapes(namePlate)
    end
    if namePlate.centerContainer or namePlate.mobilityContainer then
        UpdateCenterFramesPosition(namePlate)
        UpdateMobilityFramesPosition(namePlate)
    end
    if UsesElvUILayout() then
        local layout = SarychUI and SarychUI.PlatesAurasElvUI
        if layout and layout.UpdateElvUIAuraAnchor then
            layout.UpdateElvUIAuraAnchor(namePlate)
        end
    end
end

local function ApplyTestVisualsToPlate(namePlate)
    if not IsTestModeEnabled() then return end
    if _G.SarPlatesAurasTest and namePlate.testAuras then
        if _G.SarPlatesAurasTest.DisplayTestAuras then
            _G.SarPlatesAurasTest.DisplayTestAuras(namePlate)
        end
        if _G.SarPlatesAurasTest.UpdateCenterFramesPosition then
            _G.SarPlatesAurasTest.UpdateCenterFramesPosition(namePlate)
        end
    end
end

-- Layout/sizes/positions only — без UpdateAuras (options sliders)
function _G.sarPlatesAuras_RerenderVisual()
    local namePlates = GetAllNamePlates()
    if not namePlates or #namePlates == 0 then return end
    for _, namePlate in ipairs(namePlates) do
        ApplySizesToPlate(namePlate)
        ApplyTestVisualsToPlate(namePlate)
    end
end

-- Safe rerender function used by options when test mode is active
function _G.sarPlatesAuras_Rerender()
    local namePlates = GetAllNamePlates()
    if not namePlates or #namePlates == 0 then return end

    for _, namePlate in ipairs(namePlates) do
        ApplySizesToPlate(namePlate)

        if IsTestModeEnabled() then
            ApplyTestVisualsToPlate(namePlate)
        elseif UseAwesomeWotlk() then
            local unitId = namePlate and namePlate.namePlateUnitToken or nil
            if unitId then
                _G.UpdateAuras(namePlate, unitId)
            end
        elseif _G.sarPlatesAuras_OnNonAwesomePlate then
            -- PlateBuffs AddOurStuffToPlate — paints only with Lib GUID
            _G.sarPlatesAuras_OnNonAwesomePlate(namePlate)
        end
    end
end
