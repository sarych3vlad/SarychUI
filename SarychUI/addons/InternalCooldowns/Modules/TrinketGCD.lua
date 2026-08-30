local mod = LibStub("AceAddon-3.0"):GetAddon("InternalCooldowns"):NewModule("TrinketGCD", "AceEvent-3.0");
local lib = LibStub("LibInternalCooldowns-1.1");

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.InternalCooldowns then
		return SarychUI.db.profile.addons.InternalCooldowns.enabled ~= false;
	end
	return InternalCooldownsEnabled ~= false;
end

local GetInventorySlotInfo = GetInventorySlotInfo;
local TRINKET0_SLOT_ID = select(1, GetInventorySlotInfo("Trinket0Slot")) or 13
local TRINKET1_SLOT_ID = select(1, GetInventorySlotInfo("Trinket1Slot")) or 14

local TRINKET_SLOTS = {
    TRINKET0_SLOT_ID,
    TRINKET1_SLOT_ID,
};

local TRINKET_GCD_DURATION = 30; -- 30 секунд ГКД для тринкетов

-- Отслеживаем предыдущие тринкеты
local previousTrinkets = {};

function mod:OnEnable()
    if not IsEnabled() then
        return
    end
    -- Регистрируем события для отслеживания смены тринкетов
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    
    -- Инициализируем предыдущие тринкеты
    self:InitializePreviousTrinkets();
end;

function mod:OnDisable()
    self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED");
    self:UnregisterEvent("PLAYER_ENTERING_WORLD");
end;

function mod:InitializePreviousTrinkets()
    -- Запоминаем текущие тринкеты при загрузке
    for _, slot in ipairs(TRINKET_SLOTS) do
        local itemID = GetInventoryItemID("player", slot);
        previousTrinkets[slot] = itemID;
    end
end;

function mod:PLAYER_EQUIPMENT_CHANGED(event, slot)
    -- Проверяем только слоты тринкетов
    if slot == TRINKET0_SLOT_ID or slot == TRINKET1_SLOT_ID then
        -- Без задержек: сравниваем кэш и текущее состояние и ставим 30с только изменённым слотам
        local prev0 = previousTrinkets[TRINKET0_SLOT_ID]
        local prev1 = previousTrinkets[TRINKET1_SLOT_ID]
        local cur0 = GetInventoryItemID("player", TRINKET0_SLOT_ID)
        local cur1 = GetInventoryItemID("player", TRINKET1_SLOT_ID)
        local changed0 = cur0 ~= prev0
        local changed1 = cur1 ~= prev1

        local now = GetTime()
        local function set(slot)
            if not slot then return end
            lib:SetSlotCooldown(slot, now, TRINKET_GCD_DURATION, "TRINKET_GCD")
        end

        if changed0 then set(TRINKET0_SLOT_ID) end
        if changed1 then set(TRINKET1_SLOT_ID) end

        -- Обновляем кэш сразу
        previousTrinkets[TRINKET0_SLOT_ID] = cur0
        previousTrinkets[TRINKET1_SLOT_ID] = cur1
    end
end;

function mod:PLAYER_ENTERING_WORLD()
    -- При входе в мир обновляем предыдущие тринкеты
    self:InitializePreviousTrinkets();
end;

function mod:RefreshPreviousTrinkets()
    for _, slot in ipairs(TRINKET_SLOTS) do
        previousTrinkets[slot] = GetInventoryItemID("player", slot);
    end
end;

function mod:CheckTrinketChange(slot)
    local currentItemID = GetInventoryItemID("player", slot);
    local previousItemID = previousTrinkets[slot];
    
    -- Если тринкет изменился (надели новый или сняли старый)
    if currentItemID ~= previousItemID then
        -- Если надели новый тринкет
        if currentItemID and currentItemID > 0 then
            self:ApplyTrinketGCD(currentItemID, slot);
        end
        
        -- Обновляем предыдущий тринкет
        previousTrinkets[slot] = currentItemID;
    end
end;

function mod:ApplyTrinketGCD(itemID, slot)
    -- Проверяем, что это действительно тринкет
    if not self:IsTrinket(itemID) then
        return;
    end
    
    local currentTime = GetTime();
    local gcdDuration = TRINKET_GCD_DURATION; -- Всегда 30 секунд ГКД
    
    -- Проверяем, есть ли уже активный кулдаун на этом тринкете
    local startTime = lib.cooldownStartTimes[itemID];
    local duration = lib.cooldownDurations[itemID];
    
    if startTime and duration and startTime + duration > currentTime then
        -- Кулдаун уже активен, проверяем его длительность
        local remainingTime = startTime + duration - currentTime;
        
        -- Если оставшееся время меньше 30 секунд, устанавливаем новый 30-секундный ГКД
        if remainingTime < gcdDuration then
            -- Устанавливаем кулдаун напрямую в библиотеке
            lib.cooldownStartTimes[itemID] = currentTime;
            lib.cooldownDurations[itemID] = gcdDuration;
            lib.callbacks:Fire("InternalCooldowns_Proc", itemID, nil, currentTime, gcdDuration, "TRINKET_GCD");
        end
    else
        -- Кулдаун не активен, устанавливаем новый 30-секундный ГКД
        -- Устанавливаем кулдаун напрямую в библиотеке
        lib.cooldownStartTimes[itemID] = currentTime;
        lib.cooldownDurations[itemID] = gcdDuration;
        lib.callbacks:Fire("InternalCooldowns_Proc", itemID, nil, currentTime, gcdDuration, "TRINKET_GCD");
    end
end;

-- Синхронизация обоих слотов тринкетов по клиентскому КД (когда свапаем/надеваем)
function mod:SyncBothTrinketSlotsFromClient(avoidDowngrade)
    local function getSlotInfo(slot)
        local link = GetInventoryItemLink("player", slot);
        local id = link and tonumber(link:match("item:(%d+)")) or nil;
        local start, duration, enable = GetInventoryItemCooldown("player", slot);
        return id, start, duration, enable;
    end

    local id13, s13, d13, e13 = getSlotInfo(TRINKET0_SLOT_ID);
    local id14, s14, d14, e14 = getSlotInfo(TRINKET1_SLOT_ID);

    -- Нужен признак ГКД: около 30с
    local isGcd13 = e13 == 1 and d13 and d13 >= 28 and d13 <= 35;
    local isGcd14 = e14 == 1 and d14 and d14 >= 28 and d14 <= 35;

    if not id13 and not id14 then return end

    -- Если оба слота показывают ГКД — унифицируем и ставим обоим
    if isGcd13 and isGcd14 then
        local start = math.max(s13 or 0, s14 or 0);
        local duration = math.max(d13 or 0, d14 or 0);
        if duration < 28 or duration > 35 then duration = TRINKET_GCD_DURATION end
        if start == 0 then start = GetTime() end
        local function setIfBetter(id)
            if not id then return end
            if avoidDowngrade then
                local sInt = lib.cooldownStartTimes[id]
                local dInt = lib.cooldownDurations[id]
                if sInt and dInt then
                    local now = GetTime()
                    local remInt = (sInt + dInt - now)
                    local remCli = (start + duration - now)
                    if remInt and remInt > remCli - 0.05 then return end
                end
            end
            lib:SetExplicitCooldown(id, start, duration, "TRINKET_GCD")
        end
        setIfBetter(id13)
        setIfBetter(id14)
        return
    end

    -- Если только один слот показывает ГКД — ставим только ему
    local function setSingle(id, st, dur)
        if not id or not st or not dur then return end
        if dur < 28 or dur > 35 then dur = TRINKET_GCD_DURATION end
        if st == 0 then st = GetTime() end
        if avoidDowngrade then
            local sInt = lib.cooldownStartTimes[id]
            local dInt = lib.cooldownDurations[id]
            if sInt and dInt then
                local now = GetTime()
                local remInt = (sInt + dInt - now)
                local remCli = (st + dur - now)
                if remInt and remInt > remCli - 0.05 then return end
            end
        end
        lib:SetExplicitCooldown(id, st, dur, "TRINKET_GCD")
    end
    if isGcd13 and not isGcd14 then setSingle(id13, s13, d13); return end
    if isGcd14 and not isGcd13 then setSingle(id14, s14, d14); return end

    -- Фоллбэк: если произошло изменение и клиент ещё не отдал ГКД, но тринки есть — можно принудительно поставить 30с от сейчас
    -- Это покроет редкие гонки, UI потом синхронизируется
    local now = GetTime();
    if id13 then lib:SetExplicitCooldown(id13, now, TRINKET_GCD_DURATION, "TRINKET_GCD") end
    if id14 then lib:SetExplicitCooldown(id14, now, TRINKET_GCD_DURATION, "TRINKET_GCD") end
end

-- Принудительно начать новый 30с ГКД обоим тринкетам (для жёсткой консистентности при свапе)
-- удалено: ForceFreshGCDSelective — больше не нужен, т.к. логика без задержек

function mod:IsTrinket(itemID)
    if not itemID then return false; end
    
    -- Проверяем тип предмета
    local itemType, itemSubType = GetItemInfoInstant(itemID);
    if itemType == "Miscellaneous" and itemSubType == "Trinket" then
        return true;
    end
    
    -- Дополнительная проверка по слотам инвентаря
    local invSlot = GetInventorySlotInfo("Trinket0Slot");
    if invSlot then
        local equippedItem = GetInventoryItemID("player", invSlot);
        if equippedItem == itemID then
            return true;
        end
    end
    
    local invSlot1 = GetInventorySlotInfo("Trinket1Slot");
    if invSlot1 then
        local equippedItem = GetInventoryItemID("player", invSlot1);
        if equippedItem == itemID then
            return true;
        end
    end
    
    return false;
end;
-- debug print removed
