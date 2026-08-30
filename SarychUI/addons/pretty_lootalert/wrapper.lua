-- pretty_lootalert Wrapper for SarychUI
-- Manages loading and enabling/disabling of pretty_lootalert addon

local ADDON_NAME = "pretty_lootalert"
local addonPath = "Interface\\AddOns\\SarychUI\\addons\\pretty_lootalert\\"

-- Create wrapper module
local wrapper = {
	name = ADDON_NAME,
	author = "s0high",
	version = "2.0",
	enabled = false,
	loaded = false,
}

-- Global enabled state
pretty_lootalertEnabled = pretty_lootalertEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false;
	end
	return pretty_lootalertEnabled;
end

-- Initialize wrapper

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return pretty_lootalertEnabled ~= false
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
			pretty_lootalertEnabled = true
			self.enabled = true
			self.loaded = true
		else
			-- Set global enabled state
			pretty_lootalertEnabled = false
			self.enabled = false
		end
	else
		-- Default to enabled if no database
		pretty_lootalertEnabled = true
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
	pretty_lootalertEnabled = true
	
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
	pretty_lootalertEnabled = false
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = false
	end
	
	-- Hide all loot alert frames when disabled
	if LootAlertFrame then
		for i = 1, LOOTALERT_NUM_BUTTONS or 5 do
			local button = _G["LootAlertButton"..i]
			if button then
				button:Hide()
			end
		end
	end
end

-- Get options table for settings
function wrapper:GetOptions()
	return {
		type = "group",
		name = "pretty_lootalert",
		order = 6,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить pretty_lootalert",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			castbarOffsetEnabled = {
				type = "toggle",
				name = "Смещать по Y при касте",
				desc = "Когда отображается полоса заклинания игрока, сдвигать всплывающие уведомления о луте по вертикали, чтобы не перекрывали кастбар",
				order = 2,
				width = "full",
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				get = function()
					local t = SarychUI.db.profile.addons.pretty_lootalert
					return t.castbarOffsetEnabled ~= false
				end,
				set = function(info, value)
					if not SarychUI.db.profile.addons.pretty_lootalert then
						SarychUI.db.profile.addons.pretty_lootalert = {}
					end
					SarychUI.db.profile.addons.pretty_lootalert.castbarOffsetEnabled = value
					if LootAlertFrame and LootAlertFrame.AdjustAnchors then
						LootAlertFrame:AdjustAnchors()
					end
				end,
			},
			castbarOffsetY = {
				type = "range",
				name = "Смещение Y при касте",
				desc = "Дополнительный отступ по вертикали (пиксели), пока открыта полоса каста. Положительные значения сдвигают тосты выше, отрицательные — ниже.",
				order = 3,
				min = -300,
				max = 300,
				step = 1,
				width = "full",
				disabled = function()
					local t = SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.pretty_lootalert
					return not (wrapper:IsRuntimeEnabled() and t and t.castbarOffsetEnabled ~= false)
				end,
				get = function()
					local t = SarychUI.db.profile.addons.pretty_lootalert
					local v = t.castbarOffsetY
					if v == nil then
						return 110
					end
					return v
				end,
				set = function(info, value)
					SarychUI.db.profile.addons.pretty_lootalert.castbarOffsetY = value
					if LootAlertFrame and LootAlertFrame.AdjustAnchors then
						LootAlertFrame:AdjustAnchors()
					end
				end,
			},
			description = {
				type = "description",
				name = "Оповещение о луте из прекрасного стаффа (Loot toast addon from pretty stuff).\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
				order = 4,
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

