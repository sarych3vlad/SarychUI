-- LootHistory Wrapper for SarychUI
-- Manages loading and enabling/disabling of LootHistory addon

local ADDON_NAME = "LootHistory"
local addonPath = "Interface\\AddOns\\SarychUI\\addons\\LootHistory\\"

-- Create wrapper module
local wrapper = {
	name = ADDON_NAME,
	author = "Artur91425",
	version = "1.2",
	enabled = false,
	loaded = false,
}

-- Global enabled state
LootHistoryEnabled = LootHistoryEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false;
	end
	return LootHistoryEnabled;
end

-- Initialize wrapper

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return LootHistoryEnabled ~= false
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
			LootHistoryEnabled = true
			self.enabled = true
			self.loaded = true
		else
			-- Set global enabled state
			LootHistoryEnabled = false
			self.enabled = false
		end
	else
		-- Default to enabled if no database
		LootHistoryEnabled = true
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
	LootHistoryEnabled = true
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = true
	end
	
	-- Обновляем кнопку на вкладке Loot, если настройка включена
	if _G.LootHistory_UpdateLootTabButton then
		-- Пытаемся создать кнопку сразу
		_G.LootHistory_UpdateLootTabButton()
		-- Дополнительная попытка на случай, если окна чата еще не загрузились
		if C_Timer and C_Timer.After then
			C_Timer.After(0.5, function()
				_G.LootHistory_UpdateLootTabButton()
			end)
		else
			-- Fallback для старых версий WoW
			local timer = CreateFrame("Frame")
			timer:SetScript("OnUpdate", function(self, elapsed)
				self.elapsed = (self.elapsed or 0) + elapsed
				if self.elapsed >= 0.5 then
					self:SetScript("OnUpdate", nil)
					_G.LootHistory_UpdateLootTabButton()
				end
			end)
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
	LootHistoryEnabled = false
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = false
	end
	
	-- Hide loot history frame when disabled
	if LootHistoryFrame then
		LootHistoryFrame:Hide()
	end
end

-- Get options table for settings
function wrapper:GetOptions()
	return {
		type = "group",
		name = "LootHistory",
		order = 11,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить LootHistory",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
					if _G.LootHistory_UpdateButtonVisibility then
						_G.LootHistory_UpdateButtonVisibility()
					end
				end,
			},
			lootTabButtonEnabled = {
				type = "toggle",
				name = "Включить кнопку на вкладке loot",
				desc = "Добавить кнопку на вкладку loot для быстрого доступа к LootHistory",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				get = function()
					if not wrapper:IsRuntimeEnabled() then
						return false
					end
					return SarychUI.db.profile.addons.LootHistory.lootTabButtonEnabled == true
				end,
				set = function(info, value)
					if not wrapper:IsRuntimeEnabled() then
						return
					end
					SarychUI.db.profile.addons.LootHistory.lootTabButtonEnabled = value
					if _G.LootHistory_UpdateLootTabButton then
						_G.LootHistory_UpdateLootTabButton()
					end
				end,
			},
			description = {
				type = "description",
				name = "Бекпорт функциональности LootHistory с WoW 5.4.8 (Backport LootHistory feature from WoW 5.4.8).\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
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

