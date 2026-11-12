-- SarychUI module options wrapper
-- Module enable toggle sits on the right of the tab bar (like Тестовый режим).
-- When disabled, setting tabs are hidden and a short notice is shown.

local pairs = pairs
local type = type
local pcall = pcall
local tinsert = table.insert

local NOTICE_ORDER = -999

-- Explicit ownership metadata; never infer module controls from translated labels.
local wrappedOptions = setmetatable({}, { __mode = "k" })

local function FindModuleEnableToggle(args, ancestors)
    if type(args) ~= "table" then return end
    ancestors = ancestors or {}
    for key, option in pairs(args) do
        if type(option) == "table" then
            if option.type == "toggle" and option.suiModuleEnable then
                return option, args, key, ancestors
            elseif option.type == "group" then
                local path = {}
                for i, entry in ipairs(ancestors) do path[i] = entry end
                path[#path + 1] = { args = args, key = key, group = option }
                local found, owner, childKey, chain = FindModuleEnableToggle(option.args, path)
                if found then return found, owner, childKey, chain end
            end
        end
    end
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
		if type(tab) == "table" and tab.type then
			tab.hidden = CombineHiddenWhenModuleDisabled(isModuleEnabled, tab.hidden)
		end
	end
end

local function CollectExistingTabBarExtras(opts)
	local list = {}
	if type(opts.suiTabBarExtras) == "table" then
		for _, item in ipairs(opts.suiTabBarExtras) do
			if type(item) == "table" and (item.type == "toggle" or item.type == "execute") then
				tinsert(list, item)
			end
		end
	end
	if type(opts.suiTabBarExtra) == "table" and (opts.suiTabBarExtra.type == "toggle" or opts.suiTabBarExtra.type == "execute") then
		tinsert(list, opts.suiTabBarExtra)
	end
	return list
end

function SarychUI:WrapModuleOptionsWithEnableHeader(moduleKey, opts)
	if type(opts) ~= "table" or opts.type ~= "group" or not opts.args then
		return opts
	end

    if wrappedOptions[opts] then return opts end
    local enableOpt, ownerArgs, enableKey, ancestors = FindModuleEnableToggle(opts.args)
    if not enableOpt then return opts end
    wrappedOptions[opts] = true
    ownerArgs[enableKey] = nil
    for i = #ancestors, 1, -1 do
        local entry = ancestors[i]
        if IsOptionsGroupEmpty(entry.group.args) then entry.args[entry.key] = nil end
    end

    -- Header controls still call the original owner callbacks with their original path.
    local originalInfo = { "modules", moduleKey }
    for _, entry in ipairs(ancestors) do originalInfo[#originalInfo + 1] = entry.key end
    originalInfo[#originalInfo + 1] = enableKey
    local originalGet = enableOpt.get
    enableOpt.get = function() return originalGet(originalInfo) end

	local isModuleEnabled = BuildIsModuleEnabled(moduleKey, enableOpt)
	local originalSet = enableOpt.set
	if originalSet then
		enableOpt.set = function(info, val)
			originalSet(originalInfo, val)
            if self.OptionsCore and self.OptionsCore.ScheduleSmartRefresh then
                self.OptionsCore:ScheduleSmartRefresh(true)
            end
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

	enableOpt.name = "ui.enable_a54eaf37"
	enableOpt.width = nil

	local settingTabs = {}
	for key, value in pairs(opts.args) do
		settingTabs[key] = value
	end
	HideSettingTabsWhenDisabled(settingTabs, isModuleEnabled)

	local L = self.L
	local disabledNotice = L and L["Module_Disabled_Notice"]
		or "ui.options_135ba7633b"

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
	local opts = self:WrapModuleOptionsWithEnableHeader(moduleKey, module:GetOptions())
	if self.GetModuleOptionsOrder then
		opts.order = self:GetModuleOptionsOrder(moduleKey)
	end
	return opts
end
