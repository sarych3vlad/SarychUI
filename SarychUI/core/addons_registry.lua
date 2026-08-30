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
	if addonName == "Mapster" or addonName == "WDM" or addonName == "!Astrolabe" then
		if not addonDb then
			return true
		end
		return addonDb.enabled ~= false
	end

	return addonDb and addonDb.enabled or false
end

local function CoordinatorSetModeForAddOn(self, addonName, enable)
	if self._coordinatorApplying or not enable then
		return
	end
	if addonName == "Mapster" and self.SetMapType then
		self:SetMapType("mapster")
	elseif addonName == "Carbonite" and self.SetMapType then
		self:SetMapType("carbonite")
	elseif addonName == "GladiusEx" and self.SetArenaMode then
		self:SetArenaMode("gladiusex")
	elseif addonName == "ElvUI_NamePlates" and self.SetNameplateMode then
		self:SetNameplateMode("elvui")
	elseif addonName == "BaudBag" and self.SetBagsMode then
		self:SetBagsMode("baudbag")
	elseif addonName == "SarychUI_Bags" and self.SetBagsMode then
		self:SetBagsMode("elvui")
	elseif addonName == "pretty_lootalert" and self.SetLootMode then
		self:SetLootMode("pretty")
	elseif addonName == "Postal" then
		local addons = self.db.profile.addons
		if addons and addons.Postal then
			addons.Postal.enabled = true
		end
	end
end

local function CoordinatorClearModeForAddOn(self, addonName)
	if self._coordinatorApplying then
		return
	end
	if addonName == "GladiusEx" and self.SetArenaMode then
		self:SetArenaMode("classic")
	elseif addonName == "ElvUI_NamePlates" and self.SetNameplateMode then
		self:SetNameplateMode("classic")
	elseif addonName == "BaudBag" and self.SetBagsMode then
		local bags = self.db and self.db.profile and self.db.profile.modules and self.db.profile.modules.bags
		if bags and bags.mode == "baudbag" then
			self:SetBagsMode("default")
		end
	elseif addonName == "SarychUI_Bags" and self.SetBagsMode then
		local bags = self.db and self.db.profile and self.db.profile.modules and self.db.profile.modules.bags
		if bags and bags.mode == "elvui" then
			self:SetBagsMode("default")
		end
	elseif addonName == "Mapster" and self.SetMapType and self.GetMapMode and self:GetMapMode() == "mapster" then
		self:SetMapType("classic")
	elseif addonName == "Carbonite" and self.SetMapType and self.GetMapMode and self:GetMapMode() == "carbonite" then
		self:SetMapType("classic")
	elseif addonName == "pretty_lootalert" and self.SetLootMode then
		self:SetLootMode("classic")
	end
end

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

	CoordinatorSetModeForAddOn(self, addonName, true)
	
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

	CoordinatorClearModeForAddOn(self, addonName)
	
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

-- Initialize all registered addons
function SarychUI:InitializeAddOns()
	for name, addon in pairs(self.addons) do
		if addon.Initialize then
			addon:Initialize()
		end
	end
end

-- Enable all registered addons that are enabled in settings
function SarychUI:EnableAddOns()
	for name, addon in pairs(self.addons) do
		local addonDb = self.db.profile.addons[name]
		local enabled = addonDb and addonDb.enabled
		if name == "Mapster" or name == "WDM" or name == "!Astrolabe" then
			enabled = not addonDb or addonDb.enabled ~= false
		end
		if addon.Enable and enabled then
			if SarychUI_ProfileStartupStage then
				SarychUI_ProfileStartupStage("OnEnable.addon:" .. name, addon.Enable, addon)
			else
				addon:Enable()
			end
		end
	end
end

-- Reconcile embedded addon runtime state with the active profile.
function SarychUI:ApplyAddOnProfileState()
	if not self.addons or not self:GetActiveProfile() then
		return
	end

	for name, addon in pairs(self.addons) do
		local shouldEnable = self:IsAddOnEnabled(name)
		if name == "Mapster" or name == "WDM" or name == "!Astrolabe" then
			local addonDb = self:GetAddonProfile(name)
			shouldEnable = not addonDb or addonDb.enabled ~= false
		end

		local isRunning = addon.IsRuntimeEnabled and addon:IsRuntimeEnabled()
		if isRunning == nil then
			isRunning = shouldEnable
		end

		if shouldEnable and not isRunning and addon.Enable then
			addon:Enable()
		elseif not shouldEnable and isRunning and addon.Disable then
			addon:Disable()
		end
	end
end

-- Disable all addons
function SarychUI:DisableAddOns()
	for name, addon in pairs(self.addons) do
		if addon.Disable then
			addon:Disable()
		end
	end
end

