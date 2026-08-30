-- SarychUI module options wrapper
-- Module enable toggle sits on the right of the tab bar (like Тестовый режим).
-- When disabled, setting tabs are hidden and a short notice is shown.

local pairs = pairs
local type = type
local pcall = pcall
local tinsert = table.insert

local NOTICE_ORDER = -999

local GENERAL_TAB_KEYS = {
	general = true,
	main = true,
}

local ENABLE_TOGGLE_NAMES = {
	["Включить модуль"] = true,
	["Enable Module"] = true,
}

local function IsGeneralTabName(name)
	if type(name) ~= "string" then
		return false
	end
	if name == "Общее" or name == "Общая" or name == "General" then
		return true
	end
	local L = SarychUI and SarychUI.L
	if L and L["General"] and name == L["General"] then
		return true
	end
	return false
end

local function IsModuleEnableToggleName(name)
	if type(name) == "string" then
		if ENABLE_TOGGLE_NAMES[name] then
			return true
		end
		local L = SarychUI and SarychUI.L
		if L and L["Enable_Module"] and name == L["Enable_Module"] then
			return true
		end
	elseif type(name) == "function" then
		local ok, resolved = pcall(name)
		if ok and type(resolved) == "string" then
			return IsModuleEnableToggleName(resolved)
		end
	end
	return false
end

local function IsModuleEnableToggle(opt)
	if not opt or opt.type ~= "toggle" then
		return false
	end
	return IsModuleEnableToggleName(opt.name)
end

local function FindModuleEnableToggle(args)
	if type(args) ~= "table" then
		return nil
	end

	for tabKey, tab in pairs(args) do
		if type(tab) == "table" and tab.type == "group" and tab.args then
			local isGeneral = GENERAL_TAB_KEYS[tabKey] or IsGeneralTabName(tab.name)
			local enabledOpt = tab.args.enabled
			if isGeneral and IsModuleEnableToggle(enabledOpt) then
				return enabledOpt, tabKey, tab
			end
		end
	end

	return nil
end

local function IsOptionsGroupEmpty(groupArgs)
	if type(groupArgs) ~= "table" then
		return true
	end

	for _, opt in pairs(groupArgs) do
		if type(opt) == "table" and opt.type then
			if opt.type == "header" then
			elseif opt.type == "description" then
				local name = opt.name
				if type(name) == "function" then
					return false
				end
				if type(name) == "string" and name ~= "" then
					return false
				end
			else
				return false
			end
		end
	end

	return true
end

local function BuildIsModuleEnabled(moduleKey, enableOpt)
	return function()
		if enableOpt and enableOpt.get then
			local ok, val = pcall(enableOpt.get, { moduleKey, "enabled" })
			if ok then
				return val and true or false
			end
		end
		if SarychUI and SarychUI.IsModuleEnabled then
			return SarychUI:IsModuleEnabled(moduleKey)
		end
		local modDb = SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.modules
		modDb = modDb and modDb[moduleKey]
		return modDb and modDb.enabled and true or false
	end
end

local function CombineHiddenWhenModuleDisabled(isModuleEnabled, existingHidden)
	return function(...)
		if not isModuleEnabled() then
			return true
		end
		if existingHidden == nil then
			return false
		end
		if type(existingHidden) == "function" then
			return existingHidden(...)
		end
		return existingHidden and true or false
	end
end

local function HideSettingTabsWhenDisabled(tabArgs, isModuleEnabled)
	for _, tab in pairs(tabArgs) do
		-- Hide both content tabs and root inline setting blocks when the module is off.
		if type(tab) == "table" and tab.type == "group" then
			tab.hidden = CombineHiddenWhenModuleDisabled(isModuleEnabled, tab.hidden)
		end
	end
end

local function CollectExistingTabBarExtras(opts)
	local list = {}
	if type(opts.suiTabBarExtras) == "table" then
		for _, item in ipairs(opts.suiTabBarExtras) do
			if type(item) == "table" and item.type == "toggle" then
				tinsert(list, item)
			end
		end
	end
	if type(opts.suiTabBarExtra) == "table" and opts.suiTabBarExtra.type == "toggle" then
		tinsert(list, opts.suiTabBarExtra)
	end
	return list
end

function SarychUI:WrapModuleOptionsWithEnableHeader(moduleKey, opts)
	if type(opts) ~= "table" or opts.type ~= "group" or not opts.args then
		return opts
	end

	local enableOpt, tabKey, tabGroup = FindModuleEnableToggle(opts.args)
	if not enableOpt then
		return opts
	end

	tabGroup.args.enabled = nil
	if IsOptionsGroupEmpty(tabGroup.args) then
		opts.args[tabKey] = nil
	end

	local isModuleEnabled = BuildIsModuleEnabled(moduleKey, enableOpt)
	local originalSet = enableOpt.set
	if originalSet then
		enableOpt.set = function(info, val)
			originalSet(info, val)
			if self.NotifySarychUIOptionsChange then
				self:NotifySarychUIOptionsChange()
			else
				local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
				if reg then
					reg:NotifyChange("SarychUI")
				end
			end
		end
	end

	-- Compact label for the tab-bar pin (same style as Тестовый режим).
	if enableOpt.name == "Включить модуль" or enableOpt.name == "Enable Module" then
		enableOpt.name = "Включить"
	elseif type(enableOpt.name) == "function" then
		-- keep dynamic name
	end
	enableOpt.width = nil

	local settingTabs = {}
	for key, value in pairs(opts.args) do
		settingTabs[key] = value
	end
	HideSettingTabsWhenDisabled(settingTabs, isModuleEnabled)

	local L = self.L
	local disabledNotice = L and L["Module_Disabled_Notice"]
		or "Модуль выключен. Включите модуль, чтобы открыть его настройки."

	-- Root keeps childGroups = "tab". Enable + disabled notice live on the tab bar.
	opts.childGroups = opts.childGroups or "tab"
	opts.args = {
		-- Kept for OptionsCore to read the message when tabs are hidden;
		-- not rendered in the content body.
		disabledNotice = {
			type = "description",
			name = disabledNotice,
			order = NOTICE_ORDER,
			fontSize = "medium",
			width = "full",
			hidden = true,
		},
	}

	for key, value in pairs(settingTabs) do
		opts.args[key] = value
	end

	-- Pin enable on the right; keep any existing extras (e.g. Тестовый режим) after it.
	local extras = { enableOpt }
	for _, extra in ipairs(CollectExistingTabBarExtras(opts)) do
		if extra ~= enableOpt then
			tinsert(extras, extra)
		end
	end
	opts.suiTabBarExtra = nil
	opts.suiTabBarExtras = extras

	return opts
end

function SarychUI:GetWrappedModuleOptions(moduleKey)
	local module = self.modules and self.modules[moduleKey]
	if not module or not module.GetOptions then
		return nil
	end
	return self:WrapModuleOptionsWithEnableHeader(moduleKey, module:GetOptions())
end
