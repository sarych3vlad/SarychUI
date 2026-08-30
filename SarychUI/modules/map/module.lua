-- SarychUI Map module
-- Settings coordinator for classic / Mapster / external Carbonite map modes.

local moduleName = "map"
local module = {}

SarychUI:RegisterModule(moduleName, module)

local MAPSTER_ADDON = "Mapster"

function SarychUI:GetMapMode()
	local db = self.db and self.db.profile and self.db.profile.modules and self.db.profile.modules.map
	local mapType = db and db.mapType or "mapster"
	if self.SanitizeMapType then
		return self:SanitizeMapType(mapType)
	end
	return mapType
end

function SarychUI:SyncMapTypeFromAddons()
	if not self.db or not self.db.profile then return end

	local addons = self.db.profile.addons
	local mapDb = self.db.profile.modules and self.db.profile.modules.map
	if not addons or not mapDb then return end

	addons.Mapster = addons.Mapster or { enabled = true }
	addons.Carbonite = addons.Carbonite or { enabled = false }

	if addons.Carbonite.enabled == true and self:IsExternalCarboniteAvailable() then
		mapDb.mapType = "carbonite"
		addons.Mapster.enabled = false
	elseif addons.Mapster.enabled ~= false then
		mapDb.mapType = "mapster"
		addons.Carbonite.enabled = false
	else
		mapDb.mapType = "classic"
		addons.Carbonite.enabled = false
	end

	mapDb.mapType = self:SanitizeMapType(mapDb.mapType)
end

function SarychUI:SetMapType(mapType)
	if not self.db or not self.db.profile then return end

	local addons = self.db.profile.addons
	local mapDb = self.db.profile.modules and self.db.profile.modules.map
	if not addons or not mapDb then return end

	addons.Mapster = addons.Mapster or { enabled = true }
	addons.Carbonite = addons.Carbonite or { enabled = false }

	mapType = self:SanitizeMapType(mapType or "mapster")
	mapDb.mapType = mapType

	if mapType == "mapster" then
		addons.Mapster.enabled = true
		addons.Carbonite.enabled = false
	elseif mapType == "carbonite" then
		addons.Mapster.enabled = false
		addons.Carbonite.enabled = true
	else
		addons.Mapster.enabled = false
		addons.Carbonite.enabled = false
	end
end

function module:IsMapsterMode()
	return SarychUI:GetMapMode() == "mapster"
end

function module:IsCarboniteMode()
	return SarychUI:GetMapMode() == "carbonite"
end

function module:Initialize()
	-- settings-only coordinator
end

function module:Enable()
	-- no runtime of its own
end

function module:Disable()
	-- no runtime of its own
end

return module
