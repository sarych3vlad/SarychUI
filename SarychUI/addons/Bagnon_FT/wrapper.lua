-- Bagnon_FT Wrapper for SarychUI
-- Manages loading and enabling/disabling of Bagnon_FT addon

local ADDON_NAME = "Bagnon_FT"
local addonPath = "Interface\\AddOns\\SarychUI\\addons\\Bagnon_FT\\"

-- Create wrapper module
local wrapper = {
	name = ADDON_NAME,
	author = "Tuller",
	version = "1.1.2",
	enabled = false,
	loaded = false,
}

-- Global enabled state
BagnonFTEnabled = BagnonFTEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.IsCoordinatedAddOnAllowed then
		return SarychUI:IsCoordinatedAddOnAllowed(ADDON_NAME)
	end
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false;
	end
	return BagnonFTEnabled;
end

-- Initialize wrapper

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return BagnonFTEnabled ~= false
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
	if SarychUI and SarychUI.IsCoordinatedAddOnAllowed then
		return SarychUI:IsCoordinatedAddOnAllowed(ADDON_NAME)
	end
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
		local cfg = SarychUI.db.profile.addons[ADDON_NAME]
		if not cfg or cfg.enabled ~= false then
			-- Set global enabled state
			BagnonFTEnabled = true
			self.enabled = true
			self.loaded = true
			
			-- Initialize BagnonDB if it exists
			if BagnonDB and BagnonDB.Initialize then
				BagnonDB:Initialize()
			end
		else
			-- Set global enabled state
			BagnonFTEnabled = false
			self.enabled = false
		end
	else
		-- Default to enabled if no database
		BagnonFTEnabled = true
		self.enabled = true
		self.loaded = true
		
		-- Initialize BagnonDB if it exists
		if BagnonDB and BagnonDB.Initialize then
			BagnonDB:Initialize()
		end
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
	BagnonFTEnabled = true
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = true
	end
	
	-- Initialize BagnonDB if it exists
	if BagnonDB and BagnonDB.Initialize then
		BagnonDB:Initialize()
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
	BagnonFTEnabled = false
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = false
	end
	
	-- Unregister all events from BagnonDB
	if BagnonDB then
		BagnonDB:UnregisterAllEvents()
	end
end

-- Get options table for settings
function wrapper:GetOptions()
	return {
		type = "group",
		name = "Bagnon FT",
		order = 25,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Bagnon FT (хранит информацию об инвентаре персонажей и показывает тултипы)",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			showOnAlt = {
				type = "toggle",
				name = "Показывать при зажатом Alt",
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				desc = "Показывать информацию о владельцах предметов только при зажатой клавише Alt",
				order = 2,
				width = "double",
				suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
				get = function()
					return SarychUI.db.profile.addons.Bagnon_FT.showOnAlt == true
				end,
				set = function(info, value)
					SarychUI.db.profile.addons.Bagnon_FT.showOnAlt = value
					if BagnonFT_UpdateAltState then
						BagnonFT_UpdateAltState()
					end
				end,
			},
			coordinationNote = {
				type = "description",
				name = "|cff808080Совместим с SarychUI Bags, классическими сумками и Bagnon — дополняет UI тултипами «у кого какой предмет».|r",
				order = 2.5,
				width = "full",
			},
			description = {
				type = "description",
				name = "Хранит информацию об инвентаре ваших персонажей и показывает тултипы с информацией о том, у кого какие предметы (Stores inventory information about your characters and shows tooltips for telling who has what).\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
				order = 3,
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

