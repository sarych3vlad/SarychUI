-- SarychUI Plates Auras Module
-- Displays auras on nameplates

local moduleName = "plates_auras"
local module = {}

local DEBUG_PLATES_AURAS_PERF = false

local layoutRefreshPending = false
local rerenderPending = false
local SETTINGS_DEBOUNCE = 0.05

local function PerfPlatesAurasLog(stage, startTime)
	if not DEBUG_PLATES_AURAS_PERF then return end
	local prefix = (SarychUI and SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("PlatesAuras Perf")) or "|cffffd200SarychUI PlatesAuras Perf:|r"
	if startTime then
		print(string.format("%s %s: %.2f ms", prefix, stage, debugprofilestop() - startTime))
	else
		print(prefix .. " " .. stage)
	end
end

-- Register module
SarychUI:RegisterModule(moduleName, module)

-- Local references
local L = SarychUI.L

-- Load core.lua and configID.lua
local coreFile = "Interface\\AddOns\\SarychUI\\modules\\plates_auras\\core.lua"
local configFile = "Interface\\AddOns\\SarychUI\\modules\\plates_auras\\configID.lua"

-- Helper function to get settings
local function DB()
    return SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules and SarychUI.db.profile.modules[moduleName]
end

local PROFILE_MODES = { classic = true, elvui = true }

local function CopyTable(src, dest)
	if type(src) ~= "table" then return src end
	if type(dest) ~= "table" then dest = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dest[k] = CopyTable(v, dest[k])
		else
			dest[k] = v
		end
	end
	return dest
end

function module:GetDefaultDisplayProfile(mode)
	local defaults = SarychUI.defaults and SarychUI.defaults.profile and SarychUI.defaults.profile.modules and SarychUI.defaults.profile.modules.plates_auras
	if defaults and defaults.profiles and defaults.profiles[mode] then
		return CopyTable(defaults.profiles[mode], {})
	end
	return CopyTable(defaults and defaults.profiles and defaults.profiles.classic or {}, {})
end

function module:MigrateProfiles()
	local db = DB()
	if not db then return end

	if db.profileVersion and db.profileVersion >= 1 and db.profiles and db.profiles.classic and db.profiles.classic.sizes then
		return
	end

	local classic = self:GetDefaultDisplayProfile("classic")

	if db.positions then
		for key, value in pairs(db.positions) do
			classic.positions[key] = value
		end
	end
	if db.sizes then
		for key, value in pairs(db.sizes) do
			classic.sizes[key] = value
		end
	end
	if db.display then
		for key, value in pairs(db.display) do
			classic.display[key] = value
		end
	end

	db.profiles = db.profiles or {}
	db.profiles.classic = classic

	if not db.profiles.elvui then
		db.profiles.elvui = self:GetDefaultDisplayProfile("elvui")
	end

	db.positions = nil
	db.sizes = nil
	db.display = nil
	db.profileVersion = 1
end

function module:EnsureProfiles()
	self:MigrateProfiles()
	local db = DB()
	if not db then return end

	db.profiles = db.profiles or {}

	for mode in pairs(PROFILE_MODES) do
		if not db.profiles[mode] then
			db.profiles[mode] = self:GetDefaultDisplayProfile(mode)
		end
		local profile = db.profiles[mode]
		local defaults = self:GetDefaultDisplayProfile(mode)
		profile.positions = profile.positions or CopyTable(defaults.positions, {})
		profile.sizes = profile.sizes or CopyTable(defaults.sizes, {})
		profile.display = profile.display or CopyTable(defaults.display, {})
		if defaults.layout then
			profile.layout = profile.layout or CopyTable(defaults.layout, {})
			if defaults.layout.player then
				profile.layout.player = profile.layout.player or CopyTable(defaults.layout.player, {})
				if profile.layout.player.spacing == nil then
					profile.layout.player.spacing = defaults.layout.player.spacing or 2
				end
				if profile.layout.player.altRight == nil then
					profile.layout.player.altRight = defaults.layout.player.altRight and true or false
				end
			end
		end
		if mode == "elvui" and defaults.plateResponsiveScale then
			profile.plateResponsiveScale = profile.plateResponsiveScale or CopyTable(defaults.plateResponsiveScale, {})
			for slotName, slotDefaults in pairs(defaults.plateResponsiveScale) do
				if not profile.plateResponsiveScale[slotName] then
					profile.plateResponsiveScale[slotName] = CopyTable(slotDefaults, {})
				else
					for key, value in pairs(slotDefaults) do
						if profile.plateResponsiveScale[slotName][key] == nil then
							profile.plateResponsiveScale[slotName][key] = value
						end
					end
				end
			end
		end
	end

	if not db.profileVersion or db.profileVersion < 2 then
		local elvuiDefaults = self:GetDefaultDisplayProfile("elvui")
		if db.profiles and db.profiles.elvui and elvuiDefaults.layout and not db.profiles.elvui.layout then
			db.profiles.elvui.layout = CopyTable(elvuiDefaults.layout, {})
		end
		db.profileVersion = 2
	end

	if db.profileVersion < 3 and db.profiles and db.profiles.elvui and db.profiles.elvui.layout then
		for _, slot in pairs(db.profiles.elvui.layout) do
			if type(slot) == "table" then
				slot.offsetX = nil
				slot.offsetY = nil
			end
		end
		db.profileVersion = 3
	end

	if db.profileVersion < 4 then
		local elvuiDefaults = self:GetDefaultDisplayProfile("elvui")
		local elvuiProfile = db.profiles and db.profiles.elvui
		if elvuiProfile and elvuiDefaults and elvuiDefaults.plateResponsiveScale then
			elvuiProfile.plateResponsiveScale = elvuiProfile.plateResponsiveScale or CopyTable(elvuiDefaults.plateResponsiveScale, {})
			for slotName, slotDefaults in pairs(elvuiDefaults.plateResponsiveScale) do
				if not elvuiProfile.plateResponsiveScale[slotName] then
					elvuiProfile.plateResponsiveScale[slotName] = CopyTable(slotDefaults, {})
				else
					for key, value in pairs(slotDefaults) do
						if elvuiProfile.plateResponsiveScale[slotName][key] == nil then
							elvuiProfile.plateResponsiveScale[slotName][key] = value
						end
					end
				end
			end
		end
		db.profileVersion = 4
	end

	-- Bump barely-visible responsive scale defaults (old: ~+1.5% on target) to noticeable values.
	if db.profileVersion < 5 then
		local elvuiProfile = db.profiles and db.profiles.elvui
		local prs = elvuiProfile and elvuiProfile.plateResponsiveScale
		if prs then
			local center = prs.center
			if center and center.factor == 0.10 and center.maxBonus == 0.08 then
				center.factor = 0.55
				center.maxBonus = 0.20
			end
		end
		db.profileVersion = 5
	end

	-- Drop unused player plate-growth settings (center-only feature).
	if db.profileVersion < 6 then
		local elvuiProfile = db.profiles and db.profiles.elvui
		local prs = elvuiProfile and elvuiProfile.plateResponsiveScale
		if prs then
			prs.player = nil
		end
		db.profileVersion = 6
	end
end

function module:InstallElvUIHooks()
	local layout = SarychUI and SarychUI.PlatesAurasElvUI
	if layout and layout.TryInstallHooks then
		layout.TryInstallHooks()
	end
end

function module:GetActiveDisplayProfile()
	self:EnsureProfiles()
	local db = DB()
	if not db or not db.profiles then return nil end

	local mode = SarychUI.GetNameplateMode and SarychUI:GetNameplateMode() or "classic"
	if not db.profiles[mode] then
		mode = "classic"
	end
	return db.profiles[mode]
end

function module:GetActiveProfileMode()
	return SarychUI.GetNameplateMode and SarychUI:GetNameplateMode() or "classic"
end

-- Initialize module
function module:Initialize()
    self:EnsureProfiles()
    self:InstallElvUIHooks()
    self:ApplySettings()
end

-- Enable module
function module:Enable()
    local db = DB()
    if not db or not db.enabled then return end

    -- Stale profile: Awesome toggle on but no C_NamePlate API → force non-Awesome path
    if db.useAwesomeWotlk and not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        db.useAwesomeWotlk = false
    end

    -- Apply settings from DB to globals
    self:ApplySettings()

    if _G.sarPlatesAuras_RegisterEvents then
        _G.sarPlatesAuras_RegisterEvents()
    end

    local useAwesomeWotlk = db.useAwesomeWotlk == true and C_NamePlate and C_NamePlate.GetNamePlateForUnit
    if useAwesomeWotlk then
        if _G.sarPlatesAuras_PB_Disable then
            _G.sarPlatesAuras_PB_Disable()
        end
        if _G.sarPlatesAuras_UnregisterLibAuraInfo then
            _G.sarPlatesAuras_UnregisterLibAuraInfo()
        end
    else
        if _G.sarPlatesAuras_PB_Enable then
            _G.sarPlatesAuras_PB_Enable()
        end
        if _G.sarPlatesAuras_RegisterLibAuraInfo then
            _G.sarPlatesAuras_RegisterLibAuraInfo()
        end
        -- PlateBuffs OnEnable: only register callbacks/events — no WorldFrame plate spray / arena seed.
        -- Visible plates are handled by Lib NewNameplate/FoundGUID; target/mouseover by those events.
        if UnitExists("target") and _G.sarPlatesAuras_CollectUnitInfo then
            _G.sarPlatesAuras_CollectUnitInfo("target")
        end
        if UnitExists("mouseover") and _G.sarPlatesAuras_CollectUnitInfo then
            _G.sarPlatesAuras_CollectUnitInfo("mouseover")
        end
    end

    if useAwesomeWotlk and _G.sarPlatesAuras_GetAllNamePlates then
        local allPlates = _G.sarPlatesAuras_GetAllNamePlates()
        for _, namePlate in ipairs(allPlates) do
            if namePlate and namePlate:IsShown() then
                local unitId = namePlate.namePlateUnitToken
                if unitId and UnitGUID(unitId) and _G.OnNamePlateAdded_Auras then
                    _G.OnNamePlateAdded_Auras(unitId)
                end
            end
        end
    end
end

-- Helper function to check if module is enabled
local function IsModuleEnabled()
    local db = DB()
    return db and db.enabled == true
end

-- Expose IsModuleEnabled for core.lua
module.IsModuleEnabled = IsModuleEnabled

-- Disable module
function module:Disable()
    local db = DB()

    if _G.sarPlatesAuras_UnregisterEvents then
        _G.sarPlatesAuras_UnregisterEvents()
    end
    if _G.sarPlatesAuras_PB_Disable then
        _G.sarPlatesAuras_PB_Disable()
    end
    if _G.sarPlatesAuras_UnregisterLibAuraInfo then
        _G.sarPlatesAuras_UnregisterLibAuraInfo()
    end
    
    -- Stop test mode if active
    if _G.SarPlatesAurasTest and _G.SarPlatesAurasTest.testTimer and _G.SarPlatesAurasTest.StopTest then
        _G.SarPlatesAurasTest.StopTest()
    end
    
    -- Hide all auras when disabled
    if _G.sarPlatesAuras_GetAllNamePlates then
        local namePlates = _G.sarPlatesAuras_GetAllNamePlates()
        for _, namePlate in ipairs(namePlates) do
            if namePlate.centerContainer then 
                namePlate.centerContainer:Hide()
                if namePlate.controlFrame then namePlate.controlFrame:Hide() end
                if namePlate.castFrame then namePlate.castFrame:Hide() end
            end
            if namePlate.mobilityContainer then 
                namePlate.mobilityContainer:Hide()
                if namePlate.mobilityFrame then namePlate.mobilityFrame:Hide() end
                if namePlate.otherFrame then namePlate.otherFrame:Hide() end
            end
            if namePlate.playerFrame then 
                namePlate.playerFrame:Hide()
            end
        end
    end
end

local function SyncSpellEntry(spellID, spellSettings)
    if not _G["SPELL_DATA"] or not spellSettings then return end
    if not _G["SPELL_DATA"][spellID] then
        _G["SPELL_DATA"][spellID] = {}
    end
    local entry = _G["SPELL_DATA"][spellID]
    if spellSettings.type then
        entry.type = spellSettings.type
    end
    if spellSettings.priority then
        entry.priority = spellSettings.priority
    end
    if spellSettings.enabled ~= nil then
        entry.enabled = spellSettings.enabled ~= false and spellSettings.enabled ~= 0
    end
    if spellSettings.highlight ~= nil then
        entry.highlight = spellSettings.highlight
    end
    if spellSettings.highlightColor ~= nil then
        entry.highlightColor = spellSettings.highlightColor
    end
    if spellSettings.glowType ~= nil then
        entry.glowType = spellSettings.glowType
    end
    if spellSettings.useGlowColor ~= nil then
        entry.useGlowColor = spellSettings.useGlowColor
    end
    if spellSettings.glowLines ~= nil then
        entry.glowLines = spellSettings.glowLines
    end
    if spellSettings.glowFrequency ~= nil then
        entry.glowFrequency = spellSettings.glowFrequency
    end
    if spellSettings.glowLength ~= nil then
        entry.glowLength = spellSettings.glowLength
    end
    if spellSettings.glowThickness ~= nil then
        entry.glowThickness = spellSettings.glowThickness
    end
    if spellSettings.glowScale ~= nil then
        entry.glowScale = spellSettings.glowScale
    end
    if spellSettings.glowBorder ~= nil then
        entry.glowBorder = spellSettings.glowBorder
    end
    if spellSettings.glowXOffset ~= nil then
        entry.glowXOffset = spellSettings.glowXOffset
    end
    if spellSettings.glowYOffset ~= nil then
        entry.glowYOffset = spellSettings.glowYOffset
    end
    if spellSettings.allowFromOthers ~= nil then
        entry.allowFromOthers = spellSettings.allowFromOthers
    end
    if spellSettings.customPriority ~= nil then
        entry.customPriority = spellSettings.customPriority
    end
end

function module:SyncSpellDataFromDB(spellID)
    local db = DB()
    if not db or not db.spells or not _G["SPELL_DATA"] then return end
    if spellID then
        SyncSpellEntry(spellID, db.spells[spellID])
        return
    end
    for id, spellSettings in pairs(db.spells) do
        SyncSpellEntry(id, spellSettings)
    end
end

function module:ApplyProfileGlobals()
    local profile = self:GetActiveDisplayProfile()
    if not profile then return end
    if profile.sizes then
        for key, value in pairs(profile.sizes) do
            _G[key] = value
        end
    end
    if profile.positions then
        for key, value in pairs(profile.positions) do
            _G[key] = value
        end
    end
    if profile.layout and profile.layout.player and profile.layout.player.spacing ~= nil then
        _G.PLAYER_ICON_SPACING = profile.layout.player.spacing
    else
        _G.PLAYER_ICON_SPACING = 2
    end
    _G.PLAYER_ALT_RIGHT = (profile.layout and profile.layout.player and profile.layout.player.altRight) and true or false
end

function module:DoAuraRerenderNow()
    local rerenderStart = DEBUG_PLATES_AURAS_PERF and debugprofilestop() or nil
    self:InstallElvUIHooks()
    if _G.SarPlatesAurasTest and _G.SarPlatesAurasTest.testTimer and _G.SarPlatesAurasTest.RefreshAllPlates then
        _G.SarPlatesAurasTest:RefreshAllPlates()
    elseif _G["sarPlatesAuras_Rerender"] then
        _G["sarPlatesAuras_Rerender"]()
    end
    PerfPlatesAurasLog("rerender executed", rerenderStart)
end

function module:DoAuraLayoutRefreshNow()
    local layoutStart = DEBUG_PLATES_AURAS_PERF and debugprofilestop() or nil
    self:InstallElvUIHooks()
    if _G.SarPlatesAurasTest and _G.SarPlatesAurasTest.testTimer and _G.SarPlatesAurasTest.RefreshAllPlates then
        _G.SarPlatesAurasTest:RefreshAllPlates()
    elseif _G["sarPlatesAuras_RerenderVisual"] then
        _G["sarPlatesAuras_RerenderVisual"]()
    elseif _G["sarPlatesAuras_Rerender"] then
        _G["sarPlatesAuras_Rerender"]()
    end
    PerfPlatesAurasLog("layout refresh executed", layoutStart)
end

function module:ScheduleAuraLayoutRefresh()
    if layoutRefreshPending then return end
    layoutRefreshPending = true
    PerfPlatesAurasLog("layout refresh scheduled")
    C_Timer.After(SETTINGS_DEBOUNCE, function()
        layoutRefreshPending = false
        self:ApplyProfileGlobals()
        self:DoAuraLayoutRefreshNow()
    end)
end

function module:ScheduleAuraRerender()
    if rerenderPending then return end
    rerenderPending = true
    PerfPlatesAurasLog("rerender scheduled")
    C_Timer.After(SETTINGS_DEBOUNCE, function()
        rerenderPending = false
        self:ApplyProfileGlobals()
        self:SyncSpellDataFromDB()
        self:DoAuraRerenderNow()
    end)
end

function module:OnAuraDisplaySettingChanged(key, value)
    local startTime = DEBUG_PLATES_AURAS_PERF and debugprofilestop() or nil
    if key == "alpha" and _G["sarPlatesAuras_SetAlpha"] then
        _G["sarPlatesAuras_SetAlpha"](value)
    elseif key == "scale" and _G["sarPlatesAuras_SetScale"] then
        _G["sarPlatesAuras_SetScale"](value)
    end
    PerfPlatesAurasLog("display setting changed", startTime)
end

function module:OnAuraLayoutSettingChanged(section, key, value)
    local startTime = DEBUG_PLATES_AURAS_PERF and debugprofilestop() or nil
    if DEBUG_PLATES_AURAS_PERF then
        PerfPlatesAurasLog(string.format("layout setting changed section=%s key=%s value=%s", tostring(section), tostring(key), tostring(value)))
    end
    -- Individual player icons are only placed during an aura pass, so switching the
    -- strip's shape needs a full rerender, not just a container re-anchor.
    -- Apply immediately: unchecking must restore the old strip + center seat at once.
    if (section == "sizes" and key == "MAX_PLAYER_AURAS")
        or (section == "layout" and key == "player.altRight") then
        self:ApplyProfileGlobals()
        self:DoAuraRerenderNow()
    else
        self:ScheduleAuraLayoutRefresh()
    end
    PerfPlatesAurasLog("layout setting changed", startTime)
end

function module:OnAuraDataSettingChanged(spellID, field, value)
    if DEBUG_PLATES_AURAS_PERF then
        PerfPlatesAurasLog(string.format("data setting changed spellID=%s field=%s value=%s", tostring(spellID), tostring(field), tostring(value)))
    end
    self:SyncSpellDataFromDB(spellID)
    self:ScheduleAuraRerender()
end

-- Apply settings from DB (full path — enable/init/add spell)
function module:ApplySettings()
    local totalStart = DEBUG_PLATES_AURAS_PERF and debugprofilestop() or nil
    local db = DB()
    if not db then return end

    self:EnsureProfiles()
    local profile = self:GetActiveDisplayProfile()
    if not profile then return end

    self:SyncSpellDataFromDB()
    self:ApplyProfileGlobals()

    if profile.display then
        if profile.display.alpha and _G["sarPlatesAuras_SetAlpha"] then
            _G["sarPlatesAuras_SetAlpha"](profile.display.alpha)
        end
        if profile.display.scale and _G["sarPlatesAuras_SetScale"] then
            _G["sarPlatesAuras_SetScale"](profile.display.scale)
        end
    end

    if db.useAwesomeWotlk and not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        db.useAwesomeWotlk = false
    end

    if db.useAwesomeWotlk and _G["sarPlatesAuras_SetNameplateDistance"] then
        _G["sarPlatesAuras_SetNameplateDistance"](42)
    end

    if db.useAwesomeWotlk and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        if _G.sarPlatesAuras_PB_Disable then
            _G.sarPlatesAuras_PB_Disable()
        end
        if _G.sarPlatesAuras_UnregisterLibAuraInfo then
            _G.sarPlatesAuras_UnregisterLibAuraInfo()
        end
    elseif db.enabled then
        if _G.sarPlatesAuras_PB_Enable then
            _G.sarPlatesAuras_PB_Enable()
        end
        if _G.sarPlatesAuras_RegisterLibAuraInfo then
            _G.sarPlatesAuras_RegisterLibAuraInfo()
        end
    end

    layoutRefreshPending = false
    rerenderPending = false
    self:DoAuraRerenderNow()
    PerfPlatesAurasLog("ApplySettings total", totalStart)
end

-- Get SPELL_DATA for options
function module:GetSpellData()
    return _G["SPELL_DATA"] or {}
end

-- Add spell to SPELL_DATA
function module:AddSpell(spellID, spellType, priority, enabled, highlight)
    if not _G["SPELL_DATA"] then
        _G["SPELL_DATA"] = {}
    end
    
    -- Get spell info
    local spellName, _, spellIcon = GetSpellInfo(spellID)
    if not spellName then
        return false, "Spell ID not found"
    end
    
    -- Add or update spell data
    if not _G["SPELL_DATA"][spellID] then
        _G["SPELL_DATA"][spellID] = {}
    end
    
    _G["SPELL_DATA"][spellID].type = spellType or "other"
    _G["SPELL_DATA"][spellID].priority = priority or 100
    _G["SPELL_DATA"][spellID].enabled = enabled ~= nil and enabled or true
    
    if highlight then
        _G["SPELL_DATA"][spellID].highlight = highlight
    end
    
    -- Save to DB
    local db = DB()
    if db then
        if not db.spells then
            db.spells = {}
        end
        if not db.spells[spellID] then
            db.spells[spellID] = {}
        end
        db.spells[spellID].type = spellType or "other"
        db.spells[spellID].priority = priority or 100
        db.spells[spellID].enabled = enabled ~= nil and enabled or true
        if highlight then
            db.spells[spellID].highlight = highlight
        end
    end
    
    -- Apply settings
    self:ApplySettings()
    
    return true, "Spell added successfully"
end

-- Remove spell from SPELL_DATA
function module:RemoveSpell(spellID)
    local removed = false
    
    -- Remove from global SPELL_DATA
    if _G["SPELL_DATA"] and _G["SPELL_DATA"][spellID] then
        _G["SPELL_DATA"][spellID] = nil
        removed = true
    end
    
    -- Remove from DB
    local db = DB()
    if db and db.spells and db.spells[spellID] then
        db.spells[spellID] = nil
        removed = true
    end
    
    if removed then
        -- Apply settings
        self:ApplySettings()
        return true, "Spell removed successfully"
    end
    
    return false, "Spell not found"
end

-- Test mode functions
function module:StartTestMode()
    if _G.SarPlatesAurasTest and _G.SarPlatesAurasTest.StartTest then
        _G.SarPlatesAurasTest.StartTest()
        return true
    end
    return false
end

function module:StopTestMode()
    if _G.SarPlatesAurasTest and _G.SarPlatesAurasTest.StopTest then
        _G.SarPlatesAurasTest.StopTest()
        return true
    end
    return false
end

-- Expose for options
module.GetActiveDisplayProfile = module.GetActiveDisplayProfile
module.GetActiveProfileMode = module.GetActiveProfileMode
module.EnsureProfiles = module.EnsureProfiles
module.MigrateProfiles = module.MigrateProfiles
module.InstallElvUIHooks = module.InstallElvUIHooks
module.GetSpellData = module.GetSpellData
module.ApplySettings = module.ApplySettings
module.ApplyProfileGlobals = module.ApplyProfileGlobals
module.SyncSpellDataFromDB = module.SyncSpellDataFromDB
module.OnAuraDisplaySettingChanged = module.OnAuraDisplaySettingChanged
module.OnAuraLayoutSettingChanged = module.OnAuraLayoutSettingChanged
module.OnAuraDataSettingChanged = module.OnAuraDataSettingChanged
module.ScheduleAuraLayoutRefresh = module.ScheduleAuraLayoutRefresh
module.ScheduleAuraRerender = module.ScheduleAuraRerender
module.AddSpell = module.AddSpell
module.RemoveSpell = module.RemoveSpell
module.StartTestMode = module.StartTestMode
module.StopTestMode = module.StopTestMode
