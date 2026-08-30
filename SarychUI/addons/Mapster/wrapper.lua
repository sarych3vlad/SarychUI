-- Mapster Wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "Mapster"

local wrapper = {
	name = ADDON_NAME,
	author = "Nevcairiel",
	version = "1.3.9",
	enabled = false,
	loaded = false,
}

MapsterEnabled = MapsterEnabled or true

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return MapsterEnabled
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false

	if SarychUI.SyncMapTypeFromAddons then
		SarychUI:SyncMapTypeFromAddons()
	end
end

local function IsStandaloneMapsterEnabled()
	local getInfo = SarychUI_MapsterGetAddOnInfo or GetAddOnInfo
	if not GetNumAddOns or not getInfo then return false end
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled, loadable = getInfo(i)
		if name == "Mapster" then
			return loadable and enabled and true or false
		end
	end
	return false
end

local function ApplyMapsterRuntime(enable)
	MapsterEnabled = enable and true or false

	if Mapster then
		if enable then
			if Mapster.RegisterInterfaceOptions then
				Mapster:RegisterInterfaceOptions()
			end
			if Mapster.Enable and not Mapster:IsEnabled() then
				Mapster:Enable()
			end
		elseif Mapster.Disable and Mapster.IsEnabled and Mapster:IsEnabled() then
			Mapster:Disable()
		end
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1Mapster|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
	elseif StaticPopup_Show then
		StaticPopup_Show("SARYCHUI_RELOAD_UI")
	end
end

function wrapper:IsRuntimeEnabled()
	if IsStandaloneMapsterEnabled() then
		return false
	end
	return GetRuntimeEnabledFromDB()
end

function wrapper:SetRuntimeEnabled(enable)
	if IsStandaloneMapsterEnabled() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Отключите отдельный аддон Mapster|r — иначе встроенный модуль не запустится.")
		end
		return false
	end

	SetRuntimeEnabledInDB(enable)
	wrapper.enabled = enable and true or false
	ApplyMapsterRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	MapsterEnabled = wrapper.enabled
	wrapper.loaded = Mapster ~= nil

	if IsStandaloneMapsterEnabled() then
		wrapper.enabled = false
		MapsterEnabled = false
		ApplyMapsterRuntime(false)
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff0000Отключите отдельный аддон Mapster|r — иначе встроенный модуль не запустится.")
		end
		return
	end

	-- Enable via EnableAddOns after Ace OnInitialize; only force-disable here.
	if not wrapper.enabled then
		ApplyMapsterRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	ApplyMapsterRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyMapsterRuntime(false)
	return true
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900Mapster:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end

	ApplyMapsterRuntime(true)

	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD then
		ACD:Open("Mapster")
		return true
	end

	if InterfaceOptionsFrame_OpenToCategory and Mapster and Mapster.optionsFrames and Mapster.optionsFrames.Mapster then
		InterfaceOptionsFrame_OpenToCategory(Mapster.optionsFrames.Mapster)
		return true
	end

	if SlashCmdList and SlashCmdList["MAPSTER"] then
		SlashCmdList["MAPSTER"]("")
		return true
	end

	return false
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "Mapster",
		order = 16,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Mapster. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					if value then
						if SarychUI and SarychUI.SetMapType then
							SarychUI:SetMapType("mapster")
						end
						wrapper:SetRuntimeEnabled(true)
					else
						if SarychUI and SarychUI.SetMapType then
							local carboniteOn = SarychUI.GetMapMode and SarychUI:GetMapMode() == "carbonite"
							SarychUI:SetMapType(carboniteOn and "carbonite" or "classic")
						end
						wrapper:SetRuntimeEnabled(false)
					end
				end,
			},
			open = {
				type = "execute",
				name = "Открыть настройки Mapster",
				desc = "Открыть окно настроек Mapster (/mapster)",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					if SarychUI and SarychUI.OpenMapsterConfig then
						SarychUI:OpenMapsterConfig()
					elseif wrapper.OpenConfig then
						wrapper:OpenConfig()
					end
				end,
			},
			description = {
				type = "description",
				name = "Простой мод карты (Simple Map Mod).\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "Неизвестен")
					.. "\nВерсия: "
					.. (wrapper.version or "Неизвестна"),
				order = 3,
				width = "full",
			},
			conflict = {
				type = "description",
				name = function()
					if IsStandaloneMapsterEnabled() then
						return "|cffff0000Внимание:|r отключите отдельный аддон |cff1784d1Mapster|r — иначе встроенный модуль не запустится."
					end
					return ""
				end,
				order = 4,
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
