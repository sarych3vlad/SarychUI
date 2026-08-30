-- SarychUI UI locale system
-- UI language is independent of client GetLocale() (game APIs still use client locale).

SarychUI = SarychUI or {}
SarychUI.Locales = SarychUI.Locales or {}
SarychUI.UIMaps = SarychUI.UIMaps or {} -- [locale] = { [ruSource] = translated }
SarychUI._localePack = SarychUI._localePack or {}

-- Stable proxy so `local L = SarychUI.L` in modules always reads the active pack.
-- ApplyUILocale only swaps _localePack; it must NOT replace SarychUI.L.
-- Missing keys MUST return nil so `L["Key"] or "Русский fallback"` keeps working.
if not SarychUI._lProxyInstalled then
	SarychUI._lProxyInstalled = true
	SarychUI.L = setmetatable({}, {
		__index = function(_, key)
			local pack = SarychUI._localePack
			if type(pack) == "table" and pack[key] ~= nil then
				return pack[key]
			end
			return nil
		end,
		__newindex = function(_, key, value)
			SarychUI._localePack = SarychUI._localePack or {}
			SarychUI._localePack[key] = value
		end,
	})
end

local VALID = {
	ruRU = true, enUS = true, ptBR = true, esES = true, esMX = true,
	deDE = true, frFR = true, itIT = true, koKR = true, zhCN = true, zhTW = true,
}

local DISPLAY_ORDER = {
	"ruRU", "enUS", "ptBR", "esES", "esMX",
	"deDE", "frFR", "itIT", "koKR", "zhCN", "zhTW",
}

local DISPLAY_NAMES = {
	-- Only Russian keeps a native label; other names are English so accents/CJK
	-- don't break on Western/RU client fonts (e.g. "Português" → "Portuguкs").
	ruRU = "Русский",
	enUS = "English",
	ptBR = "Portuguese (Brazil)",
	esES = "Spanish",
	esMX = "Spanish (Latin America)",
	deDE = "German",
	frFR = "French",
	itIT = "Italian",
	koKR = "Korean",
	zhCN = "Chinese (Simplified)",
	zhTW = "Chinese (Traditional)",
}

-- Flag textures for language select (Texture widgets, not |T markup).
local FLAG_PATH = [[Interface\AddOns\SarychUI\media\flags\]]

function SarychUI.GetLocaleDisplayOrder()
	return DISPLAY_ORDER
end

function SarychUI.GetLocaleDisplayNames()
	return DISPLAY_NAMES
end

function SarychUI.GetLocaleFlagPath(code)
	if not SarychUI.IsValidUILocale(code) then
		return nil
	end
	return FLAG_PATH .. code .. ".tga"
end

function SarychUI.GetLocaleDisplayLabel(code)
	return DISPLAY_NAMES[code] or code
end

function SarychUI.IsValidUILocale(code)
	return type(code) == "string" and VALID[code] == true
end

-- Read SavedVariables before AceDB init (available when TOC files run).
function SarychUI.ResolveSavedUILocale()
	if type(SarychUIDB) == "table" then
		local g = SarychUIDB.global and SarychUIDB.global.general
		if g and type(g.uiLocale) == "string" and SarychUI.IsValidUILocale(g.uiLocale) then
			return g.uiLocale
		end
	end
	local client = GetLocale and GetLocale() or "enUS"
	if client == "enGB" then
		client = "enUS"
	end
	if SarychUI.IsValidUILocale(client) then
		return client
	end
	return "enUS"
end

function SarychUI:GetUILocale()
	if self.db and self.db.global and self.db.global.general then
		local saved = self.db.global.general.uiLocale
		if type(saved) == "string" and SarychUI.IsValidUILocale(saved) then
			return saved
		end
	end
	return SarychUI.ResolveSavedUILocale()
end

function SarychUI:SetUILocale(code)
	if not SarychUI.IsValidUILocale(code) then
		return false
	end
	if not self.db then
		SarychUIDB = SarychUIDB or {}
		SarychUIDB.global = SarychUIDB.global or {}
		SarychUIDB.global.general = SarychUIDB.global.general or {}
		SarychUIDB.global.general.uiLocale = code
		return true
	end
	self.db.global = self.db.global or {}
	self.db.global.general = self.db.global.general or {}
	self.db.global.general.uiLocale = code
	if type(SarychUIDB) == "table" then
		SarychUIDB.global = SarychUIDB.global or {}
		SarychUIDB.global.general = SarychUIDB.global.general or {}
		SarychUIDB.global.general.uiLocale = code
	end
	return true
end

local function DeepCopy(src)
	if type(src) ~= "table" then
		return src
	end
	local dst = {}
	for k, v in pairs(src) do
		dst[k] = DeepCopy(v)
	end
	return dst
end

function SarychUI:ApplyUILocale(locale)
	locale = locale or self:GetUILocale()
	if not SarychUI.IsValidUILocale(locale) then
		locale = "enUS"
	end

	local base = self.Locales and self.Locales.enUS or {}
	local pack = (self.Locales and self.Locales[locale]) or base
	local L = DeepCopy(base)
	if pack ~= base then
		for k, v in pairs(pack) do
			L[k] = v
		end
	end
	-- esMX falls back to esES for missing L keys
	if locale == "esMX" and self.Locales and self.Locales.esES then
		for k, v in pairs(self.Locales.esES) do
			if L[k] == nil or L[k] == (base[k]) then
				L[k] = v
			end
		end
		for k, v in pairs(pack) do
			L[k] = v
		end
	end
	self._localePack = L
	-- Keep SarychUI.L as the stable proxy (installed at Locale.lua load).

	-- Russian source → UI language map (hardcoded option strings)
	local map = {}
	if locale ~= "ruRU" then
		local enMap = self.UIMaps and self.UIMaps.enUS
		local locMap = self.UIMaps and self.UIMaps[locale]
		if type(enMap) == "table" then
			for ru, en in pairs(enMap) do
				map[ru] = en
			end
		end
		if type(locMap) == "table" and locale ~= "enUS" then
			for ru, tr in pairs(locMap) do
				map[ru] = tr
			end
		end
		if locale == "esMX" and self.UIMaps and type(self.UIMaps.esES) == "table" then
			for ru, tr in pairs(self.UIMaps.esES) do
				if map[ru] == nil then
					map[ru] = tr
				end
			end
			if type(locMap) == "table" then
				for ru, tr in pairs(locMap) do
					map[ru] = tr
				end
			end
		end
	end
	self._uiStringMap = map
	self._activeUILocale = locale
	return locale
end

-- Translate a hardcoded UI string (usually Russian source) into the active UI language.
function SarychUI:T(text)
	if type(text) ~= "string" or text == "" then
		return text
	end
	local map = self._uiStringMap
	if map and map[text] then
		return map[text]
	end
	-- Prefix-aware: "Пометка:" / "Внимание:" labels (optionally followed by L[] text).
	if map then
		local bestTr, bestLen
		for ru, tr in pairs(map) do
			local n = #ru
			if n >= 12 and n <= 48 and n < #text and text:sub(1, n) == ru then
				if (ru:find("Внимание", 1, true) or ru:find("Пометка", 1, true))
					and (ru:sub(-2) == "|r" or ru:sub(-3) == "|r ") then
					if not bestLen or n > bestLen then
						bestTr, bestLen = tr, n
					end
				end
			end
		end
		if bestTr then
			return bestTr .. text:sub(bestLen + 1)
		end
	end
	-- Also allow looking up by English L-key values when pack already switched.
	local pack = self._localePack
	if type(pack) == "table" and pack[text] ~= nil then
		return pack[text]
	end
	return text
end

-- Rebuild Ace options trees that baked L["..."] strings at last GetOptions() call.
function SarychUI:RebuildLocalizedOptions()
	-- Tree not built yet: it will pick up the current locale when first requested.
	if not self._optionsTableBuilt then
		return
	end
	if type(self.AddModuleOptions) == "function" then
		self:AddModuleOptions()
	end
	if type(self.AddAddOnOptions) == "function" then
		self._addonOptionsDirty = true
		self._addonOptionsBuilt = false
		self:AddAddOnOptions()
	end
	local AceDBOptions = LibStub and LibStub("AceDBOptions-3.0", true)
	local root = self._customOptionsRoot
	if AceDBOptions and self.db and root and root.args and root.args.general and root.args.general.args then
		local profileOpts = AceDBOptions:GetOptionsTable(self.db)
		if self.CustomizeProfileOptions then
			self:CustomizeProfileOptions(profileOpts)
		end
		profileOpts.name = "Профили"
		profileOpts.order = 3
		root.args.general.args.profiles = profileOpts
	end
end

-- Register helpers for locale files
function SarychUI.RegisterLocale(code, tbl)
	if not SarychUI.IsValidUILocale(code) or type(tbl) ~= "table" then
		return
	end
	SarychUI.Locales[code] = tbl
end

function SarychUI.RegisterUIMap(code, tbl)
	if not SarychUI.IsValidUILocale(code) or type(tbl) ~= "table" then
		return
	end
	SarychUI.UIMaps[code] = tbl
end
