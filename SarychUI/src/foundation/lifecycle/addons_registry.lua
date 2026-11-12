-- SarychUI AddOns Registry
-- Handles registration and management of addons from addons folder

local format = string.format
local tinsert, tremove = table.insert, table.remove
local pairs, ipairs = pairs, ipairs

local ADDON_NAME = "SarychUI"

-- AddOn registry
SarychUI.addons = SarychUI.addons or {}
SarychUI.addonList = SarychUI.addonList or {}

-- Register a new addon from addons folder
function SarychUI:RegisterAddOn(addonName, addonData)
	if not addonName or not addonData then
		error("RegisterAddOn requires addonName and addonData")
		return
	end
	
	if self.addons[addonName] then
		error(format("AddOn '%s' is already registered", addonName))
		return
	end
	
	-- Store addon
	self.addons[addonName] = addonData
	tinsert(self.addonList, addonName)
	
	-- Set addon reference to main AddOn
	addonData.addon = self
	addonData.db = self.db
	addonData.name = addonName

	if self.MarkAddOnOptionsDirty then
		self:MarkAddOnOptionsDirty("RegisterAddOn:" .. addonName)
	end
	
	return addonData
end

-- Unregister an addon
function SarychUI:UnregisterAddOn(addonName)
	if not self.addons[addonName] then
		return
	end
	
	-- Disable addon first
	if self.addons[addonName].Disable then
		self.addons[addonName]:Disable()
	end
	
	-- Remove from registry
	self.addons[addonName] = nil
	
	-- Remove from list
	for i, name in ipairs(self.addonList) do
		if name == addonName then
			tremove(self.addonList, i)
			break
		end
	end

	if self.MarkAddOnOptionsDirty then
		self:MarkAddOnOptionsDirty("UnregisterAddOn:" .. addonName)
	end
end

-- Get an addon by name
function SarychUI:GetAddOn(addonName)
	return self.addons[addonName]
end

-- Check if addon is enabled
function SarychUI:IsAddOnEnabled(addonName)
	if not self.addons[addonName] then
		return false
	end

	local addonDb = self.db.profile.addons[addonName]
	return addonDb and addonDb.enabled or false
end

-- Only standalone embedded products are registered here. Native features use
-- their module lifecycle; Postal remains coordinated with the mail mode.
-- Enable an addon
function SarychUI:EnableAddOn(addonName)
	local addon = self.addons[addonName]
	if not addon then
		return false
	end

	if not self._coordinatorApplying and self.CanEnableCoordinatedAddOn then
		local ok, reason = self:CanEnableCoordinatedAddOn(addonName)
		if not ok then
			if reason and self.Print then
				self:Print(reason)
			end
			return false
		end
	end

	-- Update database
	if not self.db.profile.addons[addonName] then
		self.db.profile.addons[addonName] = {}
	end
	self.db.profile.addons[addonName].enabled = true
	
	-- Enable addon
	if addon.Enable then
		addon:Enable()
	end

	if not self._coordinatorApplying and self.ApplyFeatureCoordination then
		self:ApplyFeatureCoordination({ source = "EnableAddOn:" .. addonName, refreshPlates = false })
	end
	
	return true
end

-- Disable an addon
function SarychUI:DisableAddOn(addonName)
	local addon = self.addons[addonName]
	if not addon then
		return false
	end

	-- Update database
	if not self.db.profile.addons[addonName] then
		self.db.profile.addons[addonName] = {}
	end
	self.db.profile.addons[addonName].enabled = false
	
	-- Disable addon
	if addon.Disable then
		addon:Disable()
	end

	if not self._coordinatorApplying and self.ApplyFeatureCoordination then
		self:ApplyFeatureCoordination({ source = "DisableAddOn:" .. addonName, refreshPlates = false })
	end
	
	return true
end

-- Toggle an addon
function SarychUI:ToggleAddOn(addonName)
	if self:IsAddOnEnabled(addonName) then
		return self:DisableAddOn(addonName)
	else
		return self:EnableAddOn(addonName)
	end
end

-- Get all addons
function SarychUI:GetAddOns()
	return self.addons
end

-- Get addon list (sorted)
function SarychUI:GetAddOnList()
	return self.addonList
end

local RAID_FRAME_INIT_ORDER = {}

local function ForEachAddOnInOrder(addons, callback)
	local done = {}
	for _, name in ipairs(RAID_FRAME_INIT_ORDER) do
		local addon = addons[name]
		if addon then
			done[name] = true
			callback(name, addon)
		end
	end
	for name, addon in pairs(addons) do
		if not done[name] then
			callback(name, addon)
		end
	end
end

-- Initialize all registered addons
function SarychUI:InitializeAddOns()
	ForEachAddOnInOrder(self.addons, function(_, addon)
		if addon.Initialize then
			addon:Initialize()
		end
	end)
end

-- Enable all registered addons that are enabled in settings
function SarychUI:EnableAddOns()
	ForEachAddOnInOrder(self.addons, function(name, addon)
		local addonDb = self.db.profile.addons[name]
		local enabled = addonDb and addonDb.enabled
		if addon.Enable and enabled then
				addon:Enable()
		end
	end)
end

-- Reconcile embedded addon runtime state with the active profile.
function SarychUI:ApplyAddOnProfileState()
	if not self.addons or not self:GetActiveProfile() then
		return
	end

	ForEachAddOnInOrder(self.addons, function(name, addon)
		local shouldEnable = self:IsAddOnEnabled(name)

		local isRunning = addon.IsRuntimeEnabled and addon:IsRuntimeEnabled()
		if isRunning == nil then
			isRunning = shouldEnable
		end

		if shouldEnable and not isRunning and addon.Enable then
			addon:Enable()
		elseif not shouldEnable and isRunning and addon.Disable then
			addon:Disable()
		end
	end)
end

-- Disable all addons
function SarychUI:DisableAddOns()
	for name, addon in pairs(self.addons) do
		if addon.Disable then
			addon:Disable()
		end
	end
end

