-- BaudBag wrapper for SarychUI (bags mode: baudbag)

local ADDON_NAME = "BaudBag"

local wrapper = {
	name = ADDON_NAME,
	title = "Baud Bag",
	author = "Baudzilla",
	version = "1.4.9",
	loaded = true,
	runtimeEnabled = false,
}

local restoring = false

local function GetBagsModule()
	return SarychUI and SarychUI.modules and SarychUI.modules.bags
end

local function EnsureCache()
	if type(BaudBag_Cache) ~= "table" then
		BaudBag_Cache = {}
	end
	return BaudBag_Cache
end

local function EnsureCfg()
	if type(BaudBag_Cfg) ~= "table" then
		BaudBag_Cfg = {}
	end
	if type(BaudBag_Cfg[1]) ~= "table" then
		BaudBag_Cfg[1] = {}
	end
	if type(BaudBag_Cfg[2]) ~= "table" then
		BaudBag_Cfg[2] = {}
	end
	EnsureCache()
	return BaudBag_Cfg
end

local function SetBagSetEnabled(cfg, bagSet, enabled)
	if type(cfg[bagSet]) ~= "table" then
		cfg[bagSet] = {}
	end
	cfg[bagSet].Enabled = enabled and true or false
end

local function SyncBankFrameEvent(enabled)
	if not BankFrame then return end
	if enabled then
		BankFrame:UnregisterEvent("BANKFRAME_OPENED")
	else
		BankFrame:RegisterEvent("BANKFRAME_OPENED")
	end
end

local function CloseBaudBags()
	if type(BaudBagCloseBagSet) ~= "function" then return end
	if not _G.BBCont1_1 then return end
	BaudBagCloseBagSet(1)
	BaudBagCloseBagSet(2)
	if BaudBagOptionsFrame and not BaudBagOptionsFrame.SarychUIEmbedded then
		BaudBagOptionsFrame:Hide()
	end
end

function wrapper:IsRuntimeEnabled()
	local bags = GetBagsModule()
	if bags and bags.IsBaudBagMode and bags:IsEnabled() then
		return bags:IsBaudBagMode()
	end
	return self.runtimeEnabled == true
end

function wrapper:SetRuntimeEnabled(enable)
	enable = enable and true or false
	local cfg = EnsureCfg()

	SetBagSetEnabled(cfg, 1, enable)
	SetBagSetEnabled(cfg, 2, enable)
	SyncBankFrameEvent(enable)

	if not enable then
		CloseBaudBags()
	end

	self.runtimeEnabled = enable
	return true
end

function wrapper:ShowOptions()
	local f = BaudBagOptionsFrame
	if not f then
		return false
	end

	-- Выше окна SarychUI (DIALOG).
	f.SarychUIEmbedded = nil
	f:SetParent(UIParent)
	f:ClearAllPoints()
	f:SetPoint("CENTER")
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	local sui = _G.SarychUIOptionsFrame
	local base = (sui and sui.GetFrameLevel and sui:GetFrameLevel()) or 100
	f:SetFrameLevel(base + 50)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:Show()
	f:Raise()
	return true
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
		name = "Baud Bag",
		args = {
			enabled = {
				type = "toggle",
				name = "Включить",
				desc = "Включить Baud Bag как режим сумок. Включение — сразу; при выключении нужен /reload для корректного возврата сумок.",
				order = 1,
				get = function()
					local db = SarychUI and SarychUI.db and SarychUI.db.profile
					return db and db.addons and db.addons.BaudBag and db.addons.BaudBag.enabled == true
				end,
				set = function(_, value)
					local db = SarychUI and SarychUI.db and SarychUI.db.profile
					local bags = db and db.modules and db.modules.bags
					local previous = (bags and bags.mode) or "default"
					if value == (previous == "baudbag") then
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
								"|cff1784d1Baud Bag|r отключён. Для корректного возврата стандартных сумок нужен /reload.",
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
			},
			open = {
				type = "execute",
				name = "Открыть настройки Baud Bag",
				desc = "Открыть окно настроек Baud Bag",
				order = 2,
				disabled = function()
					return not wrapper:IsRuntimeEnabled()
				end,
				func = function()
					wrapper:ShowOptions()
				end,
			},
			description = {
				type = "description",
				name = "Baud Bag — контейнеры сумок и банка.\nВключение — сразу; выключение режима сумок — после /reload.\n\nАвтор: "
					.. (wrapper.author or "")
					.. "\nВерсия: "
					.. (wrapper.version or ""),
				order = 3,
				width = "full",
			},
		},
	}
end

-- После BaudBagRestoreCfg снова выключаем runtime, если режим не baudbag.
if BaudBagRestoreCfg then
	local origRestore = BaudBagRestoreCfg
	BaudBagRestoreCfg = function(...)
		if restoring then
			return origRestore(...)
		end
		EnsureCache()
		restoring = true
		origRestore(...)
		restoring = false
		local bags = GetBagsModule()
		local want = bags and bags.IsEnabled and bags:IsEnabled() and bags.IsBaudBagMode and bags:IsBaudBagMode()
		if want then
			wrapper.runtimeEnabled = true
			SyncBankFrameEvent(true)
		else
			local cfg = EnsureCfg()
			SetBagSetEnabled(cfg, 1, false)
			SetBagSetEnabled(cfg, 2, false)
			wrapper.runtimeEnabled = false
			SyncBankFrameEvent(false)
		end
	end
end

do
	local cfg = EnsureCfg()
	SetBagSetEnabled(cfg, 1, false)
	SetBagSetEnabled(cfg, 2, false)
	wrapper.runtimeEnabled = false
end

_G.SarychUI_BaudBag = wrapper

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
		if addonName == "SarychUI" and RegisterWrapper() then
			self:UnregisterAllEvents()
		end
	end)
end
