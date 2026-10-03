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
	ruRU = true, enUS = true, esES = true,
}

local DISPLAY_ORDER = {
	"ruRU", "enUS", "esES",
}

local DISPLAY_NAMES = {
	ruRU = "Русский",
	enUS = "English",
	esES = "Español",
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

local function NormalizeLocaleCode(code)
	if code == "enGB" then
		return "enUS"
	end
	if code == "esMX" then
		return "esES"
	end
	return code
end

local function LocaleFromSavedTable(db)
	if type(db) ~= "table" then
		return nil
	end
	local candidates = {
		db.uiLocale,
		db.global and db.global.uiLocale,
		db.global and db.global.general and db.global.general.uiLocale,
	}
	for i = 1, #candidates do
		local saved = NormalizeLocaleCode(candidates[i])
		if type(saved) == "string" and SarychUI.IsValidUILocale(saved) then
			return saved
		end
	end
	return nil
end

-- Read SavedVariables before AceDB init (available when TOC files run).
function SarychUI.ResolveSavedUILocale()
	local saved = LocaleFromSavedTable(SarychUIDB)
	if saved then
		return saved
	end
	local client = GetLocale and GetLocale() or "enUS"
	if client == "enGB" then
		client = "enUS"
	elseif client == "esMX" then
		client = "esES"
	end
	if SarychUI.IsValidUILocale(client) then
		return client
	end
	return "enUS"
end

function SarychUI:GetUILocale()
	local saved = LocaleFromSavedTable(self.db) or LocaleFromSavedTable(SarychUIDB)
	if saved then
		return saved
	end
	return SarychUI.ResolveSavedUILocale()
end

function SarychUI:SetUILocale(code)
	code = NormalizeLocaleCode(code)
	if not SarychUI.IsValidUILocale(code) then
		return false
	end
	local function writeGlobal(db)
		if type(db) ~= "table" then
			return
		end
		db.global = db.global or {}
		db.global.uiLocale = code
		db.global.general = db.global.general or {}
		db.global.general.uiLocale = code
	end
	if self.db then
		writeGlobal(self.db)
	end
	SarychUIDB = SarychUIDB or {}
	SarychUIDB.uiLocale = code
	writeGlobal(SarychUIDB)
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
	self._localePack = L
	-- Keep SarychUI.L as the stable proxy (installed at Locale.lua load).

	-- Russian source -> UI language map (hardcoded option strings)
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
	end
	self._uiStringMap = map
	self._activeUILocale = locale
	self._tExactCache = nil
	return locale
end

local function LookupMapped(map, text)
	if not map or text == nil or text == "" then
		return nil
	end
	local hit = map[text]
	if hit then
		return hit
	end
	-- Texture markup prefix: |Tpath:size|t Label
	local tex, rest = string.match(text, "^(|T.-|[tT]%s*)(.*)$")
	if rest and rest ~= "" then
		local tr = LookupMapped(map, rest)
		if tr then
			return tex .. tr
		end
	end
	-- Color prefix: |cAARRGGBB...
	local color, rest2 = string.match(text, "^(|c%x%x%x%x%x%x%x%x)(.*)$")
	if rest2 and rest2 ~= "" then
		local tr = LookupMapped(map, rest2)
		if tr then
			return color .. tr
		end
	end
	-- Chat wheel labels: "Фраза 1 - текст"
	local num, tail = string.match(text, "^Фраза (%d+)( %- .+)$")
	if num then
		local phrase = map["Фраза " .. num] or ((map["Фраза "] or "Phrase ") .. num)
		local tailTr = map[tail]
		if phrase and tailTr then
			return phrase .. tailTr
		end
	end
	-- CVar / status lines: "Label: 0 -> 1" (single short line only).
	-- Addon notes contain "Автор:" / "Команды:" and must not be split here.
	if #text <= 96 and not string.find(text, "\n", 1, true) then
		local colon = string.find(text, ": ", 1, true)
		if colon and colon > 1 and colon <= 48 then
			local left = string.sub(text, 1, colon - 1)
			local tr = map[left]
			if tr then
				return tr .. string.sub(text, colon)
			end
		end
	end
	-- Prefix-aware: "Пометка:" / "Внимание:" labels (optionally followed by L[] text).
	local bestTr, bestLen
	for ru, tr in pairs(map) do
		local n = #ru
		if n >= 12 and n <= 64 and n < #text and string.sub(text, 1, n) == ru then
			if (string.find(ru, "Внимание", 1, true) or string.find(ru, "Пометка", 1, true))
				and (string.sub(ru, -2) == "|r" or string.sub(ru, -3) == "|r ") then
				if not bestLen or n > bestLen then
					bestTr, bestLen = tr, n
				end
			end
		end
	end
	if bestTr then
		return bestTr .. string.sub(text, bestLen + 1)
	end
	-- Addon notes: static body + "Автор: Name\nВерсия: 1.0".
	-- Map keys usually include the trailing "Автор: " prefix.
	local authorLabel = "Автор: "
	local authorAt = string.find(text, authorLabel, 1, true)
	if authorAt and authorAt > 1 then
		local prefixWithAuthor = string.sub(text, 1, authorAt + #authorLabel - 1)
		local head = string.sub(text, 1, authorAt - 1)
		local headCore = string.gsub(head, "\n+$", "")
		local headTr = map[prefixWithAuthor] or map[head] or map[headCore]
			or map[headCore .. "\n\nАвтор: "] or map[headCore .. "\nАвтор: "]
		local tail = string.sub(text, authorAt)
		if map[prefixWithAuthor] or map[headCore .. "\n\nАвтор: "] or map[headCore .. "\nАвтор: "] then
			tail = string.sub(text, authorAt + #authorLabel)
		end
		tail = string.gsub(tail, "Автор: ", map["Автор: "] or "Author: ", 1)
		tail = string.gsub(tail, "Версия: ", map["Версия: "] or "Version: ", 1)
		tail = string.gsub(tail, "Неизвестен", map["Неизвестен"] or "Unknown")
		tail = string.gsub(tail, "Неизвестна", map["Неизвестна"] or "Unknown")
		if type(headTr) == "string" then
			return headTr .. tail
		end
		local noteTr, noteLen
		for ru, tr in pairs(map) do
			local n = #ru
			if n >= 40 and n < #text and string.sub(text, 1, n) == ru then
				if not noteLen or n > noteLen then
					noteTr, noteLen = tr, n
				end
			end
		end
		if noteTr then
			local rest = string.sub(text, noteLen + 1)
			rest = string.gsub(rest, "Автор: ", map["Автор: "] or "Author: ", 1)
			rest = string.gsub(rest, "Версия: ", map["Версия: "] or "Version: ", 1)
			return noteTr .. rest
		end
	end
	local enablePrefix = "Включить/выключить "
	if #text > #enablePrefix and string.sub(text, 1, #enablePrefix) == enablePrefix then
		local rest = string.sub(text, #enablePrefix + 1)
		local prefixTr = map[enablePrefix]
		if prefixTr then
			return prefixTr .. (map[rest] or rest)
		end
	end
	local openPrefixes = {
		"Открыть окно настроек ",
		"Открыть настройки ",
	}
	for i = 1, #openPrefixes do
		local prefix = openPrefixes[i]
		if #text > #prefix and string.sub(text, 1, #prefix) == prefix then
			local prefixTr = map[prefix]
			if prefixTr then
				return prefixTr .. string.sub(text, #prefix + 1)
			end
		end
	end
	-- Long notes / concatenated addon descriptions: longest mapped prefix.
	if #text >= 60 then
		local noteTr, noteLen
		for ru, tr in pairs(map) do
			local n = #ru
			if n >= 40 and n < #text and string.sub(text, 1, n) == ru then
				if not noteLen or n > noteLen then
					noteTr, noteLen = tr, n
				end
			end
		end
		if noteTr then
			local rest = string.sub(text, noteLen + 1)
			rest = string.gsub(rest, "Автор: ", map["Автор: "] or "Author: ", 1)
			rest = string.gsub(rest, "Версия: ", map["Версия: "] or "Version: ", 1)
			return noteTr .. rest
		end
	end
	return nil
end

-- Translate a hardcoded UI string (usually Russian source) into the active UI language.
-- Extra args are string.format replacements applied after lookup (templates with %s / %d).
function SarychUI:T(text, ...)
	if type(text) ~= "string" or text == "" then
		return text
	end
	local map = self._uiStringMap
	local translated = LookupMapped(map, text)
	if not translated then
		local pack = self._localePack
		if type(pack) == "table" and pack[text] ~= nil then
			translated = pack[text]
		else
			translated = text
		end
	end
	if translated == text and map and next(map) then
		local frags = {
			"При выключении нужен /reload, чтобы убрать пункт из «Интерфейс -> Модификации».",
			"Включение - сразу; выключение из списка Модификаций - после /reload.",
			"Включение - сразу; выключение - после /reload.",
			"Отключите её в списке аддонов, чтобы использовать встроенную версию SarychUI.",
			"будет убран из «Интерфейс -> Модификации» после перезагрузки (/reload).",
			"будет убран из Интерфейс -> Модификации после перезагрузки (/reload).",
			"настройки недоступны. Проверьте Lua errors.",
			"обнаружена standalone-версия ",
			"обнаружена standalone-версия",
			"Включить/выключить ",
			"Открыть окно настроек ",
			"Открыть настройки ",
			"Автор: ",
			"Версия: ",
		}
		local out = text
		local changed
		for i = 1, #frags do
			local ru = frags[i]
			local tr = map[ru]
			if tr then
				local pos = string.find(out, ru, 1, true)
				if pos then
					out = string.sub(out, 1, pos - 1) .. tr .. string.sub(out, pos + #ru)
					changed = true
				end
			end
		end
		if changed then
			translated = out
		end
	end
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, translated, ...)
		if ok then
			return formatted
		end
	end
	return translated
end

-- Cooltip / desc payloads: string or { {text, r, g, b}, ... }.
function SarychUI:TLines(value)
	if type(value) == "string" then
		return self:T(value)
	end
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	local n = #value
	if n == 0 then
		for k, v in pairs(value) do
			if type(v) == "string" then
				out[k] = self:T(v)
			else
				out[k] = v
			end
		end
		return out
	end
	for i = 1, n do
		local line = value[i]
		if type(line) == "string" then
			out[i] = self:T(line)
		elseif type(line) == "table" then
			local copy = {}
			for k, v in pairs(line) do
				copy[k] = v
			end
			if type(copy[1]) == "string" then
				copy[1] = self:T(copy[1])
			end
			if type(copy.text) == "string" then
				copy.text = self:T(copy.text)
			end
			out[i] = copy
		else
			out[i] = line
		end
	end
	for k, v in pairs(value) do
		if type(k) ~= "number" then
			out[k] = v
		end
	end
	return out
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
		profileOpts.name = self:T("Профили")
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
	local dest = SarychUI.UIMaps[code]
	if type(dest) ~= "table" then
		SarychUI.UIMaps[code] = tbl
		return
	end
	for k, v in pairs(tbl) do
		dest[k] = v
	end
end
