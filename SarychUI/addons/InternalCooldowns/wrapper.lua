-- InternalCooldowns Wrapper for SarychUI
-- Manages loading and enabling/disabling of InternalCooldowns addon

local ADDON_NAME = "InternalCooldowns"
local addonPath = "Interface\\AddOns\\SarychUI\\addons\\InternalCooldowns\\"

-- Create wrapper module
local wrapper = {
	name = ADDON_NAME,
	author = "Сарыч (original - DarhangeR,Ardentvark)",
	version = "1.4",
	enabled = false,
	loaded = false,
}

-- Global enabled state
InternalCooldownsEnabled = InternalCooldownsEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false;
	end
	return InternalCooldownsEnabled;
end

-- Initialize wrapper

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return InternalCooldownsEnabled ~= false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function GetAceAddon()
	local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
	if not AceAddon or not AceAddon.GetAddon then return nil end
	local ok, addon = pcall(AceAddon.GetAddon, AceAddon, ADDON_NAME, true)
	return ok and addon or nil
end

-- Модули сами снимают события и останавливают свои OnUpdate в OnDisable, а
-- LibInternalCooldowns отпускает боевой лог, когда уходит последний подписчик.
-- Без этого каскада переключатель в /sui только менял флаг.
local function ApplyInternalCooldownsRuntime(enable)
	local addon = GetAceAddon()
	if not addon then return false end

	if enable then
		if addon.SetEnabledState then
			addon:SetEnabledState(true)
		end
		if addon.IsEnabled and not addon:IsEnabled() and addon.Enable then
			addon:Enable()
		end
	else
		if addon.IsEnabled and addon:IsEnabled() and addon.Disable then
			addon:Disable()
		end
		if addon.SetEnabledState then
			addon:SetEnabledState(false)
		end
	end

	return true
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
			InternalCooldownsEnabled = true
			self.enabled = true
			self.loaded = true
		else
			-- Set global enabled state
			InternalCooldownsEnabled = false
			self.enabled = false
			ApplyInternalCooldownsRuntime(false)
		end
	else
		-- Default to enabled if no database
		InternalCooldownsEnabled = true
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
	InternalCooldownsEnabled = true
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = true
	end

	-- Флаг должен быть выставлен до Enable: модули читают его в OnEnable.
	ApplyInternalCooldownsRuntime(true)
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
	InternalCooldownsEnabled = false
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = false
	end

	ApplyInternalCooldownsRuntime(false)
end

-- Get options table for settings
function wrapper:GetOptions()
	return {
		type = "group",
		name = "InternalCooldowns",
		order = 3,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить InternalCooldowns (таймеры перезарядки для аксессуаров/чар/особых камней)",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			description = {
				type = "description",
				name = "Добавляет таймеры перезарядки к вашим аксессуарам/чарам/особым камням.\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
				order = 2,
				width = "full",
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

