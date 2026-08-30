-- autolos Wrapper for SarychUI
-- Manages loading and enabling/disabling of autolos addon

local ADDON_NAME = "autolos"

local wrapper = {
	name = ADDON_NAME,
	author = "frostatom",
	version = "1.0",
	enabled = false,
	loaded = false,
}

autolosEnabled = autolosEnabled or true

local function GetAutolos()
	return _G.Autolos
end

local function SyncGlobalEnabled(value)
	autolosEnabled = value and true or false
end

local function ApplyRuntimeState()
	local autolos = GetAutolos()
	if autolos then
		if autolos.EnsureProfiles then
			autolos.EnsureProfiles()
		end
		if autolos.ApplySettings then
			autolos.ApplySettings()
		end
	end
end


local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return autolosEnabled ~= false
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
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		local db = SarychUI.db.profile.addons[ADDON_NAME]
		if db and db.enabled ~= false then
			SyncGlobalEnabled(true)
			self.enabled = true
			self.loaded = true
		else
			SyncGlobalEnabled(false)
			self.enabled = false
		end
	else
		SyncGlobalEnabled(true)
		self.enabled = true
		self.loaded = true
	end

	ApplyRuntimeState()
end

function wrapper:Enable()
	if self.enabled then
		return
	end

	self.enabled = true
	self.loaded = true
	SyncGlobalEnabled(true)

	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = true
	end

	ApplyRuntimeState()
end

function wrapper:Disable()
	if not self.enabled then
		return
	end

	self.enabled = false
	SyncGlobalEnabled(false)

	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		if not SarychUI.db.profile.addons[ADDON_NAME] then
			SarychUI.db.profile.addons[ADDON_NAME] = {}
		end
		SarychUI.db.profile.addons[ADDON_NAME].enabled = false
	end

	ApplyRuntimeState()
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "autolos",
		order = 3,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Показывать дистанцию на неймплейтах. Нужен nameplate_range.dll (статус: Система -> Обзор). Настройки шрифта и позиции — в Модули -> Индикаторы здоровья.",
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
				name = "Показывает дистанцию до юнита на неймплейте (классические и ElvUI).\n\nТребуется nameplate_range.dll — без неё текст не появится. Статус DLL: Система -> Обзор.\n\nШрифт, размер, контур, тень и смещение настраиваются в Модули -> Индикаторы здоровья -> Дистанция до неймплейта.\n\nАвтор: " .. (self.author or "Неизвестен") .. "\nВерсия: " .. (self.version or "Неизвестна"),
				order = 2,
				width = "full",
			},
		},
	}
end

local function RegisterWrapper()
	if SarychUI and SarychUI.RegisterAddOn then
		SarychUI:RegisterAddOn(ADDON_NAME, wrapper)
		return true
	end
	return false
end

if not RegisterWrapper() then
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
