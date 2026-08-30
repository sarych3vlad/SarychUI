-- RaidRoll Wrapper for SarychUI
-- Single settings entry covers RaidRoll + RaidRoll_EPGP + RaidRoll_LootTracker
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "RaidRoll"

local wrapper = {
	name = ADDON_NAME,
	title = "RaidRoll",
	author = "Musou, доработка Сарыч",
	version = "1.0",
	enabled = false,
	loaded = false,
}

RaidRollEnabled = RaidRollEnabled or true

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return RaidRollEnabled ~= false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function GetSkinStyleFromDB()
	local addons = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	local style = addons and addons[ADDON_NAME] and addons[ADDON_NAME].skinStyle
	if style == "SarychUI" or style == "ElvUI" then
		return style
	end
	return "SarychUI"
end

local function SetSkinStyleInDB(style)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = { enabled = true }
	end
	SarychUI.db.profile.addons[ADDON_NAME].skinStyle = style
end

local function ApplyRaidRollRuntime(enable)
	RaidRollEnabled = enable and true or false
	if enable then
		if type(RaidRoll_RegisterInterfaceOptions) == "function" then
			RaidRoll_RegisterInterfaceOptions()
		end
	else
		if RR_RollFrame and RR_RollFrame.Hide then RR_RollFrame:Hide() end
		if RR_LOOT_FRAME and RR_LOOT_FRAME.Hide then RR_LOOT_FRAME:Hide() end
		if RR_OptionsFrame and RR_OptionsFrame.Hide then RR_OptionsFrame:Hide() end
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1RaidRoll|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
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
	ApplyRaidRollRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	wrapper.loaded = true
	RaidRollEnabled = wrapper.enabled
	if wrapper.enabled then
		ApplyRaidRollRuntime(true)
	else
		ApplyRaidRollRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	wrapper.loaded = true
	ApplyRaidRollRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyRaidRollRuntime(false)
	return true
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "RaidRoll",
		order = 50,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить RaidRoll (включая EPGP и Loot Tracker). При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
				order = 1,
				get = function()
					return wrapper:IsRuntimeEnabled()
				end,
				set = function(_, value)
					wrapper:SetRuntimeEnabled(value)
				end,
			},
			skinStyle = {
				type = "select",
				name = "Стиль окна",
				desc = "Внешний вид RaidRoll. ElvUI — плоский скин; SarychUI — текстуры как у окна настроек SarychUI. Требуется /reload.",
				order = 2,
				values = {
					ElvUI = "ElvUI",
					SarychUI = "SarychUI",
				},
				get = function()
					return GetSkinStyleFromDB()
				end,
				set = function(_, value)
					SetSkinStyleInDB(value)
					if SarychUI and SarychUI.ShowReloadPopup then
						SarychUI:ShowReloadPopup()
					elseif StaticPopup_Show then
						StaticPopup_Show("SARYCHUI_RELOAD_UI")
					end
				end,
			},
			description = {
				type = "description",
				name = "Рейд-роллы, EPGP и окно лута (RaidRoll + RaidRoll_EPGP + RaidRoll_LootTracker).\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "Musou")
					.. "\nВерсия: "
					.. (wrapper.version or "1.0"),
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
