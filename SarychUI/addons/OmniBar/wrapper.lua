-- OmniBar Wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.
-- Client has no loadfile: core is in TOC; valve = runtime + deferred Blizzard options.

local ADDON_NAME = "OmniBar"

local wrapper = {
	name = ADDON_NAME,
	author = "Jordon, Tsoukie",
	version = "1.0.7",
	enabled = false,
	loaded = false,
}

OmniBarEnabled = OmniBarEnabled or true

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return OmniBarEnabled
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function ApplyOmniBarRuntime(enable)
	OmniBarEnabled = enable and true or false
	if not OmniBar then
		return
	end

	if enable then
		if OmniBar.EnsureRuntimeInit then
			OmniBar:EnsureRuntimeInit()
		end
		if OmniBar.RegisterInterfaceOptions then
			OmniBar:RegisterInterfaceOptions()
		end
		if OmniBar.Enable and not OmniBar:IsEnabled() then
			OmniBar:Enable()
		elseif OmniBar.OnEnable then
			OmniBar:OnEnable()
		end
	else
		if OmniBar.Disable and OmniBar.IsEnabled and OmniBar:IsEnabled() then
			OmniBar:Disable()
		end
		if OmniBar.bars then
			for _, bar in pairs(OmniBar.bars) do
				if bar and bar.Hide then
					bar:Hide()
				end
			end
		end
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1OmniBar|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyOmniBarRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	wrapper.loaded = OmniBar ~= nil
	OmniBarEnabled = wrapper.enabled

	if not wrapper.enabled then
		ApplyOmniBarRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	wrapper.loaded = OmniBar ~= nil
	ApplyOmniBarRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyOmniBarRuntime(false)
	return true
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900OmniBar:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end

	ApplyOmniBarRuntime(true)

	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD then
		if SarychUI and SarychUI.CloseOptions then
			SarychUI:CloseOptions()
		end
		ACD:Open("OmniBar")
		return true
	end

	if InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory("OmniBar")
		InterfaceOptionsFrame_OpenToCategory("OmniBar")
		return true
	end

	return false
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "OmniBar",
		order = 14,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить OmniBar. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
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
				name = "Открыть настройки OmniBar",
				desc = "Открыть окно настроек OmniBar",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					wrapper:OpenConfig()
				end,
			},
			description = {
				type = "description",
				name = "Отслеживает кулдауны врагов (Tracks enemy cooldowns).\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "Неизвестен")
					.. "\nВерсия: "
					.. (wrapper.version or "Неизвестна"),
				order = 3,
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
