-- Transfer: export/import game settings as a text string
-- Logic ported from FrostAtomUI Transfer, adapted for game macros only (no unlimited macros).

local strlower, strmatch, strtrim, strgsub = string.lower, string.match, strtrim, string.gsub
local sort = table.sort
local abs = math.abs
local InCombatLockdown = InCombatLockdown
local GetActionInfo, PickupAction, PlaceAction, ClearCursor, GetCursorInfo =
	GetActionInfo, PickupAction, PlaceAction, ClearCursor, GetCursorInfo
local GetBindingAction, SetBinding = GetBindingAction, SetBinding
local GetMacroInfo, GetNumMacros, CreateMacro, EditMacro, DeleteMacro, PickupMacro =
	GetMacroInfo, GetNumMacros, CreateMacro, EditMacro, DeleteMacro, PickupMacro
local GetNumMacroIcons, GetMacroIconInfo = GetNumMacroIcons, GetMacroIconInfo

local Transfer = {}
SarychUI.Transfer = Transfer

local EXPORT_PREFIX = "SUIT1:"
local ACTION_SLOTS = 120
local MAX_ACCOUNT = MAX_ACCOUNT_MACROS or 36
local MAX_CHARACTER = MAX_CHARACTER_MACROS or 18
local STUB_NAME_LIMIT = 16
local QUESTION_MARK = "INTERFACE\\ICONS\\INV_MISC_QUESTIONMARK"
local MODIFIERS = { "", "ALT-", "CTRL-", "SHIFT-", "ALT-CTRL-", "ALT-SHIFT-", "CTRL-SHIFT-", "ALT-CTRL-SHIFT-" }
local MACRO_SCOPES = { "gameAccount", "gameChar" }
local SCOPES = { gameAccount = true, gameChar = true }

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local handler = eventHandlers[event]
	if handler then
		handler(event, ...)
	end
end)

local function RegisterTransferEvent(event, handler)
	eventHandlers[event] = handler
	eventFrame:RegisterEvent(event)
end

local function UnregisterTransferEvent(event)
	eventHandlers[event] = nil
	eventFrame:UnregisterEvent(event)
end

local function T(text)
	if SarychUI.T then
		return SarychUI:T(text)
	end
	return text
end

local function Print(fmt, ...)
	if select("#", ...) > 0 then
		SarychUI:Printf(fmt, ...)
	else
		SarychUI:Print(fmt)
	end
end

Transfer.CATEGORIES = {
	{
		key = "macros",
		label = "Макросы",
		desc = "Макросы аккаунта и этого персонажа. Полностью совпадающие макросы остаются на месте и используются как есть. Новые дописываются в свободные слоты. Если места не хватает, удаляются только макросы, которых нет в импорте, а недостающие создаются заново.",
	},
	{
		key = "actions",
		label = "Панели команд",
		desc = "Видимость дополнительных панелей, заклинания, предметы, макросы, транспорт и комплекты экипировки во всех ячейках панелей команд. Чего у персонажа нет, остаётся пустым.",
	},
	{
		key = "bindings",
		label = "Назначение клавиш",
		desc = "Все назначения клавиш, включая клавиши кнопок панелей, заклинаний и макросов. Импортируются в набор «Для этого персонажа» и заменяют его текущие назначения.",
	},
	{
		key = "interface",
		label = "Настройки интерфейса",
		cvars = true,
		desc = "Настройки игры: текст боя, имена, индикаторы здоровья, текст состояния, автодобыча и остальные параметры раздела «Интерфейс».",
	},
	{
		key = "camera",
		label = "Камера и мышь",
		cvars = true,
		desc = "Дальность, скорость и сглаживание камеры, скорость и инверсия мыши.",
	},
	{
		key = "graphics",
		label = "Графика",
		cvars = true,
		desc = "Настройки видео, кроме разрешения, оконного режима и графического API. Некоторые вступают в силу только после перезапуска клиента.",
	},
	{
		key = "sound",
		label = "Звук",
		cvars = true,
		desc = "Громкость и настройки звука, кроме устройства вывода.",
	},
	{
		key = "chat",
		label = "Окна чата",
		desc = "Вкладки чата с типами сообщений, размером шрифта и фоном, а также цвета чата. Подписки на каналы настраиваются в меню Blizzard.",
	},
	{
		key = "friends",
		label = "Друзья",
		desc = "Друзья с заметками. Только добавляет друзей, никого не удаляет.",
	},
	{
		key = "ignore",
		label = "Список игнорирования",
		desc = "Игнорируемые игроки. Только добавляет, никого не удаляет.",
	},
}

-- Categories off unless the user turns them on.
local DEFAULT_OFF = {
	friends = true,
	ignore = true,
}

local function exportSelection()
	local db = SarychUI.db
	if not db then
		return {}
	end
	db.global = db.global or {}
	db.global.transfer = db.global.transfer or {}
	return db.global.transfer
end

function Transfer.IsExported(key)
	local saved = exportSelection()[key]
	if saved == nil then
		return not DEFAULT_OFF[key]
	end
	return saved and true or false
end

function Transfer.SetExported(key, value)
	exportSelection()[key] = value and true or false
end

-- Normalize bodies for equality checks only (GetMacroInfo may use "||" for "|").
local function normalizeBody(body)
	return (strgsub(body or "", "||", "|"))
end

local iconIndex
local function iconKey(texture)
    if type(texture) ~= "string" then return nil end
    local key = strlower(texture):gsub("/", "\\"):gsub("^interface\\icons\\", "")
    return (key:gsub("%.blp$", ""):gsub("%.tga$", ""))
end

local function iconIndexOf(texture)
	if not texture then
		return 1
	end
	if not iconIndex then
		iconIndex = {}
		for i = 1, GetNumMacroIcons() do
			local path = GetMacroIconInfo(i)
			if path then
				iconIndex[iconKey(path)] = iconIndex[iconKey(path)] or i
			end
		end
	end
	return iconIndex[iconKey(texture)] or 1
end

-- Preserve the slot (and all action-bar references), but update its appearance.
local function updateMacroIcon(slot, item)
    local _, texture = GetMacroInfo(slot)
    if iconKey(texture) == iconKey(item.icon or QUESTION_MARK) then return true end
    return pcall(EditMacro, slot, nil, iconIndexOf(item.icon))
end

-- Same as FrostAtomUI ns.TruncateUTF8: limit is characters, not bytes.
-- Byte-cutting Russian names mid-codepoint makes CreateMacro fail or collide.
local function truncateName(name, limit)
	name = type(name) == "string" and strtrim(name) or ""
	local chars, i, length = 0, 1, #name
	while i <= length do
		chars = chars + 1
		if chars > limit then
			return name:sub(1, i - 1)
		end
		local byte = name:byte(i)
		if byte >= 0xF0 then
			i = i + 4
		elseif byte >= 0xE0 then
			i = i + 3
		elseif byte >= 0xC0 then
			i = i + 2
		else
			i = i + 1
		end
	end
	return name
end

local function gameIndices(scope, out)
	local numAccount, numCharacter = GetNumMacros()
	local first, last = 1, numAccount
	if scope == "gameChar" then
		first, last = MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter
	end
	for index = first, last do
		out[#out + 1] = index
	end
	return out
end

local function exportMacroItem(scope, index)
	local name, texture, body = GetMacroInfo(index)
	if not name then
		return nil
	end
	return {
		scope = scope,
		name = name,
		icon = texture and strlower(texture) ~= strlower(QUESTION_MARK) and texture or nil,
		body = body or "",
	}
end

local function macroRef(defs, scope, index)
	local ref = "g" .. index
	if not defs[ref] then
		local item = exportMacroItem(scope, index)
		if not item then
			return nil
		end
		defs[ref] = item
	end
	return ref
end

local function gameSlotFree(scope)
	local numAccount, numCharacter = GetNumMacros()
	if scope == "gameChar" then
		return numCharacter < MAX_CHARACTER
	end
	return numAccount < MAX_ACCOUNT
end

local function sanitizeMacro(item)
	if type(item) ~= "table" or type(item.body) ~= "string" then
		return nil
	end
	local name = type(item.name) == "string" and strtrim(item.name) or ""
	local scope = item.scope
	if scope == "account" then
		scope = "gameAccount"
	elseif scope == "char" then
		scope = "gameChar"
	elseif not SCOPES[scope] then
		scope = "gameAccount"
	end
	return {
		scope = scope,
		name = truncateName(name, 64),
		icon = type(item.icon) == "string" and item.icon ~= "" and item.icon or nil,
		body = strgsub(item.body, "\r\n?", "\n"),
	}
end

-- Exact byte/char equality after trim+lower. No prefix matching.
local function namesEqual(a, b)
	a, b = strlower(strtrim(a or "")), strlower(strtrim(b or ""))
	return a ~= "" and a == b
end

-- Walk account + character slots; only exact name hits count.
local function findMacroIndexByExactName(name, scope)
	local want = strlower(strtrim(name or ""))
	if want == "" then
		return
	end
	local numAccount, numCharacter = GetNumMacros()
	local function scan(first, last)
		for i = first, last do
			local existing = GetMacroInfo(i)
			if existing and strlower(existing) == want then
				return i
			end
		end
	end
	if scope == "gameAccount" then
		return scan(1, numAccount)
	elseif scope == "gameChar" then
		return scan(MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter)
	end
	return scan(1, numAccount) or scan(MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter)
end

local function findMacroIndexByNameAndBody(name, body, scope)
	local wantName = strlower(strtrim(name or ""))
	local wantBody = body or ""
	if wantName == "" then
		return
	end
	local numAccount, numCharacter = GetNumMacros()
	local function scan(first, last)
		for i = first, last do
			local existing, _, existingBody = GetMacroInfo(i)
			if existing and strlower(existing) == wantName and normalizeBody(existingBody) == normalizeBody(wantBody) then
				return i
			end
		end
	end
	if scope == "gameAccount" then
		return scan(1, numAccount)
	elseif scope == "gameChar" then
		return scan(MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter)
	end
	return scan(1, numAccount) or scan(MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter)
end

local function lastMacroIndex(scope)
	local numAccount, numCharacter = GetNumMacros()
	if scope == "gameChar" then
		if numCharacter < 1 then
			return
		end
		return MAX_ACCOUNT + numCharacter
	end
	if numAccount < 1 then
		return
	end
	return numAccount
end

local function storedMacroName(name)
	local wanted = truncateName(name ~= "" and name or " ", STUB_NAME_LIMIT)
	if wanted == "" then
		wanted = " "
	end
	return wanted
end

local function macroIdentity(scope, name, body)
	return (scope or "gameAccount") .. "\31" .. strlower(storedMacroName(name)) .. "\31" .. normalizeBody(body)
end

local function sortedMacroKeys(keys)
	sort(keys)
	return keys
end

local function sameMacroKeys(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- First unused slot in the same pool with the same name and body.
local function takeMatchingMacro(item, used)
	if type(item) ~= "table" or type(item.body) ~= "string" then
		return
	end
	local wantName = strlower(storedMacroName(item.name))
	local wantBody = normalizeBody(item.body)
	local numAccount, numCharacter = GetNumMacros()
	local first, last = 1, numAccount
	if item.scope == "gameChar" then
		first, last = MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter
	end
	for i = first, last do
		if not used[i] then
			local existing, _, existingBody = GetMacroInfo(i)
			if existing and strlower(storedMacroName(existing)) == wantName and normalizeBody(existingBody) == wantBody then
				used[i] = true
				return i
			end
		end
	end
end

local function collectTakenNames(scope)
	local taken = {}
	local numAccount, numCharacter = GetNumMacros()
	local first, last = 1, numAccount
	if scope == "gameChar" then
		first, last = MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter
	elseif scope ~= "gameAccount" then
		for i = 1, numAccount do
			local existing = GetMacroInfo(i)
			if existing then
				taken[strlower(existing)] = true
			end
		end
		for i = MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter do
			local existing = GetMacroInfo(i)
			if existing then
				taken[strlower(existing)] = true
			end
		end
		return taken
	end
	for i = first, last do
		local existing = GetMacroInfo(i)
		if existing then
			taken[strlower(existing)] = true
		end
	end
	return taken
end

local function disambiguateName(base, taken)
	base = truncateName(strtrim(base or ""), STUB_NAME_LIMIT)
	if base == "" then
		base = " "
	end
	local name, suffix = base, 1
	while taken[strlower(name)] do
		suffix = suffix + 1
		local tail = " " .. suffix
		name = truncateName(base, STUB_NAME_LIMIT - #tail) .. tail
	end
	taken[strlower(name)] = true
	return name
end

local function createMacroExact(scope, name, icon, body)
	if not gameSlotFree(scope) then
		return
	end
	local ok, created = pcall(CreateMacro, name, icon, body, scope == "gameChar" and 1 or nil)
	if not ok then
		return
	end
	local index
	if type(created) == "number" and GetMacroInfo(created) and namesEqual(select(1, GetMacroInfo(created)), name) then
		index = created
	else
		-- Prefer last slot in that scope (append) over any name API.
		index = lastMacroIndex(scope)
		if not (index and namesEqual(select(1, GetMacroInfo(index)), name)) then
			index = findMacroIndexByExactName(name)
		end
	end
	if index then
		-- Write body again so CreateMacro cannot silently shorten it.
		pcall(EditMacro, index, name, icon, body)
	end
	return index
end

local function scopeOfItem(item)
	if type(item) == "table" and item.scope == "gameChar" then
		return "gameChar"
	end
	return "gameAccount"
end

local function liveScopeKeys(scope)
	local keys = {}
	local numAccount, numCharacter = GetNumMacros()
	local first, last = 1, numAccount
	if scope == "gameChar" then
		first, last = MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter
	end
	for i = first, last do
		local name, _, body = GetMacroInfo(i)
		if name then
			keys[#keys + 1] = macroIdentity(scope, name, body)
		end
	end
	return sortedMacroKeys(keys)
end

local function wantedScopeKeys(items, indices, scope)
	local keys = {}
	for i = 1, #indices do
		local item = items[indices[i]]
		if type(item) == "table" and type(item.body) == "string" then
			keys[#keys + 1] = macroIdentity(scope, item.name, item.body)
		end
	end
	return sortedMacroKeys(keys)
end

local function indicesForScope(items, scope)
	local indices = {}
	for index, item in ipairs(items) do
		if type(item) == "table" and type(item.body) == "string" and scopeOfItem(item) == scope then
			indices[#indices + 1] = index
		end
	end
	return indices
end

local function assignMatchedMacros(items, indices, entries, used)
	local imported, skipped = 0, 0
	for i = 1, #indices do
		local index = indices[i]
		local slot = takeMatchingMacro(items[index], used)
		if slot then
            local ok = updateMacroIcon(slot, items[index])
			if entries then
				entries[index] = slot
			end
			imported = imported + (ok and 1 or 0)
            if not ok then skipped = skipped + 1 end
		else
			skipped = skipped + 1
		end
	end
	return imported, skipped
end

local function scopeFreeSlots(scope)
	local numAccount, numCharacter = GetNumMacros()
	if scope == "gameChar" then
		return MAX_CHARACTER - numCharacter
	end
	return MAX_ACCOUNT - numAccount
end

-- Imported macros that are not already in this pool (same name and body).
local function unmatchedIndices(items, indices)
	local used, pending = {}, {}
	for i = 1, #indices do
		local index = indices[i]
		if not takeMatchingMacro(items[index], used) then
			pending[#pending + 1] = index
		end
	end
	return pending
end

local function scopeWillWipe(items, indices, scope)
	if #indices == 0 or sameMacroKeys(liveScopeKeys(scope), wantedScopeKeys(items, indices, scope)) then
		return false
	end
	return #unmatchedIndices(items, indices) > scopeFreeSlots(scope)
end

-- Replace one pool without touching macros that already match the import.
-- Keeping those slots alive is important: deleting and recreating an identical
-- account macro clears it from action bars of other characters on the account.
local function recreateMacroScope(items, indices, entries, scope)
	local used, keep = {}, {}
	for i = 1, #indices do
		local slot = takeMatchingMacro(items[indices[i]], used)
		if slot then
			keep[slot] = true
		end
	end

	local numAccount, numCharacter = GetNumMacros()
	local first, last = 1, numAccount
	if scope == "gameChar" then
		first, last = MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter
	end
	for slot = last, first, -1 do
		if not keep[slot] then
			pcall(DeleteMacro, slot)
		end
	end

	-- Deleting lower slots can renumber the preserved macros. Resolve their
	-- current indices again before creating the missing part of the import.
	used = {}
	local imported, pending, iconFailures = 0, {}, 0
	for i = 1, #indices do
		local index = indices[i]
		local slot = takeMatchingMacro(items[index], used)
		if slot then
            local ok = updateMacroIcon(slot, items[index])
			if entries then
				entries[index] = slot
			end
			imported = imported + (ok and 1 or 0)
            if not ok then iconFailures = iconFailures + 1 end
		else
			pending[#pending + 1] = index
		end
	end

	local taken = collectTakenNames(scope)
	local skipped = iconFailures
	for i = 1, #pending do
		if InCombatLockdown() then
			skipped = skipped + (#pending - i + 1)
			break
		end
		local index = pending[i]
		local item = items[index]
		local wanted = storedMacroName(item.name)
		local name = disambiguateName(wanted, taken)
		local slot = createMacroExact(scope, name, iconIndexOf(item.icon), item.body)
		if slot then
			if entries then
				entries[index] = slot
			end
			imported = imported + 1
		else
			skipped = skipped + 1
		end
	end
	return imported, skipped
end

-- Same set: leave the pool alone.
-- New macros fit in free slots: append them, keep what is already there.
-- Not enough room: preserve exact matches, remove only non-matches, then add
-- the missing imported macros.
local function importMacroScope(items, indices, entries, scope)
	if sameMacroKeys(liveScopeKeys(scope), wantedScopeKeys(items, indices, scope)) then
		return assignMatchedMacros(items, indices, entries, {})
	end
	local pending = unmatchedIndices(items, indices)
	if #pending > scopeFreeSlots(scope) then
		return recreateMacroScope(items, indices, entries, scope)
	end
	-- Misses here are the macros we are about to append, not failures.
	local imported = select(1, assignMatchedMacros(items, indices, entries, {}))
	local skipped = 0
	local taken = collectTakenNames(scope)
	for i = 1, #pending do
		if InCombatLockdown() then
			skipped = skipped + (#pending - i + 1)
			break
		end
		local index = pending[i]
		local item = items[index]
		local name = disambiguateName(storedMacroName(item.name), taken)
		local slot = createMacroExact(scope, name, iconIndexOf(item.icon), item.body)
		if slot then
			if entries then
				entries[index] = slot
			end
			imported = imported + 1
		else
			skipped = skipped + 1
		end
	end
	return imported, skipped
end

local function importMacros(items, entries)
	if InCombatLockdown() then
		return 0, #items
	end
	local imported, skipped = 0, 0
	-- Character pool first so replacing it cannot delete macros just added for the account.
	for _, scope in ipairs({ "gameChar", "gameAccount" }) do
		local indices = indicesForScope(items, scope)
		if #indices > 0 then
			local got, miss = importMacroScope(items, indices, entries, scope)
			imported = imported + (got or 0)
			skipped = skipped + (miss or 0)
		end
	end
	return imported, skipped
end

-- Used only when actions need a macro that was not part of the macros wipe/import.
local function ensureMacroSlot(item)
	if InCombatLockdown() or type(item) ~= "table" then
		return
	end
	if type(item.body) ~= "string" then
		return
	end
	local body = item.body
	local name = item.name ~= "" and truncateName(item.name, STUB_NAME_LIMIT) or " "
	local icon = iconIndexOf(item.icon)
	-- 1) Exact name + body
	local slot = findMacroIndexByNameAndBody(name, body) or findMacroIndexByNameAndBody(item.name, body)
	if slot then
        if not updateMacroIcon(slot, item) then return end
		return slot
	end
	-- 2) Exact name only → overwrite that one slot (not a prefix neighbour)
	slot = findMacroIndexByExactName(name) or findMacroIndexByExactName(item.name)
	if slot and namesEqual(GetMacroInfo(slot), name) then
		pcall(EditMacro, slot, name, icon, body)
		return slot
	end
	-- 3) Create with the exact imported name
	slot = createMacroExact(item.scope, name, icon, body)
	if slot then
		return slot
	end
	local other = item.scope == "gameChar" and "gameAccount" or "gameChar"
	slot = createMacroExact(other, name, icon, body)
	if slot then
		return slot
	end
	-- 4) Last resort: unique suffix if the exact name is somehow blocked
	local taken = {}
	local numAccount, numCharacter = GetNumMacros()
	for i = 1, numAccount do
		local existing = GetMacroInfo(i)
		if existing then
			taken[strlower(existing)] = true
		end
	end
	for i = MAX_ACCOUNT + 1, MAX_ACCOUNT + numCharacter do
		local existing = GetMacroInfo(i)
		if existing then
			taken[strlower(existing)] = true
		end
	end
	local unique = disambiguateName(name, taken)
	return createMacroExact(item.scope, unique, icon, body)
		or createMacroExact(other, unique, icon, body)
end

-- ClearCursor() while a merchant is open sells the item on the cursor.
-- Action-bar import picks up items/macros and must never dump them on a vendor.
local function closeItemSinkFrames()
	if MerchantFrame and MerchantFrame:IsShown() then
		HideUIPanel(MerchantFrame)
	end
	if MailFrame and MailFrame:IsShown() then
		HideUIPanel(MailFrame)
	end
	if TradeFrame and TradeFrame:IsShown() then
		HideUIPanel(TradeFrame)
	end
end

local function returnCursorItemToBags()
	if GetCursorInfo() ~= "item" then
		return
	end
	if PutItemInBackpack then
		pcall(PutItemInBackpack)
	end
	if GetCursorInfo() ~= "item" then
		return
	end
	local lastBag = (NUM_BAG_SLOTS or 4)
	for bag = 0, lastBag do
		if GetCursorInfo() ~= "item" then
			return
		end
		if PutItemInBag then
			pcall(PutItemInBag, bag)
		end
	end
end

local function safeClearCursor()
	if not GetCursorInfo() then
		return
	end
	if GetCursorInfo() == "item" then
		closeItemSinkFrames()
		returnCursorItemToBags()
	end
	if GetCursorInfo() then
		ClearCursor()
	end
end

local function pickupMacroSlot(slot)
	if not slot then
		return false
	end
	safeClearCursor()
	pcall(PickupMacro, slot)
	return GetCursorInfo() and true or false
end

local function addKeys(bindings, seen, command, ...)
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		if key and not seen[key] then
			seen[key] = true
			bindings[#bindings + 1] = { key, command }
		end
	end
end

local function currentBindings()
	local bindings, seen = {}, {}
	for i = 1, GetNumBindings() do
		addKeys(bindings, seen, GetBinding(i))
	end
	local bindingKeys = SarychUI.TransferBindingKeys or {}
	for _, modifier in ipairs(MODIFIERS) do
		for _, key in ipairs(bindingKeys) do
			local combo = modifier .. key
			local action = GetBindingAction(combo)
			if action and action ~= "" then
				addKeys(bindings, seen, action, combo)
			end
		end
	end
	return bindings
end

local function sameValue(a, b)
	if a == b then
		return true
	end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and y ~= nil and abs(x - y) < 0.0001
end

local function readCVar(name)
	local ok, value = pcall(GetCVar, name)
	local okDefault, default = pcall(GetCVarDefault, name)
	if ok and okDefault and value ~= nil then
		return value, default
	end
end

local function validColor(color)
	return type(color) == "table" and tonumber(color[1]) and tonumber(color[2]) and tonumber(color[3])
end

local function channelColorsStore()
	local db = SarychUI.db
	if not db then
		return {}
	end
	db.global = db.global or {}
	db.global.transferChannelColors = db.global.transferChannelColors or {}
	return db.global.transferChannelColors
end

local function exportActionBarVisibility()
    if type(GetActionBarToggles) ~= "function" then return end
    local values = {GetActionBarToggles()}
    local state = {}
    for i = 1, 4 do state[i] = values[i] == true or values[i] == 1 or values[i] == "1" end
    state.alwaysShow = GetCVar("alwaysShowActionBars") == "1"
    return state
end

local function importActionBarVisibility(state)
    if type(state) ~= "table" or type(SetActionBarToggles) ~= "function" then return end
    for i = 1, 4 do if type(state[i]) ~= "boolean" then return end end
    if type(state.alwaysShow) ~= "boolean" then return end
    SetCVar("alwaysShowActionBars", state.alwaysShow and "1" or "0")
    SHOW_MULTI_ACTIONBAR_1 = state[1] and 1 or nil
    SHOW_MULTI_ACTIONBAR_2 = state[2] and 1 or nil
    SHOW_MULTI_ACTIONBAR_3 = state[3] and 1 or nil
    SHOW_MULTI_ACTIONBAR_4 = state[4] and 1 or nil
    ALWAYS_SHOW_MULTIBARS = state.alwaysShow and 1 or nil
    SetActionBarToggles(SHOW_MULTI_ACTIONBAR_1, SHOW_MULTI_ACTIONBAR_2,
        SHOW_MULTI_ACTIONBAR_3, SHOW_MULTI_ACTIONBAR_4, ALWAYS_SHOW_MULTIBARS)
    if MultiActionBar_Update then MultiActionBar_Update() end
    if UIParent_ManageFramePositions then UIParent_ManageFramePositions() end
end

local exporters = {}

function exporters.macros(data)
	local refs = {}
	for _, scope in ipairs(MACRO_SCOPES) do
		local entries = gameIndices(scope, {})
		for i = 1, #entries do
			local ref = macroRef(data.macroDefs, scope, entries[i])
			if ref then
				refs[#refs + 1] = ref
			end
		end
	end
	return refs
end

local function textureKey(path)
	if type(path) ~= "string" or path == "" then
		return
	end
	path = strlower(path)
	path = strgsub(path, "\\", "/")
	path = strgsub(path, "%.blp$", "")
	return path
end

local function sameTexture(a, b)
	local x, y = textureKey(a), textureKey(b)
	return x and y and x == y
end

local function linkSpellId(link)
	return link and tonumber(strmatch(link, "spell:(%d+)"))
end

-- 3.3.5 GetActionInfo returns the spellbook slot as the 2nd value. The 4th
-- value (retail spell id) is nil or 0 here, so the old export stored a spell
-- with no id. Import then cleared every such button.
local function resolveActionSpell(slot, id, subType, globalId)
	local actionTex = GetActionTexture and GetActionTexture(slot)
	local book = (subType == "PET" and BOOKTYPE_PET) or BOOKTYPE_SPELL
	local petFlag = (subType == "PET") and "pet" or nil

	local function bookHit(index, bookType)
		if type(index) ~= "number" or index <= 0 or not GetSpellName or not bookType then
			return
		end
		local name = GetSpellName(index, bookType)
		if type(name) ~= "string" or name == "" then
			return
		end
		local icon = GetSpellTexture and GetSpellTexture(index, bookType)
		if actionTex and icon and not sameTexture(actionTex, icon) then
			return
		end
		if actionTex and not icon then
			return
		end
		return linkSpellId(GetSpellLink(index, bookType)), name
	end

	local function idHit(spellId)
		spellId = tonumber(spellId)
		if not spellId or spellId <= 0 or not GetSpellInfo then
			return
		end
		local name, _, icon = GetSpellInfo(spellId)
		if type(name) ~= "string" or name == "" then
			return
		end
		if actionTex and icon and not sameTexture(actionTex, icon) then
			return
		end
		return spellId, name
	end

	local sid, name = bookHit(id, book)
	if not name and book ~= BOOKTYPE_SPELL then
		sid, name = bookHit(id, BOOKTYPE_SPELL)
	end
	if name then
		return sid, name, petFlag
	end
	sid, name = idHit(globalId)
	if not name then
		sid, name = idHit(id)
	end
	if name then
		return sid, name, petFlag
	end
	-- No texture match. Prefer a real spell id over a colliding book slot.
	local gid = tonumber(globalId)
	if gid and gid > 0 and GetSpellInfo then
		name = GetSpellInfo(gid)
		if type(name) == "string" and name ~= "" then
			return gid, name, petFlag
		end
	end
	if type(id) == "number" and id > 0 and GetSpellInfo then
		name = GetSpellInfo(id)
		if type(name) == "string" and name ~= "" then
			return id, name, petFlag
		end
	end
	if type(id) == "number" and id > 0 and GetSpellName then
		name = GetSpellName(id, book)
		if type(name) == "string" and name ~= "" then
			return linkSpellId(GetSpellLink(id, book)), name, petFlag
		end
	end
end

function exporters.actions(data)
	local actions = {}
	for slot = 1, ACTION_SLOTS do
		local kind, id, subType, spellId = GetActionInfo(slot)
		if kind == "spell" then
			local sid, spellName, pet = resolveActionSpell(slot, id, subType, spellId)
			if spellName then
				actions[slot] = { kind, sid or 0, spellName, pet }
			end
		elseif kind == "companion" then
			local cid = tonumber(spellId)
			if not cid or cid <= 0 then
				cid = tonumber(id)
			end
			if cid and cid > 0 then
				actions[slot] = { kind, cid, subType }
			end
		elseif kind == "item" then
			if tonumber(id) then
				actions[slot] = { kind, id }
			end
		elseif kind == "equipmentset" then
			local name = id
			if type(name) == "number" and GetEquipmentSetInfo then
				local setName = GetEquipmentSetInfo(name)
				if type(setName) == "string" and setName ~= "" then
					name = setName
				end
			end
			if type(name) == "string" and name ~= "" then
				actions[slot] = { kind, name }
			end
		elseif kind == "macro" then
			local macroIndex = tonumber(id)
			if not macroIndex and type(id) == "string" then
				macroIndex = findMacroIndexByExactName(id)
			end
			if macroIndex and GetMacroInfo(macroIndex) then
				local scope = macroIndex > MAX_ACCOUNT and "gameChar" or "gameAccount"
				local ref = macroRef(data.macroDefs, scope, macroIndex)
				if ref then
					actions[slot] = { kind, ref }
				end
			end
		end
	end
	return actions
end

function exporters.bindings()
	return currentBindings()
end

local function exportCVars(_, group)
	local values = {}
	local list = SarychUI.TransferCVars and SarychUI.TransferCVars[group]
	if not list then
		return values
	end
	for _, name in ipairs(list) do
		local value, default = readCVar(name)
		if value and not sameValue(value, default) then
			values[name] = value
		end
	end
	return values
end

function exporters.chat()
	local windows = {}
	for id = 1, NUM_CHAT_WINDOWS do
		local name, size, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(id)
		local window = {
			name = name,
			size = size,
			color = { r, g, b, alpha },
			shown = shown and true or nil,
			locked = locked and true or nil,
			docked = docked,
			uninteractable = uninteractable and true or nil,
			messages = { GetChatWindowMessages(id) },
		}
		local point, x, y = GetChatWindowSavedPosition(id)
		if point then
			window.position = { point, x, y }
		end
		local width, height = GetChatWindowSavedDimensions(id)
		if width then
			window.dimensions = { width, height }
		end
		windows[id] = window
	end

	local colors = {}
	for chatType, info in pairs(ChatTypeInfo) do
		if not strmatch(chatType, "^CHANNEL%d") then
			colors[chatType] = { info.r, info.g, info.b }
		end
	end

	local channelColors = {}
	for name, color in pairs(channelColorsStore()) do
		channelColors[name] = { color.r, color.g, color.b }
	end
	local list = { GetChannelList() }
	for i = 1, #list, 2 do
		local name = list[i + 1]
		local info = ChatTypeInfo["CHANNEL" .. list[i]]
		if info then
			channelColors[name] = { info.r, info.g, info.b }
		end
	end

	return { windows = windows, colors = colors, channelColors = channelColors }
end

function exporters.friends()
	local friends = {}
	for i = 1, GetNumFriends() do
		local name, _, _, _, _, _, note = GetFriendInfo(i)
		if name then
			friends[#friends + 1] = { name, note }
		end
	end
	return friends
end

function exporters.ignore()
	local names = {}
	for i = 1, GetNumIgnores() do
		local name = GetIgnoreName(i)
		if name and name ~= UNKNOWN then
			names[#names + 1] = name
		end
	end
	return names
end

function Transfer.Export()
	local Encode = SarychUI.TransferEncode
	local data = {
		version = 1,
		character = UnitName("player") .. " - " .. GetRealmName(),
		class = select(2, UnitClass("player")),
		macroDefs = {},
	}
	local selected = false
	for _, category in ipairs(Transfer.CATEGORIES) do
		if Transfer.IsExported(category.key) then
			local exporter = category.cvars and exportCVars or exporters[category.key]
			data[category.key] = exporter(data, category.key)
			selected = true
		end
	end
    if data.actions or data.interface then data.actionBarVisibility = exportActionBarVisibility() end
	if not selected then
		return nil, T("ничего не отмечено для копирования")
	end
	if not next(data.macroDefs) then
		data.macroDefs = nil
	end
	return EXPORT_PREFIX .. Encode.Encode(Encode.Serialize(data))
end

function Transfer.Decode(text)
	text = text and strtrim(text)
	if not text or text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return nil, T("это не строка настроек SarychUI")
	end
	local Encode = SarychUI.TransferEncode
	local body, err = Encode.Decode(text:sub(#EXPORT_PREFIX + 1))
	if not body then
		return nil, err and T(err) or T("повреждённая строка")
	end
	local data = Encode.Deserialize(body)
	if type(data) ~= "table" then
		return nil, T("повреждённая строка настроек")
	end
	return data
end

function Transfer.Count(data, key)
	local value = data[key]
	if type(value) ~= "table" then
		return nil
	end
	local count = 0
	if key == "chat" then
		for _, window in pairs(type(value.windows) == "table" and value.windows or {}) do
			if type(window) == "table" and (window.shown or window.docked) then
				count = count + 1
			end
		end
	else
		for _ in pairs(value) do
			count = count + 1
		end
	end
	return count
end

local importers = {}

local function collectMacroItems(refs, defs)
	local items, itemRefs = {}, {}
	local seen = {}
	-- Keep export order from the macros list first.
	for _, ref in ipairs(refs or {}) do
		local item = defs and defs[ref]
		if item and not seen[ref] then
			seen[ref] = true
			items[#items + 1] = item
			itemRefs[#items] = ref
		end
	end
	-- Also include macros that exist only as bar references in macroDefs.
	for ref, item in pairs(defs or {}) do
		if item and not seen[ref] then
			seen[ref] = true
			items[#items + 1] = item
			itemRefs[#items] = ref
		end
	end
	return items, itemRefs
end

function importers.macros(refs, context)
	local items, itemRefs = collectMacroItems(refs, context.defs)
	local entries = {}
	local imported, skipped = importMacros(items, entries)
	for i, ref in ipairs(itemRefs) do
		if entries[i] then
			context.entries[ref] = entries[i]
		end
	end
	return imported, skipped or 0
end

local function resolveMacro(context, ref)
	local entry = context.entries[ref]
	if entry and GetMacroInfo(entry) then
		return entry
	end
	local item = context.defs[ref]
	if not item then
		return
	end
	local slot = ensureMacroSlot(item)
	if slot then
		context.entries[ref] = slot
	end
	return slot
end

local function spellBook(bookType)
	local byId, byName = {}, {}
	bookType = bookType or BOOKTYPE_SPELL
	local function add(index)
		local link = GetSpellLink(index, bookType)
		local id = link and tonumber(strmatch(link, "spell:(%d+)"))
		if id then
			byId[id] = index
		end
		local name = GetSpellName(index, bookType)
		if type(name) == "string" and name ~= "" then
			-- Last entry wins: the spellbook lists ranks low to high.
			byName[name] = index
		end
	end
	if bookType == BOOKTYPE_PET then
		local num = HasPetSpells and HasPetSpells()
		num = type(num) == "number" and num or 0
		for index = 1, num do
			add(index)
		end
		return byId, byName
	end
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, count = GetSpellTabInfo(tab)
		for index = offset + 1, offset + count do
			add(index)
		end
	end
	return byId, byName
end

local function companions(kind)
	local indices = {}
	for index = 1, GetNumCompanions(kind) do
		local _, _, spellId = GetCompanionInfo(kind, index)
		if spellId then
			indices[spellId] = index
		end
	end
	return indices
end

local function actionAt(actions, slot)
	if type(actions) ~= "table" then
		return
	end
	local action = actions[slot]
	if type(action) ~= "table" then
		action = actions[tostring(slot)]
	end
	if type(action) ~= "table" then
		return
	end
	return action
end

function importers.actions(actions, context)
	closeItemSinkFrames()
	local spellById, spellByName = spellBook(BOOKTYPE_SPELL)
	local spellBooks = {
		[BOOKTYPE_SPELL] = { spellById, spellByName },
	}
	if BOOKTYPE_PET then
		local petById, petByName = spellBook(BOOKTYPE_PET)
		spellBooks[BOOKTYPE_PET] = { petById, petByName }
	end
	local companionIndices = { MOUNT = companions("MOUNT"), CRITTER = companions("CRITTER") }

	local function pickupSpell(spellId, spellName, bookType)
		bookType = (bookType == BOOKTYPE_PET and BOOKTYPE_PET) or BOOKTYPE_SPELL
		local pack = spellBooks[bookType] or spellBooks[BOOKTYPE_SPELL]
		local byId, byName = pack[1], pack[2]
		local index
		if spellId and spellId > 0 then
			index = byId[spellId]
		end
		if not index and type(spellName) == "string" and spellName ~= "" then
			index = byName[spellName]
		end
		if not index and spellId and spellId > 0 and GetSpellInfo then
			local name = GetSpellInfo(spellId)
			if type(name) == "string" and name ~= "" then
				index = byName[name]
				if type(spellName) ~= "string" or spellName == "" then
					spellName = name
				end
			end
		end
		if not index and type(spellName) == "string" and spellName ~= "" and bookType ~= BOOKTYPE_SPELL then
			index = spellBooks[BOOKTYPE_SPELL][2][spellName]
			if index then
				bookType = BOOKTYPE_SPELL
			end
		end
		if index then
			PickupSpell(index, bookType)
		end
		if not GetCursorInfo() and type(spellName) == "string" and spellName ~= "" then
			pcall(PickupSpell, spellName)
		end
	end

	local applied, skipped = 0, 0
	for slot = 1, ACTION_SLOTS do
		local action = actionAt(actions, slot)
		-- Only clear a filled slot when the source slot was empty, or when this
		-- character genuinely does not have that spell/item/macro. A spell
		-- exported without an id used to look like an action and wipe the bar.
		local identified = false
		safeClearCursor()
		if type(action) == "table" then
			local kind, value, extra = action[1], action[2], action[3]
			if kind == "spell" then
				local spellId = tonumber(value)
				if spellId and spellId <= 0 then
					spellId = nil
				end
				local spellName = type(extra) == "string" and extra or nil
				local bookType = action[4] == "pet" and BOOKTYPE_PET or BOOKTYPE_SPELL
				if spellId or (spellName and spellName ~= "") then
					identified = true
					pickupSpell(spellId, spellName, bookType)
				end
			elseif kind == "companion" then
				local cid = tonumber(value)
				if cid and cid > 0 then
					identified = true
					local subType = extra
					local index = type(subType) == "string" and companionIndices[subType] and companionIndices[subType][cid]
					if not index and companionIndices.MOUNT then
						index = companionIndices.MOUNT[cid]
						subType = index and "MOUNT" or subType
					end
					if not index and companionIndices.CRITTER then
						index = companionIndices.CRITTER[cid]
						subType = index and "CRITTER" or subType
					end
					if index and (subType == "MOUNT" or subType == "CRITTER") then
						PickupCompanion(subType, index)
					end
				end
			elseif kind == "item" and tonumber(value) then
				identified = true
				PickupItem(value)
			elseif kind == "equipmentset" then
				local name = value
				if type(name) == "number" and GetEquipmentSetInfo then
					local setName = GetEquipmentSetInfo(name)
					if type(setName) == "string" and setName ~= "" then
						name = setName
					end
				end
				if type(name) == "string" and name ~= "" then
					identified = true
					if GetEquipmentSetInfoByName(name) then
						PickupEquipmentSetByName(name)
					end
				end
			elseif kind == "macro" then
				identified = true
				local entry = resolveMacro(context, value)
				if entry then
					pickupMacroSlot(entry)
				end
			end
		end
		if GetCursorInfo() then
			pcall(PlaceAction, slot)
			applied = applied + 1
		else
			if action then
				skipped = skipped + 1
			end
			if (not action or identified) and GetActionInfo(slot) then
				pcall(PickupAction, slot)
			end
		end
		safeClearCursor()
	end
	return applied, skipped
end

function importers.bindings(bindings)
	if #bindings == 0 then
		return 0, 0
	end
	for _, binding in ipairs(currentBindings()) do
		SetBinding(binding[1])
	end
	local applied, skipped = 0, 0
	for _, binding in ipairs(bindings) do
		local key, command = type(binding) == "table" and binding[1], type(binding) == "table" and binding[2]
		if type(key) == "string" and type(command) == "string" then
			if command and SetBinding(key, command) then
				applied = applied + 1
			else
				skipped = skipped + 1
			end
		end
	end
	-- Blizzard binding set 2 is the character-specific set (the
	-- "Для этого персонажа" checkbox in the default bindings window).
	SaveBindings(2)
	return applied, skipped
end

local function importCVars(values, _, group)
	local applied = 0
	local list = SarychUI.TransferCVars and SarychUI.TransferCVars[group]
	if not list then
		return 0, 0
	end
	for _, name in ipairs(list) do
		local value, default = readCVar(name)
		local wanted = type(values[name]) == "string" and values[name] or default
		if value and wanted and not sameValue(value, wanted) and pcall(SetCVar, name, wanted) then
			applied = applied + 1
		end
	end
	return applied, 0
end

local function applyWindow(id, window)
	local chatFrame = _G["ChatFrame" .. id]
	if not chatFrame then
		return
	end
	if type(window.name) == "string" then
		SetChatWindowName(id, window.name)
	end
	local size = tonumber(window.size)
	if size and size > 0 then
		FCF_SetChatWindowFontSize(nil, chatFrame, size)
	end
	local color = window.color
	if validColor(color) then
		SetChatWindowColor(id, color[1], color[2], color[3])
		SetChatWindowAlpha(id, tonumber(color[4]) or DEFAULT_CHATFRAME_ALPHA)
	end
	SetChatWindowLocked(id, window.locked and 1 or nil)
	SetChatWindowUninteractable(id, window.uninteractable and 1 or nil)
	SetChatWindowShown(id, window.shown and 1 or nil)
	SetChatWindowDocked(id, tonumber(window.docked))
	local position, dimensions = window.position, window.dimensions
	if id ~= 1 and type(position) == "table" and type(position[1]) == "string" then
		SetChatWindowSavedPosition(id, position[1], tonumber(position[2]) or 0, tonumber(position[3]) or 0)
	end
	if id ~= 1 and type(dimensions) == "table" and tonumber(dimensions[1]) and tonumber(dimensions[2]) then
		SetChatWindowSavedDimensions(id, dimensions[1], dimensions[2])
	end

	ChatFrame_RemoveAllMessageGroups(chatFrame)
	if type(window.messages) == "table" then
		for _, group in ipairs(window.messages) do
			ChatFrame_AddMessageGroup(chatFrame, group)
		end
	end

end

local function dockOrder(id)
	return (select(9, GetChatWindowInfo(id))) or NUM_CHAT_WINDOWS + id
end

local function applyChannelColors()
	local saved = channelColorsStore()
	local list = { GetChannelList() }
	for i = 1, #list, 2 do
		local color = saved[list[i + 1]]
		if color then
			ChangeChatColor("CHANNEL" .. list[i], color.r, color.g, color.b)
		end
	end
end

function importers.chat(chat)
	local windows = type(chat.windows) == "table" and chat.windows or {}

	if type(chat.channelColors) == "table" then
		local saved = channelColorsStore()
		for name, color in pairs(chat.channelColors) do
			if type(name) == "string" and validColor(color) then
				saved[name] = { r = color[1], g = color[2], b = color[3] }
			end
		end
	end
	-- Legacy channel fields are ignored; Blizzard owns channel membership and subscriptions.

	for id = 2, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame" .. id]
		if frame then
			FCF_UnDockFrame(frame)
		end
	end
	local applied = 0
	for id = 1, NUM_CHAT_WINDOWS do
		if type(windows[id]) == "table" then
			applyWindow(id, windows[id])
			applied = applied + 1
		end
	end
	local order = {}
	for id = 1, NUM_CHAT_WINDOWS do
		order[id] = id
	end
	sort(order, function(a, b)
		return dockOrder(a) < dockOrder(b)
	end)
	for _, id in ipairs(order) do
		FloatingChatFrame_Update(id, 1)
	end

	if type(chat.colors) == "table" then
		for chatType, color in pairs(chat.colors) do
			if ChatTypeInfo[chatType] and validColor(color) then
				ChangeChatColor(chatType, color[1], color[2], color[3])
			end
		end
	end
	applyChannelColors()
	return applied, 0
end

local pendingNotes = {}

local function applyNotes()
	for i = 1, GetNumFriends() do
		local name = GetFriendInfo(i)
		local note = name and pendingNotes[strlower(name)]
		if note then
			pendingNotes[strlower(name)] = nil
			SetFriendNotes(i, note)
		end
	end
	if not next(pendingNotes) then
		UnregisterTransferEvent("FRIENDLIST_UPDATE")
	end
end

function importers.friends(friends)
	local known = {}
	for i = 1, GetNumFriends() do
		local name = GetFriendInfo(i)
		if name then
			known[strlower(name)] = true
		end
	end
	known[strlower(UnitName("player"))] = true
	local applied, skipped = 0, 0
	for _, friend in ipairs(friends) do
		local name, note = type(friend) == "table" and friend[1], type(friend) == "table" and friend[2]
		if type(name) == "string" and name ~= "" then
			local key = strlower(name)
			if type(note) == "string" and note ~= "" then
				pendingNotes[key] = note
			end
			if known[key] then
				skipped = skipped + 1
			else
				known[key] = true
				AddFriend(name)
				applied = applied + 1
			end
		end
	end
	pendingNotes[strlower(UnitName("player"))] = nil
	if next(pendingNotes) then
		RegisterTransferEvent("FRIENDLIST_UPDATE", applyNotes)
		applyNotes()
	end
	return applied, skipped
end

function importers.ignore(names)
	local known = {}
	for i = 1, GetNumIgnores() do
		local name = GetIgnoreName(i)
		if name then
			known[strlower(name)] = true
		end
	end
	known[strlower(UnitName("player"))] = true
	local applied, skipped = 0, 0
	for _, name in ipairs(names) do
		if type(name) == "string" and name ~= "" then
			if known[strlower(name)] then
				skipped = skipped + 1
			else
				known[strlower(name)] = true
				AddIgnore(name)
				applied = applied + 1
			end
		end
	end
	return applied, skipped
end

function Transfer.MacrosWillReplace(data)
	if type(data) ~= "table" or type(data.macros) ~= "table" then
		return false
	end
	local defs = {}
	if type(data.macroDefs) == "table" then
		for ref, item in pairs(data.macroDefs) do
			defs[ref] = sanitizeMacro(item)
		end
	end
	local items = collectMacroItems(data.macros, defs)
	for _, scope in ipairs(MACRO_SCOPES) do
		local indices = indicesForScope(items, scope)
		if scopeWillWipe(items, indices, scope) then
			return true
		end
	end
	return false
end

function Transfer.Import(data, selected, equipRemap)
	if InCombatLockdown() then
		Print(T("нельзя импортировать настройки в бою"))
		return false
	end
	-- Importing bars picks up items; a open merchant would sell them on ClearCursor.
	if selected and selected.actions then
		closeItemSinkFrames()
	end
	if type(equipRemap) == "table" and next(equipRemap) and Transfer.ApplyEquipRemap then
		Transfer.ApplyEquipRemap(data, equipRemap)
	end
	local defs = {}
	if type(data.macroDefs) == "table" then
		for ref, item in pairs(data.macroDefs) do
			defs[ref] = sanitizeMacro(item)
		end
	end
	-- Sanitize copies bodies; apply again so /equipslot lines never keep old names.
	if type(equipRemap) == "table" and next(equipRemap) and Transfer.ApplyEquipRemapToDefs then
		Transfer.ApplyEquipRemapToDefs(defs, equipRemap)
	end
	local context = { defs = defs, entries = {} }
	Print(T("импортированы настройки %s:"):format(type(data.character) == "string" and data.character or "?"))
	for _, category in ipairs(Transfer.CATEGORIES) do
		if selected[category.key] and type(data[category.key]) == "table" then
			local importer = category.cvars and importCVars or importers[category.key]
			-- pcall (not xpcall+geterrorhandler): the Blizzard error UI can re-enter
			-- itself on format failures and blow the C stack.
			local ok, applied, skipped = pcall(importer, data[category.key], context, category.key)
			if not ok then
				Print("|cffff5555" .. T(category.label) .. ": " .. tostring(applied) .. "|r")
			elseif type(skipped) == "number" and skipped > 0 then
				Print(T("%s: %d, пропущено %d"):format(T(category.label), tonumber(applied) or 0, skipped))
			else
				Print(T("%s: %d"):format(T(category.label), tonumber(applied) or 0))
			end
		end
	end
    if (selected.actions and type(data.actions) == "table")
        or (selected.interface and type(data.interface) == "table") then
        local ok, err = pcall(importActionBarVisibility, data.actionBarVisibility)
        if not ok then Print("|cffff5555" .. T("Панели команд") .. ": " .. tostring(err) .. "|r") end
    end
	return true
end
