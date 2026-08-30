-- CL_Fix Wrapper for SarychUI
-- Manages loading and enabling/disabling of CL_Fix addon

local ADDON_NAME = "CL_Fix"
local addonPath = "Interface\\AddOns\\SarychUI\\addons\\CL_Fix\\"

-- Create wrapper module
local wrapper = {
	name = ADDON_NAME,
	author = "Gmad (Gjeneth @ Warmane - Outland)",
	version = "1.0",
	enabled = false,
	loaded = false,
}

-- Global enabled state
CL_FixEnabled = CL_FixEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false;
	end
	return CL_FixEnabled;
end

-- Initialize wrapper

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return CL_FixEnabled ~= false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

function wrapper:IsRuntimeEnabled()
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	enable = enable and true or false
	if enable then
		self.enabled = false
		self:Enable()
	else
		self.enabled = true
		self:Disable()
	end
	return true
end

function wrapper:Initialize()
	-- Check if addon should be enabled from database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if SarychUI.db.profile.addons[ADDON_NAME] and SarychUI.db.profile.addons[ADDON_NAME].enabled then
			-- Set global enabled state
			CL_FixEnabled = true
			self.enabled = true
			self.loaded = true
		else
			-- Set global enabled state
			CL_FixEnabled = false
			self.enabled = false
		end
	else
		-- Default to enabled if no database
		CL_FixEnabled = true
		self.enabled = true
		self.loaded = true
	end
end

-- Enable the addon
function wrapper:Enable()
	if self.enabled then
		return
	end
	
	-- Files are already loaded via TOC, we just mark as enabled
	-- The addon functionality is active when files are loaded
	self.enabled = true
	self.loaded = true
	
	-- Set global enabled state
	CL_FixEnabled = true
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = true
	end
	
	-- Enable the addon functionality
	if CL_Fix and CL_Fix.f and CL_Fix.fCLFix then
		if not (SarychUI and SarychUI.Compatibility and SarychUI.Compatibility:ShouldSkipCombatLogClear()) then
			CL_Fix.f:SetScript("OnUpdate", CL_Fix.fCLFix)
		end
	end
end

-- Disable the addon
function wrapper:Disable()
	if not self.enabled then
		return
	end
	
	-- Note: We can't really "unload" loaded Lua files, but we can disable functionality
	-- The addon will remain loaded but inactive
	self.enabled = false
	
	-- Set global enabled state
	CL_FixEnabled = false
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = false
	end
	
	-- Disable the addon functionality
	if CL_Fix and CL_Fix.f then
		CL_Fix.f:SetScript("OnUpdate", nil)
	end
end

-- Get options table for settings
function wrapper:GetOptions()
	local function IsWowOptimizeActive()
		return SarychUI and SarychUI.Compatibility and SarychUI.Compatibility:ShouldSkipCombatLogClear()
	end

	return {
		type = "group",
		name = "CL_Fix",
		order = 18,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = function()
					if IsWowOptimizeActive() then
						return "Активен wow_optimize — очистка combat log уже в DLL.\nВключать CL_Fix нет смысла."
					end
					return "Включить/выключить CL_Fix"
				end,
				order = 1,
				get = function()
					if IsWowOptimizeActive() then
						return false
					end
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					if value and IsWowOptimizeActive() then
						return
					end
					wrapper:SetRuntimeEnabled(value)
				end,
				disabled = function()
					return IsWowOptimizeActive()
				end,
			},
			description = {
				type = "description",
				name = "Обходной путь для бага Combat Log, введенного в патче 2.4.X, счетчики урона должны работать правильно (Workaround for the Combat Log bug introduced in patch 2.4.X, damage meters should work properly now).\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
				order = 2,
				width = "full",
			},
			compatNote = {
				type = "description",
				name = function()
					if not IsWowOptimizeActive() then
						return ""
					end
					return "|cFFFFD700Совместимость:|r активен wow_optimize — очистка combat log уже в DLL, CL_Fix отключён."
				end,
				order = 3,
				width = "full",
				hidden = function()
					return not IsWowOptimizeActive()
				end,
			},
		},
	}
end

-- Auto-register when SarychUI is available
local function RegisterWrapper()
	if SarychUI and SarychUI.RegisterAddOn then
		SarychUI:RegisterAddOn(ADDON_NAME, wrapper)
		return true
	end
	return false
end

-- Try to register immediately
if not RegisterWrapper() then
	-- Register after SarychUI loads
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", function(self, event, addonName)
		if event == "ADDON_LOADED" and addonName == "SarychUI" then
			if RegisterWrapper() then
				self:UnregisterEvent("ADDON_LOADED")
			end
		elseif event == "PLAYER_LOGIN" then
			if RegisterWrapper() then
				self:UnregisterEvent("PLAYER_LOGIN")
			end
		end
	end)
end

return wrapper

