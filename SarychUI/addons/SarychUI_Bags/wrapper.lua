-- SarychUI Bags wrapper for SarychUI
-- Bags mode valve (like BaudBag): enable immediate; reload on disable for mode cleanup.

local ADDON_NAME = "SarychUI_Bags"

local DEBUG_ELVUI_BAGS = false

local function bagDebug(...)
	if not DEBUG_ELVUI_BAGS then return end
	local prefix = (SarychUI and SarychUI.GetScopedChatPrefix and SarychUI:GetScopedChatPrefix("Bags wrapper")) or "|cffffd200SarychUI Bags wrapper:|r"
	print(prefix, ...)
end

local wrapper = {
	name = ADDON_NAME,
	title = "SarychUI Bags",
	author = "Elv; SarychUI integration",
	version = "1.00",
	loaded = true,
	runtimeEnabled = false,
}

local function GetEngine()
	return _G.SarychUI_Bags and _G.SarychUI_Bags[1]
end

local function GetBagsModule()
	return SarychUI and SarychUI.modules and SarychUI.modules.bags
end

function wrapper:IsRuntimeEnabled()
	local bags = GetBagsModule()
	if bags and bags.IsElvUIMode and bags:IsEnabled() then
		return bags:IsElvUIMode()
	end
	local E = GetEngine()
	if E and E.IsBagsRuntimeEnabled then
		return E:IsBagsRuntimeEnabled()
	end
	return self.runtimeEnabled == true
end

function wrapper:SetRuntimeEnabled(enable)
	enable = enable and true or false
	local E = GetEngine()
	if not E then
		bagDebug("SetRuntimeEnabled: engine missing")
		return false
	end

	if E.CheckElvUIConflict and E:CheckElvUIConflict() then
		bagDebug("SetRuntimeEnabled: ElvUI conflict")
		return false
	end

	if not E.loginReady then
		E.loginReady = true
	end

	if E.SyncBagsRuntimeFromSarychUI then
		E:SyncBagsRuntimeFromSarychUI()
	end

	if enable then
		bagDebug("Hook ToggleBackpack")
		bagDebug("Show unified bags")
		if E.StartBagsRuntime then
			E:StartBagsRuntime()
		end
	else
		bagDebug("Disable ElvUI bags")
		if E.ShutdownBagsRuntime then
			E:ShutdownBagsRuntime()
		end
	end

	self.runtimeEnabled = enable
	return true
end

function wrapper:Initialize()
	local E = GetEngine()
	if not E then return end

	if IsAddOnLoaded and IsAddOnLoaded("ElvUI") then
		E.disabledByConflict = true
		return
	end
end

function wrapper:Enable()
	if not self:IsRuntimeEnabled() then
		self:SetRuntimeEnabled(true)
	end
end

function wrapper:Disable()
	if self:IsRuntimeEnabled() then
		self:SetRuntimeEnabled(false)
	end
end

function wrapper:GetOptions()
	return {
		type = "group",
		name = "SarychUI Bags",
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить SarychUI Bags как режим сумок. Включение — сразу; при выключении нужен /reload для корректного возврата сумок.",
				order = 1,
				get = function()
					local db = SarychUI and SarychUI.db and SarychUI.db.profile
					return db and db.addons and db.addons.SarychUI_Bags and db.addons.SarychUI_Bags.enabled == true
				end,
				set = function(_, value)
					local db = SarychUI and SarychUI.db and SarychUI.db.profile
					local bags = db and db.modules and db.modules.bags
					local previous = (bags and bags.mode) or "default"
					if value == (previous == "elvui") then
						return
					end
					if value then
						SarychUI:EnableAddOn(ADDON_NAME)
						wrapper:SetRuntimeEnabled(true)
					else
						SarychUI:DisableAddOn(ADDON_NAME)
						wrapper:SetRuntimeEnabled(false)
						if SarychUI.ShowReloadPopup then
							SarychUI:ShowReloadPopup(
								"|cff1784d1SarychUI Bags|r отключён. Для корректного возврата стандартных сумок нужен /reload.",
								function()
									if SarychUI.SetBagsMode then
										SarychUI:SetBagsMode(previous)
									end
									if SarychUI.NotifySarychUIOptionsChange then
										SarychUI:NotifySarychUIOptionsChange()
									end
								end
							)
						elseif StaticPopup_Show then
							StaticPopup_Show("SARYCHUI_RELOAD_UI")
						end
					end
				end,
				disabled = function()
					return IsAddOnLoaded and IsAddOnLoaded("ElvUI")
				end,
			},
			description = {
				type = "description",
				name = function()
					if IsAddOnLoaded and IsAddOnLoaded("ElvUI") then
						return "|cffff0000Внимание:|r установлен полный |cff1784d1ElvUI|r — встроенная ElvUI-сумка недоступна."
					end
					return "SarychUI Bags — объединённая сумка.\nВключение — сразу; выключение режима сумок — после /reload.\n\nАвтор: " .. (wrapper.author or "") .. "\nВерсия: " .. (wrapper.version or "")
				end,
				order = 2,
				width = "full",
			},
		},
	}
end

local function RegisterWrapper()
	if SarychUI and SarychUI.RegisterAddOn then
		SarychUI:RegisterAddOn(ADDON_NAME, wrapper)
		bagDebug("wrapper registered")
		return true
	end
	return false
end

if not RegisterWrapper() then
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:SetScript("OnEvent", function(self, event, addonName)
		if addonName == "SarychUI" and RegisterWrapper() then
			self:UnregisterAllEvents()
		end
	end)
end

return wrapper
