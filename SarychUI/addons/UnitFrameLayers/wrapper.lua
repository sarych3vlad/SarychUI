-- UnitFrameLayers Wrapper for SarychUI
-- Manages loading and enabling/disabling of UnitFrameLayers addon

local ADDON_NAME = "UnitFrameLayers"
local addonPath = "Interface\\AddOns\\SarychUI\\addons\\UnitFrameLayers\\"

UnitFrameLayersEnabled = UnitFrameLayersEnabled or true

-- Create wrapper module
local wrapper = {
	name = ADDON_NAME,
	author = "RomanSpector",
	version = "1.0.1",
	enabled = false,
	loaded = false,
}

-- Initialize wrapper

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return UnitFrameLayersEnabled ~= false
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
			UnitFrameLayersEnabled = true
			self.enabled = true
			self.loaded = true
		else
			-- Set global enabled state
			UnitFrameLayersEnabled = false
			self.enabled = false
		end
	else
		-- Default to enabled if no database
		UnitFrameLayersEnabled = true
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
	UnitFrameLayersEnabled = true
	
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
	UnitFrameLayersEnabled = false
	
	-- Update database
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = false
	end
	
	-- Hide all prediction bars when disabled
	local units = {"player", "target", "focus", "party1", "party2", "party3", "party4"}
	for _, u in ipairs(units) do
		local frame = _G[u.."Frame"]
		if frame then
			if frame.myHealPredictionBar then frame.myHealPredictionBar:Hide() end
			if frame.otherHealPredictionBar then frame.otherHealPredictionBar:Hide() end
			if frame.totalAbsorbBar then frame.totalAbsorbBar:Hide() end
			if frame.overAbsorbGlow then frame.overAbsorbGlow:Hide() end
			if frame.overHealAbsorbGlow then frame.overHealAbsorbGlow:Hide() end
			if frame.healAbsorbBar then frame.healAbsorbBar:Hide() end
			if frame.myManaCostPredictionBar then frame.myManaCostPredictionBar:Hide() end
		end
	end
end

-- Get options table for settings
function wrapper:GetOptions()
	return {
		type = "group",
		name = "UnitFrameLayers",
		order = 1,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить UnitFrameLayers",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			classColorHP = {
				type = "toggle",
				name = "Цвет класса для полосы здоровья",
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				desc = "Включить/выключить цвет полосы здоровья в цвет класса игрока",
				order = 2,
				width = "double",
				get = function()
					-- Если значение не установлено, возвращаем true (по умолчанию включено)
					local val = SarychUI.db.profile.addons.UnitFrameLayers.classColorHP
					return val ~= false  -- nil или true = включено, false = выключено
				end,
				set = function(info, value)
					-- Сохраняем значение (true или false)
					SarychUI.db.profile.addons.UnitFrameLayers.classColorHP = value
					-- Обновляем цвет HP в реальном времени для всех доступных фреймов
					local units = {"player", "target", "focus", "party1", "party2", "party3", "party4"}
					for _, u in ipairs(units) do
						local frame = _G[u.."Frame"]
						if frame and frame.healthbar then
							-- Вызываем UpdateHealthBarColor напрямую (проверка UnitExists внутри функции)
							if UpdateHealthBarColor then
								UpdateHealthBarColor(frame)
							end
						end
					end
				end,
			},
			playerClassColorHP = {
				type = "toggle",
				name = "Плеер: цвет класса для полосы здоровья",
				desc = "Включить/выключить цвет полосы здоровья игрока в цвет класса",
				order = 3,
				width = "double",
				hidden = function()
					-- Скрываем, если основная настройка выключена
					local val = SarychUI.db.profile.addons.UnitFrameLayers.classColorHP
					return val == false
				end,
				disabled = function()
					-- Отключаем, если основная настройка выключена
					local val = SarychUI.db.profile.addons.UnitFrameLayers.classColorHP
					return val == false
				end,
				get = function()
					-- Если значение не установлено, возвращаем false (по умолчанию выключено)
					local val = SarychUI.db.profile.addons.UnitFrameLayers.playerClassColorHP
					return val == true
				end,
				set = function(info, value)
					-- Сохраняем значение (true или false)
					SarychUI.db.profile.addons.UnitFrameLayers.playerClassColorHP = value
					-- Обновляем цвет HP игрока в реальном времени
					local frame = _G["PlayerFrame"]
					if frame and frame.healthbar then
						if UpdateHealthBarColor then
							UpdateHealthBarColor(frame)
						end
					end
				end,
			},
			description = {
				type = "description",
				name = "Добавление анимации и текстур предикт лечения / абсорба и т.д. к стандартным blizz-frames.\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
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

