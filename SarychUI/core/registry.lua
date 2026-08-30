-- SarychUI Module Registry
-- Handles registration and management of modules

local format = string.format
local tinsert, tremove = table.insert, table.remove
local ipairs = ipairs

local ADDON_NAME = "SarychUI"

-- Register a new module
function SarychUI:RegisterModule(name, moduleData)
	if not name or not moduleData then
		error("RegisterModule requires name and moduleData")
		return
	end
	
	if self.modules[name] then
		error(format("Module '%s' is already registered", name))
		return
	end
	
	-- Store module
	self.modules[name] = moduleData
	tinsert(self.moduleList, name)
	
	-- Set module reference to main AddOn
	moduleData.addon = self
	moduleData.db = self.db
	moduleData.name = name
	
	return moduleData
end

-- Unregister a module
function SarychUI:UnregisterModule(name)
	if not self.modules[name] then
		return
	end
	
	-- Disable module first
	if self.modules[name].Disable then
		self.modules[name]:Disable()
	end
	
	-- Remove from registry
	self.modules[name] = nil
	
	-- Remove from list
	for i, moduleName in ipairs(self.moduleList) do
		if moduleName == name then
			tremove(self.moduleList, i)
			break
		end
	end
end

-- Get a module by name
function SarychUI:GetModule(name)
	return self.modules[name]
end

-- Check if module is enabled
function SarychUI:IsModuleEnabled(name)
	if not self.modules[name] then
		return false
	end
	
	return self.db.profile.modules[name] and self.db.profile.modules[name].enabled or false
end

-- Enable a module
function SarychUI:EnableModule(name)
	local module = self.modules[name]
	if not module then
		return false
	end
	
	-- Update database
	if not self.db.profile.modules[name] then
		self.db.profile.modules[name] = {}
	end
	self.db.profile.modules[name].enabled = true
	
	-- Enable module
	if module.Enable then
		module:Enable()
	end
	
	return true
end

-- Disable a module
function SarychUI:DisableModule(name)
	local module = self.modules[name]
	if not module then
		return false
	end
	
	-- Update database
	if not self.db.profile.modules[name] then
		self.db.profile.modules[name] = {}
	end
	self.db.profile.modules[name].enabled = false
	
	-- Disable module
	if module.Disable then
		module:Disable()
	end
	
	return true
end

-- Toggle a module
function SarychUI:ToggleModule(name)
	if self:IsModuleEnabled(name) then
		return self:DisableModule(name)
	else
		return self:EnableModule(name)
	end
end

-- Get all modules
function SarychUI:GetModules()
	return self.modules
end

-- Get module list (sorted)
function SarychUI:GetModuleList()
	return self.moduleList
end

