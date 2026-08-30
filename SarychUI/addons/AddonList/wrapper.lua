-- AddonList Wrapper for SarychUI
-- Manages enabling/disabling of the embedded Addon List UI

local ADDON_NAME = "AddonList"

local wrapper = {
	name = ADDON_NAME,
	author = "Blizzard, Tsoukie",
	version = "1.2",
	enabled = false,
	loaded = false,
}

AddonListEnabled = AddonListEnabled ~= false

local function EnsureDb()
	if not (SarychUI and SarychUI.db and SarychUI.db.profile) then
		return nil
	end
	local addons = SarychUI.db.profile.addons
	if not addons then
		return nil
	end
	-- Migrate ACP toggle into AddonList once.
	if addons.ACP and addons.AddonList == nil then
		addons.AddonList = { enabled = addons.ACP.enabled ~= false }
	end
	if not addons.AddonList then
		addons.AddonList = { enabled = true }
	end
	return addons.AddonList
end

local function IsEnabled()
	local db = EnsureDb()
	if db then
		return db.enabled ~= false
	end
	return AddonListEnabled ~= false
end

local function SetGameMenuButtonVisible(visible)
	local btn = _G.GameMenuButtonAddons
	local menu = _G.GameMenuFrame
	if not btn or not menu then
		return
	end
	local heightDelta = btn._sarychMenuHeight or (btn:GetHeight() + 16)
	if visible then
		if not btn:IsShown() then
			btn:Show()
			menu:SetHeight(menu:GetHeight() + heightDelta)
		end
	else
		if btn:IsShown() then
			btn:Hide()
			menu:SetHeight(math.max(menu:GetHeight() - heightDelta, 1))
		end
	end
end

-- Retry show after DB is definitely available (covers late profile load).
local function ScheduleInit()
	local boot = CreateFrame("Frame")
	boot:RegisterEvent("PLAYER_LOGIN")
	boot:SetScript("OnEvent", function(self)
		wrapper:Initialize()
		-- One more pass next frame in case AceDB profile finishes after LOGIN handlers.
		self:SetScript("OnUpdate", function(frame, elapsed)
			frame.elapsed = (frame.elapsed or 0) + elapsed
			if frame.elapsed > 0.1 then
				wrapper:Initialize()
				if _G.AddonListEnabled ~= false then
					SetGameMenuButtonVisible(true)
				end
				frame:SetScript("OnUpdate", nil)
				frame:UnregisterAllEvents()
			end
		end)
	end)
end


local function GetRuntimeEnabledFromDB()
	local db = EnsureDb()
	if db then
		return db.enabled ~= false
	end
	return AddonListEnabled ~= false
end

local function SetRuntimeEnabledInDB(enable)
	local db = EnsureDb()
	if db then
		db.enabled = enable and true or false
	end
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
	local db = EnsureDb()
	-- If DB is not ready yet, keep the button enabled (do not hide it).
	local enabled = true
	if db then
		enabled = db.enabled ~= false
	end
	AddonListEnabled = enabled
	self.enabled = enabled
	self.loaded = true
	SetGameMenuButtonVisible(enabled)
	if not enabled and _G.AddonList then
		HideUIPanel(_G.AddonList)
	end
end

function wrapper:Enable()
	if self.enabled then
		return
	end
	self.enabled = true
	self.loaded = true
	AddonListEnabled = true

	local db = EnsureDb()
	if db then
		db.enabled = true
	end

	SetGameMenuButtonVisible(true)
end

function wrapper:Disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	AddonListEnabled = false

	local db = EnsureDb()
	if db then
		db.enabled = false
	end

	if _G.AddonList then
		HideUIPanel(_G.AddonList)
	end
	SetGameMenuButtonVisible(false)
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "AddonList",
		order = 3,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Addon List (список модификаций в игровом меню)",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			open = {
				type = "execute",
				name = "Открыть Addon List",
				desc = "Открыть список модификаций",
				order = 1.5,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					if _G.AddonList then
						ShowUIPanel(_G.AddonList)
					end
				end,
			},
			description = {
				type = "description",
				name = "Стандартный список модификаций в стиле Blizzard: пункт в игровом меню, включение/выключение аддонов, загрузка устаревших.\n\nАвтор: "
					.. (self.author or "Неизвестен")
					.. "\nВерсия: "
					.. (self.version or "Неизвестна"),
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
	frame:SetScript("OnEvent", function(self, event, addonName)
		if event == "ADDON_LOADED" and addonName == "SarychUI" then
			if RegisterWrapper() then
				self:UnregisterEvent("ADDON_LOADED")
			end
		end
	end)
end

ScheduleInit()

return wrapper
