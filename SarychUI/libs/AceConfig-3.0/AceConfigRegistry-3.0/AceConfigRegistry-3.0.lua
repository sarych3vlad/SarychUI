--- AceConfigRegistry-3.0 handles central registration of options tables in use by addons and modules.\\
-- Options tables can be registered as raw tables, OR as function refs that return a table.\\
-- Such functions receive three arguments: "uiType", "uiName", "appName". \\
-- * Valid **uiTypes**: "cmd", "dropdown", "dialog". This is verified by the library at call time. \\
-- * The **uiName** field is expected to contain the full name of the calling addon, including version, e.g. "FooBar-1.0". This is verified by the library at call time.\\
-- * The **appName** field is the options table name as given at registration time \\
--
-- :IterateOptionsTables() (and :GetOptionsTable() if only given one argument) return a function reference that the requesting config handling addon must call with valid "uiType", "uiName".
-- @class file
-- @name AceConfigRegistry-3.0
-- @release Synced Ace schema with Questie AceConfigRegistry-3.0 (r20) + SarychUI sui* extensions
--
-- MINOR kept high so this copy wins over Questie/Details/etc embedded AceConfigRegistry.
local CallbackHandler = LibStub("CallbackHandler-1.0")

local MAJOR, MINOR = "AceConfigRegistry-3.0", 103
local AceConfigRegistry = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigRegistry then return end

AceConfigRegistry.tables = AceConfigRegistry.tables or {}

if not AceConfigRegistry.callbacks then
	AceConfigRegistry.callbacks = CallbackHandler:New(AceConfigRegistry)
end

-- Lua APIs
local tinsert, tconcat = table.insert, table.concat
local strfind, strmatch = string.find, string.match
local type, tostring, select, pairs = type, tostring, select, pairs
local error, assert = error, assert

-----------------------------------------------------------------------
-- Validating options table consistency:

AceConfigRegistry.validated = {
	-- CLEARED ON PURPOSE, since newer versions may have newer validators
	cmd = {},
	dropdown = {},
	dialog = {},
}

local function err(msg, errlvl, ...)
	local t = {}
	for i = select("#", ...), 1, -1 do
		tinsert(t, (select(i, ...)))
	end
	error(MAJOR .. ":ValidateOptionsTable(): " .. tconcat(t, ".") .. msg, errlvl + 2)
end

local isstring = { ["string"] = true, _ = "string" }
local isstringfunc = { ["string"] = true, ["function"] = true, _ = "string or funcref" }
local istable = { ["table"] = true, _ = "table" }
local ismethodtable = { ["table"] = true, ["string"] = true, ["function"] = true, _ = "methodname, funcref or table" }
local optstring = { ["nil"] = true, ["string"] = true, _ = "string" }
local optstringfunc = { ["nil"] = true, ["string"] = true, ["function"] = true, _ = "string or funcref" }
local optstringnumberfunc = { ["nil"] = true, ["string"] = true, ["number"] = true, ["function"] = true, _ = "string, number or funcref" }
local optnumber = { ["nil"] = true, ["number"] = true, _ = "number" }
local optmethodfalse = { ["nil"] = true, ["string"] = true, ["function"] = true, ["boolean"] = { [false] = true }, _ = "methodname, funcref or false" }
local optmethodnumber = { ["nil"] = true, ["string"] = true, ["function"] = true, ["number"] = true, _ = "methodname, funcref or number" }
local optmethodtable = { ["nil"] = true, ["string"] = true, ["function"] = true, ["table"] = true, _ = "methodname, funcref or table" }
local optmethodbool = { ["nil"] = true, ["string"] = true, ["function"] = true, ["boolean"] = true, _ = "methodname, funcref or boolean" }
local opttable = { ["nil"] = true, ["table"] = true, _ = "table" }
local optbool = { ["nil"] = true, ["boolean"] = true, _ = "boolean" }
local optboolnumber = { ["nil"] = true, ["boolean"] = true, ["number"] = true, _ = "boolean or number" }
local optstringnumber = { ["nil"] = true, ["string"] = true, ["number"] = true, _ = "string or number" }
-- true | texture path | { path=string, color={r,g,b[,a]} }
local optsuiHelpIcon = { ["nil"] = true, ["boolean"] = true, ["string"] = true, ["table"] = true, _ = "boolean, string or table" }

-- Upstream Ace keys (Questie r20) + shared SarychUI renderer hints.
local basekeys = {
	type = isstring,
	name = isstringfunc,
	desc = optstringfunc,
	descStyle = optstring,
	order = optmethodnumber,
	validate = optmethodfalse,
	confirm = optmethodbool,
	confirmText = optstring,
	disabled = optmethodbool,
	hidden = optmethodbool,
		guiHidden = optmethodbool,
		dialogHidden = optmethodbool,
		dropdownHidden = optmethodbool,
	cmdHidden = optmethodbool,
	icon = optstringnumberfunc,
	iconCoords = optmethodtable,
	handler = opttable,
	get = optmethodfalse,
	set = optmethodfalse,
	func = optmethodfalse,
	arg = { ["*"] = true },
	width = optstringnumber,
	-- SarychUI custom renderer hints (allowed on any option type).
	suiFullRow = optbool,
	suiPreviewKey = optstring,
	suiHelpIcon = optsuiHelpIcon,
	suiTooltip = optmethodtable,
	suiAlign = optstring,
	suiLiveApply = optbool,
	suiSkipWritableProfile = optbool,
	suiListGroup = optstring,
	suiListGroupRank = optnumber,
	suiListGroupOrder = optnumber,
	-- Preview hooks used on description (and sometimes other) nodes.
	suiSpinner = optbool,
	suiDistancePreview = optbool,
	suiDistancePreviewNotice = optstringfunc,
	suiLayoutPreview = optstring,
	suiLayoutPreviewNotice = optstringfunc,
	suiLootRollPreview = optbool,
	suiCooldownTextPreview = optbool,
	suiGcdCooldownPreview = optbool,
	suiActionBarTextPreview = optbool,
	suiActionBarColorPreview = optbool,
	suiActionBarAppearancePreview = optbool,
	suiActionBarTransparencyPreview = optbool,
	suiActionBarBarsPreview = optbool,
	suiErrorFilterPreview = optbool,
	suiSysMsgPreview = optbool,
	suiBossEmotePreview = optbool,
	suiFrameHitPreview = optbool,
	suiArenaPreview = optbool,
	suiAurasPreview = optbool,
	suiMinimapPreview = optbool,
	suiCombatIndicatorPreview = optbool,
	suiCombatTextPreview = optbool,
	suiCastbarTimerPreview = optbool,
	suiCountdownTimerPreview = optbool,
	suiChatTooltipPreview = optbool,
	suiFramePvpPreview = optbool,
}

local typedkeys = {
	header = {
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
	},
	description = {
		image = optstringnumberfunc,
		imageCoords = optmethodtable,
		imageHeight = optnumber,
		imageWidth = optnumber,
		fontSize = optstringfunc,
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
		-- SarychUI layout hints specific to description widgets.
		imageAlign = optstring,
		imageCenterInContent = optbool,
	},
	group = {
		args = istable,
		plugins = opttable,
		inline = optbool,
			cmdInline = optbool,
			guiInline = optbool,
			dropdownInline = optbool,
			dialogInline = optbool,
		childGroups = optstring,
		-- SarychUI custom renderer.
		suiTwoPane = optbool,
		suiSelectWithButton = optbool,
		suiOneRowAdd = optbool,
		suiCompactListRow = optbool,
		suiTwoCol = optbool,
		suiThreeCol = optbool,
		suiTabBarExtra = optmethodtable,
		suiTabBarExtras = opttable,
		suiHeaderIcon = optstring,
		suiHelpIcon = optsuiHelpIcon,
		suiPanelDecorIcon = optstringfunc,
		suiListGroup = optstring,
		suiListGroupRank = optnumber,
		suiListGroupOrder = optnumber,
		icon = optstringfunc,
	},
	execute = {
		image = optstringnumberfunc,
		imageCoords = optmethodtable,
		imageHeight = optnumber,
		imageWidth = optnumber,
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
	},
	input = {
		pattern = optstring,
		usage = optstring,
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
		multiline = optboolnumber,
		-- SarychUI custom renderer hints.
		suiCompact = optbool,
		suiSaveButton = optstring,
		suiKeepInput = optbool,
		suiOnDraft = { ["nil"] = true, ["function"] = true, _ = "funcref" },
	},
	toggle = {
		tristate = optbool,
		image = optstringnumberfunc,
		imageCoords = optmethodtable,
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
	},
	tristate = {
	},
	range = {
		min = optnumber,
		softMin = optnumber,
		max = optnumber,
		softMax = optnumber,
		step = optnumber,
		bigStep = optnumber,
		isPercent = optbool,
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
	},
	select = {
		values = ismethodtable,
		sorting = optmethodtable,
		style = {
			["nil"] = true,
			["string"] = { dropdown = true, radio = true },
			_ = "string: 'dropdown' or 'radio'",
		},
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
		itemControl = optstring,
		-- SarychUI custom renderer hints.
		suiCompact = optbool,
		suiPlaceholder = optstring,
		suiLocaleFlags = optbool,
		suiFlagPathFn = optmethodtable,
	},
	multiselect = {
		values = ismethodtable,
		style = optstring,
		tristate = optbool,
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
	},
	color = {
		hasAlpha = optmethodbool,
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
	},
	keybinding = {
		control = optstring,
		dialogControl = optstring,
		dropdownControl = optstring,
	},
}

local function validateKey(k, errlvl, ...)
	errlvl = (errlvl or 0) + 1
	if type(k) ~= "string" then
		err("[" .. tostring(k) .. "] - key is not a string", errlvl, ...)
	end
	if strfind(k, "[%c\127]") then
		err("[" .. tostring(k) .. "] - key name contained control characters", errlvl, ...)
	end
end

local function validateVal(v, oktypes, errlvl, ...)
	errlvl = (errlvl or 0) + 1
	local isok = oktypes[type(v)] or oktypes["*"]

	if not isok then
		err(": expected a " .. oktypes._ .. ", got '" .. tostring(v) .. "'", errlvl, ...)
	end
	if type(isok) == "table" then
		if not isok[v] then
			err(": did not expect " .. type(v) .. " value '" .. tostring(v) .. "'", errlvl, ...)
		end
	end
end

local function validate(options, errlvl, ...)
	errlvl = (errlvl or 0) + 1
	if type(options) ~= "table" then
		err(": expected a table, got a " .. type(options), errlvl, ...)
	end
	if type(options.type) ~= "string" then
		err(".type: expected a string, got a " .. type(options.type), errlvl, ...)
	end

	local tk = typedkeys[options.type]
	if not tk then
		err(".type: unknown type '" .. options.type .. "'", errlvl, ...)
	end

	-- Keys starting with "_" are SarychUI private hooks (not AceGUI fields).
	for k, v in pairs(options) do
		if type(k) == "string" and k:sub(1, 1) == "_" then
			-- allow
		elseif not (tk[k] or basekeys[k]) then
			err(": unknown parameter", errlvl, tostring(k), ...)
		end
	end

	for k, oktypes in pairs(basekeys) do
		validateVal(options[k], oktypes, errlvl, k, ...)
	end
	for k, oktypes in pairs(tk) do
		validateVal(options[k], oktypes, errlvl, k, ...)
	end

	if options.type == "group" then
		for k, v in pairs(options.args) do
			validateKey(k, errlvl, "args", ...)
			validate(v, errlvl, k, "args", ...)
		end
		if options.plugins then
			for plugname, plugin in pairs(options.plugins) do
				if type(plugin) ~= "table" then
					err(": expected a table, got '" .. tostring(plugin) .. "'", errlvl, tostring(plugname), "plugins", ...)
				end
				for k, v in pairs(plugin) do
					validateKey(k, errlvl, tostring(plugname), "plugins", ...)
					validate(v, errlvl, k, tostring(plugname), "plugins", ...)
				end
			end
		end
	end
end

function AceConfigRegistry:ValidateOptionsTable(options, name, errlvl)
	errlvl = (errlvl or 0) + 1
	name = name or "Optionstable"
	if not options.name then
		options.name = name
	end
	validate(options, errlvl, name)
end

function AceConfigRegistry:NotifyChange(appName)
	if not AceConfigRegistry.tables[appName] then return end
	AceConfigRegistry.callbacks:Fire("ConfigTableChange", appName)
end

local function validateGetterArgs(uiType, uiName, errlvl)
	errlvl = (errlvl or 0) + 2
	if uiType ~= "cmd" and uiType ~= "dropdown" and uiType ~= "dialog" then
		error(MAJOR .. ": Requesting options table: 'uiType' - invalid configuration UI type, expected 'cmd', 'dropdown' or 'dialog'", errlvl)
	end
	if not strmatch(uiName, "[A-Za-z]%-[0-9]") then
		error(MAJOR .. ": Requesting options table: 'uiName' - badly formatted or missing version number. Expected e.g. 'MyLib-1.2'", errlvl)
	end
end

-- skipValidation: Ace upstream (Questie r20+). Soft-fail validation so a foreign
-- addon's unknown key cannot hard-error the whole client; logs instead.
function AceConfigRegistry:RegisterOptionsTable(appName, options, skipValidation)
	if type(options) == "table" then
		if options.type ~= "group" then
			error(MAJOR .. ": RegisterOptionsTable(appName, options): 'options' - missing type='group' member in root group", 2)
		end
		AceConfigRegistry.tables[appName] = function(uiType, uiName, errlvl)
			errlvl = (errlvl or 0) + 1
			validateGetterArgs(uiType, uiName, errlvl)
			if not AceConfigRegistry.validated[uiType][appName] and not skipValidation then
				AceConfigRegistry.validated[uiType][appName] = true
				local ok, errMsg = pcall(AceConfigRegistry.ValidateOptionsTable, AceConfigRegistry, options, appName, errlvl)
				if not ok and DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage("|cffff8080AceConfigRegistry:|r " .. tostring(errMsg))
				end
			elseif skipValidation then
				AceConfigRegistry.validated[uiType][appName] = true
			end
			return options
		end
	elseif type(options) == "function" then
		AceConfigRegistry.tables[appName] = function(uiType, uiName, errlvl)
			errlvl = (errlvl or 0) + 1
			validateGetterArgs(uiType, uiName, errlvl)
			local tab = assert(options(uiType, uiName, appName))
			if not AceConfigRegistry.validated[uiType][appName] and not skipValidation then
				AceConfigRegistry.validated[uiType][appName] = true
				local ok, errMsg = pcall(AceConfigRegistry.ValidateOptionsTable, AceConfigRegistry, tab, appName, errlvl)
				if not ok and DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage("|cffff8080AceConfigRegistry:|r " .. tostring(errMsg))
				end
			elseif skipValidation then
				AceConfigRegistry.validated[uiType][appName] = true
			end
			return tab
		end
	else
		error(MAJOR .. ": RegisterOptionsTable(appName, options): 'options' - expected table or function reference", 2)
	end
end

function AceConfigRegistry:IterateOptionsTables()
	return pairs(AceConfigRegistry.tables)
end

function AceConfigRegistry:GetOptionsTable(appName, uiType, uiName)
	local f = AceConfigRegistry.tables[appName]
	if not f then
		return nil
	end
	if uiType then
		return f(uiType, uiName, 1)
	else
		return f
	end
end
