local MAJOR = "LibInternalCooldowns-1.1";
local MINOR = tonumber(("$Revision: 16 $"):match("%d+"));

local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end -- No Upgrade needed.

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0");

local GetInventoryItemLink = _G.GetInventoryItemLink;
local GetItemInfo = _G.GetItemInfo;
local GetInventoryItemTexture = _G.GetInventoryItemTexture;
local GetMacroInfo = _G.GetMacroInfo;
local GetActionInfo = _G.GetActionInfo;
local substr = _G.string.sub;
local wipe = _G.wipe;
local playerGUID = UnitGUID("player") or "";
local GetTime = _G.GetTime;
local GetInventorySlotInfo = _G.GetInventorySlotInfo;

lib.spellToItem = lib.spellToItem or {};
lib.cooldownStartTimes = lib.cooldownStartTimes or {};
lib.cooldownDurations = lib.cooldownDurations or {};
lib.callbacks = lib.callbacks or CallbackHandler:New(lib);
lib.cooldowns = lib.cooldowns or nil;
lib.hooks = lib.hooks or {};
-- Кулдауны на уровне слотов
lib.slotCooldownStartTimes = lib.slotCooldownStartTimes or {};
lib.slotCooldownDurations = lib.slotCooldownDurations or {};

-- Определяем реальные ID слотов тринкетов на клиенте (могут отличаться по версии)
local TRINKET0_SLOT_ID = select(1, GetInventorySlotInfo("Trinket0Slot")) or 13
local TRINKET1_SLOT_ID = select(1, GetInventorySlotInfo("Trinket1Slot")) or 14

local enchantProcTimes = {};

if not lib.eventFrame then
	lib.eventFrame = CreateFrame("Frame")
	lib.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	lib.eventFrame:RegisterEvent("ADDON_LOADED")
	lib.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	lib.eventFrame:RegisterEvent("PLAYER_LOGOUT")
	lib.eventFrame:SetScript("OnEvent", function(frame, event, ...)
		frame.lib[event](frame.lib, event, ...)
	end)
	
	-- Убираем периодическое сохранение - сохраняем только при событиях
end;
lib.eventFrame.lib = lib

-- Боевой лог — единственный поток высокой частоты в этой библиотеке. Слушаем его,
-- только пока кто-то подписан на проки (тот же контракт OnUsed/OnUnused,
-- что уже используется в LibAuraInfo-1.0 и LibCooldownTracker-1.0).
lib.usedCallbacks = lib.usedCallbacks or {}

function lib.callbacks:OnUsed(target, eventname)
	lib.usedCallbacks[eventname] = true
	lib.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function lib.callbacks:OnUnused(target, eventname)
	lib.usedCallbacks[eventname] = nil
	if not next(lib.usedCallbacks) then
		lib.eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

local INVALID_EVENTS = {
	SPELL_DISPEL 			= true,
	SPELL_DISPEL_FAILED 	= true,
	SPELL_STOLEN 			= true,
	SPELL_AURA_REMOVED 		= true,
	SPELL_AURA_REMOVED_DOSE = true,
	SPELL_AURA_BROKEN 		= true,
	SPELL_AURA_BROKEN_SPELL = true,
	SPELL_CAST_FAILED 		= true
};

local slots = {
	AMMOSLOT = 0,
	INVTYPE_HEAD = 1,
	INVTYPE_NECK = 2,
	INVTYPE_SHOULDER = 3,
	INVTYPE_BODY = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8,
	INVTYPE_WRIST = 9,
	INVTYPE_HAND = 10,
	INVTYPE_FINGER = {11, 12},
	INVTYPE_TRINKET = {13, 14},
	INVTYPE_CLOAK = 15,
	INVTYPE_WEAPONMAINHAND = 16,
	INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPON = {16, 17},
	INVTYPE_HOLDABLE = 17,
	INVTYPE_SHIELD = 17,
	INVTYPE_WEAPONOFFHAND = 17,
	INVTYPE_RANGED = 18
};

function lib:PLAYER_ENTERING_WORLD()
	playerGUID = UnitGUID("player")	
	self:Hook("GetInventoryItemCooldown")
	self:Hook("GetActionCooldown")
	self:Hook("GetItemCooldown")

	-- На всякий случай синхронизируем экипировку при входе (может быть ГКД от переэкипировки из прошлой сессии неактуален)
	C_Timer.After(0.5, function()
		self:HandleTrinketEquipCooldown()
	end)
	
	-- Восстанавливаем сохраненные кулдауны с задержкой
	C_Timer.After(3, function()
		self:RestoreCooldowns()
	end)
end;

function lib:ADDON_LOADED(addonName)
	if addonName == "InternalCooldowns" then
		-- Ждем полной инициализации аддона
		C_Timer.After(2, function()
			self:RestoreCooldowns()
		end)
		
		-- Добавляем хук для принудительного сохранения при выгрузке аддона
		local addon = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns")
		if addon then
			local originalOnDisable = addon.OnDisable
			addon.OnDisable = function(self)
				lib:SaveCooldowns()
				if originalOnDisable then
					originalOnDisable(self)
				end
			end
		end
	end
end;

function lib:PLAYER_LOGOUT()
	-- Принудительно сохраняем кулдауны при выходе
	self:SaveCooldowns()
end;

function lib:Hook(name)
	-- unhook if a hook existed from an older copy
	if lib.hooks[name] then
		_G[name] = lib.hooks[name]
	end
	
	-- Re-hook it now
	lib.hooks[name] = _G[name]
	_G[name] = function(...)
		return self[name](self, ...)
	end
end;

local function checkSlotForEnchantID(slot, enchantID)
	local link = GetInventoryItemLink("player", slot)
	if not link then return false; end
	local itemID, enchant = link:match("item:(%d+):(%d+)")
	if tonumber(enchant or -1) == enchantID then
		return true, tonumber(itemID);
	else
		return false;
	end
end;

local function checkInvType(id)
	local _, _, _, _, _, _, _, _, invType = GetItemInfo(id)
	return invType;
end;

local function isEquipped(itemID)
	local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID)
	local slot = slots[equipLoc]
	
	if type(slot) == "table" then
		for _, v in ipairs(slot) do
			local link = GetInventoryItemLink("player", v)
			if link and link:match(("item:%s"):format(itemID)) then
				return true;
			end
		end
	else
		local link = GetInventoryItemLink("player", slot)
		if link and link:match(("item:%s"):format(itemID)) then
			return true;
		end
	end
	return false;
end;

function lib:COMBAT_LOG_EVENT_UNFILTERED(frame, timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName)
	playerGUID = playerGUID or UnitGUID("player");
	if ((destGUID == playerGUID and (sourceGUID == nil or sourceGUID == destGUID)) 
	or sourceGUID == playerGUID) and not INVALID_EVENTS[event] and substr(event, 0, 6) == "SPELL_" then
		local itemID = lib.spellToItem[spellID]
		if itemID then
			if type(itemID) == "table" then			
				for k, v in ipairs(itemID) do
					if isEquipped(v) 
					and (checkInvType(v) ~= "INVTYPE_HEAD"
					and checkInvType(v) ~= "INVTYPE_HAND") then
						self:SetCooldownFor(v, spellID, "ITEM");
					end
				end
				return;
			else
				if isEquipped(itemID) then
					self:SetCooldownFor(itemID, spellID, "ITEM");
				end
				return;
			end
		end
		
		-- Tests for enchant procs 
		local enchantID = lib.enchants[spellID]
		if enchantID then
			local enchantID, slot1, slot2 = unpack(enchantID);
			local enchantPresent, itemID, first, second;
			enchantPresent, itemID = checkSlotForEnchantID(slot1, enchantID)
			if enchantPresent then
				first = itemID
				if (enchantProcTimes[slot1] or 0) < GetTime() - (lib.cooldowns[spellID] or 45) then
					enchantProcTimes[slot1] = GetTime();
					self:SetCooldownFor(itemID, spellID, "ENCHANT");
					return;
				end
			end

			enchantPresent, itemID = checkSlotForEnchantID(slot2, enchantID);
			if enchantPresent then
				second = itemID
				if (enchantProcTimes[slot2] or 0) < GetTime() - (lib.cooldowns[spellID] or 45) then
					enchantProcTimes[slot2] = GetTime()
					self:SetCooldownFor(itemID, spellID, "ENCHANT");
					return;
				end
			end
			
			if first and second then
				if enchantProcTimes[slot1] < enchantProcTimes[slot2] then
					self:SetCooldownFor(first, spellID, "ENCHANT");
				else
					self:SetCooldownFor(second, spellID, "ENCHANT");
				end
			end
		end
		
		local metaID = lib.metas[spellID];
		if metaID then
			local link = GetInventoryItemLink("player", 1);
			if link then
				local id = tonumber(link:match("item:(%d+)") or 0);
				local haveSpell = GetItemSpell(id);
				if id and id ~= 0 
				and haveSpell == nil then
					self:SetCooldownFor(id, spellID, "META");
				end
			end
			return;
		end
		
		local talentID = lib.talents[spellID];
		if talentID then
			self:SetCooldownFor(("%s: %s"):format(UnitClass("player"), talentID), spellID, "TALENT");
			return;
		end
	end
end;

function lib:SetCooldownFor(itemID, spellID, procSource)
	local duration = lib.cooldowns[spellID] or 45;
	lib.cooldownStartTimes[itemID] = GetTime()
	lib.cooldownDurations[itemID] = duration
	
	-- Talents have a separate callback, so that InternalCooldowns_Proc always has an item ID.
	if procSource == "TALENT" then
		lib.callbacks:Fire("InternalCooldowns_TalentProc", spellID, GetTime(), duration, procSource)
	else
		lib.callbacks:Fire("InternalCooldowns_Proc", itemID, spellID, GetTime(), duration, procSource)
	end
end;

-- Установка кулдауна с явными параметрами (для ГКД от переэкипировки)
function lib:SetExplicitCooldown(itemID, startTime, duration, source)
	if not itemID or not duration or duration <= 0 then return end
	lib.cooldownStartTimes[itemID] = startTime or GetTime()
	lib.cooldownDurations[itemID] = duration
	lib.callbacks:Fire("InternalCooldowns_Proc", itemID, nil, lib.cooldownStartTimes[itemID], lib.cooldownDurations[itemID], source or "EXPLICIT")
	C_Timer.After(0.1, function()
		self:SaveCooldowns()
	end)
end

-- Слотовый КД + синхронизация предмета в слоте
function lib:SetSlotCooldown(slot, startTime, duration, source)
    if not slot or not duration or duration <= 0 then return end
    local now = GetTime()
    local st = startTime or now
    -- Ставим КД только для тринкет-слотов 13/14, чтобы не трогать другие слоты
    if slot ~= 13 and slot ~= 14 then return end
    lib.slotCooldownStartTimes[slot] = st
    lib.slotCooldownDurations[slot] = duration
    local link = GetInventoryItemLink("player", slot)
    if link then
        local id = tonumber(link:match("item:(%d+)"))
        if id then
            lib.cooldownStartTimes[id] = st
            lib.cooldownDurations[id] = duration
            lib.callbacks:Fire("InternalCooldowns_Proc", id, nil, st, duration, source or "SLOT")
        end
    end
    C_Timer.After(0.1, function()
        lib:SaveCooldowns()
    end)
end

-- Обработка 30-секундного ГКД при переэкипировке аксессуаров
function lib:PLAYER_EQUIPMENT_CHANGED(event, slotId, isEmpty)
	-- Слоты тринок: 13 и 14
	if slotId ~= 13 and slotId ~= 14 then return end
	C_Timer.After(0, function()
		self:HandleTrinketEquipCooldown()
	end)
end

function lib:HandleTrinketEquipCooldown()
	local now = GetTime()
	local function setIfItem(slot)
		local link = GetInventoryItemLink("player", slot)
		if not link then return end
		local id = tonumber(link:match("item:(%d+)"))
		if not id then return end
		-- Попробуем получить реальный КД от клиента
		local start, duration, enable = lib.hooks.GetInventoryItemCooldown("player", slot)
		-- Если клиент показывает 30с ГКД (или около), синхронизируемся
		if enable == 1 and duration and duration >= 28 and duration <= 35 then
			-- Принудительно выставляем наш таймер, чтобы UI обновился сразу
			self:SetExplicitCooldown(id, start or now, duration, "EQUIP_GCD")
		end
	end
	setIfItem(13)
	setIfItem(14)
end

local function cooldownReturn(id)
	if not id then return end
	local hasItem = id and lib.cooldownStartTimes[id] and lib.cooldownDurations[id]
	if hasItem then
		if lib.cooldownStartTimes[id] + lib.cooldownDurations[id] > GetTime() then
			return lib.cooldownStartTimes[id], lib.cooldownDurations[id], 1
		else
			return 0, 0, 0;
		end
	else
		return nil;
	end
end;

function lib:IsInternalItemCooldown(itemID)
	return cooldownReturn(itemID) ~= nil;
end;

function lib:GetInventoryItemCooldown(unit, slot)
    local start, duration, enable = self.hooks.GetInventoryItemCooldown(unit, slot)
    -- Слотовый КД имеет приоритет
    local sSlot = lib.slotCooldownStartTimes[slot]
    local dSlot = lib.slotCooldownDurations[slot]
    if sSlot and dSlot and (sSlot + dSlot) > GetTime() then
        return sSlot, dSlot, 1
    end
    if not enable or enable == 0 then
		local link = GetInventoryItemLink("player", slot)
		if link then
			local itemID = link:match("item:(%d+)")
			itemID = tonumber(itemID or 0)
			
			local start, duration, running = cooldownReturn(itemID)
			if start then 
				return start, duration, running 
			end
		end
    else
        -- Даже если клиент уже показывает КД, отдаём максимум из нашего внутреннего и клиентского значений
        local link = GetInventoryItemLink("player", slot)
        if link then
            local itemID = tonumber((link:match("item:(%d+)")) or 0)
            if itemID and itemID > 0 then
                local s2, d2, r2 = cooldownReturn(itemID)
                if s2 and d2 then
                    local now = GetTime()
                    local remClient = (start and duration and (start + duration - now)) or 0
                    local remInternal = (s2 + d2 - now)
                    if remInternal > remClient + 0.05 then
                        return s2, d2, 1
                    end
                end
            end
        end
    end
    return start, duration, enable;
end;

function lib:GetActionCooldown(slotID)
    local t, id, subtype, globalID = GetActionInfo(slotID)
    if t == "item" then
        local start, duration, running = cooldownReturn(id)
        if start then 
            return start, duration, running 
        end
    elseif t == "macro" then
        local _, tex = GetMacroInfo(id)
        if tex == GetInventoryItemTexture("player", 13) then
            local itemLink = GetInventoryItemLink("player", 13)
            if itemLink then
                id = tonumber(itemLink:match("item:(%d+)"))
                local start, duration, running = cooldownReturn(id)
                if start then 
                    return start, duration, running 
                end
            end
        elseif tex == GetInventoryItemTexture("player", 14) then
            local itemLink = GetInventoryItemLink("player", 14)
            if itemLink then
                id = tonumber(itemLink:match("item:(%d+)"))
                local start, duration, running = cooldownReturn(id)
                if start then 
                    return start, duration, running 
                end
            end
        end
    end
    return self.hooks.GetActionCooldown(slotID);
end

function lib:GetItemCooldown(param)
	local id
	local iparam = tonumber(param)
		if iparam and iparam > 0 then
			id = param
	elseif type(param) == "string" then
			local name, link = GetItemInfo(param)
			if link then
				id = link:match("item:(%d+)")
			end
		end
		
		if id then
			id = tonumber(id)
			local start, duration, running = cooldownReturn(id)
			if start then return start, duration, running end
		end
	
	return self.hooks.GetItemCooldown(param)
end;

-- Функции для сохранения и восстановления кулдаунов
function lib:SaveCooldowns()
	-- Создаем SavedVariables если они не существуют
	if not InternalCooldownsDB then
		InternalCooldownsDB = {
			activeCooldowns = {},
			persistCooldowns = true
		}
	end
	
	local currentTime = GetTime()
	local nowEpoch = (GetServerTime and GetServerTime()) or time()
	local savedCooldowns = {}
	local savedCount = 0
	
	-- Сохраняем только активные кулдауны
	for itemID, startTime in pairs(lib.cooldownStartTimes) do
		local duration = lib.cooldownDurations[itemID]
		if duration and startTime + duration > currentTime then
			-- Пересчитываем оставшееся время в абсолютный expireAt
			local remaining = (startTime + duration) - currentTime
			if remaining > 0 then
				savedCooldowns[itemID] = {
					expireAt = nowEpoch + remaining,
					duration = duration
				}
				savedCount = savedCount + 1
			end
		end
	end
	
	InternalCooldownsDB.activeCooldowns = savedCooldowns
end

function lib:RestoreCooldowns()
	-- Создаем SavedVariables если они не существуют
	if not InternalCooldownsDB then
		InternalCooldownsDB = {
			activeCooldowns = {},
			persistCooldowns = true
		}
		return
	end
	
	if not InternalCooldownsDB.persistCooldowns then 
		return 
	end
	
	local savedCooldowns = InternalCooldownsDB.activeCooldowns
	if not savedCooldowns or type(savedCooldowns) ~= "table" then 
		return 
	end
	
	local currentTime = GetTime()
	local nowEpoch = (GetServerTime and GetServerTime()) or time()
	local restoredCount = 0
	local pruned = {}
	
	-- Защита от мусорных данных: допускаем максимум duration + 1ч запаса
	local MAX_GRACE = 3600
	for itemID, cooldownData in pairs(savedCooldowns) do
		local duration = cooldownData.duration
		local expireAt = cooldownData.expireAt
		if expireAt and duration then
			local remaining = expireAt - nowEpoch
			if remaining > 0 and remaining <= duration + MAX_GRACE then
				-- Восстанавливаем start относительно текущего GetTime
				lib.cooldownStartTimes[itemID] = currentTime - (duration - remaining)
				lib.cooldownDurations[itemID] = duration
				restoredCount = restoredCount + 1
				-- Переписываем сохранённые данные только актуальными (продлеваем хранение до конца КД)
				pruned[itemID] = { expireAt = expireAt, duration = duration }
				lib.callbacks:Fire("InternalCooldowns_Proc", itemID, nil, lib.cooldownStartTimes[itemID], lib.cooldownDurations[itemID], "RESTORED")
			end
		end
	end

	-- Перезаписываем SavedVariables только валидными данными (очистка мусора)
	InternalCooldownsDB.activeCooldowns = pruned
end

-- Сохраняем кулдауны при каждом изменении
local originalSetCooldownFor = lib.SetCooldownFor
function lib:SetCooldownFor(itemID, spellID, procSource)
	originalSetCooldownFor(self, itemID, spellID, procSource)
	
	-- Сохраняем кулдаун
	C_Timer.After(0.1, function()
		self:SaveCooldowns()
	end)
end

-- Хук для принудительного сохранения при выгрузке аддона будет добавлен в ADDON_LOADED