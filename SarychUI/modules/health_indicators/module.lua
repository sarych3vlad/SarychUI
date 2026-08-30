-- SarychUI Health Indicators module
-- Settings-only module: controls ElvUI vs classic WoW nameplates and autolos distance display.

local moduleName = "health_indicators"
local module = {}

SarychUI:RegisterModule(moduleName, module)

local ENP_ADDON = "ElvUI_NamePlates"
local AUTOLOS_ADDON = "autolos"

function SarychUI:GetNameplateMode()
	local modules = self.db and self.db.profile and self.db.profile.modules
	local hi = modules and modules.health_indicators
	-- Module disabled → always classic at runtime.
	if hi and hi.enabled == false then
		return "classic"
	end
	if hi and hi.nameplateMode then
		return hi.nameplateMode
	end
	local addons = self.db and self.db.profile and self.db.profile.addons
	if addons and addons[ENP_ADDON] and addons[ENP_ADDON].enabled ~= false then
		return "elvui"
	end
	local wrapper = self.GetAddOn and self:GetAddOn(ENP_ADDON)
	if wrapper and wrapper.IsRuntimeEnabled and wrapper:IsRuntimeEnabled() then
		return "elvui"
	end
	return "classic"
end

local function GetAutolosDB()
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile or not SarychUI.db.profile.addons then
		return nil
	end
	return SarychUI.db.profile.addons[AUTOLOS_ADDON]
end

function module:IsAutolosEnabled()
	local db = GetAutolosDB()
	if db then
		return db.enabled ~= false
	end
	return _G.autolosEnabled ~= false
end

function module:SetAutolosEnabled(value)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[AUTOLOS_ADDON] then
		SarychUI.db.profile.addons[AUTOLOS_ADDON] = { enabled = true }
	end
	SarychUI.db.profile.addons[AUTOLOS_ADDON].enabled = value and true or false

	if value then
		SarychUI:EnableAddOn(AUTOLOS_ADDON)
	else
		SarychUI:DisableAddOn(AUTOLOS_ADDON)
	end
end

function module:EnsureAutolosProfiles()
	if _G.Autolos and _G.Autolos.EnsureProfiles then
		_G.Autolos.EnsureProfiles()
	end
end

function module:GetAutolosProfile()
	self:EnsureAutolosProfiles()
	if _G.Autolos and _G.Autolos.GetActiveProfile then
		return _G.Autolos.GetActiveProfile()
	end
	return nil
end

function module:GetAutolosProfileMode()
	return SarychUI:GetNameplateMode()
end

function module:ApplyAutolosTextStyle()
	if _G.Autolos and _G.Autolos.ApplyTextStylesAll then
		_G.Autolos.ApplyTextStylesAll()
	end
end

function module:ApplyAutolosLayout()
	if _G.Autolos and _G.Autolos.ApplyLayoutsAll then
		_G.Autolos.ApplyLayoutsAll()
	end
end

function module:ApplyAutolosSettings()
	if _G.Autolos and _G.Autolos.ApplySettings then
		_G.Autolos.ApplySettings()
	end
end

function module:RefreshConfig()
	self:EnsureAutolosProfiles()
	self:ApplyAutolosSettings()
end

function module:Initialize()
	self:EnsureAutolosProfiles()
	self:ApplyAutolosSettings()
end

function module:Enable() end

function module:Disable() end

return module
