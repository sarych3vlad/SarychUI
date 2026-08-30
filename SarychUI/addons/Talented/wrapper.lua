-- Talented Wrapper for SarychUI
-- Cursor-like valve: enable works immediately; disable + /reload clears Blizzard Mods entry.

local ADDON_NAME = "Talented"

local wrapper = {
	name = ADDON_NAME,
	title = "Talented",
	author = "Jerry (Kader Edition), доработка Сарыч",
	version = "v2.4.8",
	enabled = false,
	loaded = false,
}

TalentedEnabled = TalentedEnabled or true

local function GetRuntimeEnabledFromDB()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons[ADDON_NAME] then
		return SarychUI.db.profile.addons[ADDON_NAME].enabled ~= false
	end
	return TalentedEnabled ~= false
end

local function SetRuntimeEnabledInDB(enable)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = {}
	end
	SarychUI.db.profile.addons[ADDON_NAME].enabled = enable and true or false
end

local function ApplyTalentedRuntime(enable)
	TalentedEnabled = enable and true or false
	if not Talented then return end
	if enable then
		if Talented.RegisterInterfaceOptions then
			Talented:RegisterInterfaceOptions()
		end
		if Talented.Enable and not Talented:IsEnabled() then
			Talented:Enable()
		end
	elseif Talented.Disable and Talented.IsEnabled and Talented:IsEnabled() then
		Talented:Disable()
	end
end

local function ShowDisableReloadPopup()
	if SarychUI and SarychUI.ShowReloadPopup then
		SarychUI:ShowReloadPopup("|cff1784d1Talented|r будет убран из «Интерфейс → Модификации» после перезагрузки (/reload).")
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
	ApplyTalentedRuntime(enable)
	if not enable then
		ShowDisableReloadPopup()
	end
	return true
end

function wrapper:Initialize()
	wrapper.enabled = GetRuntimeEnabledFromDB()
	wrapper.loaded = Talented ~= nil
	TalentedEnabled = wrapper.enabled
	if not wrapper.enabled then
		ApplyTalentedRuntime(false)
	end
end

function wrapper:Enable()
	if not GetRuntimeEnabledFromDB() then
		return false
	end
	wrapper.enabled = true
	wrapper.loaded = Talented ~= nil
	ApplyTalentedRuntime(true)
	return true
end

function wrapper:Disable()
	wrapper.enabled = false
	SetRuntimeEnabledInDB(false)
	ApplyTalentedRuntime(false)
	return true
end

function wrapper:OpenConfig()
	if not GetRuntimeEnabledFromDB() then
		if SarychUI and SarychUI.Print then
			SarychUI:Print("|cffff9900Talented:|r сначала включите аддон в |cff1784d1Настройки → Аддоны|r.")
		end
		return false
	end

	ApplyTalentedRuntime(true)

	if Talented and Talented.OpenOptionsFrame then
		if SarychUI and SarychUI.CloseOptions then
			SarychUI:CloseOptions()
		end
		Talented:OpenOptionsFrame()
		return true
	end
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD then
		ACD:Open("Talented")
		return true
	end
	return false
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

local function GetTalentedScale()
	if Talented and Talented.db and Talented.db.profile and type(Talented.db.profile.scale) == "number" then
		return Talented.db.profile.scale
	end
	return 1.05
end

local function SetTalentedScale(value)
	if not Talented or not Talented.db or not Talented.db.profile then return end
	if Talented.db.profile.scale == value then return end
	Talented.db.profile.scale = value
	if Talented.ReLayout then
		Talented:ReLayout()
	elseif Talented.frame then
		Talented.frame:SetScale(value)
	end
end

local function GetDragonflightHeaderFromDB()
	local addons = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons
	local cfg = addons and addons[ADDON_NAME]
	if cfg and cfg.dragonflightHeader == false then
		return false
	end
	return true
end

local function SetDragonflightHeaderInDB(enabled)
	if not SarychUI or not SarychUI.db or not SarychUI.db.profile then return end
	SarychUI.db.profile.addons = SarychUI.db.profile.addons or {}
	if not SarychUI.db.profile.addons[ADDON_NAME] then
		SarychUI.db.profile.addons[ADDON_NAME] = { enabled = true }
	end
	SarychUI.db.profile.addons[ADDON_NAME].dragonflightHeader = not not enabled
end

local function RefreshTalentedChrome()
	local frame = _G.TalentedFrame or (Talented and Talented.base) or (Talented and Talented.frame)
	if frame and frame.SetTabSize then
		frame:SetTabSize(frame.tabCount or 3)
	end
	if Talented and Talented.view and Talented.view.SetClass and Talented.view.class then
		Talented.view:SetClass(Talented.view.class, true)
	elseif Talented and Talented.ReLayout then
		Talented:ReLayout()
	end
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "Talented",
		order = 51,
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить/выключить Talented. При выключении нужен /reload, чтобы убрать пункт из «Интерфейс → Модификации».",
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
				desc = "Внешний вид Talented. ElvUI — плоский скин; SarychUI — текстуры как у окна настроек SarychUI. Требуется /reload.",
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
			dragonflightHeader = {
				type = "toggle",
				name = "Шапка в стиле Dragonflight",
				desc = "Декоративная полоса заголовка из текстуры трекера заданий (Dragonflight), как у сумок SarychUI.",
				order = 3,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				suiLiveApply = true,
				get = function()
					return GetDragonflightHeaderFromDB()
				end,
				set = function(_, value)
					SetDragonflightHeaderInDB(value)
					RefreshTalentedChrome()
				end,
			},
			scaleBox = {
				type = "group",
				name = "Масштаб",
				order = 4,
				inline = true,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				args = {
					scale = {
						type = "range",
						name = "Масштаб окна",
						desc = "Масштаб окна Talented (1.0 = 100%).",
						order = 1,
						min = 0.5,
						max = 2.0,
						step = 0.05,
						width = "full",
						suiLiveApply = true,
						get = function()
							return GetTalentedScale()
						end,
						set = function(_, value)
							SetTalentedScale(value)
						end,
					},
				},
			},
			open = {
				type = "execute",
				name = "Открыть настройки Talented",
				desc = "Открыть окно настроек Talented",
				order = 5,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					wrapper:OpenConfig()
				end,
			},
			description = {
				type = "description",
				name = "Редактор шаблонов талантов (The Talent Template Editor).\nВключение — сразу; выключение из списка Модификаций — после /reload.\n\nАвтор: "
					.. (wrapper.author or "Jerry")
					.. "\nВерсия: "
					.. (wrapper.version or "v2.4.8"),
				order = 6,
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
