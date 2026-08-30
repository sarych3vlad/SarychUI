-- IdTip Wrapper for SarychUI
-- Manages loading and enabling/disabling of IdTip addon

local ADDON_NAME = "IdTip"
local addonPath = "Interface\\AddOns\\SarychUI\\addons\\IdTip\\"

-- Create wrapper module
local wrapper = {
	name = ADDON_NAME,
	author = "Silverwind",
	version = "2.00",
	enabled = false,
	loaded = false,
}

-- Global enabled state
IdTipEnabled = IdTipEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false;
	end
	return IdTipEnabled;
end

-- Initialize wrapper

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return IdTipEnabled ~= false
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
			IdTipEnabled = true
			self.enabled = true
			self.loaded = true
		else
			-- Set global enabled state
			IdTipEnabled = false
			self.enabled = false
		end
	else
		-- Default to enabled if no database
		IdTipEnabled = true
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
	IdTipEnabled = true
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = true
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
	IdTipEnabled = false
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = false
	end
end

-- Get options table for settings
function wrapper:GetOptions()
	return {
		type = "group",
		name = "IdTip",
		order = 8,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить IdTip",
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
				name = "Показывать при зажатии Alt",
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				desc = "Показывать ID только при зажатой клавише Alt",
				order = 2,
				width = "double",
				suiHelpIcon = SarychUI.DOTA_ALT_HELP_ICON,
				get = function()
					-- Если значение не установлено, возвращаем true (по умолчанию включено)
					local val = SarychUI.db.profile.addons.IdTip.showOnAlt
					return val ~= false  -- nil или true = включено, false = выключено
				end,
				set = function(info, value)
					-- Сохраняем значение (true или false)
					SarychUI.db.profile.addons.IdTip.showOnAlt = value
					-- Немедленно обновляем состояние Alt
					if IdTip_UpdateAltState then
						IdTip_UpdateAltState()
					end
				end,
			},
			description = {
				type = "description",
				name = "Добавляет ID в различные тултипы в игре (NPC, Quest, Achievement, Achievement Criteria, ItemID).\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
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

