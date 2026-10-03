-- SarychUI Maps
-- Native world map: Mapster-style presentation with Leatrix-style zoom/pan,
-- fog-of-war reveal, points of interest and zone information built in.
--
-- This file owns the map-mode selector, the module database and the component
-- registry. The actual world map work lives in the sibling files, each of which
-- registers itself through Maps:RegisterComponent.

local moduleName = "map"
local module = {}

SarychUI:RegisterModule(moduleName, module)

SarychUI.Maps = SarychUI.Maps or {}
local Maps = SarychUI.Maps

Maps.module = module
Maps.MEDIA = "Interface\\AddOns\\SarychUI\\media\\maps\\"

-- Standalone addons that drive the same WorldMapFrame internals we do. Running
-- either at the same time produces a broken map, so the module stays dormant.
local CONFLICTING_ADDONS = {
	"Mapster",
	"Cromulent",
	"WDM",
	"Leatrix_Maps",
	"Magnify",
	"MozzFullWorldMap",
	"Carbonite",
}

-- Keys that carry a separate value while the map is in windowed ("mini") mode.
local MINI_KEYS = {
	x = true,
	y = true,
	point = true,
	scale = true,
	alpha = true,
	hideBorder = true,
	disableMouse = true,
}

local components = {}
Maps.components = components

function Maps:RegisterComponent(name, component)
	component.name = name
	components[#components + 1] = component
	Maps[name] = component
	return component
end

----------------------------------------------------------------------
-- Database
----------------------------------------------------------------------

function Maps:DB()
	if SarychUI.GetModuleProfile then
		return SarychUI:GetModuleProfile(moduleName)
	end
	local profile = SarychUI.db and SarychUI.db.profile
	return profile and profile.modules and profile.modules[moduleName]
end

-- Reads a look-and-feel setting, honouring the windowed-mode override table.
function Maps:Get(key)
	local db = self:DB()
	if not db then return nil end
	if self.windowed and MINI_KEYS[key] then
		return db.mini and db.mini[key]
	end
	return db[key]
end

function Maps:Set(key, value)
	local db = self:DB()
	if not db then return end
	if self.windowed and MINI_KEYS[key] then
		db.mini = db.mini or {}
		db.mini[key] = value
		return
	end
	db[key] = value
end

-- LibWindow reads and writes x/y/point/scale through this proxy so the windowed
-- and maximised layouts keep independent positions, exactly like Mapster did.
Maps.windowStorage = setmetatable({}, {
	__index = function(_, key) return Maps:Get(key) end,
	__newindex = function(_, key, value) Maps:Set(key, value) end,
})

-- SarychUI only supports hiding objectives or showing blobs on the full map.
-- Convert the removed Mapster-style quest-panel mode (2), including values
-- stored in old profiles, to the new default full-map mode (1).
function Maps:GetQuestObjectiveMode()
	local db = self:DB()
	if not db then return 1 end
	if db.questObjectives == 0 then return 0 end
	if db.questObjectives ~= 1 then
		db.questObjectives = 1
	end
	return 1
end

function Maps:EnsureDefaults()
	local db = self:DB()
	local defaults = SarychUI.defaults and SarychUI.defaults.profile
		and SarychUI.defaults.profile.modules and SarychUI.defaults.profile.modules.map
	if not db or not defaults then return end

	for k, v in pairs(defaults) do
		if db[k] == nil then
			if type(v) == "table" and CopyTable then
				db[k] = CopyTable(v)
			else
				db[k] = v
			end
		end
	end
	if type(defaults.mini) == "table" then
		db.mini = db.mini or {}
		for k, v in pairs(defaults.mini) do
			if db.mini[k] == nil then
				db.mini[k] = v
			end
		end
	end
	if db.mapType == "mapster" then
		db.mapType = "sarychui"
	end
	-- Previous default was 0.5; retune once so movement fade is ~20% more transparent.
	if not db.movingAlphaRetuned then
		db.movingAlphaRetuned = true
		if db.movingAlpha == nil or db.movingAlpha == 0.5 then
			db.movingAlpha = 0.4
		end
	end
	if db.fogStyle ~= "standard" and db.fogStyle ~= "leatrix" then
		if db.fogTintR == 0.623 and db.fogTintG == 0.623 and db.fogTintB == 0.623 then
			db.fogStyle = "standard"
		else
			db.fogStyle = "leatrix"
		end
	end
	self:GetQuestObjectiveMode()
end

----------------------------------------------------------------------
-- Activation state
----------------------------------------------------------------------

function Maps:GetConflictingAddOn()
	if not IsAddOnLoaded then return nil end
	for i = 1, #CONFLICTING_ADDONS do
		local name = CONFLICTING_ADDONS[i]
		if IsAddOnLoaded(name) then
			return name
		end
	end
	return nil
end

function Maps:IsSelected()
	local db = self:DB()
	if not db or db.enabled == false then return false end
	return SarychUI:GetMapMode() == "sarychui"
end

function Maps:IsActive()
	return self.active == true
end

----------------------------------------------------------------------
-- Map mode API (shared with the coordinator and the options panel)
----------------------------------------------------------------------

function SarychUI:GetMapMode()
	local db = self.db and self.db.profile and self.db.profile.modules and self.db.profile.modules.map
	local mapType = db and db.mapType or "sarychui"
	if self.SanitizeMapType then
		return self:SanitizeMapType(mapType)
	end
	return mapType
end

function SarychUI:SetMapType(mapType)
	if not self.db or not self.db.profile then return end

	local addons = self.db.profile.addons
	local mapDb = self.db.profile.modules and self.db.profile.modules.map
	if not addons or not mapDb then return end

	addons.Carbonite = addons.Carbonite or { enabled = false }

	mapType = self:SanitizeMapType(mapType or "sarychui")
	mapDb.mapType = mapType
	addons.Carbonite.enabled = (mapType == "carbonite")
end

-- External Carbonite is the only map addon left that can claim the area, so the
-- profile flag and the module setting are kept in sync from its side too.
function SarychUI:SyncMapTypeFromAddons()
	if not self.db or not self.db.profile then return end

	local addons = self.db.profile.addons
	local mapDb = self.db.profile.modules and self.db.profile.modules.map
	if not addons or not mapDb then return end

	addons.Carbonite = addons.Carbonite or { enabled = false }

	if addons.Carbonite.enabled == true and self:IsExternalCarboniteAvailable() then
		mapDb.mapType = "carbonite"
	elseif mapDb.mapType == "carbonite" then
		mapDb.mapType = "sarychui"
	end

	mapDb.mapType = self:SanitizeMapType(mapDb.mapType)
end

function module:IsSarychUIMode()
	return SarychUI:GetMapMode() == "sarychui"
end

function module:IsCarboniteMode()
	return SarychUI:GetMapMode() == "carbonite"
end

----------------------------------------------------------------------
-- One-time migration of the old Mapster profile
----------------------------------------------------------------------

-- MapsterDB is still declared in the TOC purely so this runs once for users
-- upgrading from the Mapster-based map; nothing writes to it any more.
local function MapsterProfile()
	if type(MapsterDB) ~= "table" or type(MapsterDB.profiles) ~= "table" then
		return nil
	end

	local key
	if type(MapsterDB.profileKeys) == "table" then
		local name = UnitName("player")
		local realm = GetRealmName and GetRealmName() or nil
		if name and realm then
			key = MapsterDB.profileKeys[name .. " - " .. realm]
		end
	end

	local profile = key and MapsterDB.profiles[key] or MapsterDB.profiles["Default"]
	if profile then return profile end

	for _, candidate in pairs(MapsterDB.profiles) do
		return candidate
	end
	return nil
end

local MIGRATED_KEYS = {
	"strata", "alpha", "scale", "arrowScale", "poiScale",
	"questObjectives", "miniMap", "hideBorder", "disableMouse",
	"x", "y", "point",
}

local function migrateCromulent(db)
	if db.legacyCromulentMigrated then return end
	db.legacyCromulentMigrated = true
	local addons = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	local crom = addons and addons.Cromulent
	if crom and crom.enabled == false then
		db.zoneInfo = false
	end
end

function Maps:MigrateLegacySettings()
	local db = self:DB()
	if not db then return end

	if not db.legacyMapsterMigrated then
		db.legacyMapsterMigrated = true

		local src = MapsterProfile()
		if src then
			for i = 1, #MIGRATED_KEYS do
				local key = MIGRATED_KEYS[i]
				if src[key] ~= nil then
					db[key] = src[key]
				end
			end
			-- Mapster stored the maximised anchor under "points"; LibWindow uses "point".
			if src.point == nil and src.points ~= nil then
				db.point = src.points
			end

			if type(src.mini) == "table" then
				db.mini = db.mini or {}
				for key in pairs(MINI_KEYS) do
					if src.mini[key] ~= nil then
						db.mini[key] = src.mini[key]
					end
				end
			end

			if type(src.FogClear) == "table" then
				if src.FogClear.colorR then db.fogTintR = src.FogClear.colorR end
				if src.FogClear.colorG then db.fogTintG = src.FogClear.colorG end
				if src.FogClear.colorB then db.fogTintB = src.FogClear.colorB end
				if src.FogClear.colorA then db.fogTintA = src.FogClear.colorA end
			end

			if src.hideMapButton ~= nil then
				db.hideMapButton = src.hideMapButton and true or false
			end
		end

		MapsterDB = nil
	end

	migrateCromulent(db)
	if db.mapType == "mapster" then
		db.mapType = "sarychui"
	end
	self:GetQuestObjectiveMode()
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------

local function warnOnce(conflict)
	if Maps._conflictWarned then return end
	Maps._conflictWarned = true
	local L = SarychUI.L
	local text = L and L["Maps Conflict Warning"]
	if text then
		SarychUI:Print(format(text, conflict))
	else
		SarychUI:Print(format(
			"Карта SarychUI отключена: включён отдельный аддон %s. Отключите его в списке аддонов.", conflict))
	end
end

function module:Initialize()
	Maps:EnsureDefaults()
	Maps:MigrateLegacySettings()
end

function module:Enable()
	if Maps.active then return end
	Maps:EnsureDefaults()
	if not Maps:IsSelected() then return end

	local conflict = Maps:GetConflictingAddOn()
	if conflict then
		warnOnce(conflict)
		return
	end
	if not WorldMapFrame then return end

	Maps.active = true
	for i = 1, #components do
		local component = components[i]
		if component.Enable then
			component:Enable()
		end
	end
	Maps:Refresh()
end

function module:Disable()
	if not Maps.active then return end
	Maps.active = false
	for i = #components, 1, -1 do
		local component = components[i]
		if component.Disable then
			component:Disable()
		end
	end
end

-- Re-applies every live setting. Called after profile switches and whenever an
-- option in SarychUI -> Карта changes.
function Maps:Refresh()
	if not self.active then return end
	for i = 1, #components do
		local component = components[i]
		if component.Refresh then
			component:Refresh()
		end
	end
end

function module:Refresh()
	Maps:Refresh()
end

return module
